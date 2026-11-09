extends Node
## TD-only presentation/input bridge. Combat simulation stays in the existing Manual/Driver.
const TouchUI=preload('res://scripts/touch_ui.gd')
var host
var kind:=''
var controls
var target
var raw_input_owner
var raw_input_was_enabled:=false
var guide_parent
var guide_index:=-1

class LilyPad extends TouchUI._Pad:
    func _btns()->Dictionary:
        var existing=super._btns()
        return {'atk':existing.atk,'dodge':existing.dodge}

class ManualProxy extends Node3D:
    var target
    var through_driver:=false
    func manual():
        if not is_instance_valid(target):return null
        return target.manual if through_driver else target
    func enabled()->bool:
        var m=manual()
        return is_instance_valid(m) and not m.locked
    var move_in:Vector2:
        get:
            var m=manual()
            return m.move_in if is_instance_valid(m) else Vector2.ZERO
        set(value):
            var m=manual()
            if is_instance_valid(m):m.move_in=value
    func attack_press():
        if enabled():target.attack_press()
    func attack_release():
        var m=manual()
        if is_instance_valid(m):m.attack_release()
    func dodge():
        # T3 MUST use Driver.dodge(), preserving its floor/blocker guard filter.
        if enabled():target.dodge()

class LilyPanel extends CanvasLayer:
    var main=null
    var player:Node3D
    var battle
    var pad
    func _ready():
        layer=26
        pad=LilyPad.new();pad.ui=self
        pad.set_anchors_preset(Control.PRESET_FULL_RECT)
        pad.mouse_filter=Control.MOUSE_FILTER_IGNORE
        add_child(pad)

func setup(owner,spot:String):
    host=owner;kind=spot;process_priority=110

func _candidate():
    if not is_instance_valid(host):return null
    if kind=='t2':
        if host.t2_active and not host.t2_done and is_instance_valid(host.t2_manual) and not host.t2_manual.locked:return host.t2_manual
    elif kind=='t3' and host.encounter!=null:
        if host.encounter.phase=='street' and is_instance_valid(host.lease.driver) and not host.lease.driver.manual.locked:return host.lease.driver
    return null

func _process(_delta:float):
    if not is_instance_valid(host):
        release();return
    # The old HUD updates visibility every frame; hide only its temporary combat buttons.
    if kind=='t2' and is_instance_valid(host.t2_combat_controls):host.t2_combat_controls.hide()
    elif kind=='t3' and is_instance_valid(host.street_hud):
        host.street_hud.attack_button.hide();host.street_hud.dodge_button.hide()
    var next=_candidate()
    if not is_instance_valid(next):
        if is_instance_valid(controls):release()
        return
    if next!=target or not is_instance_valid(controls):
        release();acquire(next)
    if is_instance_valid(controls) and kind=='t3':
        host.street_hud.guide_button.position=Vector2(maxf(0,get_viewport().get_visible_rect().size.x-240),110)

func acquire(next):
    target=next
    raw_input_owner=host if kind=='t2' else target
    raw_input_was_enabled=raw_input_owner.is_processing_input()
    raw_input_owner.set_process_input(false)
    var m=target if kind=='t2' else target.manual
    m.move_in=Vector2.ZERO
    if kind=='t2':host.t2_finger=-1
    else:target.finger=-1
    controls=LilyPanel.new();controls.battle=host.battle
    var proxy=ManualProxy.new();proxy.target=target;proxy.through_driver=kind=='t3'
    controls.player=proxy;controls.add_child(proxy);add_child(controls)
    if kind=='t3':
        var guide=host.street_hud.guide_button
        guide_parent=guide.get_parent();guide_index=guide.get_index()
        guide.reparent(controls)

func clear_touch():
    if not is_instance_valid(controls):return
    controls.pad.stick_id=-1;controls.pad.btn_down.clear()
    controls.player.move_in=Vector2.ZERO;controls.player.attack_release()
    controls.pad.queue_redraw()

func _notification(what:int):
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:clear_touch()

func release():
    if is_instance_valid(controls):
        controls.pad.set_process_input(false)
        clear_touch()
        if kind=='t3' and is_instance_valid(host) and is_instance_valid(host.street_hud) and is_instance_valid(guide_parent):
            var guide=host.street_hud.guide_button
            guide.reparent(guide_parent)
            guide_parent.move_child(guide,mini(guide_index,guide_parent.get_child_count()-1))
        remove_child(controls);controls.queue_free();controls=null
    if is_instance_valid(raw_input_owner):raw_input_owner.set_process_input(raw_input_was_enabled)
    raw_input_owner=null;target=null;guide_parent=null;guide_index=-1

func _exit_tree():release()
