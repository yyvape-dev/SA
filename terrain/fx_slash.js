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
  const pal = PAL[o.color] || PAL.blue, dir = o.dir || 1, sp = o.speed || 1, size = o.size;
  // 斬撃の本数：通常は1本（右上→左下へ振り下ろす）、大技は時間差で2本目が交差する
  const cuts = [{ arc: makeArc(o.x, o.y, size * 1.35, dir, .62, size * .3), t0: 0, w: size * .11 }];
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
  let start = 0, prev = 0;
  const frame = now => {
    if (!start) { start = prev = now; }
    const T = (now - start) * sp, dt = Math.min(50, now - prev) * sp / 1000; prev = now;
    ctx.clearRect(0, 0, W, H); ctx.globalCompositeOperation = 'lighter';
    let alive = false;
    cuts.forEach((c, ci) => {
      const t = T - c.t0; if (t < 0) { alive = true; return; }
      const fade = t > SWING ? clamp01(1 - (t - SWING) / FADE) : 1; if (fade > 0) alive = true;
      for (const Ly of LAYERS) {
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
    if (alive) requestAnimationFrame(frame); else cv.remove();
  };
  requestAnimationFrame(frame);
  return cv;
}
