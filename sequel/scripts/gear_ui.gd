extends RefCounted
## 装備の画面（③ specs/gear.md）。
##   ① 育成の画面の 3 つ目のタブ「装備」：左に付けている 5 枠、真ん中に持ち物（30）、右に選んだ物と「付ける」
##   ② 裏の町の工房（部品の屋台）：強化・売る・仲間の装備を買う。クリア後の店からは「売る」だけ
## 色：金＝お金・付けている物より強い印、青＝味方の決定（付ける・強化）、紫＝素材、灰＝押せない。
## 等級の ◆ は字ではなく図形で描く（UI の字は抜き出しのフォント）。
const TreeArt := preload("res://scripts/skill_tree_art.gd")
const AfterArt := preload("res://scripts/after_clear_art.gd")
const Gear := preload("res://scripts/gear.gd")
const GOLD := Color("ffc94d")
const BLUE := Color("3d8bff")
const MAT := Color(0.78, 0.66, 1.0)
const TEXT := Color("eee6d4")
const MUTED := Color("a9b5c3")
const INK := Color("0b111b")
const SHORT := {"weapon": "武器", "armor": "防具", "acc": "装飾品", "lily": "リリィ", "ranka": "ランカ"}
const CELL := Vector2(96, 88)
const STEP := Vector2(102, 94)

static func tab_gear(sz: Vector2) -> Rect2:
	var u: float = sz.y / 720.0
	var p: Vector2 = TreeArt.rects(sz, "rana").panel.position
	return Rect2(p + Vector2(364, 10) * u, Vector2(166, 84) * u)

## 持ち物の並び：枠の順 → 強い順
static func bag_list(pr) -> Array:
	var out := []
	for it in pr.items:
		if not pr.is_equipped(it):
			out.append(it)
	out.sort_custom(func(a, b):
		var sa: int = Gear.SLOTS.find(str(a.slot))
		var sb: int = Gear.SLOTS.find(str(b.slot))
		return sa < sb if sa != sb else Gear.score(a) > Gear.score(b))
	return out

static func diamonds(v, c: Vector2, n: int, r: float, col: Color) -> void:
	for k in n:
		var x: float = c.x + (float(k) - (n - 1) * 0.5) * r * 2.3
		v.draw_colored_polygon(PackedVector2Array([Vector2(x, c.y - r), Vector2(x + r, c.y), Vector2(x, c.y + r), Vector2(x - r, c.y)]), col)

static func coin(v, c: Vector2, r: float) -> void:
	v.draw_circle(c, r, GOLD)
	v.draw_circle(c, r * 0.55, GOLD.darkened(0.3))

static func gem(v, c: Vector2, r: float) -> void:
	v.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), MAT)

## 持ち物の 1 マス
static func cell(v, rc: Rect2, it: Dictionary, better: bool, sel: bool, worn: bool) -> void:
	var u: float = v.size.y / 720.0
	TreeArt.box(v, rc, Color("233846") if sel else INK, BLUE if sel else (GOLD if better else Color("51483a")), 3 if sel else (2 if better else 1))
	TreeArt.label(v, Rect2(rc.position + Vector2(6, 4) * u, Vector2(rc.size.x / u - 12, 30) * u), str(SHORT[str(it.slot)]), 20, MUTED, true)
	diamonds(v, rc.position + Vector2(rc.size.x * 0.5, 44 * u), int(it.tier), 6.5 * u, GOLD if better else Color(0.82, 0.84, 0.9))
	var big := ""
	if str(it.slot) == "weapon":
		big = str(int(round(Gear.weapon_pow(it))))
	if int(it.get("plus", 0)) > 0:
		big += ("  " if big != "" else "") + "+%d" % int(it.plus)
	if big != "":
		TreeArt.label(v, Rect2(rc.position + Vector2(0, 56) * u, Vector2(rc.size.x / u, 30) * u), big, 21, GOLD if better else TEXT, true)
	if better:   # 右上の金の印
		v.draw_circle(rc.position + Vector2(rc.size.x - 12 * u, 12 * u), 7 * u, GOLD)
	if worn:   # 付けている物：左下の青い帯
		v.draw_rect(Rect2(rc.position + Vector2(4, rc.size.y / u - 10) * u, Vector2(rc.size.x / u - 8, 6) * u), BLUE)

