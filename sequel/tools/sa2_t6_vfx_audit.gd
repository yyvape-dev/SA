extends SceneTree
# Actual-engine capture/measurement harness. SA2_VFX_CAPTURE=<absolute folder>; no audio/assets generated.
var game
var records: Array = []
var folder := ""
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    folder = OS.get_environment("SA2_VFX_CAPTURE")
    root.size = Vector2i(1280, 720)
    game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null: break
        await process_frame
    game.t2_manual.set_physics_process(false)
    game.t2_rana.set_physics_process(false)
    game.t2_lily.set_physics_process(false)
    game.t2_rana.locked = false
    game.t5_meeting_marker.hide()
    game.street_marker.hide()
    game.t2_label.hide()
    # Keep ordinary talk/meeting availability out of this combat inspection.
    game.t2_flow.begin_dialogue("C1-06", Vector3.ZERO)
    game.t2_flow.finish_dialogue()
    var sample := OS.has_environment("SA2_VFX_SAMPLE")
    var guard_only := OS.has_environment("SA2_VFX_GUARD_ONLY")
    for id in ([] if guard_only else ["atkA"] if sample else ["atkA", "atkB", "atkC", "hold", "flurry", "rift", "vortex", "ult"]):
        await inspect_move("rana", id)
    for id in ([] if guard_only else ["atk_jabkick"] if sample else ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush", "rush", "barrage", "storm", "ult"]):
        await inspect_move("lily", id)
    if not sample:
        await inspect_guard(false)
        await inspect_guard(true)
    if not folder.is_empty():
        var file := FileAccess.open(folder.path_join("measurements.json"), FileAccess.WRITE)
        file.store_string(JSON.stringify(records, "  "))
    print("T6_VFX_AUDIT_PASS: ", records.size(), " moves/guard variants captured and measured")
    quit(0)
func reset(actor_id: String) -> Node3D:
    for e in game.battle.enemies.duplicate(): game.battle.remove_enemy(e)
    var actor = game.t2_rana if actor_id == "rana" else game.t2_lily
    game.player = actor
    game.battle.player = actor
    game.battle.ally = null
    game.battle.manual_ally = game.t2_lily if actor_id == "lily" else null
    game.t2_rana.visible = actor_id == "rana"
    game.t2_lily.visible = actor_id == "lily"
    actor.position = Vector3.ZERO
    actor.face = 1
    actor.state = "move"
    actor.t = 0.0
    actor.inv = 0.0
    game.battle.freeze = 0.0
    game.battle.cine = false
    game.battle.cam_zoom = 0.0
    game.battle.cam_focus = null
    game.battle.ult = 200.0
    game.battle.ally_ult = 200.0
    game._place_cam(true)
    for at in [Vector3(1.4, 0, 0), Vector3(3.6, 0, 0), Vector3(6.4, 0, 0)]:
        game.battle.spawn("1", at)
        var e = game.battle.enemies.back()
        e.set_physics_process(false)
        e.hp = 100000.0
        e.hp_max = 100000.0
    return actor
func inspect_move(actor_id: String, id: String) -> void:
    var a = reset(actor_id)
    for frame in 36: await process_frame
    var label := actor_id + "_" + id
    var enemies: Array = game.battle.enemies.duplicate()
    var hp: Array = enemies.map(func(e): return e.hp)
    if actor_id == "rana":
        if id == "ult": a.use_ult()
        elif a.skills.has(id):
            a.skill_cd[id] = 0.0
            a.use_skill(id)
        else: a._start_attack(id)
    else:
        if id == "ult": a._start_ult(enemies[0])
        elif a.sk_tab.has(id): a.force_skill(id, enemies[2] if id == "rush" else enemies[0])
        else: a.force_attack(id, enemies[0], 1.5)
    var events := []
    var screenshot_first := false
    var impact_frame := -1
    var last_event_frame := 0
    var peak_freeze := 0.0
    var peak_shake := 0.0
    for frame in 280:
        a._physics_process(1.0 / 60.0)
        var changed := false
        for i in enemies.size():
            if enemies[i].hp != hp[i]:
                events.append({"frame": frame, "target": i, "actor_x": a.position.x, "target_x": enemies[i].position.x, "damage": hp[i] - enemies[i].hp})
                hp[i] = enemies[i].hp
                changed = true
        peak_freeze = maxf(peak_freeze, game.battle.freeze)
        peak_shake = maxf(peak_shake, game.battle.shake)
        if frame == 3: await capture(label + "_anticipation")
        if changed:
            last_event_frame = frame
            if not screenshot_first:
                impact_frame = frame + 3
                screenshot_first = true
        if frame == impact_frame:
            await capture(label + "_impact")
        if frame > 8 and a.state == "move": break
        await process_frame
    for frame in 12: await process_frame
    await capture(label + "_decay")
    records.append({"actor": actor_id, "move": id, "events": events, "last_hit_frame": last_event_frame, "peak_hitstop": peak_freeze, "peak_shake": peak_shake, "hit_observed": not events.is_empty()})
    print("AUDIT ", label, " hit_events=", events.size(), " last=",last_event_frame," freeze=",peak_freeze," shake=",peak_shake)
func inspect_guard(fallback: bool) -> void:
    var a = reset("rana")
    # Let preceding offensive VFX/cutin/number tails finish before isolated defense capture.
    for frame in 120: await process_frame
    for e in game.battle.enemies.slice(1): game.battle.remove_enemy(e)
    var e = game.battle.enemies[0]
    e.face = -1
    e._start_atk()
    e.atk.t = float(e.atk.hit_t) - 0.24
    var label := "guard_" + ("fallback3d" if fallback else "gold2d")
    if fallback: game.fx2d.enabled = false
    await capture(label + "_warning")
    a.dodge()
    for frame in 31:
        a._physics_process(1.0 / 60.0)
        e._physics_process(1.0 / 60.0)
        # Consecutive actual 60Hz rendered frames for guard contact/decay video.
        await capture(label + "_%03d" % frame)
        await process_frame
    if fallback: game.fx2d.enabled = true
    records.append({"actor": "rana", "move": label, "enemy_state": e.state, "player_state": a.state, "hp": game.battle.hp})
func capture(label: String) -> void:
    if folder.is_empty(): return
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(folder.path_join(label + ".png"))
