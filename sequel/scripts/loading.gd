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
 var m = get_parent()
 if m != null and "hud" in m and m.hud != null:
  _theme = m.hud.menu_theme
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
 var u := sz.y / 720.0
 SelectArt.background(_spin, sz, Color(0.27, 0.32, 0.42))
 _spin.draw_rect(Rect2(Vector2.ZERO,sz),Color(0.005,0.012,0.025,0.36))
 var c := sz * Vector2(0.5,0.43)
 if _theme >= 0:
  SelectArt.fit(_spin,SelectArt.NODES[_theme],Rect2(c-Vector2(150,150)*u,Vector2(300,300)*u))
 else:SelectArt.gate(_spin,c,85*u)
 var rc := c + Vector2(0,186)*u
 _spin.draw_arc(rc,21*u,0,TAU,48,Color(SelectArt.BRASS,0.28),2*u,true)
 _spin.draw_arc(rc,21*u,_t*2,_t*2+4.1,36,SelectArt.GOLD,3*u,true)
 SelectArt.diamond(_spin,rc,7*u,SelectArt.GOLD)
 var bar := Rect2(Vector2(sz.x*0.5-180*u,sz.y*0.83),Vector2(360,5)*u)
 _spin.draw_rect(bar,Color(1,1,1,0.1))
 if _progress>=0:
  _spin.draw_rect(Rect2(bar.position,Vector2(bar.size.x*_progress,bar.size.y)),SelectArt.GOLD)
  _spin.draw_string(ThemeDB.fallback_font,bar.end+Vector2(18,5)*u,str(int(_progress*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,int(20*u),SelectArt.GOLD)
 else:
  var fraction := fmod(_t*0.32,1.0)
  _spin.draw_rect(Rect2(bar.position+Vector2(bar.size.x*fraction*0.78,0),Vector2(bar.size.x*0.22,bar.size.y)),Color(SelectArt.GOLD,0.65))
