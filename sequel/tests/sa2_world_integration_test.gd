extends SceneTree

var failures: Array[String] = []
func _initialize() -> void:
    OS.set_environment("TOWN", "back")
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        printerr("WORLD_FAIL: ", label)
func frames(n: int) -> void:
    for i in n: await process_frame
func _run() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    for i in 3600:
        if scene.ui != null: break
        await process_frame
    check(scene.ui != null, "scene ready")
    if scene.ui == null:
        quit(1)
        return
    check(is_instance_valid(scene.gate), "backtown has a real dungeon gate")
    var metal_before: Color = scene._bt_mat("iron").albedo_color
    var floor_count: int = scene.ground_mats.size()
    scene.build_backtown()
    check(scene.ground_mats.size() == floor_count, "rebuild releases old floor material references")
    check(scene._bt_mat("iron").albedo_color == metal_before, "rebuilding never darkens shared metal materials")
    for id in ["w3_vision", "n1_tavern", "n2_cabaret", "n3_brothel", "n4_shady"]:
        var body = scene.piece_nodes[id].get_child(0)
        check(body.material_override is StandardMaterial3D and body.material_override.albedo_texture != null,
            id + " 3D body has a wall texture")
    for id in ["sbar_a", "sbar_b", "sbar_c", "sbar_d"]:
        var bar = scene.level.get_node("stalls/extras22/" + id)
        var has_art := false
        for child in bar.get_children():
            if child is MeshInstance3D and child.mesh is QuadMesh:
                var mat = child.material_override
                if mat is StandardMaterial3D and mat.albedo_texture != null:
                    has_art = true
        check(has_art, id + " uses completed artwork")
    check(scene.level.get_node_or_null("stalls/stall_game") == null, "deprecated game stall removed")
    check(not scene.level.get_node("marks").visible, "production hides colored guide markers")
    var painted_tubes := 0
    for child in scene.level.get_node("stalls/extras22").get_children():
        if child is MeshInstance3D and child.mesh is QuadMesh and child.material_override.albedo_texture.resource_path.ends_with("/pend_green.png"):
            painted_tubes += 1
    check(painted_tubes == 3, "glass tube placeholders use painted green lamps")
    check(scene.has_method("change_town_floor"), "production floor routing exists")
    if scene.has_method("change_town_floor"):
        var old_level = scene.level
        await scene.change_town_floor(true)
        await frames(3)
        check(scene.town_floor == "gamehall" and not is_instance_valid(old_level), "west floor swaps/frees Level")
        check(scene.player.room_x == Vector2(-24,24), "hall keeps its independent 48m walking range")
        var sidewalk_ok := false
        for child in scene.level.get_children():
            if child is MeshInstance3D and child.mesh is PlaneMesh and is_equal_approx(child.position.z, -5.2):
                sidewalk_ok = child.visible
        check(sidewalk_ok, "hall mask preserves textured sidewalk")
        check(scene.gate == null, "hall has return exit, not dungeon gate")
        check(scene.level.get_node_or_null("GAMEHALL_16M_ART_LAYERS/GamehallAnimation") != null, "approved hall animation installed")
        check(not scene.player.locked and not scene.town_floor_busy, "controls restored after hall load")
        # No edge transition while modal UI has locked the character.
        scene.hud.open_slots()
        scene.player.position.x = 24
        scene._check_town_edge()
        await frames(3)
        check(scene.town_floor == "gamehall", "modal menu blocks floor switch")
        scene.hud.close_slots()
        scene._check_town_edge()
        for i in 3600:
            if scene.town_floor == "backtown" and not scene.town_floor_busy: break
            await process_frame
        check(scene.town_floor == "backtown" and scene.player.position.x < -20, "east exit returns to backtown west side")
        check(scene.player.room_x == Vector2(-24,28), "backtown right entrance forecourt is walkable")
        check(is_instance_valid(scene.gate), "return rebuilds dungeon gate")
        scene.player.position = Vector3(scene.gate.position.x - 0.5, 0, 0)
        scene._check_gate()
        check(scene.hud.menu_open, "walking straight right opens dungeon difficulty")
        check(scene.hud.choose(0), "normal dungeon choice accepted")
        for i in 3600:
            if scene.dungeon != null and not scene.player.locked: break
            await process_frame
        check(scene.dungeon != null and scene.hud.in_dungeon, "existing dungeon actually starts")
        check(scene.bt_fg.is_empty(), "dungeon releases old backtown foreground references")
        scene.leave_dungeon()
        await frames(3)
        check(scene.dungeon == null and scene.town_floor == "backtown" and is_instance_valid(scene.gate), "dungeon exit restores original backtown")
        check(not scene.player.locked and scene.battle.ROOM_X == Vector2(-24,28), "return restores input/bounds")
        check(is_instance_valid(scene.battle.ally), "ally remains live across map/dungeon changes")
    scene.queue_free()
    await frames(2)
    print("WORLD_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
