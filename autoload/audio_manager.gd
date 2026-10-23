extends Node

# AudioManager Autoload (Singleton)
# Mirrors SoundPlayerComponent from Flutter app:
# Handles background musics (themes, queue, game) and SFX (clicks, turns, wins, pieces)

const SETTINGS_PATH = "user://settings.cfg"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_CHANNELS: int = 8
var current_sfx_index: int = 0

var is_music_enabled: bool = true
var is_sound_enabled: bool = true

# Preloaded Sounds (.wav)
var sounds: Dictionary = {}

# Preloaded Musics (.mp3)
var music_themes: Array[AudioStream] = []
var music_queue: AudioStream
var music_games: Array[AudioStream] = []

func _ready() -> void:
	_load_settings()
	_init_audio_players()
	_load_audio_assets()

func _init_audio_players() -> void:
	# Music Player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	
	# SFX Channel Pool (allows overlapping sound effects like clicks + bells)
	for i in range(MAX_SFX_CHANNELS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_players.append(player)

func _load_audio_assets() -> void:
	# Load Musics
	var t1 = load("res://assets/musics/theme1.mp3")
	var t2 = load("res://assets/musics/theme2.mp3")
	if t1: music_themes.append(t1)
	if t2: music_themes.append(t2)
	
	music_queue = load("res://assets/musics/queue.mp3")
	
	for i in range(1, 9):
		var path = "res://assets/musics/game%d.mp3" % i
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream: music_games.append(stream)
	
	# Load Sound Effects
	var sound_names = [
		"add_peace", "bell", "chat", "correct", "dice", "draw", "explode",
		"hit", "lose", "miss_turn", "move_peace", "queue-finded", "remove_peace",
		"start_game", "start_turn", "tap", "tap_button", "tap_wrong", "time", "win"
	]
	
	for s_name in sound_names:
		var path = "res://assets/sounds/%s.mp3" % s_name
		if ResourceLoader.exists(path):
			sounds[s_name] = load(path)

# --- MUSIC CONTROL ---

var current_music_mode: String = "none" # "theme", "queue", "game"

func play_theme_music() -> void:
	current_music_mode = "theme"
	if not is_music_enabled or music_themes.is_empty():
		return
	var stream = music_themes[randi() % music_themes.size()]
	_play_music_stream(stream)

func play_queue_music() -> void:
	current_music_mode = "queue"
	if not is_music_enabled or not music_queue:
		return
	_play_music_stream(music_queue)

func play_game_music() -> void:
	current_music_mode = "game"
	if not is_music_enabled or music_games.is_empty():
		return
	var stream = music_games[randi() % music_games.size()]
	_play_music_stream(stream)

func stop_music() -> void:
	current_music_mode = "none"
	music_player.stop()

func _play_music_stream(stream: AudioStream) -> void:
	if stream:
		music_player.stream = stream
		music_player.play()

func _on_music_finished() -> void:
	# Loop or rotate according to mode
	match current_music_mode:
		"theme":
			play_theme_music()
		"queue":
			play_queue_music()
		"game":
			play_game_music()

# --- SFX CONTROL ---

func play_sound(sound_name: String) -> void:
	if not is_sound_enabled:
		return
	
	if sounds.has(sound_name):
		var stream = sounds[sound_name]
		var player = sfx_players[current_sfx_index]
		player.stream = stream
		player.play()
		current_sfx_index = (current_sfx_index + 1) % MAX_SFX_CHANNELS

func stop_sound(sound_name: String) -> void:
	if sounds.has(sound_name):
		var target_stream = sounds[sound_name]
		for player in sfx_players:
			if player.playing and player.stream == target_stream:
				player.stop()

func stop_all_sfx() -> void:
	for player in sfx_players:
		if player.playing:
			player.stop()

# Shorthand helpers matching Flutter GameSoundTypes
func sfx_tap() -> void: play_sound("tap")
func sfx_button() -> void: play_sound("tap_button")
func sfx_dialog() -> void: play_sound("tap")
func sfx_add_piece() -> void: play_sound("add_peace")
func sfx_move_piece() -> void: play_sound("move_peace")
func sfx_start_game() -> void: play_sound("start_game")
func sfx_start_turn() -> void: play_sound("start_turn")
func sfx_queue_found() -> void: play_sound("queue-finded")
func sfx_win() -> void: play_sound("win")
func sfx_lose() -> void: play_sound("lose")
func sfx_draw() -> void: play_sound("draw")
func sfx_dice() -> void: play_sound("dice")
func sfx_bell() -> void: play_sound("bell")
func sfx_time() -> void: play_sound("time")

# --- SETTINGS TOGGLE ---

func set_music_enabled(enabled: bool) -> void:
	is_music_enabled = enabled
	_save_settings()
	if not enabled:
		music_player.stop()
	else:
		if current_music_mode == "theme": play_theme_music()
		elif current_music_mode == "queue": play_queue_music()
		elif current_music_mode == "game": play_game_music()

func set_sound_enabled(enabled: bool) -> void:
	is_sound_enabled = enabled
	_save_settings()

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		is_music_enabled = config.get_value("audio", "music", true)
		is_sound_enabled = config.get_value("audio", "sound", true)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music", is_music_enabled)
	config.set_value("audio", "sound", is_sound_enabled)
	config.save(SETTINGS_PATH)
