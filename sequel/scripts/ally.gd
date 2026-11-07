extends Node3D
## 仲間リリィ（2026-11-06）。ラナについて歩き、敵がいれば近い敵へ寄って、5本の攻撃パターンからランダムに蹴る。
## 絵は assets/lily/lily.json（tools/pack_lily.py）。地区 pck「al1」に入っていて、読み終えてから出てくる。
## 歩き・走り（2026-11-06 追加、その場の1周を繰り返す）。被弾（2026-11-06）：敵の攻撃を受けると揺れて押し戻される。体力は無い（倒れない。仮）。
## 通常の攻撃は5本からランダム（同じものを続けない）。スキル（2026-11-07、ユーザー決定）：迅雷・雷連打・雷陣を、待ちが明けたらその場を見て自動で出す。
## 必殺技 天雷：battle.ally_ult が満タンで自動（ボス、いなければ体力のいちばん多い敵だけを狙う）。表は scripts/lily_skills.gd。

const SPR := preload("res://scripts/sprite_bb.gdshader")
const LilySkills := preload("res://scripts/lily_skills.gd")
const STORM_R := 4.8      # 雷陣を出す判断の半径（m、奥行きは 1.3 倍で数える）
const RUSH_MIN := 3.5     # 迅雷：いちばん近い敵がこの距離〜RUSH_MAX のとき
const RUSH_MAX := 8.5     # 画面の外へ飛び出さない距離（遊ぶカメラの半分 ≒ 9.5m）
const ULT_CUT := {"zoom": 0.3, "cut_start": 0.3, "cut_end": 1.35}   # 必殺技の寄りとカットイン（実時間。ラナの必殺技と同じ）
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
var skills_on := OS.get_environment("LILY_SKILLS") != "0"   # 比べる用：LILY_SKILLS=0 でスキルを出さない
var sk_tab := {}
var sk_cd := {"rush": 1.5, "barrage": 3.0, "storm": 5.0}   # 待ちの残り（最初はずらす）
var sk_id := ""
var sk := {}
var ev_i := 0
var target: Node3D = null
var dash_from := Vector3.ZERO
var dash_to := Vector3.ZERO
var ult_t := 0.0
var ult_jumped := false
var sk_used := {}          # 技ごとの回数（自動の確認用）

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
	sk_tab = LilySkills.table()
	_show("idle", 0)

## 背の高さを変える（撮影の並べ比べ用）
func set_height(h: float) -> void:
	height_m = h
	px = h / float(data.body_px)
	_show(clip, 0)

## 敵の攻撃が当たった（enemy.gd から）
func can_be_hit() -> bool:
	return inv <= 0.0 and data.clips.has("hit") and state != "skill" and state != "ult"

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
	if state == "ult":   # 必殺技は実時間で進める（止め・演出の間も）
		_ult_process(delta)
		world.apply_light(sprite, mat, refl, position)
		return
	var dt: float = world.dt(delta)
	for id in sk_cd:
		sk_cd[id] = maxf(0.0, float(sk_cd[id]) - dt)
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
			if e and cd <= 0.0 and _pick_skill(e):
				mv = ""
			elif e and cd <= 0.0 and absf(e.position.x - position.x) < ATK_X + 0.35 and absf(e.position.z - position.z) < ATK_LANE:
				mv = ""
				_start_atk(e)
		"skill":
			if _skill_step(dt):
				state = "move"
				clip = "idle"
				mv = ""
				t = 0.0
				cd = 0.3
				_show("idle", 0)
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
	var hs := {"side": 1, "r": r, "lane": 1.0, "dmg": DMG * (1.3 if last_hit else 1.0), "strong": last_hit, "zap": true, "shake": 8.0 if last_hit else 4.0}
	for k in ["lift", "kb"]:
		if spec.has(k):
			hs[k] = spec[k]
	var fx = world.fx
	var tip := _tip_world(c, h, TRAIL_K)
	match spec.kind:
		"spear":
			var base := _tip_world(c, h, 0.25)
			fx.ribbon([base, base.lerp(tip, 0.5), tip + Vector3(face * 0.35, 0, 0)], {"w": 0.42, "life": 0.4, "bolts": 1})
		"arc":
			fx.ribbon(_trail(c, h), {"w": spec.get("w", 0.62), "life": 0.48, "bolts": spec.get("bolts", 2)})
		"sweep":
			hs.shape = "both"
			hs.side = 0
			fx.slash(position, face, {"plane": "h", "r": r, "w": 0.85, "a0": -120.0, "a1": 210.0, "y": 1.35, "life": 0.45, "draw": 0.09,
				"squash": 0.6, "tilt": 4.0, "pal": fx.SILVER})
		"pillar":
			hs.shape = "circle"
			hs.r = float(spec.r)
			hs.cx = 0.9
			var gx := position + Vector3(face * 0.9, 0, 0.12)
			fx.pillar(gx, 3.6)   # 光の柱＝太い稲妻の束＋縦の柔らかい光（板の帯はやめた。衝撃波は strong の当たりで battle が出す）
			fx.floor_bolts(gx, 8, 2.2)
			fx.dust(gx, 1.8)
			world.shake = maxf(world.shake, 12.0)
		"rush":
			hs.shape = "band"
			hs.x0 = dash_x0
			hs.x1 = position.x + face * r
			var foot := position + Vector3(face * 1.2, 1.1, 0.12)   # 足の高さ（当たりのコマの絵に焼き込まれた光の塊を拾わないよう決め打ち）
			fx.ribbon([foot - Vector3(face * 2.6, 0.05, 0), foot - Vector3(face * 1.3, 0.0, 0), foot + Vector3(face * 0.4, 0, 0)], {"w": 0.46, "life": 0.45, "bolts": 1})
	world.ally_attack(self, hs)

