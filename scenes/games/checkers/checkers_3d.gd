extends BaseGameBoard

# Checkers 3D Game Controller & Board Logic
# Ported 1:1 from Flutter CheckersController & Python CheckersGameClass:
# - 8x8 luxury wooden board with algebraic coordinates (A-H, 1-8) and side graveyard trays
# - Authentic 3D lathe-turned ribbed checkers pucks with concentric grooves & 24K gold/platinum inlays
# - Promoted Super Pawns (Kings) feature double-stacked 3D checker pucks + sculpted 3D Royal Crown
# - Complete single-jump & multi-jump chaining (BFS check_move_list + back-pointer capture resolution)
# - Parabolic jump arcs, capture shockwaves, and promotion crown bursts

signal piece_moved(from_idx: int, to_idx: int, is_capture: bool)

const GRID_SIZE: int = 8
@export var board_size: float = 1.04
var cell_size: float = 0.13
var half_board: float = 0.52

# Camera preset for 3D mode (default view is 2D top-down per GAME_SCENE_RULES)
var camera_pitch: float = -0.88
var camera_distance: float = 3.05

# Board state: 64 dictionaries {"pawn_gamer_id": int, "is_super_pawn": bool}
# Indexing matches Flutter & Backend:
#   r_index = cell_idx % 8  (column 0..7)
#   c_index = cell_idx / 8  (row 0..7)
#   cell_idx = c_index * 8 + r_index
var board_data: Array[Dictionary] = []
var pieces_nodes: Dictionary = {} # cell_index -> Node3D

var player1_pawns: int = 12
var player2_pawns: int = 12

# Move generation state
# Each move item is a Dictionary:
#   {"target": Vector2i(r, c), "removed": Variant(Vector2i or null), "source": Variant(Vector2i or null)}
var current_possible_moves: Array[Dictionary] = []
var current_pieces_moves: Dictionary = {} # cell_idx -> Array[Dictionary]
var equipped_peace_index: int = -1
var last_click_time: float = 0.0
var _last_click_frame: int = -1

# Highlight & marker nodes
var cells: Array[Area3D] = []
var cell_pads: Array[MeshInstance3D] = []
var active_markers: Array[Node3D] = []
var last_move_markers: Array[Node3D] = []
var equipped_aura_node: Node3D = null
var notation_labels_root: Node3D = null

# Graveyard Trays for Captured Checkers (Side Racks)
var tray_red: Node3D = null
var tray_blue: Node3D = null
var captured_pieces_nodes: Array[Node3D] = []
var captured_red_count: int = 0
var captured_blue_count: int = 0

# Materials
var mat_cell_light: StandardMaterial3D
var mat_cell_dark: StandardMaterial3D
var mat_cell_hover: StandardMaterial3D
var mat_tray_wood: StandardMaterial3D
var mat_tray_velvet_red: StandardMaterial3D
var mat_tray_velvet_blue: StandardMaterial3D
var mat_piece_p1: StandardMaterial3D
var mat_piece_p1_well: StandardMaterial3D
var mat_piece_p2: StandardMaterial3D
var mat_piece_p2_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_felt_base: StandardMaterial3D
var mat_marker_move: StandardMaterial3D
var mat_marker_hit: StandardMaterial3D
var mat_marker_step: StandardMaterial3D
var mat_last_move: StandardMaterial3D

var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

func _ready() -> void:
	game_type = GameTypes.CHECKERS
	cell_size = board_size / float(GRID_SIZE)
	half_board = board_size / 2.0

	_setup_materials()
	_generate_3d_board()
	_create_graveyard_trays()
	_init_board_data()
	_spawn_all_pieces_on_board()
	update_board_orientation(GameManager.my_player_index)
	super._ready()

func _setup_materials() -> void:
	# Light Square: Luxurious Antique Maple / Sycamore Ivory Wood (Satin Hand-Rubbed Oil)
	mat_cell_light = StandardMaterial3D.new()
	mat_cell_light.albedo_color = Color(0.91, 0.86, 0.78)
	mat_cell_light.metallic = 0.0
	mat_cell_light.roughness = 0.62
	mat_cell_light.clearcoat_enabled = false

	# Dark Square: Rich Roasted Espresso Walnut / Rosewood (Playable Checkers Squares)
	mat_cell_dark = StandardMaterial3D.new()
	mat_cell_dark.albedo_color = Color(0.24, 0.14, 0.09)
	mat_cell_dark.metallic = 0.0
	mat_cell_dark.roughness = 0.58
	mat_cell_dark.clearcoat_enabled = false

	# Gentle golden radiance on hover
	mat_cell_hover = StandardMaterial3D.new()
	mat_cell_hover.albedo_color = Color(0.96, 0.82, 0.32, 0.85)
	mat_cell_hover.metallic = 0.4
	mat_cell_hover.roughness = 0.22
	mat_cell_hover.emission_enabled = true
	mat_cell_hover.emission = Color(0.92, 0.72, 0.22)
	mat_cell_hover.emission_energy_multiplier = 0.75

	# Polished 24K Royal Gold Inlay & Trim
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(1.0, 0.84, 0.32)
	mat_gold_trim.metallic = 0.95
	mat_gold_trim.roughness = 0.15
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.90
	mat_gold_trim.clearcoat_roughness = 0.05
	mat_gold_trim.emission_enabled = true
	mat_gold_trim.emission = Color(0.35, 0.26, 0.08)

	# Polished Platinum / Sterling Silver Trim
	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.94, 0.96, 1.0)
	mat_platinum_trim.metallic = 0.96
	mat_platinum_trim.roughness = 0.12
	mat_platinum_trim.clearcoat_enabled = true
	mat_platinum_trim.clearcoat = 0.92
	mat_platinum_trim.clearcoat_roughness = 0.04
	mat_platinum_trim.emission_enabled = true
	mat_platinum_trim.emission = Color(0.24, 0.26, 0.32)

	# Weighted Felt Base Pad (Tournament Green Baize)
	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.08, 0.18, 0.10)
	mat_felt_base.roughness = 0.96
	mat_felt_base.metallic = 0.0

	# Player 1 (Red / Host): Royal Carmine Mahogany Piano Lacquer
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.68, 0.11, 0.14)
	mat_piece_p1.metallic = 0.06
	mat_piece_p1.roughness = 0.24
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 0.65
	mat_piece_p1.clearcoat_roughness = 0.16

	# Player 1 Recessed Inner Dish (Deep Crimson Velvet-Wood)
	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.44, 0.06, 0.09)
	mat_piece_p1_well.metallic = 0.02
	mat_piece_p1_well.roughness = 0.42
	mat_piece_p1_well.clearcoat_enabled = true
	mat_piece_p1_well.clearcoat = 0.35

	# Player 2 (Blue / Guest): Midnight Lapis Cobalt Piano Lacquer
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.10, 0.20, 0.48)
	mat_piece_p2.metallic = 0.06
	mat_piece_p2.roughness = 0.24
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 0.65
	mat_piece_p2.clearcoat_roughness = 0.16

	# Player 2 Recessed Inner Dish (Deep Royal Navy Velvet-Wood)
	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.05, 0.11, 0.28)
	mat_piece_p2_well.metallic = 0.02
	mat_piece_p2_well.roughness = 0.42
	mat_piece_p2_well.clearcoat_enabled = true
	mat_piece_p2_well.clearcoat = 0.35

	# Side Graveyard Trays (Hardwood & Plush Velvet Lining)
	mat_tray_wood = StandardMaterial3D.new()
	mat_tray_wood.albedo_color = Color(0.22, 0.13, 0.08)
	mat_tray_wood.metallic = 0.02
	mat_tray_wood.roughness = 0.45

	mat_tray_velvet_red = StandardMaterial3D.new()
	mat_tray_velvet_red.albedo_color = Color(0.36, 0.08, 0.10)
	mat_tray_velvet_red.metallic = 0.0
	mat_tray_velvet_red.roughness = 0.88

	mat_tray_velvet_blue = StandardMaterial3D.new()
	mat_tray_velvet_blue.albedo_color = Color(0.08, 0.14, 0.32)
	mat_tray_velvet_blue.metallic = 0.0
	mat_tray_velvet_blue.roughness = 0.88

	# Normal Move Marker (Emerald Green glow disc)
	mat_marker_move = StandardMaterial3D.new()
	mat_marker_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_move.albedo_color = Color(0.20, 0.92, 0.45, 0.88)
	mat_marker_move.emission_enabled = true
	mat_marker_move.emission = Color(0.15, 0.95, 0.40)
	mat_marker_move.emission_energy_multiplier = 1.4

	# Jump / Capture Destination Marker (Crimson Target Ring)
	mat_marker_hit = StandardMaterial3D.new()
	mat_marker_hit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_hit.albedo_color = Color(1.0, 0.25, 0.25, 0.92)
	mat_marker_hit.emission_enabled = true
	mat_marker_hit.emission = Color(1.0, 0.18, 0.18)
	mat_marker_hit.emission_energy_multiplier = 2.0

	# Intermediate Multi-Jump Step Marker (Golden Amber Ring)
	mat_marker_step = StandardMaterial3D.new()
	mat_marker_step.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_step.albedo_color = Color(1.0, 0.84, 0.28, 0.88)
	mat_marker_step.emission_enabled = true
	mat_marker_step.emission = Color(1.0, 0.78, 0.20)
	mat_marker_step.emission_energy_multiplier = 1.6

	# Last Move Indicator
	mat_last_move = StandardMaterial3D.new()
	mat_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_last_move.albedo_color = Color(1.0, 0.88, 0.32, 0.45)
	mat_last_move.emission_enabled = true
	mat_last_move.emission = Color(0.95, 0.80, 0.25)
	mat_last_move.emission_energy_multiplier = 0.8

