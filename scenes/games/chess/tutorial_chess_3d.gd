class_name TutorialChess3D
extends Chess3D

## Completely offline interactive Chess 3D board for the Library tutorial.
## Inherits 100% of Chess3D visuals, Staunton meshes, graveyard trays,
## legal-move dots, capture rings, and animations while overriding network
## hooks with local guided execution.

signal tutorial_piece_equipped(cell_idx: int)
signal tutorial_player_moved(src_idx: int, tgt_idx: int, is_hit: bool)
signal tutorial_scripted_move_finished(src_idx: int, tgt_idx: int)
signal tutorial_wrong_cell_tapped(cell_idx: int)

var tutorial_input_enabled: bool = false
var guided_allowed_cells: Array[int] = []

var _beacon_nodes: Dictionary = {} # cell_idx -> MeshInstance3D
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
	set_pieces_movements()


# --- Pure Offline Overrides (Zero NetworkManager Calls) ---

func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func send_move(_command_id: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var d: Dictionary = (payload as Dictionary).duplicate()
	var s_coord := Vector2i(int(d.get("s_c_index", -1)), int(d.get("s_r_index", -1)))
	var t_coord := Vector2i(int(d.get("t_c_index", -1)), int(d.get("t_r_index", -1)))
	var src_idx: int = coord_to_index(s_coord)
	var tgt_idx: int = coord_to_index(t_coord)
	if src_idx < 0 or tgt_idx < 0 or tgt_idx >= board_data.size():
		return

	var is_hit: bool = int(board_data[tgt_idx].get("gamer_id", 0)) == 2
	d["type"] = "hit" if is_hit else "move"

	clear_guided_cells()
	on_piece_selected(1, 0, d)
	tutorial_player_moved.emit(src_idx, tgt_idx, is_hit)


func equip_piece(cell_idx: int) -> void:
	super.equip_piece(cell_idx)
	if equipped_peace_index == cell_idx:
		tutorial_piece_equipped.emit(cell_idx)


func _on_cell_clicked(cell_idx: int) -> void:
	if _scripted_busy or not tutorial_input_enabled:
		return
	if not guided_allowed_cells.is_empty() and cell_idx not in guided_allowed_cells:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_cell_tapped.emit(cell_idx)
		return
	super._on_cell_clicked(cell_idx)


func trigger_scripted_move(src_coord: Vector2i, tgt_coord: Vector2i, delay_sec: float = 0.75) -> void:
	_scripted_busy = true
	tutorial_input_enabled = false
	set_board_locked(true)
	current_turn = 2
	is_my_turn = false
	GameManager.current_turn = 2

	var timer: SceneTreeTimer = get_tree().create_timer(delay_sec)
	timer.timeout.connect(func():
		if not is_instance_valid(self):
			return
		var src_idx: int = coord_to_index(src_coord)
		var tgt_idx: int = coord_to_index(tgt_coord)
		var is_hit: bool = tgt_idx >= 0 and tgt_idx < board_data.size() and int(board_data[tgt_idx].get("gamer_id", 0)) == 1
		var payload := {
			"s_c_index": src_coord.x,
			"s_r_index": src_coord.y,
			"t_c_index": tgt_coord.x,
			"t_r_index": tgt_coord.y,
			"type": "hit" if is_hit else "move"
		}
		on_piece_selected(2, 0, payload)

		# Restore local player's turn after move animation settles
		get_tree().create_timer(0.45).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_scripted_busy = false
			current_turn = 1
			is_my_turn = true
			GameManager.current_turn = 1
			set_board_locked(false)
			set_pieces_movements()
			tutorial_scripted_move_finished.emit(src_idx, tgt_idx)
		)
	)


# --- Guided Beacons & 3D-to-2D Spotlight Projection ---

func set_guided_cells(indices: Array[int]) -> void:
	clear_guided_cells()
	guided_allowed_cells = indices.duplicate()
	for idx in guided_allowed_cells:
		if idx < 0 or idx >= cells.size():
			continue
		var cell_area: Area3D = cells[idx]
		var ring: MeshInstance3D = Tutorial3DHelper.spawn_ring_beacon(
			cell_area,
			cell_size * 0.34,
			cell_size * 0.45,
			0.052,
			_beacon_mat,
			"TutorialBeacon_%d" % idx
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


func preview_piece_moves(cell_idx: int) -> void:
	release_piece()
	set_pieces_movements()
	if current_pieces_moves.has(cell_idx) or current_pieces_hits.has(cell_idx):
		equip_piece(cell_idx)


func clear_piece_preview() -> void:
	release_piece()


func show_demo_check_marker(cell_idx: int) -> void:
	clear_demo_check_marker()
	_spawn_check_marker(cell_idx)


func clear_demo_check_marker() -> void:
	if check_warning_marker and is_instance_valid(check_warning_marker):
		check_warning_marker.queue_free()
		check_warning_marker = null


func _process(delta: float) -> void:
	if _beacon_nodes.is_empty():
		return
	_pulse_time += delta
	Tutorial3DHelper.animate_beacons(_beacon_nodes, _beacon_mat, _pulse_time, 0.052, 0.008)


func get_cell_screen_rect(cell_idx: int) -> Rect2:
	if cell_idx < 0 or cell_idx >= cells.size():
		return Rect2()
	var cell_area: Area3D = cells[cell_idx]
	if not is_instance_valid(cell_area):
		return Rect2()
	var half: float = cell_size * 0.52
	return Tutorial3DHelper.project_world_box_rect(
		get_viewport(),
		cell_area.global_position + Vector3(0.0, 0.05, 0.0),
		half,
		half,
		52.0
	)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(
		get_viewport(),
		global_position,
		half_board + 0.12,
		0.05
	)


func cleanup_board() -> void:
	clear_guided_cells()
	super.cleanup_board()
