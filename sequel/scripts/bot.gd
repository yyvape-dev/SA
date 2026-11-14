extends Node
## 自動の入力（確認用）：街の入口まで歩いて難易度を選び、ダンジョンを最後まで通す。
##   CAPTURE_DUNGEON=1 … 画面を captures/dg_*.png に撮る（xvfb＋描画あり）
##   DUNGEON_TEST=1    … 撮らずに通すだけ（--headless で速い）
## 周回：ノーマル（全部の部屋を回る）→ ノーマル → ノーマル → ハード。間取りの種は固定（毎回同じ）。
## 確かめること：詰まり（45秒進まない）・抜け道（敵が残っているのに出口から出られる）・ハードの鍵。

const Map := preload("res://scripts/dungeon_map.gd")
const RUNS := [["normal", 101, true], ["normal", 202, false], ["normal", 303, false], ["hard", 404, false]]
const STUCK_T := 45.0

var main
var rng := RandomNumberGenerator.new()
var shots := false
var run_i := 0
var phase := "city"
var t := 0.0
var t_phase := 0.0
var last_prog := 0.0
var last_hp := 0.0
var ev_seen := 0
var atk_cd := 0.0
var dodge_cd := 0.0
var probe := {}         # {t, room, dir, done}
var shot_q := []        # [残り秒, 名前]
var shot_n := 0
var periodic := 0.0
var summary := []
var notes := []
var room_t := {}        # 部屋ごとの滞在時間の最大
var room_enter_t := 0.0

func _ready() -> void:
	process_physics_priority = -10
	rng.seed = 7
	shots = OS.has_environment("CAPTURE_DUNGEON")
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
		RenderingServer.render_loop_enabled = false   # 描くのは撮る瞬間だけ（ソフト描画は遅いので）
	main.battle.auto_spawn = false
	main.player.position = Vector3(8.0, 0, 0.8)
	_randomize_tree()

## スキルツリー（specs/skill_tree.md 5.）：周ごとに、3人の技レベル（3〜5）と派生（なしも含む）をランダムに付ける。TREE_RANDOM=0 で付けない
var tree_log := []
const ST := preload("res://scripts/skill_tree.gd")
func _randomize_tree() -> void:
	if OS.get_environment("TREE_RANDOM") == "0":
		return
	var pr = main.progress
	var keep_sp: Dictionary = pr.sp.duplicate()
	var line := []
	for ch in ST.CHARS:
		pr.skill_lv[ch] = {}
		pr.deriv[ch] = {}
		for id in ST.order(ch):
			pr.skill_lv[ch][id] = rng.randi_range(3, 5)
			var dd: Dictionary = ST.rows(ch)[id].derivs
			var ds: Array = []
			for k in dd:
				if not dd[k].get("todo", false):
					ds.append(k)
			var pick := rng.randi_range(-1, ds.size() - 1)
			if pick >= 0:
				pr.deriv[ch][id] = ds[pick]
			line.append("%s.%s Lv%d %s" % [ch, id, pr.skill_lv[ch][id], pr.deriv[ch].get(id, "-")])
	pr.sp = keep_sp   # SP の数え（レベル・初回クリア）は変えない
	main.apply_progress()
	tree_log.append("run %d：%s" % [run_i + 1, "、".join(line)])

func _shot(tag: String, delay := 0.0) -> void:
	if shots:
		shot_q.append([delay, tag])

func _physics_process(delta: float) -> void:
	t += delta
	t_phase += delta
	atk_cd -= delta
	dodge_cd -= delta
	for i in range(shot_q.size() - 1, -1, -1):
		shot_q[i][0] -= delta
		if shot_q[i][0] <= 0.0:
			var tag: String = shot_q[i][1]
			shot_q.remove_at(i)
			_save_shot.call_deferred(tag)
	var p: Node3D = main.player
	p.move_in = Vector2.ZERO
	match phase:
		"city": _city()
		"dungeon": _dungeon(delta)
		"result":
			if t_phase > 2.2:
				main.hud.confirm_result()
				phase = "back"
				t_phase = 0.0
		"back":
			if t_phase > 1.0:
				run_i += 1
				if run_i >= RUNS.size():
					_finish()
				else:
					phase = "city"
					t_phase = 0.0
					_randomize_tree()

