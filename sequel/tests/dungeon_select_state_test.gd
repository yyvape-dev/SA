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
 var town_floor_busy=false
 func party_flow():return true
 func ally_ready(id):return not unavailable and id in ["lily","ranka"]
func _initialize():call_deferred("run")
func run():
 var m=Model.new();root.add_child(m);m.add_child(m.player);m.add_child(m.battle);m.add_child(m.district);m.add_child(m.level)
 m.progress=Progress.new();m.progress.reset()
 var h=HUD.new();m.hud=h;h.main=m;m.add_child(h)
 h.open_menu();await process_frame;await process_frame;assert(not m.level.visible,"covered world should not render");assert(h.menu_stage=="theme");assert(not h.choose_theme(1));assert(h.shake_i==11)
 h.menu_t=1.0
 var touch=InputEventScreenTouch.new();touch.pressed=true;touch.position=h.view.menu_rects().badge0.get_center()
 var input_start=Time.get_ticks_usec();h._input(touch)
 assert(h.menu_stage=="diff" and h.menu_theme==0,"enemy report must select the same dungeon")
 assert(h.menu_feedback_t>0 and Time.get_ticks_usec()-input_start<100000,"tap feedback must begin synchronously")
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
 assert("_chosen" in loading,"loading must snapshot the chosen expedition")
 assert(loading._chosen==["lily","ranka"]);assert(loading._difficulty==2)
 h.pick.clear();assert(loading._chosen==["lily","ranka"],"snapshot must not alias HUD picks")
 m.district.progress.emit(0.42);assert(is_equal_approx(loading._progress,0.42));assert(loading._theme==3)
 m.district.download_started.emit();assert(loading._progress<0,"retry must reset unknown progress")
 m.town_floor_busy=true;loading.show_now()
 assert(loading._theme==-1 and loading._chosen.is_empty(),"town loading must not reuse the previous expedition")
 m.town_floor_busy=false
 loading.error_text="dg1 8 200";await process_frame;await process_frame
 assert(not loading._err.text.contains("dg"));assert(loading._err.text.contains("200"))
 h.menu_back();h.menu_back();h.menu_back();await process_frame;await process_frame;assert(m.level.visible,"world visibility must restore")
 print("SELECT_STATE PASS locks, party cap, unavailable/future allies, back navigation, real loading progress")
 m.free();quit(0)
