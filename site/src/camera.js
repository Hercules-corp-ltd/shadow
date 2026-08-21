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
 *  4. Attempt 3 with its arithmetic corrected — this file, now. Two things
 *     were wrong and they produced one symptom.
 *
 *     The morph was scheduled against `e` alone (finish by e = 0.25) rather
 *     than against the scale. The aspect-correct height is (vh/Z)*z, which at
 *     rest is 98.55px against the phone's 403.97 — a QUARTER of it — and it
 *     does not overtake the resting height until e = ln(h0*Z/vh)/lnZ = 0.709.
 *     Interpolating straight to it therefore drove the card's ON-SCREEN height
 *     DOWN: measured 404, 400, 384, 280, 162, 273, 402 at t = 0, 0.15, 0.25,
 *     0.40, 0.46, 0.60, 0.70. Seventy per cent of the opening was spent flying
 *     at a window smaller than the one it started as, bottoming out at 40.1%.
 *
 *     And the bezel — the phone's own aspect, scaled uniformly by Z**(e*1.22) —
 *     filled the room that left with 1854px of grey at t = 0.60. That grey was
 *     the artefact everyone saw; the shrinking window was the reason for it.
 *
 *     The height now HOLDS until the aspect-correct one has caught up, and the
 *     bezel is drawn from the card's box. Measured after: the on-screen height
 *     never drops below 402.0px — 0.5% — and is monotone from there to 720.
 *
 *  5. The consequence of 4, which is the interesting part: once the card holds
 *     its height it is TALLER than the plane inside it, and the difference
 *     used to be the card's own black. It is not, any more, because the plane
 *     is docked to the card's bottom edge and the screenshot scrolls up off it
 *     — one edge, with the home screen above and the arriving page below. See
 *     the dock in apply() and the weld in main.js's frame().
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
/*
 * easeIn 2.6 -> 2.0.
 *
 * 2.6 was chosen to keep the front of the zoom slow, which is right — the first
 * third is where the phone still reads as a phone and is worth spending scroll
 * on. But t**2.6 is very nearly flat near zero, and zero is where the loop
 * WRAPS. Measured: the first 50px after the seam moved the hero 0.4px in total.
 * Together with the close arriving at a standstill it made ~75px of scroll in
 * which nothing visibly happened — a pause, right at the join the whole design
 * is built to hide.
 *
 * 2.0 still starts slower than linear (e = 0.414 at t = 0.5, against 0.318 at
 * 2.6 and 0.5 for linear), so the phone still holds its shape through the
 * opening. It is nowhere near the 1.75 of attempt 2, which put e past 0.5 by
 * half the gesture and threw the headline off-frame early.
 */
function ease(t, easeIn = 2.0, easeOut = 1.5) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const n = Math.pow(t, easeIn);
  return n / (n + Math.pow(1 - t, easeOut));
}

