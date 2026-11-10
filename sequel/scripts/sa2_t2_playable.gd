extends "res://scripts/main.gd"
## T2 C1-06 isolated playable slice: existing sequel battle, manually controlled Lily.
## Test dialogue is a T1.5 fixture, not the approved story screenplay.
const Manual := preload("res://scripts/sa2_t2_lily_manual.gd")
const Flow := preload("res://scripts/sa2_flow_state.gd")
const DB := preload("res://scripts/sa2_dialogue_database.gd")
const DialogueScene := preload("res://ui/sa2_dialogue_panel.tscn")
const EVENT_ID := "C1-06"
const T5_DIALOGUE_ID := "C1-06-t5-preview"
const T5_MEETING_POINT := Vector3(3.5, 0, 0)
const T5_TALK_DISTANCE := 1.3
const DEMO_SAVE := "user://sa2_t2_demo_save.json"
const NORMAL_SAVE := "user://sa2_t2_progress.json"
# Unscaled seconds, independent of rendering FPS. See docs/sa2_t2_asset_wait_20261108.md.
const ALLY_LOAD_TIMEOUT_SECONDS := 60.0
signal t2_ally_load_resolved(loaded: bool)
var t2_ally_load_done := false

@export var t5_training_preview := false
var t5_talk_button: Button
var t5_meeting_marker: Label3D
var t5_fade: ColorRect
var t5_dialogue_camera: Camera3D
var t5_instructor: Sprite3D
var t5_rana_idle: Sprite3D
var t5_lily_idle: Sprite3D
var t5_idle_elapsed := 0.0
var t5_transitioning := false

var t2_flow = Flow.new()
var t2_manual
var t2_lily
var t2_rana
var t2_layer: CanvasLayer
var t2_combat_controls: Control
var t2_dialogue: Control
var t2_label: Label
var t2_result_button: Button
var t6_retry_button: Button
var t6_finishing := false
var t6_won := false
var t2_kills := 0
var t2_active := false
var t2_done := false
var t2_demo := false
var t2_finger := -1
var t2_touch_origin := Vector2.ZERO
var t2_arena: Node3D

func _startup_town() -> String:
    return "back" if t5_training_preview else super._startup_town()

func _check_town_edge() -> void:
    if not t5_training_preview:
        super._check_town_edge()

func _check_gate() -> void:
    if not t5_training_preview:
        super._check_gate()

func _ready() -> void:
    await super._ready()
    if battle == null:
        return
    t2_demo = OS.has_environment("SA2_T2_MOVIE")
    battle.auto_spawn = false
    for e in battle.enemies.duplicate():
        battle.remove_enemy(e)
    var waiting_for_lily: bool = battle.ally == null
    if waiting_for_lily:
        player.locked = true
        loading.show_now()
    if not await _t2_wait_for_ally():
        var reason := "load failed" if t2_ally_load_done else "60-second timeout"
        push_error("SA2_T2_FAIL: Lily atlas/companion did not load: " + reason)
        get_tree().quit(1)
        return
    t2_lily = battle.ally
    t2_rana = player
    t2_rana.locked = true
    t2_rana.set_physics_process(false)
    t2_rana.hide()
    ui.set_controls_enabled(false)
    # Keep the main process/camera bound to the active character, not the hidden Rana.
    player = t2_lily
    battle.player = t2_lily
    battle.ally = null # prevents one enemy attack from hitting Lily twice
    t2_lily.position = Vector3(0, 0, 0.0)
    t2_lily.face = 1
    t2_manual = Manual.new()
    t2_manual.setup(t2_lily, battle)
    t2_manual.locked = true
    add_child(t2_manual)
    _t2_build_ui()
    if t5_training_preview:
        ui.player = t2_manual
        ui.basic_combat_only = false
        ui.lily_controls = true
        t2_manual.skills_enabled = true
        t2_manual.skills = t2_lily.sk_tab
        battle.manual_ally = t2_lily
        hud.hide()
        _t5_begin_exploration()
        if waiting_for_lily:
            loading.hide_soon()
        return
    var restored: bool = not t2_demo and t2_flow.load_from(NORMAL_SAVE)
    if not restored:
        t2_flow = Flow.new()
        if not t2_flow.begin_dialogue(EVENT_ID, t2_rana.position):
            push_error("SA2_T2_FAIL: cannot start event")
            get_tree().quit(1)
            return
        _t2_save()
    if t2_flow.mode == Flow.DIALOGUE:
        _t2_open_dialogue(t2_flow.event_id, t2_flow.dialogue_line_index)
    elif t2_flow.mode == Flow.INSTANCE:
        _t2_start_training(true)
    elif t2_flow.mode == Flow.RESULT:
        t2_done = true
        _t2_show_result()
    elif t2_flow.mode == Flow.EXPLORE:
        if t2_flow.event_id == EVENT_ID and t2_flow.dialogue_finished:
            _t2_start_training(false)
        else:
            _t2_restore_exploration()
    if waiting_for_lily:
        loading.hide_soon()
    if t2_demo:
        call_deferred("_t2_movie_demo")

