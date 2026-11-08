extends SceneTree

const Flow = preload("res://scripts/sa2_flow_state.gd")
const Playable = preload("res://sa2_t2_playable.tscn")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        printerr("SA2_T2_5_FAIL: ", label)

func saved_result(won: bool):
    var flow = Flow.new()
    flow.begin_dialogue("C1-06", Vector3(-4, 0, 1))
    flow.finish_dialogue()
    flow.enter_battle("C1-06", Vector3(-4, 0, 1))
    flow.finish_battle(won)
    return flow

func open_scene(flow):
    check(flow.save_to("user://sa2_t2_progress.json"), "write fixture")
    var scene = Playable.instantiate()
    root.add_child(scene)
    for frame in 2400:
        if scene.t2_dialogue != null:
            break
        await process_frame
    await process_frame
    await process_frame
    check(scene.t2_dialogue != null, "scene ready")
    return scene

func close_scene(scene) -> void:
    scene.queue_free()
    await process_frame
    await process_frame

func _run() -> void:
    for won in [false, true]:
        var scene = await open_scene(saved_result(won))
        check(scene.t2_flow.mode == Flow.RESULT, "restart preserves RESULT " + str(won))
        check(scene.t2_flow.result == ("win" if won else "lose"), "restart preserves outcome")
        check(scene.t2_result_button.visible, "restart shows result action")
        var disk = Flow.new()
        check(disk.load_from("user://sa2_t2_progress.json") and disk.mode == Flow.RESULT, "restart does not overwrite result save")
        await close_scene(scene)
    var completed = saved_result(true)
    completed.return_to_explore()
    var scene = await open_scene(completed)
    check(scene.t2_flow.completed.get("C1-06", false), "restart preserves completion")
    check(scene.player == scene.t2_rana and scene.battle.player == scene.t2_rana, "restart restores Rana")
    check(scene.battle.ally == scene.t2_lily and scene.t2_lily.is_physics_processing(), "restart restores Lily AI")
    await close_scene(scene)
    scene = await open_scene(saved_result(true))
    # Also cover the ordinary live victory/return path independently of restart support.
    if scene.t2_flow.mode != Flow.RESULT:
        scene.t2_flow = saved_result(true)
    var manual = scene.t2_manual
    scene._t2_result_action()
    await process_frame
    await process_frame
    check(not is_instance_valid(manual), "manual adapter released")
    for node in scene.t2_layer.find_children("*", "Button", true, false):
        if node is Button:
            check(not node.is_visible_in_tree(), "no live training button after exploration return: " + node.text)
    await close_scene(scene)
    DirAccess.remove_absolute("user://sa2_t2_progress.json")
    if failures.is_empty():
        print("SA2_T2_5_RECOVERY_PASS: result restart, completed restart, live controls teardown")
    quit(0 if failures.is_empty() else 1)
