extends CanvasLayer
## ダンジョンまわりの画面：レベル・経験値・武器（いつも）、右上の小さな地図・時間・ボスの体力（ダンジョンの中）、
## 難易度を選ぶ画面、結果の画面、暗転。文字は使わず、数字と色と記号だけ。
## 色：青＝味方・ノーマル、赤＝敵・ハード、金＝物資・決着。

var main
var menu_open := false
var slot_open := false     # スキルのスロット設定（街だけ）
var slot_pick := ""        # 一覧で選んだ技
const SkillIcons := preload("res://scripts/skill_icons.gd")
const SkillTree := preload("res://scripts/skill_tree.gd")
const SelectArt := preload("res://scripts/dungeon_select_art.gd")
var menu_feedback_pos := Vector2.ZERO
var menu_feedback_t := 0.0
var _covered_world: Node3D
var _covered_world_visible := true
const Art := preload("res://scripts/t6_hud_art.gd")
## スキルツリー（specs/skill_tree.md 4.）：仮で歯車の画面に「スロット｜ツリー」の切り替えを足した（開き方は未決）
var slot_mode := "slot"    # "slot"＝スロット設定、"tree"＝スキルツリー
var tree_ch := "rana"      # 選んでいるキャラのタブ
var respec_arm := 0.0      # 振り直しの確認（1回目を押してから 3 秒の間に、もう1回で実行）
var tree_flash := {}       # 押した所の光（キー → 残り秒）
var menu_sel := 0          # 難易度の画面：0＝ノーマル 1＝ハード 2＝エキスパート／テーマの画面：0〜3＝T1〜T4
var menu_stage := "theme"  # "theme"＝テーマの札（specs/dungeon_themes.md 3.3）→ "diff"＝難易度の札
var menu_theme := 0        # 選んだテーマ
var shake_i := -1          # 揺らす札（錠で選べない）
const Themes := preload("res://scripts/dungeon_themes.gd")
var menu_t := 0.0
var in_dungeon := false
var result := {}
var result_t := -1.0
var fade_t := 0.0
var fade_d := 0.0
var lv_flash := 0.0
var w_flash := 0.0
var shake_hard := 0.0
var view: Control

const BLUE := Color("3d8bff")
const RED := Color("ff3b3b")
const GOLD := Color("ffc94d")
const DIM := Color(0.02, 0.03, 0.07, 0.75)

func _ready() -> void:
	layer = 5
	view = _View.new()
	view.hud = self
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

func _process(delta: float) -> void:
	_sync_menu_world()
	menu_t += delta
	menu_feedback_t = maxf(0.0, menu_feedback_t - delta)
	if result_t >= 0.0:
		result_t += delta
	fade_t = maxf(0.0, fade_t - delta)
	respec_arm = maxf(0.0, respec_arm - delta)
	for k in tree_flash.keys():
		tree_flash[k] = float(tree_flash[k]) - delta
		if tree_flash[k] <= 0.0:
			tree_flash.erase(k)
	lv_flash = maxf(0.0, lv_flash - delta)
	w_flash = maxf(0.0, w_flash - delta)
	shake_hard = maxf(0.0, shake_hard - delta)
	view.queue_redraw()

## The map is opaque. Skip hidden 3D drawing, restore the exact previous visibility.
func _sync_menu_world() -> void:
	var covered: bool = menu_open or (main != null and "loading" in main and is_instance_valid(main.loading) and main.loading.visible)
	var wanted: Node3D = main.level if covered and main != null and "level" in main else null
	if is_instance_valid(_covered_world) and _covered_world != wanted:
		_covered_world.visible = _covered_world_visible
		_covered_world = null
	if wanted != null and wanted != _covered_world:
		_covered_world = wanted
		_covered_world_visible = wanted.visible
		wanted.visible = false

func fade(d: float) -> void:
	fade_d = d
	fade_t = d

func flash_lv() -> void:
	lv_flash = 1.2

func flash_weapon() -> void:
	w_flash = 1.2

func show_dungeon(on: bool) -> void:
	in_dungeon = on

# ---------- 難易度を選ぶ ----------
func open_menu() -> void:
	menu_open = true
	menu_t = 0.0
	menu_stage = "theme"   # "theme"＝地図（ダンジョンを選ぶ）→ "diff"＝地図＋右の札（難易度と入場）→ "party"＝仲間の選択
	menu_sel = 0
	for i in Themes.THEMES.size():   # いちばん奥の開いているテーマを選んでおく
		if main.progress.theme_open(i):
			menu_theme = i
	main.player.locked = true
	main.battle.process_mode = Node.PROCESS_MODE_DISABLED

func close_menu() -> void:
	menu_open = false
	main.player.locked = false
	main.battle.process_mode = Node.PROCESS_MODE_INHERIT

## 地図でダンジョンを選ぶ（0〜3）。前のテーマのノーマルのクリアで開く。開いていれば右に札が出る
func choose_theme(i: int) -> bool:
	if not main.progress.theme_open(i):
		shake_hard = 0.4
		shake_i = 10 + i
		return false
	menu_theme = i
	menu_stage = "diff"
	menu_t = 0.0
	menu_sel = 0
	for k in range(last_diff, -1, -1):   # 前に選んだ難易度（開いていなければ下へ）。最初はノーマル
		if main.progress.diff_open(Themes.THEMES[i].id, Themes.DIFF_ORDER[k]):
			menu_sel = k
			break
	return true

var last_diff := 0

