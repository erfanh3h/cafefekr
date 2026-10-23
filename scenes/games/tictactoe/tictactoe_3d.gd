class_name TicTacToe3D
extends "res://scripts/games/base_game_board.gd"

# 3D Physical TicTacToe Board for Cafe Fekr
# High-polish physical wooden board with luxury brass X pieces and sapphire gemstone O rings
# Features dual-layer input detection (Area3D + Camera Raycasting) and physical drop physics
# Extends BaseGameBoard to follow Flutter's structural game architecture

signal cell_clicked(index: int)
signal round_won(winner: int, line: Array)

@export var board_size: float = 1.05
@export var has_missed_turns_limit: bool = false
var cells: Array[Area3D] = []
var cell_pads: Array[MeshInstance3D] = []
var board_state: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0 = empty, 1 = P1 (X), 2 = P2 (O)
var pieces_nodes: Dictionary = {} # cell_index -> Node3D
var winning_line_node: Node3D = null
var last_click_time: float = 0.0

# Materials
var mat_cell_normal: StandardMaterial3D
var mat_cell_hover: StandardMaterial3D
var mat_piece_x: StandardMaterial3D
var mat_piece_o: StandardMaterial3D
var mat_win_line: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D

const WIN_CONDITIONS = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

func _ready() -> void:
	game_type = GameTypes.TIC_TAC_TOE
	_setup_materials()
	_generate_3d_board()

func _setup_materials() -> void:
	# Inlaid carved cell pad: rich honey walnut wood with warm satin sheen
	mat_cell_normal = StandardMaterial3D.new()
	mat_cell_normal.albedo_color = Color(0.64, 0.44, 0.28)
	mat_cell_normal.metallic = 0.03
	mat_cell_normal.roughness = 0.40
	mat_cell_normal.clearcoat_enabled = true
	mat_cell_normal.clearcoat = 0.40
	mat_cell_normal.clearcoat_roughness = 0.15

	# Gentle golden radiance on hover (clean, luxurious, tactile)
	mat_cell_hover = StandardMaterial3D.new()
	mat_cell_hover.albedo_color = Color(0.96, 0.82, 0.32, 0.85)
	mat_cell_hover.metallic = 0.4
	mat_cell_hover.roughness = 0.22
	mat_cell_hover.emission_enabled = true
	mat_cell_hover.emission = Color(0.92, 0.72, 0.22)
	mat_cell_hover.emission_energy_multiplier = 0.65

	# Polished Gold Inlays & Studs
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.94, 0.78, 0.26)
	mat_gold_trim.metallic = 0.92
	mat_gold_trim.roughness = 0.18
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.55

	# Player 1 (X): Radiant Luxury Crimson Enamel & Gold
	mat_piece_x = StandardMaterial3D.new()
	mat_piece_x.albedo_color = Color(0.92, 0.14, 0.22)
	mat_piece_x.metallic = 0.38
	mat_piece_x.roughness = 0.15
	mat_piece_x.rim_enabled = true
	mat_piece_x.rim = 0.55
	mat_piece_x.rim_tint = 0.45
	mat_piece_x.clearcoat_enabled = true
	mat_piece_x.clearcoat = 0.9
	mat_piece_x.clearcoat_roughness = 0.12

	# Player 2 (O): Royal Persian Sapphire Gemstone Torus
	mat_piece_o = StandardMaterial3D.new()
	mat_piece_o.albedo_color = Color(0.10, 0.45, 0.98)
	mat_piece_o.metallic = 0.28
	mat_piece_o.roughness = 0.12
	mat_piece_o.rim_enabled = true
	mat_piece_o.rim = 0.65
	mat_piece_o.rim_tint = 0.55
	mat_piece_o.clearcoat_enabled = true
	mat_piece_o.clearcoat = 0.95
	mat_piece_o.clearcoat_roughness = 0.10

	# Elegant glowing laser winning strike
	mat_win_line = StandardMaterial3D.new()
	mat_win_line.albedo_color = Color(1.0, 0.92, 0.45)
	mat_win_line.emission_enabled = true
	mat_win_line.emission = Color(1.0, 0.82, 0.25)
	mat_win_line.emission_energy_multiplier = 3.0

