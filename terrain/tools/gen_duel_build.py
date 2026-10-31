# 2026-10-31 敵将（章の将軍）の一騎打ちの攻撃：元mp4の全コマ（<SRC>/<k>_<A|B>/001.png〜）→ key_soft → 体から離れた光の線を消す
#  → 武器のマゼンタかぶりを灰へ → 共通枠 → 縁(RIM5/0.32) → シート。assets/npc/foeduel_<k>_<A|B>.webp と foeduel_meta.json の '<k>' を作る（このあと pack_trim.py）
# 使い方: cd terrain && python3 -I tools/gen_duel_build.py <SRC> g1 g5 …
import sys, json, glob, numpy as np
sys.path.insert(0, 'tools')
from key_soft import key_soft
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc
SRC = sys.argv[1]; KEYS = sys.argv[2:]
N = 16
HIT = {('g2', 'B'): 12}  # 当たりのコマを決め打ち（叩きつけは、剣が一番前に出るコマ≠当たり）
OPT = { # 人ごとの色の直し：purple＝紫の服を守る、pink＝武器のマゼンタかぶりを灰へ、green＝動画の緑かぶり（くすんだ緑も）を灰へ。グレンは緑の布を着ているので触らない
  'g1': dict(purple=False, pink=True, green=False), 'g2': dict(purple=False, pink=True, green=True), 'g3': dict(purple=False, pink=True, green=True),
  'g4': dict(purple=False, pink=True, green=True), 'g5': dict(purple=False, pink=True, green=True), 'g6': dict(purple=True, pink='bright', green=True), 'g6b': dict(purple=True, pink='bright', green=True)}  # bright＝明るいピンク（剣の光）だけ。紫の服（暗い）は残す
def clean(r, o):
    r = r.copy(); al = r[..., 3] / 255.; m = al > .3
    body = ndi.binary_dilation(ndi.binary_opening(m, structure=np.ones((9, 9))), iterations=4)
    hs = mc.rgb_to_hsv(r[..., :3] / 255.); h = hs[..., 0] * 360; S = hs[..., 1]; V = hs[..., 2]
    light = ((V > .72) & (S < .35)) | ((h > 290) & (h < 345) & (S > .2))   # 剣筋の白い弧・ピンクの光
    kill = (al > 0) & ~body & light; r[..., 3] = np.where(ndi.binary_dilation(kill, iterations=1) & ~body, 0, r[..., 3])
    pk = (h > 292) & (h < 342) & (S > .18) & (r[..., 3] > 0) & bool(o['pink']) & ((V > .55) & (h > 300) if o['pink'] == 'bright' else True)  # 武器に移ったマゼンタ
    gr = (h >= 58) & (h <= 170) & (S > .06) & (r[..., 3] > 0) & o['green']    # 動画の緑・オリーブかぶり
    hs[..., 1] = np.where(pk | gr, S * .15, S); hs[..., 0] = np.where(pk | gr, 30 / 360, hs[..., 0])
    r[..., :3] = np.clip(mc.hsv_to_rgb(hs) * 255, 0, 255).astype(np.uint8)
    m = r[..., 3] > 8; lab, n = ndi.label(m, structure=np.ones((3, 3)))
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1)); big = np.argmax(sz) + 1
        r[..., 3] = np.where((lab == big) | (lab == 0) | np.isin(lab, [k + 1 for k, z in enumerate(sz) if z > 1500]), r[..., 3], 0)
    return r
def rim(o, SZ=5, A=.32):
    a = o.astype(np.float32); al = a[..., 3] / 255; rgb = a[..., :3]
    d = ndi.grey_dilation(al, size=(SZ, SZ)); d = ndi.gaussian_filter(d, 1.2 * SZ / 7)
    rm = np.clip(d - al, 0, 1) * A; oa = al + rm * (1 - al)
    col = (rgb * al[..., None] + np.array([28, 20, 16]) * rm[..., None] * (1 - al[..., None])) / np.maximum(oa[..., None], 1e-6)
    return np.dstack([np.clip(col, 0, 255), oa * 255]).astype(np.uint8)
