// 章の始まりと終わりの会話（2026-10-30）。立ち絵＋名前＋文字送り。タップで次へ。章の始まりは題字の札から。
// 話者：仲間のキー（立ち絵 ../ally/por_<k>_<n>.png）、'rana'（ラナ。立ち絵なし→待機の絵）、'foe'（章の将軍の胸像）。
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
const CSS = `
#story{position:fixed;inset:0;z-index:13;display:none;background:#0b0806;font-family:${SERIF};color:#f6ead0;-webkit-tap-highlight-color:transparent;user-select:none;overflow:hidden}
#story .bg{position:absolute;inset:0;background:url(assets/field/top.jpg) center/cover;filter:brightness(.38) saturate(.8)}
#story .card{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2.2vh;opacity:0;transition:opacity .7s}
#story .card.on{opacity:1}
#story .card small{font-size:2.4vh;letter-spacing:.5em;color:#c9a24a}
#story .card h2{margin:0;font-size:5.2vh;font-weight:700;letter-spacing:.2em;text-shadow:0 3px 8px #000}
#story .card p{margin:0 8%;font-size:2.3vh;line-height:1.7;text-align:center;color:#e8dcc0}
#story .card i{display:block;width:40vh;max-width:80%;height:2px;background:linear-gradient(90deg,#c9a24a00,#c9a24a,#c9a24a00)}
#story .pt{position:absolute;bottom:22vh;height:62vh;width:70%;opacity:0;transition:opacity .35s,transform .35s;transform:translateY(2vh);background:center bottom/contain no-repeat;filter:drop-shadow(0 6px 14px #000a)}
#story .pt.on{opacity:1;transform:none}
#story .pt.L{left:-6%}#story .pt.R{right:-6%}
#story .pt.foe{left:0;right:0;width:100%;height:66vh;background-size:cover;background-position:center top;-webkit-mask-image:linear-gradient(#000 70%,#0000);mask-image:linear-gradient(#000 70%,#0000)}
#story .box{position:absolute;left:3%;right:3%;bottom:3vh;min-height:17vh;padding:3.4vh 4% 2.6vh;background:linear-gradient(#f7ecd0f4,#ead9b0f4);border:2px solid #c9a24a;border-radius:8px;box-shadow:0 4px 18px #000b;color:#3a2410;font-size:2.15vh;line-height:1.75;letter-spacing:.03em;display:none}
#story .box.on{display:block}
#story .nm{position:absolute;left:4%;top:-2.6vh;padding:.6vh 6% .6vh 3%;font-size:2.2vh;font-weight:700;letter-spacing:.2em;color:#fff3d0;background:linear-gradient(90deg,#3a2a1e,#4a362a 80%,#4a362a00);border:1.5px solid #c9a24a;border-right:0}
#story .nm.foe{background:linear-gradient(90deg,#5a1410,#6a1a14 80%,#6a1a1400)}
#story .nx{position:absolute;right:3%;bottom:1vh;font-size:2.6vh;color:#b8862a}
#story .skip{position:absolute;right:3%;top:2vh;z-index:2;font:700 1.8vh/1 ${SERIF};color:#fff;background:#0005;border:0;padding:1vh 1.6vh;border-radius:3vh}`;

export function createStory() {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  const el = document.createElement('div'); el.id = 'story'; document.body.appendChild(el);
  let done = null, typing = 0;
  const close = () => { clearTimeout(typing); el.style.display = 'none'; el.innerHTML = ''; el.onclick = null; const f = done; done = null; f && f(); };
  // o = { c, kind: 'start'|'win'|'lose', title, desc, foeName, foeBust:[url,...], por:{k:[url]}, ranaSrc }
  function play(o, onDone) {
    const lines = o.kind === 'lose' ? LOSE : ((SCENES[o.c] || {})[o.kind] || []);
    if (!lines.length && o.kind !== 'start') { onDone && onDone(); return; }
    done = onDone; el.style.display = 'block';
    el.innerHTML = `<div class="bg"></div>${o.kind === 'start' ? `<div class="card"><small>第${NUM[o.c] || o.c}章</small><h2>${o.title}</h2><i></i><p>${o.desc}</p></div>` : ''}<div class="pt L"></div><div class="pt R"></div><div class="box"><div class="nm"></div><div class="tx"></div><span class="nx">»</span></div><button class="skip">スキップ ▶</button>`;
    const card = el.querySelector('.card'), pL = el.querySelector('.pt.L'), pR = el.querySelector('.pt.R'), box = el.querySelector('.box'), nm = el.querySelector('.nm'), tx = el.querySelector('.tx');
    el.querySelector('.skip').onclick = e => { e.stopPropagation(); close(); };
    let i = -1, full = '', step = card ? 'card' : 'line';
    if (card) requestAnimationFrame(() => card.classList.add('on'));
    const show = () => {
      i++; if (i >= lines.length) { close(); return; }
      const [k, t] = lines[i], foe = k === 'foe';
      const P = foe ? pR : (k === 'rana' ? pL : pR), Q = P === pL ? pR : pL; Q.classList.remove('on');
      P.className = 'pt ' + (P === pL ? 'L' : 'R') + (foe ? ' foe' : '');
      const src = foe ? (o.foeBust || []).map(u => `url(${u})`).join(',') : k === 'rana' ? `url(${o.ranaSrc})` : (o.por[k] && o.por[k].length ? `url(${o.por[k][Math.floor(Math.random() * o.por[k].length)]})` : `url(../ally/${k}.png)`);
      P.style.backgroundImage = src; requestAnimationFrame(() => P.classList.add('on'));
      nm.textContent = foe ? o.foeName : NAME[k] || k; nm.className = 'nm' + (foe ? ' foe' : ''); box.classList.add('on');
      full = t; let n = 0; tx.textContent = ''; clearTimeout(typing);
      const ty = () => { n++; tx.textContent = full.slice(0, n); if (n < full.length) typing = setTimeout(ty, 32); else typing = 0; }; ty();
    };
    el.onclick = () => {
      if (step === 'card') { step = 'line'; card.classList.remove('on'); if (!lines.length) { setTimeout(close, 300); return; } setTimeout(show, 250); return; }
      if (typing) { clearTimeout(typing); typing = 0; tx.textContent = full; return; }
      show();
    };
    if (!card) show();
  }
  return { play, close };
}
