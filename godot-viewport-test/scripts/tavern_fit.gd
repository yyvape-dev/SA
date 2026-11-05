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
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
