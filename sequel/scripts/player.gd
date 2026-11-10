extends Node3D
## ラナ（新しい絵 rana2、2026-11-06）。帯の中を左右・奥行きに動く。攻撃は A小→B中→C大 の連撃＋長押し（回転斬り）・回避・被弾・ダウン。
## 絵は assets/rana2/rana2.json（tools/make_rana2.py --game）：クリップごとのコマ [ページ, x, y, w, h, 足元から見た左上 x, y]、
## 再生の fps、root＝攻撃の前進（絵から外した体の移動、px）。前進はラナの位置を動かす（当たりと絵がずれない）。
## 攻撃は元の動画（24fps）を3コマおきに 24fps で流す＝3倍速。当たりの瞬間は元の動画のコマ番号÷72 秒（剣が最も届くコマを測った）。

const SPR := preload("res://scripts/sprite_bb.gdshader")
const Skills := preload("res://scripts/skills.gd")
const WALK := 2.8
const RUN := 6.2
const DEPTH_K := 0.75        # 奥行きの移動は少し遅く（アラド型）
const HEIGHT_M := 1.85       # 画面での背の高さ（構えの絵の背＝この高さ。前作の基準 205 に合わせるかは未決）
const DODGE_T := 0.24
const DODGE_D := 4.0
const HURT_T := 0.42
const HOLD_T := 0.35         # この長さ押し続けると長押しの技（回転斬り）
## 攻撃の速さ（2026-11-06、ユーザー「つながりが遅くて爽快感がない」）：連撃 1.5 倍・回転斬り 1.25 倍。次の技は当たりの 0.04 秒後から受け付ける
const ATK_SPD := {"atkA": 1.5, "atkB": 1.5, "atkC": 1.5, "hold": 1.25}
const CANCEL_AFTER := 0.04
const REACH_ADD := 0.4       # 当たりの距離を広げる（m）
const LANE_ADD := 0.25

# 斬撃のエフェクト（fx.gd の slash）。縦＝画面に立つ弧、横＝床と平行の弧。色は味方の青
const SL_THRUST := {"plane": "v", "r": 2.64, "w": 0.31, "a0": 14.0, "a1": -10.0, "y": 1.15, "life": 0.25, "draw": 0.05}
const SL_DOWN := {"plane": "v", "r": 2.18, "w": 0.84, "a0": 120.0, "a1": -50.0, "y": 0.95, "life": 0.33, "draw": 0.07}
const SL_SWEEP := {"plane": "h", "r": 2.42, "w": 0.77, "a0": 110.0, "a1": -50.0, "y": 1.0, "life": 0.3, "draw": 0.06, "squash": 0.55, "tilt": 6.0}
const SL_BACK := {"plane": "h", "r": 2.07, "w": 0.7, "a0": -40.0, "a1": 120.0, "y": 0.9, "life": 0.3, "draw": 0.06, "squash": 0.55, "tilt": -8.0}
const SL_BIG := {"plane": "v", "r": 2.99, "w": 1.19, "a0": 150.0, "a1": -60.0, "y": 1.1, "life": 0.43, "draw": 0.08}   # C の締め（元の白い大きな弧をコードで）
const SL_SPIN := {"plane": "h", "r": 2.53, "w": 0.7, "a0": -170.0, "a1": 170.0, "y": 0.85, "life": 0.33, "draw": 0.08, "squash": 0.6}

var world               # battle.gd
var room_x := Vector2(-19, 19)
var belt_z := Vector2(-3.2, 3.5)
var move_in := Vector2.ZERO   # タッチ・キーの入力（−1〜1）
var run_in := false
var sprite: Sprite3D
var mat: ShaderMaterial
var shadow: MeshInstance3D
var refl: Sprite3D
var clips := {}
var pages := {}
var clip := "idle"
var t := 0.0
var face := 1
var state := "move"   # move / atk / dodge / hurt / down
var atk_next := "atkA"
var atk_held := false     # 攻撃のボタンを押している
var held_t := 0.0
var hold_fired := false
var queued_hold := false
var root_prev := 0.0      # 攻撃の前進（px）の前のコマの値
var ghost_t := 0.0
var ghosts := []          # 回避の残像 [{node, t}]
var dust_done := false
var dodge_t := 0.0
var queued := false
var px_size := 0.005
var hold_hit := []
var skills := {}          # skills.gd の表
var skill_cd := {}        # id -> 残りの待ち（秒）
var skill_id := ""        # 使っている技
var skill_uses := {}      # id -> 使った回数（確認用）
var skill_ready_flash := {}   # id -> 使えるようになった瞬間の光（秒）
var inv := 0.0
var flash := 0.0
var kb := 0.0
var down_dir := 1
var tab := {}         # clip -> {starts, total, hits:[[t, spec]], cancel}
var hit_i := 0
var locked := false   # 選ぶ画面・結果の画面の間は動かない

