extends Node3D
## 融合都市の1区画（縦切り）。街を左右と奥行きで歩く。
## 起動の切り替え（環境変数）：
##   CAPTURE_GUIDE=1 … 外部AIに渡す下絵を art/guide/ に書き出して終了
##   CAPTURE_PLAY=1  … 動作確認の画面を captures/ に書き出して終了

const City := preload("res://scripts/city_block1.gd")
const Player := preload("res://scripts/player.gd")
const TouchUI := preload("res://scripts/touch_ui.gd")
const Battle := preload("res://scripts/battle.gd")
const Fx := preload("res://scripts/fx.gd")
const PAINT_SHADER := preload("res://scripts/proj_paint.gdshader")
const SPRITE_SHADER := preload("res://scripts/sprite_bb.gdshader")

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
var battle: Node3D
var fx: Node3D
var piece_nodes := {}   # id -> Node3D
var guide_meta := {}    # id -> {w,h,vp}

func _ready() -> void:
	_load_guide_meta()
	_build_env()
	_build_floor()
	for p in City.pieces():
		_build_piece(p)
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.near = 0.3
	cam.far = 300.0
	add_child(cam)
	battle = Battle.new()
	battle.BELT_Z = BELT_Z
	battle.ROOM_X = ROOM_X
	battle.cam = cam
	add_child(battle)
	fx = Fx.new()
	fx.cam = cam
	add_child(fx)
	battle.fx = fx
	player = Player.new()
	player.world = battle
	player.room_x = ROOM_X
	player.belt_z = BELT_Z
	battle.player = player
	add_child(player)
	player.position = Vector3(-4, 0, 1.0)
	_place_cam(true)
	ui = TouchUI.new()
	ui.player = player
	ui.battle = battle
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
	# 画面の揺れ（px 相当 → 画面の高さ 720px ≒ 8.8m）
	var sk: float = battle.shake * 0.012 if battle else 0.0
	cam.h_offset = randf_range(-1.0, 1.0) * sk
	cam.v_offset = randf_range(-1.0, 1.0) * sk * 0.7

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
	# 地面はコード（前作の教訓：AIの一枚絵は継ぎ目が苦手）。外部AIの継ぎ目の無い素材を繰り返して敷く。
	# 奥の歩道・帯（車道の石畳）・手前の歩道。キャラとエフェクトが沈まないよう暗めにする（FLOOR_DIM）。
	_ground(Vector3(0, 0.0, -5.2), Vector2(60, 3.0), SLAB_TEX, SLAB_TILE)     # 奥の歩道
	_ground(Vector3(0, -0.03, 0.15), Vector2(60, 7.6), COBBLE_TEX, COBBLE_TILE) # 帯（石畳の通り）
	_ground(Vector3(0, 0.0, 5.6), Vector2(60, 3.2), SLAB_TEX, SLAB_TILE)      # 手前の歩道
	for z in [-1.2, 1.6]:   # 路面電車の線路（真鍮の細い線）
		var r := _slab(Vector3(0, -0.02, z), Vector3(60, 0.04, 0.06), Color("b8933f"))
		var rm: StandardMaterial3D = r.material_override
		rm.metallic = 0.6
		rm.roughness = 0.35
	_slab(Vector3(0, -1.0, -30), Vector3(140, 0.1, 50), Color("221f2c"))     # 奥の街（暗がり）
	_build_glints()

const COBBLE_TEX := preload("res://assets/ground/cobble.png")
const SLAB_TEX := preload("res://assets/ground/slab.png")
const COBBLE_TILE := 2.5   # 石畳 1 枚の大きさ（m）
const SLAB_TILE := 2.0     # 敷石 1 枚（石 1 枚が約 1m×0.5m）
const FLOOR_DIM := 0.5    # 地面の明るさ（素材の色に掛ける）
const GLINT_SHADER := preload("res://scripts/glint.gdshader")

