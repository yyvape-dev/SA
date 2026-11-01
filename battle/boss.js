// 敵将の大技（2026-11-01）。jguard.js の次に読む。敵将（e.boss）は通常の攻撃に加えて、数秒おきに大技を出す。
//   大振り（heavy）：長い溜め＋床に危ない範囲が満ちる → 広い一撃と床割れ。ジャストガードで受けると大きく崩れる（jguard.js）。
//   三連撃（combo）：攻撃の絵を3回続けて流す。3発目は溜めが長く、重い。
//   突進（charge）：ガード不可（紫の帯と「ガード不可」）。回避で抜けるしかない。走り終えた後の硬直が反撃の好機。
//   e.atk に mv を付け、段（seg）ごとに starts・hitT・endT を作り直す（draw.js の drawFoe はそのまま段の絵を流す）。jguard.js は ak.hitT・ak.done・ak.rx を見る。
'use strict';
var BOSS = { cd0: 2.5, cd: [4.5, 6.5] };
var VFX_NOJG = { glow: '190,40,255', main: '230,130,255', core: '255,235,255', spark: '240,170,255', dark: '30,0,45' }; // ガード不可（紫）
// 攻撃の絵 ci を、当たりまでを pre 倍・当たりの後を post 倍の速さで流す段
function bmSeg(e, ci, pre, post, o) {
  var c = (FOE_CLIP[e.kind] || [])[ci], s = { ci: ci, starts: [], hitT: 0.4 * pre, endT: 0.4 * pre + 0.3 * post };
  if (c) { var acc = 0; for (var i = 0; i < c.n; i++) { s.starts.push(acc); if (i === c.hit) s.hitT = acc; acc += c.durs[i] / 1000 / FOE_SPD * (i < c.hit ? pre : post); } s.endT = acc; }
  for (var k in o) s[k] = o[k];
  return s;
}
function bmClipN(e) { return Math.max(1, (FOE_CLIP[e.kind] || []).length); }
// 歩きの中から呼ぶ（update.js）。大技を出したら true
function bossPick(e, dx, dy, dt) {
  if (e.bmCD == null) e.bmCD = BOSS.cd0;
  e.bmCD -= dt; if (e.bmCD > 0 || G.state !== 'play') return false;
  var ax = Math.abs(dx), n = bmClipN(e), mv;
  var onS = e.x > camX + 60 && e.x < camX + W - 60;
  if (ax > 240 && ax < 560 && onS) mv = 'charge';
  else if (ax < 230 && Math.abs(dy) < 70) mv = Math.random() < 0.5 ? 'heavy' : 'combo';
  else return false;
  e.bmCD = BOSS.cd[0] + Math.random() * (BOSS.cd[1] - BOSS.cd[0]); e.face = dx >= 0 ? 1 : -1;
  var segs;
  if (mv === 'heavy') segs = [bmSeg(e, n > 1 ? 1 : 0, 1, 1.4, { rx: 330, ry: 85, mul: 2.2, wind: 0.95 })];
  else if (mv === 'combo') segs = [bmSeg(e, 0, 0.85, 0.45, { rx: 190, ry: 50, mul: 0.8, cut: 0.14 }), bmSeg(e, n > 1 ? 1 : 0, 0.75, 0.45, { rx: 190, ry: 50, mul: 0.8, cut: 0.14, step: 45 }), bmSeg(e, 0, 1.7, 1.2, { rx: 220, ry: 55, mul: 1.6, step: 55 })];
  else segs = [{ ci: 0, charge: 1, nojg: 1, tele: 0.75, dash: 0.42, rec: 0.6, dist: Math.min(640, ax + 180), mul: 1.8 }];
  e.atk = { mv: mv, segs: segs, si: -1, t: 0, done: true }; bmNext(e);
  return true;
}
function bmNext(e) {
  var ak = e.atk; ak.si++; var s = ak.segs[ak.si]; if (!s) { e.atk = null; return; }
  ak.t = 0; ak.done = false; ak.ci = s.ci; ak.rx = s.rx; ak.ry = s.ry; ak.nojg = s.nojg;
  if (s.step) e.x += e.face * s.step;
  if (s.charge) { // 突進：構え（0コマ目を保つ）→ 走る（当たりのコマを保つ）→ 硬直
    var c = (FOE_CLIP[e.kind] || [])[0], hf = c ? c.hit : 1, st = []; for (var i = 0; c && i < c.n; i++) st.push(i < hf ? s.tele * 0.9 + i * 0.01 : i === hf ? s.tele : s.tele + s.dash + (i - hf) * 0.06);
    ak.starts = st; ak.hitT = 1e9; ak.endT = s.tele + s.dash + s.rec; ak.x0 = e.x; ak.y0 = e.y;
    fxBossTele(e, s); addText(clamp(e.x, camX + 90, camX + W - 90), e.y - eh(e) - 40, 'ガード不可', 26, '#e6a0ff', 1.0); return;
  }
  if (s.wind) { // 大振り：溜めを伸ばす（当たりの前のコマを wind 秒に引き延ばす）
    var k = s.wind / Math.max(0.05, s.hitT); s.starts = s.starts.map(function (v) { return v <= s.hitT ? v * k : v - s.hitT + s.wind; }); s.endT = s.endT - s.hitT + s.wind; s.hitT = s.wind;
  }
  ak.starts = s.starts; ak.hitT = s.hitT; ak.endT = s.cut ? s.hitT + s.cut : s.endT;
  if (s.wind) fxBossZone(e, s); else fxWarn(e, s.hitT);
  fxFoeAtk(e, s.hitT);
}
// 毎コマ（update.js の e.atk の処理の代わり）
function bossMoveTick(e, dt) {
  var ak = e.atk, s = ak.segs[ak.si], h = G.hero; ak.t += dt;
  if (s.charge) {
    var u = (ak.t - s.tele) / s.dash;
    if (u >= 0 && u <= 1) {
      if (!ak.go) { ak.go = 1; G.shake = Math.max(G.shake, 6); fxBossDash(e, s); }
      var px = e.x; e.x = clamp(ak.x0 + e.face * s.dist * vEase(u), LK(G.seg) + 40, LK(G.seg) + W - 40);
      if (!ak.done && Math.abs(h.x - e.x) < 80 + Math.abs(e.x - px) && Math.abs(h.y - e.y) < 46 && bmCanHit(h)) { ak.done = true; hitHero(e, s.mul); h.kb = e.face * 520; }
    }
  } else if (!ak.done && ak.t >= ak.hitT) {
    ak.done = true; var dx = (h.x - e.x) * e.face;
    if (dx > -50 && dx < s.rx && Math.abs(h.y - e.y) < s.ry && bmCanHit(h)) hitHero(e, s.mul);
    if (s.wind) { fxGroundSlam(e.x + e.face * 150, e.y + 4, 520, VFX_FOE_S, true); G.fx[G.fx.length - 1].thin = 1; G.shake = Math.max(G.shake, 14); G.freeze = Math.max(G.freeze, 0.05); }
    else if (ak.si === ak.segs.length - 1) G.shake = Math.max(G.shake, 8);
  }
  if (e.atk === ak && ak.t >= ak.endT) bmNext(e);
}
function bmCanHit(h) { return h.inv <= 0 && h.state !== 'dodge' && G.state === 'play' && !(h.state === 'atk' && (h.kind === 'ult' || (h.kind === 'thr' && h.t < THR.safe))); }