func _ready() -> void:
	clips = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rana2/rana2.json")).clips
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/rana2/rana2.json"))
	px_size = HEIGHT_M / float(d.px_h)
	for pg in d.pages:   # 最初の攻撃で読み込みの引っかかりが出ないよう、先に全部読む
		_tex(pg)
	_build_tables()
	skills = Skills.table()
	sprite = Sprite3D.new()
	sprite.region_enabled = true
	sprite.centered = false
	mat = ShaderMaterial.new()
	mat.shader = SPR
	sprite.material_override = mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	shadow = world.make_shadow(1.3)
	add_child(shadow)
	refl = world.make_refl()
	add_child(refl)
	_show_frame("idle", 0)

## 当たりの時間表：元の動画のコマ番号 ÷ 72（3コマおきを 24fps＝3倍速）。距離は m（剣が最も届くコマを測った値＋余裕）。
##   A 突き：18コマ目、前へ約 1.9m。B 斬り下ろし：33コマ目、約 1.7m。C 連続斬り：15・24・33・42・60（前後両方、最後が強い）。
##   長押し 回転斬り：24・36・45・57・66・75（前後両方、最後が強い）。
func _build_tables() -> void:
	var mk := func(c: String, hits: Array, cancel_after: float) -> Dictionary:
		var n: int = clips[c].frames.size()
		var sp: float = ATK_SPD[c]
		var tot: float = n / float(clips[c].fps) / sp
		var hs := []
		for h in hits:
			var spec: Dictionary = h[1].duplicate()
			spec.r = float(spec.r) + REACH_ADD
			spec.lane = float(spec.lane) + LANE_ADD
			hs.append([float(h[0]) / 72.0 / sp, spec])
		return {"total": tot, "hits": hs, "cancel": hs[hs.size() - 1][0] + cancel_after}
	var a: Dictionary = mk.call("atkA", [[18, {"side": 1, "r": 2.4, "lane": 0.85, "dmg": 18.0, "strong": false, "shake": 4.0, "slash": SL_THRUST}]], CANCEL_AFTER)
	var b: Dictionary = mk.call("atkB", [[33, {"side": 1, "r": 2.2, "lane": 1.0, "dmg": 26.0, "strong": false, "shake": 6.0, "slash": SL_DOWN}]], CANCEL_AFTER)
	var c_hits := []
	var k := 0
	for f in [15, 24, 33, 42]:
		c_hits.append([f, {"side": 0, "r": 2.1, "lane": 1.1, "dmg": 12.0, "strong": false, "shake": 4.0, "slash": SL_SWEEP if k % 2 == 0 else SL_BACK}])
		k += 1
	c_hits.append([60, {"side": 1, "r": 2.6, "lane": 1.2, "dmg": 24.0, "strong": true, "shake": 11.0, "slash": SL_BIG}])
	var c: Dictionary = mk.call("atkC", c_hits, CANCEL_AFTER)
	var h_hits := []
	for f in [24, 36, 45, 57, 66]:
		h_hits.append([f, {"side": 0, "r": 2.3, "lane": 1.3, "dmg": 14.0, "strong": false, "shake": 5.0, "slash": SL_SPIN}])
	h_hits.append([75, {"side": 0, "r": 2.4, "lane": 1.4, "dmg": 26.0, "strong": true, "shake": 12.0, "slash": SL_SPIN}])
	var h: Dictionary = mk.call("hold", h_hits, 0.08)
	tab = {"atkA": a, "atkB": b, "atkC": c, "hold": h}

func _tex(name: String) -> Texture2D:
	if not pages.has(name):
		pages[name] = load("res://assets/rana2/" + name)
	return pages[name]

