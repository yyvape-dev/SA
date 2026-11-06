extends Node2D
## Idle micro-motion prototype. Holds the source image at its original resolution.
## To take real Godot frame captures: CAPTURE_IDLE=1 godot --path godot-viewport-test
const PERIOD: float = 2.4
const FRAME_COUNT: int = 24
@onready var character: Sprite2D = $Character
var elapsed: float = 0.0
var capturing: bool = false

func _ready() -> void:
    if OS.has_environment("CAPTURE_IDLE"):
        capturing = true
        call_deferred("_capture_frames")

func _process(delta: float) -> void:
    if capturing:
        return
    elapsed = fposmod(elapsed + delta, PERIOD)
    _set_phase(elapsed / PERIOD)

func _set_phase(p: float) -> void:
    var mat := character.material as ShaderMaterial
    mat.set_shader_parameter("phase", p)

func _capture_frames() -> void:
    var dst := ProjectSettings.globalize_path("res://captures/lana_idle")
    DirAccess.make_dir_recursive_absolute(dst)
    for i in range(FRAME_COUNT):
        _set_phase(float(i) / float(FRAME_COUNT))
        await get_tree().process_frame
        await RenderingServer.frame_post_draw
        var snap := get_viewport().get_texture().get_image()
        var path := dst.path_join("lana_idle_%02d.png" % i)
        var err := snap.save_png(path)
        if err != OK:
            push_error("Capture failure: %s code=%s" % [path, err])
    get_tree().quit()
