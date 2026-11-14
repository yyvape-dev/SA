extends Node3D
## 融合都市の1区画（縦切り）。街を左右と奥行きで歩く。
## 起動の切り替え（環境変数）：
##   CAPTURE_GUIDE=1 … 外部AIに渡す下絵を art/guide/ に書き出して終了（=<部品のid> でその部品だけ）
##   CAPTURE_PLAY=1  … 動作確認の画面を captures/ に書き出して終了

const City := preload("res://scripts/city_block1.gd")
const BT := preload("res://scripts/backtown_block.gd")
const GamehallFloor := preload("res://scripts/gamehall_floor.gd")
var town_floor := "backtown"
var town_floor_busy := false
var town_edge_armed := true
var town := ""   # "back"＝裏の町の入り口の下絵（specs/backtown_blockout.md。環境変数 TOWN=back、Web は ?town=back）
const Player := preload("res://scripts/player.gd")
const TouchUI := preload("res://scripts/touch_ui.gd")
const Battle := preload("res://scripts/battle.gd")
const Fx := preload("res://scripts/fx.gd")
const PAINT_SHADER := preload("res://scripts/proj_paint.gdshader")
const SPRITE_SHADER := preload("res://scripts/sprite_bb.gdshader")

const ROOM_X := Vector2(-19.0, 19.0)   # 歩ける左右
var BELT_Z := Vector2(-3.2, 3.5)       # 歩ける奥行き（カメラの比較の案 A で狭める。specs/camera_depth.md）
const CAM_X := Vector2(-12.0, 12.0)    # カメラが動ける左右
const CAM_OFS := Vector3(0, 3.8, 13.5) # 下絵（塗ってもらった絵）を撮ったカメラ。下絵の撮り直し・使い回しの確認はこれ
const CAM_LOOK := Vector3(0, 2.1, 0)
## 遊ぶときのカメラ（2026-11-06、ユーザー「手前に来ても小さい」→「もっと大きくても良い」）：ラナの背が画面の高さの約 21％ → 31％ → 40％ → 35％（「拡大しすぎ、少し引いて」）。
## 塗った絵は下絵のカメラから投影しているので、遊ぶカメラを寄せても絵はずれない。
const PLAY_OFS := Vector3(0, 2.6, 8.0)
const PLAY_LOOK := Vector3(0, 1.35, 0)
const FG_PULL := 1.6                    # 手前の板を奥へ下げる量（m）
const PLAY_HALF_W := 5.7
## 必殺技の寄り（battle.cam_zoom＝1 の時）：ラナの胸の高さへ近づく
const ULT_OFS := Vector3(0.0, 1.5, 2.7)
const ULT_LOOK := Vector3(0, 1.25, 0)
var ult_dist := 3.8    # 必殺技の寄りの距離（m）。2026-11-12 ユーザー選択「中」（2.7 では絵の粗さが目立った）
var ult_drop := 0.3    # 画面の中心を顔からどれだけ下げるか（m）
const Cutin := preload("res://scripts/ult_cutin.gd")
const Fx2D := preload("res://scripts/fx2d.gd")
var fx2d                 # 2D のエフェクトの層（fx2d.gd、specs/vfx_overhaul.md）
var ground_mats := []    # [StandardMaterial3D, 元の色]：大技の暗転で暗くする
var fx_demo := -1.0      # ?fxtest=1：ラナの前に 2D の層のエフェクトを順に出す（実機・ブラウザの確認用）
var fx_demo_i := 0
## 重さの記録（?perf=1、specs/web_perf.md）：1 秒ごとに fps・コマの時間・draw call・2D の層の大きさと重なりを console へ。止まり（50ms 超）はその都度
var perf_on := false
var perf_t := 0.0
var perf_frames := []
var perf_t0 := 0
var perf_last_fx := ""
var perf_label: Label    # ?perf=1 の画面の隅の表示（iPhone で読める大きさ）
var lily_cutin           # リリィの必殺技のカットイン（仲間の絵を読み終えてから作る）
var ranka_cutin          # ランカの必殺技 天照のカットイン（2026-11-12）
const RankaAlly := preload("res://scripts/ranka_ally.gd")
signal ranka_loaded(ok: bool)
var cutin                # 遊ぶカメラで、帯の真ん中（z=0）に見える左右の半分（横持ち 19.5:9、m）
const CAM_FOV := 36.0
## カメラと奥行きの比較（specs/camera_depth.md。採用はユーザー判定）：環境変数 CAMV または URL ?cam= に A・B・C
##   A＝帯を狭く（奥と手前の倍率 1.3）、B＝カメラを遠く・画角を狭く（帯はそのまま、倍率 1.3）、C＝正投影（比較用）
var cam_variant := ""
var play_ofs := PLAY_OFS
var play_fov := CAM_FOV
var play_look := PLAY_LOOK
const MAGENTA := Color(1, 0, 1)

var cam: Camera3D
var player: Node3D
var ui: CanvasLayer
var battle: Node3D
var fx: Node3D
var piece_nodes := {}   # id -> Node3D
var guide_meta := {}    # id -> {w,h,vp}

const District := preload("res://scripts/district.gd")
const Loading := preload("res://scripts/loading.gd")
var district: Node
var loading: CanvasLayer
var district_nodes: Array = []   # 今の地区の絵で作った物（地区を出るときに捨てて、絵を解放する）
var level: Node3D                 # 今の場所（街の区画／ダンジョンの部屋）の物をまとめる。場所を変えるときに丸ごと捨てる
var glints_src: Array = []        # glints.json（区画の元の位置）
var cam_x := CAM_X                # カメラが動ける左右（部屋ごとに変わる）
var progress                      # progress.gd（レベル・武器・セーブ）
var dungeon: Node                 # dungeon.gd（入っている間だけ）
var hud: CanvasLayer              # dungeon_hud.gd
var gate: Node3D                  # 街の端のダンジョンの入口
var gate_armed := true            # 入口から離れたら、また選べる
const DungeonRun := preload("res://scripts/dungeon.gd")
const DungeonHud := preload("res://scripts/dungeon_hud.gd")
const Progress := preload("res://scripts/progress.gd")
const Ally := preload("res://scripts/ally.gd")
const GATE_X := 16.0              # 入口の位置（区画の右端、高架の下）

## 起動の各段の時刻（console に BOOT。specs/web_perf.md）
func _boot(stage: String) -> void:
	print("BOOT %s %dms" % [stage, Time.get_ticks_msec()])

## 重さの切り分け用（?perf=1 と一緒に使う）：?glow3d=0 3D の glow を切る、?vig=0 画面の仕上げ（画面を読む層）を出さない
func _q(key: String) -> bool:
	return OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search")).contains(key)

func _startup_town() -> String:
	if _q("town=back") or _q("at=gamehall"):
		return "back"
	return OS.get_environment("TOWN")

func _ready() -> void:
	_boot("main_ready")
	# 撮影・確認では乱数の種を固定する（版どうしで同じ場面・同じコマを比べるため）
	for k in ["CAPTURE_FX", "CAPTURE_LINEUP", "CAPTURE_PLAY", "CAPTURE_DUNGEON", "DUNGEON_TEST", "CAPTURE_GUIDE", "CAPTURE_REUSE"]:
		if OS.has_environment(k):
			seed(20261106)
	loading = Loading.new()
	add_child(loading)
	district = District.new()
	add_child(district)
	_load_guide_meta()
	_build_env()
	_boot("before_d1")
	var ok: bool = await district.ensure("d1")
	_boot("after_d1")
	if not ok:
		push_error("地区 d1 の絵を読み込めない")
		loading.error_text = district.last_error
	_load_glints()
	progress = Progress.new()
	if OS.has_environment("CAPTURE_DUNGEON") or OS.has_environment("DUNGEON_TEST") or OS.has_environment("CAPTURE_PLAY"):
		progress.path = "user://sa2_capture_save.json"   # 撮影・確認は毎回まっさらなセーブ（前の回のレベルが残ると場面がずれる）
		progress.reset()
	else:
		progress.load_save()
	town = _startup_town()
	if town == "back":
		if not await district.ensure("bt1"):
			loading.error_text = district.last_error
			return
		build_backtown()
	else:
		build_city()
	_boot("after_build_city")
	cam = Camera3D.new()
	_apply_cam_variant()
	cam.fov = play_fov
	cam.near = 0.3
	cam.far = 300.0
	add_child(cam)
	battle = Battle.new()
	battle.glints = glints
	battle.BELT_Z = BELT_Z
	battle.ROOM_X = ROOM_X
	battle.cam = cam
	battle.main = self
	add_child(battle)
	fx = Fx.new()
	fx.cam = cam
	add_child(fx)
	battle.fx = fx
	_boot("before_player")
	player = Player.new()
	player.world = battle
	player.room_x = ROOM_X
	player.belt_z = BELT_Z
	battle.player = player
	add_child(player)
	player.position = Vector3(-4, 0, 1.0)
	if town == "back":   # 裏の町の入り口の下絵：歩ける範囲・帯を区画に合わせる
		battle.ROOM_X = BT.ROOM_X
		battle.auto_spawn = false
		player.room_x = BT.ROOM_X
		player.belt_z = BELT_Z
		player.position = Vector3(0, 0, 0)
	_boot("after_player")
	_place_cam(true)
	_load_ally()
	_build_vignette()
	fx2d = Fx2D.new()   # UI より先に足す（同じ layer 1 で UI の下）
	fx2d.cam = cam
	add_child(fx2d)
	battle.fx2d = fx2d
	_load_fx()
	ui = TouchUI.new()
	ui.player = player
	ui.main = self
	ui.battle = battle
	add_child(ui)
	apply_progress()
	battle.foe_killed.connect(_on_foe_killed)
	cutin = Cutin.new()
	cutin.player = player
	add_child(cutin)
	hud = DungeonHud.new()
	hud.main = self
	add_child(hud)
	var capture := OS.has_environment("CAPTURE_FX") or OS.has_environment("CAPTURE_GUIDE") or OS.has_environment("CAPTURE_PLAY") or OS.has_environment("CAPTURE_REUSE") or OS.has_environment("CAPTURE_LINEUP")
	if capture:
		loading.visible = false
	else:
		loading.hide_soon()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__sa_ready = performance.now()")
		# 確認用：?diag=1 で左上に版と地区の読み込みの状態を出す
		if str(JavaScriptBridge.eval("window.location.search")).contains("diag=1"):
			loading.error_text = "ver %s | d1 %s | glints %d | painted %s | url %s" % [District.build_ver(), str(district.status.get("d1", "-")),
				glints_src.size(), str(ResourceLoader.exists("res://art/painted/b1_tavern.png")), str(JavaScriptBridge.eval("location.href"))]
		if str(JavaScriptBridge.eval("window.location.search")).contains("fxtest=1"):
			fx_demo = 2.0
		if str(JavaScriptBridge.eval("window.location.search")).contains("perf=1"):
			perf_on = true
			perf_t0 = Time.get_ticks_msec()
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
			var cl := CanvasLayer.new()
			cl.layer = 120
			perf_label = Label.new()
			perf_label.position = Vector2(12, 150)
			perf_label.add_theme_font_size_override("font_size", 30)
			perf_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
			perf_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			perf_label.add_theme_constant_override("outline_size", 8)
			perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cl.add_child(perf_label)
			add_child(cl)
		# 重さの計測（specs/dungeon_themes.md 3.2）：?dgtest=N で、広い部屋に敵 N 体を出し続ける（敵は倒れない・ラナは倒れない）
		var dgn = JavaScriptBridge.eval("new URLSearchParams(location.search).get('dgtest')")
		if dgn != null and str(dgn).is_valid_int():
			dg_perf_n = int(str(dgn))
			var dgt = JavaScriptBridge.eval("new URLSearchParams(location.search).get('dgtheme')")
			enter_dungeon.call_deferred("normal", 7, str(dgt) if dgt != null else "t1")
		# 確認用：?at=gate で入口の前から始める
		if str(JavaScriptBridge.eval("window.location.search")).contains("at=gate"):
			player.position = Vector3(gate.position.x - 2.0, 0, 0.0) if gate else Vector3(GATE_X - 0.5, 0, BELT_Z.x + 1.6)
			_place_cam(true)
	if _q("at=gamehall"):
		await change_town_floor(true)
		if town_floor == "gamehall":
			player.position.x = 0.0
			_place_cam(true)
	if OS.has_environment("DISTRICT_RELEASE_TEST"):
		_release_test.call_deferred()
	if OS.has_environment("CAPTURE_GUIDE"):
		_capture_guides.call_deferred()
	elif OS.has_environment("CAPTURE_PLAY"):
		_capture_play.call_deferred()
	elif OS.has_environment("CAPTURE_REUSE"):
		_capture_reuse.call_deferred()
	elif OS.has_environment("CAPTURE_FX"):
		_capture_fx.call_deferred()
	elif OS.has_environment("CAPTURE_LINEUP"):
		_capture_lineup.call_deferred()
	elif OS.has_environment("CAPTURE_DUNGEON") or OS.has_environment("DUNGEON_TEST"):
		var Bot = load("res://scripts/bot.gd")
		var bot: Node = Bot.new()
		bot.main = self
		add_child(bot)
	if OS.has_environment("DUNGEON_LAYOUT_TEST"):
		load("res://scripts/dungeon_map.gd").self_test()
		get_tree().quit()

## 仲間リリィ：絵（地区 pck「al1」）を読み終えたら出す。起動を待たせないよう、本体の起動の後に読む。
func _perf(delta: float) -> void:
	perf_frames.append(delta * 1000.0)
	if delta > 0.05:
		print("PERF_SPIKE t=%dms frame=%.0fms last_fx=%s" % [Time.get_ticks_msec() - perf_t0, delta * 1000.0, perf_last_fx])
	perf_t += delta
	if perf_t < 1.0:
		return
	perf_t = 0.0
	var arr: Array = perf_frames.duplicate()
	arr.sort()
	var avg := 0.0
	for v in arr:
		avg += v
	avg /= maxf(1.0, arr.size())
	var vp := get_viewport().get_viewport_rid()
	var dc_main := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var obj_main := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	var dc_tr := RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var cover := 0.0   # 2D の層の絵の面積の合計 ÷ 画面（重なりの目安）
	var n_items := 0
	if fx2d:
		var scr := get_viewport().get_visible_rect().size
		for it in fx2d.items:
			if is_instance_valid(it.node):
				n_items += 1
				if it.node is Sprite2D and it.node.texture:
					var sz: Vector2 = it.node.texture.get_size() * it.node.scale.abs()
					if it.node.hframes > 1:
						sz /= Vector2(it.node.hframes, it.node.vframes)
					cover += sz.x * sz.y / (scr.x * scr.y)
				elif it.node is CPUParticles2D:
					var s: float = (it.node.scale_amount_min + it.node.scale_amount_max) * 0.5 * it.node.texture.get_width()
					cover += it.node.amount * s * s / (scr.x * scr.y)
	var win := DisplayServer.window_get_size()
	print("PERF fps=%.1f avg=%.1fms p95=%.1fms max=%.1fms dc3d=%d obj3d=%d dc2d=%d vram=%.0fMB tex=%.0fMB win=%dx%d fx2d_vp=%s fx_items=%d cover=%.2f cpu=%.1fms gpu=%.1fms" % [
		Engine.get_frames_per_second(), avg, arr[int(arr.size() * 0.95)] if arr.size() > 0 else 0.0, arr[-1] if arr.size() > 0 else 0.0,
		dc_main, obj_main, dc_tr, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6,
		win.x, win.y, str(fx2d.sv.size) if fx2d else "-", n_items, cover,
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	perf_frames.clear()
	if perf_label:
		# 日本語のフォントがまだ無いので英数字だけ（frame＝1コマの時間、GPU＝Godot が数える映像のメモリ）
		perf_label.text = "%.0f fps\nframe avg %.0f ms / max %.0f ms\nGPU mem ~%.0f MB\nfx2d %s%s" % [Engine.get_frames_per_second(), avg,
			arr[-1] if arr.size() > 0 else 0.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6,
			"ON" if fx2d and fx2d.active else "OFF", " (half)" if fx2d and fx2d.half else ""]

## エフェクトの絵（地区 pck「fx1」：焼いた REEBO・Kenney の粒）。起動の後に読み、読み終えるまで 2D の層と絵の板は出さない
func _load_fx() -> void:
	if OS.has_feature("web"):
		if not await district.ensure("fx1"):
			push_warning("エフェクトの絵 fx1 を読めない: " + district.last_error)
			return
	_boot("fx1_loaded")
	if fx:
		fx.assets_ok = true
	if fx2d:
		fx2d.assets_ok = true

func _load_ally() -> void:
	if OS.has_feature("web"):
		if not await district.ensure("al1"):
			push_warning("仲間の絵 al1 を読めない: " + district.last_error)
			return
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lily/lily.json"))
	if not (d is Dictionary):
		return
	var a := Ally.new()
	a.setup(battle, d)
	a.position = player.position + Vector3(-1.4, 0, 0.7)
	battle.add_child(a)
	_boot("ally_loaded")
	battle.ally = a
	lily_cutin = Cutin.new()   # 立ち絵 assets/lily/cutin.webp（al1 に入っている）、蒼の帯
	lily_cutin.tex_path = "res://assets/lily/cutin.webp"
	lily_cutin.band_col = Color(0.02, 0.07, 0.16, 0.85)
	lily_cutin.line_col = Color(0.45, 0.8, 1.0, 0.95)
	lily_cutin.streak_col = Color(0.75, 0.9, 1.0, 0.35)
	lily_cutin.flash_col = Color(0.88, 0.95, 1.0)
	add_child(lily_cutin)
	_load_ranka()   # 待たない（リリィの準備を遅らせない）。読み終えたら ranka_loaded

## ランカを出すか（2026-11-12、ユーザー決定「同時参戦（3人）」）。?ranka=0 で出さない。撮影・比較の起動（CAPTURE_*）では
## 前の画と変わらないよう出さない（RANKA=1 で出す）。T5/T6 の演習（sa2_t2_playable）は ranka_wanted() を上書きする
func ranka_wanted() -> bool:
	if _q("ranka=0") or OS.get_environment("RANKA") == "0":
		return false
	if OS.get_environment("RANKA") == "1" or OS.get_environment("FX_ONLY") == "tree":   # スキルツリーの撮影は3人とも
		return true
	for k in ["CAPTURE_PLAY", "CAPTURE_FX", "CAPTURE_GUIDE", "CAPTURE_DUNGEON", "CAPTURE_LINEUP", "CAPTURE_REUSE"]:
		if OS.has_environment(k):
			return false
	return true

## 仲間ランカ：絵（地区 pck「al2」）を読み終えたら出す（リリィの後）
func _load_ranka() -> void:
	if not ranka_wanted():
		return
	if OS.has_feature("web"):
		if not await district.ensure("al2"):
			push_warning("仲間の絵 al2 を読めない: " + district.last_error)
			ranka_loaded.emit(false)
			return
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ranka/ranka.json"))
	if not (d is Dictionary):
		ranka_loaded.emit(false)
		return
	var a := RankaAlly.new()
	a.setup(battle, d)
	a.position = player.position + Vector3(-player.face * 2.3, 0, -0.75)
	battle.add_child(a)
	_boot("ranka_loaded")
	battle.ranka = a
	ranka_cutin = Cutin.new()   # 立ち絵 assets/ranka/cutin.webp（al2）、藍の帯・朱の線
	ranka_cutin.tex_path = "res://assets/ranka/cutin.webp"
	ranka_cutin.band_col = Color(0.03, 0.04, 0.14, 0.86)
	ranka_cutin.line_col = Color(0.93, 0.33, 0.18, 0.95)
	ranka_cutin.streak_col = Color(1.0, 0.85, 0.55, 0.38)
	ranka_cutin.flash_col = Color(1.0, 0.98, 0.94)
	add_child(ranka_cutin)
	ranka_loaded.emit(true)

func _check_town_edge() -> void:
	if town != "back" or player == null or town_floor_busy or player.locked or dungeon != null:
		return
	if hud == null or hud.menu_open or hud.slot_open:
		return
	var west_edge: bool = town_floor == "backtown" and player.position.x <= GamehallFloor.WEST_EXIT
	var east_edge: bool = town_floor == "gamehall" and player.position.x >= GamehallFloor.EAST_RETURN
	if not west_edge and not east_edge:
		town_edge_armed = true
		return
	if not town_edge_armed:
		return
	town_edge_armed = false
	if west_edge:
		town_floor_busy = true
		change_town_floor.call_deferred(true)
	elif east_edge:
		town_floor_busy = true
		change_town_floor.call_deferred(false)

func _abort_town_transition(old_mode: int, message: String) -> void:
	loading.error_text = message
	loading.hide_soon()
	player.locked = false
	battle.process_mode = old_mode
	town_floor_busy = false

func change_town_floor(enter_hall: bool) -> void:
	town_floor_busy = true
	town_edge_armed = false
	player.locked = true
	var old_mode: int = battle.process_mode
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	loading.show_now()
	loading.error_text = ""
	if enter_hall and not await district.ensure("gh1"):
		_abort_town_transition(old_mode, district.last_error)
		return
	for i in 3:
		await get_tree().process_frame
	if enter_hall:
		var assembled: Dictionary = GamehallFloor.build(self)
		if assembled.is_empty():
			_abort_town_transition(old_mode, "遊技場の画像を読み込めません")
			return
		town_floor = "gamehall"
		player.position = Vector3(21.5, 0, 0)
		player.face = -1
	else:
		build_backtown()
		town_floor = "backtown"
		player.position = Vector3(BT.ROOM_X.x + 1.5, 0, 0)
		player.face = 1
		bt_tex.erase("gamehall_approved_16m_preview")
	if is_instance_valid(battle.ally):
		battle.ally.position = player.position + Vector3(-1.4, 0, 0.7)
	if is_instance_valid(battle.ranka):
		battle.ranka.position = player.position + Vector3(-2.3, 0, -0.75)
	battle.auto_spawn = false
	battle.glints = glints
	_place_cam(true)
	await get_tree().process_frame
	loading.hide_soon()
	player.locked = false
	battle.process_mode = old_mode
	town_floor_busy = false
	print("TOWN_FLOOR_READY ", town_floor)

func _process(delta: float) -> void:
	if player == null:
		return   # 地区の読み込み中
	_place_cam(false, delta)
	_check_town_edge()
	_check_gate()
	if fx_demo >= 0.0:
		fx_demo -= delta
		if fx_demo <= 0.0:
			fx_demo = 1.0
			var wp := player.position + Vector3(player.face * 1.8, 1.1, 0.3)
			perf_last_fx = "fx%d@%dms" % [fx_demo_i % 4, Time.get_ticks_msec() - perf_t0]
			match fx_demo_i % 4:
				0: fx2d.hit(wp, player.face, false)
				1: fx2d.slash(wp, player.face, 1.4, -20.0, fx2d.BLUE)
				2: fx2d.hit(wp, player.face, true)
				3: fx2d.big(wp, fx2d.GOLD)
			fx_demo_i += 1
	if perf_on:
		_perf(delta)
	if battle:   # 大技の暗転：路面（StandardMaterial3D）は色で。ほかの背景はシェーダーの global uniform bg_dim
		for i in range(ground_mats.size() - 1, -1, -1):
			var gm = ground_mats[i]
			if not is_instance_valid(gm[0]):
				ground_mats.remove_at(i)
				continue
			gm[0].albedo_color = gm[1] * battle.bg_dim
	# 手前の板：ラナと重なったら半分ほど透ける
	for f in bt_fg:   # 裏の町の手前の柱（StandardMaterial3D）：ラナから左右 2.5m 以内で透ける
		var near: bool = absf(player.position.x - f.node.global_position.x) < f.half + 2.5
		var overpass: bool = f.get("overpass", false)
		if overpass:
			var post: Vector3 = f.node.global_position
			var eye := cam.global_position
			var hero := player.global_position
			# Project the line of sight onto the post's depth, including camera follow lag.
			var depth := inverse_lerp(eye.z, hero.z, post.z)
			near = absf(lerpf(eye.x, hero.x, depth) - post.x) < f.half + 0.38
		var cc: Color = f.mat.albedo_color
		cc.a = move_toward(cc.a, 0.3 if near else 1.0, delta * (7.5 if overpass else 3.0))
		f.mat.albedo_color = cc
	for f in fg_list:
		var over: bool = absf(player.position.x - (f.node.global_position.x)) < f.half + 2.5   # カメラを寄せたので広めに、薄く
		var col: Color = f.mat.get_shader_parameter("tint")
		var a: float = move_toward(col.a, 0.3 if over else 1.0, delta * 3.0)
		f.mat.set_shader_parameter("tint", Color(1, 1, 1, a))
	# 奥の歩道の人の流れ
	for c in crowd:
		var n: Sprite3D = c.node
		n.position.x += c.v * delta
		if n.position.x > 34.0: n.position.x = -34.0
		if n.position.x < -34.0: n.position.x = 34.0
		c.ph += delta * absf(c.v) * 5.5
		n.position.y = c.h * 0.5 + absf(sin(c.ph)) * 0.05

## 通りを横切る提灯の列：建物の前（z −6.3）から手前の歩道（z 5.2）へ張った綱に、1.4m おきに提灯。揺れる。
## 路面への映り込みは glints に足す（キャラの縁取り・染めにも効く）。
const LANTERN_X := [-6.2, 6.8, 17.0]
func _build_lanterns() -> void:
	var lm := ShaderMaterial.new()
	lm.shader = LANTERN_SHADER
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.06, 0.05, 0.05)
	rope.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in LANTERN_X:
		var z0 := -6.3
		var z1 := 5.2
		var segs := 12
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			var p0 := Vector3(x, 5.7 - 0.8 * 4.0 * t0 * (1.0 - t0), lerpf(z0, z1, t0))
			var p1 := Vector3(x, 5.7 - 0.8 * 4.0 * t1 * (1.0 - t1), lerpf(z0, z1, t1))
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 0.03, p0.distance_to(p1))
			seg.mesh = bm
			seg.material_override = rope
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(seg)
			seg.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP)
		var z := -5.4
		while z < 4.8:
			var t := (z - z0) / (z1 - z0)
			var y := 5.7 - 0.8 * 4.0 * t * (1.0 - t) - 0.42
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.46, 0.62)
			q.mesh = qm
			q.material_override = lm
			q.position = Vector3(x, y, z)
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(q)
			glints.append({"x": x, "y": y, "z": z, "w": 0.45, "col": [1.0, 0.32, 0.16], "p": 0.45, "len": 3.2, "k": 0.6})
			z += 1.4

