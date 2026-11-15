extends RefCounted
## Combat presentation. Gameplay APIs and touch geometry stay in their original owners.
const M=preload("res://scripts/combat_hud_materials.gd")
const Model=preload("res://scripts/combat_hud_model.gd")
const Old=preload("res://scripts/t6_hud_art.gd")
const BLUE=Color("42c9ef")
const PURPLE=Color("ad77ff")
const GOLD=Color("e9c06b")
const INK=Color("07111f")

static func actor_id(ui)->String:
 if ui.lily_controls and ui.player!=null and "actor" in ui.player and ui.player.actor!=null:return str(ui.player.actor.actor_id)
 return "rana"

static func health(ui)->Vector2:
 if ui.lily_controls and ui.player!=null and "actor" in ui.player and ui.player.actor!=null:
  var actor=ui.player.actor
  if actor.has_method("hp_max"):
   var maximum=float(actor.hp_max())
   return Vector2(maximum if float(actor.hp)<0 else float(actor.hp),maximum)
 return Vector2(float(ui.battle.hp),float(ui.battle.hp_max))

static func cost(ui)->float:
 if ui.player!=null and ui.player.has_method("ult_cost"):return float(ui.player.ult_cost())
 if ui.player!=null and "actor" in ui.player and ui.player.actor!=null and ui.player.actor.has_method("ult_cost"):return float(ui.player.actor.ult_cost())
 return float(ui.battle.ULT_COST)

static func fit(v,texture:Texture2D,rc:Rect2,tint:Color=Color.WHITE)->void:
 var extent=texture.get_size()*minf(rc.size.x/texture.get_width(),rc.size.y/texture.get_height())
 v.draw_texture_rect(texture,Rect2(rc.get_center()-extent*0.5,extent),false,tint)

static func number(v,rc:Rect2,text:String,fs:float,col:Color)->void:
 var font=Old.FONT
 var size_=maxi(int(fs),int(22*v.size.y/720.0))
 var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_).x
 var at=Vector2(rc.get_center().x-width*0.5,rc.get_center().y+size_*0.32)
 v.draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,maxi(1,int(v.size.y/720.0)),INK)
 v.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,col)

static func style(color:Color,radius:float)->StyleBoxFlat:
 var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(int(radius));return s

static func bar(v,texture:Texture2D,rc:Rect2,fraction:float,color:Color,ghost:float=-1.0)->Rect2:
 # Scale frame endcaps uniformly; only the empty glass track stretches horizontally.
 var scale_=rc.size.y/texture.get_height()
 var box=StyleBoxTexture.new();box.texture=texture
 box.texture_margin_left=texture.get_height()*0.68;box.texture_margin_right=texture.get_height()*0.68
 v.draw_set_transform(rc.position,0,Vector2(scale_,scale_))
 v.draw_style_box(box,Rect2(Vector2.ZERO,Vector2(rc.size.x/scale_,texture.get_height())))
 v.draw_set_transform(Vector2.ZERO)
 var inner=Rect2(rc.position+Vector2(rc.size.y*0.80,rc.size.y*0.30),Vector2(maxf(0,rc.size.x-rc.size.y*1.60),rc.size.y*0.42))
 v.draw_style_box(style(Color("07111e"),inner.size.y*0.45),inner)
 if ghost>fraction:
  var delayed=Rect2(inner.position,Vector2(inner.size.x*clampf(ghost,0,1),inner.size.y))
  v.draw_style_box(style(Color(0.80,0.87,0.95,0.65),inner.size.y*0.45),delayed)
 var fill=Rect2(inner.position,Vector2(inner.size.x*clampf(fraction,0,1),inner.size.y))
 if fill.size.x>1:
  v.draw_style_box(style(color.darkened(0.35),inner.size.y*0.4),fill)
  v.draw_rect(Rect2(fill.position+Vector2(0,inner.size.y*0.14),Vector2(fill.size.x,inner.size.y*0.38)),Color(color.lightened(0.5),0.82))
  v.draw_line(fill.position+Vector2(0,inner.size.y*0.20),fill.position+Vector2(fill.size.x,inner.size.y*0.20),Color(0.9,0.97,1,0.5),maxf(1,rc.size.y*0.045),true)
 return inner

static func portrait(v,tex:Texture2D,rc:Rect2,dim:bool=false)->void:
 v.draw_circle(rc.get_center(),rc.size.x*0.43,INK)
 fit(v,tex,rc.grow(-rc.size.x*0.07),Color(0.35,0.38,0.43) if dim else Color.WHITE)
 fit(v,M.PORTRAIT_FRAME,rc,Color(0.65,0.65,0.67) if dim else Color.WHITE)

