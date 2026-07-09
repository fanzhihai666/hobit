@Entry
@Component
struct CardPage {
  @LocalStorageProp('loginStatus') loginStatus: string = '未登录';
  @LocalStorageProp('progressText') progressText: string = '0/0';
  @LocalStorageProp('tipText') tipText: string = '请打开APP登录账号';
  @LocalStorageProp('isLoggedIn') isLoggedIn: boolean = false;

  build() {
    Column() {
      // 顶部状态栏
      Row() {
        Column() {
          Text('今日打卡')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333');
          Text(this.progressText)
            .fontSize(11)
            .fontColor('#666666')
            .margin({ top: 2 });
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1);

        Text(this.loginStatus)
          .fontSize(10)
          .fontColor('#1890FF')
          .fontWeight(FontWeight.Bold)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#E6F7FF')
          .borderRadius(4);
      }
      .width('100%')
      .margin({ bottom: 8 });

      // 中间内容区 - 点击跳转到APP
      Column() {
        if (!this.isLoggedIn) {
          Text('🔒')
            .fontSize(28)
            .margin({ bottom: 4 });
          Text('登录后查看进度')
            .fontSize(12)
            .fontColor('#999999');
        } else {
          Text(this.tipText)
            .fontSize(13)
            .fontColor('#333333')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        // 点击主体跳转到APP首页
        postCardAction(this, {
          action: 'router',
          abilityName: 'EntryAbility',
          params: {
            uri: 'pages/Index'
          }
        });
      });

      // 底部操作按钮
      Button(this.isLoggedIn ? '一键打卡' : '去登录')
        .width('100%')
        .height(32)
        .backgroundColor(this.isLoggedIn ? '#1890FF' : '#FAAD14')
        .fontSize(12)
        .fontColor('#fff')
        .borderRadius(6)
        .onClick(() => {
          if (!this.isLoggedIn) {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: {
                uri: 'pages/Login'
              }
            });
          } else {
            // 发送打卡事件，触发 FormExtensionAbility 的 onFormEvent
            postCardAction(this, {
              action: 'message',
              params: {
                event: 'quickCheckIn'
              }
            });
          }
        });
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#ffffff')
    .borderRadius(12);
  }
}