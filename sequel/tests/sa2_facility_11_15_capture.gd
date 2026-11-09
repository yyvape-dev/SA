extends SceneTree
# Native-render capture; run with --fixed-fps 30 --write-movie <movie.avi>.
var scene
var out_dir := OS.get_environment("FACILITY_CAPTURE_DIR")

func _initialize() -> void:
    OS.set_environment("TOWN", "back")
    call_deferred("_run")

func frames(n: int) -> void:
    for i in n:
        await process_frame
        await RenderingServer.frame_post_draw

func snapshot(name: String) -> void:
    root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func move_until(action: String, target: float, axis: String) -> bool:
    var start: Vector3 = scene.player.position
    Input.action_press(action)
    var reached := false
    for i in 300:
        await frames(1)
        var value: float = scene.player.position.x if axis == "x" else scene.player.position.z
        if (action in ["ui_right", "ui_down"] and value >= target) or (action in ["ui_left", "ui_up"] and value <= target):
            reached = true
            break
    Input.action_release(action)
    print("FACILITY_MOVE: ", action, " from=", start, " to=", scene.player.position, " reached=", reached)
    return reached

func _run() -> void:
    if out_dir.is_empty():
        printerr("FACILITY_CAPTURE_DIR is required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(out_dir)
    scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    for i in 3600:
        if scene.ui != null:
            break
        await process_frame
    if scene.ui == null:
        quit(1)
        return
    scene.loading.visible = false
    scene.player.position = Vector3(10.6, 0, 0)
    scene._place_cam(true)
    await frames(10)
    print("FACILITY_MOVIE_START_FRAME: ", Engine.get_frames_drawn())
    snapshot("11_game")
    await frames(45)
    var ok: bool = await move_until("ui_right", 21.9, "x")
    await frames(20)
    snapshot("15_game")
    ok = await move_until("ui_up", -1.7, "z") and ok
    await frames(20)
    snapshot("15_near_wall")
    ok = await move_until("ui_down", 1.7, "z") and ok
    await frames(20)
    ok = await move_until("ui_left", 10.6, "x") and ok
    await frames(25)
    snapshot("11_return")
    print("FACILITY_MOVIE_END_FRAME: ", Engine.get_frames_drawn())
    print("FACILITY_CAPTURE_RESULT: ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
