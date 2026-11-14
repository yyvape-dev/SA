extends SceneTree
const HUD=preload("res://scripts/dungeon_hud.gd")
const Progress=preload("res://scripts/progress.gd")
const Loading=preload("res://scripts/loading.gd")
class Actor extends Node:
 var locked=false
class BattleStub extends Node:
 func ally_list():return []
class DistrictStub extends Node:
 signal progress(ratio: float)
 signal download_started
class Model extends Node:
 var progress
 var player=Actor.new()
 var battle=BattleStub.new()
 var dungeon=null
 var level=Node3D.new()
 var party_last=[]
 var hud
 var district=DistrictStub.new()
 var unavailable=false
 func party_flow():return true
 func ally_ready(id):return not unavailable and id in ["lily","ranka"]
func _initialize():call_deferred("run")
func run():
 var m=Model.new();root.add_child(m);m.add_child(m.player);m.add_child(m.battle);m.add_child(m.district);m.add_child(m.level)
 m.progress=Progress.new();m.progress.reset()
 var h=HUD.new();m.hud=h;h.main=m;m.add_child(h)
 h.open_menu();await process_frame;await process_frame;assert(not m.level.visible,"covered world should not render");assert(h.menu_stage=="theme");assert(not h.choose_theme(1));assert(h.shake_i==11)
 assert(h.choose_theme(0));assert(h.menu_stage=="diff");assert(not h.choose(1))
 assert(h.choose(0));assert(h.menu_stage=="party");assert(h.party_cap()==2)
 h.toggle_ally(0);assert(h.pick==["lily"])
 h.toggle_ally(1);assert(h.pick==["lily"]);assert(h.shake_i==30)
 h.toggle_ally(0);assert(h.pick.is_empty())
 m.unavailable=true;h.toggle_ally(0);assert(h.pick.is_empty());assert(h.shake_i==20)
 h.toggle_ally(2);assert(h.shake_i==22)
 h.menu_back();assert(h.menu_stage=="diff");h.menu_back();assert(h.menu_stage=="theme")
 m.progress.unlock_all=true;assert(h.choose_theme(3));assert(h.choose(2));assert(h.party_cap()==3)
 m.unavailable=false;h.toggle_ally(0);h.toggle_ally(1);assert(h.pick.size()==2)
 var loading=Loading.new();m.add_child(loading);loading.show_now()
 m.district.progress.emit(0.42);assert(is_equal_approx(loading._progress,0.42));assert(loading._theme==3)
 m.district.download_started.emit();assert(loading._progress<0,"retry must reset unknown progress")
 loading.error_text="dg1 8 200";await process_frame;await process_frame
 assert(not loading._err.text.contains("dg"));assert(loading._err.text.contains("200"))
 h.menu_back();h.menu_back();h.menu_back();await process_frame;await process_frame;assert(m.level.visible,"world visibility must restore")
 print("SELECT_STATE PASS locks, party cap, unavailable/future allies, back navigation, real loading progress")
 m.free();quit(0)