func _save_shot(tag: String) -> void:
	shot_n += 1
	var n := shot_n
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	img.save_png(ProjectSettings.globalize_path("res://captures/dg_r%d_%03d_%s.png" % [run_i + 1, n, tag]))


# ---------- 街：入口まで歩いて選ぶ ----------
func _city() -> void:
	var p: Node3D = main.player
	var hud = main.hud
	if hud.menu_open:
		if t_phase > 0.0 and not probe.has("menu_shot"):
			probe["menu_shot"] = true
			_shot("menu", 0.4)
		if hud.menu_t > 0.9:
			var run: Array = RUNS[run_i]
			if run_i == 0:
				var ok: bool = hud.choose(1)   # まだ開いていないハードを押す → 選べないこと
				notes.append("ハードの鍵（ノーマル未クリア）：%s" % ("選べない＝正しい" if not ok else "選べてしまった＝誤り"))
				if ok:
					return
			main.next_seed = int(run[1])
			hud.menu_sel = 1 if run[0] == "hard" else 0
			var ok2: bool = hud.choose(hud.menu_sel)
			if not ok2:
				notes.append("run %d：%s を選べなかった" % [run_i + 1, run[0]])
				_finish()
				return
			phase = "dungeon"
			t_phase = 0.0
			last_prog = t
			ev_seen = 0
			probe = {}
			room_t = {}
			room_enter_t = t
			periodic = 0.0
		return
	if not probe.has("gate_shot") and absf(main.player.position.x - main.GATE_X) < 3.5:
		probe["gate_shot"] = true
		_shot("gate")
	_go(Vector2(main.GATE_X, main.BELT_Z.x - 0.6))
	if t_phase > 30.0:
		notes.append("run %d：入口に着けない" % (run_i + 1))
		_finish()

# ---------- ダンジョン ----------
func _dungeon(delta: float) -> void:
	var d = main.dungeon
	if d == null:
		return
	# 出来事 → 撮影・進み具合
	while ev_seen < d.events.size():
		var ev: Array = d.events[ev_seen]
		ev_seen += 1
		last_prog = t
		match ev[1]:
			"enter":
				room_enter_t = t
				_shot("enter", 0.45)
			"wave": _shot("wave", 1.2)
			"clear":
				var c: Vector2i = d.cur
				room_t[c] = maxf(float(room_t.get(c, 0.0)), t - room_enter_t)
				_shot("clear", 0.3)
			"equip": _shot("equip", 0.1)
			"boss": _shot("boss", 1.6)
			"boss_down": _shot("bossdown", 0.25)
			"result":
				_shot("result", 1.4)
				phase = "result"
				t_phase = 0.0
				_record(d)
				return
	var hp_sum := 0.0
	for e in main.battle.enemies:
		hp_sum += maxf(0.0, e.hp)
	if hp_sum < last_hp - 0.5:
		last_prog = t   # 敵の体力が減っている＝進んでいる
	last_hp = hp_sum
	if d.boss != null:
		periodic += delta
		if periodic > 5.0:
			periodic = 0.0
			_shot("bossfight")
	if t - last_prog > STUCK_T:
		notes.append("run %d：詰まり（%d秒進まない）部屋 %s 敵 %d 状態 %s" % [run_i + 1, int(STUCK_T), str(d.cur), main.battle.alive_count(), d.state])
		_shot("stuck")
		for e in main.battle.enemies:
			notes.append("  敵 %s 位置 %s 状態 %s 体力 %.0f／ラナ %s 状態 %s 向き %d 部屋の半幅 %.1f" % [e.kind, str(e.position), e.state, e.hp, str(main.player.position), main.player.state, main.player.face, d.room.rw])
		_record(d)
		_finish()
		return
	if d.state != "play":
		return
	var p: Node3D = main.player
	var b = main.battle
	# 抜け道の確認（1周目の最初の戦う部屋）：敵がいるうちに出口へ歩き続けても出られないこと
	if RUNS[run_i][2] and not probe.has("done") and not d.room_open and not d.is_boss_room(d.cur) and b.alive_count() > 0:
		if not probe.has("t"):
			probe = {"t": 0.0, "room": d.cur, "dir": d.room.exits.keys()[0]}
			_shot("probe", 1.5)
		probe.t += delta
		_go_exit(d, probe.dir)
		if probe.t > 3.0:
			probe["done"] = true
			var held: bool = d.cur == probe.room and d.state == "play"
			notes.append("抜け道の確認（敵がいるうちに出口 %s へ3秒歩く）：%s" % [probe.dir, "出られない＝正しい" if held else "出られた＝誤り"])
		return
	if _maybe_dodge():
		return
	var tgt = _nearest_enemy()
	if tgt != null:
		_fight(tgt)
		return
	if not d.room_open:
		return   # 次の波を待つ
	if not d.drops.is_empty():
		var dr: Node3D = d.drops[0].node
		_go(Vector2(dr.position.x, dr.position.z))
		return
	var goal: Vector2i = d.layout.boss
	if RUNS[run_i][2]:
		goal = _nearest_unvisited(d)
	var dir: String = Map.first_step(d.layout, d.cur, goal)
	if dir == "":
		return
	_go_exit(d, dir)

