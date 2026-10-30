// 領地の地形テスト：地形は three.js（正射影・傾き固定）、小物は切り抜き板、区画はコードのデータ。
// 座標の約束：基準画像（①）の画素座標 (sx, sy) を使う。地面 (x, z) は x=sx、z=(sy-SY0)/sinE。
import * as THREE from './vendor/three.module.min.js';
import * as GM from './game.js?v=1793650000';
import { createUI } from './ui.js?v=1793650000';
import { createMorning } from './morning.js?v=1793290034';
import { createStory } from './story.js?v=1793650000';
import { slashFX, impactFX, clashFX, chargeFX, rallyFX, starFX } from './fx_slash.js?v=1793640000';

const layout = await (await fetch('data/layout.json')).json();
const REF_W = layout.world.w, REF_H = layout.world.h, AREA0_W = 941; // 世界の大きさ（基準画像の画素）
const E = 58 * Math.PI / 180, SIN = Math.sin(E), COS = Math.cos(E);
const SY0 = 330;                       // 高さ0の地面で、z=0 に当たる基準画像のy
const syOf = z => SY0 + z * SIN;
const zOf = sy => (sy - SY0) / SIN;
const params = new URLSearchParams(location.search);
const status = { ok: false, reason: '', props: 0, ground: 'proc', sprites: 'proc' };
window.__t = { status };

// ---------- 乱数・ノイズ ----------
function rng(seed) { let s = seed >>> 0; return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const hash2 = (x, y) => { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); };
function vnoise(x, y) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi; const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf); return (hash2(xi, yi) * (1 - u) + hash2(xi + 1, yi) * u) * (1 - v) + (hash2(xi, yi + 1) * (1 - u) + hash2(xi + 1, yi + 1) * u) * v; }
const fbm = (x, y) => vnoise(x, y) * .55 + vnoise(x * 2.1, y * 2.1) * .3 + vnoise(x * 4.3, y * 4.3) * .15;
const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

// ---------- 配置データの読み込み ----------
const bootTick = () => { if (window.__bootTick) window.__bootTick(); }; // 読み込み中の画面のバーを進める
function loadImage(src) { return new Promise(res => { const im = new Image(); im.onload = () => { bootTick(); res(im); }; im.onerror = () => { bootTick(); res(null); }; im.src = src; }); }
const splatImg = await loadImage('data/splat.png');
const SW = Math.ceil(REF_W / 2), SH = Math.ceil(REF_H / 2);
const splatCv = document.createElement('canvas'); splatCv.width = SW; splatCv.height = SH;
const sctx = splatCv.getContext('2d', { willReadFrequently: true });
sctx.drawImage(splatImg, 0, 0);
// 湖は、コードの多角形（layout.lakes）で水として足す
{
  sctx.globalCompositeOperation = 'lighter'; sctx.fillStyle = 'rgb(0,0,255)';
  layout.lakes.forEach(lk => { sctx.beginPath(); lk.forEach(([x, y], i) => { i ? sctx.lineTo(x / 2, y / 2) : sctx.moveTo(x / 2, y / 2); }); sctx.closePath(); sctx.fill(); });
  sctx.globalCompositeOperation = 'source-over';
}
let baseSplat;
{ // 道は、コードのデータの線（layout.roads）で描く。絵から取った道・区画は使わない（川だけ絵のまま）。
  const id = sctx.getImageData(0, 0, SW, SH); for (let i = 0; i < SW * SH; i++) { id.data[i * 4] = 0; id.data[i * 4 + 1] = 0; } sctx.putImageData(id, 0, 0);
  sctx.globalCompositeOperation = 'lighter'; sctx.fillStyle = 'rgb(255,0,0)';
  layout.roads.forEach((rd, ri) => {
    let d = 0;
    for (let k = 0; k < rd.pts.length - 1; k++) {
      const [x0, y0] = rd.pts[k], [x1, y1] = rd.pts[k + 1], L = Math.hypot(x1 - x0, y1 - y0), nx = -(y1 - y0) / L, ny = (x1 - x0) / L;
      for (let t = 0; t <= L; t += 5, d += 5) { // 幅と中心を少し揺らす
        const wob = Math.sin(d * .045 + ri * 2) * .6 + Math.sin(d * .11 + ri) * .4, off = 2.5 * Math.sin(d * .07 + ri * 3);
        const r = rd.w * (1 + .14 * wob) / 2, px = (x0 + (x1 - x0) * t / L + nx * off) / 2, py = (y0 + (y1 - y0) * t / L + ny * off) / 2;
        sctx.beginPath(); sctx.arc(px, py, r / 2, 0, Math.PI * 2); sctx.fill();
      }
    }
  });
  layout.plazas.forEach(pz => { sctx.beginPath(); pz.poly.forEach(([x, y], i) => { i ? sctx.lineTo(x / 2, y / 2) : sctx.moveTo(x / 2, y / 2); }); sctx.closePath(); sctx.fill(); });
  sctx.globalCompositeOperation = 'source-over'; baseSplat = sctx.getImageData(0, 0, SW, SH);
}
const maskCv = document.createElement('canvas'); maskCv.width = SW; maskCv.height = SH; const mctx = maskCv.getContext('2d', { willReadFrequently: true });
function paintYards(polys) { // 各区画の地面の形（空き地=絵から取った4角、建物あり=建物の足元の平行四辺形）。clears=元の区画の砂を消す範囲
  const base = new ImageData(new Uint8ClampedArray(baseSplat.data), SW, SH);
  sctx.putImageData(base, 0, 0);
  sctx.globalCompositeOperation = 'lighter'; sctx.fillStyle = 'rgb(0,255,0)';
  polys.forEach(poly => { sctx.beginPath(); poly.forEach(([x, y], i) => { const px = x / 2, py = y / 2; i ? sctx.lineTo(px, py) : sctx.moveTo(px, py); }); sctx.closePath(); sctx.fill(); });
  sctx.globalCompositeOperation = 'source-over';
}
paintYards(layout.plots.map(p => p.poly));
const splatData = sctx.getImageData(0, 0, SW, SH).data; // 道・区画・川の初期状態（小物配置とゾーン用）
function boxBlur(a, w, h, r, passes) {
  let src = a, dst = new Float32Array(a.length);
  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) { let acc = 0; const o = y * w; for (let x = -r; x <= r; x++) acc += src[o + Math.min(w - 1, Math.max(0, x))]; for (let x = 0; x < w; x++) { dst[o + x] = acc / (2 * r + 1); acc += src[o + Math.min(w - 1, x + r + 1)] - src[o + Math.max(0, x - r)]; } }
    const t = src; src = dst; dst = (t === a) ? new Float32Array(a.length) : t;
    for (let x = 0; x < w; x++) { let acc = 0; for (let y = -r; y <= r; y++) acc += src[Math.min(h - 1, Math.max(0, y)) * w + x]; for (let y = 0; y < h; y++) { dst[y * w + x] = acc / (2 * r + 1); acc += src[Math.min(h - 1, y + r + 1) * w + x] - src[Math.max(0, y - r) * w + x]; } }
    const t2 = src; src = dst; dst = t2;
  }
  return src;
}
const mask0 = new Float32Array(SW * SH);
for (let i = 0; i < SW * SH; i++) mask0[i] = Math.max(splatData[i * 4], splatData[i * 4 + 1], splatData[i * 4 + 2]) / 255 > .3 ? 1 : 0;
const zoneArr = boxBlur(mask0, SW, SH, 14, 3);
const zoneBytes = new Uint8Array(SW * SH * 4);
for (let i = 0; i < SW * SH; i++) { const v = Math.min(255, zoneArr[i] * 255 * 1.0) | 0; zoneBytes[i * 4] = v; zoneBytes[i * 4 + 1] = v; zoneBytes[i * 4 + 2] = v; zoneBytes[i * 4 + 3] = 255; }
function zoneAt(sx, sy) { const x = Math.max(0, Math.min(SW - 1, Math.round(sx / REF_W * SW))), y = Math.max(0, Math.min(SH - 1, Math.round(sy / REF_H * SH))); return zoneArr[y * SW + x]; }
function splatAt(sx, sy) { // R=道 G=区画 B=川 を0..1で返す
  const x = Math.max(0, Math.min(SW - 1, Math.round(sx / REF_W * SW))), y = Math.max(0, Math.min(SH - 1, Math.round(sy / REF_H * SH)));
  const i = (y * SW + x) * 4; return [splatData[i] / 255, splatData[i + 1] / 255, splatData[i + 2] / 255];
}
function nearLayout(sx, sy, r) { // 道・区画・川の近く（半径r）か
  for (let a = 0; a < 8; a++) { const t = a * Math.PI / 4; const s = splatAt(sx + Math.cos(t) * r, sy + Math.sin(t) * r * .8); if (s[0] > .15 || s[1] > .15 || s[2] > .15) return true; }
  const c = splatAt(sx, sy); return c[0] > .15 || c[1] > .15 || c[2] > .15;
}

// ---------- 高さ ----------
function hgt(x, z) { // 街の中は、広場の高さへ平らにならす
  const h0 = hgt0(x, z), sy = syOf(z); let w = 0, f = 0;
  for (const pz of layout.plazas) {
    const d = Math.hypot(x - pz.center[0], (sy - pz.center[1]) * 1.6), ww = smooth(500, 380, d); if (ww <= w) continue;
    if (pz.h === undefined) { pz.h = 0; pz.h = hgt0(pz.center[0], zOf(pz.center[1])); }
    w = ww; f = pz.h;
  }
  if (w <= 0) return h0; w *= Math.min(1, zoneAt(x, sy) * 1.6);
  return h0 + (f - h0) * w;
}
function hgt0(x, z) {
  const sy = syOf(z);
  let h = 0;
  const ex = (x - 300) / 340, ey = (sy - 540) / 200; // 城の台地
  h += 80 * (1 - smooth(.55, 1.15, Math.hypot(ex, ey)));
  h += 190 * smooth(190, 0, x) * smooth(1000, 520, sy); // 左の山
  h += 26 * smooth(560, 360, sy);                       // 奥は少し高く
  h += (fbm(x / 150, z / 150) - .5) * 26 * (1 - Math.min(1, zoneAt(x, sy) * 1.6));
  const s = splatAt(x, sy); h -= 16 * s[2];             // 川は低く
  return h;
}

// ---------- 地面 ----------
const canvas = document.getElementById('gl');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
renderer.setClearColor(0x000000, 0);
const dpr = Math.min(window.devicePixelRatio || 1, 2);
renderer.setPixelRatio(dpr);
const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 1, 9000);

