extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
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
    var training_start: Vector3 = game.t2_lily.position
    _key(KEY_D, true)
    for frame in 14:
        await physics_frame
    _key(KEY_D, false)
    if game.t2_lily.position.x <= training_start.x:
        _fail("training returns movement to the player")
        return
    for frame in 50:
        await process_frame
    print("SA2_T5_PREVIEW_PASS: explore, proximity, four lines, two fades, camera swap, input lock, two targets, movement restored")
    quit(0)

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
