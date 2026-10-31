# 地割れ・えぐれ跡の「データの絵」を作る（白黒の素材。WebGL のデカールのシェーダーが読む）。Skill sa-battle-fx-check の「表現の約束」。
# 現場の作り方（2026-11-01 調査）：割れ目は線を描かず、割れ目の絵を地面に貼る（デカール）→ 中心からの距離で順に現す → 発光を時間で冷ます → 最後は細らせて閉じる。
# チャンネル：R＝深さ（縁0→割れ目の芯1。細い枝先は1まで届かない＝閉じるとき先に消える）、G＝現れる順番（中心0→先1）、B＝縁の欠け（割れ目のまわりの明るい土のふち）。
# 使い方（リポジトリ直下で）: python3 battle/tools/crack_tex.py → terrain/assets/fx/crack_a.png・crack_b.png・gouge.png
import math, random, numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 2  # 2倍で描いて縮める（縁のなめらかさ）

def poly_seg(dr, dg, p0, p1, w0, w1, g0, g1):
    (x0, y0), (x1, y1) = p0, p1; dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) or 1; nx, ny = -dy / L, dx / L
    q = [(x0 + nx * w0, y0 + ny * w0), (x1 + nx * w1, y1 + ny * w1), (x1 - nx * w1, y1 - ny * w1), (x0 - nx * w0, y0 - ny * w0)]
    dr.polygon(q, fill=255); dr.ellipse([x1 - w1, y1 - w1, x1 + w1, y1 + w1], fill=255)
    dg.polygon(q, fill=int(255 * min(1, g1))); dg.ellipse([x1 - w1, y1 - w1, x1 + w1, y1 + w1], fill=int(255 * min(1, g1)))

def branch(segs, x, y, th, L, w, d0, depth, rnd, Dmax):
    n = max(4, int(L / (14 * S))); px, py = x, y; d = d0
    for i in range(1, n + 1):
        th += rnd.uniform(-0.55, 0.55) * (0.6 if depth == 0 else 1)  # ぎざぎざ（割れは真っすぐ進まない）
        step = L / n * rnd.uniform(0.7, 1.3); nx_, ny_ = px + math.cos(th) * step, py + math.sin(th) * step
        u = i / n; ww = max(0.7 * S, w * (1 - u) ** 0.85 * rnd.uniform(0.75, 1.2))  # 先へ細る、太さにむら
        segs.append(((px, py), (nx_, ny_), max(0.7 * S, w * (1 - (i - 1) / n) ** 0.85), ww, d / Dmax, (d + step) / Dmax))
        d += step
        if depth < 2 and rnd.random() < (0.22 if depth == 0 else 0.12) and u < 0.85:  # 枝分かれ
            branch(segs, nx_, ny_, th + rnd.choice([-1, 1]) * rnd.uniform(0.5, 1.1), L * (1 - u) * rnd.uniform(0.35, 0.6), ww * 0.75, d, depth + 1, rnd, Dmax)
        px, py = nx_, ny_

