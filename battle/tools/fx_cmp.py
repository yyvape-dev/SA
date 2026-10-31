# 従来版（cv）と PixiJS 版（gl）の撮影を、場面ごとに左右に並べる。Skill sa-battle-fx-check。
# 使い方: python3 battle/tools/fx_cmp.py <従来の頭> <新しい頭> <出力フォルダ> [場面 …]
#   例: python3 battle/tools/fx_cmp.py /tmp/fx/cv /tmp/fx/gl /tmp/fx arc hit  → /tmp/fx/cmp_arc.png（左＝従来、右＝新しい、上から時刻順）
import sys, glob, os
from PIL import Image
a0, b0, od = sys.argv[1:4]; names = sys.argv[4:] or sorted({os.path.basename(f)[len(os.path.basename(b0)) + 1:].rsplit('_', 1)[0] for f in glob.glob(b0 + '_*_*.png')})
for name in names:
    ks = sorted(int(f.rsplit('_', 1)[1][:-4]) for f in glob.glob(f'{b0}_{name}_*.png'))
    rows = []
    for k in ks:
        A = Image.open(f'{a0}_{name}_{k}.png').convert('RGB'); B = Image.open(f'{b0}_{name}_{k}.png').convert('RGB')
        w, h = A.size; box = (0, int(h * .11), w, int(h * .69)); rows.append((A.crop(box), B.crop(box)))
    if not rows: continue
    W, H = rows[0][0].size; S = Image.new('RGB', (W * 2 + 10, (H + 10) * len(rows)), (255, 255, 255))
    for k, (A, B) in enumerate(rows): S.paste(A, (0, k * (H + 10))); S.paste(B, (W + 10, k * (H + 10)))
    S = S.resize((S.width * 2 // 3, S.height * 2 // 3)); S.save(os.path.join(od, f'cmp_{name}.png')); print(os.path.join(od, f'cmp_{name}.png'))
