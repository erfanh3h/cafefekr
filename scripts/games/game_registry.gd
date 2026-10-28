class_name GameRegistry
extends RefCounted

# Central Game Registry for Cafe Fekr
# Canonical authority for all 20 board configurations, scenes, rules, timing, narratives, and assets.
# 100% parity with Flutter kafehfekr & Python kafehfekrbackend.

const DEFAULT_GAME_TYPE: String = GameTypes.TIC_TAC_TOE

# Preloaded / registered board scenes
const TICTACTOE_SCENE: String = "res://scenes/games/tictactoe/tictactoe_3d.tscn"
const CHESS_SCENE: String = "res://scenes/games/chess/chess_3d.tscn"
const CHECKERS_SCENE: String = "res://scenes/games/checkers/checkers_3d.tscn"
const FOURINROW_SCENE: String = "res://scenes/games/fourinrow/four_in_row_3d.tscn"
const FEKRBEKR_SCENE: String = "res://scenes/games/fekrbekr/fekrbekr_3d.tscn"
const YATZY_SCENE: String = "res://scenes/games/yatzy/yatzy_3d.tscn"
const RPC_SCENE: String = "res://scenes/games/rpc/rpc_3d.tscn"
const BACKGAMMON_SCENE: String = "res://scenes/games/backgammon/backgammon_3d.tscn"
const OTHELLO_SCENE: String = "res://scenes/games/othello/othello_3d.tscn"
const MILL_SCENE: String = "res://scenes/games/mill/mill_3d.tscn"
const DOTBOX_SCENE: String = "res://scenes/games/dotbox/dotbox_3d.tscn"
const MNUMBERS_SCENE: String = "res://scenes/games/mnumbers/mnumbers_3d.tscn"
const BATTLESHIP_SCENE: String = "res://scenes/games/battleship/battleship_3d.tscn"
const SUDOKU_SCENE: String = "res://scenes/games/sudoku/sudoku_3d.tscn"
const TEMP_SCENE: String = "res://scenes/games/temp/temp_game_3d.tscn"

# Top Header scenes (Inheritance-based: BaseTopHeader vs Game-Specific Extensions)
const BASE_TOP_HEADER_SCENE: String = "res://scenes/games/base/base_top_header.tscn"
const CHESS_TOP_HEADER_SCENE: String = "res://scenes/games/chess/chess_top_header.tscn"
const FEKRBEKR_TOP_HEADER_SCENE: String = "res://scenes/games/fekrbekr/fekrbekr_top_header.tscn"
const YATZY_TOP_HEADER_SCENE: String = "res://scenes/games/yatzy/yatzy_top_header.tscn"
const BATTLESHIP_TOP_HEADER_SCENE: String = "res://scenes/games/battleship/battleship_top_header.tscn"