## 物の説明（右の欄）
static func detail(v, rc: Rect2, it: Dictionary, cur: Dictionary) -> void:
	var u: float = v.size.y / 720.0
	var x: Vector2 = rc.position
	TreeArt.label(v, Rect2(x, Vector2(rc.size.x, 40 * u)), Gear.name_of(it), 28, TEXT)
	diamonds(v, x + Vector2(rc.size.x - 60 * u, 20 * u), int(it.tier), 8 * u, GOLD)
	var ls: Array = Gear.lines(it)
	for i in ls.size():
		TreeArt.label(v, Rect2(x + Vector2(0, (52 + i * 36) * u), Vector2(rc.size.x, 34 * u)), str(ls[i]), 24, TEXT)
	if not cur.is_empty() and int(cur.uid) != int(it.uid):
		TreeArt.label(v, Rect2(x + Vector2(0, 140 * u), Vector2(rc.size.x, 30 * u)), "付けている物", 20, MUTED)
		var cl: Array = Gear.lines(cur)
		for i in cl.size():
			TreeArt.label(v, Rect2(x + Vector2(0, (172 + i * 32) * u), Vector2(rc.size.x, 30 * u)), str(cl[i]), 21, MUTED)

# ---------------- ① 装備のタブ ----------------
static func equip_rects(sz: Vector2, pr) -> Dictionary:
	var u: float = sz.y / 720.0
	var base: Dictionary = TreeArt.rects(sz, "rana")
	var p: Vector2 = base.panel.position
	var w: float = base.panel.size.x / u
	var r := {"panel": base.panel, "tab_slot": base.tab_slot, "tab_tree": base.tab_tree, "tab_gear": tab_gear(sz), "close": base.close}
	for i in Gear.SLOTS.size():
		r["eq_" + Gear.SLOTS[i]] = Rect2(p + Vector2(16, 112 + i * 112) * u, Vector2(360, 104) * u)
	var bag: Array = bag_list(pr)
	for i in Gear.BAG_MAX:
		r["bag%d" % i] = Rect2(p + Vector2(392 + (i % 5) * STEP.x, 112 + (i / 5) * STEP.y) * u, CELL * u)
	var dx: float = 392 + 5 * STEP.x + 10
	r["detail"] = Rect2(p + Vector2(dx, 112) * u, Vector2(w - dx - 16, 420) * u)
	r["wear"] = Rect2(p + Vector2(dx, 572) * u, Vector2(w - dx - 16, 96) * u)
	r["bag_n"] = bag.size()
	return r

