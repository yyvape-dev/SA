# マゼンタ背景を「柔らかく」抜く（髪の毛先・細い線を切らない）。2026-10-30、key_magenta.py の key_hq は細部を削って絵が崩れたため。
#  ① 背景色からの距離でアルファを決める（形を削る処理＝opening・収縮はしない）
#  ② 半透明の画素は、背景色を差し引いて元の色に戻す（アンミックス）＝縁のマゼンタかぶりが自然に消える
#  ③ 体から離れた小さな粒だけ消す。④ 動画AIの色ずれ（はっきりした緑・紫）だけ灰へ寄せる（くすんだ色は触らない）
# 使い方: python3 -I tools/key_soft.py <出力フォルダ> <入力1.png> …   → frame_01.png〜（全コマ共通の枠で切る）
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc
def key_soft(a, t0=50, t1=135, keep_purple=False):  # keep_purple＝紫の服の人（ヴァルド）。紫を灰へ寄せない
    bg = np.median(np.concatenate([a[:16, :16].reshape(-1, 3), a[:16, -16:].reshape(-1, 3), a[-16:, :16].reshape(-1, 3), a[-16:, -16:].reshape(-1, 3)]), axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(-1)); al = np.clip((d - t0) / (t1 - t0), 0, 1)
    al = np.clip(ndi.gaussian_filter(al, 0.5), 0, 1); al = np.where(al < 0.04, 0, al)  # 動画のノイズで縁がざらつかないよう、ごく軽くならす
    m = al > 0.02; lab, n = ndi.label(m, structure=np.ones((3, 3)))
    if n > 1:
        sz = ndi.sum(m, lab, range(1, n + 1)); big = lab == (int(np.argmax(sz)) + 1)
        near = ndi.binary_dilation(big, iterations=10); keep = np.isin(lab, [k for k in np.unique(lab[near]) if k])
        al = np.where(keep, al, 0)
    a2 = np.where(al[..., None] > 0.01, (a - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.01), a)  # アンミックス
    a2 = np.clip(a2, 0, 255)
    edge = (al > 0) & (al < 0.95)  # 縁に残る赤紫を少し抑える（R・B が G より高いぶんを削る）
    mn = np.minimum(a2[..., 0], a2[..., 2]); ex = np.clip(mn - a2[..., 1], 0, None) * edge * 0.7
    a2[..., 0] -= ex; a2[..., 2] -= ex
    hs = mc.rgb_to_hsv(np.clip(a2, 0, 255) / 255); h, s = hs[..., 0] * 360, hs[..., 1]
    bad = (al > 0) & (s > 0.25) & (((h >= 75) & (h <= 165)) | (((h >= 270) & (h <= 330)) & (not keep_purple)))
    hs[..., 1] = np.where(bad, s * 0.2, s); hs[..., 0] = np.where(bad, 30 / 360, hs[..., 0])
    rgb = mc.hsv_to_rgb(hs) * 255
    return np.dstack([rgb, al * 255]).astype(np.uint8)
if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    fr = [key_soft(np.array(Image.open(f).convert('RGB')).astype(np.float32)) for f in sys.argv[2:]]
    ys = []; xs = []
    for r in fr: yy, xx = np.where(r[..., 3] > 8); ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
    H, W = fr[0].shape[:2]; box = (max(0, min(xs) - 8), max(0, min(ys) - 8), min(W, max(xs) + 9), min(H, max(ys) + 9))
    for i, r in enumerate(fr): Image.fromarray(r).crop(box).save(os.path.join(out, 'frame_%02d.png' % (i + 1)))
    print('box', box, len(fr))
