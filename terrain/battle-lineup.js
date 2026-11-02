// Preview only: read live game tables without executing the game or saving settings.
const $ = id => document.getElementById(id);
const NAMES = {rana:'ラナ',mina:'ミナ',garou:'ガロウ',sera:'セラ',ranka:'ランカ',lily:'リリィ',g1:'グレン',g2:'ボルグ',g3:'エルザ',g4:'黒騎士',g5:'ヘルマン',g6:'大公',g6b:'大公（悪魔）'};
const KEYS=Object.keys(NAMES), ALLIES=KEYS.slice(0,6), GEN=KEYS.slice(6,13), cache=new Map(), failures=new Set();
let mode=new URLSearchParams(location.search).get('mode')==='action'?'action':'duel', two=false, paused=false, frame=0, tickMs=0, last=0;
const factors={duel:{},action:{}};
async function resource(url,json=true) { const r=await fetch(url,{cache:'no-cache'});if(!r.ok)throw Error(`${url}: ${r.status}`);return json?r.json():r.text(); }
function numbers(src,name) {
  const clean=src.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'');
  const body=clean.match(new RegExp('\\b'+name+'\\s*=\\s*\\{([^}]+)\\}'))?.[1];
  if(!body)throw Error(`設定 ${name} が見つかりません`);
  const out={};for(const m of body.matchAll(/(\w+)\s*:\s*(-?(?:\d+(?:\.\d*)?|\.\d+))/g))out[m[1]]=Number(m[2]);return out;
}
function picture(url) {
  if(!cache.has(url)) { const im=new Image(),item={im,ready:false};cache.set(url,item);im.onload=()=>{item.ready=true;failures.delete(url);status();};im.onerror=()=>{failures.add(url);status();};im.src=url;status(); }return cache.get(url);
}
function status() { const loading=[...cache.values()].filter(x=>!x.ready&&!failures.has(x.im.getAttribute('src'))).length;$('status').className=failures.size?'error':'';$('status').textContent=failures.size?`素材の読み込みに失敗：${[...failures].join('、')}。再読み込みしてください。`:loading?`素材を読み込み中（${loading}枚）…`:'表示中。調整値はこのページ内だけに保持されます。'; }
let human,height,hu,allyMeta,foeMeta,side,foeSide,atlas,core,defs,anchors,runK;
try {
  let main,ally;
  [main,core,ally,allyMeta,foeMeta,side,foeSide,atlas]=await Promise.all([
    resource('main.js',false),resource('../battle/core.js',false),resource('../battle/ally.js',false),resource('../ally/duel_meta.json'),resource('assets/npc/foeduel_meta.json'),resource('../ally/side_meta.json'),resource('assets/npc/side_meta.json'),resource('../sprites/atlas/rana.json')]);
  human=numbers(main,'HUMAN');height=numbers(core,'HEIGHT');hu=numbers(core,'HU');
  anchors=Object.fromEntries(['M','ATC_A','ATB_A','THR_A','ULT_A'].map(k=>[k,numbers(core,k)]));runK=Number(core.match(/\bRUN_K\s*=\s*([\d.]+)/)[1]);
  defs={};for(const k of ALLIES.slice(1)) { const b=ally.match(new RegExp('\\b'+k+':\\s*\\{([^}]+)\\}'))?.[1];if(!b)throw Error(`仲間設定 ${k} がありません`);defs[k]={runK:Number(b.match(/runK:\s*([\d.]+)/)[1]),clips:b.match(/clips:\s*\[([^\]]+)\]/)[1].split(',').map(Number)}; }
  for(const k of KEYS)if(!(human[k]>0)||!(actionHeight(k)>0))throw Error(`高さ ${k} がありません`);
} catch(e) { $('status').className='error';$('status').textContent=`読み込めませんでした：${e.message}`;throw e; }
function actionHeight(k) {return GEN.includes(k)?hu[k]*233/200:height[k];}
function baseHeight(k) {return mode==='duel'?human[k]:actionHeight(k);}
function actualHeight(k) {return baseHeight(k)*(factors[mode][k]??1)*(mode==='action'&&GEN.includes(k)?1.12:1);}
function clipList(k) {
  if(ALLIES.includes(k)) {const list=allyMeta[k]||[];return mode==='action'&&k!=='rana'?[...defs[k].clips.map(i=>list[i]),...(allyMeta[k+'_ult']||[])]:[...list,...(allyMeta[k+'_ult']||[])];}
  return foeMeta[k.startsWith('f')?k.slice(1):k]||[];
}
function descriptor(k) {
  const motion=$('motion').value,attack=motion.startsWith('attack'),ci=attack?Number(motion.slice(6)):0;
  if(mode==='action'&&k==='rana') {
    const clip=motion==='run'?'run':attack?['atc','atb','thr','ult'][ci]:'idle',name=clip+'_'+String(frame%atlas.clips[clip]).padStart(2,'0'),q=atlas.f[name];
    const a=anchors[clip==='atc'?'ATC_A':clip==='atb'?'ATB_A':clip==='thr'?'THR_A':clip==='ult'?'ULT_A':'M'];
    return {url:'../sprites/atlas/'+atlas.pages[q[0]],rect:q.slice(1,5),dx:q[5]-a.ax,dy:q[6]-a.ay,s:(height.rana/219)*(factors.action.rana??1)*a.k*(motion==='run'?runK:1),n:atlas.clips[clip]};
  }
  const isAlly=ALLIES.includes(k),list=clipList(k),idle=list[0];
  if(motion==='run') {
    const c=isAlly?(side['run_'+k]||side['walk_'+k]):foeSide['walk_'+k.slice(1)];
    if(c) {const i=frame%c.n,s=actualHeight(k)/c.ph*(mode==='duel'?.97:isAlly?defs[k].runK:1);return {url:(isAlly?'../ally/':'assets/npc/')+c.f,rect:[i%c.cols*c.cw,Math.floor(i/c.cols)*c.ch,c.cw,c.ch],dx:-c.ax,dy:-c.ay,s,n:c.n};}
  }
  const c=attack?(list[ci]||idle):idle,i=attack?frame%c.n:0,r=c.fr?.[i]||[i%c.cols*c.cw,Math.floor(i/c.cols)*c.ch,c.cw,c.ch,0,0];
  return {url:(isAlly?'../ally/':'assets/npc/')+c.f,rect:r.slice(0,4),dx:r[4]-(c.idle.x+c.idle.w/2),dy:r[5]-(c.ch-(c.pad??2.8)),s:actualHeight(k)/c.idle.h,n:attack?c.n:1,fallback:(attack&&!list[ci])||motion==='run'};
}
function list() {return two?[$('a').value,$('b').value]:KEYS;}
function output() {
  const vals=Object.fromEntries(KEYS.map(k=>[k,+(baseHeight(k)*(factors[mode][k]??1)).toFixed(3)]));
  const fmt=o=>'{ '+Object.entries(o).map(([k,v])=>`${k}: ${v}`).join(', ')+' };';
  $('out').value=mode==='duel'?'// 一騎打ち・任せた戦闘（HUMAN）。未表示の sol は現行値を維持。\nconst HUMAN = '+fmt({...human,...vals}):'// アクション戦闘（奥行き倍率1.00）。敵将は本番でさらに×1.12。\nvar HEIGHT = '+fmt(Object.fromEntries(Object.keys(height).map(k=>[k,vals[k]??height[k]])))+'\n// 敵将の HU（core.js の FOE_HK 計算用）\nvar HU = '+fmt(Object.fromEntries(GEN.map(k=>[k,+(hu[k]*(factors.action[k]??1)).toFixed(3)])));
}
function panel() {
  $('panel').innerHTML=KEYS.map(k=>`<div class="row" data-k="${k}"><label>${NAMES[k]}（${k}） <span></span><input aria-label="${NAMES[k]}の倍率" type="range" min="0.5" max="1.6" step="0.01" value="${factors[mode][k]??1}"></label><label>倍率 <input aria-label="${NAMES[k]}の倍率数値" type="number" min="0.5" max="1.6" step="0.01" value="${factors[mode][k]??1}"></label></div>`).join('');
  $('panel').querySelectorAll('input').forEach(el=>el.oninput=()=>{const v=+el.value;if(!Number.isFinite(v)||v<.5||v>1.6)return;const row=el.closest('.row'),k=row.dataset.k;factors[mode][k]=v;row.querySelectorAll('input').forEach(x=>{if(x!==el)x.value=v;});labels();output();});labels();
}
function labels() {$('panel').querySelectorAll('.row').forEach(row=>row.querySelector('span').textContent=`基準高 ${actualHeight(row.dataset.k).toFixed(1)}`);}
function refresh() {
  for(const id of ['duel','action'])$(id).setAttribute('aria-pressed',String(mode===id));for(const id of ['all','two'])$(id).setAttribute('aria-pressed',String(two===(id==='two')));
  $('note').textContent=mode==='duel'?'一騎打ち：HUMAN、攻撃の idle.h、走りの×0.97補正を使用。画面の寄りとは独立した共通縮尺です。':'アクション：HEIGHT／敵将のHUを使用。全員を奥行き倍率1.00で比較。敵将の×1.12と仲間の走り専用補正を含みます。';
  $('note').textContent+=' 動きは確認用に毎秒12コマでループ。該当素材のない動きは構えで表示します。';panel();output();resetFrame();
}
function resetFrame() {frame=0;tickMs=0;$('frame').value=0;}
function render(now) {
  if(!paused){tickMs+=Math.min(100,now-(last||now));if(tickMs>=1000/12){frame++;tickMs-=1000/12;}}last=now;
  const keys=list(),ds=keys.map(descriptor),zoom=+$('zoom').value,gap=two?360:230,base=490,w=Math.max(760,keys.length*gap+160),h=560;
  const canvas=$('sheet'),cw=Math.round(w*zoom),ch=Math.round(h*zoom),dpr=Math.min(2,devicePixelRatio||1,Math.sqrt(14000000/(cw*ch)));
  if(canvas.width!==Math.round(cw*dpr)||canvas.height!==Math.round(ch*dpr)){canvas.width=Math.round(cw*dpr);canvas.height=Math.round(ch*dpr);canvas.style.width=cw+'px';canvas.style.height=ch+'px';}
  const g=canvas.getContext('2d');g.setTransform(dpr*zoom,0,0,dpr*zoom,0,0);g.clearRect(0,0,w,h);g.font='12px system-ui';
  for(let y=0;y<=450;y+=50){g.strokeStyle=y%100?'#00ffff35':'#00ffff80';g.beginPath();g.moveTo(0,base-y);g.lineTo(w,base-y);g.stroke();g.fillStyle='#83eeee';g.fillText(y,4,base-y-4);}
  let drawn=0;
  ds.forEach((d,i)=>{const k=keys[i],x=80+(i+.5)*gap,item=picture(d.url);if(item.ready){drawn++;g.save();g.translate(x,base);g.scale(ALLIES.includes(k)?-d.s:d.s,d.s);g.drawImage(item.im,...d.rect,d.dx,d.dy,d.rect[2],d.rect[3]);g.restore();}
    const height=actualHeight(k);g.strokeStyle='#f48cfa';g.beginPath();g.moveTo(x-60,base-height);g.lineTo(x+60,base-height);g.stroke();g.textAlign='center';g.fillStyle='#fff0d0';g.fillText(`${NAMES[k]} ×${(factors[mode][k]??1).toFixed(2)}`,x,base+22);g.fillText(`基準高 ${height.toFixed(1)}${d.fallback?'（構えで代用）':''}`,x,base+40);g.textAlign='left';});
  canvas.dataset.ready=String(drawn===ds.length);
  const n=Math.max(...ds.map(d=>d.n));$('frame').max=n-1;$('frame').value=frame%n;
  requestAnimationFrame(render);
}
for(const id of ['a','b'])for(const k of KEYS)$(id).add(new Option(`${NAMES[k]}（${k}）`,k));$('a').value='rana';$('b').value='garou';
for(const id of ['duel','action'])$(id).onclick=()=>{mode=id;history.replaceState(null,'','?mode='+id);refresh();};
$('all').onclick=()=>{two=false;refresh();};$('two').onclick=()=>{two=true;refresh();};$('a').onchange=$('b').onchange=()=>{two=true;refresh();};
$('motion').onchange=resetFrame;$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'再生':'一時停止';};
function seek(v){paused=true;$('pause').textContent='再生';frame=v;tickMs=0;}
$('step').onclick=()=>seek((frame+1)%(+$('frame').max+1));$('frame').oninput=()=>seek(+$('frame').value);
$('reset').onclick=()=>{factors[mode]={};refresh();};$('copy').onclick=async()=>{try{await navigator.clipboard.writeText($('out').value);$('status').textContent='コピーしました。このチャットに貼ってください。';}catch{$('out').focus();$('out').select();$('status').textContent='下の数値を選択しました。手動でコピーしてください。';}};
refresh();requestAnimationFrame(render);
