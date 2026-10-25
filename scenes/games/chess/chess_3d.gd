class_name Chess3D
extends "res://scripts/games/base_game_board.gd"

# 3D Physical Chess Board for Cafe Fekr
# High-polish authentic tournament wooden chessboard with algebraic coordinates
# Genuine 3D Staunton pieces (Pawn, Rook, Knight, Bishop, Queen, King) with luxury Ruby & Sapphire lacquer
# Dual-layer input detection (Area3D + Camera Raycasting) and physical drop physics

signal cell_clicked(index: int)
signal piece_moved(from_idx: int, to_idx: int, is_capture: bool)
signal king_in_check(gamer_id: int, king_pos: Vector2i)

@export var board_size: float = 1.04 # 1.04m / 8 = 0.130m per square
@export var camera_pitch: float = -0.92 # -52.7 degrees: ideal angle for tall 3D chess pieces
@export var camera_distance: float = 3.32 # Comfortably frames board and side graveyard racks
@export var has_missed_turns_limit: bool = true
const GRID_SIZE: int = 8
var cell_size: float = 0.130
var half_board: float = 0.52

# Board Data State: 64 spots
# Each item: { "gamer_id": int, "name": String, "is_first_move": bool }
var board_data: Array = []
var pieces_nodes: Dictionary = {} # cell_index -> Node3D

var king1_position: Vector2i = Vector2i(0, 4)
var king2_position: Vector2i = Vector2i(7, 4)

# Legal moves caching
var current_pieces_moves: Dictionary = {} # cell_index -> Array[Vector2i]
var current_pieces_hits: Dictionary = {}  # cell_index -> Array[Vector2i]

var equipped_peace_index: int = -1
var last_click_time: float = 0.0

# Highlight & marker nodes
var cells: Array[Area3D] = []
var cell_pads: Array[MeshInstance3D] = []
var active_markers: Array[Node3D] = []
var last_move_markers: Array[Node3D] = []
var check_warning_marker: Node3D = null
var notation_labels_root: Node3D = null

# Graveyard Trays for Captured Pieces (Side Racks)
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
var mat_piece_p2: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_felt_base: StandardMaterial3D
var mat_marker_move: StandardMaterial3D
var mat_marker_hit: StandardMaterial3D
var mat_marker_check: StandardMaterial3D
var mat_last_move: StandardMaterial3D

# Preloaded Genuine 3D Staunton Meshes (.obj)
var piece_meshes: Dictionary = {}

func _ready() -> void:
	game_type = GameTypes.CHESS
	cell_size = board_size / float(GRID_SIZE)
	half_board = board_size / 2.0
	_load_3d_meshes()
	_setup_materials()
	_generate_3d_board()
	_create_graveyard_trays()
	_init_board_data()
	_spawn_all_pieces_on_board()
	update_board_orientation(GameManager.my_player_index)
	super._ready()

func _load_3d_meshes() -> void:
	piece_meshes["pawn"] = load("res://assets/models/chess/pawn.obj")
	piece_meshes["rook"] = load("res://assets/models/chess/rook.obj")
	piece_meshes["knight"] = load("res://assets/models/chess/knight.obj")
	piece_meshes["bishop"] = load("res://assets/models/chess/bishop.obj")
	piece_meshes["queen"] = load("res://assets/models/chess/queen.obj")
	piece_meshes["king"] = load("res://assets/models/chess/king.obj")

func _setup_materials() -> void:
	# Light Square: Luxurious Antique Maple / Sycamore Ivory Wood (Satin Hand-Rubbed Oil)
	mat_cell_light = StandardMaterial3D.new()
	mat_cell_light.albedo_color = Color(0.91, 0.86, 0.78)
	mat_cell_light.metallic = 0.0
	mat_cell_light.roughness = 0.62
	mat_cell_light.clearcoat_enabled = false # Soft diffuse satin finish: completely eliminates heavy light glare

	# Dark Square: Rich Roasted Espresso Walnut / Rosewood (Satin Hand-Rubbed Oil)
	mat_cell_dark = StandardMaterial3D.new()
	mat_cell_dark.albedo_color = Color(0.24, 0.14, 0.09)
	mat_cell_dark.metallic = 0.0
	mat_cell_dark.roughness = 0.60
	mat_cell_dark.clearcoat_enabled = false # Soft diffuse satin finish: completely eliminates heavy light glare

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
	mat_piece_p1.albedo_color = Color(0.60, 0.10, 0.13)
	mat_piece_p1.metallic = 0.04
	mat_piece_p1.roughness = 0.28
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 0.50
	mat_piece_p1.clearcoat_roughness = 0.20
	mat_piece_p1.rim_enabled = false

	# Player 2 (Blue / Guest): Midnight Lapis Cobalt Piano Lacquer
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.08, 0.16, 0.38)
	mat_piece_p2.metallic = 0.04
	mat_piece_p2.roughness = 0.26
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 0.50
	mat_piece_p2.clearcoat_roughness = 0.20
	mat_piece_p2.rim_enabled = false

	# Side Graveyard Trays (Hardwood & Plush Velvet Lining)
	mat_tray_wood = StandardMaterial3D.new()
	mat_tray_wood.albedo_color = Color(0.22, 0.13, 0.08)
	mat_tray_wood.metallic = 0.02
	mat_tray_wood.roughness = 0.45
	mat_tray_wood.clearcoat_enabled = false

	mat_tray_velvet_red = StandardMaterial3D.new()
	mat_tray_velvet_red.albedo_color = Color(0.36, 0.08, 0.10)
	mat_tray_velvet_red.metallic = 0.0
	mat_tray_velvet_red.roughness = 0.88
	mat_tray_velvet_red.clearcoat_enabled = false

	mat_tray_velvet_blue = StandardMaterial3D.new()
	mat_tray_velvet_blue.albedo_color = Color(0.08, 0.14, 0.32)
	mat_tray_velvet_blue.metallic = 0.0
	mat_tray_velvet_blue.roughness = 0.88
	mat_tray_velvet_blue.clearcoat_enabled = false

	# Move Marker (Emerald Green glow disc)
	mat_marker_move = StandardMaterial3D.new()
	mat_marker_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_move.albedo_color = Color(0.20, 0.92, 0.45, 0.88)
	mat_marker_move.emission_enabled = true
	mat_marker_move.emission = Color(0.15, 0.95, 0.40)
	mat_marker_move.emission_energy_multiplier = 1.4

	# Hit / Capture Marker (Crimson Target Ring)
	mat_marker_hit = StandardMaterial3D.new()
	mat_marker_hit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_hit.albedo_color = Color(1.0, 0.25, 0.25, 0.92)
	mat_marker_hit.emission_enabled = true
	mat_marker_hit.emission = Color(1.0, 0.18, 0.18)
	mat_marker_hit.emission_energy_multiplier = 2.0

	# Check (Kish) Warning Aura
	mat_marker_check = StandardMaterial3D.new()
	mat_marker_check.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_check.albedo_color = Color(1.0, 0.15, 0.15, 0.85)
	mat_marker_check.emission_enabled = true
	mat_marker_check.emission = Color(1.0, 0.1, 0.1)
	mat_marker_check.emission_energy_multiplier = 2.8

	# Last Move Indicator
	mat_last_move = StandardMaterial3D.new()
	mat_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_last_move.albedo_color = Color(1.0, 0.88, 0.32, 0.45)
	mat_last_move.emission_enabled = true
	mat_last_move.emission = Color(0.95, 0.80, 0.25)
	mat_last_move.emission_energy_multiplier = 0.8

