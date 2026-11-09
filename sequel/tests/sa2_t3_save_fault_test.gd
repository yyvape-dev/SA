extends SceneTree
class FaultStore:
    extends "res://scripts/sa2_street_checkpoint.gd"
    var fault:=""
    func _write_file(file_path:String, content:String)->bool:
        if (fault=="temp-write" and file_path==path+".tmp") or (fault=="backup-write" and file_path==path+".bak.tmp"):return false
        return super._write_file(file_path,content)
    func _replace(from:String,to:String)->bool:
        if (fault=="backup-rename" and from==path+".bak.tmp") or (fault=="commit-rename" and from==path+".tmp"):return false
        return super._replace(from,to)
var failures:=0
func check(ok:bool,label:String):
    if not ok:failures+=1;printerr("T3_SAVE_FAULT_FAIL: ",label)
func _initialize():
    var d=load("res://events/C2-09.tres")
    var checkpoint=load("res://scripts/sa2_street_checkpoint.gd").empty_checkpoint(d)
    for fault in ["temp-write","backup-write","backup-rename","commit-rename"]:
        var store=FaultStore.new();store.definition=d;store.path="user://t3-fault-"+fault+".json"
        for suffix in ["",".bak",".tmp",".bak.tmp"]:DirAccess.remove_absolute(store.path+suffix)
        var e=load("res://scripts/sa2_street_encounter.gd").new();e.definition=d;e.store=store
        check(e.begin(checkpoint),"initial checkpoint "+fault)
        for id in d.machine_ids:e.record_stopped(id)
        for id in d.resident_ids:e.record_safe(id)
        e.evaluate(100)
        var original=FileAccess.get_file_as_string(store.path)
        store.fault=fault
        check(not e.commit_result() and e.phase=="result_pending","pending preserved "+fault)
        check(FileAccess.get_file_as_string(store.path)==original,"current unchanged "+fault)
        var fresh=load("res://scripts/sa2_street_encounter.gd").new();fresh.definition=d;fresh.store=store
        check(fresh.restore_payload(store.load_payload()) and fresh.phase=="safe","crash uses durable checkpoint "+fault)
        store.fault="";check(e.commit_result() and e.phase=="complete","save retry once "+fault)
        # A checksummed unknown schema on disk is still rejected, not adopted.
        var unknown=store.load_payload();unknown.schema=99
        var canonical=JSON.parse_string(JSON.stringify(unknown))
        var file=FileAccess.open(store.path,FileAccess.WRITE)
        file.store_string(JSON.stringify({"payload":canonical,"sha256":JSON.stringify(canonical).sha256_text()}));file.close()
        check(store.load_payload().phase=="street","unknown schema fallback "+fault)
    var inaccessible=FaultStore.new();inaccessible.definition=d;inaccessible.path="user://missing-t3-parent/slot.json"
    var initial=load("res://scripts/sa2_street_encounter.gd").new();initial.definition=d;initial.store=inaccessible
    check(not initial.begin(checkpoint) and initial.phase=="explore","real open failure never starts combat")
    if failures==0:print("SA2_T3_SAVE_FAULT_PASS: temp/backup write, backup/commit rename, corrupt schema, real open failure")
    quit(0 if failures==0 else 1)
