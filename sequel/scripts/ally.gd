extends Node3D
## 仲間リリィ（2026-11-06）。ラナについて歩き、敵がいれば近い敵へ寄って、5本の攻撃パターンからランダムに蹴る。
## 絵は assets/lily/lily.json（tools/pack_lily.py）。地区 pck「al1」に入っていて、読み終えてから出てくる。
## 歩き・走り（2026-11-06 追加、その場の1周を繰り返す）。被弾（2026-11-06）：敵の攻撃を受けると揺れて押し戻される。体力は無い（倒れない。仮）。
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
## 技ごとの見せ方と当たり方（2026-11-06、specs/lily_attack_fx.md）。当たりごとに1つ。
##   kind：spear＝まっすぐな光の槍、arc＝つま先の通り道（測った点 tip を腰を中心に 1.3 倍へ伸ばしてつなぐ）、
##         sweep＝床と平行の大きな弧（前後両側）、pillar＝太い光の柱＋床の稲妻＋衝撃波＋砂煙（足元の円）、rush＝突進＋残像＋足の後ろの槍（通り道の帯）
##   lift＝浮かせる（上向きの速さ m/秒）、kb＝吹き飛ばしの倍、dash＝当たりまでに前へ進む距離（m）
const FX := {
	"atk_jabkick": [{"kind": "spear"}, {"kind": "arc", "lift": 3.2}],
	"atk_highkick": [{"kind": "arc", "lift": 4.0, "bolts": 4}],
	"atk_roundhouse": [{"kind": "sweep", "kb": 2.4}],
	"atk_heeldrop": [{"kind": "arc", "w": 0.36, "bolts": 1}, {"kind": "pillar", "r": 2.2}],
	"atk_rush": [{"kind": "rush", "dash": 3.5}],
}
const HIP := Vector2(0.05, 0.95)   # 腰（足元から m）。軌跡を外へ伸ばす中心
const TRAIL_K := 1.3               # 軌跡の長さ（通り道の 1.3 倍）
const CHARGE_T := 0.12             # 溜め（つま先に蒼い光が集まる）

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
var state := "move"     # move / atk / hurt
var kb := 0.0
var inv := 0.0
var flash := 0.0
var clip := "idle"
var t := 0.0
var hit_i := 0
var cd := 0.8
var last := ""
var mv := ""             # 今流している移動のクリップ（walk / run）
var fixed_scale := -1.0   # 撮影の並べ比べ用（背の高さを変える）
var charged := -1         # 溜めを出した当たりの番号
var dash_x0 := 0.0        # 飛び蹴りの出だしの x
var ghost_t := 0.0
var ghosts := []

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

## 敵の攻撃が当たった（enemy.gd から）
func can_be_hit() -> bool:
	return inv <= 0.0 and data.clips.has("hit")

func on_hurt(dir: int) -> void:
	state = "hurt"
	clip = "hit"
	mv = ""
	t = 0.0
	kb = dir * 1.8
	inv = 0.5
	flash = 0.22
	face = -dir

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
	charged = -1
	dash_x0 = position.x

## 撮影用：決まった技を出させる
func force_attack(c: String, e: Node3D) -> void:
	last = ""
	clip = c
	face = 1 if e.position.x >= position.x else -1
	state = "atk"
	t = 0.0
	hit_i = 0
	charged = -1
	dash_x0 = position.x

