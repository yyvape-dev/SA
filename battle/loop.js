// 月夜の回廊（縦画面版）：ループと起動、テスト用の窓口。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* ---------- ループ ---------- */
var last = 0;
function frame(ts) {
  var dt = Math.min(0.05, (ts - last) / 1000 || 0.016); last = ts;
  update(dt); draw();
  requestAnimationFrame(frame);
}
function boot() {
  document.getElementById('loadnote').textContent = failed
    ? '読み込めない素材が ' + failed + ' 個あります。ページを開き直してください。'
    : '読み込み完了。画面をクリックして始めます。';
  started = true; newGame();
  if (document.fonts && document.fonts.load) document.fonts.load('900 20px "Zen Kaku Gothic New"').catch(function () {});
}
newGame();
loadAll();
requestAnimationFrame(frame);

var fsBtn = document.getElementById('fs');
function fsFail() { fsBtn.textContent = 'この表示では全画面にできません'; }
fsBtn.addEventListener('click', function () {
  var st = document.getElementById('stage');
  try {
    if (document.fullscreenElement) document.exitFullscreen();
    else if (st.requestFullscreen) st.requestFullscreen().catch(fsFail);
    else fsFail();
  } catch (e) { fsFail(); }
});

// テスト用（遊びには影響しない）
window.__game = { get: function () { return G; }, stats: function () { return S; }, press: onPress,
  cam: function () { return { x: camX, y: camY, W: W, VH: VH, RW: RW(), room: ROOM, LK: LK }; }, setRoom: function (r) { ROOMS[0] = r; enterRoom(0); } };
