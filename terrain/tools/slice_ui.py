# UI部品のシート（マゼンタ背景）を切り出して透過PNGにする。部品はつながった塊ごと、上から・左から順に番号をつける
import sys, numpy as np, cv2
from PIL import Image
def key(rgb):
    r, g, b = [rgb[..., i].astype(np.float32) for i in range(3)]
    mag = np.clip(((r + b) / 2 - g - 60) / 90, 0, 1) * np.clip((np.minimum(r, b) - 120) / 60, 0, 1)  # 1=マゼンタ
    a = 1 - mag
    # 縁のピンクのにじみを取る（despill）：マゼンタ成分を緑の高さまで下げる
    m = np.minimum(r, b); sp = np.clip(m - g, 0, None) * (1 - a) 
    out = rgb.astype(np.float32).copy(); lim = np.maximum(g, (r + b) / 2 - 40)
    out[..., 0] = np.where(a < .98, np.minimum(r, lim + 30), r); out[..., 2] = np.where(a < .98, np.minimum(b, lim + 30), b)
    return out.clip(0, 255).astype(np.uint8), (a * 255).astype(np.uint8)
def slice_sheet(src, names, out, min_area=900, grid=None):
    im = np.asarray(Image.open(src).convert('RGB')); rgb, a = key(im)
    if grid:  # 格子で切る（アイコン）
        h, w = a.shape; rows, cols = grid; boxes = []
        for j in range(rows):
            for i in range(cols):
                x0, y0, x1, y1 = i * w // cols, j * h // rows, (i + 1) * w // cols, (j + 1) * h // rows
                sub = (a[y0:y1, x0:x1] > 40).astype(np.uint8); n, lab, st, _ = cv2.connectedComponentsWithStats(sub, 8)
                k = 1 + int(np.argmax(st[1:, 4])); x, y, w2, h2 = st[k, :4]  # 枠の中で一番大きい塊（隣の絵のはみ出しを除く）
                boxes.append((x0 + x, y0 + y, x0 + x + w2, y0 + y + h2))
    else:
        n, lab, st, _ = cv2.connectedComponentsWithStats((a > 40).astype(np.uint8), 8)
        boxes = [(x, y, x + w, y + h) for (x, y, w, h, ar) in st[1:] if ar >= min_area]
        boxes.sort(key=lambda b: (round(b[1] / 40), b[0]))
    assert len(boxes) == len(names), (len(boxes), boxes)
    for nm, (x0, y0, x1, y1) in zip(names, boxes):
        p = 2; x0, y0 = max(0, x0 - p), max(0, y0 - p); x1, y1 = min(a.shape[1], x1 + p), min(a.shape[0], y1 + p)
        img = Image.fromarray(np.dstack([rgb[y0:y1, x0:x1], a[y0:y1, x0:x1]]))
        if grid: img.thumbnail((128, 128), Image.LANCZOS)  # アイコンは128px以内
        img.save(f'{out}/{nm}.png'); print(nm, img.size)
if __name__ == '__main__':
    A = '/mnt/user-data/attachments/0531ac60-557c-54b6-9e73-a3fe93a1f37f/'
    slice_sheet(A + '3ec36086-image.png', ['frame_l', 'frame_s', 'scroll', 'btn_gold', 'btn_gold_p', 'btn_dark', 'seal', 'banner', 'divider'], 'assets/ui')
    slice_sheet(A + '509440ef-image.png', ['ic_sup', 'ic_mor', 'ic_trp', 'ic_def', 'ic_hp', 'ic_ap', 'ic_build', 'ic_demolish', 'wk_norm', 'wk_now', 'wk_raid', 'wk_past', 'wk_boss', 'ic_star', 'ic_ally', 'ic_flag'], 'assets/ui', grid=(4, 4))
