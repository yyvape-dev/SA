// コードのエフェクト その4（2026-11-01）：敵の攻撃。fx3.js の次に読む。
//   予兆（武器のきらめき・強敵は縮む輪と集まる火の粉）→ 頂点（武器の形に合わせた軌跡：突き＝まっすぐな刃、振り＝弧。斬撃と同じシェーダー）→ 余韻（斧は床を割る）。
//   色は敵＝赤（暗い下地を濃くして、明るい床でも形が残る）。格の差は大きさと量：雑兵は軌跡と火花、強敵・敵将は太く・長く・輪と光を足す。
'use strict';
var VFX_FOE_S = { glow: '235,25,20', main: '255,95,55', core: '255,226,200', spark: '255,160,90', dark: '26,0,2', dk: 0.75, dw: 1.7 }; // 敵の軌跡（赤黒）
// 敵の種類_攻撃の番号 → 軌跡の形（局所の座標。+x＝相手の向き、単位は敵の背の高さ H）
//   thr：突き（根本 x0・長さ L・高さ y・太さ w）／arc：振り（中心 cx,cy・半径 rx,ry・角度 a0→a1・太さ w）。slam＝床を割る（斧）
var FOE_SWING = {
  '1_0': { t: 'thr', x0: 0.05, L: 1.3, y: 0.56, w: 0.16 },  // 槍兵：突き
  '1_1': { t: 'thr', x0: 0.05, L: 1.35, y: 0.6, w: 0.16 },  // 槍兵：踏み込んで突き
  '2_0': { t: 'thr', x0: 0.1, L: 1.05, y: 0.62, w: 0.16 },  // 騎士：剣の突き
  '2_1': { t: 'arc', cx: 0.12, cy: 0.58, rx: 0.9, ry: 0.3, a0: -2.7, a1: 0.55, w: 0.17 }, // 騎士：横なぎ
  '3_0': { t: 'thr', x0: 0.1, L: 0.85, y: 0.52, w: 0.14 },   // 山賊：短剣の突き
  '3_1': { t: 'arc', cx: 0.2, cy: 0.52, rx: 0.62, ry: 0.5, a0: 1.25, a1: -1.45, w: 0.15 }, // 山賊：斬り上げ
  '4_0': { t: 'arc', cx: 0.18, cy: 0.5, rx: 0.78, ry: 0.62, a0: -2.25, a1: 0.95, w: 0.2, slam: 0.85 }, // 斧：振り下ろし
  '4_1': { t: 'arc', cx: 0.15, cy: 0.52, rx: 0.72, ry: 0.6, a0: -2.0, a1: 0.9, w: 0.2, slam: 0.8 }
};
var FOE_SWING_DEF = { t: 'arc', cx: 0.15, cy: 0.55, rx: 0.75, ry: 0.45, a0: -2.2, a1: 0.7, w: 0.16 };
// 細い閃き（星形の代わり）：横に長く・縦に短い、髪の毛ほどの光の筋。先へ細って消える（敵の予兆・突きの先）
function vGlint(x, y, L, rot, col, core, a) {
  if (a <= 0.01 || L < 1) return; var c = Math.cos(rot), s = Math.sin(rot);
  var RAY = [[c, s, 1, 1.4], [-c, -s, 1, 1.4], [-s, c, 0.38, 1], [s, -c, 0.38, 1]];
  for (var i = 0; i < 4; i++) { var r = RAY[i], l = L * r[2], w = r[3];
    ctx.fillStyle = vrgba(col, 0.55 * a); ctx.beginPath(); ctx.moveTo(x - r[1] * w, y + r[0] * w); ctx.lineTo(x + r[0] * l, y + r[1] * l); ctx.lineTo(x + r[1] * w, y - r[0] * w); ctx.closePath(); ctx.fill();
    ctx.fillStyle = vrgba(core, a); ctx.beginPath(); ctx.moveTo(x - r[1] * w * 0.45, y + r[0] * w * 0.45); ctx.lineTo(x + r[0] * l * 0.7, y + r[1] * l * 0.7); ctx.lineTo(x + r[1] * w * 0.45, y - r[0] * w * 0.45); ctx.closePath(); ctx.fill();
  }
}
function foeSwingOf(e) { return FOE_SWING[e.kind + '_' + (e.atk ? e.atk.ci : -1)] || FOE_SWING_DEF; }