function procTex(kind, size = 256) {
  const c = document.createElement('canvas'); c.width = c.height = size; const g = c.getContext('2d'); const R = rng(kind.length * 977 + kind.charCodeAt(0));
  const base = { grass: [92, 120, 48], forest: [48, 70, 36], road: [182, 150, 98], plot: [112, 76, 48], rock: [120, 120, 114], water: [60, 120, 190] }[kind];
  g.fillStyle = `rgb(${base})`; g.fillRect(0, 0, size, size);
  const n = size * size / 6;
  for (let i = 0; i < n; i++) {
    const x = R() * size, y = R() * size, d = (R() - .5) * 46, l = 1 + R() * 2.4;
    g.fillStyle = `rgba(${base[0] + d | 0},${base[1] + d | 0},${base[2] + d * .7 | 0},.55)`;
    if (kind === 'water') g.fillRect(x, y, 1.2, l * 7); else g.fillRect(x, y, l, l * (kind === 'grass' ? 2.6 : 1));
  }
  if (kind === 'grass') for (let i = 0; i < 40; i++) { g.fillStyle = R() < .5 ? '#e8e0b0' : '#d8c040'; g.fillRect(R() * size, R() * size, 2, 2); }
  if (kind === 'water') for (let i = 0; i < 70; i++) { g.fillStyle = 'rgba(240,248,255,.55)'; g.fillRect(R() * size, R() * size, 2, 6 + R() * 14); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t;
}
async function groundTex(kind, idx) { // assets/ground/ 以降に切り出した絵があれば使う
  const im = await loadImage(`assets/ground/g${idx}_${kind}.png`);
  if (!im) return { t: procTex(kind), real: false };
  const t = new THREE.Texture(im); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; t.generateMipmaps = true; return { t, real: true };
}
const kinds = ['grass', 'forest', 'road', 'plot', 'rock', 'water'];
const gt = await Promise.all(kinds.map((k, i) => groundTex(k, i + 1)));
status.ground = gt.every(x => x.real) ? 'sheet' : 'proc';

const splatTex = new THREE.CanvasTexture(splatCv); splatTex.colorSpace = THREE.NoColorSpace; splatTex.flipY = false; splatTex.minFilter = THREE.LinearFilter; splatTex.wrapS = splatTex.wrapT = THREE.ClampToEdgeWrapping;
const zoneTex = new THREE.DataTexture(zoneBytes, SW, SH, THREE.RGBAFormat); zoneTex.needsUpdate = true; zoneTex.minFilter = THREE.LinearFilter; zoneTex.magFilter = THREE.LinearFilter; zoneTex.flipY = false;
const TILE = 230;
const groundMat = new THREE.ShaderMaterial({
  transparent: true,
  uniforms: {
    tG: { value: gt[0].t }, tF: { value: gt[1].t }, tR: { value: gt[2].t }, tP: { value: gt[3].t }, tK: { value: gt[4].t }, tW: { value: gt[5].t },
    splat: { value: splatTex }, zone: { value: zoneTex }, time: { value: 0 }, tile: { value: TILE }
  },
  vertexShader: `
    varying vec2 vW; varying vec2 vS; varying float vSh; varying float vSl; varying float vSy;
    attribute float shade; attribute float slope;
    void main(){ vW = position.xz; vSy = ${SY0.toFixed(1)} + position.z*${SIN.toFixed(5)};
      vS = vec2(position.x/${REF_W.toFixed(1)}, vSy/${REF_H.toFixed(1)}); vSh = shade; vSl = slope;
      gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
  fragmentShader: `
    precision highp float;
    uniform sampler2D tG,tF,tR,tP,tK,tW,splat,zone; uniform float time, tile;
    varying vec2 vW; varying vec2 vS; varying float vSh; varying float vSl; varying float vSy;
    float h2(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
    float vn(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
      return mix(mix(h2(i),h2(i+vec2(1,0)),f.x), mix(h2(i+vec2(0,1)),h2(i+vec2(1,1)),f.x), f.y); }
    vec3 at(sampler2D t, vec2 uv){ float n=smoothstep(.3,.7,vn(uv*.35)); vec3 a=texture2D(t,uv).rgb; vec3 b=texture2D(t,uv*.43+vec2(.37,.11)).rgb; return mix(a,b,n); }
    void main(){
      vec2 uv = vW / tile;
      vec3 sp = texture2D(splat, vS).rgb;
      float wR = smoothstep(.16,.42,sp.r), wP = smoothstep(.18,.5,sp.g), wW = smoothstep(.18,.55,sp.b);
      float oth = max(max(wR,wP),wW);
      float wK = smoothstep(.22,.55,vSl + (vn(vW/60.)-.5)*.25) * (1.-oth);
      float zn = texture2D(zone, vS).r; float fo = smoothstep(.38,.62, vn(vW/260.)*.6+vn(vW/90.)*.4) * (1.-smoothstep(.06,.4,zn));
      float wF = fo*(1.-oth)*(1.-wK)*.9;
      float wG = max(0., 1.-oth-wK-wF);
      vec2 uvw = uv*vec2(1.,.55) + vec2(0., -time*.045);
      vec3 cR = at(tR,uv), cP = at(tP,uv);
      cR = mix(vec3(dot(cR,vec3(.3,.59,.11))), cR, .62) * vec3(1.12,1.06,.98) * 1.06;
      cP = mix(vec3(dot(cP,vec3(.3,.59,.11))), cP, .7) * 0.95;
      vec3 cG = at(tG,uv) * vec3(1.16,1.14,.92); vec3 col = cG*wG + at(tF,uv)*wF + cR*wR + cP*wP + at(tK,uv*1.3)*wK + at(tW,uvw)*wW;
      float sum = wG+wF+wR+wP+wK+wW; col /= max(sum,.001);
      col *= mix(.98,1.38, clamp(vSh,0.,1.)) * 1.08;
      float a = smoothstep(300.,380., vSy);
      gl_FragColor = vec4(col, a);
    }`
});
const GX0 = -70, GX1 = REF_W + 70, GZ0 = zOf(300), GZ1 = zOf(REF_H + 120);
const SEG_X = Math.round((GX1 - GX0) / 5.7), SEG_Z = 300;
const geo = new THREE.PlaneGeometry(GX1 - GX0, GZ1 - GZ0, SEG_X, SEG_Z);
geo.rotateX(-Math.PI / 2);
{
  const pos = geo.attributes.position; const n = pos.count; const shade = new Float32Array(n), slope = new Float32Array(n);
  const L = new THREE.Vector3(-.55, .75, -.35).normalize();
  for (let i = 0; i < n; i++) {
    const x = pos.getX(i) + (GX0 + GX1) / 2, z = pos.getZ(i) + (GZ0 + GZ1) / 2;
    const h = hgt(x, z); pos.setXYZ(i, x, h, z);
    const e = 6, hx = hgt(x + e, z) - hgt(x - e, z), hz = hgt(x, z + e) - hgt(x, z - e);
    const nn = new THREE.Vector3(-hx / (2 * e), 1, -hz / (2 * e)).normalize();
    shade[i] = .55 + .6 * Math.max(0, nn.dot(L)); slope[i] = Math.min(1, Math.hypot(hx, hz) / (2 * e) * 1.1);
  }
  geo.setAttribute('shade', new THREE.BufferAttribute(shade, 1)); geo.setAttribute('slope', new THREE.BufferAttribute(slope, 1));
  pos.needsUpdate = true;
}
const ground = new THREE.Mesh(geo, groundMat); ground.frustumCulled = false; scene.add(ground);

// ---------- 小物（切り抜きの板） ----------
const SPR = [
  { id: 'pineL', w: 50, h: 96 }, { id: 'pineM', w: 40, h: 74 }, { id: 'pineS', w: 28, h: 48 }, { id: 'pineT', w: 40, h: 74 },
  { id: 'bush', w: 36, h: 26 }, { id: 'rockM', w: 48, h: 36 }, { id: 'rockS', w: 28, h: 20 }, { id: 'boulder', w: 76, h: 58 },
  { id: 'fence', w: 66, h: 44 }, { id: 'marker', w: 18, h: 28 }
];
function procSprite(id, w, h) {
  const S = 2, c = document.createElement('canvas'); c.width = w * S; c.height = h * S; const g = c.getContext('2d'); g.scale(S, S); const R = rng(id.length * 31 + id.charCodeAt(3));
  const blob = (cx, cy, rx, ry, col) => { g.fillStyle = col; g.beginPath(); g.ellipse(cx, cy, rx, ry, 0, 0, 7); g.fill(); };
  if (id.startsWith('pine')) {
    const tilt = id === 'pineT' ? 7 : 0; g.fillStyle = '#3a2a1c'; g.fillRect(w / 2 - 3, h - 14, 6, 14);
    const tiers = 5; for (let i = 0; i < tiers; i++) { const y = h - 12 - i * (h - 22) / tiers, tw = (w / 2) * (1 - i / (tiers + .6)) + 3; g.fillStyle = ['#1c3a22', '#234a2a', '#2c5532', '#1c3a22', '#2c5532'][i % 5]; g.beginPath(); g.moveTo(w / 2 + tilt * i / tiers, y - (h - 22) / tiers * 1.5); g.lineTo(w / 2 - tw, y); g.lineTo(w / 2 + tw, y); g.closePath(); g.fill(); }
    for (let i = 0; i < 24; i++) { g.fillStyle = 'rgba(200,190,60,.6)'; g.fillRect(w / 2 + (R() - .5) * w * .6, R() * h * .8 + 8, 2, 2); }
  } else if (id === 'bush') { blob(w / 2, h * .6, w * .45, h * .38, '#33541f'); blob(w * .4, h * .5, w * .25, h * .25, '#4a6e26'); for (let i = 0; i < 14; i++) { g.fillStyle = '#e6c830'; g.fillRect(R() * w * .8 + 4, R() * h * .6 + 6, 3, 3); } }
  else if (id === 'fence') { g.strokeStyle = '#6a4a2a'; g.lineWidth = 4; g.beginPath(); g.moveTo(6, h - 8); g.lineTo(w - 6, 8); g.stroke(); for (let i = 0; i < 4; i++) { const x = 8 + i * (w - 16) / 3, y = h - 8 - i * (h - 16) / 3; g.fillStyle = '#7a5630'; g.fillRect(x - 3, y - 24, 6, 26); } }
  else if (id === 'marker') { g.fillStyle = '#8c8a80'; g.fillRect(5, 8, 16, h - 8); g.fillStyle = '#a8a69a'; g.fillRect(5, 8, 16, 6); }
  else { const k = id === 'boulder' ? 3 : 1; for (let i = 0; i < k; i++) { const ox = k > 1 ? (i - 1) * w * .26 : 0, oy = k > 1 ? (i == 1 ? -h * .2 : 0) : 0; g.fillStyle = '#7d7e76'; g.beginPath(); g.ellipse(w / 2 + ox, h * .62 + oy, w * (k > 1 ? .26 : .45), h * (k > 1 ? .34 : .4), 0, 0, 7); g.fill(); g.fillStyle = '#9a9b92'; g.beginPath(); g.ellipse(w / 2 + ox - 3, h * .5 + oy, w * (k > 1 ? .16 : .3), h * (k > 1 ? .2 : .24), 0, 0, 7); g.fill(); g.fillStyle = '#4e6a30'; g.fillRect(w / 2 + ox - w * .18, h * .36 + oy, w * .3, 4); } }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t;
}
function procCastle() { // 城は別素材。ここは位置確認用の仮の箱
  const w = 420, h = 250, c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d');
  g.fillStyle = '#8a8a82'; g.fillRect(10, 110, 400, 130); g.fillStyle = '#9c9c94'; g.fillRect(150, 30, 120, 200); g.fillStyle = '#6a6a64'; for (let x = 10; x < 410; x += 24) g.fillRect(x, 100, 14, 12);
  for (let x = 150; x < 270; x += 24) g.fillRect(x, 20, 14, 12); g.fillStyle = '#b8322a'; g.fillRect(190, 60, 40, 80); g.fillStyle = '#4a3a2a'; g.fillRect(170, 180, 40, 60);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
async function spriteTex(def, i) {
  const im = await loadImage(`assets/props/p${String(i + 1).padStart(2, '0')}_${def.id}.png`);
  if (im) { const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return { t, real: true, aspect: im.width / im.height }; }
  return { t: procSprite(def.id, def.w, def.h), real: false, aspect: def.w / def.h };
}
const stex = await Promise.all(SPR.map(spriteTex));
status.sprites = stex.every(s => s.real) ? 'sheet' : 'proc';
const planeGeo = new THREE.PlaneGeometry(1, 1); planeGeo.translate(0, .5, 0);
const tiltRot = new THREE.Euler(-E * .95, 0, 0);
const baseQ = new THREE.Quaternion().setFromEuler(tiltRot);
const buckets = SPR.map(() => []);
const R = rng(20261028);
const CAMP_CLEAR = [[70, 800], [110, 820], [30, 780], [70, 1200], [110, 1180], [30, 1220]]; // 敵の陣を置く場所は、木や岩を置かない
function place(type, x, sy, sc = 1, flip = false, tint = 1) { if (CAMP_CLEAR.some(([cx, cy]) => Math.abs(x - cx) < 70 && sy > cy - 45 && sy < cy + 120)) return; /* 手前の背の高い木も除く */ const z = zOf(sy); buckets[type].push({ x, z, y: hgt(x, z), sc, flip, tint }); }
function townDist(x, sy) { let d = 1e9; for (const pz of layout.plazas) d = Math.min(d, Math.hypot(x - pz.center[0], (sy - pz.center[1]) * 1.6)); return d; }
// 森・岩・茂み・川沿いの岩を散らす
{
  const N = Math.round(5200 * REF_W / AREA0_W);
  for (let i = 0; i < N; i++) {
    const x = -50 + R() * (REF_W + 100), sy = 380 + R() * (REF_H - 300);
    const zn = zoneAt(x, sy); if (zn > .62 || nearLayout(x, sy, 22)) continue;
    const z = zOf(sy), f = fbm(x / 230 + 5, z / 230), edge = Math.max(smooth(260, 0, x), smooth(REF_W - 260, REF_W, x)) * .5 + smooth(520, 400, sy) * .5;
    const ar = layout.areas.find(a => x >= a.x0 && x < (a.x1 || 1e9)), meadow = (ar ? ar.forest : 1) * smooth(400, 580, townDist(x, sy)); // 区域ごとの木の密度。街の中は切り開く
    const forestness = Math.min(1, Math.max(0, (f * 1.5 - .42 + edge * .55) * meadow)) * (1 - smooth(.08, .5, zn));
    const r = R();
    if (r < forestness * .55) { const t = R(); const type = t < .3 ? 0 : t < .62 ? 1 : t < .84 ? 2 : 3; place(type, x, sy, .75 + R() * .5, R() < .5, .86 + R() * .2); }
    else if (r < forestness * .55 + .035) place(4, x, sy, .8 + R() * .5, R() < .5, .9 + R() * .15);
    else if (r < forestness * .55 + .05 && forestness < .5) place(5 + (R() < .5 ? 1 : 0), x, sy, .8 + R() * .5, R() < .5);
  }
  // 左の岩壁・川沿いの岩
  for (let i = 0; i < 260; i++) { const x = R() * 200, sy = 420 + R() * 1200; if (nearLayout(x, sy, 12)) continue; place(R() < .35 ? 7 : R() < .6 ? 5 : 6, x, sy, .9 + R() * .7, R() < .5); }
  for (let i = 0; i < Math.round(1300 * REF_W / AREA0_W); i++) { const x = R() * REF_W, sy = 900 + R() * 800; const s = splatAt(x, sy); if (s[2] > .12 && s[2] < .6) place(R() < .5 ? 5 : 6, x + (R() - .5) * 20, sy + (R() - .5) * 12, .6 + R() * .6, R() < .5); }
  // 並木と植え込み：街の中の道の両脇に、等間隔で（区画・広場・道の上には置かない）
  const onLot = (x, sy) => layout.plots.some(p => pointInPoly(x, sy, p.poly)) || layout.plazas.some(p => pointInPoly(x, sy, p.poly));
  layout.roads.forEach(rd => { let d = 0;
    for (let k = 0; k < rd.pts.length - 1; k++) { const [x0, y0] = rd.pts[k], [x1, y1] = rd.pts[k + 1], L = Math.hypot(x1 - x0, y1 - y0), nx = -(y1 - y0) / L, ny = (x1 - x0) / L;
      for (let t = 30; t < L - 20; t += 78, d++) for (const sd of [-1, 1]) {
        const x = x0 + (x1 - x0) * t / L + nx * sd * (rd.w / 2 + 14), sy = y0 + (y1 - y0) * t / L + ny * sd * (rd.w / 2 + 14) * .8;
        if (townDist(x, sy) > 560 || onLot(x, sy) || splatAt(x, sy)[0] > .3) continue;
        if (d % 2) place(2, x, sy + 6, .7, sd < 0, .95); else place(4, x, sy + 4, .75, sd > 0, 1);
      } } });
}
const dummy = new THREE.Object3D();
const instMeshes = []; let total = 0;
buckets.forEach((arr, ti) => {
  if (!arr.length) return;
  const def = SPR[ti], st = stex[ti];
  const mat = new THREE.MeshBasicMaterial({ map: st.t, alphaTest: .45, side: THREE.DoubleSide });
  const m = new THREE.InstancedMesh(planeGeo, mat, arr.length); m.frustumCulled = false;
  const col = new THREE.Color();
  arr.forEach((o, i) => {
    const hh = def.h * o.sc, ww = hh * st.aspect;
    dummy.position.set(o.x, o.y, o.z); dummy.quaternion.copy(baseQ); dummy.scale.set(ww * (o.flip ? -1 : 1), hh, 1); dummy.updateMatrix(); m.setMatrixAt(i, dummy.matrix);
    col.setScalar(o.tint); m.setColorAt(i, col);
  });
  m.instanceMatrix.needsUpdate = true; if (m.instanceColor) m.instanceColor.needsUpdate = true;
  scene.add(m); instMeshes.push(m); total += arr.length;
});
status.props = total;
const bld = await (await fetch('data/bld.json')).json();
const bldTex = {};
async function loadBld(fn) { const im = await loadImage(fn); if (!im) return null; const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
function sprite3D(tex, meta, scale, baseX, baseSy) { // 足元の手前の角(ax,ay)を、地面の(baseX, baseSy)に合わせる
  const w = meta.w * scale, h = meta.h * scale, z = zOf(baseSy);
  const m = new THREE.Mesh(planeGeo, new THREE.MeshBasicMaterial({ map: tex, alphaTest: .35, side: THREE.DoubleSide }));
  m.position.set(baseX - (meta.ax - .5) * w, hgt(baseX, z), z); m.quaternion.copy(baseQ); m.scale.set(w, h, 1); m.frustumCulled = false; return m;
}
let castleHit = null;
{ // 領主の城（切り抜き絵）
  const meta = bld['assets/bld/castle.png']; const t = await loadBld('assets/bld/castle.png');
  if (t) { scene.add(sprite3D(t, meta, .37, 300, 705)); const w = meta.w * .37, h = meta.h * .37; castleHit = { left: 300 - meta.ax * w, top: 705 - meta.ay * h, w, h, im: t.image }; }
}

// ---------- 区画（コードのデータ）と選択表示 ----------
const plots = layout.plots.map(p => ({ id: p.id, poly: p.poly, home: p.poly, state: 'empty' }));
for (const p of layout.plots) GM.PLOT_AREA[p.id] = p.area; // 城壁の「区域ごとに1つ」
const selMat = new THREE.MeshBasicMaterial({ color: 0xffe08a, transparent: true, opacity: .95, depthTest: false, side: THREE.DoubleSide });
const selGlow = new THREE.MeshBasicMaterial({ color: 0xffc040, transparent: true, opacity: .3, depthTest: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending });
let selGroup = null, selected = null, selSign = null;
function pointInPoly(x, y, poly) { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; }
function select(p) {
  selSign = null; selCastle = false; selAlly = null;
  if (selGroup) { scene.remove(selGroup); selGroup = null; }
  selected = p; if (G && p && GM.allyAt(G, p.id)) newLine(GM.allyAt(G, p.id)); if (G) refreshUI(); if (!p) return;
  // 金色に光る枠（モックの選択表示）：外側に広げた形から内側をくり抜いた帯＋外のにじみ
  const ring = (k0, k1, mat) => { const cx = p.poly.reduce((a, q) => a + q[0], 0) / 4, cy = p.poly.reduce((a, q) => a + q[1], 0) / 4, g = (k) => p.poly.map(([x, y]) => new THREE.Vector2(cx + (x - cx) * k, zOf(cy + (y - cy) * k)));
    const sh = new THREE.Shape(g(k1)); sh.holes.push(new THREE.Path(g(k0).reverse())); const geo = new THREE.ShapeGeometry(sh); geo.rotateX(Math.PI / 2);
    const m = new THREE.Mesh(geo, mat); m.position.y = hgt(cx, zOf(cy)) + 5; m.renderOrder = 10; return m; };
  const fix = ring(.99, 1.07, selMat), line = ring(1.07, 1.24, selGlow);
  selGroup = new THREE.Group(); selGroup.add(fix, line); scene.add(selGroup);
}

// ---------- 施設（区画の状態：0=空き地 1=建築中 2=完成 3=発展後）----------
const FAC = GM.FAC, STAGE = GM.STAGE, ART = ['smithy', 'tavern', 'farm']; // 絵のある施設。畑はコードで描く
// 絵がまだ無い施設は、既存の絵を色づけして仮置き（本番の絵は assets/bld/<施設>_1〜3.png を置き、ART に足して ARTALIAS から外す）
const ARTALIAS = { war: ['tavern', [.5, .66, 1]], drill: ['smithy', [1, .82, .45]], wall: ['smithy', [.55, .56, .62]] };
const BS = .38; // 素材シートの画素 → 基準画像の画素
for (const f of ART) for (let k = 1; k <= 3; k++) bldTex[`${f}_${k}`] = await loadBld(`assets/bld/${f}_${k}.png`);
plots.forEach(pl => { pl.fac = null; pl.stage = 0; pl.mesh = null; pl.base = pl.poly.reduce((a, q) => q[1] > a[1] ? q : a, pl.poly[0]); pl.cx = pl.poly.reduce((a, q) => a + q[0], 0) / 4; });
const alphaCache = {};
function alphaMask(key) { // 絵の透明度（タップ判定用）
  if (alphaCache[key]) return alphaCache[key];
  const im = key === 'castle' ? castleHit.im : bldTex[key].image, c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
  const x = c.getContext('2d', { willReadFrequently: true }); x.drawImage(im, 0, 0);
  return alphaCache[key] = { w: im.width, h: im.height, d: x.getImageData(0, 0, im.width, im.height).data };
}
const stakeTex = stex[9], stakeDef = SPR[9];
plots.forEach(pl => { // 空き地の4隅の杭（建物が建つと隠す）
  const hh = stakeDef.h * .8, ww = hh * stakeTex.aspect; pl.stakes = new THREE.Group();
  pl.home.forEach(([x, sy]) => pl.stakes.add(sprite3D(stakeTex.t, { w: ww, h: hh, ax: .5, ay: 1 }, 1, x, sy + 4)));
  scene.add(pl.stakes);
});
function yardOf(pl, meta) { // 建物の足元の平行四辺形を、地面の座標へ（少し外へ広げる）
  const fp = meta.fp, ox = meta.ax * meta.w, oy = meta.ay * meta.h, bx = pl.cx, by = pl.base[1] - 4;
  const q = fp.map(([x, y]) => [bx + (x - ox) * BS, by + (y - oy) * BS]);
  const cx = q.reduce((a, p) => a + p[0], 0) / 4, cy = q.reduce((a, p) => a + p[1], 0) / 4;
  return q.map(([x, y]) => [cx + (x - cx) * 1.14, cy + (y - cy) * 1.14]);
}
let pavTex = null, plazaTex = null;
function pavingTex(opaque) { // 石畳（コード生成）。u,vは建物の足元の辺に沿う
  if (opaque ? plazaTex : pavTex) return opaque ? plazaTex : pavTex;
  const N = 512, c = document.createElement('canvas'); c.width = c.height = N; const x = c.getContext('2d');
  let seed = 7; const r = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  x.fillStyle = '#3a342b'; x.fillRect(0, 0, N, N);
  const m = opaque ? 0 : 20, rows = 11, rh = (N - 2 * m) / rows;
  for (let j = 0; j < rows; j++) {
    let px = m + (j % 2 ? -rh * .5 : 0);
    while (px < N - m) {
      const w = rh * (1.1 + r() * .9), x0 = Math.max(m, px), x1 = Math.min(N - m, px + w), y0 = m + j * rh;
      if (x1 - x0 > 6) { const g = 128 + r() * 50 | 0; x.fillStyle = `rgb(${g + 22},${g + 12},${g - 14})`; x.beginPath(); x.roundRect(x0 + 2, y0 + 2, x1 - x0 - 4, rh - 4, 6); x.fill();
        x.fillStyle = 'rgba(255,255,255,.18)'; x.fillRect(x0 + 4, y0 + 3, x1 - x0 - 8, 3); x.fillStyle = 'rgba(0,0,0,.18)'; x.fillRect(x0 + 4, y0 + rh - 7, x1 - x0 - 8, 3); }
      px += w;
    }
  }
  // 縁を不揃いに透明へ
  if (!opaque) { x.globalCompositeOperation = 'destination-in'; x.fillStyle = '#000'; x.beginPath(); x.roundRect(10, 10, N - 20, N - 20, 40); x.fill(); x.globalCompositeOperation = 'source-over'; }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; if (opaque) { t.wrapS = t.wrapT = THREE.RepeatWrapping; plazaTex = t; } else pavTex = t; return t;
}
function pavingMesh(q, opaque, tex) {
  if (opaque) return gridPaving(q, tex); // q = [T,R,B,L] の地面座標。B→R が u、B→L が v
  const [T, R, B, L] = q, P = [B, R, T, L], pos = [], z = p => zOf(p[1]);
  P.forEach(p => pos.push(p[0], hgt(p[0], z(p)) + .8, z(p)));
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  const k = opaque ? 2 : 1; g.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, k, 0, k, k, 0, k], 2)); g.setIndex([0, 2, 1, 0, 3, 2]);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: tex || pavingTex(opaque), transparent: !opaque, alphaTest: opaque ? 0 : .5, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, side: THREE.DoubleSide }));
  m.frustumCulled = false; return m;
}
const cropTex = {};
function cropTexture(stage) { // 畑（コード生成）：1=芽 2=青い畝 3=実った麦
  if (cropTex[stage]) return cropTex[stage];
  const N = 256, c = document.createElement('canvas'); c.width = c.height = N; const x = c.getContext('2d'); let seed = 11 + stage; const r = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  x.fillStyle = '#5b3b22'; x.fillRect(0, 0, N, N);
  for (let j = 0; j < 9; j++) { const y = 18 + j * 25; x.fillStyle = '#6e4a2c'; x.fillRect(10, y - 7, N - 20, 10);
    for (let i = 14; i < N - 14; i += stage === 1 ? 14 : 5) { const h = stage === 1 ? 4 : stage === 2 ? 10 + r() * 4 : 13 + r() * 4;
      x.fillStyle = stage === 3 ? `hsl(${42 + r() * 8},${70 + r() * 15}%,${52 + r() * 12}%)` : `hsl(${95 + r() * 20},${45 + r() * 15}%,${30 + r() * 14}%)`; x.fillRect(i + r() * 3, y - h, stage === 1 ? 4 : 3, h); } }
  x.globalCompositeOperation = 'destination-in'; x.beginPath(); x.roundRect(4, 4, N - 8, N - 8, 18); x.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return cropTex[stage] = t;
}
function gridPaving(q, tex) { // 広場の石畳：細かい格子にして、地面の起伏に沿わせる（角から土が出ないように）
  const [T, R, B, L] = q, N = 16, pos = [], uv = [], idx = [];
  for (let j = 0; j <= N; j++) for (let i = 0; i <= N; i++) { const u = i / N, v = j / N; // B→R が u、B→L が v
    const x = B[0] + (R[0] - B[0]) * u + (L[0] - B[0]) * v, sy = B[1] + (R[1] - B[1]) * u + (L[1] - B[1]) * v, z = zOf(sy);
    pos.push(x, hgt(x, z) + 1.2, z); uv.push(u * 2, v * 2); }
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const a = j * (N + 1) + i, b = a + 1, c = a + N + 1, d = c + 1; idx.push(a, d, b, a, c, d); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: tex || pavingTex(true), polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3, side: THREE.DoubleSide })); m.frustumCulled = false; return m;
}
function grow(q, k) { const cx = q.reduce((a, p) => a + p[0], 0) / 4, cy = q.reduce((a, p) => a + p[1], 0) / 4; return q.map(([x, y]) => [cx + (x - cx) * k, cy + (y - cy) * k]); }
const FARM_S = .325; // 畑の絵の画素 → 基準画像の画素（柵の外周が区画より少し大きい）
function groundRect(tex, left, top, w, h) { // 画面の矩形（基準画像の画素）を、地面の起伏に沿わせて貼る。奥行きを手前へ引き寄せる設定(polygonOffsetのfactor)は使わない：仲間や炎の足元に土が被さっていた
  const N = 6, pos = [], uv = [], idx = [];
  for (let j = 0; j <= N; j++) for (let i = 0; i <= N; i++) { const u = i / N, v = j / N, x = left + w * u, sy = top + h * (1 - v), z = zOf(sy); pos.push(x, hgt(x, z) + 1, z); uv.push(u, v); }
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const a = j * (N + 1) + i, b = a + 1, c = a + N + 1, d = c + 1; idx.push(a, b, d, a, d, c); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: tex, alphaTest: .4, polygonOffset: true, polygonOffsetFactor: 0, polygonOffsetUnits: -2, side: THREE.DoubleSide })); m.frustumCulled = false; return m;
}
const fireMeshes = new Set();
let fireTex = null;
// ---------- 放火の演出：着火（炎が立ち上がり、火の粉が散る）→燃え続ける（煙・火の粉・熾火の光）→修理で消える（蒸気） ----------
let smokeTex = null, steamTex = null, emberTex = null, haloTex = null; const bparts = [];
function burnTexInit() { if (smokeTex) return;
  const soft = (a, b, c) => g => { const r = g.createRadialGradient(32, 32, 2, 32, 32, 30); r.addColorStop(0, a); r.addColorStop(.6, b); r.addColorStop(1, c); g.fillStyle = r; g.fillRect(0, 0, 64, 64); };
  smokeTex = canvasSprite(64, 64, soft('rgba(70,64,62,.8)', 'rgba(50,46,44,.38)', 'rgba(40,36,34,0)'));
  steamTex = canvasSprite(64, 64, soft('rgba(245,245,240,.75)', 'rgba(225,225,220,.35)', 'rgba(220,220,215,0)'));
  emberTex = canvasSprite(16, 16, g => { const r = g.createRadialGradient(8, 8, 0, 8, 8, 8); r.addColorStop(0, '#fffbe0'); r.addColorStop(.35, '#ffb030'); r.addColorStop(1, 'rgba(255,60,0,0)'); g.fillStyle = r; g.fillRect(0, 0, 16, 16); });
  haloTex = canvasSprite(128, 96, g => { const r = g.createRadialGradient(64, 60, 4, 64, 60, 62); r.addColorStop(0, 'rgba(255,150,50,.7)'); r.addColorStop(.5, 'rgba(255,70,10,.28)'); r.addColorStop(1, 'rgba(255,40,0,0)'); g.fillStyle = r; g.fillRect(0, 0, 128, 96); }); }
function fxSprite(tex, w, h, x, sy, lift, add) { // 画面上の大きさ w×h（基準画像の画素）。地面の(x,sy)から、画面で lift だけ上に置く。他の絵の上に重ねて描く
  const z = zOf(sy), m = new THREE.Mesh(planeGeo, new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false, depthTest: false, blending: add ? THREE.AdditiveBlending : THREE.NormalBlending }));
  m.quaternion.copy(baseQ); m.scale.set(w, h, 1); m.position.set(x, hgt(x, z) + lift / COS, z); m.renderOrder = 30; m.frustumCulled = false; scene.add(m); return m; }
function spawnPart(o) { // o: tex, w0, w1, a0, life(秒), x, sy, lift, vx, vy(画面の画素/秒), add
  const m = fxSprite(o.tex, o.w0, o.w0, o.x, o.sy, o.lift, o.add); m.material.opacity = o.a0; bparts.push({ m, o, t0: performance.now(), z: zOf(o.sy) }); }
function emitAt(pl, kind, n) { // kind: smoke / ember / burst / steam
  burnTexInit(); const hw = pl.hit ? pl.hit.w * .28 : 40, top = pl.hit && pl.fac !== 'farm' ? (pl.base[1] - pl.hit.top) * .5 : 14, R = Math.random;
  for (let i = 0; i < n; i++) { const x = pl.cx + (R() - .5) * 2 * hw, sy = pl.base[1] - 30;
    if (kind === 'smoke') spawnPart({ tex: smokeTex, w0: 22, w1: 70, a0: .6, life: 2.6 + R() * 1.2, x, sy, lift: top + 20 + R() * 20, vx: 8 + R() * 10, vy: 26 + R() * 14 });
    else if (kind === 'steam') spawnPart({ tex: steamTex, w0: 26, w1: 80, a0: .7, life: 1.4 + R() * .6, x, sy, lift: top * .6 + R() * 16, vx: (R() - .5) * 20, vy: 40 + R() * 24 });
    else spawnPart({ tex: emberTex, w0: kind === 'burst' ? 9 : 6, w1: 2, a0: 1, life: (kind === 'burst' ? .9 : 1.1) + R() * .7, x, sy, lift: top * .8 + R() * 20, vx: (R() - .5) * (kind === 'burst' ? 110 : 40), vy: (kind === 'burst' ? 70 : 34) + R() * 40, add: true }); } }
function burnUpdate(now) {
  for (let i = bparts.length - 1; i >= 0; i--) { const { m, o, t0, z } = bparts[i], a = (now - t0) / 1000, k = a / o.life;
    if (k >= 1) { scene.remove(m); m.material.dispose(); bparts.splice(i, 1); continue; }
    const x = o.x + o.vx * a + Math.sin(a * 3 + o.x) * (o.tex === emberTex ? 4 : 2), w = o.w0 + (o.w1 - o.w0) * k;
    m.position.set(x, hgt(x, z) + (o.lift + o.vy * a * (o.tex === emberTex ? 1 - a / o.life * .5 : 1)) / COS, z); m.scale.set(w, w, 1);
    m.material.opacity = o.a0 * (o.tex === emberTex ? 1 - k * k : (1 - k) * Math.min(1, a * 3)); }
  for (const pl of plots) { if (!pl.fire || !pl.fire.parent) continue; burnTexInit();
    const ign = pl.fire.userData.ign; if (ign) { const t = Math.min(1, (now - ign) / 1500), c = 1 - t * (1 - BURN_COL[0]);
      [pl.mesh, pl.pav].forEach(mm => mm && mm.material.color.setRGB(1 + (BURN_COL[0] - 1) * t, 1 + (BURN_COL[1] - 1) * t, 1 + (BURN_COL[2] - 1) * t));
      if (!pl.fire.userData.burst) { pl.fire.userData.burst = 1; emitAt(pl, 'burst', 18); }
      if (t >= 1) pl.fire.userData.ign = 0; }
    if (!pl.halo) { pl.halo = fxSprite(haloTex, (pl.hit ? pl.hit.w : 150) * 1.5, (pl.hit ? pl.hit.w : 150) * 1.1, pl.cx, pl.base[1] - 30, pl.hit && pl.fac !== 'farm' ? (pl.base[1] - pl.hit.top) * .3 : 6, true); }
    pl.halo.material.opacity = (ign ? Math.min(1, (now - ign) / 900) : 1) * (.55 + .2 * Math.sin(now / 170 + pl.cx) + .1 * Math.sin(now / 53));
    if (!pl.nextSmoke || now > pl.nextSmoke) { emitAt(pl, 'smoke', 1); pl.nextSmoke = now + 380 + Math.random() * 260; }
    if (!pl.nextEmber || now > pl.nextEmber) { emitAt(pl, 'ember', 1); pl.nextEmber = now + 120 + Math.random() * 200; } } }
const BURN_COL = [.2, .16, .14];
function refreshPlot(pl) {
  if (!fireTex) fireTex = canvasSprite(96, 160, g => { // 炎と煙（コード描画）
    for (let i = 0; i < 6; i++) { const r = g.createRadialGradient(48, 30 + i * 8, 2, 48, 30 + i * 8, 34 - i * 2); r.addColorStop(0, 'rgba(70,60,60,.5)'); r.addColorStop(1, 'rgba(40,35,35,0)'); g.fillStyle = r; g.fillRect(0, 0, 96, 160); }
    const f = g.createRadialGradient(48, 128, 4, 48, 118, 40); f.addColorStop(0, '#fff6c0'); f.addColorStop(.3, '#ffb030'); f.addColorStop(.7, 'rgba(255,60,10,.8)'); f.addColorStop(1, 'rgba(255,40,0,0)');
    for (const [x0, h, w] of [[30, 70, 16], [48, 92, 20], [66, 64, 15], [40, 52, 12], [58, 78, 14]]) { const fl = g.createLinearGradient(0, 160, 0, 160 - h); fl.addColorStop(0, '#fff2b0'); fl.addColorStop(.35, '#ffa020'); fl.addColorStop(.8, 'rgba(230,50,10,.85)'); fl.addColorStop(1, 'rgba(200,30,0,0)');
      g.fillStyle = fl; g.beginPath(); g.moveTo(x0 - w, 158); g.quadraticCurveTo(x0 - w * .8, 160 - h * .5, x0, 160 - h); g.quadraticCurveTo(x0 + w * .8, 160 - h * .5, x0 + w, 158); g.closePath(); g.fill(); } });
  if (pl.pav) { scene.remove(pl.pav); pl.pav.geometry.dispose(); pl.pav = null; }
  if (pl.mesh) { scene.remove(pl.mesh); pl.mesh.material.dispose(); pl.mesh = null; }
  pl.hit = null; pl.poly = pl.home;
  const alias = ARTALIAS[pl.fac], key = `${alias ? alias[0] : pl.fac}_${pl.stage}`, t = pl.fac && pl.stage >= 1 ? bldTex[key] : null;
  if (pl.fac === 'farm' && pl.stage >= 1) { // 畑の絵は地面に貼る（真上からの正射影なので、地面の板でも絵どおりに見え、上に立つ仲間を隠さない）
    if (t) { const meta = bld[`assets/bld/${key}.png`], S = FARM_S, w = meta.w * S, h = meta.h * S, left = pl.cx - meta.ax * w, bot = pl.base[1] + 6, top = bot - meta.ay * h;
      pl.pav = groundRect(t, left, top, w, h); scene.add(pl.pav); pl.hit = { key, left, top, w, h }; }
    else { pl.pav = pavingMesh(grow(pl.home, .94), false, cropTexture(pl.stage)); scene.add(pl.pav); }
  } else if (t) {
    const meta = bld[`assets/bld/${key}.png`];
    pl.mesh = sprite3D(t, meta, BS, pl.cx, pl.base[1] - 4); scene.add(pl.mesh);
    pl.pav = pavingMesh(grow(pl.home, 1.0)); scene.add(pl.pav);
    const bottom = pl.base[1] - 4, w = meta.w * BS, h = meta.h * BS;
    pl.hit = { key, left: pl.cx - meta.ax * w, top: bottom - meta.ay * h, w, h };
    if (alias) pl.mesh.material.color.setRGB(...alias[1], THREE.SRGBColorSpace);
  }
  pl.stakes.visible = !(pl.fac && pl.stage >= 1);
  if (pl.fire) { scene.remove(pl.fire); pl.fire = null; }
  if (pl.halo) { scene.remove(pl.halo); pl.halo.material.dispose(); pl.halo = null; }
  if (pl.burnt) { const fresh = pl.ign && performance.now() - pl.ign < 1500; [pl.mesh, pl.pav].forEach(mm => mm && (fresh ? mm.material.color.setRGB(1, 1, 1) : mm.material.color.setRGB(...BURN_COL))); // 焼かれた施設：黒ずませ、火と煙を出す（燃えた直後は、炎が立ち上がりながら黒ずむ）
    pl.fire = sprite3D(fireTex, { w: 96, h: 160, ax: .5, ay: .95 }, .55, pl.cx, pl.base[1] - 30); pl.fire.position.y += (pl.hit && pl.fac !== 'farm' ? (pl.base[1] - pl.hit.top) * .45 : 10) / COS; pl.fire.renderOrder = 20; if (pl.ign && performance.now() - pl.ign < 1500) pl.fire.userData.ign = pl.ign; scene.add(pl.fire); fireMeshes.add(pl.fire); }
  paintYards(plots.map(p => p.poly)); splatTex.needsUpdate = true;
  if (selected === pl) select(pl);
}
// ---------- 広場・目印（仮の絵：コードで描いた印。あとで外部AIの絵に差し替える）----------
function canvasSprite(w, h, draw) { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d')); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; }
const ell = (g, cx, cy, rx, ry, col) => { g.fillStyle = col; g.beginPath(); g.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2); g.fill(); };
const PIECE = {
  fountain: () => canvasSprite(256, 224, g => {
    ell(g, 128, 180, 120, 38, '#6d675c'); ell(g, 128, 172, 120, 38, '#a39b8a'); ell(g, 128, 170, 104, 31, '#5aa7d8'); ell(g, 128, 168, 96, 27, '#7cc4ee');
    g.fillStyle = '#8f8878'; g.fillRect(112, 84, 32, 84); g.fillStyle = '#b3ab99'; g.fillRect(112, 84, 14, 84);
    ell(g, 128, 90, 52, 15, '#8f8878'); ell(g, 128, 86, 52, 15, '#b3ab99'); ell(g, 128, 85, 44, 11, '#7cc4ee');
    g.fillStyle = '#9a9283'; g.fillRect(122, 40, 12, 48); ell(g, 128, 40, 12, 5, '#b3ab99');
    g.strokeStyle = 'rgba(235,248,255,.85)'; g.lineWidth = 3; [-1, 1].forEach(d => { g.beginPath(); g.moveTo(128, 38); g.quadraticCurveTo(128 + d * 36, 14, 128 + d * 56, 82); g.stroke(); });
  }),
  well: () => canvasSprite(200, 240, g => {
    ell(g, 100, 200, 70, 24, '#6d675c'); g.fillStyle = '#8f8878'; g.fillRect(30, 150, 140, 50); ell(g, 100, 150, 70, 24, '#a39b8a'); ell(g, 100, 150, 54, 17, '#243a4a');
    g.fillStyle = '#6b4a2a'; g.fillRect(38, 60, 12, 95); g.fillRect(150, 60, 12, 95); g.fillRect(44, 92, 112, 7);
    g.fillStyle = '#7a3b26'; g.beginPath(); g.moveTo(14, 70); g.lineTo(100, 18); g.lineTo(186, 70); g.lineTo(170, 80); g.lineTo(100, 38); g.lineTo(30, 80); g.closePath(); g.fill();
    g.fillStyle = '#5a3a20'; g.fillRect(92, 99, 16, 22);
  }),
  lamp: () => canvasSprite(48, 160, g => {
    ell(g, 24, 152, 14, 5, 'rgba(0,0,0,.35)'); g.fillStyle = '#2b2620'; g.fillRect(21, 40, 6, 112); g.fillRect(14, 140, 20, 10);
    g.fillStyle = '#2b2620'; g.fillRect(12, 16, 24, 6); g.fillRect(14, 22, 20, 22); g.fillStyle = '#ffd77a'; g.fillRect(17, 25, 14, 16);
    g.fillStyle = 'rgba(255,215,120,.25)'; g.beginPath(); g.arc(24, 33, 20, 0, Math.PI * 2); g.fill();
  }),
  sign: label => canvasSprite(128, 144, g => {
    g.fillStyle = '#5a3a20'; g.fillRect(58, 56, 12, 86); ell(g, 64, 140, 18, 5, 'rgba(0,0,0,.35)');
    g.fillStyle = '#3a2614'; g.beginPath(); g.roundRect(6, 8, 116, 54, 8); g.fill(); g.fillStyle = '#c9a46a'; g.beginPath(); g.roundRect(10, 12, 108, 46, 6); g.fill();
    g.fillStyle = '#2a1a08'; g.font = 'bold 26px system-ui,"Noto Sans JP",sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(label, 64, 36, 100);
  }),
};
const pieceTex = {};
function piece(kind, x, sy, scale, arg) { const k = kind + (arg || ''); const t = pieceTex[k] || (pieceTex[k] = PIECE[kind](arg)); const im = t.image; const m = sprite3D(t, { w: im.width, h: im.height, ax: .5, ay: .95 }, scale, x, sy); scene.add(m); return m; }
// 街の小物の絵（assets/town/、外部AIのシートから切り出し）。立て札は板に文字をコードで書く
const TOWN = {};
for (const n of ['fountain', 'well', 'lamp', 'sign', 'stall', 'barrels', 'flowerbed', 'bench', 'cart', 'torch', 'hay', 'fence']) TOWN[n] = await loadImage(`assets/town/${n}.png`);
const townTex = {};
function townPiece(kind, x, sy, scale, label, flip) {
  const im = TOWN[kind]; if (!im) return piece(kind === 'sign' ? 'sign' : kind, x, sy, scale, label);
  const key = kind + (label || ''); let t = townTex[key];
  if (!t) {
    const c = document.createElement('canvas'); c.width = im.width; c.height = im.height; const g = c.getContext('2d'); g.drawImage(im, 0, 0);
    if (label) { const bx = im.width * .68, by = im.height * .615, bw = im.width * .56; g.fillStyle = '#2a1708'; g.font = `bold ${Math.round(im.width * .15)}px "Hiragino Mincho ProN","Yu Mincho","Noto Serif JP",serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(label, bx, by, bw); }
    t = townTex[key] = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  }
  const m = sprite3D(t, { w: im.width, h: im.height, ax: .5, ay: .96 }, scale, x, sy); if (flip) m.scale.x *= -1; scene.add(m); return m;
}
const waterMats = [];
function animateWater(mesh) { // 噴水の水だけを動かす：青い画素に、下へ流れる筋と、きらめきを足す
  const mat = mesh.material; mat.onBeforeCompile = sh => { sh.uniforms.time = { value: 0 }; mat.userData.sh = sh;
    sh.fragmentShader = 'uniform float time;\n' + sh.fragmentShader.replace('#include <map_fragment>', `#include <map_fragment>
      { vec3 c = diffuseColor.rgb; float w = smoothstep(.04, .16, c.b - max(c.r, c.g * .9)) * step(.25, c.b);
        float fall = sin(vMapUv.y * 90. + time * 9. + sin(vMapUv.x * 40.) * 2.) * .5 + .5, sp = step(.93, fract(sin(dot(floor(vMapUv * vec2(70., 50.)) + floor(time * 6.), vec2(12.9898, 78.233))) * 43758.5453));
        diffuseColor.rgb += w * (vec3(.18, .24, .28) * fall + vec3(.6) * sp); }`); };
  mat.needsUpdate = true; waterMats.push(mat); return mesh; }
const onLotOrRoad = (x, y) => layout.plots.some(p => pointInPoly(x, y, p.poly)) || splatAt(x, y)[0] > .25 || splatAt(x, y)[2] > .2;
layout.plazas.forEach((pz, n) => { // 広場：石畳＋中央の噴水／井戸＋四隅の街灯＋屋台・花壇・ベンチ・樽
  const [T, R, B, L] = pz.poly; scene.add(pavingMesh([T, R, B, L], true));
  const [cx, cy] = pz.center;
  if (pz.kind === 'fountain') animateWater(townPiece('fountain', cx, cy + 34, .44)); else townPiece('well', cx, cy + 34, .42);
  [T, R, B, L].forEach(([x, y]) => townPiece('lamp', x + (cx - x) * .12, y + (cy - y) * .12, .2));
  const mid = (p, q, k = .3) => [(p[0] + q[0]) / 2 + (cx - (p[0] + q[0]) / 2) * k, (p[1] + q[1]) / 2 + (cy - (p[1] + q[1]) / 2) * k];
  const d = [['stall', T, R, .3], ['flowerbed', L, T, .34], ['bench', B, L, .34], ['barrels', R, B, .3]];
  d.forEach(([kd, p, q, sc], i) => { const [x, y] = mid(p, q, .34); townPiece(kd, x, y + 4, sc * .62, null, (i + n) % 2 === 1); });
});
{ // 交差点と道の曲がり角に街灯、広場の外の通り沿いにたいまつ
  const pts = [];
  layout.roads.forEach(rd => rd.pts.forEach(([x, y], i) => { if (i > 0 && i < rd.pts.length - 1 && x > 0 && x < REF_W) pts.push([x, y]); }));
  pts.forEach(([x, y]) => { if (!layout.plazas.some(pz => pointInPoly(x, y, pz.poly))) townPiece('lamp', x + 26, y - 6, .2); });
}
{ // 街の外れ：荷馬車・干し草・柵（区画・道・水の上は避ける）
  const R2 = rng(77);
  layout.plazas.forEach(pz => { const [cx, cy] = pz.center;
    [[-360, -150, 'hay', .3], [-300, -175, 'cart', .26], [360, 150, 'hay', .28], [420, 120, 'fence', .26], [-420, 170, 'fence', .26], [300, -190, 'cart', .24], [0, 250, 'torch', .2], [0, -250, 'torch', .2]].forEach(([dx, dy, kd, sc]) => {
      for (let t = 0; t < 6; t++) { const x = cx + dx + (R2() - .5) * 60 * t, y = cy + dy + (R2() - .5) * 30 * t; if (!onLotOrRoad(x, y) && !layout.plazas.some(q => pointInPoly(x, y, q.poly))) { townPiece(kd, x, y, sc, null, R2() < .5); break; } }
    }); });
}
const signs = layout.signs.map(sg => ({ ...sg, mesh: townPiece('sign', sg.x, sg.y, .34, sg.label) }));

// ---------- 開拓（未開拓の地は霧で覆う）----------
const areas = layout.areas.map(a => ({ ...a }));
// 霧は1枚：未開拓のうち一番手前の区域の左端から、世界の右端まで。開拓すると古い霧が消え、新しい霧が次の区域から始まる
let fog = null;
function fogMesh(x0) {
  const x1 = REF_W + 160, z0 = zOf(372), z1 = zOf(REF_H + 300);
  const k = Math.min(.5, 70 / (x1 - x0)), tex = canvasSprite(1024, 128, g => { // 左の縁（約70px）と奥の縁をぼかした暗い霧
    const gr = g.createLinearGradient(0, 0, 1024, 0); gr.addColorStop(0, 'rgba(8,12,18,0)'); gr.addColorStop(k, 'rgba(8,12,18,.72)'); gr.addColorStop(1, 'rgba(8,12,18,.72)'); g.fillStyle = gr; g.fillRect(0, 0, 1024, 128);
    const gv = g.createLinearGradient(0, 0, 0, 128); gv.addColorStop(0, 'rgba(0,0,0,0)'); gv.addColorStop(.06, 'rgba(0,0,0,1)'); g.globalCompositeOperation = 'destination-in'; g.fillStyle = gv; g.fillRect(0, 0, 1024, 128); });
  const m = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0, z1 - z0), new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthTest: false, depthWrite: false }));
  m.rotation.x = -Math.PI / 2; m.position.set((x0 + x1) / 2, 0, (z0 + z1) / 2); m.renderOrder = 50; scene.add(m);
  m.userData.x0 = x0; return m;
}
function updateFog(instant) {
  const first = areas.filter(a => a.locked).sort((p, q) => p.x0 - q.x0)[0], x0 = first ? first.x0 - 40 : null;
  if (fog && fog.userData.x0 === x0) return;
  const old = fog; fog = x0 === null ? null : fogMesh(x0);
  if (!old) return; if (instant) { scene.remove(old); old.material.map.dispose(); return; }
  const t0 = performance.now(); (function fade() { const k = Math.min(1, (performance.now() - t0) / 900); old.material.opacity = 1 - k; if (k < 1) requestAnimationFrame(fade); else { scene.remove(old); old.material.map.dispose(); } })();
}
const areaOf = x => areas.find(a => x >= a.x0 && x < (a.x1 || Infinity)); // 区域は x の範囲で分ける（次の区域は layout に足すだけ）
const lockedAt = x => { const a = areaOf(x); return !!a && a.locked; };
function showArea(a, open) { a.locked = !open; }
function hitBuilding(sx, sy) { // 建物の絵（透明でない所）を押したか。手前の建物を優先
  let best = null;
  for (const pl of plots) {
    const h = pl.hit; if (!h) continue; const u = (sx - h.left) / h.w, v = (sy - h.top) / h.h; if (u < 0 || u > 1 || v < 0 || v > 1) continue;
    const m = alphaMask(h.key), px = Math.min(m.w - 1, u * m.w | 0), py = Math.min(m.h - 1, v * m.h | 0);
    if (m.d[(py * m.w + px) * 4 + 3] > 40 && (!best || pl.base[1] > best.base[1])) best = pl;
  }
  return best;
}
function hitCastle(sx, sy) { const h = castleHit; if (!h) return false; const u = (sx - h.left) / h.w, v = (sy - h.top) / h.h; if (u < 0 || u > 1 || v < 0 || v > .9) return false; const m = alphaMask('castle'); return m.d[((Math.min(m.h - 1, v * m.h | 0)) * m.w + Math.min(m.w - 1, u * m.w | 0)) * 4 + 3] > 40; }
function setPlot(pl, fac, stage) { pl.fac = stage ? fac : null; pl.stage = stage; refreshPlot(pl); }

