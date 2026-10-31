// 2026-10-31 エフェクト専用の WebGL の層（試作）。現場の作り方（アルファ侵食・色の帯〈グラデーションマップ〉・帯の上を流れる絵）を、ライブラリなしの小さなシェーダーで。
// 1つの舞台に1枚のキャンバスを重ね、加算（色の出力のアルファ0）と暗い下地（通常の合成）を同じ絵で描く。
// 素材：白黒の「データ」の絵。R＝形の濃さ、G＝消える順番（大きいほど後まで残る）。assets/fx/（外部AIの筆跡を tools/fx_tex_build.py で変換）。読み込むまでは手続きの仮（procStroke）。
// 2026-10-31 調査の答え合わせ：形の絵は繰り返さない（CLAMP、1回きりの斬撃）。流すのはノイズ（すじ）だけ。侵食に向き（尾から先へ欠ける）。
// isHeld（ヒットストップ）と FXPAL（色）は呼ぶ側から渡す（版の違う fx_slash.js を二重に読むと、止めの状態が共有されないため）

const TEXV = 1; // 素材を作り直したら上げる
const VS = `attribute vec2 aPos; attribute vec2 aUv; uniform vec2 uRes; varying vec2 vUv;
void main(){ vUv = aUv; vec2 c = aPos / uRes * 2.0 - 1.0; gl_Position = vec4(c.x, -c.y, 0.0, 1.0); }`;
const FS = `precision mediump float; varying vec2 vUv;
uniform sampler2D uShape, uNoise, uRamp, uFiber; uniform float uHead, uTail, uErode, uPan, uAlpha, uDark, uRep;
void main(){
  vec4 s = texture2D(uShape, vec2(.18 + .82 * pow(vUv.x, .7), vUv.y)); // 形（右端＝刃の頭、左端＝尾）。弧も根本が細いので、絵の細すぎる尾は使わない
  float fb = texture2D(uFiber, vec2(vUv.x * uRep - uPan * 1.4, vUv.y * .5)).r; // 帯の上を流れるすじ
  float n = texture2D(uNoise, vec2(vUv.x * 1.6 - uPan * 1.7, vUv.y * .7 + uPan * .4)).r;
  float sweep = smoothstep(uTail, uTail + .18, vUv.x) * (1.0 - smoothstep(uHead - .03, uHead, vUv.x)); // 刃が走る範囲（根本は遅れて追う）
  float e = (s.g * .62 + n * .38) * (.72 + .28 * vUv.x);             // 消える順番（形の芯ほど後まで残る＋ノイズで揺らす）×向き（尾から先へ）
  float keep = smoothstep(uErode, uErode + .1, e);                  // 侵食：しきい値より薄い所から欠ける
  float band = (smoothstep(uErode - .02, uErode + .03, e) - smoothstep(uErode + .03, uErode + .12, e)) * step(.01, uErode); // 欠ける縁だけが燃える
  float a = s.r * sweep * keep;
  if (uDark > 1.5) { float pr = 1.0 - abs(vUv.y - .4) / .6; float gw = max(pr, 0.0) * sweep * smoothstep(uErode, uErode + .3, .5 + n * .5) * .32 * uAlpha; gl_FragColor = vec4(texture2D(uRamp, vec2(.62, .5)).rgb * gw, 0.0); return; } // 外側の柔らかい光
  if (uDark > .5) { float d = s.r * sweep * keep * .55 * uAlpha; gl_FragColor = vec4(vec3(.06, .02, .05) * d, d); return; } // 暗い下地（通常の合成）
  float inten = clamp(a * (.45 + .55 * fb + .25 * n) + band * s.r * sweep * 1.2, 0.0, 1.0);
  gl_FragColor = vec4(texture2D(uRamp, vec2(inten, .5)).rgb * inten * uAlpha, 0.0);   // 加算（アルファ0）
}`;

