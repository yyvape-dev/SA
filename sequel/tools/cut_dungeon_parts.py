# ダンジョンの部品（外部AIの絵、マゼンタ背景）を切り抜いて assets/dungeon/<テーマ>/ に可逆 WebP で置く（2026-11-14、specs/dungeon_themes.md）。
#  - 外周につながったマゼンタだけを背景にする（中の紫の結晶・ネオンを抜かない。key_soft は色の距離だけで抜くので結晶が半透明になる）
#  - 縁は色の距離でなだらかに、背景色を差し引いて元の色に戻す（アンミックス）、縁の赤紫かぶりを少し削る
#  - 大きさは変えない（縮めない）。余白だけ切る。床（g）は抜かずにそのまま
# 使い方: python3 -I sequel/tools/cut_dungeon_parts.py <受け取りフォルダ> <テーマ> [--check 比較画像.png]
import sys, os, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi

T0, T1 = 40.0, 110.0   # 背景色からの距離：T0 以下＝透明、T1 以上＝不透明（JPEG のにじみを見込む）

def cut(a):
    bg = np.median(np.concatenate([a[:12, :12].reshape(-1, 3), a[:12, -12:].reshape(-1, 3), a[-12:, :12].reshape(-1, 3), a[-12:, -12:].reshape(-1, 3)]), axis=0)
    d = np.sqrt(((a - bg) ** 2).sum(-1))
    cand = d < T1
    lab, n = ndi.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    reg = np.isin(lab, list(border))           # 外周につながった背景らしい所
    # 閉じた穴（ホースの輪の内側など）：背景色にごく近い（T0 未満）まとまりが 150 画素以上なら背景（紫の結晶は距離が 80 以上で当たらない）
    hole = d < T0
    lab3, n3 = ndi.label(hole)
    if n3:
        sz3 = ndi.sum(hole, lab3, range(1, n3 + 1))
        big3 = [i + 1 for i, s_ in enumerate(sz3) if s_ >= 150]
        reg = reg | ndi.binary_dilation(np.isin(lab3, big3), iterations=2) & cand
    al = np.where(reg, np.clip((d - T0) / (T1 - T0), 0, 1), 1.0)
    al = np.where(al < 0.04, 0, al)
    a2 = np.where(al[..., None] > 0.01, (a - (1 - al[..., None]) * bg) / np.maximum(al[..., None], 0.01), a)
    a2 = np.clip(a2, 0, 255)
    edge = (al > 0) & (al < 0.98)
    mn = np.minimum(a2[..., 0], a2[..., 2]); ex = np.clip(mn - a2[..., 1], 0, None) * edge * 0.7
    a2[..., 0] -= ex; a2[..., 2] -= ex
    # 抜いた所から離れた小さな粒（JPEG の残り）を消す
    m = al > 0.02
    lab2, n2 = ndi.label(m, structure=np.ones((3, 3)))
    if n2 > 1:
        sz = ndi.sum(m, lab2, range(1, n2 + 1))
        keep = [i + 1 for i, s in enumerate(sz) if s >= 400]
        al = np.where(np.isin(lab2, keep), al, 0)
    return np.dstack([np.clip(a2, 0, 255), al * 255]).astype(np.uint8), bg

def main():
    src, theme = sys.argv[1], sys.argv[2]
    out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'dungeon', theme)
    os.makedirs(out, exist_ok=True)
    info = {}
    for f in sorted(os.listdir(src)):
        stem, ext = os.path.splitext(f)
        if not stem.startswith(theme + '_') or ext.lower() not in ('.jpeg', '.jpg', '.png') or stem.endswith('room') or 'room_' in stem:
            continue
        try:
            im = Image.open(os.path.join(src, f)); im.load()
        except Exception as e:
            print('読めない（壊れている）:', f, e); continue
        a = np.array(im.convert('RGB')).astype(np.float32)
        kind = stem.split('_')[1].rstrip('0123456789')
        if kind == 'g':   # 床：そのまま（繰り返し）
            r = np.dstack([a, np.full(a.shape[:2], 255)]).astype(np.uint8)
            box = (0, 0, a.shape[1], a.shape[0])
        else:
            r, bg = cut(a)
            yy, xx = np.where(r[..., 3] > 8)
            box = (max(0, xx.min() - 2), max(0, yy.min() - 2), min(a.shape[1], xx.max() + 3), min(a.shape[0], yy.max() + 3))
        img = Image.fromarray(r).crop(box)
        if kind == 'g':
            img = img.convert('RGB')
        img.save(os.path.join(out, stem + '.webp'), lossless=True, quality=100, method=4)
        info[stem] = {'src': f, 'size': list(img.size), 'box': list(map(int, box)), 'kind': kind}
        print(stem, kind, 'box', box, '→', img.size)
    json.dump(info, open(os.path.join(out, 'parts.json'), 'w'), ensure_ascii=False, indent=1)
    if '--check' in sys.argv:   # 元の絵と同じ大きさで、切り抜きを灰色の上に並べる
        cp = sys.argv[sys.argv.index('--check') + 1]
        tiles = []
        for stem, v in info.items():
            if v['kind'] == 'g':
                continue
            o = Image.open(os.path.join(src, v['src'])).convert('RGB')
            c = Image.open(os.path.join(out, stem + '.webp'))
            g = Image.new('RGB', o.size, (70, 70, 70)); g.paste(c, tuple(v['box'][:2]), c)
            pair = Image.new('RGB', (o.width * 2 + 8, o.height), (0, 0, 0)); pair.paste(o, (0, 0)); pair.paste(g, (o.width + 8, 0))
            tiles.append(pair.resize((900, int(pair.height * 900 / pair.width))))
        H = sum(t.height + 6 for t in tiles); sheet = Image.new('RGB', (900, H), (0, 0, 0)); y = 0
        for t in tiles:
            sheet.paste(t, (0, y)); y += t.height + 6
        sheet.save(cp, quality=85)

if __name__ == '__main__':
    main()
