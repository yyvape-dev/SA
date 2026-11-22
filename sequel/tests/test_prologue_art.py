"""Protect original pixels and artwork-specific white regions during cutout."""
import importlib.util
from pathlib import Path
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

class PrologueArtTest(unittest.TestCase):
    def test_background_connected_white_is_removed_but_cream_clothing_is_kept(self):
        path = ROOT / 'tools/import_prologue_art.py'
        self.assertTrue(path.exists(), 'missing source-preserving art importer')
        spec = importlib.util.spec_from_file_location('prologue_art', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        data = np.full((16, 16, 3), 255, np.uint8)
        data[3:13, 3:13] = (80, 45, 20)
        data[5:11, 5:11] = (254, 251, 239)  # white/cream fabric enclosed in silhouette
        data[6:9, 6:9] = 255
        result = np.array(module.cutout(Image.fromarray(data)))
        self.assertEqual(int(result[0, 0, 3]), 0)
        self.assertTrue(np.all(result[5:11, 5:11, 3] == 255))
        self.assertTrue(np.array_equal(result[5:11, 5:11, :3], data[5:11, 5:11]))
        hole = np.array(module.cutout(Image.fromarray(data), [(7, 7)]))
        self.assertEqual(int(hole[7, 7, 3]), 0)
        self.assertEqual(int(hole[5, 5, 3]), 255)

    def test_supplied_white_fabric_and_glass_survive_while_handle_hole_is_clear(self):
        path = ROOT / 'tools/import_prologue_art.py'
        spec = importlib.util.spec_from_file_location('prologue_art', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name, points in [('sera_book', [(350, 950)]), ('mina_bread', [(350, 370)]),
                             ('portable_lamp', [(620, 700), (620, 900)])]:
            original = Image.open(ROOT / f'art/prologue_src/{name}.jpeg').convert('RGB')
            result = module.cutout(original, module.HOLES.get(name, []))
            self.assertEqual(result.size, original.size)
            for point in points:
                self.assertEqual(result.getpixel(point), (*original.getpixel(point), 255))
            self.assertEqual(result.getpixel((0, 0))[3], 0)
            if name == 'portable_lamp':
                self.assertEqual(result.getpixel((620, 160))[3], 0)

if __name__ == '__main__':
    unittest.main()
