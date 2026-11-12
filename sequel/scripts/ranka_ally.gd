extends "res://scripts/ally.gd"
## 仲間ランカ（2026-11-12、ユーザー決定「同時参戦（3人）」）。動き方の土台は ally.gd（リリィ）と同じで、絵・技・エフェクトだけ差し替える。
## 絵：assets/ranka/ranka.json（tools/make_ranka.py。地区 pck「al2」）。背 1.93m は仮（前作の比。ユーザー判定待ち）。
## 通常攻撃：三連撃の動画を 3 本に分けた c1 突き → c2 前蹴り → c3 横蹴り・足払い・回し蹴り。
##   （2026-11-12 09:59 ユーザー指摘：掌底と思った動画は「くらい」だった → 被弾の clip「hit」に回し、通常攻撃は 3 本に）
##   自動：c1 → c2 → c3 と続けて出す（届く敵がいる間）。途中で止めるときは「戻り」（atk_back）で構えへ。
##   手動（イベントの主人公格、sa2_t2_lily_manual.gd）：押すたびに c1 → c2 → c3。間が空いたら c1 から。
## スキル（ユーザー決定）：指弾 shot・円環 ring・星震 quake、必殺技 天照（表は scripts/ranka_skills.gd）。
## 色：青・白・朱色の花・金（scripts/ranka_fx.gd）。リリィの稲妻は使わない。

const RankaSkills := preload("res://scripts/ranka_skills.gd")
const RankaFx := preload("res://scripts/ranka_fx.gd")
const RDMG := 13.0            # 1発の強さ（リリィ 11。人類最強なので少し強く。仮）
const CHAIN := {"atk_c1": "atk_c2", "atk_c2": "atk_c3"}
const MANUAL_ORDER := ["atk_c1", "atk_c2", "atk_c3"]
## 絵の速さ（ゲームの 1 秒あたりのコマ数 ÷ ally.SPD）。連撃は元の動画の約 2.6 倍、戻りは速く。くらい（hit）は json の 6（約 0.54 秒）
const CLIP_FPS := {"atk_c1": 7.8, "atk_c2": 7.8, "atk_c3": 7.8, "atk_back": 10.0}
## 当たりごとの見せ方（hit_i ごと）。kind：fist＝拳の気の槍、kick＝つま先の通り道の帯、low＝床すれすれの払い、palm＝掌から気の爆ぜ
const RFX := {
	"atk_c1": [{"kind": "fist"}],
	"atk_c2": [{"kind": "kick", "lift": 2.6}],
	"atk_c3": [{"kind": "fist", "w": 0.36}, {"kind": "low", "kb": 0.6}, {"kind": "kick", "kb": 2.2, "w": 0.75}],
}
const SHOT_MIN := 2.5
const SHOT_MAX := 9.0
const RING_R := 4.5

var rfx: Node3D               # ranka_fx.gd
var manual := false           # 手動（sa2_t2_lily_manual.gd が操作中）
var last_hit_frame := -100000   # 当たりの時刻（物理のコマ番号＝ゲームの時間。実時間だと重い端末で連撃が切れる）
var chain_broken := true
var ult_step := 0
var ult_next_t := 0.0
var ult_targets := []
var ult_done_end := false
var ult_seq_started := false
var hit_pal := "blue"

func setup(w, d: Dictionary) -> void:
	super.setup(w, d)
	asset_dir = "res://assets/ranka/"
	ult_key = "ranka_ult"
	follow_ofs = Vector3(-2.3, 0, -0.75)   # リリィ（後ろ 1.4m・手前）と重ならないよう、少し遠く・奥
	actor_id = "ranka"
	display_name = "ランカ"
	for c in CLIP_FPS:
		if data.clips.has(c):
			data.clips[c].fps = CLIP_FPS[c]
	sk_cd = {"shot": 2.0, "ring": 4.0, "quake": 8.0}

func _ready() -> void:
	super._ready()
	sk_tab = RankaSkills.table()
	rfx = RankaFx.new()
	rfx.fx = world.fx
	rfx.world = world
	world.add_child(rfx)

