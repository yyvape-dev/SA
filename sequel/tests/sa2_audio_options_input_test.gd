extends SceneTree
func _initialize(): call_deferred("run")
func run():
    root.size = Vector2i(1280,720)
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for i in 1200:
        if is_instance_valid(game.t2_dialogue): break
        await process_frame
    for i in 10: await process_frame
    var options = game.battle.combat_audio.options_ui
    options.toggle_panel()
    var e := InputEventScreenTouch.new()
    e.index = 0; e.position = Vector2(100,500); e.pressed = true
    game._input(e)
    assert(game.t2_finger == -1)
    var dialogue = game.t2_dialogue
    dialogue.active = true
    dialogue.lines = [{"text":"one"},{"text":"two"}]
    dialogue.line_index = 0
    dialogue.body.visible_characters = -1
    dialogue._unhandled_input(e)
    assert(dialogue.line_index == 0)
    print("OPTIONS_INPUT_PASS: legacy touch and dialogue advance blocked")
    quit()
