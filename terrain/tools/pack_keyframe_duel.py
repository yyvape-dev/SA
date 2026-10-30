# 使い方: python3 -I tools/pack_keyframe_duel.py <高画質化したコマのフォルダ> duel_<名前>_N.webp <当たりのコマ> <溜めのコマ> <各コマのms,カンマ区切り>（出力先と meta のキーは今 lily 固定。他の仲間に使うときは書き換える）
# 高画質化したコマ（共通の枠、右向き）を一騎打ちの連番シートにする。idle＝1コマ目の人物の枠。人物の高さを520に
import sys, json, glob, numpy as np
from PIL import Image
src, fname, hit, hold, durs = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), [int(x) for x in sys.argv[5].split(',')]
fs = sorted(glob.glob(src + '/frame_*.png')); ims = [Image.open(f).convert('RGBA') for f in fs]; assert len(ims) == len(durs), (len(ims), len(durs))
W, H = ims[0].size; a = np.array(ims[0])[..., 3] > 20; xx = np.where(a.any(0))[0]; yy = np.where(a.any(1))[0]
k = 520 / (yy.max() - yy.min() + 1); cw, ch = round(W * k), round(H * k); cols = 6
sheet = Image.new('RGBA', (cw * cols, ch * 4), (0, 0, 0, 0))
for i, im in enumerate(ims): sheet.paste(im.resize((cw, ch), Image.LANCZOS), ((i % cols) * cw, (i // cols) * ch))
sheet.save('/home/claude/sa/ally/' + fname, 'WEBP', quality=90, method=6)
c = {'f': fname, 'cols': cols, 'cw': cw, 'ch': ch, 'n': len(ims), 'durs': durs, 'hit': hit, 'hold': hold,
     'idle': {'x': round(xx.min() * k, 1), 'w': round((xx.max() - xx.min() + 1) * k, 1), 'h': 520.0}, 'pad': round((H - 1 - yy.max()) * k, 1)}
mp = '/home/claude/sa/ally/duel_meta.json'; m = json.load(open(mp)); L = m.setdefault('lily', []); L[:] = [x for x in L if x['f'] != fname] + [c]; L.sort(key=lambda x: x['f'])
json.dump(m, open(mp, 'w'), ensure_ascii=False); print(fname, sheet.size, c['idle'], c['pad'])
