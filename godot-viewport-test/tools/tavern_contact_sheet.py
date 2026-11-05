"""Arrange unmodified Godot screenshots and measure existing-pole occlusion."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
import numpy as np
root = Path(__file__).resolve().parents[1] / 'captures/tavern_fit'
canvas = Image.new('RGB', (1280, 3 * 760), '#20222c')
draw = ImageDraw.Draw(canvas)
for i, name in enumerate(['01_front', '02_oblique', '03_wide']):
    im = Image.open(root / (name + '.png')).convert('RGB')
    im.thumbnail((1280, 720))
    canvas.paste(im, (0, i * 760 + 40))
    draw.text((18, i * 760 + 12), name + ' | REAL GODOT VIEWPORT', fill='white')
canvas.save(root / 'comparison.png')
counts = {}
for name in ['04_behind_pole', '05_front_of_pole']:
    a = np.array(Image.open(root / (name + '.png')).convert('RGB')).astype(int)
    b = np.array(Image.open(root / (name + '_no_player.png')).convert('RGB')).astype(int)
    counts[name] = int((abs(a-b).max(axis=2) > 8).sum())
(root / 'occlusion_metrics.json').write_text(json.dumps(counts, indent=2))
assert counts['05_front_of_pole'] > counts['04_behind_pole'] > 0, counts
print('OCCLUSION_PIXELS', counts)
