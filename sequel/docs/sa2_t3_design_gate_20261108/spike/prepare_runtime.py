"""Recreate throwaway fixture, leaving the source checkout unchanged. No download/install."""
from pathlib import Path
import json, shutil
root=Path(__file__).resolve().parent.parent
source=root.parent/'sa2-t3-source'/'sequel'
runtime=root/'runtime'
if runtime.exists():
    raise SystemExit('runtime exists: preserve existing evidence; choose another audit directory')
shutil.copytree(source,runtime)
shutil.copyfile(root/'spike/bench.gd',runtime/'audit_bench.gd')
shutil.copyfile(root/'spike/bench_noworld.gd',runtime/'audit_noworld.gd')
p=runtime/'dialogues/ja'
j=json.loads((p/'C2-09.json').read_text())
for i in range(100):
    data=dict(j,id=f'Audit{i:03d}')
    (p/f'Audit{i:03d}.json').write_text(json.dumps(data,ensure_ascii=False))
(root/'logs').mkdir(exist_ok=True)
print('Run Godot 4.7.2 --headless --path runtime --editor --import --quit using writable XDG config/cache directories.')
