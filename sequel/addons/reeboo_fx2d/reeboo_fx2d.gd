class_name ReebooFx2D
extends Node2D
## REEBOO Stylized 2D VFX: the script on the root of every effect scene.
## Shader layers (Sprite2D + ShaderMaterial with an fx_time uniform) and GPUParticles2D children are driven from one clock.
## One-shot effects emit impact(strength) on their impact frame and finished at the end, then free themselves.
## Looping effects run until stop() is called, then fade out and free themselves.

## Emitted once per play, at impact_time. Use it for camera shake, hit-stop or a sound.
signal impact(strength: float)
## Emitted when a one-shot effect ends, or when a stopped looping effect has faded out.
signal finished

@export var autoplay := true
## Free the node when the effect has finished.
@export var free_when_done := true
## Playback speed (shaders and particles).
@export_range(0.1, 4.0, 0.05) var speed := 1.0:
	set(v):
		speed = v
		for p in _particles:
			p.speed_scale = speed
## Multiplies every layer colour (recolour the whole effect). Alpha fades it.
@export var tint := Color.WHITE:
	set(v):
		tint = v
		_apply_modulate()
@export_group("Timing")
## Looping effects run until stop().
@export var looping := false
## Length of a one-shot in seconds (the longest layer or particle).
@export var duration := 1.0
## Seconds after play() when impact(strength) is emitted.
@export var impact_time := 0.0
## 0 = none, 0.3 small hit, 0.6 heavy hit, 1.0 big explosion (a suggested camera trauma value).
@export_range(0.0, 1.0, 0.05) var impact_strength := 0.3
## Fade-out time after stop() on looping effects.
@export var stop_fade := 0.35

var _time := 0.0
var _playing := false
var _impact_sent := false
var _stopping := false
var _fade := 1.0
var _layers: Array[CanvasItem] = []
var _particles: Array[GPUParticles2D] = []
var _started: Array[bool] = []


## Instance an effect scene under parent at a global position. Returns the effect (it frees itself when done).
static func spawn(scene: PackedScene, parent: Node, at: Vector2, angle := 0.0, color := Color.WHITE) -> ReebooFx2D:
	var fx := scene.instantiate() as ReebooFx2D
	fx.tint = color
	parent.add_child(fx)
	fx.global_position = at
	fx.global_rotation = angle
	return fx


func _ready() -> void:
	_collect(self)
	_apply_modulate()
	set_process(false)
	if autoplay:
		play()


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is GPUParticles2D:
			var gp := c as GPUParticles2D
			gp.emitting = false
			gp.speed_scale = speed
			_particles.append(gp)
		elif c is CanvasItem and (c as CanvasItem).material is ShaderMaterial:
			_layers.append(c as CanvasItem)
		_collect(c)


## Start (or restart) the effect from the beginning.
func play() -> void:
	_time = 0.0
	_playing = true
	_impact_sent = false
	_stopping = false
	_fade = 1.0
	_apply_modulate()
	_started.clear()
	for p in _particles:
		p.emitting = false
		_started.append(false)
	_update_layers()
	set_process(true)


## Looping effects: stop emitting, fade out, emit finished, free. One-shots: end now.
func stop() -> void:
	if not _playing:
		return
	for p in _particles:
		p.emitting = false
	if looping:
		_stopping = true
	else:
		_end()


func is_playing() -> bool:
	return _playing


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta * speed
	_update_layers()
	for i in _particles.size():
		if not _started[i] and _time >= float(_particles[i].get_meta("fx_delay", 0.0)):
			_started[i] = true
			if not _stopping:
				_particles[i].restart()
				_particles[i].emitting = true
	if not _impact_sent and _time >= impact_time:
		_impact_sent = true
		if impact_strength > 0.0:
			impact.emit(impact_strength)
	if _stopping:
		_fade = maxf(_fade - delta / maxf(stop_fade, 0.01), 0.0)
		_apply_modulate()
		if _fade <= 0.0:
			_end()
	elif not looping and _time >= duration:
		_end()


func _update_layers() -> void:
	for l in _layers:
		(l.material as ShaderMaterial).set_shader_parameter("fx_time", _time)


func _apply_modulate() -> void:
	modulate = Color(tint.r, tint.g, tint.b, tint.a * _fade)


func _end() -> void:
	_playing = false
	set_process(false)
	finished.emit()
	if free_when_done:
		queue_free()
