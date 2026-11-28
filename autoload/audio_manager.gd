extends Node

# AudioManager Autoload (Singleton)
# Mirrors SoundPlayerComponent from Flutter app and adds mobile-safe audio enhancements:
# - Dedicated Music & SFX audio buses + Master safety limiter
# - Dual-player smooth music crossfading & non-repeating shuffle
# - Asynchronous threaded music loading to prevent Android main-thread frame hitches
# - Priority-aware SFX channel allocation, double-trigger cooldown, & pitch micro-variation
# - Automatic music ducking for win/lose/draw/queue-found/start-game fanfares
# - Android pause/focus lifecycle audio suspension

const SETTINGS_PATH = "user://settings.cfg"

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

const MAX_SFX_CHANNELS: int = 12
const CROSSFADE_SEC: float = 0.55
const INITIAL_FADE_SEC: float = 0.28
const PREVIEW_COOLDOWN_MS: int = 160

const PROTECTED_SOUNDS := {
	"win": true,
	"lose": true,
	"draw": true,
	"start_game": true,
	"queue-finded": true,
	"explode": true,
}

const PRIORITY_GAMEPLAY_SOUNDS := {
	"start_turn": true,
	"bell": true,
	"dice": true,
	"chat": true,
	"correct": true,
	"hit": true,
	"miss_turn": true,
	"remove_peace": true,
	"add_peace": true,
	"move_peace": true,
}

const COOLDOWN_MS := {
	"tap": 45,
	"tap_button": 45,
	"tap_wrong": 80,
	"move_peace": 35,
	"add_peace": 35,
	"hit": 45,
	"chat": 120,
	"time": 110,
}

const PITCH_VARIANCE := {
	"tap": 0.03,
	"tap_button": 0.03,
	"add_peace": 0.05,
	"move_peace": 0.06,
	"remove_peace": 0.05,
	"hit": 0.06,
	"dice": 0.06,
}

const DUCK_SETTINGS := {
	"win": {"factor": 0.40, "hold": 1.8},
	"lose": {"factor": 0.42, "hold": 1.6},
	"draw": {"factor": 0.45, "hold": 1.4},
	"start_game": {"factor": 0.48, "hold": 1.2},
	"queue-finded": {"factor": 0.45, "hold": 1.3},
}

var music_player: AudioStreamPlayer
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_idx: int = 0
var _music_fade_tween: Tween = null

var sfx_players: Array[AudioStreamPlayer] = []
var _sfx_channel_priority: Array[int] = []
var _sfx_channel_order: Array[int] = []
var _sfx_play_seq: int = 0
var _sfx_last_play_ms: Dictionary = {}
var _last_preview_ms: int = 0

var is_music_enabled: bool = true
var is_sound_enabled: bool = true
var music_volume: float = 0.5
var sfx_volume: float = 1.0

var _music_bus_idx: int = -1
var _sfx_bus_idx: int = -1
var _duck_factor: float = 1.0
var _duck_tween: Tween = null
var _paused_by_os: bool = false
var _is_mobile: bool = false

# Preloaded SFX streams
var sounds: Dictionary = {}

# Lazy-loaded Music Paths (.mp3) to avoid loading ~25MB synchronously at startup
var music_theme_paths: Array[String] = []
var music_queue_path: String = ""
var music_game_paths: Array[String] = []
var _current_music_path: String = ""
var _last_theme_path: String = ""
var _last_game_path: String = ""
var _pending_music_path: String = ""

var current_music_mode: String = "none" # "theme", "queue", "game"


func _ready() -> void:
	_is_mobile = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	set_process(false)
	_ensure_audio_buses()
	_load_settings()
	_init_audio_players()
	_apply_volumes()
	_load_audio_assets()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_set_os_audio_paused(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_set_os_audio_paused(false)
	elif _is_mobile and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_os_audio_paused(true)
	elif _is_mobile and what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_os_audio_paused(false)


func _set_os_audio_paused(paused: bool) -> void:
	if _paused_by_os == paused:
		return
	_paused_by_os = paused
	for mp in _music_players:
		if is_instance_valid(mp):
			mp.stream_paused = paused
	if paused:
		stop_sound("time")


func _ensure_audio_buses() -> void:
	_music_bus_idx = AudioServer.get_bus_index(BUS_MUSIC)
	if _music_bus_idx == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_MUSIC)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		_music_bus_idx = idx

	_sfx_bus_idx = AudioServer.get_bus_index(BUS_SFX)
	if _sfx_bus_idx == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		_sfx_bus_idx = idx


