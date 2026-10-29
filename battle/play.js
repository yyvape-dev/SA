// 月夜の回廊（縦画面版）：進行と技（戦場・敵の出現・攻撃・吸引・必殺・突き・被弾）。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* ---------- 進行 ---------- */
var fsTried = false;
function tryFs() { // 最初の操作で全画面と横向き固定を試す（対応していない端末では何も起きない）
  if (fsTried || !TOUCH) return; fsTried = true;
  try { var st = document.getElementById('stage'); if (!document.fullscreenElement && st.requestFullscreen) st.requestFullscreen().then(function () { try { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('portrait').catch(function () {}); } catch (e) {} }).catch(function () {}); } catch (e) {}
}
function startRun() {
  tryFs(); G.state = 'play'; G.t = 0;
  if (BAT.on && !G.batApplied) { G.batApplied = true; S.dmg *= BAT.dmg; S.bind += BAT.bind; G.hero.max += BAT.hp; G.hero.hp = G.hero.max; }
  enterRoom(0);
  var kz = document.getElementById('keys'), nt = document.getElementById('loadnote'); // 操作の説明と読み込みの表示は、始めたらしまう
  if (nt && nt.style) nt.style.display = 'none';
  if (kz && kz.style) setTimeout(function () { kz.style.opacity = '0'; }, 7000);
}

function startWave(n) {
  G.wave = n; G.queue = []; G.qT = 0;
  var count = Math.min(70, 10 + n * 6);
  count = Math.min(28, 6 + n * 4); // 2026-10-30 敵を速くしたぶん、数は約3割減（以前 min(40, 8+5n)）
  /* 3段の構成（2026-10-30）：前半＝雑兵／JOIN() の戦場から＝仲間が参入、強敵が混じる／最後の戦場＝敵将＋雑兵 */
  var last = G.seg >= ROOM.segs - 1, mid = G.seg >= JOIN();
  if (last) count = Math.round(count * 0.6);
  for (var i = 0; i < count; i++) G.queue.push({ at: rnd(0, last ? 7 : 4.5), elite: false });
  if (last) G.queue.push({ at: 1.2, elite: true, boss: true });
  else if (mid) { G.queue.push({ at: 2.5, elite: true }); if (G.seg >= ROOM.segs - 2) G.queue.push({ at: 4.5, elite: true }); }
  if (G.seg === JOIN()) allyJoin();
  G.fieldTotal = Math.max(1, G.queue.length); G.queue.sort(function (a, b) { return a.at - b.at; }); // 波の表示は出さない（倒しきったら、戦場が右へ進む）
}
// 部屋に入る：戦場0に立ち、カメラをその位置へ合わせて、最初の波を始める
function enterRoom(i) {
  G.roomNo = i; ROOM = ROOMS[i % ROOMS.length]; setRoomVars();
  G.seg = 0; G.phase = 'fight'; G.enemies = []; G.drops = []; G.parts = []; G.fx = []; G.texts = []; G.booms = []; G.queue = []; G.starfall = null;
  var h = G.hero; h.x = LK(0) + Math.round(W * 0.28); h.face = 1; h.y = Math.round((LANE_Y0 + LANE_Y1) / 2); h.state = 'idle'; h.t = 0; h.buf = 0; h.inv = 0;
  updateCam(0, true); startWave(G.wave + 1);
}
function beginTrans() { if (!G.trans) G.trans = { t: 0, sw: false }; } // 暗転→次の部屋→明転

