extends RefCounted
## インスタントダンジョンの間取り：5×5 のマス目に 12〜14 部屋を毎回ランダムにつなぐ（木の形＝行き止まりができる）。
## 入口は固定（下の段の中央）。ボス部屋は「入口から5部屋以上離れた行き止まり」からランダム（無ければいちばん遠い行き止まり）。
## 2026-11-14（specs/dungeon_themes.md 3.1）：3×3・6 部屋・1〜1.5 画面から広げた。
## 向き：L＝左 R＝右 B＝奥（マス目の上） F＝手前（マス目の下）。

const N := 5
const ROOMS_MIN := 12
const ROOMS_MAX := 14
const BOSS_D := 5
const ENTRANCE := Vector2i(2, 4)
const GROUPS := 3            # 1 部屋の敵の群れの数（ボス部屋は無し）
const GROUP_N := Vector2i(4, 6)   # 1 群れの体数（難易度で +add）
const DIRS := {"L": Vector2i(-1, 0), "R": Vector2i(1, 0), "B": Vector2i(0, -1), "F": Vector2i(0, 1)}
const OPP := {"L": "R", "R": "L", "B": "F", "F": "B"}
const BLD := ["b1_tavern", "b2_workshop", "b3_shop", "b4_bridge"]
const FG := ["f1_lamp", "f2_pipe", "f3_lamp"]

## 戻り値：{entrance, boss, rooms: {Vector2i: room}}。room＝{cell, exits:{dir: Vector2i}, dist, rw, slots, slot_x, fg, back_ofs, bx, fx, groups（群れごとの体数）}
static func generate(rng: RandomNumberGenerator) -> Dictionary:
	for attempt in 500:
		var cells: Array = [ENTRANCE]
		var exits := {ENTRANCE: {}}
		var want := rng.randi_range(ROOMS_MIN, ROOMS_MAX)
		while cells.size() < want:
			var c: Vector2i = cells[rng.randi() % cells.size()]
			var dk: String = DIRS.keys()[rng.randi() % 4]
			var n: Vector2i = c + DIRS[dk]
			if n.x < 0 or n.y < 0 or n.x >= N or n.y >= N or exits.has(n):
				continue
			cells.append(n)
			exits[n] = {}
			exits[c][dk] = n
			exits[n][OPP[dk]] = c
		var dist := _bfs(exits, ENTRANCE)
		var cand := []
		var far_d := 0
		for c in cells:
			if c != ENTRANCE and exits[c].size() == 1:
				far_d = maxi(far_d, int(dist[c]))
		if far_d < (BOSS_D if attempt < 450 else 3):   # 5 部屋以上の行き止まりが出るまで作り直す
			continue
		for c in cells:
			if c != ENTRANCE and exits[c].size() == 1 and int(dist[c]) >= mini(BOSS_D, far_d):
				cand.append(c)
		if cand.is_empty():
			continue
		var boss: Vector2i = cand[rng.randi() % cand.size()]
		var rooms := {}
		for c in cells:
			rooms[c] = _room(rng, c, exits[c], int(dist[c]))
		return {"entrance": ENTRANCE, "boss": boss, "rooms": rooms}
	return {}

static func _bfs(exits: Dictionary, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in exits[c]:
			var n: Vector2i = exits[c][d]
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist

## 次の部屋への道（最短）。from から to へ向かう最初の向きを返す（無ければ ""）
static func first_step(layout: Dictionary, from: Vector2i, to: Vector2i) -> String:
	var ex := {}
	for c in layout.rooms:
		ex[c] = layout.rooms[c].exits
	var dist := _bfs(ex, to)
	if not dist.has(from):
		return ""
	for d in ex[from]:
		if int(dist.get(ex[from][d], 999)) < int(dist[from]):
			return d
	return ""

static func _room(rng: RandomNumberGenerator, c: Vector2i, ex: Dictionary, dist: int) -> Dictionary:
	# 幅：2〜3 画面（rw は半分の幅。横持ちの画面の幅 ≈ 19m）
	var rw := rng.randf_range(19.0, 29.0)
	# 建物：9.6m おきに、カメラが端まで動いても切れない数だけ（同じ建物を隣に並べない）
	var k := int(ceil((rw + 10.3 - 4.8) / 9.6))
	var slots := []
	var slot_x := []
	var prev := ""
	for i in 2 * k + 1:
		var id: String = prev
		while id == prev:
			id = BLD[rng.randi() % BLD.size()]
		slots.append(id)
		slot_x.append((i - k) * 9.6 + rng.randf_range(-0.6, 0.6))
		prev = id
	var fg := []
	for i in rng.randi_range(1, 2) * int(ceil(rw / 12.0)):
		fg.append([FG[rng.randi() % FG.size()], rng.randf_range(-rw + 2.0, rw - 2.0)])
	# 奥・手前の出口の左右の位置（重ならないように離す）
	var bx := rng.randf_range(-rw + 3.5, rw - 3.5)
	var fx := bx
	while absf(fx - bx) < 6.0:
		fx = rng.randf_range(-rw + 3.5, rw - 3.5)
	var groups := []
	for i in GROUPS:
		groups.append(rng.randi_range(GROUP_N.x, GROUP_N.y))
	return {"cell": c, "exits": ex, "dist": dist, "rw": rw, "slots": slots, "slot_x": slot_x, "fg": fg,
		"back_ofs": rng.randf_range(-5.0, 5.0), "bx": bx, "fx": fx, "groups": groups}

## 間取りの確認（DUNGEON_LAYOUT_TEST=1）：たくさん作って、決まりを守っているか数える
static func self_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var bad := 0
	var shapes := {}
	var boss_d := {}
	var adj_same := 0
	var n_rooms := {}
	var n := 20000
	for i in n:
		var L := generate(rng)
		if L.is_empty():
			bad += 1
			continue
		var rooms: Dictionary = L.rooms
		var ok: bool = rooms.size() >= ROOMS_MIN and rooms.size() <= ROOMS_MAX and rooms.has(ENTRANCE)
		var ex := {}
		for c in rooms:
			ex[c] = rooms[c].exits
			for d in rooms[c].exits:   # つながりは両向き・となりのマスだけ
				var nb: Vector2i = rooms[c].exits[d]
				ok = ok and nb == c + DIRS[d] and rooms.has(nb) and rooms[nb].exits.get(OPP[d]) == c
			for k in range(1, 5):
				if rooms[c].slots[k] == rooms[c].slots[k - 1]:
					adj_same += 1
		var dist := _bfs(ex, ENTRANCE)
		ok = ok and dist.size() == rooms.size()                   # 全部の部屋へ行ける
		ok = ok and ex[L.boss].size() == 1 and int(dist[L.boss]) >= 3   # ボス＝行き止まり・3部屋以上（5 以上が無い時はいちばん遠い行き止まり）
		n_rooms[rooms.size()] = int(n_rooms.get(rooms.size(), 0)) + 1
		if not ok:
			bad += 1
		boss_d[int(dist[L.boss])] = int(boss_d.get(int(dist[L.boss]), 0)) + 1
		var key := ""
		for y in N:
			for x in N:
				key += "1" if rooms.has(Vector2i(x, y)) else "0"
		shapes[key] = true
	print("LAYOUT TEST n=%d 決まりの違反=%d 隣の同じ建物=%d 部屋の置き方の種類=%d ボスまでの部屋数=%s 部屋の数=%s" % [n, bad, adj_same, shapes.size(), str(boss_d), str(n_rooms)])
