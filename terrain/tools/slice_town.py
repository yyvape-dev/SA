# 街の小物シート（4×3、マゼンタ背景）を切り出す。塊は重心の位置でマスに割り当てる（はみ出した車輪・炎も取りこぼさない）
import sys, numpy as np, cv2
from PIL import Image
sys.path.insert(0, 'tools'); from slice_ui import key
def run(src, names, out, cols=4, rows=3):
    im = np.asarray(Image.open(src).convert('RGB')); rgb, a = key(im); H, W = a.shape
    # 紫のにじみ（縁の半透明でマゼンタ寄り）を、さらに消す
    r, g, b = [rgb[..., i].astype(int) for i in range(3)]; fringe = (r > g + 25) & (b > g + 25)
    a = np.where(fringe & (a < 250), 0, a).astype(np.uint8); a = np.where(fringe, (a * .4).astype(np.uint8), a)
    n, lab, st, cen = cv2.connectedComponentsWithStats((a > 40).astype(np.uint8), 8)
    masks = [np.zeros((H, W), bool) for _ in names]
    for c in range(1, n):
        if st[c, 4] < 25: continue
        i, j = min(cols - 1, int(cen[c][0] / (W / cols))), min(rows - 1, int(cen[c][1] / (H / rows)))
        masks[j * cols + i] |= lab == c
    for nm, m in zip(names, masks):
        ys, xs = np.where(m); x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        al = np.where(m, a, 0)[y0:y1, x0:x1]
        Image.fromarray(np.dstack([rgb[y0:y1, x0:x1], al])).save(f'{out}/{nm}.png'); print(nm, x1 - x0, y1 - y0)
if __name__ == '__main__':
    run('/mnt/user-data/attachments/0531ac60-557c-54b6-9e73-a3fe93a1f37f/ef0647aa-image.png',
        ['fountain', 'well', 'lamp', 'sign', 'stall', 'barrels', 'flowerbed', 'bench', 'cart', 'torch', 'hay', 'fence'], 'assets/town')
