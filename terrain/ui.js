// 画面のUI（DOM）。モック（GPTのモック2の夜版）に合わせた3層：
//  上＝題と12週の列／巻物の帯（週・次の襲撃・敵の規模）／資源6つ。下＝立ち絵つきのパネル（選んだ場所・行動・費用・効果・大ボタン・週を終える）。
// ルールは持たない。main.js が組み立てたデータを描くだけ。
const ICO = {
  sup: '<rect x="3" y="6" width="18" height="14" rx="2" fill="#c9984f" stroke="#5a3d16" stroke-width="1.5"/><path d="M3 11h18M12 6v14" stroke="#5a3d16" stroke-width="1.5"/>',
  mor: '<circle cx="12" cy="12" r="9" fill="#ffd27a" stroke="#7a5a1a" stroke-width="1.5"/><circle cx="8.6" cy="10" r="1.3" fill="#5a3d16"/><circle cx="15.4" cy="10" r="1.3" fill="#5a3d16"/><path d="M7.5 14.5q4.5 4 9 0" stroke="#5a3d16" stroke-width="1.6" fill="none"/>',
  trp: '<path d="M4 15a8 8 0 0 1 16 0v5H4z" fill="#9fb4d6" stroke="#2b3550" stroke-width="1.5"/><rect x="7" y="13" width="10" height="3" fill="#2b3550"/><path d="M12 4v3" stroke="#2b3550" stroke-width="2"/>',
  def: '<path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6z" fill="#6fa0e8" stroke="#1b2438" stroke-width="1.5"/>',
  hp: '<path d="M4 21V9l3-2v3h3V7l2-2 2 2v3h3V7l3 2v12z" fill="#a89a80" stroke="#3a3024" stroke-width="1.4"/><rect x="10" y="15" width="4" height="6" fill="#3a3024"/>',
  ap: '<path d="M8 3h5v10l6 3v4H5v-4l3-2z" fill="#c9984f" stroke="#5a3d16" stroke-width="1.5"/>',
  build: '<path d="M4 20l9-9M11 5l8 8-3 3-8-8z" stroke="#ffd77a" stroke-width="2.2" fill="#6b4a2a"/>',
  castle: '<path d="M3 21V8h3v3h3V8h2v3h2V8h2v3h3V8h3v13z" fill="#c9b48a" stroke="#3a3024" stroke-width="1.4"/>',
  flag: '<path d="M6 21V3M6 4h11l-3 4 3 4H6" stroke="#ffd77a" stroke-width="1.8" fill="#8a2a1a"/>',
  ally: '<circle cx="12" cy="8" r="4" fill="#e8c8a0" stroke="#5a3d16" stroke-width="1.4"/><path d="M4 21c1-5 4-7 8-7s7 2 8 7z" fill="#8a2a1a" stroke="#5a3d16" stroke-width="1.4"/>',
  skull: '<circle cx="12" cy="11" r="8" fill="#eee4e4" stroke="#401015" stroke-width="1.5"/><circle cx="9" cy="11" r="2.1" fill="#401015"/><circle cx="15" cy="11" r="2.1" fill="#401015"/><rect x="9" y="17" width="6" height="4" fill="#eee4e4" stroke="#401015"/>',
};
// 絵のアイコン（assets/ui/、外部AIのシートから切り出し）。絵がない名前は、SVGの仮アイコンにする
const PNG = { sup: 'ic_sup', mor: 'ic_mor', trp: 'ic_trp', def: 'ic_def', hp: 'ic_hp', ap: 'ic_ap', build: 'ic_build', demolish: 'ic_demolish', castle: 'ic_hp', flag: 'ic_flag', ally: 'ic_ally', skull: 'wk_boss', star: 'ic_star' };
export const ico = (n, px = 22) => PNG[n] ? `<img src="assets/ui/${PNG[n]}.png" alt="" style="height:${px}px;width:auto;flex:none;vertical-align:middle;filter:drop-shadow(0 1px 1px #000a)">` : `<svg viewBox="0 0 24 24" width="${px}" height="${px}" style="flex:none;vertical-align:middle">${ICO[n] || ''}</svg>`;
const SERIF = '"Hiragino Mincho ProN","Yu Mincho","Noto Serif JP",serif';
const css = `
.fr{position:relative;isolation:isolate;border:12px solid transparent;border-image:url(assets/ui/frame_l.png) 90 / 12px / 2px stretch;margin:-6px}
.fr::before{content:"";position:absolute;inset:-8px;z-index:-1;background:linear-gradient(#26190ff2,#130b07f5);border-radius:3px}
.frs{position:relative;isolation:isolate;border:10px solid transparent;border-image:url(assets/ui/frame_s.png) 70 / 10px / 1px stretch;margin:-5px}
.frs::before{content:"";position:absolute;inset:-7px;z-index:-1;background:linear-gradient(#26190ff2,#130b07f5);border-radius:3px}
#top{position:fixed;left:0;right:0;top:0;z-index:4;padding:calc(env(safe-area-inset-top) + 1px) 3px 0;pointer-events:none;color:#f3e6c0;font:600 12px/1.3 system-ui,"Noto Sans JP",sans-serif;text-shadow:0 1px 2px #000}
#top .t1{display:flex;align-items:center;gap:6px;padding:0 2px}#top .t1w{margin:0 0 0 18px}#top .bnr{position:absolute;left:2px;top:calc(env(safe-area-inset-top) + 0px);height:34px;z-index:1;filter:drop-shadow(0 2px 3px #000)}
#top .ttl{font:700 11px/1 ${SERIF};color:#ffe3a0;white-space:nowrap}
#top .wk{flex:1;display:flex;align-items:center;justify-content:space-between;position:relative;min-width:0}
#top .wk:before{content:"";position:absolute;left:4px;right:4px;top:50%;height:2px;background:#6a5030}
#top .wk i{position:relative;width:13px;height:13px;background:url(assets/ui/wk_norm.png) center/contain no-repeat;font:700 6.5px/13px system-ui;color:#e0c890;text-align:center;font-style:normal}
#top .wk i.past{background-image:url(assets/ui/wk_past.png);color:#d8d0c0}#top .wk i.raid{background-image:url(assets/ui/wk_raid.png);color:#ffe0d0}
#top .wk i.now{width:16px;height:16px;line-height:16px;font-size:8px;background-image:url(assets/ui/wk_now.png);color:#3a2410;filter:drop-shadow(0 0 5px #ffcc66)}
#top .scroll{margin:-2px 0 0;display:flex;align-items:center;gap:7px;padding:0 6px;min-height:19px;border-style:solid;border-width:2px 24px;border-color:transparent;border-image:url(assets/ui/scroll.png) 40 110 40 110 fill / 2px 24px stretch;color:#3a2410;text-shadow:none;font:700 11px/1.2 ${SERIF};filter:drop-shadow(0 2px 3px #000a)}
#top .scroll .wkn{font-size:12px;white-space:nowrap}#top .scroll .sep{width:1px;align-self:stretch;background:#8a6430}
#top .scroll .foe{margin-left:auto;display:flex;align-items:center;gap:3px;color:#7a1a10;white-space:nowrap}
#top .res{margin:-3px -4px 0;display:grid;grid-template-columns:repeat(6,1fr);gap:0;padding:0 2px}
#top .res div{display:flex;align-items:center;gap:2px;padding:0 2px;border-right:1px solid #5a4024;min-width:0}#top .res div:last-child{border:0}
#top .res b{display:block;white-space:nowrap;font:700 12px/1.1 system-ui;color:#fff2d0}#top .res small{display:block;font-size:8px;line-height:1.1;color:#c9b48a;white-space:nowrap}
#top .res .bar{height:2px;background:#3a2a1a;border-radius:2px;margin-top:1px;overflow:hidden}#top .res .bar span{display:block;height:100%}
#top .res .d{font-size:8px;font-weight:600;color:#9fd08a}#top .res .n{font-size:8px;color:#ff9a8a}
#pnl{position:fixed;left:2px;right:2px;bottom:calc(env(safe-area-inset-bottom) + 2px);margin:0;z-index:4;height:auto;min-height:132px;display:flex;color:#f3e6c0;font:600 12px/1.35 system-ui,"Noto Sans JP",sans-serif}
#pnl .por{width:26%;position:relative;overflow:hidden;border-right:1px solid #6a5030;background:radial-gradient(ellipse at 50% 30%,#4a3020,#1a100a)}
#pnl .por img{position:absolute;left:50%;top:0;width:150%;transform:translateX(-50%)}#pnl.talk .big{font-size:14px;white-space:nowrap}
#pnl.talk .bub{position:absolute;left:24%;right:10px;bottom:calc(100% + 2px);max-height:none;margin:0;box-shadow:0 3px 10px #000a;border:1.5px solid #8a6430}#pnl.talk .bub:before{left:14px;top:auto;bottom:-14px;border:7px solid transparent;border-top:9px solid #fbf4e2}
#pnl .por .nm{position:absolute;left:0;right:0;bottom:0;padding:3px 6px;background:linear-gradient(#0000,#000c);font:700 12px/1.2 ${SERIF};color:#ffe3a0}
#pnl .card{flex:1;display:flex;flex-direction:column;padding:3px 6px;min-width:0}
#pnl .hd{display:flex;align-items:center;gap:5px;font:700 13px/1.2 ${SERIF};color:#ffe3a0;padding-bottom:5px;background:url(assets/ui/divider.png) bottom/100% 5px no-repeat}
#pnl .chips{display:flex;gap:4px;flex-wrap:nowrap;overflow-x:auto;margin-top:3px;scrollbar-width:none}
#pnl .chips button{pointer-events:auto;flex:none;padding:2px 7px;border-radius:12px;border:1px solid #8a6a40;background:#2a1c12;color:#e8d8b0;font:700 11px/1.3 system-ui,"Noto Sans JP",sans-serif}
#pnl .chips button.on{background:linear-gradient(#f0d58a,#c9a24a);color:#2a1a08;border-color:#ffe9a8}#pnl .chips button.x{opacity:.5}
#pnl .act{margin-top:3px;font:700 13px/1.25 ${SERIF};color:#fff2d0}
#pnl .cost{display:flex;gap:8px;align-items:center;margin-top:1px;font-weight:700;font-size:11px;flex-wrap:wrap}#pnl .cost .m{color:#ff9a8a}#pnl .cost .p{color:#9fd08a}
#pnl .eff{color:#a8d4ff;font-size:11px}#pnl .why{color:#ff9a8a;font-size:11px}
#pnl .bub{margin-top:5px;padding:6px 8px;border-radius:8px;background:#fbf4e2;color:#2a1a08;font:600 12px/1.45 ${SERIF};position:relative;max-height:64px;overflow:auto}
#pnl .bub:before{content:"";position:absolute;left:-9px;top:10px;border:6px solid transparent;border-right:9px solid #fbf4e2}
#pnl .btns{margin-top:auto;padding-top:4px;display:flex;gap:6px}
.big{pointer-events:auto;flex:1;min-height:36px;display:flex;align-items:center;justify-content:center;gap:6px;font:700 15px/1 ${SERIF};color:#2a1a08;text-shadow:0 1px 0 #fff6;background:none;border-style:solid;border-width:8px 16px;border-color:transparent;border-image:url(assets/ui/btn_gold.png) 40 60 fill / 8px 16px stretch;padding:0 4px;filter:drop-shadow(0 2px 3px #000a)}
.big:active{border-image-source:url(assets/ui/btn_gold_p.png);filter:brightness(.9)}
.big:disabled{filter:grayscale(.85) brightness(.65)}
.wkb{pointer-events:auto;flex:none;padding:0 2px;min-height:36px;font:700 12px/1.1 ${SERIF};color:#f3e6c0;background:none;border-style:solid;border-width:8px 14px;border-color:transparent;border-image:url(assets/ui/btn_dark.png) 40 60 fill / 8px 14px stretch;filter:drop-shadow(0 2px 3px #000a)}
.wkb small{display:block;font:600 9px/1.2 system-ui;color:#c9b48a}.wkb.hot{filter:drop-shadow(0 0 6px #ffcc66)}
#reset{position:fixed;right:6px;top:calc(env(safe-area-inset-top) + 98px);z-index:5;pointer-events:auto;font-size:11px;padding:3px 7px;border-radius:8px;border:1px solid #fff4;background:#0008;color:#ddd}
#pnl.act{min-height:0}#pnl.act .por{display:none}#pnl.act .card{padding:2px 6px}#pnl.act .big,#pnl.act .wkb{min-height:34px}#pnl.act .big{font-size:14px}
#pnl .av{width:24px;height:24px;border-radius:50%;overflow:hidden;flex:none;border:1.5px solid #b48a3c;background:#3a2414;position:relative}
#pnl .av img{position:absolute;left:50%;top:-2px;width:240%;transform:translateX(-50%)}
#pnl.mini{min-height:0;align-items:center;padding:2px 4px;gap:6px}#pnl.mini .av{width:34px;height:34px}
#pnl.mini .tx{flex:1;min-width:0;font:600 12px/1.35 ${SERIF};color:#f3e6c0;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
#pnl.mini .tx b{color:#ffe3a0}#pnl.mini .wkb{min-height:34px}
#modal{position:fixed;inset:0;z-index:8;display:none;align-items:center;justify-content:center;background:radial-gradient(#3a0a0a80,#200404d0)}
#modal .box{width:min(92vw,380px);padding:16px;color:#f3e6c0;font:14px/1.6 system-ui,"Noto Sans JP",sans-serif}
#modal h3{margin:0 0 8px;color:#ffd770;font:700 18px/1.3 ${SERIF}}#modal .btns{display:flex;gap:8px;margin-top:12px;flex-wrap:wrap}#modal .btns .big{font-size:15px;min-width:30%}
#modal .big small{display:block;font:600 10px/1.2 system-ui;color:#4a3010}#modal .big{flex-direction:column;gap:1px}
#modal .box.parch{background:radial-gradient(ellipse at 50% 40%,#f3e2b8,#e2c88e 70%,#c9a466);color:#3a2410;border:none;border-radius:6px;box-shadow:0 0 0 3px #7a5420,0 8px 30px #000;font-family:${SERIF}}
#modal .box.parch h3{color:#5a2a08;text-align:center;border-bottom:1px solid #8a6430;padding-bottom:4px}
#modal .box.parch ul{margin:4px 0 8px;padding-left:18px}#modal .box.parch .w li{color:#8a1a10}#modal .box.parch .lab{font-weight:700;margin-top:6px}
#toast{position:fixed;left:50%;top:calc(env(safe-area-inset-top) + 150px);transform:translateX(-50%);z-index:6;max-width:90vw;padding:7px 14px;border-radius:6px;background:#140d08e8;border:1px solid #b48a3c;color:#ffe9b8;font:700 13px/1.4 ${SERIF};opacity:0;transition:opacity .25s;pointer-events:none;text-align:center}
#toast.on{opacity:1}
`;
export function createUI({ onEndWeek, onReset }) {
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  const mk = (tag, id, cls) => { const e = document.createElement(tag); if (id) e.id = id; if (cls) e.className = cls; document.body.appendChild(e); return e; };
  const top = mk('div', 'top'), pnl = mk('div', 'pnl', 'fr'), modal = mk('div', 'modal'), toastEl = mk('div', 'toast');
  const rs = mk('button', 'reset'); rs.textContent = '最初から'; rs.addEventListener('click', e => { e.stopPropagation(); if (confirmReset()) onReset(); });
  let armed = 0; function confirmReset() { if (Date.now() - armed < 2500) return true; armed = Date.now(); rs.textContent = 'もう一度押す'; setTimeout(() => { rs.textContent = '最初から'; }, 2500); return false; }
  pnl.addEventListener('pointerdown', e => e.stopPropagation());
  let tt = 0, pick = 0, lastKey = '';
  const ui = {
    // d = {title, week, weeks, raidWeeks:[], bossWeek, band:{wk, next, foe}, res:[{ic,lab,val,sub,cls,bar,col}]}
    top(d) {
      const wk = Array.from({ length: d.weeks }, (_, i) => { const w = i + 1, c = w < d.week ? 'past' : w === d.week ? 'now' : d.raidWeeks.includes(w) ? 'raid' : ''; return w === d.bossWeek && w !== d.week ? `<i style="width:17px;height:17px;background-image:url(assets/ui/wk_boss.png)"></i>` : `<i class="${c}">${w}</i>`; }).join('');
      top.innerHTML = `<img class="bnr" src="assets/ui/banner.png" alt=""><div class="frs t1w"><div class="t1"><span class="ttl">${d.title}</span><div class="wk">${wk}</div></div></div>
        <div class="scroll"><span class="wkn">第${d.band.wk}週</span><span class="sep"></span><span>${d.band.next}</span><span class="foe"><img src="assets/ui/seal.png" alt="" style="height:17px">${d.band.foe}</span></div>
        <div class="res frs">${d.res.map(r => `<div title="${r.lab}">${ico(r.ic, 16)}<span style="min-width:0;flex:1"><b>${r.val}${r.sub ? `<span class="${r.cls || 'd'}"> ${r.sub}</span>` : ''}</b>${r.bar !== undefined ? `<div class="bar"><span style="width:${Math.max(0, Math.min(100, r.bar))}%;background:${r.col || '#7ac06a'}"></span></div>` : ''}</span></div>`).join('')}</div>`;
    },
    // p = {key, icon, title, por:{src,name}|null, bubble, items:[{label, act, sup, ap, eff, can, why, verb, fn}], week:{label, sub, hot, disabled}}
    // p.mode: 'mini'（何も選んでいない：1行だけ）／'act'（行動：立ち絵なし、小さな顔）／'talk'（会話・報告：立ち絵と吹き出し）
    panel(p) {
      if (p.key !== lastKey) { pick = 0; lastKey = p.key; }
      const items = p.items || []; if (pick >= items.length) pick = 0;
      const it = items[pick], mode = p.mode || 'talk';
      const wkBtn = `<button class="wkb ${p.week.hot ? 'hot' : ''}" data-wk ${p.week.disabled ? 'disabled' : ''}>${p.week.label} »<small>${p.week.sub || ''}</small></button>`;
      const av = p.por ? `<span class="av">${p.por.face ? `<img src="${p.por.face}" alt="" style="width:100%;left:0;top:0;transform:none">` : `<img src="${p.por.src}" alt="">`}</span>` : '';
      pnl.className = 'fr ' + mode;
      if (mode === 'mini') {
        pnl.innerHTML = `${av}<div class="tx">${p.por ? `<b>${p.por.name.replace(/（.*）/, '')}</b>：` : ''}${p.bubble || ''}</div>${wkBtn}`;
      } else {
        pnl.innerHTML = `<div class="por">${mode === 'talk' && p.por ? `<img src="${p.por.src}" alt=""><div class="nm">${p.por.name}</div>` : ''}</div>
        <div class="card"><div class="hd">${mode === 'act' ? av : ''}${ico(p.icon || 'build', 20)}<span>${p.title}</span></div>
        ${items.length > 1 ? `<div class="chips">${items.map((x, i) => `<button data-i="${i}" class="${i === pick ? 'on' : ''} ${x.can === false ? 'x' : ''}">${x.label}</button>`).join('')}</div>` : ''}
        ${it ? `<div class="act">${it.act ?? it.label}</div><div class="cost">${it.sup ? `<span class="${it.sup < 0 ? 'm' : 'p'}">${ico('sup', 14)} 物資${it.sup > 0 ? '+' : ''}${it.sup}</span>` : ''}${it.ap ? `<span>${ico('ap', 14)} 行動 ${it.ap}</span>` : ''}${it.eff ? `<span class="eff">${it.eff}</span>` : ''}</div>${it.can === false && it.why ? `<div class="why">${it.why}</div>` : ''}` : ''}
        ${p.bubble ? `<div class="bub">${p.bubble}</div>` : ''}
        <div class="btns" style="margin-top:${mode === 'act' ? '6px' : 'auto'}">${it && it.verb ? `<button class="big" data-go ${it.can === false ? 'disabled' : ''}>${ico(p.icon || 'build', 20)}${it.verb}</button>` : '<span style="flex:1"></span>'}${wkBtn}</div></div>`;
      }
      pnl.querySelectorAll('.chips button').forEach(b => b.addEventListener('click', e => { e.stopPropagation(); pick = +b.dataset.i; ui.panel(p); }));
      const go = pnl.querySelector('[data-go]'); if (go) go.addEventListener('click', e => { e.stopPropagation(); it.fn(); });
      pnl.querySelector('[data-wk]').addEventListener('click', e => { e.stopPropagation(); onEndWeek(); });
      document.documentElement.style.setProperty('--ph', pnl.offsetHeight + 'px');
    },
    modal(title, body, buttons, cls) { // buttons: [{label, sub, fn}]
      if (!title) { modal.style.display = 'none'; return; }
      modal.innerHTML = `<div class="box ${cls || 'fr'}"><h3>${title}</h3><div>${body}</div><div class="btns"></div></div>`;
      const bx = modal.querySelector('.btns');
      for (const b of buttons) { const e = document.createElement('button'); e.className = 'big'; e.innerHTML = b.label + (b.sub ? `<small>${b.sub}</small>` : ''); e.addEventListener('click', ev => { ev.stopPropagation(); b.fn(); }); bx.appendChild(e); }
      modal.style.display = 'flex'; modal.style.alignItems = /low/.test(cls || '') ? 'flex-end' : 'center'; modal.style.paddingBottom = /low/.test(cls || '') ? 'calc(env(safe-area-inset-bottom) + 70px)' : '';
    },
    toast(msg) { toastEl.textContent = msg; toastEl.classList.add('on'); clearTimeout(tt); tt = setTimeout(() => toastEl.classList.remove('on'), 2400); },
  };
  return ui;
}
