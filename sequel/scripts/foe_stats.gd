extends RefCounted
## 敵の種類ごとの数値（2026-11-15 ユーザー「検討表の案でいく」。表 https://claude.ai/artifact/7SXNn7Xi1yTFrCEpVipjbC の「敵」「のけぞり」）。
## hp・atk＝体力・攻撃の倍率（全種共通の式 60+10×段階・7+段階 に掛ける）。
## armor：none＝なし／charge＝溜めの間だけ／attack＝予兆から当たりまで／always＝いつも（強い当たりでだけのけぞる）。
## down＝ダウン値（通常の当たり 1・強い当たり 3 をためて、この値に達したらのけぞる。1 秒当たらなければ 0 に戻る）。0＝ボス（ブレイク）。
## armor_atk＝アーマーが付く攻撃（無ければ全部）。2026-11-15 ユーザー決定「大技だけアーマー」：継ぎ腕＝3つ目の打撃 atk2・壁喰い＝跳んで叩き atk2・
##   爪の怪物＝光線 atk1・ガトリング＝連射 atk0（前の「いつも」を外した）。ほかの攻撃は殴ればダウン値どおり止まる。
## kb＝押し戻しの倍率（重い敵は半分）。gap＝攻撃の後の大きな隙（秒。ここではどの当たりでものけぞる）。
## 経験値・お金の倍率は ②③ でまとめて決める（ユーザー）ので、ここには入れない。

const T := {
	"t1e1": {"role": "標準", "hp": 1.0, "atk": 1.0, "armor": "none", "down": 1.0},
	"t1e2": {"role": "遠距離", "hp": 0.7, "atk": 0.9, "armor": "none", "down": 1.0},
	"ef": {"role": "標準", "hp": 1.0, "atk": 1.0, "armor": "charge", "down": 2.0},
	"em": {"role": "標準", "hp": 1.1, "atk": 1.1, "armor": "charge", "down": 2.0},
	"bf": {"role": "軽い", "hp": 0.8, "atk": 0.9, "armor": "none", "down": 1.0},
	"bc": {"role": "標準", "hp": 1.0, "atk": 1.0, "armor": "charge", "down": 2.0},
	"bm": {"role": "標準", "hp": 1.0, "atk": 1.1, "armor": "none", "down": 1.0},
	"t2e1": {"role": "重い", "hp": 1.6, "atk": 1.3, "armor": "attack", "armor_atk": ["atk2"], "down": 3.0, "kb": 0.5, "gap": 0.6},
	"t2e2": {"role": "遠距離", "hp": 0.8, "atk": 1.2, "armor": "none", "down": 1.0},
	"t3e1": {"role": "重い", "hp": 2.0, "atk": 1.4, "armor": "attack", "armor_atk": ["atk2"], "down": 4.0, "kb": 0.5, "gap": 0.6},
	"mo": {"role": "重い", "hp": 1.8, "atk": 1.3, "armor": "attack", "armor_atk": ["atk1"], "down": 4.0, "kb": 0.5, "gap": 0.6},
	"gm": {"role": "遠距離（硬い）", "hp": 1.4, "atk": 1.0, "armor": "attack", "armor_atk": ["atk0"], "down": 3.0, "kb": 0.5},
	"t1b": {"role": "ボス", "hp": 1.0, "atk": 1.0, "armor": "always", "down": 0.0},
	"g1": {"role": "ボス", "hp": 1.0, "atk": 1.0, "armor": "always", "down": 0.0},
	"hr": {"role": "ボス", "hp": 1.3, "atk": 1.2, "armor": "always", "down": 0.0},
}
const DEF := {"role": "標準", "hp": 1.0, "atk": 1.0, "armor": "none", "down": 1.0}

const DOWN_NORMAL := 1.0     # 通常の当たりが積むダウン値
const DOWN_STRONG := 3.0     # 強い当たり
const DOWN_ALLY_K := 0.5     # 仲間の技は半分だけ積む（仲間が止め続けないように）
const DOWN_RESET := 1.0      # この秒数当たらなければ、たまったダウン値は 0 に戻る
const HS_ARMOR := 0.02       # アーマーで受けた（のけぞらなかった）ときの止め（秒）
const JG_UNARMOR := 3.0      # ジャストガードでアーマーを外す秒数（この間はどの当たりでものけぞる。2026-11-15 ユーザー決定）
const JG_STUN := 1.2         # ジャストガードのひるみ（秒。前は 0.8）
const BREAK_K := 0.28        # ボスのブレイク：最大体力のこの割合の傷で帯が満ちる（仮。60〜90 秒で 2〜3 回を狙う）
const BREAK_T := 3.0         # ブレイクで倒れている秒数
const BREAK_DMG := 1.5       # ブレイク中に受ける傷の倍率

static func get_k(kind: String) -> Dictionary:
	var d: Dictionary = DEF.duplicate()
	d.merge(T.get(kind, {}), true)
	return d

static func heavy(kind: String) -> bool:
	return str(get_k(kind).role) == "重い"
