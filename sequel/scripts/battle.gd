extends Node3D
## 戦闘のまとめ役：敵の群れの出現、当たりの判定、ヒットストップ（止め）、画面の揺れ、ラナの体力。
## 敵は小さな群れで左右から来る。倒しきると少しして次の群れ（だんだん増える）。

const CombatAudio := preload("res://scripts/combat_audio.gd")
var combat_audio: Node

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
## ランカ（2026-11-12、ユーザー決定「同時参戦（3人）」）：2人目の仲間。ゲージは仲間ごと（ranka_ult）。絵を読み終えるまで null
var ranka: Node3D = null
var ranka_ult := 0.0
var ranka_ult_gain := true

## 自動で動いている仲間（リリィ・ランカ）。手動で操作中の仲間は battle.player 側なので入らない
func ally_list() -> Array:
	var out := []
	for a in [ally, ranka]:
		if a != null and is_instance_valid(a) and a != player:
			out.append(a)
	return out

## 誰かが必殺技の演出中か（ラナ・自動の仲間・手動の仲間）。who 自身は数えない
func ult_busy(who: Node3D = null) -> bool:
	for a in [player, ally, ranka, manual_ally]:
		if a != null and a != who and is_instance_valid(a) and str(a.get("state")) == "ult":
			return true
	return false
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
var stat_hits := 0        # 確認用：味方の当たった数・与えたダメージの合計（撮影・自動の4周で数える）
var stat_dmg := 0.0
var hits_taken := 0       # ラナが攻撃を受けた回数（数え続ける。ダンジョンは入った時との差）
signal foe_killed(e)
var shadow_mat: StandardMaterial3D
var glints: Array = []   # 看板・灯りの位置と色（assets/ground/glints.json）。キャラの縁取り・染めに使う
const REFL := preload("res://scripts/sprite_refl.gdshader")
## 縁取りの描き方（2026-11-06、ユーザー「白い縁取りで貼り絵感」）："hard"＝前の線、"off"＝無し、"soft"＝柔らかい光。撮影の比べは環境変数 RIM_MODE
var RIM_MODE: String = OS.get_environment("RIM_MODE") if OS.has_environment("RIM_MODE") else "soft"
const BODY_DIM := 0.8   # 2026-11-06：縁取りを柔らかくしたので少し明るく（前 0.7）。   # キャラの体の明るさ（夜。縁取りは暗くしない）

func _ready() -> void:
	combat_audio = CombatAudio.new()
	add_child(combat_audio)
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
	_update_lingers(delta)
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

## スキルツリーの派生の汎用の項目（specs/skill_tree.md 3.）：
##   origin＝当たりの中心を固定（結界）、z_slope＝帯・前方を斜めに（1m 進むごとに奥行きが何 m ずれるか。三叉・散弾）、
##   seek_n・seek_r＝半径 seek_r の中の近い敵 seek_n 体だけ（追雷）、pull "out"＝外へ押す（反転）、
##   linger＝{n, gap, k, band}：当たった後その場に残り、gap 秒ごとに n 回当たる（k＝この当たりの何倍。結界）、
##   band_fx・burst_fx＝帯の気の筋・円の炸裂の見た目（色の帯の名前）
var lingers := []
func _deriv_fx(p: Node3D, spec: Dictionary, pp: Vector3, dir: int) -> void:
	if spec.has("band_fx") and spec.get("shape", "") == "band":
		var x0: float = float(spec.x0)
		var x1: float = float(spec.x1)
		var len := absf(x1 - x0)
		var mid := Vector3((x0 + x1) * 0.5, 1.0, pp.z + 0.1)
		fx.sx("ki_band", mid, 0.5, {"band": spec.band_fx, "size": 1.3, "aspect": len / 1.3, "raw": 2.0, "grow_x": 1.1, "ang": 0.0 if dir > 0 else PI, "erode_from": 0.25})
		fx.sx("band_blade", mid + Vector3(dir * len * 0.1, 0.1, 0.05), 0.4, {"band": spec.band_fx, "size": 0.8, "aspect": len * 0.8 / 0.8, "raw": 1.6, "grow_x": 1.2, "ang": 0.0 if dir > 0 else PI, "erode_from": 0.2})
		fx.sx("flare", Vector3(x1, 1.0, pp.z + 0.15), 0.3, {"band": spec.band_fx, "size": 2.0, "raw": 1.5, "grow": 1.4})
		fx.dust(Vector3(x1, 0, pp.z), 1.0)
	if spec.has("burst_fx") and spec.get("shape", "") == "circle":
		var c := pp + Vector3(dir * float(spec.get("cx", 0.0)), 0, 0.1)
		var r: float = float(spec.r)
		fx.sx("burst", c + Vector3(0, 1.0, 0.1), 0.45, {"band": spec.burst_fx, "size": r * 1.3, "raw": 1.4, "grow": 1.3, "erode_from": 0.1})
		fx.sx("ring", c, 0.5, {"floor": true, "band": spec.burst_fx, "size": r * 1.7, "raw": 1.4, "grow": 1.4, "erode_from": 0.12})
		fx.sx("pillar", c + Vector3(0, 1.6, 0), 0.4, {"band": spec.burst_fx, "size": 3.2, "raw": 1.3, "grow": 1.1, "ang": 0.0, "erode_from": 0.2})
		fx.dust(c, 1.6)

