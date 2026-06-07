<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import Split from 'split.js'

const props = defineProps({
  direction: {
    type: String,
    default: 'horizontal',
    validator: (v) => ['horizontal', 'vertical'].includes(v)
  },
  sizes: {
    type: Array,
    default: () => [50, 50]
  },
  minSize: {
    type: Number,
    default: 200
  }
})

const emit = defineEmits(['drag-end'])
const containerRef = ref(null)
let splitInstance = null

onMounted(() => {
  initSplit()
})

onUnmounted(() => {
  if (splitInstance) {
    splitInstance.destroy()
    splitInstance = null
  }
})

function initSplit() {
  const children = containerRef.value?.children
  if (!children || children.length < 2) return

  const selectors = Array.from(children).map((_, i) => `.split-pane-${i}`)

  splitInstance = Split(selectors.map((s) => containerRef.value.querySelector(s)), {
    direction: props.direction,
    sizes: props.sizes,
    minSize: props.minSize,
    gutterSize: 4,
    gutterStyle: () => {
      const gutter = document.createElement('div')
      gutter.style.backgroundColor = 'var(--border)'
      gutter.style.cursor = props.direction === 'horizontal' ? 'col-resize' : 'row-resize'
      return gutter
    },
    onDragEnd: (sizes) => {
      emit('drag-end', sizes)
    }
  })
}

watch(() => props.direction, () => {
  if (splitInstance) {
    splitInstance.destroy()
    splitInstance = null
  }
  initSplit()
})
</script>

<template>
  <div ref="containerRef" class="split-container">
    <slot />
  </div>
</template>

<style scoped>
.split-container {
  width: 100%;
  height: 100%;
  display: flex;
  overflow: hidden;
}
</style>
