# 使い方: 元のシートを /home/claude/lk/bak/ に置いて python3 tools/add_rim.py <ファイル名>…（入出力のフォルダは中で固定。使うときに書き換える）
# 明るい土の地面に溶けないよう、輪郭に暗い縁（約4px、柔らかく）を足し、少しだけコントラストを上げる
import sys, numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
for f in sys.argv[1:]:
    im=Image.open(f'/home/claude/lk/bak/{f}').convert('RGBA'); a=np.array(im).astype(np.float32)
    al=a[...,3]/255; rgb=a[...,:3]
    rgb=np.clip((rgb-128)*1.08+128-4,0,255)  # コントラスト少し上げ、少し暗く
    d=ndi.grey_dilation(al,size=(7,7)); d=ndi.gaussian_filter(d,1.2)
    rim=np.clip(d-al,0,1)*0.75
    outA=al+rim*(1-al)
    col=(rgb*al[...,None]+np.array([28,20,16])*rim[...,None]*(1-al[...,None]))/np.maximum(outA[...,None],1e-6)
    o=np.dstack([np.clip(col,0,255),outA*255]).astype(np.uint8)
    Image.fromarray(o).save(f'/home/claude/sa/ally/{f}','WEBP',quality=90,method=6); print(f)
