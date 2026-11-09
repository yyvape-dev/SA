"""Export a standalone TD Web build without modifying existing web/ output."""
import argparse, hashlib, json, os, pathlib, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[1]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=pathlib.Path)
    parser.add_argument('--allow-dirty', action='store_true', help='Development preview only')
    args = parser.parse_args()
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents:
        parser.error('Use an output directory outside the source project')
    out.mkdir(parents=True, exist_ok=True)
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True))
    untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','scripts','assets/td','tools','tests','sa2_td_playable.tscn'],cwd=ROOT,text=True).splitlines()
    dirty=dirty or any(not p.endswith('.uid') for p in untracked)
    if dirty and not args.allow_dirty:raise SystemExit('Commit source before release export; --allow-dirty is preview only')
    engine = os.environ.get('GODOT_BIN', 'godot')
    version = subprocess.check_output([engine, '--version'], text=True).strip()
    if not version.startswith('4.7.2.stable'):
        raise SystemExit('Godot 4.7.2 required: '+version)
    meta = ROOT/'td_build.json'
    old = meta.read_bytes() if meta.exists() else None
    try:
        meta.write_text(json.dumps({'sha': sha, 'dirty': dirty, 'godot': version}))
        subprocess.run([engine, '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'], check=True)
        subprocess.run([engine, '--headless', '--path', str(ROOT), '--export-release', 'TD Web', str(out/'index.html')], check=True)
    finally:
        if old is None:meta.unlink(missing_ok=True)
        else:meta.write_bytes(old)
    from export_web import pck_files
    packed=dict(pck_files(str(out/'index.pck')))
    for required in ['art/guide/guide.json','dialogues/ja/C1-06.json','events/C2-09.tres.remap','assets/td/fixture-sans.otf.import']:
        if required not in packed:raise SystemExit('Missing runtime dependency: '+required)
    files = [{'path':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(out.iterdir()) if p.is_file() and p.name!='manifest.json']
    (out/'manifest.json').write_text(json.dumps({'sha':sha,'dirty':dirty,'godot':version,'files':files},indent=2)+'\n')
    print('TD_WEB_EXPORT_PASS',out)
if __name__ == '__main__':main()
