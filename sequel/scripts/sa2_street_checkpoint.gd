extends RefCounted
## Bounded, checksummed T3 save. No growth or T2 save access.
const Flow = preload("res://scripts/sa2_flow_state.gd")
const BATTLE_NUMBERS = ["hp","hp_max","ult","ally_ult","hits_taken","atk_mul","foe_hp_mul","foe_dmg_mul"]
var path := "user://sa2_t3_progress.json"
var definition: Resource
var last_error := ""
var recovered_backup := false

static func empty_checkpoint(d: Resource) -> Dictionary:
    var residents := {}
    var enemies := {}
    for i in d.resident_ids.size():
        residents[d.resident_ids[i]]={"position":vec(d.routes[i][0]),"index":0,"safe":false}
    for i in d.machine_ids.size():
        enemies[d.machine_ids[i]]={"position":vec(d.machine_positions[i]),"hp":d.profile.hp,"kind":d.profile.kind}
    return {"battle":{"hp":100.0,"hp_max":100.0,"ult":0.0,"ally_ult":0.0,"hits_taken":0,"atk_mul":1.0,"foe_hp_mul":1.0,"foe_dmg_mul":1.0,"ult_gain":true,"ally_ult_gain":true},"actors":{"rana":{"position":vec(d.lily_start+Vector3(-1,0,0.7)),"face":1,"cooldowns":{}},"lily":{"position":vec(d.lily_start),"face":1,"cooldowns":{}}},"residents":residents,"enemies":enemies,"flags":{"passage_closed":true}}

static func vec(p: Vector3) -> Array:
    return [p.x,p.y,p.z]

static func position(a: Array) -> Vector3:
    return Vector3(a[0],a[1],a[2])

static func number(v: Variant) -> bool:
    return (v is int or v is float) and is_finite(float(v))

static func integer(v: Variant, lo: int, hi: int) -> bool:
    return number(v) and v>=lo and v<=hi and float(int(v))==float(v)

static func valid_vec(a: Variant) -> bool:
    return a is Array and a.size()==3 and number(a[0]) and number(a[1]) and number(a[2]) and absf(a[0])<1000 and absf(a[1])<1000 and absf(a[2])<1000

func valid_checkpoint(cp: Variant) -> bool:
    if not cp is Dictionary: return false
    for key in ["battle","actors","residents","enemies","flags"]:
        if not cp.get(key) is Dictionary: return false
    if cp.battle.size()!=BATTLE_NUMBERS.size()+2:return false
    for key in BATTLE_NUMBERS:
        if not number(cp.battle.get(key)) or cp.battle[key]<0: return false
    if cp.battle.hp<=0 or cp.battle.hp>cp.battle.hp_max or cp.battle.hp_max>10000: return false
    for key in ["ult_gain","ally_ult_gain"]:
        if not cp.battle.get(key) is bool: return false
    if cp.actors.size()!=2 or cp.residents.size()!=definition.resident_ids.size() or cp.enemies.size()!=definition.machine_ids.size() or cp.flags!={"passage_closed":true}: return false
    for id in ["rana","lily"]:
        var a=cp.actors.get(id)
        if not a is Dictionary or not valid_vec(a.get("position")) or not number(a.get("face")) or absf(float(a.get("face",0)))!=1.0 or not a.get("cooldowns") is Dictionary or a.cooldowns.size()>32: return false
        for value in a.cooldowns.values():
            if not number(value) or value<0 or value>3600: return false
    for i in definition.resident_ids.size():
        var a=cp.residents.get(definition.resident_ids[i])
        if not a is Dictionary or not valid_vec(a.get("position")) or not integer(a.get("index"),0,definition.routes[i].size()-1) or not a.get("safe") is bool: return false
        # Only pre-battle snapshots are durable. Live route state is never resumed.
        if a.safe or int(a.index)!=0 or position(a.position).distance_to(definition.routes[i][0])>0.001: return false
    for i in definition.machine_ids.size():
        var a=cp.enemies.get(definition.machine_ids[i])
        if not a is Dictionary or a.get("kind")!=definition.profile.kind or not valid_vec(a.get("position")) or not number(a.get("hp")) or a.hp!=definition.profile.hp: return false
        if position(a.position).distance_to(definition.machine_positions[i])>0.001: return false
    return true

