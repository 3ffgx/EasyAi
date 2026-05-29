<template>
  <router-view v-slot="{ Component, route }">
    <transition name="fade-slide" mode="out-in">
      <component :is="Component" :key="route.path" />
    </transition>
  </router-view>
</template>

<script setup lang="ts">
</script>

<style>
/* 全局变量 */
:root {
  --primary-color: #409eff;
  --primary-light: #ecf5ff;
  --primary-dark: #337ecc;
  --success-color: #67c23a;
  --warning-color: #e6a23c;
  --danger-color: #f56c6c;
  --info-color: #909399;
  --text-primary: #303133;
  --text-regular: #606266;
  --text-secondary: #909399;
  --border-color: #dcdfe6;
  --border-light: #e4e7ed;
  --bg-color: #f5f7fa;
  --bg-white: #ffffff;
  --shadow-sm: 0 2px 4px rgba(0, 0, 0, 0.06);
  --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.08);
  --shadow-lg: 0 8px 24px rgba(0, 0, 0, 0.12);
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 16px;
  --transition-fast: 0.2s ease;
  --transition-normal: 0.3s ease;
  --transition-slow: 0.5s ease;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Microsoft YaHei UI', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: linear-gradient(135deg, #f5f7fa 0%, #e4e7ed 100%);
  min-height: 100vh;
  color: var(--text-primary);
}

/* 页面过渡动画 */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all var(--transition-normal);
}

.fade-slide-enter-from {
  opacity: 0;
  transform: translateX(-20px);
}

.fade-slide-leave-to {
  opacity: 0;
  transform: translateX(20px);
}

/* 全局滚动条样式 */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: var(--border-color);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--text-secondary);
}

/* Element Plus 样式增强 */
.el-card {
  border: none !important;
  border-radius: var(--radius-md) !important;
  box-shadow: var(--shadow-sm) !important;
  transition: all var(--transition-normal) !important;
}

.el-card:hover {
  box-shadow: var(--shadow-md) !important;
  transform: translateY(-2px);
}

.el-button {
  border-radius: var(--radius-sm) !important;
  transition: all var(--transition-fast) !important;
}

.el-button:active {
  transform: scale(0.97);
}

.el-input__wrapper,
.el-textarea__inner {
  border-radius: var(--radius-sm) !important;
  transition: all var(--transition-fast) !important;
}

.el-input__wrapper:hover,
.el-textarea__inner:hover {
  box-shadow: 0 0 0 1px var(--primary-color) inset;
}

.el-table {
  border-radius: var(--radius-md) !important;
  overflow: hidden;
}

.el-table th {
  background-color: var(--bg-color) !important;
  font-weight: 600;
}

.el-tag {
  border-radius: var(--radius-sm) !important;
}

/* 动画关键帧 */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-30px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes slideInRight {
  from {
    opacity: 0;
    transform: translateX(30px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

@keyframes bounce {
  0%, 100% {
    transform: translateY(0);
  }
  50% {
    transform: translateY(-5px);
  }
}

/* 工具类 */
.animate-fade-in {
  animation: fadeIn 0.5s ease forwards;
}

.animate-slide-left {
  animation: slideInLeft 0.5s ease forwards;
}

.animate-slide-right {
  animation: slideInRight 0.5s ease forwards;
}

.animate-pulse {
  animation: pulse 2s infinite;
}

.animate-bounce {
  animation: bounce 1s infinite;
}
</style>