func _exit_tree() -> void:
	if is_instance_valid(rfx):
		rfx.queue_free()

func slot_ids() -> Array:
	return ["shot", "ring", "quake"]

func fresh_cd() -> Dictionary:
	return {"shot": 0.0, "ring": 0.0, "quake": 0.0}

# ---------- 通常攻撃 ----------
func _start_atk(e: Node3D) -> void:
	force_attack("atk_c1", e, 1.0)

func force_attack(c: String, e: Node3D, speed_scale: float = 1.0) -> void:
	super.force_attack(c, e, speed_scale)
	last = c
	chain_broken = false

func manual_next(_index: int) -> String:
	if chain_broken or Engine.get_physics_frames() - last_hit_frame > int(0.9 * Engine.physics_ticks_per_second):
		return "atk_c1"
	var i := MANUAL_ORDER.find(last)
	return MANUAL_ORDER[(i + 1) % MANUAL_ORDER.size()] if i >= 0 else "atk_c1"

## c1・c2 の終わりは踏み込んだ姿勢：自動なら届く敵がいれば続きへ、いなければ（手動も）戻りで構えへ
func _after_atk() -> bool:
	if clip == "atk_back":
		return false
	if not manual and CHAIN.has(clip):
		var e := _nearest()
		if e and absf(e.position.x - position.x) < ATK_X + 1.4 and absf(e.position.z - position.z) < ATK_LANE + 0.4:
			force_attack(CHAIN[clip], e, normal_attack_scale)
			return true
	if CHAIN.has(clip):
		chain_broken = true
		clip = "atk_back"
		t = 0.0
		hit_i = 0
		charged = -1
		return true
	return false

func _atk_extras(c: Dictionary, i: int, dt: float) -> void:
	var hits: Array = c.hits
	var fps: float = float(c.fps) * SPD * normal_attack_scale
	if hit_i < hits.size() and c.has("tip_f"):
		var h: int = int(hits[hit_i])
		if charged < hit_i and i >= h - int(ceil(CHARGE_T * fps)):
			charged = hit_i
			rfx.charge(_tip_world_f(c, h), 0.8, CHARGE_T)
	_update_ghosts(dt)

func _tip_world_f(c: Dictionary, i: int) -> Vector3:
	var tp: Array = c.tip_f[clampi(i, 0, c.tip_f.size() - 1)]
	return position + Vector3(face * float(tp[0]), float(tp[1]), 0.12)

func _hit_new(c: Dictionary, h: int, n: int, last_hit: bool) -> void:
	last_hit_frame = Engine.get_physics_frames()
	var specs: Array = RFX.get(clip, [{"kind": "fist"}])
	var spec: Dictionary = specs[mini(n, specs.size() - 1)]
	var tipm := 0.0
	for f in range(maxi(0, h - 4), h + 1):
		tipm = maxf(tipm, float(c.tip_f[f][0]))
	var r := clampf(tipm * 1.25 + 0.35, 2.0, 2.8)
	var strong: bool = last_hit and clip != "atk_c1"
	var hs := {"side": 1, "r": r, "lane": 1.0, "dmg": RDMG * (1.35 if strong else 1.0), "strong": strong, "shake": 8.0 if strong else 4.0}
	for k in ["lift", "kb"]:
		if spec.has(k):
			hs[k] = spec[k]
	var tip := _tip_world_f(c, h)
	match String(spec.kind):
		"fist":   # 拳の先から前へ、まっすぐな蒼白の気の槍
			var end := tip + Vector3(face * 0.9, 0, 0)
			rfx.tx("ki_band", tip + Vector3(face * 0.1, 0, 0.14), 0.32, {"size": 0.55 * (1.3 if spec.has("w") else 1.0), "raw": 1.7, "erode_from": 0.25, "grow_x": 1.5, "ang": 0.0 if face > 0 else PI})
			rfx.tx("flare", end, 0.18, {"size": 1.1, "raw": 1.8, "grow": 1.3, "spin": 2.5})
		"kick":
			world.fx.ribbon(_trail(c, h), {"w": spec.get("w", 0.55), "life": 0.42, "bolts": 0, "pal": RankaFx.BLUE, "noise": 0.35})
			rfx.tx("band_blade", tip + Vector3(-face * 0.6, 0, 0.14), 0.3, {"size": 0.45, "raw": 1.5, "erode_from": 0.2, "ang": 0.0 if face > 0 else PI})
			if strong:
				rfx.petals_burst(tip, 10, {"spd": Vector2(2.0, 5.0), "size": 0.15})
		"low":   # 足払い：床すれすれの横の弧（前後）
			hs.shape = "both"
			hs.side = 0
			world.fx.slash(position, face, {"plane": "h", "r": r, "w": 0.6, "a0": -60.0, "a1": 200.0, "y": 0.25, "life": 0.36, "draw": 0.07, "squash": 0.5, "tilt": 2.0, "pal": RankaFx.BLUE})
			world.fx.dust(position + Vector3(face * 1.0, 0, 0), 1.2)
	var nh: int = world.ally_attack(self, hs)
	if nh > 0:
		rfx.hit(tip, strong)

