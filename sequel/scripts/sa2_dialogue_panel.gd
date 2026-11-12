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

const Art := preload("res://scripts/t6_hud_art.gd")
var auto_enabled := false
var auto_wait := 0.0
var history: Array[String] = []
var log_panel: PanelContainer
var log_text: RichTextLabel
var skip_confirm: ConfirmationDialog
var auto_button: Button
var dialogue_font: Font
var lines: Array = []
var line_index: int = 0
var active: bool = false
var reveal_progress: float = 0.0

func _ready() -> void:
	var font := dialogue_font
	if font == null:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Noto Sans CJK JP", "Yu Gothic", "Hiragino Sans", "sans-serif"])
		font = system_font
	speaker.add_theme_font_override("font", font)
	body.add_theme_font_override("normal_font", font)
	advance_button.add_theme_font_override("font", font)
	_build_skin(font)
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
	history.clear()
	auto_enabled = false
	auto_button.text = "自動"
	active = true
	_duck_music(true)
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
	auto_wait = 0.0
	history.append(str(entry["speaker"]) + "\n" + str(entry["text"]))
	advance_button.text = "タップで全文表示 ›"
	_set_portrait(str(entry.get("portrait_id", "")))
	line_changed.emit(line_index, str(entry.get("line_id", "")))

func _process(delta: float) -> void:
	queue_redraw()
	if not active or log_panel.visible or skip_confirm.visible:
		return
	if body.visible_characters == -1:
		if auto_enabled:
			auto_wait += maxf(0.0, delta)
			if auto_wait >= maxf(1.5, body.get_total_character_count() * 0.06):
				advance()
		return
	reveal_progress += maxf(0.0, delta) * CHARS_PER_SECOND
	var count: int = body.get_total_character_count()
	if count <= 0:
		return
	if reveal_progress >= count:
		body.visible_characters = -1
		advance_button.text = "タップで終了 ›" if line_index == lines.size() - 1 else "タップで次へ ›"
	else:
		body.visible_characters = int(reveal_progress)

func advance() -> bool:
	if not active or log_panel.visible or skip_confirm.visible:
		return false
	if body.visible_characters != -1:
		body.visible_characters = -1
		advance_button.text = "タップで終了 ›" if line_index == lines.size() - 1 else "タップで次へ ›"
		return true
	if line_index < lines.size() - 1:
		line_index += 1
		_show_line()
		return true
	_close_dialogue()
	return true

func _unhandled_input(event: InputEvent) -> void:
	for options in get_tree().get_nodes_in_group("sound_options"):
		if options.panel.visible:
			return
	if not active or log_panel.visible or skip_confirm.visible:
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

func _close_dialogue() -> void:
	if not active:
		return
	active = false
	_duck_music(false)
	auto_enabled = false
	log_panel.hide()
	skip_confirm.hide()
	lines.clear()
	hide()
	set_process(false)
	dialogue_closed.emit()

func _build_skin(font: Font) -> void:
	var panel: PanelContainer = $Panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.04, 0.96)
	style.border_color = Color(0.65, 0.48, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	panel.draw.connect(func():
		for x in [9.0, panel.size.x - 9.0]:
			for y in [9.0, panel.size.y - 9.0]:
				panel.draw_circle(Vector2(x, y), 2, Color(0.85, 0.68, 0.38)))
	var name_style := style.duplicate() as StyleBoxFlat
	name_style.content_margin_left = 18
	name_style.content_margin_right = 18
	speaker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	speaker.add_theme_stylebox_override("normal", name_style)
	panel.offset_left = 64
	panel.offset_right = -64
	panel.offset_top = -220
	panel.offset_bottom = -32
	var padding: MarginContainer = $Panel/Padding
	padding.add_theme_constant_override("margin_left", 42)
	padding.add_theme_constant_override("margin_right", 30)
	padding.add_theme_constant_override("margin_top", 8)
	padding.add_theme_constant_override("margin_bottom", 8)
	body.custom_minimum_size = Vector2(0, 98)
	body.add_theme_font_size_override("normal_font_size", 27)
	body.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88))
	speaker.add_theme_font_size_override("font_size", 24)
	speaker.add_theme_color_override("font_color", Color(0.95, 0.83, 0.61))
	advance_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	advance_button.add_theme_font_size_override("font_size", 19)
	portrait.hide()
	var tools := HBoxContainer.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tools.position = Vector2(-378, 24)
	tools.add_theme_constant_override("separation", 12)
	add_child(tools)
	var log_button := _tool_button("ログ", font, style)
	tools.add_child(log_button)
	log_button.pressed.connect(open_log)
	auto_button = _tool_button("自動", font, style)
	tools.add_child(auto_button)
	auto_button.pressed.connect(func():
		auto_enabled = not auto_enabled
		auto_wait = 0.0
		auto_button.text = "自動 ●" if auto_enabled else "自動")
	var skip := _tool_button("スキップ", font, style)
	tools.add_child(skip)
	skip.pressed.connect(func(): skip_confirm.popup_centered(Vector2i(460, 160)))
	log_panel = PanelContainer.new()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_panel.offset_left = 64
	log_panel.offset_right = -64
	log_panel.offset_top = 90
	log_panel.offset_bottom = -48
	log_panel.add_theme_stylebox_override("panel", style)
	add_child(log_panel)
	var layout := VBoxContainer.new()
	log_panel.add_child(layout)
	var close := _tool_button("ログを閉じる", font, style)
	layout.add_child(close)
	close.pressed.connect(close_log)
	log_text = RichTextLabel.new()
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.custom_minimum_size.y = 250
	log_text.add_theme_font_override("normal_font", font)
	log_text.add_theme_font_size_override("normal_font_size", 25)
	log_text.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88))
	layout.add_child(log_text)
	log_panel.hide()
	skip_confirm = ConfirmationDialog.new()
	skip_confirm.title = "会話をスキップ"
	skip_confirm.dialog_text = "この会話を終了して先へ進みますか？"
	skip_confirm.ok_button_text = "スキップ"
	skip_confirm.cancel_button_text = "戻る"
	skip_confirm.add_theme_font_override("font", font)
	add_child(skip_confirm)
	skip_confirm.confirmed.connect(_close_dialogue)

func _tool_button(text: String, font: Font, style: StyleBoxFlat) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(104, 44)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", style)
	return button

func open_log() -> void:
	if not active:
		return
	log_text.text = "\n\n".join(history)
	log_panel.show()
	auto_wait = 0.0

func close_log() -> void:
	log_panel.hide()
	auto_wait = 0.0

func _draw() -> void:
	if not active:
		return
	var edge := Vector2(64, size.y - 220)
	Art.gear(self, edge + Vector2(10, 16), 19)
	# Decorative conduit only, separate from the combat ultimate gauge.
	var tube := Rect2(Vector2(size.x * 0.5 - 84, size.y - 33), Vector2(168, 7))
	draw_texture_rect(Art.TUBE, Rect2(Vector2(size.x * 0.5 - 120, size.y - 43), Vector2(240, 24)), false)
	draw_rect(tube.grow(1), Color(0.6, 0.44, 0.23))
	draw_rect(tube, Color(0.58, 0.16, 0.78))
	draw_line(tube.position + Vector2(4, 2), tube.end - Vector2(4, 5), Color(0.94, 0.63, 1), 2)

func _duck_music(enabled: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		# Runtime tests attach the gameplay root directly.
		for child in get_tree().root.get_children():
			if child.get("battle") != null: scene = child; break
	if scene != null and scene.get("battle") != null and scene.battle.combat_audio != null:
		scene.battle.combat_audio.set_dialogue_duck(enabled)
