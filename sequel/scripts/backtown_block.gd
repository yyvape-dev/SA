extends RefCounted
## 裏の町の入り口 v2（specs/backtown_entrance_v2.md の 12・13 章）の下絵。2026-11-08。
## 仕組みは specs/backtown_blockout.md のまま：建物は正面の板だけに絵を貼る（出っ張りは平らに＝絵の中に）、下の帯 0〜5m、
## 扉・屋台・路地・人の立ち位置はデータ。届いた絵（art/painted_bt、tools/cut_bt.py で切り抜き）は絵を貼り、無い所は色の付いた下絵。
## 座標：x＝左右、y＝上、z＝手前が＋。カメラ D2（距離 15.3m・高さ 3.2m・16.8°）：建物の正面（z −6.5）で映るのは地面〜約 4.0m、
## 横幅の半分は 7.0m。歩ける左右 ±24（約 3 画面、U8）、カメラが動ける左右 ±19.1、正面の壁は ±26.5（計算 ±26.1）。
## 並び（12 章）：左＝明るく賑やか → 右＝暗く怪しい（門に近いほど混沌）。

const ROOM_X := Vector2(-24.0, 24.0)
const BELT_Z := Vector2(-2.0, 2.0)
const WALL_Z := -6.5
const WALL_H := 14.0
const LOW_H := 5.0            # 壁の下の帯（backtown_blockout.md の判定の反映）
const FLAT := true
const CROWD_Z := Vector2(-5.9, -4.3)   # 人混みと屋台の帯（店先）
const STALL_Z := -5.5         # 屋台（奥の層 −5.7・店の人 −5.5・カウンターの層 −5.3）
const FRAME_Z := -4.1         # 足場の枠（新規の層）：柱と、地面から 3.6〜3.8m の横の梁
const FRAME_BEAM_Y := 3.7
const ALLEY_DEPTH := 5.5
const TEX_M := 2.5            # 横の壁の素材 1 枚の実寸（m）
const ART := "res://art/painted_bt/"

## 下絵の色（新しい 4 棟・足場など、絵がまだ無い物）。夜の中間の明るさに合わせて暗め（U1）。光る物は明るく
const MAT := {
	"stone": Color("4a4652"), "brick": Color("553832"), "wood": Color("4a3424"), "iron": Color("363a42"),
	"brass": Color("8a6a2c"), "copper": Color("7a4a26"), "glass": Color("223448"), "cloth": Color("6a2244"),
	"velvet": Color("701830"), "cloth2": Color("3a2464"), "awning": Color("4a2a62"), "dark": Color("141219"),
	"shadow": Color("0c0a10"), "side": Color("1c1922"), "scaffold": Color("4a4234"), "cable": Color("141414"),
	"crate": Color("4a3a28"), "bottle": Color("3a6a50"), "curtain": Color("a04a6a"),
	"neon_p": Color("ff40b0"), "neon_g": Color("40ff90"), "neon_c": Color("30e0ff"), "neon_v": Color("b040ff"),
	"lamp": Color("ffc060"), "bulb": Color("fff0a0"), "window": Color("c88a44"),
}

