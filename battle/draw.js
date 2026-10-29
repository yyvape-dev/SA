// 月夜の回廊（縦画面版）：描画（主人公・敵・演出・舞台・上の段・重ね表示）。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* ---------- 描画 ---------- */
var C = { bone: '#c4bda8', dark: '#1b1722' };

function shadow(x, y, w) {
  ctx.fillStyle = 'rgba(0,0,0,0.38)'; ctx.beginPath(); ctx.ellipse(x, y + 2, w, w * 0.2, 0, 0, 7); ctx.fill();
}

function drawSprite(name, x, y, face, sc, sy, an, rot) {
  var im = IMG[name]; if (!im || !im.complete || !im.naturalWidth) return;
  var A = an || M;
  ctx.save(); ctx.translate(x, y); if (rot) ctx.rotate(rot); var kk = A.k || 1; ctx.scale(face * sc * kk, sc * kk * (sy || 1)); ctx.drawImage(im, -A.ax, -A.ay); ctx.restore();
}

function drawHero() {
  var h = G.hero, sc = depthScale(h.y);
  shadow(h.x, h.y, 62 * sc);
  var name = 'idle_00', sy = 1, anch = null, jit = 0;
  if (h.state === 'idle') sy = 1 + 0.012 * Math.sin(h.anim * 2 * Math.PI / 1.7);
  else if (h.state === 'walk') name = 'walk_' + pad2(Math.floor(h.anim) % 24);
  else if (h.state === 'run') name = 'run_' + pad2(Math.floor(h.anim) % 10);
  else if (h.state === 'dodge') name = 'run_' + pad2(Math.floor(h.anim) % 10);
  else if (h.state === 'hurt') { name = 'dmg_' + pad2(hurtFrame(h.t)); anch = DMG_A; }
  else if (h.state === 'atk' && h.kind === 'ult') {
    name = 'ult_' + pad2(ultFrame(h.t)); anch = ULT_A;
    if (h.t >= ULT.charge && h.t < ULT.charge + ULT.tame) jit = (Math.random() - 0.5) * 5; // 溜めを止める間の震え
  }
  else if (h.state === 'atk' && h.kind === 'thr') { name = 'thr_' + pad2(tIdx(THR_T, h.t)); anch = THR_A; }
  else if (h.state === 'atk' && h.kind === 'atk' && h.v === 1) { name = 'atb_' + pad2(tIdx(ATB_T, h.t * S.aspd)); anch = ATB_A; }
  else if (h.state === 'atk' && h.kind === 'atk') { name = 'atc_' + pad2(tIdx(ATC_T, h.t * S.aspd)); anch = ATC_A; }
  else if (h.state === 'atk') { var f = atkFrame(h.t, S.aspd); name = f.c + '_' + pad2(f.i); anch = ATK_A; }
  var rot = 0;
  if (G.state === 'dead') { // やられ：のけぞった姿のまま、足元を軸に後ろへ倒れる（静止画＋コードの動き）
    name = 'dmg_01'; anch = DMG_A; sy = 1; var dk = Math.min(1, (G.deadT || 0) / 0.7); rot = -h.face * 1.4 * (1 - Math.pow(1 - dk, 3));
  }
  var blink = h.inv > 0 && Math.floor(G.t * 24) % 2 === 0 && G.state !== 'dead';
  for (var ti = 0; ti < h.trail.length; ti++) { // 回避の残像：古いほど薄く
    var tr = h.trail[ti]; ctx.globalAlpha = 0.38 * (1 - tr.t / 0.22) * (ti + 1) / h.trail.length;
    drawSprite('run_' + pad2(tr.f), tr.x, tr.y, tr.face, depthScale(tr.y) * RUN_K, 1, null, 0);
  }
  ctx.globalAlpha = blink ? 0.55 : 1;
  drawSprite(name, h.x + jit, h.y, h.face, sc * (h.state === 'run' || h.state === 'dodge' ? RUN_K : 1), sy, anch, rot);
  ctx.globalAlpha = 1;
}

