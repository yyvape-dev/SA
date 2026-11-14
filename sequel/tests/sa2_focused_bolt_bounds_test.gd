extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var fx = load("res://scripts/fx.gd").new()
    root.add_child(fx)
    fx.set_process(false)
    for n in 64:
        seed(n)
        var before: int = fx.items.size()
        var at := Vector3(4,0,0)
        fx.focused_strike(at)
        for it in fx.items.slice(before):
            if it.kind != "bolt": continue
            var box: AABB = it.node.mesh.get_aabb()
            if box.position.x < at.x - 0.651 or box.end.x > at.x + 0.651:
                push_error("FOCUSED_BOUNDS_FAIL seed=%d aabb=%s" % [n,box])
                quit(1)
                return
        for it in fx.items: it.node.free()
        fx.items.clear()
        for it in fx.tq: it.node.free()
        fx.tq.clear()
        fx.sparks.clear()
    print("FOCUSED_BOUNDS_PASS: 64 seeds main and branch geometry confined")
    quit()
