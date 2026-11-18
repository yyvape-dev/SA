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
const Eco := preload("res://scripts/economy.gd")
const Gear := preload("res://scripts/gear.gd")
const FoeStats := preload("res://scripts/foe_stats.gd")
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
var cap := 6             # 同時に出ている敵の上限（2026-11-15 ユーザー決定 A 案。前は 10。環境変数 DG_CAP）
var kills := 0
var home = null          # 戻る扉
var home_x := 0.0
var home_t := 0.0
var fail_t := 0.0
var coins := []          # 床の硬貨・回復薬：{node, val, kind("gold"/"pot"), t, v(Vector3)}（2026-11-16 ②）
var revived := false     # この周で立ち直ったか（1 周 1 回）
var gold0 := 0           # 入った時のお金（結果の画面の「得たお金」）
var items_got := 0       # この回で拾った装備・素材の数（結果の画面）
var mats_got := 0
var finished := false    # クリアした（結果の画面のあと、ボス部屋で少し動ける＝アラド風。2026-11-16 ユーザー）
var shop_spot = null     # クリア後の店の場所（金の扉＋浮かぶ小瓶）
var shop_x := 0.0
var shop_armed := true
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
	gold0 = main.progress.gold
	items_got = 0
	mats_got = 0
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
		groups = [{"x": main.player.position.x + travel * 9.0, "n": perf_n, "m": [], "rein": 0}]
		_place_groups()
		for e in groups[0].m:
			e.state = "walk"
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
	for k in coins:   # 拾い残した硬貨・回復薬は部屋を出る時に拾ったことにする（仮）
		_take_coin(k)
		if is_instance_valid(k.node):
			k.node.queue_free()
	coins.clear()
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
		var gx: float = lerpf(x0, x1, fr[i])
		if i == 0:   # 最初の群れは入った時に画面の中に見える所（5.5〜10m 先。入口の端ではカメラが壁で止まり、見えるのは約 8m 先まで）
			gx = x0 + travel * minf(5.5, absf(x1 - x0) * 0.5)
		var n: int = int(room.groups[i]) + int(cfg().add)
		groups.append({"x": gx, "n": n, "m": [], "rein": 0, "kinds": _group_kinds(n)})
	_place_groups()

## 群れは部屋に入った時点で進む先に立たせる（2026-11-15 ユーザー「大半は最初からいる」「来た側から湧くのは NG」「片付けるたびに進む先から増援は可」）。
## 各群れの 8 割を立たせ（待ち＝idle）、残り 2 割と上限を超えた分はその群れの増援。群れを片付けたら、増援が進む先の画面の外から来る。
const PRE_K := 0.8
const REIN_WARN := 1.0   # 増援の予告の秒数
var rein_wait := 0.0
func _place_groups() -> void:
	var rw: float = room.rw
	var placed := 0
	for g in groups:
		var n: int = int(g.n)
		var pre := int(round(n * PRE_K))
		if n >= 2:
			pre = clampi(pre, 1, n - 1)
		for k in pre:
			if placed >= cap:
				break
			var x: float = clampf(float(g.x) + travel * rng.randf_range(0.0, 4.5), -rw + 0.6, rw - 0.6)
			var e = _spawn_one(x, g.kinds.pop_front())
			if e:
				e.state = "idle"
				g.m.append(e)
				placed += 1
		g.rein = n - g.m.size()   # 残り（g.kinds に種類が残っている）

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
	# 部屋を片付けた：体力 10% 戻る、床の硬貨はラナへ集まる（2026-11-16 ②。集まるのは Claude の仮）
	var b = main.battle
	if b.hp > 0.0:
		b.hp = minf(b.hp_max, b.hp + b.hp_max * Eco.ROOM_HEAL * b.g_heal)
	for c in coins:
		c.magnet = true
	for d in drops:   # 装備も集まる（拾い忘れ防止。Claude の仮）
		d.magnet = true
	log_ev("clear", cur)

