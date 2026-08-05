extends Node

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music_volume: float = 0.7
var sfx_volume: float = 1.0

func _ready() -> void:
    add_child(music_player)
    add_child(sfx_player)
    music_player.bus = "Music"
    sfx_player.bus = "SFX"

func play_sfx(stream: AudioStream) -> void:
    sfx_player.stream = stream
    sfx_player.play()