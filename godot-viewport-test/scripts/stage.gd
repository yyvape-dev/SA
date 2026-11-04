extends Node3D
## Fixed-angle 2.5D belt-scroller demo. 3D geometry + an ORIGINAL 2D character texture.
## No UI and no enemies. The character is a static cutout for camera/depth evaluation.

const SPEED := 5.5
const GRAVITY := 24.0
const JUMP_SPEED := 8.2
const STAGE_HALF_X := 28.0
const STAGE_HALF_Z := 4.15

var player: CharacterBody3D
var portrait: Sprite3D
var cam: Camera3D
var target_projection_ortho := false
var elapsed := 0.0
var moving := false
var last_direction := 1
var floor_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var trim_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var gold_material: StandardMaterial3D
var banner_tex: Texture2D

func _ready() -> void:
	_build_materials()
	_build_lighting()
	_build_ground()
	_build_architecture()
	_build_character()
	_build_camera()
	if OS.has_environment("CAPTURE_STAGE"):
		_capture_stage()

func _process(delta: float) -> void:
	elapsed += delta
	if player != null and contact_shadow != null:
		contact_shadow.global_position = Vector3(player.global_position.x, 0.023, player.global_position.z)
	if player == null or cam == null:
		return
	# Camera tracks horizontal progress but never rotates. Depth motion is real world-space Z.
	var desired := Vector3(player.global_position.x, 6.8, 17.0)
	cam.global_position = cam.global_position.lerp(desired, min(1.0, delta * 3.2))
	# Slight vertical offset is a PLACEHOLDER, not generated animation.
	portrait.position.y = 1.55 + (sin(elapsed * 10.0) * 0.035 if moving else 0.0)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var x := Input.get_axis("ui_left", "ui_right")
	var z := (1.0 if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) else 0.0)
	var direction := Vector2(x, z).normalized()
	moving = direction.length_squared() > 0.001
	player.velocity.x = direction.x * SPEED
	player.velocity.z = direction.y * SPEED * 0.78
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
		player.velocity.y = JUMP_SPEED
	else:
		player.velocity.y = -0.2
	player.move_and_slide()
	var p := player.global_position
	p.x = clampf(p.x, -STAGE_HALF_X, STAGE_HALF_X)
	p.z = clampf(p.z, -STAGE_HALF_Z, STAGE_HALF_Z)
	player.global_position = p
	if direction.x > 0.03:
		last_direction = 1
	elif direction.x < -0.03:
		last_direction = -1
	portrait.flip_h = last_direction < 0
	if Input.is_key_pressed(KEY_C) and not _c_was_pressed:
		_c_was_pressed = true
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL if cam.projection == Camera3D.PROJECTION_PERSPECTIVE else Camera3D.PROJECTION_PERSPECTIVE
	elif not Input.is_key_pressed(KEY_C):
		_c_was_pressed = false

var _c_was_pressed := false

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _build_materials() -> void:
	floor_material = _material(Color("bbb2a5"))
	floor_material.albedo_texture = load("res://assets/stone_floor.png")
	floor_material.uv1_scale = Vector3(16, 1, 4)
	wall_material = _material(Color("a8a4a3"))
	wall_material.albedo_texture = load("res://assets/stone_wall.png")
	wall_material.uv1_scale = Vector3(3, 2, 1)
	stone_material = _material(Color("83838b"))
	stone_material.albedo_texture = load("res://assets/stone_wall.png")
	trim_material = _material(Color("474956"))
	dark_material = _material(Color("292b34"))
	gold_material = _material(Color("9f8050"), 0.6)
	banner_tex = load("res://assets/banner.png")

