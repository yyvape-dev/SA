"""敵 第1弾（9体）の連番を、足元基準のアトラスと json にまとめる。
使い方（リポジトリのルートで）：
  1. 連番を作る（art/enemies/README.md）：cd sequel/art/enemies && SRC=src KEYED=_work/keyed python3 tools/key.py && KEYED=_work/keyed OUT=frames python3 tools/build.py
  2. python3 -I sequel/tools/make_enemies.py
出力：sequel/assets/foe2/foe2.json と <敵>_<n>.webp（可逆。4096 のページ）。

make_foes.py（前作の一般兵 → assets/foe/foe.json）とは別のファイルに書く。make_foes.py を流し直しても消えない。
battle.gd が foe.json と foe2.json の両方を読み、敵の種類（kind）＝敵の名前で同じ形の clip を引く。

json の1コマ：[ページ, x, y, w, h, 足元から見た左上の x, 足元から見た左上の y]（make_foes.py と同じ形）
clip：frames・h（その絵での背の高さ px＝歩き1コマ目の全高）・face（1＝右向き）・fps（歩き）／durs・hit（攻撃）
     fwd＝当たりのコマで、足元から前へいちばん出た所 ÷ h（届く距離の目安。仮）
歩きは 24fps → 12fps、攻撃は 24fps → 8fps に間引く（sa2-ally-add の規格）。
当たりのコマ（hit）は仮：攻撃の中で前へいちばん出たコマ。
"""
import json
import os
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
SRC = ROOT / "sequel/art/enemies/frames"
OUT = ROOT / "sequel/assets/foe2"
PAGE = 4096
PAD = 2
STEP = {"walk": 2, "atk1": 3, "atk2": 3}
WALK_FPS = 12
ATK_MS = 125


# 焼き込まれた軌跡を消す枠（2026-11-20 ユーザー決定：ランサーの攻撃2だけ消す。義足の襲撃者は残す）
# {(敵, 動き): {元のコマ番号（8fpsのコマ×3）: [(x0, y0, x1, y1[, 'all'|明るさのしきい値]), ...]}}、frames/ の px。
# 枠の中の明るいピンク〜黄緑（と白く飛んだ芯）だけを消す。'all'＝体・槍に触れない所で、枠の中を全部消す
FX_BOX = {("mechanical_lancer", "atk2"): {30: [(50, 50, 270, 200)], 33: [(230, 50, 790, 520), (715, 425, 775, 525, 'all')], 36: [(600, 30, 882, 625), (450, 30, 620, 200, 'all')],
          39: [(630, 270, 800, 625), (765, 535, 840, 592, 'all')], 42: [(730, 380, 820, 625)]}}
