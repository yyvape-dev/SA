"""前作の敵兵の絵（歩きのシート・一騎打ちの攻撃の連番）を、続編の足元基準の json にまとめる。
使い方：python3 -I sequel/tools/make_foes.py  （リポジトリのルートで）
出力：sequel/assets/foe/foe.json と、絵（webp をそのまま複製。画質は変えない）。
ラナの被弾の4コマ（前作のアトラス）も sequel/assets/rana/rana.json に足す。

json の1コマ：[ページ, x, y, w, h, 足元から見た左上の x, 足元から見た左上の y]（画像の y は下向き）
clip：frames・h（その絵での背の高さ px）・face（絵の向き 1＝右 −1＝左）・durs（ms）・hit（当たりのコマ）
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
NPC = ROOT / "terrain/assets/npc"
OUT = ROOT / "sequel/assets/foe"
KINDS = ["1", "3"]   # 1＝槍兵 3＝フードの山賊（前作の一般兵）


def walk_clip(kind, wm):
    cw, ch = wm["cw"], wm["ch"]
    page = f"foewalk_{kind}.webp"
    fr = []
    for i in range(8):
        x, y = (i % 4) * cw, (i // 4) * ch
        fr.append([page, x, y, cw, ch, -cw / 2, -ch * 0.985])
    return page, {"frames": fr, "h": wm["h"], "face": 1, "fps": 11}


def duel_clip(c):
    ax = c["idle"]["x"] + c["idle"]["w"] / 2
    ay = c["ch"] - (c.get("pad") if c.get("pad") is not None else 2.8)
    fr = [[c["f"], q[0], q[1], q[2], q[3], -ax + q[4], -ay + q[5]] for q in c["fr"]]
    return {"frames": fr, "h": c["idle"]["h"], "face": -1, "durs": c["durs"], "hit": c["hit"]}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    walk_meta = json.loads((NPC / "foewalk_meta.json").read_text())
    duel_meta = json.loads((NPC / "foeduel_meta.json").read_text())
    out = {}
    for k in KINDS:
        page, wc = walk_clip(k, walk_meta[int(k) - 1])
        shutil.copyfile(NPC / page, OUT / page)
        clips = {"walk": wc}
        for i, c in enumerate(duel_meta[k]):
            shutil.copyfile(NPC / c["f"], OUT / c["f"])
            clips[f"atk{i}"] = duel_clip(c)
        out[k] = clips
        print(k, {n: len(v["frames"]) for n, v in clips.items()})
    (OUT / "foe.json").write_text(json.dumps(out, ensure_ascii=False))

    # ラナの被弾（前作 battle/core.js の DMG_A＝ax215, ay261, k0.846）
    atl = json.loads((ROOT / "sprites/atlas/rana.json").read_text())
    rj = ROOT / "sequel/assets/rana/rana.json"
    rana = json.loads(rj.read_text())
    fr = []
    for i in range(4):
        q = atl["f"][f"dmg_{i:02d}"]
        page = atl["pages"][q[0]] if isinstance(atl["pages"][q[0]], str) else atl["pages"][q[0]]["f"]
        fr.append([Path(page).name, q[1], q[2], q[3], q[4], q[5] - 215, q[6] - 261])
    shutil.copyfile(ROOT / "sprites/atlas" / fr[0][0], ROOT / "sequel/assets/rana" / fr[0][0])
    rana["dmg"] = {"k": 0.846, "frames": fr}
    rj.write_text(json.dumps(rana, ensure_ascii=False))
    print("rana dmg", fr[0])


main()
