# 建物の切り抜き絵の「向き」を区画のひし形（辺の傾き ±1/2）に合わせる。2026-10-29、鍛冶場が約10〜15°回って描かれていたため。
# やり方：縦の線は縦のまま（x方向の拡大 a と、x に比例した縦のずらし c だけ）。土台の平行四辺形 fp の2辺の傾きが +0.5 と −0.5 になる a, c を解く。
#   x' = a (x − px) + PX,  y' = y + c (x − px) + PY   （px＝足元の基準点。基準点は動かさない）
# 元の絵は tools/bld_src/ に退避し、毎回そこから作る（何度回しても重ねがけにならない）。
# 最後に全体を 1/a 倍して、土台の横幅を元と同じにする（区画に対する建物の大きさを変えない）。
# 使い方: cd terrain && python3 tools/fix_bld_angle.py smithy tavern
import sys, os, json, shutil, math
from PIL import Image
SRC = 'tools/bld_src/'; os.makedirs(SRC, exist_ok=True)
meta = json.load(open('data/bld.json'))
if not os.path.exists(SRC + 'bld.json'): shutil.copy('data/bld.json', SRC + 'bld.json')
orig = json.load(open(SRC + 'bld.json'))
for fac in sys.argv[1:]:
    for k in (1, 2, 3):
        key = f'assets/bld/{fac}_{k}.png'; src = SRC + f'{fac}_{k}.png'
        if not os.path.exists(src): shutil.copy(key, src)
        m = orig[key]; fp = m['fp']; im = Image.open(src).convert('RGBA'); w, h = im.size
        sp = (fp[1][1] - fp[0][1]) / (fp[1][0] - fp[0][0])     # 右上がりの辺（奥→右）
        sm = (fp[0][1] - fp[3][1]) / (fp[0][0] - fp[3][0])     # 右下がりの辺（左→奥）を右向きに
        a = (sp - sm) / 1.0; c = 0.5 * a - sp
        px, py = m['ax'] * w, m['ay'] * h
        xs = [a * (x - px) for x in (0, w)]; ys = [y + c * (x - px) for x in (0, w) for y in (0, h)]
        PX = -min(xs); PY = -min(ys); W2 = math.ceil(max(xs) + PX) + 1; H2 = math.ceil(max(ys) + PY) + 1
        out = im.transform((W2, H2), Image.AFFINE, (1 / a, 0, px - PX / a, -c / a, 1, -PY + c * PX / a), resample=Image.BICUBIC)
        out = out.crop(out.getbbox()); bb = im.transform((W2, H2), Image.AFFINE, (1 / a, 0, px - PX / a, -c / a, 1, -PY + c * PX / a)).getbbox()
        ox, oy = bb[0], bb[1]
        k2 = 1 / a   # 土台の横幅を元の絵と同じに戻す（全体を一様に拡大縮小。建物の大きさが区画に対して変わらない）
        out = out.resize((round(out.width * k2), round(out.height * k2)), Image.LANCZOS); out.save(key, optimize=True)
        T = lambda x, y: [round((a * (x - px) + PX - ox) * k2, 1), round((y + c * (x - px) + PY - oy) * k2, 1)]
        nfp = [T(*p) for p in fp]; ax_, ay_ = T(px, py)
        meta[key] = {'w': out.width, 'h': out.height, 'ax': round(ax_ / out.width, 4), 'ay': round(ay_ / out.height, 4), 'fp': nfp}
        ang = [round(math.degrees(math.atan2(nfp[(i + 1) % 4][1] - nfp[i][1], nfp[(i + 1) % 4][0] - nfp[i][0])), 1) for i in range(4)]
        print(key, f'a={a:.3f} c={c:.3f}', (w, h), '->', out.size, ang)
json.dump(meta, open('data/bld.json', 'w'), indent=1)