static func draw_equip(v, hud) -> void:
	var u: float = v.size.y / 720.0
	var pr = hud.main.progress
	var r: Dictionary = equip_rects(v.size, pr)
	var p: Vector2 = r.panel.position
	v.draw_rect(Rect2(Vector2.ZERO, v.size), Color(0.01, 0.015, 0.025, 0.94))
	TreeArt.backing(v)
	TreeArt.button(v, r.tab_slot, "技のセット", false)
	TreeArt.button(v, r.tab_tree, "スキル育成", false)
	TreeArt.button(v, r.tab_gear, "装備", true, true)
	TreeArt.button(v, r.close, "×", true)
	coin(v, p + Vector2(566, 52) * u, 13 * u)
	TreeArt.label(v, Rect2(p + Vector2(586, 30) * u, Vector2(200, 44) * u), str(int(pr.gold)), 30, GOLD)
	TreeArt.label(v, Rect2(p + Vector2(680, 30) * u, Vector2(170, 44) * u), "持ち物 %d/%d" % [int(r.bag_n), Gear.BAG_MAX], 22, MUTED)
	for sl in Gear.SLOTS:
		var rc: Rect2 = r["eq_" + sl]
		var it: Dictionary = pr.equipped(sl)
		var on: bool = hud.gear_sel == -2 - Gear.SLOTS.find(sl)
		TreeArt.box(v, rc, Color("203342"), BLUE if on else Color("3c5568"), 3 if on else 1)
		TreeArt.label(v, Rect2(rc.position + Vector2(12, 4) * u, Vector2(180, 32) * u), str(Gear.SLOT_NAME[sl]), 20, MUTED)
		if it.is_empty():
			TreeArt.label(v, Rect2(rc.position + Vector2(12, 46) * u, Vector2(370, 34) * u), "なし", 24, MUTED)
			continue
		diamonds(v, rc.position + Vector2(rc.size.x - 50 * u, 20 * u), int(it.tier), 7 * u, GOLD)
		var ls: Array = Gear.lines(it)
		for i in ls.size():
			TreeArt.label(v, Rect2(rc.position + Vector2(12, (38 + i * 30) * u), Vector2(330, 30) * u), str(ls[i]) + ("   +%d" % int(it.plus) if i == 0 and int(it.plus) > 0 else ""), 22, TEXT)
	var bag: Array = bag_list(pr)
	for i in Gear.BAG_MAX:
		var rc: Rect2 = r["bag%d" % i]
		if i >= bag.size():
			TreeArt.box(v, rc, Color(0.04, 0.05, 0.08, 0.6), Color("2a2f36"), 1)
			continue
		var it: Dictionary = bag[i]
		cell(v, rc, it, pr.is_better(it), int(it.uid) == hud.gear_sel, false)
	var sel: Dictionary = pr.item_by_uid(hud.gear_sel) if hud.gear_sel >= 0 else {}
	if sel.is_empty():
		TreeArt.label(v, Rect2(r.detail.position, Vector2(r.detail.size.x, 36 * u)), "持ち物を押して選ぶ", 23, MUTED)
		TreeArt.label(v, Rect2(r.detail.position + Vector2(0, 44 * u), Vector2(r.detail.size.x, 36 * u)), "金の印＝今より強い", 21, GOLD)
		return
	var cur: Dictionary = pr.equipped(str(sel.slot))
	detail(v, r.detail, sel, cur)
	TreeArt.box(v, r.wear, BLUE.darkened(0.35), BLUE, 2)
	TreeArt.label(v, r.wear, "付ける", 30, Color.WHITE, true)

## 押した：持ち物を選ぶ → 付ける
static func equip_tap(hud, pos: Vector2) -> String:
	var pr = hud.main.progress
	var r: Dictionary = equip_rects(hud.view.size, pr)
	if r.tab_slot.has_point(pos):
		return "slot"
	if r.tab_tree.has_point(pos):
		return "tree"
	if r.close.has_point(pos) or not r.panel.has_point(pos):
		return "close"
	if hud.gear_sel >= 0 and r.wear.has_point(pos):
		var it: Dictionary = pr.item_by_uid(hud.gear_sel)
		if not it.is_empty():
			pr.equip[str(it.slot)] = int(it.uid)
			hud.gear_sel = -1
			hud.main.apply_progress()
			pr.save()
		return ""
	var bag: Array = bag_list(pr)
	for i in bag.size():
		if r["bag%d" % i].has_point(pos):
			hud.gear_sel = -1 if hud.gear_sel == int(bag[i].uid) else int(bag[i].uid)
			return ""
	return ""

# ---------------- ② 工房 ----------------
static func ws_list(pr) -> Array:
	var out := []
	for sl in Gear.SLOTS:
		var it: Dictionary = pr.equipped(sl)
		if not it.is_empty():
			out.append(it)
	return out + bag_list(pr)

static func ws_rects(sz: Vector2, pr) -> Dictionary:
	var u: float = sz.y / 720.0
	var base: Dictionary = TreeArt.rects(sz, "rana")
	var p: Vector2 = base.panel.position
	var w: float = base.panel.size.x / u
	var r := {"panel": base.panel, "close": base.close}
	for i in Gear.BAG_MAX + Gear.SLOTS.size():
		r["it%d" % i] = Rect2(p + Vector2(16 + (i % 7) * STEP.x, 112 + (i / 7) * STEP.y) * u, CELL * u)
	var rx: float = 16 + 7 * STEP.x + 8
	var rw: float = w - rx - 16
	r["detail"] = Rect2(p + Vector2(rx, 112) * u, Vector2(rw, 240) * u)
	r["up"] = Rect2(p + Vector2(rx, 360) * u, Vector2(rw * 0.5 - 6, 96) * u)
	r["sell"] = Rect2(p + Vector2(rx + rw * 0.5 + 6, 360) * u, Vector2(rw * 0.5 - 6, 96) * u)
	for i in Gear.SHOP_ALLY.size():
		r["buy%d" % i] = Rect2(p + Vector2(rx + (i % 2) * (rw * 0.5 + 6), 500 + (i / 2) * 82) * u, Vector2(rw * 0.5 - 6, 74) * u)
	r["rx"] = rx
	r["rw"] = rw
	return r

