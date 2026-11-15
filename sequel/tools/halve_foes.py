#!/usr/bin/env python3
"""新しい敵（foe_*・imp_* のアトラスを使う kind）の絵を半分の大きさにする（2026-11-15 ユーザー決定「B を試す」）。
理由：iPhone が熱くなる・地区 pck の読み込みに失敗する。敵の絵は展開後 約840MB（T1 だけで約370MB）あった。
foe.json の frames の矩形・足元・h を同じ倍率にするので、ゲームでの大きさは変わらない。済んだ kind には "res": 0.5 を付け、2回は縮めない。
使い方: python3 -I sequel/tools/halve_foes.py"""
import json, os
from PIL import Image
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fd = os.path.join(root, "assets", "foe")
fj = os.path.join(fd, "foe.json")
d = json.load(open(fj))
K = 0.5
done_files = set()
for kind, clips in d.items():
    files = {f[0] for c in clips.values() if isinstance(c, dict) and "frames" in c for f in c["frames"]}
    if not files or not all(f.startswith(("foe_", "imp_")) for f in files):
        continue
    if all(c.get("res") == K for c in clips.values() if isinstance(c, dict)):
        continue
    for f in files:
        if f in done_files:
            continue
        p = os.path.join(fd, f)
        im = Image.open(p).convert("RGBA").convert("RGBa")
        im = im.resize((max(1, round(im.width * K)), max(1, round(im.height * K))), Image.LANCZOS).convert("RGBA")
        im.save(p, "WEBP", quality=95, method=6)
        done_files.add(f)
    for c in clips.values():
        if not isinstance(c, dict) or "frames" not in c:
            continue
        c["frames"] = [[f[0], round(f[1] * K), round(f[2] * K), max(1, round(f[3] * K)), max(1, round(f[4] * K)), f[5] * K, f[6] * K] for f in c["frames"]]
        c["h"] = c["h"] * K
        c["res"] = K
    print(kind, "→ 半分", sorted(files))
json.dump(d, open(fj, "w"), ensure_ascii=False, separators=(",", ":"))
