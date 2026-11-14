extends SceneTree
const HUD = preload("res://scripts/dungeon_hud.gd")
func _initialize():
 var h = HUD.new()
 var v = HUD._View.new()
 v.hud = h
 var failures = []
 for dimensions in [Vector2(844,390),Vector2(1280,720)]:
  v.size = dimensions
  for stage in ["theme","diff","party"]:
   h.menu_stage = stage
   h.menu_t = 0.06
   var r = v.menu_rects()
   var keys = ["close"]
   if stage != "party":
    keys.append_array(["node0","node1","node2","node3"])
   if stage == "diff": keys.append_array(["diff0","diff1","diff2","go"])
   if stage == "party":keys.append_array(["ally0","ally1","ally2","ally3","go"])
   for key in keys:
    var rc: Rect2 = r[key]
    if minf(rc.size.x,rc.size.y) < 44.0:failures.append("%s %s target <44 at %s" % [stage,key,dimensions])
    if not Rect2(Vector2.ZERO,dimensions).encloses(rc):failures.append("offscreen "+stage+key)
   if stage == "diff":
    for i in 4:
     if r["node%d"%i].intersects(r.panel):failures.append("panel covers node")
 h.menu_stage="diff";h.menu_t=1.0;v.size=Vector2(844,390)
 h.shake_i=-1;h.shake_hard=0.0
 var before=v.menu_rects().diff0
 h.shake_i=0;h.shake_hard=0.32
 var after=v.menu_rects().diff0
 if is_equal_approx(before.position.x,after.position.x):failures.append("shake must move shared hit rect")
 v.free();h.free()
 if failures.size():
  for f in failures:push_error(f)
  quit(1)
 else:
  print("SELECT_LAYOUT PASS minimum targets, bounds and node/panel separation")
  quit(0)