static func draw_workshop(v, hud) -> void:
	if hud.ws_sell_only:
		draw_after_sell(v, hud)
		return
	var u: float = v.size.y / 720.0
	var pr = hud.main.progress
	var sell_only: bool = hud.ws_sell_only
	var r: Dictionary = ws_rects(v.size, pr)
	var p: Vector2 = r.panel.position
	v.draw_rect(Rect2(Vector2.ZERO, v.size), Color(0.01, 0.015, 0.025, 0.9))
	TreeArt.backing(v)
	TreeArt.label(v, Rect2(p + Vector2(24, 26) * u, Vector2(300, 52) * u), "装備を売る" if sell_only else "工房", 34, TEXT)
	TreeArt.button(v, r.close, "×", true)
	coin(v, p + Vector2(330, 52) * u, 13 * u)
	TreeArt.label(v, Rect2(p + Vector2(350, 30) * u, Vector2(200, 44) * u), str(int(pr.gold)), 30, GOLD)
	var mx: float = 24
	for k in ["t1", "t2", "t3", "t4"]:   # 素材の数（持ち物の下）
		gem(v, p + Vector2(mx, 628) * u, 11 * u)
		TreeArt.label(v, Rect2(p + Vector2(mx + 16, 608) * u, Vector2(170, 40) * u), "%s %d" % [Gear.MAT_NAME[k], int(pr.mats.get(k, 0))], 21, MAT)
		mx += 192
	var lst: Array = ws_list(pr)
	for i in Gear.BAG_MAX + Gear.SLOTS.size():
		var rc: Rect2 = r["it%d" % i]
		if i >= lst.size():
			TreeArt.box(v, rc, Color(0.04, 0.05, 0.08, 0.6), Color("2a2f36"), 1)
			continue
		var it: Dictionary = lst[i]
		var worn: bool = pr.is_equipped(it)
		cell(v, rc, it, false if worn else pr.is_better(it), int(it.uid) == hud.ws_sel, worn)
	var sel: Dictionary = pr.item_by_uid(hud.ws_sel) if hud.ws_sel >= 0 else {}
	if sel.is_empty():
		TreeArt.label(v, Rect2(r.detail.position, Vector2(r.detail.size.x, 36 * u)), "物を押して選ぶ", 23, MUTED)
		TreeArt.label(v, Rect2(r.detail.position + Vector2(0, 40 * u), Vector2(r.detail.size.x, 36 * u)), "青い帯＝付けている物", 21, BLUE.lightened(0.3))
	else:
		detail(v, r.detail, sel, {})
		var worn: bool = pr.is_equipped(sel)
		if not sell_only:   # 強化：100G×段＋素材（段の数）。必ず成功
			var cost: Array = Gear.up_cost(sel)
			var mk: String = str(sel.get("theme", "t1"))
			var can_up: bool = int(sel.plus) < Gear.PLUS_MAX and int(pr.gold) >= int(cost[0]) and int(pr.mats.get(mk, 0)) >= int(cost[1])
			var fl: float = float(hud.shop_flash.get("up", 0.0))
			TreeArt.box(v, r.up, (BLUE.darkened(0.35) if can_up else Color("17202b")).lerp(Color.WHITE, fl * 2.0), BLUE if can_up else Color("525a64"), 2)
			if int(sel.plus) >= Gear.PLUS_MAX:
				TreeArt.label(v, r.up, "強化 最大", 26, MUTED, true)
			else:
				TreeArt.label(v, Rect2(r.up.position + Vector2(0, 4 * u), Vector2(r.up.size.x, 40 * u)), "強化 +%d" % (int(sel.plus) + 1), 26, Color.WHITE if can_up else MUTED, true)
				coin(v, r.up.position + Vector2(24 * u, 70 * u), 9 * u)
				TreeArt.label(v, Rect2(r.up.position + Vector2(38 * u, 52 * u), Vector2(110 * u, 36 * u)), str(int(cost[0])), 22, GOLD)
				gem(v, r.up.position + Vector2(r.up.size.x * 0.55, 70 * u), 9 * u)
				TreeArt.label(v, Rect2(r.up.position + Vector2(r.up.size.x * 0.55 + 14 * u, 52 * u), Vector2(120 * u, 36 * u)), "%d / %d" % [int(cost[1]), int(pr.mats.get(mk, 0))], 22, MAT)
		var can_sell: bool = not worn
		TreeArt.box(v, r.sell, Color("2e2a1c") if can_sell else Color("17202b"), GOLD if can_sell else Color("525a64"), 2)
		TreeArt.label(v, Rect2(r.sell.position + Vector2(0, 4 * u), Vector2(r.sell.size.x, 40 * u)), "売る" if can_sell else "付けている", 26, GOLD if can_sell else MUTED, true)
		if can_sell:
			coin(v, r.sell.position + Vector2(r.sell.size.x * 0.5 - 40 * u, 70 * u), 9 * u)
			TreeArt.label(v, Rect2(r.sell.position + Vector2(r.sell.size.x * 0.5 - 24 * u, 52 * u), Vector2(120 * u, 36 * u)), "+%d" % Gear.sell_price(sel), 22, GOLD)
	if sell_only:
		return
	TreeArt.label(v, Rect2(p + Vector2(float(r.rx), 466) * u, Vector2(float(r.rw), 30) * u), "仲間の装備", 22, MUTED)
	for i in Gear.SHOP_ALLY.size():
		var o: Array = Gear.SHOP_ALLY[i]
		var rc: Rect2 = r["buy%d" % i]
		var ok: bool = int(pr.gold) >= int(o[2]) and pr.bag_count() < Gear.BAG_MAX
		var fl: float = float(hud.shop_flash.get("ally%d" % i, 0.0))
		TreeArt.box(v, rc, (Color("203342") if ok else Color("17202b")).lerp(Color.WHITE, fl * 2.0), BLUE if ok else Color("525a64"), 1)
		TreeArt.label(v, Rect2(rc.position + Vector2(12 * u, 0), Vector2(120 * u, rc.size.y)), str(SHORT[o[0]]), 22, TEXT if ok else MUTED)
		diamonds(v, rc.position + Vector2(rc.size.x * 0.48, rc.size.y * 0.5), int(o[1]), 7 * u, GOLD if ok else MUTED)
		coin(v, rc.position + Vector2(rc.size.x - 92 * u, rc.size.y * 0.5), 9 * u)
		TreeArt.label(v, Rect2(rc.position + Vector2(rc.size.x - 78 * u, 0), Vector2(76 * u, rc.size.y)), str(int(o[2])), 22, GOLD if ok else MUTED)

