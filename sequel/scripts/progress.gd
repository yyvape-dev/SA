extends RefCounted
## 成長（最小）とセーブ：レベル・経験値・武器1枠・ハードの解放・最速の記録。端末に保存（Web は IndexedDB の user://）。

var path := "user://sa2_save.json"
var lv := 1
var xp := 0
var weapon := 0          # 武器の攻撃力（0＝素手相当の初期の剣）
var hard_open := false
var best := {}           # diff -> 最速のクリア時間（秒）
var clears := {}         # diff -> クリア回数
const SKILLS_DEFAULT := ["flurry", "rift", "vortex"]
var skills_owned: Array = SKILLS_DEFAULT.duplicate()   # 持っている技（今は最初から3つ）
var skill_slots: Array = SKILLS_DEFAULT.duplicate()    # 枠1〜3 の技の id
## スキルツリー（specs/skill_tree.md、2026-11-14）。キャラ＝"rana"・"lily"・"ranka"
const SkillTree := preload("res://scripts/skill_tree.gd")
var sp := {"rana": 0, "lily": 0, "ranka": 0}   # 残りの SP（キャラごと）
var skill_lv := {}           # キャラ → 技 id → 技レベル（無ければ最初の技は 1、ほかは持っていない）
var deriv := {}              # キャラ → 技 id → 派生 id
var first_clear_paid := {}   # 難易度 → 初回クリアの SP を渡したか

func reset() -> void:
	lv = 1
	xp = 0
	weapon = 0
	hard_open = false
	best = {}
	clears = {}
	skills_owned = SKILLS_DEFAULT.duplicate()
	skill_slots = SKILLS_DEFAULT.duplicate()
	sp = {"rana": 0, "lily": 0, "ranka": 0}
	skill_lv = {}
	deriv = {}
	first_clear_paid = {}

## ---------- スキルツリー ----------
func skill_level(ch: String, id: String) -> int:
	var d: Dictionary = skill_lv.get(ch, {})
	if d.has(id):
		return int(d[id])
	return 1 if SkillTree.BASE_SKILLS.get(ch, []).has(id) else 0

func deriv_of(ch: String, id: String) -> String:
	return str(deriv.get(ch, {}).get(id, ""))

func sp_of(ch: String) -> int:
	return int(sp.get(ch, 0))

func _add_sp_all(n: int) -> void:
	for ch in SkillTree.CHARS:
		sp[ch] = sp_of(ch) + n

## 技レベルを1つ上げる（SP 1）。持っていない技は取る（need_lv・need を満たすとき）
func can_level(ch: String, id: String) -> bool:
	var r: Dictionary = SkillTree.rows(ch).get(id, {})
	if r.is_empty() or sp_of(ch) < 1:
		return false
	var cur := skill_level(ch, id)
	if cur >= int(r.max_lv):
		return false
	if cur == 0:   # 新しい技の解放
		if lv < int(r.need_lv):
			return false
		var nd: Array = r.need
		if nd.size() == 2 and skill_level(ch, str(nd[0])) < int(nd[1]):
			return false
	return true

func level_up(ch: String, id: String) -> bool:
	if not can_level(ch, id):
		return false
	if not skill_lv.has(ch):
		skill_lv[ch] = {}
	skill_lv[ch][id] = skill_level(ch, id) + 1
	sp[ch] = sp_of(ch) - 1
	if ch == "rana" and id != "ult" and not skills_owned.has(id):
		skills_owned.append(id)
	return true

## 派生を選ぶ（技レベル 3 以上、SP は使わない）。同じものを選ぶと外す（元の技に戻す）
func set_deriv(ch: String, id: String, did: String) -> bool:
	var r: Dictionary = SkillTree.rows(ch).get(id, {})
	if skill_level(ch, id) < SkillTree.DERIV_LV or not r.get("derivs", {}).has(did) or r.derivs[did].get("todo", false):
		return false
	if not deriv.has(ch):
		deriv[ch] = {}
	if deriv_of(ch, id) == did:
		deriv[ch].erase(id)
	else:
		deriv[ch][id] = did
	return true

## 振り直し（街でだけ）：そのキャラの技レベルを最初へ戻し、使った SP を全部戻す。派生も外す
func respec(ch: String) -> void:
	var back := 0
	for id in skill_lv.get(ch, {}):
		var base := 1 if SkillTree.BASE_SKILLS.get(ch, []).has(id) else 0
		back += maxi(0, int(skill_lv[ch][id]) - base)
	skill_lv[ch] = {}
	deriv[ch] = {}
	sp[ch] = sp_of(ch) + back
	if ch == "rana":
		skills_owned = skills_owned.filter(func(x): return SKILLS_DEFAULT.has(x))
		for i in skill_slots.size():
			if not skills_owned.has(skill_slots[i]):
				skill_slots[i] = SKILLS_DEFAULT[i]

## 各難易度の初回クリア：3人それぞれ +2（1回だけ）。渡したら true
func pay_first_clear(diff: String) -> bool:
	if bool(first_clear_paid.get(diff, false)):
		return false
	first_clear_paid[diff] = true
	_add_sp_all(2)
	return true

## 次のレベルまでに要る経験値
func need() -> int:
	return 60 + 40 * (lv - 1)

## 経験値を足す。上がったレベルの数を返す
func add_exp(n: int) -> int:
	xp += n
	var up := 0
	while xp >= need():
		xp -= need()
		lv += 1
		up += 1
	_add_sp_all(up)   # レベルが1つ上がるごとに 3人それぞれ SP +1
	return up

func hp_max() -> float:
	return 100.0 + 12.0 * (lv - 1)

## 攻撃の倍率：レベル1つで +6％、武器の攻撃力1で +2％
func atk_mul() -> float:
	return 1.0 + 0.06 * (lv - 1) + 0.02 * weapon

func load_save() -> void:
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return
	lv = int(d.get("lv", 1))
	xp = int(d.get("xp", 0))
	weapon = int(d.get("weapon", 0))
	hard_open = bool(d.get("hard_open", false))
	best = d.get("best", {})
	clears = d.get("clears", {})
	var so = d.get("skills_owned", null)
	if so is Array and not so.is_empty():
		skills_owned = so
	var ss = d.get("skill_slots", null)
	if ss is Array and ss.size() == 3:
		skill_slots = ss
	if d.has("sp") and d.sp is Dictionary:
		for ch in SkillTree.CHARS:
			sp[ch] = int(d.sp.get(ch, 0))
		skill_lv = d.get("skill_lv", {})
		deriv = d.get("deriv", {})
		first_clear_paid = d.get("first_clear_paid", {})
	else:
		migrate_sp()

## 前のセーブ（sp が無い）からの移行：SP ＝（今のレベル −1）＋ 2 ×（クリアが1回以上の難易度の数）。技レベルは全部1、派生はなし
## 初回クリアを済ませた難易度は「渡した」にする（二重に渡さない）
func migrate_sp() -> void:
	var n := 0
	first_clear_paid = {}
	for k in clears:
		if int(clears[k]) >= 1:
			n += 1
			first_clear_paid[k] = true
	for ch in SkillTree.CHARS:
		sp[ch] = (lv - 1) + 2 * n
	skill_lv = {}
	deriv = {}

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"lv": lv, "xp": xp, "weapon": weapon, "hard_open": hard_open, "best": best, "clears": clears, "skills_owned": skills_owned, "skill_slots": skill_slots,
		"sp": sp, "skill_lv": skill_lv, "deriv": deriv, "first_clear_paid": first_clear_paid}))
	f.close()
