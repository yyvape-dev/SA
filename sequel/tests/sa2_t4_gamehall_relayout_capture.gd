extends SceneTree
## T4 isolated layout spike. No production script or T2/T3 content is changed.
## Renders actual user-supplied painted casino source, mechanically alpha-keyed.
## No generated replacement or mock art; no T2/T3 production changes.
const BT = preload("res://scripts/backtown_block.gd")
const HALL_X0 := 7.0
const INSERT_W := 7.0
const HALL_CX := 10.5
const HALL_H := 4.17
const ENTRANCE_W := 5.04
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		printerr("T4_GODOT_PREVIEW_FAIL: ", detail)

func _layout_check() -> void:
	var coords := {}
	for s in BT.segments():
		if s.get("kind", "") == "wall":
			coords[s.id] = Vector2(s.x0, s.x1)
	_check(coords.has("n2_cabaret") and coords["n2_cabaret"].is_equal_approx(Vector2(-2.0, 5.2)), "Unexpected cabaret footprint")
	_check(coords.has("n3_brothel") and coords["n3_brothel"].is_equal_approx(Vector2(7.0, 14.2)), "Unexpected brothel footprint")
	_check(coords.has("n4_shady") and coords["n4_shady"].is_equal_approx(Vector2(18.8, 25.0)), "Unexpected shady footprint")
	var old_hall_left := 4.3 - 3.5
	var old_hall_right := 4.3 + 3.5
	var cabaret_overlap := maxf(0.0, minf(old_hall_right, 5.2) - maxf(old_hall_left, -2.0))
	var brothel_overlap := maxf(0.0, minf(old_hall_right, 14.2) - maxf(old_hall_left, 7.0))
	_check(absf(cabaret_overlap - 4.4) < 0.001 and absf(brothel_overlap - 0.8) < 0.001, "Old-slot intersection math")
	_check(absf(HALL_CX - INSERT_W * 0.5 - HALL_X0) < 0.001, "Casino does not start at old inn edge")
	_check(absf(HALL_CX + INSERT_W * 0.5 - 14.0) < 0.001, "Casino exceeds inn footprint")
	print("T4_COORDS original arcade expansion overlaps: cabaret %.2fm, brothel %.2fm" % [cabaret_overlap, brothel_overlap])
	print("T4_COORDS replacement casino x=7.00..14.00m; former inn 7.00..14.20 removed; alley_gate 16.00..18.20, shady 18.80..25.00 UNCHANGED")
	print("T4_COORDS walk belt -2..2, original street bounds and floor UNCHANGED")