# --- 3D Chess Board Generation ---

func _generate_3d_board() -> void:
	cells.clear()
	cell_pads.clear()

	for i in range(64):
		var row = i / GRID_SIZE
		var col = i % GRID_SIZE
		var pos_3d = get_cell_local_position(row, col)

		var area = Area3D.new()
		area.name = "Cell_%d" % i
		area.position = pos_3d

		# Single authoritative collision box for physics input on the board square
		var col_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(cell_size * 0.96, 0.06, cell_size * 0.96)
		col_shape.shape = box
		col_shape.position.y = 0.03
		area.add_child(col_shape)

		# Visual Wooden Inlay Square
		# Official tournament rule: Bottom-right corner (H1 or A8) is LIGHT ("White on right")
		# row 0, col 7: 0+7=7 (odd) -> Light!
		var is_light = (row + col) % 2 == 1
		var mesh_inst = MeshInstance3D.new()
		var plane_mesh = BoxMesh.new()
		plane_mesh.size = Vector3(cell_size * 0.97, 0.008, cell_size * 0.97)
		plane_mesh.material = mat_cell_light if is_light else mat_cell_dark
		mesh_inst.mesh = plane_mesh
		area.add_child(mesh_inst)
		cell_pads.append(mesh_inst)

		var cell_idx = i
		# Single Source of Input: Clicks are handled via Camera Raycast in _unhandled_input.
		# Area3D is strictly reserved for hover feedback to avoid duplicate click race conditions (Rule 4.2).
		area.mouse_entered.connect(func():
			_set_cell_hover(cell_idx, true)
		)
		area.mouse_exited.connect(func():
			_set_cell_hover(cell_idx, false)
		)

		add_child(area)
		cells.append(area)

func get_cell_local_position(row: int, col: int) -> Vector3:
	# Canonical local space:
	# Row 0 (Red / P1) is at local +Z (South)
	# Row 7 (Blue / P2) is at local -Z (North)
	# Col 0 (File A) is at local -X (West)
	# Col 7 (File H) is at local +X (East)
	var pos_z = (half_board - cell_size / 2.0) - (row * cell_size)
	var pos_x = (col * cell_size) - half_board + (cell_size / 2.0)
	return Vector3(pos_x, 0.044, pos_z)

func update_board_orientation(player_index: int) -> void:
	my_player_index = player_index
	if my_player_index == 2:
		# Player 2 (Blue): Rotate board 180 deg so Blue pieces sit in front of the player
		rotation_degrees.y = 180.0
	else:
		# Player 1 (Red): Default orientation with Red pieces in front
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
	var label_color = Color(0.92, 0.82, 0.42, 0.95) # Warm engraved gold
	var label_outline = Color(0.10, 0.06, 0.03, 0.95)

	# 1. Files along bottom and top borders
	for c in range(GRID_SIZE):
		var pos_x = (c * cell_size) - half_board + (cell_size / 2.0)
		var txt = files[c]

		# Bottom border
		var lbl_bot = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_bot.position = Vector3(pos_x, 0.043, half_board + 0.035)
		notation_labels_root.add_child(lbl_bot)

		# Top border
		var lbl_top = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_top.position = Vector3(pos_x, 0.043, -half_board - 0.035)
		notation_labels_root.add_child(lbl_top)

	# 2. Ranks along left and right borders
	for r in range(GRID_SIZE):
		var pos_z = (half_board - cell_size / 2.0) - (r * cell_size)
		var txt = ranks[r]

		# Left border
		var lbl_left = _create_3d_label(txt, font, label_color, label_outline, rot_z)
		lbl_left.position = Vector3(-half_board - 0.035, 0.043, pos_z)
		notation_labels_root.add_child(lbl_left)

		# Right border
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
	lbl.no_depth_test = false
	lbl.shaded = false
	return lbl

# --- Graveyard Trays for Captured Pieces (Side Racks) ---

func _create_graveyard_trays() -> void:
	if tray_red and is_instance_valid(tray_red):
		tray_red.queue_free()
	if tray_blue and is_instance_valid(tray_blue):
		tray_blue.queue_free()

	tray_red = _build_graveyard_tray(1)
	tray_red.name = "GraveyardTray_Red"
	add_child(tray_red)

	tray_blue = _build_graveyard_tray(2)
	tray_blue.name = "GraveyardTray_Blue"
	add_child(tray_blue)

	_update_graveyard_tray_positions()

func _build_graveyard_tray(gamer_id: int) -> Node3D:
	var root = Node3D.new()

	# 1. Outer Dark Mahogany Plinth Frame
	var frame = MeshInstance3D.new()
	frame.name = "TrayFrame"
	var box_frame = BoxMesh.new()
	box_frame.size = Vector3(0.160, 0.024, 1.100)
	frame.mesh = box_frame
	frame.material_override = mat_tray_wood
	root.add_child(frame)

	# 2. Recessed Velvet Cushion Pad (Crimson for Red, Cobalt for Blue)
	var pad = MeshInstance3D.new()
	pad.name = "VelvetPad"
	var box_pad = BoxMesh.new()
	box_pad.size = Vector3(0.136, 0.008, 1.060)
	pad.mesh = box_pad
	pad.material_override = mat_tray_velvet_red if gamer_id == 1 else mat_tray_velvet_blue
	pad.position.y = 0.010
	root.add_child(pad)

	# 3. Gold Trim Inlay Strips along Velvet Pad Edges
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

	# 4. Polished Brass Corner Brackets
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

	# 5. Front/Center Brass Plaque with Label
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
		# Player 2 view (board rotated 180 deg):
		# Local +X rotates to World -X (screen LEFT) -> Red Tray
		tray_red.position = Vector3(TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_red, 1.0, rot_z)

		# Local -X rotates to World +X (screen RIGHT) -> Blue Tray
		tray_blue.position = Vector3(-TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_blue, -1.0, rot_z)
	else:
		# Player 1 view (normal orientation 0 deg):
		# Local -X is World -X (screen LEFT) -> Red Tray
		tray_red.position = Vector3(-TRAY_OFFSET_X, 0.012, 0.0)
		_orient_tray_decor(tray_red, -1.0, rot_z)

		# Local +X is World +X (screen RIGHT) -> Blue Tray
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
	var col_idx = slot_idx / 8
	var row_idx = slot_idx % 8

	var tray_center_x: float = 0.0
	var inner_dir_x: float = 0.0

	if my_player_index == 2:
		if captured_gamer_id == 1:
			# Red Tray on screen LEFT -> local +X
			tray_center_x = 0.765
			inner_dir_x = -1.0
		else:
			# Blue Tray on screen RIGHT -> local -X
			tray_center_x = -0.765
			inner_dir_x = 1.0
	else:
		if captured_gamer_id == 1:
			# Red Tray on screen LEFT -> local -X
			tray_center_x = -0.765
			inner_dir_x = 1.0
		else:
			# Blue Tray on screen RIGHT -> local +X
			tray_center_x = 0.765
			inner_dir_x = -1.0

	# 2 parallel columns of 8:
	# col_idx 0 is inner (closer to board), col_idx 1 is outer (further from board)
	var col_offset_x = (0.034 if col_idx == 0 else -0.034) * inner_dir_x
	var slot_x = tray_center_x + col_offset_x

	var slot_z: float = 0.0
	if my_player_index == 2:
		slot_z = -0.455 + (row_idx * 0.130)
	else:
		slot_z = 0.455 - (row_idx * 0.130)

	var slot_y: float = 0.024
	return Vector3(slot_x, slot_y, slot_z)

