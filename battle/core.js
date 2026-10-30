// 月夜の回廊（縦画面版）：座標・キャンバス・素材の読み込み・部屋・状態・出撃の受け渡し。
// battle/ の各ファイルは classic script で、上から順に読み込む（トップレベルの var と function は共有）。
'use strict';
/* 縦画面の座標：世界の床の基準は従来どおり H=720（下端＝y720）。キャンバスの論理サイズは W×VH。
   VH≧720 のときは、世界の y<0（上の空き）まで見せて、カメラを引いた状態にする。TOPY＝画面の上端に来る世界の y。
   PW＝横に見せたい世界の幅の目安（大きくすると引きになり、敵が多く見えるがキャラは小さくなる）。 */
/* キャンバスは操作盤の後ろまで伸びる（操作盤の背景＝戦場の床の続き）。VH＝操作盤より上の見える高さ、EXT＝操作盤の後ろの高さ。CVH()＝キャンバス全体の高さ */
var PW = 760, W = 760, H = 720, VH = 955, EXT = 0, TOPY = 720 - 955, BW = 1280; // BW=絵の基準の幅（部屋の長さは W/BW の比で縮める）
var cv = document.getElementById('game'), ctx = cv.getContext('2d');
cv.width = W; cv.height = VH;
function CVH() { return VH + EXT; }
function fitW() {
  var fd = document.getElementById('field'), r = fd ? fd.getBoundingClientRect() : null, ce = document.getElementById('ctl'), rc = ce ? ce.getBoundingClientRect() : null;
  if (!r || !(r.width > 0) || !(r.height > 0)) return false;
  var ch = rc && rc.height > 0 ? Math.min(r.height * 0.7, rc.height) : 0, vh = r.height - ch;
  var a = r.width / vh, nvh = Math.max(720, Math.min(1000, Math.round(PW / a))), nw = Math.round(nvh * a), next = Math.round(ch * nw / r.width);
  if (Math.abs(nw - W) < 2 && Math.abs(nvh - VH) < 2 && Math.abs(next - EXT) < 2) return false;
  W = nw; VH = nvh; EXT = next; TOPY = 720 - VH; return true;
}
function RW() { return Math.round(ROOM.w * W / BW); } // 部屋の長さ（戦場 segs 個が隙間なく並ぶよう、見える幅に合わせて縮める）
var TOUCH = !!((window.matchMedia && window.matchMedia('(pointer: coarse)').matches) || (window.location && /[?&]touch=1/.test(window.location.search || '')));
(function () { var w = document.getElementById('wrap'), st = document.getElementById('stage'); if (TOUCH && w && w.classList) { w.classList.add('t'); st.classList.add('t'); } })();
var RES = 1, resTick = 0;
function fitRes() { // 画面に映る実際の大きさに合わせて内部解像度を上げる（最大2倍）。論理座標は1280×720のまま
  fitW();
  var r = cv.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
  var want = Math.max(1, Math.min(2, Math.round((Math.min(r.width / W, r.height / CVH()) * dpr) * 4) / 4));
  if (!(r.width > 0)) want = RES;
  if (want !== RES || cv.width !== Math.round(W * want) || cv.height !== Math.round(CVH() * want)) { RES = want; cv.width = Math.round(W * RES); cv.height = Math.round(CVH() * RES); }
  ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
}