func _load_ally() -> void:
    # main._ready() calls this override. Keep its existing asset/actor creation unchanged.
    await super._load_ally()
    t2_ally_load_done = true
    t2_ally_load_resolved.emit(is_instance_valid(battle.ally))

func _t2_wait_for_ally(timeout_seconds: float = ALLY_LOAD_TIMEOUT_SECONDS) -> bool:
    # Desktop/cache hits may finish before _ready() reaches this wait.
    if is_instance_valid(battle.ally):
        return true
    if t2_ally_load_done:
        return false
    var deadline := Timer.new()
    deadline.one_shot = true
    deadline.ignore_time_scale = true
    deadline.process_mode = Node.PROCESS_MODE_ALWAYS
    deadline.timeout.connect(func(): t2_ally_load_resolved.emit(false))
    add_child(deadline)
    deadline.start(timeout_seconds)
    var loaded: bool = await t2_ally_load_resolved
    deadline.stop()
    deadline.queue_free()
    return loaded and is_instance_valid(battle.ally)

func _t2_build_ui() -> void:
    t2_layer = CanvasLayer.new()
    t2_layer.layer = 20
    add_child(t2_layer)
    t2_dialogue = DialogueScene.instantiate()
    if t5_training_preview:
        t2_dialogue.dialogue_font = load("res://assets/event_idle/sa2_t6_ja.otf") as Font
    t2_layer.add_child(t2_dialogue)
    t2_dialogue.dialogue_closed.connect(_t2_on_dialogue_closed)
    t2_dialogue.line_changed.connect(_t2_on_line_changed)
    t2_label = Label.new()
    t2_label.position = Vector2(22, 72)
    t2_label.add_theme_font_size_override("font_size", 22)
    t2_layer.add_child(t2_label)
    if not t5_training_preview:
        t2_combat_controls = Control.new()
        t2_combat_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
        t2_layer.add_child(t2_combat_controls)
        var attack_button := Button.new()
        attack_button.text = "攻撃"
        attack_button.position = Vector2(1080, 525)
        attack_button.custom_minimum_size = Vector2(150, 78)
        attack_button.pressed.connect(func(): t2_manual.attack_press())
        t2_combat_controls.add_child(attack_button)
        var dodge_button := Button.new()
        dodge_button.text = "回避／防御"
        dodge_button.position = Vector2(900, 614)
        dodge_button.custom_minimum_size = Vector2(184, 78)
        dodge_button.pressed.connect(func(): t2_manual.dodge())
        t2_combat_controls.add_child(dodge_button)
    t2_result_button = Button.new()
    t2_result_button.position = Vector2(520, 440)
    t2_result_button.custom_minimum_size = Vector2(260, 90)
    t2_result_button.hide()
    t2_result_button.pressed.connect(_t2_result_action)
    t2_layer.add_child(t2_result_button)
    if t5_training_preview:
        t2_result_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        t2_result_button.position = Vector2(16, 160)
        t2_result_button.custom_minimum_size = Vector2(260, 72)
        t2_result_button.add_theme_font_size_override("font_size", 26)
        t6_retry_button = Button.new()
        t6_retry_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
        t6_retry_button.position = Vector2(-276, 160)
        t6_retry_button.custom_minimum_size = Vector2(260, 72)
        t6_retry_button.add_theme_font_size_override("font_size", 26)
        t6_retry_button.text = "もう一度"
        t6_retry_button.hide()
        t6_retry_button.pressed.connect(_t6_retry)
        t2_layer.add_child(t6_retry_button)
        var button_style := StyleBoxFlat.new()
        button_style.bg_color = Color(0.04, 0.05, 0.09, 0.94)
        button_style.border_color = Color(0.72, 0.57, 0.32)
        button_style.set_border_width_all(2)
        button_style.set_corner_radius_all(12)
        for button in [t2_result_button, t6_retry_button]:
            button.add_theme_stylebox_override("normal", button_style)
            var hover := button_style.duplicate() as StyleBoxFlat
            hover.bg_color = Color(0.16, 0.18, 0.26, 0.96)
            button.add_theme_stylebox_override("hover", hover)
            button.add_theme_stylebox_override("pressed", hover)

