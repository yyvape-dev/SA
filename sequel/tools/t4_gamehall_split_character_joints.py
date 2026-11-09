#!/usr/bin/env python3
"""Mechanically segment three approved T4 painted character layers.

No image generation, rescaling, colour correction or synthetic anatomy.
Every part retains the full 3200x2000 source coordinate system. The joints are
conservative rectangular masks, not verified anatomical segmentation.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art/painted_bt/gamehall_motion"
DEST = SRC / "character_joints"
ACTORS = ("cloaked_man", "left_woman", "right_woman")
# Relative to each source layer's nonzero alpha bbox (x0,y0,x1,y1).
# Keep feet and hips in body; overlap joints intentionally by 2-4%.
REGIONS = {
    "head": (0.28, 0.00, 0.75, 0.22),
    "left_upper_arm": (0.06, 0.19, 0.34, 0.43),
    "left_forearm": (0.02, 0.38, 0.32, 0.62),
    "left_hand": (0.00, 0.57, 0.32, 0.70),
    "right_upper_arm": (0.69, 0.19, 0.97, 0.43),
    "right_forearm": (0.70, 0.38, 0.99, 0.62),
    "right_hand": (0.70, 0.57, 1.00, 0.70),
}
ORDER = tuple(REGIONS)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def split(actor):
    source = SRC / (actor + ".png")
    image = Image.open(source).convert("RGBA")
    assert image.size == (3200, 2000), (actor, image.size)
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    assert bbox is not None, actor
    x0, y0, x1, y1 = bbox
    w, h = x1-x0, y1-y0
    # Nonoverlapping ownership in draw order: hands > forearms > upper arms > head.
    # This makes a pixel-exact static recomposition possible; occluded anatomy is
    # not invented. These pieces need source-specific joint review before animation.
    ownership = Image.new("L", image.size, 0)
    parts = {}
    for part in reversed(ORDER):
        a,b,c,d = REGIONS[part]
        rect = (round(x0+a*w), round(y0+b*h), round(x0+c*w), round(y0+d*h))
        mask = Image.new("L", image.size, 0)
        ImageDraw.Draw(mask).rectangle(rect, fill=255)
        # Restrict to source alpha; avoid making a bounding-box-shaped cutout.
        import PIL.ImageChops
        visible = PIL.ImageChops.multiply(alpha, mask)
        visible = PIL.ImageChops.multiply(visible, PIL.ImageChops.invert(ownership))
        ownership = PIL.ImageChops.lighter(ownership, mask)
        cut = image.copy()
        cut.putalpha(visible)
        target = DEST / (actor + "_" + part + ".png")
        cut.save(target, optimize=True)
        parts[part] = {"file": target.name, "bbox": list(visible.getbbox() or (0,0,0,0)),
                       "source_rect": list(rect), "sha256": sha(target)}
    body_alpha = PIL.ImageChops.multiply(alpha, PIL.ImageChops.invert(ownership))
    body = image.copy()
    body.putalpha(body_alpha)
    body_path = DEST / (actor + "_body.png")
    body.save(body_path, optimize=True)
    # Exact alpha restoration; RGB equality only for pixels with nonzero alpha.
    restored = Image.new("RGBA", image.size)
    restored.alpha_composite(body)
    for part in ORDER:
        restored.alpha_composite(Image.open(DEST / parts[part]["file"]).convert("RGBA"))
    import numpy as np
    expected = np.asarray(image)
    actual = np.asarray(restored)
    alpha_equal = bool(np.array_equal(expected[:,:,3], actual[:,:,3]))
    rgb_equal = bool(np.array_equal(expected[:,:,:3][expected[:,:,3]==255],
                                    actual[:,:,:3][expected[:,:,3]==255]))
    assert alpha_equal and rgb_equal, actor + ": static composite mismatch"
    return {"source": str(source.relative_to(ROOT)), "source_sha256": sha(source),
            "source_alpha_bbox": list(bbox), "body": body_path.name,
            "parts": parts, "static_alpha_exact": alpha_equal,
            "opaque_rgb_exact": rgb_equal, "joint_anatomy_approved": False,
            "hidden_anatomy_reconstructed": False}

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    result = {"canvas": [3200,2000], "generation": False,
              "method": "deterministic source-alpha clipped masks",
              "warning": "Provisional joint boundaries: anatomy and motion not yet approved",
              "characters": {actor: split(actor) for actor in ACTORS}}
    (DEST / "manifest.json").write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n")
    print("T4_CHARACTER_JOINT_SPLIT_PASS actors=3 exact_static_recomposition=true provisional_anatomy=true")

if __name__ == "__main__":
    main()
