# Real-ESRGAN animevideov3（SRVGGNetCompact, x4）を numpy だけで動かす。PyTorch なしで .pth を読む。
# 使い方: python3 esr_np.py <入力フォルダ> <出力フォルダ> [倍率=2]
#   透過PNG：RGB は透明部分を周りの色で埋めてから、アルファは3chにしてそれぞれモデルで拡大。最後に指定倍率へ縮める。
import sys, os, zipfile, pickle, glob, time
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def load_pth(path):
    z = zipfile.ZipFile(path); pre = z.namelist()[0].split('/')[0]
    class Storage:
        def __init__(self, key, dtype): self.key, self.dtype = key, dtype
    class U(pickle.Unpickler):
        def find_class(self, mod, name):
            if name == '_rebuild_tensor_v2':
                def rb(st, off, size, stride, *a):
                    buf = np.frombuffer(z.read(f'{pre}/data/{st.key}'), dtype=st.dtype)
                    return np.lib.stride_tricks.as_strided(buf[off:], shape=size, strides=[s * buf.itemsize for s in stride]).copy() if size else buf[off:off + 1].copy()
                return rb
            if name.endswith('Storage'): return {'FloatStorage': np.float32, 'HalfStorage': np.float16}.get(name, np.float32)
            if name == 'OrderedDict':
                import collections; return collections.OrderedDict
            return super().find_class(mod, name)
        def persistent_load(self, pid):
            _, dt, key, loc, n = pid; return Storage(key, dt)
    d = U(z.open(f'{pre}/data.pkl')).load()
    return d.get('params', d)

def conv(x, w, b):  # x: C,H,W  w: O,C,3,3
    C, H, W = x.shape; xp = np.pad(x, ((0, 0), (1, 1), (1, 1)))
    out = np.tensordot(w[:, :, 0, 0], xp[:, 0:H, 0:W], axes=([1], [0]))
    for i in range(3):
        for j in range(3):
            if i == 0 and j == 0: continue
            out += np.tensordot(w[:, :, i, j], xp[:, i:i + H, j:j + W], axes=([1], [0]))
    return out + b[:, None, None]

P = load_pth(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'realesr-animevideov3.pth'))
keys = sorted({int(k.split('.')[1]) for k in P}, key=int)
LAYERS = [(P[f'body.{i}.weight'].astype(np.float32), P.get(f'body.{i}.bias')) for i in keys]

def sr(img):  # img: H,W,3 float 0..1 -> 4x
    x = img.transpose(2, 0, 1).astype(np.float32)
    h = x
    for w, b in LAYERS:
        if w.ndim == 4: h = conv(h, w, b.astype(np.float32))
        else: a = w.reshape(-1, 1, 1); h = np.where(h >= 0, h, h * a)  # PReLU
    C, H, W = h.shape; r = 4
    h = h.reshape(3, r, r, H, W).transpose(0, 3, 1, 4, 2).reshape(3, H * r, W * r)  # pixel shuffle
    base = np.repeat(np.repeat(x, r, 1), r, 2)
    return np.clip((h + base).transpose(1, 2, 0), 0, 1)

def fill_rgb(a):  # 透明部分を一番近い不透明の色で埋める（縁ににじまないように）
    m = a[..., 3] > 8
    if not m.any(): return a[..., :3]
    idx = ndi.distance_transform_edt(~m, return_distances=False, return_indices=True)
    return a[..., :3][idx[0], idx[1]]

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]; scale = float(sys.argv[3]) if len(sys.argv) > 3 else 2
    os.makedirs(dst, exist_ok=True)
    fs = sorted(glob.glob(os.path.join(src, '*.png'))); t0 = time.time()
    for n, f in enumerate(fs):
        out = os.path.join(dst, os.path.basename(f))
        if os.path.exists(out): continue
        a = np.asarray(Image.open(f).convert('RGBA'))
        ys, xs = np.where(a[..., 3] > 0)
        if not len(ys): Image.new('RGBA', (round(a.shape[1] * scale), round(a.shape[0] * scale))).save(out); continue
        y0, y1, x0, x1 = max(0, ys.min() - 4), min(a.shape[0], ys.max() + 5), max(0, xs.min() - 4), min(a.shape[1], xs.max() + 5)
        crop = a[y0:y1, x0:x1]
        rgb = sr(fill_rgb(crop) / 255.0)
        al = sr(np.repeat(crop[..., 3:4] / 255.0, 3, 2)).mean(2)
        big = np.dstack([rgb * 255, al * 255]).round().astype(np.uint8)
        full = Image.new('RGBA', (a.shape[1] * 4, a.shape[0] * 4)); full.paste(Image.fromarray(big), (x0 * 4, y0 * 4))
        full.resize((round(a.shape[1] * scale), round(a.shape[0] * scale)), Image.LANCZOS).save(out)
        el = time.time() - t0; print(f'{n + 1}/{len(fs)} {os.path.basename(f)} {el / (n + 1):.1f}s/枚', flush=True)
