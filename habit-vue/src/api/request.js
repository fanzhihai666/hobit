import axios from 'axios'
import { ElMessage } from 'element-plus'

const request = axios.create({
    baseURL: '/api',  // 改为相对路径，走 Vite 代理
    timeout: 10000
})

// 请求拦截器：注入 JWT Token
request.interceptors.request.use(config => {
    const token = localStorage.getItem('admin_token')
    if (token) {
        config.headers.Authorization = 'Bearer ' + token
    }
    return config
})

// 响应拦截器：统一处理错误
request.interceptors.response.use(
    response => {
        const res = response.data
        if (res.code !== 200) {
            ElMessage.error(res.msg || '请求失败')
            if (res.code === 401) {
                localStorage.removeItem('admin_token')
                localStorage.removeItem('admin_user')
                window.location.href = '/login'
            }
            return Promise.reject(new Error(res.msg))
        }
        return res.data
    },
    error => {
        ElMessage.error(error.message || '网络错误')
        return Promise.reject(error)
    }
)

export default request
