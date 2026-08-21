import { createLoop, approach } from './loop.js';
import { createMotes } from './motes.js';
import { createRails } from './rails.js';
import { createBackdrop } from './backdrop.js';
import { createCamera } from './camera.js';
import { createPanel } from './panel.js';
import { createMagnet, scramble } from './effects.js';
import { STAGES, STAGE_SPAN, ZOOM_SPAN, CLOSE_SPAN, LOOP_LENGTH, stagePosition } from './content.js';
import { TUNE, mountTunePane } from './tune.js';

const sceneEl = document.getElementById('scene');
const cardEl = document.getElementById('card');
const planeEl = document.getElementById('plane');
const ctaEl = document.getElementById('cta');
const canvas = document.getElementById('backdrop');
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');

/* ------------------------------------------------------------------ build */

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
}

const APPLE = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.8c0-2.4 2-3.6 2.1-3.6-1.1-1.7-2.9-1.9-3.6-1.9-1.5-.2-3 .9-3.7.9s-2-.9-3.2-.9C6.4 7.3 4.8 8.3 4 9.9c-1.7 2.9-.4 7.2 1.2 9.5.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8s1.9.8 3.2.8 2.2-1.2 3-2.3c.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.4-.9-2.4-3.9zM14 5.7c.7-.8 1.1-1.9 1-3-1 0-2.2.7-2.9 1.5-.6.7-1.1 1.8-1 2.9 1.1.1 2.2-.6 2.9-1.4z"/></svg>';
const DROID = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M17.6 9.5l1.6-2.8a.3.3 0 00-.5-.3l-1.6 2.8A9.6 9.6 0 0012 8c-1.8 0-3.5.4-5 1.2L5.3 6.4a.3.3 0 10-.5.3l1.6 2.8A8 8 0 002 16h20a8 8 0 00-4.4-6.5zM7.5 13.4a.9.9 0 110-1.8.9.9 0 010 1.8zm9 0a.9.9 0 110-1.8.9.9 0 010 1.8z"/></svg>';

function makeBtn({ label, state, icon, primary }) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = `btn ${primary ? 'btn--primary' : 'btn--secondary'}`;
  b.setAttribute('aria-disabled', 'true');
  const wrap = el('span', 'btn__label');
  wrap.dataset.magnetLabel = '';
  if (icon) {
    const s = document.createElement('span');
    s.innerHTML = icon;
    wrap.append(s.firstChild);
  }
  wrap.append(el('span', null, label));
  wrap.append(el('span', 'btn__state', state));
  b.append(wrap);
  b.addEventListener('click', () => announce(`${label}: not released yet.`));
  return b;
}

ctaEl.append(
  makeBtn({ label: 'Get it on iOS', state: 'Soon', icon: APPLE, primary: true }),
  makeBtn({ label: 'Get it on Android', state: 'Soon', icon: DROID, primary: false }),
);

let liveRegion = el('div', 'sr-only');
liveRegion.setAttribute('role', 'status');
liveRegion.setAttribute('aria-live', 'polite');
document.body.append(liveRegion);
function announce(msg) {
  liveRegion.textContent = '';
  requestAnimationFrame(() => { liveRegion.textContent = msg; });
}

function buildStage(stage, i) {
  const s = el('section', `stage stage--${stage.kind}`);
  s.dataset.stage = stage.id;
  s.dataset.index = String(i);
  s.setAttribute('aria-label', stage.title);
  if (stage.id === 'download') s.id = 'get';

  if (stage.relief) {
    const r = el('div', 'stage__relief');
    const img = new Image();
    img.src = `assets/img/${stage.relief}.webp`;
    img.alt = '';
    img.loading = 'lazy';
    r.append(img);
    s.append(r);
  }
  if (stage.god) {
    const g = el('div', 'stage__god');
    const img = new Image();
    img.src = `assets/gods/${stage.god}.svg`;
    img.alt = '';
    img.loading = 'lazy';
    g.append(img);
    s.append(g);
  }

  // The light that rakes across the stone as you pass.
  //
  // The reference drives a beam, a heat ramp and a flame off each section's
  // own progress — that is what stops its middle from being a slideshow of
  // static frames. Ours is colder because Shadow is: one hard-edged shaft of
  // warm light that sweeps the section as you traverse it, and a wash that
  // brightens as it arrives and dims as it leaves. Both are LIGHT, not
  // opacity on content — nothing dissolves.
  if (stage.kind !== 'features') s.append(el('div', 'stage__beam'));

  const inner = el('div', 'stage__inner');
  if (stage.eyebrow) inner.append(el('p', 'eyebrow', stage.eyebrow));
  if (stage.index) inner.append(el('span', 'stage__num', stage.index));

  const h = el('h2', 'stage__title', stage.title);
  h.dataset.scramble = stage.title;
  inner.append(h);

  if (stage.lead) inner.append(el('p', 'stage__lead', stage.lead));

  if (stage.facts) {
    const dl = el('dl', 'facts');
    for (const [k, v] of stage.facts) { dl.append(el('dt', null, k)); dl.append(el('dd', null, v)); }
    inner.append(dl);
  }

  if (stage.shots) {
    // A wall of the real app rather than a picture of it. The centre screen
    // sits forward; the two flanking it are pushed back and dimmed, so the
    // group reads as depth instead of as three thumbnails in a row.
    const wall = el('div', 'wall');
    for (const shot of stage.shots) {
      const fig = el('figure', 'wall__item');
      fig.style.setProperty('--depth', String(shot.depth));
      const img = new Image();
      img.src = `assets/shots/${shot.src}.png`;
      img.alt = `Shadow — the ${shot.label.toLowerCase()} screen`;
      img.loading = 'lazy';
      img.width = 1080; img.height = 2400;
      fig.append(img);
      fig.append(el('figcaption', null, shot.label));
      wall.append(fig);
    }
    inner.append(wall);
  }

  if (stage.cards) {
    const grid = el('div', 'ledger');
    for (const [n, head, body] of stage.cards) {
      const cell = el('div', 'ledger__cell');
      cell.append(el('span', 'ledger__num', n));
      cell.append(el('h3', 'ledger__head', head));
      cell.append(el('p', 'ledger__body', body));
      grid.append(cell);
    }
    inner.append(grid);
  }

  if (stage.platforms) {
    const grid = el('div', 'platforms');
    for (const p of stage.platforms) {
      const card = el('div', 'platform');
      card.append(el('h3', 'platform__name', p.name));
      card.append(el('p', 'platform__sub', p.sub));
      card.append(el('span', 'platform__state', p.state));
      card.append(el('p', 'platform__note', p.note));
      grid.append(card);
    }
    inner.append(grid);
  }
  if (stage.note) inner.append(el('p', 'stage__note', stage.note));

  if (stage.kind === 'recursion') {
    const dev = el('div', 'again');
    const screen = el('div', 'again__screen');
    screen.id = 'againScreen';
    // A live clone rather than a screenshot, so the thing you fly into can
    // never drift out of date with the thing it turns into. Inert and hidden
    // from assistive tech — it is scenery, and the real one is a tab stop away.
    const clone = document.querySelector('.column').cloneNode(true);
    clone.removeAttribute('id');
    for (const n of clone.querySelectorAll('[id]')) n.removeAttribute('id');
    clone.setAttribute('aria-hidden', 'true');
    clone.inert = true;
    // A device with a body, not a framed thumbnail.
    //
    // The reference's ending is a whole desktop application -- a rail of real
    // file names down the left, a canvas in the middle, a conversation panel
    // on the right -- and its landing page is a small thing sitting INSIDE the
    // canvas. That arrangement is the trick: the device is big enough to read
    // and inhabit, which leaves the page inside it far enough away to be
    // somewhere you travel TO.
    //
    // Ours was the inverse: a small box with a large page in it, so there was
    // nothing to look at and nowhere to go. Now it is the browser -- chrome, a
    // tab, an address, and a rail of the very sections you just walked, with
    // this page rendered small in the canvas.
    const chrome = el('div', 'again__chrome');
    chrome.append(el('span', 'again__dot'), el('span', 'again__dot'), el('span', 'again__dot'));
    const tab = el('span', 'again__tab');
    tab.append(el('span', 'again__favi'));
    tab.append(el('span', null, 'Shadow \u2014 forget me, on purpose'));
    chrome.append(tab);
    chrome.append(el('span', 'again__url', 'shadow.browser'));

    // The rail names the walk you have just taken. It is the ending's one
    // piece of wit: the sections are the browser's history.
    const rail = el('div', 'again__rail');
    rail.append(el('span', 'again__railcap', 'This session'));
    for (const [label, on] of [['Home', true], ['One phrase', false],
                               ['An identity per site', false], ['Mail that forgets', false],
                               ['Trackers', false], ['The ledger', false],
                               ['Get it', false]]) {
      rail.append(el('span', 'again__row' + (on ? ' is-on' : ''), label));
    }

    // The canvas holds a VIEWPORT, not a column.
    //
    // It used to hold the bare hero column at scale 0.32 — 236px wide inside a
    // 705px canvas, where the lead is 5.3px tall, both buttons 4.6px and the
    // wordmark 6.4px. `.again__page` is a stand-in viewport instead: measure()
    // sizes it to the exact box the real hero column is centred in and scales it
    // by canvasWidth / viewportWidth, so it fills the canvas the way a rendered
    // page fills a browser window — same column, much larger, with the ground,
    // the 45px grid, the topbar, the headline, the lead and both buttons around
    // it.
    //
    // The grid is cloned in explicitly because the real one is a SIBLING of
    // #scene, not a child, so no amount of cloning the column can reach it.
    //
    // NOT a clone of #scene, which is the obvious alternative and is wrong
    // twice. #scene is written to by camera.apply() every frame, and cloneNode
    // copies the inline style attribute, so a clone taken at any other moment
    // inherits a stale transform. And a second `.scene .column` in the document
    // would make createRecursion's selector correct only by document order — an
    // accident worth not depending on.
    const page = el('div', 'again__page');
    const gridCopy = document.querySelector('.grid').cloneNode(false);
    const view = el('div', 'again__view');
    view.append(clone);
    page.append(gridCopy, view);
    // Scenery, all of it. The clone is already inert and aria-hidden; saying it
    // again on the wrapper covers the ground and grid copies too.
    page.setAttribute('aria-hidden', 'true');
    page.inert = true;

    const canvasArea = el('div', 'again__canvas');
    canvasArea.append(page);

    screen.append(chrome);
    screen.append(rail);
    screen.append(canvasArea);
    dev.append(screen);
    s.append(dev);
  }

  s.append(inner);
  return s;
}

