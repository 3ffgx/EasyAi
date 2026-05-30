<template>
  <div class="chat-container">
    <!-- 侧边栏 -->
    <aside class="sidebar" :class="{ collapsed: sidebarCollapsed }">
      <div class="sidebar-header">
        <button class="new-chat-btn" @click="createNewChat">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          <span v-show="!sidebarCollapsed">新对话</span>
        </button>
      </div>

      <div class="conversation-list" v-show="!sidebarCollapsed">
        <div
          v-for="conv in chatStore.conversations"
          :key="conv.id"
          class="conversation-item"
          :class="{ active: chatStore.currentConversation?.id === conv.id }"
          @click="selectConversation(conv)"
        >
          <div class="conv-icon">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
            </svg>
          </div>
          <div class="conv-info">
            <div class="conv-title">{{ conv.title || '新对话' }}</div>
            <div class="conv-meta">{{ getModelName(conv.model_id) }}</div>
          </div>
          <button class="conv-delete" @click.stop="deleteConversation(conv.id)">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
            </svg>
          </button>
        </div>
      </div>

      <div class="sidebar-footer" v-show="!sidebarCollapsed">
        <button class="sidebar-btn" @click="router.push('/usage')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
          </svg>
          使用量
        </button>
        <button class="sidebar-btn" @click="router.push('/settings')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="3"></circle>
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
          </svg>
          设置
        </button>
      </div>
    </aside>

    <!-- 主聊天区域 -->
    <main class="chat-main">
      <!-- 顶部栏 -->
      <header class="chat-header">
        <button class="toggle-sidebar" @click="sidebarCollapsed = !sidebarCollapsed">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="3" y1="12" x2="21" y2="12"></line>
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="18" x2="21" y2="18"></line>
          </svg>
        </button>

        <div class="model-selector">
          <select v-model="chatStore.selectedModel" class="model-select">
            <option v-for="model in availableModels" :key="model.id" :value="model.id">
              {{ model.name }}
            </option>
          </select>
        </div>

        <div class="header-actions">
          <button class="action-btn" @click="router.push('/dashboard')">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="3" width="7" height="7"></rect>
              <rect x="14" y="3" width="7" height="7"></rect>
              <rect x="14" y="14" width="7" height="7"></rect>
              <rect x="3" y="14" width="7" height="7"></rect>
            </svg>
          </button>
        </div>
      </header>

      <!-- 消息区域 -->
      <div class="messages-container" ref="messagesContainer">
        <!-- 空状态 -->
        <div v-if="chatStore.messages.length === 0 && !chatStore.isLoading" class="empty-state">
          <div class="empty-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
            </svg>
          </div>
          <h2>开始新对话</h2>
          <p>选择一个模型，然后输入你的问题</p>

          <div class="quick-actions">
            <button class="quick-btn" @click="sendQuickMessage('帮我解释一下量子计算')">
              <span class="quick-icon">🔬</span>
              解释量子计算
            </button>
            <button class="quick-btn" @click="sendQuickMessage('写一首关于春天的诗')">
              <span class="quick-icon">✍️</span>
              写一首诗
            </button>
            <button class="quick-btn" @click="sendQuickMessage('用 Python 实现快速排序')">
              <span class="quick-icon">💻</span>
              写排序算法
            </button>
            <button class="quick-btn" @click="sendQuickMessage('解释相对论')">
              <span class="quick-icon">🌌</span>
              解释相对论
            </button>
          </div>
        </div>

        <!-- 消息列表 -->
        <div v-else class="messages-list">
          <div
            v-for="(msg, index) in chatStore.messages"
            :key="msg.id"
            class="message"
            :class="[msg.role, { 'animate-in': index === chatStore.messages.length - 1 }]"
          >
            <div class="message-avatar">
              <div v-if="msg.role === 'user'" class="avatar user-avatar">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                </svg>
              </div>
              <div v-else class="avatar ai-avatar">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                </svg>
              </div>
            </div>

            <div class="message-content">
              <!-- 思考过程 -->
              <div v-if="msg.reasoning" class="reasoning-section">
                <button class="reasoning-toggle" @click="toggleReasoning(msg.id)">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" :class="{ expanded: expandedReasoning[msg.id] }">
                    <polyline points="6 9 12 15 18 9"></polyline>
                  </svg>
                  思考过程
                </button>
                <div v-show="expandedReasoning[msg.id]" class="reasoning-content">
                  {{ msg.reasoning }}
                </div>
              </div>

              <!-- 消息内容 -->
              <div class="message-text">
                <MarkdownRenderer v-if="msg.role === 'assistant'" :content="msg.content" />
                <span v-else>{{ msg.content }}</span>
              </div>

              <!-- 操作栏 -->
              <div class="message-actions" v-if="msg.role === 'assistant'">
                <button class="action-btn" @click="copyMessage(msg.content)" title="复制">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                  </svg>
                </button>
                <button class="action-btn" @click="regenerate(msg.id)" title="重新生成">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="23 4 23 10 17 10"></polyline>
                    <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path>
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <!-- 流式消息 -->
          <div v-if="chatStore.isLoading" class="message assistant animate-in">
            <div class="message-avatar">
              <div class="avatar ai-avatar loading">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
                </svg>
              </div>
            </div>

            <div class="message-content">
              <!-- 思考中 -->
              <div v-if="chatStore.streamingReasoning" class="reasoning-section">
                <button class="reasoning-toggle active">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="rotating">
                    <path d="M21 12a9 9 0 1 1-6.219-8.56"></path>
                  </svg>
                  思考中...
                </button>
                <div class="reasoning-content">
                  {{ chatStore.streamingReasoning }}
                </div>
              </div>

              <!-- 回复中 -->
              <div v-if="chatStore.streamingMessage" class="message-text">
                <MarkdownRenderer :content="chatStore.streamingMessage" />
              </div>

              <!-- 加载指示器 -->
              <div v-if="!chatStore.streamingMessage && !chatStore.streamingReasoning" class="typing-indicator">
                <span></span>
                <span></span>
                <span></span>
              </div>

              <!-- 停止按钮 -->
              <button class="stop-btn" @click="stopGeneration">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                  <rect x="6" y="6" width="12" height="12" rx="2"></rect>
                </svg>
                停止生成
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 输入区域 -->
      <div class="input-container">
        <div class="input-wrapper">
          <textarea
            v-model="inputMessage"
            class="message-input"
            placeholder="输入你的问题..."
            rows="1"
            @keydown="handleKeydown"
            @input="autoResize"
            ref="inputRef"
            :disabled="chatStore.isLoading"
          ></textarea>
          <button
            class="send-btn"
            :class="{ active: inputMessage.trim() && !chatStore.isLoading }"
            @click="sendMessage"
            :disabled="!inputMessage.trim() || chatStore.isLoading"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
        <div class="input-footer">
          <span class="model-info">{{ getModelName(chatStore.selectedModel) }}</span>
          <span class="char-count" v-if="inputMessage.length > 0">{{ inputMessage.length }} 字</span>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useChatStore } from '@/stores/chat'
