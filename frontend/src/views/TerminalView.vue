<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useTerminalStore } from '../stores/terminal'
import { useAuthStore } from '../stores/auth'
import { useSettingsStore } from '../stores/settings'
import TerminalTabs from '../components/terminal/TerminalTabs.vue'
import TerminalPane from '../components/terminal/TerminalPane.vue'
import StatusBar from '../components/layout/StatusBar.vue'
import FileBrowser from '../components/terminal/FileBrowser.vue'
import SettingsView from './SettingsView.vue'
import { useI18n } from 'vue-i18n'
import ThemeToggle from '../components/common/ThemeToggle.vue'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const terminalStore = useTerminalStore()
const authStore = useAuthStore()
const settingsStore = useSettingsStore()

const terminalPaneRef = ref(null)
const terminalDims = ref({ cols: 80, rows: 24 })
const connectionStatus = ref('disconnected')
const showFileBrowser = ref(false)
const showUserMenu = ref(false)
const showShellDialog = ref(false)
const selectedShell = ref('/bin/bash')
const sessionTitle = ref('')
const sessionCwd = ref('')
const creating = ref(false)

const isSettingsTab = computed(() => terminalStore.activeTab?.type === 'settings')

const shells = [
  { value: '/bin/bash', label: 'Bash', icon: '⚡' },
  { value: '/bin/zsh', label: 'Zsh', icon: '🔷' },
  { value: '/usr/bin/fish', label: 'Fish', icon: '🐟' },
  { value: '/bin/sh', label: 'SH', icon: '📟' }
]

const runningSessions = computed(() =>
  terminalStore.sessions.filter((s) => s.status === 'running')
)

const recentSessions = computed(() =>
  terminalStore.sessions.slice(0, 10)
)

onMounted(async () => {
  if (!authStore.user) {
    await authStore.fetchUser()
  }

  if (!settingsStore.loaded) {
    await settingsStore.fetchSettings()
  }

  await terminalStore.fetchSessions()

  // Close user menu on outside click
  document.addEventListener('click', () => {
    showUserMenu.value = false
  })

  // If route has a sessionId, ensure there's a tab for it
  if (route.params.sessionId) {
    const sessionId = route.params.sessionId
    const existing = terminalStore.tabs.find((t) => t.sessionId === sessionId)
    if (!existing) {
      terminalStore.addTabForSession(sessionId, `Session ${sessionId}`)
    } else {
      terminalStore.activeTabId = existing.id
    }
  } else if (terminalStore.sessions.length > 0) {
    // Auto-create tabs for all existing sessions
    for (const session of terminalStore.sessions) {
      terminalStore.addTabForSession(session.id, session.title || `${session.shell} session`, session.shell)
    }
    // Set first running session as active, or the first session
    const runningSession = terminalStore.sessions.find((s) => s.status === 'running')
    if (runningSession) {
      const runningTab = terminalStore.tabs.find((t) => t.sessionId === runningSession.id)
      if (runningTab) terminalStore.activeTabId = runningTab.id
    }
  }

  // Auto-open file browser if query param is set
  if (route.query.files === '1') {
    showFileBrowser.value = true
  }

  await nextTick()
  terminalPaneRef.value?.focus()
})

watch(() => terminalStore.activeTab, (tab) => {
  if (tab?.type === 'settings') {
    document.title = 'WebTTY - Settings'
  } else if (tab) {
    const title = settingsStore.formatTabTitle(
      settingsStore.tabTitleFormat,
      tab.shell,
      terminalStore.tabs.indexOf(tab) + 1,
      tab.title
    )
    document.title = `WebTTY - ${title}`
  } else {
    document.title = 'WebTTY'
  }
}, { immediate: true })

watch(() => route.params.sessionId, (newId) => {
  if (newId) {
    const existing = terminalStore.tabs.find((t) => t.sessionId === newId)
    if (existing) {
      terminalStore.activeTabId = existing.id
    } else {
      terminalStore.addTabForSession(newId, `Session ${newId}`)
    }
  }
})

function handleNewTerminal(shell) {
  terminalStore.createSession(shell)
}

function handleTabSwitch(tabId) {
  terminalStore.switchTab(tabId)
}

function handleTabClose(tabId) {
  terminalStore.closeTab(tabId)
}

function handleTabRename(tabId, title) {
  terminalStore.renameTab(tabId, title)
}

function handleResize(dims) {
  terminalDims.value = dims
}

function handleConnectionChange(status) {
  connectionStatus.value = status
}

function toggleFileBrowser() {
  showFileBrowser.value = !showFileBrowser.value
}

function closeFileBrowser() {
  showFileBrowser.value = false
}

