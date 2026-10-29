// コードの技エフェクト（画像なし）。吸引（引き寄せの一瞬）と拘束（続く間ずっと）。
// 作りの約束はスキル code-vfx-canvas：形・時間差の層・加算の光・向き・対象に合わせた大きさ。
// 時間は G.fx の t（update.js が進める。ヒットストップ中は止まる）。粒子は t から位置を計算するので、状態を持たない。
var VFX_PULL = { glow: '130,80,255', main: '165,125,255', core: '246,240,255', spark: '200,175,255', dark: '28,10,60' };
// 明るい昼の床では、加算の光が白く飛んで色が消える。光の下に、通常の合成で暗い下地（dark）を薄く敷いて、形と色を残す
function vrgba(c, a) { return 'rgba(' + c + ',' + (a < 0 ? 0 : a > 1 ? 1 : a) + ')'; }
function vEase(t) { t = t < 0 ? 0 : t > 1 ? 1 : t; return 1 - Math.pow(1 - t, 3); }
function vEaseIn(t) { t = t < 0 ? 0 : t > 1 ? 1 : t; return t * t; }

// 吸引を出す（play.js の doPull から）。gx,gy＝集める点、R＝範囲、foes＝引いた敵
function fxPull(gx, gy, R, foes) {
  var sp = [], n = 36 + Math.min(24, foes.length * 3);
  for (var i = 0; i < n; i++) sp.push({ a: Math.random() * 6.283, r: R * (0.35 + Math.random() * 0.7), w: 7 + Math.random() * 6, d: Math.random() * 0.12, len: 0.03 + Math.random() * 0.04, s: 1.5 + Math.random() * 2.5 });
  G.fx.push({ type: 'vpull', x: gx, y: gy, R: R, t: 0, life: 0.62, sp: sp, foes: foes.slice(), land: 0.18 });
}

// 渦の粒子の位置（年齢 a 秒）。半径は外→中へ縮み、角度は回る（内へ行くほど速い＝渦）
function vSpiral(f, q, a) {
  var k = vEaseIn((a - q.d) / 0.42), r = q.r * (1 - k) + 6, th = q.a + q.w * (a - q.d) * (0.4 + k);
  return { x: f.x + Math.cos(th) * r, y: f.y - 40 + Math.sin(th) * r * 0.32, k: k };
}

