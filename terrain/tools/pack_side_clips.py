# 横向きの動きのコマ（ユーザー作成：frame_01〜12.png ＋ frames.json、910×512 の透過PNG）を、一騎打ちの連番と同じ形のシートにまとめる。
#   出力: ally/side_<名前>.webp（6列×2段）と ally/side_meta.json（{名前: {f, cols, cw, ch, n, durs, ph, ax, ay}}）
#   ph＝コマの中の人物の高さ（全コマの最大）、ax・ay＝足元の基準（コマの中の座標）。向きは右。
# 使い方: cd terrain && python3 -I tools/pack_side_clips.py [--out <出力フォルダ>] <フォルダ> <名前> [<フォルダ> <名前> ...]（出力の既定は ../ally/）
#   例: mina_run12 run_mina  rana_walk12 walk_sera  kimono_run12 run_ranka
import sys, os, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc
def color_fix(a):  # 動画AIの色ずれ（足元が緑・紫に変わる）を、茶色寄りの灰へ戻す（claude/hq_pipeline.py の green_fix と同じ考え方）
    hs = mc.rgb_to_hsv(a[..., :3].astype(np.float32) / 255); h = hs[..., 0] * 360; m = (a[..., 3] > 0) & (hs[..., 1] > .08)
    bad = m & (((h >= 60) & (h <= 170)) | ((h >= 275) & (h <= 335)))
    hs[..., 1] = np.where(bad, hs[..., 1] * .15, hs[..., 1]); hs[..., 0] = np.where(bad, 30 / 360, hs[..., 0])
    a[..., :3] = np.clip(mc.hsv_to_rgb(hs) * 255, 0, 255).astype(np.uint8)
args = sys.argv[1:]; OUT = '../ally/'
if args and args[0] == '--out': OUT = args[1].rstrip('/') + '/'; args = args[2:]   # 敵は --out assets/npc
MAXH = 300; COLS = 6
mp = OUT + 'side_meta.json'; meta = json.load(open(mp)) if os.path.exists(mp) else {}
for src, name in zip(args[0::2], args[1::2]):
    info = json.load(open(os.path.join(src, 'frames.json')))
    fr = [np.array(Image.open(os.path.join(src, 'frame_%02d.png' % (i + 1))).convert('RGBA')) for i in range(info['count'])]
    for a in fr:  # 体から離れた小さな粒（動画AIの名残）を消す：一番大きな塊の近く（12px）にあるものだけ残す
        m = a[..., 3] > 20; lab, n = ndi.label(m, structure=np.ones((3, 3)))
        if n > 1:
            sz = ndi.sum(m, lab, range(1, n + 1)); big = lab == (int(np.argmax(sz)) + 1)
            near = ndi.binary_dilation(big, iterations=12); keep = np.isin(lab, [k for k in np.unique(lab[near]) if k])
            a[..., 3] = np.where(keep, a[..., 3], 0)
        color_fix(a)
    ys = []; xs = []
    for a in fr: yy, xx = np.where(a[..., 3] > 20); ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
    x0, y0, x1, y1 = max(0, min(xs) - 4), max(0, min(ys) - 4), max(xs) + 5, max(ys) + 3
    k = min(1.0, MAXH / (y1 - y0)); cw, ch = round((x1 - x0) * k), round((y1 - y0) * k)
    rows = -(-len(fr) // COLS); sheet = Image.new('RGBA', (cw * COLS, ch * rows), (0, 0, 0, 0)); ph = 0
    for i, a in enumerate(fr):
        im = Image.fromarray(a).crop((x0, y0, x1, y1)).resize((cw, ch), Image.LANCZOS)
        sheet.paste(im, ((i % COLS) * cw, (i // COLS) * ch))
        yy = np.where(a[..., 3] > 20)[0]; ph = max(ph, (yy.max() - yy.min()) * k)
    sheet.save(OUT + f'side_{name}.webp', 'WEBP', quality=88, method=6)
    meta[name] = {'f': f'side_{name}.webp', 'cols': COLS, 'cw': cw, 'ch': ch, 'n': len(fr), 'durs': [info['duration_ms_per_frame']] * len(fr),
                  'ph': round(ph, 1), 'ax': round(cw / 2, 1), 'ay': ch - 3}
    print(name, sheet.size, meta[name]['ph'], os.path.getsize(OUT + f'side_{name}.webp') // 1024, 'KB')
json.dump(meta, open(mp, 'w'), ensure_ascii=False)