function foeKindPick() { // 横向きの歩きの絵がある種類だけ出す（槍兵は歩きの絵が無いので外す。絵が届けば自動で戻る）
  var ks = [1, 3, 4].filter(function (k) { return FOE_SW[k]; }); if (!ks.length) ks = [1, 3, 4];
  return ks[Math.floor(Math.random() * ks.length)];
}
function spawn(q) {
  var n = G.wave, cl = LK(G.seg); // 敵は右の外からだけ来る
  var e = {
    x: cl + W + rnd(50, 170), y: rnd(LANE_Y0, LANE_Y1), yo: rnd(-1, 1) * (ROOM.spread || 20), face: -1,
    kind: q.elite ? 2 : foeKindPick(), atk: null,
    size: q.elite ? 1.12 : rnd(0.94, 1.06), elite: q.elite,
    max: (22 + n * 5) * (q.elite ? 10 : 1), hp: 0, sp: (135 + rnd(0, 45) + n * 4) * (q.elite ? 0.8 : 1), /* 2026-10-30 速く（以前 78+0〜40+3n） */
    state: 'walk', t: rnd(0, 6), atkCD: rnd(0.05, 0.35), bind: 0, /* bind を 0 で持たないと「拘束でない」の判定が外れ、歩きの絵が出なかった */ stun: 0, kx: 0, flash: 0, dt: 0, dmg: 7 + n * (q.elite ? 2 : 1)
  };
  if (q.boss) { // 敵将：大きく硬い。引き寄せと拘束はほとんど効かない（e.boss）。HPは上の帯に出す
    e.boss = true; e.size = 1.38; e.max = (22 + n * 5) * 42; e.sp *= 0.75; e.dmg = 10 + n * 3; e.x = cl + W + 60; e.y = (LANE_Y0 + LANE_Y1) / 2;
    G.boss = e; fxBossIn(e); addText(cl + W * 0.5, LANE_Y0 - 60, BAT.boss ? '将軍 出陣！' : '敵将 出現！', 46, '#ff8a7a', 1.6); G.shake = Math.max(G.shake, 8);
  }
  e.hp = e.max; G.enemies.push(e);
}

// kind: 'atk'（通常）/ 'sk'（衝撃波）/ 'pull'（吸引）
function tryAttack(kind) {
  if (G.state !== 'play' || G.trans) return;
  var h = G.hero;
  if (h.state === 'atk' && h.kind === 'ult') return; // 必殺技の最中は、入力を受けない
  if (kind === 'dodge') { tryDodge(); return; }
  if (kind === 'ult' && G.ultCD > 0) { addText(h.x, h.y - 250, '必殺 再使用まで ' + G.ultCD.toFixed(1) + '秒', 20, '#ffb3b3', 0.7); return; }
  if (kind === 'thr' && G.thrCD > 0) { addText(h.x, h.y - 250, '突き 再使用まで ' + G.thrCD.toFixed(1) + '秒', 20, '#a8dcff', 0.7); return; }
  if (kind === 'sk' && G.skCD > 0) { addText(h.x, h.y - 250, '再使用まで ' + G.skCD.toFixed(1) + '秒', 20, '#9aa0ff', 0.7); return; }
  if (kind === 'pull' && G.pullCD > 0) { addText(h.x, h.y - 250, '吸引 再使用まで ' + G.pullCD.toFixed(1) + '秒', 20, '#b7a6ff', 0.7); return; }
  if (h.state === 'hurt' || (h.state === 'atk' && h.t < h.cancelT)) { h.buf = kind; return; }
  beginAttack(kind);
}
function beginAttack(kind) {
  var h = G.hero, a = S.aspd;
  // 通常攻撃の連打：直前の攻撃から0.5秒以内なら、縦斬り(A)→横薙ぎ(B)→縦斬り…と順に出る
  var recent = h.lastAtkKind === 'atk' && G.t - h.lastAtkEnd < 0.5;
  h.v = (kind === 'atk' && recent && h.v === 0) ? 1 : 0; h.lastAtkKind = kind; h.lastAtkEnd = G.t;
  h.state = 'atk'; h.t = 0; h.kind = kind; h.sk = kind === 'sk'; h.h1 = h.h2 = h.h3 = false; h.buf = 0;
  // 吸引は、引いた直後に次の技へつなげられるよう、キャンセル可能になる時点を早める
  h.cancelT = kind === 'pull' ? (10 / 48 + 0.14) / a : (10 / 48 + 9 / 32 + 5 / 48) / a;
  h.total = (10 / 48 + 9 / 32 + 17 / 48) / a;
  if (kind === 'atk' && h.v === 1) { h.cancelT = ATB.cancel / a; h.total = ATB.total / a; }
  if (kind === 'atk' && h.v === 0) { h.cancelT = ATC.cancel / a; h.total = ATC.total / a; }
  if (kind === 'thr') { h.cancelT = THR.cancel; h.total = THR.total; h.x0 = h.x; h.fxT = 0; G.thrCD = G.thrMax; }
  if (kind === 'sk') G.skCD = G.skMax * S.cd;
  if (kind === 'pull') G.pullCD = G.pullMax * S.pcd;
  if (kind === 'ult') { h.cancelT = ULT.total; h.total = ULT.total; h.fxT = 0; h.ringT = 0; G.ultCD = G.ultMax; }
}
/* 回避：入力の向き（なければ向いている方）へ短く踏み込む。最中は無敵。攻撃の途中・のけぞりの途中でも出せる（必殺技の最中は除く）
   絵は走りのコマ＋残像（専用の絵は無い）。DODGE.dist＝進む距離、dur＝長さ、inv＝無敵の長さ（踏み込みより少し長い） */