func _init_audio_players() -> void:
	var music_bus := BUS_MUSIC if _music_bus_idx >= 0 else BUS_MASTER
	var sfx_bus := BUS_SFX if _sfx_bus_idx >= 0 else BUS_MASTER

	for i in range(2):
		var mp := AudioStreamPlayer.new()
		mp.bus = music_bus
		mp.volume_db = -80.0
		add_child(mp)
		mp.finished.connect(_on_music_player_finished.bind(mp))
		_music_players.append(mp)

	music_player = _music_players[0]

	# Priority-managed SFX Channel Pool (allows overlapping SFX without cutting fanfares)
	for i in range(MAX_SFX_CHANNELS):
		var player := AudioStreamPlayer.new()
		player.bus = sfx_bus
		add_child(player)
		sfx_players.append(player)
		_sfx_channel_priority.append(0)
		_sfx_channel_order.append(0)


func _load_audio_assets() -> void:
	for t_path in ["res://assets/musics/theme1.mp3", "res://assets/musics/theme2.mp3"]:
		if ResourceLoader.exists(t_path):
			music_theme_paths.append(t_path)

	if ResourceLoader.exists("res://assets/musics/queue.mp3"):
		music_queue_path = "res://assets/musics/queue.mp3"

	for i in range(1, 9):
		var path := "res://assets/musics/game%d.mp3" % i
		if ResourceLoader.exists(path):
			music_game_paths.append(path)

	# Prefer low-latency .wav/.ogg if present, falling back cleanly to .mp3
	var sound_names := [
		"add_peace", "bell", "chat", "correct", "dice", "draw", "explode",
		"hit", "lose", "miss_turn", "move_peace", "queue-finded", "remove_peace",
		"start_game", "start_turn", "tap", "tap_button", "tap_wrong", "time", "win"
	]

	for s_name in sound_names:
		for ext in ["wav", "ogg", "mp3"]:
			var path := "res://assets/sounds/%s.%s" % [s_name, ext]
			if ResourceLoader.exists(path):
				sounds[s_name] = load(path)
				break


