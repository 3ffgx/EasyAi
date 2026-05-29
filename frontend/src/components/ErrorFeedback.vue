<template>
  <!-- 日志终端按钮 -->
  <div class="log-terminal-btn" @click="showLogTerminal = true">
    <el-badge :value="errorCount" :hidden="errorCount === 0" type="danger">
      <el-icon :size="20"><Document /></el-icon>
    </el-badge>
    <span>日志</span>
  </div>

  <!-- 日志终端弹窗 -->
  <el-drawer
    v-model="showLogTerminal"
    title="日志终端"
    direction="btt"
    size="400px"
    :before-close="handleClose"
  >
    <template #header>
      <div class="log-header">
        <span class="log-title">日志终端</span>
        <div class="log-actions">
          <el-button size="small" @click="clearLogs">清空</el-button>
          <el-button size="small" @click="exportLogs">导出</el-button>
          <el-button size="small" type="primary" @click="feedbackAll">
            一键反馈
          </el-button>
        </div>
      </div>
    </template>

    <div class="log-filter">
      <el-checkbox-group v-model="logFilters">
        <el-checkbox label="error" value="error">错误</el-checkbox>
        <el-checkbox label="warn" value="warn">警告</el-checkbox>
        <el-checkbox label="info" value="info">信息</el-checkbox>
        <el-checkbox label="debug" value="debug">调试</el-checkbox>
      </el-checkbox-group>
    </div>

    <div class="log-content" ref="logContentRef">
      <div
        v-for="(log, index) in filteredLogs"
        :key="index"
        :class="['log-item', log.type]"
      >
        <span class="log-time">{{ log.time }}</span>
        <span class="log-type">[{{ log.type.toUpperCase() }}]</span>
        <span class="log-message">{{ log.message }}</span>
        <el-button
          v-if="log.type === 'error'"
          type="danger"
          link
          size="small"
          @click="feedbackLog(log)"
        >
          反馈
        </el-button>
      </div>
      <div v-if="filteredLogs.length === 0" class="empty-logs">
        暂无日志
      </div>
    </div>
  </el-drawer>

  <!-- 反馈弹窗 -->
  <el-dialog v-model="showFeedbackDialog" title="问题反馈" width="500px">
    <el-form :model="feedbackForm" label-width="80px">
      <el-form-item label="问题描述">
        <el-input
          v-model="feedbackForm.description"
          type="textarea"
          :rows="3"
          placeholder="请描述您遇到的问题（可选）"
        />
      </el-form-item>
      <el-form-item label="日志信息">
        <el-input
          v-model="feedbackForm.logs"
          type="textarea"
          :rows="6"
          readonly
        />
      </el-form-item>
      <el-form-item label="系统信息">
        <el-input :value="systemInfo" readonly />
      </el-form-item>
    </el-form>
    <template #footer>
      <el-button @click="showFeedbackDialog = false">取消</el-button>
      <el-button type="primary" @click="submitFeedback">提交反馈</el-button>
    </template>
  </el-dialog>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { ElMessage } from 'element-plus'

interface LogEntry {
  type: 'error' | 'warn' | 'info' | 'debug'
  message: string
  time: string
  stack?: string
}

const showLogTerminal = ref(false)
const showFeedbackDialog = ref(false)
const logs = ref<LogEntry[]>([])
const logFilters = ref(['error', 'warn', 'info'])
const logContentRef = ref<HTMLElement>()
const errorCount = ref(0)

const feedbackForm = ref({
  description: '',
  logs: '',
})

const systemInfo = computed(() => {
  return `浏览器: ${navigator.userAgent} | 屏幕: ${window.screen.width}x${window.screen.height} | 时间: ${new Date().toLocaleString()}`
})

const filteredLogs = computed(() => {
  return logs.value.filter((log) => logFilters.value.includes(log.type))
})

// 拦截 console 输出
const originalConsole = {
  error: console.error,
  warn: console.warn,
  info: console.info,
  log: console.log,
}

