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
		"shot":   # ランカ 指弾：指先から飛ぶ気弾（玉＋尾）
			ci.draw_circle(c + Vector2(r * 0.28, -r * 0.05), r * 0.18, col)
			for i in 3:
				var y := -r * 0.05 + (i - 1) * r * 0.12
				ci.draw_line(c + Vector2(-r * 0.6, y), c + Vector2(r * 0.08, y * 0.6 - r * 0.02), Color(col, 0.75 - i * 0.15), (3 - absf(i - 1)) * u * 1.5)
		"ring":   # ランカ 円環：重なって広がる輪（床の楕円）
			for i in 3:
				var rr := r * (0.22 + i * 0.2)
				var pts := PackedVector2Array()
				for k in 33:
					var a := float(k) / 32.0 * TAU
					pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.55 + r * 0.1))
				ci.draw_polyline(pts, Color(col, 1.0 - i * 0.25), (4 - i) * u)
		"quake":   # ランカ 星震：降る星（四芒星）と地面の線
			for s in [[Vector2(-0.3, -0.35), 0.22], [Vector2(0.25, -0.15), 0.3], [Vector2(-0.05, 0.12), 0.16]]:
				var q: Vector2 = c + (s[0] as Vector2) * r
				var k2: float = float(s[1]) * r
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -k2), q + Vector2(k2 * 0.25, -k2 * 0.25), q + Vector2(k2, 0), q + Vector2(k2 * 0.25, k2 * 0.25),
					q + Vector2(0, k2), q + Vector2(-k2 * 0.25, k2 * 0.25), q + Vector2(-k2, 0), q + Vector2(-k2 * 0.25, -k2 * 0.25)]), col)
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.45), c + Vector2(r * 0.6, r * 0.45), Color(col, 0.6), 3 * u)
		_:
			ci.draw_circle(c, r * 0.2, col)