func _process(_delta: float) -> void:
	if _pending_music_path.is_empty():
		set_process(false)
		return
	var status := ResourceLoader.load_threaded_get_status(_pending_music_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var stream := ResourceLoader.load_threaded_get(_pending_music_path) as AudioStream
		var finished_path := _pending_music_path
		_pending_music_path = ""
		set_process(false)
		if stream != null and is_music_enabled and current_music_mode != "none":
			_start_music_stream(finished_path, stream)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var fallback_path := _pending_music_path
		_pending_music_path = ""
		set_process(false)
		var fallback_stream := ResourceLoader.load(fallback_path) as AudioStream
		if fallback_stream != null and is_music_enabled and current_music_mode != "none":
			_start_music_stream(fallback_path, fallback_stream)


# --- MUSIC CONTROL ---

func _pick_non_repeating_path(paths: Array[String], last_path: String) -> String:
	if paths.is_empty():
		return ""
	if paths.size() == 1:
		return paths[0]
	var candidates: Array[String] = []
	for p in paths:
		if p != last_path:
			candidates.append(p)
	if candidates.is_empty():
		return paths[randi() % paths.size()]
	return candidates[randi() % candidates.size()]


func play_theme_music(force_restart: bool = false) -> void:
	if GameManager.is_game_active:
		play_game_music(force_restart)
		return
	if current_music_mode == "theme" and ((is_instance_valid(music_player) and music_player.playing) or not _pending_music_path.is_empty()) and not force_restart:
		return
	current_music_mode = "theme"
	if not is_music_enabled or music_theme_paths.is_empty():
		return
	var path := _pick_non_repeating_path(music_theme_paths, _last_theme_path)
	_last_theme_path = path
	_play_music_path(path)


func play_queue_music(force_restart: bool = false) -> void:
	if current_music_mode == "queue" and ((is_instance_valid(music_player) and music_player.playing) or not _pending_music_path.is_empty()) and not force_restart:
		return
	current_music_mode = "queue"
	if not is_music_enabled or music_queue_path.is_empty():
		return
	_play_music_path(music_queue_path)


func play_game_music(force_restart: bool = true) -> void:
	if current_music_mode == "game" and ((is_instance_valid(music_player) and music_player.playing) or not _pending_music_path.is_empty()) and not force_restart:
		return
	current_music_mode = "game"
	if not is_music_enabled or music_game_paths.is_empty():
		return
	var path := _pick_non_repeating_path(music_game_paths, _last_game_path)
	_last_game_path = path
	_play_music_path(path)


func stop_music() -> void:
	current_music_mode = "none"
	_pending_music_path = ""
	set_process(false)
	if _music_fade_tween and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()
		_music_fade_tween = null
	for mp in _music_players:
		if is_instance_valid(mp):
			mp.stop()
			mp.stream = null
			mp.volume_db = -80.0
	_current_music_path = ""


func _play_music_path(path: String) -> void:
	if path.is_empty():
		return
	if _current_music_path == path and is_instance_valid(music_player) and music_player.stream != null:
		_start_music_stream(path, music_player.stream)
		return
	if ResourceLoader.has_cached(path):
		var cached := ResourceLoader.load(path) as AudioStream
		if cached != null:
			_start_music_stream(path, cached)
			return
	var err := ResourceLoader.load_threaded_request(path, "AudioStream", false)
	if err == OK:
		_pending_music_path = path
		set_process(true)
	else:
		var sync_stream := ResourceLoader.load(path) as AudioStream
		if sync_stream != null:
			_start_music_stream(path, sync_stream)


func _start_music_stream(path: String, stream: AudioStream) -> void:
	if _music_players.size() < 2 or stream == null:
		return
	var old_player := _music_players[_active_music_idx]
	var next_idx := 1 - _active_music_idx
	var next_player := _music_players[next_idx]

	_active_music_idx = next_idx
	music_player = next_player
	_current_music_path = path

	if next_player.stream != stream:
		next_player.stream = stream
	next_player.stream_paused = _paused_by_os
	next_player.volume_db = -80.0
	next_player.play()

	if _music_fade_tween and is_instance_valid(_music_fade_tween):
		_music_fade_tween.kill()

	var was_old_playing := is_instance_valid(old_player) and old_player.playing and old_player != next_player
	var fade_dur := CROSSFADE_SEC if was_old_playing else INITIAL_FADE_SEC
	_music_fade_tween = create_tween().set_parallel(true)
	_music_fade_tween.tween_method(func(g: float) -> void:
		if is_instance_valid(next_player):
			next_player.volume_db = linear_to_db(g) if g > 0.001 else -80.0
	, 0.0, 1.0, fade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if was_old_playing:
		var start_old_gain := db_to_linear(old_player.volume_db)
		_music_fade_tween.tween_method(func(g: float) -> void:
			if is_instance_valid(old_player):
				old_player.volume_db = linear_to_db(g) if g > 0.001 else -80.0
		, start_old_gain, 0.0, fade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_fade_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(old_player) and old_player != music_player:
				old_player.stop()
				old_player.stream = null
		)


func _on_music_player_finished(finished_player: AudioStreamPlayer) -> void:
	if finished_player != music_player:
		return
	match current_music_mode:
		"theme":
			play_theme_music(true)
		"queue":
			play_queue_music(true)
		"game":
			play_game_music(true)


# --- SFX CONTROL ---

func _get_sound_priority(sound_name: String) -> int:
	if PROTECTED_SOUNDS.has(sound_name):
		return 2
	if PRIORITY_GAMEPLAY_SOUNDS.has(sound_name):
		return 1
	return 0


func _acquire_sfx_channel(incoming_prio: int) -> int:
	for i in range(sfx_players.size()):
		if not sfx_players[i].playing:
			return i

	var best_idx := 0
	var lowest_prio := 999
	var oldest_seq := 2147483647
	for i in range(sfx_players.size()):
		var p := _sfx_channel_priority[i]
		if p > incoming_prio:
			continue
		if p < lowest_prio or (p == lowest_prio and _sfx_channel_order[i] < oldest_seq):
			lowest_prio = p
			oldest_seq = _sfx_channel_order[i]
			best_idx = i
	return best_idx


func _trigger_music_duck(sound_name: String) -> void:
	if not DUCK_SETTINGS.has(sound_name) or not is_music_enabled or music_volume <= 0.001:
		return
	var cfg: Dictionary = DUCK_SETTINGS[sound_name]
	var target_factor := float(cfg.get("factor", 0.45))
	var hold_sec := float(cfg.get("hold", 1.3))

	if _duck_tween and is_instance_valid(_duck_tween):
		_duck_tween.kill()

	_duck_tween = create_tween()
	_duck_tween.tween_method(func(f: float) -> void:
		_duck_factor = f
		_apply_music_bus_volume()
	, _duck_factor, target_factor, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_duck_tween.tween_interval(hold_sec)
	_duck_tween.tween_method(func(f: float) -> void:
		_duck_factor = f
		_apply_music_bus_volume()
	, target_factor, 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func play_sound(sound_name: String) -> void:
	var variance := float(PITCH_VARIANCE.get(sound_name, 0.0))
	var pitch := randf_range(1.0 - variance, 1.0 + variance) if variance > 0.0 else 1.0
	play_sound_pitched(sound_name, pitch, 0.0)


func play_sound_pitched(sound_name: String, pitch_scale_val: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not is_sound_enabled or not sounds.has(sound_name):
		return

	var now_ms := Time.get_ticks_msec()
	var min_cooldown := int(COOLDOWN_MS.get(sound_name, 0))
	if min_cooldown > 0:
		var prev_ms := int(_sfx_last_play_ms.get(sound_name, -999999))
		if now_ms - prev_ms < min_cooldown:
			return
	_sfx_last_play_ms[sound_name] = now_ms

	var prio := _get_sound_priority(sound_name)
	var ch_idx := _acquire_sfx_channel(prio)
	var player := sfx_players[ch_idx]

	_sfx_play_seq += 1
	_sfx_channel_priority[ch_idx] = prio
	_sfx_channel_order[ch_idx] = _sfx_play_seq

	player.stream = sounds[sound_name]
	player.pitch_scale = clampf(pitch_scale_val, 0.5, 2.0)
	player.volume_db = volume_offset_db
	player.play()

	_trigger_music_duck(sound_name)


func play_sfx_preview() -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_preview_ms < PREVIEW_COOLDOWN_MS:
		return
	_last_preview_ms = now_ms
	play_sound("tap")


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


# Shorthand helpers matching Flutter GameSoundTypes + distinct game-feel cues
func sfx_tap() -> void: play_sound("tap")
func sfx_button() -> void: play_sound("tap_button")
func sfx_dialog() -> void: play_sound("tap")
func sfx_add_piece() -> void: play_sound("add_peace")
func sfx_move_piece() -> void: play_sound("move_peace")
func sfx_start_game() -> void: play_sound("start_game")
func sfx_start_turn() -> void: play_sound("start_turn")
func sfx_queue_found() -> void: play_sound("queue-finded")
func sfx_win() -> void:
	play_sound("win")
	_haptic_pulse(45)
func sfx_lose() -> void: play_sound("lose")
func sfx_draw() -> void: play_sound("draw")
func sfx_dice() -> void: play_sound("dice")
func sfx_bell() -> void: play_sound("bell")
func sfx_time() -> void: play_sound("time")
func sfx_place() -> void: play_sound("add_peace")
func sfx_invalid() -> void:
	play_sound("tap_wrong")
	_haptic_pulse(22)
func sfx_capture() -> void:
	play_sound("correct")
	_haptic_pulse(28)
func sfx_win_line() -> void:
	play_sound("explode")
	_haptic_pulse(38)
func sfx_card_play() -> void:
	play_sound_pitched("move_peace", randf_range(1.08, 1.18), -1.0)
func sfx_coin() -> void:
	play_sound_pitched("bell", randf_range(1.18, 1.26), -3.0)


func _haptic_pulse(duration_ms: int) -> void:
	if _is_mobile and is_sound_enabled:
		Input.vibrate_handheld(duration_ms)


# --- SETTINGS TOGGLE ---

func set_music_enabled(enabled: bool) -> void:
	is_music_enabled = enabled
	_save_settings()
	if not enabled:
		_pending_music_path = ""
		set_process(false)
		if _music_fade_tween and is_instance_valid(_music_fade_tween):
			_music_fade_tween.kill()
		for mp in _music_players:
			if is_instance_valid(mp):
				mp.stop()
				mp.volume_db = -80.0
	else:
		if current_music_mode == "theme": play_theme_music()
		elif current_music_mode == "queue": play_queue_music()
		elif current_music_mode == "game": play_game_music()


func set_sound_enabled(enabled: bool) -> void:
	is_sound_enabled = enabled
	_apply_sfx_bus_volume()
	_save_settings()


func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_music_bus_volume()
	_save_settings()


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_sfx_bus_volume()
	_save_settings()


func _apply_music_bus_volume() -> void:
	var eff := music_volume * _duck_factor
	var db := linear_to_db(eff) if eff > 0.001 else -80.0
	if _music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_music_bus_idx, db)
	elif is_instance_valid(music_player):
		music_player.volume_db = db


func _apply_sfx_bus_volume() -> void:
	var eff := sfx_volume if is_sound_enabled else 0.0
	var db := linear_to_db(eff) if eff > 0.001 else -80.0
	if _sfx_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_sfx_bus_idx, db)
	else:
		for player in sfx_players:
			if is_instance_valid(player):
				player.volume_db = db


func _apply_volumes() -> void:
	_apply_music_bus_volume()
	_apply_sfx_bus_volume()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		is_music_enabled = bool(config.get_value("audio", "music", true))
		is_sound_enabled = bool(config.get_value("audio", "sound", true))
		music_volume = clampf(float(config.get_value("audio", "music_volume", 0.5)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	else:
		music_volume = 0.5
		sfx_volume = 1.0
	_apply_volumes()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music", is_music_enabled)
	config.set_value("audio", "sound", is_sound_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)
