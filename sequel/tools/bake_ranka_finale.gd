extends SceneTree
## ランカの大技の締め（星震の締め quake・天照の決め ama）を、Godot で描いて連番に焼く（2026-11-12、ユーザー決定：大技は Godot で描いて焼く）。
## 手順は Skill naraku-vfx の 7.（光の回と抜きの回を分けて焼く、毎回同じ乱数）と game-vfx-juice（予兆→炸裂→余韻・層・大きさの曲線・回さない）。
## 使い方（リポジトリの sequel で、xvfb の実描画。--headless では描かれない）：
##   xvfb-run -a -s '-screen 0 1280x720x24' godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/bake_ranka_finale.gd
##   → art/vfx_bake/<名前>/light_NNN.png・dark_NNN.png（git に入れない）→ python3 -I tools/pack_ranka_finale.py でアトラスに。
## 画面：1024×576（ゲームでは半分の 512×288 に縮める）、64px＝1m、中心（ランカの胸）＝(512, 300)、地面＝中心の 1.3m 下。
## 層（光＝加算・黒地、抜き＝通常の合成・透明地）：
##   予兆（0〜HIT）：外から中心へ集まる光の筋・中心の光が育つ（EASE_IN）・床の輪が閉じる
##   炸裂（HIT）：芯の閃光 2 コマ → 爆ぜの絵が中心から外へ現れる（0.1 秒で 0.35→1.0、その後ゆっくり 1.15）。回さない。外と暗い所から侵食で消える。色は寿命で冷める
##   光の筋：放射に飛ぶ帯（速さで伸び、減速）／粒：金と青白（減速＋重力）／床の輪が広がる
##   抜き：黒い破片（放物線・回転）・地を這う土煙・朱の花びら
const W := 1024
const H := 576
const PPM := 64.0
const C := Vector2(512, 300)
const GROUND := 300.0 + 1.3 * 64.0
const FPS := 30
const HIT := 0.25
const TX := "res://assets/vfx/ranka/"

const CONF := {
	"quake": {"dur": 0.95, "burst": 0.66, "gold": 0.25, "petals": 12, "streaks": 34, "sparks": 70, "frags": 16, "wave2": false, "band": "blue"},
	"ama": {"dur": 1.25, "burst": 0.78, "gold": 0.55, "petals": 70, "streaks": 44, "sparks": 110, "frags": 12, "wave2": true, "pillar": false, "band": "gold"},
}

var rng := RandomNumberGenerator.new()
var shader: Shader
var noise: Texture2D
var grads := {}
var petal_shader: Shader

func _init() -> void:
	_run.call_deferred()

