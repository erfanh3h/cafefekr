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
const MSWEEPER_SCENE: String = "res://scenes/games/msweeper/msweeper_3d.tscn"
const BOXFOUR_SCENE: String = "res://scenes/games/boxfour/box_four_3d.tscn"
const YINSH_SCENE: String = "res://scenes/games/yinsh/yinsh_3d.tscn"
const PENTAGO_SCENE: String = "res://scenes/games/pentago/pentago_3d.tscn"
const LUDO_SCENE: String = "res://scenes/games/ludo/ludo_3d.tscn"
const LUDO_TOP_HEADER_SCENE: String = "res://scenes/games/ludo/ludo_top_header.tscn"
const RISK_SCENE: String = "res://scenes/games/risk/risk_3d.tscn"
const RISK_TOP_HEADER_SCENE: String = "res://scenes/games/risk/risk_top_header.tscn"
const QUIZ_SCENE: String = "res://scenes/games/quiz/quiz_3d.tscn"
const QUIZ_TOP_HEADER_SCENE: String = "res://scenes/games/quiz/quiz_top_header.tscn"
const QUORIDOR_SCENE: String = "res://scenes/games/quoridor/quoridor_3d.tscn"
const QUORIDOR_TOP_HEADER_SCENE: String = "res://scenes/games/quoridor/quoridor_top_header.tscn"
const COUP_SCENE: String = "res://scenes/games/coup/coup_3d.tscn"
const COUP_TOP_HEADER_SCENE: String = "res://scenes/games/coup/coup_top_header.tscn"
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
		"max_missed_turns": 2,
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
		"max_missed_turns": 2,
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
		"max_missed_turns": 2,
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
		"max_missed_turns": 2,
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
		"board_scene": PENTAGO_SCENE,
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
		"board_scene": YINSH_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
		"turn_time": 30.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/yinsh.jpg",
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	},
	GameTypes.QUORIDOR: {
		"id": GameTypes.QUORIDOR,
		"name_fa": "کوریدور",
		"narrative": "در هزارتوی پررمز و راز کوریدور، هر دیوار دژی است در برابر حریف و هر گام، جهشی به سوی خط پایان.",
		"board_scene": QUORIDOR_SCENE,
		"top_header_scene": QUORIDOR_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 30.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 2,
		"icon": "res://assets/images/games/quoridor.jpg",
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
		"board_scene": BOXFOUR_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
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
		"board_scene": MSWEEPER_SCENE,
		"top_header_scene": BASE_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_cumulative_score": true,
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
		"board_scene": LUDO_SCENE,
		"top_header_scene": LUDO_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 25.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/ludo.png",
		"min_players": 2,
		"max_players": 4,
		"is_3d": true
	},
	GameTypes.RISK: {
		"id": GameTypes.RISK,
		"name_fa": "ریسک استرایک",
		"narrative": "در تالار فرماندهی، شش قاره چشم‌به‌راه تصرف‌اند؛ جایی که کارت‌های استراتژی و تاس‌های نبرد سرنوشت امپراتوری‌ها را رقم می‌زنند.",
		"board_scene": RISK_SCENE,
		"top_header_scene": RISK_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 30.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/risk.jpg",
		"min_players": 2,
		"max_players": 4,
		"is_3d": true
	},
	GameTypes.UNO: {
		"id": GameTypes.UNO,
		"name_fa": "اونو",
		"narrative": "رقص رنگ‌ها و کارت‌های غافلگیرکننده در بازی پرهیجان اونو؛ جایی که یک تغییر رنگ یا کارت +۴ در لحظه آخر معادله را دگرگون می‌سازد!",
		"board_scene": "res://scenes/games/uno/uno_3d.tscn",
		"top_header_scene": "res://scenes/games/uno/uno_top_header.tscn",
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 20.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 3,
		"icon": "res://assets/images/games/uno.png",
		"min_players": 2,
		"max_players": 4,
		"is_3d": true
	},
	GameTypes.QUIZ: {
		"id": GameTypes.QUIZ,
		"name_fa": "کوییز",
		"narrative": "مسابقه مهیج اطلاعات عمومی در کافه فکر؛ ۱۰ سوال با پاسخگویی هم‌زمان. پاسخ درست ۱+، نادرست ۱- و بی‌پاسخ ۰ امتیاز!",
		"board_scene": QUIZ_SCENE,
		"top_header_scene": QUIZ_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": true,
		"is_simultaneous": true,
		"turn_time": 15.0,
		"has_missed_turns_limit": false,
		"icon": "res://assets/images/games/quiz.png",
		"min_players": 2,
		"max_players": 4,
		"is_3d": true
	},
	GameTypes.COUP: {
		"id": GameTypes.COUP,
		"name_fa": "کودتا",
		"narrative": "در تالار پررمز و راز قدرت، جایی که هر کارت نفوذی پنهان است؛ بلوف بزنید، مچ حریفان را بگیرید و آخرین نفوذی باشید که در دیوان باقی می‌ماند.",
		"board_scene": COUP_SCENE,
		"top_header_scene": COUP_TOP_HEADER_SCENE,
		"max_rounds": 1,
		"has_round_score": false,
		"turn_time": 25.0,
		"has_missed_turns_limit": true,
		"max_missed_turns": 3,
		"icon": "res://assets/images/games/coup.jpg",
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

static func normalize_type(raw_type: Variant) -> String:
	var s_type = str(raw_type).strip_edges() if raw_type != null else ""
	if s_type.is_empty():
		return DEFAULT_GAME_TYPE
	var clean = s_type.to_lower().replace("_", "").replace("-", "")
	for key in _registry.keys():
		var k_clean = str(key).to_lower().replace("_", "").replace("-", "")
		if clean == k_clean:
			return str(key)
	return s_type

static func get_game_info(game_type: Variant = "") -> Dictionary:
	var normalized = normalize_type(game_type)
	if _registry.has(normalized) and typeof(_registry[normalized]) == TYPE_DICTIONARY:
		return _registry[normalized]
	# Fallback info for unregistered games
	return {
		"id": normalized,
		"name_fa": "",
		"narrative": "",
		"board_scene": TEMP_SCENE,
		"max_rounds": 3,
		"has_round_score": true,
		"turn_time": 15.0,
		"is_simultaneous": false,
		"icon": "res://assets/images/games/%s.jpg" % normalized.to_lower(),
		"min_players": 2,
		"max_players": 2,
		"is_3d": true
	}

static func get_board_packed_scene(game_type: Variant = "") -> PackedScene:
	var info = get_game_info(game_type)
	var scene_path: String = str(info.get("board_scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	# Default fallback to Temp 3D board
	if ResourceLoader.exists(TEMP_SCENE):
		return load(TEMP_SCENE) as PackedScene
	return load(TICTACTOE_SCENE) as PackedScene

static func get_top_header_packed_scene(game_type: Variant = "") -> PackedScene:
	var info = get_game_info(game_type)
	var scene_path: String = str(info.get("top_header_scene", ""))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		return load(scene_path) as PackedScene
	# Default fallback to BaseTopHeader
	return load(BASE_TOP_HEADER_SCENE) as PackedScene

static func get_display_name_fa(game_type: Variant = "") -> String:
	var normalized = normalize_type(game_type)
	if _registry.has(normalized) and typeof(_registry[normalized]) == TYPE_DICTIONARY:
		return _registry[normalized].get("name_fa", str(normalized))
	return str(normalized)

static func get_narrative(game_type: Variant = "") -> String:
	var info = get_game_info(game_type)
	return info.get("narrative", "")

static func get_max_rounds(game_type: Variant = "") -> int:
	var info = get_game_info(game_type)
	return int(info.get("max_rounds", 3))

static func has_round_score(game_type: Variant = "") -> bool:
	var info = get_game_info(game_type)
	if info.has("has_round_score"):
		return bool(info.get("has_round_score", false))
	return int(info.get("max_rounds", 1)) > 1

static func get_turn_time(game_type: Variant = "") -> float:
	var info = get_game_info(game_type)
	return float(info.get("turn_time", 10.0))

static func has_missed_turns_limit(game_type: Variant = "") -> bool:
	var info = get_game_info(game_type)
	return bool(info.get("has_missed_turns_limit", false))

static func get_max_missed_turns(game_type: Variant = "") -> int:
	var info = get_game_info(game_type)
	if not has_missed_turns_limit(game_type):
		return 0
	return int(info.get("max_missed_turns", 2))

static func is_simultaneous(game_type: Variant = "") -> bool:
	var info = get_game_info(game_type)
	if typeof(info) == TYPE_DICTIONARY:
		return bool(info.get("is_simultaneous", false))
	return false

static func is_cumulative_score(game_type: Variant = "") -> bool:
	var info = get_game_info(game_type)
	if typeof(info) == TYPE_DICTIONARY:
		return bool(info.get("is_cumulative_score", false))
	return false

static func get_difficulty(game_type: Variant = "") -> String:
	match normalize_type(game_type):
		GameTypes.TIC_TAC_TOE, GameTypes.RPC, GameTypes.DOTBOX, GameTypes.LUDO, GameTypes.MNUMBERS, GameTypes.UNO:
			return "easy"
		GameTypes.FEKRBEKR, GameTypes.PENTAGO, GameTypes.MSWEEPER, GameTypes.BATTLESHIP, \
		GameTypes.FOURINROW, GameTypes.BOXFOUR, GameTypes.SUDOKU, GameTypes.YATZY, GameTypes.QUIZ, GameTypes.COUP:
			return "normal"
		GameTypes.CHESS, GameTypes.CHECKERS, GameTypes.OTHELLO, GameTypes.BACKGAMMON, \
		GameTypes.YINSH, GameTypes.MILL, GameTypes.RISK, GameTypes.QUORIDOR:
			return "hard"
		_:
			return "normal"

static func get_difficulty_name_fa(game_type: Variant = "") -> String:
	match get_difficulty(game_type):
		"easy": return "آسان"
		"normal": return "متوسط"
		"hard": return "سخت"
		_: return "متوسط"

static func get_classic_rank_xp(game_type: Variant = "", is_win: bool = false, is_draw: bool = false) -> int:
	var diff = get_difficulty(game_type)
	if diff == "easy":
		return 8 if is_win else (4 if is_draw else 2)
	elif diff == "normal":
		return 14 if is_win else (7 if is_draw else 3)
	else:
		return 20 if is_win else (10 if is_draw else 5)

static func get_lobby_xp(game_type: Variant = "", is_win: bool = false, is_draw: bool = false) -> int:
	var diff = get_difficulty(game_type)
	if diff == "easy":
		return 5 if is_win else (2 if is_draw else 1)
	elif diff == "normal":
		return 9 if is_win else (4 if is_draw else 2)
	else:
		return 14 if is_win else (7 if is_draw else 3)

static func get_multiplayer_rank_games() -> Array[String]:
	return [GameTypes.LUDO, GameTypes.RISK, GameTypes.UNO, GameTypes.QUIZ, GameTypes.COUP]

static func is_multiplayer_game(game_type: Variant = "") -> bool:
	var norm = normalize_type(game_type)
	return norm in [GameTypes.LUDO, GameTypes.RISK, GameTypes.UNO, GameTypes.QUIZ, GameTypes.COUP]

static func is_multiplayer_rank_supported(game_type: Variant = "") -> bool:
	var norm = normalize_type(game_type)
	return norm in [GameTypes.LUDO, GameTypes.RISK, GameTypes.UNO, GameTypes.QUIZ, GameTypes.COUP]

static func get_multi_rank_xp(_game_type: Variant = "", is_rank1: bool = false, is_rank2: bool = false) -> int:
	if is_rank1:
		return 50
	elif is_rank2:
		return 30
	return 10
