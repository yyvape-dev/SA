extends RefCounted
## ラナのスキル（specs/skill_ui.md、2026-11-07）。技を足すときはここに1行（1つの辞書）を足すだけにする。
## clip：使う絵（assets/rana2）、spd：流す速さの倍率、cd：待ち（秒）、total：長さ（秒、絵より長くてもよい）
## ev：[秒, 当たり] の列。当たりは battle._attack_from の spec に、次を足したもの：
##   k＝威力（連撃 A の何倍）、x0・x1＝帯の範囲（ラナの前へ m）、pull＝"front"（前 1.5m へ寄せる）／"in"（ラナへ寄せる）、pull_m＝寄せる量、
##   fx＝見た目の種類（flurry・flurry_end・rift・vortex・vortex_end）、freeze_add＝止めを長く
## 威力の元：連撃 A の 1 発 = BASE_DMG（player.gd の表と同じ）

const BASE_DMG := 18.0
const ORDER := ["flurry", "rift", "vortex"]

static func table() -> Dictionary:
	var t := {}
	# 乱れ斬り：前方へ集中する10回＋最後に強い1回。敵をラナの前へ寄せ続ける（ボスは寄せない）
	var fl := []
	for i in 10:
		fl.append([0.25 + i * 0.095, {"shape": "fwd", "side": 1, "r": 2.3, "lane": 1.1, "k": 0.45, "strong": false, "kb": 0.3,
			"pull": "front", "pull_m": 0.25, "fx": "flurry"}])
	fl.append([1.27, {"shape": "fwd", "side": 1, "r": 2.5, "lane": 1.2, "k": 2.0, "strong": true, "kb": 1.6, "fx": "flurry_end", "freeze_add": 0.08}])
	t["flurry"] = {"clip": "flurry", "spd": 1.0, "cd": 8.0, "total": 1.54, "ev": fl}
	# 地走り：斬り下ろしの当たりから、前方へ地割れの衝撃が3回（0.12 秒おき）
	var hb := 33.0 / 72.0 / 1.5
	var rf := []
	var rng := [[0.0, 3.0], [2.0, 5.5], [4.5, 8.0]]
	for i in 3:
		rf.append([hb + i * 0.12, {"shape": "band", "side": 1, "r": 2.0, "x0": rng[i][0], "x1": rng[i][1], "lane": 0.9, "k": 1.1,
			"strong": i == 2, "lift": 2.5, "fx": "rift", "n": i}])
	t["rift"] = {"clip": "atkB", "spd": 1.5, "cd": 7.0, "total": 0.85, "ev": rf}
	# 金の渦：半径 3.2m の円に 0.15 秒おき 8 回、毎回ラナへ引き寄せる。最後に外へ大きく弾く
	var vx := []
	for i in 8:
		vx.append([0.15 * (i + 1), {"shape": "circle", "side": 1, "r": 3.2, "cx": 0.0, "lane": 9.0, "k": 0.5, "strong": false, "kb": 0.2,
			"pull": "in", "pull_m": 0.6, "fx": "vortex", "n": i}])
	vx.append([1.32, {"shape": "circle", "side": 1, "r": 3.4, "cx": 0.0, "lane": 9.0, "k": 1.8, "strong": true, "kb": 2.6, "fx": "vortex_end", "freeze_add": 0.06}])
	t["vortex"] = {"clip": "hold", "spd": 1.25, "cd": 12.0, "total": 1.45, "ev": vx}
	return t
