extends Node3D
## 戦闘のエフェクト（絵を使わず、コードで描く）。色：青＝味方（ラナの通常攻撃）、赤＝敵、金＝強い当たり・撃破。
## 斬撃の帯（縦の弧／床と平行な横の弧）、当たりの光・切り口・火花、撃破の煙と火花、ダメージの数字、敵の攻撃の床の予兆。

const SH := preload("res://scripts/fx_add.gdshader")
const SH_DARK := preload("res://scripts/fx_dark.gdshader")
const BLUE := [Color8(70, 145, 255), Color8(135, 195, 255), Color8(255, 255, 255)]
const GOLD := [Color8(255, 150, 40), Color8(255, 210, 110), Color8(255, 250, 225)]
## リリィ（2026-11-06、specs/lily_attack_fx.md）：芯＝白・本体＝白銀・外のにじみ＝蒼。縁にごく淡い紫
const SILVER := [Color8(79, 184, 255), Color8(216, 228, 240), Color8(255, 255, 255)]
const BOLT_BLUE := Color8(79, 184, 255)
const BOLT_VIOLET := Color8(154, 140, 255)
const RED := [Color8(200, 20, 30), Color8(255, 70, 60), Color8(255, 210, 200)]

var cam: Camera3D
var items := []          # {node, t, life, kind, ...}
var sparks := []         # {p, v, t, life, w, c}
var spark_mesh: ImmediateMesh
var spark_mi: MeshInstance3D
var noise_tex: Texture2D        # 継ぎ目の無いノイズ（斬撃の模様・撃破の溶け消えに使う）
var screen_mat: ShaderMaterial  # 画面の仕上げ（vignette.gdshader）。衝撃波のゆがみを入れる
var waves := []                 # 衝撃波 {p, t, life, str, r}
var legacy := OS.has_environment("FX_OLD")   # 比較の撮影用：2026-11-06 より前の見た目（模様・ゆがみ・溶け消え無し）

func _ready() -> void:
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 3
	fn.seed = 7
	noise_tex = ImageTexture.create_from_image(fn.get_seamless_image(256, 256))
	spark_mesh = ImmediateMesh.new()
	spark_mi = MeshInstance3D.new()
	spark_mi.mesh = spark_mesh
	spark_mi.material_override = _mat(2)
	spark_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark_mi.extra_cull_margin = 1000.0
	add_child(spark_mi)

