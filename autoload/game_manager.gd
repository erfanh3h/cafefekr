extends Node

const GameRegistry = preload("res://scripts/games/game_registry.gd")

# GameManager Autoload (Singleton)
signal user_logged_in(user_data: Dictionary)
signal user_logged_out()
signal game_started(game_id: String, game_data: Dictionary)
signal game_finished(winner_id: Variant)

const SETTINGS_PATH: String = "user://settings.cfg"
const SESSION_PATH: String = "user://session.cfg"

var device_id: String = ""
var token: String = ""
var user_data: Dictionary = {}
var is_logged_in: bool = false
var is_guest: bool = false

# Current Match State
var active_game_id: String = ""
var is_game_active: bool = false
var current_game_type: String = GameRegistry.DEFAULT_GAME_TYPE
var current_turn: int = 0 # 0 before start / setup phase; 1 or 2 during play
var my_player_index: int = 1 # 1 (Player 1) or 2 (Player 2)
var current_round: int = 1
var max_rounds: int = 5
var match_players: Array = []
var p1_score: int = 0
var p2_score: int = 0
var local_player_surrendered: bool = false
var opponent_player_surrendered: bool = false
var ludo_rank1: int = 0
var ludo_rank2: int = 0
var current_match_mode: String = "ranked"
var last_xp_gained: int = 0

func add_xp(amount: int) -> void:
	if amount > 0:
		var cur_xp = int(user_data.get("xp", 0))
		user_data["xp"] = cur_xp + amount
		print("[GameManager] Added %d XP. Total XP: %d" % [amount, user_data["xp"]])


var is_my_turn: bool:
	get:
		if not is_game_active:
			return false
		if GameRegistry.is_simultaneous(current_game_type):
			return true
		return current_turn == my_player_index

func set_game_type(new_game_type: String) -> void:
	current_game_type = GameRegistry.normalize_type(new_game_type)
	max_rounds = GameRegistry.get_max_rounds(current_game_type)
	print("[GameManager] Match Game Type set to: %s (Max Rounds: %d)" % [current_game_type, max_rounds])

func get_game_display_name() -> String:
	return GameRegistry.get_display_name_fa(current_game_type)

func reset_match_state() -> void:
	active_game_id = ""
	is_game_active = false
	match_players.clear()
	p1_score = 0
	p2_score = 0
	current_round = 1
	current_turn = 0
	my_player_index = 1
	local_player_surrendered = false
	opponent_player_surrendered = false
	ludo_rank1 = 0
	ludo_rank2 = 0
	current_game_type = GameRegistry.DEFAULT_GAME_TYPE
	max_rounds = GameRegistry.get_max_rounds(current_game_type)
	clear_open_game_id()

func clear_open_game_id() -> void:
	var changed = false
	if user_data.has("open_game_id"):
		user_data.erase("open_game_id")
		changed = true
	if user_data.has("game_id"):
		user_data.erase("game_id")
		changed = true
	if changed and not token.is_empty():
		var config = ConfigFile.new()
		config.set_value("auth", "token", token)
		config.set_value("auth", "user_data", user_data)
		config.set_value("auth", "is_guest", is_guest)
		config.save(SESSION_PATH)
		print("[GameManager] Cleared open_game_id from cached session.")

func set_match_gamers(gamers_list: Array) -> void:
	if gamers_list.is_empty():
		return
	match_players = gamers_list.duplicate()
	var my_uid = str(get_user_id())
	var my_uname = str(get_username())
	
	for i in range(match_players.size()):
		var g = match_players[i]
		var uid = str(g.get("user_id", ""))
		var uname = str(g.get("name", g.get("username", "")))
		var gid = int(g.get("gamer_id", 0))
		
		if (not my_uid.is_empty() and uid == my_uid) or (not my_uname.is_empty() and uname == my_uname):
			my_player_index = gid if gid > 0 else (i + 1)
			print("[GameManager] Assigned local player index: Player %d" % my_player_index)
			break

func get_player_data_by_gamer_id(gamer_id: int) -> Dictionary:
	for p in match_players:
		if int(p.get("gamer_id", 0)) == gamer_id:
			return p
	if gamer_id > 0 and gamer_id <= match_players.size():
		return match_players[gamer_id - 1]
	if gamer_id == my_player_index:
		return user_data
	return {}

