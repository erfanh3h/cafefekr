class_name TutorialMill3D
extends Mill3D

## Offline interactive Mill (Nine Men's Morris) 3D board for the Library tutorial.
## Supports all 3 phases:
##   - Phase 1: Placing pieces & forming a Mill (دوز) -> removing an enemy piece
##   - Phase 2: Sliding pieces along lines to adjacent empty sockets
##   - Phase 3: Flying to any empty socket when reduced to 3 pieces

signal tutorial_piece_placed(node_id: int)
signal tutorial_piece_equipped(node_id: int)
signal tutorial_piece_swapped(src_id: int, tgt_id: int)
signal tutorial_enemy_removed(node_id: int)
signal tutorial_wrong_node_tapped(node_id: int)

var tutorial_input_enabled: bool = false
var guided_allowed_nodes: Array[int] = []

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
	_refresh_turn_markers()


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func send_move(command_id: String, payload: Variant) -> void:
	clear_guided_cells()
	if command_id == Commands.Select_Peace:
		var node_id: int = int(payload)
		on_piece_selected(1, node_id)
		is_my_turn = true
		set_board_locked(false)
		tutorial_piece_placed.emit(node_id)
	elif command_id == Commands.Select_Remove_Peace:
		var node_id: int = int(payload)
		on_piece_removed({"target_peace": node_id, "user": 1})
		is_my_turn = true
		set_board_locked(false)
		tutorial_enemy_removed.emit(node_id)
	elif command_id == Commands.Swap_Peace and typeof(payload) == TYPE_DICTIONARY:
		var d: Dictionary = payload as Dictionary
		var src_id: int = int(d.get("source", d.get("source_peace", -1)))
		var tgt_id: int = int(d.get("target", d.get("target_peace", -1)))
		on_piece_swapped({"source_peace": src_id, "target_peace": tgt_id, "user": 1})
		is_my_turn = true
		set_board_locked(false)
		tutorial_piece_swapped.emit(src_id, tgt_id)


func equip_peace(node_id: int) -> void:
	super.equip_peace(node_id)
	if equipped_peace_index == node_id:
		tutorial_piece_equipped.emit(node_id)


func _on_node_clicked(node_id: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_nodes.is_empty() and node_id not in guided_allowed_nodes:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_node_tapped.emit(node_id)
		return
	super._on_node_clicked(node_id)


func trigger_mill_removal_prompt() -> void:
	on_select_remove_peace(1)


func setup_phase1_mill_scenario() -> void:
	# P1 has 0 and 1 (ready to complete [0, 1, 2]); P2 has 6, 7, 15
	var arr: Array = []
	for _i in range(MAX_NODES):
		arr.append(0)
	arr[0] = 1
	arr[1] = 1
	arr[6] = 2
	arr[7] = 2
	arr[15] = 2
	player1_played_peaces = 2
	player2_played_peaces = 3
	player1_removed_peaces = 0
	player2_removed_peaces = 0
	let_remove_peace = false
	current_remover = 0
	sync_board_state(arr)
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	_refresh_turn_markers()


func setup_phase2_slide_scenario() -> void:
	# All 9 pieces placed for both players; P1 can slide node 2 -> 14
	var arr: Array = []
	for _i in range(MAX_NODES):
		arr.append(0)
	for idx in [0, 1, 2, 3, 4, 10, 18, 21, 22]:
		arr[idx] = 1
	for idx in [5, 6, 7, 8, 12, 13, 15, 16, 17]:
		arr[idx] = 2
	player1_played_peaces = 9
	player2_played_peaces = 9
	let_remove_peace = false
	current_remover = 0
	sync_board_state(arr)
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	_refresh_turn_markers()


func setup_phase3_flying_scenario() -> void:
	# P1 is down to 3 pieces (0, 1, 20) -> Flying unlocked! Can fly 20 -> 2 to make [0, 1, 2]
	var arr: Array = []
	for _i in range(MAX_NODES):
		arr.append(0)
	for idx in [0, 1, 20]:
		arr[idx] = 1
	for idx in [5, 6, 7, 12, 15, 17]:
		arr[idx] = 2
	player1_played_peaces = 9
	player2_played_peaces = 9
	player1_removed_peaces = 6
	let_remove_peace = false
	current_remover = 0
	sync_board_state(arr)
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	_refresh_turn_markers()


func set_guided_nodes(indices: Array[int]) -> void:
	clear_guided_cells()
	guided_allowed_nodes = indices.duplicate()
	for idx in guided_allowed_nodes:
		if idx < 0 or idx >= node_sockets.size():
			continue
		var ring: MeshInstance3D = Tutorial3DHelper.spawn_ring_beacon(
			node_sockets[idx], 0.042, 0.056, 0.050, _beacon_mat, "TutorialBeacon_%d" % idx
		)
		if ring != null:
			_beacon_nodes[idx] = ring


func clear_guided_cells() -> void:
	guided_allowed_nodes.clear()
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


func get_node_screen_rect(node_id: int) -> Rect2:
	if node_id < 0 or node_id >= node_sockets.size():
		return Rect2()
	return Tutorial3DHelper.project_world_box_rect(
		get_viewport(), node_sockets[node_id].global_position + Vector3(0.0, 0.05, 0.0), 0.065, 0.065, 52.0
	)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.62, 0.04)


func cleanup_board() -> void:
	clear_guided_cells()
	super.cleanup_board()
