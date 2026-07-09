import router from '@ohos.router';
import { GlobalState, StatisticsData, WeekDataItem, MonthDataItem } from '../model/Models';
import { ApiService } from '../service/ApiService';

@Entry
@Component
struct StatisticsPage {
  @State statistics: StatisticsData = {
    continuousDays: 0,
    weekData: [],
    badges: []
  };
  @State userId: number = GlobalState.userId;
  @State selectedTab: number = 0;

  // 月统计状态
  @State monthData: MonthDataItem[] = [];
  @State currentYearMonth: string = '';
  @State monthTotalCount: number = 0;
  @State monthActiveDays: number = 0;
  @State monthCompletionRate: string = '0.0';

  // 星期标题数据
  private weekDays: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  aboutToAppear() {
    const now = new Date();
    this.currentYearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    this.loadStatistics();
    this.loadMonthStatistics();
  }

  async loadStatistics(): Promise<void> {
    try {
      this.statistics = await ApiService.getStatistics(this.userId);
    } catch (e) {
      console.error('加载统计失败:', (e as Error).message);
    }
  }

  async loadMonthStatistics(): Promise<void> {
    try {
      const result = await ApiService.getMonthStatistics(this.currentYearMonth);
      this.monthData = result.monthData;
      this.monthTotalCount = result.totalCount;
      this.monthActiveDays = result.activeDays;
      this.monthCompletionRate = result.completionRate;
    } catch (e) {
      console.error('加载月统计失败:', (e as Error).message);
    }
  }

  switchMonth(offset: number) {
    const parts = this.currentYearMonth.split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const date = new Date(year, month - 1 + offset, 1);
    this.currentYearMonth = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    this.loadMonthStatistics();
  }

  getMaxCount(): number {
    if (!this.statistics.weekData.length) return 1;
    return Math.max(...this.statistics.weekData.map((d: WeekDataItem) => d.count)) || 1;
  }

  getHeatColor(count: number): string {
    if (count === 0) return '#f0f0f0';
    if (count === 1) return '#BAE7FF';
    if (count === 2) return '#69C0FF';
    if (count === 3) return '#1890FF';
    return '#096DD9';
  }

  @Builder
  WeekChart() {
    Column() {
      Text('近7天打卡趋势')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 20 })
      Row() {
        ForEach(this.statistics.weekData, (item: WeekDataItem, index: number) => {
          Column() {
            Column()
              .width(30)
              .height(item.count / this.getMaxCount() * 150)
              .backgroundColor(item.count > 0 ? '#1890FF' : '#e0e0e0')
              .borderRadius({ topLeft: 4, topRight: 4 })
            Text(item.date)
              .fontSize(11)
              .fontColor('#999')
              .margin({ top: 8 })
            Text(`${item.count}`)
              .fontSize(12)
              .fontColor('#666')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
        }, (item: WeekDataItem, index: number) => index.toString())
      }
      .width('100%')
      .height(250)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(12)
  }

  @Builder
  MonthChart() {
    Column() {
      // 月份切换栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor(['#1890FF'])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.switchMonth(-1))

        Text(this.currentYearMonth)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(20)
            .fontColor(['#1890FF'])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.switchMonth(1))
      }
      .width('100%')
      .margin({ bottom: 16 })

      // 统计摘要
      Row() {
        Column() {
          Text(`${this.monthTotalCount}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1890FF')
          Text('总打卡')
            .fontSize(12)
            .fontColor('#999')
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.monthActiveDays}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#52C41A')
          Text('活跃天数')
            .fontSize(12)
            .fontColor('#999')
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.monthCompletionRate}%`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FAAD14')
          Text('完成率')
            .fontSize(12)
            .fontColor('#999')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 日历热力图
      Text('打卡热力图')
        .fontSize(14)
        .fontColor('#666')
        .width('100%')
        .margin({ bottom: 12 })

      // 星期标题
      Row() {
        ForEach(this.weekDays, (day: string) => {
          Text(day)
            .fontSize(12)
            .fontColor('#999')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 日历网格
      Grid() {
        // 填充月初空白
        if (this.monthData.length > 0) {
          ForEach(Array(this.monthData[0].dayOfWeek - 1).fill(0), (_: number, idx: number) => {
            GridItem() {
              Text('')
                .width(36)
                .height(36)
            }
          }, (_: number, idx: number) => `empty_${idx}`)
        }

        ForEach(this.monthData, (item: MonthDataItem) => {
          GridItem() {
            Column() {
              Text(item.date.split('-')[1])
                .fontSize(12)
                .fontColor(item.count > 0 ? '#fff' : '#666')
            }
            .width(36)
            .height(36)
            .backgroundColor(this.getHeatColor(item.count))
            .borderRadius(4)
            .justifyContent(FlexAlign.Center)
          }
        }, (item: MonthDataItem) => item.fullDate)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .columnsGap(4)
      .rowsGap(4)
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(12)
  }

  @Builder
  AchievementView() {
    Column() {
      Text('连续打卡')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Row() {
        Text(`${this.statistics.continuousDays}`)
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1890FF')
        Text('天')
          .fontSize(16)
          .fontColor('#666')
          .margin({ left: 4, bottom: 8 })
      }
      .margin({ top: 12, bottom: 20 })
      Text('成就徽章')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ top: 16 })
      if (this.statistics.badges.length === 0) {
        Text('还没有获得徽章，快去打卡吧！')
          .fontSize(14)
          .fontColor('#999')
          .margin({ top: 20 })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.statistics.badges, (badge: string, index: number) => {
            Column() {
              Text('🏅')
                .fontSize(32)
              Text(badge)
                .fontSize(12)
                .fontColor('#666')
                .margin({ top: 4 })
            }
            .padding(12)
            .backgroundColor('#FFF7E6')
            .borderRadius(12)
            .margin(6)
          }, (badge: string, index: number) => index.toString())
        }
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fff')
    .borderRadius(12)
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(24)
            .fontColor(['#333'])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text('数据统计')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(36)
      }
      .width('100%')
      .height(56)
      .padding(16)
      .backgroundColor('#fff')

      // Tab切换
      Row() {
        Column() {
          Text('周统计')
            .fontSize(14)
            .fontWeight(this.selectedTab === 0 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedTab === 0 ? '#1890FF' : '#666')
          if (this.selectedTab === 0) {
            Divider()
              .width(20)
              .height(2)
              .color('#1890FF')
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .onClick(() => this.selectedTab = 0)

        Column() {
          Text('月统计')
            .fontSize(14)
            .fontWeight(this.selectedTab === 1 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedTab === 1 ? '#1890FF' : '#666')
          if (this.selectedTab === 1) {
            Divider()
              .width(20)
              .height(2)
              .color('#1890FF')
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .onClick(() => this.selectedTab = 1)

        Column() {
          Text('成就')
            .fontSize(14)
            .fontWeight(this.selectedTab === 2 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedTab === 2 ? '#1890FF' : '#666')
          if (this.selectedTab === 2) {
            Divider()
              .width(20)
              .height(2)
              .color('#1890FF')
              .margin({ top: 4 })
          }
        }
        .layoutWeight(1)
        .onClick(() => this.selectedTab = 2)
      }
      .width('100%')
      .height(44)
      .backgroundColor('#fff')

      Scroll() {
        Column({ space: 16 }) {
          if (this.selectedTab === 0) {
            this.WeekChart()
          } else if (this.selectedTab === 1) {
            this.MonthChart()
          } else {
            this.AchievementView()
          }
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}