# ---------- 毎コマ ----------
func _physics_process(delta: float) -> void:
	var b = main.battle
	if state == "result":
		return
	if state == "after":   # クリアの後：硬貨を拾い、店に寄り、戻る扉から街へ
		_update_coins(delta)
		_after_step(delta)
		return
	if state != "won":
		t_run += delta
	hits = b.hits_taken - hits0
	# 出口の色（閉じている＝赤、開いた＝水色。開いた出口は脈打つ）
	var pulse := 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	for d in portals:
		main.set_portal_color(portals[d], COL_OPEN if room_open else COL_SHUT, pulse if room_open else 0.35)
	_update_drops(delta)
	_update_coins(delta)
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
				if not revived and not OS.has_environment("DUNGEON_TEST"):   # その場で立ち直るか選ぶ（1 周 1 回。自動の周回は選ばない＝今どおり失敗）
					state = "revive_ask"
					main.hud.show_revive(Eco.revive_cost(cfg()), main.progress.gold)
				else:
					_fail_result()
			return
		"revive_ask":
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

## 群れ：最初から立っている（_place_groups）。1 体が動けば群れごと動く。群れを片付けたら増援が進む先の画面の外から来る。全部倒すと部屋が開く。
## 同時に出ている数が cap を超える分は pending に積み、空きができたら進む先の画面の外から出す。
func _groups_step(delta: float) -> void:
	var b = main.battle
	var p: Node3D = main.player
	var rw: float = room.rw
	# 増援：予告（画面の端に赤い印 REIN_WARN 秒）のあと、進む先の画面の外から（来た側からは出さない）
	if rein_wait > 0.0:
		rein_wait -= delta
	while not pending.is_empty() and b.alive_count() < cap and rein_wait <= 0.0:
		var x: float = clampf(p.position.x + travel * rng.randf_range(10.0, 11.5), -rw + 0.6, rw - 0.6)
		_spawn_one(x, str(pending.pop_front()))
	var left := false
	for g in groups:
		var alive := []
		var awake := false
		for e in g.m:
			if is_instance_valid(e) and e.state != "dying":
				alive.append(e)
				awake = awake or e.state != "idle"
		g.m = alive
		if awake:   # 1 体が動き出したら群れごと動く
			for e in alive:
				if e.state == "idle":
					e.state = "walk"
		if alive.is_empty() and int(g.rein) > 0:   # 群れを片付けた→増援（先に予告）
			for k in int(g.rein):
				pending.append(g.kinds.pop_front() if not g.kinds.is_empty() else "")
			rein_wait = REIN_WARN
			if main.hud and main.hud.has_method("edge_warn"):
				main.hud.edge_warn(travel, REIN_WARN + 0.6)
			log_ev("wave", int(g.rein))
			g.rein = 0
		left = left or not alive.is_empty() or int(g.rein) > 0
	if not left and b.alive_count() == 0 and pending.is_empty():
		_open_room()

func _spawn_one(x: float, kind = ""):
	var foes: Array = cfg().foes
	var k: String = str(kind) if kind != null and str(kind) != "" else str(foes[rng.randi() % foes.size()])
	return main.battle.spawn(k, Vector3(x, 0, rng.randf_range(main.BELT_Z.x, main.BELT_Z.y)))

## 1 群れの種類：出る種類から選ぶ。重い敵は 1 群れに最大 1 体（2026-11-15 ユーザー決定。アーマー持ちが並んで殴れない状態を防ぐ）
func _group_kinds(n: int) -> Array:
	var foes: Array = cfg().foes
	var light := []
	for f in foes:
		if not FoeStats.heavy(str(f)):
			light.append(f)
	var out := []
	var has_heavy := false
	for i in n:
		var k: String = str(foes[rng.randi() % foes.size()])
		if FoeStats.heavy(k) and has_heavy and not light.is_empty():
			k = str(light[rng.randi() % light.size()])
		has_heavy = has_heavy or FoeStats.heavy(k)
		out.append(k)
	return out

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
	if not b.boss_break.is_connected(_on_boss_break):
		b.boss_break.connect(_on_boss_break)

