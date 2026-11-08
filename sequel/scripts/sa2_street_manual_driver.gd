extends Node
const Manual = preload("res://scripts/sa2_t2_lily_manual.gd")
var manual
var actor
var battle
var finger := -1
var touch_origin := Vector2.ZERO

func setup(lily, combat):
    actor=lily;battle=combat
    manual=Manual.new();manual.setup(lily,combat)
    add_child(manual)
    manual.set_physics_process(false)
    manual.set_process_unhandled_key_input(false)

func _physics_process(delta:float):
    var before:Vector3=actor.position
    manual._physics_process(delta)
    battle.resolve_motion(actor,before)

func attack_press():manual.attack_press()
func dodge():
    # Guard candidate selection also obeys floors/blockers, without editing T2 Manual.
    var all:Array=battle.enemies
    battle.enemies=all.filter(func(e):return battle.combat_policy.allows_damage(e,actor,{}))
    manual.dodge()
    battle.enemies=all

func lock():
    manual.locked=true;manual.move_in=Vector2.ZERO;finger=-1
    set_physics_process(false)

func _unhandled_key_input(event:InputEvent):
    if manual.locked or not event is InputEventKey or not event.pressed or event.echo:return
    if event.keycode in [KEY_J,KEY_Z]:attack_press();get_viewport().set_input_as_handled()
    elif event.keycode in [KEY_K,KEY_X]:dodge();get_viewport().set_input_as_handled()

func _input(event:InputEvent):
    if manual==null or manual.locked:return
    var width=get_viewport().get_visible_rect().size.x
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x<width*0.5 and finger<0:
            finger=event.index;touch_origin=event.position
        elif not event.pressed and event.index==finger:
            finger=-1;manual.move_in=Vector2.ZERO
    elif event is InputEventScreenDrag and event.index==finger:
        manual.move_in=((event.position-touch_origin)/90.0).limit_length(1.0)
