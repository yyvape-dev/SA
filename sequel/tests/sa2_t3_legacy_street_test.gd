extends SceneTree
func _initialize():call_deferred("run")
func run():
    OS.set_environment("TOWN","")
    var main=load("res://main.tscn").instantiate();root.add_child(main)
    for i in 2400:
        if main.battle!=null and main.battle.ally!=null:break
        await process_frame
    for i in 100:await physics_frame;await process_frame
    var ok=main.battle.combat_policy==null and main.battle.auto_spawn and main.battle.wave>=1 and main.battle.enemies.size()==3 and main.player==main.battle.player and main.battle.ally.is_physics_processing()
    if not ok:printerr("SA2_T3_LEGACY_FAIL: null-policy normal street wave/input/AI")
    main.queue_free();await process_frame;await process_frame
    if ok:print("SA2_T3_LEGACY_STREET_PASS")
    quit(0 if ok else 1)
