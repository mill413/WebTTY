<script setup>
import { useI18n } from 'vue-i18n'

const props = defineProps({
  shell: { type: String, default: '' },
  status: { type: String, default: '' },
  connectionStatus: { type: String, default: 'disconnected' },
  leftItems: { type: Array, default: () => [] },
  rightItems: { type: Array, default: () => [] }
})

const { t } = useI18n()

function getShellName(shellPath) {
  if (!shellPath) return '--'
  return shellPath.split('/').pop()
}

function renderStatus(status) {
  return status || '--'
}
</script>

<template>
  <div class="status-bar">
    <div class="status-left">
      <template v-for="(item, index) in leftItems" :key="item.key">
        <div v-if="index > 0" class="status-divider"></div>
        <div class="status-item">
          <template v-if="item.key === 'shell'">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="4 17 10 11 4 5" />
              <line x1="12" y1="19" x2="20" y2="19" />
            </svg>
            <span>{{ getShellName(shell) }}</span>
          </template>
          <template v-else-if="item.key === 'status'">
            <span :class="{ 'text-success': status === 'running' }">{{ renderStatus(status) }}</span>
          </template>
          <template v-else-if="item.key === 'connection'">
            <span class="status-dot" :class="connectionStatus"></span>
            <span>{{ connectionStatus === 'connected' ? t('statusBar.connected') : t('statusBar.disconnected') }}</span>
          </template>
        </div>
      </template>
    </div>

    <div class="status-right">
      <template v-for="(item, index) in rightItems" :key="item.key">
        <div v-if="index > 0" class="status-divider"></div>
        <div class="status-item">
          <template v-if="item.key === 'shell'">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="4 17 10 11 4 5" />
              <line x1="12" y1="19" x2="20" y2="19" />
            </svg>
            <span>{{ getShellName(shell) }}</span>
          </template>
          <template v-else-if="item.key === 'status'">
            <span :class="{ 'text-success': status === 'running' }">{{ renderStatus(status) }}</span>
          </template>
          <template v-else-if="item.key === 'connection'">
            <span class="status-dot" :class="connectionStatus"></span>
            <span>{{ connectionStatus === 'connected' ? t('statusBar.connected') : t('statusBar.disconnected') }}</span>
          </template>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.status-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 24px;
  padding: 0 12px;
  background: var(--accent);
  color: rgba(255, 255, 255, 0.9);
  font-size: 11px;
  flex-shrink: 0;
}

.status-left,
.status-right {
  display: flex;
  align-items: center;
  gap: 4px;
}

.status-item {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 0 4px;
}

.status-divider {
  width: 1px;
  height: 12px;
  background: rgba(255, 255, 255, 0.2);
  margin: 0 4px;
}

.status-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.4);
}

.status-dot.connected {
  background: var(--success);
  box-shadow: 0 0 4px rgba(166, 227, 161, 0.6);
}

.status-dot.disconnected {
  background: var(--error);
}

.text-success {
  color: var(--success);
}
</style>
