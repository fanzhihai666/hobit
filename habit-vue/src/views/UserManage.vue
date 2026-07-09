<template>
  <div>
    <el-card shadow="hover">
      <template #header>
        <div style="display: flex; align-items: center;">
          <span style="font-weight: bold;">用户管理</span>
          <el-input
              v-model="searchKeyword"
              placeholder="搜索用户名 / 昵称"
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

      <el-table :data="userList" v-loading="loading" border stripe>
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="username" label="用户名" />
        <el-table-column prop="nickname" label="昵称" />
        <el-table-column prop="createTime" label="创建时间" />
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" size="small" @click="handleEdit(row)">编辑</el-button>
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

    <el-dialog v-model="dialogVisible" title="编辑用户" width="400px" destroy-on-close>
      <el-form :model="editForm" label-width="70px">
        <el-form-item label="用户名"><el-input v-model="editForm.username" disabled /></el-form-item>
        <el-form-item label="昵称"><el-input v-model="editForm.nickname" /></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { adminApi } from '../api/admin'

const userList = ref([])
const loading = ref(false)
const currentPage = ref(1)
const pageSize = ref(10)
const total = ref(0)
const searchKeyword = ref('')
const dialogVisible = ref(false)
const editForm = ref({})

const loadData = async () => {
  loading.value = true
  try {
    const res = await adminApi.getUserList({
      current: currentPage.value,
      size: pageSize.value,
      keyword: searchKeyword.value || undefined
    })
    userList.value = res.records || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}

const handleSearch = () => { currentPage.value = 1; loadData() }
const handleEdit = (row) => { editForm.value = { ...row }; dialogVisible.value = true }

const handleSave = async () => {
  await adminApi.updateUser(editForm.value.id, { nickname: editForm.value.nickname })
  ElMessage.success('更新成功')
  dialogVisible.value = false
  loadData()
}

const handleDelete = (row) => {
  ElMessageBox.confirm(`确认删除用户 [${row.username}]？`, '警告', { type: 'warning' })
      .then(async () => {
        await adminApi.deleteUser(row.id)
        ElMessage.success('删除成功')
        loadData()
      })
}

onMounted(loadData)
</script>

<style scoped>
.pagination { margin-top: 20px; justify-content: flex-end; }
</style>
