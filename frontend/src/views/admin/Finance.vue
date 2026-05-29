<template>
  <div class="admin-finance">
    <!-- 统计卡片 -->
    <el-row :gutter="24">
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-item">
            <div class="stat-label">本月收入</div>
            <div class="stat-value">¥{{ monthRevenue.toFixed(2) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-item">
            <div class="stat-label">本月支出（Token 成本）</div>
            <div class="stat-value">¥{{ monthCost.toFixed(2) }}</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="hover">
          <div class="stat-item">
            <div class="stat-label">本月利润</div>
            <div class="stat-value" :style="{ color: monthProfit >= 0 ? '#67c23a' : '#f56c6c' }">
              ¥{{ monthProfit.toFixed(2) }}
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 筛选 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>交易记录</span>
          <div>
            <el-select v-model="filterType" placeholder="交易类型" clearable style="width: 120px; margin-right: 12px;">
              <el-option label="全部" value="" />
              <el-option label="充值" value="topup" />
              <el-option label="消费" value="usage" />
              <el-option label="退款" value="refund" />
            </el-select>
            <el-button type="primary" @click="fetchRecords">查询</el-button>
            <el-button @click="exportRecords">导出</el-button>
          </div>
        </div>
      </template>

      <el-table :data="records" style="width: 100%" v-loading="loading">
        <el-table-column prop="created_at" label="时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column prop="user_email" label="用户" min-width="200" show-overflow-tooltip />
        <el-table-column prop="type" label="类型" width="100">
          <template #default="{ row }">
            <el-tag :type="getTagType(row.type)">{{ getTypeName(row.type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="amount" label="金额" width="120">
          <template #default="{ row }">
            <span :style="{ color: row.type === 'usage' ? '#f56c6c' : '#67c23a' }">
              {{ row.type === 'usage' ? '-' : '+' }}¥{{ row.amount.toFixed(2) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="描述" min-width="200" show-overflow-tooltip />
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
import { ref, computed, onMounted } from 'vue'
import api from '@/api'
import { ElMessage } from 'element-plus'

const loading = ref(false)
const records = ref([])
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)
const filterType = ref('')

const monthRevenue = ref(0)
const monthCost = ref(0)
const monthProfit = computed(() => monthRevenue.value - monthCost.value)

onMounted(async () => {
  await Promise.all([
    fetchMonthStats(),
    fetchRecords(),
  ])
})

async function fetchMonthStats() {
  try {
    const response = await api.get('/api/admin/finance/month-stats')
    monthRevenue.value = response.data.revenue || 0
    monthCost.value = response.data.cost || 0
  } catch {
    // 忽略错误
  }
}

async function fetchRecords() {
  loading.value = true
  try {
    const params: any = {
      page: currentPage.value,
      page_size: pageSize.value,
    }
    if (filterType.value) params.type = filterType.value

    const response = await api.get('/api/admin/finance/records', { params })
    records.value = response.data.items
    total.value = response.data.total
  } finally {
    loading.value = false
  }
}

function getTagType(type: string) {
  const map: Record<string, string> = {
    topup: 'success',
    usage: 'danger',
    refund: 'warning',
  }
  return map[type] || 'info'
}

function getTypeName(type: string) {
  const map: Record<string, string> = {
    topup: '充值',
    usage: '消费',
    refund: '退款',
  }
  return map[type] || type
}

function formatDate(dateStr: string) {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

function exportRecords() {
  ElMessage.info('导出功能开发中...')
}
</script>

<style scoped>
.admin-finance {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.stat-item {
  text-align: center;
  padding: 8px 0;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #303133;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
</style>
