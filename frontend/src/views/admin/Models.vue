<template>
  <div class="admin-models">
    <!-- 操作栏 -->
    <el-card>
      <template #header>
        <div class="card-header">
          <span>模型管理</span>
          <el-button type="primary" @click="showAddDialog">添加模型</el-button>
        </div>
      </template>

      <el-table :data="models" style="width: 100%" v-loading="loading">
        <el-table-column prop="id" label="模型 ID" width="180" />
        <el-table-column prop="name" label="显示名称" width="150" />
        <el-table-column prop="provider" label="提供商" width="100" />
        <el-table-column label="API Key" width="100">
          <template #default="{ row }">
            <el-tag :type="hasApiKey(row) ? 'success' : 'danger'" size="small">
              {{ hasApiKey(row) ? '已配置' : '未配置' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="验证状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.is_verified ? 'success' : 'warning'" size="small">
              {{ row.is_verified ? '已验证' : '未验证' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="api_base" label="API 地址" min-width="180" show-overflow-tooltip />
        <el-table-column prop="is_active" label="状态" width="80">
          <template #default="{ row }">
            <el-switch v-model="row.is_active" @change="toggleModel(row)" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="250" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="editModel(row)">编辑</el-button>
            <el-button type="success" link @click="testModel(row)" :disabled="!hasApiKey(row)">测试</el-button>
            <el-button type="danger" link @click="deleteModel(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 添加/编辑模型弹窗 -->
    <el-dialog
      v-model="showDialog"
      :title="isEdit ? '编辑模型' : '添加模型'"
      width="500px"
    >
      <el-form :model="modelForm" :rules="rules" ref="formRef" label-width="100px">
        <el-form-item label="模型 ID" prop="id">
          <el-input v-model="modelForm.id" :disabled="isEdit" placeholder="如 deepseek-v4-pro" />
        </el-form-item>
        <el-form-item label="显示名称" prop="name">
          <el-input v-model="modelForm.name" placeholder="如 DeepSeek V4 Pro" />
        </el-form-item>
        <el-form-item label="提供商" prop="provider">
          <el-select v-model="modelForm.provider" style="width: 100%">
            <el-option label="DeepSeek" value="deepseek" />
            <el-option label="OpenAI" value="openai" />
            <el-option label="Anthropic" value="anthropic" />
            <el-option label="其他" value="other" />
          </el-select>
        </el-form-item>
        <el-form-item label="API 地址" prop="api_base">
          <el-input v-model="modelForm.api_base" placeholder="https://api.deepseek.com" />
        </el-form-item>
        <el-form-item label="API Key" prop="api_key">
          <el-input v-model="modelForm.api_key" type="password" show-password placeholder="sk-..." />
        </el-form-item>
        <el-form-item label="启用">
          <el-switch v-model="modelForm.is_active" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showDialog = false">取消</el-button>
        <el-button type="primary" @click="saveModel">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import api from '@/api'
import { ElMessage, ElMessageBox } from 'element-plus'
import type { FormInstance, FormRules } from 'element-plus'

const loading = ref(false)
const models = ref([])
const showDialog = ref(false)
const isEdit = ref(false)
const formRef = ref<FormInstance>()

const modelForm = ref({
  id: '',
  name: '',
  provider: 'deepseek',
  api_base: '',
  api_key: '',
  is_active: true,
})

const rules: FormRules = {
  id: [{ required: true, message: '请输入模型 ID', trigger: 'blur' }],
  name: [{ required: true, message: '请输入显示名称', trigger: 'blur' }],
  provider: [{ required: true, message: '请选择提供商', trigger: 'change' }],
  api_base: [{ required: true, message: '请输入 API 地址', trigger: 'blur' }],
}

onMounted(() => {
  fetchModels()
})

async function fetchModels() {
  loading.value = true
  try {
    const response = await api.get('/api/admin/models')
    models.value = response.data
  } finally {
    loading.value = false
  }
}

function showAddDialog() {
  isEdit.value = false
  modelForm.value = {
    id: '',
    name: '',
    provider: 'deepseek',
    api_base: '',
    api_key: '',
    is_active: true,
  }
  showDialog.value = true
}

function editModel(model: any) {
  isEdit.value = true
  // 显示部分 key，如 sk-****1234
  let maskedKey = ''
  if (model.api_key && model.api_key.length > 8) {
    maskedKey = model.api_key.substring(0, 3) + '****' + model.api_key.substring(model.api_key.length - 4)
  }
  modelForm.value = {
    id: model.id,
    name: model.name,
    provider: model.provider,
    api_base: model.api_base,
    api_key: maskedKey,
    is_active: model.is_active,
  }
  showDialog.value = true
}

// 检查模型是否已配置 API Key
function hasApiKey(model: any) {
  return model.api_key && model.api_key.trim() !== ''
}

async function saveModel() {
  console.log('保存模型:', modelForm.value)

  // 手动验证必填字段
  if (!modelForm.value.id) {
    ElMessage.warning('请输入模型 ID')
    return
  }
  if (!modelForm.value.name) {
    ElMessage.warning('请输入显示名称')
    return
  }
  if (!modelForm.value.api_base) {
    ElMessage.warning('请输入 API 地址')
    return
  }

  try {
    if (isEdit.value) {
      console.log('编辑模型:', `/api/admin/models/${modelForm.value.id}`)
      await api.put(`/api/admin/models/${modelForm.value.id}`, modelForm.value)
    } else {
      console.log('添加模型:', '/api/admin/models')
      const response = await api.post('/api/admin/models', modelForm.value)
      console.log('添加成功:', response.data)
    }
    ElMessage.success(isEdit.value ? '模型已更新' : '模型已添加')
    showDialog.value = false
    fetchModels()
  } catch (error: any) {
    console.error('保存失败:', error)
    ElMessage.error(error.response?.data?.detail || '操作失败')
  }
}

async function toggleModel(model: any) {
  try {
    console.log('切换模型状态:', model.id, model.is_active)
    await api.put(`/api/admin/models/${model.id}`, {
      is_active: model.is_active,
      name: model.name,
      provider: model.provider,
      api_base: model.api_base,
    })
    ElMessage.success(model.is_active ? '模型已启用' : '模型已禁用')
    fetchModels() // 刷新列表
  } catch (error: any) {
    model.is_active = !model.is_active
    console.error('切换失败:', error)
    ElMessage.error(error.response?.data?.detail || '操作失败')
  }
}

async function testModel(model: any) {
  try {
    await api.post(`/api/admin/models/${model.id}/test`)
    ElMessage.success('模型测试通过')
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '模型测试失败')
  }
}

async function deleteModel(model: any) {
  await ElMessageBox.confirm(`确定删除模型 ${model.name} 吗？`, '确认', {
    type: 'warning',
  })

  try {
    await api.delete(`/api/admin/models/${model.id}`)
    ElMessage.success('模型已删除')
    fetchModels()
  } catch {
    ElMessage.error('删除失败')
  }
}
</script>

<style scoped>
.admin-models {
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
