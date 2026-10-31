// 月夜の回廊：PixiJS（WebGL）の描画の層（2026-10-31 WebGL 移行・段階2の1）。
// 背景とキャラ（絵の数が増えると重い部分）を PixiJS で描く。エフェクトと文字は、上に重ねた今の Canvas 2D（#game）のまま。
// 作り：既存の描画の関数（drawBg・drawHero・drawFoe・drawAlly）はそのまま使い、そのあいだだけ ctx を「記録係」（PXC）に差し替える。
//   記録係は Canvas 2D の命令（save/restore/translate/rotate/scale/globalAlpha/合成/drawImage/fillRect/ellipse など）を、Pixi のスプライトと図形に置き換える。
//   足元の下の演出（拘束の床・気配・溜め・星の夜空）は、半分の解像度の Canvas に描いて、背景とキャラのあいだに1枚の絵として挟む（描いた時だけ送る）。
// WebGL が使えない・初期化に失敗・描画がリセットされたときは、PX.on=false で、今までどおり全部 Canvas 2D で描く。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
var PX = { on: false, ready: false, app: null, stats: { spr: 0, gfx: 0 } };
(function () {
  if (!window.PIXI || /[?&]px=0/.test(location.search)) return; // ?px=0 で従来の Canvas 2D だけ
  var P = window.PIXI, game = document.getElementById('game'), cvs = document.createElement('canvas');
  cvs.id = 'pxgame'; cvs.setAttribute('aria-hidden', 'true');
  cvs.style.cssText = 'position:absolute;left:0;top:0;width:100%;height:100%;display:block;object-fit:contain;pointer-events:none';
  game.parentNode.insertBefore(cvs, game); game.style.position = 'relative'; game.style.zIndex = '1';

  // ---- 記録係：Canvas 2D の命令 → Pixi ----
  var TEX = new Map(), GRAD = new Map(), CTEX = new Map();
  function baseTex(im) { // 画像・Canvas → 元のテクスチャ（1回だけ作る）
    var t = TEX.get(im); if (t) return t;
    if (im instanceof HTMLImageElement && !(im.complete && im.naturalWidth)) return null; // 読み込みの途中は描かない（途中の絵を送ると、空のまま残る）
    t = { tex: im instanceof HTMLCanvasElement ? canvasTex(im) : new P.Texture({ source: new P.ImageSource({ resource: im }) }), frames: new Map() }; TEX.set(im, t); return t;
  }
  function subTex(im, sx, sy, sw, sh) {
    var b = baseTex(im); if (!b) return null; var iw = im.naturalWidth || im.width, ih = im.naturalHeight || im.height;
    sx = Math.max(0, sx); sy = Math.max(0, sy); sw = Math.min(sw, iw - sx); sh = Math.min(sh, ih - sy);
    if (!(sw > 0 && sh > 0)) return null;
    if (sx === 0 && sy === 0 && sw === iw && sh === ih) return b.tex;
    var k = sx + ',' + sy + ',' + sw + ',' + sh, f = b.frames.get(k);
    if (!f) { f = new P.Texture({ source: b.tex.source, frame: new P.Rectangle(sx, sy, sw, sh) }); b.frames.set(k, f); }
    return f;
  }
  var COL = new Map();
  function col(s) { // 'rgba(0,0,0,.38)' や '#16171f' → [数値, アルファ]
    var c = COL.get(s); if (c) return c;
    try { var o = new P.Color(s); c = [o.toNumber(), o.alpha]; } catch (e) { c = [0, 1]; }
    COL.set(s, c); return c;
  }
  function gradTex(g, rx, ry, rw, rh) { // 線形グラデーションを、塗る四角の大きさの細い Canvas に焼く（同じものは使い回す）
    var vert = Math.abs(g.x1 - g.x0) < 1e-6, n = 128, k = (vert ? [g.y0 - ry, g.y1 - ry, rh] : [g.x0 - rx, g.x1 - rx, rw]).map(function (v) { return Math.round(v * 10) / 10; }).join(',') + '|' + g.stops.join(';') + (vert ? 'v' : 'h');
    var t = GRAD.get(k); if (t) return t;
    var c = document.createElement('canvas'); c.width = vert ? 1 : n; c.height = vert ? n : 1;
    var x = c.getContext('2d'), L = vert ? rh : rw, a = (vert ? g.y0 - ry : g.x0 - rx) / L * n, b = (vert ? g.y1 - ry : g.x1 - rx) / L * n;
    var gg = vert ? x.createLinearGradient(0, a, 0, b) : x.createLinearGradient(a, 0, b, 0);
    for (var i = 0; i < g.stops.length; i++) gg.addColorStop(g.stops[i][0], g.stops[i][1]);
    x.fillStyle = gg; x.fillRect(0, 0, c.width, c.height);
    t = canvasTex(c); GRAD.set(k, t); return t;
  }
  function canvasTex(c) { return new P.Texture({ source: new P.CanvasSource({ resource: c }) }); }
  function Grad(x0, y0, x1, y1) { this.x0 = x0; this.y0 = y0; this.x1 = x1; this.y1 = y1; this.stops = []; }
  Grad.prototype.addColorStop = function (o, c) { this.stops.push([o, c]); };

  function Layer() { this.c = new P.Container(); this.sp = []; this.gs = []; this.ns = 0; this.ng = 0; }
  Layer.prototype.begin = function () { this.c.removeChildren(); this.ns = 0; this.ng = 0; };
  Layer.prototype.sprite = function () { var s = this.sp[this.ns]; if (!s) { s = new P.Sprite(); this.sp.push(s); } this.ns++; this.c.addChild(s); return s; };
  Layer.prototype.gfx = function () { var g = this.gs[this.ng]; if (!g) { g = new P.Graphics(); this.gs.push(g); } this.ng++; g.clear(); this.c.addChild(g); return g; };

  var MAT = new P.Matrix();
  function PXC() { this.m = [1, 0, 0, 1, 0, 0]; this.st = []; this.globalAlpha = 1; this.globalCompositeOperation = 'source-over'; this.fillStyle = '#000'; this.strokeStyle = '#000'; this.lineWidth = 1; this.path = []; this.L = null; }
  var C = PXC.prototype;
  C.save = function () { this.st.push([this.m.slice(), this.globalAlpha, this.globalCompositeOperation, this.fillStyle, this.strokeStyle, this.lineWidth]); };
  C.restore = function () { var s = this.st.pop(); if (!s) return; this.m = s[0]; this.globalAlpha = s[1]; this.globalCompositeOperation = s[2]; this.fillStyle = s[3]; this.strokeStyle = s[4]; this.lineWidth = s[5]; };
  C.setTransform = function (a, b, c, d, e, f) { this.m = [a, b, c, d, e, f]; };
  C.transform = function (a, b, c, d, e, f) { var m = this.m; this.m = [m[0] * a + m[2] * b, m[1] * a + m[3] * b, m[0] * c + m[2] * d, m[1] * c + m[3] * d, m[0] * e + m[2] * f + m[4], m[1] * e + m[3] * f + m[5]]; };
  C.translate = function (x, y) { var m = this.m; m[4] += m[0] * x + m[2] * y; m[5] += m[1] * x + m[3] * y; };
  C.scale = function (x, y) { var m = this.m; m[0] *= x; m[1] *= x; m[2] *= y; m[3] *= y; };
  C.rotate = function (r) { var c = Math.cos(r), s = Math.sin(r); this.transform(c, s, -s, c, 0, 0); };
  C.blend = function () { return this.globalCompositeOperation === 'lighter' ? 'add' : 'normal'; };
  C.put = function (o) { var m = this.m; MAT.set(m[0], m[1], m[2], m[3], m[4], m[5]); o.setFromMatrix(MAT); o.blendMode = this.blend(); };
  C.drawImage = function (im, a, b, c, d, e, f, g, h) {
    if (!im) return; var iw = im.naturalWidth || im.width, ih = im.naturalHeight || im.height; if (!iw || !ih) return;
    var sx = 0, sy = 0, sw = iw, sh = ih, dx, dy, dw, dh;
    if (arguments.length >= 9) { sx = a; sy = b; sw = c; sh = d; dx = e; dy = f; dw = g; dh = h; }
    else if (arguments.length >= 5) { dx = a; dy = b; dw = c; dh = d; } else { dx = a; dy = b; dw = iw; dh = ih; }
    var t = subTex(im, sx, sy, sw, sh); if (!t) return;
    var s = this.L.sprite(); s.texture = t; s.alpha = this.globalAlpha; s.tint = 0xffffff;
    this.save(); this.translate(dx, dy); this.scale(dw / sw, dh / sh); this.put(s); this.restore(); PX.stats.spr++;
  };
  C.fillRect = function (x, y, w, h) {
    var f = this.fillStyle;
    if (f instanceof Grad) { var t = gradTex(f, x, y, w, h), s = this.L.sprite(); s.texture = t; s.alpha = this.globalAlpha; s.tint = 0xffffff; this.save(); this.translate(x, y); this.scale(w / t.width, h / t.height); this.put(s); this.restore(); return; }
    var c = col(f), g = this.L.gfx(); g.rect(x, y, w, h).fill({ color: c[0], alpha: c[1] }); g.alpha = this.globalAlpha; this.put(g); PX.stats.gfx++;
  };
  C.clearRect = function () { };
  C.createLinearGradient = function (x0, y0, x1, y1) { return new Grad(x0, y0, x1, y1); };
  C.beginPath = function () { this.path = []; };
  C.ellipse = function (x, y, rx, ry, rot, a0, a1) { this.path.push(['e', x, y, Math.abs(rx), Math.abs(ry), rot || 0]); };
  C.arc = function (x, y, r) { this.path.push(['e', x, y, Math.abs(r), Math.abs(r), 0]); };
  C.rect = function (x, y, w, h) { this.path.push(['r', x, y, w, h]); };
  C.moveTo = C.lineTo = C.closePath = C.quadraticCurveTo = C.clip = C.setLineDash = function () { }; // 使わない（キャラと背景の描画には出てこない）
  C.shape = function (g) { for (var i = 0; i < this.path.length; i++) { var p = this.path[i]; if (p[0] === 'e') { if (p[5]) g.ellipse(p[1], p[2], p[3], p[4]); else g.ellipse(p[1], p[2], p[3], p[4]); } else g.rect(p[1], p[2], p[3], p[4]); } };
  C.fill = function () { if (!this.path.length || this.fillStyle instanceof Grad) return; var c = col(this.fillStyle), g = this.L.gfx(); this.shape(g); g.fill({ color: c[0], alpha: c[1] }); g.alpha = this.globalAlpha; this.put(g); PX.stats.gfx++; };
  C.stroke = function () { if (!this.path.length) return; var c = col(this.strokeStyle), g = this.L.gfx(); this.shape(g); g.stroke({ width: this.lineWidth, color: c[0], alpha: c[1] }); g.alpha = this.globalAlpha; this.put(g); PX.stats.gfx++; };
  C.measureText = function () { return { width: 0 }; }; C.fillText = C.strokeText = function () { };

  var px = new PXC(), app = new P.Application(), world = new P.Container(), bgL = new Layer(), chL = new Layer(), uSpr = null, uCv = document.createElement('canvas'), uCtx = uCv.getContext('2d'), uDrew = false, uHad = false, uTex = null;
  ['fill', 'stroke', 'fillRect', 'drawImage', 'fillText'].forEach(function (k) { var f = uCtx[k]; uCtx[k] = function () { uDrew = true; return f.apply(uCtx, arguments); }; }); // 足元の下の層：描いたかどうかを覚える
  var U_RES = 0.5;
  PX.px = px; PX.later = []; // キャラの上に描く小物（拘束の帯）。キャラの層のあとに Canvas 2D で描く

  app.init({ canvas: cvs, width: 760, height: 955, backgroundColor: 0x16171f, antialias: false, autoDensity: false, resolution: 1, preference: 'webgl', autoStart: false, sharedTicker: false }).then(function () {
    app.ticker && app.ticker.stop();
    world.addChild(bgL.c); uTex = canvasTex(uCv); uSpr = new P.Sprite(uTex); world.addChild(uSpr); world.addChild(chL.c);
    app.stage.addChild(world);
    var gl = app.renderer.gl; if (gl && gl.canvas) gl.canvas.addEventListener('webglcontextlost', function (e) { PX.on = false; cvs.style.display = 'none'; });
    PX.app = app; PX.ready = true; PX.on = true;
  }).catch(function (e) { cvs.remove(); PX.on = false; PX.err = String(e && e.message || e); });

  var real = null, RW0 = 0, RH0 = 0, RR0 = 0;
  PX.begin = function (realCtx, w, h, res) { // フレームの始め：大きさを合わせ、層を空にする
    real = realCtx; PX.stats.spr = PX.stats.gfx = 0;
    if (w !== RW0 || h !== RH0 || res !== RR0) { RW0 = w; RH0 = h; RR0 = res; app.renderer.resize(w, h, res); uCv.width = Math.round(w * res * U_RES); uCv.height = Math.round(h * res * U_RES); var old = uTex; uTex = canvasTex(uCv); uSpr.texture = uTex; old.destroy(true); uHad = true; }
    bgL.begin(); chL.begin(); uDrew = false;
    if (uHad) { uCtx.setTransform(1, 0, 0, 1, 0, 0); uCtx.clearRect(0, 0, uCv.width, uCv.height); }
  };
  function sync(c, k) { var m = real.getTransform(); c.setTransform(m.a * k, m.b * k, m.c * k, m.d * k, m.e * k, m.f * k); }
  PX.run = function (layer, fn) { // fn を Pixi の層に描く（そのあいだだけ ctx を記録係に）
    var L = layer === 'bg' ? bgL : chL; px.L = L; px.st.length = 0; px.globalAlpha = 1; px.globalCompositeOperation = 'source-over'; sync(px, 1 / RR0);
    var keep = ctx; ctx = px; try { fn(); } finally { ctx = keep; }
  };
  PX.under = function (fn) { // fn を足元の下の層（半分の解像度の Canvas）に描く
    sync(uCtx, U_RES); uCtx.globalAlpha = 1; uCtx.globalCompositeOperation = 'source-over';
    var keep = ctx; ctx = uCtx; try { fn(); } finally { ctx = keep; }
  };
  PX.end = function () { // フレームの終わり：足元の下の層を送って、描く
    uSpr.visible = uDrew; if (uDrew) { uTex.source.update(); uSpr.width = RW0; uSpr.height = RH0; uHad = true; } else uHad = false;
    app.renderer.render(app.stage);
  };
})();