# --- 3D Board Generation (Matches Chess3D) ---

func _generate_3d_board() -> void:
	cells.clear()
	cell_pads.clear()

	for i in range(64):
		var c_idx = i / GRID_SIZE # row 0..7
		var r_idx = i % GRID_SIZE # col 0..7
		var pos_3d = get_cell_local_position(c_idx, r_idx)

		var area = Area3D.new()
		area.name = "Cell_%d" % i
		area.position = pos_3d

		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(cell_size * 0.96, 0.06, cell_size * 0.96)
		col_shape.shape = box
		col_shape.position.y = 0.03
		area.add_child(col_shape)

		# Playable Checkers squares have (c_idx + r_idx) % 2 == 0 -> Dark Walnut squares!
		var is_light = (c_idx + r_idx) % 2 == 1
		var mesh_inst = MeshInstance3D.new()
		var plane_mesh = BoxMesh.new()
		plane_mesh.size = Vector3(cell_size * 0.97, 0.008, cell_size * 0.97)
		plane_mesh.material = mat_cell_light if is_light else mat_cell_dark
		mesh_inst.mesh = plane_mesh
		area.add_child(mesh_inst)
		cell_pads.append(mesh_inst)

		var cell_idx = i
		# Single Source of Input: Clicks handled via Camera Raycast in _unhandled_input (Rule 4.2)
		area.mouse_entered.connect(func():
			_set_cell_hover(cell_idx, true)
		)
		area.mouse_exited.connect(func():
			_set_cell_hover(cell_idx, false)
		)

		add_child(area)
		cells.append(area)

func get_cell_local_position(c_idx: int, r_idx: int) -> Vector3:
	# Canonical local space:
	# c_idx 0 (Red / P1 home rows 0..2) is at local +Z (South, closest to P1)
	# c_idx 7 (Blue / P2 home rows 5..7) is at local -Z (North, closest to P2 when flipped 180)
	# r_idx 0 (File A) is at local -X (West)
	# r_idx 7 (File H) is at local +X (East)
	var pos_z = (half_board - cell_size / 2.0) - (c_idx * cell_size)
	var pos_x = (r_idx * cell_size) - half_board + (cell_size / 2.0)
	return Vector3(pos_x, 0.044, pos_z)

func update_board_orientation(player_index: int) -> void:
	my_player_index = player_index
	if my_player_index == 2:
		rotation_degrees.y = 180.0
	else:
		rotation_degrees.y = 0.0
	_spawn_coordinate_labels()
	_update_graveyard_tray_positions()
	_refresh_captured_pieces_positions()

func _set_cell_hover(cell_idx: int, is_hover: bool) -> void:
	if cell_idx < 0 or cell_idx >= cell_pads.size():
		return
	var pad = cell_pads[cell_idx]
	if is_hover and GameManager.is_my_turn and not is_board_locked:
		pad.material_override = mat_cell_hover
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pad, "position:y", 0.004, 0.1)
	else:
		pad.material_override = null
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pad, "position:y", 0.0, 0.1)

# --- Algebraic Coordinate Notations (A-H, 1-8) ---

func _spawn_coordinate_labels() -> void:
	var rot_z = 180.0 if my_player_index == 2 else 0.0

	if notation_labels_root and is_instance_valid(notation_labels_root):
		for child in notation_labels_root.get_children():
			if child is Label3D:
				child.rotation_degrees = Vector3(-90.0, 0.0, rot_z)
		return

	notation_labels_root = Node3D.new()
	notation_labels_root.name = "AlgebraicLabels"
	add_child(notation_labels_root)

	var files = ["A", "B", "C", "D", "E", "F", "G", "H"]
	var ranks = ["1", "2", "3", "4", "5", "6", "7", "8"]
	var font = preload("res://assets/fonts/Vazir.ttf")
	var label_color = Color(0.92, 0.82, 0.42, 0.95)
	var label_outline = Color(0.10, 0.06, 0.03, 0.95)

	for c in range(GRID_SIZE):
		var pos_x = (c * cell_size) - half_board + (cell_size / 2.0)
		var txt = files[c]

		var lbl_bot = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_bot.position = Vector3(pos_x, 0.043, half_board + 0.035)
		notation_labels_root.add_child(lbl_bot)

		var lbl_top = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_top.position = Vector3(pos_x, 0.043, -half_board - 0.035)
		notation_labels_root.add_child(lbl_top)

	for r in range(GRID_SIZE):
		var pos_z = (half_board - cell_size / 2.0) - (r * cell_size)
		var txt = ranks[r]

		var lbl_left = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_left.position = Vector3(-half_board - 0.035, 0.043, pos_z)
		notation_labels_root.add_child(lbl_left)

		var lbl_right = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_right.position = Vector3(half_board + 0.035, 0.043, pos_z)
		notation_labels_root.add_child(lbl_right)

func _create_3d_label(text: String, font: Font, col: Color, outline_col: Color, rot_z: float = 0.0) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = text
	lbl.font = font
	lbl.font_size = 22
	lbl.pixel_size = 0.0011
	lbl.modulate = col
	lbl.outline_modulate = outline_col
	lbl.outline_size = 3
	lbl.rotation_degrees = Vector3(-90.0, 0.0, rot_z)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

# --- Side Graveyard Trays for Captured Checkers ---

func _create_graveyard_trays() -> void:
	if tray_red and is_instance_valid(tray_red):
		tray_red.queue_free()
	if tray_blue and is_instance_valid(tray_blue):
		tray_blue.queue_free()

	tray_red = _build_single_graveyard_tray(1, "GraveyardTray_Red")
	add_child(tray_red)

	tray_blue = _build_single_graveyard_tray(2, "GraveyardTray_Blue")
	add_child(tray_blue)

	_update_graveyard_tray_positions()

