extends RefCounted
## ラナのスキル（specs/skill_ui.md、2026-11-07）。技を足すときはここに1行（1つの辞書）を足すだけにする。
## clip：使う絵（assets/rana2）、spd：流す速さの倍率、cd：待ち（秒）、total：長さ（秒、絵より長くてもよい）
## ev：[秒, 当たり] の列。当たりは battle._attack_from の spec に、次を足したもの：
##   k＝威力（連撃 A の何倍）、x0・x1＝帯の範囲（ラナの前へ m）、pull＝"front"（前 1.5m へ寄せる）／"in"（ラナへ寄せる）、pull_m＝寄せる量、
##   fx＝見た目の種類（flurry・flurry_end・rift・vortex・vortex_end）、freeze_add＝止めを長く
## 威力の元：連撃 A の 1 発 = BASE_DMG（player.gd の表と同じ）

const BASE_DMG := 18.0
const ORDER := ["flurry", "rift", "vortex", "shadow"]

## 状況で変わる攻撃（2026-11-16、specs/combat_tactics.md 11.）：攻撃ボタンが金に光っている時だけ、通常攻撃の代わりに出る。
##   air＝浮いた敵への追い打ち（浮かせ直す）・back＝背中を見せた敵への一撃・counter＝ジャストガードの後の反撃。モーションは今の atkA/B/C を速く
static func context_table() -> Dictionary:
	return {
		"ctx_air": {"clip": "atkB", "spd": 1.7, "cd": 0.5, "total": 0.5, "ctx": true,
			"ev": [[0.12, {"shape": "fwd", "side": 1, "r": 2.6, "lane": 1.3, "k": 1.1, "strong": false, "kb": 0.1, "lift": 2.2, "fx": "flurry", "shake": 5.0}],
				[0.28, {"shape": "fwd", "side": 1, "r": 2.7, "lane": 1.3, "k": 1.6, "strong": true, "kb": 0.4, "lift": 2.8, "fx": "flurry_end", "freeze_add": 0.04, "shake": 9.0}]]},
		"ctx_back": {"clip": "atkA", "spd": 1.8, "cd": 0.6, "total": 0.45, "ctx": true,
			"ev": [[0.16, {"shape": "fwd", "side": 1, "r": 2.5, "lane": 1.1, "k": 2.4, "strong": true, "kb": 0.8, "fx": "flurry_end", "freeze_add": 0.06, "shake": 10.0}]]},
		"ctx_counter": {"clip": "atkC", "spd": 2.4, "cd": 0.0, "total": 0.62, "ctx": true,
			"ev": [[0.3, {"shape": "fwd", "side": 1, "r": 2.9, "lane": 1.4, "k": 3.0, "strong": true, "kb": 1.0, "lift": 2.6, "fx": "flurry_end", "freeze_add": 0.1, "shake": 14.0}]]},
	}

static func table() -> Dictionary:
	var t := {}
	# 乱れ斬り：前方へ集中する10回＋最後に強い1回。敵をラナの前へ寄せ続ける（ボスは寄せない）
	var fl := []
	for i in 10:
		fl.append([0.25 + i * 0.095, {"shape": "fwd", "side": 1, "r": 2.3, "lane": 1.1, "k": 0.45, "strong": false, "kb": 0.3,
			"pull": "front", "pull_m": 0.25, "fx": "flurry", "shake": 3.0}])
	fl.append([1.27, {"shape": "fwd", "side": 1, "r": 2.5, "lane": 1.2, "k": 2.0, "strong": true, "kb": 1.6, "fx": "flurry_end", "freeze_add": 0.08, "shake": 12.0, "wave": true}])
	t["flurry"] = {"clip": "flurry", "spd": 1.0, "cd": 8.0, "total": 1.54, "ev": fl}
	# 地走り：斬り下ろしの当たりから、前方へ地割れの衝撃が3回（0.12 秒おき）
	var hb := 33.0 / 72.0 / 1.5
	var rf := []
	var rng := [[0.0, 3.0], [2.0, 5.5], [4.5, 8.0]]
	for i in 3:
		rf.append([hb + i * 0.12, {"shape": "band", "side": 1, "r": 2.0, "x0": rng[i][0], "x1": rng[i][1], "lane": 0.9, "k": 1.1,
			"strong": i == 2, "lift": 2.5, "fx": "rift", "n": i, "shake": 13.0 if i == 2 else 8.0}])
	t["rift"] = {"clip": "atkB", "spd": 1.5, "cd": 7.0, "total": 0.85, "ev": rf}
	# 金の渦：半径 3.2m の円に 0.15 秒おき 8 回、毎回ラナへ引き寄せる。最後に外へ大きく弾く
	var vx := []
	for i in 8:
		vx.append([0.15 * (i + 1), {"shape": "circle", "side": 1, "r": 3.2, "cx": 0.0, "lane": 9.0, "k": 0.5, "strong": false, "kb": 0.2,
			"pull": "in", "pull_m": 0.6, "fx": "vortex", "n": i, "shake": 3.0}])
	vx.append([1.32, {"shape": "circle", "side": 1, "r": 3.4, "cx": 0.0, "lane": 9.0, "k": 1.8, "strong": true, "kb": 2.6, "fx": "vortex_end", "freeze_add": 0.06, "shake": 14.0}])
	t["vortex"] = {"clip": "hold", "spd": 1.25, "cd": 12.0, "total": 1.45, "ev": vx}
	# 回り込み（2026-11-16 ユーザー決定、specs/combat_tactics.md 3.・9.）：回避の動きで近い敵（前後 6.5m）の背後へ抜け、振り返って斬り下ろし。
	#   behind＝回り込む技（player.gd）。dash_t 秒で背後へ（当たらない）、着いたら敵は BACK_WRAP_T 秒背中を見せたまま。敵がいなければ前へ 3m 走って斬る
	# 2026-11-16 ユーザー「背後攻撃をもっと強く・派手に」：背後へ抜けたら、斬り上げ（小）→溜めの一閃（大・金の斬撃・長い止め・大きな揺れ）の 2 段。
	#   回り込んだ相手は背中を向けているので、2 段とも背中の当たり（傷 1.2 倍・ダウン値 2 倍・金の数字）
	t["shadow"] = {"clip": "atkB", "spd": 1.3, "cd": 6.0, "total": 0.86, "behind": true, "dash_t": 0.16, "range": 6.5,
		"ev": [[0.24, {"shape": "fwd", "side": 1, "r": 2.2, "lane": 1.0, "k": 0.9, "strong": false, "kb": 0.2, "fx": "flurry", "shake": 4.0}],
			[0.46, {"shape": "fwd", "side": 1, "r": 2.8, "lane": 1.2, "k": 2.6, "strong": true, "kb": 1.0, "fx": "flurry_end", "freeze_add": 0.08, "lift": 3.0, "shake": 15.0}]]}
	# 必殺技（当たりの流れは player.gd の _ult_process）。ツリーの技レベルで k_hit・k_end と cost_mul が変わる（skill_tree.gd）
	t["ult"] = {"k_hit": 0.8, "k_end": 4.0}
	return t
