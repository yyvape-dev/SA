"""新リリィの素材（sequel/art/lily2/src/、マゼンタ背景・右向き）を透過 PNG にする。
使い方：python3 -I sequel/tools/make_lily2.py   （リポジトリのルートで。numpy・scipy・matplotlib・PIL）
素材：立ち絵 2 枚（stance_normal 1024×1536・stance_battle 1248×1664）と攻撃の動画 5 本（24fps、atk_jabkick だけ 784×1168、ほかは 720×960）。
  atk_jabkick＝突き→上段蹴り（3秒）／atk_highkick＝短い上段蹴り（3.9秒）／atk_roundhouse＝膝上げ→回し蹴り（5秒、白い光の焼き込み）／
  atk_heeldrop＝振り上げ→かかと落とし→しゃがみ→立つ（5秒）／atk_rush＝踏み込み→飛び蹴り（白い光）→着地→立つ（5秒）。
  動画のコマ：python3 -I sequel/tools/make_lily2.py [作業フォルダ]（ffmpeg も要る）
出力：
  sequel/art/lily2/stance/<名前>.png … 元の大きさのまま透過（縮めない・切り詰めない）
  sequel/art/lily2/check/<名前>.png  … 元絵｜暗い背景｜明るい背景 を同じ大きさで並べ、下に髪・手袋・靴の拡大
  sequel/art/lily2/frames/<clip>/<clip>_NN.png … 元の大きさのまま、コマごとに余白を切り詰め（git に入れない。作り直せる）
  sequel/art/lily2/check/<clip>.png   … 元の動画のコマ（上）と抜いた絵（下、暗い背景＋地面の線＋構えの足元の線）
  sequel/art/lily2/lily2.json        … 立ち絵：大きさ・体の高さ・足裏の y。クリップ：コマ [ファイル, w, h, 足元から見た左上 x, y, 体の横の移動 dx]、
                                       構えの背の高さ body_h（動画ごとに大きさが違うので、ゲームではこれで合わせる）
背景抜き：terrain/tools/key_soft.py（背景色からの距離でアルファ・アンミックス・縁の赤紫を抑える・離れた粒を消す）。
色：リリィは銀髪・黒の上着・紺のチェック・茶のタイツ・金の飾り・青い宝石。key_soft の「はっきりした緑・紫を灰へ」は
  チェックの紺（色相 220〜250）に掛からない。銀髪の縁はマゼンタを拾いやすい → 縁 4px の赤紫を追加で抑える（fix_fringe）。
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.getcwd()
sys.path.insert(0, os.path.join(ROOT, "terrain/tools"))
from key_soft import key_soft  # noqa: E402

SRC = os.path.join(ROOT, "sequel/art/lily2/src")
OUT = os.path.join(ROOT, "sequel/art/lily2")
STILLS = ["stance_normal", "stance_battle"]
CLIPS = ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush"]
WORK = sys.argv[1] if len(sys.argv) > 1 else os.path.join(OUT, "_work")


def video_frames(clip):
    d = os.path.join(WORK, "frames", clip)
    if not os.path.isdir(d):
        os.makedirs(d)
        subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SRC, clip + ".mp4"), os.path.join(d, "%03d.png")], check=True)
    return [np.asarray(Image.open(os.path.join(d, f)).convert("RGB")) for f in sorted(os.listdir(d))]


def body_x(rgba):
    xs = np.where(rgba[..., 3] > 128)[1]
    return float(np.median(xs)) if len(xs) else 0.0


def anchor_x(rgba):
    ys, xs = np.where(rgba[..., 3] > 128)
    return float(np.median(xs[ys > ys.max() - 40]))


def do_clip(clip):
    raw = video_frames(clip)
    imgs, fixed, drift = [], 0, [0, 0]
    for f in raw:
        c = key_soft(f.astype(np.float32))
        c, n = fix_fringe(c)
        c, ng, nm = fix_drift(c)
        imgs.append(c); fixed += n; drift[0] += ng; drift[1] += nm
    ys0 = np.where(imgs[0][..., 3] > 128)[0]
    ground, top = int(ys0.max()), int(ys0.min())
    bx0 = body_x(imgs[0])
    ax = bx0   # 構えの足元＝構えの体の中心（足の幅の中ほど）
    d = os.path.join(OUT, "frames", clip)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    fr = []
    for i, im in enumerate(imgs):
        ys, xs = np.where(im[..., 3] > 0)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        fn = "%s_%02d.png" % (clip, i)
        Image.fromarray(im[y0:y1, x0:x1]).save(os.path.join(d, fn), optimize=True)
        fr.append([fn, int(x1 - x0), int(y1 - y0), round(float(x0 - ax), 1), int(y0 - ground), round(body_x(im) - bx0, 1)])
    picks = [int(i * (len(imgs) - 1) / 7) for i in range(8)]
    clip_check(clip, raw, imgs, picks, ground, ax)
    bots = [ground - int(np.where(im[..., 3] > 128)[0].max()) for im in imgs]
    info = {"src": clip + ".mp4", "size": [raw[0].shape[1], raw[0].shape[0]], "count": len(imgs), "ground_y": ground,
            "anchor_x": round(ax, 1), "body_h": ground - top + 1, "fringe_fixed": fixed, "drift_green": drift[0], "drift_purple": drift[1],
            "lift_max": max(bots), "dx_range": [min(f[5] for f in fr), max(f[5] for f in fr)], "frames": fr}
    print(clip, {k: v for k, v in info.items() if k != "frames"})
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
        if 0 <= int(ax) - x0 < w:
            arr[:, int(ax) - x0] = (255, 210, 80)
        sheet.paste(Image.fromarray(arr), (j * w, h))
    sheet.save(os.path.join(OUT, "check", name + ".png"))


def fix_fringe(rgba):
    """縁（不透明の内側 4px＋半透明）に残る赤紫だけを、近くの不透明な画素の色へ寄せる。"""
    a = rgba.astype(np.float32)
    al = a[..., 3] / 255
    solid = al > 0.97
    dist = ndi.distance_transform_edt(solid)
    edge = (al > 0) & (dist <= 6)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # R と B が G より高い＝マゼンタのにじみ。銀髪は R≧G≧B なので、B が G を少しでも超えたら色ずれとみなす
    pink = edge & (r - g > 8) & (b - g > 6)
    inner = solid & (dist > 3) & ~((r - g > 8) & (b - g > 6))
    _, idx = ndi.distance_transform_edt(~inner, return_indices=True)
    near = a[idx[0], idx[1], :3]
    a[..., :3] = np.where(pink[..., None], near, a[..., :3])
    return a.astype(np.uint8), int(pink.sum())


def fix_drift(rgba):
    """動画の色ずれを戻す（立ち絵には使わない）。リリィに緑・紫は無い。
    緑〜黄緑（色相 58〜170・彩度 0.10 以上、または 48〜58 の暗いオリーブ＝明るさ 0.45 未満）→ 色相 35（髪・タイツの暖かい灰茶）、彩度 0.7 倍。
    紫〜マゼンタ（色相 262〜338・彩度 0.15 以上）→ 色相 30、彩度 0.3 倍（黒い革・手袋・靴に出る）。
    紺のチェック（220〜250）・金（40〜55）・肌と唇の赤（340〜20）は対象外。"""
    import matplotlib.colors as mc
    a = rgba.astype(np.float32)
    hs = mc.rgb_to_hsv(a[..., :3] / 255)
    h, sat = hs[..., 0] * 360, hs[..., 1]
    on = a[..., 3] > 0
    v = hs[..., 2]
    g = on & (((h >= 58) & (h <= 170) & (sat >= 0.10)) | ((h >= 48) & (h < 58) & (v < 0.45) & (sat > 0.25)))  # 暗いオリーブも（金は明るい）
    m = on & (h >= 262) & (h <= 338) & (sat >= 0.15)
    hs[..., 0] = np.where(g, 35 / 360, np.where(m, 30 / 360, hs[..., 0]))
    hs[..., 1] = np.where(g, sat * 0.7, np.where(m, sat * 0.3, sat))
    a[..., :3] = mc.hsv_to_rgb(hs) * 255
    return a.astype(np.uint8), int(g.sum()), int(m.sum())


def board(rgba, col):
    bg = np.zeros_like(rgba[..., :3], dtype=np.float32) + np.array(col, np.float32)
    al = rgba[..., 3:4].astype(np.float32) / 255
    return (rgba[..., :3] * al + bg * (1 - al)).astype(np.uint8)


def check(name, raw, cut, info):
    h, w = raw.shape[:2]
    row = np.concatenate([raw, board(cut, (24, 20, 32)), board(cut, (225, 225, 225))], axis=1)
    # 拡大：髪の上・いちばん下（靴）・体の中ほどの縁（手袋）を 3 倍
    al = cut[..., 3] > 128
    t, btm = info["top"], info["bottom"]
    hx = np.where(al[t + 40])[0]                       # 髪：頭の上から 40px の行の左端
    by = np.where(al[:, :al.shape[1] // 2].any(1))[0].max()  # 左半分のいちばん下＝後ろ足の靴
    bx = np.where(al[by - 60])[0].min()
    fy = t + (btm - t) // 4; fx = np.where(al[fy])[0].max()  # 体の上 1/4 の行の右端＝手袋・拳
    boxes = [(t - 10, hx.min() - 40), (by - 130, bx - 40), (fy - 75, fx - 160)]
    crops = []
    for y0, x0 in boxes:
        y0 = int(np.clip(y0, 0, h - 150)); x0 = int(np.clip(x0, 0, w - 200))
        for src in (raw, board(cut, (24, 20, 32)), board(cut, (225, 225, 225))):
            c = Image.fromarray(src[y0:y0 + 150, x0:x0 + 200]).resize((600, 450), Image.NEAREST)
            crops.append(np.asarray(c))
    per = row.shape[1] // 3
    lines = []
    for i in range(3):
        seg = np.concatenate(crops[i * 3:i * 3 + 3], axis=1)
        lines.append(np.asarray(Image.fromarray(seg).resize((row.shape[1], int(450 * row.shape[1] / 1800)))))
    out = np.concatenate([row] + lines, axis=0)
    # 足裏の線（赤）
    out[info["bottom"], :] = (255, 40, 40)
    Image.fromarray(out).save(os.path.join(OUT, "check", name + ".png"))


def main():
    os.makedirs(os.path.join(OUT, "stance"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "check"), exist_ok=True)
    meta = {"note": "新リリィ（2026-11-06）。右向き。立ち絵は元の大きさのまま透過", "stills": {}}
    for st in STILLS:
        raw = np.asarray(Image.open(os.path.join(SRC, st + ".png")).convert("RGB"))
        cut = key_soft(raw.astype(np.float32))
        cut, npink = fix_fringe(cut)
        Image.fromarray(cut).save(os.path.join(OUT, "stance", st + ".png"), optimize=True)
        ys, xs = np.where(cut[..., 3] > 128)
        info = {"size": [raw.shape[1], raw.shape[0]], "top": int(ys.min()), "bottom": int(ys.max()),
                "left": int(xs.min()), "right": int(xs.max()), "body_h": int(ys.max() - ys.min() + 1),
                "fringe_fixed": npink,
                "semi_px": int(((cut[..., 3] > 0) & (cut[..., 3] < 250)).sum())}
        meta["stills"][st] = info
        check(st, raw, cut, info)
        print(st, info)
    meta["clips"] = {c: do_clip(c) for c in CLIPS}
    json.dump(meta, open(os.path.join(OUT, "lily2.json"), "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