// ---------- 仮の素材（手続き） ----------
function tileNoise(N = 256, oct = 4, seed = 1) { // 継ぎ目のない値ノイズ
  const R = (x, y, o) => { const h = Math.sin((x * 127.1 + y * 311.7 + o * 74.7 + seed) ) * 43758.5453; return h - Math.floor(h); };
  const out = new Float32Array(N * N);
  for (let o = 0; o < oct; o++) { const P = 4 << o, amp = 1 / (1 << o);
    for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) { const fx = x / N * P, fy = y / N * P, ix = Math.floor(fx), iy = Math.floor(fy), tx = fx - ix, ty = fy - iy, sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
      const g = (a, b) => R(((a % P) + P) % P, ((b % P) + P) % P, o), v = g(ix, iy) * (1 - sx) * (1 - sy) + g(ix + 1, iy) * sx * (1 - sy) + g(ix, iy + 1) * (1 - sx) * sy + g(ix + 1, iy + 1) * sx * sy; out[y * N + x] += v * amp; } }
  let mx = 0; for (const v of out) mx = Math.max(mx, v); return { N, d: out.map(v => v / mx) };
}
export function procStroke(W = 512, H = 128) { // 筆のかすれの帯：横に流れる繊維（毛のすじ）＋ぎざぎざの縁。R＝濃さ、G＝消える順番（縁からの距離＋ノイズ）
  const nz = tileNoise(256, 4, 7), fib = Array.from({ length: H }, (_, y) => .45 + .55 * Math.pow(Math.random(), .6));
  const c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d'), im = g.createImageData(W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const n = nz.d[(y * 2 % 256) * 256 + (x % 256)], v = y / (H - 1);
    const edge = .5 + (n - .5) * .35, prof = Math.max(0, 1 - Math.abs(v - .42) / (edge * .9)); // 帯の断面（外側＝上が厚い）
    const streak = fib[y] * (.65 + .35 * nz.d[(y % 256) * 256 + ((x * 3) % 256)]);         // 毛のすじ
    const r = Math.min(1, Math.pow(prof, .7) * streak * 1.25), gg = Math.min(1, prof * .8 + n * .3);
    const i = (y * W + x) * 4; im.data[i] = r * 255; im.data[i + 1] = gg * 255; im.data[i + 2] = 0; im.data[i + 3] = 255; }
  g.putImageData(im, 0, 0); return c;
}
function noiseCanvas() { const nz = tileNoise(256, 5, 3), c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d'), im = g.createImageData(256, 256);
  nz.d.forEach((v, i) => { im.data[i * 4] = im.data[i * 4 + 1] = im.data[i * 4 + 2] = v * 255; im.data[i * 4 + 3] = 255; }); g.putImageData(im, 0, 0); return c; }
export function rampCanvas(stops) { // 色の帯：[[位置, [r,g,b]], …]（暗→本体→光→芯）
  const c = document.createElement('canvas'); c.width = 256; c.height = 1; const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 256, 0);
  for (const [p, col] of stops) gr.addColorStop(p, `rgb(${col[0]},${col[1]},${col[2]})`); g.fillStyle = gr; g.fillRect(0, 0, 256, 1); return c; }
export const RAMPS = {
  rana: [[0, [40, 0, 6]], [.35, [170, 15, 30]], [.65, [255, 90, 50]], [.85, [255, 200, 110]], [1, [255, 245, 220]]],
  azure: [[0, [0, 10, 40]], [.35, [30, 90, 230]], [.65, [90, 170, 255]], [.85, [255, 214, 140]], [1, [255, 250, 235]]],
  red: [[0, [40, 0, 0]], [.35, [190, 30, 20]], [.65, [255, 110, 60]], [.85, [255, 200, 130]], [1, [255, 246, 228]]]
};