## 押した。戻り値 "close" で閉じる
static func ws_tap(hud, pos: Vector2) -> String:
	if hud.ws_sell_only:
		return after_sell_tap(hud, pos)
	var pr = hud.main.progress
	var r: Dictionary = ws_rects(hud.view.size, pr)
	if r.close.has_point(pos) or not r.panel.has_point(pos):
		return "close"
	var sel: Dictionary = pr.item_by_uid(hud.ws_sel) if hud.ws_sel >= 0 else {}
	if not sel.is_empty():
		if not hud.ws_sell_only and r.up.has_point(pos):
			var cost: Array = Gear.up_cost(sel)
			var mk: String = str(sel.get("theme", "t1"))
			if int(sel.plus) < Gear.PLUS_MAX and int(pr.gold) >= int(cost[0]) and int(pr.mats.get(mk, 0)) >= int(cost[1]):
				pr.gold -= int(cost[0])
				pr.mats[mk] = int(pr.mats.get(mk, 0)) - int(cost[1])
				sel.plus = int(sel.plus) + 1
				hud.shop_flash["up"] = 0.15
				hud.main.apply_progress()
				pr.save()
			return ""
		if r.sell.has_point(pos) and not pr.is_equipped(sel):
			pr.gold += Gear.sell_price(sel)
			pr.items.erase(sel)
			hud.ws_sel = -1
			pr.save()
			return ""
	if not hud.ws_sell_only:
		for i in Gear.SHOP_ALLY.size():
			if r["buy%d" % i].has_point(pos):
				var o: Array = Gear.SHOP_ALLY[i]
				if int(pr.gold) >= int(o[2]) and pr.bag_count() < Gear.BAG_MAX:
					var rng := RandomNumberGenerator.new()
					rng.randomize()
					var it: Dictionary = Gear.make(rng, pr.next_uid, str(o[0]), int(o[1]), [1, 1], "t1")
					pr.next_uid += 1
					pr.gold -= int(o[2])
					pr.items.append(it)
					hud.ws_sel = int(it.uid)
					hud.shop_flash["ally%d" % i] = 0.15
					pr.save()
				return ""
	var lst: Array = ws_list(pr)
	for i in lst.size():
		if r["it%d" % i].has_point(pos):
			hud.ws_sel = -1 if hud.ws_sel == int(lst[i].uid) else int(lst[i].uid)
			return ""
	return ""

