/**
 * The rails.
 *
 * A page that moves has to move THROUGH something. The reel pans and the camera
 * pushes in, and until now the only fixed structure either of them travelled
 * past was a field of dots. These are the rest of that structure: hairline
 * vertical rules standing in the same 45px grid the dots stand in, with short
 * bright segments running up them at four different rates.
 *
 * The rules themselves never move. That is the whole trick — they are the
 * fixed thing and all the parallax is in the light travelling along them, so
 * there is never a frame in which a 1px line is resampled sideways.
 *
 * ## Where they stand
 *
 * `.grid` is a 45px tile carrying an UNPOSITIONED radial-gradient, so its dots
 * sit at the centre of each cell: x = 22.5 + 45k, measured from the left edge
 * of the viewport. Rails at 45k would miss every dot by half a cell. Every
 * third of those columns carries a rail, generated outward from the centre cell
 * in symmetric PAIRS — a pair is taken only if both halves fit. Walking
 * outward from `first = centreK % stride` instead was symmetric about the
 * centre CELL rather than about the viewport, and truncated only on the right:
 * at 375px it produced rails at x = 22.5 and 202.5 and nothing right of centre.
 *
 * Two more rails land where `.column`'s left and right borders used to be,
 * measured from layout rather than recomputed from the `min(736px, 100vw-44px)`
 * in the stylesheet — a second source of truth there would go stale the first
 * time anyone touched `--col`.
 *
 * They do not sit ON those borders; they REPLACE them. styles.css turns
 * `.column`'s border-color transparent while the loop is running, because two
 * hairlines cannot coincide by being drawn twice: 0.055 over 0.055 composites
 * to 0.107, which puts a band twice as bright as the rail on exactly the
 * column's vertical extent. It is all columns, not just `#scene > .column`,
 * because the recursion clone is a `.column` too and at the seam it renders at
 * 1:1 — leaving its borders in would hand a short hard hairline over to a
 * full-height gradient one frame later.
 *
 * Those two are pinned to where the column sits AT REST. As the camera pushes
 * in, the page scales away from them and they stay: the page leaves the
 * structure behind.
 *
 * ## Surviving the wrap
 *
 * `pos` is a sawtooth — it runs 0 -> LOOP_LENGTH and drops back to nearly 0 —
 * so anything driven straight off it jumps once a lap. The segments are driven
 * off a phase instead:
 *
 *     A(pos, t) = offset - n * (pos / LOOP_LENGTH) - drift * t
 *     phase     = A - floor(A)                                  // 0..1
 *
 * with `n` a WHOLE number of laps per loop. Then A(L, t) = A(0, t) - n, and
 * frac(x - n) === frac(x) for integer n, so the phase at the end of the loop IS
 * the phase at the start. `drift` is a function of clock time, which never
 * wraps.
 *
 * In practice the loop wraps from L - d to e rather than to exactly zero. The
 * phase then advances by n * (d + e) / L, which is precisely what a step of
 * that size does anywhere else. The wrap frame is arithmetically identical to
 * every other frame — no branch, no special case, no cover.
 *
 * Note what is NOT done. The phase is never `(pos % period) / period`.
 * LOOP_LENGTH is 5800 = 2^3 * 5^2 * 29, so a rail at n = 3 has a period of
 * 1933.33...px — not a whole number of pixels, and a rounding scar once a lap.
 * What has to be integral is the COUNT of periods per lap, not the length of
 * one, and frac(n * pos / L) is the form that makes that exact for every n.
 * n = 2, 5 and 8 all divide 5800 (2900, 1160, 725); n = 3 does not, and it is
 * in the set on purpose to prove the point. Nothing depends on the section
 * count — only on integrality.
 *
 * The other half of surviving the wrap is that phase 0 and phase 1 are the same
 * point on the rail but opposite ends of the screen, so the recycle has to
 * happen where nobody can see it. A segment of length H, stretched by at most
 * S, parked at `top: -H` and translated to
 *
 *     y = phase * (vh + 2 * PAD) - PAD,     PAD = H * (S + 1) / 2 + 4
 *
 * covers [y - H/2 - sH/2, y - H/2 + sH/2] on screen. At phase 0 the BOTTOM of
 * that is -H/2 - PAD + sH/2 <= -H - 4; at phase 1 the TOP is
 * vh + PAD - H/2 - sH/2 >= vh + 4. With H = 128 and S = 3 those are -132px and
 * vh + 4px. Nothing here is hidden by luck, and nothing by something else being
 * opaque.
 *
 * ## Why DOM and not canvas
 *
 * Crispness decides it. These are 1px rules, and a 1px rule is either exactly
 * on a device pixel or it is two grey columns. As DOM each rail is an element
 * whose `left` is snapped to a whole device pixel once per resize and then
 * never touched. On a canvas the same line needs the dpr transform plus a
 * half-pixel offset, and has to be re-rasterised, gradients and all, at full
 * viewport size every frame.
 *
 * And it composes with #motes. That canvas is `mix-blend-mode: plus-lighter` at
 * z-index 22, and a blend mode composites against its BACKDROP. Leaving the
 * rails as ordinary alpha at z-index 21 means the dust blends over them for
 * free and the page keeps exactly one full-viewport blend group instead of two.
 * The cost that buys is stated rather than waved at: sixteen promoted layers
 * sit inside that blend backdrop, which is the case where Blink is most likely
 * to fold promotion back into the flattened root. It has not been profiled.
 *
 * ## The one thing deliberately not done
 *
 * The rails do not spread outward with the camera. It would strengthen the
 * "through" reading, but there is no way to move a 1px line horizontally
 * without landing it between device pixels — either a fractional transform,
 * which resamples it into two grey columns, or a per-frame `left` write, which
 * is a layout per rail per frame. The crispness is the entire reason this is
 * DOM; spending it on that would be spending the argument.
 */