// ---------- 弧のリボン（斬撃） ----------
const bz = (p, t) => { const u = 1 - t; return [u * u * u * p[0][0] + 3 * u * u * t * p[1][0] + 3 * u * t * t * p[2][0] + t * t * t * p[3][0], u * u * u * p[0][1] + 3 * u * u * t * p[1][1] + 3 * u * t * t * p[2][1] + t * t * t * p[3][1]]; };
function arcMesh(x, y, size, dir, ang, bend, width) { // u＝弧に沿って 0→1、v＝外側0→内側1。根本は細く、先端の手前で太く、先端で尖る
  const ca = Math.cos(ang), sa = Math.sin(ang), h = size / 2, nx = -sa, ny = ca, P = (s, b) => [x + dir * (ca * s + nx * b), y + sa * s + ny * b];
  const p = [P(-h, 0), P(-h * .35, -bend), P(h * .35, -bend), P(h, 0)], N = 48, pos = [], uv = [];
  for (let i = 0; i <= N; i++) { const u = i / N, a = bz(p, Math.max(0, u - .01)), b = bz(p, Math.min(1, u + .01)), c = bz(p, u), dx = b[0] - a[0], dy = b[1] - a[1], m = Math.hypot(dx, dy) || 1;
    const w = width * Math.pow(Math.sin(Math.PI * Math.min(1, u * 1.12)), .7) * (.3 + .7 * u), ox = -dy / m, oy = dx / m;
    pos.push(c[0] + ox * w, c[1] + oy * w, c[0] - ox * w * .45, c[1] - oy * w * .45); uv.push(u, 0, u, 1); }
  const wide = []; for (let i = 0; i < pos.length; i += 4) { const mx = (pos[i] + pos[i + 2]) / 2, my = (pos[i + 1] + pos[i + 3]) / 2; wide.push(mx + (pos[i] - mx) * 2.4, my + (pos[i + 1] - my) * 2.4, mx + (pos[i + 2] - mx) * 2.4, my + (pos[i + 3] - my) * 2.4); }
  return { pos: new Float32Array(pos), wide: new Float32Array(wide), uv: new Float32Array(uv), n: (N + 1) * 2 };
}