// 攻撃の始まり（update.js の startFoeAtk）：予兆と、当たりの少し前から出る軌跡を積む。止められたら（拘束・ひるみ）消える
function fxFoeAtk(e, hitT) {
  var g = foeSwingOf(e), big = e.boss ? 1.45 : e.elite ? 1.2 : 1, lead = g.t === 'thr' ? 0.05 : 0.08, sp = [], n = Math.round((g.t === 'thr' ? 10 : 14) * big);
  for (var i = 0; i < n; i++) sp.push({ u: 0.4 + Math.random() * 0.6, d: 10 + Math.random() * 80, v: 260 + Math.random() * 600, life: 0.16 + Math.random() * 0.26, s: 1.1 + Math.random() * 1.9, y: (Math.random() - 0.5) * 0.25 });
  G.fx.push({ type: 'vfwind', e: e, at: e.atk, t: 0, life: Math.max(0.05, hitT - lead) + 0.02, end: Math.max(0.05, hitT - lead), g: g });
  G.fx.push({ type: 'vfswing', e: e, at: e.atk, g: g, big: big, t: -Math.max(0, hitT - lead), life: g.t === 'thr' ? 0.3 : 0.36, sp: sp, x: e.x, y: e.y, face: e.face, H: eh(e), slamDone: false });
}
// 予兆：武器を引いた手元に赤いきらめきが集まる（雑兵は小さく）。強敵・敵将はこれに加えて fx2.js の vwarn
FX2.vfwind = function (f) {
  var e = f.e; if (!e || e.state !== 'walk' || e.atk !== f.at || f.t > f.end) return;
  var C = VFX_FOE_S, k = Math.min(1, f.t / f.end), a = vEaseIn(Math.max(0, (k - 0.35) / 0.65)); if (a <= 0) return;
  var H = eh(e), g = f.g, big = e.boss ? 1.5 : e.elite ? 1.2 : 1;
  var hx = e.x - e.face * H * 0.12, hy = e.y - H * (g.t === 'thr' ? g.y : 0.78), r = H * 0.09 * big * (0.6 + 0.6 * a);
  vGlow(hx, hy, r * 1.6, C, 0.4 * a);
  vGlint(hx, hy, r * 2.6, -0.12, C.main, C.core, a);
};
// 頂点：武器の軌跡。WebGL（pxfx.js の slashGL）なら侵食・色の帯・流れるすじ、使えないときは Canvas の層
FX2.vfswing = function (f) {
  if (f.t < 0) { var e = f.e; if (!e || e.state !== 'walk' || e.atk !== f.at) { f.t = f.life; return; } f.x = e.x; f.y = e.y; f.face = e.face; f.H = eh(e); return; } // 当たりの前は敵について行く。止められたら出さない
  var g = f.g, H = f.H, C = VFX_FOE_S, ms = f.t * 1000, SW = g.t === 'thr' ? 70 : 95, fade = ms > SW ? Math.max(0, 1 - (ms - SW) / (f.life * 1000 - SW)) : 1, big = f.big;
  if (g.slam && !f.slamDone && ms > SW * 0.8) { f.slamDone = true; foeSlam(f); }
  ctx.save(); ctx.translate(f.x, f.y); ctx.scale(f.face, 1);
  var N, pts = [], nrm = [], wl = [], i, u;
  if (g.t === 'thr') {
    var x0 = g.x0 * H, L = g.L * H * (0.92 + 0.08 * big), y = -g.y * H, W = g.w * H * big; N = 28;
    for (i = 0; i <= N; i++) { u = i / N; pts.push(x0 + L * u, y); nrm.push(0, -1); wl.push(W * Math.pow(Math.sin(Math.PI * Math.min(1, u * 1.06)), 0.6) * (0.35 + 0.65 * u)); }
    var gl = ctx.slashGL && ctx.slashGL({ pts: pts, nrm: nrm, w: wl, inner: 1, ms: ms, sw: SW, life: f.life, pal: C, tex: 'blade' });
    var LY = gl ? [{ c: C.core, lag: 0, w: 0.16, a: 1 }] : [{ c: C.dark, lag: 8, w: 1.15, a: C.dk, dk: 1 }, { c: C.glow, lag: 18, w: 0.95, a: 0.95 }, { c: C.main, lag: 8, w: 0.4, a: 0.95 }, { c: C.core, lag: 0, w: 0.14, a: 1 }];
    ctx.save(); ctx.translate(0, y);
    for (var l = 0; l < LY.length; l++) { // 芯（細い白い刃）。Canvas 版は層をすべて
      var Ly = LY[l], k = vEase((ms - Ly.lag) / SW); if (k <= 0) continue;
      var LL = L * k, tail = vEase((ms - Ly.lag - SW * 0.5) / (SW * 2)), xa = x0 + LL * tail * 0.8, gr = ctx.createLinearGradient(xa, 0, x0 + LL, 0);
      gr.addColorStop(0, vrgba(Ly.c, 0)); gr.addColorStop(0.5, vrgba(Ly.c, Ly.a * 0.5 * fade)); gr.addColorStop(0.92, vrgba(Ly.c, Ly.a * fade)); gr.addColorStop(1, vrgba(Ly.c, Ly.a * 0.7 * fade));
      ctx.globalCompositeOperation = Ly.dk ? 'source-over' : 'lighter'; vSpear(xa, x0 + LL - xa, W * Ly.w * (0.7 + 0.3 * fade), gr);
    }
    ctx.globalCompositeOperation = 'lighter';
    for (i = 0; i < f.sp.length; i++) { // 前へ流れる筋
      var q = f.sp[i], a = (ms - q.d) / 1000; if (a < 0 || a > q.life) continue;
      var px = x0 + L * 0.3 + q.v * 1.6 * a * (1 - a / (q.life * 2)), al = 1 - a / q.life;
      vStreak(px, q.y * H * 0.6, 1, 0, 30 + q.v * 0.08, q.s, i % 3 ? C.spark : C.core, al * fade);
    }
    var tipK = vEase(ms / SW); if (ms < SW + 90) vGlint(x0 + L * tipK, 0, H * 0.22 * big * (1 - Math.max(0, ms - SW) / 90), 0, C.main, C.core, 1 - Math.max(0, ms - SW) / 90); // 先端の細い閃き
    ctx.restore();
  } else {
    var rx = g.rx * H, ry = g.ry * H, a0 = g.a0, a1 = g.a1, Wa = g.w * H * big;
    ctx.translate(g.cx * H, -g.cy * H);
    if (!(ctx.slashGL && ctx.slashGL(vArcLine(rx, ry, a0, a1, Wa * 1.8, ms, SW, f.life, C, big > 1 ? 'smash' : 'ink')))) {
      var hd = vEase((ms - 10) / SW), tl = vEase((ms - 10 - SW * 0.45) / (SW * 1.4));
      ctx.globalCompositeOperation = 'source-over';
      vArcRibbon(rx, ry, a0, a1, Math.min(hd, tl), hd, Wa * C.dw, vArcGrad(rx, ry, a0, a1, Math.min(hd, tl), hd, C.dark, C.dk * fade));
      ctx.globalCompositeOperation = 'lighter';
      var AL = [{ c: C.glow, lag: 30, tail: 0.6, w: 1.5, a: 0.9 }, { c: C.main, lag: 12, tail: 0.45, w: 1.0, a: 0.95 }, { c: C.core, lag: 0, tail: 0.32, w: 0.36, a: 1 }];
      for (var m = 0; m < 3; m++) {
        var A = AL[m], head = vEase((ms - A.lag) / SW); if (head <= 0) continue;
        var tail2 = vEase((ms - A.lag - SW * A.tail) / (SW * 1.4));
        vArcRibbon(rx, ry, a0, a1, Math.min(head, tail2), head, Wa * A.w * (0.85 + 0.15 * fade), vArcGrad(rx, ry, a0, a1, Math.min(head, tail2), head, A.c, A.a * fade));
      }
    }
    ctx.globalCompositeOperation = 'lighter';
    var dir = a1 > a0 ? 1 : -1;
    for (i = 0; i < f.sp.length; i++) { // 刃の先からこぼれる火花（接線の向き）
      var s = f.sp[i], age = (ms - s.d) / 1000; if (age < 0 || age > s.life) continue;
      var th = a0 + (a1 - a0) * s.u, tx = -rx * Math.sin(th) * dir, ty = ry * Math.cos(th) * dir, mm = Math.hypot(tx, ty) || 1, dr = Math.exp(-age * 5);
      var vx = tx / mm * s.v, vy = ty / mm * s.v - 100, x = rx * Math.cos(th) + vx * (1 - dr) / 5, yy = ry * Math.sin(th) + vy * (1 - dr) / 5 + 260 * age * age;
      vStreak(x, yy, vx * dr, vy * dr + 520 * age, Math.min(40, s.v * 0.05) + 4, s.s, i % 3 ? C.spark : C.core, 0.9 * (1 - age / s.life));
    }
  }
  ctx.restore();
};
// 斧の振り下ろし：刃の落ちた所の床を割る（小さな地割れ・砂埃・岩片・むらの輪）。強敵・敵将は大きく
function foeSlam(f) {
  var x = f.x + f.face * f.g.slam * f.H, R = f.H * (f.big > 1 ? 1.9 : 1.35);
  fxGroundSlam(x, f.y + 4, R, VFX_FOE_S, false, true);
  G.shake = Math.max(G.shake, f.big > 1 ? 7 : 3.5);
}
