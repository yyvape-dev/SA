// Desktop Chromium with touch emulation; never physical-device acceptance.
const {chromium}=require('playwright');
const fs=require('fs');const path=require('path');
(async()=>{
 const output=process.env.TD_BROWSER_OUT||'/tmp/td-browser';fs.mkdirSync(output,{recursive:true});
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:844,height:390},hasTouch:true});
 const page=await context.newPage();let messages=[];let failures=[];let pageStart=0;
 page.on('console',m=>{messages.push(m.text());if(m.type()==='error')failures.push(m.text());});page.on('pageerror',e=>failures.push(e.message));
 const records=[];
 async function boot(spot){messages=[];failures=[];pageStart=Date.now();await page.goto((process.env.TD_URL||'http://127.0.0.1:8765/')+'?spot='+spot);await page.waitForFunction(id=>window.__sa2TD?.spot===id,spot,{timeout:120000});}
 await boot('t0');
 // TD toolbar in logical viewport units, converted to browser coordinates.
 let viewport=(await page.evaluate(()=>window.__sa2TD.viewport)).match(/[\d.]+/g).map(Number);
 await page.touchscreen.tap((viewport[0]-520+245)*844/viewport[0],49*390/viewport[1]);
 await page.waitForFunction(()=>window.__sa2TD.probe.token,null,{timeout:15000});
 const namespace=await page.evaluate(()=>window.__sa2TD.user_dir);if(!namespace.endsWith('/SA2-TD-Mobile-Spots'))throw Error('User save namespace not isolated: '+namespace);
 const token=await page.evaluate(()=>window.__sa2TD.probe.token);await page.reload();await page.waitForFunction(t=>window.__sa2TD?.probe.token===t,token,{timeout:120000});
 records.push({spot:'t0',storageReload:true,metrics:await page.evaluate(()=>window.__sa2TD)});
 for(const spot of (process.env.TD_SPOTS||'t1,explore,t2,t3').split(',')){
  await boot(spot);
  if(spot!=='t1')await page.waitForFunction(()=>!!window.__sa2TD?.scene_ready,null,{timeout:120000});
  const loadToReadyMs=Date.now()-pageStart;
  await page.waitForTimeout(2500);
  if(!(await page.evaluate(()=>window.__sa2TD.guide_json)))throw Error('Missing runtime guide JSON');
  if(spot==='t1'){
   for(let n=0;n<2;n++){const m=await page.evaluate(()=>window.__sa2TD);const v=m.viewport.match(/[\d.]+/g).map(Number);await page.touchscreen.tap(m.dialogue_next[0]*844/v[0],m.dialogue_next[1]*390/v[1]);await page.waitForTimeout(700);}
   await page.waitForFunction(()=>window.__sa2TD.dialogue_line>0,null,{timeout:15000});
  }
  if(spot==='t2'){
   for(let n=0;n<12;n++){
    const m=await page.evaluate(()=>window.__sa2TD);if(m.combat_active)break;
    const v=m.viewport.match(/[\d.]+/g).map(Number);await page.touchscreen.tap(m.dialogue_next[0]*844/v[0],m.dialogue_next[1]*390/v[1]);await page.waitForTimeout(800);
   }
   await page.waitForFunction(()=>window.__sa2TD.combat_active,null,{timeout:15000});
   await page.waitForFunction(()=>window.__sa2TD.controls_active,null,{timeout:15000});
   const m=await page.evaluate(()=>window.__sa2TD);const v=m.viewport.match(/[\d.]+/g).map(Number);
   if(m.control_panel!=='legacy_touch_pad'||Object.keys(m.action_buttons).sort().join(',')!=='atk,dodge')throw Error('Legacy panel missing');
   await page.touchscreen.tap(m.action_buttons.atk[0]*844/v[0],m.action_buttons.atk[1]*390/v[1]);
   await page.waitForFunction(()=>window.__sa2TD.attacks>0 && window.__sa2TD.actor_state==='move',null,{timeout:60000});
   await page.touchscreen.tap(m.action_buttons.dodge[0]*844/v[0],m.action_buttons.dodge[1]*390/v[1]);
   await page.waitForTimeout(1500);console.log('T2_AFTER_INPUT',JSON.stringify(await page.evaluate(()=>window.__sa2TD)));await page.screenshot({path:path.join(output,'t2-input.png')});
   await page.waitForFunction(()=>window.__sa2TD.attacks>0 && window.__sa2TD.dodges>0,null,{timeout:15000});
   const cdp=await context.newCDPSession(page);
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:140,y:250,id:0}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:195,y:250,id:0}]});
   await page.waitForFunction(()=>window.__sa2TD.move_vector[0]>0.9,null,{timeout:15000});
   const other=await context.newPage();await other.goto('about:blank');await page.bringToFront();await other.close();
   await page.waitForFunction(()=>window.__sa2TD.move_vector.every(v=>v===0),null,{timeout:15000});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await cdp.detach();
  }
  if(spot==='explore'){await page.touchscreen.tap(160,250);}
  if(spot==='t3'){
   // Start through existing real HUD, then touch-move; no result injection.
   const m=await page.evaluate(()=>window.__sa2TD);const v=m.viewport.match(/[\d.]+/g).map(Number);await page.touchscreen.tap(m.start_button[0]*844/v[0],m.start_button[1]*390/v[1]);await page.waitForFunction(()=>window.__sa2TD.phase==='street' && window.__sa2TD.controls_active,null,{timeout:15000});
   const active=await page.evaluate(()=>window.__sa2TD);
   await page.touchscreen.tap(active.guide_button[0]*844/v[0],active.guide_button[1]*390/v[1]);
   await page.waitForFunction(()=>window.__sa2TD.evac_moving,null,{timeout:15000});
  }
  await page.screenshot({path:path.join(output,spot+'.png')});
  records.push({spot,loadToReadyMs,loadToSampleMs:Date.now()-pageStart,metrics:await page.evaluate(()=>window.__sa2TD),errors:[...failures]});
 }
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(1500);await page.screenshot({path:path.join(output,'portrait.png')});
 fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(records,null,2));
 await browser.close();
 if(records.some(r=>r.errors?.length))throw Error('Browser errors; see results.json');
 console.log('TD_BROWSER_SMOKE_PASS');
})().catch(e=>{console.error(e);process.exit(1)});
