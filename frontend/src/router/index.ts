import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/Login.vue'),
      meta: { guest: true },
    },
    {
      path: '/',
      component: () => import('@/layouts/MainLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'Chat',
          component: () => import('@/views/Chat.vue'),
        },
        {
          path: 'dashboard',
          name: 'Dashboard',
          component: () => import('@/views/Dashboard.vue'),
        },
        {
          path: 'usage',
          name: 'Usage',
          component: () => import('@/views/Usage.vue'),
        },
        {
          path: 'admin',
          name: 'AdminDashboard',
          component: () => import('@/views/admin/Statistics.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'admin/users',
          name: 'AdminUsers',
          component: () => import('@/views/admin/Users.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'admin/models',
          name: 'AdminModels',
          component: () => import('@/views/admin/Models.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'admin/finance',
          name: 'AdminFinance',
          component: () => import('@/views/admin/Finance.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'admin/settings',
          name: 'AdminSettings',
          component: () => import('@/views/admin/Settings.vue'),
          meta: { requiresAdmin: true },
        },
      ],
    },
  ],
})

// 路由守卫
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()

  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
  } else if (to.meta.guest && authStore.isAuthenticated) {
    next('/')
  } else if (to.meta.requiresAdmin && authStore.user?.role !== 'admin') {
    next('/')
  } else {
    next()
  }
})

export default router
