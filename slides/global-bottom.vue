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
  color: var(--kc-lavender);
  font-family: 'JetBrains Mono', monospace;
  pointer-events: none;
  z-index: 10;
}
</style>
