extends RefCounted
## 店（回復薬）と「立ち直る」の確認の絵と押す所（2026-11-16 ②、specs/money_recovery.md）。
## 描くのは dungeon_hud.gd の view（Control）。色：金＝お金・決着、淡い緑＝回復、青＝味方の決定、灰＝押せない。

const GOLD := Color("ffc94d")
const GREEN := Color(0.55, 1.0, 0.65)
const BLUE := Color("3d8bff")
const DIM := Color(0.02, 0.03, 0.07, 0.88)
const EDGE := Color(0.85, 0.68, 0.36)
const SZ_TITLE := 34
const SZ_TEXT := 26
const SZ_NUM := 30

static func shop_rects(size: Vector2) -> Dictionary:
	var u := size.y / 720.0
	var w := 760.0 * u
	var h := 420.0 * u
	var p := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h))
	var r := {"panel": p}
	for i in 2:
		r["row%d" % i] = Rect2(p.position + Vector2(30 * u, (100 + i * 120) * u), Vector2(w - 60 * u, 104 * u))
		r["buy%d" % i] = Rect2(p.position + Vector2(w - 210 * u, (116 + i * 120) * u), Vector2(170 * u, 72 * u))
	r["close"] = Rect2(p.position + Vector2(w - 74 * u, 16 * u), Vector2(58 * u, 58 * u))
	return r

## 店。items＝[{heal, price, have, max}]（小・大）
static func draw_shop(c: Control, size: Vector2, gold: int, items: Array, flash: Dictionary) -> void:
	var u := size.y / 720.0
	var r := shop_rects(size)
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var p: Rect2 = r.panel
	c.draw_rect(p, DIM)
	c.draw_rect(p, EDGE, false, 3 * u)
	c.draw_string(font, p.position + Vector2(32 * u, 60 * u), "回復薬", HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_TITLE * u), Color(1, 0.95, 0.85))
	coin(c, p.position + Vector2(p.size.x - 300 * u, 48 * u), 14 * u)
	c.draw_string(font, p.position + Vector2(p.size.x - 278 * u, 60 * u), str(gold), HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_NUM * u), GOLD)
	for i in items.size():
		var it: Dictionary = items[i]
		var row: Rect2 = r["row%d" % i]
		c.draw_rect(row, Color(1, 1, 1, 0.05))
		flask(c, row.position + Vector2(52 * u, 52 * u), (30 if i == 0 else 40) * u, 1.0)
		c.draw_string(font, row.position + Vector2(110 * u, 46 * u), "体力 %d%%" % int(round(float(it.heal) * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_TEXT * u), GREEN)
		c.draw_string(font, row.position + Vector2(110 * u, 84 * u), "%d / %d" % [int(it.have), int(it.max)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_TEXT * u), Color(0.85, 0.88, 0.95))
		coin(c, row.position + Vector2(row.size.x - 330 * u, 50 * u), 12 * u)
		c.draw_string(font, row.position + Vector2(row.size.x - 310 * u, 62 * u), str(int(it.price)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_NUM * u), GOLD)
		var ok: bool = gold >= int(it.price) and int(it.have) < int(it.max)
		var b: Rect2 = r["buy%d" % i]
		var fl: float = float(flash.get("buy%d" % i, 0.0))
		c.draw_rect(b, (BLUE if ok else Color(0.3, 0.32, 0.36)).lerp(Color.WHITE, fl * 2.0))
		c.draw_string(font, b.position + Vector2(0, 48 * u), "買う", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(SZ_TEXT * u), Color(1, 1, 1, 1.0 if ok else 0.5))
	var cl: Rect2 = r.close
	c.draw_rect(cl, Color(1, 1, 1, 0.08))
	c.draw_line(cl.position + Vector2(16, 16) * u, cl.end - Vector2(16, 16) * u, Color(1, 1, 1, 0.9), 4 * u)
	c.draw_line(cl.position + Vector2(cl.size.x - 16 * u, 16 * u), cl.position + Vector2(16 * u, cl.size.y - 16 * u), Color(1, 1, 1, 0.9), 4 * u)

static func revive_rects(size: Vector2) -> Dictionary:
	var u := size.y / 720.0
	var w := 640.0 * u
	var h := 300.0 * u
	var p := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h))
	return {"panel": p,
		"yes": Rect2(p.position + Vector2(40 * u, 180 * u), Vector2(260 * u, 84 * u)),
		"no": Rect2(p.position + Vector2(w - 300 * u, 180 * u), Vector2(260 * u, 84 * u))}

## 倒れた：「立ち直る（金額）」か「あきらめる」
static func draw_revive(c: Control, size: Vector2, cost: int, gold: int, t: float) -> void:
	var u := size.y / 720.0
	var r := revive_rects(size)
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(t / 0.3, 0.0, 1.0) * 0.55))
	var p: Rect2 = r.panel
	c.draw_rect(p, DIM)
	c.draw_rect(p, EDGE, false, 3 * u)
	c.draw_string(font, p.position + Vector2(0, 70 * u), "立ち直りますか？", HORIZONTAL_ALIGNMENT_CENTER, p.size.x, int(SZ_TITLE * u), Color(1, 0.95, 0.85))
	coin(c, p.position + Vector2(p.size.x * 0.5 - 70 * u, 122 * u), 12 * u)
	c.draw_string(font, p.position + Vector2(p.size.x * 0.5 - 50 * u, 134 * u), str(gold), HORIZONTAL_ALIGNMENT_LEFT, -1, int(SZ_TEXT * u), GOLD if gold >= cost else Color(0.65, 0.65, 0.7))   # 持っているお金（値段はボタンに）
	var ok := gold >= cost
	var y: Rect2 = r.yes
	c.draw_rect(y, GOLD if ok else Color(0.3, 0.32, 0.36))
	c.draw_string(font, y.position + Vector2(0, 54 * u), "立ち直る  %d" % cost, HORIZONTAL_ALIGNMENT_CENTER, y.size.x, int(SZ_TEXT * u), Color(0.1, 0.07, 0.02) if ok else Color(1, 1, 1, 0.45))
	var n: Rect2 = r.no
	c.draw_rect(n, Color(1, 1, 1, 0.1))
	c.draw_rect(n, Color(1, 1, 1, 0.4), false, 2 * u)
	c.draw_string(font, n.position + Vector2(0, 54 * u), "あきらめる", HORIZONTAL_ALIGNMENT_CENTER, n.size.x, int(SZ_TEXT * u), Color(1, 1, 1, 0.9))

## 金の硬貨の印
static func coin(c: Control, ctr: Vector2, r: float) -> void:
	c.draw_circle(ctr, r, GOLD)
	c.draw_arc(ctr, r * 0.62, 0, TAU, 20, Color(0.55, 0.36, 0.08), maxf(1.0, r * 0.18))

## 回復薬の小瓶の印
static func flask(c: Control, ctr: Vector2, r: float, a: float) -> void:
	var glass := Color(0.9, 0.97, 1.0, 0.85 * a)
	c.draw_circle(ctr + Vector2(0, r * 0.2), r * 0.62, glass)
	c.draw_circle(ctr + Vector2(0, r * 0.2), r * 0.53, Color(GREEN.r, GREEN.g, GREEN.b, a))
	c.draw_rect(Rect2(ctr + Vector2(-r * 0.18, -r * 0.72), Vector2(r * 0.36, r * 0.42)), glass)
	c.draw_rect(Rect2(ctr + Vector2(-r * 0.24, -r * 0.9), Vector2(r * 0.48, r * 0.2)), Color(0.75, 0.55, 0.32, a))
