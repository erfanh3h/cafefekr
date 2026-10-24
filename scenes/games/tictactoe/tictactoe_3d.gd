class_name TicTacToe3D
extends "res://scripts/games/base_game_board.gd"

# Deluxe Royal Persian Inlaid 3D TicTacToe Board
# Inherits from BaseGameBoard for standardized Cafe Fekr game architecture

signal cell_clicked(index: int)
signal round_won(winner: int, line: Array)

@export var board_size: float = 1.05
@export var has_missed_turns_limit: bool = false

var cells: Array[Area3D] = []
var cell_pads: Array[MeshInstance3D] = []
var cell_rings: Array[MeshInstance3D] = []
var cell_base_mats: Array[StandardMaterial3D] = []
var board_state: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0 = empty, 1 = P1 (X), 2 = P2 (O)
var pieces_nodes: Dictionary = {} # cell_index -> Node3D
var winning_line_node: Node3D = null
var last_click_time: float = 0.0

# Luxury Materials
var mat_cell_light: StandardMaterial3D
var mat_cell_dark: StandardMaterial3D
var mat_cell_hover: StandardMaterial3D
var mat_cell_frame: StandardMaterial3D
var mat_cell_ring: StandardMaterial3D
var mat_cell_ring_hover: StandardMaterial3D
var mat_walnut_rail: StandardMaterial3D
var mat_obsidian_slate: StandardMaterial3D
var mat_piece_x: StandardMaterial3D
var mat_piece_o: StandardMaterial3D
var mat_piece_base: StandardMaterial3D
var mat_win_line: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_ruby_gem: StandardMaterial3D
var mat_sapphire_gem: StandardMaterial3D

const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")

const WIN_CONDITIONS = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6]
]

func _ready() -> void:
	game_type = GameTypes.TIC_TAC_TOE
	_setup_materials()
	_build_royal_architecture()
	_generate_3d_board()