func _t2_save() -> void:
    if not t2_demo and not t5_training_preview:
        t2_flow.save_to(NORMAL_SAVE)

func _t2_open_dialogue(event_id: String, index: int = 0) -> void:
    var db := DB.new()
    var entry: Dictionary = db.load_event(T5_DIALOGUE_ID if t5_training_preview else event_id)
    if entry.is_empty() or not t2_dialogue.start(entry, index):
        push_error("SA2_T2_FAIL: dialogue cannot load: " + db.last_error)
        get_tree().quit(1)
        return
    t2_label.text = "演習前の会話"

func _t2_on_line_changed(index: int, _line_id: String) -> void:
    if t2_flow.mode == Flow.DIALOGUE:
        t2_flow.set_dialogue_line_index(index)
        _t2_save()

func _t2_on_dialogue_closed() -> void:
    if not t2_flow.finish_dialogue():
        push_error("SA2_T2_FAIL: invalid dialogue completion")
        return
    _t2_save()
    if t5_training_preview:
        await _t5_reveal_training()
    else:
        _t2_start_training(false)

func _t2_start_training(resume: bool) -> void:
    var checkpoint: Vector3 = t2_flow.return_position if t5_training_preview else t2_rana.position
    if not resume and not t2_flow.enter_battle(EVENT_ID, checkpoint):
        push_error("SA2_T2_FAIL: cannot transition into battle")
        return
    if resume and t2_flow.mode != Flow.INSTANCE:
        push_error("SA2_T2_FAIL: invalid resume mode")
        return
    if t5_training_preview:
        t2_rana.hide()
        t2_rana.position = t2_flow.return_position
        t2_manual.set_process_unhandled_key_input(true)
        t2_label.show()
    for e in battle.enemies.duplicate():
        battle.remove_enemy(e)
    _t2_build_arena()
    t2_kills = 0
    t2_done = false
    t6_finishing = false
    t2_result_button.hide()
    if t5_training_preview:
        t6_retry_button.hide()
        ui.pad.reset_input()
        t2_manual.reset_training()
        battle.ally_ult = battle.ULT_MAX # Let the tutorial teach all four techniques in one attempt.
    t2_lily.position = Vector3(0, 0, 0)
    t2_lily.face = 1
    t2_lily.state = "move"
    t2_manual.locked = t5_transitioning
    t2_manual.move_in = Vector2.ZERO
    battle.hp_max = 100.0
    battle.hp = battle.hp_max
    for x in [2.3, 4.4]:
        var foe = battle.spawn("1", Vector3(x, 0, 0))
        foe.hp_max = 24.0
        foe.hp = 24.0
        foe.dmg = 5
        foe.sp = 0.65
        _t2_build_target(foe)
    t2_active = true
    _t2_update_training_label()
    if t5_training_preview and not t5_transitioning:
        ui.set_controls_enabled(true)
    _t2_save()

## A distinct, nonlethal greybox training area; existing Enemy objects still own real hit/HP logic.
func _t2_build_arena() -> void:
    if t2_arena != null and is_instance_valid(t2_arena):
        t2_arena.queue_free()
    t2_arena = Node3D.new()
    t2_arena.name = "T2 Nonlethal Training Area"
    add_child(t2_arena)
    var floor_mesh := MeshInstance3D.new()
    var floor_shape := PlaneMesh.new()
    floor_shape.size = Vector2(11.0, 6.0)
    floor_mesh.mesh = floor_shape
    floor_mesh.position = Vector3(2.0, 0.025, 0)
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color(0.12, 0.16, 0.21, 0.88)
    floor_mat.metallic = 0.25
    floor_mesh.material_override = floor_mat
    t2_arena.add_child(floor_mesh)
    for x in [-3.3, 7.3]:
        for z in [-2.6, 2.6]:
            var post := MeshInstance3D.new()
            var post_mesh := CylinderMesh.new()
            post_mesh.top_radius = 0.12
            post_mesh.bottom_radius = 0.17
            post_mesh.height = 1.8
            post.mesh = post_mesh
            post.position = Vector3(x, 0.9, z)
            var post_mat := StandardMaterial3D.new()
            post_mat.albedo_color = Color(0.29, 0.25, 0.2)
            post_mat.metallic = 0.75
            post.material_override = post_mat
            t2_arena.add_child(post)

