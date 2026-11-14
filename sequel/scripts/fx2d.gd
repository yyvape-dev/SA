extends CanvasLayer
## 2D のエフェクトの層（2026-11-07、specs/vfx_overhaul.md）。
## SA2 は 3D が画面全体を覆うので、2D のエフェクトを glow させるには「背景の canvas」に置けない（3D の後ろに隠れる）。
## → 専用の SubViewport（hdr_2d・背景 Canvas の WorldEnvironment で glow、黒地）に描き、3D の上・UI の下へ加算で重ねる。
##    UI は別の CanvasLayer なので光らない。画素はウィンドウの実寸で描く（size_2d_override で座標だけ 1280×720 基準）。
## 光らせる色は RAW（1 を超える値）＝GLOW_RAW 倍。閾値 GLOW_TH より明るい所だけがにじむ。
## 素材：REEBO0 godot-stylized-2d-vfx-lite（MIT、addons/reeboo_fx2d）、Kenney Particle Pack（CC0、addons/kenney_particle_pack）。
## 位置は世界の座標で受け取り、毎コマ画面へ写す（カメラが動いても付いてくる）。時間は実時間（ヒットストップ中も動く）。

## REEBO の4種は tools/bake_reeboo.gd で連番の絵（assets/vfx/reeboo_<名前>.png、白黒、黒地）に焼いたものを使う。
## 事実（2026-11-07）：iPhone の Safari では REEBO のシェーダーが動かず、白い四角（quad.png）が光って見えた → 絵をめくるだけにした。
const PICK := "coin_pickup"   # 焼いた連番で残したのは取得の輪だけ（当たり・斬撃は Kenney の絵＋共通シェーダーに。2026-11-07 の F）
const VFX := preload("res://scripts/vfx_sprite.gdshader")
## 色の帯（グラデーションマップ）：左＝芯の白 → 右＝外の暗い色、最後は透明。ラナ＝白→青→紺、強い当たり＝白→金→紅
const BANDS := {
	"blue": [[0.0, Color(1, 1, 1, 1)], [0.3, Color(0.55, 0.8, 1.0, 1)], [0.6, Color(0.15, 0.35, 1.0, 1)], [0.85, Color(0.04, 0.07, 0.35, 0.8)], [1.0, Color(0.02, 0.03, 0.15, 0)]],
	"gold": [[0.0, Color(1, 1, 1, 1)], [0.3, Color(1.0, 0.86, 0.45, 1)], [0.6, Color(1.0, 0.55, 0.12, 1)], [0.85, Color(0.8, 0.12, 0.15, 0.8)], [1.0, Color(0.3, 0.02, 0.05, 0)]],
	"silver": [[0.0, Color(1, 1, 1, 1)], [0.3, Color(0.78, 0.9, 1.0, 1)], [0.6, Color(0.3, 0.6, 1.0, 1)], [0.85, Color(0.3, 0.22, 0.65, 0.8)], [1.0, Color(0.1, 0.05, 0.2, 0)]],
	"fire": [[0.0, Color(1, 1, 0.9, 1)], [0.25, Color(1.0, 0.85, 0.35, 1)], [0.55, Color(1.0, 0.45, 0.08, 1)], [0.8, Color(0.7, 0.1, 0.05, 0.7)], [1.0, Color(0.15, 0.02, 0.02, 0)]],
}
var band_tex := {}
var noise: Texture2D     # fx.noise_tex（main が入れる。無ければ作る）
var books := {}          # 名前 -> {tex, frames, fps, cols, rows, cell, scale}
const KP := "res://assets/vfx/kenney/"   # 使う絵だけを addons/kenney_particle_pack から写した（書き出しは addons/ を外す）
const GLOW_RAW := 1.3        # 外側のにじみ
const CORE_RAW := 2.0        # 光る粒の芯（game-vfx-juice の基準：芯 2.0、にじみ 1.3）
const GLOW_TH := 0.7
const NATIVE_PX := 110.0     # REEBO の場面のおおよその大きさ（px）