function drawVPull(f) {
  var t = f.t, C = VFX_PULL, fade = t < 0.4 ? 1 : 1 - (t - 0.4) / (f.life - 0.4);
  // ① 縮む輪（床の楕円）×3層、時間差。残光＝太く薄く先に、芯＝細く白く最後に。縮むほど太く明るく
  var L = [{ c: C.glow, lag: 0, w: 30, a: 0.35 }, { c: C.main, lag: 0.03, w: 9, a: 0.8 }, { c: C.core, lag: 0.055, w: 3.2, a: 1 }];
  for (var j = 0; j < 2; j++) for (var l = 0; l < 3; l++) {
    var Ly = L[l], k = vEase((t - Ly.lag - j * 0.09) / 0.3); if (k <= 0 || k >= 1) continue;
    var r = f.R * (1 - k) * (j ? 0.7 : 1) + 10;
    if (l === 0) { ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.3 * (1 - k * 0.6) * fade); ctx.lineWidth = 6 + 6 * k; ctx.beginPath(); ctx.ellipse(f.x, f.y + 2, r, r * 0.3, 0, 0, 6.283); ctx.stroke(); ctx.globalCompositeOperation = 'lighter'; }
    ctx.strokeStyle = vrgba(Ly.c, Ly.a * (0.3 + 0.7 * k) * (1 - k * 0.6) * fade); ctx.lineWidth = Ly.w * (0.5 + k);
    ctx.beginPath(); ctx.ellipse(f.x, f.y, r, r * 0.3, 0, 0, 6.283); ctx.stroke();
  }
  // ② 鎖：集める点 → 各敵（腰の高さ）。たるんだベジェ、点線が中心へ流れる。3層
  var cx = f.x, cy = f.y - 46, cw = Math.max(0, 1 - Math.max(0, t - f.land) / 0.22) * fade;
  if (cw > 0) for (var i = 0; i < f.foes.length; i++) {
    var e = f.foes[i]; if (!e || e.dead) continue;
    var ex = e.x, ey = e.y - eh(e) * 0.45, mx = (ex + cx) / 2, my = Math.max(ey, cy) + 26 + Math.abs(ex - cx) * 0.06 * (1 - vEase(t / f.land));
    var reach = vEase(t / 0.08); // 鎖が敵まで一気に伸びる
    var px = cx + (ex - cx) * reach, py = cy + (ey - cy) * reach, qx = cx + (mx - cx) * reach, qy = cy + (my - cy) * reach;
    ctx.lineCap = 'round'; ctx.setLineDash([]);
    ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.45 * cw); ctx.lineWidth = 11; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke(); ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, 0.35 * cw); ctx.lineWidth = 17; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.strokeStyle = vrgba(C.main, 0.95 * cw); ctx.lineWidth = 6.5; ctx.setLineDash([18, 11]); ctx.lineDashOffset = t * 260; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.strokeStyle = vrgba(C.core, cw); ctx.lineWidth = 2; ctx.setLineDash([6, 23]); ctx.lineDashOffset = t * 260 + 4; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.setLineDash([]);
  }
  // ③ 渦の粒子：速度の向き（少し前の位置から今の位置）に引き延ばす。中へ行くほど明るく
  for (var s = 0; s < f.sp.length; s++) {
    var q = f.sp[s], a = t; if (a < q.d || a > q.d + 0.46) continue;
    var p1 = vSpiral(f, q, a), p0 = vSpiral(f, q, a - q.len), al = (0.35 + 0.65 * p1.k) * fade;
    var g = ctx.createLinearGradient(p0.x, p0.y, p1.x, p1.y); g.addColorStop(0, vrgba(C.spark, 0)); g.addColorStop(0.7, vrgba(C.spark, 0.8 * al)); g.addColorStop(1, vrgba(C.core, al));
    ctx.strokeStyle = g; ctx.lineWidth = q.s * (0.8 + 0.8 * p1.k); ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
  }
  // ④ 集まった瞬間の光
  var ft = t - f.land; if (ft > 0 && ft < 0.2 && f.foes.length) {
    var kk = 1 - ft / 0.2, rr = 80 + 160 * (1 - kk), gr = ctx.createRadialGradient(cx, cy, 0, cx, cy, rr);
    gr.addColorStop(0, vrgba(C.core, 0.7 * kk)); gr.addColorStop(0.35, vrgba(C.main, 0.3 * kk)); gr.addColorStop(1, vrgba(C.glow, 0));
    ctx.fillStyle = gr; ctx.fillRect(cx - rr, cy - rr, rr * 2, rr * 2);
  }
}

