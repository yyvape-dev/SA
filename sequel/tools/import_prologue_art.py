"""Deterministic import of the eight supplied prologue JPEGs. Never regenerates art.

Keeps source files unchanged and output canvases at the received dimensions.
Only exterior-connected near-white is removed, plus the documented lamp handle hole.
Requires Pillow, numpy, scipy. Run: python3 sequel/tools/import_prologue_art.py
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/prologue_src'
OUTPUT = ROOT / 'assets/prologue'
BACKGROUNDS = {'office', 'guest_room', 'audience_room'}
# This seed is inside the empty handle, not the lamp's bright glass.
HOLES = {'portable_lamp': [(620, 160)]}
SIZES = {'office': (1536, 864), 'guest_room': (1536, 864), 'audience_room': (1536, 864),
         'desk': (1536, 1024), 'portable_lamp': (1254, 1254),
         'sera_book': (702, 1536), 'mina_bread': (672, 1536), 'imperial_envoy': (1024, 1536)}


def cutout(image, holes=()):
    rgb = np.asarray(image.convert('RGB'))
    low, high = rgb.min(axis=2), rgb.max(axis=2)
    white = (low > 238) & ((high.astype(np.int16) - low) < 15)
    labels, _ = ndimage.label(white)
    exterior = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
    chosen = set(int(i) for i in exterior if i)
    for x, y in holes:
        label = int(labels[y, x])
        if not label:
            raise ValueError(f'hole seed {(x, y)} is not near-white background')
        chosen.add(label)
    background = np.isin(labels, list(chosen))
    alpha = np.where(background, 0, 255).astype(np.uint8)
    # Antialiased edge only. Enclosed whites (clothes, book, glass) are untouched.
    edge = ndimage.binary_dilation(background) & ~background
    edge_alpha = np.clip((255.0 - low.astype(float)) / 25.0, 0, 1)
    alpha[edge] = np.rint(edge_alpha[edge] * 255).astype(np.uint8)
    return Image.fromarray(np.dstack((rgb, alpha)))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for name, size in SIZES.items():
        source = SOURCE / f'{name}.jpeg'
        image = Image.open(source)
        if image.size != size:
            raise ValueError(f'{name}: unexpected source size {image.size}')
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        output = image.convert('RGB') if name in BACKGROUNDS else cutout(image, HOLES.get(name, []))
        path = OUTPUT / f'{name}.png'
        output.save(path)
        alpha = output.getchannel('A') if output.mode == 'RGBA' else None
        bounds = alpha.getbbox() if alpha else (0, 0, image.width, image.height)
        records.append(dict(name=name, source=f'art/prologue_src/{name}.jpeg', source_sha256=digest,
                            output=f'assets/prologue/{name}.png', width=image.width, height=image.height,
                            mode=output.mode, bounds=bounds, hole_seeds=HOLES.get(name, []),
                            output_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        print(name, image.size, output.mode, bounds)
        assert digest == hashlib.sha256(source.read_bytes()).hexdigest()
    (OUTPUT / 'provenance.json').write_text(json.dumps({
        'method': 'original-size PNG; exterior-connected near-white alpha only; no generated art or resize',
        'source_commit': '8ab61e8551950ce466df9b5b01db9c719072df93',
        'images': records,
    }, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
