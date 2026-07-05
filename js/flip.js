// FLIP transitions for the dot language. Elements carrying `data-flip` keys
// are matched across a DOM mutation and animated from their old position to
// their new one — dots travel between layouts instead of views switching.

/**
 * Run `mutate` (which swaps/reflows DOM inside `canvas`), then animate every
 * [data-flip] element from its previous rect to its new one. Elements whose
 * size changed scale; same-size elements just translate. New keys fade in.
 */
export function flipDots(canvas, mutate) {
  const before = new Map();
  for (const el of canvas.querySelectorAll('[data-flip]')) {
    before.set(el.dataset.flip, el.getBoundingClientRect());
  }

  mutate();

  for (const el of canvas.querySelectorAll('[data-flip]')) {
    const first = before.get(el.dataset.flip);

    if (!first) {
      el.style.transition = 'none';
      el.style.opacity = '0';
      requestAnimationFrame(() => {
        el.style.transition = 'opacity var(--motion-base) var(--motion-ease)';
        el.style.opacity = '';
        el.addEventListener('transitionend', () => { el.style.transition = ''; }, { once: true });
      });
      continue;
    }

    const now = el.getBoundingClientRect();
    const dx = first.left - now.left;
    const dy = first.top - now.top;
    const sx = now.width ? first.width / now.width : 1;
    const sy = now.height ? first.height / now.height : 1;
    if (!dx && !dy && sx === 1 && sy === 1) continue;

    el.style.transformOrigin = 'top left';
    el.style.transition = 'none';
    el.style.transform = `translate(${dx}px, ${dy}px) scale(${sx}, ${sy})`;
    requestAnimationFrame(() => {
      el.style.transition = 'transform var(--motion-base) var(--motion-ease)';
      el.style.transform = '';
      el.addEventListener('transitionend', () => {
        el.style.transition = '';
        el.style.transformOrigin = '';
      }, { once: true });
    });
  }
}

/**
 * Animate an element's height across an inner-content swap, so the raised
 * card stretches in sync with translating siblings (same duration + easing).
 */
export function animateHeight(el, mutate) {
  const oldH = el.offsetHeight;
  mutate();
  const newH = el.offsetHeight;
  if (oldH === newH) return;
  el.style.height = `${oldH}px`;
  el.style.overflow = 'hidden';
  void el.offsetHeight; // commit the starting height
  el.style.transition = 'height var(--motion-base) var(--motion-ease)';
  el.style.height = `${newH}px`;
  el.addEventListener('transitionend', () => {
    el.style.height = '';
    el.style.overflow = '';
    el.style.transition = '';
  }, { once: true });
}
