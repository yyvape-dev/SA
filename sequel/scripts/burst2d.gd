extends CanvasLayer
## 粒子の混ぜ撒き（2026-11-07、specs/vfx_recipes.md）。画面の上（3D の上・UI の下）に 2D の粒子を出す。
## 光の粒（シートの 1〜2 段目、加算、速さの向きへ伸ばす）と花びら（3〜4 段目、普通の重ね、回転＋横幅の伸縮）を同時に撒く。
## 色は粒ごとに 金・紅・桃・シアン から（color_initial_ramp を 4 色の階段にしてランダムに引く）、芯は白。
## 出は速く、強い減速（damping）で止まり、薄れて消える。
## GPUParticles2D を使う。BURST_CPU=1（環境変数）か URL の ?cpu=1 で CPUParticles2D（Web で GPU が動かない時の逃げ道）。
## 使い方：main.burst.emit_at(世界の位置, 強さ 0.5〜1.5)

const SHEET := preload("res://assets/fx/burst_sheet.png")
const SH := preload("res://scripts/burst2d.gdshader")
const COLORS := [Color8(255, 170, 40), Color8(225, 30, 55), Color8(255, 90, 180), Color8(40, 180, 255)]   # 金・紅・桃・シアン
const POOL := 3              # 同時に出せる撒き（古いものから使い回す）

var cam: Camera3D
var use_cpu := false
var hdr := 1.0               # glow の確認用（1 を超えると明るさが 1 を超える）
var fixed_seed := -1         # 撮影で同じ撒き方にする（0 以上で種を固定）
var sets := []               # [{"spark": node, "petal": node}]
var next := 0

func _ready() -> void:
	layer = 1
	use_cpu = OS.get_environment("BURST_CPU") == "1"
	if OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search")).contains("cpu=1"):
		use_cpu = true
	for i in POOL:
		sets.append({"spark": _make(false), "petal": _make(true)})

func _ramp_colors() -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT   # 4 色の階段＝混ぜない
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75])
	g.colors = PackedColorArray(COLORS)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _ramp_life(petal: bool) -> GradientTexture1D:
	var g := Gradient.new()   # 出てすぐは濃く、後半で薄れる
	g.offsets = PackedFloat32Array([0.0, 0.55 if petal else 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _make(petal: bool) -> Node2D:
	var pm := ParticleProcessMaterial.new()
	pm.particle_flag_disable_z = true
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 700.0 if not petal else 380.0
	pm.initial_velocity_max = 1500.0 if not petal else 900.0
	pm.damping_min = 1800.0 if not petal else 900.0     # 強い減速：速く出て、すぐ止まる
	pm.damping_max = 2800.0 if not petal else 1400.0
	pm.gravity = Vector3(0, 0 if not petal else 140.0, 0)   # 花びらだけゆっくり落ちる
	pm.scale_min = 0.6 if not petal else 0.7
	pm.scale_max = 1.3 if not petal else 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.55 if petal else 0.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color_initial_ramp = _ramp_colors()
	pm.color_ramp = _ramp_life(petal)
	pm.anim_speed_min = 0.0
	pm.anim_speed_max = 0.0
	pm.anim_offset_min = 0.0 if not petal else 0.5    # 光の粒＝マス 0〜7、花びら＝マス 8〜15
	pm.anim_offset_max = 0.499 if not petal else 0.999
	if petal:
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -420.0
		pm.angular_velocity_max = 420.0
	else:
		pm.particle_flag_align_y = true   # 閃きは飛ぶ向きへ伸びる
	var m := ShaderMaterial.new()
	m.shader = SH
	m.set_shader_parameter("additive", 0.0 if petal else 1.0)
	m.set_shader_parameter("flutter", 1.0 if petal else 0.0)
	var p := GPUParticles2D.new()
	p.process_material = pm
	p.texture = SHEET
	p.material = m
	p.amount = 40 if not petal else 26
	p.lifetime = 0.9 if not petal else 1.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.6
	p.emitting = false
	p.local_coords = false
	p.visibility_rect = Rect2(-2000, -2000, 4000, 4000)
	if use_cpu:
		var c := CPUParticles2D.new()
		c.convert_from_particles(p)
		c.texture = SHEET
		c.material = m
		c.emitting = false
		p.free()
		add_child(c)
		return c
	add_child(p)
	return p

## 世界の位置 wp に撒く。k＝強さ（大きさと速さ）
func emit_at(wp: Vector3, k: float = 1.0) -> void:
	if cam == null or cam.is_position_behind(wp):
		return
	var sp := cam.unproject_position(wp)
	var u: float = get_viewport().get_visible_rect().size.y / 720.0
	var s: Dictionary = sets[next]
	next = (next + 1) % POOL
	for key in ["spark", "petal"]:
		var n = s[key]
		n.position = sp
		n.scale = Vector2.ONE * u * k
		n.material.set_shader_parameter("hdr", hdr)
		if "use_fixed_seed" in n:
			n.use_fixed_seed = fixed_seed >= 0
			if fixed_seed >= 0:
				n.seed = fixed_seed
		n.restart()
		n.emitting = true
