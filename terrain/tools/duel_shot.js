// 一騎打ちをヘッドレスで撮る（2026-10-31）。リポジトリを自分で配信して、?duel=<章> を開き、仲間を選んで挑み、一定間隔で撮って一覧画像にまとめる。
// 使い方: node terrain/tools/duel_shot.js [章 1〜6] [仲間,仲間（空＝初期選択のまま）] [win|lose|rand] [出力フォルダ]
//   例: node terrain/tools/duel_shot.js 5 lily,ranka win /tmp/duel   → /tmp/duel/sheet.png（選出画面＋戦闘14枚＋結果）と、舞台だけを拡大した stage.png
// 依存：playwright（環境に入っているもの）と python3 の PIL（一覧画像を作る）。描画は遅いので全体で2〜4分。
const http = require('http'), fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const [ch = '5', picks = '', mode = 'win', out = '/tmp/duel'] = process.argv.slice(2);
const ROOT = path.resolve(__dirname, '../..'), TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.webp': 'image/webp', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2' };
fs.mkdirSync(out, { recursive: true });
const srv = http.createServer((q, r) => { const f = path.join(ROOT, decodeURIComponent(q.url.split('?')[0])); if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); r.end(); return; }
  r.writeHead(200, { 'Content-Type': TYPES[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(r); }).listen(0, async () => {
  const port = srv.address().port, b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage({ viewport: { width: 430, height: 900 } }), errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto(`http://localhost:${port}/terrain/index.html?duel=${ch}`);
  await p.waitForSelector('#dsel .cd', { timeout: 180000 }); await p.waitForTimeout(1500);
  const want = picks.split(',').filter(Boolean);
  if (want.length) { // 欲しい組を作る：目的の1人目を選んだ状態にしてから他を外し、残りを順に選ぶ（最後の1人は外せない決まり）
    const on = async k => p.$eval(`#dsel .cd[data-k="${k}"]`, c => c.classList.contains('on'));
    if (!(await on(want[0]))) await p.click(`#dsel .cd[data-k="${want[0]}"]`);
    for (const k of await p.$$eval('#dsel .cd.on', cs => cs.map(c => c.dataset.k))) if (k !== want[0]) await p.click(`#dsel .cd[data-k="${k}"]`);
    for (const k of want.slice(1)) await p.click(`#dsel .cd[data-k="${k}"]`); }
  console.log('選択:', await p.$eval('#dsel .go', e => e.textContent), '／', await p.$eval('#dsel .hint', e => e.textContent));
  await p.screenshot({ path: `${out}/s00.png` });
  if (mode !== 'rand') await p.evaluate(m => { Math.random = () => (m === 'win' ? 0.02 : 0.98); }, mode);
  await p.click('#dsel .go');
  for (let i = 1; i <= 14; i++) { await p.waitForTimeout(1500); await p.screenshot({ path: `${out}/s${String(i).padStart(2, '0')}.png` }); }
  await p.waitForTimeout(5000); await p.screenshot({ path: `${out}/s15.png` });
  console.log('エラー:', errs.length ? errs : 'なし');
  await b.close(); srv.close();
  execFileSync('python3', ['-c', `
from PIL import Image
o='${out}'; fs=[f'{o}/s{i:02d}.png' for i in range(16)]
ims=[Image.open(f).resize((215,450)) for f in fs]; g=Image.new('RGB',(215*8,900))
for i,im in enumerate(ims): g.paste(im,((i%8)*215,(i//8)*450))
g.save(f'{o}/sheet.png')
st=[Image.open(f).crop((0,130,430,700)).resize((215,285)) for f in fs[1:15]]; g=Image.new('RGB',(215*7,570))
for i,im in enumerate(st): g.paste(im,((i%7)*215,(i//7)*285))
g.save(f'{o}/stage.png')`]);
  console.log('出力:', `${out}/sheet.png`, `${out}/stage.png`);
});
