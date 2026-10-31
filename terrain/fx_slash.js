// 斬撃のエフェクト（画像なし、Canvas 2D だけ）。将軍戦の一騎打ちで使う。
// 3層（残光・本体・芯）を時間をずらして重ね、先端が明るく根本へ消えるグラデーションを毎フレーム作る。
// 軌道に沿って、速度の向きへ引き延ばした火花をバーストさせる。
// slashFX(host, { x, y, size, dir, big, speed, color })
//   host：重ねる要素（position:relative 以上）／x,y：host 内の当たりの位置(px)／size：斬撃の長さの目安(px)
//   dir：1＝右向きに斬る、-1＝左向き／big：大技（十字に2本）／speed：再生速度の倍率／color：'blue' か 'red'

const PAL = {
  blue: { glow: [90, 170, 255], main: [40, 120, 255], core: [235, 248, 255], spark: [150, 210, 255] },
  red: { glow: [255, 110, 70], main: [235, 50, 30], core: [255, 244, 225], spark: [255, 190, 120] },
};
const rgba = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
/* ===== 2026-10-31 土台：ヒットストップ・ブルーム（調査：Capcom の弱/中/強の止め、Riot/Blizzard の「予兆→当たり→余韻」） =====
   hitStop(ms)：その間、エフェクトの時間（と main.js の clipActor のコマ送り）を止める。重い当たりほど長く。 */
let HOLD = 0;
export const hitStop = ms => { HOLD = Math.max(HOLD, performance.now() + ms); };
export const isHeld = now => now < HOLD;
// ブルーム：光の層を 1/3 の解像度に写し、CSS でぼかして screen で重ねる（光っている所だけがにじむ。WebGL なしの軽い方法）
function bloomOf(cv, z) { const b = document.createElement('canvas'), k = 1 / 3; b.width = Math.max(1, Math.round(cv.width * k)); b.height = Math.max(1, Math.round(cv.height * k));
  b.style.cssText = `position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:${z};mix-blend-mode:screen;filter:blur(5px) brightness(1.25);opacity:.9`;
  cv.after(b); const bx = b.getContext('2d'); return { copy() { bx.clearRect(0, 0, b.width, b.height); bx.drawImage(cv, 0, 0, b.width, b.height); }, remove() { b.remove(); } }; }
const easeOut = t => 1 - Math.pow(1 - t, 3);
const clamp01 = t => Math.max(0, Math.min(1, t));

// 3次ベジェの点と接線
const bz = (p, t) => { const u = 1 - t; return { x: u * u * u * p[0].x + 3 * u * u * t * p[1].x + 3 * u * t * t * p[2].x + t * t * t * p[3].x, y: u * u * u * p[0].y + 3 * u * u * t * p[1].y + 3 * u * t * t * p[2].y + t * t * t * p[3].y }; };
const bzd = (p, t) => { const u = 1 - t; return { x: 3 * u * u * (p[1].x - p[0].x) + 6 * u * t * (p[2].x - p[1].x) + 3 * t * t * (p[3].x - p[2].x), y: 3 * u * u * (p[1].y - p[0].y) + 6 * u * t * (p[2].y - p[1].y) + 3 * t * t * (p[3].y - p[2].y) }; };

// 1本の斬撃の軌道。中心 (x,y) を通る、少し反った三日月の弧
function makeArc(x, y, size, dir, angle, bend) {
  const ca = Math.cos(angle), sa = Math.sin(angle), h = size / 2;
  const nx = -sa, ny = ca; // 弧のふくらむ向き
  const P = (s, b) => ({ x: x + dir * (ca * s + nx * b), y: y + sa * s + ny * b });
  return [P(-h, 0), P(-h * .35, -bend), P(h * .35, -bend), P(h, 0)];
}

// 軌道の u0〜u1 の区間を、太さが変わるリボン（三日月）として塗る
function ribbon(ctx, arc, u0, u1, width, fillStyle) {
  if (u1 - u0 < .005) return;
  const N = 28, L = [], R = [];
  for (let i = 0; i <= N; i++) {
    const s = i / N, u = u0 + (u1 - u0) * s, p = bz(arc, u), d = bzd(arc, u), m = Math.hypot(d.x, d.y) || 1;
    const w = width * Math.pow(Math.sin(Math.PI * Math.min(1, s * 1.15)), .7) * (.25 + .75 * s); // 根本は細く、先端の手前で太く、先端で尖る
    L.push({ x: p.x - d.y / m * w, y: p.y + d.x / m * w }); R.push({ x: p.x + d.y / m * w * .35, y: p.y - d.x / m * w * .35 }); // 外側に厚く、内側は薄く（刃の反り）
  }
  ctx.beginPath(); ctx.moveTo(L[0].x, L[0].y);
  for (let i = 1; i < L.length; i++) ctx.lineTo(L[i].x, L[i].y);
  for (let i = R.length - 1; i >= 0; i--) ctx.lineTo(R[i].x, R[i].y);
  ctx.closePath(); ctx.fillStyle = fillStyle; ctx.fill();
}

// 先端＝明るい、根本＝消える。毎フレーム、いまの根本と先端の位置で作り直す
function grad(ctx, arc, u0, u1, col, a) {
  const t0 = bz(arc, u0), t1 = bz(arc, u1), g = ctx.createLinearGradient(t0.x, t0.y, t1.x, t1.y);
  g.addColorStop(0, rgba(col, 0)); g.addColorStop(.55, rgba(col, a * .35)); g.addColorStop(.9, rgba(col, a)); g.addColorStop(1, rgba(col, a * .6));
  return g;
}