function drawFoe(e) { // 赤い兵：歩き（シート）／攻撃（連番）。やられはコードで倒れて消える
  var H0 = eh(e), p = e.state === 'dying' ? e.dt / 0.4 : 0, im, sx, sy, sw, shh, k, ox, oy, flip;
  e.tilt = 0;
  var c = e.atk && e.atk.ci >= 0 ? (FOE_CLIP[e.kind] || [])[e.atk.ci] : null;
  if (c && IMG['fd' + e.kind + '_' + e.atk.ci] && IMG['fd' + e.kind + '_' + e.atk.ci].naturalWidth) {
    var fi = 0; while (fi + 1 < c.n && e.atk.starts[fi + 1] <= e.atk.t) fi++;
    im = IMG['fd' + e.kind + '_' + e.atk.ci]; k = H0 / c.idle.h; sw = c.cw; shh = c.ch; sx = (fi % c.cols) * c.cw; sy = Math.floor(fi / c.cols) * c.ch;
    flip = e.face > 0; // 攻撃の絵は左向き
    ox = (c.idle.x + c.idle.w / 2); oy = c.ch - (c.pad == null ? 2.8 : c.pad);
  } else if (FOE_SW[e.kind] && IMG['sw' + e.kind] && IMG['sw' + e.kind].naturalWidth && e.state === 'walk' && e.stun <= 0 && e.bind <= 0) {
    // 歩き：横向きの歩きの絵（左向き12コマ）。歩く速さに合わせて回す
    c = FOE_SW[e.kind]; im = IMG['sw' + e.kind]; k = H0 / c.ph; sw = c.cw; shh = c.ch;
    var wf = Math.floor((e.t * 1000 + e.yo * 37) / c.durs[0] * (e.sp / 120)) % c.n; wf = (wf + c.n) % c.n;
    sx = (wf % c.cols) * c.cw; sy = Math.floor(wf / c.cols) * c.ch; flip = e.face > 0; ox = c.ax; oy = c.ay;
  } else if ((FOE_CLIP[e.kind] || [])[0] && IMG['fd' + e.kind + '_0'] && IMG['fd' + e.kind + '_0'].naturalWidth) {
    // 歩き：一騎打ちの横向きの絵（攻撃の連番の1コマ目＝構え）を、上下の揺れと傾きで歩かせる（横向きの歩きの絵ができたら差し替える）
    c = FOE_CLIP[e.kind][0]; im = IMG['fd' + e.kind + '_0']; k = H0 / c.idle.h; sw = c.cw; shh = c.ch; sx = 0; sy = 0;
    flip = e.face > 0; ox = (c.idle.x + c.idle.w / 2); oy = c.ch - (c.pad == null ? 2.8 : c.pad);
    var mv = e.state === 'walk' && e.stun <= 0 && e.bind <= 0 ? 1 : 0, ph = e.t * 9 + e.yo;
    oy += mv * Math.abs(Math.sin(ph)) * 7; e.tilt = mv * Math.sin(ph) * 0.045;
  } else {
    var wm = FOE_WALK[e.kind]; im = IMG['fw' + e.kind];
    if (!im || !im.naturalWidth) { drawSkeleton(e); return; }
    var moving = e.state === 'walk' && e.stun <= 0 && e.bind <= 0, wi = moving ? Math.floor(e.t * 11) % 8 : 0;
    k = H0 / wm.h; sw = wm.cw; shh = wm.ch; sx = (wi % 4) * wm.cw; sy = Math.floor(wi / 4) * wm.ch;
    flip = e.face < 0; // 歩きの絵は右向き
    ox = wm.cw / 2; oy = wm.ch * 0.985;
  }
  ctx.save();
  ctx.globalAlpha = 1 - p;
  shadow(e.x, e.y, 34 * depthScale(e.y) * e.size);
  ctx.translate(e.x, e.y - p * 20);
  ctx.rotate(p * 1.2 * (e.dir || 1) + (e.tilt || 0)); // 歩きの揺れの傾きも // 吹き飛ぶ向きへ倒れる
  ctx.scale(flip ? -k : k, k);
  ctx.drawImage(im, sx, sy, sw, shh, -ox, -oy, sw, shh);
  if (e.flash > 0 || e.bind > 0) { // 被弾は白く、拘束は紫に光らせる（同じ絵を加算で重ねる）
    ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = (1 - p) * (e.flash > 0 ? 0.7 : 0.28);
    ctx.drawImage(im, sx, sy, sw, shh, -ox, -oy, sw, shh);
  }
  ctx.restore();
  if (e.bind > 0 && e.state === 'walk') { // 拘束の輪（足元と腰）。切れる直前は薄くなる
    var al = Math.min(1, e.bind / 0.25) * 0.9, wob = 1 + 0.06 * Math.sin(e.t * 14), s2 = depthScale(e.y) * e.size;
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = 'rgba(160,130,255,' + al + ')'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.ellipse(e.x, e.y, 40 * s2 * wob, 11 * s2 * wob, 0, 0, 7); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(e.x, e.y - H0 * 0.45, 30 * s2, 8 * s2, 0, 0, 7); ctx.stroke();
    ctx.restore();
  }
}
function drawSkeleton(e) { // 予備（敵の絵が読めなかったとき）
  var sc = depthScale(e.y) * e.size, t = e.t;
  var p = e.state === 'dying' ? e.dt / 0.4 : 0;
  ctx.save();
  ctx.globalAlpha = 1 - p;
  shadow(e.x, e.y, 30 * sc);
  ctx.translate(e.x, e.y - p * 36 * sc);
  ctx.rotate(p * 1.1 * (e.dir || 1));
  ctx.scale(e.face * sc, sc);
  var moving = e.state === 'walk' && e.stun <= 0;
  var bob = moving ? Math.abs(Math.sin(t * 9)) * 4 : 0, sw = moving ? Math.sin(t * 9) * 11 : 0;
  var bone = e.flash > 0 ? '#ffffff' : (e.bind > 0 ? '#b7a6ff' : (e.elite ? '#cbb9ff' : C.bone));
  ctx.translate(0, -bob);
  ctx.lineCap = 'round'; ctx.strokeStyle = bone;
  ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(-8, -34); ctx.lineTo(-8 + sw, 0); ctx.moveTo(8, -34); ctx.lineTo(8 - sw, 0); ctx.stroke();
  ctx.lineWidth = 7; ctx.beginPath(); ctx.moveTo(0, -34); ctx.lineTo(0, -72); ctx.stroke();
  ctx.lineWidth = 4; for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.moveTo(-15, -70 + i * 9); ctx.lineTo(15, -70 + i * 9); ctx.stroke(); }
  ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(10, -70); ctx.lineTo(26, -52 + sw * 0.4); ctx.stroke();
  ctx.strokeStyle = e.flash > 0 ? '#fff' : '#8d939e'; ctx.beginPath(); ctx.moveTo(26, -52 + sw * 0.4); ctx.lineTo(50, -88 + sw * 0.4); ctx.stroke();
  ctx.fillStyle = bone; ctx.beginPath(); ctx.arc(0, -90, 17, 0, 7); ctx.fill(); ctx.fillRect(-9, -80, 18, 12);
  ctx.fillStyle = e.elite ? '#ff3b3b' : C.dark;
  ctx.beginPath(); ctx.arc(-6, -92, 4.6, 0, 7); ctx.arc(7, -92, 4.6, 0, 7); ctx.fill();
  ctx.fillStyle = C.dark; ctx.fillRect(-1.5, -86, 3, 4);
  ctx.strokeStyle = C.dark; ctx.lineWidth = 1.5; ctx.beginPath(); for (var j = -6; j <= 6; j += 4) { ctx.moveTo(j, -79); ctx.lineTo(j, -73); } ctx.stroke();
  ctx.restore();
  if (e.bind > 0 && e.state === 'walk') { // 拘束の輪（足元と腰）。切れる直前は薄くなる
    var al = Math.min(1, e.bind / 0.25) * 0.9, wob = 1 + 0.06 * Math.sin(e.t * 14);
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.strokeStyle = 'rgba(160,130,255,' + al + ')'; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.ellipse(e.x, e.y, 30 * sc * wob, 8 * sc * wob, 0, 0, 7); ctx.stroke();
    ctx.beginPath(); ctx.ellipse(e.x, e.y - 40 * sc, 22 * sc, 6 * sc, 0, 0, 7); ctx.stroke();
    ctx.restore();
  }
}

