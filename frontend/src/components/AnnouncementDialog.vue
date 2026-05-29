<template>
  <el-dialog
    v-model="visible"
    title="系统公告"
    width="500px"
    :close-on-click-modal="false"
    :close-on-press-escape="true"
    class="announcement-dialog"
  >
    <div v-if="announcements.length > 0" class="announcement-list">
      <div
        v-for="(item, index) in announcements"
        :key="item.id"
        class="announcement-item"
        :class="[`type-${item.type}`, { 'is-first': index === 0 }]"
      >
        <div class="announcement-header">
          <el-tag :type="getTagType(item.type)" size="small" effect="dark">
            {{ getTypeName(item.type) }}
          </el-tag>
          <span class="announcement-time">{{ formatTime(item.created_at) }}</span>
        </div>
        <h3 class="announcement-title">{{ item.title }}</h3>
        <div class="announcement-content">{{ item.content }}</div>
      </div>
    </div>
    <div v-else class="empty-state">
      <el-icon :size="48" color="#c0c4cc"><Bell /></el-icon>
      <p>暂无公告</p>
    </div>

    <template #footer>
      <div class="dialog-footer">
        <el-checkbox v-model="dontShowToday" class="dont-show">
          今日不再显示
        </el-checkbox>
        <el-button type="primary" @click="close">
          我知道了
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

const visible = ref(false)
const announcements = ref<any[]>([])
const dontShowToday = ref(false)

onMounted(() => {
  // 检查今日是否已关闭公告
  const today = new Date().toDateString()
  const lastClosed = localStorage.getItem('announcement_closed_date')
  if (lastClosed === today) {
    return
  }

  fetchAnnouncements()
})

async function fetchAnnouncements() {
  try {
    const token = localStorage.getItem('token')
    if (!token) return

    const response = await fetch('/api/auth/announcements', {
      headers: { Authorization: `Bearer ${token}` },
    })

    if (response.ok) {
      announcements.value = await response.json()
      if (announcements.value.length > 0) {
        visible.value = true
      }
    }
  } catch (error) {
    console.error('获取公告失败:', error)
  }
}

function close() {
  visible.value = false
  if (dontShowToday.value) {
    localStorage.setItem('announcement_closed_date', new Date().toDateString())
  }
}

function getTagType(type: string) {
  const map: Record<string, string> = {
    info: 'info',
    warning: 'warning',
    error: 'danger',
  }
  return map[type] || 'info'
}

function getTypeName(type: string) {
  const map: Record<string, string> = {
    info: '通知',
    warning: '警告',
    error: '紧急',
  }
  return map[type] || '通知'
}

function formatTime(dateStr: string) {
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.announcement-dialog :deep(.el-dialog__header) {
  border-bottom: 1px solid #e4e7ed;
  padding: 16px 20px;
  margin: 0;
}

.announcement-dialog :deep(.el-dialog__body) {
  padding: 20px;
  max-height: 400px;
  overflow-y: auto;
}

.announcement-dialog :deep(.el-dialog__footer) {
  border-top: 1px solid #e4e7ed;
  padding: 12px 20px;
  margin: 0;
}

.announcement-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.announcement-item {
  padding: 16px;
  background: #f8f9fa;
  border-radius: 8px;
  border-left: 4px solid #409eff;
  transition: all 0.3s;
}

.announcement-item:hover {
  background: #ecf5ff;
}

.announcement-item.type-warning {
  border-left-color: #e6a23c;
}

.announcement-item.type-error {
  border-left-color: #f56c6c;
}

.announcement-item.is-first {
  background: #ecf5ff;
}

.announcement-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.announcement-time {
  font-size: 12px;
  color: #909399;
}

.announcement-title {
  margin: 0 0 8px;
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.announcement-content {
  font-size: 14px;
  color: #606266;
  line-height: 1.6;
  white-space: pre-wrap;
}

.empty-state {
  text-align: center;
  padding: 40px 0;
  color: #909399;
}

.empty-state p {
  margin-top: 12px;
  font-size: 14px;
}

.dialog-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.dont-show {
  font-size: 13px;
  color: #909399;
}
</style>