func _build_single_graveyard_tray(gamer_id: int, node_name: String) -> Node3D:
	var root = Node3D.new()
	root.name = node_name

	var base = MeshInstance3D.new()
	var box_base = BoxMesh.new()
	box_base.size = Vector3(0.160, 0.020, 1.100)
	base.mesh = box_base
	base.material_override = mat_tray_wood
	root.add_child(base)

	var pad = MeshInstance3D.new()
	var box_pad = BoxMesh.new()
	box_pad.size = Vector3(0.136, 0.008, 1.060)
	pad.mesh = box_pad
	pad.material_override = mat_tray_velvet_red if gamer_id == 1 else mat_tray_velvet_blue
	pad.position.y = 0.010
	root.add_child(pad)

	for sx in [-1.0, 1.0]:
		var strip_z = MeshInstance3D.new()
		var box_sz = BoxMesh.new()
		box_sz.size = Vector3(0.004, 0.004, 1.060)
		strip_z.mesh = box_sz
		strip_z.material_override = mat_gold_trim
		strip_z.position = Vector3(sx * 0.068, 0.012, 0.0)
		root.add_child(strip_z)

	for sz in [-1.0, 1.0]:
		var strip_x = MeshInstance3D.new()
		var box_sx = BoxMesh.new()
		box_sx.size = Vector3(0.140, 0.004, 0.004)
		strip_x.mesh = box_sx
		strip_x.material_override = mat_gold_trim
		strip_x.position = Vector3(0.0, 0.012, sz * 0.530)
		root.add_child(strip_x)

	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var bracket = MeshInstance3D.new()
			var b_mesh = BoxMesh.new()
			b_mesh.size = Vector3(0.016, 0.006, 0.016)
			bracket.mesh = b_mesh
			bracket.material_override = mat_gold_trim
			bracket.position = Vector3(cx * 0.072, 0.014, cz * 0.540)
			root.add_child(bracket)

			var rivet = MeshInstance3D.new()
			var r_sph = SphereMesh.new()
			r_sph.radius = 0.003
			r_sph.height = 0.006
			rivet.mesh = r_sph
			rivet.material_override = mat_gold_trim
			rivet.position.y = 0.003
			bracket.add_child(rivet)

	var plaque = MeshInstance3D.new()
	plaque.name = "TrayPlaque"
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.024, 0.008, 0.080)
	plaque.mesh = p_mesh
	plaque.material_override = mat_gold_trim
	plaque.position = Vector3(0.080, 0.008, 0.0)
	root.add_child(plaque)

	var font = preload("res://assets/fonts/Vazir.ttf")
	var lbl = Label3D.new()
	lbl.name = "TrayLabel"
	lbl.text = "قرمز" if gamer_id == 1 else "آبی"
	lbl.font = font
	lbl.font_size = 18
	lbl.pixel_size = 0.0010
	lbl.modulate = Color(0.96, 0.84, 0.42, 0.95)
	lbl.outline_modulate = Color(0.12, 0.08, 0.04, 0.95)
	lbl.outline_size = 2
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.080, 0.014, 0.0)
	root.add_child(lbl)

	return root

func _update_graveyard_tray_positions() -> void:
	if not tray_red or not is_instance_valid(tray_red):
		return
	if not tray_blue or not is_instance_valid(tray_blue):
		return

	const TRAY_OFFSET_X = 0.765
	var rot_z = 180.0 if my_player_index == 2 else 0.0

	if my_player_index == 2:
		tray_red.position = Vector3(TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_red, 1.0, rot_z)
		tray_blue.position = Vector3(-TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_blue, -1.0, rot_z)
	else:
		tray_red.position = Vector3(-TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_red, -1.0, rot_z)
		tray_blue.position = Vector3(TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_blue, 1.0, rot_z)

func _orient_tray_decor(tray: Node3D, outer_sign: float, rot_z: float) -> void:
	if not is_instance_valid(tray):
		return
	var plaque = tray.get_node_or_null("TrayPlaque")
	if plaque:
		plaque.position.x = outer_sign * 0.080
	var lbl = tray.get_node_or_null("TrayLabel")
	if lbl and lbl is Label3D:
		lbl.position.x = outer_sign * 0.080
		lbl.rotation_degrees = Vector3(-90.0, 0.0, rot_z)

func get_captured_slot_position(captured_gamer_id: int, slot_idx: int) -> Vector3:
	var col_idx = slot_idx / 6
	var row_idx = slot_idx % 6

	var tray_center_x: float = 0.0
	var inner_dir_x: float = 0.0

	if my_player_index == 2:
		if captured_gamer_id == 1:
			tray_center_x = 0.765
			inner_dir_x = -1.0
		else:
			tray_center_x = -0.765
			inner_dir_x = 1.0
	else:
		if captured_gamer_id == 1:
			tray_center_x = -0.765
			inner_dir_x = 1.0
		else:
			tray_center_x = 0.765
			inner_dir_x = -1.0

	var col_offset_x = (0.034 if col_idx == 0 else -0.034) * inner_dir_x
	var slot_x = tray_center_x + col_offset_x

	var slot_z: float = 0.0
	if my_player_index == 2:
		slot_z = -0.400 + (row_idx * 0.160)
	else:
		slot_z = 0.400 - (row_idx * 0.160)

	return Vector3(slot_x, 0.024, slot_z)

func _place_captured_piece(piece_node: Node3D, captured_gamer_id: int, animate: bool = true) -> void:
	if not is_instance_valid(piece_node):
		return

	var slot_idx = captured_red_count if captured_gamer_id == 1 else captured_blue_count
	if captured_gamer_id == 1:
		captured_red_count += 1
	else:
		captured_blue_count += 1

	piece_node.set_meta("captured_gamer_id", captured_gamer_id)
	piece_node.set_meta("captured_slot_idx", slot_idx)
	piece_node.set_meta("cell_idx", -1)
	captured_pieces_nodes.append(piece_node)

	var target_pos = get_captured_slot_position(captured_gamer_id, slot_idx)
	var target_scale = Vector3(0.68, 0.68, 0.68)

	if animate:
		var start_pos = piece_node.position
		var mid_pos = (start_pos + target_pos) * 0.5 + Vector3(0.0, 0.24, 0.0)
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece_node, "scale", target_scale, 0.36)
		tw.parallel().tween_property(piece_node, "position", mid_pos, 0.18)
		tw.chain().tween_property(piece_node, "position", target_pos, 0.18).set_ease(Tween.EASE_IN)
	else:
		piece_node.position = target_pos
		piece_node.scale = target_scale

func _refresh_captured_pieces_positions() -> void:
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			var g_id = int(p.get_meta("captured_gamer_id", 1))
			var s_idx = int(p.get_meta("captured_slot_idx", 0))
			p.position = get_captured_slot_position(g_id, s_idx)

func _sync_captured_pieces() -> void:
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_pieces_nodes.clear()
	captured_red_count = 0
	captured_blue_count = 0

	var p1_remaining = 0
	var p2_remaining = 0
	for i in range(64):
		var g_id = int(board_data[i].get("pawn_gamer_id", 0))
		if g_id == 1:
			p1_remaining += 1
		elif g_id == 2:
			p2_remaining += 1

	player1_pawns = p1_remaining
	player2_pawns = p2_remaining

	var missing_p1 = clampi(12 - p1_remaining, 0, 12)
	var missing_p2 = clampi(12 - p2_remaining, 0, 12)

	for i in range(missing_p1):
		var cap_node = _build_3d_checker_piece(1, false)
		cap_node.name = "Captured_Red_%d" % i
		add_child(cap_node)
		_place_captured_piece(cap_node, 1, false)

	for i in range(missing_p2):
		var cap_node = _build_3d_checker_piece(2, false)
		cap_node.name = "Captured_Blue_%d" % i
		add_child(cap_node)
		_place_captured_piece(cap_node, 2, false)

# --- Coordinate Helpers (Matching Flutter & Backend 1:1) ---
# r_index = index % 8 (column 0..7)
# c_index = index / 8 (row 0..7)
# index = c_index * 8 + r_index

