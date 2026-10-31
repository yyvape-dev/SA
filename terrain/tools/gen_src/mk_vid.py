import base64, io, json, html
from PIL import Image
def b64(path):
    im=Image.open(path).convert('RGB'); bio=io.BytesIO(); im.save(bio,'JPEG',quality=94); return "data:image/jpeg;base64,"+base64.b64encode(bio.getvalue()).decode()
N={'g1':'グレン','g2':'ボルグ','g3':'エルザ','g4':'黒騎士','g5':'ヘルマン','g6':'ヴァルド','g6b':'ヴァルド（変貌）'}
IMG={k:b64(f'{k}_vid.png') for k in N}
C=' Camera not moving, plain magenta background.'
MV={'g1':('He swings the huge club off his shoulder and smashes it down to the left, stepping forward hard, then lifts it back onto his shoulder.','He swings the huge club in a full horizontal circle, steps forward, and slams it into the ground to the left with a heavy impact.'),
'g2':('He lunges left and slashes the greatsword diagonally down in one fast, powerful stroke, then returns to his stance.','He raises the greatsword overhead with both hands, leaps forward to the left and slams it straight down with a heavy impact, then rises.'),
'g3':('She lunges forward to the left and thrusts the longsword fast, then pulls back to her guard stance.','She steps forward to the left, slashes the longsword horizontally, then spins and slashes upward in a fast two-hit combo.'),
'g4':('The black knight steps forward to the left and sweeps the giant sword horizontally in a wide, heavy arc, then returns to his stance.','The black knight lifts the giant sword high overhead and smashes it straight down to the left with crushing force, cape whipping.'),
'g5':('The old knight steps forward to the left and cuts the longsword diagonally down in one sharp stroke, then returns to guard.','The old knight dashes forward to the left and strikes three fast slashes: down, across, and up.'),
'g6':('The duke lunges forward to the left and thrusts the rapier fast, coat flaring, then steps back to his stance.','The duke lunges forward to the left and thrusts the rapier three times in rapid succession, coat flaring.'),
'g6b':('The demon duke lunges forward to the left and thrusts the rapier fast, cloak flaring, then steps back to his stance.','The demon duke whirls his burning cloak and slashes the rapier in a wide horizontal arc to the left, then steps back.')}
def prompt(k,mv): return mv+C
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
<body><main><h1>発注票：敵将の動き</h1><p class="sub">7人×2本＝14本。1件ずつ：画像をコピー（または長押しで保存）→ プロンプトをコピー → 動画AIへ。<b>返すのは元のmp4のまま（1280×720）</b>。プロンプトは英語・動詞から短く（長い制約文は動きを殺す）。前へ踏み込んでよい（足元はこちらで合わせる）。歩き・やられはコードで動かすので不要。</p>{body}</main><div id="toast"></div>
<script>const P={P};const IM={json.dumps(IMG)};document.querySelectorAll('img[data-k]').forEach(i=>i.src=IM[i.dataset.k]);
const T=document.getElementById('toast');function toast(m){{T.textContent=m;T.classList.add('on');setTimeout(()=>T.classList.remove('on'),1400)}}
async function copyText(t){{try{{await navigator.clipboard.writeText(t);return true}}catch(e){{const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();let ok=false;try{{ok=document.execCommand('copy')}}catch(_){{}}a.remove();return ok}}}}
document.querySelectorAll('.cp').forEach(b=>b.onclick=async()=>toast(await copyText(P[b.dataset.i])?'プロンプトをコピーした':'コピーできない：文を長押しで選んでコピー'));
document.querySelectorAll('.ci').forEach(b=>b.onclick=async()=>{{const img=b.closest('figure').querySelector('img');try{{const c=document.createElement('canvas');c.width=img.naturalWidth;c.height=img.naturalHeight;c.getContext('2d').drawImage(img,0,0);const blob=await new Promise(r=>c.toBlob(r,'image/png'));await navigator.clipboard.write([new ClipboardItem({{'image/png':blob}})]);toast('画像をコピーした')}}catch(e){{toast('コピーできない：画像を長押しで保存')}}}});
let S={{}};try{{S=JSON.parse(localStorage.getItem('order_vid_v2')||'{{}}')}}catch(e){{}}
document.querySelectorAll('input[type=checkbox]').forEach(c=>{{const i=c.dataset.i;c.checked=!!S[i];c.closest('.card').classList.toggle('done',c.checked);c.onchange=()=>{{S[i]=c.checked;c.closest('.card').classList.toggle('done',c.checked);try{{localStorage.setItem('order_vid_v2',JSON.stringify(S))}}catch(e){{}}}}}});</script></body></html>'''
open('order_vid.html','w').write(page); print(len(page))
