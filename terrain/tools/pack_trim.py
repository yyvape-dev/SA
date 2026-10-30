# 一騎打ちの連番シートを「詰め直す」：1コマずつ透明な余白を切り、隙間なく並べ直す（拡大・縮小はしない＝画質はそのまま）。
# meta の各クリップに fr＝[[シート上のx, y, 幅, 高さ, 元のコマの中でのずれx, ずれy], …] と sw・sh（シートの大きさ）を足す。cw・ch・idle・pad（元のコマの座標）はそのまま。
# 読む側（terrain/main.js の clipActor・clipFrame、battle/ally.js・draw.js）は fr があれば、その矩形を、元のコマの位置＋ずれに描く。
# 使い方: cd terrain && python3 -I tools/pack_trim.py ../ally/duel_meta.json ../ally/   ／   assets/npc/foeduel_meta.json assets/npc/
#   既に fr のあるクリップは飛ばす。sol（味方の槍兵、foeduel_1 の色違い・縮小版）は foeduel_meta.json の 'sol' に別のクリップとして作る
import sys, json, numpy as np
from PIL import Image
MAXW = int(__import__('os').environ.get('MAXW', 4096)); PAD = 2
def pack(path_img, c, scale=1.0):
    im = Image.open(path_img).convert('RGBA'); A = np.array(im)
    cw, ch, cols = c['cw'] * scale, c['ch'] * scale, c['cols']
    boxes = []
    for i in range(c['n']):
        x0, y0 = round((i % cols) * cw), round((i // cols) * ch); x1, y1 = min(A.shape[1], round(x0 + cw)), min(A.shape[0], round(y0 + ch))
        a = A[y0:y1, x0:x1, 3] > 0; ys, xs = np.where(a)
        if len(xs) == 0: boxes.append((x0, y0, 1, 1, 0, 0)); continue
        bx0, by0 = max(0, xs.min() - PAD), max(0, ys.min() - PAD); bx1, by1 = min(x1 - x0, xs.max() + 1 + PAD), min(y1 - y0, ys.max() + 1 + PAD)
        boxes.append(tuple(int(v) for v in (x0 + bx0, y0 + by0, bx1 - bx0, by1 - by0, bx0, by0)))
    order = sorted(range(len(boxes)), key=lambda i: -boxes[i][3]); mw = max(b[2] for b in boxes); best = None
    for W in range(mw, MAXW + 1, 16): # 幅を変えて、面積がいちばん小さい並べ方を選ぶ（棚詰め）
        pos = [None] * len(boxes); x = y = rowh = 0
        for i in order:
            w, h = boxes[i][2], boxes[i][3]
            if x + w > W: x = 0; y += rowh + 1; rowh = 0
            pos[i] = (x, y); x += w + 1; rowh = max(rowh, h)
        Wu = max(pos[i][0] + boxes[i][2] for i in range(len(boxes))); H = y + rowh
        if H <= MAXW and (best is None or Wu * H < best[0]): best = (Wu * H, Wu, H, pos)
    _, W, H, pos = best; out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for i, b in enumerate(boxes): out.paste(im.crop((b[0], b[1], b[0] + b[2], b[1] + b[3])), pos[i])
    fr = [[pos[i][0], pos[i][1], b[2], b[3], round(b[4] / scale, 2), round(b[5] / scale, 2)] for i, b in enumerate(boxes)]
    return out, fr
def save(out, path):
    out.save(path, 'WEBP', quality=95, alpha_quality=100, method=6)  # 元は quality 88〜90。95 で保存し直しても見た目は変わらない（PSNR 約39dB）。lossless はファイルが3倍になる
if __name__ == '__main__':
    mp, base = sys.argv[1], sys.argv[2]; meta = json.load(open(mp))
    if 'foeduel' in mp and '1' in meta and 'sol' not in meta: # 味方の槍兵（色違い・縮小）：foeduel_1 と同じ並びの別ファイル
        meta['sol'] = []
        for c in meta['1']:
            f = c['f'].replace('foeduel', 'solduel'); s = Image.open(base + f).size[0] / (c['cols'] * c['cw'])
            d = {**c, 'f': f, 'cw': c['cw'] * s, 'ch': c['ch'] * s, 'idle': {k: v * s for k, v in c['idle'].items()}, 'pad': (c.get('pad') if c.get('pad') is not None else 2.8) * s}
            d.pop('fr', None); meta['sol'].append(d)
    for key, clips in meta.items():
        for c in clips:
            if 'fr' in c: continue
            p = base + c['f']; before = Image.open(p).size
            out, fr = pack(p, c); save(out, p); c['fr'] = fr; c['sw'], c['sh'] = out.size
            print(key, c['f'], before, '→', out.size, '面積 %.0f%%' % (out.size[0] * out.size[1] / (before[0] * before[1]) * 100))
    json.dump(meta, open(mp, 'w'), ensure_ascii=False)