import { ElMessage } from 'element-plus'
import MarkdownRenderer from '@/components/MarkdownRenderer.vue'
import api from '@/api'

const router = useRouter()
const chatStore = useChatStore()

const inputMessage = ref('')
const messagesContainer = ref<HTMLElement>()
const inputRef = ref<HTMLTextAreaElement>()
const sidebarCollapsed = ref(false)
const availableModels = ref<{ id: string; name: string }[]>([])
const expandedReasoning = ref<Record<string, boolean>>({})

onMounted(async () => {
  await chatStore.fetchConversations()
  await fetchModels()
})

async function fetchModels() {
  try {
    const response = await api.get('/api/models')
    availableModels.value = response.data
    if (availableModels.value.length > 0 && !availableModels.value.find(m => m.id === chatStore.selectedModel)) {
      chatStore.selectedModel = availableModels.value[0].id
    }
  } catch (error) {
    console.error('获取模型列表失败:', error)
  }
}

function getModelName(modelId: string): string {
  const model = availableModels.value.find(m => m.id === modelId)
  return model?.name || modelId
}

function toggleReasoning(msgId: string) {
  expandedReasoning.value[msgId] = !expandedReasoning.value[msgId]
}

async function createNewChat() {
  await chatStore.createConversation()
}

async function selectConversation(conv: any) {
  await chatStore.selectConversation(conv)
  scrollToBottom()
}

async function deleteConversation(id: string) {
  try {
    await chatStore.deleteConversation(id)
    ElMessage.success('对话已删除')
  } catch {
    ElMessage.error('删除失败')
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    sendMessage()
  }
}

function autoResize() {
  const textarea = inputRef.value
  if (textarea) {
    textarea.style.height = 'auto'
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px'
  }
}

async function sendMessage() {
  const content = inputMessage.value.trim()
  if (!content || chatStore.isLoading) return

  inputMessage.value = ''
  if (inputRef.value) {
    inputRef.value.style.height = 'auto'
  }

  try {
    await chatStore.sendMessage(content)
    scrollToBottom()
  } catch (error) {
    ElMessage.error('发送失败，请重试')
  }
}

async function sendQuickMessage(content: string) {
  inputMessage.value = content
  await sendMessage()
}

function stopGeneration() {
  chatStore.cancelRequest()
}

function copyMessage(content: string) {
  navigator.clipboard.writeText(content)
  ElMessage.success('已复制')
}

function regenerate(msgId: string) {
  // TODO: 重新生成
  ElMessage.info('重新生成功能开发中')
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesContainer.value) {
      messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
    }
  })
}