# ---------- スキル ----------
func _screen_foes() -> Array:
	var out := []
	for x in world.enemies:
		if x.state != "dying" and absf(x.position.x - position.x) < RankaSkills.SCREEN_R:
			out.append(x)
	return out

func _pick_skill(e: Node3D) -> bool:
	if not skills_on:
		return false
	var foes := _screen_foes()
	if float(world.get(ult_key)) >= world.ULT_COST and not world.cine and not world.ult_busy(self) and foes.size() > 0:
		_start_ult(e)
		return true
	var boss := false
	var near := 0
	for x in foes:
		boss = boss or x.boss
		if Vector2(x.position.x - position.x, (x.position.z - position.z) * 1.3).length() < RING_R:
			near += 1
	if sk_cd.quake <= 0.0 and (foes.size() >= 3 or (boss and foes.size() >= 1)):
		_start_skill("quake", e)
		return true
	if sk_cd.ring <= 0.0 and near >= 2:
		_start_skill("ring", e)
		return true
	var dx := absf(e.position.x - position.x)
	if sk_cd.shot <= 0.0 and dx > SHOT_MIN and dx < SHOT_MAX and absf(e.position.z - position.z) < 0.8:
		_start_skill("shot", e)
		return true
	return false

func _skill_hit(spec: Dictionary) -> void:
	var hs := spec.duplicate()
	hs.dmg = RDMG * float(spec.get("k", 0.0))
	var fx = world.fx
	var cx := position.x
	match String(spec.get("fx", "")):
		"shot", "shot_big":
			var big: bool = spec.fx == "shot_big"
			var a := position + Vector3(face * 1.05, 1.42, 0.12)
			var b := a + Vector3(face * float(spec.r), -0.05, 0)
			hs.x0 = position.x
			hs.x1 = position.x + face * float(spec.r)
			rfx.ki_shot(a, b, big)
			world.shake = maxf(world.shake, float(spec.get("shake", 3.0)))
		"ring", "ring_end":
			rfx.ring(position, float(spec.r), int(spec.get("n", 0)), spec.fx == "ring_end")
			if spec.fx == "ring_end":
				world.chroma_hit(0.5)
		"quake_charge":
			rfx.night_sky(cx, 11.0, 2.0)
			rfx.charge(position + Vector3(0, 1.3, 0), 1.6, 0.4)
			world.big_moment(2.0)
			return
		"quake_burst":
			rfx.quake_pillar(position)
			world.chroma_hit(0.4)
		"star":
			var foes := _screen_foes()
			var n := 0
			for x in foes:
				if n < 6:
					rfx.star(x.position + Vector3(0, 0, 0.05), randf_range(0.0, 0.05), (int(spec.n) + n) % 4 == 0)
					n += 1
			for k in 2:   # 敵のいない所にも降らせる（画面全体）
				rfx.star(Vector3(cx + randf_range(-8.0, 8.0), 0, randf_range(-2.5, 2.5)), randf_range(0.0, 0.08), k == 1)
		"quake_seq":   # 2026-11-12：締めは Godot で焼いた連番（予兆→炸裂→余韻の層）。白い板を1枚出して回す方式はやめた
			rfx.seq("quake", position + Vector3(0, 1.3, 0), 0.6)
			return
		"quake_end":
			world.chroma_hit(0.35)   # 強いと虹色の輪が出て安っぽい（sa2-skill-craft 3.5）
			world.fx.shockwave(position + Vector3(0, 1.3, 0), 1.8, 0.5, 0.9)
	if String(spec.get("shape", "")) == "none":
		return
	if String(spec.get("shape", "")) == "screen":
		hs.shape = "circle"
		hs.r = RankaSkills.SCREEN_R
		hs.cx = 0.0
		hs.lane = 99.0
	world.ally_attack(self, hs)