/*
 * The colonnade, inside the opening only.
 *
 * On the first pass this art was a full-bleed background on the hero, which
 * turned the whole page brown and dropped the type to roughly 40% contrast.
 * It belongs here instead: outside the phone you are looking at a product,
 * and going through the screen puts you in the building. Two plates at
 * different depths so the walls part as you walk.
 */
const plates = el('div', 'plates');
for (const [name, depth] of [['colonnade-far', 0.10], ['colonnade-near', 0.34]]) {
  const p = el('div', `plate plate--${name}`);
  p.dataset.depth = String(depth);
  p.style.backgroundImage = `url(assets/img/${name}.webp)`;
  plates.append(p);
}
planeEl.append(plates);

/*
 * One reel, panned.
 *
 * Stages used to be stacked on top of each other and cross-faded with a blur.
 * That is the thing that made the whole middle of the site feel like a
 * slideshow: nothing ever travels, it just swaps. They are laid end to end in
 * a strip now and the strip is translated, so one section genuinely leads to
 * the next and their edges meet. No opacity, no blur, anywhere.
 */
const reelZoom = el('div', 'reel-zoom');
const reel = el('div', 'reel');
const stageEls = STAGES.map(buildStage);
// Offsets are set in PIXELS by measure(), not percentages: a percentage top
// resolves against the REEL height (N viewports), so stage 5 landed at five
// times eight viewports instead of five, and every section past the first was
// parked miles below the fold.
stageEls.forEach((s) => reel.append(s));
reelZoom.append(reel);
planeEl.append(reelZoom);

/*
 * There is no section pill.
 *
 * It was a row of nine labels floating over the page, and on the hero it sat
 * squarely on top of the download buttons. A page whose whole job is one
 * gesture — scroll — does not need a table of contents for the gesture, and
 * the reference does not have one either. Keyboard users still get Home/End
 * and the arrows; see the keydown handler below.
 */

/* -------------------------------------------------------------- easing --- */

/*
 * Four shapes, and the reason there are exactly four.
 *
 * Everything in the ending is driven from `pos`, and `pos` is a loop. What
 * keeps the seam invisible is not that each value lands on the right number —
 * it is that each value lands on it at the right SPEED. A quantity that arrives
 * correct but moving stutters once per lap, and the join at LOOP_LENGTH is the
 * one join on this page where a stutter is unforgivable.
 *
 * The ease already in camera.js — n / (n + (1-t)^1.5) — is C1 but not C2 at its
 * top end. 1-e behaves like (1-t)^1.5, so e' vanishes like a square root while
 * e'' diverges: measured -5.66 at t = 0.9, -24.04 at 0.999, -75.14 at 0.9999,
 * unbounded. That is a move which holds its speed to the last pixel and then
 * hits a wall, which is precisely what the close felt like. None of the shapes
 * below have that property; each is flat to second order at both ends.
 */

/** Integral of `smoother` from 0 to x. The building block for flat-ended ramps. */
const rampArea = (x) => { const q = x * x * x * x; return q * (x * x - 3 * x + 2.5); };

/** Smootherstep: 0 and 1 at the ends, zero FIRST AND SECOND derivative at both. */
const smoother = (x) =>
  x <= 0 ? 0 : x >= 1 ? 1 : x * x * x * (x * (x * 6 - 15) + 10);

/**
 * A trapezoid velocity profile, integrated.
 *
 * Accelerates over `rIn`, holds a CONSTANT rate through the middle, bleeds off
 * over `rOut`. Both ramps are smootherstep, so the whole thing starts and stops
 * with zero speed and zero acceleration. `v` is exactly the constant that makes
 * the three branches agree in value and slope at both interior joins.
 *
 * The flat middle is the entire point. An ease whose velocity is a single hump
 * spends nearly all of its span either speeding up or slowing down; travel only
 * reads as travel when the rate is steady, and for a zoom "steady" means a
 * constant d(ln scale) / d(scroll). At (0.18, 0.34) the rate is dead flat
 * across 48% of the span at 1.35135x the average, and the last third is a long
 * clean deceleration into the wrap.
 */
function ramp(u, rIn, rOut) {
  if (u <= 0) return 0;
  if (u >= 1) return 1;
  const v = 1 / (1 - (rIn + rOut) / 2);   // peak rate; normalises the integral to 1
  if (u < rIn) return v * rIn * rampArea(u / rIn);
  if (u > 1 - rOut) return 1 - v * rOut * rampArea((1 - u) / rOut);
  return v * (rIn * 0.5 + (u - rIn));
}

/**
 * One late bump: zero value and zero slope at both ends, peaking at exactly 1.0
 * when x = 0.75. Added on top of a ramp it becomes a settle — the thing goes a
 * hair past its size and comes back, which is what makes an arrival read as
 * weight rather than as a number reaching its maximum.
 *
 * 89.9 is 1 / (0.75^6 * 0.25^2) = 89.897, i.e. whatever normalises the peak.
 */
const overshoot = (x) =>
  x <= 0 || x >= 1 ? 0 : 89.9 * x * x * x * x * x * x * (1 - x) * (1 - x);

/**
 * The reel's pan, landing instead of stopping.
 *
 * `idx` used to be `Math.min(cap, raw)`. That is continuous and its derivative
 * is not: the pan runs at vh/STAGE_SPAN — 1.286 px of travel per px of scroll
 * at 720p — right up to the clamp and is zero on the very next frame. It is the
 * largest velocity discontinuity on the page and it fires at the exact instant
 * the last section arrives, which is why the ending opened with a jolt and then
 * sat still for 560px.
 *
 * This bleeds the rate to zero instead. Velocity is (1 - smoother), because
 * rampArea' IS smoother, so the curve leaves the linear region at exactly rate
 * 1 and reaches exactly `cap` at rate 0, with zero acceleration at both ends. A
 * profile that starts at rate 1 and only ever decreases covers less ground than
 * it is given, so the landing borrows input: it spends 2L of `raw` to cover the
 * last L of `idx`. There is spare — `raw` reaches 9.25 by the end of the loop
 * and this needs 7.45.
 */
