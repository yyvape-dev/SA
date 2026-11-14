extends Node
## インスタントダンジョン1回分：間取り（dungeon_map.gd）・部屋の出入り・敵の群れ・出口の開閉・武器の落とし物・ボス・クリア時間と被弾回数。
## 部屋の敵を全部倒すと出口が開く（赤＝閉じている、水色＝開いている）。ボスを倒すとクリア。
## 2026-11-14（specs/dungeon_themes.md）：テーマ×難易度 3 段、1 部屋 3 群れ（進む先から来る）、ラナが倒れたら失敗、
## 入口の部屋に戻る扉。失敗・戻る扉では入る前の状態（レベル・経験値・SP・武器・技）へ戻す。

const Map := preload("res://scripts/dungeon_map.gd")
const COL_OPEN := Color(0.16, 0.88, 1.0)
const COL_SHUT := Color(1.0, 0.2, 0.2)
const COL_GOLD := Color(1.0, 0.78, 0.3)
const COL_HOME := Color(0.72, 0.5, 1.0)   # 戻る扉（街の入口の扉と同じ紫）
const Themes := preload("res://scripts/dungeon_themes.gd")
const TRIGGER_D := 8.0     # 群れの位置にこの距離まで近づくと出てくる
const LATE_T := 3.0        # 前の群れを倒してからこの秒数たっても近づかなければ、次の群れから寄ってくる
const HOME_HOLD := 1.2     # 戻る扉の上にこの秒数立つと街へ（うっかり出ないように）

var main          # main.gd
var diff := "normal"
var theme := "t1"
var seed_val := -1
var cfg_cache := {}
var snapshot := {}       # 入る時のセーブの写し（失敗・戻る扉で戻す）
var groups := []         # この部屋の群れ [{x, n, out}]
var group_i := 0         # 次に出す群れ
var pending := []        # 同時に出せる数を超えた分（位置）。空きができたら出す
var late_t := 0.0
var travel := 1          # 進む向き（+1＝右）
var cap := 10            # 同時に出ている敵の上限（仮。重さを測って決める。環境変数 DG_CAP）
var kills := 0
var home = null          # 戻る扉
var home_x := 0.0
var home_t := 0.0
var fail_t := 0.0
var perf_n := 0          # 重さの計測：敵をこの数だけ出し続ける（倒れない）
var rng := RandomNumberGenerator.new()
var layout := {}
var cur := Vector2i.ZERO
var room := {}
var visited := {}
var cleared := {}
var t_run := 0.0
var hits0 := 0
var hits := 0
var lv0 := 1
var w0 := 0
var state := "play"     # play / transit / won / result
var wave_i := 0
var wave_t := 0.0
var room_open := false
var portals := {}       # dir -> Node3D
var drops := []         # [{node, label, val, mesh}]
var boss = null
var boss_t := -1.0
var won_t := 0.0
var transit_t := 0.0
var transit_dir := ""
var events := []        # [t, 名前, 値]（撮影・確認用）
var result := {}

func cfg() -> Dictionary:
	if cfg_cache.is_empty():
		cfg_cache = Themes.cfg(theme, diff)
	return cfg_cache

func start() -> void:
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	if OS.has_environment("DG_CAP"):
		cap = int(OS.get_environment("DG_CAP"))
	snapshot = main.progress.to_dict()
	layout = Map.generate(rng)
	main.set_theme_tint(Color(1, 1, 1, 0) if Themes.has_parts(theme) else Themes.THEMES[Themes.index_of(theme)].tint)
	main.room_theme = theme
	main.battle.foe_hp_mul = cfg().hp
	main.battle.foe_dmg_mul = cfg().dmg
	hits0 = main.battle.hits_taken
	lv0 = main.progress.lv
	w0 = main.progress.weapon
	main.battle.hp = main.battle.hp_max
	_enter(layout.entrance, "")
	main.hud.show_dungeon(true)
	log_ev("start", Themes.key(theme, diff))
	if perf_n > 0:   # 入口のとなりの部屋へ移り、敵 perf_n 体を倒れない体力で出す
		cap = perf_n
		main.battle.foe_hp_mul = 10000.0
		main.battle.foe_dmg_mul = 0.0
		var d0: String = layout.rooms[layout.entrance].exits.keys()[0]
		_enter(layout.rooms[layout.entrance].exits[d0], d0)
		groups = [{"x": main.player.position.x + travel * 9.0, "n": perf_n}]
		group_i = 0
		wave_t = 0.5
		print("DGTEST n=%d" % perf_n)

