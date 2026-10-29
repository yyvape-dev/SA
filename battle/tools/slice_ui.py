# UI部品の切り出し：ユーザー作成のシート2枚（マゼンタ背景）→ battle/ui/p/*.webp（透過）。
#   battle/tools/ui_sheet_v1.png（941×1672）：顔の丸枠＋HP枠／四角の枠4つ／戦況の枠／区切り線／一時停止／パッド／下端の地面
#   battle/tools/ui_icons_v1.png（1024×1536）：技のアイコン6つ（枠つき）
# 使い方: python3 battle/tools/slice_ui.py   （リポジトリ直下で。numpy・scipy・Pillow・matplotlib が要る）
# 抜き方は claude/hq_pipeline.py の key_hq と同じ（縁の背景混じりを内側の色で塗り直す）。
import os, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc

OUT = 'battle/ui/p/'; os.makedirs(OUT, exist_ok=True)

def key_hq(a, min_blob=300, desat_all=False):
    bg = np.mean([a[:20, :20], a[:20, -20:]], axis=(0, 1, 2))   # 上の隅だけ（シートの下端は地面の絵で埋まっている）
    d = np.sqrt(((a - bg) ** 2).sum(-1)); al = np.clip((d - 45) / (130 - 45), 0, 1)
    core = al >= 0.98   # UIの線は1〜2pxと細いので、開き（opening）はかけない
    lab, n = ndi.label(core, structure=np.ones((3, 3)))
    keep = np.isin(lab, [k + 1 for k, z in enumerate(ndi.sum(core, lab, range(1, n + 1))) if z >= min_blob]) if n else core
    hsv0 = mc.rgb_to_hsv(np.clip(a, 0, 255) / 255); h0, s0, v0 = hsv0[..., 0] * 360, hsv0[..., 1], hsv0[..., 2]
    dist = ndi.distance_transform_edt(keep); band = (dist > 0) & (dist <= 3)
    keep &= ~(band & (((h0 >= 280) & (h0 <= 330) & (s0 > 0.35)) | ((v0 > 0.82) & (s0 < 0.28) & False)))
    region = ndi.binary_dilation(keep, iterations=2)
    st = ndi.generate_binary_structure(2, 1)
    src = keep   # 色の出どころ：芯そのもの（細い線は削ると消えるため、内側へは削らない）
    idx = ndi.distance_transform_edt(~src, return_distances=False, return_indices=True)
    col = np.where(src[..., None], a, a[idx[0], idx[1]])
    A = np.where(region, al, 0); A = np.clip((A - 0.35) / 0.5, 0, 1)
    A = np.where(ndi.binary_erosion(keep, structure=st, iterations=1), 1.0, A); A = np.where(A < 0.08, 0, A)
    hs = mc.rgb_to_hsv(np.clip(col, 0, 255) / 255); hh = hs[..., 0] * 360
    pk = (hh >= 280) & (hh <= 330) & (hs[..., 1] > 0.3) & (A > 0) & (True if desat_all else ~src)   # マゼンタかぶり（影の紫）の彩度を落とす。シートは紫を使っていないので全体、アイコンは縁だけ
    hs[..., 1] = np.where(pk, hs[..., 1] * 0.15, hs[..., 1])
    return np.dstack([mc.hsv_to_rgb(hs) * 255, A * 255]).astype(np.uint8)

def tight(r, pad=2):
    yy, xx = np.where(r[..., 3] > 10)
    y0, y1, x0, x1 = max(0, yy.min() - pad), min(r.shape[0], yy.max() + pad + 1), max(0, xx.min() - pad), min(r.shape[1], xx.max() + pad + 1)
    return r[y0:y1, x0:x1], (x0, y0)

def save(r, name, scale=1.0):
    im = Image.fromarray(r)
    if scale != 1.0: im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    im.save(OUT + name + '.webp', 'WEBP', quality=90, method=6, exact=True)
    return im.size

sheet = np.array(Image.open('battle/tools/ui_sheet_v1.png').convert('RGB')).astype(np.float32)
icons = np.array(Image.open('battle/tools/ui_icons_v1.png').convert('RGB')).astype(np.float32)
assert sheet.shape[:2] == (1672, 941) and icons.shape[:2] == (1536, 1024)
K = key_hq(sheet, desat_all=True); KI = key_hq(icons, min_blob=2000)
meta = {}

def part(name, box, src=K, scale=1.0):
    x0, y0, x1, y1 = box; r, off = tight(src[y0:y1, x0:x1].copy())
    meta[name] = {'src': [x0 + off[0], y0 + off[1]], 'size': list(save(r, name, scale))}
    return r

# ---- 上の帯 ----
part('hudframe', (18, 18, 818, 280))            # 顔の丸枠＋HPの枠2本（中は透過。HPと溜まりはDOMで下に描く）
for nm, x in (('sq_sword', 436), ('sq_helm', 559), ('sq_bag', 684), ('sq_star', 806)): part(nm, (x, 280, x + 118, 398), scale=0.5)
part('pause', (799, 951, 923, 1074), scale=0.6)
part('rule', (38, 530, 850, 584))               # 区切り線（長）：上の帯の下端

