#!/usr/bin/env python3
"""T4 character extraction QA. Fail closed on unreviewed anatomy.

Source: approved T4 source-registered PNGs. No redraw or rescaling.
An arbitrary rectangle is NEVER treated as an anatomical joint.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art/painted_bt/gamehall_motion"
OUT = SRC / "character_joints"
ACTORS = ("cloaked_man", "left_woman", "right_woman")
EXPECTED = {
    "cloaked_man": "d12ee49fcec1661ea5c929d1279e53f3a81fedc5a453b861bdf966c83dc63149",
    "left_woman": "eda6ed9e5d3c73f61088ca677cb7fd7b68da31ea8df2708be9969473e89fb040",
    "right_woman": "0a43bbd83e2e4ed2b58eaadfa9417e5aa277d7504dd107dd9b8f9401c00f72d8",
}
PARTS = ("head", "left_upper_arm", "left_forearm", "left_hand",
         "right_upper_arm", "right_forearm", "right_hand", "body")
# An artist-approved polygon must be authored in the SOURCE layer's native
# 3200x2000 pixel coordinates. No guessed bounding-box fractions permitted.
REQUIRED = set(PARTS[:-1])

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_approved_masks(actor, image):
    path = SRC / "character_joint_polygons.json"
    if not path.is_file():
        raise RuntimeError("JOINT_QA_BLOCKED: missing artist-reviewed character_joint_polygons.json; "
                           "rectangular proxy masks are prohibited")
    data = json.loads(path.read_text(encoding="utf-8"))
    entry = data.get("characters", {}).get(actor)
    if not entry or entry.get("source_sha256") != EXPECTED[actor] or entry.get("reviewed") is not True:
        raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: missing source-locked reviewed polygons")
    polygons = entry.get("polygons", {})
    if set(polygons) != REQUIRED:
        raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: require exact head/arm/hand polygons")
    masks = {}
    for name in PARTS[:-1]:
        points = polygons[name]
        if len(points) < 3 or any(len(p) != 2 or not all(isinstance(v, int) for v in p)
                                  or not (0 <= p[0] < 3200 and 0 <= p[1] < 2000)
                                  for p in points):
            raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}/{name}: invalid native pixel polygon")
        mask = Image.new("L", image.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=255)
        masks[name] = np.asarray(mask) != 0
    return masks

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"canvas": [3200, 2000], "status": "BLOCKED_UNTIL_ANATOMY_REVIEW",
              "source_regeneration": False, "characters": {}}
    for actor in ACTORS:
        path = SRC / f"{actor}.png"
        if digest(path) != EXPECTED[actor]:
            raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: approved source checksum mismatch")
        image = Image.open(path).convert("RGBA")
        if image.size != (3200, 2000):
            raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: invalid canvas {image.size}")
        rgba = np.asarray(image).copy()
        alpha = rgba[:, :, 3]
        masks = load_approved_masks(actor, image)
        # Ownership is disjoint; overlaps are rejected instead of silently
        # assigning pixels to an arbitrary hand or sleeve.
        count = np.zeros(alpha.shape, dtype=np.uint8)
        for name, mask in masks.items():
            if not np.any(mask & (alpha > 0)):
                raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}/{name}: empty visible anatomy")
            count += mask.astype(np.uint8)
        if np.any((count > 1) & (alpha > 0)):
            raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: overlapping source-visible joint polygons")
        masks["body"] = count == 0
        results = {}
        reconstructed = np.zeros_like(rgba)
        for name in PARTS:
            pixels = rgba.copy()
            pixels[:, :, 3] = np.where(masks[name], alpha, 0)
            # Source RGB preserved even under alpha=0, to prevent repaint.
            target = OUT / f"{actor}_{name}.png"
            Image.fromarray(pixels, "RGBA").save(target, optimize=True)
            reconstructed[masks[name]] = rgba[masks[name]]
            ys, xs = np.where(masks[name] & (alpha > 0))
            results[name] = {"file": target.name, "sha256": digest(target),
                             "bbox": [int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)]}
        if not np.array_equal(reconstructed[alpha > 0], rgba[alpha > 0]):
            raise RuntimeError(f"JOINT_QA_BLOCKED: {actor}: static source pixel mismatch")
        # 1:1 visual review sheet; no inferred hidden pixels.
        x0, y0, x1, y1 = image.getbbox()
        pad = 12
        sw, sh = x1-x0, y1-y0
        sheet = Image.new("RGBA", ((sw+pad)*4, (sh+pad)*2), (40,40,40,255))
        for i, name in enumerate(PARTS):
            part = Image.open(OUT / results[name]["file"])
            sheet.alpha_composite(part.crop((x0,y0,x1,y1)), ((i%4)*(sw+pad), (i//4)*(sh+pad)))
        preview = OUT / f"{actor}_contact_sheet.png"
        sheet.save(preview)
        report["characters"][actor] = {"source_sha256": digest(path), "parts": results,
                                       "contact_sheet": preview.name,
                                       "static_visible_pixels_exact": True,
                                       "hidden_anatomy_reconstructed": False,
                                       "animation_ready": False}
    report["status"] = "STATIC_PIXEL_QA_PASS_ANATOMY_MOTION_REVIEW_REQUIRED"
    (OUT / "manifest.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("T4_CHARACTER_STATIC_PIXEL_QA_PASS; animation_ready=false")

if __name__ == "__main__":
    main()
