"""Prepare pinned SA2 TD files for Pages, verifying the exported manifest."""
import argparse, hashlib, json, pathlib, shutil, tempfile, zipfile
SHA='903b0b9e2c9c91151d35f3802197fc127cae469a'
ZIP_SHA='063e58453af76e3b9c26116dc19c2257db6ec81b189380d65edcc80d10315ffb'
ZIP_SIZE=117458018

def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def prepare_build(build:pathlib.Path, output:pathlib.Path):
    manifest=json.loads((build/'manifest.json').read_text())
    if manifest['sha']!=SHA or manifest['dirty'] or not manifest['godot'].startswith('4.7.2.stable'):
        raise ValueError('Unexpected source, dirty tree or engine')
    names=set()
    for item in manifest['files']:
        if pathlib.PurePosixPath(item['path']).name!=item['path']:raise ValueError('Invalid manifest path')
        p=build/item['path'];names.add(item['path'])
        if p.stat().st_size!=item['bytes'] or digest(p)!=item['sha256']:raise ValueError('Web resource mismatch: '+item['path'])
    if not {'index.html','index.wasm','index.js','index.pck'}.issubset(names):raise ValueError('Incomplete Web build')
    if output.exists() and any(output.iterdir()):raise ValueError('Output must be empty')
    output.mkdir(parents=True,exist_ok=True)
    version=output/'builds'/'903b0b9';version.mkdir(parents=True)
    for name in names|{'manifest.json'}:shutil.copyfile(build/name,version/name)
    shutil.copyfile(pathlib.Path(__file__).resolve().parents[1]/'index.html',output/'index.html')
    (output/'.nojekyll').touch()
    print('TD_PAGES_PREPARE_PASS',SHA,output)

def prepare(archive:pathlib.Path, output:pathlib.Path):
    if archive.stat().st_size!=ZIP_SIZE or digest(archive)!=ZIP_SHA:raise ValueError('Unverified archive')
    with tempfile.TemporaryDirectory() as d, zipfile.ZipFile(archive) as z:
        if any(pathlib.PurePosixPath(i.filename).name!=i.filename for i in z.infolist()):raise ValueError('Expected flat Web archive')
        if z.testzip() is not None:raise ValueError('Archive CRC failed')
        z.extractall(d);prepare_build(pathlib.Path(d),output)

if __name__=='__main__':
    parser=argparse.ArgumentParser();source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--zip',type=pathlib.Path);source.add_argument('--build',type=pathlib.Path)
    parser.add_argument('--out',required=True,type=pathlib.Path);a=parser.parse_args()
    prepare(a.zip,a.out) if a.zip else prepare_build(a.build,a.out)