func get_captured_slot_rotation(captured_gamer_id: int) -> Vector3:
	# Faces inward towards the board and slightly toward the viewing player
	if my_player_index == 2:
		if captured_gamer_id == 1:
			return Vector3(0.0, -115.0, 0.0)
		else:
			return Vector3(0.0, 115.0, 0.0)
	else:
		if captured_gamer_id == 1:
			return Vector3(0.0, 65.0, 0.0)
		else:
			return Vector3(0.0, -65.0, 0.0)

func _refresh_captured_pieces_positions() -> void:
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			var gid = int(p.get_meta("captured_gamer_id", 1))
			var slot = int(p.get_meta("captured_slot_idx", 0))
			p.position = get_captured_slot_position(gid, slot)
			p.rotation_degrees = get_captured_slot_rotation(gid)

func _place_captured_piece(captured_node: Node3D, captured_gamer_id: int) -> void:
	if not is_instance_valid(captured_node):
		return

	var slot_idx = 0
	if captured_gamer_id == 1:
		slot_idx = captured_red_count
		captured_red_count += 1
	else:
		slot_idx = captured_blue_count
		captured_blue_count += 1

	slot_idx = clampi(slot_idx, 0, 15)
	captured_pieces_nodes.append(captured_node)
	captured_node.set_meta("captured_gamer_id", captured_gamer_id)
	captured_node.set_meta("captured_slot_idx", slot_idx)

	var target_pos = get_captured_slot_position(captured_gamer_id, slot_idx)
	var target_rot = get_captured_slot_rotation(captured_gamer_id)
	var target_scale = Vector3(0.80, 0.80, 0.80)

	var start_pos = captured_node.position
	# Apex of parabolic arc: 35cm above the midpoint
	var mid_pos = (start_pos + target_pos) * 0.5 + Vector3(0.0, 0.35, 0.0)

	# Parallel tweens for trajectory, scale, and inward rotation
	var tw_pos = create_tween().set_trans(Tween.TRANS_QUAD)
	tw_pos.tween_property(captured_node, "position", mid_pos, 0.30).set_ease(Tween.EASE_OUT)
	tw_pos.tween_property(captured_node, "position", target_pos, 0.28).set_ease(Tween.EASE_IN)

	var tw_props = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_props.tween_property(captured_node, "scale", target_scale, 0.58)
	tw_props.tween_property(captured_node, "rotation_degrees", target_rot, 0.58)

	tw_pos.finished.connect(func():
		if is_instance_valid(captured_node):
			captured_node.position = target_pos
			captured_node.rotation_degrees = target_rot
			captured_node.scale = target_scale
			# Gentle settle landing bounce
			var tw_settle = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw_settle.tween_property(captured_node, "position:y", target_pos.y + 0.006, 0.06)
			tw_settle.tween_property(captured_node, "position:y", target_pos.y, 0.10)
			AudioManager.play_sound("hit")
	)

func _spawn_instant_captured_piece(gamer_id: int, piece_name: String) -> void:
	var slot_idx = 0
	if gamer_id == 1:
		slot_idx = captured_red_count
		captured_red_count += 1
	else:
		slot_idx = captured_blue_count
		captured_blue_count += 1

	slot_idx = clampi(slot_idx, 0, 15)
	var p_node = _build_3d_piece_mesh(gamer_id, piece_name, -1)
	p_node.name = "Captured_%d_%s_%d" % [gamer_id, piece_name, slot_idx]
	p_node.set_meta("captured_gamer_id", gamer_id)
	p_node.set_meta("captured_slot_idx", slot_idx)
	p_node.scale = Vector3(0.80, 0.80, 0.80)
	p_node.position = get_captured_slot_position(gamer_id, slot_idx)
	p_node.rotation_degrees = get_captured_slot_rotation(gamer_id)
	add_child(p_node)
	captured_pieces_nodes.append(p_node)

func _sync_captured_pieces() -> void:
	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_pieces_nodes.clear()
	captured_red_count = 0
	captured_blue_count = 0

	var initial_counts = {
		"Pawn": 8, "Rook": 2, "Knight": 2, "Bishop": 2, "Queen": 1, "King": 1
	}
	var red_on_board = {"Pawn": 0, "Rook": 0, "Knight": 0, "Bishop": 0, "Queen": 0, "King": 0}
	var blue_on_board = {"Pawn": 0, "Rook": 0, "Knight": 0, "Bishop": 0, "Queen": 0, "King": 0}

	for i in range(64):
		var spot = board_data[i]
		var gid = int(spot.get("gamer_id", 0))
		var pname = str(spot.get("name", ""))
		if gid == 1 and red_on_board.has(pname):
			red_on_board[pname] += 1
		elif gid == 2 and blue_on_board.has(pname):
			blue_on_board[pname] += 1

	var sort_order = ["Queen", "Rook", "Bishop", "Knight", "Pawn"]

	for pname in sort_order:
		var missing_red = initial_counts[pname] - red_on_board[pname]
		for _k in range(missing_red):
			_spawn_instant_captured_piece(1, pname)

	for pname in sort_order:
		var missing_blue = initial_counts[pname] - blue_on_board[pname]
		for _k in range(missing_blue):
			_spawn_instant_captured_piece(2, pname)

# --- Dual-Layer Input Handling (Area3D + Camera Raycasting) ---

var _cell_press_pos: Vector2 = Vector2.ZERO
var _cell_press_idx: int = -1
var _cell_press_time: float = 0.0
var _last_input_frame: int = -1
var _last_click_frame: int = -1