# ---- 戦況の枠：中央の菱形を消した枠と、動かす菱形 ----
x0, y0, x1, y1 = 18, 416, 923, 516
g = K[y0:y1, x0:x1].copy()
cx = 470 - x0
# 菱形の左右の端：中央付近で、縦に高く描かれている列
hcol = (g[..., 3] > 40).sum(0); wide = np.where(hcol[cx - 80:cx + 80] > hcol[cx - 140:cx - 100].max() + 4)[0]
L, R = cx - 80 + wide.min() - 3, cx - 80 + wide.max() + 4
dia = g[:, L:R].copy()
w = R - L; g[:, L:R] = g[:, L - w - 10:R - w - 10]   # 菱形の跡を、左隣の帯の絵で埋める
gr, off = tight(g); meta['gaugeframe'] = {'src': [x0 + off[0], y0 + off[1]], 'size': list(save(gr, 'gaugeframe')), 'dia': [L - off[0], R - off[0]]}
# 菱形だけを残す（横の帯の線を、菱形の形のマスクで落とす）
H, Wd = dia.shape[:2]; yy, xx = np.mgrid[0:H, 0:Wd]
ycol = np.where(dia[..., 3].sum(1) > 0)[0]; cyy = (ycol.min() + ycol.max()) / 2; hy = (ycol.max() - ycol.min()) / 2 + 1
msk = (np.abs(xx - Wd / 2) / (Wd / 2) + np.abs(yy - cyy) / hy) <= 1.04
dia[..., 3] = np.where(msk, dia[..., 3], 0)
dr, _ = tight(dia); meta['gaugedia'] = {'size': list(save(dr, 'gaugedia'))}

# ---- 操作盤 ----
pr = K[1030:1454, 22:450].copy()               # パッドの外輪：輪の絵だけ残す（中のつまみと、隅に入る旗・技の輪の端を落とす）
lab, n = ndi.label(pr[..., 3] > 0, structure=np.ones((3, 3))); Hh, Ww = lab.shape; yy, xx = np.mgrid[0:Hh, 0:Ww]
rr = np.hypot(xx - Ww / 2, yy - Hh / 2) / (Ww / 2)
mr = ndi.mean(rr, lab, range(1, n + 1)); ok = [k + 1 for k, v in enumerate(mr) if 0.6 < v < 1.08]
pr[..., 3] = np.where(np.isin(lab, ok), pr[..., 3], 0)
prr, offp = tight(pr); meta['padring'] = {'src': [22 + offp[0], 1030 + offp[1]], 'size': list(save(prr, 'padring'))}
part('knob', (140, 1149, 330, 1338))
gd = K[1370:1672].copy()                       # 下端の地面（岩・花・旗）：下端につながる絵だけ残す（上に重なるパッドと輪の端を落とす）
lab, n = ndi.label(gd[..., 3] > 0, structure=np.ones((3, 3))); bot = set(np.unique(lab[-3:])) - {0}
gd[..., 3] = np.where(np.isin(lab, list(bot)), gd[..., 3], 0)
gr2, off2 = tight(gd); meta['ground'] = {'src': [off2[0], 1370 + off2[1]], 'size': list(save(gr2, 'ground'))}

# ---- 技のアイコン（枠つき）：左上から 攻撃／衝撃波・吸引／突き・必殺／回避 ----
for nm, (bx, by) in (('ic_atk', (40, 40)), ('ic_shock', (520, 40)), ('ic_pull', (40, 512)), ('ic_thr', (520, 512)), ('ic_ult', (40, 988)), ('ic_dodge', (520, 988))):
    part(nm, (bx, by, bx + 464, by + 464), src=KI, scale=0.62 if nm == 'ic_atk' else 0.42)

# ---- 顔（仮）：ラナの顔の絵が来るまで、モックの顔を丸く切り抜いて使う。本番は battle/ui/p/face.webp を置けば差し替わる ----
mk = np.array(Image.open('battle/tools/mock_target.png').convert('RGB'))
cxm, cym, rm = 95, 91, 66
fc = mk[cym - rm:cym + rm, cxm - rm:cxm + rm].copy(); yy, xx = np.mgrid[0:2 * rm, 0:2 * rm]
fa = (np.clip((rm - np.hypot(xx - rm + .5, yy - rm + .5)) / 1.5, 0, 1) * 255).astype(np.uint8)
meta['face_tmp'] = {'size': list(save(np.dstack([fc, fa]), 'face_tmp'))}

json.dump(meta, open(OUT + 'meta.json', 'w'), ensure_ascii=False, indent=1, default=int)
print(json.dumps(meta, ensure_ascii=False, default=int))
