// コードのエフェクト その2（画像なし）。被弾・撃破・物資・敵将・仲間の技・地を走る衝撃波。fx.js の次に読む。
// 作りの約束はスキル code-vfx-canvas（形・時間差の層・加算の光・暗い下地・向き・対象に合わせた大きさ）。
// G.fx に {type,t,life,…} を積み、draw.js の drawFx が FX2[type] を呼ぶ。粒子は t から位置を計算する（状態を持たない）。
'use strict';
var VFX_FOE = { glow: '255,40,25', main: '255,110,70', core: '255,236,215', spark: '255,170,110', dark: '40,0,0' };   // 敵の攻撃（赤）
var VFX_GOLD = { glow: '255,160,30', main: '255,210,110', core: '255,250,228', spark: '255,226,150', dark: '40,22,0' }; // 物資・決着（金）
var VFX_HEAL = { glow: '70,210,130', main: '170,250,180', core: '250,255,236', spark: '226,255,190', dark: '0,30,12' };  // セラ（緑）
var VFX_STAR = { glow: '80,150,255', main: '170,215,255', core: '255,255,255', spark: '255,233,168', dark: '4,10,40', dk: 0.5 };  // ランカ（青白・金）
var FX2 = {};
function vR(a, b) { return a + Math.random() * (b - a); }
function vStreak(x, y, vx, vy, len, w, col, a) { // 速度の向きへ引き延ばした光の筋（先が明るい）
  var m = Math.hypot(vx, vy) || 1, ex = x - vx / m * len, ey = y - vy / m * len, g = ctx.createLinearGradient(x, y, ex, ey);
  g.addColorStop(0, vrgba(col, a)); g.addColorStop(1, vrgba(col, 0));
  ctx.strokeStyle = g; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, ey); ctx.stroke();
}
function vGlow(x, y, r, C, a) { // 一瞬の丸い光
  if (a <= 0 || r <= 0) return;
  var g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, vrgba(C.core, 0.7 * a)); g.addColorStop(0.3, vrgba(C.main, 0.3 * a)); g.addColorStop(1, vrgba(C.glow, 0));
  ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
}
function vStar4(x, y, r, rot, col, a) { // 4方向に伸びるきらめき
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = vrgba(col, a);
  ctx.beginPath(); for (var i = 0; i < 4; i++) { var th = i * 1.5708; ctx.lineTo(Math.cos(th) * r, Math.sin(th) * r); ctx.lineTo(Math.cos(th + 0.785) * r * 0.16, Math.sin(th + 0.785) * r * 0.16); } ctx.closePath(); ctx.fill(); ctx.restore();
}
function vPillar(x, y, w, H, C, a) { // 光の柱：中心が明るく、横と上へ柔らかく消える
  if (a <= 0 || H <= 1) return;
  ctx.save(); ctx.translate(x, y - H / 2); ctx.scale(1, H / 2 / w);
  var g = ctx.createRadialGradient(0, w * 0.6, 0, 0, 0, w); g.addColorStop(0, vrgba(C.core, 0.45 * a)); g.addColorStop(0.35, vrgba(C.main, 0.3 * a)); g.addColorStop(1, vrgba(C.glow, 0));
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, w, 0, 6.283); ctx.fill(); ctx.restore();
}
function vPuff(x, y, r, rgb, a) { // 煙のひとかたまり（縁の柔らかい丸。光らない）
  if (a <= 0) return; var g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, 'rgba(' + rgb + ',' + a + ')'); g.addColorStop(0.55, 'rgba(' + rgb + ',' + a * 0.6 + ')'); g.addColorStop(1, 'rgba(' + rgb + ',0)');
  ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
}
// 粒子の動き（t から）：初速・抵抗・重力
function vBall(q, t, drag, grav) { var dr = Math.exp(-t * drag); return { x: q.vx * (1 - dr) / drag, y: q.vy * (1 - dr) / drag + grav * t * t * 0.5, vx: q.vx * dr, vy: q.vy * dr + grav * t }; }
function vSparks(n, dir, sp0, sp1, up) { var a = []; for (var i = 0; i < n; i++) { var th = (Math.random() - 0.5) * 1.8 - (up || 0.3); a.push({ vx: (dir || (Math.random() < 0.5 ? 1 : -1)) * Math.cos(th) * vR(sp0, sp1), vy: Math.sin(th) * vR(sp0, sp1), life: vR(0.18, 0.45), s: vR(1.4, 3.2) }); } return a; }
function drawSparks(f, x, y, C, drag, grav) {
  for (var i = 0; i < f.sp.length; i++) {
    var q = f.sp[i], t = f.t - (q.d || 0); if (t < 0 || t > q.life) continue;
    var b = vBall(q, t, drag, grav), al = 1 - t / q.life, vm = Math.hypot(b.vx, b.vy);
    vStreak(x + b.x, y + b.y, b.vx, b.vy, Math.min(42, vm * 0.045) + 3, q.s * (0.5 + 0.5 * al), i % 3 ? C.spark : C.core, al);
  }
}

/* ===== 被弾（ラナ）：赤い切り口＋火花＋画面の端の赤 ===== */
function fxHurt(h, e) {
  var dir = h.x >= e.x ? 1 : -1, ds = depthScale(h.y);
  G.fx.push({ type: 'vhurt', x: h.x - dir * 10, y: h.y - 205 * ds * 0.58, s: 205 * ds, dir: dir, t: 0, life: 0.42, rot: -0.7 + Math.random() * 0.3, sp: vSparks(12, dir, 260, 760, 0.4) });
  G.hurtAt = G.t;
}
FX2.vhurt = function (f) {
  var C = VFX_FOE, t = f.t, x = f.x, y = f.y, L = f.s * 0.62;
  ctx.save(); ctx.translate(x, y); ctx.rotate(f.rot * f.dir); ctx.scale(f.dir, 1);
  var k = vEase(t / 0.06), fd = 1 - Math.max(0, t - 0.06) / 0.18; // 切り口：一瞬で伸びて細る（暗い下地→赤→芯）
  if (fd > 0) {
    var w = f.s * 0.05 * fd, l = L * k;
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.55 * fd);
    ctx.beginPath(); ctx.moveTo(-l * 0.55, 0); ctx.lineTo(0, -w * 3); ctx.lineTo(l * 0.55, 0); ctx.lineTo(0, w * 3); ctx.closePath(); ctx.fill();
    ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = vrgba(C.glow, 0.85 * fd);
    ctx.beginPath(); ctx.moveTo(-l * 0.5, 0); ctx.lineTo(0, -w * 2); ctx.lineTo(l * 0.5, 0); ctx.lineTo(0, w * 2); ctx.closePath(); ctx.fill();
    ctx.fillStyle = vrgba(C.core, fd); ctx.beginPath(); ctx.moveTo(-l * 0.5, 0); ctx.lineTo(0, -w * 0.6); ctx.lineTo(l * 0.5, 0); ctx.lineTo(0, w * 0.6); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
  if (t < 0.12) vGlow(x, y, f.s * (0.35 + t * 2), C, 1 - t / 0.12);
  drawSparks(f, x, y, C, 6, 900);
};
// 画面の端の赤（画面座標）：被弾の直後と、HPが3割を切ったときの脈
function drawScreenFx() {
  if (G.state === 'title') return;
  var h = G.hero, a = 0;
  if (G.hurtAt != null) a = Math.max(0, 1 - (G.t - G.hurtAt) / 0.5) * 0.55;
  var low = h.max ? h.hp / h.max : 1;
  if (low < 0.3 && G.state === 'play') a = Math.max(a, (0.18 + 0.14 * Math.sin(G.t * 6)) * (1 - low / 0.3 * 0.5));
  if (a <= 0.01) return;
  var cx = W / 2, cy = CVH() / 2, r0 = Math.min(W, CVH()) * 0.3, r1 = Math.hypot(W, CVH()) * 0.6;
  var g = ctx.createRadialGradient(cx, cy, r0, cx, cy, r1); g.addColorStop(0, 'rgba(120,0,0,0)'); g.addColorStop(1, 'rgba(150,0,8,' + a + ')');
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, CVH());
}

