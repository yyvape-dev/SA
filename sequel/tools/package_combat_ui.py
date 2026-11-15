"""Replay native combat-UI crops, or --check existing lossless assets. No image resampling."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageChops
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');p.add_argument('--compare',action='store_true');args=p.parse_args()
root=Path(__file__).resolve().parents[1];source=root/'art/ui_source/combat_hud';dest=root/'assets/ui/combat';manifest=json.loads((source/'provenance.json').read_text());pairs={}
for entry in manifest['entries']:
 im=Image.open(source/entry['source']).convert('RGBA');crop=im.crop(entry['rect']);path=dest/entry['file']
 if not args.check:crop.save(path,lossless=True,exact=True,method=6)
 result=Image.open(path).convert('RGBA');assert crop.size==result.size and all(v==(0,0) for v in ImageChops.difference(crop,result).getextrema()),entry['file']
 if args.compare:
  if entry['source'] not in pairs:pairs[entry['source']]=[Image.new('RGBA',im.size),Image.new('RGBA',im.size)]
  pairs[entry['source']][0].paste(crop,entry['rect'][:2]);pairs[entry['source']][1].paste(result,entry['rect'][:2])
for name,(before,after) in pairs.items():
 combined=Image.new('RGBA',(before.width*2,before.height));combined.paste(before,(0,0));combined.paste(after,(before.width,0));combined.save(source/(Path(name).stem+'_native_compare.png'))
print('COMBAT_ART PASS',len(manifest['entries']),'native crops pixel-identical')