const BLUE := Color(0.35, 0.65, 1.0)
const GOLD := Color(1.0, 0.72, 0.28)
const SILVER := Color(0.6, 0.85, 1.0)

var cam: Camera3D
var sv: SubViewport
var root2d: Node2D
var view: TextureRect
var env: Environment
var items := []          # {node, wp, life, t}
var tex := {}
var enabled := true
var assets_ok := false
## 重さ（specs/web_perf.md の 1）：エフェクトが無い間は層の描画を止めて隠す（事実：空でも全画面の HDR の層と glow を毎コマ描き、fps −約27％）
var idle_stop := true
var half := false         # 層を半分の解像度で描く（?fxhalf=1・環境変数 FXHALF=1。採否はユーザー判定）
var active := true    # 絵（地区 pck fx1）を読み終えたか。main._load_fx が立てる

func _ready() -> void:
	layer = 1
	enabled = not OS.has_environment("FX2D_OFF")
	half = OS.has_environment("FXHALF")
	if OS.has_feature("web"):
		var q0 := str(JavaScriptBridge.eval("window.location.search"))
		half = half or q0.contains("fxhalf=1")
		idle_stop = not q0.contains("fxidle=0")   # 比べる用：?fxidle=0 で前と同じく毎コマ描く
	var q := str(JavaScriptBridge.eval("window.location.search")) if OS.has_feature("web") else ""
	if q.contains("fx2d=0"):   # 確認用：?fx2d=0 で 2D の層を出さない（従来の当たり）、?fxglow=0 で層の glow だけ切る
		enabled = false
	sv = SubViewport.new()
	sv.use_hdr_2d = true
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 0
	env.glow_enabled = not (q.contains("fxglow=0") or OS.has_environment("FXGLOW_OFF"))
	env.glow_intensity = 1.1
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = GLOW_TH
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	sv.add_child(we)
	var bg := ColorRect.new()   # 黒地（加算で重ねるので黒＝何も足さない）
	bg.color = Color.BLACK
	bg.size = Vector2(8192, 8192)
	bg.position = Vector2(-4096, -4096)
	sv.add_child(bg)
	root2d = Node2D.new()
	sv.add_child(root2d)
	add_child(sv)
	view = TextureRect.new()
	view.texture = sv.get_texture()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	view.material = cm
	add_child(view)
	_fit()
	get_viewport().size_changed.connect(_fit)

func _fit() -> void:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size()) if not OS.has_feature("web") else vis * get_viewport().get_final_transform().get_scale()
	if win.x < 8.0:
		win = vis
	if half:
		win *= 0.5
	sv.size = Vector2i(maxi(8, int(win.x)), maxi(8, int(win.y)))
	sv.size_2d_override = Vector2i(int(vis.x), int(vis.y))
	sv.size_2d_override_stretch = true
	view.position = Vector2.ZERO
	view.size = vis

func _tex(name: String) -> Texture2D:
	if not tex.has(name):
		tex[name] = load(KP + name + ".png")
	return tex[name]

## 世界の位置での 1m の画素数（画面の座標＝1280×720 基準）
func px_per_m(wp: Vector3) -> float:
	if cam == null:
		return 200.0
	var r := cam.global_transform.basis.x
	return (cam.unproject_position(wp + r) - cam.unproject_position(wp)).length()

func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	view.visible = on

func _track(n: Node2D, wp: Vector3, life: float) -> void:
	_set_active(true)
	n.position = cam.unproject_position(wp) if cam else Vector2.ZERO   # 足す前に置く（粒子が原点から尾を引かないように）
	root2d.add_child(n)
	items.append({"node": n, "wp": wp, "life": life, "t": 0.0})

