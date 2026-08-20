import { createLoop, approach } from './loop.js';
import { createMotes } from './motes.js';
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

    const canvasArea = el('div', 'again__canvas');
    canvasArea.append(clone);

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
const motesEl = document.getElementById('motes');
const motes = motesEl && !reduced.matches ? createMotes(motesEl) : null;
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

  // The last span flies into the hero living inside the final stage's screen.
  recursion.apply(pos < closeFrom ? 0 : (pos - closeFrom) / CLOSE_SPAN);

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
    : Math.min(
        STAGES.length - 1,
        (pos - ZOOM_SPAN) / STAGE_SPAN,
      );
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
        beam.style.setProperty('--sweep', `${(50 - dd * 78).toFixed(1)}%`);
        beam.style.setProperty('--lit', (Math.max(0, 1 - Math.abs(dd) * 1.25)).toFixed(3));
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
  if (motes) {
    const from = stagePosition(5);
    const up = Math.max(0, Math.min(1, (pos - from) / Math.max(1, closeFrom - from)));
    const into = pos < closeFrom ? 0 : (pos - closeFrom) / CLOSE_SPAN;
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
window.__shadow = { loop, camera, frame, stageEls, recursion, motes };
