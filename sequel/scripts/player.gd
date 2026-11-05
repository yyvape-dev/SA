extends Node3D
## ラナ（仮の絵＝前作の連番）。帯の中を左右・奥行きに動く。攻撃2種（交互に連携）・回避・被弾・ダウン。
## 絵は rana.json（クリップごとのコマ：ページ, x, y, w, h, 足元からの左上のずれ）。
## 攻撃のコマの時間と当たりの瞬間は、前作 battle/play.js の ATC・ATB と同じ（攻撃速度 1.75 倍）。

const SPR := preload("res://scripts/sprite_bb.gdshader")
const WALK := 2.8
const RUN := 6.2
const DEPTH_K := 0.75        # 奥行きの移動は少し遅く（アラド型）
const HEIGHT_M := 1.85       # 画面での背の高さ（待機の絵の366px＝この高さ）
const FPS := {"idle": 1.0, "walk": 26.0, "run": 22.0}
const ASPD := 1.75
const DODGE_T := 0.24
const DODGE_D := 4.0
const HURT_CUT := [0.0, 0.08, 0.18, 0.28]
const HURT_T := 0.36
const DOWN_T := 1.6

# 斬撃のエフェクト（fx.gd の slash）。縦＝画面に立つ弧、横＝床と平行の弧
const SL_DOWN := {"plane": "v", "r": 1.75, "w": 0.55, "a0": 115.0, "a1": -55.0, "y": 0.95, "life": 0.24, "draw": 0.06}
const SL_BACK := {"plane": "h", "r": 2.1, "w": 0.6, "a0": -40.0, "a1": 120.0, "y": 0.9, "life": 0.26, "draw": 0.07, "squash": 0.55, "tilt": -8.0}
const SL_SWEEP := {"plane": "h", "r": 2.5, "w": 0.7, "a0": 110.0, "a1": -50.0, "y": 1.0, "life": 0.26, "draw": 0.07, "squash": 0.55, "tilt": 6.0}
const SL_OVER := {"plane": "v", "r": 2.2, "w": 0.75, "a0": 80.0, "a1": -70.0, "y": 1.1, "life": 0.3, "draw": 0.07}

var world               # battle.gd
var room_x := Vector2(-19, 19)
var belt_z := Vector2(-3.2, 3.5)
var move_in := Vector2.ZERO   # タッチ・キーの入力（−1〜1）
var run_in := false
var sprite: Sprite3D
var mat: ShaderMaterial
var shadow: MeshInstance3D
var clips := {}
var pages := {}
var clip := "idle"
var t := 0.0
var face := 1
var state := "move"   # move / atk / dodge / hurt / down
var atk_next := "atc"
var dodge_t := 0.0
var queued := false
var px_size := 0.005
var inv := 0.0
var flash := 0.0
var kb := 0.0
var down_dir := 1
var tab := {}         # clip -> {starts, total, hits:[[t, spec]], cancel}
var hit_i := 0

func _ready() -> void:
	clips = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rana/rana.json"))
	px_size = HEIGHT_M / 366.0
	_build_tables()
	sprite = Sprite3D.new()
	sprite.region_enabled = true
	sprite.centered = false
	mat = ShaderMaterial.new()
	mat.shader = SPR
	sprite.material_override = mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	shadow = world.make_shadow(1.3)
	add_child(shadow)
	_show_frame("idle", 0)

