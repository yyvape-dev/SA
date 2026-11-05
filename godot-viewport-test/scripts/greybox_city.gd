extends Node3D
## 2.5D neon-city GREYBOX ONLY: 3D meshes + original existing 2D character.
## No generated images, external textures, facade art, or stage screenshot overlays.
## This is independent of main.tscn and the original stage.gd.

const SPEED := 5.5
const GRAVITY := 24.0
const STAGE_HALF_X := 28.0
const STAGE_HALF_Z := 4.0

var player: CharacterBody3D
var portrait: Sprite3D
var cam: Camera3D
var contact_shadow: MeshInstance3D
var moving := false
var elapsed := 0.0

var floor_mat: StandardMaterial3D
var lane_mat: StandardMaterial3D
var wall_mat: StandardMaterial3D
var wall_secondary: StandardMaterial3D
var trim_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var accent_mat: StandardMaterial3D
var metal_mat: StandardMaterial3D

func _ready() -> void:
	_make_materials()
	_make_environment()
	_make_floor()
	_make_tavern(-13.0)
	_make_workshop(0.0)
	_make_scrapyard(13.5)
	_make_occluders()
	_make_character()
	_make_camera()
	if OS.has_environment("CAPTURE_GREYBOX"):
		_capture_greybox()

func _process(delta: float) -> void:
	elapsed += delta
	if player == null:
		return
	contact_shadow.global_position = Vector3(player.global_position.x, 0.02, player.global_position.z)
	portrait.position.y = 1.55 + (sin(elapsed * 10.0) * 0.03 if moving else 0.0)
	if cam != null:
		cam.global_position = cam.global_position.lerp(Vector3(player.global_position.x, 6.8, 18.0), minf(1.0, delta * 4.0))

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var dx := Input.get_axis("ui_left", "ui_right")
	var dz := Input.get_axis("ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_key_pressed(KEY_D):
		dx += 1.0
	if Input.is_key_pressed(KEY_W):
		dz -= 1.0
	if Input.is_key_pressed(KEY_S):
		dz += 1.0
	var direction := Vector2(dx, dz).normalized()
	moving = direction.length_squared() > 0.001
	player.velocity.x = direction.x * SPEED
	player.velocity.z = direction.y * SPEED * 0.78
	if player.is_on_floor():
		player.velocity.y = -0.2
	else:
		player.velocity.y -= GRAVITY * delta
	player.move_and_slide()
	var p := player.global_position
	p.x = clampf(p.x, -STAGE_HALF_X, STAGE_HALF_X)
	p.z = clampf(p.z, -STAGE_HALF_Z, STAGE_HALF_Z)
	player.global_position = p
	if direction.x > 0.03:
		portrait.flip_h = false
	elif direction.x < -0.03:
		portrait.flip_h = true

func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _make_materials() -> void:
	floor_mat = _mat(Color("777782"))
	lane_mat = _mat(Color("92919a"))
	wall_mat = _mat(Color("a9a9b0"))
	wall_secondary = _mat(Color("8d8f9a"))
	trim_mat = _mat(Color("c2bdba"))
	dark_mat = _mat(Color("41434e"))
	accent_mat = _mat(Color("dad1b7"))
	metal_mat = _mat(Color("686b77"), 0.65)

func _box(title: String, center: Vector3, dims: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = title
	root.position = center
	add_child(root)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dims
		collision.shape = shape
		root.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dims
	visual.mesh = mesh
	visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(visual)
	return root

func _make_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("454558")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c1c3d7")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.name = "Neutral greybox key"
	key.rotation_degrees = Vector3(-48, -25, 0)
	key.light_color = Color("eee9df")
	key.light_energy = 1.0
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "Neutral greybox fill"
	fill.rotation_degrees = Vector3(-22, 135, 0)
	fill.light_color = Color("adbbd6")
	fill.light_energy = 0.32
	add_child(fill)

func _make_floor() -> void:
	# The floor MUST be visible and collision-enabled. The old stage helper omitted add_child for solids.
	_box("BELT FLOOR - visible, collidable", Vector3(0, -0.23, 2.85), Vector3(66, 0.46, 16.7), floor_mat, true)
	for i in range(-16, 17):
		_box("Floor grid X %02d" % i, Vector3(float(i) * 2.0, 0.012, 2.85), Vector3(0.025, 0.018, 16.5), lane_mat)
	for z in [-4.0, 0.0, 4.0, 8.0]:
		_box("Floor depth guide Z%.1f" % z, Vector3(0, 0.015, z), Vector3(65.0, 0.025, 0.04), lane_mat)
	_box("Rear belt limit", Vector3(0, 0.23, -5.5), Vector3(66.0, 0.46, 0.25), dark_mat, true)
	_box("Near belt limit", Vector3(0, 0.06, 11.15), Vector3(66.0, 0.12, 0.20), trim_mat)

func _make_tavern(x: float) -> void:
	# A closed two-story mass; doors/awnings are 3D depth cues, NOT facade textures.
	_box("TAVERN solid shell", Vector3(x, 3.45, -7.35), Vector3(9.5, 6.9, 6.0), wall_mat, true)
	_box("Tavern parapet", Vector3(x, 7.1, -7.35), Vector3(10.1, 0.4, 6.5), trim_mat)
	_box("Tavern door recess marker", Vector3(x, 1.45, -4.28), Vector3(2.0, 2.9, 0.09), dark_mat)
	_box("Tavern storefront L", Vector3(x - 3.15, 2.0, -4.25), Vector3(2.0, 2.7, 0.09), wall_secondary)
	_box("Tavern storefront R", Vector3(x + 3.15, 2.0, -4.25), Vector3(2.0, 2.7, 0.09), wall_secondary)
	_box("Tavern awning projecting from facade", Vector3(x, 3.55, -3.5), Vector3(8.0, 0.24, 1.65), metal_mat)
	for offs in [-3.65, 3.65]:
		_box("Tavern awning support", Vector3(x + offs, 1.78, -3.05), Vector3(0.14, 3.56, 0.14), dark_mat)
	for offs in [-2.75, 2.75]:
		_box("Tavern upper-window inset", Vector3(x + offs, 5.45, -4.27), Vector3(1.8, 1.5, 0.12), wall_secondary)
	_box("Tavern roof chimney", Vector3(x - 3.1, 8.0, -8.55), Vector3(0.9, 1.5, 0.9), dark_mat)

func _make_workshop(x: float) -> void:
	_box("REPAIR SHOP solid shell", Vector3(x, 3.65, -7.35), Vector3(10.4, 7.3, 6.0), wall_secondary, true)
	_box("Workshop flat roof", Vector3(x, 7.52, -7.35), Vector3(10.9, 0.42, 6.6), trim_mat)
	_box("Workshop broad garage aperture marker", Vector3(x, 2.2, -4.27), Vector3(5.6, 4.3, 0.10), dark_mat)
	_box("Workshop garage lintel", Vector3(x, 4.45, -4.12), Vector3(6.5, 0.32, 0.34), trim_mat)
	for offs in [-3.0, 3.0]:
		_box("Workshop garage upright", Vector3(x + offs, 2.3, -4.1), Vector3(0.32, 4.5, 0.32), metal_mat)
	for i in range(5):
		_box("Garage shutter segmentation", Vector3(x, 0.8 + float(i) * 0.7, -4.185), Vector3(5.25, 0.06, 0.08), metal_mat)
	_box("Workshop side door marker", Vector3(x + 4.1, 1.35, -4.25), Vector3(1.2, 2.7, 0.1), dark_mat)
	_box("Workshop external roof duct", Vector3(x - 3.75, 8.1, -6.8), Vector3(1.0, 1.0, 1.2), dark_mat)
	_box("Workshop projecting sign blank", Vector3(x + 4.7, 5.65, -3.7), Vector3(0.25, 1.2, 1.1), accent_mat)

func _make_scrapyard(x: float) -> void:
	_box("SCRAPYARD back shed shell", Vector3(x, 2.4, -7.25), Vector3(9.7, 4.8, 5.6), wall_secondary, true)
	_box("Scrapyard broad low roof", Vector3(x, 5.0, -7.25), Vector3(10.6, 0.45, 6.5), metal_mat)
	_box("Scrapyard open-bay dark recess marker", Vector3(x + 0.1, 1.95, -4.4), Vector3(6.5, 3.85, 0.12), dark_mat)
	for offs in [-4.0, 4.0]:
		_box("Scrapyard portal column", Vector3(x + offs, 2.5, -4.08), Vector3(0.5, 5.0, 0.6), trim_mat)
	_box("Scrapyard projecting canopy", Vector3(x, 4.55, -3.7), Vector3(9.0, 0.28, 1.9), trim_mat)
	_box("Scrapyard stack low", Vector3(x - 3.3, 0.7, -2.0), Vector3(1.8, 1.4, 1.6), metal_mat)
	_box("Scrapyard stack high", Vector3(x - 3.25, 1.85, -2.05), Vector3(1.4, 0.9, 1.4), wall_mat)
	_box("Scrapyard stack side", Vector3(x + 3.2, 0.65, -2.0), Vector3(1.9, 1.3, 1.2), metal_mat)
	_box("Scrapyard crane mast", Vector3(x + 4.0, 7.3, -7.3), Vector3(0.45, 4.3, 0.45), dark_mat)
	_box("Scrapyard crane arm", Vector3(x + 2.35, 9.25, -7.3), Vector3(3.9, 0.3, 0.4), trim_mat)

func _make_occluders() -> void:
	# Compare identical X and different Z screenshots: player behind/front of this 3D pillar.
	_box("FRONT OCCLUDER test pole", Vector3(2.65, 1.75, 1.6), Vector3(0.60, 3.5, 0.60), accent_mat)
	_box("Front pole cap", Vector3(2.65, 3.6, 1.6), Vector3(0.95, 0.3, 0.95), trim_mat)
	for x in [-20.0, -6.0, 8.0, 22.0]:
		_box("Depth reference short fence", Vector3(x, 0.55, 3.7), Vector3(2.4, 1.1, 0.15), wall_secondary)

func _make_character() -> void:
	player = CharacterBody3D.new()
	player.name = "Original 2D player - X/Z movement"
	player.position = Vector3(-13.0, 0.04, 0.8)
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 2.6
	collider.position = Vector3(0, 1.34, 0)
	collider.shape = capsule
	player.add_child(collider)
	portrait = Sprite3D.new()
	portrait.name = "Existing character.png (unchanged)"
	portrait.texture = load("res://assets/character.png")
	portrait.pixel_size = 0.00215
	portrait.position = Vector3(0, 1.55, 0)
	portrait.shaded = false
	portrait.no_depth_test = false
	portrait.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	portrait.alpha_scissor_threshold = 0.25
	portrait.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(portrait)
	contact_shadow = MeshInstance3D.new()
	contact_shadow.name = "Grounded shadow (independent of player jump)"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.15, 0.65)
	contact_shadow.mesh = plane
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.06, 0.06, 0.08, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	contact_shadow.material_override = sm
	add_child(contact_shadow)

func _make_camera() -> void:
	cam = Camera3D.new()
	cam.name = "Fixed angle 3D camera - X tracking only"
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 45.0
	cam.near = 0.1
	cam.far = 120.0
	cam.position = Vector3(player.position.x, 6.8, 18.0)
	add_child(cam)
	cam.look_at(Vector3(player.position.x, 1.25, -0.8), Vector3.UP)
	cam.current = true

func _capture_greybox() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://captures"))
	var shots := [
		["00_tavern", -13.0, 0.8],
		["01_workshop", 0.0, 0.8],
		["02_scrapyard", 13.5, 0.8],
		["03_occluded", 2.65, -0.8],
		["04_unoccluded", 2.65, 3.0],
		["05_rear_lane", 0.0, -3.25],
	]
	for shot in shots:
		player.global_position = Vector3(float(shot[1]), 0.04, float(shot[2]))
		player.velocity = Vector3.ZERO
		cam.global_position = Vector3(player.global_position.x, 6.8, 18.0)
		for frame in range(35):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var filepath := "res://captures/greybox_%s.png" % str(shot[0])
		var err := img.save_png(ProjectSettings.globalize_path(filepath))
		print("GREYBOX CAPTURE ", filepath, " result=", err, " player=", player.global_position)
	get_tree().quit()
