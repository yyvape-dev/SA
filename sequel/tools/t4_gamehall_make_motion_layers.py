#!/usr/bin/env python3
"""T4-only deterministic moving-layer extraction from the approved, SHAsummed facade.

Input is the ORIGINAL approved image encoded in Git on this branch. No regenerated characters
or slot machines. Source pixels are preserved; the background beneath movable objects is
inpainted and is a QA candidate, not a replacement for the approved source.
"""
import base64
import hashlib
import io
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PARTS = ROOT / "art/painted_bt_src/t4_approved_source_parts"
OUT = ROOT / "art/painted_bt/gamehall_motion"
EXPECTED_SHA = "d9e200bbdb5059613a3ea52804abe8f95cada42cb82e82e4705054ad140951a1"
# These polygons came from approved source image at 1585x992. Approved tight source is
# the same painting cropped at x=48. The conversion is deterministic, never AI tracing.
SOURCE_X_OFFSET = 48
POLYGONS = {
    "left_slot_machine": [(286,705),(322,692),(375,692),(410,713),(425,754),(428,958),(271,958),(257,934),(257,742)],
    "right_slot_machine": [(1076,713),(1112,694),(1192,696),(1228,721),(1245,758),(1247,958),(1092,959),(1066,939),(1063,739)],
    "cloaked_man": [(468,786),(503,780),(542,788),(579,830),(590,992),(468,992),(456,825)],
    "left_woman": [(369,794),(387,785),(431,801),(450,835),(456,992),(357,992),(357,817)],
    "right_woman": [(1118,795),(1137,785),(1165,797),(1180,834),(1188,992),(1103,992),(1101,818)],
    "roulette_cluster": [(557,814),(617,793),(963,793),(1034,823),(1042,992),(549,992),(546,835)],
}
TARGET_SIZE = (3200, 2000)

def normalize(source_image: Image.Image) -> Image.Image:
    # Matches t4_approved_prepare_preview.py exactly.
    scale_height = round(source_image.height * TARGET_SIZE[0] / source_image.width)
    enlarged = source_image.resize((TARGET_SIZE[0], scale_height), Image.Resampling.LANCZOS)
    top = scale_height - TARGET_SIZE[1]
    assert 130 <= top <= 136, top
    return enlarged.crop((0, top, *TARGET_SIZE))

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> None:
    data = base64.b64decode("".join((SOURCE_PARTS / f"part{i:02d}.b64").read_text(encoding="ascii").strip() for i in range(9)), validate=True)
    assert hashlib.sha256(data).hexdigest() == EXPECTED_SHA, "Approved master source SHA mismatch"
    master = Image.open(io.BytesIO(data)).convert("RGBA")
    assert master.size == (1488, 992), master.size
    OUT.mkdir(parents=True, exist_ok=True)
    total_mask = Image.new("L", master.size, 0)
    layer_masks = {}
    manifest = {"source_sha256": EXPECTED_SHA, "source_size": list(master.size), "output_size": list(TARGET_SIZE),
                "model_generation": False, "characters_redrawn": False, "masks": {},
                "motion": {"loop_frames": 24, "duration_s": 2.0}}
    for name, points in POLYGONS.items():
        mask = Image.new("L", master.size, 0)
        draw = ImageDraw.Draw(mask)
        shifted = [(x-SOURCE_X_OFFSET, y) for x,y in points]
        draw.polygon(shifted, fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(0.55))
        layer_masks[name] = mask
        total_mask = Image.fromarray(np.maximum(np.asarray(total_mask), np.asarray(mask)).astype("uint8"), "L")
        obj = master.copy()
        obj.putalpha(mask)
        full = normalize(obj)
        destination = OUT / (name + ".png")
        full.save(destination, optimize=True)
        assert full.size == TARGET_SIZE
        manifest["masks"][name] = {
            "source_polygon_1585x992": points,
            "output_alpha_bbox": list(full.getbbox()),
            "sha256": sha(destination),
            "source_pixel_identity": "Source RGB, multiplied by alpha; original pixels not repainted"
        }
    # Only the union of removed subjects is reconstructed. On all other pixels, the
    # pristine approved image is retained. Transparent background inpainting not used.
    hole = np.where(np.asarray(total_mask) > 32, 255, 0).astype("uint8")
    hole = cv2.dilate(hole, np.ones((5,5),dtype=np.uint8), iterations=1)
    rgb = np.array(master.convert("RGB"))
    filled = cv2.inpaint(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),hole,6,cv2.INPAINT_TELEA)
    filled_rgb = cv2.cvtColor(filled,cv2.COLOR_BGR2RGB)
    plate = Image.fromarray(filled_rgb, "RGB").convert("RGBA")
    plate.putalpha(master.getchannel("A"))
    bg = normalize(plate)
    bgpath = OUT / "background_clean.png"
    bg.save(bgpath, optimize=True)
    manifest["background_clean_sha256"] = sha(bgpath)
    manifest["background_method"] = "OpenCV Telea native-resolution inpaint only under extracted polygon masks"
    manifest["background_qa"] = "NOT TESTED in Godot until real animation screenshot visual check"
    # Pixel-perfect proof that the approved exterior remains unchanged in the background.
    diff = np.abs(np.array(master.convert("RGB"),dtype=np.int16) - np.array(plate.convert("RGB"),dtype=np.int16))
    unchanged = hole == 0
    assert np.max(diff[unchanged]) == 0, "Inpainting touched source outside cutout"
    # Composite expected rest state with the same source-registered full-frame layer textures.
    composite = bg.copy()
    for name in POLYGONS:
        composite.alpha_composite(Image.open(OUT/(name+".png")).convert("RGBA"))
    preview = OUT/"layered_static_preview.png"
    composite.save(preview, optimize=True)
    manifest["static_preview_sha256"] = sha(preview)
    (OUT/"motion_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("T4_MOTION_LAYER_PREP_PASS",json.dumps({
        "source_sha256":EXPECTED_SHA,"sprites":len(POLYGONS),"pixels":list(TARGET_SIZE),
        "plate_sha":manifest["background_clean_sha256"],"preview_sha":manifest["static_preview_sha256"],
        "background_qa":"NOT_TESTED_IN_GODOT"},ensure_ascii=False))

if __name__ == "__main__":
    main()
