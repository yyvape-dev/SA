extends Node3D
## 戦闘のエフェクト（絵を使わず、コードで描く）。色：青＝味方（ラナの通常攻撃）、赤＝敵、金＝強い当たり・撃破。
## 斬撃の帯（縦の弧／床と平行な横の弧）、当たりの光・切り口・火花、撃破の煙と火花、ダメージの数字、敵の攻撃の床の予兆。

const SH := preload("res://scripts/fx_add.gdshader")
const SH_DARK := preload("res://scripts/fx_dark.gdshader")
const BLUE := [Color8(70, 145, 255), Color8(135, 195, 255), Color8(255, 255, 255)]
const GOLD := [Color8(255, 150, 40), Color8(255, 210, 110), Color8(255, 250, 225)]
const RED := [Color8(200, 20, 30), Color8(255, 70, 60), Color8(255, 210, 200)]

var cam: Camera3D
var items := []          # {node, t, life, kind, ...}
var sparks := []         # {p, v, t, life, w, c}
var spark_mesh: ImmediateMesh
var spark_mi: MeshInstance3D

func _ready() -> void:
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
	for i in 10:
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
		_spark(p, out * randf_range(2.0, 6.0) + Vector3(0, randf_range(-0.5, 1.5), 0), randf_range(0.12, 0.3), 0.018, pal[1].lerp(pal[2], 0.5), 0.05 + u * 0.08)

# ---------- 当たり ----------
func hit(p: Vector3, dir: int, strong: bool, lead: bool) -> void:
	var pal: Array = BLUE
	var n := (9 if strong else 6) if lead else 3
	for i in n:
		var a := randf_range(-0.8, 0.8) - 0.25
		var v := Vector3(dir * cos(a), sin(a) + 0.4, randf_range(-0.4, 0.4)) * randf_range(3.0, 9.0)
		var c: Color = pal[1] if i % 3 else Color8(255, 236, 190)
		_spark(p, v, randf_range(0.15, 0.4), 0.032 if strong else 0.024, c, 0.0)
	if not lead:
		return
	var sz := 1.7 if strong else 1.25
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
