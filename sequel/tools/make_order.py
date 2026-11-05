"""発注票（GPT に下絵を塗ってもらう）を1枚のHTMLにする。
  python3 -I sequel/tools/make_order.py <出力.html>                      … 全件
  python3 -I sequel/tools/make_order.py <出力.html> --only b0_backrow [--style 塗った全体の絵.png]
      … その件だけ。--style を渡すと「添付2」に画風の見本（塗った key_full）を実物で入れる"""
import sys, os, json, base64
ARGS = sys.argv[1:]
ONLY = ARGS[ARGS.index('--only') + 1] if '--only' in ARGS else None
STYLE_IMG = ARGS[ARGS.index('--style') + 1] if '--style' in ARGS else None
TITLE = ARGS[ARGS.index('--title') + 1] if '--title' in ARGS else '融合都市の発注票'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = os.path.join(ROOT, 'art/guide')
meta = json.load(open(os.path.join(G, 'guide.json')))

COMMON = ("色の意味：オレンジ＝銅、黄土色＝真鍮、ピンクと水色＝ネオン管の看板、青＝ガラス窓、"
          "灰色＝鉄や石、レンガ色＝レンガ、茶＝木。")
STYLE = ("舞台は、ネオン街とスチームパンクが混ざった近未来の都市。夜。銅と真鍮の配管、リベット、"
         "蒸気、歯車、ネオン管の光（ピンクと水色）、濡れた反射。ダークファンタジー寄りの、"
         "描き込みの多い半写実のゲーム背景画。文字は入れない（看板は記号や図形にする）。")
KEEP = ("添付1は3Dの下絵。形・位置・輪郭・大きさを1pxも変えずに、その上から塗り直す"
        "（建物を足したり、はみ出したり、削ったりしない）。マゼンタ(#FF00FF)の背景は、単色のまま残す。"
        "人物は描かない。出力は添付1と同じ縦横の大きさ。")

ORDERS = [
    ("key_full", "0. 画風を決める1枚（街の全体）", ["key_full"],
     "添付1は3Dの下絵（ゲームの画面そのもの）。構図・建物の位置と形・道の位置は変えずに、完成したゲーム画面の背景画として塗る。"
     + STYLE + COMMON + "道は石畳で、2本の線は路面電車の線路。人物・UI・文字は描かない。出力は添付1と同じ1536×1024。",
     "これが基準になります。気に入るまで作り直してOK。できた絵は、以下の件の「添付2」に使います。"),
]
NAMES = {"b1_tavern": "1. 蒸気の酒場", "b2_workshop": "2. 時計塔の機関工房", "b3_shop": "3. ネオンの装備屋",
         "b4_bridge": "4. 鉄骨の高架と蒸気管", "z_skyline": "5. 遠景の高層の塔と飛行船",
         "f1_lamp": "6. 手前の街灯（暖色）", "f2_pipe": "7. 手前の蒸気弁", "f3_lamp": "8. 手前の街灯（ネオン）",
         "b0_backrow": "9. 裏通りの建物の列（奥）"}
WHAT = {"b1_tavern": "銅のボイラーと煙突のある、レンガの酒場。正面にピンクのネオン看板（ジョッキの形）、木の扉、窓から暖かい光。",
        "b2_workshop": "石造りの機関工房。鉄のシャッター、真鍮の歯車の丸窓、上に時計塔（真鍮の文字盤）。左に縦の配管。",
        "b3_shop": "レンガの装備屋。大きなガラスの陳列窓（中に剣や鎧の影）、銅の庇、右に縦長の水色のネオン看板（剣の形）。",
        "b4_bridge": "鉄骨の高架。上に路面電車の暗い影、下に太い銅の蒸気管。リベットと錆。",
        "z_skyline": "遠くの高層の塔（ガラスと暗い石）と、銅の飛行船。霞んで、窓の明かりがまばら。遠景なので細部は控えめ。",
        "f1_lamp": "鉄の街灯。上に暖色のガス灯。",
        "f2_pipe": "銅の蒸気弁（消火栓のような形）。上に真鍮のハンドル。",
        "f3_lamp": "鉄の街灯。上に水色のネオンの灯り。",
        "b0_backrow": ("表通りの建物の裏にある、裏通りの建物の列（横に長い）。路地のすき間と通りの両端から、奥に少しだけ見える。"
                       "添付2の路地の奥に霞んで見える建物と同じ扱い：紫がかった夜霧に半分溶け、手前の建物より暗く、"
                       "コントラストと彩度を控えめに、細部も少なめ。レンガと石の壁、細い銅の配管、屋上の給水塔と煙突。"
                       "窓は少数だけ暖色の明かり、小さなネオン（水色の縦の看板、ピンクの横の看板）は霧でにじむ程度。"
                       "建物の下の方ほど霧が濃い。霧と光は建物の輪郭の内側だけに描き、マゼンタの部分には霧も光も描かない。")}
for k in NAMES:
    if k not in meta or (ONLY and k != ONLY):
        continue
    w, h = meta[k]['w'], meta[k]['h']
    ORDERS.append((k, NAMES[k], [k, "STYLE"],
                   KEEP + ("添付2（画風の見本）と同じ画風・光・色合いで塗る。" if STYLE_IMG else "添付2（0. の完成画）と同じ画風・光・色合いで塗る。") + STYLE + COMMON + "これは：" + WHAT[k]
                   + "出力は %d×%d。" % (w, h),
                   ("添付2＝画風の見本（塗った全体の絵）。" if STYLE_IMG else "添付2＝「0.」で出来た絵（このページには無いので、自分で添付）。")))