## 奥の歩道の人の流れ：前作の町の人の絵を暗く・青紫に沈めて、左右へゆっくり流す（当たりには関係しない）。
func _build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 11:
		var key: String = NPC_KEYS[i % NPC_KEYS.size()]
		var tex: Texture2D = load("res://assets/npc/%s.webp" % key)
		var s := Sprite3D.new()
		s.texture = tex
		var h := rng.randf_range(1.6, 1.8)
		s.pixel_size = h / float(tex.get_height())
		var m := ShaderMaterial.new()
		m.shader = SPRITE_SHADER
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("tint", Color(0.2, 0.19, 0.3, 1.0))
		m.set_shader_parameter("bg_layer", 1.0)
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var v := rng.randf_range(0.7, 1.4) * (1.0 if i % 2 == 0 else -1.0)
		s.flip_h = v > 0.0
		s.position = Vector3(rng.randf_range(-32.0, 32.0), h * 0.5, rng.randf_range(-6.2, -4.7))
		level.add_child(s)
		crowd.append({"node": s, "v": v, "ph": rng.randf() * 6.0, "h": h})

func _build_vignette() -> void:
	if _q("vig=0"):
		return
	var cl := CanvasLayer.new()
	cl.layer = 0
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = VIGNETTE_SHADER
	r.material = m
	cl.add_child(r)
	add_child(cl)
	vignette_mat = m
	if fx:
		fx.screen_mat = m   # 衝撃波の画面のゆがみ

var vignette_mat: ShaderMaterial
## ダンジョンのテーマの色（絵が届くまでの仮置き）。a 0 で無し
func set_theme_tint(c: Color) -> void:
	if vignette_mat:
		vignette_mat.set_shader_parameter("theme_tint", c)

func _apply_cam_variant() -> void:
	cam_variant = OS.get_environment("CAMV")
	if town == "back" and cam_variant == "":
		cam_variant = "D2"   # 裏の町の下絵はカメラ D2 で作る（specs/backtown_blockout.md）
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("window.location.search"))
		for v in ["A", "B", "C", "D", "D2"]:   # D2 は D より後に見る（"cam=D" は "cam=D2" にも含まれるため）
			if q.contains("cam=" + v):
				cam_variant = v
	match cam_variant:
		"A":   # 帯を狭く：中心 z=0.15 のまわり ±1.02m（(8−奥)/(8−手前)=1.3）
			BELT_Z = Vector2(-0.87, 1.17)
		"B":   # 遠く・画角を狭く：帯の中心から 25.7m（(25.7+3.35)/(25.7−3.35)=1.3）。見下ろす角度は今と同じ 8.9°、中央のラナの大きさも同じ（見える高さ 5.21m）
			play_ofs = Vector3(0, 1.35 + 25.85 * 1.25 / 8.0, 25.85)
			play_fov = rad_to_deg(2.0 * atan(5.21 * 0.5 / 25.85))
		"D":   # A＋B（specs/camera_depth.md の案 D）：帯 4m（z −2〜2）、距離 15.3m・高さ 3.0m・縦 19.6°、見る点の高さ 1.70m（見下ろす 4.9°）。
			#   計算の目標：中央のラナ 35％、奥と手前の差 1.3 倍、建物の足元の線（z −6.5）が上から 65％（床 35％）、手前の足元が上から 90％
			BELT_Z = Vector2(-2.0, 2.0)
			play_ofs = Vector3(0, 3.0, 15.3)
			play_look = Vector3(0, 1.70, 0)
			play_fov = 19.6
		"D2":  # 案 D2（specs/camera_depth.md）：位置はほぼ D（距離 15.3m、高さ 3.0→3.2m）、画角を 19.6→16.8° に狭めて中央のラナを約 40％ に。
			#   見る点の高さ 1.50m（見下ろす 6.3°）。計算：中央 40.1％、帯の一番奥 上から 74.5％、一番手前 92.7％、建物の足元の線 61.9％
			BELT_Z = Vector2(-2.0, 2.0)
			play_ofs = Vector3(0, 3.2, 15.3)
			play_look = Vector3(0, 1.50, 0)
			play_fov = 16.8
		"C":   # 正投影：見える高さ 5.21m（中央のラナの大きさを今と同じに）
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = 5.21
	if cam_variant != "":
		print("CAMV %s belt=%s ofs=%s fov=%.2f" % [cam_variant, str(BELT_Z), str(play_ofs), play_fov])

func _cam_pos_for(x: float, ofs: Vector3 = CAM_OFS) -> Vector3:
	return Vector3(clampf(x, cam_x.x, cam_x.y), 0, 0) + ofs

func _place_cam(snap: bool, delta: float = 0.0) -> void:
	var fo0: Node3D = battle.cam_focus if battle and battle.cam_focus else player   # リリィの必殺技の間はリリィを追う
	var want := _cam_pos_for(fo0.position.x, play_ofs)
	var z: float = battle.cam_zoom if battle else 0.0
	if z > 0.0:   # 必殺技：ラナへ寄る（なめらかに）
		var zz := z * z * (3.0 - 2.0 * z)
		var fo: Node3D = battle.cam_focus if battle.cam_focus else player   # リリィの必殺技ではリリィへ寄る
		# 2026-11-12：キャラごとの顔の位置へ寄る（背の高さ・向きの違いで顔が切れていた）。顔を画面のやや上に
		var fp: Vector3 = fo.zoom_face() if fo.has_method("zoom_face") else fo.position + Vector3(0, 1.6, 0)
		var look := Vector3(fp.x, fp.y - ult_drop, fp.z)
		var near := look + Vector3(0, 0.22, ult_dist)
		cam.position = want.lerp(near, zz)
		var far_look := Vector3(cam.position.x, 0, 0) + play_look
		cam.look_at(far_look.lerp(look, zz), Vector3.UP)
	else:
		cam.position = want if snap else cam.position.lerp(want, minf(1.0, delta * 5.0))
		cam.look_at(Vector3(cam.position.x, 0, 0) + play_look, Vector3.UP)
	# 画面の揺れ（px 相当 → 画面の高さ 720px ≒ 8.8m）
	var sk: float = battle.shake * 0.012 if battle else 0.0
	cam.h_offset = randf_range(-1.0, 1.0) * sk
	cam.v_offset = randf_range(-1.0, 1.0) * sk * 0.7

# ---------- 見た目 ----------
func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b1730")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a86a8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# ネオン・灯りのにじみ（Compatibility でも効くことを確認済み。明るい所だけ）
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.1
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.78
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	if _q("glow3d=0"):
		env.glow_enabled = false
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _build_floor(width: float = 0.0, floor_tex: Texture2D = null) -> void:
	var street_width := 72.0 if town == "back" else 60.0
	if width > 0.0:   # ダンジョンの広い部屋（specs/dungeon_themes.md 3.1）
		street_width = width
	if floor_tex != null:   # テーマの床（1 枚の繰り返し。線路なし）
		# 奥の帯は建物の正面より奥（−7.6）まで敷く（足元のすき間から奥の地面の紫が線に見えた）
		# 板どうしは 0.1m 重ねる（歓楽街の床は 0.05m のすき間があり、奥の紫が横の線に見えている）
		for st in [[Vector3(0, 0.0, -4.8), Vector2(street_width, 5.6)], [Vector3(0, -0.03, 0.15), Vector2(street_width, 7.6)], [Vector3(0, 0.0, 5.55), Vector2(street_width, 3.3)]]:
			_ground(st[0], st[1], floor_tex, THEME_FLOOR_TILE, THEME_FLOOR_DIM)
		_far_ground_plane()
		return
	cobble_tex = load("res://assets/ground/cobble.png")
	slab_tex = load("res://assets/ground/slab.png")
	# 地面はコード（前作の教訓：AIの一枚絵は継ぎ目が苦手）。外部AIの継ぎ目の無い素材を繰り返して敷く。
	# 奥の歩道・帯（車道の石畳）・手前の歩道。キャラとエフェクトが沈まないよう暗めにする（FLOOR_DIM）。
	_ground(Vector3(0, 0.0, -5.2), Vector2(street_width, 3.0), slab_tex, SLAB_TILE)     # 奥の歩道
	_ground(Vector3(0, -0.03, 0.15), Vector2(street_width, 7.6), cobble_tex, COBBLE_TILE) # 帯（石畳の通り）
	_ground(Vector3(0, 0.0, 5.6), Vector2(street_width, 3.2), slab_tex, SLAB_TILE)      # 手前の歩道
	for z in [-1.2, 1.6]:   # 路面電車の線路（真鍮の細い線）
		var r := _slab(Vector3(0, -0.02, z), Vector3(street_width, 0.04, 0.06), Color("b8933f"))
		var rm: StandardMaterial3D = r.material_override
		rm.metallic = 0.6
		rm.roughness = 0.35
	_far_ground_plane()

## 奥の地面（建物の後ろ〜遠景の板）：奥ほど遠景の下端の霧の色（z_skyline の地平あたりの平均 ≈ #684c53）に溶ける
func _far_ground_plane() -> void:
	var fg_mi := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(160, 56)
	fg_mi.mesh = fpm
	fg_mi.position = Vector3(0, -0.04, -34.5)
	var fgm := ShaderMaterial.new()
	fgm.shader = FAR_GROUND_SHADER
	fgm.set_shader_parameter("fog_col", Color8(98, 72, 96))
	fg_mi.material_override = fgm
	level.add_child(fg_mi)

## 地面の素材は地区 d1 の pck に入る（本体には入れない）→ 読み込み後に load する
var cobble_tex: Texture2D
var slab_tex: Texture2D
const COBBLE_TILE := 2.5   # 石畳 1 枚の大きさ（m）
const THEME_FLOOR_TILE := 3.0   # テーマの床 1 枚（t2_g1 は石 4〜5 枚分）
const THEME_FLOOR_DIM := 0.75   # テーマの床の明るさ（t2_g1 は元から暗い。歓楽街の 0.3 だと模様が消えた）
const SLAB_TILE := 2.0     # 敷石 1 枚（石 1 枚が約 1m×0.5m）
const FLOOR_DIM := 0.3    # 地面の明るさ（素材の色に掛ける。夜。前は 0.5）
const GLINT_SHADER := preload("res://scripts/glint.gdshader")
const FAR_GROUND_SHADER := preload("res://scripts/far_ground.gdshader")
const FOOT_SHADER := preload("res://scripts/foot_shade.gdshader")
const FAR_PAINT_SHADER := preload("res://scripts/far_paint.gdshader")
const VIGNETTE_SHADER := preload("res://scripts/vignette.gdshader")
## 奥行き（2026-11-05）：奥ほど暗く・彩度を下げ・紫の霧。強さ＝遠景 ＞ 裏通り b0 ＞ 建物 b1〜b4 ＞ 路面。
const FOG_COL := Color8(97, 69, 102)
const FOG_FAR := 1.3
const FOG_BACK := 1.0
const FOG_BLD := 0.35
const BLD_DIM := 0.36       # 塗った建物の面の明るさ（夜。光る画素＝ネオン・灯り・明るい窓は暗くしない。前は 0.8）
const FG_BLUR := 5.0        # 手前の板のぼかし（テクスチャの画素）
const FG_DIM := 0.36       # 手前の板（光る画素は残す）
const LANTERN_SHADER := preload("res://scripts/lantern.gdshader")
const NPC_KEYS := ["man_1", "man_2", "man_3", "man_4", "woman_1", "woman_2", "woman_3", "woman_4", "work_1", "work_2", "work_3", "work_4"]
var crowd: Array = []      # 奥の歩道の人の流れ [{node, v, ph}]
var glints: Array = []
var fg_list: Array = []     # [{node, mat, half}]

func _ground(c: Vector3, size: Vector2, tex: Texture2D, tile: float, dim: float = FLOOR_DIM) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(dim * 0.97, dim * 0.94, dim * 1.04)   # ごく弱い紫（奥行きの霧の最弱）
	ground_mats.append([m, m.albedo_color])
	m.uv1_scale = Vector3(size.x / tile, size.y / tile, 1)
	m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.position = c
	level.add_child(mi)

## 濡れた路面の映り込み：assets/ground/glints.json（tools/make_glints.py が塗った絵から作る）の光ごとに、
## 建物の根元から手前へ、その色の筋を地面に寝かせて足す。高い所の光ほど筋が長く、強い光ほど明るい。
func _load_glints() -> void:
	var f := FileAccess.open("res://assets/ground/glints.json", FileAccess.READ)
	if f == null:
		return
	var list = JSON.parse_string(f.get_as_text())
	if list is Array:
		glints_src = list

func _build_glints() -> void:
	var list: Array = glints
	for g in list:
		var length: float = float(g.len) if g.has("len") else clampf(7.0 + float(g.y) * 0.8, 7.0, 12.0)
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(float(g.w) * 0.9, length)
		mi.mesh = pm
		mi.position = Vector3(float(g.x), 0.012, float(g.z) + length * 0.5)
		var m := ShaderMaterial.new()
		m.shader = GLINT_SHADER
		m.set_shader_parameter("col", Color(g.col[0], g.col[1], g.col[2]))
		m.set_shader_parameter("power", (0.55 + 1.0 * float(g.p)) * float(g.get("k", 1.0)))
		m.set_shader_parameter("stone", cobble_tex)
		m.set_shader_parameter("tile", COBBLE_TILE)
		m.set_shader_parameter("z0", float(g.z))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(mi)