export function slashFX(host, o) {
  const dpr = Math.min(2, window.devicePixelRatio || 1), W = host.clientWidth, H = host.clientHeight;
  const cv = document.createElement('canvas'); cv.width = W * dpr; cv.height = H * dpr;
  cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:7;mix-blend-mode:screen';
  host.appendChild(cv);
  const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr);
  const pal = o.pal || PAL[o.color] || PAL.blue, dir = o.dir || 1, sp = o.speed || 1, size = o.size, BL = o.bloom === false ? null : bloomOf(cv, 7);
  // 斬撃の本数：通常は1本（右上→左下へ振り下ろす）、大技は時間差で2本目が交差する
  const cuts = [{ arc: makeArc(o.x, o.y, size * (o.len || 1.35), dir, o.ang ?? .62, size * (o.bend ?? .3)), t0: 0, w: size * .11 * (o.thick || 1) }];
  if (o.big) cuts.push({ arc: makeArc(o.x, o.y - size * .04, size * 1.45, dir, -.5, size * .26), t0: 110, w: size * .13 });
  const SWING = 130, FADE = 300; // 刃が走る時間・消える時間（ms、×1のとき）
  // 層：lag＝先端の遅れ（ms）、tail＝根本がどれだけ遅れて追うか、w＝太さ、a＝濃さ
  const LAYERS = [
    { key: 'glow', lag: 45, tail: .55, w: 3.2, a: .45 },
    { key: 'main', lag: 18, tail: .42, w: 1.25, a: .95 },
    { key: 'core', lag: 0, tail: .3, w: .42, a: 1 },
  ];
  const sparks = []; let lastU = cuts.map(() => 0);
  const burst = (c, u0, u1) => { // 先端が通った区間に火花を置く（1本あたり計 28 個前後）
    const n = Math.round((u1 - u0) * 34 * (o.big ? 1.3 : 1));
    for (let i = 0; i < n; i++) {
      const u = u0 + Math.random() * (u1 - u0), p = bz(c.arc, u), d = bzd(c.arc, u), m = Math.hypot(d.x, d.y) || 1;
      const v = (.35 + Math.random() * .9) * size * 2.4, spread = (Math.random() - .5) * .7, ca = Math.cos(spread), sa = Math.sin(spread);
      const tx = d.x / m, ty = d.y / m, vx = (tx * ca - ty * sa) * v, vy = (tx * sa + ty * ca) * v - size * .3 * Math.random();
      sparks.push({ x: p.x, y: p.y, vx, vy, life: 0, max: 180 + Math.random() * 380, r: 1 + Math.random() * 2.6 });
    }
  };
  const flash = { at: 40, dur: 160 }; // 当たりの瞬間の光
  let prev = 0, T = 0;
  const frame = now => {
    if (!prev) prev = now; if (isHeld(now)) { prev = now; requestAnimationFrame(frame); return; } // ヒットストップ中は止める
    const dt = Math.min(50, now - prev) * sp / 1000; T += dt * 1000; prev = now;
    ctx.clearRect(0, 0, W, H); ctx.globalCompositeOperation = 'lighter';
    let alive = false;
    cuts.forEach((c, ci) => {
      const t = T - c.t0; if (t < 0) { alive = true; return; }
      const fade = t > SWING ? clamp01(1 - (t - SWING) / FADE) : 1; if (fade > 0) alive = true;
      if (o.arc !== false) for (const Ly of LAYERS) { // arc:false＝弧は WebGL の層（fx_gl.js）が描く。ここは火花と当たりの光だけ
        const head = easeOut(clamp01((t - Ly.lag) / SWING)); if (head <= 0) continue;
        const tailT = easeOut(clamp01((t - Ly.lag - SWING * Ly.tail) / (SWING * 1.4))); // 根本は遅れて追い、最後は先端に追いつく
        const u0 = Math.min(head, tailT * 1.02), u1 = head;
        const a = Ly.a * fade * (Ly.key === 'glow' ? 1 : Math.pow(fade, .6));
        ctx.save(); if (Ly.key === 'glow') { ctx.shadowColor = rgba(pal.glow, .8); ctx.shadowBlur = size * .18; }
        ribbon(ctx, c.arc, u0, u1, c.w * Ly.w * (Ly.key === 'core' ? 1 : .9 + .1 * fade), grad(ctx, c.arc, u0, u1, pal[Ly.key], a));
        ctx.restore();
      }
      const hu = easeOut(clamp01(t / SWING)); if (hu > lastU[ci]) { burst(c, lastU[ci], hu); lastU[ci] = hu; }
      // 当たりの光（芯の先端の少し手前で一瞬）
      const ft = t - flash.at; if (ft > 0 && ft < flash.dur) {
        const k = 1 - ft / flash.dur, p = bz(c.arc, .55), g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, size * .45 * (1.2 - k * .4));
        g.addColorStop(0, rgba(pal.core, .55 * k)); g.addColorStop(.3, rgba(pal.main, .25 * k)); g.addColorStop(1, rgba(pal.main, 0));
        ctx.fillStyle = g; ctx.fillRect(p.x - size, p.y - size, size * 2, size * 2);
      }
    });
    // 火花：速度の向きに引き延ばした細い光。抵抗で減速し、少し落ちる
    for (const s of sparks) {
      s.life += dt * 1000; if (s.life >= s.max) continue; alive = true;
      const k = 1 - s.life / s.max, drag = Math.pow(.02, dt); s.vx *= drag; s.vy = s.vy * drag + size * 1.6 * dt; s.x += s.vx * dt; s.y += s.vy * dt;
      const vl = Math.hypot(s.vx, s.vy), len = Math.min(size * .35, vl * .07) + s.r;
      const ex = s.x - s.vx / (vl || 1) * len, ey = s.y - s.vy / (vl || 1) * len, g = ctx.createLinearGradient(s.x, s.y, ex, ey);
      g.addColorStop(0, rgba(pal.core, k)); g.addColorStop(.35, rgba(pal.spark, .8 * k)); g.addColorStop(1, rgba(pal.spark, 0));
      ctx.strokeStyle = g; ctx.lineWidth = s.r * (.5 + .5 * k); ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(ex, ey); ctx.stroke();
    }
    if (BL) BL.copy();
    if (alive) requestAnimationFrame(frame); else { cv.remove(); BL && BL.remove(); }
  };
  requestAnimationFrame(frame);
  return cv;
}

