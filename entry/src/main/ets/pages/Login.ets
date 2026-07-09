import router from '@ohos.router';
import { ApiService } from '../service/ApiService';
import { GlobalState, User } from '../model/Models';
import { prefUtil } from '../utils/PreferenceUtil';
import { formUpdateUtil } from '../utils/FormUpdateUtil';
import { tokenFileStore } from '../utils/TokenFileStore';
import { NotificationUtil } from '../utils/NotificationUtil';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State isLoginMode: boolean = true;
  @State nickname: string = '';
  @State isLoading: boolean = false;

  async handleLogin() {
    if (!this.username.trim() || !this.password.trim()) {
      AlertDialog.show({ message: '请输入用户名和密码' });
      return;
    }

    this.isLoading = true;
    try {
      const result = await ApiService.login(this.username, this.password);
      GlobalState.setToken(result.token);
      GlobalState.setUser(result.user);

      // 保存登录态
      await prefUtil.setToken(result.token);
      await prefUtil.setUserId(result.user.id);
      const context = getContext(this);
      tokenFileStore.init(context);
      tokenFileStore.saveToken(result.token);
      tokenFileStore.saveUserId(result.user.id);

      const today = new Date().toISOString().slice(0, 10);
      try {
        const cardData = await ApiService.getCardData(today);
        formUpdateUtil.refreshAllCards(cardData.completedCount, cardData.totalCount, true).catch(() => {});
      } catch (e) {
        // 拉取失败时降级为仅更新登录状态
        formUpdateUtil.refreshAllCards(0, 0, true).catch(() => {});
      }

      // 启动通知提醒服务：为所有未打卡的习惯发送通知
      NotificationUtil.checkAndSendReminders().catch((err: BusinessError) => {
        console.error('启动通知提醒服务失败:', err.message);
      });

      router.replaceUrl({ url: 'pages/Index' });
    } catch (e) {
      AlertDialog.show({ message: (e as Error).message });
    } finally {
      this.isLoading = false;
    }
  }

  async handleRegister() {
    if (!this.username.trim() || !this.password.trim() || !this.nickname.trim()) {
      AlertDialog.show({ message: '请填写完整信息' });
      return;
    }

    if (this.password !== this.confirmPassword) {
      AlertDialog.show({ message: '两次输入的密码不一致' });
      return;
    }

    if (this.password.length < 6) {
      AlertDialog.show({ message: '密码长度至少6位' });
      return;
    }

    this.isLoading = true;
    try {
      await ApiService.register(this.username, this.password, this.nickname);
      AlertDialog.show({ message: '注册成功，请登录' });
      this.isLoginMode = true;
      this.password = '';
      this.confirmPassword = '';
    } catch (e) {
      AlertDialog.show({ message: (e as Error).message });
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Text('📋')
            .fontSize(64)
          Text('习惯打卡助手')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 12 })
          Text('培养自律，成就更好的自己')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 8 })
        }
        .margin({ top: 40, bottom: 48 })

        Row() {
          Text('登录')
            .fontSize(18)
            .fontWeight(this.isLoginMode ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.isLoginMode ? '#1890FF' : '#999')
            .onClick(() => this.isLoginMode = true)
          Divider()
            .vertical(true)
            .height(20)
            .color('#e0e0e0')
            .margin({ left: 20, right: 20 })
          Text('注册')
            .fontSize(18)
            .fontWeight(!this.isLoginMode ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(!this.isLoginMode ? '#1890FF' : '#999')
            .onClick(() => this.isLoginMode = false)
        }
        .margin({ bottom: 36 })

        Column({ space: 20 }) {
          Column({ space: 8 }) {
            Text('用户名')
              .fontSize(14)
              .fontColor('#666')
              .width('100%')
            TextInput({ placeholder: '请输入用户名', text: $$this.username })
              .height(48)
              .backgroundColor('#f5f5f5')
              .borderRadius(8)
              .padding({ left: 16, right: 16 })
          }

          Column({ space: 8 }) {
            Text('密码')
              .fontSize(14)
              .fontColor('#666')
              .width('100%')
            TextInput({ placeholder: '请输入密码', text: $$this.password })
              .type(InputType.Password)
              .height(48)
              .backgroundColor('#f5f5f5')
              .borderRadius(8)
              .padding({ left: 16, right: 16 })
          }

          if (!this.isLoginMode) {
            Column({ space: 8 }) {
              Text('确认密码')
                .fontSize(14)
                .fontColor('#666')
                .width('100%')
              TextInput({ placeholder: '请再次输入密码', text: $$this.confirmPassword })
                .type(InputType.Password)
                .height(48)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .padding({ left: 16, right: 16 })
            }
          }

          if (!this.isLoginMode) {
            Column({ space: 8 }) {
              Text('昵称')
                .fontSize(14)
                .fontColor('#666')
                .width('100%')
              TextInput({ placeholder: '请输入昵称', text: $$this.nickname })
                .height(48)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .padding({ left: 16, right: 16 })
            }
          }

          Button(this.isLoading ? '处理中...' : (this.isLoginMode ? '登录' : '注册'))
            .width('100%')
            .height(48)
            .backgroundColor('#1890FF')
            .margin({ top: 20 })
            .enabled(!this.isLoading)
            .onClick(() => {
              if (this.isLoginMode) {
                this.handleLogin();
              } else {
                this.handleRegister();
              }
            })
        }
        .width('100%')
        .padding({ left: 32, right: 32 })

        if (this.isLoginMode) {
          Text('还没有账号？点击上方"注册"')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 28 })
            .onClick(() => this.isLoginMode = false)
        } else {
          Text('已有账号？点击上方"登录"')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 28 })
            .onClick(() => this.isLoginMode = true)
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#fff')
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM])
  }
}