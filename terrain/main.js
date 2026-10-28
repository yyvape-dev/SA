// 領地の地形テスト：地形は three.js（正射影・傾き固定）、小物は切り抜き板、区画はコードのデータ。
// 座標の約束：基準画像（①）の画素座標 (sx, sy) を使う。地面 (x, z) は x=sx、z=(sy-SY0)/sinE。
import * as THREE from './vendor/three.module.min.js';
import * as GM from './game.js?v=1793169290';
import { createUI } from './ui.js?v=1793169290';

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
function place(type, x, sy, sc = 1, flip = false, tint = 1) { const z = zOf(sy); buckets[type].push({ x, z, y: hgt(x, z), sc, flip, tint }); }
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
const FAC = GM.FAC, STAGE = GM.STAGE, ART = ['smithy', 'tavern']; // 絵のある施設。畑はコードで描く
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
function pavingMesh(q, opaque, tex) { // q = [T,R,B,L] の地面座標。B→R が u、B→L が v
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
function grow(q, k) { const cx = q.reduce((a, p) => a + p[0], 0) / 4, cy = q.reduce((a, p) => a + p[1], 0) / 4; return q.map(([x, y]) => [cx + (x - cx) * k, cy + (y - cy) * k]); }
function refreshPlot(pl) {
  if (pl.pav) { scene.remove(pl.pav); pl.pav.geometry.dispose(); pl.pav = null; }
  if (pl.mesh) { scene.remove(pl.mesh); pl.mesh.material.dispose(); pl.mesh = null; }
  pl.hit = null; pl.poly = pl.home;
  const key = `${pl.fac}_${pl.stage}`, t = pl.fac && pl.stage >= 1 ? bldTex[key] : null;
  if (pl.fac === 'farm' && pl.stage >= 1) { pl.pav = pavingMesh(grow(pl.home, .94), false, cropTexture(pl.stage)); scene.add(pl.pav); }
  if (t) {
    const meta = bld[`assets/bld/${key}.png`];
    pl.mesh = sprite3D(t, meta, BS, pl.cx, pl.base[1] - 4); scene.add(pl.mesh);
    pl.pav = pavingMesh(grow(pl.home, 1.0)); scene.add(pl.pav);
    const bottom = pl.base[1] - 4, w = meta.w * BS, h = meta.h * BS;
    pl.hit = { key, left: pl.cx - meta.ax * w, top: bottom - meta.ay * h, w, h };
  }
  pl.stakes.visible = !t;
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
layout.plazas.forEach(pz => { // 広場：石畳＋中央の噴水／井戸＋四隅の街灯
  const [T, R, B, L] = pz.poly; scene.add(pavingMesh([T, R, B, L], true));
  const [cx, cy] = pz.center;
  if (pz.kind === 'fountain') piece('fountain', cx, cy + 32, .7); else piece('well', cx, cy + 26, .55);
  [T, R, B, L].forEach(([x, y]) => piece('lamp', x + (cx - x) * .12, y + (cy - y) * .12, .38));
});
{ // 交差点と道の曲がり角に街灯
  const pts = [];
  layout.roads.forEach(rd => rd.pts.forEach(([x, y], i) => { if (i > 0 && i < rd.pts.length - 1 && x > 0 && x < REF_W) pts.push([x, y]); }));
  pts.forEach(([x, y]) => { if (!layout.plazas.some(pz => pointInPoly(x, y, pz.poly))) piece('lamp', x + 26, y - 6, .38); });
}
const signs = layout.signs.map(sg => ({ ...sg, mesh: piece('sign', sg.x, sg.y, .6, sg.label) }));

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
const ALLY_POS = { mina: [405, 1048], garou: [548, 1046], sera: [508, 1080] };
const allyMesh = {};
for (const k of Object.keys(GM.ALLY)) {
  const im = await loadImage(`../ally/${k}.png`); if (!im) continue;
  const t = new THREE.Texture(im); t.needsUpdate = true; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  const [x, y] = ALLY_POS[k], sc = 74 / im.height; const m = sprite3D(t, { w: im.width, h: im.height, ax: .5, ay: .98 }, sc, x, y); m.visible = false; scene.add(m);
  allyMesh[k] = { m, x, y, w: im.width * sc, h: im.height * sc };
}
function placeAlly(k, x, y) { const a = allyMesh[k]; if (!a) return; const z = zOf(y); a.m.position.set(x, hgt(x, z), z); a.x = x; a.y = y; }
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
function loadSave() { try { const v = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null'); if (v && v.week) { v.bond = v.bond || { mina: 0, garou: 0, sera: 0 }; v.assign = v.assign || {}; return v; } return null; } catch (e) { return null; } }
function writeSave() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(G)); } catch (e) { } }
function syncMap(instant) { // 状態 → 区画の絵と霧
  for (const pl of plots) { const p = G.plots[pl.id]; const f = p ? p.fac : null, stg = p ? p.stage : 0; if (pl.fac !== f || pl.stage !== stg) setPlot(pl, f, stg); }
  for (const a of areas) showArea(a, G.open.includes(a.id)); updateFog(instant);
  for (const k of Object.keys(allyMesh)) { const v = GM.joined(G, k); if (v && !allyMesh[k].m.visible && !instant) ui.toast(`${GM.ALLY[k].n}（${GM.ALLY[k].r}）が仲間になった`); allyMesh[k].m.visible = v; if (v) placeAlly(k, ...allySpot(k)); }
}
const ui = createUI({ onEndWeek: () => endWeek(), onReset: () => { G = GM.newState(layout.areas); select(null); syncMap(true); commit('最初からやり直した'); } });
function commit(msg) { writeSave(); syncMap(); refreshUI(); if (msg) ui.toast(msg); }
function act(fn, ok) { if (fn()) commit(ok); else ui.toast('できない（行動点か物資が足りない）'); }
const sg = n => (n >= 0 ? '+' : '') + n;
function endWeek() {
  if (G.over) return; if (G.raid) { raidModal(); return; }
  G.repPrev = GM.snap(G); const msg = GM.endWeek(G); select(null); commit(G.raid ? null : msg); if (!G.raid) showReport();
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
function goBattle() { // アクション戦闘へ移る。結果は battle_result に書かれ、戻ってきたときに反映する
  const R = G.raid, id = String(Date.now()), m = GM.battleMods(G); G.battle = { id }; writeSave();
  const q = new URLSearchParams({ battle: '1', id, waves: GM.wavesOf(R.E), name: R.name, dmg: m.dmg, bind: m.bind, hp: m.hp, ret: 'terrain/index.html' });
  location.href = '../index.html?' + q.toString();
}
function takeBattleResult() {
  let r = null; try { r = JSON.parse(localStorage.getItem('battle_result') || 'null'); } catch (e) { }
  if (!r || !G.battle || !G.raid || r.id !== G.battle.id) return;
  try { localStorage.removeItem('battle_result'); } catch (e) { }
  G.battle = null; const t = GM.resolve(G, 'hand', Math.random, !!r.win); commit(`${t}（撃破${r.kills}）`); showReport();
}
function raidModal() {
  const R = G.raid; if (!R) { ui.modal(null); return; }
  const D = GM.D(G), p = Math.round(GM.handP(G, R.E) * 100), m = GM.battleMods(G), wv = GM.wavesOf(R.E);
  const mods = [m.dmg > 1 ? `ダメージ+${Math.round((m.dmg - 1) * 100)}%` : '', m.bind ? `拘束+${m.bind}秒` : '', m.hp ? `最大HP+${m.hp}` : ''].filter(Boolean).join('・');
  ui.modal(R.kind === 'sortie' ? `出撃：${R.name}` : `襲撃：${R.name}`, `敵の規模 <b>${R.E}</b> ／ こちらの防衛力 <b>${Math.round(D)}</b><br>任せる：見込みは「${GM.autoTier(G, R.E)}」<br>自分で戦う：<b>WAVE ${wv}</b> まで生き残れば勝利。勝てば報酬、負ければ被害が1段重い（${R.kind === 'sortie' ? '行動点-1' : '次の週の行動点-1'}）${mods ? '<br>仲間の補正：' + mods : ''}`,
    [{ label: '任せる', fn: () => { const t = GM.resolve(G, 'auto'); ui.modal(null); commit(t); showReport(); } },
     { label: '自分で戦う', sub: `WAVE ${wv}・アクション`, fn: goBattle },
     { label: '確率で決める', sub: `成功率 約${p}%`, fn: () => { const t = GM.resolve(G, 'hand'); ui.modal(null); commit(t); showReport(); } }]);
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
  if (!G) return; const L = []; let title = '', icon = 'build', por = null, bubble = null, key = 'none';
  const P = k => ({ src: `../ally/${k}.png`, name: `${GM.ALLY[k].n}（${GM.ALLY[k].r}）` });
  if (advisorMsg) { const k = defaultAlly(); ui.panel({ key: 'adv' + G.week, icon: 'ally', title: `${GM.ALLY[k].n}の報告`, por: P(k), bubble: advisorMsg, items: [{ label: '了解', act: '', verb: '了解', fn: () => { advisorMsg = null; refreshUI(); } }], week: weekBtn() }); return; }
  if (selSign) { key = 'sign' + selSign.id; icon = 'flag'; const a = selSign.area && areas.find(q => q.id === selSign.area); const ad = a && G.areaDefs.find(q => q.id === a.id);
    title = `目印・${selSign.label}`;
    if (ad && !G.open.includes(ad.id)) L.push({ label: '開拓', act: `${ad.name}を開拓する`, sup: -ad.cost, ap: 1, eff: `毎週 物資+${ad.income}・区画8${Object.keys(GM.ALLY).filter(k => GM.ALLY[k].join === ad.id).map(k => '・' + GM.ALLY[k].n + 'が仲間に').join('')}`, verb: '開拓する', can: GM.canOpen(G, ad), why: why(ad.cost), fn: () => act(() => GM.openArea(G, ad), `${ad.name}を開拓した`) });
    else bubble = ad ? 'この地はもう陛下の領地です。' : 'この先は、まだ道が拓けていません。'; }
  else if (selAlly) { const k = selAlly, A = GM.ALLY[k], b = G.bond[k] || 0, at = G.assign[k]; key = 'ally' + k; icon = 'ally'; por = P(k); bubble = curLine;
    title = `${A.n}　絆 ${'●'.repeat(b)}${'○'.repeat(3 - b)}`;
    if (b < 3) L.push({ label: '過ごす', act: `${A.n}と過ごす`, ap: 1, eff: `絆${b + 1}${A.lv[b + 1] ? '：' + A.lv[b + 1] : ''}`, verb: '過ごす', can: GM.canTalk(G, k), why: why(), fn: () => act(() => GM.talk(G, k), `${A.n}と過ごした`) });
    if (at) L.push({ label: '配置を外す', act: `${FAC[G.plots[at].fac].n}（${at}）から外す`, eff: '広場へ戻る', verb: '外す', fn: () => act(() => GM.unassign(G, k), `${A.n}を広場へ戻した`) }); }
  else if (selCastle) { key = 'castle'; icon = 'castle'; title = '城'; por = P(defaultAlly());
    for (const [id, c] of Object.entries(GM.CASTLE)) L.push({ label: c.t, act: c.t, sup: id === 'levy' ? 5 : -c.cost, ap: 1, eff: c.d, verb: c.t, can: GM.canCastle(G, id), why: why(c.cost), fn: () => act(() => { const ok = GM.doCastle(G, id); if (ok && G.raid) setTimeout(raidModal, 0); return ok; }, c.t + 'を行った') }); }
  else if (selected) { const id = selected.id, p = G.plots[id], here = p && GM.allyAt(G, id); key = 'plot' + id + (p ? p.fac + p.stage : '');
    por = P(here || defaultAlly()); if (here) bubble = curLine;
    if (!p) { title = '建設予定地'; for (const [f, d] of Object.entries(FAC)) L.push({ label: d.n, act: f === 'farm' ? '畑を整備' : `${d.n}を建てる`, sup: -d.cost, ap: 1, eff: `毎週 ${d.d.replace('毎週の', '')}`, verb: '建設する', can: GM.canBuild(G, f), why: why(d.cost), fn: () => act(() => GM.build(G, id, f), `${d.n}の建築を始めた（週末に完成）`) }); }
    else { const d = FAC[p.fac]; title = `${d.n}（${STAGE[p.stage]}）${here ? '・' + GM.ALLY[here].n : ''}`;
      if (p.stage === 1) { bubble = bubble || '建築中です。週末に完成します。'; }
      if (p.stage === 2) L.push({ label: '発展', act: `${d.n}を発展させる`, sup: -d.up, ap: 1, eff: '効果が2倍になる', verb: '発展させる', can: GM.canUpgrade(G, id), why: why(d.up), fn: () => act(() => GM.upgrade(G, id), `${d.n}を発展させた`) });
      if (p.stage >= 2) {
        for (const k of Object.keys(GM.ALLY)) { if (!GM.joined(G, k) || k === here) continue; const A = GM.ALLY[k], bon = GM.assignBonus(p.fac, k), fit = GM.AFFINITY[p.fac].includes(k);
          L.push({ label: `${A.n}を配置`, act: `${A.n}を配置する${fit ? '（得意）' : ''}`, eff: `効果 +${bon}${G.assign[k] ? '・今の配置から移る' : ''}`, verb: '配置する', can: GM.canAssign(G, k, id), why: why(), fn: () => act(() => GM.assign(G, k, id), `${A.n}を${d.n}に配置した`) }); }
        if (here) L.push({ label: `${GM.ALLY[here].n}を外す`, act: `${GM.ALLY[here].n}を外す`, eff: '広場へ戻る', verb: '外す', fn: () => act(() => GM.unassign(G, here), `${GM.ALLY[here].n}を広場へ戻した`) }); }
      L.push({ label: '取り壊す', act: `${d.n}を取り壊す`, eff: '行動点は使わない。配置は外れる', verb: '取り壊す', fn: () => act(() => GM.demolish(G, id), `${d.n}を取り壊した`) }); } }
  else { const k = defaultAlly(); por = P(k); title = '陛下の領地'; icon = 'flag'; key = 'idle';
    const w = GM.weekReport(GM.snap(G), G).warns; bubble = w.length ? w[0] : '区画・城・仲間・目印をタップしてください。'; }
  ui.panel({ key, icon, title, por, bubble, items: L, week: weekBtn() });
}
function weekBtn() { const inc = GM.income(G), md = GM.moraleD(G); return { label: G.raid ? '襲撃を迎える' : '週を終える', sub: `物資${sg(inc)} 民心${sg(md)}`, hot: G.ap === 0 || !!G.raid, disabled: !!G.over }; }
// ---------- 視点（パン・ズーム） ----------
const view = { cx: AREA0_W / 2, cz: zOf(REF_H * .5), zoom: 1 };
let fitZoom = 1, W = 1, H = 1;
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
    const sgn = signs.find(q => !lockedAt(q.x) && Math.abs(sx - q.x) < 38 && sy > q.y - 86 && sy < q.y + 10);
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
let last = performance.now(), frames = 0, acc = 0;
function frame(now) {
  const dt = now - last; last = now; acc += dt; frames++;
  groundMat.uniforms.time.value = now / 1000; selGlow.opacity = .38 + .2 * Math.sin(now / 260);
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
window.__t.plots = plots; window.__t.G = () => G; window.__t.showReport = showReport; window.__t.GM = GM; window.__t.commit = () => commit(); window.__t.reset = () => { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } }; window.__t.pickAt = (cx, cy) => pickAt(cx, cy); window.__t.view = view; window.__t.sel = () => selected && selected.id; window.__t.build = (id, fac, stage) => { if (stage) G.plots[id] = { fac, stage }; else delete G.plots[id]; commit(); };
requestAnimationFrame(frame);
