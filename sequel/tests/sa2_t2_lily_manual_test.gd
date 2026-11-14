extends SceneTree
# T2 red/green contract for a separate playable-Lily adapter.
const Manual = preload("res://scripts/sa2_t2_lily_manual.gd")
class FakeFoe extends Node3D:
    var state := "atk"
    var atk := {"t": 0.56, "hit_t": 0.8, "done": false}
    var face := -1
    var stun := 0.0
    var boss := false

func _initialize() -> void:
    var n := 0
    var e := FakeFoe.new()
    e.position = Vector3(1.2, 0, 0)
    if not Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard should accept incoming attack")
    e.atk.t = 0.3
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must reject early attack")
    e.atk.t = 0.74
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must reject too-late attack")
    e.atk.t = 0.56
    e.position.x = 8.0
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must reject remote enemy")
    e.position.x = 1.2
    e.atk.done = true
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must reject already-completed hit")
    e.atk.done = false
    e.atk.t = 0.0
    for remaining in [Manual.GUARD_MIN, Manual.GUARD_MAX]:
        e.atk.hit_t = remaining
        if not Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must include timing boundary")
    for remaining in [Manual.GUARD_MIN - 0.0001, Manual.GUARD_MAX + 0.0001]:
        e.atk.hit_t = remaining
        if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must exclude outside timing boundary")
    e.atk.hit_t = 0.24
    e.position = Vector3(Manual.GUARD_REACH, 0.0, 0.9)
    if not Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must include reach boundary")
    e.position.x += 0.001
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must exclude outside reach")
    e.position = Vector3(1.2, 0.0, 0.901)
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must exclude outside lane")
    e.position.z = 0.0
    e.state = "stun"
    if Manual.guard_candidate(e, Vector3.ZERO): n += 1; printerr("guard must reject non-attacking enemy")
    e.free()
    if n == 0:
        print("SA2_T2_LILY_MANUAL_PASS: guard timing and geometry")
        quit(0)
    else:
        printerr("SA2_T2_LILY_MANUAL_FAIL: ", n)
        quit(1)
