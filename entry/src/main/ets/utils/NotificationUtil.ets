import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { ApiService } from '../service/ApiService';
import { GlobalState, CheckInType, Habit } from '../model/Models';

const DOMAIN = 0x0000;
const TAG = 'NotificationUtil';

// ========== 业务配置 ==========
// 通知ID基础偏移量，避免与其他通知冲突
const NOTIFICATION_ID_BASE = 10000;

export class NotificationUtil {
  private static context: common.UIAbilityContext | null = null;

  /**
   * 初始化通知工具类（必须在应用启动时调用）
   */
  static initialize(context: common.UIAbilityContext): void {
    NotificationUtil.context = context;
    hilog.info(DOMAIN, TAG, 'NotificationUtil 初始化完成');
  }

  /**
   * 检查通知权限是否已启用（同步）
   */
  static isNotificationEnabled(): boolean {
    try {
      return notificationManager.isNotificationEnabledSync();
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `检查通知状态失败: ${error.code} - ${error.message}`);
      return false;
    }
  }

  /**
   * 请求通知权限
   * @returns Promise<boolean> 是否授权成功
   */
  static async requestNotificationPermission(): Promise<boolean> {
    if (!NotificationUtil.context) {
      hilog.error(DOMAIN, TAG, 'NotificationUtil 未初始化，请先调用 initialize 方法');
      return false;
    }

    try {
      // 先检查是否已授权
      const isEnabled = await notificationManager.isNotificationEnabled();
      if (isEnabled) {
        hilog.info(DOMAIN, TAG, '通知权限已开启');
        return true;
      }

      // 请求授权
      await notificationManager.requestEnableNotification(NotificationUtil.context);
      hilog.info(DOMAIN, TAG, '通知权限请求成功');
      return true;
    } catch (err) {
      const error = err as BusinessError;
      if (error.code === 1600004) {
        hilog.warn(DOMAIN, TAG, '用户拒绝了通知权限');
        // 用户拒绝后，可以引导用户打开设置页面
        await NotificationUtil.openNotificationSettings();
      } else {
        hilog.error(DOMAIN, TAG, `请求通知权限失败: ${error.code} - ${error.message}`);
      }
      return false;
    }
  }

  /**
   * 打开通知设置页面
   */
  static async openNotificationSettings(): Promise<void> {
    if (!NotificationUtil.context) {
      hilog.error(DOMAIN, TAG, 'NotificationUtil 未初始化');
      return;
    }

    try {
      await notificationManager.openNotificationSettings(NotificationUtil.context);
      hilog.info(DOMAIN, TAG, '通知设置页面已打开');
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `打开通知设置失败: ${error.code} - ${error.message}`);
    }
  }

  /**
   * 发送打卡提醒通知
   * @param habitId 习惯ID
   * @param habitName 习惯名称
   * @param message 通知消息
   */
  static async sendCheckInReminder(habitId: number, habitName: string, message: string): Promise<boolean> {
    // 检查通知权限
    if (!NotificationUtil.isNotificationEnabled()) {
      hilog.warn(DOMAIN, TAG, '通知权限未开启，尝试请求权限');
      const granted = await NotificationUtil.requestNotificationPermission();
      if (!granted) {
        hilog.error(DOMAIN, TAG, '无法获取通知权限，取消发送通知');
        return false;
      }
    }

    const notificationId = NOTIFICATION_ID_BASE + habitId;
    const notificationRequest: notificationManager.NotificationRequest = {
      id: notificationId,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: `📌 ${habitName}`,
          text: message,
        }
      }
    };

    try {
      await notificationManager.publish(notificationRequest);
      hilog.info(DOMAIN, TAG, `通知发送成功: habitId=${habitId}, notificationId=${notificationId}`);
      
      // 设置角标数字
      await notificationManager.setBadgeNumber(1);
      return true;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `通知发送失败: ${error.code} - ${error.message}`);
      return false;
    }
  }

  /**
   * 取消指定习惯的通知
   */
  static async cancelNotification(habitId: number): Promise<void> {
    const notificationId = NOTIFICATION_ID_BASE + habitId;
    try {
      await notificationManager.cancel(notificationId);
      hilog.info(DOMAIN, TAG, `通知取消成功: habitId=${habitId}, notificationId=${notificationId}`);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `通知取消失败: ${error.code} - ${error.message}`);
    }
  }

  /**
   * 取消所有通知
   */
  static async cancelAllNotifications(): Promise<void> {
    try {
      await notificationManager.cancelAll();
      hilog.info(DOMAIN, TAG, '所有通知已取消');
      
      // 清除角标
      await notificationManager.setBadgeNumber(0);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `取消所有通知失败: ${error.code} - ${error.message}`);
    }
  }

  /**
   * 检查并发送打卡提醒
   * 在应用启动时调用，检查未打卡习惯并发送通知
   */
  static async checkAndSendReminders(): Promise<void> {
    try {
      // 检查登录状态
      const token = GlobalState.token;
      if (!token) {
        hilog.info(DOMAIN, TAG, '未登录，跳过提醒检查');
        return;
      }

      const userId = GlobalState.userId;

      // 获取习惯列表
      const habits = await ApiService.getHabits(userId);
      if (!habits || habits.length === 0) {
        hilog.info(DOMAIN, TAG, '没有习惯数据，跳过提醒检查');
        return;
      }

      // 获取今日打卡状态
      const today = new Date().toISOString().split('T')[0];
      const checkInStatus = await ApiService.getCheckInStatus(userId, today);

      let reminderCount = 0;
      for (const habit of habits) {
        // 检查是否已打卡
        let isCheckedIn = false;
        if (habit.checkInType === CheckInType.DAILY) {
          isCheckedIn = checkInStatus[habit.id] || false;
        } else {
          isCheckedIn = habit.isCheckedIn;
        }

        // 未打卡的习惯发送通知
        if (!isCheckedIn) {
          const message = `别忘了完成今日「${habit.name}」打卡哦~`;
          const success = await NotificationUtil.sendCheckInReminder(habit.id, habit.name, message);
          if (success) {
            reminderCount++;
          }
        }
      }

      hilog.info(DOMAIN, TAG, `提醒检查完成，共发送${reminderCount}条通知`);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `检查并发送提醒失败: ${error.message}`);
    }
  }

  /**
   * 打卡成功后取消对应通知
   */
  static async onCheckInSuccess(habitId: number): Promise<void> {
    await NotificationUtil.cancelNotification(habitId);
    
    // 检查是否还有未打卡习惯，更新角标
    try {
      const userId = GlobalState.userId;
      const habits = await ApiService.getHabits(userId);
      const today = new Date().toISOString().split('T')[0];
      const checkInStatus = await ApiService.getCheckInStatus(userId, today);
      
      let uncheckedCount = 0;
      for (const habit of habits) {
        let isCheckedIn = false;
        if (habit.checkInType === CheckInType.DAILY) {
          isCheckedIn = checkInStatus[habit.id] || false;
        } else {
          isCheckedIn = habit.isCheckedIn;
        }
        if (!isCheckedIn) {
          uncheckedCount++;
        }
      }
      
      // 更新角标数字
      await notificationManager.setBadgeNumber(uncheckedCount);
      hilog.info(DOMAIN, TAG, `角标更新: ${uncheckedCount}`);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `更新角标失败: ${error.message}`);
    }
  }
}
