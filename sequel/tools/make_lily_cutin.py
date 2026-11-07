"""リリィの必殺技のカットイン（2026-11-07）：戦闘の立ち絵（art/lily2/stance/stance_battle.png、背景抜き済み）を、
縮めずに余白だけ切って可逆 WebP にする → assets/lily/cutin.webp（地区 pck al1 に入る）。
使い方：python3 -I sequel/tools/make_lily_cutin.py"""
import os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
im = Image.open(os.path.join(ROOT, "art/lily2/stance/stance_battle.png")).convert("RGBA")
bb = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
im = im.crop(bb)
out = os.path.join(ROOT, "assets/lily/cutin.webp")
im.save(out, lossless=True, quality=100, method=6)
print(out, im.size, os.path.getsize(out))
