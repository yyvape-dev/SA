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
  var L = [{ c: C.glow, lag: 0, w: 22, a: 0.35 }, { c: C.main, lag: 0.03, w: 7, a: 0.8 }, { c: C.core, lag: 0.055, w: 2.5, a: 1 }];
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
    ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba(C.dark, 0.45 * cw); ctx.lineWidth = 8; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke(); ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, 0.35 * cw); ctx.lineWidth = 12; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.strokeStyle = vrgba(C.main, 0.95 * cw); ctx.lineWidth = 5; ctx.setLineDash([14, 9]); ctx.lineDashOffset = t * 260; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.strokeStyle = vrgba(C.core, cw); ctx.lineWidth = 1.5; ctx.setLineDash([5, 18]); ctx.lineDashOffset = t * 260 + 4; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.quadraticCurveTo(qx, qy, px, py); ctx.stroke();
    ctx.setLineDash([]);
  }
  // ③ 渦の粒子：速度の向き（少し前の位置から今の位置）に引き延ばす。中へ行くほど明るく
  for (var s = 0; s < f.sp.length; s++) {
    var q = f.sp[s], a = t; if (a < q.d || a > q.d + 0.46) continue;
    var p1 = vSpiral(f, q, a), p0 = vSpiral(f, q, a - q.len), al = (0.35 + 0.65 * p1.k) * fade;
    var g = ctx.createLinearGradient(p0.x, p0.y, p1.x, p1.y); g.addColorStop(0, vrgba(C.spark, 0)); g.addColorStop(0.7, vrgba(C.spark, 0.8 * al)); g.addColorStop(1, vrgba(C.core, al));
    ctx.strokeStyle = g; ctx.lineWidth = q.s * (0.6 + 0.6 * p1.k); ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
  }
  // ④ 集まった瞬間の光
  var ft = t - f.land; if (ft > 0 && ft < 0.2 && f.foes.length) {
    var kk = 1 - ft / 0.2, rr = 60 + 120 * (1 - kk), gr = ctx.createRadialGradient(cx, cy, 0, cx, cy, rr);
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
    var s = depthScale(e.y) * e.size, rest = Math.min(1, e.bind / (e.bindMax || e.bind)), al = Math.min(1, e.bind / 0.25), rx = 46 * s, ry = 13 * s;
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
    var gx = (x0 + x1) / 2, gy = (y0 + y1) / 2, R = Math.max(90, (x1 - x0) / 2 + 70), Ry = Math.max(28, (y1 - y0) / 2 + 22), ga = Math.min(1, mb / 0.3), pulse = 1 + 0.03 * Math.sin(tt * 9);
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.18 * ga); ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.fill();
    ctx.strokeStyle = vrgba(C.dark, 0.35 * ga); ctx.lineWidth = 6; ctx.stroke(); ctx.globalCompositeOperation = 'lighter';
    ctx.strokeStyle = vrgba(C.glow, 0.3 * ga); ctx.lineWidth = 16; ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.stroke();
    ctx.strokeStyle = vrgba(C.main, 0.7 * ga); ctx.lineWidth = 2; ctx.setLineDash([3, 12]); ctx.lineDashOffset = -tt * 30;
    ctx.beginPath(); ctx.ellipse(gx, gy, R * pulse, Ry * pulse, 0, 0, 6.283); ctx.stroke(); ctx.setLineDash([]);
    for (var m = 0; m < 6; m++) { // 回る6つの楔（呪印）
      var th = tt * 1.4 + m * 1.047, px = gx + Math.cos(th) * R * pulse, py = gy + Math.sin(th) * Ry * pulse;
      ctx.fillStyle = vrgba(C.core, 0.8 * ga); ctx.beginPath(); ctx.moveTo(px, py - 7); ctx.lineTo(px + 4, py); ctx.lineTo(px, py + 7); ctx.lineTo(px - 4, py); ctx.closePath(); ctx.fill();
    }
  }
  ctx.restore();
}

// 拘束の帯（腰）：敵の絵の後に呼ぶ。手前半分だけ太く描いて、体に巻きついて見せる
function drawBindBand(e) {
  var C = VFX_PULL, tt = G.t || 0, s = depthScale(e.y) * e.size, al = Math.min(1, e.bind / 0.25), y = e.y - eh(e) * 0.45, rx = 30 * s, ry = 8 * s, wob = 1 + 0.05 * Math.sin(tt * 14 + e.x);
  ctx.save(); ctx.lineCap = 'round';
  ctx.strokeStyle = vrgba(C.dark, 0.45 * al); ctx.lineWidth = 6; ctx.beginPath(); ctx.ellipse(e.x, y + 1, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(C.glow, 0.35 * al); ctx.lineWidth = 10; ctx.beginPath(); ctx.ellipse(e.x, y, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.strokeStyle = vrgba(C.main, 0.9 * al); ctx.lineWidth = 3.5; ctx.beginPath(); ctx.ellipse(e.x, y, rx * wob, ry * wob, 0, 0.15, 2.99); ctx.stroke();
  ctx.strokeStyle = vrgba(C.core, al); ctx.lineWidth = 1.3; ctx.beginPath(); ctx.ellipse(e.x, y - 1, rx * wob, ry * wob, 0, 0.35, 2.79); ctx.stroke();
  ctx.restore();
}
