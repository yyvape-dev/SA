// 要：localhost:8123でリポジトリを配信、playwrightとChromium。
// node terrain/tools/scenario_browser_check.cjs [出力先=/tmp/sa-story-check]
// 戦闘の勝敗は境界で注入する。アクションの難易度を検証するテストではない。
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const out = process.argv[2] || '/tmp/sa-story-check', base = process.env.SA_TEST_URL || 'http://127.0.0.1:8123/terrain/';
fs.mkdirSync(out, { recursive: true });
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  try {
    const page = await browser.newPage({ viewport: { width: 430, height: 900 } }), errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto(base + 'story-review.html');
    await page.waitForSelector('#scene option', { state: 'attached' });
    const entries = await page.locator('#scene option').evaluateAll(es => es.map(e => ({ value: e.value, label: e.textContent, event: e.dataset.event })));
    let rendered = 0;
    for (const entry of entries) {
      await page.selectOption('#scene', entry.value);
      await page.click('#text');
      assert.ok((await page.locator('#transcript').textContent()).length > entry.label.length);
      await page.click('#play');
      await page.waitForSelector('#story .skip');
      await page.locator('#story .skip').click();
      if (await page.locator('#story .chs button').count()) {
        await page.locator('#story .chs button').first().click();
        await page.locator('#story .skip').click();
      }
      await page.waitForSelector('#story', { state: 'hidden' });
      rendered++;
    }
    // 中盤戦の勝敗、後日談の両方の政策、両方の刑を表示できる。
    for (const p of ['0', '1']) {
      await page.selectOption('#path', p);
      for (const e of entries.filter(e => /c3_borg|c4_elza|c4_borg|c5_elza|c5_lesson/.test(e.event))) {
        await page.selectOption('#scene', e.value);
        for (const result of ['win','lose']) { await page.selectOption('#outcome', result); await page.click('#text'); assert.ok((await page.locator('#transcript').textContent()).length > 40); }
      }
      await page.selectOption('#outcome','before');
      await page.selectOption('#scene', entries.find(e => e.label.includes('第6章') && e.label.endsWith('勝利')).value);
      await page.click('#play'); await page.waitForSelector('#story .skip'); await page.locator('#story .skip').click();
      assert.equal(await page.locator('#story .chs button').count(),2);
      await page.locator('#story .chs button').nth(+p).click();
      await page.waitForTimeout(1100); await page.screenshot({path:path.join(out,`sentence-${p}.png`)});
      await page.locator('#story .skip').click();
    }
    console.log('Preview scenes rendered:', rendered);
    if (process.env.SA_PREVIEW_ONLY === '1') {assert.deepEqual(errors,[]);return;}
    await page.goto(base + 'index.html?dev=0');
    await page.waitForFunction(() => window.__t?.G && window.__t.status.ok, null, { timeout: 180000 });
    const initialize = async (week, seen = {}) => page.evaluate(({week,seen}) => {
      const s=__t.G();s.week=week;s.chStart=0;s.proSeen=true;s.raid=null;s.over=null;s.skirm=null;s.skirmAfter=null;s.sup=50;s.morale=60;s.evSeen=seen;s.storyChoices={};s.virtue={mercy:0,rigor:0};s.open=['east','lake','forest','pass2','capital'];s.met={lily:true};__t.sync();
    }, {week,seen});
    await initialize(9,{c2_deserter:1});
    await page.evaluate(()=>__t.weekEvents());await page.waitForSelector('#story .skip');await page.locator('#story .skip').click();
    await page.locator('#story .chs button').first().click();
    assert.equal(await page.evaluate(()=>__t.G().sup),47);
    // 選択後・会話未完のまま保存し直す。
    await page.reload();await page.waitForFunction(()=>window.__t?.G&&window.__t.status.ok,null,{timeout:180000});
    await page.evaluate(()=>__t.weekEvents());await page.waitForSelector('#story .skip');
    assert.equal(await page.locator('#story .chs button').count(),0);
    await page.locator('#story .skip').click();
    assert.equal(await page.evaluate(()=>__t.G().sup),47);
    assert.equal(await page.evaluate(()=>__t.G().evSeen.c2_share),1);
    // 古い保存の未選択には、架空の過去の選択を補わない。
    await initialize(10);await page.evaluate(()=>__t.weekEvents());await page.waitForSelector('#story .skip');
    await page.waitForTimeout(900);await page.screenshot({path:path.join(out,'legacy-response.png')});await page.locator('#story .skip').click();
    // 中盤戦の帰還時に実際の戦闘結果を読み、勝敗別の会話を再開する。
    for (const won of [true,false]) {
      await initialize(29,{c5_lesson:1,c5_mina_after:1});
      await page.evaluate(won=>{const s=__t.G();s.skirm={id:'return-test',ev:'c5_lesson'};__t.commit();localStorage.setItem('battle_result',JSON.stringify({id:'return-test',win:won}));},won);
      await page.reload();await page.waitForFunction(()=>window.__t?.G&&window.__t.status.ok,null,{timeout:180000});
      await page.waitForSelector('#story .skip');
      assert.equal(await page.evaluate(()=>__t.G().skirmResults.c5_lesson),won);
      assert.ok(await page.evaluate(()=>!!__t.G().skirmAfter));
      // 保留中に再ロードしても、結果の加算は一度、会話は再開する。
      const sup=await page.evaluate(()=>__t.G().sup);
      await page.reload();await page.waitForFunction(()=>window.__t?.G&&window.__t.status.ok,null,{timeout:180000});
      await page.evaluate(()=>__t.weekEvents());await page.waitForSelector('#story .skip');
      assert.equal(await page.evaluate(()=>__t.G().sup),sup);
      await page.waitForTimeout(1500);await page.screenshot({path:path.join(out,`skirmish-${won}.png`)});
      await page.locator('#story .skip').click();assert.equal(await page.evaluate(()=>__t.G().skirmAfter),null);
    }
    // 最終章の保存から結末を出し、処遇の選択後に再開しても重複しない。
    await initialize(36);
    await page.evaluate(()=>{const s=__t.G();s.over='win';s.chEnd={c:6,win:true};__t.commit();});
    await page.waitForSelector('#story .skip');await page.locator('#story .skip').click();
    await page.locator('#story .chs button').nth(1).click();
    await page.reload();await page.waitForFunction(()=>window.__t?.G&&window.__t.status.ok,null,{timeout:180000});
    await page.waitForSelector('#story .skip');
    assert.equal(await page.locator('#story .chs button').count(),0);
    assert.equal(await page.evaluate(()=>__t.G().storyChoices.c6_judgment),1);
    assert.equal(await page.evaluate(()=>__t.G().virtue.rigor),1);
    await page.locator('#story .skip').click();
    assert.equal(await page.evaluate(()=>__t.G().chEnd),null);
    assert.deepEqual(errors,[]);
    console.log('PASS: choice replay, legacy state, both battle returns, pending dialogue reload, ending reload; page errors=0');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
