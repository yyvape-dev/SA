extends Node3D
## ランカのエフェクト（2026-11-12）。色はユーザー決定「青・白・朱色の花・金」。
## リリィ（白銀＋蒼い稲妻）と見分けるため、ランカは稲妻を使わず、なめらかな蒼白の気の帯・輪・光に、朱色の花びらと金の粒を添える。
## 共通の部品（帯・閃光・火花・衝撃波・床の板）は fx.gd を使う。ここは花びら・気弾・円環・星の雨・夜空だけ。

const BLUE := [Color8(52, 110, 255), Color8(165, 205, 255), Color8(255, 255, 255)]   # 気（外のにじみ → 本体 → 芯）
const GOLD := [Color8(255, 150, 40), Color8(255, 210, 110), Color8(255, 250, 225)]
const VERMILION := Color8(236, 74, 40)    # 朱色
const PETAL_COLS := [Color8(236, 74, 40), Color8(246, 112, 70), Color8(255, 168, 140), Color8(255, 236, 228), Color8(255, 196, 90)]

var fx            # fx.gd
var world         # battle.gd
var petal_tex: Texture2D
var petals := []  # {node, v, t, life, spin, sway, ph, drag}
var orbs := []    # 気弾 {node, a, b, t, life}

func _ready() -> void:
	petal_tex = _make_petal()

## 花びらの絵（コードで作る 64px。中心が白く縁が朱、先に切れ込み）。色は modulate で変える
func _make_petal() -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / n * 2.0 - 1.0      # −1〜1（横）
			var v := (float(y) + 0.5) / n                   # 0（根元）〜1（先）
			var half := sin(clampf(v, 0.0, 1.0) * PI) * 0.62 * (0.55 + 0.45 * v)   # しずく形
			var notch := 0.0
			if v > 0.82:
				notch = maxf(0.0, 0.16 - absf(u)) * (v - 0.82) / 0.18 * 6.0         # 先の切れ込み
			var inside := absf(u) < half and notch < 0.5
			if not inside:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := clampf((half - absf(u)) / 0.12, 0.0, 1.0)
			var w := clampf(1.0 - v * 1.1 + 0.25 - absf(u) * 0.6, 0.0, 1.0)        # 根元ほど白
			var c := Color(1, 1, 1).lerp(Color(1.0, 0.55, 0.45), 1.0 - w)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, edge))
	return ImageTexture.create_from_image(img)

# ---------- 花びら ----------
## p から花びらを n 枚。o：spd（外への速さ m/秒）・up（上向き）・life・size（m）・spread（出る場所のばらつき m）・cols
func petals_burst(p: Vector3, n: int, o: Dictionary = {}) -> void:
	var spd: Vector2 = o.get("spd", Vector2(2.0, 5.0))
	var cols: Array = o.get("cols", PETAL_COLS)
	var spread: Vector3 = o.get("spread", Vector3(0.3, 0.3, 0.3))
	for i in n:
		var a := randf() * TAU
		var dir := Vector3(cos(a), sin(a) * 0.7 + float(o.get("up", 0.5)), randf_range(-0.6, 0.6)).normalized()
		var q := p + Vector3(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y), randf_range(-spread.z, spread.z))
		_petal(q, dir * randf_range(spd.x, spd.y), randf_range(0.9, 1.7) * float(o.get("life", 1.0)), float(o.get("size", 0.16)) * randf_range(0.7, 1.3), cols[randi() % cols.size()], float(o.get("delay", 0.0)) * randf())

## 画面の上から舞い落ちる花びら（必殺技の余韻）。cx を中心に幅 w m
func petals_rain(cx: float, w: float, n: int, life: float = 2.4) -> void:
	for i in n:
		var q := Vector3(cx + randf_range(-w, w), randf_range(3.0, 6.5), randf_range(-3.0, 3.0))
		_petal(q, Vector3(randf_range(-0.8, 0.8), randf_range(-1.6, -0.6), randf_range(-0.3, 0.3)), life * randf_range(0.7, 1.2), randf_range(0.12, 0.22), PETAL_COLS[randi() % PETAL_COLS.size()], randf() * 0.9)

func _petal(p: Vector3, v: Vector3, life: float, size: float, col: Color, delay: float) -> void:
	var s := Sprite3D.new()
	s.texture = petal_tex
	s.pixel_size = size / 64.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.modulate = Color(col.r * 1.25, col.g * 1.25, col.b * 1.25, 0.0)   # 夜の画面で沈まないよう少し明るく
	s.position = p
	s.visible = delay <= 0.0
	add_child(s)
	petals.append({"node": s, "v": v, "t": -delay, "life": life, "spin": randf_range(-9.0, 9.0), "sway": randf_range(0.6, 1.4), "ph": randf() * TAU, "col": col})