func _on_cell_input(cell_idx: int, event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_cell_press_pos = event.position
			_cell_press_idx = cell_idx
			_cell_press_time = Time.get_ticks_msec() / 1000.0
			get_viewport().set_input_as_handled()
		else:
			var target_cell = _cell_press_idx if _cell_press_idx != -1 else cell_idx
			_cell_press_idx = -1
			var dist = event.position.distance_to(_cell_press_pos)
			var elapsed = (Time.get_ticks_msec() / 1000.0) - _cell_press_time
			if dist <= 28.0 and elapsed < 0.65:
				var current_frame = Engine.get_process_frames()
				var now = Time.get_ticks_msec() / 1000.0
				if current_frame == _last_input_frame or (now - last_click_time < 0.04):
					return
				_last_input_frame = current_frame
				_raycast_is_down = false
				get_viewport().set_input_as_handled()
				_on_cell_clicked(target_cell)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_cell_press_pos = event.position
			_cell_press_idx = cell_idx
			_cell_press_time = Time.get_ticks_msec() / 1000.0
		else:
			var target_cell = _cell_press_idx if _cell_press_idx != -1 else cell_idx
			_cell_press_idx = -1
			var dist = event.position.distance_to(_cell_press_pos)
			var elapsed = (Time.get_ticks_msec() / 1000.0) - _cell_press_time
			if dist <= 28.0 and elapsed < 0.65:
				var current_frame = Engine.get_process_frames()
				var now = Time.get_ticks_msec() / 1000.0
				if current_frame == _last_input_frame or (now - last_click_time < 0.04):
					return
				_last_input_frame = current_frame
				_raycast_is_down = false
				get_viewport().set_input_as_handled()
				_on_cell_clicked(target_cell)

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

	var row = int((half_board - local_hit.z) / cell_size)
	var col = int((local_hit.x + half_board) / cell_size)

	col = clampi(col, 0, GRID_SIZE - 1)
	row = clampi(row, 0, GRID_SIZE - 1)

	var cell_idx = row * GRID_SIZE + col
	_on_cell_clicked(cell_idx)

# --- Board Data Initialization ---

func _init_board_data() -> void:
	board_data.clear()
	for i in range(64):
		board_data.append({"gamer_id": 0, "name": "", "is_first_move": true})

	var back_rank = ["Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook"]

	# Row 0: Player 1 (Red) Back Rank
	for c in range(8):
		board_data[c] = {"gamer_id": 1, "name": back_rank[c], "is_first_move": true}

	# Row 1: Player 1 Pawns
	for c in range(8):
		board_data[8 + c] = {"gamer_id": 1, "name": "Pawn", "is_first_move": true}

	# Row 6: Player 2 Pawns
	for c in range(8):
		board_data[48 + c] = {"gamer_id": 2, "name": "Pawn", "is_first_move": true}

	# Row 7: Player 2 (Blue) Back Rank
	for c in range(8):
		board_data[56 + c] = {"gamer_id": 2, "name": back_rank[c], "is_first_move": true}

	king1_position = Vector2i(0, 4)
	king2_position = Vector2i(7, 4)

func _spawn_all_pieces_on_board() -> void:
	for p_node in pieces_nodes.values():
		if is_instance_valid(p_node):
			p_node.queue_free()
	pieces_nodes.clear()

	for i in range(64):
		var spot = board_data[i]
		if spot["gamer_id"] != 0:
			_spawn_piece_at_cell(i, spot["gamer_id"], spot["name"])

func _spawn_piece_at_cell(cell_idx: int, gamer_id: int, piece_name: String) -> Node3D:
	if cell_idx < 0 or cell_idx >= cells.size():
		return null
	var area = cells[cell_idx]
	var p_node = _build_3d_piece_mesh(gamer_id, piece_name, cell_idx)
	p_node.name = "Piece_%d_%s" % [cell_idx, piece_name]
	p_node.set_meta("cell_idx", cell_idx)
	p_node.set_meta("gamer_id", gamer_id)
	p_node.set_meta("piece_name", piece_name)
	# Sits on the wooden square top surface at y = 0.048
	p_node.position = Vector3(area.position.x, 0.048, area.position.z)
	add_child(p_node)
	pieces_nodes[cell_idx] = p_node
	return p_node

# --- Genuine 3D Staunton Piece Instance Builder ---

func _build_3d_piece_mesh(gamer_id: int, piece_name: String, cell_idx: int = -1) -> Node3D:
	var root = Node3D.new()
	root.set_meta("gamer_id", gamer_id)
	root.set_meta("piece_name", piece_name)
	var key = piece_name.to_lower()
	var mat_main = mat_piece_p1 if gamer_id == 1 else mat_piece_p2
	var mat_trim = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. Main Genuine 3D Staunton Mesh (Loaded from .OBJ)
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "PieceBody"
	if piece_meshes.has(key) and piece_meshes[key] != null:
		mesh_inst.mesh = piece_meshes[key]
	else:
		var fallback_cyl = CylinderMesh.new()
		fallback_cyl.top_radius = 0.03
		fallback_cyl.bottom_radius = 0.04
		fallback_cyl.height = 0.08
		mesh_inst.mesh = fallback_cyl

	mesh_inst.material_override = mat_main

	# Knights: Grandmaster tournament inward 3/4 profile (~50 deg towards board center)
	# Both Queenside and Kingside knights showcase their magnificent arched neck, snout, eye, nostrils, and mane!
	if key == "knight":
		var col = cell_idx % GRID_SIZE if cell_idx != -1 else 1
		var inward_sign = 1.0 if col < 4 else -1.0
		if gamer_id == 1:
			mesh_inst.rotation_degrees.y = 180.0 - (inward_sign * 50.0)
		else:
			mesh_inst.rotation_degrees.y = (inward_sign * 50.0)

	root.add_child(mesh_inst)

	# 2. Tournament Weighted Velvet Green Felt Base Pad
	var felt_pad = MeshInstance3D.new()
	felt_pad.name = "FeltBase"
	var cyl_felt = CylinderMesh.new()
	cyl_felt.top_radius = 0.039
	cyl_felt.bottom_radius = 0.039
	cyl_felt.height = 0.002
	felt_pad.mesh = cyl_felt
	felt_pad.material_override = mat_felt_base
	felt_pad.position.y = 0.001
	root.add_child(felt_pad)

	# 3. Polished 24K Gold / Platinum Plinth Collar Ring on Base
	var gold_ring = MeshInstance3D.new()
	gold_ring.name = "PlinthRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.038
	torus.outer_radius = 0.043
	torus.rings = 28
	torus.ring_segments = 28
	gold_ring.mesh = torus
	gold_ring.material_override = mat_trim
	gold_ring.position.y = 0.012
	root.add_child(gold_ring)

	# 4. Piece-Specific Royal Metal Finial Ornaments
	if key == "king":
		var king_cross = _build_cross_pattee(mat_trim)
		king_cross.position.y = 0.138
		root.add_child(king_cross)
	elif key == "queen":
		var queen_coronet = _build_queen_coronet(mat_trim, mat_main)
		queen_coronet.position.y = 0.126
		root.add_child(queen_coronet)
	elif key == "bishop":
		var b_orb = MeshInstance3D.new()
		b_orb.name = "BishopOrb"
		var sph = SphereMesh.new()
		sph.radius = 0.0055
		sph.height = 0.011
		b_orb.mesh = sph
		b_orb.material_override = mat_trim
		b_orb.position.y = 0.130
		root.add_child(b_orb)
	elif key == "rook":
		var r_ring = MeshInstance3D.new()
		r_ring.name = "RookParapetRing"
		var torus_r = TorusMesh.new()
		torus_r.inner_radius = 0.035
		torus_r.outer_radius = 0.039
		torus_r.rings = 24
		torus_r.ring_segments = 24
		r_ring.mesh = torus_r
		r_ring.material_override = mat_trim
		r_ring.position.y = 0.082
		root.add_child(r_ring)

	return root

func _build_cross_pattee(mat_trim: StandardMaterial3D) -> Node3D:
	var cross_root = Node3D.new()
	cross_root.name = "KingCross"

	# 1. Globus Cruciger Base Orb (Polished 24K Gold / Platinum Sphere)
	var base_orb = MeshInstance3D.new()
	base_orb.name = "GlobusCruciger"
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.0085
	orb_mesh.height = 0.017
	base_orb.mesh = orb_mesh
	base_orb.material_override = mat_trim
	base_orb.position.y = 0.007
	cross_root.add_child(base_orb)

	# Astragal plinth ring beneath orb
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.006
	torus.outer_radius = 0.0095
	torus.rings = 18
	torus.ring_segments = 18
	ring.mesh = torus
	ring.material_override = mat_trim
	ring.position.y = 0.001
	cross_root.add_child(ring)

	# 2. Main 3D Flared Cross Pattée Post (Substantial volume in both X and Z)
	var v_bar = MeshInstance3D.new()
	v_bar.name = "CrossPillar"
	var v_box = BoxMesh.new()
	v_box.size = Vector3(0.008, 0.030, 0.008)
	v_bar.mesh = v_box
	v_bar.material_override = mat_trim
	v_bar.position.y = 0.021
	cross_root.add_child(v_bar)

	# Horizontal Primary Crossbeam (X axis)
	var h_bar_x = MeshInstance3D.new()
	h_bar_x.name = "CrossbeamX"
	var h_box_x = BoxMesh.new()
	h_box_x.size = Vector3(0.028, 0.008, 0.008)
	h_bar_x.mesh = h_box_x
	h_bar_x.material_override = mat_trim
	h_bar_x.position.y = 0.023
	cross_root.add_child(h_bar_x)

	# Depth Primary Crossbeam (Z axis) - ensures 3D prominence from ANY camera angle!
	var h_bar_z = MeshInstance3D.new()
	h_bar_z.name = "CrossbeamZ"
	var h_box_z = BoxMesh.new()
	h_box_z.size = Vector3(0.008, 0.008, 0.022)
	h_bar_z.mesh = h_box_z
	h_bar_z.material_override = mat_trim
	h_bar_z.position.y = 0.023
	cross_root.add_child(h_bar_z)

	# 3. Sculpted Flared Pattée Finials at Arm Terminations
	# Top Flared Finial
	var tip_top = MeshInstance3D.new()
	var box_t = BoxMesh.new()
	box_t.size = Vector3(0.014, 0.006, 0.012)
	tip_top.mesh = box_t
	tip_top.material_override = mat_trim
	tip_top.position.y = 0.036
	cross_root.add_child(tip_top)

	# Left/Right (X-axis) Flared Finials
	for sign_x in [-1.0, 1.0]:
		var tip_x = MeshInstance3D.new()
		var box_x = BoxMesh.new()
		box_x.size = Vector3(0.006, 0.014, 0.011)
		tip_x.mesh = box_x
		tip_x.material_override = mat_trim
		tip_x.position = Vector3(sign_x * 0.014, 0.023, 0.0)
		cross_root.add_child(tip_x)

	# Front/Back (Z-axis) Flared Finials - key for top-down & 50° player views!
	for sign_z in [-1.0, 1.0]:
		var tip_z = MeshInstance3D.new()
		var box_z = BoxMesh.new()
		box_z.size = Vector3(0.011, 0.014, 0.006)
		tip_z.mesh = box_z
		tip_z.material_override = mat_trim
		tip_z.position = Vector3(0.0, 0.023, sign_z * 0.011)
		cross_root.add_child(tip_z)

	# 4. Central Faceted Royal Diamond Boss
	var diamond = MeshInstance3D.new()
	diamond.name = "CenterDiamond"
	var d_box = BoxMesh.new()
	d_box.size = Vector3(0.010, 0.010, 0.010)
	diamond.mesh = d_box
	diamond.material_override = mat_trim
	diamond.position.y = 0.023
	diamond.rotation_degrees = Vector3(45.0, 45.0, 0.0)
	cross_root.add_child(diamond)

	return cross_root

func _build_queen_coronet(mat_trim: StandardMaterial3D, mat_main: StandardMaterial3D) -> Node3D:
	var coronet_root = Node3D.new()
	coronet_root.name = "QueenCoronet"

	# 1. Ring of 8 Polished Golden Pearls on Coronet Spire Tips
	# Forms a brilliant circular halo of 8 pearls seen clearly from above & at 50° pitch!
	var pearl_radius = 0.0385
	var pearl_mesh = SphereMesh.new()
	pearl_mesh.radius = 0.0055
	pearl_mesh.height = 0.011

	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var pearl = MeshInstance3D.new()
		pearl.name = "CoronetPearl_%d" % i
		pearl.mesh = pearl_mesh
		pearl.material_override = mat_trim
		pearl.position = Vector3(
			pearl_radius * cos(angle),
			0.006,
			pearl_radius * sin(angle)
		)
		coronet_root.add_child(pearl)

	# 2. Golden Filigree Ring connecting pearl bases
	var filigree = MeshInstance3D.new()
	filigree.name = "CoronetFiligree"
	var t_fil = TorusMesh.new()
	t_fil.inner_radius = 0.034
	t_fil.outer_radius = 0.038
	t_fil.rings = 24
	t_fil.ring_segments = 24
	filigree.mesh = t_fil
	filigree.material_override = mat_trim
	filigree.position.y = 0.001
	coronet_root.add_child(filigree)

	# 3. Inner Royal Velvet/Lacquer Dome
	var dome = MeshInstance3D.new()
	dome.name = "InnerDome"
	var sph_dome = SphereMesh.new()
	sph_dome.radius = 0.024
	sph_dome.height = 0.016
	dome.mesh = sph_dome
	dome.material_override = mat_main
	dome.position.y = 0.001
	coronet_root.add_child(dome)

	# 4. Central Royal Finial Pedestal & Large Polished Imperial Pearl Orb
	var center_stem = MeshInstance3D.new()
	var cyl_stem = CylinderMesh.new()
	cyl_stem.top_radius = 0.004
	cyl_stem.bottom_radius = 0.0065
	cyl_stem.height = 0.008
	center_stem.mesh = cyl_stem
	center_stem.material_override = mat_trim
	center_stem.position.y = 0.007
	coronet_root.add_child(center_stem)

	var center_orb = MeshInstance3D.new()
	center_orb.name = "CenterImperialOrb"
	var sph_center = SphereMesh.new()
	sph_center.radius = 0.008
	sph_center.height = 0.016
	center_orb.mesh = sph_center
	center_orb.material_override = mat_trim
	center_orb.position.y = 0.015
	coronet_root.add_child(center_orb)

	return coronet_root

# --- Chess Rules & Move Calculation Engine (Mirrors Flutter & Server) ---

func index_to_coord(idx: int) -> Vector2i:
	return Vector2i(idx / GRID_SIZE, idx % GRID_SIZE)

func coord_to_index(pos: Vector2i) -> int:
	return pos.x * GRID_SIZE + pos.y

func is_valid_coord(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE

func get_piece(pos: Vector2i) -> Dictionary:
	if not is_valid_coord(pos):
		return {"gamer_id": 0, "name": "", "is_first_move": false}
	var idx = coord_to_index(pos)
	if idx < 0 or idx >= board_data.size():
		return {"gamer_id": 0, "name": "", "is_first_move": false}
	return board_data[idx]

func is_target_empty(pos: Vector2i) -> bool:
	return get_piece(pos)["gamer_id"] == 0

func is_target_mine(pos: Vector2i, gamer_id: int) -> bool:
	return get_piece(pos)["gamer_id"] == gamer_id

func is_target_enemy(pos: Vector2i, gamer_id: int) -> bool:
	var g = get_piece(pos)["gamer_id"]
	return g != 0 and g != gamer_id

func get_possible_moves_of_piece(pos: Vector2i, gamer_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var piece = get_piece(pos)
	if piece["gamer_id"] == 0:
		return result

	var p_name = piece["name"]
	var is_first = piece.get("is_first_move", false)

	match p_name:
		"Pawn":
			var dir = 1 if gamer_id == 1 else -1
			var step1 = pos + Vector2i(dir, 0)
			if is_valid_coord(step1) and is_target_empty(step1):
				result.append(step1)
				if is_first:
					var step2 = pos + Vector2i(dir * 2, 0)
					if is_valid_coord(step2) and is_target_empty(step2):
						result.append(step2)

		"Knight":
			var jumps = [
				Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1),
				Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1)
			]
			for j in jumps:
				var target = pos + j
				if is_valid_coord(target) and is_target_empty(target):
					result.append(target)

		"Bishop":
			var dirs = [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if not is_target_empty(target):
						break
					result.append(target)
					i += 1

		"Rook":
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if not is_target_empty(target):
						break
					result.append(target)
					i += 1

		"Queen":
			var dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
			]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if not is_target_empty(target):
						break
					result.append(target)
					i += 1

		"King":
			var dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)
			]
			for d in dirs:
				var target = pos + d
				if is_valid_coord(target) and is_target_empty(target):
					result.append(target)

			# Castling moves
			if is_first:
				# King-side castle
				var k_side = pos + Vector2i(0, 2)
				if is_valid_coord(k_side) and is_target_empty(pos + Vector2i(0, 1)) and is_target_empty(k_side):
					result.append(k_side)
				# Queen-side castle
				var q_side = pos + Vector2i(0, -2)
				if is_valid_coord(q_side) and is_target_empty(pos + Vector2i(0, -1)) and is_target_empty(q_side):
					result.append(q_side)

	return result

