extends RefCounted
## ダンジョンのテーマと難易度の表（specs/dungeon_themes.md、2026-11-14）。
## テーマ＝入口から門へ近づく順（奥ほど敵が強い）。難易度＝同じテーマの中の倍率（ノーマル・ハード・エキスパート）。
## 数値は全部仮（Claude Code が当てた値。遊んで直す）。絵が届くまでは、全テーマ歓楽街の部品＋画面の色（tint）で仮置き。

const THEMES := [
	{"id": "t1", "col": Color(0.95, 0.35, 0.85), "tint": Color(1, 1, 1, 0.0),
		"hp": 1.0, "dmg": 1.0, "xp": 1.0, "foes": ["t1e1", "t1e2", "ef", "em", "bf", "bc", "bm"], "boss": "t1b", "pck": "dg1"},   # 前作の仮置き 1・3 は序盤〜中盤（t1〜t3）で新しい敵に入れ替え（2026-11-14 ユーザー）。帝国兵 ef/em は前半（t1・t2）。歓楽街の入口（今の部品）
	{"id": "t2", "col": Color(0.35, 0.8, 1.0), "tint": Color(0.55, 0.78, 1.0, 0.6),
		"hp": 1.6, "dmg": 1.4, "xp": 1.5, "foes": ["t2e1", "t2e2", "ef", "em", "bf", "bc", "bm"], "boss": "t2e1", "pck": "dg_t2"},   # 奥の路地（半魔界）。部品 assets/dungeon/t2（2026-11-14）
	{"id": "t3", "col": Color(0.72, 0.42, 1.0), "tint": Color(0.78, 0.5, 1.0, 0.65),
		"hp": 2.4, "dmg": 1.9, "xp": 2.2, "foes": ["t3e1", "bf", "bc", "bm"], "boss": "t3e1", "pck": "dg_t3"},   # 門の手前の廃墟
	{"id": "t4", "col": Color(0.35, 1.0, 0.75), "tint": Color(0.5, 1.0, 0.8, 0.6),
		"hp": 3.4, "dmg": 2.5, "xp": 3.0, "foes": ["mo", "gm"], "boss": "hr", "pck": "dg_t4"},   # 深層：爪の怪物・ガトリングの機兵、ボス＝馬型の機兵（突進）（2026-11-14 ユーザー）。   # 地下の採掘坑
]

## 1 群れの増え方 add、経験値 xp（1 体）、武器の落ちる確率 drop。部屋も敵も約 4 倍になったので、1 体の経験値と落ちる確率は前（12・0.14）より下げた
const DIFFS := {
	"normal": {"hp": 1.0, "dmg": 1.0, "add": 0, "boss_hp": 2200.0, "boss_dmg": 14, "gold": 1.0, "xp": 6, "boss_xp": 150, "drop": 0.04, "w": [2, 6], "bw": [12, 18]},
	"hard":   {"hp": 1.7, "dmg": 1.6, "add": 1, "boss_hp": 4400.0, "boss_dmg": 24, "gold": 1.5, "xp": 10, "boss_xp": 260, "drop": 0.05, "w": [7, 13], "bw": [22, 30]},
	"expert": {"hp": 2.6, "dmg": 2.3, "add": 2, "boss_hp": 6800.0, "boss_dmg": 34, "gold": 2.0, "xp": 16, "boss_xp": 400, "drop": 0.06, "w": [12, 20], "bw": [32, 42]},
}
## 2026-11-15 ユーザー決定：ボスの体力を 2 倍（前 1100／2200／3400。①の後の自動の周回でボス戦が 10〜20 秒だった）
## 2026-11-15 ユーザー決定：T2・T3 のボス（前作の敵将 g1 の仮置き）を、継ぎ腕の住人・壁喰いを大きくした物に（enemy.gd の BOSS_SIZE）
## 2026-11-16 ②：雑魚の経験値を 2 倍（3/5/8→6/10/16。敵の数を半分にした分）、お金の難易度の倍率 gold（1/1.5/2）。テーマの倍率は各テーマの xp（1/1.5/2.2/3）をお金にも使う
const DIFF_ORDER := ["normal", "hard", "expert"]