func _t2_build_target(foe) -> void:
    # Replace the soldier appearance with an unmistakably mechanical practice dummy.
    foe.sprite.hide()
    var shell := Node3D.new()
    shell.name = "Nonlethal mechanical target"
    foe.add_child(shell)
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.32, 0.48, 0.58)
    metal.metallic = 0.8
    metal.roughness = 0.42
    var torso := MeshInstance3D.new()
    var body := CylinderMesh.new()
    body.top_radius = 0.27
    body.bottom_radius = 0.37
    body.height = 1.18
    torso.mesh = body
    torso.position.y = 0.88
    torso.material_override = metal
    shell.add_child(torso)
    var head := MeshInstance3D.new()
    var cap := SphereMesh.new()
    cap.radius = 0.23
    cap.height = 0.46
    head.mesh = cap
    head.position.y = 1.66
    head.material_override = metal
    shell.add_child(head)
    var mark := Label3D.new()
    mark.text = "TARGET"
    mark.font_size = 34
    mark.position.y = 2.22
    mark.modulate = Color(0.54, 0.9, 1.0)
    shell.add_child(mark)

func _on_foe_killed(_e) -> void:
    if t2_active:
        t2_kills += 1
        if t2_kills >= 2 and not t2_done:
            _t2_end(true)
    else:
        super._on_foe_killed(_e)

func _process(delta: float) -> void:
    super._process(delta)
    if t5_training_preview and battle != null:
        for foe in battle.enemies:
            if foe.state == "dying":
                var shell := foe.get_node_or_null("Nonlethal mechanical target") as Node3D
                if shell != null:
                    var progress := clampf(float(foe.die_t) / 0.75, 0.0, 1.0)
                    shell.rotation.z = float(foe.die_dir) * progress * PI * 0.5
                    shell.scale = Vector3.ONE * (1.0 - progress * 0.8)
    if is_instance_valid(t5_rana_idle) and t5_rana_idle.visible:
        t5_idle_elapsed = fmod(t5_idle_elapsed + delta, 3.0)
        var frame := int(t5_idle_elapsed * 12.0)
        t5_rana_idle.frame = frame
        t5_lily_idle.frame = frame
    if _t5_is_approaching():
        t5_talk_button.visible = _t5_within_talk_range()
    if t5_training_preview and is_instance_valid(t2_result_button) and t2_result_button.visible:
        _t6_layout_result()
    if t5_training_preview and is_instance_valid(t2_label):
        t2_label.size.x = 340
        t2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        t2_label.position = Vector2((get_viewport().get_visible_rect().size.x - 340) * 0.5, 22)
    if t6_finishing:
        if t2_lily.state == "move" and battle.enemies.is_empty():
            t6_finishing = false
            _t2_finish_result(t6_won)
        return
    if not t2_active or t2_done:
        return
    if battle.hp <= 0.0:
        _t2_end(false)
        return
    _t2_update_training_label()

func _t2_update_training_label() -> void:
    if t5_training_preview:
        t2_label.text = "模擬標的 %d/2" % t2_kills
    else:
        t2_label.text = "模擬標的 %d/2   HP %d   [WASD] 移動 [J] 攻撃 [K] 回避・防御" % [t2_kills, int(battle.hp)]

func _t2_end(won: bool) -> void:
    if t2_done:
        return
    t2_done = true
    if t5_training_preview:
        t2_manual.combat_enabled = false
        t2_manual.move_in = Vector2.ZERO
        t6_finishing = true
        t6_won = won
        if not won:
            for foe in battle.enemies.duplicate():
                battle.remove_enemy(foe)
        return
    _t2_finish_result(won)