func get_possible_hits_of_piece(pos: Vector2i, gamer_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var piece = get_piece(pos)
	if piece["gamer_id"] == 0:
		return result

	var p_name = piece["name"]

	match p_name:
		"Pawn":
			var dir = 1 if gamer_id == 1 else -1
			var hit_offsets = [Vector2i(dir, -1), Vector2i(dir, 1)]
			for offset in hit_offsets:
				var target = pos + offset
				if is_valid_coord(target) and is_target_enemy(target, gamer_id):
					result.append(target)

		"Knight":
			var jumps = [
				Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1),
				Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1)
			]
			for j in jumps:
				var target = pos + j
				if is_valid_coord(target) and is_target_enemy(target, gamer_id):
					result.append(target)

		"Bishop":
			var dirs = [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if is_target_enemy(target, gamer_id):
						result.append(target)
						break
					elif is_target_mine(target, gamer_id):
						break
					else:
						i += 1

		"Rook":
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if is_target_enemy(target, gamer_id):
						result.append(target)
						break
					elif is_target_mine(target, gamer_id):
						break
					else:
						i += 1

		"Queen":
			var dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
			]
			for d in dirs:
				var i = 1
				while true:
					var target = pos + d * i
					if not is_valid_coord(target):
						break
					if is_target_enemy(target, gamer_id):
						result.append(target)
						break
					elif is_target_mine(target, gamer_id):
						break
					else:
						i += 1

		"King":
			var dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)
			]
			for d in dirs:
				var target = pos + d
				if is_valid_coord(target) and is_target_enemy(target, gamer_id):
					result.append(target)

	return result

