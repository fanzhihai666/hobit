import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { GlobalState } from '../model/Models';
import { prefUtil } from '../utils/PreferenceUtil';
import { tokenFileStore } from '../utils/TokenFileStore';

// 导出 BASE_URL，供 EntryFormAbility 使用
export const BASE_URL = 'http://10.74.168.246:8080';

// 卡片使用的 token key
const CARD_TOKEN_KEY = 'card_user_token';

interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
}

class Request {
  private http = http.createHttp();
  private context: Context | null = null;

  setContext(ctx: Context) {
    this.context = ctx;
  }

  /**
   * 异步获取 token：优先级 GlobalState > AppStorage > Preferences
   * 适配主应用进程 + 卡片独立进程
   */
  private async getToken(): Promise<string> {
    // 1. 主应用全局状态（主进程优先）
    if (GlobalState.token && GlobalState.token.length > 0) {
      return GlobalState.token;
    }
    // 2. 跨进程文件存储（卡片进程核心依赖，最可靠）
    if (this.context) {
      tokenFileStore.init(this.context);
      const fileToken = tokenFileStore.readToken();
      if (fileToken && fileToken.length > 0) {
        return fileToken;
      }
    }
    // 3. AppStorage 缓存
    const cardToken = AppStorage.get<string>(CARD_TOKEN_KEY);
    if (cardToken && cardToken.length > 0) {
      return cardToken;
    }
    // 4. 偏好设置（兜底，多进程不可靠）
    if (this.context) {
      try {
        await prefUtil.init(this.context);
        const prefToken = await prefUtil.getToken();
        if (prefToken && prefToken.length > 0) {
          return prefToken;
        }
      } catch (e) {
        console.error('读取偏好Token失败', JSON.stringify(e));
      }
    }
    return '';
  }

  async get<T>(url: string, params?: object): Promise<T> {
    let fullUrl = BASE_URL + url;
    if (params) {
      const keys = Object.keys(params);
      const query = keys.map((key: string) => {
        const value = (params as Record<string, string | number>)[key];
        return `${key}=${encodeURIComponent(String(value))}`;
      }).join('&');
      fullUrl += '?' + query;
    }

    const token = await this.getToken();
    const response = await this.http.request(fullUrl, {
      method: http.RequestMethod.GET,
      header: {
        'Content-Type': 'application/json',
        'Authorization': token ? 'Bearer ' + token : ''
      }
    });

    const resultText = response.result as string;
    if (!resultText || resultText.trim() === '') {
      throw new Error('服务器返回空响应，请检查后端服务');
    }
    if (resultText.trim().startsWith('<')) {
      throw new Error('服务器返回 HTML 错误页面，可能是 401/403/500 错误');
    }

    const result: ApiResponse<T> = JSON.parse(resultText) as ApiResponse<T>;
    if (result.code !== 200) {
      throw new Error(result.msg);
    }
    return result.data;
  }

  async post<T>(url: string, data?: object): Promise<T> {
    const token = await this.getToken();
    const response = await this.http.request(BASE_URL + url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': token ? 'Bearer ' + token : ''
      },
      extraData: data ? JSON.stringify(data) : ''
    });

    const resultText = response.result as string;
    if (!resultText || resultText.trim() === '') {
      throw new Error('服务器返回空响应，请检查后端服务');
    }
    if (resultText.trim().startsWith('<')) {
      throw new Error('服务器返回 HTML 错误页面，可能是 401/403/500 错误');
    }

    const result: ApiResponse<T> = JSON.parse(resultText) as ApiResponse<T>;
    if (result.code !== 200) {
      throw new Error(result.msg);
    }
    return result.data;
  }

  async delete<T>(url: string): Promise<T> {
    const token = await this.getToken();
    const response = await this.http.request(BASE_URL + url, {
      method: http.RequestMethod.DELETE,
      header: {
        'Authorization': token ? 'Bearer ' + token : ''
      }
    });

    const resultText = response.result as string;
    if (!resultText || resultText.trim() === '') {
      throw new Error('服务器返回空响应，请检查后端服务');
    }
    if (resultText.trim().startsWith('<')) {
      throw new Error('服务器返回 HTML 错误页面，可能是 401/403/500 错误');
    }

    const result: ApiResponse<T> = JSON.parse(resultText) as ApiResponse<T>;
    if (result.code !== 200) {
      throw new Error(result.msg);
    }
    return result.data;
  }

  async uploadFile(fileUri: string, context?: Context): Promise<string> {
    const ctx = context || this.context;
    if (!ctx) {
      throw new Error('Context 不可用，请先调用 setContext() 或传入 context 参数');
    }

    const fileName = fileUri.substring(fileUri.lastIndexOf('/') + 1) || `image_${Date.now()}.jpg`;
    const destPath = `${ctx.cacheDir}/${Date.now()}_${fileName}`;

    const srcFile = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
    const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    fs.copyFileSync(srcFile.fd, destFile.fd);
    fs.closeSync(srcFile);
    fs.closeSync(destFile);

    const token = await this.getToken();
    const response = await this.http.request(BASE_URL + '/api/file/upload', {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'multipart/form-data',
        'Authorization': token ? 'Bearer ' + token : ''
      },
      multiFormDataList: [
        {
          name: 'file',
          contentType: 'image/jpeg',
          filePath: destPath,
          remoteFileName: fileName
        }
      ]
    });

    const resultText = response.result as string;
    if (!resultText || resultText.trim() === '') {
      throw new Error('服务器返回空响应，请检查后端服务');
    }
    if (resultText.trim().startsWith('<')) {
      throw new Error('服务器返回 HTML 错误页面');
    }

    const result: ApiResponse<string> = JSON.parse(resultText) as ApiResponse<string>;
    if (result.code !== 200) {
      throw new Error(result.msg);
    }
    return result.data;
  }
}

export const request = new Request();