/** Length of one travelling segment, in CSS px. */
const SEG = 128;
/** The most a segment ever stretches under speed. */
const STRETCH = 3;
/** How far past each edge a segment parks, so the recycle is never seen. */
const PAD = (SEG * (STRETCH + 1)) / 2 + 4;   // 260

/** `.grid` is a 45px cell with its dot in the MIDDLE of it. */
const CELL = 45;
const DOT = CELL / 2;
/** Every third dot column carries a rail; every second on a narrow screen. */
const STRIDE = 3;
/** The width at which the column's spines stop being worth drawing. */
const NARROW = 820;

/**
 * Laps per loop, segments per rail, hairline alpha, segment brightness.
 *
 * `n` must be a whole number; that is the entire wrap guarantee.
 *
 * SPINE.rule is exactly --rule, because these ARE the layout's hairlines now.
 * SPINE.lit is 0.60, BELOW the innermost tier's 0.72, so the "fast and bright
 * near the middle, slow and dim in the margins" reading survives the fact that
 * at 1280px the spines sit at d = 0.575 — well outside the centre band. At 1.00
 * they were the two brightest travelling segments on screen and furthest from
 * the centre, which is the opposite of the model.
 */
const SPINE = { n: 5, segs: 2, rule: 0.055, lit: 0.60 };
const TIERS = [
  { n: 8, segs: 2, rule: 0.040, lit: 0.72 },   // near the middle: fast, bright
  { n: 3, segs: 1, rule: 0.030, lit: 0.50 },
  { n: 2, segs: 1, rule: 0.022, lit: 0.34 },   // out in the margins: slow, dim
];

const frac = (x) => x - Math.floor(x);