func _show_frame(c: String, i: int) -> void:
	var fr: Array = clips[c].frames
	var f: Array = fr[clampi(i, 0, fr.size() - 1)]
	var tex := _tex(f[0])
	if sprite.texture != tex:
		sprite.texture = tex
		mat.set_shader_parameter("tex", tex)
	sprite.region_rect = Rect2(f[1], f[2], f[3], f[4])
	sprite.pixel_size = px_size
	# 足元（原点）から見た左上の位置。Sprite3D は y が上向き
	var ox: float = f[5]
	var oy: float = f[6]
	if face < 0:
		ox = -ox - f[3]
	sprite.flip_h = face < 0
	sprite.offset = Vector2(ox, -oy - f[4])

func _frames(c: String) -> int:
	return clips[c].frames.size()

func _fidx(c: String, tt: float) -> int:
	return mini(int(tt * float(clips[c].fps)), _frames(c) - 1)

func _root(c: String, tt: float) -> float:
	var r: Array = clips[c].root
	var x: float = tt * float(clips[c].fps)
	var i := clampi(int(x), 0, r.size() - 1)
	var j := mini(i + 1, r.size() - 1)
	return lerpf(float(r[i]), float(r[j]), clampf(x - int(x), 0.0, 1.0))

## 攻撃：押した瞬間に連撃の次の技。押し続けると長押しの技（attack_press／attack_release。tap は attack()）
func attack() -> void:
	if locked:
		return
	if state == "atk" or state == "dodge":
		queued = true
		return
	if state != "move":
		return
	_start_attack(atk_next)

func attack_press() -> void:
	if locked:
		return
	atk_held = true
	held_t = 0.0
	hold_fired = false
	attack()

func attack_release() -> void:
	atk_held = false

func _start_attack(c: String) -> void:
	# 入力の向きへ振り向いてから斬る
	if absf(move_in.x) > 0.3:
		face = 1 if move_in.x > 0 else -1
	state = "atk"
	clip = c
	if c == "atkA": atk_next = "atkB"
	elif c == "atkB": atk_next = "atkC"
	else: atk_next = "atkA"
	t = 0.0
	hit_i = 0
	root_prev = 0.0
	queued = false
	queued_hold = false

func _end_attack() -> void:
	state = "move"
	clip = "idle"
	t = 0.0
	atk_next = "atkA"
	_show_frame(clip, 0)

## スキル：使えたら true。move・atk（連撃の当たりの後）から。CD 中・回避・被弾・ダウン・locked は不可
func can_use_skill(id: String) -> bool:
	if locked or id == "" or not skills.has(id) or float(skill_cd.get(id, 0.0)) > 0.0:
		return false
	if state == "move":
		return true
	if state == "atk" and tab.has(clip):
		return t >= float(tab[clip].cancel)
	return false

func use_skill(id: String) -> bool:
	if not can_use_skill(id):
		return false
	var sk: Dictionary = skills[id]
	if absf(move_in.x) > 0.3:
		face = 1 if move_in.x > 0 else -1
	state = "skill"
	skill_id = id
	clip = sk.clip
	t = 0.0
	hit_i = 0
	root_prev = 0.0
	queued = false
	queued_hold = false
	atk_next = "atkA"
	skill_cd[id] = float(sk.cd)
	skill_uses[id] = int(skill_uses.get(id, 0)) + 1
	world.big_moment(float(sk.total) * 0.85)   # 大技の暗転（specs/vfx_overhaul.md）
	return true

func _skill_event(spec: Dictionary) -> void:
	var hs := spec.duplicate()
	hs.dmg = Skills.BASE_DMG * float(spec.k)
	if spec.shape == "band":
		hs.x0 = position.x + face * float(spec.x0)
		hs.x1 = position.x + face * float(spec.x1)
	world.player_skill(hs, self)

# ---------- 必殺技（2026-11-07）：ゲージが満タンの時。止まる → 寄って立ち絵のカットイン → 引きながら画面全体へ多段 → 決め ----------
const ULT_T := {"zoom": 0.3, "cut_start": 0.3, "cut_end": 1.35, "end": 2.45}
const ULT_HITS := [1.42, 1.52, 1.62, 1.72, 1.82, 1.92, 2.02]
const ULT_FINAL := 2.18
var ult_i := 0
var ult_t := 0.0