func _generate_3d_board() -> void:
	var step = board_size / 3.0
	var half = board_size / 2.0
	
	cells.clear()
	cell_pads.clear()
	
	for i in range(9):
		var row = i / 3
		var col = i % 3
		var pos_x = (col * step) - half + (step / 2.0)
		var pos_z = (row * step) - half + (step / 2.0)
		
		var area = Area3D.new()
		area.name = "Cell_%d" % i
		area.position = Vector3(pos_x, 0.049, pos_z)
		
		# Collision box for physics input
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(step * 0.94, 0.08, step * 0.94)
		col_shape.shape = box
		area.add_child(col_shape)
		
		# Visual cell inlay pad
		var mesh_inst = MeshInstance3D.new()
		var plane_mesh = BoxMesh.new()
		plane_mesh.size = Vector3(step * 0.88, 0.006, step * 0.88)
		plane_mesh.material = mat_cell_normal
		mesh_inst.mesh = plane_mesh
		area.add_child(mesh_inst)
		cell_pads.append(mesh_inst)
		
		var cell_idx = i
		area.mouse_entered.connect(func():
			_set_cell_hover(cell_idx, true)
		)
		area.mouse_exited.connect(func():
			_set_cell_hover(cell_idx, false)
		)
		
		add_child(area)
		cells.append(area)

func _set_cell_hover(cell_idx: int, is_hover: bool) -> void:
	if cell_idx < 0 or cell_idx >= cell_pads.size():
		return
	var pad = cell_pads[cell_idx]
	if is_hover and board_state[cell_idx] == 0 and GameManager.is_my_turn:
		pad.material_override = mat_cell_hover
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pad, "position:y", 0.006, 0.1)
	else:
		pad.material_override = null
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pad, "position:y", 0.0, 0.1)

