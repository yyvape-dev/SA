// 敵将の大技の確認（ヘッドレス）：大振り・三連撃・突進を手で時間を進めて、当たる／ジャストガード／回避で抜ける、を数え、撮る（/tmp/bst/*.png）。
// 使い方: node battle/tools/boss_test.js
const { chromium } = require('playwright'), http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..'), T = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.webp': 'image/webp', '.json': 'application/json', '.jpg': 'image/jpeg' };
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': T[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r); });
fs.mkdirSync('/tmp/bst', { recursive: true });
(async () => {
  await new Promise(r => srv.listen(0, r));
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 430, height: 900 } }); const errs = [];
  p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (/setupBoss/.test(m.text())) console.log(m.text()); });
  await p.goto(`http://localhost:${srv.address().port}/index.html?battle=1&waves=3&boss=1&al=mina&` + (process.argv[2] || ''));
  await p.waitForTimeout(4000); await p.evaluate(() => startRun()); await p.waitForTimeout(2500);
  await p.evaluate(() => {
    window.__u = update; update = function () {};
    window.setupBoss = function (mv, dist) {
      G.enemies = []; G.fx = []; G.ally = null; spawn({ boss: true }); const e = G.boss, h = G.hero; h.x = camX + W * 0.5; h.kb = 0; G.freeze = 0; G.jg = null; h.state = 'idle'; h.inv = 0; h.hp = h.max = 9999; G.dodgeCD = 0; G.ultCD = 10;
      e.x = h.x + dist; e.y = h.y; e.bmCD = 0; e.atkCD = 99; const o = Math.random; Math.random = () => mv === 'combo' ? 0.9 : 0.1;
      __u(1 / 60); Math.random = o; if (!e.atk) console.log('setupBoss failed', mv, G.state, e.x - camX, e.stun, e.bind, G.phase); return e.atk ? e.atk.mv : null;
    };
    window.step = function (sec, fn) { const n = Math.round(sec * 60); for (let i = 0; i < n; i++) { if (fn && fn()) return true; G.hero.state === 'idle' && (G.hero.x = G.hero.x); __u(1 / 60); } return false; };
  });
  const out = {};
  // 1. 当たる（立ったまま）
  for (const [mv, d] of [['heavy', 150], ['combo', 150], ['charge', 300]]) {
    out[mv + '_stand'] = await p.evaluate(([mv, d]) => { const got = setupBoss(mv, d), h = G.hero, hp0 = h.hp; step(3, () => !G.boss.atk); return { got, lost: hp0 - h.hp }; }, [mv, d]);
  }
  // 2. ジャストガード（大振り・三連撃の3発目）
  out.heavy_jg = await p.evaluate(() => { setupBoss('heavy', 150); const h = G.hero, hp0 = h.hp, n0 = G.jgN || 0; step(2, () => jgTargets().length > 0); const left = G.boss.atk.hitT - G.boss.atk.t; tryAttack('dodge'); step(0.5); return { left: +left.toFixed(3), jg: (G.jgN || 0) - n0, lost: hp0 - h.hp, stun: +G.boss.stun.toFixed(2), atk: !!G.boss.atk }; });
  out.combo3_jg = await p.evaluate(() => { setupBoss('combo', 150); const h = G.hero, hp0 = h.hp, n0 = G.jgN || 0; step(3, () => G.boss.atk && G.boss.atk.si === G.boss.atk.segs.length - 1 && jgTargets().length > 0); h.inv = 0; tryAttack('dodge'); step(0.3); return { jg: (G.jgN || 0) - n0, lost: hp0 - h.hp, stun: +G.boss.stun.toFixed(2) }; });
  // 3. 突進：ジャストガードは出ない、回避で抜ける
  out.charge_jg = await p.evaluate(() => { setupBoss('charge', 300); const n0 = G.jgN || 0; step(0.7); return { targets: jgTargets().length, jgN: (G.jgN || 0) - n0 }; });
  out.charge_dodge = await p.evaluate(() => { setupBoss('charge', 300); const h = G.hero, hp0 = h.hp, s = G.boss.atk.segs[0]; step(s.tele - 0.05); tryAttack('dodge'); step(1.5, () => !G.boss.atk); return { lost: hp0 - h.hp, hstate: h.state }; });
  // 3b. 突進を回避で抜けられる押す時刻の幅（構えの終わりを0として、前後0.02秒刻み。向き：敵へ・敵から離れる・奥へ）
  out.charge_window = await p.evaluate(() => { const r = {}; for (const dir of ['to', 'away', 'up']) { const ok = []; for (let d = -0.4; d <= 0.25; d += 0.02) { setupBoss('charge', 300); const h = G.hero, hp0 = h.hp, s = G.boss.atk.segs[0]; h.face = 1; step(Math.max(0, s.tele + d)); const o = keys.ArrowLeft, u = keys.ArrowUp; if (dir === 'away') keys.ArrowLeft = true; if (dir === 'up') keys.ArrowUp = true; tryAttack('dodge'); keys.ArrowLeft = o; keys.ArrowUp = u; step(1.5, () => !G.boss.atk); if (hp0 === h.hp) ok.push(+d.toFixed(2)); } r[dir] = ok.length ? [ok[0], ok[ok.length - 1], ok.length] : 0; } return r; });
  // 4. 大技の最中はひるまない
  out.armor = await p.evaluate(() => { setupBoss('heavy', 150); step(0.3); hurt(G.boss, 10, 1, true); return { atk: !!G.boss.atk, stun: G.boss.stun }; });
  console.log(JSON.stringify(out, null, 0));
  // 撮影
  const shots = [['heavy', 150, [0.4, 0.9, 1.0, 1.3]], ['charge', 300, [0.4, 0.8, 0.95, 1.2]], ['combo', 150, [0.25, 0.6, 1.1, 1.5]]];
  for (const [mv, d, ts] of shots) {
    await p.evaluate(([mv, d]) => { setupBoss(mv, d); G.hero.inv = 99; window.__tt = 0; }, [mv, d]);
    for (let k = 0; k < ts.length; k++) {
      await p.evaluate(t => { step(t - __tt); __tt = t; G.flash = 0; G.shake = 0; draw(); }, ts[k]); await p.waitForTimeout(120); await p.evaluate(() => draw());
      await p.screenshot({ path: `/tmp/bst/${mv}_${k}.png`, clip: { x: 0, y: 230, width: 430, height: 360 } });
    }
  }
  console.log(errs.join('\n') || 'no errors'); await b.close(); srv.close();
})();
