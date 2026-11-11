extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null:
            break
        await process_frame
    game.t2_flow.begin_dialogue("C1-06", Vector3.ZERO)
    game.t2_flow.finish_dialogue()
    game._t2_start_training(false)
    var manual = game.t2_manual
    var actor = game.t2_lily
    manual.set_physics_process(false)
    for foe in game.battle.enemies:
        foe.hp = 10000.0
        foe.set_physics_process(false)
        foe.position = actor.position + Vector3(1, 0, 0)
    manual.attack_press()
    manual.attack_release()
    manual.attack_press()
    manual.attack_release()
    for frame in 23:
        game.battle.freeze = 0.0
        manual._physics_process(1.0 / 60.0)
    if manual.attack_count != 2:
        push_error("T6_TEMPO_FAIL: buffered tap must chain after both jab hits within 0.383s")
        quit(1)
        return
    if actor.clip != "atk_highkick":
        push_error("T6_TEMPO_FAIL: next normal attack follows combo order")
        quit(1)
        return
    manual.attack_press()
    manual.locked = true
    manual._physics_process(0.1)
    manual.locked = false
    for frame in 100:
        game.battle.freeze = 0.0
        manual._physics_process(1.0 / 60.0)
    if manual.attack_count != 2:
        push_error("T6_TEMPO_FAIL: dialogue lock clears buffered input")
        quit(1)
        return
    print("T6_TEMPO_PASS: faster normal combo, buffered press/release, full multi-hit before chain, lock clears queue")
    quit(0)
