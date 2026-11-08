extends RefCounted
class_name SA2FlowState

# T1 only: progression contract, not a combat implementation.
const SAVE_PATH := "user://sa2_t1_progress.json"
const VERSION := 1
const EXPLORE := "explore"
const DIALOGUE := "dialogue"
const INSTANCE := "instance_battle"
const STREET := "street_battle"
const RESULT := "result"
const VALID_MODES := [EXPLORE, DIALOGUE, INSTANCE, STREET, RESULT]
const VALID_EVENTS := ["C1-06", "C2-09"]

var mode: String = EXPLORE
var event_id: String = ""
var return_position: Vector3 = Vector3(-13.0, 0.04, 0.8)
var player_position: Vector3 = Vector3(-13.0, 0.04, 0.8)
var completed: Dictionary = {}
var attempts: Dictionary = {}
var result: String = ""
var dialogue_finished: bool = false
var dialogue_line_index: int = 0

func begin_dialogue(id: String, at: Vector3) -> bool:
	if mode != EXPLORE or not VALID_EVENTS.has(id) or completed.get(id, false):
		return false
	mode = DIALOGUE
	event_id = id
	return_position = at
	player_position = at
	dialogue_finished = false
	dialogue_line_index = 0
	result = ""
	return true

func set_dialogue_line_index(index: int) -> bool:
	if mode != DIALOGUE or index < 0:
		return false
	dialogue_line_index = index
	return true

func finish_dialogue() -> bool:
	if mode != DIALOGUE or dialogue_finished:
		return false
	dialogue_finished = true
	dialogue_line_index = 0
	mode = EXPLORE
	return true

func enter_battle(id: String, at: Vector3) -> bool:
	if mode != EXPLORE or event_id != id or not dialogue_finished or completed.get(id, false):
		return false
	return_position = at
	player_position = at
	mode = INSTANCE if id == "C1-06" else STREET
	attempts[id] = int(attempts.get(id, 0)) + 1
	result = ""
	return true

func finish_battle(won: bool) -> bool:
	if mode != INSTANCE and mode != STREET:
		return false
	result = "win" if won else "lose"
	mode = RESULT
	return true

func return_to_explore() -> bool:
	if mode != RESULT:
		return false
	if result == "win":
		completed[event_id] = true
		event_id = ""
		dialogue_finished = false
	# On loss, keep dialogue_finished to allow retry, without re-triggering dialogue.
	player_position = return_position
	result = ""
	mode = EXPLORE
	return true

func set_explore_position(p: Vector3) -> bool:
	if mode != EXPLORE:
		return false
	player_position = p
	return true

func to_dict() -> Dictionary:
	return {
		"version": VERSION, "mode": mode, "event_id": event_id,
		"return_position": _vec(return_position),
		"player_position": _vec(player_position),
		"completed": completed.duplicate(true),
		"attempts": attempts.duplicate(true),
		"result": result, "dialogue_finished": dialogue_finished,
		"dialogue_line_index": dialogue_line_index
	}

func save_to(path: String = SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true

func load_from(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		return false
	return restore(parsed)

func restore(data: Dictionary) -> bool:
	# Validate completely before mutating the current live state.
	if data.get("version") != VERSION:
		return false
	var next_mode: String = str(data.get("mode", ""))
	var next_id: String = str(data.get("event_id", ""))
	var next_result: String = str(data.get("result", ""))
	if not VALID_MODES.has(next_mode) or (next_id != "" and not VALID_EVENTS.has(next_id)):
		return false
	if next_mode != EXPLORE and next_id == "":
		return false
	if next_mode == RESULT and not ["win", "lose"].has(next_result):
		return false
	if next_mode != RESULT and next_result != "":
		return false
	if not data.get("completed") is Dictionary or not data.get("attempts") is Dictionary:
		return false
	if not data.get("return_position") is Array or not data.get("player_position") is Array:
		return false
	var rp: Array = data["return_position"]
	var pp: Array = data["player_position"]
	if rp.size() != 3 or pp.size() != 3:
		return false
	for value in rp + pp:
		if not (value is int or value is float):
			return false
	var next_completed: Dictionary = data["completed"]
	var next_attempts: Dictionary = data["attempts"]
	for id in next_completed:
		if not VALID_EVENTS.has(id) or not next_completed[id] is bool:
			return false
	for id in next_attempts:
		if not VALID_EVENTS.has(id) or not next_attempts[id] is float and not next_attempts[id] is int:
			return false
		if int(next_attempts[id]) < 0:
			return false
	var next_line: Variant = data.get("dialogue_line_index", 0)
	if not (next_line is int or next_line is float) or next_line < 0 or float(int(next_line)) != float(next_line):
		return false
	mode = next_mode
	event_id = next_id
	result = next_result
	return_position = Vector3(float(rp[0]), float(rp[1]), float(rp[2]))
	player_position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
	completed = next_completed.duplicate(true)
	attempts = next_attempts.duplicate(true)
	dialogue_finished = bool(data.get("dialogue_finished", false))
	dialogue_line_index = next_line
	return true

func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
