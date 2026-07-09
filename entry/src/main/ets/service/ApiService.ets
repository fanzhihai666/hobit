import { request } from '../http/Request';
import { Habit, CheckInRecord, StatisticsData, User, MonthDataItem } from '../model/Models';

interface LoginResult {
  token: string;
  user: User;
}

interface LoginParams {
  username: string;
  password: string;
}

interface RegisterParams {
  username: string;
  password: string;
  nickname: string;
}

interface UserIdParams {
  userId: number;
}

interface UserIdDateParams {
  userId: number;
  date: string;
}

interface YearMonthParams {
  yearMonth: string;
}

interface MonthStatisticsResult {
  monthData: MonthDataItem[];
  totalCount: number;
  activeDays: number;
  completionRate: string;
}

export interface CheckInLogsParams {
  startDate?: string;
  endDate?: string;
  habitId?: number;
}

interface DateParams {
  date: string;
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

// 快速打卡请求体
interface QuickCheckInParams {
  habitId: number;
  userId: number;
  checkInDate: string;
  checkInTime: string;
  remark: string;
  imageUrl: string;
  isFinal: number;
}

// 快速打卡简化请求体
interface QuickCheckInRequest {
  habitId: number;
  checkInDate: string;
}

export class ApiService {
  static login(username: string, password: string): Promise<LoginResult> {
    const params: LoginParams = { username, password };
    return request.post('/api/user/login', params);
  }

  static register(username: string, password: string, nickname: string): Promise<boolean> {
    const params: RegisterParams = { username, password, nickname };
    return request.post('/api/user/register', params);
  }

  static getHabits(userId: number): Promise<Habit[]> {
    const params: UserIdParams = { userId };
    return request.get('/api/habit/list', params);
  }

  static addHabit(habit: Habit): Promise<boolean> {
    return request.post('/api/habit/add', habit);
  }

  static updateHabit(habit: Habit): Promise<boolean> {
    return request.post('/api/habit/update', habit);
  }

  static deleteHabit(id: number): Promise<boolean> {
    return request.delete(`/api/habit/${id}`);
  }

  static checkIn(record: CheckInRecord): Promise<boolean> {
    return request.post('/api/checkin/add', record);
  }

  static getTodayRecords(userId: number, date: string): Promise<CheckInRecord[]> {
    const params: UserIdDateParams = { userId, date };
    return request.get('/api/checkin/today', params);
  }

  static getCheckInStatus(userId: number, date: string): Promise<Record<number, boolean>> {
    const params: UserIdDateParams = { userId, date };
    return request.get('/api/checkin/status', params);
  }

  static getStatistics(userId: number): Promise<StatisticsData> {
    const params: UserIdParams = { userId };
    return request.get('/api/checkin/statistics', params);
  }

  static getMonthStatistics(yearMonth: string): Promise<MonthStatisticsResult> {
    const params: YearMonthParams = { yearMonth };
    return request.get('/api/checkin/statistics/month', params);
  }

  static resetHabit(habitId: number): Promise<boolean> {
    const emptyParams: Record<string, ESObject> = {};
    return request.post(`/api/checkin/reset/${habitId}`, emptyParams);
  }

  static undoCheckIn(habitId: number, date: string): Promise<boolean> {
    const params: DateParams = { date };
    return request.post(`/api/checkin/undo/${habitId}`, params);
  }

  static getCheckInLogs(params: CheckInLogsParams): Promise<CheckInRecord[]> {
    return request.get('/api/checkin/logs', params);
  }

  static getCheckInDetail(id: number): Promise<CheckInRecord> {
    return request.get(`/api/checkin/detail/${id}`, {} as Record<string, ESObject>);
  }

  static uploadImage(fileUri: string, context?: Context): Promise<string> {
    return request.uploadFile(fileUri, context);
  }


  static quickCheckIn(habitId: number, checkInDate: string): Promise<boolean> {
    const params: QuickCheckInRequest = { habitId, checkInDate };
    return request.post('/api/checkin/quick', params);
  }

  static getCardData(date: string): Promise<CardDataVO> {
    const params: DateParams = { date };
    return request.get('/api/checkin/card-data', params);
  }

  // ==================== 工具方法 ====================

  private static formatDateTime(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hour = String(date.getHours()).padStart(2, '0');
    const minute = String(date.getMinutes()).padStart(2, '0');
    const second = String(date.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
  }
}