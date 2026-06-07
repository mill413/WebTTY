import { defineStore } from 'pinia'
import api from '../services/api'

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    themeMode: localStorage.getItem('webtty-theme') || 'system',
    accentColor: localStorage.getItem('webtty-accent') || '#7c3aed',
    tabTitleFormat: '{shell} #{index}',
    sidebarPosition: 'right',
    sessionTimeout: 0,
    loaded: false
  }),

  getters: {
    sidebarOnLeft: (state) => state.sidebarPosition === 'left'
  },

  actions: {
    async fetchSettings() {
      try {
        const { data } = await api.get('/api/settings')
        this.themeMode = data.theme_mode
        this.accentColor = data.accent_color
        this.tabTitleFormat = data.tab_title_format
        this.sidebarPosition = data.sidebar_position
        this.sessionTimeout = data.session_timeout
        this.loaded = true
        this.applyAccentColor()
      } catch {
        // Use defaults if fetch fails
        this.loaded = true
      }
    },

    async updateSettings(updates) {
      try {
        const { data } = await api.put('/api/settings', updates)
        this.themeMode = data.theme_mode
        this.accentColor = data.accent_color
        this.tabTitleFormat = data.tab_title_format
        this.sidebarPosition = data.sidebar_position
        this.sessionTimeout = data.session_timeout
        this.applyAccentColor()
      } catch (err) {
        console.error('Failed to update settings:', err)
      }
    },

    applyAccentColor() {
      const root = document.documentElement
      root.style.setProperty('--accent', this.accentColor)
      // Generate a slightly darker hover color
      const hover = this.adjustBrightness(this.accentColor, -20)
      root.style.setProperty('--accent-hover', hover)
      localStorage.setItem('webtty-accent', this.accentColor)
    },

    adjustBrightness(hex, amount) {
      hex = hex.replace('#', '')
      const num = parseInt(hex, 16)
      let r = Math.min(255, Math.max(0, (num >> 16) + amount))
      let g = Math.min(255, Math.max(0, ((num >> 8) & 0x00ff) + amount))
      let b = Math.min(255, Math.max(0, (num & 0x0000ff) + amount))
      return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')
    },

    formatTabTitle(template, shell, index, title) {
      return template
        .replace('{shell}', shell?.split('/').pop() || 'bash')
        .replace('{index}', index)
        .replace('{title}', title || '')
    }
  }
})
