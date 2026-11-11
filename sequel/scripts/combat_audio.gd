extends Node
## Adopted CC0 sounds. Playback testing does not certify subjective sound quality.
signal cue_played(cue: String)
var streams := {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for cue in ["swing", "hit", "heavy", "guard", "guard_dry"]:
        streams[cue] = AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes("res://assets/audio/" + cue + ".wav.dat"))
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
