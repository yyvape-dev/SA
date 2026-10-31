# 2026-10-31 章の会話の素材：背景6枚（tools/story_src/bg_N.png → assets/story/bg_N.webp）と、敵将の全身7枚（tools/gen_src/<k>_orig.png → assets/npc/gen_<k>.webp＋gen_meta.json）
# 使い方: python3 -I tools/story_assets.py
import json, numpy as np, cv2
from PIL import Image
for n in range(1, 7):
    im = Image.open(f'tools/story_src/bg_{n}.png').convert('RGB').resize((941, 1672), Image.LANCZOS); im.save(f'assets/story/bg_{n}.webp', quality=86, method=6)
def key(path): # slice_more.py と同じマゼンタ抜き
    p = cv2.imread(path); b, g, r = [p[..., i].astype(float) for i in range(3)]
    mag = np.minimum(r, b) - g; alpha = np.clip((130 - mag) / 70, 0, 1); spill = np.clip((mag - 10) / 120, 0, 1)
    r2 = r - (r - g) * spill * 0.9; b2 = b - (b - g) * spill * 0.9
    pink = ((r2 > g + 10) & (b2 > g + 10) & (alpha < 0.999)) | ((r2 > g + 25) & (b2 > g + 25))
    r2 = np.where(pink, g, r2); b2 = np.where(pink, g * 0.7, b2)
    return np.dstack([r2, g, b2, alpha * 255]).clip(0, 255).astype(np.uint8)
meta = {}
for k in ('g1', 'g2', 'g3', 'g4', 'g5', 'g6', 'g6b'):
    a = key(f'tools/gen_src/{k}_orig.png'); al = a[..., 3] > 128
    n, lab, st, _ = cv2.connectedComponentsWithStats(al.astype(np.uint8)); big = [i for i in range(1, n) if st[i, 4] > 2000]
    al = np.isin(lab, big); a[..., 3] = np.where(cv2.dilate(al.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0, a[..., 3], 0)
    ys, xs = np.where(a[..., 3] > 128); x0, x1, y0, y1 = xs.min() - 4, xs.max() + 5, ys.min() - 4, ys.max() + 5
    a = a[y0:y1, x0:x1]; al = a[..., 3] > 128; H, W = al.shape
    yb = np.where(al.any(1))[0].max(); fx = np.where(al[yb - int(.05 * H):yb + 1].any(0))[0]; cx = (fx.min() + fx.max()) / 2  # 足元の中心
    band = al[:, max(0, int(cx - .12 * W)):int(cx + .12 * W)]; top = np.where(band.any(1))[0].min()            # 体の真上（武器を除く目安）
    if max(H, W) > 1400: s = 1400 / max(H, W); a = cv2.resize(a, (int(W * s), int(H * s)), interpolation=cv2.INTER_AREA); H, W, cx, yb, top = a.shape[0], a.shape[1], cx * s, yb * s, top * s
    Image.fromarray(a).save(f'assets/npc/gen_{k}.webp', quality=90, method=6)
    meta[k] = {'w': int(W), 'h': int(H), 'ax': round(float(cx), 1), 'ay': round(float(yb + 1), 1), 'body': round(float(yb - top), 1)}
    print(k, meta[k])
json.dump(meta, open('assets/npc/gen_meta.json', 'w'))
