<template>
  <div class="login-container">
    <div class="login-card">
      <div class="logo-section">
        <div class="logo-icon">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
          </svg>
        </div>
        <h1>EasyAi</h1>
        <p>智能对话平台</p>
      </div>

      <div class="form-section">
        <div class="tabs">
          <button
            class="tab"
            :class="{ active: activeTab === 'login' }"
            @click="activeTab = 'login'"
          >
            登录
          </button>
          <button
            class="tab"
            :class="{ active: activeTab === 'register' }"
            @click="activeTab = 'register'"
          >
            注册
          </button>
        </div>

        <!-- 登录表单 -->
        <form v-if="activeTab === 'login'" @submit.prevent="handleLogin" class="form">
          <div class="form-group">
            <label>邮箱</label>
            <input
              v-model="loginForm.email"
              type="email"
              placeholder="请输入邮箱"
              required
            />
          </div>
          <div class="form-group">
            <label>密码</label>
            <input
              v-model="loginForm.password"
              type="password"
              placeholder="请输入密码"
              required
            />
          </div>
          <button type="submit" class="submit-btn" :disabled="loading">
            <span v-if="loading" class="loading-spinner"></span>
            {{ loading ? '登录中...' : '登录' }}
          </button>
        </form>

        <!-- 注册表单 -->
        <form v-else @submit.prevent="handleRegister" class="form">
          <div class="form-group">
            <label>昵称</label>
            <input
              v-model="registerForm.nickname"
              type="text"
              placeholder="请输入昵称"
              required
            />
          </div>
          <div class="form-group">
            <label>邮箱</label>
            <input
              v-model="registerForm.email"
              type="email"
              placeholder="请输入邮箱"
              required
            />
          </div>
          <div class="form-group">
            <label>密码</label>
            <input
              v-model="registerForm.password"
              type="password"
              placeholder="请输入密码"
              required
              minlength="6"
            />
          </div>
          <div class="form-group">
            <label>确认密码</label>
            <input
              v-model="registerForm.confirmPassword"
              type="password"
              placeholder="请再次输入密码"
              required
            />
          </div>
          <button type="submit" class="submit-btn" :disabled="loading">
            <span v-if="loading" class="loading-spinner"></span>
            {{ loading ? '注册中...' : '注册' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessage } from 'element-plus'

const router = useRouter()
const authStore = useAuthStore()

const activeTab = ref('login')
const loading = ref(false)

const loginForm = reactive({
  email: '',
  password: '',
})

const registerForm = reactive({
  nickname: '',
  email: '',
  password: '',
  confirmPassword: '',
})

async function handleLogin() {
  if (!loginForm.email || !loginForm.password) {
    ElMessage.warning('请填写邮箱和密码')
    return
  }

  loading.value = true
  try {
    await authStore.login(loginForm.email, loginForm.password)
    ElMessage.success('登录成功')
    router.push('/')
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '登录失败')
  } finally {
    loading.value = false
  }
}

async function handleRegister() {
  if (!registerForm.nickname || !registerForm.email || !registerForm.password) {
    ElMessage.warning('请填写所有字段')
    return
  }

  if (registerForm.password !== registerForm.confirmPassword) {
    ElMessage.warning('两次密码不一致')
    return
  }

  if (registerForm.password.length < 6) {
    ElMessage.warning('密码至少6位')
    return
  }

  loading.value = true
  try {
    await authStore.register(registerForm.email, registerForm.password, registerForm.nickname)
    ElMessage.success('注册成功')
    router.push('/')
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '注册失败')
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.login-container {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--el-bg-color);
  padding: 20px;
}

.login-card {
  width: 100%;
  max-width: 400px;
  animation: scaleIn 0.3s ease;
}

@keyframes scaleIn {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}

.logo-section {
  text-align: center;
  margin-bottom: 40px;
}

.logo-icon {
  width: 64px;
  height: 64px;
  background: linear-gradient(135deg, var(--el-color-primary), var(--el-color-success));
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  margin: 0 auto 16px;
}

.logo-section h1 {
  font-size: 28px;
  font-weight: 700;
  color: var(--el-text-color-primary);
  margin-bottom: 4px;
}

.logo-section p {
  color: var(--el-text-color-secondary);
  font-size: 14px;
}

.form-section {
  background: var(--el-bg-color-overlay);
  border: 1px solid var(--el-border-color);
  border-radius: 16px;
  padding: 24px;
}

.tabs {
  display: flex;
  gap: 4px;
  margin-bottom: 24px;
  background: var(--el-fill-color);
  border-radius: 6px;
  padding: 4px;
}

.tab {
  flex: 1;
  padding: 10px;
  background: none;
  border: none;
  border-radius: 4px;
  color: var(--el-text-color-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
}

.tab.active {
  background: var(--el-bg-color-overlay);
  color: var(--el-text-color-primary);
  box-shadow: var(--el-box-shadow-light);
}

.form {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-group label {
  font-size: 13px;
  font-weight: 500;
  color: var(--el-text-color-secondary);
}

.form-group input {
  padding: 10px 14px;
  background: var(--el-fill-color);
  border: 1px solid var(--el-border-color);
  border-radius: 6px;
  color: var(--el-text-color-primary);
  font-size: 14px;
  outline: none;
  transition: all 0.15s ease;
}

.form-group input::placeholder {
  color: var(--el-text-color-placeholder);
}

.form-group input:focus {
  border-color: var(--el-color-primary);
  box-shadow: 0 0 0 2px var(--el-color-primary-light-9);
}

.submit-btn {
  width: 100%;
  padding: 12px;
  background: var(--el-color-primary);
  border: none;
  border-radius: 6px;
  color: white;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.15s ease;
  margin-top: 8px;
}

.submit-btn:hover:not(:disabled) {
  opacity: 0.9;
  transform: translateY(-1px);
}

.submit-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.loading-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
</style>
