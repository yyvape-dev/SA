// 章の始まりと終わりの会話（2026-10-30）。立ち絵＋名前＋文字送り。タップで次へ。章の始まりは題字の札から。
// 話者：仲間のキー、'rana'、'foe'（章の将軍）。2026-10-31 朝の会話と同じ舞台式に作り直し：章ごとの背景（assets/story/bg_N.webp）に、
// 左にラナ（アクションの歩き→待機）、右に相手（仲間＝全身の立ち姿 ../ally/<k>.png、敵将＝全身 assets/npc/gen_<k>.webp）。話していない方は暗くする。
const SERIF = "'DMincho','Hiragino Mincho ProN','Yu Mincho',serif";
const NAME = { mina: 'ミナ', garou: 'ガロウ', sera: 'セラ', ranka: 'ランカ', lily: 'リリィ', rana: 'ラナ' };
// 敵将の名前を肩書きと名前に分ける（「女騎士エルザ」→「女騎士」「エルザ」。カタカナの名前が無ければ全体を名前に）
const splitTitle = n => { const m = /^(.+?)([ァ-ヶー]+)$/.exec(n || ''); return m ? [m[1], m[2]] : ['', n || '']; };
const NUM = ['', '一', '二', '三', '四', '五', '六'];
export const SCENES = {
  1: { start: [['mina', '姫、ここなら追っ手も来ない。\n……しばらくは、ね。'], ['rana', 'ありがとう、ミナ。\nここから始めましょう。\n国を取り戻すために。'], ['mina', '民はまだ、姫を怖がってる。\n処刑されるはずだった女王だもん。\n……でも、わたしは知ってるから。']],
    win: [['foe', 'ちっ……\nただの小娘じゃなかったか。'], ['mina', 'どこまでも付いてくよ。\n……べ、別に当然でしょ。'], ['rana', '民が、少しだけ笑ってくれた。']] },
  2: { start: [['garou', 'ガハハ！\n姫、東の地は俺に任せてくだせえ。'], ['garou', '……ただ、向こうの傭兵団に、\n見覚えのある旗がありやしてね。'], ['rana', 'ガロウ？'], ['garou', 'なに、昔の話でさぁ。']],
    win: [['foe', '金で振る斧の方が、\nよっぽど楽だったろうに。'], ['garou', '金で振る斧と、\n主のために振る斧の違い……\n見せてやりましたぜ。'], ['garou', '団長、行きな。\nもう二度と、\n姫の前に立つんじゃねえ。']] },
  3: { start: [['sera', 'あの、姫さま……\n本日より内政を預かります、\nセラです。帳簿は、得意です。'], ['sera', '……向こうの陣に、\n懐かしい紋章が見えました。\n気のせいだと、いいのですが。']],
    win: [['foe', '強くなったわね、ラナ。\n……一つだけ教えてあげる。\n大公の軍は、得体の知れないものと\n取引しているわ。'], ['sera', '姉さま……。'], ['sera', '姫さま。\nわたしは、ここに残ります。\nこの国の帳簿は、\nわたしがつけます。']] },
  4: { start: [['ranka', 'あれ、困ってる？\n釣りの途中だったんだけどさ……\nお嬢、手、貸そっか？'], ['rana', 'あなたは……？'], ['ranka', 'ランカ。通りすがりの、\nちょっと強い人だよ。']],
    win: [['foe', '……グ……ァ……'], ['ranka', '……やっぱり。\nこいつ、中身は悪魔だよ。'], ['ranka', '……お嬢。\nここから先は、\nちょっとだけ真面目にやるよ。']] },
  5: { start: [['lily', 'ランカ！\nやっと見つけた……！'], ['ranka', 'げ、リリィ。'], ['lily', '「げ」じゃないでしょ！\n……ラナさん、話は聞きました。\nわたしも戦います。']],
    win: [['foe', '……強くなったな、姫。\n大公は悪魔と契約した。\n王都の地下に、封印がある。'], ['foe', 'この剣を持っていけ。\nわしには、もう振る資格がない。'], ['lily', 'ランカ、一人で行く気でしょ。\n……ちょっと！ 何してるの！\n一人で行かせるわけないでしょ。']] },
  6: { start: [['rana', '王都が見える。\n……帰ってきたわ。'], ['mina', '国なんて取り戻せなくても、\n姫と二人で生きていければよかった。\n……でも、姫が王様になりたいなら、\n隣で見てる。'], ['ranka', 'さ、お嬢。\n最後くらい派手にいこっか。']],
    win: [['foe', 'バカな……\n我が契約が……！'], ['sera', '姫さま……いえ、陛下。\nお帰りなさいませ。'], ['garou', 'ガハハ！\n近衛の長、拝命しますぜ！'], ['ranka', 'じゃ、わたしは釣りの続きに戻るよ。\nお嬢、また呼んでよ。\n悪魔が出たらね。'], ['lily', 'ちょっと！ 待ちなさいランカ！\n……ラナさん、お元気で！'], ['mina', '……おかえり、姫。']] },
};
const LOSE = [['mina', '退けきれなかった……。\nでも、まだ終わってない。'], ['rana', '立て直しましょう。\n次の章で、必ず。']];
const REF_W = 941, REF_H = 1672, FOOT = 1215;
const LANA = { dir: '../sprites/', frames: 24, fps: 12, w: 536, h: 388, ax: 336, ay: 379, scale: 1.28, x: 300, from: -220 }; // morning.js と同じ大きさ
const ALLY_S = .75, OTHER_X = 650;           // 仲間の全身（高さ640）の縮尺は朝の会話と同じ
const GEN_BODY = { g1: 540, g2: 520, g3: 490, g4: 560, g5: 510, g6: 500, g6b: 520 }; // 敵将の体の高さ（基準画素。仲間＝480）
const GEN_DX = { g1: -50 }; // 立ち位置の調整（武器が画面の外に出る人だけ）
let genMeta = null; const genMetaP = fetch('assets/npc/gen_meta.json?v=1').then(r => r.json()).then(m => (genMeta = m)).catch(() => (genMeta = {}));
const CSS = `
#story{position:fixed;inset:0;z-index:13;display:none;background:#0b0806;font-family:${SERIF};color:#f6ead0;-webkit-tap-highlight-color:transparent;user-select:none;overflow:hidden}
#story .st{position:absolute;top:0;bottom:0;left:50%;aspect-ratio:${REF_W}/${REF_H};transform:translateX(-50%);background:#000 center/100% 100% no-repeat}
#story .a{position:absolute;pointer-events:none;filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0007);transition:filter .3s}
#story .a.dim{filter:drop-shadow(0 calc(var(--u)*8) calc(var(--u)*10) #0007) brightness(.5)}
#story .oth{opacity:0;transition:opacity .45s,transform .45s,filter .3s;transform:translateX(calc(var(--u)*50))}
#story .oth.on{opacity:1;transform:none}#story .ral{z-index:2}
#story .card{position:absolute;inset:0;z-index:5;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:calc(var(--u)*36);background:#000a;opacity:0;transition:opacity .7s}
#story .card.on{opacity:1}
#story .card small{font-size:calc(var(--u)*40);letter-spacing:.5em;color:#c9a24a}
#story .card h2{margin:0;font-size:calc(var(--u)*86);font-weight:700;letter-spacing:.2em;text-shadow:0 3px 8px #000}
#story .card p{margin:0 8%;font-size:calc(var(--u)*38);line-height:1.7;text-align:center;color:#e8dcc0}
#story .card i{display:block;width:70%;height:2px;background:linear-gradient(90deg,#c9a24a00,#c9a24a,#c9a24a00)}
#story .box{position:absolute;left:calc(var(--u)*30);right:calc(var(--u)*30);bottom:calc(var(--u)*34);border:calc(var(--u)*30) solid transparent;border-image:url(assets/ui/frame_l.png) 90 / calc(var(--u)*30) / 0 stretch;margin:calc(var(--u)*-18);isolation:isolate;container-type:inline-size;display:none}
#story .box::before{content:"";position:absolute;inset:calc(var(--u)*-14);z-index:-1;background:linear-gradient(#1b2338f4,#0e1322f6);border-radius:calc(var(--u)*6);box-shadow:0 calc(var(--u)*6) calc(var(--u)*20) #0009}
#story .box::after{content:"";position:absolute;inset:calc(var(--u)*-6);z-index:-1;border:calc(var(--u)*2) solid #c9a24a8c;border-radius:calc(var(--u)*4);pointer-events:none}
#story .nm{padding:calc(var(--u)*12) calc(var(--u)*30) 0;color:#fff4dc;text-shadow:0 2px 3px #000}
#story .nm small{display:block;font:700 calc(var(--u)*27)/1.3 ${SERIF};color:#d6a64a;letter-spacing:.12em}
#story .nm small:empty{display:none}
#story .nm b{display:block;font:700 calc(var(--u)*48)/1.25 ${SERIF};letter-spacing:.08em}
#story .ln{display:block;height:calc(var(--u)*3);width:48%;margin:calc(var(--u)*12) 0 0 calc(var(--u)*26);background:linear-gradient(90deg,#c9a24a00,#c9a24a 12%,#c9a24a 55%,#c9a24a00)}
#story .tx{padding:calc(var(--u)*18) calc(var(--u)*30) calc(var(--u)*16);font:600 calc(var(--u)*43)/1.55 ${SERIF};font-size:min(calc(var(--u)*43),calc((100cqi - var(--u)*60)/18.4));color:#f2e8d4;letter-spacing:.04em;white-space:pre-line}
#story .nx{position:absolute;right:calc(var(--u)*30);bottom:calc(var(--u)*26);width:calc(var(--u)*16);height:calc(var(--u)*16);border:calc(var(--u)*3) solid #d6a64a;background:#d6a64a55;rotate:45deg;animation:storynx 1.1s ease-in-out infinite}
@keyframes storynx{50%{translate:0 calc(var(--u)*-8)}}
#story .box.on{display:block}
#story .tx{height:6.2em;box-sizing:content-box}
#story .skip{position:absolute;z-index:6;right:calc(var(--u)*36);top:calc(var(--u)*40);font:700 calc(var(--u)*32)/1 ${SERIF};color:#fff;text-shadow:0 1px 3px #000;background:#0005;border:0;padding:calc(var(--u)*10) calc(var(--u)*18);border-radius:calc(var(--u)*30)}`;
let frames = null;
function loadFrames() { if (frames) return frames; frames = []; for (let i = 0; i < LANA.frames; i++) { const im = new Image(); im.src = `${LANA.dir}walk_${String(i).padStart(2, '0')}.png`; frames.push(im); } frames.idle = new Image(); frames.idle.src = `${LANA.dir}idle_00.png`; return frames; }