// ---------- 仲間（家の街の広場に立つ。仲間になると現れる）----------
const ALLY_POS = { mina: [372, 1066], garou: [568, 1066], sera: [505, 1090], ranka: [435, 1090], lily: [470, 1110] };
const MAP_BB = { mina: 635, garou: 670, sera: 635, ranka: 625, lily: 628 }, MAP_H = { mina: 76, sera: 76, ranka: 76 * 202 / 210, garou: 76 * 228 / 210, lily: 76 * 224 / 210 }; /* リリィの背の高さは224（2026-10-30、212から上げた） */ // マップ用の絵（ally/map_*.png）の人物の高さ（実測）と、描く高さ
const allyMesh = {}, WALK_BBH = { mina: 420, garou: 452, sera: 424, ranka: 426, lily: 430 }; // 歩行コマの中の人物の高さ（元の512px基準）
for (const k of Object.keys(GM.ALLY)) {
  const mapIm = await loadImage(`../ally/map_${k}.png`), im = mapIm || await loadImage(`../ally/${k}.png`); if (!im) continue; // マップ用の小さな絵（等角）。なければ立ち絵
  const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  const [x, y] = ALLY_POS[k], sc = mapIm ? MAP_H[k] / MAP_BB[k] : 74 / im.height; /* マップ用の絵：背の高さは HUMAN と同じ比（2026-10-30） */ const m = sprite3D(t, { w: im.width, h: im.height, ax: .5, ay: .98 }, sc, x, y); m.visible = false; scene.add(m);
  allyMesh[k] = { m, x, y, w: im.width * sc, h: im.height * sc, stand: t, sw: 1, sh: 1, walkT: null };
  // 歩行シート（4×4、1コマ192×240。ループ16コマ）。立ち姿と同じ背の高さになるよう拡大率を合わせる
  const wim = await loadImage(`../ally/walk_${k}.webp`);
  if (wim) { const wt = new THREE.Texture(wim); wt.needsUpdate = true; wt.colorSpace = THREE.SRGBColorSpace; wt.anisotropy = 8; wt.repeat.set(.25, .25); const u = (im.height * sc) / WALK_BBH[k]; allyMesh[k].walkT = wt; allyMesh[k].ww = 384 * u; allyMesh[k].wh = 480 * u; }
}
function placeAlly(k, x, y) { const a = allyMesh[k]; if (!a) return; const z = zOf(y); a.m.position.set(x, hgt(x, z), z); a.x = x; a.y = y; }
// 仲間は家の街を歩き回る（広場の中と、その周りの道）。配置は施設の上の顔のアイコンで見せる
const HOME = layout.plazas[0];
function walkTarget() { const [cx, cy] = HOME.center;
  for (let t = 0; t < 20; t++) { const r = Math.random(), x = cx + (Math.random() - .5) * 520, y = cy + (Math.random() - .5) * 260;
    const inPlaza = pointInPoly(x, y, HOME.poly) && Math.hypot(x - cx, (y - cy) * 2) > 90, onRoad = splatAt(x, y)[0] > .5 && !layout.plots.some(p => pointInPoly(x, y, p.poly));
    if (inPlaza || (onRoad && r < .5)) return [x, y]; }
  return [cx - 100, cy + 40]; }
for (const k of Object.keys(allyMesh)) { const a = allyMesh[k]; a.wait = Math.random() * 3; a.tx = a.x; a.ty = a.y; a.sx = a.m.scale.x; }
function setWalkPose(a, walking, now) { // 歩く間は歩行シート、止まっている間は立ち姿に差し替える
  const mat = a.m.material;
  if (walking && a.walkT) {
    if (mat.map !== a.walkT) { mat.map = a.walkT; mat.needsUpdate = true; }
    const f = Math.floor(now / 94) % 16; a.walkT.offset.set((f % 4) * .25, 1 - (Math.floor(f / 4) + 1) * .25);
    const sg = Math.sign(a.m.scale.x) || 1; a.m.scale.set(a.ww * sg, a.wh, 1);
  } else if (mat.map !== a.stand) { mat.map = a.stand; mat.needsUpdate = true; const sg = Math.sign(a.m.scale.x) || 1; a.m.scale.set(a.w * sg, a.h, 1); }
}
function walkAllies(dt) { const now = performance.now();
  for (const k of Object.keys(allyMesh)) { const a = allyMesh[k]; if (!a.m.visible) continue;
    if (a.wait > 0) { a.wait -= dt; setWalkPose(a, false, now); if (a.wait <= 0) [a.tx, a.ty] = walkTarget(); continue; }
    const dx = a.tx - a.x, dy = a.ty - a.y, d = Math.hypot(dx, dy * 1.6); if (d < 2) { a.wait = 2 + Math.random() * 4; setWalkPose(a, false, now); continue; }
    const sp = 22 * dt; placeAlly(k, a.x + dx / d * Math.min(sp, d), a.y + dy / d * Math.min(sp, d)); if (Math.abs(dx) > 1) a.m.scale.x = Math.abs(a.m.scale.x) * (dx < 0 ? -1 : 1);
    setWalkPose(a, true, now); }
}
const faceTex = {}, faceURL = {}, faceRaw = {};
const FACE = { mina: [178, 74, 56], garou: [247, 50, 58], sera: [150, 64, 54], ranka: [180, 62, 56], lily: [140, 62, 50] }; // 立ち絵の顔の中心と半径（画素）
async function makeFace(k) { // 立ち絵の顔を丸く切り抜いて、金の縁をつける
  const im = await loadImage(`../ally/${k}.png`); if (!im) return null; const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.fillStyle = '#2a1a0c'; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.fill(); g.save(); g.beginPath(); g.arc(64, 64, 54, 0, 7); g.clip();
  const [fx, fy, fr] = FACE[k] || [im.width / 2, 70, 60], s = fr * 2.3; g.drawImage(im, fx - s / 2, fy - s / 2, s, s, 10, 10, 108, 108); g.restore();
  g.strokeStyle = '#e8c060'; g.lineWidth = 7; g.beginPath(); g.arc(64, 64, 56, 0, 7); g.stroke(); g.strokeStyle = '#5a3a10'; g.lineWidth = 2; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.stroke();
  { const c2 = document.createElement('canvas'); c2.width = c2.height = 128; const g2 = c2.getContext('2d'); g2.beginPath(); g2.arc(64, 64, 64, 0, 7); g2.clip(); g2.drawImage(im, fx - s / 2, fy - s / 2, s, s, 0, 0, 128, 128); faceRaw[k] = c2.toDataURL(); }
  faceURL[k] = c.toDataURL(); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; }
for (const k of Object.keys(GM.ALLY)) faceTex[k] = await makeFace(k);
let badges = [];
function refreshBadges() {
  badges.forEach(b => scene.remove(b)); badges = [];
  for (const [k, id] of Object.entries(G.assign || {})) { const pl = plots.find(q => q.id === id), p = G.plots[id]; if (!pl || !p || !faceTex[k] || (k === 'ranka' && G.rankaAway)) continue;
    const top = pl.hit && p.fac !== 'farm' ? pl.hit.top + 10 : pl.base[1] - 70, lift = (pl.base[1] - top) / COS;
    const bx = pl.hit ? pl.hit.left + pl.hit.w / 2 : pl.cx, b = sprite3D(faceTex[k], { w: 128, h: 128, ax: .5, ay: 1 }, .56, bx, pl.base[1]); b.position.y += lift; b.material.depthTest = false; b.material.depthWrite = false; b.material.transparent = true; b.renderOrder = 999; /* 最前面（木や建物より手前） */ b.userData.y0 = b.position.y; scene.add(b); badges.push(b); }
}
function allySpot(k) { // 配置先の施設の手前（左寄り）。配置していなければ家の広場
  const id = G.assign && G.assign[k], pl = id && plots.find(q => q.id === id);
  if (!pl) return ALLY_POS[k];
  return G.plots[id] && G.plots[id].fac === 'farm' ? [pl.cx - 20, pl.base[1] - 34] : [pl.cx - 58, pl.base[1] - 16];
}
let curLine = '';
const hitAlly = (sx, sy) => Object.keys(allyMesh).find(k => { const a = allyMesh[k]; return a.m.visible && Math.abs(sx - a.x) < a.w * .45 && sy > a.y - a.h && sy < a.y + 4; });

// ---------- ゲームの状態（game.js のルール）と画面の同期 ----------
const SAVE_KEY = 'territory_v2';
let G = null, selCastle = false, selAlly = null;
function loadSave() { try { const v = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (v && v.week) { v.bond = Object.assign({ mina: 0, garou: 0, sera: 0, ranka: 0, lily: 0 }, v.bond || {}); v.assign = v.assign || {}; v.met = v.met || {}; return v; } return null; } catch (e) { return null; } }
function writeSave() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); } catch (e) { } }
function syncMap(instant) { // 状態 → 区画の絵と霧
  for (const pl of plots) { const p = G.plots[pl.id]; const f = p ? p.fac : null, stg = p ? p.stage : 0; const bt = !!(p && p.burnt); if (pl.fac !== f || pl.stage !== stg || pl.burnt !== bt) { if (!instant && pl.burnt === false && bt) pl.ign = performance.now(); if (!instant && pl.burnt && !bt) emitAt(pl, 'steam', 9); pl.burnt = bt; setPlot(pl, f, stg); } }
  updateCamp();
  for (const a of areas) showArea(a, G.open.includes(a.id)); updateFog(instant);
  for (const k of Object.keys(allyMesh)) { const v = GM.joined(G, k); if (v && !allyMesh[k].m.visible && !instant) ui.toast(`${GM.ALLY[k].n}（${GM.ALLY[k].r}）が仲間になった`); allyMesh[k].m.visible = v && !(k === 'ranka' && G.rankaAway); }
  refreshBadges();
}
const ui = createUI({ onEndWeek: () => endWeek(), onReset: () => { G = GM.newState(layout.areas); select(null); syncMap(true); commit('最初からやり直した'); setTimeout(chapterStartScene, 300); } });
function commit(msg) { writeSave(); syncMap(); refreshUI(); if (msg) ui.toast(msg); }
function act(fn, ok) { if (fn()) commit(ok); else ui.toast('できない（行動点か物資が足りない）'); }
const sg = n => (n >= 0 ? '+' : '') + n;
function endWeek() {
  if (G.over) return; if (G.raid) { raidModal(); return; }
  G.repPrev = GM.snap(G); const msg = GM.endWeek(G); select(null);
  if (G.raid) { ui.toast(msg); raidIntro(() => { writeSave(); refreshUI(); }); commit(null); } else { commit(msg); showReport(); }
}
const morning = createMorning();
const story = createStory();
function playStory(c, kind, then) { // 章の始まり／終わりの会話（story.js）
  const C = GM.CHAPTERS[c - 1]; if (!C) { then && then(); return; }
  try { story.play({ c, kind, title: C.t, desc: C.d, foeName: C.g, foeBust: [`assets/npc/bust_g${c}${c === 6 && kind !== 'start' ? 'b' : ''}.webp`, 'assets/npc/bust_4.webp'], por: POR, ranaSrc: '../sprites/idle_00.png' }, then); } catch (e) { console.error('章の会話', e); then && then(); }
}
function chapterStartScene() { if (!G || !G.chStart || G.raid || G.over) return; const c = G.chStart; G.chStart = 0; writeSave(); playStory(c, 'start', () => refreshUI()); }
function chapterEndScene(then) { if (!G.chEnd) { then(); return; } const e = G.chEnd; G.chEnd = null; writeSave(); playStory(e.c, e.win ? 'win' : 'lose', then); }
function openMorning(prev, R) { // 朝の報告：空の部屋、ラナの歩き、報告役の3文 → タップで「今朝の変化」→ タップで領地へ
  const adv = GM.advisorOf(G), who = adv && GM.joined(G, adv) ? adv : 'mina', m = Math.round, rows = [];
  rows.push({ ic: 'sup', label: '物資', from: prev.sup, to: G.sup, d: G.sup - prev.sup });
  rows.push({ ic: 'mor', label: '民心', from: m(prev.morale), to: m(G.morale), d: m(G.morale) - m(prev.morale) });
  if (prev.troops !== G.troops) rows.push({ ic: 'trp', label: '兵力', from: prev.troops, to: G.troops, d: G.troops - prev.troops });
  if (prev.hp !== G.hp) rows.push({ ic: 'hp', label: '城の耐久', from: prev.hp, to: G.hp, d: G.hp - prev.hp });
  for (const t of [...new Set(R.changes)]) { if (t.startsWith('完成：')) rows.push({ ic: 'build', label: '完成', text: t.slice(3) }); else if (/：/.test(t)) rows.push({ ic: 'flag', label: '襲撃', text: t.split('：').slice(1).join('：') }); }
  const warns = (who === 'mina' ? R.warns : R.warns.filter(w => !/週後|今週末|来週末|敵の陣/.test(w))).slice(0, 2);
  morning.show({ week: Math.min(G.week, GM.WEEKS), res: { sup: G.sup, morale: m(G.morale), def: m(GM.D(G)) }, who, name: GM.ALLY[who].n, lines: GM.morningLines(G, who), rows, warns,
    onClose: () => { advisorMsg = null; select(null); ui.modal(null); refreshUI(); chapterStartScene(); } });
}
function showReport() { // 週末の報告。朝の場面（報告役が3文）。出せないときは、吹き出しか羊皮紙
  if (!G.repPrev || G.raid) return; if (G.over) { G.repPrev = null; return; } if (G.chEnd) { chapterEndScene(showReport); return; } const prev = G.repPrev, R = GM.weekReport(prev, G); G.repPrev = null; writeSave();
  try { ui.modal(null); openMorning(prev, R); return; } catch (e) { console.error('朝の報告', e); }
  const adv = GM.advisorOf(G);
  if (adv && GM.ALLY[adv] && GM.joined(G, adv)) {
    advisorMsg = `${R.title}です。${R.changes.join('、')}。${R.warns.length ? '<br><span style="color:#8a1a10">' + R.warns.join('<br>') + '</span>' : '<br>差し迫った心配はありません。'}`;
    select(null); ui.modal(null); refreshUI(); return;
  }
  ui.modal(R.title, `<div class="lab">変わったこと</div><ul>${R.changes.map(t => `<li>${t}</li>`).join('')}</ul><div class="lab">気をつけること</div><ul class="w">${R.warns.length ? R.warns.map(t => `<li>${t}</li>`).join('') : '<li style="color:#3a2410">差し迫った心配はない</li>'}</ul>`,
    [{ label: `第${Math.min(G.week, GM.WEEKS)}週へ`, fn: () => ui.modal(null) }], 'parch');
}
// ---------- 襲撃の演出（攻めてくる軍勢）と、任せた戦闘の演出 ----------
const fxCss = document.createElement('style'); fxCss.textContent = `
#raidfx{position:fixed;inset:0;z-index:7;pointer-events:none;opacity:0;transition:opacity .6s;background:radial-gradient(ellipse at 50% 45%,#0000 35%,#5a0a06aa 80%,#2a0402dd),linear-gradient(#3a0a0a66,#0000 40%,#1a020266)}
#raidfx.on{opacity:1}
#raidban{position:fixed;left:0;right:0;top:42%;z-index:8;pointer-events:none;text-align:center;transform:translateX(110%);transition:transform .45s cubic-bezier(.2,.9,.3,1)}
#raidban.on{transform:none}#raidban.off{transform:translateX(-110%)}
#raidban div{display:inline-block;padding:10px 40px;background:linear-gradient(90deg,#0000,#3a0806ee 15%,#3a0806ee 85%,#0000);color:#ffd8c0;font:900 26px/1.2 "Hiragino Mincho ProN","Yu Mincho",serif;text-shadow:0 0 12px #ff3a20,0 2px 3px #000;letter-spacing:.1em}
#raidban small{display:block;font-size:13px;letter-spacing:0;color:#ffb8a0}
#abt{position:fixed;inset:0;z-index:9;display:none;align-items:center;justify-content:center;background:#0a0402d8;color:#f3e6c0;font:600 13px/1.4 "Hiragino Mincho ProN","Yu Mincho",serif}
#abt .st{width:min(94vw,420px);position:relative}
#abt .ttl{text-align:center;font:900 20px/1.3 serif;color:#ffd770;text-shadow:0 0 8px #f80}
#abt .sides{display:flex;justify-content:space-between;align-items:flex-end;margin:10px 0 6px;height:150px;position:relative}
#abt .us{display:flex;align-items:flex-end;gap:0}#abt .us img{height:128px;margin-right:-26px;filter:drop-shadow(0 3px 6px #000)}
#abt .us .tr,#abt .foe .tr{font-size:12px;color:#c9b48a;align-self:center;margin-left:30px}
#abt .foe{display:flex;flex-direction:column;align-items:center;gap:4px}#abt .foe .army{font-size:30px;letter-spacing:-6px;filter:drop-shadow(0 0 4px #f30)}
#abt .bar{height:16px;border:2px solid #b48a3c;border-radius:9px;background:#5a0a06;overflow:hidden;position:relative}
#abt .bar span{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(#8fc0ff,#3a6ad0);transition:width .25s}
#abt .nums{display:flex;justify-content:space-between;font-size:12px;margin-top:3px}
#abt .clash{position:absolute;left:50%;top:60px;width:2px;height:2px}
#abt .sp{position:absolute;width:44px;height:44px;margin:-22px;border-radius:50%;background:radial-gradient(#fff,#ffd060 30%,#f0400000 70%);animation:sp .35s ease-out forwards}
@keyframes sp{from{transform:scale(.3);opacity:1}to{transform:scale(1.6);opacity:0}}
#abt .dmg{position:absolute;font:900 18px sans-serif;color:#fff;text-shadow:0 0 4px #f40,0 1px 2px #000;animation:dm .8s ease-out forwards}
@keyframes dm{from{transform:translateY(0);opacity:1}to{transform:translateY(-36px);opacity:0}}
#abt .res{text-align:center;margin-top:12px;font:900 30px/1.2 serif;opacity:0;transform:scale(2.2);transition:all .3s cubic-bezier(.2,1.6,.4,1)}
#abt .res.on{opacity:1;transform:none}#abt .res small{display:block;font-size:13px;color:#e8d8b0;margin-top:4px}
#abt .tap{text-align:center;font-size:11px;color:#9a8a70;margin-top:10px}`;
document.head.appendChild(fxCss);
const raidFx = document.createElement('div'); raidFx.id = 'raidfx'; document.body.appendChild(raidFx);
const raidBan = document.createElement('div'); raidBan.id = 'raidban'; document.body.appendChild(raidBan);
const abt = document.createElement('div'); abt.id = 'abt'; document.body.appendChild(abt);
let introPlaying = false, foes = [];
const foeTex = canvasSprite(64, 96, g => { // 敵兵の影（コード描画）：黒い鎧、赤い目、槍、たいまつ
  g.fillStyle = 'rgba(0,0,0,.35)'; g.beginPath(); g.ellipse(32, 90, 16, 5, 0, 0, 7); g.fill();
  g.fillStyle = '#1a1012'; g.beginPath(); g.moveTo(20, 88); g.lineTo(24, 50); g.lineTo(18, 34); g.lineTo(46, 34); g.lineTo(40, 50); g.lineTo(44, 88); g.closePath(); g.fill();
  g.beginPath(); g.arc(32, 26, 10, 0, 7); g.fill(); g.fillStyle = '#ff3a20'; g.fillRect(27, 24, 3, 2); g.fillRect(34, 24, 3, 2);
  g.strokeStyle = '#3a2a20'; g.lineWidth = 3; g.beginPath(); g.moveTo(50, 90); g.lineTo(52, 6); g.stroke(); g.fillStyle = '#a8a8b0'; g.beginPath(); g.moveTo(52, 0); g.lineTo(56, 10); g.lineTo(48, 10); g.fill();
  const r = g.createRadialGradient(14, 30, 1, 14, 30, 12); r.addColorStop(0, '#fff2a0'); r.addColorStop(.4, '#ff8a20'); r.addColorStop(1, '#ff300000'); g.fillStyle = r; g.beginPath(); g.arc(14, 30, 12, 0, 7); g.fill(); });
