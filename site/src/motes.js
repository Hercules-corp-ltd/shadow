/**
 * Motes in the light.
 *
 * The reference runs a genuine cell-based flame under its closing sections —
 * blocky, pixel-lit, rising. It is the single biggest reason its middle and
 * end feel alive rather than like frames sliding past: something on the page
 * is moving for its own reasons, not because you scrolled.
 *
 * Shadow is a cold page, so a fire would be a costume. The other half of the
 * same idea works better here: dust you only see because a hard light is
 * raking across it. Same physics, same rising drift, same additive light —
 * just the temperature moved.
 *
 * Kept blocky on purpose. Snapping every mote to a 3px grid gives the same
 * pixel-cell texture as the reference's flame, and it is also why this is
 * cheap: no gradients, no shadows, no per-particle state beyond six floats.
 * At 170 motes it is a couple of hundred fillRect calls a frame.
 */

const CELL = 3;
const COUNT = 170;

export function createMotes(canvas) {
  const ctx = canvas.getContext('2d', { alpha: true });
  if (!ctx) return null;

  let vw = 0, vh = 0, dpr = 1;
  let motes = [];

  function spawn(m, seeded) {
    m.x = Math.random() * vw;
    // On the first seed, scatter up the whole height; afterwards they enter
    // from below, which is what makes the field read as rising rather than
    // as a static dot pattern that happens to jitter.
    m.y = seeded ? Math.random() * vh : vh + Math.random() * 60;
    m.vy = 0.18 + Math.random() * 0.72;          // px per 16.7ms
    m.sway = 0.25 + Math.random() * 0.8;
    m.phase = Math.random() * Math.PI * 2;
    m.freq = 0.0007 + Math.random() * 0.0016;
    m.size = Math.random() < 0.16 ? 2 : 1;        // in cells
    m.warm = Math.random() < 0.78;
    m.a = 0.2 + Math.random() * 0.8;
  }

  function resize(w, h) {
    dpr = Math.min(2, window.devicePixelRatio || 1);
    if (w === vw && h === vh && canvas.width === Math.round(w * dpr)) return;
    const first = vw === 0;
    vw = w; vh = h;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (first || motes.length !== COUNT) {
      motes = Array.from({ length: COUNT }, () => {
        const m = {};
        spawn(m, true);
        return m;
      });
    }
  }

  /**
   * @param {number} dt      ms since the last frame
   * @param {number} amount  0..1 — how much of the field is lit right now
   * @param {number} rush    extra upward push from scroll speed, 0..1
   */
  function draw(dt, amount, rush) {
    ctx.clearRect(0, 0, vw, vh);
    if (amount <= 0.001) return;

    const step = Math.min(3, dt / 16.7);
    const lift = 1 + rush * 5.5;

    for (const m of motes) {
      m.y -= m.vy * step * lift;
      m.phase += m.freq * dt;
      if (m.y < -8) spawn(m, false);

      const x = m.x + Math.sin(m.phase) * m.sway * 26;

      // Fade at both ends of the travel so nothing pops into or out of
      // existence at the frame edge.
      const edge = Math.min(1, (vh - m.y) / (vh * 0.22), m.y / (vh * 0.3) + 0.15);
      const a = m.a * amount * Math.max(0, edge) * 0.5;
      if (a <= 0.004) continue;

      ctx.fillStyle = m.warm
        ? `rgba(255, 150, 66, ${a.toFixed(3)})`
        : `rgba(198, 214, 255, ${(a * 0.7).toFixed(3)})`;
      // Snap to the cell grid — this is what makes it read as pixels.
      ctx.fillRect(
        Math.round(x / CELL) * CELL,
        Math.round(m.y / CELL) * CELL,
        m.size * CELL,
        m.size * CELL,
      );
    }
  }

  function clear() { ctx.clearRect(0, 0, vw, vh); }

  return { resize, draw, clear };
}