if ONLY:
    ORDERS = [o for o in ORDERS if o[0] == ONLY]

IM = {}
if STYLE_IMG:
    from PIL import Image
    import io
    im = Image.open(STYLE_IMG).convert('RGB')
    buf = io.BytesIO(); im.save(buf, 'PNG')
    IM['STYLE'] = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
for o in ORDERS:
    for a in o[2]:
        if a not in IM and a != "STYLE":
            IM[a] = "data:image/png;base64," + base64.b64encode(open(os.path.join(G, a + ".png"), "rb").read()).decode()

cards = []
for i, (pid, title, atts, prompt, note) in enumerate(ORDERS):
    ah = ""
    for j, a in enumerate(atts):
        if a == "STYLE" and STYLE_IMG:
            ah += '<div class="att"><img data-k="STYLE"><span>添付%d</span><button onclick="cpImg(this)">画像をコピー</button></div>' % (j + 1)
        elif a == "STYLE":
            ah += '<div class="att"><div class="ph">0. の完成画</div><span>添付%d</span></div>' % (j + 1)
        else:
            ah += '<div class="att"><img data-k="%s"><span>添付%d</span><button onclick="cpImg(this)">画像をコピー</button></div>' % (a, j + 1)
    cards.append('''<section class="card" id="c%d"><h2><label><input type="checkbox" data-id="%s"> %s</label></h2>
<div class="atts">%s</div><p class="note">%s</p><pre>%s</pre><button class="big" onclick="cpTxt(this)">プロンプトをコピー</button>
<p class="id">取り込み名：<b>%s</b></p></section>''' % (i, pid, title, ah, note, prompt, pid))

html = '''<title>''' + TITLE + '''</title><meta name="claude:viewport-fit-sides" content="cover">
<style>
/* 縦長スマホで上から順にコピペする票。夜の街に合わせた暗い一色の見た目（単一テーマ） */
:root{--bg:#15131c;--card:#221f2c;--line:#3a3550;--fg:#eeeeee;--sub:#aaaaaa;--brass:#c9a24a;--ink:#111111;--btn:#2c3a52;--note:#99ddcc;--pre:#0f0e14;color-scheme:dark}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.6 system-ui,sans-serif}
main{max-width:560px;margin:auto;padding-block:14px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
h1{font-size:19px}.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px;margin:14px 0}
h2{font-size:17px;margin:0 0 8px}.atts{display:flex;gap:10px}.att{flex:1;text-align:center}.att img{width:100%;border-radius:6px;background:var(--pre)}
.ph{aspect-ratio:3/2;display:flex;align-items:center;justify-content:center;border:2px dashed var(--line);border-radius:6px;color:var(--sub)}
.att span{display:block;font-size:13px;color:var(--brass)}button{background:var(--btn);color:var(--fg);border:0;border-radius:8px;padding:8px 10px;font-size:14px}
.big{width:100%;padding:12px;font-size:16px;background:var(--brass);color:var(--ink);margin-top:6px}pre{white-space:pre-wrap;background:var(--pre);padding:10px;border-radius:8px;font-size:13.5px}
.note{color:var(--note);font-size:13.5px;margin:6px 0}.id{font-size:13px;color:var(--sub);margin:6px 0 0}#t{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:var(--pre);padding:10px 16px;border-radius:20px;display:none}
button:focus-visible{outline:2px solid var(--brass);outline-offset:2px}.atts{flex-wrap:wrap}.att{min-width:0}pre{overflow-x:auto}
</style><main><h1>融合都市・1区画目：下絵を塗る（''' + ('全%d件' % len(ORDERS)) + '''）</h1>
<p>ChatGPT（画像生成）で、上から順に。添付の画像はコピーできない端末では長押しで保存してください。できた絵は、件名の「取り込み名」と一緒に送ってください。</p>
''' + "\n".join(cards) + '''<div id="t"></div></main><script>
const IM=''' + json.dumps(IM) + ''';
document.querySelectorAll('img[data-k]').forEach(i=>i.src=IM[i.dataset.k]);
function toast(s){const t=document.getElementById('t');t.textContent=s;t.style.display='block';setTimeout(()=>t.style.display='none',1800)}
async function cpTxt(b){const s=b.parentNode.querySelector('pre').textContent;try{await navigator.clipboard.writeText(s);toast('コピーしました')}catch(e){const a=document.createElement('textarea');a.value=s;document.body.appendChild(a);a.select();document.execCommand('copy');a.remove();toast('コピーしました')}}
async function cpImg(b){const im=b.parentNode.querySelector('img');try{const c=document.createElement('canvas');c.width=im.naturalWidth;c.height=im.naturalHeight;c.getContext('2d').drawImage(im,0,0);const bl=await new Promise(r=>c.toBlob(r,'image/png'));await navigator.clipboard.write([new ClipboardItem({'image/png':bl})]);toast('画像をコピーしました')}catch(e){toast('コピーできません。画像を長押しで保存してください')}}
document.querySelectorAll('input[type=checkbox]').forEach(c=>{try{c.checked=localStorage.getItem('ord_'+c.dataset.id)==='1'}catch(e){}c.onchange=()=>{try{localStorage.setItem('ord_'+c.dataset.id,c.checked?'1':'0')}catch(e){}}});
</script>'''
open(sys.argv[1], 'w').write(html)
print(len(html) // 1024, 'KB')
