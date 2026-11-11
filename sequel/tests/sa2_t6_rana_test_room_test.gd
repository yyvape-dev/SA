extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    game.set("rana_test_room", true)
    root.add_child(game)
    for frame in 1200:
        if game.get("rana_test_ready") == true: break
        await process_frame
    if game.get("rana_test_ready") != true:
        push_error("RANA_ROOM_FAIL: direct Rana battle entry missing")
        quit(1)
        return
    assert(game.player == game.t2_rana and game.ui.player == game.t2_rana)
    assert(not game.ui.lily_controls and game.ui.pad.is_processing_input())
    assert(not game.t2_dialogue.active and not game.t2_lily.visible)
    assert(not game.ui.pad._btns().has("gear"))
    assert(game.battle.enemies.size() == 3 and game.battle.ult == 200.0)
    if OS.has_environment("RANA_ROOM_CAPTURE"):
        for frame in 120: await process_frame
        RenderingServer.force_draw(false)
        root.get_texture().get_image().save_png(OS.get_environment("RANA_ROOM_CAPTURE"))
    var xp: int = game.progress.xp
    game._on_foe_killed(game.battle.enemies[0])
    assert(game.progress.xp == xp)
    assert(game.t2_rana.use_skill("flurry"))
    game.battle.hp = 12
    game._rana_reset_room()
    assert(game.battle.hp == 100 and game.t2_rana.skill_cd.flurry == 0)
    assert(game.battle.ult == 200 and game.battle.enemies.size() == 3)
    assert(game.player.position == Vector3.ZERO and game.player.state == "move")
    for slot in [1, 2]:
        game.ui.pad._press("sk" + str(slot))
        assert(game.player.skill_id == ["flurry", "rift", "vortex"][slot])
        game._rana_reset_room()
    game.rana_enemy_button.pressed.emit()
    assert(game.rana_live_enemies and game.battle.enemies[0].atk_cd < 1.0)
    var taken: int = game.battle.hits_taken
    for frame in 180: await physics_frame
    assert(game.battle.hits_taken > taken)
    game._rana_reset_room()
    assert(game.t2_rana.use_ult())
    game._rana_reset_room()
    assert(game.player.state == "ult") # reset during cinematic must wait
    print("RANA_ROOM_PASS: direct control, all skills, enemies, repeat reset, cinematic guard")
    quit()
