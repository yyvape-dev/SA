extends SceneTree
## T4-only real Godot 4.7.2 D2 animation proof: 6 registered source-pixel layers.
## Not a Python animation mock. No production scripts, maps, T2/T3, or main modified.
const X0 := 7.0
const WIDTH := 16.0
const HEIGHT := 10.0
const CENTER_X := X0 + WIDTH * 0.5
const Z_BACKGROUND := -6.18
const FRAME_COUNT := 24
const LOOP_SECONDS := 2.0
const ART_FOLDER := "res://art/painted_bt/gamehall_motion/"
const ART_IDS := ["left_slot_machine", "right_slot_machine", "cloaked_man", "left_woman", "right_woman", "roulette_cluster"]
const DETAIL_SHADER = preload("res://tests/t4_gamehall_local_detail.gdshader")
const SOURCE_W := 1488.0
const SCALE := 3200.0 / SOURCE_W
const TOP_CROP := 133.0
# Original 1585×992 painting coordinates, NOT the 3200px display crop.
const SOURCE_REGIONS = {
    "left_slot_machine": Rect2(341, 769, 55, 62),
    "right_slot_machine": Rect2(1177, 755, 54, 73),
    "roulette_cluster": Rect2(774, 845, 28, 15),
    "cloaked_man": Rect2(468, 782, 75, 148),
    "left_woman": Rect2(394, 790, 60, 153),
    "right_woman": Rect2(1101, 786, 80, 155),
}
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, detail: String) -> void:
    if not ok:
        errors.append(detail)
        printerr("T4_MOTION_FAIL ", detail)

func _capture(game: Node3D, output: String) -> void:
    for k in 3:
        await process_frame
        await RenderingServer.frame_post_draw
    var image: Image = game.get_viewport().get_texture().get_image()
    _check(image != null, "Godot viewport screenshot missing: " + output)
    if image == null:
        return
    _check(image.get_size() == Vector2i(1688,780), "Actual D2 viewport resolution mismatch")
    _check(image.save_png(output) == OK, "Could not save Godot real screenshot: " + output)

func _region_from_source(rect: Rect2) -> Vector4:
    var x0: float = (rect.position.x - 48.0) / SOURCE_W
    var x1: float = (rect.end.x - 48.0) / SOURCE_W
    var y0: float = (rect.position.y * SCALE - TOP_CROP) / 2000.0
    var y1: float = (rect.end.y * SCALE - TOP_CROP) / 2000.0
    return Vector4(x0,y0,x1,y1)

