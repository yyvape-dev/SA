extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = load("res://sa2_t5_training_preview.tscn").instantiate()
    root.add_child(game)
    for frame in 1200:
        if game.t2_manual != null: break
        await process_frame
    var fx = game.fx2d
    var at := Vector3(0, 1.0, 0)
    var first: int = fx.items.size()
    fx.hit(at, 1, false, "silver")
    for it in fx.items.slice(first):
        var node = it.node
        if node is CPUParticles2D and node.texture.resource_path.ends_with("light_01.png"):
            fail("ordinary contact sparks do not stack broad white halo emitters")
            return
        if node is Sprite2D and node.texture.resource_path.ends_with("light_01.png"):
            var world_width: float = float(it.base) * node.texture.get_width() / fx.px_per_m(at)
            if world_width > 0.6 or float(it.life) > 0.13:
                fail("contact white core stays smaller than torso and short-lived")
                return
    game.t2_manual.set_physics_process(false)
    var actor = game.t2_lily
    actor.set_physics_process(false)
    actor.position = Vector3.ZERO
    actor.face = 1
    var b = game.battle
    b.cine = false
    for e in b.enemies.duplicate(): b.remove_enemy(e)
    for x in [1.4, 2.1, 3.0]:
        b.spawn("1", Vector3(x, 0, 0))
        b.enemies.back().set_physics_process(false)
        b.enemies.back().hp = 10000.0
    actor.target = b.enemies[0]
    var hp: Array = b.enemies.map(func(e): return e.hp)
    var before: int = game.fx.items.size()
    var waves: int = game.fx.waves.size()
    var spec: Dictionary = actor.sk_tab.ult.ev.back()[1].duplicate(true)
    actor._skill_hit(spec)
    if b.enemies[0].hp >= hp[0] or b.enemies[1].hp != hp[1] or b.enemies[2].hp != hp[2]:
        fail("focused ultimate still damages only its locked target")
        return
    if game.fx.waves.size() != waves:
        fail("single-target ultimate does not advertise a broad radial shockwave")
        return
    for it in game.fx.items.slice(before):
        var node = it.node
        if node is MeshInstance3D and node.mesh.get_aabb().size.x > 2.0:
            fail("single-target finisher keeps its visible footprint local")
            return
    print("VFX_QUALITY_PASS: compact white core no stacked halo local ultimate VFX single-target damage unchanged")
    quit(0)
func fail(message: String) -> void:
    push_error("VFX_QUALITY_FAIL: " + message)
    quit(1)
