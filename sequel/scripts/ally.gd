extends Node3D
## 仲間リリィ（2026-11-06）。ラナについて歩き、敵がいれば近い敵へ寄って、5本の攻撃パターンからランダムに蹴る。
## 絵は assets/lily/lily.json（tools/pack_lily.py）。地区 pck「al1」に入っていて、読み終えてから出てくる。
## 歩き・走り（2026-11-06 追加、その場の1周を繰り返す）。まだ無い動き：被弾 → 敵の攻撃は受けない（仮）。
## スキルは未決：攻撃パターンは全部入れて、出す順はランダム（同じものを続けない）。

const SPR := preload("res://scripts/sprite_bb.gdshader")
const SPD := 4.0          # 連番（1秒12コマ）を流す速さ。2026-11-06 ユーザー「味方の攻撃が遅すぎる」→ 2.0（1本 1.5〜2.5秒）から 4.0（0.8〜1.3秒、ラナの連撃に近づける）
const WALK := 2.4         # 歩く速さ（m/秒）
const RUN := 5.2          # 走る速さ（目標まで RUN_D より遠いとき）
const RUN_D := 2.2
const DEPTH_K := 0.75
const ATK_X := 1.0        # 敵とこの左右の距離まで寄って攻撃する
const ATK_LANE := 0.35    # 奥行きをここまで合わせてから攻撃する
const HIT_LANE := 0.8     # 当たりの奥行きの幅
const DMG := 11.0         # 1発の強さ（最後の当たりは strong＝金の数字・強い止め）
const PATTERNS := ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush"]

var world               # battle.gd
var data := {}
var pages := {}
var sprite: Sprite3D
var mat: ShaderMaterial
var shadow: MeshInstance3D
var refl: Sprite3D
var px := 0.005
var height_m := 1.70
var face := 1
var state := "move"     # move / atk
var clip := "idle"
var t := 0.0
var hit_i := 0
var cd := 0.8
var last := ""
var mv := ""             # 今流している移動のクリップ（walk / run）
var fixed_scale := -1.0   # 撮影の並べ比べ用（背の高さを変える）

func setup(w, d: Dictionary) -> void:
	world = w
	data = d
	height_m = float(d.height_m)

func _ready() -> void:
	px = height_m / float(data.body_px)
	sprite = Sprite3D.new()
	sprite.region_enabled = true
	sprite.centered = false
	mat = ShaderMaterial.new()
	mat.shader = SPR
	sprite.material_override = mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	shadow = world.make_shadow(1.1)
	add_child(shadow)
	refl = world.make_refl()
	add_child(refl)
	_show("idle", 0)

## 背の高さを変える（撮影の並べ比べ用）
func set_height(h: float) -> void:
	height_m = h
	px = h / float(data.body_px)
	_show(clip, 0)

func height() -> float:
	return height_m

func _tex(p: int) -> Texture2D:
	if not pages.has(p):
		pages[p] = load("res://assets/lily/" + str(data.pages[p]))
	return pages[p]

func _show(c: String, i: int) -> void:
	var fr: Array = data.clips[c].frames
	var f: Array = fr[clampi(i, 0, fr.size() - 1)]
	var tex := _tex(int(f[0]))
	if sprite.texture != tex:
		sprite.texture = tex
		mat.set_shader_parameter("tex", tex)
	sprite.region_rect = Rect2(f[1], f[2], f[3], f[4])
	sprite.pixel_size = px
	var ox: float = f[5]
	if face < 0:
		ox = -ox - f[3]
	sprite.flip_h = face < 0
	sprite.offset = Vector2(ox, -float(f[6]) - f[4])

func _nearest() -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for e in world.enemies:
		if e.state == "dying":
			continue
		var d: float = absf(e.position.x - position.x) + absf(e.position.z - position.z) * 1.5
		if d < bd:
			bd = d
			best = e
	return best

