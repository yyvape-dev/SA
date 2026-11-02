// 章の始まりと終わりの会話（2026-10-30）。立ち絵＋名前＋文字送り。タップで次へ。章の始まりは題字の札から。
// 話者：仲間のキー、'rana'、'foe'（章の将軍）。2026-10-31 朝の会話と同じ舞台式に作り直し：章ごとの背景（assets/story/bg_N.webp）に、
// 左にラナ（アクションの歩き→待機）、右に相手（仲間＝全身の立ち姿 ../ally/<k>.png、敵将＝全身 assets/npc/gen_<k>.webp）。話していない方は暗くする。
const SERIF = "'DMincho','Hiragino Mincho ProN','Yu Mincho',serif";
const NAME = { mina: 'ミナ', garou: 'ガロウ', sera: 'セラ', ranka: 'ランカ', lily: 'リリィ', rana: 'ラナ' };
// 敵将の名前を肩書きと名前に分ける（「女騎士エルザ」→「女騎士」「エルザ」。カタカナの名前が無ければ全体を名前に）
const splitTitle = n => { const m = /^(.+?)([ァ-ヶー]+)$/.exec(n || ''); return m ? [m[1], m[2]] : ['', n || '']; };
const NUM = ['', '一', '二', '三', '四', '五', '六'];
const GEN_NAME = { g1: '山賊頭グレン', g2: '傭兵団長ボルグ', g3: '女騎士エルザ', g4: '黒騎士', g5: '総大将ヘルマン', g6: '大公ヴァルド', g6b: '大公ヴァルド' }; // 台詞の話し手に 'g2' などと書くと、その将軍として出す。'@村の老人' は絵なしの話し手
export { SCENES } from './scenario.js?v=story2';
import { SCENES, LOSE, LOSE_C } from './scenario.js?v=story2';
import { pages } from './narrative.js?v=story2';
const REF_W = 941, REF_H = 1672, FOOT = 1215;
const LANA = { dir: '../sprites/', frames: 24, fps: 12, w: 536, h: 388, ax: 336, ay: 379, scale: 1.28, x: 300, from: -220 }; // morning.js と同じ大きさ
const ALLY_S = .75, OTHER_X = 650;           // 仲間の全身（高さ640）の縮尺は朝の会話と同じ
const GEN_BODY = { g1: 540, g2: 520, g3: 490, g4: 560, g5: 510, g6: 500, g6b: 520 }; // 敵将の体の高さ（基準画素。仲間＝480）
const GEN_DX = { g1: -50 }; // 立ち位置の調整（武器が画面の外に出る人だけ）
// 2026-11-01 大きさの調整（会話の舞台だけ）。1＝今のまま。?grid=1 のガイド線に「頭の高さ（足元からの基準画素）」と倍率が出るので、それを見て直す
export const SIZE = { rana: 1, mina: 1.03, garou: 1.18, sera: 1.04, ranka: 1.05, lily: 1, g1: 1.05, g2: 1.07, g3: 1.01, g4: 1.06, g5: 1.12, g6: 1.2, g6b: 1.18 };
const GRID = () => { try { return new URLSearchParams(location.search).has('grid'); } catch (e) { return false; } };
const headCache = new Map();
function headTop(img) { // 絵の一番上の不透明な画素（元の絵の画素）
  const src = img.currentSrc || img.src; if (headCache.has(src)) return headCache.get(src); if (!img.naturalWidth) return null;
  const c = document.createElement('canvas'), w = c.width = Math.min(200, img.naturalWidth), h = c.height = Math.round(img.naturalHeight * w / img.naturalWidth), g = c.getContext('2d'); g.drawImage(img, 0, 0, w, h);
  let top = null; try { const d = g.getImageData(0, 0, w, h).data; for (let y = 0; y < h && top == null; y++) for (let x = 0; x < w; x++) if (d[(y * w + x) * 4 + 3] > 60) { top = y * img.naturalHeight / h; break; } } catch (e) { top = null; }
  headCache.set(src, top); return top; }
