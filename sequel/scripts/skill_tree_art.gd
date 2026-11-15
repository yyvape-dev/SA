extends RefCounted
## 育成画面。描画とタッチ矩形を共通化し、完成済みの遠征盤／戦闘HUDは変更しない。
const SkillData=preload("res://scripts/skill_tree.gd")
const Info=preload("res://scripts/skill_tree_presenter.gd")
const Combat=preload("res://scripts/combat_hud_art.gd")
const Faces=preload("res://scripts/t6_hud_art.gd")
const Board=preload("res://scripts/dungeon_select_art.gd")
const FONT=preload("res://assets/event_idle/sa2_t6_ja.otf")
const GOLD=Color("d9b772")
const TEXT=Color("eee6d4")
const MUTED=Color("a9b5c3")
const BLUE=Color("71bbdf")
const INK=Color("0b111b")

static func rects(sz:Vector2,ch:String)->Dictionary:
 var u:float=sz.y/720.0
 var width:float=minf(1480,sz.x/u-32)
 var p:Vector2=Vector2((sz.x-width*u)*0.5,20*u)
 var panel:Rect2=Rect2(p,Vector2(width,680)*u)
 var out:Dictionary={"panel":panel}
 out.tab_slot=Rect2(p+Vector2(16,10)*u,Vector2(166,84)*u)
 out.tab_tree=Rect2(p+Vector2(190,10)*u,Vector2(166,84)*u)
 out.close=Rect2(p+Vector2(width-94,10)*u,Vector2(82,84)*u)
 var detail_w:float=384+(width-1232)*0.4
 var row_w:float=width-164-detail_w-22
 var dx:float=140+row_w+16
 for i in 3:
  out["ch%d"%i]=Rect2(p+Vector2(14,112+i*146)*u,Vector2(112,134)*u)
 var rows:Dictionary=SkillData.rows(ch)
 var ids:Array=SkillData.order(ch)
 for j in ids.size():
  var id:String=ids[j]
  var row:Rect2=Rect2(p+Vector2(140,112+j*112)*u,Vector2(row_w,104)*u)
  out["row_"+id]=row
  # Selection is separate from the SP spending action in the detail panel.
  out["lv_"+id]=Rect2(row.position,Vector2(row_w-282,104)*u)
  var ds:Array=rows[id].get("derivs",{}).keys()
  for k in ds.size():
   out["d_%s_%s"%[id,ds[k]]]=Rect2(row.position+Vector2(row_w-278+k*92,8)*u,Vector2(86,88)*u)
 out.detail=Rect2(p+Vector2(dx,112)*u,Vector2(detail_w,460)*u)
 out.about=Rect2(out.detail.position+Vector2(12,42)*u,Vector2(detail_w-24,68)*u)
 out.deriv_about=Rect2(out.detail.position+Vector2(12,292)*u,Vector2(detail_w-24,80)*u)
 out.upgrade=Rect2(p+Vector2(dx+12,284)*u,Vector2(detail_w-24,82)*u)
 out.apply_deriv=Rect2(p+Vector2(dx+12,486)*u,Vector2(detail_w-24,82)*u)
 out.respec=Rect2(p+Vector2(width-398,580)*u,Vector2(384,84)*u)
 return out

static func box(v,rc:Rect2,fill:Color,border:Color=Color("51483a"),thickness:float=1.0)->void:
 v.draw_style_box(Combat.style(fill,6*v.size.y/720.0),rc)
 v.draw_rect(rc,border,false,maxf(1,thickness*v.size.y/720.0))

static func backing(v)->void:
 # Reuse the approved fabric/brass artwork at its aspect ratio; the existing
 # board renderer preserves the hardware corners separately.
 Board.backing(v,v.size)

static func label(v,rc:Rect2,s:String,fs:float=24,col:Color=TEXT,center:bool=false)->void:
 var u:float=v.size.y/720.0
 v.draw_string(FONT,rc.position+Vector2(0,(rc.size.y+fs*u*0.72)*0.5),s,HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,rc.size.x,int(fs*u),col)

static func lines(v,rc:Rect2,s:String,fs:float=23,col:Color=MUTED)->void:
 var u:float=v.size.y/720.0
 var para=TextParagraph.new()
 para.add_string(s,FONT,int(fs*u))
 para.width=rc.size.x
 para.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
 para.draw(v.get_canvas_item(),rc.position,col)

static func button(v,rc:Rect2,s:String,on:bool=true,selected:bool=false)->void:
 box(v,rc,Color("283c48") if on else Color("17202b"),GOLD if on or selected else Color("525a64"),2 if selected else 1)
 label(v,rc,s,26,GOLD if on else MUTED,true)

