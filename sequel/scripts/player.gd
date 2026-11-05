extends Node3D
## ラナ（仮の絵＝前作の連番）。帯の中を左右・奥行きに動く。攻撃2種・回避。
## 絵は rana.json（クリップごとのコマ：ページ, x, y, w, h, 足元からの左上のずれ）。

const WALK := 2.8
const RUN := 6.2
const DEPTH_K := 0.75        # 奥行きの移動は少し遅く（アラド型）
const HEIGHT_M := 1.85       # 画面での背の高さ（待機の絵の366px＝この高さ）
const FPS := {"idle": 1.0, "walk": 26.0, "run": 22.0, "atc": 44.0, "atb": 52.0}
const DODGE_T := 0.24
const DODGE_D := 4.0

var room_x := Vector2(-19, 19)
var belt_z := Vector2(-3.2, 3.5)
var move_in := Vector2.ZERO   # タッチ・キーの入力（−1〜1）
var run_in := false
var sprite: Sprite3D
var shadow: MeshInstance3D
var clips := {}
var pages := {}
var clip := "idle"
var t := 0.0
var face := 1
var state := "move"   # move / atk / dodge
var atk_next := "atc"
var dodge_t := 0.0
var queued := false
var px_size := 0.005

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rana/rana.json"))
	clips = d
	px_size = HEIGHT_M / 366.0
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.shaded = false
	sprite.region_enabled = true
	sprite.centered = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	shadow = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.3, 0.5)
	qm.orientation = PlaneMesh.FACE_Y
	shadow.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.55)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	sm.albedo_texture = gt
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = sm
	shadow.position.y = 0.02
	add_child(shadow)
	_show_frame("idle", 0)

func _tex(name: String) -> Texture2D:
	if not pages.has(name):
		pages[name] = load("res://assets/rana/" + name)
	return pages[name]

func _show_frame(c: String, i: int) -> void:
	var fr: Array = clips[c].frames
	var f: Array = fr[clampi(i, 0, fr.size() - 1)]
	var k: float = clips[c].k / 0.6
	sprite.texture = _tex(f[0])
	sprite.region_rect = Rect2(f[1], f[2], f[3], f[4])
	sprite.pixel_size = px_size * k
	# 足元（原点）から見た左上の位置。Sprite3D は y が上向き
	var ox: float = f[5]
	var oy: float = f[6]
	if face < 0:
		ox = -ox - f[3]
	sprite.flip_h = face < 0
	sprite.offset = Vector2(ox, -oy - f[4])

func _frames(c: String) -> int:
	return clips[c].frames.size()

func attack() -> void:
	if state == "atk":
		queued = true
		return
	if state == "dodge":
		return
	state = "atk"
	clip = atk_next
	atk_next = "atb" if atk_next == "atc" else "atc"
	t = 0.0

func dodge() -> void:
	if state == "dodge":
		return
	state = "dodge"
	dodge_t = 0.0
	queued = false

func _physics_process(delta: float) -> void:
	var mv := move_in
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): mv.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): mv.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): mv.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): mv.y += 1
	if mv.length() > 1.0: mv = mv.normalized()
	var running := run_in or Input.is_key_pressed(KEY_SHIFT) or mv.length() > 0.9
	t += delta
	match state:
		"move":
			if absf(mv.x) > 0.1:
				face = 1 if mv.x > 0 else -1
			var sp := RUN if running else WALK
			position.x += mv.x * sp * delta
			position.z += mv.y * sp * DEPTH_K * delta
			var c := "idle"
			if mv.length() > 0.12:
				c = "run" if running else "walk"
			if c != clip:
				clip = c
				t = 0.0
			var n := _frames(clip)
			_show_frame(clip, int(t * FPS[clip]) % n)
		"atk":
			var n := _frames(clip)
			var i := int(t * FPS[clip])
			# 斬りの最中は少し前へ出る（移動距離で手応えを足す）
			if i > n * 0.25 and i < n * 0.45:
				position.x += face * 3.0 * delta
			if i >= n:
				state = "move"
				clip = "idle"
				t = 0.0
				if queued:
					queued = false
					attack()
				_show_frame(clip, 0)
			else:
				_show_frame(clip, i)
		"dodge":
			dodge_t += delta
			var dir := mv.normalized() if mv.length() > 0.2 else Vector2(face, 0)
			position.x += dir.x * DODGE_D / DODGE_T * delta
			position.z += dir.y * DODGE_D / DODGE_T * DEPTH_K * delta
			sprite.modulate = Color(0.6, 0.9, 1.0, 0.75)
			_show_frame("run", int(dodge_t * 40.0) % _frames("run"))
			if dodge_t >= DODGE_T:
				state = "move"
				sprite.modulate = Color(1, 1, 1, 1)
	position.x = clampf(position.x, room_x.x, room_x.y)
	position.z = clampf(position.z, belt_z.x, belt_z.y)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_J or e.keycode == KEY_Z:
			attack()
		elif e.keycode == KEY_K or e.keycode == KEY_X:
			dodge()

## 撮影用：状態を固定する
func debug_state(s: String) -> void:
	set_physics_process(false)
	match s:
		"walk":
			face = -1
			_show_frame("walk", 6)
		"atk":
			face = 1
			_show_frame("atc", 14)
		_:
			face = 1
			_show_frame("idle", 0)
