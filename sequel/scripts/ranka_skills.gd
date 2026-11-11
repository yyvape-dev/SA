extends RefCounted
## ランカのスキル（2026-11-12、ユーザー決定）。形は lily_skills.gd と同じ（1技＝1辞書）。
##   frames：使う絵の番号の列（clip の中の番号。技の動画は 8コマ/秒 に間引いてある）、fps：流す速さ、cd：待ち（秒）
##   ev：[frames の何番目, 当たり]。当たりは battle._attack_from の spec に k（ランカの1発 RankaAlly.DMG の何倍）と fx（見た目）を足したもの
##   当たりの shape "screen"＝画面の中（ランカから左右 SCREEN_R m 以内）の敵すべて（ranka_ally.gd が circle に直す）
## 技（ユーザーの言葉から）：
##   shot 指弾＝指さし → 指先から気弾を遠くへ（3発、最後は貫く大きい弾）
##   ring 円環＝指を顔の前に構える → 自分を中心にした大きな円環の連続範囲攻撃
##   quake 星震＝頭に蒼い雷をまとい腕を交差 → 画面の広い範囲（前作 SA1 の星震：夜空へ暗転 → 星の雨 → 大きな一撃）
##   ult 天照＝必殺技。画面の全範囲へ激しい光と揺れ、朱色の花びらが舞う連続攻撃（ranka_ally.gd の _ult_process）

const ORDER := ["shot", "ring", "quake"]
const SCREEN_R := 9.5   # 遊ぶカメラで見える横幅の半分くらい（ally.gd の RUSH_MAX と同じ考え）

static func table() -> Dictionary:
	var t := {}
	# 指弾：腕が伸びきるのが 5 コマ目。6・11 で小さい弾、17 で大きい貫く弾
	var pf := []
	for i in 33:
		pf.append(i)
	t["shot"] = {"clip": "skill_point", "frames": pf, "fps": 16.0, "cd": 8.0, "ev": [
		[6, {"shape": "band", "side": 1, "r": 9.0, "lane": 0.75, "k": 1.0, "strong": false, "kb": 0.4, "fx": "shot", "n": 0, "shake": 3.0}],
		[11, {"shape": "band", "side": 1, "r": 9.0, "lane": 0.75, "k": 1.0, "strong": false, "kb": 0.4, "fx": "shot", "n": 1, "shake": 3.0}],
		[17, {"shape": "band", "side": 1, "r": 10.0, "lane": 1.1, "k": 2.6, "strong": true, "kb": 2.0, "fx": "shot_big", "n": 2, "shake": 10.0, "wave": true, "freeze_add": 0.04}]]}
	# 円環：指を顔の前に構えたまま（4〜28 コマ目）、足元から蒼白の輪が 6 回広がる → 最後に大きな輪で外へ弾く
	var rf := []
	for i in 33:
		rf.append(i)
	var rev := []
	for i in 6:
		rev.append([6 + i * 3, {"shape": "circle", "side": 1, "r": 3.6 + i * 0.3, "cx": 0.0, "lane": 9.0, "k": 0.55, "strong": false, "kb": 0.12,
			"pull": "in", "pull_m": 0.15, "fx": "ring", "n": i, "shake": 4.0}])
	rev.append([25, {"shape": "circle", "side": 1, "r": 6.0, "cx": 0.0, "lane": 9.0, "k": 1.8, "strong": true, "kb": 2.4, "fx": "ring_end", "shake": 14.0, "wave": true, "freeze_add": 0.05}])
	t["ring"] = {"clip": "skill_ring", "frames": rf, "fps": 16.0, "cd": 12.0, "ev": rev}
	# 星震：腕を広げる（0〜12）→ 交差（13〜20）→ 頭に蒼い雷（21〜31）→ 構えへ（45〜）。21 で夜空へ・光の柱、23〜33 で星の雨、38 で大きな一撃
	var qf := []
	for i in 49:
		qf.append(i)
	var qev := [[13, {"shape": "none", "k": 0.0, "fx": "quake_charge"}],
		[21, {"shape": "circle", "side": 1, "r": 3.0, "cx": 0.0, "lane": 9.0, "k": 1.0, "strong": true, "kb": 0.6, "fx": "quake_burst", "shake": 12.0}]]
	for i in 6:
		qev.append([23 + i * 2, {"shape": "screen", "side": 1, "k": 0.6, "strong": false, "kb": 0.1, "fx": "star", "n": i, "shake": 5.0}])
	qev.append([38, {"shape": "screen", "side": 1, "k": 3.0, "strong": true, "kb": 2.6, "fx": "quake_end", "shake": 22.0, "wave": true, "freeze_add": 0.08}])
	t["quake"] = {"clip": "skill_thunder", "frames": qf, "fps": 18.0, "cd": 22.0, "ev": qev}
	# 必殺技 天照：当たりは ranka_ally.gd の _ult_process（画面の敵すべてへ 8 回 1.0 倍＋決め 9.0 倍）
	t["ult"] = {"clip": "atk_palm", "frames": [0], "fps": 12.0, "ev": [], "steps": 8, "k_step": 1.0, "k_end": 9.0}
	return t
