extends SceneTree
var passed:=0
func _initialize():call_deferred('run')
func check(value:bool,label:String)->bool:
    if not value:printerr('TD_LILY_CONTROLS_FAIL: '+label);quit(1);return false
    passed+=1;return true
func frames(n:int):
    for i in n:await physics_frame
func touch(point:Vector2,down:bool,index:int=0):
    var event=InputEventScreenTouch.new();event.position=point;event.pressed=down;event.index=index;Input.parse_input_event(event)
func drag(point:Vector2,index:int=0):
    var event=InputEventScreenDrag.new();event.position=point;event.index=index;Input.parse_input_event(event)
func count_nodes(node:Node)->int:
    var total:=1
    for child in node.get_children():total+=count_nodes(child)
    return total
func run():
    var script=load('res://scripts/sa2_td_lily_controls.gd')
    if not check(script!=null and script.can_instantiate(),'original Pad subclass compiles'):return
    DirAccess.remove_absolute('user://sa2_t2_progress.json')
    root.size=Vector2i(1280,720)
    var host=load('res://sa2_t2_playable.tscn').instantiate();root.add_child(host)
    for i in 600:
        if is_instance_valid(host.t2_dialogue):break
        await frames(1)
    if not check(is_instance_valid(host.t2_dialogue),'real T2 ready'):return
    for i in 10:
        if host.t2_active:break
        host.t2_dialogue.advance()
    var bridge=script.new();bridge.setup(host,'t2');root.add_child(bridge);await frames(3)
    if not check(is_instance_valid(bridge.controls) and not host.is_processing_input(),'T2 single touch owner'):return
    if not check(not host.t2_combat_controls.visible and not host.ui.pad.is_processing_input(),'old touch and rectangles disabled'):return
    var pad=bridge.controls.pad
    var buttons=pad._btns()
    if not check(buttons.size()==2 and buttons.atk[0].is_equal_approx(Vector2(1105,530)) and buttons.atk[1]==78 and buttons.dodge[0].is_equal_approx(Vector2(935,615)) and buttons.dodge[1]==50,'existing720 attack/dodge geometry'):return
    touch(Vector2(200,550),true);drag(Vector2(290,550));await frames(1)
    if not check(host.t2_manual.move_in.is_equal_approx(Vector2.RIGHT) and host.t2_finger==-1,'legacy joystick owns movement'):return
    var attacks=host.t2_manual.attack_count
    touch(buttons.atk[0],true,1);touch(buttons.atk[0],false,1);await frames(1)
    if not check(host.t2_manual.attack_count==attacks+1 and pad.stick_id==0,'multitouch attack keeps movement finger'):return
    bridge.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
    if not check(host.t2_manual.move_in==Vector2.ZERO and pad.stick_id==-1 and pad.btn_down.is_empty(),'focus loss cancels held controls'):return
    touch(Vector2(200,550),true);drag(Vector2(290,550))
    touch(Vector2(290,550),false);await frames(1)
    if not check(host.t2_manual.move_in==Vector2.ZERO and pad.btn_down.is_empty(),'release clears direction and held actions'):return
    for i in 180:
        if host.t2_lily.state=='move':break
        await frames(1)
    var dodges=host.t2_manual.dodge_count
    touch(buttons.dodge[0],true,1);touch(buttons.dodge[0],false,1);await frames(1)
    if not check(host.t2_manual.dodge_count==dodges+1,'real manual dodge through legacy UI'):return
    # Test the reusable Pad at a half-height component size; project stretch keeps the root logical height720.
    pad.size=Vector2(780,360)
    buttons=pad._btns()
    if not check(buttons.atk[0].is_equal_approx(Vector2(692.5,265)) and buttons.atk[1]==39,'height-scaled original geometry'):return
    touch(Vector2(100,250),true);drag(Vector2(145,250));await frames(1)
    if not check(host.t2_manual.move_in.is_equal_approx(Vector2.RIGHT),'height-scaled joystick radius'):return
    host.battle.hp=0;await frames(4)
    if not check(not is_instance_valid(bridge.controls) and host.is_processing_input() and host.t2_manual.move_in==Vector2.ZERO,'loss clears panel and restores input owner'):return
    for i in 20:
        host._t2_result_action();await frames(4)
        if not check(is_instance_valid(bridge.controls) and count_nodes(bridge)==4,'retry has exactly one panel/proxy/pad'):return
        host.battle.hp=0;await frames(4)
        if not check(bridge.get_child_count()==0,'retry release leaves no control nodes'):return
    bridge.queue_free();host.queue_free();await frames(4)
    # Real T3 binding must preserve the Driver guard filter and sole physics loop.
    host=load('res://sa2_t3_playable.tscn').instantiate();host.save_path='user://sa2_td_ui_contract_t3.json'
    DirAccess.remove_absolute(host.save_path);DirAccess.remove_absolute(host.save_path+'.bak')
    root.add_child(host)
    for i in 600:
        if host.ready_for_event:break
        await frames(1)
    if not check(host.ready_for_event,'real T3 ready'):return
    host.start_encounter()
    bridge=script.new();bridge.setup(host,'t3');root.add_child(bridge);await frames(3)
    if not check(is_instance_valid(bridge.controls) and bridge.target==host.lease.driver and not host.lease.driver.is_processing_input(),'T3 binds sole driver; raw touch off'):return
    if not check(host.lease.driver.is_physics_processing() and not host.lease.driver.manual.is_physics_processing() and not host.lily.is_physics_processing(),'one simulation owner retained'):return
    if not check(host.street_hud.guide_button.get_parent()==bridge.controls and host.street_hud.guide_button.position.x>root.size.x/2.0,'guide remains outside left joystick and action region'):return
    pad=bridge.controls.pad;pad.size=Vector2(780,360);buttons=pad._btns()
    touch(Vector2(100,250),true);drag(Vector2(145,250));await frames(1)
    if not check(host.lease.driver.manual.move_in.is_equal_approx(Vector2.RIGHT) and host.lease.driver.finger==-1,'T3 adaptive joystick single writer'):return
    touch(Vector2(145,250),false)
    host.lily.position=Vector3(16.5,0,0);host.lily.state='move';host.lily.inv=0
    var foe=host.battle.enemies[0];foe.position=Vector3(17.1,0,0);foe._start_atk();foe.atk.t=foe.atk.hit_t-0.2
    var manual=host.lease.driver.manual
    var guards=manual.guard_count;dodges=manual.dodge_count
    buttons=pad._btns()
    touch(buttons.dodge[0],true,1);touch(buttons.dodge[0],false,1);Input.flush_buffered_events()
    if not check(manual.guard_count==guards and manual.dodge_count==dodges+1 and not foe.atk.done,'T3 UI guard cannot cross blocker'):return
    host.battle.hp=0;await frames(6)
    if not check(not is_instance_valid(bridge.controls) and host.ui.pad.is_processing_input(),'T3 loss restores exploration pad'):return
    bridge.queue_free();host.queue_free();await frames(4)
    print('TD_LILY_CONTROLS_PASS ',passed);quit()