func _t2_finish_result(won: bool) -> void:
    t2_active = false
    t2_manual.locked = not t5_training_preview
    t2_manual.move_in = Vector2.ZERO
    if not t2_flow.finish_battle(won):
        push_error("SA2_T2_FAIL: invalid battle finish")
        return
    _t2_save()
    _t2_show_result()

func _t2_show_result() -> void:
    var won: bool = t2_flow.result == "win"
    t2_label.text = "演習クリア" if won else "演習失敗"
    t2_result_button.text = "探索へ戻る" if won or t5_training_preview else "再挑戦"
    if t5_training_preview:
        t6_retry_button.show()
    if t5_training_preview:
        _t6_layout_result()
    t2_result_button.show()

func _t2_result_action() -> void:
    var won: bool = t2_flow.result == "win"
    if not t2_flow.return_to_explore():
        push_error("SA2_T2_FAIL: cannot restore exploration")
        return
    _t2_save()
    if won or t5_training_preview:
        _t2_restore_exploration()
    else:
        _t2_start_training(false)

func _t6_layout_result() -> void:
    var center_x := get_viewport().get_visible_rect().size.x * 0.5
    t2_result_button.position = Vector2(center_x + 16, 160)
    t6_retry_button.position = Vector2(center_x - 276, 160)

func _t6_retry() -> void:
    if t2_flow.mode != Flow.RESULT:
        return
    t2_flow.mode = Flow.EXPLORE
    t2_flow.result = ""
    _t2_start_training(false)

func _t2_restore_exploration() -> void:
    # Shared by live victory and a saved exploration state.
    player = t2_rana
    battle.player = t2_rana
    battle.ally = t2_lily
    t2_manual.locked = true
    t2_manual.queue_free()
    if is_instance_valid(t2_combat_controls):
        t2_combat_controls.queue_free()
    if t2_arena != null and is_instance_valid(t2_arena):
        t2_arena.queue_free()
    t2_lily.set_physics_process(true)
    t2_rana.show()
    t2_rana.locked = false
    t2_rana.set_physics_process(true)
    t2_rana.position = t2_flow.player_position
    ui.player = t2_rana
    ui.basic_combat_only = false
    ui.lily_controls = false
    battle.manual_ally = null
    if is_instance_valid(t6_retry_button):
        t6_retry_button.hide()
    ui.set_controls_enabled(true)
    hud.show()
    t2_result_button.hide()
    t2_label.text = "演習完了・探索へ復帰"

func _input(event: InputEvent) -> void:
    if t5_transitioning:
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER and _t5_is_approaching() and _t5_within_talk_range():
        _t5_open_briefing()
        get_viewport().set_input_as_handled()
        return
    var legacy_touch_active := _t5_is_approaching() if t5_training_preview else t2_active
    if t2_manual == null or not legacy_touch_active:
        return
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < 550 and t2_finger < 0:
            t2_finger = event.index
            t2_touch_origin = event.position
        elif not event.pressed and event.index == t2_finger:
            t2_finger = -1
            t2_manual.move_in = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == t2_finger:
        t2_manual.move_in = ((event.position - t2_touch_origin) / 90.0).limit_length(1.0)