/* ===== 撃破：黒煙（光らない）＋赤い火の粉＋一瞬の光。群れでは上限を設ける ===== */
function fxKill(e, dir) {
  if (G.vkT !== G.t) { G.vkT = G.t; G.vkN = 0; }
  var full = ++G.vkN <= 6, n = full ? (e.elite ? 12 : 7) : 3, pf = [];
  for (var i = 0; i < n; i++) pf.push({ vx: dir * vR(40, 200) + vR(-60, 60), vy: -vR(30, 160), r: vR(8, 16) * (e.elite ? 1.4 : 1), life: vR(0.45, 0.8), d: vR(0, 0.06) });
  G.fx.push({ type: 'vkill', x: e.x, y: e.y - eh(e) * 0.5, h: eh(e), dir: dir, elite: e.elite, full: full, t: 0, life: 0.85, pf: pf, sp: vSparks(full ? (e.elite ? 16 : 9) : 3, dir, 220, 620, 0.6) });
}
FX2.vkill = function (f) {
  var t = f.t, C = f.elite ? VFX_GOLD : VFX_FOE;
  ctx.globalCompositeOperation = 'source-over';
  for (var i = 0; i < f.pf.length; i++) { // 黒煙：ふくらみながら上へ、ゆっくり消える
    var q = f.pf[i], a = t - q.d; if (a < 0 || a > q.life) continue;
    var b = vBall(q, a, 3, -80), k = a / q.life, r = q.r * (1 + k * 1.6);
    vPuff(f.x + b.x, f.y + b.y, r * 1.3, i % 2 ? '34,22,26' : '58,40,40', 0.4 * (1 - k) * (k < 0.1 ? k / 0.1 : 1));
  }
  ctx.globalCompositeOperation = 'lighter';
  if (f.full && t < 0.1) vGlow(f.x, f.y, f.h * (0.3 + t * 3), C, (1 - t / 0.1) * (f.elite ? 1 : 0.7));
  if (f.full && t < 0.22) { // 床の小さな輪
    var kr = vEase(t / 0.22), rr = f.h * 0.35 * (0.4 + kr);
    ctx.strokeStyle = vrgba(C.main, 0.6 * (1 - kr)); ctx.lineWidth = 3 * (1 - kr) + 1; ctx.beginPath(); ctx.ellipse(f.x, f.y + f.h * 0.5, rr, rr * 0.28, 0, 0, 6.283); ctx.stroke();
  }
  drawSparks(f, f.x, f.y, C, 4, 700);
};

/* ===== 物資：地面で光の柱ときらめき、吸い寄せの尾、取ったときの金の輪 ===== */
function drawDrops() {
  var tt = G.t || 0;
  for (var i = 0; i < G.drops.length; i++) {
    var d = G.drops[i], y = d.y - d.z - 10, C = VFX_GOLD, pulse = 0.75 + 0.25 * Math.sin(tt * 7 + i);
    ctx.save();
    if (!d.home) { // 足元の影と光の柱
      ctx.fillStyle = 'rgba(0,0,0,0.3)'; ctx.beginPath(); ctx.ellipse(d.x, d.y + 2, 12, 3.5, 0, 0, 6.283); ctx.fill();
      ctx.globalCompositeOperation = 'lighter';
      vPillar(d.x, d.y, 16, 150, C, 0.8 * pulse);
    } else if (d.px != null) { // 吸い寄せの尾
      ctx.globalCompositeOperation = 'lighter'; vStreak(d.x, y, d.x - d.px, y - d.py, Math.min(70, Math.hypot(d.x - d.px, y - d.py) * 3 + 10), 6, C.main, 0.9);
    }
    d.px = d.x; d.py = y;
    ctx.globalCompositeOperation = 'lighter'; vGlow(d.x, y, 26 * pulse, C, 0.8);
    ctx.globalCompositeOperation = 'source-over'; ctx.translate(d.x, y); // 金の菱形（暗い縁＋面＋光）
    var r = 9; ctx.fillStyle = 'rgba(70,40,0,0.85)'; ctx.beginPath(); ctx.moveTo(0, -r - 2); ctx.lineTo(r * 0.8 + 2, 0); ctx.lineTo(0, r + 2); ctx.lineTo(-r * 0.8 - 2, 0); ctx.closePath(); ctx.fill();
    var gg = ctx.createLinearGradient(-r, -r, r, r); gg.addColorStop(0, '#fff3c0'); gg.addColorStop(0.45, '#f0c060'); gg.addColorStop(1, '#a8701c');
    ctx.fillStyle = gg; ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(r * 0.8, 0); ctx.lineTo(0, r); ctx.lineTo(-r * 0.8, 0); ctx.closePath(); ctx.fill();
    ctx.globalCompositeOperation = 'lighter'; var gl = (tt * 1.3 + i * 0.37) % 1; // ときどき光るきらめき
    if (gl < 0.25) vStar4(-2, -3, 18 * Math.sin(gl / 0.25 * Math.PI), gl * 2, C.core, 0.95);
    ctx.restore();
  }
}
function fxPick(x, y) {
  var sp = []; for (var i = 0; i < 10; i++) sp.push({ vx: vR(-160, 160), vy: -vR(160, 420), life: vR(0.3, 0.55), s: vR(1.5, 3) });
  G.fx.push({ type: 'vpick', x: x, y: y, t: 0, life: 0.55, sp: sp });
}
FX2.vpick = function (f) {
  var C = VFX_GOLD, t = f.t, k = vEase(t / 0.35), r = 30 + 70 * k;
  if (t < 0.35) { ctx.strokeStyle = vrgba(C.main, 0.9 * (1 - k)); ctx.lineWidth = 5 * (1 - k) + 1; ctx.beginPath(); ctx.ellipse(f.x, f.y, r, r * 0.45, 0, 0, 6.283); ctx.stroke(); }
  if (t < 0.12) vGlow(f.x, f.y - 20, 60, C, 1 - t / 0.12);
  drawSparks(f, f.x, f.y - 20, C, 3, 300);
};

