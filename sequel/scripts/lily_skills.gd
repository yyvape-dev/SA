extends RefCounted
## リリィのスキル（2026-11-07、ユーザー決定）。待ちが明けたら、その場を見て自動で出す（ally.gd の _pick_skill）。
## 技を足すときはここに1つの辞書を足すだけにする。
##   frames：使う絵の番号の列（clip の中の 12コマ/秒 の番号。並べ替え・繰り返しで別の動きにする。別の clip のコマは [clip, 番号]）、fps：流す速さ
##   cd：待ち（秒）、ev：[frames の何番目, 当たり]。当たりは battle._attack_from の spec に次を足したもの：
##     k＝威力（リリィの1発 ally.DMG の何倍）、fx＝見た目（jab・kick・kick_end・rush・storm_drop・storm・storm_end・ult_hit・ult_end）
##   dash：[frames の何番目から, 何番目まで] の間に狙った敵の横まで一気に寄る
## 使う条件（ally.gd）：rush＝いちばん近い敵が 3.5〜11m 先、barrage＝近い敵が届く所、storm＝半径 4.5m に敵 3 体以上（ボスがいれば 2 体）
## 必殺技 ult：battle.ally_ult が満タン → ボス（いなければ体力のいちばん多い敵）だけを狙う

const ORDER := ["rush", "barrage", "storm"]

## 連打の1発：ジャブ（A）と上段蹴り（B）のコマを往復させる。hit＝当たるコマの位置
const JAB := {"f": [6, 7, 8, 9, 8], "hit": 2}
const KICK := {"f": [17, 18, 19, 18], "hit": 2}

static func _barrage(n: int, k: float) -> Dictionary:
	var fr := []
	var ev := []
	for i in n:
		var p: Dictionary = KICK if i % 3 == 2 else JAB
		ev.append([fr.size() + int(p.hit), {"shape": "fwd", "side": 1, "r": 2.4, "lane": 1.0, "k": k, "strong": false, "kb": 0.15,
			"pull": "front", "pull_m": 0.4, "fx": "kick" if p == KICK else "jab", "n": i, "shake": 2.0}])
		fr.append_array(p.f)
	return {"frames": fr, "ev": ev}

static func table() -> Dictionary:
	var t := {}
	# 迅雷（じんらい）：遠くの敵へ一気に詰めて飛び蹴り。通り道の帯ごと当てる
	var rf := [14, 16, 17, 18, 19, 20, 22, 23, 24, 25, 26, 28, 30, 32, 33, 34, 35, 47, 48, 49, 50, 51, 52]
	t["rush"] = {"clip": "atk_rush", "frames": rf, "fps": 30.0, "cd": 9.0, "dash": [1, 7],
		"ev": [[7, {"shape": "band", "side": 1, "r": 2.0, "lane": 1.0, "k": 2.0, "strong": true, "kb": 1.8, "fx": "rush", "shake": 11.0, "wave": true}]]}
	# 雷連打（らいれんだ）：ジャブと上段蹴りを 13 回（敵をリリィの前へ寄せ続ける）＋最後に蹴り上げ。計 14 回
	var b := _barrage(13, 0.5)
	var ev: Array = b.ev
	var fr: Array = b.frames
	ev.append([fr.size() + 2, {"shape": "fwd", "side": 1, "r": 2.4, "lane": 1.1, "k": 2.2, "strong": true, "kb": 1.4, "lift": 4.0, "fx": "kick_end", "freeze_add": 0.06, "shake": 10.0, "wave": true}])
	fr.append_array([17, 18, 19, 20, 21, 22, 28, 30, 32, 34, 36])
	t["barrage"] = {"clip": "atk_jabkick", "frames": fr, "fps": 44.0, "cd": 10.0, "ev": ev}
	# 雷陣（らいじん）：かかと落としで床を割り、自分を中心に半径 4.8m へ空から稲妻を 5 回落とす → 最後に外へ弾く
	var sf := [7, 9, 11, 12, 13, 13, 13, 26, 27, 28, 29, 30, 33, 35, 37, 37, 37, 37, 37, 37, 37, 37, 37, 37, 40, 44, 47, 49, 51, 53]
	var sev := [[9, {"shape": "circle", "side": 1, "r": 2.6, "cx": 0.0, "lane": 9.0, "k": 1.4, "strong": true, "kb": 0.4, "fx": "storm_drop", "shake": 10.0}]]
	for i in 5:
		sev.append([13 + i * 2, {"shape": "circle", "side": 1, "r": 4.8, "cx": 0.0, "lane": 9.0, "k": 0.7, "strong": false, "kb": 0.15, "fx": "storm", "n": i, "shake": 6.0}])
	sev.append([23, {"shape": "circle", "side": 1, "r": 5.0, "cx": 0.0, "lane": 9.0, "k": 1.6, "strong": true, "kb": 2.4, "fx": "storm_end", "freeze_add": 0.05, "shake": 14.0}])
	t["storm"] = {"clip": "atk_heeldrop", "frames": sf, "fps": 20.0, "cd": 14.0, "ev": sev}
	# 必殺技 天雷（てんらい）：狙った1体の横へ瞬間移動 → 6 回の連打（毎回その敵に空から稲妻）→ かかと落としで巨大な雷の柱。当たるのはその1体だけ
	var u := _barrage(6, 1.2)
	var uev: Array = u.ev
	var ufr: Array = u.frames
	for e in uev:
		e[1].fx = "ult_hit"
		e[1].erase("pull")
	uev.append([ufr.size() + 4, {"shape": "fwd", "side": 1, "r": 3.0, "lane": 2.0, "k": 18.0, "strong": true, "kb": 2.6, "fx": "ult_end", "freeze_add": 0.22, "shake": 24.0}])
	for f in [12, 13, 13, 26, 28, 29, 30, 33, 35, 37, 37, 37, 40, 44, 47, 51, 53]:
		ufr.append(["atk_heeldrop", f])   # 別の clip のコマは [clip, 番号]
	t["ult"] = {"clip": "atk_jabkick", "frames": ufr, "fps": 30.0, "ev": uev}
	return t
