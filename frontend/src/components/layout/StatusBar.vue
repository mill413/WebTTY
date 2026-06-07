<script setup>
const props = defineProps({
  shell: { type: String, default: '' },
  status: { type: String, default: '' },
  connectionStatus: { type: String, default: 'disconnected' },
  cols: { type: Number, default: 80 },
  rows: { type: Number, default: 24 }
})

function getShellName(shellPath) {
  if (!shellPath) return '--'
  return shellPath.split('/').pop()
}
</script>

<template>
  <div class="status-bar">
    <div class="status-left">
      <div class="status-item">
        <span class="status-dot" :class="connectionStatus"></span>
        <span>{{ connectionStatus === 'connected' ? 'Connected' : 'Disconnected' }}</span>
      </div>

      <div class="status-divider"></div>

      <div class="status-item" v-if="shell">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="4 17 10 11 4 5" />
          <line x1="12" y1="19" x2="20" y2="19" />
        </svg>
        <span>{{ getShellName(shell) }}</span>
      </div>

      <div class="status-divider" v-if="shell"></div>

      <div class="status-item" v-if="status">
        <span :class="{ 'text-success': status === 'running' }">{{ status }}</span>
      </div>
    </div>

    <div class="status-right">
      <div class="status-item">
        <span>{{ cols }} x {{ rows }}</span>
      </div>
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
  color: #a6e3a1;
}
</style>
