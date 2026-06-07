<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { Terminal } from 'xterm'
import { FitAddon } from 'xterm-addon-fit'
import { SearchAddon } from 'xterm-addon-search'
import { WebLinksAddon } from 'xterm-addon-web-links'
import 'xterm/css/xterm.css'
import { TerminalWebSocket } from '../../services/terminal-ws.js'

const props = defineProps({
  sessionId: {
    type: String,
    required: true
  }
})

const emit = defineEmits(['resize', 'connection-change'])

const terminalEl = ref(null)
let terminal = null
let fitAddon = null
let searchAddon = null
let wsConnection = null
let resizeObserver = null

onMounted(() => {
  initTerminal()
})

onUnmounted(() => {
  cleanup()
})

function initTerminal() {
  terminal = new Terminal({
    cursorBlink: true,
    cursorStyle: 'block',
    cursorWidth: 2,
    scrollback: 5000,
    fontSize: 14,
    fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', Menlo, monospace",
    lineHeight: 1.3,
    allowProposedApi: true,
    theme: {
      background: '#1e1e2e',
      foreground: '#cdd6f4',
      cursor: '#f5e0dc',
      cursorAccent: '#1e1e2e',
      selectionBackground: '#585b7066',
      selectionForeground: '#cdd6f4',
      black: '#45475a',
      red: '#f38ba8',
      green: '#a6e3a1',
      yellow: '#f9e2af',
      blue: '#89b4fa',
      magenta: '#f5c2e7',
      cyan: '#94e2d5',
      white: '#bac2de',
      brightBlack: '#585b70',
      brightRed: '#f38ba8',
      brightGreen: '#a6e3a1',
      brightYellow: '#f9e2af',
      brightBlue: '#89b4fa',
      brightMagenta: '#f5c2e7',
      brightCyan: '#94e2d5',
      brightWhite: '#a6adc8'
    }
  })

  fitAddon = new FitAddon()
  searchAddon = new SearchAddon()

  terminal.loadAddon(fitAddon)
  terminal.loadAddon(searchAddon)
  terminal.loadAddon(new WebLinksAddon())

  terminal.open(terminalEl.value)

  // Initial fit
  requestAnimationFrame(() => {
    fitAddon.fit()
    emit('resize', { cols: terminal.cols, rows: terminal.rows })
  })

  // Setup resize observer
  resizeObserver = new ResizeObserver(() => {
    if (fitAddon) {
      requestAnimationFrame(() => {
        try {
          fitAddon.fit()
          emit('resize', { cols: terminal.cols, rows: terminal.rows })
          if (wsConnection) {
            wsConnection.sendResize(terminal.cols, terminal.rows)
          }
        } catch {
          // Ignore fit errors during cleanup
        }
      })
    }
  })
  resizeObserver.observe(terminalEl.value)

  // Connect WebSocket
  wsConnection = new TerminalWebSocket(props.sessionId, terminal, {
    onConnect: () => {
      emit('connection-change', 'connected')
      wsConnection.sendResize(terminal.cols, terminal.rows)
    },
    onDisconnect: () => {
      emit('connection-change', 'disconnected')
    }
  })
  wsConnection.connect()

  terminal.focus()
}

function cleanup() {
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }
  if (wsConnection) {
    wsConnection.disconnect()
    wsConnection = null
  }
  if (terminal) {
    terminal.dispose()
    terminal = null
  }
}

function focus() {
  terminal?.focus()
}

function fit() {
  if (fitAddon) {
    fitAddon.fit()
    emit('resize', { cols: terminal.cols, rows: terminal.rows })
  }
}

function getTerminal() {
  return terminal
}

function openSearch() {
  // SearchAddon doesn't have a built-in UI in v0.13
  // We'll just focus the terminal for now
  terminal?.focus()
}

function closeSearch() {
  terminal?.focus()
}

defineExpose({ focus, fit, getTerminal, openSearch, closeSearch })
</script>

<template>
  <div class="terminal-pane">
    <div ref="terminalEl" class="terminal-container"></div>
  </div>
</template>

<style scoped>
.terminal-pane {
  width: 100%;
  height: 100%;
  padding: 4px;
  background: #1e1e2e;
}

.terminal-container {
  width: 100%;
  height: 100%;
}

.terminal-container :deep(.xterm) {
  height: 100%;
}

.terminal-container :deep(.xterm-viewport) {
  overflow-y: auto;
}
</style>