func _on_boss_break(_e) -> void:
	log_ev("break", t_run)

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
	var fs: Dictionary = FoeStats.get_k(str(e.kind))
	main.gain_exp(int(c.boss_xp) if e.boss else maxi(1, int(round(float(c.xp) * float(fs.xp)))))   # 種類ごとの経験値の倍率（2026-11-16 ②）
	# お金：種類ごとの額×テーマ×難易度。ボスは額を COIN_BOSS_N 枚に分けて散らす
	var gr: Array = fs.gold if not (e.boss and str(fs.role) != "ボス") else FoeStats.BOSS_GOLD
	var g: int = int(round(rng.randi_range(int(gr[0]), int(gr[1])) * float(c.gold_mul)))
	var n: int = Eco.COIN_BOSS_N if e.boss else 1
	for i in n:
		var share: int = g / n + (1 if i < g % n else 0)
		_coin(Vector3(e.position.x, 0, e.position.z), share, "gold", float(i) / maxf(1.0, n - 1.0) * 2.0 - 1.0 if n > 1 else 0.0)
	if not e.boss and rng.randf() < Eco.POT_DROP:
		_coin(Vector3(e.position.x, 0, e.position.z), 1, "pot", 0.4)
	# 装備（③ specs/gear.md）：雑魚は難易度ごとの割合、ボスは必ず 1 つ（1 段上）
	var drop: bool = e.boss or rng.randf() < float(c.drop)
	if drop:
		var r: Array = c.bw if e.boss else c.w
		var add: int = 0 if e.boss else int(room.dist) * 2
		var pr = main.progress
		var it: Dictionary = Gear.make(rng, pr.next_uid, Gear.roll_slot(rng), Gear.roll_tier(rng, diff, e.boss), [int(r[0]) + add, int(r[1]) + add], Themes.mat_key(theme))
		pr.next_uid += 1
		_drop(Vector3(e.position.x, 0, e.position.z), it)
	# 素材（そのテーマのもの）：雑魚は 8/10/12%、ボスは 3〜5 個
	var mn: int = rng.randi_range(3, 5) if e.boss else (1 if rng.randf() < float(Gear.MAT_P.get(diff, 0.08)) else 0)
	for i in mn:
		_coin(Vector3(e.position.x, 0, e.position.z), 1, "mat", float(i) / maxf(1.0, mn - 1.0) * 2.0 - 1.0 if mn > 1 else -0.4)

## 立ち直る（ユーザーが選んだ）：お金を払い、体力を戻してその場で続ける
func revive_yes() -> void:
	var cost: int = Eco.revive_cost(cfg())
	if main.progress.gold < cost or state != "revive_ask":
		return
	main.progress.gold -= cost
	revived = true
	main.battle.hp = main.battle.hp_max
	main.player.revive(Eco.REVIVE_INV)
	state = "play"
	log_ev("revive", cost)

func revive_no() -> void:
	if state == "revive_ask":
		_fail_result()

## 硬貨・回復薬の落とし物：弧を描いて飛び出し、床で回る。触れるか近づくと拾う（ラナへ寄る）
func _coin(pos: Vector3, val: int, kind: String, spread: float) -> void:
	if val <= 0:
		return
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.6, clampf(pos.z, main.BELT_Z.x + 0.3, main.BELT_Z.y - 0.3))
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if kind == "mat":   # 素材：紫がかった小さな結晶（仮の形）
		var pm2 := PrismMesh.new()
		pm2.size = Vector3(0.2, 0.26, 0.12)
		mi.mesh = pm2
		m.albedo_color = Color(0.78, 0.66, 1.0)
	elif kind == "pot":   # 回復薬：淡い緑の小瓶（箱）
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.28, 0.1)
		mi.mesh = bm
		m.albedo_color = Color(0.55, 1.0, 0.65)
	else:   # 硬貨：金の円盤
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.13
		cm.height = 0.035
		mi.mesh = cm
		mi.rotation.x = PI * 0.5
		m.albedo_color = COL_GOLD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	main.level.add_child(root)
	var vx: float = spread * 2.2 + rng.randf_range(-0.8, 0.8)
	coins.append({"node": root, "mesh": mi, "val": val, "kind": kind, "t": 0.0, "v": Vector3(vx, rng.randf_range(3.2, 4.4), rng.randf_range(-0.6, 0.6)), "magnet": false})

func _update_coins(delta: float) -> void:
	var p: Node3D = main.player
	for i in range(coins.size() - 1, -1, -1):
		var c: Dictionary = coins[i]
		c.t += delta
		var n: Node3D = c.node
		if not is_instance_valid(n):
			coins.remove_at(i)
			continue
		var to: Vector3 = p.position - n.position
		to.y = 0.0
		var near: bool = to.length() < Eco.COIN_MAGNET
		if (c.magnet or near) and c.t > 0.45:   # ラナへ寄る
			n.position += to.normalized() * minf(to.length(), (6.0 + c.t * 4.0) * delta)
			n.position.y = move_toward(n.position.y, 0.5, delta * 3.0)
		else:   # 飛び出して床で弾む
			c.v.y -= 14.0 * delta
			n.position += c.v * delta
			if n.position.y < 0.18:
				n.position.y = 0.18
				c.v = Vector3(c.v.x * 0.5, absf(c.v.y) * 0.35 if absf(c.v.y) > 1.0 else 0.0, c.v.z * 0.5)
			n.position.x = clampf(n.position.x, -float(room.rw) + 0.6, float(room.rw) - 0.6)
			n.position.z = clampf(n.position.z, main.BELT_Z.x + 0.2, main.BELT_Z.y - 0.2)
		c.mesh.rotation.y = c.t * 5.0
		if c.t > 0.45 and to.length() < 0.45:
			_take_coin(c)
			n.queue_free()
			coins.remove_at(i)