var DODGE = { dist: 250, dur: 0.24, inv: 0.32 };
function tryDodge() {
  var h = G.hero;
  if (G.dodgeCD > 0) { addText(h.x, h.y - 250, '回避 再使用まで ' + G.dodgeCD.toFixed(1) + '秒', 20, '#a8dcff', 0.7); return; }
  var ax = (keys.ArrowRight || keys.KeyD ? 1 : 0) - (keys.ArrowLeft || keys.KeyA ? 1 : 0) + pad.x;
  var ay = (keys.ArrowDown || keys.KeyS ? 1 : 0) - (keys.ArrowUp || keys.KeyW ? 1 : 0) + pad.y, m = Math.hypot(ax, ay);
  if (m < 0.25) { ax = h.face; ay = 0; m = 1; }
  h.dx = ax / m; h.dy = ay / m * 0.7; // 奥行きは短め（帯が浅いので）
  if (Math.abs(h.dx) > 0.2) h.face = h.dx > 0 ? 1 : -1;
  h.state = 'dodge'; h.t = 0; h.buf = 0; h.kb = 0; h.dsx = h.x; h.dsy = h.y; h.trail = []; h.trT = 0; h.anim = 0;
  G.dodgeCD = G.dodgeMax;
  for (var i = 0; i < 8; i++) G.parts.push({ x: h.x + rnd(-30, 30), y: h.y - rnd(0, 20), vx: -h.dx * rnd(80, 220), vy: -rnd(20, 90), g: 300, life: rnd(0.25, 0.45), t: 0, c: '#d8c9a3', s: rnd(3, 6) }); // 足元の土ぼこり
}
function dodgeTick(h, dt) {
  h.t += dt; h.anim += dt * 40;
  var k = clamp(h.t / DODGE.dur, 0, 1), e = 1 - Math.pow(1 - k, 3);
  h.x = clamp(h.dsx + h.dx * DODGE.dist * e, heroMinX(), heroMaxX()); h.y = clamp(h.dsy + h.dy * DODGE.dist * e, LANE_Y0, LANE_Y1);
  h.trT -= dt; if (h.trT <= 0 && h.t < DODGE.dur) { h.trT = 0.035; h.trail.push({ x: h.x, y: h.y, f: Math.floor(h.anim) % 10, face: h.face, t: 0 }); }
  if (h.t >= DODGE.dur) { h.state = 'idle'; h.anim = 0; h.inv = Math.max(h.inv, DODGE.inv - DODGE.dur); }
}
// 被弾：のけぞり(0.08秒)→大きくのけぞる(0.10)→踏ん張る(0.10)→立ち直る(0.08)。攻撃中は、のけぞらない（一掃の流れを止めない）。のけぞり中の入力は、先行入力として受け、終わったら出す
var HURT = { cut: [0, 0.08, 0.18, 0.28], total: 0.36 };
function hurtFrame(t) { var i = 0; while (i + 1 < HURT.cut.length && HURT.cut[i + 1] <= t) i++; return i; }
// 必殺技：回転斬り。溜め→一瞬止める→斬る(当たり)→振り抜き→戻り。動画の3秒を、約1.5秒に詰める
var ULT = { charge: 0.75, tame: 0.15, slash: 0.10, post: 0.22, ret: 0.30 };
ULT.hit = ULT.charge + ULT.tame + ULT.slash; ULT.total = ULT.hit + ULT.post + ULT.ret;
function ultFrame(t) {
  var f;
  if (t < ULT.charge) f = 8 + 32 * (t / ULT.charge);
  else if (t < ULT.charge + ULT.tame) f = 40;
  else if (t < ULT.hit) f = 40 + 7 * ((t - ULT.charge - ULT.tame) / ULT.slash);
  else if (t < ULT.hit + ULT.post) f = 47 + 9 * ((t - ULT.hit) / ULT.post);
  else f = 56 + 10 * Math.min(1, (t - ULT.hit - ULT.post) / ULT.ret);
  return Math.max(0, Math.min(58, Math.floor(f) - ULT_F0));
}
function ultTick(h, dt) {
  var t = h.t;
  if (t < ULT.hit) { // 溜め：気が集まる。ためている間は、光の粒が増える
    var k = t / ULT.hit;
    h.fxT -= dt;
    if (h.fxT <= 0) {
      h.fxT = 0.04;
      for (var i = 0; i < 2 + Math.floor(k * 3); i++) G.parts.push({ x: h.x + rnd(-80, 80), y: h.y - rnd(0, 230), vx: rnd(-20, 20), vy: -rnd(80, 240), g: 0, life: rnd(0.4, 0.8), t: 0, c: i % 2 ? '#ff9a6a' : '#ffe2a0', s: rnd(3, 7) });
    }
    h.ringT -= dt;
    if (h.ringT <= 0) { h.ringT = 0.28; G.fx.push({ type: 'vsuck', x: h.x, y: h.y, t: 0, life: 0.45 }); }
    if (t > ULT.charge) G.shake = Math.max(G.shake, 2.5); // 止めている間の、ためた震え
  }
  if (!h.h1 && t >= ULT.hit) { h.h1 = true; doUlt(h); }
  if (t >= ULT.total) h.state = 'idle';
}
// 範囲：左右それぞれ540px（回転斬りなので、背中側も当たる）。吸引で集めておくと、遠い敵も一緒に入る
function doUlt(h) {
  var R = 540 * S.range, hits = 0, dmg = 150 * S.dmg, i;
  for (i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i];
    if (e.state !== 'walk' || Math.abs(e.x - h.x) > R) continue;
    hurt(e, dmg * (0.9 + Math.random() * 0.2), e.x >= h.x ? 1 : -1, true); hits++;
  }
  var sf = -h.face; // 動画の振り抜きは、立ち姿の向きと逆へ出る（剣の見える側）
  // 必殺：巨大な三日月（赤黒・金）を前後に、床の衝撃の輪（battle/fx.js）
  fxArc(h, sf, R, 0.6, true, false, VFX_RANA, { rx: 720, ry: 280, a0: 1.25, a1: -1.55, w: 120, ox: 40, oy: -130, sw: 150 });
  fxArc(h, -sf, R, 0.5, true, false, VFX_RANA, { rx: 460, ry: 180, a0: 1.2, a1: -1.4, w: 70, ox: 40, oy: -130, sw: 130 });
  G.fx.push({ type: 'vshock', x: h.x, y: h.y, dir: 1, t: 0, life: 0.6, rana: true });
  G.fx.push({ type: 'vshock', x: h.x, y: h.y, dir: -1, t: 0, life: 0.6, rana: true });
  fxRing(h.x, h.y, R * 1.15, 0.7);
  G.flash = 0.38; G.flashRGB = '255,205,160'; /* 白い全面の光は弱め・暖色に（紅の三日月が見えなくなるため） */
  G.freeze = Math.max(G.freeze, 0.14 + Math.min(hits, 14) * 0.006);
  G.shake = Math.max(G.shake, 22 + Math.min(hits, 14) * 1.2);
  for (i = 0; i < 40; i++) { var dr = i % 2 ? 1 : -1; G.parts.push({ x: h.x + dr * rnd(40, 400), y: h.y - rnd(0, 30), vx: dr * rnd(80, 520), vy: -rnd(120, 520), g: 900, life: rnd(0.4, 0.9), t: 0, c: i % 3 ? '#d9d2bd' : '#ffc76a', s: rnd(3, 8) }); }
  addText(h.x, h.y - 280, '必殺！', 58, '#ffe9a8', 1.0);
  if (hits) addText(h.x, h.y - 340, hits + '体 撃破', 30, '#ffb3b3', 1.0);
}
// 攻撃B：横薙ぎ。元動画のコマ番号ごとの再生時間(ms)。当たりは、前方(コマ28)→背面(コマ30)→頭上からの払い・背面(コマ55)
var ATB_SRC = [], ATB_T = [], ATB = {}, i0;
for (i0 = 12; i0 <= 37; i0++) ATB_SRC.push(i0);
for (i0 = 50; i0 <= 72; i0++) ATB_SRC.push(i0);
function atbMs(s) { return s <= 18 ? 25 : s <= 26 ? 22 : s === 27 ? 30 : s === 28 ? 35 : s === 29 ? 25 : s === 30 ? 30 : s <= 37 ? 30 : s <= 53 ? 35 : s <= 55 ? 30 : s === 56 ? 35 : 34; }
(function () {
  var t = 0;
  for (var i = 0; i < ATB_SRC.length; i++) { ATB_T.push(t); t += atbMs(ATB_SRC[i]) / 1000; }
  ATB.total = t; ATB.h1 = ATB_T[ATB_SRC.indexOf(28)]; ATB.h2 = ATB_T[ATB_SRC.indexOf(30)]; ATB.h3 = ATB_T[ATB_SRC.indexOf(55)]; ATB.cancel = ATB.h3 + 0.14;
})();
// 攻撃A：縦斬り。頭上へ振りかぶる→前へ斬り下ろす(コマ18、前方)→低く構えたまま→左へ払う(コマ42、背面)→戻る
var ATC_SRC = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 22, 26, 30, 34, 36, 37, 38, 39, 40, 41, 42, 44, 48, 52, 53, 54, 55, 56, 57, 58, 59, 60];
var ATC_T = [], ATC = {};
function atcMs(s) { return s <= 11 ? 30 : s <= 16 ? 25 : s === 17 ? 20 : s === 18 ? 40 : (s === 22 || s === 26 || s === 34) ? 0 : s <= 36 ? 30 : s <= 41 ? 25 : s <= 52 ? 40 : 35; } // 低い構えの静止は、3コマだけ残して詰める（時間0のコマは飛ばす）
(function () {
  var t = 0;
  for (var i = 0; i < ATC_SRC.length; i++) { ATC_T.push(t); t += atcMs(ATC_SRC[i]) / 1000; }
  ATC.total = t; ATC.h1 = ATC_T[ATC_SRC.indexOf(18)]; ATC.h2 = ATC_T[ATC_SRC.indexOf(42)]; ATC.cancel = ATC.h2 + 0.12;
})();
function atcTick(h) {
  var tt = h.t * S.aspd;
  if (!h.h1 && tt >= ATC.h1) { h.h1 = true; doHitC(1); }
  if (!h.h2 && tt >= ATC.h2) { h.h2 = true; doHitC(2); }
}
function doHitC(n) { // 1：前方への斬り下ろし 2：背面への払い（ダメージは従来の20・13）
  var h = G.hero, side = n === 1 ? 1 : -1, R = (n === 1 ? 340 : 300) * S.range, lane = 72 * ZK, hits = 0, dmg = (n === 1 ? 20 : 13) * S.dmg;
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (e.state !== 'walk') continue;
    var dx = (e.x - h.x) * h.face * side, dy = Math.abs(e.y - h.y);
    if (dx > -50 && dx < R && dy < lane) { hurt(e, dmg * (0.9 + Math.random() * 0.2), e.x >= h.x ? 1 : -1, false); hits++; }
  }
  fxArc(h, h.face * side, R, 0.2, false, n === 2);
  if (hits) { G.freeze = Math.max(G.freeze, 0.028 + Math.min(hits, 10) * 0.003); G.shake = Math.max(G.shake, 5 + Math.min(hits, 12) * 1.1); } /* 通常攻撃のヒットストップは短く（2026-10-30、以前 0.05+0.008/体） */
  else G.shake = Math.max(G.shake, 1.5);
}
// 貫通の突き：動画の24コマ。溜め(コマ1〜11)は0.35倍に詰め、突き(12〜20)は等倍、戻り(21〜24)は0.7倍
var THR_MS = [220, 280, 120, 100, 110, 150, 190, 200, 230, 270, 180, 70, 30, 30, 40, 30, 50, 80, 100, 90, 60, 90, 130, 180];
var THR_T = [], THR = {};
(function () {
  var t = 0;
  for (var i = 0; i < 24; i++) { THR_T.push(t); t += THR_MS[i] * (i < 11 ? 0.15 : i >= 20 ? 0.7 : 1) / 1000; /* 溜めは0.15倍（2026-10-30、0.35倍では長い） */ }
  THR.total = t; THR.move0 = THR_T[11]; THR.move1 = THR_T[17]; THR.hit = THR_T[15]; THR.safe = THR_T[20]; THR.cancel = t - 0.2;
})();
function tIdx(T, t) { var i = 0; while (i + 1 < T.length && T[i + 1] <= t) i++; return i; }
function atbTick(h) {
  var tt = h.t * S.aspd;
  if (!h.h1 && tt >= ATB.h1) { h.h1 = true; doHitB(1); }
  if (!h.h2 && tt >= ATB.h2) { h.h2 = true; doHitB(2); }
  if (!h.h3 && tt >= ATB.h3) { h.h3 = true; doHitB(3); }
}
function doHitB(n) {
  var h = G.hero, side = n === 1 ? 1 : -1, R = (n === 1 ? 380 : 320) * S.range, lane = 84 * ZK, hits = 0;
  var dmg = (n === 1 ? 22 : n === 2 ? 14 : 18) * S.dmg;
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (e.state !== 'walk') continue;
    var dx = (e.x - h.x) * h.face * side, dy = Math.abs(e.y - h.y);
    if (dx > -50 && dx < R && dy < lane) { hurt(e, dmg * (0.9 + Math.random() * 0.2), e.x >= h.x ? 1 : -1, n === 3); hits++; }
  }
  fxArc(h, h.face * side, R, 0.22, n === 3, n === 2);
  if (hits) { G.freeze = Math.max(G.freeze, 0.028 + Math.min(hits, 10) * 0.003); G.shake = Math.max(G.shake, 5 + Math.min(hits, 12) * 1.1); } /* 通常攻撃のヒットストップは短く（2026-10-30、以前 0.05+0.008/体） */
  else G.shake = Math.max(G.shake, 1.5);
}
function thrTick(h, dt) {
  var t = h.t;
  if (t < THR.hit) { // 溜め：細い光の粒が剣先へ集まる
    h.fxT -= dt;
    if (h.fxT <= 0) { h.fxT = 0.05; G.parts.push({ x: h.x + h.face * rnd(40, 160), y: h.y - rnd(30, 200), vx: -h.face * rnd(40, 120), vy: -rnd(20, 90), g: 0, life: rnd(0.3, 0.5), t: 0, c: '#bfe4ff', s: rnd(3, 6) }); }
  }
  var k = clamp((t - THR.move0) / (THR.move1 - THR.move0), 0, 1); k = 1 - Math.pow(1 - k, 2); // 踏み込みで前へ滑る
  h.x = clamp(h.x0 + h.face * 110 * k, heroMinX(), heroMaxX());
  if (!h.h1 && t >= THR.hit) { h.h1 = true; doThr(h); }
}
// 貫通の突き：前方520pxの一直線を貫く。拘束した敵には1.5倍。吸引で集めた敵をまとめて貫く
function doThr(h) {
  var R = 520 * S.range, lane = 72 * ZK, base = 70 * S.dmg, hits = 0, i;
  for (i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (e.state !== 'walk') continue;
    var dx = (e.x - h.x) * h.face, dy = Math.abs(e.y - h.y);
    if (dx > -40 && dx < R && dy < lane) { hurt(e, base * (e.bind > 0 ? 1.5 : 1) * (0.9 + Math.random() * 0.2), h.face, true); hits++; }
  }
  fxLance(h, R); // 突きの槍（battle/fx.js、赤黒・金）
  G.fx.push({ type: 'vshock', x: h.x, y: h.y, dir: h.face, t: 0, life: 0.5, rana: true });
  G.freeze = Math.max(G.freeze, 0.06 + Math.min(hits, 12) * 0.008);
  G.shake = Math.max(G.shake, 8 + Math.min(hits, 12) * 1.4);
  addText(h.x + h.face * 200, h.y - 250, '貫通！', 40, '#ffd27a', 0.9);
  if (hits) addText(h.x + h.face * 200, h.y - 300, hits + '体 貫く', 24, '#d9f0ff', 0.9);
}
function atkFrame(t, a) {
  var P = [['atk', 0, 9, 48], ['atk', 10, 18, 32], ['rec', 0, 16, 48]];
  for (var k = 0; k < P.length; k++) {
    var c = P[k][0], f = P[k][1], to = P[k][2], fps = P[k][3], n = to - f + 1, d = n / (fps * a);
    if (t < d) return { c: c, i: f + Math.min(n - 1, Math.floor(t * fps * a)) };
    t -= d;
  }
  return { c: 'rec', i: 16 };
}