## 区画の並び（x の小さい順）。kind：wall＝建物（parts＝下絵の地帯 [x0,y0,x1,y1,素材]、art＝届いた絵）、
##   filler＝つなぎの壁（横の壁の素材を実寸で繰り返す）、pillar＝鉄骨の柱、alley＝路地の口
static func segments() -> Array:
	return [
		{"kind": "filler", "x0": -26.5, "x1": -22.2, "tex": "tex_brick"},
		{"kind": "pillar", "x0": -22.2, "x1": -21.6},
		{"kind": "wall", "id": "w3_vision", "x0": -21.6, "x1": -16.2, "note": "ビジョンの建物（届いた絵）", "art": "w3_vision_off",
			"art_box": [-22.65, 0.0, -15.15, 5.0], "upper_tex": "tex_iron"},
		{"kind": "filler", "x0": -16.2, "x1": -14.4, "tex": "tex_iron"},
		{"kind": "alley", "x0": -14.4, "x1": -12.0, "id": "alley_towers"},
		{"kind": "pillar", "x0": -12.0, "x1": -11.4},
		{"kind": "wall", "id": "n1_tavern", "x0": -11.4, "x1": -4.0, "base": "wood", "note": "飲み屋・酒場（主役）", "parts": [
			[-10.9, 0.0, -6.6, 2.9, "dark"],          # 開いた店先（中は暗い）
			[-10.7, 1.5, -6.8, 2.6, "bottle"],        # 酒瓶の棚
			[-10.9, 0.0, -6.6, 1.1, "wood"],          # カウンター
			[-11.1, 2.95, -6.4, 3.35, "awning"],      # 店先の天幕
			[-6.0, 0.0, -4.6, 2.5, "wood"],           # 扉
			[-10.2, 3.5, -7.4, 3.95, "brass"],        # 木と真鍮の看板（下段が映る）
			[-11.2, 5.4, -8.0, 6.8, "window"], [-7.6, 5.4, -4.2, 6.8, "dark"],
		]},
		{"kind": "pillar", "x0": -4.0, "x1": -3.4},
		{"kind": "filler", "x0": -3.4, "x1": -2.0, "tex": "tex_boards"},
		{"kind": "wall", "id": "n2_cabaret", "x0": -2.0, "x1": 5.2, "base": "stone", "note": "劇場・キャバレーの入口", "parts": [
			[0.2, 0.0, 3.0, 3.0, "bulb"],             # 電球で縁取った入口（縁）
			[0.4, 0.0, 2.8, 2.8, "velvet"],           # ビロードの幕
			[1.3, 0.0, 1.9, 2.4, "dark"],             # 幕の合わせ目
			[-1.6, 0.6, -0.2, 2.6, "glass"],          # 演目の貼り紙の枠
			[3.4, 0.6, 4.8, 2.6, "glass"],
			[-0.6, 3.15, 3.8, 3.95, "neon_p"],        # ピンクのネオン（光る部品）
			[-1.8, 4.4, 5.0, 6.0, "dark"],
		]},
		{"kind": "pillar", "x0": 5.2, "x1": 5.8},
		{"kind": "filler", "x0": 5.8, "x1": 7.0, "tex": "tex_plaster"},
		{"kind": "wall", "id": "n3_brothel", "x0": 7.0, "x1": 14.2, "base": "brick", "note": "娼館風の宿", "parts": [
			[8.3, 0.0, 9.7, 2.5, "dark"],             # 戸口（暖かい暗がり）
			[8.4, 0.0, 9.6, 2.3, "window"],
			[7.4, 0.8, 8.0, 2.0, "curtain"], [10.0, 0.8, 10.6, 2.0, "curtain"],
			[7.4, 2.9, 9.2, 3.95, "curtain"],         # 2 階の窓（カーテン越しの人影の場所。下が映る）
			[10.0, 2.9, 11.8, 3.95, "curtain"],
			[11.9, 0.0, 14.0, 2.7, "wood"],           # 外階段（人が立つ・もたれる）
			[7.2, 2.7, 14.0, 2.85, "iron"],           # 2 階の床の縁
		]},
		{"kind": "pillar", "x0": 14.2, "x1": 14.8},
		{"kind": "filler", "x0": 14.8, "x1": 16.0, "tex": "tex_iron"},
		{"kind": "alley", "x0": 16.0, "x1": 18.2, "id": "alley_gate"},
		{"kind": "pillar", "x0": 18.2, "x1": 18.8},
		{"kind": "wall", "id": "n4_shady", "x0": 18.8, "x1": 25.0, "base": "iron", "note": "怪しい店（薬・売人）", "parts": [
			[19.3, 0.0, 22.0, 2.4, "dark"],           # 暗い店先
			[22.3, 0.0, 23.5, 2.3, "wood"],           # 扉
			[23.8, 1.2, 24.6, 1.9, "iron"],           # 格子の小窓
			[19.6, 2.6, 20.6, 3.0, "neon_g"],         # 小さな緑の看板（暗い）
			[19.0, 3.4, 24.8, 3.6, "copper"],         # 配管
		]},
		{"kind": "filler", "x0": 25.0, "x1": 26.5, "tex": "tex_brick"},
	]

## 路地の奥の書き割り（届いた絵）
const ALLEY_BACKS := {"alley_towers": "back_alley_2", "alley_gate": "back_alley_1"}
## データ（13 章の 1）
const DOORS := [{"id": "door_tavern", "x": -5.3, "w": 1.4, "h": 2.5}, {"id": "door_cabaret", "x": 1.6, "w": 2.4, "h": 2.8},
	{"id": "door_brothel", "x": 9.0, "w": 1.4, "h": 2.5}, {"id": "door_shady", "x": 22.9, "w": 1.2, "h": 2.3}]
