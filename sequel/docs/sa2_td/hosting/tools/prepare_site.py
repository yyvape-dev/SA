"""Prepare pinned SA2 TD files for Pages, verifying the exported manifest."""
import argparse, hashlib, json, pathlib, shutil, urllib.request
SHA='1bd34b84811cc255a98bb4b268e4525005d834c6'
VERSION=SHA[:7]

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
    version=output/'builds'/VERSION;version.mkdir(parents=True)
    for name in names|{'manifest.json'}:shutil.copyfile(build/name,version/name)
    shutil.copyfile(pathlib.Path(__file__).resolve().parents[1]/'index.html',output/'index.html')
    (output/'.nojekyll').touch()
    print('TD_PAGES_PREPARE_PASS',SHA,output)

def preserve_legacy(output:pathlib.Path,base_url:str):
    trusted=json.loads((pathlib.Path(__file__).resolve().parents[1]/'evidence/public-http.json').read_text())['manifest']
    assert trusted['sha']=='903b0b9e2c9c91151d35f3802197fc127cae469a'
    base=base_url.rstrip('/')+'/builds/903b0b9/'
    with urllib.request.urlopen(base+'manifest.json',timeout=60) as response:raw=response.read()
    if json.loads(raw)!=trusted:raise ValueError('Legacy manifest changed')
    legacy=output/'builds'/'903b0b9';legacy.mkdir(parents=True)
    for item in trusted['files']:
        if pathlib.PurePosixPath(item['path']).name!=item['path']:raise ValueError('Invalid legacy path')
        req=urllib.request.Request(base+item['path'],headers={'Accept-Encoding':'identity'})
        target=legacy/item['path']
        with urllib.request.urlopen(req,timeout=120) as response,target.open('wb') as dest:
            shutil.copyfileobj(response,dest)
        if target.stat().st_size!=item['bytes'] or digest(target)!=item['sha256']:raise ValueError('Legacy resource changed')
    (legacy/'manifest.json').write_bytes(raw)
    print('LEGACY_903_BYTES_PRESERVED')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--build',required=True,type=pathlib.Path)
    parser.add_argument('--out',required=True,type=pathlib.Path);parser.add_argument('--preserve-url');a=parser.parse_args()
    prepare_build(a.build,a.out)
    if a.preserve_url:preserve_legacy(a.out,a.preserve_url)
