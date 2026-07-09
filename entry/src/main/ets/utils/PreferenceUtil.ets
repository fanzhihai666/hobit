import preferences from '@ohos.data.preferences';

const PREF_NAME = 'habit_prefs';
const KEY_TOKEN = 'user_token';
const KEY_USER_ID = 'user_id';
const KEY_FORM_IDS = 'form_id_list';

class PreferenceUtil {
  private pref: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    const appContext = context.getApplicationContext();
    this.pref = await preferences.getPreferences(appContext, PREF_NAME);
  }

  async setToken(token: string): Promise<void> {
    if (!this.pref) {
      console.error('[prefUtil] setToken 失败: pref 未初始化');
      return;
    }
    console.info(`[prefUtil] setToken - 保存token: ${token ? token.substring(0, 20) + '...' : '空'}`);
    await this.pref.put(KEY_TOKEN, token);
    await this.pref.flush();
    console.info('[prefUtil] setToken - token保存成功');
  }

  async setUserId(userId: number): Promise<void> {
    if (!this.pref) return;
    await this.pref.put(KEY_USER_ID, userId);
    await this.pref.flush();
  }

  async getToken(): Promise<string> {
    if (!this.pref) {
      console.error('[prefUtil] getToken 失败: pref 未初始化');
      return '';
    }
    const token = await this.pref.get(KEY_TOKEN, '') as string;
    console.info(`[prefUtil] getToken - 读取token: ${token ? token.substring(0, 20) + '...' : '空'}`);
    return token;
  }

  async getUserId(): Promise<number> {
    if (!this.pref) return 0;
    return await this.pref.get(KEY_USER_ID, 0) as number;
  }

  // 新增：添加卡片ID
  async addFormId(formId: string): Promise<void> {
    if (!this.pref) return;
    const idsStr = await this.pref.get(KEY_FORM_IDS, '') as string;
    const idList = idsStr ? idsStr.split(',') : [];
    if (!idList.includes(formId)) {
      idList.push(formId);
      await this.pref.put(KEY_FORM_IDS, idList.join(','));
      await this.pref.flush();
    }
  }

  // 新增：移除卡片ID
  async removeFormId(formId: string): Promise<void> {
    if (!this.pref) return;
    const idsStr = await this.pref.get(KEY_FORM_IDS, '') as string;
    const idList = idsStr ? idsStr.split(',').filter(id => id !== formId) : [];
    await this.pref.put(KEY_FORM_IDS, idList.join(','));
    await this.pref.flush();
  }

  // 新增：获取所有卡片ID
  async getAllFormIds(): Promise<string[]> {
    if (!this.pref) return [];
    const idsStr = await this.pref.get(KEY_FORM_IDS, '') as string;
    return idsStr ? idsStr.split(',') : [];
  }

  async clear(): Promise<void> {
    if (!this.pref) return;
    await this.pref.clear();
    await this.pref.flush();
  }
}

export const prefUtil = new PreferenceUtil();