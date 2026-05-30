<template>
  <div class="usage-page">
    <!-- 统计卡片 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-item">
            <div class="stat-label">总 Token 用量</div>
            <div class="stat-value">{{ formatNumber(stats.total?.tokens || 0) }}</div>
            <div class="stat-detail">
              <span class="input">输入: {{ formatNumber(stats.total?.input || 0) }}</span>
              <span class="output">输出: {{ formatNumber(stats.total?.output || 0) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-item">
            <div class="stat-label">今日 Token 用量</div>
            <div class="stat-value">{{ formatNumber(stats.today?.tokens || 0) }}</div>
            <div class="stat-detail">
              <span class="input">输入: {{ formatNumber(stats.today?.input || 0) }}</span>
              <span class="output">输出: {{ formatNumber(stats.today?.output || 0) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-item">
            <div class="stat-label">本月 Token 用量</div>
            <div class="stat-value">{{ formatNumber(stats.month?.tokens || 0) }}</div>
            <div class="stat-detail">
              <span class="input">输入: {{ formatNumber(stats.month?.input || 0) }}</span>
              <span class="output">输出: {{ formatNumber(stats.month?.output || 0) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-item">
            <div class="stat-label">账户余额</div>
            <div class="stat-value">¥{{ balance.toFixed(2) }}</div>
            <div class="stat-detail">
              <span>总花费: ¥{{ (stats.total?.cost || 0).toFixed(2) }}</span>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="16" class="chart-row">
      <el-col :span="16">
        <el-card shadow="never">
          <template #header>
            <div class="card-header">
              <span>每日 Token 用量趋势</span>
              <el-radio-group v-model="chartDays" size="small" @change="fetchDailyUsage">
                <el-radio-button :value="7">近7天</el-radio-button>
                <el-radio-button :value="14">近14天</el-radio-button>
                <el-radio-button :value="30">近30天</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="dailyChartRef" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never">
          <template #header>
            <span>模型使用分布</span>
          </template>
          <div ref="modelChartRef" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 使用记录表格 -->
    <el-card shadow="never">
      <template #header>
        <div class="card-header">
          <span>使用记录</span>
          <el-button type="primary" @click="exportRecords">导出记录</el-button>
        </div>
      </template>

      <el-table :data="records" style="width: 100%" v-loading="loading">
        <el-table-column prop="created_at" label="时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="model_id" label="模型" width="150" />
        <el-table-column prop="tokens_input" label="输入 Tokens" width="120">
          <template #default="{ row }">
            {{ row.tokens_input.toLocaleString() }}
          </template>
        </el-table-column>
        <el-table-column prop="tokens_output" label="输出 Tokens" width="120">
          <template #default="{ row }">
            {{ row.tokens_output.toLocaleString() }}
          </template>
        </el-table-column>
        <el-table-column label="合计" width="120">
          <template #default="{ row }">
            {{ (row.tokens_input + row.tokens_output).toLocaleString() }}
          </template>
        </el-table-column>
        <el-table-column prop="cost" label="费用" width="100">
          <template #default="{ row }">
            ¥{{ row.cost.toFixed(4) }}
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :page-sizes="[20, 50, 100]"
        :total="total"
        layout="total, sizes, prev, pager, next, jumper"
        @size-change="fetchRecords"
        @current-change="fetchRecords"
        style="margin-top: 16px; justify-content: flex-end"
      />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'

const loading = ref(false)
const records = ref([])
const stats = ref<any>({})
const balance = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)
const chartDays = ref(7)

const dailyChartRef = ref<HTMLElement>()
const modelChartRef = ref<HTMLElement>()
let dailyChart: echarts.ECharts | null = null
let modelChart: echarts.ECharts | null = null
let refreshTimer: ReturnType<typeof setInterval> | null = null

onMounted(async () => {
  await fetchAllData()

  nextTick(() => {
    initCharts()
  })

  // 每 20 秒刷新数据
  refreshTimer = setInterval(() => {
    fetchAllData()
  }, 20000)
})

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
  window.removeEventListener('resize', handleResize)
})

async function fetchAllData() {
  await Promise.all([
    fetchStats(),
    fetchBalance(),
    fetchRecords(),
    fetchDailyUsage(),
    fetchModelStats(),
  ])
}

async function fetchStats() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch('/api/usage/stats', {
      headers: { Authorization: `Bearer ${token}` },
    })
    stats.value = await response.json()
  } catch (error) {
    console.error('获取统计失败:', error)
  }
}

async function fetchBalance() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch('/api/usage/balance', {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await response.json()
    balance.value = data.balance || 0
  } catch (error) {
    console.error('获取余额失败:', error)
  }
}

async function fetchRecords() {
  loading.value = true
  try {
    const token = localStorage.getItem('token')
    const response = await fetch(`/api/usage/records?page=${currentPage.value}&page_size=${pageSize.value}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await response.json()
    records.value = data.items || []
    total.value = data.total || 0
  } finally {
    loading.value = false
  }
}

async function fetchDailyUsage() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch(`/api/usage/daily?days=${chartDays.value}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await response.json()
    updateDailyChart(data)
  } catch (error) {
    console.error('获取每日统计失败:', error)
  }
}

async function fetchModelStats() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch('/api/usage/model-stats', {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await response.json()
    updateModelChart(data.models || [])
  } catch (error) {
    console.error('获取模型统计失败:', error)
  }
}

function initCharts() {
  if (dailyChartRef.value) {
    dailyChart = echarts.init(dailyChartRef.value)
  }
  if (modelChartRef.value) {
    modelChart = echarts.init(modelChartRef.value)
  }

  window.addEventListener('resize', handleResize)
}

function handleResize() {
  dailyChart?.resize()
  modelChart?.resize()
}

function updateDailyChart(data: any) {
  if (!dailyChart || !data.dates) return

  dailyChart.setOption({
    tooltip: {
      trigger: 'axis',
    },
    legend: {
      data: ['输入 Token', '输出 Token'],
      top: 0,
    },
    grid: {
      left: '10%',
      right: '5%',
      top: '15%',
      bottom: '10%',
    },
    xAxis: {
      type: 'category',
      data: data.dates?.map((d: string) => d.substring(5)) || [],
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: function (value: number) {
          if (value >= 1000000) return (value / 1000000).toFixed(1) + 'M'
          if (value >= 1000) return (value / 1000).toFixed(0) + 'K'
          return value.toString()
        },
      },
    },
    series: [
      {
        name: '输入 Token',
        type: 'bar',
        stack: 'total',
        data: data.input || [],
        itemStyle: { color: '#409eff', borderRadius: [4, 4, 0, 0] },
      },
      {
        name: '输出 Token',
        type: 'bar',
        stack: 'total',
        data: data.output || [],
        itemStyle: { color: '#67c23a', borderRadius: [4, 4, 0, 0] },
      },
    ],
  })
}

function updateModelChart(models: any[]) {
  if (!modelChart || models.length === 0) return

  const colors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#909399']

  modelChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'center',
    },
    series: [
      {
        type: 'pie',
        radius: ['45%', '75%'],
        center: ['40%', '50%'],
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: { show: false },
        emphasis: {
          label: { show: true, fontSize: 14, fontWeight: 'bold' },
        },
        data: models.map((m, i) => ({
          name: m.model_id,
          value: m.total,
          itemStyle: { color: colors[i % colors.length] },
        })),
      },
    ],
  })
}

function formatNumber(num: number): string {
  if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M'
  if (num >= 1000) return (num / 1000).toFixed(1) + 'K'
  return num.toString()
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString('zh-CN')
}

function exportRecords() {
  alert('导出功能开发中...')
}
</script>

<style scoped>
.usage-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.stats-row {
  margin-bottom: 0;
}

.stat-card {
  border: none;
}

.stat-item {
  text-align: center;
  padding: 8px 0;
}

.stat-label {
  font-size: 13px;
  color: var(--el-text-color-secondary);
  margin-bottom: 8px;
}

.stat-value {
  font-size: 24px;
  font-weight: 700;
  color: var(--el-text-color-primary);
  margin-bottom: 8px;
}

.stat-detail {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  display: flex;
  justify-content: center;
  gap: 16px;
}

.stat-detail .input {
  color: var(--el-color-primary);
}

.stat-detail .output {
  color: var(--el-color-success);
}

.chart-row {
  margin-bottom: 0;
}

.chart-container {
  height: 300px;
  width: 100%;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
</style>
