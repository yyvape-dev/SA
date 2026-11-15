extends SceneTree
var game
func _initialize():
 OS.set_environment("TOWN","back")
 call_deferred("run")
func run():
 game=load("res://main.tscn").instantiate();root.add_child(game)
 for i in 1200:
  if game.ui!=null and game.hud!=null and not game.loading.visible:break
  await process_frame
 assert(game.ui!=null and game.dungeon==null)
 var pr=game.progress
 var original:Dictionary=pr.to_dict()
 var original_path:String=pr.path
 pr.path="user://skill-tree-live-test.json"
 pr.reset();pr.sp.rana=4
 game.hud.open_slots();game.hud.slot_mode="tree"
 await process_frame;await process_frame
 assert(not game.ui.visible and root.disable_3d,"modal must hide combat controls and skip 3D")
 var h=game.hud
 var r:Dictionary=h.view.tree_rects()
 h.menu_t=1
 for i in 2:
  var event=InputEventScreenTouch.new();event.pressed=true;event.position=r.upgrade.get_center()
  h._input(event)
 assert(pr.skill_level("rana","flurry")==3 and pr.sp_of("rana")==2)
 h.close_slots()
 await process_frame;await process_frame
 assert(game.ui.visible and not root.disable_3d and not game.player.locked,"modal must restore combat controls and world")
 assert(is_equal_approx(game.player.skills.flurry.cd,7.2),"closing applies trained skills to actual player")
 var restored=preload("res://scripts/progress.gd").new();restored.path=pr.path;restored.load_save()
 assert(restored.skill_level("rana","flurry")==3)
 DirAccess.remove_absolute(pr.path)
 pr.path=original_path;pr.from_dict(original)
 # Detached bench actors belong to the live-scene harness teardown.
 for actor in game.bench.values():actor.queue_free()
 game.bench.clear()
 game.queue_free();await process_frame;await process_frame
 print("SKILL_TREE_LIVE PASS actual scene, touch upgrade, apply_progress, save, modal restore");quit()
