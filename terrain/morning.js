// 朝の報告：空の部屋に、歩いて入ってくるラナと、報告役（セラ／ミナ）。タップで「今朝の変化」へ、もう一度タップで領地へ。
// 基準は背景画像 941×1672。位置と大きさは、その画素で持つ（画面の高さに合わせて --u で拡縮）。
const REF_W = 941, REF_H = 1672;
const LANA = { dir: '../sprites/', frames: 24, fps: 12, w: 536, h: 388, ax: 336, ay: 379, scale: 1.28, footX: 350, footY: 1215, fromX: -200 }; // 背の高さはゲーム全体の表（ラナ205：ミナ・セラ210）に合わせる（2026-10-30。旧 1.13）;
const SPK = { sera: { ax: 174, w: 291, h: 640, scale: .75, footX: 630, footY: 1215, flip: true }, mina: { ax: 126, w: 280, h: 640, scale: .75, footX: 630, footY: 1215, flip: true } };
const SERIF = '"Hiragino Mincho ProN","Yu Mincho",serif';
const CSS = `
#morn{position:fixed;inset:0;z-index:12;background:#000;display:none;overflow:hidden;font-family:${SERIF};-webkit-tap-highlight-color:transparent;user-select:none}
#morn .st{position:absolute;top:0;bottom:0;left:50%;aspect-ratio:${REF_W}/${REF_H};transform:translateX(-50%);background:url(assets/report/room.jpg) center/100% 100% no-repeat}
#morn .a{position:absolute;pointer-events:none}
#morn .lana{image-rendering:auto;filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0006)}
#morn .spk{opacity:0;transition:opacity .6s,transform .6s;transform:translateX(calc(var(--u)*40));filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0006)}
#morn .spk.on{opacity:1;transform:none}
#morn .hud{position:absolute;left:0;right:0;top:0;height:calc(var(--u)*92);display:flex;align-items:center;gap:calc(var(--u)*18);padding:0 calc(var(--u)*22);background:linear-gradient(#3a2a1ef2,#2a1d14f2);border-bottom:calc(var(--u)*3) solid #c9a24a;color:#f6ead0;box-shadow:0 calc(var(--u)*4) calc(var(--u)*12) #0007}
#morn .hud .wk{font:700 calc(var(--u)*40)/1 ${SERIF};letter-spacing:.04em;margin-right:auto;text-shadow:0 2px 3px #000a}
#morn .hud .r{display:flex;align-items:center;gap:calc(var(--u)*6);font:700 calc(var(--u)*27)/1 ${SERIF};white-space:nowrap}
#morn .hud .r img{height:calc(var(--u)*36);width:auto}#morn .hud .r small{font-size:calc(var(--u)*24);color:#d8c8a0}
#morn .skip{position:absolute;right:calc(var(--u)*36);top:calc(var(--u)*118);font:700 calc(var(--u)*32)/1 ${SERIF};color:#fff;text-shadow:0 1px 3px #000;background:#0003;border:0;padding:calc(var(--u)*10) calc(var(--u)*18);border-radius:calc(var(--u)*30);z-index:3}
#morn .box{position:absolute;left:calc(var(--u)*30);right:calc(var(--u)*30);bottom:calc(var(--u)*34);border:calc(var(--u)*30) solid transparent;border-image:url(assets/ui/frame_l.png) 90 / calc(var(--u)*30) / 0 stretch;margin:calc(var(--u)*-18);isolation:isolate;container-type:inline-size}
#morn .box::before{content:"";position:absolute;inset:calc(var(--u)*-14);z-index:-1;background:linear-gradient(#1b2338f4,#0e1322f6);border-radius:calc(var(--u)*6);box-shadow:0 calc(var(--u)*6) calc(var(--u)*20) #0009}
#morn .box::after{content:"";position:absolute;inset:calc(var(--u)*-6);z-index:-1;border:calc(var(--u)*2) solid #c9a24a8c;border-radius:calc(var(--u)*4);pointer-events:none}
#morn .nm{padding:calc(var(--u)*12) calc(var(--u)*30) 0;color:#fff4dc;text-shadow:0 2px 3px #000}
#morn .nm small{display:block;font:700 calc(var(--u)*27)/1.3 ${SERIF};color:#d6a64a;letter-spacing:.12em}
#morn .nm small:empty{display:none}
#morn .nm b{display:block;font:700 calc(var(--u)*48)/1.25 ${SERIF};letter-spacing:.08em}
#morn .ln{display:block;height:calc(var(--u)*3);width:48%;margin:calc(var(--u)*12) 0 0 calc(var(--u)*26);background:linear-gradient(90deg,#c9a24a00,#c9a24a 12%,#c9a24a 55%,#c9a24a00)}
#morn .tx{padding:calc(var(--u)*18) calc(var(--u)*30) calc(var(--u)*16);font:600 calc(var(--u)*43)/1.55 ${SERIF};font-size:min(calc(var(--u)*43),calc((100cqi - var(--u)*60)/18.4));color:#f2e8d4;letter-spacing:.04em;white-space:pre-line}
#morn .nx{position:absolute;right:calc(var(--u)*30);bottom:calc(var(--u)*26);width:calc(var(--u)*16);height:calc(var(--u)*16);border:calc(var(--u)*3) solid #d6a64a;background:#d6a64a55;rotate:45deg;animation:mornnx 1.1s ease-in-out infinite}
@keyframes mornnx{50%{translate:0 calc(var(--u)*-8)}}
#morn .tx{min-height:6.2em}
#morn .chg{display:none}#morn.p2 .tx,#morn.p2 .nm,#morn.p2 .ln,#morn.p2 .nx{display:none}#morn.p2 .chg{display:block}
#morn .chg h4{margin:0;padding:calc(var(--u)*12) calc(var(--u)*30) 0;font:700 calc(var(--u)*48)/1.25 ${SERIF};color:#fff4dc;letter-spacing:.08em;text-shadow:0 2px 3px #000}#morn .chg h4::after{content:"";display:block;height:calc(var(--u)*3);width:48%;margin:calc(var(--u)*12) 0 0 calc(var(--u)*-4);background:linear-gradient(90deg,#c9a24a00,#c9a24a 12%,#c9a24a 55%,#c9a24a00)}
#morn .chg .row{display:flex;align-items:center;gap:calc(var(--u)*22);padding:calc(var(--u)*14) calc(var(--u)*26);border-bottom:calc(var(--u)*2) solid #c9a24a40;font:600 calc(var(--u)*43)/1.2 ${SERIF};color:#f2e8d4}
#morn .chg .row:first-of-type{margin-top:calc(var(--u)*12)}#morn .chg .row:last-of-type{border-bottom:0}
#morn .chg .row img{height:calc(var(--u)*56);width:auto;flex:none}
#morn .chg .row b{width:calc(var(--u)*130);font-weight:700}#morn .chg .row span{flex:1}
#morn .chg .row em{font-style:normal;font-weight:900;font-size:calc(var(--u)*50);min-width:calc(var(--u)*130);text-align:right}#morn .chg .up{color:#7fdc7f}#morn .chg .dn{color:#ff7d62}
#morn .chg .wn{padding:calc(var(--u)*8) calc(var(--u)*26) calc(var(--u)*4);font:600 calc(var(--u)*34)/1.5 ${SERIF};color:#ff9a82}
#morn .chg .go{text-align:right;padding:calc(var(--u)*6) calc(var(--u)*20) calc(var(--u)*8) 0;font:600 calc(var(--u)*34)/1 ${SERIF};color:#d6b878}`;
const ICON = { sup: 'ic_sup', mor: 'ic_mor', def: 'ic_def', trp: 'ic_trp', hp: 'ic_hp', build: 'ic_build', flag: 'ic_flag' };
const icon = n => ICON[n] ? `<img src="assets/ui/${ICON[n]}.png" alt="">` : '';
let frames = null;
function loadFrames() { if (frames) return frames; frames = []; for (let i = 0; i < LANA.frames; i++) { const im = new Image(); im.src = `${LANA.dir}walk_${String(i).padStart(2, '0')}.png`; frames.push(im); } frames.idle = new Image(); frames.idle.src = `${LANA.dir}idle_00.png`; return frames; }