static var _registry: Dictionary = {
	GameTypes.RPC: {
		"id": GameTypes.RPC,
		"name_fa": "سنگ کاغذ قیچی",
		"narrative": "در سکوت انتظار، دست‌ها با دقتی آموخته‌شده به حرکت درآمدند و نمادها سرنوشت را رقم زدند.",
		"board_scene": RPC_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 3,
		"has_round_score": true,
		"is_simultaneous": true,
		"is_cumulative_score": false,
		"turn_time": 7.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/rpc.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.FEKRBEKR: {
		"id": GameTypes.FEKRBEKR,
		"name_fa": "فکر بکر",
		"narrative": "در قلمروی مرموز فکربکر، هر عدد رمزی است از رازهای پنهان که ذهن‌های کنجکاو را به چالش می‌کشد.",
		"board_scene": FEKRBEKR_SCENE,
		"top_header_scene": FEKRBEKR_TOP_HEADER_SCENE,
		"max_rounds": 12,
		"has_round_score": false,
		"is_simultaneous": true,
		"is_cumulative_score": false,
		"turn_time": 60.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/fekrbekr.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.YATZY: {
		"id": GameTypes.YATZY,
		"name_fa": "یاتزی",
		"narrative": "در یاتزی، هر بار انداختن تاس، لحظه‌ای گذرا از شانس است که نجواهای سرنوشت را بازگو می‌کند.",
		"board_scene": YATZY_SCENE,
		"top_header_scene": YATZY_TOP_HEADER_SCENE,
		"max_rounds": 12,
		"has_round_score": true,
		"is_simultaneous": true,
		"is_cumulative_score": true,
		"turn_time": 60.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/yatzy.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.TIC_TAC_TOE: {
		"id": GameTypes.TIC_TAC_TOE,
		"name_fa": "تیک تاک تو",
		"narrative": "تخته به میدان نبردی از تنش خاموش بدل شده بود؛ هر علامت، تقدیری را رقم می‌زند.",
		"board_scene": TICTACTOE_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 5,
		"has_round_score": true,
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
		"narrative": "در تئاتر بزرگ شطرنج، هر حرکت همچون آتشفشانی خاموش و باله‌ای از عقل و اندیشه است.",
		"board_scene": CHESS_SCENE,
		"top_header_scene": CHESS_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
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
		"narrative": "در رقصی بی‌زمان، هر قطعه همچون سربازی است که در میدان نبرد خرد به پیش می‌تازد.",
		"board_scene": CHECKERS_SCENE,
		"top_header_scene": CHESS_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 20.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/checkers.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.FOURINROW: {
		"id": GameTypes.FOURINROW,
		"name_fa": "دوز چهارتایی",
		"narrative": "در این بازی، هر دیسکی که به شبکه انداخته می‌شود، گامی است در راستای خط پیروزی.",
		"board_scene": FOURINROW_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 15.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/fourinrow.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.BACKGAMMON: {
		"id": GameTypes.BACKGAMMON,
		"name_fa": "تخته نرد",
		"narrative": "در سحرگاه باستانی تخته نرد، تاس‌ها در رقصی بی‌پایان به گردش درمی‌آیند.",
		"board_scene": BACKGAMMON_SCENE,
		"top_header_scene": CHESS_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 30.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 4,
		"icon": "res://assets/images/games/backgammon.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.OTHELLO: {
		"id": GameTypes.OTHELLO,
		"name_fa": "اتللو",
		"narrative": "در بازی اتللو، هر مهره مانند سربازی است که در میدان نبرد ذهن‌ها جبهه را دگرگون می‌سازد.",
		"board_scene": OTHELLO_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
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
		"narrative": "در میان شبکه پیچیده‌ی نُه‌مرد موریس، هر قرارگیری نغمه‌ای از تفکر است.",
		"board_scene": MILL_SCENE,
		"top_header_scene": CHESS_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 15.0,
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
		"narrative": "در بازی نقطه خط، تصاحب هر مربع با تفکر استراتژیک برنده را مشخص می‌کند.",
		"board_scene": DOTBOX_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 15.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/dotbox.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.PENTAGO: {
		"id": GameTypes.PENTAGO,
		"name_fa": "پنتاگو",
		"narrative": "در دنیای پنتاگو، هر مهره‌ داستانی را روایت می‌کند و هر چرخش، تقدیری نو رقم می‌زند.",
		"board_scene": TEMP_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 25.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/pentago.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.YINSH: {
		"id": GameTypes.YINSH,
		"name_fa": "یینش",
		"narrative": "در دنیای یینش، هر حلقه فرمانده‌ای خاموش است که نشانگرها را به خط می‌کند.",
		"board_scene": TEMP_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 30.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/yinsh.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.BATTLESHIP: {
		"id": GameTypes.BATTLESHIP,
		"name_fa": "نبرد کشتی",
		"narrative": "در پهنه وسیع دریا، کشتی جنگی به‌سان نبردی از خرد و استراتژی در مه پنهان است.",
		"board_scene": BATTLESHIP_SCENE,
		"top_header_scene": BATTLESHIP_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 12.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/battleship.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.BOXFOUR: {
		"id": GameTypes.BOXFOUR,
		"name_fa": "چهارطرفه",
		"narrative": "در یک شبکه‌ی رنگین ۵x۵، اعداد به رقص در می‌آیند و رنگ‌ها شکوه می‌آفرینند.",
		"board_scene": TEMP_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 12.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/boxfour.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.SUDOKU: {
		"id": GameTypes.SUDOKU,
		"name_fa": "سودوکو",
		"narrative": "در رقص ظریف سودوکو، هر عدد گامی به‌سوی تعادل است و هر خانه‌ی خالی رازی نهفته.",
		"board_scene": SUDOKU_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"is_simultaneous": true,
		"turn_time": 1200.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/sudoku.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.MNUMBERS: {
		"id": GameTypes.MNUMBERS,
		"name_fa": "کشف اعداد",
		"narrative": "در ظرافت خاموش بازی، هر برگشت کارت همچون ضربه‌ای از قلم در پیوند اعداد است.",
		"board_scene": MNUMBERS_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 7.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/mnumbers.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.MSWEEPER: {
		"id": GameTypes.MSWEEPER,
		"name_fa": "مین یاب",
		"narrative": "در هزارتوی پیکسل‌ها، هر کلیک گامی محتاطانه به سوی ناشناخته‌هاست.",
		"board_scene": TEMP_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"is_simultaneous": true,
		"turn_time": 600.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/msweeper.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.LUDO: {
		"id": GameTypes.LUDO,
		"name_fa": "منچ",
		"narrative": "هیجان پرتاب تاس و تعقیب و گریز مهره‌ها در بازی خاطره‌انگیز منچ.",
		"board_scene": TEMP_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 25.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/ludo.jpg",
		"min_players": 2,
		"max_players": 4,
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
		"narrative": "",
		"board_scene": TEMP_SCENE,
		"max_rounds": 3,
		"has_round_score": true,
		"turn_time": 15.0,
		"icon": "res://assets/images/games/%s.jpg" % normalized.to_lower(),
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	}

static func get_board_packed_scene(game_type: String) -> PackedScene:
	var info = get_game_info(game_type)
	var scene_path: String = str(info.get("board_scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	# Default fallback to Temp 3D board
	if ResourceLoader.exists(TEMP_SCENE):
		return load(TEMP_SCENE) as PackedScene
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

static func get_narrative(game_type: String) -> String:
	var info = get_game_info(game_type)
	return info.get("narrative", "")

static func get_max_rounds(game_type: String) -> int:
	var info = get_game_info(game_type)
	return int(info.get("max_rounds", 3))

static func has_round_score(game_type: String = "") -> bool:
	var info = get_game_info(game_type)
	if info.has("has_round_score"):
		return bool(info.get("has_round_score", false))
	return int(info.get("max_rounds", 1)) > 1

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

static func is_simultaneous(game_type: String = "") -> bool:
	var info = get_game_info(game_type)
	return bool(info.get("is_simultaneous", false))

static func is_cumulative_score(game_type: String = "") -> bool:
	var info = get_game_info(game_type)
	return bool(info.get("is_cumulative_score", false))
