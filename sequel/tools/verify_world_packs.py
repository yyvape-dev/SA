"""Black-box audit of exported PCKs; usage: python3 verify_world_packs.py /absolute/web."""
from pathlib import Path
import json,sys
from export_web import pck_files
p=Path(sys.argv[1])
names={name:{n.removeprefix('res://') for n,_ in pck_files(str(p/file))}
       for name,file in {'main':'index.pck','bt1':'districts/bt1.pck','gh1':'districts/gh1.pck'}.items()}
assert not any(n.startswith('art/painted_bt/') for n in names['main']), 'world art leaked into main pack'
world_ctex = {n for k in ['bt1','gh1'] for n in names[k] if n.endswith('.ctex')}
assert not world_ctex & names['main'], 'orphan imported world texture leaked into main pack'
assert not any('gamehall' in n for n in names['bt1']), 'hall art leaked into street pack'
assert not any(n.startswith('art/painted_bt_src/') for ns in names.values() for n in ns), 'source art was exported twice'
required_hall=['art/painted_bt/gamehall_approved_16m_preview.png.import',
 'art/painted_bt/gamehall_motion/playable/accepted_people_atlas.png.import',
 'art/painted_bt/gamehall_motion/playable/accepted_people.json']
required_hall += [f'art/painted_bt/gamehall_motion/remaining_animation/motion_frames_0{i}.png.import' for i in range(4)]
assert set(required_hall) <= names['gh1'], 'hall pack incomplete'
required_street=[f'art/painted_bt/{x}.png.import' for x in ['w_bar','w_cabaret','w_brothel','w_shady','sbar_a','sbar_b','sbar_c','sbar_d','tex_brick','tex_iron','tex_boards','tex_plaster','tex_cloth']]
assert set(required_street) <= names['bt1'], 'street pack incomplete'
shared=names['bt1'] & names['gh1']
assert not any(n.startswith('art/painted_bt/') or n.startswith('.godot/imported/') for n in shared), 'street/hall texture duplicated'
print(json.dumps({'pass':True,'main_has_no_world_art':True,'hall_and_street_textures_disjoint':True,
                  'required_hall_files':len(required_hall),'required_street_files':len(required_street),
                  'bt1_bytes':(p/'districts/bt1.pck').stat().st_size,'gh1_bytes':(p/'districts/gh1.pck').stat().st_size},indent=2))
