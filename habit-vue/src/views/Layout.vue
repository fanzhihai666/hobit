<template>
  <el-container class="layout-container">
    <el-aside width="210px" class="aside">
      <div class="logo">习惯打卡管理</div>
      <el-menu
          :default-active="route.path"
          router
          background-color="#304156"
          text-color="#bfcbd9"
          active-text-color="#409EFF"
          style="border-right: none;"
      >
        <el-menu-item index="/dashboard">
          <el-icon><DataLine /></el-icon>
          <span>数据概览</span>
        </el-menu-item>
        <el-menu-item index="/users">
          <el-icon><User /></el-icon>
          <span>用户管理</span>
        </el-menu-item>
        <el-menu-item index="/habits">
          <el-icon><Calendar /></el-icon>
          <span>习惯管理</span>
        </el-menu-item>
        <el-menu-item index="/checkins">
          <el-icon><Check /></el-icon>
          <span>打卡记录</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <div class="header-right">
          <span>{{ userInfo?.nickname || userInfo?.username }}</span>
          <el-button type="danger" text @click="handleLogout">退出登录</el-button>
        </div>
      </el-header>
      <el-main style="background: #f0f2f5;">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { useRoute, useRouter } from 'vue-router'
const route = useRoute()
const router = useRouter()
const userInfo = JSON.parse(localStorage.getItem('admin_user') || '{}')

const handleLogout = () => {
  localStorage.removeItem('admin_token')
  localStorage.removeItem('admin_user')
  router.push('/login')
}
</script>

<style scoped>
.layout-container { height: 100vh; }
.aside { background-color: #304156; }
.logo {
  height: 60px; line-height: 60px;
  text-align: center; color: #fff;
  font-size: 16px; font-weight: bold;
  border-bottom: 1px solid #1f2d3d;
}
.header {
  background: #fff;
  box-shadow: 0 1px 4px rgba(0,21,41,.08);
  display: flex; align-items: center; justify-content: flex-end;
}
.header-right {
  display: flex; align-items: center; gap: 15px;
  font-size: 14px; color: #606266;
}
</style>
