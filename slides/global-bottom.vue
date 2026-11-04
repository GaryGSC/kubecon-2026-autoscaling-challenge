<template>
  <div v-if="$nav.currentPage > 1" class="slide-number">
    {{ $nav.currentPage }} / {{ $nav.total }}
  </div>
</template>

<style scoped>
.slide-number {
  position: absolute;
  bottom: 0.4rem;
  right: 0.6rem;
  font-size: 0.7rem;
  color: #fff;
  opacity: 0.35;
  font-family: 'JetBrains Mono', monospace;
  pointer-events: none;
  z-index: 10;
}
</style>
