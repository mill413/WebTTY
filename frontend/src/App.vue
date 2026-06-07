<script setup>
import { useThemeStore } from './stores/theme'

const themeStore = useThemeStore()
themeStore.apply()
</script>

<template>
  <router-view />
</template>

<style>
/* App-level styles are in global.css */
</style>
