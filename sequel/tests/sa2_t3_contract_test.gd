extends SceneTree
var failures := 0
func check(ok: bool, label: String):
    if not ok:
        failures += 1
        print("T3_CONTRACT_FAIL: " + label)
func _initialize():
    call_deferred("run")
func run():
    if not ResourceLoader.exists("res://scripts/sa2_street_combat_policy.gd"):
        check(false, "swept street policy is missing")
        quit(1)
        return
    var p = load("res://scripts/sa2_street_combat_policy.gd").new()
    p.bounds = Rect2(-5,-2,10,4)
    p.blockers = [Rect2(0,-2,0.1,4)]
    var a := Node3D.new()
    var b := Node3D.new()
    var npc := Node3D.new()
    root.add_child(a); root.add_child(b); root.add_child(npc)
    a.position=Vector3(-1,0,0); b.position=Vector3(1,0,0)
    check(p.register_actor(a,"lily","player","lower"),"register player")
    check(p.register_actor(b,"machine-a","enemy","lower"),"register machine")
    check(not p.register_actor(npc,"resident-a","resident","upper"),"resident cannot enter combat roster")
    check(p.resolve_motion(a,a.position,Vector3(3,0,0)).x < 0,"dash cannot tunnel through thin fence")
    check(not p.allows_damage(a,b,{}),"attack cannot cross fence")
    p.blockers=[]
    check(p.allows_damage(a,b,{}),"enemy on same floor hittable")
    check(not p.allows_damage(a,npc,{}),"non-roster NPC never hittable")
    b.position.y=2.6
    check(not p.allows_damage(a,b,{}),"same xz different height denied")
    b.position.y=0
    p.roster[b.get_instance_id()].floor="upper"
    check(not p.allows_damage(a,b,{}),"different floor denied")
    var d = load("res://events/C2-09.tres")
    check(d.validate_definition()=="","shipped definition is valid")
    check(d.machine_ids.size()==2 and d.resident_ids.size()==3,"two machines and three residents")
    var copy=d.duplicate(true)
    copy.resident_ids[1]=copy.resident_ids[0]
    check(copy.validate_definition()!="","duplicate stable ID refused")
    copy=d.duplicate(true);copy.routes[0]=PackedVector3Array([Vector3(1,0,0)])
    check(copy.validate_definition()!="","invalid evacuation route refused")
    check(d.profile.validate_profile()=="","profile textures and attack timing valid")
    a.free();b.free();npc.free()
    if failures==0: print("SA2_T3_CONTRACT_PASS")
    quit(0 if failures==0 else 1)
