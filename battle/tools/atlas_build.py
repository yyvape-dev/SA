# キャラの連番（1コマ＝1枚の透過PNG）を、余白を切り詰めて技ごとのアトラス（可逆 WebP）に詰める。Skill sa-sprite-atlas。
# 画質は落ちない：透明（アルファ0）の外側を捨てて並べ替えるだけ。画素はそのまま。
# 使い方（リポジトリ直下で）:
#   python3 battle/tools/atlas_build.py <コマのフォルダ> <出力の頭> [--page 2048] [--check]
#   例: python3 battle/tools/atlas_build.py sprites sprites/atlas/rana
#   コマの名前は <技>_<番号>.png（例 walk_00.png）。同じ技はなるべく同じページに入る（技ごとに GPU へ送る・手放すため）。
# 出力: <頭>_<技>_<n>.webp と <頭>.json
#   json: { "v":1, "pages":[ファイル名…], "clips":{技: コマ数}, "f":{ "walk_00":[ページ, x, y, w, h, 切った左, 切った上, 元の幅, 元の高さ] } }
#   描くとき: drawImage(ページ, x, y, w, h, -ax + 切った左, -ay + 切った上, w, h)（ax, ay は元のコマでの足元の基準。今までと同じ値）
# --check: 全コマを元の大きさに戻して、元の PNG と1画素ずつ比べる（無劣化の確認）。
import sys, os, re, json, glob
from PIL import Image

def main():
    a = sys.argv[1:]; src, out = a[0], a[1]
    page = int(a[a.index('--page') + 1]) if '--page' in a else 2048
    PAD = 2
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    clips = {}
    for f in sorted(glob.glob(os.path.join(src, '*.png'))):
        m = re.match(r'(.+)_(\d+)\.png$', os.path.basename(f))
        if m: clips.setdefault(m.group(1), []).append(f)
    base = os.path.basename(out); pages = []; F = {}; tot0 = tot1 = 0
    for clip, files in clips.items():
        items = []
        for f in files:
            im = Image.open(f).convert('RGBA'); W, H = im.size; tot0 += W * H * 4
            bb = im.getchannel('A').getbbox() or (0, 0, 1, 1)
            items.append((os.path.basename(f)[:-4], im.crop(bb), bb, W, H))
        items.sort(key=lambda t: -t[1].size[1])  # 高い順に棚へ並べる
        shelves = []  # ページごと：[(棚の y, 棚の高さ, 次の x)]
        cur = None; pi = -1
        def new_page():
            nonlocal cur, pi
            cur = {'img': Image.new('RGBA', (page, page), (0, 0, 0, 0)), 'y': 0, 'sh': 0, 'x': 0, 'used': [0, 0]}
            pages.append((clip, cur)); pi = len(pages) - 1
        new_page()
        for name, im, bb, W, H in items:
            w, h = im.size
            if w + PAD > page or h + PAD > page: raise SystemExit(f'{name} が {page} 角より大きい（--page を上げる）')
            if cur['x'] + w + PAD > page: cur['y'] += cur['sh']; cur['x'] = 0; cur['sh'] = 0
            if cur['y'] + h + PAD > page: new_page()
            x, y = cur['x'], cur['y']; cur['img'].paste(im, (x, y)); cur['x'] += w + PAD; cur['sh'] = max(cur['sh'], h + PAD)
            cur['used'] = [max(cur['used'][0], x + w), max(cur['used'][1], y + h)]
            F[name] = [pi, x, y, w, h, bb[0], bb[1], W, H]; tot1 += w * h * 4
    names = []; area = 0
    n_by = {}
    for i, (clip, p) in enumerate(pages):
        k = n_by.get(clip, 0); n_by[clip] = k + 1
        uw, uh = p['used']; img = p['img'].crop((0, 0, uw, uh))  # 使った所だけ（ページの余りを捨てる）
        fn = f'{base}_{clip}_{k}.webp'; img.save(os.path.join(os.path.dirname(out), fn), 'WEBP', lossless=True, quality=100, method=4)
        names.append(fn); area += uw * uh * 4
    meta = {'v': 1, 'pages': names, 'clips': {c: len(v) for c, v in clips.items()}, 'f': F}
    json.dump(meta, open(out + '.json', 'w'), separators=(',', ':'))
    size = sum(os.path.getsize(os.path.join(os.path.dirname(out), n)) for n in names)
    print(f'コマ {len(F)}・ページ {len(names)}　展開のメモリ {tot0/1e6:.0f}MB → {area/1e6:.0f}MB　ファイル {size/1e6:.1f}MB')
    if '--check' in a:
        bad = 0; P = [Image.open(os.path.join(os.path.dirname(out), n)).convert('RGBA') for n in names]
        for name, (pi, x, y, w, h, l, t, W, H) in F.items():
            r = Image.new('RGBA', (W, H), (0, 0, 0, 0)); r.paste(P[pi].crop((x, y, x + w, y + h)), (l, t))
            o = Image.open(os.path.join(src, name + '.png')).convert('RGBA')
            # アルファ0の画素は色を問わない（見えない）
            z = lambda im: [(p if p[3] else (0, 0, 0, 0)) for p in im.getdata()]
            if z(r) != z(o): bad += 1; print('ちがう', name)
        print('無劣化の確認：' + ('全コマ一致' if not bad else f'{bad} コマちがう'))

main()