/* ===== 敵将 ===== */
// 出現：赤黒の柱が立ち、床の輪が2重に広がる
function fxBossIn(e) {
  var em = []; for (var i = 0; i < 36; i++) em.push({ ox: vR(-90, 90), v: vR(160, 420), d: vR(0, 0.5), life: vR(0.5, 1.0), s: vR(1.5, 3.5) });
  G.fx.push({ type: 'vbossin', e: e, x: e.x, y: e.y, h: eh(e), t: 0, life: 1.4, em: em }); // 敵将は画面の右の外から来るので、位置は毎フレーム敵将に合わせる
  G.flash = 0.3; G.flashRGB = '90,0,0';
}
FX2.vbossin = function (f) {
  if (f.e) { f.x = f.e.x; f.y = f.e.y; }
  var C = VFX_FOE, t = f.t, up = vEase(t / 0.25), fade = t < 0.6 ? 1 : 1 - (t - 0.6) / (f.life - 0.6), H = f.h * 1.6 * up, w = 110 * (1 - 0.4 * Math.min(1, t / f.life));
  ctx.globalCompositeOperation = 'source-over'; // 柱：黒い下地
  if (H > 1) { ctx.save(); ctx.translate(f.x, f.y - H / 2); ctx.scale(1, H / 2 / w); var g0 = ctx.createRadialGradient(0, w * 0.5, 0, 0, 0, w); g0.addColorStop(0, vrgba(C.dark, 0.55 * fade)); g0.addColorStop(1, vrgba(C.dark, 0)); ctx.fillStyle = g0; ctx.beginPath(); ctx.arc(0, 0, w, 0, 6.283); ctx.fill(); ctx.restore(); }
  ctx.globalCompositeOperation = 'lighter';
  vPillar(f.x, f.y, w * 0.55, H, C, fade);
  for (var j = 0; j < 2; j++) { // 床の輪
    var k = vEase((t - j * 0.18) / 0.8); if (k <= 0 || k >= 1) continue; var r = 60 + 460 * k;
    ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.5 * (1 - k)); ctx.lineWidth = 14 * (1 - k) + 2; ctx.beginPath(); ctx.ellipse(f.x, f.y + 3, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
    ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.8 * (1 - k)); ctx.lineWidth = 10 * (1 - k) + 1; ctx.beginPath(); ctx.ellipse(f.x, f.y, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
    ctx.strokeStyle = vrgba(C.core, 0.8 * (1 - k)); ctx.lineWidth = 2; ctx.stroke();
  }
  for (var i = 0; i < f.em.length; i++) { // 火の粉が昇る
    var q = f.em[i], a = t - q.d; if (a < 0 || a > q.life) continue; var al = 1 - a / q.life;
    vStreak(f.x + q.ox + Math.sin(a * 6 + i) * 10, f.y - q.v * a, 0, -q.v, 18, q.s, i % 3 ? C.spark : C.core, al);
  }
};
// 足元の気配（敵将は赤黒の渦と昇る火の粉、強敵は薄い赤の輪）。draw.js が敵より先（床）に呼ぶ
function drawFoeAura() {
  var tt = G.t || 0, C = VFX_FOE;
  ctx.save();
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (!(e.boss || e.elite) || e.state !== 'walk') continue;
    var s = depthScale(e.y) * e.size, rx = (e.boss ? 82 : 58) * s, ry = rx * 0.27;
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, e.boss ? 0.42 : 0.25); ctx.beginPath(); ctx.ellipse(e.x, e.y, rx * 1.15, ry * 1.15, 0, 0, 6.283); ctx.fill();
    ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, e.boss ? 0.5 : 0.3); ctx.lineWidth = e.boss ? 3 : 2; ctx.setLineDash([14 * s, 9 * s]); ctx.lineDashOffset = -tt * 50;
    ctx.beginPath(); ctx.ellipse(e.x, e.y, rx, ry, 0, 0, 6.283); ctx.stroke(); ctx.setLineDash([]);
    if (!e.boss) continue;
    ctx.strokeStyle = vrgba(C.main, 0.35); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.ellipse(e.x, e.y, rx * 0.72, ry * 0.72, 0, 0, 6.283); ctx.stroke();
    var H = eh(e);
    for (var j = 0; j < 14; j++) { // 体のまわりを昇る火の粉（周期で繰り返す。t から位置を計算）
      var ph = (tt * (0.55 + (j % 5) * 0.08) + j * 0.137) % 1, ox = Math.sin(j * 2.3) * rx * 0.9 + Math.sin(tt * 3 + j) * 6, yy = e.y - ph * H * 1.1;
      vStreak(e.x + ox, yy, 0, -1, 10 + ph * 10, 2.2, j % 3 ? C.spark : C.main, Math.sin(ph * Math.PI) * 0.75);
    }
  }
  ctx.restore();
}
// 攻撃の予兆（敵将・強敵）：武器の高さのきらめき＋足元から縮む赤い輪。当たりの瞬間に輪が閉じる
function fxWarn(e, hitT) {
  if (!(e.boss || e.elite)) return;
  G.fx.push({ type: 'vwarn', e: e, at: e.atk, t: 0, life: Math.max(0.12, hitT) + 0.08, hitT: Math.max(0.12, hitT) });
}
FX2.vwarn = function (f) {
  var e = f.e; if (!e || e.state !== 'walk' || e.atk !== f.at) return; // 止められたら消す
  var C = VFX_FOE, k = Math.min(1, f.t / f.hitT), s = depthScale(e.y) * e.size, H = eh(e), big = e.boss ? 1.3 : 1;
  var r = (150 - 90 * vEaseIn(k)) * s * big, x = e.x + e.face * 70 * s;
  ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.35); ctx.lineWidth = 7; ctx.beginPath(); ctx.ellipse(x, e.y + 2, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
  ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.35 + 0.6 * k); ctx.lineWidth = 3 + 3 * k; ctx.beginPath(); ctx.ellipse(x, e.y, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
  var gx = e.x + e.face * 40 * s, gy = e.y - H * 0.78, gr = (10 + 14 * k) * s * big;
  vGlow(gx, gy, gr * 2.2, C, 0.4 + 0.5 * k); vStar4(gx, gy, gr * 1.5, 0.785, C.spark, 0.5 + 0.5 * k); vStar4(gx, gy, gr * 0.7, 0.785, C.core, 0.6 + 0.4 * k);
};
// 撃破：放射の光線＋金の輪＋黒煙の柱＋火の粉
function fxBossDown(e) {
  var rays = []; for (var i = 0; i < 14; i++) rays.push({ a: i / 14 * 6.283 + vR(-0.12, 0.12), L: vR(0.7, 1.2), w: vR(0.6, 1.2) });
  var pf = []; for (i = 0; i < 16; i++) pf.push({ vx: vR(-120, 120), vy: -vR(80, 260), r: vR(18, 34), life: vR(0.8, 1.3), d: vR(0, 0.25) });
  G.fx.push({ type: 'vbossdown', x: e.x, y: e.y - eh(e) * 0.5, gy: e.y, h: eh(e), t: 0, life: 1.4, rays: rays, pf: pf, sp: vSparks(40, 0, 300, 900, 0.8) });
  fxRing(e.x, e.y, 620, 0.8, VFX_GOLD);
  G.flash = 0.22; G.flashRGB = '255,215,160';
}
FX2.vbossdown = function (f) {
  var t = f.t, C = VFX_GOLD, i;
  ctx.globalCompositeOperation = 'source-over';
  for (i = 0; i < f.pf.length; i++) { var q = f.pf[i], a = t - q.d; if (a < 0 || a > q.life) continue; var b = vBall(q, a, 2, -60), k = a / q.life; vPuff(f.x + b.x, f.y + b.y, q.r * (1.3 + k * 1.8), '30,20,22', 0.4 * (1 - k)); }
  ctx.globalCompositeOperation = 'lighter';
  var rk = vEase(t / 0.35), rf = t < 0.35 ? 1 : Math.max(0, 1 - (t - 0.35) / 0.6);
  for (i = 0; i < f.rays.length; i++) { // 放射の光線（太さの変わる楔）
    var ry = f.rays[i], L = f.h * 1.5 * ry.L * rk, w = 9 * ry.w * rf, th = ry.a + t * 0.25, cs = Math.cos(th), sn = Math.sin(th);
    var g = ctx.createLinearGradient(f.x, f.y, f.x + cs * L, f.y + sn * L); g.addColorStop(0, vrgba(C.main, 0.6 * rf)); g.addColorStop(0.4, vrgba(C.glow, 0.35 * rf)); g.addColorStop(1, vrgba(C.glow, 0));
    ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(f.x - sn * w, f.y + cs * w); ctx.lineTo(f.x + cs * L, f.y + sn * L); ctx.lineTo(f.x + sn * w, f.y - cs * w); ctx.closePath(); ctx.fill();
  }
  if (t < 0.3) vGlow(f.x, f.y, f.h * (0.5 + t * 2), C, 0.8 * (1 - t / 0.3));
  drawSparks(f, f.x, f.y, C, 2.5, 600);
};

