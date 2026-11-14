#!/usr/bin/env python3
"""動画AIの敵の動画（歩き1本＋攻撃1〜3本）→ 敵の連番アトラス＋foe.json の項目（汎用）。

使い方:
  python3 -I sequel/tools/make_foes.py <kind> <背の高さm> <向き:L|R> <歩き.mp4> <攻撃1.mp4> [攻撃2.mp4 ...] [--charge] [--preview DIR]
- 背景のマゼンタを抜き、白い軌跡は赤に（make_imperial_foes.key）。紫の軌跡（色相 235〜300・彩度 0.5 超）も赤へ回す。
- 歩きは 8 コマ（1本で1周期の前提、帽子・頭の位置で横の移動を消す）。攻撃は 16 コマ（当たり＝いちばん前へ伸びたコマ、前 7・後 8）。
- 攻撃が1本だけのとき --charge で、同じコマの溜めの型（atk1：当たりの前で 0.55 秒止めて赤い光→赤い弧）を足す。
- 大きさはラナの画面の密度（431px＝1.85m）。
"""
import json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_imperial_foes import frames_of, key, foot_of, head_x, Atlas, crop_scaled, standing_h, PX_PER_M

SPD = 2.4


def purple_to_red(rgba):
    a = rgba[..., :3].astype(np.float32) / 255
    mx, mn = a.max(-1), a.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    hue = np.where(mx == r, (g - b) / np.maximum(mx - mn, 1e-6) % 6, np.where(mx == g, (b - r) / np.maximum(mx - mn, 1e-6) + 2, (r - g) / np.maximum(mx - mn, 1e-6) + 4)) * 60
    sel = (hue >= 235) & (hue <= 300) & (s > 0.5) & (mx > 0.4) & (rgba[..., 3] > 0)
    out = rgba.copy()
    v = mx[sel]
    out[..., 0][sel] = (v * 255).clip(0, 255).astype(np.uint8)
    out[..., 1][sel] = (v * 255 * (1 - s[sel]) * 0.9).clip(0, 255).astype(np.uint8)
    out[..., 2][sel] = (v * 255 * (1 - s[sel]) * 0.8).clip(0, 255).astype(np.uint8)
    return out


def main():
    argv = sys.argv[1:]
    prev = None
    if "--preview" in argv:
        i = argv.index("--preview"); prev = argv[i + 1]; del argv[i:i + 2]
    charge = "--charge" in argv
    argv = [a for a in argv if a != "--charge"]
    kind, height, facing, wpath, apaths = argv[0], float(argv[1]), argv[2], argv[3], argv[4:]
    face = -1 if facing.upper() == "L" else 1
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "foe")
    W = [purple_to_red(key(a)) for a in frames_of(wpath)]
    As = [[purple_to_red(key(a)) for a in frames_of(p)] for p in apaths]
    A0 = As[0][0]
    ref_y, _ = foot_of(A0)
    scale = height * PX_PER_M / standing_h(A0)
    h_px = height * PX_PER_M
    entry = {}
    # 歩き：1本＝1周期として 8 コマ。横は頭の位置、縦はそのコマの足裏
    n = len(W)
    atl = Atlas(f"foe_{kind}_walk.webp")
    for i in [round(k * (n - 1) / 8) for k in range(8)]:
        y1, _ = foot_of(W[i])
        img, ft = crop_scaled(W[i], scale, (head_x(W[i]), y1))
        atl.add(img, ft)
    wf, wsz = atl.build(out)
    entry["walk"] = {"frames": wf, "h": h_px, "face": face, "fps": 11}
    sizes = [("walk", wsz)]
    previews = [("walk", atl)]
    for ai, A in enumerate(As):
        hx_ref = head_x(A[0])
        n = len(A)
        # 当たり＝前へいちばん伸びたコマ（不透明の外接矩形の前端）
        front = []
        for a in A:
            xs = np.where((a[..., 3] > 128).any(0))[0]
            front.append(-xs.min() if face < 0 else xs.max())
        hf = int(np.argmax(front))
        hf = max(8, min(hf, n - 10))
        idx = [round(k * (hf - 1) / 6) for k in range(7)] + [hf] + [round(hf + 2 + k * (n - 1 - hf - 2) / 7) for k in range(8)]
        atl = Atlas(f"foe_{kind}_atk{ai}.webp")
        for i in idx:
            img, ft = crop_scaled(A[i], scale, (hx_ref, ref_y))
            atl.add(img, ft)
        af, asz = atl.build(out)
        hit = 7
        real = []
        for j in range(16):
            gap = ((idx[j + 1] if j + 1 < 16 else n) - idx[j]) / 24.0
            real.append(gap * (0.6 if j < hit else (0.35 if j < 11 else 0.5)))
        d = [round(r * 1000 * SPD) for r in real]
        entry[f"atk{ai}"] = {"frames": af, "h": h_px, "face": face, "durs": d, "hit": hit}
        sizes.append((f"atk{ai}", asz, "hit@%.2fs/%.2fs" % (sum(real[:hit]), sum(real)), "src hit f%d" % hf))
        previews.append((f"atk{ai}", atl))
        if charge and len(As) == 1:
            r1 = list(real); r1[5] += 0.55
            entry["atk1"] = {"frames": af, "h": h_px, "face": face, "durs": [round(r * 1000 * SPD) for r in r1], "hit": hit,
                             "charge": 5, "charge_y": 1.4,
                             "slash": {"plane": "v", "r": 2.1, "w": 0.6, "a0": 60.0, "a1": -20.0, "y": 1.15, "life": 0.3, "draw": 0.06}}
    print(kind, "scale %.3f" % scale, sizes)
    fj = os.path.join(out, "foe.json")
    dj = json.load(open(fj))
    dj[kind] = entry
    json.dump(dj, open(fj, "w"), ensure_ascii=False, separators=(",", ":"))
    if prev:
        os.makedirs(prev, exist_ok=True)
        for nm, atl in previews:
            cells = []
            for img, (fx, fy) in atl.items:
                c = np.zeros((560, 1000, 3), np.uint8); c[:] = (40, 44, 56)
                ox, oy = int(600 - fx), int(520 - fy)
                h, w = img.shape[:2]
                sx0, sy0 = max(0, -ox), max(0, -oy); sx1, sy1 = min(w, 1000 - ox), min(h, 560 - oy)
                src = img[sy0:sy1, sx0:sx1].astype(np.float32); al = src[..., 3:4] / 255
                dst = c[oy + sy0:oy + sy1, ox + sx0:ox + sx1].astype(np.float32)
                c[oy + sy0:oy + sy1, ox + sx0:ox + sx1] = (src[..., :3] * al + dst * (1 - al)).astype(np.uint8)
                c[520, :] = (0, 255, 120); c[:, 600] = (0, 255, 120)
                cells.append(c)
            cols = 4; rows = (len(cells) + cols - 1) // cols
            sh = np.zeros((560 * rows, 1000 * cols, 3), np.uint8)
            for k, c in enumerate(cells):
                sh[560 * (k // cols):560 * (k // cols + 1), 1000 * (k % cols):1000 * (k % cols + 1)] = c
            Image.fromarray(sh).resize((sh.shape[1] // 3, sh.shape[0] // 3)).save(f"{prev}/{kind}_{nm}.png")


if __name__ == "__main__":
    main()
