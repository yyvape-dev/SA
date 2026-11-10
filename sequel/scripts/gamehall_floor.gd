extends RefCounted
## Production adaptation of test/sa2-t4-gamehall-relayout-20261109 @ 6404831.
## Independent left-connected floor; the original district is rebuilt on return.
const WEST_EXIT := -23.55
const EAST_RETURN := 23.55
const ROOM := Vector2(-24.0, 24.0)
const HALL_X0 := -8.0
const HALL_W := 16.0
const HALL_H := 10.0
const HallAnimation := preload("res://scripts/gamehall_animation.gd")

static func build(game: Node3D) -> Dictionary:
    if game.call("_bt_art", "gamehall_approved_16m_preview") == null:
        return {}
    var animation := HallAnimation.new()
    if not animation.setup():
        animation.free()
        push_error("GAMEHALL_MAP_FAIL: missing animation artwork")
        return {}
    # Reuse the exact established street/floor/lighting generation as the base.
    # This creates a different Level node and never moves the former map.
    game.call("build_backtown", false)
    var area: Node3D = game.get("level")
    area.name = "GamehallFloor"
    var stack: Array[Node] = [area]
    var masked: int = 0
    while not stack.is_empty():
        var current: Node = stack.pop_back()
        for ch in current.get_children():
            stack.push_back(ch)
        if current is GeometryInstance3D:
            var gi := current as GeometryInstance3D
            var p: Vector3 = gi.global_position
            # Clear source scenery only within the new hall's facade/frontage.
            # Do not clear the gameplay belt, floor, distant frontage or flank shops.
            if p.y > 0.05 and p.x >= -9.25 and p.x <= 9.25 and p.z < -2.10 and p.z > -10.50:
                gi.visible = false
                masked += 1
    var holder := Node3D.new()
    holder.name = "GAMEHALL_16M_ART_LAYERS"
    area.add_child(holder)
    var background: MeshInstance3D = game.call("_bt_quad",holder,
        "gamehall_approved_16m_preview",HALL_X0,0.0,HALL_X0+HALL_W,HALL_H,
        -6.18,1.0) as MeshInstance3D
    if background == null:
        animation.free()
        push_error("GAMEHALL_MAP_FAIL: approved background not available")
        return {}
    animation.name = "GamehallAnimation"
    holder.add_child(animation)
    game.call("_bt_npc", holder, 5.9, -3.4, 0, "gambler", 1.83)
    # Right edge returns to the original district. A lit floor marker is already
    # part of the project's portal vocabulary; do not add a new UI system.
    var exit_marker: Node3D = game.call("make_portal",
        Vector3(23.0,0.0,0.0), false,3.0,Color(0.72,0.39,0.85),false) as Node3D
    exit_marker.name = "RETURN_TO_BACKTOWN"
    var battle: Node3D = game.get("battle")
    var player: Node3D = game.get("player")
    var camera_bound := Vector2(-19.08,19.08)
    game.set("cam_x", camera_bound)
    if battle != null:
        battle.set("ROOM_X",ROOM)
        battle.set("auto_spawn",false)
    if player != null:
        player.set("room_x",ROOM)
    print("GAMEHALL_FLOOR_BUILT width=16m height=10m hidden=%d" % masked)
    return {"level": area}
