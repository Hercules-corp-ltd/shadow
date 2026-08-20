/**
 * The camera, and the opening rectangle.
 *
 * Three attempts got this wrong in three different ways, and the failures are
 * worth keeping written down because each one looks fine in the numbers.
 *
 *  1. Grew the card, held the hero still, faded it. Reads as a panel expanding
 *     over a page — no sense of travel at all.
 *
 *  2. Scaled the whole scene about the card. The headline grows and leaves,
 *     which is right, but the card keeps the phone's 0.44 aspect the entire
 *     way. A portrait window revealing landscape content has to grow to about
 *     four times the viewport *height* before its width fills the screen, so
 *     most of the zoom is a small block of content marooned in a tall black
 *     rectangle. On screen it reads as a fade, because the only thing actually
 *     changing is what is inside a shape whose edges left the frame early.
 *
 *  3. This one. Two things move at once:
 *
 *       · the SCENE scales, so the headline grows and slides out of frame the
 *         way it would through a lens;
 *       · the RECTANGLE itself morphs — its on-screen box interpolates from
 *         the phone's screen to the viewport, each axis on its own exponential.
 *
 *     So the opening is always a real rectangle with visible edges, travelling
 *     toward you *and* unfolding from a phone into a page. And the content
 *     inside it fills it at every instant rather than floating in it, which is
 *     what makes it read as a window rather than a picture frame.
 *
 * ## Keeping the content exactly filling the opening
 *
 * The plane is a child of the card, so it inherits the scene scale `z`. Its own
 * scale is therefore chosen to cancel `z` and land on the opening's current
 * on-screen width:
 *
 *     planeScale = wScreen / (viewportWidth * z)
 *
 * At rest that is cardWidth/viewportWidth — a miniature exactly filling the
 * phone. At the end it is 1/Z, which the scene's Z multiplies back to 1: life
 * size, pixel for pixel, with nothing swapped.
 */

/**
 * Slow at the front.
 *
 * The first third is where the phone still reads as a phone, and it is the
 * part worth spending scroll on. Attempt 2 used (1.75, 2.15), which put the
 * eased value at 0.57 by the time the raw one reached 0.5 — the headline was
 * off-frame before half the gesture was done.
 */
function ease(t, easeIn = 2.6, easeOut = 1.5) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const n = Math.pow(t, easeIn);
  return n / (n + Math.pow(1 - t, easeOut));
}