static func slot_rects(sz:Vector2,owned:Array)->Dictionary:
 var out:Dictionary=rects(sz,"rana")
 var u:float=sz.y/720.0
 var c:Vector2=out.panel.get_center()
 for i in 3:
  out["slot%d"%i]=Rect2(c+Vector2((i-1)*284-134,-178)*u,Vector2(268,152)*u)
 for i in owned.size():
  out["own%d"%i]=Rect2(c+Vector2((i-(owned.size()-1)*0.5)*284-134,72)*u,Vector2(268,152)*u)
 return out

static func slots(v,hud)->void:
 var u:float=v.size.y/720.0
 var pr=hud.main.progress
 var r:Dictionary=slot_rects(v.size,pr.skills_owned)
 var p:Vector2=r.panel.position
 v.draw_rect(Rect2(Vector2.ZERO,v.size),Color(0.01,0.015,0.025,0.94))
 backing(v)
 button(v,r.tab_slot,"技のセット",true,true)
 button(v,r.tab_tree,"スキル育成",true)
 button(v,r.close,"×",true)
 label(v,Rect2(p+Vector2(386,20)*u,Vector2(700,60)*u),"ラナの技を戦闘の3枠へセット",28,GOLD)
 label(v,Rect2(p+Vector2(24,112)*u,Vector2(900,40)*u),"① 下の技を選ぶ  →  ② 入れたい上の枠を押す",26,TEXT)
 var rows:Dictionary=SkillData.rows("rana")
 for i in 3:
  var rc:Rect2=r["slot%d"%i]
  var id:String=pr.skill_slots[i]
  box(v,rc,Color("203342"),GOLD if hud.slot_pick!="" else BLUE,2)
  Combat.fit(v,Combat.icon("rana",id),Rect2(rc.position+Vector2(10,18)*u,Vector2(92,92)*u))
  label(v,Rect2(rc.position+Vector2(108,18)*u,Vector2(152,36)*u),"枠 %d"%(i+1),24,MUTED)
  label(v,Rect2(rc.position+Vector2(108,61)*u,Vector2(152,38)*u),rows[id].name,27,TEXT)
  label(v,Rect2(rc.position+Vector2(8,114)*u,Vector2(252,30)*u),"ここに入れる" if hud.slot_pick!="" else "セット中",22,GOLD if hud.slot_pick!="" else MUTED,true)
 label(v,Rect2(p+Vector2(24,344)*u,Vector2(900,38)*u),"使える技  /  同じ技は入れ替えます",24,MUTED)
 for i in pr.skills_owned.size():
  var id:String=pr.skills_owned[i]
  var rc:Rect2=r["own%d"%i]
  var on:bool=hud.slot_pick==id
  box(v,rc,Color("233846") if on else INK,GOLD if on else Color("51483a"),2 if on else 1)
  Combat.fit(v,Combat.icon("rana",id),Rect2(rc.position+Vector2(10,18)*u,Vector2(92,92)*u))
  label(v,Rect2(rc.position+Vector2(108,28)*u,Vector2(152,40)*u),rows[id].name,27,TEXT)
  label(v,Rect2(rc.position+Vector2(108,73)*u,Vector2(152,32)*u),"Lv %d"%pr.skill_level("rana",id),24,MUTED)
  label(v,Rect2(rc.position+Vector2(8,114)*u,Vector2(252,30)*u),"選択中" if on else "押して選ぶ",22,GOLD if on else MUTED,true)
 label(v,Rect2(p+Vector2(24,614)*u,Vector2(1100,40)*u),"街でのみ変更できます。閉じると保存。仲間の技は自動戦闘で使われます。",23,MUTED)

