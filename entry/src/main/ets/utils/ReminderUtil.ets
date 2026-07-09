import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiService } from '../service/ApiService';
import { GlobalState, CheckInType } from '../model/Models';

const DOMAIN = 0x0000;
const TAG = 'ReminderUtil';

// ========== 业务配置 ==========
// 关键时间点提醒：早、中、晚三个关键时间点
const KEY_REMIND_HOURS = [8, 12, 16]; // 8:00, 12:00, 16:00
// 到期前提前提醒时长：30分钟
const ADVANCE_MINUTES = 30;
// 应用包名与主Ability，点击通知跳转使用
const BUNDLE_NAME = 'com.example.hobit';
const ABILITY_NAME = 'EntryAbility';
// 单个习惯占用2个提醒ID，通过偏移量区分
const NOTIFICATION_ID_OFFSET = 10000;

interface ReminderExtInfo extends reminderAgentManager.ReminderInfo {
  notificationId?: number;
}

export class ReminderUtil {
  /**
   * 为单个每日习惯创建全套提醒
   * 实现真正的每小时循环提醒 + 到期前30分钟精准提醒
   * @param habitId 习惯ID，作为通知唯一标识
   * @param habitName 习惯名称，用于通知内容
   * @param remindTimeStr 习惯打卡时间，格式 HH:mm
   */
  static async addDailyReminder(habitId: number, habitName: string, remindTimeStr: string): Promise<void> {
    // 1. 解析时间
    let targetHour: number;
    let targetMinute: number;
    try {
      const timeArr = remindTimeStr.split(':').map(Number);
      targetHour = timeArr[0];
      targetMinute = timeArr[1];
      if (isNaN(targetHour) || isNaN(targetMinute)) {
        hilog.error(DOMAIN, TAG, `时间格式错误: ${remindTimeStr}`);
        return;
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `提醒时间解析失败: ${remindTimeStr}`);
      return;
    }

    // 2. 先取消该习惯已有的旧提醒，避免重复
    await ReminderUtil.cancelReminder(habitId);

    // 3. 计算到期前30分钟的精准提醒时间
    let advanceHour = targetHour;
    let advanceMinute = targetMinute - ADVANCE_MINUTES;
    if (advanceMinute < 0) {
      advanceHour -= 1;
      advanceMinute += 60;
    }

    // 4. 创建到期前30分钟精准提醒（每日重复）
    if (advanceHour >= 6) { // 至少在早上6点之后
      const preciseAlarm: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        title: '⏰ 打卡即将到期',
        content: `「${habitName}」还有30分钟就到打卡时间啦，快去完成吧~`,
        hour: advanceHour,
        minute: advanceMinute,
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // 每日重复
        notificationId: habitId + NOTIFICATION_ID_OFFSET,
        wantAgent: {
          pkgName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        },
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        ringDuration: 5,
        snoozeTimes: 0, // 精准提醒不贪睡
        timeInterval: 0
      };

      try {
        await reminderAgentManager.publishReminder(preciseAlarm);
        hilog.info(DOMAIN, TAG,
          `精准提醒已创建: habitId=${habitId}, 时间=${advanceHour}:${String(advanceMinute).padStart(2, '0')}`
        );
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, TAG, `精准提醒创建失败: ${error.code} ${error.message}`);
      }
    }

    // 5. 创建关键时间点提醒（早、中、晚三个时间点）
    // 只在精准提醒时间之前的关键时间点创建提醒
    let successCount = 0;
    for (const hour of KEY_REMIND_HOURS) {
      // 跳过在精准提醒时间之后或相同的关键时间点
      if (hour >= advanceHour) {
        continue;
      }
      
      // 使用不同的notificationId区分：habitId * 100 + hour
      const loopNotificationId = habitId * 100 + hour;
      
      const loopAlarm: reminderAgentManager.ReminderRequestAlarm = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
        title: '📌 习惯打卡提醒',
        content: `别忘了完成今日「${habitName}」打卡哦~`,
        hour: hour,
        minute: 0, // 整点提醒
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7], // 每日重复
        notificationId: loopNotificationId,
        wantAgent: {
          pkgName: BUNDLE_NAME,
          abilityName: ABILITY_NAME
        },
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        ringDuration: 3,
        snoozeTimes: 0,
        timeInterval: 0
      };

      try {
        await reminderAgentManager.publishReminder(loopAlarm);
        successCount++;
        hilog.info(DOMAIN, TAG,
          `关键时间点提醒已创建: habitId=${habitId}, 时间=${hour}:00`
        );
      } catch (err) {
        const error = err as BusinessError;
        hilog.error(DOMAIN, TAG, `关键时间点提醒创建失败(${hour}:00): ${error.code} ${error.message}`);
      }
    }
    
    if (successCount > 0) {
      hilog.info(DOMAIN, TAG, 
        `习惯「${habitName}」共创建${successCount}个关键时间点提醒 + 1个精准提醒`
      );
    }
  }

  /**
   * 取消指定习惯的全部提醒（关键时间点提醒 + 精准提醒）
   */
  static async cancelReminder(habitId: number): Promise<void> {
    try {
      const reminders = await reminderAgentManager.getAllValidReminders();
      let cancelCount = 0;
      for (const r of reminders) {
        const extInfo = r as ReminderExtInfo;
        const notificationId = extInfo.notificationId;
        
        // 跳过无效的 notificationId
        if (notificationId === undefined) {
          continue;
        }
        
        // 匹配该习惯的所有提醒ID：
        // 1. 精准提醒: habitId + NOTIFICATION_ID_OFFSET
        // 2. 关键时间点提醒: habitId * 100 + hour (hour范围: 8, 12, 16)
        const isPreciseReminder = notificationId === habitId + NOTIFICATION_ID_OFFSET;
        const isKeyReminder = KEY_REMIND_HOURS.some(hour => notificationId === habitId * 100 + hour);
        
        if (isPreciseReminder || isKeyReminder) {
          await reminderAgentManager.cancelReminder(r.reminderId);
          cancelCount++;
        }
      }
      hilog.info(DOMAIN, TAG, `取消提醒完成: habitId=${habitId}, 共取消${cancelCount}条`);
    } catch (err) {
      const error = err as BusinessError;
      // 1700003 为无有效提醒的错误码，忽略
      if (error.code !== 1700003) {
        hilog.error(DOMAIN, TAG, `取消提醒失败: ${error.code} ${error.message}`);
      }
    }
  }

  /**
   * 获取所有有效提醒ID
   */
  static async getAllReminders(): Promise<number[]> {
    try {
      const list = await reminderAgentManager.getAllValidReminders();
      return list.map((r: reminderAgentManager.ReminderInfo) => r.reminderId);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `获取提醒列表失败: ${JSON.stringify(err)}`);
      return [];
    }
  }

  /**
   * 清理所有无业务关联的残留提醒
   */
  static async cleanAllInvalidReminders(): Promise<void> {
    try {
      const reminders = await reminderAgentManager.getAllValidReminders();
      hilog.info(DOMAIN, TAG, `清理前有效提醒数量: ${reminders.length}`);
      for (const r of reminders) {
        const extInfo = r as ReminderExtInfo;
        // 无notificationId的为无效残留，直接清理
        if (!extInfo.notificationId) {
          await reminderAgentManager.cancelReminder(r.reminderId);
        }
      }
      const afterCount = (await reminderAgentManager.getAllValidReminders()).length;
      hilog.info(DOMAIN, TAG, `清理后有效提醒数量: ${afterCount}`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `清理提醒失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 重新调度所有未打卡习惯的提醒
   * 用于：登录后、应用启动时、切前台时
   */
  static async rescheduleAllReminders(): Promise<void> {
    try {
      // 1. 检查是否登录
      const isLogin = GlobalState.isLoggedIn();
      if (!isLogin) {
        hilog.info(DOMAIN, TAG, '未登录，跳过提醒调度');
        return;
      }

      hilog.info(DOMAIN, TAG, '开始重新调度提醒...');

      // 2. 清理无效提醒
      await ReminderUtil.cleanAllInvalidReminders();

      // 3. 获取习惯列表
      const userId = GlobalState.userId;
      const habits = await ApiService.getHabits(userId);
      if (!habits || habits.length === 0) {
        hilog.info(DOMAIN, TAG, '无习惯数据，跳过提醒创建');
        return;
      }

      // 4. 获取今日日期和打卡状态
      const today = ReminderUtil.formatDate(new Date());
      const checkInStatus = await ApiService.getCheckInStatus(userId, today);

      // 5. 为每个未打卡的习惯创建提醒
      let reminderCount = 0;
      for (const habit of habits) {
        // 跳过已删除或已完成的习惯
        if (habit.isDeleted === 1 || habit.isCompleted === 1) {
          continue;
        }

        // 检查是否已打卡
        let isCheckedIn = false;
        if (habit.checkInType === CheckInType.DAILY) {
          // 每日习惯：检查今日是否打卡
          isCheckedIn = checkInStatus[habit.id] || false;
        } else {
          // 一次性习惯：检查是否已打卡
          isCheckedIn = habit.isCheckedIn;
        }

        // 未打卡的习惯创建提醒
        if (!isCheckedIn && habit.remindTime) {
          await ReminderUtil.addDailyReminder(habit.id, habit.name, habit.remindTime);
          reminderCount++;
        }
      }

      hilog.info(DOMAIN, TAG, `提醒调度完成，共为${reminderCount}个未打卡习惯创建提醒`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `重新调度提醒失败: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 格式化日期为 YYYY-MM-DD
   */
  private static formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}