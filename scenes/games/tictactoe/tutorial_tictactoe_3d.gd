class_name TutorialTicTacToe3D
extends TicTacToe3D

## Completely offline interactive Tic-Tac-Toe 3D board for pre-login onboarding.
## Inherits 100% of TicTacToe3D visuals, 3D piece drop animations, hover effects,
## raycasting, and golden winning-line strike while overriding all network hooks
## with local tutorial rules, 3D glowing cell beacons, and an easy win-friendly bot.

signal tutorial_player_moved(cell_idx: int)
signal tutorial_bot_moved(cell_idx: int)
signal tutorial_wrong_cell_tapped(cell_idx: int)
signal tutorial_player_won(winning_line: Array)
signal tutorial_draw_reached()

var tutorial_input_enabled: bool = false
var guided_allowed_cells: Array[int] = []

var _beacon_nodes: Dictionary = {} # cell_idx -> MeshInstance3D
var _beacon_mat: StandardMaterial3D = null
var _pulse_time: float = 0.0
var _bot_thinking: bool = false
var _match_won: bool = false


func _ready() -> void:
	super._ready()
	_setup_tutorial_beacon_material()
	is_my_turn = true
	my_player_index = 1
	current_turn = 1
	is_board_locked = false


# --- Pure Offline Overrides (Zero NetworkManager Calls) ---

func _connect_network_signals() -> void:
	# Intentionally empty: TutorialTicTacToe3D is 100% offline.
	pass


func _disconnect_network_signals() -> void:
	# Intentionally empty: no network signals were connected.
	pass


func send_move(_command_id: String, payload: Variant) -> void:
	# Route local player's selected cell directly into offline game state.
	var cell_idx: int = int(payload)
	_apply_offline_player_move(cell_idx)


func on_round_finished(_payload: Variant) -> void:
	# Prevent base class from auto-resetting board before the Win Dialog displays.
	set_board_locked(true)


func _attempt_move(cell_idx: int) -> void:
	if _match_won or _bot_thinking:
		return
	if not tutorial_input_enabled:
		return
	if cell_idx < 0 or cell_idx >= 9:
		return
	if board_state[cell_idx] != 0:
		show_hint("این خانه قبلاً پر شده است!")
		AudioManager.play_sound("miss_turn")
		return
	if not guided_allowed_cells.is_empty() and cell_idx not in guided_allowed_cells:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_cell_tapped.emit(cell_idx)
		return

	# Delegate to parent TicTacToe3D._attempt_move() which handles juice, locking,
	# and invokes our overridden send_move() cleanly.
	super._attempt_move(cell_idx)