func get_possible_hits_with_changed_position(checker_pos: Vector2i, enemy_id: int, src_pos: Vector2i, tgt_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if checker_pos == tgt_pos:
		# Enemy piece was captured by this move; it cannot attack anything.
		return result
	var piece = get_piece(checker_pos)
	if piece["gamer_id"] == 0:
		return result

	var p_name = piece["name"]
	var is_multi = (p_name in ["Bishop", "Rook", "Queen"])

	var dirs: Array[Vector2i] = []
	match p_name:
		"Pawn":
			var dir = 1 if enemy_id == 1 else -1
			dirs = [Vector2i(dir, -1), Vector2i(dir, 1)]
		"Knight":
			dirs = [
				Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1),
				Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(-2, -1)
			]
		"Bishop":
			dirs = [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
		"Rook":
			dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		"Queen":
			dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)
			]
		"King":
			dirs = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, -1)
			]

	if is_multi:
		for d in dirs:
			var i = 1
			while true:
				var t = checker_pos + d * i
				if not is_valid_coord(t):
					break
				if t == src_pos:
					i += 1
				elif t == tgt_pos:
					result.append(t)
					break
				else:
					if is_target_enemy(t, enemy_id):
						result.append(t)
						break
					elif is_target_mine(t, enemy_id):
						break
					else:
						i += 1
	else:
		for d in dirs:
			var t = checker_pos + d
			if is_valid_coord(t):
				if t == src_pos:
					pass
				elif t == tgt_pos:
					result.append(t)
				else:
					if is_target_enemy(t, enemy_id):
						result.append(t)

	return result

