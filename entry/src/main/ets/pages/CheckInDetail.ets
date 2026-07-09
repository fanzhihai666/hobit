import router from '@ohos.router';
import { CheckInRecord, GlobalState, Habit, CheckInType } from '../model/Models';
import { ApiService } from '../service/ApiService';
import picker from '@ohos.file.picker';
import { NotificationUtil } from '../utils/NotificationUtil';
import hilog from '@ohos.hilog';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;
const TAG = 'CheckInDetail';

@Entry
@Component
struct CheckInDetailPage {
  @State habit: Habit = new Habit();
  @State remark: string = '';
  @State imageUri: string = '';
  @State imageUrl: string = '';
  @State currentDate: string = '';
  @State isUploading: boolean = false;
  @State isDaily: boolean = false;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params.habit) {
      this.habit = params.habit as Habit;
      this.isDaily = this.habit.checkInType === CheckInType.DAILY;
    } else if (params && params.habitId) {
      const habitId = params.habitId as number;
      this.loadHabitById(habitId);
    } else {
      router.back();
      return;
    }
    this.currentDate = this.formatDate(new Date());
  }

  private async loadHabitById(habitId: number) {
    try {
      const habits = await ApiService.getHabits(GlobalState.userId);
      const found = habits.find(h => h.id === habitId);
      if (found) {
        this.habit = found;
        this.isDaily = found.checkInType === CheckInType.DAILY;
      } else {
        AlertDialog.show({ message: '习惯不存在或已被删除' });
        router.back();
      }
    } catch (e) {
      console.error('加载习惯失败', e);
      AlertDialog.show({ message: '加载失败，请重试' });
      router.back();
    }
  }

  formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  async selectImage() {
    const photoPicker = new picker.PhotoViewPicker();
    const result = await photoPicker.select({
      MIMEType: picker.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris && result.photoUris.length > 0) {
      this.imageUri = result.photoUris[0];
    }
  }

  async submitCheckIn() {
    this.isUploading = true;
    try {
      if (this.imageUri) {
        const context: Context = getContext(this) as Context;
        this.imageUrl = await ApiService.uploadImage(this.imageUri, context);
      }

      const record: CheckInRecord = {
        id: 0,
        habitId: this.habit.id,
        userId: GlobalState.userId,
        checkInDate: this.currentDate,
        remark: this.remark,
        imageUrl: this.imageUrl,
        isFinal: this.isDaily ? 0 : 1,
        checkInTime: '',
        fullImageUrl: '',
        habitName: this.habit.name,
        habitIcon: this.habit.icon
      };

      await ApiService.checkIn(record);

      // 打卡成功后取消对应通知
      if (this.isDaily) {
        NotificationUtil.onCheckInSuccess(this.habit.id)
          .then(() => {
            hilog.info(DOMAIN, TAG, `打卡成功，已取消习惯${this.habit.id}的通知`);
          })
          .catch((err: BusinessError) => {
            hilog.error(DOMAIN, TAG, `取消通知失败: ${JSON.stringify(err)}`);
          });
      }

      const successMsg = this.isDaily ? '打卡成功！' : '目标完成！';
      AlertDialog.show({
        title: successMsg,
        message: this.remark ? `备注：${this.remark}` : '继续保持，好习惯正在养成中~',
        confirm: {
          value: '确定',
          action: () => router.back()
        }
      });
    } catch (e) {
      AlertDialog.show({ message: (e as Error).message });
    } finally {
      this.isUploading = false;
    }
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

        Text(this.isDaily ? '每日打卡' : '完成目标')
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
          Row({ space: 12 }) {
            Text(this.habit.icon)
              .fontSize(36)
              .margin({ right: 12 });

            Column() {
              Text(this.habit.name)
                .fontSize(20)
                .fontWeight(FontWeight.Bold);
              Text(`${this.currentDate} ${this.isDaily ? '每日打卡' : '一次性打卡'}`)
                .fontSize(14)
                .fontColor('#999')
                .margin({ top: 4 });
            }
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(12);

          Column({ space: 8 }) {
            Text('打卡备注')
              .fontSize(14)
              .fontColor('#666')
              .width('100%');
            TextArea({ placeholder: '记录一下今天的心得...', text: $$this.remark })
              .height(120)
              .backgroundColor('#f5f5f5')
              .borderRadius(8);
          }

          Column({ space: 8 }) {
            Text('上传图片（可选）')
              .fontSize(14)
              .fontColor('#666')
              .width('100%');

            if (this.imageUri) {
              Image(this.imageUri)
                .width('100%')
                .height(200)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
                .onClick(() => this.selectImage());
            } else {
              Column() {
                SymbolGlyph($r('sys.symbol.plus'))
                  .fontSize(40)
                  .fontColor(['#ccc'])
                Text('点击添加图片')
                  .fontSize(12)
                  .fontColor('#999');
              }
              .width('100%')
              .height(150)
              .backgroundColor('#f5f5f5')
              .borderRadius(8)
              .border({ width: 1, color: '#e0e0e0', style: BorderStyle.Dashed })
              .onClick(() => this.selectImage());
            }
          }

          Button(this.isUploading ? '提交中...' : (this.isDaily ? '确认打卡' : '确认完成'))
            .width('100%')
            .height(48)
            .backgroundColor('#1890FF')
            .enabled(!this.isUploading)
            .margin({ top: 30 })
            .onClick(() => this.submitCheckIn());
        }
        .width('100%')
        .padding(20);
      }
      .layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5');
  }
}