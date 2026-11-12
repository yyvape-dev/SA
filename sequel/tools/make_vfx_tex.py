"""外部AIの白黒のエフェクト素材（黒地・白黒・中に濃淡）を、3D の板（scripts/tex_fx.gdshader、fx.gd の tex_quad）用の絵にする（2026-11-12、ランカ）。
使い方：python3 -I sequel/tools/make_vfx_tex.py（リポジトリのルートで）。元：sequel/art/vfx_src/ranka/・shared/（git に入れる。.gdignore で Godot は読まない）
出力：sequel/assets/vfx/shared/<名前>.png（キャラ共通。地区 pck fx1）と assets/vfx/ranka/petals.png（ランカ専用。al2）（RGBA。RGB＝明るさ〈芯ほど明るい＝侵食で後まで残る〉、A＝形。WebGL2 で L8 は出ないので RGBA）
  - 余白は切り詰め、形の外接に 4% の余白。長い辺を MAX_PX に縮める（縦横比は保つ。板の縦横は tex_quad の aspect で合わせる）。
  - petals は 4×2 のマスを 1 枚ずつ切り、256px の正方形に置いた 4×2 のシート（1024×512）。Sprite3D の hframes 4・vframes 2。
"""
import os, json
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/vfx_src/ranka")
SRC2 = os.path.join(ROOT, "art/vfx_src/shared")   # 2026-11-12 ラナ・リリィ用に追加（GPT）
OUT = os.path.join(ROOT, "assets/vfx/shared")
OUT_RK = os.path.join(ROOT, "assets/vfx/ranka")
MAX_PX = {"ring": 768, "flare": 512, "pillar": 768, "ki_band": 1024, "burst": 768, "band_blade": 1024, "band_ink": 1024, "band_smash": 1024,
          "rift": 1024, "vortex": 768, "bolt_h": 1024, "bolt_v": 768, "plasma": 768}
BLACK = 10   # これ以下は背景（GPT の黒は真っ黒でないことがある）


def to_rgba(g):
    a = np.clip((g.astype(np.float32) - BLACK) / (255 - BLACK), 0, 1)
    rgb = np.clip(g.astype(np.float32) * 1.0, 0, 255)
    return np.dstack([rgb, rgb, rgb, a * 255]).astype(np.uint8)


def trim(g, pad=0.04):
    ys, xs = np.where(g > BLACK + 6)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    p = int(max(y1 - y0, x1 - x0) * pad)
    return g[max(0, y0 - p):y1 + p, max(0, x0 - p):x1 + p]


def main():
    os.makedirs(OUT, exist_ok=True)
    info = {}
    for name, mx in MAX_PX.items():
        src = os.path.join(SRC, name + ".png")
        if not os.path.exists(src):
            src = os.path.join(SRC2, name + ".png")
        g = np.asarray(Image.open(src).convert("L"))
        g = trim(g)
        im = Image.fromarray(to_rgba(g))
        s = mx / max(im.size)
        if s < 1:
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
        info[name] = {"size": im.size, "aspect": round(im.width / im.height, 3)}
    # 花びら：4×2 のマスごとに切り、形の中心で 256 の正方形へ
    g = np.asarray(Image.open(os.path.join(SRC, "petals.png")).convert("L"))
    H, W = g.shape
    sheet = Image.new("RGBA", (1024, 512))
    for r in range(2):
        for c in range(4):
            cell = g[r * H // 2:(r + 1) * H // 2, c * W // 4:(c + 1) * W // 4]
            cell = trim(cell, 0.06)
            im = Image.fromarray(to_rgba(cell))
            s = 240 / max(im.size)
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
            sheet.alpha_composite(im, (c * 256 + (256 - im.width) // 2, r * 256 + (256 - im.height) // 2))
    sheet.save(os.path.join(OUT_RK, "petals.png"), optimize=True)
    info["petals"] = {"size": [1024, 512], "hframes": 4, "vframes": 2}
    json.dump(info, open(os.path.join(OUT, "vfx_shared.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(info, ensure_ascii=False))


if __name__ == "__main__":
    main()