func _take_coin(c: Dictionary) -> void:
	var pr = main.progress
	var pos: Vector3 = main.player.position + Vector3(0, 2.3, 0)
	if c.kind == "mat":
		var key: String = Themes.mat_key(theme)
		pr.mats[key] = int(pr.mats.get(key, 0)) + 1
		mats_got += 1
		main.fx.number(pos, 1, "mat")
	elif c.kind == "pot":
		if pr.pot_s < Eco.POT_S_MAX:
			pr.pot_s += 1
		else:
			pr.gold += Eco.POT_S_PRICE / 2   # 持ちきれない：半値のお金に（仮）
		main.fx.number(pos, 1, "pot")
	else:
		var gv: int = int(round(float(c.val) * main.battle.g_gold))
		pr.gold += gv
		main.fx.number(pos, gv, "gold")
	if main.fx2d and not main.fx.legacy:
		main.fx2d.pickup(main.player.position + Vector3(0, 0.6, 0))
	log_ev("coin", c.val)

## 装備の落とし物：床に浮かぶ菱形（等級の数だけ）。付けている物より強ければ金、そうでなければ灰色。武器は攻撃力の数字も出す
func _drop(pos: Vector3, it: Dictionary) -> void:
	var root := Node3D.new()
	var x: float = clampf(pos.x, -float(room.rw) + 0.8, float(room.rw) - 0.8)
	root.position = Vector3(x, 0, clampf(pos.z, main.BELT_Z.x + 0.3, main.BELT_Z.y - 0.3))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gems := Node3D.new()
	gems.position.y = 0.55
	root.add_child(gems)
	var n: int = int(it.tier)
	for k in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s0: float = 0.3 if k == 0 else 0.16
		bm.size = Vector3(s0, s0, 0.07)
		mi.mesh = bm
		mi.rotation.z = PI * 0.25
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k > 0:   # 2 つ目からは小さく、上に並べる
			mi.position = Vector3((float(k) - float(n) * 0.5) * 0.22, 0.34, 0)
		gems.add_child(mi)
	var l := Label3D.new()
	l.text = str(int(round(Gear.weapon_pow(it)))) if str(it.slot) == "weapon" else ""
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.005
	l.font_size = 56
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position.y = 1.15
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
	var better: bool = main.progress.is_better(it)
	drops.append({"node": root, "mesh": gems, "mat": m, "label": l, "glow": gm, "item": it, "better": better, "t": 0.0, "magnet": false})
	log_ev("drop", int(it.tier))

func _update_drops(delta: float) -> void:
	var p: Node3D = main.player
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.t += delta
		var col: Color = COL_GOLD if d.better else Color(0.62, 0.62, 0.68)
		d.mat.albedo_color = col
		d.label.modulate = col
		d.glow.albedo_color = Color(col.r, col.g, col.b, 0.35 + 0.15 * sin(d.t * 5.0))
		d.mesh.rotation.y = d.t * 2.4
		d.mesh.position.y = 0.55 + sin(d.t * 3.0) * 0.06
		if (d.magnet or room_open or state == "after") and d.t > 1.0:   # 部屋を片付けた後：ラナへ寄る（硬貨と同じ）
			var to: Vector3 = p.position - d.node.position
			to.y = 0.0
			d.node.position += to.normalized() * minf(to.length(), 7.0 * delta)
		if d.t > 0.5 and absf(p.position.x - d.node.position.x) < 0.75 and absf(p.position.z - d.node.position.z) < 0.6:
			_pickup(d)
			drops.remove_at(i)

