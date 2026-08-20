import { createLoop, approach } from './loop.js';
import { createBackdrop } from './backdrop.js';
import { createCamera } from './camera.js';
import { createPanel } from './panel.js';
import { createMagnet, createMarker, scramble } from './effects.js';
import { STAGES, STAGE_SPAN, ZOOM_SPAN, LOOP_LENGTH, NAV, stagePosition } from './content.js';
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

const stageEls = STAGES.map(buildStage);
stageEls.forEach((s) => planeEl.append(s));

/* Nav */
const nav = el('nav', 'nav');
nav.setAttribute('aria-label', 'Sections');
const trailEl = el('span', 'nav__marker nav__marker--trail');
const markerEl = el('span', 'nav__marker');
nav.append(trailEl, markerEl);
const navButtons = NAV.map((n) => {
  const b = el('button', 'nav__item', n.label);
  b.type = 'button';
  b.addEventListener('click', () => loop.glideTo(n.at, { ms: TUNE.navGlideMs }));
  nav.append(b);
  return b;
});
document.body.append(nav);

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
  // Left behind by the camera rather than dissolved: these fade only in the
  // last third, once they are already sliding past the edge of the frame.
  fadeEls: [document.querySelector('.topbar'), document.querySelector('.hero__title'),
            document.querySelector('.lead'), document.querySelector('.cta'),
            document.querySelector('.cta__note')].filter(Boolean),
});
const backdrop = createBackdrop(canvas, TUNE);
if (!backdrop) document.body.classList.add('no-webgl');

const magnets = [...document.querySelectorAll('.btn')].map((b) => createMagnet(b, TUNE));
const marker = createMarker(TUNE);

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
let fpsFrames = 0, fpsSince = performance.now();
const markPerf = document.getElementById('markPerf');
const markRoute = document.getElementById('markRoute');

function measure() {
  vw = window.innerWidth;
  vh = window.innerHeight;
  camera.measure();
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

  // ---- the opening -----------------------------------------------------
  // Distance to 0 is signed and continuous across the wrap, so coming back
  // round from the download stage closes the portal again rather than jumping.
  const toTop = loop.distanceTo(0);
  const zoomT = toTop <= -ZOOM_SPAN || toTop > 0
    ? (toTop > 0 ? 0 : 1)
    : -toTop / ZOOM_SPAN;
  camera.apply(zoomT);
  // The app screen clears over the first half, revealing the page behind it.
  if (cardShot) cardShot.style.opacity = String(1 - Math.min(1, Math.max(0, (zoomT - 0.06) / 0.44)));

  // ---- stages ----------------------------------------------------------
  for (let i = 0; i < stageEls.length; i++) {
    const d = loop.distanceTo(stagePosition(i));
    const t = d / STAGE_SPAN;
    const a = Math.abs(t);
    const s = stageEls[i];

    if (a > 1.2) {
      if (s.style.visibility !== 'hidden') { s.style.visibility = 'hidden'; s.setAttribute('aria-hidden', 'true'); }
      continue;
    }
    if (s.style.visibility === 'hidden') { s.style.visibility = ''; s.removeAttribute('aria-hidden'); }

    const y = t * vh * TUNE.stageTravel;
    const scale = 1 - Math.min(0.12, a * TUNE.stageShrink);
    const opacity = Math.max(0, 1 - Math.pow(a / TUNE.stageFade, 2));
    s.style.transform = `translate3d(0, ${y.toFixed(1)}px, 0) scale(${scale.toFixed(4)})`;
    s.style.opacity = opacity.toFixed(3);
    s.style.filter = a > 0.55 ? `blur(${((a - 0.55) * TUNE.stageBlur).toFixed(2)}px)` : '';

    if (a < 0.16 && !scrambled.has(s) && !reduced.matches) {
      scrambled.add(s);
      const h = s.querySelector('[data-scramble]');
      if (h) scramble(h, h.dataset.scramble, TUNE);
    }
  }

  // ---- colonnade plates ------------------------------------------------
  for (const pl of plates.children) {
    const depth = +pl.dataset.depth;
    pl.style.transform = 
      `translate3d(0, ${(-pos * depth * 0.05).toFixed(1)}px, 0) scale(${(1 + depth * 0.1).toFixed(3)})`;
  }

  // ---- magnets ---------------------------------------------------------
  for (const m of magnets) {
    if (pointer.active && zoomT < 0.5) m.point(pointer.x, pointer.y); else m.release();
    m.tick(dt);
  }

  // ---- nav marker ------------------------------------------------------
  let nearest = 0, best = Infinity;
  for (let i = 0; i < NAV.length; i++) {
    const d = Math.abs(loop.distanceTo(NAV[i].at));
    if (d < best) { best = d; nearest = i; }
  }
  navButtons.forEach((b, i) => b.classList.toggle('is-current', i === nearest));
  const r = navButtons[nearest].getBoundingClientRect();
  const nr = nav.getBoundingClientRect();
  const m = marker.tick(r.left - nr.left + r.width / 2, r.width * TUNE.markerWidthFrac, true, dt);
  markerEl.style.transform = `translate3d(${(m.x - m.width / 2).toFixed(1)}px, 0, 0)`;
  markerEl.style.width = `${m.width.toFixed(1)}px`;
  trailEl.style.transform = `translate3d(${(m.tail - m.width / 2).toFixed(1)}px, 0, 0)`;
  trailEl.style.width = `${m.width.toFixed(1)}px`;
  trailEl.style.opacity = String(TUNE.markerTrailAmt * m.alpha);

  // ---- backdrop --------------------------------------------------------
  const busy = speedEMA > 0.05 || loop.isGliding;
  if (backdrop && (busy || now - lastDraw >= 1000 / TUNE.idleFps)) {
    backdrop.resize(vw, vh, renderScale);
    backdrop.draw(now / 1000, pos / LOOP_LENGTH);
    lastDraw = now;
  }

  // ---- marginalia ------------------------------------------------------
  // Real numbers. Annotations that read like instrumentation but are hard-
  // coded are just decoration pretending to be data.
  fpsFrames++;
  if (now - fpsSince >= 500) {
    const fps = Math.round((fpsFrames * 1000) / (now - fpsSince));
    fpsFrames = 0; fpsSince = now;
    if (markPerf) markPerf.textContent = 
      (backdrop ? 'WEBGL2' : 'CANVAS') + ' — ' + fps + 'FPS' + (renderScale < 1 ? ' — RES x' + renderScale : '');
  }
  if (markRoute) {
    const label = zoomT < 0.98 ? 'SEC / HERO' : 'SEC / ' + NAV[nearest].label.toUpperCase();
    if (markRoute.textContent !== label) markRoute.textContent = label;
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
