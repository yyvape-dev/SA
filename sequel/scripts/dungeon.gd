extends Node
## インスタントダンジョン1回分：間取り（dungeon_map.gd）・部屋の出入り・敵の波・出口の開閉・武器の落とし物・ボス・クリア時間と被弾回数。
## 部屋の敵を全部倒すと出口が開く（赤＝閉じている、水色＝開いている）。ボスを倒すとクリア。

const Map := preload("res://scripts/dungeon_map.gd")
const COL_OPEN := Color(0.16, 0.88, 1.0)
const COL_SHUT := Color(1.0, 0.2, 0.2)
const COL_GOLD := Color(1.0, 0.78, 0.3)
const DIFF := {
	"normal": {"hp": 1.0, "dmg": 1.0, "add": 0, "boss_hp": 1100.0, "boss_dmg": 14, "xp": 12, "boss_xp": 150, "drop": 0.14, "w": [2, 6], "bw": [12, 18]},
	"hard":   {"hp": 1.7, "dmg": 1.6, "add": 2, "boss_hp": 2200.0, "boss_dmg": 24, "xp": 20, "boss_xp": 260, "drop": 0.2, "w": [7, 13], "bw": [22, 30]},
}

var main          # main.gd
var diff := "normal"
var seed_val := -1
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
	return DIFF[diff]

func start() -> void:
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	layout = Map.generate(rng)
	main.battle.foe_hp_mul = cfg().hp
	main.battle.foe_dmg_mul = cfg().dmg
	hits0 = main.battle.hits_taken
	lv0 = main.progress.lv
	w0 = main.progress.weapon
	main.battle.hp = main.battle.hp_max
	_enter(layout.entrance, "")
	main.hud.show_dungeon(true)
	log_ev("start", diff)

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
	boss_t = 1.2 if (is_boss_room(c) and not room_open) else -1.0
	log_ev("enter", c)

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
		if b.alive_count() == 0:
			if wave_i < room.waves.size():
				wave_t -= delta
				if wave_t <= 0.0:
					_spawn_wave(int(room.waves[wave_i]))
					wave_i += 1
					wave_t = 1.0
			else:
				_open_room()
	if room_open:
		_check_exits()

func _spawn_wave(n: int) -> void:
	var b = main.battle
	var rw: float = room.rw
	var p: Node3D = main.player
	n = mini(n + int(cfg().add), 7)
	var side := 1 if p.position.x < 0.0 else -1
	for i in n:
		var s := side if i % 3 != 2 else -side   # 3体に1体は反対側から
		var x: float = s * (rw - rng.randf_range(0.6, 2.6))
		if absf(x - p.position.x) < 4.0:
			x = -x
		b.spawn(["1", "3"][rng.randi() % 2], Vector3(x, 0, rng.randf_range(main.BELT_Z.x, main.BELT_Z.y)))
	log_ev("wave", n)

func _spawn_boss() -> void:
	var b = main.battle
	var p: Node3D = main.player
	var x: float = (room.rw - 3.0) * (-1.0 if p.position.x > 0.0 else 1.0)
	boss = b.spawn("g1", Vector3(x, 0, 0.2))
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
	var key := diff
	var nb: bool = not pr.best.has(key) or t_run < float(pr.best[key])
	if nb:
		pr.best[key] = t_run
	pr.clears[key] = int(pr.clears.get(key, 0)) + 1
	var unlocked := false
	if diff == "normal" and not pr.hard_open:
		pr.hard_open = true
		unlocked = true
	pr.save()
	result = {"time": t_run, "hits": hits, "lv0": lv0, "lv": pr.lv, "w0": w0, "w": pr.weapon, "best": nb, "diff": diff, "unlocked": unlocked}
	log_ev("result", result)
	main.hud.show_result(result)

## 結果の画面を閉じた → 街へ戻る
func close_result() -> void:
	main.player.locked = false
	main.hud.show_dungeon(false)
	main.hud.fade(0.6)
	main.leave_dungeon()