## 難易度を決めて仲間の選択へ（撮影・自動テストでは仲間を全員つれて、そのまま入る）。
## 0＝ノーマル 1＝ハード 2＝エキスパート。ハードはノーマル、エキスパートはハードのクリアで開く
func choose(i: int) -> bool:
	var th: String = Themes.THEMES[menu_theme].id
	var dk: String = Themes.DIFF_ORDER[i]
	if not main.progress.diff_open(th, dk):
		shake_hard = 0.4
		shake_i = i
		return false
	menu_sel = i
	if not main.party_flow():
		close_menu()
		fade(0.6)
		main.enter_dungeon(dk, main.dungeon_seed(), th)
		return true
	menu_stage = "party"
	menu_t = 0.0
	pick = []
	for id in main.party_last:   # 前の組み合わせ（人数の上限で切る）
		if main.ally_ready(id) and pick.size() < party_cap() - 1:
			pick.append(id)
	return true

## 入れる人数（ラナを含む）：ノーマル 2 人、ハード以上 3 人（2026-11-15 ユーザー）
func party_cap() -> int:
	return 2 if menu_sel == 0 else 3

const ALLY_IDS := ["lily", "ranka", "", ""]   # 空＝今後の仲間（錠）
var pick: Array = []

func toggle_ally(k: int) -> void:
	var id: String = ALLY_IDS[k]
	if id == "" or not main.ally_ready(id):
		shake_hard = 0.4
		shake_i = 20 + k
		return
	if id in pick:
		pick.erase(id)
	elif pick.size() < party_cap() - 1:
		pick.append(id)
	else:
		shake_hard = 0.4
		shake_i = 30   # 人数の点を揺らす
	menu_t = maxf(menu_t, 0.3)

func go() -> void:
	main.party_last = pick.duplicate()
	last_diff = menu_sel
	close_menu()
	fade(0.6)
	main.enter_dungeon(Themes.DIFF_ORDER[menu_sel], main.dungeon_seed(), Themes.THEMES[menu_theme].id, pick.duplicate())

func menu_back() -> void:
	menu_t = 0.0
	if menu_stage == "party":
		menu_stage = "diff"
	elif menu_stage == "diff":
		menu_stage = "theme"
	else:
		close_menu()

# ---------- スキルのスロット設定（specs/skill_ui.md 2.） ----------
func open_slots() -> void:
	if main.dungeon != null:
		return
	slot_open = true
	slot_pick = ""
	respec_arm = 0.0
	menu_t = 0.0
	main.player.locked = true
	main.battle.process_mode = Node.PROCESS_MODE_DISABLED

func close_slots() -> void:
	slot_open = false
	main.player.locked = false
	main.battle.process_mode = Node.PROCESS_MODE_INHERIT
	main.progress.save()
	main.apply_progress()   # ツリーで変えた技レベル・派生を3人の技の表へ

## ツリーの画面を押した
func tree_tap(pos: Vector2) -> void:
	var r: Dictionary = view.tree_rects()
	if r.close.has_point(pos) or not r.panel.has_point(pos):
		close_slots()
		return
	if r.tab_slot.has_point(pos):
		slot_mode = "slot"
		return
	var pr = main.progress
	for i in SkillTree.CHARS.size():
		if r["ch%d" % i].has_point(pos):
			tree_ch = SkillTree.CHARS[i]
			respec_arm = 0.0
			return
	if r.respec.has_point(pos):
		if respec_arm > 0.0:
			pr.respec(tree_ch)
			respec_arm = 0.0
			tree_flash["respec"] = 0.4
		else:
			respec_arm = 3.0
		return
	var rows: Dictionary = SkillTree.rows(tree_ch)
	for id in SkillTree.order(tree_ch):
		if r.has("lv_" + id) and r["lv_" + id].has_point(pos):
			if pr.level_up(tree_ch, id):
				tree_flash["lv_" + id] = 0.35
			else:
				tree_flash["no_" + id] = 0.3
			return
		for did in rows[id].get("derivs", {}):
			var k: String = "d_%s_%s" % [id, did]
			if r.has(k) and r[k].has_point(pos):
				if pr.set_deriv(tree_ch, id, did):
					tree_flash[k] = 0.35
				else:
					tree_flash["no_" + k] = 0.3
				return

## 一覧の技を選ぶ → 枠を押すと入れる（同じ技が他の枠にあれば入れ替え）
func slot_tap(pos: Vector2) -> void:
	if slot_mode == "tree":
		tree_tap(pos)
		return
	var r: Dictionary = view.slot_rects()
	if r.tab_tree.has_point(pos):
		slot_mode = "tree"
		slot_pick = ""
		return
	if r.close.has_point(pos) or not r.panel.has_point(pos):
		close_slots()
		return
	var pr = main.progress
	for i in 3:
		if r["slot%d" % i].has_point(pos):
			if slot_pick != "":
				var old: String = str(pr.skill_slots[i])
				var j: int = pr.skill_slots.find(slot_pick)
				if j >= 0:
					pr.skill_slots[j] = old
				pr.skill_slots[i] = slot_pick
				slot_pick = ""
			return
	for i in pr.skills_owned.size():
		if r.has("own%d" % i) and r["own%d" % i].has_point(pos):
			slot_pick = "" if slot_pick == str(pr.skills_owned[i]) else str(pr.skills_owned[i])
			return

# ---------- 結果 ----------
func show_result(r: Dictionary) -> void:
	result = r
	result_t = 0.0

func confirm_result() -> void:
	if result_t < 1.2:
		return
	result_t = -1.0
	result = {}
	if main.dungeon:
		main.dungeon.close_result()

