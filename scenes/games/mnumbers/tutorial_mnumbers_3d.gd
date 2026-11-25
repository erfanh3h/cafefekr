class_name TutorialMNumbers3D
extends "res://scenes/games/mnumbers/mnumbers_3d.gd"

## Offline interactive Match Numbers (کشف اعداد) 3D board for the Library tutorial.
## Lets the player flip a mismatching pair (to see memory & flip-back) and then a matching pair (+1 score & extra turn).

signal tutorial_tile_flipped(idx: int, is_first: bool, is_match: bool)

var tutorial_input_enabled: bool = false
var _first_idx: int = -1
var _tile_nums: Array[int] = []


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_mnumbers_state()


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_mnumbers_state() -> void:
	_tile_nums.clear()
	for i: int in range(TOTAL_TILES):
		_tile_nums.append((i % 18) + 1)
	# Ensure easy-to-remember demo tiles: 0 = 7, 1 = 4, 2 = 7
	_tile_nums[0] = 7
	_tile_nums[1] = 4
	_tile_nums[2] = 7
	_first_idx = -1
	on_start_game()
	on_turn_changed(1, true)


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		var idx: int = int((payload as Dictionary).get("index", -1))
		if idx < 0 or idx >= TOTAL_TILES:
			return
		if _first_idx == -1:
			_first_idx = idx
			on_piece_selected(1, -1, {
				"user": 1,
				"index1": idx,
				"value1": _tile_nums[idx],
				"is_first": true,
			})
			is_my_turn = true
			is_board_locked = false
			tutorial_tile_flipped.emit(idx, true, false)
		else:
			var idx1: int = _first_idx
			_first_idx = -1
			var v1: int = _tile_nums[idx1]
			var v2: int = _tile_nums[idx]
			var is_corr: bool = (v1 == v2)
			on_piece_selected(1, -1, {
				"user": 1,
				"index1": idx1,
				"value1": v1,
				"index2": idx,
				"value2": v2,
				"is_correct": is_corr,
			})
			is_my_turn = true
			is_board_locked = false
			tutorial_tile_flipped.emit(idx, false, is_corr)


func get_tile_screen_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= cell_centers.size():
		return get_board_screen_rect()
	var w_pos: Vector3 = to_global(cell_centers[idx])
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), w_pos, 0.065, 0.065, 58.0)
	return r if r.size.x > 0.0 else get_board_screen_rect()


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
