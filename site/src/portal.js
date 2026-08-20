/**
 * The zoom that opens the next page.
 *
 * This is the move the whole site is built around, so it is worth being exact
 * about what it is and is not.
 *
 * It is NOT a crossfade between a hero and a second section, and it is not a
 * scaled screenshot. The rest of the page is genuinely behind the phone's
 * screen the entire time — laid out at full viewport size, scaled down to fit
 * through the opening. Scrolling grows the opening until it is the viewport
 * and the scale reaches exactly 1. At that instant the content is pixel-for-
 * pixel a normal page, because it always was one; nothing swaps.
 *
 * ## The camera
 *
 * Growth is exponential, not linear:
 *
 *     z(t) = Z ** t      where Z = the scale needed to cover the viewport
 *
 * so z runs 1 → Z. Linear growth reads as a box being stretched; exponential
 * growth reads as a camera moving at constant speed toward a plane, because
 * apparent size under a dolly *is* exponential in distance. That single
 * substitution is most of why the effect feels like moving rather than
 * resizing.
 *
 * ## Why the opening is a clip and not a transform
 *
 * The opening has a border radius that has to relax to zero, and its content
 * must not scale with it — the content has its own scale. Two separate
 * transforms on nested nodes would multiply. So the opening is a plain clip
 * rect (width/height/border-radius) and the content inside carries the scale
 * on its own. They meet at exactly 1:1 at t = 1.
 */

/** Ease shaped so the first third is slow — that is where the phone reads as a phone. */
function ease(t, easeIn = 1.7, easeOut = 2.2) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const n = Math.pow(t, easeIn);
  return n / (n + Math.pow(1 - t, easeOut));
}

export function createPortal({ portalEl, planeEl, deviceEl, heroEl, shotEl }) {
  let vw = 0, vh = 0;
  /** The phone-screen rect in page coordinates, remeasured on resize. */
  let rect = { x: 0, y: 0, w: 320, h: 690, r: 34 };

  function measure() {
    vw = window.innerWidth;
    vh = window.innerHeight;
    const shot = deviceEl.querySelector('.device__shot');
    const target = shot || deviceEl;
    const b = target.getBoundingClientRect();
    if (b.width > 0) {
      const cs = getComputedStyle(target);
      rect = {
        x: b.left,
        y: b.top,
        w: b.width,
        h: b.height,
        r: parseFloat(cs.borderTopLeftRadius) || 30,
      };
    }
    // The plane is always laid out at viewport size; only its scale changes.
    planeEl.style.width = `${vw}px`;
    planeEl.style.height = `${vh}px`;
  }

  /**
   * @param {number} t 0 = phone on the hero, 1 = content fills the viewport.
   */
  function apply(t) {
    const e = ease(Math.min(1, Math.max(0, t)));

    // Each axis grows exponentially toward the viewport on its own.
    //
    // The first version used one factor — max(vw/w, vh/h) — for both axes and
    // then clamped. Because a phone is far taller than it is wide relative to
    // a landscape window, height hit the clamp at about a quarter of the way
    // through and the opening spent the rest of the zoom as a letterbox slot
    // widening sideways, which reads as a door sliding open rather than as
    // moving toward something. Interpolating the axes separately keeps it a
    // rectangle travelling toward you, drifts the aspect from phone to window
    // gradually enough not to notice, and lands exactly on the viewport at
    // e = 1 with no clamping.
    const w = rect.w * Math.pow(vw / rect.w, e);
    const h = rect.h * Math.pow(vh / rect.h, e);

    // The opening's centre travels from the phone to the middle of the screen.
    const cx0 = rect.x + rect.w / 2;
    const cy0 = rect.y + rect.h / 2;
    const cx = cx0 + (vw / 2 - cx0) * e;
    const cy = cy0 + (vh / 2 - cy0) * e;

    portalEl.style.width = `${w}px`;
    portalEl.style.height = `${h}px`;
    portalEl.style.left = `${cx - w / 2}px`;
    portalEl.style.top = `${cy - h / 2}px`;
    portalEl.style.borderRadius = `${rect.r * (1 - e)}px`;

    // The content's scale is the opening's width against the viewport, so the
    // two reach 1:1 at the same instant.
    const scale = Math.min(1, w / vw);
    planeEl.style.transform = `scale(${scale.toFixed(5)})`;

    // The app's own screen, sitting on top of the content inside the opening.
    //
    // Without this the portal covers the phone's screenshot at rest, so the
    // hero shows a 19%-scale web page inside a phone frame instead of showing
    // the app. It is the same image, in the same rect, as the one behind it —
    // so at e = 0 there is no seam — and it clears during the first half of
    // the zoom to reveal the page that was always behind it.
    if (shotEl) {
      const shotOut = Math.min(1, Math.max(0, (e - 0.06) / 0.44));
      shotEl.style.opacity = String(1 - shotOut);
    }

    // The hero pulls back and dims as the opening takes over. It is hidden
    // outright at the end so it cannot eat pointer events or be tabbed into
    // while off-screen.
    const heroOut = Math.min(1, e / 0.75);
    heroEl.style.opacity = String(1 - heroOut);
    heroEl.style.transform = `scale(${(1 - heroOut * 0.06).toFixed(4)})`;
    const gone = e > 0.92;
    if (gone !== heroEl.dataset.gone) {
      heroEl.dataset.gone = String(gone);
      heroEl.style.visibility = gone ? 'hidden' : '';
      heroEl.setAttribute('aria-hidden', gone ? 'true' : 'false');
      heroEl.querySelectorAll('a, button').forEach((n) => {
        if (gone) n.setAttribute('tabindex', '-1');
        else n.removeAttribute('tabindex');
      });
    }

    // Only interactive once it is actually open.
    portalEl.style.pointerEvents = e > 0.98 ? 'auto' : 'none';
    return e;
  }

  /** Static fallback: no zoom, everything at rest and full size. */
  function flatten() {
    portalEl.style.cssText = '';
    portalEl.classList.add('portal--flat');
    if (shotEl) shotEl.style.opacity = '';
    planeEl.style.transform = '';
    planeEl.style.width = '';
    planeEl.style.height = '';
    heroEl.style.opacity = '';
    heroEl.style.transform = '';
    heroEl.style.visibility = '';
    heroEl.removeAttribute('aria-hidden');
  }

  measure();
  return { measure, apply, flatten, get rect() { return rect; } };
}
