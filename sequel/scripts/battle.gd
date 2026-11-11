extends Node3D
## 戦闘のまとめ役：敵の群れの出現、当たりの判定、ヒットストップ（止め）、画面の揺れ、ラナの体力。
## 敵は小さな群れで左右から来る。倒しきると少しして次の群れ（だんだん増える）。

const Enemy := preload("res://scripts/enemy.gd")
const HPBAR := preload("res://scripts/hpbar.gdshader")

var BELT_Z := Vector2(-3.2, 3.5)
var ROOM_X := Vector2(-19, 19)
var player: Node3D
var main                  # main.gd（スキルの枠・進み具合を読む）
## 必殺技（2026-11-07）：ゲージ 0〜ULT_MAX。当てると 1 体 1.5、被弾で 5。cine＝演出の間（敵と仲間は止まる）、cam_zoom＝カメラの寄り 0〜1
const ULT_COST := 100.0
const ULT_MAX := ULT_COST * 2.0
var ult := 0.0
var ult_gain := true
var cine := false
var cam_zoom := 0.0
var ally: Node3D = null   # 仲間（ally.gd）。絵を読み終えるまで null
## リリィの必殺技のゲージ（2026-11-07）：リリィの当たり 1 体 ALLY_ULT_GAIN。満タンで自動。cam_focus＝寄る相手（null ならラナ）
const ALLY_ULT_GAIN := 1.2
var manual_ally: Node3D
var ally_ult := 0.0
var ally_ult_gain := true
var cam_focus: Node3D = null
var fx: Node3D
var fx2d                  # 2D のエフェクトの層（fx2d.gd）。無ければ従来の fx.hit
## 大技の暗転（specs/vfx_overhaul.md）：bg_dim＝背景の明るさ（1→0.4 を 0.15 秒、戻り 0.25 秒）、dim_hold＝暗いままの残り
const DIM_TO := 0.4
var bg_dim := 1.0
var dim_hold := 0.0
var chroma := 0.0         # 一瞬の色収差（0.25 秒で引く）
## ヒットストップ（秒）：通常 HS_NORMAL、強い当たり（各技の最後・大技）HS_BIG。揺れは技ごとの spec.shake（無ければ 通常 SHAKE_NORMAL／強い SHAKE_BIG）
const HS_NORMAL := 0.05
const HS_BIG := 0.09
const SHAKE_NORMAL := 5.0
const SHAKE_BIG := 10.0
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
var atk_mul := 1.0        # ラナの攻撃の倍率（レベル・武器。progress.gd）
var foe_hp_mul := 1.0     # 敵の体力・攻撃の倍率（ダンジョンのハード）
var foe_dmg_mul := 1.0
var hits_taken := 0       # ラナが攻撃を受けた回数（数え続ける。ダンジョンは入った時との差）
signal foe_killed(e)
var shadow_mat: StandardMaterial3D
var glints: Array = []   # 看板・灯りの位置と色（assets/ground/glints.json）。キャラの縁取り・染めに使う
const REFL := preload("res://scripts/sprite_refl.gdshader")
## 縁取りの描き方（2026-11-06、ユーザー「白い縁取りで貼り絵感」）："hard"＝前の線、"off"＝無し、"soft"＝柔らかい光。撮影の比べは環境変数 RIM_MODE
var RIM_MODE: String = OS.get_environment("RIM_MODE") if OS.has_environment("RIM_MODE") else "soft"
const BODY_DIM := 0.8   # 2026-11-06：縁取りを柔らかくしたので少し明るく（前 0.7）。   # キャラの体の明るさ（夜。縁取りは暗くしない）

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/foe/foe.json"))
	foe_clips = d
	shadow_mat = StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.8)   # 足元の影（濃いめ）
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

## 濡れた路面に映る逆さの姿（キャラの子）
func make_refl() -> Sprite3D:
	var r := Sprite3D.new()
	r.region_enabled = true
	r.centered = false
	var m := ShaderMaterial.new()
	m.shader = REFL
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return r

