extends SceneTree
## T4 isolated layout spike. No production script or T2/T3 content is changed.
## This captures real Godot viewport PNGs. The new arcade is flat-color
## 3D geometry, NOT the approved painted casino artwork and NOT a final guide.
const BT = preload("res://scripts/backtown_block.gd")
const CUT_X := 5.2
const INSERT_W := 7.0
const HALL_CX := 8.7
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
	_check(absf(HALL_CX - INSERT_W * 0.5 - 5.2) < 0.001, "Casino does not start at cabaret edge")
	_check(absf(HALL_CX + INSERT_W * 0.5 - (7.0 + INSERT_W - 1.8)) < 0.001, "Casino/filler inserted span")
	print("T4_COORDS original arcade expansion overlaps: cabaret %.2fm, brothel %.2fm" % [cabaret_overlap, brothel_overlap])
	print("T4_COORDS proposed casino x=5.20..12.20m; brothel shifts 7.00..14.20 -> 14.00..21.20; alley_gate 16.00..18.20 -> 23.00..25.20; shady 18.80..25.00 -> 25.80..32.00")
	print("T4_COORDS prototype-only right-hand area extends beyond x30 floor and original x24 walk boundary; full street route NOT TESTED")

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

func _shift_render_nodes(node: Node) -> int:
	var moved := 0
	if node is GeometryInstance3D:
		var g: GeometryInstance3D = node
		# Do not translate floor, distant backdrop or the whole level.
		if g.global_position.x >= CUT_X and g.global_position.x < 35.0:
			g.global_position += Vector3(INSERT_W, 0, 0)
			return 1
	for ch in node.get_children():
		moved += _shift_render_nodes(ch)
	return moved

func _add_gamehall(game: Node3D, parent: Node3D) -> void:
	var hall := Node3D.new()
	hall.name = "T4_GAMEHALL_PROXY_NOT_FINAL_ART"
	parent.add_child(hall)
	var left := HALL_CX - ENTRANCE_W * 0.5
	var right := HALL_CX + ENTRANCE_W * 0.5
	# 3D interior is separate from a facade. No walking-street floor painted into art.
	_block(hall, Vector3(HALL_CX, 1.48, -9.3), Vector3(5.5, 2.96, 0.08), "3a163a", "casino_back_wall")
	_block(hall, Vector3(HALL_CX, 0.025, -7.9), Vector3(5.5, 0.05, 2.8), "3f224e", "interior_floor")
	_block(hall, Vector3(left - 0.48, 1.42, -6.48), Vector3(0.96, 2.84, 0.32), "432044", "left_jamb")
	_block(hall, Vector3(right + 0.48, 1.42, -6.48), Vector3(0.96, 2.84, 0.32), "432044", "right_jamb")
	_block(hall, Vector3(HALL_CX, 3.49, -6.51), Vector3(INSERT_W, 1.34, 0.28), "492151", "facade_header")
	_block(hall, Vector3(HALL_CX, 2.86, -6.29), Vector3(INSERT_W, 0.12, 0.18), "d8a34d", "brass_lintel")
	_block(hall, Vector3(HALL_CX, 3.86, -6.25), Vector3(INSERT_W - 0.4, 0.11, 0.2), "ce9750", "upper_trim")
	for px in [HALL_CX - 3.05, HALL_CX + 3.05]:
		_block(hall, Vector3(px, 1.43, -6.23), Vector3(0.18, 2.85, 0.27), "d1a34b", "gold_jamb")
	for px in [6.75, 10.68]:
		for depth in [-7.25, -8.32]:
			_block(hall, Vector3(px, 0.88, depth), Vector3(0.66, 1.65, 0.30), "7b3b73", "slot_machine")
			_block(hall, Vector3(px, 1.14, depth + 0.18), Vector3(0.46, 0.56, 0.07), "be57d8", "machine_display")
	for px in [8.0, 9.40]:
		_block(hall, Vector3(px, 0.52, -7.60), Vector3(1.08, 0.12, 0.8), "bf8536", "game_table")
		_block(hall, Vector3(px, 0.23, -7.6), Vector3(0.15, 0.45, 0.15), "8c552d", "table_foot")
	for px, depth, idx in [[7.4, -8.8, 2], [8.2, -8.6, 3], [9.5, -8.9, 5], [10.25, -7.95, 7]]:
		game.call("_bt_npc", hall, px, depth, idx)
	_block(hall, Vector3(HALL_CX, 2.73, -8.0), Vector3(2.15, 0.12, 0.6), "f1b452", "ceiling_light")
	print("T4_PROXY geometry hall=7.00m, height=4.17m, entrance=5.04m; interior depth=2.8m; 4 in-engine NPC sprites; not painted output")

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
	if loading != null:
		loading.visible = false
	player.position = Vector3(HALL_CX, 0, 0)
	player.set_physics_process(false)
	game.call("_place_cam", true)
	var output := ProjectSettings.globalize_path("res://captures/t4-gamehall")
	DirAccess.make_dir_recursive_absolute(output)
	await _save(game, output + "/before_d2_x8p7.png")
	var shifted := _shift_render_nodes(level)
	_check(shifted > 30, "Right-side street objects were not translated")
	_add_gamehall(game, level)
	# Preview-only camera bound for the extended 7m section.
	game.set("cam_x", Vector2(-19.08, 26.08))
	player.position = Vector3(HALL_CX, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/after_d2_x8p7.png")
	player.position = Vector3(15.0, 0, 0)
	game.call("_place_cam", true)
	await _save(game, output + "/after_d2_x15p0.png")
	print("T4_SHIFT_COUNT %d" % shifted)
	if failures.is_empty():
		print("T4_GODOT_PREVIEW_PASS captures=3 (actual Godot viewport, proxy materials only)")
		quit(0)
	else:
		quit(1)
