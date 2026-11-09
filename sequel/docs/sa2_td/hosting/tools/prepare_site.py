"""Prepare exact, verified SA2 TD files for Pages; no network or deploy."""
import argparse, hashlib, json, pathlib, shutil, zipfile
SHA='903b0b9e2c9c91151d35f3802197fc127cae469a'
ZIP_SHA='063e58453af76e3b9c26116dc19c2257db6ec81b189380d65edcc80d10315ffb'
ZIP_SIZE=117458018

def prepare(archive:pathlib.Path, output:pathlib.Path):
    if archive.stat().st_size!=ZIP_SIZE or hashlib.sha256(archive.read_bytes()).hexdigest()!=ZIP_SHA:
        raise ValueError('Unverified archive: SHA256 or byte count differs')
    if output.exists() and any(output.iterdir()):raise ValueError('Output must be empty')
    output.mkdir(parents=True,exist_ok=True)
    version=output/'builds'/'903b0b9';version.mkdir(parents=True)
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            if pathlib.PurePosixPath(item.filename).name!=item.filename:raise ValueError('Expected flat Web archive')
        if z.testzip() is not None:raise ValueError('Archive CRC failed')
        z.extractall(version)
    manifest=json.loads((version/'manifest.json').read_text())
    if manifest['sha']!=SHA or manifest['dirty'] or not manifest['godot'].startswith('4.7.2.stable'):
        raise ValueError('Unexpected source, dirty tree or engine')
    for item in manifest['files']:
        if pathlib.PurePosixPath(item['path']).name!=item['path']:raise ValueError('Invalid manifest path')
        p=version/item['path']
        if p.stat().st_size!=item['bytes'] or hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:
            raise ValueError('Web resource mismatch: '+item['path'])
    shutil.copyfile(pathlib.Path(__file__).resolve().parents[1]/'index.html',output/'index.html')
    (output/'.nojekyll').touch()
    print('TD_PAGES_PREPARE_PASS',SHA,output)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--zip',required=True,type=pathlib.Path);parser.add_argument('--out',required=True,type=pathlib.Path)
    a=parser.parse_args();prepare(a.zip,a.out)
