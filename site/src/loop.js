/**
 * The scroll loop.
 *
 * The page never scrolls. `document.body` is exactly one viewport tall and the
 * wheel is consumed, so the scroll position is a float we own rather than a
 * value the browser owns. That is the whole reason a seamless infinite loop is
 * possible: you cannot wrap a native scrollbar without a visible jump.
 *
 * ## Two numbers
 *
 * `raw` is the accumulator — the wheel adds `deltaY` straight into it, touch
 * adds the drag distance. `shown` chases `raw` with an exponential ease and is
 * what actually drives rendering. Keeping them apart is what makes the wrap
 * invisible (below) and gives the whole page its weight.
 *
 * ## Why the ease is written the way it is
 *
 * `shown += (raw - shown) * (1 - Math.exp(-dt / TAU))`
 *
 * and never `shown += (raw - shown) * 0.1`. The second form is a different
 * animation on a 60 Hz laptop and a 120 Hz phone — the constant is per *frame*,
 * not per unit of time, so the page feels twice as fast on better hardware. The
 * exponential form asks "how much of the gap should close in `dt` milliseconds"
 * and is identical at any frame rate. Every eased value in this project uses it.
 *
 * ## The wrap
 *
 * When `shown` runs past the end we subtract the loop length from **both**
 * numbers in the same tick. The gap between them — which *is* the easing state —
 * is untouched, so there is no seam and no velocity discontinuity. Subtracting
 * from only the displayed value is the usual mistake and it stutters once per
 * lap.
 *
 * `hasWrapped` starts false so that on first load you cannot drag upward into
 * negative space before you have ever reached the end.
 */

export const DEFAULTS = {
  /** Milliseconds for the displayed value to close ~63% of the gap. */
  smoothingMs: 380,
  /** Touch drags are amplified; a finger moves far less than a wheel. */
  touchMultiplier: 2,
  /** Fling friction, expressed per 16.67 ms so it is frame-rate independent. */
  friction: 0.94,
  /** Below this velocity a fling is over. */
  flingCutoff: 0.015,
  /** Longest frame we will integrate; protects against tab-restore jumps. */
  maxFrameMs: 64,
};