/* ===== 地を走る衝撃波（ラナ、赤黒・金）：立ち上がる三日月の刃が床を進み、跡に裂け目と土ぼこり ===== */
FX2.vshock = function (f) {
  var C = f.pal || VFX_RANA, p = f.t / f.life, k = vEase(p), sx = f.x + f.dir * (60 + 760 * k), fade = p < 0.6 ? 1 : 1 - (p - 0.6) / 0.4, H = 150 * (1 - 0.45 * k), y = f.y;
  // 跡の裂け目（暗い下地→紅→金）
  var g0 = ctx.createLinearGradient(f.x, 0, sx, 0); g0.addColorStop(0, vrgba(C.dark, 0)); g0.addColorStop(1, vrgba(C.dark, 0.6 * fade));
  ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = g0; ctx.lineWidth = 9; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(f.x + f.dir * 40, y); ctx.lineTo(sx, y); ctx.stroke();
  ctx.globalCompositeOperation = 'lighter';
  var g1 = ctx.createLinearGradient(f.x, 0, sx, 0); g1.addColorStop(0, vrgba(C.glow, 0)); g1.addColorStop(1, vrgba(C.main, 0.9 * fade));
  ctx.strokeStyle = g1; ctx.lineWidth = 3.5; ctx.beginPath(); ctx.moveTo(f.x + f.dir * 40, y); ctx.lineTo(sx, y); ctx.stroke();
  // 刃：床から立ち上がる三日月（前へふくらむ）
  ctx.save(); ctx.translate(sx, y); ctx.scale(f.dir, 1);
  var LY = [{ c: C.dark, w: 1.25, a: C.dk, dk: 1, o: -8 }, { c: C.glow, w: 1.1, a: 0.85, o: -4 }, { c: C.main, w: 0.55, a: 1, o: 0 }, { c: C.core, w: 0.2, a: 1, o: 2 }];
  for (var l = 0; l < LY.length; l++) {
    var L = LY[l], W2 = 34 * L.w * fade;
    ctx.globalCompositeOperation = L.dk ? 'source-over' : 'lighter'; ctx.fillStyle = vrgba(L.c, L.a * fade);
    ctx.beginPath(); ctx.moveTo(L.o - 40, 0); ctx.quadraticCurveTo(L.o + W2 + 26, -H * 0.45, L.o - 6, -H); ctx.quadraticCurveTo(L.o + 8, -H * 0.45, L.o - 40 + W2 * 0.3, 0); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
  ctx.globalCompositeOperation = 'source-over'; // 前の土ぼこり
  for (var i = 0; i < 4; i++) { var ph = (f.t * 5 + i * 0.25) % 1; ctx.fillStyle = 'rgba(120,96,70,' + (0.35 * (1 - ph) * fade) + ')'; ctx.beginPath(); ctx.arc(sx - f.dir * ph * 70, y - ph * 40 - 6, 8 + ph * 14, 0, 6.283); ctx.fill(); }
  ctx.globalCompositeOperation = 'lighter';
};
// 必殺の溜め：赤黒・金の輪が足元へ縮む
FX2.vsuck = function (f) {
  var C = VFX_RANA, p = f.t / f.life;
  for (var r = 0; r < 2; r++) {
    var q = vEaseIn(Math.min(1, p * 1.2 + r * 0.25)); if (q >= 1) continue; var rx = 260 * (1 - q) + 20, al = (0.3 + 0.7 * q) * (1 - p * 0.5);
    ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.5 * al); ctx.lineWidth = 8; ctx.beginPath(); ctx.ellipse(f.x, f.y + 2, rx, rx * 0.28, 0, 0, 6.283); ctx.stroke();
    ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.7 * al); ctx.lineWidth = 6 * q + 2; ctx.beginPath(); ctx.ellipse(f.x, f.y, rx, rx * 0.28, 0, 0, 6.283); ctx.stroke();
    ctx.strokeStyle = vrgba(C.core, al); ctx.lineWidth = 1.5; ctx.stroke();
  }
};

/* ===== 仲間の技 ===== */
// セラ：癒しの頁。緑金の光の柱＋広がる輪＋昇る十字のきらめき
function fxHeal(h) {
  var q = []; for (var i = 0; i < 26; i++) q.push({ ox: vR(-110, 110), v: vR(120, 300), d: vR(0, 0.4), life: vR(0.5, 0.9), s: vR(6, 13), r: vR(0, 3) });
  G.fx.push({ type: 'vheal', x: h.x, y: h.y, t: 0, life: 1.1, q: q });
}
FX2.vheal = function (f) {
  var C = VFX_HEAL, t = f.t, up = vEase(t / 0.2), fade = t < 0.5 ? 1 : 1 - (t - 0.5) / 0.6, H = 380 * up;
  vPillar(f.x, f.y, 90, H, C, 0.4 * fade);
  for (var j = 0; j < 2; j++) { var k = vEase((t - j * 0.15) / 0.6); if (k <= 0 || k >= 1) continue; var r = 50 + 400 * k; ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.45 * (1 - k)); ctx.lineWidth = 9 * (1 - k) + 2; ctx.beginPath(); ctx.ellipse(f.x, f.y + 3, r, r * 0.28, 0, 0, 6.283); ctx.stroke(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.9 * (1 - k)); ctx.lineWidth = 8 * (1 - k) + 1; ctx.beginPath(); ctx.ellipse(f.x, f.y, r, r * 0.28, 0, 0, 6.283); ctx.stroke(); }
  for (var i = 0; i < f.q.length; i++) { var q = f.q[i], a = t - q.d; if (a < 0 || a > q.life) continue; var al = Math.sin(a / q.life * Math.PI); vStar4(f.x + q.ox + Math.sin(a * 4 + i) * 12, f.y - 30 - q.v * a, q.s, q.r, i % 3 ? C.spark : C.core, al); }
};
// ランカ：星震。敵ごとに上から星の筋が落ち、当たりで光る（先頭10体まで）
function fxStar(e, k) {
  var d = Math.min(0.25, k * 0.025), full = k < 10;
  G.fx.push({ type: 'vstar', x: e.x, y: e.y - eh(e) * 0.55, h: eh(e), d: d, full: full, t: 0, life: d + 0.5, sp: full ? vSparks(8, 0, 200, 600, 1.2) : [] });
}
FX2.vstar = function (f) {
  var C = VFX_STAR, a = f.t - f.d; if (a < 0) return;
  var fall = 0.11, k = Math.min(1, a / fall), sx = f.x + 160 * (1 - k), sy = f.y - 520 * (1 - k);
  if (a < fall + 0.08) { var fd = a < fall ? 1 : 1 - (a - fall) / 0.08; ctx.lineCap = 'round';
    vStreak(sx, sy, -160, 520, 220, 16, C.glow, 0.7 * fd); vStreak(sx, sy, -160, 520, 180, 6, C.main, fd); vStreak(sx, sy, -160, 520, 120, 2.2, C.core, fd); }
  if (a >= fall && f.full) { var b = a - fall; if (b < 0.14) { vGlow(f.x, f.y, f.h * (0.4 + b * 3), C, 1 - b / 0.14); vStar4(f.x, f.y, f.h * 0.6 * (1 - b / 0.14), 0.3, C.core, 1 - b / 0.14); }
    var ff = { t: b, sp: f.sp }; drawSparks(ff, f.x, f.y, C, 5, 800); }
};

