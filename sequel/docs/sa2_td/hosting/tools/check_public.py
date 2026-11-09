"""Verify the deployed public Web files against their published manifest."""
import argparse, hashlib, json, pathlib, urllib.request
SHA='903b0b9e2c9c91151d35f3802197fc127cae469a'
def check(url):
    url=url.rstrip('/')+'/'
    with urllib.request.urlopen(url,timeout=60) as response:
        assert response.status==200
        landing=response.read().decode()
    assert 'builds/903b0b9/index.html?spot=t0' in landing
    base=url+'builds/903b0b9/'
    with urllib.request.urlopen(base+'manifest.json',timeout=60) as response:manifest=json.load(response)
    assert manifest['sha']==SHA and manifest['dirty'] is False
    records=[]
    for item in manifest['files']:
        assert pathlib.PurePosixPath(item['path']).name==item['path']
        request=urllib.request.Request(base+item['path'],headers={'Accept-Encoding':'identity'})
        with urllib.request.urlopen(request,timeout=120) as response:
            assert response.status==200
            digest=hashlib.sha256();size=0
            while chunk:=response.read(1024*1024):digest.update(chunk);size+=len(chunk)
            assert size==item['bytes'] and digest.hexdigest()==item['sha256'],item['path']
            mime=response.headers.get('Content-Type','')
            if item['path'].endswith('.wasm'):assert 'application/wasm' in mime
            records.append({'path':item['path'],'status':200,'bytes':size,'sha256':digest.hexdigest(),'content_type':mime})
    return {'url':url,'source':SHA,'landing_status':200,'files':records,'manifest':manifest}
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--url',default='https://yyvape-dev.github.io/SA2-TD/');p.add_argument('--out',required=True,type=pathlib.Path);a=p.parse_args()
    result=check(a.url);a.out.write_text(json.dumps(result,indent=2)+'\n');print('PUBLIC_HTTP_HASH_PASS',result['url'])
