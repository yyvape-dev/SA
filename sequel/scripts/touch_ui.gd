extends CanvasLayer
## 横持ちのタッチ操作。左半分＝触った所に出るスティック（倒しきると走る）。右下＝攻撃（大）・回避。
## 文字は使わない（日本語フォントを入れるまでは図形のアイコン）。

const Art := preload("res://scripts/t6_hud_art.gd")
const CombatArt := preload("res://scripts/combat_hud_art.gd")
var main          # main.gd（スキルの枠・街かどうか）
var player # Rana or the manual Lily input controller
var battle: Node3D
var pad: Control
var hud: Control
var basic_combat_only := false
var lily_controls := false
# Optional contextual replacement for the attack slot. Other scenes keep normal attacks.
var attack_context_available: Callable
var attack_context_action: Callable
var attack_context_font: Font

func attack_is_contextual() -> bool:
	return attack_context_available.is_valid() and attack_context_action.is_valid() and attack_context_available.call()

func draw_attack_context(canvas: CanvasItem, center: Vector2, radius: float, pressed: bool) -> void:
	Art.button(canvas, center, radius, pressed, false, true)
	var font: Font = attack_context_font if attack_context_font != null else ThemeDB.fallback_font
	var font_size := int(24 * radius / 78.0)
	canvas.draw_string(font, center + Vector2(-radius, font_size * 0.35), "話す", HORIZONTAL_ALIGNMENT_CENTER, radius * 2, font_size, Color(1, 1, 1, 0.9))


func ult_value() -> float:
	if lily_controls and player != null and player.has_method("ult_value"):
		return player.ult_value()   # 手動の仲間（リリィ ally_ult・ランカ ranka_ult）
	return battle.ally_ult if lily_controls else battle.ult

func _ready() -> void:
	pad = _Pad.new()
	pad.ui = self
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(pad)
	hud = _Hud.new()
	hud.ui = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

func set_controls_enabled(enabled: bool) -> void:
	if not enabled:
		pad.reset_input()
	pad.set_process_input(enabled)
	visible = enabled

## 左上：キャラクターの体力（青＝味方）。減った分は少し遅れて追いかける白い帯
class _Hud extends Control:
	var ui
	var shown := 1.0
	func _process(delta: float) -> void:
		var hp: Vector2 = CombatArt.health(ui)
		var r: float = clampf(hp.x / maxf(1.0,hp.y),0,1)
		shown = maxf(r, shown - delta * 0.6) if shown > r else r
		queue_redraw()
	func _draw() -> void:
		CombatArt.gauges(self, ui, size.y / 720.0, shown)

