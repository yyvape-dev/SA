extends SceneTree
var failed:=false
func check(ok:bool,label:String):
    if not ok:failed=true;print("T3_PLAY_FAIL: "+label)
func frames(n:int):
    for i in n:await physics_frame;await process_frame
func _initialize():call_deferred("run")
func run():
    if not ResourceLoader.exists("res://sa2_t3_playable.tscn"):
        check(false,"same-Level playable missing");quit(1);return
    var scene=load("res://sa2_t3_playable.tscn").instantiate()
    scene.save_path="user://t3-playable-test.json"
    for s in ["",".bak",".tmp"]:DirAccess.remove_absolute(scene.save_path+s)
    root.add_child(scene)
    for i in 2400:
        if scene.ready_for_event:break
        await process_frame
    check(scene.ready_for_event,"ready")
    if failed:quit(1);return
    var level_id=scene.level.get_instance_id()
    var growth=scene.progress.path
    var original_growth=FileAccess.get_file_as_string(growth) if FileAccess.file_exists(growth) else ""
    check(scene.start_encounter(),"start saves then acquires controls")
    check(scene.level.get_instance_id()==level_id and scene.player==scene.lily and scene.battle.ally==null,"same city, single Lily target")
    check(not scene.lily.is_physics_processing() and not scene.lease.driver.manual.is_physics_processing(),"only manual driver owns update")
    check(scene.battle.enemies.size()==2 and scene.evacuation.people.size()==3,"two machines three residents")
    var count_before=0
    for i in 20:
        scene.battle.hp=0
        await frames(2)
        check(scene.encounter.phase=="safe" and scene.battle.hp>0,"failure restores HP to safe")
        check(scene.battle.freeze==0 and not scene.battle.cine and scene.lily.state=="move","battle and actor transients reset")
        check(scene.evacuation.snapshot()["resident-a"].index==0 and not scene.evacuation.moving,"NPC reset")
        check(scene.start_encounter(),"explicit retry")
        await frames(2)
        var count_now=get_node_count()
        if i==0:count_before=count_now
        check(count_now==count_before,"retry has stable node count")
        check(scene.battle.foe_killed.get_connections().size()==1,"single death connection")
    scene.battle.hp=100
    for foe in scene.battle.enemies.duplicate():foe.take_hit(10000,1,true)
    await frames(2)
    check(scene.encounter.phase=="street","machines first still awaits residents")
    scene.guide_residents()
    for i in 1500:
        if scene.encounter.phase=="complete":break
        await frames(1)
    check(scene.encounter.phase=="complete","real routes plus actual machine HP deaths commit win")
    check(scene.level.get_instance_id()==level_id and scene.player==scene.rana,"same Level exploration restored")
    check(not scene.battle.auto_spawn and scene.battle.enemies.is_empty(),"no respawn after win")
    check(scene.encounter.flow.completed.get("C2-09",false),"completion stored")
    var after_growth=FileAccess.get_file_as_string(growth) if FileAccess.file_exists(growth) else ""
    check(original_growth==after_growth,"growth save untouched")
    scene.queue_free();await frames(2)
    if not failed:print("SA2_T3_PLAYABLE_PASS: same-Level, 20 retries, real deaths/routes, restore, no growth writes")
    quit(1 if failed else 0)
