extends CanvasLayer
## 横持ちのタッチ操作。左半分＝触った所に出るスティック（倒しきると走る）。右下＝攻撃（大）・回避。
## 文字は使わない（日本語フォントを入れるまでは図形のアイコン）。

var player: Node3D
var pad: Control

func _ready() -> void:
	pad = _Pad.new()
	pad.ui = self
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(pad)

class _Pad extends Control:
	var ui
	var stick_id := -1
	var stick_c := Vector2.ZERO
	var stick_p := Vector2.ZERO
	var btn_down := {}
	const R := 90.0

	func _btns() -> Dictionary:
		var s := size
		var u := s.y / 720.0
		return {
			"atk": [Vector2(s.x - 170 * u, s.y - 150 * u), 82 * u],
			"dodge": [Vector2(s.x - 330 * u, s.y - 95 * u), 56 * u],
		}

	func _input(e: InputEvent) -> void:
		var pos := Vector2.ZERO
		var idx := 0
		var pressed := false
		var is_touch := false
		if e is InputEventScreenTouch:
			pos = e.position; idx = e.index; pressed = e.pressed; is_touch = true
		elif e is InputEventScreenDrag:
			if e.index == stick_id:
				stick_p = e.position
				_apply()
				queue_redraw()
			return
		else:
			return
		if not is_touch:
			return
		if pressed:
			var b := _btns()
			for k in b:
				if pos.distance_to(b[k][0]) < b[k][1] * 1.15:
					btn_down[k] = idx
					if k == "atk": ui.player.attack()
					else: ui.player.dodge()
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
		queue_redraw()

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
		for k in b:
			var p: Vector2 = b[k][0]
			var r: float = b[k][1]
			var on := btn_down.has(k)
			draw_circle(p, r, Color(0.08, 0.1, 0.16, 0.55 if not on else 0.8))
			draw_arc(p, r, 0, TAU, 48, Color("c9a24a") if k == "atk" else Color("29e0ff"), 3 * u)
			if k == "atk":   # 斬撃の弧
				draw_arc(p + Vector2(-8, 10) * u, r * 0.55, -2.4, -0.2, 20, Color(1, 1, 1, 0.9), 6 * u)
			else:            # 回避の山形2つ
				for dx in [-12, 8]:
					var q := p + Vector2(dx, 0) * u
					draw_polyline(PackedVector2Array([q + Vector2(-8, -16) * u, q + Vector2(8, 0) * u, q + Vector2(-8, 16) * u]), Color(1, 1, 1, 0.9), 5 * u)
