"""新ラナの動画（sequel/art/rana2/src/*.mp4、マゼンタ背景・右向き・24fps）を、透過 PNG の連番にする。
使い方：python3 -I sequel/tools/make_rana2.py [作業フォルダ]   （リポジトリのルートで。ffmpeg・numpy・scipy・opencv・PIL）
出力：
  sequel/art/rana2/frames/<clip>/<clip>_NN.png … 元の大きさのまま（縮めない）。コマごとに余白を切り詰める
  sequel/art/rana2/rana2.json                   … クリップごとのコマ：[ファイル, w, h, 足元から見た左上の x, y, 体の横の移動 dx]
  sequel/art/rana2/check/*.png                  … 元の動画のコマと、抜いた絵（暗い背景）を同じ大きさで並べた比較・足元の線
手順（video-to-sprite-pipeline）：
  1. 背景抜き：四隅の色からの距離でアルファ。体の縁は最も近い不透明な画素の色（マゼンタのにじみを消す）、
     体から離れた半透明（焼き込みの光・軌跡）は背景色を差し引いて元の光の色を戻す（まず抜いて試す。汚ければコードで描き直す）。
  2. 色ずれ：黄緑〜緑（色相 62〜110・彩度 0.15 以上）を金（色相 45）へ。この絵に緑は無い。胸の宝石の青緑（150 以上）は残す。
     事実：atkC で袖・手袋・軌跡の縁が黄緑になっていた（README は「髪」としていたが、測ると袖と軌跡）。
  3. 大きさ：頭の照合で全クリップ 1.0 倍（±0.05〜0.1）→ 補正しない。
  4. 足元：各クリップの最初のコマ（構え）の足元＝原点。攻撃の前進などの体の移動はそのまま絵の位置に残す（dx に記録）。
     足裏の高さはそろえない（浮いているコマは測った値を check に出して判断する）。
  5. 繰り返し：walk＝31 コマ周期（差 6.8、ほかの周期は 10 以上）。run＝19〜36 コマ目の 18 コマ（体の横の移動を消してその場で走る。
     つなぎ目の差 15.7 ＜ となりのコマの差 20.8）。回避は走りを流用（残像はコード）。
"""
import json, os, subprocess, sys
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.getcwd()
SRC = os.path.join(ROOT, "sequel/art/rana2/src")
OUT = os.path.join(ROOT, "sequel/art/rana2")
WORK = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "sequel/art/rana2/_work")
GROUND_Y = 783          # 構えの足裏（動画の y）
LOOPS = {"walk": ("walk", 0, 31, False), "run": ("run_dodge", 19, 18, True)}   # 名前: (動画, 最初のコマ, コマ数, その場にする)
ONESHOT = ["atkA_thrust", "atkB_downslash", "atkC_flurry", "atkHold_spin", "hit", "down", "spare_spinkick", "spare_combo"]


def frames(clip):
    d = os.path.join(WORK, "frames", clip)
    if not os.path.isdir(d):
        os.makedirs(d)
        subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SRC, clip + ".mp4"), os.path.join(d, "%03d.png")], check=True)
    return [np.asarray(Image.open(os.path.join(d, f)).convert("RGB")) for f in sorted(os.listdir(d))]


def key(rgb):
    a = rgb.astype(np.float32)
    bg = np.mean([a[:20, :20], a[:20, -20:], a[-20:, :20], a[-20:, -20:]], axis=(0, 1, 2))
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    al = np.clip((d - 45) / (130 - 45), 0, 1)
    core = al >= 0.98
    dist, idx = ndi.distance_transform_edt(~core, return_distances=True, return_indices=True)
    near = a[idx[0], idx[1]]
    unmix = np.clip((a - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.05), 0, 255)
    edge = dist <= 3   # 体の縁：近くの不透明な色。離れた半透明（光）：背景を差し引いた色
    col = np.where(core[..., None], a, np.where(edge[..., None], near, unmix))
    al = np.where(al < 0.12, 0, al)
    return np.dstack([col, al * 255]).astype(np.uint8)


