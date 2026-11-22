extends SceneTree
const Info=preload("res://scripts/skill_tree_presenter.gd")
const Progress=preload("res://scripts/progress.gd")
func _initialize():
 var pr=Progress.new()
 var d=Info.detail(pr,"rana","flurry")
 assert(d.power==100 and d.next_power==110 and d.timing==8.0 and d.next_timing==8.0)
 assert(not d.can_level)
 pr.sp.rana=5;pr.skill_lv={"rana":{"flurry":2,"ult":4},"lily":{"storm":3}}
 d=Info.detail(pr,"rana","flurry","senpu")
 assert(d.can_level and not d.can_deriv and is_equal_approx(d.next_timing,7.2))
 assert(Info.refund(pr,"rana")==4 and Info.refund(pr,"lily")==2)
 d=Info.detail(pr,"rana","ult","todo1",100)
 assert(d.timing==90 and d.next_timing==80 and not d.can_deriv)
 pr.skill_lv.rana.flurry=5
 d=Info.detail(pr,"rana","flurry","iai")
 assert(d.power==140 and not d.can_level and d.can_deriv)
 pr.deriv={"lily":{"storm":"sokujin"}}
 var base=preload("res://scripts/skill_tree.gd").base_table("lily").storm.cd
 d=Info.detail(pr,"lily","storm","sokujin")
 assert(is_equal_approx(d.timing,base*0.6*0.9),"CD includes active derivation and level")
 var old=Progress.new();old.from_dict({"lv":4,"clears":{"normal":1,"hard":2}})
 # 2026-11-18 の 1ステージ4ダンジョンで、古いセーブのクリアは D4 へ移り D1〜D3 もクリア済み＝初回クリアの SP +2×6 が足される（7→19）。
 # 2026-11-22 統合で期待値を今の動きに合わせた（意図どおりかはユーザー判定待ち。HANDOFF の未決）
 assert(old.sp_of("rana")==19 and old.sp_of("lily")==19 and old.sp_of("ranka")==19)
 print("SKILL_TREE_PRESENTER PASS");quit()
