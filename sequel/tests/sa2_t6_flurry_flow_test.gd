extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null: break
        await process_frame
    var p = game.t2_rana
    var first := {}
    var last := {}
    for i in [0, 9, 0]:
        p.hit_i = i
        var spec: Dictionary = p.skills.flurry.ev[i][1].duplicate(true)
        spec.dmg = 0.0
        game.battle.player_skill(spec, p)
        if i == 9:
            last = spec.slash.duplicate(true)
        elif first.is_empty():
            first = spec.slash.duplicate(true)
        elif first != spec.slash:
            push_error("FLURRY_FLOW_FAIL: identical swing must keep authored direction and size")
            quit(1)
            return
    if float(last.w) <= float(first.w) or float(last.r) > 2.5:
        push_error("FLURRY_FLOW_FAIL: crescendo grows trail thickness within attack reach")
        quit(1)
        return
    print("FLURRY_FLOW_PASS: repeatable authored flow, crescendo, bounded visual reach")
    quit()