def finish(R, Gc, size, out, rnd):
    m = np.asarray(R, np.float32) / 255; g = np.asarray(Gc, np.float32) / 255
    # 深さ：縮めながら重ねる（距離の近似。scipy なし）
    acc = np.zeros_like(m); cur = R; K = 7
    for k in range(K): acc += np.asarray(cur, np.float32) / 255; cur = cur.filter(ImageFilter.MinFilter(3))
    depth = np.clip(acc / K * 1.15, 0, 1)
    # 縁の欠け：割れ目のまわりの帯（少し下へずらす＝手前のふちが光を受ける）＋小さな欠片の点
    dil = np.asarray(R.filter(ImageFilter.MaxFilter(7 * S // 2 * 2 + 1)), np.float32) / 255
    edge = np.clip(dil - m, 0, 1); edge = np.roll(edge, 2 * S, axis=0)
    noise = np.asarray(Image.effect_noise((R.size[0], R.size[1]), 90).filter(ImageFilter.GaussianBlur(1.2 * S)), np.float32) / 255
    edge = edge * np.clip((noise - 0.35) * 2.2, 0, 1)
    rgb = np.stack([depth, np.where(m > 0.02, g, 1.0), edge], -1)
    im = Image.fromarray((rgb * 255).astype(np.uint8), 'RGB').resize((size[0], size[1]), Image.LANCZOS)
    im.save(out); print(out, im.size)

def crack(seed, out, N=1024):
    rnd = random.Random(seed); W = N * S; R = Image.new('L', (W, W), 0); Gc = Image.new('L', (W, W), 255); dr, dg = ImageDraw.Draw(R), ImageDraw.Draw(Gc)
    c = W / 2; segs = []; Dmax = W * 0.47; nb = rnd.randint(7, 9)
    for i in range(nb):
        th = i / nb * 6.283 + rnd.uniform(-0.3, 0.3)
        branch(segs, c + math.cos(th) * 18 * S, c + math.sin(th) * 18 * S, th, W * rnd.uniform(0.3, 0.46), rnd.uniform(9, 14) * S, 0, 0, rnd, Dmax)
    for a, b, w0, w1, g0, g1 in sorted(segs, key=lambda s: -s[5]): poly_seg(dr, dg, a, b, w0, w1, g0, g1)  # 近い方を後に（順番は小さい方が勝つ）
    pts = [(c + math.cos(t) * r, c + math.sin(t) * r) for t, r in ((i / 9 * 6.283, rnd.uniform(26, 40) * S) for i in range(9))]  # 中心の砕けたくぼみ
    dr.polygon(pts, fill=255); dg.polygon(pts, fill=0)
    finish(R, Gc, (N, N), out, rnd)

def gouge(seed, out, Wd=1024, Hd=256):
    rnd = random.Random(seed); W, H = Wd * S, Hd * S; R = Image.new('L', (W, H), 0); Gc = Image.new('L', (W, H), 255); dr, dg = ImageDraw.Draw(R), ImageDraw.Draw(Gc)
    segs = []; n = 40; y = H / 2; px = 0.02 * W
    n = 70
    for i in range(1, n + 1):  # 本体の溝：左（始まり）→右（踏み込み）。後ろほど深く太い
        u = i / n; x = 0.02 * W + 0.96 * W * u; ny_ = H / 2 + rnd.uniform(-1, 1) * H * 0.05
        w = H * (0.04 + 0.12 * math.sin(math.pi * min(1, u * 1.05)) ** 0.6 * (0.4 + 0.6 * u)) * rnd.uniform(0.6, 1.3)
        segs.append(((px, y), (x, ny_), w, w, (i - 1) / n, u)); px, y = x, ny_
        if rnd.random() < 0.3:  # 横へ走る割れ
            sd = rnd.choice([-1, 1]); th = sd * rnd.uniform(1.0, 1.9); bx, by, bw = x, ny_ + sd * w * 0.6, w * 0.35
            for j in range(1, 6):
                th += rnd.uniform(-0.5, 0.5); nx_, nyy = bx + math.cos(th) * H * 0.06, by + math.sin(th) * H * 0.06
                segs.append(((bx, by), (nx_, nyy), bw * (1 - (j - 1) / 5) + S, bw * (1 - j / 5) + S, u, u + 0.04 * j)); bx, by = nx_, nyy
    for a, b, w0, w1, g0, g1 in sorted(segs, key=lambda s: -s[5]): poly_seg(dr, dg, a, b, w0, w1, g0, g1)
    finish(R, Gc, (Wd, Hd), out, rnd)

crack(3, 'terrain/assets/fx/crack_a.png'); crack(11, 'terrain/assets/fx/crack_b.png'); gouge(5, 'terrain/assets/fx/gouge.png')
