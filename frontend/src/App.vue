<template>
  <router-view v-slot="{ Component, route }">
    <transition name="page-fade" mode="out-in">
      <component :is="Component" :key="route.path" />
    </transition>
  </router-view>
</template>

<script setup lang="ts">
</script>

<style>
/* ===== 自定义 CSS 变量 ===== */
:root {
  /* 主色调 */
  --accent-primary: #10a37f;
  --accent-secondary: #7c3aed;
  --accent-blue: #3b82f6;

  /* 圆角 */
  --radius-sm: 6px;
  --radius-md: 12px;
  --radius-lg: 16px;

  /* 过渡 */
  --transition-fast: 150ms ease;
  --transition-normal: 250ms ease;
  --transition-slow: 400ms cubic-bezier(0.4, 0, 0.2, 1);
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body {
  height: 100%;
  overflow: hidden;
}

body {
  font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#app {
  height: 100%;
}

/* ===== 页面过渡动画 ===== */
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.page-fade-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.page-fade-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

/* ===== 全局滚动条 ===== */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: var(--el-border-color);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--el-text-color-secondary);
}

/* ===== 动画关键帧 ===== */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

@keyframes typing {
  0% { opacity: 0.3; transform: scale(0.8); }
  50% { opacity: 1; transform: scale(1); }
  100% { opacity: 0.3; transform: scale(0.8); }
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* ===== 工具类 ===== */
.animate-fade-in {
  animation: fadeIn 0.3s ease forwards;
}

.animate-slide-up {
  animation: slideUp 0.3s ease forwards;
}
</style>
