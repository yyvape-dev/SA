#!/usr/bin/env python3
"""帝国兵（女 ef・男 em）の動画4本 → 敵の連番アトラス＋foe.json の項目。

使い方: python3 -I sequel/tools/make_imperial_foes.py <女歩き.mp4> <女攻撃.mp4> <男歩き.mp4> <男攻撃.mp4> [--preview DIR]
- 背景のマゼンタを抜く。白い軌跡・火花（マゼンタと白の混ざり）は、白の割合を不透明度にして赤へ塗り替える（敵＝赤）。
- 男の歩きは前へ進む前半だけを使い、帽子の位置で横の移動を消す（その場歩き）。
- 大きさ：ラナの画面の密度（431px＝1.85m）にそろえる（HEIGHT の m × 233px）。
- 攻撃は2種：atk0＝そのまま、atk1＝振りかぶりで溜め（止め＋赤い溜めの光）→当たりで赤い弧。コマは同じ。
"""
import json, subprocess, sys, os, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

PX_PER_M = 431.0 / 1.85
HEIGHT = {"ef": 1.90, "em": 2.00}   # 仮（ラナ 1.85・ランカ 1.93）
RED = np.array([235, 30, 25], np.float32)


def frames_of(path):
    d = tempfile.mkdtemp()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, f"{d}/f_%03d.png"], check=True)
    fs = sorted(os.listdir(d))
    return [np.asarray(Image.open(f"{d}/{f}").convert("RGB")).astype(np.float32) for f in fs]


def key(a):
    """マゼンタ抜き＋白の混ざり（軌跡）を赤に。戻り値 RGBA uint8。"""
    corner = np.mean([a[:20, -20:], a[-20:, -20:], a[:20, -200:-180]], axis=(0, 1, 2))
    d = np.sqrt(((a - corner) ** 2).sum(-1))
    al = np.clip((d - 45) / (130 - 45), 0, 1)
    # 体の色（暗い・金・肌・銀の刃）＝マゼンタと白を結ぶ線から外れる画素
    on_line = (a[..., 0] > 200) & (a[..., 2] > 185)
    body = (al >= 0.98) & ~on_line
    near = ndi.binary_dilation(body, iterations=3)
    trail = on_line & ~near & (al > 0.05)
    core = al >= 0.98
    idx = ndi.distance_transform_edt(~core, return_distances=False, return_indices=True)
    col = np.where(core[..., None], a, a[idx[0], idx[1]])
    # 軌跡：白の割合（緑の上がり具合）を不透明度に、色は赤（芯ほど明るい赤）
    w = np.clip((a[..., 1] - corner[1]) / (255 - corner[1]), 0, 1)
    tcol = RED[None, None, :] * (1 - 0.2 * w[..., None]) + np.array([255, 150, 120], np.float32) * 0.2 * w[..., None]
    # マゼンタのにじみ（縁・刃・ぶれたコマ）：縁の4px以内か、はっきりマゼンタの画素だけ、赤と青を緑の高さへ寄せる
    edge = ~ndi.binary_erosion(al > 0.5, iterations=4)
    mag = (col[..., 0] > 150) & (col[..., 2] > 150) & (col[..., 1] < 110)
    m = np.minimum(col[..., 0], col[..., 2]) - col[..., 1]
    sp = np.where((edge | mag) & ~trail & (m > 0), m, 0)[..., None]
    col = col - np.concatenate([sp, np.zeros_like(sp), sp], -1) * np.array([0.85, 0, 1.0])
    col = np.where(trail[..., None], tcol, col)
    al = np.where(trail, np.clip(w * 1.15, 0, 1), al)
    # 画面の端で切れた軌跡は端へ向けて薄く（切り口を見せない）
    h, wd = al.shape
    ramp = np.minimum(np.clip(np.arange(wd)[None, :] / 40.0, 0, 1), np.clip(np.arange(h)[:, None] / 40.0, 0, 1))
    al = np.where(trail, al * ramp, al)
    al = np.where(al < 0.12, 0, al)
    return np.dstack([col, al * 255]).clip(0, 255).astype(np.uint8)


def foot_of(rgba):
    m = rgba[..., 3] > 128
    ys, xs = np.where(m)
    y1 = ys.max()
    low = m[y1 - 30:y1 + 1]
    fx = np.where(low.any(0))[0]
    return y1, fx