# ---------- 気弾（指弾） ----------
## a から b へ光の玉が飛び、通った後に蒼白の帯が残る。big で太く、通り道に朱の花びら
func ki_shot(a: Vector3, b: Vector3, big: bool) -> void:
	var life := 0.16 if not big else 0.22
	fx.ribbon([a, a.lerp(b, 0.5) + Vector3(0, 0.03, 0), b], {"w": 0.22 if not big else 0.5, "life": 0.3 if not big else 0.45, "draw": life, "bolts": 0, "pal": BLUE, "noise": 0.25, "tail": 1.6})
	var m: ShaderMaterial = fx._mat(1, BLUE)
	m.set_shader_parameter("core_gain", 1.0)
	var orb: MeshInstance3D = fx._quad(a + Vector3(0, 0, 0.18), Vector2(0.9, 0.9) * (1.6 if big else 1.0), m, "flash", life + 0.06, 0.0)
	orbs.append({"node": orb, "a": a + Vector3(0, 0, 0.18), "b": b + Vector3(0, 0, 0.18), "t": 0.0, "life": life})
	fx._quad(a + Vector3(0, 0, 0.2), Vector2(1.2, 1.2) * (1.5 if big else 1.0), fx._mat(1, BLUE), "flash", 0.12, 0.0)   # 指先の閃光
	if big:
		petals_burst(a.lerp(b, 0.3), 10, {"spd": Vector2(1.0, 3.0), "spread": Vector3(2.0, 0.2, 0.3), "size": 0.14})
		fx._quad(b + Vector3(0, 0, 0.2), Vector2(2.2, 2.2), fx._mat(1, GOLD), "flash", 0.18, life)