func can_use_ult() -> bool:
	if world.cine or (world.ally and world.ally.state == "ult"):   # リリィの必殺技の最中は出さない
		return false
	return not locked and world.ult >= world.ULT_COST and (state == "move" or (state == "atk" and tab.has(clip) and t >= float(tab[clip].cancel)))

func use_ult() -> bool:
	if not can_use_ult():
		return false
	world.ult = maxf(0.0, world.ult - world.ULT_COST)
	world.ult_gain = false
	if absf(move_in.x) > 0.3:
		face = 1 if move_in.x > 0 else -1
	state = "ult"
	ult_t = 0.0
	ult_i = 0
	root_prev = 0.0
	queued = false
	queued_hold = false
	atk_next = "atkA"
	world.cine = true
	world.big_moment(2.3)
	return true

func _ult_process(delta: float) -> void:
	ult_t += delta
	inv = 0.4   # 必殺技の間は当たらない
	var zt: float = ULT_T.zoom
	if ult_t < ULT_T.cut_end:
		world.cam_zoom = minf(1.0, ult_t / zt)
		if ult_t - delta < ULT_T.cut_start and ult_t >= ULT_T.cut_start and world.main and world.main.cutin:
			world.main.cutin.play()   # 寄りきってから立ち絵が差し込む
		_show_frame("idle", 0)
		return
	world.cine = false
	world.cam_zoom = maxf(0.0, 1.0 - (ult_t - ULT_T.cut_end) / 0.35)
	var tt: float = (ult_t - ULT_T.cut_end) * 1.3
	_show_frame("atkC", _fidx("atkC", tt))
	var fx = world.fx
	while ult_i < ULT_HITS.size() and ult_t >= ULT_HITS[ult_i]:
		var sl: Dictionary = [SL_SWEEP, SL_DOWN, SL_BACK, SL_SPIN][ult_i % 4].duplicate()
		sl.r = float(sl.r) * 1.6
		sl.w = float(sl.w) * 1.3
		sl.pal = world.GOLD_PAL
		world._attack_from(self, {"side": 0, "shape": "both", "r": 8.0, "lane": 4.0, "dmg": 18.0 * 0.8, "strong": false, "kb": 0.2, "slash": sl}, world.atk_mul)
		if ult_i % 2 == 0:
			fx.rift(position.x, position.x + 7.0 * (1 if ult_i % 4 == 0 else -1), position.z, 1)
		world.shake = maxf(world.shake, 8.0)
		ult_i += 1
	if ult_i == ULT_HITS.size() and ult_t >= ULT_FINAL:
		ult_i += 1
		var big: Dictionary = SL_BIG.duplicate()
		big.r = float(big.r) * 1.5
		big.w = float(big.w) * 1.5
		big.pal = world.GOLD_PAL
		world._attack_from(self, {"side": 0, "shape": "both", "r": 8.0, "lane": 4.0, "dmg": 18.0 * 4.0, "strong": true, "kb": 3.0, "freeze_add": 0.2, "slash": big}, world.atk_mul)
		fx.vortex_burst(position, 6.0)
		fx.shockwave(position + Vector3(0, 1.0, 0), 2.2, 0.6, 0.9)
		world.chroma_hit(1.0)
		if world.fx2d and not fx.legacy:
			world.fx2d.big(position + Vector3(0, 1.2, 0), world.fx2d.GOLD, fx, position)
		world.shake = maxf(world.shake, 22.0)
		if world.main and world.main.cutin:
			world.main.cutin.flash_white()
	if ult_t >= ULT_T.end:
		world.ult_gain = true
		world.cam_zoom = 0.0
		_end_attack()

func dodge() -> void:
	if locked:
		return
	if state == "dodge" or state == "down" or state == "hurt":
		return
	state = "dodge"
	dodge_t = 0.0
	ghost_t = 0.0
	queued = false

func can_be_hit() -> bool:
	return inv <= 0.0 and state != "dodge" and state != "down" and state != "ult"

