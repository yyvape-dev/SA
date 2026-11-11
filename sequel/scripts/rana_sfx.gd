extends Node
## SA2 Rana combat SFX playback. Add three authorized Pixabay clips as WAV files to
## res://assets/sfx/rana/ before enabling; intentionally never substitutes synth sounds.
## Source: https://pixabay.com/sound-effects/film-special-effects-sword-slash-and-swing-185432/
## Source: https://pixabay.com/sound-effects/film-special-effects-sword-blade-slicing-flesh-352708/
## Source: https://pixabay.com/sound-effects/film-special-effects-sword-block-the-ballad-of-blades-257226/
const FILES := {
	"swing": "res://assets/sfx/rana/sword_swing.wav",
	"hit": "res://assets/sfx/rana/sword_hit.wav",
	"just_guard": "res://assets/sfx/rana/just_guard.wav",
}
const VOICES := 4
var _streams: Dictionary = {}
var _players: Dictionary = {}
var _next: Dictionary = {}

func _ready() -> void:
	for kind in FILES:
		var path: String = FILES[kind]
		if not ResourceLoader.exists(path):
			push_warning("SA2 SFX missing: " + path + " (no substitute audio)")
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			push_warning("SA2 SFX invalid audio: " + path)
			continue
		_streams[kind] = stream
		_players[kind] = []
		_next[kind] = 0
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.name = "SFX_" + kind + "_" + str(i)
			p.bus = "Master"
			p.volume_db = -5.0 if kind == "hit" else -7.0
			p.stream = stream
			add_child(p)
			_players[kind].append(p)

func play_sfx(kind: String) -> void:
	if not _players.has(kind):
		return
	var slots: Array = _players[kind]
	var index: int = int(_next[kind])
	var p: AudioStreamPlayer = slots[index] as AudioStreamPlayer
	if p.playing:
		p.stop()
	p.play()
	_next[kind] = (index + 1) % slots.size()

func play_just_guard() -> void:
	play_sfx("just_guard")
