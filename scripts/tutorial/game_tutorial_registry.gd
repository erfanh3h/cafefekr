class_name GameTutorialRegistry
extends RefCounted

## Central registry mapping GameTypes -> interactive Library tutorial lessons.
## Add new games here one by one as their `Tutorial<Game>3D` scene and
## `<game>_lesson.gd` are implemented.

const _LESSONS: Dictionary = {
	GameTypes.TIC_TAC_TOE: "res://scripts/tutorial/lessons/tictactoe_lesson.gd",
	GameTypes.CHESS: "res://scripts/tutorial/lessons/chess_lesson.gd",
	GameTypes.CHECKERS: "res://scripts/tutorial/lessons/checkers_lesson.gd",
	GameTypes.FOURINROW: "res://scripts/tutorial/lessons/fourinrow_lesson.gd",
	GameTypes.OTHELLO: "res://scripts/tutorial/lessons/othello_lesson.gd",
	GameTypes.BACKGAMMON: "res://scripts/tutorial/lessons/backgammon_lesson.gd",
	GameTypes.MILL: "res://scripts/tutorial/lessons/mill_lesson.gd",
	GameTypes.DOTBOX: "res://scripts/tutorial/lessons/dotbox_lesson.gd",
	GameTypes.PENTAGO: "res://scripts/tutorial/lessons/pentago_lesson.gd",
	GameTypes.LUDO: "res://scripts/tutorial/lessons/ludo_lesson.gd",
	GameTypes.YATZY: "res://scripts/tutorial/lessons/yatzy_lesson.gd",
	GameTypes.BATTLESHIP: "res://scripts/tutorial/lessons/battleship_lesson.gd",
	GameTypes.QUIZ: "res://scripts/tutorial/lessons/quiz_lesson.gd",
	GameTypes.UNO: "res://scripts/tutorial/lessons/uno_lesson.gd",
	GameTypes.RISK: "res://scripts/tutorial/lessons/risk_lesson.gd",
	GameTypes.COUP: "res://scripts/tutorial/lessons/coup_lesson.gd",
	GameTypes.MONOPOLY: "res://scripts/tutorial/lessons/monopoly_lesson.gd",
	GameTypes.YINSH: "res://scripts/tutorial/lessons/yinsh_lesson.gd",
}


static func has_interactive_tutorial(game_type: String) -> bool:
	var norm: String = GameRegistry.normalize_type(game_type)
	if not _LESSONS.has(norm):
		return false
	return ResourceLoader.exists(str(_LESSONS[norm]))


static func create_lesson(game_type: String) -> GameTutorialLesson:
	var norm: String = GameRegistry.normalize_type(game_type)
	if not _LESSONS.has(norm):
		return null
	var path: String = str(_LESSONS[norm])
	if not ResourceLoader.exists(path):
		return null
	var script_res: Script = load(path) as Script
	if script_res == null:
		return null
	var instance: Variant = script_res.new()
	if instance is GameTutorialLesson:
		return instance as GameTutorialLesson
	return null


static func get_supported_game_types() -> Array[String]:
	var out: Array[String] = []
	for k in _LESSONS.keys():
		out.append(str(k))
	return out
