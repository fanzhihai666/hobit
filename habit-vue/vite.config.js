import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    open: true,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        // 无需 rewrite，因为后端接口本身就是 /api 开头
      },
      '/avatars': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      }
    }
  }
})