## 拾う：持ち物へ（付け替えは街の「装備」で）。強い物は金の数字（等級）、持ち物がいっぱいなら売った値段のお金に
func _pickup(d: Dictionary) -> void:
	var it: Dictionary = d.item
	var pr = main.progress
	var pos: Vector3 = d.node.position + Vector3(0, 1.6, 0)
	if main.fx2d and not main.fx.legacy:
		main.fx2d.pickup(d.node.position + Vector3(0, 0.5, 0))
	if pr.add_item(it):
		items_got += 1
		main.fx.number(pos, int(it.tier), "strong" if d.better else "")
		if d.better:
			main.hud.flash_weapon()
		log_ev("item", int(it.tier))
	else:
		var g: int = Gear.sell_price(it)
		pr.gold += g
		main.fx.number(pos, g, "gold")
		log_ev("bag_full", g)
	d.node.queue_free()

# ---------- クリア ----------
func _finish() -> void:
	state = "result"
	finished = true
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
	result = {"time": t_run, "hits": hits, "lv0": lv0, "lv": pr.lv, "w0": w0, "w": pr.weapon, "best": nb, "diff": diff, "theme": theme, "gold": pr.gold - gold0, "items": items_got, "mats": mats_got,
		"unlocked": unlocked, "unlocked_diff": nd, "theme_unlocked": theme_unlocked, "sp_paid": sp_paid, "kills": kills}
	log_ev("result", result)
	main.hud.show_result(result)

## 結果の画面を閉じた → 街へ戻る
func close_result() -> void:
	if finished and state == "result" and not OS.has_environment("DUNGEON_TEST"):   # クリアの後はボス部屋で少し動ける（アラド風）。自動の周回は今どおりすぐ街へ
		_start_after()
		return
	_leave_now()

## クリアの後：店の場所（金）と戻る扉（紫）を出し、ラナを動けるように
func _start_after() -> void:
	state = "after"
	main.player.locked = false
	var bz: Vector2 = main.BELT_Z
	var rw: float = room.rw
	shop_x = clampf(main.player.position.x - 4.0, -rw + 3.0, rw - 3.0)
	home_x = clampf(main.player.position.x + 4.0, -rw + 3.0, rw - 3.0)
	if absf(shop_x - home_x) < 5.0:
		shop_x = home_x - 6.0 if home_x > 0.0 else home_x + 6.0
	shop_spot = main.make_portal(Vector3(shop_x, 0, bz.x - 0.15), true, 2.2, COL_GOLD)
	var fl := MeshInstance3D.new()   # 浮かぶ小瓶（店の印。絵は後で）
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36, 0.56, 0.2)
	fl.mesh = bm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.55, 1.0, 0.65)
	fl.material_override = fm
	fl.position = Vector3(0, 2.0, 0.3)
	fl.name = "flask"
	shop_spot.add_child(fl)
	home = main.make_portal(Vector3(home_x, 0, bz.x - 0.15), true, 2.6, COL_HOME)
	home_t = 0.0
	for c in coins:
		c.magnet = true
	for d in drops:
		d.magnet = true
	log_ev("after", t_run)

func _after_step(delta: float) -> void:
	var p: Node3D = main.player
	if shop_spot != null:
		var fl = shop_spot.get_node_or_null("flask")
		if fl:
			fl.position.y = 2.0 + sin(Time.get_ticks_msec() * 0.004) * 0.12
			fl.rotation.y += delta * 1.5
		main.set_portal_color(shop_spot, COL_GOLD, 0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.005))
		var near: bool = absf(p.position.x - shop_x) < 1.3 and p.position.z <= main.BELT_Z.x + 0.9
		if near and shop_armed and not main.hud.shop_open:
			shop_armed = false
			main.hud.open_shop()
		elif not near:
			shop_armed = true
	if main.hud.shop_open:
		return
	var on: bool = p.position.z <= main.BELT_Z.x + 0.35 and absf(p.position.x - home_x) < 1.3
	home_t = home_t + delta if on else maxf(0.0, home_t - delta * 2.0)
	main.set_portal_color(home, COL_HOME.lerp(Color.WHITE, home_t / HOME_HOLD * 0.6), 0.4 + 0.6 * home_t / HOME_HOLD)
	if home_t >= HOME_HOLD:
		state = "result"
		main.player.locked = true
		main.progress.save()
		_leave_now()

func _leave_now() -> void:
	main.player.locked = false
	main.hud.show_dungeon(false)
	main.hud.fade(0.6)
	main.leave_dungeon()
