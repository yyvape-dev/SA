"""Web 版の書き出し（本体＋地区 pck）。 python3 -I sequel/tools/export_web.py

1. 版の番号を決め、本体の build_ver.json と各地区の districts/<id>_ver.json に同じ値を書く。
2. export_presets.cfg を整える：本体（preset.0 "Web"）から地区の絵を外し、地区ごとの書き出し設定（"District <id>"）を作る。
3. 本体 web/index.html と、地区 web/districts/<id>.pck を書き出す。
4. 中身を確かめる：本体に地区の絵が入っていないこと、地区 pck に絵と版の番号が入っていること。

地区に絵を足したら DISTRICTS に書く（例：新しい地区 d2 の絵を art/d2/ に置くなら "d2": {"res": ["art/d2/*.png"], ...}）。
"""
import os, re, glob, json, struct, subprocess, datetime, shutil

# 使う Godot と出力先（既定：godot と web/）。例：GODOT_BIN=godot47 WEB_OUT=web47 python3 -I sequel/tools/export_web.py
GODOT = os.environ.get('GODOT_BIN', 'godot')
OUT = os.environ.get('WEB_OUT', 'web')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DISTRICTS = {
    "gh1": {"res": ["art/painted_bt/gamehall_approved_16m_preview.png", "art/painted_bt/gamehall_motion/*/*.png"],
            "files": ["art/painted_bt/gamehall_motion/playable/accepted_people.json"]},
    "bt1": {"res": ["art/painted_bt/*.png"], "exclude": ["art/painted_bt/gamehall*.png"], "files": []},  # 裏町：入場時だけ読む。原寸のまま。
    "d1": {"res": ["art/painted/*.png", "assets/ground/*.png"],   # 歓楽街：塗った部品・遠景・地面
           "files": ["assets/ground/glints.json"]},                # 映り込みの元（json は include_filter で入れる）
    "dg1": {"res": ["assets/foe/gen_g1.webp", "assets/foe/foeduel_g1_*.webp"],   # ダンジョンのボス（仮置きの敵将 g1）。入るときに読む
            "files": []},
    "fx1": {"res": ["assets/vfx/*.png", "assets/vfx/kenney/*.png"],    # エフェクトの絵（焼いた REEBO・Kenney の粒。起動の後に読む。2026-11-07）
            "files": ["assets/vfx/reeboo.json"]},
    "al1": {"res": ["assets/lily/*.webp"],                           # 仲間リリィ（起動の後に読む。読み終えてから出てくる）
            "files": []},
}
MAIN_EXCLUDE = ["captures/*", "art/guide/*.png", "art/guide_bt/*", "art/painted_bt/*", "art/painted_bt_src/*", "tools/*", "districts/*", "art/incoming/*", "addons/*"]   # addons/＝取得した素材の元（使う絵は assets/vfx/ に写した。2026-11-07）


def resource_files(spec):
    excluded = {f for g in spec.get("exclude", []) for f in glob.glob(g)}
    return sorted({f for g in spec["res"] for f in glob.glob(g)} - excluded)


