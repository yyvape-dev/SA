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

## 仲間の技・必殺技のアイコン（スキルツリーの画面。コードの図形）
static func draw2(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color, u: float) -> void:
	match id:
		"rush":   # 迅雷：稲妻の矢印
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.3), c + Vector2(-r * 0.05, -r * 0.05), c + Vector2(-r * 0.2, r * 0.15), c + Vector2(r * 0.55, r * 0.35)]), col, 4 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.62, r * 0.38), c + Vector2(r * 0.3, r * 0.42), c + Vector2(r * 0.45, r * 0.12)]), col)
		"barrage":   # 雷連打：並んだ拳の点
			for i in 4:
				ci.draw_circle(c + Vector2(-r * 0.45 + i * r * 0.3, (i % 2) * r * 0.2 - r * 0.1), r * 0.13, Color(col, 1.0 - i * 0.15))
		"storm":   # 雷陣：輪と落ちる稲妻
			ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.55, 0, TAU, 28, Color(col, 0.6), 3 * u)
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.6), c + Vector2(-r * 0.12, -r * 0.1), c + Vector2(r * 0.1, -r * 0.05), c + Vector2(-r * 0.08, r * 0.35)]), col, 4 * u)
		"ult":   # 必殺技：8本の光
			for i in 8:
				var a := i * TAU / 8.0
				var l := r * (0.6 if i % 2 == 0 else 0.38)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.12, c + Vector2(cos(a), sin(a)) * l, col, (4 if i % 2 == 0 else 3) * u)
			ci.draw_circle(c, r * 0.14, col)
		_:
			draw(ci, id, c, r, col, u)

