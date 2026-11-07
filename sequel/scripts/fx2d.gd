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
const HIT := "hit_spark"
const SLASH := "slash_arc"
const PICK := "coin_pickup"
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
var assets_ok := false    # 絵（地区 pck fx1）を読み終えたか。main._load_fx が立てる

func _ready() -> void:
	layer = 1
	enabled = not OS.has_environment("FX2D_OFF")
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

func _track(n: Node2D, wp: Vector3, life: float) -> void:
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
		if it.has("pop"):   # ポン：0.3 倍から行き過ぎて 1 倍へ（BACK）、後半で薄れる
			var k: float = clampf(it.t / it.life, 0.0, 1.0)
			var e: float = 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			it.node.scale = Vector2.ONE * float(it.pop) * maxf(0.3, e)
			it.node.modulate.a = float(it.a0) * (1.0 - k * k)
		if it.has("book"):
			it.node.frame = mini(int(it.t * float(it.book.fps) * float(it.spd)), int(it.book.frames) - 1)

func _book(name: String) -> Dictionary:
	if books.is_empty():
		var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/reeboo.json"))
		for k in meta:
			var m: Dictionary = meta[k]
			books[k] = {"tex": load("res://assets/vfx/reeboo_%s.png" % k), "frames": int(m.frames), "fps": float(m.fps),
				"cols": int(m.cols), "rows": int(ceil(float(m.frames) / float(m.cols))), "cell": float(m.cell), "scale": float(m.scale)}
	return books[name]

## 焼いた連番を出す。size_m＝世界での大きさ（m）、angle＝画面での向き（度、右が 0、時計回り）、col は RAW で渡す
func spawn(name: String, wp: Vector3, size_m: float, col: Color, angle: float = 0.0, flip: bool = false, spd: float = 1.0) -> Node2D:
	if not enabled or not assets_ok or cam == null or cam.is_position_behind(wp):
		return null
	var b := _book(name)
	var sp := Sprite2D.new()
	sp.texture = b.tex
	sp.hframes = b.cols
	sp.vframes = b.rows
	sp.frame = 0
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = cm
	sp.modulate = col
	var s: float = px_per_m(wp) * size_m / NATIVE_PX / float(b.scale)
	sp.scale = Vector2(-s if flip else s, s)
	sp.rotation_degrees = angle
	var life: float = float(b.frames) / float(b.fps) / spd
	_track(sp, wp, life)
	items[items.size() - 1]["book"] = b
	items[items.size() - 1]["spd"] = spd
	return sp

## 事実（2026-11-07）：REEBO の火花は「粒を速さの向きにそろえる＋強い減速」で、止まった粒が画面の端まで白い線になった → 焼く時に外した（tools/bake_reeboo.gd）

## Kenney の粒を撒く（CPUParticles2D、加算）。粒ごとに「芯」と「にじみ」の2枚：同じ乱数の種で同じ動きをさせ、
## 芯＝その絵を CORE_RAW（2.0）、にじみ＝柔らかい丸（light_01）を 2.4 倍の大きさ・GLOW_RAW（1.3）・薄く。
## cols は色（RAW を掛ける前）、life は ±20% ばらつく（randomness）。end_col があれば寿命の中で色が変わる（一定の色は止まって見える）
func burst(names: Array, wp: Vector3, n: int, cols: Array, spd_m: Vector2, life: float, size_m: Vector2, damp: float = 6.0, up: float = 0.0, align: bool = false, spin: float = 0.0, end_col: Color = Color(1, 1, 1, 1), halo: bool = true) -> void:
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
			var sc := Curve.new()
			sc.add_point(Vector2(0, 1))
			sc.add_point(Vector2(1, 0.15))
			p.scale_amount_curve = sc
			var g := Gradient.new()   # 粒ごとの色（混ぜない階段）
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			var offs := PackedFloat32Array()
			var cs := PackedColorArray()
			var rk: float = CORE_RAW if layer == 0 else GLOW_RAW
			for j in cols.size():
				offs.append(float(j) / cols.size())
				var c0: Color = cols[j]
				cs.append(Color(c0.r * rk, c0.g * rk, c0.b * rk, c0.a * (1.0 if layer == 0 else 0.35)))
			g.offsets = offs
			g.colors = cs
			p.color_initial_ramp = g
			var fade := Gradient.new()   # 寿命の中で色を変え、最後は必ず透明
			fade.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
			fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(lerpf(1.0, end_col.r, 0.5), lerpf(1.0, end_col.g, 0.5), lerpf(1.0, end_col.b, 0.5), 0.85), Color(end_col.r, end_col.g, end_col.b, 0.0)])
			p.color_ramp = fade
			if align or spin > 0.0:   # 向きは出た時の角度で（速さの向きにそろえると、止まった粒が画面の端まで伸びた）
				p.angle_min = -180.0
				p.angle_max = 180.0
			if spin > 0.0:
				p.angular_velocity_min = -spin
				p.angular_velocity_max = spin
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = cm
			p.amount = per
			p.lifetime = life
			p.lifetime_randomness = 0.4   # 寿命を ±20% ばらつかせる（一斉に消えない）
			p.one_shot = true
			p.explosiveness = 1.0
			p.randomness = 0.5
			p.local_coords = false
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE   # 一点から出すと平たい → 小さな円から
			p.emission_sphere_radius = 0.08 * ppm
			_track(p, wp, life * 1.25 + 0.2)
			p.emitting = true