// 拘束の印（床）：回る2重の輪＋残り時間の弧。残り時間で薄くなる。draw.js が敵より先（床の上）に呼ぶ
function drawBindFloor() {
  if (!G.enemies) return;
  var C = VFX_PULL, tt = G.t || 0, bound = [];
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (!(e.bind > 0) || e.state !== 'walk') continue; bound.push(e);
    var s = depthScale(e.y) * e.size, rest = Math.min(1, e.bind / (e.bindMax || e.bind)), al = Math.min(1, e.bind / 0.25), rx = 60 * s, ry = 17 * s;
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.32 * al); ctx.beginPath(); ctx.ellipse(e.x, e.y, rx * 1.18, ry * 1.18, 0, 0, 6.283); ctx.fill(); ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, 0.25 * al); ctx.lineWidth = 9; ctx.beginPath(); ctx.ellipse(e.x, e.y, rx, ry, 0, 0, 6.283); ctx.stroke();
    ctx.strokeStyle = vrgba(C.main, 0.85 * al); ctx.lineWidth = 2.5; ctx.setLineDash([10 * s, 7 * s]); ctx.lineDashOffset = -tt * 40;
    ctx.beginPath(); ctx.ellipse(e.x, e.y, rx, ry, 0, 0, 6.283); ctx.stroke();
    ctx.lineDashOffset = tt * 60; ctx.beginPath(); ctx.ellipse(e.x, e.y, rx * 0.7, ry * 0.7, 0, 0, 6.283); ctx.stroke(); ctx.setLineDash([]);
    // 残り時間の弧（上から時計回りに減る）。切れる直前に分かる
    ctx.strokeStyle = vrgba(C.core, 0.95 * al); ctx.lineWidth = 3.5; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.ellipse(e.x, e.y, rx * 1.12, ry * 1.12, 0, -1.571, -1.571 + 6.283 * rest); ctx.stroke();
  }
  // 2体以上を束ねたら、全体を囲む大きな印（一掃の狙いどころ）
  if (bound.length >= 2) {
    var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9, mb = 0;
    bound.forEach(function (e) { x0 = Math.min(x0, e.x); x1 = Math.max(x1, e.x); y0 = Math.min(y0, e.y); y1 = Math.max(y1, e.y); mb = Math.max(mb, e.bind); });
    var gx = (x0 + x1) / 2, gy = (y0 + y1) / 2, R = Math.max(120, (x1 - x0) / 2 + 95), Ry = Math.max(36, (y1 - y0) / 2 + 30), ga = Math.min(1, mb / 0.3), pulse = 1 + 0.03 * Math.sin(tt * 9);
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.18 * ga); ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.fill();
    ctx.strokeStyle = vrgba(C.dark, 0.35 * ga); ctx.lineWidth = 6; ctx.stroke(); ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, 0.3 * ga); ctx.lineWidth = 16; ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.stroke();
    ctx.strokeStyle = vrgba(C.main, 0.7 * ga); ctx.lineWidth = 2; ctx.setLineDash([3, 12]); ctx.lineDashOffset = -tt * 30;
    ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.stroke(); ctx.setLineDash([]);
    for (var m = 0; m < 6; m++) { // 回る6つの楔（呪印）
      var th = tt * 1.4 + m * 1.047, px = gx + Math.cos(th) * R * pulse, py = gy + Math.sin(th) * Ry * pulse;
      ctx.fillStyle = vrgba(C.core, 0.8 * ga); ctx.beginPath(); ctx.moveTo(px, py - 10); ctx.lineTo(px + 5.5, py); ctx.lineTo(px, py + 10); ctx.lineTo(px - 5.5, py); ctx.closePath(); ctx.fill();
    }
  }
  ctx.restore();
}