func _setup_materials() -> void:
	# Warm Royal Cream-Ivory Marble Inlay (Corners & Center)
	mat_cell_light = StandardMaterial3D.new()
	mat_cell_light.albedo_color = Color(0.84, 0.75, 0.60)
	mat_cell_light.metallic = 0.05
	mat_cell_light.roughness = 0.28
	mat_cell_light.clearcoat_enabled = true
	mat_cell_light.clearcoat = 0.55
	mat_cell_light.clearcoat_roughness = 0.14

	# Rich Roasted Persian Walnut-Teak Inlay (Cardinal Edge Cells)
	mat_cell_dark = StandardMaterial3D.new()
	mat_cell_dark.albedo_color = Color(0.42, 0.26, 0.16)
	mat_cell_dark.metallic = 0.06
	mat_cell_dark.roughness = 0.30
	mat_cell_dark.clearcoat_enabled = true
	mat_cell_dark.clearcoat = 0.55
	mat_cell_dark.clearcoat_roughness = 0.15

	# Gentle Golden Radiance on Hover
	mat_cell_hover = StandardMaterial3D.new()
	mat_cell_hover.albedo_color = Color(0.98, 0.84, 0.36)
	mat_cell_hover.metallic = 0.45
	mat_cell_hover.roughness = 0.20
	mat_cell_hover.emission_enabled = true
	mat_cell_hover.emission = Color(0.95, 0.76, 0.24)
	mat_cell_hover.emission_energy_multiplier = 0.55

	# Beveled Dark Bronze Cell Frame
	mat_cell_frame = StandardMaterial3D.new()
	mat_cell_frame.albedo_color = Color(0.22, 0.15, 0.09)
	mat_cell_frame.metallic = 0.55
	mat_cell_frame.roughness = 0.28
	mat_cell_frame.clearcoat_enabled = true
	mat_cell_frame.clearcoat = 0.45

	# Subtle Engraved Gold Target Ring inside Cell Well
	mat_cell_ring = StandardMaterial3D.new()
	mat_cell_ring.albedo_color = Color(0.88, 0.70, 0.26)
	mat_cell_ring.metallic = 0.85
	mat_cell_ring.roughness = 0.24

	mat_cell_ring_hover = StandardMaterial3D.new()
	mat_cell_ring_hover.albedo_color = Color(1.0, 0.92, 0.45)
	mat_cell_ring_hover.metallic = 0.90
	mat_cell_ring_hover.roughness = 0.15
	mat_cell_ring_hover.emission_enabled = true
	mat_cell_ring_hover.emission = Color(1.0, 0.85, 0.30)
	mat_cell_ring_hover.emission_energy_multiplier = 1.2

	# Sculpted Royal Walnut Perimeter Rails
	mat_walnut_rail = StandardMaterial3D.new()
	mat_walnut_rail.albedo_color = Color(0.24, 0.13, 0.07)
	mat_walnut_rail.metallic = 0.08
	mat_walnut_rail.roughness = 0.26
	mat_walnut_rail.clearcoat_enabled = true
	mat_walnut_rail.clearcoat = 0.75
	mat_walnut_rail.clearcoat_roughness = 0.14

	# Deep Obsidian-Emerald Slate Deck
	mat_obsidian_slate = StandardMaterial3D.new()
	mat_obsidian_slate.albedo_color = Color(0.10, 0.13, 0.16)
	mat_obsidian_slate.metallic = 0.22
	mat_obsidian_slate.roughness = 0.24
	mat_obsidian_slate.clearcoat_enabled = true
	mat_obsidian_slate.clearcoat = 0.65
	mat_obsidian_slate.clearcoat_roughness = 0.14

	# Polished Imperial Gold Inlays, Trims & Studs
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.95, 0.79, 0.28)
	mat_gold_trim.metallic = 0.92
	mat_gold_trim.roughness = 0.16
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.60

	# Dark Brushed Bronze-Gold Token Pedestal Base
	mat_piece_base = StandardMaterial3D.new()
	mat_piece_base.albedo_color = Color(0.18, 0.14, 0.10)
	mat_piece_base.metallic = 0.72
	mat_piece_base.roughness = 0.24
	mat_piece_base.clearcoat_enabled = true
	mat_piece_base.clearcoat = 0.65

	# Player 1 (X): Radiant Luxury Crimson Enamel & Ruby
	mat_piece_x = StandardMaterial3D.new()
	mat_piece_x.albedo_color = Color(0.92, 0.14, 0.22)
	mat_piece_x.metallic = 0.38
	mat_piece_x.roughness = 0.14
	mat_piece_x.rim_enabled = true
	mat_piece_x.rim = 0.55
	mat_piece_x.rim_tint = 0.45
	mat_piece_x.clearcoat_enabled = true
	mat_piece_x.clearcoat = 0.92
	mat_piece_x.clearcoat_roughness = 0.10

	mat_ruby_gem = StandardMaterial3D.new()
	mat_ruby_gem.albedo_color = Color(1.0, 0.18, 0.26)
	mat_ruby_gem.metallic = 0.45
	mat_ruby_gem.roughness = 0.10
	mat_ruby_gem.emission_enabled = true
	mat_ruby_gem.emission = Color(0.95, 0.12, 0.20)
	mat_ruby_gem.emission_energy_multiplier = 0.45

	# Player 2 (O): Royal Persian Sapphire Gemstone Torus
	mat_piece_o = StandardMaterial3D.new()
	mat_piece_o.albedo_color = Color(0.10, 0.46, 0.98)
	mat_piece_o.metallic = 0.32
	mat_piece_o.roughness = 0.12
	mat_piece_o.rim_enabled = true
	mat_piece_o.rim = 0.65
	mat_piece_o.rim_tint = 0.55
	mat_piece_o.clearcoat_enabled = true
	mat_piece_o.clearcoat = 0.95
	mat_piece_o.clearcoat_roughness = 0.10

	mat_sapphire_gem = StandardMaterial3D.new()
	mat_sapphire_gem.albedo_color = Color(0.18, 0.58, 1.0)
	mat_sapphire_gem.metallic = 0.45
	mat_sapphire_gem.roughness = 0.10
	mat_sapphire_gem.emission_enabled = true
	mat_sapphire_gem.emission = Color(0.12, 0.48, 0.96)
	mat_sapphire_gem.emission_energy_multiplier = 0.45

	# Elegant Glowing Laser Winning Strike
	mat_win_line = StandardMaterial3D.new()
	mat_win_line.albedo_color = Color(1.0, 0.92, 0.45)
	mat_win_line.emission_enabled = true
	mat_win_line.emission = Color(1.0, 0.82, 0.25)
	mat_win_line.emission_energy_multiplier = 3.0

