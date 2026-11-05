extends Node3D
## 融合都市の1区画（縦切り）。街を左右と奥行きで歩く。
## 起動の切り替え（環境変数）：
##   CAPTURE_GUIDE=1 … 外部AIに渡す下絵を art/guide/ に書き出して終了
##   CAPTURE_PLAY=1  … 動作確認の画面を captures/ に書き出して終了

const City := preload("res://scripts/city_block1.gd")
const Player := preload("res://scripts/player.gd")
const TouchUI := preload("res://scripts/touch_ui.gd")
const PAINT_SHADER := preload("res://scripts/proj_paint.gdshader")

const ROOM_X := Vector2(-19.0, 19.0)   # 歩ける左右
const BELT_Z := Vector2(-3.2, 3.5)     # 歩ける奥行き
const CAM_X := Vector2(-12.0, 12.0)    # カメラが動ける左右
const CAM_OFS := Vector3(0, 3.8, 13.5) # 主人公からのカメラの位置
const CAM_LOOK := Vector3(0, 2.1, 0)
const CAM_FOV := 36.0
const MAGENTA := Color(1, 0, 1)

var cam: Camera3D
var player: Node3D
var ui: CanvasLayer
var piece_nodes := {}   # id -> Node3D
var guide_meta := {}    # id -> {w,h,vp}

func _ready() -> void:
	_load_guide_meta()
	_build_env()
	_build_floor()
	for p in City.pieces():
		_build_piece(p)
	player = Player.new()
	player.room_x = ROOM_X
	player.belt_z = BELT_Z
	add_child(player)
	player.position = Vector3(-4, 0, 1.0)
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.near = 0.3
	cam.far = 300.0
	add_child(cam)
	_place_cam(true)
	ui = TouchUI.new()
	ui.player = player
	add_child(ui)
	if OS.has_environment("CAPTURE_GUIDE"):
		_capture_guides.call_deferred()
	elif OS.has_environment("CAPTURE_PLAY"):
		_capture_play.call_deferred()

func _process(delta: float) -> void:
	_place_cam(false, delta)

func _cam_pos_for(x: float) -> Vector3:
	return Vector3(clampf(x, CAM_X.x, CAM_X.y), 0, 0) + CAM_OFS

func _place_cam(snap: bool, delta: float = 0.0) -> void:
	var want := _cam_pos_for(player.position.x)
	cam.position = want if snap else cam.position.lerp(want, minf(1.0, delta * 5.0))
	cam.look_at(Vector3(cam.position.x, 0, 0) + CAM_LOOK, Vector3.UP)

# ---------- 見た目 ----------
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b1730")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a86a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _build_floor() -> void:
	# 地面はコードで作る（前作の教訓：AIの一枚絵は継ぎ目が苦手）。奥の歩道・車道（帯）・手前の歩道。
	_slab(Vector3(0, -0.05, -5.2), Vector3(60, 0.1, 3.0), Color("6b6460"))   # 奥の歩道
	_slab(Vector3(0, -0.08, 0.15), Vector3(60, 0.1, 7.6), Color("4a4650"))   # 帯（石畳の通り）
	_slab(Vector3(0, -0.05, 5.6), Vector3(60, 0.1, 3.2), Color("6b6460"))    # 手前の歩道
	for z in [-1.2, 1.6]:   # 路面電車の線路
		_slab(Vector3(0, -0.02, z), Vector3(60, 0.04, 0.12), Color("a59a85"))
	_slab(Vector3(0, -1.0, -30), Vector3(140, 0.1, 50), Color("221f2c"))     # 奥の街（暗がり）