/* ===== 一騎打ちの残りのエフェクト（2026-10-30）。同じ骨組み：1回＝キャンバス1枚、加算の光、時間差、t から位置 ===== */
PAL.teal = { glow: [70, 230, 200], main: [40, 200, 180], core: [240, 255, 250], spark: [180, 255, 230] };
PAL.red.dark = [40, 0, 0]; PAL.gold = { glow: [255, 170, 40], main: [255, 205, 100], core: [255, 250, 228], spark: [255, 226, 150], dark: [60, 30, 0] };
// キャンバスを重ねて draw(ctx, T, dt) を回す。draw が false を返したら消す
function layer(host, sp, draw, z = 7, blend = 'screen', bloom = false) { // blend＝'normal' のときは、暗い下地を描ける（明るい背景で色を残す）。bloom＝光をにじませる
  const dpr = Math.min(2, window.devicePixelRatio || 1), W = host.clientWidth, H = host.clientHeight;
  const cv = document.createElement('canvas'); cv.width = W * dpr; cv.height = H * dpr;
  cv.style.cssText = `position:absolute;inset:0;width:100%;height:100%;pointer-events:none;z-index:${z};mix-blend-mode:${blend}`;
  host.appendChild(cv); const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr);
  let prev = 0, T = 0, dead = false; const BL = bloom && blend === 'screen' ? bloomOf(cv, z) : null;
  const kill = () => { dead = true; cv.remove(); BL && BL.remove(); };
  const frame = now => { if (dead) return; if (!prev) prev = now; if (isHeld(now)) { prev = now; requestAnimationFrame(frame); return; } const dt = Math.min(50, now - prev) * sp / 1000; T += dt * 1000; prev = now;
    ctx.clearRect(0, 0, W, H); ctx.globalCompositeOperation = 'lighter';
    if (draw(ctx, T, dt) === false) { kill(); return; } BL && BL.copy(); requestAnimationFrame(frame); };
  requestAnimationFrame(frame);
  return { stop: kill, cv };
}
const glow = (ctx, x, y, r, pal, a) => { if (a <= 0) return; const g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, rgba(pal.core, .7 * a)); g.addColorStop(.3, rgba(pal.main, .3 * a)); g.addColorStop(1, rgba(pal.glow, 0)); ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2); };
const streak = (ctx, x, y, vx, vy, len, w, col, a) => { const m = Math.hypot(vx, vy) || 1, ex = x - vx / m * len, ey = y - vy / m * len, g = ctx.createLinearGradient(x, y, ex, ey); g.addColorStop(0, rgba(col, a)); g.addColorStop(1, rgba(col, 0)); ctx.strokeStyle = g; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(ex, ey); ctx.stroke(); };
const star4 = (ctx, x, y, r, rot, col, a) => { ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = rgba(col, a); ctx.beginPath(); for (let i = 0; i < 4; i++) { const th = i * Math.PI / 2; ctx.lineTo(Math.cos(th) * r, Math.sin(th) * r); ctx.lineTo(Math.cos(th + .785) * r * .14, Math.sin(th + .785) * r * .14); } ctx.closePath(); ctx.fill(); ctx.restore(); };
const ring = (ctx, x, y, r, w, col, a, sq = .3) => { if (a <= 0 || r <= 0) return; ctx.strokeStyle = rgba(col, a); ctx.lineWidth = w; ctx.beginPath(); ctx.ellipse(x, y, r, r * sq, 0, 0, 7); ctx.stroke(); };
// 火花の束（t から位置）
const sparkSet = (n, dir, v0, v1, size) => Array.from({ length: n }, () => { const th = (Math.random() - .5) * 2.2 - .35; const v = (v0 + Math.random() * (v1 - v0)) * size; return { vx: (dir || (Math.random() < .5 ? 1 : -1)) * Math.cos(th) * v, vy: Math.sin(th) * v, life: 200 + Math.random() * 380, r: 1 + Math.random() * 2.4 }; });
const drawSparkSet = (ctx, S, x, y, T, pal, size) => { let alive = false; for (const s of S) { const t = T / 1000; if (T > s.life) continue; alive = true; const dr = Math.exp(-t * 4), px = x + s.vx * (1 - dr) / 4, py = y + s.vy * (1 - dr) / 4 + size * .9 * t * t, cvx = s.vx * dr, cvy = s.vy * dr + size * 1.8 * t, k = 1 - T / s.life; streak(ctx, px, py, cvx, cvy, Math.min(size * .3, Math.hypot(cvx, cvy) * .06) + s.r, s.r * (.5 + .5 * k), k > .5 ? pal.core : pal.spark, k); } return alive; };

