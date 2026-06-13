import { createRouter, createWebHistory } from 'vue-router'
import axios from 'axios'

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

router.beforeEach(async (to, from, next) => {
  const token = localStorage.getItem('access_token')

  // If authenticated, redirect away from login
  if (to.meta.guest && token) {
    return next({ name: 'Terminal' })
  }

  // If unauthenticated and not going to login, check if any users exist
  if (!token && to.name !== 'Login') {
    try {
      const res = await axios.get('/api/auth/has-users')
      if (!res.data.has_users) {
        return next({ name: 'Login', query: { mode: 'register' } })
      }
    } catch (e) {
      // If check fails, fall through to login
    }
    return next({ name: 'Login' })
  }

  if (to.meta.requiresAuth && !token) {
    next({ name: 'Login' })
  } else {
    next()
  }
})

export default router
