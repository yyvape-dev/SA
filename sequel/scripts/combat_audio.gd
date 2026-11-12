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
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for cue in ["swing", "hit", "heavy", "guard", "guard_dry", "dash", "skill"]:
        streams[cue] = AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/audio/" + cue + ".wav.dat"))
    music = AudioStreamPlayer.new()
    music.volume_db = -20.0
    add_child(music)
    for i in 8:
        var voice := AudioStreamPlayer.new()
        voice.volume_db = -12.0
        add_child(voice)
        voices.append(voice)
func play_cue(cue: String) -> void:
    if not streams.has(cue): return
    var voice := voices[cursor]
    cursor = (cursor + 1) % voices.size()
    voice.stream = streams[cue]
    voice.volume_db = -16.0 if cue == "swing" else -12.0
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
    if music != null: music.volume_db = -28.0 if enabled else -20.0