func index_to_coord(index: int) -> Vector2i:
	return Vector2i(index % GRID_SIZE, index / GRID_SIZE)

func coord_to_index(coord: Vector2i) -> int:
	return coord.y * GRID_SIZE + coord.x

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < GRID_SIZE and coord.y >= 0 and coord.y < GRID_SIZE

# --- Raycast Input Handling ---

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
				if dist <= 28.0 and elapsed < 0.65:
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
				if dist <= 28.0 and elapsed < 0.65:
					var now = Time.get_ticks_msec() / 1000.0
					if now - last_click_time >= 0.15:
						_raycast_board_click(event.position)

func _raycast_board_click(screen_pos: Vector2) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var board_y = global_position.y + 0.048
	if abs(ray_normal.y) < 0.0001:
		return
	var t = (board_y - ray_origin.y) / ray_normal.y
	if t < 0.0:
		return
	var hit_world = ray_origin + ray_normal * t
	var local_hit = to_local(hit_world)
	if abs(local_hit.x) > half_board or abs(local_hit.z) > half_board:
		return
	var c_idx = int((half_board - local_hit.z) / cell_size)
	var r_idx = int((local_hit.x + half_board) / cell_size)
	r_idx = clampi(r_idx, 0, GRID_SIZE - 1)
	c_idx = clampi(c_idx, 0, GRID_SIZE - 1)
	var cell_idx = c_idx * GRID_SIZE + r_idx
	_on_cell_clicked(cell_idx)

# --- Board Data Initialization (Matches initPeaces / add_pawns_to_board) ---

func _init_board_data() -> void:
	board_data.clear()
	for i in range(64):
		board_data.append({"pawn_gamer_id": 0, "is_super_pawn": false})

	# Player 1 (Red) 12 Pawns at indices: 0,2,4,6, 9,11,13,15, 16,18,20,22
	var p1_indices = [0, 2, 4, 6, 9, 11, 13, 15, 16, 18, 20, 22]
	for idx in p1_indices:
		board_data[idx] = {"pawn_gamer_id": 1, "is_super_pawn": false}

	# Player 2 (Blue) 12 Pawns at indices: 41,43,45,47, 48,50,52,54, 57,59,61,63
	var p2_indices = [41, 43, 45, 47, 48, 50, 52, 54, 57, 59, 61, 63]
	for idx in p2_indices:
		board_data[idx] = {"pawn_gamer_id": 2, "is_super_pawn": false}

	player1_pawns = 12
	player2_pawns = 12

# --- 3D Tournament Checkers Piece Builder ---

func _spawn_all_pieces_on_board() -> void:
	for p in pieces_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	pieces_nodes.clear()

	for i in range(64):
		var spot = board_data[i]
		var g_id = int(spot.get("pawn_gamer_id", 0))
		var is_super = bool(spot.get("is_super_pawn", false))
		if g_id != 0:
			_spawn_piece_at_cell(i, g_id, is_super)

func _spawn_piece_at_cell(cell_idx: int, gamer_id: int, is_super_pawn: bool) -> Node3D:
	var area = cells[cell_idx]
	var p_node = _build_3d_checker_piece(gamer_id, is_super_pawn)
	p_node.name = "Checker_%d_P%d" % [cell_idx, gamer_id]
	p_node.set_meta("cell_idx", cell_idx)
	p_node.set_meta("gamer_id", gamer_id)
	p_node.set_meta("is_super_pawn", is_super_pawn)
	p_node.position = Vector3(area.position.x, 0.048, area.position.z)
	add_child(p_node)
	pieces_nodes[cell_idx] = p_node
	return p_node

func _build_3d_checker_piece(gamer_id: int, is_super_pawn: bool) -> Node3D:
	var root = Node3D.new()
	root.set_meta("gamer_id", gamer_id)
	root.set_meta("is_super_pawn", is_super_pawn)

	var mat_main = mat_piece_p1 if gamer_id == 1 else mat_piece_p2
	var mat_well = mat_piece_p1_well if gamer_id == 1 else mat_piece_p2_well
	var mat_trim = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. Weighted Velvet Green Felt Base Pad
	var felt_pad = MeshInstance3D.new()
	felt_pad.name = "FeltBase"
	var cyl_felt = CylinderMesh.new()
	cyl_felt.top_radius = 0.045
	cyl_felt.bottom_radius = 0.045
	cyl_felt.height = 0.002
	cyl_felt.radial_segments = 36
	felt_pad.mesh = cyl_felt
	felt_pad.material_override = mat_felt_base
	felt_pad.position.y = 0.001
	root.add_child(felt_pad)

	# 2. Primary Lathe-Turned Ribbed Checker Puck (Bottom Puck)
	var disc1 = _build_single_checker_puck(mat_main, mat_well, mat_trim)
	disc1.name = "CheckerDisc1"
	disc1.position.y = 0.002
	root.add_child(disc1)

	# 3. If Promoted Super Pawn (King / شاه چکرز): Second Stacked Puck + 3D Royal Crown!
	if is_super_pawn:
		var king_stack = _build_king_stack_assembly(mat_main, mat_well, mat_trim)
		king_stack.name = "KingStackNode"
		king_stack.position.y = 0.021
		root.add_child(king_stack)

	return root

func _build_single_checker_puck(mat_main: StandardMaterial3D, mat_well: StandardMaterial3D, mat_trim: StandardMaterial3D) -> Node3D:
	var puck = Node3D.new()

	# Lower Beveled Gold/Platinum Plinth Ring
	var lower_ring = MeshInstance3D.new()
	var torus_low = TorusMesh.new()
	torus_low.inner_radius = 0.041
	torus_low.outer_radius = 0.0465
	torus_low.rings = 32
	torus_low.ring_segments = 24
	lower_ring.mesh = torus_low
	lower_ring.material_override = mat_trim
	lower_ring.position.y = 0.003
	puck.add_child(lower_ring)

	# Main Cylindrical Puck Body
	var body = MeshInstance3D.new()
	var cyl_body = CylinderMesh.new()
	cyl_body.top_radius = 0.0445
	cyl_body.bottom_radius = 0.0455
	cyl_body.height = 0.017
	cyl_body.radial_segments = 48
	body.mesh = cyl_body
	body.material_override = mat_main
	body.position.y = 0.009
	puck.add_child(body)

	# Recessed Inner Well (Classic Checkers Dish)
	var dish = MeshInstance3D.new()
	var cyl_dish = CylinderMesh.new()
	cyl_dish.top_radius = 0.036
	cyl_dish.bottom_radius = 0.036
	cyl_dish.height = 0.002
	cyl_dish.radial_segments = 36
	dish.mesh = cyl_dish
	dish.material_override = mat_well
	dish.position.y = 0.0172
	puck.add_child(dish)

	# Raised Outer Gripping Rim (Torus)
	var outer_rim = MeshInstance3D.new()
	var torus_rim = TorusMesh.new()
	torus_rim.inner_radius = 0.0355
	torus_rim.outer_radius = 0.045
	torus_rim.rings = 36
	torus_rim.ring_segments = 24
	outer_rim.mesh = torus_rim
	outer_rim.material_override = mat_main
	outer_rim.position.y = 0.0172
	puck.add_child(outer_rim)

	# 16 Radial Tactile Grip Ridges around Outer Rim (Authentic Ribbed Checkers Edge)
	var notch_mesh = BoxMesh.new()
	notch_mesh.size = Vector3(0.0032, 0.0035, 0.0075)
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		var notch = MeshInstance3D.new()
		notch.mesh = notch_mesh
		notch.material_override = mat_main
		var r_pos = 0.040
		notch.position = Vector3(r_pos * cos(angle), 0.0195, r_pos * sin(angle))
		notch.rotation.y = -angle + PI * 0.5
		puck.add_child(notch)

	# Concentric 24K Gold / Platinum Inlay Ring inside the Dish
	var mid_gold_ring = MeshInstance3D.new()
	var torus_mid = TorusMesh.new()
	torus_mid.inner_radius = 0.0235
	torus_mid.outer_radius = 0.0278
	torus_mid.rings = 32
	torus_mid.ring_segments = 20
	mid_gold_ring.mesh = torus_mid
	mid_gold_ring.material_override = mat_trim
	mid_gold_ring.position.y = 0.018
	puck.add_child(mid_gold_ring)

	# Inner Concentric Lacquer Ridge
	var inner_ridge = MeshInstance3D.new()
	var torus_in = TorusMesh.new()
	torus_in.inner_radius = 0.0125
	torus_in.outer_radius = 0.0185
	torus_in.rings = 28
	torus_in.ring_segments = 20
	inner_ridge.mesh = torus_in
	inner_ridge.material_override = mat_main
	inner_ridge.position.y = 0.0182
	puck.add_child(inner_ridge)

	# Center Medallion Boss (Gold / Platinum Star Medallion)
	var boss = MeshInstance3D.new()
	var cyl_boss = CylinderMesh.new()
	cyl_boss.top_radius = 0.0085
	cyl_boss.bottom_radius = 0.0095
	cyl_boss.height = 0.003
	cyl_boss.radial_segments = 24
	boss.mesh = cyl_boss
	boss.material_override = mat_trim
	boss.position.y = 0.0185
	puck.add_child(boss)

	return puck