function addText(x, y, s, size, col, life) { G.texts.push({ x: x, y: y, s: s, size: size, col: col, life: life, t: 0 }); }

function doHit(n) {
  var h = G.hero, sk = h.sk, hits = 0;
  var R = (sk ? 430 : 340) * S.range, lane = (sk ? 160 : 72) * ZK;
  var dmg = (sk ? 62 : (n === 1 ? 20 : 13)) * S.dmg;
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i];
    if (e.state !== 'walk') continue;
    var dx = (e.x - h.x) * h.face, dy = Math.abs(e.y - h.y), ok;
    if (sk) ok = Math.pow(e.x - h.x, 2) / (R * R) + Math.pow(dy / (R * 0.4), 2) < 1;
    else ok = dx > -50 && dx < R && dy < lane;
    if (ok) { hurt(e, dmg * (0.9 + Math.random() * 0.2), (e.x >= h.x ? 1 : -1) * (sk ? 1 : h.face > 0 ? 1 : -1), sk); hits++; }
  }
  if (sk) fxRing(h.x, h.y, R * 1.1, 0.55);
  fxArc(h, h.face, R, sk ? 0.28 : 0.2, sk, n === 2, sk ? VFX_RANA : null);
  if (hits) { G.freeze = Math.max(G.freeze, sk ? 0.05 + Math.min(hits, 10) * 0.008 : 0.028 + Math.min(hits, 10) * 0.003); G.shake = Math.max(G.shake, 5 + Math.min(hits, 12) * (sk ? 1.8 : 1.1)); }
  else G.shake = Math.max(G.shake, sk ? 6 : 1.5);
}

