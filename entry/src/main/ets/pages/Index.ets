import router from '@ohos.router';
import { Habit, CheckInRecord, CATEGORY_ICONS, PRIORITY_COLORS, GlobalState, CheckInType } from '../model/Models';
import { ApiService } from '../service/ApiService';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { prefUtil } from '../utils/PreferenceUtil';
import { formUpdateUtil } from '../utils/FormUpdateUtil';
import { tokenFileStore } from '../utils/TokenFileStore';
import { NotificationUtil } from '../utils/NotificationUtil';

interface FilterItem {
  label: string;
  value: number;
}

interface NavItem {
  label: string;
  icon: string;
  activeIcon: string;
  index: number;
}

@Entry
@Component
struct HabitPage {
  private habitDataSource: HabitDataSource = new HabitDataSource([]);
  @State habitList: Habit[] = [];
  @State isRefreshing: boolean = false;
  @State currentDate: string = '';

  @State allCompletedCount: number = 0;
  @State allTotalCount: number = 0;

  @State dailyCompletedCount: number = 0;
  @State dailyTotalCount: number = 0;

  @State currentBreakpoint: string = 'sm';
  @State selectedFilter: number = 0;

  @State selectedNavIndex: number = 0;

  private breakpoints: Record<string, number> = {
    'sm': 0,
    'md': 600,
    'lg': 900
  };

  private filterItems: FilterItem[] = [
    { label: '全部', value: 0 },
    { label: '每日打卡', value: 1 },
    { label: '一次性打卡', value: 2 }
  ];

  private navItems: NavItem[] = [
    { label: '首页', icon: 'sys.symbol.house', activeIcon: 'sys.symbol.house_fill', index: 0 },
    { label: '日志', icon: 'sys.symbol.doc_text', activeIcon: 'sys.symbol.doc_text_fill', index: 1 },
    { label: '统计', icon: 'sys.symbol.list_bullet', activeIcon: 'sys.symbol.list_bullet', index: 2 },
    { label: '我的', icon: 'sys.symbol.person', activeIcon: 'sys.symbol.person_fill', index: 3 }
  ];

  aboutToAppear() {
    if (!GlobalState.isLoggedIn()) {
      router.replaceUrl({ url: 'pages/Login' });
      return;
    }
    this.currentDate = this.formatDate(new Date());
    this.loadData();
    formUpdateUtil.refreshAllCards(this.allCompletedCount, this.allTotalCount, GlobalState.isLoggedIn()).catch(() => {});
  }

  onPageShow() {
    if (GlobalState.isLoggedIn()) {
      this.loadData();
      formUpdateUtil.refreshAllCards(this.allCompletedCount, this.allTotalCount, GlobalState.isLoggedIn()).catch(() => {});
    }
  }

  formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private getUserId(): number {
    return GlobalState.userId;
  }

  async loadData(): Promise<void> {
    const userId = this.getUserId();
    if (userId === 0) {
      console.error('userId 为 0，请重新登录');
      return;
    }
    try {
      const habits: Habit[] = await ApiService.getHabits(userId);
      const checkInStatus: Record<number, boolean> = await ApiService.getCheckInStatus(userId, this.currentDate);

      habits.forEach((h: Habit) => {
        h.isCheckedIn = checkInStatus[h.id] || false;
      });

      this.habitList = habits.sort((a: Habit, b: Habit) => {
        if (a.checkInType === CheckInType.ONCE && a.isCheckedIn) return 1;
        if (b.checkInType === CheckInType.ONCE && b.isCheckedIn) return -1;
        if (a.isCheckedIn !== b.isCheckedIn) {
          return a.isCheckedIn ? 1 : -1;
        }
        return b.priority - a.priority;
      });

      this.habitDataSource.setData(this.getFilteredHabits());

      this.allTotalCount = habits.length;
      this.allCompletedCount = habits.filter((h: Habit) => h.isCheckedIn).length;

      const dailyHabits = habits.filter((h: Habit) => h.checkInType === CheckInType.DAILY);
      this.dailyTotalCount = dailyHabits.length;
      this.dailyCompletedCount = dailyHabits.filter((h: Habit) => h.isCheckedIn).length;

    } catch (e) {
      console.error('加载失败:', (e as Error).message);
    }
  }

  getFilteredHabits(): Habit[] {
    if (this.selectedFilter === 0) return this.habitList;
    return this.habitList.filter((h: Habit) => h.checkInType === this.selectedFilter);
  }

  async onRefresh(): Promise<void> {
    this.isRefreshing = true;
    await this.loadData();
    this.isRefreshing = false;
  }

