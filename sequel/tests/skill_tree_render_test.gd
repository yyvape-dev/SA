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
 func apply_progress():pass
func _initialize():call_deferred("run")
func run():
 var m=Model.new();root.add_child(m);m.add_child(m.player);m.add_child(m.battle)
 var h=HUD.new();h.main=m;m.add_child(h)
 h.slot_open=true;h.slot_mode="tree";h.set_process(false)
 var folder=OS.get_environment("TREE_CAPTURE_DIR")
 if folder=="":folder="res://docs/skill_tree_polish/evidence"
 DirAccess.make_dir_recursive_absolute(folder)
 for sz in [Vector2i(844,390),Vector2i(1280,720)]:
  root.size=sz
  for ch in ["rana","lily","ranka"]:
   h.tree_ch=ch;h.respec_arm=0
   var id:String=preload("res://scripts/skill_tree.gd").order(ch)[0]
   m.progress.sp={"rana":4,"lily":2,"ranka":0}
   m.progress.skill_lv={ch:{id:3}}
   if "tree_skill" in h:
    h.tree_skill=id
    h.tree_deriv=preload("res://scripts/skill_tree.gd").rows(ch)[id].derivs.keys()[0]
   h.view.queue_redraw()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   var path:String=folder+"/%s_%dx%d.png"%[ch,sz.x,sz.y]
   root.get_texture().get_image().save_png(path)
   print("CAPTURE ",path)
  if "tree_skill" in h:
   h.tree_ch="rana";h.tree_skill="ult";h.tree_deriv="todo1"
   m.progress.skill_lv={"rana":{"ult":5}};h.respec_arm=2
   h.view.queue_redraw()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/ultimate_%dx%d.png"%[sz.x,sz.y])
  if "tree_skill" in h:
   h.tree_ch="rana";h.tree_skill="rift";h.tree_deriv="sansa";h.respec_arm=0
   m.progress.skill_lv={};m.progress.sp.rana=0
   h.view.queue_redraw()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/locked_%dx%d.png"%[sz.x,sz.y])
   h.slot_mode="slot";h.slot_pick="rift";h.view.queue_redraw()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/slots_%dx%d.png"%[sz.x,sz.y])
   h.slot_mode="tree"
 m.free();print("SKILL_TREE_RENDER PASS (fixture)");quit()
