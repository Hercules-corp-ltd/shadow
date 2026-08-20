/**
 * The small behaviours: scrambling text, magnetic buttons, the sliding marker.
 *
 * All three share one rule — they animate on a time constant, not a per-frame
 * constant, so they behave identically at 60 and 120 Hz. See `approach` in
 * loop.js for why that matters.
 */

import { approach, springStep } from './loop.js';

/* Characters the scramble draws from. Deliberately narrow: Greek capitals plus
 * a few technical glyphs, so the churn reads as "this is being derived" rather
 * than as generic matrix rain. */
const CHURN = 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ0123456789/\\|<>=+·';

/**
 * Resolve text left-to-right out of noise.
 *
 * Each character has its own start time, spread across the run by `wave`, so
 * the line settles as a front moving across it rather than all at once. A
 * character that has not started yet shows a random glyph, re-rolled at
 * `churn` probability per frame — re-rolling every frame looks like static and
 * costs legibility, which defeats the point.
 */
export function scramble(el, text, tune, done) {
  const n = text.length;
  const starts = new Array(n);
  for (let i = 0; i < n; i++) {
    // Slight jitter so the front is ragged rather than a ruler edge.
    const base = (i / Math.max(1, n - 1)) * tune.scrambleWave;
    starts[i] = base + (Math.random() - 0.5) * tune.scrambleJitter * 0.2;
  }

  const t0 = performance.now();
  const total = tune.scrambleMs;
  let raf = 0;

  const step = (now) => {
    const p = Math.min(1, (now - t0) / total);
    let out = '';
    let settled = 0;
    for (let i = 0; i < n; i++) {
      const ch = text[i];
      if (ch === ' ' || ch === '\n') { out += ch; settled++; continue; }
      const local = (p - starts[i]) / Math.max(0.0001, 1 - tune.scrambleWave);
      if (local >= 1) { out += ch; settled++; }
      else if (local <= 0) out += CHURN[(Math.random() * CHURN.length) | 0];
      else {
        out += Math.random() < tune.scrambleChurn
          ? CHURN[(Math.random() * CHURN.length) | 0]
          : (Math.random() < local ? ch : CHURN[(Math.random() * CHURN.length) | 0]);
      }
    }
    el.textContent = out;
    if (settled === n) {
      el.textContent = text;
      el.classList.remove('is-scrambling');
      done && done();
      return;
    }
    raf = requestAnimationFrame(step);
  };

  el.classList.add('is-scrambling');
  raf = requestAnimationFrame(step);
  return () => cancelAnimationFrame(raf);
}

/**
 * Buttons that lean toward the cursor.
 *
 * The label moves further than the box (`labelParallax` > 1), which is the
 * whole trick — equal movement reads as the button sliding, unequal movement
 * reads as the button having depth. Displacement is capped so the control never
 * separates from where it is actually clickable.
 */
export function createMagnet(el, tune) {
  const label = el.querySelector('[data-magnet-label]') || el.firstElementChild;
  const state = { x: 0, y: 0, tx: 0, ty: 0, hover: 0 };

  function point(px, py) {
    const r = el.getBoundingClientRect();
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const dx = px - cx;
    const dy = py - cy;
    const dist = Math.hypot(dx, dy);
    const reach = Math.max(r.width, r.height) / 2 + tune.magnetRadius;
    if (dist > reach) { state.tx = 0; state.ty = 0; state.hover = 0; return; }
    const f = (1 - dist / reach) * tune.magnetStrength;
    state.tx = Math.max(-tune.magnetMax, Math.min(tune.magnetMax, dx * f));
    state.ty = Math.max(-tune.magnetMax, Math.min(tune.magnetMax, dy * f));
    state.hover = 1;
  }

  function release() { state.tx = 0; state.ty = 0; state.hover = 0; }

  function tick(dt) {
    state.x = approach(state.x, state.tx, dt, tune.magnetEaseMs);
    state.y = approach(state.y, state.ty, dt, tune.magnetEaseMs);
    el.style.transform = `translate3d(${state.x.toFixed(2)}px, ${state.y.toFixed(2)}px, 0)`;
    if (label) {
      const k = tune.magnetLabelParallax;
      label.style.transform =
        `translate3d(${(state.x * (k - 1)).toFixed(2)}px, ${(state.y * (k - 1)).toFixed(2)}px, 0)`;
    }
  }

  return { point, release, tick, state };
}

/**
 * The marker that slides between nav items.
 *
 * Two parts: the marker itself on a spring, and a trailing copy on a slower
 * exponential lag. The gap between them is the streak — no particles, no blur
 * filter, just two rectangles and the fact that one is always behind.
 */
export function createMarker(tune) {
  const head = { x: 0, v: 0 };
  let tail = 0;
  let width = 0;
  let alpha = 0;
  let started = false;

  return {
    tick(target, targetW, visible, dt) {
      if (!started && target != null) { head.x = target; tail = target; width = targetW; started = true; }
      if (target != null) {
        springStep(head, target, dt, tune.markerOmega, tune.markerZeta);
        width = approach(width, targetW, dt, tune.markerEaseMs);
      }
      tail = approach(tail, head.x, dt, tune.markerTrailMs);
      alpha = approach(alpha, visible ? 1 : 0, dt, tune.hoverFadeMs);
      return { x: head.x, tail, width, alpha };
    },
  };
}