func _input(e: InputEvent) -> void:
	if slot_open:
		if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_K or e.keycode == KEY_X or e.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			close_slots()
		elif e is InputEventScreenTouch and e.pressed and menu_t > 0.2:
			get_viewport().set_input_as_handled()
			slot_tap(e.position)
		elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_T:   # T＝スロット／ツリーの切り替え（キーボード）
			get_viewport().set_input_as_handled()
			slot_mode = "slot" if slot_mode == "tree" else "tree"
		return
	if not menu_open and result_t < 0.0:
		return
	var key := -1
	if e is InputEventKey and e.pressed and not e.echo:
		key = e.keycode
	var tap := Vector2(-1, -1)
	if e is InputEventScreenTouch and e.pressed:
		tap = e.position
	if key < 0 and tap.x < 0:
		return
	get_viewport().set_input_as_handled()
	if result_t >= 0.0:
		confirm_result()
		return
	if menu_t < 0.05:
		return
	if tap.x >= 0:
		menu_feedback_pos = tap
		menu_feedback_t = 0.14
	var r: Dictionary = view.menu_rects()
	if menu_stage == "party":
		match key:
			KEY_1, KEY_2, KEY_3, KEY_4: toggle_ally(key - KEY_1)
			KEY_J, KEY_Z, KEY_ENTER, KEY_SPACE: go()
			KEY_ESCAPE, KEY_K, KEY_X: menu_back()
		if tap.x >= 0:
			for k in 4:
				if r["ally%d" % k].has_point(tap):
					toggle_ally(k)
					return
			if r.go.has_point(tap):
				go()
			elif r.close.has_point(tap):
				menu_back()
		return
	match key:
		KEY_A, KEY_LEFT: menu_theme = maxi(0, menu_theme - 1); menu_stage = "theme"
		KEY_D, KEY_RIGHT: menu_theme = mini(Themes.THEMES.size() - 1, menu_theme + 1); menu_stage = "theme"
		KEY_W, KEY_UP: menu_sel = maxi(0, menu_sel - 1)
		KEY_S, KEY_DOWN: menu_sel = mini(2, menu_sel + 1)
		KEY_1, KEY_2, KEY_3, KEY_4: choose_theme(key - KEY_1)
		KEY_J, KEY_Z, KEY_ENTER, KEY_SPACE:
			if menu_stage == "theme":
				choose_theme(menu_theme)
			else:
				choose(menu_sel)
		KEY_ESCAPE, KEY_K, KEY_X: menu_back()
	if tap.x >= 0:
		for i in Themes.THEMES.size():
			if r["node%d" % i].has_point(tap):
				choose_theme(i)
				return
		if menu_stage == "diff":
			for i in 3:
				if r["diff%d" % i].has_point(tap):
					if not main.progress.diff_open(Themes.THEMES[menu_theme].id, Themes.DIFF_ORDER[i]):
						shake_hard = 0.4
						shake_i = i
					else:
						menu_sel = i
					return
			if r.go.has_point(tap):
				choose(menu_sel)
				return
		if r.close.has_point(tap):
			menu_back()