class _Pad extends Control:
	## 右下（specs/skill_ui.md）：攻撃・回避・スキル3枠（攻撃の中心から半径 175u の弧、165°・115°・65°）。4枠目 215° は空けておく。
	## 街にいる時だけ、回避の左下に歯車（スロット設定）
	var ui
	var stick_id := -1
	var stick_c := Vector2.ZERO
	var stick_p := Vector2.ZERO
	var btn_down := {}
	var shake := {}     # ボタン -> 揺れの残り（CD 中に押した）
	const R := 90.0
	const SKILL_ANG := [165.0, 115.0, 65.0]

	func _btns() -> Dictionary:
		var s := size
		var u := s.y / 720.0
		var ac := Vector2(s.x - 175 * u, s.y - 175 * u)
		var b := {
			"atk": [ac, 78 * u],
			"dodge": [Vector2(s.x - 345 * u, s.y - 80 * u), 50 * u],
		}
		if ui.basic_combat_only:
			return b
		for i in 3:
			var a := deg_to_rad(SKILL_ANG[i])
			b["sk%d" % i] = [ac + Vector2(cos(a), -sin(a)) * 175 * u, 52 * u]
		# 回復薬（2026-11-16 ②）：攻撃ボタンの右上（スキルの弧と画面の右端の間）。右の親指から一番近い空き。
		#   前は左上に置いたが、ユーザー「頻繁に触る物を一番押しづらい場所にするのはどうなん」→ 移した
		if not ui.lily_controls and ui.main and ui.main.dungeon != null:
			b["pot"] = [Vector2(s.x - 48 * u, s.y - 246 * u), 40 * u]
			# 仲間を呼ぶ（2026-11-16）：回復薬の下に縦に並べる（右の親指の列）。連れている仲間だけ
			var bt = ui.main.battle
			var cy := s.y - 150 * u
			for who in ["lily", "ranka"]:
				var a2 = bt.ally if who == "lily" else bt.ranka
				if a2 != null and is_instance_valid(a2):
					b["call_" + who] = [Vector2(s.x - 48 * u, cy), 41 * u]
					cy += 96 * u
		# 4 枠目（2026-11-16、回り込み）：回避の左。弧の 215° は回避と重なるので使わない。街で歯車が出る時は出さない
		var town_gear: bool = not ui.lily_controls and ui.main and ui.main.hud and ui.main.hud.visible and ui.main.dungeon == null and not ui.main.hud.menu_open and not ui.main.hud.slot_open
		if not ui.lily_controls and not town_gear and ui.main and ui.main.progress and ui.main.progress.has_method("battle_slots"):
			b["sk3"] = [Vector2(s.x - 460 * u, s.y - 90 * u), 48 * u]
		b["ult"] = [Vector2(s.x - 100 * u, 210 * u), 62 * u]
		if not ui.lily_controls and ui.main and ui.main.hud and ui.main.hud.visible and ui.main.dungeon == null and not ui.main.hud.menu_open and not ui.main.hud.slot_open:
			b["gear"] = [Vector2(s.x - 420 * u, s.y - 52 * u), 30 * u]
		return b

	func _process(delta: float) -> void:
		for k in shake.keys():
			shake[k] = float(shake[k]) - delta
			if shake[k] <= 0.0:
				shake.erase(k)
		queue_redraw()

	func _slot_id(i: int) -> String:
		if ui.lily_controls:
			if ui.player != null and ui.player.actor != null:
				return str(ui.player.actor.slot_ids()[i])
			return ["rush", "barrage", "storm"][i]
		if ui.main and ui.main.progress:
			if i >= 3 and ui.main.progress.has_method("battle_slots"):
				return str(ui.main.progress.battle_slots()[i])
			return str(ui.main.progress.skill_slots[i])
		return ""

	func _press(k: String) -> void:
		var pl = ui.player
		match k:
			"atk":
				if ui.attack_is_contextual():
					# No attack press/release ownership is created for a Talk touch.
					btn_down.erase("atk")
					ui.attack_context_action.call()
				else:
					pl.attack_press()
			"dodge": pl.dodge()
			"gear": ui.main.hud.open_slots()
			"ult": pl.use_ult()
			"pot":
				if not pl.use_potion():
					shake[k] = 0.25
			"call_lily", "call_ranka":
				var bt = ui.main.battle
				var a2 = bt.ally if k == "call_lily" else bt.ranka
				if a2 == null or not a2.call_tactic("flank" if k == "call_lily" else "lure"):
					shake[k] = 0.25
			_:
				var id := _slot_id(int(k.substr(2)))
				if not pl.use_skill(id) and float(pl.skill_cd.get(id, 0.0)) > 0.0:
					shake[k] = 0.25

	func _input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		var idx := 0
		var pressed := false
		if e is InputEventScreenTouch:
			pos = e.position; idx = e.index; pressed = e.pressed
		elif e is InputEventScreenDrag:
			if e.index == stick_id:
				stick_p = e.position
				_apply()
				queue_redraw()
			return
		else:
			return
		if pressed:
			# 判定は半径×1.15。重なったら近い方
			var b := _btns()
			var best := ""
			var bd := INF
			for k in b:
				var d: float = pos.distance_to(b[k][0])
				if d < b[k][1] * 1.15 and d / b[k][1] < bd:
					bd = d / b[k][1]
					best = k
			if best != "":
				if btn_down.has(best):
					return
				btn_down[best] = idx
				_press(best)
				queue_redraw()
				return
			if pos.x < size.x * 0.5 and stick_id < 0:
				stick_id = idx
				stick_c = pos
				stick_p = pos
				_apply()
		else:
			if idx == stick_id:
				stick_id = -1
				ui.player.move_in = Vector2.ZERO
			for k in btn_down.keys():
				if btn_down[k] == idx:
					btn_down.erase(k)
					if k == "atk":
						ui.player.attack_release()
		queue_redraw()

	func reset_input() -> void:
		if btn_down.has("atk"):
			ui.player.attack_release()
		ui.player.move_in = Vector2.ZERO
		stick_id = -1
		btn_down.clear()
		shake.clear()

	func _apply() -> void:
		var u := size.y / 720.0
		var v := (stick_p - stick_c) / (R * u)
		if v.length() > 1.0: v = v.normalized()
		ui.player.move_in = v

	## 攻撃ボタンの上乗せ（2026-11-16、specs/combat_tactics.md 11.）：状況で変わる時は金に光る輪と印（↑↑浮き・↶背中・✦反撃）、
	##   長押しの間は溜まっていく金の弧（満ちると回転斬り→締めで浮かせる）
	func _draw_atk_extra(c: Vector2, r: float, u: float) -> void:
		var pl = ui.player
		if pl == null or not pl.has_method("context_move"):
			return
		var ctx: String = pl.context_move()
		var gold := Color(1.0, 0.8, 0.3)
		if ctx != "":
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
			draw_arc(c, r * 1.08, 0, TAU, 56, Color(gold.r, gold.g, gold.b, 0.9 * pulse), 7 * u)
			draw_arc(c, r * 1.2, 0, TAU, 56, Color(gold.r, gold.g, gold.b, 0.35 * pulse), 4 * u)
			var m := c + Vector2(r * 0.62, -r * 0.62)   # 右上の小さな印
			draw_circle(m, r * 0.3, Color(0.08, 0.06, 0.03, 0.9))
			draw_arc(m, r * 0.3, 0, TAU, 24, gold, 3 * u)
			var k := r * 0.14
			match ctx:
				"ctx_air":   # 上向きの山形 2 つ
					for j in 2:
						var y0 := m.y + k * 0.9 - j * k * 1.1
						draw_polyline(PackedVector2Array([Vector2(m.x - k, y0), Vector2(m.x, y0 - k), Vector2(m.x + k, y0)]), gold, 3.5 * u)
				"ctx_back":   # 回り込む弧＋矢
					draw_arc(m, k * 1.1, PI * 0.2, PI * 1.6, 16, gold, 3.5 * u)
					var tip := m + Vector2(cos(PI * 1.6), sin(PI * 1.6)) * k * 1.1
					draw_polyline(PackedVector2Array([tip + Vector2(-k * 0.7, -k * 0.1), tip, tip + Vector2(-k * 0.1, k * 0.7)]), gold, 3.5 * u)
				"ctx_counter":   # 四方の光
					for j in 4:
						var a := j * PI * 0.5 + PI * 0.25
						draw_line(m + Vector2(cos(a), sin(a)) * k * 0.3, m + Vector2(cos(a), sin(a)) * k * 1.3, gold, 3.5 * u)
		if pl.atk_held and not pl.hold_fired and pl.held_t > 0.08:
			var f: float = clampf(pl.held_t / pl.HOLD_T, 0.0, 1.0)
			draw_arc(c, r * 0.92, -PI * 0.5, -PI * 0.5 + TAU * f, 48, Color(gold.r, gold.g, gold.b, 0.95), 6 * u)

	## 仲間を呼ぶボタン：仲間の顔＋待ちの扇。押せる時は青の縁（青＝味方）
	func _draw_call(key: String, c: Vector2, r: float, pressed: bool, u: float) -> void:
		var bt = ui.main.battle
		var who := key.substr(5)
		var a2 = bt.ally if who == "lily" else bt.ranka
		if a2 == null:
			return
		var id := "flank" if who == "lily" else "lure"
		var cd: float = float(a2.sk_cd.get(id, 0.0))
		var ok: bool = cd <= 0.0 and (a2.state == "move" or a2.state == "atk")
		var tex: Texture2D = CombatArt.Old.LILY if who == "lily" else CombatArt.Old.RANKA
		CombatArt.portrait(self, tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), not ok)
		if pressed:
			draw_circle(c, r * 0.9, Color(1, 1, 1, 0.15))
		if cd > 0.0:
			var full: float = float(a2.sk_tab.get(id, {}).get("cd", 8.0))
			draw_arc(c, r * 0.8, -PI * 0.5, -PI * 0.5 + TAU * clampf(cd / full, 0.0, 1.0), 40, Color(0, 0, 0, 0.6), r * 0.3)
			var font := ThemeDB.fallback_font
			draw_string_outline(font, c + Vector2(-r, r * 0.25), "%.0f" % ceilf(cd), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(24 * u), int(6 * u), Color(0, 0, 0, 0.9))
			draw_string(font, c + Vector2(-r, r * 0.25), "%.0f" % ceilf(cd), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(24 * u), Color(1, 1, 1))
		else:
			draw_arc(c, r * 1.02, 0, TAU, 40, Color(0.24, 0.55, 1.0, 0.95), 4 * u)

	## 回復薬のボタン（2026-11-16 ②）：淡い緑の小瓶。右下に持っている数（小、大があれば「小+大」）、使えない間は暗く＋残りの扇
	func _draw_pot(c: Vector2, r: float, pressed: bool, u: float) -> void:
		var pr = ui.main.progress
		var pl = ui.player
		var n_s: int = int(pr.pot_s)
		var n_l: int = int(pr.pot_l)
		var empty: bool = n_s + n_l <= 0
		Art.button(self, c, r, pressed)
		var a: float = 0.35 if empty or float(pl.pot_cd) > 0.0 else 1.0
		var liq := Color(0.55, 1.0, 0.65, a)
		var glass := Color(0.9, 0.97, 1.0, 0.85 * a)
		# 瓶：丸い胴＋首＋栓
		draw_circle(c + Vector2(0, 6 * u), r * 0.42, glass)
		draw_circle(c + Vector2(0, 6 * u), r * 0.36, liq)
		draw_rect(Rect2(c + Vector2(-r * 0.13, -r * 0.5), Vector2(r * 0.26, r * 0.3)), glass)
		draw_rect(Rect2(c + Vector2(-r * 0.17, -r * 0.62), Vector2(r * 0.34, r * 0.14)), Color(0.75, 0.55, 0.32, a))
		if float(pl.pot_cd) > 0.0:
			var Eco = load("res://scripts/economy.gd")
			var f: float = float(pl.pot_cd) / float(Eco.POT_CD)
			draw_arc(c, r * 0.92, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(0, 0, 0, 0.55), r * 0.16)
		var font := ThemeDB.fallback_font
		var txt: String = str(n_s) if n_l <= 0 else "%d+%d" % [n_s, n_l]
		var fs := int(26 * u)
		var p := c + Vector2(r * 0.25, r * 1.02)
		draw_string_outline(font, p - Vector2(60 * u, 0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 60 * u + r * 0.75, fs, int(6 * u), Color(0, 0, 0, 0.9))
		draw_string(font, p - Vector2(60 * u, 0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 60 * u + r * 0.75, fs, Color(0.85, 1.0, 0.88) if not empty else Color(0.6, 0.6, 0.65))

	func _draw() -> void:
		var u := size.y / 720.0
		var stick_center := stick_c if stick_id >= 0 else Vector2(200 * u, size.y - 170 * u)
		Art.button(self, stick_center, R * u, stick_id >= 0)
		if stick_id >= 0:
			var offset := (stick_p - stick_c).limit_length(R * u)
			draw_circle(stick_c + offset, 30 * u, Color(0.55, 0.59, 0.65, 0.3))
		else:
			draw_circle(stick_center, 28 * u, Color(0.3, 0.33, 0.38, 0.2))
		var buttons := _btns()
		for key in buttons:
			var center: Vector2 = buttons[key][0]
			var radius: float = buttons[key][1]
			if shake.has(key):
				center.x += sin(float(shake[key]) * 80.0) * 4 * u
			var pressed := btn_down.has(key)
			if key == "atk" and ui.attack_is_contextual():
				ui.draw_attack_context(self, center, radius, pressed)
				continue
			if key == "gear":
				Art.button(self, center, radius, pressed)
				Art.gear(self, center, radius * 0.6, 0.5)
				continue
			if key == "pot":
				_draw_pot(center, radius, pressed, u)
				continue
			if key.begins_with("call_"):
				_draw_call(key, center, radius, pressed, u)
				continue
			var id := _slot_id(int(key.substr(2))) if key.begins_with("sk") else ""
			CombatArt.action(self, ui, key, id, center, radius, pressed, u)
			if key == "atk":
				_draw_atk_extra(center, radius, u)