func _box(parent: Node3D, name: String, center: Vector3, dims: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var holder: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.name = name
		holder = body
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dims
		collision.shape = shape
		body.add_child(collision)
	else:
		holder = Node3D.new()
		holder.name = name
	parent.add_child(holder)
	holder.position = center
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dims
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mesh_instance)
	return holder

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("4a526a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("aaa9bf")
	env.ambient_light_energy = 0.58
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Warm directional sun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffdfb9")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Cool fill"
	fill.rotation_degrees = Vector3(-20, 135, 0)
	fill.light_color = Color("91a9d8")
	fill.light_energy = 0.32
	add_child(fill)

func _build_ground() -> void:
	_box(self, "3D floor / collision", Vector3(0, -0.34, 0), Vector3(66, 0.68, 10.5), floor_material, true)
	_box(self, "Front stone rim", Vector3(0, -0.2, 5.45), Vector3(66, 0.72, 0.6), stone_material)
	_box(self, "Rear edge", Vector3(0, 0.55, -5.25), Vector3(66, 1.1, 0.55), wall_material, true)
	# Inlaid lines make changing depth perspective visibly measurable.
	for i in range(-15, 16):
		_box(self, "floor joint", Vector3(float(i) * 2.0, 0.015, 0), Vector3(0.055, 0.025, 10.15), dark_material)
	# Thin wall blocks are true opaque geometry, not part of a flattened backdrop.
	for i in range(-7, 8):
		_box(self, "wall section", Vector3(i * 4.0, 2.2, -7.7), Vector3(3.9, 4.4, 0.65), wall_material)
		_box(self, "wall cap", Vector3(i * 4.0, 4.52, -7.7), Vector3(4.0, 0.28, 0.83), trim_material)
	# panoramic illustration is far behind geometry (parallax texture, NOT a stage screenshot)
	var backdrop := Sprite3D.new()
	backdrop.name = "Distant illustrated castle panorama"
	backdrop.texture = load("res://assets/skyline.png")
	backdrop.pixel_size = 0.048
	backdrop.position = Vector3(0, 11.0, -32.0)
	backdrop.shaded = false
	backdrop.no_depth_test = false
	backdrop.fixed_size = false
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

func _pillar(x: float, z: float, height: float) -> void:
	_box(self, "pillar footing", Vector3(x, 0.23, z), Vector3(1.5, 0.46, 1.5), stone_material, true)
	_box(self, "pillar base", Vector3(x, 0.70, z), Vector3(1.17, 0.50, 1.16), stone_material, true)
	_box(self, "pillar body", Vector3(x, 0.96 + height / 2.0, z), Vector3(0.88, height, 0.88), wall_material, true)
	_box(self, "pillar capital", Vector3(x, height + 1.2, z), Vector3(1.48, 0.43, 1.48), stone_material, true)
	_box(self, "pillar gold detail", Vector3(x, height + 1.45, z), Vector3(1.59, 0.10, 1.59), gold_material)

func _torch(x: float, z: float) -> void:
	_box(self, "brazier stand", Vector3(x, 1.08, z), Vector3(0.14, 2.1, 0.14), dark_material)
	_box(self, "brazier bowl", Vector3(x, 2.17, z), Vector3(0.7, 0.22, 0.7), trim_material)
	var light := OmniLight3D.new()
	light.name = "Torch glow"
	light.position = Vector3(x, 2.65, z)
	light.light_color = Color("ff934c")
	light.light_energy = 1.35
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)
	for n in range(4):
		var flame := Sprite3D.new()
		flame.name = "Stylized flame"
		flame.texture = _flame_texture()
		flame.pixel_size = 0.014
		flame.position = Vector3(x + (float(n)-1.5)*0.095, 2.52 + float(n%2)*0.09, z)
		flame.shaded = false
		flame.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(flame)

var cached_flame: ImageTexture
func _flame_texture() -> ImageTexture:
	if cached_flame != null:
		return cached_flame
	var image := Image.create(48, 92, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(92):
		var h := float(y) / 91.0
		var radius := pow(h, 0.65) * 23.0
		for x in range(48):
			var dx := absf(float(x)-23.5)
			if dx < radius:
				var t := dx / maxf(radius, 0.01)
				var color := Color(1.0, 0.34 + h*0.62, 0.06 + h*0.34, (1.0-t)*0.85)
				image.set_pixel(x,y,color)
	cached_flame = ImageTexture.create_from_image(image)
	return cached_flame

func _banner(x: float, z: float) -> void:
	var b := Sprite3D.new()
	b.name = "2D transparent cloth ornament"
	b.texture = banner_tex
	b.pixel_size = 0.010
	b.position = Vector3(x, 3.85, z)
	b.shaded = true
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b)