const ALLEYS := [{"id": "alley_towers", "x": -13.2, "w": 2.4}, {"id": "alley_gate", "x": 17.1, "w": 2.2, "note": "門へ向かう道"}]
## 屋台：art＝届いた絵（2 層に分けて人を挟む）、art が無ければ色の付いた下絵。w・h は m
const STALLS := [
	{"id": "stall_food", "x": -23.6, "w": 2.48, "h": 3.45, "art": "stall_food", "keeper": true},
	{"id": "stall_crystal", "x": -15.6, "w": 2.48, "h": 3.45, "art": "stall_crystal", "keeper": true},
	{"id": "stall_game", "x": 4.3, "w": 2.4, "h": 3.0, "art": "", "keeper": false, "note": "遊技の屋台（歯車仕掛けの機械）。絵は未発注"},
	{"id": "stall_parts", "x": 20.6, "w": 2.48, "h": 3.45, "art": "stall_parts", "keeper": true},
]
const STALL_SPLIT := 0.65     # 屋台の絵の上から 65％ ＝ 奥の層（天幕・棚）、下 35％ ＝ カウンターの層（発注の下絵の 1024 行目）
## 人の立ち位置（7 章。絵はまだ無いので、前作の町の人を暗くして仮に立たせる）：[x, z, 役]
const PEOPLE := [[-8.5, -5.6, "飲み屋の店の人（カウンター）"], [-3.9, -5.0, "酔客（樽の立ち飲み）"], [-2.6, -5.1, "酔客"],
	[2.9, -5.3, "キャバレーの客引き"], [8.0, -5.6, "客引きの女（戸口）"], [12.6, -5.8, "客引きの女（階段）"],
	[17.1, -5.9, "用心棒（門の路地の口）"], [23.6, -5.6, "売人"]]
## 外に置く樽（飲み屋の立ち飲み）：[x, z]
const BARRELS := [[-3.6, -4.9], [-2.4, -5.3]]

## 光る看板（届いた絵の光る部品を使い回す）：[絵, 中心 x, 下端 y, 幅 m, z の前へのずれ]。どの画面幅でも 4〜6 枚（U1）
const SIGNS := [
	["sign_sigil", -24.2, 2.9, 2.0, 0.06],       # 入ってすぐ（つなぎの壁）
	["sign_vneon", -21.9, 0.9, 0.5, 0.3],        # 柱の縦のネオン
	["vision_screen", -18.8, 2.6, 4.4, 0.06],   # w3 のビジョン（画面の位置）
	["sign_vneon", -16.4, 0.9, 0.5, 0.3],        # w3 の右端の縦のネオン
	["sign_rune", -15.3, 2.7, 1.4, 0.06],
	["sign_vneon", -11.1, 0.9, 0.5, 0.3],        # 飲み屋の左の縦のネオン
	["sign_sigil", -8.6, 3.2, 2.6, 0.06],        # 飲み屋の上（魔導の酒場）
	["sign_vneon", -4.35, 0.9, 0.5, 0.25],       # 飲み屋の端の縦のネオン
	["sign_rune", -2.7, 2.8, 1.1, 0.06],         # 飲み屋とキャバレーの間（つなぎの壁）
	["sign_vneon", 4.95, 0.9, 0.5, 0.25],        # キャバレーの端
	["sign_vneon", 7.35, 0.9, 0.5, 0.25],        # 娼館の端
	["sign_rune", 12.9, 2.95, 1.0, 0.06],        # 娼館の階段の上
	["sign_rune", 15.4, 2.7, 1.1, 0.06],
	["sign_sigil", 21.9, 3.0, 2.0, 0.06],        # 怪しい店の上（暗めに）
]
## 色の付いた下絵の光る物で、看板として数えるもの：[名前, x]（キャバレーの電球の入口とピンクのネオン、怪しい店の小さな看板、門の光）
const GLOW_BLOCKOUT := [["cabaret_neon", 1.6], ["cabaret_bulbs", 1.6], ["shady_small", 20.1], ["gate_glow", 17.1]]

## 足場の枠（13 章の 1、新規の層）：柱の x（梁は全幅）。梁から垂らす物：[種類, x, 絵/素材]
const FRAME_POSTS := [-23.0, -17.4, -11.7, -6.3, -0.5, 5.5, 11.2, 15.4, 19.5, 25.0]
const HANGS := [
	["pend", -20.3, "pend_cyan"], ["banner", -17.9, "banner_red"], ["pend", -14.6, "pend_warm"], ["pend", -9.4, "pend_warm"],
	["banner", -7.6, "banner_violet"], ["pend", -2.6, "pend_violet"], ["pend", 3.6, "pend_warm"], ["banner", 6.6, "banner_red"],
	["pend", 10.6, "pend_violet"], ["pend", 13.0, "pend_cyan"], ["banner", 15.8, "banner_violet"], ["pend", 21.4, "pend_green"], ["pend", 24.0, "pend_violet"],
]
const PEND_W := 0.42          # ペンダントライトの幅（m。絵の縦横比で高さ ≒ 0.88m、上端は梁）
const BANNER_W := 0.8         # 垂れ幕の幅（高さ ≒ 1.25m）

## 手前の物（帯の手前 z 3.5、届いた絵）：[絵, x, 高さ m]
const FG := [["fg_crate", -17.6, 1.0], ["fg_pillar", -9.0, 4.4], ["fg_pillar_lamp", 8.0, 4.4], ["fg_crates", 15.6, 1.4], ["fg_pillar", 21.5, 4.4]]
const FG_Z := 3.5
