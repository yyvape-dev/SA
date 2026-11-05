extends Node3D
## One-building facade fit test. Uses the existing 3D greybox as-is.
## Required local asset: res://fit_assets/tavern_front.png
## The asset is a mechanical background extraction from the approved tavern illustration.
## This scene deliberately does not modify or replace the source greybox.

const GREYBOX := preload("res://greybox_city.tscn")
const TAVERN_FRONT := "res://fit_assets/tavern_front.png"

func _ready() -> void:
	var stage := GREYBOX.instantiate()
	stage.name = "GreyboxStage"
	add_child(stage)
	# Defer until the stage has constructed its procedural meshes.
	call_deferred("_apply_facade", stage)

func _apply_facade(stage: Node3D) -> void:
	if not ResourceLoader.exists(TAVERN_FRONT):
		push_error("Missing local tavern PNG: " + TAVERN_FRONT)
		return
	# The existing block is 9.5 m wide and 6.9 m high.
	# Its FRONT is z=-4.35. The facade is offset toward camera to avoid z-fighting.
	# Hide only the tavern's 3D ornaments that would double up with the artwork.
	for node in stage.get_children():
		if node.name.begins_with("Tavern ") and node.name != "TAVERN solid shell":
			node.visible = false
	var texture := load(TAVERN_FRONT) as Texture2D
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	var panel := MeshInstance3D.new()
	panel.name = "TAVERN only - flat facade texture test"
	var quad := QuadMesh.new()
	quad.size = Vector2(9.5, 6.9)
	panel.mesh = quad
	panel.material_override = material
	panel.position = Vector3(-13.0, 3.45, -4.30)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(panel)
	print("TAVERN_FIT: facade panel 9.5x6.9 at x=-13.0, z=-4.30")

	if OS.has_environment("CAPTURE_TAVERN"):
		_capture_fit(stage)

func _capture_fit(stage: Node3D) -> void:
	# Disable camera tracking so oblique and wide cameras remain reproducible.
	stage.set_process(false)
	stage.set_physics_process(false)
	var output := ProjectSettings.globalize_path("res://captures/tavern_fit")
	DirAccess.make_dir_recursive_absolute(output)
	var camera: Camera3D = stage.cam
	var player: CharacterBody3D = stage.player
	var shots := [
		["01_front", Vector3(-13, 6.8, 18), Vector3(-13, 3.1, -4.35)],
		["02_oblique", Vector3(-0.5, 8.5, 12), Vector3(-13, 3.2, -6)],
		["03_wide", Vector3(0, 16, 43), Vector3(0, 2.5, -4)],
	]
	for shot in shots:
		player.position = Vector3(-13, 0.04, 0.8)
		stage.contact_shadow.position = Vector3(-13, 0.02, 0.8)
		camera.position = shot[1]
		camera.look_at(shot[2])
		await _save_view(output, shot[0])
	# Exercise existing physics/input code for one second, rather than teleporting.
	player.position = Vector3(-13, 0.04, 2)
	stage.set_physics_process(true)
	Input.action_press("ui_up")
	for i in range(60):
		await get_tree().physics_frame
	Input.action_release("ui_up")
	stage.set_physics_process(false)
	var depth_end := player.position
	print("TAVERN_DEPTH_MOVEMENT start_z=2 end=", depth_end)
	assert(depth_end.z < -1.0, "Depth movement failed")
	# Same camera and X, player on either side of an existing solid pole.
	camera.position = Vector3(2.65, 6.8, 18)
	camera.look_at(Vector3(2.65, 1.25, -0.8))
	stage.contact_shadow.visible = false
	for z in [-0.8, 3.0]:
		player.position = Vector3(2.65, 0.04, z)
		stage.portrait.visible = true
		var label := "04_behind_pole" if z < 0 else "05_front_of_pole"
		await _save_view(output, label)
		stage.portrait.visible = false
		await _save_view(output, label + "_no_player")
	var metadata := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(),
		"source": TAVERN_FRONT,
		"panel_m": [9.5, 6.9], "depth_start_z": 2.0,
		"depth_end": [depth_end.x, depth_end.y, depth_end.z],
		"capture": "Viewport.get_texture().get_image() after frame_post_draw"
	}
	var file := FileAccess.open(output.path_join("capture_metadata.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "  "))
	file.close()
	get_tree().quit()

func _save_view(output: String, label: String) -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	assert(not img.is_empty(), "Empty Godot viewport")
	var result := img.save_png(output.path_join(label + ".png"))
	assert(result == OK, "PNG save failed")
	print("TAVERN_CAPTURE ", label, " ", img.get_size())
