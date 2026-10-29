# 一騎打ちの攻撃の連番を、拡大AI（Upscayl など）で大きくしたコマから作り直す。
#   入力：フォルダ（frame_01〜NN の PNG。Upscayl の .temp-…-frame_05_upscayl_4x_….png の名前でも可）と、差し替える連番のファイル名。
#   出力：ally/<ファイル名>（webp、同じ名前で上書き）と ally/duel_meta.json の寸法（cw・ch・idle・pad を同じ倍率で拡大）。
#   人物の高さ（idle.h）を TARGET_H にそろえる（大きすぎるシートは iPhone で重いので、拡大した絵を縮めて使う）。抜けたコマは今の絵を拡大して埋める。
# 使い方: cd terrain && python3 -I tools/pack_upscaled_duel.py <フォルダ> duel_garou_1.webp [<フォルダ> duel_mina_2.webp …]
#   敵将の連番は --npc を先頭に（assets/npc/ と foeduel_meta.json を使う）
import sys, os, re, glob, json
from PIL import Image
TARGET_H = 520
args = sys.argv[1:]; base, mp = '../ally/', '../ally/duel_meta.json'
if args and args[0] == '--npc': base, mp = 'assets/npc/', 'assets/npc/foeduel_meta.json'; args = args[1:]
meta = json.load(open(mp))
for src, fname in zip(args[0::2], args[1::2]):
    c = next(c for v in meta.values() for c in v if c['f'] == fname)
    old = Image.open(base + fname).convert('RGBA')
    fs = {}
    for f in glob.glob(os.path.join(src, '**', '*.png'), recursive=True) + glob.glob(os.path.join(src, '**', '.*.png'), recursive=True):
        m = re.search(r'frame_(\d+)', os.path.basename(f))
        if m: fs[int(m.group(1))] = f
    k = TARGET_H / c['idle']['h']; cw, ch = round(c['cw'] * k), round(c['ch'] * k)
    rows = -(-c['n'] // c['cols']); sheet = Image.new('RGBA', (cw * c['cols'], ch * 4), (0, 0, 0, 0)); filled = []
    for i in range(c['n']):
        if i + 1 in fs: im = Image.open(fs[i + 1]).convert('RGBA')
        else:  # 抜けたコマ：今の絵を拡大
            x, y = (i % c['cols']) * c['cw'], (i // c['cols']) * c['ch']; im = old.crop((x, y, x + c['cw'], y + c['ch'])); filled.append(i + 1)
        sheet.paste(im.resize((cw, ch), Image.LANCZOS), ((i % c['cols']) * cw, (i // c['cols']) * ch))
    sheet.save(base + fname, 'WEBP', quality=90, method=6)
    c['cw'], c['ch'] = cw, ch
    c['idle'] = {kk: round(v * k, 1) for kk, v in c['idle'].items()}
    c['pad'] = round((c['pad'] if c.get('pad') is not None else 2.8) * k, 1)
    print(fname, f'x{k:.2f}', sheet.size, os.path.getsize(base + fname) // 1024, 'KB', '埋めたコマ', filled)
json.dump(meta, open(mp, 'w'), ensure_ascii=False)
