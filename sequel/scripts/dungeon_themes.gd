extends RefCounted
## ダンジョンのテーマと難易度の表（specs/dungeon_themes.md、2026-11-14）。
## テーマ＝入口から門へ近づく順（奥ほど敵が強い）。難易度＝同じテーマの中の倍率（ノーマル・ハード・エキスパート）。
## 数値は全部仮（Claude Code が当てた値。遊んで直す）。絵が届くまでは、全テーマ歓楽街の部品＋画面の色（tint）で仮置き。

const THEMES := [
	{"id": "t1", "col": Color(0.95, 0.35, 0.85), "tint": Color(1, 1, 1, 0.0),
		"hp": 1.0, "dmg": 1.0, "xp": 1.0, "foes": ["t1e1", "t1e2", "ef", "em", "bf", "bc", "bm"], "boss": "t1b", "pck": "dg1"},   # 前作の仮置き 1・3 は序盤〜中盤（t1〜t3）で新しい敵に入れ替え（2026-11-14 ユーザー）。帝国兵 ef/em は前半（t1・t2）。歓楽街の入口（今の部品）
	{"id": "t2", "col": Color(0.35, 0.8, 1.0), "tint": Color(0.55, 0.78, 1.0, 0.6),
		"hp": 1.6, "dmg": 1.4, "xp": 1.5, "foes": ["t2e1", "t2e2", "ef", "em", "bf", "bc", "bm"], "boss": "g1", "pck": "dg_t2"},   # 奥の路地（半魔界）。部品 assets/dungeon/t2（2026-11-14）
	{"id": "t3", "col": Color(0.72, 0.42, 1.0), "tint": Color(0.78, 0.5, 1.0, 0.65),
		"hp": 2.4, "dmg": 1.9, "xp": 2.2, "foes": ["t3e1", "bf", "bc", "bm"], "boss": "g1", "pck": "dg1"},   # 門の手前の廃墟
	{"id": "t4", "col": Color(0.35, 1.0, 0.75), "tint": Color(0.5, 1.0, 0.8, 0.6),
		"hp": 3.4, "dmg": 2.5, "xp": 3.0, "foes": ["mo", "gm"], "boss": "hr", "pck": "dg1"},   # 深層：爪の怪物・ガトリングの機兵、ボス＝馬型の機兵（突進）（2026-11-14 ユーザー）。   # 地下の採掘坑
]

## 1 群れの増え方 add、経験値 xp（1 体）、武器の落ちる確率 drop。部屋も敵も約 4 倍になったので、1 体の経験値と落ちる確率は前（12・0.14）より下げた
const DIFFS := {
	"normal": {"hp": 1.0, "dmg": 1.0, "add": 0, "boss_hp": 1100.0, "boss_dmg": 14, "xp": 3, "boss_xp": 150, "drop": 0.04, "w": [2, 6], "bw": [12, 18]},
	"hard":   {"hp": 1.7, "dmg": 1.6, "add": 1, "boss_hp": 2200.0, "boss_dmg": 24, "xp": 5, "boss_xp": 260, "drop": 0.05, "w": [7, 13], "bw": [22, 30]},
	"expert": {"hp": 2.6, "dmg": 2.3, "add": 2, "boss_hp": 3400.0, "boss_dmg": 34, "xp": 8, "boss_xp": 400, "drop": 0.06, "w": [12, 20], "bw": [32, 42]},
}
const DIFF_ORDER := ["normal", "hard", "expert"]

static func index_of(id: String) -> int:
	for i in THEMES.size():
		if THEMES[i].id == id:
			return i
	return 0

## テーマ×難易度を掛けた設定（dungeon.gd の cfg）
static func cfg(theme: String, diff: String) -> Dictionary:
	var t: Dictionary = THEMES[index_of(theme)]
	var d: Dictionary = DIFFS[diff].duplicate(true)
	d.hp = float(d.hp) * float(t.hp)
	d.dmg = float(d.dmg) * float(t.dmg)
	d.boss_hp = float(d.boss_hp) * float(t.hp)
	d.boss_dmg = int(round(float(d.boss_dmg) * float(t.dmg)))
	d.xp = maxi(1, int(round(float(d.xp) * float(t.xp))))
	d.boss_xp = int(round(float(d.boss_xp) * float(t.xp)))
	var tw: int = index_of(theme) * 6   # 奥のテーマほど武器の数字も上がる
	d.w = [int(d.w[0]) + tw, int(d.w[1]) + tw]
	d.bw = [int(d.bw[0]) + tw, int(d.bw[1]) + tw]
	d.foes = t.foes
	d.boss = t.boss
	return d

static func key(theme: String, diff: String) -> String:
	return "%s_%s" % [theme, diff]

## このテーマの部品の絵があるか（無ければ歓楽街の部品＋画面の色で仮置き）
static func has_parts(theme: String) -> bool:
	return theme != "t1" and ResourceLoader.exists("res://assets/dungeon/%s/%s_b1.webp" % [theme, theme])
