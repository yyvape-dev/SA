extends Node3D

# Independent T1 integration surface. Battles remain placeholders until T2/T3.
const FlowScript = preload("res://scripts/sa2_flow_state.gd")
const Stage = preload("res://greybox_city.tscn")
var flow = FlowScript.new()
var stage: Node3D
var status: Label
var controls: VBoxContainer

func _ready() -> void:
	stage = Stage.instantiate()
	add_child(stage)
	if flow.load_from():
		stage.player.global_position = flow.player_position
		if flow.mode == FlowScript.EXPLORE:
			stage.player.global_position = flow.player_position
		else:
			stage.player.global_position = flow.return_position
	_make_ui()
	_sync()

func _process(_delta: float) -> void:
	if flow.mode == FlowScript.EXPLORE and stage != null and stage.player != null:
		flow.set_explore_position(stage.player.global_position)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(365, 0)
	layer.add_child(panel)
	controls = VBoxContainer.new()
	panel.add_child(controls)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	_button("C1-06 会話開始", func(): _begin("C1-06"))
	_button("C2-09 会話開始", func(): _begin("C2-09"))
	_button("会話終了", func(): _apply(flow.finish_dialogue()))
	_button("対象戦闘へ (T2/T3では未実装)", func(): _start_battle())
	_button("仮結果: 勝利", func(): _apply(flow.finish_battle(true)))
	_button("仮結果: 敗北", func(): _apply(flow.finish_battle(false)))
	_button("探索へ復帰", func(): _return())
	_button("保存", func(): _save())
	_button("再読込", func(): _load())

func _button(title: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = title
	b.pressed.connect(callback)
	controls.add_child(b)

func _begin(id: String) -> void:
	_apply(flow.begin_dialogue(id, stage.player.global_position))

func _start_battle() -> void:
	_apply(flow.enter_battle(flow.event_id, stage.player.global_position))

func _return() -> void:
	if flow.return_to_explore():
		stage.player.global_position = flow.player_position
	_sync()

func _save() -> void:
	flow.save_to()
	_sync()

func _load() -> void:
	if flow.load_from():
		stage.player.global_position = flow.player_position if flow.mode == FlowScript.EXPLORE else flow.return_position
	_sync()

func _apply(_success: bool) -> void:
	_sync()

func _sync() -> void:
	var exploration := flow.mode == FlowScript.EXPLORE
	stage.set_physics_process(exploration)
	# The original greybox controls player movement via its own physics loop.
	status.text = "SA2 T1 / 共通進行の動作確認 (戦闘は未実装)\n"
	status.text += "mode=%s  event=%s  result=%s\n" % [flow.mode, flow.event_id, flow.result]
	status.text += "completed=%s  attempts=%s\n" % [flow.completed, flow.attempts]
	status.text += "saved at user://sa2_t1_progress.json\n"
	status.text += "会話・戦闘中はX/Z移動停止。二方式の戦闘実装はT2/T3。"
