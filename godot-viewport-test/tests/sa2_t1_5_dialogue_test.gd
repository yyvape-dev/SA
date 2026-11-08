extends SceneTree

const Loader = preload("res://scripts/sa2_dialogue_database.gd")
const UI = preload("res://ui/sa2_dialogue_panel.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures.append(why)

func _run() -> void:
	var db = Loader.new()
	var c1: Dictionary = db.load_event("C1-06")
	check(c1.get("id", "") == "C1-06", "C1 id")
	check(c1.get("lines", []).size() == 3, "3 external lines")
	check(c1.get("lines", [])[0].get("speaker", "") == "案内係", "speaker from JSON")
	check(c1.get("lines", [])[0].get("text", "").begins_with("こちらは"), "Japanese JSON text")
	check(db.load_event("C2-09").get("id","") == "C2-09", "second event file")
	check(db.load_event("../attack").is_empty(), "reject path traversal")
	check(db.load_event("NOT-A-SCENE").is_empty(), "reject unknown event")
	check(db.load_event("MISSING").is_empty(), "reject missing data")
	var view = UI.instantiate()
	root.add_child(view)
	await process_frame
	check(view.start(c1), "start valid dialogue")
	check(view.visible, "shows window")
	check(view.line_index == 0, "initial index")
	check(view.body.visible_characters == 0, "typing starts hidden")
	view._process(0.05)
	check(view.body.visible_characters > 0, "typing progresses")
	check(view.line_index == 0, "typing not skip")
	view.advance()
	check(view.line_index == 0, "first press reveals same line")
	check(view.body.visible_characters == -1, "reveal all text")
	view.advance()
	check(view.line_index == 1, "second press advances line")
	view.advance()
	check(view.line_index == 1, "fast-forward second")
	view.advance()
	check(view.line_index == 2, "advance final")
	view.advance()
	check(view.visible, "still visible after reveal final")
	view.advance()
	check(not view.visible, "closes after final line")
	check(not view.advance(), "no double completion")
	check(view.start(c1), "reopen without stale state")
	check(view.line_index == 0, "reset index")
	check(not view.start(c1), "no duplicate start")
	var bad := {"id":"C1-06","lines":[{"speaker":"X","text":""}]}
	check(not view.start(bad), "do not replace active dialogue")
	view.queue_free()
	if failures.is_empty():
		print("SA2_T1_5_PASS: external dialogue, JSON guardrails, typing, fast-forward, advance, close, reopen")
		quit(0)
	else:
		for why in failures:
			printerr("SA2_T1_5_FAIL: ", why)
		quit(1)
