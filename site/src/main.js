import { createLoop, approach } from './loop.js';
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
    screen.append(clone);
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
  let base = null;   // { cx, cy, w } of the clone column, unzoomed

  function measure() {
    base = null;
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
    // Deliberately NOT cached.
    //
    // The baseline depends on the camera's scale, the reel's pan and the
    // viewport, and caching it meant one measurement taken on the wrong frame
    // poisoned the whole close — the clone was measured at 39px instead of
    // 309 (the camera happened to be shut) and the fly-in then overshot by a
    // factor of eight. This costs one extra layout per frame, and only during
    // the 900px of scroll the close actually occupies.
    const prev = zoomEl.style.transform;
    zoomEl.style.transform = 'none';
    const clone = zoomEl.querySelector('.again__screen .column');
    if (!clone) { zoomEl.style.transform = prev; return null; }
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
    return base;
  }

  function apply(u) {
    if (u <= 0) { zoomEl.style.transform = 'none'; return; }
    const b = ensure();
    if (!b) return;
    const real = document.querySelector('.scene .column');
    if (!real) return;

    // Measured with the scene transform OFF.
    //
    // This is the whole seam. The target is not where the real hero is *now* —
    // during the close the camera is fully pushed in, so the hero column reads
    // as 5829px wide. It is where the hero will be one frame after the wrap,
    // when the camera is back at rest and the column is its plain 736px. Aiming
    // at the live rect matched that 5829 exactly and was, by construction,
    // eight times too big at the only instant that matters.
    const sceneEl_ = document.getElementById('scene');
    const prevScene = sceneEl_.style.transform;
    sceneEl_.style.transform = 'none';
    const tb = real.getBoundingClientRect();
    const t = { left: tb.left, top: tb.top, width: tb.width, height: tb.height };
    sceneEl_.style.transform = prevScene;

    // Same asymmetric ease as the opening, so both ends move with one hand.
    const e = u >= 1 ? 1 : (() => {
      const n = Math.pow(u, 2.6);
      return n / (n + Math.pow(1 - u, 1.5));
    })();

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
  phoneEl: [...document.querySelectorAll('.phone__frame, .phone__screen, .phone__gloss')],
  // Left behind by the camera rather than dissolved: these fade only in the
  // last third, once they are already sliding past the edge of the frame.
  fadeEls: [document.querySelector('.topbar'), document.querySelector('.hero__title'),
            document.querySelector('.lead'), document.querySelector('.cta'),
            document.querySelector('.cta__note')].filter(Boolean),
});
const recursion = createRecursion(reelZoom);
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
    case 'End': e.preventDefault(); loop.glideTo(stagePosition(STAGES.length - 1), { ms: TUNE.navGlideMs }); break;
  }
});

/* Tabbing to something inside a stage must bring that stage into view, or the
 * focus ring ends up on a control nobody can see. */
planeEl.addEventListener('focusin', (e) => {
  const s = e.target.closest('.stage');
  if (!s) return;
  const at = stagePosition(+s.dataset.index);
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

function measure() {
  vw = window.innerWidth;
  vh = window.innerHeight;
  camera.measure();
  recursion.measure();
  // One viewport per stage, in real pixels.
  for (let i = 0; i < stageEls.length; i++) {
    stageEls[i].style.top = `${i * vh}px`;
    stageEls[i].style.height = `${vh}px`;
  }
  reel.style.height = `${stageEls.length * vh}px`;
}
measure();
window.addEventListener('resize', measure);
/* The phone's rect is measured from layout, and web fonts change layout when
 * they land. Remeasure once they have. */
if (document.fonts?.ready) document.fonts.ready.then(measure);

function frame(now) {
  const dt = Math.min(64, now - last) || 16.7;
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
  const zoomT = pos < ZOOM_SPAN ? pos / ZOOM_SPAN : 1;
  camera.apply(zoomT);
  // The app screen SLIDES away, it does not fade.
  //
  // Every dissolve on this page has been removed for the same reason: the
  // moment something changes opacity it reads as a slideshow transition
  // rather than as one thing moving out of the way of another. The reference
  // slides its app icon down out of the frame over the first two thirds of
  // the zoom; this does the same, so the page behind is uncovered rather than
  // revealed.
  if (cardShot) {
    const k = Math.min(1, Math.max(0, (camera.progress - 0.04) / 0.42));
    const slide = k * k * (3 - 2 * k);          // smoothstep, so it eases out
    cardShot.style.transform =
      `translateY(${(slide * 108).toFixed(2)}%) scale(${(1 - slide * 0.06).toFixed(4)})`;
  }

  // The last span flies into the hero living inside the final stage's screen.
  recursion.apply(pos < closeFrom ? 0 : (pos - closeFrom) / CLOSE_SPAN);

  // ---- the reel --------------------------------------------------------
  // A single translate. Fractional index in, pixels out.
  const idx = Math.max(0, pos - ZOOM_SPAN) / STAGE_SPAN;
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
  if (cardShot) cardShot.style.opacity = '';
  for (const s of stageEls) {
    s.style.cssText = '';
    s.removeAttribute('aria-hidden');
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
window.__shadow = { loop, camera, frame, stageEls };