func _build_royal_architecture() -> void:
	var arch_root = Node3D.new()
	arch_root.name = "RoyalArchitecture"
	add_child(arch_root)

	# 1. Raised Beveled Walnut Perimeter Walls framing the 1.08m x 1.08m arena
	var wall_len = 1.24
	var wall_thick = 0.068
	var wall_h = 0.022
	var wall_offset = 0.586
	for side in [
		{"pos": Vector3(0, 0.044, -wall_offset), "size": Vector3(wall_len, wall_h, wall_thick)},
		{"pos": Vector3(0, 0.044, wall_offset), "size": Vector3(wall_len, wall_h, wall_thick)},
		{"pos": Vector3(-wall_offset, 0.044, 0), "size": Vector3(wall_thick, wall_h, wall_len)},
		{"pos": Vector3(wall_offset, 0.044, 0), "size": Vector3(wall_thick, wall_h, wall_len)}
	]:
		var wall_mi = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = side["size"]
		bm.material = mat_walnut_rail
		wall_mi.mesh = bm
		wall_mi.position = side["pos"]
		arch_root.add_child(wall_mi)

	# 2. Continuous Imperial Gold Inner Perimeter Molding around the 3x3 Arena
	var trim_len = 1.11
	var trim_w = 0.014
	var trim_h = 0.012
	var trim_off = 0.548
	for t_side in [
		{"pos": Vector3(0, 0.054, -trim_off), "size": Vector3(trim_len, trim_h, trim_w)},
		{"pos": Vector3(0, 0.054, trim_off), "size": Vector3(trim_len, trim_h, trim_w)},
		{"pos": Vector3(-trim_off, 0.054, 0), "size": Vector3(trim_w, trim_h, trim_len)},
		{"pos": Vector3(trim_off, 0.054, 0), "size": Vector3(trim_w, trim_h, trim_len)}
	]:
		var trim_mi = MeshInstance3D.new()
		var tm = BoxMesh.new()
		tm.size = t_side["size"]
		tm.material = mat_gold_trim
		trim_mi.mesh = tm
		trim_mi.position = t_side["pos"]
		arch_root.add_child(trim_mi)

	# 3. Rosewood Sub-Grid Base Bars beneath the Gold Grid Lines for 3D Layered Depth
	var step = board_size / 3.0
	var g_off = step / 2.0
	for h_z in [-g_off, g_off]:
		var sub_h = MeshInstance3D.new()
		var sbm = BoxMesh.new()
		sbm.size = Vector3(1.076, 0.012, 0.036)
		sbm.material = mat_cell_frame
		sub_h.mesh = sbm
		sub_h.position = Vector3(0, 0.047, h_z)
		arch_root.add_child(sub_h)
	for v_x in [-g_off, g_off]:
		var sub_v = MeshInstance3D.new()
		var sbm = BoxMesh.new()
		sbm.size = Vector3(0.036, 0.012, 1.076)
		sbm.material = mat_cell_frame
		sub_v.mesh = sbm
		sub_v.position = Vector3(v_x, 0.047, 0)
		arch_root.add_child(sub_v)

	# 4. Jewel Cabochons & Concentric Rings on the 4 Grid Intersection Medallions + 8 Outer Grid End-Caps
	for mx in [-g_off, g_off]:
		for mz in [-g_off, g_off]:
			var ring_mi = MeshInstance3D.new()
			var tr = TorusMesh.new()
			tr.inner_radius = 0.024
			tr.outer_radius = 0.038
			tr.rings = 24
			tr.ring_segments = 24
			tr.material = mat_gold_trim
			ring_mi.mesh = tr
			ring_mi.position = Vector3(mx, 0.062, mz)
			arch_root.add_child(ring_mi)

			var gem_mi = MeshInstance3D.new()
			var sp = SphereMesh.new()
			sp.radius = 0.016
			sp.height = 0.016
			sp.material = mat_ruby_gem
			gem_mi.mesh = sp
			gem_mi.position = Vector3(mx, 0.064, mz)
			arch_root.add_child(gem_mi)

	# 8 Golden Grid End-Cap Studs where grid bars meet the perimeter molding
	var cap_positions = [
		Vector3(-g_off, 0.058, -0.535), Vector3(g_off, 0.058, -0.535),
		Vector3(-g_off, 0.058, 0.535), Vector3(g_off, 0.058, 0.535),
		Vector3(-0.535, 0.058, -g_off), Vector3(-0.535, 0.058, g_off),
		Vector3(0.535, 0.058, -g_off), Vector3(0.535, 0.058, g_off)
	]
	for c_pos in cap_positions:
		var cap_mi = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.016
		cyl.bottom_radius = 0.019
		cyl.height = 0.012
		cyl.material = mat_gold_trim
		cap_mi.mesh = cyl
		cap_mi.position = c_pos
		arch_root.add_child(cap_mi)

	# 5. Crowned Corner Finial Collars on all 4 Corners
	for cx in [-0.585, 0.585]:
		for cz in [-0.585, 0.585]:
			var collar = MeshInstance3D.new()
			var c_torus = TorusMesh.new()
			c_torus.inner_radius = 0.026
			c_torus.outer_radius = 0.042
			c_torus.rings = 24
			c_torus.ring_segments = 24
			c_torus.material = mat_gold_trim
			collar.mesh = c_torus
			collar.position = Vector3(cx, 0.054, cz)
			arch_root.add_child(collar)



