// 月夜の回廊（縦画面版）：途中で参入する仲間（AIで戦う）と、連携の技。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
// 仲間は ALLY_K（core.js）。JOIN() 番目の戦場の始まりに、カットインのあと左から駆けつける。仲間は倒れない（敵は主人公だけを狙う）。
'use strict';
/* 絵：走り＝ally/side_meta.json（右向き12コマ。セラは歩き）、攻撃＝ally/duel_meta.json（一騎打ちの連番）。
   一騎打ちの連番は向きがそろっていない（ガロウの1つ目・セラの1つ目は左向き）ので、右向きのものだけ使う（clips の番号）。
   h＝見た目の背の高さ（領地の HUMAN 表。敵の槍兵 197＝FOE_H）。pow＝通常攻撃1回のダメージ。 */
var ALLY_DEF = {
  mina: { n: 'ミナ', r: '捕縛役', clips: [0, 2], h: 163, pow: 16, range: 240, sk: '捕縛網', col: '#c9bcff',
    join: '姫、遅くなった！ ……べ、別に急いで来たわけじゃ、ないけど。', use: 'まとめて縛るよ、姫！' },
  garou: { n: 'ガロウ', r: '火力役', clips: [1], h: 212, pow: 26, range: 230, sk: '大薙ぎ', col: '#ffb27a',
    join: 'ガハハ！ 姫、加勢に参りましたぜ！', use: 'まとめて吹っ飛べぇ！' },
  sera: { n: 'セラ', r: '内政役', clips: [2], h: 157, pow: 9, range: 200, sk: '癒しの頁', col: '#b8f0c0',
    join: '姫さま、お待たせしました！ 手当ては任せてください。', use: '姫さま、いま治します！' },
  ranka: { n: 'ランカ', r: '将軍', clips: [0, 1, 2], h: 166, pow: 34, range: 250, sk: '星震', col: '#9fd8ff',
    join: 'お嬢、お待たせ〜。あとはわたしが片付けるじゃん？', use: '星、震わせちゃおっか。' }
};
var ALLY_SPD = 2.8, ALLY_RUN = null, ALLY_CLIP = []; // 攻撃の連番は一騎打ちの2.8倍速
function allyLoad(one) {
  if (!ALLY_K) return;
  total += 2; // 2つの meta（読み終えたら、その中の絵の数だけ total を足す）
  one('apor', 'ally/por_' + ALLY_K + '_1.png'); total++;
  var bi = document.getElementById('btnCi'); if (bi) bi.src = 'ally/por_' + ALLY_K + '_1.png'; // 連携ボタンの顔
  fetch('ally/side_meta.json').then(function (r) { return r.json(); }).then(function (m) {
    var c = m['run_' + ALLY_K] || m['walk_' + ALLY_K]; if (c) { ALLY_RUN = c; total++; one('arun', 'ally/' + c.f); }
    onDone();
  }).catch(function () { failed++; onDone(); });
  fetch('ally/duel_meta.json').then(function (r) { return r.json(); }).then(function (m) {
    var list = m[ALLY_K] || [];
    ALLY_DEF[ALLY_K].clips.forEach(function (ci) { var c = list[ci]; if (!c) return; var j = ALLY_CLIP.length; ALLY_CLIP.push(c); total++; one('aclip' + j, 'ally/' + c.f); });
    onDone();
  }).catch(function () { failed++; onDone(); });
}
function allyH(a) { return FOE_H * ALLY_DEF[a.k].h / 197 * depthScale(a.y); }

/* ---------- 参入 ---------- */
function allyJoin() { // JOIN() 番目の戦場の始まりに呼ぶ（startWave）
  if (!ALLY_K || G.ally) return;
  var h = G.hero;
  G.ally = { k: ALLY_K, x: LK(G.seg) - 90, y: clamp(h.y + 40, LANE_Y0, LANE_Y1), face: 1, state: 'enter', t: 0, anim: 0, atk: null, cd: 0.4, tg: null };
  G.cutin = { t: 0, life: 2.6, k: ALLY_K };
  G.coCD = 0; // 参入した直後から連携を使える
}

