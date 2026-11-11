extends SceneTree
## ランカ（2026-11-12）：操作の入口（?mode=ranka 相当）で、通常攻撃の連なり・3スキル・必殺技 天照・リセット・リリィ同行（自動の仲間2人目の作り）を確かめる。
## 実行：godot --headless --path sequel --fixed-fps 60 --script res://tests/sa2_t7_ranka_test.gd
## 撮影：RANKA_CAPTURE=<フォルダ> を付けて、xvfb の実描画で（--headless を外す）。技ごとの要所を PNG に
var cap := OS.get_environment("RANKA_CAPTURE")
var game

func _initialize():
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	if cap == "":
		return
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(cap.path_join(name + ".png"))

func _fail(msg: String) -> void:
	push_error("RANKA_FAIL: " + msg)
	quit(1)

func _hp_sum() -> float:
	var s := 0.0
	for e in game.battle.enemies:
		s += float(e.hp)
	return s

func _run():
	if cap != "":
		DirAccess.make_dir_recursive_absolute(cap)
	game = load("res://sa2_t5_training_preview.tscn").instantiate()
	game.set("ranka_test_room", true)
	root.add_child(game)
	for frame in 1800:
		if game.get("ranka_test_ready") == true: break
		await process_frame
	if game.get("ranka_test_ready") != true:
		_fail("ranka room not ready")
		return
	var r = game.t7_ranka
	var m = game.t7_manual
	if not (game.player == r and game.battle.player == r and game.ui.player == m and game.ui.lily_controls):
		_fail("ranka is not the controlled actor")
		return
	if game.t2_lily.visible or game.t2_rana.visible or game.battle.ally != null:
		_fail("others visible in solo")
		return
	if m.ult_value() != game.battle.ULT_MAX or r.slot_ids() != ["shot", "ring", "quake"]:
		_fail("gauge/slots")
		return
	if game.battle.enemies.size() != 3:
		_fail("targets")
		return
	await _frames(30)
	await _shot("00_room")
	# 通常攻撃：押し続けると c1 → c2 → c3 → 掌底
	var seen := []
	for k in 240:
		if r.state == "move" or m.attack_queued == false:
			m.attack_press()
		if r.state == "atk" and (seen.is_empty() or seen.back() != r.clip) and r.clip != "atk_back":
			seen.append(r.clip)
		if k == 26: await _shot("01_c1")
		await process_frame
		if seen.size() >= 4:
			break
	print("RANKA chain ", seen)
	if seen.slice(0, 4) != ["atk_c1", "atk_c2", "atk_c3", "atk_palm"]:
		_fail("chain order " + str(seen))
		return
	await _frames(90)
	# 単発の c1 → 戻り（atk_back）→ 構え
	m.attack_press()
	var backed := false
	for k in 120:
		backed = backed or r.clip == "atk_back"
		await process_frame
	if not backed or r.state != "move":
		_fail("c1 recovery " + r.clip + " " + r.state)
		return
	# スキル
	game._ranka_reset_room()
	await _frames(10)
	for id in ["shot", "ring", "quake"]:
		game._ranka_reset_room()
		await _frames(5)
		var before := _hp_sum()
		if not m.use_skill(id):
			_fail("use_skill " + id)
			return
		var t := 0
		while r.state == "skill" and t < 600:
			await process_frame
			t += 1
			if cap != "" and t in ([30, 60, 90] if id != "quake" else [60, 80, 100, 130]):
				await _shot("02_%s_%d" % [id, t])
		var dealt := before - _hp_sum()
		print("RANKA skill %s frames=%d dealt=%.0f cd=%.1f" % [id, t, dealt, float(r.sk_cd[id])])
		if dealt <= 0.0 or float(r.sk_cd[id]) <= 0.0:
			_fail("skill had no effect " + id)
			return
	# 必殺技 天照：画面の敵すべてに当たる、ゲージを 100 使う
	game._ranka_reset_room()
	await _frames(5)
	var hp0 := []
	for e in game.battle.enemies:
		hp0.append(float(e.hp))
	m.use_ult()
	if r.state != "ult":
		_fail("ult did not start")
		return
	var u := 0
	while r.state == "ult" and u < 900:
		await process_frame
		u += 1
		if cap != "" and u in [10, 60, 100, 130, 162, 168, 180]:
			await _shot("03_ult_%d" % u)
	var all_hit := true
	for i in game.battle.enemies.size():
		all_hit = all_hit and float(game.battle.enemies[i].hp) < float(hp0[i])
	print("RANKA ult frames=%d all_hit=%s gauge=%.0f" % [u, str(all_hit), game.battle.ranka_ult])
	if not all_hit or game.battle.ranka_ult != 100.0 or game.battle.cine or game.battle.cam_focus != null:
		_fail("ult result")
		return
	# リリィ同行：自動の仲間が戦う（2人目の仲間の作り）、ゲージは別
	game.ranka_lily_button.emit_signal("pressed")
	await _frames(5)
	if game.battle.ally != game.t2_lily or not game.t2_lily.visible:
		_fail("lily join")
		return
	var lily_ult0: float = game.battle.ally_ult
	var before2 := _hp_sum()
	for k in 360:
		await process_frame
	await _shot("04_with_lily")
	print("RANKA with lily dealt=%.0f lily_ult %.0f->%.0f ranka_ult=%.0f lily_skills=%s" % [before2 - _hp_sum(), lily_ult0, game.battle.ally_ult, game.battle.ranka_ult, str(game.t2_lily.sk_used)])
	if before2 - _hp_sum() <= 0.0:
		_fail("lily did not fight")
		return
	# 会話の立ち絵
	game._ranka_toggle_idle()
	await _frames(20)
	if not game.event_idles.ranka.visible or r.sprite.visible:
		_fail("event idle")
		return
	await _shot("05_event_idle")
	game._ranka_toggle_idle()
	# 撃破で経験値が増えない
	var xp: int = game.progress.xp
	game._on_foe_killed(game.battle.enemies[0])
	if game.progress.xp != xp:
		_fail("xp changed")
		return
	print("RANKA_PASS")
	quit(0)
