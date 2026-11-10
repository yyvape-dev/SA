extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1560 if OS.has_environment("SA2_T6_WIDE") else 1280, 720)
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for i in 1200:
        if game.t2_manual != null:
            break
        await process_frame
    var manual = game.t2_manual
    if not manual.has_method("use_skill") or not manual.has_method("use_ult"):
        push_error("T6_FAIL: manual Lily has no skill input")
        quit(1)
        return

    game.t2_flow.begin_dialogue("C1-06", Vector3.ZERO)
    game.t2_flow.finish_dialogue()
    game._t2_start_training(false)
    for id in ["rush", "barrage", "storm", "ult"]:
        for foe in game.battle.enemies:
            foe.hp = 10000.0
            foe.hp_max = 10000.0
            foe.set_physics_process(false)
        manual.reset_training()
        game.t2_lily.state = "move"
        game.battle.ally_ult = game.battle.ULT_MAX
        var target = game.battle.enemies[0]
        target.position = game.t2_lily.position + Vector3(1.0, 0, 0)
        if id == "ult":
            manual.use_ult()
        else:
            if not manual.use_skill(id):
                _fail("skill refused " + id)
                return
            if manual.use_skill(id):
                _fail("skill can be retriggered while active")
                return
        await _capture(id + "_start")
        for frame in 600:
            await physics_frame
            if frame == 24:
                await _capture(id + "_hit")
            if game.t2_lily.state == "move":
                break
        if game.t2_lily.state != "move" or target.hp >= 10000.0:
            _fail("existing skill must finish and damage its target " + id)
            return
        if int(game.t2_lily.sk_used.get(id, 0)) != 1:
            _fail("skill executes exactly once " + id)
            return
    manual.reset_training()
    manual.attack_press()
    for foe in game.battle.enemies.duplicate():
        foe.take_hit(100000.0, 1, true)
        foe.set_physics_process(true)
    if not game.t6_finishing or manual.locked or game.t2_result_button.visible:
        _fail("victory must let the current animation finish")
        return
    for frame in 600:
        await physics_frame
        if game.t2_result_button.visible:
            break
    if game.t2_lily.state != "move" or not game.t6_retry_button.visible or game.t2_flow.result != "win":
        _fail("victory settles before showing both choices")
        return
    await _capture("result")
    var position: Vector3 = game.t2_lily.position
    manual.move_in = Vector2.RIGHT
    for frame in 10:
        await physics_frame
    manual.move_in = Vector2.ZERO
    if game.t2_lily.position.x <= position.x:
        _fail("movement works while the result choices are visible")
        return
    game.t6_retry_button.pressed.emit()
    if game.t2_done or game.t2_result_button.visible or game.battle.enemies.size() != 2 or game.battle.hp != 100.0:
        _fail("retry restores a fresh exercise")
        return
    for cd in manual.skill_cd.values():
        if float(cd) != 0.0:
            _fail("retry resets skill cooldowns")
            return
    game.battle.hp = 0.0
    for frame in 60:
        await process_frame
        if game.t2_flow.result == "lose":
            break
    game.t2_result_button.pressed.emit()
    await process_frame
    if game.player != game.t2_rana or game.ui.lily_controls or game.battle.manual_ally != null:
        _fail("leaving the exercise restores Rana")
        return
    print("T6_PASS: four existing skills, damage, recovery, death animation, result movement, retry reset, leave on defeat")

    quit(0)

func _fail(message: String) -> void:
    push_error("T6_FAIL: " + message)
    quit(1)

func _capture(label: String) -> void:
    var folder := OS.get_environment("SA2_T6_CAPTURE")
    if folder.is_empty():
        return
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
