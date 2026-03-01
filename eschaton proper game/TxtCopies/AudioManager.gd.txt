extends Node
class_name AudioManager

@export var sfx_laser: AudioStream
@export var sfx_explosion: AudioStream
@export var sfx_move: AudioStream
@export var sfx_ui: AudioStream

var players: Dictionary = {}

func _ready() -> void:
	_create_player("SFX_Laser", sfx_laser)
	_create_player("SFX_Explosion", sfx_explosion)
	_create_player("SFX_Move", sfx_move)
	_create_player("SFX_UI", sfx_ui)

func _create_player(p_name: String, stream: AudioStream) -> void:
	var player = AudioStreamPlayer.new()
	player.name = p_name
	if stream:
		player.stream = stream
	add_child(player)
	players[p_name] = player

func play_sfx(sfx_name: String) -> void:
	if players.has(sfx_name):
		var player: AudioStreamPlayer = players[sfx_name]
		if player.stream:
			# Slight random pitch variation (0.9 to 1.1) to make it organic
			player.pitch_scale = randf_range(0.9, 1.1)
			player.play()
		else:
			# Dummy system since files aren't provided yet
			_print_dummy_sfx(sfx_name)
	else:
		_print_dummy_sfx(sfx_name)

func _print_dummy_sfx(sfx_name: String) -> void:
	match sfx_name:
		"SFX_Laser":
			print("[AUDIO] PEW!")
		"SFX_Explosion":
			print("[AUDIO] BOOM!")
		"SFX_Move":
			print("[AUDIO] swish...")
		"SFX_UI":
			print("[AUDIO] click")
		_:
			print("[AUDIO] " + sfx_name)
