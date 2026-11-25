class_name TutorialSudoku3D
extends "res://scenes/games/sudoku/sudoku_3d.gd"

## Offline interactive Sudoku 3D board for the Library tutorial.
## Starts with 78/81 filled cells and 3 strategic empty cells:
## - (0, 2) = index 2 -> answer 4
## - (4, 4) = index 40 -> answer 5
## - (8, 8) = index 80 -> answer 9
## Then player taps the 3D Solve button on the board.

signal tutorial_cell_filled(idx: int, num: int)
signal tutorial_solved()

var tutorial_input_enabled: bool = false


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_sudoku_state()
	call_deferred("enable_2d_top_down_view")
	get_tree().create_timer(1.10).timeout.connect(func():
		if is_instance_valid(self):
			enable_2d_top_down_view()
	)


func _find_cafe_table() -> Node:
	var p1: Node = get_parent()
	if is_instance_valid(p1) and is_instance_valid(p1.get_parent()) and p1.get_parent().has_method("set_top_down_view"):
		return p1.get_parent()
	var tree := get_tree()
	if not tree:
		return null
	var table: Node = tree.get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		table = tree.root.find_child("CafeTable", true, false)
	return table


func enable_2d_top_down_view() -> void:
	var table: Node = _find_cafe_table()
	if not is_instance_valid(table):
		return
	table.set("_intro_glide_pending", false)
	table.set("_intro_glide_played_for_board", true)
	table.set("_intro_glide_active", false)
	table.set("is_board_view_active", true)
	table.set("top_down_target_height", 2.95)
	if not bool(table.get("is_top_down_view")) and table.has_method("set_top_down_view"):
		table.call("set_top_down_view", true, 0.25)


func _exit_tree() -> void:
	var table: Node = _find_cafe_table()
	if is_instance_valid(table) and table.has_method("set_top_down_view"):
		table.call("set_top_down_view", false, 0.25)
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_sudoku_state() -> void:
	var grid: Array[int] = [
		5, 3, 0, 6, 7, 8, 9, 1, 2,
		6, 7, 2, 1, 9, 5, 3, 4, 8,
		1, 9, 8, 3, 4, 2, 5, 6, 7,
		8, 5, 9, 7, 6, 1, 4, 2, 3,
		4, 2, 6, 8, 0, 3, 7, 9, 1,
		7, 1, 3, 9, 2, 4, 8, 5, 6,
		9, 6, 1, 5, 3, 7, 2, 8, 4,
		2, 8, 7, 4, 1, 9, 6, 3, 5,
		3, 4, 5, 2, 8, 6, 1, 7, 0,
	]
	sync_board_state(grid)
	on_start_game()


func _send_sudoku_command(cmd_id: String, params: Dictionary) -> void:
	if not tutorial_input_enabled:
		return
	if cmd_id == Commands.Select_Peace:
		var idx: int = int(params.get("piece_id", -1))
		var num: int = int(params.get("number", 0))
		tutorial_cell_filled.emit(idx, num)
	elif cmd_id == Commands.Solve:
		tutorial_solved.emit()


func get_cell_screen_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= cell_centers.size():
		return get_board_screen_rect()
	var w_pos: Vector3 = to_global(cell_centers[idx])
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), w_pos, 0.048, 0.048, 56.0)
	return r if r.size.x > 0.0 else get_board_screen_rect()


func get_solve_button_control() -> Control:
	if is_instance_valid(_action_solve_btn):
		return _action_solve_btn
	return _action_dock_panel


func get_digit_button(num: int) -> Control:
	if num >= 1 and num < _action_digit_buttons.size() and is_instance_valid(_action_digit_buttons[num]):
		return _action_digit_buttons[num]
	return _action_dock_panel


func get_dock_control() -> Control:
	return _action_dock_panel


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.68, 0.04)