/* ---------- 素材 ---------- */
var RUN_K = 0.93; /* 2026-10-30 頭の大きさを待機とそろえた（0.86では走ると約17%縮んで見えた） */ // 走りの動画はキャラが約1.15倍の大きさで出たため、足元を基準に縮める
var M = { ax: 362, ay: 379, k: 0.6, clips: { walk: 24, run: 10, atk: 19, rec: 17, idle: 1, ult: 59, atb: 49, thr: 24, atc: 33, dmg: 4 } }; // 待機・歩き・走りは1.0倍で保存。0.6倍で描くと従来と同じ大きさ
var ATK_A = { ax: 235.2, ay: 328.2, k: 1 }; // 攻撃・構え直しは旧素材（0.6倍で保存）。攻撃の動画を撮り直したら置き換える
var ATC_A = { ax: 419, ay: 543, k: 0.6 };   // 攻撃A（縦斬り・新）。動画のコマ9〜60から、静止を詰めて使う
var ATB_A = { ax: 458, ay: 536, k: 0.6 };   // 攻撃B（横薙ぎ）。動画のコマ12〜37と50〜72（頭上の静止は省く）
var THR_A = { ax: 553.1, ay: 697, k: 0.508 }; // 貫通の突き。元の絵が大きいので、0.508倍で主人公と同じ背丈
var DMG_A = { ax: 215, ay: 261, k: 0.846 }; // 被弾・死亡（静止画4枚：被弾→のけぞり→踏ん張り→立ち直り）。元絵が小さいので、拡大率で主人公の背丈にそろえた
var ULT_A = { ax: 446, ay: 568, k: 0.6 }, ULT_F0 = 8; // 必殺技の連番は、動画のコマ8〜66。足元の基準は主人公と同じ高さ
var IMG = {}, loaded = 0, total = 1, failed = 0, started = false;
function pad2(n) { return (n < 10 ? '0' : '') + n; }
function onDone() { loaded++; if (loaded >= total) boot(); }
function loadAll() {
  var names = [];
  Object.keys(M.clips).forEach(function (c) { for (var i = 0; i < M.clips[c]; i++) names.push(c + '_' + pad2(i)); });
  total = names.length + 2 + FOE_TYPES.length;
  if (typeof allyLoad === 'function') allyLoad(one); // 参入する仲間の絵（battle/ally.js）
  function one(key, src) { var im = new Image(); im.onload = onDone; im.onerror = function () { failed++; onDone(); }; im.src = src; IMG[key] = im; }
  one('fbk', 'terrain/assets/field/duel.jpg'); // 昼の草原（上＝奥の背景、土の帯＝床）
  FOE_TYPES.forEach(function (n) { one('fw' + n, 'terrain/assets/npc/foewalk_' + n + '.webp'); });
  fetch('terrain/assets/npc/foeduel_meta.json?v=2').then(function (r) { return r.json(); }).then(function (meta) { // 攻撃の連番（一騎打ちと同じ絵。左向き）
    FOE_TYPES.forEach(function (n) { FOE_CLIP[n] = (meta[n] || []).map(function (c, i) { total++; one('fd' + n + '_' + i, 'terrain/assets/npc/' + c.f); return c; }); });
    onDone();
  }).catch(function () { failed++; onDone(); });
  total++; // 横向きの歩き（ユーザー作成、左向き12コマ）。ある種類だけ使い、無い種類は構えの揺れで代用
  fetch('terrain/assets/npc/side_meta.json').then(function (r) { return r.json(); }).then(function (meta) {
    FOE_TYPES.forEach(function (n) { var c = meta['walk_' + n]; if (!c) return; FOE_SW[n] = c; total++; one('sw' + n, 'terrain/assets/npc/' + c.f); });
    onDone();
  }).catch(function () { onDone(); });
  names.forEach(function (n) {
    var im = new Image(); im.onload = onDone; im.onerror = function () { failed++; onDone(); };
    im.src = 'sprites/' + n + '.png'; IMG[n] = im;
  });
}

/* ---------- 敵（赤い兵）：歩き＝4×2のシート（右向き）、攻撃＝一騎打ちの連番（左向き）を速めて流す ---------- */
var FOE_TYPES = [1, 2, 3, 4]; // 1=槍兵 2=赤マントの騎士（強敵） 3=フードの山賊 4=斧の戦士
var FOE_WALK = { 1: { cw: 145, ch: 257, h: 240 }, 2: { cw: 146, ch: 220, h: 210 }, 3: { cw: 145, ch: 211, h: 202 }, 4: { cw: 161, ch: 220, h: 209 } }; // terrain/assets/npc/foewalk_meta.json と同じ
/* 背の高さ（2026-10-30 決定。同じ奥行きで、画面上の頭〜足の高さ。ゲーム全体で共通）：
   ラナ205・ミナ210・セラ210・ランカ202・ガロウ228／槍兵233（穂先込み、頭で210）・騎士212・山賊225・斧212。強敵は×1.12、敵将は×1.38。
   FOE_HK＝FOE_H(200)に掛ける比。絵ごとの実測（歩きの絵で 槍兵201・騎士207・山賊182・斧198）から逆算した値 */
