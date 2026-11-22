extends Node3D
## Independent review scene. Production main scene, battle and district loading are untouched.
const State := preload("res://scripts/sa2_prologue_state.gd")
const Room := preload("res://scripts/sa2_prologue_room.gd")
const Dialogue := preload("res://ui/sa2_dialogue_panel.tscn")
const FONT := preload("res://assets/event_idle/sa2_prologue_ja.otf")
@export var auto_load := true
var save_path := State.SAVE_PATH
var state = State.new()
var room
var dialogue
var paper: PanelContainer
var time_title: Label
var time_scrim: ColorRect
var action: Button
var objective: Label
var status: Label
var movement := Vector2.ZERO
var touch_axis := Vector2.ZERO
var pad_finger := -1
var pad_origin := Vector2.ZERO
var dialogue_beat := ""
var fade: ColorRect
var fade_tween: Tween
var autosave_wait := 0.0

func _ready() -> void:
	room = Room.new()
	room.font = FONT
	add_child(room)
	_build_ui()
	if auto_load and FileAccess.file_exists(save_path) and not state.load_from(save_path):
		status.text = "保存を読み込めませんでした。冒頭から開始します。"
	present()

func _button(text: String, at: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 23)
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	objective = Label.new()
	objective.position = Vector2(32, 24)
	objective.add_theme_font_override("font", FONT)
	objective.add_theme_font_size_override("font_size", 26)
	ui.add_child(objective)
	status = Label.new()
	status.position = Vector2(32, 64)
	status.add_theme_font_override("font", FONT)
	status.add_theme_font_size_override("font_size", 17)
	status.text = "プロローグ・提供原画を使用"
	ui.add_child(status)
	action = _button("", Vector2(-240, -112), Vector2(208, 72))
	action.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ui.add_child(action)
	action.pressed.connect(perform_action)
	var pad := HBoxContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.position = Vector2(32, -110)
	ui.add_child(pad)
	for direction in [-1, 1]:
		var button := _button("◀" if direction < 0 else "▶", Vector2.ZERO, Vector2(80, 70))
		button.custom_minimum_size = Vector2(80, 70)
		pad.add_child(button)
		button.button_down.connect(func(): movement.x = direction)
		button.button_up.connect(func(): movement.x = 0)
	pad.name = "MovePad"
	var restart := _button("最初から", Vector2(-180, 88), Vector2(148, 44))
	restart.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ui.add_child(restart)
	var confirm := ConfirmationDialog.new()
	confirm.title = "プロローグを最初から"
	confirm.dialog_text = "プロローグの進行をリセットしますか？"
	confirm.ok_button_text = "最初から"
	confirm.cancel_button_text = "戻る"
	confirm.add_theme_font_override("font", FONT)
	ui.add_child(confirm)
	restart.pressed.connect(func(): confirm.popup_centered(Vector2i(470, 160)))
	confirm.confirmed.connect(func():
		movement = Vector2.ZERO
		touch_axis = Vector2.ZERO
		state = State.new()
		_replace_dialogue()
		save_progress()
		present())
	confirm.visibility_changed.connect(func():
		if confirm.visible:
			movement = Vector2.ZERO
			touch_axis = Vector2.ZERO
		set_process(not confirm.visible)
		if is_instance_valid(dialogue) and dialogue.active:
			dialogue.set_process(not confirm.visible))
	paper = PanelContainer.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.position = Vector2(-330, -160)
	paper.custom_minimum_size = Vector2(660, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ded0ad")
	style.set_content_margin_all(45)
	paper.add_theme_stylebox_override("panel", style)
	ui.add_child(paper)
	var text := Label.new()
	text.text = str(State.DB.new().load_event("P0-04").lines[0].text)
	text.add_theme_font_override("font", FONT)
	text.add_theme_font_size_override("font_size", 34)
	text.add_theme_color_override("font_color", Color("302b26"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paper.add_child(text)
	time_scrim = ColorRect.new()
	time_scrim.color = Color(0, 0, 0, 0.95)
	time_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(time_scrim)
	ui.move_child(time_scrim, 0)
	time_title = Label.new()
	time_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	time_title.position = Vector2(-380, -180)
	time_title.size = Vector2(760, 260)
	time_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_title.add_theme_font_override("font", FONT)
	time_title.add_theme_font_size_override("font_size", 44)
	ui.add_child(time_title)
	_replace_dialogue()
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)

func _replace_dialogue() -> void:
	if is_instance_valid(dialogue):
		dialogue.dialogue_closed.disconnect(_dialogue_closed)
		dialogue.queue_free()
	dialogue = Dialogue.instantiate()
	dialogue.dialogue_font = FONT
	get_child(1).get_child(0).add_child(dialogue)
	dialogue.dialogue_closed.connect(_dialogue_closed)
	dialogue.line_changed.connect(func(_index: int, id: String):
		if state.set_line(id): save_progress())

func present() -> void:
	var old_room: String = room.room_id
	room.apply(state)
	if old_room != room.room_id and old_room != "" and is_instance_valid(fade):
		# Save only the settled target. Reopening during fade restores this configuration.
		if fade_tween: fade_tween.kill()
		fade.color.a = 1.0
		fade_tween = create_tween()
		fade_tween.tween_property(fade, "color:a", 0.0, 0.4)
	paper.visible = state.beat_id == "note"
	time_title.visible = state.beat_id in ["three_days", "ending"]
	time_scrim.visible = time_title.visible
	time_title.text = "三日後" if state.beat_id == "three_days" else "第一章\n黄金の帝都"
	objective.text = {"office": "序章　失踪 ─ 朝の執務室", "guest": "序章　失踪 ─ ランカの客室", "audience": "序章　失踪 ─ 海の向こうから"}[state.scene_id()]
	get_child(1).get_child(0).get_node("MovePad").visible = state.can_move()
	action.visible = not state.EVENTS.has(state.beat_id) and not state.is_complete()
	action.text = {"talk_lily": "話す", "guest_door": "客室へ", "find_note": "調べる", "note": "紙を置く", "three_days": "続ける"}.get(state.beat_id, "")
	_update_action()
	var data: Dictionary = state.dialogue()
	if not data.is_empty():
		dialogue_beat = state.beat_id
		var index := 0
		for i in range(data.lines.size()):
			if data.lines[i].line_id == state.line_id: index = i
		dialogue.start(data, index)
	else:
		dialogue_beat = ""
	movement = Vector2.ZERO
	touch_axis = Vector2.ZERO
	pad_finger = -1

func _dialogue_closed() -> void:
	if dialogue_beat != state.beat_id or dialogue.active: return
	dialogue_beat = ""
	if state.finish_dialogue():
		save_progress()
		present()

func _update_action() -> void:
	action.disabled = state.TARGETS.has(state.beat_id) and state.player.distance_to(state.TARGETS[state.beat_id]) > 1.0

func perform_action() -> bool:
	if dialogue.active: return false
	var next_action: String = state.ACTIONS.get(state.beat_id, "")
	if next_action.is_empty() or not state.interact(next_action): return false
	save_progress()
	present()
	return true

func move_player(axis: Vector2, delta: float) -> void:
	if dialogue.active or not state.can_move(): return
	if state.move_to(state.player.x + axis.x * 2.8 * delta, state.player.y + axis.y * 1.2 * delta):
		room.actors.rana.position = Vector3(state.player.x, 0.02, state.player.y)
		if absf(axis.x) > 0.01: room.actors.rana.flip_h = axis.x < 0
		_update_action()

func _process(delta: float) -> void:
	if state.can_move():
		var axis := movement + touch_axis
		axis.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		axis.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		move_player(axis.limit_length(1), delta)
		autosave_wait += delta
		if autosave_wait >= 0.5:
			autosave_wait = 0
			save_progress()

func _unhandled_input(event: InputEvent) -> void:
	if dialogue.active or not is_processing(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
		perform_action()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and pad_finger == -1 and state.can_move():
			pad_finger = event.index
			pad_origin = event.position
		elif not event.pressed and event.index == pad_finger:
			pad_finger = -1
			touch_axis = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == pad_finger:
		touch_axis = ((event.position - pad_origin) / 70.0).limit_length(1)

func save_progress() -> bool:
	var ok: bool = state.save_to(save_path)
	if not ok and is_instance_valid(status): status.text = "進行を保存できません。このまま続けられます。"
	return ok

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		movement = Vector2.ZERO
		touch_axis = Vector2.ZERO
		save_progress()