## 派生の印（スキルツリーの画面。名前の文字の代わり。glyph は skill_tree.gd の表）
static func glyph(ci: CanvasItem, g: String, c: Vector2, r: float, col: Color, u: float) -> void:
	var w := 3.0 * u
	match g:
		"band":   # 前へ飛ぶ帯
			ci.draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.35, 0), col, w * 2.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.65, 0), c + Vector2(r * 0.3, -r * 0.25), c + Vector2(r * 0.3, r * 0.25)]), col)
		"heavy":   # 1本の太い斬撃
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.5), c + Vector2(r * 0.5, -r * 0.5), col, w * 2.6)
		"many":   # たくさんの点
			for i in 9:
				ci.draw_circle(c + Vector2((i % 3 - 1) * r * 0.38, (i / 3 - 1) * r * 0.38), r * 0.1, col)
		"fork":   # 三叉
			for a in [-0.45, 0.0, 0.45]:
				ci.draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(cos(a), sin(a)) * r * 0.6, col, w)
		"long":   # 長い矢印
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.25), c + Vector2(r * 0.55, r * 0.25), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.75, r * 0.25), c + Vector2(r * 0.45, r * 0.05), c + Vector2(r * 0.45, r * 0.45)]), col)
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.15), c + Vector2(r * 0.1, -r * 0.15), Color(col, 0.5), w)
		"burst":   # 終点の爆発
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.45), c + Vector2(r * 0.1, r * 0.45), Color(col, 0.6), w)
			for i in 6:
				var a := -PI * 0.5 + (i - 2.5) * 0.45
				ci.draw_line(c + Vector2(r * 0.35, r * 0.3), c + Vector2(r * 0.35, r * 0.3) + Vector2(cos(a), sin(a)) * r * 0.55, col, w)
		"big":   # 大きな円
			ci.draw_arc(c, r * 0.62, 0, TAU, 32, col, w * 1.6)
			ci.draw_arc(c, r * 0.25, 0, TAU, 20, Color(col, 0.6), w)
		"walk":   # 動ける：渦＋矢印
			ci.draw_arc(c + Vector2(-r * 0.15, 0), r * 0.35, 0, TAU * 0.8, 20, col, w)
			ci.draw_line(c + Vector2(r * 0.2, r * 0.45), c + Vector2(r * 0.7, r * 0.45), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, r * 0.45), c + Vector2(r * 0.6, r * 0.3), c + Vector2(r * 0.6, r * 0.6)]), col)
		"out":   # 外へ押す
			for i in 4:
				var a2 := i * TAU / 4.0 + PI * 0.25
				var d := Vector2(cos(a2), sin(a2))
				ci.draw_line(c + d * r * 0.2, c + d * r * 0.6, col, w)
				ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.72, c + d * r * 0.5 + d.orthogonal() * r * 0.13, c + d * r * 0.5 - d.orthogonal() * r * 0.13]), col)
		"back":   # 行って戻る
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.2), c + Vector2(r * 0.5, -r * 0.2), col, w)
			ci.draw_line(c + Vector2(r * 0.6, r * 0.25), c + Vector2(-r * 0.5, r * 0.25), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.7, -r * 0.2), c + Vector2(r * 0.45, -r * 0.38), c + Vector2(r * 0.45, -r * 0.02)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.25), c + Vector2(-r * 0.45, r * 0.07), c + Vector2(-r * 0.45, r * 0.43)]), col)
		"chain":   # 次の敵へ跳ぶ
			var pts := [c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.1, -r * 0.35), c + Vector2(r * 0.2, r * 0.3), c + Vector2(r * 0.6, -r * 0.3)]
			ci.draw_polyline(PackedVector2Array(pts), col, w)
			for q in pts:
				ci.draw_circle(q, r * 0.1, col)
		"slam":   # 叩きつけ
			ci.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.1), col, w * 1.5)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.25), c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.2, 0)]), col)
			ci.draw_arc(c + Vector2(0, r * 0.45), r * 0.55, PI * 0.05, PI * 0.95, 14, col, w)
		"seek":   # 狙う
			ci.draw_arc(c, r * 0.45, 0, TAU, 24, col, w)
			for d2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + d2 * r * 0.25, c + d2 * r * 0.65, col, w)
		"fast":   # 速い（時計）
			ci.draw_arc(c, r * 0.5, 0, TAU, 24, col, w)
			ci.draw_line(c, c + Vector2(0, -r * 0.35), col, w)
			ci.draw_line(c, c + Vector2(r * 0.25, 0), col, w)
		"spread":   # 3方向
			for a3 in [-0.4, 0.0, 0.4]:
				var d3 := Vector2(cos(a3), sin(a3))
				ci.draw_line(c + Vector2(-r * 0.5, 0), c + d3 * r * 0.55, col, w)
				ci.draw_circle(c + d3 * r * 0.62, r * 0.1, col)
		"charge":   # 大きな1発
			ci.draw_circle(c + Vector2(r * 0.2, 0), r * 0.32, col)
			ci.draw_line(c + Vector2(-r * 0.7, 0), c + Vector2(-r * 0.1, 0), Color(col, 0.6), w * 2.0)
		"wave":   # 遠くまで広がる輪
			for i in 3:
				ci.draw_arc(c, r * (0.2 + i * 0.22), 0, TAU, 24, Color(col, 1.0 - i * 0.25), w)
		"stay":   # その場に残る輪
			ci.draw_arc(c, r * 0.5, 0, TAU, 24, col, w * 1.5)
			for i in 4:
				var a4 := i * TAU / 4.0
				ci.draw_circle(c + Vector2(cos(a4), sin(a4)) * r * 0.5, r * 0.1, col)
		"focus":   # 一点へ集める
			for i in 4:
				var a5 := i * TAU / 4.0 + PI * 0.25
				var d5 := Vector2(cos(a5), sin(a5))
				ci.draw_line(c + d5 * r * 0.65, c + d5 * r * 0.3, col, w)
			ci.draw_circle(c, r * 0.14, col)
		"todo":   # 未定（中身はユーザー確認後）
			ci.draw_arc(c + Vector2(0, -r * 0.12), r * 0.25, PI, TAU + PI * 0.4, 12, col, w)
			ci.draw_line(c + Vector2(r * 0.08, r * 0.08), c + Vector2(0, r * 0.22), col, w)
			ci.draw_circle(c + Vector2(0, r * 0.42), r * 0.06, col)
		_:
			ci.draw_circle(c, r * 0.2, col)
