extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    root.size = Vector2i(1280, 720)
    var panel = load("res://ui/sa2_dialogue_panel.tscn").instantiate()
    root.add_child(panel)
    var data = {"lines": [{"speaker": "教官", "text": "訓練を始めます。"}, {"speaker": "リリィ", "text": "お願いします。"}]}
    assert(panel.start(data))
    panel.advance()
    panel.open_log()
    assert(not panel.advance())
    assert(panel.line_index == 0 and panel.log_text.text.contains("訓練を始めます。"))
    panel.auto_enabled = true
    panel._process(20)
    assert(panel.line_index == 0)
    panel.close_log()
    panel._process(2)
    assert(panel.line_index == 1)
    panel.skip_confirm.popup_centered()
    assert(not panel.advance())
    panel.skip_confirm.hide()
    panel._close_dialogue()
    assert(not panel.active)
    assert(panel.start(data) and panel.history.size() == 1 and not panel.auto_enabled)
    print("T6_DIALOGUE_UI_PASS: log pauses, auto waits, skip modal blocks advance, restart resets")
    quit()