export function createMorning() {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  const el = document.createElement('div'); el.id = 'morn'; document.body.appendChild(el);
  let timers = [], raf = 0, phase = 0, done = null, typing = null;
  const clear = () => { timers.forEach(clearTimeout); timers = []; cancelAnimationFrame(raf); clearTimeout(typing); typing = null; };
  const T = (f, ms) => timers.push(setTimeout(f, ms));
  const close = () => { clear(); el.style.display = 'none'; el.className = ''; el.innerHTML = ''; const f = done; done = null; f && f(); };

  function show(o) { // o: { week, res:{sup,morale,def}, who, name, lines[], rows[], warns[], onClose }
    clear(); done = o.onClose; phase = 0; const fr = loadFrames();
    el.className = ''; el.style.display = 'block';
    const sp = SPK[o.who] || SPK.mina;
    el.innerHTML = `<div class="st"><img class="a lana" alt=""><img class="a spk" src="../ally/${o.who}.png" alt=""></div>
      <div class="hud"><span class="wk">第${o.week}週・朝</span>
        <span class="r">${icon('sup')}物資 ${o.res.sup}</span><span class="r">${icon('mor')}民心 ${o.res.morale}</span><span class="r">${icon('def')}防衛 ${o.res.def}</span></div>
      <button class="skip">スキップ ▶</button>
      <div class="box"><div class="nm"><b>${o.name}</b></div><i class="ln"></i><div class="tx"></div><span class="nx"></span>
        <div class="chg"><h4>今朝の変化</h4>${o.rows.map(r => `<div class="row">${icon(r.ic)}<b>${r.label}</b>${r.text !== undefined ? `<span>${r.text}</span>` : `<span>${r.from} → ${r.to}</span><em class="${r.d > 0 ? 'up' : r.d < 0 ? 'dn' : ''}">${r.d > 0 ? '+' : ''}${r.d}</em>`}</div>`).join('')}
          ${o.warns && o.warns.length ? `<div class="wn">${o.warns.map(w => '・' + w).join('<br>')}</div>` : ''}<div class="go">タップで領地へ ›</div></div></div>`;
    const stage = el.querySelector('.st'), lana = el.querySelector('.lana'), spk = el.querySelector('.spk'), tx = el.querySelector('.tx'), nx = el.querySelector('.nx');
    const fit = () => { const h = stage.clientHeight, u = h / REF_H; el.style.setProperty('--u', u + 'px'); };
    fit(); const onR = () => fit(); window.addEventListener('resize', onR); const prevDone = done; done = () => { window.removeEventListener('resize', onR); prevDone && prevDone(); };
    // 立ち位置（基準画素。足元の中心を合わせる）
    const u = () => stage.clientHeight / REF_H;
    const place = (img, a, footX, footY, s) => { const k = u() * s; img.style.width = a.w * k + 'px'; img.style.height = a.h * k + 'px'; img.style.left = (footX - a.ax * s) * u() + 'px'; img.style.top = (footY - a.ay * s) * u() + 'px'; };
    place(spk, { w: sp.w, h: sp.h, ax: sp.ax, ay: sp.h - 1 }, sp.footX, sp.footY, sp.scale);
    if (sp.flip) { spk.style.scale = '-1 1'; spk.style.transformOrigin = sp.ax * sp.scale * u() + 'px 100%'; } // ラナの方を向かせる
    const lanaAt = x => place(lana, LANA, x, LANA.footY, LANA.scale);
    // ラナ：左から歩いて入り、立ち止まる
    const t0 = performance.now(), WALK_MS = 1700; let arrived = false;
    const tick = now => { const t = Math.min(1, (now - t0) / WALK_MS), e = 1 - (1 - t) * (1 - t), x = LANA.fromX + (LANA.footX - LANA.fromX) * e;
      if (t < 1) { lana.src = fr[Math.max(0, Math.floor((now - t0) / 1000 * LANA.fps)) % LANA.frames].src; lanaAt(x); raf = requestAnimationFrame(tick); }
      else { lana.src = fr.idle.src; lanaAt(LANA.footX); arrived = true; } };
    lana.src = fr[0].src; lanaAt(LANA.fromX); raf = requestAnimationFrame(tick);
    T(() => spk.classList.add('on'), 700);
    // せりふ：1文ずつ、文字を送る
    const full = o.lines.join('<br>'); let shown = false;
    const typeAll = () => { const L = o.lines; let li = 0, ci = 0; tx.innerHTML = ''; nx.style.visibility = 'hidden';
      const step = () => { if (li >= L.length) { typing = null; nx.style.visibility = 'visible'; return; } ci++; tx.innerHTML = L.slice(0, li).join('<br>') + (li ? '<br>' : '') + L[li].slice(0, ci);
        if (ci >= L[li].length) { li++; ci = 0; typing = setTimeout(step, 260); } else typing = setTimeout(step, 34); };
      typing = setTimeout(step, 0); };
    T(() => { shown = true; typeAll(); }, 900);
    const finishTyping = () => { clearTimeout(typing); typing = null; tx.innerHTML = full; nx.style.visibility = 'visible'; };
    el.querySelector('.skip').onclick = e => { e.stopPropagation(); close(); };
    el.onclick = () => {
      if (phase === 0) { if (!shown) { shown = true; finishTyping(); return; } if (typing) { finishTyping(); return; } phase = 1; el.classList.add('p2'); return; }
      close(); };
  }
  return { show, close };
}
