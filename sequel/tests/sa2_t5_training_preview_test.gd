extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var wide := OS.has_environment("SA2_T6_WIDE")
    root.size = Vector2i(1560 if wide else 1280, 720)
    var preview := load("res://sa2_t5_training_preview.tscn") as PackedScene
    if preview == null:
        quit(1)
        return
    var game = preview.instantiate()
    root.add_child(game)
    for frame in 600:
        if is_instance_valid(game.t2_dialogue):
            break
        await process_frame
    if not is_instance_valid(game.t2_dialogue) or game.t2_flow.mode != "explore":
        _fail("starts in exploration")
        return
    if game.town != "back" or game.find_child("street_overpass", true, false) == null:
        _fail("T5 starts on the current Backtown map")
        return
    _key(KEY_ENTER, true)
    _key(KEY_ENTER, false)
    await process_frame
    if game.t2_dialogue.active:
        _fail("cannot open from out of range")
        return
    for frame in 15:
        await process_frame
    _key(KEY_D, true)
    for frame in 130:
        if game.t5_talk_button.visible:
            break
        await physics_frame
    _key(KEY_D, false)
    if not game.t5_talk_button.visible:
        _fail("normal movement reaches the interaction")
        return
    for frame in 16:
        await process_frame
    var approach_position: Vector3 = game.t2_lily.position
    _key(KEY_ENTER, true)
    _key(KEY_ENTER, false)
    await process_frame
    if game.t2_dialogue.active or game.t2_lily.position != approach_position or not game.t2_manual.locked:
        _fail("talk locks input before moving actors or showing dialogue")
        return
    for frame in 90:
        if game.t2_dialogue.active:
            break
        await process_frame
    if root.get_camera_3d() == game.cam or game.t2_lily.position == approach_position:
        _fail("dark cut stages actors and switches to a dedicated dialogue camera")
        return
    if not game.t2_dialogue.active or game.t2_dialogue.speaker.text != "教官":
        _fail("interaction starts the instructor dialogue")
        return
    var rana_idle := game.get_node_or_null("RanaEventIdle") as Sprite3D
    var lily_idle := game.get_node_or_null("LilyEventIdle") as Sprite3D
    if rana_idle == null or lily_idle == null or not rana_idle.visible or not lily_idle.visible or game.t2_rana.visible or game.t2_lily.visible:
        _fail("both event sprites replace the original actors during dialogue")
        return
    if game.ui.pad.is_processing_input():
        _fail("combat touch input remains disabled during dialogue")
        return
    await _capture("dialogue")
    var idle_frame := rana_idle.frame
    var stopped: Vector3 = game.t2_lily.position
    _key(KEY_D, true)
    for frame in 12:
        await physics_frame
    _key(KEY_D, false)
    if stopped != game.t2_lily.position:
        _fail("dialogue locks movement")
        return
    if rana_idle.frame == idle_frame or lily_idle.frame == idle_frame:
        _fail("both event sprites advance during dialogue")
        return
    for line in 4:
        if game.t2_dialogue.line_index != line:
            _fail("each line is reached in order")
            return
        while game.t2_dialogue.body.visible_characters != -1:
            await process_frame
        for frame in 18:
            await process_frame
        _key(KEY_SPACE, true)
        _key(KEY_SPACE, false)
        await process_frame
    if game.t2_active or not game.t2_manual.locked or root.get_camera_3d() == game.cam:
        _fail("closing dialogue starts a separate fade with input still locked")
        return
    for frame in 90:
        if game.t2_active and not game.t2_manual.locked:
            break
        await process_frame
    if root.get_camera_3d() != game.cam or game.t2_manual.locked:
        _fail("gameplay camera and movement return after the reveal")
        return
    if game.t2_dialogue.active or not game.t2_active or game.t2_flow.mode != "instance_battle" or game.battle.enemies.size() != 2:
        _fail("dialogue closes and the two-target exercise starts")
        return
    if rana_idle.visible or lily_idle.visible or not game.t2_lily.visible:
        _fail("event sprites leave and combat Lily returns at the second cut")
        return
    await _capture("lily")
    var training_start: Vector3 = game.t2_lily.position
    _key(KEY_D, true)
    for frame in 14:
        await physics_frame
    _key(KEY_D, false)
    if game.t2_lily.position.x <= training_start.x:
        _fail("training returns movement to the player")
        return
    if not game.ui.visible or not game.ui.pad.is_processing_input() or game.hud.visible:
        _fail("training uses the common touch pad")
        return
    var pad: Control = game.ui.pad
    var buttons: Dictionary = pad._btns()
    if buttons.size() != 2 or not buttons.has("atk") or not buttons.has("dodge"):
        _fail("Lily only exposes her supported actions")
        return
    var stick := Vector2(200, pad.size.y - 170)
    _touch(0, stick, true)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = stick + Vector2(100, 0)
    root.push_input(drag, true)
    if game.t2_manual.move_in.x < 0.95:
        _fail("shared stick sends movement to Lily")
        return
    _touch(0, drag.position, false)
    if game.t2_manual.move_in != Vector2.ZERO:
        _fail("shared stick release clears movement")
        return

    var attacks: int = game.t2_manual.attack_count
    _touch(1, buttons.atk[0], true)
    if game.t2_manual.attack_count != attacks + 1 or not pad.btn_down.has("atk"):
        _fail("attack starts on touch down")
        return
    _touch(3, buttons.atk[0], true)
    _touch(3, buttons.atk[0], false)
    if not pad.btn_down.has("atk"):
        _fail("a second finger cannot release the first attack press")
        return
    _touch(1, buttons.atk[0], false)
    if game.t2_manual.attack_count != attacks + 1 or pad.btn_down.has("atk"):
        _fail("attack releases without starting another Lily technique")
        return
    for frame in 150:
        if game.t2_lily.state == "move":
            break
        await physics_frame
    var foe = game.battle.enemies[0]
    foe.position = game.t2_lily.position + Vector3(1.2, 0, 0)
    foe.face = -1
    foe._start_atk()
    foe.atk.t = float(foe.atk.hit_t) - 0.24
    await _capture("warning")
    var hp: float = game.battle.hp
    _touch(2, buttons.dodge[0], true)
    _touch(2, buttons.dodge[0], false)
    if game.t2_manual.guard_count != 1 or foe.state != "stun" or game.battle.hp != hp:
        _fail("the dodge button triggers Lily's timed guard")
        return
    await _capture("guard")
    _touch(2, buttons.dodge[0], true)
    _touch(2, buttons.dodge[0], false)
    if game.t2_manual.dodge_count != 1:
        _fail("the same button dodges outside the guard window")
        return
    await _capture("dodge")
    for frame in 20:
        await physics_frame

    _touch(0, stick, true)
    game.battle.hp = 1.0
    game.t2_lily.inv = 0.0
    foe.position = game.t2_lily.position + Vector3(0.5, 0, 0)
    foe.face = -1
    foe._start_atk()
    foe.atk.t = float(foe.atk.hit_t)
    for frame in 30:
        if game.t2_flow.result == "lose":
            break
        await physics_frame
    if game.t2_flow.result != "lose" or game.ui.pad.is_processing_input():
        _fail("a lethal hit locks touch input and offers a retry")
        return
    game.t2_result_button.pressed.emit()
    if not game.t2_active or not game.ui.pad.is_processing_input() or game.battle.hp != game.battle.hp_max:
        _fail("retry restores the shared touch controls and HP")
        return

    root.push_input(drag, true)
    if game.t2_manual.move_in != Vector2.ZERO:
        _fail("retry cannot inherit a touch from the previous attempt")
        return
    _touch(0, drag.position, false)
    var captured_hit := false
    for attempt in 90:
        if game.t2_done:
            break
        var target = game.t2_lily._nearest()
        if target != null:
            var offset: Vector3 = target.position - game.t2_lily.position
            var direction := Vector2(signf(offset.x) if absf(offset.x) > 1.3 else 0.0, signf(offset.z) if absf(offset.z) > 0.3 else 0.0)
            _touch(0, stick, true)
            drag.position = stick + direction.normalized() * 100.0
            root.push_input(drag, true)
            for frame in 8:
                await physics_frame
            _touch(0, drag.position, false)
        var target_hp: float = target.hp if is_instance_valid(target) else 0.0
        _touch(1, buttons.atk[0], true)
        _touch(1, buttons.atk[0], false)
        for frame in 28:
            await physics_frame
            if not captured_hit and is_instance_valid(target) and target.hp < target_hp:
                await _capture("hit")
                captured_hit = true
    if game.t2_flow.result != "win" or game.ui.pad.is_processing_input() or not captured_hit:
        _fail("touch attacks can win and lock the pad on the results screen")
        return
    game.t2_result_button.pressed.emit()
    await process_frame
    var rana_buttons: Dictionary = pad._btns()
    if game.player != game.t2_rana or not game.hud.visible or not rana_buttons.has("sk0") or rana_buttons.atk != buttons.atk or rana_buttons.dodge != buttons.dodge:
        _fail("Rana returns with the same attack/dodge geometry and her skill slots")
        return
    if OS.has_environment("SA2_T6_CAPTURE"):
        game.battle.spawn("1", game.t2_rana.position + Vector3(1.5, 0, 0))
    await _capture("rana")
    _touch(1, rana_buttons.atk[0], true)
    if not game.t2_rana.atk_held:
        _fail("Rana still receives attack presses")
        return
    _touch(1, rana_buttons.atk[0], false)
    if game.t2_rana.atk_held:
        _fail("Rana still receives attack releases")
        return
    _touch(2, rana_buttons.dodge[0], true)
    _touch(2, rana_buttons.dodge[0], false)
    if game.t2_rana.state != "dodge":
        _fail("Rana still receives dodge presses")
        return
    print("SA2_T5_PREVIEW_PASS: dialogue, fades, touch move/press/release, Lily guard and dodge, defeat/retry, win/return, Rana input regression")
    quit(0)

func _capture(label: String) -> void:
    var folder := OS.get_environment("SA2_T6_CAPTURE")
    if folder.is_empty():
        return
    await process_frame
    RenderingServer.force_draw(false)
    var image := root.get_texture().get_image()
    if image.save_png(folder.path_join(label + ".png")) != OK:
        _fail("cannot save " + label + " capture")

func _touch(index: int, position: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    root.push_input(event, true)

func _key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.pressed = pressed
    if code == KEY_D:
        Input.parse_input_event(event)
    else:
        root.push_input(event, true)

func _fail(message: String) -> void:
    push_error("SA2_T5_PREVIEW_FAIL: " + message)
    quit(1)