function drawFx() {
  var i, f, p;
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  for (i = 0; i < G.fx.length; i++) {
    f = G.fx[i]; p = f.t / f.life;
    if (f.type === 'arc') {
      ctx.save(); ctx.translate(f.x, f.y - 95 * depthScale(f.y)); ctx.scale(f.face, 1);
      var rx = f.R * (0.55 + 0.45 * Math.min(1, p * 1.6)), ry = f.second ? 70 : 110;
      ctx.strokeStyle = 'rgba(190,232,255,' + (1 - p) + ')'; ctx.lineWidth = (f.big ? 56 : 40) * (1 - p) + 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.ellipse(0, f.second ? 30 : 0, rx, ry, 0, f.second ? -0.9 : -1.75, f.second ? 0.9 : 0.75); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,' + (0.9 * (1 - p)) + ')'; ctx.lineWidth = (f.big ? 16 : 10) * (1 - p) + 1;
      ctx.beginPath(); ctx.ellipse(0, f.second ? 30 : 0, rx * 0.97, ry * 0.97, 0, f.second ? -0.8 : -1.6, f.second ? 0.8 : 0.65); ctx.stroke();
      ctx.restore();
    } else if (f.type === 'lance') { // 突きの光：前へ一気に伸びる細い槍
      ctx.save(); ctx.translate(f.x, f.y - 95 * depthScale(f.y)); ctx.scale(f.face, 1);
      var Ll = f.R * Math.min(1, p * 3.2), fl = 1 - p, wl = 36 * fl + 2;
      ctx.fillStyle = 'rgba(120,190,255,' + (0.55 * fl) + ')'; ctx.beginPath(); ctx.moveTo(40, 0); ctx.lineTo(40 + Ll * 0.15, -wl); ctx.lineTo(40 + Ll, 0); ctx.lineTo(40 + Ll * 0.15, wl); ctx.closePath(); ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,' + (0.95 * fl) + ')'; ctx.beginPath(); ctx.moveTo(40, 0); ctx.lineTo(40 + Ll * 0.15, -wl * 0.35); ctx.lineTo(40 + Ll, 0); ctx.lineTo(40 + Ll * 0.15, wl * 0.35); ctx.closePath(); ctx.fill();
      ctx.restore();
    } else if (f.type === 'ring') {
      ctx.strokeStyle = 'rgba(' + (f.rgb || '255,205,110') + ',' + (1 - p) + ')'; ctx.lineWidth = 16 * (1 - p) + 2;
      ctx.beginPath(); ctx.ellipse(f.x, f.y, f.R * p, f.R * 0.4 * p, 0, 0, 7); ctx.stroke();
      ctx.fillStyle = 'rgba(' + (f.rgb2 || '255,170,60') + ',' + (0.18 * (1 - p)) + ')'; ctx.beginPath(); ctx.ellipse(f.x, f.y, f.R * p, f.R * 0.4 * p, 0, 0, 7); ctx.fill();
    } else if (f.type === 'suck') { // 一点へ縮む渦
      for (var r = 0; r < 3; r++) {
        var q = (p * 1.5 + r / 3) % 1;
        ctx.strokeStyle = 'rgba(' + (f.rgb || '175,150,255') + ',' + (0.9 * q * (1 - p)) + ')'; ctx.lineWidth = 7 * q + 1;
        ctx.beginPath(); ctx.ellipse(f.x, f.y - 30, 170 * (1 - q) + 8, 70 * (1 - q) + 3, 0, 0, 7); ctx.stroke();
      }
    } else if (f.type === 'pline') { // 引き寄せの軌跡
      ctx.strokeStyle = 'rgba(190,170,255,' + (0.55 * (1 - p)) + ')'; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(f.x1, f.y1 - 50); ctx.lineTo(f.x2, f.y2 - 50); ctx.stroke();
    } else if (f.type === 'ultarc') { // 回転斬りの弧：下から前へ、一気に振り上がる
      ctx.save(); ctx.translate(f.x, f.y - 130); ctx.scale(f.face, 1);
      var sw = Math.min(1, p * 2.4), rx = f.small ? 380 : 600, ry = f.small ? 150 : 230, a0 = 1.2, a1 = a0 - 2.6 * sw;
      var fa = 1 - Math.max(0, p - 0.35) / 0.65, wd = (f.small ? 36 : 70) * (1 - p * 0.6); ctx.lineCap = 'round';
      ctx.strokeStyle = 'rgba(120,190,255,' + (0.55 * fa) + ')'; ctx.lineWidth = wd * 1.8; ctx.beginPath(); ctx.ellipse(40, 0, rx, ry, 0, a0, a1, true); ctx.stroke();
      ctx.strokeStyle = 'rgba(190,235,255,' + (0.9 * fa) + ')'; ctx.lineWidth = wd; ctx.beginPath(); ctx.ellipse(40, 0, rx, ry, 0, a0, a1, true); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,' + fa + ')'; ctx.lineWidth = wd * 0.35; ctx.beginPath(); ctx.ellipse(40, 0, rx, ry, 0, a0, a1, true); ctx.stroke();
      ctx.restore();
    } else if (f.type === 'shock') { // 地面を走る衝撃波（前後へ）
      var sx0 = f.x + f.dir * (60 + 760 * p), fa2 = 1 - p;
      ctx.strokeStyle = 'rgba(255,240,205,' + fa2 + ')'; ctx.lineWidth = 14 * fa2 + 2; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.ellipse(sx0, f.y - 30, 46, 96, 0, -Math.PI / 2, Math.PI / 2, f.dir < 0); ctx.stroke();
      ctx.strokeStyle = 'rgba(190,225,255,' + (0.5 * fa2) + ')'; ctx.lineWidth = 5;
      ctx.beginPath(); ctx.moveTo(f.x + f.dir * 40, f.y); ctx.lineTo(sx0, f.y); ctx.stroke();
    } else if (f.type === 'boom') {
      ctx.strokeStyle = 'rgba(255,120,60,' + (1 - p) + ')'; ctx.lineWidth = 8 * (1 - p) + 1;
      ctx.beginPath(); ctx.ellipse(f.x, f.y - 30, f.R * p, f.R * 0.5 * p, 0, 0, 7); ctx.stroke();
    }
  }
  for (i = 0; i < G.parts.length; i++) {
    p = G.parts[i]; ctx.globalAlpha = 1 - p.t / p.life; ctx.fillStyle = p.c; ctx.fillRect(p.x, p.y, p.s, p.s);
  }
  ctx.restore();
}

