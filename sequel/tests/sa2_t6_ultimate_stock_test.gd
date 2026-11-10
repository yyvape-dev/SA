extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(1560 if OS.has_environment("SA2_T6_WIDE") else 1280, 720)
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null:
            break
        await process_frame
    game.t2_flow.begin_dialogue("C1-06", Vector3.ZERO)
    game.t2_flow.finish_dialogue()
    game._t2_start_training(false)
    if game.battle.ally_ult != 200.0:
        _fail("exercise starts with two stocks")
        return
    for foe in game.battle.enemies:
        foe.hp = 10000.0
        foe.hp_max = 10000.0
        foe.set_physics_process(false)
        foe.position = game.t2_lily.position + Vector3(1, 0, 0)
    var buttons: Dictionary = game.ui.pad._btns()
    for key in buttons:
        if key == "ult":
            continue
        if buttons.ult[0].distance_to(buttons[key][0]) <= float(buttons.ult[1] + buttons[key][1]) * 1.15:
            _fail("ultimate touch area overlaps another action")
            return
    for frame in 60:
        await process_frame
    await _capture("two_stocks")
    for stock in [1, 0]:
        game.ui.pad._press("ult")
        if game.battle.ally_ult != float(stock * 100):
            _fail("one cast must consume exactly one stock")
            return
        var used: int = int(game.t2_lily.sk_used.get("ult", 0))
        game.ui.pad._press("ult")
        if int(game.t2_lily.sk_used.get("ult", 0)) != used:
            _fail("one gesture cannot spend both stocks during a cast")
            return
        for frame in 600:
            await physics_frame
            if game.t2_lily.state == "move":
                break
        await _capture("stock_" + str(stock))
        if game.t2_lily.state != "move":
            _fail("ultimate finishes")
            return
    game.ui.pad._press("ult")
    if int(game.t2_lily.sk_used.get("ult", 0)) != 2:
        _fail("third cast is rejected when empty")
        return
    game.battle.ally_ult = 99.0
    game.t2_manual.use_ult()
    if int(game.t2_lily.sk_used.get("ult", 0)) != 2:
        _fail("partial stock cannot cast")
        return
    game.battle.ally_ult = 199.8
    game.battle.ally_attack(game.t2_lily, {"side": 0, "r": 10.0, "lane": 5.0, "dmg": 1.0, "strong": false})
    if game.battle.ally_ult != 200.0:
        _fail("hits fill and clamp the second stock")
        return
    game._t2_end(true)
    for foe in game.battle.enemies.duplicate():
        game.battle.remove_enemy(foe)
    for frame in 120:
        await physics_frame
        if game.t2_result_button.visible:
            break
    game.t2_result_button.pressed.emit()
    await process_frame
    game.t2_lily.set_physics_process(false)
    game.battle.ult = 200.0
    game.t2_rana.state = "move"
    for stock in [1, 0]:
        if not game.t2_rana.use_ult() or game.battle.ult != float(stock * 100):
            _fail("Rana uses the same stock rules")
            return
        for frame in 600:
            await physics_frame
            if game.t2_rana.state == "move":
                break
    print("T6_STOCK_PASS: two stocks, sequential casts, empty/partial rejection, cap, separate touch regions, Rana regression")
    quit(0)

func _fail(message: String) -> void:
    push_error("T6_STOCK_FAIL: " + message)
    quit(1)

func _capture(label: String) -> void:
    var folder := OS.get_environment("SA2_T6_CAPTURE")
    if folder.is_empty():
        return
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