func _build_king_stack_assembly(mat_main: StandardMaterial3D, mat_well: StandardMaterial3D, mat_trim: StandardMaterial3D) -> Node3D:
	var stack_root = Node3D.new()

	# Second Stacked Checker Puck ("King Me!" Double-Stack)
	var disc2 = _build_single_checker_puck(mat_main, mat_well, mat_trim)
	disc2.name = "CheckerDisc2"
	stack_root.add_child(disc2)

	# 3D Sculpted Royal Imperial Crown on top of the Second Puck
	var crown = _build_royal_crown_3d(mat_trim, mat_main)
	crown.name = "RoyalCrown"
	crown.position.y = 0.0195
	stack_root.add_child(crown)

	return stack_root

func _build_royal_crown_3d(mat_trim: StandardMaterial3D, mat_main: StandardMaterial3D) -> Node3D:
	var crown_root = Node3D.new()

	# 1. Golden Filigree Crown Base Band
	var base_band = MeshInstance3D.new()
	var torus_base = TorusMesh.new()
	torus_base.inner_radius = 0.018
	torus_base.outer_radius = 0.0235
	torus_base.rings = 28
	torus_base.ring_segments = 20
	base_band.mesh = torus_base
	base_band.material_override = mat_trim
	base_band.position.y = 0.002
	crown_root.add_child(base_band)

	# 2. Royal Velvet Inner Cushion Dome
	var cushion = MeshInstance3D.new()
	var sph_cush = SphereMesh.new()
	sph_cush.radius = 0.0175
	sph_cush.height = 0.014
	cushion.mesh = sph_cush
	cushion.material_override = mat_main
	cushion.position.y = 0.004
	crown_root.add_child(cushion)

	# 3. 8 Flared Crown Spires with Polished Pearl Finials
	var spire_mesh = CylinderMesh.new()
	spire_mesh.top_radius = 0.0012
	spire_mesh.bottom_radius = 0.0038
	spire_mesh.height = 0.014
	spire_mesh.radial_segments = 12

	var pearl_mesh = SphereMesh.new()
	pearl_mesh.radius = 0.0032
	pearl_mesh.height = 0.0064

	var ring_r = 0.0205
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var spire_pivot = Node3D.new()
		spire_pivot.position = Vector3(ring_r * cos(angle), 0.003, ring_r * sin(angle))
		spire_pivot.rotation.y = -angle
		# Flare outward slightly (15 deg) for a regal silhouette
		spire_pivot.rotation.z = deg_to_rad(-16.0)

		var spire = MeshInstance3D.new()
		spire.mesh = spire_mesh
		spire.material_override = mat_trim
		spire.position.y = 0.007
		spire_pivot.add_child(spire)

		var pearl = MeshInstance3D.new()
		pearl.mesh = pearl_mesh
		pearl.material_override = mat_trim
		pearl.position.y = 0.0145
		spire_pivot.add_child(pearl)

		crown_root.add_child(spire_pivot)

	# 4. Central Imperial Globus Orb at Crown Apex
	var center_pillar = MeshInstance3D.new()
	var cyl_pil = CylinderMesh.new()
	cyl_pil.top_radius = 0.0028
	cyl_pil.bottom_radius = 0.0045
	cyl_pil.height = 0.010
	center_pillar.mesh = cyl_pil
	center_pillar.material_override = mat_trim
	center_pillar.position.y = 0.011
	crown_root.add_child(center_pillar)

	var apex_orb = MeshInstance3D.new()
	var sph_apex = SphereMesh.new()
	sph_apex.radius = 0.0052
	sph_apex.height = 0.0104
	apex_orb.mesh = sph_apex
	apex_orb.material_override = mat_trim
	apex_orb.position.y = 0.0175
	crown_root.add_child(apex_orb)

	return crown_root

# --- Exact Checkers Rule Engine (Ported 1:1 from Flutter & Python Backend) ---

func is_target_peace_empty(r_index: int, c_index: int) -> bool:
	var idx = c_index * GRID_SIZE + r_index
	if idx < 0 or idx >= board_data.size():
		return false
	return int(board_data[idx].get("pawn_gamer_id", 0)) == 0

func is_target_peace_enemy(r_index: int, c_index: int, gamer_id: int) -> bool:
	var idx = c_index * GRID_SIZE + r_index
	if idx < 0 or idx >= board_data.size():
		return false
	var occupant = int(board_data[idx].get("pawn_gamer_id", 0))
	return occupant != 0 and occupant != gamer_id

func _get_right_pawn_move(r_index: int, c_index: int, gamer_id: int, direction: int, is_multi_move: bool, check_move_list: Array) -> Dictionary:
	var new_r: int = (r_index - 1) if direction == 1 else (r_index + 1)
	var new_c: int = (c_index + 1) if direction == 1 else (c_index - 1)
	var null_res = {"target": null, "removed": null, "source": null, "is_multi": false}

	if new_r < 0 or new_r > 7 or new_c < 0 or new_c > 7:
		return null_res

	if is_target_peace_empty(new_r, new_c) and not is_multi_move:
		return {
			"target": Vector2i(new_r, new_c),
			"removed": null,
			"source": null,
			"is_multi": false
		}
	elif is_target_peace_enemy(new_r, new_c, gamer_id):
		var new_r1: int = (new_r - 1) if direction == 1 else (new_r + 1)
		var new_c1: int = (new_c + 1) if direction == 1 else (new_c - 1)
		if new_r1 >= 0 and new_r1 <= 7 and new_c1 >= 0 and new_c1 <= 7 and is_target_peace_empty(new_r1, new_c1):
			check_move_list.append({
				"target": Vector2i(new_r1, new_c1),
				"removed": Vector2i(new_r, new_c),
				"source": Vector2i(r_index, c_index),
				"is_multi": true
			})
		return null_res
	return null_res