function softLand(raw, cap, L) {
  const from = cap - L;
  if (raw <= from) return raw;
  const span = 2 * L;
  const x = Math.min(span, raw - from);
  return from + x - span * rampArea(x / span);
}

/* The ending, in four numbers. Derived, not guessed — see the beat-one block in
 * frame() where each one is spent. */
const STAGE_LAND = 0.45;        // stage-spans of pan the last arrival lands over
const AGAIN_S0 = 0.45;          // device scale where the approach begins
const AGAIN_LAG = 0.30;         // viewport heights it trails the reel by at the start
const AGAIN_GROW_FROM = 0.45;   // fraction of the approach spent before it grows

/* Where the last stage actually comes to rest now that the pan lands rather
 * than clamping. stagePosition(7) = 4540 is where the OLD clamp bit; softLand
 * needs 2*STAGE_LAND of input to cover STAGE_LAND of output, so idx reaches
 * STAGES.length - 1 here instead. Aiming End at 4540 would leave the recursion
 * section (7 - 6.9297) * vh = 50.6px low at 720p. */
const LAST_STAGE_AT =
  ZOOM_SPAN + (STAGES.length - 1 + STAGE_LAND) * STAGE_SPAN;   // 4792

/**
 * The recursive close.
 *
 * The last stage contains a device whose screen holds a live clone of the
 * hero. This flies into that screen so the clone grows until it sits exactly
 * where the real hero sits — same width, same centre — at which point the loop
 * wraps and the real one takes over. Nothing fades and nothing cuts: the end
 * of the page literally contains its beginning.
 *
 * The target is measured against the REAL hero column rather than the
 * viewport, because that is what has to match at the seam. Matching the
 * viewport instead would land the clone at the right size but the wrong
 * position whenever the column is not exactly centred.
 */
function createRecursion(zoomEl) {
  let base = null;    // { cx, cy, w } of the clone column, unzoomed
  let baseKey = '';   // the transform state `base` was measured under
  let target = null;  // the real hero column's rect, at rest

  /*
   * Element handles, looked up once.
   *
   * Only their inline `style.transform` STRINGS are read per frame, which is a
   * CSSOM property read and forces nothing — that is the whole basis of the
   * cache below.
   */
  let sceneRef = null, reelRef = null, devRef = null;
  function refs() {
    if (!sceneRef) sceneRef = document.getElementById('scene');
    if (!reelRef) reelRef = zoomEl.querySelector('.reel');
    if (!devRef) devRef = zoomEl.querySelector('.again');
    return { sceneRef, reelRef, devRef };
  }

  /**
   * Everything the measurement below depends on, as a string.
   *
   * `base` is a function of exactly three transforms — the camera's on `.scene`,
   * the pan on `.reel`, and the approach's on `.again` — plus the viewport,
   * which measure() handles. Nothing else can move it. So if all three strings
   * are byte-identical to the ones the cached measurement was taken under, the
   * measurement is still valid, and re-taking it can only produce the same
   * numbers at the cost of two forced layouts.
   */
  function stateKey() {
    const r = refs();
    const a = r.sceneRef ? r.sceneRef.style.transform : '';
    const b = r.reelRef ? r.reelRef.style.transform : '';
    const c = r.devRef ? r.devRef.style.transform : '';
    return a + '|' + b + '|' + c;
  }

  function measure() {
    base = null;
    baseKey = '';
    // Viewport or fonts changed, so the hero's resting box has moved.
    target = null;
  }

  /**
   * Everything is measured with the zoom off, and in the zoom element's OWN
   * coordinates — offsets from its top-left corner.
   *
   * The first version passed viewport coordinates to `transform-origin`, which
   * is resolved against the element's own box. `.reel-zoom` sits inside a plane
   * that is itself translated and scaled by the camera, so its box is nowhere
   * near the viewport origin, and the scale pivoted around a point thousands of
   * pixels away: the clone finished 5827px wide instead of 736 and ten thousand
   * pixels above the fold.
   */
  function ensure() {
    // Cached against the transform state it was measured under.
    //
    // This was flatly uncached, with a comment insisting it had to be: an
    // earlier attempt cached it unconditionally, measured once on a frame where
    // the camera happened to be shut, got 39px instead of 309, and overshot the
    // whole close by a factor of eight. That comment was right about the hazard
    // and wrong about the remedy — the fix for "cached the wrong frame" is to
    // know WHICH frame you cached, not to refuse to cache.
    //
    // The cost it was paying is real and lands where it hurts most. The two
    // getBoundingClientRect calls below are separated from two style writes, so
    // each forces a synchronous layout of a document holding eight stages, a
    // cloned hero and the browser mock — and the close is the ONLY stretch of
    // the loop that does this. Measured at 390x844: 1.075ms per frame inside the
    // close against 0.272ms walking, a 4x step, on a desktop CPU. A phone is
    // several times slower again, and this is precisely the stretch that is
    // supposed to feel like flight.
    //
    // stateKey() reads three inline transform strings. A CSSOM property read
    // forces no layout, so a hit costs three string reads and a compare.
    //
    // Behaviour is preserved exactly, including the awkward case. apply() runs
    // BEFORE the reel and `.again` transforms are written for the current frame,
    // so a frame that jumps into the close from far away measures against the
    // previous frame's values and is wrong — as it always has been. The only
    // difference is that a stale reading is now cached under a stale KEY, so the
    // next frame, whose key differs, re-measures and corrects it. One frame
    // wrong either way; the cache cannot make it stick.
    const key = stateKey();
    if (base && key === baseKey) return base;

    const prev = zoomEl.style.transform;
    zoomEl.style.transform = 'none';
    // `.again` now carries the approach's own transform, and it is written
    // AFTER this call in frame(). It is identity for every pos >= 4792, so in
    // steady state this is a no-op — but a single frame that steps from before
    // the hold to inside the close (a hard flick, or glideTo, a 308px jump)
    // would otherwise measure the clone at grow < 1 and inflate Z for that
    // frame: grow = 0.7 gives Z = 2.60 instead of 1.818, a one-frame size pop.
    const dev = zoomEl.querySelector('.again');
    const prevDev = dev ? dev.style.transform : '';
    if (dev) dev.style.transform = 'none';
    const clone = zoomEl.querySelector('.again__screen .column');
    if (!clone) {
      zoomEl.style.transform = prev;
      if (dev) dev.style.transform = prevDev;
      return null;
    }
    const z0 = zoomEl.getBoundingClientRect();
    const b = clone.getBoundingClientRect();
    base = {
      // Local to the zoom element, not the viewport.
      cx: b.left + b.width / 2 - z0.left,
      cy: b.top + b.height / 2 - z0.top,
      w: Math.max(1, b.width),
      originLeft: z0.left,
      originTop: z0.top,
    };
    zoomEl.style.transform = prev;
    if (dev) dev.style.transform = prevDev;
    baseKey = key;
    return base;
  }

  function apply(u) {
    if (u <= 0) { zoomEl.style.transform = 'none'; return; }
    const b = ensure();
    if (!b) return;

    // Measured with the scene transform OFF, and held until the viewport moves.
    //
    // This is the whole seam. The target is not where the real hero is *now* —
    // during the close the camera is fully pushed in, so the hero column reads
    // as 5829px wide. It is where the hero will be one frame after the wrap,
    // when the camera is back at rest and the column is its plain 736px. Aiming
    // at the live rect matched that 5829 exactly and was, by construction,
    // eight times too big at the only instant that matters.
    //
    // Cached on a plain measure() invalidation rather than on a state key,
    // because unlike `base` this does not depend on the scroll position at all —
    // it is the column's LAYOUT box, and the only per-frame writes anywhere near
    // it are to `.card` and `.phone__frame`, both of which are absolutely
    // positioned precisely so their size cannot reflow the column. (That is not
    // incidental: `.card` was moved out of flow when animating its height
    // reflowed the phone mid-zoom and walked the card off screen.) So the
    // viewport and the fonts are the only things that can move it, and both
    // land in measure().
    //
    // `#scene > .column`, not `.scene .column`. The recursion clone is a
    // `.column` inside `.scene` as well — it lives in the plane inside this very
    // card — so the old selector matched both and returned the right one only
    // because the real column comes first in document order. Depending on that
    // is depending on the markup never being reordered.
    if (!target) {
      const real = document.querySelector('#scene > .column');
      if (!real) return;
      const sceneEl_ = refs().sceneRef;
      const prevScene = sceneEl_.style.transform;
      sceneEl_.style.transform = 'none';
      const tb = real.getBoundingClientRect();
      target = { left: tb.left, top: tb.top, width: tb.width, height: tb.height };
      sceneEl_.style.transform = prevScene;
    }
    const t = target;

    // The same ramp the rest of the ending is built on: a constant zoom rate
    // through the middle, flat to second order at both ends.
    //
    // It replaces n / (n + (1-u)^1.5). That one was C1 here — e'(1) = 0, so it
    // did meet the wrap at zero speed — but its SECOND derivative diverged:
    // -24.0 at u = 0.999, -75.1 at 0.9999. It kept 7.7% of peak rate at u = 0.99
    // and then arrested inside the last seven pixels of scroll. On screen that
    // is a camera that flies at you and then is grabbed.
    //
    // ramp'(1) = ramp''(1) = 0 with everything bounded, so the rate now bleeds
    // away over the last third. That is also what matches the far side of the
    // seam: camera.js's ease goes as t^2.6 near t = 0, so the opening leaves
    // rest at zero speed AND zero acceleration. Zero meets zero, twice over.
    //
    // The honest cost: ramp(0.95) = 0.999553, so the last 35px of the close
    // change the scale by 0.05% — 0.12px of clone width — and the first ~60px
    // after the wrap are equally still. Roughly 100px of scroll around the seam
    // with no perceptible motion. A soft arrival at a join that must be
    // invisible is worth more than momentum through it.
    //
    // Exact at the endpoint where it matters: ramp(u >= 1) returns 1 by branch,
    // and ramp(0.999) = 1 - 2.2e-10 against the old ease's 1 - 3.2e-5.
    //
    // rOut 0.34 -> 0.20. The long tail was bleeding the close to a standstill
    // roughly 50px before the wrap, and the opening on the far side was equally
    // flat, so the two dead stretches met and formed one ~75px pause. Shortening
    // the deceleration keeps the arrival soft — ramp'(1) is still exactly 0, so
    // the seam is still C1 — while spending far less scroll getting there.
    //
    // rIn 0.18 -> 0.16 for the same reason at the other end: the close begins
    // right after a 308px hold, and it should not need 126px to get moving.
    const e = ramp(u, 0.16, 0.20);

    const Z = Math.max(1, t.width) / b.w;
    const z = Math.pow(Z, e);

    // Target centre, in the same local space as `base`.
    const tx = t.left + t.width / 2 - b.originLeft;
    const ty = t.top + t.height / 2 - b.originTop;

    // Solve the translate directly with the origin pinned at 0 0, rather than
    // fighting transform-origin: a point p maps to translate + p*z, so to send
    // the clone's centre to the target centre, translate = target - centre*z.
    // Interpolated by e so it starts at rest.
    const dx = (tx - b.cx * z) * e;
    const dy = (ty - b.cy * z) * e;

    zoomEl.style.transformOrigin = '0 0';
    zoomEl.style.transform =
      `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${z.toFixed(5)})`;
  }

  return { apply, measure };
}