## ---------- 描く ----------
class _View extends Control:
	var hud
	var font: Font

	func _ready() -> void:
		font = ThemeDB.fallback_font

	func _u() -> float:
		return size.y / 720.0

	func _num(p: Vector2, s: String, fs: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		var u := _u()
		draw_string_outline(font, p, s, align, w, int(fs * u), int(8 * u), Color(0, 0, 0, 0.9))
		draw_string(font, p, s, align, w, int(fs * u), col)

	func _diamond(c: Vector2, r: float, col: Color, filled := true) -> void:
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)])
		if filled:
			draw_colored_polygon(pts, col)
		else:
			pts.append(pts[0])
			draw_polyline(pts, col, 3 * _u())

	func _sword(c: Vector2, s: float, col: Color) -> void:
		var u := _u()
		draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 5 * u)
		draw_line(c + Vector2(-s * 0.85, s * 0.2), c + Vector2(-s * 0.2, s * 0.85), col, 4 * u)

	func _chev(c: Vector2, s: float, col: Color) -> void:
		draw_polyline(PackedVector2Array([c + Vector2(-s, s * 0.5), c + Vector2(0, -s * 0.5), c + Vector2(s, s * 0.5)]), col, 5 * _u())

	func _clock(c: Vector2, r: float, col: Color) -> void:
		draw_arc(c, r, 0, TAU, 32, col, 4 * _u())
		draw_line(c, c + Vector2(0, -r * 0.7), col, 4 * _u())
		draw_line(c, c + Vector2(r * 0.55, 0), col, 4 * _u())

	func _burst(c: Vector2, r: float, col: Color) -> void:
		for i in 4:
			var a := PI * 0.25 + i * PI * 0.5
			draw_line(c + Vector2(cos(a), sin(a)) * r * 0.25, c + Vector2(cos(a), sin(a)) * r, col, 5 * _u())

	func _lock(c: Vector2, s: float, col: Color) -> void:
		var u := _u()
		draw_arc(c + Vector2(0, -s * 0.35), s * 0.5, PI, TAU, 16, col, 5 * u)
		draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.35), Vector2(s * 1.4, s * 1.1)), col)

	func _time_str(t: float) -> String:
		var m := int(t / 60.0)
		return "%d:%05.2f" % [m, t - m * 60.0]

	func _draw() -> void:
		var u := _u()
		var m = hud.main
		if m == null or m.progress == null:
			return
		var pr = m.progress
		# レベル（金の山形＋数字）・経験値の細い帯（金）・武器（剣＋数字）。体力の帯（touch_ui）の下
		var y := 150.0 * u   # 必殺技のゲージ（体力の帯の下）の下
		var lvc := GOLD.lerp(Color.WHITE, hud.lv_flash) if hud.lv_flash > 0.0 else GOLD
		_chev(Vector2(48 * u, y - 10 * u), 11 * u, lvc)
		_num(Vector2(66 * u, y), str(pr.lv), 30, lvc)
		var bx := 112.0 * u
		draw_rect(Rect2(Vector2(bx, y - 16 * u), Vector2(150 * u, 8 * u)), DIM)
		draw_rect(Rect2(Vector2(bx, y - 16 * u), Vector2(150 * u * float(pr.xp) / float(pr.need()), 8 * u)), GOLD)
		var wc := GOLD if hud.w_flash > 0.0 and int(hud.w_flash * 8) % 2 == 0 else Color(0.9, 0.92, 1.0)
		_sword(Vector2(296 * u, y - 10 * u), 10 * u, wc)
		_num(Vector2(316 * u, y), str(pr.weapon), 30, wc)
		# 仲間の体力（青＝味方。倒れている間は灰で、起きるまでの残りを細い線で）
		var ay := y + 18 * u
		for a in m.battle.ally_list():
			if not a.has_method("hp_ratio"):
				continue
			var down: bool = a.state == "down"
			draw_circle(Vector2(54 * u, ay + 4 * u), 6 * u, Color(0.75, 0.88, 1.0) if not down else Color(0.4, 0.4, 0.45))
			draw_rect(Rect2(Vector2(68 * u, ay), Vector2(140 * u, 8 * u)), DIM)
			if down:
				draw_rect(Rect2(Vector2(68 * u, ay + 3 * u), Vector2(140 * u * (1.0 - a.down_t / a.DOWN_T), 2 * u)), Color(0.6, 0.6, 0.66))
			else:
				draw_rect(Rect2(Vector2(68 * u, ay), Vector2(140 * u * a.hp_ratio(), 8 * u)), Color(0.45, 0.72, 1.0))
			ay += 16 * u
		var d = m.dungeon
		if hud.in_dungeon and d != null and not d.layout.is_empty():
			_map(d)
			_num(Vector2(0, 52 * u), _time_str(d.t_run), 34, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_CENTER, size.x)
			if d.boss != null and is_instance_valid(d.boss):
				var w := 560.0 * u
				var p := Vector2((size.x - w) * 0.5, 70 * u)
				var r: float = maxf(0.0, d.boss.hp / d.boss.hp_max)
				draw_rect(Rect2(p - Vector2(4, 4) * u, Vector2(w, 18 * u) + Vector2(8, 8) * u), DIM)
				draw_rect(Rect2(p, Vector2(w * r, 18 * u)), RED)
				draw_rect(Rect2(p, Vector2(w * r, 6 * u)), Color(1, 1, 1, 0.25))
		if hud.menu_open:
			_menu()
		if hud.slot_open:
			if hud.slot_mode == "tree":
				_tree()
			else:
				_slots()
		if hud.result_t >= 0.0:
			_result()
		if hud.fade_t > 0.0 and hud.fade_d > 0.0:
			var k: float = 1.0 - hud.fade_t / hud.fade_d
			var a: float = 1.0 - absf(2.0 * k - 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.03, clampf(a * 1.4, 0.0, 1.0)))

	## 右上の小さな地図：今いる部屋（明るい青）・行った部屋（暗い青）・となりの知らない部屋（枠だけ）・ボス部屋（赤。最初から表示）
	func _map(d) -> void:
		var u := _u()
		var cs := 17.0 * u
		var gap := 8.0 * u
		var n := 5
		var org := Vector2(size.x - 30 * u - n * cs - (n - 1) * gap, 26 * u)
		draw_rect(Rect2(org - Vector2(10, 10) * u, Vector2(n * cs + (n - 1) * gap, n * cs + (n - 1) * gap) + Vector2(20, 20) * u), DIM)
		var known := {}
		for c in d.visited:
			known[c] = true
			for k in d.layout.rooms[c].exits:
				known[d.layout.rooms[c].exits[k]] = true
		known[d.layout.boss] = true
		var ctr := func(c: Vector2i) -> Vector2:
			return org + Vector2(c.x * (cs + gap) + cs * 0.5, c.y * (cs + gap) + cs * 0.5)
		for c in d.visited:
			for k in d.layout.rooms[c].exits:
				var nb: Vector2i = d.layout.rooms[c].exits[k]
				draw_line(ctr.call(c), ctr.call(nb), Color(0.55, 0.7, 1.0, 0.8), 3 * u)
		for c in known:
			var r := Rect2(ctr.call(c) - Vector2(cs, cs) * 0.5, Vector2(cs, cs))
			if c == d.cur:
				draw_rect(r, Color(0.6, 0.85, 1.0))
			elif d.visited.has(c):
				draw_rect(r, Color(0.2, 0.36, 0.7))
			elif c == d.layout.boss:
				draw_rect(r, Color(0.35, 0.05, 0.06))
			else:
				draw_rect(r, Color(0.08, 0.1, 0.16))
			if c == d.layout.boss:
				draw_rect(r, RED, false, 3 * u)
				_diamond(ctr.call(c), cs * 0.32, RED if c != d.cur else Color(0.7, 0.05, 0.08))
			elif not d.visited.has(c):
				draw_rect(r, Color(0.55, 0.7, 1.0, 0.5), false, 2 * u)
		# 入口（紫の小さな点）
		draw_circle(ctr.call(d.layout.entrance) + Vector2(0, cs * 0.5 + 5 * u), 3.5 * u, Color(0.72, 0.5, 1.0))

	## 地図（アラド戦記風）：画面いっぱいの地図に、門から奥へ続く道と 4 つのダンジョン。右に選んだダンジョンの札
	const NODE_POS := [Vector2(250, 520), Vector2(440, 300), Vector2(640, 500), Vector2(820, 250)]
	func menu_rects() -> Dictionary:
		return SelectArt.rects(size, hud.menu_stage, hud.menu_t, hud.shake_i, hud.shake_hard)

	func _theme_glyph(i: int, c: Vector2, s: float, col: Color) -> void:
		var u := _u()
		match i:
			0:
				for k in 3:
					var x := (k - 1) * s * 0.55
					var h := s * (0.9 if k == 1 else 0.65)
					draw_rect(Rect2(c + Vector2(x - s * 0.13, -h * 0.5), Vector2(s * 0.26, h)), col)
			1:
				draw_polyline(PackedVector2Array([c + Vector2(-0.1, -1) * s * 0.6, c + Vector2(0.25, -0.35) * s * 0.6, c + Vector2(-0.2, 0.15) * s * 0.6, c + Vector2(0.2, 0.6) * s * 0.6, c + Vector2(0.0, 1.0) * s * 0.6]), col, 8 * u)
			2:
				draw_arc(c, s * 0.5, 0, TAU, 40, col, 7 * u)
				draw_arc(c, s * 0.3, 0, TAU, 32, Color(col.r, col.g, col.b, 0.6), 4 * u)
			3:
				var pts := PackedVector2Array([c + Vector2(0, -0.62) * s, c + Vector2(0.3, -0.1) * s, c + Vector2(0.18, 0.55) * s, c + Vector2(-0.18, 0.55) * s, c + Vector2(-0.3, -0.1) * s])
				draw_colored_polygon(pts, col)

	func _menu() -> void:
		SelectArt.map(self, hud, size)

	func _dg_panel(r: Dictionary) -> void:
		SelectArt.panel(self, hud, r, size)

	func _go_btn(g: Rect2) -> void:
		SelectArt.go_button(self, g, _u(), hud.menu_t)

	func _person(c: Vector2, s: float, col: Color) -> void:
		draw_circle(c + Vector2(0, -s * 0.9), s * 0.55, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, s * 1.1), c + Vector2(-s * 0.55, -s * 0.15), c + Vector2(s * 0.55, -s * 0.15), c + Vector2(s * 0.85, s * 1.1)]), col)

	## 仲間の選択：左にラナ（固定・金）、右に仲間の札（選ぶと青）。上に人数の点。今後の仲間は錠
	func _party(r: Dictionary) -> void:
		SelectArt.party(self, hud, r, size)

	func _face_card(rc: Rect2, tex: Texture2D, col: Color, on: bool, locked: bool) -> void:
		SelectArt.face_card(self, rc, tex, col, on, locked, _u())

	func slot_rects() -> Dictionary:
		var u := _u()
		var c := size * 0.5
		var panel := Rect2(c - Vector2(330, 230) * u, Vector2(660, 460) * u)
		var out := {"panel": panel, "close": Rect2(panel.position + Vector2(panel.size.x - 52 * u, 8 * u), Vector2(44, 44) * u)}
		out.tab_slot = Rect2(panel.position + Vector2(12, 10) * u, Vector2(84, 40) * u)   # 切り替え（スロット｜ツリー）
		out.tab_tree = Rect2(panel.position + Vector2(100, 10) * u, Vector2(84, 40) * u)
		for i in 3:   # 上に3枠
			out["slot%d" % i] = Rect2(c + Vector2((i - 1) * 170 - 65, -170) * u, Vector2(130, 130) * u)
		var own: Array = hud.main.progress.skills_owned
		for i in own.size():   # 下に持っている技
			out["own%d" % i] = Rect2(c + Vector2((i - (own.size() - 1) * 0.5) * 130 - 50, 50) * u, Vector2(100, 100) * u)
		return out

	func _slots() -> void:
		var u := _u()
		var pr = hud.main.progress
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var r := slot_rects()
		draw_rect(r.panel, Color(0.04, 0.04, 0.09, 0.92))
		draw_rect(r.panel, Color(0.72, 0.5, 1.0, 0.8), false, 3 * u)
		_close_x(r.close)
		_mode_tabs(r)
		for i in 3:
			var rc: Rect2 = r["slot%d" % i]
			draw_rect(rc, Color(0.1, 0.12, 0.2, 0.9))
			draw_rect(rc, GOLD if hud.slot_pick != "" else Color(1, 1, 1, 0.5), false, 3 * u)
			_num(rc.position + Vector2(8, 28) * u, str(i + 1), 24, Color(1, 1, 1, 0.6))
			SkillIcons.draw(self, str(pr.skill_slots[i]), rc.get_center(), rc.size.x * 0.5, Color.WHITE, u)
		# 枠と一覧の境目に下向きの山形
		var mid := size * 0.5 + Vector2(0, 5 * u)
		draw_polyline(PackedVector2Array([mid + Vector2(-16, -8) * u, mid + Vector2(0, 6) * u, mid + Vector2(16, -8) * u]), Color(1, 1, 1, 0.5), 3 * u)
		for i in pr.skills_owned.size():
			var rc2: Rect2 = r["own%d" % i]
			var sel: bool = hud.slot_pick == str(pr.skills_owned[i])
			draw_rect(rc2, Color(0.08, 0.09, 0.15, 0.9))
			draw_rect(rc2, GOLD if sel else Color(1, 1, 1, 0.35), false, (5 if sel else 2) * u)
			SkillIcons.draw(self, str(pr.skills_owned[i]), rc2.get_center(), rc2.size.x * 0.5, Color.WHITE, u)

	func _close_x(rc: Rect2) -> void:
		var u := _u()
		var cc: Vector2 = rc.get_center()
		draw_line(cc + Vector2(-12, -12) * u, cc + Vector2(12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)
		draw_line(cc + Vector2(12, -12) * u, cc + Vector2(-12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)

	## 切り替えのタブ：左＝スロット（3つの枠）、右＝ツリー（枝）。選んでいる方は金の縁
	func _mode_tabs(r: Dictionary) -> void:
		var u := _u()
		for k in ["tab_slot", "tab_tree"]:
			var rc: Rect2 = r[k]
			var on: bool = (k == "tab_tree") == (hud.slot_mode == "tree")
			draw_rect(rc, Color(0.1, 0.12, 0.2, 0.95 if on else 0.6))
			draw_rect(rc, GOLD if on else Color(1, 1, 1, 0.3), false, (3 if on else 2) * u)
			var c := rc.get_center()
			var col := Color(1, 1, 1, 1.0 if on else 0.55)
			if k == "tab_slot":
				for i in 3:
					draw_rect(Rect2(c + Vector2(-25 + i * 18, -7) * u, Vector2(14, 14) * u), col, false, 2 * u)
			else:
				draw_line(c + Vector2(-26, 0) * u, c + Vector2(-6, 0) * u, col, 2 * u)
				draw_circle(c + Vector2(-26, 0) * u, 5 * u, col)
				for dy in [-10, 10]:
					draw_line(c + Vector2(-6, 0) * u, c + Vector2(14, dy) * u, col, 2 * u)
					draw_circle(c + Vector2(18, dy) * u, 5 * u, col)

	## ---------- スキルツリー（A 案「技ごとの枝」） ----------
	func tree_rects() -> Dictionary:
		var u := _u()
		var c := size * 0.5
		var panel := Rect2(c - Vector2(540, 330) * u, Vector2(1080, 660) * u)
		var out := {"panel": panel, "close": Rect2(panel.position + Vector2(panel.size.x - 52 * u, 8 * u), Vector2(44, 44) * u)}
		out.tab_slot = Rect2(panel.position + Vector2(12, 10) * u, Vector2(84, 40) * u)
		out.tab_tree = Rect2(panel.position + Vector2(100, 10) * u, Vector2(84, 40) * u)
		for i in 3:   # 左：キャラのタブ
			out["ch%d" % i] = Rect2(panel.position + Vector2(16, 70 + i * 150) * u, Vector2(120, 136) * u)
		var ids: Array = SkillTree.order(hud.tree_ch)
		var rows: Dictionary = SkillTree.rows(hud.tree_ch)
		var x0: float = panel.position.x + 160 * u
		for j in ids.size():   # 各行：アイコン・技レベルの丸5つ（押すと +1）・派生の枝
			var y: float = panel.position.y + (70 + j * 122) * u
			out["row_" + str(ids[j])] = Rect2(Vector2(x0, y), Vector2(900, 110) * u)
			out["lv_" + str(ids[j])] = Rect2(Vector2(x0 + 110 * u, y + 20 * u), Vector2(230, 70) * u)
			var ds: Array = rows[ids[j]].get("derivs", {}).keys()
			for k in ds.size():
				out["d_%s_%s" % [ids[j], ds[k]]] = Rect2(Vector2(x0 + (450 + k * 150) * u, y + 10 * u), Vector2(110, 90) * u)
		out.respec = Rect2(Vector2(panel.get_center().x - 70 * u, panel.end.y - 64 * u), Vector2(140, 52) * u)
		return out

	func _tree() -> void:
		var u := _u()
		var pr = hud.main.progress
		var ch: String = hud.tree_ch
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var r := tree_rects()
		draw_rect(r.panel, Color(0.04, 0.04, 0.09, 0.94))
		draw_rect(r.panel, Color(0.72, 0.5, 1.0, 0.8), false, 3 * u)
		_close_x(r.close)
		_mode_tabs(r)
		# 右上：残りの SP（金のひし形＋数字）
		var spc := Vector2(r.panel.end.x - 150 * u, r.panel.position.y + 32 * u)
		_diamond(spc, 14 * u, GOLD)
		_num(spc + Vector2(24, 13) * u, str(pr.sp_of(ch)), 34, GOLD)
		# 左：キャラのタブ（丸い顔の絵）。選んでいるタブは金の縁。右下に残り SP
		var faces := {"rana": Art.RANA, "lily": Art.LILY, "ranka": Art.RANKA}
		for i in SkillTree.CHARS.size():
			var rc: Rect2 = r["ch%d" % i]
			var cid: String = SkillTree.CHARS[i]
			var on: bool = cid == ch
			draw_rect(rc, Color(0.1, 0.12, 0.2, 0.95 if on else 0.55))
			draw_rect(rc, GOLD if on else Color(1, 1, 1, 0.25), false, (4 if on else 2) * u)
			var tex: Texture2D = faces[cid]
			var fr := Rect2(rc.get_center() - Vector2(46, 52) * u, Vector2(92, 92) * u)
			draw_texture_rect(tex, fr, false, Color(1, 1, 1, 1.0 if on else 0.55))
			if pr.sp_of(cid) > 0:
				_num(Vector2(rc.end.x - 30 * u, rc.end.y - 8 * u), str(pr.sp_of(cid)), 24, GOLD)
		var ids: Array = SkillTree.order(ch)
		var rows: Dictionary = SkillTree.rows(ch)
		for id in ids:
			var row: Rect2 = r["row_" + str(id)]
			var lv: int = pr.skill_level(ch, id)
			var ult: bool = id == "ult"
			draw_rect(row, Color(0.06, 0.07, 0.12, 0.8 if not ult else 0.95))
			if ult:   # 必殺技の行は一番下（金の細い縁）
				draw_rect(row, Color(GOLD, 0.5), false, 2 * u)
			# 技のアイコン（今のコードの図形）
			var ic := row.position + Vector2(55, 55) * u
			draw_circle(ic, 44 * u, Color(0.1, 0.12, 0.2, 1.0))
			draw_arc(ic, 44 * u, 0, TAU, 36, GOLD if ult else Color(1, 1, 1, 0.5), 2 * u)
			if Art.ICONS.has(id):
				Art.icon(self, Art.ICONS[id], ic, 70 * u, Color.WHITE)
			else:
				SkillIcons.draw2(self, str(id), ic, 44 * u, Color.WHITE, u)
			# 技レベルの丸5つ（埋まった数＝Lv）＋押すと +1 の印
			var lr: Rect2 = r["lv_" + str(id)]
			var can: bool = pr.can_level(ch, id)
			var fl: float = float(hud.tree_flash.get("lv_" + str(id), 0.0))
			var nofl: float = float(hud.tree_flash.get("no_" + str(id), 0.0))
			for k in SkillTree.MAX_LV:
				var pc := lr.position + Vector2(18 + k * 36, 35) * u
				if nofl > 0.0:
					pc.x += sin(nofl * 70.0) * 3 * u
				if k < lv:
					draw_circle(pc, 12 * u, GOLD.lerp(Color.WHITE, fl * 2.0) if k == lv - 1 else GOLD)
				else:
					draw_arc(pc, 12 * u, 0, TAU, 20, Color(1, 1, 1, 0.45), 2 * u)
				if k + 1 == SkillTree.DERIV_LV:   # 派生が開く Lv の印（小さな山形）
					draw_polyline(PackedVector2Array([pc + Vector2(-6, -20) * u, pc + Vector2(0, -26) * u, pc + Vector2(6, -20) * u]), Color(GOLD, 0.7), 2 * u)
			var plc := lr.position + Vector2(205, 35) * u
			draw_circle(plc, 18 * u, Color(GOLD, 0.9) if can else Color(1, 1, 1, 0.12))
			var pcol := Color(0.05, 0.04, 0.02) if can else Color(1, 1, 1, 0.35)
			draw_line(plc + Vector2(-9, 0) * u, plc + Vector2(9, 0) * u, pcol, 4 * u)
			draw_line(plc + Vector2(0, -9) * u, plc + Vector2(0, 9) * u, pcol, 4 * u)
			# 派生の枝：線を右へ引いて、ノード 2〜3 個（Lv3 未満は薄い）。選んだ派生は金の縁
			var open: bool = lv >= SkillTree.DERIV_LV
			var ds: Array = rows[id].get("derivs", {}).keys()
			var start := Vector2(lr.end.x + 12 * u, row.get_center().y)
			if ds.size() > 0:
				var first: Rect2 = r["d_%s_%s" % [id, ds[0]]]
				var lastr: Rect2 = r["d_%s_%s" % [id, ds[-1]]]
				var bx: float = first.position.x - 30 * u
				var lc := Color(GOLD, 0.6) if open else Color(1, 1, 1, 0.18)
				draw_line(start, Vector2(bx, start.y), lc, 3 * u)
				draw_line(Vector2(bx, start.y), Vector2(lastr.position.x, start.y), lc, 3 * u)
			for k in ds.size():
				var did: String = ds[k]
				var dr: Rect2 = r["d_%s_%s" % [id, did]]
				var dd: Dictionary = rows[id].derivs[did]
				var todo: bool = dd.get("todo", false)
				var sel: bool = pr.deriv_of(ch, id) == did
				var a := 1.0 if open and not todo else 0.3
				var key: String = "d_%s_%s" % [id, did]
				var dc := dr.get_center()
				if float(hud.tree_flash.get("no_" + key, 0.0)) > 0.0:
					dc.x += sin(float(hud.tree_flash["no_" + key]) * 70.0) * 3 * u
				var hex := PackedVector2Array()
				for q in 6:
					var ang := q * TAU / 6.0
					hex.append(dc + Vector2(cos(ang) * 52, sin(ang) * 44) * u)
				draw_colored_polygon(hex, Color(0.12, 0.1, 0.06, 0.95) if sel else Color(0.08, 0.09, 0.15, 0.9 * a + 0.1))
				hex.append(hex[0])
				var bc := GOLD if sel else Color(1, 1, 1, 0.5 * a)
				if float(hud.tree_flash.get(key, 0.0)) > 0.0:
					bc = Color.WHITE
				draw_polyline(hex, bc, (5 if sel else 2) * u)
				SkillIcons.glyph(self, String(dd.get("glyph", "")), dc, 40 * u, Color(GOLD if sel else Color.WHITE, a), u)
				_num(dr.position + Vector2(-2, 18) * u, str(k + 1), 18, Color(1, 1, 1, 0.55 * a))
		# 下：振り直し（全部の SP を戻す。確認は1回：1回目で赤く光り、3 秒以内にもう1回で実行）
		var rr: Rect2 = r.respec
		var arm: bool = hud.respec_arm > 0.0
		draw_rect(rr, Color(0.35, 0.05, 0.05, 0.9) if arm else Color(0.1, 0.12, 0.2, 0.9))
		draw_rect(rr, RED if arm else Color(1, 1, 1, 0.45), false, (3 if arm else 2) * u)
		var rc2 := rr.get_center()
		draw_arc(rc2 + Vector2(-20, 0) * u, 14 * u, -PI * 0.2, PI * 1.5, 18, Color.WHITE, 3 * u)
		draw_colored_polygon(PackedVector2Array([rc2 + Vector2(-20 + 14, -4) * u, rc2 + Vector2(-20 + 6, -14) * u, rc2 + Vector2(-20 + 22, -14) * u]), Color.WHITE)
		_diamond(rc2 + Vector2(20, 0) * u, 10 * u, GOLD)
		if arm:
			_num(rc2 + Vector2(36, 12) * u, "?", 30, RED)

	func _result() -> void:
		var u := _u()
		var res: Dictionary = hud.result
		var k := clampf(hud.result_t / 0.35, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6 * k))
		var w := 560.0 * u
		var h := 420.0 * u
		var p := (size - Vector2(w, h)) * 0.5
		var fail: bool = res.get("fail", false)
		var frame: Color = RED if fail else GOLD
		draw_rect(Rect2(p, Vector2(w, h)), Color(0.05, 0.04, 0.03, 0.94 * k))
		draw_rect(Rect2(p, Vector2(w, h)), Color(frame.r, frame.g, frame.b, k), false, 4 * u)
		# 上：決着の金の菱形（失敗は赤の割れた菱形）と、テーマの印・難易度の印
		var top := p + Vector2(w * 0.5, 54 * u)
		if fail:
			_diamond(top, 34 * u, RED, false)
			draw_line(top + Vector2(-10, -30) * u, top + Vector2(8, 30) * u, RED, 4 * u)
		else:
			_diamond(top, 34 * u, GOLD)
		var ti: int = Themes.index_of(str(res.get("theme", "t1")))
		_theme_glyph(ti, top + Vector2(-90 * u, 0), 40 * u, Themes.THEMES[ti].col)
		var di: int = maxi(0, Themes.DIFF_ORDER.find(str(res.diff)))
		for j in di + 1:
			_diamond(top + Vector2(80 * u + j * 30 * u, 6 * u), 16 * u, [BLUE, RED, RED][di])
		if fail:   # 失敗：時間と倒した数だけ（何も持ち帰らない）
			var fx0 := p.x + 110 * u
			var fx1 := p.x + 160 * u
			var frow := p.y + 170 * u
			_clock(Vector2(fx0, frow - 12 * u), 18 * u, Color.WHITE)
			_num(Vector2(fx1, frow), _time_str(float(res.time)), 44, Color.WHITE)
			frow += 84 * u
			_burst(Vector2(fx0, frow - 12 * u), 20 * u, GOLD)
			_num(Vector2(fx1, frow), str(res.get("kills", 0)), 44, Color.WHITE)
			_next_mark(p, w, h)
			return
		var x0 := p.x + 110 * u
		var x1 := p.x + 160 * u
		var row := p.y + 150 * u
		# 時間
		_clock(Vector2(x0, row - 12 * u), 18 * u, Color.WHITE)
		_num(Vector2(x1, row), _time_str(float(res.time)), 44, GOLD if res.best else Color.WHITE)
		if res.best:
			_diamond(Vector2(x1 + 260 * u, row - 14 * u), 12 * u, GOLD)
		# 被弾回数
		row += 74 * u
		_burst(Vector2(x0, row - 12 * u), 20 * u, RED)
		_num(Vector2(x1, row), str(res.hits), 44, Color.WHITE)
		# レベル・武器（前 → 後）
		row += 74 * u
		_chev(Vector2(x0, row - 14 * u), 14 * u, GOLD)
		_num(Vector2(x1, row), "%d  >  %d" % [res.lv0, res.lv], 36, GOLD if res.lv > res.lv0 else Color.WHITE)
		row += 64 * u
		_sword(Vector2(x0, row - 14 * u), 13 * u, Color.WHITE)
		_num(Vector2(x1, row), "%d  >  %d" % [res.w0, res.w], 36, GOLD if res.w > res.w0 else Color.WHITE)
		# 次の難易度が開いた（その難易度の菱形＋金の枠）
		if res.unlocked:
			var c := Vector2(p.x + w - 90 * u, p.y + h - 120 * u)
			var nd: int = Themes.DIFF_ORDER.find(str(res.get("unlocked_diff", "hard"))) + 1
			draw_rect(Rect2(c - Vector2(56, 34) * u, Vector2(112, 68) * u), GOLD, false, 3 * u)
			for j in nd:
				_diamond(c + Vector2((j - (nd - 1) * 0.5) * 30 * u, 0), 16 * u, RED)
		# 次のテーマが開いた（そのテーマの印＋金の枠）
		if res.get("theme_unlocked", false) and ti + 1 < Themes.THEMES.size():
			var c3 := Vector2(p.x + w - 90 * u, p.y + h - 200 * u)
			draw_rect(Rect2(c3 - Vector2(40, 34) * u, Vector2(80, 68) * u), GOLD, false, 3 * u)
			_theme_glyph(ti + 1, c3, 46 * u, Themes.THEMES[ti + 1].col)
		_next_mark(p, w, h)

	func _next_mark(p: Vector2, w: float, h: float) -> void:
		var u := _u()
		# 次へ（点滅する山形）
		if hud.result_t >= 1.2:
			var a := 0.5 + 0.5 * sin(hud.result_t * 6.0)
			var c2 := Vector2(p.x + w * 0.5, p.y + h - 26 * u)
			draw_polyline(PackedVector2Array([c2 + Vector2(-14, -8) * u, c2 + Vector2(0, 6) * u, c2 + Vector2(14, -8) * u]), Color(1, 1, 1, a), 4 * u)
