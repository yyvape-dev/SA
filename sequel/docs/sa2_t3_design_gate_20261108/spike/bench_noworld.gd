extends SceneTree
# Throwaway measurement only: does not implement C2-09 or edit source scripts.
var scene
var textures := []
var entries := []
var samples := []
var physics_samples := []
var draw_samples := []
var started := 0
var previous := 0
var case_name := OS.get_environment("AUDIT_CASE")
var count := int(OS.get_environment("AUDIT_ENEMIES"))
var npc_count := int(OS.get_environment("AUDIT_NPCS"))
var asset_count := int(OS.get_environment("AUDIT_ASSETS"))
var event_count := int(OS.get_environment("AUDIT_EVENTS"))
func _initialize():
    call_deferred("run")
func run():
    seed(20261108)
    var boot := Time.get_ticks_usec()
    scene = load("res://main.tscn").instantiate()
    root.add_child(scene)
    while scene.battle == null or scene.battle.ally == null:
        await process_frame
    scene.battle.auto_spawn = false
    for e in scene.battle.enemies.duplicate():
        scene.battle.remove_enemy(e)
    await process_frame
    scene.player.position = Vector3(0,0,0)
    scene.player.locked = true
    scene.player.set_physics_process(false)
    scene.battle.ally.set_physics_process(false)
    scene.battle.ally.position = Vector3(-1.4,0,0.7)
    scene.battle.hp = 1e9 # Keep natural AI attacking throughout every sample; not a victory test.
    for i in count:
        scene.battle.spawn("1" if i % 2 == 0 else "3", Vector3(1.8+(i%6)*0.55,0,-2.0+(i/6)*0.7))
    while scene.crowd.size() < npc_count:
        scene._build_crowd()
    while scene.crowd.size() > npc_count:
        var c = scene.crowd.pop_back()
        c.node.queue_free()
    var load_start := Time.get_ticks_usec()
    var files := DirAccess.get_files_at("res://art/painted_bt")
    var paths := []
    for f in files:
        if f.ends_with(".png"):
            paths.append("res://art/painted_bt/"+f)
    paths.sort()
    for i in mini(asset_count, paths.size()):
        var tex = load(paths[i])
        textures.append(tex)
        var s := Sprite3D.new()
        s.texture = tex
        s.pixel_size = 0.7 / tex.get_height()
        s.position = Vector3(-4.5+(i%8)*0.7,1.8+(i/8)*0.7,-2)
        scene.add_child(s)
    var asset_ms := (Time.get_ticks_usec()-load_start)/1000.0
    load_start = Time.get_ticks_usec()
    var db = load("res://scripts/sa2_dialogue_database.gd").new()
    for i in event_count:
        var entry = db.load_event("Audit%03d" % i)
        if entry.is_empty():
            push_error(db.last_error)
            quit(1)
            return
        entries.append(entry)
    var event_ms := (Time.get_ticks_usec()-load_start)/1000.0
    var ready_ms := (Time.get_ticks_usec()-boot)/1000.0
    scene.level.hide()
    var warm_start := Time.get_ticks_usec()
    while Time.get_ticks_usec()-warm_start < 2000000:
        await process_frame
    started = Time.get_ticks_usec()
    previous = started
    while Time.get_ticks_usec()-started < 6000000:
        await process_frame
        var now := Time.get_ticks_usec()
        samples.append((now-previous)/1000.0)
        previous = now
        physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
        draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var total := 0.0
    var physics_total := 0.0
    var draw_total := 0.0
    for s in samples: total += s
    for s in physics_samples: physics_total += s
    for s in draw_samples: draw_total += s
    samples.sort()
    var micro := Time.get_ticks_usec()
    for i in 1000: scene.battle._separate(0.0)
    var separate_us := (Time.get_ticks_usec()-micro)/1000.0
    var rss := ""
    var proc_status := FileAccess.get_file_as_string("/proc/self/status")
    for line in proc_status.split("\n"):
        if line.begins_with("VmRSS:") or line.begins_with("VmHWM:"): rss += line+" "
    var result := {"case":case_name,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"enemy_count":count,"npcs":scene.crowd.size(),"extra_distinct_textures":textures.size(),"events_loaded":entries.size(),"frames":samples.size(),"fps_wall":1000.0/(total/samples.size()),"mean_frame_ms":total/samples.size(),"p95_frame_ms":samples[int(floor((samples.size()-1)*0.95))],"physics_monitor_mean_ms":physics_total/physics_samples.size(),"draw_calls_mean":draw_total/draw_samples.size(),"static_mem_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"texture_mem_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"rss":rss,"scene_setup_ms":ready_ms,"extra_asset_load_ms":asset_ms,"event_load_validate_ms":event_ms,"separate_us_per_call":separate_us,"nodes":get_node_count()}
    print("AUDIT_RESULT "+JSON.stringify(result))
    if DisplayServer.get_name() != "headless":
        await process_frame
        root.get_texture().get_image().save_png("/workspace/sa2-t3-audit/"+case_name+".png")
    scene.queue_free()
    await process_frame
    quit(0)