## 一度だけ光る芯（撃破の閃光など）：Kenney の絵を 1 枚、ポンと大きくして消す
func pop(name: String, wp: Vector3, size_m: float, col: Color, life: float) -> void:
	if not enabled or not assets_ok or cam == null or cam.is_position_behind(wp):
		return
	var sp := Sprite2D.new()
	sp.texture = _tex(name)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = cm
	sp.modulate = col
	sp.rotation = randf() * TAU
	_track(sp, wp, life)
	var it: Dictionary = items[items.size() - 1]
	it["pop"] = px_per_m(wp) * size_m / float(sp.texture.get_width())
	it["a0"] = col.a

# ---------- SA2 の場面ごとの出し方（色は RAW＝GLOW_RAW 倍で光らせる） ----------
func raw(c: Color, k: float = GLOW_RAW) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## 当たり：火花の場面＋細い火花（Kenney spark/trace、飛ぶ向きへ伸びる）。strong は金で大きく
func hit(wp: Vector3, dir: int, strong: bool, pal: String = "blue") -> void:
	var c: Color = GOLD if strong else (SILVER if pal == "silver" else BLUE)
	spawn(HIT, wp, 0.9 if strong else 0.6, raw(c), 0.0, dir < 0, 1.25)
	burst(["spark_05", "trace_01"], wp, 14 if strong else 8, [c, Color(1, 1, 1)], Vector2(4.0, 9.0), 0.35, Vector2(0.18, 0.4), 14.0, 0.0, false, 0.0)

## 振りの弧：REEBO の斬撃（三日月）を、技の向きに合わせて重ねる。angle は画面での向き
func slash(wp: Vector3, face: int, size_m: float, angle: float, col: Color = BLUE) -> void:
	spawn(SLASH, wp, size_m, raw(col), angle if face > 0 else -angle, face < 0, 1.3)

## 撃破（game-vfx-juice の層：芯＝加算、煙・焦げ＝普通の合成、余韻に残り火）。煙と焦げ跡は 3D の板（fx.tex_quad）で敵の足元・奥に
func kill(wp: Vector3, fx3d = null, foot: Vector3 = Vector3.ZERO) -> void:
	pop("flare_01", wp, 1.6, raw(GOLD, CORE_RAW), 0.18)                           # 芯の閃光（一瞬）
	pop("light_01", wp, 2.4, raw(GOLD, GLOW_RAW) * Color(1, 1, 1, 0.5), 0.3)       # にじみ
	burst(["fire_01", "flame_02"], wp, 10, [GOLD, Color(1.0, 0.5, 0.15)], Vector2(1.2, 3.2), 0.45, Vector2(0.35, 0.7), 5.0, 0.6, false, 90.0, Color(1.0, 0.25, 0.1))
	burst(["spark_01", "magic_02"], wp, 14, [GOLD, Color(1.0, 0.85, 0.5)], Vector2(1.5, 4.5), 1.1, Vector2(0.06, 0.16), 3.0, 0.9, false, 0.0, Color(1.0, 0.3, 0.1))   # 残り火（余韻）
	if fx3d:
		for k in 3:   # 煙：暗い紫灰、上へ昇って広がる（普通の合成）
			fx3d.tex_quad(["smoke_04", "smoke_07"][k % 2], foot + Vector3(randf_range(-0.3, 0.3), 0.7 + k * 0.25, -0.05), 1.1,
				{"add": false, "col": Color(0.13, 0.11, 0.17, 0.75), "size": 0.9 + k * 0.2, "grow": 1.9, "rise": 0.8, "spin": randf_range(-1.0, 1.0), "fade_in": 0.1})
		fx3d.tex_quad(["scorch_01", "scorch_02"][randi() % 2], foot, 1.8, {"floor": true, "add": false, "col": Color(0.05, 0.03, 0.04, 0.7), "size": 1.4, "grow": 1.1, "fade_in": 0.05})
		fx3d.tex_quad("light_01", foot, 0.5, {"floor": true, "add": true, "col": GOLD, "raw": 1.3, "size": 2.2, "grow": 1.4})

## 拾った：取得の輪（金）
func pickup(wp: Vector3) -> void:
	spawn(PICK, wp, 0.9, raw(GOLD), 0.0)

## 大技の決め：撃破と同じ層で大きく（REEBO の爆発はやめた）。col＝金（ラナ）／銀（リリィ）
func big(wp: Vector3, col: Color, fx3d = null, foot: Vector3 = Vector3.ZERO) -> void:
	pop("flare_01", wp, 3.0, raw(col, CORE_RAW), 0.22)
	pop("light_01", wp, 4.2, raw(col, GLOW_RAW) * Color(1, 1, 1, 0.5), 0.4)
	burst(["light_01", "spark_05"], wp, 24, [col, Color(1, 1, 1)], Vector2(4.0, 10.0), 0.6, Vector2(0.12, 0.35), 10.0, 0.0, false, 0.0, col)
	burst(["spark_01"], wp, 16, [col, Color(1, 0.9, 0.6)], Vector2(1.5, 4.0), 1.2, Vector2(0.06, 0.14), 3.0, 0.9, false, 0.0, Color(1.0, 0.3, 0.1))
	if fx3d:
		fx3d.tex_quad("light_01", foot, 0.6, {"floor": true, "add": true, "col": col, "raw": 1.3, "size": 3.5, "grow": 1.6})
		fx3d.tex_quad("scorch_02", foot, 2.0, {"floor": true, "add": false, "col": Color(0.05, 0.03, 0.04, 0.6), "size": 2.4, "fade_in": 0.05})