export function createRails({ length, columnEl, sceneEl }) {
  // Built here rather than in index.html: with scripting off there is no scroll
  // loop, and a decorative cage over the <noscript> layout would be a worse
  // page than no cage at all.
  const root = document.createElement('div');
  root.className = 'rails';
  root.id = 'rails';
  root.setAttribute('aria-hidden', 'true');
  root.style.setProperty('--seg-h', `${SEG}px`);
  document.body.append(root);

  /** Flat list of every segment; the per-frame loop touches nothing else. */
  let segs = [];
  let vw = 0, vh = 0, span = 0;
  let hotShown = -1;

  /**
   * The two borders of the real content column, measured with the camera's
   * transform off — the same trick camera.measure() and recursion.ensure() use,
   * and for the same reason: during the loop `.scene` is scaled by up to 7.3, so
   * a live rect is the wrong number by that factor. One synchronous layout, on
   * resize only.
   */
  function columnEdges() {
    if (!columnEl || vw <= NARROW) return [];
    const prev = sceneEl ? sceneEl.style.transform : '';
    if (sceneEl) sceneEl.style.transform = 'none';
    const b = columnEl.getBoundingClientRect();
    if (sceneEl) sceneEl.style.transform = prev;
    if (!(b.width > 2)) return [];
    return [b.left, b.right - 1];               // each border is its own pixel
  }

  function build() {
    root.textContent = '';
    segs = [];
    if (vw < 2 || vh < 2) return;

    const dpr = Math.min(3, window.devicePixelRatio || 1);
    /* Whole device pixels only. A hairline at x.5 on a 1x screen is two grey
       columns, which is the exact cheapness this layer exists to avoid. At odd
       viewport widths this puts the rail up to 0.5/dpr px from where the border
       used to be — that is the point of snapping, not a defect in it. */
    const snap = (x) => Math.round(x * dpr) / dpr;

    const cx = vw / 2;
    const edges = columnEdges();
    // k carries a +0.37 on the spines so a spine and a grid rail of the same
    // index cannot draw the same offset seed.
    const picks = edges.map((x) => ({ x, k: Math.round((x - DOT) / CELL) + 0.37, spine: true }));

    // 90px on a phone (the spines are gone there and 180px left one or two
    // lines in the whole viewport), 135px on desktop.
    const stride = vw <= NARROW ? 2 : STRIDE;
    const centreK = Math.round((cx - DOT) / CELL);
    const xOf = (k) => DOT + k * CELL;
    const inView = (x) => x >= 2 && x <= vw - 2 && !edges.some((e) => Math.abs(e - x) < 14);

    // Outward in PAIRS, and a pair is taken only if both halves fit. Truncating
    // one side and not the other is what made 375px land a rail at x = 22.5 and
    // nothing right of centre.
    if (inView(xOf(centreK))) picks.push({ x: xOf(centreK), k: centreK, spine: false });
    for (let j = stride; ; j += stride) {
      const a = xOf(centreK - j);
      const b = xOf(centreK + j);
      if (a < 2 || b > vw - 2) break;           // both bounds are monotone in j
      if (inView(a)) picks.push({ x: a, k: centreK - j, spine: false });
      if (inView(b)) picks.push({ x: b, k: centreK + j, spine: false });
    }
    picks.sort((a, b) => a.x - b.x);

    for (const p of picks) {
      // Distance from the middle of the screen: 0 at the centre, 1 at either
      // edge. Depth radiates outward — near the column fast and bright, out in
      // the margins slow and almost gone. Same falloff `.grid` gets from its
      // radial mask, done with two numbers instead of a full-viewport mask layer
      // that would have to be re-rasterised whenever anything inside it moved.
      //
      // Spines take no falloff at all: they carry --rule exactly, because they
      // are the layout's hairlines rather than atmosphere, and 0.055 * 0.835
      // would have made the page's own structure dimmer than the stylesheet
      // says it is.
      const d = Math.min(1, Math.abs(p.x - cx) / Math.max(1, cx));
      const tier = p.spine ? SPINE : TIERS[d < 0.30 ? 0 : d < 0.62 ? 1 : 2];
      const falloff = p.spine ? 1 : 1 - 0.5 * d * d;

      const rail = document.createElement('span');
      rail.className = p.spine ? 'rail rail--spine' : 'rail';
      rail.style.left = `${snap(p.x)}px`;
      rail.style.setProperty('--rail-a', (tier.rule * falloff).toFixed(4));
      rail.style.setProperty('--seg-a', (tier.lit * falloff).toFixed(4));

      for (let s = 0; s < tier.segs; s++) {
        const el = document.createElement('span');
        el.className = 'rail__seg';
        rail.append(el);
        segs.push({
          el,
          n: tier.n,
          // Golden-ratio offsets, seeded from the rail's own GRID COLUMN rather
          // than from its index in a rebuilt array: a resize must not reshuffle
          // the field, and the array index changes whenever centreK moves.
          off: frac((p.k + 1) * 0.6180339887 + s / tier.segs),
          // Laps per second with nothing touching the wheel. Time-based, so it
          // is wrap-immune by construction.
          drift: 0.008 + 0.020 * frac((p.k + 1) * 0.7548776662),
        });
      }
      root.append(rail);
    }

    span = vh + PAD * 2;
  }

  function measure(w, h) {
    vw = w; vh = h;
    build();
  }

  /**
   * @param {number} pos    loop position, 0..length
   * @param {number} now    performance.now(), ms
   * @param {number} speed  main's speedEMA — px of loop travel per 16.7ms
   */
  function tick(pos, now, speed) {
    if (!segs.length) return;

    const u = pos / length;
    const t = now / 1000;

    // How hard the page is being pushed, 0..1. speedEMA is already smoothed on a
    // 120ms time constant in main, and loop.velocityOf() reports 0 on the wrap
    // frame rather than a spike of one loop length — so this is continuous
    // across the seam as well.
    const rush = 1 - Math.exp(-Math.max(0, speed) / 9);

    // Brightness, not opacity. This is written into the gradient's colour stops,
    // so what changes is how much light the segment emits; the element itself is
    // fully opaque from first paint to last. Written only when it has actually
    // moved, because a custom-property change repaints the gradient.
    const hot = 0.30 + rush * 0.62;
    if (Math.abs(hot - hotShown) > 0.008) {
      root.style.setProperty('--hot', hot.toFixed(3));
      hotShown = hot;
    }

    // Speed stretches the light into a trail. scaleY ONLY — a hairline scaled
    // horizontally stops being a hairline. Built once, not per segment.
    const tail = `, 0) scaleY(${(1 + rush * (STRETCH - 1)).toFixed(3)})`;

    for (const s of segs) {
      // Minus, so the light travels UP as the position increases: the same
      // direction the reel pans and the same direction the motes rise.
      const y = frac(s.off - s.n * u - s.drift * t) * span - PAD;
      s.el.style.transform = `translate3d(0, ${y.toFixed(2)}px${tail}`;
    }
  }

  /** Reduced motion and the static layout: the rules stay, the light stops. */
  function flatten() {
    root.classList.add('is-still');
    for (const s of segs) s.el.style.transform = '';
  }

  return { measure, tick, flatten, get el() { return root; } };
}