def body_box(r): # 立ち姿の体（武器を除く目安）：足元の中心から幅±60pxの帯の、上端・下端
    al = r[..., 3] > 128; ys, xs = np.where(al); yb = ys.max()
    cs = np.convolve(al.sum(0), np.ones(41) / 41, 'same'); cx = float(np.argmax(cs))  # 体の中心＝縦に一番詰まった列（足元の近くに剣先があっても引っぱられない）
    band = al[:, int(cx - 60):int(cx + 60)]; top = np.where(band.any(1))[0].min()
    hw = .2 * (yb - top)  # 幅は体の高さから決める（横に伸びた剣を含めない。中心＝足元）
    return top, yb, cx, cx - hw, cx + hw
mp = 'assets/npc/foeduel_meta.json'; meta = json.load(open(mp))
for k in KEYS:
    out = []
    for v in ('A', 'B'):
        fs = sorted(glob.glob(f'{SRC}/{k}_{v}/*.png'))
        if not fs: continue
        raw = [clean(key_soft(np.array(Image.open(f).convert('RGB')).astype(np.float32), keep_purple=OPT[k]['purple']), OPT[k]) for f in fs]
        # 当たり＝武器が一番左（前）へ伸びたコマ。そこまでを細かく、後ろを粗く、16コマ選ぶ
        reach = [np.where((r[..., 3] > 128).any(0))[0].min() for r in raw]; hi = int(np.argmin(reach[:int(len(raw) * .8)]))
        if (k, v) in HIT: hi = HIT[(k, v)]
        if len(raw) < N: raw = raw + [raw[i] for i in range(N - len(raw) - 1, -1, -1)]  # コマが足りない（zip の途中で切れた）ときは、最初の構えへ逆再生で戻す
        if len(raw) == N: idx = list(range(N))  # GPT が選んだ16コマ（zip）はそのまま使う
        else:
            pre = np.linspace(0, hi, 10).round().astype(int).tolist(); post = np.linspace(hi, len(raw) - 1, 7).round().astype(int).tolist()[1:]
            idx = sorted(set(pre + post)); idx = (idx + [len(raw) - 1] * N)[:N]
        hit = idx.index(hi)
        fr = [raw[i] for i in idx]
        ys = []; xs = []
        for r in fr:
            yy, xx = np.where(r[..., 3] > 8); ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
        P = 10; FH, FW = fr[0].shape[:2]; x0, y0, x1, y1 = max(0, min(xs) - P), max(0, min(ys) - P), min(FW, max(xs) + P + 1), min(FH, max(ys) + P + 1)
        cw, ch = x1 - x0, y1 - y0; cols = 6; rows = -(-N // cols)
        sh = Image.new('RGBA', (cw * cols, ch * rows))
        for i, r in enumerate(fr): sh.paste(Image.fromarray(rim(r[y0:y1, x0:x1])), ((i % cols) * cw, (i // cols) * ch))
        f = f'foeduel_{k}_{v}.webp'; sh.save('assets/npc/' + f, 'WEBP', lossless=True, method=4)
        top, yb, cx, bx0, bx1 = body_box(fr[0][y0:y1, x0:x1])
        durs = [120] * N; durs[max(0, hit - 1)] = 260; durs[-1] = 30
        out.append({'f': f, 'cols': cols, 'cw': int(cw), 'ch': int(ch), 'n': N, 'durs': durs, 'hit': hit, 'hold': max(0, hit - 1),
                    'idle': {'x': float(bx0), 'w': float(bx1 - bx0 + 1), 'h': float(yb - top + 1)}, 'pad': float(ch - 1 - yb), 'src': idx})
        print(k, v, 'hit', hit, 'src', idx, 'box', cw, ch, 'body h', yb - top + 1)
    old = {c['f']: c for c in meta.get(k, [])}
    for v in ('A', 'B'):
        f = f'foeduel_{k}_{v}.webp'
        if not any(c['f'] == f for c in out) and f in old: out.append(old[f])
    out.sort(key=lambda c: c['f']); meta[k] = out
json.dump(meta, open(mp, 'w'))
