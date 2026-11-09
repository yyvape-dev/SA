#!/usr/bin/env python3
"""T4: deterministic chroma removal of the user's actual supplied casino JPEG.

This transforms ONLY the exterior magenta into alpha; the casino interior,
people, machines, detail, light and shape are never generated or repainted.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

EXPECTED_SOURCE_SHA = "cca3607a782ac26b15de4651dc5551658d5ba92fbdd71893b22e43892e08220b"
EXPECTED_SOURCE_SIZE = (1535, 1024)
TARGET_SIZE = (1536, 1024)

def prepare(source: Path, output: Path):
    raw = source.read_bytes()
    source_sha = hashlib.sha256(raw).hexdigest()
    if source_sha != EXPECTED_SOURCE_SHA:
        raise SystemExit("T4_ART_FAIL: wrong source file SHA-256: " + source_sha)
    img = Image.open(source).convert("RGB")
    if img.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"T4_ART_FAIL: source image size {img.size} (expected {EXPECTED_SOURCE_SIZE})")
    a = np.asarray(img)
    r, g, b = (a[:, :, k].astype(np.int16) for k in range(3))
    # Exterior-connected magenta only. Interior purple casino artwork is protected.
    chroma = (r > 185) & (b > 185) & (g < 100) & (r + b > 430) & (b - r > -45)
    seeds = np.zeros(chroma.shape, dtype=bool)
    seeds[0] = chroma[0]
    seeds[-1] = chroma[-1]
    seeds[:, 0] = chroma[:, 0]
    seeds[:, -1] = chroma[:, -1]
    outside = ndi.binary_propagation(seeds, mask=chroma)
    edge = (r > 148) & (b > 145) & (g < 143) & (r + b > 360) & (b - r > -70)
    outside = ndi.binary_propagation(outside, mask=edge)
    alpha = np.where(outside, 0, 255).astype(np.uint8)
    rgba = Image.fromarray(np.dstack([a, alpha]), "RGBA")
    if rgba.size != TARGET_SIZE:
        rgba = rgba.resize(TARGET_SIZE, Image.Resampling.BICUBIC)
    output.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(output, optimize=True)
    assert rgba.mode == "RGBA" and rgba.size == TARGET_SIZE
    for pos in [(0,0), (TARGET_SIZE[0]-1,0), (0,TARGET_SIZE[1]-1), (TARGET_SIZE[0]-1,TARGET_SIZE[1]-1)]:
        if rgba.getpixel(pos)[3] != 0:
            raise SystemExit(f"T4_ART_FAIL: nontransparent magenta corner {pos}")
    bbox = rgba.getchannel("A").getbbox()
    qa = {
        "artifact": "user-supplied casino art, mechanical exterior-chroma transparency only",
        "source_file": source.name, "source_sha256": source_sha,
        "source_px": list(img.size), "output_file": output.name,
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "output_px": list(rgba.size), "alpha_bbox": list(bbox) if bbox else [],
        "transparent_pixels_before_resize": int(outside.sum()),
        "characters": "painted in source; do NOT add NPC sprites over the picture",
        "outside": "transparent; no extra street floor or background is painted",
        "godot_acceptance": "requires actual viewport screenshots"
    }
    output.with_name("gamehall_user_rgba_qa.json").write_text(json.dumps(qa, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    # T4 scale correction: only crop transparent padding; never repaint pixels.
    # Nonzero alpha defines the visible physical boundary, not the source canvas.
    visible_bbox = rgba.getchannel("A").getbbox()
    if visible_bbox is None:
        raise SystemExit("T4_TRIM_FAIL: painting has no visible pixels")
    trimmed = rgba.crop(visible_bbox)
    trim_path = output.with_name("gamehall_user_trimmed.png")
    trimmed.save(trim_path, format="PNG", optimize=True)
    reloaded = Image.open(trim_path).convert("RGBA")
    if not np.array_equal(np.asarray(reloaded), np.asarray(trimmed)):
        raise SystemExit("T4_TRIM_FAIL: crop has changed source RGBA pixels")
    w, h = reloaded.size
    visible_ratio = w / h
    target_ratio = 7.0 / 4.17
    if abs(visible_ratio / target_ratio - 1.0) > 0.015:
        raise SystemExit("T4_TRIM_FAIL: image/physical aspect mismatch: " + str(visible_ratio))
    alp = np.asarray(reloaded.getchannel("A"))
    partly_transparent = int(((alp > 0) & (alp < 255)).sum())
    trim_qa = {
        "source_file": source.name,
        "source_sha256": source_sha,
        "original_rgba": output.name,
        "original_rgba_sha256": qa["output_sha256"],
        "original_canvas_px": list(rgba.size),
        "alpha_bbox_xyxy_exclusive": list(visible_bbox),
        "trimmed_file": trim_path.name,
        "trimmed_sha256": hashlib.sha256(trim_path.read_bytes()).hexdigest(),
        "trimmed_px": [w, h],
        "pixel_identity_with_source_crop": True,
        "visible_image_aspect": visible_ratio,
        "target_world_m": [7.0, 4.17],
        "target_world_aspect": target_ratio,
        "pixels_per_meter": [w / 7.0, h / 4.17],
        "partly_transparent_pixels": partly_transparent,
        "human_halo_and_visual_review": "NOT TESTED; inspect D2 rendered screenshot",
    }
    trim_qa_file = output.with_name("gamehall_user_trimmed_qa.json")
    trim_qa_file.write_text(json.dumps(trim_qa, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("T4_TRIM_PASS", json.dumps(trim_qa, ensure_ascii=False))
    print("T4_ART_PASS", json.dumps(qa, ensure_ascii=False))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    prepare(args.source, args.out)

if __name__ == "__main__":
    main()
