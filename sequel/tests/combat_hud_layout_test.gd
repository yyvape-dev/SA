extends SceneTree
const Art=preload("res://scripts/combat_hud_art.gd")
const UI=preload("res://scripts/touch_ui.gd")
class Context extends RefCounted:
 var basic_combat_only=false
 var lily_controls=false
 var main=null
func _initialize():
 var context=Context.new();var pad=UI._Pad.new();pad.ui=context
 for sz in [Vector2(844,390),Vector2(1280,720)]:
  pad.size=sz
  var boss=Art.boss_rect(sz)
  assert(boss.position.x>=478*sz.y/720.0,"boss health must not overlap main status at16:9")
  for basic in [false,true]:
   context.basic_combat_only=basic
   var targets=pad._btns()
   assert(targets.size()==(2 if basic else 6))
   for id in targets:
    var c:Vector2=targets[id][0];var radius:float=targets[id][1]
    assert(radius*2>=44,"combat button must be at least44px")
    assert(Rect2(Vector2.ZERO,sz).encloses(Rect2(c-Vector2.ONE*radius,Vector2.ONE*radius*2)),"combat control outside viewport")
 pad.free();print("COMBAT_LAYOUT PASS existing arc, 44px targets and bounds at844x390/1280x720");quit()
