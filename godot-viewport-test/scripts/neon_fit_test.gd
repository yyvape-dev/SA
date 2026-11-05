extends Node3D
## Existing-assets overlay for 2.5D art fit. No image generation.
## Keep original main.tscn / scripts/stage.gd untouched.

const BG := "res://fit_assets/neon_bg.png"
const PROP_DIR := "res://fit_assets/"

func _ready() -> void:
	var stage: Node3D = $OriginalStage
	# Retain the original 3D floor collision, camera and character.
	for n in stage.get_children():
		if n is CharacterBody3D or n is Camera3D or n is WorldEnvironment or n is DirectionalLight3D:
			continue
		if n.name == "3D floor / collision" or n.name == "Contact shadow":
			continue
		n.queue_free()
	stage.floor_material.albedo_color = Color("323344")
	stage.floor_material.albedo_texture = null
	var background := Sprite3D.new()
	background.name = "Original 2D neon backdrop - unchanged"
	background.texture = load(BG)
	background.pixel_size = 0.032
	background.position = Vector3(0.0, 10.5, -19.0)
	background.shaded = false
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(background)
	_add_prop(stage, "Pole (front occluder)", "pole.png", Vector3(-8.0, 2.65, 3.4), 0.010)
	_add_prop(stage, "Motorcycle (middle)", "bike.png", Vector3(4.0, 1.18, 0.9), 0.009)
	_add_prop(stage, "Car (rear)", "car.png", Vector3(9.5, 1.25, -2.8), 0.009)
	_add_prop(stage, "Fence (rear)", "fence.png", Vector3(-4.8, 1.30, -3.5), 0.009)
	_add_prop(stage, "Pipes (front)", "pipes.png", Vector3(8.0, 1.25, 4.5), 0.009)
	_add_prop(stage, "Barricade (front)", "barricade.png", Vector3(-2.7, 1.0, 4.65), 0.007)

func _add_prop(stage: Node3D, title: String, file: String, pos: Vector3, pixel_size: float) -> void:
	var prop := Sprite3D.new()
	prop.name = title
	prop.texture = load(PROP_DIR + file)
	prop.pixel_size = pixel_size
	prop.position = pos
	prop.shaded = false
	prop.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	prop.alpha_scissor_threshold = 0.25
	prop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(prop)
