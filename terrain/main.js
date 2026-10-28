// 領地の地形テスト：地形は three.js（正射影・傾き固定）、小物は切り抜き板、区画はコードのデータ。
// 座標の約束：基準画像（①）の画素座標 (sx, sy) を使う。地面 (x, z) は x=sx、z=(sy-SY0)/sinE。
import * as THREE from './vendor/three.module.min.js';
import * as GM from './game.js?v=1793191333';
import { createUI } from './ui.js?v=1793191333';

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
function loadImage(src) { return new Promise(res => { const im = new Image(); im.onload = () => res(im); im.onerror = () => res(null); im.src = src; }); }
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
const selMat = new THREE.MeshBasicMaterial({ color: 0xffe08a, transparent: true, opacity: .95, depthTest: false, side: THREE.DoubleSide });
const selGlow = new THREE.MeshBasicMaterial({ color: 0xffc040, transparent: true, opacity: .3, depthTest: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending });
let selGroup = null, selected = null, selSign = null;
function pointInPoly(x, y, poly) { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; }
function select(p) {
  selSign = null; selCastle = false; selAlly = null;
  if (selGroup) { scene.remove(selGroup); selGroup = null; }
  selected = p; if (G && p && GM.allyAt(G, p.id)) curLine = GM.lineOf(G, GM.allyAt(G, p.id)); if (G) refreshUI(); if (!p) return;
  // 金色に光る枠（モックの選択表示）：外側に広げた形から内側をくり抜いた帯＋外のにじみ
  const ring = (k0, k1, mat) => { const cx = p.poly.reduce((a, q) => a + q[0], 0) / 4, cy = p.poly.reduce((a, q) => a + q[1], 0) / 4, g = (k) => p.poly.map(([x, y]) => new THREE.Vector2(cx + (x - cx) * k, zOf(cy + (y - cy) * k)));
    const sh = new THREE.Shape(g(k1)); sh.holes.push(new THREE.Path(g(k0).reverse())); const geo = new THREE.ShapeGeometry(sh); geo.rotateX(Math.PI / 2);
    const m = new THREE.Mesh(geo, mat); m.position.y = hgt(cx, zOf(cy)) + 5; m.renderOrder = 10; return m; };
  const fix = ring(.99, 1.07, selMat), line = ring(1.07, 1.24, selGlow);
  selGroup = new THREE.Group(); selGroup.add(fix, line); scene.add(selGroup);
}

