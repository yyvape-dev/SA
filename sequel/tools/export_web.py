"""Web 版の書き出し（本体＋地区 pck）。 python3 -I sequel/tools/export_web.py

1. 版の番号を決め、本体の build_ver.json と各地区の districts/<id>_ver.json に同じ値を書く。
2. export_presets.cfg を整える：本体（preset.0 "Web"）から地区の絵を外し、地区ごとの書き出し設定（"District <id>"）を作る。
3. 本体 web/index.html と、地区 web/districts/<id>.pck を書き出す。
4. 中身を確かめる：本体に地区の絵が入っていないこと、地区 pck に絵と版の番号が入っていること。

地区に絵を足したら DISTRICTS に書く（例：新しい地区 d2 の絵を art/d2/ に置くなら "d2": {"res": ["art/d2/*.png"], ...}）。
"""
import os, re, glob, json, struct, subprocess, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DISTRICTS = {
    "d1": {"res": ["art/painted/*.png", "assets/ground/*.png"],   # 歓楽街：塗った部品・遠景・地面
           "files": ["assets/ground/glints.json"]},                # 映り込みの元（json は include_filter で入れる）
    "dg1": {"res": ["assets/foe/gen_g1.webp", "assets/foe/foeduel_g1_*.webp"],   # ダンジョンのボス（仮置きの敵将 g1）。入るときに読む
            "files": []},
}
MAIN_EXCLUDE = ["captures/*", "art/guide/*.png", "tools/*", "districts/*", "art/incoming/*"]


def pck_files(path):
    d = open(path, 'rb').read()
    off = 24 + 8 + 64
    n, = struct.unpack_from('<I', d, off); off += 4
    out = []
    for _ in range(n):
        l, = struct.unpack_from('<I', d, off); off += 4
        p = d[off:off + l].rstrip(b'\0').decode(); off += l
        _, s = struct.unpack_from('<QQ', d, off); off += 16 + 16 + 4
        out.append((p, s))
    return out


def preset_block(idx, name, files, include, export_path, options):
    return ('[preset.%d]\n\nname="%s"\nplatform="Web"\nrunnable=false\ndedicated_server=false\ncustom_features=""\n'
            'export_filter="resources"\nexport_files=PackedStringArray(%s)\ninclude_filter="%s"\nexclude_filter=""\n'
            'export_path="%s"\npatches=PackedStringArray()\nencryption_include_filters=""\nencryption_exclude_filters=""\n'
            'seed=0\nencrypt_pck=false\nencrypt_directory=false\nscript_export_mode=2\n\n' % (
                idx, name, ", ".join('"res://%s"' % f for f in files), ", ".join(include), export_path)
            + options.replace('[preset.0.options]', '[preset.%d.options]' % idx))


def main():
    os.chdir(ROOT)
    head = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()
    ver = '%s-%s' % (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S'), head)
    json.dump({"ver": ver}, open('build_ver.json', 'w'))
    os.makedirs('districts', exist_ok=True)
    for d in DISTRICTS:
        json.dump({"ver": ver}, open('districts/%s_ver.json' % d, 'w'))
    # 書き出し設定
    s = open('export_presets.cfg', encoding='utf-8').read()
    s = s[:s.index('[preset.1]')] if '[preset.1]' in s else s
    s = re.sub(r'exclude_filter="[^"]*"', 'exclude_filter="%s"' % ", ".join(
        MAIN_EXCLUDE + [p for d in DISTRICTS.values() for p in d["res"] + d["files"]]), s, count=1)
    opts = s[s.index('[preset.0.options]'):]
    blocks = [s.rstrip('\n') + '\n']
    for i, (d, spec) in enumerate(DISTRICTS.items(), start=1):
        files = sorted(f for g in spec["res"] for f in glob.glob(g))
        blocks.append(preset_block(i, 'District ' + d, files, ['districts/%s_ver.json' % d] + spec["files"],
                                   'web/districts/%s.pck' % d, opts))
    # 注意（2026-11-06 に試した事実）：<link rel="preload"> で地区 pck を先読みすると、Godot の読み込みが使い回さず
    # 二重に落とし、かえって遅くなった（20Mbps 相当で 240 秒以内に終わらない）。先読みはしない。
    base_head = '<meta name=\\"apple-mobile-web-app-capable\\" content=\\"yes\\"><meta name=\\"mobile-web-app-capable\\" content=\\"yes\\">'
    blocks = [re.sub(r'html/head_include="[^\n]*"', lambda m: 'html/head_include="%s"' % base_head, b) for b in blocks]
    open('export_presets.cfg', 'w', encoding='utf-8').write('\n'.join(blocks))
    # 書き出し
    run = lambda *a: subprocess.run(['timeout', '600', 'godot', '--headless', '--path', '.', *a], capture_output=True, text=True)
    run('--import')
    run('--export-release', 'Web', 'web/index.html')
    os.makedirs('web/districts', exist_ok=True)
    for d in DISTRICTS:
        run('--export-pack', 'District ' + d, 'web/districts/%s.pck' % d)
    # 確かめる
    main_files = [p for p, _ in pck_files('web/index.pck')]
    bad = [p for p in main_files if re.match(r'(res://)?(art/painted|assets/ground|districts)/', p)]
    print('版', ver)
    print('本体 index.pck %.1fMB、地区の絵が入っていない: %s %s' % (os.path.getsize('web/index.pck') / 1e6, not bad, bad[:3]))
    for d, spec in DISTRICTS.items():
        fs = pck_files('web/districts/%s.pck' % d)
        names = [p for p, _ in fs]
        need = ['districts/%s_ver.json' % d] + spec["files"] + [f + '.import' for g in spec["res"] for f in glob.glob(g)]
        miss = [n for n in need if n not in names and 'res://' + n not in names]
        print('地区 %s.pck %.1fMB（%d ファイル）、足りない物: %s' % (d, os.path.getsize('web/districts/%s.pck' % d) / 1e6, len(fs), miss or 'なし'))


if __name__ == '__main__':
    main()
