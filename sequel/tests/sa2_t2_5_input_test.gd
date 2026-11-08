extends SceneTree
## Real scene and input dispatch; no direct combat-adapter action calls or enemy attack-clock edits.
const Scene = preload("res://sa2_t2_playable.tscn")
const Flow = preload("res://scripts/sa2_flow_state.gd")
const Manual = preload("res://scripts/sa2_t2_lily_manual.gd")
var scene
var stopped: Array[float] = []

func _initialize() -> void:
    call_deferred("_run")

func require(ok: bool, label: String) -> bool:
    if not ok:
        printerr("SA2_T2_5_INPUT_FAIL: ", label)
        quit(1)
    else:
        print("T2_5_CHECK: ", label)
    return ok

func frames(n: int) -> void:
    for i in n:
        await physics_frame
        await process_frame

func key(code: Key, pressed: bool) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = pressed
    Input.parse_input_event(event)

func tap(code: Key) -> void:
    key(code, true)
    await frames(1)
    key(code, false)
    await frames(1)

func click(button: Button) -> void:
    var event := InputEventMouseButton.new()
    event.position = button.get_global_rect().get_center()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = true
    root.push_input(event, true)
    await frames(1)
    event = event.duplicate()
    event.pressed = false
    root.push_input(event, true)
    await frames(2)

