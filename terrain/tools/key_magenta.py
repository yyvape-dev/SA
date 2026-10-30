# マゼンタ背景のコマ（動画AIのキーフレームなど）を透過PNGにする。縁の背景混じりは内側の色で塗り直す（claude/hq_pipeline.py の key_hq と同じ考え方）。
# 全コマ共通の枠で切り抜く（足元の位置がコマ間でずれない）。続けて esr/esr_np.py で拡大し、pack_side_clips.py でシートにする。
# 使い方: python3 -I tools/key_magenta.py <出力フォルダ> <入力1.png> <入力2.png> ...   → frame_01.png〜
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc
def key_hq(a, min_blob=500):
    bg = np.mean([a[:20, :20], a[:20, -20:], a[-20:, :20], a[-20:, -20:]], axis=(0, 1, 2))
    d = np.sqrt(((a - bg) ** 2).sum(-1)); al = np.clip((d - 45) / (130 - 45), 0, 1)
    core = ndi.binary_opening(al >= 0.98, structure=np.ones((2, 2)))
    lab, n = ndi.label(core, structure=np.ones((3, 3)))
    keep = np.isin(lab, [k + 1 for k, z in enumerate(ndi.sum(core, lab, range(1, n + 1))) if z >= min_blob]) if n else core
    hsv0 = mc.rgb_to_hsv(np.clip(a, 0, 255) / 255); h0, s0, v0 = hsv0[..., 0] * 360, hsv0[..., 1], hsv0[..., 2]
    dist = ndi.distance_transform_edt(keep); band = (dist > 0) & (dist <= 3)
    keep &= ~(band & (((h0 >= 250) & (h0 <= 350) & (s0 > 0.08)) | ((v0 > 0.82) & (s0 < 0.28))))   # 縁の帯のピンク・白っぽい点は背景の名残
    keep = ndi.binary_opening(keep, structure=np.ones((2, 2)))
    region = ndi.binary_dilation(keep, iterations=3); st = ndi.generate_binary_structure(2, 1)
    src = ndi.binary_erosion(keep, structure=st, iterations=2)
    idx = ndi.distance_transform_edt(~src, return_distances=False, return_indices=True); col = a[idx[0], idx[1]]
    A = np.where(region, al, 0); A = np.clip((A - 0.35) / 0.5, 0, 1)
    A = np.where(ndi.binary_erosion(keep, structure=st, iterations=1), 1.0, A); A = np.where(A < 0.08, 0, A)
    hs = mc.rgb_to_hsv(np.clip(col, 0, 255) / 255); hh = hs[..., 0] * 360
    pk = (hh >= 255) & (hh <= 345) & (hs[..., 1] > 0.12) & (~src) & (A > 0)   # 縁に残るマゼンタかぶりは彩度を落とす
    hs[..., 1] = np.where(pk, hs[..., 1] * 0.15, hs[..., 1])
    return np.dstack([mc.hsv_to_rgb(hs) * 255, A * 255]).astype(np.uint8)
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
fr = [key_hq(np.array(Image.open(f).convert('RGB')).astype(np.float32)) for f in sys.argv[2:]]
ys = []; xs = []
for r in fr: yy, xx = np.where(r[..., 3] > 20); ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
H, W = fr[0].shape[:2]; box = (max(0, min(xs) - 8), max(0, min(ys) - 8), min(W, max(xs) + 9), min(H, max(ys) + 9))
for i, r in enumerate(fr): Image.fromarray(r).crop(box).save(os.path.join(out, 'frame_%02d.png' % (i + 1)))
print('box', box, len(fr))