func _slab(c: Vector3, s: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	mi.material_override = m
	mi.position = c
	level.add_child(mi)
	return mi

## ofs：同じ部品（同じ絵）を別の位置に置くときのずれ（使い回し）。key：その置き場所の名前（既定は部品の id）。
func _build_piece(p: Dictionary, ofs: Vector3 = Vector3.ZERO, key: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = p.id if key == "" else key
	root.position = ofs
	level.add_child(root)
	piece_nodes[root.name] = root
	var painted: Texture2D = _load_painted(p.id)
	if p.kind == "far" and painted != null:
		_build_far_plane(root, painted)
		return root
	if p.kind == "fg" and painted != null:
		root.position.z -= FG_PULL   # 遊ぶカメラを寄せたので、手前の板を帯のすぐ手前まで下げる（近すぎて画面をふさいだ）
		_build_fg_plane(root, p, painted)
		return root
	var has_alpha := painted != null and painted.get_image().detect_alpha() != Image.ALPHA_NONE
	for b in p.boxes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.position = b[0]
		var col: Color = City.MAT[b[2]]
		mi.set_meta("col", col)
		if painted != null and guide_meta.has(p.id):
			var sm := ShaderMaterial.new()
			sm.shader = PAINT_SHADER
			sm.set_shader_parameter("paint", painted)
			sm.set_shader_parameter("ref_vp", _proj_from(guide_meta[p.id].vp))
			sm.set_shader_parameter("fallback", col)
			sm.set_shader_parameter("alpha_mask", has_alpha)
			sm.set_shader_parameter("dim", BLD_DIM)
			sm.set_shader_parameter("glow_boost", 0.15)
			sm.set_shader_parameter("flicker", 1.0 if p.kind == "bld" else 0.0)
			sm.set_shader_parameter("fog_amt", FOG_BACK if p.kind == "back" else FOG_BLD)
			sm.set_shader_parameter("fog_col", FOG_COL)
			sm.set_shader_parameter("ofs", ofs)
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 塗った絵の部品は日光の影を落とさない（足元は _foot_shade）
		else:
			mi.material_override = _grey_mat(col, b[2])
		root.add_child(mi)
	if painted != null and p.kind == "bld":
		_foot_shade(root, p)

## 建物の足元の薄い暗がり：地面に接する箱の左右の範囲・正面から手前へ 1.6m、柔らかく薄れる板を置く。
	return root

func _foot_shade(root: Node3D, p: Dictionary) -> void:
	var x0 := INF
	var x1 := -INF
	var zf := -INF
	for b in p.boxes:
		if b[0].y - b[1].y * 0.5 > 0.05:
			continue
		x0 = minf(x0, b[0].x - b[1].x * 0.5)
		x1 = maxf(x1, b[0].x + b[1].x * 0.5)
		zf = maxf(zf, b[0].z + b[1].z * 0.5)
	if x0 == INF:
		return
	var depth := 1.6
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0 + 0.8, depth)
	mi.mesh = pm
	mi.position = Vector3((x0 + x1) * 0.5, 0.016, zf + depth * 0.5)
	var m := ShaderMaterial.new()
	m.shader = FOOT_SHADER
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 遠景：一枚絵を奥に立てた板（箱は使わない）。縦横比はそのまま。iPhone の横長（約2.17:1）でカメラが左右の端まで動いても
## 画面の上半分が切れない幅（z=-62 で約131m）。見えるのは絵の高さの約22％なので、ユーザー決定で「中の帯（塔の胴と窓）」が
## 見える高さに置く（絵の 470〜699 行目が、奥の街の地平 y≈-1.5 〜 画面の上端 y≈18 に来る）。
const FAR_Z := -62.0
const FAR_W := 136.0
const FAR_ROW_BOTTOM := 699.0   # 地平に合わせる絵の行（1024 行中）

func _build_far_plane(root: Node3D, tex: Texture2D) -> void:
	var w := FAR_W
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var px := h / float(tex.get_height())
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.position = Vector3(0, -1.6 + (FAR_ROW_BOTTOM - tex.get_height() * 0.5) * px, FAR_Z)
	var m := ShaderMaterial.new()
	m.shader = FAR_PAINT_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("fog_amt", FOG_FAR)
	m.set_shader_parameter("fog_col", FOG_COL)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## 手前の部品：背景を抜いた絵（key_soft）を、画面に正対する板として立てる（箱への投影は側面が伸びるのでやめた）。
## 足元＝地面、背の高さ＝箱のいちばん上。左右・奥行きは箱の中心。当たりには関係しない。
func _build_fg_plane(root: Node3D, p: Dictionary, tex: Texture2D) -> void:
	var top := 0.0
	var cx := 0.0
	var cz := 0.0
	for b in p.boxes:
		top = maxf(top, b[0].y + b[1].y * 0.5)
		cx += b[0].x
		cz += b[0].z
	cx /= p.boxes.size()
	cz /= p.boxes.size()
	var h := top
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.position = Vector3(cx, h * 0.5, cz)
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("blur", FG_BLUR)   # 表示のときだけぼかして暗く（元の絵は変えない）
	m.set_shader_parameter("night_dim", FG_DIM)
	m.set_shader_parameter("bg_layer", 1.0)
	m.set_shader_parameter("tint", Color(1, 1, 1, 1))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	fg_list.append({"node": mi, "mat": m, "half": w * 0.5})

func _grey_mat(col: Color, kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.8
	if kind.begins_with("neon") or kind == "light":
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.6
	return m

func _load_painted(id: String) -> Texture2D:
	var path := "res://art/painted/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_guide_meta() -> void:
	var f := FileAccess.open("res://art/guide/guide.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			guide_meta = d

func _proj_from(a: Array) -> Projection:
	return Projection(Vector4(a[0], a[1], a[2], a[3]), Vector4(a[4], a[5], a[6], a[7]),
		Vector4(a[8], a[9], a[10], a[11]), Vector4(a[12], a[13], a[14], a[15]))

# ---------- 下絵の書き出し ----------
func _piece_corners(p: Dictionary) -> Array:
	var pts := []
	for b in p.boxes:
		var c: Vector3 = b[0]
		var h: Vector3 = b[1] * 0.5
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					pts.append(c + Vector3(h.x * sx, h.y * sy, h.z * sz))
	return pts

func _capture_guides() -> void:
	ui.visible = false
	player.visible = false
	var dir := ProjectSettings.globalize_path("res://art/guide")
	DirAccess.make_dir_recursive_absolute(dir)
	var meta := {}
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var rc := Camera3D.new()
	vp.add_child(rc)
	var renv := Environment.new()
	renv.background_mode = Environment.BG_COLOR
	renv.background_color = MAGENTA
	renv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	renv.ambient_light_color = Color(1, 1, 1)
	renv.ambient_light_energy = 0.12
	renv.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	rc.environment = renv
	for c in crowd:
		c.node.visible = false
	var floor_nodes := []
	if gate:
		gate.visible = false
	for ch in level.get_children():
		if ch is MeshInstance3D:
			floor_nodes.append(ch)
	# CAPTURE_GUIDE=<部品のid> なら、その部品だけ撮り直す（ほかの下絵と guide.json の他の項目は変えない）
	var only := OS.get_environment("CAPTURE_GUIDE")
	if only == "1":
		only = ""
	if only != "":
		var gf := FileAccess.open(dir + "/guide.json", FileAccess.READ)
		if gf:
			var d = JSON.parse_string(gf.get_as_text())
			if d is Dictionary:
				meta = d
	for p in City.pieces():
		if p.boxes.is_empty() or (only != "" and p.id != only):
			continue
		for k in piece_nodes:
			piece_nodes[k].visible = (k == p.id)
		for fnode in floor_nodes:
			fnode.visible = false
		# 撮る位置：ゲームのカメラと同じ高さ・向き。左右は部品の中心（遠景は中央）
		var cx := 0.0
		var pts := _piece_corners(p)
		for q in pts:
			cx += q.x
		cx /= pts.size()
		var cpos := _cam_pos_for(cx if p.kind != "far" else 0.0)
		rc.transform = Transform3D(Basis(), cpos)
		rc.look_at(Vector3(cpos.x, 0, 0) + CAM_LOOK, Vector3.UP)
		var inv := rc.global_transform.affine_inverse()
		var tx0 := INF; var tx1 := -INF; var ty0 := INF; var ty1 := -INF
		for q in pts:
			var v: Vector3 = inv * q
			var d := -v.z
			tx0 = minf(tx0, v.x / d); tx1 = maxf(tx1, v.x / d)
			ty0 = minf(ty0, v.y / d); ty1 = maxf(ty1, v.y / d)
		var wr := tx1 - tx0
		var hr := ty1 - ty0
		var size := Vector2i(1536, 1024)
		if wr / hr < 0.83:
			size = Vector2i(1024, 1536)
		elif wr / hr < 1.2:
			size = Vector2i(1024, 1024)
		var asp := float(size.x) / size.y
		var m := 1.08
		var hh := maxf(hr, wr / asp) * m
		var n := 0.5
		vp.size = size
		rc.keep_aspect = Camera3D.KEEP_HEIGHT
		rc.set_frustum(hh * n, Vector2((tx0 + tx1) * 0.5 * n, (ty0 + ty1) * 0.5 * n), n, 400.0)
		rc.current = true
		for i in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(dir + "/%s.png" % p.id)
		var pr: Projection = rc.get_camera_projection() * Projection(rc.global_transform.affine_inverse())
		var arr := []
		for c in [pr.x, pr.y, pr.z, pr.w]:
			arr.append_array([c.x, c.y, c.z, c.w])
		meta[p.id] = {"w": size.x, "h": size.y, "vp": arr, "kind": p.kind}
		print("GUIDE ", p.id, " ", size)
	if only != "":
		var f1 := FileAccess.open(dir + "/guide.json", FileAccess.WRITE)
		f1.store_string(JSON.stringify(meta, " "))
		f1.close()
		print("GUIDE DONE (only ", only, ")")
		get_tree().quit()
		return
	# 全体の絵（画風を決める1枚）：ゲームのカメラ、中央、全部を表示
	for k in piece_nodes:
		piece_nodes[k].visible = true
	for fnode in floor_nodes:
		fnode.visible = true
	vp.size = Vector2i(1536, 1024)
	var cpos0 := _cam_pos_for(0.0)
	rc.transform = Transform3D(Basis(), cpos0)
	rc.look_at(Vector3(0, 0, 0) + CAM_LOOK, Vector3.UP)
	rc.projection = Camera3D.PROJECTION_PERSPECTIVE
	rc.keep_aspect = Camera3D.KEEP_WIDTH
	rc.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(CAM_FOV) * 0.5) * (16.0 / 9.0)))
	renv.background_color = Color("1b1730")
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(dir + "/key_full.png")
	var f := FileAccess.open(dir + "/guide.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, " "))
	f.close()
	print("GUIDE DONE")
	get_tree().quit()

## 地区を出る：その地区の絵で作った物を捨て、絵への参照を手放す（参照が無くなった絵は Godot が解放する）。
func release_district() -> void:
	if level:
		level.queue_free()
		level = null
	gate = null
	crowd.clear()
	piece_nodes.clear()
	fg_list.clear()
	bt_fg.clear()
	glints = []
	if battle:
		battle.glints = []
	cobble_tex = null
	slab_tex = null

## 解放の確認（DISTRICT_RELEASE_TEST=1）：絵の使うメモリを、捨てる前と後で出す
func _release_test() -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	var before := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	release_district()
	for i in 5:
		await RenderingServer.frame_post_draw
	var after := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	print("RELEASE TEST texture_mem before=%.1fMB after=%.1fMB" % [before / 1048576.0, after / 1048576.0])
	get_tree().quit()

# ---------- 使い回しの確認（CAPTURE_REUSE=1）----------
## 酒場 b1 を別の位置に置き、元の位置と「同じ相対位置のカメラ」で撮って captures/reuse_*.png に書き出す。
func _capture_reuse() -> void:
	var p: Dictionary = {}
	for q in City.pieces():
		if q.id == "b1_tavern":
			p = q
	var cases := {"ok": Vector3(40, 0, 0), "old": Vector3(40, 0, 0), "deep": Vector3(40, 0, -3), "near": Vector3(40, 0, 1.5)}
	var roots := {"orig": piece_nodes["b1_tavern"]}
	for k in cases:
		roots[k] = _build_piece(p, cases[k], "b1_" + k)
	# "old"＝ずれを引かない（これまでのシェーダーのまま置いた場合）
	for mi in roots["old"].get_children():
		if mi is MeshInstance3D and mi.material_override is ShaderMaterial:
			mi.material_override.set_shader_parameter("ofs", Vector3.ZERO)
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	for ch in get_children() + level.get_children():
		if ch == level:
			continue
		if ch is Node3D and ch != cam and not (ch is DirectionalLight3D) and not roots.values().has(ch):
			ch.visible = false
		elif ch is CanvasLayer:
			ch.visible = false
	set_process(false)
	var cx := -14.0
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	for k in ["orig", "ok", "old", "deep", "near"]:
		for r in roots:
			roots[r].visible = (r == k)
		var o: Vector3 = Vector3.ZERO if k == "orig" else cases[k]
		for rel in [-6.0, 0.0, 6.0]:
			var x: float = cx + o.x + float(rel)
			cam.position = Vector3(x, 0, 0) + CAM_OFS
			cam.look_at(Vector3(x, 0, 0) + CAM_LOOK, Vector3.UP)
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			for i in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir + "/reuse_%s_%d.png" % [k, int(rel)])
	print("REUSE DONE")
	get_tree().quit()

# ---------- 動作確認の撮影 ----------
## 決まった入力で戦闘を流し、3コマに1枚 captures/ へ書き出す（--fixed-fps 60 で起動すると毎回同じ）。
func _capture_play() -> void:
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	battle.auto_spawn = false
	player.position = Vector3(-2.0, 0, 0.6)
	_place_cam(true)
	var foes := [
		battle.spawn("1", Vector3(0.6, 0, 0.6)), battle.spawn("3", Vector3(1.6, 0, 1.2)),
		battle.spawn("1", Vector3(1.2, 0, -0.1)), battle.spawn("3", Vector3(-3.6, 0, 0.5)),
	]
	for e in foes:
		e.atk_cd = 9.0     # 最初はラナの攻撃を見るため、敵は攻撃しない
	# 新ラナ（2026-11-06）：A→B→C の連撃 → 長押しの回転斬り → 敵の攻撃（予兆→被弾）→ 回避（残像）→ 体力を減らしてダウン（土煙）→ 起き上がり
	var script := {6: "atk", 16: "atk", 30: "atk", 120: "hold_on", 150: "hold_off", 250: "foes", 330: "dodge", 380: "low"}
	for f in 560:
		if script.has(f):
			match script[f]:
				"atk": player.attack()
				"hold_on": player.attack_press()
				"hold_off": player.attack_release()
				"dodge": player.dodge()
				"low": battle.hp = 3.0
				"foes":
					for e in battle.enemies.duplicate():
						battle.remove_enemy(e)
					var a = battle.spawn("1", player.position + Vector3(1.05, 0, 0.05))
					var b = battle.spawn("3", player.position + Vector3(-1.1, 0, -0.1))
					b.atk_cd = 0.9
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if f % 3 == 0:
			get_viewport().get_texture().get_image().save_png(dir + "/play_%03d.png" % f)
	print("PLAY DONE")
	get_tree().quit()

