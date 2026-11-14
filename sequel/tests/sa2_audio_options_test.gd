extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var audio = load("res://scripts/combat_audio.gd").new()
    audio.settings_path = "user://audio_options_test.cfg"
    if FileAccess.file_exists(audio.settings_path): DirAccess.remove_absolute(audio.settings_path)
    root.add_child(audio)
    audio.set_audio_options(0.5, 0.25, false)
    audio.set_region("back", false)
    assert(is_equal_approx(audio.music.volume_db, -20.0 + linear_to_db(0.5)))
    audio.set_dialogue_duck(true)
    assert(is_equal_approx(audio.music.volume_db, -28.0 + linear_to_db(0.5)))
    audio.play_cue("hit")
    assert(is_equal_approx(audio.voices[0].volume_db, -12.0 + linear_to_db(0.25)))
    audio.set_audio_options(0.5, 0.25, true)
    assert(audio.music.volume_db <= -80 and audio.voices[0].volume_db <= -80)
    audio.set_audio_options(0.5, 0.25, false)
    assert(is_equal_approx(audio.voices[0].volume_db, -12.0 + linear_to_db(0.25)))
    var again = load("res://scripts/combat_audio.gd").new()
    again.settings_path = audio.settings_path
    root.add_child(again)
    assert(again.bgm_gain == 0.5 and again.se_gain == 0.25 and not again.muted)
    assert(again.options_ui != null and not again.options_ui.panel.visible)
    again.options_ui.toggle_panel()
    again.options_ui.bgm_slider.value = 30
    again.options_ui.se_slider.value = 70
    again.options_ui.mute_toggle.button_pressed = true
    assert(again.bgm_gain == 0.3 and again.se_gain == 0.7 and again.muted)
    assert(again.options_ui.blocks_touch(Vector2(1,1)))
    again.options_ui.toggle_panel()
    assert(not again.options_ui.blocks_touch(Vector2(1,1)))
    audio.set_audio_options(0, 0, false)
    assert(audio.music.volume_db <= -80)
    audio.queue_free(); again.queue_free()
    await process_frame
    DirAccess.remove_absolute("user://audio_options_test.cfg")
    print("AUDIO_OPTIONS_PASS: independent gain, duck, active mute, restore, persistence, touch gate")
    quit()
