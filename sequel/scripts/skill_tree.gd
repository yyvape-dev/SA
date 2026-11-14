extends RefCounted
## スキルツリー（specs/skill_tree.md、2026-11-14 ユーザー決定）。表はこのファイル1か所。
## キャラ → 技 id → {name, max_lv, need_lv, need, glyph, derivs: {派生id: {name, glyph, patch}}}
##   need_lv＝取るのに要るキャラのレベル、need＝[前の技の id, 技レベル]（最初の技は空）。新しい技はここに行を足すだけ（今は無い）。
## 技の辞書は skills.gd・lily_skills.gd・ranka_skills.gd の table()。ここで「技レベル（k・cd の倍率）」と「派生の差分（patch）」を掛けた辞書を返す。
## patch（派生）：技ごとの if を処理に足さず、元の辞書への差分だけで書く。
##   最上位のキー＝上書き（cd・fps・move_ok・chain_n・dash_back など）。"cd_mul"＝待ちに掛ける。"frames_add"＝絵のコマの列に足す。
##   "ev_ops"＝当たりの列への操作の列。sel は "hits"（締め以外の当たり）／"last"（締めの強い当たり）／"all"。
##     {"op":"set", "sel", "v":{キー:値}}           … 当たりの辞書へ上書き
##     {"op":"mul", "sel", "v":{キー:倍}}           … 数の項目に掛ける
##     {"op":"thin", "keep":n}                      … 締め以外の当たりを、同じ時間の中で等間隔に n 回へ減らす（0＝無し）
##     {"op":"dense", "n":n}                        … 締め以外の当たりを n 回へ増やす（時刻と数の項目は最初〜最後の間を補間）
##     {"op":"lerp", "sel", "v":{キー:[最初, 最後]}} … 選んだ当たりへ、最初〜最後を等間隔に割り当てる（"t"＝時刻）
##     {"op":"fork", "sel", "v":{キー:値}, "z_slope":[...]} … 当たりを複製して斜めの帯にする（z_slope ごとに1本）
##     {"op":"append", "t_from":"last", "dt":秒/コマ, "spec":{...}} … 当たりを足す（時刻は締めの時刻＋dt）
## 処理側の汎用の項目（spec の末尾にも追記）：z_slope・move_ok・move_spd・chain_n・dash_back・return_trip・linger・seek_n・seek_r・pull "out"・band_fx・burst_fx・rev

const MAX_LV := 5
const DERIV_LV := 3
const CHARS := ["rana", "lily", "ranka"]
const BASE_SKILLS := {"rana": ["flurry", "rift", "vortex", "ult"], "lily": ["rush", "barrage", "storm", "ult"], "ranka": ["shot", "ring", "quake", "ult"]}
const Skills := preload("res://scripts/skills.gd")
const LilySkills := preload("res://scripts/lily_skills.gd")
const RankaSkills := preload("res://scripts/ranka_skills.gd")