## 撮影用：攻撃のコマを止めて見せる
func debug_pose(c: String, i: int) -> void:
	set_physics_process(false)
	clip = c
	_show(c, i)
	world.apply_light(sprite, mat, refl, position)

# ---------- スキル（2026-11-07、ユーザー決定）。表は scripts/lily_skills.gd ----------
func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and e.state != "dying"

## 待ちが明けた技から、その場に合うものを選ぶ。出したら true
func _pick_skill(e: Node3D) -> bool:
	if not skills_on:
		return false
	var pl: Node3D = world.player
	# 必殺技：満タン・誰も演出中でない
	if world.ally_ult >= world.ULT_MAX and not world.cine and pl.state != "ult":
		var tg := _ult_target()
		if tg:
			_start_ult(tg)
			return true
	var near := 0
	var boss_near := false
	for x in world.enemies:
		if x.state == "dying":
			continue
		if Vector2(x.position.x - position.x, (x.position.z - position.z) * 1.3).length() < STORM_R:
			near += 1
			boss_near = boss_near or x.boss
	if sk_cd.storm <= 0.0 and (near >= 3 or (near >= 2 and boss_near)):
		_start_skill("storm", e)
		return true
	var dx := absf(e.position.x - position.x)
	if sk_cd.rush <= 0.0 and dx > RUSH_MIN and dx < RUSH_MAX:
		_start_skill("rush", e)
		return true
	if sk_cd.barrage <= 0.0 and dx < ATK_X + 0.5 and absf(e.position.z - position.z) < ATK_LANE + 0.15:
		_start_skill("barrage", e)
		return true
	return false

func _start_skill(id: String, e: Node3D) -> void:
	sk_id = id
	sk = sk_tab[id]
	sk_cd[id] = float(sk.get("cd", 0.0))
	sk_used[id] = int(sk_used.get(id, 0)) + 1
	target = e
	face = 1 if e.position.x >= position.x else -1
	state = "skill"
	t = 0.0
	ev_i = 0
	ghost_t = 0.0
	dash_from = position
	var side := -face
	dash_to = Vector3(e.position.x + side * 1.0, 0, e.position.z)
	world.big_moment(float(sk.frames.size()) / float(sk.fps) * 0.85)
	dash_to.x = clampf(dash_to.x, world.ROOM_X.x, world.ROOM_X.y)

