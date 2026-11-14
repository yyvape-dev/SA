extends Node3D
## Supplied paintings and separate foreground props. No city/dungeon packs.
var room_id := ""
var scenery: Node3D
var actors := {}
var camera: Camera3D
var lamp: Node3D
var marker: Label3D
var elapsed := 0.0
var font: Font

func _ready() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.0, 15)
	camera.fov = 22
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0.75, 0))
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("292d38")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c1c8dd")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -28, 0)
	sun.light_color = Color("ffdfab")
	sun.light_energy = 1.3
	add_child(sun)
	for id in ["rana", "lily"]:
		var sprite := Sprite3D.new()
		sprite.texture = load("res://assets/event_idle/%s_idle.webp" % id)
		sprite.hframes = 6
		sprite.vframes = 6
		var pivot := Vector2(105, 367.5) if id == "rana" else Vector2(115, 371.5)
		sprite.offset = Vector2(100 - pivot.x, pivot.y - 188)
		sprite.pixel_size = (1.85 if id == "rana" else 1.8) / pivot.y
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		actors[id] = sprite
	for entry in [["mina", "mina_bread", 1.70], ["sera", "sera_book", 1.75], ["envoy", "imperial_envoy", 1.90]]:
		var sprite := _art_sprite(str(entry[1]), float(entry[2]))
		add_child(sprite)
		actors[entry[0]] = sprite
	marker = _label(self, "", Vector3(0, 1.5, 0), 25)

func _art_sprite(asset: String, height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/prologue/%s.png" % asset)
	var image := sprite.texture.get_image()
	var rect := image.get_used_rect()
	# Keep received canvas, place the measured silhouette's foot at local y=0.
	var pivot := Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
	sprite.offset = Vector2(image.get_width() * 0.5 - pivot.x, pivot.y - image.get_height() * 0.5)
	sprite.pixel_size = height / float(rect.size.y)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite

func _label(parent: Node3D, text: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = font_size
	label.pixel_size = 0.006
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color("ffe4a7")
	parent.add_child(label)
	return label

func rebuild(id: String) -> void:
	room_id = id
	if scenery != null:
		remove_child(scenery)
		scenery.queue_free()
	scenery = Node3D.new()
	add_child(scenery)
	var background := Sprite3D.new()
	background.name = "PaintedBackground"
	var asset: String = {"office": "office", "guest": "guest_room", "audience": "audience_room"}[id]
	background.texture = load("res://assets/prologue/%s.png" % asset)
	background.pixel_size = 16.0 / 1536.0
	# Source wall/floor join (~row 660) meets y=0 at the back of the walking strip.
	background.offset = Vector2(0, 660 - 432)
	background.position = Vector3(0, 0, -2.4)
	background.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	scenery.add_child(background)
	var desk := _art_sprite("desk", 1.05)
	desk.name = "PaintedDesk"
	desk.position = {"office": Vector3(-0.5, 0, 0.15), "guest": Vector3(2.2, 0, -0.65), "audience": Vector3(1.45, 0, -0.65)}[id]
	scenery.add_child(desk)
	if id == "guest":
		var paper := MeshInstance3D.new()
		paper.mesh = BoxMesh.new()
		paper.mesh.size = Vector3(0.30, 0.015, 0.22)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("f1dfad")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paper.material_override = mat
		paper.position = Vector3(2.2, 0.95, -0.65)
		scenery.add_child(paper)
	lamp = _art_sprite("portable_lamp", 0.65)
	lamp.name = "PaintedLamp"
	lamp.position = Vector3(1.8, 0.95, -0.60)
	scenery.add_child(lamp)
	lamp.hide()


func apply(state) -> void:
	if room_id != state.scene_id(): rebuild(state.scene_id())
	for actor in actors.values(): actor.hide()
	actors.rana.show()
	actors.rana.position = Vector3(state.player.x, 0.02, state.player.y)
	actors.rana.flip_h = state.facing < 0
	actors.lily.position = Vector3(2.2, 0.02, 0)
	actors.lily.flip_h = true
	if room_id == "office":
		actors.sera.show()
		actors.sera.position = Vector3(-3.2, 0, -0.2)
		if state.beat_id != "morning":
			actors.mina.show()
			actors.mina.position = Vector3(0.5, 0, -0.1)
		if state.beat_id in ["talk_lily", "missing", "guest_door"]: actors.lily.show()
	elif room_id == "guest":
		actors.lily.show()
		actors.lily.position = Vector3(0.4, 0.02, 0)
		actors.lily.flip_h = state.player.x < 0.4
	else:
		actors.lily.show()
		actors.lily.position = Vector3(-0.3, 0.02, -0.1)
		if state.beat_id in ["audience", "lamp"]:
			actors.lily.flip_h = false
			actors.envoy.show()
			actors.envoy.position = Vector3(2.8, 0, -0.1)
	lamp.visible = state.beat_id == "lamp"
	camera.fov = 18 if state.beat_id == "lamp" else 22
	camera.position = Vector3(0.8, 3.0, 15) if state.beat_id == "lamp" else Vector3(0, 3.0, 15)
	camera.look_at(Vector3(0.8, 0.70, -0.3) if state.beat_id == "lamp" else Vector3(0, 0.75, 0))
	marker.visible = state.can_move()
	if marker.visible:
		var target: Vector2 = state.TARGETS[state.beat_id]
		marker.position = Vector3(target.x, 1.9 if state.beat_id == "talk_lily" else 1.35, target.y)
		marker.text = {"talk_lily": "◇ リリィに話す", "guest_door": "◇ 客室へ", "find_note": "◇ 机を調べる"}[state.beat_id]

func _process(delta: float) -> void:
	elapsed += delta
	for id in ["rana", "lily"]:
		actors[id].frame = int(elapsed * 12) % 36
