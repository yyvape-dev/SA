extends SceneTree
var game
var output := OS.get_environment("WORLD_CAPTURE_DIR")
var failed := false
func _initialize() -> void:
    OS.set_environment("TOWN", "back")
    call_deferred("_run")
func frames(n: int) -> void:
    for i in n:
        await process_frame
        await RenderingServer.frame_post_draw
func shot(name: String) -> void:
    root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func walk(action: String, mode: String, target: float = 0.0) -> void:
    Input.action_press(action)
    var reached := false
    for i in 1100:
        await frames(1)
        if mode == "hall" and game.town_floor == "gamehall": reached = true
        elif mode == "back" and game.town_floor == "backtown": reached = true
        elif mode == "gate" and game.hud.menu_open: reached = true
        elif mode == "x" and ((action == "ui_left" and game.player.position.x <= target) or (action == "ui_right" and game.player.position.x >= target)): reached = true
        if reached: break
    Input.action_release(action)
    for i in 600:
        if not game.town_floor_busy: break
        await frames(1)
    if not reached: failed = true
    print("WORLD_CAPTURE_MOVE ", action, " ", mode, " reached=", reached, " x=", game.player.position.x)
func _run() -> void:
    if output.is_empty(): quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    for i in 3600:
        if game.ui != null: break
        await process_frame
    game.loading.visible = false
    game.player.position = Vector3(-22,0,0)
    game._place_cam(true)
    await frames(8)
    print("WORLD_MOVIE_START_FRAME: ", Engine.get_frames_drawn())
    shot("street_west")
    await walk("ui_left","hall")
    await walk("ui_left","x",0.0)
    await frames(45)
    shot("hall_center")
    await walk("ui_right","back")
    await walk("ui_right","x",-7.7)
    await frames(12)
    shot("tavern_finished")
    await walk("ui_right","x",10.6)
    await frames(12)
    shot("inn_finished")
    await walk("ui_right","x",23.0)
    await frames(12)
    shot("gate_approach")
    await walk("ui_right","gate")
    await frames(25)
    shot("gate_menu")
    var rects: Dictionary = game.hud.view.call("menu_rects")
    var tap := InputEventScreenTouch.new()
    tap.index = 1; tap.position = rects.normal.get_center(); tap.pressed = true
    Input.parse_input_event(tap)
    await frames(1)
    tap = InputEventScreenTouch.new()
    tap.index = 1; tap.position = rects.normal.get_center(); tap.pressed = false
    Input.parse_input_event(tap)
    for i in 1200:
        if game.dungeon != null and not game.player.locked: break
        await frames(1)
    if game.dungeon == null: failed = true
    await frames(45)
    shot("dungeon_entered")
    # Real combat input; full clear/result flow is covered by the existing dungeon bot separately.
    for i in 5:
        var key := InputEventKey.new();key.keycode=KEY_J;key.pressed=true;Input.parse_input_event(key)
        await frames(1)
        key=InputEventKey.new();key.keycode=KEY_J;key.pressed=false;Input.parse_input_event(key)
        await frames(10)
    # Invoke the existing result-close return API for the compact continuous recording.
    # This does not pretend that this short recording cleared the dungeon.
    game.dungeon.close_result()
    await frames(25)
    shot("backtown_returned")
    print("WORLD_MOVIE_END_FRAME: ",Engine.get_frames_drawn())
    print("WORLD_CAPTURE_RESULT: ","FAIL" if failed else "PASS")
    quit(1 if failed else 0)
