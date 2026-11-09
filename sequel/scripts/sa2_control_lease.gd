extends RefCounted
const Driver=preload("res://scripts/sa2_street_manual_driver.gd")
var driver
var host
var saved:Dictionary={}

func acquire(owner):
    host=owner
    saved={"player":host.player,"battle_player":host.battle.player,"ally":host.battle.ally,"ui_visible":host.ui.visible,"rana_visible":host.rana.visible,"rana_physics":host.rana.is_physics_processing(),"lily_physics":host.lily.is_physics_processing(),"locked":host.rana.locked,"cutin_player":host.cutin.player,"rana_input":host.rana.is_processing_unhandled_input(),"room_x":host.battle.ROOM_X,"belt_z":host.battle.BELT_Z,"battle_process":host.battle.process_mode}
    host.rana.set_process_unhandled_input(false)
    host.rana.locked=true;host.rana.move_in=Vector2.ZERO;host.rana.set_physics_process(false);host.rana.hide()
    host.ui.hide();_reset_pad()
    host.ui.pad.set_process_input(false)
    host.player=host.lily;host.battle.player=host.lily;host.battle.ally=null
    host.cutin.player=host.lily
    driver=Driver.new();host.add_child(driver);driver.setup(host.lily,host.battle)

func _reset_pad():
    if host.ui.pad:
        host.ui.pad.stick_id=-1;host.ui.pad.btn_down.clear()
    host.rana.move_in=Vector2.ZERO;host.rana.atk_held=false

func release():
    if saved.is_empty():return
    driver.lock()
    host.remove_child(driver);driver.queue_free();driver=null
    host.player=saved.player;host.battle.player=saved.battle_player;host.battle.ally=saved.ally
    host.rana.visible=saved.rana_visible;host.rana.locked=saved.locked
    host.rana.set_physics_process(saved.rana_physics);host.lily.set_physics_process(saved.lily_physics)
    host.ui.visible=saved.ui_visible;host.ui.pad.set_process_input(true)
    host.battle.ROOM_X=saved.room_x;host.battle.BELT_Z=saved.belt_z;host.battle.process_mode=saved.battle_process
    host.cutin.player=saved.cutin_player
    host.rana.set_process_unhandled_input(saved.rana_input)
    _reset_pad();saved.clear()