let genMeta = null; const genMetaP = fetch('assets/npc/gen_meta.json?v=1').then(r => r.json()).then(m => (genMeta = m)).catch(() => (genMeta = {}));
const CSS = `
#story{position:fixed;inset:0;z-index:13;display:none;background:#0b0806;font-family:${SERIF};color:#f6ead0;-webkit-tap-highlight-color:transparent;user-select:none;overflow:hidden}
#story .st{position:absolute;top:0;bottom:0;left:50%;aspect-ratio:${REF_W}/${REF_H};transform:translateX(-50%);background:#000 center/100% 100% no-repeat}
#story .a{position:absolute;pointer-events:none;filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0007);transition:filter .3s}
#story .a.dim{filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0007) brightness(.5)}
#story .st.night .a{z-index:1}#story .st.night::after{content:'';position:absolute;inset:0;z-index:0;background:linear-gradient(#050a1ee6,#0a1430b3 60%,#0a1430cc);pointer-events:none} /* 序章：逃亡の夜 */
#story .oth{opacity:0;transition:opacity .45s,transform .45s,filter .3s;transform:translateX(calc(var(--u)*50))}
#story .oth.on{opacity:1;transform:none}#story .ral{z-index:2}
#story .card{position:absolute;inset:0;z-index:5;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:calc(var(--u)*36);background:#000a;opacity:0;transition:opacity .7s}
#story .card.on{opacity:1}
#story .card small{font-size:calc(var(--u)*40);letter-spacing:.5em;color:#c9a24a}
#story .card h2{margin:0;font-size:calc(var(--u)*86);font-weight:700;letter-spacing:.2em;text-shadow:0 3px 8px #000}
#story .card p{margin:0 8%;font-size:calc(var(--u)*38);line-height:1.7;text-align:center;color:#e8dcc0}
#story .card i{display:block;width:70%;height:2px;background:linear-gradient(90deg,#c9a24a00,#c9a24a,#c9a24a00)}
#story .box{position:absolute;left:calc(var(--u)*34);right:calc(var(--u)*34);bottom:calc(var(--u)*40);padding:calc(var(--u)*14) calc(var(--u)*8) calc(var(--u)*10);background:#efe3c8 url(assets/ui2/parch.jpg) 0 0/calc(var(--u)*900) auto repeat;border:calc(var(--u)*3) solid #a8833c;border-radius:calc(var(--u)*10);box-shadow:0 0 0 calc(var(--u)*2) #f3ead6 inset,0 calc(var(--u)*8) calc(var(--u)*24) #0009;container-type:inline-size;display:none}
#story .box::after{content:'';position:absolute;left:calc(var(--u)*10);right:calc(var(--u)*10);bottom:calc(var(--u)*-26);height:calc(var(--u)*52);background:url(assets/ui2/vine.webp) center/100% 100% no-repeat;pointer-events:none;opacity:.95}
#story .box .c1,#story .box .c2{position:absolute;top:calc(var(--u)*-10);width:calc(var(--u)*96);aspect-ratio:220/153;background:url(assets/ui2/corner.webp) center/contain no-repeat;pointer-events:none}
#story .box .c1{left:calc(var(--u)*-10)}#story .box .c2{right:calc(var(--u)*-10);transform:scaleX(-1)}
#story .nm{padding:calc(var(--u)*8) calc(var(--u)*40) 0;color:#2b1d10}
#story .nm small{display:block;font:700 calc(var(--u)*26)/1.3 ${SERIF};color:#7a5a2a;letter-spacing:.12em}
#story .nm small:empty{display:none}
#story .nm b{display:block;font:700 calc(var(--u)*46)/1.25 ${SERIF};letter-spacing:.08em}
#story .ln{display:block;height:calc(var(--u)*20);width:56%;margin:calc(var(--u)*4) 0 0 calc(var(--u)*28);background:url(assets/ui2/divider2.webp) left center/contain no-repeat}
#story .tx{padding:calc(var(--u)*18) calc(var(--u)*30) calc(var(--u)*16);font:600 calc(var(--u)*43)/1.55 ${SERIF};font-size:min(calc(var(--u)*43),calc((100cqi - var(--u)*60)/18.4));color:#2b1d10;letter-spacing:.04em;white-space:pre-line}
#story .nx{position:absolute;right:calc(var(--u)*30);bottom:calc(var(--u)*26);width:calc(var(--u)*16);height:calc(var(--u)*16);border:calc(var(--u)*3) solid #a8833c;background:#a8833c88;rotate:45deg;animation:storynx 1.1s ease-in-out infinite}
@keyframes storynx{50%{translate:0 calc(var(--u)*-8)}}
#story .box.on{display:block}
#story .chs{position:absolute;z-index:7;left:6%;right:6%;bottom:calc(var(--u)*330);display:flex;flex-direction:column;gap:calc(var(--u)*18)}
#story .chs button{font:700 calc(var(--u)*36)/1.4 ${SERIF};color:#2b1d10;background:#f3ead6 url(assets/ui2/parch.jpg) 0 0/calc(var(--u)*900) auto;border:calc(var(--u)*3) solid #a8833c;border-radius:calc(var(--u)*14);padding:calc(var(--u)*20) calc(var(--u)*28);text-align:left;box-shadow:0 calc(var(--u)*6) calc(var(--u)*18) #0008}
#story .tx{height:3.1em;box-sizing:content-box}
#story .sl,#story .sr{opacity:0;transition:opacity .4s,filter .3s}#story .sl.on,#story .sr.on{opacity:1}
#story .gd{position:absolute;inset:0;z-index:4;pointer-events:none}#story .gl{position:absolute;left:0;right:0;border-top:1px solid #0ff9}#story .gl.s{border-top-style:dashed;border-color:#0ff5}#story .gl b{position:absolute;left:4px;top:-1.1em;font:700 12px/1 monospace;color:#0ff;text-shadow:0 0 2px #000}
#story .gh{position:absolute;border-top:2px solid #f0f}#story .gh b{position:absolute;left:0;top:-1.3em;font:700 12px/1 monospace;color:#fff;background:#a0a9;padding:1px 3px;white-space:nowrap}
#story .skip{position:absolute;z-index:6;right:calc(var(--u)*36);top:calc(var(--u)*40);font:700 calc(var(--u)*32)/1 ${SERIF};color:#fff;text-shadow:0 1px 3px #000;background:#0005;border:0;padding:calc(var(--u)*10) calc(var(--u)*18);border-radius:calc(var(--u)*30)}`;
let frames = null;
function loadFrames() { if (frames) return frames; frames = []; for (let i = 0; i < LANA.frames; i++) { const im = new Image(); im.src = `${LANA.dir}walk_${String(i).padStart(2, '0')}.png`; frames.push(im); } frames.idle = new Image(); frames.idle.src = `${LANA.dir}idle_00.png`; return frames; }

