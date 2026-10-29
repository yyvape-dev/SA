// 月夜の回廊（縦画面版）：入力（キー・パッド・ボタン）。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* ---------- 入力 ---------- */
window.addEventListener('keydown', function (e) {
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].indexOf(e.code) >= 0) e.preventDefault();
  if (!keys[e.code]) onPress(e.code);
  keys[e.code] = true;
});
window.addEventListener('keyup', function (e) { keys[e.code] = false; });
window.addEventListener('blur', function () { keys = {}; });

function onPress(code) {
  if (!started) return;
  if ((code === 'Escape' || code === 'KeyP') && (G.state === 'play' || G.paused)) { togglePause(); return; }
  if (G.paused) { if (code === 'Space' || code === 'Enter') togglePause(); return; }
  if (G.state === 'result') { backToMap(); return; }
  if (G.state === 'title') { startRun(); return; }
  if (G.state === 'dead') { if (code === 'KeyR' || code === 'Space' || code === 'Enter') { newGame(); startRun(); } return; }
  if (G.state === 'pick') {
    if (code === 'Digit1' || code === 'Numpad1') choose(0);
    if (code === 'Digit2' || code === 'Numpad2') choose(1);
    if (code === 'Digit3' || code === 'Numpad3') choose(2);
    return;
  }
  if (code === 'KeyR' && !BAT.on) { newGame(); startRun(); return; }
  if (code === 'KeyJ' || code === 'Space' || code === 'KeyZ') tryAttack('atk');
  if (code === 'KeyK' || code === 'KeyX') tryAttack('sk');
  if (code === 'KeyL' || code === 'KeyC') tryAttack('pull');
  if (code === 'KeyU' || code === 'KeyV') tryAttack('ult');
  if (code === 'KeyI' || code === 'KeyB') tryAttack('thr');
  if (code === 'KeyO' || code === 'KeyN') tryAttack('dodge');
}

function canvasPoint(ev) {
  var r = cv.getBoundingClientRect(), k = Math.min(r.width / W, r.height / CVH());
  var ox = (r.width - W * k) / 2, oy = (r.height - CVH() * k) / 2;
  return { x: (ev.clientX - r.left - ox) / k, y: (ev.clientY - r.top - oy) / k };
}
cv.addEventListener('pointerdown', function (ev) {
  cv.focus();
  if (!started) return;
  var p = canvasPoint(ev);
  if (G.state === 'result') { backToMap(); return; }
  if (G.state === 'title') { startRun(); return; }
  if (G.state === 'dead') { newGame(); startRun(); return; }
  if (G.state === 'pick') {
    for (var i = 0; i < 3; i++) {
      var pr = pickRect(i), py = p.y - (VH - 720) / 2;
      if (p.x >= pr.x && p.x <= pr.x + pr.w && py >= pr.y && py <= pr.y + pr.h) { choose(i); return; }
    }
  }
});

var padEl = document.getElementById('pad'), knob = document.getElementById('knob'), padId = null;
function padMove(ev) {
  var r = padEl.getBoundingClientRect();
  var cx = r.left + r.width / 2, cy = r.top + r.height / 2, R = r.width / 2 - 10;
  var dx = ev.clientX - cx, dy = ev.clientY - cy, d = Math.hypot(dx, dy) || 1;
  var k = Math.min(1, d / R);
  pad.x = dx / d * k; pad.y = dy / d * k; pad.mag = k;
  knob.style.transform = 'translate(' + (pad.x * R * 0.55) + 'px,' + (pad.y * R * 0.55) + 'px)';
}
padEl.addEventListener('pointerdown', function (ev) { padId = ev.pointerId; padEl.setPointerCapture(ev.pointerId); padEl.classList.add('pressed'); padMove(ev); });
padEl.addEventListener('pointermove', function (ev) { if (ev.pointerId === padId) padMove(ev); });
function padEnd(ev) { if (ev.pointerId !== padId) return; padId = null; pad.x = pad.y = pad.mag = 0; knob.style.transform = ''; padEl.classList.remove('pressed'); }
padEl.addEventListener('pointerup', padEnd); padEl.addEventListener('pointercancel', padEnd);
/* 連打・ピンチで画面が拡大されるのを防ぐ */
(function () {
  var lastEnd = 0, opt = { passive: false };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach(function (n) { document.addEventListener(n, function (e) { e.preventDefault(); }, opt); });
  document.addEventListener('touchmove', function (e) { e.preventDefault(); }, opt);
  document.addEventListener('touchstart', function (e) { if (e.touches && e.touches.length > 1) e.preventDefault(); }, opt);
  document.addEventListener('touchend', function (e) { var n = Date.now(); if (n - lastEnd < 350) e.preventDefault(); lastEnd = n; }, opt);
  document.addEventListener('dblclick', function (e) { e.preventDefault(); }, opt);
  document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  window.addEventListener('resize', function () { resTick = 0; });
  window.addEventListener('orientationchange', function () { resTick = 0; });
})();
function tapBtn(id, fn) {
  var el = document.getElementById(id);
  el.addEventListener('pointerdown', function (ev) {
    ev.preventDefault(); el.classList.add('pressed');
    if (!started) return;
    if (G.state === 'result') { backToMap(); return; }
    if (G.state === 'title') { startRun(); return; }
    if (G.state === 'dead') { newGame(); startRun(); return; }
    fn();
  });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach(function (n) { el.addEventListener(n, function () { el.classList.remove('pressed'); }); });
}
// ボタンとパッドの絵は battle/ui/p/ の部品（index.html の img）。差し替えは、同じ名前のファイルを置くか slice_ui.py を回し直す
tapBtn('btnA', function () { tryAttack('atk'); });
tapBtn('btnS', function () { tryAttack('sk'); });
tapBtn('btnP', function () { tryAttack('pull'); });
tapBtn('btnU', function () { tryAttack('ult'); });
tapBtn('btnT', function () { tryAttack('thr'); });
tapBtn('btnD', function () { tryAttack('dodge'); });