func log_ev(name: String, val = null) -> void:
	events.append([t_run, name, val])

func is_boss_room(c: Vector2i) -> bool:
	return c == layout.boss

# ---------- 部屋に入る ----------
## moved：前の部屋から動いた向き（"" は入口）。新しい部屋では反対側の出口から出てくる
func _enter(c: Vector2i, moved: String) -> void:
	for e in main.battle.enemies.duplicate():
		main.battle.remove_enemy(e)
	drops.clear()
	boss = null
	cur = c
	room = layout.rooms[c]
	main.build_room(room)
	portals.clear()
	var rw: float = room.rw
	var bz: Vector2 = main.BELT_Z
	for d in room.exits:
		var n: Node3D
		match d:
			"L": n = main.make_portal(Vector3(-rw + 0.25, 0, (bz.x + bz.y) * 0.5), false, bz.y - bz.x + 0.4, COL_SHUT)
			"R": n = main.make_portal(Vector3(rw - 0.25, 0, (bz.x + bz.y) * 0.5), false, bz.y - bz.x + 0.4, COL_SHUT)
			"B": n = main.make_portal(Vector3(room.bx, 0, bz.x - 0.15), true, 2.6, COL_SHUT)
			"F": n = main.make_portal(Vector3(room.fx, 0, bz.y + 0.15), true, 2.6, COL_SHUT, false)
		portals[d] = n
	var p: Node3D = main.player
	var arrive: String = Map.OPP.get(moved, "")
	match arrive:
		"L": p.position = Vector3(-rw + 1.8, 0, 0.3)
		"R": p.position = Vector3(rw - 1.8, 0, 0.3)
		"B": p.position = Vector3(room.bx, 0, bz.x + 1.0)
		"F": p.position = Vector3(room.fx, 0, bz.y - 1.0)
		_: p.position = Vector3(0, 0, 0.6)
	if arrive == "L": p.face = 1
	elif arrive == "R": p.face = -1
	p.state = "move"
	main.player.room_x = Vector2(-rw, rw)
	main._place_cam(true)
	visited[c] = true
	main.battle.wave = int(room.dist) + 1
	wave_i = 0
	wave_t = 0.9
	room_open = cleared.has(c) or c == layout.entrance
	# 進む向き：入った側の反対。奥・手前・入口から入った時は、遠い方の壁へ
	match arrive:
		"L": travel = 1
		"R": travel = -1
		_: travel = 1 if p.position.x <= 0.0 else -1
	_plan_groups(p.position.x)
	home = null
	home_t = 0.0
	if c == layout.entrance:
		_build_home()
	boss_t = 1.2 if (is_boss_room(c) and not room_open) else -1.0
	log_ev("enter", c)

## 群れの位置：入った所から進む先の壁の手前まで、1/3・2/3・奥の端（specs/dungeon_themes.md 3.2）
func _plan_groups(x0: float) -> void:
	groups = []
	group_i = 0
	pending = []
	late_t = 0.0
	if room_open or is_boss_room(cur):
		return
	var rw: float = room.rw
	var x1: float = travel * (rw - 2.5)
	var fr := [0.3, 0.62, 0.95]
	for i in room.groups.size():
		groups.append({"x": lerpf(x0, x1, fr[i]), "n": int(room.groups[i]) + int(cfg().add)})

