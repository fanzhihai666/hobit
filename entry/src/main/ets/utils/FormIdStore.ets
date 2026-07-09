import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';

const DOMAIN = 0x0000;
const TAG = 'FormIdStore';
const FILE_NAME = 'form_ids.txt';

class FormIdStore {
  private filePath: string = '';

  init(context: Context): void {
    this.filePath = `${context.filesDir}/${FILE_NAME}`;
  }

  addFormId(formId: string): void {
    if (!this.filePath || !formId) return;
    try {
      const ids = this.getAllFormIds();
      if (ids.includes(formId)) return;
      ids.push(formId);
      this.writeIdsToFile(ids);
      hilog.info(DOMAIN, TAG, `add formId success: ${formId}, total: ${ids.length}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `addFormId failed: ${JSON.stringify(e)}`);
    }
  }

  removeFormId(formId: string): void {
    if (!this.filePath || !formId) return;
    try {
      const ids = this.getAllFormIds();
      const newIds = ids.filter(id => id !== formId);
      this.writeIdsToFile(newIds);
      hilog.info(DOMAIN, TAG, `remove formId success: ${formId}, total: ${newIds.length}`);
    } catch (e) {
      hilog.error(DOMAIN, TAG, `removeFormId failed: ${JSON.stringify(e)}`);
    }
  }

  getAllFormIds(): string[] {
    if (!this.filePath) return [];
    try {
      fs.accessSync(this.filePath);
    } catch {
      return [];
    }
    try {
      const stat = fs.statSync(this.filePath);
      if (stat.size <= 0) return [];

      const buffer = new ArrayBuffer(stat.size);
      const file = fs.openSync(this.filePath, fs.OpenMode.READ_ONLY);
      try {
        fs.readSync(file.fd, buffer);
        const content = String.fromCharCode(...new Uint8Array(buffer));
        return content.split('\n').filter(id => id.trim() !== '');
      } finally {
        fs.closeSync(file.fd);
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, `getAllFormIds failed: ${JSON.stringify(e)}`);
      return [];
    }
  }

  private writeIdsToFile(ids: string[]): void {
    const file = fs.openSync(this.filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(file.fd, ids.join('\n'));
    } finally {
      fs.closeSync(file.fd);
    }
  }
}

export const formIdStore = new FormIdStore();