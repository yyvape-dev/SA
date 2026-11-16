extends "res://scripts/main.gd"
const Definition=preload("res://events/C2-09.tres")
const Encounter=preload("res://scripts/sa2_street_encounter.gd")
const Store=preload("res://scripts/sa2_street_checkpoint.gd")
const Policy=preload("res://scripts/sa2_street_combat_policy.gd")
const Lease=preload("res://scripts/sa2_control_lease.gd")
const Evac=preload("res://scripts/sa2_evacuation.gd")
const Snapshot=preload("res://scripts/sa2_street_snapshot.gd")
const StreetHud=preload("res://scripts/sa2_t3_hud.gd")
@export var save_path := "user://sa2_t3_progress.json"
var definition=Definition
var encounter
var store
var lease=Lease.new()
var policy=Policy.new()
var exploration_policy=Policy.new()
var explore_previous:=Vector3.ZERO
var roam_cam_x:=Vector2.ZERO
var evacuation
var rana
var lily
var street_hud
var ready_for_event:=false
var blocked_save:=false
var message:="Explore the lower street; SPACE starts the rescue."
var ally_resolved:=false
signal ally_loaded

func build_city():
    town="back"
    build_backtown()

func _check_gate():pass # T3 keeps the current street; no dungeon transition.

func _load_ally():
    await super._load_ally()
    ally_resolved=true;ally_loaded.emit()

func _ready():
    await super._ready()
    battle.auto_spawn=false
    if not ally_resolved:
        var previous_lock:bool=player.locked
        player.locked=true;loading.show_now()
        var deadline=Timer.new();deadline.one_shot=true;deadline.ignore_time_scale=true;deadline.process_mode=Node.PROCESS_MODE_ALWAYS
        deadline.timeout.connect(ally_loaded.emit,CONNECT_ONE_SHOT);add_child(deadline);deadline.start(60.0)
        await ally_loaded
        deadline.stop();deadline.queue_free()
        if is_instance_valid(battle.ally):player.locked=previous_lock
    if not is_instance_valid(battle.ally):
        message="Lily could not load. Reload to retry.";loading.error_text=message;return
    if definition.validate_definition()!="":
        push_error("T3 definition invalid: "+definition.validate_definition());return
    var readonly=load("res://scripts/sa2_street_readonly_progress.gd").new()
    for key in ["path","lv","xp","weapon","hard_open","best","clears","skills_owned","skill_slots"]:
        readonly.set(key,progress.get(key))
    progress=readonly
    rana=player;lily=battle.ally
    rana.position=definition.lily_start+Vector3(-1,0,0.7);lily.position=definition.lily_start
    roam_cam_x=cam_x
    exploration_policy.bounds=Rect2(-24,-2,48,4);exploration_policy.blockers=definition.blockers;exploration_policy.active=false
    battle.combat_policy=exploration_policy
    cam_x=Vector2(13,13);play_ofs=Vector3(0,3.8,17);play_look=Vector3(0,2,0);cam.fov=21
    _place_cam(true)
    evacuation=Evac.new();add_child(evacuation);evacuation.configure(definition)
    _build_route_marks()
    store=Store.new();store.definition=definition;store.path=save_path
    encounter=Encounter.new();encounter.definition=definition;encounter.store=store
    evacuation.safe_arrived.connect(encounter.record_safe)
    var payload=store.load_payload()
    if not payload.is_empty():
        encounter.restore_payload(payload)
        Snapshot.restore(self,encounter.checkpoint)
        if encounter.phase=="complete":
            evacuation.finish_all();message="All safe. Street remains closed; exploration restored."
        else:message="Checkpoint restored. SPACE retries from safety."
    elif FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path+".bak"):
        blocked_save=true;message="No valid save. Preserve files; recovery required."
    street_hud=StreetHud.new();street_hud.host=self;add_child(street_hud)
    # Hide legacy combat HUD during this slice; keep normal exploration movement.
    ui.hud.hide()
    process_physics_priority=100
    explore_previous=rana.position
    ready_for_event=true
    loading.hide_soon()

func _build_route_marks():
    var markers=load("res://scenes/sa2_c2_09_routes.tscn").instantiate()
    level.add_child(markers)
    var safe=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(2.2,1.2);safe.mesh=plane
    safe.position=definition.safe_marker+Vector3(0,0.025,0)
    var mat=StandardMaterial3D.new();mat.albedo_color=Color(0.12,0.6,0.38);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;safe.material_override=mat;markers.add_child(safe)
    var label=Label3D.new();label.text="SAFE ZONE";label.position=definition.safe_marker+Vector3(0,0.25,0);label.font_size=36;label.modulate=Color(0.4,1,0.7);markers.add_child(label)
    # Closed boundary remains after victory. It is outside the residents' route.
    for rect in definition.blockers:
        var fence=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(rect.size.x,0.8,rect.size.y);fence.mesh=box;fence.position=Vector3(rect.get_center().x,0.4,rect.get_center().y)
        var fm=StandardMaterial3D.new();fm.albedo_color=Color(0.7,0.35,0.12);fence.material_override=fm;markers.add_child(fence)