// 当たりの衝撃：放射の楔＋床の輪＋光。ko＝決着の一撃（金・大きく・長く）
export function impactFX(host, o) {
  const pal = PAL[o.ko ? 'gold' : o.color] || PAL.blue, size = o.size * (o.ko ? 1.3 : 1), sp = o.speed || 1, dir = o.dir || 1;
  const rays = Array.from({ length: o.ko ? 16 : 9 }, (_, i) => ({ a: (o.ko ? i / 16 * 6.283 : (Math.random() - .5) * 1.6 + (dir > 0 ? 0 : Math.PI)) + (Math.random() - .5) * .2, L: .6 + Math.random() * .6, w: .6 + Math.random() * .7 }));
  const S = sparkSet(o.ko ? 40 : 18, o.ko ? 0 : dir, .8, 2.6, size), END = o.ko ? 900 : 520;
  return layer(host, sp, (ctx, T) => {
    const rk = easeOut(clamp01(T / 140)), rf = clamp01(1 - (T - 120) / (o.ko ? 500 : 260));
    for (const r of rays) { const L = size * .75 * r.L * rk, w = size * .028 * r.w * rf, c = Math.cos(r.a), s = Math.sin(r.a); if (rf <= 0) break;
      const g = ctx.createLinearGradient(o.x, o.y, o.x + c * L, o.y + s * L); g.addColorStop(0, rgba(pal.core, .8 * rf)); g.addColorStop(.35, rgba(pal.main, .45 * rf)); g.addColorStop(1, rgba(pal.glow, 0));
      ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(o.x - s * w, o.y + c * w); ctx.lineTo(o.x + c * L, o.y + s * L); ctx.lineTo(o.x + s * w, o.y - c * w); ctx.closePath(); ctx.fill(); }
    const k = easeOut(clamp01(T / (o.ko ? 520 : 320))); if (k < 1) { ring(ctx, o.x, o.y + size * .42, size * (.15 + .7 * k), size * .03 * (1 - k) + 1, pal.glow, .8 * (1 - k)); ring(ctx, o.x, o.y + size * .42, size * (.15 + .7 * k), 1.5, pal.core, .8 * (1 - k)); }
    if (T < 160) glow(ctx, o.x, o.y, size * (.35 + T / 600), pal, 1 - T / 160);
    const a = drawSparkSet(ctx, S, o.x, o.y, T, pal, size);
    return a || T < END;
  }, 8);
}
// 見切り（COUNTER）：刃と刃がぶつかる。青緑の十字の光＋2つの輪＋左右へ散る火花
export function clashFX(host, o) {
  const pal = PAL.teal, size = o.size, S = sparkSet(36, 0, 1, 3, size);
  return layer(host, o.speed || 1, (ctx, T) => {
    if (T < 220) { const k = 1 - T / 220, r = size * (.25 + .8 * easeOut(T / 220)); glow(ctx, o.x, o.y, r, pal, k); star4(ctx, o.x, o.y, size * .9 * (.4 + .6 * easeOut(T / 90)), .785, pal.main, .8 * k); star4(ctx, o.x, o.y, size * .55, 0, pal.core, k); }
    for (let j = 0; j < 2; j++) { const k = easeOut(clamp01((T - j * 70) / 380)); if (k > 0 && k < 1) { ring(ctx, o.x, o.y, size * (.1 + .65 * k), size * .025 * (1 - k) + 1, pal.glow, .9 * (1 - k), 1); ring(ctx, o.x, o.y, size * (.1 + .65 * k), 1.2, pal.core, .9 * (1 - k), 1); } }
    return drawSparkSet(ctx, S, o.x, o.y, T, pal, size) || T < 600;
  }, 8);
}
// 大技の構え：相手（el）の体から赤黒の炎の筋が昇り、足元の輪が脈打つ。stop() まで続く
export function chargeFX(host, el, o = {}) { let L;
  const pal = PAL[o.color || 'red'], N = 34, seeds = Array.from({ length: N }, (_, i) => ({ x: Math.random() * 2 - 1, p: Math.random(), v: .6 + Math.random() * .7, w: 2 + Math.random() * 2.2 }));
  el.classList.add('chg'); // 体の縁が赤く光る（CSS の drop-shadow、main.js）
  L = layer(host, o.speed || 1, (ctx, T) => {
    const hr = host.getBoundingClientRect(), r = el.getBoundingClientRect(); if (!r.width) return true;
    const cx = (r.left + r.right) / 2 - hr.left, by = r.bottom - hr.top - r.height * .04, w = r.width * .32, h = r.height, k = clamp01(T / 300);
    const pulse = .75 + .25 * Math.sin(T / 90);
    ctx.globalCompositeOperation = 'source-over'; // 暗い下地：足元の影と、体のまわりの赤黒いもや
    const g0 = ctx.createRadialGradient(cx, by - h * .4, 0, cx, by - h * .4, h * .55); g0.addColorStop(0, rgba(pal.dark, .0)); g0.addColorStop(.55, rgba(pal.dark, .22 * k)); g0.addColorStop(1, rgba(pal.dark, 0)); ctx.fillStyle = g0; ctx.fillRect(cx - h, by - h, h * 2, h * 1.1);
    ring(ctx, cx, by + 2, w * 1.25, 10 * k, pal.dark, .45 * k);
    ctx.globalCompositeOperation = 'lighter';
    ring(ctx, cx, by, w * 1.25 * (1 + .06 * Math.sin(T / 90)), 6 * k, pal.glow, .55 * k * pulse); ring(ctx, cx, by, w * 1.25 * (1 + .06 * Math.sin(T / 90)), 1.5, pal.core, .6 * k * pulse);
    const g = ctx.createRadialGradient(cx, by - h * .45, 0, cx, by - h * .45, h * .6); g.addColorStop(0, rgba(pal.glow, .18 * k * pulse)); g.addColorStop(1, rgba(pal.glow, 0)); ctx.fillStyle = g; ctx.fillRect(cx - h, by - h * 1.1, h * 2, h * 1.2);
    for (const s of seeds) { const ph = (T / 1000 * s.v + s.p) % 1, x = cx + s.x * w * 1.4 * (1 - ph * .3) + Math.sin(T / 120 + s.p * 9) * w * .06, y = by - ph * h * .95; const ea = Math.sin(ph * Math.PI) * k; glow(ctx, x, y, s.w * 4, pal, ea * .5); streak(ctx, x, y, Math.sin(T / 150 + s.p * 7) * .3, -1, h * .035, s.w * .8, ph < .5 ? pal.core : pal.spark, ea); } // 火の粉（小さな光と短い尾）
    return true;
  }, 3, 'normal');
  return { stop() { el.classList.remove('chg'); L.stop(); } };
}
// 鬨の声：味方（el）の足元から金の輪が2重に広がり、光の筋が昇る
export function rallyFX(host, el, o = {}) {
  const pal = PAL.gold, seeds = Array.from({ length: 32 }, () => ({ x: Math.random() * 2 - 1, d: Math.random() * 250, v: .8 + Math.random() * .8, w: 1.4 + Math.random() * 2.2 }));
  return layer(host, o.speed || 1, (ctx, T) => {
    const hr = host.getBoundingClientRect(), r = el.getBoundingClientRect(), cx = (r.left + r.right) / 2 - hr.left, by = r.bottom - hr.top - r.height * .04, w = r.width * .35, h = r.height;
    for (let j = 0; j < 2; j++) { const k = easeOut(clamp01((T - j * 150) / 600)); if (k > 0 && k < 1) { ctx.globalCompositeOperation = 'source-over'; ring(ctx, cx, by + 2, w * (.5 + 2.2 * k), 10 * (1 - k) + 2, pal.dark, .4 * (1 - k)); ctx.globalCompositeOperation = 'lighter'; ring(ctx, cx, by, w * (.5 + 2.2 * k), 14 * (1 - k) + 2, pal.glow, (1 - k)); ring(ctx, cx, by, w * (.5 + 2.2 * k), 2.5, pal.core, (1 - k)); } }
    if (T < 700) { const k = clamp01(T / 120) * clamp01(1 - (T - 300) / 400), g = ctx.createRadialGradient(cx, by - h * .45, 0, cx, by - h * .45, h * .6); g.addColorStop(0, rgba(pal.main, .35 * k)); g.addColorStop(1, rgba(pal.glow, 0)); ctx.fillStyle = g; ctx.fillRect(cx - h, by - h * 1.1, h * 2, h * 1.2); }
    let alive = T < 800;
    for (const s of seeds) { const t = T - s.d; if (t < 0 || t > 600) { if (t < 0) alive = true; continue; } alive = true; const ph = t / 600; ctx.globalCompositeOperation = 'source-over'; streak(ctx, cx + s.x * w * 1.6, by - ph * h * s.v + 2, 0, -1, h * .1, s.w * 2, pal.dark, Math.sin(ph * Math.PI) * .3); ctx.globalCompositeOperation = 'lighter'; streak(ctx, cx + s.x * w * 1.6, by - ph * h * s.v, 0, -1, h * .1, s.w, ph < .4 ? pal.core : pal.spark, Math.sin(ph * Math.PI)); }
    if (T < 200) glow(ctx, cx, by - h * .5, h * .5, pal, .6 * (1 - T / 200));
    return alive;
  }, 8, 'normal');
}

/* ===== 星震の止め（一騎打ちの将軍戦。2026-10-30）。アクション戦闘の vsstomp・starfall を DOM の舞台に移したもの =====
   starFX(host, at, df, { speed }) … at＝打つ仲間の要素、df＝敵将の要素。毎フレーム位置を測るので、カメラが引いても追う。
   流れ（ms）：0 踏み抜き（光の柱＋扇の流線、夜空へ暗転）→ 320〜1050 星の雨（敵将へ14個、舞台全体に飾り30個）→ 1150 大きな一撃（輪・閃光）→ 1700 明るく戻る */
