import router from '@ohos.router';
import { CheckInRecord, GlobalState, Habit } from '../model/Models';
import { ApiService, CheckInLogsParams } from '../service/ApiService';

interface LogGroup {
  date: string;
  records: CheckInRecord[];
}

@Entry
@Component
struct CheckInLogsPage {
  @State logList: CheckInRecord[] = [];
  @State groupedLogs: LogGroup[] = [];
  @State isRefreshing: boolean = false;
  @State selectedHabitId: number = 0;
  @State habitList: Habit[] = [];

  // 日期筛选
  @State selectedDate: string = '';
  @State showDatePicker: boolean = false;
  @State pickerDate: Date = new Date();

  // 是否只看某一天
  @State filterByDate: boolean = false;

  aboutToAppear() {
    // 默认选中今天
    this.selectedDate = this.formatDate(new Date());
    this.pickerDate = new Date();
    this.loadHabits();
    this.loadLogs();
  }

  formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  async loadHabits() {
    try {
      this.habitList = await ApiService.getHabits(GlobalState.userId);
    } catch (e) {
      console.error('加载习惯失败:', (e as Error).message);
    }
  }

  async loadLogs() {
    try {
      const params: CheckInLogsParams = {} as CheckInLogsParams;
      if (this.selectedHabitId > 0) {
        params.habitId = this.selectedHabitId;
      }
      // 如果按日期筛选，只查询当天
      if (this.filterByDate && this.selectedDate) {
        params.startDate = this.selectedDate;
        params.endDate = this.selectedDate;
      }
      this.logList = await ApiService.getCheckInLogs(params);
      this.groupLogs();
    } catch (e) {
      console.error('加载日志失败:', (e as Error).message);
    }
  }

  groupLogs() {
    const groupMap: Map<string, CheckInRecord[]> = new Map();

    for (const record of this.logList) {
      const date = record.checkInDate;
      if (!groupMap.has(date)) {
        groupMap.set(date, []);
      }
      groupMap.get(date)?.push(record);
    }

    this.groupedLogs = Array.from(groupMap.entries())
      .map((entry: [string, CheckInRecord[]]) => ({ date: entry[0], records: entry[1] } as LogGroup))
      .sort((a, b) => b.date.localeCompare(a.date));
  }

  async onRefresh() {
    this.isRefreshing = true;
    await this.loadLogs();
    this.isRefreshing = false;
  }

