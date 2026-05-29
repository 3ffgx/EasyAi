import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/api'

interface User {
  id: string
  email: string
  nickname: string
  role: 'user' | 'admin'
  tier_id: string
  balance: number
  is_active: boolean
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('token'))
  const refreshToken = ref<string | null>(localStorage.getItem('refreshToken'))

  const isAuthenticated = computed(() => !!token.value)
  const isAdmin = computed(() => user.value?.role === 'admin')

  async function login(email: string, password: string) {
    const response = await api.post('/api/auth/login', { email, password })
    token.value = response.data.access_token
    refreshToken.value = response.data.refresh_token
    localStorage.setItem('token', token.value!)
    localStorage.setItem('refreshToken', refreshToken.value!)
    await fetchUser()
  }

  async function register(email: string, password: string, nickname: string) {
    await api.post('/api/auth/register', { email, password, nickname })
    await login(email, password)
  }

  async function fetchUser() {
    if (!token.value) return
    try {
      const response = await api.get('/api/auth/me')
      user.value = response.data
    } catch {
      logout()
    }
  }

  function logout() {
    user.value = null
    token.value = null
    refreshToken.value = null
    localStorage.removeItem('token')
    localStorage.removeItem('refreshToken')
  }

  async function refreshAccessToken() {
    if (!refreshToken.value) return
    try {
      const response = await api.post('/api/auth/refresh', {
        refresh_token: refreshToken.value,
      })
      token.value = response.data.access_token
      localStorage.setItem('token', token.value!)
    } catch {
      logout()
    }
  }

  // 初始化时获取用户信息
  if (token.value) {
    fetchUser()
  }

  return {
    user,
    token,
    isAuthenticated,
    isAdmin,
    login,
    register,
    logout,
    fetchUser,
    refreshAccessToken,
  }
})