function drawDrops() {
  for (var i = 0; i < G.drops.length; i++) {
    var d = G.drops[i], col = d.type === 3 ? '#e8b85a' : d.type === 2 ? '#d48cff' : d.type === 1 ? '#7ec8ff' : '#fff2b8', r = d.type === 3 ? 9 : d.type === 2 ? 9 : d.type === 1 ? 7 : 5;
    var y = d.y - d.z - 6;
    ctx.save(); ctx.translate(d.x, y);
    ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = col; ctx.globalAlpha = 0.25;
    ctx.beginPath(); ctx.arc(0, 0, r * 2.6, 0, 7); ctx.fill(); ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over'; ctx.rotate(Math.PI / 4 + d.t * 3);
    ctx.fillStyle = col; ctx.fillRect(-r * 0.7, -r * 0.7, r * 1.4, r * 1.4);
    ctx.restore();
  }
}

function txt(s, x, y, size, col, align, w) {
  ctx.font = '700 ' + size + 'px "DMincho","Hiragino Mincho ProN","Yu Mincho",serif';
  var mw = ctx.measureText(s).width; // 縦画面は幅が狭いので、はみ出す文字は小さくする
  if (mw > W - 24) { size = size * (W - 24) / mw; ctx.font = '700 ' + size + 'px "DMincho","Hiragino Mincho ProN","Yu Mincho",serif'; if (w) w = Math.max(2, w * (W - 24) / mw); }
  ctx.textAlign = align || 'left'; ctx.textBaseline = 'alphabetic';
  ctx.lineJoin = 'round'; ctx.lineWidth = w || Math.max(3, size / 6); ctx.strokeStyle = 'rgba(8,6,12,0.9)';
  ctx.strokeText(s, x, y); ctx.fillStyle = col; ctx.fillText(s, x, y);
}