static func after_sell_rects(size: Vector2) -> Dictionary:
	var u := size.y / 720.0
	var content := Rect2(Vector2(66, 42) * u, size - Vector2(132, 84) * u)
	var origin := content.position
	var details_x := origin.x + content.size.x * 0.515
	var details_width := content.end.x - details_x
	var cell_w := (details_x - origin.x - 40 * u) / 7.0 - 7 * u
	var layout := {
		"close": Rect2(Vector2(content.end.x - 182 * u, origin.y), Vector2(182, 84) * u),
		"mode": Rect2(Vector2(details_x, origin.y + 112 * u), Vector2(details_width, 84 * u)),
		"detail": Rect2(Vector2(details_x, origin.y + 220 * u), Vector2(details_width, 240 * u)),
		"sell": Rect2(Vector2(details_x, content.end.y - 92 * u), Vector2(details_width, 92 * u)),
	}
	for i in Gear.BAG_MAX + Gear.SLOTS.size():
		layout["it%d" % i] = Rect2(origin + Vector2((i % 7) * (cell_w + 7 * u), (106 + int(i / 7.0) * 92) * u), Vector2(cell_w, 85 * u))
	return layout

static func sale_items(hud) -> Array:
	var pr = hud.main.progress
	var items := []
	var ids: Array = hud.ws_selected if hud.ws_multi else [int(hud.ws_sel)]
	for uid in ids:
		var item: Dictionary = pr.item_by_uid(uid)
		if not item.is_empty() and not pr.is_equipped(item):
			items.append(item)
	return items

static func sale_total(items: Array) -> int:
	var total := 0
	for item in items:
		total += Gear.sell_price(item)
	return total

