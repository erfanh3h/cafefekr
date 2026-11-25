class_name TutorialBoxFour3D
extends "res://scenes/games/boxfour/box_four_3d.gd"

## Offline interactive BoxFour (چهارطرفه) 3D board for the Library tutorial.
## Demonstrates boosting your orb stack (2 -> 3) and reaching 4 orbs to trigger
## a 4-way explosion & chain reaction that conquers adjacent opponent cells.

signal tutorial_cell_played(c_idx: int, r_idx: int, new_val: int)

var tutorial_input_enabled: bool = false


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_boxfour_state()


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_boxfour_state() -> void:
	var board: Array = []
	for _i: int in range(MAX_CELLS):
		board.append({"value": 0, "equipped_user": 0})
	# Center cell (2,2) -> idx = 12 (You, 2 orbs -> 1 tap = 3 orbs -> 2nd tap = EXPLODE!)
	board[12] = {"value": 2, "equipped_user": 1}
	# Adjacent cell (2,1) -> idx = 11 (Opponent, 3 orbs -> triggers chain explosion when hit!)
	board[11] = {"value": 3, "equipped_user": 2}
	# Neighbor of (2,1): (1,1) -> idx = 6 (Opponent, 1 orb -> conquered in chain reaction!)
	board[6] = {"value": 1, "equipped_user": 2}
	# Keep a corner reserve for Player 1
	board[0] = {"value": 1, "equipped_user": 1}

	on_reconnect_data({
		"game_data": {
			"board": board,
			"scores": [3, 4],
			"current_turn": 1,
		}
	})
	on_start_game()
	is_my_turn = true
	is_board_locked = false


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		var d: Dictionary = payload as Dictionary
		var c_idx: int = int(d.get("c_index", -1))
		var r_idx: int = int(d.get("r_index", -1))
		var idx: int = c_idx * GRID_SIZE + r_idx
		on_piece_selected(1, idx, {"gamer_id": 1, "c_index": c_idx, "r_index": r_idx})
		is_my_turn = true
		is_board_locked = false
		_refresh_highlights()
		var v: int = cell_values[idx] if (idx >= 0 and idx < cell_values.size()) else 0
		tutorial_cell_played.emit(c_idx, r_idx, v)


func get_cell_screen_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= cell_cap_nodes.size() or not is_instance_valid(cell_cap_nodes[idx]):
		return get_board_screen_rect()
	var w_pos: Vector3 = cell_cap_nodes[idx].global_position
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), w_pos, 0.085, 0.085, 66.0)
	return r if r.size.x > 0.0 else get_board_screen_rect()


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.68, 0.04)