## 残る当たり（linger）を進める
func _update_lingers(delta: float) -> void:
	for L in lingers.duplicate():
		L.t -= delta
		if L.t > 0.0:
			continue
		if not is_instance_valid(L.p):
			lingers.erase(L)
			continue
		L.t = float(L.gap)
		L.n -= 1
		fx.sx("ring", L.spec.origin, 0.4, {"floor": true, "band": L.band, "size": float(L.spec.r) * 1.6, "raw": 1.2, "grow": 1.1, "erode_from": 0.2, "spin": 1.5})
		_attack_from(L.p, L.spec, L.mul)
		if L.n <= 0:
			lingers.erase(L)

func _attack_from(p: Node3D, spec: Dictionary, mul: float) -> int:
	var dir: int = p.face * (spec.side if spec.side != 0 else 1)
	var shape: String = spec.get("shape", "both" if spec.side == 0 else "fwd")
	var pp: Vector3 = spec.get("origin", p.position)
	var zs: float = float(spec.get("z_slope", 0.0))
	var hits := 0
	_deriv_fx(p, spec, pp, dir)
	var seek := []
	if spec.has("seek_n"):   # 追雷：半径の中の近い敵だけを狙う
		var cand := []
		for e in enemies:
			if e.state != "dying":
				var dd := Vector2(e.position.x - pp.x, (e.position.z - pp.z) * 1.3).length()
				if dd < float(spec.get("seek_r", 8.0)):
					cand.append([dd, e])
		cand.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(int(spec.seek_n), cand.size()):
			seek.append(cand[i][1])
		shape = "seek"
	for e in enemies:
		if e.state == "dying":
			continue
		var dx: float = (e.position.x - pp.x) * dir
		var dz: float = absf(e.position.z - (pp.z + zs * maxf(0.0, dx)))
		var inside := false
		if spec.has("only"):   # 1体だけに当てる（リリィの必殺技）
			shape = "only"
		match shape:
			"only":
				inside = e == spec.only
			"seek":
				inside = seek.has(e)
			"both":   # 前後両方（回転斬り・連続斬り・回し蹴り）
				inside = absf(e.position.x - pp.x) < spec.r and dz < spec.lane
			"circle":   # 足元の円（かかと落とし）：中心は前へ cx
				var c: Vector3 = pp + Vector3(dir * float(spec.get("cx", 0.0)), 0, 0)
				inside = Vector2(e.position.x - c.x, (e.position.z - c.z) * 1.3).length() < spec.r
			"band":   # 通り道の帯（飛び蹴り）：x0〜x1（世界の x）
				var lo: float = minf(float(spec.x0), float(spec.x1)) - 0.3
				var hi: float = maxf(float(spec.x0), float(spec.x1)) + 0.3
				inside = e.position.x > lo and e.position.x < hi and dz < spec.lane
			_:
				inside = dx > -0.42 and dx < spec.r and dz < spec.lane
		if inside:
			var d: float = spec.dmg * mul * randf_range(0.9, 1.1)
			stat_dmg += d
			var edir := 1 if e.position.x >= pp.x else -1
			e.take_hit(d, edir, spec.strong)
			if spec.has("kb"):   # 吹き飛ばしの強さ（倍）
				e.kx *= float(spec.kb)
			if spec.has("pull") and not e.boss:   # 寄せる（スキル）：front＝ラナの前 1.5m へ、in＝ラナへ、out＝外へ押す（派生 反転）
				var m: float = float(spec.get("pull_m", 0.3))
				if spec.pull == "out":
					e.position.x = clampf(e.position.x + edir * m, ROOM_X.x, ROOM_X.y)
					e.position.z = clampf(e.position.z + signf(e.position.z - pp.z) * m * 0.4, BELT_Z.x, BELT_Z.y)
				else:
					var tx: float = pp.x + (p.face * 1.5 if spec.pull == "front" else 0.0)
					if spec.pull == "in" and absf(e.position.x - pp.x) < 0.9:
						m = 0.0
					e.position.x = move_toward(e.position.x, tx, m)
					e.position.z = move_toward(e.position.z, pp.z, m * 0.5)
			if spec.has("lift") and e.has_method("lift_up"):   # 浮かせる（強めののけぞり＋絵を持ち上げる）
				e.lift_up(float(spec.lift))
			var hp_pos: Vector3 = e.position + Vector3(0, e.height() * 0.55, 0)
			if fx2d and fx2d.enabled and not fx.legacy:   # 当たり：REEBO の火花＋Kenney の細い火花（2D の層で光る）
				if hits < 4:
					fx2d.hit(hp_pos, edir, spec.strong, str(p.get("hit_pal")) if p.get("hit_pal") != null else ("silver" if p == ally else "blue"))
					if p != ranka and (p == player or p == ally or p == manual_ally):   # 2026-11-12：当たりの閃光（白黒の素材。ランカは自分で出す）
						var lily: bool = p == ally or str(p.get("actor_id")) == "lily"
						fx.sx("plasma" if lily else "flare", hp_pos + Vector3(0, 0, 0.22), 0.2 if not spec.strong else 0.28,
							{"band": "lily" if lily else "ranka", "size": (0.9 if not spec.strong else 1.4) * (1.0 if hits < 2 else 0.7), "raw": 1.3, "grow": 1.3, "spin": randf_range(-3.0, 3.0), "erode_from": 0.1})
						if spec.strong and hits == 0:
							fx.sx("burst", hp_pos + Vector3(0, 0, 0.18), 0.35, {"band": "lily" if lily else "ranka", "size": 2.0, "raw": 1.1, "grow": 1.3, "erode_from": 0.1})
			else:
				fx.hit(hp_pos, edir, spec.strong, hits < 4)
			if spec.get("zap", false):   # 当たった所で稲妻が弾ける（リリィ）
				fx.zap(hp_pos, 6 if spec.strong else 4, 0.9 if spec.strong else 0.6)
			fx.number(e.position + Vector3(0, e.height() + 0.5, 0), int(round(d)), "strong" if spec.strong else "")
			hits += 1
	# One cue per resolved strike, regardless of how many enemies were hit.
	if combat_audio != null:
		if p == player and p != manual_ally and spec.has("slash"):
			combat_audio.play_cue("swing")
		if hits > 0:
			combat_audio.play_cue("heavy" if spec.strong or p == ally or p == ranka or p == manual_ally else "hit")
	if spec.has("slash"):
		fx.slash(p.position, dir, spec.slash)
		if fx2d and fx2d.enabled and not fx.legacy and p == player:   # 振りの弧に REEBO の三日月を重ねる（光る縁）
			var sl: Dictionary = spec.slash
			var big: bool = spec.strong
			var ang: float = 0.0 if sl.get("plane", "h") == "h" else 25.0   # 三日月の向き（0＝前を上から下へ。縦振りは少し前へ倒す）
			var col: Color = fx2d.GOLD if sl.has("pal") else fx2d.BLUE
			var edge_at: Vector3 = p.position + Vector3(dir * float(sl.get("r", 2.0)) * 0.35, float(sl.get("y", 1.0)) + 0.1, 0.2)
			if sl.has("edge_angle"):
				fx2d.flurry_edge(edge_at, dir, float(sl.r), float(sl.edge_angle), big)
			else:
				fx2d.slash(edge_at, dir, float(sl.get("r", 2.0)) * (0.8 if big else 0.6), ang + randf_range(-12.0, 12.0), col)
	if hits > 0 and spec.strong and (fx.legacy or spec.get("wave", false)):   # 画面のゆがみは大技の一瞬だけ（2026-11-07。iPhone で重い）。前は強い当たりすべて
		fx.shockwave(p.position + Vector3(dir * minf(spec.r, 2.0) * 0.5, 0.9, 0), 0.9 + mini(hits, 5) * 0.12)
	if spec.has("linger") and not spec.has("origin"):   # 結界：その場に残って当たり続ける
		var L: Dictionary = spec.linger
		var ls: Dictionary = spec.duplicate()
		ls.erase("linger")
		ls.erase("wave")
		ls.erase("freeze_add")
		ls.origin = pp
		ls.dmg = float(spec.dmg) * float(L.get("k", 0.3))
		ls.strong = false
		ls.kb = 0.15
		ls.shake = 3.0
		lingers.append({"p": p, "spec": ls, "mul": mul, "n": int(L.get("n", 4)), "gap": float(L.get("gap", 0.4)), "t": float(L.get("gap", 0.4)), "band": String(L.get("band", "gold"))})
	stat_hits += hits
	if hits > 0 and p == player and ult_gain:
		ult = minf(ULT_MAX, ult + hits * 1.5)
	if hits > 0 and (p == ally or p == ranka or p == manual_ally):   # 仲間ごとのゲージ（ult_key：リリィ ally_ult・ランカ ranka_ult）
		var key: String = str(p.get("ult_key")) if p.get("ult_key") != null else "ally_ult"
		if bool(get(key + "_gain")):
			set(key, minf(ULT_MAX, float(get(key)) + hits * ALLY_ULT_GAIN))
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
		"flurry":
			# Authored crossing cuts: the tail of one swing leads into the next.
			var index := clampi(hit_count_in_skill(p), 0, 9)
			var progress := float(index) / 9.0
			var base: Dictionary = [p.SL_DOWN, p.SL_BACK, p.SL_SWEEP, p.SL_DOWN][index % 4].duplicate()
			base.r = lerpf(1.9, 2.3, progress)
			base.w = lerpf(0.32, 0.72, progress)
			base.a0 = [125.0, -55.0, 105.0, 135.0][index % 4]
			base.a1 = [-45.0, 120.0, -50.0, -55.0][index % 4]
			base.y = [1.05, 0.95, 1.0, 1.15][index % 4]
			base.pal = GOLD_PAL
			base.life = lerpf(0.14, 0.23, progress)
			base.draw = lerpf(0.045, 0.025, progress)
			base.edge_angle = -35.0 if index % 2 == 0 else 40.0
			spec.slash = base
		"flurry_end":
			var big: Dictionary = p.SL_BIG.duplicate()
			big.r = 2.5
			big.w = 1.15
			big.life = 0.36
			big.draw = 0.045
			big.edge_angle = -30.0
			big.pal = GOLD_PAL
			spec.slash = big
			chroma_hit(0.8)
		"rift":
			# 派生 三叉（z_slope）：区間ごとに奥行きをずらして置く（3つの区間で斜めに走って見える）
			var rz: float = p.position.z + float(spec.get("z_slope", 0.0)) * absf((float(spec.x0) + float(spec.x1)) * 0.5 - p.position.x)
			fx.rift(float(spec.x0), float(spec.x1), rz, int(spec.n))
			if fx2d and not fx.legacy:   # 割れ目の先端で金の火花と、上へ飛ぶ細い光（Kenney trace）
				var tip := Vector3(float(spec.x1), 0.4, rz)
				fx2d.hit(tip, p.face, int(spec.n) == 2, "gold")
				# 割れ目の焦げ跡と、割れ目から漏れる光（床の板＝足元・奥）
				var mid := Vector3((float(spec.x0) + float(spec.x1)) * 0.5, 0, rz)
				fx.tex_quad("scorch_01", mid, 1.4, {"floor": true, "add": false, "col": Color(0.04, 0.03, 0.05, 0.65), "size": absf(float(spec.x1) - float(spec.x0)) * 0.9, "fade_in": 0.05})
				fx.tex_quad("light_01", mid, 0.45, {"floor": true, "add": true, "col": Color(1.0, 0.72, 0.28), "raw": 1.3, "size": absf(float(spec.x1) - float(spec.x0)) * 0.8, "grow": 1.2})
				fx2d.burst(["trace_02", "spark_06"], tip, 10, "gold", Vector2(3.0, 8.0), 0.45, Vector2(0.2, 0.5), 8.0, 1.5, true, 0.0, 0.5, 2.0)
		"vortex":
			if int(spec.n) == 0:
				# 派生：大渦は r に合わせて大きく、反転（rev）は回る向きを逆に・外へ広がる
				var vs: float = float(spec.r) / 3.2
				var rv: float = -1.0 if spec.get("rev", false) else 1.0
				fx.vortex(p, float(spec.r), 1.25)
				# 床の渦：3D の板（キャラより先に描く＝足元・奥に見える）。Kenney の渦巻き 2 枚を逆に回す
				# 2026-11-12：渦の素材（GPT、白黒）を2枚、逆に回しながら縮める（Kenney の渦巻きから差し替え）
				fx.sx("vortex", p.position, 1.3, {"floor": true, "band": "gold", "raw": 1.6, "size": 7.0 * vs * (0.55 if rv < 0 else 1.0), "grow": 0.5 if rv > 0 else 1.9, "spin": -6.0 * rv, "follow": p, "erode_from": 0.55})
				fx.sx("vortex", p.position, 1.2, {"floor": true, "band": "gold", "raw": 1.2, "size": 4.8 * vs * (0.55 if rv < 0 else 1.0), "grow": 0.55 if rv > 0 else 1.9, "spin": 4.5 * rv, "follow": p, "erode_from": 0.5})
			if spec.get("rev", false):   # 反転：毎回、外へ押す輪
				fx.sx("ring", p.position, 0.3, {"floor": true, "band": "gold", "size": 2.0, "grow": float(spec.r) * 0.8, "raw": 1.2, "erode_from": 0.15, "follow": p})
		"vortex_end":
			fx.vortex_burst(p.position, float(spec.r))
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
	if combat_audio != null:
		combat_audio.play_cue("guard")
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
	if main and main.dungeon and main.dungeon.state in ["failed", "result"]:   # ダンジョンで倒れた＝失敗（起き上がっても回復しない）
		return
	hp = hp_max
