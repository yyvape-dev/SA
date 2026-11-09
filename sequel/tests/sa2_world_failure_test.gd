extends SceneTree
const FailingPack = preload("res://tests/fixtures/failing_gamehall_pack.gd")
var failures: Array[String] = []
func _initialize() -> void:
    OS.set_environment("TOWN", "back")
    call_deferred("_run")
func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        printerr("WORLD_FAILURE_FAIL: ", label)
func frames(n: int) -> void:
    for i in n: await process_frame
func _run() -> void:
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    for i in 3600:
        if game.ui != null: break
        await process_frame
    var original_pack = game.district
    var failure = FailingPack.new()
    game.add_child(failure)
    game.district = failure
    game.player.position.x = -24
    var old_level = game.level
    await game.change_town_floor(true)
    await frames(40)
    check(failure.requests == 1, "one failed edge attempt does not become an automatic retry loop")
    check(not game.loading.visible, "failed download releases full-screen touch-blocking fade")
    check(not game.player.locked and not game.town_floor_busy, "failed download restores controls")
    check(game.level == old_level and game.town_floor == "backtown", "failed download preserves current street")
    game.player.position.x = -22
    await frames(2)
    game.district = original_pack
    failure.queue_free()
    game.bt_tex["gamehall_approved_16m_preview"] = null
    game.player.position.x = -24
    await game.change_town_floor(true)
    await frames(40)
    check(not game.loading.visible and game.level == old_level, "missing artwork also returns to the current street")
    game.player.position.x = -22
    await frames(2)
    game.bt_tex.erase("gamehall_approved_16m_preview")
    await game.change_town_floor(true)
    await frames(40)
    check(game.town_floor == "gamehall" and not game.player.locked, "player can retry successfully after moving away")
    check(game.loading.error_text.is_empty(), "successful retry clears error state")
    var label = game.loading.get("_err")
    check(label == null or not label.visible, "successful retry clears visible error label")
    game.queue_free()
    await frames(2)
    print("WORLD_FAILURE_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
    quit(0 if failures.is_empty() else 1)
