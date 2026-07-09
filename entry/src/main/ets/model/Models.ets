import { prefUtil } from "../utils/PreferenceUtil";

export class User {
  id: number = 0;
  username: string = '';
  nickname: string = '';
  createTime: string = '';
}

export enum CheckInType {
  DAILY = 1,
  ONCE = 2
}

@Observed
export class Habit {
  id: number = 0;
  userId: number = 0;
  name: string = '';
  category: string = '学习';
  priority: number = 3;
  remindTime: string = '';
  icon: string = '📌';
  checkInType: number = CheckInType.DAILY;
  isCompleted: number = 0;
  isDeleted: number = 0;
  createTime: string = '';
  isCheckedIn: boolean = false;
}

export class CheckInRecord {
  id: number = 0;
  habitId: number = 0;
  userId: number = 0;
  checkInDate: string = '';
  remark: string = '';
  imageUrl: string = '';
  isFinal: number = 0;
  checkInTime: string = '';
  fullImageUrl: string = '';
  habitName: string = '';
  habitIcon: string = '';
}

export interface WeekDataItem {
  date: string;
  count: number;
}

export interface StatisticsData {
  continuousDays: number;
  weekData: WeekDataItem[];
  badges: string[];
}

export interface CheckInTypeOption {
  label: string;
  value: number;
  icon: string;
}

export interface MonthDataItem {
  date: string;
  fullDate: string;
  count: number;
  dayOfWeek: number;
}

// 卡片数据 VO 接口
export interface CardDataVO {
  isLoggedIn: boolean;
  completedCount: number;
  totalCount: number;
  progress: number;
  habits: CardHabitItemVO[];
  showToast: boolean;
  toastMessage: string;
}

export interface CardHabitItemVO {
  id: number;
  name: string;
  icon: string;
  isCheckedIn: boolean;
  isDaily: boolean;
}

export const CATEGORY_OPTIONS: string[] = ['学习', '运动', '生活', '自定义'];
export const CATEGORY_ICONS: Record<string, string> = {
  '学习': '📚',
  '运动': '🏃',
  '生活': '🌱',
  '自定义': '🎯'
};
export const PRIORITY_COLORS: string[] = ['#FF4D4F', '#FF7A45', '#FFA940', '#FFC53D', '#73D13D'];

export const CHECK_IN_TYPE_OPTIONS: CheckInTypeOption[] = [
  { label: '每日打卡', value: 1, icon: '📅' },
  { label: '一次性打卡', value: 2, icon: '🎯' }
];

export class GlobalState {
  static token: string = '';
  static currentUser: User | null = null;
  static userId: number = 0;

  static async initFromStorage(context: Context): Promise<void> {
    await prefUtil.init(context);
    GlobalState.token = await prefUtil.getToken();
    GlobalState.userId = await prefUtil.getUserId();

    // 调试日志：打印读取到的 token
    console.info(`[GlobalState] initFromStorage - token: ${GlobalState.token ? '已读取(' + GlobalState.token.substring(0, 20) + '...)' : '空'}`);
    console.info(`[GlobalState] initFromStorage - userId: ${GlobalState.userId}`);

    // 同步回 AppStorage，供 UI 绑定使用
    AppStorage.setOrCreate('token', GlobalState.token);
    AppStorage.setOrCreate('userId', GlobalState.userId);
  }

  static setToken(token: string): void {
    GlobalState.token = token;
    AppStorage.setOrCreate('token', token);
  }

  static setUser(user: User): void {
    GlobalState.currentUser = user;
    GlobalState.userId = user.id;
    AppStorage.setOrCreate('userId', user.id);
  }

  static clear(): void {
    GlobalState.token = '';
    GlobalState.currentUser = null;
    GlobalState.userId = 0;
    AppStorage.delete('token');
    AppStorage.delete('userId');
  }

  static isLoggedIn(): boolean {
    return GlobalState.token !== '' && GlobalState.token.length > 0;
  }
}