def erase(im, boxes):
    a = np.asarray(im.convert('RGBA')).copy()
    hsv = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2HSV_FULL).astype(int)
    h, s, v = hsv[..., 0] * 360 // 256, hsv[..., 1], hsv[..., 2]
    fx = (v > 120) & (s > 25) & (((h >= 280) | (h <= 30)) | ((h >= 40) & (h <= 120)))
    fx |= (v > 200) & (s <= 25)   # 白く飛んだ芯
    m = np.zeros(fx.shape, bool)
    k = np.zeros(fx.shape, bool)
    for b in boxes:
        x0, y0, x1, y1 = b[:4]
        m[y0:y1, x0:x1] = True
        mode = b[4] if len(b) > 4 else None
        if mode == 'all':      # 体・槍に触れない所：枠の中を全部消す
            k[y0:y1, x0:x1] = True
        elif mode is not None:  # 明るさのしきい値を下げる
            f2 = (v > mode) & (s > 25) & (((h >= 280) | (h <= 30)) | ((h >= 40) & (h <= 120)))
            k[y0:y1, x0:x1] |= f2[y0:y1, x0:x1]
    k = (k | (fx & m)) & (a[..., 3] > 0)
    k = cv2.dilate(k.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & m
    a[k, 3] = 0
    # 残った薄い縁の粒を消す（小さな島）
    n, lab, st, _ = cv2.connectedComponentsWithStats((a[..., 3] > 0).astype(np.uint8))
    for i in range(1, n):
        if st[i, 4] < 40:
            x, y, w, hh = st[i, :4]
            if m[y:y+hh, x:x+w].any(): a[lab == i, 3] = 0
    return Image.fromarray(a)


def trim(path, boxes=None):
    im = Image.open(path).convert("RGBA")
    if boxes:
        im = erase(im, boxes)
    a = np.asarray(im)[..., 3]
    ys, xs = np.where(a > 0)
    if len(xs) == 0:
        return im.crop((0, 0, 1, 1)), 0, 0
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    return im.crop((x0, y0, x1, y1)), int(x0), int(y0)


def pack(items):
    """棚詰め（高い順）。items: [(key, img)] → {key: (page, x, y)}、ページの絵の一覧"""
    order = sorted(items, key=lambda it: -it[1].height)
    pages, pos = [], {}
    x = y = shelf = 0
    cur = None
    for key, im in order:
        w, h = im.width + PAD, im.height + PAD
        if cur is None or x + w > PAGE:
            x, y, shelf = 0, y + shelf, 0
        if cur is None or y + h > PAGE:
            cur = Image.new("RGBA", (PAGE, PAGE), (0, 0, 0, 0))
            pages.append(cur)
            x = y = shelf = 0
        cur.paste(im, (x, y))
        pos[key] = (len(pages) - 1, x, y)
        x += w
        shelf = max(shelf, h)
    return pages, pos


def main():
    meas = json.loads((SRC / "measure.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    only = [x for x in os.environ.get("ONLY", "").split(",") if x]   # 例：ONLY=mechanical_lancer（その敵だけ作り直す）
    out = json.loads((OUT / "foe2.json").read_text()) if only and (OUT / "foe2.json").exists() else {}
    for old in OUT.glob("*.webp"):
        if not only or any(old.name.startswith(o + "_") for o in only):
            old.unlink()
    for e in sorted(meas):
        if only and e not in only:
            continue
        m = meas[e]
        ax, ay = m["anchor_foot"]
        items, clips = [], {}
        for act in ("walk", "atk1", "atk2"):
            files = sorted((SRC / e).glob(f"{act}_*.png"))
            if not files:
                continue
            files = files[::STEP[act]]
            fr = []
            for f in files:
                im, x0, y0 = trim(f, FX_BOX.get((e, act), {}).get(int(f.stem.split("_")[1])))
                key = f.stem
                items.append((key, im))
                fr.append([key, im.width, im.height, x0 - ax, y0 - ay, int(f.stem.split("_")[1])])
            clips[act] = fr
        pages, pos = pack(items)
        names = []
        for i, pg in enumerate(pages):
            bb = pg.getbbox()
            pg = pg.crop((0, 0, PAGE if bb[2] > PAGE // 2 else bb[2], bb[3]))
            n = f"{e}_{i}.webp"
            pg.save(OUT / n, lossless=True, quality=100, method=6)
            names.append(n)
        walk0 = clips["walk"][0]
        h = -walk0[4]   # 歩き1コマ目：足元から上の端まで
        ec = {}
        for act, fr in clips.items():
            rows = []
            for key, w, hh, ox, oy, src_i in fr:
                p, x, y = pos[key]
                rows.append([names[p], x, y, w, hh, ox, oy])
            c = {"frames": rows, "h": h, "face": 1, "src": [r[5] for r in fr]}
            if act == "walk":
                c["fps"] = WALK_FPS
            else:
                fwd = [r[5] + r[3] for r in rows]
                hit = int(np.argmax(fwd))
                c.update({"durs": [ATK_MS] * len(rows), "hit": hit, "fwd": round(fwd[hit] / h, 3)})
            ec[act] = c
        out[e] = ec
        print(e, len(names), "ページ", {a: (len(c["frames"]), c.get("hit"), c.get("fwd")) for a, c in ec.items()})
    (OUT / "foe2.json").write_text(json.dumps(out, ensure_ascii=False))
    tot = sum(p.stat().st_size for p in OUT.glob("*.webp"))
    print("合計 %.1fMB" % (tot / 1e6))


if __name__ == "__main__":
    main()
