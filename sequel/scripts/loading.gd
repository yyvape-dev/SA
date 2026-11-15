extends CanvasLayer
## Shared expedition loading screen. Progress is the actual district download ratio.
const SelectArt = preload("res://scripts/dungeon_select_art.gd")
var _t := 0.0
var _a := 1.0
var _hiding := false
var _rect: ColorRect
var _spin: Control
var error_text := ""
var _err: Label
var _progress := -1.0
var _connected := false
var _theme := -1
var _difficulty := 0
var _chosen: Array = []

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
 _bind_progress()
 _hiding = false
 _a = 1.0
 _t = 0.0
 _progress = -1.0
 _theme = -1
 _difficulty = 0
 _chosen = []
 var m = get_parent()
 var town_transition: bool = m != null and "town_floor_busy" in m and m.town_floor_busy
 if not town_transition and m != null and "hud" in m and m.hud != null and m.hud.menu_stage in ["diff", "party"]:
  _theme = m.hud.menu_theme
  _difficulty = m.hud.menu_sel
  _chosen = m.hud.pick.duplicate()
 visible = true
 _apply()

func hide_soon() -> void:
 _hiding = true

func _process(delta: float) -> void:
 _t += delta
 _bind_progress()
 if error_text != "" and _err == null:
  _err = Label.new()
  _err.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
  _err.add_theme_font_size_override("font_size", 22)
  var cl := CanvasLayer.new()
  cl.layer = 101
  get_parent().add_child(cl)
  cl.add_child(_err)
  _err.position = Vector2(8, 4)
 if is_instance_valid(_err):
  # Keep raw diagnostic available to the caller; display numbers/symbols only.
  var digits := "!  "
  for ch in error_text:
   if ch in "0123456789 -:./":digits += ch
  _err.text = digits
  _err.visible = error_text != ""
 if _hiding:
  _a = maxf(0.0, _a - delta / 0.3)
  if _a <= 0.0:visible = false
 _apply()
 _spin.queue_redraw()

func _bind_progress() -> void:
 var m = get_parent()
 if not _connected and m != null and "district" in m and m.district != null:
  m.district.progress.connect(func(ratio: float): _progress = clampf(ratio, 0.0, 1.0))
  m.district.download_started.connect(func(): _progress = -1.0)
  _connected = true

func _apply() -> void:
 _rect.color.a = _a
 _spin.modulate.a = _a

func _draw_spin() -> void:
 var sz := _spin.size
 if sz.x < 1:return
 SelectArt.loading(_spin,sz,_theme,_difficulty,_chosen,_t,_progress)
