import router from '@ohos.router';
import { CheckInRecord } from '../model/Models';

@Entry
@Component
struct CheckInLogDetailPage {
  @State record: CheckInRecord = new CheckInRecord();
  @State imageLoaded: boolean = false;
  @State imageLoadError: boolean = false;
  @State isPreviewVisible: boolean = false;  // 大图预览开关
  @State previewScale: number = 1;             // 缩放比例
  @State previewOffsetX: number = 0;         // 拖拽偏移
  @State previewOffsetY: number = 0;

  aboutToAppear() {
    const params = router.getParams() as Record<string, CheckInRecord>;
    if (params && params.record) {
      this.record = params.record as CheckInRecord;
    }
  }

  // 修复：增强版时间格式化
  formatDateTime(dateTimeStr: string): string {
    if (!dateTimeStr || dateTimeStr.length === 0) return '未记录';
    let normalized = dateTimeStr.replace('T', ' ');
    normalized = normalized.replace(/(\d{4}-\d{2}-\d{2})(\d{2}:\d{2}:\d{2})/, '$1 $2');
    const date = new Date(normalized.replace(/-/g, '/'));
    if (isNaN(date.getTime())) {
      return normalized;
    }
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hour = String(date.getHours()).padStart(2, '0');
    const minute = String(date.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  formatCheckInDate(dateStr: string): string {
    if (!dateStr) return '';
    const date = new Date(dateStr.replace(/-/g, '/'));
    const weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${dateStr} ${weekDays[date.getDay()]}`;
  }

  // 打开大图预览
  openPreview() {
    this.isPreviewVisible = true;
    this.previewScale = 1;
    this.previewOffsetX = 0;
    this.previewOffsetY = 0;
  }

  // 关闭大图预览
  closePreview() {
    this.isPreviewVisible = false;
    this.previewScale = 1;
    this.previewOffsetX = 0;
    this.previewOffsetY = 0;
  }

  build() {
    Stack() {
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

          Text('打卡记录详情')
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

        Scroll() {
          Column({ space: 16 }) {
            // 习惯信息卡片
            Column({ space: 12 }) {
              Row({ space: 12 }) {
                Text(this.record.habitIcon || '📌')
                  .fontSize(48)

                Column({ space: 4 }) {
                  Text(this.record.habitName || '未知习惯')
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333');

                  Text(this.record.isFinal === 1 ? '一次性打卡' : '每日打卡')
                    .fontSize(12)
                    .fontColor(this.record.isFinal === 1 ? '#FAAD14' : '#1890FF')
                    .backgroundColor(this.record.isFinal === 1 ? '#FFF7E6' : '#E6F7FF')
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(4);
                }
                .alignItems(HorizontalAlign.Start);
              }
              .width('100%')

              Divider()
                .width('100%')
                .color('#f0f0f0')

              Row() {
                Text('打卡日期')
                  .fontSize(14)
                  .fontColor('#999')
                  .layoutWeight(1)
                Text(this.formatCheckInDate(this.record.checkInDate))
                  .fontSize(14)
                  .fontColor('#333')
              }
              .width('100%')

              Row() {
                Text('打卡时间')
                  .fontSize(14)
                  .fontColor('#999')
                  .layoutWeight(1)
                Text(this.formatDateTime(this.record.checkInTime))
                  .fontSize(14)
                  .fontColor('#333')
              }
              .width('100%')

              Row() {
                Text('记录编号')
                  .fontSize(14)
                  .fontColor('#999')
                  .layoutWeight(1)
                Text(`#${this.record.id}`)
                  .fontSize(14)
                  .fontColor('#999')
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#fff')
            .borderRadius(12)

            // 备注
            if (this.record.remark && this.record.remark.length > 0) {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.doc_text'))
                    .fontSize(16)
                    .fontColor(['#1890FF'])
                  Text('打卡备注')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333')
                }
                .width('100%')

                Text(this.record.remark)
                  .fontSize(14)
                  .fontColor('#666')
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#fff')
              .borderRadius(12)
            }

            // 图片（关键修复区域）
            if (this.record.fullImageUrl && this.record.fullImageUrl.length > 0) {
              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  SymbolGlyph($r('sys.symbol.ohos_photo'))
                    .fontSize(16)
                    .fontColor(['#1890FF'])
                  Text('打卡图片')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333')
                }
                .width('100%')

                if (this.imageLoadError) {
                  Column() {
                    SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
                      .fontSize(40)
                      .fontColor(['#FAAD14'])
                    Text('图片加载失败')
                      .fontSize(14)
                      .fontColor('#999')
                      .margin({ top: 8 })
                  }
                  .width('100%')
                  .height(200)
                  .backgroundColor('#f5f5f5')
                  .borderRadius(8)
                  .justifyContent(FlexAlign.Center)
                } else {
                  // 修复1: 使用 Contain 完整展示图片，保持原始比例
                  // 修复2: 添加点击事件查看大图
                  Stack({ alignContent: Alignment.BottomEnd }) {
                    Image(this.record.fullImageUrl)
                      .width('100%')
                      .height(280)  // 固定高度，Contain 会在内部完整显示
                      .objectFit(ImageFit.Contain)  // ✅ 完整展示，不裁剪
                      .borderRadius(8)
                      .backgroundColor('#f0f0f0')  // 图片外的背景色（黑边区域）
                      .onComplete(() => {
                        this.imageLoaded = true;
                      })
                      .onError(() => {
                        this.imageLoadError = true;
                      })

                    // 点击提示角标
                    Row() {
                      SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
                        .fontSize(12)
                        .fontColor(['#fff'])
                      Text('查看大图')
                        .fontSize(11)
                        .fontColor('#fff')
                    }
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('rgba(0,0,0,0.5)')
                    .borderRadius({ topLeft: 8, bottomRight: 8 })
                    .margin(0)
                  }
                  .width('100%')
                  .onClick(() => this.openPreview())  // ✅ 点击打开大图
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#fff')
              .borderRadius(12)
            }

            // 无备注无图片提示
            if ((!this.record.remark || this.record.remark.length === 0) &&
              (!this.record.fullImageUrl || this.record.fullImageUrl.length === 0)) {
              Column({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.doc_text'))
                  .fontSize(40)
                  .fontColor(['#ccc'])
                Text('该记录未填写备注和上传图片')
                  .fontSize(14)
                  .fontColor('#999')
              }
              .width('100%')
              .padding(32)
              .backgroundColor('#fff')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
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

      // 全屏大图预览层
      if (this.isPreviewVisible) {
        Column() {
          // 黑色背景
          Stack({ alignContent: Alignment.Center }) {
            // 可缩放、可拖拽的图片
            Image(this.record.fullImageUrl)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({ x: this.previewScale, y: this.previewScale })
              .offset({ x: this.previewOffsetX, y: this.previewOffsetY })
              .gesture(
                GestureGroup(GestureMode.Sequence,
                  // 双击缩放
                  TapGesture({ count: 2 })
                    .onAction(() => {
                      if (this.previewScale > 1) {
                        this.previewScale = 1;
                        this.previewOffsetX = 0;
                        this.previewOffsetY = 0;
                      } else {
                        this.previewScale = 2.5;
                      }
                    }),
                  // 捏合缩放
                  PinchGesture()
                    .onActionUpdate((event: GestureEvent) => {
                      this.previewScale = Math.max(1, Math.min(event.scale * this.previewScale, 5));
                    })
                    .onActionEnd(() => {
                      if (this.previewScale < 1) {
                        this.previewScale = 1;
                        this.previewOffsetX = 0;
                        this.previewOffsetY = 0;
                      }
                    }),
                  // 拖拽
                  PanGesture()
                    .onActionUpdate((event: GestureEvent) => {
                      if (this.previewScale > 1) {
                        this.previewOffsetX += event.offsetX;
                        this.previewOffsetY += event.offsetY;
                      }
                    })
                    .onActionEnd(() => {
                      // 可选：边界回弹逻辑
                    })
                )
              )

            // 关闭按钮
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.xmark'))
                .fontSize(20)
                .fontColor(['#fff'])
            }
            .width(40)
            .height(40)
            .backgroundColor('rgba(0,0,0,0.5)')
            .position({ x: 16, y: 56 })
            .onClick(() => this.closePreview())

            // 缩放提示
            if (this.previewScale === 1) {
              Text('双击或捏合缩放')
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.6)')
                .position({ y: -40 })
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#000')
        }
        .width('100%')
        .height('100%')
        // 点击背景关闭
        .onClick(() => this.closePreview())
      }
    }
    .width('100%')
    .height('100%')
  }
}