extends CanvasLayer
## ダンジョン選択・戦闘情報・結果・暗転、および街でのスキル育成。
## 遠征盤・戦闘は数字と絵、育成・技セットは日本語の説明を使用。
## 色：青＝味方・ノーマル、赤＝敵・ハード、金＝物資・決着。

var main
var menu_open := false
var slot_open := false     # スキルのスロット設定（街だけ）
var slot_pick := ""        # 一覧で選んだ技
const SkillIcons := preload("res://scripts/skill_icons.gd")
const CombatArt := preload("res://scripts/combat_hud_art.gd")
const SkillTree := preload("res://scripts/skill_tree.gd")
const TreeArt := preload("res://scripts/skill_tree_art.gd")
const SelectArt := preload("res://scripts/dungeon_select_art.gd")
const ShopUI := preload("res://scripts/shop_ui.gd")
const Eco := preload("res://scripts/economy.gd")
## お金と回復（2026-11-16 ②）：店（回復薬）と「立ち直る」の確認
var shop_open := false
var shop_t := 0.0
var shop_flash := {}
var revive_open := false
var revive_cost := 0
var revive_t := 0.0
var menu_feedback_pos := Vector2.ZERO
var menu_feedback_t := 0.0
var _covered_world: Node3D
var _covered_world_visible := true
var _covered_viewport: Viewport
var _viewport_3d_was_disabled := false
var _covered_controls: CanvasLayer
var _controls_were_visible := true
var _controls_pad: Node
var _pad_was_processing_input := true
var _covered_postprocess: CanvasItem
var _postprocess_was_visible := true
const Art := preload("res://scripts/t6_hud_art.gd")
## スキル育成（specs/skill_tree.md）：街の歯車から。技セットと切り替え。
var slot_mode := "tree"    # "slot"＝スロット設定、"tree"＝スキルツリー
var tree_ch := "rana"      # 選んでいるキャラのタブ
var tree_skill := "flurry"  # 説明を表示する技（選択ではSPを使わない）
var tree_deriv := ""        # 効果を確認する派生候補
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
	shop_t += delta
	revive_t += delta
	for k in shop_flash.keys():
		shop_flash[k] = maxf(0.0, float(shop_flash[k]) - delta)
	if result_t >= 0.0:
		result_t += delta
	fade_t = maxf(0.0, fade_t - delta)
	warn_t = maxf(0.0, warn_t - delta)
	respec_arm = maxf(0.0, respec_arm - delta)
	for k in tree_flash.keys():
		tree_flash[k] = float(tree_flash[k]) - delta
		if tree_flash[k] <= 0.0:
			tree_flash.erase(k)
	lv_flash = maxf(0.0, lv_flash - delta)
	w_flash = maxf(0.0, w_flash - delta)
	shake_hard = maxf(0.0, shake_hard - delta)
	view.queue_redraw()

## 増援の予告：進む先の画面の端に赤い山形（敵＝赤）。dir＝+1 右・-1 左（2026-11-15 ユーザー）
var warn_t := 0.0
var warn_dir := 1
func edge_warn(dir: int, d: float) -> void:
	warn_dir = dir
	warn_t = d

