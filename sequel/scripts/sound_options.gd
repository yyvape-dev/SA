extends CanvasLayer
## Touch-safe, device-local audio preferences.
var audio: Node
var panel: PanelContainer
var button: Button
var input_shield: Control
var bgm_slider: HSlider
var se_slider: HSlider
var mute_toggle: CheckButton
var bgm_value: Label
var se_value: Label

class SpeakerButton extends Button:
    func _draw():
        var c := Color(0.9, 0.95, 1.0, 0.75)
        draw_rect(Rect2(13, 22, 6, 12), c)
        draw_colored_polygon(PackedVector2Array([Vector2(19,22),Vector2(28,15),Vector2(28,41),Vector2(19,34)]), c)
        draw_arc(Vector2(26,28), 11, -0.8, 0.8, 16, c, 2.0, true)
        draw_arc(Vector2(26,28), 17, -0.8, 0.8, 20, c, 2.0, true)

func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("sound_options")
    var host := Control.new()
    host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(host)
    var font = load("res://assets/event_idle/sa2_sound_ja.otf")
    if font != null:
        host.theme = Theme.new()
        host.theme.default_font = font
        host.theme.default_font_size = 20
    input_shield = Control.new()
    input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
    host.add_child(input_shield)
    input_shield.hide()
    button = SpeakerButton.new()
    button.name = "SoundButton"
    button.tooltip_text = "サウンド設定"
    button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    button.position = Vector2(-72, 12)
    button.size = Vector2(56, 56)
    button.focus_mode = Control.FOCUS_NONE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.03, 0.04, 0.08, 0.38)
    style.set_corner_radius_all(18)
    button.add_theme_stylebox_override("normal", style)
    host.add_child(button)
    button.pressed.connect(toggle_panel)
    panel = PanelContainer.new()
    panel.name = "SoundPanel"
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    panel.position = Vector2(-364, 78)
    panel.size = Vector2(348, 250)
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color(0.025, 0.035, 0.065, 0.95)
    skin.border_color = Color(0.5, 0.65, 0.8, 0.45)
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(14)
    skin.content_margin_left = 20; skin.content_margin_right = 20
    skin.content_margin_top = 16; skin.content_margin_bottom = 16
    panel.add_theme_stylebox_override("panel", skin)
    host.add_child(panel)
    var rows := VBoxContainer.new()
    rows.add_theme_constant_override("separation", 12)
    panel.add_child(rows)
    var title := Label.new()
    title.text = "サウンド"
    rows.add_child(title)
    var bgm := _slider_row(rows, "BGM", audio.bgm_gain)
    bgm_slider = bgm[0]; bgm_value = bgm[1]
    var se := _slider_row(rows, "SE", audio.se_gain)
    se_slider = se[0]; se_value = se[1]
    mute_toggle = CheckButton.new()
    mute_toggle.text = "ミュート"
    mute_toggle.button_pressed = audio.muted
    rows.add_child(mute_toggle)
    var close := Button.new()
    close.text = "閉じる"
    rows.add_child(close)
    close.pressed.connect(toggle_panel)
    bgm_slider.value_changed.connect(func(_v): _changed())
    se_slider.value_changed.connect(func(_v): _changed())
    mute_toggle.toggled.connect(func(_v): _changed())
    panel.hide()

func _slider_row(rows: VBoxContainer, title: String, gain: float) -> Array:
    var row := HBoxContainer.new()
    rows.add_child(row)
    var label := Label.new()
    label.text = title
    label.custom_minimum_size.x = 48
    row.add_child(label)
    var slider := HSlider.new()
    slider.min_value = 0; slider.max_value = 100; slider.step = 1
    slider.value = round(gain * 100)
    slider.custom_minimum_size = Vector2(164, 36)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value := Label.new()
    value.text = "%d%%" % slider.value
    value.custom_minimum_size.x = 52
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value)
    return [slider, value]

func _changed() -> void:
    bgm_value.text = "%d%%" % bgm_slider.value
    se_value.text = "%d%%" % se_slider.value
    audio.set_audio_options(bgm_slider.value / 100.0, se_slider.value / 100.0, mute_toggle.button_pressed)

func toggle_panel() -> void:
    panel.visible = not panel.visible
    input_shield.visible = panel.visible
    for pad in get_tree().get_nodes_in_group("sound_touch_pad"):
        pad.reset_input()

func blocks_touch(pos: Vector2) -> bool:
    return panel.visible or button.get_global_rect().has_point(pos)
