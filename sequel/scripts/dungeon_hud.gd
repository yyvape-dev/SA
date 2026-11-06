extends CanvasLayer
## ダンジョンまわりの画面：レベル・経験値・武器（いつも）、右上の小さな地図・時間・ボスの体力（ダンジョンの中）、
## 難易度を選ぶ画面、結果の画面、暗転。文字は使わず、数字と色と記号だけ。
## 色：青＝味方・ノーマル、赤＝敵・ハード、金＝物資・決着。

var main
var menu_open := false
var menu_sel := 0          # 0＝ノーマル 1＝ハード
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
	menu_t += delta
	if result_t >= 0.0:
		result_t += delta
	fade_t = maxf(0.0, fade_t - delta)
	lv_flash = maxf(0.0, lv_flash - delta)
	w_flash = maxf(0.0, w_flash - delta)
	shake_hard = maxf(0.0, shake_hard - delta)
	view.queue_redraw()

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
	menu_sel = 0
	main.player.locked = true
	main.battle.process_mode = Node.PROCESS_MODE_DISABLED

func close_menu() -> void:
	menu_open = false
	main.player.locked = false
	main.battle.process_mode = Node.PROCESS_MODE_INHERIT

## 0＝ノーマル 1＝ハード。ハードはノーマルのクリアで開く
func choose(i: int) -> bool:
	if i == 1 and not main.progress.hard_open:
		shake_hard = 0.4
		return false
	close_menu()
	fade(0.6)
	main.enter_dungeon("hard" if i == 1 else "normal", main.dungeon_seed())
	return true

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
	if menu_t < 0.25:
		return
	match key:
		KEY_1, KEY_A, KEY_LEFT: menu_sel = 0
		KEY_2, KEY_D, KEY_RIGHT: menu_sel = 1
		KEY_J, KEY_Z, KEY_ENTER, KEY_SPACE: choose(menu_sel)
		KEY_ESCAPE, KEY_K, KEY_X: close_menu()
	if tap.x >= 0:
		var r: Dictionary = view.menu_rects()
		if r.normal.has_point(tap):
			choose(0)
		elif r.hard.has_point(tap):
			choose(1)
		elif r.close.has_point(tap) or not r.panel.has_point(tap):
			close_menu()

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
		var y := 78.0 * u
		var lvc := GOLD.lerp(Color.WHITE, hud.lv_flash) if hud.lv_flash > 0.0 else GOLD
		_chev(Vector2(48 * u, y - 10 * u), 11 * u, lvc)
		_num(Vector2(66 * u, y), str(pr.lv), 30, lvc)
		var bx := 112.0 * u
		draw_rect(Rect2(Vector2(bx, y - 16 * u), Vector2(150 * u, 8 * u)), DIM)
		draw_rect(Rect2(Vector2(bx, y - 16 * u), Vector2(150 * u * float(pr.xp) / float(pr.need()), 8 * u)), GOLD)
		var wc := GOLD if hud.w_flash > 0.0 and int(hud.w_flash * 8) % 2 == 0 else Color(0.9, 0.92, 1.0)
		_sword(Vector2(296 * u, y - 10 * u), 10 * u, wc)
		_num(Vector2(316 * u, y), str(pr.weapon), 30, wc)
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
		if hud.result_t >= 0.0:
			_result()
		if hud.fade_t > 0.0 and hud.fade_d > 0.0:
			var k: float = 1.0 - hud.fade_t / hud.fade_d
			var a: float = 1.0 - absf(2.0 * k - 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.03, clampf(a * 1.4, 0.0, 1.0)))

	## 右上の小さな地図：今いる部屋（明るい青）・行った部屋（暗い青）・となりの知らない部屋（枠だけ）・ボス部屋（赤。最初から表示）
	func _map(d) -> void:
		var u := _u()
		var cs := 26.0 * u
		var gap := 12.0 * u
		var n := 3
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
				draw_line(ctr.call(c), ctr.call(nb), Color(0.55, 0.7, 1.0, 0.8), 4 * u)
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

	func menu_rects() -> Dictionary:
		var u := _u()
		var cw := 300.0 * u
		var ch := 230.0 * u
		var gap := 40.0 * u
		var c := size * 0.5
		var panel := Rect2(c - Vector2(cw + gap * 0.5 + 30 * u, ch * 0.5 + 40 * u), Vector2(cw * 2 + gap + 60 * u, ch + 80 * u))
		return {
			"panel": panel,
			"normal": Rect2(c + Vector2(-cw - gap * 0.5, -ch * 0.5), Vector2(cw, ch)),
			"hard": Rect2(c + Vector2(gap * 0.5, -ch * 0.5), Vector2(cw, ch)),
			"close": Rect2(panel.position + Vector2(panel.size.x - 52 * u, 8 * u), Vector2(44, 44) * u),
		}

	func _menu() -> void:
		var u := _u()
		var pr = hud.main.progress
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		var r := menu_rects()
		draw_rect(r.panel, Color(0.04, 0.04, 0.09, 0.92))
		draw_rect(r.panel, Color(0.72, 0.5, 1.0, 0.8), false, 3 * u)
		# 閉じる（×）
		var cc: Vector2 = r.close.get_center()
		draw_line(cc + Vector2(-12, -12) * u, cc + Vector2(12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)
		draw_line(cc + Vector2(12, -12) * u, cc + Vector2(-12, 12) * u, Color(1, 1, 1, 0.8), 4 * u)
		for i in 2:
			var rect: Rect2 = r.normal if i == 0 else r.hard
			var col := BLUE if i == 0 else RED
			var locked: bool = i == 1 and not pr.hard_open
			if i == 1 and hud.shake_hard > 0.0:
				rect.position.x += sin(hud.shake_hard * 60.0) * 8 * u
			var sel: bool = hud.menu_sel == i
			draw_rect(rect, Color(col.r * 0.18, col.g * 0.18, col.b * 0.18, 0.95))
			draw_rect(rect, col if not locked else Color(0.4, 0.4, 0.45), false, (6 if sel else 3) * u)
			var c := rect.get_center() + Vector2(0, -28 * u)
			var nd := 1 if i == 0 else 2
			for k in nd:
				var off := (k - (nd - 1) * 0.5) * 70 * u
				_diamond(c + Vector2(off, 0), 44 * u, col if not locked else Color(0.3, 0.3, 0.34))
			if locked:
				_lock(c + Vector2(0, 6 * u), 26 * u, Color(0.85, 0.85, 0.9))
			# 最速の記録（金の時計＋数字）
			var key := "normal" if i == 0 else "hard"
			if pr.best.has(key):
				_clock(Vector2(rect.position.x + 70 * u, rect.end.y - 42 * u), 13 * u, GOLD)
				_num(Vector2(rect.position.x + 92 * u, rect.end.y - 30 * u), _time_str(float(pr.best[key])), 32, GOLD)

	func _result() -> void:
		var u := _u()
		var res: Dictionary = hud.result
		var k := clampf(hud.result_t / 0.35, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6 * k))
		var w := 560.0 * u
		var h := 420.0 * u
		var p := (size - Vector2(w, h)) * 0.5
		draw_rect(Rect2(p, Vector2(w, h)), Color(0.05, 0.04, 0.03, 0.94 * k))
		draw_rect(Rect2(p, Vector2(w, h)), Color(GOLD.r, GOLD.g, GOLD.b, k), false, 4 * u)
		# 上：決着の金の菱形と、難易度の印
		var top := p + Vector2(w * 0.5, 54 * u)
		_diamond(top, 34 * u, GOLD)
		var hard: bool = res.diff == "hard"
		for j in (2 if hard else 1):
			_diamond(top + Vector2(80 * u + j * 30 * u, 6 * u), 16 * u, RED if hard else BLUE)
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
		# ハードが開いた（赤の菱形2つ＋開いた錠の代わりに金の枠）
		if res.unlocked:
			var c := Vector2(p.x + w - 90 * u, p.y + h - 120 * u)
			draw_rect(Rect2(c - Vector2(50, 34) * u, Vector2(100, 68) * u), GOLD, false, 3 * u)
			_diamond(c + Vector2(-18 * u, 0), 18 * u, RED)
			_diamond(c + Vector2(18 * u, 0), 18 * u, RED)
		# 次へ（点滅する山形）
		if hud.result_t >= 1.2:
			var a := 0.5 + 0.5 * sin(hud.result_t * 6.0)
			var c2 := Vector2(p.x + w * 0.5, p.y + h - 26 * u)
			draw_polyline(PackedVector2Array([c2 + Vector2(-14, -8) * u, c2 + Vector2(0, 6) * u, c2 + Vector2(14, -8) * u]), Color(1, 1, 1, a), 4 * u)
