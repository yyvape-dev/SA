extends RefCounted
## Approved T6 skin. Frames, interchangeable icons and live gauge contents are separate.
const FONT := preload("res://assets/event_idle/sa2_t6_ja.otf")
const HEADER := preload("res://assets/ui/t6/t6_header_frame.png")
const TUBE := preload("res://assets/ui/t6/t6_tube_frame.png")
const RING := preload("res://assets/ui/t6/t6_ring.png")
const LILY := preload("res://assets/ui/t6/t6_portrait.png")
const RANA := preload("res://assets/ui/t6/t6_rana_portrait.png")
const RANKA := preload("res://assets/ui/t6/t6_ranka_portrait.png")   # 2026-11-12：会話用の立ち絵の顔を丸く切ったもの（tools/make_ranka_ui.py）
const FIST := preload("res://assets/ui/t6/t6_fist.png")
const DODGE := preload("res://assets/ui/t6/t6_dodge.png")
const ICONS := {
    "rush": preload("res://assets/ui/t6/t6_rush.png"),
    "barrage": preload("res://assets/ui/t6/t6_barrage.png"),
    "storm": preload("res://assets/ui/t6/t6_storm.png"),
}
const BRASS := Color(0.62, 0.47, 0.27, 0.75)
const IRON := Color(0.025, 0.035, 0.05, 0.82)
const QUIET := Color(1, 1, 1, 0.38)

static func gear(canvas: CanvasItem, center: Vector2, radius: float, alpha: float = 1.0) -> void:
    canvas.draw_circle(center, radius * 0.77, Color(0.06, 0.05, 0.04, 0.9 * alpha))
    for tooth in 12:
        var angle := float(tooth) * TAU / 12.0
        var direction := Vector2(cos(angle), sin(angle))
        canvas.draw_line(center + direction * radius * 0.73, center + direction * radius, Color(BRASS, BRASS.a * alpha), radius * 0.18, true)
    canvas.draw_arc(center, radius * 0.7, 0, TAU, 40, Color(BRASS, BRASS.a * alpha), radius * 0.13, true)
    canvas.draw_circle(center, radius * 0.28, Color(0.08, 0.09, 0.1, alpha))

static func panel(canvas: CanvasItem, rect: Rect2) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = IRON
    style.border_color = BRASS
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    canvas.draw_style_box(style, rect)
    for x in [rect.position.x + 7, rect.end.x - 7]:
        for y in [rect.position.y + 7, rect.end.y - 7]:
            canvas.draw_circle(Vector2(x, y), 2, BRASS)

static func icon(canvas: CanvasItem, texture: Texture2D, center: Vector2, extent: float, color: Color) -> void:
    var dimensions := texture.get_size()
    var scale := extent / maxf(dimensions.x, dimensions.y)
    var size := dimensions * scale
    canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, color)

static func button(canvas: CanvasItem, center: Vector2, radius: float, pressed: bool, ultimate: bool = false, action: bool = false) -> void:
    var opacity := (0.9 if pressed else 0.65) if action else (0.7 if pressed else 0.38)
    canvas.draw_circle(center, radius * 0.85, Color(0.02, 0.03, 0.05, (0.55 if pressed else 0.28) if action else (0.23 if pressed else 0.12)))
    if ultimate:
        var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
        canvas.draw_colored_polygon(points, Color(0.05, 0.02, 0.08, 0.28))
        canvas.draw_polyline(points, Color(BRASS, 0.65), 3, true)
        canvas.draw_arc(center, radius * 0.7, 0, TAU, 48, Color(0.75, 0.26, 0.88, 0.35), 2, true)
        var bolt := PackedVector2Array([center + Vector2(0.18, -0.55) * radius, center + Vector2(-0.25, 0.03) * radius, center + Vector2(0.11, 0.03) * radius, center + Vector2(-0.18, 0.55) * radius])
        canvas.draw_polyline(bolt, Color(0.89, 0.59, 1, 0.8), radius * 0.08, true)
        return
    canvas.draw_texture_rect(RING, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(1, 1, 1, opacity))