func touch(at: Vector2, pressed: bool, index: int = 0) -> void:
    var event := InputEventScreenTouch.new()
    event.position = at
    event.index = index
    event.pressed = pressed
    root.push_input(event, true)

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var args := OS.get_cmdline_user_args()
    var restarting := args.has("--resume") or args.has("--resume-instance") or args.has("--resume-result")
    if not restarting:
        DirAccess.remove_absolute("user://sa2_t2_progress.json")
    scene = Scene.instantiate()
    root.add_child(scene)
    for i in 2400:
        if scene.t2_dialogue != null:
            break
        await process_frame
    await frames(3)
    if not require(scene.t2_dialogue != null, "scene ready"): return
    for i in 180:
        if not scene.loading.visible: break
        await frames(1)
    if args.has("--resume-instance"):
        if not require(scene.t2_flow.mode == Flow.INSTANCE and scene.t2_active and scene.t2_flow.attempts.get("C1-06", 0) == 1, "fresh engine resumes instance without duplicate attempt"): return
        print("SA2_T2_5_INSTANCE_RESTART_PASS: encounter restarts; per-enemy HP and position are not persisted")
        quit(0)
        return
    if args.has("--resume-result"):
        if not require(scene.t2_flow.mode == Flow.RESULT and scene.t2_flow.result == "lose", "fresh engine restores defeat result"): return
        await click(scene.t2_result_button)
        if not require(scene.t2_active and scene.t2_flow.attempts.get("C1-06", 0) == 2, "fresh engine result permits GUI retry"): return
        print("SA2_T2_5_RESULT_RESTART_PASS")
        quit(0)
        return
    if restarting:
        if not require(scene.t2_flow.mode == Flow.EXPLORE and scene.t2_flow.completed.get("C1-06", false), "fresh engine restores completed exploration"): return
        if not require(scene.player == scene.t2_rana and scene.battle.ally == scene.t2_lily, "fresh engine restores actors"): return
        print("SA2_T2_5_RESTART_PASS")
        quit(0)
        return
    if not require(scene.t2_flow.mode == Flow.DIALOGUE, "initial conversation"): return
    await frames(60)
    for i in 8:
        if not scene.t2_dialogue.active: break
        await tap(KEY_SPACE)
        await frames(5)
    if not require(scene.t2_active and scene.player == scene.t2_lily, "conversation to Lily training via keyboard"): return
    if args.has("--pause-instance"):
        print("SA2_T2_5_INSTANCE_SAVED")
        quit(0)
        return
    var before: Vector3 = scene.t2_lily.position
    touch(Vector2(200, 500), true)
    await frames(1)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = Vector2(245, 500)
    root.push_input(drag, true)
    await frames(1)
    await frames(12)
    touch(Vector2(245, 500), false)
    await frames(2)
    if not require(scene.t2_lily.position.x > before.x and scene.t2_manual.move_in == Vector2.ZERO, "Linux injected touch move and release"): return
    # The fixture starts at 4 HP so one REAL enemy AI hit proves damage and defeat quickly.
    scene.battle.hp = 4.0
    var hits_before: int = scene.battle.hits_taken
    for i in 1200:
        if scene.t2_flow.mode == Flow.RESULT: break
        await frames(1)
    if not require(scene.t2_flow.result == "lose" and scene.battle.hits_taken > hits_before and scene.battle.hp == 0.0, "real AI hit reduces HP to defeat"): return
    if args.has("--pause-result"):
        print("SA2_T2_5_RESULT_SAVED")
        quit(0)
        return
    await frames(60)
    await click(scene.t2_result_button)
    if not require(scene.t2_active and scene.t2_flow.attempts.get("C1-06", 0) == 2 and scene.battle.hp == 100.0, "GUI retry resets HP and attempts"): return
    scene.battle.foe_killed.connect(func(foe): stopped.append(float(foe.hp)))
    # Observe an unmodified enemy AI wind-up, then dispatch the player's K input.
    var guarded := false
    for i in 1200:
        for foe in scene.battle.enemies:
            if Manual.guard_candidate(foe, scene.t2_lily.position) and scene.t2_lily.state == "move":
                await tap(KEY_K)
                guarded = scene.t2_manual.guard_count == 1
                break
        if guarded: break
        await frames(1)
    if not require(guarded, "keyboard just guard against natural AI wind-up"): return
    await frames(2)
    for i in 120:
        var candidate := false
        for foe in scene.battle.enemies:
            candidate = candidate or Manual.guard_candidate(foe, scene.t2_lily.position)
        if not candidate and scene.t2_lily.state == "move": break
        await frames(1)
    await tap(KEY_K)
    if not require(scene.t2_manual.dodge_count == 1, "same keyboard button also dodges"): return
    await frames(30)
    var attack_button: Button = scene.t2_combat_controls.get_child(0)
    var attack_count: int = scene.t2_manual.attack_count
    await click(attack_button)
    if not require(scene.t2_manual.attack_count == attack_count + 1, "GUI attack fires once"): return
    # Remaining attacks are actual J inputs; movement keys keep the target in reach.
    for i in 120:
        if scene.t2_done: break
        var foe = scene.t2_lily._nearest()
        if foe == null: break
        var delta: Vector3 = foe.position - scene.t2_lily.position
        key(KEY_A, delta.x < -1.2)
        key(KEY_D, delta.x > 1.2)
        key(KEY_W, delta.z < -0.3)
        key(KEY_S, delta.z > 0.3)
        await tap(KEY_J)
        await frames(20)
    for code in [KEY_A, KEY_D, KEY_W, KEY_S]: key(code, false)
    if not require(scene.t2_flow.result == "win" and stopped.size() == 2 and stopped[0] <= 0.0 and stopped[1] <= 0.0, "two targets defeated by real hit and HP logic"): return
    await frames(60)
    await click(scene.t2_result_button)
    if not require(scene.t2_flow.mode == Flow.EXPLORE and scene.player == scene.t2_rana and scene.battle.ally == scene.t2_lily, "victory GUI restores exploration actors"): return
    if not require(not is_instance_valid(scene.t2_combat_controls), "training controls freed"): return
    # Prove ordinary Rana attacks and Lily AI attacks still work after restoration.
    scene.t2_lily.set_physics_process(false)
    var target = scene.battle.spawn("1", scene.t2_rana.position + Vector3(1.0, 0, 0))
    target.hp_max = 1000.0
    target.hp = 1000.0
    var hp_before: float = target.hp
    await tap(KEY_J)
    await frames(75)
    if not require(target.hp < hp_before, "restored Rana keyboard attack damages enemy"): return
    for i in 180:
        if scene.t2_rana.state == "move": break
        await frames(1)
    if not require(scene.t2_rana.state == "move", "Rana attack finishes before independent AI check"): return
    hp_before = target.hp
    scene.t2_lily.set_physics_process(true)
    for i in 600:
        if target.hp < hp_before: break
        await frames(1)
    if not require(target.hp < hp_before, "restored Lily AI damages enemy"): return
    for foe in scene.battle.enemies.duplicate(): scene.battle.remove_enemy(foe)
    await frames(60)
    print("SA2_T2_5_INPUT_PASS: real scene, keyboard, Linux touch, AI defeat, GUI retry, natural guard, real victory, Rana and Lily AI restore")
    quit(0)