static func gauges(v,ui,u:float,shown_hp:float)->void:
 var ch=actor_id(ui)
 var face:Texture2D=Old.RANA if ch=="rana" else Old.RANKA if ch=="ranka" else Old.LILY
 var hp=health(ui)
 var data=Model.meter(hp.x,hp.y,ui.ult_value(),ui.battle.ULT_MAX,cost(ui))
 portrait(v,face,Rect2(Vector2(10,5)*u,Vector2(88,88)*u),hp.x<=0)
 bar(v,M.HP_FRAME,Rect2(Vector2(100,24)*u,Vector2(358,40)*u),data.health_fraction,BLUE,shown_hp)
 number(v,Rect2(Vector2(244,0)*u,Vector2(204,27)*u),"%d/%d"%[int(maxf(0,hp.x)),int(hp.y)],24*u,Color("f3ead8"))
 if ui.main!=null and "progress" in ui.main and ui.main.progress!=null:
  var pr=ui.main.progress
  var h=ui.main.hud if "hud" in ui.main else null
  var level_color=GOLD.lerp(Color.WHITE,clampf(h.lv_flash,0,1)) if h!=null else GOLD
  var weapon_color=GOLD if h!=null and h.w_flash>0 and int(h.w_flash*8)%2==0 else Color("eee4cf")
  number(v,Rect2(Vector2(87,61)*u,Vector2(45,28)*u),str(pr.lv),27*u,level_color)
  bar(v,M.XP_FRAME,Rect2(Vector2(134,70)*u,Vector2(196,12)*u),clampf(float(pr.xp)/maxf(1,pr.need()),0,1),GOLD)
  fit(v,M.ATTACK_SWORD,Rect2(Vector2(350,62)*u,Vector2(30,30)*u))
  number(v,Rect2(Vector2(389,61)*u,Vector2(56,28)*u),str(pr.weapon),25*u,weapon_color)
 if ui.basic_combat_only:return
 var charge=bar(v,M.CHARGE_FRAME,Rect2(Vector2(100,97)*u,Vector2(322,27)*u),data.charge_fraction,PURPLE)
 for threshold in data.thresholds:
  var p=charge.position+Vector2(charge.size.x*threshold,charge.size.y*0.5)
  v.draw_circle(p,2.5*u,GOLD if data.charge_fraction>=threshold else Color("6b697a"))
 var counter=Rect2(Vector2(424,86)*u,Vector2(49,49)*u)
 fit(v,M.STOCK_FRAME,counter,Color.WHITE if data.stock>0 else Color(0.55,0.55,0.58))
 number(v,counter,str(data.stock),25*u,GOLD if data.stock>0 else Color("9a9cac"))
 if ui.lily_controls:return
 var row=0
 for ally in ui.battle.ally_list():
  if not ally.has_method("hp_ratio"):continue
  var y=(140+row*65)*u
  var down:bool=ally.state=="down"
  var is_ranka:bool=ally.actor_id=="ranka"
  portrait(v,Old.RANKA if is_ranka else Old.LILY,Rect2(Vector2(25*u,y-8*u),Vector2(57,57)*u),down)
  var hp_rc=Rect2(Vector2(89*u,y),Vector2(220,22)*u)
  bar(v,M.HP_FRAME,hp_rc,1.0-float(ally.down_t)/ally.DOWN_T if down else ally.hp_ratio(),Color("7c8492") if down else BLUE)
  var charge_value:float=ui.battle.ranka_ult if is_ranka else ui.battle.ally_ult
  bar(v,M.CHARGE_FRAME,Rect2(Vector2(89*u,y+28*u),Vector2(184,13)*u),charge_value/ui.battle.ULT_MAX,PURPLE)
  if down:number(v,Rect2(Vector2(273*u,y-1*u),Vector2(34,26)*u),str(int(ceil(ally.down_t))),22*u,Color("e1e3e8"))
  row+=1

static func boss_rect(sz:Vector2)->Rect2:
 var u=sz.y/720.0
 var width=maxf(240*u,minf(560*u,sz.x-980*u))
 return Rect2(Vector2((sz.x-width)*0.5-6*u,62*u),Vector2(width+12*u,38*u))

static func boss(v,rc:Rect2,fraction:float)->void:
 bar(v,M.BOSS_FRAME,rc,fraction,Color("ed4d55"))

static func icon(ch:String,id:String)->Texture2D:
 var icons={"rana":{"flurry":M.RANA_FLURRY,"rift":M.RANA_RIFT,"vortex":M.RANA_VORTEX,"ult":M.RANA_ULT},"lily":{"rush":M.LILY_RUSH,"barrage":M.LILY_BARRAGE,"storm":M.LILY_STORM,"ult":M.LILY_ULT},"ranka":{"shot":M.RANKA_SHOT,"ring":M.RANKA_RING,"quake":M.RANKA_QUAKE,"ult":M.RANKA_ULT}}
 return icons.get(ch,{}).get(id)

