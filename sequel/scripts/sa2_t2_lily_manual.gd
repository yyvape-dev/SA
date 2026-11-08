extends Node
## T2 only: drives the existing Lily animation and hit callbacks without enabling her companion AI.
## Never changes the default behavior of scripts/ally.gd.
signal guard_success
signal dodge_started
signal attack_started(clip: String)

const WALK_SPEED := 4.0
const DEPTH_FACTOR := 0.75
const DODGE_TIME := 0.24
const DODGE_DISTANCE := 3.5
const GUARD_MIN := 0.15
const GUARD_MAX := 0.32
const GUARD_REACH := 1.8
const ATTACKS := ["atk_jabkick", "atk_highkick", "atk_roundhouse", "atk_heeldrop", "atk_rush"]

var actor
var battle
var move_in := Vector2.ZERO
var locked := true
var dodge_left := 0.0
var dodge_direction := Vector2.RIGHT
var animation_t := 0.0
var attack_index := 0
var guard_count := 0
var dodge_count := 0
var attack_count := 0

func setup(lily, combat) -> void:
    actor = lily
    battle = combat
    actor.set_physics_process(false)
    actor.state = "move"
    actor.cd = 0.0
    actor.inv = 0.0
    actor._show("idle", 0)
    locked = false

static func guard_candidate(e, at: Vector3) -> bool:
    if e.state != "atk" or bool(e.atk.get("done", false)):
        return false
    var rem: float = float(e.atk.get("hit_t", -1.0)) - float(e.atk.get("t", 0.0))
    if rem < GUARD_MIN or rem > GUARD_MAX:
        return false
    var offset: Vector3 = e.position - at
    return absf(offset.x) <= GUARD_REACH and absf(offset.z) <= 0.9

func attack_press() -> void:
    if locked or actor == null or actor.state != "move" or dodge_left > 0.0:
        return
    var e = actor._nearest()
    if e == null:
        return
    var clip: String = ATTACKS[attack_index % ATTACKS.size()]
    attack_index += 1
    if not actor.data.clips.has(clip):
        return
    actor.force_attack(clip, e)
    attack_count += 1
    attack_started.emit(clip)

func attack_release() -> void:
    pass # Not a hold attack: existing Lily clips are discrete.

func dodge() -> void:
    if locked or actor == null or actor.state != "move" or dodge_left > 0.0:
        return
    for foe in battle.enemies:
        if not is_instance_valid(foe):
            continue
        if guard_candidate(foe, actor.position):
            foe.atk.done = true
            foe.state = "stun"
            foe.stun = maxf(foe.stun, 0.8)
            foe.kx = (-1 if foe.position.x < actor.position.x else 1) * 1.2
            actor.inv = maxf(actor.inv, 0.6)
            guard_count += 1
            guard_success.emit()
            return
    var direction: Vector2 = move_in.normalized() if move_in.length() > 0.2 else Vector2(float(actor.face), 0)
    dodge_direction = direction
    dodge_left = DODGE_TIME
    actor.inv = maxf(actor.inv, DODGE_TIME + 0.12)
    dodge_count += 1
    dodge_started.emit()

func _physics_process(delta: float) -> void:
    if actor == null or battle == null or locked:
        return
    if actor.state != "move":
        actor._physics_process(delta) # Existing Lily hit-frame timing, VFX and combat callbacks.
        return
    var dt: float = battle.dt(delta)
    if dt <= 0.0:
        return
    actor.inv = maxf(0.0, actor.inv - dt)
    animation_t += dt
    var direction := move_in
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.y += 1.0
    direction = direction.limit_length(1.0)
    if dodge_left > 0.0:
        direction = dodge_direction
        var step := minf(dodge_left, dt)
        dodge_left = maxf(0.0, dodge_left - dt)
        actor.position.x += direction.x * DODGE_DISTANCE / DODGE_TIME * step
        actor.position.z += direction.y * DODGE_DISTANCE / DODGE_TIME * step * DEPTH_FACTOR
    else:
        actor.position.x += direction.x * WALK_SPEED * dt
        actor.position.z += direction.y * WALK_SPEED * dt * DEPTH_FACTOR
    actor.position.x = clampf(actor.position.x, battle.ROOM_X.x, battle.ROOM_X.y)
    actor.position.z = clampf(actor.position.z, battle.BELT_Z.x, battle.BELT_Z.y)
    if absf(direction.x) > 0.1:
        actor.face = 1 if direction.x > 0.0 else -1
    var clip: String = "run" if dodge_left > 0.0 else "walk"
    if direction.length() < 0.1:
        clip = "idle"
    if not actor.data.clips.has(clip):
        clip = "idle"
    var frames: Array = actor.data.clips[clip].frames
    var fps: float = float(actor.data.clips[clip].fps)
    actor._show(clip, int(animation_t * fps) % frames.size())
    battle.apply_light(actor.sprite, actor.mat, actor.refl, actor.position)

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo or locked:
        return
    if event.keycode == KEY_J or event.keycode == KEY_Z:
        attack_press()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_K or event.keycode == KEY_X:
        dodge()
        get_viewport().set_input_as_handled()
