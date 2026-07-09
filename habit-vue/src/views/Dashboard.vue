<template>
  <div class="dashboard">
    <el-row :gutter="20">
      <el-col :span="6" v-for="item in statCards" :key="item.key">
        <el-card shadow="hover">
          <div class="stat-card">
            <div class="stat-title">{{ item.title }}</div>
            <div class="stat-value" :style="{ color: item.color }">{{ stats[item.key] || 0 }}</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card class="chart-card" shadow="hover">
      <template #header><span>近7天打卡趋势</span></template>
      <div ref="chartRef" style="height: 320px;"></div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { adminApi } from '../api/admin'

const stats = ref({})
const chartRef = ref(null)
let chartInstance = null

const statCards = [
  { title: '用户总数', key: 'userCount', color: '#409EFF' },
  { title: '习惯总数', key: 'habitCount', color: '#67C23A' },
  { title: '打卡总数', key: 'checkInCount', color: '#E6A23C' },
  { title: '今日打卡', key: 'todayCheckInCount', color: '#F56C6C' }
]

const loadData = async () => {
  const res = await adminApi.getStatistics()
  stats.value = res

  await nextTick()
  if (!chartRef.value) return
  if (chartInstance) chartInstance.dispose()
  chartInstance = echarts.init(chartRef.value)

  const xData = (res.weekTrend || []).map(i => i.date)
  const sData = (res.weekTrend || []).map(i => i.count)

  chartInstance.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: { type: 'category', boundaryGap: false, data: xData },
    yAxis: { type: 'value', minInterval: 1 },
    series: [{
      data: sData,
      type: 'line',
      smooth: true,
      areaStyle: { color: 'rgba(64, 158, 255, 0.2)' },
      itemStyle: { color: '#409EFF' },
      lineStyle: { width: 3 }
    }]
  })
}

onMounted(() => {
  loadData()
  window.addEventListener('resize', () => chartInstance?.resize())
})
</script>

<style scoped>
.stat-card { text-align: center; padding: 10px; }
.stat-title { color: #666; font-size: 14px; margin-bottom: 10px; }
.stat-value { font-size: 32px; font-weight: bold; }
.chart-card { margin-top: 20px; }
</style>