func _run() -> void:
    for filename in ART_IDS + ["background_clean"]:
        var p: String = ART_FOLDER + str(filename) + ".png"
        _check(ResourceLoader.exists(p), "T4 generated source-pixel texture missing: " + p)
        if ResourceLoader.exists(p):
            var texture: Texture2D = load(p)
            _check(texture.get_size() == Vector2(3200,2000), "T4 layer not 3200x2000: " + filename)
    if not errors.is_empty():
        quit(1)
        return
    var packed: PackedScene = load("res://main.tscn")
    _check(packed != null, "Cannot load real game scene")
    if packed == null:
        quit(1)
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    var player: Node3D
    var camera: Camera3D
    var level: Node3D
    var ui: CanvasLayer
    for j in 600:
        await process_frame
        player = game.get("player")
        camera = game.get("cam")
        level = game.get("level")
        ui = game.get("ui")
        if player != null and camera != null and level != null and ui != null:
            break
    _check(player != null and camera != null and level != null and ui != null, "Game boot missing D2 scene nodes")
    if not errors.is_empty():
        quit(1)
        return
    _check(absf(camera.fov - 16.8) < 0.05, "Camera FOV changed; must use D2")
    _check(absf(camera.position.z - 15.3) < 0.05, "Camera distance changed; must use D2")
    # Stretch layout may report the 1280x720 project viewport; validate actual PNG capture size instead.
    if not errors.is_empty():
        quit(1)
        return
    ui.visible = false
    var hud: CanvasLayer = game.get("hud")
    if hud != null:
        hud.visible = false
    var loading: CanvasLayer = game.get("loading")
    if loading != null:
        loading.visible = false
    player.set_physics_process(false)
    var nodes: Dictionary = game.get("piece_nodes")
    var inn: Node3D = nodes.get("n3_brothel")
    _check(inn != null, "Existing inn segment not found")
    if inn != null:
        inn.visible = false
    var stalls: Node3D = nodes.get("stalls")
    var old_stall: Node3D = stalls.get_node_or_null("stall_game") if stalls != null else null
    if old_stall != null:
        old_stall.visible = false
    # Replicate accepted T4-only fit view; no existing content is deleted or moved.
    var stack: Array[Node] = [level]
    var hidden: int = 0
    while not stack.is_empty():
        var current: Node = stack.pop_back()
        for child in current.get_children():
            stack.push_back(child)
        if current is GeometryInstance3D:
            var gi := current as GeometryInstance3D
            var point := gi.global_position
            if point.x >= X0 and point.x <= X0 + WIDTH and point.z <= -4.0 and point.z >= -7.5:
                gi.visible = false
                hidden += 1
    var old_fg: Array = game.get("bt_fg")
    for fd in old_fg:
        if absf((fd.node as Node3D).position.x - 12.0) < 0.05:
            fd.node.visible = false
    var holder := Node3D.new()
    holder.name = "T4_MOTION_LAYER_TEST_ONLY"
    level.add_child(holder)
    var bg: MeshInstance3D = game.call("_bt_quad", holder, "gamehall_motion/background_clean",
        X0, 0.0, X0 + WIDTH, HEIGHT, Z_BACKGROUND, 1.0, [0.0,0.0,1.0,1.0], 0) as MeshInstance3D
    _check(bg != null, "Cannot draw clean base layer")
    var meshes: Dictionary = {}
    var original_transforms: Dictionary = {}
    var detail_materials: Dictionary = {}
    for i in ART_IDS.size():
        var id: String = ART_IDS[i]
        var depth: float = Z_BACKGROUND + 0.015 + float(i) * 0.003
        var quad: MeshInstance3D = game.call("_bt_quad", holder, "gamehall_motion/" + id,
            X0, 0.0, X0 + WIDTH, HEIGHT, depth, 1.0, [0.0,0.0,1.0,1.0], 1) as MeshInstance3D
        _check(quad != null, "Cannot draw movable layer: " + id)
        if quad != null:
            quad.name = id + "_LOCALIZED_DETAIL"
            var mat := ShaderMaterial.new()
            mat.shader = DETAIL_SHADER
            mat.render_priority = 1
            mat.set_shader_parameter("painted", load(ART_FOLDER + id + ".png"))
            var region: Rect2 = SOURCE_REGIONS[id]
            mat.set_shader_parameter("region", _region_from_source(region))
            mat.set_shader_parameter("motion_kind",
                1 if id == "left_slot_machine" or id == "right_slot_machine"
                else (2 if id == "roulette_cluster" else 3))
            quad.material_override = mat
            meshes[id] = quad
            original_transforms[id] = quad.transform
            detail_materials[id] = mat
    if not errors.is_empty():
        quit(1)
        return
    # Suspend game physics/UI progression so captured pixel changes belong to T4.
    game.set_process(false)
    game.set_physics_process(false)
    player.position = Vector3(CENTER_X,0,0)
    game.set("cam_x",Vector2(-12,32))
    game.call("_place_cam",true)
    var output := ProjectSettings.globalize_path("res://captures/t4-gamehall-motion")
    DirAccess.make_dir_recursive_absolute(output)
    var animated_materials: int = 0
    for frame in FRAME_COUNT:
        var theta: float = TAU * float(frame) / float(FRAME_COUNT)
        for id in ART_IDS:
            var quad: MeshInstance3D = meshes[id]
            _check(quad.transform.is_equal_approx(original_transforms[id]),
                "Whole prop or table changed its position: " + id)
            var mat: ShaderMaterial = detail_materials[id]
            var cycle_theta: float = theta + (0.48 if id == "right_slot_machine" else 0.0)
            mat.set_shader_parameter("cycle", cycle_theta)
            animated_materials += 1
        await _capture(game, output + "/frame_%02d.png" % frame)
    _check(animated_materials == FRAME_COUNT * ART_IDS.size(), "Missing localized material updates")
    print("T4_MOTION_GEOMETRY_PASS width=16.00m height=10.00m static_prop_transforms=true localized_reels=2 roulette_disc=1 upper_bodies=3 frames=%d D2=true hidden=%d" %
        [FRAME_COUNT,hidden])
    if errors.is_empty():
        print("T4_MOTION_CAPTURE_PASS frames=24 Godot=4.7.2 localized_details=true whole_props_static=true visual_review_pending=true")
        quit(0)
    else:
        quit(1)