func add_possible_moves(cell_idx: int, enemy_id: int, king_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var pos = index_to_coord(cell_idx)
	var enemy_pieces = get_enemy_positions(enemy_id)
	var moves = get_possible_moves_of_piece(pos, my_player_index)

	for new_pos in moves:
		var can_select = true
		var target_king_pos = new_pos if (king_pos == pos) else king_pos
		for check_pos in enemy_pieces:
			var raw_hits = get_possible_hits_with_changed_position(check_pos, enemy_id, pos, new_pos)
			if raw_hits.has(target_king_pos):
				can_select = false
				break
		if can_select:
			result.append(new_pos)

	return result

func add_possible_hits(cell_idx: int, enemy_id: int, king_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var pos = index_to_coord(cell_idx)
	var enemy_pieces = get_enemy_positions(enemy_id)
	var hits = get_possible_hits_of_piece(pos, my_player_index)

	for new_pos in hits:
		var can_select = true
		var target_king_pos = new_pos if (king_pos == pos) else king_pos
		for check_pos in enemy_pieces:
			var raw_hits = get_possible_hits_with_changed_position(check_pos, enemy_id, pos, new_pos)
			if raw_hits.has(target_king_pos):
				if new_pos == check_pos:
					result.append(new_pos)
					break
				can_select = false
				break
		if can_select:
			result.append(new_pos)

	return result

func get_enemy_positions(enemy_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(64):
		if board_data[i]["gamer_id"] == enemy_id:
			result.append(index_to_coord(i))
	return result

func get_my_pieces_indexes() -> Array[int]:
	var result: Array[int] = []
	if board_data.size() < 64:
		return result
	for i in range(64):
		if board_data[i]["gamer_id"] == my_player_index:
			result.append(i)
	return result

func set_pieces_movements() -> void:
	current_pieces_moves.clear()
	current_pieces_hits.clear()
	if board_data.size() < 64:
		return

	var my_pieces = get_my_pieces_indexes()
	var enemy_id = 2 if my_player_index == 1 else 1
	var king_pos = king1_position if my_player_index == 1 else king2_position

	# Ensure king_pos is valid; if not, search board_data
	if king_pos == Vector2i.ZERO or not is_valid_coord(king_pos):
		for i in range(64):
			if board_data[i]["gamer_id"] == my_player_index and board_data[i]["name"] == "King":
				king_pos = index_to_coord(i)
				if my_player_index == 1:
					king1_position = king_pos
				else:
					king2_position = king_pos
				break

	for idx in my_pieces:
		var moves = add_possible_moves(idx, enemy_id, king_pos)
		var hits = add_possible_hits(idx, enemy_id, king_pos)
		if not moves.is_empty():
			current_pieces_moves[idx] = moves
		if not hits.is_empty():
			current_pieces_hits[idx] = hits

func get_king_checks(gamer_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if board_data.size() < 64:
		return result
	var target_king = king1_position if gamer_id == 1 else king2_position
	var enemy_id = 2 if gamer_id == 1 else 1

	for i in range(64):
		var pos = index_to_coord(i)
		if is_target_mine(pos, enemy_id):
			var hits = get_possible_hits_of_piece(pos, enemy_id)
			if hits.has(target_king):
				result.append(pos)
	return result

# --- Interactive Turn Handling & Equipping Pieces ---

func _on_cell_clicked(cell_idx: int) -> void:
	if not GameManager.is_game_active:
		print("[Chess3D] Move rejected: Game is not started yet!")
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return

	if is_board_locked:
		print("[Chess3D] Click ignored: Board is locked waiting for server ACK")
		return

	if not is_my_turn:
		print("[Chess3D] Click rejected: Not my turn!")
		show_hint("نوبتت نیست!")
		AudioManager.play_sound("miss_turn")
		return

	var now = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_click_frame or (now - last_click_time < 0.04):
		return
	_last_click_frame = current_frame
	last_click_time = now

	# Ensure pieces moves are populated on active turn
	if current_pieces_moves.is_empty() and current_pieces_hits.is_empty():
		set_pieces_movements()

	var pos = index_to_coord(cell_idx)
	var spot = board_data[cell_idx]
	if equipped_peace_index != -1:
		# If clicking the currently equipped piece again, release it
		if equipped_peace_index == cell_idx:
			release_piece()
			AudioManager.play_sound("tap")
			return

		# If clicking another friendly piece, equip that one instead
		if spot["gamer_id"] == my_player_index:
			release_piece()
			equip_piece(cell_idx)
			return

		# Otherwise, check if clicked cell is a valid move or hit target
		var is_valid_move = current_pieces_moves.has(equipped_peace_index) and current_pieces_moves[equipped_peace_index].has(pos)
		var is_valid_hit = current_pieces_hits.has(equipped_peace_index) and current_pieces_hits[equipped_peace_index].has(pos)

		if not is_valid_move and not is_valid_hit:
			release_piece()
			show_hint("حرکت نامعتبر است!")
			AudioManager.play_sound("miss_turn")
			return

		# Dispatch move command to server
		var src_coord = index_to_coord(equipped_peace_index)
		var tgt_coord = pos
		var payload = {
			"s_c_index": src_coord.x,
			"s_r_index": src_coord.y,
			"t_c_index": tgt_coord.x,
			"t_r_index": tgt_coord.y
		}
		print("[Chess3D] Sending move: %s -> %s" % [str(src_coord), str(tgt_coord)])
		ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
		set_board_locked(true)
		send_move(Commands.Select_Peace, payload)
		release_piece()
	else:
		# No piece equipped: equip piece if it belongs to me
		if spot["gamer_id"] == my_player_index:
			equip_piece(cell_idx)
		elif spot["gamer_id"] != 0:
			show_hint("این مهره شما نیست!")
			AudioManager.play_sound("miss_turn")

func equip_piece(cell_idx: int) -> void:
	if not current_pieces_moves.has(cell_idx) and not current_pieces_hits.has(cell_idx):
		# No legal moves for this piece
		show_hint("این مهره حرکتی ندارد!")
		AudioManager.play_sound("miss_turn")
		return

	equipped_peace_index = cell_idx
	AudioManager.play_sound("tap")

	# Slightly elevate equipped piece
	if pieces_nodes.has(cell_idx) and is_instance_valid(pieces_nodes[cell_idx]):
		var p_node = pieces_nodes[cell_idx]
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "position:y", 0.048 + 0.024, 0.12)

	_clear_markers()

	# Spawn move markers (green dots)
	if current_pieces_moves.has(cell_idx):
		for tgt_pos in current_pieces_moves[cell_idx]:
			var tgt_idx = coord_to_index(tgt_pos)
			_spawn_marker(tgt_idx, false)

	# Spawn hit markers (crimson target rings)
	if current_pieces_hits.has(cell_idx):
		for tgt_pos in current_pieces_hits[cell_idx]:
			var tgt_idx = coord_to_index(tgt_pos)
			_spawn_marker(tgt_idx, true)

func release_piece() -> void:
	if equipped_peace_index != -1:
		if pieces_nodes.has(equipped_peace_index) and is_instance_valid(pieces_nodes[equipped_peace_index]):
			var p_node = pieces_nodes[equipped_peace_index]
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(p_node, "position:y", 0.048, 0.1)

	equipped_peace_index = -1
	_clear_markers()

func _spawn_marker(cell_idx: int, is_hit: bool) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	var marker = Node3D.new()
	marker.name = "Marker_%d" % cell_idx
	marker.position = Vector3(area.position.x, 0.050, area.position.z)

	var mesh_inst = MeshInstance3D.new()
	if is_hit:
		var torus = TorusMesh.new()
		torus.inner_radius = cell_size * 0.32
		torus.outer_radius = cell_size * 0.44
		torus.rings = 24
		torus.ring_segments = 24
		torus.material = mat_marker_hit
		mesh_inst.mesh = torus
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

	# Breathing pulse tween
	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", Vector3(1.15, 1.0, 1.15), 0.7)
	tw.tween_property(marker, "scale", Vector3(0.92, 1.0, 0.92), 0.7)

func _clear_markers() -> void:
	for m in active_markers:
		if is_instance_valid(m):
			m.queue_free()
	active_markers.clear()

# --- Server Event Execution & Move Animations ---

func on_turn_changed(turn: int, is_me: bool) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)
	release_piece()
	if is_me:
		set_pieces_movements()

	# Check if King is in check
	_update_king_check_status(turn)

func _update_king_check_status(turn: int) -> void:
	if check_warning_marker and is_instance_valid(check_warning_marker):
		check_warning_marker.queue_free()
		check_warning_marker = null

	var checks = get_king_checks(turn)
	if not checks.is_empty():
		var king_pos = king1_position if turn == 1 else king2_position
		var king_idx = coord_to_index(king_pos)
		_spawn_check_marker(king_idx)
		king_in_check.emit(turn, king_pos)

		if turn == my_player_index:
			show_hint("⚠️ کیش شدید!")
			AudioManager.play_sound("bell")
		else:
			show_hint("⚡ حریف کیش شد!")
			AudioManager.play_sound("bell")

func _spawn_check_marker(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	check_warning_marker = Node3D.new()
	check_warning_marker.name = "KingCheckMarker"
	check_warning_marker.position = Vector3(area.position.x, 0.050, area.position.z)

	var mesh_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = cell_size * 0.38
	torus.outer_radius = cell_size * 0.46
	torus.rings = 24
	torus.ring_segments = 24
	torus.material = mat_marker_check
	mesh_inst.mesh = torus
	check_warning_marker.add_child(mesh_inst)
	add_child(check_warning_marker)

	var tw = check_warning_marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(check_warning_marker, "scale", Vector3(1.2, 1.0, 1.2), 0.4)
	tw.tween_property(check_warning_marker, "scale", Vector3(0.95, 1.0, 0.95), 0.4)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	if extra.is_empty():
		return

	var data = extra
	if extra.has("select_data") and typeof(extra["select_data"]) == TYPE_DICTIONARY:
		data = extra["select_data"]

	var s_row = int(data.get("s_c_index", -1))
	var s_col = int(data.get("s_r_index", -1))
	var t_row = int(data.get("t_c_index", -1))
	var t_col = int(data.get("t_r_index", -1))
	var move_type = str(data.get("type", "move"))

	if s_row == -1 or s_col == -1 or t_row == -1 or t_col == -1:
		return

	var src_coord = Vector2i(s_row, s_col)
	var tgt_coord = Vector2i(t_row, t_col)
	var src_idx = coord_to_index(src_coord)
	var tgt_idx = coord_to_index(tgt_coord)

	print("[Chess3D] Move confirmed by server: P%d %s -> %s (Type: %s)" % [user_id, str(src_coord), str(tgt_coord), move_type])
	_execute_move_animation(src_idx, tgt_idx, user_id, move_type == "hit")

func _execute_move_animation(src_idx: int, tgt_idx: int, user_id: int, is_hit: bool) -> void:
	_update_last_move_highlights(src_idx, tgt_idx)

	var src_spot = board_data[src_idx]
	var tgt_spot = board_data[tgt_idx]
	var piece_name = src_spot["name"]
	var src_coord = index_to_coord(src_idx)
	var tgt_coord = index_to_coord(tgt_idx)

	# 1. Update Board Data immediately so state is synchronously in sync with server
	board_data[tgt_idx] = {
		"gamer_id": user_id,
		"name": piece_name,
		"is_first_move": false
	}
	board_data[src_idx] = {"gamer_id": 0, "name": "", "is_first_move": false}

	# 2. King position tracking
	if user_id == 1 and piece_name == "King":
		king1_position = tgt_coord
	elif user_id == 2 and piece_name == "King":
		king2_position = tgt_coord

	# Check capture
	var captured_node: Node3D = null
	var captured_gamer_id: int = int(tgt_spot.get("gamer_id", 0))
	var cap_idx = tgt_idx

	if pieces_nodes.has(tgt_idx) and is_instance_valid(pieces_nodes[tgt_idx]):
		captured_node = pieces_nodes[tgt_idx]
		cap_idx = tgt_idx
	elif is_hit:
		# En-passant check
		var ep_idx = coord_to_index(Vector2i(src_coord.x, tgt_coord.y))
		if pieces_nodes.has(ep_idx) and is_instance_valid(pieces_nodes[ep_idx]):
			captured_node = pieces_nodes[ep_idx]
			cap_idx = ep_idx
			captured_gamer_id = int(board_data[ep_idx].get("gamer_id", 0))
			board_data[ep_idx] = {"gamer_id": 0, "name": "", "is_first_move": false}

	if captured_node != null:
		if captured_gamer_id == 0:
			captured_gamer_id = 2 if user_id == 1 else 1
		pieces_nodes.erase(cap_idx)
		AudioManager.play_sound("remove_peace")
		ActionVFXManager.spawn_piece_impact_vfx(self, captured_node.position, user_id)
		_place_captured_piece(captured_node, captured_gamer_id)

	# Animate moving piece
	var moving_node: Node3D = null
	if pieces_nodes.has(src_idx) and is_instance_valid(pieces_nodes[src_idx]):
		moving_node = pieces_nodes[src_idx]
		pieces_nodes.erase(src_idx)
	else:
		moving_node = _spawn_piece_at_cell(src_idx, user_id, piece_name)

	var tgt_area = cells[tgt_idx]
	var final_pos = Vector3(tgt_area.position.x, 0.048, tgt_area.position.z)
	pieces_nodes[tgt_idx] = moving_node
	moving_node.set_meta("cell_idx", tgt_idx)

	# Animate moving piece with clean physical 3D parabolic arc flight
	var start_pos = moving_node.position
	var mid_pos = (start_pos + final_pos) / 2.0 + Vector3(0, 0.12, 0)

	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(moving_node, "position", mid_pos, 0.20)
	tw.chain().tween_property(moving_node, "position", final_pos, 0.20).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		AudioManager.play_sound("hit")
		ActionVFXManager.spawn_piece_impact_vfx(self, final_pos, user_id)
		_post_move_updates(src_idx, tgt_idx, user_id, piece_name)
	)

func _post_move_updates(src_idx: int, tgt_idx: int, user_id: int, piece_name: String) -> void:
	var src_coord = index_to_coord(src_idx)
	var tgt_coord = index_to_coord(tgt_idx)

	# 1. Castling Secondary Move
	if piece_name == "King":
		if src_idx == 60 and tgt_idx == 58: # P2 Queen-side: Rook (7, 0) -> (7, 3)
			_move_rook_castling(56, 59, 2)
		elif src_idx == 60 and tgt_idx == 62: # P2 King-side: Rook (7, 7) -> (7, 5)
			_move_rook_castling(63, 61, 2)
		elif src_idx == 4 and tgt_idx == 6: # P1 King-side: Rook (0, 7) -> (0, 5)
			_move_rook_castling(7, 5, 1)
		elif src_idx == 4 and tgt_idx == 2: # P1 Queen-side: Rook (0, 0) -> (0, 3)
			_move_rook_castling(0, 3, 1)

	# 2. Pawn Promotion
	if piece_name == "Pawn":
		if (src_coord.x == 6 and tgt_coord.x == 7) or (src_coord.x == 1 and tgt_coord.x == 0):
			_promote_pawn(tgt_idx, user_id)

	piece_moved.emit(src_idx, tgt_idx, false)

func _move_rook_castling(r_src_idx: int, r_tgt_idx: int, gamer_id: int) -> void:
	if pieces_nodes.has(r_src_idx) and is_instance_valid(pieces_nodes[r_src_idx]):
		var r_node = pieces_nodes[r_src_idx]
		pieces_nodes.erase(r_src_idx)
		var tgt_area = cells[r_tgt_idx]
		var final_pos = Vector3(tgt_area.position.x, 0.048, tgt_area.position.z)
		pieces_nodes[r_tgt_idx] = r_node
		r_node.set_meta("cell_idx", r_tgt_idx)

		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(r_node, "position", final_pos, 0.25)
		tw.finished.connect(func():
			AudioManager.play_sound("move_peace")
		)

	board_data[r_tgt_idx] = {"gamer_id": gamer_id, "name": "Rook", "is_first_move": false}
	board_data[r_src_idx] = {"gamer_id": 0, "name": "", "is_first_move": false}

func _promote_pawn(cell_idx: int, gamer_id: int) -> void:
	board_data[cell_idx] = {"gamer_id": gamer_id, "name": "Queen", "is_first_move": false}
	if pieces_nodes.has(cell_idx) and is_instance_valid(pieces_nodes[cell_idx]):
		var old_pawn = pieces_nodes[cell_idx]
		old_pawn.queue_free()

	_spawn_piece_at_cell(cell_idx, gamer_id, "Queen")
	AudioManager.play_sound("bell")
	ActionVFXManager.spawn_piece_impact_vfx(self, cells[cell_idx].position, gamer_id)
	show_hint("👑 ارتقا به وزیر!")

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

# --- Lifecycle & Synchronization ---

func setup_board(game_data: Dictionary) -> void:
	reset_board()
	update_board_orientation(GameManager.my_player_index)
	super._ready()
	if game_data.has("board_data"):
		sync_board_state(game_data["board_data"])
	elif game_data.has("board"):
		sync_board_state(game_data["board"])
	if is_my_turn:
		set_pieces_movements()

func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != 64:
		return
	update_board_orientation(GameManager.my_player_index)
	super._ready()
	var b_arr = new_board as Array
	print("[Chess3D] Synchronizing board from server state...")
	_clear_markers()

	for i in range(64):
		var raw = b_arr[i]
		var gamer_id = 0
		var piece_name = ""
		var is_first = true

		if typeof(raw) == TYPE_DICTIONARY:
			gamer_id = int(raw.get("gamer_id", 0))
			piece_name = str(raw.get("name", ""))
			is_first = bool(raw.get("is_first_move", true))

		board_data[i] = {"gamer_id": gamer_id, "name": piece_name, "is_first_move": is_first}
		if gamer_id == 1 and piece_name == "King":
			king1_position = index_to_coord(i)
		elif gamer_id == 2 and piece_name == "King":
			king2_position = index_to_coord(i)

	_spawn_all_pieces_on_board()
	_sync_captured_pieces()
	if is_my_turn:
		set_pieces_movements()

func on_reconnect_data(_payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)
	sync_turn_state()

func reset_board() -> void:
	_clear_markers()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()

	if check_warning_marker and is_instance_valid(check_warning_marker):
		check_warning_marker.queue_free()
		check_warning_marker = null

	for p in captured_pieces_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_pieces_nodes.clear()
	captured_red_count = 0
	captured_blue_count = 0

	equipped_peace_index = -1
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
	if check_warning_marker and is_instance_valid(check_warning_marker):
		check_warning_marker.queue_free()
		check_warning_marker = null
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
	current_pieces_moves.clear()
	current_pieces_hits.clear()
	board_data.clear()