static func skill_ready(ui,id:String)->bool:
 var pl=ui.player
 if icon(actor_id(ui),id)==null or float(pl.skill_cd.get(id,0))>0:return false
 if "locked" in pl and pl.locked:return false
 if pl.has_method("can_use_skill"):return pl.can_use_skill(id)
 if ui.lily_controls:
  var actor=pl.actor if "actor" in pl else null
  return actor!=null and actor.state=="move" and pl.skills.has(id) and (bool(pl.skills_enabled) if "skills_enabled" in pl else true) and (bool(pl.combat_enabled) if "combat_enabled" in pl else true) and (float(pl.dodge_left)<=0 if "dodge_left" in pl else true)
 return true

static func action(v,ui,key:String,id:String,c:Vector2,radius:float,pressed:bool,u:float)->void:
 var ch=actor_id(ui)
 var pl=ui.player
 var texture:Texture2D
 var ready=true
 var cd=0.0
 var full=1.0
 var stock=0
 var blocked=bool(pl.locked) if "locked" in pl else false
 var actor=pl.actor if "actor" in pl and pl.actor!=null else pl
 var actor_state=str(actor.state) if "state" in actor else "move"
 if key=="atk":texture=M.ATTACK_SWORD if ch=="rana" else M.ATTACK_PALM if ch=="ranka" else M.ATTACK_FIST
 elif key=="dodge":texture=M.DODGE
 elif key=="ult":
  texture=icon(ch,"ult")
  stock=Model.meter(1,1,ui.ult_value(),ui.battle.ULT_MAX,cost(ui)).stock
  ready=stock>0 and not blocked
  if pl.has_method("can_use_ult"):ready=pl.can_use_ult()
  elif ui.lily_controls:
   ready=ready and actor_state=="move" and (bool(pl.skills_enabled) if "skills_enabled" in pl else true) and (bool(pl.combat_enabled) if "combat_enabled" in pl else true) and (float(pl.dodge_left)<=0 if "dodge_left" in pl else true) and (not bool(ui.battle.cine) if "cine" in ui.battle else true)
  elif actor_state in ["down","hurt","ult"]:ready=false
 else:
  texture=icon(ch,id)
  if texture==null:texture=M.DODGE # 絵の無い新しい技（回り込み、2026-11-16）は回避の絵で仮置き
  cd=float(pl.skill_cd.get(id,0))
  full=float(pl.skills.get(id,{}).get("cd",1))
  ready=skill_ready(ui,id)
 var draw_radius=radius*(0.95 if pressed else 1.0)
 var at=c+Vector2(0,1.4*u if pressed else 0.0)
 v.draw_circle(at,draw_radius*0.86,Color(0.015,0.025,0.04,0.42))
 if texture!=null:fit(v,texture,Rect2(at-Vector2.ONE*draw_radius*0.86,Vector2.ONE*draw_radius*1.72),Color.WHITE if ready else Color(0.48,0.50,0.55))
 fit(v,M.ULT_FRAME if key=="ult" else M.BUTTON_FRAME,Rect2(at-Vector2.ONE*draw_radius,Vector2.ONE*draw_radius*2),Color.WHITE if ready else Color(0.53,0.55,0.60))
 if cd>0:
  var fraction=clampf(cd/maxf(0.001,full),0,1)
  var sector=PackedVector2Array([at])
  for i in range(int(ceil(fraction*48))+1):
   var a=-PI*0.5+TAU*minf(i/48.0,fraction)
   sector.append(at+Vector2(cos(a),sin(a))*radius*0.80)
  if fraction>=0.999:v.draw_circle(at,radius*0.80,Color(0.01,0.02,0.035,0.37))
  elif fraction>0.001 and sector.size()>=3:v.draw_colored_polygon(sector,Color(0.01,0.02,0.035,0.37))
  v.draw_arc(at,radius*0.95,-PI*0.5,-PI*0.5+TAU*fraction,48,Color(GOLD,0.72),2.5*u,true)
  var chip=Rect2(at+Vector2(-radius*0.56,radius*0.43),Vector2(radius*1.12,28*u))
  v.draw_style_box(style(Color(INK,0.90),6*u),chip)
  number(v,chip,("%.1f"%cd) if cd<10 else str(int(ceil(cd))),24*u,Color("f2f4fa"))
 if key=="ult":
  var badge=Rect2(at+Vector2(-radius*0.32,radius*0.50),Vector2.ONE*radius*0.64)
  fit(v,M.STOCK_FRAME,badge,Color.WHITE if ready else Color(0.48,0.49,0.53))
  number(v,badge,str(stock),24*u,GOLD if ready else Color("b1b5c2"))
  if ready:v.draw_arc(at,radius*0.94,0,TAU,48,Color(GOLD,0.85),2*u,true)
 if key.begins_with("sk") and "skill_ready_flash" in pl and pl.skill_ready_flash.has(id):
  v.draw_arc(at,radius*0.97,0,TAU,48,Color(GOLD,float(pl.skill_ready_flash[id])/0.25*0.8),2*u,true)
 if pressed:v.draw_arc(at,radius*0.89,0,TAU,40,Color(GOLD,0.65),u,true)
