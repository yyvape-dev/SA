// 領地の地形テスト：地形は three.js（正射影・傾き固定）、小物は切り抜き板、区画はコードのデータ。
// 座標の約束：基準画像（①）の画素座標 (sx, sy) を使う。地面 (x, z) は x=sx、z=(sy-SY0)/sinE。
import * as THREE from './vendor/three.module.min.js';

const REF_W = 941, REF_H = 1672;
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
const layout = await (await fetch('data/layout.json')).json();
function loadImage(src) { return new Promise(res => { const im = new Image(); im.onload = () => res(im); im.onerror = () => res(null); im.src = src; }); }
const splatImg = await loadImage('data/splat.png');
const SW = splatImg.width, SH = splatImg.height;
const splatCv = document.createElement('canvas'); splatCv.width = SW; splatCv.height = SH;
const sctx = splatCv.getContext('2d', { willReadFrequently: true });
sctx.drawImage(splatImg, 0, 0);
// 遠景の湖（基準画像の右上）を水として足す（コードの形）
{
  sctx.globalCompositeOperation = 'lighter';
  sctx.fillStyle = 'rgb(0,0,255)';
  sctx.beginPath();
  [[640, 520], [700, 480], [800, 455], [941, 440], [941, 610], [860, 600], [780, 585], [700, 560]].forEach(([x, y], i) => { const px = x / 2, py = y / 2; i ? sctx.lineTo(px, py) : sctx.moveTo(px, py); });
  sctx.closePath(); sctx.fill(); sctx.globalCompositeOperation = 'source-over';
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
  sctx.beginPath(); layout.plaza.forEach(([x, y], i) => { i ? sctx.lineTo(x / 2, y / 2) : sctx.moveTo(x / 2, y / 2); }); sctx.closePath(); sctx.fill();
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
function hgt(x, z) { // 街の中は、噴水の高さへ平らにならす
  const h0 = hgt0(x, z), sy = syOf(z), d = Math.hypot(x - layout.fountain[0], (sy - layout.fountain[1]) * 1.6);
  const w = Math.min(1, zoneAt(x, sy) * 1.6) * smooth(500, 380, d); if (w <= 0) return h0;
  if (hgt.f === undefined) hgt.f = 0, hgt.f = hgt0(layout.fountain[0], zOf(layout.fountain[1]));
  return h0 + (hgt.f - h0) * w;
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
const SEG_X = 190, SEG_Z = 300;
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
// 森・岩・茂み・川沿いの岩を散らす
{
  const N = 5200;
  for (let i = 0; i < N; i++) {
    const x = -50 + R() * (REF_W + 100), sy = 380 + R() * (REF_H - 300);
    const zn = zoneAt(x, sy); if (zn > .62 || nearLayout(x, sy, 22)) continue;
    const z = zOf(sy), f = fbm(x / 230 + 5, z / 230), edge = Math.max(smooth(260, 0, x), smooth(REF_W - 260, REF_W, x)) * .5 + smooth(520, 400, sy) * .5;
    const forestness = Math.min(1, Math.max(0, f * 1.5 - .42 + edge * .55)) * (1 - smooth(.08, .5, zn));
    const r = R();
    if (r < forestness * .55) { const t = R(); const type = t < .3 ? 0 : t < .62 ? 1 : t < .84 ? 2 : 3; place(type, x, sy, .75 + R() * .5, R() < .5, .86 + R() * .2); }
    else if (r < forestness * .55 + .035) place(4, x, sy, .8 + R() * .5, R() < .5, .9 + R() * .15);
    else if (r < forestness * .55 + .05 && forestness < .5) place(5 + (R() < .5 ? 1 : 0), x, sy, .8 + R() * .5, R() < .5);
  }
  // 左の岩壁・川沿いの岩
  for (let i = 0; i < 260; i++) { const x = R() * 200, sy = 420 + R() * 1200; if (nearLayout(x, sy, 12)) continue; place(R() < .35 ? 7 : R() < .6 ? 5 : 6, x, sy, .9 + R() * .7, R() < .5); }
  for (let i = 0; i < 1300; i++) { const x = R() * REF_W, sy = 900 + R() * 800; const s = splatAt(x, sy); if (s[2] > .12 && s[2] < .6) place(R() < .5 ? 5 : 6, x + (R() - .5) * 20, sy + (R() - .5) * 12, .6 + R() * .6, R() < .5); }
  // 区画の四隅に杭（標識）
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
{ // 領主の城（切り抜き絵）
  const meta = bld['assets/bld/castle.png']; const t = await loadBld('assets/bld/castle.png');
  if (t) scene.add(sprite3D(t, meta, .37, 300, 705));
}

// ---------- 区画（コードのデータ）と選択表示 ----------
const plots = layout.plots.map(p => ({ id: p.id, poly: p.poly, home: p.poly, state: 'empty' }));
const selMat = new THREE.MeshBasicMaterial({ color: 0xffd25a, transparent: true, opacity: .32, depthTest: false });
const selLine = new THREE.LineBasicMaterial({ color: 0xffe08a, depthTest: false });
let selGroup = null, selected = null;
function pointInPoly(x, y, poly) { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const [xi, yi] = poly[i], [xj, yj] = poly[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c; } return c; }
function select(p) {
  if (selGroup) { scene.remove(selGroup); selGroup = null; }
  selected = p; renderActions(); if (!p) return;
  const pts = p.poly.map(([sx, sy]) => { const z = zOf(sy); return new THREE.Vector3(sx, hgt(sx, z) + 3, z); });
  const sh = new THREE.Shape(p.poly.map(([sx, sy]) => new THREE.Vector2(sx, zOf(sy))));
  const g = new THREE.ShapeGeometry(sh); g.rotateX(Math.PI / 2); // (x,z)->(x,0,z)
  const fix = new THREE.Mesh(g, selMat); fix.position.y = 4; fix.renderOrder = 10;
  const line = new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(pts), selLine); line.renderOrder = 11;
  selGroup = new THREE.Group(); selGroup.add(fix, line); scene.add(selGroup);
}

// ---------- 施設（区画の状態：0=空き地 1=建築中 2=完成 3=発展後）----------
const FAC = { smithy: '鍛冶場', tavern: '酒場' }, STAGE = ['空き地', '建築中', '完成', '発展後'];
const BS = .38; // 素材シートの画素 → 基準画像の画素
for (const f of Object.keys(FAC)) for (let k = 1; k <= 3; k++) bldTex[`${f}_${k}`] = await loadBld(`assets/bld/${f}_${k}.png`);
plots.forEach(pl => { pl.fac = null; pl.stage = 0; pl.mesh = null; pl.base = pl.poly.reduce((a, q) => q[1] > a[1] ? q : a, pl.poly[0]); pl.cx = pl.poly.reduce((a, q) => a + q[0], 0) / 4; });
const alphaCache = {};
function alphaMask(key) { // 絵の透明度（タップ判定用）
  if (alphaCache[key]) return alphaCache[key];
  const im = bldTex[key].image, c = document.createElement('canvas'); c.width = im.width; c.height = im.height;
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
function pavingMesh(q, opaque) { // q = [T,R,B,L] の地面座標。B→R が u、B→L が v
  const [T, R, B, L] = q, P = [B, R, T, L], pos = [], z = p => zOf(p[1]);
  P.forEach(p => pos.push(p[0], hgt(p[0], z(p)) + .8, z(p)));
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  const k = opaque ? 2 : 1; g.setAttribute('uv', new THREE.Float32BufferAttribute([0, 0, k, 0, k, k, 0, k], 2)); g.setIndex([0, 2, 1, 0, 3, 2]);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: pavingTex(opaque), transparent: !opaque, alphaTest: opaque ? 0 : .5, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2, side: THREE.DoubleSide }));
  m.frustumCulled = false; return m;
}
function grow(q, k) { const cx = q.reduce((a, p) => a + p[0], 0) / 4, cy = q.reduce((a, p) => a + p[1], 0) / 4; return q.map(([x, y]) => [cx + (x - cx) * k, cy + (y - cy) * k]); }
function refreshPlot(pl) {
  if (pl.pav) { scene.remove(pl.pav); pl.pav.geometry.dispose(); pl.pav = null; }
  if (pl.mesh) { scene.remove(pl.mesh); pl.mesh.material.dispose(); pl.mesh = null; }
  pl.hit = null; pl.poly = pl.home;
  const key = `${pl.fac}_${pl.stage}`, t = pl.fac && pl.stage >= 1 ? bldTex[key] : null;
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
{ // 広場（石畳）と噴水（仮の絵：コードで描いた印。あとで外部AIの絵に差し替える）
  const [T, R, B, L] = layout.plaza; scene.add(pavingMesh([T, R, B, L], true));
  const c = document.createElement('canvas'); c.width = 256; c.height = 224; const g = c.getContext('2d');
  const ell = (cx, cy, rx, ry, col) => { g.fillStyle = col; g.beginPath(); g.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2); g.fill(); };
  ell(128, 180, 120, 38, '#6d675c'); ell(128, 172, 120, 38, '#a39b8a'); ell(128, 170, 104, 31, '#5aa7d8'); ell(128, 168, 96, 27, '#7cc4ee');
  g.fillStyle = '#8f8878'; g.fillRect(112, 84, 32, 84); g.fillStyle = '#b3ab99'; g.fillRect(112, 84, 14, 84);
  ell(128, 90, 52, 15, '#8f8878'); ell(128, 86, 52, 15, '#b3ab99'); ell(128, 85, 44, 11, '#7cc4ee');
  g.fillStyle = '#9a9283'; g.fillRect(122, 40, 12, 48); ell(128, 40, 12, 5, '#b3ab99');
  g.strokeStyle = 'rgba(235,248,255,.85)'; g.lineWidth = 3; [[-1, 0], [1, 0]].forEach(([d]) => { g.beginPath(); g.moveTo(128, 38); g.quadraticCurveTo(128 + d * 36, 14, 128 + d * 56, 82); g.stroke(); });
  const ft = new THREE.CanvasTexture(c); ft.colorSpace = THREE.SRGBColorSpace;
  const [fx, fy] = layout.fountain; scene.add(sprite3D(ft, { w: 256, h: 224, ax: .5, ay: .82 }, .7, fx, fy + 6));
}
function hitBuilding(sx, sy) { // 建物の絵（透明でない所）を押したか。手前の建物を優先
  let best = null;
  for (const pl of plots) {
    const h = pl.hit; if (!h) continue; const u = (sx - h.left) / h.w, v = (sy - h.top) / h.h; if (u < 0 || u > 1 || v < 0 || v > 1) continue;
    const m = alphaMask(h.key), px = Math.min(m.w - 1, u * m.w | 0), py = Math.min(m.h - 1, v * m.h | 0);
    if (m.d[(py * m.w + px) * 4 + 3] > 40 && (!best || pl.base[1] > best.base[1])) best = pl;
  }
  return best;
}
function setPlot(pl, fac, stage) { pl.fac = stage ? fac : null; pl.stage = stage; refreshPlot(pl); renderActions(); }
const actEl = document.createElement('div');
actEl.style.cssText = 'position:fixed;left:0;right:0;bottom:calc(env(safe-area-inset-bottom) + 28px);z-index:3;display:flex;gap:8px;justify-content:center;flex-wrap:wrap;padding:0 8px;pointer-events:none';
document.body.appendChild(actEl);
function btn(label, fn) { const b = document.createElement('button'); b.textContent = label; b.style.cssText = 'pointer-events:auto;min-height:48px;padding:0 16px;font-size:15px;font-weight:700;color:#2a1a08;background:linear-gradient(#f0d58a,#c9a24a);border:2px solid #5a3d12;border-radius:10px;box-shadow:0 2px 6px #000a'; b.addEventListener('click', e => { e.stopPropagation(); fn(); }); return b; }
function renderActions() {
  actEl.replaceChildren(); const pl = selected; if (!pl) return;
  if (pl.stage === 0) { for (const f of Object.keys(FAC)) actEl.appendChild(btn(`${FAC[f]}を建てる`, () => setPlot(pl, f, 1))); }
  else { if (pl.stage < 3) actEl.appendChild(btn(`${STAGE[pl.stage + 1]}へ進める`, () => setPlot(pl, pl.fac, pl.stage + 1))); actEl.appendChild(btn('取り壊す', () => setPlot(pl, null, 0))); }
}

