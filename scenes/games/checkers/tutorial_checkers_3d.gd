class_name TutorialCheckers3D
extends "res://scenes/games/checkers/checkers_3d.gd"

## Offline interactive Checkers 3D board for the Library tutorial.

signal tutorial_piece_equipped(cell_idx: int)
signal tutorial_player_moved(src_idx: int, tgt_idx: int)
signal tutorial_wrong_cell_tapped(cell_idx: int)

var tutorial_input_enabled: bool = false
var guided_allowed_cells: Array[int] = []

var _beacon_nodes: Dictionary = {}
var _beacon_mat: StandardMaterial3D = null
var _pulse_time: float = 0.0


func _ready() -> void:
	super._ready()
	_beacon_mat = Tutorial3DHelper.create_beacon_material()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	set_pieces_movements()


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func send_move(_command_id: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload as Dictionary
	var src_idx: int = coord_to_index(Vector2i(int(d.get("s_r_index", -1)), int(d.get("s_c_index", -1))))
	var tgt_idx: int = coord_to_index(Vector2i(int(d.get("t_r_index", -1)), int(d.get("t_c_index", -1))))
	clear_guided_cells()
	on_piece_selected(1, 0, d)
	is_my_turn = true
	set_board_locked(false)
	tutorial_player_moved.emit(src_idx, tgt_idx)


func equip_piece(cell_idx: int) -> void:
	super.equip_piece(cell_idx)
	if equipped_peace_index == cell_idx:
		tutorial_piece_equipped.emit(cell_idx)


func _on_cell_clicked(cell_idx: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_cells.is_empty() and cell_idx not in guided_allowed_cells:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_cell_tapped.emit(cell_idx)
		return
	super._on_cell_clicked(cell_idx)


func setup_capture_and_king_scenario() -> void:
	# Playable dark squares have (row + col) % 2 == 0:
	# P1 at (row=5, col=1) -> idx 41, P2 enemy at (row=6, col=2) -> idx 50,
	# jumping to (row=7, col=3) -> idx 59 captures P2 AND promotes to King on row 7!
	var new_board: Array = []
	for _i in range(64):
		new_board.append({"pawn_gamer_id": 0, "is_super_pawn": false})
	new_board[5 * 8 + 1] = {"pawn_gamer_id": 1, "is_super_pawn": false} # idx 41
	new_board[2 * 8 + 0] = {"pawn_gamer_id": 1, "is_super_pawn": false} # idx 16
	new_board[6 * 8 + 2] = {"pawn_gamer_id": 2, "is_super_pawn": false} # idx 50
	new_board[6 * 8 + 4] = {"pawn_gamer_id": 2, "is_super_pawn": false} # idx 52
	sync_board_state(new_board)
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	release_piece()
	set_pieces_movements()


func get_first_movable_cell() -> int:
	if not current_pieces_moves.is_empty():
		return int(current_pieces_moves.keys()[0])
	return 16


func get_first_target_for(cell_idx: int) -> int:
	if current_pieces_moves.has(cell_idx):
		var arr: Array = current_pieces_moves[cell_idx]
		if not arr.is_empty():
			var mv: Dictionary = arr[0] as Dictionary
			if mv.has("target") and mv["target"] is Vector2i:
				return coord_to_index(mv["target"] as Vector2i)
	return -1


func set_guided_cells(indices: Array[int]) -> void:
	clear_guided_cells()
	guided_allowed_cells = indices.duplicate()
	for idx in guided_allowed_cells:
		if idx < 0 or idx >= cells.size():
			continue
		var ring: MeshInstance3D = Tutorial3DHelper.spawn_ring_beacon(
			cells[idx], 0.042, 0.056, 0.050, _beacon_mat, "TutorialBeacon_%d" % idx
		)
		if ring != null:
			_beacon_nodes[idx] = ring


func clear_guided_cells() -> void:
	guided_allowed_cells.clear()
	for k in _beacon_nodes.keys():
		var n: Node = _beacon_nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_beacon_nodes.clear()


func _process(delta: float) -> void:
	if _beacon_nodes.is_empty():
		return
	_pulse_time += delta
	Tutorial3DHelper.animate_beacons(_beacon_nodes, _beacon_mat, _pulse_time, 0.050, 0.008)


func get_cell_screen_rect(cell_idx: int) -> Rect2:
	if cell_idx < 0 or cell_idx >= cells.size():
		return Rect2()
	return Tutorial3DHelper.project_world_box_rect(
		get_viewport(), cells[cell_idx].global_position + Vector3(0.0, 0.04, 0.0), 0.065, 0.065, 52.0
	)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.58, 0.04)


func cleanup_board() -> void:
	clear_guided_cells()
	super.cleanup_board()
