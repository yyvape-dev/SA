// 月夜の回廊（縦画面版）：毎フレームの更新（主人公・敵・ドロップ）。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* ---------- 更新 ---------- */
function update(dt) {
  G.t += dt;
  if (G.shake > 0.1) G.shake *= Math.pow(0.002, dt); else G.shake = 0;
  if (G.state === 'title' || G.paused) return;
  if (G.freeze > 0) { G.freeze -= dt; return; }
  if (G.state === 'dead') G.deadT = (G.deadT || 0) + dt;
  if (G.state === 'result') G.resT += dt;
  if (G.state === 'pick' || G.state === 'dead' || G.state === 'result') { updateFx(dt); return; }
  if (G.trans) { // 部屋の移動中：暗転の真ん中で次の部屋へ切り替える
    var tr = G.trans; tr.t += dt;
    if (!tr.sw && tr.t >= 0.5) { tr.sw = true; enterRoom(G.roomNo + 1); }
    if (tr.t >= 1) G.trans = null;
    updateFx(dt); return;
  }

  var h = G.hero;
  if (G.skCD > 0) G.skCD = Math.max(0, G.skCD - dt);
  if (G.pullCD > 0) G.pullCD = Math.max(0, G.pullCD - dt);
  if (G.thrCD > 0) G.thrCD = Math.max(0, G.thrCD - dt);
  if (G.ultCD > 0) G.ultCD = Math.max(0, G.ultCD - dt);
  if (G.comboT > 0) { G.comboT -= dt; if (G.comboT <= 0) G.combo = 0; }
  if (h.inv > 0) h.inv -= dt;
  if (h.flash > 0) h.flash -= dt;

  var ax = 0, ay = 0;
  if (keys.ArrowLeft || keys.KeyA) ax -= 1;
  if (keys.ArrowRight || keys.KeyD) ax += 1;
  if (keys.ArrowUp || keys.KeyW) ay -= 1;
  if (keys.ArrowDown || keys.KeyS) ay += 1;
  ax += pad.x; ay += pad.y;
  var mag = Math.min(1, Math.hypot(ax, ay));
  var run = !!(keys.ShiftLeft || keys.ShiftRight) || pad.mag > 0.8;

  if (h.state === 'atk' && h.kind === 'ult') {
    h.t += dt; ultTick(h, dt);
  } else if (h.state === 'atk') {
    h.t += dt;
    var a = S.aspd, t1 = 10 / (48 * a), t2 = t1 + 3 / (32 * a);
    if (h.kind === 'atk') h.lastAtkEnd = G.t;
    if (h.kind === 'thr') thrTick(h, dt);
    else if (h.kind === 'atk' && h.v === 1) atbTick(h);
    else if (h.kind === 'atk') atcTick(h);
    else {
      if (!h.h1 && h.t >= t1) { h.h1 = true; if (h.kind === 'pull') doPull(h); else doHit(1); }
      if (h.kind === 'atk' && !h.h2 && h.t >= t2) { h.h2 = true; doHit(2); }
    }
    if (h.t >= h.cancelT) {
      if (h.buf) {
        var bk = h.buf;
        if ((bk === 'sk' && G.skCD > 0) || (bk === 'pull' && G.pullCD > 0) || (bk === 'ult' && G.ultCD > 0) || (bk === 'thr' && G.thrCD > 0)) bk = 'atk';
        beginAttack(bk);
      }
      else if (mag > 0.2) h.state = 'idle';
    }
    if (h.state === 'atk' && h.t >= h.total) h.state = 'idle';
  }
  if (h.state === 'hurt') { // のけぞり：少し押し戻され、終わったら先行入力を出す
    h.t += dt; h.x += h.kb * dt; h.kb *= Math.pow(0.02, dt);
    if (h.t >= HURT.total) { h.state = 'idle'; h.anim = 0; if (h.buf) { var hb = h.buf; h.buf = 0; if (!((hb === 'sk' && G.skCD > 0) || (hb === 'pull' && G.pullCD > 0) || (hb === 'ult' && G.ultCD > 0) || (hb === 'thr' && G.thrCD > 0))) beginAttack(hb); } }
  }
  if (h.state !== 'atk' && h.state !== 'hurt') {
    if (mag > 0.2) {
      var sp = run ? 440 : 240; // 縦画面：横版（190・380）より速く、縦の動きも速く（0.6→0.85）
      h.x += ax / Math.max(1, Math.hypot(ax, ay)) * sp * dt * (mag > 1 ? 1 : 1);
      h.y += ay / Math.max(1, Math.hypot(ax, ay)) * sp * 0.85 * dt;
      if (Math.abs(ax) > 0.2) h.face = ax > 0 ? 1 : -1;
      var mode = run ? 'run' : 'walk';
      if (h.state !== mode) { h.state = mode; h.anim = 0; }
      h.anim += dt * (run ? 24 : 12);
    } else { h.state = 'idle'; h.anim += dt; }
  }
  h.x = clamp(h.x, heroMinX(), heroMaxX()); h.y = clamp(h.y, LANE_Y0, LANE_Y1);

  // 画面送り：GOの間にカメラが次の戦場へ着いたら固定して次の波。最後の戦場は、右端の出口へ着いたら次の部屋
  if (G.phase === 'go') {
    if (G.seg < ROOM.segs - 1) { if (camX >= LK(G.seg + 1) - 1) { G.seg++; G.phase = 'fight'; startWave(G.wave + 1); } }
    else if (h.x >= RW() - 150) beginTrans();
  }
  updateCam(dt);

  // 敵の出現
  G.qT += dt;
  while (G.queue.length && G.queue[0].at <= G.qT) spawn(G.queue.shift());

  // 敵
  for (var i = G.enemies.length - 1; i >= 0; i--) {
    var e = G.enemies[i];
    e.t += dt; if (e.flash > 0) e.flash -= dt;
    if (e.state === 'dying') { e.dt += dt; if (e.dt > 0.4) G.enemies.splice(i, 1); else e.x += e.dir * 160 * dt * (1 - e.dt / 0.4); continue; }
    if (e.bind > 0) { // 拘束：引き寄せの間だけ動き、あとは固まる。攻撃もしない
      e.bind -= dt; e.atk = null;
      e.face = h.x >= e.x ? 1 : -1;
      if (e.pull) {
        e.pull.t += dt;
        var pk = Math.min(1, e.pull.t / e.pull.dur); pk = 1 - Math.pow(1 - pk, 3);
        e.x = e.pull.sx + (e.pull.tx - e.pull.sx) * pk; e.y = e.pull.sy + (e.pull.ty - e.pull.sy) * pk;
        if (e.pull.t >= e.pull.dur) e.pull = null;
      } else { e.x += e.kx * dt; e.kx *= Math.pow(0.0005, dt); }
      if (e.bind <= 0) { e.bind = 0; e.pull = null; e.kx = 0; }
      e.y = clamp(e.y, LANE_Y0 - 6, LANE_Y1 + 6);
      continue;
    }
    if (e.stun > 0) { e.atk = null; e.stun -= dt; e.x += e.kx * dt; e.kx *= Math.pow(0.0005, dt); }
    else if (e.atk) { // 攻撃の連番を流す。山場（hit のコマ）で、まだ間合いにいれば当たる
      var ak = e.atk; ak.t += dt;
      if (!ak.done && ak.t >= ak.hitT) { ak.done = true;
        var adx = h.x - e.x, ady = h.y - e.y;
        if (Math.abs(adx) < 105 * e.size && Math.abs(ady) < 36 && h.inv <= 0 && G.state === 'play' && !(h.state === 'atk' && (h.kind === 'ult' || (h.kind === 'thr' && h.t < THR.safe)))) hitHero(e);
      }
      if (ak.t >= ak.endT) e.atk = null;
    }
    else {
      var dx = h.x - e.x, dy = h.y - e.y;
      e.face = dx >= 0 ? 1 : -1;
      if (Math.abs(dx) > 70 * e.size) e.x += Math.sign(dx) * e.sp * dt;
      var fk = clamp((Math.abs(dx) - 60) / 260, 0.25, 1); // 遠いほど奥行きにばらけ、近づくと主人公の奥行きへ寄る
      var tgy = clamp(h.y + e.yo * fk, LANE_Y0, LANE_Y1), ddy2 = tgy - e.y;
      if (Math.abs(ddy2) > 6) e.y += Math.sign(ddy2) * e.sp * 0.55 * dt;
      e.atkCD -= dt;
      if (Math.abs(dx) < 95 * e.size && Math.abs(dy) < 30 && e.atkCD <= 0) startFoeAtk(e); // 必殺技と、突きの溜め〜突きの間は、当たりの瞬間に無敵で外れる
    }
    e.y = clamp(e.y, LANE_Y0 - 6, LANE_Y1 + 6);
  }
  // 敵どうしが重なりすぎないようにする
  for (var p = 0; p < G.enemies.length; p++) {
    var A = G.enemies[p]; if (A.state !== 'walk') continue; // 人の大きさの敵なので、横版の骸骨より間を広く
    for (var q = p + 1; q < G.enemies.length; q++) {
      var B = G.enemies[q]; if (B.state !== 'walk') continue;
      var bA = A.bind > 0, bB = B.bind > 0; if (bA && bB) continue; // 拘束どうしは、重なったまま固める
      var ddx = A.x - B.x, ddy = (A.y - B.y) * 2;
      var d2 = ddx * ddx + ddy * ddy;
      if (d2 < 2900 && d2 > 0.01) { var d = Math.sqrt(d2), push = (54 - d) * 0.5 * Math.min(1, dt * 12); if (!bA) A.x += ddx / d * push; if (!bB) B.x -= ddx / d * push; }
    }
  }
  for (var b = G.booms.length - 1; b >= 0; b--) { G.booms[b].t -= dt; if (G.booms[b].t <= 0) { boom(G.booms[b]); G.booms.splice(b, 1); } }

  // ドロップ
  for (var k = G.drops.length - 1; k >= 0; k--) {
    var d = G.drops[k]; d.t += dt;
    if (d.home) {
      var tx = h.x - d.x, ty = (h.y - 60) - (d.y - d.z), dist = Math.hypot(tx, ty) || 1;
      var spd = 500 + d.t * 900; d.x += tx / dist * spd * dt; d.y += ty / dist * spd * dt * 1.0; d.z = 0;
      if (dist < 34) { collect(d); G.drops.splice(k, 1); }
    } else {
      d.vz -= 900 * dt; d.z += d.vz * dt; d.x += d.vx * dt; d.vx *= Math.pow(0.2, dt);
      if (d.z <= 0) { d.z = 0; d.vz *= -0.35; if (Math.abs(d.vz) < 40) d.vz = 0; }
      if (d.t > 0.55 || Math.hypot(h.x - d.x, h.y - d.y) < 150) d.home = true;
    }
  }
  updateFx(dt);

  // ウェーブ終了
  if (G.state === 'play' && G.phase === 'fight' && !G.queue.length && !G.enemies.length) { if (BAT.on && G.wave >= BAT.waves) finishBattle(true); else clearField(); }
}