# ---------- 必殺技 天照：止まって寄る → カットイン → 画面の敵の間を瞬く間に8回打つ（毎回、画面全体へ当たり・光・花びら）→ 掌底で決め（画面全体へ激しい光と揺れ、花びらの嵐） ----------
func _start_ult(e: Node3D) -> void:
	super._start_ult(e)
	ult_step = 0
	ult_next_t = 0.0
	ult_done_end = false
	ult_seq_started = false
	ult_targets = _screen_foes()

const STEP_DT := 0.13
const STEP_POSES := [["atk_c1", 6], ["atk_c3", 8], ["atk_c2", 2], ["atk_c3", 3], ["atk_c1", 7], ["atk_c3", 6], ["atk_c2", 3], ["atk_c3", 8]]
const FIN_FROM := 13          # 決め：星震の動画の「腕を交差」（13）→「頭に蒼い雷」（21）→ 構えたまま（28）
const FIN_HIT := 21
const FIN_HOLD := 28

func _ult_process(delta: float) -> void:
	ult_t += delta
	inv = 0.5
	if ult_t < ULT_CUT.cut_end:
		world.cine = true
		world.cam_zoom = minf(1.0, ult_t / ULT_CUT.zoom)
		if ult_t - delta < ULT_CUT.cut_start and ult_t >= ULT_CUT.cut_start and world.main and world.main.ranka_cutin:
			world.main.ranka_cutin.play()
		_show("skill_ring", 12)   # 構え（指を顔の前に）
		if ult_t - delta < 0.05:
			rfx.petals_burst(position + Vector3(0, 1.2, 0), 18, {"spd": Vector2(1.0, 3.0), "up": 0.8, "size": 0.16})
		return
	world.cine = false
	world.cam_zoom = maxf(0.0, 1.0 - (ult_t - ULT_CUT.cut_end) / 0.35)
	var t2 := ult_t - ULT_CUT.cut_end
	var steps: int = int(sk_tab.ult.steps)
	if ult_step < steps:
		if t2 >= ult_next_t:
			_ult_flash_step(ult_step)
			ult_step += 1
			ult_next_t += STEP_DT
		_update_ghosts(delta)
		return
	# 決め：腕を交差して雷をまとう（0.0〜0.32 秒で 13→21）→ 0.32 で画面全体が光る → 0.95 秒まで構えたまま（21→28）
	var t3 := t2 - steps * STEP_DT
	var fi := FIN_FROM + int(t3 / 0.32 * float(FIN_HIT - FIN_FROM)) if t3 < 0.32 else mini(FIN_HOLD, FIN_HIT + int((t3 - 0.32) * 12.0))
	_show("skill_thunder", clampi(fi, 0, data.clips.skill_thunder.frames.size() - 1))
	if t3 < 0.32 and int(t3 * 30.0) % 3 == 0:
		rfx.charge(position + Vector3(0, 1.4, 0), 1.8, 0.2)
	if t3 >= 0.07 and not ult_seq_started:   # 焼いた決めの連番（炸裂の 0.25 秒前から）
		ult_seq_started = true
		rfx.seq("ama", position + Vector3(0, 1.3, 0), 0.8)
	if t3 >= 0.32 and not ult_done_end:
		ult_done_end = true
		_ult_end_hit()
	_update_ghosts(delta)
	if t3 >= 0.95:
		_end_ult()