def pck_files(path):
    d = open(path, 'rb').read()
    pack_ver, = struct.unpack_from('<I', d, 4)
    if pack_ver >= 3:   # Godot 4.5 以降（4.7.2 は pack 4）：見出しに目録の位置がある
        off, = struct.unpack_from('<Q', d, 32)
    else:               # Godot 4.4 まで（pack 2）：見出しの直後が目録
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
    head = os.environ.get('WEB_SOURCE_REF', head)  # non-gitのmain検証スナップショット用の由来識別子
    eng = subprocess.run([GODOT, '--version'], capture_output=True, text=True).stdout.strip().split('.stable')[0]
    # 版の番号＝時刻－commit－Godot の版（Godot の版が違う本体と地区 pck は混ぜない）
    ver = '%s-%s-g%s' % (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S'), head, eng)
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
        files = resource_files(spec)
        blocks.append(preset_block(i, 'District ' + d, files, ['districts/%s_ver.json' % d] + spec["files"],
                                   OUT + '/districts/%s.pck' % d, opts))
    # 注意（2026-11-06 に試した事実）：<link rel="preload"> で地区 pck を先読みすると、Godot の読み込みが使い回さず
    # 二重に落とし、かえって遅くなった（20Mbps 相当で 240 秒以内に終わらない）。先読みはしない。
    base_head = '<meta name=\\"apple-mobile-web-app-capable\\" content=\\"yes\\"><meta name=\\"mobile-web-app-capable\\" content=\\"yes\\">'
    blocks = [re.sub(r'html/head_include="[^\n]*"', lambda m: 'html/head_include="%s"' % base_head, b) for b in blocks]
    open('export_presets.cfg', 'w', encoding='utf-8').write('\n'.join(blocks))
    # 書き出し
    run = lambda *a: subprocess.run(['timeout', '600', GODOT, '--headless', '--path', '.', *a], capture_output=True, text=True, check=True)
    run('--import')
    os.makedirs(OUT, exist_ok=True)
    if not os.path.exists(OUT + '/.gdignore'):
        open(OUT + '/.gdignore', 'w').close()
    if os.environ.get('WEB_PACK_ONLY') == '1':
        # 同じ4.7.2の既存Webランタイムを再利用する検証用。新しいengineは生成しない。
        if os.path.realpath(OUT) == os.path.realpath('web'):
            raise ValueError('WEB_PACK_ONLY requires a separate WEB_OUT directory')
        for source in glob.glob('web/index.*'):
            if not source.endswith('.pck'):
                shutil.copy2(source, os.path.join(OUT, os.path.basename(source)))
        run('--export-pack', 'Web', OUT + '/index.pck')
    else:
        run('--export-release', 'Web', OUT + '/index.html')
    # 本体の pck にも版の番号を付けて取りに行く（ブラウザに古い index.pck が残り、新しい版が動かないのを防ぐ）
    h = open(OUT + '/index.html', encoding='utf-8').read()
    h = re.sub(r'"mainPack":"[^"]*",?', '', h)
    h = re.sub(r'"fileSizes":\{[^}]*\}', '"fileSizes":' + json.dumps({"index.pck": os.path.getsize(OUT + '/index.pck'), "index.wasm": os.path.getsize(OUT + '/index.wasm')}), h)
    h = h.replace('"executable":"index",', '"executable":"index","mainPack":"index.pck?v=%s",' % ver, 1)
    assert 'mainPack' in h, 'index.html の GODOT_CONFIG を書き換えられない'
    open(OUT + '/index.html', 'w', encoding='utf-8').write(h)
    os.makedirs(OUT + '/districts', exist_ok=True)
    for d in DISTRICTS:
        run('--export-pack', 'District ' + d, OUT + '/districts/%s.pck' % d)
    # 確かめる
    main_files = [p for p, _ in pck_files(OUT + '/index.pck')]
    bad = [p for p in main_files if re.match(r'(res://)?(art/painted|assets/ground|districts)/', p)]
    print('版', ver)
    print('本体 index.pck %.1fMB、地区の絵が入っていない: %s %s' % (os.path.getsize(OUT + '/index.pck') / 1e6, not bad, bad[:3]))
    for d, spec in DISTRICTS.items():
        fs = pck_files(OUT + '/districts/%s.pck' % d)
        names = [p for p, _ in fs]
        need = ['districts/%s_ver.json' % d] + spec["files"] + [f + '.import' for f in resource_files(spec)]
        miss = [n for n in need if n not in names and 'res://' + n not in names]
        print('地区 %s.pck %.1fMB（%d ファイル）、足りない物: %s' % (d, os.path.getsize(OUT + '/districts/%s.pck' % d) / 1e6, len(fs), miss or 'なし'))
        if miss:
            raise RuntimeError('district asset pack is incomplete: ' + str(miss))


if __name__ == '__main__':
    main()