function startFoeAtk(e) {
  var cl = FOE_CLIP[e.kind] || [], ci = Math.floor(Math.random() * cl.length), c = cl[ci];
  e.atkCD = 1.6;
  if (!c) { e.atk = { t: 0, hitT: 0.35, endT: 0.6, ci: -1, done: false }; return; } // 攻撃の絵が無いときは、少し止まってから当たる
  var acc = 0, hitT = 0, starts = [];
  for (var i = 0; i < c.n; i++) { starts.push(acc / 1000 / FOE_SPD); if (i === c.hit) hitT = acc / 1000 / FOE_SPD; acc += c.durs[i]; }
  e.atk = { t: 0, hitT: hitT, endT: acc / 1000 / FOE_SPD, ci: ci, starts: starts, done: false };
}
function hitHero(e) {
  var h = G.hero; h.hp -= e.dmg; h.inv = 0.45; h.flash = 0.25; G.shake = Math.max(G.shake, 4);
  addText(h.x, h.y - 230, '-' + e.dmg, 26, '#ff6b6b', 0.7);
  if (h.state !== 'atk' && h.hp > 0) { h.state = 'hurt'; h.t = 0; h.buf = 0; h.kb = (h.x >= e.x ? 1 : -1) * 240; }
  if (h.hp <= 0) { h.hp = 0; G.state = 'dead'; G.deadT = 0; if (BAT.on) finishBattle(false); }
}
function clearField() { // 戦場の敵を倒しきった：少し回復して、GO で右の戦場へ（強化の選択はなし）
  G.hero.hp = Math.min(G.hero.max, G.hero.hp + 25); G.phase = 'go';
}

function collect(d) {
  if (d.type === 3) { G.sup++; addText(G.hero.x, G.hero.y - 250, '物資 +1', 24, '#f0c869', 0.9); return; }
  if (d.type === 0) G.gold += 1;
  else if (d.type === 1) { G.gold += 5; G.rare++; addText(G.hero.x, G.hero.y - 260, 'レア素材', 22, '#7ec8ff', 0.9); }
  else { G.gold += 30; G.rare += 3; addText(G.hero.x, G.hero.y - 260, 'エピック素材！', 26, '#d48cff', 1.1); }
}

function updateFx(dt) {
  var i;
  if (G.flash > 0) G.flash = Math.max(0, G.flash - dt * 3.2);
  for (i = G.fx.length - 1; i >= 0; i--) { G.fx[i].t += dt; if (G.fx[i].t >= G.fx[i].life) G.fx.splice(i, 1); }
  for (i = G.parts.length - 1; i >= 0; i--) { var p = G.parts[i]; p.t += dt; p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; if (p.t >= p.life) G.parts.splice(i, 1); }
  for (i = G.texts.length - 1; i >= 0; i--) { var x = G.texts[i]; x.t += dt; x.y -= 36 * dt; if (x.t >= x.life) G.texts.splice(i, 1); }
}
