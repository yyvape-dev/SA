extends SceneTree
var cues: Array = []
func _initialize():
    call_deferred("run")
func run():
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    game.rana_test_room = true
    root.add_child(game)
    for frame in 1200:
        if game.rana_test_ready: break
        await process_frame
    if game.battle.get("combat_audio") == null:
        push_error("AUDIO_FAIL: combat cues not integrated")
        quit(1)
        return
    game.battle.combat_audio.cue_played.connect(func(cue): cues.append(cue))
    var spec = {"side":1,"r":0.01,"lane":0.01,"dmg":1.0,"strong":false,"slash":game.player.SL_THRUST}
    game.battle.player_attack(spec)
    assert(cues == ["swing"])
    cues.clear()
    spec.r = 50.0
    spec.lane = 50.0
    game.battle.player_attack(spec)
    assert(cues == ["swing", "hit"])
    cues.clear()
    spec.strong = true
    game.battle.player_attack(spec)
    assert(cues == ["swing", "heavy"])
    cues.clear()
    game.battle.just_guard(game.player, game.battle.enemies[0])
    assert(cues == ["guard"])
    assert(game.battle.combat_audio.streams.guard.get_length() > game.battle.combat_audio.streams.guard_dry.get_length())
    cues.clear()
    game._rana_reset_room()
    assert(game.player.use_skill("flurry"))
    assert(not game.player.use_skill("flurry"))
    assert(cues == ["skill"])
    cues.clear()
    game._rana_reset_room()
    game.player.dodge()
    game.player.dodge()
    assert(cues == ["dash"])
    print("AUDIO_PASS: swing without contact, one hit per strike not per foe, heavy, guard tail")
    game.queue_free()
    for frame in 3: await process_frame
    quit()
