class_name GameTutorialLesson
extends RefCounted

## Abstract base class for per-game interactive Library tutorials.
## Each game implements a lightweight, self-contained subclass under
## `res://scripts/tutorial/lessons/<game>_lesson.gd` and registers it in
## `GameTutorialRegistry`.
##
## Lifecycle:
##   1. TutorialCoordinator instantiates the lesson & spawns `get_tutorial_board_scene()`.
##   2. `on_board_ready(board, coordinator)` wires board-specific signals.
##   3. `build_steps(coordinator)` returns ordered `TutorialStep` descriptors.
##   4. Interactive steps communicate back via `on_board_event(...)` or direct lambdas.
##   5. `cleanup()` disconnects/resets any lesson-local state on exit.

var _coordinator: Node = null
var _board: Node = null


func get_game_type() -> String:
	return ""


func get_tutorial_board_scene() -> PackedScene:
	return null


func get_tutorial_title_fa() -> String:
	var gtype: String = get_game_type()
	if not gtype.is_empty():
		return "%s (آموزش)" % GameRegistry.get_display_name_fa(gtype)
	return "آموزش بازی"


func get_tutorial_subtitle_fa() -> String:
	return "میز تمرینی کتابخانه کافه فکر"


func get_hud_turn_time() -> float:
	var gtype: String = get_game_type()
	if not gtype.is_empty():
		return GameRegistry.get_turn_time(gtype)
	return 20.0


func get_missed_turns_limit_visible() -> bool:
	return false


func get_total_display_steps(default_total: int) -> int:
	return default_total


func get_display_step_index(raw_index: int) -> int:
	return raw_index


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	return []


func on_board_ready(board: Node, coordinator: Node) -> void:
	_board = board
	_coordinator = coordinator


func cleanup() -> void:
	_board = null
	_coordinator = null
