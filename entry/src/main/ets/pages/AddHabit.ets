import router from '@ohos.router';
import { Habit, CATEGORY_OPTIONS, CATEGORY_ICONS, GlobalState, CheckInType, CHECK_IN_TYPE_OPTIONS, CheckInTypeOption } from '../model/Models';
import { ApiService } from '../service/ApiService';
import promptAction from '@ohos.promptAction';
import { NotificationUtil } from '../utils/NotificationUtil';

@Entry
@Component
struct AddHabitPage {
  @State name: string = '';
  @State category: string = '学习';
  @State priority: number = 3;
  @State remindTime: string = '';
  @State icon: string = '📚';
  @State checkInType: number = CheckInType.DAILY;
  @State isEdit: boolean = false;
  @State habitId: number = 0;

  @State showTimePicker: boolean = false;
  @State sheetTime: Date = new Date();

  // 用于获取新建习惯 ID 的辅助变量
  private oldMaxId: number = 0;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Habit>;
    if (params && params.habit) {
      const habit: Habit = params.habit;
      this.name = habit.name;
      this.category = habit.category;
      this.priority = habit.priority;
      this.remindTime = habit.remindTime;
      this.icon = habit.icon;
      this.checkInType = habit.checkInType || CheckInType.DAILY;
      this.habitId = habit.id;
      this.isEdit = true;

      // 解析时间到选择器
      if (habit.remindTime && habit.remindTime.length > 0 && this.checkInType === CheckInType.DAILY) {
        let timeStr = habit.remindTime;
        // 兼容旧格式：如果带日期，提取时分
        if (timeStr.includes(' ')) {
          timeStr = timeStr.split(' ')[1];
        }
        const GeneratedDestructArray_1 = timeStr.split(':').map(Number);
        const h = GeneratedDestructArray_1[0];
        const m = GeneratedDestructArray_1[1];
        const date = new Date();
        date.setHours(h, m, 0, 0);
        this.sheetTime = date;
      }
    }
    this.updateIcon();
    this.loadMaxId();
  }

  private async loadMaxId() {
    if (this.isEdit) return;
    try {
      const habits = await ApiService.getHabits(GlobalState.userId);
      if (habits.length > 0) {
        this.oldMaxId = Math.max(...habits.map(h => h.id));
      }
    } catch (e) {
      console.error('获取最大ID失败', e);
    }
  }

  updateIcon() {
    this.icon = CATEGORY_ICONS[this.category] || '📌';
  }

  // 仅格式化时分
  formatTime(date: Date): string {
    const hour = String(date.getHours()).padStart(2, '0');
    const minute = String(date.getMinutes()).padStart(2, '0');
    return `${hour}:${minute}`;
  }

  async saveHabit() {
    if (!this.name.trim()) {
      AlertDialog.show({ message: '请输入习惯名称' });
      return;
    }

    const habit: Habit = {
      id: this.habitId,
      userId: GlobalState.userId,
      name: this.name,
      category: this.category,
      priority: this.priority,
      remindTime: this.checkInType === CheckInType.DAILY ? this.remindTime : '',
      icon: this.icon,
      checkInType: this.checkInType,
      isCompleted: 0,
      isDeleted: 0,
      createTime: '',
      isCheckedIn: false
    };

    try {
      if (this.isEdit) {
        await ApiService.updateHabit(habit);
        promptAction.showToast({ message: '修改成功' });
        await NotificationUtil.cancelNotification(habit.id);
        if (habit.remindTime && habit.remindTime.length > 0 && habit.id > 0) {
          await NotificationUtil.sendCheckInReminder(habit.id, habit.name, `别忘了完成今日「${habit.name}」打卡哦~`);
        }
      } else {
        const res = await ApiService.addHabit(habit);
        if (res) {
          const newId = await this.findNewHabitId();
          if (newId > 0) {
            habit.id = newId;
            this.habitId = newId;
            promptAction.showToast({ message: '添加成功' });
            if (habit.remindTime && habit.remindTime.length > 0) {
              await NotificationUtil.sendCheckInReminder(habit.id, habit.name, `别忘了完成今日「${habit.name}」打卡哦~`);
            }
          } else {
            promptAction.showToast({ message: '添加成功，但未能获取习惯ID，通知可能无法正常工作' });
          }
        } else {
          AlertDialog.show({ message: '添加失败' });
          return;
        }
      }
      setTimeout(() => router.back(), 500);
    } catch (e) {
      AlertDialog.show({ message: (e as Error).message });
    }
  }

  private async findNewHabitId(): Promise<number> {
    try {
      const habits = await ApiService.getHabits(GlobalState.userId);
      const newHabit = habits.find(h => h.id > this.oldMaxId && h.name === this.name && h.checkInType === this.checkInType);
      if (newHabit) return newHabit.id;
      if (habits.length > 0) {
        return Math.max(...habits.map(h => h.id));
      }
    } catch (e) {
      console.error('查找新习惯ID失败', e);
    }
    return 0;
  }

  build() {
    Column() {
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

        Text(this.isEdit ? '编辑习惯' : '添加习惯')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(36)
      }
      .width('100%')
      .height(56)
      .padding(16)
      .backgroundColor('#fff');

      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            Text('习惯名称')
              .fontSize(14)
              .fontColor('#666')
              .width('100%');
            TextInput({ placeholder: '例如：早起、阅读30分钟', text: $$this.name })
              .height(48)
              .backgroundColor('#f5f5f5')
              .borderRadius(8);
          }

          // 打卡类型选择
          Column({ space: 8 }) {
            Text('打卡类型')
              .fontSize(14)
              .fontColor('#666')
              .width('100%');
            Row({ space: 12 }) {
              ForEach(CHECK_IN_TYPE_OPTIONS, (type: CheckInTypeOption) => {
                Column() {
                  Text(type.icon)
                    .fontSize(24)
                    .fontColor(this.checkInType === type.value ? '#fff' : '#666')
                  Text(type.label)
                    .fontSize(13)
                    .fontColor(this.checkInType === type.value ? '#fff' : '#666')
                    .margin({ top: 4 })
                }
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                .backgroundColor(this.checkInType === type.value ? '#1890FF' : '#f0f0f0')
                .borderRadius(12)
                .onClick(() => {
                  this.checkInType = type.value;
                })
              }, (type: CheckInTypeOption) => type.value.toString())
            }
            .width('100%');
          }

          Column({ space: 8 }) {
            Text('分类')
              .fontSize(14)
              .fontColor('#666')
              .width('100%');
            Row({ space: 12 }) {
              ForEach(CATEGORY_OPTIONS, (cat: string) => {
                Text(cat)
                  .fontSize(14)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(this.category === cat ? '#1890FF' : '#f0f0f0')
                  .fontColor(this.category === cat ? '#fff' : '#666')
                  .borderRadius(20)
                  .onClick(() => {
                    this.category = cat;
                    this.updateIcon();
                  });
              }, (cat: string) => cat);
            }
            .width('100%');
          }

          Column({ space: 8 }) {
            Text(`优先级: ${this.priority}`)
              .fontSize(14)
              .fontColor('#666')
              .width('100%');
            Slider({
              value: this.priority,
              min: 1,
              max: 5,
              step: 1
            })
              .width('100%')
              .onChange((value: number) => this.priority = value);
          }

          // 提醒时间（仅每日打卡显示）
          if (this.checkInType === CheckInType.DAILY) {
            Column({ space: 8 }) {
              Text('提醒时间（可选）')
                .fontSize(14)
                .fontColor('#666')
                .width('100%');
              Text(this.remindTime || '请选择提醒时间')
                .width('100%')
                .height(48)
                .padding({ left: 16, right: 16 })
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .fontColor(this.remindTime ? '#333' : '#999')
                .textAlign(TextAlign.Start)
                .onClick(() => {
                  this.showTimePicker = true;
                })
            }
          }

          Row() {
            Text('图标预览: ')
              .fontSize(14)
              .fontColor('#666');
            Text(this.icon)
              .fontSize(32);
          }
          .width('100%')
          .margin({ top: 20 });

          Button('保存')
            .width('100%')
            .height(48)
            .backgroundColor('#1890FF')
            .margin({ top: 40 })
            .onClick(() => this.saveHabit());
        }
        .width('100%')
        .padding(20);
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .bindSheet($$this.showTimePicker, this.TimePickerSheet(), {
      height: 360,
      dragBar: true,
      showClose: true,
      preferType: SheetType.CENTER,
      maskColor: 'rgba(0,0,0,0.4)'
    });
  }

  @Builder
  TimePickerSheet() {
    Column({ space: 12 }) {
      Text('选择提醒时间')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      TimePicker({ selected: this.sheetTime })
        .width('100%')
        .height(180)
        .onChange((value: TimePickerResult) => {
          const newDate = new Date();
          if (value.hour !== undefined) {
            newDate.setHours(value.hour);
          }
          if (value.minute !== undefined) {
            newDate.setMinutes(value.minute);
          }
          newDate.setSeconds(0, 0);
          this.sheetTime = newDate;
        })

      Button('确定')
        .width('90%')
        .height(44)
        .backgroundColor('#1890FF')
        .margin({ top: 8, bottom: 16 })
        .onClick(() => {
          this.remindTime = this.formatTime(this.sheetTime);
          this.showTimePicker = false;
        })
    }
    .width('100%')
    .padding({ top: 16, left: 16, right: 16, bottom: 16 })
  }
}