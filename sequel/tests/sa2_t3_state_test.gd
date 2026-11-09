extends SceneTree
class FailingStore:
    extends "res://scripts/sa2_street_checkpoint.gd"
    var fail_write:=false
    func _write_file(file_path: String, content: String) -> bool:
        return false if fail_write else super._write_file(file_path,content)
var failures:=0
func check(ok:bool,label:String):
    if not ok: failures+=1; print("T3_STATE_FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
    if not ResourceLoader.exists("res://scripts/sa2_street_encounter.gd"):
        check(false,"durable two-condition encounter missing");quit(1);return
    var def=load("res://events/C2-09.tres")
    var store=FailingStore.new()
    store.definition=def
    store.path="user://t3-state-test.json"
    for suffix in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(store.path+suffix)
    var encounter=load("res://scripts/sa2_street_encounter.gd").new()
    encounter.definition=def;encounter.store=store
    var cp=load("res://scripts/sa2_street_checkpoint.gd").empty_checkpoint(def)
    check(encounter.begin(cp),"save before street start")
    if encounter.phase!="street":quit(1);return
    check(not encounter.record_stopped("human"),"unknown enemy refused")
    check(encounter.record_stopped("machine-a"),"first machine")
    check(not encounter.record_stopped("machine-a"),"duplicate death refused")
    encounter.record_stopped("machine-b");encounter.evaluate(100)
    check(encounter.phase=="street","machines alone cannot win")
    for id in def.resident_ids:encounter.record_safe(id)
    encounter.evaluate(0)
    check(encounter.phase=="result_pending" and encounter.candidate=="lose","HP0 wins same-tick tie")
    check(encounter.commit_result() and encounter.phase=="safe","durable failure safe checkpoint")
    check(encounter.stopped.is_empty() and encounter.safe.is_empty(),"failure rolls back both completion sets")
    check(encounter.begin(cp),"retry")
    for id in def.resident_ids: encounter.record_safe(id)
    encounter.evaluate(100)
    check(encounter.phase=="street","evacuation alone cannot win")
    for id in def.machine_ids: encounter.record_stopped(id)
    encounter.evaluate(100)
    check(encounter.phase=="result_pending","durability barrier")
    var street=store.load_payload()
    check(street.phase=="street","disk remains checkpoint before commit")
    var before=FileAccess.get_file_as_string(store.path)
    store.fail_write=true
    check(not encounter.commit_result() and encounter.phase=="result_pending","write failure preserves result pending")
    check(FileAccess.get_file_as_string(store.path)==before,"failed victory leaves checkpoint byte-identical")
    store.fail_write=false
    check(encounter.commit_result() and encounter.phase=="complete","commit victory")
    var complete=store.load_payload()
    check(complete.phase=="complete","current completed")
    var f=FileAccess.open(store.path,FileAccess.WRITE);f.store_string("{broken");f.close()
    check(store.load_payload().phase=="street","corrupt current falls back to previous checkpoint")
    f=FileAccess.open(store.path+".tmp",FileAccess.WRITE);f.store_string(JSON.stringify(complete));f.close()
    check(store.load_payload().phase=="street","temp is never promoted")
    var invalid=street.duplicate(true);invalid.schema=99
    check(not store.save_payload(invalid),"unknown schema cannot replace save")
    check(store.load_payload().phase=="street","last good save survives invalid write")
    for extra_key in ["auto_spawn","player","combat_policy"]:
        var extra=street.duplicate(true);extra.checkpoint.battle[extra_key]=true
        var preserved=FileAccess.get_file_as_string(store.path)
        check(not store.save_payload(extra),"unknown battle restore property refused: "+extra_key)
        check(FileAccess.get_file_as_string(store.path)==preserved,"unknown field cannot replace current")
    if failures==0:print("SA2_T3_STATE_PASS")
    quit(0 if failures==0 else 1)
