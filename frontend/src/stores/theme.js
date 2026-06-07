import { defineStore } from 'pinia'

const STORAGE_KEY = 'webtty-theme'

export const useThemeStore = defineStore('theme', {
  state: () => ({
    theme: localStorage.getItem(STORAGE_KEY) || 'dark'
  }),

  getters: {
    isDark: (state) => state.theme === 'dark'
  },

  actions: {
    toggle() {
      this.theme = this.theme === 'dark' ? 'light' : 'dark'
      this.apply()
    },

    apply() {
      localStorage.setItem(STORAGE_KEY, this.theme)
      document.documentElement.setAttribute('data-theme', this.theme)
    }
  }
})
