extends SceneTree
var failures: Array[String] = []
func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)
func _initialize() -> void:
	var path := "res://scripts/sa2_prologue_state.gd"
	if not ResourceLoader.exists(path):
		printerr("PROLOGUE_FAIL: missing dedicated state")
		quit(1)
		return
	var script = load(path)
	var state = script.new()
	check(state.beat_id == "morning", "starts in office")
	check(not state.interact("note"), "note cannot be discovered in office dialogue")
	check(state.finish_dialogue(), "morning closes")
	check(state.beat_id == "breakfast", "Mina enters next")
	check(state.finish_dialogue(), "breakfast closes")
	check(state.beat_id == "talk_lily", "wait for Lily, no premature guest room")
	check(not state.finish_dialogue(), "double close cannot skip operation")
	check(not state.interact("talk"), "too far to talk")
	state.move_to(2.2, 0.0)
	check(state.interact("talk"), "talk nearby")
	check(state.beat_id == "missing", "Lily explains")
	state.finish_dialogue()
	check(not state.interact("note"), "exit required before note")
	state.move_to(4.0, 0.0)
	check(state.interact("guest"), "enter guest room")
	check(state.beat_id == "find_note" and not state.note_found(), "discovery not automatic")
	check(not state.finish_dialogue(), "cannot skip investigation")
	state.move_to(2.2, 0.0)
	check(state.interact("note"), "inspect desk")
	check(state.note_found() and state.beat_id == "note", "paper shown before promise")
	check(state.interact("read"), "close note explicitly")
	check(state.beat_id == "promise", "promise follows note")
	state.finish_dialogue()
	check(state.beat_id == "three_days", "time transition checkpoint")
	check(state.interact("continue"), "continue three days later")
	for beat in ["audience", "lamp", "departure"]:
		check(state.beat_id == beat, "expected " + beat)
		check(state.finish_dialogue(), "finish " + beat)
	check(state.is_complete(), "completed for first chapter")
	check(not state.finish_dialogue(), "completion idempotent")
	# Each checkpoint must restore the exact dialogue line and operation lock.
	for beat in script.BEATS:
		var original = script.new()
		original.beat_id = beat
		var data: Dictionary = original.dialogue()
		if not data.is_empty():
			check(original.set_line(str(data.lines[-1].line_id)), "last line stored " + beat)
		var resumed = script.new()
		check(resumed.restore(original.snapshot()), "restore " + beat)
		check(resumed.snapshot() == original.snapshot(), "exact checkpoint " + beat)
		check(resumed.note_found() == original.note_found(), "derived discovery " + beat)
		check(resumed.save_to("user://sa2_prologue_state_test.json"), "save " + beat)
		var disk = script.new()
		check(disk.load_from("user://sa2_prologue_state_test.json"), "load " + beat)
		check(disk.snapshot() == resumed.snapshot(), "disk checkpoint " + beat)
	var before: Dictionary = state.snapshot()
	for bad in [{}, {"schema_version": 1, "beat_id": "wrong"}, {"schema_version": 1, "beat_id": "morning", "line_id": "later", "x": 0, "z": 0}, {"schema_version": 1, "beat_id": "find_note", "line_id": "", "x": 999, "z": 0}]:
		check(not state.restore(bad), "reject corrupted save")
		check(state.snapshot() == before, "failed restore atomic")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sa2_prologue_state_test.json"))
	if failures.is_empty():
		print("PROLOGUE_STATE_PASS")
		quit(0)
	else:
		for why in failures: printerr("PROLOGUE_FAIL: ", why)
		quit(1)
