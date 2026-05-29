<template>
  <el-container class="main-layout">
    <!-- 侧边栏 -->
    <el-aside :width="isCollapse ? '64px' : '240px'" class="aside">
      <div class="logo" @click="router.push('/')">
        <div class="logo-icon">
          <el-icon :size="24"><ChatDotRound /></el-icon>
        </div>
        <transition name="fade">
          <span v-show="!isCollapse" class="logo-text">EasyAi</span>
        </transition>
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
              <transition name="fade">
                <span v-show="!isCollapse" class="group-title">管理后台</span>
              </transition>
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
    </el-aside>

    <!-- 主内容区 -->
    <el-container>
      <el-header class="header">
        <div class="header-left">
          <h2 class="page-title">{{ currentTitle }}</h2>
        </div>
        <div class="header-right">
          <el-dropdown @command="handleCommand" trigger="click">
            <div class="user-info">
              <el-avatar :size="36" class="user-avatar">
                <el-icon :size="20"><UserFilled /></el-icon>
              </el-avatar>
              <transition name="fade">
                <span class="username">{{ authStore.user?.nickname }}</span>
              </transition>
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
      </el-header>

      <el-main class="main">
        <router-view v-slot="{ Component, route }">
          <transition name="fade-slide" mode="out-in">
            <div :key="route.path" class="page-container">
              <component :is="Component" />
            </div>
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>

  <!-- 公告弹窗 -->
  <AnnouncementDialog />
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AnnouncementDialog from '@/components/AnnouncementDialog.vue'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

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
  overflow: hidden;
}

.aside {
  background: linear-gradient(180deg, #1a1f36 0%, #252b48 100%);
  transition: width var(--transition-normal);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  box-shadow: 4px 0 12px rgba(0, 0, 0, 0.1);
  z-index: 10;
}

.logo {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  gap: 10px;
  padding: 0 16px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  transition: all var(--transition-normal);
}

.logo:hover {
  background: rgba(255, 255, 255, 0.05);
}

.logo-icon {
  width: 36px;
  height: 36px;
  background: linear-gradient(135deg, #409eff 0%, #6366f1 100%);
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
  color: white;
  white-space: nowrap;
  background: linear-gradient(135deg, #fff 0%, #a5b4fc 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
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
  color: rgba(255, 255, 255, 0.65);
  border-radius: 8px;
  margin: 2px 0;
  height: 44px;
  transition: all var(--transition-fast);
}

:deep(.el-menu-item:hover),
:deep(.el-menu-item.is-active) {
  color: white;
  background: linear-gradient(135deg, rgba(64, 158, 255, 0.3) 0%, rgba(99, 102, 241, 0.3) 100%);
}

:deep(.el-menu-item.is-active) {
  background: linear-gradient(135deg, rgba(64, 158, 255, 0.5) 0%, rgba(99, 102, 241, 0.5) 100%);
  box-shadow: 0 2px 8px rgba(64, 158, 255, 0.3);
}

:deep(.el-menu-item-group__title) {
  padding: 0;
}

.menu-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.08);
  margin: 12px 16px;
}

.group-title {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.35);
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
  color: rgba(255, 255, 255, 0.45);
  border-top: 1px solid rgba(255, 255, 255, 0.08);
  transition: all var(--transition-fast);
}

.collapse-btn:hover {
  color: white;
  background: rgba(255, 255, 255, 0.05);
}

.header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-bottom: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  height: 64px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
}

.page-title {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  padding: 6px 12px;
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.user-info:hover {
  background: var(--bg-color);
}

.user-avatar {
  background: linear-gradient(135deg, #409eff 0%, #6366f1 100%);
}

.username {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.arrow-icon {
  font-size: 12px;
  color: var(--text-secondary);
  transition: transform var(--transition-fast);
}

.user-info:hover .arrow-icon {
  transform: rotate(180deg);
}

.main {
  background: var(--bg-color);
  padding: 20px;
  overflow-y: auto;
}

.page-container {
  animation: fadeIn 0.4s ease;
}

/* 页面内过渡动画 */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.3s ease;
}

.fade-slide-enter-from {
  opacity: 0;
  transform: translateY(10px);
}

.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