## 1コマ進める（t は呼ぶ側で進める）。終わったら true
func _skill_step(dt: float) -> bool:
	var fr: Array = sk.frames
	var fps: float = float(sk.fps)
	var i := int(t * fps)
	if sk.has("dash"):   # 一気に詰める：dash の間に dash_to まで（はじめ速く、着く前にゆるむ）
		var d0: float = float(sk.dash[0]) / fps
		var d1: float = float(sk.dash[1]) / fps
		if t >= d0 and t <= d1 + dt:
			var u := clampf((t - d0) / (d1 - d0), 0.0, 1.0)
			u = 1.0 - pow(1.0 - u, 2.0)
			position = dash_from.lerp(dash_to, u)
			ghost_t -= dt
			if ghost_t <= 0.0:
				ghost_t = (d1 - d0) / 4.0
				_ghost()
	_update_ghosts(dt)
	var ev: Array = sk.ev
	while ev_i < ev.size() and i >= int(ev[ev_i][0]):
		_skill_hit(ev[ev_i][1])
		ev_i += 1
	if i >= fr.size():
		return true
	var f = fr[i]
	if f is Array:
		_show(f[0], int(f[1]))
	else:
		_show(sk.clip, int(f))
	return false

## 当たり1回：見た目を出してから battle に判定させる
func _skill_hit(spec: Dictionary) -> void:
	var hs := spec.duplicate()
	hs.dmg = DMG * float(spec.k)
	hs.zap = true
	var fx = world.fx
	var c: Dictionary = data.clips["atk_jabkick"]
	match String(spec.get("fx", "")):
		"jab":   # 拳の光の槍（高さを少しずつずらす）
			var y := 1.25 + randf_range(-0.12, 0.12)
			var a := position + Vector3(face * 0.35, y, 0.12)
			var b := position + Vector3(face * (1.6 + randf_range(0.0, 0.3)), y + randf_range(-0.08, 0.08), 0.12)
			fx.ribbon([a, a.lerp(b, 0.5), b], {"w": 0.3, "life": 0.22, "bolts": 0})
		"kick":
			fx.ribbon(_trail(c, 19), {"w": 0.45, "life": 0.3, "bolts": 1})
		"kick_end":
			fx.ribbon(_trail(c, 19), {"w": 0.75, "life": 0.5, "bolts": 3})
			fx.sky_bolt(position + Vector3(face * 1.6, 0, 0), 0.0)
			world.shake = maxf(world.shake, 10.0)
		"rush":
			hs.x0 = dash_from.x
			hs.x1 = position.x + face * float(spec.r)
			fx.dash_trail(dash_from, position + Vector3(face * 1.2, 0, 0))
		"storm_drop":
			var g := position + Vector3(0, 0, 0.12)
			fx.pillar(g, 3.6)
			fx.floor_bolts(g, 10, 2.6)
			fx.dust(g, 2.0)
			world.shake = maxf(world.shake, 12.0)
		"storm":   # 半径の中の敵（多くて4体）と、あいた所へ空から稲妻
			var n := 0
			for x in world.enemies:
				if n < 3 and x.state != "dying" and Vector2(x.position.x - position.x, (x.position.z - position.z) * 1.3).length() < float(spec.r):
					fx.sky_bolt(x.position + Vector3(0, 0, 0.05), randf_range(0.0, 0.04))
					n += 1
			for k in 1:
				var a2 := randf() * TAU
				fx.sky_bolt(position + Vector3(cos(a2) * randf_range(1.5, 4.0), 0, sin(a2) * 2.2), randf_range(0.0, 0.06))
			world.shake = maxf(world.shake, 7.0)
		"storm_end":
			fx.storm_ring(position, float(spec.r))
			world.chroma_hit(0.8)
			fx.floor_bolts(position, 14, float(spec.r))
			world.shake = maxf(world.shake, 16.0)
		"ult_hit":
			hs.only = target if _alive(target) else null
			if _alive(target):
				fx.sky_bolt(target.position + Vector3(0, 0, 0.05), 0.0)
			if int(spec.n) % 3 == 2:
				fx.ribbon(_trail(c, 19), {"w": 0.55, "life": 0.3, "bolts": 2})
			else:
				var y2 := 1.25 + randf_range(-0.1, 0.1)
				var a3 := position + Vector3(face * 0.35, y2, 0.12)
				fx.ribbon([a3, a3 + Vector3(face * 1.0, 0.04, 0), a3 + Vector3(face * 1.9, 0, 0)], {"w": 0.4, "life": 0.25, "bolts": 1})
			world.shake = maxf(world.shake, 8.0)
		"ult_end":   # 天雷：狙った敵へ巨大な雷の柱
			hs.only = target if _alive(target) else null
			var g2: Vector3 = (target.position if _alive(target) else position + Vector3(face * 1.0, 0, 0)) + Vector3(0, 0, 0.1)
			fx.sky_bolt(g2, 0.0, true)
			fx.sky_bolt(g2 + Vector3(0.25, 0, 0), 0.05, true)
			fx.pillar(g2, 7.0)
			fx.floor_bolts(g2, 16, 3.6)
			fx.storm_ring(g2, 3.6)
			fx.shockwave(g2 + Vector3(0, 1.0, 0), 2.2, 0.6, 0.9)
			world.chroma_hit(1.0)
			if world.fx2d and not fx.legacy:
				world.fx2d.big(g2 + Vector3(0, 1.2, 0), world.fx2d.SILVER)
			fx.dust(g2, 2.4)
			world.shake = maxf(world.shake, 24.0)
			if world.main and world.main.lily_cutin:
				world.main.lily_cutin.flash_white()
	var nh: int = world.ally_attack(self, hs)
	if OS.has_environment("LSKILL_LOG"):
		print("  hit ", spec.get("fx", ""), " dmg ", hs.dmg, " 当たった ", nh)

