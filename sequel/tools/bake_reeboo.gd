extends SceneTree
## REEBO0 Stylized 2D VFX Lite の4種を、連番の絵（黒地・横に並べたアトラス）に焼く（2026-11-07、specs/vfx_overhaul.md）。
## 理由：iPhone（Safari）で REEBO のシェーダーが動かず、白い四角（quad.png）が光って見えた → ゲームでは絵をめくるだけにする。
## 黒地に描くのは、ゲームの 2D の層が黒地＋加算だから（同じ見た目になる）。色は白の tint で焼き、ゲームで色を掛ける。
## 使い方（xvfb・opengl3・--fixed-fps 30 で毎回同じ）：
##   xvfb-run -a godot --path sequel --rendering-driver opengl3 --fixed-fps 30 -s res://tools/bake_reeboo.gd
## 出力：assets/vfx/reeboo_<名前>.png（1コマ CELL px、COLS 列）と reeboo.json（コマ数・fps・列数）
const CELL := 320
const COLS := 8
const FPS := 30
const LIST := {"hit_spark": 0.5, "slash_arc": 0.35, "explosion_small": 1.02, "coin_pickup": 0.9}
const SCALE := 1.2     # 元の大きさ（爆発の輪で約 250px）を 1.2 倍で焼く（はみ出さない）

func _init() -> void:
	_run.call_deferred()

func _fix_align(n: Node) -> void:
	for c in n.get_children():
		if c is GPUParticles2D:
			c.use_fixed_seed = true
			c.seed = 7
			if c.process_material is ParticleProcessMaterial and c.process_material.particle_flag_align_y:
				var pm: ParticleProcessMaterial = c.process_material.duplicate()
				pm.particle_flag_align_y = false
				pm.angle_min = -180.0
				pm.angle_max = 180.0
				c.process_material = pm
		_fix_align(c)

func _run() -> void:
	var out := ProjectSettings.globalize_path("res://assets/vfx")
	DirAccess.make_dir_recursive_absolute(out)
	var meta := {}
	for name in LIST:
		var sv := SubViewport.new()
		sv.size = Vector2i(CELL, CELL)
		sv.transparent_bg = false
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new()
		bg.color = Color.BLACK
		bg.size = Vector2(CELL, CELL)
		sv.add_child(bg)
		root.add_child(sv)
		var fx = load("res://addons/reeboo_fx2d/effects/%s.tscn" % name).instantiate()
		fx.autoplay = false
		fx.free_when_done = false
		_fix_align(fx)
		if fx.has_node("Smoke"):   # 灰色の煙は焼かない（ゲームの層は加算なので暗くできず、灰色の光の塊になる）
			fx.get_node("Smoke").visible = false
		fx.position = Vector2(CELL * 0.5, CELL * 0.5)
		fx.scale = Vector2(SCALE, SCALE)
		sv.add_child(fx)
		await process_frame
		fx.play()
		var n := int(ceil(float(LIST[name]) * FPS)) + 1
		var rows := int(ceil(float(n) / COLS))
		var atlas := Image.create(CELL * COLS, CELL * rows, false, Image.FORMAT_RGB8)
		for i in n:
			await process_frame
			await RenderingServer.frame_post_draw
			var im := sv.get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			atlas.blit_rect(im, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLS) * CELL, (i / COLS) * CELL))
		# 明るさだけ（いちばん明るい色の値）を RGB の3つに同じ値で入れる。色はゲームで掛ける。
		# 事実（2026-11-07）：白黒（L8）で保存すると Web（WebGL2）では表示されなかった（推測：L8 は色の並べ替え swizzle で表すが WebGL2 に無い）→ RGB で保存
		var gray := Image.create(atlas.get_width(), atlas.get_height(), false, Image.FORMAT_RGB8)
		for y in atlas.get_height():
			for x in atlas.get_width():
				var c := atlas.get_pixel(x, y)
				var v := maxf(c.r, maxf(c.g, c.b))
				gray.set_pixel(x, y, Color(v, v, v))
		gray.save_png(out + "/reeboo_%s.png" % name)
		meta[name] = {"frames": n, "fps": FPS, "cols": COLS, "cell": CELL, "scale": SCALE}
		print("焼いた ", name, " ", n, " コマ")
		sv.queue_free()
	var f := FileAccess.open(out + "/reeboo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	quit()