func _nearest_unvisited(d) -> Vector2i:
	var best: Vector2i = d.layout.boss
	var bd := 999
	var ex := {}
	for c in d.layout.rooms:
		ex[c] = d.layout.rooms[c].exits
	var dist: Dictionary = Map._bfs(ex, d.cur)
	for c in d.layout.rooms:
		if not d.visited.has(c) and c != d.layout.boss and int(dist[c]) < bd:
			bd = int(dist[c])
			best = c
	return best

func _go(target: Vector2) -> void:
	var p: Node3D = main.player
	var v := Vector2(target.x - p.position.x, target.y - p.position.z)
	if v.length() < 0.05:
		return
	p.move_in = v.normalized() * (1.0 if v.length() > 1.5 else 0.6)

func _go_exit(d, dir: String) -> void:
	var p: Node3D = main.player
	var rw: float = d.room.rw
	var bz: Vector2 = main.BELT_Z
	match dir:
		"L": _go(Vector2(-rw - 2.0, 0.3))
		"R": _go(Vector2(rw + 2.0, 0.3))
		"B":
			if absf(p.position.x - float(d.room.bx)) > 0.5:
				_go(Vector2(d.room.bx, bz.x + 0.8))
			else:
				_go(Vector2(d.room.bx, bz.x - 2.0))
		"F":
			if absf(p.position.x - float(d.room.fx)) > 0.5:
				_go(Vector2(d.room.fx, bz.y - 0.8))
			else:
				_go(Vector2(d.room.fx, bz.y + 2.0))

func _nearest_enemy():
	var p: Node3D = main.player
	var best = null
	var bd := INF
	for e in main.battle.enemies:
		if e.state == "dying":
			continue
		var dd: float = absf(e.position.x - p.position.x) + absf(e.position.z - p.position.z) * 1.5
		if dd < bd:
			bd = dd
			best = e
	return best

