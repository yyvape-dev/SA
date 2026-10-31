// 章の始まりと終わりの会話（2026-10-30）。立ち絵＋名前＋文字送り。タップで次へ。章の始まりは題字の札から。
// 話者：仲間のキー、'rana'、'foe'（章の将軍）。2026-10-31 朝の会話と同じ舞台式に作り直し：章ごとの背景（assets/story/bg_N.webp）に、
// 左にラナ（アクションの歩き→待機）、右に相手（仲間＝全身の立ち姿 ../ally/<k>.png、敵将＝全身 assets/npc/gen_<k>.webp）。話していない方は暗くする。
const SERIF = "'DMincho','Hiragino Mincho ProN','Yu Mincho',serif";
const NAME = { mina: 'ミナ', garou: 'ガロウ', sera: 'セラ', ranka: 'ランカ', lily: 'リリィ', rana: 'ラナ' };
const NUM = ['', '一', '二', '三', '四', '五', '六'];
export const SCENES = {
  1: { start: [['mina', '姫、ここなら追っ手も来ない。……しばらくは、ね。'], ['rana', 'ありがとう、ミナ。ここから始めましょう。国を取り戻すために。'], ['mina', '民はまだ、姫を怖がってる。処刑されるはずだった女王だもん。……でも、わたしは知ってるから。']],
    win: [['foe', 'ちっ……ただの小娘じゃなかったか。'], ['mina', 'どこまでも付いてくよ。……べ、別に当然でしょ。'], ['rana', '民が、少しだけ笑ってくれた。']] },
  2: { start: [['garou', 'ガハハ！ 姫、東の地は俺に任せてくだせえ。'], ['garou', '……ただ、向こうの傭兵団に、見覚えのある旗がありやしてね。'], ['rana', 'ガロウ？'], ['garou', 'なに、昔の話でさぁ。']],
    win: [['foe', '金で振る斧の方が、よっぽど楽だったろうに。'], ['garou', '金で振る斧と、主のために振る斧の違い……見せてやりましたぜ。'], ['garou', '団長、行きな。もう二度と、姫の前に立つんじゃねえ。']] },
  3: { start: [['sera', 'あの、姫さま……本日より内政を預かります、セラです。帳簿は、得意です。'], ['sera', '……向こうの陣に、懐かしい紋章が見えました。気のせいだと、いいのですが。']],
    win: [['foe', '強くなったわね、セラ。……一つだけ教えてあげる。大公の軍は、得体の知れないものと取引しているわ。'], ['sera', '姉さま……。'], ['sera', '姫さま。わたしは、ここに残ります。この国の帳簿は、わたしがつけます。']] },
  4: { start: [['ranka', 'あれ、困ってる？ 釣りの途中だったんだけどさ……お嬢、手、貸そっか？'], ['rana', 'あなたは……？'], ['ranka', 'ランカ。通りすがりの、ちょっと強い人だよ。']],
    win: [['foe', '……グ……ァ……'], ['ranka', '……やっぱり。こいつ、中身は悪魔だよ。'], ['ranka', '……お嬢。ここから先は、ちょっとだけ真面目にやるよ。']] },
  5: { start: [['lily', 'ランカ！ やっと見つけた……！'], ['ranka', 'げ、リリィ。'], ['lily', '「げ」じゃないでしょ！ ……ラナさん、話は聞きました。わたしも戦います。']],
    win: [['foe', '……強くなったな、姫。大公は悪魔と契約した。王都の地下に、封印がある。'], ['foe', 'この剣を持っていけ。わしには、もう振る資格がない。'], ['lily', 'ランカ、一人で行く気でしょ。……ちょっと！ 何してるの！ 一人で行かせるわけないでしょ。']] },
  6: { start: [['rana', '王都が見える。……帰ってきたわ。'], ['mina', '国なんて取り戻せなくても、姫と二人で生きていければよかった。……でも、姫が王様になりたいなら、隣で見てる。'], ['ranka', 'さ、お嬢。最後くらい派手にいこっか。']],
    win: [['foe', 'バカな……我が契約が……！'], ['sera', '姫さま……いえ、陛下。お帰りなさいませ。'], ['garou', 'ガハハ！ 近衛の長、拝命しますぜ！'], ['ranka', 'じゃ、わたしは釣りの続きに戻るよ。お嬢、また呼んでよ。悪魔が出たらね。'], ['lily', 'ちょっと！ 待ちなさいランカ！ ……ラナさん、お元気で！'], ['mina', '……おかえり、姫。']] },
};
const LOSE = [['mina', '退けきれなかった……。でも、まだ終わってない。'], ['rana', '立て直しましょう。次の章で、必ず。']];
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
#story .box{position:absolute;z-index:4;left:calc(var(--u)*30);right:calc(var(--u)*30);bottom:calc(var(--u)*34);border:calc(var(--u)*30) solid transparent;border-image:url(assets/ui/frame_l.png) 90 / calc(var(--u)*30) / 0 stretch;margin:calc(var(--u)*-18);isolation:isolate;display:none}
#story .box.on{display:block}
#story .box::before{content:"";position:absolute;inset:calc(var(--u)*-14);z-index:-1;background:linear-gradient(#f7ecd0f8,#ead9b0f8);border-radius:calc(var(--u)*10)}
#story .nm{position:absolute;left:calc(var(--u)*28);top:calc(var(--u)*-62);padding:calc(var(--u)*10) calc(var(--u)*56) calc(var(--u)*10) calc(var(--u)*26);font:700 calc(var(--u)*40)/1.2 ${SERIF};color:#fff3d0;background:linear-gradient(90deg,#3a2a1e,#4a362a 80%,#4a362a00);border:calc(var(--u)*2) solid #c9a24a;border-right:0;letter-spacing:.2em;text-shadow:0 2px 3px #000}
#story .nm.foe{background:linear-gradient(90deg,#5a1410,#6a1a14 80%,#6a1a1400)}
#story .tx{min-height:calc(var(--u)*196);padding:calc(var(--u)*30) calc(var(--u)*30) calc(var(--u)*20);font:600 calc(var(--u)*43)/1.62 ${SERIF};color:#3a2410;letter-spacing:.04em}
#story .nx{position:absolute;right:calc(var(--u)*22);bottom:calc(var(--u)*10);font:900 calc(var(--u)*50)/1 ${SERIF};color:#b8862a}
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
    el.innerHTML = `<div class="st" style="background-image:url(assets/story/bg_${o.c}.webp?v=1)"><img class="a oth" alt=""><img class="a ral" alt=""></div>${o.kind === 'start' ? `<div class="card"><small>第${NUM[o.c] || o.c}章</small><h2>${o.title}</h2><i></i><p>${o.desc}</p></div>` : ''}<div class="box"><div class="nm"></div><div class="tx"></div><span class="nx">»</span></div><button class="skip">スキップ ▶</button>`;
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
      nm.textContent = foe ? o.foeName : NAME[k] || k; nm.className = 'nm' + (foe ? ' foe' : ''); box.classList.add('on');
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