func get_my_player_data() -> Dictionary:
	for p in match_players:
		if int(p.get("gamer_id", 0)) == my_player_index:
			return p
	if my_player_index > 0 and my_player_index <= match_players.size():
		return match_players[my_player_index - 1]
	return user_data

func get_opponent_player_data() -> Dictionary:
	var opp_idx = 2 if my_player_index == 1 else 1
	for p in match_players:
		if int(p.get("gamer_id", 0)) == opp_idx:
			return p
	if opp_idx > 0 and opp_idx <= match_players.size():
		return match_players[opp_idx - 1]
	return {}

func update_gamer_not_played_turns(gamer_id: int, count: int) -> void:
	for p in match_players:
		if int(p.get("gamer_id", 0)) == gamer_id:
			p["not_played_turns"] = count
			return

func get_player_not_played_turns(gamer_id: int) -> int:
	for p in match_players:
		if int(p.get("gamer_id", 0)) == gamer_id:
			return int(p.get("not_played_turns", 0))
	return 0

func _ready() -> void:
	_load_or_create_device_id()

func _load_or_create_device_id() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err == OK and config.has_section_key("device", "id"):
		device_id = config.get_value("device", "id")
	else:
		# Generate a persistent random device ID
		device_id = "device_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000)
		config.set_value("device", "id", device_id)
		config.save(SETTINGS_PATH)

func load_saved_token() -> String:
	var config = ConfigFile.new()
	var err = config.load(SESSION_PATH)
	if err == OK:
		is_guest = config.get_value("auth", "is_guest", false)
		if config.has_section_key("auth", "token"):
			return config.get_value("auth", "token", "")
	return ""

func load_saved_user_data() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SESSION_PATH)
	if err == OK:
		is_guest = config.get_value("auth", "is_guest", false)
		if config.has_section_key("auth", "user_data"):
			return config.get_value("auth", "user_data", {})
	return {}

func start_guest_session() -> void:
	is_guest = true
	is_logged_in = true
	token = "guest_" + device_id
	user_data = {
		"_id": "guest_" + device_id.substr(0, 8),
		"id": "guest_" + device_id.substr(0, 8),
		"username": "کاربر مهمان",
		"name": "کاربر مهمان",
		"phone": "",
		"coin": 0,
		"score": 0,
		"xp": 0,
		"avatar": 0,
		"is_guest": true
	}
	var config = ConfigFile.new()
	config.set_value("auth", "token", token)
	config.set_value("auth", "user_data", user_data)
	config.set_value("auth", "is_guest", true)
	config.save(SESSION_PATH)
	print("[GameManager] Guest session initiated.")
	user_logged_in.emit(user_data)

func set_session(new_token: String, new_user_data: Dictionary, save_to_disk: bool = true) -> void:
	token = new_token
	user_data = new_user_data
	is_logged_in = true
	is_guest = false
	
	if save_to_disk:
		var config = ConfigFile.new()
		config.set_value("auth", "token", token)
		config.set_value("auth", "user_data", user_data)
		config.set_value("auth", "is_guest", false)
		config.save(SESSION_PATH)
		print("[GameManager] Session saved locally.")
		
	user_logged_in.emit(user_data)

func logout() -> void:
	token = ""
	user_data.clear()
	is_logged_in = false
	is_guest = false
	
	# Delete local session file
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	print("[GameManager] Logged out. Session cleared.")
	
	user_logged_out.emit()

func get_user_id() -> String:
	return str(user_data.get("_id", user_data.get("id", "")))

func get_username() -> String:
	var name_str = str(user_data.get("username", user_data.get("name", ""))).strip_edges()
	if name_str.is_empty():
		return "کاربر مهمان" if is_guest else "Guest"
	return name_str

func has_username() -> bool:
	var uname = get_username().strip_edges()
	if uname.is_empty() or uname == "Guest" or uname == "کاربر مهمان":
		return false
	return true

func get_phone() -> String:
	return str(user_data.get("phone", "")).strip_edges()

func has_phone() -> bool:
	return not get_phone().is_empty()

func get_coins() -> int:
	return int(user_data.get("coin", 0))

func get_score() -> int:
	return int(user_data.get("score", 0))

func get_avatar_id() -> int:
	return int(user_data.get("image", user_data.get("avatar", user_data.get("avatar_id", 0))))

func get_open_game_id() -> String:
	return str(user_data.get("open_game_id", ""))
