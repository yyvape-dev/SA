#!/usr/bin/env python3
"""Extract source-faithful character-only silhouettes from the T4 source layers.

The six T4 moving layers are environment-inclusive painted polygon crops.
This pass removes surrounding scene pixels BEFORE any joint rigging.
It is conservative: ambiguous pixels remain review candidates, never claimed
as anatomy. Original RGB is copied unchanged. No generated content.
"""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/"art/painted_bt/gamehall_motion"
OUT=SRC/"character_isolated"
# Approximate person regions, measured in full 3200x2000 coordinates from
# the source registered image. These are GrabCut seed boxes, NOT joint masks.
# Head, torso and feet are included; stools and cabinets lie outside.
PERSON_BOXES={
 "cloaked_man": (900,1565,1035,1935),
 "left_woman": (735,1565,849,1900),
 "right_woman": (2300,1565,2422,1910),
}

def process(name, box):
    im=Image.open(SRC/f"{name}.png").convert("RGBA")
    assert im.size==(3200,2000)
    arr=np.array(im)
    alpha=arr[:,:,3]
    # Crop to source visible extent to reduce memory, preserve global coords.
    ys,xs=np.where(alpha>8)
    x0,x1=max(0,int(xs.min())-5),min(3200,int(xs.max())+6)
    y0,y1=max(0,int(ys.min())-5),min(2000,int(ys.max())+6)
    rgb=arr[y0:y1,x0:x1,:3].copy()
    a=alpha[y0:y1,x0:x1]
    h,w=a.shape
    bx0,by0,bx1,by1=box
    # GrabCut uses original RGB pixels only. Source exterior is sure background.
    mask=np.full((h,w),cv2.GC_BGD,np.uint8)
    mask[a>8]=cv2.GC_PR_BGD
    xlo=max(0,bx0-x0);xhi=min(w,bx1-x0)
    ylo=max(0,by0-y0);yhi=min(h,by1-y0)
    if xlo>=xhi or ylo>=yhi:raise RuntimeError(name+": seed rectangle empty")
    mask[ylo:yhi,xlo:xhi]=cv2.GC_PR_FGD
    # Small central torso is the sole definite foreground; do not mark an
    # entire rectangle as definite person (would preserve background).
    cx=(xlo+xhi)//2
    cy=ylo+int((yhi-ylo)*.40)
    rx=max(3,(xhi-xlo)//9);ry=max(4,(yhi-ylo)//11)
    cv2.ellipse(mask,(cx,cy),(rx,ry),0,0,360,cv2.GC_FGD,-1)
    mask[a<=8]=cv2.GC_BGD
    bg=np.zeros((1,65),np.float64);fg=np.zeros((1,65),np.float64)
    cv2.grabCut(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),mask,None,bg,fg,8,cv2.GC_INIT_WITH_MASK)
    fgmask=np.isin(mask,(cv2.GC_FGD,cv2.GC_PR_FGD)).astype("uint8")
    # Keep connected foreground associated with torso seed; disjoint tiny
    # pieces are uncertain and excluded from automatic approval.
    n,labels,stats,_=cv2.connectedComponentsWithStats(fgmask,8)
    center_label=int(labels[min(h-1,cy),min(w-1,cx)])
    if center_label==0:raise RuntimeError(name+": lost definite torso seed")
    selected=(labels==center_label).astype("uint8")
    selected=cv2.morphologyEx(selected,cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    # Only alpha is modified. Do not recolor or invent hidden anatomy.
    isolated=np.zeros_like(arr)
    isolated[:,:,:3]=arr[:,:,:3]
    isolated[y0:y1,x0:x1,3]=(a.astype("uint16")*selected).astype("uint8")
    OUT.mkdir(parents=True,exist_ok=True)
    dest=OUT/f"{name}_person_candidate.png"
    Image.fromarray(isolated,"RGBA").save(dest,optimize=True)
    # Side-by-side source/person extraction at 3x nearest neighbour for review.
    left=Image.fromarray(arr,"RGBA").crop((x0,y0,x1,y1))
    right=Image.fromarray(isolated,"RGBA").crop((x0,y0,x1,y1))
    preview=Image.new("RGBA",(2*w,h),(38,38,38,255))
    preview.alpha_composite(left,(0,0));preview.alpha_composite(right,(w,0))
    preview.resize((w*6,h*3),Image.Resampling.NEAREST).convert("RGB").save(OUT/f"{name}_review.png")
    # Pixels outside the selected mask are deliberately rejected, not altered.
    count=int(np.count_nonzero(isolated[:,:,3]))
    if count<100:raise RuntimeError(name+": implausibly few foreground pixels")
    return {"source_box":box,"candidate":dest.name,"review":f"{name}_review.png",
            "alpha_pixels":count,"original_rgb_unchanged":True,
            "human_review":"REQUIRED","joint_rigging":"BLOCKED_UNTIL_REVIEW"}

def main():
    result={n:process(n,b) for n,b in PERSON_BOXES.items()}
    (OUT/"isolation_manifest.json").write_text(json.dumps(result,indent=2)+"\n")
    print("T4_PERSON_ISOLATION_CANDIDATES_CREATED count=3; review=REQUIRED")
if __name__=="__main__":main()
