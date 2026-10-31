"""外部AIの白黒の素材 → WebGL のエフェクト用のデータの絵（terrain/assets/fx/）。
帯（band_*）：黒地の帯を切り詰めて 1024×256 に。R＝形の濃さ（白黒の幅を目いっぱいに）、G＝消える順番（帯の芯ほど大きい＝後まで残る）。右端＝刃の頭、左端＝尾。
ノイズ（noise_*）：512×512、半分ずらして混ぜ、継ぎ目なしに。R=G=B。
使い方：python3 terrain/tools/fx_tex_build.py [元フォルダ] [出力フォルダ]
"""
import sys, glob, os
import numpy as np
from PIL import Image, ImageFilter
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), 'fx_src')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', 'assets', 'fx')
os.makedirs(OUT, exist_ok=True)

def levels(a, lo_p=1.0, hi_p=99.7):
    lo, hi = np.percentile(a, lo_p), np.percentile(a, hi_p)
    return np.clip((a - lo) / max(1e-6, hi - lo), 0, 1)

def band(path, name):
    L = np.asarray(Image.open(path).convert('L'), np.float32) / 255
    L = np.clip((L - 0.04) / 0.96, 0, 1)                        # 黒地のかすかなむらを落とす
    ys, xs = np.where(L > 0.06)
    y0, y1 = np.percentile(ys, [0.3, 99.7]).astype(int); x0, x1 = xs.min(), xs.max()
    m = 6; y0, y1, x0, x1 = max(0, y0 - m), min(L.shape[0], y1 + m), max(0, x0 - m), min(L.shape[1], x1 + m)
    c = Image.fromarray((L[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((1024, 256), Image.LANCZOS)
    R = levels(np.asarray(c, np.float32) / 255, 0, 99.5)
    core = np.asarray(Image.fromarray((R * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    G = np.clip(0.65 * levels(core, 0, 99.5) + 0.35 * R, 0, 1)
    Image.fromarray(np.dstack([R, G, np.zeros_like(R)]).__mul__(255).astype(np.uint8)).save(os.path.join(OUT, name + '.png'), optimize=True)
    print(name, 'crop', (x0, y0, x1, y1), 'cover', round(float((R > .1).mean()), 3))

def noise(path, name, N=512):
    a = np.asarray(Image.open(path).convert('L').resize((N, N), Image.LANCZOS), np.float32) / 255
    b = np.roll(np.roll(a, N // 2, 0), N // 2, 1)
    t = np.abs(np.arange(N) / (N - 1) - .5) * 2; w = np.maximum(t[None, :], t[:, None]); w = np.clip((w - .55) / .45, 0, 1); w = w * w * (3 - 2 * w)
    o = a * (1 - w) + b * w                                     # 縁は、ずらした方（縁が中ほどにある絵）に寄せる
    o = levels(o)
    Image.fromarray((o * 255).astype(np.uint8)).convert('RGB').save(os.path.join(OUT, name + '.png'), optimize=True)
    print(name, 'mean', round(float(o.mean()), 3))

for p in sorted(glob.glob(os.path.join(SRC, '*.png'))):
    n = os.path.splitext(os.path.basename(p))[0]
    (band if n.startswith('band_') else noise)(p, n)