/* ===== 効果 ===== */
// 大振りの床：前の扇が赤く満ちていき、満ちきった瞬間に振り下ろす
function fxBossZone(e, s) { G.fx.push({ type: 'vbzone', e: e, at: e.atk, si: e.atk.si, t: 0, life: s.wind + 0.12, hit: s.wind, rx: s.rx, ry: s.ry, face: e.face, x: e.x, y: e.y, C: VFX_FOE }); }
// 突進の床：走る道に紫の帯（ガード不可）
function fxBossTele(e, s) { G.fx.push({ type: 'vbzone', e: e, at: e.atk, si: e.atk.si, t: 0, life: s.tele + 0.1, hit: s.tele, lane: s.dist + 90, ry: 46, face: e.face, x: e.x, y: e.y, C: VFX_NOJG }); }
FX2.vbzone = function () {};
FX_UNDER.vbzone = function (f) {
  var e = f.e; if (!e || e.atk !== f.at || e.atk.si !== f.si || f.t > f.hit + 0.1) return;
  var C = f.C, k = Math.min(1, f.t / f.hit), pul = 0.75 + 0.25 * Math.sin(f.t * 30), ga = vEase(f.t / 0.12);
  ctx.save(); ctx.translate(f.x, f.y); ctx.scale(f.face, 1);
  if (f.lane) { // 帯：枠は最初から、中身が手前から先へ満ちる
    var L = f.lane, R = f.ry;
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.35 * ga); ctx.fillRect(0, -R, L, R * 2);
    ctx.globalCompositeOperation = 'lighter';
    var g = ctx.createLinearGradient(0, 0, L * k, 0); g.addColorStop(0, vrgba(C.glow, 0.08)); g.addColorStop(1, vrgba(C.glow, 0.35 * pul)); ctx.fillStyle = g; ctx.fillRect(0, -R, L * k, R * 2);
    ctx.strokeStyle = vrgba(C.main, 0.75 * ga * pul); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(0, -R); ctx.lineTo(L, -R); ctx.lineTo(L, R); ctx.lineTo(0, R); ctx.closePath(); ctx.stroke();
    for (var i = 0; i < 6; i++) { var ax = ((f.t * 1.6 + i / 6) % 1) * L; ctx.strokeStyle = vrgba(C.core, 0.5 * ga); ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(ax - 14, -R * 0.6); ctx.lineTo(ax + 6, 0); ctx.lineTo(ax - 14, R * 0.6); ctx.stroke(); } // 向きの矢じり
  } else { // 扇（床の半楕円）：中心から外へ満ちる
    var cx = (f.rx - 50) / 2, rx = (f.rx + 50) / 2, ry = f.ry; // 当たりの範囲（前 -50〜rx）を覆う楕円。満ちるのは敵の足元から前へ
    ctx.globalCompositeOperation = 'source-over'; ctx.fillStyle = vrgba(C.dark, 0.28 * ga); ctx.beginPath(); ctx.ellipse(cx, 0, rx, ry, 0, 0, 6.283); ctx.fill();
    ctx.globalCompositeOperation = 'lighter';
    var g2 = ctx.createRadialGradient(cx, 0, 0, cx, 0, rx); g2.addColorStop(0, vrgba(C.glow, (0.06 + 0.22 * k * k) * pul)); g2.addColorStop(Math.max(0.01, k * 0.95), vrgba(C.glow, (0.1 + 0.2 * k) * pul)); g2.addColorStop(Math.min(1, k * 0.95 + 0.05), vrgba(C.glow, 0));
    ctx.save(); ctx.translate(cx, 0); ctx.scale(1, ry / rx); ctx.fillStyle = g2; ctx.beginPath(); ctx.arc(0, 0, rx, 0, 6.283); ctx.fill(); ctx.restore();
    ctx.strokeStyle = vrgba(C.main, 0.75 * ga * pul); ctx.lineWidth = 2.5; ctx.beginPath(); ctx.ellipse(cx, 0, rx, ry, 0, 0, 6.283); ctx.stroke(); // 外の縁
    ctx.strokeStyle = vrgba(C.core, 0.7 * k); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.ellipse(cx, 0, rx * k, ry * k, 0, 0, 6.283); ctx.stroke();
  }
  ctx.restore();
};
// 溜めの光：敵将の体に集まる（大振り＝赤、突進＝紫）。fx の vbzone と同じ時間
FX2.vbaura = function () {};
// 突進：走る間の残像の筋と砂埃
function fxBossDash(e, s) { G.fx.push({ type: 'vbdash', e: e, at: e.atk, t: 0, life: s.dash + 0.45, dash: s.dash, face: e.face, du: vMakeDust(18, 120, Math.random() * 99) , pts: [] }); }
FX2.vbdash = function (f) {
  var e = f.e, C = VFX_NOJG; if (!e) return;
  if (f.t <= f.dash && e.atk === f.at) f.pts.push({ x: e.x, y: e.y, t: f.t });
  var H = eh(e);
  for (var i = 0; i < f.pts.length; i++) { // 走った跡：横に流れる紫の筋（古いほど薄い）
    var p = f.pts[i], a = Math.max(0, 1 - (f.t - p.t) / 0.35); if (a <= 0) continue;
    for (var j = 0; j < 4; j++) vStreak(p.x, p.y - H * (0.2 + j * 0.2), -f.face, 0, 60 + j * 20, 2.2 - j * 0.3, j % 2 ? C.main : C.glow, a * 0.6);
  }
  if (f.pts.length) { var q = f.pts[f.pts.length - 1]; if (f.t <= f.dash) vGlow(q.x + f.face * 40, q.y - H * 0.5, H * 0.5, C, 0.5); vDrawDust(f.pts[0].x, f.pts[0].y, f.du, f.t, 0.8); }
};