watch(() => chatStore.streamingMessage, scrollToBottom)
watch(() => chatStore.streamingReasoning, scrollToBottom)
</script>

<style scoped>
.chat-container {
  display: flex;
  height: 100vh;
  background: var(--el-bg-color);
}

/* ===== 侧边栏 ===== */
.sidebar {
  width: 260px;
  background: var(--el-bg-color-overlay);
  border-right: 1px solid var(--el-border-color);
  display: flex;
  flex-direction: column;
  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  overflow: hidden;
}

.sidebar.collapsed {
  width: 60px;
}

.sidebar-header {
  padding: 12px;
  border-bottom: 1px solid var(--el-border-color);
}

.new-chat-btn {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  background: var(--el-fill-color);
  border: 1px solid var(--el-border-color);
  border-radius: 12px;
  color: var(--el-text-color-primary);
  cursor: pointer;
  font-size: 14px;
  transition: all 0.15s ease;
}

.new-chat-btn:hover {
  background: var(--el-fill-color-light);
  border-color: var(--el-text-color-secondary);
}

.conversation-list {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}

.conversation-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s ease;
  margin-bottom: 2px;
}

.conversation-item:hover {
  background: var(--el-fill-color);
}

.conversation-item.active {
  background: var(--el-fill-color-light);
}

.conv-icon {
  color: var(--el-text-color-secondary);
  flex-shrink: 0;
}

.conv-info {
  flex: 1;
  min-width: 0;
}