func _ground(c: Vector3, size: Vector2, tex: Texture2D, tile: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(FLOOR_DIM, FLOOR_DIM, FLOOR_DIM)
	m.uv1_scale = Vector3(size.x / tile, size.y / tile, 1)
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.position = c
	add_child(mi)

## 濡れた路面の映り込み：assets/ground/glints.json（tools/make_glints.py が塗った絵から作る）の光ごとに、
## 建物の根元から手前へ、その色の筋を地面に寝かせて足す。高い所の光ほど筋が長く、強い光ほど明るい。
func _build_glints() -> void:
	var f := FileAccess.open("res://assets/ground/glints.json", FileAccess.READ)
	if f == null:
		return
	var list = JSON.parse_string(f.get_as_text())
	if not (list is Array):
		return
	for g in list:
		var length := clampf(7.0 + float(g.y) * 0.8, 7.0, 12.0)
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(g.w) * 0.9, length)
		mi.mesh = pm
		mi.position = Vector3(float(g.x), 0.012, float(g.z) + length * 0.5)
		var m := ShaderMaterial.new()
		m.shader = GLINT_SHADER
		m.set_shader_parameter("col", Color(g.col[0], g.col[1], g.col[2]))
		m.set_shader_parameter("power", 0.35 + 0.65 * float(g.p))
		m.set_shader_parameter("stone", COBBLE_TEX)
		m.set_shader_parameter("tile", COBBLE_TILE)
		m.set_shader_parameter("z0", float(g.z))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _slab(c: Vector3, s: Vector3, col: Color) -> MeshInstance3D:
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
	return mi

func _build_piece(p: Dictionary) -> void:
	var root := Node3D.new()
	root.name = p.id
	add_child(root)
	piece_nodes[p.id] = root
	var painted: Texture2D = _load_painted(p.id)
	if p.kind == "far" and painted != null:
		_build_far_plane(root, painted)
		return
	if p.kind == "fg" and painted != null:
		_build_fg_plane(root, p, painted)
		return
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

## 遠景：一枚絵を奥に立てた板（箱は使わない）。縦横比はそのまま。iPhone の横長（約2.17:1）でカメラが左右の端まで動いても
## 画面の上半分が切れない幅（z=-62 で約131m）。見えるのは絵の高さの約22％なので、ユーザー決定で「中の帯（塔の胴と窓）」が
## 見える高さに置く（絵の 470〜699 行目が、奥の街の地平 y≈-1.5 〜 画面の上端 y≈18 に来る）。
const FAR_Z := -62.0
const FAR_W := 136.0
const FAR_ROW_BOTTOM := 699.0   # 地平に合わせる絵の行（1024 行中）

func _build_far_plane(root: Node3D, tex: Texture2D) -> void:
	var w := FAR_W
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var px := h / float(tex.get_height())
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.position = Vector3(0, -1.6 + (FAR_ROW_BOTTOM - tex.get_height() * 0.5) * px, FAR_Z)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 手前の部品：背景を抜いた絵（key_soft）を、画面に正対する板として立てる（箱への投影は側面が伸びるのでやめた）。
## 足元＝地面、背の高さ＝箱のいちばん上。左右・奥行きは箱の中心。当たりには関係しない。
func _build_fg_plane(root: Node3D, p: Dictionary, tex: Texture2D) -> void:
	var top := 0.0
	var cx := 0.0
	var cz := 0.0
	for b in p.boxes:
		top = maxf(top, b[0].y + b[1].y * 0.5)
		cx += b[0].x
		cz += b[0].z
	cx /= p.boxes.size()
	cz /= p.boxes.size()
	var h := top
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.position = Vector3(cx, h * 0.5, cz)
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER
	m.set_shader_parameter("tex", tex)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		if p.boxes.is_empty():
			continue
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
## 決まった入力で戦闘を流し、3コマに1枚 captures/ へ書き出す（--fixed-fps 60 で起動すると毎回同じ）。
func _capture_play() -> void:
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	battle.auto_spawn = false
	player.position = Vector3(-2.0, 0, 0.6)
	_place_cam(true)
	var foes := [
		battle.spawn("1", Vector3(0.6, 0, 0.6)), battle.spawn("3", Vector3(1.6, 0, 1.2)),
		battle.spawn("1", Vector3(1.2, 0, -0.1)), battle.spawn("3", Vector3(-3.6, 0, 0.5)),
	]
	for e in foes:
		e.atk_cd = 9.0     # 最初はラナの攻撃を見るため、敵は攻撃しない
	# 前半：ラナの連携（A→B→A…）。後半：新しい2体がラナを攻撃する（床の予兆→被弾）。最後に回避
	var script := {6: "atk", 26: "atk", 50: "atk", 70: "atk", 92: "atk", 112: "atk", 170: "foes", 300: "dodge"}
	for f in 360:
		if script.has(f):
			match script[f]:
				"atk": player.attack()
				"dodge": player.dodge()
				"foes":
					for e in battle.enemies.duplicate():
						battle.remove_enemy(e)
					var pz: float = player.position.z
					var a = battle.spawn("1", player.position + Vector3(1.05, 0, 0.05))
					var b = battle.spawn("3", player.position + Vector3(-1.1, 0, -0.1))
					b.atk_cd = 0.9
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if f % 3 == 0:
			get_viewport().get_texture().get_image().save_png(dir + "/play_%03d.png" % f)
	print("PLAY DONE")
	get_tree().quit()
