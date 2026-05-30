<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <el-row :gutter="16" class="stats-row">
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-icon primary">
            <el-icon :size="24"><TrendCharts /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.today?.tokens || 0) }}</div>
            <div class="stat-label">今日 Token</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-icon success">
            <el-icon :size="24"><Calendar /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.month?.tokens || 0) }}</div>
            <div class="stat-label">本月 Token</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-icon warning">
            <el-icon :size="24"><Wallet /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">¥{{ balance.toFixed(2) }}</div>
            <div class="stat-label">账户余额</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="never" class="stat-card">
          <div class="stat-icon danger">
            <el-icon :size="24"><DataLine /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.total?.tokens || 0) }}</div>
            <div class="stat-label">总 Token</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="16" class="chart-row">
      <el-col :span="16">
        <el-card shadow="never" class="chart-card">
          <template #header>
            <div class="card-header">
              <span>使用趋势</span>
              <el-radio-group v-model="chartDays" size="small" @change="fetchDailyUsage">
                <el-radio-button :value="7">近7天</el-radio-button>
                <el-radio-button :value="14">近14天</el-radio-button>
                <el-radio-button :value="30">近30天</el-radio-button>
              </el-radio-group>
            </div>
          </template>
          <div ref="trendChartRef" class="chart-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never" class="chart-card">
          <template #header>
            <span>模型分布</span>
          </template>
          <div ref="pieChartRef" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最近对话 -->
    <el-card shadow="never" class="recent-card">
      <template #header>
        <div class="card-header">
          <span>最近对话</span>
          <el-button type="primary" link @click="router.push('/')">
            查看全部
            <el-icon class="el-icon--right"><ArrowRight /></el-icon>
          </el-button>
        </div>
      </template>
      <el-table :data="recentConversations" style="width: 100%">
        <el-table-column prop="title" label="对话标题" min-width="200" show-overflow-tooltip />
        <el-table-column prop="model_id" label="模型" width="150" />
        <el-table-column label="时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.last_message_at || row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="goToChat(row)">
              继续
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import * as echarts from 'echarts'

const router = useRouter()

const chartDays = ref(7)
const trendChartRef = ref<HTMLElement>()
const pieChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null
let refreshTimer: ReturnType<typeof setInterval> | null = null

const stats = ref<any>({})
const balance = ref(0)
const recentConversations = ref<any[]>([])
const dailyData = ref<any>({})
const modelStats = ref<any[]>([])

onMounted(async () => {
  // 等待 DOM 渲染完成后再初始化图表
  await nextTick()
  initCharts()

  // 获取数据
  await fetchAllData()

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
  trendChart?.dispose()
  pieChart?.dispose()
})

function initCharts() {
  if (trendChartRef.value) {
    trendChart = echarts.init(trendChartRef.value)
  }
  if (pieChartRef.value) {
    pieChart = echarts.init(pieChartRef.value)
  }
  window.addEventListener('resize', handleResize)
}

function handleResize() {
  trendChart?.resize()
  pieChart?.resize()
}

async function fetchAllData() {
  await Promise.all([
    fetchStats(),
    fetchBalance(),
    fetchConversations(),
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

async function fetchConversations() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch('/api/conversations', {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await response.json()
    recentConversations.value = (data || []).slice(0, 5)
  } catch (error) {
    console.error('获取对话失败:', error)
  }
}

async function fetchDailyUsage() {
  try {
    const token = localStorage.getItem('token')
    const response = await fetch(`/api/usage/daily?days=${chartDays.value}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    dailyData.value = await response.json()
    updateTrendChart()
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
    modelStats.value = data.models || []
    updatePieChart()
  } catch (error) {
    console.error('获取模型统计失败:', error)
  }
}

function updateTrendChart() {
  if (!trendChart) return

  const dates = dailyData.value.dates || []
  const inputData = dailyData.value.input || []
  const outputData = dailyData.value.output || []

  trendChart.setOption({
    tooltip: {
      trigger: 'axis',
      formatter: function (params: any) {
        let result = params[0].axisValue + '<br/>'
        let total = 0
        params.forEach((param: any) => {
          result += param.marker + param.seriesName + ': ' + param.value.toLocaleString() + '<br/>'
          total += param.value
        })
        result += '<b>总计: ' + total.toLocaleString() + '</b>'
        return result
      },
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
      data: dates.map((d: string) => d.substring(5)),
      axisLabel: {
        color: '#666',
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        color: '#666',
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
        data: inputData,
        itemStyle: { color: '#409eff', borderRadius: [4, 4, 0, 0] },
        barWidth: '40%',
      },
      {
        name: '输出 Token',
        type: 'bar',
        stack: 'total',
        data: outputData,
        itemStyle: { color: '#67c23a', borderRadius: [4, 4, 0, 0] },
        barWidth: '40%',
      },
    ],
  })
}

function updatePieChart() {
  if (!pieChart || modelStats.value.length === 0) return

  const colors = ['#409eff', '#67c23a', '#e6a23c', '#f56c6c', '#909399']

  pieChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'center',
      textStyle: { color: '#666' },
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
        data: modelStats.value.map((m, i) => ({
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
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

function goToChat(conv: any) {
  router.push('/')
}
</script>

<style scoped>
.dashboard {
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

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.stat-icon.primary {
  background: var(--el-color-primary);
}

.stat-icon.success {
  background: var(--el-color-success);
}

.stat-icon.warning {
  background: var(--el-color-warning);
}

.stat-icon.danger {
  background: var(--el-color-danger);
}

.stat-info {
  flex: 1;
}

.stat-value {
  font-size: 24px;
  font-weight: 700;
  color: var(--el-text-color-primary);
  line-height: 1.2;
}

.stat-label {
  font-size: 13px;
  color: var(--el-text-color-secondary);
  margin-top: 4px;
}

.chart-row {
  margin-bottom: 0;
}

.chart-card {
  border: none;
}

.chart-card :deep(.el-card__body) {
  padding: 0 20px 20px;
}

.chart-container {
  height: 350px;
  width: 100%;
  min-height: 300px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.recent-card {
  border: none;
}

.recent-card :deep(.el-card__body) {
  padding: 0;
}
</style>