function openSettings() {
  showUserMenu.value = false
  terminalStore.openSettingsTab()
}

async function createNewSession() {
  creating.value = true
  try {
    await terminalStore.createSession(selectedShell.value, sessionTitle.value, sessionCwd.value)
    showShellDialog.value = false
    sessionTitle.value = ''
    sessionCwd.value = ''
  } catch (err) {
    console.error('Failed to create session:', err)
  } finally {
    creating.value = false
  }
}

async function reconnectToSession(sessionId) {
  try {
    await terminalStore.reconnectSession(sessionId)
  } catch (err) {
    console.error('Failed to reconnect:', err)
  }
}

async function deleteSession(sessionId) {
  if (!confirm(t('home.confirmDelete'))) return
  try {
    await terminalStore.deleteSession(sessionId)
  } catch (err) {
    console.error('Failed to delete session:', err)
  }
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function goHome() {
  terminalStore.activeTabId = null
  router.push('/terminal')
}

function logout() {
  authStore.logout()
  router.push('/login')
}
</script>

<template>
  <div class="terminal-page">
    <div class="terminal-header">
      <div class="header-left">
        <button class="btn-home" @click="goHome" :title="t('terminal.home')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="4 17 10 11 4 5" />
            <line x1="12" y1="19" x2="20" y2="19" />
          </svg>
        </button>
        <span class="header-brand">WebTTY</span>
      </div>
      <div class="header-tabs">
        <TerminalTabs
          :tabs="terminalStore.tabs"
          :activeTabId="terminalStore.activeTabId"
          @switch="handleTabSwitch"
          @close="handleTabClose"
          @rename="handleTabRename"
          @new-tab="handleNewTerminal"
        />
      </div>
      <div class="header-right">
        <ThemeToggle />
        <button
          class="toolbar-btn"
          :class="{ active: showFileBrowser }"
          @click="toggleFileBrowser"
          :title="t('toolbar.fileBrowser')"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z"/>
          </svg>
        </button>
        <div class="user-menu-wrapper" @click.stop>
          <button class="user-label" @click="showUserMenu = !showUserMenu">
            <img v-if="authStore.avatar" :src="authStore.avatar" class="user-avatar" :alt="authStore.username" />
            <span v-else class="username">{{ authStore.username }}</span>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="6 9 12 15 18 9" />
            </svg>
          </button>
          <div v-if="showUserMenu" class="user-dropdown">
            <button class="dropdown-item" @click="openSettings">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="3" />
                <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83 0 2 2 0 010-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 010-2.83 2 2 0 012.83 0l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 0 2 2 0 010 2.83l-.06.06A1.65 1.65 0 0019.32 9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z" />
              </svg>
              {{ t('toolbar.settings') }}
            </button>
            <button class="dropdown-item" @click="logout">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4" />
                <polyline points="16 17 21 12 16 7" />
                <line x1="21" y1="12" x2="9" y2="12" />
              </svg>
              {{ t('terminal.logout') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="terminal-main">
      <FileBrowser
        v-if="showFileBrowser && settingsStore.sidebarOnLeft"
        :position="settingsStore.sidebarPosition"
        @close="closeFileBrowser"
      />
      <div class="terminal-body">
        <!-- Settings tab content -->
        <SettingsView
          v-if="isSettingsTab"
          :embedded="true"
        />
        <!-- Terminal pane -->
        <TerminalPane
          v-else-if="terminalStore.activeTab"
          ref="terminalPaneRef"
          :sessionId="terminalStore.activeTab.sessionId"
          :key="terminalStore.activeTab.sessionId"
          @resize="handleResize"
          @connection-change="handleConnectionChange"
        />
        <!-- Welcome / empty state -->
        <div v-else class="welcome-page">
          <section class="welcome-section">
            <h1>{{ t('home.welcome') }} <span class="accent">{{ authStore.username }}</span></h1>
            <p class="text-subtext">{{ t('home.subtitle') }}</p>
          </section>

          <section class="stats-row">
            <div class="stat-card">
              <div class="stat-value">{{ terminalStore.sessions.length }}</div>
              <div class="stat-label text-subtext">{{ t('home.totalSessions') }}</div>
            </div>
            <div class="stat-card">
              <div class="stat-value text-success">{{ runningSessions.length }}</div>
              <div class="stat-label text-subtext">{{ t('home.running') }}</div>
            </div>
            <div class="stat-card">
              <div class="stat-value">{{ terminalStore.tabs.length }}</div>
              <div class="stat-label text-subtext">{{ t('home.openTabs') }}</div>
            </div>
          </section>

          <section class="actions-section">
            <button class="btn-new-terminal" @click="showShellDialog = true">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="12" y1="5" x2="12" y2="19" />
                <line x1="5" y1="12" x2="19" y2="12" />
              </svg>
              {{ t('home.newTerminal') }}
            </button>
          </section>

          <section v-if="runningSessions.length > 0" class="sessions-section">
            <h2>{{ t('home.runningSessions') }}</h2>
            <div class="session-list">
              <div
                v-for="session in runningSessions"
                :key="session.id"
                class="session-card session-running"
                @click="reconnectToSession(session.id)"
              >
                <div class="session-info">
                  <div class="session-title">
                    <span class="status-dot running"></span>
                    {{ session.title || session.shell }}
                  </div>
                  <div class="session-meta text-subtext">
                    {{ session.shell }} &middot; {{ formatDate(session.created_at) }}
                  </div>
                </div>
                <div class="session-action">
                  <span class="badge-running">{{ t('home.running') }}</span>
                </div>
                <button class="btn-delete-session" @click.stop="deleteSession(session.id)" :title="t('home.deleteSession')">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6" />
                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                  </svg>
                </button>
              </div>
            </div>
          </section>

          <section v-if="recentSessions.length > 0" class="sessions-section">
            <h2>{{ t('home.recentSessions') }}</h2>
            <div class="session-list">
              <div
                v-for="session in recentSessions"
                :key="session.id"
                class="session-card"
                @click="reconnectToSession(session.id)"
              >
                <div class="session-info">
                  <div class="session-title">
                    <span class="status-dot" :class="session.status"></span>
                    {{ session.title || session.shell }}
                  </div>
                  <div class="session-meta text-subtext">
                    {{ session.shell }} &middot; {{ formatDate(session.created_at) }}
                  </div>
                </div>
                <div class="session-action text-subtext">
                  {{ session.status || 'detached' }}
                </div>
                <button class="btn-delete-session" @click.stop="deleteSession(session.id)" :title="t('home.deleteSession')">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="3 6 5 6 21 6" />
                    <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2" />
                  </svg>
                </button>
              </div>
            </div>
          </section>
        </div>
      </div>
      <FileBrowser
        v-if="showFileBrowser && !settingsStore.sidebarOnLeft"
        :position="settingsStore.sidebarPosition"
        @close="closeFileBrowser"
      />
    </div>

    <StatusBar
      v-if="terminalStore.activeTab && !isSettingsTab"
      :shell="terminalStore.activeTab?.shell || ''"
      :status="terminalStore.activeTab?.status || ''"
      :connectionStatus="connectionStatus"
      :cols="terminalDims.cols"
      :rows="terminalDims.rows"
    />

    <!-- Shell selector dialog -->
    <Teleport to="body">
      <div v-if="showShellDialog" class="dialog-overlay" @click.self="showShellDialog = false">
        <div class="dialog-card">
          <h3>{{ t('home.newSession') }}</h3>

          <div class="form-group">
            <label>{{ t('home.shell') }}</label>
            <div class="shell-grid">
              <button
                v-for="shell in shells"
                :key="shell.value"
                class="shell-option"
                :class="{ active: selectedShell === shell.value }"
                @click="selectedShell = shell.value"
              >
                <span class="shell-icon">{{ shell.icon }}</span>
                <span>{{ shell.label }}</span>
              </button>
            </div>
          </div>

          <div class="form-group">
            <label>{{ t('home.titleOptional') }}</label>
            <input v-model="sessionTitle" type="text" :placeholder="t('home.titlePlaceholder')" />
          </div>

          <div class="form-group">
            <label>{{ t('home.cwdOptional') }}</label>
            <input v-model="sessionCwd" type="text" :placeholder="t('home.cwdPlaceholder')" />
          </div>

          <div class="dialog-actions">
            <button class="btn-secondary" @click="showShellDialog = false">{{ t('home.cancel') }}</button>
            <button class="btn-primary" @click="createNewSession" :disabled="creating">
              {{ creating ? t('home.creating') : t('home.create') }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.terminal-page {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--bg);
}

.terminal-header {
  display: flex;
  align-items: stretch;
  height: 36px;
  background: var(--bg-deep);
  flex-shrink: 0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 0 10px;
  flex-shrink: 0;
}

.btn-home {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 26px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--subtext);
  transition: all var(--transition);
}

.btn-home:hover {
  background: var(--surface);
  color: var(--text);
}

.header-brand {
  font-weight: 600;
  font-size: 13px;
  color: var(--subtext);
  white-space: nowrap;
}

.header-tabs {
  flex: 1;
  min-width: 0;
  height: 36px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  flex-shrink: 0;
}

.toolbar-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--subtext);
  transition: all var(--transition);
  cursor: pointer;
}

