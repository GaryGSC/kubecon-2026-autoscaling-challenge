<script setup lang="ts">
import { ref } from 'vue'

defineProps<{ src: string }>()
// placeholder until the screenshot is dropped into slides/public
const missing = ref(false)
</script>

<template>
  <div class="shot">
    <img v-if="!missing" :src="src" @error="missing = true" />
    <div v-else class="shot-empty">📸 screenshot goes to <code>slides/public{{ src }}</code></div>
  </div>
</template>

<style scoped>
.shot {
  height: 78%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.shot img {
  max-height: 100%;
  max-width: 100%;
  border-radius: 6px;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.45);
}
.shot-empty {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px dashed var(--kc-lavender);
  border-radius: 8px;
  color: var(--kc-lavender);
  font-size: 1.1rem;
}
</style>