func on_hurt(dir: int, dead: bool) -> void:
	flash = 0.25
	if state == "skill" and not dead:   # 技の間はのけぞらない（ダメージは受ける。無敵ではない）
		inv = 0.35
		return
	inv = HURT_T + 0.3   # 被弾の動きが終わってから 0.3 秒は当たらない（囲まれて被弾し続けないように）
	queued = false
	queued_hold = false
	if dead:
		state = "down"
		t = 0.0
		down_dir = dir
		face = -dir
		dust_done = false
		return
	state = "hurt"
	t = 0.0
	kb = dir * 2.0
	face = -dir

## 回避の残像（青＝味方）：今の絵を写した板を置いて、すぐ薄れさせる
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
	gm.set_shader_parameter("tint", Color(0.45, 0.7, 1.0, 0.55))
	gm.set_shader_parameter("flash", Color(0.35, 0.6, 1.0, 0.6))
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.position = position - Vector3(0, 0, 0.05)
	world.add_child(g)
	ghosts.append({"node": g, "t": 0.0})

func _update_ghosts(delta: float) -> void:
	for i in range(ghosts.size() - 1, -1, -1):
		var g: Dictionary = ghosts[i]
		g.t += delta
		var a: float = 0.55 * (1.0 - g.t / 0.24)
		if a <= 0.0:
			g.node.queue_free()
			ghosts.remove_at(i)
		else:
			g.node.material_override.set_shader_parameter("tint", Color(0.45, 0.7, 1.0, a))

