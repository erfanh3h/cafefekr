extends Node

const GameRegistry = preload("res://scripts/games/game_registry.gd")

# GameManager Autoload (Singleton)
signal user_logged_in(user_data: Dictionary)
signal user_logged_out()
signal user_data_updated(user_data: Dictionary)
signal game_started(game_id: String, game_data: Dictionary)
signal game_finished(winner_id: Variant)

const SETTINGS_PATH: String = "user://settings.cfg"
const SESSION_PATH: String = "user://session.cfg"

var device_id: String = ""
var token: String = ""
var user_data: Dictionary = {}
var is_logged_in: bool = false
var is_guest: bool = false

# Server Configuration & Versioning
var server_config: Dictionary = {}
var is_queue_open: bool = true
var is_force_update_required: bool = false
var allowed_version: String = ""
var latest_version: String = ""

func get_app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "2.0.0"))

func is_version_ok(current_version: String, allowed_ver: String) -> bool:
	if allowed_ver.is_empty():
		return true
	var cur_parts = current_version.split(".")
	var allowed_parts = allowed_ver.split(".")
	var cur_major = int(cur_parts[0]) if cur_parts.size() > 0 else 0
	var cur_minor = int(cur_parts[1]) if cur_parts.size() > 1 else 0
	var cur_patch = int(cur_parts[2]) if cur_parts.size() > 2 else 0
	var all_major = int(allowed_parts[0]) if allowed_parts.size() > 0 else 0
	var all_minor = int(allowed_parts[1]) if allowed_parts.size() > 1 else 0
	var all_patch = int(allowed_parts[2]) if allowed_parts.size() > 2 else 0
	if all_major > cur_major:
		return false
	if all_major == cur_major and all_minor > cur_minor:
		return false
	if all_major == cur_major and all_minor == cur_minor and all_patch > cur_patch:
		return false
	return true

# Current Match State
var active_game_id: String = ""
var is_game_active: bool = false
var active_pre_game_id: String = ""
var is_in_pre_game: bool = false
var current_match_mode: String = ""
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
	if changed:
		_save_session_config()
		print("[GameManager] Cleared open_game_id from cached session.")

func set_active_game(game_id: String) -> void:
	active_game_id = game_id
	if not game_id.is_empty():
		user_data["open_game_id"] = game_id
		user_data["game_id"] = game_id
		# Crucial: once match is active, pre-game draft is 100% finished!
		active_pre_game_id = ""
		is_in_pre_game = false
		if user_data.has("open_pre_game_id"):
			user_data.erase("open_pre_game_id")
	else:
		is_game_active = false
		clear_open_game_id()
	_save_session_config()
	print("[GameManager] Set active match game_id: %s" % game_id)

func set_active_pre_game(pre_id: String) -> void:
	# Only allow setting active pre-game if NOT currently in an active game!
	if is_game_active or not active_game_id.is_empty() or not get_open_game_id().is_empty():
		print("[GameManager] Ignored set_active_pre_game because match is already active!")
		return
	active_pre_game_id = pre_id
	is_in_pre_game = not pre_id.is_empty()
	if is_in_pre_game:
		user_data["open_pre_game_id"] = pre_id
	else:
		user_data.erase("open_pre_game_id")
	_save_session_config()
	print("[GameManager] Set active pre-game draft: %s" % pre_id)

func get_open_pre_game_id() -> String:
	# If a match is active or open_game_id is set, pre_game_id is invalid!
	if is_game_active or not active_game_id.is_empty() or not get_open_game_id().is_empty():
		return ""
	return str(user_data.get("open_pre_game_id", active_pre_game_id))

func clear_open_pre_game_id() -> void:
	active_pre_game_id = ""
	is_in_pre_game = false
	if user_data.has("open_pre_game_id"):
		user_data.erase("open_pre_game_id")
	_save_session_config()
	print("[GameManager] Cleared open_pre_game_id from cached session.")

func _save_session_config() -> void:
	if not token.is_empty():
		var config = ConfigFile.new()
		config.set_value("auth", "token", token)
		config.set_value("auth", "user_data", user_data)
		config.set_value("auth", "is_guest", is_guest)
		config.save(SESSION_PATH)

