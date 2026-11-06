"""リリィの攻撃の各コマから「つま先（攻撃の先端）」の点を測って、assets/lily/lily.json の clip に書き足す。
使い方：python3 -I sequel/tools/lily_tips.py   （リポジトリのルートで。pack_lily.py の後に流す。pack_lily.py の最後でも呼ぶ）
読むのはゲーム用のアトラス（assets/lily/lily_<n>.webp）だけ＝元の連番（git に入らない）が無くても測れる。
出力：clip.tip＝腰からいちばん遠い点（手足の先。軌跡に使う）、tip_f＝前へいちばん遠い点、tip_u＝上へいちばん遠い点（体の前半分の中で）。どちらも [[x, y], …]（m、足元原点、右向き、y は上が＋）。
仕様：sequel/specs/lily_attack_fx.md（軌跡は足の通り道をなぞる）。
"""
import json, os
import numpy as np
from PIL import Image

ROOT = os.getcwd()
D = os.path.join(ROOT, "sequel/assets/lily")


def main():
    j = json.load(open(os.path.join(D, "lily.json")))
    px = float(j["height_m"]) / float(j["body_px"])
    pages = [np.asarray(Image.open(os.path.join(D, p)).convert("RGBA")) for p in j["pages"]]
    for name, c in j["clips"].items():
        if not name.startswith("atk"):
            continue
        tf, tu = [], []
        for f in c["frames"]:
            pg, x, y, w, h, ox, oy = f
            a = pages[int(pg)][int(y):int(y) + int(h), int(x):int(x) + int(w), 3] > 128
            ys, xs = np.where(a)
            fx = (xs + float(ox)) * px            # 足元から前へ（m）
            uy = -(ys + float(oy)) * px           # 足元から上へ（m）
            i = int(np.argmax(fx + uy * 0.05))    # 前へいちばん遠い（同じなら高い方）
            tf.append([round(float(fx[i]), 3), round(float(uy[i]), 3)])
            front = fx > 0.15                     # 体の前半分で、上へいちばん遠い（髪・頭を拾わないよう前側だけ）
            if front.any():
                k = np.where(front)[0][int(np.argmax(uy[front] + fx[front] * 0.3))]
                tu.append([round(float(fx[k]), 3), round(float(uy[k]), 3)])
            else:
                tu.append(tf[-1])
        c["tip_f"], c["tip_u"] = tf, tu
        # 腰（足元から 0.95m）からいちばん遠い点＝手足の先（頭は腰に近いので拾わない）。軌跡にはこれを使う
        th = []
        for f in c["frames"]:
            pg, x, y, w, h, ox, oy = f
            a = pages[int(pg)][int(y):int(y) + int(h), int(x):int(x) + int(w), 3] > 128
            ys, xs = np.where(a)
            fx = (xs + float(ox)) * px
            uy = -(ys + float(oy)) * px
            d = (fx - 0.05) ** 2 + (uy - 0.95) ** 2 + np.maximum(fx, 0) * 0.15   # 前へ出た方を少し優先
            i = int(np.argmax(d))
            th.append([round(float(fx[i]), 3), round(float(uy[i]), 3)])
        c["tip"] = th
        print(name, "当たりのコマの先端（前）", [tf[i] for i in c["hits"]], "（上）", [tu[i] for i in c["hits"]])
    json.dump(j, open(os.path.join(D, "lily.json"), "w"), ensure_ascii=False)


if __name__ == "__main__":
    main()