// 吸引：前方の一点へ敵を引き寄せ、S.bind 秒だけ動けなくする（ダメージは与えない）
function doPull(c) {
  var R = 560 * S.range, gx = clamp(c.x + c.face * 110, heroMinX() + 10, heroMaxX() - 10), n = 0, got = [];
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i];
    if (e.state !== 'walk' || Math.abs(e.x - c.x) > R) continue;
    var ang = n * 2.4, rad = 10 + Math.sqrt(n) * 17;
    var tx = gx + Math.cos(ang) * rad, ty = clamp(c.y + Math.sin(ang) * rad * 0.22, LANE_Y0 - 6, LANE_Y1 + 6);
    var f = e.boss ? 0.15 : e.elite ? 0.4 : 1; // 強敵は半分以下しか引けず、拘束も短い。敵将はほぼ動かない
    tx = e.x + (tx - e.x) * f; ty = e.y + (ty - e.y) * f;
    e.pull = { t: 0, dur: 0.18, sx: e.x, sy: e.y, tx: tx, ty: ty };
    e.bind = e.bindMax = S.bind * (e.boss ? 0.3 : e.elite ? 0.5 : 1); e.stun = 0; e.kx = 0; e.atkCD = Math.max(e.atkCD, 0.3);
    got.push(e);
    n++;
  }
  fxPull(gx, c.y, Math.min(R * 1.25, 680), got); // コードの吸引エフェクト（battle/fx.js）
  if (n) {
    G.freeze = Math.max(G.freeze, 0.04 + Math.min(n, 10) * 0.006);
    G.shake = Math.max(G.shake, 3 + Math.min(n, 12) * 0.8);
    addText(gx, c.y - 230, n + '体 捕縛！', 30, '#c9bcff', 0.9);
  } else {
    G.pullCD = Math.min(G.pullCD, 1.2); // 空振りは、ほぼ罰しない
    addText(gx, c.y - 230, '範囲内に敵なし', 20, '#9d93ab', 0.7);
  }
}