func _physics_process(delta: float) -> void:
	var dt: float = world.dt(delta)
	if dt <= 0.0:
		world.apply_light(sprite, mat, refl, position)
		return
	t += dt
	inv = maxf(0.0, inv - dt)
	flash = maxf(0.0, flash - delta)
	mat.set_shader_parameter("flash", Color(1.0, 0.25, 0.2, 0.6 if flash > 0.0 else 0.0))
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
		"hurt":
			position.x += kb * dt
			kb *= pow(0.003, dt)
			var hc: Dictionary = data.clips["hit"]
			var hi := int(t * float(hc.fps) * SPD)
			if hi >= hc.frames.size():
				state = "move"
				clip = "idle"
				t = 0.0
				cd = randf_range(0.2, 0.6)
				_show("idle", 0)
			else:
				_show("hit", hi)
		"atk":
			var c: Dictionary = data.clips[clip]
			var fps: float = float(c.fps) * SPD
			var i := int(t * fps)
			var hits: Array = c.hits
			var legacy: bool = world.fx.legacy or not c.has("tip")
			if not legacy:
				_atk_extras(c, i, dt)
			while hit_i < hits.size() and i >= int(hits[hit_i]):
				var last_hit := hit_i == hits.size() - 1
				if legacy:   # 前の見た目（FX_OLD=1 の比較用）
					world.ally_attack(self, {"side": 1, "r": maxf(1.5, float(c.reach[hit_i]) + 0.35), "lane": HIT_LANE,
						"dmg": DMG * (1.3 if last_hit else 1.0), "strong": last_hit,
						"slash": {"plane": "h", "r": maxf(1.5, float(c.reach[hit_i]) * 1.15), "w": 0.65, "a0": 120.0, "a1": -40.0,
							"y": 1.0 if clip != "atk_heeldrop" or hit_i == 0 else 0.7, "life": 0.28, "draw": 0.06, "squash": 0.55, "tilt": 4.0}})
				else:
					_hit_new(c, int(hits[hit_i]), hit_i, last_hit)
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

# ---------- リリィの軌跡とエフェクト（2026-11-06、specs/lily_attack_fx.md） ----------
## つま先の点（足元から m、右向き）を世界の座標へ。k＝腰を中心に外へ伸ばす倍率
func _tip_world(c: Dictionary, i: int, k: float = 1.0) -> Vector3:
	var tp: Array = c.tip[clampi(i, 0, c.tip.size() - 1)]
	var v := HIP + (Vector2(float(tp[0]), float(tp[1])) - HIP) * k
	return position + Vector3(face * v.x, v.y, 0.12)

## 当たりの前のつま先の通り道（床に近い点は除く）を、腰を中心にした角度と距離でなめらかにつなぐ
func _trail(c: Dictionary, h: int) -> Array:
	var raw := []
	for f in range(maxi(0, h - 6), h + 1):
		var tp: Array = c.tip[f]
		if float(tp[1]) > 0.45:
			raw.append(Vector2(float(tp[0]), float(tp[1])) - HIP)
	if raw.size() == 1:   # 点が1つ：下から振り上げてきた弧を足す
		raw.push_front(raw[0].rotated(-0.9 if raw[0].x >= 0.0 else 0.9) * 0.85)
	var pts := []
	for n in raw.size() - 1:
		var a: Vector2 = raw[n]
		var b: Vector2 = raw[n + 1]
		var aa := a.angle()
		var da := wrapf(b.angle() - aa, -PI, PI)
		for s in 6:
			var u := float(s) / 6.0
			var r := lerpf(a.length(), b.length(), u) * TRAIL_K
			var v := HIP + Vector2(cos(aa + da * u), sin(aa + da * u)) * r
			pts.append(position + Vector3(face * v.x, v.y, 0.12))
	var e: Vector2 = HIP + raw[raw.size() - 1] * TRAIL_K
	pts.append(position + Vector3(face * e.x, e.y, 0.12))
	return pts

## 溜め・突進・残像（当たりの前）
func _atk_extras(c: Dictionary, i: int, dt: float) -> void:
	var hits: Array = c.hits
	var fps: float = float(c.fps) * SPD
	if hit_i < hits.size():
		var h: int = int(hits[hit_i])
		if charged < hit_i and i >= h - int(ceil(CHARGE_T * fps)):
			charged = hit_i
			world.fx.charge(_tip_world(c, h), 0.9, CHARGE_T)
		var spec: Dictionary = FX[clip][hit_i]
		if spec.has("dash"):   # 飛び蹴り：当たりまでの半分の時間で dash m 前へ
			var t0: float = h / fps * 0.5
			var t1: float = h / fps
			if t > t0 and t <= t1 + dt:
				position.x += face * float(spec.dash) / (t1 - t0) * dt
				ghost_t -= dt
				if ghost_t <= 0.0:
					ghost_t = (t1 - t0) / 3.0
					_ghost()
	_update_ghosts(dt)