func _get_left_pawn_move(r_index: int, c_index: int, gamer_id: int, direction: int, is_multi_move: bool, check_move_list: Array) -> Dictionary:
	var new_r: int = (r_index + 1) if direction == 1 else (r_index - 1)
	var new_c: int = (c_index + 1) if direction == 1 else (c_index - 1)
	var null_res = {"target": null, "removed": null, "source": null, "is_multi": false}

	if new_r < 0 or new_r > 7 or new_c < 0 or new_c > 7:
		return null_res

	if is_target_peace_empty(new_r, new_c) and not is_multi_move:
		return {
			"target": Vector2i(new_r, new_c),
			"removed": null,
			"source": null,
			"is_multi": false
		}
	elif is_target_peace_enemy(new_r, new_c, gamer_id):
		var new_r1: int = (new_r + 1) if direction == 1 else (new_r - 1)
		var new_c1: int = (new_c + 1) if direction == 1 else (new_c - 1)
		if new_r1 >= 0 and new_r1 <= 7 and new_c1 >= 0 and new_c1 <= 7 and is_target_peace_empty(new_r1, new_c1):
			check_move_list.append({
				"target": Vector2i(new_r1, new_c1),
				"removed": Vector2i(new_r, new_c),
				"source": Vector2i(r_index, c_index),
				"is_multi": true
			})
		return null_res
	return null_res

func _get_direction_moves_list(r_index: int, c_index: int, gamer_id: int, direction: int) -> Array[Dictionary]:
	var temp_list: Array[Dictionary] = []
	var check_move_list: Array = []

	var right_res = _get_right_pawn_move(r_index, c_index, gamer_id, direction, false, check_move_list)
	var left_res = _get_left_pawn_move(r_index, c_index, gamer_id, direction, false, check_move_list)
	temp_list.append(right_res)
	temp_list.append(left_res)

	var safety_steps = 0
	while not check_move_list.is_empty() and safety_steps < 64:
		safety_steps += 1
		var current = check_move_list.pop_front()
		temp_list.append(current)
		if current["removed"] != null and current["target"] != null:
			var tgt: Vector2i = current["target"]
			var is_multi: bool = bool(current["is_multi"])
			var r_next = _get_right_pawn_move(tgt.x, tgt.y, gamer_id, direction, is_multi, check_move_list)
			var l_next = _get_left_pawn_move(tgt.x, tgt.y, gamer_id, direction, is_multi, check_move_list)
			check_move_list.append(r_next)
			check_move_list.append(l_next)

	return temp_list

func get_possible_moves_of_peace(r_index: int, c_index: int, gamer_id: int) -> Array[Dictionary]:
	var temp_list: Array[Dictionary] = []
	var result: Array[Dictionary] = []
	var idx = c_index * GRID_SIZE + r_index
	if idx < 0 or idx >= board_data.size():
		return result

	var is_super = bool(board_data[idx].get("is_super_pawn", false))
	if is_super:
		temp_list.append_array(_get_direction_moves_list(r_index, c_index, gamer_id, 1))
		temp_list.append_array(_get_direction_moves_list(r_index, c_index, gamer_id, 2))
	elif gamer_id == 1:
		temp_list.append_array(_get_direction_moves_list(r_index, c_index, gamer_id, 1))
	else:
		temp_list.append_array(_get_direction_moves_list(r_index, c_index, gamer_id, 2))

	for item in temp_list:
		if item["target"] != null:
			result.append(item)

	return result

func check_is_last_peace(c_index: int, gamer_id: int) -> bool:
	if gamer_id == 1:
		return c_index == 7
	else:
		return c_index == 0

func set_pieces_movements() -> void:
	current_pieces_moves.clear()
	if board_data.size() < 64:
		return
	for idx in range(64):
		if int(board_data[idx].get("pawn_gamer_id", 0)) == my_player_index:
			var coord = index_to_coord(idx)
			var moves = get_possible_moves_of_peace(coord.x, coord.y, my_player_index)
			if not moves.is_empty():
				current_pieces_moves[idx] = moves

# --- Interactive Turn Handling & Piece Selection ---

func _on_cell_clicked(cell_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked:
		return
	if not is_my_turn:
		show_hint("نوبتت نیست!")
		AudioManager.play_sound("miss_turn")
		return

	var now = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_click_frame or (now - last_click_time < 0.04):
		return
	_last_click_frame = current_frame
	last_click_time = now

	if current_pieces_moves.is_empty():
		set_pieces_movements()

	var spot = board_data[cell_idx]
	var occupant = int(spot.get("pawn_gamer_id", 0))

	if equipped_peace_index != -1:
		if equipped_peace_index == cell_idx:
			release_piece()
			AudioManager.play_sound("tap")
			return
		if occupant == my_player_index:
			release_piece()
			equip_piece(cell_idx)
			return

		# Check if cell_idx is a valid target move for equipped_peace_index
		var target_coord = index_to_coord(cell_idx)
		var is_valid_target = false
		for m in current_possible_moves:
			if m["target"] == target_coord:
				is_valid_target = true
				break

		if not is_valid_target:
			release_piece()
			show_hint("حرکت نامعتبر است!")
			AudioManager.play_sound("miss_turn")
			return

		var src_coord = index_to_coord(equipped_peace_index)
		var payload = {
			"s_c_index": src_coord.y,
			"s_r_index": src_coord.x,
			"t_c_index": target_coord.y,
			"t_r_index": target_coord.x
		}
		ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
		set_board_locked(true)
		send_move(Commands.Select_Peace, payload)
		release_piece()
	else:
		if occupant == my_player_index:
			equip_piece(cell_idx)
		elif occupant != 0:
			show_hint("این مهره شما نیست!")
			AudioManager.play_sound("miss_turn")

func equip_piece(cell_idx: int) -> void:
	var coord = index_to_coord(cell_idx)
	var moves = get_possible_moves_of_peace(coord.x, coord.y, my_player_index)
	if moves.is_empty():
		show_hint("این مهره حرکتی ندارد!")
		AudioManager.play_sound("miss_turn")
		return

	equipped_peace_index = cell_idx
	current_possible_moves = moves
	AudioManager.play_sound("tap")

	# Elevate equipped checker piece & spawn golden selection aura ring
	if pieces_nodes.has(cell_idx) and is_instance_valid(pieces_nodes[cell_idx]):
		var p_node = pieces_nodes[cell_idx]
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "position:y", 0.048 + 0.026, 0.16)

	_clear_markers()
	_spawn_equipped_aura(cell_idx)

	# Spawn destination & intermediate jump path markers
	var spawned_targets: Dictionary = {}
	var spawned_threatened: Dictionary = {}

	for m in current_possible_moves:
		var tgt_coord: Vector2i = m["target"]
		var tgt_idx = coord_to_index(tgt_coord)
		var is_jump = (m["removed"] != null)

		if not spawned_targets.has(tgt_idx):
			spawned_targets[tgt_idx] = is_jump
			_spawn_marker(tgt_idx, is_jump)

		# Highlight enemy pieces that will be jumped along this move
		if is_jump:
			var rem_coord: Vector2i = m["removed"]
			var rem_idx = coord_to_index(rem_coord)
			if not spawned_threatened.has(rem_idx):
				spawned_threatened[rem_idx] = true
				_spawn_threatened_enemy_marker(rem_idx)

func release_piece() -> void:
	if equipped_peace_index != -1:
		if pieces_nodes.has(equipped_peace_index) and is_instance_valid(pieces_nodes[equipped_peace_index]):
			var p_node = pieces_nodes[equipped_peace_index]
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(p_node, "position:y", 0.048, 0.12)
	equipped_peace_index = -1
	current_possible_moves.clear()
	_clear_markers()

