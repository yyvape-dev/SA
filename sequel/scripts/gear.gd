extends RefCounted
## 装備（③、2026-11-18、specs/gear.md）。検討表「ドロップ」「お金と回復」の案と、ユーザーの決定。「仮」は Claude が決めた数値。
## 物 1 つ＝辞書 {uid, slot, tier(1〜4), pow, trait, tv, plus, theme}
##   slot：weapon＝武器 / armor＝防具 / acc＝装飾品 / lily・ranka＝仲間の装備
##   weapon：pow＝攻撃力（今までの武器の数字と同じ尺度）、trait＝crit（会心%）・cd（技の待ち −%）・down（ダウン値 +%）
##   armor：pow＝体力 +、tv＝受ける傷 −%
##   acc：trait＝heal（回復量 +%）・gold（お金 +%）・ult（必殺技のたまり +%）、tv＝その値
##   lily・ranka：tv＝技の強さ +%、pow＝技の待ち −%
##   plus＝強化の段（0〜10）。主な値が 1 段ごとに +8%（仮）

const SLOTS := ["weapon", "armor", "acc", "lily", "ranka"]
const SLOT_NAME := {"weapon": "武器", "armor": "防具", "acc": "装飾品", "lily": "リリィの装備", "ranka": "ランカの装備"}
const SLOT_W := {"weapon": 35, "armor": 25, "acc": 20, "lily": 10, "ranka": 10}   # 落ちる割合（検討表：武器 35・防具 25・装飾品 20・仲間 20）
const TIER_K := [0.0, 1.0, 1.15, 1.3, 1.5]     # 等級ごとの主な値の倍率（仮）
const SELL := [0, 10, 30, 90, 270]             # 売る値段（検討表）
const PLUS_MAX := 10                           # 強化の上限（仮）
const PLUS_K := 0.08                           # 強化 1 段で主な値 +8%（仮）
const BAG_MAX := 30                            # 持ち物の上限（ユーザー了承）。いっぱいの時に拾った物は売った値段のお金に（仮）
const TRAIT_NAME := {"crit": "会心", "cd": "技の待ち", "down": "ダウン値", "heal": "回復量", "gold": "お金", "ult": "必殺技のたまり"}
const MAT_NAME := {"t1": "歯車のかけら", "t2": "裂晶", "t3": "門の破片", "t4": "結晶の芯"}   # 検討表の例
## 等級の出方（検討表）：[◆1, ◆2, ◆3, ◆4]
const TIER_P := {"normal": [0.70, 0.25, 0.05, 0.0], "hard": [0.0, 0.60, 0.35, 0.05], "expert": [0.0, 0.0, 0.70, 0.30]}
const MAT_P := {"normal": 0.08, "hard": 0.10, "expert": 0.12}   # 雑魚が素材を落とす割合（検討表）、ボスは 3〜5 個
## 工房で売る仲間の装備（検討表：◆1〜2・200〜600G）
const SHOP_ALLY := [["lily", 1, 200], ["ranka", 1, 200], ["lily", 2, 600], ["ranka", 2, 600]]

static func roll_tier(rng: RandomNumberGenerator, diff: String, boss: bool) -> int:
	var p: Array = TIER_P.get(diff, TIER_P.normal)
	var r := rng.randf()
	var t := 1
	var acc := 0.0
	for i in 4:
		acc += float(p[i])
		if r < acc:
			t = i + 1
			break
	if boss:
		t = mini(4, t + 1)   # ボスは雑魚より 1 段上（検討表）
	return t

static func roll_slot(rng: RandomNumberGenerator) -> String:
	var tot := 0
	for k in SLOT_W:
		tot += int(SLOT_W[k])
	var r := rng.randi_range(1, tot)
	for k in SLOT_W:
		r -= int(SLOT_W[k])
		if r <= 0:
			return k
	return "weapon"

## 新しい物。wr＝武器の攻撃力の幅（テーマ・難易度の w／ボスは bw）
static func make(rng: RandomNumberGenerator, uid: int, slot: String, tier: int, wr: Array, theme: String) -> Dictionary:
	var k: float = TIER_K[tier]
	var it := {"uid": uid, "slot": slot, "tier": tier, "pow": 0, "trait": "", "tv": 0.0, "plus": 0, "theme": theme}
	var base := float(rng.randi_range(int(wr[0]), int(wr[1])))
	match slot:
		"weapon":
			it.pow = int(round(base * k))
			it.trait = ["crit", "cd", "down"][rng.randi() % 3]
			it.tv = {"crit": 4.0 + 3.0 * tier, "cd": 3.0 + 2.5 * tier, "down": 10.0 + 8.0 * tier}[it.trait] * rng.randf_range(0.85, 1.15)
		"armor":
			it.pow = int(round(base * 1.5 * k))
			it.tv = (2.0 + 1.5 * tier) * rng.randf_range(0.85, 1.15)
		"acc":
			it.trait = ["heal", "gold", "ult"][rng.randi() % 3]
			it.tv = (8.0 + 4.0 * tier) * rng.randf_range(0.85, 1.15)
		_:   # 仲間の装備
			it.tv = (6.0 + 4.0 * tier) * rng.randf_range(0.85, 1.15)
			it.pow = int(round((2.0 + 1.5 * tier) * rng.randf_range(0.85, 1.15)))
	it.tv = snappedf(float(it.tv), 0.1)
	return it

## 強化を入れた主な値
static func plus_k(it: Dictionary) -> float:
	return 1.0 + PLUS_K * int(it.get("plus", 0))

static func weapon_pow(it: Dictionary) -> float:
	return float(it.pow) * plus_k(it)

## 比べる点数（同じ枠の中で、強さの目安）。金の印を出すかに使う
static func score(it: Dictionary) -> float:
	var k := plus_k(it)
	match str(it.slot):
		"weapon": return float(it.pow) * k * (1.0 + float(it.tv) / 100.0)
		"armor": return float(it.pow) * k + float(it.tv) * 6.0 * k
		"acc": return float(it.tv) * k
		_: return (float(it.tv) + float(it.pow)) * k

static func name_of(it: Dictionary) -> String:
	var s: String = SLOT_NAME.get(str(it.slot), "?")
	if int(it.get("plus", 0)) > 0:
		s += " +%d" % int(it.plus)
	return s

static func diamonds(tier: int) -> String:
	return "◆".repeat(tier)

## 1 行の説明（数字だけ。強化の分を含む）
static func lines(it: Dictionary) -> Array:
	var k := plus_k(it)
	match str(it.slot):
		"weapon": return ["攻撃力 %d" % int(round(float(it.pow) * k)), "%s +%.0f%%" % [TRAIT_NAME[it.trait], float(it.tv)]]
		"armor": return ["体力 +%d" % int(round(float(it.pow) * k)), "受ける傷 −%.1f%%" % (float(it.tv) * k)]
		"acc": return ["%s +%.0f%%" % [TRAIT_NAME[it.trait], float(it.tv) * k]]
		_: return ["技の強さ +%.0f%%" % (float(it.tv) * k), "技の待ち −%.0f%%" % (float(it.pow) * k)]

static func sell_price(it: Dictionary) -> int:
	return int(SELL[int(it.tier)])

## 次の強化の値段：100G×段＋素材（段の数）、必ず成功（検討表）
static func up_cost(it: Dictionary) -> Array:
	var n := int(it.get("plus", 0)) + 1
	return [100 * n, n]