  formatDisplayDate(dateStr: string): string {
    const date = new Date(dateStr.replace(/-/g, '/'));
    const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${dateStr} ${weekDays[date.getDay()]}`;
  }

  // 修复：格式化打卡时间，处理多种格式
  formatCheckInTime(timeStr: string): string {
    if (!timeStr || timeStr.length === 0) return '';
    // 处理 ISO 格式: 2026-07-03T11:53:52 -> 2026-07-03 11:53:52
    // 处理连在一起: 2026-07-0311:53:52 -> 2026-07-03 11:53:52
    let normalized = timeStr.replace('T', ' ');
    normalized = normalized.replace(/(\d{4}-\d{2}-\d{2})(\d{2}:\d{2}:\d{2})/, '$1 $2');
    return normalized;
  }

  goToDetail(record: CheckInRecord) {
    router.pushUrl({
      url: 'pages/CheckInLogDetail',
      params: { record: record }
    });
  }

  // 确认日期选择
  confirmDate() {
    this.selectedDate = this.formatDate(this.pickerDate);
    this.showDatePicker = false;
    this.loadLogs();
  }

  // 切换日期筛选开关
  toggleDateFilter() {
    this.filterByDate = !this.filterByDate;
    if (this.filterByDate) {
      this.selectedDate = this.formatDate(new Date());
    }
    this.loadLogs();
  }

  @Builder
  FilterBar() {
    Column({ space: 8 }) {
      // 习惯筛选
      Row({ space: 8 }) {
        Text('全部习惯')
          .fontSize(13)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.selectedHabitId === 0 ? '#1890FF' : '#f0f0f0')
          .fontColor(this.selectedHabitId === 0 ? '#fff' : '#666')
          .borderRadius(16)
          .onClick(() => {
            this.selectedHabitId = 0;
            this.loadLogs();
          })

        ForEach(this.habitList, (habit: Habit) => {
          Text(habit.name)
            .fontSize(13)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.selectedHabitId === habit.id ? '#1890FF' : '#f0f0f0')
            .fontColor(this.selectedHabitId === habit.id ? '#fff' : '#666')
            .borderRadius(16)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              this.selectedHabitId = habit.id;
              this.loadLogs();
            })
        }, (habit: Habit) => habit.id.toString())
      }
      .width('100%')

      // 日期筛选栏
      Row() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.calendar'))
            .fontSize(16)
            .fontColor([this.filterByDate ? '#1890FF' : '#999'])
          Text(this.filterByDate ? this.selectedDate : '全部日期')
            .fontSize(13)
            .fontColor(this.filterByDate ? '#1890FF' : '#999')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(this.filterByDate ? '#E6F7FF' : '#f0f0f0')
        .borderRadius(16)
        .onClick(() => {
          this.showDatePicker = true;
        })

        Blank()

        // 日期筛选开关
        Toggle({ type: ToggleType.Switch, isOn: $$this.filterByDate })
          .width(40)
          .height(24)
          .selectedColor('#1890FF')
          .onChange((isOn: boolean) => {
            this.filterByDate = isOn;
            if (isOn) {
              this.selectedDate = this.formatDate(new Date());
            }
            this.loadLogs();
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  LogRecordItem(record: CheckInRecord) {
    Row({ space: 12 }) {
      // 习惯图标
      Text(record.habitIcon || '📌')
        .fontSize(24)

      Column({ space: 4 }) {
        Row() {
          Text(record.habitName || '未知习惯')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .layoutWeight(1)

          // 图片标记
          if (record.imageUrl && record.imageUrl.length > 0) {
            SymbolGlyph($r('sys.symbol.camera'))
              .fontSize(16)
              .fontColor(['#1890FF'])
          }
        }
        .width('100%')

        // 备注预览
        if (record.remark && record.remark.length > 0) {
          Text(record.remark)
            .fontSize(13)
            .fontColor('#666')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        // 打卡时间 - 使用修复后的格式化方法
        Text(this.formatCheckInTime(record.checkInTime))
          .fontSize(11)
          .fontColor('#999')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 箭头
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor(['#ccc'])
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fff')
    .borderRadius(8)
    .onClick(() => this.goToDetail(record))
  }

  @Builder
  DatePickerSheet() {
    Column({ space: 16 }) {
      Text('选择日期')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)

      DatePicker({
        start: new Date('2020-01-01'),
        end: new Date('2030-12-31'),
        selected: $$this.pickerDate
      })
        .width('100%')
        .height(200)

      Row({ space: 12 }) {
        Button('取消')
          .width('45%')
          .height(44)
          .backgroundColor('#f0f0f0')
          .fontColor('#666')
          .onClick(() => {
            this.showDatePicker = false;
          })

        Button('确定')
          .width('45%')
          .height(44)
          .backgroundColor('#1890FF')
          .onClick(() => this.confirmDate())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(16)
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

        Text('打卡日志')
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

      // 筛选栏
      Scroll() {
        this.FilterBar()
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })

      // 日志列表
      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ space: 16 }) {
          ForEach(this.groupedLogs, (group: LogGroup) => {
            ListItemGroup({ header: this.GroupHeader(group.date) }) {
              ForEach(group.records, (record: CheckInRecord) => {
                ListItem() {
                  this.LogRecordItem(record)
                }
              }, (record: CheckInRecord) => record.id.toString())
            }
          }, (group: LogGroup) => group.date)
        }
        .padding({ left: 16, right: 16, bottom: 20 })
        .layoutWeight(1)
      }
      .onRefreshing(() => {
        this.onRefresh();
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .bindSheet($$this.showDatePicker, this.DatePickerSheet(), {
      height: 360,
      dragBar: true,
      showClose: true,
      preferType: SheetType.CENTER,
      maskColor: 'rgba(0,0,0,0.4)'
    })
  }

  @Builder
  GroupHeader(date: string) {
    Row() {
      Text(this.formatDisplayDate(date))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
      Blank()
      Text(`${this.getRecordCount(date)} 次打卡`)
        .fontSize(12)
        .fontColor('#999')
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  getRecordCount(date: string): number {
    const group = this.groupedLogs.find(g => g.date === date);
    return group ? group.records.length : 0;
  }
}