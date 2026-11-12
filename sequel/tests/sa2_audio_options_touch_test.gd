extends SceneTree
func _initialize(): call_deferred("run")
func touch(at: Vector2, down: bool):
    var e := InputEventScreenTouch.new()
    e.index = 0; e.position = at; e.pressed = down
    Input.parse_input_event(e)
    var m := InputEventMouseButton.new()
    m.position = at; m.button_index = MOUSE_BUTTON_LEFT; m.pressed = down
    Input.parse_input_event(m)
    await process_frame
func run():
    root.size = Vector2i(1280,720)
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    game.rana_test_room = true
    root.add_child(game)
    for i in 1200:
        if game.rana_test_ready: break
        await process_frame
    for i in 10: await process_frame
    var options = game.battle.combat_audio.options_ui
    var center = options.button.get_global_rect().get_center()
    print("BUTTON ", center, " root ",root.size)
    await touch(center, true); await touch(center, false)
    assert(options.panel.visible)
    await touch(Vector2(100, 500), true)
    for pad in get_nodes_in_group("sound_touch_pad"):
        assert(pad.stick_id == -1 and pad.btn_down.is_empty())
    await touch(Vector2(100, 500), false)
    options.bgm_slider.value = 35
    assert(game.battle.combat_audio.bgm_gain == 0.35)
    options.toggle_panel()
    game.battle.combat_audio.set_audio_options(1,1,false)
    print("OPTIONS_TOUCH_PASS: actual icon tap, gameplay gate, slider signal")
    quit()