## 戻る扉：入口の部屋の奥の縁、奥・手前の出口から離れた所
func _build_home() -> void:
	var rw: float = room.rw
	var bz: Vector2 = main.BELT_Z
	var best := 0.0
	var bd := -1.0
	for k in 9:
		var x := lerpf(-rw + 4.0, rw - 4.0, k / 8.0)
		var d := 99.0
		if room.exits.has("B"):
			d = minf(d, absf(x - float(room.bx)))
		if room.exits.has("F"):
			d = minf(d, absf(x - float(room.fx)))
		d = minf(d, absf(x) + 3.0)   # 出てきた所（x 0）の近くは避けつつ、近すぎず
		if d > bd:
			bd = d
			best = x
	home_x = best
	home = main.make_portal(Vector3(home_x, 0, bz.x - 0.15), true, 2.6, COL_HOME)

func _open_room() -> void:
	room_open = true
	cleared[cur] = true
	log_ev("clear", cur)

# ---------- 毎コマ ----------
func _physics_process(delta: float) -> void:
	var b = main.battle
	if state == "result":
		return
	if state != "won":
		t_run += delta
	hits = b.hits_taken - hits0
	# 出口の色（閉じている＝赤、開いた＝水色。開いた出口は脈打つ）
	var pulse := 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	for d in portals:
		main.set_portal_color(portals[d], COL_OPEN if room_open else COL_SHUT, pulse if room_open else 0.35)
	_update_drops(delta)
	match state:
		"transit":
			transit_t += delta
			if transit_t >= 0.22 and transit_dir != "":
				var nxt: Vector2i = room.exits[transit_dir]
				var mv := transit_dir
				transit_dir = ""
				_enter(nxt, mv)
			if transit_t >= 0.3:
				state = "play"
				main.player.locked = false
			return
		"won":
			won_t += delta
			if won_t >= 1.8:
				_finish()
			return
		"failed":
			fail_t += delta
			if fail_t >= 1.4:
				_fail_result()
			return
	# ラナが倒れた（体力 0）＝失敗
	if b.hp <= 0.0 and main.player.state == "down":
		state = "failed"
		fail_t = 0.0
		main.player.locked = true
		log_ev("fail", t_run)
		return
	# ボス
	if boss_t > 0.0:
		boss_t -= delta
		if boss_t <= 0.0:
			_spawn_boss()
	if boss != null:
		if not is_instance_valid(boss) or boss.state == "dying":
			boss = null
			_open_room()
			state = "won"
			won_t = 0.0
			log_ev("boss_down", t_run)
		return
	if not room_open and not is_boss_room(cur):
		_groups_step(delta)
	if room_open:
		_check_exits()
	_home_step(delta)

## 群れ：次の群れに近づいたら出す。前の群れを倒して LATE_T 秒たっても近づかなければ、次の群れから寄ってくる。
## 同時に出ている数が cap を超える分は pending に積み、空きができたら進む先の画面の外から出す。
func _groups_step(delta: float) -> void:
	var b = main.battle
	var p: Node3D = main.player
	var rw: float = room.rw
	while not pending.is_empty() and b.alive_count() < cap:
		var x: float = clampf(p.position.x + travel * rng.randf_range(10.0, 11.5), -rw + 0.6, rw - 0.6)
		_spawn_one(x)
		pending.pop_front()
	if group_i < groups.size():
		var g: Dictionary = groups[group_i]
		var near: bool = (float(g.x) - p.position.x) * travel < TRIGGER_D
		if b.alive_count() == 0 and pending.is_empty() and group_i > 0:
			late_t += delta
		if near or late_t >= LATE_T or (group_i == 0 and wave_t <= 0.0):
			_spawn_group(g)
			group_i += 1
			late_t = 0.0
		wave_t -= delta
	elif b.alive_count() == 0 and pending.is_empty():
		_open_room()

func _spawn_group(g: Dictionary) -> void:
	var p: Node3D = main.player
	var rw: float = room.rw
	var n: int = int(g.n)
	var back_n := 1 if n <= 5 else 2   # 後ろから来るのは 1〜2 体（大半は進む先から）
	for i in n:
		var x: float
		if i < back_n:
			x = p.position.x - travel * rng.randf_range(9.5, 11.0)
			if absf(x) > rw - 0.6:   # 後ろが壁なら進む先へ
				x = float(g.x) + travel * rng.randf_range(0.0, 3.0)
		else:
			x = maxf(float(g.x) * travel, p.position.x * travel + 7.5) * travel + travel * rng.randf_range(0.0, 3.0)
		x = clampf(x, -rw + 0.6, rw - 0.6)
		if main.battle.alive_count() >= cap:
			pending.append(x)
		else:
			_spawn_one(x)
	log_ev("wave", n)

