extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    root.size = Vector2i(1280, 720)
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 600:
        if is_instance_valid(game.t2_dialogue): break
        await process_frame
    if not game.has_method("_street_open"):
        fail("street conversation available")
        return
    if game._street_available():
        fail("out of range rejected")
        return
    game.player.position = Vector3(-3.6, 0, -1.8)
    for frame in 20: await process_frame
    game.t2_manual.locked = true
    if game._street_available():
        fail("existing input lock preserved")
        return
    game.t2_manual.locked = false
    game.town_floor_busy = true
    if game._street_available():
        fail("district transition excluded")
        return
    game.town_floor_busy = false
    game.t2_manual.dodge_left = 0.1
    if game._street_available():
        fail("cannot interrupt a running dodge")
        return
    game.t2_manual.dodge_left = 0.0
    for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720)]:
        root.size = dimensions
        for frame in 3: await process_frame
        var attack: Array = game.ui.pad._btns().atk
        if game.street_button.get_global_rect().get_center() != attack[0] or game.street_button.size != Vector2.ONE * attack[1] * 2:
            fail("Talk uses the shared attack center and diameter at each viewport width")
            return
    root.size = Vector2i(1280, 720)
    for frame in 3: await process_frame
    await capture("street-nearby")
    var original_position: Vector3 = game.player.position
    var original_camera: Transform3D = game.cam.global_transform
    var original_flow: Dictionary = game.t2_flow.to_dict()
    var attacks: int = game.t2_manual.attack_count
    for attempt in 2:
        var key := InputEventKey.new()
        key.keycode = KEY_ENTER
        key.pressed = true
        if attempt == 0:
            root.push_input(key, true)
        else:
            var at: Vector2 = game.street_button.get_global_rect().get_center()
            touch(at, true)
            await process_frame
            touch(at, false)
        await process_frame
        if game.t2_manual.attack_count != attacks:
            fail("Talk does not increment Lily attack count")
            return
        if not game.street_active or not game.t2_manual.locked or game.t5_fade.visible:
            fail("Enter locks without blackout")
            return
        await capture("street-camera-transition")
        for frame in 60: await process_frame
        await capture("street-dialogue")
        if not game.t2_dialogue.active or game.t2_active or game.t2_flow.to_dict() != original_flow:
            fail("panel opens without training/state mutation")
            return
        game.t2_manual.move_in = Vector2.RIGHT
        for frame in 15: await physics_frame
        if game.player.position != original_position or game.cam.global_transform != original_camera:
            fail("movement and original camera fixed")
            return
        game.t2_dialogue._close_dialogue()
        for frame in 60: await process_frame
        if game.street_active or game.t2_manual.locked or game.player.position != original_position or root.get_camera_3d() != game.cam or game.cam.global_transform != original_camera:
            fail("restores exact position camera control repeatedly")
            return
    game.t2_manual.move_in = Vector2.RIGHT
    for frame in 8: await physics_frame
    if game.player.position.x <= original_position.x:
        fail("movement restored")
        return
    game.t2_manual.move_in = Vector2.ZERO
    # Exercise the existing training route after repeated street talks, then talk as Rana.
    game.player.position = game.T5_MEETING_POINT
    game._t5_open_briefing()
    for frame in 100:
        if game.t2_dialogue.active: break
        await process_frame
    if not game.t2_dialogue.active or game.street_active:
        fail("training dialogue still opens separately")
        return
    game.t2_dialogue._close_dialogue()
    for frame in 100:
        if game.t2_active and not game.t5_transitioning: break
        await process_frame
    for foe in game.battle.enemies.duplicate():
        game.battle.remove_enemy(foe)
    game._t2_end(true)
    for frame in 180:
        if game.t2_flow.mode == "result": break
        await process_frame
    game._t2_result_action()
    await process_frame
    if game.player != game.t2_rana:
        fail("existing training returns to Rana")
        return
    game.player.position = Vector3(-3.6, 0, -1.8)
    await process_frame
    await process_frame
    var attack: Array = game.ui.pad._btns().atk
    if game.street_button.visible:
        fail("shared Talk action has no duplicate overlay button")
        return
    touch(attack[0], true)
    await process_frame
    touch(attack[0], false)
    if game.t2_rana.atk_held:
        fail("Talk touch never presses attack")
        return
    for frame in 60: await process_frame
    if not game.street_active or not game.t2_rana.locked or game.ui.pad.is_processing_input():
        fail("Rana and shared touch controls lock")
        return
    game.t2_dialogue._close_dialogue()
    for frame in 60: await process_frame
    if game.t2_rana.locked or not game.ui.pad.is_processing_input():
        fail("Rana shared controls restore")
        return
    await capture("street-return-rana")
    game.player.position = Vector3(0, 0, 0)
    await process_frame
    if game.ui.attack_is_contextual():
        fail("leaving range restores attack action")
        return
    touch(attack[0], true)
    await process_frame
    if not game.t2_rana.atk_held:
        fail("same slot receives attack outside talk range")
        return
    touch(attack[0], false)
    print("SA2_T6_STREET_PASS: range Enter no-blackout lock camera repeat flow-isolation movement")
    quit(0)
func fail(message: String) -> void:
    push_error("SA2_T6_STREET_FAIL: " + message)
    quit(1)

func touch(at: Vector2, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = at
    event.pressed = down
    Input.parse_input_event(event)

func capture(label: String) -> void:
    var folder := OS.get_environment("SA2_STREET_CAPTURE")
    if folder.is_empty(): return
    await process_frame
    RenderingServer.force_draw(false)
    if root.get_texture().get_image().save_png(folder.path_join(label + ".png")) != OK:
        fail("capture " + label)
