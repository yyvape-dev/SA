# UIの仮素材：GPTのモック（941×1672、ユーザー作成）から、上の帯・下の操作盤・つまみ・菱形・アイコンを切り出す。
# 変わる部分（HPの中身・文字・戦況の中身・つまみ・回避のラベルと絵）は消して、ゲームが上に描く。
# 使い方: python3 battle/tools/slice_mock.py <モックのPNG>   → battle/ui/*.webp
import sys, numpy as np, cv2
from PIL import Image
SRC = sys.argv[1]; OUT = 'battle/ui/'
a = np.array(Image.open(SRC).convert('RGB'))
assert a.shape[:2] == (1672, 941), a.shape
def save(img, name, q=88):
    Image.fromarray(img).save(OUT + name, 'WEBP', quality=q, method=6)
def inpaint(img, rects=(), circles=(), r=5):
    m = np.zeros(img.shape[:2], np.uint8)
    for x0, y0, x1, y1 in rects: m[y0:y1, x0:x1] = 255
    for cx, cy, rr in circles: cv2.circle(m, (cx, cy), rr, 255, -1)
    return cv2.inpaint(img, m, r, cv2.INPAINT_TELEA)
def fill_rows(img, x0, x1, y0, y1, sx0, sx1):  # 帯の中身を、空の部分の色（行ごと）で塗る
    for y in range(y0, y1):
        img[y, x0:x1] = img[y, sx0:sx1].reshape(-1, 3).mean(0).astype(np.uint8)
def circle_rgba(img, cx, cy, rr):  # 円の切り抜き（縁はなめらかに）
    c = img[cy - rr:cy + rr, cx - rr:cx + rr].copy()
    yy, xx = np.mgrid[0:2 * rr, 0:2 * rr]; d = np.sqrt((xx - rr + .5) ** 2 + (yy - rr + .5) ** 2)
    al = np.clip((rr - d) / 1.5, 0, 1) * 255
    return np.dstack([c, al.astype(np.uint8)])

# ---- 上の帯（0〜178）----
top = a[0:178].copy()
save(top[128:166, 360:394].copy(), 'ic_skull.webp')     # 残りのドクロ
save(top[126:166, 795:836].copy(), 'ic_chest.webp')     # 物資の箱
fill_rows(top, 176, 662, 49, 79, 640, 660)              # HPの中身（赤と文字）を空に
fill_rows(top, 176, 516, 85, 104, 440, 510)             # 下の青い帯（必殺の溜まり）を空に
top = inpaint(top, rects=[(172, 122, 932, 170)])        # 情報の行（WAVE・残り・コイン…）を消す
save(top, 'hud_top.webp', 90)

# ---- 下の操作盤（1090〜1672）----
B0 = 1090; bot = a[B0:].copy()
save(circle_rgba(a, 243, B0 + 288, 64), 'knob.webp', 92)          # つまみ
save(bot[18:98, 440:500].copy(), 'gauge_dia.webp', 92)             # 戦況の菱形（背景ごと）
save(circle_rgba(a, 697, B0 + 162, 60), 'btn_blue.webp', 92)      # 回避の円（突きに使う。中の絵は消す）
fill_rows(bot, 252, 690, 50, 70, 600, 680)                         # 戦況の中身を空に
bot[18:98, 440:500] = bot[18:98, 380:440]                         # 菱形の所は、左隣の帯を写して埋める
bot = inpaint(bot, rects=[(668, 205, 728, 236)], circles=[(243, 288, 66)])  # 菱形・回避のラベル・つまみ
save(bot, 'panel.webp', 88)
print('ok')