static func gauges(canvas: CanvasItem, ui, unit: float, shown_hp: float) -> void:
    var u := unit
    if ui.lily_controls:
        panel(canvas, Rect2(Vector2(canvas.get_viewport_rect().size.x * 0.5 - 160 * u, 14 * u), Vector2(320, 48) * u))
    var portrait := Vector2(55, 48) * u
    panel(canvas, Rect2(Vector2(30, 15) * u, Vector2(440, 64) * u))
    canvas.draw_circle(portrait, 39 * u, Color(0.04, 0.04, 0.06, 0.94))
    gear(canvas, portrait, 42 * u, 0.8)
    var manual_id := str(ui.player.actor.actor_id) if ui.lily_controls and ui.player != null and "actor" in ui.player and ui.player.actor != null else "lily"
    icon(canvas, (RANKA if manual_id == "ranka" else LILY) if ui.lily_controls else RANA, portrait, 75 * u, Color.WHITE)
    var font: Font = FONT
    var name := ("ランカ" if manual_id == "ranka" else "リリィ") if ui.lily_controls else "ラナ"
    canvas.draw_string(font, Vector2(104, 37) * u, name, HORIZONTAL_ALIGNMENT_LEFT, 180 * u, int(22 * u), Color(0.91, 0.88, 0.78))
    var hp_text := "%d / %d" % [int(ui.battle.hp), int(ui.battle.hp_max)]
    canvas.draw_string(ThemeDB.fallback_font, Vector2(265, 37) * u, hp_text, HORIZONTAL_ALIGNMENT_RIGHT, 185 * u, int(19 * u), Color(0.91, 0.92, 0.93))
    var hp := Rect2(Vector2(103, 50) * u, Vector2(347, 16) * u)
    canvas.draw_rect(hp.grow(3 * u), Color(0.015, 0.02, 0.025, 0.9))
    canvas.draw_rect(Rect2(hp.position, Vector2(hp.size.x * shown_hp, hp.size.y)), Color(0.7, 0.76, 0.77, 0.55))
    var fraction := clampf(float(ui.battle.hp) / float(ui.battle.hp_max), 0.0, 1.0)
    canvas.draw_rect(Rect2(hp.position, Vector2(hp.size.x * fraction, hp.size.y)), Color(0.12, 0.72, 0.77, 0.95))
    canvas.draw_rect(Rect2(hp.position, Vector2(hp.size.x * fraction, 4 * u)), Color(0.71, 0.96, 0.97, 0.7))
    canvas.draw_rect(hp.grow(2 * u), BRASS, false, u)
    canvas.draw_texture_rect(HEADER, Rect2(Vector2(9, 8) * u, Vector2(465, 75) * u), false)
    if ui.basic_combat_only:
        return
    var tube := Rect2(Vector2(99, 96) * u, Vector2(332, 14) * u)
    liquid(canvas, tube, ui.ult_value() / ui.battle.ULT_MAX, u)
    canvas.draw_texture_rect(TUBE, Rect2(Vector2(24, 78) * u, Vector2(448, 44) * u), false)
    if ui.battle.ally and not ui.lily_controls:
        liquid(canvas, Rect2(Vector2(103, 118) * u, Vector2(240, 8) * u), ui.battle.ally_ult / ui.battle.ULT_MAX, u * 0.65)
    if ui.battle.ranka and ui.battle.ranka != ui.battle.player and not ui.lily_controls:   # ランカのゲージ（リリィの下）
        liquid(canvas, Rect2(Vector2(103, 134) * u, Vector2(240, 8) * u), ui.battle.ranka_ult / ui.battle.ULT_MAX, u * 0.65)

static func liquid(canvas: CanvasItem, rect: Rect2, fraction: float, u: float) -> void:
    canvas.draw_rect(rect.grow(5 * u), Color(0.025, 0.02, 0.04, 0.8))
    canvas.draw_rect(rect.grow(3 * u), BRASS, false, 2 * u)
    canvas.draw_rect(rect, Color(0.07, 0.025, 0.1, 0.86))
    var width := rect.size.x * clampf(fraction, 0.0, 1.0)
    if width > 0:
        canvas.draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), Color(0.52, 0.07, 0.68, 0.86))
        canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.32), rect.position + Vector2(width, rect.size.y * 0.32), Color(0.95, 0.43, 1, 0.85), 2 * u, true)
        var time := float(Time.get_ticks_msec()) * 0.001
        for bubble in 9:
            var x := fmod(float(bubble) * 43.7 + time * 11.0, maxf(width, 1))
            var y := rect.size.y * (0.55 + sin(time * 1.6 + float(bubble)) * 0.22)
            canvas.draw_circle(rect.position + Vector2(x, y), 0.8 * u, Color(1, 0.72, 1, 0.55))
    canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.9, 0.87, 1, 0.5), u)
    var midpoint := rect.position + Vector2(rect.size.x * 0.5, 0)
    canvas.draw_line(midpoint - Vector2(0, 6 * u), midpoint + Vector2(0, rect.size.y + 6 * u), Color(0.08, 0.06, 0.09, 0.95), 5 * u)
    canvas.draw_line(midpoint - Vector2(0, 5 * u), midpoint + Vector2(0, rect.size.y + 5 * u), Color(0.77, 0.61, 0.35, 0.95), 2 * u)
