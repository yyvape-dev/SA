"""Import user-delivered 06/08 facades without resizing or repainting.
Run: python3 sequel/tools/import_facility_06_08.py
Only edge-connected near-magenta pixels become transparent; artwork RGB is unchanged.
Dependencies: Pillow, numpy, scipy (same as existing cut_bt.py).
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
REPORT = []
for name, size in [("w_bar", (1280, 865)), ("w_cabaret", (1280, 888))]:
    source = ROOT / "art/painted_bt_src" / (name + "_user_20261109.jpg")
    rgb = np.asarray(Image.open(source).convert("RGB"))
    if (rgb.shape[1], rgb.shape[0]) != size:
        raise ValueError(f"{name}: unexpected source size; review before replacing")
    r, g, b = (rgb[:, :, i].astype(np.int16) for i in range(3))
    key = (r > 180) & (b > 180) & (g < 100) & (r - g > 110) & (b - g > 110)
    labels, _ = ndimage.label(key)
    edge_labels = np.unique(np.concatenate([labels[:, 0], labels[:, -1]]))
    remove = np.isin(labels, edge_labels[edge_labels != 0])
    alpha = np.where(remove, 0, 255).astype(np.uint8)
    rgba = np.dstack((rgb, alpha))
    destination = ROOT / "art/painted_bt" / (name + ".png")
    Image.fromarray(rgba).save(destination, optimize=True)
    assert np.array_equal(np.asarray(Image.open(destination))[:, :, :3], rgb)
    REPORT.append({"id": name, "size": list(size), "transparent_pixels": int(remove.sum()),
                   "opaque_pixels": int((~remove).sum()), "rgb_unchanged": True,
                   "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                   "png_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
print(json.dumps(REPORT, indent=2))
