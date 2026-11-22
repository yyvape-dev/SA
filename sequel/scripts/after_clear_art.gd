extends RefCounted

const ROOT := "res://assets/after_clear/"
static var textures: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not textures.has(id):
		var path := ROOT + id + ".png"
		textures[id] = load(path) if ResourceLoader.exists(path) else null
	return textures[id] as Texture2D

static func draw_art(c: CanvasItem, id: String, area: Rect2, tint := Color.WHITE) -> bool:
	var art := texture(id)
	if art == null:
		return false
	var dimensions := art.get_size()
	var fitted := dimensions * minf(area.size.x / dimensions.x, area.size.y / dimensions.y)
	c.draw_texture_rect(art, Rect2(area.get_center() - fitted * 0.5, fitted), false, tint)
	return true

static func draw_panel(c: CanvasItem, area: Rect2, border: float) -> void:
	c.draw_rect(area, Color("101521"))
	var art := texture("panel")
	if art == null:
		c.draw_rect(area, Color("af8e54"), false, 2.0)
		return
	var source: Vector2 = art.get_size()
	var slice := minf(source.y * 0.24, source.x * 0.24)
	var inset := minf(border, minf(area.size.x, area.size.y) * 0.24)
	var sx := [0.0, slice, source.x - slice, source.x]
	var sy := [0.0, slice, source.y - slice, source.y]
	var dx := [0.0, inset, area.size.x - inset, area.size.x]
	var dy := [0.0, inset, area.size.y - inset, area.size.y]
	for y in 3:
		for x in 3:
			var src := Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y])
			var dst := Rect2(area.position + Vector2(dx[x], dy[y]), Vector2(dx[x + 1] - dx[x], dy[y + 1] - dy[y]))
			c.draw_texture_rect_region(art, dst, src)
