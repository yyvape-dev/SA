// 月夜の回廊（縦画面版）：画面の部品（上の帯・戦況のバー・重ね表示・一時停止）。見た目は battle/battle.css。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
var UI = null, UIkey = '', UIstate = '';
function uiEls() {
  if (UI) return UI;
  var $ = function (id) { return document.getElementById(id); };
  UI = { hp: $('hpI'), hpT: $('hpT'), ul: $('ulI'), ulW: $('ulW'), wave: $('hWave'), left: $('hLeft'), sup: $('hSup'), g: $('gI'), dia: $('gdia'), ov: $('ov'), pz: $('pz') };
  UI.t1 = UI.ov.querySelector('.t1'); UI.h2 = UI.ov.querySelector('h2'); UI.s1 = UI.ov.querySelector('.s1'); UI.s2 = UI.ov.querySelector('.s2'); UI.row = UI.ov.querySelector('.row');
  UI.pz.addEventListener('click', function () { if (started && (G.state === 'play' || G.paused)) togglePause(); });
  return UI;
}
/* 戦況：0＝敵軍優勢 … 1＝自軍優勢。戦場をどこまで突破したか（今の戦場は倒した割合）と、HPの減りで決める */
function warShare() {
  var alive = G.queue.length + G.enemies.filter(function (e) { return e.state === 'walk'; }).length;
  var frac = G.phase === 'go' ? 1 : 1 - alive / Math.max(1, G.fieldTotal);
  var prog = (G.seg + frac) / Math.max(1, ROOM.segs), h = G.hero;
  if (G.state === 'result') return G.result ? 0.92 : 0.08;
  return clamp(0.35 + 0.55 * prog - 0.25 * (1 - h.hp / h.max), 0.05, 0.95);
}
function uiTick() { // 毎フレーム。変わったときだけ書き換える
  var u = uiEls(), h = G.hero;
  var alive = G.queue.length + G.enemies.filter(function (e) { return e.state === 'walk'; }).length;
  var ulv = G.ultCD > 0 ? 1 - G.ultCD / G.ultMax : 1, share = warShare();
  var key = [Math.ceil(h.hp), h.max, G.seg, ROOM.segs, alive, G.sup, Math.round(ulv * 50), Math.round(share * 100)].join('|');
  if (key !== UIkey) {
    UIkey = key;
    u.hp.style.width = Math.max(0, Math.min(100, 100 * h.hp / h.max)) + '%'; u.hp.className = h.hp / h.max > 0.3 ? '' : 'low';
    u.hpT.textContent = 'HP ' + Math.ceil(h.hp) + ' / ' + h.max;
    u.ul.style.width = (ulv * 100) + '%'; u.ulW.classList.toggle('full', ulv >= 1);
    u.wave.innerHTML = '戦場 <b>' + Math.min(ROOM.segs, G.seg + 1) + ' / ' + ROOM.segs + '</b>';
    u.left.textContent = alive; u.sup.textContent = G.sup;
    u.g.style.width = (share * 100) + '%'; u.dia.style.left = (26.78 + 46.55 * share) + '%';
  }
  var st = G.state + (G.paused ? '+p' : '') + (G.state === 'result' && G.resT > 0.8 ? '+r' : '') + (started ? '' : '-');
  if (st !== UIstate) { UIstate = st; uiShow(); }
}
function uiBtn(label, fn, cls) {
  var b = document.createElement('button'); b.type = 'button'; b.className = 'go' + (cls ? ' ' + cls : ''); b.textContent = label;
  b.addEventListener('click', function (ev) { ev.stopPropagation(); fn(); }); return b;
}
function uiShow() { // 重ね表示の中身を、今の状態に合わせて作り直す
  var u = uiEls(); u.row.innerHTML = ''; u.h2.className = ''; u.s2.textContent = '';
  var on = true;
  if (!started) on = false;
  else if (G.paused) {
    u.t1.textContent = ''; u.h2.textContent = '一時停止'; u.s1.textContent = '';
    u.row.appendChild(uiBtn('再開する', togglePause));
  } else if (G.state === 'title') {
    if (BAT.on) {
      u.t1.textContent = '出撃'; u.h2.textContent = BAT.name; u.s1.textContent = '戦場 ' + BAT.waves + ' つを突破すれば勝利';
      var mods = []; if (BAT.dmg > 1) mods.push('ダメージ+' + Math.round((BAT.dmg - 1) * 100) + '%'); if (BAT.bind) mods.push('拘束+' + BAT.bind + '秒'); if (BAT.hp) mods.push('最大HP+' + BAT.hp);
      if (mods.length) u.s2.textContent = '仲間の補正：' + mods.join('・');
    } else { u.t1.textContent = '試し斬り'; u.h2.textContent = '前線'; u.s1.textContent = '群れを、一振りで薙ぎ払え。'; }
    u.row.appendChild(uiBtn('戦いを始める', function () { startRun(); }));
  } else if (G.state === 'result') {
    u.t1.textContent = BAT.name; u.h2.textContent = G.result ? '勝利' : '敗北'; u.h2.className = G.result ? 'win' : 'lose';
    u.s1.textContent = '突破 ' + (G.result ? BAT.waves : Math.max(0, G.seg)) + ' / ' + BAT.waves + '　撃破 ' + G.kills + '　最大コンボ ' + G.bestCombo;
    u.s2.textContent = '物資 +' + G.sup + '（領地へ持ち帰る）';
    var b = uiBtn('領地へ戻る', backToMap); if (G.resT <= 0.8) b.disabled = true; u.row.appendChild(b);
  } else if (G.state === 'dead') {
    u.t1.textContent = ''; u.h2.textContent = 'やられた…'; u.h2.className = 'lose';
    u.s1.textContent = '突破 ' + G.seg + ' / ' + ROOM.segs + '　撃破 ' + G.kills + '　最大コンボ ' + G.bestCombo;
    u.row.appendChild(uiBtn('やり直す', function () { newGame(); startRun(); }));
  } else on = false;
  u.ov.classList.toggle('on', on);
}
function togglePause() {
  if (!G.paused && G.state !== 'play') return;
  G.paused = !G.paused; keys = {}; pad.x = pad.y = pad.mag = 0;
  uiTick();
}
