extends SceneTree
const Art=preload("res://scripts/combat_hud_art.gd")
const Manual=preload("res://scripts/sa2_t2_lily_manual.gd")
class Actor extends Node:
 var actor_id="ranka"
 var hp=31.0
 var state="move"
 var sk_cd={"shot":0.0}
 var ult_key="ranka_ult"
 func hp_max():return 100.0
 func ult_cost():return 80.0
class Battle extends Node:
 var hp=99.0
 var hp_max=120.0
 const ULT_COST=100.0
 const ULT_MAX=200.0
 var ranka_ult=160.0
class Ui extends RefCounted:
 var lily_controls=true
 var player
 var battle
func _initialize():
 var a=Actor.new();var b=Battle.new();var control=Manual.new();control.actor=a;control.battle=b
 var ui=Ui.new();ui.player=control;ui.battle=b
 assert(Art.health(ui)==Vector2(31,100),"manual HUD must show the controlled actor, not Rana")
 assert(Art.cost(ui)==80,"manual ultimate threshold must use actor's trained cost")
 control.locked=false;control.skills_enabled=true;control.combat_enabled=true;control.skills={"shot":{"cd":8.0}}
 assert(Art.skill_ready(ui,"shot"))
 control.dodge_left=0.1;assert(not Art.skill_ready(ui,"shot"),"manual dodge must not advertise skill-ready")
 control.dodge_left=0;control.combat_enabled=false;assert(not Art.skill_ready(ui,"shot"),"disabled combat must dim skills")
 control.combat_enabled=true;control.skills={};assert(not Art.skill_ready(ui,"shot"),"absent skills must not advertise ready")
 for ch in ["rana","lily","ranka"]:
  var ids={"rana":["flurry","rift","vortex"],"lily":["rush","barrage","storm"],"ranka":["shot","ring","quake"]}[ch]
  ids.append("ult")
  for id in ids:assert(Art.icon(ch,id)!=null,"missing actual character skill icon")
 assert(Art.icon("future","unknown")==null)
 control.free();a.free();b.free()
 print("COMBAT_BINDING PASS controlled health, actual trained cost and 12 skill mappings")
 quit()
