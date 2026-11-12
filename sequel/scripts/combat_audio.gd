extends Node
## Adopted CC0 sounds. Playback testing does not certify subjective sound quality.
signal cue_played(cue: String)
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
var music: AudioStreamPlayer
var current_music := ""
var music_streams := {}
var dialogue_duck := false
var settings_path := "user://sound_options.cfg"
var bgm_gain := 1.0
var se_gain := 1.0
var muted := false
var options_ui: CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var config := ConfigFile.new()
    if config.load(settings_path) == OK:
        bgm_gain = clampf(float(config.get_value("audio", "bgm", 1.0)), 0.0, 1.0)
        se_gain = clampf(float(config.get_value("audio", "se", 1.0)), 0.0, 1.0)
        muted = bool(config.get_value("audio", "muted", false))
    for cue in ["swing", "hit", "heavy", "guard", "guard_dry", "dash", "skill"]:
        streams[cue] = AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/audio/" + cue + ".wav.dat"))
    music = AudioStreamPlayer.new()
    music.volume_db = -20.0
    add_child(music)
    for i in 8:
        var voice := AudioStreamPlayer.new()
        voice.volume_db = -12.0
        add_child(voice)
        voice.set_meta("base_db", -12.0)
        voices.append(voice)
    _apply_options()
    options_ui = load("res://scripts/sound_options.gd").new()
    options_ui.audio = self
    add_child(options_ui)
func play_cue(cue: String) -> void:
    if not streams.has(cue): return
    var voice := voices[cursor]
    cursor = (cursor + 1) % voices.size()
    voice.stream = streams[cue]
    voice.set_meta("base_db", -16.0 if cue == "swing" else -12.0)
    voice.volume_db = float(voice.get_meta("base_db")) + _gain_db(se_gain)
    voice.play()
    cue_played.emit(cue)

# Called only after gameplay has loaded; keep music out of the initial runtime/data load.
func set_region(town: String, in_dungeon: bool) -> void:
    var key := "dungeon" if in_dungeon else ("town" if town == "back" else "")
    if key == current_music: return
    if key.is_empty():
        music.stop()
        current_music = ""
        return
    if not music_streams.has(key):
        if not ProjectSettings.load_resource_pack("res://assets/audio/music.pck", false):
            push_error("SA2 music pack cannot load")
            return
        var stream := AudioStreamOggVorbis.load_from_buffer(FileAccess.get_file_as_bytes("res://sa2_music/" + key + ".ogg.dat"))
        if stream == null: return
        stream.loop = true
        music_streams[key] = stream
    music.stream = music_streams[key]
    current_music = key
    music.play()

func set_dialogue_duck(enabled: bool) -> void:
    dialogue_duck = enabled
    _apply_options()

func _gain_db(gain: float) -> float:
    return -80.0 if muted or gain <= 0.0 else linear_to_db(gain)

func _apply_options() -> void:
    if music != null:
        music.volume_db = (-28.0 if dialogue_duck else -20.0) + _gain_db(bgm_gain)
    for voice in voices:
        voice.volume_db = float(voice.get_meta("base_db", -12.0)) + _gain_db(se_gain)

func set_audio_options(bgm: float, se: float, mute: bool) -> void:
    bgm_gain = clampf(bgm, 0.0, 1.0)
    se_gain = clampf(se, 0.0, 1.0)
    muted = mute
    _apply_options()
    var config := ConfigFile.new()
    config.set_value("audio", "bgm", bgm_gain)
    config.set_value("audio", "se", se_gain)
    config.set_value("audio", "muted", muted)
    if config.save(settings_path) != OK:
        push_warning("Sound preferences could not be saved")
