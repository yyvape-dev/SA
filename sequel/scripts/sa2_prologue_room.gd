extends Node3D
## Rebuildable room blockout: no baked characters/text and no city/dungeon packs.
var room_id := ""
var scenery: Node3D
var actors := {}
var camera: Camera3D
var lamp: Node3D
var marker: Label3D
var elapsed := 0.0
var font: Font
const STONE := Color("66615c")
const WOOD := Color("594332")
const GOLD := Color("b79a63")

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
	for id in ["mina", "sera", "envoy"]:
		var standin := Node3D.new()
		add_child(standin)
		actors[id] = standin
		# Deliberately neutral, labelled stand-ins, never passed off as new character art.
		var color := Color("738b87") if id == "sera" else (Color("ba9278") if id == "mina" else Color("454958"))
		_box(standin, Vector3(0, 0.75, 0), Vector3(0.48, 1.3, 0.26), color)
		var head := MeshInstance3D.new()
		head.mesh = SphereMesh.new()
		head.mesh.radius = 0.18
		head.mesh.height = 0.36
		head.position.y = 1.55
		head.material_override = _material(Color("c9bca8"))
		standin.add_child(head)
		_label(standin, {"mina": "ミナ", "sera": "セラ", "envoy": "使節"}[id] + "（仮）", Vector3(0, 1.95, 0), 22)
	marker = _label(self, "", Vector3(0, 1.5, 0), 25)

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = _material(color, glow)
	mesh.position = at
	parent.add_child(mesh)
	return mesh

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
	_box(scenery, Vector3(0, -0.12, -0.2), Vector3(12, 0.24, 5), Color("7b7568"))
	_box(scenery, Vector3(0, 2.1, -2.3), Vector3(12, 4.2, 0.3), STONE)
	for x in [-5.1, -2.8, 0.0, 2.8, 5.1]:
		_box(scenery, Vector3(x, 2, -2.02), Vector3(0.17, 4, 0.3), Color("8d877a"))
	_box(scenery, Vector3(0, 0.2, -1.95), Vector3(12, 0.3, 0.35), Color("494745"))
	for x in [-3.9, 0.0, 3.9]:
		_box(scenery, Vector3(x, 2.5, -2.06), Vector3(1.5, 2.25, 0.12), Color("c5c9bd"), true)
		_box(scenery, Vector3(x, 2.5, -1.96), Vector3(0.06, 2.3, 0.1), GOLD)
		_box(scenery, Vector3(x, 2.4, -1.95), Vector3(1.55, 0.06, 0.1), GOLD)
	for x in range(-6, 7):
		_box(scenery, Vector3(x, 0.005, 0), Vector3(0.02, 0.01, 4), Color("59574e"))
	for z in [-1.5, -0.5, 0.5, 1.5]:
		_box(scenery, Vector3(0, 0.006, z), Vector3(12, 0.01, 0.02), Color("59574e"))
	if id == "office":
		_desk(Vector3(-1.9, 0, -0.9))
		for x in [-2.5, -1.9]:
			_box(scenery, Vector3(x, 0.94, -0.8), Vector3(0.4, 0.025, 0.3), Color("ded2b2"))
		_box(scenery, Vector3(-1.05, 0.96, -0.8), Vector3(0.42, 0.08, 0.32), Color("d0a15a"))
		_box(scenery, Vector3(-4.7, 1.1, -1.6), Vector3(1.1, 2.2, 0.6), WOOD)
	elif id == "guest":
		_box(scenery, Vector3(-3.2, 0.35, -1.1), Vector3(2.5, 0.7, 1.2), WOOD)
		_box(scenery, Vector3(-3.2, 0.75, -1.1), Vector3(2.45, 0.12, 1.15), Color("b4af9d"))
		_box(scenery, Vector3(-4.05, 0.86, -1.1), Vector3(0.5, 0.15, 0.9), Color("e6dfc5"))
		_desk(Vector3(2.2, 0, -0.8))
		_box(scenery, Vector3(2.2, 0.94, -0.7), Vector3(0.4, 0.02, 0.3), Color("f1dfad"), true)
		# Empty pegs: no fishing rod or new clue about Ranka's destination.
		for x in [-0.5, 0, 0.5]:
			_box(scenery, Vector3(x, 1.5, -1.95), Vector3(0.08, 0.08, 0.3), WOOD)
	else:
		_box(scenery, Vector3(0, 0.015, -0.2), Vector3(2.8, 0.02, 4), Color("624153"))
		_desk(Vector3(1.4, 0, -0.9))
		_box(scenery, Vector3(0.9, 0.94, -0.8), Vector3(0.4, 0.03, 0.3), Color("ded2b2"))
	lamp = Node3D.new()
	lamp.position = Vector3(1.8, 0.94, -0.8)
	scenery.add_child(lamp)
	_box(lamp, Vector3(0, 0.04, 0), Vector3(0.25, 0.08, 0.25), GOLD)
	_box(lamp, Vector3(0, 0.25, 0), Vector3(0.16, 0.34, 0.16), Color("ffedba"), true)
	_box(lamp, Vector3(0, 0.44, 0), Vector3(0.23, 0.05, 0.23), GOLD)
	lamp.hide()

func _desk(at: Vector3) -> void:
	_box(scenery, at + Vector3(0, 0.87, 0), Vector3(2.4, 0.12, 0.85), WOOD)
	for x in [-1, 1]:
		_box(scenery, at + Vector3(x, 0.42, 0), Vector3(0.16, 0.84, 0.65), WOOD)

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
