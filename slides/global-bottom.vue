<template>
  <div class="slide-number">
    <SlideCurrentNo /> / <SlidesTotal />
  </div>
</template>

<style scoped>
.slide-number {
  position: absolute;
  bottom: 0.4rem;
  right: 0.6rem;
  font-size: 0.7rem;
  color: #94a3b8;
  font-family: 'JetBrains Mono', monospace;
  pointer-events: none;
  z-index: 10;
}
</style>