## その場の光（近くの看板・灯り）をキャラの絵に反映する：輪郭の光の側を細く光らせ、体を少し染め、映り込みを合わせる。毎コマ呼ぶ。
func apply_light(spr: Sprite3D, mat: ShaderMaterial, refl: Sprite3D, p: Vector3) -> void:
	var sum := Vector3.ZERO
	var wt := 0.0
	var side := 0.0
	for g in glints:
		var dx: float = float(g.x) - p.x
		var w: float = float(g.p) / (1.0 + dx * dx * 0.08)
		sum += Vector3(float(g.col[0]), float(g.col[1]), float(g.col[2])) * w
		wt += w
		side += w * signf(dx)
	if wt > 0.0:
		var c: Vector3 = sum / wt
		c /= maxf(maxf(c.x, c.y), maxf(c.z, 0.001))
		var k: float = clampf(wt * 0.35, 0.0, 1.0)
		mat.set_shader_parameter("light_col", Color(c.x, c.y, c.z, 0.25 * k))
		match RIM_MODE:
			"hard":   # 前：くっきりした線（貼り絵っぽく見えた）
				mat.set_shader_parameter("rim_mode", 0)
				mat.set_shader_parameter("rim_col", Color(c.x * 1.2, c.y * 1.2, c.z * 1.2, 0.95 * k))
			"off":
				mat.set_shader_parameter("rim_col", Color(0, 0, 0, 0))
			_:        # 柔らかい光＋輪郭のなだらか＋夜の色へ寄せる
				mat.set_shader_parameter("rim_mode", 1)
				mat.set_shader_parameter("rim_px", 3.0)
				mat.set_shader_parameter("rim_col", Color(c.x, c.y, c.z, 0.55 * k))
				mat.set_shader_parameter("edge_soft", 1.0)
				mat.set_shader_parameter("amb_col", Color(0.5, 0.46, 0.68, 0.28))
		mat.set_shader_parameter("body_dim", BODY_DIM)
		var d: float = 1.0 if side >= 0.0 else -1.0
		mat.set_shader_parameter("rim_dir", -d if spr.flip_h else d)
	if refl:
		if refl.texture != spr.texture:
			refl.texture = spr.texture
			refl.material_override.set_shader_parameter("tex", spr.texture)
		refl.region_rect = spr.region_rect
		refl.pixel_size = spr.pixel_size
		refl.flip_h = spr.flip_h
		refl.offset = spr.offset
		refl.material_override.set_shader_parameter("tint", mat.get_shader_parameter("tint"))

## ラナと敵が使う時間（止めている間は 0）
func dt(delta: float) -> float:
	return 0.0 if (freeze > 0.0 or cine) else delta

## 大技の始まり：背景を暗くし、hold 秒そのまま
func big_moment(hold: float) -> void:
	if fx and fx.legacy:
		return
	dim_hold = maxf(dim_hold, hold)

## 大技の決めの一瞬：色収差
func chroma_hit(v: float = 1.0) -> void:
	if fx and fx.legacy:
		return
	chroma = maxf(chroma, v)

func _update_dim(delta: float) -> void:
	dim_hold = maxf(0.0, dim_hold - delta)
	if dim_hold > 0.0:
		bg_dim = maxf(DIM_TO, bg_dim - delta * (1.0 - DIM_TO) / 0.15)
	else:
		bg_dim = minf(1.0, bg_dim + delta * (1.0 - DIM_TO) / 0.25)
	RenderingServer.global_shader_parameter_set("bg_dim", bg_dim)
	chroma = maxf(0.0, chroma - delta / 0.25)
	if fx and fx.screen_mat:
		fx.screen_mat.set_shader_parameter("chroma", chroma)

func _physics_process(delta: float) -> void:
	_update_dim(delta)
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

func on_kill(e) -> void:
	foe_killed.emit(e)