func _fight(e) -> void:
	var p: Node3D = main.player
	var rw: float = main.battle.ROOM_X.y
	var s := 1 if e.position.x >= p.position.x else -1
	var dist := 2.3 if e.boss else 1.5
	var tx: float = e.position.x - s * dist
	if absf(tx) > rw - 0.3:   # 壁際の敵は反対側から
		tx = e.position.x + s * dist
		s = -s
	tx = clampf(tx, -rw + 0.3, rw - 0.3)
	var tz: float = e.position.z
	if absf(p.position.x - tx) < 0.6 and absf(p.position.z - tz) < 0.35:
		var want := 1 if e.position.x >= p.position.x else -1
		if p.face != want:
			p.move_in = Vector2(want * 0.35, 0)
		# スキル：待ちが明けたら使う（枠1〜3の順。群れには渦を優先）
		var used := false
		if OS.get_environment("BOT_SKILLS") != "0" and p.use_ult():
			used = true
			ult_uses += 1
		if not used and OS.get_environment("BOT_SKILLS") != "0":
			for id in (["vortex", "flurry", "rift"] if main.battle.alive_count() >= 3 else ["flurry", "rift", "vortex"]):
				if main.progress.skill_slots.has(id) and p.use_skill(id):
					used = true
					break
		if not used and atk_cd <= 0.0:
			p.attack()
			atk_cd = 0.12
	else:
		_go(Vector2(tx, tz))

## 床の予兆の中にいて、当たりの瞬間が近ければ、奥行きの方向へ回避する（4回に3回。人の手の再現）
func _maybe_dodge() -> bool:
	if dodge_cd > 0.0:
		return false
	var p: Node3D = main.player
	if p.state != "move" and p.state != "atk":
		return false
	for e in main.battle.enemies:
		if e.state != "atk" or e.atk.is_empty() or e.atk.done or not e.atk.has("area"):
			continue
		if e.atk.has("bot"):
			continue
		var rem: float = float(e.atk.hit_t) - float(e.atk.t)
		var area: Rect2 = e.atk.area
		if rem < 0.3 and area.grow(0.25).has_point(Vector2(p.position.x, p.position.z)):
			e.atk["bot"] = true
			if rng.randf() < 0.75:
				var cz: float = area.get_center().y
				var dz := 1.0 if p.position.z >= cz else -1.0
				if p.position.z + dz * 2.5 > main.BELT_Z.y or p.position.z + dz * 2.5 < main.BELT_Z.x:
					dz = -dz
				p.move_in = Vector2(0, dz)
				p.dodge()
				dodge_cd = 0.5
				return true
	return false

func _record(d) -> void:
	var r: Dictionary = d.result
	var mx := 0.0
	for c in room_t:
		mx = maxf(mx, float(room_t[c]))
	summary.append("run %d %s 種%d：クリア %s 時間 %.2f秒 被弾 %d Lv %d→%d 武器 %d→%d 行った部屋 %d/6 ボスまで %d部屋 1部屋の最長 %.1f秒" % [
		run_i + 1, d.diff, RUNS[run_i][1], "済" if not r.is_empty() else "未", d.t_run, d.hits,
		int(r.get("lv0", 0)), int(r.get("lv", 0)), int(r.get("w0", 0)), int(r.get("w", 0)),
		d.visited.size(), int(d.layout.rooms[d.layout.boss].dist), mx])

var finished := false
var ult_uses := 0
func _finish() -> void:
	if finished:
		return
	finished = true
	print("==== DUNGEON BOT ====")
	for s in summary:
		print(s)
	for n in notes:
		print("note: ", n)
	print("ハードの鍵（保存）：", main.progress.hard_open, "  保存：Lv ", main.progress.lv, " 武器 ", main.progress.weapon, " 最速 ", main.progress.best)
	print("スキルを使った回数：", main.player.skill_uses, "  必殺技：", ult_uses)
	for tl in tree_log:
		print("ツリー ", tl)
	print("SP（レベル＋初回クリア）：", main.progress.sp, "  期待 ", (main.progress.lv - 1) + 2 * main.progress.first_clear_paid.size(), "  初回クリア ", main.progress.first_clear_paid)
	print("当たった数（味方の合計） ", main.battle.stat_hits, "  ダメージ合計 ", int(main.battle.stat_dmg))
	if main.battle.ally:
		print("リリィの技の回数：", main.battle.ally.sk_used)
	if main.battle.ranka:
		print("ランカの技の回数：", main.battle.ranka.sk_used)
	print("DUNGEON DONE")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
