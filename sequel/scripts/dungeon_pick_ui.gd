extends RefCounted
## ダンジョンの札（2026-11-18 ユーザー決定：ステージ → 4 つの札 → 難易度。specs/dungeon_themes.md 4.）
## 地図でステージを押すと、右に 2×2 の札。札＝番号（1-1〜4-4）・ボスの絵（色替えの色で）・出る敵・クリアの金の輪・錠。
## 字は番号だけ（名前はまだ決めていない）。
const SA := preload("res://scripts/dungeon_select_art.gd")
const M := preload("res://scripts/dungeon_select_materials.gd")
const Themes := preload("res://scripts/dungeon_themes.gd")
const GOLD := Color("e7bd72")
const RED := Color("ef666b")
const INK := Color("080e18")

static func rects(sz: Vector2, t: float) -> Dictionary:
	var r: Dictionary = SA.rects(sz, "diff", t)
	var slide: float = (1.0 - smoothstep(0.0, 0.18, t)) * 10.0 * sz.y / 720.0
	for i in Themes.DN:
		r["dun%d" % i] = Rect2(Vector2(sz.x * (0.405 + (i % 2) * 0.265) + slide, sz.y * (0.18 + (i / 2) * 0.30)), Vector2(sz.x * 0.255, sz.y * 0.28))
	return r

## 敵の 1 コマ目（歩き）を rc に収めて描く。コマを切り出して ImageTexture にして持つ
## （圧縮のまま 2D で範囲を描くと、ソフトの GL で白い四角になった。2026-11-18）
static var _cache := {}
static func _frame(v, kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var tex: Texture2D = null
	var clips: Dictionary = v.hud.main.battle.foe_clips
	if clips.has(kind) and clips[kind].has("walk"):
		var f: Array = clips[kind].walk.frames[0]
		var path: String = "res://assets/foe/" + str(f[0])
		if ResourceLoader.exists(path):
			var img: Image = (load(path) as Texture2D).get_image()
			if img.is_compressed():
				img.decompress()
			tex = ImageTexture.create_from_image(img.get_region(Rect2i(int(f[1]), int(f[2]), int(f[3]), int(f[4]))))
	_cache[kind] = tex
	return tex

static func foe(v, kind: String, rc: Rect2, col: Color) -> void:
	var tex: Texture2D = _frame(v, kind)
	if tex == null:
		return
	var sz: Vector2 = tex.get_size()
	var k: float = minf(rc.size.x / sz.x, rc.size.y / sz.y)
	var ext: Vector2 = sz * k
	v.draw_texture_rect(tex, Rect2(Vector2(rc.get_center().x - ext.x * 0.5, rc.end.y - ext.y), ext), false, col)

static func draw(v, h, sz: Vector2) -> void:
	var u: float = sz.y / 720.0
	var r: Dictionary = rects(sz, h.menu_t)
	SA.backing(v, sz)
	SA.mission(v, h, r.hero)
	var pr = h.main.progress
	for i in Themes.DN:
		var rc: Rect2 = r["dun%d" % i]
		if h.shake_hard > 0.0 and h.shake_i == 40 + i:
			rc.position.x += sin(h.shake_hard * 60.0) * 7.0 * u
		var id: String = Themes.dungeon_id(h.menu_theme, i + 1)
		var open_: bool = pr.dungeon_open(id)
		var sleeve := StyleBoxTexture.new()
		sleeve.texture = M.REPORT
		sleeve.texture_margin_left = 85
		sleeve.texture_margin_right = 90
		sleeve.texture_margin_top = 32
		sleeve.texture_margin_bottom = 32
		sleeve.modulate_color = Color.WHITE if open_ else Color(0.45, 0.45, 0.48)
		var ps: float = rc.size.y / M.REPORT.get_height() * 0.62
		v.draw_set_transform(rc.position, 0, Vector2(ps, ps))
		v.draw_style_box(sleeve, Rect2(Vector2.ZERO, rc.size / ps))
		v.draw_set_transform(Vector2.ZERO)
		var ds: Dictionary = Themes.dspec(id)
		var cf: Dictionary = Themes.cfg(id, "normal")
		var dim := Color(0.28, 0.28, 0.32)
		# 背景の色合いの帯（D4 はステージの色）
		var bg: Color = ds.get("bg", Themes.THEMES[h.menu_theme].col)
		v.draw_rect(Rect2(rc.position + rc.size * Vector2(0.07, 0.12), rc.size * Vector2(0.86, 0.06)), Color(bg.r, bg.g, bg.b, 0.85) if open_ else dim)
		# ボス（左、大きく）
		var bc: Color = ds.get("boss_col", Color.WHITE)
		bc.a = 1.0
		foe(v, str(cf.boss), Rect2(rc.position + rc.size * Vector2(0.06, 0.22), rc.size * Vector2(0.42, 0.70)), bc if open_ else dim)
		# 番号（右上）
		SA.number(v, Rect2(rc.position + rc.size * Vector2(0.50, 0.20), rc.size * Vector2(0.44, 0.36)), "%d-%d" % [h.menu_theme + 1, i + 1], INK if open_ else Color(0.2, 0.2, 0.22), 44 * u)
		# 出る敵（右下、小さく）
		var fs: Array = cf.foes
		for j in mini(3, fs.size()):
			foe(v, str(fs[j]), Rect2(rc.position + rc.size * Vector2(0.50 + j * 0.15, 0.58), rc.size * Vector2(0.15, 0.32)), Color.WHITE if open_ else dim)
		if pr.cleared(id, "normal"):
			v.draw_arc(rc.end - Vector2(22, 22) * u, 10 * u, 0, TAU, 24, GOLD, 3 * u, true)
		if h.menu_dn == i + 1 and open_:
			v.draw_rect(rc.grow(-4 * u), Color(GOLD, 0.9), false, 2 * u)
			SA.halo(v, rc.position + Vector2(rc.size.x * 0.27, rc.size.y * 0.56), rc.size.y * 0.30, GOLD, 2)
		if not open_:
			SA.chained(v, Rect2(rc.get_center() - Vector2(22, 32) * u, Vector2(44, 64) * u))
	SA.close(v, r.close, u, true)
