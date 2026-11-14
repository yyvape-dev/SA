extends SceneTree
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if not ResourceLoader.exists("res://sa2_prologue_preview.tscn"):
		printerr("PROLOGUE_PREVIEW_FAIL: missing independent playable scene")
		quit(1)
		return
	var view = load("res://sa2_prologue_preview.tscn").instantiate()
	view.auto_load = false
	view.save_path = "user://sa2_prologue_preview_test.json"
	root.add_child(view)
	await process_frame
	check(view.dialogue.active, "opening dialogue starts")
	var pos: Vector2 = view.state.player
	view.move_player(Vector2(1, 0), 1.0)
	check(view.state.player == pos, "movement locked during dialogue")
	view.dialogue.body.visible_characters = -1
	view.dialogue.auto_enabled = true
	view.dialogue.auto_wait = 100.0
	var reset_modal: ConfirmationDialog
	for child in view.dialogue.get_parent().get_children():
		if child is ConfirmationDialog: reset_modal = child
	reset_modal.popup_centered(Vector2i(470, 160))
	await process_frame
	await process_frame
	check(view.state.line_id == "P0-01-001", "reset confirmation pauses auto and saves")
	view.dialogue.auto_enabled = false
	reset_modal.hide()
	view.dialogue.body.visible_characters = 0
	view.dialogue.advance()
	check(view.dialogue.body.visible_characters == -1, "reveal current line")
	view.dialogue.advance()
	check(view.state.line_id == "P0-01-002", "line signal checkpoints")
	view.dialogue.open_log()
	check(not view.dialogue.advance(), "log blocks advance")
	view.dialogue.close_log()
	view.dialogue.skip_confirm.confirmed.emit()
	check(view.state.beat_id == "breakfast", "skip current unit only")
	view.dialogue.skip_confirm.confirmed.emit()
	check(view.state.beat_id == "talk_lily", "skip stops at operation")
	check(not view.dialogue.active, "operation has no dialogue overlay")
	view.pad_finger = 7
	view.touch_axis = Vector2.RIGHT
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = view.action.get_global_rect().get_center()
	Input.parse_input_event(release)
	await process_frame
	check(view.pad_finger == -1 and view.touch_axis == Vector2.ZERO, "release clears joystick even above UI")
	view.dialogue.dialogue_closed.emit()
	check(view.state.beat_id == "talk_lily", "stale close ignored")
	check(not view.perform_action(), "distant talk fails")
	view.move_player(Vector2.RIGHT, 1.4)
	view.move_player(Vector2.LEFT, 0.1)
	check(view.perform_action(), "walk to talk target")
	check(view.state.beat_id == "missing" and view.dialogue.active, "interaction starts conversation")
	check(view.save_progress(), "save exact line")
	var snapshot: Dictionary = view.state.snapshot()
	var resumed = load("res://sa2_prologue_preview.tscn").instantiate()
	resumed.save_path = view.save_path
	root.add_child(resumed)
	await process_frame
	check(resumed.state.snapshot() == snapshot, "load exact cursor and position")
	check(resumed.dialogue.active and resumed.room.actors.lily.visible, "restores actors and lock")
	check(resumed.room.actors.rana.flip_h, "restore left facing")
	resumed.queue_free()
	view.dialogue.skip_confirm.confirmed.emit()
	view.state.move_to(4, 0)
	check(view.perform_action(), "guest room doorway")
	check(view.room.room_id == "guest" and not view.state.note_found(), "guest placement before discovery")
	view.state.move_to(2.2, 0)
	check(view.perform_action(), "investigate paper")
	check(view.paper.visible and view.state.note_found(), "paper overlay visible")
	check(view.perform_action(), "put paper down")
	check(not view.paper.visible and view.dialogue.active, "promise resumes")
	check(view.room.actors.rana.flip_h and not view.room.actors.lily.flip_h, "guest conversation faces partner")
	view.dialogue.skip_confirm.confirmed.emit()
	check(view.time_title.visible and not view.dialogue.active, "three days boundary")
	check(view.get("time_scrim") != null and view.time_scrim.visible, "time change has blackout")
	check(view.perform_action(), "advance three days")
	view.dialogue.skip_confirm.confirmed.emit()
	check(view.state.beat_id == "lamp" and view.room.lamp.visible, "lamp presented in separate beat")
	check(view.room.camera.fov < 22.0, "camera closes on prop")
	check(not view.room.actors.lily.flip_h, "Lily faces lamp and envoy")
	view.dialogue.skip_confirm.confirmed.emit()
	check(not view.room.actors.envoy.visible, "envoy leaves before private talk")
	view.dialogue.skip_confirm.confirmed.emit()
	check(view.state.is_complete() and view.time_title.visible, "ends with chapter title")
	check(view.state.load_from(view.save_path) and view.state.is_complete(), "completion persisted")
	view.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sa2_prologue_preview_test.json"))
	if failures.is_empty():
		print("PROLOGUE_PREVIEW_PASS")
		quit(0)
	else:
		for why in failures: printerr("PROLOGUE_PREVIEW_FAIL: ", why)
		quit(1)