var HEIGHT = { rana: 205, mina: 210, sera: 210, ranka: 202, garou: 228, lily: 224, /* 2026-10-30 212→224：細身で暗い服のため、同じ背でも小さく見えた */ f1: 233, f2: 212, f3: 225, f4: 212 };
var FOE_HK = { 1: 233 / 201, 2: 1.04 * 212 / 207, 3: 0.91 * 225 / 182, 4: 1.04 * 212 / 198 };
var HERO_K = HEIGHT.rana / 219; // ラナの絵は0.6倍で219（実測）。当たり判定はそのまま
var FOE_H = 200, FOE_SPD = 3.3, FOE_CLIP = {}, FOE_SW = {}; // FOE_H＝槍兵の見た目の背の高さ（世界座標。主人公は約220）。攻撃は一騎打ちの2.6倍速
// 一騎打ちの連番の1コマ：詰め直したシート（c.fr、terrain/tools/pack_trim.py）なら、その矩形と元のコマの中でのずれ。なければ格子のマス
function cellOf(c, i) { if (c.fr) { var r = c.fr[i]; return [r[0], r[1], r[2], r[3], r[4], r[5]]; } return [(i % c.cols) * c.cw, Math.floor(i / c.cols) * c.ch, c.cw, c.ch, 0, 0]; }
function eh(e) { return FOE_H * FOE_HK[e.kind] * depthScale(e.y) * e.size; } // 敵の見た目の背の高さ

/* ---------- 定数と状態 ---------- */
/* 部屋＝横に長い一枚。segs 個の「戦場」（画面1つぶんの区画）が並ぶ。
   戦場に入るとカメラが固定され、敵を全滅させるとGOが出て、次の戦場へ進める。最後の戦場は右端の出口から次の部屋へ。
   h が画面の高さ(720)より大きい部屋では、カメラが上下にも追従する（y0〜y1 はその部屋で動ける奥行きの帯。背景の絵ができたら使う）。 */
var ROOMS = [ // 縦画面：横が狭いぶん、奥行きの帯を広くとる（y0〜y1 が 150→295）。segs と w は newGame で出撃の数に合わせる
  { name: '前線', w: BW * 4, h: 720, y0: 400, y1: 695, segs: 4, stage: 'field', hz: 330, par: 0.5, zk: 0.9, ds0: 0.9, ds1: 1.06, /* 奥行きの縮み（2026-10-30 0.82〜1.12 から弱めた） */ spread: 120 }
];
var ROOM = ROOMS[0], LANE_Y0 = ROOM.y0, LANE_Y1 = ROOM.y1, ZK = ROOM.zk || 1, camX = 0, camY = 0;
function setRoomVars() { LANE_Y0 = ROOM.y0; LANE_Y1 = ROOM.y1; ZK = ROOM.zk || 1; }
function LK(k) { return ROOM.segs < 2 ? 0 : Math.round(k * (RW() - W) / (ROOM.segs - 1)); } // k番目の戦場のカメラ位置（画面の左端）
function depthScale(y) { var a = ROOM.ds0 || 0.9, b = ROOM.ds1 || 1.06; return a + (b - a) * ((y - LANE_Y0) / (LANE_Y1 - LANE_Y0)); }
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function rnd(a, b) { return a + Math.random() * (b - a); }
function heroMinX() { return LK(G.seg) + 70; }
function heroMaxX() { return ((G.phase === 'go' && G.seg < ROOM.segs - 1) ? LK(G.seg + 1) : LK(G.seg)) + W - 70; }
function camRange() { var a = LK(G.seg); return (G.phase === 'go' && G.seg < ROOM.segs - 1) ? [a, LK(G.seg + 1)] : [a, a]; } // 戦闘中は min=max（固定）
function updateCam(dt, snap) {
  var h = G.hero, r = camRange(), k = snap ? 1 : Math.min(1, dt * 7), maxY = Math.max(0, ROOM.h - H);
  var tx = clamp(h.x - W * 0.4, r[0], r[1]), ty = clamp(h.y - H * 0.72, 0, maxY);
  camX = clamp(camX + (tx - camX) * k, r[0], r[1]); camY = clamp(camY + (ty - camY) * k, 0, maxY);
}

