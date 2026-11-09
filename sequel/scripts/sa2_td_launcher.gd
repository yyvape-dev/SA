extends Node
## TD-only entry; existing playable scenes and saves remain unchanged.
const Diagnostics=preload('res://scripts/sa2_td_diagnostics.gd')
var probe=Diagnostics.new()
var spot:='menu'
var started:=0
var scene:Node
var status:Label
var menu:VBoxContainer
var panel:PanelContainer
var elapsed:=0.0
var build:='source'
var dirty:=true
var dialogue_font_applied:=false
const FixtureFont=preload('res://assets/td/fixture-sans.otf')
static func scene_path(id:String)->String:
    return {'explore':'res://main.tscn','t2':'res://sa2_t2_playable.tscn','t3':'res://sa2_t3_playable.tscn'}.get(id,'')
func _ready():
    started=Time.get_ticks_msec()
    if FileAccess.file_exists('res://td_build.json'):
        var data=JSON.parse_string(FileAccess.get_file_as_string('res://td_build.json'))
        if data is Dictionary:
            build=str(data.get('sha','source'));dirty=bool(data.get('dirty',true))
    var layer=CanvasLayer.new();layer.layer=100;add_child(layer)
    panel=PanelContainer.new();panel.position=Vector2(8,8);layer.add_child(panel)
    var column=VBoxContainer.new();panel.add_child(column)
    var bar=HBoxContainer.new();column.add_child(bar)
    _button(bar,'TD menu',_return_menu)
    _button(bar,'Save probe',_save_probe)
    _button(bar,'Stats',func():status.visible=not status.visible)
    status=Label.new();status.add_theme_font_size_override('font_size',20);column.add_child(status)
    menu=VBoxContainer.new();column.add_child(menu)
    for id in ['t0','explore','t1','t2','t3']:_button(menu,id.to_upper(),func():_launch(id))
    var tip=Label.new();tip.text='TEST BUILD / landscape recommended\nT1: dialogue fixture; T2: training; T3: street\nNo physical-device acceptance yet';menu.add_child(tip)
    var initial:='menu'
    if OS.has_feature('web'):initial=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('spot') || 'menu'"))
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with('--spot='):initial=arg.trim_prefix('--spot=')
    if initial!='menu':_launch.call_deferred(initial)
func _button(parent:Node,title:String,action:Callable):
    var button=Button.new();button.text=title;button.custom_minimum_size=Vector2(160,82);button.add_theme_font_size_override('font_size',24);parent.add_child(button);button.pressed.connect(action)
func _return_menu():
    # Fresh engine run releases all old input leases and retains browser save.
    if OS.has_feature('web'):JavaScriptBridge.eval("location.href=location.pathname+'?spot=menu'")
    else:get_tree().reload_current_scene()
func _launch(id:String):
    if spot!='menu':return
    if not id in ['t0','t1','explore','t2','t3']:
        status.text='Invalid spot ID';return
    if OS.get_user_data_dir().get_file()!='SA2-TD-Mobile-Spots':
        status.text='TD namespace missing. Use the TD Web build.';return
    spot=id;menu.hide()
    if OS.has_feature('web'):JavaScriptBridge.eval("history.replaceState(null,'',location.pathname+'?spot="+id+"')")
    # Keep diagnostics below the scene HUD and expose only a compact return button.
    status.visible=id=='t0'
    panel.position=Vector2(maxf(8,get_viewport().get_visible_rect().size.x-520),8)
    panel.reset_size.call_deferred()
    if id=='t0':return
    if id=='t1':
        var db=load('res://scripts/sa2_dialogue_database.gd').new()
        scene=load('res://ui/sa2_dialogue_panel.tscn').instantiate()
        var layer=CanvasLayer.new();add_child(layer);layer.add_child(scene)
        _apply_dialogue_font(scene)
        scene.start(db.load_event('C1-06'));return
    scene=load(scene_path(id)).instantiate()
    if id=='t3':scene.save_path='user://sa2_td_t3_progress.json'
    add_child(scene)
func _apply_dialogue_font(dialogue):
    for widget in [dialogue.speaker,dialogue.advance_button]:widget.add_theme_font_override('font',FixtureFont)
    dialogue.body.add_theme_font_override('normal_font',FixtureFont)
    dialogue_font_applied=true
func _save_probe():
    var token=str(Time.get_unix_time_from_system())
    if not probe.write_probe(token):push_error('TD save probe failed')
func _process(delta:float):
    probe.sample(delta);elapsed+=delta
    if elapsed<1.0 or status==null:return
    elapsed=0.0
    panel.position=Vector2(8,8) if spot=='menu' else Vector2(maxf(8,get_viewport().get_visible_rect().size.x-520),8)
    var metrics=probe.report()
    if not dialogue_font_applied and spot=='t2' and is_instance_valid(scene) and is_instance_valid(scene.t2_dialogue):_apply_dialogue_font(scene.t2_dialogue)
    metrics['scene_ready']=spot in ['t0','t1']
    if is_instance_valid(scene) and spot in ['explore','t2','t3']:
        var actor=scene.get('player')
        metrics['scene_ready']=is_instance_valid(actor) and is_instance_valid(scene.get('battle'))
        if is_instance_valid(actor):metrics['player_x']=actor.position.x
        if spot=='t2':metrics['scene_ready']=is_instance_valid(scene.get('t2_lily'))
        if spot=='t3':
            metrics['scene_ready']=scene.ready_for_event
            if scene.encounter!=null:metrics['phase']=scene.encounter.phase
            if scene.street_hud!=null:
                var center=scene.street_hud.start_button.get_global_rect().get_center()
                metrics['start_button']=[center.x,center.y]
    if spot=='t1' and is_instance_valid(scene):
        metrics['dialogue_line']=scene.line_index
        var next_center=scene.advance_button.get_global_rect().get_center()
        metrics['dialogue_next']=[next_center.x,next_center.y]
    if spot=='t2' and is_instance_valid(scene):
        metrics['combat_active']=scene.t2_active
        if is_instance_valid(scene.t2_manual):
            metrics['attacks']=scene.t2_manual.attack_count
            metrics['dodges']=scene.t2_manual.dodge_count
        if is_instance_valid(scene.t2_dialogue):
            metrics['dialogue_active']=scene.t2_dialogue.active
            var next_center=scene.t2_dialogue.advance_button.get_global_rect().get_center()
            metrics['dialogue_next']=[next_center.x,next_center.y]
    metrics['guide_json']=FileAccess.file_exists('res://art/guide/guide.json')
    metrics.merge({'spot':spot,'sha':build,'dirty':dirty,'user_dir':OS.get_user_data_dir(),'elapsed_ms':Time.get_ticks_msec()-started,'fps':Engine.get_frames_per_second(),'persistent':OS.is_userfs_persistent(),'probe':probe.read_probe(),'viewport':str(get_viewport().get_visible_rect().size)})
    status.text='%s | %s\nFPS %s mean %.1f p95 %.1f ms | save %s\n%s'%[spot,build.left(8)+(' DIRTY' if dirty else ''),metrics.fps,metrics.mean_ms,metrics.p95_ms,str(metrics.persistent),str(metrics.probe.get('token','none'))]
    if OS.has_feature('web'):JavaScriptBridge.eval('window.__sa2TD='+JSON.stringify(metrics))
