"""Regenerate TD fixture font from Debian fonts-noto-cjk and SIL license."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
root=Path(__file__).resolve().parents[1]
source=Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
font=TTFont(source,fontNumber=0)
text=''.join(p.read_text() for p in (root/'dialogues/ja').glob('*.json'))+'話者次へ'
options=subset.Options();sub=subset.Subsetter(options=options)
sub.populate(unicodes=set(range(32,127))|set(map(ord,text)));sub.subset(font)
for record in font['name'].names:
    if record.nameID in (1,3,4,6,16):record.string=('SA2TDFixtureSans' if record.nameID==6 else 'SA2 TD Fixture Sans').encode(record.getEncoding())
font.save(root/'assets/td/fixture-sans.otf')
license_text=Path('/usr/share/doc/fonts-noto-cjk/copyright').read_text()
license_text=license_text[license_text.index('License: SIL-1.1',license_text.index('Files: debian/*')):]
license_text=license_text[:license_text.index('License: GPL-3+')]
(root/'assets/td/LICENSE.txt').write_text('Derived subset of Noto Sans CJK JP. Copyright 2010-2012 Google Corporation.\nSource: https://github.com/notofonts/noto-cjk\nRenamed SA2 TD Fixture Sans, only current test JSON glyphs and ASCII.\n\n'+license_text)
