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
const FRAME_BEAM_Y := 3.2   # 15章（ユーザー決定）：頭上の物を映る高さへ下げる。扉 2.6m・屋台の天幕より上
const ALLEY_DEPTH := 5.5
const TEX_M := 2.5            # 横の壁の素材 1 枚の実寸（m）
const ART := "res://art/painted_bt/"

## 下絵の色（新しい 4 棟・足場など、絵がまだ無い物）。夜の中間の明るさに合わせて暗め（U1）。光る物は明るく
const MAT := {
	"stone": Color("4a4652"), "brick": Color("553832"), "wood": Color("4a3424"), "iron": Color("363a42"),
	"brass": Color("8a6a2c"), "copper": Color("7a4a26"), "glass": Color("223448"), "cloth": Color("6a2244"),
	"velvet": Color("701830"), "cloth2": Color("3a2464"), "awning": Color("4a2a62"), "dark": Color("141219"),
	"shadow": Color("0c0a10"), "side": Color("1c1922"), "scaffold": Color("4a4234"), "cable": Color("141414"),
	"crate": Color("4a3a28"), "bottle": Color("3a6a50"), "curtain": Color("a04a6a"), "linen": Color("7a6e5c"),
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
## [絵, 中心 x, 下端 y, 幅 m, 置き方]：置き方 "wall"＝壁に貼る（z は壁の前 0.06〜0.3m）、"beam"＝足場の梁から吊るす（上端＝梁、下端 y は無視）
##   15章：梁を 3.2m に下げ、布の天幕を張ったので、壁の高い所（3m より上）の看板は天幕に隠れる → 梁から吊るして天幕の手前に出す
const SIGNS := [
	["sign_sigil", -25.4, 0.0, 1.2, "beam"],     # 入ってすぐ（食べ物の屋台の天幕を避けて左へ）
	["sign_vneon", -21.9, 0.7, 0.5, "wall"],     # 柱の縦のネオン（上端を天幕の下へ）
	["vision_screen", -18.8, 2.6, 4.4, "wall"],  # w3 のビジョン（前は天幕を張らない）
	["sign_vneon", -16.4, 0.7, 0.5, "wall"],
	["sign_rune", -15.0, 3.42, 1.0, "wall"],     # 結晶の屋台の天幕の上（壁の高い所。ここは天幕を張らない）
	["sign_vneon", -11.1, 0.7, 0.5, "wall"],
	["sign_sigil", -8.6, 0.0, 2.2, "beam"],      # 飲み屋の上（魔導の酒場）
	["sign_vneon", -4.35, 0.7, 0.5, "wall"],
	["sign_rune", -2.7, 0.0, 1.0, "beam"],
	["sign_vneon", 4.95, 0.7, 0.5, "wall"],
	["sign_vneon", 7.35, 0.7, 0.5, "wall"],
	["sign_rune", 12.9, 0.0, 1.0, "beam"],       # 娼館の階段の上
	["sign_vneon", 14.5, 0.7, 0.5, "wall"],      # 娼館の右の柱
	["sign_rune", 15.0, 0.0, 1.0, "beam"],
	["sign_sigil", 23.0, 0.0, 1.6, "beam"],      # 怪しい店の上（義手の屋台の天幕を避けて右へ）
]
## 色の付いた下絵の光る物で、看板として数えるもの：[名前, x]（キャバレーの電球の入口とピンクのネオン、怪しい店の小さな看板、門の光）
const GLOW_BLOCKOUT := [["cabaret_neon", 1.6], ["cabaret_bulbs", 1.6], ["shady_small", 20.1], ["gate_glow", 17.1]]

## 足場の枠（13 章の 1、新規の層）：柱の x（梁は全幅）。梁から垂らす物：[種類, x, 絵/素材]
const FRAME_POSTS := [-23.0, -17.4, -11.7, -6.3, -0.5, 5.5, 11.2, 15.4, 19.5, 25.0]
## 15章：看板を梁から吊るしたので、重ならないよう位置を動かした。扉・光る看板・屋台の天幕・路地の口の前は避ける
const HANGS := [
	["pend", -20.3, "pend_cyan"], ["banner", -17.9, "banner_red"], ["pend", -16.9, "pend_warm"], ["pend", -10.6, "pend_warm"],
	["banner", -6.9, "banner_violet"], ["pend", -1.4, "pend_violet"], ["pend", 6.2, "pend_warm"], ["banner", 6.9, "banner_red"],
	["pend", 10.6, "pend_violet"], ["pend", 13.9, "pend_cyan"], ["banner", 14.2, "banner_violet"], ["pend", 23.9, "pend_green"], ["pend", 25.2, "pend_violet"],
]
## 15章（ユーザー決定）：布の天幕を店先の帯の上に張り渡す（たるんだ布、下端 3.0〜3.6m、継ぎはぎの紫・紅・生成り）。下絵は色の帯。
##   張らない所：w3 のビジョン・キャバレーのネオン（光る看板をふさがない）、路地の口2つ。屋台の上は下端を 3.5m 以上に（屋台の天幕 3.45m）
const CANOPY_Z := -4.7
const CANOPY_TOP := 4.4
const CANOPY_SPANS := [[-26.5, -22.0], [-11.8, -1.0], [4.4, 15.8], [18.4, 26.5]]
const CANOPY_HIGH := [[-24.9, -22.3], [19.3, 21.9]]   # 屋台の上（下端 3.55m 以上）
const PEND_W := 0.42          # ペンダントライトの幅（m。絵の縦横比で高さ ≒ 0.88m、上端は梁）
const BANNER_W := 0.8         # 垂れ幕の幅（高さ ≒ 1.25m）

## 手前の物（帯の手前 z 3.5、届いた絵）：[絵, x, 高さ m]
## 15章（ユーザー決定）：手前の柱は 1 画面の幅（手前 z 3.5 で 7.6m）に 1 本まで → 3 本から 2 本に（間 21m）。ラナから左右 2.5m 以内で透ける
const FG := [["fg_crate", -17.6, 1.0], ["fg_pillar", -9.0, 4.4], ["fg_pillar_lamp", 12.0, 4.4], ["fg_crates", 15.6, 1.4]]
const FG_Z := 3.5
