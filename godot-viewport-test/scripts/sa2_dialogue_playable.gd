extends Node3D

# Playable 2.5D scene: NPC proximity and state orchestration only.
# Narrative text and presentation live in JSON and a reusable Control scene.
const Flow = preload("res://scripts/sa2_flow_state.gd")
const Database = preload("res://scripts/sa2_dialogue_database.gd")
const DialogueView = preload("res://ui/sa2_dialogue_panel.tscn")
const Stage = preload("res://greybox_city.tscn")
const EVENT_ID := "C1-06"
const TALK_RADIUS := 3.2
const SAVE_PATH := "user://sa2_t1_5_dialogue.json"

var flow = Flow.new()
var database = Database.new()
var stage: Node3D
var npc: Node3D
var hud: CanvasLayer
var hint: Label
var dialogue_ui: Control
var demo: bool = false
var japanese_font: SystemFont

func _ready() -> void:
	demo = OS.has_environment("SA2_DIALOGUE_MOVIE")
	if not demo:
		flow.load_from(SAVE_PATH)
	stage = Stage.instantiate()
	add_child(stage)
	if not demo and flow.event_id != "":
		stage.player.global_position = flow.player_position
	else:
		stage.player.global_position = Vector3(-17.5, 0.04, 0.8)
	stage.cam.global_position = Vector3(stage.player.global_position.x, 6.8, 18.0)
	_build_npc()
	_build_hud()
	if flow.mode == Flow.DIALOGUE:
		var data: Dictionary = database.load_event(flow.event_id)
		if data.is_empty() or not dialogue_ui.start(data, flow.dialogue_line_index):
			push_error("Could not resume saved dialogue; preserving save for recovery: " + database.last_error)
			# Recover exploration on screen, without overwriting the saved file.
			flow = Flow.new()
	_update_view()
	if demo:
		call_deferred("_run_demo")

func _build_npc() -> void:
	npc = Node3D.new()
	npc.name = "Conversation NPC (temporary marker)"
	npc.position = Vector3(-11.0, 0, -0.25)
	add_child(npc)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.58, 0.57)
	var torso := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.36
	cylinder.bottom_radius = 0.48
	cylinder.height = 1.8
	torso.mesh = cylinder
	torso.position.y = 1.0
	torso.material_override = material
	npc.add_child(torso)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	head.mesh = sphere
	head.position.y = 2.18
	head.material_override = material
	npc.add_child(head)

func _build_hud() -> void:
	japanese_font = SystemFont.new()
	japanese_font.font_names = PackedStringArray(["Noto Sans CJK JP", "Yu Gothic", "Hiragino Sans", "sans-serif"])
	hud = CanvasLayer.new()
	add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(32, 28)
	hud.add_child(top)
	var column := VBoxContainer.new()
	top.add_child(column)
	var header := Label.new()
	header.text = "SA2 / 探索・会話UI  試作"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_font_override("font", japanese_font)
	column.add_child(header)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_font_override("font", japanese_font)
	column.add_child(hint)
	dialogue_ui = DialogueView.instantiate()
	hud.add_child(dialogue_ui)
	dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)
	dialogue_ui.line_changed.connect(_on_line_changed)

func _process(_delta: float) -> void:
	if flow.mode == Flow.EXPLORE:
		flow.set_explore_position(stage.player.global_position)
	_update_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if flow.mode == Flow.EXPLORE:
			_try_talk()
		get_viewport().set_input_as_handled()

func _near_npc() -> bool:
	var p: Vector3 = stage.player.global_position
	var n: Vector3 = npc.global_position
	return Vector2(p.x, p.z).distance_to(Vector2(n.x, n.z)) <= TALK_RADIUS

func _try_talk() -> void:
	if not _near_npc() or flow.mode != Flow.EXPLORE:
		return
	var data: Dictionary = database.load_event(EVENT_ID)
	if data.is_empty():
		push_error("Dialogue file invalid: " + database.last_error)
		return
	if not flow.begin_dialogue(EVENT_ID, stage.player.global_position):
		return
	if not dialogue_ui.start(data):
		# Never trap the player if the UI cannot start.
		flow.finish_dialogue()
		return
	flow.save_to(SAVE_PATH)
	_update_view()

func _on_line_changed(index: int, _line_id: String) -> void:
	if flow.mode == Flow.DIALOGUE:
		flow.set_dialogue_line_index(index)
		flow.save_to(SAVE_PATH)

func _on_dialogue_closed() -> void:
	if flow.finish_dialogue():
		flow.save_to(SAVE_PATH)
	_update_view()

func _update_view() -> void:
	if stage != null:
		stage.set_physics_process(flow.mode == Flow.EXPLORE)
	if hint == null:
		return
	if flow.mode == Flow.DIALOGUE:
		hint.text = "会話中：移動停止"
	elif _near_npc():
		hint.text = "WASD / 方向キー：移動   E：話す"
	else:
		hint.text = "WASD / 方向キー：移動   案内係に近づいて E"

func _run_demo() -> void:
	await _frames(40)
	var start_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(48)
	Input.action_release("ui_right")
	assert(stage.player.global_position.x > start_x + 1.0, "approach failed")
	assert(_near_npc(), "NPC not in talk range")
	await _frames(22)
	_try_talk()
	assert(flow.mode == Flow.DIALOGUE and dialogue_ui.active)
	assert(dialogue_ui.body.visible_characters == 0, "typing must begin at zero")
	var frozen_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(24)
	Input.action_release("ui_right")
	assert(absf(stage.player.global_position.x - frozen_x) < 0.02, "movement lock failed")
	await _frames(12)
	assert(dialogue_ui.body.visible_characters > 0, "typewriter did not progress")
	dialogue_ui.advance() # fast-forward text
	assert(dialogue_ui.line_index == 0 and dialogue_ui.body.visible_characters == -1)
	await _frames(35)
	dialogue_ui.advance() # line 2
	assert(dialogue_ui.line_index == 1 and flow.dialogue_line_index == 1)
	await _frames(42)
	dialogue_ui.advance() # complete text if still typing
	if dialogue_ui.line_index == 1:
		dialogue_ui.advance()
	assert(dialogue_ui.line_index == 2)
	await _frames(35)
	dialogue_ui.advance()
	if dialogue_ui.active:
		dialogue_ui.advance()
	assert(flow.mode == Flow.EXPLORE, "failed to return to exploration")
	await _frames(30)
	var resume_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(36)
	Input.action_release("ui_right")
	assert(stage.player.global_position.x > resume_x + 0.4, "movement did not resume")
	print("SA2_DIALOGUE_DEMO_PASS: JSON, NPC proximity, typing, reveal, 3 lines, movement lock, save, close, resume")
	await _frames(24)
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
