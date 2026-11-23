class_name TutorialStore
extends RefCounted

## Persistent local storage for Cafe Fekr onboarding & tutorial progression.
## Stored independently from auth session (`user://session.cfg`) so logging out
## never resets one-time post-auth tutorials while pre-login game tutorial still
## triggers automatically whenever the player is not logged in.

const CONFIG_PATH: String = "user://tutorial_state.cfg"
const SECTION: String = "tutorial"
const KEY_SCHEMA_VERSION: String = "schema_version"
const KEY_MAIN_TOUR_COMPLETED: String = "main_tour_completed"
const KEY_GAME_TUTORIAL_WINS: String = "game_tutorial_wins"
const KEY_MAIN_TOUR_COMPLETED_AT: String = "main_tour_completed_at"
const CURRENT_SCHEMA_VERSION: int = 1


static func _load_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(CONFIG_PATH)
	if err != OK:
		cfg.set_value(SECTION, KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
	return cfg


static func _save_config(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
	var err: Error = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("[TutorialStore] Failed to save tutorial state (err=%d)" % err)


static func is_main_tour_completed() -> bool:
	var cfg: ConfigFile = _load_config()
	return bool(cfg.get_value(SECTION, KEY_MAIN_TOUR_COMPLETED, false))


static func mark_main_tour_completed() -> void:
	var cfg: ConfigFile = _load_config()
	cfg.set_value(SECTION, KEY_MAIN_TOUR_COMPLETED, true)
	cfg.set_value(SECTION, KEY_MAIN_TOUR_COMPLETED_AT, int(Time.get_unix_time_from_system()))
	_save_config(cfg)


static func get_game_tutorial_wins() -> int:
	var cfg: ConfigFile = _load_config()
	return int(cfg.get_value(SECTION, KEY_GAME_TUTORIAL_WINS, 0))


static func record_game_tutorial_win() -> void:
	var cfg: ConfigFile = _load_config()
	var current_wins: int = int(cfg.get_value(SECTION, KEY_GAME_TUTORIAL_WINS, 0))
	cfg.set_value(SECTION, KEY_GAME_TUTORIAL_WINS, current_wins + 1)
	_save_config(cfg)


static func reset_main_tour() -> void:
	var cfg: ConfigFile = _load_config()
	cfg.set_value(SECTION, KEY_MAIN_TOUR_COMPLETED, false)
	_save_config(cfg)


static func reset_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_SCHEMA_VERSION, CURRENT_SCHEMA_VERSION)
	cfg.set_value(SECTION, KEY_MAIN_TOUR_COMPLETED, false)
	cfg.set_value(SECTION, KEY_GAME_TUTORIAL_WINS, 0)
	_save_config(cfg)
