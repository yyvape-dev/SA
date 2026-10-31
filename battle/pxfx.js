// 月夜の回廊：エフェクトの層を PixiJS（WebGL）で描く（2026-10-31 WebGL 移行・段階2の2）。
// 作り：エフェクトの描画の関数（fx.js・fx2.js・drawFx・drawUnder）はそのまま使い、そのあいだだけ ctx を「三角形の記録係」（VX）に差し替える。
//   記録係は Canvas 2D の命令（線・塗り・楕円・曲線・点線・線形／放射のグラデーション・加算）を、色つきの三角形に分けて1つの頂点の束に積む。
//   加算（lighter）と通常の合成は、事前乗算の色で「加算＝アルファ0」にして同じ合成（ONE, ONE_MINUS_SRC_ALPHA）で描く → 重ね順を守ったまま、層ごとに1回の描画。
//   縁は 1px の柔らかい帯（アンチエイリアスの代わり）。
// 斬撃の弧（drawVArc）と突き（drawVLance）は、terrain/fx_gl.js のシェーダー（侵食・色の帯・流れるすじ）を Pixi の Mesh＋Shader に載せ替えて描く（ctx.slashGL）。
//   素材は terrain/assets/fx（白黒のデータの絵。R＝形、G＝消える順番）。読み込むまでと ?fxgl=0 では、今までの Canvas の形の弧。
// 層：足元の下（drawUnder）＝背景とキャラのあいだ、エフェクト（拘束の帯・物資・drawFx・星震）＝キャラの上。文字・HUD・暗転は Canvas 2D（#game）のまま。
// ?px=0 か WebGL が使えないときは、pxr.js と同じく全部 Canvas 2D。
'use strict';
(function () {
  if (!window.PIXI || typeof PX === 'undefined' || /[?&]px=0/.test(location.search)) return;
  var P = window.PIXI, NOGL = /[?&]fxgl=0/.test(location.search), TEXV = 2;
  PX.vstats = { v: 0, i: 0, seg: 0, arc: 0 };

  // ---------- 色 ----------
  var CC = new Map();
  function rgba(s) { // 'rgba(r,g,b,a)'・'#fff' など → [r,g,b,a]（0〜1）
    if (typeof s !== 'string') return [0, 0, 0, 0];
    if (s.charCodeAt(0) === 114) { var o = s.indexOf('('), p = s.slice(o + 1, s.lastIndexOf(')')).split(','), a = p.length > 3 ? +p[3] : 1; return [+p[0] / 255 || 0, +p[1] / 255 || 0, +p[2] / 255 || 0, a > 1 ? 1 : a > 0 ? a : 0]; }
    var c = CC.get(s); if (c) return c;
    try { var q = new P.Color(s).toArray(); c = [q[0], q[1], q[2], q[3]]; } catch (e) { c = [0, 0, 0, 1]; }
    CC.set(s, c); return c;
  }
  function LG(x0, y0, x1, y1) { this.r = 0; this.x0 = x0; this.y0 = y0; this.x1 = x1; this.y1 = y1; this.s = []; }
  function RG(x0, y0, r0, x1, y1, r1) { this.r = 1; this.x0 = x0; this.y0 = y0; this.r0 = r0; this.x1 = x1; this.y1 = y1; this.r1 = r1; this.s = []; }
  LG.prototype.addColorStop = RG.prototype.addColorStop = function (o, c) { this.s.push(o, rgba(c)); };
  var GC = [0, 0, 0, 0];
  function gAt(g, t) { // グラデーションの t の色（止めの間を線形に）
    var s = g.s, n = s.length; if (!n) { GC[3] = 0; return GC; }
    if (t <= s[0]) return s[1]; if (t >= s[n - 2]) return s[n - 1];
    for (var i = 2; i < n; i += 2) if (t <= s[i]) { var a = s[i - 2], b = s[i], k = b > a ? (t - a) / (b - a) : 1, A = s[i - 1], B = s[i + 1]; GC[0] = A[0] + (B[0] - A[0]) * k; GC[1] = A[1] + (B[1] - A[1]) * k; GC[2] = A[2] + (B[2] - A[2]) * k; GC[3] = A[3] + (B[3] - A[3]) * k; return GC; }
    return s[n - 1];
  }
  function gT(g, x, y) { // 局所の座標 (x,y) でのグラデーションの位置
    if (!g.r) { var dx = g.x1 - g.x0, dy = g.y1 - g.y0, d = dx * dx + dy * dy; return d ? ((x - g.x0) * dx + (y - g.y0) * dy) / d : 0; }
    var cx = g.x1 - g.x0, cy = g.y1 - g.y0, dr = g.r1 - g.r0, px = x - g.x0, py = y - g.y0, A = cx * cx + cy * cy - dr * dr, B = px * cx + py * cy + g.r0 * dr, C = px * px + py * py - g.r0 * g.r0;
    if (Math.abs(A) < 1e-6) return B ? C / (2 * B) : 1;
    var D = B * B - A * C; if (D < 0) return 1; D = Math.sqrt(D); var t1 = (B + D) / A, t2 = (B - D) / A, t = Math.max(t1, t2); // 大きい方（半径が負にならない方）
    if (g.r0 + t * dr < 0) t = Math.min(t1, t2); return t;
  }

  // ---------- 頂点の束（層ごと・斬撃の弧で区切る） ----------
  var VS = 'attribute vec2 aPosition; attribute vec4 aColor; uniform mat3 uProjectionMatrix; uniform mat3 uWorldTransformMatrix; uniform mat3 uTransformMatrix; varying vec4 vColor;\n' +
    'void main(){ mat3 m = uProjectionMatrix * uWorldTransformMatrix * uTransformMatrix; gl_Position = vec4((m * vec3(aPosition, 1.0)).xy, 0.0, 1.0); vColor = aColor; }';
  var FS = 'varying vec4 vColor; void main(){ gl_FragColor = vColor; }';
  var vShader = null;
  function Seg() {
    this.vc = 2048; this.ic = 6144; this.pos = new Float32Array(this.vc * 2); this.col = new Float32Array(this.vc * 4); this.idx = new Uint32Array(this.ic); this.nv = 0; this.ni = 0;
    this.geo = new P.Geometry({ attributes: { aPosition: { buffer: new P.Buffer({ data: new Float32Array(8), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x2' }, aColor: { buffer: new P.Buffer({ data: new Float32Array(16), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x4' } }, indexBuffer: new P.Buffer({ data: new Uint32Array(3), usage: P.BufferUsage.INDEX | P.BufferUsage.COPY_DST }) });
    this.mesh = new P.Mesh({ geometry: this.geo, shader: vShader });
  }
  Seg.prototype.grow = function (nv, ni) {
    if (this.nv + nv > this.vc) { this.vc = Math.max(this.vc * 2, this.nv + nv); var p = new Float32Array(this.vc * 2), c = new Float32Array(this.vc * 4); p.set(this.pos); c.set(this.col); this.pos = p; this.col = c; }
    if (this.ni + ni > this.ic) { this.ic = Math.max(this.ic * 2, this.ni + ni); var q = new Uint32Array(this.ic); q.set(this.idx); this.idx = q; }
  };
  Seg.prototype.flush = function () { // GPU へ送る
    this.geo.getBuffer('aPosition').data = this.pos.subarray(0, this.nv * 2); this.geo.getBuffer('aColor').data = this.col.subarray(0, this.nv * 4); this.geo.indexBuffer.data = this.idx.subarray(0, this.ni);
    PX.vstats.v += this.nv; PX.vstats.i += this.ni;
  };

  // ---------- 記録係 ----------
  function VX() { this.m = [1, 0, 0, 1, 0, 0]; this.st = []; this.reset(); this.sp = []; this.cur = null; this.seg = null; this.L = null; }
  var X = VX.prototype;
  X.reset = function () { this.globalAlpha = 1; this.globalCompositeOperation = 'source-over'; this.fillStyle = '#000'; this.strokeStyle = '#000'; this.lineWidth = 1; this.lineCap = 'butt'; this.lineJoin = 'miter'; this.dash = []; this.lineDashOffset = 0; this.font = ''; this.textAlign = 'left'; this.textBaseline = 'alphabetic'; this.st.length = 0; };
  X.save = function () { this.st.push([this.m.slice(), this.globalAlpha, this.globalCompositeOperation, this.fillStyle, this.strokeStyle, this.lineWidth, this.lineCap, this.dash, this.lineDashOffset]); };
  X.restore = function () { var s = this.st.pop(); if (!s) return; this.m = s[0]; this.globalAlpha = s[1]; this.globalCompositeOperation = s[2]; this.fillStyle = s[3]; this.strokeStyle = s[4]; this.lineWidth = s[5]; this.lineCap = s[6]; this.dash = s[7]; this.lineDashOffset = s[8]; };
  X.setTransform = function (a, b, c, d, e, f) { this.m = [a, b, c, d, e, f]; };
  X.getTransform = function () { var m = this.m; return { a: m[0], b: m[1], c: m[2], d: m[3], e: m[4], f: m[5] }; };
  X.transform = function (a, b, c, d, e, f) { var m = this.m; this.m = [m[0] * a + m[2] * b, m[1] * a + m[3] * b, m[0] * c + m[2] * d, m[1] * c + m[3] * d, m[0] * e + m[2] * f + m[4], m[1] * e + m[3] * f + m[5]]; };
  X.translate = function (x, y) { var m = this.m; m[4] += m[0] * x + m[2] * y; m[5] += m[1] * x + m[3] * y; };
  X.scale = function (x, y) { var m = this.m; m[0] *= x; m[1] *= x; m[2] *= y; m[3] *= y; };
  X.rotate = function (r) { var c = Math.cos(r), s = Math.sin(r); this.transform(c, s, -s, c, 0, 0); };
  X.setLineDash = function (a) { this.dash = a && a.length ? a.slice() : []; };
  X.getLineDash = function () { return this.dash.slice(); };
  X.createLinearGradient = function (x0, y0, x1, y1) { return new LG(x0, y0, x1, y1); };
  X.createRadialGradient = function (x0, y0, r0, x1, y1, r1) { return new RG(x0, y0, r0, x1, y1, r1); };
  X.measureText = function () { return { width: 0 }; }; X.fillText = X.strokeText = X.clip = X.clearRect = X.drawImage = function () { };
  X.sc = function () { var m = this.m; return Math.sqrt(Math.abs(m[0] * m[3] - m[1] * m[2])) || 1e-6; };
  // 道（画面の座標で持つ）
  X.beginPath = function () { this.sp.length = 0; this.cur = null; };
  X.moveTo = function (x, y) { var m = this.m; this.cur = { p: [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]], c: false }; this.sp.push(this.cur); };
  X.pt = function (sx, sy) { if (!this.cur) { this.cur = { p: [], c: false }; this.sp.push(this.cur); } var p = this.cur.p, n = p.length; if (n && Math.abs(p[n - 2] - sx) < 1e-3 && Math.abs(p[n - 1] - sy) < 1e-3) return; p.push(sx, sy); };
  X.lineTo = function (x, y) { var m = this.m; this.pt(m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]); };
  X.closePath = function () { if (!this.cur || !this.cur.p.length) return; this.cur.c = true; var p = this.cur.p; this.cur = { p: [p[0], p[1]], c: false }; this.sp.push(this.cur); };
  X.last = function () { var p = this.cur && this.cur.p, n = p ? p.length : 0; return n ? [p[n - 2], p[n - 1]] : null; };
  X.quadraticCurveTo = function (cx, cy, x, y) {
    var m = this.m, a = this.last(); if (!a) { this.moveTo(cx, cy); a = this.last(); }
    var bx = m[0] * cx + m[2] * cy + m[4], by = m[1] * cx + m[3] * cy + m[5], ex = m[0] * x + m[2] * y + m[4], ey = m[1] * x + m[3] * y + m[5];
    var n = Math.max(4, Math.min(32, Math.ceil((Math.hypot(bx - a[0], by - a[1]) + Math.hypot(ex - bx, ey - by)) / 10)));
    for (var i = 1; i <= n; i++) { var t = i / n, u = 1 - t; this.pt(u * u * a[0] + 2 * u * t * bx + t * t * ex, u * u * a[1] + 2 * u * t * by + t * t * ey); }
  };
  X.bezierCurveTo = function (c1x, c1y, c2x, c2y, x, y) {
    var m = this.m, a = this.last(); if (!a) { this.moveTo(c1x, c1y); a = this.last(); }
    var T = function (px, py) { return [m[0] * px + m[2] * py + m[4], m[1] * px + m[3] * py + m[5]]; }, b = T(c1x, c1y), c = T(c2x, c2y), e = T(x, y);
    var n = Math.max(6, Math.min(40, Math.ceil((Math.hypot(b[0] - a[0], b[1] - a[1]) + Math.hypot(c[0] - b[0], c[1] - b[1]) + Math.hypot(e[0] - c[0], e[1] - c[1])) / 10)));
    for (var i = 1; i <= n; i++) { var t = i / n, u = 1 - t; this.pt(u * u * u * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t * t * t * e[0], u * u * u * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t * t * t * e[1]); }
  };
  X.ellipse = function (x, y, rx, ry, rot, a0, a1, ccw) {
    rx = Math.abs(rx); ry = Math.abs(ry); var TAU = 6.283185307179586, sw = a1 - a0, full = false;
    if (!ccw) { if (sw >= TAU - 1e-4) { sw = TAU; full = true; } else { sw = sw % TAU; if (sw < 0) sw += TAU; } }
    else { if (-sw >= TAU - 1e-4) { sw = -TAU; full = true; } else { sw = -((a0 - a1) % TAU); if (sw > 0) sw -= TAU; } }
    var m = this.m, s = this.sc(), n = Math.max(6, Math.min(128, Math.ceil(Math.abs(sw) * Math.sqrt(Math.max(rx, ry) * s + 1) * 0.9))), cr = Math.cos(rot || 0), sr = Math.sin(rot || 0);
    if (full && this.cur && this.cur.p.length) { this.cur = null; } // 丸ごとの輪は、前の道とつなげない（今の使い方では、beginPath の直後か moveTo なし）
    for (var i = 0; i <= n; i++) { if (full && i === n) break; var t = a0 + sw * i / n, ex = Math.cos(t) * rx, ey = Math.sin(t) * ry, lx = x + ex * cr - ey * sr, ly = y + ex * sr + ey * cr; this.pt(m[0] * lx + m[2] * ly + m[4], m[1] * lx + m[3] * ly + m[5]); }
    if (full) { this.cur.c = true; this.cur = null; }
  };
  X.arc = function (x, y, r, a0, a1, ccw) { this.ellipse(x, y, r, r, 0, a0, a1, ccw); };
  X.rect = function (x, y, w, h) { this.moveTo(x, y); this.lineTo(x + w, y); this.lineTo(x + w, y + h); this.lineTo(x, y + h); this.cur.c = true; this.cur = null; };

  // 頂点を積む：今の塗り（単色かグラデーション）の色。am＝縁の薄め
  X.prep = function (style) {
    this.add = this.globalCompositeOperation === 'lighter'; this.ga = this.globalAlpha;
    if (typeof style === 'string') { this.sol = rgba(style); this.g = null; return this.sol[3] * this.ga > 0.002; }
    if (style instanceof LG || style instanceof RG) {
      this.sol = null; this.g = style; var m = this.m, d = m[0] * m[3] - m[1] * m[2] || 1e-9; this.im = [m[3] / d, -m[1] / d, -m[2] / d, m[0] / d, (m[2] * m[5] - m[3] * m[4]) / d, (m[1] * m[4] - m[0] * m[5]) / d];
      for (var i = 1, any = false; i < style.s.length; i += 2) if (style.s[i][3] > 0.002) any = true; return any && this.ga > 0.002;
    }
    return false;
  };
  X.v = function (x, y, am) {
    var S = this.seg, k = S.nv, c = this.sol;
    if (!c) { var im = this.im; c = gAt(this.g, gT(this.g, im[0] * x + im[2] * y + im[4], im[1] * x + im[3] * y + im[5])); }
    var a = c[3] * this.ga * am, p = k * 2, q = k * 4; S.pos[p] = x; S.pos[p + 1] = y; S.col[q] = c[0] * a; S.col[q + 1] = c[1] * a; S.col[q + 2] = c[2] * a; S.col[q + 3] = this.add ? 0 : a; S.nv++; return k;
  };
  X.tri = function (a, b, c) { var S = this.seg, i = S.ni; S.idx[i] = a; S.idx[i + 1] = b; S.idx[i + 2] = c; S.ni += 3; };
  X.quad = function (a, b, c, d) { this.tri(a, b, c); this.tri(a, c, d); };
  function subdiv(p, closed, L) { // 長い辺を L 以下に分ける（グラデーションの色を頂点で拾うため）
    var o = [], n = p.length / 2, e = closed ? n : n - 1;
    for (var i = 0; i < e; i++) { var j = (i + 1) % n, x0 = p[i * 2], y0 = p[i * 2 + 1], x1 = p[j * 2], y1 = p[j * 2 + 1], k = Math.ceil(Math.hypot(x1 - x0, y1 - y0) / L); o.push(x0, y0); for (var s = 1; s < k; s++) o.push(x0 + (x1 - x0) * s / k, y0 + (y1 - y0) * s / k); }
    if (!closed) o.push(p[(n - 1) * 2], p[(n - 1) * 2 + 1]); return o;
  }
  function dashes(p, closed, D, off) { // 点線に切る（画面の長さ）
    var pts = closed ? p.concat([p[0], p[1]]) : p, out = [], tot = 0; for (var i = 0; i < D.length; i++) tot += D[i]; if (!(tot > 0)) return [p];
    var di = 0, rem, on = true, o = ((off % tot) + tot) % tot; while (o > 0) { if (o >= D[di]) { o -= D[di]; di = (di + 1) % D.length; on = !on; } else break; } rem = D[di] - o;
    var cur = on ? [pts[0], pts[1]] : null;
    for (i = 0; i + 3 < pts.length; i += 2) {
      var x0 = pts[i], y0 = pts[i + 1], x1 = pts[i + 2], y1 = pts[i + 3], L = Math.hypot(x1 - x0, y1 - y0), u = 0;
      while (L - u > rem) { u += rem; var x = x0 + (x1 - x0) * u / L, y = y0 + (y1 - y0) * u / L; if (on) { cur.push(x, y); out.push(cur); cur = null; } else cur = [x, y]; on = !on; di = (di + 1) % D.length; rem = D[di]; if (out.length > 600) return out; }
      rem -= L - u; if (on) cur.push(x1, y1);
    }
    if (on && cur && cur.length >= 4) out.push(cur); return out;
  }
  X.F = 0.5;
  X.stroke = function () {
    if (!this.sp.length || !this.prep(this.strokeStyle)) return;
    var hw = this.lineWidth * this.sc() / 2; if (!(hw > 0)) return;
    var round = this.lineCap === 'round', D = null; if (this.dash.length) { var s = this.sc(); D = this.dash.map(function (v) { return Math.max(0.5, v * s); }); }
    for (var i = 0; i < this.sp.length; i++) {
      var sp = this.sp[i], p = sp.p; if (p.length < 4) { if (round && p.length === 2 && !D) this.dot(p[0], p[1], hw); continue; }
      if (this.g) p = subdiv(p, sp.c, 14);
      if (D) { var ds = dashes(p, sp.c, D, this.lineDashOffset * this.sc()); for (var k = 0; k < ds.length; k++) this.poly(ds[k], false, hw, round); }
      else this.poly(p, sp.c, hw, round);
    }
  };
  X.poly = function (p, closed, hw, round) { // 太さのある線（縁は 1px の柔らかい帯）
    var n = p.length / 2; if (closed && n > 2 && Math.abs(p[0] - p[n * 2 - 2]) < 1e-3 && Math.abs(p[1] - p[n * 2 - 1]) < 1e-3) { p = p.slice(0, -2); n--; }
    if (n < 2) return; var F = this.F, w2 = Math.max(hw, F), am = Math.min(1, hw / F), o1 = w2 + F, o2 = w2 - F;
    this.seg.grow(n * 4 + 40, n * 18 + 120);
    var base = -1, first = -1, nx0 = 0, ny0 = 0;
    for (var i = 0; i < n; i++) {
      var x = p[i * 2], y = p[i * 2 + 1], ip = i - 1, inx = i + 1, ax, ay, bx, by;
      if (ip < 0) ip = closed ? n - 1 : -1; if (inx >= n) inx = closed ? 0 : -1;
      if (ip >= 0) { ax = x - p[ip * 2]; ay = y - p[ip * 2 + 1]; var la = Math.hypot(ax, ay) || 1; ax /= la; ay /= la; }
      if (inx >= 0) { bx = p[inx * 2] - x; by = p[inx * 2 + 1] - y; var lb = Math.hypot(bx, by) || 1; bx /= lb; by /= lb; }
      if (ip < 0) { ax = bx; ay = by; } if (inx < 0) { bx = ax; by = ay; }
      var mx = -(ay + by), my = ax + bx, ml = Math.hypot(mx, my); if (ml < 1e-4) { mx = -ay; my = ax; ml = 1; } mx /= ml; my /= ml;
      var dt = mx * -ay + my * ax, k = 1 / Math.max(0.4, dt); // 角の伸び（とがりすぎは抑える）
      var ux = mx * k, uy = my * k;
      var v0 = this.v(x + ux * o1, y + uy * o1, 0), v1 = this.v(x + ux * o2, y + uy * o2, am); this.v(x - ux * o2, y - uy * o2, am); this.v(x - ux * o1, y - uy * o1, 0);
      if (i === 0) { first = v0; nx0 = -ay; ny0 = ax; } else { this.quad(base, base + 1, v1, v0); this.quad(base + 1, base + 2, v1 + 1, v1); this.quad(base + 2, base + 3, v1 + 2, v1 + 1); }
      base = v0;
    }
    if (closed) { this.quad(base, base + 1, first + 1, first); this.quad(base + 1, base + 2, first + 2, first + 1); this.quad(base + 2, base + 3, first + 3, first + 2); return; }
    if (!round) return;
    this.cap(p[0], p[1], -(p[2] - p[0]), -(p[3] - p[1]), o1, o2, am);
    this.cap(p[n * 2 - 2], p[n * 2 - 1], p[n * 2 - 2] - p[n * 2 - 4], p[n * 2 - 1] - p[n * 2 - 3], o1, o2, am);
  };
  X.cap = function (x, y, dx, dy, o1, o2, am) { // 丸い端（半円）
    var l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l; var nx = -dy, ny = dx, N = o1 > 6 ? 10 : 6, c = this.v(x, y, am), pi = -1, po = -1;
    this.seg.grow(N * 2 + 4, N * 9 + 9);
    for (var j = 0; j <= N; j++) { var a = Math.PI * j / N - Math.PI / 2, cs = Math.cos(a), sn = Math.sin(a), ex = dx * cs + nx * -sn, ey = dy * cs + ny * -sn;
      var vi = this.v(x + ex * o2, y + ey * o2, am), vo = this.v(x + ex * o1, y + ey * o1, 0);
      if (j) { this.tri(c, pi, vi); this.quad(pi, po, vo, vi); } pi = vi; po = vo; }
  };
  X.dot = function (x, y, hw) { var F = this.F; this.cap(x, y, 1, 0, Math.max(hw, F) + F, Math.max(hw, F) - F, Math.min(1, hw / F)); this.cap(x, y, -1, 0, Math.max(hw, F) + F, Math.max(hw, F) - F, Math.min(1, hw / F)); };
  X.fill = function () {
    if (!this.sp.length || !this.prep(this.fillStyle)) return;
    if (this.g && this.g.r) return this.disk(this.g);
    for (var i = 0; i < this.sp.length; i++) { var p = this.sp[i].p; if (p.length >= 6) this.area(this.g ? subdiv(p, true, 18) : p); }
  };
  X.fillRect = function (x, y, w, h) {
    if (!this.prep(this.fillStyle)) return;
    var g = this.g; if (g && g.r) return this.disk(g);
    var m = this.m;
    if (g) { // 線形のグラデーション：格子に分けて色を拾う
      var vert = Math.abs(g.x1 - g.x0) < 1e-6, hor = Math.abs(g.y1 - g.y0) < 1e-6, nx = vert ? 1 : 16, ny = hor ? 1 : 16, b = this.seg.nv; this.seg.grow((nx + 1) * (ny + 1), nx * ny * 6);
      for (var j = 0; j <= ny; j++) for (var i = 0; i <= nx; i++) { var lx = x + w * i / nx, ly = y + h * j / ny; this.v(m[0] * lx + m[2] * ly + m[4], m[1] * lx + m[3] * ly + m[5], 1); }
      for (j = 0; j < ny; j++) for (i = 0; i < nx; i++) { var a = b + j * (nx + 1) + i; this.quad(a, a + 1, a + nx + 2, a + nx + 1); }
      return;
    }
    var T = function (px, py) { return [m[0] * px + m[2] * py + m[4], m[1] * px + m[3] * py + m[5]]; }, A = T(x, y), B = T(x + w, y), C = T(x + w, y + h), Dd = T(x, y + h);
    this.area([A[0], A[1], B[0], B[1], C[0], C[1], Dd[0], Dd[1]]);
  };
  X.disk = function (g) { // 放射のグラデーション：外の円（x1,y1,r1）を同心の輪で塗る（外の止めは透明の前提）
    var m = this.m, s = this.sc(), R = g.r1, few = g.s.length <= 6 && g.r0 === 0 && g.x0 === g.x1 && g.y0 === g.y1, segs = Math.max(12, Math.min(few ? 24 : 36, Math.ceil(R * s / (few ? 7 : 5)))), rings = R * s < 40 ? [0.15, 0.4, 0.7, 1] : few ? [0.12, 0.3, 0.55, 0.78, 1] : [0.08, 0.2, 0.33, 0.47, 0.62, 0.78, 0.9, 1]; // 止めが3つまでの同心の光（砂埃・光の丸）は粗くてよい
    if (!(R > 0)) return; var nr = rings.length, b, cx = g.x1, cy = g.y1;
    this.seg.grow(nr * segs + 1, segs * 3 + (nr - 1) * segs * 6);
    b = this.v(m[0] * cx + m[2] * cy + m[4], m[1] * cx + m[3] * cy + m[5], 1);
    for (var r = 0; r < nr; r++) for (var j = 0; j < segs; j++) { var a = j / segs * 6.283185307, lx = cx + Math.cos(a) * R * rings[r], ly = cy + Math.sin(a) * R * rings[r]; this.v(m[0] * lx + m[2] * ly + m[4], m[1] * lx + m[3] * ly + m[5], 1); }
    for (j = 0; j < segs; j++) this.tri(b, b + 1 + j, b + 1 + (j + 1) % segs);
    for (r = 0; r + 1 < nr; r++) for (j = 0; j < segs; j++) { var i0 = b + 1 + r * segs, i1 = i0 + segs, jn = (j + 1) % segs; this.quad(i0 + j, i0 + jn, i1 + jn, i1 + j); }
  };
  X.area = function (p) { // 多角形を塗る（耳切りで三角形に）＋外へ 1px の柔らかい縁
    var n = p.length / 2; if (n > 2 && Math.abs(p[0] - p[n * 2 - 2]) < 1e-3 && Math.abs(p[1] - p[n * 2 - 1]) < 1e-3) { p = p.slice(0, -2); n--; } if (n < 3) return;
    var ar = 0; for (var i = 0; i < n; i++) { var j = (i + 1) % n; ar += p[i * 2] * p[j * 2 + 1] - p[j * 2] * p[i * 2 + 1]; } if (Math.abs(ar) < 1e-4) return;
    var sg = ar > 0 ? 1 : -1, F2 = this.F * 2, b = this.seg.nv; this.seg.grow(n * 2, n * 9);
    for (i = 0; i < n; i++) this.v(p[i * 2], p[i * 2 + 1], 1);
    for (i = 0; i < n; i++) { // 外向きの法線（隣の2辺の平均）
      var ip = (i + n - 1) % n, inx = (i + 1) % n, ax = p[i * 2] - p[ip * 2], ay = p[i * 2 + 1] - p[ip * 2 + 1], bx = p[inx * 2] - p[i * 2], by = p[inx * 2 + 1] - p[i * 2 + 1], la = Math.hypot(ax, ay) || 1, lb = Math.hypot(bx, by) || 1;
      var nx = (ay / la + by / lb) * sg, ny = -(ax / la + bx / lb) * sg, nl = Math.hypot(nx, ny) || 1; this.v(p[i * 2] + nx / nl * F2, p[i * 2 + 1] + ny / nl * F2, 0);
    }
    var o = b + n; for (i = 0; i < n; i++) { j = (i + 1) % n; this.quad(b + i, b + j, o + j, o + i); }
    earcut(p, n, sg, this, b);
  };
  function earcut(p, n, sg, X, b) { // 単純な多角形の耳切り（n は数十まで）。うまく切れないときは扇形
    if (n === 3) { X.tri(b, b + 1, b + 2); return; }
    var V = new Array(n); for (var i = 0; i < n; i++) V[i] = i; var m = n, guard = 0, c = 0;
    function cr(a, b2, c2) { return ((p[b2 * 2] - p[a * 2]) * (p[c2 * 2 + 1] - p[a * 2 + 1]) - (p[b2 * 2 + 1] - p[a * 2 + 1]) * (p[c2 * 2] - p[a * 2])) * sg; }
    function inside(a, b2, c2, q) { return cr(a, b2, q) >= 0 && cr(b2, c2, q) >= 0 && cr(c2, a, q) >= 0; }
    while (m > 3 && guard++ < n * 3) {
      var i0 = V[(c + m - 1) % m], i1 = V[c % m], i2 = V[(c + 1) % m], ok = cr(i0, i1, i2) > 1e-9;
      if (ok) for (var k = 0; k < m; k++) { var q = V[k]; if (q === i0 || q === i1 || q === i2) continue; if (inside(i0, i1, i2, q)) { ok = false; break; } }
      if (ok) { X.tri(b + i0, b + i1, b + i2); V.splice(c % m, 1); m--; c = c % m; guard = 0; } else c = (c + 1) % m;
    }
    if (m > 3) { for (i = 1; i + 1 < m; i++) X.tri(b + V[0], b + V[i], b + V[i + 1]); return; }
    X.tri(b + V[0], b + V[1], b + V[2]);
  }

  // ---------- 斬撃の弧のシェーダー（terrain/fx_gl.js と同じ。暗い下地・柔らかい光・本体を、1つの形の束で） ----------
  var AVS = 'attribute vec2 aPosition; attribute vec3 aUv; uniform mat3 uProjectionMatrix; uniform mat3 uWorldTransformMatrix; uniform mat3 uTransformMatrix; varying vec2 vUv; varying float vMode;\n' +
    'void main(){ mat3 m = uProjectionMatrix * uWorldTransformMatrix * uTransformMatrix; gl_Position = vec4((m * vec3(aPosition, 1.0)).xy, 0.0, 1.0); vUv = aUv.xy; vMode = aUv.z; }';
  var AFS = 'varying vec2 vUv; varying float vMode; uniform sampler2D uShape; uniform sampler2D uNoise; uniform sampler2D uRamp; uniform sampler2D uFiber; uniform float uHead; uniform float uTail; uniform float uErode; uniform float uPan; uniform float uAlpha; uniform float uRep;\n' +
    'void main(){\n' +
    '  vec4 s = texture2D(uShape, vec2(.18 + .82 * pow(vUv.x, .7), vUv.y));\n' +
    '  float fb = texture2D(uFiber, vec2(vUv.x * uRep - uPan * 1.4, vUv.y * .5)).r;\n' +
    '  float n = texture2D(uNoise, vec2(vUv.x * 1.6 - uPan * 1.7, vUv.y * .7 + uPan * .4)).r;\n' +
    '  float sweep = smoothstep(uTail, uTail + .18, vUv.x) * (1.0 - smoothstep(uHead - .03, uHead, vUv.x));\n' +
    '  float e = (s.g * .62 + n * .38) * (.72 + .28 * vUv.x);\n' +
    '  float keep = smoothstep(uErode, uErode + .1, e);\n' +
    '  float band = (smoothstep(uErode - .02, uErode + .03, e) - smoothstep(uErode + .03, uErode + .12, e)) * step(.01, uErode);\n' +
    '  float a = s.r * sweep * keep;\n' +
    '  if (vMode > 1.5) { float pr = 1.0 - abs(vUv.y - .4) / .6; float gw = max(pr, 0.0) * sweep * smoothstep(uErode, uErode + .3, .5 + n * .5) * .32 * uAlpha; gl_FragColor = vec4(texture2D(uRamp, vec2(.62, .5)).rgb * gw, 0.0); return; }\n' +
    '  if (vMode > .5) { float d = s.r * sweep * keep * .55 * uAlpha; gl_FragColor = vec4(vec3(.06, .02, .05) * d, d); return; }\n' +
    '  float inten = clamp(a * (.45 + .55 * fb + .25 * n) + band * s.r * sweep * 1.2, 0.0, 1.0);\n' +
    '  gl_FragColor = vec4(texture2D(uRamp, vec2(inten, .5)).rgb * inten * uAlpha, 0.0);\n' +
    '}';
  var TX = {}, txN = 0, txReady = false; // 画像AIの素材を作り直したら TEXV を上げる
  function loadTex(name, rep) {
    var im = new Image(); im.onload = function () { TX[name] = new P.Texture({ source: new P.ImageSource({ resource: im, addressMode: rep ? 'repeat' : 'clamp-to-edge', scaleMode: 'linear' }) }); if (['band_ink', 'band_blade', 'band_smash', 'noise_cloud', 'noise_fiber'].every(function (k) { return TX[k]; })) txReady = true; };
    im.src = 'terrain/assets/fx/' + name + (/_col$/.test(name) ? '.webp' : '.png') + '?v=' + TEXV; // 色の絵は WebP（透過）
  }
  var RAMP = new Map();
  function rampTex(C) { // 色の帯（暗→光→本体→火花→芯）。ラナ・味方の青は fx_gl の帯、ほかは色の組から
    var t = RAMP.get(C); if (t) return t;
    var st = C === VFX_RANA ? [[0, '40,0,6'], [.35, '170,15,30'], [.65, '255,90,50'], [.85, '255,200,110'], [1, '255,245,220']]
      : C === VFX_ATK ? [[0, '0,10,40'], [.35, '30,90,230'], [.65, '90,170,255'], [.85, '255,214,140'], [1, '255,250,235']]
      : [[0, C.dark || '0,0,0'], [.35, C.glow], [.65, C.main], [.85, C.spark || C.main], [1, C.core]];
    var c = document.createElement('canvas'); c.width = 256; c.height = 1; var g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 256, 0);
    st.forEach(function (s) { gr.addColorStop(s[0], 'rgb(' + s[1] + ')'); }); g.fillStyle = gr; g.fillRect(0, 0, 256, 1);
    t = new P.Texture({ source: new P.CanvasSource({ resource: c, addressMode: 'clamp-to-edge' }) }); RAMP.set(C, t); return t;
  }
  function Arc() {
    this.cap = 0; this.uni = new P.UniformGroup({ uHead: { value: 0, type: 'f32' }, uTail: { value: 0, type: 'f32' }, uErode: { value: 0, type: 'f32' }, uPan: { value: 0, type: 'f32' }, uAlpha: { value: 1, type: 'f32' }, uRep: { value: 1.6, type: 'f32' } });
    this.shader = P.Shader.from({ gl: { vertex: AVS, fragment: AFS }, resources: { uShape: TX.band_ink.source, uNoise: TX.noise_cloud.source, uRamp: TX.noise_cloud.source, uFiber: TX.noise_fiber.source, arcU: this.uni } });
    this.geo = new P.Geometry({ attributes: { aPosition: { buffer: new P.Buffer({ data: new Float32Array(8), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x2' }, aUv: { buffer: new P.Buffer({ data: new Float32Array(12), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x3' } }, indexBuffer: new P.Buffer({ data: new Uint32Array(3), usage: P.BufferUsage.INDEX | P.BufferUsage.COPY_DST }) });
    this.mesh = new P.Mesh({ geometry: this.geo, shader: this.shader });
  }
  var E3 = function (t) { t = t < 0 ? 0 : t > 1 ? 1 : t; return 1 - Math.pow(1 - t, 3); };
  // o: { pts:[局所の中心線 x,y,…], nrm:[外向きの法線], w:[太さ], inner:内側の比, ms, sw, life, pal, tex }
  X.slashGL = function (o) {
    if (NOGL || !txReady || !this.L) return false;
    var L = this.L, a = L.arcs[L.na] || (L.arcs[L.na] = new Arc()); L.na++;
    var N = o.pts.length / 2, m = this.m, pos = new Float32Array(N * 2 * 3 * 2), uv = new Float32Array(N * 2 * 3 * 3), idx = new Uint32Array((N - 1) * 6 * 3);
    for (var pass = 0; pass < 3; pass++) { // 0＝暗い下地（mode 1）、1＝柔らかい光（mode 2、2.4倍の幅）、2＝本体（mode 0）
      var mode = pass === 0 ? 1 : pass === 1 ? 2 : 0, wide = pass === 1 ? 2.4 : 1, vb = pass * N * 2;
      for (var i = 0; i < N; i++) {
        var x = o.pts[i * 2], y = o.pts[i * 2 + 1], nx = o.nrm[i * 2], ny = o.nrm[i * 2 + 1], w = o.w[i], wi = w * o.inner, c = (w - wi) / 2, mx = x + nx * c, my = y + ny * c, h = (w + wi) / 2 * wide; // 中ほどから外・内へ
        var ox = mx + nx * h, oy = my + ny * h, ix = mx - nx * h, iy = my - ny * h, k = (vb + i * 2) * 2, u = i / (N - 1);
        pos[k] = m[0] * ox + m[2] * oy + m[4]; pos[k + 1] = m[1] * ox + m[3] * oy + m[5]; pos[k + 2] = m[0] * ix + m[2] * iy + m[4]; pos[k + 3] = m[1] * ix + m[3] * iy + m[5];
        var q = (vb + i * 2) * 3; uv[q] = u; uv[q + 1] = 0; uv[q + 2] = mode; uv[q + 3] = u; uv[q + 4] = 1; uv[q + 5] = mode;
        if (i) { var j = (pass * (N - 1) + i - 1) * 6, b0 = vb + (i - 1) * 2; idx[j] = b0; idx[j + 1] = b0 + 1; idx[j + 2] = b0 + 2; idx[j + 3] = b0 + 1; idx[j + 4] = b0 + 3; idx[j + 5] = b0 + 2; }
      }
    }
    a.geo.getBuffer('aPosition').data = pos; a.geo.getBuffer('aUv').data = uv; a.geo.indexBuffer.data = idx;
    var ms = o.ms, sw = o.sw, lf = o.life * 1000, U = a.uni.uniforms;
    U.uHead = E3(ms / sw) * 1.03; U.uTail = E3((ms - sw * 0.85) / Math.max(1, lf - sw * 0.85)) * 0.55; U.uErode = Math.max(0, Math.min(1, (ms - sw) / Math.max(1, lf - sw))) * 1.05; U.uPan = ms * 0.0022; U.uAlpha = this.globalAlpha; U.uRep = 1.6;
    var R = a.shader.resources; R.uShape = (TX['band_' + (o.tex || 'ink')] || TX.band_ink).source; R.uRamp = rampTex(o.pal).source;
    this.cut(); L.c.addChild(a.mesh); PX.vstats.arc++;
    return true;
  };

  // ---------- 地面に貼る絵（デカール）：地割れ・えぐれ跡。現場の作り方：絵を貼る → 中心からの距離で順に現す → 発光を冷ます → 細らせて閉じる ----------
  // 素材（battle/tools/crack_tex.py）：R＝深さ（縁0→芯1）、G＝現れる順番、B＝縁の欠け（明るい土のふち）
  var DVS = 'attribute vec2 aPosition; attribute vec2 aUv; uniform mat3 uProjectionMatrix; uniform mat3 uWorldTransformMatrix; uniform mat3 uTransformMatrix; varying vec2 vUv;\n' +
    'void main(){ mat3 m = uProjectionMatrix * uWorldTransformMatrix * uTransformMatrix; gl_Position = vec4((m * vec3(aPosition, 1.0)).xy, 0.0, 1.0); vUv = aUv; }';
  var DFS = 'varying vec2 vUv; uniform sampler2D uTex; uniform sampler2D uRamp; uniform float uProg; uniform float uHeat; uniform float uClose; uniform float uAlpha;\n' +
    'void main(){\n' +
    '  if (vUv.x < 0.0 || vUv.x > 1.0 || vUv.y < 0.0 || vUv.y > 1.0) discard;\n' +
    '  vec3 d = texture2D(uTex, vUv).rgb;\n' +
    '  float vis = 1.0 - smoothstep(uProg - .06, uProg, d.g);\n' +              // 中心から順に現れる
    '  float cl = smoothstep(uClose, uClose + .12, d.r);\n' +                    // 閉じる：浅い所（細い枝先・縁）から消える
    '  float m = smoothstep(.02, .22, d.r) * vis * cl;\n' +
    '  float ad = m * .8 * uAlpha;\n' +
    '  float al = d.b * vis * (1.0 - uClose) * .5 * (1.0 - ad) * uAlpha;\n' +    // 縁の欠け（光を受ける土のふち）
    '  vec3 dark = mix(vec3(.38, .29, .21), vec3(.11, .07, .05), smoothstep(.15, .85, d.r));\n' + // 深いほど暗い
    '  float front = smoothstep(uProg - .18, uProg - .02, d.g) * vis;\n' +       // 割れが走る先端は熱い
    '  float e = (uHeat * pow(d.r, 1.3) * (1.15 - d.g * .6) + front * .9 * min(1.0, uHeat * 1.2) * step(uProg, 1.0)) * vis * cl;\n' +
    '  vec3 em = texture2D(uRamp, vec2(clamp(e, 0.0, 1.0), .5)).rgb * clamp(e * 1.5, 0.0, 1.0);\n' +
    '  gl_FragColor = vec4(dark * ad + vec3(.86, .78, .64) * al + em * uAlpha, ad + al);\n' +
    '}';
  // 色の絵のデカール（画像AIの手描き：battle/tools/decal_import.py）。uCol＝色と透明度、uTex＝データ（R＝深さ・G＝現れる順・B＝割れの溝）
  var CFS = 'varying vec2 vUv; uniform sampler2D uCol; uniform sampler2D uTex; uniform sampler2D uRamp; uniform float uProg; uniform float uHeat; uniform float uClose; uniform float uAlpha;\n' +
    'void main(){\n' +
    '  if (vUv.x < 0.0 || vUv.x > 1.0 || vUv.y < 0.0 || vUv.y > 1.0) discard;\n' +
    '  vec3 d = texture2D(uTex, vUv).rgb; vec4 c = texture2D(uCol, vUv);\n' +
    '  float vis = 1.0 - smoothstep(uProg - .08, uProg, d.g);\n' +              // 中心（走る跡は始まり）から順に現れる
    '  float cl = smoothstep(uClose, uClose + .15, d.r);\n' +                    // 縁・細い所から閉じる
    '  float k = vis * cl * uAlpha;\n' +
    '  float front = smoothstep(uProg - .2, uProg - .02, d.g) * vis;\n' +       // 走る先端は熱い
    '  float e = (uHeat * d.b * (1.2 - d.g * .5) + front * (.35 + d.b) * min(1.0, uHeat * 1.2) * step(uProg, 1.0)) * vis * cl;\n' +
    '  vec3 em = texture2D(uRamp, vec2(clamp(e, 0.0, 1.0), .5)).rgb * clamp(e * 1.6, 0.0, 1.0);\n' +
    '  vec3 base = c.a > .001 ? c.rgb / c.a : vec3(0.0);\n' +
    '  base = clamp((base - .5) * 1.45 + .42, 0.0, 1.0) * (1.0 - .55 * d.b);\n' +   // 地面と同じ土色に溶けないよう、明暗を強め、割れの溝を濃く
    '  gl_FragColor = vec4(base * c.a * k + em * uAlpha * c.a, c.a * k);\n' +
    '}';
  function Decal(col) {
    this.uni = new P.UniformGroup({ uProg: { value: 0, type: 'f32' }, uHeat: { value: 0, type: 'f32' }, uClose: { value: 0, type: 'f32' }, uAlpha: { value: 1, type: 'f32' } });
    var r0 = (TX.crack_a || TX.band_ink).source, res = { uTex: r0, uRamp: r0, decU: this.uni }; if (col) res.uCol = r0;
    this.shader = P.Shader.from({ gl: { vertex: DVS, fragment: col ? CFS : DFS }, resources: res });
    this.geo = new P.Geometry({ attributes: { aPosition: { buffer: new P.Buffer({ data: new Float32Array(8), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x2' }, aUv: { buffer: new P.Buffer({ data: new Float32Array(8), usage: P.BufferUsage.VERTEX | P.BufferUsage.COPY_DST }), format: 'float32x2' } }, indexBuffer: new P.Buffer({ data: new Uint32Array([0, 1, 2, 0, 2, 3]), usage: P.BufferUsage.INDEX | P.BufferUsage.COPY_DST }) });
    this.mesh = new P.Mesh({ geometry: this.geo, shader: this.shader });
  }
  // o: { tex, pts:[局所の4隅 x,y,…], uv:[4隅の uv], prog, heat, close, pal }
  X.decalGL = function (o) {
    if (NOGL || !this.L || !TX[o.tex] || !txReady) return false;
    if (o.col && !TX[o.col]) return false;
    var L = this.L, pool = o.col ? L.cdecals : L.decals, ni = o.col ? 'ncd' : 'nd', d = pool[L[ni]] || (pool[L[ni]] = new Decal(!!o.col)); L[ni]++;
    var m = this.m, p = o.pts, pos = new Float32Array(8);
    for (var i = 0; i < 4; i++) { var x = p[i * 2], y = p[i * 2 + 1]; pos[i * 2] = m[0] * x + m[2] * y + m[4]; pos[i * 2 + 1] = m[1] * x + m[3] * y + m[5]; }
    d.geo.getBuffer('aPosition').data = pos; d.geo.getBuffer('aUv').data = new Float32Array(o.uv);
    var U = d.uni.uniforms; U.uProg = o.prog; U.uHeat = o.heat; U.uClose = o.close; U.uAlpha = this.globalAlpha;
    d.shader.resources.uTex = TX[o.tex].source; d.shader.resources.uRamp = rampTex(o.pal).source; if (o.col) d.shader.resources.uCol = TX[o.col].source;
    this.cut(); L.c.addChild(d.mesh); PX.vstats.arc++;
    return true;
  };

  // ---------- 層 ----------
  function Lay() { this.c = new P.Container(); this.segs = []; this.ns = 0; this.arcs = []; this.na = 0; this.decals = []; this.nd = 0; this.cdecals = []; this.ncd = 0; }
  Lay.prototype.begin = function () { this.c.removeChildren(); this.ns = 0; this.na = 0; this.nd = 0; this.ncd = 0; };
  X.cut = function () { // 今の頂点の束を閉じて、次の束を始める（斬撃の弧を挟むとき）
    var L = this.L; if (this.seg && this.seg.nv) { this.seg.flush(); L.c.addChild(this.seg.mesh); PX.vstats.seg++; }
    var s = L.segs[L.ns] || (L.segs[L.ns] = new Seg()); L.ns++; s.nv = 0; s.ni = 0; this.seg = s;
  };
  X.open = function (L) { this.L = L; this.seg = null; this.cut(); };
  X.close = function () { var L = this.L; if (this.seg && this.seg.nv) { this.seg.flush(); L.c.addChild(this.seg.mesh); PX.vstats.seg++; } this.seg = null; this.L = null; };

  var vx = new VX(), lays = {};
  PX.vx = vx;
  function ready() {
    vShader = P.Shader.from({ gl: { vertex: VS, fragment: FS } });
    lays.under = new Lay(); lays.fx = new Lay();
    var w = PX.world; w.addChildAt(lays.under.c, w.getChildIndex(PX.chC)); w.addChild(lays.fx.c);
    if (!NOGL) ['band_ink', 'band_blade', 'band_smash', 'crack_a', 'crack_b', 'gouge', 'crater_col', 'crater_dat', 'gouge2_col', 'gouge2_dat'].forEach(function (k) { loadTex(k, false); }), ['noise_cloud', 'noise_fiber'].forEach(function (k) { loadTex(k, true); });
    PX.vOn = true;
  }
  if (PX.ready) { try { ready(); } catch (e) { PX.err = String(e && e.message || e); } } else (PX.onReady = PX.onReady || []).push(ready); // pxr.js の初期化が先に済むこともある
  PX.vBegin = function () { if (!PX.vOn) return; lays.under.begin(); lays.fx.begin(); PX.vstats.v = PX.vstats.i = PX.vstats.seg = PX.vstats.arc = 0; };
  PX.vrun = function (layer, fn) { // fn を記録係で描く（そのあいだだけ ctx を差し替える）
    vx.reset(); vx.beginPath(); PX.sync(vx); vx.F = 0.5 / (PX.res() || 1); vx.open(lays[layer]);
    var keep = ctx; ctx = vx; try { fn(); } finally { ctx = keep; vx.close(); }
  };
  PX.vEnd = function () { };
})();
