extends Node3D
## 融合都市の1区画（縦切り）。街を左右と奥行きで歩く。
## 起動の切り替え（環境変数）：
##   CAPTURE_GUIDE=1 … 外部AIに渡す下絵を art/guide/ に書き出して終了（=<部品のid> でその部品だけ）
##   CAPTURE_PLAY=1  … 動作確認の画面を captures/ に書き出して終了

const City := preload("res://scripts/city_block1.gd")
const BT := preload("res://scripts/backtown_block.gd")
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
	town = OS.get_environment("TOWN")
	if _q("town=back"):
		town = "back"
	if town == "back":
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
		# 確認用：?at=gate で入口の前から始める
		if str(JavaScriptBridge.eval("window.location.search")).contains("at=gate"):
			player.position = Vector3(GATE_X - 0.5, 0, BELT_Z.x + 1.6)
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

func _process(delta: float) -> void:
	if player == null:
		return   # 地区の読み込み中
	_place_cam(false, delta)
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
	if fx:
		fx.screen_mat = m   # 衝撃波の画面のゆがみ

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
		var near := Vector3(fo.position.x + fo.face * 0.6, 0, fo.position.z) + ULT_OFS
		cam.position = want.lerp(near, zz)
		cam.look_at(Vector3(cam.position.x, 0, fo.position.z * zz) + play_look.lerp(ULT_LOOK, zz), Vector3.UP)
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

func _build_floor() -> void:
	cobble_tex = load("res://assets/ground/cobble.png")
	slab_tex = load("res://assets/ground/slab.png")
	# 地面はコード（前作の教訓：AIの一枚絵は継ぎ目が苦手）。外部AIの継ぎ目の無い素材を繰り返して敷く。
	# 奥の歩道・帯（車道の石畳）・手前の歩道。キャラとエフェクトが沈まないよう暗めにする（FLOOR_DIM）。
	_ground(Vector3(0, 0.0, -5.2), Vector2(60, 3.0), slab_tex, SLAB_TILE)     # 奥の歩道
	_ground(Vector3(0, -0.03, 0.15), Vector2(60, 7.6), cobble_tex, COBBLE_TILE) # 帯（石畳の通り）
	_ground(Vector3(0, 0.0, 5.6), Vector2(60, 3.2), slab_tex, SLAB_TILE)      # 手前の歩道
	for z in [-1.2, 1.6]:   # 路面電車の線路（真鍮の細い線）
		var r := _slab(Vector3(0, -0.02, z), Vector3(60, 0.04, 0.06), Color("b8933f"))
		var rm: StandardMaterial3D = r.material_override
		rm.metallic = 0.6
		rm.roughness = 0.35
	# 奥の地面（建物の後ろ〜遠景の板）：奥ほど遠景の下端の霧の色（z_skyline の地平あたりの平均 ≈ #684c53）に溶ける
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