// 前線：敵が来る方角ごとに、陣の場所（遠い→近い）と、迎え撃つ場所（前線）を持つ
const FRONTS = { pass: { camp: [[30, 780], [70, 800], [110, 820]], front: [200, 865] }, river: { camp: [[30, 1220], [70, 1200], [110, 1180]], front: [200, 1135] } }; // どちらも街道の上（小物が置かれない）
const tentTex = canvasSprite(120, 90, g => { g.fillStyle = 'rgba(0,0,0,.35)'; g.beginPath(); g.ellipse(60, 84, 54, 7, 0, 0, 7); g.fill();
  g.fillStyle = '#5a1410'; g.beginPath(); g.moveTo(8, 84); g.lineTo(60, 14); g.lineTo(112, 84); g.closePath(); g.fill(); g.fillStyle = '#3a0a08'; g.beginPath(); g.moveTo(60, 14); g.lineTo(112, 84); g.lineTo(72, 84); g.closePath(); g.fill();
  g.fillStyle = '#140606'; g.beginPath(); g.moveTo(50, 84); g.lineTo(60, 52); g.lineTo(70, 84); g.fill(); g.strokeStyle = '#2a1a10'; g.lineWidth = 3; g.beginPath(); g.moveTo(60, 14); g.lineTo(60, 0); g.stroke(); g.fillStyle = '#c02a1a'; g.fillRect(60, 0, 18, 10); });
let camp = null;
// 敵兵の絵（槍兵・羽飾りの兵・フードの山賊・毛皮の斧の山賊）。読めなければコード描画の影で代用
const FOE_IMG = await Promise.all([1, 2, 3, 4].map(i => loadImage(`assets/npc/foe_${i}.webp`)));
const FOE_TEX = FOE_IMG.map(im => { if (!im) return null; const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; });
const FOEWALK_META = await fetch('assets/npc/foewalk_meta.json').then(r => r.json()).catch(() => null); // 敵の歩き（4×2の8コマ）
const FOEWALK_IMG = FOEWALK_META ? await Promise.all([1, 2, 3, 4].map(i => loadImage(`assets/npc/foewalk_${i}.webp`))) : [];
const FOEWALK_TEX = FOEWALK_IMG.map(im => { if (!im) return null; const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; });
function foeSprite(i, sc, x, y) { // i：0〜3。足元を(x,y)に置く。sc＝立ち絵（高さ360）に掛ける拡大率。歩きの絵があればそれで出す
  const k = i % 4, wt = FOEWALK_TEX[k];
  if (wt) { const M = FOEWALK_META[k], u = 360 * sc / M.h, t = wt.clone(); t.needsUpdate = true; t.repeat.set(.25, .5);
    const m = sprite3D(t, { w: M.cw, h: M.ch, ax: .5, ay: 1 }, u, x, y); m.userData.walk = { t, k }; foeFrame(m, 0, 1); return m; } // 敵は西から来る。絵は右向き（城の側）のまま使う
  const t0 = FOE_TEX[k]; if (!t0) return sprite3D(foeTex, { w: 64, h: 96, ax: .5, ay: .94 }, sc * .42 / .178, x, y);
  const im = FOE_IMG[k]; return sprite3D(t0, { w: im.width, h: im.height, ax: .5, ay: .98 }, sc, x, y); }
function foeFrame(m, f, dir) { const w = m.userData.walk; if (!w) return; w.t.offset.set((f % 4) * .25, f < 4 ? .5 : 0); if (dir) m.scale.x = Math.abs(m.scale.x) * (dir > 0 ? 1 : -1); } // 絵は右向き（城＝街の側）。左へ進むときだけ反転
function updateCamp() { // 襲撃の2週前から、敵の陣が街の外に見え、週ごとに近づく
  if (camp) { camp.forEach(c => scene.remove(c)); camp = null; }
  const r = GM.raidView(G); if (!r || r.inWeeks > 2 || G.raid) return; const F = FRONTS[r.dir]; if (!F) return;
  const [x, y] = F.camp[2 - r.inWeeks]; camp = [];
  const add = (t, meta, sc, dx, dy) => { const s = sprite3D(t, meta, sc, x + dx, y + dy); scene.add(s); camp.push(s); };
  add(tentTex, { w: 120, h: 90, ax: .5, ay: .93 }, .42, 0, 0); add(tentTex, { w: 120, h: 90, ax: .5, ay: .93 }, .34, -34, 16);
  if (TOWN.torch) add(townTex.torch || (townTex.torch = Object.assign(new THREE.Texture(TOWN.torch), { needsUpdate: true, colorSpace: THREE.SRGBColorSpace })), { w: TOWN.torch.width, h: TOWN.torch.height, ax: .5, ay: .96 }, .14, 26, 10);
  for (let i = 0; i < Math.min(6, 2 + Math.round(r.E / 10)); i++) { const s2 = foeSprite((i * 3 + 2) % 4, .15, x - 20 + i * 14 + (i % 2) * 6, y + 26 + (i % 2) * 8); scene.add(s2); camp.push(s2); }
}
function raidIntro(done) { // 空が赤くなり、陣から軍勢が街道を進み、前線で止まる。帯で名前を出してから、窓を開く
  const R = G.raid; introPlaying = true; ui.modal(null); if (camp) { camp.forEach(c => scene.remove(c)); camp = null; }
  const F = FRONTS[R.dir] || FRONTS.pass, src = F.camp[2], dst = F.front, n = Math.min(26, 6 + Math.round(R.E / 2));
  view.zoom = Math.max(view.zoom, .75); view.cx = (src[0] + dst[0]) / 2 + 120; view.cz = zOf(dst[1] + 230); clampView(); /* 前線は画面の上寄り（窓に隠れない） */
  foes.forEach(f => scene.remove(f.m)); foes = [];
  const dx = dst[0] - src[0], dy = dst[1] - src[1], L = Math.hypot(dx, dy), nx = -dy / L, ny = dx / L;
  for (let i = 0; i < n; i++) { const a = ((i % 5) - 2) * 34 + (Math.random() - .5) * 14, back = Math.floor(i / 5) * 24 + Math.random() * 10, m = foeSprite((R.boss || R.gen) && i === 0 ? 3 : Math.floor(Math.random() * 4), .165 * ((R.boss || R.gen) && i === 0 ? 1.45 : 1), src[0], src[1]); scene.add(m);
    foes.push({ m, x0: src[0] - dx / L * (60 + back) + nx * a, y0: src[1] - dy / L * (60 + back) + ny * a * .6, x1: dst[0] - dx / L * back * .8 + nx * a, y1: dst[1] - dy / L * back * .8 + ny * a * .6, d: Math.random() * .5 }); }
  raidFx.classList.add('on'); const t0 = performance.now();
  const f = now => { const t = (now - t0) / 2800;
    foes.forEach(o => { const k = Math.min(1, Math.max(0, (t - o.d * .3) / .8)), e = k * (2 - k), x = o.x0 + (o.x1 - o.x0) * e, y = o.y0 + (o.y1 - o.y0) * e, z = zOf(y); o.m.position.set(x, hgt(x, z) + (o.m.userData.walk ? 0 : Math.abs(Math.sin(now / 110 + o.d * 9)) * 2 * (k < 1)), z); if (o.m.userData.walk) foeFrame(o.m, k < 1 ? Math.floor((now + o.d * 900) / 140) % 8 : 0, o.x1 - o.x0); });
    if (t > .35 && !f.b) { f.b = 1; const fr = GM.FRONT[R.dir]; raidBan.innerHTML = `<div>${(R.boss || R.gen) ? '将軍の侵攻' : '敵襲'}<small>${R.name}・規模 ${R.E}／${fr ? fr.n + 'で迎え撃つ' : ''}</small></div>`; raidBan.className = 'on'; }
    if (t > 1.05 && !f.c) { f.c = 1; raidBan.className = 'off'; }
    if (t > 1.2) { f.done = true; introPlaying = false; done && done(); } };
  fx.push(f);
}
function endRaidFx() { raidFx.classList.remove('on'); foes.forEach(f => scene.remove(f.m)); foes = []; raidBan.className = ''; }
function autoBattle(resolveFn) { // 任せた戦闘：仲間と兵が軍勢とぶつかり、押し合いの末に結果が出る（約3秒、タップで飛ばせる）
  if (!G.raid) { ui.modal(null); return; }
  const R = G.raid, usD = GM.raidD(G), E = R.E;
  const team = Object.keys(GM.ALLY).filter(k => GM.fighter(k) && GM.joined(G, k) && !(k === 'ranka' && (G.rankaAway || !R.ranka))).slice(0, 4);
  const t = resolveFn(); // 先に結果を決め、演出をその結果に合わせる
  const good = /被害なし|完勝|勝利/.test(t) && !/敗北/.test(t), mid = /小被害|苦戦/.test(t);
  const label = good ? '勝利' : mid ? '辛勝' : /大被害|敗北|敗走/.test(t) ? '敗北' : '苦戦', col = good ? '#ffd770' : mid ? '#ffe0a0' : '#ff7a6a';
  abt.innerHTML = `<div class="st"><div class="ttl">${R.name}</div><div class="sides"><div class="us">${team.map(k => `<img src="../ally/map_${k}.png" onerror="this.src='../ally/${k}.png'">`).join('')}<span class="tr">兵 ${R.kind === 'sortie' ? R.sent : G.troops}</span></div>
    <div class="foe"><div class="army">${'💀'.repeat(Math.min(7, Math.ceil(E / 7)))}</div><span class="tr">敵 ${E}</span></div><div class="clash"></div></div>
    <div class="bar"><span style="width:50%"></span></div><div class="nums"><span>${R.kind === 'sortie' ? `戦力（兵${R.sent}）` : '防衛力'} ${Math.round(usD)}</span><span>敵の規模 ${E}</span></div>
    <div class="res" style="color:${col}">${label}<small>${t.split('：')[1] || ''}</small></div><div class="tap">タップで閉じる</div></div>`;
  const fr = GM.FRONT[R.dir]; abt.style.backgroundImage = `linear-gradient(#0a0402c8,#0a0402e8), url(assets/field/${R.dir || 'pass'}.jpg), linear-gradient(#3a2a1a,#140c06)`; abt.style.backgroundSize = 'cover'; abt.style.backgroundPosition = 'center';
  abt.querySelector('.ttl').innerHTML = `${R.name}<small style="display:block;font-size:12px;color:#e8d8b0">${fr ? fr.n : ''}</small>`;
  abt.style.display = 'flex'; const bar = abt.querySelector('.bar span'), cl = abt.querySelector('.clash'), res = abt.querySelector('.res');
  const fin = good ? 82 : mid ? 58 : 26; let i = 0, closed = false;
  const iv = setInterval(() => { i++; const w = i < 9 ? 50 + Math.sin(i * 1.7) * 18 + (fin - 50) * i / 12 : fin; bar.style.width = w + '%';
    const s = document.createElement('div'); s.className = 'sp'; s.style.left = (Math.random() - .5) * 120 + 'px'; s.style.top = (Math.random() - .5) * 60 + 'px'; cl.appendChild(s);
    const d = document.createElement('div'); d.className = 'dmg'; d.textContent = Math.round(3 + Math.random() * E / 3); d.style.left = (Math.random() - .5) * 140 + 'px'; d.style.top = (Math.random() - .5) * 40 + 'px'; cl.appendChild(d);
    setTimeout(() => { s.remove(); d.remove(); }, 800);
    if (i === 10) { res.classList.add('on'); clearInterval(iv); } }, 230);
  const close = () => { if (closed || !res.classList.contains('on')) { if (!closed) { i = 9; } return; } closed = true; abt.style.display = 'none'; abt.onclick = null; endRaidFx(); commit(t); showReport(); };
  abt.onclick = e => { e.stopPropagation(); if (!res.classList.contains('on')) { clearInterval(iv); bar.style.width = fin + '%'; res.classList.add('on'); return; } close(); };
}
// ---------- 一騎打ちの演出（仮：マップ用の絵を大きく並べ、動きはコード）----------
const dCss = document.createElement('style'); dCss.textContent = `
@font-face{font-family:'DMincho';src:url(assets/font/mincho-b.woff2?v=4) format('woff2');font-weight:700;font-display:swap}
#dsel,#duel{--u:min(.2326vw,.1073dvh);--ink:#2b1d10;--ink2:#5e4728;--gold:#a8833c;--teal:#2c6a64;--red:#a3362b;
  position:fixed;inset:0;display:none;flex-direction:column;overflow:hidden;font-family:'DMincho','Hiragino Mincho ProN','Yu Mincho',serif;font-weight:700;color:var(--ink);
  background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(760*var(--u)) auto repeat;-webkit-font-smoothing:antialiased}
#dsel{z-index:10}#duel{z-index:11}
#dsel *,#duel *{box-sizing:border-box}#dsel button,#duel button{font:inherit;color:inherit;cursor:pointer;border:0;background:none;padding:0}
#dsel .cn,#duel .cn{position:absolute;width:calc(62*var(--u));aspect-ratio:220/153;background:url(assets/ui2/corner.webp) center/contain no-repeat;pointer-events:none;z-index:1;opacity:.92}
#dsel .cn.tl,#duel .cn.tl{left:calc(4*var(--u));top:calc(4*var(--u))}#dsel .cn.tr,#duel .cn.tr{right:calc(4*var(--u));top:calc(4*var(--u));transform:scaleX(-1)}#dsel .cn.bl,#duel .cn.bl{left:calc(4*var(--u));bottom:calc(4*var(--u));transform:scaleY(-1)}#dsel .cn.br,#duel .cn.br{right:calc(4*var(--u));bottom:calc(4*var(--u));transform:scale(-1,-1)}
#dsel .dline{display:flex;align-items:center;justify-content:center;gap:calc(10*var(--u));color:var(--ink2)}
#dsel #dsel .dline::before,#dsel .dline::after{content:'';height:1px;width:calc(70*var(--u));background:linear-gradient(90deg,transparent,var(--gold))}
#dsel .dline::after{background:linear-gradient(90deg,var(--gold),transparent)}
/* ---------- 選出 ---------- */
#dsel .hero{position:relative;flex:0 0 41%;background:#222 0 0/124% auto no-repeat;-webkit-mask-image:linear-gradient(#000 88%,transparent);mask-image:linear-gradient(#000 88%,transparent)}
#dsel .hero::before{content:'';position:absolute;left:-10%;top:-6%;width:72%;height:78%;background:radial-gradient(closest-side,#f3ead6e6,#f3ead6a0 55%,transparent);pointer-events:none}
#dsel .tt{position:absolute;left:calc(26*var(--u));top:calc(30*var(--u))}
#dsel .tt small{display:block;font-size:calc(12*var(--u));letter-spacing:.12em;color:var(--ink2)}
#dsel .tt .dv0{display:block;width:calc(150*var(--u));margin:calc(3*var(--u)) 0 calc(4*var(--u))}
#dsel .tt h1{margin:0;font-size:calc(30*var(--u));font-weight:700;letter-spacing:.14em;line-height:1.15}
#dsel .tt .dv1{display:block;width:calc(170*var(--u));margin-top:calc(6*var(--u))}
#dsel .qt{position:absolute;left:calc(26*var(--u));top:43%;max-width:44%;font-size:calc(15*var(--u));line-height:1.6;letter-spacing:.04em}
#dsel .qt small{display:flex;align-items:center;gap:calc(6*var(--u));margin-top:calc(6*var(--u));font-size:calc(11*var(--u));color:var(--ink2)}
#dsel .qt small::before{content:'';width:calc(26*var(--u));height:1px;background:var(--ink2)}
#dsel .pn{position:relative;z-index:1;flex:1;min-height:0;display:flex;flex-direction:column;align-items:center;padding:0 calc(16*var(--u)) calc(52*var(--u))}
#dsel h2{margin:calc(-2*var(--u)) 0 0;font-size:calc(23*var(--u));font-weight:700;letter-spacing:.12em}
#dsel .dv{width:calc(220*var(--u));margin:calc(2*var(--u)) 0 calc(12*var(--u))}
#dsel .grid{width:100%;display:grid;grid-template-columns:1fr 1fr;gap:calc(10*var(--u));flex:0 1 auto;min-height:0;overflow-y:auto;-webkit-overflow-scrolling:touch;overscroll-behavior:contain;padding:calc(2*var(--u))} /* 仲間が増えて入りきらないときは、カードの欄だけスクロール */
#dsel.many .hero{flex-basis:30%}#dsel.many .cd{aspect-ratio:2.05}#dsel.many .dv{margin-bottom:calc(6*var(--u))}#dsel.many .cd .nm{font-size:calc(17*var(--u))}#dsel.many .go{height:calc(58*var(--u));margin-top:calc(6*var(--u))}#dsel.many .no{margin-top:calc(8*var(--u))} /* 5人以上：敵将の絵とカードを縮める */
#dsel .cd{position:relative;aspect-ratio:1.58;overflow:hidden;cursor:pointer;background:#ece2c8;border:1px solid #bba57a;box-shadow:inset 0 0 0 calc(3*var(--u)) #ece2c8,inset 0 0 0 calc(4*var(--u)) #cdb98e;transition:box-shadow .15s,background .15s}
#dsel .cd img{position:absolute;left:0;top:0;height:100%;width:60%;object-fit:cover;object-position:50% 10%;-webkit-mask-image:linear-gradient(90deg,#000 62%,transparent);mask-image:linear-gradient(90deg,#000 62%,transparent)}
#dsel .cd .tx{position:absolute;right:calc(8*var(--u));top:0;bottom:0;width:44%;display:flex;flex-direction:column;justify-content:center;align-items:center}
#dsel .cd .nm{font-size:calc(19*var(--u));letter-spacing:.1em;white-space:nowrap}
#dsel .cd .ln{width:100%;height:calc(9*var(--u));margin:calc(4*var(--u)) 0;background:linear-gradient(var(--ink2),var(--ink2)) center/100% 1px no-repeat;position:relative;opacity:.7}
#dsel .cd .ln::after{content:'';position:absolute;left:50%;top:50%;width:calc(6*var(--u));height:calc(6*var(--u));background:#ece2c8;border:1px solid var(--ink2);transform:translate(-50%,-50%) rotate(45deg)}
#dsel .cd .pw{font-size:calc(13.5*var(--u));white-space:nowrap;color:var(--ink2)}#dsel .cd .pw b{font-size:1.1em;color:var(--ink)}
#dsel .cd.on{background:#dfe5cc;border-color:#58775a;box-shadow:inset 0 0 0 calc(3*var(--u)) #dfe5cc,inset 0 0 0 calc(4*var(--u)) #8aa483,0 0 calc(10*var(--u)) #5a8a5f66}
#dsel .cd .ck{display:none;position:absolute;right:calc(7*var(--u));top:calc(7*var(--u));width:calc(26*var(--u));height:calc(26*var(--u));border-radius:50%;background:#2f4a3c;border:1px solid #c9d6bb;color:#f2f0e0;align-items:center;justify-content:center;font-size:calc(15*var(--u))}
#dsel .cd.on .ck{display:flex}
#dsel .hint{margin-top:auto;font-size:calc(12.5*var(--u));letter-spacing:.06em}
#dsel .go{width:88%;height:calc(66*var(--u));margin-top:calc(10*var(--u));background:url(assets/ui2/btn_teal.webp) center/100% 100% no-repeat;color:#f3ead2;font-size:calc(20*var(--u));letter-spacing:.16em;text-shadow:0 1px 2px #0006}
#dsel .go:active{filter:brightness(1.12)}
#dsel .no{margin-top:calc(12*var(--u));font-size:calc(13*var(--u));letter-spacing:.1em;color:var(--ink2);border-bottom:1px solid #8a7450;padding:0 calc(10*var(--u)) calc(3*var(--u));cursor:pointer}
#dsel::after{content:'';position:absolute;left:0;right:0;bottom:0;height:calc(46*var(--u));background:url(assets/ui2/vine.webp) center bottom/100% 100% no-repeat;opacity:.85;pointer-events:none}
/* ---------- 戦闘 ---------- */
#duel .hd{position:relative;flex:0 0 14.5%;display:flex;align-items:flex-end;justify-content:space-between;gap:calc(26*var(--u));padding:0 calc(14*var(--u)) calc(12*var(--u))}
#duel .ct{position:absolute;left:0;right:0;top:calc(14*var(--u));display:flex;flex-direction:column;align-items:center;pointer-events:none}
#duel .ct small{font-size:calc(11*var(--u));letter-spacing:.14em;color:var(--ink2)}#duel .ct img{width:calc(120*var(--u));margin:calc(1*var(--u)) 0 calc(2*var(--u))}
#duel .ct h1{margin:0;font-size:calc(26*var(--u));font-weight:700;letter-spacing:.16em;line-height:1.1}
#duel .sd{display:flex;align-items:center;gap:calc(8*var(--u));flex:1;min-width:0}#duel .sd.r{flex-direction:row-reverse}
#duel .fw{position:relative;flex:0 0 calc(66*var(--u));width:calc(66*var(--u));aspect-ratio:290/281}
#duel .fw .fc{position:absolute;left:50%;top:50%;width:72%;height:74%;transform:translate(-50%,-50%);border-radius:50%;object-fit:cover}
#duel .fw .fc.foe{background:#c9b68a 50% 8%/220% no-repeat}
#duel .fw .rg{position:absolute;inset:0;background:url(assets/ui2/ring.webp) center/100% 100% no-repeat;pointer-events:none}
#duel .hb{flex:1;min-width:0;padding-bottom:calc(6*var(--u))}#duel .sd.r .hb{text-align:right}
#duel .nm{font-size:calc(14.5*var(--u));letter-spacing:.08em;margin-bottom:calc(5*var(--u));white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#duel .hp{height:calc(10*var(--u));padding:1px;background:#2a1e12;border:1px solid #8c6c34;box-shadow:0 0 0 1px #e9dcbcaa;position:relative}
#duel .hp b{position:absolute;top:1px;bottom:1px;left:1px;max-width:calc(100% - 2px);background:linear-gradient(#5aa59a,#2c6a64 60%,#24564f);transition:width .45s cubic-bezier(.3,.8,.3,1)}
#duel .sd.r .hp b{left:auto;right:1px;background:linear-gradient(#d4705c,#a3362b 60%,#86281f)}
#duel .stage{position:relative;flex:1;min-height:0;background:#222;overflow:hidden;box-shadow:inset 0 calc(8*var(--u)) calc(10*var(--u)) calc(-6*var(--u)) #0005}
#duel .stage::after{content:'';position:absolute;inset:0;background:linear-gradient(transparent 70%,#0003);pointer-events:none}
#duel .f{position:absolute;bottom:15%;height:34%;transition:transform .18s ease-out,filter .08s;z-index:2}
#duel .f .sp{pointer-events:none}#duel .f .ly{position:absolute;background-repeat:no-repeat;clip-path:inset(1px);will-change:background-position}#duel .f img{height:100%}
#duel .f .gs{position:absolute;left:50%;bottom:-3%;width:120%;height:9%;transform:translateX(-50%);border-radius:50%;background:radial-gradient(closest-side,#000b,#0006 55%,#0000);pointer-events:none}
#duel .f .sp .sh{position:absolute;inset:0;pointer-events:none;-webkit-mask-repeat:no-repeat;mask-repeat:no-repeat;background:linear-gradient(100deg,#fff3 0%,#0000 34%,#0000 52%,#0a0e2a66 100%),linear-gradient(180deg,#0000 55%,#1a0f0a55 100%)} /* 味方の陰（2026-10-29 濃すぎたので約6割に） */
#duel .R .sp .sh{background:linear-gradient(260deg,#fff3 0%,#0000 34%,#0000 48%,#0a0e2aa6 100%),linear-gradient(180deg,#0000 50%,#1a0f0a8c 100%)}
#duel .cam,#duel .f{will-change:transform}
#duel .ld{position:absolute;inset:0;z-index:6;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:calc(10*var(--u));background:#0007;color:#f3e7c8;font-size:calc(15*var(--u));letter-spacing:.15em;transition:opacity .3s}#duel .ld.out{opacity:0}
#duel .ld i{width:50%;height:calc(4*var(--u));background:#0008;border:1px solid #a8833c}#duel .ld u{display:block;height:100%;width:0;background:#d9b878;transition:width .15s}
#duel .L{left:9%}#duel .R{right:8%}
#duel .cam{position:absolute;inset:0;transform-origin:50% 72%;transition:transform .26s cubic-bezier(.2,.7,.3,1)}#duel .cam .bg{position:absolute;inset:-2%;background:#222 center 66%/cover no-repeat}
#duel .f.chg .sp,#duel .f.chg img{animation:dchg .45s ease-in-out infinite alternate}@keyframes dchg{from{filter:drop-shadow(0 0 calc(3*var(--u)) #ff4a2a) drop-shadow(0 0 calc(8*var(--u)) #b0100088)}to{filter:drop-shadow(0 0 calc(5*var(--u)) #ff6a3a) drop-shadow(0 0 calc(14*var(--u)) #c01000aa)}}#duel .f.ko .sp,#duel .f.ko img{filter:grayscale(.7) brightness(.62)!important;transition:filter .9s .3s}#duel .stage.kof::before{content:'';position:absolute;inset:0;background:#fff3d6;z-index:9;pointer-events:none;animation:kof .55s ease-out forwards}@keyframes kof{from{opacity:.7}to{opacity:0}}
#duel .f.hit{animation:fhit .32s linear}#duel .f.hit .sp,#duel .f.hit img{filter:sepia(.35) saturate(2.2) hue-rotate(-25deg) brightness(1.06)!important}
@keyframes fhit{0%,100%{translate:0 0}20%{translate:-4px 0}45%{translate:4px 0}70%{translate:-2px 0}}
#duel .say{position:absolute;bottom:57%;max-width:52%;min-width:28%;padding:calc(14*var(--u)) calc(14*var(--u)) calc(10*var(--u));background:#fbf6e9;border:1.5px solid #3b2a16;border-radius:calc(12*var(--u));box-shadow:0 calc(3*var(--u)) 0 #3b2a1622,0 calc(4*var(--u)) calc(12*var(--u)) #0004;
  font-size:calc(15.5*var(--u));line-height:1.45;letter-spacing:.03em;opacity:0;transform:scale(.6);transition:opacity .12s,transform .22s cubic-bezier(.2,1.5,.4,1);pointer-events:none;z-index:4}
#duel .say::after{content:'';position:absolute;bottom:calc(-9*var(--u));width:calc(14*var(--u));height:calc(14*var(--u));background:#fbf6e9;border:1.5px solid #3b2a16;border-top:0;border-left:0;transform:rotate(45deg)}
#duel .say.l{left:4%;transform-origin:22% 110%}#duel .say.l::after{left:22%}#duel .say.r{right:4%;transform-origin:78% 110%}#duel .say.r::after{right:22%}
#duel .say.on{opacity:1;transform:none}
#duel .say small{position:absolute;top:calc(-10*var(--u));left:calc(10*var(--u));padding:calc(1*var(--u)) calc(8*var(--u));background:#3b2a16;color:#f3e7c8;border-radius:calc(3*var(--u));font-size:calc(10*var(--u));letter-spacing:.1em;line-height:1.6}
#duel .say.r small{left:auto;right:calc(10*var(--u))}#duel .say.foe{border-color:#6e1f17}#duel .say.foe small{background:#6e1f17}
#duel .say.big{font-size:calc(18*var(--u));color:#7a1d14;max-width:66%}
#duel .num{position:absolute;font:italic 700 calc(34*var(--u)) Georgia,'DMincho',serif;color:#fff3d2;-webkit-text-stroke:calc(1.2*var(--u)) #4a1c08;text-shadow:0 calc(2*var(--u)) 0 #4a1c08,0 0 calc(10*var(--u)) #ff9a3c;animation:dnum .9s cubic-bezier(.2,.8,.3,1) forwards;pointer-events:none;z-index:5}
@keyframes dnum{0%{transform:translateY(0) scale(1.6);opacity:1}25%{transform:translateY(-6px) scale(1)}100%{transform:translateY(-44px);opacity:0}}
#duel .slash{position:absolute;width:42%;height:calc(5*var(--u));top:52%;background:linear-gradient(90deg,#fff0,#fff,#ffe9a8,#fff0);box-shadow:0 0 calc(14*var(--u)) #ffd060;transform:rotate(-20deg) scaleX(0);animation:dsl .24s ease-out forwards;z-index:5}
@keyframes dsl{to{transform:rotate(-20deg) scaleX(1);opacity:0}}
#duel .cut{position:absolute;left:0;bottom:3%;display:flex;flex-direction:column;align-items:flex-start;padding:calc(6*var(--u)) calc(26*var(--u)) calc(7*var(--u)) calc(16*var(--u));background:linear-gradient(90deg,#0d2b28e6,#163f3bcc 70%,#163f3b00);border-top:1px solid #d8b86a;transform:translateX(-110%) skewX(-12deg);opacity:0;transition:transform .22s cubic-bezier(.2,.9,.3,1),opacity .22s;z-index:6;color:#f6ecd0;pointer-events:none}
#duel .cut.on{transform:skewX(-12deg);opacity:1}#duel .cut img{display:none}#duel .cut div{font:italic 700 calc(30*var(--u))/1 Georgia,'Times New Roman',serif;letter-spacing:.06em;color:#f3d98a;text-shadow:0 0 calc(10*var(--u)) #e9c45a99,0 calc(2*var(--u)) 0 #0008}#duel .cut small{display:block;margin-top:calc(3*var(--u));font-family:inherit;font-size:calc(11*var(--u));font-weight:700;line-height:1.3;font-style:normal;white-space:nowrap;letter-spacing:.12em;color:#e6d6aa;text-shadow:none}#duel .cut div::after{content:'';display:block;height:2px;margin-top:calc(4*var(--u));background:linear-gradient(90deg,#f3d98a,#f3d98a00)}
#duel .ft{position:relative;z-index:2;flex:0 0 25%;display:flex;flex-direction:column;align-items:center;justify-content:space-evenly;padding:calc(14*var(--u)) calc(18*var(--u)) calc(14*var(--u))}
#duel .ft::before{content:'';position:absolute;left:0;right:0;top:calc(-20*var(--u));height:calc(40*var(--u));background:url(assets/ui2/vine.webp) center/100% 100% no-repeat;pointer-events:none}
#duel .ln{display:flex;justify-content:space-between;gap:calc(8*var(--u));width:100%;min-height:calc(40*var(--u))}
#duel .ln p{margin:0;flex:1;max-width:50%;padding:calc(12*var(--u)) calc(10*var(--u)) calc(6*var(--u));position:relative;background:#fbf6e9;border:1.5px solid #3b2a16;border-radius:calc(8*var(--u));font-size:calc(13.5*var(--u));line-height:1.35;color:#2b1d10;opacity:0;transform:translateY(calc(4*var(--u)));transition:opacity .15s,transform .15s}
#duel .ln p.r{text-align:right;border-color:#6e1f17}#duel .ln p.on{opacity:1;transform:none}#duel .ln p.big{color:#7a1d14;font-size:calc(15*var(--u))}
#duel .ln p small{position:absolute;top:calc(-9*var(--u));left:calc(8*var(--u));padding:0 calc(7*var(--u));background:#3b2a16;color:#f3e7c8;border-radius:calc(3*var(--u));font-size:calc(10*var(--u));letter-spacing:.1em;line-height:1.6}
#duel .ln p.r small{left:auto;right:calc(8*var(--u));background:#6e1f17}
#duel .ft h3{margin:0;font-size:calc(18*var(--u));font-weight:700;letter-spacing:.3em;padding-left:.3em}
#duel .blr{display:flex;align-items:center;gap:calc(10*var(--u));width:100%;font-size:calc(12.5*var(--u));letter-spacing:.06em}
#duel .bal{flex:1;height:calc(12*var(--u));padding:1px;background:#2a1e12;border:1px solid #8c6c34;box-shadow:0 0 0 1px #e9dcbcaa;position:relative}
#duel .bal::before{content:'';position:absolute;inset:1px;background:linear-gradient(#d4705c,#a3362b 60%,#86281f)}
#duel .bal b{position:absolute;left:1px;top:1px;bottom:1px;background:linear-gradient(#5aa59a,#2c6a64 60%,#24564f);transition:width .45s cubic-bezier(.3,.8,.3,1)}
#duel .bal u{position:absolute;top:50%;width:calc(14*var(--u));height:calc(14*var(--u));background:linear-gradient(135deg,#f6e2a0,#c99a3c);border:1px solid #5e4320;transform:translate(-50%,-50%) rotate(45deg);transition:left .45s cubic-bezier(.3,.8,.3,1)}
#duel .row{display:flex;align-items:center;justify-content:center;gap:calc(12*var(--u));width:100%}
#duel .stt{font-size:calc(14*var(--u));letter-spacing:.08em;min-width:calc(120*var(--u));text-align:center;white-space:nowrap}#duel .stt em{font-style:normal;color:var(--ink2);font-size:.85em;margin-right:.6em}#duel .stt.hv{color:var(--red)}
#duel .pips{display:flex;gap:calc(7*var(--u))}
#duel .pips i{position:relative;width:calc(12*var(--u));height:calc(12*var(--u));border:1px solid #7d6438;background:#efe5cb;transform:rotate(45deg);transition:background .2s}
#duel .pips i.h{border-color:var(--red);box-shadow:0 0 0 1px #a3362b55}
#duel .pips i.w{background:var(--teal);border-color:#173d39}#duel .pips i.l{background:var(--red);border-color:#5e1a13}
#duel .pips i.cur{background:#f2cf6a;border-color:#7a5418;box-shadow:0 0 calc(6*var(--u)) #e8b030}
#duel .bt{display:flex;gap:calc(8*var(--u));width:100%;align-items:center}
#duel .bt .sp2,#duel .bt .sk{flex:0 0 26%;height:calc(48*var(--u));background:url(assets/ui2/btn_cream.webp) center/100% 100% no-repeat;font-size:calc(14*var(--u));letter-spacing:.08em;white-space:nowrap}
#duel .go2{flex:1;position:relative;height:calc(70*var(--u));background:url(assets/ui2/btn_teal.webp) center/100% 100% no-repeat;color:#f3ead2;text-shadow:0 1px 2px #0006;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden}
#duel .go2 b{font-size:calc(22*var(--u));font-weight:700;letter-spacing:.3em;padding-left:.3em;line-height:1.2}#duel .go2 small{font-size:calc(10.5*var(--u));letter-spacing:.06em;color:#e3d7b4}
#duel .go2 em{position:absolute;right:calc(20*var(--u));top:calc(4*var(--u));font-style:normal;font-size:calc(9.5*var(--u));border:1px solid #d8b86acc;border-radius:calc(8*var(--u));padding:0 calc(6*var(--u));background:#173f3b;color:#f3e2b0;letter-spacing:.04em;line-height:1.6;text-shadow:none}
#duel .go2 .tm{position:absolute;left:14%;right:14%;bottom:calc(9*var(--u));height:calc(2*var(--u));background:#0003}#duel .go2 .tm b{display:block;height:100%;width:0;padding:0;background:#f0cd70;letter-spacing:0}
#duel .go2.ready{animation:dgo .7s infinite alternate}@keyframes dgo{to{filter:drop-shadow(0 0 calc(7*var(--u)) #ffd060) brightness(1.12)}}
#duel .go2.used{filter:grayscale(.85) brightness(.82);animation:none}
#duel .res{position:absolute;inset:0;display:none;align-items:center;justify-content:center;background:#0006;z-index:9;cursor:pointer}
#duel .res.on{display:flex}
#duel .res .bd{width:100%;padding:calc(22*var(--u)) 0 calc(18*var(--u));display:flex;flex-direction:column;align-items:center;background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(760*var(--u)) auto;border-top:1px solid var(--gold);border-bottom:1px solid var(--gold);box-shadow:0 0 calc(30*var(--u)) #0008;animation:dres .35s cubic-bezier(.2,1.3,.4,1)}
@keyframes dres{from{transform:scaleY(0);opacity:0}}
#duel .res .k{font-size:calc(12*var(--u));letter-spacing:.3em;color:var(--ink2)}
#duel .res h2{margin:calc(2*var(--u)) 0;font-size:calc(40*var(--u));font-weight:700;letter-spacing:.3em;padding-left:.3em}
#duel .res h2.w{color:var(--teal)}#duel .res h2.l{color:var(--red)}
#duel .res img{width:calc(200*var(--u))}#duel .res p{margin:calc(6*var(--u)) 0 0;font-size:calc(13*var(--u));letter-spacing:.08em}#duel .res p small{display:block;margin-top:calc(8*var(--u));font-size:calc(11*var(--u));color:var(--ink2)}
#duel.shake .stage{animation:dsh .25s}@keyframes dsh{25%{transform:translate(-5px,3px)}75%{transform:translate(5px,-3px)}}`;
document.head.appendChild(dCss);
const duelEl = document.createElement('div'); duelEl.id = 'duel'; document.body.appendChild(duelEl);
const foeURL = FOE_IMG[3] ? 'assets/npc/foe_4.webp' : foeTex.image.toDataURL();
// 大将戦の攻撃モーション（動画由来の24コマ）。ある仲間だけ。ない仲間は立ち絵のまま
const DUEL_CLIP = await fetch('../ally/duel_meta.json?v=8').then(r => r.json()).catch(() => ({})); // 仲間ごとの攻撃モーション一覧
// 一騎打ちの絵の先読み：読み込みに加えて decode まで済ませ、Image を持ち続ける（切り替えの瞬間に消える・カクつくのを防ぐ）
const IMGHOLD = new Map();
const holdImg = src => { if (!IMGHOLD.has(src)) { const im = new Image(); im.src = src; IMGHOLD.set(src, (im.decode ? im.decode() : new Promise(r => { im.onload = r; })).catch(() => {}).then(() => im)); } return IMGHOLD.get(src); };
const duelSrcs = (k, look) => [...(DUEL_CLIP[k] || []).map(c => `../ally/${c.f}`), ...(G && G.raid && (G.raid.boss || G.raid.gen) ? (DUEL_CLIP[k + '_ult'] || []).map(c => `../ally/${c.f}`) : []), ...(runClipOf(k) ? [`../ally/${runClipOf(k).f}`] : []),
  ...(look ? [...(FOEDUEL[look] || []).map(c => `assets/npc/${c.f}`), ...(foeRunOf(look) ? [`assets/npc/${foeRunOf(look).f}`] : [])] : [])];
