// 領地マップを発展度ごとに同じ視点で撮って並べる（Skill sa-map-check）
// 使い方: node terrain/tools/map_shot.js "<発展度,…>" <出力フォルダ> [拡大 x y]
//   例: node terrain/tools/map_shot.js 0,2,3,5 /tmp/mapc      … 本拠の街（既定の視点）
//       node terrain/tools/map_shot.js 0,5 /tmp/mapc 1.6 470 1000  … 広場に寄る
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs'), path = require('path');
const lvs = (process.argv[2] || '0,3,5').split(',').map(Number), out = process.argv[3] || '/tmp/mapc';
const view = process.argv[4] ? process.argv.slice(4, 7).map(Number) : null;
const base = process.env.MS_URL || 'http://localhost:8123/terrain/';
fs.mkdirSync(out, { recursive: true });
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const files = [];
  for (const lv of lvs) {
    const p = await b.newPage({ viewport: { width: 540, height: 960 } });
    p.on('pageerror', e => console.log(`[dev${lv}] ERR`, e.message));
    p.on('console', m => { if (m.type() === 'error') console.log(`[dev${lv}] console`, m.text()); });
    await p.goto(`${base}?dev=${lv}&v=${Date.now()}`, { waitUntil: 'load' });
    await p.waitForFunction(() => window.__t && window.__t.status && window.__t.status.ok, null, { timeout: 180000 });
    if (view) await p.evaluate(v => window.__t.setView(...v), view);
    await p.waitForTimeout(2500);
    const f = path.join(out, `dev${lv}.png`); await p.screenshot({ path: f }); files.push(f);
    console.log(`dev${lv}`, JSON.stringify(await p.evaluate(() => ({ dev: window.__t.dev(), props: window.__t.status.props }))));
    await p.close();
  }
  await b.close();
  execFileSync('python3', ['-I', '-c', `
import sys
from PIL import Image, ImageDraw
fs=sys.argv[2:]; ims=[Image.open(f) for f in fs]; w,h=ims[0].size
S=Image.new('RGB',(w*len(ims),h),'black')
for i,(im,f) in enumerate(zip(ims,fs)):
  S.paste(im,(i*w,0)); ImageDraw.Draw(S).text((i*w+8,h-24),f.split('/')[-1],fill='yellow')
S.save(sys.argv[1])`, path.join(out, 'sheet.png'), ...files]);
  console.log('sheet', path.join(out, 'sheet.png'));
})();