func _mat(mode: int, pal: Array = BLUE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("col_glow", pal[0])
	m.set_shader_parameter("col_main", pal[1])
	m.set_shader_parameter("col_core", pal[2])
	return m

func _dark(mode: int, strength: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SH_DARK
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("strength", strength)
	return m

# ---------- 斬撃の帯 ----------
## 弧の帯のメッシュ。plane "v"＝画面に立つ縦の弧（XY）、"h"＝床と平行な横の弧（XZ）。
## 角度は face=+1 のときの向き（0＝前、+90°＝上／奥）。太さは中央で最大、両端で細る。
func _arc_mesh(r: float, w: float, a0: float, a1: float, plane: String, face: int, squash: float) -> ArrayMesh:
	var n := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in n + 1:
		var u := float(i) / n
		var a := deg_to_rad(lerpf(a0, a1, u))
		var th := w * pow(sin(PI * clampf(u * 0.92 + 0.08, 0.0, 1.0)), 0.6)
		var ro := r
		var ri := r - th
		var o: Vector3
		var ii: Vector3
		if plane == "v":
			o = Vector3(cos(a) * ro * face, sin(a) * ro, 0)
			ii = Vector3(cos(a) * ri * face, sin(a) * ri, 0)
		else:
			o = Vector3(cos(a) * ro * face, 0, -sin(a) * ro * squash)
			ii = Vector3(cos(a) * ri * face, 0, -sin(a) * ri * squash)
		pts.append([o, ii, u])
	for i in n:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		for q in [[p0[0], p0[2], 0.0], [p1[0], p1[2], 0.0], [p1[1], p1[2], 1.0], [p0[0], p0[2], 0.0], [p1[1], p1[2], 1.0], [p0[1], p0[2], 1.0]]:
			st.set_uv(Vector2(q[1], q[2]))
			st.add_vertex(q[0])
	return st.commit()

## spec：{plane, r, w, a0, a1, y, life, pal, squash, tilt}
func slash(origin: Vector3, face: int, spec: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh(spec.r, spec.w, spec.a0, spec.a1, spec.plane, face, spec.get("squash", 1.0))
	var pal: Array = spec.get("pal", BLUE)
	mi.material_override = _mat(0, pal)
	mi.material_override.set_shader_parameter("noise", noise_tex)   # 流れる模様（2026-11-06）
	mi.material_override.set_shader_parameter("n_amt", 0.0 if legacy else spec.get("noise", 1.0))
	mi.material_override.set_shader_parameter("seed", randf() * 10.0)
	mi.sorting_offset = 0.05
	# 暗い下地：少し太く、少し外側まで
	var dk := MeshInstance3D.new()
	dk.mesh = _arc_mesh(spec.r + spec.w * 0.15, spec.w * 1.8, spec.a0, spec.a1, spec.plane, face, spec.get("squash", 1.0))
	dk.material_override = _dark(0, 0.8)   # 塗った絵の上でも帯が埋もれないよう濃く・太く（2026-11-05）
	dk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dk.position = Vector3(0, 0, -0.02)
	mi.add_child(dk)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = origin + Vector3(0, spec.y, 0.12)
	if spec.plane == "h":
		mi.rotation.x = deg_to_rad(spec.get("lift", 32.0))   # 奥側を起こす（カメラが低いので、床と平行のままだと細い線に見える）
	if spec.has("tilt"):
		mi.rotation.z = deg_to_rad(spec.tilt) * face
	add_child(mi)
	items.append({"node": mi, "t": 0.0, "life": spec.get("life", 0.22), "kind": "slash", "draw": spec.get("draw", 0.07)})
	# 弧に沿って、外側へ飛ぶ細かい粒（刃の先から散る光）
	for i in 22:
		var u := randf()
		var a := deg_to_rad(lerpf(spec.a0, spec.a1, u))
		var p: Vector3
		var out: Vector3
		if spec.plane == "v":
			out = Vector3(cos(a) * face, sin(a), 0)
		else:
			out = Vector3(cos(a) * face, 0, -sin(a) * spec.get("squash", 1.0))
		p = mi.position + mi.basis * (out * spec.r)
		out = mi.basis * out
		_spark(p, out * randf_range(3.0, 9.0) + Vector3(0, randf_range(-0.5, 1.5), 0), randf_range(0.15, 0.38), 0.024, pal[1].lerp(pal[2], 0.5), 0.05 + u * 0.08)

# ---------- 衝撃波（画面のゆがみ） ----------
## 世界の位置 p から輪が広がる。str＝強さ（0.5〜1.5）、r＝最大の半径（画面の高さに対する割合）。同時に4つまで。
func shockwave(p: Vector3, str: float = 1.0, life: float = 0.42, r: float = 0.55) -> void:
	if legacy:
		return
	if waves.size() >= 4:
		waves.pop_front()
	waves.append({"p": p, "t": 0.0, "life": life, "str": str, "r": r})

func _update_waves(delta: float) -> void:
	if screen_mat == null:
		return
	var vp := get_viewport().get_visible_rect().size
	screen_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	var arr := []
	for i in range(waves.size() - 1, -1, -1):
		waves[i].t += delta
		if waves[i].t >= waves[i].life:
			waves.remove_at(i)
	for w in waves:
		var k: float = w.t / w.life
		var sp: Vector2 = cam.unproject_position(w.p) / vp if cam else Vector2(0.5, 0.5)
		var e := 1.0 - pow(1.0 - k, 2.5)       # 速く広がり、ゆっくり止まる
		arr.append(Vector4(sp.x, sp.y, w.r * e, w.str * (1.0 - k) * (1.0 - k)))
	while arr.size() < 4:
		arr.append(Vector4(0, 0, 0, 0))
	screen_mat.set_shader_parameter("wave", PackedVector4Array(arr))

# ---------- 当たり ----------
func hit(p: Vector3, dir: int, strong: bool, lead: bool) -> void:
	var pal: Array = BLUE
	var n := (16 if strong else 10) if lead else 5
	for i in n:
		var a := randf_range(-0.8, 0.8) - 0.25
		var v := Vector3(dir * cos(a), sin(a) + 0.4, randf_range(-0.4, 0.4)) * randf_range(3.0, 9.0)
		var c: Color = pal[1] if i % 3 else Color8(255, 236, 190)
		_spark(p, v * 1.3, randf_range(0.18, 0.45), 0.04 if strong else 0.03, c, 0.0)
	if not lead:
		return
	var sz := 2.5 if strong else 1.8
	_quad(p + Vector3(0, 0, 0.15), Vector2(sz * 1.2, sz * 1.2), _dark(1, 0.35), "flash", 0.12, 0.0)
	var fm := _mat(1, pal)
	fm.set_shader_parameter("core_gain", 0.7)   # 光の中心を弱める（白く飛ばない）
	_quad(p + Vector3(0, 0, 0.2), Vector2(sz, sz), fm, "flash", 0.1, 0.0)
	# 切り口：細長いひし形が一瞬で伸びて細る
	var cut := MeshInstance3D.new()
	cut.mesh = _diamond()
	cut.material_override = _mat(1, pal)
	cut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cut.position = p + Vector3(0, 0, 0.25)
	cut.rotation.z = (-0.5 + randf() * 0.35) * dir
	add_child(cut)
	items.append({"node": cut, "t": 0.0, "life": 0.14, "kind": "cut", "len": sz * 1.3})
	if strong:   # 強い当たり：床に青い輪が広がる
		var ring := MeshInstance3D.new()
		ring.mesh = _arc_mesh(1.0, 0.2, -180, 180, "h", 1, 0.55)
		ring.material_override = _mat(0, pal)
		ring.material_override.set_shader_parameter("head", 1.3)
		ring.material_override.set_shader_parameter("tail", 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = Vector3(p.x, 0.05, p.z)
		add_child(ring)
		items.append({"node": ring, "t": 0.0, "life": 0.32, "kind": "ring"})

func _diamond() -> ArrayMesh:
	# 中心を UV(0.5,0.5)（いちばん明るい）にした、4つの三角形のひし形
	var v := [Vector3(-0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0.5, 0, 0), Vector3(0, -0.5, 0)]
	var uv := [Vector2(0.0, 0.5), Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var j := (i + 1) % 4
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(Vector3.ZERO)
		st.set_uv(uv[i]); st.add_vertex(v[i])
		st.set_uv(uv[j]); st.add_vertex(v[j])
	return st.commit()

func _quad(p: Vector3, size: Vector2, m: ShaderMaterial, kind: String, life: float, delay: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	m.set_shader_parameter("billboard", true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = p
	mi.scale = Vector3(size.x, size.y, 1)
	add_child(mi)
	items.append({"node": mi, "t": -delay, "life": life, "kind": kind, "size": size})
	return mi

# ---------- 撃破 ----------
func kill(p: Vector3, dir: int, h: float) -> void:
	_quad(p + Vector3(0, h * 0.5, 0.2), Vector2(h * 1.1, h * 1.1), _mat(1, GOLD), "flash", 0.16, 0.0)
	for i in 12:
		var a := randf_range(-1.2, 1.2)
		var v := Vector3(dir * cos(a) * 0.8 + randf_range(-0.3, 0.3), sin(a) * 0.6 + 0.7, randf_range(-0.5, 0.5)) * randf_range(3.0, 8.0)
		_spark(p + Vector3(0, h * randf_range(0.3, 0.7), 0), v, randf_range(0.3, 0.6), 0.024, GOLD[1] if i % 2 else RED[1], 0.0)
	# 床の衝撃の輪（横の弧を1周）
	var ring := MeshInstance3D.new()
	ring.mesh = _arc_mesh(1.0, 0.22, -180, 180, "h", 1, 0.55)
	ring.material_override = _mat(0, GOLD)
	ring.material_override.set_shader_parameter("head", 1.3)
	ring.material_override.set_shader_parameter("tail", 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = p + Vector3(0, 0.05, 0)
	add_child(ring)
	items.append({"node": ring, "t": 0.0, "life": 0.35, "kind": "ring"})

## 撃破の溶け消えから昇る火の粉（金）
func ember(p: Vector3) -> void:
	_spark(p, Vector3(randf_range(-0.6, 0.6), randf_range(1.2, 2.8), 0), randf_range(0.35, 0.7), 0.03, GOLD[1].lerp(GOLD[2], randf()), 0.0)

# ---------- 被弾（ラナ） ----------
func hurt(p: Vector3, dir: int) -> void:
	_quad(p + Vector3(0, 0, 0.2), Vector2(1.3, 1.3), _mat(1, RED), "flash", 0.12, 0.0)
	for i in 7:
		var a := randf_range(-0.9, 0.9)
		_spark(p, Vector3(dir * cos(a), sin(a) + 0.3, 0) * randf_range(3.0, 7.0), randf_range(0.15, 0.35), 0.02, RED[1], 0.0)

# ---------- 敵の攻撃の予兆（床の赤い枠。当たりの瞬間まで中が満ちる） ----------
func warn(center: Vector3, size: Vector2, life: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _mat(3, RED)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center + Vector3(0, 0.03, 0)
	add_child(mi)
	items.append({"node": mi, "t": 0.0, "life": life, "kind": "warn"})
	return mi

# ---------- 数字 ----------
func number(p: Vector3, val: int, kind: String) -> void:
	var l := Label3D.new()
	l.text = str(val)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0062
	l.font_size = 64 if kind != "strong" else 86
	l.outline_size = 22
	l.outline_modulate = Color(0, 0, 0, 0.85)
	match kind:
		"strong": l.modulate = Color8(255, 236, 165)
		"hurt": l.modulate = Color8(255, 107, 107)
		_: l.modulate = Color(1, 1, 1)
	# 同じ所に続けて出た数字は、少しずつ上へずらして重ならないように
	var lift := 0.0
	for it in items:
		if it.kind == "num" and it.t < 0.25 and absf(it.node.position.x - p.x) < 0.5:
			lift += 0.28
	l.position = p + Vector3(randf_range(-0.15, 0.15), lift, 0.3)
	l.render_priority = 10
	add_child(l)
	items.append({"node": l, "t": 0.0, "life": 0.6, "kind": "num", "y0": l.position.y})

# ---------- 火花 ----------
func _spark(p: Vector3, v: Vector3, life: float, w: float, c: Color, delay: float) -> void:
	sparks.append({"p": p, "v": v, "t": -delay, "life": life, "w": w, "c": c})

func _process(delta: float) -> void:
	_update_waves(delta)
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		it.t += delta
		var node: Node3D = it.node
		if it.t < 0.0:
			node.visible = false
			continue
		node.visible = true
		var k: float = it.t / it.life
		if k >= 1.0:
			node.queue_free()
			items.remove_at(i)
			continue
		var m = node.get("material_override")
		match it.kind:
			"slash":
				# 先端が draw 秒で弧を走り、そのあと尾が追いついて消える
				var hd := clampf(it.t / it.draw, 0.0, 1.0)
				hd = 1.0 - pow(1.0 - hd, 2.0)
				var hv: float = hd * 1.0 + maxf(0.0, it.t - it.draw) / (it.life - it.draw) * 1.6
				m.set_shader_parameter("head", hv)
				m.set_shader_parameter("fade", 1.0 - pow(k, 3.0))
				var dm: ShaderMaterial = node.get_child(0).material_override
				dm.set_shader_parameter("head", hv)
				dm.set_shader_parameter("fade", 1.0 - pow(k, 2.0))
			"flash":
				var s: Vector2 = it.size * (0.6 + 0.6 * k)
				node.scale = Vector3(s.x, s.y, 1)
				m.set_shader_parameter("fade", 1.0 - k)
			"cut":
				var e := clampf(it.t / 0.05, 0.0, 1.0)
				var fd := 1.0 - maxf(0.0, it.t - 0.05) / 0.09
				node.scale = Vector3(it.len * (1.0 - pow(1.0 - e, 3.0)), 0.11 * fd + 0.015, 1)
				m.set_shader_parameter("fade", fd)
			"ring":
				var s2 := 0.4 + 1.6 * (1.0 - pow(1.0 - k, 2.0))
				node.scale = Vector3(s2, 1, s2)
				m.set_shader_parameter("fade", 1.0 - k)
			"warn":
				m.set_shader_parameter("fill", k)
				m.set_shader_parameter("fade", 0.6 + 0.4 * sin(it.t * 40.0) * 0.5 + k * 0.4)
			"bolt":   # 稲妻：明滅しながら消える
				m.set_shader_parameter("fade", (1.0 - k) * (1.0 if randf() > 0.35 else 0.25))
			"charge":   # 溜め：外から中心へ集まって濃くなる
				var sc2: float = it.size.x * lerpf(1.7, 0.35, k)
				node.scale = Vector3(sc2, sc2, 1)
				m.set_shader_parameter("fade", 0.3 + 0.9 * k)
			"dust":
				var e2 := 1.0 - pow(1.0 - k, 2.0)
				node.scale = Vector3.ONE * it.size.x * (0.5 + 0.9 * e2)
				node.position.y = it.y0 + 0.35 * e2
				m.albedo_color.a = 0.45 * (1.0 - k)
			"num":
				var up := 1.0 - pow(1.0 - minf(1.0, k * 2.5), 3.0)
				node.position.y = it.y0 + 0.35 * up + k * 0.15
				var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
				node.modulate.a = a
				node.outline_modulate.a = a * 0.85
				var sc := 1.0 + 0.5 * maxf(0.0, 1.0 - it.t / 0.08)
				node.scale = Vector3.ONE * sc
	_draw_sparks(delta)

## 予兆などを途中で消す（敵がひるんで攻撃が止まったとき）
func drop(node: Node3D) -> void:
	for i in items.size():
		if items[i].node == node:
			node.queue_free()
			items.remove_at(i)
			return

func _draw_sparks(delta: float) -> void:
	spark_mesh.clear_surfaces()
	if sparks.is_empty() or cam == null:
		return
	var cdir := -cam.global_transform.basis.z
	spark_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s.t += delta
		if s.t >= s.life:
			sparks.remove_at(i)
			continue
		if s.t < 0.0:
			continue
		var dr := exp(-delta * 5.0)
		s.v = s.v * dr + Vector3(0, -9.0 * delta, 0)
		s.p += s.v * delta
		var vl: float = s.v.length()
		var ln := minf(0.45, vl * 0.035) + 0.03
		var d: Vector3 = s.v / maxf(vl, 0.001)
		var p0: Vector3 = s.p
		var p1: Vector3 = s.p - d * ln
		var side: Vector3 = d.cross(cdir).normalized() * float(s.w)
		var c: Color = s.c
		c.a = 1.0 - s.t / s.life
		for q in [p0 + side, p0 - side, p1 - side * 0.3, p0 + side, p1 - side * 0.3, p1 + side * 0.3]:
			spark_mesh.surface_set_color(c)
			spark_mesh.surface_add_vertex(q)
		n += 1
	if n == 0:
		spark_mesh.surface_add_vertex(Vector3.ZERO)
		spark_mesh.surface_add_vertex(Vector3.ZERO)
		spark_mesh.surface_add_vertex(Vector3.ZERO)
	spark_mesh.surface_end()

# ---------- レベルが上がった（金の輪が足元から広がり、火の粉が昇る） ----------
func levelup(p: Vector3) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = _arc_mesh(1.2, 0.18, -180, 180, "h", 1, 0.55)
	ring.material_override = _mat(0, GOLD)
	ring.material_override.set_shader_parameter("head", 1.3)
	ring.material_override.set_shader_parameter("tail", 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = p + Vector3(0, 0.05, 0)
	add_child(ring)
	items.append({"node": ring, "t": 0.0, "life": 0.5, "kind": "ring"})
	for i in 16:
		var a := randf() * TAU
		_spark(p + Vector3(cos(a) * 0.6, 0.1, sin(a) * 0.4), Vector3(0, randf_range(2.5, 5.0), 0), randf_range(0.4, 0.8), 0.02, GOLD[1], i * 0.02)

# ---------- 土煙（ダウンで床に倒れたとき。元の動画の土煙は消してコードで描く） ----------
func dust(p: Vector3, w: float) -> void:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	for i in 7:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = gt
		m.albedo_color = Color(0.62, 0.58, 0.66, 0.45)   # 夜の路面の灰紫
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pos := p + Vector3(randf_range(-w, w) * 0.6, 0.25, randf_range(-0.3, 0.3))
		mi.position = pos
		add_child(mi)
		var sz := randf_range(0.7, 1.2)
		items.append({"node": mi, "t": -i * 0.03, "life": randf_range(0.5, 0.8), "kind": "dust", "size": Vector2(sz, sz), "y0": pos.y})


# ---------- リリィの軌跡（2026-11-06、specs/lily_attack_fx.md） ----------
## 点の列（世界の座標）から、太さ付きの光の帯を作る。太さは中央で最大・両端で細る。帯の面は視線に向ける（画面に立つ）。
## spec：{w（最大の太さ m）, life, draw（先端が走る秒）, pal, bolts（縁の稲妻の本数）, dissolve（余韻で粒に散る）}
func ribbon(pts: Array, spec: Dictionary) -> void:
	if pts.size() < 2:
		return
	var pal: Array = spec.get("pal", SILVER)
	var w: float = spec.get("w", 0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = _strip(pts, w, 1.0)
	mi.material_override = _mat(0, pal)
	mi.material_override.set_shader_parameter("noise", noise_tex)
	mi.material_override.set_shader_parameter("n_amt", spec.get("noise", 0.5))
	mi.material_override.set_shader_parameter("seed", randf() * 10.0)
	mi.material_override.set_shader_parameter("tail", spec.get("tail", 2.2))   # 尾を長く（余韻）
	var dk := MeshInstance3D.new()
	dk.mesh = _strip(pts, w * 1.9, 1.0)
	dk.material_override = _dark(0, 0.85)
	dk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dk.position = Vector3(0, 0, -0.03)
	mi.add_child(dk)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 0.06
	add_child(mi)
	var life: float = spec.get("life", 0.42)
	items.append({"node": mi, "t": 0.0, "life": life, "kind": "slash", "draw": spec.get("draw", 0.06)})
	# 縁の稲妻のひび（外側の縁に沿って、細い折れ線）
	for b in spec.get("bolts", 2):
		var a: int = randi_range(0, maxi(0, pts.size() - 3))
		var e: int = mini(pts.size() - 1, a + randi_range(2, 4))
		var path := []
		for j in range(a, e + 1):
			path.append(pts[j] + Vector3(0, 0, 0.05))
		bolt(path, 0.035, BOLT_BLUE if b % 3 != 2 else BOLT_VIOLET, life * 0.8, 0.02 + b * 0.03, 0.12)
	# 余韻：帯が稲妻の粒になって散る（すぐ消さない）
	if spec.get("dissolve", true):
		for j in pts.size() * 3:
			var u := randf()
			var q: Vector3 = _along(pts, u)
			var v := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.2), randf_range(-0.4, 0.4)) * randf_range(0.6, 2.2)
			_spark(q, v, randf_range(0.25, 0.5), 0.02, pal[1] if j % 3 else pal[0], life * randf_range(0.35, 0.7))

func _along(pts: Array, u: float) -> Vector3:
	var f := u * (pts.size() - 1)
	var i := clampi(int(f), 0, pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)

## 帯のメッシュ：UV.x＝始め→終わり、UV.y＝外の縁 0 → 内 1（mode 0 と同じ）。外＝曲がりの外側
func _strip(pts: Array, w: float, taper: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var o := []
	var ii := []
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= n
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
		tg.z = 0.0
		tg = tg.normalized() if tg.length() > 0.0001 else Vector3.RIGHT
		var nm := Vector3(-tg.y, tg.x, 0)
		if nm.dot(p - center) < 0.0:
			nm = -nm   # 外側へ
		var u := float(i) / (n - 1)
		var th := w * pow(sin(PI * clampf(u * 0.9 + 0.1, 0.0, 1.0)), 0.6 * taper)
		o.append([p + nm * th * 0.5, u])
		ii.append([p - nm * th * 0.5, u])
	for i in n - 1:
		for q in [[o[i], 0.0], [o[i + 1], 0.0], [ii[i + 1], 1.0], [o[i], 0.0], [ii[i + 1], 1.0], [ii[i], 1.0]]:
			st.set_uv(Vector2(q[0][1], q[1]))
			st.add_vertex(q[0][0])
	return st.commit()

## 稲妻：点の列を折れ線にゆがめた細い帯（加算、明滅）。delay 秒後に出る
func bolt(path: Array, w: float, col: Color, life: float, delay: float, jitter: float, on_floor: bool = false) -> void:
	var pts := []
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var segs := 3
		for k in segs:
			var q := a.lerp(b, float(k) / segs)
			if k > 0 or i > 0:
				q += (Vector3(randf_range(-1, 1), 0, randf_range(-0.6, 0.6)) if on_floor else Vector3(randf_range(-1, 1), randf_range(-1, 1), 0)) * jitter
			pts.append(q)
	pts.append(path[path.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := (b - a)
		var nm := Vector3(-d.y, d.x, 0).normalized() * w if absf(d.z) < absf(d.x) + absf(d.y) else Vector3(-d.z, 0, d.x).normalized() * w
		for v in [a + nm, b + nm, b - nm, a + nm, b - nm, a - nm]:
			st.set_color(col)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	items.append({"node": mi, "t": -delay, "life": life, "kind": "bolt"})

## 当たった所で稲妻が弾ける：短い折れ線の放射＋粒
func zap(p: Vector3, n: int, r: float) -> void:
	for i in n:
		var a := randf() * TAU
		var d := Vector3(cos(a), sin(a), 0)
		var len := r * randf_range(0.5, 1.0)
		bolt([p, p + d * len * 0.5, p + d * len], 0.03, BOLT_BLUE if i % 4 else BOLT_VIOLET, randf_range(0.14, 0.24), 0.0, 0.12)
	for i in 14:
		var a2 := randf() * TAU
		_spark(p, Vector3(cos(a2), sin(a2) + 0.3, randf_range(-0.3, 0.3)) * randf_range(3.0, 8.0), randf_range(0.15, 0.35), 0.026, SILVER[1] if i % 2 else SILVER[0], 0.0)
	_quad(p + Vector3(0, 0, 0.2), Vector2(1.6, 1.6), _mat(1, SILVER), "flash", 0.12, 0.0)

## 溜め：つま先に蒼い光が集まる（0.1〜0.15 秒）
func charge(p: Vector3, size: float, life: float) -> void:
	var m := _mat(1, SILVER)
	m.set_shader_parameter("core_gain", 0.9)
	_quad(p + Vector3(0, 0, 0.15), Vector2(size, size), m, "charge", life, 0.0)
	for i in 6:
		var a := randf() * TAU
		var off := Vector3(cos(a), sin(a), 0) * size * 0.8
		_spark(p + off, -off / life, life, 0.02, SILVER[0], 0.0)

## 床を走る稲妻（かかと落としの着地）：中心から放射状に、床に寝かせた折れ線
func floor_bolts(p: Vector3, n: int, r: float) -> void:
	for i in n:
		var a := (float(i) + randf_range(-0.3, 0.3)) / n * TAU
		var d := Vector3(cos(a), 0, sin(a) * 0.6)
		var path := [p + Vector3(0, 0.03, 0)]
		for k in 3:
			path.append(p + d * r * float(k + 1) / 3.0 * randf_range(0.8, 1.1) + Vector3(0, 0.03, 0))
		bolt(path, 0.045, BOLT_BLUE if i % 3 else BOLT_VIOLET, randf_range(0.3, 0.45), randf_range(0.0, 0.05), 0.18, true)
