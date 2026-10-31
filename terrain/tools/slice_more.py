# 2026-10-31 施設の追加分（訓練場・作戦室・城壁・聖堂・兵舎）と区域の門（峠・王都）を切り出す。
# 使い方: python3 -I tools/slice_more.py  （tools/bld_src2/<名前>.png → assets/bld/<名前>_1〜3.webp と gate_pass/gate_cap.webp。data/bld.json に追記）
# 切り方・足元の求め方は slice_buildings.py と同じ。重さを抑えるため webp（品質92）で書く。
import json, numpy as np, cv2
from PIL import Image
SRC = 'tools/bld_src2/'
def key(path):
    p = cv2.imread(path); b, g, r = [p[..., i].astype(float) for i in range(3)]
    mag = np.minimum(r, b) - g
    alpha = np.clip((130 - mag) / 70, 0, 1)
    spill = np.clip((mag - 10) / 120, 0, 1)
    r2 = r - (r - g) * spill * 0.9; b2 = b - (b - g) * spill * 0.9
    pink = ((r2 > g + 10) & (b2 > g + 10) & (alpha < 0.999)) | ((r2 > g + 25) & (b2 > g + 25))
    r2 = np.where(pink, g, r2); b2 = np.where(pink, g * 0.7, b2)
    return np.dstack([b2, g, r2, alpha * 255]).clip(0, 255).astype(np.uint8), (alpha > 0.35).astype(np.uint8)
def cut(rgba, m, minarea=3000):
    m2 = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
    n, lab, st, cen = cv2.connectedComponentsWithStats(m2)
    comps = [i for i in range(1, n) if st[i, 4] > minarea]; comps.sort(key=lambda i: cen[i][0])
    outs = []
    for i in comps:
        x, y, w, h = st[i, :4]; pad = 4; x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(rgba.shape[1], x + w + pad), min(rgba.shape[0], y + h + pad)
        sub = rgba[y0:y1, x0:x1].copy(); mk = cv2.dilate((lab[y0:y1, x0:x1] == i).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        sub[..., 3] = np.where(mk, sub[..., 3], 0); outs.append(cv2.cvtColor(sub, cv2.COLOR_BGRA2RGBA))
    return outs
def footprint(a):
    al = a[..., 3] > 128; h, w = al.shape
    by = np.array([(np.where(al[:, x])[0].max() if al[:, x].any() else -1) for x in range(w)], float)
    x0 = int(np.argmax(by)); yb = by[x0]; xs = np.where(by > yb - 0.30 * h)[0]; xl, xr = int(xs.min()) + 6, int(xs.max()) - 6
    return {'B': [float(x0), float(yb)], 'L': [float(xl), float(by[xl])], 'R': [float(xr), float(by[xr])]}
def meta_of(a, fp=True):
    al = a[..., 3] > 128; ys, xs = np.where(al); yb = ys.max(); band = al[max(0, yb - int(0.04 * a.shape[0])):yb + 1]; bx = np.where(band.any(axis=0))[0]
    m = {'w': int(a.shape[1]), 'h': int(a.shape[0]), 'ax': round(float((bx.min() + bx.max()) / 2 / a.shape[1]), 3), 'ay': round(float((yb + 1) / a.shape[0]), 3)}
    if fp: m['fp'] = {k: [round(v[0], 1), round(v[1], 1)] for k, v in footprint(a).items()}
    return m
meta = json.load(open('data/bld.json'))
def save(a, fn, fp=True):
    Image.fromarray(a).save(fn, quality=92, method=6); meta[fn] = meta_of(a, fp); print(fn, a.shape[:2])
for name in ('drill', 'war', 'wall', 'shrine', 'barracks', 'banner'):
    parts = cut(*key(SRC + name + '.png')); assert len(parts) == 3, (name, len(parts))
    for k, a in enumerate(parts): save(a, f'assets/bld/{name}_{k + 1}.webp')
parts = cut(*key(SRC + 'gates.png')); assert len(parts) == 2, len(parts)
save(parts[0], 'assets/bld/gate_pass.webp', False); save(parts[1], 'assets/bld/gate_cap.webp', False)
json.dump(meta, open('data/bld.json', 'w'), indent=1)