/* ===== ランカの星震（2026-10-30 作り直し）：夜空へ暗転 → 星が灯り星座の線で敵を結ぶ → 星が1体ずつ落ちる（当たりごとにダメージ）→ 地面が割れる大きな一撃 → 明転 ===== */
var SF = { dim: 0.3, sky: 0.45, fall: 0.7, quake: 1.25, end: 1.5, dur: 0.1 }; // 踏み抜きの光（約0.5秒）が引いてから星が灯る // 放つ瞬間（寄りから引いたところ）から始まる
function startStarfall(a) {
  var list = G.enemies.filter(function (e) { return e.state === 'walk' && e.x > camX - 40 && e.x < camX + W + 40; }).sort(function (p, q) { return p.x - q.x; });
  var n = list.length, step = n ? Math.min(0.07, 0.5 / n) : 0, top = camY + TOPY + VH * 0.16, stars = [];
  for (var i = 0; i < n; i++) stars.push({ e: list[i], x: clamp(list[i].x + rnd(-50, 50), camX + 30, camX + W - 30), y: top + rnd(0, VH * 0.14), at: SF.fall + i * step, r: rnd(10, 14), hit: false, wk: rnd(0.6, 1.45), lk: rnd(0.7, 1.35), ph: rnd(0, 6.283) }); // wk・lk＝太さと長さの個体差、ph＝明滅のずれ
  G.starfall = { t: 0, a: a, stars: stars, quaked: false, carry: 0.55 }; // carry＝溜めの暗さから続けて暗くする（踏み抜きで一瞬明るく戻らない）
}
function starfallTick(dt) {
  var sf = G.starfall; if (!sf) return;
  sf.t += dt;
  for (var i = 0; i < sf.stars.length; i++) {
    var s = sf.stars[i]; if (s.hit || sf.t < s.at + SF.dur) continue;
    s.hit = true; var e = s.e;
    if (e && e.state === 'walk') { hurt(e, 150 * (0.9 + Math.random() * 0.2) * (e.bind > 0 ? 1.5 : 1), e.x >= sf.a.x ? 1 : -1, true); }
    var tx = e ? e.x : s.x, ty = e ? e.y - eh(e) * 0.55 : s.y;
    G.fx.push({ type: 'vstar', x: tx, y: ty, h: e ? eh(e) : 200, d: -0.11, full: i < 10, t: 0, life: 0.4, sp: i < 10 ? vSparks(8, 0, 200, 600, 1.2) : [] });
    G.shake = Math.max(G.shake, 6);
  }
  if (!sf.quaked && sf.t >= SF.quake) { // 大きな一撃：星の輪＋地を走る裂け目（青白・金）＋揺れ
    sf.quaked = true; var a = sf.a, n = sf.stars.length;
    fxRing(a.x, a.y, W * 0.9, 0.8, VFX_STAR); fxRing(a.x, a.y, W * 0.55, 0.6, VFX_STAR);
    G.fx.push({ type: 'vshock', x: a.x, y: a.y, dir: 1, t: 0, life: 0.6, pal: VFX_STAR }); G.fx.push({ type: 'vshock', x: a.x, y: a.y, dir: -1, t: 0, life: 0.6, pal: VFX_STAR });
    G.flash = 0.3; G.flashRGB = '190,220,255'; G.freeze = Math.max(G.freeze, 0.12); G.shake = Math.max(G.shake, 26);
  }
  if (sf.t >= SF.end) G.starfall = null;
}
function sfDimA(sf) { var t = sf.t, c = sf.carry || 0; return t < SF.dim ? c + (1 - c) * t / SF.dim : t < SF.quake ? 1 : Math.max(0, 1 - (t - SF.quake) / (SF.end - SF.quake)); }
// 夜空の暗転（世界座標。背景の後・人物の前に描く）
function drawStarDim() {
  var sf = G.starfall; if (!sf) return; var k = sfDimA(sf), x0 = camX - 20, y0 = camY + TOPY - 20, w = W + 40, h = CVH() + 40;
  var g = ctx.createLinearGradient(0, y0, 0, y0 + h); g.addColorStop(0, 'rgba(4,8,30,' + 0.78 * k + ')'); g.addColorStop(0.6, 'rgba(8,14,44,' + 0.55 * k + ')'); g.addColorStop(1, 'rgba(10,16,40,' + 0.4 * k + ')');
  ctx.fillStyle = g; ctx.fillRect(x0, y0, w, h);
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; // 遠くの小さな星（またたき。t から）
  for (var i = 0; i < 40; i++) { var px = x0 + ((i * 97.3) % 1) * 0 + (i * 137.5 % w), py = y0 + (i * 61.7 % (h * 0.45)), tw = 0.5 + 0.5 * Math.sin(G.t * 5 + i * 1.7); ctx.fillStyle = 'rgba(220,235,255,' + 0.7 * k * tw + ')'; ctx.fillRect(px, py, 2, 2); }
  ctx.restore();
}
// 星・星座の線・落ちる星（人物の後に描く）
function drawStarfall() {
  var sf = G.starfall; if (!sf) return; var C = VFX_STAR, t = sf.t, k = sfDimA(sf), S = sf.stars, i;
  ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
  var lk = vEase((t - SF.sky) / (SF.fall - SF.sky + 0.05)); // 星座の線：左から順に結ばれる
  for (i = 0; i + 1 < S.length; i++) {
    var seg = Math.max(0, Math.min(1, lk * (S.length - 1) - i)); if (seg <= 0) break;
    var p = S[i], q = S[i + 1], ex = p.x + (q.x - p.x) * seg, ey = p.y + (q.y - p.y) * seg;
    var lf = k * Math.max(0, 1 - Math.max(0, t - p.at) / 0.15); if (lf <= 0) continue; // 星が落ちたら、その線は消える
    ctx.strokeStyle = vrgba(C.glow, 0.45 * lf); ctx.lineWidth = 8; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(ex, ey); ctx.stroke();
    ctx.strokeStyle = vrgba(C.core, 0.9 * lf); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(ex, ey); ctx.stroke();
  }
  for (i = 0; i < S.length; i++) {
    var s = S[i], ap = vEase((t - SF.sky - i * 0.012) / 0.15); if (ap <= 0) continue;
    var e = s.e, tx = e ? e.x : s.x, ty = e ? e.y - eh(e) * 0.55 : s.y + 300;
    if (t < s.at) { // 空で灯る星（照準の細い線を足元へ）
      var tw = 0.8 + 0.2 * Math.sin(G.t * 14 + i);
      vGlow(s.x, s.y, s.r * 3.2 * ap, C, ap * k); vStar4(s.x, s.y, s.r * 2.2 * ap * tw, 0, C.core, ap * k); vStar4(s.x, s.y, s.r * 1.2 * ap, 0.785, C.spark, 0.8 * ap * k);
      if (e && i < 10) { var g = ctx.createLinearGradient(s.x, s.y, tx, ty); g.addColorStop(0, vrgba(C.main, 0.35 * ap * k)); g.addColorStop(1, vrgba(C.main, 0)); ctx.strokeStyle = g; ctx.lineWidth = 1.2; ctx.setLineDash([4, 8]); ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(tx, ty); ctx.stroke(); ctx.setLineDash([]); }
    } else if (!s.hit) { // 落ちる星：3層の筋
      var u = (t - s.at) / SF.dur, f = u * u * u, x = s.x + (tx - s.x) * f, y = s.y + (ty - s.y) * f, vx = tx - s.x, vy = ty - s.y; // 3乗で加速（重力のように、着弾の直前が一番速い）
      var L = Math.min(300, Math.hypot(vx, vy) * (0.2 + 0.6 * f)) * s.lk, sh = (1 - 0.6 * f) * s.wk; // 着弾に近づくほど細く鋭く
      var fl = 0.72 + 0.28 * Math.abs(Math.sin(G.t * 61 + s.ph) * Math.sin(G.t * 37 + s.ph * 2)); // 毎フレームのパチパチした明滅
      vStreak(x, y, vx, vy, L, 18 * sh, C.glow, 0.7 * fl); vStreak(x, y, vx, vy, L * 0.8, 6.5 * sh, C.main, fl); vStreak(x, y, vx, vy, L * 0.55, 2.4 * sh, C.core, 1);
      vStar4(x, y, s.r * 2.4 * (0.8 + 0.4 * fl), G.t * 8, C.core, fl);
    }
  }
  ctx.restore();
}

