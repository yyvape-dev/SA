"""裏の町の届いた絵（art/painted_bt_src）を、ゲームで置ける形に切り抜く（2026-11-08、specs/backtown_entrance_v2.md の 13）。
マゼンタを抜く（terrain/tools/key_soft.py の ①背景色からの距離でアルファ ②アンミックス ③縁の赤紫の抑え を使う。
ただし key_soft の「いちばん大きな塊だけ残す」と「緑・紫を灰へ寄せる」はキャラの切り抜き用で、部品のシートでは部品が消え、緑のネオンが灰になる＝外した）→ 部品のシートは塊ごとに切り出す → art/painted_bt/<名前>.png（RGBA、縮めない）。
部品の実寸（m）は main.gd 側のデータで決める（ここでは画素だけ）。使い方：python3 -I sequel/tools/cut_bt.py
"""
import os, sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art/painted_bt_src")
OUT = os.path.join(ROOT, "art/painted_bt")
os.makedirs(OUT, exist_ok=True)


def key_sheet(a, t0=50, t1=135):
    a = a.astype(np.float32)
    bg = np.median(np.concatenate([a[:16, :16].reshape(-1, 3), a[:16, -16:].reshape(-1, 3), a[-16:, :16].reshape(-1, 3), a[-16:, -16:].reshape(-1, 3)]), axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    al = np.clip((d - t0) / (t1 - t0), 0, 1)
    al = np.clip(ndi.gaussian_filter(al, 0.5), 0, 1)
    al = np.where(al < 0.04, 0, al)
    a2 = np.where(al[..., None] > 0.01, (a - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.01), a)
    a2 = np.clip(a2, 0, 255)
    edge = (al > 0) & (al < 0.95)
    mn = np.minimum(a2[..., 0], a2[..., 2])
    ex = np.clip(mn - a2[..., 1], 0, None) * edge * 0.7
    a2[..., 0] -= ex
    a2[..., 2] -= ex
    return np.dstack([a2, al * 255]).astype(np.uint8)


def keyed(name):
    return key_sheet(np.asarray(Image.open(os.path.join(SRC, name + ".png")).convert("RGB")))


def save(arr, name):
    Image.fromarray(arr).save(os.path.join(OUT, name + ".png"), optimize=True)
    return [int(arr.shape[1]), int(arr.shape[0])]


def pieces(rgba, min_area=1500):
    m = rgba[..., 3] > 40
    lab, n = ndi.label(ndi.binary_closing(m, iterations=3))
    out = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        if sl is None:
            continue
        area = int((lab[sl] == i + 1).sum())
        if area < min_area:
            continue
        out.append((sl[0].start, sl[1].start, sl[0].stop, sl[1].stop))
    return out


meta = {}
# 壁 w3（画面を消した版）：外周のマゼンタを抜くだけ（1536×1024 のまま。下絵の窓＝棟の中心 ±3.75m × 0〜5m）
w3 = keyed("w3_vision_off")
meta["w3_vision_off"] = save(w3, "w3_vision_off")
# ビジョンの中身：最初の絵 w3_vision_v1 の画面の部分（下絵の画面 x 0.2〜4.6m・y 2.6〜5.0m → 窓の画素）
v1 = np.asarray(Image.open(os.path.join(SRC, "w3_vision_v1.png")).convert("RGB"))
ppm = 1536 / 7.5
x0, x1 = int((0.2 - (2.3 - 3.75)) * ppm), int((4.6 - (2.3 - 3.75)) * ppm)
y0, y1 = 0, int((5.0 - 2.6) * ppm)
scr = np.dstack([v1[y0:y1, x0:x1], np.full((y1 - y0, x1 - x0), 255, np.uint8)])
meta["vision_screen"] = save(scr, "vision_screen")
# 屋台 3 種：塊を 1 つ切り出す（下絵は 1m＝約 380px）
for s in ["stall_food", "stall_crystal", "stall_parts"]:
    k = keyed(s)
    ys, xs = np.where(k[..., 3] > 40)
    meta[s] = save(k[ys.min():ys.max() + 1, xs.min():xs.max() + 1], s)
# 部品のシート：塊ごとに（左上から右下の順）
for sheet, names in [("glow_props", ["sign_sigil", "sign_vneon", "sign_rune"]),
                     ("overhead_props", ["pend_cyan", "pend_violet", "pend_green", "pend_warm", "banner_red", "banner_violet"]),
                     ("foreground_props", ["fg_pillar", "fg_pillar_lamp", "fg_crate", "fg_crates"])]:
    k = keyed(sheet)
    ps = pieces(k)
    ps.sort(key=lambda b: (round(b[0] / 250), b[1]))   # 段ごと→左から
    if sheet == "glow_props":   # 並び：左上 横長（魔方陣）、左下 小（ルーン）、右 縦（ネオン）
        ps.sort(key=lambda b: (b[1] > 700, b[0]))
        order = {0: "sign_sigil", 1: "sign_rune", 2: "sign_vneon"}
        names = [order[i] for i in range(len(ps))]
    print(sheet, len(ps), "塊", ps)
    for nm, b in zip(names, ps):
        meta[nm] = save(k[b[0]:b[2], b[1]:b[3]], nm)
# 路地の奥の書き割り：対応表の dst_box（1024 角のシートの大きさに合わせてから）
om = json.load(open(os.path.join(ROOT, "art/guide_bt/order/order_map.json")))["orders"]["back_alleys"]
ba = Image.open(os.path.join(SRC, "back_alleys.png")).convert("RGB")
sh = Image.open(os.path.join(ROOT, "art/guide_bt/order", om["sheet"]))
ba = ba.resize(sh.size, Image.LANCZOS) if ba.size != sh.size else ba
bk = key_sheet(np.asarray(ba))
for p in om["pieces"]:
    x0, y0, x1, y1 = p["dst_box"]
    meta[p["src"]] = save(bk[y0:y1, x0:x1], p["src"])
# 横の壁の素材：そのまま写す（端をなじませるのは後で）
for t in ["tex_brick", "tex_iron", "tex_plaster", "tex_boards"]:
    im = Image.open(os.path.join(SRC, t + ".png")).convert("RGB")
    im.save(os.path.join(OUT, t + ".png"), optimize=True)
    meta[t] = list(im.size)
json.dump(meta, open(os.path.join(OUT, "cut.json"), "w"), ensure_ascii=False, indent=1)
print(json.dumps(meta, ensure_ascii=False))
