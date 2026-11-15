extends RefCounted
## コンボとスタイルのランク（2026-11-16 ユーザー決定、specs/combat_tactics.md 5.・9.）。元：奈落の JC（dev/naraku_src.html）。
## 数字＝ラナの当たった数。ランクは点数：当たり 1 点＋違う技へ移った最初の当たり・背中・空中・技の取り消し・ジャストガードで加点、
## 同じ技を続けると伸びない。WIN 秒当たらなければ切れる（ランクが高いほど早く減る）。被弾でランクが 1 段下がる。
## 数えるのはラナの当たりだけ（仲間の自動の当たりは数えない＝自分の打ち手の評価にする。Claude の仮）。

const WIN := 2.6
const RANKS := [   # [必要な点, 文字, 添え字（仮）, 芯の色, 縁の色]。赤系は使わない（赤＝敵）
	[4.0, "D", "DIM", Color("d6dde8"), Color("4a5a70")],
	[10.0, "C", "CRESCENT", Color("b8e4ff"), Color("2a5f86")],
	[20.0, "B", "BRILLIANT", Color("7cc4ff"), Color("1d4a8c")],
	[35.0, "A", "ARCANE", Color("ffe7a6"), Color("8a6a22")],
	[55.0, "S", "SPLENDID", Color("ffd36a"), Color("8a5a12")],
	[80.0, "SS", "SUPERNOVA", Color("ffc94d"), Color("7a4a0a")],
	[115.0, "SSS", "SOVEREIGN", Color("fff4d0"), Color("b07a1a")],
]
const P_HIT := 1.0
const P_NEW_TECH := 1.5     # 違う技へ移った最初の当たり
const P_BACK := 1.0
const P_AIR := 1.0
const P_CANCEL := 3.0
const P_GUARD := 5.0
const SAME_K := 0.5         # 同じ技の 3 回目以降の当たり（技の出し直し単位で数える）

var hits := 0
var pts := 0.0
var t := 0.0
var rank := -1
var best := 0
var pop := 0.0          # 数字が膨らむ
var rank_pop := 0.0     # ランクが上がった瞬間
var out_t := 0.0        # 切れた後に最後の数字を流す
var out_n := 0
var out_r := -1
var last_tech := ""
var tech_streak := 0    # 同じ技を続けて出した回数
var tech_seen := false  # 今の技で 1 回当たったか

static func rank_of(p: float) -> int:
	var r := -1
	for i in RANKS.size():
		if p >= float(RANKS[i][0]):
			r = i
	return r

## 技を出し始めた（技の出し直しの単位）。tech＝atkA・flurry など
func tech_start(tech: String) -> void:
	if tech == last_tech:
		tech_streak += 1
	else:
		tech_streak = 0
	last_tech = tech
	tech_seen = false

func hit(back: bool, air: bool) -> void:
	var p := P_HIT
	if not tech_seen:
		tech_seen = true
		if tech_streak == 0 and hits > 0:
			p += P_NEW_TECH
	if tech_streak >= 2:
		p *= SAME_K
	if back:
		p += P_BACK
	if air:
		p += P_AIR
	hits += 1
	_add(p)
	pop = 1.0

func bonus(kind: String) -> void:
	if hits <= 0 and kind != "guard":
		return
	_add(P_CANCEL if kind == "cancel" else P_GUARD)

func hurt() -> void:
	if rank >= 0:
		rank -= 1
		pts = float(RANKS[rank][0]) if rank >= 0 else 0.0

func _add(p: float) -> void:
	pts += p
	t = WIN
	best = maxi(best, hits)
	var r := rank_of(pts)
	if r > rank:
		rank = r
		rank_pop = 1.0

func tick(dt: float) -> void:
	pop = maxf(0.0, pop - dt / 0.22)
	rank_pop = maxf(0.0, rank_pop - dt / 0.35)
	if out_t > 0.0:
		out_t -= dt
	if hits > 0 or pts > 0.0:
		t -= dt * (1.0 + maxf(0.0, rank) * 0.12)   # ランクが上がるほど早く減る
		if t <= 0.0:
			_break()