func _generate_3d_board() -> void:
	var step = board_size / 3.0
	var half = board_size / 2.0

	cells.clear()
	cell_pads.clear()
	cell_rings.clear()
	cell_base_mats.clear()

	for i in range(9):
		var row = i / 3
		var col = i % 3
		var pos_x = (col * step) - half + (step / 2.0)
		var pos_z = (row * step) - half + (step / 2.0)

		var area = Area3D.new()
		area.name = "Cell_%d" % i
		area.position = Vector3(pos_x, 0.049, pos_z)

		# Collision box for hover detection
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(step * 0.94, 0.08, step * 0.94)
		col_shape.shape = box
		area.add_child(col_shape)

		# Outer Recessed Bronze Frame Pad
		var well_frame = MeshInstance3D.new()
		var wf_mesh = BoxMesh.new()
		wf_mesh.size = Vector3(step * 0.88, 0.005, step * 0.88)
		wf_mesh.material = mat_cell_frame
		well_frame.mesh = wf_mesh
		well_frame.position.y = -0.001
		area.add_child(well_frame)

		# Alternating Luxury Checkerboard Cell Inlay Pad (Cream-Ivory vs Roasted Walnut)
		var is_light_cell = ((row + col) % 2 == 0)
		var base_mat = mat_cell_light if is_light_cell else mat_cell_dark
		cell_base_mats.append(base_mat)

		var mesh_inst = MeshInstance3D.new()
		var plane_mesh = BoxMesh.new()
		plane_mesh.size = Vector3(step * 0.81, 0.007, step * 0.81)
		plane_mesh.material = base_mat
		mesh_inst.mesh = plane_mesh
		area.add_child(mesh_inst)
		cell_pads.append(mesh_inst)

		# Subtle Engraved Gold Target Ring on the Cell Pad
		var ring_inst = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.088
		torus.outer_radius = 0.096
		torus.rings = 28
		torus.ring_segments = 28
		torus.material = mat_cell_ring
		ring_inst.mesh = torus
		ring_inst.position.y = 0.004
		mesh_inst.add_child(ring_inst)
		cell_rings.append(ring_inst)

		# Center Throne Cell (Cell 4) gets an extra inner golden rosette ring
		if i == 4:
			var inner_rosette = MeshInstance3D.new()
			var r_torus = TorusMesh.new()
			r_torus.inner_radius = 0.036
			r_torus.outer_radius = 0.044
			r_torus.rings = 24
			r_torus.ring_segments = 24
			r_torus.material = mat_gold_trim
			inner_rosette.mesh = r_torus
			inner_rosette.position.y = 0.0042
			mesh_inst.add_child(inner_rosette)

		# 4 Delicate Corner Filigree Studs inside each Cell Pad
		var stud_off = step * 0.34
		for sx in [-stud_off, stud_off]:
			for sz in [-stud_off, stud_off]:
				var c_stud = MeshInstance3D.new()
				var s_cyl = CylinderMesh.new()
				s_cyl.top_radius = 0.008
				s_cyl.bottom_radius = 0.010
				s_cyl.height = 0.004
				s_cyl.material = mat_gold_trim
				c_stud.mesh = s_cyl
				c_stud.position = Vector3(sx, 0.0045, sz)
				mesh_inst.add_child(c_stud)

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
	var ring = cell_rings[cell_idx] if cell_idx < cell_rings.size() else null
	if is_hover and board_state[cell_idx] == 0 and GameManager.is_my_turn and not is_board_locked:
		pad.material_override = mat_cell_hover
		if ring:
			ring.material_override = mat_cell_ring_hover
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pad, "position:y", 0.006, 0.1)
	else:
		pad.material_override = null
		if ring:
			ring.material_override = null
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
	_set_cell_hover(cell_idx, false)

	print("[TicTacToe] Attempting move on cell %d as Player %d..." % [cell_idx, my_player_index])
	ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
	cell_clicked.emit(cell_idx)
	send_move(Commands.Select_Peace, cell_idx)