## エフェクトの比較（CAPTURE_FX=1、前の見た目は FX_OLD=1 を足す）：同じ場面・同じ時刻で
## 斬撃（横の弧）・衝撃波（画面のゆがみ）・撃破（溶け消え）を撮る → captures/fx_<場面>_<コマ>.png
func _capture_fx() -> void:
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	battle.auto_spawn = false
	for e in battle.enemies.duplicate():
		battle.remove_enemy(e)
	if battle.ally:
		battle.ally.visible = false
		battle.ally.set_physics_process(false)
	player.position = Vector3(-1.5, 0, 0.8)
	player.debug_state("atk")
	_place_cam(true)
	var shots := {"slash": [2, 5, 9, 13], "wave": [3, 8, 14, 20], "kill": [6, 16, 26, 36]}
	var scenes := ["slash", "wave", "kill"]
	if OS.get_environment("FX_ONLY") != "":
		scenes = []
	for scene in scenes:
		var e = battle.spawn("3", Vector3(0.6, 0, 0.8))
		e.atk_cd = 99.0
		e.face = -1
		for f in 3:
			await get_tree().physics_frame
		match scene:
			"slash":
				fx.slash(player.position, 1, {"plane": "h", "r": 2.5, "w": 0.7, "a0": 110.0, "a1": -50.0, "y": 1.0, "life": 0.26, "draw": 0.07, "squash": 0.55, "tilt": 6.0})
			"wave":
				fx.shockwave(e.position + Vector3(0, 0.9, 0), 1.3)
			"kill":
				e.take_hit(99999.0, 1, false)
		var last: int = shots[scene][-1]
		for f in last + 1:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if f in shots[scene]:
				get_viewport().get_texture().get_image().save_png(dir + "/fx_%s_%02d.png" % [scene, f])
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		for f in 30:
			await get_tree().physics_frame
	if OS.get_environment("FX_ONLY") == "ult":
		await _capture_ult(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "lilyskill":
		await _capture_lily_skill(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "backtown":
		await _capture_backtown(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "camdepth":
		await _capture_camdepth(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "camcmp":
		await _capture_camcmp(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "vfxlab":
		await _capture_vfxlab(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "hitwin":
		await _capture_hitwin(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "overhaul":
		await _capture_overhaul(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "tree":
		await _capture_tree(dir)
		print("FX DONE")
		get_tree().quit()
		return
	if OS.get_environment("FX_ONLY") == "skill":
		await _capture_skill_fx(dir)
		print("FX DONE")
		get_tree().quit()
		return
	await _capture_lily_fx(dir)
	print("FX DONE")
	get_tree().quit()

## 必殺技（ゲージ満タン → 寄り・カットイン → 全体の多段 → 決め）→ captures/fx_ult_<n>.png
func _capture_ult(dir: String) -> void:
	player.visible = true
	player.set_physics_process(true)
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	player.position = Vector3(-1.0, 0, 0.6)
	player.face = 1
	_place_cam(true)
	for sp in [[2.0, 0.0], [3.6, 1.0], [-2.6, -0.8], [5.0, -1.2]]:
		var e = battle.spawn(["1", "3"][randi() % 2], player.position + Vector3(sp[0], 0, sp[1]))
		e.atk_cd = 99.0
	battle.ult = battle.ULT_MAX
	for f in 8:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/fx_ult_0.png")   # 満タン（ボタンとゲージ）
	player.use_ult()
	var marks := [0.15, 0.32, 0.75, 1.2, 1.5, 1.9, 2.22, 2.4]
	var n := 0
	for f in 160:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		if n < marks.size() and f >= int(marks[n] * 60.0):
			n += 1
			get_viewport().get_texture().get_image().save_png(dir + "/fx_ult_%d.png" % n)

## カメラの比較の重ね合わせ用（specs/camera_depth.md）：ラナを一番奥・中央・一番手前に（左右をずらして）立たせて 1 枚ずつ、
##   ラナを隠した背景の 1 枚も撮る → captures/cd_<案>_<back|mid|front|bg>.png。画面の座標（足元・頭・帯の線・建物の足元の線）を CDPOS で出す
func _capture_camdepth(dir: String) -> void:
	var tag := cam_variant if cam_variant != "" else "now"
	player.visible = true
	player.set_physics_process(false)
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	battle.auto_spawn = false
	if battle.ally:
		battle.ally.visible = false
		battle.ally.set_physics_process(false)
	var zs := {"back": BELT_Z.x, "mid": (BELT_Z.x + BELT_Z.y) * 0.5, "front": BELT_Z.y}
	var xs := {"back": -2.6, "mid": -0.6, "front": 1.4}
	player.position = Vector3(-0.6, 0, zs.mid)
	player.face = 1
	_place_cam(true)
	var cx := cam.position.x
	var keep_cam_x := cam_x
	cam_x = Vector2(cx - cam.position.x + _cam_pos_for(player.position.x, play_ofs).x, cx - cam.position.x + _cam_pos_for(player.position.x, play_ofs).x)   # 撮影の間はカメラを止める（ラナを動かしても背景がずれない）
	if ui:
		ui.visible = false
	var vh := get_viewport().get_visible_rect().size
	for key in ["back", "mid", "front"]:
		player.position = Vector3(cx + float(xs[key]), 0, float(zs[key]))
		player._show_frame("idle", 0)
		battle.apply_light(player.sprite, player.mat, player.refl, player.position)
		for f in 4:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/cd_%s_%s.png" % [tag, key])
		var foot := cam.unproject_position(player.position)
		var head := cam.unproject_position(player.position + Vector3(0, player.HEIGHT_M, 0))
		print("CDPOS %s %s %.4f %.4f %.4f" % [tag, key, foot.x / vh.x, foot.y / vh.y, head.y / vh.y])
	player.visible = false
	for f in 4:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/cd_%s_bg.png" % tag)
	for nm in [["belt_back", BELT_Z.x], ["belt_front", BELT_Z.y], ["bld", -6.5]]:
		var l := cam.unproject_position(Vector3(cx, 0, float(nm[1])))
		print("CDLINE %s %s %.4f" % [tag, nm[0], l.y / vh.y])
	player.visible = true
	cam_x = keep_cam_x
	if ui:
		ui.visible = true

## カメラの比較（specs/camera_depth.md）：一番奥・中央・一番手前で、同じ場面（ラナと敵、突きの当たり）→ captures/cam_<案>_<奥|中|手前>.png
func _capture_camcmp(dir: String) -> void:
	var tag := cam_variant if cam_variant != "" else "now"
	player.visible = true
	player.set_physics_process(true)
	if battle.ally:
		battle.ally.visible = false
		battle.ally.set_physics_process(false)
	battle.auto_spawn = false
	var zs := {"back": BELT_Z.x, "mid": (BELT_Z.x + BELT_Z.y) * 0.5, "front": BELT_Z.y}
	for key in ["back", "mid", "front"]:
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		var z: float = zs[key]
		player.position = Vector3(-1.0, 0, z)
		player.face = 1
		player.state = "move"
		player.inv = 99.0
		battle.freeze = 0.0
		_place_cam(true)
		var e = battle.spawn("3", Vector3(0.6, 0, z))
		e.atk_cd = 99.0
		e.face = -1
		e.hp_max = 9999.0
		e.hp = 9999.0
		for f in 4:
			await get_tree().physics_frame
		var foot := cam.unproject_position(player.position)
		var head := cam.unproject_position(player.position + Vector3(0, player.HEIGHT_M, 0))
		var vh := get_viewport().get_visible_rect().size.y
		var line := cam.unproject_position(Vector3(player.position.x, 0, -6.5))   # 建物の正面の足元（z −6.5）
		print("CAMH %s %s z=%.2f ラナの画面の高さ %.1f%%（足元 上から %.1f%%）／建物の足元の線 上から %.1f%%（床 %.1f%%）" % [tag, key, z, absf(foot.y - head.y) / vh * 100.0,
			foot.y / vh * 100.0, line.y / vh * 100.0, 100.0 - line.y / vh * 100.0])
		player._start_attack("atkA")
		var got := false
		for f in 40:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if not got and battle.freeze > 0.0:
				got = true
				for g in 3:
					await get_tree().physics_frame
					await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(dir + "/cam_%s_%s.png" % [tag, key])
		for f in 30:
			await get_tree().physics_frame
	player.inv = 0.0

## 共通シェーダーの素材を単体で撮る（向き・出方・消え方の確認）→ captures/lab_<名前>_<コマ>.png
func _capture_vfxlab(dir: String) -> void:
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	player.position = Vector3(-3.0, 0, 0.6)
	player.face = 1
	_place_cam(true)
	for f in 30:
		await get_tree().physics_frame
	var wp := player.position + Vector3(1.2, 1.1, 0.2)
	var tests := {"slashH": func(): fx2d.slash(wp, 1, 1.5, 0.0, fx2d.BLUE), "slashV": func(): fx2d.slash(wp, 1, 1.5, 25.0, fx2d.BLUE),
		"slashL": func(): fx2d.slash(wp, -1, 1.5, 0.0, fx2d.BLUE), "hit": func(): fx2d.hit(wp + Vector3(1.0, 0, 0), 1, false),
		"hitS": func(): fx2d.hit(wp + Vector3(1.0, 0, 0), 1, true), "kill": func(): fx2d.kill(wp + Vector3(1.0, -0.3, 0), fx, player.position + Vector3(2.2, 0, 0))}
	for name in tests:
		tests[name].call()
		for f in 37:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if f in [1, 3, 6, 10, 18, 36]:
				get_viewport().get_texture().get_image().save_png(dir + "/lab_%s_%02d.png" % [name, f])
		for f in 60:
			await get_tree().physics_frame

## 当たりの前 60ms〜後 600ms（specs/vfx_overhaul.md の 6）：毎コマ記憶して、当たりの瞬間を基準に選ぶ → captures/hw_<場面>_<ms>.png
##   基準：atkA＝最初の当たり（止めが始まったコマ）、技＝最後の強い当たり（止め 0.085 秒以上）、撃破＝敵が倒れ始めたコマ
const HW_MS := [-60, 0, 60, 150, 300, 600]
func _capture_hitwin(dir: String) -> void:
	player.visible = true
	player.set_physics_process(true)
	for id in ["atkA", "flurry", "rift", "vortex", "kill"]:
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		player.position = Vector3(-2.0 if id != "rift" else -4.5, 0, 0.6)
		player.face = 1
		player.state = "move"
		player.inv = 99.0
		battle.freeze = 0.0
		_place_cam(true)
		var spots := {"rift": [[1.6, 0.0], [3.8, -0.2], [6.2, 0.2]], "vortex": [[2.4, 0.9], [-2.6, -0.3], [1.8, -1.4]]}
		var foes := []
		for sp in spots.get(id, [[1.5, 0.0], [2.2, 0.5]]):
			var e = battle.spawn("3", player.position + Vector3(sp[0], 0, sp[1]))
			e.atk_cd = 99.0
			e.face = -1
			e.hp_max = 9999.0 if id != "kill" else 5.0
			e.hp = e.hp_max
			foes.append(e)
		for f in 4:
			await get_tree().physics_frame
		player.skill_cd.clear()
		match id:
			"atkA":
				player._start_attack("atkA")
			"kill":
				player._start_attack("atkB")
			_:
				player.use_skill(id)
		var frames := []
		var anchor := -1
		var prev_freeze := 0.0
		for f in 220:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			frames.append(get_viewport().get_texture().get_image())
			if anchor < 0:
				match id:
					"atkA":
						if battle.freeze > 0.0:
							anchor = f
					"kill":
						for e in foes:
							if is_instance_valid(e) and e.state == "dying":
								anchor = f
					_:
						if battle.freeze >= 0.085 and battle.freeze > prev_freeze:
							anchor = f
			prev_freeze = battle.freeze
			if anchor >= 0 and f >= anchor + 37:
				break
		if anchor < 0:
			print("HITWIN: 当たりが見つからない ", id)
			continue
		for ms in HW_MS:
			var k := clampi(anchor + int(round(ms / 1000.0 * 60.0)), 0, frames.size() - 1)
			frames[k].save_png(dir + "/hw_%s_%+04d.png" % [id, ms])
		print("HITWIN ", id, " 基準のコマ ", anchor)
		for f in 50:
			await get_tree().physics_frame
	player.inv = 0.0

## エフェクトの作り直し（specs/vfx_overhaul.md）：前後を同じ瞬間で撮る → captures/ov_<場面>_<n>.png
##   通常攻撃（A の突き・C の最後）、技3つ、撃破。開始からのコマ数で撮る（--fixed-fps 60）
func _capture_overhaul(dir: String) -> void:
	player.visible = true
	player.set_physics_process(true)
	var plan := [
		["atkA", [6, 9, 14]], ["atkC", [52, 56, 64]], ["flurry", [20, 46, 80]], ["rift", [20, 28, 40]], ["vortex", [22, 60, 84]], ["kill", [20, 28, 44]],
	]
	for pl in plan:
		var id: String = pl[0]
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		player.position = Vector3(-2.0 if id != "rift" else -4.5, 0, 0.6)
		player.face = 1
		player.state = "move"
		player.inv = 99.0
		_place_cam(true)
		var spots := {"rift": [[1.6, 0.0], [3.8, -0.2], [6.2, 0.2]], "vortex": [[2.4, 0.9], [-2.6, -0.3], [1.8, -1.4]]}
		for sp in spots.get(id, [[1.5, 0.0], [2.2, 0.5]]):
			var e = battle.spawn("3", player.position + Vector3(sp[0], 0, sp[1]))
			e.atk_cd = 99.0
			e.face = -1
			e.hp_max = 9999.0 if id != "kill" else 5.0
			e.hp = e.hp_max
		for f in 4:
			await get_tree().physics_frame
		player.skill_cd.clear()
		match id:
			"atkA", "atkC":
				player._start_attack(id)
			"kill":
				player._start_attack("atkB")
			_:
				player.use_skill(id)
		var marks: Array = pl[1]
		var n := 0
		for f in int(marks[-1]) + 1:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if n < marks.size() and f >= int(marks[n]):
				get_viewport().get_texture().get_image().save_png(dir + "/ov_%s_%d.png" % [id, n + 1])
				n += 1
		for f in 50:
			await get_tree().physics_frame
	player.inv = 0.0

## ラナのスキル3つ（specs/skill_ui.md）：溜め・頂点・余韻 → captures/fx_skill_<id>_<1|2|3>.png、右下の操作 → captures/ui_skill.png
func _capture_skill_fx(dir: String) -> void:
	player.visible = true
	player.set_physics_process(true)
	var at := {"flurry": [0.18, 0.75, 1.33], "rift": [0.3, 0.6, 0.85], "vortex": [0.35, 1.0, 1.4]}
	for id in ["flurry", "rift", "vortex"]:
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		player.position = Vector3(-2.0 if id != "rift" else -4.5, 0, 0.6)
		player.face = 1
		player.state = "move"
		_place_cam(true)
		# ラナからの相対位置（左右 m, 奥行き m）
		var spots := {"flurry": [[1.6, 0.0], [2.2, 0.5]], "rift": [[1.6, 0.0], [3.8, -0.2], [6.2, 0.2]], "vortex": [[2.4, 0.9], [-2.8, -0.3], [1.8, -1.4], [-1.6, 1.2]]}
		for sp in spots[id]:
			var e = battle.spawn("3", player.position + Vector3(sp[0], 0, sp[1]))
			e.atk_cd = 99.0
			e.hp_max = 999.0
			e.hp = 999.0
		for f in 3:
			await get_tree().physics_frame
		player.skill_cd.clear()
		player.use_skill(id)
		var marks: Array = at[id]
		var n := 0
		for f in int(marks[2] * 60.0) + 2:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if n < 3 and f >= int(marks[n] * 60.0):
				get_viewport().get_texture().get_image().save_png(dir + "/fx_skill_%s_%d.png" % [id, n + 1])
				n += 1
		for f in 40:
			await get_tree().physics_frame
	# 右下の操作：枠1 は待ち中（残り秒と外周の弧）、ほかは使える
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	player.skill_cd = {"flurry": 5.4, "rift": 0.0, "vortex": 0.0}
	for f in 6:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/ui_skill.png")
	hud.open_slots()
	hud.slot_pick = "vortex"
	for f in 6:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/ui_slots.png")
	hud.close_slots()

## スキルツリー（specs/skill_tree.md 5.、FX_ONLY=tree）：
##   ツリー画面（3人のタブ）→ captures/ui_tree_<char>.png
##   派生ごと（技レベル 3）に「最初の当たり・締めの当たり・余韻」の3枚 → captures/fx_deriv_<char>_<skill>_<deriv|base>_<1|2|3>.png
##   数字：技レベル1・5（元の技）と派生（Lv3）の、当たった数・ダメージの合計（TREE_STAT の行）
const TREE_SPOTS := {
	"flurry": [[1.6, 0.0], [2.2, 0.5], [5.2, 0.0]], "rift": [[1.6, 0.0], [3.8, -0.2], [6.2, 0.2], [4.5, 1.3], [9.5, 0.0], [8.0, -1.3]],
	"vortex": [[2.4, 0.9], [-2.8, -0.3], [1.8, -1.4], [-1.6, 1.2], [4.0, 0.0]],
	"rush": [[7.0, 0.3], [8.0, -0.4], [10.5, 1.0]], "barrage": [[1.3, 0.0], [1.9, 0.4], [3.4, -0.6]], "storm": [[2.4, 0.9], [-2.6, -0.3], [1.6, -1.4], [-1.5, 1.2], [3.6, 0.0], [6.5, 0.4]],
	"shot": [[4.0, 0.0], [6.5, 0.9], [7.5, -1.0]], "ring": [[2.4, 0.9], [-2.6, -0.3], [1.6, -1.4], [5.5, 0.4], [-6.0, -0.5]], "quake": [[2.4, 0.9], [-2.6, -0.3], [1.6, -1.4], [5.5, 0.4], [-6.5, 0.6]],
}
const TREE_CAM := {"rift": 4.5, "shot": 4.5, "rush": 4.5, "flurry": 2.0}   # 撮影のカメラの中心（技を出す位置から前へ m）
func _tree_demo(pr) -> void:   # 画面を見せるための仮の進み具合（撮影だけ。保存しない）
	pr.sp = {"rana": 4, "lily": 2, "ranka": 0}
	pr.skill_lv = {"rana": {"flurry": 3, "rift": 5, "vortex": 2, "ult": 1}, "lily": {"rush": 4, "barrage": 1, "storm": 3, "ult": 2}, "ranka": {"shot": 3, "ring": 1, "quake": 5, "ult": 3}}
	pr.deriv = {"rana": {"flurry": "iai", "rift": "enshin"}, "lily": {"rush": "rensa"}, "ranka": {"shot": "tame", "quake": "itten"}}

func _capture_tree(dir: String) -> void:
	progress.path = "user://sa2_capture_save.json"   # 撮影でセーブを変えない
	progress.reset()
	for w in 600:   # 仲間（al1・al2）を読み終えるまで待つ
		if battle.ally != null and battle.ranka != null:
			break
		await get_tree().physics_frame
	print("TREE 仲間 ", battle.ally != null, " ", battle.ranka != null)
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	player.visible = true
	player.set_physics_process(true)
	player.position = Vector3(-1.5, 0, 0.6)
	_place_cam(true)
	# 1) ツリー画面
	_tree_demo(progress)
	hud.open_slots()
	hud.slot_mode = "tree"
	for ch in ["rana", "lily", "ranka"]:
		hud.tree_ch = ch
		for f in 8:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/ui_tree_%s.png" % ch)
	hud.slot_mode = "slot"
	for f in 4:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/ui_tree_slotmode.png")
	hud.close_slots()
	progress.reset()
	# 2) 派生
	const ST := preload("res://scripts/skill_tree.gd")
	var cam_mark := Node3D.new()
	add_child(cam_mark)
	var only_ch: String = OS.get_environment("TREE_CH")
	for ch in ["rana", "lily", "ranka"]:
		if only_ch != "" and only_ch != ch:
			continue
		var actor: Node3D = player if ch == "rana" else (battle.ally if ch == "lily" else battle.ranka)
		if actor == null:
			print("TREE ", ch, " がいない")
			continue
		for a in [battle.ally, battle.ranka]:
			if a != null:
				a.visible = a == actor
				a.set_physics_process(a == actor)
				a.skills_on = false
				a.cd = 99.0
		for id in ST.order(ch):
			if id == "ult" or (OS.get_environment("TREE_SKILLS") != "" and not OS.get_environment("TREE_SKILLS").split(",").has(id)):
				continue
			var runs := [["base", 1, false], ["base", 5, false], ["base", 3, true]]
			for did in ST.rows(ch)[id].derivs:
				runs.append([did, 3, true])
			for run in runs:
				var did: String = run[0]
				progress.reset()
				progress.skill_lv = {ch: {id: run[1]}}
				if did != "base":
					progress.deriv = {ch: {id: did}}
				apply_progress()
				var tab: Dictionary = player.skills if ch == "rana" else actor.sk_tab
				var sk: Dictionary = tab[id]
				for x in battle.enemies.duplicate():
					battle.remove_enemy(x)
				var start := Vector3(-3.5 if id in ["rift", "rush", "shot"] else -1.0, 0, 0.5)
				actor.position = start
				actor.face = 1
				actor.state = "move"
				if ch != "rana":
					player.position = start + Vector3(-1.4, 0, 1.3)
					player.face = 1
				player.state = "move"
				# カメラ：遠くまで届く技は、当たる範囲が画面に入るよう前へずらす（撮影だけ）
				cam_mark.position = start + Vector3(TREE_CAM.get(id, 1.2), 0, 0)
				battle.cam_focus = cam_mark
				_place_cam(true)
				var first = null
				for sp in TREE_SPOTS[id]:
					var e = battle.spawn("3", start + Vector3(sp[0], 0, sp[1]))
					e.atk_cd = 99.0
					e.hp_max = 99999.0
					e.hp = 99999.0
					if first == null:
						first = e
				for f in 24:   # 出てきた時の白い光が消えるまで
					await get_tree().physics_frame
				battle.stat_hits = 0
				battle.stat_dmg = 0.0
				# 撮る時：最初の当たりを処理した直後・締め（最後の当たり）を処理した直後・その余韻（止めで技の時間が延びるので、時刻でなく当たりの番号で）
				var ev_all: Array = sk.ev
				var i_first := -1
				var i_last := -1
				for k in ev_all.size():
					if ev_all[k][1].has("k") and float(ev_all[k][1].k) > 0.0:
						if i_first < 0:
							i_first = k
						i_last = k
				var after := 0.35
				if did in ["kekkai", "rensa"]:
					after = 1.6 if did == "kekkai" else 1.0
				if ch == "rana":
					player.skill_cd.clear()
					player.use_skill(id)
				else:
					actor.sk_cd[id] = 0.0
					actor.force_skill(id, first)
				var n := 0
				var shoot: bool = run[2]
				var t_last := -1.0
				var tt := 0.0
				RenderingServer.render_loop_enabled = false   # 描くのは撮る瞬間だけ（ソフト描画は遅い。bot.gd と同じ）
				for f in 600:
					await get_tree().physics_frame
					tt += 1.0 / 60.0
					var done_i: int = int(player.hit_i) if ch == "rana" else int(actor.ev_i)
					var want := false
					if n == 0 and done_i > i_first:
						want = true
					elif n == 1 and done_i > i_last:
						want = true
					if t_last < 0.0 and done_i > i_last:
						t_last = tt
					if n == 2 and t_last >= 0.0 and tt >= t_last + after:
						want = true
					if want:
						if shoot:
							RenderingServer.render_loop_enabled = true
							await RenderingServer.frame_post_draw
							get_viewport().get_texture().get_image().save_png(dir + "/fx_deriv_%s_%s_%s_%d.png" % [ch, id, did, n + 1])
							RenderingServer.render_loop_enabled = false
						n += 1
					if n >= 3:
						break
				RenderingServer.render_loop_enabled = false
				for f in 90:   # 連鎖・結界の残りまで数える
					await get_tree().physics_frame
				RenderingServer.render_loop_enabled = true
				print("TREE_STAT %s %s %s Lv%d 当たった数 %d ダメージ合計 %d" % [ch, id, did, run[1], battle.stat_hits, int(battle.stat_dmg)])
				battle.lingers.clear()
				battle.cam_focus = null
				for f in 30:
					await get_tree().physics_frame
	progress.reset()

## リリィのスキル（2026-11-07）：技ごとに 3〜5 枚 → captures/fx_lskill_<id>_<n>.png
func _capture_lily_skill(dir: String) -> void:
	for w in 240:
		if battle.ally != null:
			break
		await get_tree().physics_frame
	var a = battle.ally
	if a == null:
		print("LILY SKILL: 仲間がいない")
		return
	a.visible = true
	a.set_physics_process(true)
	player.visible = true
	player.set_physics_process(true)
	var at := {"rush": [0.12, 0.25, 0.45], "barrage": [0.5, 0.9, 1.7, 1.85, 2.0], "storm": [0.47, 0.8, 1.18], "ult": [0.15, 0.75, 1.42, 2.0, 2.45, 2.7]}
	var spots := {"rush": [[7.0, 0.3], [8.0, -0.4]], "barrage": [[1.3, 0.0], [1.9, 0.4]], "storm": [[2.4, 0.9], [-2.6, -0.3], [1.6, -1.4], [-1.5, 1.2], [3.6, 0.0]],
		"ult": [[4.0, 0.2], [2.4, -1.0], [5.6, 1.0]]}
	for id in ["rush", "barrage", "storm", "ult"]:
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		a.position = Vector3(-3.0 if id == "rush" else -1.0, 0, 0.4)
		a.face = 1
		a.state = "move"
		a.cd = 99.0
		player.position = a.position + Vector3(-1.6, 0, 1.2)
		player.face = 1
		player.state = "move"
		_place_cam(true)
		var first = null
		for sp in spots[id]:
			var e = battle.spawn("3", a.position + Vector3(sp[0], 0, sp[1]))
			e.atk_cd = 99.0
			e.hp_max = 2999.0
			e.hp = 2999.0 if first == null else 999.0
			if first == null:
				first = e
		for f in 3:
			await get_tree().physics_frame
		if id == "ult":
			battle.ally_ult = battle.ULT_MAX
		a.force_skill(id, first)
		var marks: Array = at[id]
		var n := 0
		for f in int(marks[-1] * 60.0) + 2:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if n < marks.size() and f >= int(marks[n] * 60.0):
				get_viewport().get_texture().get_image().save_png(dir + "/fx_lskill_%s_%d.png" % [id, n + 1])
				n += 1
		print("LSKILL ", id, " 狙った敵の体力 ", first.hp, " / ほか ", battle.enemies.map(func(x): return int(x.hp)))
		for f in 50:
			await get_tree().physics_frame

## リリィの5本（specs/lily_attack_fx.md）：溜め・頂点・余韻を撮る → captures/fx_lily_<技>_<1〜3>.png
func _capture_lily_fx(dir: String) -> void:
	for w in 240:   # 仲間の絵（地区 pck al1）を読み終えるまで待つ
		if battle.ally != null:
			break
		await get_tree().physics_frame
	var a = battle.ally
	if a == null:
		print("LILY FX: 仲間がいない")
		return
	a.visible = true
	a.set_physics_process(true)
	player.visible = false
	for pat in ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush"]:
		for x in battle.enemies.duplicate():
			battle.remove_enemy(x)
		var rush: bool = pat == "atk_rush"
		player.position = Vector3(1.6 if rush else 0.4, 0, 0.8)
		_place_cam(true)
		a.position = Vector3(-1.2, 0, 0.8)
		var foes := []
		for ex in ([1.4, 3.6] if rush else [0.4]):   # 普通の技は 1.6m 先（当たる距離）
			var e = battle.spawn("3", Vector3(ex, 0, 0.8))
			e.atk_cd = 99.0
			e.face = -1
			foes.append(e)
		for f in 3:
			await get_tree().physics_frame
		a.force_attack(pat, foes[0])
		var c: Dictionary = a.data.clips[pat]
		var h: int = int(c.hits[c.hits.size() - 1])
		var hit_f: int = int(ceil(h / (float(c.fps) * a.SPD) * 60.0))
		var at := {hit_f - 4: 1, hit_f + 2: 2, hit_f + 15: 3}
		for f in hit_f + 16:
			await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			if at.has(f):
				get_viewport().get_texture().get_image().save_png(dir + "/fx_lily_%s_%d.png" % [pat.substr(4), at[f]])
		for f in 50:
			await get_tree().physics_frame

## 背の並べ比べ（CAPTURE_LINEUP=1）：ラナの待機と、リリィの構えを背の高さ違いで横に並べて撮る → captures/lineup_*.png
## 左から ラナ 1.85m ／ リリィ 1.80m（2026-11-06 決定）の構え・歩き・走り。もう1枚はリリィの攻撃の当たりのコマ。
func _capture_lineup() -> void:
	var dir := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	battle.auto_spawn = false
	for e in battle.enemies.duplicate():
		battle.remove_enemy(e)
	player.position = Vector3(-2.4, 0, 0.8)
	player.debug_state("idle")
	_place_cam(true)
	cam.position.x = 0.0
	cam.look_at(Vector3(0, 0, 0) + CAM_LOOK, Vector3.UP)
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lily/lily.json"))
	if battle.ally:
		battle.ally.queue_free()
		battle.ally = null
	var hs := [1.80, 1.80, 1.80]
	var lil := []
	for i in hs.size():
		var a := Ally.new()
		a.setup(battle, d)
		a.position = Vector3(-0.6 + i * 1.5, 0, 0.8)
		battle.add_child(a)
		a.set_height(hs[i])
		a.face = 1
		a.debug_pose(["idle", "walk", "run"][i], [0, 5, 4][i])
		lil.append(a)
	for f in 4:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/lineup_stand.png")
	# 当たりの瞬間（1.70m）：ジャブ・上段・回し蹴り・かかと落とし・飛び蹴り
	for a in lil:
		a.queue_free()
	player.position = Vector3(-8.6, 0, 0.8)
	var pats := ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush"]
	for i in pats.size():
		var a := Ally.new()
		a.setup(battle, d)
		a.position = Vector3(-6.2 + i * 2.4, 0, 0.8)
		battle.add_child(a)
		a.face = 1
		var c: Dictionary = d.clips[pats[i]]
		a.debug_pose(pats[i], int(c.hits[c.hits.size() - 1]))
	for f in 4:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/lineup_hits.png")
	print("LINEUP DONE")
	get_tree().quit()

# ---------- 場所の組み立て（街の区画／ダンジョンの部屋） ----------
func _clear_level() -> void:
	bt_fg.clear()
	ground_mats.clear()
	if level:
		remove_child(level)
		level.queue_free()
	level = Node3D.new()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	piece_nodes.clear()
	fg_list.clear()
	crowd.clear()
	glints = []
	gate = null

## 街の区画（縦切り1）
func build_city() -> void:
	_clear_level()
	_build_floor()
	for p in City.pieces():
		_build_piece(p)
	glints = glints_src.duplicate(true)
	_build_lanterns()
	_build_gate()
	_build_glints()
	_build_crowd()
	cam_x = CAM_X
	if battle:
		battle.glints = glints
		battle.ROOM_X = ROOM_X
	if player:
		player.room_x = ROOM_X

# ---------- 裏の町の入り口 v2（specs/backtown_entrance_v2.md の 13 章、2026-11-08） ----------
## 届いた絵（art/painted_bt）は絵の板、無い所は色の付いた下絵。下の帯は 0〜5m、出っ張りは平ら。
var bt_marks := []   # 撮影の書き込み用 [種類, 名前, 世界の位置]
var bt_tex := {}
var bt_surface_mats := {}
var bt_lights := []  # 床の映り込みの元 [絵/種類, x, y, z, 幅]
var bt_hang_rects := []    # 24章：吊り物 [名前, x0, y0, x1, y1, z]（ふさいでいないかの確かめ）
var bt_target_rects := []  # 24章：ふさいではいけない物 [名前, x0, y0, x1, y1, z]（扉・光る看板・屋台の天幕・路地の口・ビジョン）
var bt_fg := []      # 手前の物 [{node, mat, half}]（ラナから左右 2.5m 以内で透ける）
## 床の映り込みの色（光る部品・灯り・屋台）
const BT_GLINT_COL := {"sign_sigil": [0.35, 1.0, 0.5], "sign_vneon": [1.0, 0.3, 0.75], "sign_rune": [0.25, 0.9, 1.0], "vision_screen": [0.3, 0.85, 1.0],
	"pend_cyan": [0.3, 0.95, 1.0], "pend_violet": [0.8, 0.4, 1.0], "pend_green": [0.4, 1.0, 0.5], "pend_warm": [1.0, 0.72, 0.3],
	"stall": [1.0, 0.68, 0.32], "west_grill": [1.0, 0.65, 0.29], "west_crystal": [0.33, 0.78, 0.73], "cabaret_neon": [1.0, 0.3, 0.75], "cabaret_bulbs": [1.0, 0.88, 0.55], "gate": [0.75, 0.4, 1.0], "shady": [0.35, 1.0, 0.55], "tube": [0.35, 1.0, 0.55]}
const BT_ART_DIM := 0.62      # 届いた絵（壁・屋台・手前）の明るさ（U1＝中間：壁と床は暗め）
const BT_GLOW := 1.35         # 光る部品の明るさ（1 を超えて 3D の glow がにじむ）

func _bt_mat(key: String) -> StandardMaterial3D:
	if bt_surface_mats.has(key):
		return bt_surface_mats[key]
	var col: Color = BT.MAT[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 下絵は色の意味を見せる
	var surfaces := {"side": "tex_iron", "stone": "tex_brick", "brick": "tex_brick", "scaffold": "tex_iron",
		"iron": "tex_iron", "tin": "tex_iron", "wood": "tex_boards", "wood_dk": "tex_boards", "wood_lt": "tex_boards",
		"crate": "tex_boards", "brass": "tex_iron", "copper": "tex_iron", "cable": "tex_iron", "shadow": "tex_brick",
		"cloth": "tex_cloth", "cloth2": "tex_cloth", "awning": "tex_cloth", "white": "tex_cloth", "red": "tex_cloth", "linen": "tex_cloth"}
	if surfaces.has(key):
		m.albedo_texture = _bt_art(surfaces[key])
		m.albedo_color = Color(0.65, 0.65, 0.65) if key != "shadow" else Color(0.22, 0.22, 0.28)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / BT.TEX_M
		m.texture_repeat = true
	if key.begins_with("neon") or key in ["lamp", "bulb", "window", "curtain"]:
		m.albedo_color = col * (1.3 if key != "curtain" else 0.9)
	bt_surface_mats[key] = m
	return m

func _bt_box(parent: Node3D, c: Vector3, s: Vector3, key: String, mname: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.position = c
	mi.material_override = _bt_mat(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mname != "":
		mi.name = mname
	parent.add_child(mi)
	return mi

func _bt_art(name: String) -> Texture2D:
	if not bt_tex.has(name):
		var path: String = BT.ART + name + ".png"
		bt_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return bt_tex[name]

## 絵の板（正面向き、カメラに正対させない＝建物と同じ向き）。uv：絵の中の範囲 [u0,v0,u1,v1]（0〜1）。k＝明るさ
func _bt_quad(parent: Node3D, name: String, x0: float, y0: float, x1: float, y1: float, z: float, k: float = BT_ART_DIM, uv: Array = [0.0, 0.0, 1.0, 1.0], prio: int = 0) -> MeshInstance3D:
	var tex := _bt_art(name)
	if tex == null:
		return null
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(x1 - x0, y1 - y0)
	mi.mesh = qm
	mi.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(k, k, k, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if prio == 0 else BaseMaterial3D.TRANSPARENCY_ALPHA
	m.alpha_scissor_threshold = 0.5
	m.uv1_offset = Vector3(uv[0], uv[1], 0)
	m.uv1_scale = Vector3(uv[2] - uv[0], uv[3] - uv[1], 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.render_priority = prio
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## 横の壁の素材を実寸（1 枚＝TEX_M）で繰り返す板
func _bt_tex_wall(parent: Node3D, tex_name: String, x0: float, y0: float, x1: float, y1: float, z: float, k: float) -> void:
	var tex := _bt_art(tex_name)
	if tex == null:
		_bt_box(parent, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z), Vector3(x1 - x0, y1 - y0, 0.04), "stone")
		return
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(x1 - x0, y1 - y0)
	mi.mesh = qm
	mi.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, z)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(k, k, k, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.uv1_scale = Vector3((x1 - x0) / BT.TEX_M, (y1 - y0) / BT.TEX_M, 1)
	m.uv1_offset = Vector3(x0 / BT.TEX_M, 0, 0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

const BT_NPC_MOTION := preload("res://scripts/backtown_npc_motion.gdshader")
# center/radii, joint, travel, rotation, period, phase offset, upper-body sway
const BT_NPC_GESTURES := {
	"prosthesis_repair": [Vector4(0.86, 0.18, 0.23, 0.18), Vector2(0.82, 0.31), Vector2(-0.075, -0.044), -0.24, 3.6, 0.00, 0.008],
	"courtesan": [Vector4(0.80, 0.51, 0.32, 0.22), Vector2(0.72, 0.39), Vector2(-0.010, -0.050), -0.18, 4.2, 0.19, 0.009],
	"gambler": [Vector4(0.23, 0.29, 0.28, 0.14), Vector2(0.33, 0.34), Vector2(0.033, 0.016), 0.13, 3.5, 0.52, 0.007],
	"food_vendor": [Vector4(0.83, 0.31, 0.27, 0.19), Vector2(0.68, 0.37), Vector2(-0.046, 0.066), 0.24, 2.6, 0.34, 0.008],
	"apothecary": [Vector4(0.15, 0.16, 0.23, 0.18), Vector2(0.17, 0.23), Vector2(0.051, -0.046), 0.33, 3.7, 0.12, 0.008],
	"night_worker": [Vector4(0.78, 0.91, 0.24, 0.21), Vector2(0.70, 0.76), Vector2(0.025, -0.027), -0.13, 2.9, 0.27, 0.020],
	"drunk": [Vector4(0.09, 0.48, 0.26, 0.19), Vector2(0.24, 0.37), Vector2(0.026, -0.034), 0.13, 3.4, 0.64, 0.040],
}

# 店内の暖色、路地の青紫、遊技場の強い照明に合わせる初期値。
const BT_NPC_LOCAL_TINT := {
	"food_vendor": Color(0.93, 0.76, 0.62),
	"apothecary": Color(0.79, 0.72, 0.82),
	"prosthesis_repair": Color(0.72, 0.65, 0.60),
	"courtesan": Color(0.89, 0.68, 0.77),
	"gambler": Color(0.98, 0.88, 0.76),
	"night_worker": Color(0.60, 0.63, 0.76),
	"drunk": Color(0.83, 0.69, 0.60),
}

func _bt_npc(parent: Node3D, x: float, z: float, idx: int, preview_key: String = "", height_m: float = 1.72) -> void:
	var key: String = NPC_KEYS[idx % NPC_KEYS.size()] if preview_key.is_empty() else preview_key
	var tex: Texture2D = load("res://assets/npc/%s.webp" % key)
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = height_m / float(tex.get_height())
	if not preview_key.is_empty():
		s.name = preview_key
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER if preview_key.is_empty() else BT_NPC_MOTION
	m.set_shader_parameter("tex", tex)
	var tint: Color = BT_NPC_LOCAL_TINT.get(preview_key, Color(0.42, 0.38, 0.5))
	m.set_shader_parameter("tint", tint)
	if preview_key.is_empty():
		m.set_shader_parameter("bg_layer", 1.0)
	else:
		var gesture: Array = BT_NPC_GESTURES[preview_key]
		m.set_shader_parameter("region", gesture[0])
		m.set_shader_parameter("joint", gesture[1])
		m.set_shader_parameter("travel", gesture[2])
		m.set_shader_parameter("turn", gesture[3])
		m.set_shader_parameter("period", gesture[4])
		m.set_shader_parameter("phase_offset", gesture[5])
		m.set_shader_parameter("sway", gesture[6])
		m.set_shader_parameter("aspect", float(tex.get_width()) / float(tex.get_height()))
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.flip_h = preview_key.is_empty() and idx % 2 == 0
	s.position = Vector3(x, height_m * 0.5, z)
	parent.add_child(s)

func _bt_start_patrol(walker: Sprite3D, east: float) -> void:
	var frames: Array[Texture2D] = []
	for index in 4:
		var frame := load("res://assets/npc/night_worker_walk_%d.webp" % index) as Texture2D
		if frame == null:
			return
		frames.append(frame)
	var material := walker.material_override as ShaderMaterial
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("tint", BT_NPC_LOCAL_TINT["night_worker"])
	material.set_shader_parameter("bg_layer", 1.0)
	walker.texture = frames[0]
	material.set_shader_parameter("tex", frames[0])
	walker.pixel_size = walker.position.y * 2.0 / float(frames[0].get_height())
	var west := walker.position.x
	var duration := (east - west) / 1.35
	var move := func(x: float, going_left: bool) -> void:
		var distance := east - x if going_left else x - west
		var frame := frames[int(distance * 6.0 / 1.35) % frames.size()]
		walker.position.x = x
		walker.flip_h = going_left
		if walker.texture != frame:
			walker.texture = frame
			material.set_shader_parameter("tex", frame)
	var patrol := walker.create_tween().set_loops()
	patrol.tween_method(move.bind(false), west, east, duration)
	patrol.tween_interval(0.35)
	patrol.tween_method(move.bind(true), east, west, duration)
	patrol.tween_interval(0.35)

## 24章：吊るす所 → [上端の y, z]（綱は BT.ROPES、軒・手すりは BT.ANCHORS）
func _bt_anchor(id: String) -> Array:
	if BT.ROPES.has(id):
		return [BT.ROPES[id].y, BT.ROPES[id].z]
	return [BT.ANCHORS[id][0], BT.ANCHORS[id][1]]

## ---- 22章：小屋の形の部品（色の付いた下絵） ----
## 板：[x0, y0, x1, y1, 前の面の z, 素材, 奥行き(既定 0.03)]
func _bt_plate(parent: Node3D, b: Array) -> MeshInstance3D:
	var d: float = b[6] if b.size() > 6 else 0.03
	return _bt_box(parent, Vector3((b[0] + b[2]) * 0.5, (b[1] + b[3]) * 0.5, b[4] - d * 0.5), Vector3(b[2] - b[0], b[3] - b[1], d), b[5])

## 傾いた屋根・庇：[x0, x1, 奥の y, 奥の z, 前の y, 前の z, 素材]。前の縁に暗い線
func _bt_roof(parent: Node3D, r: Array) -> void:
	var dz: float = r[5] - r[3]
	var dy: float = r[2] - r[4]
	var L := sqrt(dz * dz + dy * dy)
	var mi := _bt_box(parent, Vector3((r[0] + r[1]) * 0.5, (r[2] + r[4]) * 0.5, (r[3] + r[5]) * 0.5), Vector3(r[1] - r[0], 0.05, L), r[6])
	mi.rotation.x = atan2(dy, dz)
	_bt_box(parent, Vector3((r[0] + r[1]) * 0.5, r[4] - 0.04, r[5]), Vector3(r[1] - r[0], 0.08, 0.04), "shadow")

## 手すり：[x0, x1, 下の y, 上の y, z, 素材]。上下の横木と 0.22m おきの縦の棒
func _bt_rail(parent: Node3D, rl: Array) -> void:
	var x0: float = rl[0]
	var x1: float = rl[1]
	var z: float = rl[4]
	_bt_box(parent, Vector3((x0 + x1) * 0.5, rl[2] + 0.05, z), Vector3(x1 - x0, 0.1, 0.05), rl[5])
	_bt_box(parent, Vector3((x0 + x1) * 0.5, rl[3] - 0.15, z), Vector3(x1 - x0, 0.07, 0.05), rl[5])
	var x := x0 + 0.05
	while x < x1:
		_bt_box(parent, Vector3(x, (rl[2] + rl[3]) * 0.5, z), Vector3(0.04, rl[3] - rl[2], 0.04), rl[5])
		x += 0.22

## 外階段：[下の x, 上の x, 上の y, 前の z, 奥行き, 段数]
func _bt_stairs(parent: Node3D, s2: Array) -> void:
	var n: int = s2[5]
	for i in n:
		var xa: float = lerpf(s2[0], s2[1], float(i) / n)
		var xb: float = lerpf(s2[0], s2[1], float(i + 1) / n)
		var yt: float = s2[2] * float(i + 1) / n
		_bt_box(parent, Vector3((xa + xb) * 0.5, yt - 0.06, s2[3] - s2[4] * 0.5), Vector3(absf(xb - xa) + 0.02, 0.12, s2[4]), "wood_lt")   # 24章：明るい木
		_bt_box(parent, Vector3((xa + xb) * 0.5, (yt - 0.12) * 0.5, s2[3] - s2[4] * 0.5 - 0.1), Vector3(absf(xb - xa) + 0.02, maxf(0.01, yt - 0.12), 0.02), "wood")   # 24章：段の下を暗い影から木に（後ろの明るい地と分ける）
		_bt_box(parent, Vector3((xa + xb) * 0.5, yt - 0.135, s2[3] + 0.005), Vector3(absf(xb - xa) + 0.02, 0.03, 0.02), "shadow")   # 段の縁の影の線
	for i in range(0, n + 1, 2):   # 手すりの柱
		var xs: float = lerpf(s2[0], s2[1], float(i) / n)
		var ys: float = s2[2] * float(i) / n
		_bt_box(parent, Vector3(xs, ys + 0.45, s2[3] + 0.02), Vector3(0.05, 0.9, 0.05), "wood_lt")
	for i in n:   # 24章：手すりの横木（段ごとの短い棒で斜めに見せる）
		var xa2: float = lerpf(s2[0], s2[1], float(i) / n)
		var xb2: float = lerpf(s2[0], s2[1], float(i + 1) / n)
		_bt_box(parent, Vector3((xa2 + xb2) * 0.5, s2[2] * (i + 0.5) / n + 0.9, s2[3] + 0.02), Vector3(absf(xb2 - xa2) + 0.03, 0.06, 0.04), "wood_lt")

## 円柱（樽・釜・ガラス管）
func _bt_cyl(parent: Node3D, x: float, y0: float, z: float, r: float, h: float, key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	mi.mesh = cm
	mi.position = Vector3(x, y0 + h * 0.5, z)
	mi.material_override = _bt_mat(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## 樽：胴と2本のたが。k＝明るさ（手前の物は暗く）
func _bt_barrel(parent: Node3D, x: float, y0: float, z: float, r: float, h: float, k: float = 1.0) -> void:
	var parts := [_bt_cyl(parent, x, y0, z, r, h, "crate")]
	for f in [0.2, 0.78]:
		parts.append(_bt_cyl(parent, x, y0 + h * f, z, r + 0.015, 0.06, "iron"))
	if k < 1.0:
		for mi in parts:
			var m: StandardMaterial3D = mi.material_override.duplicate()
			mi.material_override = m
			m.albedo_color = m.albedo_color * k

func _bt_shack(root: Node3D, sg: Dictionary) -> void:
	for b in sg.get("boxes", []):
		_bt_plate(root, b)
	for r in sg.get("roofs", []):
		_bt_roof(root, r)
	for rl in sg.get("rails", []):
		_bt_rail(root, rl)
	for s2 in sg.get("stairs", []):
		_bt_stairs(root, s2)
	for sh in sg.get("silh", []):   # 24章：カーテン越しの人影（全身。頭・肩と胴・裾の広い服）
		var hx: float = sh[0]
		var fy: float = sh[1]
		var hgt: float = sh[2]
		var hz := BT.WALL_Z + 0.06
		_bt_box(root, Vector3(hx, fy + hgt * 0.9, hz), Vector3(hgt * 0.16, hgt * 0.18, 0.01), "silh")
		_bt_box(root, Vector3(hx, fy + hgt * 0.66, hz), Vector3(hgt * 0.3, hgt * 0.3, 0.01), "silh")
		_bt_box(root, Vector3(hx, fy + hgt * 0.27, hz), Vector3(hgt * 0.4, hgt * 0.54, 0.01), "silh")
		bt_marks.append(["chk", "silh_head", Vector3(hx, fy + hgt, hz)])
		bt_marks.append(["chk", "silh_foot", Vector3(hx, fy, hz)])
	for r in sg.get("roofs", []):   # 24章：軒・天幕の前の縁（画面に映るかの確かめ）
		bt_marks.append(["eave", sg.id, Vector3((r[0] + r[1]) * 0.5, r[4], r[5])])
		bt_marks.append(["fix", "3", Vector3((r[0] + r[1]) * 0.5, (r[2] + r[4]) * 0.5, (r[3] + r[5]) * 0.5)])
	for pt in sg.get("parts", []):   # 24章：2階の窓・ネオン（3.0m より上）の上端
		if pt[1] >= 3.0 and pt[4] in ["window", "curtain", "neon_p", "neon_g"]:
			bt_marks.append(["chk", "win2f_top:" + pt[4], Vector3((pt[0] + pt[2]) * 0.5, pt[3], BT.WALL_Z)])
			bt_marks.append(["win2f", sg.id, Vector3((pt[0] + pt[2]) * 0.5, pt[3], BT.WALL_Z)])
			bt_marks.append(["fix", "2", Vector3((pt[0] + pt[2]) * 0.5, (pt[1] + pt[3]) * 0.5, BT.WALL_Z)])
	for c in sg.get("cyls", []):
		if c[5] == "crate":
			_bt_barrel(root, c[0], c[1], c[2], c[3], c[4])
		else:
			_bt_cyl(root, c[0], c[1], c[2], c[3], c[4], c[5])
	if sg.id == "n1_tavern":   # 床の映り込み：奥の戸口・棚の灯り
		bt_lights.append(["stall", -5.45, 1.2, -6.3, 1.0])
		bt_lights.append(["pend_warm", -9.3, 1.9, -6.3, 2.0])

## 屋台風の飲み屋・吊り布・ガラス管・歯車・ネオンの置き場所（22章）
func _bt_extras(st: Node3D, finished: bool) -> void:
	var ex := Node3D.new()
	ex.name = "extras22"
	st.add_child(ex)
	var z: float = BT.SBAR_Z
	for sb in BT.STREET_BARS:
		var g := Node3D.new()
		g.name = sb.id
		ex.add_child(g)
		var x: float = sb.x
		if sb.id == "sbar_a":   # 24章：A の移動先の案（SBAR_A_X で別の案を撮る。未決）
			if OS.get_environment("SBAR_A_X") != "":
				x = float(OS.get_environment("SBAR_A_X"))
			for ai in BT.SBAR_A_PEOPLE.size():
				var ap: Array = BT.SBAR_A_PEOPLE[ai]
				_bt_npc(st, x + ap[0], ap[1], 3 + ai * 4)
				bt_marks.append(["person", ap[2], Vector3(x + ap[0], 1.9, ap[1])])
			bt_marks.append(["fix", "4", Vector3(x, 1.6, z)])
		var sw: float = sb.w
		var hw: float = sw * 0.5
		if _bt_art(sb.id) != null:
			_bt_quad(g, sb.id, x - hw - 0.15, 0.0, x + hw + 0.15, 2.6, z + 0.26)
			bt_lights.append(["stall", x, 2.0, z, sw * 0.6])
			continue
		_bt_box(g, Vector3(x, 0.52, z), Vector3(sw, 1.04, 0.05), "wood")                  # 立ち飲みのカウンター
		_bt_box(g, Vector3(x, 1.08, z - 0.15), Vector3(sw + 0.1, 0.08, 0.4), "brass")     # 天板
		_bt_box(g, Vector3(x, 1.5, z - 0.75), Vector3(sw - 0.2, 0.9, 0.02), "bottle")    # 奥の小さな酒瓶の棚
		for sx in [x - hw + 0.06, x + hw - 0.06]:
			_bt_box(g, Vector3(sx, 1.15, z + 0.1), Vector3(0.08, 2.3, 0.08), "wood")        # 柱
			_bt_box(g, Vector3(sx, 1.25, z - 0.8), Vector3(0.08, 2.5, 0.08), "wood")
		_bt_roof(g, [x - hw - 0.15, x + hw + 0.15, 2.55, z - 0.9, 2.28, z + 0.25, sb.cloth])   # 布の屋根
		_bt_box(g, Vector3(x, 2.05, z - 0.2), Vector3(0.22, 0.22, 0.05), "lamp")            # 吊るした灯り
		_bt_barrel(g, x - hw * 0.45, 0.0, z + 0.7, 0.28, 0.95)                               # 樽のテーブル
		if sw > 1.9:
			_bt_barrel(g, x + hw * 0.55, 0.0, z + 0.75, 0.26, 0.9)
		bt_marks.append(["streetbar", sb.id, Vector3(x, 2.4, z)])
		bt_hang_rects.append(["sbar_roof:" + sb.id, x - hw - 0.15, 2.28, x + hw + 0.15, 2.55, z + 0.25])
		bt_lights.append(["stall", x, 2.0, z, sw * 0.6])
	for c in BT.CLOTHS:   # 吊り布（24章：手すりに掛けるか綱から。下の端に切れ込み＝短い布 2 枚）
		if finished and c[4] == "rope_cb" and _bt_art("market_cloth_cream") != null:
			continue
		if (c[4] == "rail_cabaret" and _bt_art("w_cabaret") != null) or (c[4] == "rail_brothel" and _bt_art("w_brothel") != null) or (c[4] == "rail_shady" and _bt_art("w_shady") != null):
			continue   # 納品画に装飾を焼き込み済み。仮の色面を重ねない。
		var ay: Array = _bt_anchor(c[4])
		var top: float = ay[0]
		var cz: float = ay[1] + 0.05
		var w: float = c[1]
		var d: float = c[2]
		_bt_box(ex, Vector3(c[0], top - d * 0.4, cz), Vector3(w, d * 0.8, 0.02), c[3])
		_bt_box(ex, Vector3(c[0] - w * 0.25, top - d * 0.9, cz), Vector3(w * 0.45, d * 0.2, 0.02), c[3])
		_bt_box(ex, Vector3(c[0] + w * 0.25, top - d * 0.9, cz), Vector3(w * 0.45, d * 0.2, 0.02), c[3])
		bt_hang_rects.append(["cloth:" + c[3] + "@" + c[4], c[0] - w * 0.5, top - d, c[0] + w * 0.5, top, cz])
	for t in BT.TUBES:   # 緑に光るガラス管（真鍮の口金）
		var painted_glass := _bt_art("pend_green")
		if painted_glass != null:
			var glass_w: float = t[4] * float(painted_glass.get_width()) / float(painted_glass.get_height())
			_bt_quad(ex, "pend_green", t[0] - glass_w * 0.5, t[1], t[0] + glass_w * 0.5, t[1] + t[4], t[2] + 0.2, BT_GLOW)
			bt_lights.append(["tube", t[0], t[1] + t[4] * 0.5, t[2], 0.5])
			continue
		_bt_cyl(ex, t[0], t[1], t[2], t[3], t[4], "glass_g")
		_bt_cyl(ex, t[0], t[1] - 0.18, t[2], t[3] + 0.05, 0.2, "brass")
		_bt_cyl(ex, t[0], t[1] + t[4] - 0.02, t[2], t[3] + 0.05, 0.2, "brass")
		bt_marks.append(["tube", "glass_tube", Vector3(t[0], t[1] + t[4] * 0.5, t[2])])
		bt_lights.append(["tube", t[0], t[1] + t[4] * 0.5, t[2], 0.5])
	for gr in BT.GEARS:   # 歯車の大きな輪（輪・歯・スポーク・軸）
		var r: float = gr[3]
		var gp := Vector3(gr[0], gr[1], gr[2])
		var tm := TorusMesh.new()
		tm.inner_radius = r * 0.82
		tm.outer_radius = r
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.position = gp
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3(1, 0.2, 1)
		ring.material_override = _bt_mat("brass")
		ex.add_child(ring)
		for i in 14:
			var a := TAU * i / 14.0
			var tooth := _bt_box(ex, gp + Vector3(cos(a), sin(a), 0) * (r + 0.05), Vector3(0.1, 0.12, 0.04), "brass")
			tooth.rotation.z = a
		for i in 3:
			var sp := _bt_box(ex, gp, Vector3(r * 1.7, 0.07, 0.03), "copper")
			sp.rotation.z = PI * i / 3.0
		var hub := _bt_cyl(ex, gp.x, gp.y - 0.06, gp.z + 0.05, 0.12, 0.12, "iron")
		hub.rotation.x = PI * 0.5
		bt_marks.append(["gear", "gear_wheel", gp])
	for ns in BT.NEON_SLOTS:   # 光るネオンの置き場所（枠だけ。光らせない＝看板の数に入れない）
		var source_art: String = {"neon_liquor_tavern": "w_bar", "neon_woman_brothel": "w_brothel", "neon_liquor_sbar_b": "sbar_b"}.get(ns[0], "")
		if source_art != "" and _bt_art(source_art) != null:
			continue   # 納品画に看板が含まれる。未読込時だけ仮パネルを残す。
		var x0: float = ns[1]
		var y0: float = ns[2]
		var x1: float = ns[3]
		var y1: float = ns[4]
		var nz: float = ns[5]
		_bt_box(ex, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, nz - 0.01), Vector3(x1 - x0, y1 - y0, 0.01), "dark")
		for e in [[x0, y0, x1, y0 + 0.04], [x0, y1 - 0.04, x1, y1], [x0, y0, x0 + 0.04, y1], [x1 - 0.04, y0, x1, y1]]:
			_bt_box(ex, Vector3((e[0] + e[2]) * 0.5, (e[1] + e[3]) * 0.5, nz), Vector3(e[2] - e[0], e[3] - e[1], 0.02), "slot")
		bt_marks.append(["slot", ns[0], Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, nz)])
		for cpt in [Vector3(x0, y1, nz), Vector3(x1, y1, nz), Vector3(x0, y0, nz), Vector3(x1, y0, nz)]:
			bt_marks.append(["chk", "slot_corner:" + ns[0], cpt])
		bt_target_rects.append(["slot:" + ns[0], x0, y0, x1, y1, nz])

func _bt_hanging_run(parent: Node3D, cable: PackedVector2Array, z: float, lamps: Array, laundry: Array = []) -> void:
	for i in range(1, cable.size()):
		var span := cable[i] - cable[i - 1]
		var midpoint := (cable[i] + cable[i - 1]) * 0.5
		var wire := _bt_box(parent, Vector3(midpoint.x, midpoint.y, z), Vector3(span.length() + 0.012, 0.026, 0.024), "cable")
		wire.rotation.z = span.angle()
	for anchor in [cable[0], cable[-1]]:
		_bt_box(parent, Vector3(anchor.x, anchor.y, (BT.WALL_Z + z) * 0.5), Vector3(0.065, 0.065, z - BT.WALL_Z), "iron")
	for mount in lamps + laundry:
		var joint := cable[int(mount[0])]
		var art: String = mount[1]
		var width: float = mount[2]
		var drop: float = mount[3]
		var tex := _bt_art(art)
		if tex == null:
			continue
		var height := width * float(tex.get_height()) / float(tex.get_width())
		var top := joint.y - drop
		var brightness := 0.92 if art.begins_with("market_lamp") else 0.58
		_bt_quad(parent, art, joint.x - width * 0.5, top - height, joint.x + width * 0.5, top, z + 0.02, brightness)
		if drop > 0.0:
			_bt_box(parent, Vector3(joint.x, joint.y - drop * 0.5, z), Vector3(0.021, drop + 0.02, 0.02), "cable")

func _bt_market_overhead(parent: Node3D) -> void:
	var hang := Node3D.new()
	hang.name = "market_overhead"
	parent.add_child(hang)
	# The alley openings stay clear. Laundry belongs to the tavern and the lodging.
	_bt_hanging_run(hang, PackedVector2Array([
		Vector2(-24.7, 3.62), Vector2(-23.45, 3.42), Vector2(-22.03, 3.27),
		Vector2(-20.5, 3.20), Vector2(-18.96, 3.24), Vector2(-17.38, 3.39), Vector2(-15.18, 3.72),
	]), -4.72, [[1, "market_lamp_ruby", 0.31, 0.04], [2, "market_lamp_jade", 0.28, 0.13],
		[4, "market_lamp_cobalt", 0.32, 0.06], [5, "market_lamp_ruby", 0.30, 0.13]])
	_bt_hanging_run(hang, PackedVector2Array([
		Vector2(-11.35, 3.67), Vector2(-10.05, 3.44), Vector2(-8.65, 3.37),
		Vector2(-7.15, 3.39), Vector2(-5.4, 3.52), Vector2(-3.45, 3.75),
	]), -4.86, [[1, "market_lamp_jade", 0.32, 0.07], [3, "market_lamp_ruby", 0.31, 0.12]],
		[[2, "market_cloth_teal", 0.72, 0.0], [4, "market_cloth_ochre", 0.65, 0.0]])
	_bt_hanging_run(hang, PackedVector2Array([
		Vector2(4.95, 3.75), Vector2(6.15, 3.57), Vector2(7.42, 3.45),
		Vector2(8.6, 3.47), Vector2(9.9, 3.63), Vector2(11.12, 3.83),
	]), -5.32, [[1, "market_lamp_cobalt", 0.31, 0.08], [4, "market_lamp_jade", 0.28, 0.07]],
		[[2, "market_cloth_cream", 0.65, 0.0], [3, "market_cloth_teal", 0.68, 0.0]])
	_bt_hanging_run(hang, PackedVector2Array([
		Vector2(18.83, 3.74), Vector2(20.12, 3.56), Vector2(21.78, 3.40),
		Vector2(23.27, 3.45), Vector2(25.0, 3.68),
	]), -5.05, [[1, "market_lamp_ruby", 0.30, 0.06], [2, "market_lamp_cobalt", 0.31, 0.12],
		[3, "market_lamp_jade", 0.30, 0.08]])

# Existing west-market foreground dressing stays behind the playable belt.
func _bt_west_market_finish(stalls: Node3D) -> void:
	var market := Node3D.new()
	market.name = "west_market_finish"
	stalls.add_child(market)
	# Loose fabric and a low cluster sit against the posts, outside the hand area.
	var cloth := _bt_quad(market, "banner_red", -22.43, 1.92, -21.94, 2.78, -5.25, 0.56)
	if cloth != null:
		cloth.rotation.z = -0.13
	cloth = _bt_quad(market, "banner_violet", -17.23, 2.21, -16.82, 2.95, -5.31, 0.59)
	if cloth != null:
		cloth.rotation.z = 0.11
	_bt_quad(market, "fg_crate", -22.46, 0.0, -21.75, 0.53, -4.97, 0.65)
	_bt_quad(market, "fg_crate", -22.12, 0.39, -21.68, 0.73, -4.99, 0.63)
	_bt_quad(market, "fg_crate", -17.37, 0.0, -16.77, 0.42, -5.07, 0.55)

	# Three fading wisps stay at the food stall's grill, below the pendant line.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var vapor := GradientTexture2D.new()
	vapor.gradient = fade
	vapor.width = 32
	vapor.height = 32
	vapor.fill = GradientTexture2D.FILL_RADIAL
	vapor.fill_from = Vector2(0.5, 0.5)
	vapor.fill_to = Vector2(1.0, 0.5)
	var puff := QuadMesh.new()
	puff.size = Vector2(0.32, 0.46)
	for i in 3:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = vapor
		var wisp := MeshInstance3D.new()
		wisp.name = "grill_steam_%d" % i
		wisp.mesh = puff
		wisp.material_override = material
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		market.add_child(wisp)
		var phase := float(i) / 3.0
		var drift := func(t: float) -> void:
			var age := fposmod(t + phase, 1.0)
			wisp.position = Vector3(-24.22 + age * 0.30 + sin(age * TAU) * 0.07, 1.15 + age * 0.94, -5.16)
			wisp.scale = Vector3.ONE * lerpf(0.55, 1.32, age)
			material.albedo_color = Color(0.91, 0.74, 0.60, sin(age * PI) * 0.30)
		drift.call(0.0)
		wisp.create_tween().set_loops().tween_method(drift, 0.0, 1.0, 2.35)


func _bt_finish_alley(id: String, left: float, right: float) -> void:
	var alley := Node3D.new()
	alley.name = id + "_finish"
	level.add_child(alley)
	var center := (left + right) * 0.5
	var mouth := BT.WALL_Z
	var depth := BT.ALLEY_DEPTH
	_ground(Vector3(center, 0.008, mouth - depth * 0.5), Vector2(right - left, depth + 0.14), cobble_tex, COBBLE_TILE)
	for side in [-1.0, 1.0]:
		var jamb := left + 0.11 if side < 0 else right - 0.11
		for offset in [0.04, 1.42, 3.15]:
			_bt_box(alley, Vector3(jamb, 2.27, mouth - offset), Vector3(0.15, 4.54, 0.20), "brick")
		_bt_box(alley, Vector3(jamb, 0.15, mouth - depth * 0.5), Vector3(0.14, 0.30, depth), "brick")
	_bt_box(alley, Vector3(center, 0.025, mouth + 0.02), Vector3(right - left - 0.19, 0.05, 0.22), "stone")
	var lamp_x := right - 0.33 if id == "alley_gate" else left + 0.32
	var art := "market_lamp_cobalt" if id == "alley_gate" else "market_lamp_jade"
	_bt_box(alley, Vector3(lamp_x, 2.74, mouth - 1.08), Vector3(0.31, 0.045, 0.055), "iron")
	_bt_quad(alley, art, lamp_x - 0.13, 2.29, lamp_x + 0.13, 2.73, mouth - 1.05, 0.64)

	if id == "alley_gate":
		_bt_east_alley_depth(alley, left, right, mouth)

## A boxed member with its long axis following two 3D attachment points.
func _bt_alley_member(parent: Node3D, from: Vector3, to: Vector3, section: Vector2, material: String) -> MeshInstance3D:
	var member := _bt_box(parent, (from + to) * 0.5, Vector3(section.x, section.y, from.distance_to(to)), material)
	member.look_at(parent.to_global(to))
	return member

func _bt_east_alley_depth(alley: Node3D, left: float, right: float, mouth: float) -> void:
	var bridge := Node3D.new()
	bridge.name = "patched_walkway"
	alley.add_child(bridge)
	var start := Vector3(left - 0.05, 3.05, mouth - 1.55)
	var end := Vector3(right + 0.05, 3.18, mouth - 2.22)
	var front := Vector3(0, 0, 0.33)
	var rise := Vector3.UP * 0.57

	_bt_alley_member(bridge, start, end, Vector2(0.72, 0.16), "wood")
	_bt_alley_member(bridge, start + front - Vector3.UP * 0.10, end + front - Vector3.UP * 0.10, Vector2(0.12, 0.16), "iron")
	_bt_alley_member(bridge, start + front + rise, end + front + rise, Vector2(0.055, 0.065), "iron")
	_bt_alley_member(bridge, start - front + rise, end - front + rise, Vector2(0.05, 0.055), "iron")
	for t in [0.08, 0.34, 0.65, 0.92]:
		var anchor := start.lerp(end, t)
		for edge in [-front, front]:
			_bt_box(bridge, anchor + edge + rise * 0.5, Vector3(0.05, rise.y, 0.05), "iron")
	# A patched timber skirt and dissimilar braces give the crossing two visibly different anchors.
	_bt_alley_member(bridge, start + front + Vector3.UP * 0.16, start.lerp(end, 0.49) + front + Vector3.UP * 0.16, Vector2(0.065, 0.25), "wood_lt")
	_bt_alley_member(bridge, start - Vector3.UP * 0.74, start.lerp(end, 0.23), Vector2(0.11, 0.14), "wood")
	_bt_alley_member(bridge, end - Vector3.UP * 0.55, end.lerp(start, 0.23), Vector2(0.085, 0.095), "iron")

	var rig := Node3D.new()
	rig.name = "depth_cable"
	alley.add_child(rig)
	var points := PackedVector3Array([
		Vector3(right + 1.48, 3.58, mouth + 3.36),
		Vector3(right + 0.54, 3.04, mouth + 1.78),
		Vector3(right - 0.31, 2.94, mouth + 0.38),
		Vector3(left + 0.58, 3.21, mouth - 1.72),
		Vector3(left + 0.33, 2.91, mouth - 3.73),
		Vector3(left + 0.07, 3.13, mouth - 5.03),
	])
	var near_cable := StandardMaterial3D.new()
	near_cable.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	near_cable.albedo_color = Color(0.22, 0.145, 0.12)
	for i in range(1, points.size()):
		var gauge := 0.043 if i <= 2 else 0.026
		var wire := _bt_alley_member(rig, points[i - 1], points[i], Vector2(gauge, gauge), "cable")
		if i <= 2:
			wire.material_override = near_cable
	# Tie the visible front end back to the iron frontage and clip the tail to the alley wall.
	_bt_alley_member(rig, points[0], Vector3(right + 1.48, 3.70, mouth + 0.02), Vector2(0.065, 0.07), "iron")
	_bt_box(rig, points[-1], Vector3(0.18, 0.14, 0.12), "iron")
	for mount in [[1, "market_lamp_ruby", 0.27, 1.02], [2, "market_lamp_jade", 0.21, 0.86], [4, "market_lamp_cobalt", 0.16, 0.71]]:
		var joint := points[int(mount[0])]
		var art: String = mount[1]
		var width: float = mount[2]
		var tex := _bt_art(art)
		if tex == null:
			continue
		var height := width * float(tex.get_height()) / float(tex.get_width())
		var light := _bt_quad(rig, art, joint.x - width * 0.5, joint.y - 0.04 - height, joint.x + width * 0.5, joint.y - 0.04, joint.z + 0.013, float(mount[3]))
		light.name = "depth_lamp_%d" % int(mount[0])

	# Laundry follows the lodging wall, leaving the center of the passage visible.
	var line_start := Vector3(left + 0.25, 3.43, mouth - 0.52)
	var line_mid := Vector3(left + 0.48, 3.12, mouth - 1.12)
	var line_end := Vector3(left + 0.32, 3.31, mouth - 2.33)
	_bt_alley_member(alley, line_start, line_mid, Vector2(0.025, 0.023), "cable")
	_bt_alley_member(alley, line_mid, line_end, Vector2(0.025, 0.023), "cable")
	var cloth := _bt_quad(alley, "market_cloth_teal", line_mid.x - 0.25, 2.53, line_mid.x + 0.25, 3.17, line_mid.z + 0.02, 0.62)
	if cloth != null:
		cloth.rotation.y = -0.70
	cloth = _bt_quad(alley, "market_cloth_ochre", line_end.x - 0.18, 2.77, line_end.x + 0.18, 3.26, line_end.z + 0.29, 0.52)
	if cloth != null:
		cloth.rotation.y = -0.79


## A separate crossing over the playable street, from a foreground gantry to the east facade.
func _bt_street_overpass(parent: Node3D) -> void:
	var bridge := Node3D.new()
	bridge.name = "street_overpass"
	parent.add_child(bridge)
	var near := Vector3(17.0, 3.32, BT.FG_Z + 0.35)
	var far := Vector3(18.72, 3.16, BT.WALL_Z + 0.03)
	var left := Vector3.LEFT * 0.86
	var right := -left

	var deck := _bt_alley_member(bridge, near, far, Vector2(1.72, 0.21), "wood")
	deck.name = "deck"
	for edge in [left, right]:
		_bt_alley_member(bridge, near + edge - Vector3.UP * 0.18, far + edge - Vector3.UP * 0.18, Vector2(0.12, 0.16), "iron")
		_bt_alley_member(bridge, near + edge + Vector3.UP * 0.58, far + edge + Vector3.UP * 0.58, Vector2(0.06, 0.07), "iron")
		for t in [0.04, 0.24, 0.43, 0.64, 0.84, 0.98]:
			var p: Vector3 = near.lerp(far, t) + edge
			_bt_box(bridge, p + Vector3.UP * 0.33, Vector3(0.06, 0.53, 0.06), "iron")
	for t in [0.04, 0.16, 0.31, 0.48, 0.63, 0.77, 0.92]:
		var p := near.lerp(far, t) - Vector3.UP * 0.19
		_bt_alley_member(bridge, p + left, p + right, Vector2(0.16, 0.14), "wood")
	# The left side has a later timber repair, the other side is mostly open ironwork.
	_bt_alley_member(bridge, near + left + Vector3.UP * 0.28, near.lerp(far, 0.41) + left + Vector3.UP * 0.28, Vector2(0.09, 0.32), "wood")
	_bt_alley_member(bridge, near.lerp(far, 0.51) + right + Vector3.UP * 0.17, near.lerp(far, 0.75) + right + Vector3.UP * 0.17, Vector2(0.07, 0.17), "tin")

	for side in [-1.0, 1.0]:
		var foot := near + Vector3(side * 0.93, -near.y, 0)
		var post := _bt_box(bridge, foot + Vector3.UP * 1.56, Vector3(0.54, 3.12, 0.59), "scaffold", "near_left_post" if side < 0.0 else "near_right_post")
		var fade_material := post.material_override.duplicate() as StandardMaterial3D
		fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		post.material_override = fade_material
		bt_fg.append({"node": post, "mat": fade_material, "half": 0.29, "overpass": true})
		var plinth := _bt_box(bridge, foot + Vector3.UP * 0.20, Vector3(0.68, 0.40, 0.71), "stone")
		var plinth_mat := plinth.material_override.duplicate() as StandardMaterial3D
		plinth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plinth.material_override = plinth_mat
		bt_fg.append({"node": plinth, "mat": plinth_mat, "half": 0.34, "overpass": true})
		_bt_alley_member(bridge, foot + Vector3.UP * 2.63, near + Vector3(side * 0.43, -0.24, 0.05), Vector2(0.12, 0.12), "wood")
	# Brackets run into the facade instead of adding a post in the walking lane.
	for side in [-1.0, 1.0]:
		var plate := far + Vector3(side * 0.71, -0.45, -0.04)
		_bt_box(bridge, plate, Vector3(0.22, 0.83, 0.12), "iron")
		_bt_alley_member(bridge, plate - Vector3.UP * 0.26, far + Vector3(side * 0.71, -0.15, 1.0), Vector2(0.11, 0.12), "iron")

	# Keep the storage on one edge so the deck still reads as a passage.
	var props := Node3D.new()
	props.name = "deck_props"
	bridge.add_child(props)
	var crate_spot := near.lerp(far, 0.69) + Vector3(0.43, 0.105, 0.0)
	var crate := _bt_box(props, crate_spot + Vector3.UP * 0.22, Vector3(0.48, 0.44, 0.44), "crate")
	crate.rotation.y = -0.19
	var small_spot := near.lerp(far, 0.76) + Vector3(0.24, 0.24, 0.0)
	var small_crate := _bt_box(props, small_spot, Vector3(0.35, 0.26, 0.34), "wood_lt")
	small_crate.rotation.y = 0.13
	var barrel_spot := near.lerp(far, 0.82) + Vector3(0.50, 0.105, 0.0)
	_bt_barrel(props, barrel_spot.x, barrel_spot.y, barrel_spot.z, 0.17, 0.49)
	var rail := near.lerp(far, 0.61) + right + Vector3.UP * 0.57
	var cloth := _bt_quad(props, "market_cloth_ochre", rail.x - 0.33, rail.y - 0.75, rail.x + 0.33, rail.y, rail.z, 0.74)
	if cloth != null:
		cloth.rotation.y = 1.0

	var wires := PackedVector3Array([
		near + Vector3(0.52, -0.27, -0.07),
		near.lerp(far, 0.25) + Vector3(0.42, -0.38, 0),
		near.lerp(far, 0.54) + Vector3(0.28, -0.33, 0),
		far + Vector3(0.40, -0.22, 0),
	])
	for i in range(1, wires.size()):
		_bt_alley_member(bridge, wires[i - 1], wires[i], Vector2(0.037, 0.035), "cable")
	for lamp in [[1, "market_lamp_ruby", 0.18, 1.0], [2, "market_lamp_jade", 0.15, 0.84]]:
		var p := wires[int(lamp[0])]
		var w: float = lamp[2]
		_bt_quad(bridge, lamp[1], p.x - w * 0.5, p.y - 0.39, p.x + w * 0.5, p.y, p.z + 0.015, lamp[3])


func build_backtown(with_gate: bool = true) -> void:
	_clear_level()
	_build_floor()
	bt_marks.clear()
	bt_lights.clear()
	bt_hang_rects.clear()
	bt_target_rects.clear()
	bt_fg.clear()
	BELT_Z = BT.BELT_Z
	var wz: float = BT.WALL_Z
	var h: float = BT.WALL_H
	var lh: float = BT.LOW_H
	# 建物の正面・つなぎの壁・柱・路地の口
	for sg in BT.segments():
		var x0: float = sg.x0
		var x1: float = sg.x1
		var cx: float = (x0 + x1) * 0.5
		match sg.kind:
			"wall":
				var root := Node3D.new()
				root.name = sg.id
				level.add_child(root)
				piece_nodes[sg.id] = root
				_bt_box(root, Vector3(cx, h * 0.5, wz - 1.6), Vector3(x1 - x0, h, 3.0), "side")   # 胴の前の面を壁の面より 0.1m 奥に（絵の板を隠さない）
				if sg.has("art") and _bt_art(sg.art) != null:   # 届いた絵：下の帯の窓（棟の中心 ±3.75m × 0〜5m）に貼る。上は素材を暗く
					var ab: Array = sg.art_box
					_bt_tex_wall(root, sg.get("upper_tex", "tex_iron"), x0, lh - 0.3, x1, h, wz - 0.03, 0.28)
					_bt_box(root, Vector3(cx, lh * 0.5, wz - 0.04), Vector3(x1 - x0, lh, 0.02), "dark")
					_bt_quad(root, sg.art, ab[0], ab[1], ab[2], ab[3], wz - 0.01)
				else:
					_bt_box(root, Vector3(cx, h * 0.5, wz - 0.02), Vector3(x1 - x0, h, 0.04), sg.base, "face")
					var pi := 0
					for pt in sg.parts:   # 並びの順に少しずつ手前へ（同じ奥行きで重なると描く順がばらつく）
						_bt_box(root, Vector3((pt[0] + pt[2]) * 0.5, (pt[1] + pt[3]) * 0.5, wz + 0.011 + pi * 0.004), Vector3(pt[2] - pt[0], pt[3] - pt[1], 0.02), pt[4])
						pi += 1
					_bt_shack(root, sg)   # 22章：小屋の形（張り出し・屋根・手すり・階段・樽）
				bt_marks.append(["wall", sg.id, Vector3(cx, 0, wz)])
			"filler":
				_bt_tex_wall(level, sg.tex, x0, 0.0, x1, h, wz - 0.2, 0.5)
				if with_gate and sg.get("finish", false):
					var crop := (x1 - x0) / lh * 0.5
					_bt_quad(level, "market_wall", x0, 0.0, x1, lh, wz - 0.18, 0.63, [0.5 - crop, 0.0, 0.5 + crop, 1.0])
			"pillar":
				_bt_box(level, Vector3(cx, h * 0.5, wz + 0.15), Vector3(x1 - x0, h, 0.5), "scaffold")
			"alley":
				var ad: float = BT.ALLEY_DEPTH
				for sx in [x0, x1]:
					_bt_box(level, Vector3(sx, h * 0.5, wz - ad * 0.5), Vector3(0.2, h, ad), "shadow")
				if with_gate:
					_bt_finish_alley(sg.id, x0, x1)
				else:
					_bt_box(level, Vector3(cx, -0.01, wz - ad * 0.5), Vector3(x1 - x0, 0.02, ad), "dark")
				var art_name: String = BT.ALLEY_BACKS.get(sg.id, "")
				var bw: float = x1 - x0 + 0.4
				var tex := _bt_art(art_name)
				var bh: float = bw * float(tex.get_height()) / float(tex.get_width()) if tex else 6.0
				var half_back := bw * 0.5 + (0.7 if with_gate else 0.0)
				if _bt_quad(level, art_name, cx - half_back, 0.0, cx + half_back, bh, wz - ad, 0.75) == null:
					_bt_box(level, Vector3(cx, 3.0, wz - ad), Vector3(bw, 6.0, 0.1), "cloth2")
	# 光る看板（届いた光る部品）
	var glow := Node3D.new()
	glow.name = "glow"
	level.add_child(glow)
	piece_nodes["glow"] = glow
	for sn in BT.SIGNS:
		var tex := _bt_art(sn[0])
		if tex == null:
			continue
		var w: float = sn[3]
		var hh: float = w * float(tex.get_height()) / float(tex.get_width())
		var y0: float = sn[2]
		var z: float = wz + (0.3 if sn[0] == "sign_vneon" else 0.06)
		if BT.ROPES.has(sn[4]):   # 24章：小屋の間の綱から吊るす（上端＝綱の下）
			var rp: Dictionary = BT.ROPES[sn[4]]
			y0 = rp.y - 0.06 - hh
			z = rp.z + 0.04
		elif sn[4] == "roof":   # 22章：飲み屋の屋根の上に立てる
			z = -4.55
		_bt_quad(glow, sn[0], sn[1] - w * 0.5, y0, sn[1] + w * 0.5, y0 + hh, z, BT_GLOW, [0.0, 0.0, 1.0, 1.0], 1)
		bt_marks.append(["sign", sn[0], Vector3(sn[1], y0 + hh * 0.5, z)])
		bt_lights.append([sn[0], sn[1], y0 + hh * 0.5, z, w])
		bt_target_rects.append(["sign:" + sn[0], sn[1] - w * 0.5, y0, sn[1] + w * 0.5, y0 + hh, z])
	for gb in BT.GLOW_BLOCKOUT:
		bt_marks.append(["sign", gb[0], Vector3(gb[1], 3.0, wz)])
	bt_lights.append(["cabaret_neon", 1.6, 3.5, wz + 0.05, 4.4])
	bt_lights.append(["cabaret_bulbs", 1.6, 1.5, wz + 0.05, 2.8])
	bt_lights.append(["shady", 21.3, 3.25, wz + 0.05, 1.0])
	bt_lights.append(["gate", 17.1, 2.2, wz - 2.0, 1.6])
	# 24章：足場の枠（柱・梁）と、柱で支えた布の天幕は外した。吊る物は小屋の軒・バルコニーの手すり・小屋の間の綱から（hangs）
	var fr := Node3D.new()
	fr.name = "hangs"
	level.add_child(fr)
	piece_nodes["hangs"] = fr
	for rk in BT.ROPES:   # 綱と両端の壁の金具
		var rp: Dictionary = BT.ROPES[rk]
		_bt_box(fr, Vector3((rp.x0 + rp.x1) * 0.5, rp.y, rp.z), Vector3(rp.x1 - rp.x0, 0.025, 0.02), "cable")
		for ex in [rp.x0, rp.x1]:
			_bt_box(fr, Vector3(ex, rp.y, (rp.z + BT.WALL_Z) * 0.5), Vector3(0.06, 0.06, absf(rp.z - BT.WALL_Z)), "iron")
		bt_marks.append(["rope", rk, Vector3((rp.x0 + rp.x1) * 0.5, rp.y, rp.z)])
	for hg in BT.HANGS:
		var tex := _bt_art(hg[2])
		if tex == null:
			continue
		var w: float = BT.PEND_W if hg[0] == "pend" else BT.BANNER_W
		var hh: float = w * float(tex.get_height()) / float(tex.get_width())
		var ay: Array = _bt_anchor(hg[3])
		var top: float = ay[0] - 0.04
		var hz: float = ay[1] + 0.04
		_bt_quad(fr, hg[2], hg[1] - w * 0.5, top - hh, hg[1] + w * 0.5, top, hz, BT_GLOW if hg[0] == "pend" else BT_ART_DIM, [0.0, 0.0, 1.0, 1.0], 0)
		_bt_box(fr, Vector3(hg[1], top + 0.02, hz), Vector3(0.02, 0.05, 0.02), "cable")   # 吊り紐
		bt_hang_rects.append([hg[0] + ":" + hg[2] + "@" + hg[3], hg[1] - w * 0.5, top - hh, hg[1] + w * 0.5, top, hz])
		if hg[0] == "pend":
			bt_lights.append([hg[2], hg[1], top - hh * 0.8, hz, 0.5])
	# 屋台（届いた絵は 2 層：奥の層 → 店の人 → カウンターの層）
	var st := Node3D.new()
	st.name = "stalls"
	level.add_child(st)
	piece_nodes["stalls"] = st
	var ni := 0
	var preview_keepers := {
		"stall_food": ["food_vendor", 1.72, 0.82],
		"stall_crystal": ["apothecary", 1.67, 0.30],
		"stall_parts": ["prosthesis_repair", 1.80, 0.30],
	}
	for s2 in BT.STALLS:
		var sx: float = s2.x
		var sw: float = s2.w
		var sh: float = s2.h
		if s2.art != "" and _bt_art(s2.art) != null:
			var sp: float = BT.STALL_SPLIT
			_bt_quad(st, s2.art, sx - sw * 0.5, sh * (1.0 - sp), sx + sw * 0.5, sh, BT.STALL_Z - 0.2, BT_ART_DIM, [0.0, 0.0, 1.0, sp])
			var front_art: String = {
				"stall_food": "stall_food_griddle",
				"stall_crystal": "stall_crystal_counter",
				"stall_parts": "stall_parts_workbench",
			}.get(s2.id, "")
			var low_front: bool = with_gate and not front_art.is_empty() and _bt_art(front_art) != null
			var food_front: bool = low_front and s2.id == "stall_food"
			if food_front:
				# Fill below the retained shelf, behind the keeper and the lower counter.
				_bt_tex_wall(st, "tex_boards", sx - 1.08, 0.0, sx + 1.08, sh * (1.0 - sp), BT.STALL_Z - 0.21, 0.44)
				var griddle := _bt_quad(st, "stall_food_griddle", sx - 1.12, 0.0, sx + 1.24, 1.10, BT.STALL_Z + 0.25, 0.73)
				griddle.name = "food_stall_front"
				_bt_quad(st, "fg_crate", sx + 0.95, 0.0, sx + 1.54, 0.49, BT.STALL_Z + 0.49, 0.67)
				_bt_barrel(st, sx + 1.30, 0.0, BT.STALL_Z + 0.31, 0.23, 0.71, 0.75)
				_bt_quad(st, "banner_red", sx + 1.15, 0.34, sx + 1.49, 0.72, BT.STALL_Z + 0.56, 0.67)
			elif low_front:
				_bt_tex_wall(st, "tex_boards", sx - 1.08, 0.0, sx + 1.08, sh * (1.0 - sp), BT.STALL_Z - 0.21, 0.42)
				var crystal: bool = s2.id == "stall_crystal"
				var front := _bt_quad(st, front_art, sx - 1.16, 0.0, sx + 1.16, 1.08, BT.STALL_Z + 0.25, 0.72)
				front.name = String(s2.id) + "_front"
				var side := -1.0 if crystal else 1.0
				var prop_x := sx + side * 1.15
				_bt_quad(st, "fg_crate" if crystal else "fg_crates", prop_x - 0.34, 0.0, prop_x + 0.34, 0.48, BT.STALL_Z + 0.46, 0.65)
			else:
				_bt_quad(st, s2.art, sx - sw * 0.5, 0.0, sx + sw * 0.5, sh * (1.0 - sp), BT.STALL_Z + 0.2, BT_ART_DIM, [0.0, sp, 1.0, 1.0])
			if s2.keeper:
				var keeper: Array = preview_keepers.get(s2.id, ["", 1.72, 0.30]) if with_gate else ["", 1.72, 0.30]
				var offset_x: float = keeper[2]
				if low_front:
					offset_x = 0.42 if s2.id != "stall_parts" else -0.24
				_bt_npc(st, sx + offset_x, BT.STALL_Z, ni, keeper[0], keeper[1])
				ni += 1
		else:   # 遊技の屋台（下絵）：台・歯車仕掛けの機械・光る窓・天幕。下絵の書き出しのため、屋台ごとの Node3D に入れる
			var gn := Node3D.new()
			gn.name = s2.id
			st.add_child(gn)
			_bt_box(gn, Vector3(sx, 0.55, BT.STALL_Z + 0.2), Vector3(sw, 1.1, 0.02), "wood")
			_bt_box(gn, Vector3(sx, 1.75, BT.STALL_Z - 0.2), Vector3(sw * 0.8, 1.3, 0.02), "brass")
			_bt_box(gn, Vector3(sx, 1.85, BT.STALL_Z - 0.18), Vector3(sw * 0.5, 0.7, 0.02), "neon_c")
			_bt_box(gn, Vector3(sx, sh - 0.25, BT.STALL_Z - 0.2), Vector3(sw + 0.2, 0.5, 0.02), "awning")
		bt_marks.append(["stall", s2.id, Vector3(sx, sh, BT.STALL_Z)])
		var light_key: String = "stall"
		if with_gate and s2.id == "stall_food":
			light_key = "west_grill"
		elif with_gate and s2.id == "stall_crystal":
			light_key = "west_crystal"
		bt_lights.append([light_key, sx, 1.6, BT.STALL_Z + 0.2, sw * 0.7])
	# 22章：屋台風の飲み屋・吊り布・ガラス管・歯車の輪・光るネオンの置き場所。人の立ち位置（前作の町の人を仮に）
	_bt_extras(st, with_gate)
	for pp in BT.PEOPLE:
		if with_gate and pp[2] == "屋台風の飲み屋D の客":
			ni += 1
			continue
		if with_gate and pp[2] == "客引きの女（戸口）":
			_bt_npc(st, pp[0], pp[1], ni, "courtesan", 1.75)
		elif with_gate and pp[0] == -3.6:
			_bt_npc(st, pp[0], pp[1], ni, "drunk", 1.69)
		else:
			_bt_npc(st, pp[0], pp[1], ni)
		ni += 1
		bt_marks.append(["person", pp[2], Vector3(pp[0], 1.9, pp[1])])
	if with_gate:
		_bt_west_market_finish(st)
		_bt_market_overhead(fr)
		var motion_enabled := not _q("npc_motion=off")
		var edge_margin := 0.5
		var start_x := BT.ROOM_X.x + edge_margin if motion_enabled else -16.4
		_bt_npc(st, start_x, -1.2, 0, "night_worker", 1.74)
		if motion_enabled:
			_bt_start_patrol(st.get_node("night_worker"), BT.ROOM_X.y - edge_margin)
	# 手前の物（届いた絵）
	var fgn := Node3D.new()
	fgn.name = "foreground"
	level.add_child(fgn)
	piece_nodes["foreground"] = fgn
	for f in BT.FG:
		var tex := _bt_art(f[0])
		if tex == null:
			continue
		var hh: float = f[2]
		var w: float = hh * float(tex.get_width()) / float(tex.get_height())
		var fq := _bt_quad(fgn, f[0], f[1] - w * 0.5, 0.0, f[1] + w * 0.5, hh, BT.FG_Z, 0.45, [0.0, 0.0, 1.0, 1.0], 2)   # 透けるので半透明の描き方
		if fq and String(f[0]).begins_with("fg_pillar"):
			bt_fg.append({"node": fq, "mat": fq.material_override, "half": w * 0.5})
	if with_gate:
		_bt_street_overpass(fgn)
	for fb in BT.FG_BARRELS:   # 22章：手前の樽
		_bt_barrel(fgn, fb[0], 0.0, BT.FG_Z, fb[1], fb[2], 0.55)
	# 印（扉・路地の口・人混みの帯）。正面図には写さない
	var mk := Node3D.new()
	mk.name = "marks"
	mk.visible = OS.get_environment("BT_GUIDES") == "1"
	level.add_child(mk)
	piece_nodes["marks"] = mk
	for d in BT.DOORS:
		_bt_box(mk, Vector3(d.x, 0.015, wz + 0.8), Vector3(d.w, 0.02, 1.4), "neon_g")
		bt_marks.append(["door", d.id, Vector3(d.x, d.h, wz)])
		bt_target_rects.append(["door:" + d.id, d.x - d.w * 0.5, 0.0, d.x + d.w * 0.5, d.h, wz])
	for al in BT.ALLEYS:
		bt_target_rects.append(["alley:" + al.id, al.x - al.w * 0.5, 0.0, al.x + al.w * 0.5, 3.9, wz])
	for s3 in BT.STALLS:   # 屋台の天幕（絵の上 30％）
		bt_target_rects.append(["stall_awning:" + s3.id, s3.x - s3.w * 0.5, s3.h * 0.7, s3.x + s3.w * 0.5, s3.h, BT.STALL_Z - 0.2])
	bt_target_rects.append(["sign:cabaret_neon", -0.6, 3.05, 3.0, 3.75, wz + 0.05])
	bt_target_rects.append(["sign:cabaret_bulbs", 0.2, 0.0, 3.0, 2.5, wz + 0.05])
	bt_target_rects.append(["sign:shady_small", 20.8, 3.05, 21.8, 3.45, wz + 0.05])
	for fx in [-19.1, -9.5, 0.0, 9.5, 19.1]:   # 番号 1：外した足場の梁があった所
		bt_marks.append(["fix", "1", Vector3(fx - 2.5, 3.2, -4.1)])
	for al in BT.ALLEYS:
		_bt_box(mk, Vector3(al.x, 0.015, wz + 0.3), Vector3(al.w, 0.02, 0.4), "lamp")
		bt_marks.append(["alley", al.id, Vector3(al.x, 2.0, wz)])
	_build_crowd()
	# 床の濡れた映り込み（15章）：この区画の光る部品・ペンダントライト・屋台・キャバレー・門から（make_glints.py は塗った建物の絵から拾う作りなので、
	#   部品の位置をデータで持つこの区画ではデータから作る）。強い光ほど明るく、高い所ほど長い筋
	glints = []
	for L in bt_lights:
		var key: String = L[0]
		var col: Array = BT_GLINT_COL.get(key, [1.0, 0.8, 0.5])
		var p: float = 0.95 if key in ["vision_screen", "cabaret_neon", "sign_sigil", "gate"] else (0.55 if key.begins_with("pend") else 0.75)
		var glint := {"x": L[1], "y": L[2], "z": L[3] + 0.2, "w": clampf(float(L[4]), 0.4, 2.4), "col": col, "p": p, "k": 0.8}
		if key in ["west_grill", "west_crystal"]:
			glint.w = 0.93
			glint.len = 4.6
		elif with_gate and key == "vision_screen" and is_equal_approx(float(L[1]), -18.8):
			glint.k = 0.47
		glints.append(glint)
	if with_gate:
		_build_gate(BT.DUNGEON_GATE_X, true)
	_build_glints()
	cam_x = Vector2(BT.ROOM_X.x + 4.92, BT.ROOM_X.y - 3.0)
	if battle:
		battle.glints = glints
		battle.ROOM_X = BT.ROOM_X
		battle.BELT_Z = BELT_Z
	if player:
		player.room_x = BT.ROOM_X
		player.belt_z = BELT_Z

## 裏の町の撮影（TOWN=back FX_ONLY=backtown）：ゲームの画面（カメラ D2）でラナを帯の中央に、区画の左から右へ 5 か所 → captures/bt_play_<n>.png。
##   どの画面にも光る看板が何枚入るかを BTSIGNS で出す。最後に区画全体の正面図（正投影、届いた絵込み）→ captures/bt_front.png
func _capture_backtown(dir: String) -> void:
	player.visible = true
	player.set_physics_process(false)
	player._show_frame("idle", 0)
	for x in battle.enemies.duplicate():
		battle.remove_enemy(x)
	if battle.ally:
		battle.ally.visible = false
		battle.ally.set_physics_process(false)
	var vh := get_viewport().get_visible_rect().size
	var cams := [cam_x.x, cam_x.x * 0.5, 0.0, cam_x.y * 0.5, cam_x.y]
	for n in cams.size():
		player.position = Vector3(cams[n], 0, 0)
		player.face = 1
		_place_cam(true)
		battle.apply_light(player.sprite, player.mat, player.refl, player.position)
		ui.visible = false
		for f in 5:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/bt_play_%d.png" % n)
		var nsign := 0
		for m in bt_marks:
			var sp := cam.unproject_position(m[2])
			var on: bool = not cam.is_position_behind(m[2]) and sp.x > 0 and sp.x < vh.x
			if on or m[0] in ["chk", "eave", "win2f"]:
				print("BTMARK %d %s %s %.4f %.4f%s" % [n, m[0], m[1], sp.x / vh.x, sp.y / vh.y, "" if on else " off"])
				if m[0] == "sign":
					nsign += 1
		print("BTSIGNS %d cam_x=%.1f 光る看板 %d 枚" % [n, cams[n], nsign])
		_bt_occlusion(n, vh)
	# 細かく：カメラを 0.5m おきに動かしたときの、画面の光る看板の数の最小・最大。
	#   24章：前の数え方（置いた直後に数える）と、カメラを動かして 2 コマ待ってから数える方法を並べる
	var mn := 99
	var mxn := 0
	var mn0 := 99
	var mx0 := 0
	var lows := []
	var cxx: float = cam_x.x
	while cxx <= cam_x.y + 0.01:
		player.position = Vector3(cxx, 0, 0)
		_place_cam(true)
		var c0 := _bt_count_signs(vh)
		for f in 2:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var c := _bt_count_signs(vh)
		mn0 = mini(mn0, c0)
		mx0 = maxi(mx0, c0)
		mn = mini(mn, c)
		mxn = maxi(mxn, c)
		if c < 4 or c > 6 or c != c0:
			lows.append("%.1f:%d/%d" % [cxx, c0, c])
		cxx += 0.5
	print("BTSIGNS_RANGE_OLD 最小 %d 最大 %d（置いた直後）" % [mn0, mx0])
	print("BTSIGNS_LOW %s" % " ".join(lows))
	_bt_belt_check()
	print("BTSIGNS_RANGE 最小 %d 最大 %d" % [mn, mxn])
	ui.visible = true
	await _bt_front(dir)
	if OS.get_environment("BT_GUIDES") == "1":   # 22章：下絵の書き出しは判定のあと（BT_GUIDES=1 のときだけ art/guide_bt を上書き）
		await _bt_guides_v2()

## 24章：画面の光る看板の数（印の中心が画面の左右の内側）
func _bt_count_signs(vh: Vector2) -> int:
	var c := 0
	for m in bt_marks:
		if m[0] == "sign":
			var sp2 := cam.unproject_position(m[2])
			if not cam.is_position_behind(m[2]) and sp2.x > 0 and sp2.x < vh.x:
				c += 1
	return c

## 24章：吊り物・手前の柱・屋台風の飲み屋の屋根が、扉・光る看板・屋台の天幕・路地の口・ビジョン・ネオンの枠をふさいでいないか（画面の四角の重なり、手前にある物だけ）
func _bt_rect_on_screen(r: Array) -> Rect2:
	var a := cam.unproject_position(Vector3(r[1], r[2], r[5]))
	var b := cam.unproject_position(Vector3(r[3], r[4], r[5]))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y)))

func _bt_occlusion(n: int, vh: Vector2) -> void:
	var covers := bt_hang_rects.duplicate()
	for f in bt_fg:   # 手前の柱（ラナから 2.5m 以内は透ける）
		var fp: Vector3 = f.node.position
		var hh: float = (f.node.mesh as QuadMesh).size.y
		var alpha: float = 0.3 if absf(fp.x - player.position.x) < 2.5 else 1.0
		covers.append(["fg_pillar(%.1f,透明度%.1f)" % [fp.x, alpha], fp.x - f.half, 0.0, fp.x + f.half, hh, fp.z])
	var screen := Rect2(Vector2.ZERO, vh)
	for t in bt_target_rects:
		var tr := _bt_rect_on_screen(t)
		var tvis := tr.intersection(screen)
		if tvis.get_area() <= 1.0:
			continue
		for cv in covers:
			if cv[5] <= t[5]:
				continue
			var cr := _bt_rect_on_screen(cv).intersection(tvis)
			var ratio := cr.get_area() / tr.get_area()
			if ratio > 0.01:
				print("OCCL %d %s が %s を %.0f%% 隠す" % [n, cv[0], t[0], ratio * 100.0])

## 24章：ラナの歩く帯（z −2〜2）に物が無いか（床・映り込みの板・ラナ自身は除く）
func _bt_belt_check() -> void:
	var cnt := 0
	var stack: Array = [level]
	while stack.size() > 0:
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		if nd is GeometryInstance3D and nd.visible:
			var gi: GeometryInstance3D = nd
			if gi is MeshInstance3D and ((gi as MeshInstance3D).mesh is PlaneMesh):
				continue
			var bb := gi.global_transform * gi.get_aabb()
			if bb.end.z > BT.BELT_Z.x and bb.position.z < BT.BELT_Z.y and bb.end.y > 0.05:
				cnt += 1
				print("BELT %s %s z %.2f〜%.2f y 〜%.2f" % [gi.name, gi.get_class(), bb.position.z, bb.end.z, bb.end.y])
	print("BELT_COUNT %d" % cnt)

## 下絵の書き出し（19章）：新しい建物の下の帯（棟の中心 ±3.75m × 0〜5m → 1536×1024、1m＝204.8px）と遊技の屋台（1024×1536、1m＝380px）。
##   マゼンタの地、その部品だけを写す（正投影）。art/guide_bt/<名前>.png と guide.json の "v2"（範囲・1m の画素・凡例・扉・屋台・路地・人）
func _bt_guides_v2() -> void:
	var out := ProjectSettings.globalize_path("res://art/guide_bt")
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var rc := Camera3D.new()
	rc.projection = Camera3D.PROJECTION_ORTHOGONAL
	rc.keep_aspect = Camera3D.KEEP_HEIGHT
	var renv := Environment.new()
	renv.background_mode = Environment.BG_COLOR
	renv.background_color = MAGENTA
	rc.environment = renv
	vp.add_child(rc)
	player.visible = false
	var shots := []
	for sg in BT.segments():
		if sg.kind == "wall" and BT.GUIDE_OUT.has(sg.id):
			var cx: float = (sg.x0 + sg.x1) * 0.5
			shots.append({"name": BT.GUIDE_OUT[sg.id], "node": piece_nodes[sg.id], "box": [cx - 3.75, 0.0, cx + 3.75, BT.LOW_H], "size": Vector2i(1536, 1024), "note": sg.note})
	for s2 in BT.STALLS:
		if s2.art == "":
			var stn: Node3D = piece_nodes["stalls"].get_node(NodePath(s2.id))
			var hw := 1024.0 / 380.0 * 0.5
			shots.append({"name": s2.id, "node": stn, "box": [s2.x - hw, -0.3, s2.x + hw, -0.3 + 1536.0 / 380.0], "size": Vector2i(1024, 1536), "note": s2.note})
	# 26章：BT_GUIDE_ONLY="<棟の id>=<名前>" のときはその 1 枚だけ（他の下絵は上書きしない）。guide.json は "v2_<名前>" に書く（"v2" は触らない）。
	#   飲み屋は上の小屋の酒の記号の枠（NEON_SLOTS の neon_liquor_tavern）も一緒に写す（人・手前の柱・ペンダントライト・光る看板は写さない）
	var only := OS.get_environment("BT_GUIDE_ONLY")
	var meta_key := "v2"
	var temp_nodes := []
	if only != "":
		var oid := only.get_slice("=", 0)
		var oname := only.get_slice("=", 1)
		meta_key = "v2_" + oname
		var keep := []
		for sh0 in shots:
			if sh0.node == piece_nodes.get(oid, null):
				sh0.name = oname
				if oid == "n1_tavern":
					var tn := Node3D.new()
					tn.name = "guide_slot"
					level.add_child(tn)
					temp_nodes.append(tn)
					for ns in BT.NEON_SLOTS:
						if ns[0] == "neon_liquor_tavern":
							_bt_box(tn, Vector3((ns[1] + ns[3]) * 0.5, (ns[2] + ns[4]) * 0.5, ns[5] - 0.01), Vector3(ns[3] - ns[1], ns[4] - ns[2], 0.01), "dark")
							for e in [[ns[1], ns[2], ns[3], ns[2] + 0.04], [ns[1], ns[4] - 0.04, ns[3], ns[4]], [ns[1], ns[2], ns[1] + 0.04, ns[4]], [ns[3] - 0.04, ns[2], ns[3], ns[4]]]:
								_bt_box(tn, Vector3((e[0] + e[2]) * 0.5, (e[1] + e[3]) * 0.5, ns[5]), Vector3(e[2] - e[0], e[3] - e[1], 0.02), "slot")
					sh0["extra"] = tn
				keep.append(sh0)
		shots = keep
	var meta := {"px_note": "x0〜x1・y0〜y1 は世界の m。1m の画素＝w÷(x1−x0)", "legend": {}, "parts": {}, "doors": BT.DOORS, "alleys": BT.ALLEYS, "stalls": BT.STALLS,
		"people": BT.PEOPLE, "low_h": BT.LOW_H, "visible_top_m": 3.98}
	for k in BT.LEGEND:
		var c: Color = BT.MAT[k]
		meta.legend["#" + c.to_html(false)] = {"key": k, "ja": BT.LEGEND[k][0], "en": BT.LEGEND[k][1]}
	for sh in shots:
		var b: Array = sh.box
		vp.size = sh.size
		rc.size = b[3] - b[1]
		rc.position = Vector3((b[0] + b[2]) * 0.5, (b[1] + b[3]) * 0.5, 40.0)
		# その部品だけ見せる
		var vis_state := []
		for ch in level.get_children():
			vis_state.append([ch, ch.visible])
			ch.visible = false
		var nd: Node3D = sh.node
		if sh.has("extra"):
			sh.extra.visible = true
		var p := nd
		while p != level and p != null:
			p.visible = true
			p = p.get_parent()
		if nd.get_parent() == piece_nodes["stalls"]:
			for c2 in piece_nodes["stalls"].get_children():
				c2.visible = c2 == nd
		for f in 4:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/%s.png" % sh.name)
		meta.parts[sh.name] = {"x0": b[0], "y0": b[1], "x1": b[2], "y1": b[3], "w": sh.size.x, "h": sh.size.y, "px_per_m": sh.size.x / (b[2] - b[0]), "note": sh.note}
		print("BTGUIDE %s %s" % [sh.name, str(sh.size)])
		for vs in vis_state:
			vs[0].visible = vs[1]
		if nd.get_parent() == piece_nodes["stalls"]:
			for c2 in piece_nodes["stalls"].get_children():
				c2.visible = true
	player.visible = true
	vp.queue_free()
	for tn2 in temp_nodes:
		tn2.queue_free()
	var gpath := out + "/guide.json"
	var g = JSON.parse_string(FileAccess.get_file_as_string(gpath)) if FileAccess.file_exists(gpath) else {}
	if not (g is Dictionary):
		g = {}
	g[meta_key] = meta
	var f2 := FileAccess.open(gpath, FileAccess.WRITE)
	f2.store_string(JSON.stringify(g, "  "))
	f2.close()

## 区画全体の正面図（正投影・届いた絵込み・人と印は写さない）。x −26.5〜26.5・y 0〜6m
func _bt_front(dir: String) -> void:
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(2048 * 2, int(2048 * 2 * 6.0 / 53.0))
	add_child(vp)
	var rc := Camera3D.new()
	rc.projection = Camera3D.PROJECTION_ORTHOGONAL
	rc.keep_aspect = Camera3D.KEEP_HEIGHT
	rc.size = 6.0
	rc.position = Vector3(0, 3.0, 40.0)
	var renv := Environment.new()
	renv.background_mode = Environment.BG_COLOR
	renv.background_color = Color(0.05, 0.04, 0.07)
	rc.environment = renv
	vp.add_child(rc)
	player.visible = false
	var hidden := []
	for ch in level.get_children():
		var nm := String(ch.name)
		if nm == "marks" or nm == "foreground" or ch is Sprite3D or (ch is MeshInstance3D and ch.mesh is PlaneMesh):
			if ch.visible:
				ch.visible = false
				hidden.append(ch)
	for f in 5:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(dir + "/bt_front.png")
	for ch in hidden:
		ch.visible = true
	player.visible = true
	vp.queue_free()

## ダンジョンの部屋：歓楽街の部品を並べ替えて置く（ofs の使い回し）。spec は dungeon_map.gd の部屋。
func build_room(spec: Dictionary) -> void:
	if DgThemes.has_parts(room_theme):
		build_room_parts(spec, room_theme)
		return
	_clear_level()
	var rw: float = spec.rw
	_build_floor(2.0 * rw + 28.0)
	var by_id := {}
	for p in City.pieces():
		by_id[p.id] = p
	# 裏通りの列と遠景はそのまま（少し横へずらして毎回の見え方を変える）。
	# 部屋が広い（2〜3 画面）とカメラが ±12m より先へ動き、1 枚では端が切れる → 左右に写しを足す（2026-11-14）
	var cam_far: float = maxf(0.0, rw - _play_half_w())
	_build_piece(by_id["b0_backrow"], Vector3(spec.back_ofs, 0, 0), "b0_room")
	if cam_far + 19.4 > 32.0:
		for s in [-1, 1]:
			_build_piece(by_id["b0_backrow"], Vector3(spec.back_ofs + s * 64.0, 0, 0), "b0_room_%d" % s)
	_build_piece(by_id["z_skyline"])
	if cam_far + 56.0 > FAR_W * 0.5:
		for s in [-1, 1]:
			_build_piece(by_id["z_skyline"], Vector3(s * FAR_W, 0, 0), "z_skyline_%d" % s)
	glints = []
	for i in spec.slots.size():
		var id: String = spec.slots[i]
		var p: Dictionary = by_id[id]
		var ext := _piece_x_range(p)
		var cx: float = (ext.x + ext.y) * 0.5
		var ofs := Vector3(float(spec.slot_x[i]) - cx, 0, 0)
		_build_piece(p, ofs, "%s_%d" % [id, i])
		for g in glints_src:   # その建物の看板・灯りの映り込みも一緒に動かす
			if float(g.x) >= ext.x - 0.5 and float(g.x) <= ext.y + 0.5 and float(g.z) < -5.0:
				var q: Dictionary = g.duplicate(true)
				q.x = float(g.x) + ofs.x
				glints.append(q)
	for i in spec.fg.size():
		var f: Array = spec.fg[i]
		var p: Dictionary = by_id[f[0]]
		var ext := _piece_x_range(p)
		_build_piece(p, Vector3(float(f[1]) - (ext.x + ext.y) * 0.5, 0, 0), "%s_fg%d" % [f[0], i])
	_build_glints()
	cam_x = Vector2(-cam_far, cam_far)
	battle.glints = glints
	battle.ROOM_X = Vector2(-rw, rw)
	player.room_x = Vector2(-rw, rw)

## テーマの部品（外部AIの絵を切り抜いた板。assets/dungeon/<テーマ>/）で部屋を組む（2026-11-14、仮組み）。
## 3D の下絵（箱）への投影ではなく、画面に正対する板を並べる。間取りの slots（b1〜b4）・fg（f1〜f3）の番号をそのまま使う。
## 板の大きさ＝絵の画素 ÷ THEME_PPM（全部品で同じ割合＝部品どうしの大きさは絵のまま）。
const THEME_PPM := 150.0        # 正面の建物・手前の物：1m あたりの画素
const THEME_WALL_Z := -6.6      # 建物の正面の線（歓楽街の建物の正面 −6.5 に合わせる）
const THEME_BLD_DIM := 0.55     # 建物の板の明るさ（光る画素は残す）
func build_room_parts(spec: Dictionary, theme: String) -> void:
	_clear_level()
	var rw: float = spec.rw
	var dir := "res://assets/dungeon/%s/" % theme
	_build_floor(2.0 * rw + 28.0, load(dir + theme + "_g1.webp"))
	var cam_far: float = maxf(0.0, rw - _play_half_w())
	var root := Node3D.new()
	root.name = "theme_parts"
	level.add_child(root)
	# 遠景（いちばん奥・霧に沈める）と裏の列：横に繰り返して、カメラが端まで動いても切れない幅に
	var far_tex: Texture2D = load(dir + theme + "_far1.webp")
	var far_w := 70.0
	var far_h := far_w * float(far_tex.get_height()) / float(far_tex.get_width())
	var n_far := int(ceil((cam_far + 60.0) / far_w))
	for i in range(-n_far, n_far + 1):
		_theme_plane(root, far_tex, Vector3(i * far_w + spec.back_ofs * 2.0, -2.0, -45.0), Vector2(far_w, far_h), 0.75, Color(0.38, 0.27, 0.42, 0.55), i % 2 != 0)
	var back_tex: Texture2D = load(dir + theme + "_back1.webp")
	var back_w := 30.0
	var back_h := back_w * float(back_tex.get_height()) / float(back_tex.get_width())
	var n_back := int(ceil((cam_far + 26.0) / back_w))
	for i in range(-n_back, n_back + 1):
		_theme_plane(root, back_tex, Vector3(i * (back_w - 1.0) + spec.back_ofs, -0.2, -14.0), Vector2(back_w, back_h), 0.6, Color(0.38, 0.27, 0.42, 0.35), i % 2 != 0)
	# 正面の建物：slots の順に、すき間なく（0.35m 重ねて）並べ、全体を部屋の中心にそろえる
	var bld := []
	var total := 0.0
	for id in spec.slots:
		var tid: String = theme + "_" + str(id).substr(0, 2)   # "b1_tavern" → "t2_b1"
		var tex: Texture2D = load(dir + tid + ".webp")
		var w := float(tex.get_width()) / THEME_PPM
		bld.append([tex, w])
		total += w - 0.35
	var x: float = -total * 0.5 + float(spec.back_ofs) * 0.3
	for i in bld.size():
		var tex: Texture2D = bld[i][0]
		var w: float = bld[i][1]
		var h := float(tex.get_height()) / THEME_PPM
		_theme_plane(root, tex, Vector3(x + w * 0.5, -0.06, THEME_WALL_Z - (0.02 * (i % 2))), Vector2(w, h), THEME_BLD_DIM, Color(1, 1, 1, 0.0), false)   # 足元を少し床へ沈める
		x += w - 0.35
	# 手前の物（f1〜f3）：ぼかして暗く。ラナと重なると透ける（fg_list）
	for i in spec.fg.size():
		var f: Array = spec.fg[i]
		var tid: String = theme + "_" + str(f[0]).substr(0, 2)
		var tex: Texture2D = load(dir + tid + ".webp")
		var h := 5.0
		var w := h * float(tex.get_width()) / float(tex.get_height())
		var mi := _theme_plane(root, tex, Vector3(float(f[1]), 0.0, 5.6 - FG_PULL), Vector2(w, h), FG_DIM, Color(1, 1, 1, 0.0), false)
		var m: ShaderMaterial = mi.material_override
		m.set_shader_parameter("blur", FG_BLUR)
		fg_list.append({"node": mi, "mat": m, "half": w * 0.5})
	glints = []   # 映り込みの光の元はまだ無い（T2 の看板・灯りの位置を拾うのは後で）
	_build_glints()
	cam_x = Vector2(-cam_far, cam_far)
	battle.glints = glints
	battle.ROOM_X = Vector2(-rw, rw)
	player.room_x = Vector2(-rw, rw)

## 板 1 枚（足元＝pos.y、中心＝pos.x、奥行き＝pos.z）。night＝光る画素以外の明るさ、amb＝霧の色（a＝量）、flip＝左右反転（繰り返しの継ぎ目を目立たなくする）
func _theme_plane(root: Node3D, tex: Texture2D, pos: Vector3, size: Vector2, night: float, amb: Color, flip: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	if flip:
		mi.scale.x = -1.0
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("night_dim", night)
	m.set_shader_parameter("bg_layer", 1.0)
	m.set_shader_parameter("tint", Color(1, 1, 1, 1))
	m.set_shader_parameter("amb_col", amb)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi

func _play_half_w() -> float:
	return DG_HALF_W if cam_variant == "D2" else PLAY_HALF_W

func _piece_x_range(p: Dictionary) -> Vector2:
	var x0 := INF
	var x1 := -INF
	for b in p.boxes:
		x0 = minf(x0, b[0].x - b[1].x * 0.5)
		x1 = maxf(x1, b[0].x + b[1].x * 0.5)
	return Vector2(x0, x1)

## 出口・入口の印：床の光の帯＋2本の柱の灯。色で状態を見せる（文字なし）。
func make_portal(center: Vector3, along_x: bool, length: float, col: Color, posts: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = center
	var band := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(length, 0.9) if along_x else Vector2(0.9, length)
	band.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.55)
	band.material_override = m
	band.position.y = 0.025
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.name = "band"
	root.add_child(band)
	if posts:
		var pm2 := StandardMaterial3D.new()
		pm2.albedo_color = Color(0.08, 0.08, 0.1)
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = col
		for sgn in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.22, 2.6, 0.22)
			post.mesh = bm
			post.material_override = pm2
			var off := Vector3(sgn * length * 0.5, 1.3, 0) if along_x else Vector3(0, 1.3, sgn * length * 0.5)
			post.position = off
			root.add_child(post)
			var lamp := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.3, 0.5, 0.3)
			lamp.mesh = lb
			lamp.material_override = lm
			lamp.position = off + Vector3(0, 1.45, 0)
			lamp.name = "lamp"
			root.add_child(lamp)
	level.add_child(root)
	return root

func set_portal_color(n: Node3D, col: Color, a: float) -> void:
	for ch in n.get_children():
		if not ch is MeshInstance3D:
			continue
		var m = ch.material_override
		if m is StandardMaterial3D and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			if ch.name == "band":
				m.albedo_color = Color(col.r, col.g, col.b, a)
			else:
				m.albedo_color = col

## 街の端（高架の下）のダンジョンの入口：奥の歩道側の門。紫＝どちらの陣営でもない。
const GATE_COL := Color(0.72, 0.5, 1.0)
const GATE_SHADER := preload("res://scripts/gate.gdshader")
func _build_gate(x: float = GATE_X, straight: bool = false) -> void:
	gate = make_portal(Vector3(x, 0, 0.0 if straight else BELT_Z.x - 0.15), true, 2.6, GATE_COL)
	gate.set_meta("straight_entry", straight)
	if straight:
		var trim := Node3D.new()
		trim.name = "painted_gate_frame"
		gate.add_child(trim)
		for child in gate.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh:
				if String(child.name).begins_with("lamp"):
					gate.remove_child(child)
					child.queue_free()
				else:
					child.reparent(trim, false)
					child.material_override = _bt_mat("stone")
		_bt_box(trim, Vector3(0, 2.86, -0.02), Vector3(2.99, 0.39, 0.31), "iron")
		_bt_box(trim, Vector3(0, 3.06, 0.04), Vector3(3.14, 0.105, 0.33), "brass")
		for x_post in [-1.3, 1.3]:
			_bt_box(trim, Vector3(x_post, 0.23, 0.03), Vector3(0.32, 0.46, 0.31), "iron")
			_bt_quad(trim, "market_lamp_cobalt", x_post - 0.13, 2.35, x_post + 0.13, 2.77, 0.19, 0.88)
	# 柱の間の光る扉（縦の板、下ほど明るい）と上の梁。遠くからでも入口と分かるように
	var door := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.4, 2.9)
	door.mesh = qm
	var dm := ShaderMaterial.new()
	dm.shader = GATE_SHADER
	dm.set_shader_parameter("col", GATE_COL)
	door.material_override = dm
	door.position = Vector3(0, 1.45, -0.05)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(door)
	if not straight:
		var beam := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.0, 0.22, 0.26)
		beam.mesh = bm
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = GATE_COL
		beam.material_override = lm
		beam.position = Vector3(0, 2.95, 0)
		beam.name = "lamp_beam"
		gate.add_child(beam)
	glints.append({"x": x, "y": 2.0, "z": gate.position.z, "w": 1.6, "col": [GATE_COL.r, GATE_COL.g, GATE_COL.b], "p": 0.8, "len": 4.0})

func _check_gate() -> void:
	if gate == null or dungeon != null or player == null or town_floor_busy or hud == null:
		return
	set_portal_color(gate, GATE_COL, 0.4 + 0.25 * sin(Time.get_ticks_msec() * 0.004))
	var near: bool = absf(player.position.x - gate.position.x) < 1.4 and (gate.get_meta("straight_entry", false) or player.position.z < BELT_Z.x + 0.7)
	if near and gate_armed and not hud.menu_open and not hud.slot_open and not player.locked:
		gate_armed = false
		hud.open_menu()
	elif not near:
		gate_armed = true

var next_seed := -1   # 撮影の自動入力が決めた間取りの種（-1＝毎回ランダム）
const DgThemes := preload("res://scripts/dungeon_themes.gd")
var room_theme := "t1"   # 今のダンジョンのテーマ（build_room が部品を選ぶ）
var dg_perf_n := 0    # ?dgtest=N（環境変数 DG_PERF でも）：重さの計測
func dungeon_seed() -> int:
	var s := next_seed
	next_seed = -1
	return s

## ダンジョンのカメラ（2026-11-14 ユーザー決定）：入口に関係なく、新しい街（裏の町）と同じ案 D2・帯 4m（z −2〜2）。
## 出る時に元へ戻す（古い大通りから入った時のため）
const DG_CAM := {"belt": Vector2(-2.0, 2.0), "ofs": Vector3(0, 3.2, 15.3), "look": Vector3(0, 1.50, 0), "fov": 16.8}
const DG_HALF_W := 4.9   # D2 で帯の中心に見える横幅の半分（m）。カメラが部屋の端まで寄る量
var cam_saved := {}
func _set_belt(b: Vector2) -> void:
	BELT_Z = b
	if battle:
		battle.BELT_Z = b
	if player:
		player.belt_z = b

func _dungeon_cam(on: bool) -> void:
	if on:
		if cam_saved.is_empty():
			cam_saved = {"belt": BELT_Z, "ofs": play_ofs, "look": play_look, "fov": play_fov, "var": cam_variant}
		_set_belt(DG_CAM.belt)
		play_ofs = DG_CAM.ofs
		play_look = DG_CAM.look
		play_fov = DG_CAM.fov
		cam_variant = "D2"
	elif not cam_saved.is_empty():
		_set_belt(cam_saved.belt)
		play_ofs = cam_saved.ofs
		play_look = cam_saved.look
		play_fov = cam_saved.fov
		cam_variant = cam_saved["var"]
		cam_saved = {}
	if cam:
		cam.fov = play_fov

func enter_dungeon(diff: String, seed_val: int = -1, theme: String = "t1") -> void:
	for e in battle.enemies.duplicate():
		battle.remove_enemy(e)
	battle.auto_spawn = false
	# ボスの絵はダンジョン用の pck（dg1）。起動を重くしないよう、入るときに読む
	player.locked = true
	if not district.ensure_cached("dg1"):
		loading.show_now()
		if not await district.ensure("dg1"):
			loading.error_text = district.last_error
		loading.hide_soon()
	var tpck: String = DgThemes.THEMES[DgThemes.index_of(theme)].pck   # テーマの部品の pck（T2 dg_t2 など）
	if tpck != "dg1" and not district.ensure_cached(tpck):
		loading.show_now()
		if not await district.ensure(tpck):
			loading.error_text = district.last_error
		loading.hide_soon()
	player.locked = false
	_dungeon_cam(true)
	dungeon = DungeonRun.new()
	dungeon.main = self
	dungeon.diff = diff
	dungeon.theme = theme
	dungeon.seed_val = seed_val
	if dg_perf_n <= 0 and OS.has_environment("DG_PERF"):
		dg_perf_n = int(OS.get_environment("DG_PERF"))
	dungeon.perf_n = dg_perf_n
	add_child(dungeon)
	dungeon.start()

func leave_dungeon() -> void:
	room_theme = "t1"
	_dungeon_cam(false)
	if dungeon:
		dungeon.queue_free()
		dungeon = null
	set_theme_tint(Color(1, 1, 1, 0))
	for a in battle.ally_list():   # 仲間の体力も戻す（specs/dungeon_themes.md 3.4）
		if a.has_method("revive_full"):
			a.revive_full()
	battle.foe_hp_mul = 1.0
	battle.foe_dmg_mul = 1.0
	battle.hp = battle.hp_max
	for e in battle.enemies.duplicate():
		battle.remove_enemy(e)
	if town == "back":
		build_backtown()
		town_floor = "backtown"
		player.position = Vector3(BT.DUNGEON_GATE_X - 2.0, 0, 0.0)
	else:
		build_city()
		player.position = Vector3(GATE_X - 2.0, 0, 0.5)
	player.face = -1
	gate_armed = false
	_place_cam(true)
	battle.auto_spawn = town != "back" and not OS.has_environment("CAPTURE_DUNGEON") and not OS.has_environment("DUNGEON_TEST")
	battle.next_t = 3.0

## 成長をラナと戦闘に反映する
func apply_progress() -> void:
	var r: float = battle.hp / battle.hp_max
	battle.hp_max = progress.hp_max()
	battle.hp = battle.hp_max * r
	battle.atk_mul = progress.atk_mul()
	for a in [player, battle.ally, battle.ranka]:   # スキルツリーの技レベル・派生を読み直す（specs/skill_tree.md）
		if a != null and is_instance_valid(a) and a.has_method("refresh_skills"):
			a.refresh_skills()

func _on_foe_killed(e) -> void:
	if dungeon:
		dungeon.on_foe_killed(e)
		return
	gain_exp(5)

func gain_exp(n: int) -> void:
	var up: int = progress.add_exp(n)
	if up > 0:
		var r: float = battle.hp / battle.hp_max
		apply_progress()
		battle.hp = minf(battle.hp_max, battle.hp_max * r + 30.0)
		fx.number(player.position + Vector3(0, 2.6, 0), progress.lv, "strong")
		fx.levelup(player.position)
		hud.flash_lv()
	progress.save()
