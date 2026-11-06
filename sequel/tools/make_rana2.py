"""新ラナの動画（sequel/art/rana2/src/*.mp4、マゼンタ背景・右向き・24fps）を、透過 PNG の連番にする。
使い方：python3 -I sequel/tools/make_rana2.py [作業フォルダ]   （リポジトリのルートで。ffmpeg・numpy・scipy・opencv・PIL）
      ゲーム用のアトラスだけ作り直す：python3 -I sequel/tools/make_rana2.py --game  → sequel/assets/rana2/
出力：
  sequel/art/rana2/frames/<clip>/<clip>_NN.png … 元の大きさのまま（縮めない）。コマごとに余白を切り詰める
  sequel/art/rana2/rana2.json                   … クリップごとのコマ：[ファイル, w, h, 足元から見た左上の x, y, 体の横の移動 dx]
  sequel/art/rana2/check/*.png                  … 元の動画のコマと、抜いた絵（暗い背景）を同じ大きさで並べた比較・足元の線
手順（video-to-sprite-pipeline）：
  1. 背景抜き：四隅の色からの距離でアルファ。体の縁は最も近い不透明な画素の色（マゼンタのにじみを消す）、
     体から離れた半透明（焼き込みの光・軌跡）は背景色を差し引いて元の光の色を戻す（まず抜いて試す。汚ければコードで描き直す）。
  2. 色ずれ：黄緑〜緑とピンク（マゼンタのにじみ）を、上半身（髪・袖）は金、下半身（靴・裾）はくすんだ茶へ（fix_green）。この絵に緑は無い。胸の宝石の青緑（150 以上）は残す。
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
WORK = [a for a in sys.argv[1:] if not a.startswith("--")][0] if [a for a in sys.argv[1:] if not a.startswith("--")] else os.path.join(ROOT, "sequel/art/rana2/_work")
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
    """色ずれを戻す。上半身（髪・袖）は金、下半身（靴・裾）はくすんだ茶。
    緑：色相 62〜110・彩度 0.15 以上（淡いものは 52〜）。ピンク：色相 285〜340・彩度 0.12 以上（上半身は全部＝髪の筋、下半身は縁 6px だけ）。
    事実：atkC の袖・軌跡の縁が黄緑、run の靴がオリーブ、髪の筋と靴の縁にマゼンタのにじみ。服の紫（〜275）・赤（〜10）は対象外。"""
    rgb = np.ascontiguousarray(rgba[..., :3])
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    h = hsv[..., 0].astype(np.float32) * 2
    s = hsv[..., 1] / 255.0
    op = rgba[..., 3] > 0
    ys = np.where(rgba[..., 3] > 128)[0]
    upper = np.zeros(op.shape, bool)
    if len(ys):
        upper[: int(ys.min() + 0.45 * (ys.max() - ys.min())), :] = True
    edge = ndi.distance_transform_edt(rgba[..., 3] > 200) <= 6
    green = (((h > 62) & (h < 110) & (s > 0.15)) | ((h > 52) & (h <= 62) & (s > 0.12) & (s < 0.45))) & op
    pink = (h >= 285) & (h <= 340) & (s > 0.12) & op & (upper | edge | ((h >= 300) & (h <= 345) & (s > 0.25)))   # 下半身も鮮やかなピンク（靴）は直す
    to_gold = (green | pink) & upper
    to_brown = (green | pink) & ~upper
    hsv[..., 0] = np.where(to_gold, 20, np.where(to_brown, 15, hsv[..., 0]))   # 金 40°／茶 30°
    sat = hsv[..., 1].astype(np.float32)
    sat = np.where(pink & upper, sat * 0.6, np.where(to_brown, sat * 0.5, sat))
    hsv[..., 1] = sat.astype(np.uint8)
    out = rgba.copy()
    out[..., :3] = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    return out, int((to_gold | to_brown).sum())


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


if __name__ == "__main__" and "--game" not in sys.argv and "--cutin" not in sys.argv:
    main()


# ---------- ゲーム用（--game）：frames/ から間引き・前進の分離・光の削除・足裏・縮小・アトラス ----------
GAME_OUT = os.path.join(ROOT, "sequel/assets/rana2")
GAME_SCALE = 430 / 717       # 構えの背 717px → 430px（2026-11-06：366px は iPhone で約1.28倍に引き伸ばされて荒かった。カメラ 35％なら画面で約410画素）
# 名前: (連番, 使う元のコマ, 再生の fps, 前進を位置へ, 体から離れた光の扱い)
#   光："keep"＝残す、"gold"＝金の軌跡だけ残す（白い弧・きらめきは消してコードで描く）、"none"＝全部消す（土煙）
GAME_CLIPS = {
    "idle": ("atkA_thrust", [0], 1, False, "none"),
    "walk": ("walk", list(range(0, 31, 2)), 12, False, "none"),
    "run": ("run", list(range(0, 18)), 24, False, "none"),
    "atkA": ("atkA_thrust", list(range(0, 73, 3)), 24, True, "none"),
    "atkB": ("atkB_downslash", list(range(0, 73, 3)), 24, True, "none"),
    "atkC": ("atkC_flurry", list(range(0, 73, 3)), 24, True, "gold"),
    "hold": ("atkHold_spin", list(range(0, 121, 3)), 24, True, "gold"),
    "hurt": ("hit", [8, 10, 12], 8, False, "none"),
    "down": ("down", list(range(0, 73, 2)), 20, False, "none"),
    "flurry": ("spare_combo", list(range(0, 73, 2)), 24, True, "gold"),   # スキル「乱れ斬り」（37コマ＝約1.54秒、specs/skill_ui.md）
}


def strip_lights(rgba, mode):
    """体（不透明の最大のかたまり＋6px）から離れた画素を消す。gold なら金の色だけ残す。none は体に重なる淡いピンクの煙も消す"""
    if mode == "keep":
        return rgba
    a = rgba[..., 3]
    lab, n = ndi.label(a > 240)   # 体＝ほぼ不透明の最大のかたまり（半透明の煙・にじみは体に入れない）
    if n == 0:
        return rgba
    sizes = ndi.sum(a > 240, lab, range(1, n + 1))
    body = ndi.binary_dilation(lab == (int(np.argmax(sizes)) + 1), iterations=2)
    out = rgba.copy()
    hsv = cv2.cvtColor(np.ascontiguousarray(rgba[..., :3]), cv2.COLOR_RGB2HSV)
    h = hsv[..., 0].astype(np.float32) * 2
    s = hsv[..., 1] / 255.0
    gold = (h >= 25) & (h <= 65) & (s > 0.35)
    drop = ~body & (a > 0)
    if mode == "gold":
        drop &= ~gold
    else:   # 土煙：体に重なる淡いピンク〜灰の半透明も消す
        drop |= body & (a < 215) & (((h >= 280) & (h <= 350)) | (s < 0.12))
    out[..., 3] = np.where(drop, 0, a)
    return out


def build_game():
    meta = json.load(open(os.path.join(OUT, "rana2.json")))
    os.makedirs(GAME_OUT, exist_ok=True)
    for f in os.listdir(GAME_OUT):
        if f.endswith(".webp") or f.endswith(".json"):
            os.remove(os.path.join(GAME_OUT, f))
    k = GAME_SCALE
    pieces = []   # (clip, i, image, ox, oy, root)
    report = []
    for name, (src, idx, fps, root, lights) in GAME_CLIPS.items():
        fr = meta["clips"][src]["frames"]
        imgs = []
        for i in idx:
            fn, w, h, ox, oy, dx = fr[i]
            im = np.asarray(Image.open(os.path.join(OUT, "frames", src, fn)).convert("RGBA"))
            im = strip_lights(im, lights)
            ys, xs = np.where(im[..., 3] > 0)
            x0, y0 = xs.min(), ys.min()
            im = im[y0:ys.max() + 1, x0:xs.max() + 1]
            ox += x0
            oy += y0
            if root:
                ox -= dx     # 前進は絵から外し、位置の移動（root）にする
            imgs.append([im, ox, oy, dx if root else 0.0])
        # 足裏：歩きは毎コマ地面へ。走りは全体をずらして一番低いコマを地面へ
        if name == "walk":
            for it in imgs:
                it[2] = -it[0].shape[0]
        elif name == "run":
            lift = min(-(it[2] + it[0].shape[0]) for it in imgs)
            for it in imgs:
                it[2] += lift
        for i, (im, ox, oy, dx) in enumerate(imgs):
            pil = Image.fromarray(im)
            pil = pil.resize((max(1, round(pil.width * k)), max(1, round(pil.height * k))), Image.LANCZOS)
            pieces.append((name, i, pil, ox * k, oy * k, dx * k))
        report.append("%s %dコマ %dfps" % (name, len(imgs), fps))
    # 棚詰めのアトラス（2048×2048）
    order = sorted(range(len(pieces)), key=lambda j: -pieces[j][2].height)
    pages, cur, x, y, row_h = [], None, 0, 0, 0
    place = {}
    for j in order:
        im = pieces[j][2]
        w, h = im.width + 2, im.height + 2
        if cur is None or x + w > 2048:
            x, y, row_h = 0, y + row_h, 0
        if cur is None or y + h > 2048:
            cur = Image.new("RGBA", (2048, 2048), (0, 0, 0, 0))
            pages.append(cur)
            x, y, row_h = 0, 0, 0
        cur.paste(im, (x + 1, y + 1))
        place[j] = (len(pages) - 1, x + 1, y + 1)
        x += w
        row_h = max(row_h, h)
    names = []
    for p, pg in enumerate(pages):
        bb = pg.getbbox()
        pg = pg.crop((0, 0, 2048, bb[3] + 1))
        fn = "rana2_%d.webp" % p
        pg.save(os.path.join(GAME_OUT, fn), lossless=True, quality=100, method=6)
        names.append(fn)
    clips = {}
    for j, (name, i, im, ox, oy, dx) in enumerate(pieces):
        c = clips.setdefault(name, {"fps": GAME_CLIPS[name][2], "frames": [], "root": []})
        p, px, py = place[j]
        c["frames"].append([names[p], px, py, im.width, im.height, round(ox, 1), round(oy, 1)])
        c["root"].append(round(dx, 1))
    idle_h = pieces[0][2].height
    json.dump({"px_h": idle_h, "face": 1, "pages": names, "clips": clips},
              open(os.path.join(GAME_OUT, "rana2.json"), "w"), ensure_ascii=False)
    sz = sum(os.path.getsize(os.path.join(GAME_OUT, n)) for n in names)
    print("ゲーム用：%d コマ、ページ %d 枚（%s）、%.1fMB、構えの背 %dpx" % (len(pieces), len(pages), ", ".join("%dx%d" % (2048, Image.open(os.path.join(GAME_OUT, n)).height) for n in names), sz / 1e6, idle_h))
    print("  " + " / ".join(report))


if __name__ == "__main__" and "--game" in sys.argv:
    build_game()


# ---------- 必殺技のカットイン（--cutin）：戦闘の立ち絵を背景抜きして元の大きさのまま可逆 WebP に ----------
def build_cutin():
    rgb = np.asarray(Image.open(os.path.join(SRC, "stance_battle.png")).convert("RGB"))
    im, _ = fix_green(key(rgb))
    ys, xs = np.where(im[..., 3] > 0)
    im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(im).save(os.path.join(GAME_OUT, "cutin.webp"), lossless=True, quality=100, method=6)
    print("カットイン", im.shape[1], "x", im.shape[0], "（縮めない）")


if __name__ == "__main__" and "--cutin" in sys.argv:
    build_cutin()