/* ===== 必殺・連携の寄り（2026-10-30）：打つ人物へ寄って少しスロー → 放つ瞬間に一気に引く =====
   時間は実時間（loop.js が cineTick(dt) を先に呼び、返した倍率で update を遅くする）。HUD と操作盤は寄らない（draw.js で世界座標の前にだけ掛ける） */
var CINE = { z: 1.42, slow: 0.62, inT: 0.26, outT: 0.16, maxIn: 2.6 };
function cineStart(who, h) { G.cine = { who: who, h: h || 200, t: 0, phase: 'in', z: 1, ts: 1 }; }
function cineRelease() { var c = G.cine; if (!c || c.phase !== 'in') return; c.phase = 'out'; c.ot = 0; c.z0 = c.z; c.fx = c.who.x; c.fy = c.who.y - c.h * 0.55; }
function cineTick(rdt) {
  var c = G.cine; if (!c) return 1;
  if (G.state !== 'play' || G.paused) { if (G.state !== 'play') G.cine = null; return 1; }
  if (c.phase === 'in') {
    c.t += rdt; var k = vEase(c.t / CINE.inT); c.z = 1 + (CINE.z - 1) * k; c.ts = 1 - (1 - CINE.slow) * k;
    c.fx = c.who.x; c.fy = c.who.y - c.h * 0.55;
    if (c.t > CINE.maxIn) cineRelease(); // 念のため（放つ前に止められた場合）
  } else {
    c.ot += rdt; var u = c.ot / CINE.outT;
    c.z = c.z0 + (1 - c.z0) * vEase(u); // 一気に引く（1倍より引くと背景の端が見えるので、1倍で止める）
    c.ts = 1;
    if (c.ot >= CINE.outT) { G.cine = null; return 1; }
  }
  return c.ts;
}
function cineApply() {
  var c = G.cine; if (!c || Math.abs(c.z - 1) < 0.002) return;
  var px = clamp(c.fx - camX, W * 0.28, W * 0.72), py = clamp(c.fy - camY - TOPY, VH * 0.3, VH * 0.62); // 寄る点（画面の座標）。端に寄りすぎない
  c.px = px; c.py = py; ctx.translate(px, py); ctx.scale(c.z, c.z); ctx.translate(-px, -py);
}

/* ===== リリィの追星（2026-10-30）：駆け抜けた一直線に、青白の光の帯（暗い下地→光→芯、後ろから消える）＋星の粒＋先端の衝撃 ===== */
function fxDash(x0, x1, y, face) {
  var st = []; for (var i = 0; i < 26; i++) st.push({ u: Math.random(), oy: (Math.random() - 0.5) * 90, d: Math.random() * 0.12, r: vR(5, 11), vy: -vR(30, 140), life: vR(0.35, 0.7) });
  G.fx.push({ type: 'vdash', x0: x0, x1: x1, y: y - 95, gy: y, face: face, t: 0, life: 0.6, st: st, sp: vSparks(14, face, 300, 800, 0.4) });
}
FX2.vdash = function (f) {
  var C = VFX_STAR, t = f.t, head = vEase(t / 0.08), tail = vEase((t - 0.08) / 0.4), xa = f.x0 + (f.x1 - f.x0) * tail, xb = f.x0 + (f.x1 - f.x0) * head, fade = 1 - Math.max(0, t - 0.3) / 0.3;
  if (xb !== xa && fade > 0) {
    var LY = [{ c: C.dark, w: 34, a: 0.45, dk: 1 }, { c: C.glow, w: 30, a: 0.6 }, { c: C.main, w: 11, a: 0.95 }, { c: C.core, w: 3.5, a: 1 }];
    for (var l = 0; l < LY.length; l++) { var L = LY[l], g = ctx.createLinearGradient(xa, 0, xb, 0); g.addColorStop(0, vrgba(L.c, 0)); g.addColorStop(0.85, vrgba(L.c, L.a * fade)); g.addColorStop(1, vrgba(L.c, L.a * 0.6 * fade));
      ctx.globalCompositeOperation = L.dk ? 'source-over' : 'lighter'; ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(xa, f.y); ctx.quadraticCurveTo((xa + xb) / 2, f.y - L.w * 0.5, xb, f.y); ctx.quadraticCurveTo((xa + xb) / 2, f.y + L.w * 0.5, xa, f.y); ctx.fill(); }
    ctx.globalCompositeOperation = 'lighter';
  }
  for (var i = 0; i < f.st.length; i++) { var q = f.st[i], a = t - q.d - q.u * 0.08; if (a < 0 || a > q.life) continue; var al = Math.sin(a / q.life * Math.PI); vStar4(f.x0 + (f.x1 - f.x0) * q.u, f.y + q.oy + q.vy * a, q.r, a * 3, i % 3 ? C.spark : C.core, al); }
  var bt = t - 0.06; if (bt > 0 && bt < 0.14) { vGlow(f.x1 + f.face * 30, f.y, 120 * (0.5 + bt * 4), C, 1 - bt / 0.14); }
  if (t > 0.06) drawSparks({ t: t - 0.06, sp: f.sp }, f.x1 + f.face * 30, f.y, C, 5, 700);
};

/* ===== ランカの星震：溜め（青と金のオーラ）→ 踏み抜き（足から縦に昇る光の柱＋画面いっぱいの流線）（2026-10-30） =====
   スキル code-vfx-canvas の手法：太さの変わる形／時間差の3層（残光・本体・芯）／加算の光＋暗い下地／速度の向きの筋／対象に追従／t から位置／重なりの上限 */
