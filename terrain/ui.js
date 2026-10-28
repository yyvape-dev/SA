// 画面のUI（DOM）：上のHUD、下の行動ボタン、週を終えるボタン、襲撃などの窓、短い通知。ルールは持たない。
const css = `
#hud2{position:fixed;left:0;right:0;top:0;z-index:4;padding:calc(env(safe-area-inset-top) + 6px) 8px 6px;background:linear-gradient(#0c0f14e6,#0c0f1480 80%,#0000);color:#f3e6c0;font:600 13px/1.35 system-ui,"Noto Sans JP",sans-serif;text-shadow:0 1px 2px #000;pointer-events:none}
#hud2 .row{display:flex;flex-wrap:wrap;gap:4px 10px;align-items:center}
#hud2 .k{color:#ffd770}#hud2 .d{color:#9fd08a;font-size:11px}#hud2 .n{color:#ff9a8a;font-size:11px}
#hud2 .raid{margin-top:3px;font-size:12px;color:#ffc2b0}#hud2 .sel{margin-top:2px;font-size:12px;color:#e8dcc0}
#hud2 .ap{letter-spacing:1px;color:#ffd770}
#acts{position:fixed;left:0;right:0;bottom:calc(env(safe-area-inset-bottom) + 70px);z-index:4;display:flex;gap:6px;justify-content:center;flex-wrap:wrap;padding:0 8px;pointer-events:none}
.b2{pointer-events:auto;min-height:46px;padding:4px 12px;font:700 14px/1.2 system-ui,"Noto Sans JP",sans-serif;color:#2a1a08;background:linear-gradient(#f0d58a,#c9a24a);border:2px solid #5a3d12;border-radius:10px;box-shadow:0 2px 6px #000a}
.b2 small{display:block;font-size:11px;font-weight:600;color:#5a3d12}
.b2:disabled{filter:grayscale(.8) brightness(.7)}
#endw{position:fixed;right:10px;bottom:calc(env(safe-area-inset-bottom) + 14px);z-index:4}
#reset{position:fixed;left:8px;bottom:calc(env(safe-area-inset-bottom) + 26px);z-index:5;pointer-events:auto;font-size:12px;padding:4px 8px;border-radius:8px;border:1px solid #fff4;background:#0008;color:#ddd}
#modal{position:fixed;inset:0;z-index:8;display:none;align-items:center;justify-content:center;background:radial-gradient(#3a0a0a80,#200404d0)}
#modal .box{width:min(92vw,380px);background:#1b140e;border:2px solid #b48a3c;border-radius:14px;padding:16px;color:#f3e6c0;font:14px/1.6 system-ui,"Noto Sans JP",sans-serif;box-shadow:0 6px 30px #000}
#modal h3{margin:0 0 8px;color:#ffd770;font-size:17px}#modal .btns{display:flex;gap:8px;margin-top:12px}#modal .btns .b2{flex:1}
#toast{position:fixed;left:50%;top:calc(env(safe-area-inset-top) + 92px);transform:translateX(-50%);z-index:6;max-width:90vw;padding:8px 14px;border-radius:10px;background:#000c;color:#fff;font:600 13px/1.4 system-ui,"Noto Sans JP",sans-serif;opacity:0;transition:opacity .25s;pointer-events:none;text-align:center}
#toast.on{opacity:1}
`;
export function createUI({ onEndWeek, onReset }) {
  const st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  const mk = (tag, id, html) => { const e = document.createElement(tag); if (id) e.id = id; if (html) e.innerHTML = html; document.body.appendChild(e); return e; };
  const hud = mk('div', 'hud2'), acts = mk('div', 'acts'), modal = mk('div', 'modal'), toastEl = mk('div', 'toast');
  const endw = mk('button', 'endw'); endw.className = 'b2'; endw.addEventListener('click', e => { e.stopPropagation(); onEndWeek(); });
  const rs = mk('button', 'reset'); rs.textContent = '最初から'; rs.addEventListener('click', e => { e.stopPropagation(); if (confirmReset()) onReset(); });
  let armed = 0; function confirmReset() { if (Date.now() - armed < 2500) return true; armed = Date.now(); rs.textContent = 'もう一度押す'; setTimeout(() => { rs.textContent = '最初から'; }, 2500); return false; }
  let tt = 0;
  return {
    hud(html) { hud.innerHTML = html; },
    endWeek(label, hot, disabled) { endw.innerHTML = label; endw.disabled = !!disabled; endw.style.boxShadow = hot ? '0 0 0 3px #ffd770,0 2px 8px #000' : ''; },
    actions(list) { // list: [{label, sub, can, fn}]
      acts.replaceChildren();
      for (const a of list) { const b = document.createElement('button'); b.className = 'b2'; b.innerHTML = a.label + (a.sub ? `<small>${a.sub}</small>` : ''); b.disabled = a.can === false; b.addEventListener('click', e => { e.stopPropagation(); a.fn(); }); acts.appendChild(b); }
    },
    modal(title, body, buttons) { // buttons: [{label, sub, fn}]
      if (!title) { modal.style.display = 'none'; return; }
      modal.innerHTML = `<div class="box"><h3>${title}</h3><div>${body}</div><div class="btns"></div></div>`;
      const bx = modal.querySelector('.btns');
      for (const b of buttons) { const e = document.createElement('button'); e.className = 'b2'; e.innerHTML = b.label + (b.sub ? `<small>${b.sub}</small>` : ''); e.addEventListener('click', ev => { ev.stopPropagation(); b.fn(); }); bx.appendChild(e); }
      modal.style.display = 'flex';
    },
    toast(msg) { toastEl.textContent = msg; toastEl.classList.add('on'); clearTimeout(tt); tt = setTimeout(() => toastEl.classList.remove('on'), 2200); },
  };
}