/* ------------------------------------------------------------------- loop */

const loop = createLoop({
  length: LOOP_LENGTH,
  config: {
    smoothingMs: TUNE.smoothingMs,
    touchMultiplier: TUNE.touchMultiplier,
    friction: TUNE.friction,
  },
});

const cardShot = document.getElementById('cardShot');
const camera = createCamera({
  sceneEl, cardEl, planeEl,
  // The bezel layers only — never .phone__body, which contains the card.
  //
  // By id, and that is the whole point. This line ran at module scope AFTER
  // `planeEl.append(reelZoom)`, so querySelectorAll matched SIX elements, not
  // three: the recursion clone is a deep copy of this column and it lives
  // inside #card. Since zoomT is pinned at 1 for every pos past ZOOM_SPAN, the
  // clone's bezel sat at scale(11.3168) for the entire walk — measured
  // 2118x4707, covering 100% of the viewport at u = 0.97, the one frame that
  // has to match the real hero. `.phone__frame` is positioned and the hero copy
  // is not, so an opaque gradient painted straight over the miniature's topbar,
  // headline, lead and buttons. Ids are stripped from the clone when it is
  // built, so getElementById can only ever return the real one.
  frameEl: document.getElementById('phoneFrame'),
  glossEl: document.getElementById('phoneGloss'),
  // Left behind by the camera rather than dissolved: these fade only in the
  // last third, once they are already sliding past the edge of the frame.
  fadeEls: [document.querySelector('.topbar'), document.querySelector('.hero__title'),
            document.querySelector('.lead'), document.querySelector('.cta'),
            document.querySelector('.cta__note')].filter(Boolean),
});
const recursion = createRecursion(reelZoom);
/* The stand-in viewport inside the closing device, and the canvas it fills.
 * Sized and scaled from layout in measure() — never from `pos`. */
const againPageEl = document.querySelector('.again__page');
const againCanvasEl = document.querySelector('.again__canvas');
const againBandEl = document.querySelector('.again');
const againScreenEl = document.querySelector('.again__screen');

/**
 * How much of the frame the closing device is allowed to take.
 *
 * Narrower on a phone, and not for taste: below about 820px the device would
 * otherwise run edge to edge, which leaves it no air and leaves the fly-in
 * almost nothing to cover. This was a `@media (max-width: 820px)` rule until
 * the sizing moved into JS; keeping it there as well would have been two places
 * to change one number.
 */
const AGAIN_DEV_CAP = (w) => Math.min(w * (w <= 820 ? 0.74 : 0.92), 1400);

/** Height of .again__chrome, which the stylesheet fixes at 34px. */
const AGAIN_CHROME = 34;

/**
 * How much taller than strictly necessary the closing canvas is made.
 *
 * The coverage condition below is an equality at 1.0, and an equality means the
 * canvas edge and the viewport edge land on the same pixel at the seam — where
 * a rounding of half a pixel shows a hairline of device chrome across the top
 * of the arriving page. 6% is far more than rounding and costs nothing: the
 * page is then letterboxed inside the canvas by 3% top and bottom, in the
 * canvas's own var(--bg), which is the page's own ground.
 */
const AGAIN_COVER = 1.06;
const motesEl = document.getElementById('motes');
const motes = motesEl && !reduced.matches ? createMotes(motesEl) : null;
// Built unconditionally: under reduced motion the rules are still worth having
// as drawing, and only the travelling light is switched off (see flatten()).
const rails = createRails({
  length: LOOP_LENGTH,
  // The direct child, not `.scene .column` — the recursion clone is a
  // `.column` too, and it lives inside this one.
  columnEl: document.querySelector('#scene > .column'),
  sceneEl,
});
const backdrop = createBackdrop(canvas, TUNE);
if (!backdrop) document.body.classList.add('no-webgl');

const magnets = [...document.querySelectorAll('.btn')].map((b) => createMagnet(b, TUNE));

const pointer = { x: -1e4, y: -1e4, active: false };
window.addEventListener('pointermove', (e) => {
  pointer.x = e.clientX; pointer.y = e.clientY; pointer.active = e.pointerType !== 'touch';
}, { passive: true });
window.addEventListener('blur', () => { pointer.active = false; });

const detach = loop.attach(window);