func alive_count() -> int:
	var n := 0
	for e in enemies:
		if e.state != "dying":
			n += 1
	return n

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
	_attack_from(player, spec, atk_mul)

## 仲間（ally.gd）の攻撃。強さはラナのレベルの倍率に合わせる
func ally_attack(a: Node3D, spec: Dictionary) -> int:
	return _attack_from(a, spec, atk_mul)

func _attack_from(p: Node3D, spec: Dictionary, mul: float) -> int:
	var dir: int = p.face * (spec.side if spec.side != 0 else 1)
	var shape: String = spec.get("shape", "both" if spec.side == 0 else "fwd")
	var hits := 0
	for e in enemies:
		if e.state == "dying":
			continue
		var dx: float = (e.position.x - p.position.x) * dir
		var dz: float = absf(e.position.z - p.position.z)
		var inside := false
		if spec.has("only"):   # 1体だけに当てる（リリィの必殺技）
			shape = "only"
		match shape:
			"only":
				inside = e == spec.only
			"both":   # 前後両方（回転斬り・連続斬り・回し蹴り）
				inside = absf(e.position.x - p.position.x) < spec.r and dz < spec.lane
			"circle":   # 足元の円（かかと落とし）：中心は前へ cx
				var c: Vector3 = p.position + Vector3(dir * float(spec.get("cx", 0.0)), 0, 0)
				inside = Vector2(e.position.x - c.x, (e.position.z - c.z) * 1.3).length() < spec.r
			"band":   # 通り道の帯（飛び蹴り）：x0〜x1（世界の x）
				var lo: float = minf(float(spec.x0), float(spec.x1)) - 0.3
				var hi: float = maxf(float(spec.x0), float(spec.x1)) + 0.3
				inside = e.position.x > lo and e.position.x < hi and dz < spec.lane
			_:
				inside = dx > -0.42 and dx < spec.r and dz < spec.lane
		if inside:
			var d: float = spec.dmg * mul * randf_range(0.9, 1.1)
			var edir := 1 if e.position.x >= p.position.x else -1
			e.take_hit(d, edir, spec.strong)
			if spec.has("kb"):   # 吹き飛ばしの強さ（倍）
				e.kx *= float(spec.kb)
			if spec.has("pull") and not e.boss:   # 寄せる（スキル）：front＝ラナの前 1.5m へ、in＝ラナへ
				var tx: float = p.position.x + (p.face * 1.5 if spec.pull == "front" else 0.0)
				var m: float = float(spec.get("pull_m", 0.3))
				if spec.pull == "in" and absf(e.position.x - p.position.x) < 0.9:
					m = 0.0
				e.position.x = move_toward(e.position.x, tx, m)
				e.position.z = move_toward(e.position.z, p.position.z, m * 0.5)
			if spec.has("lift") and e.has_method("lift_up"):   # 浮かせる（強めののけぞり＋絵を持ち上げる）
				e.lift_up(float(spec.lift))
			var hp_pos: Vector3 = e.position + Vector3(0, e.height() * 0.55, 0)
			if fx2d and fx2d.enabled and not fx.legacy:   # 当たり：REEBO の火花＋Kenney の細い火花（2D の層で光る）
				if hits < 4:
					fx2d.hit(hp_pos, edir, spec.strong, "silver" if p == ally else "blue")
			else:
				fx.hit(hp_pos, edir, spec.strong, hits < 4)
			if spec.get("zap", false):   # 当たった所で稲妻が弾ける（リリィ）
				fx.zap(hp_pos, 6 if spec.strong else 4, 0.9 if spec.strong else 0.6)
			fx.number(e.position + Vector3(0, e.height() + 0.5, 0), int(round(d)), "strong" if spec.strong else "")
			hits += 1
	if spec.has("slash"):
		fx.slash(p.position, dir, spec.slash)
		if fx2d and fx2d.enabled and not fx.legacy and p == player:   # 振りの弧に REEBO の三日月を重ねる（光る縁）
			var sl: Dictionary = spec.slash
			var big: bool = spec.strong
			var ang: float = 0.0 if sl.get("plane", "h") == "h" else 25.0   # 三日月の向き（0＝前を上から下へ。縦振りは少し前へ倒す）
			var col: Color = fx2d.GOLD if sl.has("pal") else fx2d.BLUE
			fx2d.slash(p.position + Vector3(dir * float(sl.get("r", 2.0)) * 0.35, float(sl.get("y", 1.0)) + 0.1, 0.2), dir, float(sl.get("r", 2.0)) * (0.8 if big else 0.6), ang + randf_range(-12.0, 12.0), col)
	if hits > 0 and spec.strong and (fx.legacy or spec.get("wave", false)):   # 画面のゆがみは大技の一瞬だけ（2026-11-07。iPhone で重い）。前は強い当たりすべて
		fx.shockwave(p.position + Vector3(dir * minf(spec.r, 2.0) * 0.5, 0.9, 0), 0.9 + mini(hits, 5) * 0.12)
	if hits > 0 and p == player and ult_gain:
		ult = minf(ULT_MAX, ult + hits * 1.5)
	if hits > 0 and (p == ally or p == manual_ally) and ally_ult_gain:
		ally_ult = minf(ULT_MAX, ally_ult + hits * ALLY_ULT_GAIN)
	if hits > 0:
		if fx.legacy:   # 前の値（比較用）
			freeze = maxf(freeze, 0.045 + mini(hits, 10) * 0.006 + (0.03 if spec.strong else 0.0) + float(spec.get("freeze_add", 0.0)))
			shake = maxf(shake, 5.0 + mini(hits, 12) * 1.1 + (4.0 if spec.strong else 0.0))
		else:   # 2026-11-07：通常 50ms・大技 90ms（＋必殺技などの freeze_add）、揺れは技ごと
			freeze = maxf(freeze, (HS_BIG if spec.strong else HS_NORMAL) + float(spec.get("freeze_add", 0.0)))
			shake = maxf(shake, float(spec.get("shake", SHAKE_BIG if spec.strong else SHAKE_NORMAL)))
		combo += hits
		combo_t = 2.4
	else:
		shake = maxf(shake, 1.5)
	return hits