export function createLoop({ length, onTick, config = {} }) {
  const cfg = { ...DEFAULTS, ...config };

  let raw = 0;
  let shown = 0;
  let hasWrapped = false;

  let velocity = 0; // px per ms, only during a touch fling
  let lastTouchY = null;
  let lastTouchAt = 0;
  let velocityEMA = 0;

  let glide = null; // { from, to, t0, ms, easeIn, easeOut }

  const clamp = (v) => (hasWrapped ? v : Math.max(0, v));

  /**
   * Asymmetric normalised ease.
   *
   * Ordinary cubic-bezier easings couple acceleration and deceleration. This
   * one lets them be dialled separately and still lands exactly on 0 and 1,
   * which matters when it is driving a position that must not overshoot into a
   * wrap.
   */
  function ease(t, easeIn, easeOut) {
    if (t >= 1) return 1;
    const n = Math.pow(t, easeIn);
    return n / (n + Math.pow(1 - t, easeOut));
  }

  function advance(dtMs, now) {
    const dt = Math.min(dtMs, cfg.maxFrameMs);

    // A fling in flight keeps feeding the accumulator.
    if (velocity !== 0) {
      raw = clamp(raw + velocity * dt);
      velocity *= Math.pow(cfg.friction, dt / 16.67);
      if (Math.abs(velocity) < cfg.flingCutoff) velocity = 0;
    }

    // A scripted glide overrides both numbers so it cannot fight the ease.
    if (glide) {
      const t = Math.min(1, (now - glide.t0) / glide.ms);
      const v = glide.from + (glide.to - glide.from) * ease(t, glide.easeIn, glide.easeOut);
      raw = v;
      shown = v;
      if (t >= 1) glide = null;
    } else {
      const gap = raw - shown;
      shown = Math.abs(gap) > 0.5
        ? shown + gap * (1 - Math.exp(-dt / cfg.smoothingMs))
        : raw;
    }

    // The wrap. Both numbers, same tick, same amount.
    if (shown >= length) {
      shown -= length;
      raw -= length;
      hasWrapped = true;
      if (glide) { glide.from -= length; glide.to -= length; }
    } else if (hasWrapped && shown < 0) {
      shown += length;
      raw += length;
      if (glide) { glide.from += length; glide.to += length; }
    }

    return shown;
  }

  // ---- input -------------------------------------------------------------

  /**
   * Anything inside `[data-native-scroll]` keeps its own scrolling.
   *
   * The loop takes the wheel globally and preventDefaults it, which is what
   * makes the page a fixed viewport — and it also means any panel with real
   * overflow is dead on arrival, because its wheel events never reach it. The
   * handler bails out when the event started inside an element that has asked
   * to be left alone, so a scroller inside an overlay behaves like a scroller.
   *
   * Checked with `closest` rather than a flag on the loop, so nothing has to
   * remember to tell the loop when a panel opens and closes.
   */
  function isNativeScroll(target) {
    return target instanceof Element && target.closest('[data-native-scroll]') !== null;
  }

  function onWheel(e) {
    if (isNativeScroll(e.target)) return;
    e.preventDefault();
    glide = null;
    raw = clamp(raw + e.deltaY);
  }

  function onTouchStart(e) {
    if (isNativeScroll(e.target)) { lastTouchY = null; return; }
    lastTouchY = e.touches.length === 1 ? e.touches[0].clientY : null;
    lastTouchAt = e.timeStamp;
    velocity = 0;
    velocityEMA = 0;
    glide = null;
  }

  function onTouchMove(e) {
    if (e.touches.length !== 1 || lastTouchY === null) return;
    if (isNativeScroll(e.target)) return;   // same exemption as the wheel
    e.preventDefault();
    const y = e.touches[0].clientY;
    const delta = (lastTouchY - y) * cfg.touchMultiplier;
    raw = clamp(raw + delta);

    const elapsed = e.timeStamp - lastTouchAt;
    if (elapsed > 0) {
      // Weighted toward the most recent sample so a flick at the end of a slow
      // drag still throws, which is what a thumb expects.
      velocityEMA = velocityEMA * 0.4 + (delta / elapsed) * 0.6;
    }
    lastTouchAt = e.timeStamp;
    lastTouchY = y;
  }

  function onTouchEnd() {
    lastTouchY = null;
    velocity = velocityEMA;
    velocityEMA = 0;
  }

  // ---- public ------------------------------------------------------------

  return {
    get position() { return shown; },
    get raw() { return raw; },
    get length() { return length; },
    get isGliding() { return glide !== null; },

    /** Distance moved this frame, signed. Used to drive speed-based effects. */
    velocityOf(prev) {
      const d = shown - prev;
      // Ignore the frame a wrap happened on, or speed spikes by `length`.
      return Math.abs(d) > length / 2 ? 0 : d;
    },

    /**
     * Shortest signed distance from the current position to a point on the
     * loop, in (-length/2, +length/2]. This is what makes stages seamless: a
     * stage's transform is a pure function of this number, and this number is
     * continuous across the wrap, so nothing needs to know a wrap happened.
     */
    distanceTo(point) {
      const half = length / 2;
      return ((point - shown + half) % length + length) % length - half;
    },

    glideTo(point, { ms = 1400, easeIn = 1.6, easeOut = 2.6 } = {}) {
      // Always travel the short way round, then let the wrap sort out the
      // bookkeeping if that takes us off either end.
      const target = shown + this.distanceTo(point);
      glide = { from: shown, to: target, t0: performance.now(), ms, easeIn, easeOut };
      velocity = 0;
    },

    nudge(px) {
      glide = null;
      raw = clamp(raw + px);
    },

    advance,

    attach(target = window) {
      target.addEventListener('wheel', onWheel, { passive: false });
      target.addEventListener('touchstart', onTouchStart, { passive: false });
      target.addEventListener('touchmove', onTouchMove, { passive: false });
      target.addEventListener('touchend', onTouchEnd);
      return () => {
        target.removeEventListener('wheel', onWheel);
        target.removeEventListener('touchstart', onTouchStart);
        target.removeEventListener('touchmove', onTouchMove);
        target.removeEventListener('touchend', onTouchEnd);
      };
    },
  };
}

/**
 * The one lerp shape used everywhere in this project.
 *
 * `k` is "how much of the remaining gap closes in `dt` ms", so behaviour is
 * identical at 60, 90 and 120 Hz.
 */
export function approach(current, target, dt, timeConstantMs) {
  const k = 1 - Math.exp(-Math.min(dt, 64) / timeConstantMs);
  return current + (target - current) * k;
}

/**
 * A damped spring, sub-stepped so it stays stable when a frame runs long.
 *
 * Used for anything that should overshoot slightly and settle rather than
 * easing politely into place — the marker under the nav, mostly. A single
 * Euler step at 15 fps with omega 30 explodes; sub-stepping to a fixed maximum
 * step does not.
 */
export function springStep(state, target, dtMs, omega = 30, zeta = 0.65) {
  const dt = Math.min(dtMs, 64) / 1000;
  const steps = Math.max(1, Math.ceil((dt * omega) / 0.5));
  const h = dt / steps;
  for (let i = 0; i < steps; i++) {
    state.v += (-2 * zeta * omega * state.v - omega * omega * (state.x - target)) * h;
    state.x += state.v * h;
  }
  return state.x;
}