/* ---------- 毎フレーム（update から呼ぶ） ---------- */
function allyTick(dt) {
  var a = G.ally; if (!a) return;
  var d = ALLY_DEF[a.k], h = G.hero;
  a.t += dt; a.anim += dt;
  if (G.cutin) { G.cutin.t += dt; if (G.cutin.t >= G.cutin.life) G.cutin = null; }
  if (G.coCD > 0) G.coCD = Math.max(0, G.coCD - dt);
  if (a.cd > 0) a.cd -= dt;
  var minX = LK(G.seg) + 50, maxX = heroMaxX() + 20;
  if (a.atk) { // 攻撃の連番：山場のコマで当たる（連携のときは技が出る）
    var k = a.atk; k.t += dt;
    if (!k.done && k.t >= k.hitT) { k.done = true; if (k.co) allySkill(a); else allyHit(a); }
    if (k.t >= k.endT) { a.atk = null; a.state = 'idle'; a.cd = k.co ? 0.3 : rnd(0.35, 0.7); }
    return;
  }
  if (a.state === 'enter') { // 左の外から走り込む
    a.x += 520 * dt; a.face = 1;
    if (a.x >= minX + 120) a.state = 'idle';
    return;
  }
  // ねらう敵：近いもの（拘束中も斬る）。いなければ、主人公の後ろへ付く
  var best = null, bd = 1e9;
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (e.state !== 'walk' || e.x < camX - 20 || e.x > camX + W + 20) continue;
    var dd = Math.abs(e.x - a.x) + Math.abs(e.y - a.y) * 1.6; if (dd < bd) { bd = dd; best = e; }
  }
  var tx, ty, near = false;
  if (best) {
    var side = a.x <= best.x ? -1 : 1; tx = best.x + side * d.range * 0.55; ty = best.y;
    near = Math.abs(best.x - a.x) < d.range * 0.8 && Math.abs(best.y - a.y) < 34;
    a.face = best.x >= a.x ? 1 : -1;
  } else { tx = h.x - h.face * 130; ty = clamp(h.y + 30, LANE_Y0, LANE_Y1); }
  if (near && a.cd <= 0) { allyStartAtk(a, false); return; }
  var dx = tx - a.x, dy = ty - a.y, run = Math.abs(dx) > 18 || Math.abs(dy) > 8;
  if (run) {
    var sp = best ? 400 : 330;
    if (Math.abs(dx) > 18) a.x += Math.sign(dx) * Math.min(Math.abs(dx), sp * dt);
    if (Math.abs(dy) > 8) a.y += Math.sign(dy) * Math.min(Math.abs(dy), sp * 0.6 * dt);
    if (!best && Math.abs(dx) > 18) a.face = dx > 0 ? 1 : -1;
    a.state = 'run';
  } else a.state = 'idle';
  a.x = clamp(a.x, minX, maxX); a.y = clamp(a.y, LANE_Y0, LANE_Y1);
}
function allyStartAtk(a, co) {
  var n = ALLY_CLIP.length, ci = n ? Math.floor(Math.random() * n) : -1, c = ALLY_CLIP[ci];
  if (!c) { a.atk = { t: 0, hitT: 0.25, endT: 0.5, ci: -1, co: co, done: false }; a.state = 'atk'; return; }
  var acc = 0, hitT = 0, starts = [], sp = co ? ALLY_SPD * 1.2 : ALLY_SPD;
  for (var i = 0; i < c.n; i++) { starts.push(acc / 1000 / sp); if (i === c.hit) hitT = acc / 1000 / sp; acc += c.durs[i]; }
  a.atk = { t: 0, hitT: hitT, endT: acc / 1000 / sp, ci: ci, starts: starts, co: co, done: false }; a.state = 'atk';
}
function allyHit(a) { // 通常攻撃：前方の帯
  var d = ALLY_DEF[a.k], hits = 0, R = d.range, lane = 70 * ZK;
  for (var i = 0; i < G.enemies.length; i++) {
    var e = G.enemies[i]; if (e.state !== 'walk') continue;
    var dx = (e.x - a.x) * a.face, dy = Math.abs(e.y - a.y);
    if (dx > -40 && dx < R && dy < lane) { hurt(e, d.pow * (0.9 + Math.random() * 0.2), a.face, false); hits++; }
  }
  fxArc(a, a.face, R, 0.2, false, false); // 味方の色（青白）
  if (hits) G.shake = Math.max(G.shake, 3 + Math.min(hits, 8) * 0.6);
}

