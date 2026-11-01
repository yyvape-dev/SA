// 章の将軍をアクション戦闘の敵将にした見た目（大きさ・歩き・攻撃）を撮る。使い方: node battle/tools/gen_shot.js [g1,g2,…]  → /tmp/gen/<g>.png
const { chromium } = require('playwright'), http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..'), T = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.webp': 'image/webp', '.json': 'application/json', '.jpg': 'image/jpeg' };
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': T[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r); });
fs.mkdirSync('/tmp/gen', { recursive: true });
(async () => {
  await new Promise(r => srv.listen(0, r));
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] }); const errs = [];
  for (const g of (process.argv[2] || 'g1,g2,g3,g4,g5,g6').split(',')) {
    const p = await b.newPage({ viewport: { width: 430, height: 900 } }); p.on('pageerror', e => errs.push(g + ' ' + e.message));
    await p.goto(`http://localhost:${srv.address().port}/index.html?battle=1&waves=3&boss=1&al=mina&gen=${g}`);
    await p.waitForTimeout(4000); await p.evaluate(() => startRun()); await p.waitForTimeout(2000);
    const info = await p.evaluate(() => { update = function () {}; G.enemies = []; G.fx = []; spawn({ boss: true }); G.fx = []; G.flash = 0; G.cine = null; G.cutin = null; const e = G.boss, h = G.hero; h.x = camX + W * 0.3; e.x = h.x + 200; e.y = h.y; e.face = -1; return { kind: e.kind, H: Math.round(eh(e)), clips: (FOE_CLIP[e.kind] || []).length, name: BOSS_GEN[e.gen] && BOSS_GEN[e.gen].n }; });
    const cl = { x: 0, y: 200, width: 430, height: 420 };
    await p.evaluate(() => draw()); await p.waitForTimeout(200); await p.evaluate(() => draw()); await p.screenshot({ path: `/tmp/gen/${g}_walk.png`, clip: cl });
    for (const ci of [0, 1]) {
      await p.evaluate(ci => { const e = G.boss, o = Math.random; let c = 0; Math.random = () => c++ ? o() : (ci + 0.5) / 2; startFoeAtk(e); Math.random = o; G.fx.forEach(f => f.t0 = f.t); e.atk.t = e.atk.hitT + 0.06; G.fx.forEach(f => f.t = f.t0 + e.atk.hitT + 0.06); draw(); }, ci);
      await p.waitForTimeout(200); await p.evaluate(() => draw()); await p.screenshot({ path: `/tmp/gen/${g}_a${ci}.png`, clip: cl }); await p.evaluate(() => { G.boss.atk = null; G.fx = []; });
    }
    console.log(g, JSON.stringify(info)); await p.close();
  }
  console.log(errs.join('\n') || 'no errors'); await b.close(); srv.close();
})();
