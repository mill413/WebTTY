import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/LoginView.vue'),
    meta: { guest: true }
  },
  {
    path: '/',
    redirect: '/terminal'
  },
  {
    path: '/terminal',
    name: 'Terminal',
    component: () => import('../views/TerminalView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/terminal/:sessionId',
    name: 'TerminalSession',
    component: () => import('../views/TerminalView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/settings',
    name: 'Settings',
    component: () => import('../views/SettingsView.vue'),
    meta: { requiresAuth: true }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to, from, next) => {
  const token = localStorage.getItem('access_token')

  if (to.meta.requiresAuth && !token) {
    next({ name: 'Login' })
  } else if (to.meta.guest && token) {
    next({ name: 'Terminal' })
  } else {
    next()
  }
})

export default router