var VFX_SKY = { glow: '60,140,255', main: '140,205,255', core: '255,255,255', spark: '255,226,150', gold: '255,196,70', dark: '4,8,34', dk: 0.5 };
// 曲線（2次ベジェ p0→c→p1）の u0〜u1 を、太さの変わるリボン（根本は細く、先端の手前で太く、先端で尖る）で塗る
function vCurveRibbon(p0x, p0y, cx, cy, p1x, p1y, u0, u1, w, style) {
  if (u1 - u0 < 0.01) return; var N = 22, L = [], R = [];
  for (var i = 0; i <= N; i++) {
    var s = i / N, u = u0 + (u1 - u0) * s, iu = 1 - u, x = iu * iu * p0x + 2 * iu * u * cx + u * u * p1x, y = iu * iu * p0y + 2 * iu * u * cy + u * u * p1y;
    var dx = 2 * iu * (cx - p0x) + 2 * u * (p1x - cx), dy = 2 * iu * (cy - p0y) + 2 * u * (p1y - cy), m = Math.hypot(dx, dy) || 1;
    var ww = w * Math.pow(Math.sin(Math.PI * Math.min(1, s * 1.1)), 0.7) * (0.25 + 0.75 * s);
    L.push(x - dy / m * ww, y + dx / m * ww); R.push(x + dy / m * ww * 0.45, y - dx / m * ww * 0.45);
  }
  ctx.beginPath(); ctx.moveTo(L[0], L[1]); for (i = 2; i < L.length; i += 2) ctx.lineTo(L[i], L[i + 1]); for (i = R.length - 2; i >= 0; i -= 2) ctx.lineTo(R[i], R[i + 1]); ctx.closePath(); ctx.fillStyle = style; ctx.fill();
}
function vCurveGrad(p0x, p0y, cx, cy, p1x, p1y, u0, u1, col, a) {
  var q = function (u) { var iu = 1 - u; return [iu * iu * p0x + 2 * iu * u * cx + u * u * p1x, iu * iu * p0y + 2 * iu * u * cy + u * u * p1y]; }, A = q(u0), B = q(u1);
  var g = ctx.createLinearGradient(A[0], A[1], B[0], B[1]); g.addColorStop(0, vrgba(col, 0)); g.addColorStop(0.6, vrgba(col, a * 0.4)); g.addColorStop(0.92, vrgba(col, a)); g.addColorStop(1, vrgba(col, a * 0.6)); return g;
}
// 溜め：連携を押した瞬間から、踏み抜き（cineRelease）まで続く
function fxStarCharge(a) {
  var sp = []; for (var i = 0; i < 54; i++) sp.push({ a: Math.random() * 6.283, r: vR(200, 420), w: vR(4, 8) * (Math.random() < 0.5 ? 1 : -1), d: Math.random() * 1.2, life: vR(0.45, 0.75), s: vR(1.6, 3.2), gold: i % 3 === 0 });
  var em = []; for (i = 0; i < 26; i++) em.push({ ox: vR(-1, 1), p: Math.random(), v: vR(0.7, 1.3), s: vR(3, 6), gold: i % 2 === 0 });
  G.fx.push({ type: 'vscharge', a: a, at: a.atk, t: 0, life: 4, sp: sp, em: em });
}
function vsCharge(f) { var a = f.a; if (!a || a.atk !== f.at || f.done) { f.t = f.life; return null; } var H = allyH(a); return { a: a, H: H, cx: a.x, cy: a.y - H * 0.55, fy: a.y, k: Math.min(1, f.t / 0.5), pulse: 0.8 + 0.2 * Math.sin(f.t * 22) }; }
// 後ろの層（人物より先に描く＝体の後ろで光り、輪郭が浮く）：足元の輪・光の柱・胸の光
function drawChargeBack() {
  if (!G.fx) return; ctx.save();
  for (var n = 0; n < G.fx.length; n++) { var f = G.fx[n]; if (f.type !== 'vscharge') continue; var o = vsCharge(f); if (!o) continue;
    var C = VFX_SKY, t = f.t, H = o.H, cx = o.cx, cy = o.cy, fy = o.fy, k = o.k, pulse = o.pulse;
    for (var j = 0; j < 2; j++) {
      var ph = (t * 1.6 + j * 0.5) % 1, r = (230 - 170 * vEaseIn(ph)) * (0.7 + 0.3 * k), al = Math.sin(ph * Math.PI) * k;
      ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.4 * al); ctx.lineWidth = 9; ctx.beginPath(); ctx.ellipse(cx, fy + 3, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
      ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(j ? C.gold : C.glow, 0.8 * al); ctx.lineWidth = 6; ctx.stroke(); ctx.strokeStyle = vrgba(C.core, 0.9 * al); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.ellipse(cx, fy, r, r * 0.28, 0, 0, 6.283); ctx.stroke();
    }
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = 'rgba(4,6,22,' + (0.42 * k) + ')'; ctx.fillRect(camX - 20, camY + TOPY - 20, W + 40, CVH() + 40); // ラナの必殺と同じく、背景を暗くして光を立たせる
    vPuff(cx, cy, H * 0.9, C.dark, 0.35 * k);
    ctx.globalCompositeOperation = 'lighter'; vPillar(cx, fy, H * 1.0, H * 1.6 * k, { core: C.main, main: C.glow, glow: C.glow }, 0.95 * k * pulse); vPillar(cx, fy, H * 0.45, H * 1.3 * k, { core: C.core, main: C.gold, glow: C.gold }, 0.75 * k * pulse);
    for (var tg = 0; tg < 12; tg++) { // オーラの炎の舌：足元から体の外側を、揺れながら頭の上まで昇る（太さの変わるリボン、外は青・内は金、時間差の層）
      var sd = tg % 2 ? 1 : -1, ph2 = (t * 1.4 + tg * 0.29) % 1, base = cx + sd * H * (0.18 + (tg % 3) * 0.07), tipx = cx + sd * H * (0.1 + 0.25 * Math.sin(t * 4 + tg)), tipy = fy - H * (1.15 + 0.35 * (tg % 3) / 2) * (0.6 + 0.4 * ph2) * k;
      var ccx = base + sd * H * (0.35 + 0.15 * Math.sin(t * 6 + tg * 1.7)), ccy = fy - H * 0.6 * k, al3 = Math.sin(ph2 * Math.PI) * k, gold = tg % 3 === 0;
      var u1 = vEase(ph2 * 1.6), u0 = Math.max(0, ph2 * 1.6 - 0.7);
      vCurveRibbon(base, fy, ccx, ccy, tipx, tipy, Math.min(u0, u1), u1, H * 0.11, vCurveGrad(base, fy, ccx, ccy, tipx, tipy, Math.min(u0, u1), u1, gold ? C.gold : C.glow, 0.75 * al3));
      vCurveRibbon(base, fy, ccx, ccy, tipx, tipy, Math.min(u0, u1), u1, H * 0.04, vCurveGrad(base, fy, ccx, ccy, tipx, tipy, Math.min(u0, u1), u1, gold ? C.spark : C.core, al3));
    }
    for (var fl = 0; fl < 10; fl++) { var fp = (t * (1.3 + fl % 3 * 0.2) + fl * 0.17) % 1, fx = cx + Math.sin(fl * 2.1 + t * 3) * H * 0.3, fyy = fy - fp * H * 1.3; vGlow(fx, fyy, H * 0.22 * (1 - fp * 0.5), { core: C.core, main: fl % 2 ? C.gold : C.main, glow: fl % 2 ? C.gold : C.glow }, Math.sin(fp * Math.PI) * 0.55 * k); } // 体の後ろで揺らめく炎のかたまり
    vGlow(cx, cy, H * (0.35 + 0.35 * k) * pulse, { core: C.core, main: C.gold, glow: C.glow }, 0.7 * k);
  }
  ctx.restore();
}
// 前の層（人物の後に描く）：吸い込まれる光の筋と、昇る火の粉
FX2.vscharge = function (f) {
  var o = vsCharge(f); if (!o) return; var C = VFX_SKY, t = f.t, H = o.H, cx = o.cx, cy = o.cy, fy = o.fy, k = o.k, i;
  for (i = 0; i < f.sp.length; i++) {
    var q = f.sp[i], age = (t - q.d) % q.life; if (t < q.d) continue; var u = vEaseIn(age / q.life), rr = q.r * (1 - u) + 8, th = q.a + q.w * age * (0.5 + u);
    if (rr < H * 0.22) continue; // 体に重なる手前で消す（顔や着物を白く塗らない）
    var px = cx + Math.cos(th) * rr, py = cy + Math.sin(th) * rr * 0.6, a0 = Math.max(0, age - 0.05), u0 = vEaseIn(a0 / q.life), r0 = q.r * (1 - u0) + 8, th0 = q.a + q.w * a0 * (0.5 + u0);
    vStreak(px, py, px - (cx + Math.cos(th0) * r0), py - (cy + Math.sin(th0) * r0 * 0.6), Math.min(60, rr * 0.25) + 6, q.s * (0.6 + u), q.gold ? C.gold : C.main, (0.3 + 0.7 * u) * k);
  }
  for (i = 0; i < f.em.length; i++) { var e = f.em[i], p = (t * e.v + e.p) % 1, x = cx + e.ox * H * 0.42 * (1 - p * 0.3), y = fy - p * H * 1.15, al2 = Math.sin(p * Math.PI) * k; vGlow(x, y, e.s * 3, { core: C.core, main: e.gold ? C.gold : C.main, glow: e.gold ? C.gold : C.glow }, al2 * 0.6); vStreak(x, y, 0, -1, H * 0.06, e.s * 0.6, e.gold ? C.spark : C.core, al2); }
};
// 踏み抜き：足から縦に昇る光の柱 ＋ 画面いっぱいに走る流線 ＋ 地面の衝撃
function fxStarStomp(a) {
  G.fx.forEach(function (f) { if (f.type === 'vscharge' && f.a === a) f.done = true; });
  var H = allyH(a), ln = [];
  for (var i = 0; i < 22; i++) { // 流線：足元から扇形に、上と左右へ。画面の外まで
    var side = i % 2 ? 1 : -1, ang = -Math.PI / 2 + side * vR(0.15, 1.45), L = vR(W * 0.8, W * 1.4), bend = vR(0.12, 0.35) * side;
    ln.push({ ex: Math.cos(ang) * L, ey: Math.sin(ang) * L * 0.85, bx: Math.cos(ang + bend) * L * 0.5, by: Math.sin(ang + bend) * L * 0.5 * 0.85, d: vR(0, 0.12) + (i < 10 ? 0 : 0.05), w: vR(10, 22), gold: i % 3 === 0 });
  }
  for (i = 0; i < 6; i++) ln.push({ ex: (i % 2 ? 1 : -1) * W * vR(0.9, 1.3), ey: vR(-20, 10), bx: (i % 2 ? 1 : -1) * W * 0.4, by: -vR(20, 60), d: vR(0, 0.08), w: vR(8, 14), gold: i % 2 === 0, low: true }); // 地をはう流線
  G.fx.push({ type: 'vsstomp', x: a.x, y: a.y, h: H, t: 0, life: 0.95, ln: ln, sp: vSparks(36, 0, 400, 1200, 1.4) });
  fxRing(a.x, a.y, W * 0.75, 0.6, VFX_STAR);
  G.flash = 0.32; G.flashRGB = '170,205,255'; G.shake = Math.max(G.shake, 28); G.freeze = Math.max(G.freeze, 0.09);
}
FX2.vsstomp = function (f) {
  var C = VFX_SKY, t = f.t, ms = t * 1000, x = f.x, y = f.y, top = camY + TOPY - 40, PH = y - top, i;
  // ① 足から縦に昇る光の柱（3層＋暗い下地、先端が駆け上がり、根本は遅れて細る）
  var LY = [{ c: C.dark, w: 1.25, a: C.dk, lag: 20, dk: 1 }, { c: C.glow, w: 1.0, a: 0.85, lag: 30 }, { c: C.gold, w: 0.5, a: 0.95, lag: 12 }, { c: C.core, w: 0.18, a: 1, lag: 0 }];
  for (var l = 0; l < LY.length; l++) {
    var Ly = LY[l], head = vEase((ms - Ly.lag) / 120), fade = Math.max(0, 1 - Math.max(0, ms - 160) / 520); if (head <= 0 || fade <= 0) continue;
    var Wd = f.h * 0.55 * Ly.w * (0.6 + 0.4 * fade), hy = y - PH * head, g = ctx.createLinearGradient(0, y, 0, hy);
    g.addColorStop(0, vrgba(Ly.c, Ly.a * 0.25 * fade)); g.addColorStop(0.06, vrgba(Ly.c, Ly.a * fade)); g.addColorStop(0.7, vrgba(Ly.c, Ly.a * 0.7 * fade)); g.addColorStop(1, vrgba(Ly.c, 0)); // 根本も先端も四角く切れないよう、両端をぼかす
    ctx.globalCompositeOperation = Ly.dk ? 'source-over' : 'lighter'; ctx.fillStyle = g;
    ctx.beginPath(); ctx.moveTo(x - Wd * 0.25, y); ctx.quadraticCurveTo(x - Wd * 0.55, y - PH * 0.35 * head, x, hy); ctx.quadraticCurveTo(x + Wd * 0.55, y - PH * 0.35 * head, x + Wd * 0.25, y); ctx.closePath(); ctx.fill();
  }
  ctx.globalCompositeOperation = 'lighter';
  // ② 画面いっぱいの流線（時間差の3層：残光・本体・芯。青と金）
  for (i = 0; i < f.ln.length; i++) {
    var q = f.ln[i], b = ms - q.d * 1000; if (b <= 0) continue; var fd = Math.max(0, 1 - Math.max(0, b - 260) / 380); if (fd <= 0) continue;
    var p0x = x, p0y = y - (q.low ? 6 : f.h * 0.1), cx = x + q.bx, cy = p0y + q.by, p1x = x + q.ex, p1y = p0y + q.ey;
    var lay = [{ c: q.gold ? C.gold : C.glow, lag: 40, tail: 0.6, w: 2.2, a: 0.5 }, { c: q.gold ? C.gold : C.main, lag: 16, tail: 0.45, w: 1, a: 0.95 }, { c: C.core, lag: 0, tail: 0.32, w: 0.35, a: 1 }];
    for (var m = 0; m < 3; m++) { var Lr = lay[m], hd = vEase((b - Lr.lag) / 200), tl = vEase((b - Lr.lag - 200 * Lr.tail) / 300); if (hd <= 0) continue; var u0 = Math.min(hd, tl);
      vCurveRibbon(p0x, p0y, cx, cy, p1x, p1y, u0, hd, q.w * Lr.w * (0.7 + 0.3 * fd), vCurveGrad(p0x, p0y, cx, cy, p1x, p1y, u0, hd, Lr.c, Lr.a * fd)); }
  }
  // ③ 踏み抜いた点の光と、跳ね上がる火花（上へ）
  if (ms < 160) { vGlow(x, y - f.h * 0.2, f.h * (0.8 + ms / 120), { core: C.core, main: C.gold, glow: C.glow }, 1 - ms / 160); vStar4(x, y - f.h * 0.15, f.h * 0.9 * (1 - ms / 160), 0, C.core, 0.8 * (1 - ms / 160)); }
  drawSparks(f, x, y - 10, { core: C.core, spark: C.spark }, 3, 900);
};
