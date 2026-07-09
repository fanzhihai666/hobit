import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';

const DOMAIN = 0x0000;
const TAG = 'TokenFileStore';
const TOKEN_FILE = 'card_token.txt';
const USER_ID_FILE = 'card_user_id.txt';

class TokenFileStore {
  private filesDir: string = '';

  init(context: Context): void {
    this.filesDir = context.filesDir;
  }

  // 保存Token
  saveToken(token: string): void {
    this.writeFile(TOKEN_FILE, token);
  }

  // 读取Token
  readToken(): string {
    return this.readFile(TOKEN_FILE);
  }

  // 保存userId
  saveUserId(userId: number): void {
    this.writeFile(USER_ID_FILE, String(userId));
  }

  // 读取userId
  readUserId(): number {
    const content = this.readFile(USER_ID_FILE);
    const num = parseInt(content, 10);
    return isNaN(num) ? 0 : num;
  }

  // 清空所有数据
  clearAll(): void {
    this.deleteFile(TOKEN_FILE);
    this.deleteFile(USER_ID_FILE);
  }

  // ========== 私有文件操作 ==========
  private writeFile(fileName: string, content: string): void {
    if (!this.filesDir || !content) return;
    const filePath = `${this.filesDir}/${fileName}`;
    try {
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
      fs.closeSync(file.fd);
      hilog.info(DOMAIN, TAG, `${fileName} 写入成功`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `${fileName} 写入失败: ${JSON.stringify(e)}`);
    }
  }

  private readFile(fileName: string): string {
    if (!this.filesDir) return '';
    const filePath = `${this.filesDir}/${fileName}`;
    try {
      fs.accessSync(filePath);
      const stat = fs.statSync(filePath);
      if (stat.size <= 0) return '';

      const buffer = new ArrayBuffer(stat.size);
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      try {
        fs.readSync(file.fd, buffer);
        return String.fromCharCode(...new Uint8Array(buffer)).trim();
      } finally {
        fs.closeSync(file.fd);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `${fileName} 读取失败: ${JSON.stringify(e)}`);
      return '';
    }
  }

  private deleteFile(fileName: string): void {
    if (!this.filesDir) return;
    const filePath = `${this.filesDir}/${fileName}`;
    try {
      fs.unlinkSync(filePath);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `${fileName} 删除失败: ${JSON.stringify(e)}`);
    }
  }
}

export const tokenFileStore = new TokenFileStore();