func _start_atk(e: Node3D) -> void:
	var opts := []
	for p in PATTERNS:
		if p != last and data.clips.has(p):
			opts.append(p)
	clip = opts[randi() % opts.size()]
	last = clip
	face = 1 if e.position.x >= position.x else -1
	state = "atk"
	t = 0.0
	hit_i = 0

func _physics_process(delta: float) -> void:
	var dt: float = world.dt(delta)
	if dt <= 0.0:
		world.apply_light(sprite, mat, refl, position)
		return
	t += dt
	var pl: Node3D = world.player
	# ラナから離れすぎたら（部屋の移動など）すぐそばへ
	if absf(pl.position.x - position.x) > 9.0:
		position = pl.position + Vector3(-pl.face * 1.4, 0, 0.6)
		state = "move"
	match state:
		"move":
			cd -= dt
			var e := _nearest()
			var goal: Vector3
			if e:
				var side := 1.0 if position.x >= e.position.x else -1.0
				goal = Vector3(e.position.x + side * ATK_X * 0.9, 0, e.position.z)
			else:
				goal = pl.position + Vector3(-pl.face * 1.4, 0, 0.7)
			var d := goal - position
			var moving := absf(d.x) > 0.12 or absf(d.z) > 0.08
			var run := Vector2(d.x, d.z).length() > RUN_D
			var sp := RUN if run else WALK
			if moving:
				position.x += clampf(d.x, -sp * dt, sp * dt)
				position.z += clampf(d.z, -sp * DEPTH_K * dt, sp * DEPTH_K * dt)
			if e:
				face = 1 if e.position.x >= position.x else -1
			elif absf(d.x) > 0.12:
				face = 1 if d.x > 0 else -1
			else:
				face = pl.face
			var want := ("run" if run else "walk") if moving and data.clips.has("walk") else ""
			if want != mv:
				mv = want
				t = 0.0
			if mv == "":
				_show("idle", 0)
			else:
				var lc: Dictionary = data.clips[mv]
				_show(mv, int(t * float(lc.fps)) % lc.frames.size())
			if e and cd <= 0.0 and absf(e.position.x - position.x) < ATK_X + 0.35 and absf(e.position.z - position.z) < ATK_LANE:
				mv = ""
				_start_atk(e)
		"atk":
			var c: Dictionary = data.clips[clip]
			var fps: float = float(c.fps) * SPD
			var i := int(t * fps)
			var hits: Array = c.hits
			while hit_i < hits.size() and i >= int(hits[hit_i]):
				var last_hit := hit_i == hits.size() - 1
				world.ally_attack(self, {"side": 1, "r": maxf(1.5, float(c.reach[hit_i]) + 0.35), "lane": HIT_LANE,
					"dmg": DMG * (1.3 if last_hit else 1.0), "strong": last_hit,
					"slash": {"plane": "h", "r": maxf(1.5, float(c.reach[hit_i]) * 1.15), "w": 0.65, "a0": 120.0, "a1": -40.0,
						"y": 1.0 if clip != "atk_heeldrop" or hit_i == 0 else 0.7, "life": 0.28, "draw": 0.06, "squash": 0.55, "tilt": 4.0}})
				hit_i += 1
			if i >= c.frames.size():
				state = "move"
				clip = "idle"
				mv = ""
				t = 0.0
				cd = randf_range(0.2, 0.45)   # 次の攻撃まで（前 0.5〜1.1）
				_show("idle", 0)
			else:
				_show(clip, i)
	mat.set_shader_parameter("tint", Color(1, 1, 1, 1))
	world.apply_light(sprite, mat, refl, position)
	position.x = clampf(position.x, world.ROOM_X.x, world.ROOM_X.y)
	position.z = clampf(position.z, world.BELT_Z.x, world.BELT_Z.y)

## 撮影用：攻撃のコマを止めて見せる
func debug_pose(c: String, i: int) -> void:
	set_physics_process(false)
	clip = c
	_show(c, i)
	world.apply_light(sprite, mat, refl, position)
