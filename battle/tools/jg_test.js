// ジャストガードの確認（ヘッドレス）：成功・早すぎ・遅すぎの判定、スローの倍率、効果の撮影（/tmp/jgt/jg_*.png）、実際に押す。使い方: node battle/tools/jg_test.js
const { chromium } = require('playwright'), http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..'), T = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.webp': 'image/webp', '.json': 'application/json', '.jpg': 'image/jpeg' };
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': T[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r); });
fs.mkdirSync('/tmp/jgt', { recursive: true });
(async () => {
  await new Promise(r => srv.listen(0, r));
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 430, height: 900 } }); const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto(`http://localhost:${srv.address().port}/index.html?battle=1&waves=3&boss=1&al=mina`);
  await p.waitForTimeout(4000); await p.evaluate(() => startRun()); await p.waitForTimeout(2500);
  // 時間を止めて手で進める
  const r = await p.evaluate(() => {
    window.__u = update; update = function () {};
    const h = G.hero, out = {};
    function setup(left) { const e = G.enemies[0]; e.state = 'walk'; e.stun = 0; e.bind = 0; e.x = h.x + 80; e.y = h.y; e.face = -1; e.hp = e.max; startFoeAtk(e); e.atk.t = e.atk.hitT - left; G.dodgeCD = 0; h.state = 'idle'; h.inv = 0; return e; }
    let e = setup(0.1); const hp0 = h.hp, cd0 = G.ultCD = 10;
    tryAttack('dodge'); out.ok = { jgN: G.jgN || 0, done: !e.atk || e.atk.done, stun: e.stun, eHpLost: e.max - e.hp, ultCD: G.ultCD, dodgeCD: G.dodgeCD, hstate: h.state, slow: !!G.jg };
    // 早すぎ：0.4秒前 → 普通の回避
    G.jg = null; h.state = 'idle'; e = setup(0.4); tryAttack('dodge'); out.early = { jgN: G.jgN || 0, hstate: h.state };
    // 遅すぎ（当たりの後）
    h.state = 'idle'; e = setup(-0.02); e.atk.done = true; G.dodgeCD = 0; tryAttack('dodge'); out.late = { jgN: G.jgN || 0, hstate: h.state };
    return out;
  });
  console.log(JSON.stringify(r));
  // 実時間：jgTick で update が遅くなるか
  const s = await p.evaluate(() => { const v = []; G.jg = { t: 0 }; for (let i = 0; i < 12; i++) v.push(+jgTick(0.04).toFixed(2)); return v; });
  console.log('slow', JSON.stringify(s));
  // 見た目
  await p.evaluate(() => { const h = G.hero, e = G.enemies[0]; G.fx = []; e.state = 'walk'; e.stun = 0; e.bind = 0; e.x = h.x + 90; e.y = h.y; e.face = -1; e.hp = e.max; e.elite = true; startFoeAtk(e); e.atk.t = e.atk.hitT - 0.08; G.dodgeCD = 0; h.state = 'idle'; tryJustGuard(); G.fx.forEach(f => f.t0 = f.t); });
  for (const [k, t] of [[0, 0.02], [1, 0.07], [2, 0.15], [3, 0.3]].entries ? [[0, 0.02], [1, 0.07], [2, 0.15], [3, 0.3]] : []) {
    await p.evaluate(t => { G.fx.forEach(f => f.t = f.t0 + t); G.t += 0.0001; G.flash = 0; G.shake = 0; draw(); }, t); await p.waitForTimeout(150); await p.evaluate(() => draw());
    await p.screenshot({ path: `/tmp/jgt/jg_${k}.png`, clip: { x: 0, y: 250, width: 430, height: 330 } });
  }
  // 実際に遊ぶ：update を戻して、敵の当たりの直前に回避を押し続ける
  const play = await p.evaluate(async () => {
    update = window.__u; G.hero.hp = G.hero.max = 1e6; let n0 = G.jgN || 0, tries = 0;
    for (let i = 0; i < 200; i++) { await new Promise(r => setTimeout(r, 50)); if (jgTargets().length && G.dodgeCD <= 0) { tries++; __game.press('KeyO'); } }
    return { tries, jg: (G.jgN || 0) - n0 };
  });
  console.log('play', JSON.stringify(play));
  console.log(errs.join('\n') || 'no errors'); await b.close(); srv.close();
})();
