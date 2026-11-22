"""ランカ（2026-11-12）の動画を、ゲーム用のアトラス・会話用の立ち絵ループ・カットインにする。
使い方（リポジトリのルートで）：python3 -I sequel/tools/make_ranka.py [作業フォルダ]   （numpy・scipy・matplotlib・PIL・ffmpeg。約3〜5分）
  段階だけ：RANKA_STAGE=cut（背景抜き）／pack（アトラス）／idle（会話の立ち絵）／cutin のどれか（カンマ区切り）。既定は全部。
素材 sequel/art/ranka/src/（マゼンタ背景・右向き・24fps。ユーザーの動画AI。2026-11-12 チャットで受け取り）：
  hit＝くらい（3秒、1104×832。胸に閃光を受けて頭がのけぞる。2026-11-12 09:59 ユーザー指摘で掌底から「くらい」に変更）／atk_combo＝突き→前蹴り→横蹴り→足払い→回し蹴り（3秒。黄〜橙の閃光・弧・ピンクのぶれが焼き込み）
  skill_point＝指さし（4秒）→ 技1「指弾」／skill_ring＝指を顔の前に構える（4秒）→ 技2「円環」（ユーザー：自分中心の大きな円環の連続範囲攻撃）
  skill_thunder＝頭に蒼い雷をまとって腕を交差（6秒）→ 技3「星震」（SA1 の星震。画面の広い範囲）
  walk・run＝その場の歩き・走り（6秒）／event_idle＝会話用の立ち絵（6秒、784×1168）
出力：
  sequel/art/ranka/frames/<clip>/*.png（元の大きさ・切り詰め。git に入れない）・check/<clip>.png（元｜抜いた絵）・ranka_src.json
  sequel/assets/ranka/ranka_<n>.webp・ranka.json（可逆。地区 pck「al2」）・cutin.webp
  sequel/assets/event_idle/ranka_idle.webp（9×8＝72 コマ、1コマ 200×376、12fps＝6秒。lily_idle・rana_idle〈6×6・3秒〉と同じ大きさ）
決まり：
  - 背の高さ HEIGHT_M＝1.93m は仮（前作の比 ranka 214.12 ÷ rana 205 × 1.85m）。ユーザー判定待ち。
  - 画素の細かさはラナ（待機 366px＝1.85m）と同じ。元の連番は元の大きさのまま。
  - 焼き込みの閃光・弧（atk_combo・atk_palm）は FX_BOX の枠の中だけ消し、コードで描く（ラナの atkC と同じ方針）。
  - 通常攻撃：atk_combo を 3 本に分ける（SPLIT）。c1＝突き、c2＝前蹴り、c3＝横蹴り→足払い→回し蹴り→構えへ。
    c1・c2 の終わりは踏み込んだ姿勢なので、続けないときは「戻り」（c1 の出だしを逆に流す）で構えへ。
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc

ROOT = os.getcwd()
sys.path.insert(0, os.path.join(ROOT, "terrain/tools"))
from key_soft import key_soft  # noqa: E402

SRC = os.path.join(ROOT, "sequel/art/ranka/src")
OUT = os.path.join(ROOT, "sequel/art/ranka")
ASSET = os.path.join(ROOT, "sequel/assets/ranka")
IDLE_OUT = os.path.join(ROOT, "sequel/assets/event_idle/ranka_idle.webp")
WORK = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "_work")
STAGES = [s for s in os.environ.get("RANKA_STAGE", "cut,pack,idle,cutin").split(",") if s]

HEIGHT_M = 1.93
BODY_PX = round(366 * HEIGHT_M / 1.85)
CLIPS = ["hit", "atk_combo", "skill_point", "skill_ring", "skill_thunder", "walk", "run"]
LOOPS = ["walk", "run"]
STEP = 2   # 24fps → 12fps（ゲームでは速さを掛けて流す）
PAGE = 4096
# 焼き込みの光を消す枠（元の動画のコマ番号 1 始まり → 枠 [x0, y0, x1, y1]、元の画素）。チャットでコマを並べて決めた
_C = {}
for f in (13, 14): _C[f] = [(700, 60, 1104, 440)]
for f in (15, 16): _C[f] = [(820, 40, 1104, 420)]
_C[30] = [(700, 120, 1104, 440)]
_C[31] = [(650, 40, 1104, 540)]
_C[32] = [(560, 40, 1104, 640)]
for f in (33, 34): _C[f] = [(430, 330, 1104, 832), (700, 40, 1104, 330)]
for f in (37, 38): _C[f] = [(0, 540, 230, 832)]
_C[43] = [(780, 180, 1104, 500)]
_C[44] = [(760, 60, 1104, 520)]
_C[45] = [(680, 140, 1104, 720)]
_C[46] = [(560, 140, 1104, 740)]
for f in (47, 48): _C[f] = [(0, 540, 270, 832)]
for f in (49, 50): _C[f] = [(0, 520, 390, 832)]
_C[51] = [(0, 520, 270, 832)]
_C[52] = [(0, 520, 270, 832), (760, 100, 1104, 600)]
_C[53] = [(780, 80, 1104, 580)]
_C[54] = [(680, 120, 1104, 660)]
for f in (55, 56): _C[f] = [(560, 80, 1104, 832)]
_C[57] = [(560, 80, 1104, 832)]
FX_BOX = {"atk_combo": _C}
# くらい：胸の黄色い閃光（11〜14）と散る赤い破片（15〜19）。体の上なので、黄色の強い所とピンクだけ消す（STRICT）
_H = {}
for f in range(11, 15): _H[f] = [(330, 180, 580, 410)]
for f in range(15, 20): _H[f] = [(430, 170, 640, 590)]
FX_BOX["hit"] = _H
STRICT = {"hit"}
# 通常攻撃の切り分け（元の 24fps のコマ番号 0 始まり、終わりを含まない）と当たり（同じ番号）
SPLIT = {"atk_c1": (0, 26, [12]), "atk_c2": (25, 37, [29]), "atk_c3": (36, 73, [42, 48, 52])}



def video_frames(clip):
    d = os.path.join(WORK, "frames", clip)
    if not os.path.isdir(d) or not os.listdir(d):
        os.makedirs(d, exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SRC, clip + ".mp4"), os.path.join(d, "%03d.png")], check=True)
    return [np.asarray(Image.open(os.path.join(d, f)).convert("RGB")) for f in sorted(os.listdir(d))]


def hsv(a):
    hs = mc.rgb_to_hsv(np.clip(a[..., :3].astype(np.float32), 0, 255) / 255)
    return hs[..., 0] * 360, hs[..., 1], hs[..., 2]


def remove_smear(c):
    """枠の外：足のピンクのぶれ（半透明・ピンク）だけを消す（atk_combo のみ）。"""
    a = c.copy()
    al = a[..., 3].astype(np.float32) / 255
    h, s, v = hsv(a)
    m = (al > 0) & (al < 0.97) & (h >= 315) & (h <= 357) & (s > 0.3) & (v > 0.45)
    a[m, 3] = 0
    return a, int(m.sum())


def remove_baked(c, boxes, strict=False):
    """枠の中の焼き込みの光（黄〜橙の明るい所・ピンクのぶれ・半透明・細い光線）を透明に。体の暗い所は残す。"""
    if not boxes:
        return c, 0
    a = c.copy()
    al = a[..., 3].astype(np.float32) / 255
    h, s, v = hsv(a)
    zone = np.zeros(al.shape, bool)
    for x0, y0, x1, y1 in boxes:
        zone[y0:y1, x0:x1] = True
    solid = al > 0.6
    thin = solid & ~ndi.binary_opening(solid, structure=np.ones((7, 7)))
    warm = (h >= 8) & (h <= 72) & (s > 0.3) & (v > 0.66)
    pale = (v > 0.9) & (s < 0.35) & (al < 0.95)
    pinkred = ((h >= 300) | (h <= 6)) & (s > 0.25) & (v > 0.35)   # 弧の縁の赤・ピンクのぶれ
    if strict:   # 体の上の閃光：はっきりした黄色・ピンク・半透明だけ（肌・シャツは残す）
        yellow = (h >= 38) & (h <= 66) & (s > 0.45) & (v > 0.85)
        m = zone & (al > 0) & (yellow | pinkred | (al < 0.5))
    else:
        m = zone & (al > 0) & (warm | pale | pinkred | (al < 0.6) | thin) & ~((v < 0.4) & ~pinkred)
    a[m, 3] = 0
    n = int(m.sum())
    # 本体から離れた粒（光線の欠片）を消す
    rest = a[..., 3] > 12
    lab, k = ndi.label(rest, np.ones((3, 3)))
    if k > 1:
        sz = ndi.sum(rest, lab, range(1, k + 1))
        big = lab == (int(np.argmax(sz)) + 1)
        near = ndi.binary_dilation(big, iterations=5)
        ids = [i for i in np.unique(lab[near]) if i]
        far = (a[..., 3] > 0) & ~np.isin(lab, ids) & ~near
        a[far, 3] = 0
        n += int(far.sum())
    return a, n


def fix_fringe(rgba):
    """縁（不透明の内側 6px＋半透明）に残る赤紫を、近くの不透明な画素の色へ。"""
    a = rgba.astype(np.float32)
    al = a[..., 3] / 255
    solid = al > 0.97
    dist = ndi.distance_transform_edt(solid)
    edge = (al > 0) & (dist <= 6)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    pink = edge & (r - g > 14) & (b - g > 14) & (b > r * 0.55)
    inner = solid & (dist > 3) & ~((r - g > 14) & (b - g > 14))
    if not inner.any():
        return rgba, 0
    _, idx = ndi.distance_transform_edt(~inner, return_indices=True)
    a[..., :3] = np.where(pink[..., None], a[idx[0], idx[1], :3], a[..., :3])
    return a.astype(np.uint8), int(pink.sum())


def body_x(rgba):
    xs = np.where(rgba[..., 3] > 128)[1]
    return float(np.median(xs)) if len(xs) else 0.0


def board(rgba, col):
    bg = np.zeros_like(rgba[..., :3], dtype=np.float32) + np.array(col, np.float32)
    al = rgba[..., 3:4].astype(np.float32) / 255
    return (rgba[..., :3] * al + bg * (1 - al)).astype(np.uint8)


def find_loop(imgs, pmin=10, pmax=33):
    small = [np.asarray(Image.fromarray(im[..., 3]).resize((im.shape[1] // 4, im.shape[0] // 4))).astype(np.float32) / 255 for im in imgs]
    n = len(small)
    best = (1e9, 0, 0, 0)
    for p in range(pmin, pmax):
        for s0 in range(int(n * 0.2), n - p - int(n * 0.1)):
            d = float(np.abs(small[s0] - small[s0 + p]).mean())
            if d < best[0]:
                best = (d, s0, p, float(np.abs(small[s0] - small[s0 + 1]).mean()))
    return {"start": best[1], "len": best[2], "seam_diff": round(best[0] * 1000, 2), "next_diff": round(best[3] * 1000, 2)}


def cut_clip(clip):
    raw = video_frames(clip)
    boxes = FX_BOX.get(clip, {})
    imgs, removed, fringe = [], 0, 0
    for i, f in enumerate(raw):
        c = key_soft(f.astype(np.float32))
        c, n = remove_baked(c, boxes.get(i + 1), clip in STRICT)
        if clip == "atk_combo":
            c, n2 = remove_smear(c)
            n += n2
        c, nf = fix_fringe(c)
        imgs.append(c); removed += n; fringe += nf
    ys0 = np.where(imgs[0][..., 3] > 128)[0]
    ground, top = int(ys0.max()), int(ys0.min())
    bx0 = body_x(imgs[0])
    d = os.path.join(OUT, "frames", clip)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    fr = []
    for i, im in enumerate(imgs):
        ys, xs = np.where(im[..., 3] > 0)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        fn = "%s_%03d.png" % (clip, i)
        Image.fromarray(im[y0:y1, x0:x1]).save(os.path.join(d, fn), optimize=True)
        fr.append([fn, int(x1 - x0), int(y1 - y0), round(float(x0 - bx0), 1), int(y0 - ground), round(body_x(im) - bx0, 1)])
    picks = sorted(set([int(i * (len(imgs) - 1) / 7) for i in range(8)] + [k - 1 for k in list(boxes)[:4]]))[:10]
    clip_check(clip, raw, imgs, picks, ground, bx0)
    info = {"src": clip + ".mp4", "size": [raw[0].shape[1], raw[0].shape[0]], "count": len(imgs), "ground_y": ground,
            "anchor_x": round(bx0, 1), "body_h": ground - top + 1, "baked_removed_px": removed, "fringe_fixed": fringe,
            "lift_max": max(ground - int(np.where(im[..., 3] > 128)[0].max()) for im in imgs),
            "loop": find_loop(imgs) if clip in LOOPS else None, "frames": fr}
    print(clip, {k: v for k, v in info.items() if k != "frames"}, flush=True)
    return info


def clip_check(name, raw, imgs, picks, ground, ax):
    xs, ys = [], []
    for i in picks:
        y, x = np.where(imgs[i][..., 3] > 0)
        xs += [x.min(), x.max()]; ys += [y.min(), y.max()]
    H, W = raw[0].shape[:2]
    x0, x1, y0, y1 = max(0, min(xs) - 10), min(W, max(xs) + 10), max(0, min(ys) - 10), min(H, max(ys) + 10)
    w, h = x1 - x0, y1 - y0
    sheet = Image.new("RGB", (w * len(picks), h * 2), (0, 0, 0))
    for j, i in enumerate(picks):
        sheet.paste(Image.fromarray(raw[i][y0:y1, x0:x1]), (j * w, 0))
        arr = board(imgs[i][y0:y1, x0:x1], (34, 30, 48)).copy()
        if 0 <= ground - y0 < h:
            arr[ground - y0, :] = (60, 220, 255)
        sheet.paste(Image.fromarray(arr), (j * w, h))
    sc = min(1.0, 2400 / sheet.width)
    sheet = sheet.resize((int(sheet.width * sc), int(sheet.height * sc)), Image.LANCZOS)
    os.makedirs(os.path.join(OUT, "check"), exist_ok=True)
    sheet.save(os.path.join(OUT, "check", name + ".png"))


class Packer:
    def __init__(self):
        self.pages, self.x, self.y, self.row = [Image.new("RGBA", (PAGE, PAGE))], 0, 0, 0

    def add(self, im):
        w, h = im.size
        if self.x + w > PAGE:
            self.x, self.y, self.row = 0, self.y + self.row + 2, 0
        if self.y + h > PAGE:
            self.pages.append(Image.new("RGBA", (PAGE, PAGE)))
            self.x = self.y = self.row = 0
        p = len(self.pages) - 1
        self.pages[p].alpha_composite(im, (self.x, self.y))
        r = (p, self.x, self.y)
        self.x += w + 2
        self.row = max(self.row, h)
        return r


def pack():
    meta = json.load(open(os.path.join(OUT, "ranka_src.json")))
    os.makedirs(ASSET, exist_ok=True)
    for f in os.listdir(ASSET):
        if f.startswith("ranka_") and (f.endswith(".webp") or f.endswith(".import")):
            os.remove(os.path.join(ASSET, f))
    pk = Packer()
    cache = {}
    out = {"height_m": HEIGHT_M, "body_px": BODY_PX, "clips": {}, "note": "ランカ（2026-11-12）。make_ranka.py。frames=[ページ, x, y, w, h, 足元から見た左上 x, y]、fps は 12（歩き・走りは 24）"}

    def put(clip, j, s, dx_off=0.0):
        key = (clip, j)
        if key not in cache:
            c = meta["clips"][clip]
            fn, w, h, ox, oy, dx = c["frames"][j]
            im = Image.open(os.path.join(OUT, "frames", clip, fn))
            w2, h2 = max(1, round(w * s)), max(1, round(h * s))
            im = im.resize((w2, h2), Image.LANCZOS)
            p, x, y = pk.add(im)
            cache[key] = [p, x, y, w2, h2, round((ox - dx_off) * s, 1), round(oy * s, 1)]
        return cache[key]

    def make(name, clip, picks, hits24, fps, loop=False):
        c = meta["clips"][clip]
        s = BODY_PX / c["body_h"]
        frames = []
        for j in picks:
            dxo = c["frames"][j][5] if loop else 0.0
            frames.append(put(clip, j, s, dxo))
        hits = []
        for h24 in hits24:
            hits.append(min(range(len(picks)), key=lambda k: (abs(picks[k] - h24), picks[k] < h24)))
        out["clips"][name] = {"fps": fps, "frames": frames, "hits": hits, "src": clip, "src_frames": picks}
        print(name, len(frames), "コマ、当たり", hits)

    # 構え（idle）＝くらいの動画の最初のコマ（どの動画も同じ構えから始まる）
    make("idle", "hit", [0], [], 1)
    for lp in LOOPS:
        L = meta["clips"][lp]["loop"]
        make(lp, lp, list(range(L["start"], L["start"] + L["len"])), [], 24, loop=True)
    # くらい：構え → のけぞり（元の 19〜30。閃光と破片の 10〜18 は飛ばす＝頭が弾かれる一瞬に見える）→ 構えへ早戻し
    make("hit", "hit", [6, 19, 20, 21, 22, 24, 26, 28, 30, 24, 8, 4, 0], [], 6.0)
    for name, (a, b, h) in SPLIT.items():
        make(name, "atk_combo", list(range(a, b, STEP)) + ([b - 1] if (b - 1 - a) % STEP else []), h, 24 / STEP)
    make("atk_back", "atk_combo", list(range(12, -1, -STEP)), [], 24 / STEP)   # 戻り：c1 の出だしを逆に（踏み込み→構え）
    for sk in ["skill_point", "skill_ring", "skill_thunder"]:
        n = meta["clips"][sk]["count"]
        make(sk, sk, list(range(0, n, 3)), [], 8.0)   # 技の動画は長い（4〜6秒）ので 8fps に間引く（2 ページに収める。速さは技の表で掛ける）
    for i, pg in enumerate(pk.pages):
        bb = pg.getbbox()
        pg = pg.crop((0, 0, bb[2], bb[3]))
        fn = "ranka_%d.webp" % i
        pg.save(os.path.join(ASSET, fn), lossless=True, quality=100, method=6)
        out.setdefault("pages", []).append(fn)
        print("page", i, pg.size, os.path.getsize(os.path.join(ASSET, fn)) // 1024, "KB")
    tips(out)
    json.dump(out, open(os.path.join(ASSET, "ranka.json"), "w"), ensure_ascii=False)


def _auto_hit(meta, clip):
    """前への届きの山（元の 24fps の番号）"""
    c = meta["clips"][clip]
    reach = [f[3] + f[1] for f in c["frames"]]
    return [int(np.argmax(reach))]


def tips(out):
    """攻撃のコマごとに、前へいちばん遠い点（tip_f）と腰からいちばん遠い点（tip）を m で（足元原点・右向き・上が＋）。"""
    px = HEIGHT_M / BODY_PX
    pages = [np.asarray(Image.open(os.path.join(ASSET, p)).convert("RGBA")) for p in out["pages"]]
    for name, c in out["clips"].items():
        if not (name.startswith("atk") or name.startswith("skill")):
            continue
        tf, th = [], []
        for pg, x, y, w, h, ox, oy in c["frames"]:
            a = pages[int(pg)][int(y):int(y) + int(h), int(x):int(x) + int(w), 3] > 128
            ys, xs = np.where(a)
            fx = (xs + float(ox)) * px
            uy = -(ys + float(oy)) * px
            i = int(np.argmax(fx + uy * 0.05))
            tf.append([round(float(fx[i]), 3), round(float(uy[i]), 3)])
            d = (fx - 0.05) ** 2 + (uy - 1.0) ** 2 + np.maximum(fx, 0) * 0.15
            k = int(np.argmax(d))
            th.append([round(float(fx[k]), 3), round(float(uy[k]), 3)])
        c["tip_f"], c["tip"] = tf, th


def idle_sheet():
    """会話用の立ち絵：6秒の動画まるごと（最初と最後のコマがほぼ同じ＝そのまま繰り返せる）を 2コマおきの 72 コマ、9×8 に。
    1コマ 200×376、足元は (x 100, y 371)。lily_idle と同じ大きさの体（背 ≈ 369px）。12fps＝6秒。"""
    raw = video_frames("event_idle")
    cut = []
    for f in raw:
        c = key_soft(f.astype(np.float32))
        c, _ = fix_fringe(c)
        cut.append(c)
    n = len(cut)
    small = [np.asarray(Image.fromarray(c[..., 3]).resize((c.shape[1] // 4, c.shape[0] // 4))).astype(np.float32) / 255 for c in cut]
    best = (float(np.abs(small[0] - small[n - 1]).mean()), 0)
    s0 = 0
    picks = list(range(0, min(n, 144), 2))
    al = np.maximum.reduce([cut[i][..., 3] for i in picks])
    ys, xs = np.where(al > 128)
    top, bot = int(ys.min()), int(ys.max())
    ys0, xs0 = np.where(cut[picks[0]][..., 3] > 128)
    foot_x = float(np.median(xs0[ys0 > ys0.max() - 30]))
    body = 369.0
    s = body / (bot - top + 1)
    CW, CH = 200, 376
    sheet = Image.new("RGBA", (CW * 9, CH * 8))
    for k, i in enumerate(picks):
        im = Image.fromarray(cut[i])
        w2, h2 = round(im.width * s), round(im.height * s)
        im = im.resize((w2, h2), Image.LANCZOS)
        cell = Image.new("RGBA", (CW, CH))
        ox = round(CW / 2 - foot_x * s)
        oy = round(371 - bot * s)
        cell.alpha_composite(im, (max(-w2, ox), oy)) if ox >= 0 else cell.paste(im.crop((-ox, 0, w2, h2)), (0, oy), im.crop((-ox, 0, w2, h2)))
        sheet.alpha_composite(cell, ((k % 9) * CW, (k // 9) * CH))
    sheet.save(IDLE_OUT, quality=92, method=6)   # lily_idle・rana_idle と同じく非可逆（会話の小さな立ち絵）
    a = np.asarray(sheet)[..., 3]
    clipped = int((a[:, ::CW] > 8).sum() + (a[:, CW - 1::CW] > 8).sum())
    print("event idle", "start", s0, "seam", round(best[0] * 1000, 2), "scale", round(s, 3), "pivot x", 100, "y", 371,
          "edge px", clipped, os.path.getsize(IDLE_OUT) // 1024, "KB")
    return picks


def cutin():
    """必殺技のカットイン：会話用の立ち絵の最初のコマ（正面寄り・全身）を、縮めずに余白だけ切る。"""
    raw = video_frames("event_idle")
    c = key_soft(raw[0].astype(np.float32))
    c, _ = fix_fringe(c)
    im = Image.fromarray(c)
    bb = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    im = im.crop(bb)
    os.makedirs(ASSET, exist_ok=True)
    p = os.path.join(ASSET, "cutin.webp")
    im.save(p, lossless=True, quality=100, method=6)
    print("cutin", im.size, os.path.getsize(p) // 1024, "KB")


def main():
    os.makedirs(os.path.join(OUT, "check"), exist_ok=True)
    if "cut" in STAGES:
        meta = {"note": "ランカ（2026-11-12）。右向き。make_ranka.py の背景抜きの結果", "clips": {}}
        for c in CLIPS:
            meta["clips"][c] = cut_clip(c)
        json.dump(meta, open(os.path.join(OUT, "ranka_src.json"), "w"), ensure_ascii=False, indent=1)
    if "pack" in STAGES:
        pack()
    if "idle" in STAGES:
        idle_sheet()
    if "cutin" in STAGES:
        cutin()


if __name__ == "__main__":
    main()