## The map is opaque. Skip hidden 3D drawing, restore the exact previous visibility.
func _sync_menu_world() -> void:
	var covered: bool = menu_open or slot_open or (main != null and "loading" in main and is_instance_valid(main.loading) and main.loading.visible)
	if covered and not is_instance_valid(_covered_viewport):
		_covered_viewport = get_viewport()
		_viewport_3d_was_disabled = _covered_viewport.disable_3d
		_covered_viewport.disable_3d = true
	elif not covered and is_instance_valid(_covered_viewport):
		_release_viewport()
	var controls: CanvasLayer = main.ui if covered and main != null and "ui" in main else null
	if is_instance_valid(_covered_controls) and _covered_controls != controls:
		_release_controls()
	if controls != null and controls != _covered_controls:
		_covered_controls = controls
		_controls_were_visible = controls.visible
		_controls_pad = controls.get("pad") if "pad" in controls else null
		if is_instance_valid(_controls_pad):
			_pad_was_processing_input = _controls_pad.is_processing_input()
		if controls.has_method("set_controls_enabled"):
			controls.set_controls_enabled(false)
		else:
			controls.visible = false
	if covered and not is_instance_valid(_covered_postprocess) and main != null and "vignette_mat" in main and main.vignette_mat != null:
		for layer_node in main.get_children():
			if layer_node is CanvasLayer:
				for item in layer_node.get_children():
					if item is CanvasItem and item.material == main.vignette_mat:
						_covered_postprocess = item
						_postprocess_was_visible = item.visible
						item.visible = false
	elif not covered:
		_release_postprocess()
	var wanted: Node3D = main.level if covered and main != null and "level" in main else null
	if is_instance_valid(_covered_world) and _covered_world != wanted:
		_covered_world.visible = _covered_world_visible
		_covered_world = null
	if wanted != null and wanted != _covered_world:
		_covered_world = wanted
		_covered_world_visible = wanted.visible
		wanted.visible = false

func _release_postprocess() -> void:
	if is_instance_valid(_covered_postprocess):
		_covered_postprocess.visible = _postprocess_was_visible
	_covered_postprocess = null

func _release_controls() -> void:
	if is_instance_valid(_covered_controls):
		_covered_controls.visible = _controls_were_visible
	if is_instance_valid(_controls_pad):
		_controls_pad.set_process_input(_pad_was_processing_input)
	_covered_controls = null
	_controls_pad = null

func _release_viewport() -> void:
	if is_instance_valid(_covered_viewport):
		_covered_viewport.disable_3d = _viewport_3d_was_disabled
	_covered_viewport = null

func _exit_tree() -> void:
	_release_postprocess()
	_release_controls()
	_release_viewport()
	if is_instance_valid(_covered_world):
		_covered_world.visible = _covered_world_visible

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
	if main.dungeon != null:
		return
	var r: Dictionary = view.tree_rects()
	if r.close.has_point(pos) or not r.panel.has_point(pos):
		close_slots()
		return
	if r.tab_slot.has_point(pos):
		slot_mode = "slot"
		respec_arm = 0.0
		return
	var pr = main.progress
	for i in SkillTree.CHARS.size():
		if r["ch%d" % i].has_point(pos):
			tree_ch = SkillTree.CHARS[i]
			tree_skill = SkillTree.order(tree_ch)[0]
			tree_deriv = pr.deriv_of(tree_ch, tree_skill)
			respec_arm = 0.0
			return
	if r.respec.has_point(pos):
		if TreeArt.Info.refund(pr, tree_ch) <= 0:
			return
		if respec_arm > 0.0:
			pr.respec(tree_ch)
			respec_arm = 0.0
			tree_deriv = ""
			tree_flash["respec"] = 0.4
		else:
			respec_arm = 3.0
		return
	respec_arm = 0.0
	if r.upgrade.has_point(pos):
		if pr.level_up(tree_ch, tree_skill):
			tree_flash["lv_" + tree_skill] = 0.35
		else:
			tree_flash["no_" + tree_skill] = 0.3
		return
	if r.apply_deriv.has_point(pos):
		if pr.set_deriv(tree_ch, tree_skill, tree_deriv):
			tree_flash["deriv"] = 0.35
		return
	var rows: Dictionary = SkillTree.rows(tree_ch)
	for id in SkillTree.order(tree_ch):
		for did in rows[id].get("derivs", {}):
			var k: String = "d_%s_%s" % [id, did]
			if r.has(k) and r[k].has_point(pos):
				tree_skill = id
				tree_deriv = did
				return
		if r["row_" + id].has_point(pos):
			tree_skill = id
			tree_deriv = pr.deriv_of(tree_ch, id)
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

