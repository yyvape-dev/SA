extends CanvasLayer
## 読み込み中の表示：暗転＋小さな回る印（文字は出さない）。いちばん上の層。
var _t := 0.0
var _a := 1.0
var _hiding := false
var _rect: ColorRect
var _spin: Control

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0.02, 0.015, 0.04, 1.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)
	_spin = Control.new()
	_spin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin.draw.connect(_draw_spin)
	add_child(_spin)

func show_now() -> void:
	_hiding = false
	_a = 1.0
	visible = true
	_apply()

func hide_soon() -> void:
	_hiding = true

func _process(delta: float) -> void:
	_t += delta
	if _hiding:
		_a = maxf(0.0, _a - delta / 0.3)
		if _a <= 0.0:
			visible = false
	_apply()
	_spin.queue_redraw()

func _apply() -> void:
	_rect.color.a = _a
	_spin.modulate.a = _a

func _draw_spin() -> void:
	var sz := _spin.size
	var c := Vector2(sz.x - 44.0, sz.y - 44.0)   # 右下の小さな印
	var a0 := _t * 5.0
	_spin.draw_arc(c, 13.0, a0, a0 + 4.2, 32, Color(0.85, 0.62, 0.95, 0.9), 3.0, true)