// ---------- 視点（パン・ズーム） ----------
const view = { cx: REF_W / 2, cz: zOf(REF_H * .5), zoom: 1 };
let fitZoom = 1, W = 1, H = 1;
const bg = document.getElementById('bg'), hud = document.getElementById('hud'), st = document.getElementById('st');
function resize() {
  W = window.innerWidth; H = window.innerHeight; renderer.setSize(W, H, false);
  camera.left = -W / 2; camera.right = W / 2; camera.top = H / 2; camera.bottom = -H / 2; camera.updateProjectionMatrix();
  fitZoom = Math.min(W / REF_W, H / REF_H * 1.0);
  if (!view._init) { view.zoom = Math.max(W / REF_W, H / REF_H); view._init = true; view.cx = REF_W / 2; view.cz = zOf(REF_H * .62); }
  clampView();
}
function clampView() {
  const cover = Math.max(W / REF_W, H / REF_H); view.zoom = Math.min(Math.max(view.zoom, cover), cover * 5);
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
  if (drag && !drag.moved) { const [sx, sy] = pickAt(e.clientX, e.clientY); select(hitBuilding(sx, sy) || plots.find(p => pointInPoly(sx, sy, p.poly)) || null); }
  pointers.delete(e.pointerId); if (pointers.size < 2) pinch = null; if (!pointers.size) drag = null;
});
canvas.addEventListener('pointercancel', e => { pointers.delete(e.pointerId); pinch = null; drag = null; });
canvas.addEventListener('wheel', e => { e.preventDefault(); const [sx, sy] = pickAt(e.clientX, e.clientY); const f = Math.exp(-e.deltaY * .0012); view.zoom *= f; clampView(); const [sx2, sy2] = pickAt(e.clientX, e.clientY); view.cx += sx - sx2; view.cz += (sy - sy2) / SIN; clampView(); }, { passive: false });
window.addEventListener('resize', resize);

