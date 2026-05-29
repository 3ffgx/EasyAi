<template>
  <div class="admin-settings">
    <!-- 套餐管理 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>套餐管理</span>
          <el-button type="primary" @click="showTierDialog = true">添加套餐</el-button>
        </div>
      </template>

      <el-table :data="tiers" style="width: 100%">
        <el-table-column prop="id" label="ID" width="100" />
        <el-table-column prop="name" label="名称" width="120" />
        <el-table-column prop="monthly_price" label="月费" width="100">
          <template #default="{ row }">
            ¥{{ row.monthly_price.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="free_quota" label="免费额度" width="120">
          <template #default="{ row }">
            {{ formatTokens(row.free_quota) }}
          </template>
        </el-table-column>
        <el-table-column prop="overage_rate" label="超出单价" width="120">
          <template #default="{ row }">
            ¥{{ row.overage_rate.toFixed(4) }}/1K
          </template>
        </el-table-column>
        <el-table-column prop="is_active" label="状态" width="80">
          <template #default="{ row }">
            <el-tag :type="row.is_active ? 'success' : 'info'">
              {{ row.is_active ? '启用' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-button type="primary" link @click="editTier(row)">编辑</el-button>
            <el-button type="danger" link @click="deleteTier(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 系统公告 -->
    <el-card>
      <template #header>
        <span>系统公告</span>
      </template>
      <el-form :model="announcementForm" label-width="80px">
        <el-form-item label="标题">
          <el-input v-model="announcementForm.title" placeholder="公告标题" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input
            v-model="announcementForm.content"
            type="textarea"
            :rows="4"
            placeholder="公告内容"
          />
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="announcementForm.type">
            <el-option label="通知" value="info" />
            <el-option label="警告" value="warning" />
            <el-option label="紧急" value="error" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="publishAnnouncement">发布公告</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 全局配置 -->
    <el-card>
      <template #header>
        <span>全局配置</span>
      </template>
      <el-form :model="globalConfig" label-width="120px">
        <el-form-item label="最大上下文轮数">
          <el-input-number v-model="globalConfig.max_context_turns" :min="1" :max="50" />
        </el-form-item>
        <el-form-item label="单次最大 Token">
          <el-input-number v-model="globalConfig.max_tokens_per_message" :min="100" :max="32000" :step="100" />
        </el-form-item>
        <el-form-item label="每日免费额度">
          <el-input-number v-model="globalConfig.daily_free_tokens" :min="0" :step="1000" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="saveGlobalConfig">保存配置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <!-- 套餐弹窗 -->
    <el-dialog
      v-model="showTierDialog"
      :title="isEditTier ? '编辑套餐' : '添加套餐'"
      width="400px"
    >
      <el-form :model="tierForm" label-width="80px">
        <el-form-item label="ID">
          <el-input v-model="tierForm.id" :disabled="isEditTier" placeholder="如 basic" />
        </el-form-item>
        <el-form-item label="名称">
          <el-input v-model="tierForm.name" placeholder="如 基础版" />
        </el-form-item>
        <el-form-item label="月费">
          <el-input-number v-model="tierForm.monthly_price" :min="0" :precision="2" />
        </el-form-item>
        <el-form-item label="免费额度">
          <el-input-number v-model="tierForm.free_quota" :min="0" :step="1000" />
        </el-form-item>
        <el-form-item label="超出单价">
          <el-input-number v-model="tierForm.overage_rate" :min="0" :precision="4" :step="0.001" />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="tierForm.is_active" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showTierDialog = false">取消</el-button>
        <el-button type="primary" @click="saveTier">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/api'
import { ElMessage, ElMessageBox } from 'element-plus'

const tiers = ref([])
const showTierDialog = ref(false)
const isEditTier = ref(false)

const tierForm = ref({
  id: '',
  name: '',
  monthly_price: 0,
  free_quota: 0,
  overage_rate: 0,
  is_active: true,
})

const announcementForm = ref({
  title: '',
  content: '',
  type: 'info',
})

const globalConfig = ref({
  max_context_turns: 20,
  max_tokens_per_message: 4096,
  daily_free_tokens: 10000,
})

onMounted(async () => {
  await Promise.all([
    fetchTiers(),
    fetchGlobalConfig(),
  ])
})

async function fetchTiers() {
  try {
    const response = await api.get('/api/admin/tiers')
    tiers.value = response.data
  } catch {
    // 忽略错误
  }
}

async function fetchGlobalConfig() {
  try {
    const response = await api.get('/api/admin/config')
    globalConfig.value = { ...globalConfig.value, ...response.data }
  } catch {
    // 忽略错误
  }
}

function editTier(tier: any) {
  isEditTier.value = true
  tierForm.value = { ...tier }
  showTierDialog.value = true
}

async function saveTier() {
  try {
    if (isEditTier.value) {
      await api.put(`/api/admin/tiers/${tierForm.value.id}`, tierForm.value)
    } else {
      await api.post('/api/admin/tiers', tierForm.value)
    }
    ElMessage.success(isEditTier.value ? '套餐已更新' : '套餐已添加')
    showTierDialog.value = false
    fetchTiers()
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '操作失败')
  }
}

async function deleteTier(tier: any) {
  await ElMessageBox.confirm(`确定删除套餐 ${tier.name} 吗？`, '确认', {
    type: 'warning',
  })

  try {
    await api.delete(`/api/admin/tiers/${tier.id}`)
    ElMessage.success('套餐已删除')
    fetchTiers()
  } catch {
    ElMessage.error('删除失败')
  }
}

async function publishAnnouncement() {
  if (!announcementForm.value.title || !announcementForm.value.content) {
    ElMessage.warning('请填写标题和内容')
    return
  }

  try {
    await api.post('/api/admin/announcements', announcementForm.value)
    ElMessage.success('公告已发布')
    announcementForm.value = { title: '', content: '', type: 'info' }
  } catch {
    ElMessage.error('发布失败')
  }
}

async function saveGlobalConfig() {
  try {
    await api.put('/api/admin/config', globalConfig.value)
    ElMessage.success('配置已保存')
  } catch {
    ElMessage.error('保存失败')
  }
}

function formatTokens(tokens: number) {
  if (!tokens) return '0'
  if (tokens >= 1000000) {
    return (tokens / 1000000).toFixed(1) + 'M'
  }
  if (tokens >= 1000) {
    return (tokens / 1000).toFixed(0) + 'K'
  }
  return tokens.toString()
}
</script>

<style scoped>
.admin-settings {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
</style>
