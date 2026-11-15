extends RefCounted
## 表示だけを担当する。SP消費・派生の適用は progress.gd に委ねる。
const SkillData = preload("res://scripts/skill_tree.gd")
const NAMES = {"rana":"ラナ", "lily":"リリィ", "ranka":"ランカ"}
const ABOUT = {
 "rana": {"flurry":"前方を連続で斬る。敵を寄せ、最後に吹き飛ばす。", "rift":"前方の地面を走る衝撃。離れた敵を打ち上げる。", "vortex":"周囲の敵を吸い寄せて連打。最後に外へ弾く。", "ult":"必殺ゲージで放つ連続斬撃。強化で威力と消費が変化。"},
 "lily": {"rush":"雷をまとって敵へ突進。離れた敵との距離を詰める。", "barrage":"近くの敵へ拳を連打。最後に強い一撃を放つ。", "storm":"周囲へ雷を落とす範囲攻撃。群れをまとめて狙う。", "ult":"必殺ゲージを使う天雷。強化で威力と消費量が変わる。"},
 "ranka": {"shot":"前方へ気の弾を放つ遠距離攻撃。離れた敵を狙う。", "ring":"周囲へ気の輪を広げる範囲攻撃。近づく敵をまとめて打つ。", "quake":"広い範囲へ星の衝撃を降らせ、群れを攻撃する。", "ult":"必殺ゲージを使う天照。強化で威力と消費量が変わる。"}
}
const DERIV_ABOUT = {
 "senpu":"締めの一撃が前方6mまで届く帯になる。", "iai":"連打を4回に減らし、一撃を重くする。", "donkomi":"連打15回。一撃は軽く、引き寄せは強くなる。",
 "sansa":"前方に加え、奥と手前の斜めにも衝撃を出す。", "enshin":"衝撃を5回に増やし、前方12mまで伸ばす。", "fukiage":"終点に爆発を加え、敵を大きく打ち上げる。",
 "ouzu":"吸い寄せる範囲が広がる。連打は5回に減る。", "aruki":"渦を出しながら移動できる。", "hanten":"吸い寄せの代わりに、敵を外へ押し続ける。",
 "ofuku":"敵へ突進して元の位置へ戻る。往復で攻撃。", "rensa":"近くの別の敵へ跳び、最大3体へ続けて突進する。",
 "arashi":"連打を20回に増やす。一撃は軽くなる。", "tataki":"締めが周囲を巻き込む叩きつけになる。",
 "tsuirai":"近くの敵を最大3体まで狙って雷を落とす。", "sokujin":"攻撃範囲が狭くなる代わりに、待ち時間を短くする。",
 "sandan":"前方に加え、奥と手前の斜めにも弾を放つ。", "tame":"連打をなくし、最後の一発を強い貫通攻撃にする。",
 "hamon":"輪が遠くまで広がる。", "kekkai":"締めの位置に攻撃が残り、繰り返し当たる。",
 "seigun":"星の連打を10回に増やす。一撃は軽くなる。", "itten":"範囲を狭める代わりに、威力を集中させる。"
}

static func detail(pr, ch:String, id:String, candidate:String="", ult_cost:float=100.0)->Dictionary:
 var row:Dictionary = SkillData.rows(ch)[id]
 var lv:int = pr.skill_level(ch,id)
 var next_lv:int = mini(lv+1,int(row.max_lv))
 var active:String = pr.deriv_of(ch,id)
 var base:Dictionary = SkillData.base_table(ch)[id]
 var current:Dictionary = SkillData.apply(ch,id,base,lv,active)
 var after:Dictionary = SkillData.apply(ch,id,base,next_lv,active)
 var is_ult:bool = id == "ult"
 var status:String = "最大レベル" if lv >= int(row.max_lv) else "SPが足りません" if pr.sp_of(ch)<1 else "強化すると派生が開放" if next_lv==SkillData.DERIV_LV else "1 SPで強化できます"
 var ds:Dictionary = row.get("derivs",{})
 var chosen:Dictionary = ds.get(candidate,{})
 var todo:bool = chosen.get("todo",false)
 var can_deriv:bool = not chosen.is_empty() and not todo and lv>=SkillData.DERIV_LV
 var deriv_status:String = "派生を選ぶと効果を確認できます"
 if not chosen.is_empty():
  deriv_status = "必殺技の派生は未実装" if todo else "技Lv3で開放・SP不要" if lv<SkillData.DERIV_LV else "元の技に戻す" if active==candidate else "この派生に変更・SP不要"
 return {"name":row.name, "about":ABOUT[ch][id], "lv":lv, "next_lv":next_lv,
  "power":int(round(SkillData.k_mul(lv)*100)), "next_power":int(round(SkillData.k_mul(next_lv)*100)),
  "timing":ult_cost*float(current.get("cost_mul",1)) if is_ult else float(current.get("cd",0)),
  "next_timing":ult_cost*float(after.get("cost_mul",1)) if is_ult else float(after.get("cd",0)),
  "can_level":pr.can_level(ch,id), "status":status, "active":active,
  "candidate":candidate, "deriv_name":chosen.get("name","派生"),
  "deriv_about":"内容が決まるまで選べません。" if todo else DERIV_ABOUT.get(candidate,""),
  "can_deriv":can_deriv, "deriv_status":deriv_status}

static func refund(pr,ch:String)->int:
 var n:int=0
 for id in pr.skill_lv.get(ch,{}):
  n+=maxi(0,int(pr.skill_lv[ch][id])-(1 if SkillData.BASE_SKILLS[ch].has(id) else 0))
 return n