.conv-title {
  font-size: 13px;
  color: var(--el-text-color-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.conv-meta {
  font-size: 11px;
  color: var(--el-text-color-secondary);
  margin-top: 2px;
}

.conv-delete {
  opacity: 0;
  background: none;
  border: none;
  color: var(--el-text-color-secondary);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  transition: all 0.15s ease;
}

.conversation-item:hover .conv-delete {
  opacity: 1;
}

.conv-delete:hover {
  color: var(--el-color-danger);
  background: var(--el-color-danger-light-9);
}

.sidebar-footer {
  padding: 12px;
  border-top: 1px solid var(--el-border-color);
}

.sidebar-btn {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  background: none;
  border: none;
  border-radius: 6px;
  color: var(--el-text-color-regular);
  cursor: pointer;
  font-size: 13px;
  transition: all 0.15s ease;
}

.sidebar-btn:hover {
  background: var(--el-fill-color);
  color: var(--el-text-color-primary);
}

/* ===== 主聊天区域 ===== */
.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.chat-header {
  height: 56px;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 16px;
  border-bottom: 1px solid var(--el-border-color);
  background: var(--el-bg-color-overlay);
}

.toggle-sidebar {
  background: none;
  border: none;
  color: var(--el-text-color-secondary);
  cursor: pointer;
  padding: 8px;
  border-radius: 6px;
  transition: all 0.15s ease;
}

.toggle-sidebar:hover {
  background: var(--el-fill-color);
  color: var(--el-text-color-primary);
}

.model-selector {
  flex: 1;
}

.model-select {
  background: var(--el-fill-color);
  border: 1px solid var(--el-border-color);
  border-radius: 6px;
  color: var(--el-text-color-primary);
  padding: 6px 12px;
  font-size: 13px;
  cursor: pointer;
  outline: none;
  transition: all 0.15s ease;
}

.model-select:hover {
  border-color: var(--el-text-color-secondary);
}

.model-select:focus {
  border-color: var(--el-color-primary);
}

.model-select option {
  background: var(--el-bg-color-overlay);
  color: var(--el-text-color-primary);
}

.header-actions {
  display: flex;
  gap: 8px;
}

.action-btn {
  background: none;
  border: none;
  color: var(--el-text-color-secondary);
  cursor: pointer;
  padding: 8px;
  border-radius: 6px;
  transition: all 0.15s ease;
}

.action-btn:hover {
  background: var(--el-fill-color);
  color: var(--el-text-color-primary);
}

/* ===== 消息区域 ===== */
.messages-container {
  flex: 1;
  overflow-y: auto;
  padding: 0;
}

.empty-state {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  animation: fadeIn 0.5s ease;
}

.empty-icon {
  width: 80px;
  height: 80px;
  background: var(--el-fill-color);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--el-text-color-secondary);
  margin-bottom: 24px;
}

.empty-state h2 {
  font-size: 24px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  margin-bottom: 8px;
}

.empty-state p {
  color: var(--el-text-color-secondary);
  margin-bottom: 32px;
}

.quick-actions {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
  max-width: 500px;
}

.quick-btn {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 14px 16px;
  background: var(--el-bg-color-overlay);
  border: 1px solid var(--el-border-color);
  border-radius: 12px;
  color: var(--el-text-color-primary);
  cursor: pointer;
  font-size: 13px;
  text-align: left;
  transition: all 0.15s ease;
}

.quick-btn:hover {
  background: var(--el-fill-color);
  border-color: var(--el-text-color-secondary);
  transform: translateY(-2px);
}

.quick-icon {
  font-size: 20px;
}

/* ===== 消息列表 ===== */
.messages-list {
  padding: 24px 0;
}

.message {
  display: flex;
  gap: 16px;
  padding: 24px 24px;
  transition: background 0.15s ease;
}

.message.assistant {
  background: var(--el-fill-color-lighter);
}

.message.user {
  background: transparent;
}

.message.animate-in {
  animation: slideUp 0.3s ease;
}

.message-avatar {
  flex-shrink: 0;
}

.avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.user-avatar {
  background: var(--el-color-primary);
  color: white;
}

.ai-avatar {
  background: var(--el-color-success);
  color: white;
}

.ai-avatar.loading {
  animation: pulse 2s infinite;
}

.message-content {
  flex: 1;
  min-width: 0;
  max-width: 800px;
}

/* ===== 思考过程 ===== */
.reasoning-section {
  margin-bottom: 12px;
}

.reasoning-toggle {
  display: flex;
  align-items: center;
  gap: 6px;
  background: none;
  border: none;
  color: var(--el-text-color-secondary);
  cursor: pointer;
  font-size: 12px;
  padding: 4px 0;
  transition: color 0.15s ease;
}

.reasoning-toggle:hover {
  color: var(--el-text-color-regular);
}

.reasoning-toggle svg {
  transition: transform 0.15s ease;
}

.reasoning-toggle svg.expanded {
  transform: rotate(180deg);
}

.reasoning-toggle svg.rotating {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.reasoning-content {
  margin-top: 8px;
  padding: 12px 16px;
  background: var(--el-fill-color);
  border-radius: 6px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
  line-height: 1.6;
  max-height: 200px;
  overflow-y: auto;
}

/* ===== 消息内容 ===== */
.message-text {
  font-size: 15px;
  line-height: 1.7;
  color: var(--el-text-color-primary);
  word-break: break-word;
}

.message-actions {
  display: flex;
  gap: 4px;
  margin-top: 8px;
  opacity: 0;
  transition: opacity 0.15s ease;
}

.message:hover .message-actions {
  opacity: 1;
}

.message-actions .action-btn {
  padding: 6px;
  font-size: 12px;
}

/* ===== 打字指示器 ===== */
.typing-indicator {
  display: flex;
  gap: 4px;
  padding: 8px 0;
}

.typing-indicator span {
  width: 8px;
  height: 8px;
  background: var(--el-text-color-secondary);
  border-radius: 50%;
  animation: typing 1.4s infinite;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

.stop-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: var(--el-fill-color);
  border: 1px solid var(--el-border-color);
  border-radius: 6px;
  color: var(--el-text-color-secondary);
  cursor: pointer;
  font-size: 12px;
  margin-top: 12px;
  transition: all 0.15s ease;
}

.stop-btn:hover {
  background: var(--el-fill-color-light);
  color: var(--el-text-color-primary);
}

/* ===== 输入区域 ===== */
.input-container {
  padding: 16px 24px 24px;
  background: var(--el-bg-color);
}

.input-wrapper {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  background: var(--el-fill-color);
  border: 1px solid var(--el-border-color);
  border-radius: 16px;
  padding: 8px 12px;
  transition: border-color 0.15s ease;
}

.input-wrapper:focus-within {
  border-color: var(--el-color-primary);
}

.message-input {
  flex: 1;
  background: none;
  border: none;
  color: var(--el-text-color-primary);
  font-size: 15px;
  line-height: 1.5;
  resize: none;
  outline: none;
  max-height: 200px;
  padding: 4px 0;
}

.message-input::placeholder {
  color: var(--el-text-color-placeholder);
}

.send-btn {
  width: 36px;
  height: 36px;
  background: var(--el-fill-color);
  border: none;
  border-radius: 50%;
  color: var(--el-text-color-secondary);
  cursor: not-allowed;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.15s ease;
  flex-shrink: 0;
}

.send-btn.active {
  background: var(--el-color-primary);
  color: white;
  cursor: pointer;
}

.send-btn.active:hover {
  opacity: 0.9;
  transform: scale(1.05);
}

.input-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 8px;
  padding: 0 4px;
}

.model-info {
  font-size: 11px;
  color: var(--el-text-color-secondary);
}

.char-count {
  font-size: 11px;
  color: var(--el-text-color-secondary);
}

/* ===== 响应式 ===== */
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    z-index: 100;
    height: 100%;
    transform: translateX(-100%);
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .sidebar:not(.collapsed) {
    transform: translateX(0);
  }

  .quick-actions {
    grid-template-columns: 1fr;
  }
}
</style>