static func tree() -> Dictionary:
	return {
		"rana": {
			"flurry": {"name": "乱れ斬り", "derivs": {
				"senpu": {"name": "旋風", "glyph": "band", "patch": {"ev_ops": [
					{"op": "set", "sel": "last", "v": {"shape": "band", "x0": 0.3, "x1": 6.0, "lane": 1.0, "band_fx": "gold"}}]}},
				"iai": {"name": "居合", "glyph": "heavy", "patch": {"ev_ops": [
					{"op": "thin", "keep": 4},
					{"op": "mul", "sel": "hits", "v": {"k": 2.4}},
					{"op": "set", "sel": "hits", "v": {"strong": true, "kb": 0.6, "freeze_add": 0.05, "shake": 7.0}}]}},
				"donkomi": {"name": "呑込", "glyph": "many", "patch": {"ev_ops": [
					{"op": "dense", "n": 15},
					{"op": "mul", "sel": "hits", "v": {"k": 0.6, "pull_m": 1.8}}]}}}},
			"rift": {"name": "地走り", "derivs": {
				"sansa": {"name": "三叉", "glyph": "fork", "patch": {"ev_ops": [
					{"op": "fork", "sel": "all", "z_slope": [-0.32, 0.32], "v": {"k_mul": 0.6, "lane": 0.55}}]}},
				"enshin": {"name": "延伸", "glyph": "long", "patch": {"ev_ops": [
					{"op": "dense", "n": 4},
					{"op": "lerp", "sel": "all", "v": {"x0": [0.0, 9.0], "x1": [3.0, 12.0], "t": [0.306, 0.786]}}]}},
				"fukiage": {"name": "噴上げ", "glyph": "burst", "patch": {"ev_ops": [
					{"op": "append", "t_from": "last", "dt": 0.12, "spec": {"shape": "circle", "side": 1, "r": 2.3, "cx": 8.0, "lane": 9.0, "k": 1.6,
						"strong": true, "kb": 0.5, "lift": 7.0, "burst_fx": "gold", "shake": 13.0, "wave": true}}]}}}},
			"vortex": {"name": "金の渦", "derivs": {
				"ouzu": {"name": "大渦", "glyph": "big", "patch": {"ev_ops": [
					{"op": "thin", "keep": 5},
					{"op": "set", "sel": "hits", "v": {"r": 4.5}},
					{"op": "set", "sel": "last", "v": {"r": 4.8}},
					{"op": "mul", "sel": "hits", "v": {"k": 1.3}}]}},
				"aruki": {"name": "歩き渦", "glyph": "walk", "patch": {"move_ok": true, "move_spd": 0.6}},
				"hanten": {"name": "反転", "glyph": "out", "patch": {"ev_ops": [
					{"op": "set", "sel": "hits", "v": {"pull": "out", "pull_m": 0.2, "kb": 0.3, "rev": true}}]}}}},
			"ult": {"name": "必殺技", "derivs": _ult_todo()},
		},
		"lily": {
			"rush": {"name": "迅雷", "derivs": {
				"ofuku": {"name": "往復", "glyph": "back", "patch": {"frames_add": [24, 22, 20, 19, 18, 17, 47, 48, 49, 50, 51, 52], "dash_back": [24, 29],
					"ev_ops": [{"op": "append", "t_from": "last", "dt": 22, "spec": {"shape": "band", "side": 1, "r": 2.0, "lane": 1.0, "k": 1.4,
						"strong": true, "kb": 1.4, "fx": "rush", "back": true, "shake": 9.0}}]}},
				"rensa": {"name": "連鎖", "glyph": "chain", "patch": {"chain_n": 3, "chain_r": 7.0}}}},
			"barrage": {"name": "雷連打", "derivs": {
				"arashi": {"name": "嵐打", "glyph": "many", "patch": {"fps": 52.0, "ev_ops": [
					{"op": "dense", "n": 20},
					{"op": "mul", "sel": "hits", "v": {"k": 0.75}}]}},
				"tataki": {"name": "叩付け", "glyph": "slam", "patch": {"ev_ops": [
					{"op": "set", "sel": "last", "v": {"shape": "circle", "r": 3.2, "cx": 1.4, "lane": 9.0, "lift": 0.0, "kb": 2.0, "burst_fx": "lily"}}]}}}},
			"storm": {"name": "雷陣", "derivs": {
				"tsuirai": {"name": "追雷", "glyph": "seek", "patch": {"ev_ops": [
					{"op": "set", "sel": "hits", "v": {"seek_n": 3, "seek_r": 8.0, "r": 8.0}}]}},
				"sokujin": {"name": "速陣", "glyph": "fast", "patch": {"cd_mul": 0.6, "ev_ops": [
					{"op": "mul", "sel": "all", "v": {"r": 0.7}}]}}}},
			"ult": {"name": "必殺技", "derivs": _ult_todo()},
		},
		"ranka": {
			"shot": {"name": "指弾", "derivs": {
				"sandan": {"name": "散弾", "glyph": "spread", "patch": {"ev_ops": [
					{"op": "fork", "sel": "all", "z_slope": [-0.22, 0.22], "v": {"k_mul": 0.6, "lane": 0.45}}]}},
				"tame": {"name": "溜め撃ち", "glyph": "charge", "patch": {"ev_ops": [
					{"op": "thin", "keep": 0},
					{"op": "mul", "sel": "last", "v": {"k": 1.8}},
					{"op": "set", "sel": "last", "v": {"r": 12.0, "lane": 1.5, "freeze_add": 0.08, "shake": 14.0}}]}}}},
			"ring": {"name": "円環", "derivs": {
				"hamon": {"name": "波紋", "glyph": "wave", "patch": {"ev_ops": [
					{"op": "lerp", "sel": "hits", "v": {"r": [3.6, 8.5]}},
					{"op": "set", "sel": "last", "v": {"r": 9.5}}]}},
				"kekkai": {"name": "結界", "glyph": "stay", "patch": {"ev_ops": [
					{"op": "set", "sel": "last", "v": {"linger": {"n": 6, "gap": 0.35, "k": 0.25, "band": "ranka"}}}]}}}},
			"quake": {"name": "星震", "derivs": {
				"seigun": {"name": "星群", "glyph": "many", "patch": {"ev_ops": [
					{"op": "dense", "n": 10},
					{"op": "mul", "sel": "hits", "v": {"k": 0.75}}]}},
				"itten": {"name": "一点", "glyph": "focus", "patch": {"ev_ops": [
					{"op": "set", "sel": "hits", "v": {"shape": "circle", "r": 4.0, "cx": 0.0, "lane": 9.0}},
					{"op": "set", "sel": "last", "v": {"shape": "circle", "r": 4.5, "cx": 0.0, "lane": 9.0}},
					{"op": "mul", "sel": "all", "v": {"k": 1.5}}]}}}},
			"ult": {"name": "必殺技", "derivs": _ult_todo()},
		},
	}

