extends RefCounted
## 融合都市・1区画目（下町の大通り）のグレーボックス。
## piece = 外部AIに塗ってもらう単位（1件＝1枚の絵）。boxes = [中心, 大きさ, 色の意味]。
## 座標：x＝左右（右が+）、y＝上、z＝手前が+。歩ける帯は z −3.2〜3.5。
## 色の意味は下絵で「何の素材か」をAIに伝えるためのもの（ゲームの見た目ではない）。

const MAT := {
	"stone": Color("8d8a86"), "brick": Color("9a6a55"), "wood": Color("7a5a3e"),
	"copper": Color("b87333"), "brass": Color("c9a24a"), "iron": Color("5d6168"),
	"glass": Color("2f4a66"), "neon_p": Color("ff3fa4"), "neon_c": Color("29e0ff"),
	"roof": Color("4a4f57"), "pipe": Color("8a6a4a"), "dark": Color("2a2c33"),
	"light": Color("ffd27a"),
}

static func pieces() -> Array:
	return [
		# 左端：蒸気の酒場（銅のボイラーとネオンの看板）
		{"id": "b1_tavern", "kind": "bld", "boxes": [
			[Vector3(-14, 3.0, -8.5), Vector3(8, 6, 4), "brick"],
			[Vector3(-14, 6.4, -8.8), Vector3(8.6, 0.8, 4.6), "roof"],
			[Vector3(-14, 1.3, -6.45), Vector3(2.0, 2.6, 0.1), "wood"],      # 扉
			[Vector3(-16.6, 1.8, -6.45), Vector3(2.2, 1.6, 0.1), "glass"],   # 窓
			[Vector3(-11.4, 1.8, -6.45), Vector3(2.2, 1.6, 0.1), "glass"],
			[Vector3(-14, 4.4, -6.3), Vector3(4.2, 1.0, 0.3), "neon_p"],    # 看板
			[Vector3(-18.6, 3.2, -7.6), Vector3(1.4, 6.4, 1.4), "copper"],  # ボイラー
			[Vector3(-18.6, 7.4, -7.6), Vector3(0.5, 2.0, 0.5), "iron"],    # 煙突
		]},
		# 中央：時計塔の機関工房（歯車の大窓とシャッター）
		{"id": "b2_workshop", "kind": "bld", "boxes": [
			[Vector3(-3, 3.5, -9), Vector3(9, 7, 5), "stone"],
			[Vector3(-3, 7.3, -9.2), Vector3(9.6, 0.6, 5.4), "roof"],
			[Vector3(-3, 1.6, -6.45), Vector3(4.4, 3.2, 0.1), "iron"],      # シャッター
			[Vector3(-3, 5.0, -6.45), Vector3(2.6, 2.6, 0.1), "brass"],     # 歯車の丸窓
			[Vector3(0.6, 10.0, -9.5), Vector3(2.6, 6.4, 2.6), "stone"],    # 時計塔
			[Vector3(0.6, 11.0, -8.15), Vector3(1.8, 1.8, 0.1), "brass"],   # 文字盤
			[Vector3(0.6, 13.6, -9.5), Vector3(3.0, 0.8, 3.0), "roof"],
			[Vector3(-7.2, 3.0, -6.6), Vector3(0.6, 6.0, 0.6), "pipe"],     # 縦の配管
		]},
		# 右：ネオンの装備屋（ガラスの陳列窓と縦の看板）
		{"id": "b3_shop", "kind": "bld", "boxes": [
			[Vector3(8, 4.0, -8.5), Vector3(7, 8, 4), "brick"],
			[Vector3(8, 8.3, -8.7), Vector3(7.6, 0.6, 4.4), "roof"],
			[Vector3(8, 1.6, -6.45), Vector3(5.0, 2.8, 0.1), "glass"],      # 陳列窓
			[Vector3(10.9, 5.0, -6.0), Vector3(0.5, 4.0, 1.4), "neon_c"],  # 縦の看板
			[Vector3(8, 3.3, -6.0), Vector3(6.0, 0.25, 1.2), "copper"],    # 庇
			[Vector3(6.2, 6.2, -6.45), Vector3(1.6, 1.4, 0.1), "glass"],
			[Vector3(9.8, 6.2, -6.45), Vector3(1.6, 1.4, 0.1), "glass"],
		]},
		# 右端：鉄骨の高架と蒸気管
		{"id": "b4_bridge", "kind": "bld", "boxes": [
			[Vector3(17.5, 5.5, -7.5), Vector3(9, 1.0, 3.0), "iron"],       # 橋桁
			[Vector3(14.0, 2.5, -7.5), Vector3(0.8, 5.0, 0.8), "iron"],     # 柱
			[Vector3(21.0, 2.5, -7.5), Vector3(0.8, 5.0, 0.8), "iron"],
			[Vector3(17.5, 6.6, -7.5), Vector3(9, 1.2, 1.8), "dark"],       # 列車の影
			[Vector3(17.5, 1.0, -9.5), Vector3(9, 2.0, 1.0), "pipe"],       # 太い蒸気管
		]},
		# 手前（帯より手前。主人公を隠す）
		{"id": "f1_lamp", "kind": "fg", "boxes": [
			[Vector3(-8.5, 2.6, 5.6), Vector3(0.35, 5.2, 0.35), "iron"],
			[Vector3(-8.5, 5.3, 5.6), Vector3(0.9, 0.7, 0.9), "light"],
		]},
		{"id": "f2_pipe", "kind": "fg", "boxes": [
			[Vector3(4.5, 1.2, 5.8), Vector3(0.9, 2.4, 0.9), "copper"],     # 消火栓のような蒸気弁
			[Vector3(4.5, 2.6, 5.8), Vector3(0.5, 0.5, 0.5), "brass"],
		]},
		{"id": "f3_lamp", "kind": "fg", "boxes": [
			[Vector3(14.5, 2.6, 5.6), Vector3(0.35, 5.2, 0.35), "iron"],
			[Vector3(14.5, 5.3, 5.6), Vector3(0.9, 0.7, 0.9), "neon_c"],
		]},
		# 遠景：高層の塔と飛行船（ゆっくり動く）
		{"id": "z_skyline", "kind": "far", "boxes": [
			[Vector3(-40, 20, -60), Vector3(10, 40, 6), "dark"],
			[Vector3(-22, 28, -62), Vector3(8, 56, 6), "glass"],
			[Vector3(-6, 16, -58), Vector3(12, 32, 6), "dark"],
			[Vector3(10, 34, -64), Vector3(7, 68, 6), "glass"],
			[Vector3(26, 22, -60), Vector3(11, 44, 6), "dark"],
			[Vector3(42, 18, -58), Vector3(9, 36, 6), "glass"],
			[Vector3(-12, 42, -66), Vector3(18, 5, 5), "copper"],           # 飛行船
		]},
	]
