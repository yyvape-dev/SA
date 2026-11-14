extends SceneTree
## Review-only capture driver. Does not write the user's production saves.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var view = load("res://sa2_prologue_preview.tscn").instantiate()
	view.auto_load = false
	view.save_path = "user://sa2_prologue_capture.json"
	root.add_child(view)
	await process_frame
	var folder := "res://docs/prologue_20261114"
	for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720)]:
		root.size = dimensions
		for beat in ["morning", "breakfast", "talk_lily", "find_note", "note", "promise", "three_days", "audience", "lamp", "departure", "ending"]:
			if OS.has_environment("PROLOGUE_CAPTURE_BEAT") and not beat in OS.get_environment("PROLOGUE_CAPTURE_BEAT").split(","): continue
			view._replace_dialogue()
			view.state.beat_id = beat
			view.state.line_id = ""
			view.state.player = Vector2(-1.8, 0)
			view.state.facing = -1 if beat == "promise" else 1
			if beat == "note" or beat == "promise": view.state.player = Vector2(2.2, 0)
			view.present()
			if view.dialogue.active: view.dialogue.advance()
			# Finish any room fade, but leave the real camera and UI intact.
			if view.fade_tween: view.fade_tween.kill()
			view.fade.color.a = 0
			for i in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var output := "%s/%s_%dx%d.png" % [folder, beat, dimensions.x, dimensions.y]
			root.get_texture().get_image().save_png(output)
			var foot: Vector2 = view.room.camera.unproject_position(view.room.actors.rana.position)
			var panel_y: float = view.dialogue.get_node("Panel").get_global_rect().position.y
			print("PROLOGUE_CAPTURE ", output, " foot=", foot, " panel_y=", panel_y)
	view.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sa2_prologue_capture.json"))
	quit()
