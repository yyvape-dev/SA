extends CanvasLayer
var host
var status:Label
var hp:ProgressBar
var start_button:Button
var guide_button:Button
var attack_button:Button
var dodge_button:Button
var retry_save:Button

func button(label:String, parent:Node, callback:Callable) -> Button:
    var b=Button.new();b.text=label;b.custom_minimum_size=Vector2(160,62)
    b.add_theme_font_size_override("font_size",22);b.pressed.connect(callback);parent.add_child(b)
    return b

func _ready():
    layer=25
    var panel=PanelContainer.new();panel.position=Vector2(16,16);panel.custom_minimum_size=Vector2(560,150);add_child(panel)
    var box=VBoxContainer.new();panel.add_child(box)
    status=Label.new();status.add_theme_font_size_override("font_size",25);box.add_child(status)
    hp=ProgressBar.new();hp.custom_minimum_size=Vector2(530,25);box.add_child(hp)
    start_button=button("START / RETRY [SPACE]",box,host.start_encounter)
    retry_save=button("RETRY SAVE",box,host.retry_result_save)
    var root=Control.new();root.set_anchors_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
    var row=HBoxContainer.new();root.add_child(row)
    row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    row.offset_left=-590;row.offset_top=-90;row.offset_right=-18;row.offset_bottom=-18
    guide_button=button("GUIDE [E]",row,host.guide_residents)
    attack_button=button("ATTACK [J]",row,func():
        if host.lease.driver!=null:host.lease.driver.attack_press())
    dodge_button=button("DODGE / GUARD [K]",row,func():
        if host.lease.driver!=null:host.lease.driver.dodge())

func _process(_delta:float):
    if host.encounter==null:return
    var e=host.encounter
    var fighting=e.phase=="street"
    status.text="C2-09  |  %s\nMACHINES %d/2   RESIDENTS %d/3\n%s"%[e.phase.to_upper(),e.stopped.size(),e.safe.size(),host.message]
    hp.max_value=host.battle.hp_max;hp.value=host.battle.hp
    start_button.visible=e.phase in ["explore","safe"] and not host.blocked_save
    retry_save.visible=e.phase=="result_pending"
    guide_button.visible=fighting and not host.evacuation.moving and e.safe.size()<3
    attack_button.visible=fighting;dodge_button.visible=fighting