## 前作の時間表：攻撃A（縦斬り）は元動画のコマ 9〜60、攻撃B（横薙ぎ）は 12〜37 と 50〜72。
func _build_tables() -> void:
	var atc_src := [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 22, 26, 30, 34, 36, 37, 38, 39, 40, 41, 42, 44, 48, 52, 53, 54, 55, 56, 57, 58, 59, 60]
	var atb_src := []
	for s in range(12, 38): atb_src.append(s)
	for s in range(50, 73): atb_src.append(s)
	var mk := func(src: Array, ms: Callable) -> Dictionary:
		var st := []
		var acc := 0.0
		for s in src:
			st.append(acc / ASPD)
			acc += ms.call(s) / 1000.0
		return {"starts": st, "total": acc / ASPD}
	var atc_ms := func(s: int) -> float:
		if s <= 11: return 30.0
		if s <= 16: return 25.0
		if s == 17: return 20.0
		if s == 18: return 40.0
		if s == 22 or s == 26 or s == 34: return 0.0
		if s <= 36: return 30.0
		if s <= 41: return 25.0
		if s <= 52: return 40.0
		return 35.0
	var atb_ms := func(s: int) -> float:
		if s <= 18: return 25.0
		if s <= 26: return 22.0
		if s == 27: return 30.0
		if s == 28: return 35.0
		if s == 29: return 25.0
		if s == 30: return 30.0
		if s <= 37: return 30.0
		if s <= 53: return 35.0
		if s <= 55: return 30.0
		if s == 56: return 35.0
		return 34.0
	var a: Dictionary = mk.call(atc_src, atc_ms)
	var b: Dictionary = mk.call(atb_src, atb_ms)
	# 当たり：距離は前作の px（ラナ 205px＝1.85m）を m に直した。奥行きの幅は続編で決めた値
	a.hits = [
		[a.starts[atc_src.find(18)], {"side": 1, "r": 2.85, "lane": 0.95, "dmg": 20.0, "strong": false, "slash": SL_DOWN}],
		[a.starts[atc_src.find(42)], {"side": -1, "r": 2.5, "lane": 0.95, "dmg": 13.0, "strong": false, "slash": SL_BACK}],
	]
	a.cancel = a.hits[1][0] + 0.12 / ASPD
	b.hits = [
		[b.starts[atb_src.find(28)], {"side": 1, "r": 3.2, "lane": 1.1, "dmg": 22.0, "strong": false, "slash": SL_SWEEP}],
		[b.starts[atb_src.find(30)], {"side": -1, "r": 2.7, "lane": 1.1, "dmg": 14.0, "strong": false, "slash": SL_BACK}],
		[b.starts[atb_src.find(55)], {"side": -1, "r": 2.9, "lane": 1.1, "dmg": 18.0, "strong": true, "slash": SL_OVER}],
	]
	b.cancel = b.hits[2][0] + 0.14 / ASPD
	tab = {"atc": a, "atb": b}

func _tex(name: String) -> Texture2D:
	if not pages.has(name):
		pages[name] = load("res://assets/rana/" + name)
	return pages[name]

func _show_frame(c: String, i: int) -> void:
	var fr: Array = clips[c].frames
	var f: Array = fr[clampi(i, 0, fr.size() - 1)]
	var k: float = clips[c].k / 0.6
	var tex := _tex(f[0])
	if sprite.texture != tex:
		sprite.texture = tex
		mat.set_shader_parameter("tex", tex)
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
	if state == "atk" or state == "dodge":
		queued = true
		return
	if state != "move":
		return
	_start_attack()

func _start_attack() -> void:
	# 入力の向きへ振り向いてから斬る
	if absf(move_in.x) > 0.3:
		face = 1 if move_in.x > 0 else -1
	state = "atk"
	clip = atk_next
	atk_next = "atb" if atk_next == "atc" else "atc"
	t = 0.0
	hit_i = 0
	queued = false

func dodge() -> void:
	if state == "dodge" or state == "down" or state == "hurt":
		return
	state = "dodge"
	dodge_t = 0.0
	queued = false

func can_be_hit() -> bool:
	return inv <= 0.0 and state != "dodge" and state != "down"

func on_hurt(dir: int, dead: bool) -> void:
	flash = 0.25
	inv = 0.45
	queued = false
	if dead:
		state = "down"
		t = 0.0
		down_dir = dir
		face = -dir
		return
	state = "hurt"
	t = 0.0
	kb = dir * 2.0
	face = -dir

