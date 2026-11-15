// Browser smoke check. Uses the real exported game and touch events, no fixtures.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
 const out = process.env.TREE_WEB_EVIDENCE || path.resolve(__dirname, '../docs/skill_tree_polish/evidence');
 fs.mkdirSync(out, {recursive:true});
 const browser = await chromium.launch({executablePath:'/usr/bin/chromium', headless:true,
  args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page = await browser.newPage({viewport:{width:844,height:390}, hasTouch:true});
 const errors=[]; const logs=[]; const packs=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{logs.push(m.text());if(/SCRIPT ERROR|Parse Error|unsupported format/.test(m.text()))errors.push(m.text());});
 page.on('response',r=>{if(r.url().includes('.pck'))packs.push({url:r.url(),status:r.status()});});
 await page.goto((process.env.TREE_WEB_URL||'http://127.0.0.1:8765/')+'?town=back', {waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>document.querySelector('canvas') && !document.querySelector('#status'),null,{timeout:120000});
 await page.waitForTimeout(12000);
 await page.screenshot({path:path.join(out,'web_town.png')});
 await page.touchscreen.tap(617,362); // existing town gear target
 await page.waitForTimeout(2500);
 await page.screenshot({path:path.join(out,'web_tree.png')});
 await page.touchscreen.tap(58,188); // Lily tab
 await page.waitForTimeout(500);
 await page.screenshot({path:path.join(out,'web_lily.png')});
 await page.touchscreen.tap(75,40); // slot setting tab
 await page.waitForTimeout(500);
 await page.screenshot({path:path.join(out,'web_slots.png')});
 await page.touchscreen.tap(795,40); // close
 await page.waitForTimeout(1200);
 await page.screenshot({path:path.join(out,'web_closed.png')});
 fs.writeFileSync(path.join(out,'web-console.json'),JSON.stringify({errors,logs,packs},null,2));
 await browser.close();
 if(errors.length)throw new Error(errors.join('\n'));
 console.log('SKILL_TREE_WEB captured town → tree → Lily → slots → close; pageerrors='+errors.length);
})().catch(e=>{console.error(e);process.exit(1)});