const SKY = { glow: [90, 150, 255], main: [120, 185, 255], core: [235, 245, 255], spark: [190, 225, 255], gold: [255, 205, 110], dark: [4, 8, 30] };
export function starFX(host, at, df, o = {}) {
  const sp = o.speed || 1, R = (a, b) => a + Math.random() * (b - a), ease = t => 1 - Math.pow(1 - clamp01(t), 3);
  const QK = 1150, END = 1750, W0 = host.clientWidth;
  const box = el => { const hr = host.getBoundingClientRect(), r = el.getBoundingClientRect(); return { cx: (r.left + r.right) / 2 - hr.left, by: r.bottom - hr.top - r.height * .04, h: r.height * .8, w: r.width }; };
  const st = Array.from({ length: 34 }, () => { const q = Math.random() * 2 - 1, a = Math.abs(q); return { ox: q, d: a * 40 + R(0, 30), sp: 90 + a * 90 + R(0, 40), fo: R(280, 600), hk: R(.75, 1.05) - a * .2, w: (a < .25 ? 2 : 4) + R(0, a < .25 ? 3 : 9), al: a < .25 ? 1 : R(.55, .9), c: a < .2 ? 'core' : Math.random() < .3 ? 'gold' : 'main', sw: R(0, 4), ph: R(0, 6.28) }; });
  const ln = Array.from({ length: 22 }, (_, i) => { const s = i % 2 ? 1 : -1, ang = -Math.PI / 2 + s * R(.15, 1.45), L = R(W0 * .8, W0 * 1.4), b = R(.12, .35) * s; return { ex: Math.cos(ang) * L, ey: Math.sin(ang) * L * .85, bx: Math.cos(ang + b) * L * .5, by: Math.sin(ang + b) * L * .42, d: R(0, 120), w: R(6, 14), gold: i % 3 === 0 }; });
  const rain = Array.from({ length: 14 }, (_, i) => ({ at: 320 + i * 45 + R(0, 30), dur: R(150, 210), ox: R(-.35, .35), oy: R(-.55, .1), sx: R(60, 200), wk: R(.6, 1.4), gold: i % 4 === 0, S: sparkSet(8, 0, .6, 1.8, 120) }));
  const deco = Array.from({ length: 30 }, () => ({ at: R(260, 1100), dur: R(120, 200), gx: R(.03, .97), gy: R(-.06, .04), sx: R(60, 200), wk: R(.4, 1), gold: Math.random() < .3 }));
  const sky = Array.from({ length: 40 }, () => ({ x: Math.random(), y: Math.random() * .45, p: R(0, 6.28) }));
  const dimK = T => T < 300 ? .55 + .45 * T / 300 : T < QK ? 1 : Math.max(0, 1 - (T - QK) / (END - QK));
  const quake = { done: false };
  // 後ろ：夜空の暗転（人物の前、光の後ろ）
  const D = layer(host, sp, (ctx, T) => { const k = dimK(T); ctx.globalCompositeOperation = 'source-over'; const H = host.clientHeight, W = host.clientWidth;
    const g = ctx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, `rgba(4,8,30,${.78 * k})`); g.addColorStop(.6, `rgba(8,14,44,${.55 * k})`); g.addColorStop(1, `rgba(10,16,40,${.4 * k})`); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    ctx.globalCompositeOperation = 'lighter'; for (const s of sky) { ctx.fillStyle = `rgba(220,235,255,${.7 * k * (.5 + .5 * Math.sin(T / 200 + s.p))})`; ctx.fillRect(s.x * W, s.y * H, 2, 2); }
    return T < END; }, 6, 'normal');
  return layer(host, sp, (ctx, T) => {
    const a = box(at), f = box(df), H = host.clientHeight, x = a.cx, y = a.by, PH = y + 20;
    // ① 光の柱（細い筋の重ね）
    for (const q of st) { const b = T - q.d; if (b <= 0) continue; const hd = ease(b / q.sp), tl = ease((b - q.sp * .35) / (q.sp * 3.5)), fd = Math.max(0, 1 - Math.max(0, b - q.sp - 60) / q.fo); if (fd <= 0) continue;
      const sx = x + q.ox * a.h * .28 * (1 - .5 * hd) + Math.sin(T * .02 + q.ph) * q.sw, t2 = y - PH * q.hk * hd, b2 = y - PH * q.hk * Math.min(hd, tl) * .9, len = b2 - t2; if (len < 4) continue;
      const w2 = q.w * (.6 + .4 * fd), col = SKY[q.c], g = ctx.createLinearGradient(0, b2, 0, t2); g.addColorStop(0, rgba(col, 0)); g.addColorStop(.25, rgba(col, .55 * q.al * fd)); g.addColorStop(.85, rgba(col, q.al * fd)); g.addColorStop(1, rgba(col, 0));
      ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(sx, b2); ctx.quadraticCurveTo(sx - w2, b2 - len * .55, sx, t2); ctx.quadraticCurveTo(sx + w2, b2 - len * .55, sx, b2); ctx.fill(); }
    // ② 扇の流線（3層）
    for (const q of ln) { const b = T - q.d; if (b <= 0) continue; const fd = Math.max(0, 1 - Math.max(0, b - 260) / 380); if (fd <= 0) continue; const p0y = y - a.h * .1;
      [[q.gold ? SKY.gold : SKY.glow, 40, .6, 2.2, .5], [q.gold ? SKY.gold : SKY.main, 16, .45, 1, .95], [SKY.core, 0, .32, .35, 1]].forEach(([c, lag, tail, w, al]) => { const hd = ease((b - lag) / 200), tl = ease((b - lag - 200 * tail) / 300); if (hd <= 0) return;
        const pt = u => { const iu = 1 - u; return [iu * iu * x + 2 * iu * u * (x + q.bx) + u * u * (x + q.ex), iu * iu * p0y + 2 * iu * u * (p0y + q.by) + u * u * (p0y + q.ey)]; }, A = pt(Math.min(hd, tl)), B = pt(hd);
        streak(ctx, B[0], B[1], B[0] - A[0], B[1] - A[1], Math.hypot(B[0] - A[0], B[1] - A[1]), q.w * w * fd, c, al * fd); }); }
    if (T < 160) { glow(ctx, x, y - a.h * .2, a.h * (.8 + T / 120), { core: SKY.core, main: SKY.gold, glow: SKY.glow }, 1 - T / 160); star4(ctx, x, y - a.h * .15, a.h * .9 * (1 - T / 160), 0, SKY.core, .8 * (1 - T / 160)); }
    // ③ 星の雨：敵将へ
    for (const s of rain) { const u = (T - s.at) / s.dur, tx = f.cx + s.ox * f.w * .5, ty = f.by - f.h * (.55 - s.oy), sx0 = tx + s.sx, sy0 = -20;
      if (u > 0 && u < 1) { const e = u * u, px = sx0 + (tx - sx0) * e, py = sy0 + (ty - sy0) * e; streak(ctx, px, py, tx - sx0, ty - sy0, f.h * .55 * s.wk, 7 * s.wk, s.gold ? SKY.gold : SKY.glow, .7); streak(ctx, px, py, tx - sx0, ty - sy0, f.h * .35 * s.wk, 2.5 * s.wk, SKY.core, 1); star4(ctx, px, py, 14 * s.wk, T / 300, SKY.core, .9); }
      else if (u >= 1) { const b = T - s.at - s.dur; if (b < 260) { glow(ctx, tx, ty, f.h * .35, { core: SKY.core, main: SKY.main, glow: SKY.glow }, 1 - b / 260); star4(ctx, tx, ty, f.h * .3 * (1 - b / 260), .4, SKY.core, 1 - b / 260); } drawSparkSet(ctx, s.S, tx, ty, b, { core: SKY.core, spark: SKY.spark }, 120); } }
    // 飾りの星：舞台全体の地面へ
    for (const s of deco) { const u = (T - s.at) / s.dur, W = host.clientWidth, gx = s.gx * W, gy = f.by + s.gy * H, sx0 = gx + s.sx;
      if (u > 0 && u < 1) { const e = u * u, px = sx0 + (gx - sx0) * e, py = -20 + (gy + 20) * e; streak(ctx, px, py, gx - sx0, gy + 20, 70 * s.wk, 4 * s.wk, s.gold ? SKY.gold : SKY.glow, .6); streak(ctx, px, py, gx - sx0, gy + 20, 40 * s.wk, 1.5 * s.wk, SKY.core, .9); }
      else if (u >= 1 && T - s.at - s.dur < 220) { const k = 1 - (T - s.at - s.dur) / 220; ring(ctx, gx, gy, 30 * s.wk * (1.6 - k), 1.5, SKY.main, k); glow(ctx, gx, gy, 26 * s.wk, { core: SKY.core, main: SKY.main, glow: SKY.glow }, .6 * k); } }
    // ④ 大きな一撃
    if (T >= QK && !quake.done) { quake.done = true; host.classList.remove('kof'); void host.offsetWidth; host.classList.add('kof'); o.onQuake && o.onQuake(); }
    if (T >= QK) { const k = ease((T - QK) / 600); if (k < 1) for (const [rr, c] of [[1.4, SKY.glow], [.9, SKY.gold]]) { ring(ctx, f.cx, f.by, f.h * rr * (.2 + k), 10 * (1 - k) + 2, c, 1 - k); ring(ctx, f.cx, f.by, f.h * rr * (.2 + k), 2, SKY.core, 1 - k); } }
    return T < END;
  }, 8);
}

