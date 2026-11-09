extends RefCounted
## T4-only independent left-connected floor. Rebuild the approved backtown base,
## then replace ONLY this new floor's centre with the approved 16 m game hall.
## Existing backtown level, T2/T3 and the repository main branch are unchanged.
const WEST_EXIT := -23.55
const EAST_RETURN := 23.55
const ROOM := Vector2(-24.0, 24.0)
const HALL_X0 := -8.0
const HALL_W := 16.0
const HALL_H := 10.0
const ART := "res://art/painted_bt/gamehall_motion/"
const LOCAL_SHADER := preload("res://tests/t4_gamehall_local_detail.gdshader")
const PARTS := ["left_slot_machine", "right_slot_machine", "cloaked_man", "left_woman", "right_woman", "roulette_cluster"]
const SOURCE_W := 1488.0
const SCALE := 3200.0 / SOURCE_W
const TOP_CROP := 133.0
const REGIONS := {
    "left_slot_machine": Rect2(341,769,55,62),
    "right_slot_machine": Rect2(1177,755,54,73),
    "roulette_cluster": Rect2(774,845,28,15),
    "cloaked_man": Rect2(468,782,75,148),
    "left_woman": Rect2(394,790,60,153),
    "right_woman": Rect2(1101,786,80,155),
}

static func _uv(rect: Rect2) -> Vector4:
    return Vector4(
        (rect.position.x - 48.0) / SOURCE_W,
        (rect.position.y * SCALE - TOP_CROP) / 2000.0,
        (rect.end.x - 48.0) / SOURCE_W,
        (rect.end.y * SCALE - TOP_CROP) / 2000.0)

static func build(game: Node3D) -> Dictionary:
    # Reuse the exact established street/floor/lighting generation as the base.
    # This creates a different Level node and never moves the former map.
    game.call("build_backtown")
    var area: Node3D = game.get("level")
    area.name = "T4GamehallFloor"
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
            if p.x >= -9.25 and p.x <= 9.25 and p.z < -2.10 and p.z > -10.50:
                gi.visible = false
                masked += 1
    var holder := Node3D.new()
    holder.name = "GAMEHALL_16M_ART_LAYERS"
    area.add_child(holder)
    var background: MeshInstance3D = game.call("_bt_quad",holder,
        "gamehall_motion/background_clean",HALL_X0,0.0,HALL_X0+HALL_W,HALL_H,
        -6.18,1.0) as MeshInstance3D
    if background == null:
        push_error("T4_NEW_MAP_FAIL: clean background not available")
        return {}
    var mats: Dictionary = {}
    var props: Dictionary = {}
    for i in PARTS.size():
        var key: String = PARTS[i]
        var quad: MeshInstance3D = game.call("_bt_quad",holder,"gamehall_motion/"+key,
            HALL_X0,0.0,HALL_X0+HALL_W,HALL_H,-6.165+float(i)*0.003,
            1.0,[0.0,0.0,1.0,1.0],1) as MeshInstance3D
        if quad == null:
            push_error("T4_NEW_MAP_FAIL: missing layer "+key)
            return {}
        var material := ShaderMaterial.new()
        material.shader = LOCAL_SHADER
        material.render_priority = 1
        material.set_shader_parameter("painted", load(ART+key+".png"))
        material.set_shader_parameter("region",_uv(REGIONS[key]))
        material.set_shader_parameter("motion_kind",
            1 if key in ["left_slot_machine","right_slot_machine"]
            else (2 if key=="roulette_cluster" else 3))
        quad.material_override = material
        quad.name = "T4_"+key
        props[key] = quad
        mats[key] = material
    # Right edge returns to the original district. A lit floor marker is already
    # part of the project's portal vocabulary; do not add a new UI system.
    var exit_marker: Node3D = game.call("make_portal",
        Vector3(23.0,0.0,0.0), false,3.0,Color(0.72,0.39,0.85),false) as Node3D
    exit_marker.name = "T4_RETURN_EAST"
    var battle: Node3D = game.get("battle")
    var player: Node3D = game.get("player")
    var camera_bound := Vector2(-19.08,19.08)
    game.set("cam_x", camera_bound)
    if battle != null:
        battle.set("ROOM_X",ROOM)
        battle.set("auto_spawn",false)
    if player != null:
        player.set("room_x",ROOM)
    print("T4_NEW_FLOOR_BUILT geometry_copy=backtown new_node=%s facade_x=-8..8 width=16m height=10m hidden=%d animated=%d" %
        [area.name,masked,mats.size()])
    return {"materials":mats,"prop_nodes":props,"level":area,
        "concealed":masked,"floor_right_exit":exit_marker,
        "base_clone":"build_backtown copied on entering a separate Level"}