static func draw_after_sell(v, hud) -> void:
	var pr = hud.main.progress
	var u: float = v.size.y / 720.0
	var r := after_sell_rects(v.size)
	TreeArt.backing(v)
	var origin := Vector2(66, 42) * u
	TreeArt.label(v, Rect2(origin, Vector2(260, 84) * u), "装備を売る", 32, TEXT)
	coin(v, origin + Vector2(278, 42) * u, 13 * u)
	TreeArt.label(v, Rect2(origin + Vector2(301, 0) * u, Vector2(180, 84) * u), str(pr.gold), 30, GOLD)
	TreeArt.button(v, r.close, "店へ戻る", false)
	TreeArt.button(v, r.mode, "一つ選ぶ" if hud.ws_multi else "まとめて選ぶ", false)
	var list := ws_list(pr)
	for i in Gear.BAG_MAX + Gear.SLOTS.size():
		var rect: Rect2 = r["it%d" % i]
		var item: Dictionary = list[i] if i < list.size() else {}
		var uid := int(item.get("uid", -1))
		var chosen: bool = not item.is_empty() and (uid in hud.ws_selected if hud.ws_multi else uid == hud.ws_sel)
		TreeArt.box(v, rect, Color("233846") if chosen else INK, GOLD if chosen else Color("454639"), 2 if chosen else 1)
		if item.is_empty():
			continue
		var image := Rect2(rect.position + Vector2((rect.size.x - 58 * u) * 0.5, 4 * u), Vector2(58, 58) * u)
		if not AfterArt.draw_art(v, str(item.slot), image):
			TreeArt.label(v, image, SHORT[str(item.slot)], 17, TEXT, true)
		diamonds(v, rect.position + Vector2(rect.size.x * 0.5, 70 * u), int(item.tier), 5.5 * u, GOLD)
		if pr.is_equipped(item):
			v.draw_rect(Rect2(rect.end - Vector2(rect.size.x, 6 * u), Vector2(rect.size.x, 6 * u)), BLUE)
	var sale := sale_items(hud)
	var detail_rect: Rect2 = r.detail
	var sel: Dictionary = pr.item_by_uid(hud.ws_sel)
	if hud.ws_multi:
		var summary := "%d 点  +%d" % [sale.size(), sale_total(sale)]
		if hud.ws_confirm:
			summary = "%d 点を売りますか？  +%d" % [sale.size(), sale_total(sale)]
		TreeArt.label(v, Rect2(detail_rect.position, Vector2(detail_rect.size.x, 56 * u)), summary, 28, GOLD)
		for i in mini(sale.size(), 4):
			TreeArt.label(v, Rect2(detail_rect.position + Vector2(0, (56 + i * 32) * u), Vector2(detail_rect.size.x, 32 * u)), Gear.name_of(sale[i]), 21, TEXT)
		if sale.size() > 4:
			TreeArt.label(v, Rect2(detail_rect.position + Vector2(0, 184 * u), Vector2(detail_rect.size.x, 32 * u)), "残り %d 点" % (sale.size() - 4), 21, TEXT)
	elif not sel.is_empty():
		detail(v, detail_rect, sel, {})
		if pr.is_equipped(sel):
			TreeArt.label(v, Rect2(detail_rect.position + Vector2(0, 195 * u), Vector2(detail_rect.size.x, 40 * u)), "装備中", 24, BLUE.lightened(0.25))
	else:
		var hint := "物を押して選ぶ"
		if list.is_empty():
			hint = "売れる装備がありません"
		if hud.ws_received > 0:
			hint = "受け取り  +%d" % hud.ws_received
		TreeArt.label(v, Rect2(detail_rect.position, Vector2(detail_rect.size.x, 56 * u)), hint, 27, MUTED)
	if not sale.is_empty():
		var action := "売る  +%d" % sale_total(sale)
		if hud.ws_multi:
			action = "売る・確定  +%d" % sale_total(sale) if hud.ws_confirm else "%d 点を売る" % sale.size()
		TreeArt.box(v, r.sell, Color("2e2a1c"), GOLD, 2)
		TreeArt.label(v, r.sell, action, 28, GOLD, true)

static func after_sell_tap(hud, pos: Vector2) -> String:
	var pr = hud.main.progress
	var r := after_sell_rects(hud.view.size)
	if r.close.has_point(pos):
		return "close"
	if r.mode.has_point(pos):
		hud.ws_multi = not hud.ws_multi
		hud.ws_confirm = false
		hud.ws_sel = -1
		hud.ws_selected.clear()
		return ""
	if r.sell.has_point(pos):
		var sale := sale_items(hud)
		if sale.is_empty():
			return ""
		if hud.ws_multi and not hud.ws_confirm:
			hud.ws_confirm = true
			return ""
		hud.ws_received = sale_total(sale)
		pr.gold += hud.ws_received
		for item in sale:
			pr.items.erase(item)
		hud.ws_sel = -1
		hud.ws_selected.clear()
		hud.ws_confirm = false
		hud.ws_multi = false
		pr.save()
		return ""
	var list := ws_list(pr)
	for i in list.size():
		if not r["it%d" % i].has_point(pos):
			continue
		var uid := int(list[i].uid)
		hud.ws_confirm = false
		if not hud.ws_multi:
			hud.ws_sel = uid if hud.ws_sel != uid else -1
		elif uid in hud.ws_selected:
			hud.ws_selected.erase(uid)
		elif not pr.is_equipped(list[i]):
			hud.ws_selected.append(uid)
		break
	return ""