func set_match_gamers(gamers_list: Array) -> void:
	if gamers_list.is_empty():
		return
	var existing_ids: Dictionary = {}
	for ep in match_players:
		if typeof(ep) == TYPE_DICTIONARY:
			var e_uid = str(ep.get("user_id", ""))
			var e_gid = int(ep.get("gamer_id", 0))
			if not e_uid.is_empty() and e_gid > 0:
				existing_ids[e_uid] = e_gid
	match_players = gamers_list.duplicate(true)
	for mp in match_players:
		if typeof(mp) == TYPE_DICTIONARY:
			var m_uid = str(mp.get("user_id", ""))
			if int(mp.get("gamer_id", 0)) <= 0 and existing_ids.has(m_uid):
				mp["gamer_id"] = existing_ids[m_uid]
				mp["team_id"] = existing_ids[m_uid]
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_quit_on_go_back(false)
	_load_or_create_device_id()
	_load_saved_session_on_boot()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Completely disable Android hardware/gesture back button
		return

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_BACK:
		get_viewport().set_input_as_handled()

func _load_saved_session_on_boot() -> void:
	var saved_token = load_saved_token()
	if not saved_token.is_empty():
		token = saved_token
		var saved_data = load_saved_user_data()
		if not saved_data.is_empty():
			user_data = saved_data
			is_logged_in = true
			print("[GameManager] Boot: Restored local session for '%s' (Level: %d, XP: %d, Score: %d, Coins: %d)" % [
				get_username(), get_user_level(), get_xp(), get_score(), get_coins()
			])
			user_logged_in.emit(user_data)

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
		var saved_guest = bool(config.get_value("auth", "is_guest", false))
		var saved_tok = str(config.get_value("auth", "token", ""))
		if saved_guest or saved_tok.begins_with("guest_"):
			is_guest = false
			return ""
		is_guest = false
		return saved_tok
	return ""

func load_saved_user_data() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SESSION_PATH)
	if err == OK:
		var saved_guest = bool(config.get_value("auth", "is_guest", false))
		var saved_tok = str(config.get_value("auth", "token", ""))
		if saved_guest or saved_tok.begins_with("guest_"):
			is_guest = false
			return {}
		is_guest = false
		if config.has_section_key("auth", "user_data"):
			var udata = config.get_value("auth", "user_data", {})
			if bool(udata.get("is_guest", false)):
				return {}
			var open_gid = str(udata.get("open_game_id", udata.get("game_id", "")))
			if not open_gid.is_empty():
				udata.erase("open_pre_game_id")
			return udata
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
	
	# If an ongoing game exists, pick & ban draft is definitely finished!
	var open_gid = str(user_data.get("open_game_id", user_data.get("game_id", "")))
	if not open_gid.is_empty():
		active_game_id = open_gid
		is_game_active = true
		active_pre_game_id = ""
		is_in_pre_game = false
		user_data["open_pre_game_id"] = ""
	
	if save_to_disk:
		_save_session_config()
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

func update_username(new_name: String) -> void:
	user_data["username"] = new_name
	user_data["name"] = new_name
	_save_session_config()
	if has_signal("user_data_updated"):
		user_data_updated.emit(user_data)

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

func get_xp() -> int:
	var val = user_data.get("xp", user_data.get("user_xp", 0))
	return int(float(val)) if val != null else 0

static func to_fa_num(val: Variant) -> String:
	var s = str(val)
	var fa_digits = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for i in range(s.length()):
		var code = s.unicode_at(i)
		if code >= 48 and code <= 57:
			out += fa_digits[code - 48]
		else:
			out += s[i]
	return out

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var cur_xp = int(user_data.get("xp", 0))
	user_data["xp"] = cur_xp + amount
	if not token.is_empty():
		var config = ConfigFile.new()
		config.set_value("auth", "token", token)
		config.set_value("auth", "user_data", user_data)
		config.set_value("auth", "is_guest", is_guest)
		config.save(SESSION_PATH)
	print("[GameManager] Added %d XP. New total: %d" % [amount, user_data["xp"]])
	user_data_updated.emit(user_data)
	user_logged_in.emit(user_data)

func add_coins(amount: int) -> void:
	if amount == 0:
		return
	var cur_coin = int(user_data.get("coin", 0))
	user_data["coin"] = max(0, cur_coin + amount)
	_save_session_config()
	print("[GameManager] Added %d Coins. New total: %d" % [amount, user_data["coin"]])
	user_data_updated.emit(user_data)
	user_logged_in.emit(user_data)

