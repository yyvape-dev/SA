extends RefCounted
## インスタントダンジョンの間取り：3×3 のマス目に6部屋を毎回ランダムにつなぐ（木の形＝行き止まりができる）。
## 入口は固定（下の段の中央）。ボス部屋は「入口から3部屋以上離れた行き止まり」からランダム。
## 向き：L＝左 R＝右 B＝奥（マス目の上） F＝手前（マス目の下）。

const N := 3
const ROOMS := 6
const ENTRANCE := Vector2i(1, 2)
const DIRS := {"L": Vector2i(-1, 0), "R": Vector2i(1, 0), "B": Vector2i(0, -1), "F": Vector2i(0, 1)}
const OPP := {"L": "R", "R": "L", "B": "F", "F": "B"}
const BLD := ["b1_tavern", "b2_workshop", "b3_shop", "b4_bridge"]
const FG := ["f1_lamp", "f2_pipe", "f3_lamp"]

## 戻り値：{entrance, boss, rooms: {Vector2i: room}}。room＝{cell, exits:{dir: Vector2i}, dist, rw, slots, slot_x, fg, back_ofs, bx, fx, waves}
static func generate(rng: RandomNumberGenerator) -> Dictionary:
	for attempt in 500:
		var cells: Array = [ENTRANCE]
		var exits := {ENTRANCE: {}}
		while cells.size() < ROOMS:
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
		for c in cells:
			if c != ENTRANCE and exits[c].size() == 1 and int(dist[c]) >= 3:
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
	# 幅：1〜1.5画面（横持ちの画面の幅 ≈ 19m）。rw は半分の幅
	var rw := rng.randf_range(9.5, 14.0)
	# 建物：5か所に、同じ建物を隣に並べない
	var slots := []
	var slot_x := []
	var prev := ""
	for i in 5:
		var id: String = prev
		while id == prev:
			id = BLD[rng.randi() % BLD.size()]
		slots.append(id)
		slot_x.append((i - 2) * 9.6 + rng.randf_range(-0.6, 0.6))
		prev = id
	var fg := []
	for i in rng.randi_range(1, 2):
		fg.append([FG[rng.randi() % FG.size()], rng.randf_range(-rw + 2.0, rw - 2.0)])
	# 奥・手前の出口の左右の位置（重ならないように離す）
	var bx := rng.randf_range(-rw + 3.5, rw - 3.5)
	var fx := bx
	while absf(fx - bx) < 4.0:
		fx = rng.randf_range(-rw + 3.5, rw - 3.5)
	var waves := [rng.randi_range(3, 4)]
	if rng.randf() < 0.55:
		waves.append(rng.randi_range(3, 4) + (1 if dist >= 2 else 0))
	return {"cell": c, "exits": ex, "dist": dist, "rw": rw, "slots": slots, "slot_x": slot_x, "fg": fg,
		"back_ofs": rng.randf_range(-5.0, 5.0), "bx": bx, "fx": fx, "waves": waves}

## 間取りの確認（DUNGEON_LAYOUT_TEST=1）：たくさん作って、決まりを守っているか数える
static func self_test() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var bad := 0
	var shapes := {}
	var boss_d := {}
	var adj_same := 0
	var n := 20000
	for i in n:
		var L := generate(rng)
		if L.is_empty():
			bad += 1
			continue
		var rooms: Dictionary = L.rooms
		var ok: bool = rooms.size() == ROOMS and rooms.has(ENTRANCE)
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
		ok = ok and dist.size() == ROOMS                          # 全部の部屋へ行ける
		ok = ok and ex[L.boss].size() == 1 and int(dist[L.boss]) >= 3   # ボス＝行き止まり・3部屋以上
		if not ok:
			bad += 1
		boss_d[int(dist[L.boss])] = int(boss_d.get(int(dist[L.boss]), 0)) + 1
		var key := ""
		for y in N:
			for x in N:
				key += "1" if rooms.has(Vector2i(x, y)) else "0"
		shapes[key] = true
	print("LAYOUT TEST n=%d 決まりの違反=%d 隣の同じ建物=%d 部屋の置き方の種類=%d ボスまでの部屋数=%s" % [n, bad, adj_same, shapes.size(), str(boss_d)])
