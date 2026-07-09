import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';
import { formIdStore } from '../utils/FormIdStore';
import { formUpdateUtil } from '../utils/FormUpdateUtil';
import { GlobalState } from '../model/Models';
import { request } from '../http/Request';
import notificationManager from '@ohos.notificationManager';
import { NotificationUtil } from '../utils/NotificationUtil';
import { ApiService } from '../service/ApiService';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  // 标记全局状态是否初始化完成，解决冷启动时序问题
  private isGlobalStateReady: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    formIdStore.init(this.context);
    request.setContext(this.context);

    // 初始化通知工具类
    NotificationUtil.initialize(this.context);

    // 初始化通知渠道
    notificationManager.addSlot(
      notificationManager.SlotType.SOCIAL_COMMUNICATION,
      (err) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `addSlot failed: ${JSON.stringify(err)}`);
        }
      }
    );

    // 全局状态初始化完成后，主动检查并发送通知提醒
    GlobalState.initFromStorage(this.context)
      .then(() => {
        hilog.info(DOMAIN, TAG, 'GlobalState初始化完成');
        this.isGlobalStateReady = true;
        // 登录态有效则检查并发送通知提醒
        if (GlobalState.isLoggedIn()) {
          hilog.info(DOMAIN, TAG, '冷启动已登录，开始检查提醒');
          NotificationUtil.checkAndSendReminders().catch((err: BusinessError) => {
            hilog.error(DOMAIN, TAG, `冷启动提醒检查失败: ${err.message}`);
          });
        } else {
          hilog.info(DOMAIN, TAG, '冷启动未登录，跳过提醒检查');
        }
      })
      .catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, `GlobalState初始化失败: ${err.message}`);
      });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
    this.syncCardDataFromServer();
    // 仅在全局状态就绪后执行提醒检查，避免冷启动时序导致的空执行
    if (this.isGlobalStateReady) {
      hilog.info(DOMAIN, TAG, '切前台，执行提醒检查');
      NotificationUtil.checkAndSendReminders().catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, `切前台提醒检查失败: ${err.message}`);
      });
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }

  private async syncCardDataFromServer() {
    try {
      const today = this.formatDate(new Date());
      const cardData = await ApiService.getCardData(today);
      if (cardData && cardData.isLoggedIn) {
        formUpdateUtil.refreshAllCards(cardData.completedCount, cardData.totalCount, true);
      } else {
        formUpdateUtil.refreshAllCards(0, 0, false);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `同步卡片数据失败: ${(e as Error).message}`);
      const isLogin = GlobalState.isLoggedIn();
      if (isLogin) {
        formUpdateUtil.refreshAllCards(0, 0, true);
      } else {
        formUpdateUtil.refreshAllCards(0, 0, false);
      }
    }
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}