func _slab(c: Vector3, s: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	mi.material_override = m
	mi.position = c
	add_child(mi)

func _build_piece(p: Dictionary) -> void:
	var root := Node3D.new()
	root.name = p.id
	add_child(root)
	piece_nodes[p.id] = root
	var painted: Texture2D = _load_painted(p.id)
	for b in p.boxes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.position = b[0]
		var col: Color = City.MAT[b[2]]
		mi.set_meta("col", col)
		if painted != null and guide_meta.has(p.id):
			var sm := ShaderMaterial.new()
			sm.shader = PAINT_SHADER
			sm.set_shader_parameter("paint", painted)
			sm.set_shader_parameter("ref_vp", _proj_from(guide_meta[p.id].vp))
			sm.set_shader_parameter("fallback", col)
			mi.material_override = sm
		else:
			mi.material_override = _grey_mat(col, b[2])
		root.add_child(mi)

func _grey_mat(col: Color, kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	if kind.begins_with("neon") or kind == "light":
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.6
	return m

func _load_painted(id: String) -> Texture2D:
	var path := "res://art/painted/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_guide_meta() -> void:
	var f := FileAccess.open("res://art/guide/guide.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			guide_meta = d

func _proj_from(a: Array) -> Projection:
	return Projection(Vector4(a[0], a[1], a[2], a[3]), Vector4(a[4], a[5], a[6], a[7]),
		Vector4(a[8], a[9], a[10], a[11]), Vector4(a[12], a[13], a[14], a[15]))

# ---------- 下絵の書き出し ----------
func _piece_corners(p: Dictionary) -> Array:
	var pts := []
	for b in p.boxes:
		var c: Vector3 = b[0]
		var h: Vector3 = b[1] * 0.5
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					pts.append(c + Vector3(h.x * sx, h.y * sy, h.z * sz))
	return pts

func _capture_guides() -> void:
	ui.visible = false
	player.visible = false
	var dir := ProjectSettings.globalize_path("res://art/guide")
	DirAccess.make_dir_recursive_absolute(dir)
	var meta := {}
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var rc := Camera3D.new()
	vp.add_child(rc)
	var renv := Environment.new()
	renv.background_mode = Environment.BG_COLOR
	renv.background_color = MAGENTA
	renv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	renv.ambient_light_color = Color(1, 1, 1)
	renv.ambient_light_energy = 0.12
	renv.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	rc.environment = renv
	var floor_nodes := []
	for ch in get_children():
		if ch is MeshInstance3D:
			floor_nodes.append(ch)
	for p in City.pieces():
		for k in piece_nodes:
			piece_nodes[k].visible = (k == p.id)
		for fnode in floor_nodes:
			fnode.visible = false
		# 撮る位置：ゲームのカメラと同じ高さ・向き。左右は部品の中心（遠景は中央）
		var cx := 0.0
		var pts := _piece_corners(p)
		for q in pts:
			cx += q.x
		cx /= pts.size()
		var cpos := _cam_pos_for(cx if p.kind != "far" else 0.0)
		rc.transform = Transform3D(Basis(), cpos)
		rc.look_at(Vector3(cpos.x, 0, 0) + CAM_LOOK, Vector3.UP)
		var inv := rc.global_transform.affine_inverse()
		var tx0 := INF; var tx1 := -INF; var ty0 := INF; var ty1 := -INF
		for q in pts:
			var v: Vector3 = inv * q
			var d := -v.z
			tx0 = minf(tx0, v.x / d); tx1 = maxf(tx1, v.x / d)
			ty0 = minf(ty0, v.y / d); ty1 = maxf(ty1, v.y / d)
		var wr := tx1 - tx0
		var hr := ty1 - ty0
		var size := Vector2i(1536, 1024)
		if wr / hr < 0.83:
			size = Vector2i(1024, 1536)
		elif wr / hr < 1.2:
			size = Vector2i(1024, 1024)
		var asp := float(size.x) / size.y
		var m := 1.08
		var hh := maxf(hr, wr / asp) * m
		var n := 0.5
		vp.size = size
		rc.keep_aspect = Camera3D.KEEP_HEIGHT
		rc.set_frustum(hh * n, Vector2((tx0 + tx1) * 0.5 * n, (ty0 + ty1) * 0.5 * n), n, 400.0)
		rc.current = true
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(dir + "/%s.png" % p.id)
		var pr: Projection = rc.get_camera_projection() * Projection(rc.global_transform.affine_inverse())
		var arr := []
		for c in [pr.x, pr.y, pr.z, pr.w]:
			arr.append_array([c.x, c.y, c.z, c.w])
		meta[p.id] = {"w": size.x, "h": size.y, "vp": arr, "kind": p.kind}
		print("GUIDE ", p.id, " ", size)
	# 全体の絵（画風を決める1枚）：ゲームのカメラ、中央、全部を表示
	for k in piece_nodes:
		piece_nodes[k].visible = true
	for fnode in floor_nodes:
		fnode.visible = true
	vp.size = Vector2i(1536, 1024)
	var cpos0 := _cam_pos_for(0.0)
	rc.transform = Transform3D(Basis(), cpos0)
	rc.look_at(Vector3(0, 0, 0) + CAM_LOOK, Vector3.UP)
	rc.projection = Camera3D.PROJECTION_PERSPECTIVE
	rc.keep_aspect = Camera3D.KEEP_WIDTH
	rc.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAM_FOV) * 0.5) * (16.0 / 9.0)))
	renv.background_color = Color("1b1730")
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(dir + "/key_full.png")
	var f := FileAccess.open(dir + "/guide.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, " "))
	f.close()
	print("GUIDE DONE")
	get_tree().quit()

# ---------- 動作確認の撮影 ----------
func _capture_play() -> void:
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [[-4.0, 1.0, "idle"], [-12.0, -2.5, "walk"], [4.5, 3.4, "behind_fg"], [12.0, 0.0, "atk"]]
	for s in shots:
		player.position = Vector3(s[0], 0, s[1])
		player.debug_state(s[2])
		_place_cam(true)
		for i in 8:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/play_%s.png" % s[2])
		print("PLAY ", s[2])
	get_tree().quit()
