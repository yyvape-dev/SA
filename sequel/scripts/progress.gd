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

func reset() -> void:
	lv = 1
	xp = 0
	weapon = 0
	hard_open = false
	best = {}
	clears = {}
	skills_owned = SKILLS_DEFAULT.duplicate()
	skill_slots = SKILLS_DEFAULT.duplicate()

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

func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"lv": lv, "xp": xp, "weapon": weapon, "hard_open": hard_open, "best": best, "clears": clears, "skills_owned": skills_owned, "skill_slots": skill_slots}))
	f.close()