func _break() -> void:
	if hits >= 10:
		out_t = 0.9
		out_n = hits
		out_r = rank
	hits = 0
	pts = 0.0
	t = 0.0
	rank = -1
	last_tech = ""
	tech_streak = 0

## 右上のコンボ表示（奈落の jcDrawCombo を Godot の Control へ）。c＝描く Control、right＝右端の x、y0＝ランクの文字の基準線、u＝720 基準の倍率
func draw(c: Control, right: float, y0: float, u: float) -> void:
	var show := hits >= 2
	var out := out_t > 0.0 and not show
	if not show and not out:
		return
	var n: int = hits if show else out_n
	var ri: int = rank if show else out_r
	var a: float = 1.0 if show else clampf(out_t / 0.9, 0.0, 1.0)
	var slide: float = 0.0 if show else (1.0 - a) * 40.0 * u
	var font: Font = ThemeDB.fallback_font
	# 全体を右へ傾ける（スタイリッシュに）
	c.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.16, 1), Vector2(y0 * 0.16 + slide, 0)))
	var y := y0
	if ri >= 0:
		var R: Array = RANKS[ri]
		var rp: float = rank_pop if show else 0.0
		var sz := int(64 * u * (1.0 + rp * 0.45))
		var wob: float = sin(Time.get_ticks_msec() * 0.06) * rp * 2.0 * u
		if rp > 0.0:
			c.draw_circle(Vector2(right - 30 * u, y - 22 * u), 46 * u * (1.0 + rp), Color(R[3].r, R[3].g, R[3].b, rp * 0.35))
		_text(c, font, str(R[1]), Vector2(right + wob, y), sz, R[3], R[4], a)
		var sub: String = " ".join(str(R[2]).split(""))
		c.draw_string(font, Vector2(right - 400 * u, y + 26 * u), sub, HORIZONTAL_ALIGNMENT_RIGHT, 400 * u, int(22 * u), Color(R[3].r, R[3].g, R[3].b, a * 0.9))
		y += 70 * u
	var pz: float = 1.0 + (pop if show else 0.0) * 0.5
	_text(c, font, str(n), Vector2(right - 92 * u, y), int(44 * u * pz), Color("ffe6a8"), Color("7a4a12"), a)
	c.draw_string_outline(font, Vector2(right - 300 * u, y), "COMBO", HORIZONTAL_ALIGNMENT_RIGHT, 300 * u, int(28 * u), int(6 * u), Color(0, 0, 0, a * 0.85))
	c.draw_string(font, Vector2(right - 300 * u, y), "COMBO", HORIZONTAL_ALIGNMENT_RIGHT, 300 * u, int(28 * u), Color(0.95, 0.87, 0.69, a))
	if show:   # 残り時間の細い帯
		var w := 150.0 * u
		var f := clampf(t / WIN, 0.0, 1.0)
		c.draw_rect(Rect2(Vector2(right - w, y + 9 * u), Vector2(w, 5 * u)), Color(0, 0, 0, 0.55))
		var col: Color = RANKS[ri][3] if ri >= 0 else Color("f3dfb0")
		c.draw_rect(Rect2(Vector2(right - w * f, y + 9 * u), Vector2(w * f, 5 * u)), Color(col.r, col.g, col.b, 0.95))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _text(c: Control, font: Font, s: String, p: Vector2, size: int, core: Color, edge: Color, a: float) -> void:
	var w := 600.0
	var pos := Vector2(p.x - w, p.y)
	c.draw_string_outline(font, pos + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_RIGHT, w, size, maxi(3, int(size * 0.16)), Color(0, 0, 0, 0.85 * a))
	c.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_RIGHT, w, size, maxi(2, int(size * 0.1)), Color(edge.r, edge.g, edge.b, a))
	c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_RIGHT, w, size, Color(core.r, core.g, core.b, a))
