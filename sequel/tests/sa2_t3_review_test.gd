extends SceneTree
var host
var failures:=0
var growth_before:=""
var growth_existed:=false
var t2_before:=""
var t2_existed:=false
func restore_files():
    for item in [["user://sa2_save.json",growth_existed,growth_before],["user://sa2_t2_progress.json",t2_existed,t2_before]]:
        if item[1]:
            var f=FileAccess.open(item[0],FileAccess.WRITE);f.store_string(item[2]);f.close()
        else:DirAccess.remove_absolute(item[0])
func check(ok:bool,label:String)->bool:
    if not ok:failures+=1;printerr("T3_REVIEW_FAIL: ",label)
    return ok
func frames(n:int):
    for i in n:await physics_frame;await process_frame
func key(code:Key,pressed:bool):
    var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func _initialize():call_deferred("run")
func run():
    growth_existed=FileAccess.file_exists("user://sa2_save.json")
    growth_before=FileAccess.get_file_as_string("user://sa2_save.json") if growth_existed else ""
    t2_existed=FileAccess.file_exists("user://sa2_t2_progress.json")
    t2_before=FileAccess.get_file_as_string("user://sa2_t2_progress.json") if t2_existed else ""
    var growth_fixture='{"lv":2, "xp":7, "weapon":1, "unknown_metadata":"must survive T3"}'
    var f=FileAccess.open("user://sa2_save.json",FileAccess.WRITE);f.store_string(growth_fixture);f.close()
    f=FileAccess.open("user://sa2_t2_progress.json",FileAccess.WRITE);f.store_string("T2 sentinel");f.close()
    host=load("res://sa2_t3_playable.tscn").instantiate()
    if OS.has_environment("T3_REVIEW_OLD_HOST"):host.set_script(load(OS.get_environment("T3_REVIEW_OLD_HOST")))
    host.save_path="user://t3-review.json"
    for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(host.save_path+suffix)
    root.add_child(host)
    for i in 2400:
        if host.ready_for_event:break
        await process_frame
    if not check(host.ready_for_event,"ready"):quit(1);return
    if not OS.has_environment("T3_REVIEW_OLD_HOST"):
        await frames(24)
        var pos:Vector2=host.ui.pad._btns().gear[0]
        var touch=InputEventScreenTouch.new();touch.index=2;touch.position=pos;touch.pressed=true;root.push_input(touch,true);await frames(1)
        touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames(1)
        if not check(host.hud.slot_open,"actual gear touch opens modal"):quit(1);return
    if not OS.has_environment("T3_REVIEW_OLD_HOST"):
        key(KEY_SPACE,true);await frames(1);key(KEY_SPACE,false);await frames(1)
    if not OS.has_environment("T3_REVIEW_OLD_HOST") and not check(host.encounter.phase=="explore" and host.player==host.rana,"slot menu cannot transfer control to street combat"):
        quit(1);return
    if not OS.has_environment("T3_REVIEW_OLD_HOST"):
        key(KEY_K,true);await frames(1);key(KEY_K,false);await frames(1)
        check(not host.hud.slot_open and not host.rana.locked and host.battle.process_mode!=Node.PROCESS_MODE_DISABLED,"K closes original modal with Rana ownership")
    check(FileAccess.get_file_as_string("user://sa2_save.json")==growth_fixture and FileAccess.get_file_as_string("user://sa2_t2_progress.json")=="T2 sentinel","modal close preserves growth/T2 saves byte-for-byte")
    # Capture shared values distinct from defaults, then dirty every combat owner.
    host.battle.hp=75;host.battle.ult=23;host.battle.ally_ult=17;host.battle.hits_taken=3
    host.start_encounter()
    host.battle.hp=0;host.battle.ult=99;host.battle.ally_ult=98;host.battle.cine=true;host.battle.freeze=0.7
    host.lily.state="atk";host.lily.clip="atk_rush";host.lily.target=host.battle.enemies[0];host.lily.inv=2
    await frames(2)
    check(host.encounter.phase=="safe" and host.battle.hp==75 and host.battle.ult==23 and host.battle.ally_ult==17 and host.battle.hits_taken==3,"HP/gauges/hit counts restored")
    check(host.lily.state=="move" and host.lily.target==null and host.lily.inv==0 and host.battle.freeze==0 and not host.battle.cine,"actor and battle transients normalized")
    check(host.battle.ROOM_X==Vector2(-24,24),"exploration world bounds restored after lease")
    host.rana.position=Vector3(16,0,0);await frames(2)
    key(KEY_D,true);await frames(30);key(KEY_D,false);await frames(1)
    check(host.rana.position.x<16.7,"closed passage still blocks exploration movement")
    var cp=host.encounter.checkpoint
    var flow=host.store.load_payload().flow
    check(host.Store.position(flow.player_position).distance_to(host.Store.position(cp.actors.rana.position))<0.0001 and host.Store.position(flow.return_position).distance_to(host.Store.position(cp.actors.rana.position))<0.0001,"Flow and actor checkpoint coordinates agree")
    host.queue_free();await frames(2)
    restore_files()
    if failures==0:print("SA2_T3_REVIEW_PASS: modal ownership, shared reset, closure and Flow consistency")
    quit(0 if failures==0 else 1)