/* ===== 2026-10-31 技ごとの形（調査：「形で何の技か読める」Riot、「重さで止め・揺れ・光を変える」） =====
   色：味方は青系（ラナは赤黒・金、ミナは拘束の紫、セラは癒しの緑金、ランカ・リリィは青白・金）、敵は赤系（黒騎士・大公は赤紫の闇） */
export const FXPAL = {
  rana: { glow: [255, 90, 60], main: [200, 25, 35], core: [255, 238, 205], spark: [255, 205, 110], dark: [40, 0, 8] },
  azure: { glow: [90, 170, 255], main: [55, 125, 255], core: [255, 246, 222], spark: [255, 212, 130], dark: [0, 10, 40] },
  violet: { glow: [190, 120, 255], main: [140, 70, 255], core: [246, 236, 255], spark: [214, 184, 255], dark: [26, 6, 56] },
  jade: { glow: [140, 240, 160], main: [70, 205, 140], core: [252, 255, 230], spark: [240, 230, 140], dark: [0, 30, 16] },
  sky: { glow: [90, 150, 255], main: [120, 185, 255], core: [235, 245, 255], spark: [255, 214, 120], dark: [4, 8, 30] },
  silver: { glow: [150, 190, 255], main: [110, 150, 255], core: [252, 253, 255], spark: [220, 232, 255], dark: [6, 10, 30] },
  red: { glow: [255, 110, 70], main: [235, 50, 30], core: [255, 244, 225], spark: [255, 190, 120], dark: [40, 0, 0] },
  steel: { glow: [255, 140, 90], main: [215, 70, 40], core: [255, 248, 230], spark: [255, 214, 150], dark: [40, 8, 0] },
  abyss: { glow: [230, 60, 130], main: [140, 10, 80], core: [255, 215, 240], spark: [255, 120, 200], dark: [24, 0, 22] }
};

// 画面の揺れ（Eiserloh の trauma 方式）：当たりで trauma を足し、時間で減らす。揺れ＝trauma²×なめらかなノイズ。CSS の translate/rotate で（カメラの transform と重ならない）
export function shaker(el, maxPx = 14, maxDeg = 1.2) {
  let tr = 0, raf = 0, prev = 0, t = 0;
  const n = (x, a) => Math.sin(x * 1.7 + a) * .5 + Math.sin(x * 3.1 + a * 2.3) * .3 + Math.sin(x * 5.3 + a * 1.1) * .2; // なめらかな揺らぎ（乱数ではなく連続）
  const tick = now => { const dt = Math.min(.05, (now - (prev || now)) / 1000); prev = now; t += dt * 18; tr = Math.max(0, tr - dt * 1.6);
    const s = tr * tr; el.style.translate = s ? `${(maxPx * s * n(t, 0)).toFixed(2)}px ${(maxPx * s * n(t, 4)).toFixed(2)}px` : ''; el.style.rotate = s ? `${(maxDeg * s * n(t, 9)).toFixed(3)}deg` : '';
    raf = tr > 0 ? requestAnimationFrame(tick) : 0; if (!raf) prev = 0; };
  return { add(v) { tr = Math.min(1, tr + v); if (!raf) raf = requestAnimationFrame(tick); }, stop() { tr = 0; cancelAnimationFrame(raf); raf = 0; el.style.translate = el.style.rotate = ''; } };
}

// 集中線（漫画の効果線）：相手の周りから中心へ向かう細い楔。重い当たり・決着だけ
function speedLines(ctx, x, y, size, pal, k, seed) {
  for (let i = 0; i < seed.length; i++) { const q = seed[i], a = q.a, r0 = size * (.55 + q.r * .25), r1 = r0 + size * (.6 + q.l * .9), w = size * .012 * q.w;
    const c = Math.cos(a), s = Math.sin(a), g = ctx.createLinearGradient(x + c * r1, y + s * r1, x + c * r0, y + s * r0); g.addColorStop(0, rgba(pal.glow, 0)); g.addColorStop(1, rgba(q.g ? pal.spark : pal.core, .75 * k));
    ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(x + c * r1 - s * w, y + s * r1 + c * w); ctx.lineTo(x + c * r0, y + s * r0); ctx.lineTo(x + c * r1 + s * w, y + s * r1 - c * w); ctx.closePath(); ctx.fill(); }
}
const lineSeed = n => Array.from({ length: n }, () => ({ a: Math.random() * 6.283, r: Math.random(), l: Math.random(), w: .6 + Math.random() * 1.4, g: Math.random() < .3 }));

