// アクション戦闘のエフェクトを、同じ時刻で止めて撮る（ヘッドレス）。Skill sa-battle-fx-check。
// 使い方（リポジトリ直下で）: node battle/tools/fx_shot.js <出力の頭> [URL に足す引数] [場面,場面]
//   例: node battle/tools/fx_shot.js /tmp/fx/gl            … PixiJS 版
//       node battle/tools/fx_shot.js /tmp/fx/cv px=0       … 従来の Canvas 2D 版
//       node battle/tools/fx_shot.js /tmp/fx/gl "" arc,hit … 場面をしぼる
//   出力: <頭>_<場面>_<0〜3>.png。標準出力に頂点の数（PX.vstats）と、ページのエラー。
//   play を付けると（FX_PLAY=1）、最後に70回ボタンを押して遊び、エラーと頂点の最大を出す。
const { chromium } = require('playwright'), http = require('http'), fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '../..'), TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.json': 'application/json', '.woff2': 'font/woff2', '.otf': 'font/otf', '.ttf': 'font/ttf' };
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); } r.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r); });
const SCENES = {
  arc: ['G.fx=[]; fxArc(G.hero, G.hero.face, 300, 0.36, false, false); fxArc(G.hero, G.hero.face, 300, 0.36, true, true, VFX_RANA);', [0.06, 0.12, 0.22, 0.32]],
  ult: ['G.fx=[]; fxArc(G.hero, 1, 300, 0.6, true, false, VFX_RANA, { rx: 720, ry: 280, a0: 1.25, a1: -1.55, w: 120, ox: 40, oy: -130, sw: 150 });', [0.08, 0.16, 0.3, 0.5]],
  lance: ['G.fx=[]; fxLance(G.hero, 420);', [0.05, 0.1, 0.2, 0.32]],
  hit: ['G.fx=[]; G.enemies.slice(0,3).forEach(e=>{fxHit(e,1,true);fxKill(e,1);}); fxRing(G.hero.x,G.hero.y,400,0.55); fxPull(G.hero.x+200,G.hero.y,300,G.enemies.slice(0,3));', [0.04, 0.1, 0.2, 0.35]],
  boss: ['G.fx=[]; var e=G.enemies[0]; fxBossDown(e); fxHeal(G.hero); fxStar(G.enemies[1]||e,0); fxDash(G.hero.x-200,G.hero.x+250,G.hero.y,1); G.fx.push({type:"vshock",x:G.hero.x,y:G.hero.y,dir:1,t:0,life:0.6}); G.fx.push({type:"vsuck",x:G.hero.x,y:G.hero.y,t:0,life:0.6});', [0.05, 0.15, 0.3, 0.5]],
  under: ['G.fx=[]; G.enemies.forEach((e,i)=>{ e.state="walk"; if(i<3){e.bind=2;e.bindMax=3;} }); G.enemies[3]&&(G.enemies[3].elite=true); if (G.ally) fxStarCharge(G.ally); fxPull(G.hero.x+200,G.hero.y,300,G.enemies.slice(0,3));', [0.1, 0.3, 0.5, 0.8]],
  slam: ['G.fx=[]; fxGroundSlam(G.hero.x+120, G.hero.y, W*0.85, VFX_SKY, false);', [0.05, 0.15, 0.35, 0.8]],
  wake: ['G.fx=[]; fxDash(G.hero.x-150, G.hero.x+230, G.hero.y, 1);', [0.05, 0.12, 0.3, 0.6]],
  swirl: ['G.fx=[]; if (!G.ally && typeof allyJoin === "function") { G.allyJoined = false; allyJoin(); } var a = G.ally || null; if (a) { a.state = "idle"; a.x = G.hero.x + 120; a.y = G.hero.y; a.atk = { t: 0 }; fxStarCharge(a); }', [0.3, 0.6, 1.0, 1.5]],
  foe1: ['G.fx=[]; function fa(e,k,ci,el,bs){e.kind=k;e.elite=el;e.boss=bs;e.size=bs?1.38:el?1.12:1;e.face=-1;e.state="walk";e.stun=0;e.bind=0;e.pull=null;var o=Math.random,c=0;Math.random=function(){return c++?o():(ci+0.5)/FOE_CLIP[k].length;};startFoeAtk(e);Math.random=o;} var E=G.enemies,hx=G.hero.x;E.forEach(function(e,i){e.x=hx+150+(i%2)*190;e.y=i<2?LANE_Y0+40:LANE_Y1-30;});window.__align=1; fa(E[0],1,0); fa(E[1],2,1,true); E[2]&&fa(E[2],3,1); E[3]&&fa(E[3],4,0); fxHurt(G.hero,E[0]);', [-0.15, 0.03, 0.1, 0.22]],
  foe2: ['G.fx=[]; function fa(e,k,ci,el,bs){e.kind=k;e.elite=el;e.boss=bs;e.size=bs?1.38:el?1.12:1;e.face=-1;e.state="walk";e.stun=0;e.bind=0;e.pull=null;var o=Math.random,c=0;Math.random=function(){return c++?o():(ci+0.5)/FOE_CLIP[k].length;};startFoeAtk(e);Math.random=o;} var E=G.enemies,hx=G.hero.x;E.forEach(function(e,i){e.x=hx+150+(i%2)*190;e.y=i<2?LANE_Y0+40:LANE_Y1-30;});window.__align=1; fa(E[0],1,1); fa(E[1],2,0,false,true); E[2]&&fa(E[2],3,0); E[3]&&fa(E[3],4,1,true);', [-0.15, 0.03, 0.1, 0.22]],
  star: ['G.fx=[]; G.enemies.forEach(e=>{e.bind=0;e.state="walk";}); startStarfall(G.ally||G.hero); G.starfall.t=0;', [0.5, 0.8, 1.0, 1.3]],
};
(async () => {
  const out = process.argv[2], q = process.argv[3] || '', only = (process.argv[4] || '').split(',').filter(Boolean);
  if (!out) { console.log('使い方: node battle/tools/fx_shot.js <出力の頭> [引数] [場面,…]　場面: ' + Object.keys(SCENES).join(',')); process.exit(1); }
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  await new Promise(r => srv.listen(0, r)); const port = srv.address().port;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 430, height: 900 }, deviceScaleFactor: +(process.env.DPR || 1) });
  const errs = []; p.on('pageerror', e => errs.push('ERR ' + e.message)); p.on('console', m => { if (m.type() === 'error') errs.push('console ' + m.text()); });
  await p.goto(`http://localhost:${port}/index.html?battle=1&waves=3&boss=1&al=mina&` + q);
  await p.waitForTimeout(4000); await p.evaluate(() => startRun()); await p.waitForTimeout(2500);
  console.log(JSON.stringify(await p.evaluate(() => ({ px: PX.on, fx: !!PX.vOn, err: PX.err || '', foes: G.enemies.length }))));
  await p.evaluate(() => { window.__upd = update; update = function () {}; G.enemies.forEach((e, i) => { e.x = G.hero.x + 160 + i * 70; e.y = G.hero.y + (i % 2 ? 30 : -20); }); }); // 止めて、敵を前に並べる
  for (const [name, [code, ts]] of Object.entries(SCENES)) {
    if (only.length && !only.includes(name)) continue;
    await p.evaluate(() => { window.__align = 0; }); await p.evaluate(code);
    for (let k = 0; k < ts.length; k++) {
      await p.evaluate(t => { if (window.__align) { G.fx.forEach(f => { if (f.t0 == null) f.t0 = f.t; f.t = f.t0 + (f.e && f.e.atk ? f.e.atk.hitT : 0) + t; }); G.enemies.forEach(e => { if (e.atk) e.atk.t = e.atk.hitT + t; }); } else G.fx.forEach(f => f.t = t); if (G.starfall) G.starfall.t = t; G.t = t; G.flash = 0; G.shake = 0; if (G.drops) G.drops.length = 0; draw(); }, ts[k]);
      await p.waitForTimeout(150); await p.evaluate(() => draw()); // 素材の読み込みを待ってもう一度
      await p.screenshot({ path: `${out}_${name}_${k}.png` });
      console.log(name, ts[k], await p.evaluate(() => PX.vstats ? JSON.stringify(PX.vstats) : ''));
    }
  }
  if (process.env.FX_PLAY) { // 実際に遊ぶ：攻撃・技・吸引・投げ・必殺・連携・回避を押し続ける
    await p.evaluate(() => { update = window.__upd; G.hero.hp = G.hero.max = 1e6; });
    const keys = ['KeyJ', 'KeyJ', 'KeyK', 'KeyL', 'KeyJ', 'KeyI', 'KeyU', 'KeyM', 'KeyJ', 'KeyO', 'KeyK'], mx = { v: 0, arc: 0 };
    for (let i = 0; i < 70; i++) { await p.evaluate(k => { __game.press(k); G.hero.hp = G.hero.max; }, keys[i % keys.length]); await p.waitForTimeout(250); const s = await p.evaluate(() => PX.vstats || { v: 0, arc: 0 }); mx.v = Math.max(mx.v, s.v); mx.arc = Math.max(mx.arc, s.arc); }
    console.log('play max', JSON.stringify(mx));
  }
  console.log(errs.slice(0, 15).join('\n') || 'no errors');
  await b.close(); srv.close();
})();
