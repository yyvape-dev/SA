"""濡れた路面の映り込み（光の筋）の元を、塗った絵から取り出す → assets/ground/glints.json

使い方:  python3 -I sequel/tools/make_glints.py
  建物（kind=bld）の塗った絵で「明るく色のある所」（看板・灯り・窓）を塊ごとに拾い、
  下絵のカメラ（guide.json）から建物の正面へ逆に投影して、世界の x・高さ・色を出す。
  ゲームは、その x の地面に、その色の縦の筋を足す（加算）。絵を描き直したら、これを流し直す。
"""
import os, re, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def pieces():
    src = open(os.path.join(ROOT, 'scripts/city_block1.gd'), encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'\{"id": "(\w+)", "kind": "(\w+)", "boxes": \[(.*?)\]\}', src, re.S):
        boxes = []
        for b in re.finditer(r'Vector3\(([^)]*)\), Vector3\(([^)]*)\)', m.group(3)):
            c = [float(v) for v in b.group(1).split(',')]
            s = [float(v) for v in b.group(2).split(',')]
            boxes.append((c, s))
        out[m.group(1)] = (m.group(2), boxes)
    return out


def main():
    guide = json.load(open(os.path.join(ROOT, 'art/guide/guide.json')))
    res = []
    for pid, (kind, boxes) in pieces().items():
        path = os.path.join(ROOT, 'art/painted/%s.png' % pid)
        if kind != 'bld' or not os.path.exists(path) or pid not in guide:
            continue
        g = guide[pid]
        M = np.array(g['vp'], float).reshape(4, 4).T          # 列ごとに並んでいる → 行列へ
        im = Image.open(path).convert('RGB').resize((g['w'], g['h']), Image.LANCZOS)  # 測るためだけ
        a = np.array(im).astype(float)
        mx, mn = a.max(-1), a.min(-1)
        sat = (mx - mn) / np.maximum(mx, 1)
        mag = (a[..., 0] > 190) & (a[..., 2] > 190) & (a[..., 1] < 110)
        hot = (mx > 215) & (sat > 0.25) & ~mag
        hot = ndi.binary_opening(hot, iterations=1)
        lab, n = ndi.label(ndi.binary_dilation(hot, iterations=3))
        zf = max(c[2] + s[2] * 0.5 for c, s in boxes)          # 建物の正面
        y0 = min(c[1] - s[1] * 0.5 for c, s in boxes)
        found = []
        for k in range(1, n + 1):
            m = (lab == k) & hot
            area = m.sum()
            if area < 120:
                continue
            ys, xs = np.nonzero(m)
            col = a[m].mean(0) / 255.0
            col = col / max(col.max(), 1e-3)                    # 色味だけ（明るさは strength）
            def world(u, v):
                nx, ny = u / g['w'] * 2 - 1, 1 - v / g['h'] * 2
                # clip = M·(x,y,zf,1)。nx·w = clip.x、ny·w = clip.y を x・y について解く
                A = np.array([[M[0, 0] - nx * M[3, 0], M[0, 1] - nx * M[3, 1]],
                              [M[1, 0] - ny * M[3, 0], M[1, 1] - ny * M[3, 1]]])
                bvec = -np.array([M[0, 2] * zf + M[0, 3] - nx * (M[3, 2] * zf + M[3, 3]),
                                  M[1, 2] * zf + M[1, 3] - ny * (M[3, 2] * zf + M[3, 3])])
                return np.linalg.solve(A, bvec)
            x0, _ = world(xs.min(), ys.mean())
            x1, _ = world(xs.max(), ys.mean())
            xc, yc = world(xs.mean(), ys.mean())
            found.append({'id': pid, 'x': round(float(xc), 3), 'y': round(float(yc - y0), 3), 'z': round(zf, 3),
                          'w': round(float(min(1.4, max(0.3, abs(x1 - x0)))), 3),
                          'col': [round(float(v), 3) for v in col],
                          'p': round(float(np.sqrt(area) * (mx[m].mean() / 255.0)), 2)})
        found.sort(key=lambda f: -f['p'])
        res += found[:8]
        print(pid, '光の塊', len(found), '→ 使う', min(8, len(found)))
    if res:
        pm = max(f['p'] for f in res)
        for f in res:
            f['p'] = round(f['p'] / pm, 3)
    out = os.path.join(ROOT, 'assets/ground/glints.json')
    json.dump(res, open(out, 'w'), ensure_ascii=False, indent=1)
    print('保存：%s（%d 本）' % (out, len(res)))


if __name__ == '__main__':
    main()