// 打撃（掌打・蹴り）：①芯の光 ②体の高さの衝撃の輪（縦に潰さない円）×2 ③床の輪 ④打った向きの楔 ⑤火花 ⑥（重いとき）集中線
export function burstFX(host, o) {
  const pal = o.pal || FXPAL.sky, size = o.size, dir = o.dir || 1, heavy = !!o.heavy, sp = o.speed || 1;
  const rays = Array.from({ length: heavy ? 12 : 7 }, () => ({ a: (Math.random() - .5) * 1.3 + (dir > 0 ? 0 : Math.PI), L: .5 + Math.random() * .7, w: .6 + Math.random() * .8 }));
  const S = sparkSet(heavy ? 34 : 18, dir, .9, 2.8, size), SL = heavy ? lineSeed(30) : null, END = heavy ? 640 : 460;
  return layer(host, sp, (ctx, T) => {
    if (T < 90) { glow(ctx, o.x, o.y, size * (.3 + T / 300), pal, 1 - T / 90); star4(ctx, o.x, o.y, size * (.7 - T / 300), dir > 0 ? .2 : -.2, pal.core, .9 * (1 - T / 90)); }
    for (let j = 0; j < 2; j++) { const k = easeOut(clamp01((T - j * 60) / 300)); if (k > 0 && k < 1) { ring(ctx, o.x, o.y, size * (.12 + .55 * k), size * .05 * (1 - k) + 1, pal.glow, .9 * (1 - k), 1); ring(ctx, o.x, o.y, size * (.12 + .55 * k), 1.6, pal.core, (1 - k), 1); } }
    const kf = easeOut(clamp01(T / 380)); if (kf < 1) { ring(ctx, o.x, o.y + size * .45, size * (.2 + .8 * kf), size * .03 * (1 - kf) + 1, pal.glow, .7 * (1 - kf)); }
    const rf = clamp01(1 - (T - 60) / 220), rk = easeOut(clamp01(T / 110));
    if (rf > 0) for (const r of rays) { const L = size * .8 * r.L * rk, w = size * .03 * r.w * rf, c = Math.cos(r.a), s = Math.sin(r.a), g = ctx.createLinearGradient(o.x, o.y, o.x + c * L, o.y + s * L);
      g.addColorStop(0, rgba(pal.core, .8 * rf)); g.addColorStop(.4, rgba(pal.main, .45 * rf)); g.addColorStop(1, rgba(pal.glow, 0)); ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(o.x - s * w, o.y + c * w); ctx.lineTo(o.x + c * L, o.y + s * L); ctx.lineTo(o.x + s * w, o.y - c * w); ctx.closePath(); ctx.fill(); }
    if (SL && T < 260) speedLines(ctx, o.x, o.y, size, pal, 1 - T / 260, SL);
    return drawSparkSet(ctx, S, o.x, o.y, T, pal, size) || T < END;
  }, 8, 'screen', true);
}

// 地割れ（斧の叩き割り）：着地点から床に沿って走るギザギザの裂け目（暗い下地→光る芯）＋土ぼこり（通常の合成・茶）
export function crackFX(host, o) { // 2026-10-31 作り直し：光る線（電気に見えた）→ 土の色の暗い溝。光るのは割れた瞬間の短い間だけ。石のかけらと土ぼこり
  const pal = o.pal || FXPAL.azure, size = o.size, sp = o.speed || 1, gy = o.y;
  const cracks = Array.from({ length: 6 }, (_, i) => { let th = i / 6 * 6.283 + (Math.random() - .5) * .6, x = 0, y = 0; const n = 4 + Math.floor(Math.random() * 3), L = size * (.08 + Math.random() * .05), pts = [[0, 0]];
    for (let j = 1; j <= n; j++) { th += (Math.random() - .5) * .8; x += Math.cos(th) * L; y += Math.sin(th) * L; pts.push([x, y]); } return { pts, d: Math.random() * 30 }; });
  const rocks = Array.from({ length: 12 }, () => ({ vx: (Math.random() - .5) * size * 1.6, vy: -size * (.6 + Math.random() * .9), s: size * (.016 + Math.random() * .024), r: Math.random() * 6, vr: (Math.random() - .5) * 14, c: 50 + Math.random() * 40 }));
  const dust = Array.from({ length: 12 }, () => ({ x: (Math.random() - .5) * size * .9, vx: (Math.random() - .5) * size * .7, vy: -size * (.15 + Math.random() * .3), r: size * (.07 + Math.random() * .08), d: Math.random() * 60 }));
  return layer(host, sp, (ctx, T) => { const t = T / 1000; ctx.globalCompositeOperation = 'source-over';
    // 溝：根本が太く先が細い、暗い土の色。少しずつ薄れる
    const fd = clamp01(1 - (T - 350) / 450);
    for (const c of cracks) { const k = easeOut(clamp01((T - c.d) / 110)); if (k <= 0 || fd <= 0) continue; const m = Math.max(1, Math.ceil(k * (c.pts.length - 1)));
      for (let j = 1; j <= m; j++) { const [x0, y0] = c.pts[j - 1], [x1, y1] = c.pts[j], w = 6.5 * (1 - (j - 1) / c.pts.length) + 1;
        ctx.strokeStyle = `rgba(30,18,10,${.85 * fd})`; ctx.lineWidth = w; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(o.x + x0, gy + y0 * .32); ctx.lineTo(o.x + x1, gy + y1 * .32); ctx.stroke();
        ctx.strokeStyle = `rgba(150,120,85,${.35 * fd})`; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(o.x + x0, gy + y0 * .32 - w * .5); ctx.lineTo(o.x + x1, gy + y1 * .32 - w * .5); ctx.stroke(); } } // 溝の縁の明るい土
    // 土ぼこり（後ろで膨らむ）
    for (const q of dust) { const tt = (T - q.d) / 1000; if (tt < 0 || tt > .9) continue; const k = 1 - tt / .9, x = o.x + q.x + q.vx * tt, y = gy + q.vy * tt + size * .35 * tt * tt, r = q.r * (1 + tt * 2.2), g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, `rgba(122,98,70,${.5 * k})`); g.addColorStop(1, 'rgba(122,98,70,0)'); ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2); }
    // 石のかけら（重力・回転、地面で消える）
    for (const q of rocks) { const x = o.x + q.vx * t, y = gy + q.vy * t + size * 2.6 * t * t; if (t > .05 && y > gy + 4) continue; ctx.save(); ctx.translate(x, y); ctx.rotate(q.r + q.vr * t); ctx.fillStyle = `rgb(${q.c},${q.c * .8 | 0},${q.c * .6 | 0})`; ctx.fillRect(-q.s, -q.s * .7, q.s * 2, q.s * 1.4); ctx.restore(); }
    // 割れた瞬間だけ、溝の奥が光る
    ctx.globalCompositeOperation = 'lighter'; if (T < 160) { const k = 1 - T / 160; glow(ctx, o.x, gy, size * .45, pal, .8 * k); for (const c of cracks) { ctx.strokeStyle = rgba(pal.spark, .7 * k); ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(o.x, gy); for (const [x, y] of c.pts.slice(1, 3)) ctx.lineTo(o.x + x, gy + y * .32); ctx.stroke(); } }
    return T < 950;
  }, 6, 'normal');
}

