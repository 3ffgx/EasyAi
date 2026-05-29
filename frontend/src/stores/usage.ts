import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '@/api'

interface UsageStats {
  total_tokens: number
  total_cost: number
  today_tokens: number
  today_cost: number
  month_tokens: number
  month_cost: number
}

interface UsageRecord {
  id: string
  model_id: string
  tokens_input: number
  tokens_output: number
  cost: number
  created_at: string
}

export const useUsageStore = defineStore('usage', () => {
  const stats = ref<UsageStats | null>(null)
  const records = ref<UsageRecord[]>([])
  const balance = ref(0)
  const loading = ref(false)

  async function fetchStats() {
    loading.value = true
    try {
      const response = await api.get('/api/usage/stats')
      stats.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchRecords(params?: {
    page?: number
    page_size?: number
    model_id?: string
    start_date?: string
    end_date?: string
  }) {
    const response = await api.get('/api/usage/records', { params })
    records.value = response.data.items
    return response.data
  }

  async function fetchBalance() {
    const response = await api.get('/api/usage/balance')
    balance.value = response.data.balance
  }

  return {
    stats,
    records,
    balance,
    loading,
    fetchStats,
    fetchRecords,
    fetchBalance,
  }
})