func _spawn_equipped_aura(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	equipped_aura_node = Node3D.new()
	equipped_aura_node.name = "EquippedAura"
	equipped_aura_node.position = Vector3(area.position.x, 0.050, area.position.z)

	var mesh_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = cell_size * 0.36
	torus.outer_radius = cell_size * 0.44
	torus.rings = 28
	torus.ring_segments = 24
	torus.material = mat_marker_step
	mesh_inst.mesh = torus
	equipped_aura_node.add_child(mesh_inst)
	add_child(equipped_aura_node)
	active_markers.append(equipped_aura_node)

	var tw = equipped_aura_node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(equipped_aura_node, "scale", Vector3(1.12, 1.0, 1.12), 0.55)
	tw.tween_property(equipped_aura_node, "scale", Vector3(0.94, 1.0, 0.94), 0.55)

func _spawn_marker(cell_idx: int, is_jump: bool) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	var marker = Node3D.new()
	marker.name = "Marker_%d" % cell_idx
	marker.position = Vector3(area.position.x, 0.050, area.position.z)

	var mesh_inst = MeshInstance3D.new()
	if is_jump:
		# Glowing Crimson Capture Ring + Inner Bullseye Disc
		var torus = TorusMesh.new()
		torus.inner_radius = cell_size * 0.30
		torus.outer_radius = cell_size * 0.43
		torus.rings = 24
		torus.ring_segments = 24
		torus.material = mat_marker_hit
		mesh_inst.mesh = torus

		var inner_dot = MeshInstance3D.new()
		var cyl_dot = CylinderMesh.new()
		cyl_dot.top_radius = cell_size * 0.13
		cyl_dot.bottom_radius = cell_size * 0.13
		cyl_dot.height = 0.004
		cyl_dot.material = mat_marker_hit
		inner_dot.mesh = cyl_dot
		marker.add_child(inner_dot)
	else:
		var cyl = CylinderMesh.new()
		cyl.top_radius = cell_size * 0.18
		cyl.bottom_radius = cell_size * 0.18
		cyl.height = 0.004
		cyl.radial_segments = 24
		cyl.material = mat_marker_move
		mesh_inst.mesh = cyl

	marker.add_child(mesh_inst)
	add_child(marker)
	active_markers.append(marker)

	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", Vector3(1.15, 1.0, 1.15), 0.65)
	tw.tween_property(marker, "scale", Vector3(0.92, 1.0, 0.92), 0.65)

func _spawn_threatened_enemy_marker(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	var marker = Node3D.new()
	marker.name = "ThreatMarker_%d" % cell_idx
	marker.position = Vector3(area.position.x, 0.088, area.position.z)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = cell_size * 0.24
	torus.outer_radius = cell_size * 0.32
	torus.rings = 20
	torus.ring_segments = 20
	torus.material = mat_marker_hit
	ring.mesh = torus
	marker.add_child(ring)
	add_child(marker)
	active_markers.append(marker)

	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "position:y", 0.098, 0.45)
	tw.tween_property(marker, "position:y", 0.082, 0.45)

func _clear_markers() -> void:
	for m in active_markers:
		if is_instance_valid(m):
			m.queue_free()
	active_markers.clear()
	equipped_aura_node = null

# --- Server Event Execution & Multi-Jump Animations ---

func on_turn_changed(_turn: int, is_me: bool) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)
	release_piece()
	if is_me:
		set_pieces_movements()

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	if extra.is_empty():
		return
	var data = extra
	if extra.has("select_data") and typeof(extra["select_data"]) == TYPE_DICTIONARY:
		data = extra["select_data"]

	var s_c_index = int(data.get("s_c_index", -1))
	var s_r_index = int(data.get("s_r_index", -1))
	var t_c_index = int(data.get("t_c_index", -1))
	var t_r_index = int(data.get("t_r_index", -1))
	var gamer_id = int(data.get("gamer_id", user_id))

	if s_c_index == -1 or s_r_index == -1 or t_c_index == -1 or t_r_index == -1:
		return

	_execute_checkers_move(s_c_index, s_r_index, t_c_index, t_r_index, gamer_id)