## 必殺技の派生：枠だけ（中身はユーザー確認後。specs/skill_tree.md 2. の仮の案）。todo＝選べない
static func _ult_todo() -> Dictionary:
	return {"todo1": {"name": "未定", "glyph": "todo", "todo": true, "patch": {}}, "todo2": {"name": "未定", "glyph": "todo", "todo": true, "patch": {}}}

## キャラの表（技 id → 行）。max_lv・need_lv・need の既定を埋める
static func rows(ch: String) -> Dictionary:
	var t: Dictionary = tree().get(ch, {})
	for id in t:
		var r: Dictionary = t[id]
		if not r.has("max_lv"): r.max_lv = MAX_LV
		if not r.has("need_lv"): r.need_lv = 1
		if not r.has("need"): r.need = []
	return t

## 並び（必殺技は一番下）
static func order(ch: String) -> Array:
	var out: Array = BASE_SKILLS[ch].duplicate()
	out.erase("ult")
	for id in rows(ch):
		if not out.has(id) and id != "ult":
			out.append(id)
	out.append("ult")
	return out

static func base_table(ch: String) -> Dictionary:
	match ch:
		"lily": return LilySkills.table()
		"ranka": return RankaSkills.table()
	return Skills.table()

## 技レベルの倍率：威力は Lv1 から +10％ずつ、待ちは Lv3 で −10％・Lv5 で −20％（必殺技はゲージの必要量）
static func k_mul(lv: int) -> float:
	return 1.0 + 0.1 * float(clampi(lv, 1, MAX_LV) - 1)

static func cd_mul(lv: int) -> float:
	return 0.8 if lv >= 5 else (0.9 if lv >= 3 else 1.0)

## 進み具合（progress.gd）を読んで、技レベルと派生を掛けたキャラの表を返す（pr が null なら元の表）
static func table_for(ch: String, pr) -> Dictionary:
	var base := base_table(ch)
	if pr == null:
		return base
	var out := {}
	for id in base:
		out[id] = apply(ch, id, base[id], pr.skill_level(ch, id), pr.deriv_of(ch, id))
	return out

## 1技に技レベルと派生を掛けた辞書（元の辞書は変えない）
static func apply(ch: String, id: String, sk: Dictionary, lv: int, deriv: String) -> Dictionary:
	var d: Dictionary = sk.duplicate(true)
	var r: Dictionary = rows(ch).get(id, {})
	if deriv != "" and lv >= DERIV_LV and r.has("derivs") and r.derivs.has(deriv) and not r.derivs[deriv].get("todo", false):
		d = _patch(d, r.derivs[deriv].patch)
		d.deriv = deriv
	var km := k_mul(lv)
	for key in ["k_step", "k_end", "k_hit"]:   # 必殺技の当たりの倍（ランカ天照・ラナ）
		if d.has(key):
			d[key] = float(d[key]) * km
	if d.has("ev"):
		for e in d.ev:
			if e[1].has("k"):
				e[1].k = float(e[1].k) * km
	if d.has("cd"):
		d.cd = float(d.cd) * cd_mul(lv)
	if id == "ult":
		d.cost_mul = cd_mul(lv)
	d.lv = lv
	return d

