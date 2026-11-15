extends SceneTree
const Manual=preload("res://scripts/sa2_t2_lily_manual.gd")
const UI=preload("res://scripts/touch_ui.gd")
const Art=preload("res://scripts/combat_hud_art.gd")
const Progress=preload("res://scripts/progress.gd")
class AllyStub extends Node:
 var actor_id="lily"
 var hp=76.0
 var ult_key="ally_ult"
 var sk_cd={}
 var required=100.0
 func ult_cost():return required
 var state="move"
 var down_t=0.0
 const DOWN_T=4.0
 func slot_ids():return ["shot","ring","quake"] if actor_id=="ranka" else ["rush","barrage","storm"]
 func hp_max():return 100.0
 func hp_ratio():return hp/100.0
class PlayerStub extends Node:
 var move_in=Vector2.ZERO
 var skills={"flurry":{"cd":8},"rift":{"cd":7},"vortex":{"cd":12}}
 var skill_cd={"flurry":0,"rift":3.2,"vortex":0}
 var skill_ready_flash={}
 var locked=false
 var state="move"
 var actor
 var required=100.0
 var world
 func ult_value():return world.ranka_ult if actor.actor_id=="ranka" else world.ally_ult
 func ult_cost():return required
 func can_use_skill(id):return not locked and float(skill_cd.get(id,0))<=0
class BattleStub extends Node3D:
 var hp=76.0
 var ult_key="ally_ult"
 var sk_cd={}
 var required=100.0
 func ult_cost():return required
 var hp_max=100.0
 const ULT_COST=100.0
 const ULT_MAX=200.0
 var ult=150.0
 var ally_ult=80.0
 var ranka_ult=120.0
 var allies=[]
 func ally_list():return allies
class MainStub extends Node:
 var progress
 var dungeon=true
 var hud
class BossSurface extends Control:
 func _draw():
  Art.boss(self,Art.boss_rect(size),0.58)
func _initialize():call_deferred("run")
func run():
 var main=MainStub.new();root.add_child(main)
 main.progress=Progress.new();main.progress.reset();main.progress.lv=6;main.progress.weapon=12;main.progress.xp=int(main.progress.need()*0.60)
 var battle=BattleStub.new();main.add_child(battle)
 for id in ["lily","ranka"]:
  var ally=AllyStub.new();ally.actor_id=id;main.add_child(ally);battle.allies.append(ally)
 var player=PlayerStub.new();main.add_child(player);player.world=battle;player.actor=battle.allies[0]
 var bg=ColorRect.new();bg.color=Color("101725");bg.set_anchors_preset(Control.PRESET_FULL_RECT);main.add_child(bg)
 var manual=Manual.new();manual.battle=battle;manual.locked=false;manual.skills_enabled=true
 var ui=UI.new();ui.main=main;ui.player=player;ui.battle=battle;main.add_child(ui)
 var boss=BossSurface.new();boss.set_anchors_preset(Control.PRESET_FULL_RECT);main.add_child(boss)
 var output=ProjectSettings.globalize_path("res://captures");DirAccess.make_dir_recursive_absolute(output)
 for mode in ["ready","cooldown","lily","ranka","basic"]:
  ui.lily_controls=mode in ["lily","ranka"];ui.basic_combat_only=mode=="basic"
  player.required=80.0 if mode=="cooldown" else 100.0
  if mode=="cooldown":
   battle.hp=31;ui.hud.shown=0.70;battle.ult=79.9;player.skill_cd={"flurry":8.0,"rift":0.0,"vortex":0.8};battle.allies[0].state="down";battle.allies[0].down_t=3.2
  if mode=="lily":
   manual.actor=battle.allies[0];manual.actor.state="move";manual.actor.required=80;manual.skills={"rush":{"cd":8},"barrage":{"cd":9},"storm":{"cd":12}};manual.actor.sk_cd={"rush":0,"barrage":4.0,"storm":0};battle.ally_ult=180;ui.player=manual
  if mode=="ranka":
   manual.actor=battle.allies[1];manual.actor.ult_key="ranka_ult";manual.skills={"shot":{"cd":8},"ring":{"cd":12},"quake":{"cd":18}};manual.actor.sk_cd={"shot":0,"ring":0,"quake":2.2};battle.ranka_ult=40;ui.player=manual
  if mode=="basic":ui.player=player
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png(output+"/combat_"+mode+".png")==OK)
 print("COMBAT_RENDER PASS ready, full cooldown, low HP, ally down, Lily/Ranka/manual and basic")
 main.free();manual.free();quit()
