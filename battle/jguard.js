// ジャストガード（2026-11-01）：敵の当たりの直前（構えの後半7割。jgWin）に回避を押すと、受け止めて自動で反撃する。fx4.js の次に読む。
//   成功：その攻撃は当たらない・相手に強い反撃（大きくひるむ）・一瞬のスロー・回避の再使用がすぐ戻る・必殺の残りを JG.ult 秒縮める。
//   外れ（間合いの中に当たりの近い敵がいない）：今までどおりの回避。合図は敵の予兆の赤いきらめき（fx4.js の vfwind）。
'use strict';
var JG = { win: 0.7, winMin: 0.15, winMax: 0.32, dmg: 30, ult: 3, inv: 0.6, slow: 0.25, slowT: 0.28, backT: 0.18 };
// 受付の幅：構え（攻撃の始まり→当たり）の後半7割。最短0.15秒・最長0.32秒（速い攻撃だけ極端に楽、遅い攻撃は押すだけ、にならないように）
function jgWin(ak) { return Math.max(JG.winMin, Math.min(JG.winMax, ak.hitT * JG.win)); }
function jgTargets() {
  var h = G.hero, out = [];
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i], ak = e.atk; if (!ak || ak.done || ak.nojg || e.state !== 'walk' || e.stun > 0 || e.bind > 0) continue;
    var left = ak.hitT - ak.t; if (left < 0 || left > jgWin(ak)) continue;
    if (Math.abs(h.x - e.x) < (ak.rx ? ak.rx + 20 : 115 * e.size) && Math.abs(h.y - e.y) < (ak.ry ? ak.ry + 8 : 44)) out.push(e); // 大技は技の範囲（battle/boss.js） // 当たりの判定（update.js）より少し広く
  }
  return out;
}
function tryJustGuard() {
  if (G.state !== 'play') return false;
  var T = jgTargets(); if (!T.length) return false;
  var h = G.hero, near = T[0];
  T.forEach(function (e) { if (Math.abs(e.x - h.x) < Math.abs(near.x - h.x)) near = e; });
  h.face = near.x >= h.x ? 1 : -1;
  var cx = h.x + h.face * 55, cy = h.y - 120 * depthScale(h.y);
  var brk = T.some(function (e) { return e.atk.mv === 'heavy' || (e.atk.mv === 'combo' && e.atk.si === e.atk.segs.length - 1); }); // 大技の重い一撃を受けた＝崩し
  T.forEach(function (e) {
    var big = e.atk.mv === 'heavy' || (e.atk.mv === 'combo' && e.atk.si === e.atk.segs.length - 1);
    e.atk.done = true; var dir = e.x >= h.x ? 1 : -1;
    e.atk = null; hurt(e, JG.dmg * S.dmg * (0.9 + Math.random() * 0.2) * (big ? 2 : 1), dir, true); // 大技は先に止めてから（スーパーアーマーを外す）
    if (e.hp > 0) { e.stun = Math.max(e.stun, big ? 1.6 : e.boss ? 0.55 : e.elite ? 0.8 : 1.0); e.kx = dir * (e.boss ? 160 : 420); }
  });
  h.inv = Math.max(h.inv, JG.inv); h.buf = 0; h.lastAtkKind = null;
  if (h.state !== 'atk' || h.kind !== 'ult') beginAttack('atk'); // 反撃の振り（通常の斬り下ろし。当たりもそのまま入る）
  G.dodgeCD = 0; G.ultCD = Math.max(0, G.ultCD - JG.ult);
  G.jg = { t: 0 }; G.freeze = Math.max(G.freeze, 0.06); G.shake = Math.max(G.shake, 9); G.flash = 0.16; G.flashRGB = '255,240,210';
  fxJustGuard(cx, cy, h.face, h.y);
  addText(h.x, h.y - 270, 'JUST GUARD', 30, '#ffe28a', 0.9);
  if (brk) { addText(near.x, near.y - eh(near) - 40, '崩し', 34, '#ffd27a', 1.1); G.shake = Math.max(G.shake, 14); fxRing(near.x, near.y, 520, 0.6, VFX_GOLD); }
  if (G.ultCD > 0) addText(h.x, h.y - 238, '必殺 -' + JG.ult + '秒', 18, '#ffb3b3', 0.8);
  G.jgN = (G.jgN || 0) + 1;
  return true;
}
// スロー（実時間で進める。loop.js が update の dt に掛ける）
function jgTick(rdt) {
  var j = G.jg; if (!j) return 1;
  if (G.state !== 'play') { G.jg = null; return 1; }
  j.t += rdt; if (j.t >= JG.slowT + JG.backT) { G.jg = null; return 1; }
  return j.t < JG.slowT ? JG.slow : JG.slow + (1 - JG.slow) * vEase((j.t - JG.slowT) / JG.backT);
}