const duelWarm = k => duelSrcs(k, G && G.raid ? foeLook() : null).forEach(holdImg);
const SIDE_ALLY = await fetch('../ally/side_meta.json?v=3').then(r => r.json()).catch(() => ({})); // 仲間の横向きの走り（右向き）
const SIDE_FOE = await fetch('assets/npc/side_meta.json').then(r => r.json()).catch(() => ({}));  // 敵の横向きの歩き（左向き）
const runClipOf = k => SIDE_ALLY['run_' + k] || SIDE_ALLY['walk_' + k] || null, foeRunOf = look => SIDE_FOE['walk_' + look] || null;
const FOEDUEL = await fetch('assets/npc/foeduel_meta.json?v=2').then(r => r.json()).catch(() => ({})); // 敵将の攻撃モーション（見た目の番号ごと）
const foeLook = () => G.raid && (G.raid.boss || G.raid.gen) ? 4 : G.raid && G.raid.E >= 30 ? 2 : (G.raid && G.raid.w % 2 ? 3 : 1); // 隊長＝槍兵かフードの山賊（週で入れ替え）、副官＝羽飾りの兵、将軍＝斧の山賊
const FOLLOW = 380; // 当たりのあと、振り抜きを見せる長さ（ミリ秒）
function clipActor(el, sp, clips, base, T, run, runBase) { // 動画由来の連番を、枠(el)の中に出す。立ち姿の中心を揃え、足元は枠の下端。run＝横向きの走り（あれば）
  // 連番ごとに層（div）を最初に全部作り、切り替えは表示/非表示だけ（絵の差し替えで GPU への載せ直しが起きて、つなぎで止まるのを防ぐ）
  // コマ送りは画面の描画（requestAnimationFrame）に合わせる。タイマーを大量に積まない
  const c0 = clips[0]; if (!c0) return null; let order = [];
  el.style.width = c0.idle.w * (el.clientHeight / c0.idle.h) + 'px'; Object.assign(sp.style, { position: 'absolute', inset: '0', background: 'none' });
  const gs = document.createElement('i'); gs.className = 'gs'; el.insertBefore(gs, sp); // 足元の影
  const mk = (url, cols, rows, cw, ch, left, bottom, P) => { const L = document.createElement('div'); L.className = 'ly'; const sh = document.createElement('i'); sh.className = 'sh'; L.appendChild(sh); // P＝詰め直したシート（{fr, k, sw, sh}、tools/pack_trim.py）
    const size = P ? `${P.sw * P.k}px ${P.sh * P.k}px` : `${cols * cw}px ${rows * ch}px`; Object.assign(L.style, { left: left + 'px', bottom: bottom + 'px', width: cw + 'px', height: ch + 'px', backgroundImage: url, backgroundSize: size });
    sh.style.webkitMaskImage = sh.style.maskImage = url; sh.style.webkitMaskSize = sh.style.maskSize = size; sp.appendChild(L);
    return { L, set(i) { let ps;
      if (P) { const r = P.fr[i], k = P.k; Object.assign(L.style, { left: left + r[4] * k + 'px', bottom: bottom + (ch - (r[5] + r[3]) * k) + 'px', width: r[2] * k + 'px', height: r[3] * k + 'px' }); ps = `${-r[0] * k}px ${-r[1] * k}px`; } // その矩形を、元のコマの位置＋ずれに置く
      else ps = `${-(i % cols) * cw}px ${-Math.floor(i / cols) * ch}px`;
      L.style.backgroundPosition = ps; sh.style.webkitMaskPosition = sh.style.maskPosition = ps; } }; };
  const H = el.clientHeight, W2 = el.clientWidth / 2;
  const lay = clips.map(c => { const k = H / c.idle.h; return mk(`url(${base}${c.f})`, c.cols, c.rows || 4, c.cw * k, c.ch * k, W2 - (c.idle.x + c.idle.w / 2) * k, -(c.pad ?? 2.8) * k, c.fr ? { fr: c.fr, k, sw: c.sw, sh: c.sh } : null); });
  const runLay = run ? (() => { const k = H * .97 / run.ph; return mk(`url(${runBase}${run.f})`, run.cols, Math.ceil(run.n / run.cols), run.cw * k, run.ch * k, W2 - run.ax * k, -(run.ch - run.ay) * k); })() : null;
  let curL = null, seq = null, raf = 0;
  const show = Lo => { if (curL === Lo) return; if (curL) curL.L.style.visibility = 'hidden'; curL = Lo; Lo.L.style.visibility = 'visible'; };
  [...lay, runLay].forEach(x => x && (x.L.style.visibility = 'hidden')); show(lay[0]); lay[0].set(0);
  const tick = now => { raf = 0; if (!seq || !el.isConnected) return; const t = now - seq.t0; // seq：{ Lo, ts（各コマの開始ミリ秒）, end, loop, done }
    if (t < 0) { const p = seq.prev; if (p) { show(p.Lo); p.Lo.set(Math.floor((now - p.t0) / p.step) % p.n); } raf = requestAnimationFrame(tick); return; } // 始まるまでは、前の走りを回し続ける
    if (seq.loop) { show(seq.Lo); seq.Lo.set(Math.floor(t / seq.step) % seq.n); }
    else { if (t >= seq.end) { const d = seq.done; seq = null; d && d(); return; } let i = 0; while (i + 1 < seq.ts.length && seq.ts[i + 1] <= t) i++; show(seq.Lo); seq.Lo.set(i); }
    raf = requestAnimationFrame(tick); };
  const start = (q, at) => { const prev = seq && seq.loop ? seq : null; seq = { ...q, prev, t0: performance.now() + at }; if (!raf) raf = requestAnimationFrame(tick); };
  const idle = () => { seq = null; show(lay[0]); lay[0].set(0); };
  return { reset: idle,
    run(ms, rate = 1) { if (!runLay) return false; start({ Lo: runLay, loop: true, step: Math.max(28, run.durs[0] / rate), n: run.n }, 0); T(() => { if (seq && seq.loop) seq = null; }, ms + 200); return true; }, // 走りのコマを回す（攻撃が始まれば上書き）
    play(at, tame = 0) { // at（今からのミリ秒）で振りかぶりを始め、hold のコマで tame ミリ秒止める（溜め）。返り値：使った動きと、当たりの時刻
      // 速さはコマごとに変える：当たりまでは元の時間を 1/5 に（16〜35ms。全部のコマを見せる＝高速再生）、溜めは hold で止める、振り抜きは 1/2.2 で FOLLOW まで
      const ui = clips.findIndex(c => c.ult); let ci; // ult＝専用の止めの大技（ランカの星震）。普段の攻撃からは選ばない
      if (tame === 'ult' && ui >= 0) ci = ui; else { if (!order.length) order = clips.map((_, i) => i).filter(i => !clips[i].ult).sort(() => Math.random() - .5); ci = order.pop(); }
      const c = clips[ci], U = !!c.ult; if (U) tame = 0;
      const ts = []; let t = 0; c.durs.forEach((d, fi) => { ts.push(t); t += U ? d / 1.15 : fi < c.hit ? Math.max(16, Math.min(35, d / 5)) : d / 2.2; if (fi === (c.hold ?? c.hit - 1)) t += tame; }); // 専用の大技は、溜め・回転・着地をほぼ元の速さで見せる
      const end = U ? t : Math.min(t, ts[c.hit] + FOLLOW);
      start({ Lo: lay[ci], ts, end, done: idle }, at);
      return { c, hitAt: at + ts[c.hit] }; } };
}
const HUMAN = { mina: 181, sera: 181, ranka: 174, garou: 196, lily: 192, sol: 200, f1: 200, f2: 182, f3: 194, f4: 182 }; /* 2026-10-30 ゲーム全体の背の高さ（battle/core.js の HEIGHT と同じ比。×0.86 で、一騎打ち・任せた戦闘の画面の大きさは従来並み） */ // 見た目の背の高さ：一騎打ちと戦場の大きさをこれで揃える。槍の穂先・兜の飾りが測った高さに入る絵は大きめの値（並べて目で合わせた値）
const duelSel = document.createElement('div'); duelSel.id = 'dsel'; document.body.appendChild(duelSel);
const bustBG = (look, duel) => { const g = G.raid && G.raid.gen; const n = g ? 'g' + g + (g === 6 && duel ? 'b' : '') : look; return `url(assets/npc/bust_${n}.webp),url(assets/npc/bust_${look}.webp)`; }; /* 大公（第6章）は、一騎打ちで悪魔の姿（g6b） */ /* 章の将軍は bust_g<章>.webp（無ければ従来の胸像） */
const duelRank = () => G.raid && (G.raid.boss || G.raid.gen) ? 'boss' : G.raid && G.raid.E >= 30 ? 'vice' : 'cap';
const pickOf = a => a[Math.floor(Math.random() * a.length)];
function playDuel(k, done) { // 画面いっぱいの一騎打ち。五合の勝負（先に3合）。鬨の声は1回（作戦室で増える）：大技の合に使えば見切り、通常の合なら強化
  const R = G.raid, A = GM.ALLY[k], F = GM.foeGeneral(G), look = foeLook(), plan = GM.duelPlan(G, k), AL = GM.DUEL_LINES[k] || GM.DUEL_LINES.mina, FL = GM.DUEL_LINES[duelRank()];
  duelEl.style.display = 'flex';
  const pipsHtml = [0, 1, 2, 3, 4].map(i => `<i class="${plan.heavy.includes(i) ? 'h' : ''}"></i>`).join('');
  duelEl.innerHTML = `<div class="hd"><i class="cn tl"></i><i class="cn tr"></i><div class="sd"><div class="fw"><img class="fc" src="${faceRaw[k]}"><i class="rg"></i></div><div class="hb"><div class="nm">${A.n}</div><div class="hp"><b style="width:100%"></b></div></div></div>
    <div class="ct"><small>第${R.w || G.week}週</small><img src="assets/ui2/divider2.webp"><h1>一騎打ち</h1></div>
    <div class="sd r"><div class="fw"><div class="fc foe" style="background-image:url(assets/npc/foe_${look}.webp)"></div><i class="rg"></i></div><div class="hb"><div class="nm">${F.n}</div><div class="hp"><b style="width:100%"></b></div></div></div></div>
    <div class="stage"><div class="cam"><div class="bg" style="background-image:url(assets/field/duel.jpg),url(assets/field/${R.dir || 'pass'}.jpg)"></div>
      <div class="f L" style="height:${27 * (HUMAN[k] || 165) / 170}%">${(DUEL_CLIP[k] || []).length ? `<div class="sp"></div>` : `<img src="../ally/${k}.png">`}</div><div class="f R" style="height:${27 * (HUMAN['f' + look] || 178) / 170}%">${(FOEDUEL[look] || []).length ? `<div class="sp"></div>` : `<img src="assets/npc/foe_${look}.webp">`}</div>
      </div><div class="cut"><img src="${faceURL[k]}"><div></div></div></div>
    <div class="ft"><i class="cn bl"></i><i class="cn br"></i><div class="ln"><p class="l"></p><p class="r foe"></p></div><h3>戦況</h3><div class="blr"><span>自軍</span><div class="bal"><b style="width:50%"></b><u style="left:50%"></u></div><span>敵軍</span></div>
      <div class="row"><div class="pips">${pipsHtml}</div><div class="stt">間合いを測る</div></div>
      <div class="bt"><button class="sp2">▶▶ 速度 ×1</button><button class="go2"><b>鬨の声</b><small>次の一合を強化</small><em>残り${GM.orders(G)}回</em><i class="tm"><b></b></i></button><button class="sk">スキップ ›</button></div></div>
    <div class="res"></div>`;
  const $ = q => duelEl.querySelector(q), L = $('.L'), Rf = $('.R'), hl = $('.sd:not(.r) .hp b'), hr = $('.sd.r .hp b'), pips = [...duelEl.querySelectorAll('.pips i')], tm = $('.tm b'), gb = $('.go2'), stt = $('.stt'), bal = $('.bal b'), balu = $('.bal u'), stage = $('.stage'), cam = $('.cam');
  let timers = [], spd = 1, hpL = 100, hpR = 100, aw = 0, fw = 0, nextI = 0, left = GM.orders(G), used = left <= 0, armed = false, inWin = false, over = false, winT = null, cur = -1;
  let chg = null; const stopChg = () => { if (chg) { chg.stop(); chg = null; } }; // 大技の構えの気配（fx_slash.js chargeFX）
  const T = (f, ms) => { const t = setTimeout(f, ms); timers.push(t); return t; }, D = ms => ms / spd;
  const actL = clipActor(L, L.querySelector('.sp') || document.createElement('div'), [...(DUEL_CLIP[k] || []), ...((R.boss || R.gen) ? DUEL_CLIP[k + '_ult'] || [] : [])], '../ally/', T, runClipOf(k), '../ally/');
  const actR = clipActor(Rf, Rf.querySelector('.sp') || document.createElement('div'), FOEDUEL[look] || [], 'assets/npc/', T, foeRunOf(look), 'assets/npc/');
  const sayT = {}; const say = (side, text, ms = 1700, big = false) => { const e = $('.ln .' + side); /* 台詞は舞台に重ねず、下の帯（戦況の上の段）に出す */ clearTimeout(sayT[side]); e.classList.remove('on'); void e.offsetWidth; e.classList.toggle('big', big); e.innerHTML = `<small>${side === 'l' ? A.n : F.n}</small>${text}`; e.classList.add('on'); sayT[side] = setTimeout(() => e.classList.remove('on'), ms); timers.push(sayT[side]); };
  const upd = () => { hl.style.width = hpL + '%'; hr.style.width = hpR + '%'; const b = Math.max(6, Math.min(94, 50 + (hpL - hpR) / 2)); bal.style.width = b + '%'; balu.style.left = b + '%'; word = b > 62 ? '優勢' : b < 38 ? '劣勢' : '拮抗'; };
  let word = '拮抗'; const msg = (html, hv = false) => { stt.innerHTML = html; stt.classList.toggle('hv', hv); };
  const apply = (i, r) => { if (r.ally) { aw++; hpR = Math.max(0, hpR - r.dmg); } else { fw++; hpL = Math.max(0, hpL - r.dmg); } nextI = i + 1; pips[i].classList.remove('cur'); pips[i].classList.add(r.ally ? 'w' : 'l'); };
  const finish = () => { if (over) return; over = true; stopChg(); (aw >= 3 ? Rf : L).classList.add('ko'); if (window.__duelLog) console.log('DUEL finish aw=' + aw + ' fw=' + fw + ' pips=' + pips.map(p => p.className).join('|') + ' dom=' + pips[0].isConnected); const win = aw >= 3; GM.duelSet(G, k, win); if (win) hpR = 0; else hpL = 0; upd(); gb.classList.remove('ready'); msg(win ? '勝負あり' : '勝負あり'); tm.style.width = '0%';
    say(win ? 'l' : 'r', pickOf((win ? AL : FL).win), 2600); say(win ? 'r' : 'l', pickOf((win ? FL : AL).lose), 2600);
    T(() => { const r = $('.res'); r.innerHTML = `<div class="bd"><div class="k">一騎打ち</div><h2 class="${win ? 'w' : 'l'}">${win ? '勝利' : '敗北'}</h2><img src="assets/ui2/divider2.webp"><p>${win ? `${A.n}が${F.n}を討ち取った。戦況が有利になる` : `${A.n}が敗れた。戦況が不利になる`}<small>タップで続ける</small></p></div>`; r.classList.add('on');
      r.onclick = e => { e.stopPropagation(); if (!r.classList.contains('on')) return; timers.forEach(clearTimeout); if (actL) actL.reset(); if (actR) actR.reset(); duelEl.style.display = 'none'; duelEl.innerHTML = ''; srcs.forEach(sr => IMGHOLD.delete(sr)); /* 使い終わった絵を手放す（読み込んだ画像と、画面の層） */ done(); }; }, 1900); };
  // カメラ：走り出した側に寄って追いかける → 攻撃で二人がぎりぎり収まる大きさまで引く → 元の位置へ戻りながら引きへ
  const FOCUS_ATK = true; // true＝攻撃も攻める側に寄ったまま／false＝攻撃で二人が収まるまで引く
  const camTo = (z, wx, ms, ease = 'cubic-bezier(.2,.7,.3,1)', fr = .5) => { // fr＝wx を画面の横のどこに置くか（.5＝中央） // 世界の x＝wx を画面の中央に、足元（舞台の85%）が画面の92%に来るよう、z倍に寄る（背景の外が見えないように抑える）
    const sw = stage.clientWidth, sh = stage.clientHeight; z = Math.max(1, z);
    const tx = Math.min(0, Math.max(sw - z * sw, sw * fr - z * wx)), ty = Math.min(0, Math.max(sh - z * sh, sh * (.92 - z * .85)));
    cam.style.transition = `transform ${ms}ms ${ease}`; cam.style.transformOrigin = '0 0'; cam.style.transform = z === 1 ? '' : `translate(${tx}px,${ty}px) scale(${z})`; };
  const runRound = i => { inWin = false; gb.classList.remove('ready');
    const r = GM.duelRound(plan, i, armed), at = r.ally ? L : Rf, df = r.ally ? Rf : L, dir = r.ally ? 1 : -1, act = r.ally ? actL : actR; armed = false; const fin = (r.ally ? aw : fw) + 1 >= 3; // fin＝決着の一撃
    const big = r.kind === 'counter' || r.kind === 'heavy', sw = stage.clientWidth, rs = stage.getBoundingClientRect(), ra = at.getBoundingClientRect(), rd = df.getBoundingClientRect();
    const CLOSE = .10; /* 詰める深さ：絵の枠（余白つき）同士を、舞台の幅のこの割合だけ重ねる（2026-10-29、もっと近くへ） */ const gap = r.ally ? rd.left - ra.right : ra.left - rd.right, dx = dir * Math.max(0, gap + sw * CLOSE); // 相手の懐まで詰める
    const cx0 = (ra.left + ra.right) / 2 - rs.left, cx1 = cx0 + dx; // 走る側の中心（世界の座標。カメラは毎合 引きから始まる）
    const span = Math.max(ra.right + dx, rd.right) - Math.min(ra.left + dx, rd.left), mid = (Math.max(ra.right + dx, rd.right) + Math.min(ra.left + dx, rd.left)) / 2 - rs.left;
    const zFit = Math.min(1.9, sw / (span + sw * .1)), zRun = Math.max(zFit + .3, 1.7); /* 2026-10-30 寄りを約2割弱く（以前 2.2・+.5・2.1） */ // 攻撃＝二人がぎりぎり収まる／走り＝その人を大きく
    const runMs = D(dx ? 470 : 160), ran = act && dx ? act.run(runMs, r.ally ? 1 : 2.2) : false, lead = D(140);
    at.style.transition = `transform ${runMs}ms ${ran ? 'linear' : 'ease-in'}`; at.style.transform = `translateX(${dx}px)`;
    const FR = dir > 0 ? .32 : .68; /* 寄るとき、攻める側を中央より後ろに置き、進む先（相手と斬撃）に余白を残す（2026-10-29） */ camTo(zRun, cx0 + dx * .25, lead, undefined, FR); T(() => camTo(zRun, cx1, runMs - lead, 'linear', FR), lead); // 寄ってから、走りに合わせて追う
    const clashX = (r.ally ? ra.right + dx : ra.left + dx) - rs.left + dir * sw * .02, tame = D(big ? 300 : 170);
    const ultFin = fin && r.ally && (R.boss || R.gen) && (DUEL_CLIP[k + '_ult'] || []).length; /* 将軍戦の止め：専用の大技 */ const P = act ? act.play(Math.max(0, runMs - D(120)), ultFin ? 'ult' : tame) /* 走りの終わりに重ねて振りかぶり始める（踏み込みながら構える） */ : { c: null, hitAt: runMs + 240 };
    const zAtk = big ? zRun * 1.08 : zRun, fx = cx1; // 攻撃の間も、走った側に寄ったまま（少しだけ前へ向ける）。二人を収める案は FOCUS_ATK=false
    T(() => FOCUS_ATK ? camTo(zAtk, fx, D(220), undefined, FR) : camTo(big ? zFit * 1.06 : zFit, mid, D(big ? 320 : 240)), runMs);
    if (r.kind === 'counter') { const c = $('.cut'); c.querySelector('div').innerHTML = `COUNTER<small>見切り　${A.n}が大技を受け流す</small>`; T(() => c.classList.add('on'), runMs); T(() => c.classList.remove('on'), P.hitAt + 500); }
    T(() => { /* コードの斬撃（fx_slash.js、全戦。2026-10-30 以前は将軍戦だけ）。味方の攻撃は青、敵は赤。カメラの寄りに合わせて、画面上の相手の位置に出す */ stopChg();
      const rs2 = stage.getBoundingClientRect(), r2 = df.getBoundingClientRect(), hx = (r2.left + r2.right) / 2 - rs2.left - dir * r2.width * .05, hy = r2.top - rs2.top + r2.height * .42, hsz = Math.min(rs2.height * .95, r2.height * 1.05);
      if (ultFin) { starFX(stage, at, df, { speed: spd, onQuake: () => { duelEl.classList.remove('shake'); void duelEl.offsetWidth; duelEl.classList.add('shake'); T(() => duelEl.classList.remove('shake'), 300); } }); } /* 星震の止め：踏み抜き→星の雨→大きな一撃（fx_slash.js starFX） */ else slashFX(stage, { x: hx, y: hy, size: hsz, dir, big, speed: spd, color: r.ally ? 'blue' : 'red' }); const sl = document.createElement('i');
      if (r.kind === 'counter') clashFX(stage, { x: (dir > 0 ? r2.left : r2.right) - rs2.left + dir * r2.width * .12, y: hy - hsz * .05, size: hsz * .6, speed: spd }); // 見切り：刃がぶつかる
      if (big || fin) impactFX(stage, { x: hx, y: hy, size: hsz * .7, dir, color: r.ally ? 'blue' : 'red', ko: fin, speed: spd }); // 大技・決着の一撃
      if (fin) { stage.classList.remove('kof'); void stage.offsetWidth; stage.classList.add('kof'); } df.classList.remove('hit'); void df.offsetWidth; df.classList.add('hit'); df.style.transition = 'transform .18s ease-out'; df.style.transform = `translateX(${dir * sw * .04}px)`; duelEl.classList.add('shake');
      if (ultFin) camTo(1, sw / 2, D(260), 'ease-out'); /* 星震の止め：打った瞬間に引いて、舞台全体に星を降らせる（2026-10-30 ユーザー） */ else FOCUS_ATK ? camTo(zAtk * 1.05, fx, 90, undefined, FR) : camTo((big ? zFit * 1.06 : zFit) * 1.05, mid, 90); // 当たりの瞬間、少しだけ寄る
      const n = document.createElement('div'); n.className = 'num'; n.textContent = r.dmg * 7 + Math.round(Math.random() * 9); n.style.left = (clashX / sw * 100 + (r.ally ? 6 : -14)) + '%'; n.style.top = '30%'; cam.appendChild(n); setTimeout(() => { sl.remove(); n.remove(); }, 900);
      apply(i, r); upd(); say(r.ally ? 'l' : 'r', pickOf((r.ally ? AL : FL).hit), 1500); T(() => say(r.ally ? 'r' : 'l', pickOf((r.ally ? FL : AL).hurt), 1400), D(350)); }, P.hitAt);
    T(() => { df.classList.remove('hit'); duelEl.classList.remove('shake'); df.style.transform = ''; }, P.hitAt + 260);
    const back = ultFin ? D(1800) : D(FOLLOW + (big ? 140 : 40)), backMs = D(420); // 専用の大技は、着地のあとの残心まで寄ったまま
    T(() => { camTo(1, sw / 2, backMs, 'ease-in-out'); at.style.transition = `transform ${backMs}ms ease-in-out`; at.style.transform = ''; }, P.hitAt + back); // 元の位置へ戻りながら、引きへ
    T(() => { if (aw >= 3 || fw >= 3) finish(); else roundStart(i + 1); }, P.hitAt + back + backMs + D(250)); };
  const goRound = i => { gb.classList.remove('ready'); runRound(i); };
  const roundStart = i => { if (over) return; cur = i; const heavy = plan.heavy.includes(i); pips[i].classList.add('cur'); inWin = true;
    msg(heavy ? `<em>第${i + 1}合</em>大技の構え${used ? '' : '　─　鬨の声で見切れる'}` : `<em>第${i + 1}合</em>${word}`, heavy); if (heavy) { say('r', pickOf(FL.heavy), D(1600), true); stopChg(); chg = chargeFX(stage, Rf, { color: 'red', speed: spd }); }
    const w = D(used ? 700 : 1800); /* 鬨の声を押せる時間（2.6秒→1.8秒、2026-10-29） */ tm.style.transition = 'none'; tm.style.width = '100%'; void tm.offsetWidth; tm.style.transition = `width ${w}ms linear`; tm.style.width = '0%'; if (!used) gb.classList.add('ready'); winT = T(() => goRound(i), w); };
  gb.onclick = e => { e.stopPropagation(); if (used || over || !inWin) return; left--; used = left <= 0; armed = true; rallyFX(stage, L, { speed: spd }); // 鬨の声の金の輪 gb.classList.remove('ready'); if (used) gb.classList.add('used'); gb.querySelector('em').textContent = used ? '使用済み' : `残り${left}回`;
    const heavy = plan.heavy.includes(cur); msg(`<em>鬨の声</em>${heavy ? '見切りの構え' : '次の一合を強化'}`); say('l', pickOf(AL.hit), D(900)); clearTimeout(winT); winT = T(() => goRound(cur), D(650)); };
  $('.sp2').onclick = e => { e.stopPropagation(); spd = spd === 1 ? 2 : 1; e.currentTarget.textContent = `▶▶ 速度 ×${spd}`; };
  $('.sk').onclick = e => { e.stopPropagation(); if (over) return; timers.forEach(clearTimeout); stopChg(); if (actL) actL.reset(); if (actR) actR.reset(); [L, Rf].forEach(x => { x.style.transform = ''; x.style.filter = ''; }); camTo(1, stage.clientWidth / 2, 0); duelEl.classList.remove('shake'); $('.cut').classList.remove('on'); pips.forEach(p => p.classList.remove('cur'));
    while (aw < 3 && fw < 3 && nextI < 5) { apply(nextI, GM.duelRound(plan, nextI, armed)); armed = false; } upd(); finish(); };
  duelEl.onclick = null;
  const srcs = duelSrcs(k, look), ld = document.createElement('div'); ld.className = 'ld'; ld.innerHTML = '<b>構えを整えている…</b><i><u></u></i>'; stage.appendChild(ld); // 全部の絵を読み終えてから始める
  let got = 0; const bar = ld.querySelector('u');
  Promise.all(srcs.map(sr => holdImg(sr).then(() => { got++; bar.style.width = (got / srcs.length * 100) + '%'; }))).then(() => { if (over) return; ld.classList.add('out'); setTimeout(() => ld.remove(), 300);
    say('l', pickOf(AL.open), 2200); say('r', pickOf(FL.open), 2200); T(() => roundStart(0), 2300); });
}
function openSelect(cs, F, onPick, onDecline) { // 一騎打ちに送り出す仲間を選ぶ（モック準拠：上に敵将、下に仲間のカード）
  const R = G.raid, look = foeLook(), FLo = GM.DUEL_LINES[duelRank()]; let sel = cs[0];
  const por = {}; cs.forEach(k => { por[k] = POR[k] ? pickOf(POR[k]) : `../ally/${k}.png`; });
  duelSel.innerHTML = `<div class="hero" style="background-image:${bustBG(look, 1)},url(assets/field/${R.dir || 'pass'}.jpg);background-size:124% auto,124% auto,cover;background-position:0 0,0 0,center"><div class="tt"><small>第${R.w || G.week}週</small><img class="dv0" src="assets/ui2/divider2.webp"><h1>一騎打ち</h1></div><div class="qt">${FLo.open[0]}<small>${F.n}</small></div></div>
    <div class="pn"><i class="cn tl"></i><i class="cn tr"></i><h2>誰を送り出す？</h2><img class="dv" src="assets/ui2/divider2.webp"><div class="grid">${cs.map(k => { const p = Math.round(GM.duelP(G, k) * 100); return `<div class="cd" data-k="${k}"><img src="${por[k]}"><div class="tx"><div class="nm">${GM.ALLY[k].n}</div><div class="ln"></div><div class="pw">勝率 約<b>${p}</b>%</div></div><div class="ck">✓</div></div>`; }).join('')}</div>
      <div class="hint dline">勝てば有利に、負ければ不利になる</div>${cs.length ? '<button class="go"></button>' : ''}<div class="no">挑戦に応じない</div></div>`;
  const go = duelSel.querySelector('.go'), mark = () => { duelSel.querySelectorAll('.cd').forEach(c => c.classList.toggle('on', c.dataset.k === sel)); if (go) go.textContent = `${GM.ALLY[sel].n}を送り出す`; }; mark();
  duelSel.querySelectorAll('.cd').forEach(c => { c.onclick = e => { e.stopPropagation(); sel = c.dataset.k; mark(); }; });
  if (go) go.onclick = e => { e.stopPropagation(); duelSel.style.display = 'none'; onPick(sel); };
  duelSel.querySelector('.no').onclick = e => { e.stopPropagation(); duelSel.style.display = 'none'; onDecline(); };
  duelSel.classList.toggle('many', cs.length > 4); duelSel.style.display = 'flex';
}
function maybeDuel(next) { // 接戦なら、一騎打ちに出す仲間を選ぶ
  if (!GM.duelDue(G) || G.raid.duel !== undefined) { next(); return; }
  const F = GM.foeGeneral(G), cs = GM.champions(G); ui.modal(null);
  openSelect(cs, F, k => playDuel(k, next), () => { G.raid.duel = null; next(); });
}
// ---------- 任せた戦闘（俯瞰の戦場。モック準拠）：兵がぶつかる → 接戦なら敵将が一騎打ちを挑む → 勝敗 ----------
const fbCss = document.createElement('style'); fbCss.textContent = `
#abt.fb{--u:min(.2326vw,.1073dvh);--ink:#2b1d10;--ink2:#5e4728;--gold:#a8833c;--teal:#2c6a64;--red:#a3362b;display:none;flex-direction:column;align-items:stretch;justify-content:flex-start;padding:0;
  font-family:'DMincho','Hiragino Mincho ProN','Yu Mincho',serif;font-weight:700;color:var(--ink);background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(760*var(--u)) auto repeat}
#abt.fb *{box-sizing:border-box}
#abt.fb .cn{position:absolute;width:calc(62*var(--u));aspect-ratio:220/153;background:url(assets/ui2/corner.webp) center/contain no-repeat;pointer-events:none;z-index:1;opacity:.92}
#abt.fb .cn.tl{left:calc(4*var(--u));top:calc(4*var(--u))}#abt.fb .cn.tr{right:calc(4*var(--u));top:calc(4*var(--u));transform:scaleX(-1)}#abt.fb .cn.bl{left:calc(4*var(--u));bottom:calc(4*var(--u));transform:scaleY(-1)}#abt.fb .cn.br{right:calc(4*var(--u));bottom:calc(4*var(--u));transform:scale(-1,-1)}
#abt.fb .fh{position:relative;flex:0 0 auto;height:calc(96*var(--u));padding:calc(10*var(--u)) calc(20*var(--u)) 0;text-align:center}
#abt.fb .fh .tag{position:absolute;left:calc(24*var(--u));top:calc(14*var(--u));padding:calc(3*var(--u)) calc(14*var(--u));border:1px solid var(--ink2);box-shadow:inset 0 0 0 calc(2*var(--u)) #efe3c8,inset 0 0 0 calc(3*var(--u)) #a48a5c;font-size:calc(13*var(--u));letter-spacing:.12em}
#abt.fb .fh h1{margin:0;font-size:calc(27*var(--u));font-weight:700;letter-spacing:.14em;line-height:1.3}
#abt.fb .fh img{display:block;width:calc(190*var(--u));margin:calc(2*var(--u)) auto}
#abt.fb .fh .sub{display:flex;justify-content:space-between;align-items:baseline;font-size:calc(13*var(--u));letter-spacing:.08em;margin-top:calc(-2*var(--u))}
#abt.fb .fh .sub b{font-size:1.65em;font-weight:700;margin-left:.3em;letter-spacing:0}#abt.fb .fh .sub .md{font-size:calc(12.5*var(--u));color:var(--ink2)}
#abt.fb .fs{position:relative;z-index:0;isolation:isolate;flex:1;min-height:0;overflow:hidden;background:#6b6a3a url(assets/field/top.jpg) center/cover no-repeat}
#abt.fb .fs.nobg{background:radial-gradient(120% 80% at 50% 45%,#9a9452,#6d6a35 70%,#4c4a26),#6d6a35}
#abt.fb .fs::after{content:'';position:absolute;inset:0;box-shadow:inset 0 0 calc(40*var(--u)) #0006;pointer-events:none;z-index:1550}
#abt.fb .un{position:absolute;width:0;height:0}
#abt.fb .un .s{position:absolute;background-repeat:no-repeat;pointer-events:none;filter:drop-shadow(0 calc(3*var(--u)) calc(3*var(--u)) #0007)}
#abt.fb .un .sh{position:absolute;left:calc(-14*var(--u));top:calc(-4*var(--u));width:calc(28*var(--u));height:calc(8*var(--u));border-radius:50%;background:#0004}
#abt.fb .un.hit .s{animation:fhit .32s linear}#abt.fb .un.foe.hit .s,#abt.fb .un.hit .s{filter:sepia(.35) saturate(2.2) hue-rotate(-25deg) brightness(1.06) drop-shadow(0 0 calc(2*var(--u)) #ff3a2088)}
@keyframes fhit{0%,100%{translate:0 0}20%{translate:calc(-3*var(--u)) 0}45%{translate:calc(3*var(--u)) 0}70%{translate:calc(-2*var(--u)) 0}}
#abt.fb .un.dead{transition:opacity .9s .2s,transform .6s;opacity:0}
#abt.fb .un.foe .s{filter:drop-shadow(0 0 calc(2*var(--u)) #c0301c) drop-shadow(0 calc(3*var(--u)) calc(3*var(--u)) #0007)}
#abt.fb .spk{position:absolute;width:calc(46*var(--u));height:calc(46*var(--u));margin:calc(-23*var(--u)) 0 0 calc(-23*var(--u));background:radial-gradient(circle,#fff 0,#ffe7a0 18%,#ffb04066 40%,transparent 70%);animation:fspk .32s ease-out forwards;pointer-events:none;z-index:1600}
@keyframes fspk{from{transform:scale(.3)}to{transform:scale(1.4);opacity:0}}
#abt.fb .dn{position:absolute;font:italic 700 calc(19*var(--u)) Georgia,'DMincho',serif;color:#fff3d2;-webkit-text-stroke:calc(.8*var(--u)) #4a1c08;text-shadow:0 calc(1.5*var(--u)) 0 #4a1c08;animation:fdn .8s ease-out forwards;pointer-events:none;z-index:1601;transform:translateX(-50%)}
#abt.fb .dn.us{color:#ffd6c8}
@keyframes fdn{from{margin-top:0;opacity:1}to{margin-top:calc(-30*var(--u));opacity:0}}
#abt.fb .say{position:absolute;max-width:56%;padding:calc(12*var(--u)) calc(13*var(--u)) calc(9*var(--u));background:#fbf6e9;border:1.5px solid #6e1f17;border-radius:calc(12*var(--u));box-shadow:0 calc(4*var(--u)) calc(12*var(--u)) #0005;font-size:calc(15*var(--u));line-height:1.45;opacity:0;transform:translate(-80%,-100%) scale(.6);transform-origin:80% 100%;transition:opacity .12s,transform .22s cubic-bezier(.2,1.5,.4,1);z-index:1700;white-space:nowrap;pointer-events:none}
#abt.fb .say.on{opacity:1;transform:translate(-80%,-100%)}#abt.fb .say::after{content:'';position:absolute;bottom:calc(-9*var(--u));right:18%;width:calc(14*var(--u));height:calc(14*var(--u));background:#fbf6e9;border:1.5px solid #6e1f17;border-top:0;border-left:0;transform:rotate(45deg)}
#abt.fb .say small{position:absolute;top:calc(-10*var(--u));right:calc(10*var(--u));padding:0 calc(8*var(--u));background:#6e1f17;color:#f3e7c8;border-radius:calc(3*var(--u));font-size:calc(10*var(--u));letter-spacing:.1em;line-height:1.7}
#abt.fb .say.us{border-color:#3b2a16;transform:translate(-20%,-100%) scale(.6);transform-origin:20% 100%}#abt.fb .say.us.on{transform:translate(-20%,-100%)}#abt.fb .say.us::after{right:auto;left:18%;border-color:#3b2a16}#abt.fb .say.us small{right:auto;left:calc(10*var(--u));background:#3b2a16}
#abt.fb .ban{position:absolute;left:0;right:0;top:40%;padding:calc(10*var(--u)) 0;text-align:center;background:linear-gradient(90deg,transparent,#1b120ad0 20%,#1b120ad0 80%,transparent);color:#f6ecd0;font-size:calc(22*var(--u));letter-spacing:.3em;opacity:0;transition:opacity .3s;z-index:1650;pointer-events:none}
#abt.fb .ban.on{opacity:1}#abt.fb .ban small{display:block;font-size:calc(11*var(--u));letter-spacing:.12em;color:#e3d2a6}
#abt.fb .ff{position:relative;z-index:2;flex:0 0 auto;height:calc(214*var(--u));display:flex;flex-direction:column;align-items:center;padding:calc(18*var(--u)) calc(22*var(--u)) calc(10*var(--u))}
#abt.fb .ff::before{content:'';position:absolute;left:0;right:0;top:calc(-20*var(--u));height:calc(40*var(--u));background:url(assets/ui2/vine.webp) center/100% 100% no-repeat;pointer-events:none}
#abt.fb .ff h3{margin:calc(4*var(--u)) 0 calc(6*var(--u));font-size:calc(18*var(--u));font-weight:700;letter-spacing:.3em;padding-left:.3em;display:flex;align-items:center;gap:calc(12*var(--u))}
#abt.fb .ff h3::before,#abt.fb .ff h3::after{content:'';width:calc(80*var(--u));height:1px;background:linear-gradient(90deg,transparent,var(--gold))}#abt.fb .ff h3::after{background:linear-gradient(90deg,var(--gold),transparent)}
#abt.fb .bal{width:96%;height:calc(13*var(--u));padding:1px;background:#2a1e12;border:1px solid #8c6c34;box-shadow:0 0 0 1px #e9dcbcaa;position:relative}
#abt.fb .bal::before{content:'';position:absolute;inset:1px;background:linear-gradient(#d4705c,#a3362b 60%,#86281f)}
#abt.fb .bal b{position:absolute;left:1px;top:1px;bottom:1px;background:linear-gradient(#5aa59a,#2c6a64 60%,#24564f);transition:width .6s cubic-bezier(.3,.8,.3,1)}
#abt.fb .bal u{position:absolute;top:50%;width:calc(15*var(--u));height:calc(15*var(--u));background:linear-gradient(135deg,#f6e2a0,#c99a3c);border:1px solid #5e4320;transform:translate(-50%,-50%) rotate(45deg);transition:left .6s cubic-bezier(.3,.8,.3,1)}
#abt.fb .stt{margin-top:calc(8*var(--u));font-size:calc(14.5*var(--u));letter-spacing:.14em;min-height:1.5em}
#abt.fb .dbtn{margin-top:calc(8*var(--u));width:80%;height:calc(66*var(--u));display:flex;align-items:center;gap:calc(14*var(--u));padding:0 calc(18*var(--u));border:1px solid #6a5434;box-shadow:inset 0 0 0 calc(3*var(--u)) #efe3c8,inset 0 0 0 calc(4*var(--u)) #a48a5c;background:#f1e7cf;font:inherit;color:var(--ink);font-size:calc(19*var(--u));letter-spacing:.12em;cursor:pointer;visibility:hidden;opacity:0;transform:translateY(8px);transition:opacity .25s,transform .25s}
#abt.fb .dbtn.on{visibility:visible;opacity:1;transform:none;animation:fdb 1s infinite alternate}@keyframes fdb{to{box-shadow:inset 0 0 0 calc(3*var(--u)) #efe3c8,inset 0 0 0 calc(4*var(--u)) #a48a5c,0 0 calc(14*var(--u)) #d8a03a}}
#abt.fb .dbtn i{flex:0 0 calc(50*var(--u));height:calc(50*var(--u));border-radius:50%;background:#7a1d14 50% 10%/240% no-repeat;box-shadow:0 0 0 calc(2*var(--u)) #6e1f17,0 0 0 calc(3.5*var(--u)) #d8b86a}
#abt.fb .dbtn span{flex:1;text-align:center}
#abt.fb .fk{position:absolute;left:calc(26*var(--u));right:calc(26*var(--u));bottom:calc(12*var(--u));display:flex;justify-content:space-between;font-size:calc(13.5*var(--u));letter-spacing:.08em;z-index:3}
#abt.fb .fk button{font:inherit;color:inherit;background:none;border:0;padding:calc(6*var(--u)) calc(4*var(--u));border-bottom:1px solid #a48a5c88;cursor:pointer}
#abt.fb .fr{position:absolute;inset:0;display:none;align-items:center;justify-content:center;background:#0006;z-index:80;cursor:pointer}
#abt.fb .fr.on{display:flex}
#abt.fb .fr .bd{width:100%;padding:calc(22*var(--u)) calc(16*var(--u)) calc(18*var(--u));display:flex;flex-direction:column;align-items:center;text-align:center;background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(760*var(--u)) auto;border-top:1px solid var(--gold);border-bottom:1px solid var(--gold);box-shadow:0 0 calc(30*var(--u)) #0008;animation:dres .35s cubic-bezier(.2,1.3,.4,1)}
#abt.fb .fr .k{font-size:calc(12*var(--u));letter-spacing:.3em;color:var(--ink2)}
#abt.fb .fr h2{margin:calc(2*var(--u)) 0;font-size:calc(40*var(--u));font-weight:700;letter-spacing:.3em;padding-left:.3em}#abt.fb .fr h2.w{color:var(--teal)}#abt.fb .fr h2.m{color:#8a6a24}#abt.fb .fr h2.l{color:var(--red)}
#abt.fb .fr img{width:calc(200*var(--u))}#abt.fb .fr p{margin:calc(6*var(--u)) 0 0;font-size:calc(13*var(--u));letter-spacing:.06em;line-height:1.6}#abt.fb .fr p small{display:block;margin-top:calc(8*var(--u));font-size:calc(11*var(--u));color:var(--ink2)}`;
document.head.appendChild(fbCss);
const FB_TOP = await loadImage('assets/field/top.jpg'); // 俯瞰の戦場の絵（無ければ仮の地面）
const fbImg = {}; const fbSize = src => fbImg[src] || (fbImg[src] = new Promise(res => { const im = new Image(); im.onload = () => res([im.width, im.height]); im.onerror = () => res(null); im.src = src; }));
// 部隊の種類：歩き（シート）と攻撃（一騎打ち用の連番を流用）。right＝元の絵が右向きか
function fbKinds() {
  const K = {};
  for (const k of Object.keys(GM.ALLY)) K[k] = { walk: `../ally/walk_${k}.webp`, wc: 4, wr: 4, wn: 16, wp: (WALK_BBH[k] || 430) / 512, wr0: true, clips: (DUEL_CLIP[k] || []).map(c => ({ ...c, base: '../ally/' })), cr: true, h: 1.2 };
  const FW = FOEWALK_META || [];
  K.sol = { walk: 'assets/npc/solwalk_1.webp', wc: 4, wr: 2, wn: 8, wp: FW[0] ? FW[0].h / FW[0].ch : .9, wr0: true, clips: (FOEDUEL.sol || (FOEDUEL[1] || []).map(c => ({ ...c, f: c.f.replace('foeduel', 'solduel') }))).map(c => ({ ...c, base: 'assets/npc/' })), cr: false, h: 1 };
  for (const n of [1, 2, 3, 4]) K['f' + n] = { walk: `assets/npc/foewalk_${n}.webp`, wc: 4, wr: 2, wn: 8, wp: FW[n - 1] ? FW[n - 1].h / FW[n - 1].ch : .9, wr0: true, clips: (FOEDUEL[n] || []).map(c => ({ ...c, base: 'assets/npc/' })), cr: false, h: 1 };
  return K;
}
function fbUnit(stage, kind, K, side, x, y, H) { // x,y＝足元（舞台の％）、H＝人物の高さ(px)
  const el = document.createElement('div'); el.className = 'un ' + side; el.style.left = x + '%'; el.style.top = y + '%'; el.style.zIndex = Math.round(y * 10);
  el.innerHTML = '<i class="sh"></i><div class="s"></div>'; stage.appendChild(el); const s = el.lastChild, k = K[kind];
  const face = side === 'us' ? 1 : -1; // 味方は右向き、敵は左向き
  const u = { el, s, kind, side, x, y, H, face, alive: true, busy: false, f: Math.floor(Math.random() * 16) };
  u.setWalk = async (frame) => { const sz = await fbSize(k.walk); if (!sz) return; const fw = sz[0] / k.wc, fh = sz[1] / k.wr, sc = H / (fh * k.wp);
    const i = frame % k.wn, cx = i % k.wc, cy = Math.floor(i / k.wc), flip = (k.wr0 ? 1 : -1) * u.face < 0;
    Object.assign(s.style, { width: fw * sc + 'px', height: fh * sc + 'px', left: -fw * sc / 2 + 'px', top: -fh * sc * .985 + 'px', backgroundImage: `url(${k.walk})`, backgroundSize: `${sz[0] * sc}px ${sz[1] * sc}px`, backgroundPosition: `${-cx * fw * sc}px ${-cy * fh * sc}px`, transform: flip ? 'scaleX(-1)' : '' }); };
  u.clipFrame = (c, i) => { const sc = H / c.idle.h, cw = c.cw * sc, ch = c.ch * sc, cx = (c.idle.x + c.idle.w / 2) * sc, flip = (k.cr ? 1 : -1) * u.face < 0, rows = Math.ceil(c.n / c.cols);
    const L0 = flip ? -(cw - cx) : -cx, T0 = -(ch - (c.pad ?? 2.8) * sc);
    if (c.fr) { const r = c.fr[i]; Object.assign(s.style, { width: r[2] * sc + 'px', height: r[3] * sc + 'px', left: L0 + (flip ? cw - (r[4] + r[2]) * sc : r[4] * sc) + 'px', top: T0 + r[5] * sc + 'px', backgroundImage: `url(${c.base}${c.f})`, backgroundSize: `${c.sw * sc}px ${c.sh * sc}px`, backgroundPosition: `${-r[0] * sc}px ${-r[1] * sc}px`, transform: flip ? 'scaleX(-1)' : '' }); return; } // 詰め直したシート
    Object.assign(s.style, { width: cw + 'px', height: ch + 'px', left: L0 + 'px', top: T0 + 'px', backgroundImage: `url(${c.base}${c.f})`, backgroundSize: `${c.cols * cw}px ${rows * ch}px`, backgroundPosition: `${-(i % c.cols) * cw}px ${-Math.floor(i / c.cols) * ch}px`, transform: flip ? 'scaleX(-1)' : '' }); };
  u.idle = () => { if (k.clips.length) u.clipFrame(k.clips[0], 0); else u.setWalk(0); };
  u.attack = (T, onHit) => { // 一騎打ち用の連番を速めて流す。山場で onHit
    if (!k.clips.length) { T(onHit, 200); return 600; } const c = k.clips[Math.floor(Math.random() * k.clips.length)], SPD = 2.6; let acc = 0; u.busy = true;
    c.durs.forEach((d, fi) => { T(() => { if (u.alive) u.clipFrame(c, fi); if (fi === c.hit) onHit(); }, acc / SPD); acc += d; });
    T(() => { u.busy = false; if (u.alive) u.idle(); }, acc / SPD + 20); return acc / SPD; };
  u.die = () => { u.alive = false; el.classList.add('dead'); el.style.transform = `translate(${-face * 12}px,6px) rotate(${-face * 14}deg)`; };
  return u;
}
function fieldBattle(mode, onEnd) { // onEnd：試しのとき、結果を記録せずに呼ぶ // mode：'auto'（任せる）。'hand' は旧「確率で決める」（画面からは外した）
  if (!G.raid) { ui.modal(null); return; }
  const R = G.raid, usD = Math.round(GM.raidD(G)), E = R.E, fr = GM.FRONT[R.dir], K = fbKinds(), rank = duelRank(), FL = GM.DUEL_LINES[rank], F = GM.foeGeneral(G), look = foeLook();
  const team = Object.keys(GM.ALLY).filter(k => GM.fighter(k) && GM.joined(G, k) && !(k === 'ranka' && (G.rankaAway || !R.ranka))).slice(0, 4);
  abt.className = 'fb'; abt.style.backgroundImage = ''; abt.onclick = null;
  abt.innerHTML = `<div class="fh"><i class="cn tl"></i><i class="cn tr"></i><div class="tag">${R.kind === 'sortie' ? '出撃' : '防衛戦'}</div><h1>${R.name}</h1><img src="assets/ui2/divider2.webp">
      <div class="sub"><span>${R.kind === 'sortie' ? `戦力（兵${R.sent}）` : '防衛力'}<b>${usD}</b></span><span class="md">${fr ? fr.n : ''}</span><span>敵の規模<b>${E}</b></span></div></div>
    <div class="fs${FB_TOP ? '' : ' nobg'}"><div class="ban"></div></div>
    <div class="ff"><i class="cn bl"></i><i class="cn br"></i><h3>戦況</h3><div class="bal"><b style="width:50%"></b><u style="left:50%"></u></div><div class="stt">両軍、前へ</div>
      <button class="dbtn"><i style="background-image:${bustBG(look, 1)}"></i><span>一騎打ちの挑戦 ›</span></button>
      <div class="fk"><button class="spd">速度 ×1</button><button class="sk">スキップ ›</button></div></div>
    <div class="fr"></div>`;
  abt.style.display = 'flex';
  const $ = q => abt.querySelector(q), st = $('.fs'), balB = $('.bal b'), balU = $('.bal u'), stt = $('.stt'), dbtn = $('.dbtn'), ban = $('.ban');
  const W = () => st.clientWidth, Hs = () => st.clientHeight, unit = Hs() * .1; // 兵の背の高さ＝舞台の約12%
  let timers = [], spd = 1, phase = 'march', gauge = 50, done = false; const T = (f, ms) => { const t = setTimeout(f, ms / spd); timers.push(t); return t; };
  const setG = v => { gauge = Math.max(5, Math.min(95, v)); balB.style.width = gauge + '%'; balU.style.left = gauge + '%'; if (phase !== 'duel') stt.textContent = gauge > 62 ? '優勢' : gauge < 38 ? '劣勢' : '拮抗'; };
  // 布陣（モック準拠）：味方＝左（仲間は一番左の列）、敵＝右（将は一番右）
  const us = [], foe = [], nSol = Math.max(9, Math.min(18, 6 + ((R.kind === 'sortie' ? R.sent : G.troops) || 0) * 2)), nFoe = Math.max(18, Math.min(36, Math.round(E / 1.4)));
  const rowY = (i, n) => 28 + (i + .5) * 62 / n, jit = () => (Math.random() - .5) * 3;
  const hu = n => unit * (HUMAN[n] || 190) / 190;
  team.forEach((k, i) => us.push(fbUnit(st, k, K, 'us', 9 + (i % 2) * 3, 34 + i * 52 / Math.max(1, team.length - 1 || 1), hu(k))));
  for (let i = 0; i < nSol; i++) { const col = i % 3, row = Math.floor(i / 3), rows = Math.ceil(nSol / 3); us.push(fbUnit(st, 'sol', K, 'us', 19 + col * 8 + jit(), rowY(row, rows) + (col % 2) * 3 + jit(), hu('sol'))); }
  const fk = ['f1', 'f2', 'f3']; for (let i = 0; i < nFoe; i++) { const col = i % 4, row = Math.floor(i / 4), rows = Math.ceil(nFoe / 4), kd = fk[(i * 7 + row) % 3]; foe.push(fbUnit(st, kd, K, 'foe', 57 + col * 8 + jit(), rowY(row, rows) + (col % 2) * 3 + jit(), hu(kd))); }
  const gen = fbUnit(st, 'f' + look, K, 'foe', 91, 58, hu('f' + look) * 1.06); gen.gen = true; foe.push(gen);
  if (rank !== 'boss') { foe.push(fbUnit(st, 'f3', K, 'foe', 92, 36, hu('f3'))); foe.push(fbUnit(st, 'f3', K, 'foe', 90, 80, hu('f3'))); }
  [...us, ...foe].forEach(u => u.idle());
  // 行進（歩きのコマで少し前へ）
  const march = (ms, dist) => { const t0 = performance.now(); const tick = () => { if (done) return; const k = Math.min(1, (performance.now() - t0) * spd / ms);
      [...us, ...foe].forEach(u => { if (!u.alive || u.gen) return; const dx = (u.side === 'us' ? 1 : -1) * dist * (k * (2 - k)); u.el.style.left = (u.x + dx) + '%'; u.f++; if (k < 1) u.setWalk(Math.floor(u.f / 5)); });
      if (k < 1) requestAnimationFrame(tick); else [...us, ...foe].forEach(u => { if (u.alive && !u.gen) { u.x += (u.side === 'us' ? 1 : -1) * dist; u.idle(); } }); }; tick(); };
  const moveTo = (u, x, y, ms) => { const x0 = u.x, y0 = u.y, t0 = performance.now(); u.mv = (u.mv || 0) + 1; const id = u.mv; if (Math.abs(x - x0) > 8) u.face = x > x0 ? 1 : -1; // 大きく動くときは進む向きを向く
    const tick = () => { if (done || !u.alive || u.mv !== id) return; const k = Math.min(1, (performance.now() - t0) * spd / ms), e = k * (2 - k);
      u.x = x0 + (x - x0) * e; u.y = y0 + (y - y0) * e; u.el.style.left = u.x + '%'; u.el.style.top = u.y + '%'; u.el.style.zIndex = Math.round(u.y * 10);
      if (k < 1) { if (!u.busy) { u.f++; u.setWalk(Math.floor(u.f / 5)); } requestAnimationFrame(tick); } else if (!u.busy) u.idle(); }; tick(); };
  const MID = 47, melee = u => { u.eng = true; moveTo(u, MID + (u.side === 'us' ? -2.5 : 2.5) + (Math.random() - .5) * 13, Math.max(26, Math.min(90, u.y + (Math.random() - .5) * 8)), 900 + Math.random() * 600); };
  const reinforce = side => { const pool = (side === 'us' ? us : foe).filter(u => u.alive && !u.gen && !u.eng && !GM.ALLY[u.kind]); if (pool.length) melee(pool.sort((a, b) => (side === 'us' ? b.x - a.x : a.x - b.x))[0]); };
  const pos = u => [parseFloat(u.el.style.left) / 100 * W(), parseFloat(u.el.style.top) / 100 * Hs()];
  const spark = (u, n, mine) => { const [x, y] = pos(u), s = document.createElement('i'); s.className = 'spk'; s.style.left = x + 'px'; s.style.top = (y - u.H * .55) + 'px'; st.appendChild(s);
    const d = document.createElement('div'); d.className = 'dn' + (mine ? ' us' : ''); d.textContent = n; d.style.left = x + 'px'; d.style.top = (y - u.H * 1.05) + 'px'; st.appendChild(d);
    u.el.classList.remove('hit'); void u.el.offsetWidth; u.el.classList.add('hit'); clearTimeout(u.ht); u.ht = setTimeout(() => u.el.classList.remove('hit'), 320); setTimeout(() => { s.remove(); d.remove(); }, 820); };
  const say = (u, text, ms = 1800) => { const [x, y] = pos(u), b = document.createElement('div'); b.className = 'say ' + u.side; b.innerHTML = `<small>${u.side === 'us' ? GM.ALLY[u.kind] ? GM.ALLY[u.kind].n : '兵' : F.n}</small>${text}`;
    b.style.left = x + 'px'; b.style.top = (y - u.H * 1.15) + 'px'; st.appendChild(b); requestAnimationFrame(() => b.classList.add('on')); setTimeout(() => { b.classList.remove('on'); setTimeout(() => b.remove(), 300); }, ms / spd); };
  const live = a => a.filter(u => u.alive && !u.gen);
  // 斬り合い：優勢な側ほど多く当てる。lossUs/lossFoe＝この区間で倒れる数
  const clash = (ms, toward, lossUs, lossFoe) => { const n = Math.round(ms / 200), g0 = gauge; let du = 0, df = 0;
    for (let j = 0; j < n; j++) T(() => { if (j % 2 === 0 && Math.random() < .5) live(Math.random() < .5 ? us : foe).filter(u => u.eng && !u.busy).slice(0, 1).forEach(u => moveTo(u, u.x + (Math.random() - .5) * 4, u.y + (Math.random() - .5) * 4, 500)); // 混戦の中で位置を入れ替える
      if (done) return; const ourTurn = Math.random() < gauge / 100, A = live(ourTurn ? us : foe), D = live(ourTurn ? foe : us); if (!A.length || !D.length) return;
      const free = A.filter(u => !u.busy), pick = free.filter(u => u.eng).length ? free.filter(u => u.eng) : free; const a = pick.sort(() => Math.random() - .5)[0]; if (!a) return; const d = D.sort((p, q) => Math.hypot(p.x - a.x, (p.y - a.y) * 1.6) - Math.hypot(q.x - a.x, (q.y - a.y) * 1.6))[Math.floor(Math.random() * Math.min(2, D.length))];
      a.attack(T, () => { spark(d, Math.round(8 + Math.random() * E / 2), !ourTurn); const kill = !GM.ALLY[d.kind] && (ourTurn ? (df < lossFoe && Math.random() < .5) : (du < lossUs && Math.random() < .5)); if (kill) { if (ourTurn) df++; else du++; T(() => { d.die(); T(() => reinforce(d.side), 500); }, 160); } });
      setG(g0 + (toward - g0) * (j + 1) / n + (Math.random() - .5) * 6); }, j * 200 + Math.random() * 120); };
  const banner = (h, sub, ms) => { ban.innerHTML = `${h}${sub ? `<small>${sub}</small>` : ''}`; ban.classList.add('on'); T(() => ban.classList.remove('on'), ms); };
  // 1. 行進 → 2. 斬り合い（見込みの方向へ） → 3. 接戦なら敵将の挑戦 → 4. 決着
  const m0 = GM.raidD(G) - E, lean = 50 + Math.max(-16, Math.min(16, m0 * 2));
  banner((R.boss || R.gen) ? '将軍の侵攻' : '開戦', fr ? `${fr.n}で迎え撃つ` : '', 1500 * spd);
  march(1300, 3); T(() => { const fr1 = (s, n) => (s === 'us' ? us : foe).filter(u => !u.gen && !GM.ALLY[u.kind]).sort((a, b) => s === 'us' ? b.x - a.x : a.x - b.x).slice(0, n); [...fr1('us', Math.ceil(nSol * .55)), ...fr1('foe', Math.ceil(nFoe * .45))].forEach((u, i) => T(() => melee(u), i * 60)); }, 1300);
  T(() => { phase = 'clash'; clash(3800, lean, 3, 4); }, 2100);
  const wantDuel = GM.duelDue(G) && R.duel === undefined;
  T(() => wantDuel ? challenge() : finale(), 6000);
  function challenge() { // 敵将が前に出て、一騎打ちを挑む。押すまで待つ
    phase = 'duel'; stt.textContent = '敵将が前に出た'; gen.el.style.transition = `left ${0.8 / spd}s ease-out`; gen.x -= 8; gen.el.style.left = gen.x + '%';
    T(() => say(gen, FL.open[0], 2600), 700); T(() => dbtn.classList.add('on'), 900); }
  dbtn.onclick = e => { e.stopPropagation(); if (phase !== 'duel' || done) return; dbtn.classList.remove('on');
    const cs = GM.champions(G); 
    openSelect(cs, F, k => playDuel(k, afterDuel), () => { G.raid.duel = null; afterDuel(); }); };
  function afterDuel() { // 一騎打ちの結果を戦場に返す
    abt.style.display = 'flex'; phase = 'clash'; const r = G.raid.duel;
    if (r === true) { gen.die(); banner('敵将を討ち取った', '味方の士気が上がる', 1500 * spd); setG(gauge + 14); live(us).slice(0, 2).forEach((u, i) => T(() => say(u, i ? 'おおっ！' : '今だ、押せ！', 1300), 300 + i * 500)); }
    else if (r === false) { const c = us.find(u => u.kind === G.raid.champ); if (c) c.die(); banner('一騎打ちに敗れた', '敵の勢いが増す', 1500 * spd); setG(gauge - 14); }
    T(finale, r === undefined || r === null ? 0 : 1300); }
  function finale() { // ここで結果を決め、演出を合わせる
    phase = 'end'; const t = GM.resolve(G, mode); const good = /被害なし|完勝|勝利/.test(t) && !/敗北/.test(t), mid = /小被害|苦戦/.test(t);
    const fin = good ? 84 : mid ? 58 : 22; clash(2600, fin, good ? 3 : mid ? 5 : 8, good ? 11 : mid ? 6 : 3);
    T(() => { if (good) live(foe).forEach((u, i) => T(() => { u.busy = false; moveTo(u, 112, u.y + (Math.random() - .5) * 10, 1400); }, i * 40)); else if (!mid) live(us).filter(u => !GM.ALLY[u.kind]).forEach((u, i) => T(() => { u.busy = false; moveTo(u, Math.max(18, u.x - 18), u.y, 1200); }, i * 50)); }, 2700);
    T(() => result(t, good, mid), 3400); }
  function result(t, good, mid) { if (done) return; done = true; timers.forEach(clearTimeout); const label = good ? '勝利' : mid ? '辛勝' : '敗北', cls = good ? 'w' : mid ? 'm' : 'l';
    const fr2 = $('.fr'); fr2.innerHTML = `<div class="bd"><div class="k">${R.kind === 'sortie' ? '出撃' : '防衛戦'}</div><h2 class="${cls}">${label}</h2><img src="assets/ui2/divider2.webp"><p>${(t.split('：')[1] || '').replace(/ /g, '　')}<small>タップで続ける</small></p></div>`; fr2.classList.add('on');
    fr2.onclick = e => { e.stopPropagation(); abt.style.display = 'none'; abt.className = ''; abt.innerHTML = ''; endRaidFx(); if (onEnd) { onEnd(); return; } commit(t); showReport(); }; }
  $('.spd').onclick = e => { e.stopPropagation(); spd = spd === 1 ? 2 : 1; e.currentTarget.textContent = `速度 ×${spd}`; };
  $('.sk').onclick = e => { e.stopPropagation(); if (done) return; if (phase === 'duel') { dbtn.click(); return; }
    timers.forEach(clearTimeout); timers = []; if (wantDuel && G.raid && G.raid.duel === undefined) { challenge(); return; } if (phase !== 'end') { const t = GM.resolve(G, mode); const good = /被害なし|完勝|勝利/.test(t) && !/敗北/.test(t), mid = /小被害|苦戦/.test(t); setG(good ? 84 : mid ? 58 : 22); result(t, good, mid); } };
}
function goBattle() { // アクション戦闘へ移る。結果は battle_result に書かれ、戻ってきたときに反映する
  const R = G.raid, id = String(Date.now()), m = GM.battleMods(G); G.battle = { id }; writeSave();
  const al = Object.keys(GM.ALLY).filter(k => GM.fighter(k) && GM.joined(G, k) && !(k === 'ranka' && !R.ranka)).join(','); // 途中で参入する仲間の候補（戦闘の側でランダムに1人。ランカは街にいる週だけ）
  const q = new URLSearchParams({ battle: '1', id, waves: GM.wavesOf(R.E), name: R.name, dmg: m.dmg, bind: m.bind, hp: m.hp, al, boss: (R.boss || R.gen) ? 1 : 0, ret: 'terrain/index.html' });
  location.href = '../index.html?' + q.toString();
}
function takeBattleResult() {
  let r = null; try { r = JSON.parse(localStorage.getItem('battle_result') || 'null'); } catch (e) { }
  if (!r || !G.battle || !G.raid || r.id !== G.battle.id) return;
  try { localStorage.removeItem('battle_result'); } catch (e) { }
  G.battle = null; const t = GM.resolve(G, 'hand', Math.random, !!r.win); const sup = Math.max(0, Math.floor(+r.sup || 0)); if (sup) G.sup += sup; /* 戦場で拾った物資 */ endRaidFx(); commit(`${t}（撃破${r.kills}${sup ? `・物資+${sup}` : ''}）`); ui.modal(null); /* 出撃は週の報告がなく、起動時に開いた出撃の窓が残って止まっていた */ showReport();
}
// ---------- 襲撃の決断（一騎打ちの選出と同じ見た目：上＝敵将と戦場、下＝3つの迎え撃ち方）----------
const rdCss = document.createElement('style'); rdCss.textContent = `
#rdec{--u:min(.2326vw,.1073dvh);--ink:#2b1d10;--ink2:#5e4728;--gold:#a8833c;--teal:#2c6a64;--red:#a3362b;position:fixed;inset:0;z-index:9;display:none;flex-direction:column;overflow-x:hidden;overflow-y:auto;-webkit-overflow-scrolling:touch;touch-action:pan-y;
  font-family:'DMincho','Hiragino Mincho ProN','Yu Mincho',serif;font-weight:700;color:var(--ink);background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(760*var(--u)) auto repeat;-webkit-font-smoothing:antialiased}
#rdec.in{animation:rdin .35s ease-out}@keyframes rdin{from{opacity:0}}
#rdec *{box-sizing:border-box}#rdec button{font:inherit;color:inherit;cursor:pointer;border:0;background:none;padding:0}
#rdec .cn{position:absolute;width:calc(62*var(--u));aspect-ratio:220/153;background:url(assets/ui2/corner.webp) center/contain no-repeat;pointer-events:none;z-index:1;opacity:.92}
#rdec .cn.tl{left:calc(4*var(--u));top:calc(4*var(--u))}#rdec .cn.tr{right:calc(4*var(--u));top:calc(4*var(--u));transform:scaleX(-1)}
#rdec .hero{position:relative;flex:0 1 45%;min-height:28%;background-repeat:no-repeat;-webkit-mask-image:linear-gradient(#000 86%,transparent);mask-image:linear-gradient(#000 86%,transparent)}
#rdec .hero::before{content:'';position:absolute;left:-10%;top:-6%;width:74%;height:84%;background:radial-gradient(closest-side,#f3ead6e6,#f3ead6a0 55%,transparent);pointer-events:none}
#rdec .tt{position:absolute;left:calc(26*var(--u));top:calc(28*var(--u))}
#rdec .tt small{display:block;font-size:calc(12*var(--u));letter-spacing:.12em;color:var(--ink2)}
#rdec .tt img{display:block;width:calc(150*var(--u));margin:calc(3*var(--u)) 0 calc(4*var(--u))}
#rdec .tt h1{margin:0;font-size:calc(30*var(--u));font-weight:700;letter-spacing:.14em;line-height:1.15}#rdec .tt h1.boss{color:var(--red)}
#rdec .tt .nm{margin-top:calc(6*var(--u));font-size:calc(14.5*var(--u));letter-spacing:.06em}
#rdec .pn{position:relative;z-index:1;flex:1 0 auto;display:flex;flex-direction:column;align-items:center;padding:calc(2*var(--u)) calc(20*var(--u)) calc(44*var(--u))}
#rdec .vs{width:100%;display:flex;align-items:center;gap:calc(10*var(--u));font-size:calc(12.5*var(--u));letter-spacing:.04em;white-space:nowrap}
#rdec .vs b{font-size:calc(19*var(--u));margin-left:.2em}#rdec .vs .us b{color:var(--teal)}#rdec .vs .fo b{color:var(--red)}
#rdec .bal{flex:1;height:calc(12*var(--u));padding:1px;background:#2a1e12;border:1px solid #8c6c34;box-shadow:0 0 0 1px #e9dcbcaa;position:relative}
#rdec .bal::before{content:'';position:absolute;inset:1px;background:linear-gradient(#d4705c,#a3362b 60%,#86281f)}
#rdec .bal i{position:absolute;left:1px;top:1px;bottom:1px;background:linear-gradient(#5aa59a,#2c6a64 60%,#24564f)}
#rdec .bal u{position:absolute;top:50%;width:calc(14*var(--u));height:calc(14*var(--u));background:linear-gradient(135deg,#f6e2a0,#c99a3c);border:1px solid #5e4320;transform:translate(-50%,-50%) rotate(45deg)}
#rdec .pr{margin-top:calc(5*var(--u));font-size:calc(12.5*var(--u));letter-spacing:.08em;color:var(--ink2)}#rdec .pr b{color:var(--ink);font-size:1.15em}#rdec .pr b.ng{color:var(--red)}#rdec .pr b.ok{color:var(--teal)}
#rdec h2{margin:calc(10*var(--u)) 0 0;font-size:calc(23*var(--u));font-weight:700;letter-spacing:.12em}
#rdec .dv{width:calc(220*var(--u));margin:calc(2*var(--u)) 0 calc(10*var(--u))}
#rdec .ops{width:100%;display:flex;flex-direction:column;gap:calc(12*var(--u))}
#rdec .oc{position:relative;height:calc(118*var(--u));overflow:hidden;cursor:pointer;background:#ece2c8;border:1px solid #bba57a;box-shadow:inset 0 0 0 calc(3*var(--u)) #ece2c8,inset 0 0 0 calc(4*var(--u)) #cdb98e;transition:box-shadow .15s,background .15s}
#rdec .oc .im{position:absolute;left:0;top:0;bottom:0;width:30%;background-repeat:no-repeat;-webkit-mask-image:linear-gradient(90deg,#000 60%,transparent);mask-image:linear-gradient(90deg,#000 60%,transparent)}
#rdec .oc .tx{position:absolute;left:27%;right:calc(10*var(--u));top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;gap:calc(4*var(--u))}
#rdec .oc .t{font-size:calc(20*var(--u));letter-spacing:.1em;white-space:nowrap}#rdec .oc .t em{font-style:normal;font-size:calc(11*var(--u));color:var(--ink2);letter-spacing:.04em;margin-left:.7em}
#rdec .oc .l{font-size:calc(13.5*var(--u));letter-spacing:.02em;line-height:1.35;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#rdec .oc .l i{font-style:normal;display:inline-block;min-width:3.4em;color:var(--ink2)}#rdec .oc .l b{font-size:1.25em}#rdec .oc .ok{color:var(--teal)}#rdec .oc .ng{color:var(--red)}
#rdec .oc .c{font-size:calc(11.5*var(--u));color:var(--ink2);letter-spacing:.04em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#rdec .oc.on{background:#dfe5cc;border-color:#58775a;box-shadow:inset 0 0 0 calc(3*var(--u)) #dfe5cc,inset 0 0 0 calc(4*var(--u)) #8aa483,0 0 calc(10*var(--u)) #5a8a5f66}
#rdec .oc .ck{display:none;position:absolute;right:calc(7*var(--u));top:calc(7*var(--u));width:calc(24*var(--u));height:calc(24*var(--u));border-radius:50%;background:#2f4a3c;border:1px solid #c9d6bb;color:#f2f0e0;align-items:center;justify-content:center;font-size:calc(14*var(--u))}
#rdec .oc.on .ck{display:flex}
#rdec .rk{width:100%;margin-top:calc(8*var(--u));display:flex;align-items:center;gap:calc(10*var(--u));padding:calc(4*var(--u)) calc(8*var(--u));border-top:1px solid #bba57a;border-bottom:1px solid #bba57a}
#rdec .rk img{width:calc(40*var(--u));height:calc(40*var(--u));border-radius:50%;object-fit:cover;object-position:50% 8%;box-shadow:0 0 0 1px #a48a5c}
#rdec .rk span{flex:1;min-width:0;font-size:calc(14*var(--u));letter-spacing:.06em}#rdec .rk small{display:block;font-size:calc(10.5*var(--u));color:var(--ink2);letter-spacing:.02em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#rdec .rk button{flex:0 0 auto;min-width:calc(92*var(--u));height:calc(40*var(--u));background:url(assets/ui2/btn_cream.webp) center/100% 100% no-repeat;font-size:calc(13.5*var(--u));letter-spacing:.06em}
#rdec .rk>b{flex:0 0 auto;font-size:calc(13.5*var(--u));letter-spacing:.1em;color:var(--teal)}#rdec .rk button.on{background-image:url(assets/ui2/btn_teal.webp);color:#f3ead2;text-shadow:0 1px 2px #0006}#rdec .rk.off{opacity:.6}
#rdec .go{width:88%;height:calc(66*var(--u));margin-top:auto;background:url(assets/ui2/btn_teal.webp) center/100% 100% no-repeat;color:#f3ead2;font-size:calc(20*var(--u));letter-spacing:.16em;text-shadow:0 1px 2px #0006}
#rdec .go:active{filter:brightness(1.12)}
#rdec::after{content:'';position:absolute;left:0;right:0;bottom:0;height:calc(40*var(--u));background:url(assets/ui2/vine.webp) center bottom/100% 100% no-repeat;opacity:.85;pointer-events:none}`;
document.head.appendChild(rdCss);
const rdec = document.createElement('div'); rdec.id = 'rdec'; document.body.appendChild(rdec);
let rdSel = 'auto';
function raidModal() { // 襲撃・出撃の決断。選んでから大ボタンで決める（一騎打ちの選出と同じ2手）
  const R = G.raid; if (!R) { rdec.style.display = 'none'; ui.modal(null); return; } if (introPlaying || abt.style.display === 'flex' || duelEl.style.display === 'flex' || duelSel.style.display === 'flex') return;
  raidFx.classList.add('on'); ui.modal(null);
  R.ranka = GM.rankaReady(G); // 2026-10-30 街にいれば必ず出る（連戦できるので、温存の切り替えはやめた）
  const P = GM.raidPlan(G), D = Math.round(GM.raidD(G)), m = GM.battleMods(G), fr = GM.FRONT[R.dir], look = foeLook(), sortie = R.kind === 'sortie';
  const mods = [m.dmg > 1 ? `ダメージ+${Math.round((m.dmg - 1) * 100)}%` : '', m.bind ? `拘束+${m.bind}秒` : '', m.hp ? `最大HP+${m.hp}` : ''].filter(Boolean).join('・');
  const duel = P.duel ? '敵将が一騎打ちを挑む' : '';
  const ops = [
    { k: 'auto', t: '任せる', em: '仲間と兵が戦う', im: 'assets/npc/sol_1.webp', ip: '50% 12%/150% auto',
      l: [`<i>見込み</i><b class="${P.auto.ok ? 'ok' : 'ng'}">${P.auto.res}</b>`], c: [duel, '行動点は減らない'].filter(Boolean).join('・'), go: '仲間に任せる' },
    { k: 'act', t: '自分で戦う', em: `アクション・WAVE ${P.act.waves}`, im: '../sprites/idle_00.png', ip: '62% 30%/190% auto',
      l: [`<i>勝てば</i><span class="ok">${P.act.win}</span>`, `<i>負ければ</i><span class="ng">${P.act.lose}</span>`], c: [P.act.cost, mods.replace('最大HP', 'HP')].filter(Boolean).join('・'), go: '自ら剣を取る' }];
  if (!ops.some(o => o.k === rdSel)) rdSel = 'auto';
  let rk = '';
  if (GM.joined(G, 'ranka')) { const ready = GM.rankaReady(G), why = G.rankaAway ? '今週は街にいない（出られない）' : '';
    rk = `<div class="rk${ready ? '' : ' off'}"><img src="${porOf('ranka')}"><span>ランカ<small>${ready ? `防衛力+${GM.rankaD(G)}・ダメージ+${Math.round(GM.rankaDmg(G) * 100)}%` : why}</small></span>${ready ? '<b>出撃</b>' : ''}</div>`; }
  const pct = Math.max(8, Math.min(92, D / (D + R.E) * 100));
  const shown = rdec.style.display === 'flex';
  rdec.innerHTML = `<div class="hero" style="background-image:${bustBG(look)},url(assets/field/${R.dir || 'pass'}.jpg);background-size:cover,cover,cover;background-position:62% 0,62% 0,center"><div class="tt"><small>第${R.w || G.week}週${fr ? '・' + fr.n : ''}</small><img src="assets/ui2/divider2.webp"><h1 class="${R.boss || R.gen ? 'boss' : ''}">${sortie ? '出撃' : R.boss || R.gen ? '将軍の侵攻' : '敵襲'}</h1>${R.gen ? `<div class="nm">${GM.CHAPTERS[R.gen - 1].g}</div>` : R.boss || R.name === '敵襲' ? '' : `<div class="nm">${R.name}</div>`}</div></div>
    <div class="pn">
      <div class="vs"><span class="us">${sortie ? `戦力（兵${R.sent}）` : '防衛力'}<b>${D}</b></span><div class="bal"><i style="width:${pct}%"></i><u style="left:${pct}%"></u></div><span class="fo">敵<b>${R.E}</b></span></div>
      <h2>どう迎え撃つ？</h2><img class="dv" src="assets/ui2/divider2.webp">
      <div class="ops">${ops.map(o => `<div class="oc" data-k="${o.k}"><div class="im" style="background:url(${o.im}) ${o.ip} no-repeat"></div><div class="tx"><div class="t">${o.t}<em>${o.em}</em></div>${o.l.map(x => `<div class="l">${x}</div>`).join('')}<div class="c">${o.c}</div></div><div class="ck">✓</div></div>`).join('')}</div>
      ${rk}<button class="go"></button></div>`;
  const go = rdec.querySelector('.go'), mark = () => { rdec.querySelectorAll('.oc').forEach(c => c.classList.toggle('on', c.dataset.k === rdSel)); go.textContent = ops.find(o => o.k === rdSel).go; }; mark();
  rdec.querySelectorAll('.oc').forEach(c => { c.onclick = e => { e.stopPropagation(); rdSel = c.dataset.k; mark(); }; });
  go.onclick = e => { e.stopPropagation(); rdec.style.display = 'none'; const k = rdSel; rdSel = 'auto'; if (k === 'act') goBattle(); else fieldBattle(k); };
  if (!shown) { rdec.classList.remove('in'); void rdec.offsetWidth; rdec.classList.add('in'); }
  rdec.style.display = 'flex';
}
function overModal() {
  if (!G.over) return; if (G.chEnd) { chapterEndScene(overModal); return; }
  ui.modal(G.over === 'win' ? '勝利' : '敗北', `${G.why}（第${Math.min(G.week, GM.WEEKS)}週・第${GM.chapterOf(Math.min(G.week, GM.WEEKS))}章）<br>開拓した区域：${G.open.length}／${areas.length} ／ 施設：${Object.keys(G.plots).length}`, [{ label: '最初から', fn: () => { G = GM.newState(layout.areas); ui.modal(null); select(null); syncMap(true); commit('最初からやり直した'); setTimeout(chapterStartScene, 300); } }]);
}
// せりふ用の立ち絵（バストアップ、1人3枚まで）。せりふが変わるたびにランダムに選ぶ。なければ全身の立ち絵
const POR = {};
for (const k of Object.keys(GM.ALLY)) { const L = []; for (let i = 1; i <= 4; i++) { const im = await loadImage(`../ally/por_${k}_${i}.png`); if (im) L.push(`../ally/por_${k}_${i}.png`); } if (L.length) POR[k] = L; }
const porPick = {};
function porOf(k) { return POR[k] ? POR[k][porPick[k] || 0] : `../ally/${k}.png`; }
function newLine(k) { curLine = GM.lineOf(G, k); lineKey = k; if (POR[k]) porPick[k] = Math.floor(Math.random() * POR[k].length); }
let lineKey = '';
let advisorMsg = null; // 内政役の報告（吹き出し）。了解で閉じる
const why = (need) => (G.raid ? '襲撃の最中' : G.ap < 1 ? '行動点が足りない' : need && G.sup < need ? '物資が足りない' : '今はできない');
function defaultAlly() { const a = GM.advisorOf(G); return a && GM.joined(G, a) ? a : 'mina'; }
function refreshUI() {
  const r = GM.raidView(G), inc = GM.income(G), md = GM.moraleD(G), apMax = GM.apOf(G.morale), wk = Math.min(G.week, GM.WEEKS);
  ui.top({ title: `第${GM.chapterOf(wk)}章　${GM.CHAPTERS[GM.chapterOf(wk) - 1].t}`, week: wk, weeks: GM.WEEKS, raidWeeks: GM.SCHED.map(x => x.w), bossWeek: GM.SCHED.find(x => x.boss).w, genWeeks: GM.SCHED.filter(x => x.gen && !x.boss).map(x => x.w),
    band: { wk, next: r ? (r.inWeeks ? `次の襲撃まであと<b style="font-size:15px"> ${r.inWeeks} </b>週` : '今週末に襲撃') : '襲撃の予定はない', foe: r ? `敵 ${r.known ? r.E : r.lo + '〜' + r.hi}` : '' },
    res: [{ ic: 'sup', lab: '物資', val: G.sup, sub: `${sg(inc)}/週`, cls: inc >= 0 ? 'd' : 'n' }, { ic: 'mor', lab: '民心', val: Math.round(G.morale), bar: G.morale, col: G.morale < 30 ? '#e05a4a' : '#6ac06a' },
      { ic: 'trp', lab: '兵力', val: G.troops, bar: G.troops / 16 * 100, col: '#7aa8e0' }, { ic: 'def', lab: '防衛', val: Math.round(GM.D(G)) },
      { ic: 'hp', lab: '耐久', val: `${G.hp}/3` }, { ic: 'ap', lab: '行動', val: `${G.ap}/${apMax}`, sub: '●'.repeat(G.ap) + '○'.repeat(Math.max(0, apMax - G.ap)), cls: 'd' }] });
  renderActions(); if (G.raid) raidModal(); else { rdec.style.display = 'none'; const h = document.querySelector('#modal h3'); if (h && /^(出撃|襲撃)：/.test(h.textContent)) ui.modal(null); /* 終わった襲撃の窓を残さない */ if (G.over) overModal(); }
}
function renderActions() {
  if (!G) return; const L = []; let title = '', icon = 'build', por = null, bubble = null, key = 'none', mode = 'act';
  const P = k => ({ src: porOf(k), bust: !!POR[k], face: faceURL[k], name: `${GM.ALLY[k].n}（${GM.ALLY[k].r}）` });
  if (advisorMsg) { const k = defaultAlly(); ui.panel({ key: 'adv' + G.week, icon: 'ally', title: `${GM.ALLY[k].n}の報告`, por: P(k), bubble: advisorMsg, items: [{ label: '了解', act: '', verb: '了解', fn: () => { advisorMsg = null; refreshUI(); } }], week: weekBtn(), mode: 'talk' }); return; }
  if (selSign) { key = 'sign' + selSign.id; icon = 'flag'; const a = selSign.area && areas.find(q => q.id === selSign.area); const ad = a && G.areaDefs.find(q => q.id === a.id);
    title = `目印・${selSign.label}`;
    if (ad && !G.open.includes(ad.id)) { const c = GM.chapterOfArea(ad.id); bubble = c ? `第${c}章「${GM.CHAPTERS[c - 1].t}」で、この地へ進みます。` : 'この先は、まだ道が拓けていません。'; }
    else bubble = ad ? 'この地はもう姫の領地です。' : 'この先は、まだ道が拓けていません。'; }
  else if (selAlly) { const k = selAlly, A = GM.ALLY[k], b = G.bond[k] || 0, at = G.assign[k]; if (lineKey !== k) newLine(k); key = 'ally' + k; icon = 'ally'; por = P(k); bubble = curLine; mode = 'talk';
    title = `${A.n}　絆 ${'●'.repeat(b)}${'○'.repeat(3 - b)}`;
    if (b < 3) L.push({ label: '過ごす', act: `${A.n}と過ごす`, ap: 1, eff: `絆${b + 1}${A.lv[b + 1] ? '：' + A.lv[b + 1] : ''}`, verb: '過ごす', can: GM.canTalk(G, k), why: why(), fn: () => act(() => GM.talk(G, k), `${A.n}と過ごした`) });
    if (at) L.push({ label: '配置を外す', act: `${FAC[G.plots[at].fac].n}（${at}）から外す`, eff: '広場へ戻る', verb: '外す', fn: () => act(() => GM.unassign(G, k), `${A.n}を広場へ戻した`) }); }
  else if (selCastle) { key = 'castle'; icon = 'castle'; title = '城'; por = P(defaultAlly());
    for (const [id, c] of Object.entries(GM.CASTLE)) L.push({ label: c.t, act: c.t, sup: id === 'levy' ? 5 : -c.cost, ap: 1, eff: c.d, verb: c.t, can: GM.canCastle(G, id), why: GM.castleWhy(G, id) || why(c.cost), fn: () => act(() => { const ok = GM.doCastle(G, id); if (ok && G.raid) setTimeout(raidModal, 0); return ok; }, c.t + 'を行った') }); }
  else if (selected) { const id = selected.id, p = G.plots[id], here = p && GM.allyAt(G, id); key = 'plot' + id + (p ? p.fac + p.stage + (here || '') : '');
    if (here && lineKey !== here) newLine(here); por = P(here || defaultAlly()); if (here) { bubble = curLine; mode = 'talk'; }
    if (!p) { title = '建設予定地'; for (const [f, d] of Object.entries(FAC)) L.push({ label: d.n, act: f === 'farm' ? '畑を整備' : `${d.n}を建てる`, sup: -d.cost, ap: 1, eff: (d.d.startsWith('毎週の') ? `毎週 ${d.d.replace('毎週の', '')}` : d.d) + (GM.dimNote(G, f) ? `（${GM.dimNote(G, f)}）` : ''), verb: '建設する', can: GM.canBuild(G, f, id), why: GM.buildWhy(G, f, id) || why(d.cost), fn: () => act(() => GM.build(G, id, f), `${d.n}の建築を始めた（週末に完成）`) }); }
    else { const d = FAC[p.fac]; title = `${d.n}（${p.burnt ? '焼かれた' : STAGE[p.stage]}）${here ? '・' + GM.ALLY[here].n : ''}`;
      if (p.burnt) L.push({ label: '修理', act: `${d.n}を修理する`, sup: -GM.REPAIR, ap: 1, eff: '効果が戻る', verb: '修理する', can: GM.canRepair(G, id), why: why(GM.REPAIR), fn: () => act(() => GM.repair(G, id), `${d.n}を修理した`) });
      if (p.stage === 1 && !here) title += '・週末に完成';
      if (p.stage === 2) L.push({ label: '発展', act: `${d.n}を発展させる`, sup: -d.up, ap: 1, eff: d.ud || '効果が2倍になる', verb: '発展させる', can: GM.canUpgrade(G, id), why: why(d.up), fn: () => act(() => GM.upgrade(G, id), `${d.n}を発展させた`) });
      if (p.stage >= 2 && !d.noStaff) {
        for (const k of Object.keys(GM.ALLY)) { if (!GM.joined(G, k) || k === here) continue; const A = GM.ALLY[k], bon = GM.assignBonus(p.fac, k), fit = GM.AFFINITY[p.fac].includes(k);
          L.push({ label: `${A.n}を配置`, act: `${A.n}を配置する${fit ? '（得意）' : ''}`, eff: `${p.fac === 'smithy' ? '兵1人の強さ' : '効果'} +${bon}${k === 'lily' && G.assign.ranka && GM.PLOT_AREA[G.assign.ranka] === GM.PLOT_AREA[id] ? '・ランカと同じ区域：ランカ+50%' : ''}${G.assign[k] ? '・今の配置から移る' : ''}`, verb: '配置する', can: GM.canAssign(G, k, id), why: why(), fn: () => act(() => GM.assign(G, k, id), `${A.n}を${d.n}に配置した`) }); }
        if (here) L.push({ label: `${GM.ALLY[here].n}を外す`, act: `${GM.ALLY[here].n}を外す`, eff: '広場へ戻る', verb: '外す', fn: () => act(() => GM.unassign(G, here), `${GM.ALLY[here].n}を広場へ戻した`) }); }
      L.push({ label: '取り壊す', act: `${d.n}を取り壊す`, eff: '行動点は使わない。配置は外れる', verb: '取り壊す', fn: () => act(() => GM.demolish(G, id), `${d.n}を取り壊した`) }); } }
  else { const k = defaultAlly(); por = P(k); title = '陛下の領地'; icon = 'flag'; key = 'idle';
    const w = GM.weekReport(GM.snap(G), G).warns; bubble = w.length ? w[0] : '区画・城・仲間・目印をタップしてください。'; mode = 'mini'; }
  ui.panel({ key, icon, title, por, bubble, items: L, week: weekBtn(), mode });
}
function weekBtn() { const inc = GM.income(G), md = GM.moraleD(G); return { label: G.raid ? '襲撃を迎える' : '週を終える', sub: `物資${sg(inc)} 民心${sg(md)}`, hot: G.ap === 0 || !!G.raid, disabled: !!G.over }; }
// ---------- 視点（パン・ズーム） ----------
const view = { cx: AREA0_W / 2, cz: zOf(REF_H * .5), zoom: 1 };
let fitZoom = 1, W = 1, H = 1;
if (params.has('debug')) document.getElementById('st').style.display = 'block';
const bg = document.getElementById('bg'), hud = document.getElementById('hud'), st = document.getElementById('st');
{ // 遠景（空と山）は、世界の幅まで左右反転でつなぐ
  const im = await loadImage('assets/backdrop.jpg');
  if (im && REF_W > im.width) { const c = document.createElement('canvas'), n = Math.ceil(REF_W / im.width); c.width = im.width * n; c.height = im.height; const g = c.getContext('2d');
    for (let i = 0; i < n; i++) { g.save(); if (i % 2) { g.translate(im.width * (i + 1), 0); g.scale(-1, 1); g.drawImage(im, 0, 0); } else g.drawImage(im, im.width * i, 0); g.restore(); }
    document.getElementById('bg').src = c.toDataURL('image/jpeg', .9); }
}
function resize() {
  W = window.innerWidth; H = window.innerHeight; renderer.setSize(W, H, false);
  camera.left = -W / 2; camera.right = W / 2; camera.top = H / 2; camera.bottom = -H / 2; camera.updateProjectionMatrix();
  fitZoom = Math.min(W / AREA0_W, H / REF_H * 1.0);
  if (!view._init) { view.zoom = Math.max(W / AREA0_W, H / REF_H); view._init = true; view.cx = AREA0_W / 2; view.cz = zOf(REF_H * .62); }
  clampView();
}
function clampView() {
  const cover = Math.max(W / AREA0_W, H / REF_H); view.zoom = Math.min(Math.max(view.zoom, cover), cover * 5);
  const halfW = W / view.zoom / 2, halfH = H / view.zoom / 2;
  const minSy = halfH, maxSy = REF_H - halfH; view.cz = zOf(Math.min(Math.max(syOf(view.cz), minSy), Math.max(minSy, maxSy)));
  view.cx = halfW * 2 >= REF_W ? REF_W / 2 : Math.min(Math.max(view.cx, halfW), REF_W - halfW);
}
function apply() {
  const d = 3000, tx = view.cx, tz = view.cz, ty = hgt(tx, tz) * 0;
  camera.zoom = view.zoom; camera.updateProjectionMatrix();
  camera.position.set(tx, ty + SIN * d, tz + COS * d); camera.lookAt(tx, ty, tz);
  // 背景画像（遠景）も同じ変換にする
  const Z = view.zoom, sc = syOf(view.cz);
  bg.style.transform = `translate(${W / 2 - view.cx * Z}px,${H / 2 - sc * Z}px) scale(${Z})`;
}
let pointers = new Map(), drag = null, pinch = null;
canvas.addEventListener('pointerdown', e => { canvas.setPointerCapture(e.pointerId); pointers.set(e.pointerId, { x: e.clientX, y: e.clientY }); if (pointers.size === 1) drag = { x0: e.clientX, y0: e.clientY, moved: false, cx: view.cx, cz: view.cz }; if (pointers.size === 2) { const [a, b] = [...pointers.values()]; pinch = { d: Math.hypot(a.x - b.x, a.y - b.y), z: view.zoom }; drag = null; } });
canvas.addEventListener('pointermove', e => {
  if (!pointers.has(e.pointerId)) return; pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (pinch && pointers.size >= 2) { const [a, b] = [...pointers.values()]; view.zoom = pinch.z * Math.hypot(a.x - b.x, a.y - b.y) / pinch.d; clampView(); return; }
  if (drag) { const dx = e.clientX - drag.x0, dy = e.clientY - drag.y0; if (!drag.moved && Math.hypot(dx, dy) > 10) drag.moved = true; if (drag.moved) { view.cx = drag.cx - dx / view.zoom; view.cz = drag.cz - dy / (view.zoom * SIN); clampView(); } }
});
function pickAt(cx, cy) { // 画面の点 → 基準画像の座標（高さ0の地面）
  const Z = view.zoom, sx = view.cx + (cx - W / 2) / Z, sy = syOf(view.cz) + (cy - H / 2) / Z; return [sx, sy];
}
canvas.addEventListener('pointerup', e => {
  if (drag && !drag.moved) {
    const [sx, sy] = pickAt(e.clientX, e.clientY);
    const sgn = signs.find(q => !lockedAt(q.x) && Math.abs(sx - q.x) < 44 && sy > q.y - 110 && sy < q.y + 10);
    if (G.raid || G.over) { refreshUI(); }
    else if (sgn) { select(null); selSign = sgn; refreshUI(); }
    else if (lockedAt(sx)) select(null);
    else if (hitAlly(sx, sy)) { const k = hitAlly(sx, sy); select(null); selAlly = k; newLine(k); refreshUI(); }
    else { const pl = hitBuilding(sx, sy); if (!pl && hitCastle(sx, sy)) { select(null); selCastle = true; refreshUI(); } else select(pl || plots.find(p => pointInPoly(sx, sy, p.poly)) || null); }
  }
  pointers.delete(e.pointerId); if (pointers.size < 2) pinch = null; if (!pointers.size) drag = null;
});
canvas.addEventListener('pointercancel', e => { pointers.delete(e.pointerId); pinch = null; drag = null; });
canvas.addEventListener('wheel', e => { e.preventDefault(); const [sx, sy] = pickAt(e.clientX, e.clientY); const f = Math.exp(-e.deltaY * .0012); view.zoom *= f; clampView(); const [sx2, sy2] = pickAt(e.clientX, e.clientY); view.cx += sx - sx2; view.cz += (sy - sy2) / SIN; clampView(); }, { passive: false });
window.addEventListener('resize', resize);

