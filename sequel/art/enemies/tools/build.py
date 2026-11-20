import os, json, glob, numpy as np, cv2, shutil
from PIL import Image, ImageDraw
K = os.environ.get('KEYED','_work/keyed'); OUT = os.environ.get('OUT','frames')
TARGET_H = 400          # 歩き1コマ目の全高をこのpxにそろえる（ゲーム側で最終倍率）
MARGIN = 12

def load(clip, i): return np.asarray(Image.open(f'{K}/{clip}/{i:03d}.png'))
def meta(clip): return json.load(open(f'{K}/{clip}/meta.json'))

def loop_period(clip, n):
    sm = [cv2.resize(load(clip, i)[..., 3], (96, 96), interpolation=cv2.INTER_AREA).astype(np.float32) for i in range(n)]
    best = None
    for k in range(16, n):
        d = np.mean([np.abs(sm[i] - sm[i + k]).mean() for i in range(0, n - k)])
        adj = np.mean([np.abs(sm[i] - sm[i + 1]).mean() for i in range(n - 1)])
        if best is None or d < best[1]: best = (k, d, adj)
    return best

def gray_on(img):
    a = img[..., 3:4] / 255.0
    return (img[..., :3] * a + 110 * (1 - a)).astype(np.uint8)

def match_scale(ref, refbb, tgt):
    # 参照（歩き1コマ目）の上部35%を型にして、倍率を振って探す
    x0, y0, x1, y1 = refbb; hh = int((y1 - y0) * 0.35)
    tpl = cv2.cvtColor(gray_on(ref[y0:y0 + hh, x0:x1 + 1]), cv2.COLOR_RGB2GRAY)
    msk = (ref[y0:y0 + hh, x0:x1 + 1, 3] > 128).astype(np.uint8) * 255
    g = cv2.cvtColor(gray_on(tgt), cv2.COLOR_RGB2GRAY)
    best = (0, 1)
    for s in np.arange(0.55, 1.65, 0.01):
        t = cv2.resize(tpl, None, fx=s, fy=s); m = cv2.resize(msk, None, fx=s, fy=s)
        if t.shape[0] >= g.shape[0] or t.shape[1] >= g.shape[1]: continue
        r = cv2.matchTemplate(g, t, cv2.TM_CCORR_NORMED, mask=m)
        r[~np.isfinite(r)] = 0
        v = r.max()
        if v > best[0]: best = (v, s)
    return best

def foot(img, bb):
    a = img[..., 3] > 128; y1 = bb[3]
    xs = np.where(a[max(y1 - 30, 0):y1 + 1].any(0))[0]
    return (xs.min() + xs.max()) / 2, y1

enemies = sorted({c.rsplit('_', 1)[0] for c in os.listdir(K)})
OVR={'hammer_arm_atk1':1.0,'hammer_arm_atk2':1.0,'steam_shield_atk1':1.02,'steam_shield_atk2':1.02}
ONLY=os.environ.get('ONLY','').split(',')
report=json.load(open(f'{OUT}/measure.json')) if os.path.exists(f'{OUT}/measure.json') else {}
for e in enemies:
    if ONLY!=[''] and e not in ONLY: continue
    shutil.rmtree(f'{OUT}/{e}', ignore_errors=True)
    clips = sorted(c for c in os.listdir(K) if c.rsplit('_', 1)[0] == e)
    walk = f'{e}_walk'; wm = meta(walk); wref = load(walk, 0); wbb = wm['frames'][0]['bbox']
    base = TARGET_H / (wbb[3] - wbb[1])
    info = {}
    for c in clips:
        m = meta(c); n = len(m['frames']); f0 = load(c, 0); bb0 = m['frames'][0]['bbox']
        if c == walk: sc, conf = 1.0, 1.0
        elif c in OVR: sc, conf = OVR[c], -1.0
        else: conf, sc = match_scale(wref, wbb, f0)   # sc = 対象での見え方 / 歩き
        s = base / sc
        fx, fy = foot(f0, bb0)
        ci = {'n': n, 'scale_vs_walk': round(float(sc), 3), 'match': round(float(conf), 3), 's': s, 'foot': (fx, fy),
              'clipped_frames': [i for i, f in enumerate(m['frames']) if f['edge']]}
        if c == walk:
            k, d, adj = loop_period(c, n); ci['loop'] = {'period': int(k), 'diff': round(float(d), 2), 'adjacent': round(float(adj), 2)}
        else:
            ci['first_last_diff'] = round(float(np.abs(cv2.resize(f0[..., 3], (96, 96)).astype(float) - cv2.resize(load(c, n - 1)[..., 3], (96, 96)).astype(float)).mean()), 2)
        info[c] = ci
    # 共通の枠（足元基準の座標で全コマの外接）
    L = T = 1e9; R = B = -1e9
    for c, ci in info.items():
        m = meta(c); s = ci['s']; fx, fy = ci['foot']
        for f in m['frames']:
            if not f['bbox']: continue
            x0, y0, x1, y1 = f['bbox']
            L = min(L, (x0 - fx) * s); R = max(R, (x1 - fx) * s); T = min(T, (y0 - fy) * s); B = max(B, (y1 - fy) * s)
    L, T = int(np.floor(L)) - MARGIN, int(np.floor(T)) - MARGIN; R, B = int(np.ceil(R)) + MARGIN, int(np.ceil(B)) + MARGIN
    W, H = R - L, B - T; ax, ay = -L, -T
    od = f'{OUT}/{e}'; os.makedirs(od, exist_ok=True)
    for c, ci in info.items():
        s = ci['s']; fx, fy = ci['foot']
        M = np.float32([[s, 0, ax - fx * s], [0, s, ay - fy * s]])
        cnt = ci['loop']['period'] if 'loop' in ci else ci['n']
        for i in range(cnt):
            im = load(c, i).astype(np.float32)
            pm = im.copy(); pm[..., :3] *= pm[..., 3:4] / 255     # 乗算済みで縮小（縁の暗い輪を防ぐ）
            o = cv2.warpAffine(pm, M, (W, H), flags=cv2.INTER_AREA, borderValue=0)
            a = o[..., 3:4]; o[..., :3] = np.where(a > 0, o[..., :3] * 255 / np.maximum(a, 1e-3), 0)
            act = c[len(e) + 1:]
            Image.fromarray(np.clip(o, 0, 255).astype(np.uint8)).save(f'{od}/{act}_{i:03d}.png', optimize=True)
        ci['frames_out'] = cnt
    report[e] = {'frame_size': [W, H], 'anchor_foot': [ax, ay], 'clips': {c[len(e) + 1:]: {k: v for k, v in ci.items() if k not in ('s', 'foot')} for c, ci in info.items()}}
    print(e, W, H, {c[len(e)+1:]: (ci['scale_vs_walk'], ci['match'], ci['frames_out']) for c, ci in info.items()}, flush=True)
json.dump(report, open(f'{OUT}/measure.json', 'w'), ensure_ascii=False, indent=1)
