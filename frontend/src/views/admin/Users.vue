<template>
  <div class="admin-users">
    <!-- 搜索筛选 -->
    <el-card class="filter-card">
      <el-form :inline="true" :model="filterForm">
        <el-form-item label="关键词">
          <el-input v-model="filterForm.keyword" placeholder="邮箱/昵称" clearable />
        </el-form-item>
        <el-form-item label="角色">
          <el-select v-model="filterForm.role" placeholder="全部角色" clearable>
            <el-option label="全部" value="" />
            <el-option label="普通用户" value="user" />
            <el-option label="管理员" value="admin" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filterForm.is_active" placeholder="全部状态" clearable>
            <el-option label="全部" value="" />
            <el-option label="启用" :value="true" />
            <el-option label="禁用" :value="false" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="fetchUsers">查询</el-button>
          <el-button @click="resetFilter">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 用户列表 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>用户列表</span>
          <div>
            <el-button type="success" @click="exportUsers">导出</el-button>
          </div>
        </div>
      </template>

      <el-table :data="users" style="width: 100%" v-loading="loading">
        <el-table-column prop="email" label="邮箱" min-width="200" />
        <el-table-column prop="nickname" label="昵称" width="120" />
        <el-table-column prop="role" label="角色" width="100">
          <template #default="{ row }">
            <el-tag :type="row.role === 'admin' ? 'danger' : 'info'">
              {{ row.role === 'admin' ? '管理员' : '用户' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="tier_id" label="套餐" width="100">
          <template #default="{ row }">
            <el-tag>{{ row.tier_id || 'Free' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="balance" label="余额" width="100">
          <template #default="{ row }">
            ¥{{ row.balance.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="is_active" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_active ? 'success' : 'danger'">
              {{ row.is_active ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="注册时间" width="180">
          <template #default="{ row }">
            {{ formatDate(row.created_at) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="250" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="showUserDetail(row)">
              详情
            </el-button>
            <el-button
              :type="row.is_active ? 'warning' : 'success'"
              link
              @click="toggleUserStatus(row)"
            >
              {{ row.is_active ? '禁用' : '启用' }}
            </el-button>
            <el-button type="info" link @click="showChangeTier(row)">
              改套餐
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :page-sizes="[20, 50, 100]"
        :total="total"
        layout="total, sizes, prev, pager, next, jumper"
        @size-change="fetchUsers"
        @current-change="fetchUsers"
        style="margin-top: 16px; justify-content: flex-end"
      />
    </el-card>

    <!-- 用户详情弹窗 -->
    <el-dialog v-model="showDetailDialog" title="用户详情" width="600px">
      <el-descriptions :column="2" border>
        <el-descriptions-item label="邮箱">{{ currentUser?.email }}</el-descriptions-item>
        <el-descriptions-item label="昵称">{{ currentUser?.nickname }}</el-descriptions-item>
        <el-descriptions-item label="角色">{{ currentUser?.role === 'admin' ? '管理员' : '用户' }}</el-descriptions-item>
        <el-descriptions-item label="套餐">{{ currentUser?.tier_id || 'Free' }}</el-descriptions-item>
        <el-descriptions-item label="余额">¥{{ currentUser?.balance.toFixed(2) }}</el-descriptions-item>
        <el-descriptions-item label="状态">{{ currentUser?.is_active ? '启用' : '禁用' }}</el-descriptions-item>
        <el-descriptions-item label="注册时间" :span="2">{{ formatDate(currentUser?.created_at) }}</el-descriptions-item>
      </el-descriptions>

      <h4 style="margin: 16px 0 8px">使用统计</h4>
      <el-descriptions :column="2" border>
        <el-descriptions-item label="总使用量">{{ userStats?.total_tokens?.toLocaleString() || 0 }} Tokens</el-descriptions-item>
        <el-descriptions-item label="总花费">¥{{ userStats?.total_cost?.toFixed(2) || '0.00' }}</el-descriptions-item>
        <el-descriptions-item label="今日使用">{{ userStats?.today_tokens?.toLocaleString() || 0 }} Tokens</el-descriptions-item>
        <el-descriptions-item label="本月使用">{{ userStats?.month_tokens?.toLocaleString() || 0 }} Tokens</el-descriptions-item>
      </el-descriptions>
    </el-dialog>

    <!-- 修改套餐弹窗 -->
    <el-dialog v-model="showTierDialog" title="修改套餐" width="400px">
      <el-form :model="tierForm" label-width="80px">
        <el-form-item label="用户">
          <el-input :value="currentUser?.email" disabled />
        </el-form-item>
        <el-form-item label="套餐">
          <el-select v-model="tierForm.tier_id" style="width: 100%">
            <el-option label="Free" value="free" />
            <el-option label="Basic" value="basic" />
            <el-option label="Pro" value="pro" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showTierDialog = false">取消</el-button>
        <el-button type="primary" @click="changeTier">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/api'
import { ElMessage, ElMessageBox } from 'element-plus'

const loading = ref(false)
const users = ref([])
const currentPage = ref(1)
const pageSize = ref(20)
const total = ref(0)

const filterForm = ref({
  keyword: '',
  role: '',
  is_active: '',
})

const showDetailDialog = ref(false)
const showTierDialog = ref(false)
const currentUser = ref<any>(null)
const userStats = ref<any>(null)

const tierForm = ref({
  tier_id: '',
})

onMounted(() => {
  fetchUsers()
})

async function fetchUsers() {
  loading.value = true
  try {
    const params: any = {
      page: currentPage.value,
      page_size: pageSize.value,
    }
    if (filterForm.value.keyword) params.keyword = filterForm.value.keyword
    if (filterForm.value.role) params.role = filterForm.value.role
    if (filterForm.value.is_active !== '') params.is_active = filterForm.value.is_active

    const response = await api.get('/api/admin/users', { params })
    users.value = response.data.items
    total.value = response.data.total
  } finally {
    loading.value = false
  }
}

function resetFilter() {
  filterForm.value = { keyword: '', role: '', is_active: '' }
  fetchUsers()
}

function formatDate(dateStr: string) {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}

async function showUserDetail(user: any) {
  currentUser.value = user
  showDetailDialog.value = true

  try {
    const response = await api.get(`/api/admin/users/${user.id}/stats`)
    userStats.value = response.data
  } catch {
    userStats.value = null
  }
}

async function toggleUserStatus(user: any) {
  const action = user.is_active ? '禁用' : '启用'
  await ElMessageBox.confirm(`确定要${action}用户 ${user.email} 吗？`, '确认', {
    type: 'warning',
  })

  try {
    await api.put(`/api/admin/users/${user.id}`, {
      is_active: !user.is_active,
    })
    user.is_active = !user.is_active
    ElMessage.success(`已${action}`)
  } catch {
    ElMessage.error(`${action}失败`)
  }
}

function showChangeTier(user: any) {
  currentUser.value = user
  tierForm.value.tier_id = user.tier_id || 'free'
  showTierDialog.value = true
}

async function changeTier() {
  try {
    await api.put(`/api/admin/users/${currentUser.value.id}`, {
      tier_id: tierForm.value.tier_id,
    })
    currentUser.value.tier_id = tierForm.value.tier_id
    showTierDialog.value = false
    ElMessage.success('套餐已更新')
    fetchUsers()
  } catch {
    ElMessage.error('更新失败')
  }
}

function exportUsers() {
  ElMessage.info('导出功能开发中...')
}
</script>

<style scoped>
.admin-users {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.filter-card {
  margin-bottom: 0;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
</style>
