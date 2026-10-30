# 明朝体（しっぽり明朝 B1、OFL）を、ゲームで使う文字だけに絞って woff2 にする。
# 文言を足したら、もう一度実行する： python3 tools/subset_font.py <元のttfのフォルダ>
import sys, glob
from fontTools import subset
src = sys.argv[1] if len(sys.argv) > 1 else '.'
txt = ''.join(open(f, encoding='utf-8').read() for f in ['main.js', 'game.js', 'ui.js', 'morning.js', 'index.html'] + sorted(glob.glob('../battle/*.js')) + ['../index.html']) # アクション戦闘（battle/）の文言も含める
chars = set(c for c in txt if ord(c) > 0x2e7f)
chars |= set(chr(c) for c in range(0x20, 0x7f)) | set(chr(c) for c in range(0x3041, 0x3097)) | set(chr(c) for c in range(0x30a1, 0x30fb))
chars |= set('ー〜・、。「」『』（）！？…―─×％＋－：　①②③④⑤')
for w, out in [('Bold', 'mincho-b')]:
    opt = subset.Options(); opt.flavor = 'woff2'; opt.layout_features = ['*']; opt.name_IDs = ['*']
    f = subset.load_font(f'{src}/ShipporiMinchoB1-{w}.ttf', opt); s = subset.Subsetter(opt); s.populate(text=''.join(chars)); s.subset(f)
    subset.save_font(f, f'assets/font/{out}.woff2', opt); print(out, len(chars))
