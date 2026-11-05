extends Node3D
## 戦闘のまとめ役：敵の群れの出現、当たりの判定、ヒットストップ（止め）、画面の揺れ、ラナの体力。
## 敵は小さな群れで左右から来る。倒しきると少しして次の群れ（だんだん増える）。

const Enemy := preload("res://scripts/enemy.gd")
const HPBAR := preload("res://scripts/hpbar.gdshader")

var BELT_Z := Vector2(-3.2, 3.5)
var ROOM_X := Vector2(-19, 19)
var player: Node3D
var fx: Node3D
var cam: Camera3D
var enemies := []
var foe_clips := {}
var freeze := 0.0         # ヒットストップの残り（秒）。この間、ラナと敵は止まる
var shake := 0.0          # 画面の揺れ（px 相当）
var wave := 0
var next_t := 1.2
var spawn_side := 1
var hp := 100.0
var hp_max := 100.0
var combo := 0
var combo_t := 0.0
var auto_spawn := true
var shadow_mat: StandardMaterial3D

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/foe/foe.json"))
	foe_clips = d
	shadow_mat = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.55)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	shadow_mat.albedo_texture = gt
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

## ラナと敵が使う時間（止めている間は 0）
func dt(delta: float) -> float:
	return 0.0 if freeze > 0.0 else delta

func _physics_process(delta: float) -> void:
	freeze = maxf(0.0, freeze - delta)
	shake = maxf(0.0, shake - delta * 60.0)
	combo_t = maxf(0.0, combo_t - delta)
	if combo_t <= 0.0:
		combo = 0
	_separate(delta)
	if auto_spawn and enemies.is_empty():
		next_t -= delta
		if next_t <= 0.0:
			_spawn_wave()

func make_shadow(w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, w * 0.38)
	qm.orientation = PlaneMesh.FACE_Y
	mi.mesh = qm
	mi.material_override = shadow_mat
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func make_hpbar() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.075)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = HPBAR
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ---------- 出現 ----------
func _spawn_wave() -> void:
	wave += 1
	var n := mini(3 + wave / 2, 7)
	var half_w := 10.5   # 画面の端より外（横持ち 19.5:9 で約 9.5m）
	for i in n:
		var side := spawn_side if i % 3 != 2 else -spawn_side   # 3体に1体は反対側から（挟まれる）
		var x := cam.position.x + side * (half_w + randf_range(0.0, 2.0) + i * 0.4)
		if x > ROOM_X.y + 2.0 or x < ROOM_X.x - 2.0:
			x = cam.position.x - side * (half_w + randf_range(0.0, 2.0))
		spawn(["1", "3"][randi() % 2], Vector3(x, 0, randf_range(BELT_Z.x, BELT_Z.y)))
	spawn_side = -spawn_side
	next_t = 1.5

func spawn(kind: String, pos: Vector3) -> Node3D:
	var e := Enemy.new()
	e.setup(self, kind, foe_clips[kind], wave)
	e.position = pos
	e.face = 1 if player.position.x > pos.x else -1
	add_child(e)
	enemies.append(e)
	return e

func remove_enemy(e) -> void:
	enemies.erase(e)
	e.queue_free()

func _separate(delta: float) -> void:
	for i in enemies.size():
		var a = enemies[i]
		if a.state == "dying":
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if b.state == "dying":
				continue
			var d := Vector2(a.position.x - b.position.x, (a.position.z - b.position.z) * 1.6)
			var l := d.length()
			if l < 0.62 and l > 0.001:
				var push := (0.62 - l) * 0.5 * minf(1.0, delta * 12.0)
				a.position.x += d.x / l * push
				b.position.x -= d.x / l * push

# ---------- ラナの攻撃 ----------
## spec：{side（+1＝前 −1＝背）, r（届く距離）, lane（奥行き）, dmg, strong, slash（エフェクト）}
func player_attack(spec: Dictionary) -> void:
	var p: Node3D = player
	var dir: int = p.face * spec.side
	var hits := 0
	for e in enemies:
		if e.state == "dying":
			continue
		var dx: float = (e.position.x - p.position.x) * dir
		var dz: float = absf(e.position.z - p.position.z)
		if dx > -0.42 and dx < spec.r and dz < spec.lane:
			var d: float = spec.dmg * randf_range(0.9, 1.1)
			var edir := 1 if e.position.x >= p.position.x else -1
			e.take_hit(d, edir, spec.strong)
			var hp_pos: Vector3 = e.position + Vector3(0, e.height() * 0.55, 0)
			fx.hit(hp_pos, edir, spec.strong, hits < 4)
			fx.number(e.position + Vector3(0, e.height() + 0.5, 0), int(round(d)), "strong" if spec.strong else "")
			hits += 1
	fx.slash(p.position, dir, spec.slash)
	if hits > 0:
		freeze = maxf(freeze, 0.045 + mini(hits, 10) * 0.006 + (0.03 if spec.strong else 0.0))
		shake = maxf(shake, 5.0 + mini(hits, 12) * 1.1 + (4.0 if spec.strong else 0.0))
		combo += hits
		combo_t = 2.4
	else:
		shake = maxf(shake, 1.5)

# ---------- 敵の攻撃 ----------
func player_alive() -> bool:
	return hp > 0.0

func enemy_hits_player(e) -> void:
	var p: Node3D = player
	if not p.can_be_hit():
		return
	var d: int = e.dmg
	hp = maxf(0.0, hp - d)
	var dir := 1 if p.position.x >= e.position.x else -1
	fx.hurt(p.position + Vector3(0, 1.0, 0), dir)
	fx.number(p.position + Vector3(0, 2.1, 0), d, "hurt")
	freeze = maxf(freeze, 0.06)
	shake = maxf(shake, 7.0)
	p.on_hurt(dir, hp <= 0.0)

## 倒れたあと起き上がった
func player_revived() -> void:
	hp = hp_max
