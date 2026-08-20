/**
 * The light the whole page sits in.
 *
 * This is the app's `AmbientLight` ported to WebGL: a few slow warm pools
 * drifting over black, a vignette, and grain. Deliberately the same idea in
 * both places so the site and the thing it is selling feel like one object.
 *
 * ## Why WebGL for something this simple
 *
 * Three overlapping radial gradients could be CSS. But they are animated
 * continuously behind the whole page, and CSS gradient animation forces a
 * full-layer repaint every frame at whatever size the window happens to be. On
 * a 4K display that is the single most expensive thing on the page. In a shader
 * it is a handful of instructions per pixel, and — crucially — we can drop the
 * render scale while the user is moving without touching layout.
 *
 * ## Degradation
 *
 * If WebGL is unavailable the canvas stays empty and CSS underneath provides a
 * static version of the same palette. Nothing here is load-bearing for reading
 * the page.
 */

const VERT = `#version 300 es
in vec2 p;
void main() { gl_Position = vec4(p, 0.0, 1.0); }`;

const FRAG = `#version 300 es
precision highp float;

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;      // seconds
uniform float uScroll;    // 0..1 around the loop
uniform vec3  uWarm;
uniform vec3  uCool;
uniform float uIntensity;
uniform float uGrain;

/* Cheap hash-based value noise; only used for grain, so quality barely matters. */
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

/*
 * One drifting pool. Each is an anisotropic falloff rather than a circle —
 * light coming through a gap between columns is taller than it is wide, and
 * the difference is most of what sells it.
 */
float pool(vec2 uv, vec2 c, float rx, float ry) {
  vec2 d = (uv - c) / vec2(rx, ry);
  float r = dot(d, d);
  return exp(-r * 2.2);
}

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  float aspect = uRes.x / uRes.y;
  uv.x *= aspect;

  /*
   * Three pools on wildly different periods — 47, 59 and 71 seconds. Primes,
   * so the pattern does not visibly repeat inside any session. The same three
   * numbers are used in the app.
   */
  float t = uTime;
  vec2 a = vec2(0.30 * aspect + 0.10 * sin(t / 47.0), 0.62 + 0.07 * cos(t / 59.0));
  vec2 b = vec2(0.78 * aspect + 0.08 * cos(t / 59.0), 0.30 + 0.09 * sin(t / 71.0));
  vec2 c = vec2(0.55 * aspect + 0.12 * sin(t / 71.0), 0.85 + 0.05 * cos(t / 47.0));

  /* Scroll shifts the pools sideways so movement feels like travel, not drift. */
  float s = uScroll * 6.28318530718;
  a.x += 0.05 * sin(s);
  b.x -= 0.07 * sin(s);
  c.x += 0.03 * cos(s);

  float la = pool(uv, a, 0.42, 0.30) * 1.00;
  float lb = pool(uv, b, 0.34, 0.26) * 0.75;
  float lc = pool(uv, c, 0.50, 0.22) * 0.55;

  vec3 col = uWarm * (la + lc) + uCool * lb;
  col *= uIntensity;

  /* Vignette, so the edges of the frame stay properly black. */
  vec2 vc = gl_FragCoord.xy / uRes - 0.5;
  col *= 1.0 - smoothstep(0.32, 0.86, dot(vc, vc) * 2.0);

  /*
   * Grain, added not multiplied. On a near-black field a little additive noise
   * is what stops 8-bit gradients from banding into visible rings, which is
   * otherwise very obvious on a dark page.
   */
  float g = hash(gl_FragCoord.xy + fract(uTime) * 137.0) - 0.5;
  col += g * uGrain;

  fragColor = vec4(max(col, 0.0), 1.0);
}`;

function compile(gl, type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
    console.warn('[backdrop]', gl.getShaderInfoLog(s));
    gl.deleteShader(s);
    return null;
  }
  return s;
}

export function createBackdrop(canvas, tune) {
  const gl = canvas.getContext('webgl2', {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    powerPreference: 'low-power',
  });
  if (!gl) return null;

  const vs = compile(gl, gl.VERTEX_SHADER, VERT);
  const fs = compile(gl, gl.FRAGMENT_SHADER, FRAG);
  if (!vs || !fs) return null;

  const prog = gl.createProgram();
  gl.attachShader(prog, vs);
  gl.attachShader(prog, fs);
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
    console.warn('[backdrop]', gl.getProgramInfoLog(prog));
    return null;
  }
  gl.deleteShader(vs);
  gl.deleteShader(fs);

  // One triangle covering the viewport. Two would need an extra vertex and a
  // diagonal seam that some drivers shade twice.
  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const loc = gl.getAttribLocation(prog, 'p');
  gl.enableVertexAttribArray(loc);
  gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

  const u = {};
  for (const n of ['uRes', 'uTime', 'uScroll', 'uWarm', 'uCool', 'uIntensity', 'uGrain']) {
    u[n] = gl.getUniformLocation(prog, n);
  }

  const hexToRgb = (hex) => {
    const n = parseInt(hex.replace('#', ''), 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
  };

  let w = 0, h = 0, scale = 1;

  function resize(cssW, cssH, renderScale) {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const nw = Math.max(1, Math.round(cssW * dpr * renderScale));
    const nh = Math.max(1, Math.round(cssH * dpr * renderScale));
    if (nw === w && nh === h && renderScale === scale) return;
    w = nw; h = nh; scale = renderScale;
    canvas.width = w;
    canvas.height = h;
    gl.viewport(0, 0, w, h);
  }

  function draw(timeSec, scroll01) {
    gl.useProgram(prog);
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    gl.uniform2f(u.uRes, w, h);
    gl.uniform1f(u.uTime, timeSec);
    gl.uniform1f(u.uScroll, scroll01);
    gl.uniform3fv(u.uWarm, hexToRgb(tune.warm));
    gl.uniform3fv(u.uCool, hexToRgb(tune.cool));
    gl.uniform1f(u.uIntensity, tune.lightIntensity);
    gl.uniform1f(u.uGrain, tune.grain);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  return {
    resize,
    draw,
    dispose() {
      gl.deleteBuffer(buf);
      gl.deleteProgram(prog);
    },
  };
}