# ---------- 店・立ち直る（2026-11-16 ②） ----------
func open_shop() -> void:
	if shop_open:
		return
	shop_open = true
	shop_t = 0.0
	if main.player:
		main.player.locked = true
		main.player.move_in = Vector2.ZERO

func close_shop() -> void:
	shop_open = false
	if main.player:
		main.player.locked = false
	if main.progress:
		main.progress.save()

func shop_items() -> Array:
	var pr = main.progress
	return [{"heal": Eco.POT_S_HEAL, "price": Eco.POT_S_PRICE, "have": pr.pot_s, "max": Eco.POT_S_MAX},
		{"heal": Eco.POT_L_HEAL, "price": Eco.POT_L_PRICE, "have": pr.pot_l, "max": Eco.POT_L_MAX}]

func buy(i: int) -> bool:
	var pr = main.progress
	var it: Dictionary = shop_items()[i]
	if pr.gold < int(it.price) or int(it.have) >= int(it.max):
		return false
	pr.gold -= int(it.price)
	if i == 0:
		pr.pot_s += 1
	else:
		pr.pot_l += 1
	shop_flash["buy%d" % i] = 0.15
	return true

func show_revive(cost: int, _gold: int) -> void:
	revive_open = true
	revive_cost = cost
	revive_t = 0.0