.toolbar-btn:hover {
  background: var(--surface);
  color: var(--text);
}

.toolbar-btn.active {
  background: var(--surface);
  color: var(--accent);
}

.user-menu-wrapper {
  position: relative;
}

.user-label {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--subtext);
  font-size: 12px;
  cursor: pointer;
  transition: all var(--transition);
}

.username {
  color: var(--subtext);
  font-size: 12px;
}

.user-avatar {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  object-fit: cover;
}

.user-label:hover {
  background: var(--surface);
  color: var(--text);
}

.user-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  min-width: 140px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 4px;
  z-index: 9999;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.2);
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 8px 12px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--text);
  font-size: 12px;
  text-align: left;
  cursor: pointer;
  transition: background var(--transition);
}

.dropdown-item:hover {
  background: var(--overlay);
}

.terminal-body {
  flex: 1;
  overflow: hidden;
  position: relative;
}

.terminal-main {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.welcome-page {
  height: 100%;
  overflow-y: auto;
  padding: 40px;
  max-width: 900px;
  margin: 0 auto;
  width: 100%;
  box-sizing: border-box;
}

.welcome-section {
  margin-bottom: 32px;
}

.welcome-section h1 {
  font-size: 28px;
  font-weight: 700;
  margin-bottom: 6px;
}

.accent {
  color: var(--accent);
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 32px;
}

.stat-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  padding: 20px;
  text-align: center;
}