window.addEventListener('keydown', (e) => {
  const page = window.innerHeight * 0.9;
  switch (e.key) {
    case 'ArrowDown': case 'PageDown': case ' ':
      e.preventDefault(); loop.nudge(e.key === ' ' ? page : 150); break;
    case 'ArrowUp': case 'PageUp':
      e.preventDefault(); loop.nudge(e.key === 'PageUp' ? -page : -150); break;
    case 'Home': e.preventDefault(); loop.glideTo(0, { ms: TUNE.navGlideMs }); break;
    // LAST_STAGE_AT, not stagePosition(7). The pan lands over 2*STAGE_LAND of
    // input, so idx reaches 7 at 4792, not at the 4540 the old clamp bit at —
    // aiming at 4540 parks the recursion section 50.6px low at 720p.
    case 'End': e.preventDefault(); loop.glideTo(LAST_STAGE_AT, { ms: TUNE.navGlideMs }); break;
  }
});

/* Tabbing to something inside a stage must bring that stage into view, or the
 * focus ring ends up on a control nobody can see. */
planeEl.addEventListener('focusin', (e) => {
  const s = e.target.closest('.stage');
  if (!s) return;
  const i = +s.dataset.index;
  // Same correction as End above: only the last stage's resting position moved.
  const at = i === STAGES.length - 1 ? LAST_STAGE_AT : stagePosition(i);
  if (Math.abs(loop.distanceTo(at)) > 40) loop.glideTo(at, { ms: 420 });
});

/* --------------------------------------------------------------- rendering */

const scrambled = new WeakSet();
let last = performance.now();
let prevPos = 0;
let speedEMA = 0;
let renderScale = 1;
let calmFor = 0;
let lastDraw = 0;
let vw = 0, vh = 0;

/**
 * Set when measure() was asked to run against a viewport of zero.
 *
 * A hidden tab, a browser pane that has not been displayed, or a load that
 * beats first layout all report innerWidth/innerHeight as 0. measure() used to
 * take that at face value, and the result does not degrade gracefully — it
 * poisons the layout permanently:
 *
 *   · every stage gets `top: 0px; height: 0px`, so the reel is a strip of
 *     nothing and the sections are stacked on each other;
 *   · `.again__page` is sized from `Math.max(1, sceneEl.offsetWidth)`, so it
 *     comes out 1px wide;
 *   · the closing device's width is (bandH - CHROME) / (frac * need) where
 *     `need` is vh/vw — 0/0 — so `--again-dev-w` is written as literally
 *     "NaNpx" and the mock collapses to 2px;
 *   · and the fly-in then has nothing to scale, so the whole last span of the
 *     loop is a scale(1) no-op. The ending does not look wrong, it looks
 *     ABSENT: a stretch of scroll where nothing moves at all.
 *
 * And nothing recovered, because measure() only ever ran again on `resize`.
 * Load the page in a background tab, come back to it, and it stayed broken
 * until the window was dragged.
 */
let needsMeasure = false;

function measure() {
  // Refuse a zero viewport rather than writing it out. camera.js has had this
  // guard since the card's height law was rewritten; this is the same argument
  // one level up, and it is the level that was actually doing the damage.
  if (!window.innerWidth || !window.innerHeight) {
    needsMeasure = true;
    return;
  }
  needsMeasure = false;
  vw = window.innerWidth;
  vh = window.innerHeight;
  camera.measure();
  recursion.measure();
  // After the camera, because both briefly clear the scene transform to take a
  // rest-state measurement and each restores whatever it found.
  rails.measure(vw, vh);
  // One viewport per stage, in real pixels.
  for (let i = 0; i < stageEls.length; i++) {
    stageEls[i].style.top = `${i * vh}px`;
    stageEls[i].style.height = `${vh}px`;
  }
  reel.style.height = `${stageEls.length * vh}px`;

  // The miniature at the end of the loop is a real viewport, so give it the
  // real viewport's box.
  //
  // Sized from the scene's own layout box rather than from 100vw/100vh: the
  // scene is `position: fixed; inset: 0`, and on a phone that box and the vh
  // unit disagree by the height of the URL bar. The clone column has to be
  // centred in exactly the box the real column is centred in or the two will not
  // coincide at the wrap. offsetWidth/offsetHeight are LAYOUT values, so neither
  // the camera's transform nor the closing device's own scale can corrupt them
  // and nothing has to be toggled off first.
  //
  // The scale fits the page to the canvas by WIDTH. Fitting by height instead
  // would crop the page's sides and give the fly-in less to cover.
  //
  // One pixel of underscan, because offsetWidth is the true width ROUNDED: it
  // is at most true+0.5, so offsetWidth-1 is at most true-0.5 and the page can
  // never be wider than the canvas. That asymmetry is deliberate: a wrapper a
  // fraction wider than the canvas puts a sliver of the browser rail across the
  // edge of the arriving page at the seam, whereas half a pixel of canvas
  // ground costs nothing, because it is the same ground.
  //
  // Read AFTER the stage heights above: `.again` is a percentage of the stage,
  // so the canvas has no correct size until those are written.
  //
  // None of this is a function of `pos`. It changes on resize and on
  // fonts.ready, and is therefore constant across the wrap by construction.
  // The device fits inside BOTH the band's height and the frame's width, at a
  // fixed 16/9. CSS cannot express that — see the note on .again__screen — so
  // the min() is taken here, where both numbers are already measured, and the
  // stylesheet derives the height from the ratio.
  //
  // Ordered deliberately: the stage heights are written above, `.again` is a
  // percentage of the stage, `.again__screen` fits inside `.again`, and
  // `.again__canvas` is a percentage of the screen. Each line below reads a box
  // the line before it settled.
  // The closing device, sized so that it CANNOT crop the page it hands over to.
  //
  // The fly-in maps the canvas onto the viewport at the seam, and the canvas
  // clips. So the canvas has to be at least as tall-relative-to-its-width as
  // the viewport, or the arriving page is cropped on the one frame that has to
  // be invisible:
  //
  //     canvasH / canvasW  >=  vh / vw
  //
  // Desktop satisfies it by accident of the 16/9 mock: 0.692 against 0.487. A
  // 390x844 phone misses it by 3.8x — 0.573 against 2.164 — and the measured
  // result was an arriving page at its correct 390x844 inside a 392x225 canvas,
  // 619 of 844 viewport pixels cropped. No landscape mock can satisfy it on a
  // portrait screen at any size, which is why the shape changes rather than the
  // numbers.
  //
  // Two candidates, and the natural one is preferred so that nothing about the
  // desktop ending moves:
  //
  //   A  the shape the mock wants to be — 16/9, filling the band
  //   B  the shortest device that still satisfies coverage
  //
  // A is used whenever it already covers, which is every ordinary landscape
  // window. B takes over otherwise: portrait phones, and also squarer landscape
  // viewports like a 1024x768 tablet, where A misses at 0.684 against 0.795.
  if (againBandEl && againScreenEl) {
    const bandH = againBandEl.offsetHeight;
    if (bandH > 0) {
      const portrait = vh > vw;
      // The rail is a desktop-browser idiom and it eats 23% of the width that
      // coverage needs, so it goes on portrait. Toggled BEFORE the canvas is
      // measured below, since hiding it changes the canvas width.
      document.body.classList.toggle('again-portrait', portrait);

      const frac = portrait ? 1 : 0.77;          // canvas width / device width
      const need = (vh / vw) * AGAIN_COVER;      // required canvasH / canvasW
      const cap = AGAIN_DEV_CAP(vw);

      let devW = Math.min(cap, (bandH * 16) / 9);
      let devH = (devW * 9) / 16;
      const covers = !portrait
        && (devH - AGAIN_CHROME) / Math.max(1, devW * frac) >= need;

      if (!covers) {
        devW = Math.min(cap, (bandH - AGAIN_CHROME) / Math.max(1e-3, frac * need));
        devH = AGAIN_CHROME + devW * frac * need;
      }

      againScreenEl.style.setProperty('--again-dev-w', `${devW.toFixed(2)}px`);
      againScreenEl.style.setProperty('--again-dev-h', `${devH.toFixed(2)}px`);
    }
  }

  if (againPageEl && againCanvasEl) {
    const boxW = Math.max(1, sceneEl.offsetWidth);
    const boxH = Math.max(1, sceneEl.offsetHeight);
    againPageEl.style.width = `${boxW}px`;
    againPageEl.style.height = `${boxH}px`;
    againPageEl.style.setProperty(
      '--again-page-scale',
      (Math.max(1, againCanvasEl.offsetWidth - 1) / boxW).toFixed(6),
    );
  }
}
measure();
window.addEventListener('resize', measure);
/* The phone's rect is measured from layout, and web fonts change layout when
 * they land. Remeasure once they have. */
