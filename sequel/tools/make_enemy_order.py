# SA2 ダンジョンの敵 12 体（雑魚 8・ボス 4）の設定画の発注票。設計書 sequel/docs/sa2_dungeon_design_T1-T4.md から作る。
# 設定画＝右向きの真横・全身・攻撃前の待機の構え 1 枚（2026-11-14 ユーザー決定）。添付 1＝ラナの待機の構え（画風と構えの見本。本人は描かない）
import re, base64, io, json, html, sys
from PIL import Image

DOC = sys.argv[1]
RANA = sys.argv[2]
OUT = sys.argv[3]
s = open(DOC, encoding='utf-8').read()

# 攻撃前の構え（設計書の 1 つ目の攻撃の出だしに合わせた、待機の姿勢）。チャットの案
POSE = {
 't1_e1': 'knees slightly bent, weight on the front foot, the iron sap held low and ready in the right hand, left hand open for balance',
 't1_e2': 'feet apart, the magitech pistol held at hip height pointing screen-right, left hand open near the chest',
 't1_boss': 'wide planted stance, the huge iron right fist held forward at waist height, the human left arm guarding the chest',
 't2_e1': 'leaning forward, the iron right prosthetic arm cocked back at the elbow ready to swing, left hand low',
 't2_e2': 'hunched forward under the crystal plates, right hand reaching back over the shoulder toward the crystals, ready to throw',
 't2_boss': 'hunched forward, the iron clamp arm reaching forward half open, the hammer arm raised at shoulder height',
 't3_e1': 'low crouch, the oversized right forearm resting forward with knuckles near the ground, ready to slam',
 't3_e2': 'low crouch with the head down, hind legs compressed and all four paws planted, ready to leap screen-right',
 't3_boss': 'hunched forward, both massive arms hanging in front with the knuckles near the ground, legs planted wide',
 't4_e1': 'chassis level and still, the drill pointing screen-right, both tread units fully on the ground',
 't4_e2': 'low four-legged stance, the jaw slightly open and the chest swollen, ready to spit',
 't4_boss': 'treads planted, the drill arm aimed forward at chest height, the crusher hammer arm raised slightly behind',
}
LAND = {'t3_e2', 't4_e1', 't4_e2', 't4_boss'}   # 四つ足・機械＝横長

items = []
for m in re.finditer(r'### (t\d_(?:e\d|boss)) (.+?)\n\n\*\*説明【案】\*\*：(.+?) \*\*高さ：(.+?)。\*\*\n\n形の固定【案】：(.+?)\n', s):
    tid, name, desc, h, shape = m.groups()
    land = tid in LAND
    boss = tid.endswith('boss')
    prompt = (
        f"Create one character design image for an enemy in a 2.5D side-scrolling fantasy action game.\n\n"
        f"Attachment 1 is ONLY a reference for the art style and the kind of pose. Do not draw that girl. "
        f"Match its painterly anime game-art rendering: clean dark outlines, soft painted shading, opaque colors, the same level of detail.\n\n"
        f"Character ({'boss, ' if boss else ''}height {h}): {shape}\n\n"
        f"Pose: a strict RIGHT-FACING SIDE VIEW (profile), full body, standing in a ready combat stance just before attacking: {POSE[tid]}. "
        f"All limbs and the weapon or tool are clearly separated and visible, nothing hidden behind the body. "
        f"This image will be the first frame of an image-to-video animation, so keep a calm, stable stance with no motion blur, no speed lines and no effects.\n\n"
        f"Framing: {'landscape 3:2' if land else 'portrait 2:3'} image. The whole body fits inside with a margin on every side; the character fills about 85% of the image {'width' if land else 'height'}, placed slightly left of center to leave room on the right for the attack motion.\n\n"
        f"Colors: any glow or light on the character is red to red-violet only. No blue, cyan or gold glow (blue means allies and gold means loot in this game). No glowing outline around the character.\n\n"
        f"Background: one solid flat magenta color #FF00FF over the whole background. No floor, no ground line, no cast shadow, no text, no logo, no frame, no other characters."
    )
    items.append({'id': tid, 'name': name, 'desc': desc, 'h': h, 'land': land, 'prompt': prompt})

assert len(items) == 12, len(items)

# 添付 1：ラナの待機の構え（マゼンタの上に置いた PNG）
r = Image.open(RANA).convert('RGBA')
bg = Image.new('RGBA', (r.width + 80, r.height + 60), (255, 0, 255, 255)); bg.alpha_composite(r, (40, 30))
buf = io.BytesIO(); bg.convert('RGB').save(buf, 'PNG')
IM = {'rana': 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()}

