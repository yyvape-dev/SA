extends SceneTree
const Manual=preload("res://scripts/sa2_t2_lily_manual.gd")
var scene
var death_hp:Array=[]
func require(ok:bool,label:String)->bool:
    if not ok:printerr("SA2_T3_INPUT_FAIL: ",label);quit(1)
    else:print("T3_INPUT_CHECK: ",label)
    return ok
func frames(n:int):
    for i in n:await physics_frame;await process_frame
func key(code:Key,pressed:bool):
    var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;Input.parse_input_event(e)
func tap(code:Key):
    key(code,true);await frames(1);key(code,false);await frames(1)
func click(b:Button):
    var e=InputEventMouseButton.new();e.position=b.get_global_rect().get_center();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
    root.push_input(e,true);await frames(1);e=e.duplicate();e.pressed=false;root.push_input(e,true);await frames(2)
func _initialize():call_deferred("run")
func run():
    root.size=Vector2i(1560,720) if OS.get_cmdline_user_args().has("--wide") else Vector2i(1280,720)
    var args=OS.get_cmdline_user_args()
    var resume=args.has("--restart-resume") or args.has("--resume-win")
    var path="user://t3-input.json"
    if not resume:
        for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
    scene=load("res://sa2_t3_playable.tscn").instantiate();scene.save_path=path;root.add_child(scene)
    for i in 2400:
        if scene.ready_for_event:break
        await process_frame
    if not require(scene.ready_for_event,"ready"):return
    await frames(20)
    var level_id=scene.level.get_instance_id()
    if args.has("--restart-resume"):
        if not require(scene.encounter.phase=="safe" and scene.encounter.attempt==1 and scene.battle.hp==100 and scene.evacuation.snapshot()["resident-a"].index==0 and scene.battle.enemies.is_empty(),"fresh process restores pre-battle HP/NPCs/flags, no enemies"):return
        await frames(48)
        print("SA2_T3_RESTART_PASS");quit();return
    if args.has("--resume-win"):
        if not require(scene.encounter.phase=="complete" and scene.encounter.safe.size()==3 and scene.battle.enemies.is_empty() and not scene.battle.auto_spawn,"fresh process preserves completed encounter"):return
        print("SA2_T3_COMPLETE_RESTART_PASS");quit();return
    await click(scene.street_hud.start_button)
    if not require(scene.encounter.phase=="street" and scene.player==scene.lily,"GUI starts manual Lily on same Level"):return
    scene.battle.foe_killed.connect(func(e):death_hp.append(e.hp))
    var before:Vector3=scene.lily.position
    # Real viewport touch move and release, independent of action methods.
    var touch=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(180,540);touch.pressed=true;root.push_input(touch,true)
    await frames(1)
    var drag=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(225,540);root.push_input(drag,true)
    await frames(8)
    touch=touch.duplicate();touch.position=drag.position;touch.pressed=false;root.push_input(touch,true)
    await frames(2)
    if not require(scene.lily.position.x>before.x and scene.lease.driver.manual.move_in==Vector2.ZERO,"touch movement release"):return
    await tap(KEY_E)
    if not require(scene.evacuation.moving,"keyboard guide starts actual three-person routes"):return
    if args.has("--restart-save"):
        await frames(20)
        if not require(scene.store.load_payload().phase=="street","durable street checkpoint before process exit"):return
        print("SA2_T3_RESTART_SAVED");quit();return
    if args.has("--loss"):
        scene.battle.hp=4 # Fault fixture: outcome still requires a natural enemy AI damage callback.
        var hits:int=scene.battle.hits_taken
        for i in 800:
            if scene.encounter.phase=="safe":break
            await frames(1)
        if not require(scene.encounter.phase=="safe" and scene.battle.hp==100 and scene.evacuation.snapshot()["resident-a"].index==0,"real AI defeat restores checkpoint"):return
        await frames(48)
        await click(scene.street_hud.start_button)
        if not require(scene.encounter.phase=="street" and scene.encounter.attempt==2 and scene.level.get_instance_id()==level_id,"GUI retries same street, no duplicate scene"):return
        await frames(48)
        print("SA2_T3_LOSS_INPUT_PASS");quit();return
    # Observe the natural AI telegraph, then the real shared guard input.
    var guarded:=false
    for i in 600:
        for foe in scene.battle.enemies:
            if Manual.guard_candidate(foe,scene.lily.position) and scene.lily.state=="move":
                await tap(KEY_K)
                guarded=scene.lease.driver.manual.guard_count>0
                break
        if guarded:break
        await frames(1)
    if not require(guarded,"keyboard guard against natural machine wind-up"):return
    await frames(24)
    await tap(KEY_K)
    await frames(24)
    var attacks:=0
    for i in 160:
        if scene.encounter.phase!="street":break
        await tap(KEY_J)
        if scene.lease.driver!=null:attacks=scene.lease.driver.manual.attack_count
        await frames(5)
    for i in 600:
        if scene.encounter.phase!="street":break
        await frames(1)
    if not require(scene.encounter.phase=="complete" and death_hp.size()==2 and death_hp[0]<=0 and death_hp[1]<=0 and attacks>0,"input attacks stop both real machine HP and all routes complete"):return
    if not require(scene.level.get_instance_id()==level_id and scene.player==scene.rana and not scene.battle.auto_spawn,"same Level normal exploration restored"):return
    await frames(48)
    if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OS.get_environment("T3_SCREENSHOT") if OS.has_environment("T3_SCREENSHOT") else "/workspace/sa2-t3-evidence/captures/t3-win.png")
    print("SA2_T3_INPUT_PASS");quit()
