/**
 * The camera.
 *
 * ## What the first attempt got wrong
 *
 * It grew the card and left the rest of the hero still, fading it out. That
 * reads as a panel expanding over a page. Watch the reference frame by frame
 * and the headline is *also* getting bigger — by the third frame "Design,
 * build, ship, repeat." is half off the left edge at roughly three times its
 * starting size. Nothing is fading; the camera is moving toward the card and
 * the whole scene grows with it, exactly as it would through a lens.
 *
 * So there is one transform on one element — the scene — and everything in the
 * hero is inside it. That is the whole trick.
 *
 * ## The maths
 *
 *   z    = Z ** e            Z = viewportWidth / cardWidth
 *   origin = the card's centre, in scene coordinates
 *   offset = (viewportCentre - cardCentre) * e
 *
 * With the transform origin pinned to the card's centre, scaling leaves that
 * point where it is, and the offset walks it to the middle of the screen. At
 * e = 1 the card is exactly viewport-wide and exactly centred, which is to say
 * it *is* the viewport.
 *
 * ## Why the content inside the card never changes scale
 *
 * The plane is a child of the card, so it already inherits `z`. It is laid out
 * at full viewport size and held at a constant `1 / Z`. At the start that makes
 * it fill the card as a miniature; at the end, `(1/Z) * Z = 1`, life size. It
 * is the same page the whole way through at the same relative size — the camera
 * did all of the work, which is why there is no seam to hide.
 */

/** Slow at the start, where the phone still reads as a phone. */
function ease(t, easeIn = 1.75, easeOut = 2.15) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const n = Math.pow(t, easeIn);
  return n / (n + Math.pow(1 - t, easeOut));
}

export function createCamera({ sceneEl, cardEl, planeEl, fadeEls = [] }) {
  let vw = 0, vh = 0;
  let Z = 4;
  let origin = { x: 0, y: 0 };      // card centre, scene-local
  let start = { x: 0, y: 0 };       // card centre, screen, at rest
  let radius0 = 28;

  function measure() {
    vw = window.innerWidth;
    vh = window.innerHeight;

    // Measure with the scene untransformed, or every number is scaled.
    const prev = sceneEl.style.transform;
    sceneEl.style.transform = 'none';

    const s = sceneEl.getBoundingClientRect();
    const c = cardEl.getBoundingClientRect();
    origin = { x: c.left - s.left + c.width / 2, y: c.top - s.top + c.height / 2 };
    start = { x: c.left + c.width / 2, y: c.top + c.height / 2 };
    radius0 = parseFloat(getComputedStyle(cardEl).borderTopLeftRadius) || 28;

    Z = Math.max(vw / Math.max(1, c.width), vh / Math.max(1, c.height));

    sceneEl.style.transformOrigin = `${origin.x}px ${origin.y}px`;
    planeEl.style.width = `${vw}px`;
    planeEl.style.height = `${vh}px`;
    planeEl.style.transform = `translate(-50%, -50%) scale(${(1 / Z).toFixed(6)})`;

    sceneEl.style.transform = prev;
  }

  function apply(t) {
    const e = ease(Math.min(1, Math.max(0, t)));
    const z = Math.pow(Z, e);
    const dx = (vw / 2 - start.x) * e;
    const dy = (vh / 2 - start.y) * e;

    sceneEl.style.transform = `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${z.toFixed(5)})`;

    // Divided by z so the radius stays constant on screen while it relaxes.
    cardEl.style.borderRadius = `${(radius0 * (1 - e) / z).toFixed(3)}px`;

    // The hero copy holds its ground and only leaves near the end — it should
    // read as having been left behind by the camera, not as having dissolved.
    const out = Math.max(0, (e - 0.55) / 0.4);
    for (const n of fadeEls) n.style.opacity = String(Math.max(0, 1 - out));

    const done = e > 0.995;
    cardEl.style.pointerEvents = done ? 'auto' : 'none';
    return e;
  }

  function flatten() {
    sceneEl.style.transform = '';
    sceneEl.style.transformOrigin = '';
    cardEl.style.borderRadius = '';
    cardEl.style.pointerEvents = '';
    planeEl.style.transform = '';
    planeEl.style.width = '';
    planeEl.style.height = '';
    for (const n of fadeEls) n.style.opacity = '';
  }

  measure();
  return { measure, apply, flatten, get scaleToFill() { return Z; } };
}
