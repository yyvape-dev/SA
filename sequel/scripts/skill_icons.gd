extends RefCounted
## スキルのアイコン（コードの図形。技が固まったら外部AIに発注票）。c＝中心、r＝半径、col＝線の色
static func draw(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, u: float) -> void:
	match id:
		"flurry":   # 交差する斬撃の弧3本
			for i in 3:
				var a := -0.9 + i * 0.6
				ci.draw_arc(c + Vector2(cos(a), sin(a)) * r * 0.15, r * 0.55, a + 1.9, a + 3.6, 14, col, 4 * u)
		"rift":   # 床を走るひび（ギザギザ）
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(c + Vector2(-r * 0.6 + i * r * 0.24, (r * 0.18 if i % 2 else -r * 0.12) + r * 0.15))
			ci.draw_polyline(pts, col, 4 * u)
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.42), c + Vector2(r * 0.6, r * 0.42), Color(col, 0.5), 2 * u)
		"vortex":   # 渦（巻き込む螺旋）
			var sp := PackedVector2Array()
			for i in 28:
				var k := float(i) / 27.0
				var a2 := k * 4.6
				sp.append(c + Vector2(cos(a2), sin(a2)) * r * (0.08 + 0.55 * k))
			ci.draw_polyline(sp, col, 4 * u)
		_:
			ci.draw_circle(c, r * 0.2, col)
