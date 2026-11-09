extends Node3D

const ART := "res://art/painted_bt/gamehall_motion/"
const PIXEL_SIZE := 0.005
const FACADE_Z := -6.18
const FRAME_SIZE := Vector2(2050, 405)
const FRAME_ORIGIN := Vector2(550, 1400)
const ATLAS_COUNT := 4
const FRAMES_PER_ATLAS := 9

var _atlases: Array[Texture2D] = []
var _frame_texture := AtlasTexture.new()
var _joints: Array[Dictionary] = []
var _clock := 0.0
var _frame := -1

static func point(pixel: Vector2) -> Vector3:
	return Vector3(-8.0 + pixel.x * PIXEL_SIZE, 10.0 - pixel.y * PIXEL_SIZE, 0.0)

static func _vec(coords: Array) -> Vector2:
	return Vector2(coords[0], coords[1])

func setup() -> bool:
	for i in ATLAS_COUNT:
		var atlas := load(ART + "remaining_animation/motion_frames_%02d.png" % i) as Texture2D
		if atlas == null:
			return false
		_atlases.append(atlas)
	var people := load(ART + "playable/accepted_people_atlas.png") as Texture2D
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART + "playable/accepted_people.json"))
	if people == null or not data is Dictionary:
		return false
	_frame_texture.filter_clip = true
	_set_frame(0)
	var playback := _sprite(_frame_texture, 2)
	playback.position = point(FRAME_ORIGIN + FRAME_SIZE * 0.5) + Vector3(0, 0, FACADE_Z + 0.003)
	add_child(playback)

	for actor in data.actors.values():
		var clean: Dictionary = data.tiles[actor.cleanup]
		var cleanup := _sprite(_tile(people, clean), 3)
		cleanup.position = point(_vec(clean.center)) + Vector3(0, 0, FACADE_Z + 0.004)
		add_child(cleanup)
		var sockets := {}
		for key in actor.parts:
			var part: Dictionary = actor.parts[key]
			var tile: Dictionary = data.tiles[part.tile]
			var pivot := point(_vec(part.pivot))
			var joint := Node3D.new()
			if part.parent == null:
				add_child(joint)
				joint.position = pivot + Vector3(0, 0, FACADE_Z + 0.005)
			else:
				sockets[part.parent].add_child(joint)
				joint.position = pivot - point(_vec(actor.parts[part.parent].pivot))
			sockets[key] = joint
			var sprite := _sprite(_tile(people, tile), 4 + int(part.z))
			sprite.position = point(_vec(tile.center)) - pivot
			joint.add_child(sprite)
			if part.degrees != 0.0:
				_joints.append({"node": joint, "degrees": part.degrees, "delay": part.delay})
	return true

func _tile(atlas: Texture2D, tile: Dictionary) -> AtlasTexture:
	var result := AtlasTexture.new()
	var r: Array = tile.region
	result.atlas = atlas
	result.region = Rect2(r[0], r[1], r[2], r[3])
	result.filter_clip = true
	return result

func _sprite(texture: Texture2D, priority: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PIXEL_SIZE
	sprite.render_priority = priority
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite

func _set_frame(frame: int) -> void:
	if frame == _frame:
		return
	_frame = frame
	_frame_texture.atlas = _atlases[frame / FRAMES_PER_ATLAS]
	_frame_texture.region = Rect2(0, FRAME_SIZE.y * (frame % FRAMES_PER_ATLAS), FRAME_SIZE.x, FRAME_SIZE.y)

func _process(delta: float) -> void:
	_clock = fmod(_clock + delta, 12.0)
	_set_frame(int(_clock * 12.0) % (ATLAS_COUNT * FRAMES_PER_ATLAS))
	var phase := fmod(_clock, 2.4) / 2.4
	for joint in _joints:
		var u := clampf((phase - joint.delay) / 0.78, 0.0, 1.0)
		joint.node.rotation.z = -deg_to_rad(joint.degrees) * pow(sin(PI * u), 2)
