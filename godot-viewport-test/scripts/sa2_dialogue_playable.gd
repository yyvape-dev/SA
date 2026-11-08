extends Node3D

# T1 playable dialogue: actual proximity interaction, text advance, movement lock and return.
# Scripted lines are temporary non-story placeholders; no spoilers or canonical dialogue.
const Flow = preload("res://scripts/sa2_flow_state.gd")
const Stage = preload("res://greybox_city.tscn")
const TALK_RADIUS := 3.2
const LINES := [
	["案内係", "こちらは演習区画です。\n準備ができたら、先へ進んでください。"],
	["リリィ", "わかりました。周囲を確認してから向かいます。"],
	["案内係", "お気をつけて。"]
]
var flow = Flow.new()
var stage: Node3D
var npc: Node3D
var talk_index := 0
var hud: CanvasLayer
var hint: Label
var dialogue_panel: PanelContainer
var speaker: Label
var dialogue_text: Label
var advance_button: Button
var demonstration := false

func _ready() -> void:
	stage = Stage.instantiate()
	add_child(stage)
	stage.player.global_position = Vector3(-17.5, 0.04, 0.8)
	stage.cam.global_position = Vector3(-17.5, 6.8, 18.0)
	_build_npc()
	_build_hud()
	_update_view()
	demonstration = OS.has_environment("SA2_DIALOGUE_MOVIE")
	if demonstration:
		call_deferred("_run_demo")

func _build_npc() -> void:
	npc = Node3D.new()
	npc.name = "Conversation NPC (temporary 3D marker)"
	npc.position = Vector3(-13.0, 0, -0.25)
	add_child(npc)
	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.36
	cylinder.bottom_radius = 0.48
	cylinder.height = 1.8
	body.mesh = cylinder
	body.position.y = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.58, 0.57)
	body.material_override = mat
	npc.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	head.mesh = sphere
	head.position.y = 2.18
	head.material_override = mat
	npc.add_child(head)

func _label(text_value: String, size: int = 24) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.add_theme_font_size_override("font_size", size)
	return lbl

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var top := PanelContainer.new()
	top.position = Vector2(32, 28)
	hud.add_child(top)
	var top_column := VBoxContainer.new()
	top.add_child(top_column)
	top_column.add_child(_label("SA2 / 探索・会話UI  試作", 24))
	hint = _label("", 20)
	top_column.add_child(hint)
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(120, 635)
	dialogue_panel.custom_minimum_size = Vector2(1360, 225)
	hud.add_child(dialogue_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	dialogue_panel.add_child(box)
	speaker = _label("", 27)
	box.add_child(speaker)
	dialogue_text = _label("", 27)
	dialogue_text.custom_minimum_size = Vector2(1250, 92)
	box.add_child(dialogue_text)
	var foot := HBoxContainer.new()
	box.add_child(foot)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(space)
	advance_button = Button.new()
	advance_button.text = "次へ  ▶  [Space / Enter]"
	advance_button.add_theme_font_size_override("font_size", 21)
	advance_button.pressed.connect(_advance)
	foot.add_child(advance_button)
	dialogue_panel.visible = false

func _process(_delta: float) -> void:
	if flow.mode == Flow.EXPLORE:
		flow.set_explore_position(stage.player.global_position)
	_update_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E and flow.mode == Flow.EXPLORE:
		_try_talk()
		get_viewport().set_input_as_handled()
	elif flow.mode == Flow.DIALOGUE and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_advance()
		get_viewport().set_input_as_handled()

func _near_npc() -> bool:
	var p: Vector3 = stage.player.global_position
	var n: Vector3 = npc.global_position
	return Vector2(p.x, p.z).distance_to(Vector2(n.x, n.z)) <= TALK_RADIUS

func _try_talk() -> void:
	if not _near_npc():
		return
	if flow.begin_dialogue("C1-06", stage.player.global_position):
		talk_index = 0
		_update_view()

func _advance() -> void:
	if flow.mode != Flow.DIALOGUE:
		return
	if talk_index < LINES.size() - 1:
		talk_index += 1
	else:
		assert(flow.finish_dialogue())
	_update_view()

func _update_view() -> void:
	var conversing: bool = flow.mode == Flow.DIALOGUE
	if stage != null:
		stage.set_physics_process(not conversing)
	if dialogue_panel == null:
		return
	dialogue_panel.visible = conversing
	if conversing:
		speaker.text = str(LINES[talk_index][0])
		dialogue_text.text = str(LINES[talk_index][1])
		advance_button.text = "閉じる  ▶  [Space / Enter]" if talk_index == LINES.size() - 1 else "次へ  ▶  [Space / Enter]"
		hint.text = "会話中：移動停止"
	else:
		hint.text = "WASD / 方向キー：移動   E：話す" if _near_npc() else "WASD / 方向キー：移動   案内係に近づいて E"
		
func _run_demo() -> void:
	await _frames(40)
	var starting_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(48)
	Input.action_release("ui_right")
	assert(stage.player.global_position.x > starting_x + 1.0, "approach failed")
	assert(_near_npc(), "NPC not within range")
	await _frames(22)
	_try_talk()
	assert(flow.mode == Flow.DIALOGUE, "dialogue start failed")
	var locked_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(24)
	Input.action_release("ui_right")
	assert(absf(stage.player.global_position.x - locked_x) < 0.02, "movement not locked")
	await _frames(70)
	_advance()
	assert(talk_index == 1)
	await _frames(65)
	_advance()
	assert(talk_index == 2)
	await _frames(65)
	_advance()
	assert(flow.mode == Flow.EXPLORE, "failed to return to exploration")
	await _frames(24)
	var resume_x: float = stage.player.global_position.x
	Input.action_press("ui_right")
	await _physics_frames(36)
	Input.action_release("ui_right")
	assert(stage.player.global_position.x > resume_x + 0.4, "movement did not resume")
	print("SA2_DIALOGUE_DEMO_PASS: approach, start, 3 lines, movement lock, close, resume")
	await _frames(28)
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
