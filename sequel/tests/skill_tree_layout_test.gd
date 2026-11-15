extends SceneTree
const Art=preload("res://scripts/skill_tree_art.gd")
const Skills=preload("res://scripts/skill_tree.gd")
const Info=preload("res://scripts/skill_tree_presenter.gd")
func _initialize():
 var failures=[]
 for sz in [Vector2(844,390),Vector2(1280,720)]:
  var u=sz.y/720.0
  for ch in Skills.CHARS:
   var r=Art.rects(sz,ch)
   var targets=["close","tab_slot","tab_tree","upgrade","apply_deriv","respec","ch0","ch1","ch2"]
   for id in Skills.order(ch):
    targets.append("lv_"+id)
    for did in Skills.rows(ch)[id].derivs:targets.append("d_%s_%s"%[id,did])
   for k in targets:
    var rc:Rect2=r[k]
    if minf(rc.size.x,rc.size.y)<44:failures.append("target too small "+k)
    if not Rect2(Vector2.ZERO,sz).encloses(rc):failures.append("offscreen "+k)
    for other in targets:
     if k!=other and rc.intersects(r[other]):failures.append("overlap "+k+" "+other)
   for id in Skills.order(ch):
    if not fits(Info.ABOUT[ch][id],r.about,23*u):failures.append("clipped about "+ch+id+str(sz))
    for did in Skills.rows(ch)[id].derivs:
     if Info.DERIV_ABOUT.has(did) and not fits(Info.DERIV_ABOUT[did],r.deriv_about,23*u):failures.append("clipped deriv "+did+str(sz))
   var slots=Art.slot_rects(sz,["flurry","rift","vortex"])
   for k in ["slot0","slot1","slot2","own0","own1","own2"]:
    if minf(slots[k].size.x,slots[k].size.y)<44 or not slots.panel.encloses(slots[k]):failures.append("slot target "+k)
 if failures.size():
  for f in failures:push_error(f)
  quit(1)
 else:print("SKILL_TREE_LAYOUT PASS targets, bounds, no overlaps, all descriptions fit");quit()
func fits(s:String,rc:Rect2,fs:float)->bool:
 var p=TextParagraph.new();p.add_string(s,Art.FONT,int(fs));p.width=rc.size.x
 p.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
 if p.get_size().y>rc.size.y:print("TEXT SIZE ",p.get_size()," box ",rc.size," text ",s)
 return p.get_size().y<=rc.size.y
