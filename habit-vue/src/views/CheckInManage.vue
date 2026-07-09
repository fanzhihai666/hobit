<template>
  <div>
    <el-card shadow="hover">
      <template #header>
        <div style="display: flex; align-items: center; gap: 10px;">
          <span style="font-weight: bold;">打卡记录管理</span>
          <div style="margin-left: auto; display: flex; gap: 10px;">
            <el-input v-model="searchForm.userId" placeholder="用户ID" style="width: 120px" clearable />
            <el-input v-model="searchForm.habitId" placeholder="习惯ID" style="width: 120px" clearable />
            <el-date-picker
                v-model="searchForm.dateRange"
                type="daterange"
                range-separator="至"
                start-placeholder="开始日期"
                end-placeholder="结束日期"
                value-format="YYYY-MM-DD"
                style="width: 240px"
            />
            <el-button type="primary" @click="handleSearch">查询</el-button>
          </div>
        </div>
      </template>

      <el-table :data="recordList" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="userId" label="用户ID" width="80" />
        <el-table-column prop="habitName" label="习惯名称" />
        <el-table-column prop="habitIcon" label="图标" width="80">
          <template #default="{ row }">
            <span style="font-size: 20px;">{{ row.habitIcon || '📌' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="checkInDate" label="打卡日期" width="120" />
        <el-table-column prop="remark" label="备注" show-overflow-tooltip />
        <el-table-column prop="checkInTime" label="打卡时间" />
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

const recordList = ref([])
const loading = ref(false)
const currentPage = ref(1)
const pageSize = ref(10)
const total = ref(0)
const searchForm = ref({ userId: '', habitId: '', dateRange: [] })

const loadData = async () => {
  loading.value = true
  try {
    const params = {
      current: currentPage.value,
      size: pageSize.value,
      userId: searchForm.value.userId || undefined,
      habitId: searchForm.value.habitId || undefined
    }
    if (searchForm.value.dateRange?.length === 2) {
      params.startDate = searchForm.value.dateRange[0]
      params.endDate = searchForm.value.dateRange[1]
    }
    const res = await adminApi.getCheckInList(params)
    recordList.value = res.records || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

const handleSearch = () => { currentPage.value = 1; loadData() }

const handleDelete = (row) => {
  ElMessageBox.confirm('确认删除该打卡记录？', '警告', { type: 'warning' })
      .then(async () => {
        await adminApi.deleteCheckIn(row.id)
        ElMessage.success('删除成功')
        loadData()
      })
}

onMounted(loadData)
</script>

<style scoped>
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
