extends Node3D
## 敵兵（仮の絵＝前作の一般兵）。帯の中でラナへ寄り、間合いに入ると攻撃の連番を流す。
## 状態：walk（寄る）／atk（攻撃。予兆→当たり→戻り）／stun（ひるみ）／dying（倒れて消える）。
## 数値は前作 battle/ の値を、ラナの背（205px＝1.85m）で m に直したもの。

const SPR := preload("res://scripts/sprite_bb.gdshader")
const HEIGHT := {"1": 2.10, "3": 2.03, "g1": 2.7}   # 前作の HEIGHT（f1 233・f3 225 px）÷205×1.85。g1＝ボス（前作の敵将。大きめに）
const FOE_SPD := 2.4       # 攻撃の連番の速さ（一騎打ちの何倍か。前作は3.3。予兆を読めるよう少し遅く）
const ATK_START := 1.15    # この左右の距離で攻撃を始める
const ATK_REACH := 1.45    # 当たりの瞬間に、この距離までなら当たる
const ATK_LANE := 0.45     # 奥行きのずれがこれ以内なら当たる（奥行きをずらして避けられる）
const STOP := 0.95         # これより近くへは歩かない

var battle               # battle.gd
var kind := "1"
var clips: Dictionary
var pages := {}
var sprite: Sprite3D
var mat: ShaderMaterial
var shadow: MeshInstance3D
var refl: Sprite3D
var hpbar: MeshInstance3D
var hp := 30.0
var hp_max := 30.0
var dmg := 8
var sp := 1.2
var size := 1.0
var yo := 0.0             # 奥行きのばらけ（寄る先のずれ）
var face := -1
var state := "walk"
var t := 0.0
var atk_cd := 0.3
var atk := {}             # {clip, t, starts, hit_t, end_t, done, warn}
var stun := 0.0
var kx := 0.0
var flash := 0.0
var bar_t := 0.0
var die_t := 0.0
var die_dir := 1
var lift_y := 0.0         # 浮かされた高さ（m）。絵だけを持ち上げる（空中の状態は別の作業）
var lift_v := 0.0
# ボス（前作の敵将を仮置き）：体力が大きい・のけぞらない・3回に1回は左右両側の大振り（床の予兆が長い）
var boss := false
var reach := ATK_REACH
var lane := ATK_LANE
var atk_start := ATK_START
var stop_d := STOP
var atk_n := 0
var spd := FOE_SPD

func setup(b, k: String, c: Dictionary, level: int) -> void:
	battle = b
	kind = k
	clips = c
	size = randf_range(0.94, 1.06)
	hp_max = (60.0 + level * 10.0) * b.foe_hp_mul   # 前作（22+5n）は2振りで倒れ、連携を見せる前に終わったので硬く
	hp = hp_max
	dmg = int(round((7 + level) * b.foe_dmg_mul))
	sp = (1.13 + randf_range(0.0, 0.38) + level * 0.03)
	yo = randf_range(-1.0, 1.0) * 1.1
	t = randf_range(0.0, 6.0)
	atk_cd = randf_range(0.05, 0.6)

## ボスにする（spawn の直後に呼ぶ）
func make_boss(hp_val: float, dmg_val: int) -> void:
	boss = true
	size = 1.0
	hp_max = hp_val
	hp = hp_val
	dmg = dmg_val
	sp = 1.05
	reach = 2.6
	lane = 0.75
	atk_start = 2.1
	stop_d = 1.7
	atk_cd = 1.2
	spd = 2.0
	yo = 0.0
	if shadow:
		shadow.scale = Vector3(1.6, 1, 1.6)

func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.region_enabled = true
	sprite.centered = false
	mat = ShaderMaterial.new()
	mat.shader = SPR
	sprite.material_override = mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	shadow = battle.make_shadow(1.1 * size)
	add_child(shadow)
	refl = battle.make_refl()
	add_child(refl)
	hpbar = battle.make_hpbar()
	hpbar.position.y = HEIGHT[kind] * size + 0.25
	hpbar.visible = false
	add_child(hpbar)
	_show("walk", 0)

func height() -> float:
	return HEIGHT[kind] * size

func _tex(name: String) -> Texture2D:
	if not pages.has(name):
		pages[name] = load("res://assets/foe/" + name)
	return pages[name]