export function createGL(host, { isHeld = () => false, FXPAL = {} } = {}) {
  const dpr = Math.min(2, window.devicePixelRatio || 1), cv = document.createElement('canvas');
  cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:8';
  host.appendChild(cv);
  const gl = cv.getContext('webgl', { premultipliedAlpha: true, alpha: true, antialias: true }); if (!gl) { cv.remove(); return null; }
  let lost = false; cv.addEventListener('webglcontextlost', e => { e.preventDefault(); lost = true; }); // スマホで描画がリセットされたら、呼ぶ側は Canvas の描画に戻す（ok() が false）
  const sh = (t, s) => { const o = gl.createShader(t); gl.shaderSource(o, s); gl.compileShader(o); if (!gl.getShaderParameter(o, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(o)); return o; };
  const pr = gl.createProgram(); gl.attachShader(pr, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(pr, sh(gl.FRAGMENT_SHADER, FS)); gl.linkProgram(pr); gl.useProgram(pr);
  const U = n => gl.getUniformLocation(pr, n), aPos = gl.getAttribLocation(pr, 'aPos'), aUv = gl.getAttribLocation(pr, 'aUv'), bP = gl.createBuffer(), bU = gl.createBuffer();
  const tex = (src, unit, repeat) => { const t = gl.createTexture(); gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(gl.TEXTURE_2D, t); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
    const w = repeat ? gl.REPEAT : gl.CLAMP_TO_EDGE; gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, w); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR); return t; };
  const noiseT = tex(noiseCanvas(), 1, true); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  const fiberT = tex(noiseCanvas(), 3, true); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  const proc = tex(procStroke(), 0, false), shapes = { ink: proc, blade: proc, smash: proc };
  const load = (name, done) => { const im = new Image(); im.onload = () => { if (!lost) done(im); }; im.src = new URL(`./assets/fx/${name}.png?v=${TEXV}`, import.meta.url).href; };
  for (const k of ['ink', 'blade', 'smash']) load('band_' + k, im => { shapes[k] = tex(im, 0, false); });
  load('noise_cloud', im => { gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, noiseT); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, im); });
  load('noise_fiber', im => { gl.activeTexture(gl.TEXTURE3); gl.bindTexture(gl.TEXTURE_2D, fiberT); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, im); });
  const fromPal = k => { const P = FXPAL[k]; return P ? [[0, P.dark || [0, 0, 0]], [.35, P.main], [.65, P.glow], [.85, P.spark], [1, P.core]] : null; }; // 一騎打ちの色（FXPAL）から色の帯を作る
  const ramps = {}; const rampT = k => ramps[k] || (ramps[k] = tex(rampCanvas(RAMPS[k] || fromPal(k) || RAMPS.azure), 2, false));
  gl.uniform1i(U('uShape'), 0); gl.uniform1i(U('uNoise'), 1); gl.uniform1i(U('uRamp'), 2); gl.uniform1i(U('uFiber'), 3);
  gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
  const items = []; let raf = 0, prev = 0;
  const resize = () => { const W = host.clientWidth, H = host.clientHeight; if (cv.width !== Math.round(W * dpr) || cv.height !== Math.round(H * dpr)) { cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr); } gl.viewport(0, 0, cv.width, cv.height); gl.uniform2f(U('uRes'), W, H); };
  const draw = (m, o, dark) => {
    gl.bindBuffer(gl.ARRAY_BUFFER, bP); gl.bufferData(gl.ARRAY_BUFFER, dark === 2 ? m.wide : m.pos, gl.DYNAMIC_DRAW); gl.enableVertexAttribArray(aPos); gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ARRAY_BUFFER, bU); gl.bufferData(gl.ARRAY_BUFFER, m.uv, gl.DYNAMIC_DRAW); gl.enableVertexAttribArray(aUv); gl.vertexAttribPointer(aUv, 2, gl.FLOAT, false, 0, 0);
    gl.uniform1f(U('uHead'), o.head); gl.uniform1f(U('uTail'), o.tail); gl.uniform1f(U('uErode'), o.erode); gl.uniform1f(U('uPan'), o.pan); gl.uniform1f(U('uAlpha'), o.alpha); gl.uniform1f(U('uDark'), dark === 2 ? 2 : dark ? 1 : 0); gl.uniform1f(U('uRep'), o.rep || 1.2);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, m.n); };
  const frame = now => { raf = 0; if (!prev) prev = now; const held = isHeld(now), dt = held ? 0 : Math.min(50, now - prev); prev = now;
    resize(); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
    for (let i = items.length - 1; i >= 0; i--) { const it = items[i]; it.t += dt * it.sp; if (it.t > it.end) { items.splice(i, 1); continue; } }
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, noiseT); gl.activeTexture(gl.TEXTURE3); gl.bindTexture(gl.TEXTURE_2D, fiberT);
    for (const it of items) { gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, shapes[it.tex] || shapes.ink); gl.activeTexture(gl.TEXTURE2); gl.bindTexture(gl.TEXTURE_2D, rampT(it.ramp)); for (const m of it.meshes) { const st = it.state(it.t - (m.delay || 0)); if (!st) continue; draw(m, st, true); draw(m, st, 2); draw(m, st, false); } } // 下地→柔らかい光→本体（加算）
    if (items.length) raf = requestAnimationFrame(frame); };
  const kick = () => { if (!raf) { prev = 0; raf = requestAnimationFrame(frame); } };
  const E = t => 1 - Math.pow(1 - Math.max(0, Math.min(1, t)), 3);
  return {
    // 斬撃：刃が走る（130ms）→ 根本が追う → 侵食で崩れ、欠ける縁が燃えて消える（約500ms）。big＝2本目が交差
    ok: () => !lost,
    slash(o) { const size = o.size, dir = o.dir || 1, meshes = [arcMesh(o.x, o.y, size * (o.len || 1.4), dir, o.ang ?? .62, size * (o.bend ?? .3), size * .2 * (o.thick || 1))];
      if (o.big) meshes.push(Object.assign(arcMesh(o.x, o.y - size * .04, size * 1.5, dir, -.5, size * .26, size * .17), { delay: 110 }));
      items.push({ t: 0, sp: o.speed || 1, end: 740, ramp: o.ramp || 'azure', tex: o.tex || 'ink', meshes, state: t => t < 0 ? null : ({ head: E(t / 130) * 1.03, tail: E((t - 110) / 520) * .55, erode: Math.max(0, Math.min(1, (t - 130) / 430)) * 1.05, pan: t * .0022, alpha: 1, rep: 1.6 }) }); kick(); },
    destroy() { cancelAnimationFrame(raf); cv.remove(); }, cv };
}