// ---------- ループ ----------
let last = performance.now(), frames = 0, acc = 0;
function frame(now) {
  const dt = now - last; last = now; acc += dt; frames++;
  groundMat.uniforms.time.value = now / 1000;
  apply(); renderer.render(scene, camera);
  if (acc > 500) { st.textContent = `3D: ${status.ok ? 'OK' : status.reason} / 地面:${status.ground} 小物:${status.sprites}(${status.props}) / ${(frames * 1000 / acc).toFixed(0)}fps / 拡大 ${view.zoom.toFixed(2)}`; frames = 0; acc = 0; }
  hud.innerHTML = `<b>領地 地形テスト</b>（コード生成の地形）<br>${selected ? `区画 <b>${selected.id}</b>：${selected.fac ? FAC[selected.fac] + '（' + STAGE[selected.stage] + '）' : '空き地'}` : '区画をタップ'}`;
  requestAnimationFrame(frame);
}
canvas.addEventListener('webglcontextlost', e => { e.preventDefault(); status.ok = false; status.reason = 'WebGLが失われた'; });
resize(); apply(); renderer.render(scene, camera); status.ok = true;
window.__t.setView = (zoom, sx, sy) => { view.zoom = zoom; view.cx = sx; view.cz = zOf(sy); clampView(); apply(); renderer.render(scene, camera); };
window.__t.select = id => select(plots.find(p => p.id === id) || null);
window.__t.plots = plots; window.__t.pickAt = (cx, cy) => pickAt(cx, cy); window.__t.view = view; window.__t.sel = () => selected && selected.id; window.__t.build = (id, fac, stage) => { const pl = plots.find(q => q.id === id); if (pl) setPlot(pl, fac, stage); };
requestAnimationFrame(frame);
