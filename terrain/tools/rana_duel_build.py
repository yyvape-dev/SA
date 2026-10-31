# 2026-10-31 ラナの一騎打ちの攻撃：アクション戦闘の連番（sprites/atc・atb・thr、右向き）をそのまま並べて、一騎打ちの連番シートにする（拡大・縮小なし）。
#  1＝縦斬り（atc 0〜20、当たり＝コマ9＝元のコマ18）／2＝横薙ぎ（atb 0〜24、当たり＝16＝元のコマ28）／3＝貫通の突き（thr 0〜23、当たり15）
#  足元と体の中心は battle/core.js の ATC_A・ATB_A・THR_A。立ち姿の背の高さ＝219（0.6倍で描いたときの実測）÷ k。
# 使い方: cd terrain && python3 -I tools/rana_duel_build.py && python3 -I tools/pack_trim.py ../ally/duel_meta.json ../ally/（走り side_run_rana も作る）
import json, numpy as np
from PIL import Image
CL = [('atc', range(0, 21), 9, 419, 543, .6), ('atb', range(0, 25), 16, 458, 536, .6), ('thr', range(0, 24), 15, 553.1, 697, .508)]
out = []
for j, (nm, rg, hit, ax, ay, k) in enumerate(CL, 1):
    fr = [np.array(Image.open(f'../sprites/{nm}_{i:02d}.png').convert('RGBA')) for i in rg]
    FH, FW = fr[0].shape[:2]; xs = []; ys = []
    for r in fr:
        yy, xx = np.where(r[..., 3] > 8); xs += [xx.min(), xx.max()]; ys += [yy.min(), yy.max()]
    P = 10; x0, y0, x1, y1 = max(0, min(xs) - P), max(0, min(ys) - P), min(FW, max(xs) + P + 1), min(FH, max(max(ys), int(ay)) + P + 1)
    cw, ch, cols, n = x1 - x0, y1 - y0, 6, len(fr); rows = -(-n // cols)
    sh = Image.new('RGBA', (cw * cols, ch * rows))
    for i, r in enumerate(fr): sh.paste(Image.fromarray(r[y0:y1, x0:x1]), ((i % cols) * cw, (i // cols) * ch))
    f = f'duel_rana_{j}.webp'; sh.save('../ally/' + f, 'WEBP', lossless=True, method=4)
    h = 219 / k; w = h * .4
    durs = [120] * n; durs[hit - 1] = 260
    for i in range(hit, n): durs[i] = 80
    out.append({'f': f, 'cols': cols, 'rows': rows, 'cw': int(cw), 'ch': int(ch), 'n': n, 'durs': durs, 'hit': hit, 'hold': hit - 1,
                'idle': {'x': round(ax - x0 - w / 2, 1), 'w': round(w, 1), 'h': round(h, 1)}, 'pad': round(ch - (ay - y0), 1)})
    print(f, n, 'frames', cw, ch, 'hit', hit)
mp = '../ally/duel_meta.json'; meta = json.load(open(mp)); meta['rana'] = out; json.dump(meta, open(mp, 'w'))
# 走り（一騎打ちで踏み込むとき）：sprites/run_00〜09（1.0倍、足元 362,379）。battle は 0.6×RUN_K(0.93) で描く → 立ち姿 365 相当の ph は 365/0.93
fr = [Image.open(f'../sprites/run_{i:02d}.png').convert('RGBA') for i in range(10)]; cw, ch = fr[0].size; sh = Image.new('RGBA', (cw * 6, ch * 2))
for i, im in enumerate(fr): sh.paste(im, ((i % 6) * cw, (i // 6) * ch))
sh.save('../ally/side_run_rana.webp', 'WEBP', lossless=True, method=4)
sp = '../ally/side_meta.json'; sm = json.load(open(sp)); sm['run_rana'] = {'f': 'side_run_rana.webp', 'cols': 6, 'cw': cw, 'ch': ch, 'n': 10, 'durs': [50] * 10, 'ph': round(365 / .93, 1), 'ax': 362, 'ay': 379}; json.dump(sm, open(sp, 'w'))