func _show(c: String, i: int) -> void:
	var cl: Dictionary = clips[c]
	var fr: Array = cl.frames
	var f: Array = fr[clampi(i, 0, fr.size() - 1)]
	var tex := _tex(f[0])
	if sprite.texture != tex:
		sprite.texture = tex
		mat.set_shader_parameter("tex", tex)
	sprite.region_rect = Rect2(f[1], f[2], f[3], f[4])
	sprite.pixel_size = HEIGHT[kind] * size / float(cl.h)
	var flip: bool = (face != int(cl.face))
	var ox: float = f[5]
	if flip:
		ox = -ox - f[3]
	sprite.flip_h = flip
	sprite.offset = Vector2(ox, -f[6] - f[4])

func _physics_process(delta: float) -> void:
	var dt: float = battle.dt(delta)
	flash = maxf(0.0, flash - delta)
	if battle.fx.legacy:
		mat.set_shader_parameter("flash", Color(0.75, 0.88, 1.0, 0.3 * flash / 0.1 if flash > 0.0 else 0.0))
	else:   # 2026-11-07：被弾の白光り（色を白へ置き換え、0.1 秒で引く。specs/vfx_recipes.md）
		var fk: float = flash / 0.1
		mat.set_shader_parameter("flash_mix", Color(1.0, 1.0, 1.0, 0.85 * fk * fk))
		mat.set_shader_parameter("flash", Color(0.75, 0.88, 1.0, 0.15 * fk))
	battle.apply_light(sprite, mat, refl, position)
	bar_t = maxf(0.0, bar_t - delta)
	hpbar.visible = bar_t > 0.0 and state != "dying"
	if dt <= 0.0:
		return
	t += dt
	if lift_y > 0.0 or lift_v > 0.0:
		lift_v -= 16.0 * dt
		lift_y = maxf(0.0, lift_y + lift_v * dt)
		if lift_y <= 0.0:
			lift_v = 0.0
		sprite.position.y = lift_y
		refl.position.y = -lift_y
	if boss:   # 立ち絵1枚の歩き＝構えの揺れ（前作と同じ）
		sprite.position.y = absf(sin(t * 3.2)) * 0.05 if state == "walk" else 0.0
	var pl: Node3D = battle.player
	match state:
		"dying":
			die_t += dt
			var k := die_t / (1.2 if boss else (0.45 if battle.fx.legacy else 0.75))   # 溶け消えは少し長く（縁が燃えるのを見せる）
			position.x += die_dir * 1.4 * dt * (1.0 - k)
			mat.set_shader_parameter("rot", -die_dir * 1.25 * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0)))
			mat.set_shader_parameter("tint", Color(1, 1, 1, 1.0 - k))
			shadow.transparency = k
			if k >= (3.0 if boss else 1.0):
				battle.remove_enemy(self)
			return
		"stun":
			stun -= dt
			position.x += kx * dt
			kx *= pow(0.0005, dt)
			if stun <= 0.0:
				state = "walk"
			_show("walk", 0)
		"atk":
			atk.t += dt
			var st: Array = atk.starts
			var fi := 0
			while fi + 1 < st.size() and st[fi + 1] <= atk.t:
				fi += 1
			_show(atk.clip, fi)
			if not atk.done and atk.t >= atk.hit_t:
				atk.done = true
				atk.warn = null
				var dx: float = (pl.position.x - position.x) * face
				var dz: float = absf(pl.position.z - position.z)
				if atk.wide:
					dx = absf(pl.position.x - position.x)
				if dx > -0.3 and dx < float(atk.reach) and dz < float(atk.lane):
					battle.enemy_hits_player(self)
				# 仲間（リリィ）も同じ範囲にいれば当たる（体力は無い。揺れて押し戻されるだけ。2026-11-06）
				var al: Node3D = battle.ally
				if al and al.can_be_hit():
					var adx: float = (al.position.x - position.x) * face
					if atk.wide:
						adx = absf(al.position.x - position.x)
					if adx > -0.3 and adx < float(atk.reach) and absf(al.position.z - position.z) < float(atk.lane):
						var ad := 1 if al.position.x >= position.x else -1
						battle.fx.hurt(al.position + Vector3(0, 1.0, 0), ad)
						al.on_hurt(ad)
			if atk.t >= atk.end_t:
				state = "walk"
				atk_cd = 0.8 if boss else 1.0
		"walk":
			var dx: float = pl.position.x - position.x
			face = 1 if dx >= 0 else -1
			if absf(dx) > stop_d * size:
				position.x += signf(dx) * sp * dt
			# 遠いほど奥行きにばらけ、近づくとラナの奥行きへ寄る
			var fk := clampf((absf(dx) - 0.5) / 2.2, 0.25, 1.0)
			var tz: float = clampf(pl.position.z + yo * fk, battle.BELT_Z.x, battle.BELT_Z.y)
			var dz: float = tz - position.z
			if absf(dz) > 0.05:
				position.z += signf(dz) * minf(absf(dz), sp * 0.6 * dt)
			atk_cd -= dt
			if absf(dx) < atk_start * size and absf(pl.position.z - position.z) < lane * 0.8 and atk_cd <= 0.0 and battle.player_alive():
				_start_atk()
			else:
				var wc: Dictionary = clips.walk
				var moving: bool = absf(dx) > stop_d * size or absf(dz) > 0.05
				var wf: int = int((t + yo) * wc.fps * sp / 1.2) % wc.frames.size() if moving else 0
				_show("walk", wf)
	position.z = clampf(position.z, battle.BELT_Z.x - 0.1, battle.BELT_Z.y + 0.1)
	position.x = clampf(position.x, battle.ROOM_X.x - 0.6, battle.ROOM_X.y + 0.6)

