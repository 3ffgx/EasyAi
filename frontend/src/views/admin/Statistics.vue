<template>
  <div class="admin-statistics">
    <!-- 统计卡片 -->
    <el-row :gutter="24">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: #409eff">
            <el-icon :size="24"><User /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.total_users || 0 }}</div>
            <div class="stat-label">总用户数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: #67c23a">
            <el-icon :size="24"><ChatLineRound /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ stats.total_conversations || 0 }}</div>
            <div class="stat-label">总对话数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: #e6a23c">
            <el-icon :size="24"><Coin /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">{{ formatTokens(stats.total_tokens) }}</div>
            <div class="stat-label">总 Token 用量</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background: #f56c6c">
            <el-icon :size="24"><Wallet /></el-icon>
          </div>
          <div class="stat-info">
            <div class="stat-value">¥{{ stats.total_revenue?.toFixed(2) || '0.00' }}</div>
            <div class="stat-label">总收入</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 今日统计 -->
    <el-row :gutter="24">
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-info">
            <div class="stat-value">{{ stats.today_users || 0 }}</div>
            <div class="stat-label">今日新增用户</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-info">
            <div class="stat-value">{{ stats.today_conversations || 0 }}</div>
            <div class="stat-label">今日对话数</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-info">
            <div class="stat-value">{{ formatTokens(stats.today_tokens) }}</div>
            <div class="stat-label">今日 Token 用量</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-info">
            <div class="stat-value">¥{{ stats.today_revenue?.toFixed(2) || '0.00' }}</div>
            <div class="stat-label">今日收入</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 模型使用排行 -->
    <el-card>
      <template #header>
        <span>模型使用排行</span>
      </template>
      <el-table :data="modelRanking" style="width: 100%">
        <el-table-column type="index" label="排名" width="80" />
        <el-table-column prop="model_id" label="模型" />
        <el-table-column prop="usage_count" label="调用次数" />
        <el-table-column prop="total_tokens" label="Token 用量">
          <template #default="{ row }">
            {{ formatTokens(row.total_tokens) }}
          </template>
        </el-table-column>
        <el-table-column prop="total_cost" label="费用">
          <template #default="{ row }">
            ¥{{ row.total_cost?.toFixed(2) || '0.00' }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 最近活跃用户 -->
    <el-card>
      <template #header>
        <span>最近活跃用户</span>
      </template>
      <el-table :data="activeUsers" style="width: 100%">
        <el-table-column prop="email" label="邮箱" />
        <el-table-column prop="nickname" label="昵称" />
        <el-table-column prop="conversation_count" label="对话数" />
        <el-table-column prop="last_active" label="最后活跃">
          <template #default="{ row }">
            {{ formatDate(row.last_active) }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/api'

const stats = ref({
  total_users: 0,
  total_conversations: 0,
  total_tokens: 0,
  total_revenue: 0,
  today_users: 0,
  today_conversations: 0,
  today_tokens: 0,
  today_revenue: 0,
})

const modelRanking = ref([])
const activeUsers = ref([])

onMounted(async () => {
  await Promise.all([
    fetchStats(),
    fetchModelRanking(),
    fetchActiveUsers(),
  ])
})

async function fetchStats() {
  try {
    const response = await api.get('/api/admin/statistics')
    stats.value = response.data
  } catch {
    // 忽略错误
  }
}

async function fetchModelRanking() {
  try {
    const response = await api.get('/api/admin/statistics/model-ranking')
    modelRanking.value = response.data
  } catch {
    // 忽略错误
  }
}

async function fetchActiveUsers() {
  try {
    const response = await api.get('/api/admin/statistics/active-users')
    activeUsers.value = response.data
  } catch {
    // 忽略错误
  }
}

function formatTokens(tokens: number) {
  if (!tokens) return '0'
  if (tokens >= 1000000) {
    return (tokens / 1000000).toFixed(1) + 'M'
  }
  if (tokens >= 1000) {
    return (tokens / 1000).toFixed(1) + 'K'
  }
  return tokens.toString()
}

function formatDate(dateStr: string) {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.admin-statistics {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.stat-card {
  display: flex;
  align-items: center;
  padding: 20px;
}

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 16px;
  width: 100%;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.stat-info {
  flex: 1;
}

.stat-value {
  font-size: 24px;
  font-weight: bold;
  color: #303133;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-top: 4px;
}
</style>