func on_piece_selected(user_id: int, target_peace: int, _extra: Dictionary = {}) -> void:
	if target_peace < 0 or target_peace >= 9:
		return

	print("[TicTacToe] Piece placed on cell %d by Player %d" % [target_peace, user_id])
	board_state[target_peace] = user_id
	_set_cell_hover(target_peace, false)
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

	var final_y: float = area.position.y + 0.025

	# Shared Royal Medallion Token Pedestal Base
	var pedestal = MeshInstance3D.new()
	var ped_cyl = CylinderMesh.new()
	ped_cyl.top_radius = 0.128
	ped_cyl.bottom_radius = 0.136
	ped_cyl.height = 0.010
	ped_cyl.radial_segments = 36
	ped_cyl.material = mat_piece_base
	pedestal.mesh = ped_cyl
	pedestal.position.y = -0.014
	piece_root.add_child(pedestal)

	var ped_rim = MeshInstance3D.new()
	var ped_torus = TorusMesh.new()
	ped_torus.inner_radius = 0.120
	ped_torus.outer_radius = 0.134
	ped_torus.rings = 32
	ped_torus.ring_segments = 32
	ped_torus.material = mat_gold_trim
	ped_rim.mesh = ped_torus
	ped_rim.position.y = -0.009
	piece_root.add_child(ped_rim)

	if user_id == 1:
		# P1: Royal Sculpted Crimson Ruby & Gold X Cross with Faceted Center Crown
		final_y = area.position.y + 0.025
		var cross_container = Node3D.new()

		var box1 = BoxMesh.new()
		box1.size = Vector3(0.228, 0.042, 0.048)
		box1.material = mat_piece_x

		var b1 = MeshInstance3D.new()
		b1.mesh = box1
		b1.rotation_degrees.y = 45.0
		cross_container.add_child(b1)

		var b2 = MeshInstance3D.new()
		b2.mesh = box1
		b2.rotation_degrees.y = -45.0
		cross_container.add_child(b2)

		# Golden spine inlay strips along the top of both X blades
		var gold_strip_mesh = BoxMesh.new()
		gold_strip_mesh.size = Vector3(0.205, 0.006, 0.014)
		gold_strip_mesh.material = mat_gold_trim

		var gs1 = MeshInstance3D.new()
		gs1.mesh = gold_strip_mesh
		gs1.position.y = 0.021
		gs1.rotation_degrees.y = 45.0
		cross_container.add_child(gs1)

		var gs2 = MeshInstance3D.new()
		gs2.mesh = gold_strip_mesh
		gs2.position.y = 0.021
		gs2.rotation_degrees.y = -45.0
		cross_container.add_child(gs2)

		# Center Golden Bezel Ring & Glowing Ruby Cabochon
		var center_bezel = MeshInstance3D.new()
		var cb_torus = TorusMesh.new()
		cb_torus.inner_radius = 0.018
		cb_torus.outer_radius = 0.030
		cb_torus.rings = 24
		cb_torus.ring_segments = 24
		cb_torus.material = mat_gold_trim
		center_bezel.mesh = cb_torus
		center_bezel.position.y = 0.023
		cross_container.add_child(center_bezel)

		var ruby_stud = MeshInstance3D.new()
		var sph_stud = SphereMesh.new()
		sph_stud.radius = 0.020
		sph_stud.height = 0.020
		sph_stud.material = mat_ruby_gem
		ruby_stud.mesh = sph_stud
		ruby_stud.position.y = 0.025
		cross_container.add_child(ruby_stud)

		piece_root.add_child(cross_container)
	else:
		# P2: Polished Royal Sapphire Gemstone Ring with Concentric Gold Crown & Center Medallion
		final_y = area.position.y + 0.0265
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.068
		torus.outer_radius = 0.118
		torus.rings = 36
		torus.ring_segments = 36
		torus.material = mat_piece_o
		ring.mesh = torus
		piece_root.add_child(ring)

		# Inner concentric gold inlay ring
		var inner_gold = MeshInstance3D.new()
		var torus_inner = TorusMesh.new()
		torus_inner.inner_radius = 0.058
		torus_inner.outer_radius = 0.072
		torus_inner.rings = 28
		torus_inner.ring_segments = 28
		torus_inner.material = mat_gold_trim
		inner_gold.mesh = torus_inner
		inner_gold.position.y = 0.004
		piece_root.add_child(inner_gold)

		# Center Sapphire Cabochon Jewel
		var center_sapphire = MeshInstance3D.new()
		var sap_sph = SphereMesh.new()
		sap_sph.radius = 0.024
		sap_sph.height = 0.018
		sap_sph.material = mat_sapphire_gem
		center_sapphire.mesh = sap_sph
		center_sapphire.position.y = 0.002
		piece_root.add_child(center_sapphire)

		# 4 Cardinal Gold Studs on top of the Sapphire Ring
		var r_mid = 0.093
		for stud_pos in [Vector3(r_mid, 0.016, 0), Vector3(-r_mid, 0.016, 0), Vector3(0, 0.016, r_mid), Vector3(0, 0.016, -r_mid)]:
			var c_stud = MeshInstance3D.new()
			var s_sph = SphereMesh.new()
			s_sph.radius = 0.010
			s_sph.height = 0.010
			s_sph.material = mat_gold_trim
			c_stud.mesh = s_sph
			c_stud.position = stud_pos
			piece_root.add_child(c_stud)

	# Elevated spawn position with physical squash & stretch drop animation (no hands in TicTacToe)
	piece_root.position = Vector3(area.position.x, final_y, area.position.z)
	add_child(piece_root)
	pieces_nodes[cell_idx] = piece_root

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
	var strike_y = cells[line_indices[1]].position.y + 0.048
	var p_start = Vector3(cells[line_indices[0]].position.x, strike_y, cells[line_indices[0]].position.z)
	var p_end = Vector3(cells[line_indices[2]].position.x, strike_y, cells[line_indices[2]].position.z)
	var p_mid = Vector3(cells[line_indices[1]].position.x, strike_y, cells[line_indices[1]].position.z)

	var dir = (p_end - p_start).normalized()
	var total_len = p_start.distance_to(p_end) + 0.24

	winning_line_node = Node3D.new()
	winning_line_node.name = "WinningLineStrike"

	var up = dir
	var ref = Vector3.UP
	if abs(up.dot(ref)) > 0.95:
		ref = Vector3.FORWARD
	var right = up.cross(ref).normalized()
	var fwd = right.cross(up).normalized()
	winning_line_node.transform = Transform3D(Basis(right, up, fwd), p_mid)

	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = total_len
	cyl.radial_segments = 24

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

	# Golden Finial Orbs at both ends of the Winning Line
	for end_y in [-total_len * 0.5, total_len * 0.5]:
		var orb = MeshInstance3D.new()
		var sp = SphereMesh.new()
		sp.radius = 0.032
		sp.height = 0.064
		sp.material = mat_gold_trim
		orb.mesh = sp
		orb.position = Vector3(0, end_y, 0)
		winning_line_node.add_child(orb)

	winning_line_node.scale = Vector3(0.01, 1.0, 0.01)
	add_child(winning_line_node)

	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(winning_line_node, "scale", Vector3.ONE, 0.45)
	AudioManager.play_sound("bell")

	ActionVFXManager.spawn_victory_celebration(self, p_mid, winner_user_id)

func on_turn_changed(_turn: int, _is_me: bool) -> void:
	for i in range(cells.size()):
		_set_cell_hover(i, false)

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	var timer = get_tree().create_timer(1.8)
	timer.timeout.connect(func():
		if is_instance_valid(self) and is_inside_tree():
			reset_board()
	)

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
			tw.finished.connect(func():
				if is_instance_valid(piece):
					piece.queue_free()
			)

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
