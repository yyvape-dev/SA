// 最終章の新しい避難路→アクション、未完の中盤戦への復帰を検証する。
const {chromium}=require('playwright'), assert=require('assert/strict');
const base=process.env.SA_TEST_URL||'http://127.0.0.1:8123/terrain/';
(async()=>{
  const b=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try {
    const p=await b.newPage({viewport:{width:430,height:900}}),errors=[];
    p.on('pageerror',e=>{errors.push(e.message);console.error('PAGEERROR',e.message)});
    await p.route('**/index.html?battle=*',route=>route.fulfill({contentType:'text/html',body:'<p>戦闘への受け渡しを検証中</p>'}));
    await p.goto(base+'index.html?dev=0');
    await p.waitForFunction(()=>window.__t?.G&&window.__t.status.ok,null,{timeout:180000});
    await p.evaluate(()=>{const s=__t.G();s.week=36;s.chStart=0;s.proSeen=true;s.over=null;s.open=['east','lake','forest','pass2','capital'];s.met={lily:true};s.troops=16;s.sup=100;s.morale=80;s.raid={...__t.GM.SCHED.find(x=>x.w===36),kind:'raid',E:1};__t.sync();});
    const decision=await p.locator('#rdec').textContent();assert.ok(decision.includes('避難路'));assert.ok(!decision.includes('副将グレンと一騎打ち'));
    await p.locator('#rdec .go').click();await p.waitForSelector('#abt .sk');await p.evaluate(()=>document.querySelector('#abt .sk').click());
    await p.waitForSelector('#abt .fr.on');await p.locator('#abt .fr.on').click();
    await p.waitForSelector('#story .skip');
    assert.equal(await p.locator('#dsel:visible').count(),0,'Glenn must not challenge a duel during evacuation');
    await p.waitForFunction(()=>[...document.querySelectorAll('#story img.a')].every(i=>i.naturalWidth>0));await p.waitForTimeout(500);await p.screenshot({path:'/tmp/sa-final-escape.png'});
    await p.locator('#story .skip').click();await p.waitForURL('**/index.html?battle=*');
    let q=new URL(p.url()).searchParams;assert.equal(q.get('gen'),'g6');assert.equal(q.get('al'),'mina');assert.equal(q.get('boss'),'1');
    console.log('PASS: chapter 6 prelude -> evacuation (no duel) -> g6 boss with Mina');
    // ブラウザの戻る等で未完戦から領地へ来ても、同じIDで再開。
    await p.evaluate(()=>{const s=JSON.parse(localStorage.getItem('territory_v2'));s.week=29;s.raid=null;s.battle=null;s.over=null;s.chStart=0;s.proSeen=true;s.skirm={id:'unfinished-check',ev:'c5_lesson'};s.skirmAfter=null;localStorage.removeItem('battle_result');localStorage.setItem('territory_v2',JSON.stringify(s));});
    await p.goto(base+'index.html');await p.waitForURL('**/index.html?battle=*',{timeout:180000});
    q=new URL(p.url()).searchParams;assert.equal(q.get('id'),'unfinished-check');assert.equal(q.get('gen'),'g5');assert.equal(q.get('al'),'');
    assert.deepEqual(errors,[]);console.log('PASS: unfinished skirmish resumes with same id; page errors=0');
  } finally {await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