export function createCamera({ sceneEl, cardEl, planeEl, phoneEl, fadeEls = [] }) {
  const bezelEls = phoneEl ? (Array.isArray(phoneEl) ? phoneEl : [phoneEl]) : [];
  let vw = 0, vh = 0;
  let Z = 4;
  let card0 = { w: 212, h: 486, r: 25 };
  let origin = { x: 0, y: 0 };
  let start = { x: 0, y: 0 };
  let progress = 0;   // the eased value, exposed so callers can time against it

  function measure() {
    vw = window.innerWidth;
    vh = window.innerHeight;

    const prev = sceneEl.style.transform;
    sceneEl.style.transform = 'none';
    // Clear any size we imposed, so we measure the layout's own idea of the card.
    cardEl.style.height = '';
    cardEl.style.top = '';

    const s = sceneEl.getBoundingClientRect();
    const c = cardEl.getBoundingClientRect();

    card0 = {
      w: Math.max(1, c.width),
      h: Math.max(1, c.height),
      r: parseFloat(getComputedStyle(cardEl).borderTopLeftRadius) || 25,
    };
    origin = { x: c.left - s.left + c.width / 2, y: c.top - s.top + c.height / 2 };
    start = { x: c.left + c.width / 2, y: c.top + c.height / 2 };
    Z = vw / card0.w;

    sceneEl.style.transformOrigin = `${origin.x}px ${origin.y}px`;
    planeEl.style.width = `${vw}px`;
    planeEl.style.height = `${vh}px`;

    sceneEl.style.transform = prev;
  }

  /**
   * @param {number} t 0 = phone on the hero; 1 = the page fills the viewport.
   */
  function apply(t) {
    const e = progress = ease(Math.min(1, Math.max(0, t)));
    const z = Math.pow(Z, e);

    // The card keeps the scene's scale for its WIDTH — so it stays married to
    // everything else growing — and animates only its height, which is what
    // opens the aspect from a phone to a window. Height is in scene units;
    // the scene multiplies it by z.
    //
    // Front-loaded (e ** 0.55) so most of the opening happens while the app
    // screenshot is still fading. If it lagged, the content would sit
    // letterboxed in a tall black box for the middle third of the zoom, which
    // was the previous failure.
    // Open the aspect EARLY and be done with it.
    //
    // e ** 0.55 was far too lazy: with the slow-in ease, e is only ~0.29 when
    // half the scroll is spent, so the box was still twice as tall as its
    // content and the page sat letterboxed in black bands through the middle
    // of the zoom. Reaching viewport aspect by e = 0.25 means the shape is
    // settled while the screenshot is still covering it, and everything after
    // that is pure travel — a rectangle of the right shape flying at you.
    const k = Math.min(1, e / 0.25);
    const hCss = card0.h + (vh / Z - card0.h) * k;
    cardEl.style.height = `${hCss.toFixed(3)}px`;
    // Grow about the centre rather than the top edge.
    cardEl.style.top = `${(6 - (hCss - card0.h) / 2).toFixed(3)}px`;
    cardEl.style.borderRadius = `${(card0.r * (1 - e)).toFixed(3)}px`;

    // Constant: the plane fills the card's width at every instant, and since
    // the card ends at exactly the viewport, so does the plane. (1/Z) * Z = 1.
    planeEl.style.transform = `translate(-50%, -50%) scale(${(1 / Z).toFixed(6)})`;

    const dx = (vw / 2 - start.x) * e;
    const dy = (vh / 2 - start.y) * e;
    sceneEl.style.transform =
      `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${z.toFixed(5)})`;

    // You go THROUGH the phone. It does not fade.
    //
    // Fading it out was the lazy answer and it read exactly like what it was:
    // the device dissolving rather than the camera arriving. A frame you fly
    // into has to pass you — grow until its edges leave the viewport on all
    // four sides and you are through it.
    //
    // So the bezel gets its own scale ON TOP of the scene's. The scene is
    // already at z = Z**e; multiplying by Z**(e*rush) means the bezel reaches
    // full-viewport width at e = 1/(1+rush) instead of at e = 1, and keeps
    // going after that. With rush = 1.22 it passes the frame edge at about
    // 45% of the zoom, which is where a doorway stops being a doorway and
    // becomes the walls either side of you.
    const rush = Math.pow(Z, e * 1.22);
    for (const n of bezelEls) n.style.transform = `scale(${rush.toFixed(4)})`;

    // The hero copy is NOT faded. It is carried out of frame by the same scale
    // that is carrying everything else, which is the only reason the move reads
    // as travel — the instant you dim something it reads as a slideshow
    // transition instead, however slow the dim is. By the time it would have
    // started fading it is already several viewports wide and mostly past the
    // edge; there is nothing left to hide.
    void fadeEls;

    cardEl.style.pointerEvents = e > 0.995 ? 'auto' : 'none';
    return e;
  }

  function flatten() {
    for (const [el, props] of [
      [sceneEl, ['transform', 'transformOrigin']],
      [cardEl, ['height', 'top', 'borderRadius', 'pointerEvents']],
      [planeEl, ['transform', 'width', 'height']],
    ]) {
      if (!el) continue;
      for (const p of props) el.style[p] = '';
    }
    for (const n of fadeEls) n.style.opacity = '';
    for (const n of bezelEls) n.style.transform = '';
  }

  measure();
  return { measure, apply, flatten, get scaleToFill() { return Z; }, get progress() { return progress; } };
}
