"""新リリィの連番（make_lily2.py の出力）を、ゲーム用のアトラス（可逆 WebP）にまとめる。
使い方：python3 -I sequel/tools/pack_lily.py   （リポジトリのルートで。先に make_lily2.py を流す）
出力：sequel/assets/lily/lily_<n>.webp・lily.json
  clips.<名前> = {fps, frames:[[ページ, x, y, w, h, 足元から見た左上 x, y]], hits:[当たりのコマ…], reach:[前への届き m…], end_dx（最後のコマの体の前進 m）}
  idle＝戦闘の立ち絵 1 枚（歩き・走りの動画が届くまで、移動もこれを揺らして使う）
決まり（2026-11-06）：
  - 大きさ：ラナ（assets/rana の待機 366px＝1.85m）と同じ画素の細かさにそろえる＝構えの背 BODY_PX。元の連番（art/lily2/frames）は元の大きさのまま。
  - 歩き・走り：make_lily2 が探した 1 周（loop）を 24 コマのまま、体の横のずれ（dx）を消してその場で。
  - コマ：攻撃は 1 秒 12 コマに間引き（ゲームでは 2 倍の速さで流す）。
  - 色が崩れたコマ（BAD）は、近くの正常なコマで置き換える（チャットで番号を示して判定待ち）。
  - 当たり（HITS で上書きできる）：前への届き（足元から絵の前の端まで）の山を自動で探す。構えより 0.30 背 以上前に出た山で、山の 92% に届いた最初のコマ。
"""
import json, os
import numpy as np
from PIL import Image

ROOT = os.getcwd()
SRC = os.path.join(ROOT, "sequel/art/lily2")
OUT = os.path.join(ROOT, "sequel/assets/lily")
HEIGHT_M = 1.80                 # 2026-11-06 ユーザー決定（ゲームで 1.62・1.70・1.78 を並べて判定）
BODY_PX = round(366 * HEIGHT_M / 1.85)   # ラナと同じ画素の細かさ
STEP = 2                         # 24fps → 12fps
PAGE = 4096
RANGE = {"hit": (8, 34)}   # 使うコマの範囲（元の24コマ単位）。被弾＝揺れている所だけ
HITS = {"atk_rush": [23], "atk_heeldrop": [9, 28]}   # 自動で外れたもの（12コマ単位）：rush＝飛び蹴りの山、heeldrop＝振り下ろし
BAD = {"atk_heeldrop": [13, 14, 17, 19, 21, 100, 101, 102], "atk_roundhouse": [9, 10, 11, 13, 14], "atk_rush": [42]}


def load(clip, fn):
    return Image.open(os.path.join(SRC, "frames", clip, fn))


class Packer:
    def __init__(self):
        self.pages, self.x, self.y, self.row = [Image.new("RGBA", (PAGE, PAGE))], 0, 0, 0

    def add(self, im):
        w, h = im.size
        if self.x + w > PAGE:
            self.x, self.y, self.row = 0, self.y + self.row + 2, 0
        if self.y + h > PAGE:
            self.pages.append(Image.new("RGBA", (PAGE, PAGE)))
            self.x = self.y = self.row = 0
        p = len(self.pages) - 1
        self.pages[p].alpha_composite(im, (self.x, self.y))
        r = (p, self.x, self.y)
        self.x += w + 2
        self.row = max(self.row, h)
        return r


def main():
    meta = json.load(open(os.path.join(SRC, "lily2.json")))
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("lily_") and (f.endswith(".webp") or f.endswith(".import")):
            os.remove(os.path.join(OUT, f))
    pk = Packer()
    out = {"height_m": HEIGHT_M, "body_px": BODY_PX, "clips": {}}
    # 立ち絵（戦闘）
    st = meta["stills"]["stance_battle"]
    im = Image.open(os.path.join(SRC, "stance", "stance_battle.png"))
    box = (st["left"] - 4, st["top"] - 4, st["right"] + 5, st["bottom"] + 1)
    im = im.crop(box)
    s = BODY_PX / st["body_h"]
    cx = (st["left"] + st["right"]) / 2
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    p, x, y = pk.add(im)
    out["clips"]["idle"] = {"fps": 1, "frames": [[p, x, y, im.width, im.height, round((box[0] - cx) * s, 1), -im.height]],
                            "hits": [], "reach": [], "end_dx": 0.0}
    for clip, c in meta["clips"].items():
        s = BODY_PX / c["body_h"]
        bad = set(BAD.get(clip, []))
        n = len(c["frames"])
        good = [i for i in range(n) if i not in bad]
        lp = c.get("loop")
        if lp:   # 歩き・走り：1 周だけ、24 コマのまま、体の横のずれを消してその場に
            picks = list(range(lp["start"], lp["start"] + lp["len"]))
        else:
            picks = []
            r0, r1 = RANGE.get(clip, (0, n))
            for i in range(r0, r1, STEP):
                j = i if i not in bad else min(good, key=lambda g: (abs(g - i), g))
                picks.append(j)
        frames, reach = [], []
        for j in picks:
            fn, w, h, ox, oy, dx = c["frames"][j]
            if lp:
                ox -= dx
            im = load(clip, fn)
            w2, h2 = max(1, round(w * s)), max(1, round(h * s))
            im = im.resize((w2, h2), Image.LANCZOS)
            p, x, y = pk.add(im)
            frames.append([p, x, y, w2, h2, round(ox * s, 1), round(oy * s, 1)])
            reach.append((ox + w) * s)
        # 当たり：前への届きの山
        base = reach[0]
        thr = base + 0.30 * BODY_PX
        hits, i = [], 0
        while i < len(reach):
            if reach[i] > thr:
                j = i
                while j + 1 < len(reach) and reach[j + 1] > thr:
                    j += 1
                seg = reach[i:j + 1]
                pk_v = max(seg)
                k = next(t for t, v in enumerate(seg) if v >= pk_v * 0.92 + base * 0.08)
                if not hits or i + k - hits[-1] >= 6:
                    hits.append(i + k)
                i = j + 1
            else:
                i += 1
        hits = [] if (lp or clip in RANGE) else HITS.get(clip, hits)
        px_m = HEIGHT_M / BODY_PX
        out["clips"][clip] = {"fps": 24 if lp else 24 / STEP, "frames": frames, "hits": hits,
                              "reach": [round((reach[h] - base) * px_m + 0.6, 2) for h in hits],
                              "end_dx": round(c["frames"][picks[-1]][5] * s * px_m, 2), "replaced": sorted(bad)}
        print(clip, len(frames), "コマ、当たり", hits, "届き", out["clips"][clip]["reach"], "最後の前進", out["clips"][clip]["end_dx"], "m")
    for i, pg in enumerate(pk.pages):
        bb = pg.getbbox()
        pg = pg.crop((0, 0, bb[2], bb[3]))
        pg.save(os.path.join(OUT, "lily_%d.webp" % i), lossless=True, quality=100, method=6)
        out.setdefault("pages", []).append("lily_%d.webp" % i)
        print("page", i, pg.size, os.path.getsize(os.path.join(OUT, "lily_%d.webp" % i)) // 1024, "KB")
    json.dump(out, open(os.path.join(OUT, "lily.json"), "w"), ensure_ascii=False)
    import subprocess, sys   # つま先の点（軌跡の元）を書き足す（2026-11-06、specs/lily_attack_fx.md）
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "sequel/tools/lily_tips.py")], check=True)


if __name__ == "__main__":
    main()
