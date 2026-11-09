#!/usr/bin/env python3
"""Deterministic T4 casino physical-coordinate guide. NOT finished painted artwork.

Dimensions come from the 2026-11-09 design gate and the in-engine proxy:
7.00 m width, 4.17 m height, 5.04 m clear entrance, 2.86 m entrance height.
The outside is exact #FF00FF chroma. Interior is explicitly opaque, never a
background photograph. All coordinates are measured from local floor/left.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

W, H, SCALE = 1536, 1024, 204.8
BUILDING_W, BUILDING_H = 7.0, 4.17
OPEN_W, OPEN_H = 5.04, 2.86
X_ORIGIN = (W - BUILDING_W * SCALE) / 2.0
Y_FLOOR = H - 1
M = {
    "magenta": "#FF00FF",
    "stone": "#392346",
    "roof": "#592d58",
    "brass": "#bf8c36",
    "velvet": "#57204e",
    "interior": "#19111f",
    "interior_mid": "#2b1b35",
    "machine": "#7e447a",
    "screen": "#2b8a98",
    "table": "#926133",
    "gem": "#8d338c",
}

def pt(x: float, y: float) -> tuple[int, int]:
    return round(X_ORIGIN + x * SCALE), round(Y_FLOOR - y * SCALE)

def rect(draw: ImageDraw.ImageDraw, x0, y0, x1, y1, key):
    a, b = pt(x0, y1), pt(x1, y0)
    draw.rectangle((a[0], a[1], b[0], b[1]), fill=M[key])

def polygon(draw, points, key):
    draw.polygon([pt(x, y) for x, y in points], fill=M[key])

def build():
    im = Image.new("RGB", (W, H), M["magenta"])
    d = ImageDraw.Draw(im)
    # One freestanding casino silhouette, no street/floor outside building.
    polygon(d, [(0,0),(7,0),(7,3.70),(5.8,3.73),(3.5,4.17),(1.2,3.73),(0,3.70)], "brass")
    polygon(d, [(0.08,0),(6.92,0),(6.92,3.62),(5.76,3.65),(3.5,4.07),(1.24,3.65),(0.08,3.62)], "roof")
    rect(d,0.08,2.86,6.92,3.73,"velvet")
    rect(d,0.98,0,6.02,2.86,"interior")
    # Flat geometry-only depth cues. They represent interior building, not exterior scenery.
    rect(d,1.28,0.0,5.72,2.54,"interior_mid")
    rect(d,1.49,0.0,5.51,2.32,"interior")
    for x in (1.40, 1.90, 4.53, 5.05):
        rect(d,x,0.35,x+0.36,1.80,"machine")
        rect(d,x+0.04,0.92,x+0.32,1.48,"screen")
    rect(d,2.57,0.48,4.42,0.82,"table")
    rect(d,2.68,0.0,2.82,0.51,"table")
    rect(d,4.19,0.0,4.33,0.51,"table")
    # Precisely 5.04m clear structural span between pillars.
    rect(d,0,0,0.98,3.74,"stone")
    rect(d,6.02,0,7,3.74,"stone")
    rect(d,0.04,0.12,0.18,3.65,"brass")
    rect(d,0.80,0.12,0.94,3.65,"brass")
    rect(d,6.06,0.12,6.20,3.65,"brass")
    rect(d,6.82,0.12,6.96,3.65,"brass")
    rect(d,0.92,2.85,6.08,2.98,"brass")
    rect(d,0.12,3.48,6.88,3.60,"brass")
    polygon(d,[(3.5,3.27),(3.74,3.49),(3.5,3.69),(3.26,3.49)],"gem")
    for x in (0.50,6.50):
        rect(d,x-0.15,3.23,x+0.15,3.53,"gem")
    return im

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    dest = Path(args.out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im = build()
    im.save(dest, format="PNG")
    assert im.size == (1536,1024)
    assert im.getpixel((0,0)) == (255,0,255)
    assert im.getpixel((W-1,0)) == (255,0,255)
    assert abs((pt(7,0)[0] - pt(0,0)[0])/SCALE - BUILDING_W) < 0.01
    assert abs(OPEN_W - (6.02 - 0.98)) < 0.0001
    manifest = {
        "kind": "T4 deterministic geometry guide; not approved painting",
        "source": "test/sa2-t4-gamehall-relayout-20261109, in-engine replacement render and visual acceptance pending",
        "file": dest.name,
        "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
        "canvas_px": [W,H],
        "pixel_per_meter": SCALE,
        "local_x_range_m": [0,BUILDING_W],
        "local_y_range_m": [0,BUILDING_H],
        "world_x_range_m": [7.0,14.0],
        "facade_z_m": -6.5,
        "rear_interior_z_m": -9.3,
        "clear_opening_x_m": [0.98,6.02],
        "clear_opening_width_m": OPEN_W,
        "clear_opening_height_m": OPEN_H,
        "building_height_m": BUILDING_H,
        "chroma": "#FF00FF",
        "coordinate_to_pixel": "px=round(51.2+x*204.8); py=round(1023-y*204.8)",
        "restrictions": ["geometry test only","do not use as finished art","no people or outdoor floor", "D2 crops uppermost part of 4.17m facade"],
    }
    dest.with_suffix(".json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("T4_GUIDE_PASS", dest, manifest["sha256"], "size",im.size, "entrance_width_m",OPEN_W)

if __name__ == "__main__":
    main()
