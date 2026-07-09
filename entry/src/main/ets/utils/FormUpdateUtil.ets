import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import hilog from '@ohos.hilog';
import { formIdStore } from './FormIdStore';

const DOMAIN = 0x0000;
const TAG = 'FormUpdateUtil';

// 统一卡片数据结构，与 EntryFormAbility 保持一致
interface CardFormData {
  loginStatus: string;
  progressText: string;
  tipText: string;
  isLoggedIn: boolean;
}

class FormUpdateUtil {
  async refreshAllCards(completed: number, total: number, isLogin: boolean): Promise<void> {
    const formIds = formIdStore.getAllFormIds();
    hilog.info(DOMAIN, TAG, `refreshAllCards, form count: ${formIds.length}`);
    if (formIds.length === 0) return;

    // 完整组装所有字段，补充 isLoggedIn 控制锁图案显隐
    const targetData: CardFormData = isLogin ? {
      loginStatus: '已登录',
      progressText: `${completed}/${total}`,
      tipText: `今日完成 ${completed} 个习惯`,
      isLoggedIn: true
    } : {
      loginStatus: '未登录',
      progressText: '0/0',
      tipText: '请打开APP登录账号',
      isLoggedIn: false
    };

    const formData = formBindingData.createFormBindingData(targetData);
    for (const formId of formIds) {
      formProvider.updateForm(formId, formData).then(() => {
        hilog.info(DOMAIN, TAG, `update form success: ${formId}`);
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, `update form failed: ${formId}, ${err.message}`);
      });
    }
  }
}

export const formUpdateUtil = new FormUpdateUtil();