func start_encounter() -> bool:
    if not ready_for_event or blocked_save or not encounter.phase in ["explore","safe"]:return false
    if hud.slot_open or hud.menu_open or hud.result_t>=0 or battle.process_mode==Node.PROCESS_MODE_DISABLED:
        message="Close the current menu before starting.";return false
    cam_x=Vector2(13,13)
    var cp=Snapshot.capture(self) if encounter.phase=="explore" else encounter.checkpoint.duplicate(true)
    if not encounter.begin(cp):message=store.last_error;return false
    _clear_effects()
    Snapshot.restore(self,cp)
    lease.acquire(self)
    # Manual.setup runs before restoring saved cooldowns/normalizing all transients.
    Snapshot.restore(self,cp)
    lily.position=definition.lily_start
    battle.ROOM_X=Vector2(definition.combat_bounds.position.x,definition.combat_bounds.end.x)
    battle.BELT_Z=Vector2(definition.combat_bounds.position.y,definition.combat_bounds.end.y)
    policy.clear();policy.bounds=definition.combat_bounds;policy.blockers=definition.blockers;policy.active=true
    policy.register_actor(lily,"lily","player","lower");battle.combat_policy=policy
    for i in definition.machine_ids.size():
        var foe=battle.spawn(definition.profile.kind,definition.machine_positions[i],definition.profile)
        foe.set_meta("encounter_id",definition.machine_ids[i])
        var blade=load("res://scripts/sa2_machine_blade.gd").new();blade.foe=foe;foe.add_child(blade)
        policy.register_actor(foe,definition.machine_ids[i],"enemy","lower")
        var mark=Label3D.new();mark.text="MACHINE %d"%(i+1);mark.font_size=30;mark.position.y=1.8;mark.modulate=Color(1,0.75,0.35);foe.add_child(mark)
    evacuation.reset()
    battle.set_physics_process(true)
    message="LILY: WASD move, J attack, K dodge/guard. E guides residents."
    return true

func guide_residents():
    if encounter!=null and encounter.phase=="street":
        evacuation.start();message="Residents use the safe stairs. Stop both machines."

func _on_foe_killed(foe):
    if encounter!=null:encounter.record_stopped(str(foe.get_meta("encounter_id","")))
    # No super: T3 has no experience/reward writes.

func _physics_process(_delta:float):
    if not ready_for_event:return
    if encounter.phase in ["explore","safe","complete"]:
        if rana.position.distance_to(explore_previous)>0.001:cam_x=roam_cam_x
        rana.position=exploration_policy.resolve_motion(rana,explore_previous,rana.position)
        explore_previous=rana.position
        return
    if encounter.phase!="street":return
    encounter.evaluate(battle.hp)
    if encounter.phase=="result_pending":
        _freeze_combat()
        retry_result_save()

func _freeze_combat():
    policy.active=false;evacuation.stop();lease.driver.lock()
    battle.set_physics_process(false)
    for e in battle.enemies:e.set_physics_process(false)

func retry_result_save():
    if encounter.phase!="result_pending":return
    if not encounter.commit_result():message="SAVE FAILED: "+store.last_error;return
    _clear_combat()
    lease.release()
    Snapshot.restore(self,encounter.checkpoint)
    explore_previous=rana.position;cam_x=roam_cam_x
    battle.set_physics_process(true)
    if encounter.phase=="complete":
        evacuation.finish_all();message="All safe. Street remains closed; explore with Rana."
    else:
        evacuation.reset();message="Checkpoint restored. SPACE to retry."

func _clear_combat():
    for e in battle.enemies.duplicate():battle.remove_enemy(e)
    policy.clear();battle.combat_policy=exploration_policy
    _clear_effects()

func _clear_effects():
    for collection in [fx.items,fx.tq,fx2d.items]:
        for value in collection:
            if value.has("node") and is_instance_valid(value.node):value.node.queue_free()
        collection.clear()
    fx.sparks.clear();fx.waves.clear()

func _unhandled_key_input(event:InputEvent):
    if not ready_for_event or not event is InputEventKey or not event.pressed or event.echo:return
    if event.keycode==KEY_SPACE and encounter.phase in ["explore","safe"]:
        start_encounter();get_viewport().set_input_as_handled()
    elif event.keycode==KEY_E:
        guide_residents();get_viewport().set_input_as_handled()