func _build_architecture() -> void:
	# Main hall architectural rhythm, with nearer geometry providing real occlusion.
	for x in [-23.0, -13.0, -3.0, 7.0, 17.0, 27.0]:
		_pillar(x, -4.45, 4.8)
		_banner(x + 1.4, -4.61)
	for x in [-18.0, 2.0, 22.0]:
		_torch(x, -4.17)
	# Two real 3D front columns. Walking behind them makes the 2D sprite get occluded.
	for x in [-8.5, 12.0]:
		_pillar(x, 3.55, 3.85)
	# Low scenic blocks near the front, independent of parallax background.
	for x in [-25.0, -15.0, -0.8, 19.0, 27.0]:
		_box(self, "broken parapet", Vector3(x, 0.38, 4.55), Vector3(2.3, 0.76, 0.85), stone_material, true)
	# Raised side structures demonstrate volumetric architecture from perspective.
	for x in [-26.0, 26.0]:
		_box(self, "turret", Vector3(x, 3.5, -9.0), Vector3(4.6, 7.0, 4.1), wall_material)
		_box(self, "turret crown", Vector3(x, 7.1, -9.0), Vector3(5.1, 0.5, 4.6), stone_material)

func _build_character() -> void:
	player = CharacterBody3D.new()
	player.name = "Player (3D collisions, 2D visual)"
	player.position = Vector3(-1.5, 0.13, 0.8)
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 2.6
	collider.position = Vector3(0, 1.34, 0)
	collider.shape = capsule
	player.add_child(collider)
	portrait = Sprite3D.new()
	portrait.name = "Original image extracted sprite - NOT 3D mesh character"
	portrait.texture = load("res://assets/character.png")
	portrait.pixel_size = 0.00215
	portrait.position = Vector3(0, 1.55, 0)
	portrait.shaded = false
	portrait.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	portrait.alpha_scissor_threshold = 0.25
	portrait.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(portrait)
	# Shadow is a 3D mesh that stays on ground even while the sprite jumps.
	var shadow := MeshInstance3D.new()
	shadow.name = "Contact shadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.15, 0.65)
	shadow.mesh = plane
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.06,0.06,0.08,0.43)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = sm
	shadow.position = Vector3(0, -0.10, 0)
	# Putting shadow under player means it rises with jumping. Fix by updating global Y.
	add_child(shadow)
	shadow.set_meta("follow_player",true)
	contact_shadow = shadow

var contact_shadow: MeshInstance3D
func _build_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Fixed angle 3D tracking camera"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 45.0
	cam.size = 13.5 # Orthographic comparison uses a sane scale
	cam.near = 0.1
	cam.far = 120.0
	cam.position = Vector3(player.position.x, 6.8, 17.0)
	# Camera orientation is fixed thereafter; only horizontal position changes.
	add_child(cam)
	cam.look_at(Vector3(player.position.x, 1.25, -0.8), Vector3.UP)
	cam.current = true


# When CAPTURE_STAGE=1, take screenshots of ACTUAL Godot viewport output.
# Only used by the GitHub Actions capture workflow; normal gameplay is unchanged.
func _capture_stage() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var locations := [
		Vector3(-1.5, 0.13, 2.6),
		Vector3(0.5, 0.13, 0.1),
		Vector3(2.5, 0.13, -2.4),
	]
	for i in range(locations.size()):
		player.global_position = locations[i]
		player.velocity = Vector3.ZERO
		# Settle camera and rendering over multiple frames.
		for j in range(36):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var filename := "res://captures/actual_%02d.png" % i
		var error := image.save_png(ProjectSettings.globalize_path(filename))
		print("CAPTURE: ", filename, " result=", error)
	get_tree().quit()