func _t5_begin_exploration() -> void:
    var font: Font = t2_dialogue.dialogue_font
    var control_theme := Theme.new()
    control_theme.default_font = font
    t2_result_button.theme = control_theme
    t6_retry_button.theme = control_theme
    t2_label.add_theme_font_override("font", font)
    t2_label.position.y = 112
    t2_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
    t2_label.add_theme_constant_override("outline_size", 6)
    var panel := t2_dialogue.get_node("Panel") as PanelContainer
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.04, 0.08, 0.88)
    style.border_color = Color(0.64, 0.49, 0.28, 0.8)
    style.border_width_top = 2
    style.set_corner_radius_all(8)
    panel.add_theme_stylebox_override("panel", style)
    t2_label.text = "公開演習  ›  教官のいる受付へ"
    t2_manual.locked = false
    t2_manual.set_process_unhandled_key_input(false)
    t2_rana.position = T5_MEETING_POINT + Vector3(0.55, 0, -0.55)
    t2_rana.show()

    t5_meeting_marker = Label3D.new()
    t5_meeting_marker.text = "演習受付"
    t5_meeting_marker.font = font
    t5_meeting_marker.font_size = 48
    t5_meeting_marker.outline_size = 8
    t5_meeting_marker.position = T5_MEETING_POINT + Vector3.UP * 2.45
    t5_meeting_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(t5_meeting_marker)

    t5_talk_button = Button.new()
    t5_talk_button.text = "話す  [Enter]"
    t5_talk_button.add_theme_font_override("font", font)
    t5_talk_button.add_theme_font_size_override("font_size", 24)
    t5_talk_button.custom_minimum_size = Vector2(194, 66)
    t5_talk_button.position = Vector2(1044, 602)
    t5_talk_button.focus_mode = Control.FOCUS_NONE
    t5_talk_button.hide()
    t5_talk_button.pressed.connect(_t5_open_briefing)
    t2_layer.add_child(t5_talk_button)

    var fade_layer := CanvasLayer.new()
    fade_layer.layer = 100
    add_child(fade_layer)
    t5_fade = ColorRect.new()
    t5_fade.color = Color.BLACK
    t5_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    t5_fade.hide()
    fade_layer.add_child(t5_fade)

    t5_dialogue_camera = Camera3D.new()
    t5_dialogue_camera.fov = 32.0
    add_child(t5_dialogue_camera)
    t5_instructor = Sprite3D.new()
    t5_instructor.texture = preload("res://assets/npc/man_1.webp")
    t5_instructor.pixel_size = 1.85 / t5_instructor.texture.get_height()
    t5_instructor.offset.y = t5_instructor.texture.get_height() * 0.5
    t5_instructor.flip_h = true
    t5_instructor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    t5_instructor.hide()
    add_child(t5_instructor)
    t5_rana_idle = _t5_make_idle_sprite("RanaEventIdle", "rana", Vector2(105, 367.5), 1.85)
    t5_lily_idle = _t5_make_idle_sprite("LilyEventIdle", "lily", Vector2(115, 371.5), t2_lily.height_m)

func _t5_make_idle_sprite(node_name: String, actor_id: String, pivot: Vector2, height_m: float) -> Sprite3D:
    var sprite := Sprite3D.new()
    sprite.name = node_name
    sprite.texture = load("res://assets/event_idle/%s_idle.webp" % actor_id) as Texture2D
    sprite.hframes = 6
    sprite.vframes = 6
    sprite.offset = Vector2(100 - pivot.x, pivot.y - 188)
    sprite.pixel_size = height_m / pivot.y
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    sprite.hide()
    add_child(sprite)
    return sprite

func _t5_is_approaching() -> bool:
    return is_instance_valid(t5_talk_button) and t2_flow.mode == Flow.EXPLORE and t2_flow.event_id.is_empty() and not t2_flow.completed.get(EVENT_ID, false)

func _t5_within_talk_range() -> bool:
    return t2_lily.position.distance_to(T5_MEETING_POINT) <= T5_TALK_DISTANCE

func _t5_open_briefing() -> void:
    if not _t5_is_approaching() or not _t5_within_talk_range():
        return
    if not t2_flow.begin_dialogue(EVENT_ID, t2_lily.position):
        return
    t2_manual.locked = true
    t2_manual.move_in = Vector2.ZERO
    t2_finger = -1
    t5_talk_button.hide()
    await _t5_fade_to_black()

    t2_label.hide()
    t5_meeting_marker.hide()
    _t5_stage_briefing()
    await _t5_fade_from_black()
    _t2_open_dialogue(EVENT_ID)

func _t5_stage_briefing() -> void:
    t2_lily.position = T5_MEETING_POINT + Vector3(-1.35, 0, 0.15)
    t2_rana.position = T5_MEETING_POINT + Vector3(-0.1, 0, -0.25)
    t5_instructor.position = T5_MEETING_POINT + Vector3(1.55, 0, -0.12)
    t5_instructor.show()

    t2_rana.hide()
    t2_lily.hide()
    t5_rana_idle.position = t2_rana.position
    t5_lily_idle.position = t2_lily.position
    t5_idle_elapsed = 0.0
    t5_rana_idle.frame = 0
    t5_lily_idle.frame = 0
    t5_rana_idle.show()
    t5_lily_idle.show()
    t5_dialogue_camera.position = T5_MEETING_POINT + Vector3(0.55, 2.2, 6.1)
    t5_dialogue_camera.look_at(T5_MEETING_POINT + Vector3(0.15, 0.97, 0))
    t5_dialogue_camera.make_current()

