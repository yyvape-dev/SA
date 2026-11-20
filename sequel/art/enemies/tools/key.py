import sys, os, json, subprocess, numpy as np
from PIL import Image
from scipy import ndimage as ndi
from multiprocessing import Pool

SRC = os.environ.get('SRC','src')+''; OUT = os.environ.get('KEYED','_work/keyed')

def frames(path):
    w, h = map(int, subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_entries','stream=width,height','-of','csv=p=0',path]).decode().strip().split(','))
    p = subprocess.Popen(['ffmpeg','-v','error','-i',path,'-f','rawvideo','-pix_fmt','rgb24','-'], stdout=subprocess.PIPE)
    while True:
        b = p.stdout.read(w*h*3)
        if len(b) < w*h*3: break
        yield np.frombuffer(b, np.uint8).reshape(h, w, 3)

def key(rgb):
    a = rgb.astype(np.float32)
    r, g, b = a[...,0], a[...,1], a[...,2]
    d = g - np.maximum(r, b)                      # 緑っぽさ
    al = np.clip(1 - (d - 25) / 70, 0, 1)
    al = ndi.median_filter(al, 3)
    core = al >= 0.98
    idx = ndi.distance_transform_edt(~core, return_distances=False, return_indices=True)
    col = np.where(core[..., None], a, a[idx[0], idx[1]])   # 縁は最寄りの不透明色で置換
    m = np.maximum(col[...,0], col[...,2])
    col[...,1] = np.minimum(col[...,1], m + 12)              # 緑かぶり除去
    al = np.where(al < 0.12, 0, al)
    # 小さなゴミ除去
    lab, n = ndi.label(al > 0.5)
    if n > 1:
        sz = ndi.sum(np.ones_like(al), lab, range(1, n+1))
        keep = np.isin(lab, 1 + np.where(sz >= max(150, sz.max()*0.002))[0])
        keep = ndi.binary_dilation(keep, iterations=3)
        al = al * keep
    return np.dstack([col, al*255]).astype(np.uint8)

def run(name):
    od = f'{OUT}/{name}'; os.makedirs(od, exist_ok=True)
    meta = []
    for i, f in enumerate(frames(f'{SRC}/{name}.mp4')):
        k = key(f)
        al = k[...,3] > 128
        ys, xs = np.where(al)
        bb = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None
        edge = bool(al[0].any() or al[-1].any() or al[:,0].any() or al[:,-1].any())
        Image.fromarray(k).save(f'{od}/{i:03d}.png', compress_level=1)
        meta.append({'bbox': bb, 'edge': edge})
    json.dump({'size': [int(f.shape[1]), int(f.shape[0])], 'frames': meta}, open(f'{od}/meta.json', 'w'))
    return name, len(meta), sum(m['edge'] for m in meta)

if __name__ == '__main__':
    names = sorted(n[:-4] for n in os.listdir(SRC) if n.endswith('.mp4'))
    with Pool(os.cpu_count()) as p:
        for r in p.imap_unordered(run, names): print(*r, flush=True)
