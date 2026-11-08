extends SceneTree
## Delay the real loader across the old 120-frame limit; retain real scene/actor creation.
const Playable = preload("res://scripts/sa2_t2_playable.gd")
const Flow = preload("res://scripts/sa2_flow_state.gd")

class DelayedPlayable extends Playable:
    func _load_ally() -> void:
        for i in 180:
            await get_tree().process_frame
        await super._load_ally()

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        printerr("SA2_T2_ASSET_WAIT_FAIL: ", label)

func _run() -> void:
    var flow = Flow.new()
    flow.begin_dialogue("C1-06", Vector3(-4, 0, 1))
    check(flow.save_to("user://sa2_t2_progress.json"), "write isolated dialogue fixture")
    var scene = DelayedPlayable.new()
    root.add_child(scene)
    for i in 600:
        if scene.t2_dialogue != null:
            break
        await process_frame
    check(scene.t2_dialogue != null, "loading past 120 frames still opens dialogue")
    check(scene.battle.player == scene.t2_lily and scene.t2_lily != null, "real Lily actor becomes controlled character")
    # Let the expensive scene/texture setup frame finish before using millisecond I/O fixtures.
    await process_frame
    await process_frame
    await process_frame
    # T2 clears battle.ally after switching battle.player to Lily. Recreate the pre-switch slot.
    var lily = scene.t2_lily
    scene.battle.ally = lily
    check(await scene._t2_wait_for_ally(0.1), "already loaded actor succeeds without waiting for a missed signal")
    # Only the pending I/O boundary is simulated below; exercise the production waiter/timer.
    scene.battle.ally = null
    scene.t2_ally_load_done = true
    check(not await scene._t2_wait_for_ally(0.1), "already failed loader returns failure")
    scene.t2_ally_load_done = false
    create_timer(0.02, true, false, true).timeout.connect(func():
        scene.t2_ally_load_done = true
        scene.t2_ally_load_resolved.emit(false))
    check(not await scene._t2_wait_for_ally(0.2), "asynchronous loader failure wakes waiter")
    scene.t2_ally_load_done = false
    create_timer(0.02, true, false, true).timeout.connect(func():
        scene.battle.ally = lily
        scene.t2_ally_load_done = true
        scene.t2_ally_load_resolved.emit(true))
    check(await scene._t2_wait_for_ally(0.2), "asynchronous completion wakes waiter")
    scene.battle.ally = null
    scene.t2_ally_load_done = false
    var previous_scale := Engine.time_scale
    var previous_pause := paused
    paused = true
    Engine.time_scale = 0.0
    check(not await scene._t2_wait_for_ally(0.03), "deadline still expires while paused with time_scale zero")
    Engine.time_scale = previous_scale
    paused = previous_pause
    check(not scene.t2_ally_load_done, "timeout does not falsely mark loader completed")
    # A late completion must not restart the scene or revive a discarded timeout Timer.
    scene.battle.ally = lily
    scene.t2_ally_load_done = true
    scene.t2_ally_load_resolved.emit(true)
    await process_frame
    await process_frame
    var timer_count := 0
    for child in scene.get_children():
        if child is Timer: timer_count += 1
    check(timer_count == 0, "success, failure and timeout release their Timers")
    check(scene.t2_flow.mode == Flow.DIALOGUE, "late signal does not duplicate progression")
    scene.queue_free()
    await process_frame
    await process_frame
    DirAccess.remove_absolute("user://sa2_t2_progress.json")
    if failures.is_empty():
        print("SA2_T2_ASSET_WAIT_PASS: delayed real loader, cache hit, failure, unscaled timeout, cleanup and late signal")
    quit(0 if failures.is_empty() else 1)
