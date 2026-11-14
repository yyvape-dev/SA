extends SceneTree
const SelectSkin=preload("res://scripts/dungeon_select_art.gd")
const Progress=preload("res://scripts/progress.gd")
class Model extends RefCounted:
 var progress
 var hud
 func ally_ready(_id):return true
class HudState extends RefCounted:
 var main
 var menu_stage="theme"
 var menu_t=1.0
 var menu_theme=2
 var menu_sel=2
 var menu_feedback_t=0.0
 var menu_feedback_pos=Vector2.ZERO
 var shake_i=-1
 var shake_hard=0.0
 var pick=["lily"]
 var ALLY_IDS=["lily","ranka","",""]
 func party_cap():return 2 if menu_sel==0 else 3
class Surface extends Control:
 var hud
 var font=ThemeDB.fallback_font
 func _draw():SelectSkin.map(self,hud,size)
 func _clock(c,r,col):
  draw_arc(c,r,0,TAU,24,col,1,true);draw_line(c,c+Vector2(0,-r*0.65),col,1,true);draw_line(c,c+Vector2(r*0.55,0),col,1,true)
 func _time_str(t):return "%d:%05.2f"%[int(t/60),fmod(t,60)]
 func _num(p,s,fs,col):draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,int(fs*size.y/720),col)
func _initialize():call_deferred("run")
func run():
 var m=Model.new();m.progress=Progress.new();m.progress.unlock_all=true;m.progress.best["t3_expert"]=123.45
 var h=HudState.new();h.main=m
 var v=Surface.new();v.hud=h;v.set_anchors_preset(Control.PRESET_FULL_RECT);root.add_child(v)
 for stage in ["theme","diff","party"]:
  h.menu_stage=stage;v.queue_redraw()
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/workspace/ui-evidence/skin_"+stage+".png")
 quit()
