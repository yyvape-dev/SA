extends RefCounted
const Store=preload("res://scripts/sa2_street_checkpoint.gd")

static func capture(host) -> Dictionary:
    var cp=Store.empty_checkpoint(host.definition)
    for key in Store.BATTLE_NUMBERS+["ult_gain","ally_ult_gain"]:cp.battle[key]=host.battle.get(key)
    for id in ["rana","lily"]:
        var actor=host.get(id)
        cp.actors[id]={"position":Store.vec(actor.position),"face":actor.face,"cooldowns":(actor.skill_cd if id=="rana" else actor.sk_cd).duplicate(true)}
    return cp

static func normalize_actor(actor):
    # Explicit safe-state mapping, only fields actually owned by this actor.
    var fields={}
    for item in actor.get_property_list():fields[item.name]=true
    var zeros=["t","hit_i","ev_i","inv","flash","kb","ghost_t","dodge_t","ult_i","ult_t","held_t","root_prev","dash_x0"]
    for key in zeros:
        if fields.has(key):actor.set(key,0)
    for key in ["atk_held","hold_fired","queued_hold","queued","ult_jumped","dust_done"]:
        if fields.has(key):actor.set(key,false)
    for key in ["skill_id","sk_id","mv","last"]:
        if fields.has(key):actor.set(key,"")
    for key in ["sk","skill_ready_flash"]:
        if fields.has(key):actor.set(key,{})
    if fields.has("target"):actor.target=null
    if fields.has("charged"):actor.charged=-1
    if fields.has("cd"):actor.cd=0.0
    if fields.has("move_in"):actor.move_in=Vector2.ZERO
    if fields.has("hold_hit"):actor.hold_hit=[]
    for ghost in actor.ghosts:
        if is_instance_valid(ghost.node):ghost.node.queue_free()
    actor.ghosts.clear()
    actor.state="move";actor.clip="idle"
    if actor.has_method("_show"):actor._show("idle",0)
    else:actor._show_frame("idle",0)
    actor.sprite.position=Vector3.ZERO;actor.refl.position=Vector3.ZERO
    actor.mat.set_shader_parameter("tint",Color.WHITE)
    actor.mat.set_shader_parameter("flash",Color(0,0,0,0))

static func restore(host, cp:Dictionary):
    for key in Store.BATTLE_NUMBERS+["ult_gain","ally_ult_gain"]:host.battle.set(key,cp.battle[key])
    for key in ["freeze","shake","combo","combo_t","cam_zoom","bg_dim","dim_hold","chroma"]:
        host.battle.set(key,1.0 if key=="bg_dim" else 0)
    host.battle.cine=false;host.battle.cam_focus=null
    RenderingServer.global_shader_parameter_set("bg_dim",1.0)
    for id in ["rana","lily"]:
        var actor=host.get(id)
        normalize_actor(actor)
        actor.position=Store.position(cp.actors[id].position);actor.face=int(cp.actors[id].face)
        if id=="rana":actor.skill_cd=cp.actors[id].cooldowns.duplicate(true)
        else:actor.sk_cd=cp.actors[id].cooldowns.duplicate(true)
    host.cutin.t=-1.0;host.cutin.white=0
    if host.lily_cutin:host.lily_cutin.t=-1.0;host.lily_cutin.white=0