function drawHud() {
  if (G.phase === 'go' && G.state === 'play' && !G.trans && Math.floor(G.t * 2.5) % 2 === 0) txt('GO →', W - 90, VH / 2, 58, '#ffd27a', 'center'); // 全滅したら、進む先を点滅で示す
  if (G.combo >= 2) {
    var s = 34 + Math.min(G.combo, 40) * 0.9;
    txt(G.combo + ' COMBO', W - 24, 60 + (s - 34) * 0.4, s, '#ff9a5a', 'right');
    ctx.fillStyle = 'rgba(255,154,90,0.85)'; ctx.fillRect(W - 24 - 180 * (G.comboT / 2.4), 72 + (s - 34) * 0.4, 180 * (G.comboT / 2.4), 5);
  }
  // スキルの残り時間は、下の段のボタンに出す（updateTouchCd）
}
function skillIcon(cx, cy, key, label, cd, max, ring, keyCol) {
  var r = 36, ready = cd <= 0;
  ctx.fillStyle = 'rgba(8,6,12,0.75)'; ctx.beginPath(); ctx.arc(cx, cy, r, 0, 7); ctx.fill();
  ctx.strokeStyle = ready ? ring : '#5a5066'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(cx, cy, r, 0, 7); ctx.stroke();
  if (!ready) { ctx.fillStyle = 'rgba(120,100,150,0.45)'; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, r - 3, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * (cd / max)); ctx.closePath(); ctx.fill(); }
  txt(key, cx, cy + 8, 22, ready ? keyCol : '#8a80a0', 'center', 3);
  txt(label, cx, cy + r + 20, 14, '#cfc6dc', 'center', 3);
}

function pickRect(i) { return { x: 24, y: 200 + i * 165, w: W - 48, h: 150 }; } // 強化のカード（720の枠の中の座標）
function drawOverlay() { if (G.state === 'title' || G.state === 'result' || G.state === 'dead') return; var oy = (VH - 720) / 2; ctx.save(); ctx.translate(0, oy); drawOverlay0(oy); ctx.restore(); }
function drawOverlay0(oy) {
  var i;
  if (G.state === 'result') {
    ctx.fillStyle = G.result ? 'rgba(10,8,4,0.72)' : 'rgba(30,4,8,0.72)'; ctx.fillRect(0, -oy, W, VH);
    txt(G.result ? '勝利' : '敗北', W / 2, 250, 72, G.result ? '#ffd27a' : '#ff6b6b', 'center');
    txt(BAT.name + '　突破 ' + (G.result ? BAT.waves : Math.max(0, G.wave - 1)) + '／' + BAT.waves + '　撃破 ' + G.kills + '　最大コンボ ' + G.bestCombo, W / 2, 330, 26, '#fff', 'center');
    if (G.resT > 0.8) txt('タップ、またはキーで領地へ戻る', W / 2, 470, 30, '#ffd27a', 'center');
    return;
  }
  if (G.state === 'title' && BAT.on) {
    ctx.fillStyle = 'rgba(6,4,10,0.66)'; ctx.fillRect(0, -oy, W, VH);
    txt('出撃：' + BAT.name, W / 2, 230, 56, '#ffd27a', 'center');
    txt('戦場 ' + BAT.waves + ' つを突破すれば勝利', W / 2, 300, 32, '#ece6f2', 'center');
    var mods = []; if (BAT.dmg > 1) mods.push('ダメージ+' + Math.round((BAT.dmg - 1) * 100) + '%'); if (BAT.bind) mods.push('拘束+' + BAT.bind + '秒'); if (BAT.hp) mods.push('最大HP+' + BAT.hp);
    if (mods.length) txt('仲間の補正：' + mods.join('・'), W / 2, 352, 24, '#c9bcff', 'center');
    txt('移動 ←↑↓→　攻撃 J　衝撃波 K　吸引 L　必殺 U　（スマホはパッドとボタン）', W / 2, 420, 20, '#cfc6dc', 'center');
    txt('クリック、またはキーを押して開始', W / 2, 520, 30, '#fff', 'center');
    return;
  }
  if (G.state === 'title') {
    ctx.fillStyle = 'rgba(6,4,10,0.62)'; ctx.fillRect(0, -oy, W, VH);
    txt('月夜の回廊（試作）', W / 2, 250, 64, '#ffd27a', 'center');
    txt('群れを、一振りで薙ぎ払え。', W / 2, 310, 28, '#ece6f2', 'center');
    txt('移動  ←↑↓→ / WASD　　走る  Shift　　攻撃  J / Space', W / 2, 390, 22, '#cfc6dc', 'center');
    txt('吸引（集めて拘束）  L　　衝撃波（一掃）  K　　→  L のあとに K', W / 2, 426, 22, '#c9bcff', 'center');
    txt('必殺  U（回転斬り・周囲一掃）　　吸引 → 必殺 でほぼ全滅', W / 2, 462, 22, '#ffb3b3', 'center');
    txt('下の段：左の丸いパッドと、右のボタン', W / 2, 498, 20, '#9d93ab', 'center');
    txt('クリック、またはキーを押して開始', W / 2, 560, 30, '#fff', 'center');
    return;
  }
  if (G.state === 'pick') {
    ctx.fillStyle = 'rgba(6,4,10,0.7)'; ctx.fillRect(0, -oy, W, VH);
    txt('WAVE ' + G.wave + ' クリア！ 強化を1つ選ぶ', W / 2, 120, 40, '#ffd27a', 'center');
    txt('1 / 2 / 3 キー、またはタップで選ぶ', W / 2, 165, 20, '#9d93ab', 'center');
    for (i = 0; i < 3; i++) {
      var u = UPG[G.pickOpts[i]], pr = pickRect(i), mx = pr.x + 70 + (pr.w - 70) / 2;
      ctx.fillStyle = 'rgba(30,22,42,0.96)'; ctx.fillRect(pr.x, pr.y, pr.w, pr.h);
      ctx.strokeStyle = '#ffb347'; ctx.lineWidth = 3; ctx.strokeRect(pr.x, pr.y, pr.w, pr.h);
      txt(String(i + 1), pr.x + 34, pr.y + 90, 48, '#ffb347', 'center');
      wrapText(u.name, mx, pr.y + 52, pr.w - 100, 28, '#fff', 'center', 2);
      wrapText(u.desc, mx, pr.y + 100, pr.w - 100, 19, '#b9b0c8', 'center', 1);
    }
  }
  if (G.state === 'dead') {
    ctx.fillStyle = 'rgba(30,4,8,0.72)'; ctx.fillRect(0, -oy, W, VH);
    txt('やられた…', W / 2, 250, 66, '#ff6b6b', 'center');
    txt('到達 WAVE ' + G.wave + '　撃破 ' + G.kills + '　最大コンボ ' + G.bestCombo + '　素材 ' + G.gold, W / 2, 330, 28, '#fff', 'center');
    if (G.upgraded.length) wrapText('強化：' + G.upgraded.join(' / '), W / 2, 390, W - 60, 18, '#cfc6dc', 'center', 2);
    txt('R キー、またはタップでやり直す', W / 2, 500, 28, '#ffd27a', 'center');
  }
}