def head_x(rgba):
    m = rgba[..., 3] > 128
    ys, xs = np.where(m)
    top = ys.min()
    sel = (ys < top + 70)
    return float(np.median(xs[sel]))


def shift(rgba, dx, dy=0):
    out = np.zeros_like(rgba)
    h, w = rgba.shape[:2]
    dx, dy = int(round(dx)), int(round(dy))
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = rgba[ys0:ys1, xs0:xs1]
    return out


class Atlas:
    def __init__(self, name, maxw=4096):
        self.name, self.maxw, self.items = name, maxw, []

    def add(self, img, foot):
        self.items.append((img, foot))

    def build(self, outdir):
        x = y = rowh = 0
        place = []
        for img, foot in self.items:
            h, w = img.shape[:2]
            if x + w > self.maxw:
                x, y, rowh = 0, y + rowh + 2, 0
            place.append((x, y))
            x += w + 2
            rowh = max(rowh, h)
        W = max(px + it[0].shape[1] for (px, py), it in zip(place, self.items))
        H = y + rowh
        sheet = np.zeros((H, W, 4), np.uint8)
        fr = []
        for (px, py), (img, (fx, fy)) in zip(place, self.items):
            h, w = img.shape[:2]
            sheet[py:py + h, px:px + w] = img
            fr.append([self.name, px, py, w, h, -float(fx), -float(fy)])
        Image.fromarray(sheet, "RGBA").save(os.path.join(outdir, self.name), "WEBP", quality=95, method=6)
        return fr, (W, H)


def crop_scaled(rgba, scale, ref_foot):
    """縮尺をかけ、不透明の外接矩形で切る。足元（ref_foot＝全コマ共通の基準）の位置を返す。"""
    im = Image.fromarray(rgba, "RGBA")
    W, H = im.size
    im = im.resize((round(W * scale), round(H * scale)), Image.LANCZOS)
    a = np.asarray(im)
    m = a[..., 3] > 8
    ys, xs = np.where(m)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    fx, fy = ref_foot[0] * scale - x0, ref_foot[1] * scale - y0
    return a[y0:y1, x0:x1].copy(), (fx, fy)


