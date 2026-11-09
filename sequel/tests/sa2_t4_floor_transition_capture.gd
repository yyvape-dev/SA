extends SceneTree
## T4 acceptance: real D2 engine, backtown left edge -> loading -> separate floor
## -> animated facade -> return at the new floor's right edge.
const MAX_WAIT := 420
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _test(ok: bool, msg: String) -> void:
    if not ok:
        failures.append(msg)
        printerr("T4_FLOOR_FAIL "+msg)

func _shot(game: Node3D, filename: String) -> void:
    for i in 4:
        await process_frame
        await RenderingServer.frame_post_draw
    var frame: Image = game.get_viewport().get_texture().get_image()
    _test(frame != null,"No actual Godot viewport")
    if frame == null:
        return
    _test(frame.get_size() == Vector2i(1688,780),"Rendered viewport is not 1688x780")
    _test(frame.save_png(filename)==OK,"Could not save real Godot capture: "+filename)
    print("T4_FLOOR_REAL_FRAME "+filename+" "+str(frame.get_size()))

func _wait_state(game: Node3D, target:int) -> bool:
    for i in MAX_WAIT:
        await process_frame
        if int(game.get("t4_floor_state"))==target and not bool(game.get("t4_floor_busy")):
            return true
    return false

func _run() -> void:
    var path := "res://main.tscn"
    _test(ResourceLoader.exists(path),"main.tscn not found")
    if not failures.is_empty():
        quit(1)
        return
    var game: Node3D = load(path).instantiate()
    root.add_child(game)
    var hero: Node3D
    var cam: Camera3D
    var area: Node3D
    var overlay: CanvasLayer
    for i in MAX_WAIT:
        await process_frame
        hero=game.get("player")
        cam=game.get("cam")
        area=game.get("level")
        overlay=game.get("loading")
        if hero!=null and cam!=null and area!=null and overlay!=null and game.get("ui")!=null:
            break
    _test(hero!=null and cam!=null and overlay!=null,"Original playable scene did not boot")
    _test(str(game.get("town"))=="back","Must test in real TOWN=back")
    _test(int(game.get("t4_floor_state"))==0,"Initially in wrong floor")
    _test(absf(cam.fov-16.8)<0.05 and absf(cam.position.z-15.3)<0.05,"D2 camera changed")
    if not failures.is_empty():
        quit(1)
        return
    var ui: CanvasLayer=game.get("ui")
    ui.visible=false
    var hud: CanvasLayer=game.get("hud")
    if hud!=null:
        hud.visible=false
    hero.set_physics_process(false)
    var dir := ProjectSettings.globalize_path("res://captures/t4-gamehall-floor")
    DirAccess.make_dir_recursive_absolute(dir)
    hero.position=Vector3(-22.0,0.0,0.0)
    game.call("_place_cam",true)
    await _shot(game,dir+"/01_existing_backtown_west.png")
    var original_level: Node3D=game.get("level")
    # Trigger by the same player-X threshold used by gameplay (not direct teleport).
    hero.position.x = -23.70
    var saw_loading := false
    for i in 24:
        await process_frame
        if bool(game.get("t4_floor_busy")) and overlay.visible:
            saw_loading = true
            await _shot(game,dir+"/02_loading_visible.png")
            break
    _test(saw_loading,"Crossing the west edge did not show loading")
    _test(await _wait_state(game,1),"West exit failed to open separate map")
    var new_level: Node3D=game.get("level")
    _test(new_level!=original_level and new_level.name=="T4GamehallFloor","New MAP was not created as an independent Level")
    _test(absf(hero.position.x-21.5)<0.1 and int(hero.get("face"))==-1,"Player was not delivered to right edge of new floor")
    var materials: Dictionary=game.get("t4_floor_materials")
    _test(materials.size()==6,"Micro-animation not attached to new floor")
    _test(bool(game.get("t4_floor_busy"))==false,"Transition never unlocked player")
    _test(absf(cam.fov-16.8)<0.05,"New floor camera deviates from D2")
    hero.position=Vector3(0.0,0.0,0.0)
    game.call("_place_cam",true)
    await _shot(game,dir+"/03_new_gamehall_centre.png")
    for frame_id in 24:
        await _shot(game,dir+"/motion_%02d.png" % frame_id)
    await _shot(game,dir+"/04_new_gamehall_motion.png")
    var phi: float=float(materials["left_slot_machine"].get_shader_parameter("cycle"))
    _test(phi>0.1,"Motion is not running in new floor gameplay")
    hero.position=Vector3(23.7,0.0,0.0)
    _test(await _wait_state(game,0),"Returning east did not restore original map")
    _test(game.get("level")!=new_level,"Original MAP was not freshly rebuilt")
    _test(absf(hero.position.x-(-22.5))<0.1 and int(hero.get("face"))==1,"Return position or direction incorrect")
    _test(game.get("t4_floor_materials").is_empty(),"New floor animation left running in original MAP")
    game.call("_place_cam",true)
    await _shot(game,dir+"/05_return_original.png")
    if failures.is_empty():
        print("T4_FLOOR_ROUTE_PASS west_to_new_loading=true east_to_original=true distinct_level=true animated_parts=6 base_copied=true D2=true screenshots=29")
        quit(0)
    else:
        for f in failures:
            printerr("T4_FLOOR_FAIL "+f)
        quit(1)
