extends "res://tools/sa2_t6_vfx_audit.gd"
# Same seeded 5-enemy fixture before/after. 50/100/200ms samples and optional 60Hz clips.
var events: Array = []
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
    game.t2_flow.begin_dialogue("C1-06", Vector3.ZERO)
    game.t2_flow.finish_dialogue()
    for id in ["lily_normal", "lily_barrage", "lily_ult", "rana_combo", "overlap"]:
        await run_case(id)
    var file := FileAccess.open(folder.path_join("measurements.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(events, "  "))
    print("VFX_QUALITY_CAPTURE_PASS: seeded 5-enemy normal/barrage/ult/combo/overlap")
    quit(0)
func run_case(id: String) -> void:
    seed(20261111)
    var lily_case := id.begins_with("lily")
    var a = reset("lily" if lily_case else "rana")
    for e in game.battle.enemies.duplicate(): game.battle.remove_enemy(e)
    seed(20261111)
    for at in [Vector3(1.4, 0, 0), Vector3(1.7, 0, 0.35), Vector3(2.2, 0, -0.3), Vector3(3.6, 0, 0), Vector3(6.0, 0, 0)]:
        game.battle.spawn("1", at)
        var e = game.battle.enemies.back()
        e.set_physics_process(false)
        e.hp = 100000.0
        e.hp_max = 100000.0
    for frame in 150: await process_frame
    var enemies: Array = game.battle.enemies.duplicate()
    var hp: Array = enemies.map(func(e): return e.hp)
    game._place_cam(true)
    if id == "lily_normal": a.force_attack("atk_jabkick", enemies[0], 1.5)
    elif id == "lily_barrage": a.force_skill("barrage", enemies[0])
    elif id == "lily_ult": a._start_ult(enemies[0])
    elif id == "rana_combo": a._start_attack("atkA")
    else:
        a.skill_cd.flurry = 0.0
        a.use_skill("flurry")
        game.t2_lily.show()
        game.t2_lily.position = Vector3(-0.4, 0, 0.4)
        game.t2_lily.state = "move"
        game.t2_lily.force_skill("barrage", enemies[0])
        game.battle.manual_ally = game.t2_lily
    var selected := -1
    var combo := 0
    var record := {"case": id, "hits": [], "camera_start": str(game.cam.global_transform)}
    for frame in 340:
        a._physics_process(1.0 / 60.0)
        if id == "overlap": game.t2_lily._physics_process(1.0 / 60.0)
        var changed := false
        for i in enemies.size():
            if hp[i] != enemies[i].hp:
                record.hits.append({"frame": frame, "target": i})
                hp[i] = enemies[i].hp
                changed = true
        if selected < 0 and changed and (id != "lily_ult" or a.ev_i == a.sk.ev.size()): selected = frame
        if selected >= 0:
            var age := frame - selected
            if age in [3, 6, 12]: await capture(id + "_%03dms" % (age * 1000 / 60))
            if id in ["lily_barrage", "lily_ult"] and age < 25: await capture(id + "_clip_%03d" % age)
        if id == "rana_combo" and a.state == "move" and combo < 2:
            combo += 1
            a._start_attack("atkB" if combo == 1 else "atkC")
        if frame > 20 and a.state == "move" and (selected < 0 or frame - selected > 25) and (id != "overlap" or game.t2_lily.state == "move"): break
        await process_frame
    record["selected_hit_frame"] = selected
    record["target_ids"] = hp
    events.append(record)
    print("QUALITY ", id, " hits=",record.hits.size()," selected=",selected)
