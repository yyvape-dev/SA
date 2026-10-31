// コードのエフェクト その3（2026-11-01）：格上の仲間（ランカ・リリィ）の技を、派手さと豪快さで強く見せる部品。fx2.js の次に読む。
// 調べた現場の考え方（引き継ぎ 2026-11-01）：
//   ・予兆（溜め）→ 頂点（当たり）→ 余韻。余韻は急に消さない（地割れ・砂埃が残って引く）。
//   ・衝撃の輪は「中心から広がる」「均一にしない」（太さと濃さにむら、途切れ）。煙・砂埃は大きさと寿命をばらす。
//   ・地面に効いた手ごたえは、砂埃・岩片・地割れ・揺れで出す。広がるものは薄く、集まるもの（溜め）は濃く。
//   ・簡素に見える原因は情報量と動きの単調さ。芯・光・火花・衝撃波・砂埃を重ねる。
// 粒子は t から位置を計算する（状態を持たない）。Pixi 版（battle/pxfx.js）では三角形の束になり、数が多くても1回の描画。
'use strict';
var FX_UNDER = {}; // 床の層に描くエフェクト（type → 関数）
var VFX_DUST = ['222,204,172', '150,124,96', '98,78,60']; // 砂埃（光らない。明るい土・中・影）
function vNz(s, a) { return 0.5 + 0.25 * Math.sin(a * 3 + s) + 0.15 * Math.sin(a * 7 + s * 2.3) + 0.1 * Math.sin(a * 13 + s * 4.1); } // 輪をまわる、継ぎ目のないむら（0〜1）
function vRnd(seed) { var x = Math.sin(seed * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }

// むらのある衝撃の輪（床の楕円）：中心から広がり、太さと濃さが角度で変わり、ところどころ途切れる。前の縁が明るく、後ろへ柔らかい
function vRingN(x, y, r, w, col, a, seed, gap) {
  if (a <= 0.01 || r < 2) return; var N = 56;
  ctx.lineCap = 'butt'; // 隣り合う短い弧なので丸い端は要らない（頂点が数倍になる）
  for (var i = 0; i < N; i++) {
    var a0 = i / N * 6.283, a1 = (i + 1) / N * 6.283, n = vNz(seed, a0 + 0.5 / N * 6.283);
    if (gap && n < gap) continue; // 途切れ
    var k = Math.min(1, (n - (gap || 0)) / 0.25);
    ctx.strokeStyle = vrgba(col, a * (0.35 + 0.65 * n) * k); ctx.lineWidth = Math.max(0.5, w * (0.45 + 1.1 * n));
    ctx.beginPath(); ctx.ellipse(x, y, r, r * 0.28, 0, a0, a1 + 0.02); ctx.stroke();
  }
}
// 地割れ（床）：中心から枝分かれするぎざぎざの線。暗い溝（通常の合成）＋芯の光（加算）。光は早く引き、溝は長く残る
function vMakeCracks(n, L, seed) {
  var out = [];
  for (var i = 0; i < n; i++) {
    var th = i / n * 6.283 + (vRnd(seed + i) - 0.5) * 0.6, len = L * (0.55 + 0.6 * vRnd(seed + i * 3.1)), pts = [0, 0], x = 0, y = 0, seg = 9;
    for (var j = 1; j <= seg; j++) { var tt = th + (vRnd(seed + i * 17 + j) - 0.5) * 0.9; x += Math.cos(tt) * len / seg; y += Math.sin(tt) * len / seg; pts.push(x, y); }
    out.push({ p: pts, w: 1 + vRnd(seed + i * 5) * 1.2 });
    if (vRnd(seed + i * 7) < 0.6) { // 枝
      var b = 3 + Math.floor(vRnd(seed + i * 9) * 4), bx = pts[b * 2], by = pts[b * 2 + 1], bt = th + (vRnd(seed + i * 11) < 0.5 ? -1 : 1) * (0.5 + vRnd(seed + i) * 0.5), q = [bx, by];
      for (j = 1; j <= 5; j++) { bx += Math.cos(bt + (vRnd(seed + i * 23 + j) - 0.5)) * len * 0.07; by += Math.sin(bt + (vRnd(seed + i * 29 + j) - 0.5)) * len * 0.07; q.push(bx, by); }
      out.push({ p: q, w: 0.6, br: b / seg });
    }
  }
  return out;
}
function vDrawCracks(cx, cy, cr, grow, dark, glow, C) {
  for (var i = 0; i < cr.length; i++) {
    var c = cr[i], p = c.p, n = p.length / 2, g = c.br != null ? Math.max(0, (grow - c.br) / (1 - c.br)) : grow, m = Math.max(1, Math.floor((n - 1) * g)); if (g <= 0) continue;
    for (var pass = 0; pass < (glow > 0.01 ? 3 : 1); pass++) {
      if (pass === 0) { ctx.globalCompositeOperation = 'source-over'; ctx.strokeStyle = vrgba('24,14,10', 0.8 * dark); ctx.lineWidth = 8 * c.w; }
      else { ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = vrgba(pass === 1 ? C.glow : C.core, (pass === 1 ? 0.5 : 0.95) * glow); ctx.lineWidth = (pass === 1 ? 10 : 2.6) * c.w; }
      ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(cx + p[0], cy + p[1] * 0.3);
      for (var j = 1; j <= m; j++) ctx.lineTo(cx + p[j * 2], cy + p[j * 2 + 1] * 0.3);
      ctx.stroke();
    }
  }
  ctx.globalCompositeOperation = 'lighter';
}
// 岩片：多角形が回りながら飛び、床に落ちて止まり、消える
function vMakeDebris(n, sp0, sp1, seed) {
  var a = []; for (var i = 0; i < n; i++) { var th = vRnd(seed + i) * 6.283, v = sp0 + (sp1 - sp0) * vRnd(seed + i * 2.7); a.push({ vx: Math.cos(th) * v, vz: Math.sin(th) * v * 0.3, vy: -(300 + vRnd(seed + i * 5.3) * 700), s: 6 + vRnd(seed + i * 7.1) * 11, rot: vRnd(seed + i * 3) * 6, w: (vRnd(seed + i * 9) - 0.5) * 18, d: vRnd(seed + i * 11) * 0.05, k: Math.floor(vRnd(seed + i * 13) * 3) }); }
  return a;
}
function vDrawDebris(x, y, D, t, life) {
  ctx.globalCompositeOperation = 'source-over';
  for (var i = 0; i < D.length; i++) {
    var q = D[i], a = t - q.d; if (a < 0) continue; var G2 = 2200, tl = -2 * q.vy / G2, ta = Math.min(a, tl), h = q.vy * ta + 0.5 * G2 * ta * ta, al = Math.min(1, (life - a) / 0.3); if (al <= 0) continue;
    var dr = 1 - Math.exp(-ta * 1.5), px = x + q.vx * dr / 1.5, pz = q.vz * dr / 1.5, py = y + pz + Math.min(0, h);
    ctx.save(); ctx.translate(px, py); ctx.rotate(q.rot + q.w * ta); ctx.fillStyle = vrgba(VFX_DUST[2 - q.k % 2], 0.95 * al);
    var s = q.s; ctx.beginPath(); ctx.moveTo(-s, -s * 0.4); ctx.lineTo(-s * 0.2, -s); ctx.lineTo(s * 0.9, -s * 0.5); ctx.lineTo(s * 0.7, s * 0.6); ctx.lineTo(-s * 0.5, s * 0.8); ctx.closePath(); ctx.fill();
    ctx.fillStyle = vrgba(VFX_DUST[0], 0.6 * al); ctx.beginPath(); ctx.moveTo(-s * 0.2, -s); ctx.lineTo(s * 0.9, -s * 0.5); ctx.lineTo(s * 0.2, -s * 0.1); ctx.closePath(); ctx.fill(); // 上の面（光が当たる）
    ctx.restore();
  }
  ctx.globalCompositeOperation = 'lighter';
}
// 砂埃の輪：床をころがって外へ広がり、少し渦を巻いて昇り、ふくらみながら薄くなる（大きさと寿命はばらばら）
function vMakeDust(n, R, seed) {
  var a = []; for (var i = 0; i < n; i++) a.push({ th: i / n * 6.283 + vRnd(seed + i) * 0.4, v: R * (0.55 + 0.6 * vRnd(seed + i * 2.1)), sw: (vRnd(seed + i * 4.3) - 0.3) * 1.2, up: 30 + vRnd(seed + i * 5.7) * 120, r: 24 + vRnd(seed + i * 6.1) * 34, life: 0.7 + vRnd(seed + i * 8.9) * 0.9, d: vRnd(seed + i * 9.7) * 0.08, c: Math.floor(vRnd(seed + i * 3.3) * 3) });
  return a;
}
function vDustPuff(x, y, r, c, a) { // 砂埃のひとかたまり：影の土台＋上に明るい頂（平たい塊に見せない）
  vPuff(x, y + r * 0.12, r, VFX_DUST[Math.min(2, c + 1)], a * 0.9); vPuff(x - r * 0.12, y - r * 0.22, r * 0.62, VFX_DUST[0], a * 0.75);
}
function vDrawDust(x, y, D, t, k) {
  ctx.globalCompositeOperation = 'source-over';
  for (var i = 0; i < D.length; i++) {
    var q = D[i], a = t - q.d; if (a < 0 || a > q.life) continue; var u = a / q.life, dr = 1 - Math.exp(-a * 3.2), th = q.th + q.sw * dr;
    var px = x + Math.cos(th) * q.v * dr, py = y + Math.sin(th) * q.v * dr * 0.3 - q.up * dr - 12, r = q.r * (0.6 + 1.6 * dr) * (k || 1);
    vDustPuff(px, py, r, q.c % 2, 0.62 * (1 - u) * Math.min(1, a / 0.05)); // 広がるほど薄く
  }
  ctx.globalCompositeOperation = 'lighter';
}

/* ===== 地を割る一撃（ランカの踏み抜き・星震の締め）：むらのある衝撃の輪×2・地割れ・岩片・砂埃の輪・中心の光 ===== */
function fxGroundSlam(x, y, R, C, big, lite) { // lite＝小さな当たり用（数を減らす）
  var s = Math.random() * 100, m = lite ? 0.3 : 1;
  G.fx.push({ type: 'vgslam', x: x, y: y, R: R, C: C || VFX_STAR, t: 0, life: big ? 1.6 : lite ? 0.9 : 1.2, seed: s, cr: vMakeCracks(lite ? 5 : big ? 11 : 8, R * 0.42, s), deb: vMakeDebris(Math.round((big ? 30 : 20) * m), R * 0.25, R * 0.7, s), dust: vMakeDust(Math.round((big ? 46 : 34) * m), R * 0.55, s + 9), big: big, lite: lite });
}
FX_UNDER.vgslam = function (f) { // 床の層：地割れ（暗い溝は長く残り、光は早く引く）
  var t = f.t, grow = vEase(t / 0.12), dark = Math.min(1, (f.life - t) / 0.5), glow = t < 0.05 ? 1 : Math.max(0, 1 - (t - 0.05) / 0.55);
  vDrawCracks(f.x, f.y, f.cr, grow, dark, glow, f.C);
};
FX2.vgslam = function (f) {
  var C = f.C, t = f.t, R = f.R;
  for (var j = 0; j < 2; j++) { // むらのある衝撃の輪：外の速い輪（細く明るい）と、内の遅い輪（太く暗い下地つき）
    var k = vEase((t - j * 0.07) / (j ? 0.75 : 0.5)); if (k <= 0 || k >= 1) continue; var r = (j ? 0.6 : 1) * R * k + 30, fd = 1 - k;
    ctx.globalCompositeOperation = 'source-over'; vRingN(f.x, f.y + 3, r * 0.98, (j ? 20 : 10) * (0.4 + fd), C.dark, (C.dk || 0.5) * fd, f.seed + j, 0.18);
    ctx.globalCompositeOperation = 'lighter'; vRingN(f.x, f.y, r, (j ? 16 : 9) * (0.4 + fd), C.glow, 0.85 * fd, f.seed + j, 0.18); vRingN(f.x, f.y - 1, r * 1.01, (j ? 4 : 3) * (0.5 + fd), C.core, fd, f.seed + j + 3, 0.3);
  }
  vDrawDust(f.x, f.y, f.dust, t, f.big ? 1.25 : 1);
  vDrawDebris(f.x, f.y, f.deb, t, f.life);
  if (t < 0.16) { var kk = 1 - t / 0.16; vGlow(f.x, f.y - 30, R * 0.35 * (0.6 + t * 4), C, kk); vStar4(f.x, f.y - 30, R * 0.4 * kk, 0.2, C.core, kk); }
};

/* ===== 渦をまとう溜め（ランカ）：足元の砂埃と光の粒が、体のまわりを渦を巻いて集まり、昇る。集まるほど濃く ===== */
function fxSwirl(a, C) {
  var q = []; for (var i = 0; i < 90; i++) q.push({ th: Math.random() * 6.283, r0: vR(0.45, 1.0), w: vR(2.2, 4.2), p: Math.random(), v: vR(0.45, 0.85), s: vR(1.6, 3.4), dust: i % 2 === 0, c: Math.floor(Math.random() * 3), gold: i % 4 === 1 });
  G.fx.push({ type: 'vswirl', a: a, at: a.atk, C: C, t: 0, life: 4, q: q });
}
function vSwirlOn(f) { var a = f.a; if (!a || a.atk !== f.at || f.done) { f.t = f.life; return false; } return true; }
FX2.vswirl = function (f) {
  if (!vSwirlOn(f)) return; var a = f.a, C = f.C, H = allyH(a), cx = a.x, fy = a.y, k = Math.min(1, f.t / 0.4), t = f.t;
  for (var i = 0; i < f.q.length; i++) {
    var q = f.q[i], p = (t * q.v + q.p) % 1, rr = H * q.r0 * (1 - 0.75 * p), th = q.th + t * q.w * (1 + p * 1.5), hy = H * 1.25 * p * p, x = cx + Math.cos(th) * rr, y = fy - hy + Math.sin(th) * rr * 0.3, front = Math.sin(th) > 0, al = Math.sin(p * Math.PI) * k;
    if (q.dust) { if (p > 0.7 || (!front && rr < H * 0.4)) continue; ctx.globalCompositeOperation = 'source-over'; vDustPuff(x, y - 6, (26 + 30 * (1 - p)) * (0.6 + q.r0 * 0.5), q.c % 2, 0.75 * Math.sin(p / 0.7 * Math.PI) * k); ctx.globalCompositeOperation = 'lighter'; continue; } // 砂埃：下で濃く、昇りながら細る（竜巻）
    if (!front && rr < H * 0.3) continue; // 体の後ろに回った粒は、体に重ねない
    var th0 = th - 0.25, x0 = cx + Math.cos(th0) * rr * 1.04, y0 = fy - hy + 8 + Math.sin(th0) * rr * 0.31; // 渦の向きへ伸ばす（光の筋）
    vStreak(x, y, x - x0, y - y0, Math.min(40, rr * 0.3) + 6, q.s * (0.7 + p), q.gold ? C.gold || C.spark : C.main, al * (0.5 + 0.5 * p));
  }
  for (var j = 0; j < 4; j++) { // 体のまわりを回る風の輪：高さ違いの傾いた楕円の弧。上ほど小さく速い（手前の半分を太く）
    var rx = H * (0.62 - 0.1 * j), ry = rx * 0.26, yy = fy - H * (0.08 + 0.3 * j), sp = 7 + j * 2.5, a0 = t * sp + j * 1.7, tilt = (j % 2 ? 0.12 : -0.1), pul = 0.55 + 0.45 * Math.sin(t * 9 + j);
    ctx.save(); ctx.translate(cx, yy); ctx.rotate(tilt); ctx.lineCap = 'round';
    ctx.strokeStyle = vrgba(C.glow, 0.45 * k * pul); ctx.lineWidth = 9; ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, a0, a0 + 2.6); ctx.stroke();
    ctx.strokeStyle = vrgba(j % 2 ? C.gold || C.spark : C.core, 0.9 * k * pul); ctx.lineWidth = 2.4; ctx.beginPath(); ctx.ellipse(0, 0, rx, ry, 0, a0 + 0.3, a0 + 2.4); ctx.stroke();
    ctx.restore();
  }
};
FX_UNDER.vswirl = function (f) { // 床：砂の渦の跡（回る腕。集まるほど濃い）
  if (!vSwirlOn(f)) return; var a = f.a, C = f.C, H = allyH(a), cx = a.x, fy = a.y, k = Math.min(1, f.t / 0.4), t = f.t;
  for (var arm = 0; arm < 3; arm++) for (var j = 0; j < 22; j++) {
    var u = j / 22, th = arm * 2.094 + t * 3 + u * 4.2, r = H * (1.15 - 0.85 * u), x = cx + Math.cos(th) * r, y = fy + Math.sin(th) * r * 0.28;
    ctx.globalCompositeOperation = 'source-over'; vPuff(x, y, 18 + 16 * (1 - u), VFX_DUST[1 + (arm + j) % 2], 0.6 * k * (0.4 + 0.6 * u));
    if (j % 3 === 0) { ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = vrgba(j % 2 ? C.main : C.gold || C.spark, 0.5 * k * u); ctx.beginPath(); ctx.arc(x, y - 2, 2.2, 0, 6.283); ctx.fill(); }
  }
  ctx.globalCompositeOperation = 'lighter';
};