func _ghost() -> void:
	var g := Sprite3D.new()
	g.texture = sprite.texture
	g.region_enabled = true
	g.region_rect = sprite.region_rect
	g.centered = false
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.pixel_size = sprite.pixel_size
	var gm := ShaderMaterial.new()
	gm.shader = SPR
	gm.set_shader_parameter("tex", sprite.texture)
	gm.set_shader_parameter("tint", Color(0.5, 0.75, 1.0, 0.55))
	gm.set_shader_parameter("flash", Color(0.3, 0.7, 1.0, 0.7))
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.position = position - Vector3(0, 0, 0.05)
	world.add_child(g)
	ghosts.append({"node": g, "t": 0.0})

func _update_ghosts(dt: float) -> void:
	for n in range(ghosts.size() - 1, -1, -1):
		var g: Dictionary = ghosts[n]
		g.t += dt
		var a: float = 0.55 * (1.0 - g.t / 0.35)
		if a <= 0.0:
			g.node.queue_free()
			ghosts.remove_at(n)
		else:
			g.node.material_override.set_shader_parameter("tint", Color(0.5, 0.75, 1.0, a))

## 当たり：見た目（軌跡）と当たり方を、技の表 FX から
func _hit_new(c: Dictionary, h: int, n: int, last_hit: bool) -> void:
	var spec: Dictionary = FX[clip][n]
	var tipm: float = 0.0
	for f in range(maxi(0, h - 6), h + 1):
		tipm = maxf(tipm, float(c.tip_f[f][0]))
	var r := clampf(tipm * TRAIL_K + 0.3, 2.0, 2.6)   # 見た目より少し広い（目安 2.0〜2.6m）
	var hs := {"side": 1, "r": r, "lane": 1.0, "dmg": DMG * (1.3 if last_hit else 1.0), "strong": last_hit, "zap": true}
	for k in ["lift", "kb"]:
		if spec.has(k):
			hs[k] = spec[k]
	var fx = world.fx
	var tip := _tip_world(c, h, TRAIL_K)
	match spec.kind:
		"spear":
			var base := _tip_world(c, h, 0.25)
			fx.ribbon([base, base.lerp(tip, 0.5), tip + Vector3(face * 0.35, 0, 0)], {"w": 0.42, "life": 0.4, "bolts": 2})
		"arc":
			fx.ribbon(_trail(c, h), {"w": spec.get("w", 0.62), "life": 0.48, "bolts": spec.get("bolts", 2)})
		"sweep":
			hs.shape = "both"
			hs.side = 0
			fx.slash(position, face, {"plane": "h", "r": r, "w": 0.85, "a0": -120.0, "a1": 210.0, "y": 1.35, "life": 0.45, "draw": 0.09,
				"squash": 0.6, "tilt": 4.0, "pal": fx.SILVER})
			fx.bolt([position + Vector3(-face * r * 0.7, 1.35, 0.3), position + Vector3(0, 1.4, 0.5), position + Vector3(face * r * 0.9, 1.35, 0.3)], 0.035, fx.BOLT_BLUE, 0.35, 0.03, 0.15)
		"pillar":
			hs.shape = "circle"
			hs.r = float(spec.r)
			hs.cx = 0.9
			var gx := position + Vector3(face * 0.9, 0, 0.12)
			fx.ribbon([gx + Vector3(0, 3.4, 0), gx + Vector3(0, 1.7, 0), gx + Vector3(0, 0.05, 0)], {"w": 0.8, "life": 0.5, "draw": 0.05, "bolts": 3})
			fx.floor_bolts(gx, 8, 2.2)
			fx.shockwave(gx + Vector3(0, 0.4, 0), 1.4)
			fx.dust(gx, 1.8)
			world.shake = maxf(world.shake, 12.0)
		"rush":
			hs.shape = "band"
			hs.x0 = dash_x0
			hs.x1 = position.x + face * r
			var foot := _tip_world(c, h, TRAIL_K)
			fx.ribbon([foot - Vector3(face * 2.6, 0.05, 0), foot - Vector3(face * 1.3, 0.0, 0), foot + Vector3(face * 0.4, 0, 0)], {"w": 0.46, "life": 0.45, "bolts": 2})
	world.ally_attack(self, hs)

## 撮影用：攻撃のコマを止めて見せる
func debug_pose(c: String, i: int) -> void:
	set_physics_process(false)
	clip = c
	_show(c, i)
	world.apply_light(sprite, mat, refl, position)