function hurt(e, d, dir, strong) {
  var bound = e.bind > 0; // 拘束中は、吹き飛ばず、その場に固まったまま
  e.hp -= d; e.flash = 0.1; e.stun = bound ? 0 : (strong ? 0.5 : 0.13) * (e.boss ? 0.25 : e.elite ? 0.5 : 1); e.kx = dir * (strong ? 460 : 190) /* 通常の当たりのひるみを短く（以前0.28秒・280）：連打だけで封じられないように */ * (e.elite ? 0.3 : 1) * (bound ? 0.12 : 1);
  addText(e.x + rnd(-14, 14), e.y - eh(e) - 10, String(Math.round(d)), strong ? 30 : 22, strong ? '#ffe28a' : '#ffffff', 0.7);
  e.atk = null;
  fxHit(e, dir, strong); // 当たりの衝撃（battle/fx.js）
  if (e.hp <= 0) kill(e, dir);
}

function kill(e, dir) {
  e.state = 'dying'; e.dt = 0; e.dir = dir;
  G.kills++; G.combo++; G.comboT = 2.4; if (G.combo > G.bestCombo) G.bestCombo = G.combo;
  if (e.boss) fxBossDown(e); else fxKill(e, dir); // 撃破のエフェクト（battle/fx2.js）
  if (e.boss) { G.boss = null; addText(e.x, e.y - eh(e) - 40, '敵将 撃破！', 48, '#ffe28a', 1.4); G.freeze = Math.max(G.freeze, 0.2); G.shake = Math.max(G.shake, 24); }
  var nd = e.boss ? 5 : e.elite ? 2 : (Math.random() < 0.07 ? 1 : 0); // 落とすのは物資だけ（1つ＝領地の物資+1）。強敵は2つ
  for (var k = 0; k < nd; k++) G.drops.push({ x: e.x, y: e.y, z: 20, vx: rnd(-120, 120), vz: rnd(180, 340), type: 3, t: 0, home: false });
  if (S.chain > 0) G.booms.push({ x: e.x, y: e.y, t: 0.12 });
}