// 拘束の帯（腰）：敵の絵の後に呼ぶ。手前半分だけ太く描いて、体に巻きついて見せる
function drawBindBand(e) {
  var C = VFX_PULL, tt = G.t || 0, s = depthScale(e.y) * e.size, al = Math.min(1, e.bind / 0.25), y = e.y - eh(e) * 0.45, rx = 38 * s, ry = 10 * s, wob = 1 + 0.05 * Math.sin(tt * 14 + e.x);
  ctx.save(); ctx.lineCap = 'round';
  ctx.strokeStyle = vrgba(C.dark, 0.45 * al); ctx.lineWidth = 6; ctx.beginPath(); ctx.ellipse(e.x, y + 1, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.35 * al); ctx.lineWidth = 10; ctx.beginPath(); ctx.ellipse(e.x, y, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.strokeStyle = vrgba(C.main, 0.9 * al); ctx.lineWidth = 3.5; ctx.beginPath(); ctx.ellipse(e.x, y, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.strokeStyle = vrgba(C.core, al); ctx.lineWidth = 1.3; ctx.beginPath(); ctx.ellipse(e.x, y - 1, rx * wob, ry * wob, 0, 0.35, 2.79); ctx.stroke();
  ctx.restore();
}

// ===== 攻撃：剣の軌跡（三日月×3層）と、当たった敵ごとの衝撃 =====
var VFX_ATK = { glow: '90,160,255', main: '150,205,255', core: '255,255,255', spark: '200,230,255', dark: '10,20,50' };
// 楕円の弧に沿った三日月のリボン（ローカル座標）。a0→a1 へ刃が走る。u0〜u1 は描く区間（0〜1）
function vArcRibbon(rx, ry, a0, a1, u0, u1, w, style) {
  if (u1 - u0 < 0.01) return;
  var N = 26, Lp = [], Rp = [];
  for (var i = 0; i <= N; i++) {
    var s = i / N, u = u0 + (u1 - u0) * s, th = a0 + (a1 - a0) * u, c = Math.cos(th), sn = Math.sin(th);
    var ww = w * Math.pow(Math.sin(Math.PI * Math.min(1, s * 1.12)), 0.7) * (0.2 + 0.8 * s);
    var nx = c / rx, ny = sn / ry, m = Math.hypot(nx, ny) || 1; nx /= m; ny /= m; // 楕円の外向きの法線
    var px = rx * c, py = ry * sn;
    Lp.push(px + nx * ww, py + ny * ww); Rp.push(px - nx * ww * 0.35, py - ny * ww * 0.35); // 外に厚く、内に薄く
  }
  ctx.beginPath(); ctx.moveTo(Lp[0], Lp[1]);
  for (i = 2; i < Lp.length; i += 2) ctx.lineTo(Lp[i], Lp[i + 1]);
  for (i = Rp.length - 2; i >= 0; i -= 2) ctx.lineTo(Rp[i], Rp[i + 1]);
  ctx.closePath(); ctx.fillStyle = style; ctx.fill();
}
function vArcGrad(rx, ry, a0, a1, u0, u1, col, a) {
  var t0 = a0 + (a1 - a0) * u0, t1 = a0 + (a1 - a0) * u1, g = ctx.createLinearGradient(rx * Math.cos(t0), ry * Math.sin(t0), rx * Math.cos(t1), ry * Math.sin(t1));
  g.addColorStop(0, vrgba(col, 0)); g.addColorStop(0.55, vrgba(col, a * 0.35)); g.addColorStop(0.9, vrgba(col, a)); g.addColorStop(1, vrgba(col, a * 0.6));
  return g;
}
function drawVArc(f) {
  var C = VFX_ATK, ms = f.t * 1000, SW = f.big ? 120 : 90, FD = f.life * 1000 - SW;
  var rx = f.R * (f.second ? 0.62 : 0.68), ry = f.second ? 78 : 128, a0 = f.second ? -0.95 : -1.85, a1 = f.second ? 0.95 : 0.8;
  if (f.big) { rx *= 1.12; ry *= 1.15; }
  var W = (f.big ? 52 : 36), fade = ms > SW ? Math.max(0, 1 - (ms - SW) / FD) : 1;
  var LY = [{ c: C.glow, lag: 40, tail: 0.6, w: 2.2, a: 0.5 }, { c: C.main, lag: 15, tail: 0.45, w: 1.0, a: 0.95 }, { c: C.core, lag: 0, tail: 0.32, w: 0.38, a: 1 }];
  ctx.save(); ctx.translate(f.x + f.face * 30, f.y - 95 * depthScale(f.y) + (f.second ? 30 : 0)); ctx.scale(f.face, 1);
  // 暗い下地（明るい床でも形が残る）：本体と同じ形を、通常の合成で薄く
  var hd = vEase((ms - 15) / SW), tl = vEase((ms - 15 - SW * 0.45) / (SW * 1.4));
  ctx.globalCompositeOperation = 'source-over';
  vArcRibbon(rx, ry, a0, a1, Math.min(hd, tl), hd, W * 1.25, vArcGrad(rx, ry, a0, a1, Math.min(hd, tl), hd, C.dark, 0.28 * fade));
  ctx.globalCompositeOperation = 'lighter';
  for (var l = 0; l < 3; l++) {
    var L = LY[l], head = vEase((ms - L.lag) / SW); if (head <= 0) continue;
    var tail = vEase((ms - L.lag - SW * L.tail) / (SW * 1.4)), u0 = Math.min(head, tail);
    vArcRibbon(rx, ry, a0, a1, u0, head, W * L.w * (0.85 + 0.15 * fade), vArcGrad(rx, ry, a0, a1, u0, head, L.c, L.a * fade));
  }
  // 刃の先端からこぼれる火花（接線の向き）。t から位置を計算
  for (var k = 0; k < f.sp.length; k++) {
    var q = f.sp[k], age = (ms - q.d) / 1000; if (age < 0 || age > q.life) continue;
    var th = a0 + (a1 - a0) * q.u, tx = -rx * Math.sin(th) * (a1 > a0 ? 1 : -1), ty = ry * Math.cos(th) * (a1 > a0 ? 1 : -1), m = Math.hypot(tx, ty) || 1;
    var vx = tx / m * q.v, vy = ty / m * q.v - 120, dr = Math.exp(-age * 5), x = rx * Math.cos(th) + vx * (1 - dr) / 5, y = ry * Math.sin(th) + vy * (1 - dr) / 5 + 260 * age * age;
    var cvx = vx * dr, cvy = vy * dr + 520 * age, cm = Math.hypot(cvx, cvy) || 1, ln = Math.min(46, cm * 0.05) + 3, al = 1 - age / q.life;
    ctx.strokeStyle = vrgba(C.spark, 0.9 * al); ctx.lineWidth = q.s * (0.5 + 0.5 * al); ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x - cvx / cm * ln, y - cvy / cm * ln); ctx.stroke();
  }
  ctx.restore();
}
function fxArc(h, face, R, life, big, second) {
  var sp = [], n = big ? 26 : 16;
  for (var i = 0; i < n; i++) sp.push({ u: 0.35 + Math.random() * 0.65, d: 20 + Math.random() * 90, v: 300 + Math.random() * 700, life: 0.18 + Math.random() * 0.3, s: 1.2 + Math.random() * 2.2 });
  G.vhitN = 0; // 1振りで光と切り口を出す敵は先頭の4体まで（重なると白く飛ぶ）
  G.fx.push({ type: 'varc', x: h.x, y: h.y, face: face, R: R, t: 0, life: Math.max(life, 0.3), big: big, second: second, sp: sp });
}
// 当たった敵ごとの衝撃：一瞬の光＋刃の向きの短い切り口＋飛び散る火花
function fxHit(e, dir, strong) {
  var lead = (G.vhitN = (G.vhitN || 0) + 1) <= 4, sp = [], n = lead ? (strong ? 9 : 6) : 3;
  for (var i = 0; i < n; i++) { var a = (Math.random() - 0.5) * 1.6 - 0.25; sp.push({ vx: dir * Math.cos(a) * (250 + Math.random() * 650), vy: Math.sin(a) * (250 + Math.random() * 500) - 150, life: 0.15 + Math.random() * 0.25, s: 1.2 + Math.random() * 2 }); }
  G.fx.push({ type: 'vhit', e: e, x: e.x, y: e.y - eh(e) * 0.55, h: eh(e), dir: dir, strong: strong, lead: lead, t: 0, life: 0.4, sp: sp, rot: -0.5 + Math.random() * 0.35 });
}
function drawVHit(f) {
  var C = VFX_ATK, t = f.t, x = f.x, y = f.y, sz = f.h * (f.strong ? 0.75 : 0.55);
  if (f.lead && t < 0.1) { // 光
    var k = 1 - t / 0.1, r = sz * (0.3 + 0.35 * (1 - k)), g = ctx.createRadialGradient(x, y, 0, x, y, r);
    g.addColorStop(0, vrgba(C.core, 0.5 * k)); g.addColorStop(0.3, vrgba(C.main, 0.22 * k)); g.addColorStop(1, vrgba(C.glow, 0)); ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }
  if (f.lead && t < 0.14) { // 切り口：細長いひし形が一瞬で伸びて細る
    var k2 = vEase(t / 0.05), fd = 1 - Math.max(0, t - 0.05) / 0.09, L = sz * 0.95 * k2, w = sz * 0.04 * fd;
    ctx.save(); ctx.translate(x, y); ctx.rotate(f.rot * f.dir); ctx.scale(f.dir, 1);
    ctx.fillStyle = vrgba(C.main, 0.6 * fd); ctx.beginPath(); ctx.moveTo(-L * 0.5, 0); ctx.lineTo(0, -w * 2.2); ctx.lineTo(L * 0.5, 0); ctx.lineTo(0, w * 2.2); ctx.closePath(); ctx.fill();
    ctx.fillStyle = vrgba(C.core, fd); ctx.beginPath(); ctx.moveTo(-L * 0.5, 0); ctx.lineTo(0, -w * 0.7); ctx.lineTo(L * 0.5, 0); ctx.lineTo(0, w * 0.7); ctx.closePath(); ctx.fill();
    ctx.restore();
  }
  for (var i = 0; i < f.sp.length; i++) { // 火花：打った向きへ、速度に沿って伸びる
    var q = f.sp[i]; if (t > q.life) continue;
    var dr = Math.exp(-t * 6), px = x + q.vx * (1 - dr) / 6, py = y + q.vy * (1 - dr) / 6 + 500 * t * t, cvx = q.vx * dr, cvy = q.vy * dr + 1000 * t, cm = Math.hypot(cvx, cvy) || 1, ln = Math.min(40, cm * 0.045) + 2, al = 1 - t / q.life;
    ctx.strokeStyle = vrgba(i % 3 ? C.spark : '255,236,190', al); ctx.lineWidth = q.s; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px - cvx / cm * ln, py - cvy / cm * ln); ctx.stroke();
  }
}