func _start_atk() -> void:
	var names := []
	for k in clips:
		if str(k).begins_with("atk"):
			names.append(k)
	var c: String = names[randi() % names.size()]
	var cl: Dictionary = clips[c]
	atk_n += 1
	var wide := boss and atk_n % 3 == 0
	var s_: float = spd * (0.7 if wide else 1.0)   # 大振りは遅い（予兆が長い）
	var acc := 0.0
	var starts := []
	var hit_t := 0.0
	for i in cl.durs.size():
		starts.append(acc / 1000.0 / s_)
		if i == int(cl.hit):
			hit_t = acc / 1000.0 / s_
		acc += float(cl.durs[i])
	state = "atk"
	var r: float = (3.4 if wide else reach) * size
	var ln: float = 1.25 if wide else lane
	atk = {"clip": c, "t": 0.0, "starts": starts, "hit_t": hit_t, "end_t": acc / 1000.0 / s_, "done": false,
		"wide": wide, "reach": r, "lane": ln}
	# 床の予兆：当たる範囲（前へ reach、奥行き ±lane。大振りは左右両側）
	var cx := position.x if wide else position.x + face * r * 0.5
	var w := r * 2.0 if wide else r
	atk.area = Rect2(cx - w * 0.5, position.z - ln, w, ln * 2.0)
	atk.warn = battle.fx.warn(Vector3(cx, 0, position.z), Vector2(w, ln * 2.0), hit_t)

## 浮かせる（リリィの上段・ジャブの2発目）：v＝上向きの速さ（m/秒）。ボスは浮かない
func lift_up(v: float) -> void:
	if boss or state == "dying":
		return
	lift_v = maxf(lift_v, v)
	stun = maxf(stun, 0.45)

## ラナの攻撃が当たった
func take_hit(d: float, dir: int, strong: bool) -> void:
	if state == "dying":
		return
	hp -= d
	flash = 0.1
	bar_t = 0.0 if boss else 1.6
	hpbar.material_override.set_shader_parameter("ratio", maxf(0.0, hp / hp_max))
	if boss:   # のけぞらない（少しだけ押される）
		position.x += dir * (0.12 if strong else 0.04)
		if hp <= 0.0:
			if atk.get("warn") != null and not atk.done:
				battle.fx.drop(atk.warn)
			atk = {}
			state = "dying"
			die_t = 0.0
			die_dir = dir
			battle.fx.kill(position, dir, height())
			battle.on_kill(self)
		return
	if atk.get("warn") != null and not atk.done:
		battle.fx.drop(atk.warn)
	atk = {}
	stun = maxf(stun, 0.5 if strong else 0.16)
	kx = dir * (3.9 if strong else 1.6)
	state = "stun"
	if hp <= 0.0:
		state = "dying"
		die_t = 0.0
		die_dir = dir
		battle.fx.kill(position, dir, height())
		battle.on_kill(self)
