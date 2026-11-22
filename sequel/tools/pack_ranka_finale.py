"""tools/bake_ranka_finale.gd で焼いたコマ（光＝黒地の加算、抜き＝透明地の通常合成）を、1枚のアトラス（straight alpha の RGBA）にする。
Skill naraku-vfx の 7. の pack と同じ考え：光は「RGB の最大値＝不透明度、色は割り戻し」、抜きは premultiplied を割り戻し、光を抜きの上に重ね、上の回（花びら）をいちばん上に。
ゲームでは Sprite3D（通常の合成。自前のシェーダーを使わない＝iPhone で確実）でめくるだけ。
使い方：python3 -I sequel/tools/pack_ranka_finale.py（リポジトリのルートで）
出力：sequel/assets/vfx/ranka/seq_<名前>.png（1コマ 512×288、COLS 列）と seq_ranka.json
"""
import os, glob, json
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/vfx_bake")
OUT = os.path.join(ROOT, "assets/vfx/ranka")      # ランカの連番（al2）
OUT2 = os.path.join(ROOT, "assets/vfx/seq")       # ラナ・リリィの連番（fx1。2026-11-12）
RANKA = {"quake", "ama"}
CELL = (512, 288)
COLS = 8
meta = {"note": "ランカの大技の締め（tools/bake_ranka_finale.gd → pack_ranka_finale.py）。1コマ 512×288＝16m×9m（32px＝1m）、中心（ランカの胸）＝(256,150)、地面＝中心の 1.3m 下。fps 30。炸裂は 0.25 秒（7.5 コマ目）",
        "cell": CELL, "cols": COLS, "fps": 30, "px_per_m": 32, "center": [256, 150], "hit_s": 0.25, "seq": {}}
for name in sorted(os.listdir(SRC)):
    d = os.path.join(SRC, name)
    if not os.path.isdir(d):
        continue
    lights = sorted(glob.glob(os.path.join(d, "light_*.png")))
    darks = sorted(glob.glob(os.path.join(d, "dark_*.png")))
    tops = sorted(glob.glob(os.path.join(d, "top_*.png")))
    n = len(lights)
    rows = (n + COLS - 1) // COLS
    atlas = Image.new("RGBA", (CELL[0] * COLS, CELL[1] * rows))
    white = []
    for i in range(n):
        L = np.asarray(Image.open(lights[i]).convert("RGB")).astype(np.float32) / 255
        D = np.asarray(Image.open(darks[i]).convert("RGBA")).astype(np.float32) / 255
        la = L.max(axis=2, keepdims=True)                    # 光：明るさ＝不透明度（加算を通常の合成で再現）
        da = D[..., 3:4]
        dp = D[..., :3]                                      # 抜き：viewport は premultiplied で出る
        a = la + da * (1 - la)
        prem = L + dp * (1 - la)
        if tops:   # 上の回（花びら）を光の上に
            T = np.asarray(Image.open(tops[i]).convert("RGBA")).astype(np.float32) / 255
            ta = T[..., 3:4]
            ts = np.clip(T[..., :3] / np.maximum(ta, 1e-4), 0, 1)
            prem = ts * ta + prem * (1 - ta)
            a = ta + a * (1 - ta)
        rgb = np.where(a > 1e-4, prem / np.maximum(a, 1e-4), 0)
        im = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)]) * 255).astype(np.uint8), "RGBA").resize(CELL, Image.LANCZOS)
        atlas.paste(im, ((i % COLS) * CELL[0], (i // COLS) * CELL[1]))
        white.append(int((L.min(axis=2) > 0.92).sum()))
    od = OUT if name in RANKA else OUT2
    os.makedirs(od, exist_ok=True)
    p = os.path.join(od, "seq_%s.png" % name)
    atlas.save(p, optimize=True)
    meta["seq"][name] = {"frames": n, "rows": rows, "file": ("res://assets/vfx/ranka/" if name in RANKA else "res://assets/vfx/seq/") + "seq_%s.png" % name}
    print(name, n, "コマ", atlas.size, os.path.getsize(p) // 1024, "KB", "白い画素（光の回、最大）", max(white))
json.dump(meta, open(os.path.join(OUT2, "seq.json"), "w"), ensure_ascii=False, indent=1)   # 目録は本体（fx1）に置く
