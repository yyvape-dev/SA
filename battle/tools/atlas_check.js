// アトラスの位置ずれの確認：Canvas 版で全コマを「アトラス」と「元の PNG」で同じ所に描いて、画面に出る色（色×アルファ）を比べる。Skill sa-sprite-atlas。
// 使い方（リポジトリ直下で）: node battle/tools/atlas_check.js　→ maxd（最大の差、2以下なら合格）・nbad（差のあるコマ数。丸めの差なので多くても可）
const { chromium } = require('playwright'), http = require('http'), fs = require('fs'), path = require('path');
const ROOT = require('path').resolve(__dirname, '../..');
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); } r.writeHead(200); fs.createReadStream(f).pipe(r); });
(async () => { await new Promise(r => srv.listen(8790, r));
 const b = await chromium.launch(); const p = await b.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message));
 await p.goto('http://localhost:8790/index.html?px=0'); await p.waitForTimeout(5000);
 const res = await p.evaluate(async () => {
   const names = Object.keys(ATL.f), A = { ax: 400, ay: 500, k: 1 }, c = document.createElement('canvas'); c.width = 1100; c.height = 800; const x = c.getContext('2d'); const keep = ctx; let bad = [], maxd = 0;
   for (const n of names) {
     const im = new Image(); im.src = 'sprites/' + n + '.png'; await im.decode(); IMG[n] = im;
     ctx = x; x.setTransform(1,0,0,1,0,0); x.clearRect(0,0,1100,800); drawSprite(n, 500, 600, 1, 1, 1, A, 0); const a = x.getImageData(0,0,1100,800).data;
     const s = ATL; ATL = null; x.setTransform(1,0,0,1,0,0); x.clearRect(0,0,1100,800); drawSprite(n, 500, 600, 1, 1, 1, A, 0); ATL = s; const bb = x.getImageData(0,0,1100,800).data; ctx = keep;
     let d = 0, cnt = 0, big = 0, amax = -1; for (let i = 0; i < a.length; i += 4) { if (a[i+3] === 0 && bb[i+3] === 0) continue; const P = (v, al) => v * al / 255; const m = Math.round(Math.max(Math.abs(P(a[i],a[i+3])-P(bb[i],bb[i+3])), Math.abs(P(a[i+1],a[i+3])-P(bb[i+1],bb[i+3])), Math.abs(P(a[i+2],a[i+3])-P(bb[i+2],bb[i+3])), Math.abs(a[i+3]-bb[i+3]))); if (m > 0) cnt++; if (m > 40) big++; if (m > d) { d = m; amax = [a[i],a[i+1],a[i+2],a[i+3],bb[i],bb[i+1],bb[i+2],bb[i+3]].join(','); } }
     if (d > 0) bad.push(n + ':' + d + ' cnt' + cnt + ' big' + big + ' @' + amax); maxd = Math.max(maxd, d); delete IMG[n];
   }
   return { n: names.length, pages: ATL.pages.length, bad: bad.filter(t=>/big[1-9]/.test(t)).slice(0,6).concat(bad.slice(0,3)), nbad: bad.length, maxd };
 });
 console.log(JSON.stringify(res)); console.log(errs.join('\n') || 'no errors'); await b.close(); srv.close(); })();