// 鎖（ミナ）：打つ側から相手へ、たるんだ線が一気に伸びて張り、点線が流れる → 相手に拘束の輪（紫）
export function chainFX(host, o) {
  const pal = o.pal || FXPAL.violet, sp = o.speed || 1, END = 620;
  return layer(host, sp, (ctx, T) => {
    const k = easeOut(clamp01(T / 120)), fd = clamp01(1 - (T - 260) / 340); if (fd <= 0) return T < END;
    const ex = o.x0 + (o.x1 - o.x0) * k, ey = o.y0 + (o.y1 - o.y0) * k, sag = (1 - clamp01((T - 120) / 80)) * 40 + 6, mx = (o.x0 + ex) / 2, my = (o.y0 + ey) / 2 + sag;
    for (const [col, w, a, dash] of [[pal.glow, 7, .5, null], [pal.main, 3, .9, [10, 7]], [pal.core, 1.2, 1, [10, 7]]]) { ctx.strokeStyle = rgba(col, a * fd); ctx.lineWidth = w; ctx.setLineDash(dash || []); ctx.lineDashOffset = -T * .25; ctx.beginPath(); ctx.moveTo(o.x0, o.y0); ctx.quadraticCurveTo(mx, my, ex, ey); ctx.stroke(); }
    ctx.setLineDash([]);
    if (T > 100) { const b = clamp01((T - 100) / 200); for (let j = 0; j < 2; j++) ring(ctx, o.x1, o.y1 + o.r * .1 * j, o.r * (1.1 - .35 * b) * (1 - j * .2), 3 - j, j ? pal.core : pal.glow, fd, .35); glow(ctx, o.x1, o.y1, o.r * .9, pal, .6 * fd * (1 - b * .5)); }
    return T < END;
  }, 8, 'screen', true);
}

// 紋様（セラの本の術）：相手の前に、回りながら縮む2重の円と刻み・6つの小さな印 → 閉じた瞬間に光がはじける
export function glyphFX(host, o) {
  const pal = o.pal || FXPAL.jade, size = o.size, sp = o.speed || 1, S = sparkSet(22, 0, .6, 2, size), CL = 260;
  return layer(host, sp, (ctx, T) => {
    if (T < CL) { const k = easeOut(T / CL), r = size * (.6 - .3 * k), rot = T / 180, a = Math.min(1, T / 80);
      ctx.globalCompositeOperation = 'source-over'; for (const rr of [1, .78]) { ctx.strokeStyle = rgba(pal.dark, .45 * a); ctx.lineWidth = 7; ctx.beginPath(); ctx.ellipse(o.x, o.y, r * rr, r * rr * .92, 0, 0, 7); ctx.stroke(); } ctx.globalCompositeOperation = 'lighter'; // 明るい背景でも線が残るよう、暗い下地
      for (const [rr, w, c] of [[1, 3, pal.glow], [1, 1.4, pal.core], [.78, 2, pal.main]]) { ctx.strokeStyle = rgba(c, a); ctx.lineWidth = w; ctx.beginPath(); ctx.ellipse(o.x, o.y, r * rr, r * rr * .92, 0, 0, 7); ctx.stroke(); }
      for (let i = 0; i < 24; i++) { const th = rot + i / 24 * 6.283, c = Math.cos(th), s = Math.sin(th); ctx.strokeStyle = rgba(pal.main, .8 * a); ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(o.x + c * r * .82, o.y + s * r * .76); ctx.lineTo(o.x + c * r * .92, o.y + s * r * .85); ctx.stroke(); }
      for (let i = 0; i < 6; i++) { const th = -rot * 1.4 + i / 6 * 6.283; star4(ctx, o.x + Math.cos(th) * r * .62, o.y + Math.sin(th) * r * .57, size * .07, th, pal.spark, a); } return true; }
    const t = T - CL; if (t < 200) { glow(ctx, o.x, o.y, size * (.4 + t / 400), pal, 1 - t / 200); ring(ctx, o.x, o.y, size * (.45 + t / 300), 2, pal.core, 1 - t / 200, .92); }
    return drawSparkSet(ctx, S, o.x, o.y, t, pal, size) || t < 420;
  }, 8, 'normal');
}

// 闇の煙（黒騎士・大公）：当たりの周りに、縁の柔らかい暗い煙（通常の合成）と赤紫の光の粒
export function smokeFX(host, o) {
  const size = o.size, sp = o.speed || 1, P = Array.from({ length: 16 }, () => ({ a: Math.random() * 6.283, v: size * (.35 + Math.random() * .6), r: size * (.06 + Math.random() * .08), d: Math.random() * 90 }));
  return layer(host, sp, (ctx, T) => { const t = T / 1000; if (t > .8) return false; const k = 1 - t / .8; ctx.globalCompositeOperation = 'source-over';
    for (const q of P) { const tt = Math.max(0, t - q.d / 1000), x = o.x + Math.cos(q.a) * q.v * tt, y = o.y + Math.sin(q.a) * q.v * tt * .6 - size * .25 * tt, r = q.r * (1 + tt * 3), g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, `rgba(30,4,26,${.22 * k * Math.min(1, tt * 12)})`); g.addColorStop(.5, `rgba(30,4,26,${.1 * k})`); g.addColorStop(1, 'rgba(30,4,26,0)'); ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2); }
    return true; }, 6, 'normal');
}

// 空間の歪み（決着の一撃だけ）：SVG の乱流で舞台を一瞬ゆがめる（PixiJS の ShockwaveFilter の代わり。重いので短く）
let WARP = null;
export function warpFX(el, ms = 360, amp = 26) {
  if (!WARP) { const ns = 'http://www.w3.org/2000/svg', sv = document.createElementNS(ns, 'svg'); sv.setAttribute('width', 0); sv.setAttribute('height', 0); sv.style.position = 'absolute';
    sv.innerHTML = '<filter id="fxwarp" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency="0.012 0.03" numOctaves="2" seed="3" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="0" xChannelSelector="R" yChannelSelector="G"/></filter>';
    document.body.appendChild(sv); WARP = sv.querySelector('feDisplacementMap'); }
  const t0 = performance.now(); el.style.filter = 'url(#fxwarp)';
  const tick = now => { const u = (now - t0) / ms; if (u >= 1) { el.style.filter = ''; WARP.setAttribute('scale', 0); return; } WARP.setAttribute('scale', (amp * Math.sin(Math.PI * u) * (1 - u * .5)).toFixed(1)); requestAnimationFrame(tick); };
  requestAnimationFrame(tick);
}
