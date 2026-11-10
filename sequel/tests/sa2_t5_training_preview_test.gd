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
    _key(KEY_ENTER, true)
    _key(KEY_ENTER, false)
    await process_frame
    if not game.t2_dialogue.active or game.t2_dialogue.speaker.text != "教官":
        _fail("interaction starts the instructor dialogue")
        return
    var stopped: Vector3 = game.t2_lily.position
    _key(KEY_D, true)
    for frame in 12:
        await physics_frame
    _key(KEY_D, false)
    if stopped != game.t2_lily.position:
        _fail("dialogue locks movement")
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
    if game.t2_dialogue.active or not game.t2_active or game.t2_flow.mode != "instance_battle" or game.battle.enemies.size() != 2:
        _fail("dialogue closes and the two-target exercise starts")
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
    print("SA2_T5_PREVIEW_PASS: explore, proximity, four lines, input lock, two targets, movement restored")
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