func _grad(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var c := PackedColorArray()
	for s in stops:
		o.append(float(s[0]))
		c.append(s[1])
	g.offsets = o
	g.colors = c
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return t

func _mat(band: String, gain: float, erode_from: float, sd: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("grad", grads[band])
	m.set_shader_parameter("noise_tex", noise)
	m.set_shader_parameter("gain", gain)
	m.set_shader_parameter("erode_from", erode_from)
	m.set_shader_parameter("seed", sd)
	return m

func _spr(parent: Node, tex: Texture2D, m: Material) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.material = m
	parent.add_child(s)
	return s

func _view(transparent: bool) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.transparent_bg = transparent
	sv.use_hdr_2d = not transparent
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not transparent:
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		bg.size = Vector2(W, H)
		sv.add_child(bg)
		var we := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		env.glow_hdr_threshold = 1.0
		env.glow_intensity = 0.7
		env.set_glow_level(1, 0.0)
		env.set_glow_level(2, 1.0)
		env.set_glow_level(3, 1.0)
		env.set_glow_level(4, 0.6)
		we.environment = env
		sv.add_child(we)
	root.add_child(sv)
	return sv

static func ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x

func _run() -> void:
	shader = load("res://tools/bake_texfx.gdshader")
	petal_shader = Shader.new()
	petal_shader.code = "shader_type canvas_item;\nuniform vec3 col : source_color;\nvoid fragment(){ vec4 t = texture(TEXTURE, UV); float l = max(t.r, max(t.g, t.b)); COLOR = vec4(mix(col, vec3(1.0, 0.95, 0.9), l * l * 0.45), min(1.0, t.a * 2.2) * COLOR.a); }"
	var fn := FastNoiseLite.new()
	fn.seed = 11
	fn.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = fn
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	await nt.changed
	noise = nt
	var W1 := Color(1, 1, 1, 1)
	grads["blue"] = _grad([[0.0, Color(1.0, 1.0, 1.0, 1)], [0.25, Color(0.62, 0.82, 1.0, 1)], [0.6, Color(0.2, 0.42, 1.0, 0.95)], [1.0, Color(0.05, 0.08, 0.5, 0)]])
	grads["gold"] = _grad([[0.0, Color(1.0, 1.0, 0.96, 1)], [0.25, Color(1.0, 0.86, 0.5, 1)], [0.6, Color(1.0, 0.52, 0.16, 0.95)], [1.0, Color(0.6, 0.12, 0.08, 0)]])
	grads["white"] = _grad([[0.0, W1], [0.5, Color(0.85, 0.92, 1.0, 1)], [1.0, Color(0.5, 0.6, 0.9, 0)]])
	for name in CONF:
		await _bake(name, CONF[name])
	quit(0)

func _bake(name: String, cf: Dictionary) -> void:
	rng.seed = 20261112 + name.length()
	var out := ProjectSettings.globalize_path("res://art/vfx_bake/" + name)
	DirAccess.make_dir_recursive_absolute(out)
	var lv := _view(false)
	var dv := _view(true)
	var tv := _view(true)   # 上の回：花びら（光の上に重ねる。朱が光に埋もれないように）
	var tex := {}
	for k in ["burst", "flare", "ring", "band_blade", "pillar", "petals"]:
		tex[k] = load(TX + k + ".png")
	var smoke: Texture2D = load("res://assets/vfx/kenney/smoke_04.png")
	var main_band: String = cf.band
	# ---- 光の回 ----
	var pre := []
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.15, 0.15)
		var s := _spr(lv, tex.band_blade, _mat("blue" if i % 3 else "gold", 1.6, 0.9, rng.randf() * 9.0))
		pre.append({"n": s, "a": a, "r0": rng.randf_range(260.0, 360.0), "d": rng.randf_range(0.0, 0.08)})
	var core := _spr(lv, tex.flare, _mat("white", 2.0, 0.5, 1.0))
	var close_ring := _spr(lv, tex.ring, _mat("blue", 1.2, 0.95, 2.0))
	var burst := _spr(lv, tex.burst, _mat(main_band, 1.45, 0.04, 3.0))
	(burst.material as ShaderMaterial).set_shader_parameter("cool", 0.75)
	var burst2: Sprite2D = null
	if cf.wave2:
		burst2 = _spr(lv, tex.burst, _mat("blue", 1.5, 0.1, 4.0))
	var pillar: Sprite2D = null
	if cf.get("pillar", false):
		pillar = _spr(lv, tex.pillar, _mat("gold", 1.6, 0.25, 5.0))
	var ground_ring := _spr(lv, tex.ring, _mat("blue", 1.5, 0.15, 6.0))
	var streaks := []
	for i in int(cf.streaks):
		var a := rng.randf() * TAU
		a = lerp_angle(a, 0.0 if cos(a) > 0 else PI, 0.25)   # 横へ少し寄せる（画面が横長）
		var gold := rng.randf() < float(cf.gold)
		var s := _spr(lv, tex.band_blade, _mat("gold" if gold else "blue", 1.7, 0.1, rng.randf() * 9.0))
		streaks.append({"n": s, "a": a, "v": rng.randf_range(700.0, 1600.0), "d": rng.randf_range(0.0, 0.05), "w": rng.randf_range(0.18, 0.32), "life": rng.randf_range(0.35, 0.6)})
	var sparks := []
	for i in int(cf.sparks):
		var a := rng.randf() * TAU
		var gold := rng.randf() < float(cf.gold)
		var s := _spr(lv, tex.flare, _mat("gold" if gold else "blue", 2.2, 0.6, rng.randf() * 9.0))
		sparks.append({"n": s, "a": a, "v": rng.randf_range(300.0, 1200.0), "d": rng.randf_range(0.0, 0.12), "sz": rng.randf_range(0.03, 0.075), "life": rng.randf_range(0.4, 0.75)})
	# ---- 抜きの回 ----
	var frags := []
	for i in int(cf.frags):
		var p := Polygon2D.new()
		var pts := PackedVector2Array()
		var nv := rng.randi_range(4, 7)
		var rr := rng.randf_range(7.0, 18.0)
		for k in nv:
			var aa := TAU * float(k) / nv + rng.randf_range(-0.3, 0.3)
			pts.append(Vector2(cos(aa), sin(aa)) * rr * rng.randf_range(0.6, 1.2))
		p.polygon = pts
		p.color = Color(0.05, 0.06, 0.12, 0.95)
		dv.add_child(p)
		var a := rng.randf_range(-PI, 0.0) if rng.randf() < 0.8 else rng.randf() * TAU   # 多くは上半分へ
		frags.append({"n": p, "a": a, "v": rng.randf_range(450.0, 1050.0), "spin": rng.randf_range(-12.0, 12.0)})
	var dust := []
	for i in 10:
		var s := Sprite2D.new()
		s.texture = smoke
		s.modulate = Color(0.07, 0.07, 0.11, 0.0)
		dv.add_child(s)
		dust.append({"n": s, "dir": -1.0 if i % 2 else 1.0, "v": rng.randf_range(120.0, 380.0), "sz": rng.randf_range(0.35, 0.7), "y": rng.randf_range(-14.0, 6.0)})
	var petals := []
	var pcols := [Color(1.0, 0.36, 0.2), Color(1.0, 0.48, 0.32), Color(1.0, 0.62, 0.5), Color(1.0, 0.86, 0.8), Color(1.0, 0.4, 0.26)]   # 朱が主（白っぽい素材に掛けて暗くならないよう明るめ）
	for i in int(cf.petals):
		var s := Sprite2D.new()
		s.texture = tex.petals
		s.hframes = 4
		s.vframes = 2
		s.frame = rng.randi() % 8
		var c: Color = pcols[rng.randi() % pcols.size()]
		s.modulate = Color(1, 1, 1, 0.0)
		var pm := ShaderMaterial.new()   # 花びら：明るさ→色（暗い所＝朱、明るい根元＝白）。掛け算だと朱が茶色に濁った
		pm.shader = petal_shader
		pm.set_shader_parameter("col", c)
		s.material = pm
		tv.add_child(s)
		var a := rng.randf() * TAU
		petals.append({"n": s, "a": a, "v": rng.randf_range(700.0, 1700.0), "d": rng.randf_range(0.06, 0.22), "spin": rng.randf_range(-8.0, 8.0),
			"sz": rng.randf_range(0.24, 0.42), "ph": rng.randf() * TAU, "flip": rng.randf_range(5.0, 10.0)})
	await process_frame
	var n := int(ceil(float(cf.dur) * FPS))
	for f in n:
		var t := float(f) / FPS
		var u := t - HIT                     # 炸裂からの時間
		var L := clampf(u / (float(cf.dur) - HIT), 0.0, 1.0)
		# 予兆：外から中心へ集まる筋
		for q in pre:
			var k := clampf((t - q.d) / (HIT - q.d), 0.0, 1.0)
			var s: Sprite2D = q.n
			s.visible = t < HIT and t >= q.d
			var r := lerpf(q.r0, 24.0, ease_in(k))
			s.position = C + Vector2(cos(q.a), sin(q.a) * 0.75) * r
			s.rotation = q.a + PI   # 頭を中心へ向ける
			s.scale = Vector2(0.12 + 0.18 * k, 0.12)
			(s.material as ShaderMaterial).set_shader_parameter("life", 0.0)
			(s.material as ShaderMaterial).set_shader_parameter("alpha", k)
		# 中心の光：溜めで育つ → 炸裂で大きく 2 コマ → しぼむ
		var cs := 0.0
		if u < 0.0:
			cs = lerpf(0.12, 0.55, ease_in(t / HIT))
		elif u < 2.0 / FPS:
			cs = 1.7 * float(cf.burst)
		else:
			cs = lerpf(0.8, 0.12, ease_out(u / 0.25))
		core.position = C
		core.scale = Vector2.ONE * cs
		(core.material as ShaderMaterial).set_shader_parameter("life", clampf(u / 0.6, 0.0, 1.0))
		(core.material as ShaderMaterial).set_shader_parameter("alpha", 1.0 if u < 0.45 else 1.0 - (u - 0.45) / 0.2)
		# 床の輪：溜めの間に閉じる
		close_ring.visible = u < 0.0
		close_ring.position = Vector2(C.x, GROUND)
		close_ring.scale = Vector2(1.0, 0.24) * lerpf(0.75, 0.1, ease_in(t / HIT))
		(close_ring.material as ShaderMaterial).set_shader_parameter("alpha", 0.45 * clampf(t / HIT * 2.0, 0.0, 1.0))
		# 爆ぜ：中心から外へ現れ、ゆっくり広がり、外から侵食で消える（回さない）
		burst.visible = u >= 0.0
		var bs := (0.35 + 0.65 * ease_out(u / 0.1)) if u < 0.1 else lerpf(1.0, 1.15, ease_out((u - 0.1) / 0.8))
		burst.position = C
		burst.scale = Vector2.ONE * bs * float(cf.burst)
		var bm := burst.material as ShaderMaterial
		bm.set_shader_parameter("alpha", 1.0 - smoothstep(0.55, 1.0, L))
		bm.set_shader_parameter("reveal", ease_out(u / 0.12) * 1.15)
		bm.set_shader_parameter("life", L)
		if burst2:
			var u2 := u - 0.2
			burst2.visible = u2 >= 0.0
			burst2.position = C + Vector2(0, -10)
			burst2.scale = Vector2.ONE * (0.3 + 0.5 * ease_out(u2 / 0.15)) * float(cf.burst)
			var b2 := burst2.material as ShaderMaterial
			b2.set_shader_parameter("reveal", ease_out(u2 / 0.15) * 1.15)
			b2.set_shader_parameter("life", clampf(u2 / 0.7, 0.0, 1.0))
		if pillar:
			pillar.visible = u >= 0.0
			pillar.position = Vector2(C.x, GROUND - 768.0 * 0.62 * 0.5 + 10.0)
			pillar.scale = Vector2(0.7 + 0.6 * ease_out(u / 0.3), 0.62)
			var pm := pillar.material as ShaderMaterial
			pm.set_shader_parameter("reveal", ease_out(u / 0.12) * 1.2)
			pm.set_shader_parameter("life", clampf(u / 0.9, 0.0, 1.0))
		# 床の輪：広がるほど細く、侵食で消える
		ground_ring.visible = u >= 0.0
		ground_ring.position = Vector2(C.x, GROUND)
		ground_ring.scale = Vector2(1.0, 0.24) * lerpf(0.35, 1.25, ease_out(u / 0.45))
		(ground_ring.material as ShaderMaterial).set_shader_parameter("life", clampf(u / 0.45, 0.0, 1.0))
		# 光の筋：放射に飛び、減速しながら縮み、侵食で消える
		for q in streaks:
			var s: Sprite2D = q.n
			var tt: float = u - q.d
			s.visible = tt >= 0.0 and tt < q.life
			if not s.visible:
				continue
			var kk := 4.0
			var dist: float = q.v / kk * (1.0 - exp(-kk * tt))
			var vnow: float = q.v * exp(-kk * tt)
			var dir := Vector2(cos(q.a), sin(q.a))
			s.position = C + dir * (40.0 + dist)
			s.rotation = q.a
			s.scale = Vector2(q.w * (0.35 + vnow / 1400.0), q.w * 0.55)
			(s.material as ShaderMaterial).set_shader_parameter("life", tt / q.life)
		# 粒：減速＋重力
		for q in sparks:
			var s: Sprite2D = q.n
			var tt: float = u - q.d
			s.visible = tt >= 0.0 and tt < q.life
			if not s.visible:
				continue
			var kk := 3.0
			var dir := Vector2(cos(q.a), sin(q.a))
			var p: Vector2 = C + dir * (q.v / kk * (1.0 - exp(-kk * tt))) + Vector2(0, 380.0 * tt * tt)
			s.position = p
			s.scale = Vector2.ONE * q.sz
			(s.material as ShaderMaterial).set_shader_parameter("life", tt / q.life)
		# 抜き：黒い破片
		for q in frags:
			var p2: Polygon2D = q.n
			p2.visible = u >= 0.0
			var kk := 2.0
			var dir := Vector2(cos(q.a), sin(q.a))
			p2.position = C + dir * (q.v / kk * (1.0 - exp(-kk * u))) + Vector2(0, 900.0 * u * u)
			p2.rotation = q.spin * u
			p2.color.a = 0.95 * (1.0 - smoothstep(0.45, 0.8, u))
		# 抜き：地を這う土煙
		for q in dust:
			var s: Sprite2D = q.n
			s.visible = u >= 0.02
			var kk := 2.5
			s.position = Vector2(C.x + q.dir * (60.0 + q.v / kk * (1.0 - exp(-kk * u))), GROUND + q.y - 30.0 * u)
			s.scale = Vector2(1.3, 0.8) * lerpf(q.sz * 0.5, q.sz * 1.3, ease_out(u / 0.7))
			s.modulate.a = 0.75 * smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.4, 0.95, L))
		# 抜き：朱の花びら（飛び出してから、ひらひら落ちる）
		for q in petals:
			var s: Sprite2D = q.n
			var tt: float = u - q.d
			s.visible = tt >= 0.0
			if not s.visible:
				continue
			var kk := 3.5
			var dir := Vector2(cos(q.a), sin(q.a) * 0.8 - 0.25).normalized()   # 少し上へ（舞い上がってから落ちる）
			s.position = C + dir * (70.0 + q.v / kk * (1.0 - exp(-kk * tt))) + Vector2(sin(tt * 5.0 + q.ph) * 18.0, 160.0 * tt * tt)
			s.rotation = q.spin * tt
			s.scale = Vector2(1.0, 0.5 + 0.5 * absf(sin(tt * q.flip + q.ph))) * q.sz
			s.modulate.a = smoothstep(0.0, 0.05, tt) * (1.0 - smoothstep(0.7, 1.0, L))
		await process_frame
		await RenderingServer.frame_post_draw
		lv.get_texture().get_image().save_png(out.path_join("light_%03d.png" % f))
		dv.get_texture().get_image().save_png(out.path_join("dark_%03d.png" % f))
		tv.get_texture().get_image().save_png(out.path_join("top_%03d.png" % f))
	print("baked ", name, " frames=", n)
	lv.queue_free()
	dv.queue_free()
	tv.queue_free()
	await process_frame
