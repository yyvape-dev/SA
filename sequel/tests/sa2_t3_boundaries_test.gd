extends SceneTree
var failed:=false
func check(ok:bool,label:String):
    if not ok:failed=true;printerr("T3_BOUNDARY_FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var host=load("res://sa2_t3_playable.tscn").instantiate();host.save_path="user://t3-boundary.json"
    for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(host.save_path+suffix)
    root.add_child(host)
    for i in 2400:
        if host.ready_for_event:break
        await process_frame
    if not host.ready_for_event:check(false,"scene ready");quit(1);return
    host.start_encounter()
    var battle=host.battle
    var p=host.policy
    host.set_physics_process(false);host.lease.driver.set_physics_process(false)
    for e in battle.enemies:e.set_physics_process(false);e.hp=10000;e.hp_max=10000
    p.bounds=Rect2(-5,-2,10,4);p.blockers=[Rect2(0,-2,0.01,4)]
    battle.ROOM_X=Vector2(-5,5);battle.BELT_Z=Vector2(-2,2)
    var a=battle.enemies[0];var b=battle.enemies[1];var lily=host.lily
    a.position=Vector3(-0.05,0,0);b.position=Vector3(-0.1,0,0)
    battle._separate(1)
    check(a.position.x<0 and b.position.x<0,"pair a displacement stops before thin fence")
    a.position=Vector3(0.1,0,0);b.position=Vector3(0.05,0,0)
    battle._separate(1)
    check(a.position.x>0.01 and b.position.x>0.01,"pair b displacement stops before thin fence")
    lily.position=Vector3(-0.2,0,0);lily.state="move";lily.face=1
    host.lease.driver.manual.dodge_left=0;host.lease.driver.manual.move_in=Vector2.RIGHT
    a.position=Vector3(3,0,0);b.position=Vector3(4,0,0)
    host.lease.driver.dodge();host.lease.driver._physics_process(0.3)
    check(lily.position.x<0,"manual dodge cannot tunnel")
    a.position=Vector3(-0.1,0,0);a.state="stun";a.kx=5;a.stun=1;battle.freeze=0
    a._physics_process(0.3)
    check(a.position.x<0,"enemy knockback cannot tunnel")
    a.position=Vector3(0.5,0,0);lily.position=Vector3(-0.2,0,0);lily.inv=0;lily.state="move"
    var hp=battle.hp
    battle.enemy_hits_player(a)
    check(battle.hp==hp,"enemy damage denied across fence")
    for shape in ["both","circle","band","only"]:
        var before=a.hp
        var spec={"shape":shape,"side":0,"r":10.0,"lane":10.0,"x0":-5.0,"x1":5.0,"only":a,"dmg":1.0,"strong":false}
        if shape!="only":spec.erase("only")
        battle._attack_from(lily,spec,1)
        check(a.hp==before,"all attack shapes reject fence: "+shape)
    p.blockers=[]
    a.position=Vector3(-0.1,2.6,0)
    var before=a.hp
    battle._attack_from(lily,{"side":0,"r":10.0,"lane":10.0,"dmg":1.0,"strong":false},1)
    check(a.hp==before,"upper floor target denied even same xz")
    a.position=Vector3(-0.1,0,0);p.blockers=[Rect2(0,-2,0.01,4)]
    lily.position=Vector3(-1,0,0);lily.face=1
    battle._attack_from(lily,{"side":1,"r":2.0,"lane":1.0,"dmg":1.0,"strong":false,"pull":"front","pull_m":4.0},1)
    check(a.position.x<0,"pull cannot move valid hit target through fence")
    a.position=Vector3(0.6,0,0);lily.position=Vector3(-0.2,0,0);lily.force_attack("atk_rush",a)
    var clip:Dictionary=lily.data.clips.atk_rush
    var hit:float=float(clip.hits[0])/(float(clip.fps)*lily.SPD)
    lily.t=hit*0.55;battle.freeze=0
    before=a.hp;lily._physics_process(hit*0.6)
    check(lily.position.x<0 and a.hp==before,"within-attack dash constrained before hit")
    lily.position=Vector3(-0.1,0,0);lily.state="hurt";lily.t=0;lily.kb=5;battle.freeze=0
    lily._physics_process(0.3)
    check(lily.position.x<0,"hurt displacement constrained")
    # Noncombat objects never enter the target registry; only-target spec cannot attack them.
    var npc=host.evacuation.people["resident-a"].node
    var old_npc:Vector3=npc.position
    var old_rana:Vector3=host.rana.position
    for target in [npc,host.rana,host.level]:
        battle._attack_from(lily,{"only":target,"side":0,"r":999.0,"lane":999.0,"dmg":9999.0,"strong":true},1)
    check(npc.position==old_npc and host.rana.position==old_rana,"resident/person/equipment excluded from damage")
    host.queue_free();await process_frame;await process_frame
    if not failed:print("SA2_T3_BOUNDARY_PASS: all displacements, shapes, floors and non-targets")
    quit(1 if failed else 0)
