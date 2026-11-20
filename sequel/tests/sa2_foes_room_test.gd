extends SceneTree
## 敵 第1弾（9体）の部屋（?mode=foes）。入口・9体が出る・各攻撃が最後まで流れる・整備兵の攻撃1で回復・リセット。
## FOES_CAPTURE=<フォルダ> で撮影：room.png（部屋の全体）と <敵>_<walk|atk1|atk2>.png（1体ずつ、同じ場所・同じ光）
func _initialize():
    call_deferred("_run")

func _shot(path: String) -> void:
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(path)

func _run():
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    game.set("foes_test_room", true)
    root.add_child(game)
    for frame in 1500:
        if game.get("rana_test_ready") == true: break
        await process_frame
    if game.get("rana_test_ready") != true:
        push_error("FOES_ROOM_FAIL: entry missing")
        quit(1)
        return
    var b = game.battle
    var kinds: Array = game.FOES9
    assert(b.enemies.size() == 9)
    for i in 9:
        assert(b.enemies[i].kind == kinds[i])
    var cap := OS.get_environment("FOES_CAPTURE")
    if cap != "":
        DirAccess.make_dir_recursive_absolute(cap)
        for frame in 90: await process_frame
        _shot(cap + "/room.png")
        var f := FileAccess.open(cap + "/room.json", FileAccess.WRITE)
        var pts := {}
        for e in b.enemies:
            var cam: Camera3D = game.get_viewport().get_camera_3d()
            var p0: Vector2 = cam.unproject_position(e.position)
            var p1: Vector2 = cam.unproject_position(e.position + Vector3(0, e.height(), 0))
            pts[e.kind] = [p0.x, p0.y, p1.y]
        f.store_string(JSON.stringify(pts))
        f.close()
    # 1体ずつ：カメラを x=1.6 に止め、敵を x=-1.0 に右向きで置く（攻撃が空いた右へ伸びる）。ラナと操作の絵は隠す
    var focus := Node3D.new()
    focus.position = Vector3(1.6, 0, 0)
    game.add_child(focus)
    if cap != "":
        b.cam_focus = focus
        game.player.hide()
        for layer in [game.ui, game.t2_layer]:
            layer.visible = false
    for k in kinds:
        for e in b.enemies.duplicate():
            b.remove_enemy(e)
        var e = b.spawn(k, Vector3(-1.0, 0, 0) if cap != "" else Vector3(2.6, 0, 0))
        e.face = 1 if cap != "" else -1
        await physics_frame
        e.set_physics_process(false)
        var poses := {"walk": int(e.clips.walk.frames.size() / 2)}
        for c in ["atk1", "atk2"]:
            if e.clips.has(c):
                poses[c] = int(e.clips[c].hit)
        for c in poses:
            e._show(c, poses[c])
            b.apply_light(e.sprite, e.mat, e.refl, e.position)
            if cap != "":
                for frame in (30 if c == "walk" else 3): await process_frame
                _shot("%s/%s_%s.png" % [cap, k, c])
                if c == "walk":
                    var cam: Camera3D = game.get_viewport().get_camera_3d()
                    var q0: Vector2 = cam.unproject_position(e.position)
                    var q1: Vector2 = cam.unproject_position(e.position + Vector3(0, 1.0, 0))
                    var g := FileAccess.open("%s/%s.json" % [cap, k], FileAccess.WRITE)
                    g.store_string(JSON.stringify([q0.x, q0.y, q0.y - q1.y]))
                    g.close()
        # 実際に攻撃を最後まで流す（両方の攻撃。止まらず walk に戻る）
        e.set_physics_process(true)
        for c in ["atk1", "atk2"]:
            if not e.clips.has(c):
                continue
            e.state = "walk"
            e.atk_cd = 0.0
            var guard := 0
            while e.state != "atk" or e.atk.clip != c:
                e.state = "walk"
                e._start_atk()
                guard += 1
                assert(guard < 50)
            for frame in 900:
                if e.state != "atk": break
                await physics_frame
            assert(e.state == "walk")
    b.cam_focus = null
    game.player.show()
    game.ui.visible = true
    game.t2_layer.visible = true
    # 整備兵の攻撃1＝回復：減った体力が戻り、ラナには当たらない
    for e in b.enemies.duplicate():
        b.remove_enemy(e)
    var medic = b.spawn("maintenance_soldier", Vector3(1.0, 0, 0))
    var hurt = b.spawn("steam_shield", Vector3(2.0, 0, 0))
    hurt.hp = hurt.hp_max * 0.3
    hurt.atk_cd = 99999.0
    hurt.sp = 0.0
    var taken: int = b.hits_taken
    medic.state = "walk"
    while medic.state != "atk" or medic.atk.clip != "atk1":
        medic.state = "walk"
        medic._start_atk()
    for frame in 900:
        if medic.state != "atk": break
        await physics_frame
    assert(hurt.hp > hurt.hp_max * 0.3 + 1.0)
    assert(b.hits_taken == taken)
    game._rana_reset_room()
    assert(b.enemies.size() == 9)
    print("FOES_ROOM_PASS: 9 kinds, walk/atk1/atk2 play through, medic heal, reset")
    quit()