## ---------- 差分（patch）を掛ける ----------
static func _is_hit(e: Array) -> bool:
	var s: Dictionary = e[1]
	return String(s.get("fx", "")) != "seq" and String(s.get("shape", "")) != "none" and s.has("k") and float(s.k) > 0.0

static func _last_i(ev: Array) -> int:
	var li := -1
	for i in ev.size():
		if _is_hit(ev[i]) and bool(ev[i][1].get("strong", false)):
			li = i
	return li

static func _sel(ev: Array, sel: String) -> Array:
	var li := _last_i(ev)
	var out := []
	for i in ev.size():
		if not _is_hit(ev[i]):
			continue
		if sel == "all" or (sel == "last" and i == li) or (sel == "hits" and i != li and not bool(ev[i][1].get("strong", false))):
			out.append(i)
	return out

static func _patch(d: Dictionary, p: Dictionary) -> Dictionary:
	for key in p:
		match key:
			"ev_ops":
				for op in p.ev_ops:
					d.ev = _op(d.ev, op, d)
			"cd_mul":
				d.cd = float(d.cd) * float(p.cd_mul)
			"frames_add":
				d.frames = d.frames + p.frames_add
			_:
				d[key] = p[key]
	return d

static func _num_t(ev: Array) -> bool:   # 時刻が秒（ラナ）か、コマの番号（リリィ・ランカ）か
	return ev.size() > 0 and ev[0][0] is float

static func _op(ev: Array, op: Dictionary, d: Dictionary) -> Array:
	var sec := _num_t(ev)
	match String(op.op):
		"set", "mul":
			for i in _sel(ev, String(op.get("sel", "all"))):
				for k in op.v:
					if op.op == "set":
						ev[i][1][k] = op.v[k]
					elif ev[i][1].has(k):
						ev[i][1][k] = float(ev[i][1][k]) * float(op.v[k])
		"thin", "dense":
			var idx := _sel(ev, "hits")
			if idx.is_empty():
				return ev
			var n: int = int(op.get("keep", op.get("n", 0)))
			var first: Array = ev[idx[0]]
			var lastv: Array = ev[idx[-1]]
			var keep := []
			for i in ev.size():
				if not idx.has(i):
					keep.append(ev[i])
			for j in n:
				var u := 0.5 if n == 1 else float(j) / float(n - 1)
				if op.op == "thin" and n > 1:   # 減らすときは元の当たりから等間隔に選ぶ（コマに合う時刻のまま）
					var src: Array = ev[idx[int(round(u * float(idx.size() - 1)))]]
					keep.append([src[0], src[1].duplicate(true)])
					continue
				var s: Dictionary = first[1].duplicate(true)
				for k in s:
					if (s[k] is float or s[k] is int) and lastv[1].has(k) and k != "n":
						s[k] = lerpf(float(first[1][k]), float(lastv[1][k]), u)
				s.n = j
				var tt: float = lerpf(float(first[0]), float(lastv[0]), u)
				keep.append([tt if sec else int(round(tt)), s])
			keep.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
			return keep
		"lerp":
			var idx2 := _sel(ev, String(op.get("sel", "all")))
			for j in idx2.size():
				var u2 := 0.0 if idx2.size() == 1 else float(j) / float(idx2.size() - 1)
				for k in op.v:
					var ab: Array = op.v[k]
					var v: float = lerpf(float(ab[0]), float(ab[1]), u2)
					if k == "t":
						ev[idx2[j]][0] = v if sec else int(round(v))
					else:
						ev[idx2[j]][1][k] = v
		"fork":
			var add := []
			for i in _sel(ev, String(op.get("sel", "all"))):
				for zs in op.z_slope:
					var s2: Dictionary = ev[i][1].duplicate(true)
					s2.z_slope = float(zs)
					s2.fork = true
					if op.v.has("k_mul"):
						s2.k = float(s2.k) * float(op.v.k_mul)
					for k in op.v:
						if k != "k_mul":
							s2[k] = op.v[k]
					add.append([ev[i][0], s2])
			ev.append_array(add)
			ev.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		"append":
			var li := _last_i(ev)
			var t0: float = float(ev[li][0]) if li >= 0 else float(ev[-1][0])
			var tt2: float = t0 + float(op.dt)
			ev.append([tt2 if sec else int(round(tt2)), op.spec.duplicate(true)])
			ev.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
			if sec and d.has("total"):
				d.total = maxf(float(d.total), tt2 + 0.2)
	return ev
