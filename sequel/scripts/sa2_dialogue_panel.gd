extends Control
class_name SA2DialoguePanel

# Reusable view; accepts validated JSON Dictionary from SA2DialogueDatabase.
signal dialogue_closed
signal line_changed(line_index: int, line_id: String)

const CHARS_PER_SECOND := 28.0
@onready var body: RichTextLabel = $Panel/Padding/Layout/Content/Body
@onready var speaker: Label = $Panel/Padding/Layout/Speaker
@onready var portrait: TextureRect = $Panel/Padding/Layout/Content/Portrait
@onready var advance_button: Button = $Panel/Padding/Layout/Advance

var lines: Array = []
var line_index: int = 0
var active: bool = false
var reveal_progress: float = 0.0

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK JP", "Yu Gothic", "Hiragino Sans", "sans-serif"])
	speaker.add_theme_font_override("font", font)
	body.add_theme_font_override("normal_font", font)
	advance_button.add_theme_font_override("font", font)
	advance_button.pressed.connect(advance)
	hide()
	set_process(false)

func start(data: Dictionary, from_index: int = 0) -> bool:
	if active:
		return false
	var incoming: Variant = data.get("lines")
	if not incoming is Array or incoming.is_empty():
		return false
	if from_index < 0 or from_index >= incoming.size():
		return false
	for item in incoming:
		if not item is Dictionary or not item.get("speaker") is String or not item.get("text") is String or str(item.get("text")).is_empty():
			return false
	lines = (incoming as Array).duplicate(true)
	line_index = from_index
	active = true
	show()
	set_process(true)
	_show_line()
	return true

func _show_line() -> void:
	var entry: Dictionary = lines[line_index]
	speaker.text = entry["speaker"]
	body.text = entry["text"]
	body.visible_characters = 0
	reveal_progress = 0.0
	advance_button.text = "全文表示 ▷"
	_set_portrait(str(entry.get("portrait_id", "")))
	line_changed.emit(line_index, str(entry.get("line_id", "")))

func _process(delta: float) -> void:
	if not active or body.visible_characters == -1:
		return
	reveal_progress += maxf(0.0, delta) * CHARS_PER_SECOND
	var count: int = body.get_total_character_count()
	if count <= 0:
		return
	if reveal_progress >= count:
		body.visible_characters = -1
		advance_button.text = "閉じる ▷" if line_index == lines.size() - 1 else "次へ ▷"
	else:
		body.visible_characters = int(reveal_progress)

func advance() -> bool:
	if not active:
		return false
	if body.visible_characters != -1:
		body.visible_characters = -1
		advance_button.text = "閉じる ▷" if line_index == lines.size() - 1 else "次へ ▷"
		return true
	if line_index < lines.size() - 1:
		line_index += 1
		_show_line()
		return true
	active = false
	lines.clear()
	hide()
	set_process(false)
	dialogue_closed.emit()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if pressed:
		advance()
		get_viewport().set_input_as_handled()

func _set_portrait(id: String) -> void:
	portrait.visible = false
	portrait.texture = null
	if id.is_empty() or id.contains("/") or id.contains(".") or id.contains("\\"):
		return
	var path := "res://assets/dialogue/" + id + ".png"
	if ResourceLoader.exists(path, "Texture2D"):
		var texture: Resource = load(path)
		if texture is Texture2D:
			portrait.texture = texture
			portrait.visible = true