func _physics_process(delta: float) -> void:
	var mv := move_in
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): mv.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): mv.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): mv.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): mv.y += 1
	if mv.length() > 1.0: mv = mv.normalized()
	if locked:
		mv = Vector2.ZERO
	flash = maxf(0.0, flash - delta)
	_update_ghosts(delta)
	var blink := inv > 0.0 and state != "down" and int(Time.get_ticks_msec() / 42) % 2 == 0
	mat.set_shader_parameter("flash", Color(1.0, 0.25, 0.2, 0.7 if flash > 0.0 else 0.0))
	for id in skill_cd:   # 待ちは止め（ヒットストップ）中も進める
		if float(skill_cd[id]) > 0.0:
			skill_cd[id] = maxf(0.0, float(skill_cd[id]) - delta)
			if skill_cd[id] <= 0.0:
				skill_ready_flash[id] = 0.25
	for id in skill_ready_flash.keys():
		skill_ready_flash[id] = float(skill_ready_flash[id]) - delta
		if skill_ready_flash[id] <= 0.0:
			skill_ready_flash.erase(id)
	if state == "ult":
		_ult_process(delta)
		mat.set_shader_parameter("tint", Color(1, 1, 1, 1))
		world.apply_light(sprite, mat, refl, position)
		return
	var dt: float = world.dt(delta)
	if dt <= 0.0:
		return
	inv = maxf(0.0, inv - dt)
	# 長押し：押し続けて HOLD_T を超えたら回転斬り（A の当たりの前なら A を取り消して出す。それ以外は次の技にする）
	if atk_held and not locked:
		held_t += dt
		if held_t >= HOLD_T and not hold_fired:
			hold_fired = true
			if state == "atk" and clip == "atkA" and t < tab.atkA.hits[0][0]:
				_start_attack("hold")
			elif state == "atk" or state == "dodge":
				queued_hold = true
			elif state == "move":
				_start_attack("hold")
	var running := run_in or Input.is_key_pressed(KEY_SHIFT) or mv.length() > 0.9
	t += dt
	var tint := Color(1, 1, 1, 0.55 if blink else 1.0)
	mat.set_shader_parameter("rot", 0.0)
	match state:
		"move":
			if absf(mv.x) > 0.1:
				face = 1 if mv.x > 0 else -1
			var sp := RUN if running else WALK
			position.x += mv.x * sp * dt
			position.z += mv.y * sp * DEPTH_K * dt
			var c := "idle"
			if mv.length() > 0.12:
				c = "run" if running else "walk"
			if c != clip:
				clip = c
				t = 0.0
			_show_frame(clip, int(t * float(clips[clip].fps)) % _frames(clip))
		"atk":
			var tb: Dictionary = tab[clip]
			# 前進：絵から外した体の移動を、位置の移動にする
			var te: float = t * float(ATK_SPD[clip])
			var r := _root(clip, te)
			position.x += face * (r - root_prev) * px_size
			root_prev = r
			# 当たりの瞬間ごとに判定（1振りで1回）
			while hit_i < tb.hits.size() and t >= tb.hits[hit_i][0]:
				world.player_attack(tb.hits[hit_i][1])
				hit_i += 1
			if (queued or queued_hold) and t >= tb.cancel:
				_start_attack("hold" if queued_hold else atk_next)
				_show_frame(clip, 0)
			elif t >= tb.total:
				_end_attack()
			else:
				_show_frame(clip, _fidx(clip, te))
		"skill":
			var sk: Dictionary = skills[skill_id]
			var te: float = t * float(sk.spd)
			if absf(mv.x) > 0.3:   # 移動の入力は向きだけ
				face = 1 if mv.x > 0 else -1
			var r := _root(clip, te)
			position.x += face * (r - root_prev) * px_size * 0.3   # その場の技：前進は 0.3 倍
			root_prev = r
			var ev: Array = sk.ev
			while hit_i < ev.size() and t >= float(ev[hit_i][0]):
				_skill_event(ev[hit_i][1])
				hit_i += 1
			if t >= float(sk.total) and hit_i >= ev.size():
				skill_id = ""
				_end_attack()
			else:
				_show_frame(clip, _fidx(clip, te))
		"dodge":
			dodge_t += dt
			var dir := mv.normalized() if mv.length() > 0.2 else Vector2(face, 0)
			if absf(dir.x) > 0.2:
				face = 1 if dir.x > 0 else -1
			position.x += dir.x * DODGE_D / DODGE_T * dt
			position.z += dir.y * DODGE_D / DODGE_T * DEPTH_K * dt
			tint = Color(0.75, 0.9, 1.0, 0.85)
			_show_frame("run", int(dodge_t * 60.0) % _frames("run"))   # 走りを速く流す
			ghost_t -= dt
			if ghost_t <= 0.0:
				ghost_t = 0.035
				_ghost()
			if dodge_t >= DODGE_T:
				state = "move"
				if queued_hold:
					_start_attack("hold")
				elif queued:
					_start_attack(atk_next)
		"hurt":
			# 当たりの瞬間の3コマ（hit の最初の約0.5秒）→ のけぞりと戻りはコード（傾けて戻す）
			position.x += kb * dt
			kb *= pow(0.002, dt)
			var hi := mini(int(t / 0.07), 2)
			_show_frame("hurt", hi)
			var lean := sin(clampf(t / HURT_T, 0.0, 1.0) * PI)
			mat.set_shader_parameter("rot", face * 0.22 * lean)
			if t >= HURT_T:
				state = "move"
				clip = "idle"
				t = 0.0
		"down":
			# 倒れて起き上がるまでを、元の動画の2コマおきで流す（土煙はコード）
			var n := _frames("down")
			var fi := _fidx("down", t)
			_show_frame("down", fi)
			if t < 0.3:
				position.x += down_dir * 2.0 * dt * (1.0 - t / 0.3)
			if not dust_done and fi >= 8:
				dust_done = true
				world.fx.dust(position + Vector3(-face * 1.1, 0, 0.1), 1.6)
			if t >= n / float(clips.down.fps):
				state = "move"
				clip = "idle"
				t = 0.0
				inv = 1.5
				world.player_revived()
	mat.set_shader_parameter("tint", tint)
	world.apply_light(sprite, mat, refl, position)
	position.x = clampf(position.x, room_x.x, room_x.y)
	position.z = clampf(position.z, belt_z.x, belt_z.y)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and not e.echo:
		if e.keycode == KEY_J or e.keycode == KEY_Z:
			if e.pressed: attack_press()
			else: attack_release()
		elif (e.keycode == KEY_K or e.keycode == KEY_X) and e.pressed:
			dodge()
		elif e.pressed and e.keycode == KEY_L:
			use_ult()
		elif e.pressed and (e.keycode == KEY_U or e.keycode == KEY_I or e.keycode == KEY_O):
			var slot: int = [KEY_U, KEY_I, KEY_O].find(e.keycode)
			if world.main and world.main.progress:
				use_skill(str(world.main.progress.skill_slots[slot]))

## 撮影用：状態を固定する
func debug_state(s: String) -> void:
	set_physics_process(false)
	match s:
		"walk":
			face = -1
			_show_frame("walk", 6)
		"atk":
			face = 1
			_show_frame("atkA", 6)
		_:
			face = 1
			_show_frame("idle", 0)