## スキル（skills.gd の当たり 1 回）：見た目を出してから当たりを判定する
const GOLD_PAL := [Color8(255, 150, 40), Color8(255, 210, 110), Color8(255, 250, 225)]
func player_skill(spec: Dictionary, p: Node3D) -> void:
	var f: int = p.face
	match spec.get("fx", ""):
		"flurry":   # 金の弧を毎回、大きさと角度をずらして重ねる
			var base: Dictionary = [p.SL_SWEEP, p.SL_DOWN, p.SL_BACK, p.SL_THRUST][randi() % 4].duplicate()
			base.r = float(base.r) * randf_range(0.85, 1.15) * 0.9
			var rot := randf_range(-35.0, 35.0)
			base.a0 = float(base.a0) + rot
			base.a1 = float(base.a1) + rot
			base.pal = GOLD_PAL
			base.life = 0.22
			spec.slash = base
			if hit_count_in_skill(p) >= 9:
				shake = maxf(shake, 3.0)   # 10 回目以降はわずかに揺れ続ける
		"flurry_end":
			var big: Dictionary = p.SL_BIG.duplicate()
			big.pal = GOLD_PAL
			spec.slash = big
			chroma_hit(0.8)
		"rift":
			fx.rift(float(spec.x0), float(spec.x1), p.position.z, int(spec.n))
			if fx2d and not fx.legacy:   # 割れ目の先端で金の火花と、上へ飛ぶ細い光（Kenney trace）
				var tip := Vector3(float(spec.x1), 0.4, p.position.z)
				fx2d.hit(tip, p.face, int(spec.n) == 2, "gold")
				# 割れ目の焦げ跡と、割れ目から漏れる光（床の板＝足元・奥）
				var mid := Vector3((float(spec.x0) + float(spec.x1)) * 0.5, 0, p.position.z)
				fx.tex_quad("scorch_01", mid, 1.4, {"floor": true, "add": false, "col": Color(0.04, 0.03, 0.05, 0.65), "size": absf(float(spec.x1) - float(spec.x0)) * 0.9, "fade_in": 0.05})
				fx.tex_quad("light_01", mid, 0.45, {"floor": true, "add": true, "col": Color(1.0, 0.72, 0.28), "raw": 1.3, "size": absf(float(spec.x1) - float(spec.x0)) * 0.8, "grow": 1.2})
				fx2d.burst(["trace_02", "spark_06"], tip, 10, "gold", Vector2(3.0, 8.0), 0.45, Vector2(0.2, 0.5), 8.0, 1.5, true, 0.0, 0.5, 2.0)
		"vortex":
			if int(spec.n) == 0:
				fx.vortex(p, 3.2, 1.25)
				# 床の渦：3D の板（キャラより先に描く＝足元・奥に見える）。Kenney の渦巻き 2 枚を逆に回す
				fx.tex_quad("twirl_02", p.position, 1.3, {"floor": true, "add": true, "col": Color(1.0, 0.72, 0.28), "raw": 1.3, "size": 6.4, "grow": 0.55, "spin": -7.0, "follow": p})
				fx.tex_quad("twirl_03", p.position, 1.2, {"floor": true, "add": true, "col": Color(1.0, 0.85, 0.5), "raw": 1.0, "size": 4.6, "grow": 0.6, "spin": 5.0, "follow": p})
		"vortex_end":
			fx.vortex_burst(p.position, 3.4)
			if fx2d and not fx.legacy:
				fx2d.big(p.position + Vector3(0, 1.0, 0), fx2d.GOLD, fx, p.position)
			chroma_hit(1.0)
	var hits := _attack_from(p, spec, atk_mul)
	if spec.get("fx", "") == "rift" and int(spec.n) == 2:
		fx.shockwave(Vector3(float(spec.x1), 0.5, p.position.z), 1.1)
		chroma_hit(0.8)