func _material(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _block(parent: Node3D, at: Vector3, size: Vector3, hex: String, label: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = at
	n.material_override = _material(hex)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.name = label
	parent.add_child(n)
	return n

func _remove_former_inn(game: Node3D, level: Node3D) -> int:
	var hidden := 0
	var nodes: Dictionary = game.get("piece_nodes")
	var inn: Node3D = nodes.get("n3_brothel")
	_check(inn != null, "Former inn segment missing")
	if inn != null:
		inn.visible = false
		hidden += 1
	# The inn NPCs, balcony roof ornaments and sign/crowd extras are
	# independent children of the old segment, so remove only the original
	# inn frontage area. Do not relocate the rest of the street.
	var queue: Array[Node] = [level]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		if node == inn:
			continue
		for child in node.get_children():
			queue.push_back(child)
		if node is GeometryInstance3D:
			var gi: GeometryInstance3D = node
			var p := gi.global_position
			# Exclude floor, road, distant stage, and the foreground at z=+3.5.
			if p.x >= 7.0 and p.x <= 14.2 and p.z <= -4.0 and p.z >= -7.5:
				gi.visible = false
				hidden += 1
	return hidden

func _add_gamehall(game: Node3D, parent: Node3D, art_name: String, expected_px: Vector2i, tag: String) -> Node3D:
	# Preview-only artwork: the canonical guide is alpha-keyed separately,
	# and the accepted painted source is cropped losslessly, never regenerated.
	var art_path := "res://art/painted_bt/%s.png" % art_name
	var tex: Texture2D = load(art_path) if ResourceLoader.exists(art_path) else null
	_check(tex != null, "T4 texture absent: " + art_path)
	if tex == null:
		return null
	_check(tex.get_size() == Vector2(expected_px.x, expected_px.y), "T4 artwork pixel dimensions differ from QA: " + art_name)
	var hall := Node3D.new()
	hall.name = "T4_GAMEHALL_" + tag
	parent.add_child(hall)
	var quad: MeshInstance3D = game.call("_bt_quad", hall, art_name,
		HALL_X0, 0.0, HALL_X0 + INSERT_W, HALL_H, -6.18, 0.84) as MeshInstance3D
	_check(quad != null, "Failed to place T4 in Godot: " + art_name)
	if quad != null:
		quad.name = "casino_" + tag
		var mesh: QuadMesh = quad.mesh as QuadMesh
		_check(mesh != null, "T4 facade is not QuadMesh: " + art_name)
		if mesh != null:
			_check(absf(mesh.size.x - INSERT_W) < 0.001 and absf(mesh.size.y - HALL_H) < 0.001, "T4 physical geometry violates 7.00 x 4.17 m")
			_check(absf(quad.position.y - HALL_H * 0.5) < 0.001, "Casino bottom is not y=0")
			_check(absf(quad.position.x - HALL_CX) < 0.001, "Casino world x is not 7..14m")
	print("T4_PHYSICAL_FACADE_CHECK %s art=%s px=%s width=%.3fm height=%.3fm x=[%.2f,%.2f] floor_y=0" % [tag, art_name, str(tex.get_size()), INSERT_W, HALL_H, HALL_X0, HALL_X0 + INSERT_W])
	return hall

func _save(game: Node3D, path: String) -> void:
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	var img: Image = game.get_viewport().get_texture().get_image()
	_check(img != null, "Viewport texture absent: " + path)
	if img == null:
		return
	var rc := img.save_png(path)
	_check(rc == OK and FileAccess.file_exists(path), "Cannot save Godot screenshot " + path)
	if rc == OK:
		print("T4_SCREENSHOT %s %dx%d" % [path, img.get_width(), img.get_height()])

func _run() -> void:
	_layout_check()
	if not failures.is_empty():
		quit(1)
		return
	var scene: PackedScene = load("res://main.tscn")
	_check(scene != null, "main.tscn unavailable")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	var player: Node3D
	var camera: Camera3D
	var level: Node3D
	var ui: CanvasLayer
	var loading: CanvasLayer
	for i in 600:
		await process_frame
		player = game.get("player")
		camera = game.get("cam")
		level = game.get("level")
		ui = game.get("ui")
		loading = game.get("loading")
		if player != null and camera != null and level != null and ui != null:
			break
	_check(player != null and camera != null and level != null and ui != null, "Game boot did not produce backtown scene")
	if player == null or camera == null or level == null or ui == null:
		quit(1)
		return
	_check(absf(camera.fov - 16.8) < 0.05, "Camera FOV not D2")
	_check(absf(camera.position.z - 15.3) < 0.01, "Camera distance not D2")
	_check(BT.BELT_Z.is_equal_approx(Vector2(-2.0, 2.0)), "Walk belt changed")
	if not failures.is_empty():
		quit(1)
		return
	ui.visible = false
	var hud: CanvasLayer = game.get("hud")
	if hud != null:
		hud.visible = false
	if loading != null:
		loading.visible = false
	player.position = Vector3(HALL_CX, 0, 0)
	player.set_physics_process(false)
	game.call("_place_cam", true)
	var output := ProjectSettings.globalize_path("res://captures/t4-gamehall")
	DirAccess.make_dir_recursive_absolute(output)
	await _save(game, output + "/before_d2_x10p5.png")
	var source_nodes: Dictionary = game.get("piece_nodes")
	var stall_container: Node3D = source_nodes.get("stalls")
	var old_game_stall: Node3D = stall_container.get_node_or_null("stall_game") if stall_container != null else null
	_check(old_game_stall != null, "Cannot locate existing stall_game proxy for removal")
	if old_game_stall != null:
		old_game_stall.visible = false
	var removed := _remove_former_inn(game, level)
	_check(removed > 1, "Former inn not removed")
	# Actual Godot proof showed the x=12 foreground column masked casino center-right.
	var old_fg: Array = game.get("bt_fg")
	var fg_removed := 0
	for fd in old_fg:
		if absf((fd.node as Node3D).position.x - 12.0) < 0.05:
			fd.node.visible = false
			fg_removed += 1
	_check(fg_removed == 1, "Expected exactly one foreground column at x12")
	print("T4_FOREGROUND_CASINO_REMOVED columns=%d x=12.0" % fg_removed)
	# Phase 1/2/3: Real in-engine guide at exact physical scale BEFORE generating any new art.
	var guide: Node3D = _add_gamehall(game, level, "gamehall_preview_guide", Vector2i(1536, 1024), "SCALE_GUIDE")
	if guide == null or not failures.is_empty():
		quit(1)
		return
	player.position = Vector3(HALL_CX, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/guide_d2_x10p5.png")
	player.position = Vector3(5.2, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/guide_d2_x5p2.png")
	player.position = Vector3(16.0, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/guide_d2_x16p0.png")
	guide.visible = false
	# Control render: preserve approved painted pixels, crop ONLY outside alpha bbox.
	var painted: Node3D = _add_gamehall(game, level, "gamehall_user_trimmed", Vector2i(1443, 862), "ORIGINAL_PAINT_CROPPED")
	if painted == null or not failures.is_empty():
		quit(1)
		return
	player.position = Vector3(HALL_CX, 0, 0)
	game.call("_place_cam", true)
	var roof_px: Vector2 = camera.unproject_position(Vector3(HALL_CX, HALL_H, -6.18))
	var vp_h: float = game.get_viewport().get_visible_rect().size.y
	print("T4_TRIMMED_ROOF_TOP projected_y=%.2fpx ratio=%.4f viewport_height=%.0f (negative means cropped)" % [roof_px.y, roof_px.y / vp_h, vp_h])
	await _save(game, output + "/painted_d2_x10p5.png")
	player.position = Vector3(5.2, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/painted_d2_x5p2.png")
	player.position = Vector3(16.0, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/painted_d2_x16p0.png")
	print("T4_INN_HIDDEN_GEOMETRIES %d" % removed)
	if failures.is_empty():
		print("T4_GODOT_PREVIEW_PASS captures=7 (actual D2 Godot, physical facade 7.00x4.17, visual acceptance pending)")
		quit(0)
	else:
		quit(1)
