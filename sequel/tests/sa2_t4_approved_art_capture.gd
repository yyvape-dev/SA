extends SceneTree
## T4 ONLY. Actual backtown scene + real D2 camera, no production scene edits.
## The approved 16m facade is one static RGBA quad; animation/layer separation
## and independent new map are intentionally NOT accepted by this smoke test.
const BT = preload("res://scripts/backtown_block.gd")
const X0 := 7.0
const W := 16.0
const H := 10.0
const MID_X := X0 + W * 0.5
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(valid: bool, detail: String) -> void:
    if not valid:
        errors.append(detail)
        printerr("T4_APPROVED_PREVIEW_FAIL " + detail)

func _capture(game: Node3D, filename: String) -> void:
    for i in 6:
        await process_frame
        await RenderingServer.frame_post_draw
    var picture := game.get_viewport().get_texture().get_image()
    _assert(picture != null, "Missing actual viewport: " + filename)
    if picture == null:
        return
    var err := picture.save_png(filename)
    _assert(err == OK, "Could not save actual viewport: " + filename)
    if err == OK:
        print("T4_APPROVED_SCREENSHOT %s %dx%d" % [filename, picture.get_width(), picture.get_height()])

func _run() -> void:
    var texture_path := "res://art/painted_bt/gamehall_approved_16m_preview.png"
    _assert(ResourceLoader.exists(texture_path), "Approved image is missing")
    if not errors.is_empty():
        quit(1)
        return
    var tex: Texture2D = load(texture_path)
    _assert(tex.get_size() == Vector2(3200, 2000), "Approved preview needs 3200x2000")
    var packed: PackedScene = load("res://main.tscn")
    _assert(packed != null, "Main scene not found")
    if not errors.is_empty():
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    var player: Node3D
    var camera: Camera3D
    var level: Node3D
    var ui: CanvasLayer
    for i in 600:
        await process_frame
        player = game.get("player")
        camera = game.get("cam")
        level = game.get("level")
        ui = game.get("ui")
        if player != null and camera != null and level != null and ui != null:
            break
    _assert(player != null and camera != null and level != null and ui != null, "Could not boot actual backtown")
    if not errors.is_empty():
        quit(1)
        return
    _assert(absf(camera.fov - 16.8) < 0.05, "D2 FOV modified")
    _assert(absf(camera.position.z - 15.3) < 0.05, "D2 camera offset modified")
    _assert(BT.BELT_Z.is_equal_approx(Vector2(-2.0, 2.0)), "Walking belt modified")
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
    _assert(inn != null, "Missing old inn to hide in test")
    if inn != null:
        inn.visible = false
    var stalls: Node3D = nodes.get("stalls")
    var old_game: Node3D = stalls.get_node_or_null("stall_game") if stalls != null else null
    _assert(old_game != null, "Missing obsolete game stall")
    if old_game != null:
        old_game.visible = false
    # Hiding overlapping scenery is strictly for this isolated visual fit trial.
    # The intended NEW left-linked loading map is not built by this test.
    var hidden := 0
    var stack: Array[Node] = [level]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        for ch in n.get_children():
            stack.push_back(ch)
        if n is GeometryInstance3D:
            var g: GeometryInstance3D = n
            var pos: Vector3 = g.global_position
            if pos.x >= X0 and pos.x <= X0 + W and pos.z <= -4.0 and pos.z >= -7.5:
                g.visible = false
                hidden += 1
    var old_fg: Array = game.get("bt_fg")
    for fd in old_fg:
        if absf((fd.node as Node3D).position.x - 12.0) < 0.05:
            fd.node.visible = false
    var holder := Node3D.new()
    holder.name = "T4_APPROVED_ART_ONLY"
    level.add_child(holder)
    var quad: MeshInstance3D = game.call("_bt_quad", holder, "gamehall_approved_16m_preview",
        X0, 0.0, X0+W, H, -6.18, 1.0) as MeshInstance3D
    _assert(quad != null, "Godot could not create facade textured quad")
    if not errors.is_empty():
        quit(1)
        return
    quad.name = "gamehall_16m_final_art_d2_smoke_test"
    var mesh: QuadMesh = quad.mesh as QuadMesh
    _assert(mesh != null and mesh.size.is_equal_approx(Vector2(W,H)), "World dimensions incorrect")
    _assert(is_equal_approx(quad.position.y,H * 0.5), "Ground connection incorrect")
    # New isolated scene would have wider camera travel; preview only.
    game.set("cam_x", Vector2(-12.0, 32.0))
    var output := ProjectSettings.globalize_path("res://captures/t4-gamehall-approved")
    DirAccess.make_dir_recursive_absolute(output)
    for item in [
        {"x":MID_X, "file":"approved_16m_center.png"},
        {"x":9.0, "file":"approved_16m_left.png"},
        {"x":21.0, "file":"approved_16m_right.png"}
    ]:
        player.position = Vector3(item.x, 0, 0)
        game.call("_place_cam", true)
        await _capture(game, output + "/" + item.file)
    print("T4_APPROVED_GEOMETRY src_px=1488x992 output_px=3200x2000 world=16.00x10.00m camera=D2 hidden_overlap=%d" % hidden)
    if errors.is_empty():
        print("T4_APPROVED_D2_PREVIEW_PASS captures=3 STATIC_ONLY new_map=NOT_TESTED mobile=NOT_TESTED")
        quit(0)
    else:
        quit(1)