func valid_payload(p: Variant) -> bool:
    if definition==null or not p is Dictionary or p.get("schema")!=1 or p.get("event_id")!=definition.event_id or p.get("map_id")!=definition.map_id or p.get("definition_version")!=definition.version or not p.get("phase") in ["street","safe","complete"] or not integer(p.get("attempt"),1,1000000) or not valid_checkpoint(p.get("checkpoint")) or not p.get("flow") is Dictionary:
        return false
    var f=Flow.new()
    if not f.restore(p.flow): return false
    if f.return_position!=position(p.checkpoint.actors.rana.position) or f.player_position!=f.return_position or int(f.attempts.get(definition.event_id,0))!=int(p.attempt):return false
    if p.phase=="street": return f.mode==Flow.STREET and f.event_id==definition.event_id and not f.completed.get(definition.event_id,false)
    if p.phase=="complete":return f.mode==Flow.EXPLORE and f.event_id=="" and f.completed.get(definition.event_id,false)
    return f.mode==Flow.EXPLORE and f.event_id==definition.event_id and not f.completed.get(definition.event_id,false)

func _read_file(file_path: String) -> Dictionary:
    if not FileAccess.file_exists(file_path): return {}
    var f=FileAccess.open(file_path,FileAccess.READ)
    if f==null: return {}
    if f.get_length()>2*1024*1024: f.close();return {}
    var parser=JSON.new()
    var parse_error=parser.parse(f.get_as_text());f.close()
    if parse_error!=OK:return {}
    var data=parser.data
    if not data is Dictionary or not data.get("payload") is Dictionary or not data.get("sha256") is String: return {}
    if JSON.stringify(data.payload).sha256_text()!=data.sha256 or not valid_payload(data.payload): return {}
    return data.payload

func load_payload() -> Dictionary:
    recovered_backup=false
    var current=_read_file(path)
    if not current.is_empty(): return current
    var backup=_read_file(path+".bak")
    recovered_backup=not backup.is_empty()
    last_error="" if recovered_backup else "No valid T3 save (current/backup); temporary file is not committed."
    return backup

func _write_file(file_path: String, content: String) -> bool:
    var f=FileAccess.open(file_path,FileAccess.WRITE)
    if f==null: return false
    f.store_string(content);f.flush()
    var ok=f.get_error()==OK
    f.close()
    return ok

func _replace(from: String, to: String) -> bool:
    return DirAccess.rename_absolute(from,to)==OK

func save_payload(p: Dictionary) -> bool:
    last_error=""
    if not valid_payload(p): last_error="Invalid T3 payload";return false
    # Canonicalize once through JSON so in-memory int/float formatting matches read-back.
    var canonical=JSON.parse_string(JSON.stringify(p))
    var data=JSON.stringify({"payload":canonical,"sha256":JSON.stringify(canonical).sha256_text()})
    if not _write_file(path+".tmp",data) or _read_file(path+".tmp").is_empty():
        last_error="Cannot write/verify T3 temporary save";return false
    # Never rotate a corrupt current over a known-good backup.
    if not _read_file(path).is_empty():
        var current=FileAccess.get_file_as_string(path)
        if not _write_file(path+".bak.tmp",current) or _read_file(path+".bak.tmp").is_empty() or not _replace(path+".bak.tmp",path+".bak"):
            last_error="Cannot preserve T3 backup";return false
    if not _replace(path+".tmp",path): last_error="Cannot commit T3 save";return false
    return true
