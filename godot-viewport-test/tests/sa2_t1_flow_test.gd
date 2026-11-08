extends SceneTree

const Flow = preload("res://scripts/sa2_flow_state.gd")
const P := Vector3(2.5, 0.04, -1.25)
const Q := Vector3(4.0, 0.04, 2.0)
var failures: Array[String] = []

func _initialize() -> void:
	_run()
	if failures.is_empty():
		print("SA2_T1_PASS: 32 checks: dialogue, trigger guards, battle adapters, save/reload, retry, restore")
		quit(0)
	else:
		for failure in failures:
			printerr("SA2_T1_FAIL: ", failure)
		quit(1)

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _run() -> void:
	var s = Flow.new()
	check(s.mode == Flow.EXPLORE, "initial exploration")
	check(s.begin_dialogue("C1-06", P), "start C1 dialogue")
	check(not s.begin_dialogue("C1-06", P), "guard duplicate dialogue")
	check(not s.enter_battle("C1-06", P), "no battle before dialogue completion")
	check(s.save_to("user://sa2_t1_test.json"), "save during dialogue")
	var loaded = Flow.new()
	check(loaded.load_from("user://sa2_t1_test.json"), "load dialogue")
	check(loaded.mode == Flow.DIALOGUE, "dialogue persistence")
	check(loaded.return_position.is_equal_approx(P), "dialogue position persistence")
	check(loaded.finish_dialogue(), "finish dialogue")
	check(not loaded.finish_dialogue(), "guard duplicate finish")
	check(loaded.enter_battle("C1-06", Q), "instance adapter")
	check(loaded.mode == Flow.INSTANCE, "instance mode")
	check(not loaded.enter_battle("C1-06", Q), "guard duplicate instance")
	check(loaded.save_to("user://sa2_t1_test.json"), "save during instance")
	var resumed = Flow.new()
	check(resumed.load_from("user://sa2_t1_test.json"), "load instance")
	check(resumed.attempts.get("C1-06", 0) == 1, "attempt not duplicated")
	check(resumed.return_position.is_equal_approx(Q), "battle return position")
	check(resumed.finish_battle(false), "lose instance")
	check(resumed.return_to_explore(), "return on loss")
	check(resumed.player_position.is_equal_approx(Q), "position on loss")
	check(resumed.enter_battle("C1-06", Q), "retry without dialogue")
	check(resumed.attempts.get("C1-06", 0) == 2, "attempt counter on retry")
	check(resumed.finish_battle(true), "win instance")
	check(resumed.save_to("user://sa2_t1_test.json"), "save result")
	var after_result = Flow.new()
	check(after_result.load_from("user://sa2_t1_test.json"), "load result")
	check(after_result.return_to_explore(), "return on win")
	check(after_result.completed.get("C1-06", false), "completion flag")
	check(not after_result.begin_dialogue("C1-06", P), "guard completed replay")
	check(after_result.begin_dialogue("C2-09", P), "street dialogue")
	check(after_result.finish_dialogue(), "street finish dialogue")
	check(after_result.enter_battle("C2-09", Q), "street adapter")
	check(after_result.mode == Flow.STREET, "street mode")
	check(after_result.finish_battle(true), "street success")
	check(after_result.return_to_explore(), "street return")
	check(after_result.completed.get("C2-09", false), "street completion")
	var corrupt := after_result.to_dict()
	corrupt["mode"] = "unknown"
	check(not after_result.restore(corrupt), "reject invalid mode")
	check(after_result.mode == Flow.EXPLORE, "invalid save did not mutate state")