func _spawn_one(x: float) -> void:
	var foes: Array = cfg().foes
	main.battle.spawn(foes[rng.randi() % foes.size()], Vector3(x, 0, rng.randf_range(main.BELT_Z.x, main.BELT_Z.y)))

## 戻る扉：上に HOME_HOLD 秒立つと街へ（何も残さない）
func _home_step(delta: float) -> void:
	if home == null or state != "play":
		return
	var p: Node3D = main.player
	var on: bool = p.position.z <= main.BELT_Z.x + 0.35 and absf(p.position.x - home_x) < 1.3
	home_t = home_t + delta if on else maxf(0.0, home_t - delta * 2.0)
	main.set_portal_color(home, COL_HOME.lerp(Color.WHITE, home_t / HOME_HOLD * 0.6), 0.4 + 0.6 * home_t / HOME_HOLD)
	if home_t >= HOME_HOLD:
		log_ev("home", t_run)
		_restore()
		state = "result"
		main.player.locked = true
		main.hud.fade(0.6)
		close_result()

## 入る前の状態へ戻す（レベル・経験値・SP・武器・技）
func _restore() -> void:
	main.progress.from_dict(snapshot)
	main.progress.save()
	main.apply_progress()

func _fail_result() -> void:
	state = "result"
	_restore()
	result = {"fail": true, "time": t_run, "kills": kills, "hits": hits, "diff": diff, "theme": theme}
	log_ev("result", result)
	main.hud.show_result(result)

func _spawn_boss() -> void:
	var b = main.battle
	var p: Node3D = main.player
	var x: float = (room.rw - 3.0) * (-1.0 if p.position.x > 0.0 else 1.0)
	x = clampf(x, p.position.x - 12.0, p.position.x + 12.0)   # 広い部屋で遠すぎないように
	boss = b.spawn(str(cfg().boss), Vector3(x, 0, 0.2))
	boss.make_boss(cfg().boss_hp, int(cfg().boss_dmg))
	log_ev("boss", null)

func _check_exits() -> void:
	var p: Node3D = main.player
	var rw: float = room.rw
	var bz: Vector2 = main.BELT_Z
	for d in room.exits:
		var hit := false
		match d:
			"L": hit = p.position.x <= -rw + 0.35
			"R": hit = p.position.x >= rw - 0.35
			"B": hit = p.position.z <= bz.x + 0.25 and absf(p.position.x - float(room.bx)) < 1.3
			"F": hit = p.position.z >= bz.y - 0.25 and absf(p.position.x - float(room.fx)) < 1.3
		if hit:
			state = "transit"
			transit_t = 0.0
			transit_dir = d
			main.player.locked = true
			main.hud.fade(0.5)
			log_ev("exit", d)
			return

# ---------- 敵を倒した・落とし物 ----------
func on_foe_killed(e) -> void:
	kills += 1
	var c := cfg()
	main.gain_exp(int(c.boss_xp) if e.boss else int(c.xp))
	var drop: bool = e.boss or rng.randf() < float(c.drop)
	if drop:
		var r: Array = c.bw if e.boss else c.w
		var val: int = rng.randi_range(int(r[0]), int(r[1])) + (0 if e.boss else int(room.dist) * 2)
		_drop(Vector3(e.position.x, 0, e.position.z), val)