/* ---------- 連携（ボタン） ---------- */
function tryCo() {
  if (G.state !== 'play' || G.trans) return;
  var a = G.ally; if (!a) return;
  if (G.coCD > 0) { addText(G.hero.x, G.hero.y - 250, '連携 再使用まで ' + G.coCD.toFixed(1) + '秒', 20, '#a8dcff', 0.7); return; }
  if (a.state === 'enter') a.state = 'idle';
  G.coCD = G.coMax;
  a.atk = null; allyStartAtk(a, true);
  addText(a.x, a.y - allyH(a) - 30, ALLY_DEF[a.k].use, 22, ALLY_DEF[a.k].col, 1.3);
}
function allySkill(a) {
  var d = ALLY_DEF[a.k], h = G.hero, i, e, n = 0;
  if (a.k === 'mina') { // 捕縛網：広い範囲の敵を、ミナの前の一点へ引き寄せて長く縛る（吸引より広く長い）
    var R = 680, gx = clamp(a.x + a.face * 170, heroMinX() + 10, heroMaxX() - 10), got = [];
    for (i = 0; i < G.enemies.length; i++) {
      e = G.enemies[i]; if (e.state !== 'walk' || Math.abs(e.x - a.x) > R) continue;
      var ang = n * 2.4, rad = 10 + Math.sqrt(n) * 17, tx = gx + Math.cos(ang) * rad, ty = clamp(a.y + Math.sin(ang) * rad * 0.22, LANE_Y0 - 6, LANE_Y1 + 6), f = e.boss ? 0.15 : e.elite ? 0.4 : 1;
      e.pull = { t: 0, dur: 0.22, sx: e.x, sy: e.y, tx: e.x + (tx - e.x) * f, ty: e.y + (ty - e.y) * f };
      e.bind = e.bindMax = (S.bind + 1.6) * (e.boss ? 0.3 : e.elite ? 0.5 : 1); e.stun = 0; e.kx = 0; e.atkCD = Math.max(e.atkCD, 0.3); e.atk = null;
      got.push(e); n++;
    }
    fxPull(gx, a.y, Math.min(R * 1.25, 720), got);
    G.freeze = Math.max(G.freeze, 0.05 + Math.min(n, 10) * 0.006); G.shake = Math.max(G.shake, 4 + Math.min(n, 12) * 0.8);
    addText(gx, a.y - 240, n ? n + '体 捕縛網！' : '捕縛網', 32, d.col, 1.0);
  } else if (a.k === 'garou') { // 大薙ぎ：前後の広い範囲に大ダメージ＋大きく吹き飛ばす
    var R2 = 470, lane = 170 * ZK;
    for (i = 0; i < G.enemies.length; i++) {
      e = G.enemies[i]; if (e.state !== 'walk' || Math.abs(e.x - a.x) > R2 || Math.abs(e.y - a.y) > lane) continue;
      hurt(e, 95 * (0.9 + Math.random() * 0.2) * (e.bind > 0 ? 1.3 : 1), e.x >= a.x ? 1 : -1, true); n++;
    }
    fxArc(a, a.face, R2, 0.5, true, false, null, { rx: 520, ry: 200, a0: 1.25, a1: -1.55, w: 90, ox: 30, oy: -110, sw: 140 });
    fxArc(a, -a.face, R2 * 0.8, 0.45, true, false);
    fxRing(a.x, a.y, R2 * 1.1, 0.6);
    G.freeze = Math.max(G.freeze, 0.1 + Math.min(n, 12) * 0.006); G.shake = Math.max(G.shake, 18 + Math.min(n, 12));
    addText(a.x, a.y - 280, '大薙ぎ！', 46, d.col, 1.0); if (n) addText(a.x, a.y - 330, n + '体', 26, '#ffe0b8', 0.9);
  } else if (a.k === 'sera') { // 癒しの頁：主人公を回復し、近くの敵を足止めする
    var heal = Math.round(h.max * 0.4); h.hp = Math.min(h.max, h.hp + heal);
    for (i = 0; i < G.enemies.length; i++) {
      e = G.enemies[i]; if (e.state !== 'walk' || Math.abs(e.x - h.x) > 420 || e.bind > 0) continue;
      e.stun = 1.3 * (e.boss ? 0.3 : 1); e.kx = (e.x >= h.x ? 1 : -1) * 120; e.atk = null; n++;
    }
    for (i = 0; i < 36; i++) G.parts.push({ x: h.x + rnd(-90, 90), y: h.y - rnd(0, 220), vx: rnd(-30, 30), vy: -rnd(60, 220), g: 0, life: rnd(0.5, 1.0), t: 0, c: i % 2 ? '#c9f5c8' : '#fff1b8', s: rnd(3, 7) });
    G.fx.push({ type: 'ring', x: h.x, y: h.y, R: 420, t: 0, life: 0.6, rgb: '190,245,190', rgb2: '150,230,170' });
    addText(h.x, h.y - 260, 'HP +' + heal, 34, d.col, 1.1); if (n) addText(h.x, h.y - 305, n + '体 足止め', 22, '#e8f6d8', 0.9);
  } else { // 星震：画面の敵すべてに大ダメージ（拘束中は1.5倍）
    for (i = 0; i < G.enemies.length; i++) {
      e = G.enemies[i]; if (e.state !== 'walk' || e.x < camX - 40 || e.x > camX + W + 40) continue;
      hurt(e, 150 * (0.9 + Math.random() * 0.2) * (e.bind > 0 ? 1.5 : 1), e.x >= a.x ? 1 : -1, true); n++;
      for (var s = 0; s < 4; s++) G.parts.push({ x: e.x + rnd(-30, 30), y: e.y - eh(e) - rnd(120, 360), vx: rnd(-40, 40), vy: rnd(500, 900), g: 0, life: rnd(0.25, 0.45), t: 0, c: s % 2 ? '#bfe4ff' : '#ffe9a8', s: rnd(3, 6) });
    }
    fxRing(a.x, a.y, W * 0.9, 0.8);
    G.fx.push({ type: 'ring', x: a.x, y: a.y, R: W * 1.1, t: 0, life: 0.7, rgb: '160,215,255', rgb2: '120,180,255' });
    G.flash = 0.3; G.flashRGB = '190,220,255';
    G.freeze = Math.max(G.freeze, 0.14 + Math.min(n, 14) * 0.006); G.shake = Math.max(G.shake, 26);
    addText(a.x, a.y - 290, '星震！', 56, d.col, 1.1); if (n) addText(a.x, a.y - 345, n + '体', 28, '#e6f4ff', 0.9);
  }
}

