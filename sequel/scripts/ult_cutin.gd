extends CanvasLayer
## 必殺技のカットイン（2026-11-07）：画面を暗く → 金の斜めの帯 → 立ち絵（元の大きさ 850×1472 を縮めずに読み、画面の高さに合わせて表示）が左から差し込む → 抜ける。
## 決めの瞬間に白い閃光。時間は play() からの実時間（止め・演出の間も進む）。
var player
## 立ち絵と色（リリィは蒼。2026-11-07）
var tex_path := "res://assets/rana2/cutin.webp"
var band_col := Color(0.16, 0.1, 0.02, 0.85)
var line_col := Color(1.0, 0.8, 0.35, 0.95)
var streak_col := Color(1.0, 0.9, 0.6, 0.35)
var flash_col := Color(1, 0.97, 0.88)
var t := -1.0
var white := 0.0
var tex: Texture2D
var view: Control

func _ready() -> void:
	layer = 4
	tex = load(tex_path) if ResourceLoader.exists(tex_path) else null
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)

func play() -> void:
	t = 0.0

func flash_white() -> void:
	white = 1.0

func _process(delta: float) -> void:
	if t >= 0.0:
		t += delta
		if t > 1.2:
			t = -1.0
	white = maxf(0.0, white - delta * 3.0)
	view.queue_redraw()

func _draw_view() -> void:
	var sz := view.size
	if t >= 0.0:
		# 暗転（0〜0.2 で濃く、1.0〜1.2 で戻る）
		var dark := clampf(t / 0.2, 0.0, 1.0) * clampf((1.2 - t) / 0.2, 0.0, 1.0)
		view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.01, 0.05, 0.6 * dark))
		# 金の斜めの帯（画面を横切る）
		var bt := clampf((t - 0.2) / 0.12, 0.0, 1.0) * clampf((1.1 - t) / 0.15, 0.0, 1.0)
		if bt > 0.0:
			var h := sz.y * 0.42
			var cy := sz.y * 0.55
			var sk := sz.y * 0.18
			var pts := PackedVector2Array([Vector2(0, cy - h * 0.5 + sk), Vector2(sz.x * bt, cy - h * 0.5 - sk * bt), Vector2(sz.x * bt, cy + h * 0.5 - sk * bt), Vector2(0, cy + h * 0.5 + sk)])
			view.draw_colored_polygon(pts, band_col)
			view.draw_polyline(PackedVector2Array([pts[0], pts[1]]), line_col, 4.0)
			view.draw_polyline(PackedVector2Array([pts[3], pts[2]]), line_col, 4.0)
			for i in 6:   # 流れる光の筋
				var y := cy - h * 0.4 + i * h * 0.16
				var x0 := fmod(t * 2600.0 + i * 377.0, sz.x + 400.0) - 400.0
				view.draw_line(Vector2(x0, y), Vector2(x0 + 260.0, y - sk * 0.25), streak_col, 3.0)
		# 立ち絵：左から差し込み（0.25〜0.45）、少し流れて（〜0.95）、右へ抜ける（0.95〜1.1）
		if tex and t > 0.22 and t < 1.12:
			var dh := sz.y * 1.05
			var dw := dh * float(tex.get_width()) / float(tex.get_height())
			var x_in := clampf((t - 0.22) / 0.2, 0.0, 1.0)
			x_in = 1.0 - pow(1.0 - x_in, 3.0)
			var x := lerpf(-dw, sz.x * 0.08, x_in) + (t - 0.42) * 60.0
			if t > 0.95:
				x += pow((t - 0.95) / 0.15, 2.0) * sz.x
			var a := clampf((1.12 - t) / 0.1, 0.0, 1.0)
			view.draw_texture_rect(tex, Rect2(Vector2(x, sz.y * 0.0 - sz.y * 0.02), Vector2(dw, dh)), false, Color(1, 1, 1, a))
	if white > 0.0:
		view.draw_rect(Rect2(Vector2.ZERO, sz), Color(flash_col.r, flash_col.g, flash_col.b, 0.7 * white))