.stat-value {
  font-size: 32px;
  font-weight: 700;
  margin-bottom: 4px;
}

.stat-label {
  font-size: 13px;
}

.actions-section {
  display: flex;
  gap: 12px;
  margin-bottom: 40px;
}

.btn-new-terminal {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 24px;
  background: var(--accent);
  color: white;
  border: none;
  border-radius: var(--radius);
  font-size: 14px;
  font-weight: 600;
  transition: background var(--transition);
}

.btn-new-terminal:hover {
  background: var(--accent-hover);
}

.sessions-section {
  margin-bottom: 32px;
}

.sessions-section h2 {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 12px;
}

.session-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.session-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  cursor: pointer;
  transition: all var(--transition);
}

.session-card:hover {
  background: var(--surface-hover);
  border-color: var(--accent);
}

.session-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 500;
  margin-bottom: 2px;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--overlay);
}

.status-dot.running {
  background: var(--success);
  box-shadow: 0 0 6px rgba(166, 227, 161, 0.4);
}

.session-meta {
  font-size: 12px;
  padding-left: 16px;
}

.session-action {
  font-size: 13px;
}

.badge-running {
  display: inline-block;
  padding: 2px 10px;
  background: rgba(166, 227, 161, 0.12);
  color: var(--success);
  border-radius: 10px;
  font-size: 12px;
  font-weight: 500;
}

.btn-delete-session {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background: transparent;
  border: none;
  border-radius: var(--radius);
  color: var(--subtext);
  cursor: pointer;
  transition: all var(--transition);
  flex-shrink: 0;
}

.btn-delete-session:hover {
  background: rgba(243, 139, 168, 0.15);
  color: var(--error);
}

/* Shell dialog */
.dialog-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
}

.dialog-card {
  width: 440px;
  max-width: 90vw;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  padding: 28px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
}

.dialog-card h3 {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: var(--subtext);
  margin-bottom: 6px;
}

.form-group input {
  width: 100%;
  padding: 9px 12px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  outline: none;
  transition: border-color var(--transition);
  box-sizing: border-box;
}

.form-group input:focus {
  border-color: var(--accent);
}

.shell-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}

.shell-option {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 12px 8px;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-size: 13px;
  transition: all var(--transition);
  cursor: pointer;
}

.shell-option:hover {
  border-color: var(--accent);
}

.shell-option.active {
  border-color: var(--accent);
  background: rgba(124, 58, 237, 0.12);
}

.shell-icon {
  font-size: 20px;
}

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 24px;
}

.btn-secondary {
  padding: 9px 18px;
  background: transparent;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  font-size: 13px;
  transition: all var(--transition);
  cursor: pointer;
}

.btn-secondary:hover {
  background: var(--bg);
}

.btn-primary {
  padding: 9px 18px;
  background: var(--accent);
  border: none;
  border-radius: var(--radius);
  color: white;
  font-size: 13px;
  font-weight: 600;
  transition: background var(--transition);
  cursor: pointer;
}

.btn-primary:hover:not(:disabled) {
  background: var(--accent-hover);
}

.btn-primary:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}
</style>