## 武器の落とし物：床に浮かぶ菱形と攻撃力の数字。今の武器より強ければ金、弱ければ灰色。
func _drop(pos: Vector3, val: int) -> void:
	var root := Node3D.new()
	var x: float = clampf(pos.x, -float(room.rw) + 0.8, float(room.rw) - 0.8)
	root.position = Vector3(x, 0, clampf(pos.z, main.BELT_Z.x + 0.3, main.BELT_Z.y - 0.3))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.32, 0.08)
	mi.mesh = bm
	mi.rotation.z = PI * 0.25
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position.y = 0.55
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var l := Label3D.new()
	l.text = str(val)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.005
	l.font_size = 56
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position.y = 1.0
	l.render_priority = 9
	root.add_child(l)
	var glow := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.9, 0.5)
	glow.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.material_override = gm
	glow.position.y = 0.03
	root.add_child(glow)
	main.level.add_child(root)
	drops.append({"node": root, "mesh": mi, "label": l, "glow": gm, "val": val, "t": 0.0})
	log_ev("drop", val)

func _update_drops(delta: float) -> void:
	var p: Node3D = main.player
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.t += delta
		var better: bool = int(d.val) > int(main.progress.weapon)
		var col: Color = COL_GOLD if better else Color(0.62, 0.62, 0.68)
		d.mesh.material_override.albedo_color = col
		d.label.modulate = col
		d.glow.albedo_color = Color(col.r, col.g, col.b, 0.35 + 0.15 * sin(d.t * 5.0))
		d.mesh.rotation.y = d.t * 2.4
		d.mesh.position.y = 0.55 + sin(d.t * 3.0) * 0.06
		if d.t > 0.5 and absf(p.position.x - d.node.position.x) < 0.75 and absf(p.position.z - d.node.position.z) < 0.6:
			_pickup(d)
			drops.remove_at(i)

## 拾う：今の武器と比べて、強ければ持ち替える（数字を金で出す）。弱ければ捨てる（灰色の数字）
func _pickup(d: Dictionary) -> void:
	var val: int = d.val
	var pos: Vector3 = d.node.position + Vector3(0, 1.6, 0)
	if main.fx2d and not main.fx.legacy:
		main.fx2d.pickup(d.node.position + Vector3(0, 0.5, 0))
	if val > main.progress.weapon:
		main.progress.weapon = val
		main.apply_progress()
		main.progress.save()
		main.fx.number(pos, val, "strong")
		main.hud.flash_weapon()
		log_ev("equip", val)
	else:
		log_ev("discard", val)
	d.node.queue_free()

# ---------- クリア ----------
func _finish() -> void:
	state = "result"
	main.player.locked = true
	var pr = main.progress
	var key := Themes.key(theme, diff)
	var nb: bool = not pr.best.has(key) or t_run < float(pr.best[key])
	if nb:
		pr.best[key] = t_run
	# 開いた物：このクリアで次の難易度・次のテーマが開いたか（前後の差）
	var ti := Themes.index_of(theme)
	var nd: String = Themes.DIFF_ORDER[mini(Themes.DIFF_ORDER.find(diff) + 1, 2)]
	var before_d: bool = pr.diff_open(theme, nd)
	var before_t: bool = ti + 1 < Themes.THEMES.size() and pr.theme_open(ti + 1)
	pr.clears[key] = int(pr.clears.get(key, 0)) + 1
	var sp_paid: bool = pr.pay_first_clear(key)   # 初回クリア：3人それぞれ SP +2（specs/skill_tree.md）
	var unlocked: bool = diff != "expert" and not before_d and pr.diff_open(theme, nd)
	var theme_unlocked: bool = ti + 1 < Themes.THEMES.size() and not before_t and pr.theme_open(ti + 1)
	pr.hard_open = pr.diff_open("t1", "hard")
	pr.save()
	result = {"time": t_run, "hits": hits, "lv0": lv0, "lv": pr.lv, "w0": w0, "w": pr.weapon, "best": nb, "diff": diff, "theme": theme,
		"unlocked": unlocked, "unlocked_diff": nd, "theme_unlocked": theme_unlocked, "sp_paid": sp_paid, "kills": kills}
	log_ev("result", result)
	main.hud.show_result(result)

## 結果の画面を閉じた → 街へ戻る
func close_result() -> void:
	main.player.locked = false
	main.hud.show_dungeon(false)
	main.hud.fade(0.6)
	main.leave_dungeon()