if (document.fonts?.ready) document.fonts.ready.then(measure);

/*
 * The phone's own scroll across the opening, in screens.
 *
 * Boundary conditions rather than taste — every one is something that goes
 * visibly wrong if it is not met:
 *
 *   s(0)   = 0     the page is at rest when the loop is at rest, so the frame
 *   s'(0)  = 0     after the wrap cannot start the phone scrolling out of
 *                  nothing. The camera's own ease leaves t = 0 at zero speed
 *                  too; this matches it.
 *
 *   s(1)   = 1     the first section has exactly arrived when the zoom lands.
 *
 *   s'(1)  = ZOOM_SPAN / STAGE_SPAN
 *                  and it arrives at exactly the speed the reel cruises at
 *                  afterwards. This is the one the old code got wrong. With the
 *                  reel pinned through the zoom, the section's on-screen speed
 *                  stepped from 0.120 px per scroll px to 1.283 across six
 *                  pixels of scroll at pos = ZOOM_SPAN — the zoom stopped and
 *                  then the page started. It is now exactly C1: ease'(u) goes
 *                  as 1.5*(1-u)^0.5 -> 0 at u = 1, which kills every camera
 *                  term, leaving d(top)/dpos = -vh/STAGE_SPAN on both sides.
 *
 *   s''(1) = 0     and it stops accelerating as it gets there, so the join has
 *                  no corner in it either.
 *
 * The unique quintic through those is a*u^3 + b*u^4 + c*u^5 below. Two things
 * fall out of it: a + b + c = 1 identically, so s(1) is exactly 1 for any span
 * ratio; and s'(u) = u^2 * (3a + 4b*u + 5c*u^2), whose quadratic has
 * discriminant -54.41 at our ratio, so it has no real roots and the scroll is
 * strictly monotone — it never runs backwards.
 */
const SCROLL_SLOPE = ZOOM_SPAN / STAGE_SPAN;
const SCROLL_A = 10 - 4 * SCROLL_SLOPE;
const SCROLL_B = 7 * SCROLL_SLOPE - 15;
const SCROLL_C = 6 - 3 * SCROLL_SLOPE;
function pageScroll(u) {
  return u * u * u * (SCROLL_A + u * (SCROLL_B + u * SCROLL_C));
}

