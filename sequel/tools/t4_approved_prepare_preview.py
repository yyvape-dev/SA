#!/usr/bin/env python3
"""T4 approved art preview: lossless Git source recovery, deterministic 3200x2000 enlargement.
No AI enhancement, no invented pixels, and no changes to the original.
"""
import base64
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PARTS = ROOT / "art/painted_bt_src/t4_approved_source_parts"
OUTPUT = ROOT / "art/painted_bt/gamehall_approved_16m_preview.png"
EXPECTED_SHA256 = "d9e200bbdb5059613a3ea52804abe8f95cada42cb82e82e4705054ad140951a1"
PART_NAMES = [f"part{i:02d}.b64" for i in range(9)]

def main():
    encoded = "".join((PARTS / name).read_text(encoding="ascii").strip() for name in PART_NAMES)
    data = base64.b64decode(encoded, validate=True)
    sha = hashlib.sha256(data).hexdigest()
    assert sha == EXPECTED_SHA256, f"source hash mismatch {sha}"
    source = Image.open(io.BytesIO(data)).convert("RGBA")
    assert source.size == (1488, 992), source.size
    assert source.getbbox() == (0, 0, 1488, 992)
    # Width 16m gives 200 pixels/m; natural height 10.666m.
    # Crop ONLY the top of the enlarged original down to 10.00m:
    # 3200x2000 -> precisely 200 pixels/m in both axes.
    target_w, target_h = 3200, 2000
    resampled_h = round(source.height * target_w / source.width)
    enlarged = source.resize((target_w, resampled_h), Image.Resampling.LANCZOS)
    crop_top = resampled_h - target_h
    assert 130 <= crop_top <= 136, crop_top
    output = enlarged.crop((0, crop_top, target_w, resampled_h))
    assert output.size == (target_w, target_h)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, optimize=True)
    qa = {
        "approved_source_tight_png_sha256": sha,
        "approved_source_size": list(source.size),
        "output_file": OUTPUT.name,
        "output_size": list(output.size),
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "method": "deterministic Pillow Lanczos; NOT AI upscaling",
        "no_geometric_stretch": True,
        "crop_top_pixels_after_upscale": crop_top,
        "facade_width_m": 16.0,
        "visible_facade_height_m": 10.0,
        "pixel_per_meter": 200.0,
        "cropped_upper_facade": True,
        "character_motion": "NOT TESTED",
        "new_map_integration": "NOT TESTED"
    }
    manifest = OUTPUT.with_suffix(".json")
    manifest.write_text(json.dumps(qa, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("T4_APPROVED_PREP_PASS", json.dumps(qa, ensure_ascii=False))

if __name__ == "__main__":
    main()
