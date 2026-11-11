extends CanvasLayer
## 横持ちのタッチ操作。左半分＝触った所に出るスティック（倒しきると走る）。右下＝攻撃（大）・回避。
## 文字は使わない（日本語フォントを入れるまでは図形のアイコン）。

const Art := preload("res://scripts/t6_hud_art.gd")
const SkillIcons := preload("res://scripts/skill_icons.gd")
var main          # main.gd（スキルの枠・街かどうか）
var player # Rana or the manual Lily input controller
var battle: Node3D
var pad: Control
var hud: Control
var basic_combat_only := false
var lily_controls := false

func ult_value() -> float:
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
		var r: float = ui.battle.hp / ui.battle.hp_max
		shown = maxf(r, shown - delta * 0.6) if shown > r else r
		queue_redraw()
	func _draw() -> void:
		Art.gauges(self, ui, size.y / 720.0, shown)

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
		b["ult"] = [Vector2(s.x - 100 * u, 210 * u), 62 * u]
		if not ui.lily_controls and ui.main and ui.main.hud and ui.main.dungeon == null and not ui.main.hud.menu_open and not ui.main.hud.slot_open:
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
			return ["rush", "barrage", "storm"][i]
		if ui.main and ui.main.progress:
			return str(ui.main.progress.skill_slots[i])
		return ""

	func _press(k: String) -> void:
		var pl = ui.player
		match k:
			"atk": pl.attack_press()
			"dodge": pl.dodge()
			"gear": ui.main.hud.open_slots()
			"ult": pl.use_ult()
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
		var font := ThemeDB.fallback_font
		var pl = ui.player
		for key in buttons:
			var center: Vector2 = buttons[key][0]
			var radius: float = buttons[key][1]
			if shake.has(key):
				center.x += sin(float(shake[key]) * 80.0) * 4 * u
			var pressed := btn_down.has(key)
			var action: bool = key == "atk" or key.begins_with("sk")
			Art.button(self, center, radius, pressed, key == "ult", action)
			var color := Color(1, 1, 1, (1.0 if pressed else 0.9) if action else (0.7 if pressed else 0.38))
			match key:
				"atk":
					if ui.lily_controls:
						Art.icon(self, Art.FIST, center, radius * 1.25, color)
					else:
						draw_arc(center + Vector2(-8, 10) * u, radius * 0.55, -2.4, -0.2, 20, color, 5 * u, true)
				"dodge":
					Art.icon(self, Art.DODGE, center, radius * 1.25, color)
				"ult":
					if ui.ult_value() < ui.battle.ULT_COST:
						draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), Color(0.015, 0.015, 0.025, 0.55))
					else:
						for stock in int(ui.ult_value() / ui.battle.ULT_COST):
							draw_circle(center + Vector2((stock - 0.5) * 15, radius * 0.65), 3 * u, Color(0.88, 0.45, 1, 0.7))
				"gear":
					Art.gear(self, center, radius * 0.6, 0.5)
				_:
					var id := _slot_id(int(key.substr(2)))
					var cd: float = float(pl.skill_cd.get(id, 0.0))
					var full: float = float(pl.skills[id].cd) if pl.skills.has(id) else 1.0
					if ui.lily_controls and Art.ICONS.has(id):
						Art.icon(self, Art.ICONS[id], center, radius * 1.25, color)
					else:
						SkillIcons.draw(self, id, center, radius, color, u)
					if cd > 0.0:
						draw_circle(center, radius * 0.78, Color(0.01, 0.015, 0.025, 0.35))
						draw_arc(center, radius * 0.9, -PI * 0.5, -PI * 0.5 + TAU * clampf(cd / full, 0, 1), 48, Color(0.73, 0.61, 0.39, 0.55), 2 * u, true)
						var text := ("%.1f" % cd) if cd < 10.0 else str(int(ceil(cd)))
						var font_size := int(24 * u)
						var position := center + Vector2(-radius, font_size * 0.35)
						draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, font_size, int(5 * u), Color(0.01, 0.01, 0.02, 0.85))
						draw_string(font, position, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, font_size, Color(0.9, 0.92, 0.94, 0.85))
					if pl.skill_ready_flash.has(id):
						draw_arc(center, radius * 0.95, 0, TAU, 48, Color(0.8, 0.7, 0.48, float(pl.skill_ready_flash[id]) / 0.25 * 0.5), 2 * u, true)
