"""UI の日本語フォント（assets/event_idle/sa2_t6_ja.otf＝Noto Sans CJK JP Regular の抜き出し）に字を足す（2026-11-12、ランカの入口の文字）。
今ある字はそのまま残し、引数の文字列の字を足して作り直す。元：システムの NotoSansCJK-Regular.ttc（JP）。ライセンスは sa2_t5_ja_license.txt（SIL OFL）。
使い方：python3 -I sequel/tools/extend_ja_font.py "足したい文字列" …"""
import sys, os
from fontTools.ttLib import TTFont, TTCollection
from fontTools import subset
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, "assets/event_idle/sa2_t6_ja.otf")
SRC = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
have = set(chr(c) for c in TTFont(DST).getBestCmap())
want = have | set("".join(sys.argv[1:]))
coll = TTCollection(SRC)
font = next(f for f in coll.fonts if f["name"].getDebugName(4) == "Noto Sans CJK JP")
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(want)))
sub.subset(font)
font.save(DST)
print("added", "".join(sorted(want - have)), "total", len(TTFont(DST).getBestCmap()))
