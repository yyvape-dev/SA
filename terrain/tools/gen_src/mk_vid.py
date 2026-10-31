import base64, io, json, html
from PIL import Image
def b64(path):
    im=Image.open(path).convert('RGB'); bio=io.BytesIO(); im.save(bio,'JPEG',quality=94); return "data:image/jpeg;base64,"+base64.b64encode(bio.getvalue()).decode()
N={'g1':'グレン','g2':'ボルグ','g3':'エルザ','g4':'黒騎士','g5':'ヘルマン','g6':'ヴァルド','g6b':'ヴァルド（変貌）'}
IMG={k:b64(f'{k}_vid.png') for k in N}
MV={'g1':('肩に担いだ棍棒を、前へ振り下ろす一撃','棍棒を両手で持ち、大きく振りかぶって地面へ叩きつける'),
'g2':('大剣で、斜め上から前へ斬り下ろす','大剣を頭上に振りかぶり、一歩踏み込んで真下へ叩き斬る'),
'g3':('長剣で、前へ鋭く突く','長剣で横に薙ぎ、そのまま斬り上げる二連撃'),
'g4':('大剣を、前へ横薙ぎに払う','大剣を両手で頭上へ掲げ、重く振り下ろす'),
'g5':('長剣で、斜めに斬り下ろす','一歩踏み込みながら、長剣で三連の斬撃'),
'g6':('細剣で、前へ素早く突く','細剣で、前へ素早く三回連続で突く'),
'g6b':('細剣で、前へ素早く突く','外套を大きくひるがえし、細剣を横に大きく薙ぐ')}
def prompt(k,mv):
    fx='外套の赤い火の粉が少し揺れるのはよいが、それ以外の光や炎のエフェクトは入れない。' if k=='g6b' else '光や炎などのエフェクトは入れない。'
    return f'この画像の人物を動かす。横長1280×720のまま。カメラ固定、ズームなし、パンなし。人物の全身と武器が常に画面内に収まる。背景は単色のマゼンタ(#FF00FF)のまま。顔・髪・鎧・服・武器の形と色は変えない。人物は左を向いたまま、その場で（立ち位置はほぼ動かさず）次の動きをする：{mv}。動きは約3秒で、最後は最初の構えに戻る。{fx}'
cards=[]
for k,n in N.items():
    for j,lab in enumerate(('攻撃A（通常）','攻撃B（大技）')): cards.append((f'{n}：{lab}',k,prompt(k,MV[k][j])))
body=''
for i,(t,k,pr) in enumerate(cards):
    body+=f'''<section class="card"><header><label><input type="checkbox" data-i="{i}"> <b>{html.escape(t)}</b></label></header>
<div class="att"><figure><img data-k="{k}" alt="{k}"><figcaption>添付1（1280×720）<button class="ci">画像をコピー</button></figcaption></figure></div>
<pre>{html.escape(pr)}</pre><button class="cp" data-i="{i}">プロンプトをコピー</button></section>'''
P=json.dumps([c[2] for c in cards],ensure_ascii=False)
page=f'''<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>発注票：敵将の動き（動画AI）</title>
<style>body{{margin:0;background:#1b1712;color:#eee3cf;font:15px/1.6 "Hiragino Mincho ProN","Yu Mincho",serif}}main{{max-width:560px;margin:0 auto;padding:14px}}
h1{{font-size:19px;margin:6px 0 2px}}.sub{{font-size:12.5px;color:#b9a888;margin:0 0 12px}}.sub b{{color:#e8c870}}
.card{{background:#2a231b;border:1px solid #5a4630;border-radius:10px;padding:12px;margin:0 0 14px}}.card.done{{opacity:.45}}
header{{font-size:16px;margin-bottom:8px}}figure{{margin:0;text-align:center}}figure img{{width:100%;border-radius:6px;-webkit-touch-callout:default}}
figcaption{{font-size:12px;color:#c8b48f;display:flex;gap:8px;justify-content:center;align-items:center}}
pre{{white-space:pre-wrap;background:#14110d;border-radius:6px;padding:10px;font-size:13px;margin:10px 0 8px;user-select:all}}
button{{font:inherit;border:0;border-radius:8px;cursor:pointer}}.cp{{width:100%;padding:10px;background:#c9a24a;color:#1b1712;font-weight:700}}.ci{{padding:4px 8px;background:#4a3c2a;color:#eee3cf;font-size:12px}}
#toast{{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:#c9a24a;color:#1b1712;padding:8px 16px;border-radius:20px;opacity:0;transition:.2s;pointer-events:none}}#toast.on{{opacity:1}}</style></head>
<body><main><h1>発注票：敵将の動き</h1><p class="sub">7人×2本＝14本。1件ずつ：画像をコピー（または長押しで保存）→ プロンプトをコピー → 動画AIへ。<b>返すのは元のmp4のまま（1280×720）</b>。歩き・やられは今の敵と同じくコードで動かすので不要。会話の立ち姿は、もらった静止画をそのまま使う。</p>{body}</main><div id="toast"></div>
<script>const P={P};const IM={json.dumps(IMG)};document.querySelectorAll('img[data-k]').forEach(i=>i.src=IM[i.dataset.k]);
const T=document.getElementById('toast');function toast(m){{T.textContent=m;T.classList.add('on');setTimeout(()=>T.classList.remove('on'),1400)}}
async function copyText(t){{try{{await navigator.clipboard.writeText(t);return true}}catch(e){{const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();let ok=false;try{{ok=document.execCommand('copy')}}catch(_){{}}a.remove();return ok}}}}
document.querySelectorAll('.cp').forEach(b=>b.onclick=async()=>toast(await copyText(P[b.dataset.i])?'プロンプトをコピーした':'コピーできない：文を長押しで選んでコピー'));
document.querySelectorAll('.ci').forEach(b=>b.onclick=async()=>{{const img=b.closest('figure').querySelector('img');try{{const c=document.createElement('canvas');c.width=img.naturalWidth;c.height=img.naturalHeight;c.getContext('2d').drawImage(img,0,0);const blob=await new Promise(r=>c.toBlob(r,'image/png'));await navigator.clipboard.write([new ClipboardItem({{'image/png':blob}})]);toast('画像をコピーした')}}catch(e){{toast('コピーできない：画像を長押しで保存')}}}});
let S={{}};try{{S=JSON.parse(localStorage.getItem('order_vid_v1')||'{{}}')}}catch(e){{}}
document.querySelectorAll('input[type=checkbox]').forEach(c=>{{const i=c.dataset.i;c.checked=!!S[i];c.closest('.card').classList.toggle('done',c.checked);c.onchange=()=>{{S[i]=c.checked;c.closest('.card').classList.toggle('done',c.checked);try{{localStorage.setItem('order_vid_v1',JSON.stringify(S))}}catch(e){{}}}}}});</script></body></html>'''
open('order_vid.html','w').write(page); print(len(page))