def fix_green(rgba):
    rgb = np.ascontiguousarray(rgba[..., :3])
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    h = hsv[..., 0].astype(np.float32) * 2
    s = hsv[..., 1] / 255.0
    m = (h > 62) & (h < 110) & (s > 0.15) & (rgba[..., 3] > 0)
    hsv[..., 0] = np.where(m, 45 // 2 + 1, hsv[..., 0])
    out = rgba.copy()
    out[..., :3] = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    return out, int(m.sum())


def body_x(rgba):
    m = rgba[..., 3] > 128
    ys, xs = np.where(m)
    return float(np.median(xs)) if len(xs) else 0.0


def anchor_x(rgba):
    m = rgba[..., 3] > 128
    ys, xs = np.where(m)
    bot = ys.max()
    return float(np.median(xs[ys > bot - 40]))


def save_clip(name, imgs, ax, inplace):
    d = os.path.join(OUT, "frames", name)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    meta = []
    bx0 = body_x(imgs[0])
    for i, im in enumerate(imgs):
        dx = body_x(im) - bx0
        sx = -dx if inplace else 0.0
        a = im[..., 3]
        ys, xs = np.where(a > 0)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = im[y0:y1, x0:x1]
        fn = "%s_%02d.png" % (name, i)
        Image.fromarray(crop).save(os.path.join(d, fn), optimize=True)
        meta.append([fn, int(x1 - x0), int(y1 - y0), round(float(x0 - ax + sx), 1), int(y0 - GROUND_Y), round(dx, 1)])
    return meta


def check_sheet(name, raw, imgs, picks, ax):
    """元の動画のコマ（上）と抜いた絵（下、暗い背景＋足元の線）を、同じ大きさで並べる"""
    xs, ys = [], []
    for i in picks:
        y, x = np.where(imgs[i][..., 3] > 0)
        xs += [x.min(), x.max()]; ys += [y.min(), y.max()]
    x0, x1, y0, y1 = max(0, min(xs) - 10), min(raw[0].shape[1], max(xs) + 10), max(0, min(ys) - 10), min(raw[0].shape[0], max(ys) + 10)
    w, h = x1 - x0, y1 - y0
    sheet = Image.new("RGB", (w * len(picks), h * 2), (0, 0, 0))
    for j, i in enumerate(picks):
        sheet.paste(Image.fromarray(raw[i][y0:y1, x0:x1]), (j * w, 0))
        bg = Image.new("RGBA", (w, h), (34, 30, 48, 255))
        bg.alpha_composite(Image.fromarray(imgs[i][y0:y1, x0:x1]))
        arr = np.asarray(bg.convert("RGB")).copy()
        gy = GROUND_Y - y0
        if 0 <= gy < h:
            arr[gy, :] = (60, 220, 255)          # 地面（構えの足裏）
        gx = int(ax) - x0
        if 0 <= gx < w:
            arr[:, gx] = (255, 210, 80)          # 構えの足元
        sheet.paste(Image.fromarray(arr), (j * w, h))
    os.makedirs(os.path.join(OUT, "check"), exist_ok=True)
    sheet.save(os.path.join(OUT, "check", name + ".png"))


def main():
    os.makedirs(WORK, exist_ok=True)
    meta = {"ground_y": GROUND_Y, "fps_src": 24, "face": 1, "scale": 1.0, "clips": {}}
    report = []
    jobs = [(n, *LOOPS[n]) for n in LOOPS] + [(c, c, 0, None, False) for c in ONESHOT]
    for name, clip, start, count, inplace in jobs:
        raw = frames(clip)
        raw = raw[start:start + count] if count else raw
        imgs, fixed = [], 0
        for r in raw:
            k, n = fix_green(key(r))
            imgs.append(k)
            fixed += n
        ax = anchor_x(imgs[0])
        meta["clips"][name] = {"src": clip, "start": start, "anchor_x": round(ax, 1), "loop": count is not None,
                               "frames": save_clip(name, imgs, ax, inplace)}
        picks = [int(i * (len(imgs) - 1) / 5) for i in range(6)]
        check_sheet(name, raw, imgs, picks, ax)
        bots = [GROUND_Y - int(np.where(im[..., 3] > 128)[0].max()) for im in imgs]
        report.append("%s：%d コマ、緑→金 %d 画素、足裏の浮き 最大 %dpx（地面より上が＋）" % (name, len(imgs), fixed, max(bots)))
    # 立ち絵（静止画。元から透過）
    for st in ["stance_battle", "stance_normal"]:
        im = Image.open(os.path.join(SRC, st + ".png")).convert("RGBA")
        a = np.asarray(im)
        ys, xs = np.where(a[..., 3] > 0)
        meta["clips"][st] = {"src": st + ".png", "size": list(im.size), "body_h": int(ys.max() - ys.min() + 1)}
    json.dump(meta, open(os.path.join(OUT, "rana2.json"), "w"), ensure_ascii=False, indent=1)
    print("\n".join(report))


if __name__ == "__main__":
    main()
