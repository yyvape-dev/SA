extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null: break
        await process_frame
    var p = game.t2_rana
    var b = game.battle
    game.player = p
    b.player = p
    b.ally = null
    b.cine = false
    p.locked = false
    p.position = Vector3.ZERO
    p.set_physics_process(false)
    game.t2_manual.set_physics_process(false)
    b.spawn("1", Vector3(1.2, 0, 0))
    var e = b.enemies.back()
    e.set_physics_process(false)
    e.size = 1.0
    for remaining in [0.15, 0.24, 0.32]:
        incoming(p, e, remaining)
        var hp: float = b.hp
        var hit_count: int = b.hits_taken
        var warn: Node3D = e.atk.warn
        var effects: int = game.fx2d.items.size()
        p.dodge()
        if p.state == "dodge" or e.state != "stun" or not e.atk.done or p.inv < 0.6:
            fail("Rana timed guard accepts inclusive window and prevents damage")
            return
        if not warn.is_queued_for_deletion() or e.atk.warn != null or b.freeze < 0.06 or game.fx2d.items.size() <= effects:
            fail("successful guard drops warning and creates impact/hitstop")
            return
        b.enemy_hits_player(e)
        b.enemy_hits_player(e)
        if b.hp != hp or b.hits_taken != hit_count:
            fail("guard cannot take damage twice")
            return
    for remaining in [0.1499, 0.3201]:
        incoming(p, e, remaining)
        p.dodge()
        if p.state != "dodge" or e.state != "atk" or e.atk.done:
            fail("too early/late remains the existing dodge")
            return
    for offset in [Vector3(1.5, 0, 0), Vector3(1.501, 0, 0), Vector3(1.2, 0, 0.5), Vector3(1.2, 0, 0.501)]:
        incoming(p, e, 0.24)
        e.position = offset
        e.atk.reach = 1.5
        e.atk.lane = 0.5
        p.dodge()
        if p.state != "dodge":
            fail("guard rejects exact/outside enemy hitbox boundaries")
            return
    incoming(p, e, 0.24)
    e.face = 1
    p.dodge()
    if p.state != "dodge":
        fail("guard rejects attacks facing away")
        return
    incoming(p, e, 0.24)
    e.face = 1
    e.atk.wide = true
    p.dodge()
    if p.state == "dodge" or e.state != "stun":
        fail("two-sided wide swing accepts rear contact")
        return
    incoming(p, e, 0.24)
    p.locked = true
    p.dodge()
    if e.atk.done or p.state != "move":
        fail("locked input does not guard or dodge")
        return
    p.locked = false
    incoming(p, e, 0.24)
    e.atk.done = true
    p.dodge()
    if p.state != "dodge":
        fail("completed attack cannot be guarded again")
        return
    incoming(p, e, 0.24)
    var expired_warning: Node3D = e.atk.warn
    b.fx.drop(expired_warning)
    await process_frame
    p.dodge()
    if e.state != "stun" or not e.atk.done:
        fail("guard handles an already-expired warning during hitstop")
        return
    # Lily keeps her adapter timing and now receives the same feedback/cleanup.
    var manual = game.t2_manual
    manual.locked = false
    manual.actor.state = "move"
    manual.actor.position = Vector3.ZERO
    incoming(p, e, 0.24)
    var warn: Node3D = e.atk.warn
    var count: int = manual.guard_count
    manual.dodge()
    if manual.guard_count != count + 1 or not warn.is_queued_for_deletion() or e.atk.warn != null:
        fail("Lily keeps guard timing and gets canceled-warning cleanup")
        return
    print("T6_RANA_GUARD_PASS: timing boundaries facing real hitbox wide-swing lock no-double-damage fallback feedback Lily regression")
    quit(0)
func incoming(p, e, remaining: float) -> void:
    p.state = "move"
    p.inv = 0.0
    e.position = Vector3(1.2, 0, 0)
    e.face = -1
    e._start_atk()
    e.atk.t = float(e.atk.hit_t) - remaining
func fail(message: String) -> void:
    push_error("T6_RANA_GUARD_FAIL: " + message)
    quit(1)