// ---------- ループ ----------
let last = performance.now(), frames = 0, acc = 0, fx = [];
function frame(now) {
  const dt = now - last; last = now; acc += dt; frames++;
  if (duelEl.style.display === 'flex' || duelSel.style.display === 'flex') { requestAnimationFrame(frame); return; } // 一騎打ちの全画面の間は、裏の地図を描かない（重さ対策）
  groundMat.uniforms.time.value = now / 1000; selGlow.opacity = .38 + .2 * Math.sin(now / 260);
  walkAllies(Math.min(.05, dt / 1000)); badges.forEach((b, i) => { b.position.y = b.userData.y0 + Math.sin(now / 400 + i) * 2; }); fireMeshes.forEach(f => { if (!f.parent) { fireMeshes.delete(f); return; } if (!f.userData.s) f.userData.s = f.scale.clone(); const k = 1 + Math.sin(now / 90 + f.id) * .06, g = f.userData.ign ? Math.min(1, (now - f.userData.ign) / 1200) : 1, ge = Math.max(.1, g * (2 - g)); f.scale.set(f.userData.s.x * (2 - k) * (.5 + .5 * ge), f.userData.s.y * k * ge, 1); }); burnUpdate(now);
  waterMats.forEach(mt => { if (mt.userData.sh) mt.userData.sh.uniforms.time.value = now / 1000; }); fx.forEach(f => f(now)); fx = fx.filter(f => !f.done);
  apply(); renderer.render(scene, camera);
  if (acc > 500) { st.textContent = `3D: ${status.ok ? 'OK' : status.reason} / 地面:${status.ground} 小物:${status.sprites}(${status.props}) / ${(frames * 1000 / acc).toFixed(0)}fps / 拡大 ${view.zoom.toFixed(2)}`; frames = 0; acc = 0; }
  // HUD は refreshUI() が書く
  requestAnimationFrame(frame);
}
canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); status.ok = false; status.reason = 'WebGLが失われた'; });
G = loadSave() || GM.newState(layout.areas); syncMap(true); refreshUI(); takeBattleResult();
if (params.has('field')) { const sv = JSON.stringify(G); for (const a of Object.values(GM.ALLY)) if (a.join && !G.open.includes(a.join)) G.open.push(a.join); G.met = Object.assign({}, G.met, { lily: true }); /* 出来事で加入する仲間（リリィ）も試しでは選べる */ G.raid = { kind: 'raid', E: 46, name: '将軍の侵攻（試し）', boss: true, w: GM.WEEKS, dir: 'pass', ranka: false }; G.troops = Math.max(G.troops || 0, 6); fieldBattle('auto', () => { G = JSON.parse(sv); writeSave(); refreshUI(); ui.toast('試しの戦闘を終えた（記録は残らない）'); }); } // ?field で任せた戦闘だけ見る
if (params.has('duel')) { const sv = JSON.stringify(G); for (const a of Object.values(GM.ALLY)) if (a.join && !G.open.includes(a.join)) G.open.push(a.join); G.met = Object.assign({}, G.met, { lily: true }); /* 出来事で加入する仲間（リリィ）も試しでは選べる */ G.rankaAway = false; G.rankaRest = false; // 試しは仲間4人とも選べる（ランカも）
  G.raid = { kind: 'raid', E: 46, name: '将軍の侵攻（試し）', boss: true, w: GM.WEEKS, dir: 'pass', ranka: true }; maybeDuel(() => { G = JSON.parse(sv); writeSave(); refreshUI(); ui.toast('試しの一騎打ちを終えた（記録は残らない）'); }); } // ?duel で一騎打ちだけ見る
