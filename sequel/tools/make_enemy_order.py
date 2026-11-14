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
# キャンバス＝全員 1440×1080（4:3、横長）。動画AI（Grok）の横長は 4:3 で、720p に縮めて使う（ラナの動画も 4:3）。
# 配置＝攻撃で前（右）へ動く量と、頭上へ振り上げるかで決める（設計書の各攻撃）。数字は 1440×1080 の画素と割合
#   h＝人型の頭〜足の高さ（％）、len＝四つ足・機械の体の長さ（横幅に対する％）、back＝体の後ろ端の左からの位置（％）、front＝体の前端の上限（％）
PLACE = {
 't1_e1':   {'h': 88, 'back': 18, 'front': 50, 'why': '一歩踏み込んで殴る＝前へ少し動く'},
 't1_e2':   {'h': 88, 'back': 18, 'front': 48, 'why': '腕を水平に伸ばして撃つ＝その場'},
 't1_boss': {'h': 72, 'back': 10, 'front': 40, 'why': '鉄拳を頭上へ・3 歩の突進＝上と前に大きな余白'},
 't2_e1':   {'h': 88, 'back': 18, 'front': 48, 'why': '義腕をまっすぐ突き出す＝その場で腕が伸びる'},
 't2_e2':   {'h': 80, 'back': 18, 'front': 50, 'why': '欠片を頭越しに投げる＝頭上の余白'},
 't2_boss': {'h': 80, 'back': 15, 'front': 50, 'why': '短槌を振り上げる・鉗子を伸ばす＝頭上と前の余白'},
 't3_e1':   {'h': 80, 'back': 18, 'front': 52, 'why': '殻の腕を肩より上へ上げて叩く＝頭上の余白'},
 't3_e2':   {'len': 34, 'back': 9, 'front': 43, 'why': '一直線に跳ぶ＝前に大きな余白（跳んだ先も画面の中）'},
 't3_boss': {'h': 80, 'back': 12, 'front': 52, 'why': '片脚を上げて踏む・反る・腕で薙ぐ＝頭上と前の余白'},
 't4_e1':   {'len': 36, 'back': 9, 'front': 45, 'why': '履帯で短く突進＝前に大きな余白'},
 't4_e2':   {'len': 48, 'back': 14, 'front': 62, 'why': '首を突き出して吐く＝その場'},
 't4_boss': {'len': 46, 'back': 9, 'front': 55, 'why': '直線に走る・槌を高く上げる＝前と上の余白'},
}
LAND = {'t3_e2', 't4_e1', 't4_e2', 't4_boss'}   # 四つ足・機械

items = []
for m in re.finditer(r'### (t\d_(?:e\d|boss)) (.+?)\n\n\*\*説明【案】\*\*：(.+?) \*\*高さ：(.+?)。\*\*\n\n形の固定【案】：(.+?)\n', s):
    tid, name, desc, h, shape = m.groups()
    land = tid in LAND
    boss = tid.endswith('boss')
    P = PLACE[tid]
    prompt = (
        f"Create one character design image for an enemy in a 2.5D side-scrolling fantasy action game.\n\n"
        f"Attachment 1 is ONLY a reference for the art style and the kind of pose. Do not draw that girl. "
        f"Match its painterly anime game-art rendering: clean dark outlines, soft painted shading, opaque colors, the same level of detail.\n\n"
        f"Character ({'boss, ' if boss else ''}height {h}): {shape}\n\n"
        f"Pose: a strict RIGHT-FACING SIDE VIEW (profile), full body, standing in a ready combat stance just before attacking: {POSE[tid]}. "
        f"All limbs and the weapon or tool are clearly separated and visible, nothing hidden behind the body. "
        f"This image will be the first frame of an image-to-video animation, so keep a calm, stable stance with no motion blur, no speed lines and no effects.\n\n"
        f"Canvas: landscape 4:3, 1440 x 1080 pixels. This exact framing matters because the image is animated afterwards: "
        + (f"the body length from tail or rear to the front tip is about {P['len']}% of the canvas width ({int(14.4*P['len'])} px); " if land else f"the character is about {P['h']}% of the canvas height from the top of the head to the soles ({int(10.8*P['h'])} px); ")
        + f"the feet (or treads) stand on an invisible ground line about 7% above the bottom edge (y = 1000 px); "
        f"the rear of the body starts at about {P['back']}% from the left edge (x = {int(14.4*P['back'])} px) and the front of the body ends before {P['front']}% (x = {int(14.4*P['front'])} px). "
        f"Leave the whole right side and the space above the head empty for the attack motion. Nothing touches or crosses any edge.\n\n"
        f"Colors: any glow or light on the character is red to red-violet only. No blue, cyan or gold glow (blue means allies and gold means loot in this game). No glowing outline around the character.\n\n"
        f"Background: one solid flat magenta color #FF00FF over the whole background. No floor, no ground line, no cast shadow, no text, no logo, no frame, no other characters."
    )
    items.append({'id': tid, 'name': name, 'desc': desc, 'h': h, 'land': land, 'prompt': prompt, 'P': P})

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
 <div class="hd"><label><input type="checkbox" data-done="{it['id']}"> <b>{i}. {html.escape(it['name'])}</b></label><span class="tag">{it['id']}.png ・ 背 {html.escape(it['h'])} ・ キャンバス 1440×1080（4:3）</span></div>
 <p class="desc">{html.escape(it['desc'])}</p>
 <p class="place">配置：{('体の長さ 横幅の'+str(it['P']['len'])+'％') if it['land'] else ('頭〜足 高さの'+str(it['P']['h'])+'％')}・足元は下から7％・後ろ端 左から{it['P']['back']}％・前端 {it['P']['front']}％まで<br>理由：{html.escape(it['P']['why'])}</p>
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
.desc{{font-size:13px;color:#cfc8dc;margin:6px 0}} .place{{font-size:13px;background:#2c2540;border-left:3px solid #9b7cff;padding:6px 8px;margin:6px 0;line-height:1.5}}
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
<p class="lead"><b>キャンバスは全員 1440×1080（4:3、横長）</b>：動画AIの横長 4:3 にそのまま入れる大きさ（720p に縮めて使う）。配置は攻撃で前・上へ動く分を空けてある（各カードの紫の欄）。<br>4:3 が選べない生成AIなら 1536×1024 で作り、左右を同じだけ切って 1440×1080 相当にする（後ろ端を左から 9％以上にしてあるので、切っても体は残る）。</p>
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