## ---------- 1 ステージ 4 ダンジョン（2026-11-18 ユーザー決定、specs/dungeon_themes.md 4.） ----------
## ダンジョンの id＝"t1d1"〜"t4d4"（ステージ t1〜t4 ＋ d1〜d4）。順番に開く（D4＝今のボス。D4 のノーマルで次のステージ）。
## 違い＝敵の顔ぶれ・背景の色合い（ユーザー決定）。強さ D1→D4 ×1.0／1.1／1.2／1.3（案のとおり）。
## D1〜D3 のボス＝雑魚を大きくして色を変えた物（boss_col＝体の色、boss_size）。D4＝今のボス（顔ぶれ・色は今のまま）。
## 色：青は味方の色なので、敵の色・背景の色合いに使わない。顔ぶれ・色は Claude の仮（遊んで直す）。
const DN := 4
const D_K := [1.0, 1.1, 1.2, 1.3]
const DUNGEONS := [
	[   # T1 歓楽街の入口
		{"foes": ["t1e1", "t1e2", "bf"], "boss": "t1e1", "boss_col": Color(1.0, 0.45, 0.25), "boss_size": 1.45, "bg": Color(1.0, 0.62, 0.35, 0.42)},
		{"foes": ["bf", "bc", "bm", "t1e2"], "boss": "bm", "boss_col": Color(0.85, 0.4, 1.0), "boss_size": 1.45, "bg": Color(0.85, 0.45, 1.0, 0.42)},
		{"foes": ["ef", "em", "t1e1"], "boss": "em", "boss_col": Color(1.0, 0.25, 0.3), "boss_size": 1.4, "bg": Color(1.0, 0.4, 0.4, 0.42)},
		{},
	],
	[   # T2 奥の路地
		{"foes": ["t2e2", "bf", "bc"], "boss": "t2e2", "boss_col": Color(1.0, 0.5, 0.2), "boss_size": 1.4, "bg": Color(1.0, 0.7, 0.4, 0.42)},
		{"foes": ["ef", "em", "t2e1"], "boss": "ef", "boss_col": Color(0.9, 0.3, 0.9), "boss_size": 1.5, "bg": Color(0.95, 0.45, 0.85, 0.42)},
		{"foes": ["t2e1", "t2e2", "bm"], "boss": "bc", "boss_col": Color(0.55, 1.0, 0.35), "boss_size": 1.5, "bg": Color(0.6, 1.0, 0.5, 0.42)},
		{},
	],
	[   # T3 門の手前の廃墟
		{"foes": ["t3e1", "bf", "bc"], "boss": "bf", "boss_col": Color(1.0, 0.3, 0.3), "boss_size": 1.5, "bg": Color(1.0, 0.45, 0.4, 0.42)},
		{"foes": ["t3e1", "bm", "t2e2"], "boss": "t2e2", "boss_col": Color(0.6, 1.0, 0.4), "boss_size": 1.45, "bg": Color(0.6, 1.0, 0.45, 0.42)},
		{"foes": ["t3e1", "bc", "em"], "boss": "bc", "boss_col": Color(1.0, 0.6, 0.15), "boss_size": 1.5, "bg": Color(1.0, 0.65, 0.3, 0.42)},
		{},
	],
	[   # T4 地下の採掘坑
		{"foes": ["mo", "t3e1"], "boss": "mo", "boss_col": Color(1.0, 0.35, 0.25), "boss_size": 1.35, "bg": Color(1.0, 0.5, 0.35, 0.42)},
		{"foes": ["gm", "t2e2"], "boss": "gm", "boss_col": Color(0.85, 0.35, 1.0), "boss_size": 1.35, "bg": Color(0.85, 0.5, 1.0, 0.42)},
		{"foes": ["mo", "gm", "t3e1"], "boss": "t3e1", "boss_col": Color(0.95, 0.2, 0.25), "boss_size": 1.45, "bg": Color(1.0, 0.35, 0.35, 0.42)},
		{},
	],
]