# Direct Camera Raycasting: Guarantees clicks work 100% across all devices
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_raycast_down_pos = event.position
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
		else:
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = event.position.distance_to(_raycast_down_pos)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if dist <= 14.0 and elapsed < 0.6:
					var now = Time.get_ticks_msec() / 1000.0
					if now - last_click_time >= 0.15:
						_raycast_board_click(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_raycast_down_pos = event.position
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
		else:
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = event.position.distance_to(_raycast_down_pos)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if dist <= 14.0 and elapsed < 0.6:
					var now = Time.get_ticks_msec() / 1000.0
					if now - last_click_time >= 0.15:
						_raycast_board_click(event.position)

func _raycast_board_click(screen_pos: Vector2) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
		
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	
	var board_y = global_position.y + 0.035
	if abs(ray_normal.y) < 0.0001:
		return
		
	var t = (board_y - ray_origin.y) / ray_normal.y
	if t < 0.0:
		return
		
	var hit_world = ray_origin + ray_normal * t
	var local_hit = to_local(hit_world)
	
	var half = board_size / 2.0
	if abs(local_hit.x) > half or abs(local_hit.z) > half:
		return
		
	var step = board_size / 3.0
	var col = int((local_hit.x + half) / step)
	var row = int((local_hit.z + half) / step)
	col = clampi(col, 0, 2)
	row = clampi(row, 0, 2)
	
	var cell_idx = row * 3 + col
	_attempt_move(cell_idx)

func _attempt_move(cell_idx: int) -> void:
	if not GameManager.is_game_active:
		print("[TicTacToe] Move rejected: Game is not started yet!")
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if cell_idx < 0 or cell_idx >= 9:
		return
	# 1. Silently ignore clicks while board is locked waiting for server ACK or animating
	if is_board_locked:
		print("[TicTacToe] Move ignored: Board is locked waiting for server ACK")
		return
	
	# 2. Only show 'نوبتت نیست!' if it is legitimately the opponent's turn
	if not is_my_turn:
		print("[TicTacToe] Move rejected: not my turn! (Turn: %d, My Role: %d)" % [current_turn, my_player_index])
		show_hint("نوبتت نیست!")
		AudioManager.play_sound("miss_turn")
		return
		
	# 3. If cell already has a piece, notify player
	if board_state[cell_idx] != 0:
		show_hint("این خانه قبلاً انتخاب شده است!")
		AudioManager.play_sound("miss_turn")
		return
		
	# Lock board immediately so duplicate clicks/touches are dropped cleanly without spamming toasts
	set_board_locked(true)
	is_my_turn = false
	last_click_time = Time.get_ticks_msec() / 1000.0
	
	print("[TicTacToe] Attempting move on cell %d as Player %d..." % [cell_idx, my_player_index])
	ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
	cell_clicked.emit(cell_idx)
	send_move(Commands.Select_Peace, cell_idx)

func on_piece_selected(user_id: int, target_peace: int, _extra: Dictionary = {}) -> void:
	if target_peace < 0 or target_peace >= 9:
		return
	
	print("[TicTacToe] Piece placed on cell %d by Player %d" % [target_peace, user_id])
	board_state[target_peace] = user_id
	_spawn_3d_piece(target_peace, user_id)
	
	# Check for 3-in-a-row winning line
	var win_line = _check_winning_line(user_id)
	if win_line.size() == 3:
		_draw_winning_line(win_line, user_id)
		round_won.emit(user_id, win_line)

func _spawn_3d_piece(cell_idx: int, user_id: int) -> void:
	# If cell already has a piece, don't duplicate
	if pieces_nodes.has(cell_idx) and is_instance_valid(pieces_nodes[cell_idx]):
		return
		
	var area = cells[cell_idx]
	var piece_root = Node3D.new()
	piece_root.name = "Piece_%d" % cell_idx
	
	# Compute resting height based on piece thickness so neither piece clips into the table
	var final_y: float = area.position.y + 0.026
	
	if user_id == 1:
		# P1: Luxury Sculpted Brass & Crimson X Cross with Gold Center Medallion
		final_y = area.position.y + 0.025
		var cross_container = Node3D.new()
		
		var b1 = MeshInstance3D.new()
		var box1 = BoxMesh.new()
		box1.size = Vector3(0.24, 0.048, 0.054)
		box1.material = mat_piece_x
		b1.mesh = box1
		b1.rotation_degrees.y = 45.0
		
		var b2 = MeshInstance3D.new()
		b2.mesh = box1
		b2.rotation_degrees.y = -45.0
		
		cross_container.add_child(b1)
		cross_container.add_child(b2)
		
		# Center gold faceted cabochon stud
		var gold_stud = MeshInstance3D.new()
		var sph_stud = SphereMesh.new()
		sph_stud.radius = 0.024
		sph_stud.height = 0.022
		sph_stud.material = mat_gold_trim
		gold_stud.mesh = sph_stud
		gold_stud.position.y = 0.024
		cross_container.add_child(gold_stud)
		
		piece_root.add_child(cross_container)
	else:
		# P2: Polished Royal Sapphire Gemstone Ring with Inner Gold Core
		final_y = area.position.y + 0.0265
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.074
		torus.outer_radius = 0.126
		torus.rings = 36
		torus.ring_segments = 36
		torus.material = mat_piece_o
		ring.mesh = torus
		ring.rotation_degrees = Vector3.ZERO
		piece_root.add_child(ring)
		
		# Inner concentric gold inlay ring
		var inner_gold = MeshInstance3D.new()
		var torus_inner = TorusMesh.new()
		torus_inner.inner_radius = 0.066
		torus_inner.outer_radius = 0.078
		torus_inner.rings = 24
		torus_inner.ring_segments = 24
		torus_inner.material = mat_gold_trim
		inner_gold.mesh = torus_inner
		inner_gold.rotation_degrees = Vector3.ZERO
		piece_root.add_child(inner_gold)
	
	# Elevated spawn position with hand placement animation
	piece_root.position = Vector3(area.position.x, final_y, area.position.z)
	add_child(piece_root)
	pieces_nodes[cell_idx] = piece_root
	
	var table = get_tree().get_first_node_in_group("cafe_table")
	if table and table.has_method("animate_place_piece"):
		var target_world = area.global_position
		target_world.y = global_position.y + final_y
		table.animate_place_piece(user_id, target_world, piece_root, func():
			AudioManager.play_sound("hit")
			ActionVFXManager.spawn_piece_impact_vfx(self, Vector3(area.position.x, final_y, area.position.z), user_id)
		)
	else:
		# Fallback Action Drop with physical squash & stretch and particle impact
		ActionVFXManager.animate_piece_drop(piece_root, final_y, func():
			AudioManager.play_sound("hit")
			ActionVFXManager.spawn_piece_impact_vfx(self, Vector3(area.position.x, final_y, area.position.z), user_id)
		)

func _check_winning_line(user_id: int) -> Array:
	for cond in WIN_CONDITIONS:
		if board_state[cond[0]] == user_id and board_state[cond[1]] == user_id and board_state[cond[2]] == user_id:
			return cond
	return []

func _draw_winning_line(line_indices: Array, winner_user_id: int = 0) -> void:
	if winning_line_node and is_instance_valid(winning_line_node):
		winning_line_node.queue_free()
		winning_line_node = null
		
	if line_indices.size() != 3:
		return
		
	# Exact 3D coordinates passing through all 3 winning cells
	var strike_y = cells[line_indices[1]].position.y + 0.046
	var p_start = Vector3(cells[line_indices[0]].position.x, strike_y, cells[line_indices[0]].position.z)
	var p_end = Vector3(cells[line_indices[2]].position.x, strike_y, cells[line_indices[2]].position.z)
	var p_mid = Vector3(cells[line_indices[1]].position.x, strike_y, cells[line_indices[1]].position.z)
	
	var dir = (p_end - p_start).normalized()
	var total_len = p_start.distance_to(p_end) + 0.22 # Extends gracefully past both outer piece edges
	
	winning_line_node = Node3D.new()
	winning_line_node.name = "WinningLineStrike"
	
	# Build precise mathematical transform so local Y is aligned with 'dir'
	var up = dir
	var ref = Vector3.UP
	if abs(up.dot(ref)) > 0.95:
		ref = Vector3.FORWARD
	var right = up.cross(ref).normalized()
	var fwd = right.cross(up).normalized()
	winning_line_node.transform = Transform3D(Basis(right, up, fwd), p_mid)
	
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = total_len
	cyl.radial_segments = 24
	
	# Laser color matching the winner's theme (Red for P1, Blue for P2)
	var strike_mat = mat_win_line.duplicate() as StandardMaterial3D
	if winner_user_id == 1:
		strike_mat.albedo_color = Color(1.0, 0.35, 0.35)
		strike_mat.emission = Color(1.0, 0.2, 0.2)
	elif winner_user_id == 2:
		strike_mat.albedo_color = Color(0.35, 0.75, 1.0)
		strike_mat.emission = Color(0.2, 0.6, 1.0)
	else:
		strike_mat.albedo_color = Color(1.0, 0.88, 0.3)
		strike_mat.emission = Color(1.0, 0.75, 0.2)
	cyl.material = strike_mat
	mesh_inst.mesh = cyl
	winning_line_node.add_child(mesh_inst)
	
	# Start with minimal radial thickness, then expand outward along win path
	winning_line_node.scale = Vector3(0.01, 1.0, 0.01)
	add_child(winning_line_node)
	
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(winning_line_node, "scale", Vector3.ONE, 0.45)
	AudioManager.play_sound("bell")
	
	# Action Victory Celebration: Star and confetti shower with celebratory camera shake
	ActionVFXManager.spawn_victory_celebration(self, p_mid, winner_user_id)

func on_turn_changed(_turn: int, _is_me: bool) -> void:
	for i in range(cells.size()):
		_set_cell_hover(i, false)

func on_round_finished(_payload: Variant) -> void:
	get_tree().create_timer(1.8).timeout.connect(reset_board)

func on_new_round(_round_num: int) -> void:
	reset_board()

func reset_board() -> void:
	board_state = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	if winning_line_node and is_instance_valid(winning_line_node):
		winning_line_node.queue_free()
		winning_line_node = null
		
	for piece in pieces_nodes.values():
		if is_instance_valid(piece):
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(piece, "scale", Vector3.ZERO, 0.22)
			tw.parallel().tween_property(piece, "position:y", piece.position.y + 0.22, 0.22)
			tw.finished.connect(piece.queue_free)
			
	pieces_nodes.clear()

func cleanup_board() -> void:
	board_state = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	if winning_line_node and is_instance_valid(winning_line_node):
		winning_line_node.queue_free()
		winning_line_node = null
	for piece in pieces_nodes.values():
		if is_instance_valid(piece):
			piece.queue_free()
	pieces_nodes.clear()

# Synchronizes physical 3D board pieces from server state on reconnect or sync
func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != 9:
		return
	var b_arr = new_board as Array
	print("[TicTacToe 3D] Synchronizing board pieces from server state: %s" % str(b_arr))
	for i in range(9):
		var target_user = int(b_arr[i])
		board_state[i] = target_user
		if target_user != 0 and (not pieces_nodes.has(i) or not is_instance_valid(pieces_nodes[i])):
			_spawn_3d_piece(i, target_user)
		elif target_user == 0 and pieces_nodes.has(i) and is_instance_valid(pieces_nodes[i]):
			pieces_nodes[i].queue_free()
			pieces_nodes.erase(i)
			
	# Check if winning line already exists
	for u in [1, 2]:
		var win_line = _check_winning_line(u)
		if win_line.size() == 3:
			_draw_winning_line(win_line, u)
			break

func on_reconnect_data(_payload: Dictionary) -> void:
	sync_turn_state()
