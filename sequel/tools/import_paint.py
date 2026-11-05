"""外部AIが塗った絵を、ゲームに入れる（下絵と同じ大きさ・同じ位置にそろえる）。

使い方:  python3 -I sequel/tools/import_paint.py <塗られた絵.png> <部品のid>
  例:    python3 -I sequel/tools/import_paint.py ~/Downloads/tavern.png b1_tavern

やること（事実の確認つき）:
  1. 下絵（art/guide/<id>.png）と同じ大きさに合わせる（比率が違えば中止）。
  2. 両方の「マゼンタでない所」（形）を比べ、ずれ（平行移動）を探して直す。
  3. 形の重なり（IoU）を表示。0.93 未満なら、形が変わっている → 作り直しを勧める。
  4. art/painted/<id>.png に保存。ゲームは次の起動で、箱にこの絵を投影する。
"""
import sys, os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def shape_mask(a):
    a = a.astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = (r > 190) & (b > 190) & (g < 110)
    return ~mag


def best_shift(m_src, m_ref, rng=24):
    best = (-1.0, 0, 0)
    ys, xs = np.nonzero(m_ref)
    for dy in range(-rng, rng + 1, 2):
        for dx in range(-rng, rng + 1, 2):
            s = np.roll(np.roll(m_src, dy, 0), dx, 1)
            inter = (s & m_ref).sum()
            uni = (s | m_ref).sum()
            iou = inter / max(1, uni)
            if iou > best[0]:
                best = (iou, dy, dx)
    # 1px単位で詰める
    iou0, dy0, dx0 = best
    for dy in range(dy0 - 1, dy0 + 2):
        for dx in range(dx0 - 1, dx0 + 2):
            s = np.roll(np.roll(m_src, dy, 0), dx, 1)
            iou = (s & m_ref).sum() / max(1, (s | m_ref).sum())
            if iou > best[0]:
                best = (iou, dy, dx)
    return best


def main():
    src, pid = sys.argv[1], sys.argv[2]
    ref = np.array(Image.open(os.path.join(ROOT, 'art/guide/%s.png' % pid)).convert('RGB'))
    im = Image.open(src).convert('RGB')
    H, W = ref.shape[:2]
    if abs(im.size[0] / im.size[1] - W / H) > 0.02:
        print('NG：縦横の比率が下絵と違う（塗った絵 %dx%d、下絵 %dx%d）。同じ比率で出し直してください。' % (im.size + (W, H)))
        sys.exit(1)
    if im.size != (W, H):
        im = im.resize((W, H), Image.LANCZOS)
    a = np.array(im)
    m_ref, m_src = shape_mask(ref), shape_mask(a)
    iou_raw = (m_src & m_ref).sum() / max(1, (m_src | m_ref).sum())
    iou, dy, dx = best_shift(m_src, m_ref)
    if (dy, dx) != (0, 0):
        a = np.roll(np.roll(a, dy, 0), dx, 1)
    out = os.path.join(ROOT, 'art/painted/%s.png' % pid)
    Image.fromarray(a).save(out, optimize=True)
    print('形の重なり IoU：そのまま %.3f → ずれ補正後 %.3f（下へ%dpx・右へ%dpx）' % (iou_raw, iou, dy, dx))
    print('保存：%s' % out)
    if iou < 0.93:
        print('注意：形が下絵から変わっています（0.93未満）。はみ出した所は投影されず、欠けた所は仮の色になります。作り直しを勧めます。')


if __name__ == '__main__':
    main()
