<template>
  <div class="chat-container">
    <!-- 对话列表侧边栏 -->
    <div class="conversation-sidebar">
      <div class="sidebar-header">
        <el-button type="primary" @click="createNewChat" style="width: 100%">
          <el-icon><Plus /></el-icon>
          新建对话
        </el-button>
      </div>

      <div class="conversation-list">
        <div
          v-for="conv in chatStore.conversations"
          :key="conv.id"
          :class="['conversation-item', { active: chatStore.currentConversation?.id === conv.id }]"
          @click="selectConversation(conv)"
        >
          <div class="conv-info">
            <div class="conv-title">{{ conv.title || '新对话' }}</div>
            <div class="conv-meta">
              <span class="conv-model">{{ getModelName(conv.model_id) }}</span>
              <span class="conv-time">{{ formatTime(conv.last_message_at || conv.updated_at || conv.created_at) }}</span>
            </div>
            <div class="conv-stats">{{ conv.message_count || 0 }} 条消息</div>
          </div>
          <el-button
            type="danger"
            link
            @click.stop="deleteConversation(conv.id)"
          >
            <el-icon><Delete /></el-icon>
          </el-button>
        </div>
      </div>
    </div>

    <!-- 聊天区域 -->
    <div class="chat-main">
      <!-- 顶部栏 -->
      <div class="chat-header">
        <el-select
          v-model="chatStore.selectedModel"
          placeholder="选择模型"
          style="width: 200px"
        >
          <el-option
            v-for="model in availableModels"
            :key="model.id"
            :label="model.name"
            :value="model.id"
          />
        </el-select>
      </div>

      <!-- 消息列表 -->
      <div class="message-list" ref="messageListRef">
        <div v-if="chatStore.messages.length === 0" class="empty-state">
          <el-icon :size="64" color="#c0c4cc"><ChatLineRound /></el-icon>
          <p>开始新的对话</p>
        </div>

        <div
          v-for="msg in chatStore.messages"
          :key="msg.id"
          :class="['message', msg.role]"
        >
          <div class="message-avatar">
            <el-avatar :size="36" :icon="msg.role === 'user' ? 'User' : 'Service'" />
          </div>
          <div class="message-content">
            <!-- 思考过程（可折叠） -->
            <div v-if="msg.reasoning" class="reasoning-section">
              <el-collapse>
                <el-collapse-item title="思考过程" name="reasoning">
                  <div class="reasoning-text">{{ msg.reasoning }}</div>
                </el-collapse-item>
              </el-collapse>
            </div>
            <!-- 回答内容（Markdown 渲染） -->
            <div class="message-text">
              <MarkdownRenderer :content="msg.content" />
            </div>
            <div class="message-meta">
              <span v-if="msg.tokens_used">{{ msg.tokens_used }} tokens</span>
            </div>
          </div>
        </div>

        <!-- 流式消息（正在生成） -->
        <div v-if="chatStore.isLoading" class="message assistant">
          <div class="message-avatar">
            <el-avatar :size="36" icon="Service" />
          </div>
          <div class="message-content">
            <!-- 思考过程（可折叠） -->
            <div v-if="chatStore.streamingReasoning" class="reasoning-section">
              <el-collapse>
                <el-collapse-item title="正在思考..." name="reasoning">
                  <div class="reasoning-text">{{ chatStore.streamingReasoning }}</div>
                </el-collapse-item>
              </el-collapse>
            </div>
            <!-- 回答内容（Markdown 渲染） -->
            <div v-if="chatStore.streamingMessage" class="message-text">
              <MarkdownRenderer :content="chatStore.streamingMessage" />
            </div>
            <!-- 加载状态 -->
            <div v-if="!chatStore.streamingMessage && !chatStore.streamingReasoning" class="typing-indicator">
              <span></span>
              <span></span>
              <span></span>
            </div>
            <!-- 停止按钮 -->
            <div class="message-actions">
              <el-button
                type="danger"
                size="small"
                @click="stopGeneration"
              >
                <el-icon><VideoPause /></el-icon>
                停止生成
              </el-button>
            </div>
          </div>
        </div>
      </div>

      <!-- 输入区域 -->
      <div class="input-area">
        <el-input
          v-model="inputMessage"
          type="textarea"
          :rows="3"
          placeholder="输入消息... (Enter 发送, Shift+Enter 换行)"
          resize="none"
          @keydown="handleKeydown"
          :disabled="chatStore.isLoading"
        />
        <el-button
          type="primary"
          :loading="chatStore.isLoading"
          @click="sendMessage"
          :disabled="!inputMessage.trim()"
        >
          发送
        </el-button>
      </div>
    </div>

    <!-- 对话索引侧边栏 -->
    <div class="index-sidebar" v-if="userQuestions.length > 0">
      <div class="index-header">
        <span>对话索引</span>
        <el-button link @click="showIndex = !showIndex">
          <el-icon><Fold v-if="showIndex" /><Expand v-else /></el-icon>
        </el-button>
      </div>
      <div class="index-list" v-show="showIndex">
        <div
          v-for="(item, index) in userQuestions"
          :key="index"
          class="index-item"
          @click="scrollToQuestion(index)"
        >
          <div class="index-number">{{ index + 1 }}</div>
          <div class="index-text">{{ item.question }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useChatStore } from '@/stores/chat'