resize(); apply(); renderer.render(scene, camera); status.ok = true; if (window.__bootDone) window.__bootDone();
window.__t.castle = () => { select(null); selCastle = true; refreshUI(); }; // 試験：城を選ぶ
window.__t.selAlly = k => { select(null); selAlly = k; newLine(k); refreshUI(); }; window.__t.sync = () => { syncMap(); refreshUI(); writeSave(); }; // 試験：仲間を選ぶ／状態を画面へ
window.__t.setView = (zoom, sx, sy) => { view.zoom = zoom; view.cx = sx; view.cz = zOf(sy); clampView(); apply(); renderer.render(scene, camera); };
window.__t.playDuel = playDuel; window.__t.fieldBattle = fieldBattle; window.__t.maybeDuel = maybeDuel; window.__t.raidIntro = raidIntro; window.__t.allyMesh = allyMesh; window.__t.select = id => select(plots.find(p => p.id === id) || null);
window.__t.plots = plots; window.__t.G = () => G; window.__t.playDuel = playDuel; window.__t.fieldBattle = fieldBattle; window.__t.maybeDuel = maybeDuel; window.__t.raidIntro = raidIntro; window.__t.camp = () => camp && camp.map(c => [c.position.x|0, c.position.y|0, c.position.z|0, c.visible]); window.__t.faces = () => faceURL; window.__t.raidIntro = raidIntro; window.__t.raidModal = raidModal; window.__t.showReport = showReport; window.__t.openMorning = openMorning; window.__t.GM = GM; window.__t.commit = () => commit(); window.__t.reset = () => { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } }; window.__t.pickAt = (cx, cy) => pickAt(cx, cy); window.__t.view = view; window.__t.sel = () => selected && selected.id; window.__t.build = (id, fac, stage) => { if (stage) G.plots[id] = { fac, stage }; else delete G.plots[id]; commit(); };
requestAnimationFrame(frame);
if (!params.has('duel') && !params.has('field')) setTimeout(chapterStartScene, 400); // 新しいゲームの第1章、または保存の途中の章の始まり
window.__t.story = (c, kind) => playStory(c, kind || 'start', () => refreshUI());
