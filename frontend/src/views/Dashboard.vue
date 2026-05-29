<template>
  <div class="dashboard">
    <!-- 统计卡片 -->
    <el-row :gutter="20" class="stats-row">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: linear-gradient(135deg, #409eff 0%, #6366f1 100%)">
            <el-icon :size="24"><TrendCharts /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.today?.tokens || 0) }}</div>
            <div class="stat-label">今日 Token 用量</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: linear-gradient(135deg, #67c23a 0%, #22c55e 100%)">
            <el-icon :size="24"><Calendar /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.month?.tokens || 0) }}</div>
            <div class="stat-label">本月 Token 用量</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: linear-gradient(135deg, #e6a23c 0%, #f59e0b 100%)">
            <el-icon :size="24"><Wallet /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">¥{{ balance.toFixed(2) }}</div>
            <div class="stat-label">账户余额</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: linear-gradient(135deg, #f56c6c 0%, #ef4444 100%)">
            <el-icon :size="24"><DataLine /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatNumber(stats.total?.tokens || 0) }}</div>
            <div class="stat-label">总 Token 用量</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 图表区域 -->
    <el-row :gutter="20" class="chart-row">
      <el-col :span="16">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <div class="header-left">
                <h3>使用趋势</h3>
                <span class="header-subtitle">近 7 天 Token 使用量</span>
              </div>
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
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <h3>模型分布</h3>
              <span class="header-subtitle">各模型使用占比</span>
            </div>
          </template>
          <div ref="pieChartRef" class="chart-container"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 最近对话 -->
    <el-card class="recent-card">
      <template #header>
        <div class="card-header">
          <div class="header-left">
            <h3>最近对话</h3>
            <span class="header-subtitle">最近 5 条对话记录</span>
          </div>
          <el-button type="primary" link @click="router.push('/')">
            查看全部
            <el-icon class="el-icon--right"><ArrowRight /></el-icon>
          </el-button>
        </div>
      </template>
      <el-table :data="recentConversations" style="width: 100%" :row-class-name="tableRowClassName">
        <el-table-column prop="title" label="对话标题" min-width="200">
          <template #default="{ row }">
            <div class="conversation-title">
              <el-icon class="conv-icon"><ChatLineRound /></el-icon>
              {{ row.title || '新对话' }}
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="model_id" label="模型" width="150">
          <template #default="{ row }">
            <el-tag size="small" effect="plain">{{ row.model_id }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="时间" width="180">
          <template #default="{ row }">
            <div class="time-cell">
              <el-icon class="time-icon"><Clock /></el-icon>
              {{ formatDate(row.last_message_at || row.created_at) }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="goToChat(row)" class="action-btn">
              继续对话
              <el-icon class="el-icon--right"><ArrowRight /></el-icon>
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import * as echarts from 'echarts'

const router = useRouter()

const chartDays = ref(7)
const trendChartRef = ref<HTMLElement>()
const pieChartRef = ref<HTMLElement>()
let trendChart: echarts.ECharts | null = null
let pieChart: echarts.ECharts | null = null

const stats = ref<any>({})
const balance = ref(0)
const recentConversations = ref<any[]>([])
const dailyData = ref<any>({})
const modelStats = ref<any[]>([])

onMounted(async () => {
  await Promise.all([
    fetchStats(),
    fetchBalance(),
    fetchConversations(),
    fetchDailyUsage(),
    fetchModelStats(),
  ])

  nextTick(() => {
    initCharts()
  })
})

async function fetchStats() {
  try {
    const response = await fetch('/api/usage/stats', {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    })
    stats.value = await response.json()
  } catch (error) {
    console.error('获取统计失败:', error)
  }
}

async function fetchBalance() {
  try {
    const response = await fetch('/api/usage/balance', {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    })
    const data = await response.json()
    balance.value = data.balance || 0
  } catch (error) {
    console.error('获取余额失败:', error)
  }
}

async function fetchConversations() {
  try {
    const response = await fetch('/api/conversations', {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    })
    const data = await response.json()
    recentConversations.value = (data || []).slice(0, 5)
  } catch (error) {
    console.error('获取对话失败:', error)
  }
}

async function fetchDailyUsage() {
  try {
    const response = await fetch(`/api/usage/daily?days=${chartDays.value}`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    })
    dailyData.value = await response.json()
    updateTrendChart()
  } catch (error) {
    console.error('获取每日统计失败:', error)
  }
}

async function fetchModelStats() {
  try {
    const response = await fetch('/api/usage/model-stats', {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    })
    const data = await response.json()
    modelStats.value = data.models || []
    updatePieChart()
  } catch (error) {
    console.error('获取模型统计失败:', error)
  }
}

function initCharts() {
  if (trendChartRef.value) {
    trendChart = echarts.init(trendChartRef.value)
    updateTrendChart()
  }
  if (pieChartRef.value) {
    pieChart = echarts.init(pieChartRef.value)
    updatePieChart()
  }

  window.addEventListener('resize', () => {
    trendChart?.resize()
    pieChart?.resize()
  })
}

function updateTrendChart() {
  if (!trendChart || !dailyData.value.dates) return

  trendChart.setOption({
    tooltip: {
      trigger: 'axis',
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      borderColor: '#e4e7ed',
      textStyle: { color: '#303133' },
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
      left: '3%',
      right: '4%',
      bottom: '3%',
      top: '15%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: dailyData.value.dates?.map((d: string) => d.substring(5)) || [],
      axisLine: { lineStyle: { color: '#e4e7ed' } },
      axisLabel: { color: '#909399' },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      splitLine: { lineStyle: { color: '#f0f0f0', type: 'dashed' } },
      axisLabel: {
        color: '#909399',
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
        data: dailyData.value.input || [],
        itemStyle: { color: '#409eff', borderRadius: [4, 4, 0, 0] },
        barWidth: '40%',
      },
      {
        name: '输出 Token',
        type: 'bar',
        stack: 'total',
        data: dailyData.value.output || [],
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
      backgroundColor: 'rgba(255, 255, 255, 0.95)',
      borderColor: '#e4e7ed',
      textStyle: { color: '#303133' },
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'center',
      textStyle: { color: '#606266' },
    },
    series: [
      {
        type: 'pie',
        radius: ['45%', '75%'],
        center: ['40%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 3,
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

function tableRowClassName({ rowIndex }: { rowIndex: number }) {
  return rowIndex % 2 === 0 ? '' : 'stripe-row'
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
  gap: 20px;
}

.stats-row {
  margin-bottom: 0;
}

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
}

.stat-icon {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.stat-info {
  flex: 1;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.2;
}

.stat-label {
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 4px;
}

.chart-row {
  margin-bottom: 0;
}

.chart-card {
  height: 400px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header-left h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.header-subtitle {
  font-size: 12px;
  color: var(--text-secondary);
  margin-top: 4px;
  display: block;
}

.chart-container {
  height: 320px;
  width: 100%;
}

.conversation-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.conv-icon {
  color: var(--primary-color);
}

.time-cell {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
  font-size: 13px;
}

.time-icon {
  font-size: 14px;
}

.action-btn {
  font-weight: 500;
}

:deep(.stripe-row) {
  background: var(--bg-color);
}
</style>