  async doCheckIn(habit: Habit): Promise<void> {
    if (habit.isCheckedIn) {
      return;
    }

    router.pushUrl({
      url: 'pages/CheckInDetail',
      params: {
        habit: habit,
        isDaily: habit.checkInType === CheckInType.DAILY
      }
    });
  }

  async handleDelete(id: number): Promise<void> {
    AlertDialog.show({
      title: '确认删除',
      message: '删除后无法恢复，确定要删除这个习惯吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        action: async () => {
          await ApiService.deleteHabit(id);
          await NotificationUtil.cancelNotification(id);
          this.loadData();
        }
      }
    });
  }

  async handleReset(habit: Habit): Promise<void> {
    AlertDialog.show({
      title: '确认重置',
      message: '重置后该习惯将恢复为未完成状态，确定要重置吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '重置',
        action: async () => {
          try {
            await ApiService.resetHabit(habit.id);
            habit.isCompleted = 0;
            habit.isCheckedIn = false;
            this.loadData();
          } catch (e) {
            AlertDialog.show({ message: (e as Error).message });
          }
        }
      }
    });
  }

  async handleUndo(habit: Habit): Promise<void> {
    AlertDialog.show({
      title: '确认撤销',
      message: '撤销今日打卡记录，确定要撤销吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '撤销',
        action: async () => {
          try {
            await ApiService.undoCheckIn(habit.id, this.currentDate);
            habit.isCheckedIn = false;
            this.allCompletedCount--;
            this.dailyCompletedCount--;
            if (habit.checkInType === CheckInType.DAILY && habit.remindTime && habit.remindTime.length > 0) {
              await NotificationUtil.sendCheckInReminder(habit.id, habit.name, `别忘了完成今日「${habit.name}」打卡哦~`);
            }
            this.loadData();
          } catch (e) {
            AlertDialog.show({ message: (e as Error).message });
          }
        }
      }
    });
  }

  async handleLogout(): Promise<void> {
    // 取消所有通知
    await NotificationUtil.cancelAllNotifications();

    const context: Context = getContext(this) as Context;
    tokenFileStore.init(context);
    tokenFileStore.clearAll();

    GlobalState.clear();
    formUpdateUtil.refreshAllCards(0, 0, false).catch(() => {});
    router.replaceUrl({ url: 'pages/Login' });
  }

  handleNavClick(index: number): void {
    if (index === this.selectedNavIndex) {
      return;
    }
    if (index === 0) {
      this.selectedNavIndex = 0;
      this.loadData();
    } else if (index === 1) {
      router.pushUrl({ url: 'pages/CheckInLogs' });
    } else if (index === 2) {
      router.pushUrl({ url: 'pages/Statistics' });
    } else if (index === 3) {
      this.showMyDialog();
    }
  }

  showMyDialog(): void {
    AlertDialog.show({
      title: '个人中心',
      message: `用户: ${GlobalState.currentUser?.nickname || GlobalState.currentUser?.username || '未知'}`,
      primaryButton: {
        value: '退出登录',
        action: () => this.handleLogout()
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    });
  }

  async addCardToDesktop() {
    try {
      if (!GlobalState.isLoggedIn()) {
        AlertDialog.show({ message: '请先登录' });
        return;
      }

      await prefUtil.setToken(GlobalState.token);
      await prefUtil.setUserId(GlobalState.userId);
      formUpdateUtil.refreshAllCards(this.allCompletedCount, this.allTotalCount, GlobalState.isLoggedIn()).catch(() => {});

      AlertDialog.show({
        title: '添加服务卡片',
        message: '请返回桌面，长按"习惯打卡"应用图标，选择"服务卡片"，即可在桌面一键打卡！',
        confirm: { value: '我知道了', action: () => {} }
      });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, 'Index', 'Add card failed: %{public}s', JSON.stringify(error));
      AlertDialog.show({ message: '操作失败：' + error.message });
    }
  }

  getProgressPercent(): number {
    if (this.allTotalCount === 0) return 0;
    return Math.floor((this.allCompletedCount / this.allTotalCount) * 100);
  }

  getProgressColor(): string {
    const percent = this.getProgressPercent();
    if (percent >= 100) return '#52C41A';
    if (percent >= 60) return '#1890FF';
    if (percent >= 30) return '#FAAD14';
    return '#FF4D4F';
  }

  @Builder
  ProgressCard() {
    Column() {
      Row() {
        Text('今日进度')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .layoutWeight(1)

        Text(`${this.getProgressPercent()}%`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getProgressColor())
      }
      .width('100%')
      .margin({ bottom: 12 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(12)
          .backgroundColor('#f0f0f0')
          .borderRadius(6)

        Row()
          .width(`${this.getProgressPercent()}%`)
          .height(12)
          .backgroundColor(this.getProgressColor())
          .borderRadius(6)
          .animation({
            duration: 500,
            curve: Curve.EaseInOut
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        Column() {
          Text(`${this.allCompletedCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getProgressColor())
          Text('已完成')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.allTotalCount - this.allCompletedCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#666')
          Text('待完成')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.allTotalCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
          Text('总习惯')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .width('100%')

      if (this.dailyTotalCount > 0) {
        Row() {
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(14)
            .fontColor(['#1890FF'])
            .margin({ right: 4 })
          Text(`每日打卡: ${this.dailyCompletedCount}/${this.dailyTotalCount}`)
            .fontSize(12)
            .fontColor('#1890FF')
        }
        .margin({ top: 8 })
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(12)
    .margin({ bottom: 12 })
  }

  @Builder
  FilterBar() {
    Row({ space: 12 }) {
      ForEach(this.filterItems, (item: FilterItem) => {
        Text(item.label)
          .fontSize(13)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.selectedFilter === item.value ? '#1890FF' : '#f0f0f0')
          .fontColor(this.selectedFilter === item.value ? '#fff' : '#666')
          .borderRadius(16)
          .onClick(() => {
            this.selectedFilter = item.value;
            this.habitDataSource.setData(this.getFilteredHabits());
          })
      }, (item: FilterItem) => item.label)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  SwipeActionButtons(habit: Habit) {
    Column({ space: 0 }) {
      if (habit.checkInType === CheckInType.DAILY && habit.isCheckedIn) {
        Button() {
          Text('撤销')
            .fontSize(14)
            .fontColor('#fff')
        }
        .width(60)
        .height('50%')
        .backgroundColor('#FAAD14')
        .borderRadius(0)
        .onClick(() => {
          this.handleUndo(habit);
        })
      } else if (habit.checkInType === CheckInType.ONCE && habit.isCheckedIn) {
        Button() {
          Text('重置')
            .fontSize(14)
            .fontColor('#fff')
        }
        .width(60)
        .height('50%')
        .backgroundColor('#FAAD14')
        .borderRadius(0)
        .onClick(() => {
          this.handleReset(habit);
        })
      } else {
        Button() {
          Text('')
            .fontSize(14)
        }
        .width(60)
        .height('50%')
        .backgroundColor('#f0f0f0')
        .borderRadius(0)
        .enabled(false)
      }

      Button() {
        Text('删除')
          .fontSize(14)
          .fontColor('#fff')
      }
      .width(60)
      .height('50%')
      .backgroundColor('#FF4D4F')
      .borderRadius(0)
      .onClick(() => {
        this.handleDelete(habit.id);
      })
    }
    .width(60)
    .height('100%')
    .borderRadius({ topRight: 12, bottomRight: 12 })
    .clip(true)
  }

  @Builder
  BottomNavBar() {
    Row() {
      ForEach(this.navItems, (item: NavItem) => {
        Column() {
          SymbolGlyph($r(item.index === this.selectedNavIndex ? item.activeIcon : item.icon))
            .fontSize(24)
            .fontColor([item.index === this.selectedNavIndex ? '#1890FF' : '#999'])
          Text(item.label)
            .fontSize(11)
            .fontColor(item.index === this.selectedNavIndex ? '#1890FF' : '#999')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .onClick(() => this.handleNavClick(item.index))
      }, (item: NavItem) => item.index.toString())
    }
    .width('100%')
    .height(56)
    .backgroundColor('#fff')
    .border({ width: { top: 1 }, color: '#e8e8e8' })
  }

  build() {
    Column() {
      Row() {
        Text('习惯打卡')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')

        Blank()

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus_square'))
            .fontSize(24)
            .fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor('rgba(255,255,255,0.2)')
        .margin({ right: 8 })
        .onClick(() => this.addCardToDesktop())

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(28)
            .fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor('rgba(255,255,255,0.2)')
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddHabit' });
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .backgroundColor('#1890FF')

      Text(this.currentDate)
        .fontSize(14)
        .fontColor('#666')
        .margin({ top: 12, left: 16 })
        .width('100%')

      Column() {
        this.ProgressCard()
      }
      .margin({ top: 8, left: 16, right: 16 })

      Column() {
        this.FilterBar()
      }
      .margin({ left: 16, right: 16 })

      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ space: 12 }) {
          LazyForEach(this.habitDataSource, (item: Habit, index: number) => {
            ListItem() {
              HabitCard({
                habit: item,
                onCheckIn: (habit: Habit) => this.doCheckIn(habit),
                onReset: (habit: Habit) => this.handleReset(habit)
              })
            }
            .swipeAction({
              end: this.SwipeActionButtons(item)
            })
          }, (item: Habit, index: number) => `${item.id}_${item.isCheckedIn}_${item.isCompleted}`)
        }
        .padding({ left: 16, right: 16, bottom: 20 })
        .layoutWeight(1)
        .lanes(this.getColumnCount())
      }
      .onRefreshing(() => {
        this.onRefresh();
      })
      .layoutWeight(1)

      this.BottomNavBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .onAreaChange((oldArea, newArea) => {
      const width = newArea.width as number;
      if (width >= this.breakpoints.lg) this.currentBreakpoint = 'lg';
      else if (width >= this.breakpoints.md) this.currentBreakpoint = 'md';
      else this.currentBreakpoint = 'sm';
    })
  }

  getColumnCount(): number {
    if (this.currentBreakpoint === 'lg') return 3;
    if (this.currentBreakpoint === 'md') return 2;
    return 1;
  }
}

@Component
struct HabitCard {
  @ObjectLink habit: Habit;
  onCheckIn: (habit: Habit) => void = () => {};
  onReset: (habit: Habit) => void = () => {};

  build() {
    Column() {
      Row() {
        Text(this.habit.icon)
          .fontSize(28)
          .margin({ right: 12 })
        Column() {
          Text(this.habit.name)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.habit.isCheckedIn ? '#999' : '#333')

          Row() {
            Text(this.habit.category)
              .fontSize(12)
              .fontColor('#999')
            Text(this.habit.checkInType === 2 ? ' 一次性' : ' 每日')
              .fontSize(10)
              .fontColor(this.habit.checkInType === 2 ? '#FAAD14' : '#1890FF')
              .backgroundColor(this.habit.checkInType === 2 ? '#FFF7E6' : '#E6F7FF')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4)
              .margin({ left: 8 })
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          ForEach(Array(this.habit.priority).fill(0), (_: number, idx: number) => {
            Circle()
              .width(8)
              .height(8)
              .fill(PRIORITY_COLORS[5 - this.habit.priority] || '#73D13D')
              .margin({ right: 2 })
          }, (_: number, idx: number) => idx.toString())
        }
      }
      .width('100%')

      if (this.habit.remindTime && this.habit.checkInType === 1) {
        Text(`提醒时间: ${this.habit.remindTime}`)
          .fontSize(12)
          .fontColor('#666')
          .margin({ top: 8 })
          .width('100%')
      }

      if (this.habit.checkInType === 2 && this.habit.isCheckedIn) {
        Text('✅ 已完成')
          .fontSize(12)
          .fontColor('#52C41A')
          .margin({ top: 8 })
          .width('100%')
      }

      if (this.habit.checkInType === 2 && this.habit.isCheckedIn) {
        Button() {
          Row() {
            SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
              .fontSize(18)
              .fontColor(['#FAAD14'])
            Text('重新开始')
              .fontSize(14)
              .fontColor('#FAAD14')
              .margin({ left: 4 })
          }
        }
        .width('100%')
        .height(40)
        .margin({ top: 12 })
        .backgroundColor('#FFF7E6')
        .border({ width: 1, color: '#FFD591' })
        .onClick(() => this.onReset(this.habit))
      } else {
        Button() {
          Row() {
            if (this.habit.isCheckedIn) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(20)
                .fontColor([Color.White])
              Text('已打卡')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ left: 4 })
            } else {
              Text(this.habit.checkInType === 2 ? '完成目标' : '立即打卡')
                .fontSize(14)
                .fontColor(Color.White)
            }
          }
        }
        .width('100%')
        .height(40)
        .margin({ top: 12 })
        .backgroundColor(this.habit.isCheckedIn ? '#52C41A' : '#1890FF')
        .enabled(!this.habit.isCheckedIn)
        .onClick(() => this.onCheckIn(this.habit))
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(12)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.08)', offsetX: 0, offsetY: 2 })
    .opacity(this.habit.isCheckedIn && this.habit.checkInType === 1 ? 0.7 : 1)
  }
}

class HabitDataSource implements IDataSource {
  private data: Habit[] = [];
  private dataChangeListener: DataChangeListener | null = null;

  constructor(data: Habit[]) {
    this.data = data;
  }

  setData(data: Habit[]): void {
    this.data = data;
    if (this.dataChangeListener) {
      this.dataChangeListener.onDataReloaded();
    }
  }

  totalCount(): number {
    return this.data.length;
  }

  getData(index: number): Habit {
    return this.data[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    this.dataChangeListener = listener;
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.dataChangeListener = null;
  }
}