static func draw(v,hud)->void:
 var u:float=v.size.y/720.0
 var ch:String=hud.tree_ch
 var pr=hud.main.progress
 var r:Dictionary=rects(v.size,ch)
 var p:Vector2=r.panel.position
 v.draw_rect(Rect2(Vector2.ZERO,v.size),Color(0.01,0.015,0.025,0.94))
 backing(v)
 button(v,r.tab_slot,"技のセット",false)
 button(v,r.tab_tree,"スキル育成",true,true)
 button(v,r.close,"×",true)
 label(v,Rect2(p+Vector2(386,16)*u,Vector2(380,36)*u),Info.NAMES[ch]+"  /  残り %d SP"%pr.sp_of(ch),30,GOLD)
 label(v,Rect2(p+Vector2(386,53)*u,Vector2(540,28)*u),"技を選ぶ → 説明を確認 → 強化・派生",22,MUTED)
 var faces:Dictionary={"rana":Faces.RANA,"lily":Faces.LILY,"ranka":Faces.RANKA}
 for i in 3:
  var cid:String=SkillData.CHARS[i]
  var rc:Rect2=r["ch%d"%i]
  var on:bool=cid==ch
  box(v,rc,Color("233846") if on else INK,GOLD if on else Color("51483a"),2 if on else 1)
  Combat.portrait(v,faces[cid],Rect2(rc.position+Vector2(20,2)*u,Vector2(72,72)*u))
  label(v,Rect2(rc.position+Vector2(0,74)*u,Vector2(112,28)*u),Info.NAMES[cid],25,TEXT,true)
  label(v,Rect2(rc.position+Vector2(0,103)*u,Vector2(112,26)*u),"%d SP"%pr.sp_of(cid),22,GOLD,true)
 var rows:Dictionary=SkillData.rows(ch)
 for id in SkillData.order(ch):
  var row:Rect2=r["row_"+id]
  var selected:bool=hud.tree_skill==id
  var lv:int=pr.skill_level(ch,id)
  box(v,row,Color("223442") if selected else Color("131f2b"),BLUE if selected else Color("4a4c49"),2 if selected else 1)
  var icon=Combat.icon(ch,id)
  Combat.fit(v,icon,Rect2(row.position+Vector2(5,15)*u,Vector2(72,72)*u))
  var lr:Rect2=r["lv_"+id]
  var name:String=rows[id].name
  label(v,Rect2(row.position+Vector2(80,10)*u,Vector2(lr.size.x-84*u,36*u)),name,26,GOLD if id=="ult" else TEXT)
  label(v,Rect2(row.position+Vector2(80,46)*u,Vector2(130,25)*u),"Lv %d / 5"%lv,22,MUTED)
  for k in 5:
   v.draw_circle(row.position+Vector2(86+k*20,84)*u,5*u,GOLD if k<lv else Color("49515d"))
  var ds:Array=rows[id].get("derivs",{}).keys()
  for did in ds:
   var dr:Rect2=r["d_%s_%s"%[id,did]]
   var todo:bool=rows[id].derivs[did].get("todo",false)
   var active:bool=pr.deriv_of(ch,id)==did
   var preview:bool=selected and hud.tree_deriv==did
   var enabled:bool=lv>=3 and not todo
   box(v,dr,Color("393322") if active else INK,GOLD if active else BLUE if preview else Color("4a4c49"),2 if active or preview else 1)
   label(v,Rect2(dr.position,Vector2(dr.size.x,48*u)),"準備中" if todo else rows[id].derivs[did].name,22,TEXT if enabled else MUTED,true)
   label(v,Rect2(dr.position+Vector2(0,49)*u,Vector2(dr.size.x,30*u)),"選択中" if active else "未実装" if todo else "Lv3" if not enabled else "派生",19,GOLD if active else MUTED,true)
 var id:String=hud.tree_skill
 var d:Dictionary=Info.detail(pr,ch,id,hud.tree_deriv,float(hud.main.battle.ULT_COST))
 var detail:Rect2=r.detail
 box(v,detail,INK,Color("71614a"))
 var at:Vector2=detail.position+Vector2(12,8)*u
 var width:float=detail.size.x-24*u
 label(v,Rect2(at,Vector2(width,34*u)),d.name+"  Lv%d"%d.lv,28,GOLD)
 lines(v,r.about,d.about,23,TEXT)
 label(v,Rect2(at+Vector2(0,112)*u,Vector2(width,28*u)),"威力補正  %d%% → %d%%"%[d.power,d.next_power],24,BLUE)
 var timing:String="必殺消費  %.0f → %.0f"%[d.timing,d.next_timing] if id=="ult" else "待ち時間  %.1f → %.1f 秒"%[d.timing,d.next_timing]
 label(v,Rect2(at+Vector2(0,134)*u,Vector2(width,28*u)),timing,23,TEXT)
 var upgrade_text:String="強化 1 SP・派生開放" if d.lv==2 else "強化  1 SP"
 button(v,r.upgrade,upgrade_text if d.can_level else d.status,d.can_level)
 var dp:Vector2=detail.position+Vector2(12,258)*u
 label(v,Rect2(dp,Vector2(width,29*u)),d.deriv_name if hud.tree_deriv!="" else "派生は技Lv3で開放",25,GOLD)
 lines(v,r.deriv_about,d.deriv_about if hud.tree_deriv!="" else "枝を選んで効果を比較。派生は1つだけ適用。SP不要。",23,TEXT)
 var apply_text:String=d.deriv_status
 if d.can_deriv and d.active!=hud.tree_deriv:apply_text="この派生にする  0 SP"
 button(v,r.apply_deriv,apply_text,d.can_deriv)
 var footer:Vector2=p+Vector2(18,578)*u
 var help_width:float=r.respec.position.x-footer.x-18*u
 lines(v,Rect2(footer,Vector2(help_width,88*u)),"SP：Lv上昇で各人＋1／各テーマ・難易度の初回クリアで各人＋2。\n仲間の自動戦闘にも反映。街で変更でき、閉じると保存します。",22,MUTED)
 var armed:bool=hud.respec_arm>0
 var refund:int=Info.refund(pr,ch)
 button(v,r.respec,"もう一度押すと確定  ＋%d SP"%refund if armed else Info.NAMES[ch]+"を振り直す  ＋%d SP"%refund,refund>0,armed)