function frame(now) {
  // Recover from a measurement that was refused.
  //
  // rAF does not run in a hidden tab, so the first frame after the page becomes
  // visible is exactly the first moment the viewport can be trusted — and it is
  // this line. No listener, no polling: the thing that needs a real viewport is
  // the frame loop, so the frame loop is where the retry belongs.
  if (needsMeasure && window.innerWidth && window.innerHeight) measure();

  // Clamped at BOTH ends. The upper bound stops a backgrounded tab resuming
  // with a two-second step; the lower one is the interesting half.
  //
  // A negative delta is poison here rather than merely wrong. Every ease on the
  // page is k = 1 - exp(-dt / tau), so dt < 0 gives exp(positive) > 1 and k < 0
  // — the easing steps AWAY from its target instead of toward it, and does so
  // by a larger factor each frame. It diverges rather than glitching: a harness
  // driving frame() with timestamps ahead of the clock produced a position of
  // -2.15e12 in about three hundred frames. This page has already shipped one
  // runaway of that shape (a wrap that subtracted one loop length per frame and
  // could never normalise a value several lengths out, fixed with a modulo),
  // and the lesson from it was to bound the inputs rather than to trust that
  // the arithmetic can only be driven sensibly.
  //
  // performance.now() is monotonic, so a real rAF cannot deliver this. It costs
  // one Math.max to be sure of that rather than to assume it — and it is what
  // makes frame() safe to step by hand, which is the only way any of this page
  // can be verified in a pane that will not composite.
  //
  // `|| 16.7` still catches the exactly-zero case, which two rAF callbacks in
  // the same tick will produce.
  const dt = Math.min(64, Math.max(0, now - last)) || 16.7;
  last = now;

  const pos = loop.advance(dt, now);
  const moved = Math.abs(loop.velocityOf(prevPos));
  prevPos = pos;

  speedEMA = approach(speedEMA, (moved / Math.max(1, dt)) * 16.7, dt, 120);

  if (renderScale === 1) {
    if (speedEMA > TUNE.motionResEnter) { renderScale = TUNE.motionResScale; calmFor = 0; }
  } else if (speedEMA < TUNE.motionResExit) {
    calmFor += dt;
    if (calmFor >= TUNE.motionResCalmMs) renderScale = 1;
  } else calmFor = 0;

  // ---- the opening ------------------------------------------------------
  //
  // The rectangle opens over the first ZOOM_SPAN and closes again over the
  // last CLOSE_SPAN, so the loop reads as: push in through the phone, walk
  // the colonnade, pull back out, and arrive at the landing page you started
  // on. Driven from the absolute position rather than a signed distance to
  // zero — that was the earlier bug, and it made the camera snap all the way
  // out halfway round the loop, which is what turned the whole thing into a
  // fade.
  // The opening rectangle only ever OPENS. It used to run backwards over the
  // last span to close, which is the one camera move with no forward momentum
  // and is why the ending read as a fade. The way back is the recursion below.
  const closeFrom = LOOP_LENGTH - CLOSE_SPAN;
  // The close's own clock, raw and eased.
  //
  // Everything that has to be extinguished before the wrap is driven from
  // `into` rather than from the raw fraction, so it reaches zero with zero SPEED
  // as well as zero value. On the far side of the seam it is zero and static, so
  // zero meets zero. Driving it linearly, as the motes were, lands the right
  // number at the wrong rate and kinks once per lap.
  const closeU = pos < closeFrom ? 0 : Math.min(1, (pos - closeFrom) / CLOSE_SPAN);
  // Same shape as the fly-in above, deliberately: the motes fade out on the
  // camera's own clock, so if these two ever drifted apart the dust would still
  // be thinning after the doors had stopped moving.
  const into = ramp(closeU, 0.16, 0.20);
  // Clamped at zero, and that clamp is load-bearing now.
  //
  // `pos` can be negative. loop.glideTo() takes the short way round and does
  // NOT clamp its target, and loop.js only normalises negatives once hasWrapped
  // is true. Pressing End on a fresh load glides to 0 + distanceTo(4540) and
  // parks there. That used to render identically to pos 0 — camera.apply clamps
  // t, and Math.max(0, ...) clamped idx — but pageScroll() is a quintic, so an
  // unclamped u = -2.48 gives s = -614.6: the screenshot flies 67759px down the
  // page, the reel goes to +664842px, every stage culls, and the phone screen
  // is left showing nothing but .card's own black. Clamping here fixes it at
  // the source, for the camera, the magnets and the scroll alike.
  const zoomT = pos < ZOOM_SPAN ? Math.max(0, pos) / ZOOM_SPAN : 1;
  camera.apply(zoomT);
  // ---- the phone scrolls to the next page --------------------------------
  //
  // ONE scroll, not two slides. Nothing fades here either; that has not changed
  // and must not.
  //
  // What was here slid the app screenshot DOWNWARD out of the card while the
  // reel sat frozen on stage 0 behind it. Two independently timed moves in
  // opposite directions: measured in screen px per scroll px at pos 300 / 400 /
  // 500, the screenshot ran -2.82 / -3.15 / -3.38 while the section under it
  // ran +0.53 / +1.10 / +1.15. And the screenshot was gone by e = 0.46, so the
  // last third of the zoom had nothing moving in it at all. That is the gap.
  //
  // Now there is a single number — s, how far the phone's page has scrolled, in
  // screens — and both layers are the same function of it. With the window
  // docked to the card's bottom edge (camera.js), in card pixels:
  //
  //     screenshot bottom edge = hCss - s * win
  //     first section top edge = hCss - s * win
  //
  // The same expression, so these are not two things moving at similar rates;
  // they are one edge, with the home screen above it and the page you are
  // arriving at below it. Measured every 4px through the zoom, the two never
  // differ by more than 0.083px at 1280x720, 0.052 at 375x812, 0.0835 at
  // 1440x640, 0.0425 at 1920x1080 — and the union of screenshot and section
  // covers the whole card at every frame, so no black band can open.
  //
  // `win` is one page in CARD pixels — vh/Z — and the unit is the whole
  // correction. A percentage of the screenshot's own height is wrong: at rest
  // the card is 4.10x taller than the page-window, so translateY(-100%) would
  // have moved the screenshot four pages while the reel moved one.
  //
  // No Math.max on the divisor: camera.measure() refuses a zero viewport, so Z
  // is never degenerate, and guarding only this side would have let the dock
  // and the weld disagree in exactly the case being guarded.
  const win = vh / camera.scaleToFill;
  const s = pageScroll(zoomT);
  if (cardShot) {
    cardShot.style.transform = `translateY(${(-s * win).toFixed(3)}px)`;
    // A cull, not a fade — the same mechanism the stages below use. At the end
    // of the zoom hCss IS win, so the screenshot is exactly one box-height
    // above a box that clips and its visible area is zero by construction
    // (measured clearance 0.000 to 0.086px). This only stops a rounding
    // remainder from leaving a hairline of it along the top of the viewport for
    // the 5100px of loop it spends parked there. Guarded like the stage cull,
    // so it is a state change rather than a style write every frame.
    const gone = zoomT >= 1;
    if (gone !== (cardShot.style.visibility === 'hidden')) {
      cardShot.style.visibility = gone ? 'hidden' : '';
    }
  }

  // Beat three. The last span flies into the hero living inside the final
  // stage's screen. It is handed the raw 0..1 and eases it internally, so this
  // call site stays a plain statement of where we are in the close.
  recursion.apply(closeU);

  // ---- the reel --------------------------------------------------------
  // A single translate. Fractional index in, pixels out.
  //
  // Clamped at the top end, and that clamp is the whole ending.
  //
  // Without it the pan keeps running through the close: at closeFrom the index
  // reaches STAGES.length exactly, which is one full viewport PAST the last
  // stage, and it carries on to 9.75 by the end of the loop. So the camera
  // spent the entire close flying into a device that had already left the top
  // of the screen. Measured: the closing device sat at y = -540 in a 720px
  // viewport the moment the close began -- entirely above the fold.
  //
  // That is why the ending read as "it just shows the landing page". The
  // fly-in was working perfectly and landing the clone exactly on the hero;
  // you simply never saw the device it was flying out of, so all that was
  // left to see was the arrival. The pan now parks on the last stage and holds
  // there while the camera does the travelling.
  // Below zero through the opening, and that is the change.
  //
  // idx = -1 puts stage 0 exactly one page below the fold; idx = 0 puts it in
  // the window. Running it from -1 to 0 across the zoom is what makes the first
  // section ARRIVE. Math.max(0, ...) used to pin it at 0 for all 620px of the
  // zoom, which is why nothing inside the phone ever moved.
  //
  // Everything downstream survives the negative range — checked, not assumed:
  //
  //   · culling, off = d > 1.35. Stage 0's d peaks at exactly 1.0, because the
  //     scroll is defined in screens rather than as a linear ramp from pos = 0
  //     (which would start at -1.107 and leave only 0.24 of margin). d is in
  //     index units, so this is viewport-independent. Stage 1 stays above 1.35
  //     until s = 0.65 and is a measured 131px below the card's bottom edge
  //     when it un-culls, so nothing pops — and it is never needed inside the
  //     card at any point in the zoom (max intrusion 0.032px).
  //
  //   · parallax, dd = clamp(idx - i, -1.4, 1.4). Stage 0's dd runs -1 -> 0,
  //     inside the clamp, and settles at exactly 0 on arrival, so the landed
  //     frame is identical to today's.
  //
  //   · scramble, d < 0.18. Now fires at about 85% of the zoom, as the title
  //     lands and while you are looking at it. It used to fire on the very
  //     first frame at pos = 0, behind the screenshot, where nobody saw it.
  const idx = pos < ZOOM_SPAN
    ? s - 1
    //
    // And on the far branch it LANDS rather than clamping. Math.min was right
    // and the way it clamped was wrong: d(idx)/d(pos) is 1/560 below the clamp
    // and 0 above it, so the pan ran at 1.286 px per scroll px and stopped
    // between one frame and the next, at pos 4540 — the exact moment the last
    // section arrives. That jolt, and the 560px of frozen nothing behind it,
    // are most of what "the ending animation is 0% there" was describing. The
    // fly-in after it was never the problem.
    //
    // softLand covers the last 0.45 of a stage-span over 0.90 of scroll input
    // with a (1 - smoother) velocity profile: linear to pos 4288, landing 4288
    // -> 4792, parked after. The last section decelerates into place instead of
    // being caught, and the section before it decelerates out of frame the same
    // way — the two are one pan. It also leaves the near branch's C1 join
    // untouched, because softLand is the identity at raw = 0.
    : softLand((pos - ZOOM_SPAN) / STAGE_SPAN, STAGES.length - 1, STAGE_LAND);
  reel.style.transform = `translate3d(0, ${(-idx * vh).toFixed(1)}px, 0)`;

  for (let i = 0; i < stageEls.length; i++) {
    const d = Math.abs(idx - i);
    const st = stageEls[i];
    // Culling only — never opacity. A stage is either in the strip or it is
    // not worth painting.
    const off = d > 1.35;
    if (off !== (st.style.visibility === 'hidden')) {
      st.style.visibility = off ? 'hidden' : '';
      if (off) st.setAttribute('aria-hidden', 'true');
      else st.removeAttribute('aria-hidden');
    }
    // Life inside the section.
    //
    // The reel moves everything at one rate, which is a pan — correct, but on
    // its own it is eight static pictures sliding by. Each layer now moves at
    // its own rate against that pan, so the art and the type separate as you
    // travel and the section has depth rather than just position. Signed, so
    // it leads on the way in and trails on the way out.
    const dd = Math.max(-1.4, Math.min(1.4, idx - i));
    if (!off) {
      const relief = st.querySelector('.stage__relief');
      const god = st.querySelector('.stage__god');
      const body = st.querySelector('.stage__inner');
      const beam = st.querySelector('.stage__beam');
      if (relief) relief.style.transform = `translate3d(0, ${(dd * vh * 0.22).toFixed(1)}px, 0) scale(${(1 + Math.abs(dd) * 0.04).toFixed(3)})`;
      if (god) god.style.transform = `translate3d(${(dd * 34).toFixed(1)}px, ${(dd * vh * 0.13).toFixed(1)}px, 0)`;
      if (body) body.style.transform = `translate3d(0, ${(dd * vh * -0.055).toFixed(1)}px, 0)`;
      if (beam) {
        // Sweeps left to right across the section as it passes, and is only
        // bright while the section is near the middle of the screen.
        //
        // Deliberately NOT multiplied by (1 - into), which was the obvious way
        // to stop the recursion section's beam sitting at --lit 1.000 across the
        // whole viewport at LOOP_LENGTH and vanishing at pos 0. `--lit` is bound
        // straight to `opacity` on a plus-lighter layer, so that would have been
        // a 700px opacity ramp. It is unnecessary: `.again` and `.stage__beam`
        // are both z-index:0 positioned siblings and the beam is appended first,
        // so `.again` paints above it — and at the wrap `.again__canvas` covers
        // the whole viewport with an opaque var(--bg) ground. The beam is
        // completely occluded on the one frame it would have shown.
        beam.style.setProperty('--sweep', `${(50 - dd * 78).toFixed(1)}%`);
        beam.style.setProperty('--lit', (Math.max(0, 1 - Math.abs(dd) * 1.25)).toFixed(3));
      }

      // ---- beat one: the closing device arrives ------------------------
      //
      // Every other section slides past at the reel's rate with its parts
      // separated by a few percent. This one is not a section you read past, it
      // is a thing you walk up to, so it gets an arrival instead of a parallax
      // offset: it comes up from under the fold, grows, goes three quarters of
      // a percent past its size and settles. Only then does the camera start
      // travelling into it.
      //
      // `a` is 1 + dd — 0 when the section's top edge is exactly at the bottom
      // of the frame, 1 when it is centred. Same clock as everything else in
      // this block, and because `idx` now lands rather than stopping, da/dpos is
      // 0 at a = 1. Both terms below are also flat at a = 1, so the whole
      // transform arrives at zero speed and the 308px hold that follows is a
      // continuation of the deceleration rather than a stop.
      //
      // Nothing here is faded. The device is smaller and lower, then bigger and
      // higher; at no point is any part of it more or less opaque.
      //
      // Do NOT add will-change: transform. This scales a large cloned-text
      // subtree from 0.45 to 1.00 over 500px of scroll; without the hint the
      // browser re-rasterises per frame and the type stays crisp, with it Chrome
      // is liable to rasterise once near 0.45 and stretch. .reel-zoom already
      // carries the hint for the entry.
      const again = st.querySelector('.again');
      if (again) {
        const a = Math.max(0, Math.min(1, 1 + dd));
        // Trails the reel by 0.30vh and closes the gap on a smootherstep, so it
        // rises INTO the frame rather than arriving with the wall behind it.
        // Composite on-screen y is (1-a)*vh from the reel plus this; both terms
        // have zero slope in pos at a = 1, because smoother'(1) = 0.
        const lift = AGAIN_LAG * vh * (1 - smoother(a));
        // Growth is held back until a = 0.45. The device's top edge crosses the
        // bottom of the frame at about a = 0.55, and every bit of growth spent
        // before that happens off-screen and is thrown away. Held back, the
        // device enters at ~0.50 and does all of its growing in front of you.
        //
        // Trapezoid so the growth is steady rather than a lunge, plus one 4.5%
        // bump whose own peak is at b = 0.75 and which returns to exactly 1.0000
        // at a = 1. That is the settle: a few px of device height, taken back
        // over the last ~65px of scroll. Felt, not seen.
        const b = (a - AGAIN_GROW_FROM) / (1 - AGAIN_GROW_FROM);
        const grow = AGAIN_S0 + (1 - AGAIN_S0)
          * (ramp(b, 0.25, 0.30) + 0.045 * overshoot(b));
        again.style.transform =
          `translate3d(0, ${lift.toFixed(1)}px, 0) scale(${grow.toFixed(4)})`;
      }
    }

    if (d < 0.18 && !scrambled.has(st) && !reduced.matches) {
      scrambled.add(st);
      const h = st.querySelector('[data-scramble]');
      if (h) scramble(h, h.dataset.scramble, TUNE);
    }
  }

  // ---- magnets ---------------------------------------------------------
  for (const m of magnets) {
    if (pointer.active && zoomT < 0.5) m.point(pointer.x, pointer.y); else m.release();
    m.tick(dt);
  }

  // ---- rails -----------------------------------------------------------
  //
  // Driven by where you are, plus a slow drift so the page is never quite dead,
  // plus speed for how bright and how long the light is. The travel is a phase,
  // frac(n * pos / LOOP_LENGTH), with n a whole number of laps per loop — so it
  // is continuous across the wrap by construction rather than by being covered.
  //
  // Called unconditionally, unlike the backdrop below, and that has a cost worth
  // knowing: the drift term changes every frame from the clock alone, at 10-35
  // px/s, so the compositor never reaches idle and TUNE.idleFps buys nothing
  // here. That is the intent — a page that is completely still at rest reads as
  // a screenshot — but it is a battery cost, not a free one.
  rails.tick(pos, now, speedEMA);

  // ---- motes -----------------------------------------------------------
  //
  // Lit by where you are, not by a timer. The field builds through the last
  // three sections the way the reference's flame builds under its closing
  // ones, peaks with the device fully on screen, and dies back to its resting
  // level as the camera enters the device.
  //
  // That last part is not decoration -- it is what keeps the seam invisible.
  // The motes are a fixed overlay, so if the field were still at full strength
  // at LOOP_LENGTH it would jump to its resting level the instant the position
  // wrapped to 0, and the one frame nobody is allowed to notice would flash.
  // Ramping down across the close makes the value continuous across the wrap,
  // and it is the honest reading too: you are leaving the room the device is
  // standing in.
  //
  // Both halves of that ramp were linear, which got the values right and the
  // rates wrong. `up` saturated at closeFrom while `into` started there:
  // measured +4.4e-4 per pixel at 5099 against -7.6e-4 at 5101, a kink at the
  // exact join. And it arrived at the wrap still falling, to meet a value that
  // is flat. Smootherstep on the way up and the close's own ramp on the way
  // down make both slopes zero where they meet anything. `into` is now the
  // shared one declared at the top of frame().
  if (motes) {
    const from = stagePosition(5);
    const up = smoother((pos - from) / Math.max(1, closeFrom - from));
    motes.resize(vw, vh);
    motes.draw(dt, 0.26 + 0.74 * up * (1 - into), Math.min(1, speedEMA * 0.9));
  }

  // ---- backdrop --------------------------------------------------------
  const busy = speedEMA > 0.05 || loop.isGliding;
  if (backdrop && (busy || now - lastDraw >= 1000 / TUNE.idleFps)) {
    backdrop.resize(vw, vh, renderScale);
    backdrop.draw(now / 1000, pos / LOOP_LENGTH);
    lastDraw = now;
  }

  raf = requestAnimationFrame(frame);
}

