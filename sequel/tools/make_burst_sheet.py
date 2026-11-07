"""粒子の混ぜ撒きの仮のシート（2026-11-07、specs/vfx_recipes.md）。素材が届いたら同じ形（4×4、1マス 64px、透明の背景）で差し替える。
並び：1段目＝丸い光の粒、2段目＝細い閃き（縦長。速さの向きにそろえる）、3〜4段目＝花びら（回転＋横幅の伸縮）。
色は白だけ：明るさ＝芯（白く残す所）、透明度＝形。色はゲームが粒ごとに付ける。
使い方：python3 -I sequel/tools/make_burst_sheet.py"""
import os, math
from PIL import Image, ImageDraw, ImageFilter
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = 64
sheet = Image.new("RGBA", (C * 4, C * 4), (0, 0, 0, 0))

def cell(draw_fn, blur=1.2):
    a = Image.new("L", (C * 4, C * 4), 0)       # 4 倍で描いて縮める（縁をなめらかに）
    core = Image.new("L", (C * 4, C * 4), 0)
    draw_fn(ImageDraw.Draw(a), ImageDraw.Draw(core))
    a = a.resize((C, C), Image.LANCZOS).filter(ImageFilter.GaussianBlur(blur))
    core = core.resize((C, C), Image.LANCZOS).filter(ImageFilter.GaussianBlur(blur * 1.5))
    lum = Image.eval(core, lambda v: 110 + v * 145 // 255)   # 縁 110（色が乗る）〜 芯 255（白）
    return Image.merge("RGBA", (lum, lum, lum, a))

S = C * 4
cx = cy = S // 2
shapes = []
for r in [0.16, 0.22, 0.28, 0.34]:   # 丸い粒
    R = int(S * r)
    shapes.append(lambda d, k, R=R: (d.ellipse([cx - R, cy - R, cx + R, cy + R], 255), k.ellipse([cx - R // 3, cy - R // 3, cx + R // 3, cy + R // 3], 255)))
for w, h in [(0.05, 0.42), (0.07, 0.36), (0.04, 0.46), (0.09, 0.3)]:   # 細い閃き（縦長のひし形）
    W, H = int(S * w), int(S * h)
    shapes.append(lambda d, k, W=W, H=H: (d.polygon([(cx, cy - H), (cx + W, cy), (cx, cy + H), (cx - W, cy)], 255),
                                         k.polygon([(cx, cy - H * 2 // 3), (cx + W // 3, cy), (cx, cy + H * 2 // 3), (cx - W // 3, cy)], 255)))
def petal(d, k, w, h, bend):
    pts = []
    for i in range(41):
        t = i / 40 * math.pi
        x = math.sin(t) * w * (1 - 0.35 * math.cos(t))
        y = -math.cos(t) * h
        pts.append((cx + x + bend * math.sin(t) ** 2, cy + y))
    pts += [(cx - x + bend * math.sin(t) ** 2, cy + y) for (x, y, t) in
            [(math.sin(i / 40 * math.pi) * w * (1 - 0.35 * math.cos(i / 40 * math.pi)), -math.cos(i / 40 * math.pi) * h, i / 40 * math.pi) for i in range(40, -1, -1)]]
    d.polygon(pts, 255)
    k.ellipse([cx - w // 4, cy - h // 3, cx + w // 4, cy + h // 3], 255)
for w, h, b in [(0.2, 0.34, 0), (0.16, 0.38, 10), (0.24, 0.3, -12), (0.18, 0.4, 20), (0.22, 0.32, 6), (0.14, 0.36, -18), (0.26, 0.34, 0), (0.2, 0.42, 14)]:
    shapes.append(lambda d, k, w=int(S * w), h=int(S * h), b=b * 2: petal(d, k, w, h, b))
for i, fn in enumerate(shapes):
    sheet.alpha_composite(cell(fn), ((i % 4) * C, (i // 4) * C))
out = os.path.join(ROOT, "assets/fx/burst_sheet.png")
sheet.save(out)
print(out, sheet.size)
