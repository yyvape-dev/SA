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
const BOOM := "explosion_small"
const PICK := "coin_pickup"
var books := {}          # 名前 -> {tex, frames, fps, cols, rows, cell, scale}
const KP := "res://addons/kenney_particle_pack/"
const GLOW_RAW := 1.3
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
		tex[name] = load(KP + ("rotated/" if name.ends_with("_rotated") else "") + name + ".png")
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
	if not enabled or cam == null or cam.is_position_behind(wp):
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

## Kenney の粒を撒く（CPUParticles2D、加算。iPhone で確実に動く方を使う）。names＝使う絵（粒ごとにどれか）、n＝数、spd_m＝出る速さ（m/秒）、damp＝減速、size_m＝粒の大きさ
func burst(names: Array, wp: Vector3, n: int, cols: Array, spd_m: Vector2, life: float, size_m: Vector2, damp: float = 6.0, up: float = 0.0, align: bool = false, spin: float = 0.0) -> void:
	if not enabled or cam == null or cam.is_position_behind(wp):
		return
	var ppm := px_per_m(wp)
	var per := maxi(1, n / names.size())
	for k in names.size():
		var t := _tex(String(names[k]))
		var p := CPUParticles2D.new()
		p.texture = t
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = spd_m.x * ppm
		p.initial_velocity_max = spd_m.y * ppm
		p.damping_min = damp * ppm * 0.7
		p.damping_max = damp * ppm * 1.3
		p.gravity = Vector2(0, -up * ppm)
		var px: float = float(t.get_width())
		p.scale_amount_min = size_m.x * ppm / px
		p.scale_amount_max = size_m.y * ppm / px
		var sc := Curve.new()
		sc.add_point(Vector2(0, 1))
		sc.add_point(Vector2(1, 0.15))
		p.scale_amount_curve = sc
		var g := Gradient.new()   # 粒ごとの色（混ぜない階段）
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		var offs := PackedFloat32Array()
		var cs := PackedColorArray()
		for j in cols.size():
			offs.append(float(j) / cols.size())
			cs.append(cols[j])
		g.offsets = offs
		g.colors = cs
		p.color_initial_ramp = g
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
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
		p.one_shot = true
		p.explosiveness = 1.0
		p.randomness = 0.5
		p.local_coords = false
		_track(p, wp, life + 0.2)
		p.emitting = true

# ---------- SA2 の場面ごとの出し方（色は RAW＝GLOW_RAW 倍で光らせる） ----------
func raw(c: Color, k: float = GLOW_RAW) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## 当たり：火花の場面＋細い火花（Kenney spark/trace、飛ぶ向きへ伸びる）。strong は金で大きく
func hit(wp: Vector3, dir: int, strong: bool, pal: String = "blue") -> void:
	var c: Color = GOLD if strong else (SILVER if pal == "silver" else BLUE)
	spawn(HIT, wp, 0.9 if strong else 0.6, raw(c), 0.0, dir < 0, 1.25)
	burst(["spark_05", "trace_01"], wp, 14 if strong else 8, [raw(c), raw(Color(1, 1, 1))], Vector2(4.0, 9.0), 0.35, Vector2(0.18, 0.4), 14.0, 0.0, false, 0.0)

## 振りの弧：REEBO の斬撃（三日月）を、技の向きに合わせて重ねる。angle は画面での向き
func slash(wp: Vector3, face: int, size_m: float, angle: float, col: Color = BLUE) -> void:
	spawn(SLASH, wp, size_m, raw(col), angle if face > 0 else -angle, face < 0, 1.3)

## 撃破：小さな爆発（金）＋金の残り火
func kill(wp: Vector3) -> void:
	spawn(BOOM, wp, 0.8, raw(GOLD, 1.2), 0.0, false, 1.3)
	burst(["magic_02", "spark_01"], wp, 12, [raw(GOLD), raw(Color(1, 0.9, 0.6))], Vector2(1.5, 4.0), 0.8, Vector2(0.12, 0.3), 4.0, 0.8)

## 拾った：取得の輪（金）
func pickup(wp: Vector3) -> void:
	spawn(PICK, wp, 0.9, raw(GOLD), 0.0)

## 大技の決め：大きな爆発＋光の粒（Kenney light/flare）
func big(wp: Vector3, col: Color) -> void:
	spawn(BOOM, wp, 1.6, raw(col, 1.4), 0.0, false, 1.0)
	burst(["light_01", "flare_01", "spark_05"], wp, 30, [raw(col), raw(Color(1, 1, 1))], Vector2(4.0, 11.0), 0.6, Vector2(0.2, 0.55), 10.0, 0.0, false)

## 金の渦（技）：Kenney の渦巻き（twirl）を回し、床の楕円につぶして（親でつぶし、子を回す）縮めながら薄れる。who に付いていく
func twirl(who: Node3D, r_m: float, life: float, col: Color) -> void:
	if not enabled or cam == null:
		return
	for k in 2:
		var box := Node2D.new()
		var s := Sprite2D.new()
		s.texture = _tex("twirl_0%d" % (2 + k))
		var cm := CanvasItemMaterial.new()
		cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = cm
		s.modulate = raw(col, 1.2 if k == 0 else 0.9)
		box.add_child(s)
		root2d.add_child(box)
		items.append({"node": box, "spr": s, "wp": who.position, "life": life, "t": 0.0, "who": who, "spin": 520.0 if k == 0 else -380.0, "r": r_m * (1.0 if k == 0 else 0.7), "kind": "twirl"})

func _physics_process(delta: float) -> void:
	for it in items:
		if it.get("kind", "") == "twirl" and is_instance_valid(it.node) and is_instance_valid(it.who):
			it.wp = it.who.position + Vector3(0, 0.05, 0)
			var k: float = clampf(it.t / it.life, 0.0, 1.0)
			var px: float = px_per_m(it.wp) * float(it.r) * 2.0 * (1.0 - 0.5 * k) / float(it.spr.texture.get_width())
			it.node.scale = Vector2(px, px * 0.42)   # 床の楕円（奥行きにつぶす）
			it.spr.rotation_degrees += float(it.spin) * delta
			it.spr.modulate.a = 1.0 - k * k