export function createStory() {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  const el = document.createElement('div'); el.id = 'story'; document.body.appendChild(el);
  let done = null, typing = 0, raf = 0, onR = null;
  const jobs = new Set();
  const later = (fn, ms) => { const id = setTimeout(() => { jobs.delete(id); fn(); }, ms); jobs.add(id); return id; };
  const close = () => { jobs.forEach(clearTimeout); jobs.clear(); clearTimeout(typing); cancelAnimationFrame(raf); if (onR) window.removeEventListener('resize', onR); el.style.display = 'none'; el.innerHTML = ''; el.onclick = null; const f = done; done = null; f && f(); };
  // o = { c, kind: 'start'|'win'|'lose', title, desc, foeName, foeKey:'g1'…'g6b' }
  async function play(o, onDone) {
    // 2026-11-01 作り直し：舞台に2つの立ち位置（左・右）。話し手と、いま話している相手が向かい合う（ラナを左に固定しない）。
    // 台詞は2行ずつのページに分けて送る（JRPG風）。窓は一騎打ちと同じ絵本の紙。?grid=1 で大きさのガイド線（基準画素）
    const pageify = pages;
    const lines = pageify(o.lines || (o.kind === 'lose' ? (LOSE_C[o.c] || LOSE) : ((SCENES[o.c] || {})[o.kind] || []))); let picked = false; // o.lines＝任意の台詞、o.choices＝最後に選択肢（{t, reply}）、o.onPick(i)
    if (!lines.length && o.kind !== 'start') { onDone && onDone(); return; }
    await genMetaP; done = onDone; el.style.display = 'block'; const fr = loadFrames(), grid = GRID();
    el.innerHTML = `<div class="st${o.kind === 'pro' ? ' night' : ''}" style="background-image:url(assets/story/bg_${o.c}.webp?v=1)"><img class="a sl" alt=""><img class="a sr" alt="">${grid ? '<div class="gd"></div>' : ''}</div>${o.kind === 'start' ? `<div class="card"><small>第${NUM[o.c] || o.c}章</small><h2>${o.title}</h2><i></i><p>${o.desc}</p></div>` : ''}<div class="box"><i class="c1"></i><i class="c2"></i><div class="nm"><small></small><b></b></div><i class="ln"></i><div class="tx"></div><span class="nx"></span></div><button class="skip">スキップ ▶</button>`;
    const stage = el.querySelector('.st'), card = el.querySelector('.card'), box = el.querySelector('.box'), nm = el.querySelector('.nm'), tx = el.querySelector('.tx'), gd = el.querySelector('.gd');
    const U = () => stage.clientHeight / REF_H;
    const fk = k => k === 'foe' ? o.foeKey : k, isGen = k => k === 'foe' || !!GEN_NAME[k];
    // 立ち位置：side 0＝左（右を向く）、1＝右（左を向く）。元の絵の向き：ラナ・仲間＝右向き、将軍＝左向き
    const slots = [{ img: el.querySelector('.sl'), k: null, t: -1 }, { img: el.querySelector('.sr'), k: null, t: -1 }];
    const SX = [LANA.x, OTHER_X];
    const metaOf = (k, img) => { if (k === 'rana') return { w: LANA.w, h: LANA.h, ax: LANA.ax, ay: LANA.ay, s: LANA.scale * (SIZE.rana || 1), right: true };
      if (isGen(k)) { const K = fk(k), m = genMeta[K]; if (!m) return null; return { w: m.w, h: m.h, ax: m.ax, ay: m.ay, s: (GEN_BODY[K] || 520) / m.body * (SIZE[K] || 1), right: false, dx: (GEN_DX[K] || 0) + 40 }; }
      const w = img.naturalWidth || 300, h = img.naturalHeight || 640; return { w, h, ax: w / 2, ay: h - 1, s: ALLY_S * (SIZE[k] || 1), right: true }; };
    const placeSlot = (sl, side, xo = 0) => { const k = sl.k; if (!k) return; const m = metaOf(k, sl.img); if (!m) return; const u = U(), img = sl.img, x = SX[side] + (side ? 1 : -1) * (m.dx || 0) + xo;
      img.style.width = m.w * m.s * u + 'px'; img.style.height = m.h * m.s * u + 'px'; img.style.left = (x - m.ax * m.s) * u + 'px'; img.style.top = (FOOT - m.ay * m.s) * u + 'px';
      img.style.transformOrigin = `${m.ax * m.s * u}px ${m.ay * m.s * u}px`; const flip = side === 0 ? !m.right : m.right; img.style.scale = flip ? '-1 1' : ''; sl.m = m; sl.x = x; };
    const srcOf = k => k === 'rana' ? fr.idle.src : isGen(k) ? `assets/npc/gen_${fk(k)}.webp?v=1` : `../ally/${k}.png`;
    const enter = (side, k) => { const sl = slots[side]; sl.k = k; sl.img.classList.remove('on'); const img = sl.img;
      later(() => { img.onload = () => { placeSlot(sl, side); drawGrid(); requestAnimationFrame(() => img.classList.add('on')); }; img.src = srcOf(k); if (img.complete && img.naturalWidth) img.onload(); }, sl.t >= 0 ? 160 : 0); };
    let clock = 0, prev = null;
    const stageFor = k => { // 話し手を舞台に出す。いなければ、直前の話し手（＝聞き手）ではない方と入れ替える
      if (k[0] === '@') return -1; const on = slots.findIndex(s => s.k === k); if (on >= 0) return on;
      let side = slots.findIndex(s => !s.k); if (side < 0) { const keep = slots.findIndex(s => s.k === prev); side = keep >= 0 ? 1 - keep : (slots[0].t < slots[1].t ? 0 : 1); }
      enter(side, k); return side; };
    // 最初の二人：ラナは左、将軍は右を優先
    { const first = [...new Set(lines.map(l => l[0]).filter(k => k[0] !== '@'))].slice(0, 2); const L = first.includes('rana') ? 'rana' : first.find(k => !isGen(k)) || first[1], R = first.find(k => k !== L);
      if (L) enter(0, L); if (R) enter(1, R); }
    // ラナが最初に左へ出るときは、歩いて入る
    if (slots[0].k === 'rana') { const sl = slots[0], img = sl.img, t0 = performance.now() + (card ? 400 : 0), WALK = 1500; img.classList.add('on');
      const tick = now => { if (sl.k !== 'rana') return; const t = Math.max(0, Math.min(1, (now - t0) / WALK)), e = 1 - (1 - t) * (1 - t); placeSlot(sl, 0, (LANA.from - LANA.x) * (1 - e));
        if (t < 1) { img.src = fr[Math.floor(Math.max(0, now - t0) / 1000 * LANA.fps) % LANA.frames].src; raf = requestAnimationFrame(tick); } else { img.src = fr.idle.src; placeSlot(sl, 0); drawGrid(); } };
      raf = requestAnimationFrame(tick); }
    function drawGrid() { if (!gd) return; const u = U(); let h = ''; for (let y = 0; y <= 800; y += 50) { const top = (FOOT - y) * u; h += `<div class="gl${y % 100 ? ' s' : ''}" style="top:${top}px"><b>${y}</b></div>`; }
      slots.forEach((sl, side) => { if (!sl.k || !sl.m) return; const hd = headTop(sl.img); if (hd == null) return; const yh = Math.round((sl.m.ay - hd) * sl.m.s); h += `<div class="gh" style="top:${(FOOT - yh) * u}px;left:${(sl.x - 130) * u}px;width:${260 * u}px"><b>${NAME[sl.k] || GEN_NAME[fk(sl.k)] || sl.k}（${sl.k === 'foe' ? fk(sl.k) : sl.k}）頭 ${yh}・×${(SIZE[sl.k === 'foe' ? fk(sl.k) : sl.k] || 1).toFixed(2)}</b></div>`; });
      gd.innerHTML = h; }
    onR = () => { el.style.setProperty('--u', U() + 'px'); slots.forEach((sl, side) => placeSlot(sl, side)); drawGrid(); }; el.style.setProperty('--u', U() + 'px'); window.addEventListener('resize', onR);
    el.querySelector('.skip').onclick = e => {
      e.stopPropagation();
      if (o.choices?.length && !picked) {
        if (step === 'choice') return;
        jobs.forEach(clearTimeout); jobs.clear(); clearTimeout(typing); typing = 0;
        i = lines.length - 1; if (card) card.classList.remove('on'); box.classList.add('on');
        tx.textContent = '選択してください。'; choose();
      } else close();
    };
    let i = -1, full = '', step = card ? 'card' : 'line';
    if (card) requestAnimationFrame(() => card.classList.add('on'));
    const show = () => {
      i++; if (i >= lines.length) { if (o.choices && !picked) { choose(); return; } close(); return; }
      const [k, t] = lines[i], foe = isGen(k), side = stageFor(k); clock++;
      if (side >= 0) { slots[side].t = clock; if (k !== prev) prev = k; }
      slots.forEach((sl, j) => sl.img.classList.toggle('dim', side >= 0 ? j !== side : false));
      { const [ti, na] = foe ? splitTitle(k === 'foe' ? o.foeName : GEN_NAME[k]) : k[0] === '@' ? ['', k.slice(1)] : ['', NAME[k] || k]; nm.firstChild.textContent = ti; nm.lastChild.textContent = na; } box.classList.add('on');
      full = t; let n = 0; tx.textContent = ''; clearTimeout(typing);
      const ty = () => { n++; tx.textContent = full.slice(0, n); if (n < full.length) typing = later(ty, 32); else typing = 0; }; ty();
    };
    const choose = () => { step = 'choice'; const ch = document.createElement('div'); ch.className = 'chs'; // 選択肢：押すと、その返しの台詞へ続く
      ch.innerHTML = o.choices.map((c, j) => `<button data-j="${j}">${c.t}</button>`).join(''); el.appendChild(ch);
      ch.querySelectorAll('button').forEach(b => b.onclick = e => { e.stopPropagation(); const j = +b.dataset.j; picked = true; ch.remove(); step = 'line'; o.onPick && o.onPick(j); lines.push(...pageify(o.choices[j].reply || [])); show(); }); };
    el.onclick = () => {
      if (step === 'choice') return;
      if (step === 'card') { step = 'line'; card.classList.remove('on'); if (!lines.length) { later(close, 300); return; } later(show, 350); return; }
      if (typing) { clearTimeout(typing); typing = 0; tx.textContent = full; return; }
      show();
    };
    if (!card) later(show, 500);
  }
  return { play, close };
}
export { LANA, ALLY_S, GEN_BODY, FOOT, REF_H, GEN_NAME, NAME }; // 2026-11-01 lineup.html（大きさを比べる資料のページ）用