// ---------- 施設（区画の状態：0=空き地 1=建築中 2=完成 3=発展後）----------
const FAC = GM.FAC, STAGE = GM.STAGE, ART = ['smithy', 'tavern', 'farm']; // 絵のある施設。畑はコードで描く
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
function groundRect(tex, left, top, w, h) { // 画面の矩形（基準画像の画素）を、高さ0の地面に貼る
  const P = [[left, top + h], [left + w, top + h], [left + w, top], [left, top]], pos = [];
  P.forEach(([x, sy]) => { const z = zOf(sy); pos.push(x, hgt(x, z) + .6, z); });
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, 1, 0, 1, 1, 0, 1], 2)); g.setIndex([0, 1, 2, 0, 2, 3]);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: tex, transparent: true, alphaTest: .4, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, side: THREE.DoubleSide })); m.frustumCulled = false; return m;
}
const fireMeshes = new Set();
let fireTex = null;
function refreshPlot(pl) {
  if (!fireTex) fireTex = canvasSprite(96, 160, g => { // 炎と煙（コード描画）
    for (let i = 0; i < 6; i++) { const r = g.createRadialGradient(48, 30 + i * 8, 2, 48, 30 + i * 8, 34 - i * 2); r.addColorStop(0, 'rgba(70,60,60,.5)'); r.addColorStop(1, 'rgba(40,35,35,0)'); g.fillStyle = r; g.fillRect(0, 0, 96, 160); }
    const f = g.createRadialGradient(48, 128, 4, 48, 118, 40); f.addColorStop(0, '#fff6c0'); f.addColorStop(.3, '#ffb030'); f.addColorStop(.7, 'rgba(255,60,10,.8)'); f.addColorStop(1, 'rgba(255,40,0,0)');
    for (const [x0, h, w] of [[30, 70, 16], [48, 92, 20], [66, 64, 15], [40, 52, 12], [58, 78, 14]]) { const fl = g.createLinearGradient(0, 160, 0, 160 - h); fl.addColorStop(0, '#fff2b0'); fl.addColorStop(.35, '#ffa020'); fl.addColorStop(.8, 'rgba(230,50,10,.85)'); fl.addColorStop(1, 'rgba(200,30,0,0)');
      g.fillStyle = fl; g.beginPath(); g.moveTo(x0 - w, 158); g.quadraticCurveTo(x0 - w * .8, 160 - h * .5, x0, 160 - h); g.quadraticCurveTo(x0 + w * .8, 160 - h * .5, x0 + w, 158); g.closePath(); g.fill(); } });
  if (pl.pav) { scene.remove(pl.pav); pl.pav.geometry.dispose(); pl.pav = null; }
  if (pl.mesh) { scene.remove(pl.mesh); pl.mesh.material.dispose(); pl.mesh = null; }
  pl.hit = null; pl.poly = pl.home;
  const key = `${pl.fac}_${pl.stage}`, t = pl.fac && pl.stage >= 1 ? bldTex[key] : null;
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
  }
  pl.stakes.visible = !(pl.fac && pl.stage >= 1);
  if (pl.fire) { scene.remove(pl.fire); pl.fire = null; }
  if (pl.burnt) { [pl.mesh, pl.pav].forEach(mm => mm && mm.material.color.setRGB(.2, .16, .14)); // 焼かれた施設：黒ずませ、火と煙を出す
    pl.fire = sprite3D(fireTex, { w: 96, h: 160, ax: .5, ay: .95 }, .55, pl.cx, pl.base[1] - 30); pl.fire.position.y += (pl.hit && pl.fac !== 'farm' ? (pl.base[1] - pl.hit.top) * .45 : 10) / COS; pl.fire.renderOrder = 20; scene.add(pl.fire); fireMeshes.add(pl.fire); }
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
const ALLY_POS = { mina: [372, 1066], garou: [568, 1066], sera: [505, 1090], ranka: [435, 1090] };
const allyMesh = {};
for (const k of Object.keys(GM.ALLY)) {
  const mapIm = await loadImage(`../ally/map_${k}.png`), im = mapIm || await loadImage(`../ally/${k}.png`); if (!im) continue; // マップ用の小さな絵（等角）。なければ立ち絵
  const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  const [x, y] = ALLY_POS[k], sc = mapIm ? 76 / 635 : 74 / im.height; /* マップ用の絵は4人共通の縮尺（背の違いを残す） */ const m = sprite3D(t, { w: im.width, h: im.height, ax: .5, ay: .98 }, sc, x, y); m.visible = false; scene.add(m);
  allyMesh[k] = { m, x, y, w: im.width * sc, h: im.height * sc };
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
function walkAllies(dt) {
  for (const k of Object.keys(allyMesh)) { const a = allyMesh[k]; if (!a.m.visible) continue;
    if (a.wait > 0) { a.wait -= dt; if (a.wait <= 0) [a.tx, a.ty] = walkTarget(); continue; }
    const dx = a.tx - a.x, dy = a.ty - a.y, d = Math.hypot(dx, dy * 1.6); if (d < 2) { a.wait = 2 + Math.random() * 4; continue; }
    const sp = 22 * dt; placeAlly(k, a.x + dx / d * Math.min(sp, d), a.y + dy / d * Math.min(sp, d)); a.m.scale.x = Math.abs(a.sx) * (dx < 0 ? -1 : 1);
    a.m.position.y += Math.abs(Math.sin(performance.now() / 140)) * 1.6; }
}
const faceTex = {}, faceURL = {};
const FACE = { mina: [178, 74, 56], garou: [247, 50, 58], sera: [150, 64, 54], ranka: [180, 62, 56] }; // 立ち絵の顔の中心と半径（画素）
async function makeFace(k) { // 立ち絵の顔を丸く切り抜いて、金の縁をつける
  const im = await loadImage(`../ally/${k}.png`); if (!im) return null; const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.fillStyle = '#2a1a0c'; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.fill(); g.save(); g.beginPath(); g.arc(64, 64, 54, 0, 7); g.clip();
  const [fx, fy, fr] = FACE[k] || [im.width / 2, 70, 60], s = fr * 2.3; g.drawImage(im, fx - s / 2, fy - s / 2, s, s, 10, 10, 108, 108); g.restore();
  g.strokeStyle = '#e8c060'; g.lineWidth = 7; g.beginPath(); g.arc(64, 64, 56, 0, 7); g.stroke(); g.strokeStyle = '#5a3a10'; g.lineWidth = 2; g.beginPath(); g.arc(64, 64, 60, 0, 7); g.stroke();
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
function loadSave() { try { const v = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (v && v.week) { v.bond = Object.assign({ mina: 0, garou: 0, sera: 0, ranka: 0 }, v.bond || {}); v.assign = v.assign || {}; return v; } return null; } catch (e) { return null; } }
function writeSave() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); } catch (e) { } }
function syncMap(instant) { // 状態 → 区画の絵と霧
  for (const pl of plots) { const p = G.plots[pl.id]; const f = p ? p.fac : null, stg = p ? p.stage : 0; const bt = !!(p && p.burnt); if (pl.fac !== f || pl.stage !== stg || pl.burnt !== bt) { pl.burnt = bt; setPlot(pl, f, stg); } }
  updateCamp();
  for (const a of areas) showArea(a, G.open.includes(a.id)); updateFog(instant);
  for (const k of Object.keys(allyMesh)) { const v = GM.joined(G, k); if (v && !allyMesh[k].m.visible && !instant) ui.toast(`${GM.ALLY[k].n}（${GM.ALLY[k].r}）が仲間になった`); allyMesh[k].m.visible = v && !(k === 'ranka' && G.rankaAway); }
  refreshBadges();
}
const ui = createUI({ onEndWeek: () => endWeek(), onReset: () => { G = GM.newState(layout.areas); select(null); syncMap(true); commit('最初からやり直した'); } });
function commit(msg) { writeSave(); syncMap(); refreshUI(); if (msg) ui.toast(msg); }
function act(fn, ok) { if (fn()) commit(ok); else ui.toast('できない（行動点か物資が足りない）'); }
const sg = n => (n >= 0 ? '+' : '') + n;
function endWeek() {
  if (G.over) return; if (G.raid) { raidModal(); return; }
  G.repPrev = GM.snap(G); const msg = GM.endWeek(G); select(null);
  if (G.raid) { ui.toast(msg); raidIntro(() => { writeSave(); refreshUI(); }); commit(null); } else { commit(msg); showReport(); }
}
function showReport() { // 週末の報告。参謀がいれば吹き出し、いなければ羊皮紙
  if (!G.repPrev || G.raid) return; if (G.over) { G.repPrev = null; return; } const R = GM.weekReport(G.repPrev, G); G.repPrev = null; writeSave();
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
function updateCamp() { // 襲撃の2週前から、敵の陣が街の外に見え、週ごとに近づく
  if (camp) { camp.forEach(c => scene.remove(c)); camp = null; }
  const r = GM.raidView(G); if (!r || r.inWeeks > 2 || G.raid) return; const F = FRONTS[r.dir]; if (!F) return;
  const [x, y] = F.camp[2 - r.inWeeks]; camp = [];
  const add = (t, meta, sc, dx, dy) => { const s = sprite3D(t, meta, sc, x + dx, y + dy); scene.add(s); camp.push(s); };
  add(tentTex, { w: 120, h: 90, ax: .5, ay: .93 }, .42, 0, 0); add(tentTex, { w: 120, h: 90, ax: .5, ay: .93 }, .34, -34, 16);
  if (TOWN.torch) add(townTex.torch || (townTex.torch = Object.assign(new THREE.Texture(TOWN.torch), { needsUpdate: true, colorSpace: THREE.SRGBColorSpace })), { w: TOWN.torch.width, h: TOWN.torch.height, ax: .5, ay: .96 }, .14, 26, 10);
  for (let i = 0; i < Math.min(6, 2 + Math.round(r.E / 10)); i++) add(foeTex, { w: 64, h: 96, ax: .5, ay: .94 }, .36, -20 + i * 14 + (i % 2) * 6, 26 + (i % 2) * 8);
}
function raidIntro(done) { // 空が赤くなり、陣から軍勢が街道を進み、前線で止まる。帯で名前を出してから、窓を開く
  const R = G.raid; introPlaying = true; ui.modal(null); if (camp) { camp.forEach(c => scene.remove(c)); camp = null; }
  const F = FRONTS[R.dir] || FRONTS.pass, src = F.camp[2], dst = F.front, n = Math.min(26, 6 + Math.round(R.E / 2));
  view.zoom = Math.max(view.zoom, .75); view.cx = (src[0] + dst[0]) / 2 + 120; view.cz = zOf(dst[1] + 230); clampView(); /* 前線は画面の上寄り（窓に隠れない） */
  foes.forEach(f => scene.remove(f.m)); foes = [];
  const dx = dst[0] - src[0], dy = dst[1] - src[1], L = Math.hypot(dx, dy), nx = -dy / L, ny = dx / L;
  for (let i = 0; i < n; i++) { const a = (Math.random() - .5) * 70, back = Math.random() * 90, m = sprite3D(foeTex, { w: 64, h: 96, ax: .5, ay: .94 }, .42 * (R.boss && i === 0 ? 1.8 : 1), src[0], src[1]); scene.add(m);
    foes.push({ m, x0: src[0] - dx / L * (60 + back) + nx * a, y0: src[1] - dy / L * (60 + back) + ny * a * .6, x1: dst[0] - dx / L * back * .5 + nx * a, y1: dst[1] - dy / L * back * .5 + ny * a * .6, d: Math.random() * .5 }); }
  raidFx.classList.add('on'); const t0 = performance.now();
  const f = now => { const t = (now - t0) / 2800;
    foes.forEach(o => { const k = Math.min(1, Math.max(0, (t - o.d * .3) / .8)), e = k * (2 - k), x = o.x0 + (o.x1 - o.x0) * e, y = o.y0 + (o.y1 - o.y0) * e, z = zOf(y); o.m.position.set(x, hgt(x, z) + Math.abs(Math.sin(now / 110 + o.d * 9)) * 2 * (k < 1), z); });
    if (t > .35 && !f.b) { f.b = 1; const fr = GM.FRONT[R.dir]; raidBan.innerHTML = `<div>${R.boss ? '将軍の侵攻' : '敵襲'}<small>${R.name}・規模 ${R.E}／${fr ? fr.n + 'で迎え撃つ' : ''}</small></div>`; raidBan.className = 'on'; }
    if (t > 1.05 && !f.c) { f.c = 1; raidBan.className = 'off'; }
    if (t > 1.2) { f.done = true; introPlaying = false; done && done(); } };
  fx.push(f);
}
function endRaidFx() { raidFx.classList.remove('on'); foes.forEach(f => scene.remove(f.m)); foes = []; raidBan.className = ''; }
function autoBattle(resolveFn) { // 任せた戦闘：仲間と兵が軍勢とぶつかり、押し合いの末に結果が出る（約3秒、タップで飛ばせる）
  const R = G.raid, usD = GM.raidD(G), E = R.E;
  const team = Object.keys(GM.ALLY).filter(k => GM.joined(G, k) && !(k === 'ranka' && (G.rankaAway || !R.ranka))).slice(0, 4);
  const t = resolveFn(); // 先に結果を決め、演出をその結果に合わせる
  const good = /被害なし|完勝|勝利/.test(t) && !/敗北/.test(t), mid = /小被害|苦戦/.test(t);
  const label = good ? '勝利' : mid ? '辛勝' : /大被害|敗北|敗走/.test(t) ? '敗北' : '苦戦', col = good ? '#ffd770' : mid ? '#ffe0a0' : '#ff7a6a';
  abt.innerHTML = `<div class="st"><div class="ttl">${R.name}</div><div class="sides"><div class="us">${team.map(k => `<img src="../ally/map_${k}.png" onerror="this.src='../ally/${k}.png'">`).join('')}<span class="tr">兵 ${G.troops}</span></div>
    <div class="foe"><div class="army">${'💀'.repeat(Math.min(7, Math.ceil(E / 7)))}</div><span class="tr">敵 ${E}</span></div><div class="clash"></div></div>
    <div class="bar"><span style="width:50%"></span></div><div class="nums"><span>防衛力 ${Math.round(usD)}</span><span>敵の規模 ${E}</span></div>
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
#duel{position:fixed;inset:0;z-index:10;display:none;overflow:hidden;background:#000 center/cover no-repeat;font-family:"Hiragino Mincho ProN","Yu Mincho",serif;color:#fff}
#duel .stage{position:absolute;left:0;right:0;top:50%;height:56vw;max-height:420px;transform:translateY(-50%);background:inherit;background-size:cover;background-position:center 70%;box-shadow:0 0 0 100vh #000c}
#duel .f{position:absolute;bottom:6%;height:78%;transition:transform .18s ease-out,filter .08s}
#duel .f img{height:100%;filter:drop-shadow(0 6px 8px #000)}
#duel .L{left:6%}#duel .R{right:6%}#duel .R img{transform:scaleX(-1)}
#duel .hp{position:absolute;top:calc(50% - min(28vw,210px) - 46px);width:44%;font:700 13px/1.2 serif;text-shadow:0 1px 3px #000}
#duel .hp.l{left:3%}#duel .hp.r{right:3%;text-align:right}
#duel .hp i{display:block;height:9px;margin-top:3px;border:1.5px solid #e8c060;background:#3a0806;position:relative;overflow:hidden}
#duel .hp i b{position:absolute;top:0;bottom:0;left:0;background:linear-gradient(#ffe080,#d08a20);transition:width .3s}
#duel .hp.r i b{left:auto;right:0;background:linear-gradient(#ff9a80,#c02a1a)}
#duel .num{position:absolute;font:900 30px sans-serif;color:#fff;text-shadow:0 0 6px #f40,0 2px 2px #000;animation:dnum .9s ease-out forwards;pointer-events:none}
@keyframes dnum{from{transform:translateY(0) scale(1.4);opacity:1}to{transform:translateY(-50px);opacity:0}}
#duel .slash{position:absolute;width:60%;height:6px;left:20%;top:45%;background:linear-gradient(90deg,#fff0,#fff,#fff0);box-shadow:0 0 18px #ffd060;transform:rotate(-18deg) scaleX(0);animation:dsl .25s ease-out forwards}
@keyframes dsl{to{transform:rotate(-18deg) scaleX(1);opacity:0}}
#duel .cut{position:absolute;left:0;right:0;top:calc(50% - 70px);height:140px;display:flex;align-items:center;gap:12px;padding:0 6%;background:linear-gradient(90deg,#000e,#3a0806e8 60%,#0000);transform:translateX(-100%);transition:transform .3s cubic-bezier(.2,.9,.3,1)}
#duel .cut.on{transform:none}#duel .cut img{height:130px;border-radius:50%;border:3px solid #e8c060}#duel .cut div{font:900 26px/1.3 serif;text-shadow:0 0 10px #f60}#duel .cut small{display:block;font-size:13px;color:#ffd8b0}
#duel .ban{position:absolute;left:0;right:0;top:12%;text-align:center;font:900 30px serif;letter-spacing:.2em;text-shadow:0 0 12px #f30,0 2px 3px #000;opacity:0;transition:opacity .3s}
#duel .ban.on{opacity:1}#duel .res{position:absolute;left:0;right:0;bottom:10%;text-align:center;font:900 34px serif;opacity:0;transform:scale(2);transition:all .3s cubic-bezier(.2,1.6,.4,1)}
#duel .res.on{opacity:1;transform:none}#duel .res small{display:block;font-size:13px;color:#e8d8b0}
#duel.shake .stage{animation:dsh .25s}@keyframes dsh{25%{transform:translate(-6px,calc(-50% + 3px))}75%{transform:translate(6px,calc(-50% - 3px))}}`;
document.head.appendChild(dCss);
const duelEl = document.createElement('div'); duelEl.id = 'duel'; document.body.appendChild(duelEl);
const foeURL = foeTex.image.toDataURL();
function playDuel(k, done) {
  const R = G.raid, A = GM.ALLY[k], F = GM.foeGeneral(G), win = GM.duel(G, k), bg = `assets/field/${R.dir || 'pass'}.jpg`;
  duelEl.style.backgroundImage = `url(${bg})`; duelEl.style.display = 'block';
  duelEl.innerHTML = `<div class="stage"><div class="f L"><img src="../ally/${k}.png"></div><div class="f R" style="height:88%"><img src="${foeURL}" style="filter:drop-shadow(0 0 10px #f30) drop-shadow(0 6px 8px #000)"></div></div>
    <div class="hp l">${A.n}<i><b style="width:100%"></b></i></div><div class="hp r">${F.n}<i><b style="width:100%"></b></i></div>
    <div class="ban">一騎打ち</div><div class="cut"><img src="${faceURL[k]}"><div>${win ? '決める！' : 'まだだ…！'}<small>${A.n}（${A.r}）</small></div></div><div class="res"></div>`;
  const $ = q => duelEl.querySelector(q), L = $('.L'), Rf = $('.R'), hl = $('.hp.l b'), hr = $('.hp.r b');
  // 3往復：結果に合わせてHPの減りを決める
  let hpL = 100, hpR = 100; const seq = [];
  const hits = win ? [['L', 28], ['R', 18], ['L', 30], ['R', 22], ['L', 42]] : [['R', 26], ['L', 20], ['R', 30], ['L', 24], ['R', 44]];
  hits.forEach(([who, dmg]) => seq.push({ who, dmg }));
  let i = 0, timers = [], skipped = false;
  const T = (f, ms) => timers.push(setTimeout(f, ms));
  T(() => $('.ban').classList.add('on'), 100); T(() => $('.ban').classList.remove('on'), 1100);
  const strike = (st, t0) => {
    const at = st.who === 'L' ? L : Rf, df = st.who === 'L' ? Rf : L, dir = st.who === 'L' ? 1 : -1;
    T(() => { at.style.transform = `translateX(${dir * 34}vw)`; }, t0);
    T(() => { const sl = document.createElement('div'); sl.className = 'slash'; $('.stage').appendChild(sl); df.style.filter = 'brightness(3)'; df.style.transform = `translateX(${dir * 4}vw)`; duelEl.classList.add('shake');
      const n = document.createElement('div'); n.className = 'num'; n.textContent = st.dmg * 7 + Math.round(Math.random() * 9); n.style.left = st.who === 'L' ? '68%' : '18%'; n.style.top = '35%'; $('.stage').appendChild(n);
      if (st.who === 'L') { hpR = Math.max(win && st === seq[seq.length - 1] ? 0 : 4, hpR - st.dmg); hr.style.width = hpR + '%'; } else { hpL = Math.max(!win && st === seq[seq.length - 1] ? 0 : 4, hpL - st.dmg); hl.style.width = hpL + '%'; }
      setTimeout(() => { sl.remove(); n.remove(); }, 900); }, t0 + 180);
    T(() => { df.style.filter = ''; duelEl.classList.remove('shake'); at.style.transform = ''; df.style.transform = ''; }, t0 + 420);
  };
  seq.forEach((st, j) => { if (j === seq.length - 1) { T(() => $('.cut').classList.add('on'), 1300 + j * 650); T(() => $('.cut').classList.remove('on'), 2300 + j * 650); strike(st, 2350 + j * 650); } else strike(st, 1300 + j * 650); });
  const endT = 2350 + (seq.length - 1) * 650 + 600;
  const fin = () => { const r = $('.res'); r.innerHTML = `<span style="color:${win ? '#ffd770' : '#ff7a6a'}">${win ? '一騎打ちに勝利' : '一騎打ちに敗北'}</span><small>${win ? '戦況が有利になった' : '戦況が不利になった'}・タップで続ける</small>`; r.classList.add('on'); };
  T(fin, endT);
  duelEl.onclick = e => { e.stopPropagation(); if (!$('.res').classList.contains('on')) { timers.forEach(clearTimeout); hl.style.width = (win ? 60 : 0) + '%'; hr.style.width = (win ? 0 : 55) + '%'; fin(); return; }
    duelEl.style.display = 'none'; duelEl.onclick = null; done(); };
}
function maybeDuel(next) { // 接戦なら、一騎打ちに出す仲間を選ぶ
  if (!GM.duelDue(G) || G.raid.duel !== undefined) { next(); return; }
  const F = GM.foeGeneral(G), cs = GM.champions(G);
  ui.modal('接戦――一騎打ち', `${F.n}が前に出てきた。こちらも将を一人出す。<br>勝てば戦況が有利に、負ければ不利になる。`,
    [...cs.map(k => ({ label: GM.ALLY[k].n, sub: `勝率 約${Math.round(GM.duelP(G, k) * 100)}%`, fn: () => { ui.modal(null); playDuel(k, next); } })),
     { label: '応じない', sub: 'そのまま戦う', fn: () => { G.raid.duel = null; ui.modal(null); next(); } }], 'fr low');
}
function goBattle() { // アクション戦闘へ移る。結果は battle_result に書かれ、戻ってきたときに反映する
  const R = G.raid, id = String(Date.now()), m = GM.battleMods(G); G.battle = { id }; writeSave();
  const q = new URLSearchParams({ battle: '1', id, waves: GM.wavesOf(R.E), name: R.name, dmg: m.dmg, bind: m.bind, hp: m.hp, ret: 'terrain/index.html' });
  location.href = '../index.html?' + q.toString();
}
function takeBattleResult() {
  let r = null; try { r = JSON.parse(localStorage.getItem('battle_result') || 'null'); } catch (e) { }
  if (!r || !G.battle || !G.raid || r.id !== G.battle.id) return;
  try { localStorage.removeItem('battle_result'); } catch (e) { }
  G.battle = null; const t = GM.resolve(G, 'hand', Math.random, !!r.win); endRaidFx(); commit(`${t}（撃破${r.kills}）`); showReport();
}
function raidModal() {
  const R = G.raid; if (!R) { ui.modal(null); return; } if (introPlaying || abt.style.display === 'flex' || duelEl.style.display === 'block' || /一騎打ち/.test(document.querySelector('#modal h3') ? document.querySelector('#modal h3').textContent : '')) return;
  raidFx.classList.add('on');
  if (R.ranka === undefined) R.ranka = GM.rankaReady(G); // 出られるなら出す（窓で切り替えられる）
  const D = GM.raidD(G), p = Math.round(GM.handP(G, R.E) * 100), m = GM.battleMods(G), wv = GM.wavesOf(R.E);
  const mods = [m.dmg > 1 ? `ダメージ+${Math.round((m.dmg - 1) * 100)}%` : '', m.bind ? `拘束+${m.bind}秒` : '', m.hp ? `最大HP+${m.hp}` : ''].filter(Boolean).join('・');
  const rk = GM.joined(G, 'ranka') ? (G.rankaAway ? '<br><span style="color:#c9b48a">ランカは今週、街にいない</span>' : G.rankaRest ? '<br><span style="color:#c9b48a">ランカは前の戦闘に出たので休み（2回続けて出られない）</span>' : `<br>ランカ：<b>${R.ranka ? '出撃する' : '温存する'}</b>（防衛力+${GM.rankaD(G)}・ダメージ+${Math.round(GM.rankaDmg(G) * 100)}%。出ると次の戦闘は休み）`) : '';
  const btns = [{ label: '任せる', sub: '仲間と兵が戦う', fn: () => { ui.modal(null); maybeDuel(() => autoBattle(() => GM.resolve(G, 'auto'))); } },
     { label: '自分で戦う', sub: `WAVE ${wv}・アクション`, fn: goBattle },
     { label: '確率で決める', sub: `成功率 約${p}%`, fn: () => { ui.modal(null); maybeDuel(() => autoBattle(() => GM.resolve(G, 'hand'))); } }];
  if (GM.rankaReady(G)) btns.push({ label: R.ranka ? 'ランカを温存する' : 'ランカを出す', sub: R.ranka ? '次の戦闘に回す' : '最強の戦力', fn: () => { GM.setRanka(G, !R.ranka); writeSave(); raidModal(); } });
  ui.modal(R.kind === 'sortie' ? `出撃：${R.name}` : `襲撃：${R.name}`, `敵の規模 <b>${R.E}</b> ／ こちらの防衛力 <b>${Math.round(D)}</b><br>任せる：見込みは「${GM.autoTier(G, R.E)}」<br>自分で戦う：<b>WAVE ${wv}</b> まで生き残れば勝利。勝てば報酬、負ければ被害が1段重い${mods ? '<br>仲間の補正：' + mods : ''}${rk}`, btns, 'fr low');
}
function overModal() {
  if (!G.over) return;
  ui.modal(G.over === 'win' ? '勝利' : '敗北', `${G.why}（第${Math.min(G.week, GM.WEEKS)}週）<br>開拓した区域：${G.open.length}／${areas.length} ／ 施設：${Object.keys(G.plots).length}`, [{ label: '最初から', fn: () => { G = GM.newState(layout.areas); ui.modal(null); select(null); syncMap(true); commit('最初からやり直した'); } }]);
}
let advisorMsg = null; // 内政役の報告（吹き出し）。了解で閉じる
const why = (need) => (G.raid ? '襲撃の最中' : G.ap < 1 ? '行動点が足りない' : need && G.sup < need ? '物資が足りない' : '今はできない');
function defaultAlly() { const a = GM.advisorOf(G); return a && GM.joined(G, a) ? a : 'mina'; }
function refreshUI() {
  const r = GM.raidView(G), inc = GM.income(G), md = GM.moraleD(G), apMax = GM.apOf(G.morale), wk = Math.min(G.week, GM.WEEKS);
  ui.top({ title: '再建の12週', week: wk, weeks: GM.WEEKS, raidWeeks: GM.SCHED.map(x => x.w), bossWeek: GM.SCHED.find(x => x.boss).w,
    band: { wk, next: r ? (r.inWeeks ? `次の襲撃まであと<b style="font-size:15px"> ${r.inWeeks} </b>週` : '今週末に襲撃') : '襲撃の予定はない', foe: r ? `敵 ${r.known ? r.E : r.lo + '〜' + r.hi}` : '' },
    res: [{ ic: 'sup', lab: '物資', val: G.sup, sub: `${sg(inc)}/週`, cls: inc >= 0 ? 'd' : 'n' }, { ic: 'mor', lab: '民心', val: Math.round(G.morale), bar: G.morale, col: G.morale < 30 ? '#e05a4a' : '#6ac06a' },
      { ic: 'trp', lab: '兵力', val: G.troops, bar: G.troops / 16 * 100, col: '#7aa8e0' }, { ic: 'def', lab: '防衛', val: Math.round(GM.D(G)) },
      { ic: 'hp', lab: '耐久', val: `${G.hp}/3` }, { ic: 'ap', lab: '行動', val: `${G.ap}/${apMax}`, sub: '●'.repeat(G.ap) + '○'.repeat(Math.max(0, apMax - G.ap)), cls: 'd' }] });
  renderActions(); if (G.raid) raidModal(); else if (G.over) overModal();
}
function renderActions() {
  if (!G) return; const L = []; let title = '', icon = 'build', por = null, bubble = null, key = 'none', mode = 'act';
  const P = k => ({ src: `../ally/${k}.png`, face: faceURL[k], name: `${GM.ALLY[k].n}（${GM.ALLY[k].r}）` });
  if (advisorMsg) { const k = defaultAlly(); ui.panel({ key: 'adv' + G.week, icon: 'ally', title: `${GM.ALLY[k].n}の報告`, por: P(k), bubble: advisorMsg, items: [{ label: '了解', act: '', verb: '了解', fn: () => { advisorMsg = null; refreshUI(); } }], week: weekBtn(), mode: 'talk' }); return; }
  if (selSign) { key = 'sign' + selSign.id; icon = 'flag'; const a = selSign.area && areas.find(q => q.id === selSign.area); const ad = a && G.areaDefs.find(q => q.id === a.id);
    title = `目印・${selSign.label}`;
    if (ad && !G.open.includes(ad.id)) L.push({ label: '開拓', act: `${ad.name}を開拓する`, sup: -ad.cost, ap: 1, eff: `毎週 物資+${ad.income}・区画8${Object.keys(GM.ALLY).filter(k => GM.ALLY[k].join === ad.id).map(k => '・' + GM.ALLY[k].n + 'が仲間に').join('')}`, verb: '開拓する', can: GM.canOpen(G, ad), why: why(ad.cost), fn: () => act(() => GM.openArea(G, ad), `${ad.name}を開拓した`) });
    else bubble = ad ? 'この地はもう陛下の領地です。' : 'この先は、まだ道が拓けていません。'; }
  else if (selAlly) { const k = selAlly, A = GM.ALLY[k], b = G.bond[k] || 0, at = G.assign[k]; key = 'ally' + k; icon = 'ally'; por = P(k); bubble = curLine; mode = 'talk';
    title = `${A.n}　絆 ${'●'.repeat(b)}${'○'.repeat(3 - b)}`;
    if (b < 3) L.push({ label: '過ごす', act: `${A.n}と過ごす`, ap: 1, eff: `絆${b + 1}${A.lv[b + 1] ? '：' + A.lv[b + 1] : ''}`, verb: '過ごす', can: GM.canTalk(G, k), why: why(), fn: () => act(() => GM.talk(G, k), `${A.n}と過ごした`) });
    if (at) L.push({ label: '配置を外す', act: `${FAC[G.plots[at].fac].n}（${at}）から外す`, eff: '広場へ戻る', verb: '外す', fn: () => act(() => GM.unassign(G, k), `${A.n}を広場へ戻した`) }); }
  else if (selCastle) { key = 'castle'; icon = 'castle'; title = '城'; por = P(defaultAlly());
    for (const [id, c] of Object.entries(GM.CASTLE)) L.push({ label: c.t, act: c.t, sup: id === 'levy' ? 5 : -c.cost, ap: 1, eff: c.d, verb: c.t, can: GM.canCastle(G, id), why: why(c.cost), fn: () => act(() => { const ok = GM.doCastle(G, id); if (ok && G.raid) setTimeout(raidModal, 0); return ok; }, c.t + 'を行った') }); }
  else if (selected) { const id = selected.id, p = G.plots[id], here = p && GM.allyAt(G, id); key = 'plot' + id + (p ? p.fac + p.stage : '');
    por = P(here || defaultAlly()); if (here) { bubble = curLine; mode = 'talk'; }
    if (!p) { title = '建設予定地'; for (const [f, d] of Object.entries(FAC)) L.push({ label: d.n, act: f === 'farm' ? '畑を整備' : `${d.n}を建てる`, sup: -d.cost, ap: 1, eff: `毎週 ${d.d.replace('毎週の', '')}`, verb: '建設する', can: GM.canBuild(G, f), why: why(d.cost), fn: () => act(() => GM.build(G, id, f), `${d.n}の建築を始めた（週末に完成）`) }); }
    else { const d = FAC[p.fac]; title = `${d.n}（${p.burnt ? '焼かれた' : STAGE[p.stage]}）${here ? '・' + GM.ALLY[here].n : ''}`;
      if (p.burnt) L.push({ label: '修理', act: `${d.n}を修理する`, sup: -GM.REPAIR, ap: 1, eff: '効果が戻る', verb: '修理する', can: GM.canRepair(G, id), why: why(GM.REPAIR), fn: () => act(() => GM.repair(G, id), `${d.n}を修理した`) });
      if (p.stage === 1 && !here) title += '・週末に完成';
      if (p.stage === 2) L.push({ label: '発展', act: `${d.n}を発展させる`, sup: -d.up, ap: 1, eff: '効果が2倍になる', verb: '発展させる', can: GM.canUpgrade(G, id), why: why(d.up), fn: () => act(() => GM.upgrade(G, id), `${d.n}を発展させた`) });
      if (p.stage >= 2) {
        for (const k of Object.keys(GM.ALLY)) { if (!GM.joined(G, k) || k === here) continue; const A = GM.ALLY[k], bon = GM.assignBonus(p.fac, k), fit = GM.AFFINITY[p.fac].includes(k);
          L.push({ label: `${A.n}を配置`, act: `${A.n}を配置する${fit ? '（得意）' : ''}`, eff: `効果 +${bon}${G.assign[k] ? '・今の配置から移る' : ''}`, verb: '配置する', can: GM.canAssign(G, k, id), why: why(), fn: () => act(() => GM.assign(G, k, id), `${A.n}を${d.n}に配置した`) }); }
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
    else if (hitAlly(sx, sy)) { const k = hitAlly(sx, sy); select(null); selAlly = k; curLine = GM.lineOf(G, k); refreshUI(); }
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
  groundMat.uniforms.time.value = now / 1000; selGlow.opacity = .38 + .2 * Math.sin(now / 260);
  walkAllies(Math.min(.05, dt / 1000)); badges.forEach((b, i) => { b.position.y = b.userData.y0 + Math.sin(now / 400 + i) * 2; }); fireMeshes.forEach(f => { if (!f.parent) { fireMeshes.delete(f); return; } if (!f.userData.s) f.userData.s = f.scale.clone(); const k = 1 + Math.sin(now / 90 + f.id) * .06; f.scale.set(f.userData.s.x * (2 - k), f.userData.s.y * k, 1); });
  waterMats.forEach(mt => { if (mt.userData.sh) mt.userData.sh.uniforms.time.value = now / 1000; }); fx.forEach(f => f(now)); fx = fx.filter(f => !f.done);
  apply(); renderer.render(scene, camera);
  if (acc > 500) { st.textContent = `3D: ${status.ok ? 'OK' : status.reason} / 地面:${status.ground} 小物:${status.sprites}(${status.props}) / ${(frames * 1000 / acc).toFixed(0)}fps / 拡大 ${view.zoom.toFixed(2)}`; frames = 0; acc = 0; }
  // HUD は refreshUI() が書く
  requestAnimationFrame(frame);
}
canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); status.ok = false; status.reason = 'WebGLが失われた'; });
G = loadSave() || GM.newState(layout.areas); syncMap(true); refreshUI(); takeBattleResult();
resize(); apply(); renderer.render(scene, camera); status.ok = true;
window.__t.setView = (zoom, sx, sy) => { view.zoom = zoom; view.cx = sx; view.cz = zOf(sy); clampView(); apply(); renderer.render(scene, camera); };
window.__t.select = id => select(plots.find(p => p.id === id) || null);
window.__t.plots = plots; window.__t.G = () => G; window.__t.playDuel = playDuel; window.__t.camp = () => camp && camp.map(c => [c.position.x|0, c.position.y|0, c.position.z|0, c.visible]); window.__t.faces = () => faceURL; window.__t.raidIntro = raidIntro; window.__t.showReport = showReport; window.__t.GM = GM; window.__t.commit = () => commit(); window.__t.reset = () => { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } }; window.__t.pickAt = (cx, cy) => pickAt(cx, cy); window.__t.view = view; window.__t.sel = () => selected && selected.id; window.__t.build = (id, fac, stage) => { if (stage) G.plots[id] = { fac, stage }; else delete G.plots[id]; commit(); };
requestAnimationFrame(frame);