import { ElMessage, ElMessageBox } from 'element-plus'
import MarkdownRenderer from '@/components/MarkdownRenderer.vue'
import api from '@/api'

const chatStore = useChatStore()
const inputMessage = ref('')
const messageListRef = ref<HTMLElement>()
const showIndex = ref(true)

// 可用模型列表
const availableModels = ref<{ id: string; name: string }[]>([])

// 用户问题列表（对话索引）
const userQuestions = computed(() => {
  return chatStore.messages
    .filter(msg => msg.role === 'user')
    .map((msg, index) => ({
      question: msg.content.length > 30 ? msg.content.substring(0, 30) + '...' : msg.content,
      fullContent: msg.content,
      index: index,
    }))
})

// 滚动到指定问题
function scrollToQuestion(index: number) {
  const messageElements = messageListRef.value?.querySelectorAll('.message.user')
  if (messageElements && messageElements[index]) {
    messageElements[index].scrollIntoView({ behavior: 'smooth', block: 'center' })
  }
}

// 获取模型显示名称
function getModelName(modelId: string): string {
  const model = availableModels.value.find(m => m.id === modelId)
  return model?.name || modelId
}

// 格式化时间
function formatTime(dateStr: string | undefined): string {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - date.getTime()

  // 今天内显示时间
  if (diff < 24 * 60 * 60 * 1000 && date.getDate() === now.getDate()) {
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  }

  // 昨天
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  if (date.getDate() === yesterday.getDate() && date.getMonth() === yesterday.getMonth()) {
    return '昨天'
  }

  // 今年内显示月日
  if (date.getFullYear() === now.getFullYear()) {
    return `${date.getMonth() + 1}月${date.getDate()}日`
  }

  // 其他显示年月日
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
}

onMounted(async () => {
  await chatStore.fetchConversations()
  await fetchModels()
})

async function fetchModels() {
  try {
    const response = await api.get('/api/models')
    availableModels.value = response.data
    // 如果当前选择的模型不在列表中，选择第一个
    if (availableModels.value.length > 0 && !availableModels.value.find(m => m.id === chatStore.selectedModel)) {
      chatStore.selectedModel = availableModels.value[0].id
    }
  } catch (error) {
    console.error('获取模型列表失败:', error)
  }
}

// 监听消息变化，自动滚动到底部
watch(
  () => [chatStore.messages.length, chatStore.streamingMessage],
  () => {
    nextTick(() => {
      if (messageListRef.value) {
        messageListRef.value.scrollTop = messageListRef.value.scrollHeight
      }
    })
  }
)

async function createNewChat() {
  await chatStore.createConversation()
}

async function selectConversation(conv: any) {
  await chatStore.selectConversation(conv)
}

async function deleteConversation(id: string) {
  await ElMessageBox.confirm('确定删除这个对话吗？', '确认', {
    type: 'warning',
  })
  await chatStore.deleteConversation(id)
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    sendMessage()
  }
}

async function sendMessage() {
  const content = inputMessage.value.trim()
  if (!content || chatStore.isLoading) return

  inputMessage.value = ''
  try {
    await chatStore.sendMessage(content)
  } catch (error) {
    ElMessage.error('发送失败，请重试')
  }
}

function stopGeneration() {
  chatStore.cancelRequest()
}
</script>