export function createStory() {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  const el = document.createElement('div'); el.id = 'story'; document.body.appendChild(el);
  let done = null, typing = 0, raf = 0, onR = null;
  const close = () => { clearTimeout(typing); cancelAnimationFrame(raf); if (onR) window.removeEventListener('resize', onR); el.style.display = 'none'; el.innerHTML = ''; el.onclick = null; const f = done; done = null; f && f(); };
  // o = { c, kind: 'start'|'win'|'lose', title, desc, foeName, foeKey:'g1'…'g6b' }
  async function play(o, onDone) {
    const lines = o.kind === 'lose' ? LOSE : ((SCENES[o.c] || {})[o.kind] || []);
    if (!lines.length && o.kind !== 'start') { onDone && onDone(); return; }
    await genMetaP; done = onDone; el.style.display = 'block'; const fr = loadFrames();
    el.innerHTML = `<div class="st" style="background-image:url(assets/story/bg_${o.c}.webp?v=1)"><img class="a oth" alt=""><img class="a ral" alt=""></div>${o.kind === 'start' ? `<div class="card"><small>第${NUM[o.c] || o.c}章</small><h2>${o.title}</h2><i></i><p>${o.desc}</p></div>` : ''}<div class="box"><div class="nm"><small></small><b></b></div><i class="ln"></i><div class="tx"></div><span class="nx"></span></div><button class="skip">スキップ ▶</button>`;
    const stage = el.querySelector('.st'), ral = el.querySelector('.ral'), oth = el.querySelector('.oth'), card = el.querySelector('.card'), box = el.querySelector('.box'), nm = el.querySelector('.nm'), tx = el.querySelector('.tx');
    const U = () => stage.clientHeight / REF_H;
    onR = () => { el.style.setProperty('--u', U() + 'px'); ralAt(rx); if (cur) placeOth(cur); }; el.style.setProperty('--u', U() + 'px'); window.addEventListener('resize', onR);
    const place = (img, w, h, ax, ay, x, y, s) => { const u = U(); img.style.width = w * s * u + 'px'; img.style.height = h * s * u + 'px'; img.style.left = (x - ax * s) * u + 'px'; img.style.top = (y - ay * s) * u + 'px'; };
    let rx = LANA.from; const ralAt = x => place(ral, LANA.w, LANA.h, LANA.ax, LANA.ay, x, FOOT, LANA.scale);
    // 右の相手：仲間は全身の立ち姿（左右反転でラナの方を向く）、敵将は全身（もともと左向き）
    let cur = null;
    const placeOth = k => { const u = U();
      if (k === 'foe') { const m = genMeta[o.foeKey]; if (!m) return; const s = (GEN_BODY[o.foeKey] || 520) / m.body; oth.style.scale = ''; place(oth, m.w, m.h, m.ax, m.ay, OTHER_X + 40 + (GEN_DX[o.foeKey] || 0), FOOT, s); }
      else { const w = oth.naturalWidth || 300, h = oth.naturalHeight || 640; place(oth, w, h, w / 2, h - 1, OTHER_X, FOOT, ALLY_S); oth.style.scale = '-1 1'; } };
    const setOth = k => { if (cur === k) return; cur = k; oth.classList.remove('on');
      const src = k === 'foe' ? `assets/npc/gen_${o.foeKey}.webp?v=1` : `../ally/${k}.png`;
      setTimeout(() => { oth.onload = () => { placeOth(k); requestAnimationFrame(() => oth.classList.add('on')); }; oth.src = src; if (oth.complete && oth.naturalWidth) oth.onload(); }, cur ? 180 : 0); };
    // ラナ：左から歩いて入り、立ち止まる
    const t0 = performance.now() + (card ? 400 : 0), WALK = 1500;
    const tick = now => { const t = Math.max(0, Math.min(1, (now - t0) / WALK)), e = 1 - (1 - t) * (1 - t); rx = LANA.from + (LANA.x - LANA.from) * e; ralAt(rx);
      if (t < 1) { ral.src = fr[Math.floor(Math.max(0, now - t0) / 1000 * LANA.fps) % LANA.frames].src; raf = requestAnimationFrame(tick); } else ral.src = fr.idle.src; };
    ral.src = fr[0].src; ralAt(rx); raf = requestAnimationFrame(tick);
    { const first = lines.find(l => l[0] !== 'rana'); if (first) setOth(first[0]); } // 最初の相手は先に立たせておく
    el.querySelector('.skip').onclick = e => { e.stopPropagation(); close(); };
    let i = -1, full = '', step = card ? 'card' : 'line';
    if (card) requestAnimationFrame(() => card.classList.add('on'));
    const show = () => {
      i++; if (i >= lines.length) { close(); return; }
      const [k, t] = lines[i], foe = k === 'foe';
      if (k !== 'rana') setOth(k);
      ral.classList.toggle('dim', k !== 'rana'); oth.classList.toggle('dim', k === 'rana');
      { const [ti, na] = foe ? splitTitle(o.foeName) : ['', NAME[k] || k]; nm.firstChild.textContent = ti; nm.lastChild.textContent = na; } box.classList.add('on');
      full = t; let n = 0; tx.textContent = ''; clearTimeout(typing);
      const ty = () => { n++; tx.textContent = full.slice(0, n); if (n < full.length) typing = setTimeout(ty, 32); else typing = 0; }; ty();
    };
    el.onclick = () => {
      if (step === 'card') { step = 'line'; card.classList.remove('on'); if (!lines.length) { setTimeout(close, 300); return; } setTimeout(show, 350); return; }
      if (typing) { clearTimeout(typing); typing = 0; tx.textContent = full; return; }
      show();
    };
    if (!card) setTimeout(show, 500);
  }
  return { play, close };
}
