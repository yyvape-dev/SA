# 画像AI（GPT）が描いた地割れ・えぐれ跡（透過 PNG の色の絵）を、WebGL のデカールの素材にする。Skill sa-battle-fx-check の「表現の約束」。
# 出力：<名前>_col.webp（色と透明度。縁のゴミを掃除）と <名前>_dat.png（シェーダー用のデータ：R＝深さ〈閉じる順〉、G＝現れる順、B＝割れの溝〈光る所〉）
# 使い方（リポジトリ直下で）:
#   python3 battle/tools/decal_import.py <入力.png> <名前> radial   … 中心から放射（クレーター。現れる順＝中心からの距離）
#   python3 battle/tools/decal_import.py <入力.png> <名前> line     … 左→右に走る跡（えぐれ跡。現れる順＝左からの位置。右が踏み込み）
#   出力先は terrain/assets/fx/。radial は 1024 角、line は 1536×512 に収める。
import sys, numpy as np
from PIL import Image, ImageFilter

src, name, kind = sys.argv[1], sys.argv[2], sys.argv[3]
im = Image.open(src).convert('RGBA'); a = np.asarray(im).astype(np.float32)
al = a[..., 3]
# 1) 縁のゴミ：ほぼ透明な画素（透明度 < 48）は捨てる（画像AIの透過で、ここに赤・黄の色が残る）。残りの透明度は広げ直す
al = np.clip((al - 48) / (255 - 48), 0, 1)
# 2) 縁の色のにじみ：半透明の画素の色を、近くの不透明な色で置き換える（白・黒・赤のふちを出さない）
opq = al > 0.85; rgb = a[..., :3].copy()
blur_w = Image.fromarray((opq * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)); bw = np.asarray(blur_w, np.float32) / 255
blur_c = np.stack([np.asarray(Image.fromarray((a[..., i] * opq).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), np.float32) for i in range(3)], -1)
fill = blur_c / np.maximum(bw[..., None], 1e-3); semi = (al > 0) & ~opq
rgb[semi] = fill[semi]
# 3) 中身の範囲で切り抜き、決まった大きさに
ys, xs = np.where(al > 0); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
pad = 8; y0, x0 = max(0, y0 - pad), max(0, x0 - pad); y1, x1 = min(al.shape[0], y1 + pad), min(al.shape[1], x1 + pad)
col = np.dstack([rgb, al[..., None] * 255])[y0:y1, x0:x1]
W, H = (1024, 1024) if kind == 'radial' else (1536, 512)
ci = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), 'RGBA'); h0, w0 = ci.size[1], ci.size[0]
s = min(W / w0, H / h0); ci = ci.resize((max(1, int(w0 * s)), max(1, int(h0 * s))), Image.LANCZOS)
out = Image.new('RGBA', (W, H), (0, 0, 0, 0)); out.paste(ci, ((W - ci.size[0]) // 2, (H - ci.size[1]) // 2)); out.save(f'terrain/assets/fx/{name}_col.webp', 'WEBP', quality=92, method=6)
o = np.asarray(out).astype(np.float32); A = o[..., 3] / 255; lum = (o[..., 0] * .3 + o[..., 1] * .59 + o[..., 2] * .11) / 255
# 4) データの絵
# R＝深さ：縁から内へ（縮めながら重ねる）。細い所・縁から先に閉じる
m = Image.fromarray((A > 0.5).astype(np.uint8) * 255); acc = np.zeros_like(A); cur = m; K = 12
for k in range(K): acc += np.asarray(cur, np.float32) / 255; cur = cur.filter(ImageFilter.MinFilter(3))
R = np.clip(acc / K * 1.4, 0, 1) * (A > 0.02)
# G＝現れる順：放射＝中心からの距離（＋むら）、走る跡＝左からの位置
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
nz = np.asarray(Image.effect_noise((W, H), 60).filter(ImageFilter.GaussianBlur(6)), np.float32) / 255
if kind == 'radial':
    cy, cx = (yy * A).sum() / A.sum(), (xx * A).sum() / A.sum(); d = np.hypot(xx - cx, yy - cy); G = d / max(1, np.percentile(d[A > 0.5], 99))
else:
    G = xx / W
G = np.clip(G * 0.92 + (nz - 0.5) * 0.12, 0, 1)
# B＝割れの溝：絵の暗い所（割れ目の奥）。ここが光って冷める
B = np.clip((0.42 - lum) / 0.3, 0, 1) * A
dat = np.dstack([R, np.where(A > 0.02, G, 1.0), B]); Image.fromarray((dat * 255).astype(np.uint8), 'RGB').save(f'terrain/assets/fx/{name}_dat.png')
print(name, out.size, '不透明', round(float((A > 0.5).mean()), 3), '溝', round(float((B > 0.3).mean()), 3))