/* ===== 疾風の跡（リリィの追星）：通った道に、渦を巻く風の線・巻き上がる砂埃・最後の踏み込みの地割れと岩片 ===== */
function fxWake(x0, x1, y, face, C) {
  var s = Math.random() * 100, du = [], L = Math.abs(x1 - x0);
  for (var i = 0; i < 34; i++) du.push({ u: Math.random(), up: vR(40, 160), dx: -face * vR(20, 110), r: vR(20, 42), d: vR(0, 0.1), life: vR(0.6, 1.1), c: Math.floor(Math.random() * 3) });
  G.fx.push({ type: 'vwake', x0: x0, x1: x1, y: y, face: face, C: C || VFX_STAR, t: 0, life: 1.2, du: du, seed: s, cr: vMakeCracks(6, 150, s), deb: vMakeDebris(18, 140, 420, s) });
}
FX_UNDER.vwake = function (f) { var b = f.t - 0.06; if (b <= 0) return; vDrawCracks(f.x1 + f.face * 20, f.y, f.cr, vEase(b / 0.1), Math.min(1, (f.life - f.t) / 0.4), Math.max(0, 1 - b / 0.45), f.C); };
FX2.vwake = function (f) {
  var C = f.C, t = f.t, head = vEase(t / 0.08), tail = vEase((t - 0.1) / 0.5), fade = 1 - Math.max(0, t - 0.35) / 0.4, i;
  // 渦を巻く風の線：進む向きの螺旋（奥と手前で太さが変わる）。2本を逆の位相で
  if (fade > 0) for (var s2 = 0; s2 < 2; s2++) {
    var N = 40, pts = []; for (i = 0; i <= N; i++) { var u = tail + (head - tail) * i / N, x = f.x0 + (f.x1 - f.x0) * u, ph = u * 14 + s2 * 3.14 - t * 20, amp = 46 * (0.4 + 0.6 * u); pts.push(x, f.y - 95 + Math.sin(ph) * amp, Math.cos(ph)); }
    for (i = 0; i + 1 <= N; i++) { var z = pts[i * 3 + 2], al = (i / N) * fade; if (al <= 0.02) continue;
      ctx.strokeStyle = vrgba(z > 0 ? C.core : C.main, (z > 0 ? 0.9 : 0.4) * al); ctx.lineWidth = z > 0 ? 3.2 : 1.6; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(pts[i * 3], pts[i * 3 + 1]); ctx.lineTo(pts[i * 3 + 3], pts[i * 3 + 4]); ctx.stroke(); }
  }
  for (i = 0; i < f.du.length; i++) { // 巻き上がる砂埃：通った所から遅れて昇り、後ろへ流れる
    var q = f.du[i], a = t - q.d - q.u * 0.08; if (a < 0 || a > q.life) continue; var dr = 1 - Math.exp(-a * 3);
    ctx.globalCompositeOperation = 'source-over'; vDustPuff(f.x0 + (f.x1 - f.x0) * q.u + q.dx * dr, f.y - 10 - q.up * dr, q.r * (0.6 + 1.4 * dr), q.c % 2, 0.62 * (1 - a / q.life) * Math.min(1, a / 0.05));
  }
  ctx.globalCompositeOperation = 'lighter';
  var b = t - 0.06; if (b > 0) { // 最後の踏み込み：むらのある輪と岩片
    var k = vEase(b / 0.45); if (k < 1) { ctx.globalCompositeOperation = 'source-over'; vRingN(f.x1 + f.face * 20, f.y + 3, 30 + 230 * k, 12 * (1 - k) + 2, C.dark, 0.45 * (1 - k), f.seed, 0.2); ctx.globalCompositeOperation = 'lighter'; vRingN(f.x1 + f.face * 20, f.y, 30 + 230 * k, 9 * (1 - k) + 1, C.glow, 0.8 * (1 - k), f.seed, 0.2); vRingN(f.x1 + f.face * 20, f.y - 1, 30 + 232 * k, 2.4, C.core, 0.9 * (1 - k), f.seed + 2, 0.3); }
    vDrawDebris(f.x1 + f.face * 20, f.y, f.deb, b, f.life - 0.06);
  }
};

// 床の層のエフェクト（draw.js の drawUnder から。キャラの足元の下に描く）
function drawGroundFx() {
  if (!G.fx) return; ctx.save(); ctx.globalCompositeOperation = 'lighter';
  for (var i = 0; i < G.fx.length; i++) { var f = G.fx[i]; if (FX_UNDER[f.type]) FX_UNDER[f.type](f); }
  ctx.restore();
}
