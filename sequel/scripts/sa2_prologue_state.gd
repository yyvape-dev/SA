extends RefCounted
## Standalone progress. Never writes SA2 growth/training saves or accepts executable commands.
const DB := preload("res://scripts/sa2_dialogue_database.gd")
const SAVE_PATH := "user://sa2_prologue_preview_v1.json"
const BEATS := ["morning", "breakfast", "talk_lily", "missing", "guest_door", "find_note", "note", "promise", "three_days", "audience", "lamp", "departure", "ending"]
const EVENTS := {"morning": "P0-01", "breakfast": "P0-02", "missing": "P0-03", "promise": "P0-05", "audience": "P0-06", "lamp": "P0-06-lamp", "departure": "P0-07"}
const ACTIONS := {"talk_lily": "talk", "guest_door": "guest", "find_note": "note", "note": "read", "three_days": "continue"}
const TARGETS := {"talk_lily": Vector2(2.2, 0), "guest_door": Vector2(4, 0), "find_note": Vector2(2.2, 0)}
var beat_id := "morning"
var line_id := ""
var facing := 1
var player := Vector2(-1.8, 0)

func dialogue() -> Dictionary:
	return DB.new().load_event(EVENTS[beat_id]) if EVENTS.has(beat_id) else {}

func scene_id() -> String:
	var i := BEATS.find(beat_id)
	return "office" if i < 5 else ("guest" if i < 9 else "audience")

func is_complete() -> bool:
	return beat_id == "ending"

func note_found() -> bool:
	return BEATS.find(beat_id) >= BEATS.find("note")

func can_move() -> bool:
	return TARGETS.has(beat_id)

func move_to(x: float, z: float) -> bool:
	if not can_move() or not is_finite(x) or not is_finite(z): return false
	if absf(x - player.x) > 0.001: facing = -1 if x < player.x else 1
	player = Vector2(clampf(x, -4.5, 4.5), clampf(z, -0.45, 0.45))
	return true

func interact(action: String) -> bool:
	if ACTIONS.get(beat_id, "") != action: return false
	if TARGETS.has(beat_id) and player.distance_to(TARGETS[beat_id]) > 1.0: return false
	return _next()

func finish_dialogue() -> bool:
	if not EVENTS.has(beat_id): return false
	return _next()

func _next() -> bool:
	var index := BEATS.find(beat_id)
	if index < 0 or index >= BEATS.size() - 1: return false
	var old_scene := scene_id()
	beat_id = BEATS[index + 1]
	line_id = ""
	if beat_id == "promise": facing = -1
	if scene_id() != old_scene:
		player = Vector2(-1.8, 0)
		facing = 1
	return true

func set_line(id: String) -> bool:
	for line in dialogue().get("lines", []):
		if line.line_id == id:
			line_id = id
			return true
	return false

func snapshot() -> Dictionary:
	return {"schema_version": 1, "beat_id": beat_id, "line_id": line_id, "x": player.x, "z": player.y, "facing": facing}

func restore(data: Dictionary) -> bool:
	if data.get("schema_version") != 1 or not data.get("beat_id") in BEATS: return false
	if not data.get("line_id") is String: return false
	if data.get("facing", 1) != -1 and data.get("facing", 1) != 1: return false
	for key in ["x", "z"]:
		if not (data.get(key) is float or data.get(key) is int): return false
		if not is_finite(float(data[key])): return false
	if absf(float(data.x)) > 4.5 or absf(float(data.z)) > 0.45: return false
	var candidate = get_script().new()
	candidate.beat_id = data.beat_id
	if not str(data.line_id).is_empty() and not candidate.set_line(data.line_id): return false
	beat_id = candidate.beat_id
	line_id = str(data.line_id)
	facing = int(data.get("facing", 1))
	player = Vector2(float(data.x), float(data.z))
	return true

func save_to(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func load_from(path: String = SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return restore(parsed) if parsed is Dictionary else false
