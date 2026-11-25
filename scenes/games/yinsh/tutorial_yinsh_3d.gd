class_name TutorialYinsh3D
extends "res://scenes/games/yinsh/yinsh_3d.gd"

## Offline interactive YINSH 3D board for the Library tutorial.
## Uses the exact 3D hex lattice, ring placement, disk planting, ring jumping & disk flipping,
## local 5-in-a-row detection + beam VFX, and ring removal for scoring.

signal tutorial_ring_placed(piece_id: int)
signal tutorial_ring_selected(piece_id: int)
signal tutorial_ring_moved(target_id: int, flipped_count: int)
signal tutorial_five_formed()
signal tutorial_ring_removed(piece_id: int)

var tutorial_input_enabled: bool = false
var _stage: String = "place" # "place" | "select_jump" | "move_jump" | "five_row" | "remove_ring"
var _tut_coord_to_id: Dictionary = {}


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	_build_tut_coord_map()
	super._ready()
	setup_initial_ring_placement()


func _build_tut_coord_map() -> void:
	_tut_coord_to_id.clear()
	var pid: int = 0
	for r: int in range(ROW_COLS.size()):
		var cols: Array = ROW_COLS[r]
		for c in cols:
			_tut_coord_to_id[Vector2i(r, int(c))] = pid
			pid += 1


func _connect_yinsh_signals() -> void:
	pass


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func _spot(r: int, c: int) -> int:
	return int(_tut_coord_to_id.get(Vector2i(r, c), -1))


func _clear_all_pieces() -> void:
	for i: int in range(NUM_SPOTS):
		ring_owners[i] = 0
		disk_owners[i] = 0
	last_selected_piece_id = -1
	possible_moves.clear()
	current_remover = 0
	last_move_from = -1
	last_move_to = -1
	hovered_piece_id = -1


func setup_initial_ring_placement() -> void:
	_stage = "place"
	_clear_all_pieces()
	is_setup_ring_phase = true
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	player1_score = 0
	player2_score = 0
	remaining_disks = 51

	# 4 White rings + 5 Black rings already placed -> user places their 5th ring!
	for c: Vector2i in [Vector2i(2, -3), Vector2i(2, 3), Vector2i(8, -3), Vector2i(8, 3)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 1
	for c: Vector2i in [Vector2i(1, -2), Vector2i(1, 2), Vector2i(5, 0), Vector2i(9, -2), Vector2i(9, 2)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 2

	player1_rings_left = 1
	player2_rings_left = 0
	_rebuild_all_pieces_visual()
	_sync_hud_scores()


func setup_jump_and_flip_scenario() -> void:
	_stage = "select_jump"
	_clear_all_pieces()
	is_setup_ring_phase = false
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	remaining_disks = 47

	# White rings: (5, -4) is ready to jump right along Row 5 over (5, -2) and (5, 0) -> (5, 2)!
	for c: Vector2i in [Vector2i(5, -4), Vector2i(2, -3), Vector2i(2, 3), Vector2i(8, -3), Vector2i(8, 3)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 1
	# Black rings
	for c: Vector2i in [Vector2i(1, -2), Vector2i(1, 2), Vector2i(7, -4), Vector2i(7, 4), Vector2i(9, 0)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 2

	# 2 Black disks directly in front of White ring (5, -4) along Row 5 -> jump lands at (5, +2)!
	for c: Vector2i in [Vector2i(5, -2), Vector2i(5, 0)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			disk_owners[id] = 2

	player1_rings_left = 0
	player2_rings_left = 0
	_rebuild_all_pieces_visual()
	_sync_hud_scores()


func setup_five_in_row_scenario() -> void:
	_stage = "five_row"
	_clear_all_pieces()
	is_setup_ring_phase = false
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	remaining_disks = 45

	# White ring (5, -4) plants the 5th white disk in line (5,-4)..(5,+4)!
	for c: Vector2i in [Vector2i(5, -4), Vector2i(2, -3), Vector2i(2, 3), Vector2i(8, -3), Vector2i(8, 3)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 1
	# Black rings
	for c: Vector2i in [Vector2i(1, -2), Vector2i(1, 2), Vector2i(7, -4), Vector2i(7, 4), Vector2i(9, 0)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			ring_owners[id] = 2

	# 4 collinear White disks along Row 5 at (5,-2), (5,0), (5,2), (5,4)
	for c: Vector2i in [Vector2i(5, -2), Vector2i(5, 0), Vector2i(5, 2), Vector2i(5, 4)]:
		var id := _spot(c.x, c.y)
		if id >= 0:
			disk_owners[id] = 1

	player1_rings_left = 0
	player2_rings_left = 0
	_rebuild_all_pieces_visual()
	_sync_hud_scores()


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return

	if command_id == Commands.Submit_Ring:
		var pid: int = int(payload)
		on_ring_submitted({"gamer_id": 1, "piece_id": pid})
		is_my_turn = true
		is_board_locked = false
		tutorial_ring_placed.emit(pid)

	elif command_id == Commands.Select_Peace:
		var pid: int = int(payload)
		is_my_turn = true
		is_board_locked = false
		tutorial_ring_selected.emit(pid)

	elif command_id == Commands.Move_Ring and typeof(payload) == TYPE_DICTIONARY:
		var tgt: int = int((payload as Dictionary).get("target_id", -1))
		var flipped: int = 0
		if last_move_from >= 0 and last_move_to >= 0:
			flipped = _get_disks_between(last_move_from, last_move_to).size()
		# Check if 5-in-a-row happened (Yinsh3D._execute_ring_move already checked _check_local_five_in_a_row and set current_remover!)
		if current_remover == 1:
			is_my_turn = true
			is_board_locked = false
			tutorial_five_formed.emit()
		else:
			is_my_turn = true
			is_board_locked = false
			tutorial_ring_moved.emit(tgt, flipped)

	elif command_id == Commands.Select_Remove_Peace:
		var pid: int = int(payload)
		player1_score += 1
		current_remover = 0
		is_my_turn = true
		is_board_locked = false
		_sync_hud_scores()
		_update_3d_labels_and_highlights()
		tutorial_ring_removed.emit(pid)


func get_spot_screen_rect(r: int, c: int, min_px: float = 68.0) -> Rect2:
	var pid: int = _spot(r, c)
	if pid < 0 or pid >= spot_positions.size():
		return get_board_screen_rect()
	var world_pos: Vector3 = to_global(spot_positions[pid])
	var rect: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), world_pos, 0.068, 0.068, min_px)
	return rect if rect.size.x > 0.0 else get_board_screen_rect()


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
