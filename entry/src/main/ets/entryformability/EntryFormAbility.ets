import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import Want from '@ohos.app.ability.Want';
import hilog from '@ohos.hilog';
import { formIdStore } from '../utils/FormIdStore';
import { request } from '../http/Request';
import { ApiService, CardDataVO, CardHabitItemVO } from '../service/ApiService';
import { prefUtil } from '../utils/PreferenceUtil';
import { tokenFileStore } from '../utils/TokenFileStore';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryFormAbility';

// 显式声明卡片数据接口，严格模式禁止匿名对象
interface CardFormData {
  loginStatus: string;
  progressText: string;
  tipText: string;
  isLoggedIn: boolean;
}

// 卡片事件消息结构
interface FormEventMessage {
  event: string;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm called');
    // 安全获取 formId，显式断言类型，消除隐式 any
    let formId: string = '';
    if (want.parameters) {
      const paramValue = want.parameters['ohos.extra.param.key.form_identity'] as string;
      formId = paramValue || '';
    }

    // 初始化工具类上下文
    formIdStore.init(this.context);
    formIdStore.addFormId(formId);
    request.setContext(this.context);
    prefUtil.init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'init pref failed: ' + err.message);
    });

    // 显式指定接口类型
    const initData: CardFormData = {
      loginStatus: '未登录',
      progressText: '0/0',
      tipText: '请打开APP登录账号',
      isLoggedIn: false
    };

    // 异步拉取最新数据并刷新卡片
    this.refreshCardData(formId).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '首次刷新卡片失败: ' + err.message);
    });

    return formBindingData.createFormBindingData(initData);
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onRemoveForm, formId=${formId}`);
    formIdStore.removeFormId(formId);
  }

  // 系统定时刷新触发
  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onUpdateForm, formId=${formId}`);
    prefUtil.init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'init pref failed: ' + err.message);
    });
    this.refreshCardData(formId).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, '定时刷新卡片失败: ' + err.message);
    });
  }

  // 接收卡片点击事件：API 10 标准签名，第二个参数为 string
  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, TAG, `onFormEvent: ${message}`);
    request.setContext(this.context);
    // 关键：每次点击事件都重新初始化偏好，确保拿到最新Token
    prefUtil.init(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, 'init pref failed: ' + err.message);
    });

    try {
      const msgObj: FormEventMessage = JSON.parse(message) as FormEventMessage;
      if (msgObj.event === 'quickCheckIn') {
        this.handleQuickCheckIn(formId).catch((err: Error) => {
          hilog.error(DOMAIN, TAG, '一键打卡失败: ' + err.message);
        });
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, '解析事件消息失败: ' + (e as Error).message);
    }
  }

  // ==================== 私有业务方法 ====================

  private async refreshCardData(formId: string): Promise<void> {
    try {
      const today: string = this.formatDate(new Date());
      const cardData: CardDataVO = await ApiService.getCardData(today);

      // 强校验字段，防止解析异常
      const isLoggedIn = Boolean(cardData.isLoggedIn);
      const completed = typeof cardData.completedCount === 'number' ? cardData.completedCount : 0;
      const total = typeof cardData.totalCount === 'number' ? cardData.totalCount : 0;

      const updateData: CardFormData = {
        loginStatus: isLoggedIn ? '已登录' : '未登录',
        progressText: `${completed}/${total}`,
        tipText: `今日完成 ${completed} 个习惯`,
        isLoggedIn: isLoggedIn
      };

      const formData = formBindingData.createFormBindingData(updateData);
      await formProvider.updateForm(formId, formData);
      hilog.info(DOMAIN, TAG, `刷新卡片成功: ${formId}, 进度 ${completed}/${total}`);
    } catch (e) {
      const errMsg = (e as Error).message;
      hilog.error(DOMAIN, TAG, `刷新卡片失败: ${errMsg}`);

      // 只有明确是鉴权错误，才重置为未登录
      const isAuthError = errMsg.includes('未登录') || errMsg.includes('401') || errMsg.includes('凭证');
      const errorData: CardFormData = isAuthError ? {
        loginStatus: '未登录',
        progressText: '0/0',
        tipText: '请打开APP登录账号',
        isLoggedIn: false
      } : {
        // 非鉴权错误：保持已登录状态，不显示锁图案
        loginStatus: '已登录',
        progressText: '--/--',
        tipText: '加载失败，请稍后重试',
        isLoggedIn: true
      };

      const formData = formBindingData.createFormBindingData(errorData);
      formProvider.updateForm(formId, formData).catch(() => {});
    }
  }

  private async handleQuickCheckIn(formId: string): Promise<void> {
    try {
      const today: string = this.formatDate(new Date());
      hilog.info(DOMAIN, TAG, `开始一键打卡，日期: ${today}`);

      const cardData: CardDataVO = await ApiService.getCardData(today);
      hilog.info(DOMAIN, TAG, `卡片数据获取成功，习惯总数: ${cardData.habits.length}`);

      if (!cardData.isLoggedIn) {
        throw new Error('未登录，无法打卡');
      }

      // 过滤出所有未打卡的每日习惯
      const uncheckedDailyHabits = cardData.habits.filter(
        (h: CardHabitItemVO): boolean => !h.isCheckedIn && h.isDaily
      );

      hilog.info(DOMAIN, TAG, `待打卡习惯数量: ${uncheckedDailyHabits.length}`);
      if (uncheckedDailyHabits.length === 0) {
        hilog.info(DOMAIN, TAG, '没有需要打卡的习惯，直接刷新卡片');
        await this.refreshCardData(formId);
        return;
      }

      // 逐个打卡（后端不支持批量）
      let successCount = 0;
      for (const habit of uncheckedDailyHabits) {
        try {
          hilog.info(DOMAIN, TAG, `正在打卡: ${habit.name} (ID: ${habit.id})`);
          await ApiService.quickCheckIn(habit.id, today);
          successCount++;
          hilog.info(DOMAIN, TAG, `打卡成功: ${habit.name}`);
        } catch (err) {
          const errMsg = (err as Error).message;
          hilog.error(DOMAIN, TAG, `打卡失败 [${habit.name}]: ${errMsg}`);
          // 失败时继续下一个，不中断整体流程
        }
      }

      hilog.info(DOMAIN, TAG, `一键打卡完成，成功: ${successCount}/${uncheckedDailyHabits.length}`);
      // 刷新卡片显示最新进度
      await this.refreshCardData(formId);
    } catch (e) {
      const errMsg = (e as Error).message;
      hilog.error(DOMAIN, TAG, `一键打卡流程异常: ${errMsg}`);
      // 即使异常也尝试刷新卡片
      this.refreshCardData(formId).catch(() => {});
    }
  }

  private formatDate(date: Date): string {
    const year: number = date.getFullYear();
    const month: string = String(date.getMonth() + 1).padStart(2, '0');
    const day: string = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}