func _alive_targets() -> Array:
	var out := []
	for x in ult_targets:
		if _alive(x):
			out.append(x)
	if out.is_empty():
		out = _screen_foes()
		ult_targets = out.duplicate()
	return out

func _ult_flash_step(n: int) -> void:
	var foes := _alive_targets()
	if not foes.is_empty():   # 狙った敵の横へ瞬間移動（左右を交互に）。元の場所に残像
		_ghost()
		var e: Node3D = foes[n % foes.size()]
		var side := -1.0 if n % 2 == 0 else 1.0
		position = Vector3(clampf(e.position.x + side * 1.1, world.ROOM_X.x, world.ROOM_X.y), 0, e.position.z)
		face = 1 if e.position.x >= position.x else -1
	var pose: Array = STEP_POSES[n % STEP_POSES.size()]
	_show(pose[0], int(pose[1]))
	var at := position + Vector3(face * 1.0, 1.1, 0.15)
	world.fx.ribbon([position + Vector3(-face * 0.8, 0.6 + 0.1 * (n % 3), 0.12), position + Vector3(face * 0.2, 1.2, 0.12), at + Vector3(face * 0.8, 0.1, 0)],
		{"w": 0.5, "life": 0.3, "bolts": 0, "pal": RankaFx.BLUE if n % 3 else RankaFx.GOLD, "noise": 0.3})
	rfx.petals_burst(at, 12, {"spd": Vector2(3.0, 7.0), "size": 0.17})
	rfx.tx("flare", at, 0.2, {"size": 2.2, "raw": 1.9, "grow": 1.3, "spin": 3.0, "band": "gold" if n % 3 == 0 else "ranka"})
	rfx.tx("band_ink", at + Vector3(-face * 1.2, 0, -0.02), 0.3, {"size": 0.9, "raw": 1.5, "erode_from": 0.2, "ang": 0.0 if face > 0 else PI})
	world.shake = maxf(world.shake, 9.0)
	var hs := {"shape": "circle", "side": 1, "r": RankaSkills.SCREEN_R, "cx": 0.0, "lane": 99.0, "dmg": RDMG * float(sk_tab.ult.k_step),
		"strong": false, "kb": 0.15, "shake": 6.0}
	world.ally_attack(self, hs)

func _ult_end_hit() -> void:
	var cx := position.x
	var at := position + Vector3(0, 1.3, 0.15)   # 交差した腕（胸の前）から光が爆ぜる
	# 炸裂の見た目は焼いた連番（rfx.seq "ama"、_ult_process で 0.25 秒前に出している）。ここは余韻の 3D の花びらと手応えだけ
	rfx.petals_burst(at, 24, {"spd": Vector2(4.0, 9.0), "up": 0.4, "size": 0.2, "spread": Vector3(1.0, 0.6, 0.6), "delay": 0.15})
	rfx.petals_rain(cx, 10.0, 90, 2.6)
	world.fx.shockwave(at, 2.6, 0.7, 1.1)
	world.chroma_hit(1.0)
	world.shake = maxf(world.shake, 28.0)
	if world.main and world.main.ranka_cutin:
		world.main.ranka_cutin.flash_white()
	var hs := {"shape": "circle", "side": 1, "r": RankaSkills.SCREEN_R + 1.0, "cx": 0.0, "lane": 99.0, "dmg": RDMG * float(sk_tab.ult.k_end),
		"strong": true, "kb": 3.0, "shake": 28.0, "wave": true, "freeze_add": 0.22}
	world.ally_attack(self, hs)

func force_skill(id: String, e: Node3D) -> void:
	if id == "ult":
		_start_ult(e)
	else:
		_start_skill(id, e)