def standing_h(rgba):
    m = rgba[..., 3] > 128
    ys, _ = np.where(m)
    return ys.max() - ys.min()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    prev = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    if prev:
        args.remove(prev)
    fw, fa, mw, ma = args
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "foe")
    entries = {}
    for kind, wpath, apath in (("ef", fw, fa), ("em", mw, ma)):
        W = [key(a) for a in frames_of(wpath)]
        A = [key(a) for a in frames_of(apath)]
        ref_y, ref_fx = foot_of(A[0])
        base_h = standing_h(A[0])           # 攻撃の1コマ目＝待機の立ち姿（帽子〜足裏）
        scale = HEIGHT[kind] * PX_PER_M / base_h
        if kind == "ef":
            widx = list(range(0, 72, 9))     # 1本で1周期（71コマ）→8コマ
            aidx = [0, 4, 8, 11, 13, 15, 17, 19, 22, 28, 36, 44, 50, 54, 60, 68]
            ahit, acharge = 6, 3               # 当たり＝17（突き切る）、溜め＝11（剣を上げきった、ぶれの無いコマ）
            slash = {"plane": "v", "r": 2.3, "w": 0.31, "a0": 14.0, "a1": -10.0, "y": 1.2, "life": 0.25, "draw": 0.05}
        else:
            # 前へ進む前半（0〜42）だけ。帽子の位置で横の移動を消し、足裏を待機にそろえる
            hx0 = head_x(W[0])
            fixed = []
            for i in range(0, 43):
                y1, _ = foot_of(W[i])
                fixed.append(shift(W[i], hx0 - head_x(W[i]), ref_y - y1))
            W = fixed
            widx = list(range(0, 42, 5))[:8]
            aidx = [0, 3, 6, 9, 12, 14, 16, 18, 20, 23, 30, 40, 48, 54, 60, 68]
            ahit, acharge = 7, 3               # 当たり＝18（振り下ろし）、溜め＝9（振りかぶり）
            slash = {"plane": "v", "r": 2.1, "w": 0.84, "a0": 120.0, "a1": -50.0, "y": 1.0, "life": 0.33, "draw": 0.07}
        # 足元の基準：横は待機の帽子の位置（歩きはそのコマの帽子）、縦は足裏
        hx_ref = head_x(A[0])
        atl_w = Atlas(f"imp_{kind}_walk.webp")
        for i in widx:
            y1, _ = foot_of(W[i])
            img, foot = crop_scaled(W[i], scale, (head_x(W[i]), y1))   # 横＝帽子、縦＝その コマの足裏
            atl_w.add(img, foot)
        atl_a = Atlas(f"imp_{kind}_atk.webp")
        for i in aidx:
            img, foot = crop_scaled(A[i], scale, (hx_ref, ref_y))   # 待機の帽子の位置と足裏に固定
            atl_a.add(img, foot)
        wf, wsz = atl_w.build(out)
        af, asz = atl_a.build(out)
        h_px = HEIGHT[kind] * PX_PER_M
        # 実時間（秒）：振りかぶり 0.6 倍・当たり後の伸び 0.35 倍・戻り 0.5 倍に詰める。durs は ms×FOE_SPD(2.4)
        SPD = 2.4
        real = []
        for j in range(16):
            gap = ((aidx[j + 1] if j + 1 < 16 else 73) - aidx[j]) / 24.0
            k = 0.6 if j < ahit else (0.35 if aidx[j] < 48 else 0.5)
            real.append(gap * k)
        d0 = [round(r * 1000 * SPD) for r in real]
        r1 = list(real)
        r1[acharge] += 0.55                    # 溜め：振りかぶりで止める
        d1 = [round(r * 1000 * SPD) for r in r1]
        entries[kind] = {
            "walk": {"frames": wf, "h": h_px, "face": 1, "fps": 11},
            "atk0": {"frames": af, "h": h_px, "face": 1, "durs": d0, "hit": ahit},
            "atk1": {"frames": af, "h": h_px, "face": 1, "durs": d1, "hit": ahit,
                     "charge": acharge, "charge_y": 1.55 if kind == "em" else 1.3, "slash": slash},
        }
        print(kind, "scale %.3f" % scale, "walk", wsz, "atk", asz,
              "atk0 %.2fs" % (sum(d0) / 1000 / SPD), "atk1 %.2fs" % (sum(d1) / 1000 / SPD),
              "hit at %.2fs / %.2fs" % (sum(d0[:ahit]) / 1000 / SPD, sum(d1[:ahit]) / 1000 / SPD))
        if prev:
            os.makedirs(prev, exist_ok=True)
            for nm, atl in (("walk", atl_w), ("atk", atl_a)):
                cells = []
                for img, (fx, fy) in atl.items:
                    c = np.zeros((560, 900, 4), np.uint8)
                    c[..., :3] = (40, 44, 56); c[..., 3] = 255
                    ox, oy = int(300 - fx), int(520 - fy)
                    h, w = img.shape[:2]
                    sx0, sy0 = max(0, -ox), max(0, -oy)
                    sx1, sy1 = min(w, 900 - ox), min(h, 560 - oy)
                    src = img[sy0:sy1, sx0:sx1].astype(np.float32)
                    dst = c[oy + sy0:oy + sy1, ox + sx0:ox + sx1, :3].astype(np.float32)
                    al = src[..., 3:4] / 255
                    c[oy + sy0:oy + sy1, ox + sx0:ox + sx1, :3] = (src[..., :3] * al + dst * (1 - al)).astype(np.uint8)
                    c[520, :, :3] = (0, 255, 120); c[:, 300, :3] = (0, 255, 120)
                    cells.append(c)
                n = len(cells); cols = 4
                sheet = np.zeros((560 * ((n + cols - 1) // cols), 900 * cols, 4), np.uint8)
                for k, c in enumerate(cells):
                    sheet[560 * (k // cols):560 * (k // cols + 1), 900 * (k % cols):900 * (k % cols + 1)] = c
                Image.fromarray(sheet).convert("RGB").resize((sheet.shape[1] // 2, sheet.shape[0] // 2)).save(f"{prev}/{kind}_{nm}.png")
    fj = os.path.join(out, "foe.json")
    d = json.load(open(fj))
    d.update(entries)
    json.dump(d, open(fj, "w"), ensure_ascii=False, separators=(",", ":"))
    print("foe.json updated:", list(entries))


if __name__ == "__main__":
    main()
