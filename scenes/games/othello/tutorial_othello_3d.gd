class_name TutorialOthello3D
extends Othello3D

## Offline interactive Othello 3D board for the Library tutorial.

signal tutorial_player_moved(cell_idx: int)
signal tutorial_scripted_move_finished(cell_idx: int)
signal tutorial_wrong_cell_tapped(cell_idx: int)

var tutorial_input_enabled: bool = false
var guided_allowed_cells: Array[int] = []

var _beacon_nodes: Dictionary = {}
var _beacon_mat: StandardMaterial3D = null
var _pulse_time: float = 0.0
var _scripted_busy: bool = false


func _ready() -> void:
	super._ready()
	_beacon_mat = Tutorial3DHelper.create_beacon_material()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	update_legal_moves_for_turn()


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func send_move(_command_id: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = payload as Dictionary
	var r_idx: int = int(d.get("r_index", -1))
	var c_idx: int = int(d.get("c_index", -1))
	var cell_idx: int = coord_to_index(r_idx, c_idx)
	clear_guided_cells()
	on_piece_selected(1, 0, d)
	tutorial_player_moved.emit(cell_idx)


func _on_cell_clicked(cell_idx: int) -> void:
	if _scripted_busy or not tutorial_input_enabled:
		return
	if not guided_allowed_cells.is_empty() and cell_idx not in guided_allowed_cells:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_cell_tapped.emit(cell_idx)
		return
	super._on_cell_clicked(cell_idx)


func trigger_scripted_move(r_idx: int, c_idx: int, delay_sec: float = 0.85) -> void:
	_scripted_busy = true
	tutorial_input_enabled = false
	set_board_locked(true)
	current_turn = 2
	is_my_turn = false
	GameManager.current_turn = 2

	get_tree().create_timer(delay_sec).timeout.connect(func():
		if not is_instance_valid(self):
			return
		var cell_idx: int = coord_to_index(r_idx, c_idx)
		on_piece_selected(2, 0, {"r_index": r_idx, "c_index": c_idx})
		get_tree().create_timer(0.55).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_scripted_busy = false
			current_turn = 1
			is_my_turn = true
			GameManager.current_turn = 1
			set_board_locked(false)
			update_legal_moves_for_turn()
			tutorial_scripted_move_finished.emit(cell_idx)
		)
	)


func set_guided_cells(indices: Array[int]) -> void:
	clear_guided_cells()
	guided_allowed_cells = indices.duplicate()
	for idx in guided_allowed_cells:
		if idx < 0 or idx >= cells.size():
			continue
		var ring: MeshInstance3D = Tutorial3DHelper.spawn_ring_beacon(
			cells[idx], 0.036, 0.050, 0.045, _beacon_mat, "TutorialBeacon_%d" % idx
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
	Tutorial3DHelper.animate_beacons(_beacon_nodes, _beacon_mat, _pulse_time, 0.045, 0.008)


func get_first_legal_cell() -> int:
	if not current_legal_moves.is_empty():
		return int(current_legal_moves.keys()[0])
	return 19


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
