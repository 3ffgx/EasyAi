<template>
  <div class="main-layout">
    <!-- 侧边栏 -->
    <div class="aside" :style="{ width: isCollapse ? '64px' : '240px' }">
      <div class="logo" @click="router.push('/')">
        <div class="logo-icon">
          <el-icon :size="24"><ChatDotRound /></el-icon>
        </div>
        <span v-show="!isCollapse" class="logo-text">EasyAi</span>
      </div>

      <el-menu
        :default-active="activeMenu"
        :collapse="isCollapse"
        router
        class="side-menu"
      >
        <el-menu-item index="/">
          <el-icon><ChatLineRound /></el-icon>
          <template #title>对话</template>
        </el-menu-item>
        <el-menu-item index="/dashboard">
          <el-icon><DataBoard /></el-icon>
          <template #title>仪表盘</template>
        </el-menu-item>
        <el-menu-item index="/usage">
          <el-icon><TrendCharts /></el-icon>
          <template #title>使用量</template>
        </el-menu-item>

        <template v-if="authStore.isAdmin">
          <div class="menu-divider"></div>
          <el-menu-item-group>
            <template #title>
              <span v-show="!isCollapse" class="group-title">管理后台</span>
            </template>
            <el-menu-item index="/admin">
              <el-icon><Histogram /></el-icon>
              <template #title>统计概览</template>
            </el-menu-item>
            <el-menu-item index="/admin/users">
              <el-icon><User /></el-icon>
              <template #title>用户管理</template>
            </el-menu-item>
            <el-menu-item index="/admin/models">
              <el-icon><Setting /></el-icon>
              <template #title>模型管理</template>
            </el-menu-item>
            <el-menu-item index="/admin/finance">
              <el-icon><Wallet /></el-icon>
              <template #title>财务中心</template>
            </el-menu-item>
            <el-menu-item index="/admin/settings">
              <el-icon><Tools /></el-icon>
              <template #title>系统配置</template>
            </el-menu-item>
          </el-menu-item-group>
        </template>
      </el-menu>

      <div class="collapse-btn" @click="isCollapse = !isCollapse">
        <el-icon :size="18">
          <Fold v-if="!isCollapse" />
          <Expand v-else />
        </el-icon>
      </div>
    </div>

    <!-- 主内容区 -->
    <div class="content-wrapper">
      <div class="header">
        <div class="header-left">
          <h2 class="page-title">{{ currentTitle }}</h2>
        </div>
        <div class="header-right">
          <button class="theme-toggle" @click="themeStore.toggleTheme()" :title="themeStore.isDark ? '切换到亮色模式' : '切换到暗色模式'">
            <el-icon :size="18">
              <Sunny v-if="themeStore.isDark" />
              <Moon v-else />
            </el-icon>
          </button>

          <el-dropdown @command="handleCommand" trigger="click">
            <div class="user-info">
              <el-avatar :size="36" class="user-avatar">
                <el-icon :size="20"><UserFilled /></el-icon>
              </el-avatar>
              <span class="username">{{ authStore.user?.nickname }}</span>
              <el-icon class="arrow-icon"><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="profile">
                  <el-icon><User /></el-icon>
                  个人信息
                </el-dropdown-item>
                <el-dropdown-item command="logout" divided>
                  <el-icon><SwitchButton /></el-icon>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </div>

      <div class="main-content">
        <router-view />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore } from '@/stores/theme'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const themeStore = useThemeStore()

const isCollapse = ref(false)

const activeMenu = computed(() => route.path)

const currentTitle = computed(() => {
  const titles: Record<string, string> = {
    '/': '对话',
    '/dashboard': '仪表盘',
    '/usage': '使用量统计',
    '/admin': '统计概览',
    '/admin/users': '用户管理',
    '/admin/models': '模型管理',
    '/admin/finance': '财务中心',
    '/admin/settings': '系统配置',
  }
  return titles[route.path] || 'EasyAi'
})

function handleCommand(command: string) {
  if (command === 'logout') {
    authStore.logout()
    router.push('/login')
  }
}
</script>

<style scoped>
.main-layout {
  height: 100vh;
  display: flex;
  overflow: hidden;
}

.aside {
  background: var(--el-bg-color-overlay);
  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--el-border-color);
  z-index: 10;
  flex-shrink: 0;
  overflow: hidden;
}

.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  gap: 10px;
  padding: 0 16px;
  border-bottom: 1px solid var(--el-border-color);
}

.logo:hover {
  background: var(--el-fill-color-light);
}

.logo-icon {
  width: 36px;
  height: 36px;
  background: var(--el-color-primary);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.logo-text {
  font-size: 18px;
  font-weight: 700;
  color: var(--el-text-color-primary);
  white-space: nowrap;
}

.side-menu {
  flex: 1;
  border-right: none;
  background: transparent;
  padding: 8px;
}

.side-menu:not(.el-menu--collapse) {
  width: 100%;
}

:deep(.el-menu-item) {
  color: var(--el-text-color-regular);
  border-radius: 8px;
  margin: 2px 0;
  height: 44px;
}

:deep(.el-menu-item:hover) {
  background: var(--el-fill-color-light);
  color: var(--el-text-color-primary);
}

:deep(.el-menu-item.is-active) {
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
}

:deep(.el-menu-item-group__title) {
  padding: 0;
}

.menu-divider {
  height: 1px;
  background: var(--el-border-color);
  margin: 12px 16px;
}

.group-title {
  font-size: 11px;
  color: var(--el-text-color-secondary);
  text-transform: uppercase;
  letter-spacing: 1px;
  padding: 0 16px;
}

.collapse-btn {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  color: var(--el-text-color-secondary);
  border-top: 1px solid var(--el-border-color);
}

.collapse-btn:hover {
  color: var(--el-text-color-primary);
  background: var(--el-fill-color-light);
}

.content-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
}

.header {
  background: var(--el-bg-color-overlay);
  border-bottom: 1px solid var(--el-border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  height: 64px;
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.page-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.theme-toggle {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: 1px solid var(--el-border-color);
  border-radius: 8px;
  color: var(--el-text-color-secondary);
  cursor: pointer;
}

.theme-toggle:hover {
  background: var(--el-fill-color-light);
  color: var(--el-text-color-primary);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: 8px;
}

.user-info:hover {
  background: var(--el-fill-color-light);
}

.user-avatar {
  background: var(--el-color-primary);
}

.username {
  font-size: 14px;
  font-weight: 500;
  color: var(--el-text-color-primary);
}

.arrow-icon {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.main-content {
  flex: 1;
  background: var(--el-bg-color);
  padding: 20px;
  overflow-y: auto;
}
</style>