function boom(b) {
  var R = 130 + 20 * S.chain;
  G.fx.push({ type: 'boom', x: b.x, y: b.y, R: R, t: 0, life: 0.3 });
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i];
    if (e.state !== 'walk') continue;
    if (Math.pow(e.x - b.x, 2) + Math.pow((e.y - b.y) * 2.4, 2) < R * R) hurt(e, 14 * S.chain * S.dmg, e.x >= b.x ? 1 : -1, false);
  }
}

var UPG = [
  { name: '斬撃と衝撃波の範囲 +20%', desc: '届く距離と衝撃波の広さが伸びる', fn: function () { S.range *= 1.2; } },
  { name: 'ダメージ +25%', desc: '通常攻撃も衝撃波も強くなる', fn: function () { S.dmg *= 1.25; } },
  { name: '攻撃速度 +15%', desc: '振りが速くなり、次の攻撃へ早くつなげる', fn: function () { S.aspd *= 1.15; } },
  { name: '衝撃波の再使用 −30%', desc: '衝撃波を、より頻繁に撃てる', fn: function () { S.cd *= 0.7; } },
  { name: '連鎖爆発', desc: '倒した敵が爆発し、周りの敵を巻き込む（重ねると強化）', fn: function () { S.chain += 1; } },
  { name: '最大HP +30、全回復', desc: '耐えながら、群れの中で戦える', fn: function () { G.hero.max += 30; G.hero.hp = G.hero.max; } },
  { name: '吸引の再使用 −30%', desc: '敵を集める回数が増え、衝撃波とつなげやすくなる', fn: function () { S.pcd *= 0.7; } },
  { name: '拘束時間 +0.4秒', desc: '集めた敵が長く動けず、まとめて斬る余裕が増える', fn: function () { S.bind += 0.4; } }
];
function offerPick() {
  var idx = UPG.map(function (u, i) { return i; }).sort(function () { return Math.random() - 0.5; }).slice(0, 3);
  G.pickOpts = idx; G.state = 'pick';
}
function choose(i) {
  var u = UPG[G.pickOpts[i]]; u.fn(); G.upgraded.push(u.name);
  G.hero.hp = Math.min(G.hero.max, G.hero.hp + 25);
  G.state = 'play'; G.phase = 'go'; // 強化を選んだら、GOが出て、次の戦場（最後なら出口）へ進める
}
