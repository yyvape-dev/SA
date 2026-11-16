extends SceneTree
var host
var retained:Array=[]
var rows:Array=[]
func _initialize():call_deferred("run")
func run():
    seed(20261108)
    var baseline=OS.get_environment("T3_PERF_CASE")=="baseline"
    var enemies=int(OS.get_environment("T3_PERF_ENEMIES"))
    var npcs=int(OS.get_environment("T3_PERF_NPCS"))
    var extras=int(OS.get_environment("T3_PERF_ASSETS"))
    var asset_root="res://art/painted/" if OS.get_environment("T3_PERF_CASE")=="nonresident9" else "res://art/painted_bt/"
    var uncached:=0
    var texture_before:=0.0
    var asset_ms:=0.0
    var texture_after_additions:=0.0
    var boot=Time.get_ticks_usec()
    if baseline:
        OS.set_environment("TOWN","back")
        host=load("res://main.tscn").instantiate()
    else:
        host=load("res://sa2_t3_playable.tscn").instantiate();host.save_path="user://t3-perf.json"
        for s in ["",".bak",".tmp"]:DirAccess.remove_absolute(host.save_path+s)
    root.add_child(host)
    for i in 5000:
        if (baseline and host.battle!=null and host.battle.ally!=null) or (not baseline and host.ready_for_event):break
        await process_frame
    host.battle.auto_spawn=false
    if baseline:
        host.player.position=Vector3(11.2,0,0);host.player.locked=true;host.player.set_physics_process(false);host.battle.ally.set_physics_process(false)
        host.cam_x=Vector2(13,13);host.play_ofs=Vector3(0,3.8,17);host.play_look=Vector3(0,2,0);host.cam.fov=21
        for i in enemies:host.battle.spawn("1" if i%2==0 else "3",Vector3(13+(i%5)*0.45,0,-1+(i/5)*0.3))
    else:
        if not host.start_encounter():push_error("perf start failed");quit(1);return
        host.guide_residents()
        for i in range(2,enemies):
            var foe=host.battle.spawn(host.definition.profile.kind,Vector3(12+(i%6)*0.5,0,-1+(i/6)*0.3),host.definition.profile)
            host.policy.register_actor(foe,"perf-machine-%d"%i,"enemy","lower")
            var blade=load("res://scripts/sa2_machine_blade.gd").new();blade.foe=foe;foe.add_child(blade)
        if npcs>3:
            # Diagnostic-only expanded route set, not a change to the approved 3-person definition.
            var d=host.definition.duplicate(true);d.resident_ids=PackedStringArray();d.routes=[]
            for i in npcs-3:d.resident_ids.append("perf-resident-%d"%i);d.routes.append(host.definition.routes[i%3])
            var evac=load("res://scripts/sa2_evacuation.gd").new();host.add_child(evac);evac.configure(d);evac.start()
    host.battle.hp=100000;host.battle.hp_max=100000
    if extras>0:
        var previous_mode=host.process_mode
        host.process_mode=Node.PROCESS_MODE_DISABLED
        await process_frame
        texture_before=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
        var load_start=Time.get_ticks_usec()
        var files=DirAccess.get_files_at(asset_root);var paths:Array=[]
        for f in files:
            if f.ends_with(".png"):paths.append(f)
        paths.sort()
        for i in mini(extras,paths.size()):
            if not ResourceLoader.has_cached(asset_root+paths[i]):uncached+=1
            var texture=load(asset_root+paths[i]);retained.append(texture)
            var sprite=Sprite3D.new();sprite.texture=texture;sprite.pixel_size=0.5/texture.get_height();sprite.position=Vector3(9+(i%8)*0.6,2.0+(i/8)*0.7,-2)
            host.add_child(sprite)
        asset_ms=(Time.get_ticks_usec()-load_start)/1000.0
        await process_frame
        await process_frame
        texture_after_additions=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
        host.process_mode=previous_mode
    var setup=(Time.get_ticks_usec()-boot)/1000.0
    var start=Time.get_ticks_usec()
    while Time.get_ticks_usec()-start<2000000:await process_frame
    start=Time.get_ticks_usec();var before=start;var draws:=0.0
    while Time.get_ticks_usec()-start<6000000:
        await process_frame
        var now=Time.get_ticks_usec();rows.append((now-before)/1000.0);before=now
        draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var total:=0.0
    for value in rows:total+=value
    rows.sort()
    print("T3_PERF_RESULT ",JSON.stringify({"case":OS.get_environment("T3_PERF_CASE"),"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"enemies":enemies,"evacuation_agents":0 if baseline else npcs,"added_sprite_assets":retained.size(),"previously_uncached_assets":uncached,"texture_bytes_before_additions":texture_before,"texture_bytes_after_additions":texture_after_additions,"asset_load_ms":asset_ms,"frames":rows.size(),"mean_ms":total/rows.size(),"p95_ms":rows[int((rows.size()-1)*0.95)],"fps":1000/(total/rows.size()),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"draw_calls":draws/rows.size(),"setup_ms":setup}))
    host.queue_free();await process_frame;await process_frame;quit()