export function createCamera({ sceneEl, cardEl, planeEl, frameEl, glossEl, fadeEls = [] }) {
  let vw = 0, vh = 0;
  let Z = 4;
  let card0 = { w: 212, h: 486, r: 25 };
  // The bezel, measured off the stylesheet rather than assumed. Whatever the
  // sheet insets the card by inside the phone body IS the rim, and it is the
  // rim the recursion clone is still showing at the seam.
  let rim = { x: 6, y: 6 };
  let top0 = 6;               // the card's resting top inside the phone body
  let origin = { x: 0, y: 0 };
  let start = { x: 0, y: 0 };
  let progress = 0;   // the eased value, exposed so callers can time against it
  // The three moments the opening is timed against, all in eased t. Written by
  // measure(), because every one of them is a function of the viewport:
  //   morphFill  the aspect-correct height finally equals the resting height
  //   morphFrom  the box starts handing its height over to the aspect-correct one
  //   morphTo    the hand-over is complete and the plane fills the card exactly
  let morphFill = 0.7, morphFrom = 0.63, morphTo = 0.87;

  function measure() {
    // A hidden or zero-size viewport reports 0 — a backgrounded browser pane
    // does exactly this, and scaleToFill came back 0 on first load because of
    // it. Z = 0 makes hCss, the dock and the plane scale all Infinity, so every
    // transform written below becomes an invalid declaration and is dropped;
    // worse, main.js's `win = vh / camera.scaleToFill` would then disagree with
    // the dock computed here and the two halves of the weld would separate.
    // Guarding at the source keeps them consistent by construction. Keep the
    // last good measurement instead of poisoning the frame.
    if (!window.innerWidth || !window.innerHeight) return;
    vw = window.innerWidth;
    vh = window.innerHeight;

    const prev = sceneEl.style.transform;
    sceneEl.style.transform = 'none';
    // Clear EVERYTHING we imposed, so we measure the layout's own idea of the
    // card and of the bezel around it. The RADIUS matters as much as the box:
    // it is read back three lines down, and reading back the value written last
    // frame made a resize mid-zoom restart the corners from wherever they had
    // got to instead of from 25px.
    cardEl.style.height = '';
    cardEl.style.top = '';
    cardEl.style.borderRadius = '';
    if (frameEl) { frameEl.style.top = ''; frameEl.style.height = ''; frameEl.style.borderRadius = ''; }

    const s = sceneEl.getBoundingClientRect();
    const c = cardEl.getBoundingClientRect();

    card0 = {
      w: Math.max(1, c.width),
      h: Math.max(1, c.height),
      r: parseFloat(getComputedStyle(cardEl).borderTopLeftRadius) || 25,
    };
    top0 = parseFloat(getComputedStyle(cardEl).top) || 0;
    // Measured 6px on both axes at 1280x720. Measured rather than hardcoded so
    // that changing `.card`'s inset moves the bezel with it instead of silently
    // separating the two shapes again.
    if (frameEl) {
      const f = frameEl.getBoundingClientRect();
      rim = { x: Math.max(0, c.left - f.left), y: Math.max(0, c.top - f.top) };
    }
    origin = { x: c.left - s.left + c.width / 2, y: c.top - s.top + c.height / 2 };
    start = { x: c.left + c.width / 2, y: c.top + c.height / 2 };
    Z = vw / card0.w;

    // Where the aspect-correct height catches up with the height the card
    // starts at. That height is vh/Z on screen at rest — 98.55px against the
    // phone's 403.97 at 1280x720 — and it grows by Z**e, so it overtakes at
    // e = ln(h0*Z/vh)/lnZ: 0.709 here. Every timing in the second half of the
    // opening hangs off this one number, because it is the first instant at
    // which the card can be viewport-shaped without being smaller than the
    // phone screen it came from.
    //
    // Viewport-dependent by nature: on a 390x844 phone, where the device aspect
    // is already close to the viewport's, it lands at 0.068 and the hold below
    // does almost nothing. That is the right answer there.
    const lnZ = Math.log(Z);
    morphFill = lnZ > 1e-6
      ? Math.min(0.98, Math.max(0, Math.log((card0.h * Z) / vh) / lnZ))
      : 0;
    morphFrom = Math.max(0, morphFill - 0.07);
    morphTo = Math.min(1, Math.max(morphFrom + 0.12, morphFill + 0.16));

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
    // Two heights are in play at every instant, and the mistake was to treat
    // only one of them as real:
    //
    //   hold  what the phone's screen measures ON SCREEN if it simply travels
    //         toward you — card0.h, unchanged, forever;
    //   fill  the height at which the box has the viewport's aspect, which is
    //         the only height at which the plane exactly fills it.
    //
    // `fill` is (vh/Z)*z. At rest that is 98.55px against the phone's 403.97,
    // and it does not overtake `hold` until e = 0.709. The old min(1, e/0.25)
    // interpolated straight to it and therefore made the card SHRINK as you
    // approached: 404, 400, 384, 280, 162, 273, 402 at t = 0, 0.15, 0.25, 0.40,
    // 0.46, 0.60, 0.70. Below where it started for the first 70% of the
    // gesture, bottoming at 40.1%.
    //
    // So the box HOLDS its on-screen height until `fill` has caught up, and
    // hands over with a smoothstep so the top and bottom edges do not start
    // moving from a standstill. Both ends of the hand-over have zero first
    // derivative, which is why the eased-ramp patch the old law needed is not
    // here: there is no corner left to smooth. Measured after: the on-screen
    // height never drops below 402.0px and is monotone from there to 720.
    //
    // The card is briefly SHORTER than the plane between morphFill and morphTo
    // — 10.3px per edge at e = 0.773, worst case. With the plane docked to the
    // card's bottom edge that band is clipped off the TOP of the window, and at
    // that instant the screenshot still covers card pixels [-0.677*win,
    // hCss - 0.677*win], which contains all of it. Nothing visible is cropped.
    const kt = Math.min(1, Math.max(0, (e - morphFrom) / Math.max(1e-4, morphTo - morphFrom)));
    const k = kt * kt * (3 - 2 * kt);
    const hHoldCss = card0.h / z;      // constant ON SCREEN, so shrinking in scene units
    const hCss = hHoldCss + (vh / Z - hHoldCss) * k;
    cardEl.style.height = `${hCss.toFixed(3)}px`;
    // Grow about the centre rather than the top edge. Named, and taken from the
    // MEASURED resting top rather than a literal 6, because the bezel below is
    // now drawn from this number: the rim is the card's box, one rim further
    // out on every side.
    const topCss = top0 - (hCss - card0.h) / 2;
    cardEl.style.top = `${topCss.toFixed(3)}px`;
    cardEl.style.borderRadius = `${(card0.r * (1 - e)).toFixed(3)}px`;

    // Constant scale: the plane fills the card's width at every instant, and
    // since the card ends at exactly the viewport, so does the plane.
    // (1/Z) * Z = 1.
    //
    // And DOCKED vertically, which is the one piece of geometry that lets the
    // phone read as a device being scrolled rather than a lid coming off.
    //
    // The card and the page-window are not the same rectangle until the aspect
    // has finished opening. At rest the card is the phone's screen — 175 x 404
    // at 1280x720 — and the window is one viewport at 1/Z, 175 x 98.5. It is
    // 4.10x shorter (the ratio is 2.31 * vw/vh; 5.21 at 1440x640), and centred
    // it sat in the MIDDLE of the phone screen. So the first section began
    // halfway up the screenshot, and no way of sliding the screenshot turns
    // that into a scroll: filling the phone at rest wants its bottom edge at
    // 404, and butting against the section wants it at 251.
    //
    // Docked, the window's bottom edge sits on the card's bottom edge, so in
    // card pixels the screenshot's bottom edge and the first section's top edge
    // are the same expression, hCss - s*win, for every e and every s. main.js
    // then moves that edge, and only that edge.
    //
    // Written BEFORE the scale, so it is in CARD pixels — a translate placed
    // after scale(1/Z) would be in plane pixels and land 7.3x short.
    //
    // At e = 1 the hand-over is complete, hCss IS vh/Z, and this term is
    // exactly 0.000 — so the arrival, the whole middle of the loop, the close
    // and the seam never see it. The emitted string then differs from the old
    // one only by a literal `translateY(0px)`.
    const dock = (hCss - vh / Z) / 2;
    planeEl.style.transform =
      `translate(-50%, -50%) translateY(${dock.toFixed(3)}px) scale(${(1 / Z).toFixed(6)})`;

    const dx = (vw / 2 - start.x) * e;
    const dy = (vh / 2 - start.y) * e;
    sceneEl.style.transform =
      `translate(${dx.toFixed(2)}px, ${dy.toFixed(2)}px) scale(${z.toFixed(5)})`;

    // The bezel is a RIM, and a rim is defined by the thing it surrounds.
    //
    // It used to be an inset:0 box scaled uniformly by Z**(e*1.22) while the
    // card morphed to a different aspect underneath it, so the two shapes came
    // apart. Measured gap, top and bottom, at t = 0, 0.40, 0.60, 0.70, 0.80,
    // 1.00: 6.0, 292.3, 1854.1, 4506.1, 9086.4, 16835.9px. At t = 0.60 that is
    // a 485x273 card inside a 1791x3981 frame — the grey slab that gave the
    // whole thing away. Drawn from the card's box instead: 6.0, 8.3, 16.6,
    // 24.5, 33.3, 43.8px, equal on all four sides for the whole journey.
    //
    // You still go THROUGH it. The rim sits OUTSIDE a card that ends up exactly
    // the viewport, so its edges have to cross the frame edge before the card
    // does: e = 0.9437 for top and bottom, e = 0.9719 for left and right (raw
    // t = 0.878 and 0.919), which is the fastest the scale ever moves. The
    // scene's translate only centres the card at e = 1, so between t = 0.87 and
    // t = 0.92 the strip left over is ONE-SIDED — 51.9px of backdrop down the
    // left at t = 0.87, 17.9px at t = 0.90, nothing on the right. The frame's
    // own drop shadow largely fills it. That is seeing past the device, and it
    // lasts about thirty pixels of scroll.
    //
    // Only top and height are written. left/right are pinned by the stylesheet,
    // and card0.w + 2*rim.x IS the frame's own width, so the horizontal rim is
    // right for free and stays right on resize.
    //
    // The two lines this replaces were applied BY CLASS, which is why they also
    // drove the bezel of the clone inside the last stage — measured 2118x4707
    // at (-180, -1974), an opaque gradient covering 100% of the viewport at
    // u = 0.97, one frame before the seam, and gone at pos = 0. Deleting them
    // removes a seam violation; it does not add one.
    if (frameEl) {
      frameEl.style.top = `${(topCss - rim.y).toFixed(3)}px`;
      frameEl.style.height = `${(hCss + rim.y * 2).toFixed(3)}px`;
      // Concentric with the card: same centre, one rim further out.
      frameEl.style.borderRadius = `${(card0.r * (1 - e) + rim.y).toFixed(3)}px`;
    }

    // The reflection is on the glass, so it goes when you go through the glass.
    // It may not fade, so it slides — up and out of the card, which clips it.
    // The screen opens like a shutter instead of dissolving.
    //
    // Timed off morphFrom/morphTo so it leaves while the box is opening rather
    // than on a clock of its own. At e = 1 it is translated -118% of its own
    // height and is entirely above the clip: measured bottom edge at y = -129.7
    // against a card top edge at y = -0.1. Continuity across the wrap is not
    // needed for it; invisibility is proven.
    if (glossEl) {
      const gt = Math.min(1, Math.max(0,
        (e - morphFrom) / Math.max(1e-4, (morphTo - morphFrom) * 0.7)));
      const g = gt * gt * (3 - 2 * gt);
      glossEl.style.transform = `translate3d(0, ${(-g * 118).toFixed(2)}%, 0)`;
    }

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
      [frameEl, ['top', 'height', 'borderRadius']],
      [glossEl, ['transform']],
    ]) {
      if (!el) continue;
      for (const p of props) el.style[p] = '';
    }
    for (const n of fadeEls) n.style.opacity = '';
  }

  measure();
  return { measure, apply, flatten, get scaleToFill() { return Z; }, get progress() { return progress; } };
}