function addLog(type: LogEntry['type'], message: string, stack?: string) {
  const now = new Date()
  const time = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}`

  logs.value.push({ type, message, time, stack })

  // 限制日志数量
  if (logs.value.length > 1000) {
    logs.value = logs.value.slice(-500)
  }

  if (type === 'error') {
    errorCount.value++
  }

  // 自动滚动到底部
  nextTick(() => {
    if (logContentRef.value) {
      logContentRef.value.scrollTop = logContentRef.value.scrollHeight
    }
  })
}

// 拦截全局错误
function handleError(event: ErrorEvent) {
  addLog('error', event.message, event.error?.stack)
}

function handleUnhandledRejection(event: PromiseRejectionEvent) {
  addLog('error', `Unhandled Promise: ${event.reason}`)
}

onMounted(() => {
  // 重写 console 方法
  console.error = (...args) => {
    originalConsole.error(...args)
    addLog('error', args.map(String).join(' '))
  }
  console.warn = (...args) => {
    originalConsole.warn(...args)
    addLog('warn', args.map(String).join(' '))
  }
  console.info = (...args) => {
    originalConsole.info(...args)
    addLog('info', args.map(String).join(' '))
  }
  console.log = (...args) => {
    originalConsole.log(...args)
    addLog('debug', args.map(String).join(' '))
  }

  // 监听全局错误
  window.addEventListener('error', handleError)
  window.addEventListener('unhandledrejection', handleUnhandledRejection)
})

onUnmounted(() => {
  // 恢复 console
  console.error = originalConsole.error
  console.warn = originalConsole.warn
  console.info = originalConsole.info
  console.log = originalConsole.log

  window.removeEventListener('error', handleError)
  window.removeEventListener('unhandledrejection', handleUnhandledRejection)
})

function clearLogs() {
  logs.value = []
  errorCount.value = 0
}

function exportLogs() {
  const logText = logs.value
    .map((log) => `[${log.time}] [${log.type.toUpperCase()}] ${log.message}${log.stack ? '\n' + log.stack : ''}`)
    .join('\n')

  const blob = new Blob([logText], { type: 'text/plain' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `easyai-logs-${new Date().toISOString().slice(0, 10)}.txt`
  a.click()
  URL.revokeObjectURL(url)
}

function feedbackLog(log: LogEntry) {
  feedbackForm.value = {
    description: '',
    logs: `[${log.time}] [${log.type.toUpperCase()}] ${log.message}${log.stack ? '\n' + log.stack : ''}`,
  }
  showFeedbackDialog.value = true
}

function feedbackAll() {
  const errorLogs = logs.value.filter((log) => log.type === 'error')
  feedbackForm.value = {
    description: '',
    logs: errorLogs
      .map((log) => `[${log.time}] [${log.type.toUpperCase()}] ${log.message}${log.stack ? '\n' + log.stack : ''}`)
      .join('\n'),
  }
  showFeedbackDialog.value = true
}

async function submitFeedback() {
  try {
    // TODO: 发送到服务器
    // await api.post('/api/feedback', {
    //   description: feedbackForm.value.description,
    //   logs: feedbackForm.value.logs,
    //   system_info: systemInfo.value,
    // })

    ElMessage.success('反馈已提交，感谢您的反馈！')
    showFeedbackDialog.value = false
    feedbackForm.value = { description: '', logs: '' }
  } catch {
    ElMessage.error('反馈提交失败，请重试')
  }
}

function handleClose() {
  showLogTerminal.value = false
}
</script>

<style scoped>
.log-terminal-btn {
  position: fixed;
  bottom: 20px;
  right: 20px;
  background: #303133;
  color: white;
  padding: 8px 16px;
  border-radius: 20px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 14px;
  z-index: 1000;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.3);
  transition: all 0.3s;
}

.log-terminal-btn:hover {
  background: #409eff;
  transform: scale(1.05);
}

.log-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.log-title {
  font-size: 16px;
  font-weight: bold;
}

.log-actions {
  display: flex;
  gap: 8px;
}

.log-filter {
  margin-bottom: 12px;
  padding: 8px;
  background: #f5f7fa;
  border-radius: 4px;
}

.log-content {
  height: 280px;
  overflow-y: auto;
  background: #1e1e1e;
  border-radius: 4px;
  padding: 12px;
  font-family: 'Consolas', 'Monaco', monospace;
  font-size: 12px;
  line-height: 1.6;
}

.log-item {
  margin-bottom: 4px;
  display: flex;
  align-items: flex-start;
  gap: 8px;
}

.log-time {
  color: #6a9955;
  white-space: nowrap;
}

.log-type {
  white-space: nowrap;
  font-weight: bold;
}

.log-item.error .log-type {
  color: #f44747;
}

.log-item.warn .log-type {
  color: #cca700;
}

.log-item.info .log-type {
  color: #569cd6;
}

.log-item.debug .log-type {
  color: #808080;
}

.log-message {
  flex: 1;
  color: #d4d4d4;
  word-break: break-all;
}

.empty-logs {
  text-align: center;
  color: #6a9955;
  padding: 20px;
}
</style>
