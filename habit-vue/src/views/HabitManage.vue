<template>
  <div>
    <el-card shadow="hover">
      <template #header>
        <div style="display: flex; align-items: center;">
          <span style="font-weight: bold;">习惯管理</span>
          <el-input
              v-model="searchKeyword"
              placeholder="搜索习惯名称"
              style="width: 260px; margin-left: auto;"
              clearable
              @keyup.enter="handleSearch"
          >
            <template #append>
              <el-button @click="handleSearch"><el-icon><Search /></el-icon></el-button>
            </template>
          </el-input>
        </div>
      </template>

      <el-table :data="habitList" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="name" label="习惯名称" />
        <el-table-column prop="category" label="分类" width="100" />
        <el-table-column prop="priority" label="优先级" width="90" />
        <el-table-column prop="checkInType" label="打卡类型" width="110">
          <template #default="{ row }">
            <el-tag v-if="row.checkInType === 1" size="small">每日打卡</el-tag>
            <el-tag v-else type="success" size="small">一次性</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="userId" label="所属用户" width="90" />
        <el-table-column prop="createTime" label="创建时间" />
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button type="danger" size="small" @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
          class="pagination"
          v-model:current-page="currentPage"
          v-model:page-size="pageSize"
          :total="total"
          layout="total, prev, pager, next"
          @current-change="loadData"
      />
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { adminApi } from '../api/admin'

const habitList = ref([])
const loading = ref(false)
const currentPage = ref(1)
const pageSize = ref(10)
const total = ref(0)
const searchKeyword = ref('')

const loadData = async () => {
  loading.value = true
  try {
    const res = await adminApi.getHabitList({
      current: currentPage.value,
      size: pageSize.value,
      keyword: searchKeyword.value || undefined
    })
    habitList.value = res.records || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

const handleSearch = () => { currentPage.value = 1; loadData() }

const handleDelete = (row) => {
  ElMessageBox.confirm(`确认删除习惯 [${row.name}]？`, '警告', { type: 'warning' })
      .then(async () => {
        await adminApi.deleteHabit(row.id)
        ElMessage.success('删除成功')
        loadData()
      })
}

onMounted(loadData)
</script>

<style scoped>
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
