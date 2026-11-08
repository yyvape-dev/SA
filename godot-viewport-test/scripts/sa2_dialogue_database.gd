extends RefCounted
class_name SA2DialogueDatabase

# Story strings live only in res://dialogues/ja/*.json, never in GDScript.
const VALID_EVENTS := ["C1-06", "C2-09"]
const BASE_PATH := "res://dialogues/ja/"
const VERSION := 1
var last_error: String = ""

func load_event(event_id: String) -> Dictionary:
	last_error = ""
	if not VALID_EVENTS.has(event_id):
		last_error = "Unknown event ID"
		return {}
	var path := BASE_PATH + event_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Missing dialogue file: " + path
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		last_error = "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		return {}
	var payload: Variant = json.data
	if not payload is Dictionary:
		last_error = "Root must be an object"
		return {}
	if not (payload.get("schema_version") == VERSION and payload.get("id") == event_id):
		last_error = "Schema version or event ID mismatch"
		return {}
	var lines: Variant = payload.get("lines")
	if not lines is Array or lines.is_empty() or lines.size() > 1000:
		last_error = "lines must contain 1-1000 entries"
		return {}
	var unique_ids := {}
	for i in range(lines.size()):
		var line: Variant = lines[i]
		if not line is Dictionary:
			last_error = "line %d must be an object" % i
			return {}
		for key in ["line_id", "speaker_id", "speaker", "text"]:
			if not line.has(key) or not line[key] is String or (line[key] as String).strip_edges().is_empty():
				last_error = "line %d invalid %s" % [i, key]
				return {}
		if unique_ids.has(line["line_id"]):
			last_error = "Duplicate line_id: " + line["line_id"]
			return {}
		unique_ids[line["line_id"]] = true
		if line["text"].length() > 600:
			last_error = "Text too long; split into multiple lines"
			return {}
		if line.has("portrait_id"):
			if not line["portrait_id"] is String or not _safe_asset_id(line["portrait_id"]):
				last_error = "Invalid portrait_id"
				return {}
	return (payload as Dictionary).duplicate(true)

func _safe_asset_id(id: String) -> bool:
	if id.is_empty():
		return true
	if id.length() > 64:
		return false
	for i in range(id.length()):
		var c := id.unicode_at(i)
		if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 or c == 45):
			return false
	return true
