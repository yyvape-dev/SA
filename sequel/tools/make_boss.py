"""前作の敵将（章の将軍）の絵を、ダンジョンのボス（仮置き）として sequel/assets/foe/foe.json に足す。
使い方：python3 -I sequel/tools/make_boss.py [g1]  （リポジトリのルートで）
歩き＝立ち絵 gen_<id>.webp の1コマ（前作も歩きは構えの揺れ）。攻撃＝一騎打ちの連番2本。絵は複製するだけ（画質は変えない）。
"""
import json, shutil, sys
from pathlib import Path

ROOT = Path.cwd()
NPC = ROOT / "terrain/assets/npc"
OUT = ROOT / "sequel/assets/foe"
gid = sys.argv[1] if len(sys.argv) > 1 else "g1"
sys.path.insert(0, str(ROOT / "sequel/tools"))
from make_foes import duel_clip  # noqa: E402  (make_foes は import しても main を走らせないよう __name__ を見る)

gm = json.loads((NPC / "gen_meta.json").read_text())[gid]
dm = json.loads((NPC / "foeduel_meta.json").read_text())[gid]
page = f"gen_{gid}.webp"
shutil.copyfile(NPC / page, OUT / page)
clips = {"walk": {"frames": [[page, 0, 0, gm["w"], gm["h"], -gm["ax"], -gm["ay"]]], "h": gm["body"], "face": -1, "fps": 1}}
for i, c in enumerate(dm):
    shutil.copyfile(NPC / c["f"], OUT / c["f"])
    clips[f"atk{i}"] = duel_clip(c)
fj = OUT / "foe.json"
d = json.loads(fj.read_text())
d[gid] = clips
fj.write_text(json.dumps(d, ensure_ascii=False))
print(gid, {n: len(v["frames"]) for n, v in clips.items()})