func _physics_process(delta: float) -> void:
	var mv := move_in
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): mv.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): mv.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): mv.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): mv.y += 1
	if mv.length() > 1.0: mv = mv.normalized()
	flash = maxf(0.0, flash - delta)
	var blink := inv > 0.0 and state != "down" and int(Time.get_ticks_msec() / 42) % 2 == 0
	mat.set_shader_parameter("flash", Color(1.0, 0.25, 0.2, 0.7 if flash > 0.0 else 0.0))
	var dt: float = world.dt(delta)
	if dt <= 0.0:
		return
	inv = maxf(0.0, inv - dt)
	var running := run_in or Input.is_key_pressed(KEY_SHIFT) or mv.length() > 0.9
	t += dt
	var tint := Color(1, 1, 1, 0.55 if blink else 1.0)
	mat.set_shader_parameter("rot", 0.0)
	match state:
		"move":
			if absf(mv.x) > 0.1:
				face = 1 if mv.x > 0 else -1
			var sp := RUN if running else WALK
			position.x += mv.x * sp * dt
			position.z += mv.y * sp * DEPTH_K * dt
			var c := "idle"
			if mv.length() > 0.12:
				c = "run" if running else "walk"
			if c != clip:
				clip = c
				t = 0.0
			var n := _frames(clip)
			_show_frame(clip, int(t * FPS[clip]) % n)
		"atk":
			var tb: Dictionary = tab[clip]
			var st: Array = tb.starts
			var i := 0
			while i + 1 < st.size() and st[i + 1] <= t:
				i += 1
			# 当たりの瞬間ごとに判定（1振りで1回）
			while hit_i < tb.hits.size() and t >= tb.hits[hit_i][0]:
				world.player_attack(tb.hits[hit_i][1])
				hit_i += 1
			# 最初の当たりの直前に、少し前へ出る（移動距離で手応えを足す）
			var h0: float = tb.hits[0][0]
			if t > h0 - 0.08 and t < h0 + 0.02:
				position.x += face * 3.0 * dt
			if queued and t >= tb.cancel:
				_start_attack()
				_show_frame(clip, 0)
			elif t >= tb.total:
				state = "move"
				clip = "idle"
				t = 0.0
				_show_frame(clip, 0)
			else:
				_show_frame(clip, i)
		"dodge":
			dodge_t += dt
			var dir := mv.normalized() if mv.length() > 0.2 else Vector2(face, 0)
			position.x += dir.x * DODGE_D / DODGE_T * dt
			position.z += dir.y * DODGE_D / DODGE_T * DEPTH_K * dt
			tint = Color(0.6, 0.9, 1.0, 0.75)
			_show_frame("run", int(dodge_t * 40.0) % _frames("run"))
			if dodge_t >= DODGE_T:
				state = "move"
				if queued:
					_start_attack()
		"hurt":
			position.x += kb * dt
			kb *= pow(0.002, dt)
			var hi := 0
			while hi + 1 < HURT_CUT.size() and HURT_CUT[hi + 1] <= t:
				hi += 1
			_show_frame("dmg", hi)
			if t >= HURT_T:
				state = "move"
				clip = "idle"
				t = 0.0
		"down":
			# 倒れて、少し置いて起き上がる（体力は全快）
			var dk := minf(1.0, t / 0.5)
			_show_frame("dmg", 1)
			mat.set_shader_parameter("rot", down_dir * 1.4 * (1.0 - pow(1.0 - dk, 3.0)) * (1.0 if t < DOWN_T else maxf(0.0, 1.0 - (t - DOWN_T) / 0.25)))
			if t < 0.3:
				position.x += down_dir * 2.0 * dt * (1.0 - t / 0.3)
			if t >= DOWN_T + 0.25:
				state = "move"
				clip = "idle"
				t = 0.0
				inv = 1.5
				world.player_revived()
	mat.set_shader_parameter("tint", tint)
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