func hit_count_in_skill(p: Node3D) -> int:
	return int(p.hit_i)

# Successful defense: cancel exactly one strike, leaving a manual counter opportunity.
func just_guard(p: Node3D, e) -> void:
	if e.atk.get("warn") != null:
		fx.drop(e.atk.warn)
		e.atk.warn = null
	e.atk.done = true
	e.state = "stun"
	e.stun = maxf(e.stun, 0.8)
	e.kx = (-1 if e.position.x < p.position.x else 1) * 1.2
	e.flash = maxf(e.flash, 0.1)
	p.inv = maxf(p.inv, 0.6)
	var direction := 1 if e.position.x >= p.position.x else -1
	p.face = direction
	var contact: Vector3 = p.position + Vector3(direction * minf(absf(e.position.x - p.position.x) * 0.5, 0.75), 1.05, (e.position.z - p.position.z) * 0.5 + 0.05)
	freeze = maxf(freeze, 0.07)
	shake = maxf(shake, 4.0)
	if fx2d and fx2d.enabled and not fx.legacy:
		fx2d.guard(contact)
	else:
		fx.tex_quad("circle_03", contact, 0.26, {"add": true, "col": Color(1.0, 0.78, 0.32), "raw": 1.3, "size": 0.55, "grow": 2.1})
		fx.hit(contact, -direction, false, true)

# ---------- 敵の攻撃 ----------
func player_alive() -> bool:
	return hp > 0.0

func enemy_hits_player(e) -> void:
	var p: Node3D = player
	if not p.can_be_hit():
		return
	var d: int = e.dmg
	hits_taken += 1
	ult = minf(ULT_MAX, ult + 5.0)
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