func apply_ranked_rewards(score_delta: int, xp_delta: int, coin_delta: int) -> void:
	if score_delta != 0:
		user_data["score"] = max(0, int(user_data.get("score", 0)) + score_delta)
	if xp_delta > 0:
		user_data["xp"] = int(user_data.get("xp", 0)) + xp_delta
	if coin_delta != 0:
		user_data["coin"] = max(0, int(user_data.get("coin", 0)) + coin_delta)
	_save_session_config()
	print("[GameManager] Applied ranked rewards: score %+d, xp +%d, coin %+d" % [score_delta, xp_delta, coin_delta])
	user_data_updated.emit(user_data)
	user_logged_in.emit(user_data)

# ==============================================================================
# LEVEL & XP PROGRESSION SYSTEM
# ==============================================================================
# Modern progressive curve calibrated to Cafe Fekr match rewards (15-50 XP/match):
# Total cumulative XP needed to reach Level L (L >= 1):
#   TotalXP(L) = 20 * (L^2 - 1)
# Step XP needed to go from Level L to Level L+1:
#   DeltaXP(L) = 20 + 40 * L  (Level 1->2: 60 XP, Level 2->3: 100 XP, etc.)
# Direct O(1) closed-form calculation:
#   Level(XP) = floor(sqrt(XP / 20.0 + 1.0))
# ==============================================================================

static func total_exp_to_level(level: int) -> int:
	if level <= 1:
		return 0
	return 20 * (level * level - 1)

static func calculate_level(xp: int) -> int:
	if xp <= 0:
		return 1
	return int(floor(sqrt(float(xp) / 20.0 + 1.0)))

static func calculate_exp_percent(xp: int) -> float:
	if xp <= 0:
		return 0.0
	var level = calculate_level(xp)
	var current_level_exp = total_exp_to_level(level)
	var next_level_exp = total_exp_to_level(level + 1)
	var needed = next_level_exp - current_level_exp
	if needed <= 0:
		return 1.0
	var exp_in_level = xp - current_level_exp
	return clampf(float(exp_in_level) / float(needed), 0.0, 1.0)

static func get_level_info(xp: int) -> Dictionary:
	var lvl = calculate_level(xp)
	var cur_base = total_exp_to_level(lvl)
	var next_base = total_exp_to_level(lvl + 1)
	var needed = next_base - cur_base
	var in_level = max(0, xp - cur_base)
	var percent = clampf(float(in_level) / float(needed), 0.0, 1.0) if needed > 0 else 1.0
	return {
		"level": lvl,
		"current_level_exp": cur_base,
		"next_level_exp": next_base,
		"exp_in_level": in_level,
		"exp_needed": needed,
		"current_xp": xp,
		"target_xp": next_base,
		"remaining_xp": max(0, next_base - xp),
		"progress": percent,
		"percent_int": int(round(percent * 100.0))
	}

func get_user_level() -> int:
	return calculate_level(get_xp())

func get_user_exp_percent() -> float:
	return calculate_exp_percent(get_xp())

# ==============================================================================
# RANKED MODE ACCESS CONTROL (Level 3 / 160 XP Requirement)
# ==============================================================================
const MIN_RANKED_LEVEL: int = 3
const MIN_RANKED_XP: int = 160

func is_ranked_unlocked() -> bool:
	return get_xp() >= MIN_RANKED_XP

func get_ranked_unlock_progress() -> Dictionary:
	var cur_xp = get_xp()
	var needed = MIN_RANKED_XP
	var pct = clampf(float(cur_xp) / float(needed), 0.0, 1.0) if needed > 0 else 1.0
	return {
		"unlocked": cur_xp >= needed,
		"current_xp": cur_xp,
		"current_level": calculate_level(cur_xp),
		"required_xp": needed,
		"target_xp": needed,
		"required_level": MIN_RANKED_LEVEL,
		"remaining_xp": max(0, needed - cur_xp),
		"progress": pct,
		"percent_int": int(round(pct * 100.0))
	}

func get_open_game_id() -> String:
	if not active_game_id.is_empty():
		return active_game_id
	return str(user_data.get("open_game_id", user_data.get("game_id", "")))