func _execute_checkers_move(s_c_index: int, s_r_index: int, t_c_index: int, t_r_index: int, gamer_id: int) -> void:
	var src_coord = Vector2i(s_r_index, s_c_index)
	var tgt_coord = Vector2i(t_r_index, t_c_index)
	var src_idx = coord_to_index(src_coord)
	var tgt_idx = coord_to_index(tgt_coord)

	_update_last_move_highlights(src_idx, tgt_idx)

	# Compute legal moves from source square BEFORE mutating board_data
	# so we can trace the exact multi-jump chain and captured pawns!
	var moves = get_possible_moves_of_peace(s_r_index, s_c_index, gamer_id)
	var matched_move: Dictionary = {}
	for m in moves:
		if m["target"] == tgt_coord:
			matched_move = m
			break

	# Reconstruct ordered landing path and captured enemy coordinates (mirrors move_pawn in Backend/Flutter)
	var captured_coords: Array[Vector2i] = []
	var landing_coords: Array[Vector2i] = [tgt_coord]

	if not matched_move.is_empty() and matched_move["removed"] != null:
		var rem_pt = matched_move["removed"]
		var src_pt = matched_move["source"]
		var safety = 0
		while rem_pt != null and safety < 16:
			safety += 1
			captured_coords.push_front(rem_pt)
			rem_pt = null
			if src_pt != null and src_pt != src_coord:
				landing_coords.push_front(src_pt)
				for raw_m in moves:
					if raw_m["target"] == src_pt:
						rem_pt = raw_m["removed"]
						src_pt = raw_m["source"]
						break

	# Determine Super Pawn (King) state before & after move
	var was_super_pawn = bool(board_data[src_idx].get("is_super_pawn", false))
	var becomes_super_pawn = was_super_pawn or check_is_last_peace(t_c_index, gamer_id)
	var is_newly_promoted = (not was_super_pawn) and becomes_super_pawn

	# Immediately update authoritative board_data so state is 100% synchronized
	board_data[src_idx] = {"pawn_gamer_id": 0, "is_super_pawn": false}
	board_data[tgt_idx] = {"pawn_gamer_id": gamer_id, "is_super_pawn": becomes_super_pawn}

	for cap_coord in captured_coords:
		var cap_idx = coord_to_index(cap_coord)
		board_data[cap_idx] = {"pawn_gamer_id": 0, "is_super_pawn": false}
		if gamer_id == 1:
			player2_pawns = max(0, player2_pawns - 1)
		else:
			player1_pawns = max(0, player1_pawns - 1)

	# Retrieve or spawn moving 3D checker node
	var moving_node: Node3D = null
	if pieces_nodes.has(src_idx) and is_instance_valid(pieces_nodes[src_idx]):
		moving_node = pieces_nodes[src_idx]
		pieces_nodes.erase(src_idx)
	else:
		moving_node = _spawn_piece_at_cell(src_idx, gamer_id, was_super_pawn)
		pieces_nodes.erase(src_idx)

	# If destination accidentally had a lingering node, remove it
	if pieces_nodes.has(tgt_idx) and is_instance_valid(pieces_nodes[tgt_idx]) and pieces_nodes[tgt_idx] != moving_node:
		pieces_nodes[tgt_idx].queue_free()

	pieces_nodes[tgt_idx] = moving_node
	moving_node.set_meta("cell_idx", tgt_idx)
	moving_node.set_meta("is_super_pawn", becomes_super_pawn)

	# Animate multi-hop or single-hop parabolic trajectory across landing_coords
	var tw = create_tween()
	var prev_pos = moving_node.position
	var hop_count = landing_coords.size()

	for step_i in range(hop_count):
		var step_coord: Vector2i = landing_coords[step_i]
		var step_idx = coord_to_index(step_coord)
		var step_area = cells[step_idx]
		var step_final_pos = Vector3(step_area.position.x, 0.048, step_area.position.z)
		var is_jump_step = (step_i < captured_coords.size())
		var arc_height = 0.145 if is_jump_step else 0.085
		var step_mid_pos = (prev_pos + step_final_pos) * 0.5 + Vector3(0.0, arc_height, 0.0)

		# Upward leap to apex
		tw.tween_property(moving_node, "position", step_mid_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# At apex of jump, trigger capture VFX and launch jumped enemy checker into Graveyard Tray!
		if is_jump_step:
			var cap_coord_step: Vector2i = captured_coords[step_i]
			var cap_idx_step = coord_to_index(cap_coord_step)
			tw.tween_callback(func():
				_trigger_checker_capture(cap_idx_step, gamer_id)
			)

		# Downward landing onto square
		tw.tween_property(moving_node, "position", step_final_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			AudioManager.play_sound("hit")
			ActionVFXManager.spawn_piece_impact_vfx(self, step_final_pos, gamer_id)
		)
		prev_pos = step_final_pos

	tw.tween_callback(func():
		if is_newly_promoted:
			_animate_king_promotion(moving_node, tgt_idx, gamer_id)
		piece_moved.emit(src_idx, tgt_idx, not captured_coords.is_empty())
	)

func _trigger_checker_capture(cap_idx: int, attacker_gamer_id: int) -> void:
	var captured_gamer_id = 2 if attacker_gamer_id == 1 else 1
	var cap_pos = cells[cap_idx].position + Vector3(0.0, 0.048, 0.0) if (cap_idx >= 0 and cap_idx < cells.size()) else Vector3.ZERO

	AudioManager.play_sound("remove_peace")
	ActionVFXManager.spawn_piece_impact_vfx(self, cap_pos, attacker_gamer_id)
	_spawn_capture_shockwave_vfx(cap_pos, attacker_gamer_id)

	if pieces_nodes.has(cap_idx) and is_instance_valid(pieces_nodes[cap_idx]):
		var cap_node = pieces_nodes[cap_idx]
		pieces_nodes.erase(cap_idx)
		_place_captured_piece(cap_node, captured_gamer_id, true)

func _animate_king_promotion(piece_node: Node3D, cell_idx: int, gamer_id: int) -> void:
	if not is_instance_valid(piece_node):
		return
	if piece_node.has_node("KingStackNode"):
		return

	var mat_main = mat_piece_p1 if gamer_id == 1 else mat_piece_p2
	var mat_well = mat_piece_p1_well if gamer_id == 1 else mat_piece_p2_well
	var mat_trim = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	var king_stack = _build_king_stack_assembly(mat_main, mat_well, mat_trim)
	king_stack.name = "KingStackNode"
	# Start elevated above the checker and drop down with a royal bounce
	king_stack.position = Vector3(0.0, 0.16, 0.0)
	king_stack.scale = Vector3(0.2, 0.2, 0.2)
	piece_node.add_child(king_stack)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(king_stack, "position:y", 0.021, 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(king_stack, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	AudioManager.play_sound("bell")
	if cell_idx >= 0 and cell_idx < cells.size():
		_spawn_king_promotion_vfx(cells[cell_idx].position + Vector3(0.0, 0.052, 0.0))
	if gamer_id == my_player_index:
		show_hint("👑 ارتقا به شاه چکرز!")

# --- Custom 3D VFX (Capture Shockwave & King Promotion Crown Burst) ---

func _spawn_capture_shockwave_vfx(pos_3d: Vector3, attacker_gamer_id: int) -> void:
	var vfx_root = Node3D.new()
	vfx_root.position = pos_3d
	add_child(vfx_root)

	var ring_mat = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.32, 0.22, 0.92) if attacker_gamer_id == 1 else Color(0.28, 0.68, 1.0, 0.92)

	var ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.020
	torus.outer_radius = 0.032
	torus.rings = 24
	torus.ring_segments = 16
	torus.material = ring_mat
	ring_mesh.mesh = torus
	vfx_root.add_child(ring_mesh)

	# 8 radial 3D golden/crimson spark cubes
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.009, 0.009, 0.009)
	spark_mesh.material = ring_mat

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring_mesh, "scale", Vector3(2.8, 1.0, 2.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.35)

	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var sp = MeshInstance3D.new()
		sp.mesh = spark_mesh
		vfx_root.add_child(sp)
		var target_offset = Vector3(cos(angle) * 0.085, 0.045, sin(angle) * 0.085)
		tw.tween_property(sp, "position", target_offset, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector3(0.1, 0.1, 0.1), 0.32)

	tw.chain().tween_callback(func():
		if is_instance_valid(vfx_root):
			vfx_root.queue_free()
	)

func _spawn_king_promotion_vfx(pos_3d: Vector3) -> void:
	var vfx_root = Node3D.new()
	vfx_root.position = pos_3d
	add_child(vfx_root)

	var gold_mat = StandardMaterial3D.new()
	gold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold_mat.albedo_color = Color(1.0, 0.88, 0.28, 0.95)

	var ring1 = MeshInstance3D.new()
	var torus1 = TorusMesh.new()
	torus1.inner_radius = 0.030
	torus1.outer_radius = 0.042
	torus1.material = gold_mat
	ring1.mesh = torus1
	vfx_root.add_child(ring1)

	var ring2 = MeshInstance3D.new()
	ring2.mesh = torus1
	ring2.position.y = 0.015
	vfx_root.add_child(ring2)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring1, "scale", Vector3(2.6, 1.0, 2.6), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring2, "position:y", 0.14, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring2, "scale", Vector3(1.8, 1.0, 1.8), 0.48)
	tw.tween_property(gold_mat, "albedo_color:a", 0.0, 0.48)

	tw.chain().tween_callback(func():
		if is_instance_valid(vfx_root):
			vfx_root.queue_free()
	)

func _update_last_move_highlights(src_idx: int, tgt_idx: int) -> void:
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()

	for idx in [src_idx, tgt_idx]:
		if idx >= 0 and idx < cells.size():
			var area = cells[idx]
			var marker = MeshInstance3D.new()
			var plane = BoxMesh.new()
			plane.size = Vector3(cell_size * 0.96, 0.005, cell_size * 0.96)
			plane.material = mat_last_move
			marker.mesh = plane
			marker.position = Vector3(area.position.x, 0.049, area.position.z)
			add_child(marker)
			last_move_markers.append(marker)

# --- Lifecycle & Reconnect State Synchronization ---

func setup_board(game_data: Dictionary) -> void:
	reset_board()
	update_board_orientation(GameManager.my_player_index)
	super._ready()
	if game_data.has("board"):
		sync_board_state(game_data["board"])
	if is_my_turn:
		set_pieces_movements()

func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != 64:
		return
	update_board_orientation(GameManager.my_player_index)
	super._ready()
	var b_arr = new_board as Array
	_clear_markers()

	for i in range(64):
		var raw = b_arr[i]
		var g_id = 0
		var is_super = false
		if typeof(raw) == TYPE_DICTIONARY:
			g_id = int(raw.get("pawn_gamer_id", raw.get("gamer_id", 0)))
			is_super = bool(raw.get("is_super_pawn", false))
		board_data[i] = {"pawn_gamer_id": g_id, "is_super_pawn": is_super}

	_spawn_all_pieces_on_board()
	_sync_captured_pieces()
	if is_my_turn:
		set_pieces_movements()

func on_reconnect_data(payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("pawns_count") and typeof(g_data["pawns_count"]) == TYPE_ARRAY and (g_data["pawns_count"] as Array).size() >= 2:
			player1_pawns = int(g_data["pawns_count"][0])
			player2_pawns = int(g_data["pawns_count"][1])
	sync_turn_state()

func reset_board() -> void:
	_clear_markers()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_pieces_nodes.clear()
	captured_red_count = 0
	captured_blue_count = 0
	equipped_peace_index = -1
	current_possible_moves.clear()
	current_pieces_moves.clear()
	_init_board_data()
	_spawn_all_pieces_on_board()
	update_board_orientation(GameManager.my_player_index)

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	release_piece()

func on_new_round(_round_num: int) -> void:
	reset_board()

func cleanup_board() -> void:
	_clear_markers()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()
	for p in pieces_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	pieces_nodes.clear()
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_pieces_nodes.clear()
	captured_red_count = 0
	captured_blue_count = 0
	equipped_peace_index = -1
	current_possible_moves.clear()
	current_pieces_moves.clear()
	board_data.clear()
