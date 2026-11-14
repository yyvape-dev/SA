"""Subset the installed Noto font for the standalone prologue. No art resampling.
Run from any cwd: python3 sequel/tools/make_prologue_font.py [source.otf|source.ttc]
Requires fontTools; defaults to Debian's Japanese-first Noto CJK collection.
"""
from pathlib import Path
import sys
from fontTools import subset
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
text = ''.join(p.read_text() for p in (root / 'dialogues/ja').glob('P0-*.json'))
for name in ['sa2_prologue_preview', 'sa2_prologue_room', 'sa2_dialogue_panel']:
    text += (root / f'scripts/{name}.gd').read_text()
text += ''.join(chr(i) for i in range(32, 127))
text += '話者タップで全文表示終了次へ自動ログを閉じる会話スキップこのをして先に進みますか？戻る●勤めを果たしてくる。'
font = TTFont(source, **({'fontNumber': 0} if source.suffix == '.ttc' else {}))
worker = subset.Subsetter()
worker.populate(text=text)
worker.subset(font)
font.save(root / 'assets/event_idle/sa2_prologue_ja.otf')
print('PROLOGUE_FONT:', source, '->', len(set(text)), 'characters')