## "t2d3" → "t2"（前の id "t2" はそのまま）
static func stage_id(id: String) -> String:
	var i: int = id.find("d")
	return id if i < 0 else id.substr(0, i)

## "t2d3" → 3（前の id "t2" は D4＝今のボスのダンジョン）
static func dnum(id: String) -> int:
	var i: int = id.find("d")
	return DN if i < 0 else clampi(int(id.substr(i + 1)), 1, DN)

static func dungeon_id(stage_i: int, n: int) -> String:
	return "%sd%d" % [THEMES[stage_i].id, n]

static func dspec(id: String) -> Dictionary:
	return DUNGEONS[index_of(id)][dnum(id) - 1]

static func index_of(id: String) -> int:
	var sid: String = stage_id(id)
	for i in THEMES.size():
		if THEMES[i].id == sid:
			return i
	return 0

## テーマ×難易度を掛けた設定（dungeon.gd の cfg）
static func cfg(theme: String, diff: String) -> Dictionary:
	var t: Dictionary = THEMES[index_of(theme)]
	var d: Dictionary = DIFFS[diff].duplicate(true)
	var dk: float = D_K[dnum(theme) - 1]   # D1→D4 の強さ
	d.hp = float(d.hp) * float(t.hp) * dk
	d.dmg = float(d.dmg) * float(t.dmg) * dk
	d.boss_hp = float(d.boss_hp) * float(t.hp) * dk
	d.boss_dmg = int(round(float(d.boss_dmg) * float(t.dmg) * dk))
	d.xp = maxi(1, int(round(float(d.xp) * float(t.xp))))
	d.boss_xp = int(round(float(d.boss_xp) * float(t.xp)))
	d.theme_mul = float(t.xp)                       # お金のテーマの倍率（2026-11-16 ②）
	d.gold_mul = float(d.gold) * float(t.xp)        # 雑魚・ボスのお金に掛ける
	var tw: int = index_of(theme) * 6   # 奥のテーマほど武器の数字も上がる
	d.w = [int(d.w[0]) + tw, int(d.w[1]) + tw]
	d.bw = [int(d.bw[0]) + tw, int(d.bw[1]) + tw]
	var ds: Dictionary = dspec(theme)
	d.foes = ds.get("foes", t.foes)
	d.boss = ds.get("boss", t.boss)
	d.boss_col = ds.get("boss_col", Color(1, 1, 1, 0))
	d.boss_size = float(ds.get("boss_size", 0.0))   # 0＝enemy.gd の BOSS_SIZE のまま
	d.dn = dnum(theme)
	return d

## 画面の色合い：D4 はステージの色（今のまま）、D1〜D3 はダンジョンの色
static func tint_of(id: String) -> Color:
	var ds: Dictionary = dspec(id)
	if ds.has("bg"):
		return ds.bg
	return Color(1, 1, 1, 0) if has_parts(id) else THEMES[index_of(id)].tint

static func key(theme: String, diff: String) -> String:
	return "%s_%s" % [theme, diff]

## このテーマの部品の絵があるか（無ければ歓楽街の部品＋画面の色で仮置き）
static func has_parts(theme0: String) -> bool:
	var theme: String = stage_id(theme0)
	return theme != "t1" and ResourceLoader.exists("res://assets/dungeon/%s/%s_b1.webp" % [theme, theme])

## 素材の鍵（③ specs/gear.md）：テーマの順番 1〜4 → "t1"〜"t4"
static func mat_key(theme_id: String) -> String:
	return "t%d" % (index_of(theme_id) + 1)
