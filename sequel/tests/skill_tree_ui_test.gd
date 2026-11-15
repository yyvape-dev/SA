extends SceneTree
const HUD=preload("res://scripts/dungeon_hud.gd")
const Progress=preload("res://scripts/progress.gd")
class Actor extends Node:
 var locked=false
class BattleStub extends Node:
 const ULT_COST=100.0
 func ally_list():return []
class Model extends Node:
 var progress=Progress.new()
 var player=Actor.new()
 var battle=BattleStub.new()
 var dungeon=null
 var applies=0
 func apply_progress():applies+=1
func _initialize():call_deferred("run")
func run():
 var m=Model.new();root.add_child(m);m.add_child(m.player);m.add_child(m.battle)
 m.progress.path="user://skill-tree-ui-test.json"
 m.progress.sp={"rana":8,"lily":8,"ranka":8}
 var h=HUD.new();h.main=m;m.add_child(h);h.open_slots();h.slot_mode="tree"
 await process_frame
 var r:Dictionary=h.view.tree_rects()
 var before:Dictionary=m.progress.to_dict()
 h.tree_tap(r.lv_flurry.get_center())
 assert(m.progress.to_dict()==before,"Selecting a skill must not spend SP")
 assert(h.get("tree_skill")=="flurry")
 h.tree_tap(r.upgrade.get_center())
 assert(m.progress.skill_level("rana","flurry")==2 and m.progress.sp_of("rana")==7)
 h.tree_tap(r.d_flurry_senpu.get_center())
 assert(m.progress.deriv_of("rana","flurry")=="","previewing locked derivation must not apply")
 h.tree_tap(r.apply_deriv.get_center());assert(m.progress.deriv_of("rana","flurry")=="")
 h.tree_tap(r.upgrade.get_center());assert(m.progress.skill_level("rana","flurry")==3)
 h.tree_tap(r.apply_deriv.get_center());assert(m.progress.deriv_of("rana","flurry")=="senpu")
 assert(m.progress.sp_of("rana")==6,"derivations are free")
 h.tree_tap(r.apply_deriv.get_center());assert(m.progress.deriv_of("rana","flurry")=="","active derivation can be removed")
 h.tree_tap(r.d_flurry_iai.get_center());assert(m.progress.deriv_of("rana","flurry")=="")
 h.tree_tap(r.apply_deriv.get_center());assert(m.progress.deriv_of("rana","flurry")=="iai")
 h.tree_tap(r.respec.get_center());assert(m.progress.skill_level("rana","flurry")==3,"first respec tap only arms confirmation")
 h.tree_tap(r.ch1.get_center());assert(h.respec_arm==0,"changing character cancels respec confirmation")
 assert(h.tree_ch=="lily" and m.progress.sp_of("lily")==8)
 h.tree_tap(h.view.tree_rects().ch0.get_center())
 h.tree_tap(r.respec.get_center());h.tree_tap(r.respec.get_center())
 assert(m.progress.skill_level("rana","flurry")==1 and m.progress.sp_of("rana")==8)
 assert(m.progress.sp_of("lily")==8)
 m.progress.sp.rana=0
 h.tree_tap(r.upgrade.get_center());assert(m.progress.skill_level("rana","flurry")==1)
 h.tree_tap(r.tab_slot.get_center())
 var sr=h.view.slot_rects()
 h.slot_tap(sr.own1.get_center());assert(m.progress.skill_slots==["flurry","rift","vortex"])
 h.slot_tap(sr.slot0.get_center());assert(m.progress.skill_slots==["rift","flurry","vortex"])
 h.close_slots();assert(m.applies==1 and not m.player.locked)
 var saved=Progress.new();saved.path=m.progress.path;saved.load_save();assert(saved.to_dict()==m.progress.to_dict())
 DirAccess.remove_absolute(m.progress.path)
 m.free()
 print("SKILL_TREE_UI PASS");quit()