# ---------- 円環 ----------
## 足元から外へ広がる輪（床と平行、2重）。r＝届く半径、n＝何回目（色と太さを少しずつ変える）
func ring(p: Vector3, r: float, n: int, final: bool = false) -> void:
	var k_list := [[0.5, 0.42 if not final else 0.8], [0.4, 0.16 if not final else 0.34]]
	for k in k_list.size():
		var mi := MeshInstance3D.new()
		mi.mesh = fx._arc_mesh(r * float(k_list[k][0]), float(k_list[k][1]), -180, 180, "h", 1, 0.6)
		var pal: Array = BLUE if (k == 0 or not final) else GOLD
		mi.material_override = fx._mat(0, pal)
		mi.material_override.set_shader_parameter("head", 1.3)
		mi.material_override.set_shader_parameter("tail", 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(0, 0.05 + k * 0.03, 0)
		fx.add_child(mi)
		fx.items.append({"node": mi, "t": 0.0, "life": (0.36 if not final else 0.5) + k * 0.08, "kind": "ring"})
	# 立ち上がる光の壁（輪の縁から上へ短い光の筋）
	for i in (10 if not final else 22):
		var a := randf() * TAU
		var q := p + Vector3(cos(a) * r * 0.82, 0.05, sin(a) * r * 0.5)
		fx._spark(q, Vector3(0, randf_range(3.0, 6.0), 0), randf_range(0.18, 0.32), 0.03, BLUE[1] if i % 3 else BLUE[2], 0.0)
	fx.tex_quad("circle_03", p, 0.4 if not final else 0.6, {"floor": true, "add": true, "col": BLUE[0], "raw": 1.4, "size": r * 1.1, "grow": 1.25, "erode_from": 0.1})
	if final:
		petals_burst(p + Vector3(0, 0.6, 0), 26, {"spd": Vector2(4.0, 8.0), "up": 0.3, "spread": Vector3(0.6, 0.4, 0.4)})
		for i in 24:
			var a2 := randf() * TAU
			fx._spark(p + Vector3(0, randf_range(0.3, 1.2), 0), Vector3(cos(a2) * randf_range(6, 11), randf_range(0.5, 3.0), sin(a2) * randf_range(3, 6)), randf_range(0.3, 0.55), 0.03, GOLD[1] if i % 2 else GOLD[2], 0.0)
		fx.shockwave(p + Vector3(0, 0.8, 0), 1.6, 0.5, 0.8)
	elif n % 2 == 0:
		petals_burst(p + Vector3(0, 0.3, 0), 4, {"spd": Vector2(2.5, 4.5), "up": 0.2, "spread": Vector3(r * 0.4, 0.1, 0.3)})

# ---------- 星震 ----------
## 夜空：空に瞬く星（止まった粒）を life 秒。cx を中心に幅 w m
func night_sky(cx: float, w: float, life: float) -> void:
	for i in 70:
		var q := Vector3(cx + randf_range(-w, w), randf_range(3.2, 7.5), randf_range(-6.0, -2.0))
		fx._spark(q, Vector3(0, 0.001, 0), life * randf_range(0.7, 1.0), randf_range(0.02, 0.05), BLUE[2] if i % 3 else GOLD[2], randf() * 0.3)

## 星の雨の1粒：空から g へ斜めに落ちる光の筋（蒼白、4つに1つは金）→ 当たった所で閃光と粒と小さな輪
func star(g: Vector3, delay: float, gold: bool = false) -> void:
	var top := g + Vector3(randf_range(1.5, 3.0), randf_range(6.5, 8.0), 0.1)
	var col: Color = GOLD[1] if gold else BLUE[1]
	fx.bolt([top, top.lerp(g, 0.5), g + Vector3(0, 0.05, 0.1)], 0.07, col, 0.24, delay, 0.015, false, 0)
	fx.bolt([top, g + Vector3(0, 0.05, 0.1)], 0.025, BLUE[2], 0.2, delay, 0.01, false, 0)
	fx._quad(g + Vector3(0, 0.4, 0.2), Vector2(1.8, 1.4), fx._mat(1, GOLD if gold else BLUE), "flash", 0.18, delay + 0.05)
	for i in 10:
		var a := randf() * TAU
		fx._spark(g + Vector3(0, 0.15, 0), Vector3(cos(a) * randf_range(2, 5), randf_range(2.0, 5.0), sin(a) * randf_range(1, 3)), randf_range(0.25, 0.45), 0.026, BLUE[1] if i % 2 else GOLD[2], delay + 0.05)

## 星震の柱（交差した腕が光る瞬間）：ランカから空へ光の柱と、扇に広がる光の筋
func quake_pillar(p: Vector3) -> void:
	var m: ShaderMaterial = fx._mat(1, BLUE)
	m.set_shader_parameter("core_gain", 0.4)
	fx._quad(p + Vector3(0, 3.2, 0.15), Vector2(1.3, 7.0), m, "flash", 0.5, 0.0)
	for i in 14:
		var ang := deg_to_rad(randf_range(20, 160))
		var d := Vector3(cos(ang), sin(ang), 0)
		var o := p + Vector3(0, 1.2, 0.15)
		fx.bolt([o, o + d * randf_range(2.0, 4.5)], 0.03, GOLD[1] if i % 3 == 0 else BLUE[1], 0.3, randf() * 0.08, 0.01, false, 0)
	fx._quad(p + Vector3(0, 1.0, 0.2), Vector2(3.4, 3.4), fx._mat(1, GOLD), "flash", 0.2, 0.0)

## 星震の締め：画面の地面が割れるような大きな輪＋閃光＋金と蒼の粒
func quake_end(cx: float, z: float, w: float) -> void:
	for x in [cx - w * 0.5, cx, cx + w * 0.5]:
		ring(Vector3(x, 0, z), 5.0, 0, true)
	fx.shockwave(Vector3(cx, 1.0, z), 2.2, 0.6, 1.0)

## 気の溜め：手元に蒼白の光が集まる＋足元の小さな輪
func charge(p: Vector3, size: float, life: float) -> void:
	var m: ShaderMaterial = fx._mat(1, BLUE)
	m.set_shader_parameter("core_gain", 0.9)
	fx._quad(p + Vector3(0, 0, 0.15), Vector2(size, size), m, "charge", life, 0.0)
	for i in 8:
		var a := randf() * TAU
		var off := Vector3(cos(a), sin(a), 0) * size * 0.8
		fx._spark(p + off, -off / life, life, 0.02, BLUE[1] if i % 2 else GOLD[2], 0.0)

## 当たり：蒼白の閃光と火花（金の粒を少し）。strong で花びら
func hit(p: Vector3, strong: bool) -> void:
	fx._quad(p + Vector3(0, 0, 0.2), Vector2(1.2, 1.2) * (1.6 if strong else 1.0), fx._mat(1, BLUE), "flash", 0.1, 0.0)
	for i in (12 if strong else 6):
		var a := randf() * TAU
		fx._spark(p, Vector3(cos(a), sin(a) + 0.2, randf_range(-0.3, 0.3)) * randf_range(3.0, 8.0), randf_range(0.15, 0.32), 0.024, GOLD[2] if i % 3 == 0 else BLUE[1], 0.0)
	if strong:
		petals_burst(p, 8, {"spd": Vector2(2.0, 5.5), "size": 0.15})

func _process(delta: float) -> void:
	for i in range(petals.size() - 1, -1, -1):
		var q: Dictionary = petals[i]
		q.t += delta
		var s: Sprite3D = q.node
		if q.t < 0.0:
			continue
		if q.t >= q.life or not is_instance_valid(s):
			if is_instance_valid(s):
				s.queue_free()
			petals.remove_at(i)
			continue
		s.visible = true
		var k: float = q.t / q.life
		var v: Vector3 = q.v
		v *= pow(0.12, delta)                           # 空気で止まる
		v.y -= 1.4 * delta                              # ゆっくり落ちる
		q.v = v
		s.position += v * delta + Vector3(sin(q.t * 4.0 * q.sway + q.ph) * 0.6 * delta, 0, 0)   # ひらひら
		s.rotation.z += q.spin * delta
		s.scale = Vector3(1.0, 0.55 + 0.45 * absf(sin(q.t * 6.0 + q.ph)), 1.0)                # 裏返る
		var a := minf(1.0, q.t / 0.06) * (1.0 - smoothstep(0.6, 1.0, k))
		s.modulate.a = a
	for i in range(orbs.size() - 1, -1, -1):
		var o: Dictionary = orbs[i]
		o.t += delta
		if not is_instance_valid(o.node) or o.t >= o.life:
			orbs.remove_at(i)
			continue
		var u: float = o.t / o.life
		o.node.position = (o.a as Vector3).lerp(o.b, 1.0 - pow(1.0 - u, 2.0))