cards = []
for i, it in enumerate(items, 1):
    cards.append(f'''
<section class="card" id="c{i}">
 <div class="hd"><label><input type="checkbox" data-done="{it['id']}"> <b>{i}. {html.escape(it['name'])}</b></label><span class="tag">{it['id']}.png ・ {html.escape(it['h'])} ・ {'横長 3:2' if it['land'] else '縦長 2:3'}</span></div>
 <p class="desc">{html.escape(it['desc'])}</p>
 <div class="att"><figure><img data-k="rana" alt="添付1"><figcaption>添付1（画風と構えの見本。全件同じ）</figcaption><button class="b" data-img="rana">画像をコピー</button></figure></div>
 <pre id="p{i}">{html.escape(it['prompt'])}</pre>
 <button class="b big" data-copy="p{i}">プロンプトをコピー</button>
 <p class="note">保存名：<code>{it['id']}.png</code>（PNG のまま。最後まで開けるか確かめてから GitHub へ）</p>
</section>''')

page = f'''<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SA2 敵の設定画の発注票（12体）</title>
<style>
body{{margin:0;background:#14121a;color:#eee;font-family:system-ui,-apple-system,"Hiragino Sans",sans-serif;}}
main{{max-width:560px;margin:0 auto;padding:14px;}}
h1{{font-size:20px;margin:6px 0 4px}} .lead{{font-size:14px;color:#cfc8dc;line-height:1.6}}
.card{{background:#201d29;border:1px solid #3a3448;border-radius:12px;padding:12px;margin:14px 0}}
.card.done{{opacity:.55}}
.hd{{display:flex;flex-direction:column;gap:4px}} .hd b{{font-size:17px}} .tag{{font-size:12px;color:#b9b0cc}}
input[type=checkbox]{{width:22px;height:22px;vertical-align:middle}}
.desc{{font-size:13px;color:#cfc8dc;margin:6px 0}}
figure{{margin:6px 0;display:flex;align-items:center;gap:10px;flex-wrap:wrap}} figure img{{width:96px;border-radius:6px}}
figcaption{{font-size:12px;color:#b9b0cc;flex:1}}
pre{{white-space:pre-wrap;word-break:break-word;background:#0e0c13;border-radius:8px;padding:10px;font-size:12.5px;line-height:1.5;max-height:260px;overflow:auto}}
.b{{background:#3d2f5c;color:#fff;border:0;border-radius:10px;padding:10px 14px;font-size:14px}}
.big{{width:100%;padding:14px;font-size:16px;background:#6a3fc8}}
.note{{font-size:12px;color:#b9b0cc}} code{{color:#e6c9ff}}
#toast{{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:#000c;color:#fff;padding:10px 16px;border-radius:20px;font-size:14px;display:none}}
</style></head><body><main>
<h1>SA2 敵の設定画の発注票（12体）</h1>
<p class="lead">各カード：添付1（全件同じ）を付けて、プロンプトをそのまま貼る。出すのは<b>右向きの真横・全身・攻撃前の待機の構え</b>の1枚だけ（正面は作らない）。背景は #FF00FF。中身は設計書 <code>sequel/docs/sa2_dungeon_design_T1-T4.md</code> の【案】。順番は T1 → T4（どこからでも可）。チェックはこの端末だけに残る。</p>
{''.join(cards)}
</main><div id="toast"></div>
<script>
const IM={json.dumps(IM)};
document.querySelectorAll('img[data-k]').forEach(i=>i.src=IM[i.dataset.k]);
function toast(t){{const e=document.getElementById('toast');e.textContent=t;e.style.display='block';clearTimeout(e._t);e._t=setTimeout(()=>e.style.display='none',2200);}}
async function copyText(t){{try{{await navigator.clipboard.writeText(t);toast('コピーしました');}}catch(e){{const a=document.createElement('textarea');a.value=t;document.body.appendChild(a);a.select();let ok=false;try{{ok=document.execCommand('copy');}}catch(_){{}}a.remove();toast(ok?'コピーしました':'コピーできませんでした。長押しで選んでください');}}}}
async function copyImg(k){{try{{const img=new Image();img.src=IM[k];await img.decode();const c=document.createElement('canvas');c.width=img.naturalWidth;c.height=img.naturalHeight;c.getContext('2d').drawImage(img,0,0);const b=await new Promise(r=>c.toBlob(r,'image/png'));await navigator.clipboard.write([new ClipboardItem({{'image/png':b}})]);toast('画像をコピーしました');}}catch(e){{toast('コピーできませんでした。画像を長押しして保存してください');}}}}
document.querySelectorAll('[data-copy]').forEach(b=>b.onclick=()=>copyText(document.getElementById(b.dataset.copy).textContent));
document.querySelectorAll('[data-img]').forEach(b=>b.onclick=()=>copyImg(b.dataset.img));
document.querySelectorAll('[data-done]').forEach(cb=>{{const k='sa2_enemy_order_'+cb.dataset.done;try{{cb.checked=localStorage.getItem(k)==='1';}}catch(e){{}}const card=cb.closest('.card');card.classList.toggle('done',cb.checked);cb.onchange=()=>{{card.classList.toggle('done',cb.checked);try{{localStorage.setItem(k,cb.checked?'1':'0');}}catch(e){{}}}};}});
</script></body></html>'''
open(OUT, 'w', encoding='utf-8').write(page)
print('cards', len(items), 'bytes', len(page))
print(items[0]['prompt'])
