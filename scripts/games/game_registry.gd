class_name GameRegistry
extends RefCounted

# Central Game Registry for Cafe Fekr
# Maps game types to their metadata, display names, 3D board scenes, and rules.
# Provides unified lookups for both Lobby, Ranked, and Offline matches.

const DEFAULT_GAME_TYPE: String = GameTypes.TIC_TAC_TOE

# Preloaded / registered board scenes
const TICTACTOE_SCENE: String = "res://scenes/games/tictactoe/tictactoe_3d.tscn"
const CHESS_SCENE: String = "res://scenes/games/chess/chess_3d.tscn"
const FEKRBEKR_SCENE: String = "res://scenes/games/fekrbekr/fekrbekr_3d.tscn"

# Top Header scenes (Inheritance-based: BaseTopHeader vs Game-Specific Extensions)
const BASE_TOP_HEADER_SCENE: String = "res://scenes/games/base/base_top_header.tscn"
const CHESS_TOP_HEADER_SCENE: String = "res://scenes/games/chess/chess_top_header.tscn"
const FEKRBEKR_TOP_HEADER_SCENE: String = "res://scenes/games/fekrbekr/fekrbekr_top_header.tscn"

static var _registry: Dictionary = {
	GameTypes.FEKRBEKR: {
		"id": GameTypes.FEKRBEKR,
		"name_fa": "فکر بکر",
		"board_scene": FEKRBEKR_SCENE,
		"top_header_scene": FEKRBEKR_TOP_HEADER_SCENE,
		"max_rounds": 12,
		"turn_time": 60.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/fekrbekr.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.TIC_TAC_TOE: {
		"id": GameTypes.TIC_TAC_TOE,
		"name_fa": "تیک تاک تو",
		"board_scene": TICTACTOE_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 5,
		"turn_time": 10.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/tictactoe.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.CHESS: {
		"id": GameTypes.CHESS,
		"name_fa": "شطرنج",
		"board_scene": CHESS_SCENE,
		"top_header_scene": CHESS_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"turn_time": 20.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/chess.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.CHECKERS: {
		"id": GameTypes.CHECKERS,
		"name_fa": "چکرز",
		"board_scene": "",
		"max_rounds": 3,
		"turn_time": 20.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/checkers.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.BACKGAMMON: {
		"id": GameTypes.BACKGAMMON,
		"name_fa": "تخته نرد",
		"board_scene": "",
		"max_rounds": 3,
		"turn_time": 25.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/backgammon.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.FOURINROW: {
		"id": GameTypes.FOURINROW,
		"name_fa": "دوز چهارتایی",
		"board_scene": "",
		"max_rounds": 3,
		"turn_time": 15.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/fourinrow.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.OTHELLO: {
		"id": GameTypes.OTHELLO,
		"name_fa": "اتللو",
		"board_scene": "",
		"max_rounds": 1,
		"turn_time": 20.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/othello.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.MILL: {
		"id": GameTypes.MILL,
		"name_fa": "دوز نه تایی",
		"board_scene": "",
		"max_rounds": 3,
		"turn_time": 20.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/mill.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.DOTBOX: {
		"id": GameTypes.DOTBOX,
		"name_fa": "نقطه خط",
		"board_scene": "",
		"max_rounds": 1,
		"turn_time": 15.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/dotbox.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	}
}

# Registers a new game board scene dynamically at runtime or initialization
static func register_game(game_type: String, info: Dictionary) -> void:
	var norm = normalize_type(game_type)
	if _registry.has(norm):
		for k in info.keys():
			_registry[norm][k] = info[k]
	else:
		info["id"] = norm
		if not info.has("name_fa"):
			info["name_fa"] = GameTypes.get_display_name_fa(norm)
		_registry[norm] = info

static func normalize_type(raw_type: String) -> String:
	if raw_type.is_empty():
		return DEFAULT_GAME_TYPE
	var clean = raw_type.to_lower().replace("_", "").replace("-", "").strip_edges()
	for key in _registry.keys():
		var k_clean = key.to_lower().replace("_", "").replace("-", "")
		if clean == k_clean:
			return key
	return raw_type

static func get_game_info(game_type: String) -> Dictionary:
	var normalized = normalize_type(game_type)
	if _registry.has(normalized):
		return _registry[normalized]
	# Fallback info for unregistered games
	return {
		"id": normalized,
		"name_fa": GameTypes.get_display_name_fa(normalized),
		"board_scene": TICTACTOE_SCENE,
		"max_rounds": 3,
		"turn_time": 15.0,
		"icon": "",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	}

static func get_board_packed_scene(game_type: String) -> PackedScene:
	var info = get_game_info(game_type)
	var scene_path: String = str(info.get("board_scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	# Default fallback to TicTacToe 3D board
	return load(TICTACTOE_SCENE) as PackedScene

static func get_top_header_packed_scene(game_type: String) -> PackedScene:
	var info = get_game_info(game_type)
	var scene_path: String = str(info.get("top_header_scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	# Default fallback to BaseTopHeader
	return load(BASE_TOP_HEADER_SCENE) as PackedScene

static func get_display_name_fa(game_type: String) -> String:
	var info = get_game_info(game_type)
	return info.get("name_fa", GameTypes.get_display_name_fa(game_type))

static func get_max_rounds(game_type: String) -> int:
	var info = get_game_info(game_type)
	return int(info.get("max_rounds", 3))

static func get_turn_time(game_type: String) -> float:
	var info = get_game_info(game_type)
	return float(info.get("turn_time", 10.0))

static func has_missed_turns_limit(game_type: String = "") -> bool:
	var info = get_game_info(game_type)
	return bool(info.get("has_missed_turns_limit", false))

static func get_max_missed_turns(game_type: String = "") -> int:
	var info = get_game_info(game_type)
	if not has_missed_turns_limit(game_type):
		return 0
	return int(info.get("max_missed_turns", 4))