# ---------- 必殺技 天雷（2026-11-07）：止まって寄る → 立ち絵のカットイン → 狙った1体の横へ瞬間移動 → 6 回の連打（毎回空から稲妻）→ 巨大な雷の柱 ----------
## ボスがいればボス、いなければ体力のいちばん多い敵
func _ult_target() -> Node3D:
	var best: Node3D = null
	var bh := -1.0
	for x in world.enemies:
		if x.state == "dying" or absf(x.position.x - position.x) > 14.0:
			continue
		var h: float = float(x.hp) + (1e6 if x.boss else 0.0)
		if h > bh:
			bh = h
			best = x
	return best

func _start_ult(e: Node3D) -> void:
	world.ally_ult = 0.0
	world.ally_ult_gain = false
	sk_id = "ult"
	sk = sk_tab["ult"]
	sk_used["ult"] = int(sk_used.get("ult", 0)) + 1
	target = e
	face = 1 if e.position.x >= position.x else -1
	state = "ult"
	ult_t = 0.0
	ult_jumped = false
	t = 0.0
	ev_i = 0
	world.cine = true
	world.cam_focus = self
	world.big_moment(2.9)

func _ult_process(delta: float) -> void:
	ult_t += delta
	inv = 0.5
	if ult_t < ULT_CUT.cut_end:
		world.cine = true
		world.cam_zoom = minf(1.0, ult_t / ULT_CUT.zoom)
		if ult_t - delta < ULT_CUT.cut_start and ult_t >= ULT_CUT.cut_start and world.main and world.main.lily_cutin:
			world.main.lily_cutin.play()
		_show("atk_jabkick", 13)   # 構え
		return
	if not ult_jumped:   # 狙った敵の横へ瞬間移動（元の場所と着いた所に蒼い光）
		ult_jumped = true
		world.cine = false
		if not _alive(target):
			target = _ult_target()
		if target == null:
			_end_ult()
			return
		_ghost()
		world.fx.charge(position + Vector3(0, 1.0, 0), 1.0, 0.18)
		var side := -1.0 if position.x < target.position.x else 1.0
		position = Vector3(clampf(target.position.x + side * 1.0, world.ROOM_X.x, world.ROOM_X.y), 0, target.position.z)
		face = 1 if target.position.x >= position.x else -1
		world.fx.zap(position + Vector3(0, 1.0, 0.1), 6, 1.0)
	world.cam_zoom = maxf(0.0, 1.0 - (ult_t - ULT_CUT.cut_end) / 0.35)
	t = ult_t - ULT_CUT.cut_end
	if _skill_step(delta):
		_end_ult()

func _end_ult() -> void:
	world.ally_ult_gain = true
	world.cine = false
	world.cam_zoom = 0.0
	world.cam_focus = null
	state = "move"
	clip = "idle"
	mv = ""
	t = 0.0
	cd = 0.4
	_show("idle", 0)

## 撮影用：決まった技を出させる（id＝rush・barrage・storm・ult）
func force_skill(id: String, e: Node3D) -> void:
	if id == "ult":
		_start_ult(e)
	else:
		_start_skill(id, e)