func _apply_offline_player_move(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= 9 or board_state[cell_idx] != 0:
		set_board_locked(false)
		is_my_turn = true
		return

	clear_guided_cells()
	on_piece_selected(1, cell_idx)
	tutorial_player_moved.emit(cell_idx)

	var win_line: Array = _check_winning_line(1)
	if win_line.size() == 3:
		_match_won = true
		tutorial_input_enabled = false
		set_board_locked(true)
		tutorial_player_won.emit(win_line)
		return

	if _is_board_full():
		tutorial_draw_reached.emit()
		return


func trigger_easy_bot_move(preferred_cell: int = -1, delay_sec: float = 0.65) -> void:
	if _match_won or _is_board_full():
		return
	_bot_thinking = true
	tutorial_input_enabled = false
	set_board_locked(true)
	current_turn = 2
	is_my_turn = false
	GameManager.current_turn = 2
	GameManager.is_my_turn = false

	var timer: SceneTreeTimer = get_tree().create_timer(delay_sec)
	timer.timeout.connect(func():
		if not is_instance_valid(self) or _match_won:
			return
		var chosen: int = _choose_easy_bot_cell(preferred_cell)
		_bot_thinking = false
		if chosen < 0:
			tutorial_draw_reached.emit()
			return

		on_piece_selected(2, chosen)

		# Restore local player's turn
		current_turn = 1
		is_my_turn = true
		GameManager.current_turn = 1
		GameManager.is_my_turn = true
		set_board_locked(false)

		tutorial_bot_moved.emit(chosen)

		if _is_board_full() and _check_winning_line(1).is_empty():
			tutorial_draw_reached.emit()
	)


func _choose_easy_bot_cell(preferred_cell: int) -> int:
	if preferred_cell >= 0 and preferred_cell < 9 and board_state[preferred_cell] == 0:
		return preferred_cell

	var empty_cells: Array[int] = []
	for i in range(9):
		if board_state[i] == 0:
			empty_cells.append(i)
	if empty_cells.is_empty():
		return -1

	# Easy friendly bot policy:
	# 1. Never take a cell that would make the bot win.
	# 2. Never block the player's immediate 2-in-a-row winning cell.
	var player_win_cells: Array[int] = _find_immediate_win_cells(1)
	var bot_win_cells: Array[int] = _find_immediate_win_cells(2)

	var best_friendly: Array[int] = []
	for c in empty_cells:
		if c not in player_win_cells and c not in bot_win_cells:
			best_friendly.append(c)

	if not best_friendly.is_empty():
		# Prefer corners/edges that leave the player's center/row lines wide open
		for pref in [0, 2, 6, 8, 1, 7, 3, 5, 4]:
			if pref in best_friendly:
				return pref
		return best_friendly[0]

	# Fallback: avoid winning for bot if possible
	for c in empty_cells:
		if c not in bot_win_cells:
			return c
	return empty_cells[0]


func _find_immediate_win_cells(player_id: int) -> Array[int]:
	var result: Array[int] = []
	for cond in WIN_CONDITIONS:
		var a: int = int(cond[0])
		var b: int = int(cond[1])
		var c: int = int(cond[2])
		var vals: Array[int] = [int(board_state[a]), int(board_state[b]), int(board_state[c])]
		var count_p: int = 0
		var empty_idx: int = -1
		var indices: Array[int] = [a, b, c]
		for k in range(3):
			if vals[k] == player_id:
				count_p += 1
			elif vals[k] == 0:
				empty_idx = indices[k]
		if count_p == 2 and empty_idx >= 0 and empty_idx not in result:
			result.append(empty_idx)
	return result


func find_recommended_player_cell() -> int:
	# 1. Immediate winning move for player!
	var wins: Array[int] = _find_immediate_win_cells(1)
	if not wins.is_empty():
		return wins[0]
	# 2. Center if available
	if board_state[4] == 0:
		return 4
	# 3. Any cell that creates a 2-in-a-row threat on an open line
	for cond in WIN_CONDITIONS:
		var a: int = int(cond[0])
		var b: int = int(cond[1])
		var c: int = int(cond[2])
		var indices: Array[int] = [a, b, c]
		var has_p1: bool = false
		var has_p2: bool = false
		var empties: Array[int] = []
		for idx in indices:
			if int(board_state[idx]) == 1:
				has_p1 = true
			elif int(board_state[idx]) == 2:
				has_p2 = true
			else:
				empties.append(idx)
		if has_p1 and not has_p2 and not empties.is_empty():
			return empties[0]
	# 4. First empty cell
	for i in range(9):
		if board_state[i] == 0:
			return i
	return -1


func _is_board_full() -> bool:
	for i in range(9):
		if int(board_state[i]) == 0:
			return false
	return true


# --- 3D Glowing Cell Beacon & 3D-to-2D Spotlight Projection ---

func _setup_tutorial_beacon_material() -> void:
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.albedo_color = Color(1.0, 0.86, 0.28, 0.92)
	_beacon_mat.emission_enabled = true
	_beacon_mat.emission = Color(1.0, 0.80, 0.18)
	_beacon_mat.emission_energy_multiplier = 2.6
	_beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_mat.roughness = 0.2
	_beacon_mat.metallic = 0.4


func set_guided_cells(indices: Array[int]) -> void:
	clear_guided_cells()
	guided_allowed_cells = indices.duplicate()
	for idx in guided_allowed_cells:
		if idx < 0 or idx >= cells.size():
			continue
		if int(board_state[idx]) != 0:
			continue
		_spawn_beacon_on_cell(idx)


func clear_guided_cells() -> void:
	guided_allowed_cells.clear()
	for k in _beacon_nodes.keys():
		var n: Node = _beacon_nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	_beacon_nodes.clear()


func _spawn_beacon_on_cell(cell_idx: int) -> void:
	var cell_area: Area3D = cells[cell_idx]
	if not is_instance_valid(cell_area):
		return
	var ring := MeshInstance3D.new()
	ring.name = "TutorialBeacon_%d" % cell_idx
	var torus := TorusMesh.new()
	torus.inner_radius = 0.105
	torus.outer_radius = 0.138
	torus.rings = 24
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = _beacon_mat
	ring.position = Vector3(0.0, 0.042, 0.0)
	cell_area.add_child(ring)
	_beacon_nodes[cell_idx] = ring


func _process(delta: float) -> void:
	if _beacon_nodes.is_empty():
		return
	_pulse_time += delta
	var s: float = 1.0 + 0.09 * sin(_pulse_time * 5.2)
	var y_off: float = 0.042 + 0.012 * sin(_pulse_time * 5.2)
	if _beacon_mat != null:
		_beacon_mat.emission_energy_multiplier = 2.1 + 0.9 * sin(_pulse_time * 5.2)
	for k in _beacon_nodes.keys():
		var ring: MeshInstance3D = _beacon_nodes[k] as MeshInstance3D
		if is_instance_valid(ring):
			ring.scale = Vector3(s, 1.0, s)
			ring.position.y = y_off


func get_cell_screen_rect(cell_idx: int) -> Rect2:
	if cell_idx < 0 or cell_idx >= cells.size():
		return Rect2()
	var cell_area: Area3D = cells[cell_idx]
	if not is_instance_valid(cell_area):
		return Rect2()
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		return Rect2()

	var center_w: Vector3 = cell_area.global_position + Vector3(0.0, 0.04, 0.0)
	if cam.is_position_behind(center_w):
		return Rect2()

	var half: float = (board_size / 3.0) * 0.48
	var corners: Array[Vector3] = [
		center_w + Vector3(-half, 0.0, -half),
		center_w + Vector3(half, 0.0, -half),
		center_w + Vector3(half, 0.0, half),
		center_w + Vector3(-half, 0.0, half)
	]

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pt in corners:
		var sp: Vector2 = cam.unproject_position(pt)
		min_p.x = minf(min_p.x, sp.x)
		min_p.y = minf(min_p.y, sp.y)
		max_p.x = maxf(max_p.x, sp.x)
		max_p.y = maxf(max_p.y, sp.y)

	var rect_size: Vector2 = max_p - min_p
	if rect_size.x < 48.0:
		var cx: float = (min_p.x + max_p.x) * 0.5
		min_p.x = cx - 24.0
		rect_size.x = 48.0
	if rect_size.y < 48.0:
		var cy: float = (min_p.y + max_p.y) * 0.5
		min_p.y = cy - 24.0
		rect_size.y = 48.0
	return Rect2(min_p, rect_size)


func get_board_screen_rect() -> Rect2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		return Rect2()

	var half_extent: float = (board_size * 0.5) + 0.14
	var base_y: float = global_position.y + 0.04
	var corners: Array[Vector3] = [
		global_position + Vector3(-half_extent, base_y - global_position.y, -half_extent),
		global_position + Vector3(half_extent, base_y - global_position.y, -half_extent),
		global_position + Vector3(half_extent, base_y - global_position.y, half_extent),
		global_position + Vector3(-half_extent, base_y - global_position.y, half_extent)
	]

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pt in corners:
		if cam.is_position_behind(pt):
			return Rect2()
		var sp: Vector2 = cam.unproject_position(pt)
		min_p.x = minf(min_p.x, sp.x)
		min_p.y = minf(min_p.y, sp.y)
		max_p.x = maxf(max_p.x, sp.x)
		max_p.y = maxf(max_p.y, sp.y)

	var sz: Vector2 = max_p - min_p
	if sz.x <= 10.0 or sz.y <= 10.0:
		return Rect2()
	return Rect2(min_p, sz)


func reset_tutorial_match() -> void:
	_match_won = false
	_bot_thinking = false
	clear_guided_cells()
	reset_board()
	current_turn = 1
	my_player_index = 1
	is_my_turn = true
	is_board_locked = false


func cleanup_board() -> void:
	clear_guided_cells()
	super.cleanup_board()