func _ground(c: Vector3, size: Vector2, tex: Texture2D, tile: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = Color(FLOOR_DIM * 0.97, FLOOR_DIM * 0.94, FLOOR_DIM * 1.04)   # ごく弱い紫（奥行きの霧の最弱）
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
	var at := {"rush": [0.12, 0.25, 0.45], "barrage": [0.6, 1.0, 1.5, 1.7], "storm": [0.47, 0.8, 1.18], "ult": [0.15, 0.75, 1.42, 2.0, 2.45, 2.7]}
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

# ---------- 裏の町の入り口の下絵（specs/backtown_blockout.md、2026-11-08） ----------
var bt_marks := []   # 撮影の書き込み用 [種類, 名前, 世界の位置]

func _bt_mat(key: String) -> StandardMaterial3D:
	var col: Color = BT.MAT[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # 下絵は色の意味を見せる（光は塗る段階で付ける）
	if key.begins_with("neon") or key in ["lamp", "screen", "window"]:
		m.albedo_color = col * 1.25   # 光る物（3D の glow で少しにじむ）
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

func build_backtown() -> void:
	_clear_level()
	_build_floor()
	bt_marks.clear()
	BELT_Z = BT.BELT_Z
	var wz: float = BT.WALL_Z
	var h: float = BT.WALL_H
	# 3. 正面の壁（棟ごとに 1 つの Node3D ＝ 1 枚の絵）。面は z = wz の板、奥行き 3m の箱の側面は暗い単色
	for w in BT.walls():
		var root := Node3D.new()
		root.name = w.id
		level.add_child(root)
		piece_nodes[w.id] = root
		var x0: float = w.x0
		var x1: float = w.x1
		_bt_box(root, Vector3((x0 + x1) * 0.5, h * 0.5, wz - 1.5), Vector3(x1 - x0, h, 3.0), "side")   # 胴（側面は暗い）
		_bt_box(root, Vector3((x0 + x1) * 0.5, h * 0.5, wz - 0.02), Vector3(x1 - x0, h, 0.04), w.base, "face")   # 正面の板（ここに絵を貼る）
		for pt in w.parts:
			var dep: float = pt[5]
			var sz := Vector3(pt[2] - pt[0], pt[3] - pt[1], maxf(dep, 0.02))
			_bt_box(root, Vector3((pt[0] + pt[2]) * 0.5, (pt[1] + pt[3]) * 0.5, wz + sz.z * 0.5 + 0.01), sz, pt[4])
		bt_marks.append(["wall", w.id, Vector3((x0 + x1) * 0.5, 0, wz)])
	# 壁の間：柱（足場の鉄骨）／路地の口（暗い隙間、奥の側壁、遠景が見える）
	for g in BT.gaps():
		var gx: float = (g.x0 + g.x1) * 0.5
		var gw: float = g.x1 - g.x0
		if g.kind == "pillar":
			_bt_box(level, Vector3(gx, h * 0.5, wz + 0.15), Vector3(gw, h, 0.5), "scaffold")
		else:
			for sx in [g.x0, g.x1]:
				_bt_box(level, Vector3(sx, h * 0.5, wz - 7.0), Vector3(0.2, h, 14.0), "shadow")
			_bt_box(level, Vector3(gx, -0.01, wz - 7.0), Vector3(gw, 0.02, 14.0), "dark")
	# 4. 頭上：垂れ幕・灯り・渡り廊下の桁、提灯のたるみ
	var ov := Node3D.new()
	ov.name = "overhead"
	level.add_child(ov)
	piece_nodes["overhead"] = ov
	for o in BT.overhead():
		_bt_box(ov, Vector3((o[0] + o[2]) * 0.5, (o[1] + o[3]) * 0.5, o[4]), Vector3(o[2] - o[0], o[3] - o[1], 0.05), o[5])
	for sg in BT.SAGS:
		var n := 24
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var pa := Vector3(lerpf(sg[0], sg[1], u0), lerpf(sg[2], sg[3], 1.0 - pow(2.0 * u0 - 1.0, 2.0)), sg[4])
			var pb := Vector3(lerpf(sg[0], sg[1], u1), lerpf(sg[2], sg[3], 1.0 - pow(2.0 * u1 - 1.0, 2.0)), sg[4])
			var mid := (pa + pb) * 0.5
			var seg := _bt_box(ov, mid, Vector3((pb - pa).length(), 0.04, 0.04), "cable")
			seg.rotation.z = atan2(pb.y - pa.y, pb.x - pa.x)
		for k in int(sg[5]):
			var u := (float(k) + 0.5) / float(sg[5])
			var y: float = lerpf(sg[2], sg[3], 1.0 - pow(2.0 * u - 1.0, 2.0))
			_bt_box(ov, Vector3(lerpf(sg[0], sg[1], u), y - 0.25, sg[4]), Vector3(0.28, 0.36, 0.28), "lamp")
	# 1. 手前の物（帯の手前）
	var fgn := Node3D.new()
	fgn.name = "foreground"
	level.add_child(fgn)
	piece_nodes["foreground"] = fgn
	for f in BT.FG:
		_bt_box(fgn, Vector3(f[0], f[4] + f[2] * 0.5, BT.FG_Z), Vector3(f[1], f[2], 0.3), f[3])
	# 5. 遠景：見える窓（z −62 で 0〜7m）だけの横長の書き割り。塔の影と、地平で紫に光る門
	var far := Node3D.new()
	far.name = "far"
	level.add_child(far)
	piece_nodes["far"] = far
	_bt_box(far, Vector3(0, BT.FAR_H * 0.5, BT.FAR_Z), Vector3(BT.FAR_W, BT.FAR_H, 0.1), "cloth2")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tx := -BT.FAR_W * 0.5 + 1.0
	while tx < BT.FAR_W * 0.5 - 1.0:
		var tw := rng.randf_range(1.2, 3.0)
		_bt_box(far, Vector3(tx + tw * 0.5, rng.randf_range(2.5, 6.5) * 0.5, BT.FAR_Z + 0.1), Vector3(tw, 0, 0.1), "dark")
		var th := rng.randf_range(2.5, 6.8)
		far.get_child(far.get_child_count() - 1).mesh.size.y = th
		far.get_child(far.get_child_count() - 1).position.y = th * 0.5
		tx += tw + rng.randf_range(0.3, 1.5)
	_bt_box(far, Vector3(0, 2.2, BT.FAR_Z + 0.2), Vector3(5.0, 4.4, 0.1), "neon_v")   # 門の光（中央）
	_bt_box(far, Vector3(0, 2.2, BT.FAR_Z + 0.25), Vector3(3.0, 3.6, 0.1), "dark")
	# 印（扉・屋台・路地・人混みの帯）。撮影の書き込みと、後で作る扉の仕組みの位置。下絵（正面図）には写さない
	var mk := Node3D.new()
	mk.name = "marks"
	level.add_child(mk)
	piece_nodes["marks"] = mk
	for d in BT.DOORS:
		for sx in [-1.0, 1.0]:
			_bt_box(mk, Vector3(d.x + sx * d.w * 0.5, d.h * 0.5, wz + 0.08), Vector3(0.06, d.h, 0.06), "neon_g")
		_bt_box(mk, Vector3(d.x, d.h, wz + 0.08), Vector3(d.w, 0.06, 0.06), "neon_g")
		_bt_box(mk, Vector3(d.x, 0.015, wz + 0.8), Vector3(d.w, 0.02, 1.4), "neon_g")
		bt_marks.append(["door", d.id, Vector3(d.x, d.h, wz)])
	for st in BT.STALLS:
		var disc := _bt_box(mk, Vector3(st.npc_x, 0.015, wz + 1.25), Vector3(0.7, 0.02, 0.7), "neon_c")
		bt_marks.append(["stall", st.id, Vector3(st.x, 2.4, wz)])
	for al in BT.ALLEYS:
		_bt_box(mk, Vector3(al.x, 0.015, wz + 0.3), Vector3(al.w, 0.02, 0.4), "lamp")
		bt_marks.append(["alley", al.id, Vector3(al.x, 2.0, wz)])
	var crowd_mark := _bt_box(mk, Vector3(0, 0.012, (BT.CROWD_Z.x + BT.CROWD_Z.y) * 0.5), Vector3(32.0, 0.01, BT.CROWD_Z.y - BT.CROWD_Z.x), "awning")
	crowd_mark.material_override.albedo_color.a = 0.35
	crowd_mark.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_build_crowd()   # 人混み（前作の町の人を仮に。暗く、z −6.2〜−4.7）
	glints = []
	cam_x = Vector2(BT.ROOM_X.x + 4.92, BT.ROOM_X.y - 4.92)
	if battle:
		battle.glints = glints
		battle.ROOM_X = BT.ROOM_X
		battle.BELT_Z = BELT_Z
	if player:
		player.room_x = BT.ROOM_X
		player.belt_z = BELT_Z

## 裏の町の下絵の撮影（TOWN=back FX_ONLY=backtown）：
##   ① ゲームの画面（カメラ D2）でラナを帯の中央に、カメラの左端・中央・右端 → captures/bt_play_<l|c|r>.png（印の画面の位置を BTMARK で出す）
##   ② 正投影の正面図（マゼンタの地）→ art/guide_bt/<id>.png と guide.json（部品の範囲・1m の画素・扉・屋台・路地のデータ）
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
	for side in [["l", cam_x.x], ["c", 0.0], ["r", cam_x.y]]:
		player.position = Vector3(side[1], 0, 0)
		player.face = 1
		_place_cam(true)
		battle.apply_light(player.sprite, player.mat, player.refl, player.position)
		for show_ui in [false, true]:
			ui.visible = show_ui
			for f in 5:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir + "/bt_play_%s%s.png" % [side[0], "_ui" if show_ui else ""])
		for m in bt_marks:
			if not cam.is_position_behind(m[2]):
				var sp := cam.unproject_position(m[2])
				print("BTMARK %s %s %s %.4f %.4f" % [side[0], m[0], m[1], sp.x / vh.x, sp.y / vh.y])
		for yy in [0.0, 4.0, 14.0]:
			var sp2 := cam.unproject_position(Vector3(cam.position.x, yy, BT.WALL_Z))
			print("BTLINE %s wall_y%d %.4f" % [side[0], int(yy), sp2.y / vh.y])
		var head := cam.unproject_position(player.position + Vector3(0, player.HEIGHT_M, 0))
		var foot := cam.unproject_position(player.position)
		print("BTRANA %s %.4f %.4f %.4f" % [side[0], foot.x / vh.x, foot.y / vh.y, head.y / vh.y])
	ui.visible = true
	await _bt_guides()

func _bt_guides() -> void:
	var out := ProjectSettings.globalize_path("res://art/guide_bt")
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var rc := Camera3D.new()
	rc.projection = Camera3D.PROJECTION_ORTHOGONAL
	rc.keep_aspect = Camera3D.KEEP_HEIGHT
	vp.add_child(rc)
	var renv := Environment.new()
	renv.background_mode = Environment.BG_COLOR
	renv.background_color = MAGENTA
	rc.environment = renv
	player.visible = false
	for c in crowd:
		c.node.visible = false
	var floor_nodes := []
	for ch in level.get_children():
		if ch is MeshInstance3D and (ch.mesh is PlaneMesh):
			floor_nodes.append(ch)
	const PX_PER_M := 64.0   # 正面図の細かさ（1m＝64px。壁 1 棟 5m×14m で約 320×900px）
	var walls := {}
	for w in BT.walls():
		walls[w.id] = [w.x0 - 0.4, 0.0, w.x1 + 0.4, BT.WALL_H]
	var shots := {"key_front": [-16.0, 0.0, 16.0, BT.WALL_H], "overhead": [-16.0, 2.5, 16.0, 9.0], "foreground": [-14.5, 0.0, 14.5, 6.0],
		"far": [-BT.FAR_W * 0.5, 0.0, BT.FAR_W * 0.5, BT.FAR_H]}
	for k in walls:
		shots[k] = walls[k]
	var meta := {"px_per_m": PX_PER_M, "wall_z": BT.WALL_Z, "visible_top_m": {"wall": 3.98, "overhead_z-4": 3.89, "far": 5.98},
		"doors": BT.DOORS, "stalls": BT.STALLS, "alleys": BT.ALLEYS, "parts": {}}
	for id in shots:
		var r: Array = shots[id]
		var wpx := int(round((r[2] - r[0]) * PX_PER_M))
		var hpx := int(round((r[3] - r[1]) * PX_PER_M))
		var k := 1.0
		if wpx > 2048:   # 1 枚 2048px まで（spec の 8）。遠景・区画全体は縮めて撮る
			k = 2048.0 / wpx
		vp.size = Vector2i(int(wpx * k), int(hpx * k))
		rc.size = r[3] - r[1]
		rc.position = Vector3((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5, 40.0)
		# 見せる物：key_front＝壁・柱・路地・頭上・遠景、壁＝その棟だけ、頭上・手前・遠景はそれだけ
		for ch in level.get_children():
			var nm := String(ch.name)
			var vis := true
			if nm == "marks" or ch in floor_nodes or ch is Sprite3D:   # 印・床・人混みは写さない
				vis = false
			elif id == "key_front":
				vis = nm != "foreground"
			elif id == "overhead" or id == "foreground" or id == "far":
				vis = nm == id
			else:
				vis = nm == id
			ch.visible = vis
		for f in 4:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/%s.png" % id)
		meta.parts[id] = {"x0": r[0], "y0": r[1], "x1": r[2], "y1": r[3], "w": vp.size.x, "h": vp.size.y, "px_per_m": PX_PER_M * k}
		print("BTGUIDE %s %dx%d" % [id, vp.size.x, vp.size.y])
	for ch in level.get_children():
		ch.visible = true
	for c in crowd:
		c.node.visible = true
	player.visible = true
	vp.queue_free()
	var f2 := FileAccess.open(out + "/guide.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify(meta, "  "))
	f2.close()
	var g := FileAccess.open(out + "/.gdignore", FileAccess.WRITE)
	g.close()

## ダンジョンの部屋：歓楽街の部品を並べ替えて置く（ofs の使い回し）。spec は dungeon_map.gd の部屋。
func build_room(spec: Dictionary) -> void:
	_clear_level()
	_build_floor()
	var by_id := {}
	for p in City.pieces():
		by_id[p.id] = p
	var rw: float = spec.rw
	# 裏通りの列と遠景はそのまま（少し横へずらして毎回の見え方を変える）
	_build_piece(by_id["b0_backrow"], Vector3(spec.back_ofs, 0, 0), "b0_room")
	_build_piece(by_id["z_skyline"])
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
	cam_x = Vector2(-maxf(0.0, rw - PLAY_HALF_W), maxf(0.0, rw - PLAY_HALF_W))
	battle.glints = glints
	battle.ROOM_X = Vector2(-rw, rw)
	player.room_x = Vector2(-rw, rw)

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
		var m = ch.material_override
		if m is StandardMaterial3D and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			if ch.name == "band":
				m.albedo_color = Color(col.r, col.g, col.b, a)
			else:
				m.albedo_color = col

## 街の端（高架の下）のダンジョンの入口：奥の歩道側の門。紫＝どちらの陣営でもない。
const GATE_COL := Color(0.72, 0.5, 1.0)
const GATE_SHADER := preload("res://scripts/gate.gdshader")
func _build_gate() -> void:
	gate = make_portal(Vector3(GATE_X, 0, BELT_Z.x - 0.15), true, 2.6, GATE_COL)
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
	glints.append({"x": GATE_X, "y": 2.0, "z": BELT_Z.x - 0.2, "w": 1.6, "col": [GATE_COL.r, GATE_COL.g, GATE_COL.b], "p": 0.8, "len": 4.0})

func _check_gate() -> void:
	if gate == null or dungeon != null or player == null:
		return
	set_portal_color(gate, GATE_COL, 0.4 + 0.25 * sin(Time.get_ticks_msec() * 0.004))
	var near: bool = absf(player.position.x - GATE_X) < 1.4 and player.position.z < BELT_Z.x + 0.7
	if near and gate_armed and not hud.menu_open:
		gate_armed = false
		hud.open_menu()
	elif not near:
		gate_armed = true

var next_seed := -1   # 撮影の自動入力が決めた間取りの種（-1＝毎回ランダム）
func dungeon_seed() -> int:
	var s := next_seed
	next_seed = -1
	return s

func enter_dungeon(diff: String, seed_val: int = -1) -> void:
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
	player.locked = false
	dungeon = DungeonRun.new()
	dungeon.main = self
	dungeon.diff = diff
	dungeon.seed_val = seed_val
	add_child(dungeon)
	dungeon.start()

func leave_dungeon() -> void:
	if dungeon:
		dungeon.queue_free()
		dungeon = null
	battle.foe_hp_mul = 1.0
	battle.foe_dmg_mul = 1.0
	battle.hp = battle.hp_max
	for e in battle.enemies.duplicate():
		battle.remove_enemy(e)
	build_city()
	player.position = Vector3(GATE_X - 2.0, 0, 0.5)
	player.face = -1
	gate_armed = false
	_place_cam(true)
	battle.auto_spawn = not OS.has_environment("CAPTURE_DUNGEON") and not OS.has_environment("DUNGEON_TEST")
	battle.next_t = 3.0

## 成長をラナと戦闘に反映する
func apply_progress() -> void:
	var r: float = battle.hp / battle.hp_max
	battle.hp_max = progress.hp_max()
	battle.hp = battle.hp_max * r
	battle.atk_mul = progress.atk_mul()

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
