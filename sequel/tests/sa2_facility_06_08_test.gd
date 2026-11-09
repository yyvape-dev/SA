extends SceneTree

# Catches missing/misassigned art, wrong placement, double-built placeholder geometry,
# and loss of the existing fallback when a resource is unavailable.
var failures: Array[String] = []
const CASES := [
    ["n1_tavern", "w_bar", Vector2(7.4, 5.0), Vector3(-7.7, 2.5, -6.51), Vector2i(1280, 865)],
    ["n2_cabaret", "w_cabaret", Vector2(7.2, 5.0), Vector3(1.6, 2.5, -6.51), Vector2i(1280, 888)],
]

func _initialize() -> void:
    OS.set_environment("TOWN", "back")
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        printerr("FACILITY_FAIL: ", label)

func painted(node: Node) -> Array:
    var result := []
    for child in node.get_children():
        if child is MeshInstance3D and child.mesh is QuadMesh:
            var mat = child.material_override
            if mat is StandardMaterial3D and mat.albedo_texture:
                result.append(child)
    return result

func _run() -> void:
    var scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    for frame in 3600:
        if scene.ui != null:
            break
        await process_frame
    check(scene.ui != null, "main scene finished loading")
    if scene.ui == null:
        quit(1)
        return
    for c in CASES:
        var node: Node = scene.piece_nodes[c[0]]
        var quads := painted(node)
        var art_quads := []
        for q in quads:
            if q.material_override.albedo_texture.resource_path.ends_with("/" + c[1] + ".png"):
                art_quads.append(q)
        check(art_quads.size() == 1, c[0] + " uses its delivered image exactly once")
        if art_quads.size() == 1:
            var q = art_quads[0]
            check(q.mesh.size.is_equal_approx(c[2]), c[0] + " world size")
            check(q.position.is_equal_approx(c[3]), c[0] + " placement")
            check(q.material_override.albedo_texture.get_size() == Vector2(c[4]), c[0] + " keeps native resolution")
        check(node.get_child_count() == 4, c[0] + " replaces primitive facade/shack, keeps body and upper wall")
    check(painted(scene.piece_nodes["w3_vision"]).size() > 0, "existing vision artwork retained")
    check(scene.piece_nodes["n3_brothel"].get_child_count() > 4, "undelivered inn retains placeholder")
    check(not scene.bt_marks.any(func(m): return m[0] == "slot" and m[1] == "neon_liquor_tavern"), "painted tavern sign is not covered by a placeholder panel")
    check(not scene.bt_hang_rects.any(func(r): return str(r[0]).ends_with("@rail_cabaret")), "painted cabaret is not covered by placeholder cloth blocks")
    # Exercise the existing missing-resource path without deleting a delivered file.
    scene.bt_tex["w_bar"] = null
    scene.bt_tex["w_cabaret"] = null
    scene.build_backtown()
    check(scene.piece_nodes["n1_tavern"].get_child_count() > 4, "tavern fallback remains usable")
    check(scene.piece_nodes["n2_cabaret"].get_child_count() > 4, "cabaret fallback remains usable")
    check(scene.bt_marks.any(func(m): return m[0] == "slot" and m[1] == "neon_liquor_tavern"), "missing-art fallback retains tavern placeholder sign")
    check(scene.bt_hang_rects.any(func(r): return str(r[0]).ends_with("@rail_cabaret")), "missing-art fallback retains cabaret cloth blocks")
    scene.queue_free()
    await process_frame
    print("FACILITY_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
