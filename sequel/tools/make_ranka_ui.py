"""ランカの HUD の顔（2026-11-12）：カットインの立ち絵（assets/ranka/cutin.webp）から顔を丸く切って 114px に。
t6_portrait.png（リリィ）と同じ大きさ・丸。使い方：python3 -I sequel/tools/make_ranka_ui.py（リポジトリのルートで）"""
import os
from PIL import Image, ImageDraw
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
im = Image.open(os.path.join(ROOT, "assets/ranka/cutin.webp")).convert("RGBA")
cx, cy, r = 205, 135, 125          # 顔の中心と半径（立ち絵の画素。チャットで目視）
face = im.crop((cx - r, cy - r, cx + r, cy + r))
bg = Image.new("RGBA", face.size, (18, 20, 34, 255))
bg.alpha_composite(face)
mask = Image.new("L", face.size, 0)
ImageDraw.Draw(mask).ellipse((2, 2, face.width - 3, face.height - 3), fill=255)
bg.putalpha(mask)
out = bg.resize((114, 114), Image.LANCZOS)
p = os.path.join(ROOT, "assets/ui/t6/t6_ranka_portrait.png")
out.save(p)
print(p, out.size)
