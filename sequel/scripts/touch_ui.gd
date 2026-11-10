extends CanvasLayer
## 横持ちのタッチ操作。左半分＝触った所に出るスティック（倒しきると走る）。右下＝攻撃（大）・回避。
## 文字は使わない（日本語フォントを入れるまでは図形のアイコン）。

const SkillIcons := preload("res://scripts/skill_icons.gd")
var main          # main.gd（スキルの枠・街かどうか）
var player # Rana or the manual Lily input controller
var battle: Node3D
var pad: Control
var hud: Control
var basic_combat_only := false

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
		var u := size.y / 720.0
		var p := Vector2(36, 30) * u
		var w := 420.0 * u
		var h := 22.0 * u
		var r: float = ui.battle.hp / ui.battle.hp_max
		draw_rect(Rect2(p - Vector2(4, 4) * u, Vector2(w, h) + Vector2(8, 8) * u), Color(0.02, 0.03, 0.07, 0.75))
		draw_rect(Rect2(p, Vector2(w * shown, h)), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(p, Vector2(w * r, h)), Color("3d8bff") if r > 0.3 else Color("29e0ff"))
		draw_rect(Rect2(p, Vector2(w * r, h * 0.35)), Color(1, 1, 1, 0.25))
		if ui.basic_combat_only:
			return
		# 必殺技のゲージ（金の細い帯）。満タンで脈打つ
		var g: float = ui.battle.ult / ui.battle.ULT_MAX
		var gp := p + Vector2(0, h + 8 * u)
		draw_rect(Rect2(gp - Vector2(2, 2) * u, Vector2(w, 9 * u) + Vector2(4, 4) * u), Color(0.02, 0.03, 0.07, 0.75))
		var full := g >= 1.0
		var gc := Color("ffc94d") if not full else Color("ffc94d").lerp(Color(1, 1, 0.9), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
		draw_rect(Rect2(gp, Vector2(w * g, 9 * u)), gc)
		# リリィの必殺技のゲージ（蒼の細い帯、2026-11-07）。仲間がいる時だけ。満タンで自動で出る
		if ui.battle.ally:
			var lg: float = ui.battle.ally_ult / ui.battle.ULT_MAX
			var lp := gp + Vector2(0, 9 * u + 6 * u)
			var lw := w * 0.6
			draw_rect(Rect2(lp - Vector2(2, 2) * u, Vector2(lw, 5 * u) + Vector2(4, 4) * u), Color(0.02, 0.03, 0.07, 0.75))
			var lc := Color("4fb8ff") if lg < 1.0 else Color("4fb8ff").lerp(Color(0.9, 0.97, 1.0), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
			draw_rect(Rect2(lp, Vector2(lw * lg, 5 * u)), lc)

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
		var ac := Vector2(s.x - 175 * u, s.y - 190 * u)
		var b := {
			"atk": [ac, 78 * u],
			"dodge": [Vector2(s.x - 345 * u, s.y - 105 * u), 50 * u],
		}
		if ui.basic_combat_only:
			return b
		for i in 3:
			var a := deg_to_rad(SKILL_ANG[i])
			b["sk%d" % i] = [ac + Vector2(cos(a), -sin(a)) * 175 * u, 52 * u]
		if ui.battle and ui.battle.ult >= ui.battle.ULT_MAX:   # 必殺技：4枠目の場所（215°）に、満タンの時だけ大きな金のボタン
			var a4 := deg_to_rad(215.0)
			b["ult"] = [ac + Vector2(cos(a4), -sin(a4)) * 175 * u, 60 * u]
		if ui.main and ui.main.hud and ui.main.dungeon == null and not ui.main.hud.menu_open and not ui.main.hud.slot_open:
			b["gear"] = [Vector2(s.x - 420 * u, s.y - 52 * u), 30 * u]
		return b

	func _process(delta: float) -> void:
		for k in shake.keys():
			shake[k] = float(shake[k]) - delta
			if shake[k] <= 0.0:
				shake.erase(k)
		queue_redraw()

	func _slot_id(i: int) -> String:
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
		if stick_id >= 0:
			draw_circle(stick_c, R * u, Color(1, 1, 1, 0.10))
			draw_arc(stick_c, R * u, 0, TAU, 48, Color(1, 1, 1, 0.35), 3 * u)
			var v := stick_p - stick_c
			if v.length() > R * u: v = v.normalized() * R * u
			draw_circle(stick_c + v, 34 * u, Color(1, 1, 1, 0.45))
		else:
			var c := Vector2(200 * u, size.y - 170 * u)
			draw_arc(c, R * u, 0, TAU, 48, Color(1, 1, 1, 0.18), 3 * u)
		var b := _btns()
		var font := ThemeDB.fallback_font
		var pl = ui.player
		for k in b:
			var p: Vector2 = b[k][0]
			var r: float = b[k][1]
			if shake.has(k):
				p.x += sin(float(shake[k]) * 80.0) * 5 * u
			var on := btn_down.has(k)
			draw_circle(p, r, Color(0.04, 0.06, 0.13, 0.55 if on else 0.28))
			var rim := Color(1, 1, 1, 0.5)
			if k == "atk": rim = Color("c9a24a")
			elif k == "ult":
				var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
				draw_circle(p, r, Color(0.35, 0.22, 0.02, 0.6))
				draw_arc(p, r + 4 * u * pulse, 0, TAU, 48, Color(1, 0.85, 0.4, 0.5 + 0.5 * pulse), 4 * u, true)
				rim = Color("ffc94d")
			elif k == "dodge": rim = Color("29e0ff")
			draw_arc(p, r, 0, TAU, 48, rim, 2 * u, true)
			match k:
				"atk":   # 斬撃の弧
					draw_arc(p + Vector2(-8, 10) * u, r * 0.55, -2.4, -0.2, 20, Color(1, 1, 1, 0.9), 6 * u)
				"dodge":   # 山形2つ
					for dx in [-12, 8]:
						var q := p + Vector2(dx, 0) * u
						draw_polyline(PackedVector2Array([q + Vector2(-8, -16) * u, q + Vector2(8, 0) * u, q + Vector2(-8, 16) * u]), Color(1, 1, 1, 0.9), 5 * u)
				"ult":   # 必殺技：金の菱形（決着の色）と、交差する2本の弧
					var dpts := PackedVector2Array([p + Vector2(0, -r * 0.5), p + Vector2(r * 0.38, 0), p + Vector2(0, r * 0.5), p + Vector2(-r * 0.38, 0)])
					draw_colored_polygon(dpts, Color(1, 0.86, 0.45, 0.95))
					draw_arc(p, r * 0.7, -2.6, -0.5, 18, Color(1, 1, 1, 0.9), 4 * u)
					draw_arc(p, r * 0.7, 0.5, 2.6, 18, Color(1, 1, 1, 0.9), 4 * u)
				"gear":   # 歯車
					for i in 8:
						var a := i * TAU / 8.0
						draw_line(p + Vector2(cos(a), sin(a)) * r * 0.35, p + Vector2(cos(a), sin(a)) * r * 0.7, Color(1, 1, 1, 0.8), 5 * u)
					draw_circle(p, r * 0.42, Color(1, 1, 1, 0.8))
					draw_circle(p, r * 0.2, Color(0.04, 0.06, 0.13, 1))
				_:
					var id := _slot_id(int(k.substr(2)))
					var cd: float = float(pl.skill_cd.get(id, 0.0))
					var full: float = float(pl.skills[id].cd) if pl.skills.has(id) else 1.0
					var ic := Color(1, 1, 1, 0.9) if cd <= 0.0 else Color(1, 1, 1, 0.35)
					if cd > 0.0:
						draw_circle(p, r, Color(0, 0, 0, 0.5))
					SkillIcons.draw(self, id, p, r, ic, u)
					if cd > 0.0:   # 外周：残りの割合（金、12時から時計回りに減る）＋残り秒
						draw_arc(p, r - 2 * u, -PI / 2.0, -PI / 2.0 + TAU * (cd / full), 48, Color("ffc94d"), 4 * u, true)
						var txt := ("%.1f" % cd) if cd < 10.0 else str(int(ceil(cd)))
						var fs := int(26 * u)
						draw_string_outline(font, p + Vector2(-r, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, int(6 * u), Color(0, 0, 0, 0.9))
						draw_string(font, p + Vector2(-r, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color.WHITE)
					if pl.skill_ready_flash.has(id):   # 使えるようになった瞬間に縁が光る
						draw_arc(p, r + 2 * u, 0, TAU, 48, Color(1, 0.86, 0.45, float(pl.skill_ready_flash[id]) / 0.25), 6 * u, true)