/* ---------- 描画 ---------- */
function drawAlly() {
  var a = G.ally; if (!a) return;
  var H0 = allyH(a), im, c, k, sx, sy, sw, shh, ox, oy;
  shadow(a.x, a.y, 34 * depthScale(a.y));
  if (a.atk && a.atk.ci >= 0 && (im = IMG['aclip' + a.atk.ci]) && im.naturalWidth) {
    c = ALLY_CLIP[a.atk.ci]; var fi = 0; while (fi + 1 < c.n && a.atk.starts[fi + 1] <= a.atk.t) fi++;
    k = H0 / c.idle.h; sw = c.cw; shh = c.ch; sx = (fi % c.cols) * c.cw; sy = Math.floor(fi / c.cols) * c.ch; ox = c.idle.x + c.idle.w / 2; oy = c.ch - (c.pad == null ? 2.8 : c.pad);
  } else if ((a.state === 'run' || a.state === 'enter') && ALLY_RUN && (im = IMG.arun) && im.naturalWidth) {
    c = ALLY_RUN; var rf = Math.floor(a.anim * 1000 / c.durs[0] * (c.durs[0] > 80 ? 2.2 : 1)) % c.n;
    k = H0 / c.ph; sw = c.cw; shh = c.ch; sx = (rf % c.cols) * c.cw; sy = Math.floor(rf / c.cols) * c.ch; ox = c.ax; oy = c.ay;
  } else if (ALLY_CLIP[0] && (im = IMG.aclip0) && im.naturalWidth) { // 待機：攻撃の連番の1コマ目（構え）を、息で少し揺らす
    c = ALLY_CLIP[0]; k = H0 / c.idle.h; sw = c.cw; shh = c.ch; sx = 0; sy = 0; ox = c.idle.x + c.idle.w / 2; oy = c.ch - (c.pad == null ? 2.8 : c.pad);
  } else return;
  ctx.save(); ctx.translate(a.x, a.y);
  var br = a.state === 'idle' && !a.atk ? 1 + 0.012 * Math.sin(a.t * 3.7) : 1;
  ctx.scale(a.face < 0 ? -k : k, k * br); // 絵は右向き
  ctx.drawImage(im, sx, sy, sw, shh, -ox, -oy, sw, shh);
  ctx.restore();
  if (a.state !== 'enter') { // 足元の青い印（味方の目印）
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = 'rgba(110,190,255,0.55)'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.ellipse(a.x, a.y + 2, 40 * depthScale(a.y), 9 * depthScale(a.y), 0, 0, 7); ctx.stroke(); ctx.restore();
  }
}
function drawCutin() { // 参入のカットイン（画面座標）：青い帯＋立ち絵＋名前＋ひとこと。戦闘は止めない
  var ci = G.cutin; if (!ci) return;
  var d = ALLY_DEF[ci.k], t = ci.t, life = ci.life, inK = vEase(t / 0.28), outK = t > life - 0.35 ? vEaseIn((t - (life - 0.35)) / 0.35) : 0;
  var y0 = VH * 0.2, bh = 220, off = (1 - inK) * -W + outK * W;
  ctx.save(); ctx.globalAlpha = 1 - outK * 0.6;
  ctx.translate(off, 0);
  var g = ctx.createLinearGradient(0, y0, 0, y0 + bh); g.addColorStop(0, 'rgba(10,30,60,0.88)'); g.addColorStop(0.5, 'rgba(24,70,120,0.92)'); g.addColorStop(1, 'rgba(10,30,60,0.88)');
  ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(0, y0 + 26); ctx.lineTo(W, y0); ctx.lineTo(W, y0 + bh - 26); ctx.lineTo(0, y0 + bh); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = 'rgba(150,210,255,0.9)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(0, y0 + 26); ctx.lineTo(W, y0); ctx.moveTo(0, y0 + bh); ctx.lineTo(W, y0 + bh - 26); ctx.stroke();
  var im = IMG.apor;
  if (im && im.naturalWidth) { // 立ち絵の上半分を、帯の中に切り抜いて置く
    ctx.save(); ctx.beginPath(); ctx.moveTo(0, y0 + 26); ctx.lineTo(W, y0); ctx.lineTo(W, y0 + bh - 26); ctx.lineTo(0, y0 + bh); ctx.closePath(); ctx.clip();
    var ph = bh * 2.0, pw = im.naturalWidth * ph / im.naturalHeight, px = W - pw * 0.85 + (1 - inK) * 120;
    ctx.drawImage(im, px, y0 - bh * 0.08, pw, ph); ctx.restore();
  }
  txt('援軍', 28, y0 + 64, 24, '#9fd8ff', 'left', 4);
  txt(d.n + '　参上！', 28, y0 + 120, 52, '#f3f8ff', 'left', 6);
  ctx.font = '700 21px "DMincho","Hiragino Mincho ProN","Yu Mincho",serif';
  var line = d.join, mw = W * 0.6, ls = [], cur = '';
  for (var i = 0; i < line.length; i++) { var tt = cur + line[i]; if (ctx.measureText(tt).width > mw && cur) { ls.push(cur); cur = line[i]; } else cur = tt; }
  ls.push(cur);
  for (var j = 0; j < Math.min(2, ls.length); j++) txt(ls[j], 30, y0 + 158 + j * 28, 21, '#dbeaff', 'left', 4);
  ctx.restore();
}
