extends SceneTree
func _initialize():
    var launcher=load('res://scripts/sa2_td_launcher.gd')
    if launcher==null:quit(1);return
    assert(launcher.scene_path('t2')=='res://sa2_t2_playable.tscn')
    assert(launcher.scene_path('t3')=='res://sa2_t3_playable.tscn')
    assert(launcher.scene_path('../main')=='')
    var probe=load('res://scripts/sa2_td_diagnostics.gd').new()
    probe.path='user://sa2_td_test_probe.json'
    assert(probe.read_probe().is_empty())
    assert(probe.write_probe('roundtrip'))
    assert(probe.read_probe().token=='roundtrip')
    probe.sample(0.016);probe.sample(0.032)
    assert(probe.report().p95_ms==32.0)
    DirAccess.remove_absolute(probe.path)
    print('SA2_TD_TEST_PASS');quit()
