extends "res://tools/sa2_t6_vfx_audit.gd"
func _run():
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
    var p = reset("rana")
    for frame in 30: await process_frame
    p.use_skill("flurry")
    var last := 0
    var wait_frames := -1
    for frame in 600:
        p._physics_process(1.0 / 60.0)
        if p.hit_i != last:
            last = p.hit_i
            if last in [1, 5, 10, 11]: wait_frames = 3
        elif wait_frames > 0:
            wait_frames -= 1
            if wait_frames == 0: await capture("flurry_" + str(last))
        await process_frame
        if p.state == "move": break
    print("FLURRY_CAPTURE_PASS: authored crossing sequence and finisher")
    quit()