var keys = {}, pad = { x: 0, y: 0, mag: 0 };
var G, S;
/* ---------- 領地からの出撃（?battle=1）：WAVE waves まで生き残れば勝利。結果を localStorage の battle_result に書いて、領地へ戻る ---------- */
var BAT = (function () { var q = new URLSearchParams(location.search || ''); if (q.get('battle') !== '1') return { on: false };
  return { on: true, id: q.get('id') || '', waves: Math.max(1, +q.get('waves') || 3), name: q.get('name') || '出撃', dmg: +q.get('dmg') || 1, bind: +q.get('bind') || 0, hp: +q.get('hp') || 0, al: (q.get('al') || '').split(',').filter(Boolean), boss: q.get('boss') === '1', ret: q.get('ret') || 'terrain/index.html' }; })();
/* 途中で参入する仲間（battle/ally.js）：領地から渡された候補（al）からランダムに1人。試し（?battle なし）は4人から。?ally=mina で固定。候補が無ければ参入なし */
var ALLY_K = (function () { var q = new URLSearchParams(location.search || ''), f = q.get('ally'), pool = BAT.on ? BAT.al : ['mina', 'garou', 'sera', 'ranka', 'lily'];
  if (f === 'none') return ''; if (f && ['mina', 'garou', 'sera', 'ranka', 'lily'].indexOf(f) >= 0) return f; return pool.length ? pool[Math.floor(Math.random() * pool.length)] : ''; })();
/* 戦場の数：領地の wavesOf は「規模÷7（2〜7）＋2」。前半＝雑兵、JOIN の戦場から仲間が参入して強敵が混じる、最後＝敵将 */
function SEGS() { return BAT.on ? Math.max(3, BAT.waves) : 5; }
function JOIN() { return Math.max(1, Math.floor(SEGS() * 0.4)); } // 仲間が参入する戦場（0始まり）
function finishBattle(win) {
  if (G.state === 'result') return; G.state = 'result'; G.result = !!win; G.resT = 0;
  try { localStorage.setItem('battle_result', JSON.stringify({ id: BAT.id, win: !!win, kills: G.kills, wave: G.wave, sup: G.sup })); } catch (e) { }
}
function backToMap() { if (G.resT < 0.8) return; location.href = BAT.ret; }

function newGame() {
  S = { dmg: 1, range: 1, aspd: 1.75, cd: 1, chain: 0, pcd: 1, bind: 0.8 }; // 強化の選択をやめたぶん、攻撃速度は最初から少し速い（1.5→1.75）
  ROOMS[0].segs = SEGS(); ROOMS[0].w = BW * ROOMS[0].segs;
  ROOM = ROOMS[0]; setRoomVars(); camX = 0; camY = 0;
  G = {
    roomNo: 0, seg: 0, phase: 'fight', trans: null,
    state: 'title', t: 0, wave: 0, enemies: [], drops: [], parts: [], fx: [], texts: [], booms: [],
    queue: [], qT: 0, shake: 0, freeze: 0, combo: 0, comboT: 0, bestCombo: 0, kills: 0, gold: 0, rare: 0, sup: 0, paused: false, fieldTotal: 1,
    ally: null, cutin: null, boss: null, coCD: 0, coMax: 12, skCD: 0, skMax: 3.2, pullCD: 0, pullMax: 6, thrCD: 0, thrMax: 8, ultCD: 0, ultMax: 14, dodgeCD: 0, dodgeMax: 1.1, flash: 0, picks: [], pickOpts: [], upgraded: [],
    hero: { x: 340, y: 560, face: 1, hp: 120, max: 120, state: 'idle', t: 0, anim: 0, sk: false, kind: 'atk', fxT: 0, ringT: 0, h1: false, h2: false, h3: false, v: 0, lastAtkEnd: -9, lastAtkKind: '', x0: 0, buf: 0, cancelT: 0, total: 0, inv: 0, flash: 0, kb: 0, dx: 0, dy: 0, dsx: 0, dsy: 0, trail: [], trT: 0 }
  };
}
