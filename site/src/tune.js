/**
 * Every number this page's feel depends on, in one object, editable live.
 *
 * Taste arguments are unwinnable in a code review and settled in about ninety
 * seconds with a slider. Open with `?tune` in the URL or Cmd/Ctrl + period; the
 * panel writes straight into this object, which the render loop reads fresh
 * every frame, so nothing needs re-initialising.
 *
 * The panel is built only when asked for, so it costs nothing in production.
 */

export const TUNE = {
  // -- scroll ------------------------------------------------------------
  smoothingMs: 380,       // how long the shown value takes to catch the raw one
  touchMultiplier: 2,     // a thumb travels less than a wheel
  friction: 0.94,         // fling decay per 16.67 ms
  navGlideMs: 1400,       // click a nav item

  // -- stages ------------------------------------------------------------
  stageTravel: 0.92,      // how far a stage moves, in viewport heights
  stageShrink: 0.11,      // scale falloff with distance
  stageFade: 0.78,        // distance at which a stage is fully gone
  stageBlur: 7,           // px of blur at the far edge

  // -- text --------------------------------------------------------------
  scrambleMs: 620,
  scrambleWave: 0.55,     // how much of the run is spent sweeping across
  scrambleChurn: 0.22,    // re-roll chance per frame for an unsettled glyph
  scrambleJitter: 0.4,    // raggedness of the settle front

  // -- pointer -----------------------------------------------------------
  magnetStrength: 0.22,
  magnetRadius: 56,
  magnetMax: 7,
  magnetLabelParallax: 1.35,
  magnetEaseMs: 130,
  hoverFadeMs: 140,

  // -- marker ------------------------------------------------------------
  markerWidthFrac: 0.5,
  markerOmega: 30,        // spring stiffness
  markerZeta: 0.65,       // under 1 so it overshoots and settles
  markerEaseMs: 160,
  markerTrailMs: 400,
  markerTrailAmt: 0.5,

  // -- light -------------------------------------------------------------
  warm: '#F97316',
  cool: '#2A1B12',
  lightIntensity: 0.42,
  grain: 0.045,

  // -- performance -------------------------------------------------------
  motionResEnter: 4,      // px/frame above which we drop resolution
  motionResExit: 1.2,
  motionResCalmMs: 180,
  motionResScale: 0.7,
  idleFps: 30,            // when nothing is moving
};

const RANGES = {
  smoothingMs: [80, 900, 10], touchMultiplier: [0.5, 4, 0.1], friction: [0.85, 0.99, 0.005],
  navGlideMs: [300, 3000, 50],
  stageTravel: [0.3, 1.6, 0.02], stageShrink: [0, 0.4, 0.01], stageFade: [0.4, 1.4, 0.02],
  stageBlur: [0, 20, 0.5],
  scrambleMs: [120, 1800, 20], scrambleWave: [0, 0.95, 0.05], scrambleChurn: [0, 1, 0.02],
  scrambleJitter: [0, 1, 0.05],
  magnetStrength: [0, 0.8, 0.01], magnetRadius: [0, 200, 4], magnetMax: [0, 30, 1],
  magnetLabelParallax: [1, 3, 0.05], magnetEaseMs: [40, 500, 10], hoverFadeMs: [40, 500, 10],
  markerWidthFrac: [0.1, 1, 0.02], markerOmega: [5, 60, 1], markerZeta: [0.2, 1.5, 0.05],
  markerEaseMs: [40, 600, 10], markerTrailMs: [80, 1200, 20], markerTrailAmt: [0, 1, 0.05],
  lightIntensity: [0, 1.2, 0.02], grain: [0, 0.2, 0.005],
  motionResEnter: [1, 20, 0.5], motionResExit: [0.2, 10, 0.1], motionResCalmMs: [0, 1000, 20],
  motionResScale: [0.3, 1, 0.05], idleFps: [5, 60, 1],
};

export function mountTunePane(tune, { loop } = {}) {
  let pane = null;

  function build() {
    if (pane) return pane;
    pane = document.createElement('div');
    pane.className = 'tune';
    pane.innerHTML = '<header>tune <small>⌘. to hide</small></header>';

    for (const key of Object.keys(tune)) {
      const v = tune[key];
      const row = document.createElement('label');
      row.className = 'tune__row';

      const name = document.createElement('span');
      name.className = 'tune__name';
      name.textContent = key;
      row.append(name);

      if (typeof v === 'string' && v.startsWith('#')) {
        const inp = document.createElement('input');
        inp.type = 'color';
        inp.value = v;
        inp.addEventListener('input', () => { tune[key] = inp.value; });
        row.append(inp);
      } else if (typeof v === 'number') {
        const [min, max, step] = RANGES[key] || [0, v * 3 || 1, 0.01];
        const inp = document.createElement('input');
        inp.type = 'range';
        inp.min = String(min); inp.max = String(max); inp.step = String(step);
        inp.value = String(v);
        const out = document.createElement('output');
        out.textContent = String(v);
        inp.addEventListener('input', () => {
          tune[key] = +inp.value;
          out.textContent = inp.value;
        });
        row.append(inp, out);
      }
      pane.append(row);
    }

    const dump = document.createElement('button');
    dump.type = 'button';
    dump.className = 'tune__dump';
    dump.textContent = 'copy values';
    dump.addEventListener('click', () => {
      navigator.clipboard?.writeText(JSON.stringify(tune, null, 2));
      dump.textContent = 'copied';
      setTimeout(() => { dump.textContent = 'copy values'; }, 1200);
    });
    pane.append(dump);

    document.body.append(pane);
    return pane;
  }

  function toggle(on) {
    const p = build();
    p.style.display = on ?? p.style.display === 'none' ? 'block' : 'none';
  }

  if (new URLSearchParams(location.search).has('tune')) toggle(true);

  window.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === '.') {
      e.preventDefault();
      const p = build();
      p.style.display = p.style.display === 'none' || !p.style.display ? 'block' : 'none';
    }
    // A loop with no end is hard to survey; this walks it hands-free.
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k' && loop) {
      e.preventDefault();
      clearInterval(window.__auto);
      if (!window.__autoOn) { window.__auto = setInterval(() => loop.nudge(9), 16); window.__autoOn = true; }
      else window.__autoOn = false;
    }
  });
}
