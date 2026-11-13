extends SceneTree
var cues: Array = []
func _initialize(): call_deferred("run")
func run():
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    game.rana_test_room = true
    root.add_child(game)
    for frame in 1200:
        if game.rana_test_ready: break
        await process_frame
    game.set_process(false)
    game.player.set_physics_process(false)
    game.t2_lily.set_physics_process(false)
    game.battle.set_process(false)
    var sound = game.battle.combat_audio
    sound.cue_played.connect(func(cue): cues.append(cue))
    game._rana_reset_room()
    game.battle.ult = game.battle.ULT_COST
    assert(game.player.use_ult())
    assert(cues == ["ult_charge"])
    assert(not game.player.use_ult())
    assert(cues == ["ult_charge"])
    game.player._ult_process(game.player.ULT_T.cut_end)
    assert(cues.count("ult_release") == 1)
    game.player._ult_process(0.01)
    assert(cues.count("ult_release") == 1)
    for i in 12: sound.play_cue("hit")
    assert(sound.cinematic_voice.stream == sound.streams.ult_release)
    sound.set_audio_options(1, 0, false)
    assert(sound.cinematic_voice.volume_db <= -80)
    sound.set_audio_options(1, 1, false)
    cues.clear()
    game._rana_reset_room()
    var lily = game.t2_lily
    lily._start_ult(game.battle.enemies[0])
    assert(cues == ["ult_charge"])
    lily._ult_process(lily.ULT_CUT.cut_end)
    assert(cues.count("ult_release") == 1)
    lily._ult_process(0.01)
    assert(cues.count("ult_release") == 1)
    print("ULTIMATE_AUDIO_PASS: Rana/Lily start, rejection, release once, dedicated voice, SE volume")
    quit()
