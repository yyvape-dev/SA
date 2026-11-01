# 2026-11-01 マップの小物（外部AIのシート3枚）を切り出す：開拓の小物・魔法の森・都市
# 使い方: cd terrain && python3 -I tools/slice_props2.py  （tools/props_src/<シート>.png → assets/props2/<名前>.webp と assets/props2/meta.json）
# 背景抜きは slice_more.py と同じ（マゼンタ）。並びは上の段から、左から右。
import json, numpy as np, cv2
from PIL import Image
SHEETS = {
  'clear': ['stump_s', 'stump_l', 'stump_axe', 'logs', 'sawbench', 'stones'],
  'magic': ['m_bench', 'm_lantern', 'm_rune', 'm_shroom', 'm_spring', 'm_fence', 'm_basket', 'm_orb'],
  'city':  ['c_fountain', 'c_lamp', 'c_bench', 'c_flowerbed', 'c_well', 'c_fence', 'c_statue', 'c_cart'],
}
def key(path):
    p = cv2.imread(path); b, g, r = [p[..., i].astype(float) for i in range(3)]
    mag = np.minimum(r, b) - g
    alpha = np.clip((130 - mag) / 70, 0, 1)
    spill = np.clip((mag - 10) / 120, 0, 1)
    r2 = r - (r - g) * spill * 0.9; b2 = b - (b - g) * spill * 0.9
    pink = ((r2 > g + 10) & (b2 > g + 10) & (alpha < 0.999)) | ((r2 > g + 25) & (b2 > g + 25))
    r2 = np.where(pink, g, r2); b2 = np.where(pink, g * 0.7, b2)
    return np.dstack([b2, g, r2, alpha * 255]).clip(0, 255).astype(np.uint8), (alpha > 0.35).astype(np.uint8)
def cut(rgba, m, minarea=2500):
    m2 = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8))
    n, lab, st, cen = cv2.connectedComponentsWithStats(m2)
    H = rgba.shape[0]; comps = [i for i in range(1, n) if st[i, 4] > minarea]
    comps.sort(key=lambda i: (int((st[i, 1] + st[i, 3]) > H * .62), cen[i][0]))  # 下端で段を分け、左から
    outs = []
    for i in comps:
        x, y, w, h = st[i, :4]; pad = 4; x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(rgba.shape[1], x + w + pad), min(H, y + h + pad)
        sub = rgba[y0:y1, x0:x1].copy(); mk = cv2.dilate((lab[y0:y1, x0:x1] == i).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        sub[..., 3] = np.where(mk, sub[..., 3], 0); outs.append(cv2.cvtColor(sub, cv2.COLOR_BGRA2RGBA))
    return outs
meta = {}
for sh, names in SHEETS.items():
    parts = cut(*key(f'tools/props_src/{sh}.png')); assert len(parts) == len(names), (sh, len(parts))
    for nm, a in zip(names, parts):
        al = a[..., 3] > 128; ys = np.where(al.any(axis=1))[0]
        Image.fromarray(a).save(f'assets/props2/{nm}.webp', quality=92, method=6); meta[nm] = {'w': a.shape[1], 'h': a.shape[0], 'ay': round(float((ys.max() + 1) / a.shape[0]), 3)}; print(nm, a.shape[:2])
json.dump(meta, open('assets/props2/meta.json', 'w'), indent=1)