func _process(delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		it.t += delta
		if not is_instance_valid(it.node) or (it.life > 0.0 and it.t > it.life):
			if is_instance_valid(it.node):
				it.node.queue_free()
			items.remove_at(i)
			continue
		if cam and not cam.is_position_behind(it.wp):
			it.node.position = cam.unproject_position(it.wp)
		if it.has("mat"):   # 共通シェーダーの寿命の進み
			it.mat.set_shader_parameter("life", clampf(it.t / it.life, 0.0, 1.0))
		if it.has("base"):   # 単発の大きさ：出は 2〜3 コマで 0→1.15、そのあとゆっくり
			var sk: float = float(it.base) * size_k(it.t, it.life, float(it.end))
			it.node.scale = Vector2(-sk if it.flip else sk, sk)
		if it.has("book"):
			it.node.frame = mini(int(it.t * float(it.book.fps)), int(it.book.frames) - 1)
	if idle_stop and items.is_empty():   # 何も無ければ層を止める（glow の余韻は items の寿命の中で消えている）
		_set_active(false)

func _book(name: String) -> Dictionary:
	if books.is_empty():
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/reeboo.json"))
		for k in meta:
			var m: Dictionary = meta[k]
			books[k] = {"tex": load("res://assets/vfx/reeboo_%s.png" % k), "frames": int(m.frames), "fps": float(m.fps),
				"cols": int(m.cols), "rows": int(ceil(float(m.frames) / float(m.cols))), "cell": float(m.cell), "scale": float(m.scale)}
	return books[name]

func _band(name: String) -> GradientTexture1D:
	if not band_tex.has(name):
		var g := Gradient.new()
		var offs := PackedFloat32Array()
		var cs := PackedColorArray()
		for st in BANDS[name]:
			offs.append(float(st[0]))
			cs.append(st[1])
		g.offsets = offs
		g.colors = cs
		var t := GradientTexture1D.new()
		t.gradient = g
		t.width = 64   # 小さく（大きいと段が出る）
		band_tex[name] = t
	return band_tex[name]

func _noise() -> Texture2D:
	if noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.02
		fn.fractal_octaves = 3
		noise = ImageTexture.create_from_image(fn.get_seamless_image(128, 128))
	return noise

## 共通シェーダーの材質。o：raw・cool・erode_from・erode_soft・noise_amt・stretch・arc・particles
func vmat(band: String, o: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VFX
	m.set_shader_parameter("grad", _band(band))
	m.set_shader_parameter("noise_tex", _noise())
	m.set_shader_parameter("seed", randf() * 10.0)
	for k in o:
		m.set_shader_parameter(k, o[k])
	return m

## 大きさの曲線（単発）：出は 2〜3 コマ（0.045 秒）で 0→1.15（ease-out）、そのあとゆっくり end へ
static func size_k(t: float, life: float, end: float) -> float:
	var t0 := 0.045
	if t < t0:
		var k := t / t0
		return 1.15 * (1.0 - (1.0 - k) * (1.0 - k))
	return lerpf(1.15, end, clampf((t - t0) / maxf(life - t0, 0.001), 0.0, 1.0))

## 単発の絵（Kenney の1枚）。size_m＝世界での大きさ、end＝寿命の終わりの大きさの倍、angle＝画面での向き（度）
func sprite(name: String, wp: Vector3, size_m: float, life: float, band: String, o: Dictionary = {}, angle: float = 0.0, flip: bool = false, end: float = 1.3) -> Sprite2D:
	if not enabled or not assets_ok or cam == null or cam.is_position_behind(wp):
		return null
	var sp := Sprite2D.new()
	sp.texture = _tex(name)
	var m := vmat(band, o)
	sp.material = m
	sp.rotation_degrees = angle
	_track(sp, wp, life)
	var it: Dictionary = items[items.size() - 1]
	it["mat"] = m
	it["base"] = px_per_m(wp) * size_m / float(sp.texture.get_width())
	it["flip"] = flip
	it["end"] = end
	sp.scale = Vector2.ZERO
	return sp

## 焼いた連番（取得の輪）も共通シェーダーで色を付ける
func book(name: String, wp: Vector3, size_m: float, band: String, raw_k: float = 1.3) -> void:
	if not enabled or not assets_ok or cam == null or cam.is_position_behind(wp):
		return
	var b := _book(name)
	var sp := Sprite2D.new()
	sp.texture = b.tex
	sp.hframes = b.cols
	sp.vframes = b.rows
	var m := vmat(band, {"raw": raw_k, "erode_from": 0.6, "cool": 0.3})
	sp.material = m
	var s: float = px_per_m(wp) * size_m / NATIVE_PX / float(b.scale)
	sp.scale = Vector2(s, s)
	var life: float = float(b.frames) / float(b.fps)
	_track(sp, wp, life)
	var it: Dictionary = items[items.size() - 1]
	it["book"] = b
	it["mat"] = m

## Kenney の粒を撒く（CPUParticles2D＋共通シェーダー）。芯（RAW 2.0）とにじみ（light_01、RAW 1.3）の2枚を同じ乱数の種で。
## 寿命は ±20%（lifetime_randomness）、大きさは出で 0→1.15→end、色と侵食はシェーダー（寿命＝INSTANCE_CUSTOM.y）
func burst(names: Array, wp: Vector3, n: int, band: String, spd_m: Vector2, life: float, size_m: Vector2, damp: float = 6.0, up: float = 0.0, align: bool = false, spin: float = 0.0, end: float = 0.6, stretch: float = 0.0, halo: bool = true) -> void:
	if not enabled or not assets_ok or cam == null or cam.is_position_behind(wp):
		return
	var ppm := px_per_m(wp)
	var per := maxi(1, n / names.size())
	for k in names.size():
		var sd := randi()
		for layer in ([0, 1] if halo else [0]):
			var t := _tex(String(names[k]) if layer == 0 else "light_01")
			var p := CPUParticles2D.new()
			p.use_fixed_seed = true
			p.seed = sd
			p.texture = t
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = spd_m.x * ppm
			p.initial_velocity_max = spd_m.y * ppm
			p.damping_min = damp * ppm * 0.7
			p.damping_max = damp * ppm * 1.3
			p.gravity = Vector2(0, -up * ppm)
			var px: float = float(t.get_width())
			var sk: float = 1.0 if layer == 0 else 2.4
			p.scale_amount_min = size_m.x * sk * ppm / px
			p.scale_amount_max = size_m.y * sk * ppm / px
			var sc := Curve.new()   # 出は 2〜3 コマで 0→1.15、そのあとゆっくり end へ
			sc.max_value = 1.2
			sc.add_point(Vector2(0, 0))
			sc.add_point(Vector2(clampf(0.045 / life, 0.02, 0.3), 1.15))
			sc.add_point(Vector2(1, end))
			p.scale_amount_curve = sc
			if align:   # CPU の粒子は速さ 0 の時に向きを変えない（GPU 版で出た画面の端までの線は出ない）
				p.particle_flag_align_y = true
			elif spin > 0.0:
				p.angle_min = -180.0
				p.angle_max = 180.0
				p.angular_velocity_min = -spin
				p.angular_velocity_max = spin
			p.material = vmat(band, {"particles": 1.0, "raw": CORE_RAW if layer == 0 else GLOW_RAW, "stretch": stretch if layer == 0 else 0.0,
				"alpha": 1.0 if layer == 0 else 0.35, "erode_from": 0.35, "cool": 0.45})
			p.amount = per
			p.lifetime = life
			p.lifetime_randomness = 0.4
			p.one_shot = true
			p.explosiveness = 1.0
			p.randomness = 0.5
			p.local_coords = false
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE   # 一点から出すと平たい → 小さな円から
			p.emission_sphere_radius = 0.08 * ppm
			_track(p, wp, life * 1.25 + 0.2)
			p.emitting = true

func raw(c: Color, k: float = GLOW_RAW) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

func _pal(strong: bool, pal: String) -> String:
	return "gold" if strong else ("silver" if pal == "silver" else "blue")

## 当たり：芯の閃光（侵食で消える）＋飛ぶ向きに伸びる火花。輪は強い当たりだけ（広がるほど細く＝侵食で外から食う）
func hit(wp: Vector3, dir: int, strong: bool, pal: String = "blue") -> void:
	var b := _pal(strong, pal)
	# Local sharp contact, then a colored directional tail. Broad particle halos stack into white discs in crowds.
	sprite("light_01", wp, 0.50 if strong else 0.38, 0.11 if strong else 0.08, b, {"raw": CORE_RAW, "erode_from": 0.2, "cool": 0.65}, 0.0, false, 1.1)
	sprite("trace_01", wp, 0.85 if strong else 0.65, 0.20, b, {"raw": 1.2, "alpha": 0.55, "erode_from": 0.3, "cool": 0.65}, 90.0 * dir, false, 1.3)
	burst(["spark_05", "trace_01"], wp, 14 if strong else 8, b, Vector2(4.0, 9.0), 0.28, Vector2(0.10, 0.23), 14.0, 0.0, true, 0.0, 0.5, 2.2, false)
	if strong:
		sprite("circle_03", wp, 0.7, 0.32, b, {"raw": 1.6, "erode_from": 0.0, "erode_soft": 0.1, "noise_amt": 0.3, "cool": 0.6}, 0.0, false, 3.2)

## Single-target finisher: a vertical silver needle plus local contact, without an area-sized flare.
func target_hit(wp: Vector3) -> void:
	sprite("trace_01", wp, 1.15, 0.20, "silver", {"raw": 1.6, "alpha": 0.85, "erode_from": 0.2, "cool": 0.6})
	sprite("light_01", wp, 0.55, 0.11, "silver", {"raw": 1.8, "erode_from": 0.15, "cool": 0.65}, 0.0, false, 1.1)
	sprite("circle_03", wp, 0.6, 0.32, "silver", {"raw": 1.3, "erode_from": 0.0, "cool": 0.6}, 0.0, false, 1.6)
	burst(["spark_05", "trace_01"], wp, 12, "silver", Vector2(3.0, 7.0), 0.32, Vector2(0.10, 0.22), 14.0, 0.0, true, 0.0, 0.5, 2.0, false)

## Defense contact: compact gold ring and sparks, distinct from offensive blue/silver.
## 0-45ms ignition, 45-100ms peak, 100-280ms erosion/decay. No full-screen flash.
func guard(wp: Vector3) -> void:
	sprite("light_01", wp, 0.7, 0.10, "gold", {"raw": 1.6, "alpha": 0.7, "erode_from": 0.25}, 0.0, false, 1.1)
	sprite("circle_03", wp, 0.55, 0.26, "gold", {"raw": 1.3, "erode_from": 0.0, "erode_soft": 0.12, "cool": 0.5}, 0.0, false, 2.1)
	burst(["spark_05", "trace_01"], wp, 8, "gold", Vector2(2.5, 5.0), 0.28, Vector2(0.10, 0.22), 14.0, 0.0, true, 0.0, 0.5, 1.8)

## 振りの弧：Kenney の三日月（slash_02）を、弧に沿って先端が走り、尾から消えるように。angle は画面での向き（0＝右を上から下へ）
func slash(wp: Vector3, face: int, size_m: float, angle: float, col: Color = BLUE) -> void:
	var b := "gold" if col == GOLD else "blue"
	sprite("slash_02", wp, size_m * 2.0, 0.28, b, {"raw": CORE_RAW, "arc": 1.0, "erode_from": 0.55, "noise_amt": 0.2, "cool": 0.35}, (-90.0 + angle) * (1 if face > 0 else -1), face < 0, 1.08)

## 撃破（芯＝加算、煙・焦げ＝3D の板で普通の合成、余韻に残り火）
func kill(wp: Vector3, fx3d = null, foot: Vector3 = Vector3.ZERO) -> void:
	sprite("flare_01", wp, 1.6, 0.2, "gold", {"raw": CORE_RAW, "erode_from": 0.3, "cool": 0.6})
	sprite("light_01", wp, 2.4, 0.32, "gold", {"raw": GLOW_RAW, "alpha": 0.5, "erode_from": 0.2})
	burst(["fire_01", "flame_02"], wp, 10, "fire", Vector2(1.2, 3.2), 0.5, Vector2(0.35, 0.7), 5.0, 0.6, false, 90.0, 1.3)
	burst(["spark_01", "magic_02"], wp, 14, "fire", Vector2(1.5, 4.5), 1.1, Vector2(0.06, 0.16), 3.0, 0.9, false, 0.0, 0.7)   # 残り火（余韻）
	if fx3d:
		for k in 3:
			fx3d.tex_quad(["smoke_04", "smoke_07"][k % 2], foot + Vector3(randf_range(-0.3, 0.3), 0.7 + k * 0.25, -0.05), 1.1,
				{"add": false, "col": Color(0.13, 0.11, 0.17, 0.75), "size": 0.9 + k * 0.2, "grow": 1.9, "rise": 0.8, "spin": randf_range(-1.0, 1.0), "fade_in": 0.1})
		fx3d.tex_quad(["scorch_01", "scorch_02"][randi() % 2], foot, 1.8, {"floor": true, "add": false, "col": Color(0.05, 0.03, 0.04, 0.7), "size": 1.4, "grow": 1.1, "fade_in": 0.05})
		fx3d.tex_quad("light_01", foot, 0.5, {"floor": true, "add": true, "col": GOLD, "raw": 1.3, "size": 2.2, "grow": 1.4})

## 拾った：取得の輪（焼いた連番、金）
func pickup(wp: Vector3) -> void:
	book(PICK, wp, 0.9, "gold")

## 大技の決め：撃破と同じ層で大きく。col＝金（ラナ）／銀（リリィ）
func big(wp: Vector3, col: Color, fx3d = null, foot: Vector3 = Vector3.ZERO) -> void:
	var b := "gold" if col == GOLD else "silver"
	sprite("flare_01", wp, 3.0, 0.24, b, {"raw": CORE_RAW, "erode_from": 0.3})
	sprite("light_01", wp, 4.2, 0.4, b, {"raw": GLOW_RAW, "alpha": 0.5, "erode_from": 0.2})
	sprite("circle_03", wp, 1.4, 0.45, b, {"raw": 1.6, "erode_from": 0.0, "noise_amt": 0.3, "cool": 0.6}, 0.0, false, 3.5)
	burst(["light_01", "spark_05"], wp, 24, b, Vector2(4.0, 10.0), 0.6, Vector2(0.12, 0.35), 10.0, 0.0, true, 0.0, 0.5, 2.0)
	burst(["spark_01"], wp, 16, "fire", Vector2(1.5, 4.0), 1.2, Vector2(0.06, 0.14), 3.0, 0.9, false, 0.0, 0.7)
	if fx3d:
		fx3d.tex_quad("light_01", foot, 0.6, {"floor": true, "add": true, "col": col, "raw": 1.3, "size": 3.5, "grow": 1.6})
		fx3d.tex_quad("scorch_02", foot, 2.0, {"floor": true, "add": false, "col": Color(0.05, 0.03, 0.04, 0.6), "size": 2.4, "fade_in": 0.05})

## Flowing Rana skill edge: broad colored silhouette, brief white core, crossing motion.
func flurry_edge(wp: Vector3, face: int, reach: float, angle: float, final: bool) -> void:
	sprite("slash_02", wp, reach * (1.65 if final else 1.35), 0.30 if final else 0.17, "gold", {"raw": 1.55, "arc": 1.0, "erode_from": 0.35, "noise_amt": 0.25, "cool": 0.45}, (-90.0 + angle) * face, face < 0, 1.08)
	if final:
		sprite("trace_01", wp, 2.4, 0.18, "gold", {"raw": 1.45, "alpha": 0.7, "erode_from": 0.25, "cool": 0.6}, -25.0 * face, face < 0, 1.2)
		burst(["trace_01", "spark_05"], wp, 16, "gold", Vector2(5.0, 10.0), 0.32, Vector2(0.08, 0.18), 12.0, 0.0, true, 0.0, 0.5, 2.5, false)