<style scoped>
.chat-container {
  display: flex;
  height: calc(100vh - 112px);
  background: white;
  border-radius: 8px;
  overflow: hidden;
}

.conversation-sidebar {
  width: 280px;
  border-right: 1px solid #e8e8e8;
  display: flex;
  flex-direction: column;
}

.sidebar-header {
  padding: 16px;
  border-bottom: 1px solid #e8e8e8;
}

.conversation-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}

.conversation-item {
  display: flex;
  align-items: center;
  padding: 12px;
  border-radius: 8px;
  cursor: pointer;
  margin-bottom: 4px;
}

.conversation-item:hover {
  background: #f5f7fa;
}

.conversation-item.active {
  background: #ecf5ff;
}

.conv-info {
  flex: 1;
  min-width: 0;
}

.conv-title {
  font-size: 14px;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-bottom: 4px;
}

.conv-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.conv-model {
  font-size: 11px;
  color: #909399;
  background: #f0f0f0;
  padding: 1px 6px;
  border-radius: 4px;
}

.conv-time {
  font-size: 11px;
  color: #909399;
}

.conv-stats {
  font-size: 11px;
  color: #c0c4cc;
  margin-top: 2px;
}

.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.chat-header {
  padding: 12px 16px;
  border-bottom: 1px solid #e8e8e8;
}

.message-list {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}

.empty-state {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #909399;
}

.empty-state p {
  margin-top: 16px;
  font-size: 16px;
}

.message {
  display: flex;
  gap: 12px;
  margin-bottom: 24px;
}

.message.user {
  flex-direction: row-reverse;
}

.message-content {
  max-width: 70%;
}

.message.user .message-content {
  text-align: right;
}

.message-text {
  padding: 12px 16px;
  border-radius: 12px;
  font-size: 14px;
  line-height: 1.6;
  word-break: break-word;
  overflow: hidden;
}

.message.assistant .message-text {
  background: #f5f7fa;
  color: #303133;
}

.message.user .message-text {
  background: #409eff;
  color: white;
}

.message-meta {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
}

.message-actions {
  margin-top: 8px;
}

.reasoning-section {
  margin-bottom: 8px;
}

.reasoning-section :deep(.el-collapse-item__header) {
  font-size: 12px;
  color: #909399;
  background: #f0f0f0;
  padding: 0 12px;
  height: 32px;
  line-height: 32px;
  border-radius: 4px;
}

.reasoning-section :deep(.el-collapse-item__content) {
  padding: 0;
}

.reasoning-text {
  font-size: 12px;
  color: #606266;
  background: #f5f5f5;
  padding: 8px 12px;
  border-radius: 4px;
  white-space: pre-wrap;
  line-height: 1.5;
  max-height: 200px;
  overflow-y: auto;
}

.typing-indicator {
  display: flex;
  gap: 4px;
  padding: 12px 16px;
  background: #f5f7fa;
  border-radius: 12px;
}

.typing-indicator span {
  width: 8px;
  height: 8px;
  background: #c0c4cc;
  border-radius: 50%;
  animation: typing 1.4s infinite both;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typing {
  0%, 100% {
    opacity: 0.3;
    transform: scale(0.8);
  }
  50% {
    opacity: 1;
    transform: scale(1);
  }
}

.input-area {
  padding: 16px;
  border-top: 1px solid #e8e8e8;
  display: flex;
  gap: 12px;
  align-items: flex-end;
}

.input-area .el-textarea {
  flex: 1;
}

/* 对话索引样式 */
.index-sidebar {
  width: 240px;
  border-left: 1px solid #e8e8e8;
  background: #fafafa;
  display: flex;
  flex-direction: column;
}

.index-header {
  padding: 12px 16px;
  border-bottom: 1px solid #e8e8e8;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 600;
  font-size: 14px;
}

.index-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}

.index-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 8px 12px;
  border-radius: 6px;
  cursor: pointer;
  margin-bottom: 4px;
  transition: background 0.2s;
}

.index-item:hover {
  background: #ecf5ff;
}

.index-number {
  min-width: 20px;
  height: 20px;
  background: #409eff;
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 600;
}

.index-text {
  font-size: 12px;
  color: #606266;
  line-height: 1.4;
  word-break: break-all;
}
</style>
