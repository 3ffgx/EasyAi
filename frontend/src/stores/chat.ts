import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api'

interface Message {
  id: string
  role: 'user' | 'assistant' | 'system'
  content: string
  reasoning?: string
  tokens_used: number
  created_at: string
}

interface Conversation {
  id: string
  title: string
  model_id: string
  created_at: string
  last_message?: string
}

export const useChatStore = defineStore('chat', () => {
  const conversations = ref<Conversation[]>([])
  const currentConversation = ref<Conversation | null>(null)
  const messages = ref<Message[]>([])
  const isLoading = ref(false)
  const selectedModel = ref('deepseek-v4-pro')
  const streamingMessage = ref('')
  const streamingReasoning = ref('')
  let abortController: AbortController | null = null

  async function fetchConversations() {
    const response = await api.get('/api/conversations')
    conversations.value = response.data
  }

  async function createConversation(modelId?: string) {
    const response = await api.post('/api/conversations', {
      model_id: modelId || selectedModel.value,
    })
    conversations.value.unshift(response.data)
    currentConversation.value = response.data
    messages.value = []
    return response.data
  }

  async function deleteConversation(id: string) {
    await api.delete(`/api/conversations/${id}`)
    conversations.value = conversations.value.filter((c) => c.id !== id)
    if (currentConversation.value?.id === id) {
      currentConversation.value = null
      messages.value = []
    }
  }

  async function fetchMessages(conversationId: string) {
    const response = await api.get(`/api/chat/history/${conversationId}`)
    messages.value = response.data
  }

  function cancelRequest() {
    if (abortController) {
      abortController.abort()
      abortController = null
    }
    // 如果有正在流式输出的内容，保存为消息
    if (streamingMessage.value || streamingReasoning.value) {
      const assistantMessage: Message = {
        id: Date.now().toString(),
        role: 'assistant',
        content: streamingMessage.value,
        reasoning: streamingReasoning.value || undefined,
        tokens_used: 0,
        created_at: new Date().toISOString(),
      }
      messages.value.push(assistantMessage)
      streamingMessage.value = ''
      streamingReasoning.value = ''
    }
    isLoading.value = false
  }

  async function sendMessage(content: string) {
    if (!currentConversation.value) {
      await createConversation()
    }

    // 添加用户消息
    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content,
      tokens_used: 0,
      created_at: new Date().toISOString(),
    }
    messages.value.push(userMessage)
    isLoading.value = true
    streamingMessage.value = ''
    streamingReasoning.value = ''

    // 创建新的 AbortController
    abortController = new AbortController()

    try {
      // 获取有效的 token（如果过期会自动刷新）
      let token = localStorage.getItem('token')

      // 使用 SSE 流式响应
      let response = await fetch('/api/chat/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          conversation_id: currentConversation.value!.id,
          content,
          model_id: selectedModel.value,
        }),
        signal: abortController.signal,
      })

      // 如果是 401 错误，尝试刷新 token 后重试
      if (response.status === 401) {
        const refreshToken = localStorage.getItem('refreshToken')
        if (refreshToken) {
          try {
            const refreshResponse = await fetch('/api/auth/refresh', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ refresh_token: refreshToken }),
            })

            if (refreshResponse.ok) {
              const data = await refreshResponse.json()
              localStorage.setItem('token', data.access_token)
              if (data.refresh_token) {
                localStorage.setItem('refreshToken', data.refresh_token)
              }
              token = data.access_token

              // 重试请求
              response = await fetch('/api/chat/send', {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify({
                  conversation_id: currentConversation.value!.id,
                  content,
                  model_id: selectedModel.value,
                }),
                signal: abortController.signal,
              })
            }
          } catch (refreshError) {
            console.error('刷新 token 失败:', refreshError)
          }
        }
      }

      if (!response.ok) {
        throw new Error('发送失败')
      }

      const reader = response.body?.getReader()
      const decoder = new TextDecoder()

      if (reader) {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          const chunk = decoder.decode(value)
          const lines = chunk.split('\n')

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6)
              if (data === '[DONE]') {
                // 流结束
                if (streamingMessage.value || streamingReasoning.value) {
                  const assistantMessage: Message = {
                    id: Date.now().toString(),
                    role: 'assistant',
                    content: streamingMessage.value,
                    reasoning: streamingReasoning.value || undefined,
                    tokens_used: 0,
                    created_at: new Date().toISOString(),
                  }
                  messages.value.push(assistantMessage)
                  streamingMessage.value = ''
                  streamingReasoning.value = ''
                }
              } else {
                try {
                  const parsed = JSON.parse(data)
                  if (parsed.type === 'reasoning') {
                    streamingReasoning.value += parsed.content
                  } else if (parsed.type === 'content') {
                    streamingMessage.value += parsed.content
                  }
                } catch {
                  // 忽略解析错误
                }
              }
            }
          }
        }
      }
    } catch (error: any) {
      if (error.name === 'AbortError') {
        console.log('请求已取消')
      } else {
        console.error('发送消息失败:', error)
        throw error
      }
    } finally {
      isLoading.value = false
      abortController = null
    }
  }

  async function selectConversation(conversation: Conversation) {
    // 清空流式显示（但不取消请求，让后台继续完成）
    streamingMessage.value = ''
    streamingReasoning.value = ''

    currentConversation.value = conversation
    selectedModel.value = conversation.model_id
    await fetchMessages(conversation.id)
  }

  return {
    conversations,
    currentConversation,
    messages,
    isLoading,
    selectedModel,
    streamingMessage,
    streamingReasoning,
    fetchConversations,
    createConversation,
    deleteConversation,
    fetchMessages,
    sendMessage,
    selectConversation,
    cancelRequest,
  }
})