func _revive_pick(yes: bool) -> void:
	if revive_t < 0.4 or main.dungeon == null:
		return
	if yes and main.progress.gold < revive_cost:
		return
	revive_open = false
	if yes:
		main.dungeon.revive_yes()
	else:
		main.dungeon.revive_no()

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
	if shop_open or revive_open:
		var k2 := -1
		if e is InputEventKey and e.pressed and not e.echo:
			k2 = e.keycode
		var tp := Vector2(-1, -1)
		if e is InputEventScreenTouch and e.pressed:
			tp = e.position
		if k2 < 0 and tp.x < 0:
			return
		get_viewport().set_input_as_handled()
		if revive_open:
			var rr: Dictionary = ShopUI.revive_rects(view.size)
			if k2 == KEY_J or k2 == KEY_ENTER or (tp.x >= 0 and rr.yes.has_point(tp)):
				_revive_pick(true)
			elif k2 == KEY_K or k2 == KEY_ESCAPE or (tp.x >= 0 and rr.no.has_point(tp)):
				_revive_pick(false)
			return
		if shop_t < 0.2:
			return
		var sr: Dictionary = ShopUI.shop_rects(view.size)
		if k2 == KEY_1 or (tp.x >= 0 and sr.buy0.has_point(tp)):
			buy(0)
		elif k2 == KEY_2 or (tp.x >= 0 and sr.buy1.has_point(tp)):
			buy(1)
		elif k2 == KEY_K or k2 == KEY_ESCAPE or k2 == KEY_X or (tp.x >= 0 and (sr.close.has_point(tp) or not sr.panel.has_point(tp))):
			close_shop()
		return
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
			respec_arm = 0.0
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
			if menu_stage == "theme" and (r["node%d" % i].has_point(tap) or r["badge%d" % i].has_point(tap)):
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
		if hud.menu_open:
			_menu()
			return
		var d = m.dungeon
		if hud.in_dungeon and d != null and not d.layout.is_empty():
			_map(d)
			_num(Vector2(0, 52 * u), _time_str(d.t_run), 34, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_CENTER, size.x)
			# お金（2026-11-16 ②）：時間の右に、金の硬貨＋数
			ShopUI.coin(self, Vector2(size.x * 0.5 + 118 * u, 40 * u), 12 * u)
			_num(Vector2(size.x * 0.5 + 136 * u, 52 * u), str(m.progress.gold), 30, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 200 * u)
			if d.boss != null and is_instance_valid(d.boss):
				var brc: Rect2 = CombatArt.boss_rect(size)
				CombatArt.boss(self,brc,maxf(0.0,d.boss.hp/d.boss.hp_max))
				# ブレイクの帯（金＝決着）：Codex の真鍮の帯の下。傷がたまると満ち、満ちると倒れる。倒れている間は点滅しながら減る（2026-11-15）
				if d.boss.has_method("break_ratio"):
					var br: float = d.boss.break_ratio()
					var bw: float = brc.size.x - 24 * u
					var bp := Vector2(brc.position.x + 12 * u, brc.end.y + 4 * u)
					var brk_on: bool = d.boss.state == "broken"
					draw_rect(Rect2(bp - Vector2(3, 3) * u, Vector2(bw, 8 * u) + Vector2(6, 6) * u), DIM)
					var ga: float = 1.0 if not brk_on else 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
					draw_rect(Rect2(bp, Vector2(bw * br, 8 * u)), Color(GOLD.r, GOLD.g, GOLD.b, ga))
		if hud.in_dungeon and m.battle and m.battle.get("style") != null and not OS.has_environment("COMBO_OFF"):   # コンボとランク（ミニマップの下・必殺技のボタンの左。specs/combat_tactics.md 5.）
			m.battle.style.draw(self, size.x - 185 * u, 178 * u, u)
		if hud.menu_open:
			_menu()
		if hud.slot_open:
			if hud.slot_mode == "tree":
				_tree()
			else:
				_slots()
		if hud.result_t >= 0.0:
			_result()
		if hud.shop_open:
			ShopUI.draw_shop(self, size, int(m.progress.gold), hud.shop_items(), hud.shop_flash)
		if hud.revive_open:
			ShopUI.draw_revive(self, size, hud.revive_cost, int(m.progress.gold), hud.revive_t)
		if hud.warn_t > 0.0 and m.dungeon != null:   # 増援の予告：画面の端に赤い山形が3つ、外へ向かって点滅
			var a: float = clampf(hud.warn_t / 0.3, 0.0, 1.0) * (0.55 + 0.45 * sin(hud.warn_t * 14.0))
			var ex: float = size.x - 46 * u if hud.warn_dir > 0 else 46 * u
			var cy := size.y * 0.52
			draw_rect(Rect2(Vector2(size.x - 14 * u if hud.warn_dir > 0 else 0.0, 0), Vector2(14 * u, size.y)), Color(RED.r, RED.g, RED.b, 0.35 * a))
			for k in 3:
				var cx: float = ex - hud.warn_dir * k * 24 * u
				var s_: float = 20 * u
				draw_polyline(PackedVector2Array([Vector2(cx - hud.warn_dir * s_ * 0.6, cy - s_), Vector2(cx + hud.warn_dir * s_ * 0.6, cy), Vector2(cx - hud.warn_dir * s_ * 0.6, cy + s_)]), Color(RED.r, RED.g, RED.b, a * (1.0 - k * 0.25)), 7 * u)
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
		return TreeArt.slot_rects(size, hud.main.progress.skills_owned)

	func _slots() -> void:
		TreeArt.slots(self, hud)

	func _close_x(rc: Rect2) -> void:
		var u := _u()
		var cc: Vector2 = rc.get_center()
		draw_line(cc + Vector2(-12, -12) * u, cc + Vector2(12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)
		draw_line(cc + Vector2(12, -12) * u, cc + Vector2(-12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)

	## スキル育成：描画とタッチ矩形を同じモジュールで管理。
	func tree_rects() -> Dictionary:
		return TreeArt.rects(size, hud.tree_ch)

	func _tree() -> void:
		TreeArt.draw(self, hud)

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
		# 得たお金（2026-11-16 ②。ボス部屋に残った硬貨はこのあと拾える）
		if res.has("gold"):
			var gg: int = int(res.gold)
			_num(Vector2(x1 + 260 * u, row), ("+%d" % gg) if gg >= 0 else str(gg), 36, GOLD if gg >= 0 else Color(0.8, 0.8, 0.85))
			ShopUI.coin(self, Vector2(x1 + 242 * u, row - 12 * u), 11 * u)
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