function wrapText(s, x, y, maxW, size, col, align, lh) {
  ctx.font = '700 ' + size + 'px "DMincho","Hiragino Mincho ProN","Yu Mincho",serif';
  var line = '', lines = [];
  for (var i = 0; i < s.length; i++) {
    var t = line + s[i];
    if (ctx.measureText(t).width > maxW && line) { lines.push(line); line = s[i]; } else line = t;
  }
  lines.push(line);
  for (var k = 0; k < lines.length; k++) txt(lines[k], x, y + k * size * (1 + (lh || 2) * 0.1 + 0.25), size, col, align, 3);
}

var CDB = null;
function updateTouchCd() { // スキルボタンの円グラフ（残り時間の割合）と、使えない間の暗さ
  if (!CDB) CDB = [['btnP', 'pullCD', function () { return G.pullMax * S.pcd; }], ['btnS', 'skCD', function () { return G.skMax * S.cd; }], ['btnT', 'thrCD', function () { return G.thrMax; }], ['btnU', 'ultCD', function () { return G.ultMax; }], ['btnD', 'dodgeCD', function () { return G.dodgeMax; }]].map(function (d) { return { el: document.getElementById(d[0]), key: d[1], max: d[2], last: -1 }; });
  for (var i = 0; i < CDB.length; i++) {
    var b = CDB[i], v = Math.round(Math.max(0, Math.min(1, G[b.key] / b.max())) * 50) / 50;
    if (v === b.last || !b.el.style || !b.el.style.setProperty) continue;
    b.last = v; b.el.style.setProperty('--cd', String(v)); if (b.el.classList) b.el.classList.toggle('cool', v > 0);
  }
}
// 背景：元絵(BW×H)を横にも縦にも並べる。隣どうしは鏡写しにして、つなぎ目の絵柄を合わせる（部屋ごとの一枚絵ができたら差し替える）
var FLC = null; // 床の上端を溶かした画像（読み込み後に一度だけ作る）
function drawStage() { // 奥の背景（視差つき・鏡写しで繰り返し）＋ 床（1:1・横に繰り返せる）
  var bk = IMG.s1_back, fl = IMG.s1_floor, hz = ROOM.hz, m = G.shake > 0.5 ? 12 : 0;
  var bk0 = Math.min(0, TOPY), bw = BW * (hz - bk0) / hz, bh = hz + 8; // 背景は地平線の少し下まで描き、床の溶けた上端の下に敷く。縦画面で上に空きが出るときは、縦横比を保ったまま拡大して上端まで覆う
  ctx.fillStyle = '#16171f'; ctx.fillRect(camX - m, camY + TOPY - m, W + 2 * m, VH + 2 * m);
  var off = camX * ROOM.par, i0 = Math.floor((off - m) / bw), i1 = Math.floor((off + W + m - 0.01) / bw);
  for (var i = i0; i <= i1; i++) {
    ctx.save(); ctx.translate(i * bw - off + camX, 0);
    if (((i % 2) + 2) % 2) { ctx.translate(bw, 0); ctx.scale(-1, 1); }
    ctx.drawImage(bk, 0, 0, bk.naturalWidth, bk.naturalHeight, 0, bk0, bw + 1, hz - bk0 + 1); ctx.restore();
  }
  ctx.fillStyle = '#1b1c26'; ctx.fillRect(camX - m, hz, W + 2 * m, H - hz + m);
  if (!FLC) {
    FLC = document.createElement('canvas'); FLC.width = fl.naturalWidth; FLC.height = fl.naturalHeight;
    var c = FLC.getContext('2d'); c.drawImage(fl, 0, 0);
    var g = c.createLinearGradient(0, 0, 0, 90); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,1)');
    c.globalCompositeOperation = 'destination-in'; c.fillStyle = g; c.fillRect(0, 0, FLC.width, FLC.height);
  }
  var sc = (H - hz) / FLC.height, fw = FLC.width * sc;
  var j0 = Math.floor((camX - m) / fw), j1 = Math.floor((camX + W + m - 0.01) / fw);
  for (var j = j0; j <= j1; j++) {
    var fx = Math.round(j * fw), fwd = Math.ceil(fw) + 1;
    ctx.drawImage(FLC, 0, 0, FLC.width, FLC.height, fx, hz, fwd, H - hz); // 縮尺は一定のまま（揺れの余白で伸ばさない）
    if (m) ctx.drawImage(FLC, 0, FLC.height - 1, FLC.width, 1, fx, H, fwd, m); // 揺れで見える下端の余白は、最下段を伸ばして埋める
  }
  var mg = ctx.createLinearGradient(0, hz - 16, 0, hz + 70); mg.addColorStop(0, 'rgba(70,74,96,0)'); mg.addColorStop(0.3, 'rgba(70,74,96,0.42)'); mg.addColorStop(1, 'rgba(70,74,96,0)'); // 地平線に薄い霧
  ctx.fillStyle = mg; ctx.fillRect(camX - m, hz - 16, W + 2 * m, 86);
}
var FB = { back1: 830, fl0: 835, fl1: 1150 }, FLF = null; // duel.jpg（1086×1448）の切り分け：0〜830＝奥（空・山・城）、835〜1150＝土の帯
function drawField() {
  var im = IMG.fbk, hz = ROOM.hz, m = G.shake > 0.5 ? 12 : 0, top = camY + TOPY - m;
  ctx.fillStyle = '#a9c9e8'; ctx.fillRect(camX - m, top, W + 2 * m, CVH() + 2 * m);
  if (!im || !im.naturalWidth) return;
  var ks = (hz + 100 - Math.min(0, TOPY)) / FB.back1, bw = im.naturalWidth * ks, bh = FB.back1 * ks, by = hz + 100 - bh; // 床の溶ける幅（90）より下まで描く // 奥：上端まで覆う大きさ。地平線の少し下まで描く
  var off = camX * ROOM.par, i0 = Math.floor((off - m) / bw), i1 = Math.floor((off + W + m - 0.01) / bw);
  for (var i = i0; i <= i1; i++) {
    ctx.save(); ctx.translate(i * bw - off + camX, 0);
    if (((i % 2) + 2) % 2) { ctx.translate(bw, 0); ctx.scale(-1, 1); }
    ctx.drawImage(im, 0, 0, im.naturalWidth, FB.back1, 0, by, bw + 1, bh); ctx.restore();
  }
  if (!im.complete) return; // 読み込みの途中で切り出すと、空の床のまま残る
  if (!FLF) { // 床：土の帯を切り出し、上端を溶かす（一度だけ）
    FLF = document.createElement('canvas'); FLF.width = im.naturalWidth; FLF.height = im.naturalHeight - FB.fl0; // 土の帯から絵の下端まで（1150より下＝手前の草と花は、操作盤の後ろに見える）
    var c = FLF.getContext('2d'); c.drawImage(im, 0, FB.fl0, im.naturalWidth, FLF.height, 0, 0, FLF.width, FLF.height);
    var g = c.createLinearGradient(0, 0, 0, 90); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(0,0,0,1)');
    c.globalCompositeOperation = 'destination-in'; c.fillStyle = g; c.fillRect(0, 0, FLF.width, FLF.height);
  }
  var sc = (H - hz) / (FB.fl1 - FB.fl0), fw = FLF.width * sc, bot = camY + TOPY + CVH() + m; // 縮尺は従来どおり（土の帯 835〜1150 が 地平線〜y720）
  var fh = Math.max(FLF.height * sc, bot - hz); // 操作盤の後ろ（1150より下＝手前のぼかした草花）が足りない画面では、その部分だけ縦に伸ばす
  var j0 = Math.floor((camX - m) / fw), j1 = Math.floor((camX + W + m - 0.01) / fw);
  for (var j = j0; j <= j1; j++) {
    ctx.save(); ctx.translate(Math.round(j * fw), hz);
    if (((j % 2) + 2) % 2) { ctx.translate(Math.ceil(fw), 0); ctx.scale(-1, 1); } // 鏡写しで継ぎ目を合わせる
    var f1 = FB.fl1 - FB.fl0, w1 = Math.ceil(fw) + 1;
    ctx.drawImage(FLF, 0, 0, FLF.width, f1, 0, 0, w1, H - hz);
    ctx.drawImage(FLF, 0, f1 - 1, FLF.width, FLF.height - f1 + 1, 0, H - hz - 1, w1, fh - (H - hz) + 1); ctx.restore();
  }
}
function drawBg() {
  if (ROOM.stage === 'field') { drawField(); return; }
  if (ROOM.stage && IMG.s1_back && IMG.s1_back.naturalWidth && IMG.s1_floor && IMG.s1_floor.naturalWidth) { drawStage(); return; }
  var im = IMG.bg; if (!im || !im.naturalWidth) return;
  var m = G.shake > 0.5 ? 12 : 0; // 画面の揺れで端が見えないよう、揺れている間だけ余白を描く
  var i0 = Math.floor((camX - m) / BW), i1 = Math.floor((camX + W + m - 0.01) / BW);
  var j0 = Math.floor((camY + TOPY - m) / H), j1 = Math.floor((camY + H + m - 0.01) / H);
  for (var j = j0; j <= j1; j++) for (var i = i0; i <= i1; i++) {
    ctx.save(); ctx.translate(i * BW, j * H);
    if (((i % 2) + 2) % 2) { ctx.translate(BW, 0); ctx.scale(-1, 1); }
    if (((j % 2) + 2) % 2) { ctx.translate(0, H); ctx.scale(1, -1); }
    ctx.drawImage(im, 0, 0, BW + 1, H + 1); ctx.restore();
  }
}
function draw() {
  if (resTick++ % 30 === 0) fitRes();
  updateTouchCd();
  ctx.setTransform(RES, 0, 0, RES, 0, 0);
  ctx.save();
  ctx.clearRect(0, 0, W, CVH());
  var sx = G.shake ? (Math.random() - 0.5) * G.shake : 0, sy = G.shake ? (Math.random() - 0.5) * G.shake : 0;
  ctx.translate(sx, sy);
  ctx.save(); ctx.translate(-camX, -camY - TOPY); // ここから世界座標（カメラ追従）。HUDと暗転は、あとで画面座標に戻して描く
  drawBg();
  var h0 = G.hero; // 必殺技の溜め中は、背景を暗くして、主人公と敵を目立たせる
  if (G.state === 'play' && h0.state === 'atk' && h0.kind === 'ult' && h0.t < ULT.hit + 0.02) {
    ctx.fillStyle = 'rgba(6,4,14,' + (0.5 * Math.min(1, h0.t / 0.5)) + ')'; ctx.fillRect(camX - 10, camY + TOPY - 10, W + 20, CVH() + 20);
  }
  var list = [];
  G.enemies.forEach(function (e) { list.push({ y: e.y, f: function () { drawFoe(e); } }); });
  if (G.state !== 'title') list.push({ y: G.hero.y, f: drawHero });
  else list.push({ y: G.hero.y, f: function () { G.hero.anim += 0.016; drawHero(); } });
  list.sort(function (a, b) { return a.y - b.y; });
  list.forEach(function (o) { o.f(); });
  drawDrops(); drawFx();
  G.texts.forEach(function (t) {
    ctx.globalAlpha = Math.min(1, (t.life - t.t) / 0.3);
    txt(t.s, t.x, t.y, t.size, t.col, 'center');
    ctx.globalAlpha = 1;
  });
  ctx.restore(); // 世界座標ここまで
  ctx.restore();
  if (G.flash > 0) { ctx.fillStyle = 'rgba(255,255,255,' + Math.min(1, G.flash) + ')'; ctx.fillRect(0, 0, W, CVH()); }
  if (G.state !== 'title') drawHud();
  uiTick();
  drawOverlay();
  if (G.trans) { // 部屋の移動：暗転→部屋名→明転
    var tk = G.trans.t, ta = tk < 0.5 ? tk / 0.5 : Math.max(0, (1 - tk) / 0.5);
    ctx.fillStyle = 'rgba(0,0,0,' + Math.min(1, ta) + ')'; ctx.fillRect(0, 0, W, CVH());
    if (tk > 0.3 && tk < 0.85) { ctx.globalAlpha = Math.min(1, ta * 1.5); txt(ROOMS[(G.roomNo + (G.trans.sw ? 0 : 1)) % ROOMS.length].name, W / 2, VH / 2 + 10, 44, '#ffd27a', 'center'); ctx.globalAlpha = 1; }
  }
}