func _t5_reveal_training() -> void:
    await _t5_fade_to_black()
    t5_instructor.hide()
    t5_rana_idle.hide()
    t5_lily_idle.hide()
    t2_lily.show()
    _t2_start_training(false)
    t2_lily._show("idle", 0)
    _place_cam(true)
    cam.make_current()
    await _t5_fade_from_black()
    t2_manual.locked = false
    ui.set_controls_enabled(true)

func _t5_fade_to_black() -> void:
    t5_transitioning = true
    battle.cine = true
    t5_fade.color.a = 0.0
    t5_fade.show()
    await create_tween().tween_property(t5_fade, "color:a", 1.0, 0.22).finished
    await get_tree().process_frame

func _t5_fade_from_black() -> void:
    var fade := create_tween()
    fade.tween_interval(0.10)
    fade.tween_property(t5_fade, "color:a", 0.0, 0.30)
    await fade.finished
    t5_fade.hide()
    battle.cine = false
    t5_transitioning = false

func _t2_movie_demo() -> void:
    await _t2_frames(36)
    if t2_flow.mode == Flow.DIALOGUE:
        for i in 6:
            t2_dialogue.advance()
            await _t2_frames(5)
    if not t2_active:
        push_error("SA2_T2_MOVIE_FAIL: battle did not start")
        get_tree().quit(1)
        return
    # Lose once to a real enemy hit, and retry through the actual FlowState transition.
    battle.hp = 4.0
    for i in 300:
        if t2_flow.mode == Flow.RESULT:
            break
        await _t2_frames(1)
    if t2_flow.result != "lose":
        push_error("SA2_T2_MOVIE_FAIL: enemy damage did not produce defeat")
        get_tree().quit(1)
        return
    _t2_result_action()
    if t2_flow.mode != Flow.INSTANCE or int(t2_flow.attempts.get(EVENT_ID, 0)) != 2:
        push_error("SA2_T2_MOVIE_FAIL: retry state/attempt count")
        get_tree().quit(1)
        return
    await _t2_frames(8)
    # Use a real enemy attack wind-up, then the same dodge button for a successful timed guard.
    var guarding_foe = battle.enemies[0]
    guarding_foe.position = t2_lily.position + Vector3(1.2, 0, 0)
    guarding_foe.face = -1
    guarding_foe._start_atk()
    guarding_foe.atk.t = float(guarding_foe.atk.hit_t) - 0.24
    t2_manual.dodge()
    if t2_manual.guard_count != 1:
        push_error("SA2_T2_MOVIE_FAIL: timed guard did not activate")
        get_tree().quit(1)
        return
    await _t2_frames(8)
    t2_manual.move_in = Vector2.RIGHT
    await _t2_frames(9)
    t2_manual.move_in = Vector2.ZERO
    t2_manual.dodge()
    await _t2_frames(20)
    for attempt in 90:
        if t2_done:
            break
        var e = t2_lily._nearest()
        if e != null and e.position.x - t2_lily.position.x > 1.6:
            t2_manual.move_in = Vector2.RIGHT
            await _t2_frames(8)
            t2_manual.move_in = Vector2.ZERO
        t2_manual.attack_press()
        await _t2_frames(28)
    if not t2_done or t2_flow.result != "win" or t2_manual.attack_count == 0 or t2_manual.dodge_count == 0 or t2_manual.guard_count == 0:
        push_error("SA2_T2_MOVIE_FAIL: not a complete real combat loop")
        get_tree().quit(1)
        return
    await _t2_frames(25)
    _t2_result_action()
    await _t2_frames(30)
    if t2_flow.mode != Flow.EXPLORE or not t2_flow.completed.get(EVENT_ID, false):
        push_error("SA2_T2_MOVIE_FAIL: exploration restore")
        get_tree().quit(1)
        return
    print("SA2_T2_MOVIE_PASS: dialogue, real enemy-hit defeat/retry, Lily move/attack/dodge/just-guard, two targets, win, exploration restore")
    get_tree().quit(0)

func _t2_frames(n: int) -> void:
    for i in n:
        await get_tree().process_frame