let raf = 0;

/* ------------------------------------------------------- reduced motion */

function useStaticLayout() {
  document.body.classList.add('static-layout');
  detach();
  cancelAnimationFrame(raf);
  camera.flatten();
  rails.flatten();
  if (cardShot) {
    cardShot.style.opacity = '';
    cardShot.style.transform = '';
    cardShot.style.visibility = '';
  }
  // At rest the reel now holds stage 0 one page BELOW the fold rather than
  // sitting at translate 0, so switching into reduced motion mid-session has to
  // clear it or the whole strip lands a viewport low. `.plane` is already
  // covered by `transform: none !important` under .static-layout; `.reel` and
  // `.reel-zoom` are not.
  reel.style.transform = '';
  reelZoom.style.transform = '';
  for (const s of stageEls) {
    s.style.cssText = '';
    s.removeAttribute('aria-hidden');
    // The closing device's arrival is written to .again, not to the stage, and
    // `body.static-layout .stage { transform: none !important }` does not reach
    // a child. Left behind, the last section would render its browser mock at
    // 45% in a layout that has no camera to fly it anywhere.
    const again = s.querySelector('.again');
    if (again) again.style.transform = '';
  }
  for (const h of document.querySelectorAll('[data-scramble]')) h.textContent = h.dataset.scramble;
  if (backdrop) { backdrop.resize(vw, vh, 1); backdrop.draw(0, 0); }
}

if (reduced.matches) useStaticLayout();
else raf = requestAnimationFrame(frame);

reduced.addEventListener?.('change', (e) => { if (e.matches) useStaticLayout(); else location.reload(); });

/* The build log. Lazy: nothing is fetched until it is opened. */
const panel = createPanel();
document.getElementById('openLog')?.addEventListener('click', (e) => panel.open(e.currentTarget));
window.addEventListener('keydown', (e) => {
  if (e.key.toLowerCase() === 'l' && !e.metaKey && !e.ctrlKey && !panel.isOpen) {
    if (document.activeElement?.tagName === 'INPUT') return;
    panel.open();
  }
});

mountTunePane(TUNE, { loop });

document.body.classList.remove('is-loading');

/* Exposed for verification: the browser pane cannot composite while hidden, so
 * rAF never runs there and the only way to check the geometry is to step it. */
window.__shadow = { loop, camera, frame, stageEls, recursion, motes, rails };
