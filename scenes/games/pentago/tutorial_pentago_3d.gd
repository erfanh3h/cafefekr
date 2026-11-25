class_name TutorialPentago3D
extends Pentago3D

## Offline interactive Pentago 3D board for the Library tutorial.

signal tutorial_marble_placed(cell_id: int)
signal tutorial_quadrant_rotated(rot_id: int)

var tutorial_input_enabled: bool = false
var guided_allowed_cells: Array[int] = []
var guided_allowed_rotations: Array[int] = []


func _ready() -> void:
	super._ready()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func _connect_pentago_signals() -> void:
	pass


func _disconnect_pentago_signals() -> void:
	pass


func send_move(command_id: String, payload: Variant) -> void:
	if command_id == Commands.Select_Peace:
		var cell_id: int = int(payload)
		on_piece_selected(1, cell_id)
		is_my_turn = true
		set_board_locked(false)
		tutorial_marble_placed.emit(cell_id)
	elif command_id == Commands.Rotate_Peace:
		var rot_id: int = int(payload)
		on_peace_rotated({"rotation_id": rot_id, "user_id": 1})
		is_my_turn = true
		set_board_locked(false)
		tutorial_quadrant_rotated.emit(rot_id)


func _attempt_place_marble(cell_id: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_cells.is_empty() and cell_id not in guided_allowed_cells:
		AudioManager.play_sound("miss_turn")
		return
	super._attempt_place_marble(cell_id)


func _attempt_rotate_quadrant(rot_id: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_rotations.is_empty() and rot_id not in guided_allowed_rotations:
		AudioManager.play_sound("miss_turn")
		return
	super._attempt_rotate_quadrant(rot_id)


func get_rotation_paddle_screen_rect(rot_id: int) -> Rect2:
	var idx: int = rot_id - 1
	if idx < 0 or idx >= rotation_btn_nodes.size():
		return Rect2()
	var n: Node3D = rotation_btn_nodes[idx]
	if not is_instance_valid(n):
		return Rect2()
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), n.global_position, 0.065, 0.055, 54.0)


func setup_winning_rotation_scenario() -> void:
	# Pentago3D indexes cells per quadrant (Q0=0..8, Q1=9..17, Q2=18..26, Q3=27..35):
	# Middle row across Q0+Q1 is [3, 4, 5, 12, 13, 14].
	# Pre-place P1 at [3, 4, 5] (Q0) and [10] (Q1 top-middle).
	# Player places at [13] (Q1 center, invariant to rotation),
	# then rotates Q1 CCW (rot_id=3) -> [10] moves to [12], forming [3, 4, 5, 12, 13] = 5 in a row!
	var arr: Array[int] = []
	arr.resize(NUM_CELLS)
	arr.fill(0)
	arr[3] = 1
	arr[4] = 1
	arr[5] = 1
	arr[10] = 1
	arr[18] = 2
	arr[19] = 2
	arr[27] = 2
	arr[31] = 2
	sync_board_state(arr)
	_win_vfx_shown = false
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	is_selection_played = false
	is_rotation_played = false
	_update_3d_labels_and_highlights()


func get_cell_screen_rect(cell_id: int) -> Rect2:
	var w_pos: Vector3 = to_global(_get_cell_world_pos(cell_id))
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), w_pos, 0.036, 0.036, 46.0)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.62, 0.04)
