class_name Othello3D
extends "res://scripts/games/base_game_board.gd"

# Othello 3D Board (اتللو سه بعدی — Cafe Fekr Royal Tournament Edition)
# Exact 1:1 port of Flutter OthelloController + Python Backend OthelloGameClass & OthelloGameSession.
# Features:
# - Luxury 3D 8x8 board matching Checkers 3D craftsmanship (satin walnut & dark rosewood/emerald squares,
#   24K gold wire grid lines, 4 brass Hoshi quadrant star-points, algebraic coordinates, and side reserve trays)
# - Reversible 3D Checkers-style lathe-turned ribbed pucks (Red with 24K Gold inlay on one side,
#   Blue with Brushed Platinum inlay on the opposite side, united by a 24K gold equator band)
# - Smooth 180-degree mid-air 3D flip wave animation along every bracketed ray with shockwave VFX
# - Pulsing legal-move target indicators on valid empty squares during the player's turn

signal piece_placed(cell_idx: int, flipped_count: int)

const GRID_SIZE: int = 8
const MAX_CELLS: int = 64

# 8 Othello Ray Directions: (dc, dr) matching MOVE_DIRS in backend & Flutter
const MOVE_DIRS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1),
	Vector2i(0, -1),                   Vector2i(0, 1),
	Vector2i(1, -1),  Vector2i(1, 0),  Vector2i(1, 1)
]

var cell_size: float = 0.13
var board_width: float = 1.04 # 8 * 0.13
var half_board: float = 0.52

# --- State (Matches OthelloController & OthelloGameClass 1:1) ---
# board_data[idx] = 0 (empty), 1 (Player 1 Red), 2 (Player 2 Blue)
# where r_index = idx % 8, c_index = idx / 8, idx = c_index * 8 + r_index
var board_data: Array[int] = []
var current_legal_moves: Dictionary = {} # cell_idx -> Array[Dictionary] of flipped tiles

var player1_pawns: int = 30
var player2_pawns: int = 30
var player1_score: int = 2
var player2_score: int = 2

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

# --- 3D Nodes & Caches ---
var cells: Array[Area3D] = []
var cell_meshes: Array[MeshInstance3D] = []
var pieces_nodes: Dictionary = {} # cell_idx -> Node3D
var reserve_red_nodes: Array[Node3D] = []
var reserve_blue_nodes: Array[Node3D] = []
var tray_red: Node3D = null
var tray_blue: Node3D = null
var lbl_tray_red_count: Label3D = null
var lbl_tray_blue_count: Label3D = null

var active_markers: Array[Node3D] = []
var last_move_markers: Array[MeshInstance3D] = []
var coord_labels: Array[Label3D] = []

# --- Luxury Procedural Materials ---
var mat_cell_light: StandardMaterial3D
var mat_cell_dark: StandardMaterial3D
var mat_gold_grid: StandardMaterial3D
var mat_brass_corner: StandardMaterial3D
var mat_piece_p1: StandardMaterial3D
var mat_piece_p1_well: StandardMaterial3D
var mat_piece_p2: StandardMaterial3D
var mat_piece_p2_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_marker_legal: StandardMaterial3D
var mat_marker_legal_ring: StandardMaterial3D
var mat_last_move: StandardMaterial3D
var mat_flipped_highlight: StandardMaterial3D

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")

static func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out

func _ready() -> void:
	game_type = GameTypes.OTHELLO
	add_to_group("board")
	_init_materials()
	_build_board_3d()
	_init_board_data()
	_spawn_all_pieces_on_board()
	_sync_reserve_trays()
	_sync_hud_scores()
	update_board_orientation(GameManager.my_player_index)
	super._ready()

func _init_materials() -> void:
	# 1. Light Square — Warm Satin Maple / Honey Walnut
	mat_cell_light = StandardMaterial3D.new()
	mat_cell_light.albedo_color = Color(0.84, 0.72, 0.54)
	mat_cell_light.metallic = 0.04
	mat_cell_light.roughness = 0.34
	mat_cell_light.clearcoat_enabled = true
	mat_cell_light.clearcoat = 0.45
	mat_cell_light.clearcoat_roughness = 0.22

	# 2. Dark Square — Rich Smoked Rosewood / Tournament Walnut
	mat_cell_dark = StandardMaterial3D.new()
	mat_cell_dark.albedo_color = Color(0.28, 0.16, 0.10)
	mat_cell_dark.metallic = 0.05
	mat_cell_dark.roughness = 0.38
	mat_cell_dark.clearcoat_enabled = true
	mat_cell_dark.clearcoat = 0.50
	mat_cell_dark.clearcoat_roughness = 0.24

	# 3. 24K Gold Wire Grid & Borders
	mat_gold_grid = StandardMaterial3D.new()
	mat_gold_grid.albedo_color = Color(0.92, 0.76, 0.26)
	mat_gold_grid.metallic = 0.88
	mat_gold_grid.roughness = 0.32

	# 4. Corner Brass Brackets
	mat_brass_corner = StandardMaterial3D.new()
	mat_brass_corner.albedo_color = Color(0.92, 0.74, 0.26)
	mat_brass_corner.metallic = 0.92
	mat_brass_corner.roughness = 0.20

	# 5. Player 1 (Red) — Imperial Ruby Crimson Lacquer (Matches Checkers 3D & AppColors.darkRed)
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.76, 0.11, 0.15)
	mat_piece_p1.metallic = 0.18
	mat_piece_p1.roughness = 0.22
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 0.92
	mat_piece_p1.clearcoat_roughness = 0.10

	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.56, 0.07, 0.10)
	mat_piece_p1_well.metallic = 0.22
	mat_piece_p1_well.roughness = 0.28
	mat_piece_p1_well.clearcoat_enabled = true
	mat_piece_p1_well.clearcoat = 0.85

	# 6. Player 2 (Blue) — Royal Sapphire Cobalt Lacquer (Matches Checkers 3D & AppColors.imageBlueColor)
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.11, 0.36, 0.78)
	mat_piece_p2.metallic = 0.20
	mat_piece_p2.roughness = 0.22
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 0.92
	mat_piece_p2.clearcoat_roughness = 0.10

	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.07, 0.24, 0.58)
	mat_piece_p2_well.metallic = 0.24
	mat_piece_p2_well.roughness = 0.28
	mat_piece_p2_well.clearcoat_enabled = true
	mat_piece_p2_well.clearcoat = 0.85

	# 7. 24K Gold & Brushed Platinum Trim on Pieces
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.98, 0.82, 0.28)
	mat_gold_trim.metallic = 0.94
	mat_gold_trim.roughness = 0.16

	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.88, 0.93, 1.0)
	mat_platinum_trim.metallic = 0.92
	mat_platinum_trim.roughness = 0.18

	# 8. Legal Move Markers (Golden-Emerald Target Ring & Inner Dot)
	mat_marker_legal_ring = StandardMaterial3D.new()
	mat_marker_legal_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_legal_ring.albedo_color = Color(0.95, 0.76, 0.14, 0.92)
	mat_marker_legal_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_marker_legal = StandardMaterial3D.new()
	mat_marker_legal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_legal.albedo_color = Color(0.24, 0.94, 0.52, 0.88)
	mat_marker_legal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# 9. Last Move & Flipped Square Highlights
	mat_last_move = StandardMaterial3D.new()
	mat_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_last_move.albedo_color = Color(1.0, 0.86, 0.24, 0.34)
	mat_last_move.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_flipped_highlight = StandardMaterial3D.new()
	mat_flipped_highlight.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flipped_highlight.albedo_color = Color(1.0, 0.92, 0.45, 0.18)
	mat_flipped_highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _build_board_3d() -> void:
	cells.resize(64)
	cell_meshes.resize(64)

	var tile_mesh_light = BoxMesh.new()
	tile_mesh_light.size = Vector3(cell_size * 0.975, 0.014, cell_size * 0.975)
	tile_mesh_light.material = mat_cell_light

	var tile_mesh_dark = BoxMesh.new()
	tile_mesh_dark.size = Vector3(cell_size * 0.975, 0.014, cell_size * 0.975)
	tile_mesh_dark.material = mat_cell_dark

	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(cell_size, 0.03, cell_size)

	# Coordinate Mapping (Matches Checkers3D, OthelloController, and OthelloGameClass):
	# index = c_index * 8 + r_index
	# r_index = index % 8 (0..7 -> X axis from -half_board to +half_board)
	# c_index = index / 8 (0..7 -> Z axis from +half_board to -half_board)
	for c_index in range(GRID_SIZE):
		for r_index in range(GRID_SIZE):
			var idx = c_index * GRID_SIZE + r_index
			var is_light = ((r_index + c_index) % 2 != 0)

			var pos_x = -half_board + (r_index * cell_size) + (cell_size * 0.5)
			var pos_z = half_board - (c_index * cell_size) - (cell_size * 0.5)

			var area = Area3D.new()
			area.name = "Cell_%d" % idx
			area.position = Vector3(pos_x, 0.041, pos_z)

			var col = CollisionShape3D.new()
			col.shape = col_shape
			area.add_child(col)

			var m_inst = MeshInstance3D.new()
			m_inst.mesh = tile_mesh_light if is_light else tile_mesh_dark
			area.add_child(m_inst)

			add_child(area)
			cells[idx] = area
			cell_meshes[idx] = m_inst

	_build_grid_wire_lines()
	_build_hoshi_star_points()
	_build_algebraic_coordinates()
	_build_reserve_trays()

func _build_grid_wire_lines() -> void:
	var wire_h = BoxMesh.new()
	wire_h.size = Vector3(board_width, 0.003, 0.0035)
	wire_h.material = mat_gold_grid

	var wire_v = BoxMesh.new()
	wire_v.size = Vector3(0.0035, 0.003, board_width)
	wire_v.material = mat_gold_grid

	for i in range(1, GRID_SIZE):
		var offset = -half_board + (i * cell_size)

		var line_h = MeshInstance3D.new()
		line_h.mesh = wire_h
		line_h.position = Vector3(0.0, 0.0482, offset)
		add_child(line_h)

		var line_v = MeshInstance3D.new()
		line_v.mesh = wire_v
		line_v.position = Vector3(offset, 0.0482, 0.0)
		add_child(line_v)

func _build_hoshi_star_points() -> void:
	# 4 Classic Tournament Othello Quadrant Star-Points at intersections (2,2), (2,6), (6,2), (6,6)
	var dot_mesh = CylinderMesh.new()
	dot_mesh.top_radius = 0.0065
	dot_mesh.bottom_radius = 0.0075
	dot_mesh.height = 0.0035
	dot_mesh.radial_segments = 20
	dot_mesh.material = mat_brass_corner

	for ix in [2, 6]:
		for iz in [2, 6]:
			var px = -half_board + (ix * cell_size)
			var pz = -half_board + (iz * cell_size)
			var dot = MeshInstance3D.new()
			dot.name = "HoshiDot_%d_%d" % [ix, iz]
			dot.mesh = dot_mesh
			dot.position = Vector3(px, 0.0485, pz)
			add_child(dot)

func _build_algebraic_coordinates() -> void:
	coord_labels.clear()
	var files = ["A", "B", "C", "D", "E", "F", "G", "H"]
	var border_offset = half_board + 0.036

	for i in range(8):
		var pos_step = -half_board + (i * cell_size) + (cell_size * 0.5)
		var z_rank = half_board - (i * cell_size) - (cell_size * 0.5)

		var lbl_s = _create_coord_label(files[i], Vector3(pos_step, 0.043, border_offset))
		var lbl_n = _create_coord_label(files[i], Vector3(pos_step, 0.043, -border_offset))
		var rank_str = str(i + 1)
		var lbl_w = _create_coord_label(rank_str, Vector3(-border_offset, 0.043, z_rank))
		var lbl_e = _create_coord_label(rank_str, Vector3(border_offset, 0.043, z_rank))

		coord_labels.append_array([lbl_s, lbl_n, lbl_w, lbl_e])

func _create_coord_label(txt: String, pos: Vector3) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.font_size = 30
	lbl.pixel_size = 0.0008
	lbl.modulate = Color(0.95, 0.82, 0.48, 0.92)
	lbl.outline_modulate = Color(0.10, 0.05, 0.02, 0.90)
	lbl.outline_size = 6
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.position = pos
	add_child(lbl)
	return lbl

func update_board_orientation(player_idx: int) -> void:
	my_player_index = player_idx
	if my_player_index == 2:
		rotation_degrees.y = 180.0
	else:
		rotation_degrees.y = 0.0

	var label_rot_z = 180.0 if my_player_index == 2 else 0.0
	for lbl in coord_labels:
		if is_instance_valid(lbl):
			lbl.rotation_degrees = Vector3(-90.0, 0.0, label_rot_z)

	_update_reserve_tray_positions()
	_refresh_reserve_pieces_positions()

# --- Side Reserve Disc Trays (30 Reserve Discs per Player) ---

func _build_reserve_trays() -> void:
	if tray_red and is_instance_valid(tray_red):
		tray_red.queue_free()
	if tray_blue and is_instance_valid(tray_blue):
		tray_blue.queue_free()

	tray_red = _create_single_tray_mesh("ReserveTrayRed", Color(0.45, 0.08, 0.10), "ذخیره قرمز")
	add_child(tray_red)
	lbl_tray_red_count = tray_red.get_node_or_null("TrayCountLabel") as Label3D

	tray_blue = _create_single_tray_mesh("ReserveTrayBlue", Color(0.08, 0.22, 0.48), "ذخیره آبی")
	add_child(tray_blue)
	lbl_tray_blue_count = tray_blue.get_node_or_null("TrayCountLabel") as Label3D

	_update_reserve_tray_positions()

func _create_single_tray_mesh(tray_name: String, felt_color: Color, label_fa: String) -> Node3D:
	var root = Node3D.new()
	root.name = tray_name

	const TRAY_W: float = 0.178
	const TRAY_L: float = 0.98
	const TRAY_H: float = 0.022
	const WALL_T: float = 0.015
	const WALL_H: float = 0.015

	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.20, 0.11, 0.06)
	mat_wood.metallic = 0.04
	mat_wood.roughness = 0.36
	mat_wood.clearcoat_enabled = true
	mat_wood.clearcoat = 0.55

	var base_inst = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = Vector3(TRAY_W, TRAY_H, TRAY_L)
	base_box.material = mat_wood
	base_inst.mesh = base_box
	base_inst.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(base_inst)

	var mat_felt = StandardMaterial3D.new()
	mat_felt.albedo_color = felt_color
	mat_felt.roughness = 0.88
	mat_felt.metallic = 0.0

	var felt_inst = MeshInstance3D.new()
	var felt_box = BoxMesh.new()
	felt_box.size = Vector3(TRAY_W - WALL_T * 1.8, 0.004, TRAY_L - WALL_T * 1.8)
	felt_box.material = mat_felt
	felt_inst.mesh = felt_box
	felt_inst.position = Vector3(0.0, TRAY_H * 0.5 + 0.001, 0.0)
	root.add_child(felt_inst)

	var wall_long_mesh = BoxMesh.new()
	wall_long_mesh.size = Vector3(WALL_T, WALL_H, TRAY_L)
	wall_long_mesh.material = mat_wood

	for sx in [-1.0, 1.0]:
		var w_side = MeshInstance3D.new()
		w_side.mesh = wall_long_mesh
		w_side.position = Vector3(sx * (TRAY_W * 0.5 - WALL_T * 0.5), TRAY_H * 0.5 + WALL_H * 0.5 - 0.002, 0.0)
		root.add_child(w_side)

	var wall_short_mesh = BoxMesh.new()
	wall_short_mesh.size = Vector3(TRAY_W, WALL_H, WALL_T)
	wall_short_mesh.material = mat_wood

	for sz in [-1.0, 1.0]:
		var w_end = MeshInstance3D.new()
		w_end.mesh = wall_short_mesh
		w_end.position = Vector3(0.0, TRAY_H * 0.5 + WALL_H * 0.5 - 0.002, sz * (TRAY_L * 0.5 - WALL_T * 0.5))
		root.add_child(w_end)

	var divider_mesh = BoxMesh.new()
	divider_mesh.size = Vector3(0.004, 0.005, TRAY_L - WALL_T * 2.2)
	divider_mesh.material = mat_gold_grid
	var divider = MeshInstance3D.new()
	divider.mesh = divider_mesh
	divider.position = Vector3(0.0, TRAY_H * 0.5 + 0.003, 0.0)
	root.add_child(divider)

	var corner_cap_mesh = BoxMesh.new()
	corner_cap_mesh.size = Vector3(0.026, WALL_H + 0.006, 0.026)
	corner_cap_mesh.material = mat_brass_corner

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cap = MeshInstance3D.new()
			cap.mesh = corner_cap_mesh
			cap.position = Vector3(sx * (TRAY_W * 0.5 - 0.008), TRAY_H * 0.5 + WALL_H * 0.5, sz * (TRAY_L * 0.5 - 0.008))
			root.add_child(cap)

	var plaque_mesh = BoxMesh.new()
	plaque_mesh.size = Vector3(0.012, 0.005, 0.24)
	plaque_mesh.material = mat_brass_corner
	var plaque = MeshInstance3D.new()
	plaque.name = "TrayPlaque"
	plaque.mesh = plaque_mesh
	plaque.position = Vector3(0.080, TRAY_H * 0.5 + WALL_H + 0.002, 0.0)
	root.add_child(plaque)

	var lbl = Label3D.new()
	lbl.name = "TrayCountLabel"
	if _font_hekayat:
		lbl.font = _font_hekayat
	lbl.text = "%s: ۳۰" % label_fa
	lbl.font_size = 24
	lbl.pixel_size = 0.00065
	lbl.modulate = Color(0.98, 0.88, 0.45, 0.98)
	lbl.outline_modulate = Color(0.10, 0.06, 0.03, 0.95)
	lbl.outline_size = 6
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.080, 0.032, 0.0)
	root.add_child(lbl)

	return root

func _update_reserve_tray_positions() -> void:
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
	var lbl = tray.get_node_or_null("TrayCountLabel")
	if lbl and lbl is Label3D:
		lbl.position.x = outer_sign * 0.080
		lbl.rotation_degrees = Vector3(-90.0, 0.0, rot_z)

func get_reserve_slot_position(gamer_id: int, slot_idx: int) -> Vector3:
	# Up to 30 reserve discs arranged in 2 columns x 5 stacks (3 stacked per slot)
	var stack_slot = slot_idx % 10
	var stack_layer = slot_idx / 10
	var col_idx = stack_slot / 5
	var row_idx = stack_slot % 5

	var tray_center_x: float = 0.0
	var inner_dir_x: float = 0.0

	if my_player_index == 2:
		if gamer_id == 1:
			tray_center_x = 0.765
			inner_dir_x = -1.0
		else:
			tray_center_x = -0.765
			inner_dir_x = 1.0
	else:
		if gamer_id == 1:
			tray_center_x = -0.765
			inner_dir_x = 1.0
		else:
			tray_center_x = 0.765
			inner_dir_x = -1.0

	var col_offset_x = (0.035 if col_idx == 0 else -0.035) * inner_dir_x
	var slot_x = tray_center_x + col_offset_x

	var slot_z: float = 0.0
	if my_player_index == 2:
		slot_z = -0.360 + (row_idx * 0.180)
	else:
		slot_z = 0.360 - (row_idx * 0.180)

	var slot_y = 0.025 + (stack_layer * 0.015)
	return Vector3(slot_x, slot_y, slot_z)

func _sync_reserve_trays() -> void:
	for p in reserve_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_red_nodes.clear()

	for p in reserve_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_blue_nodes.clear()

	var p1_cnt = clampi(player1_pawns, 0, 30)
	var p2_cnt = clampi(player2_pawns, 0, 30)

	for i in range(p1_cnt):
		var r_node = _build_3d_othello_piece(1)
		r_node.name = "Reserve_Red_%d" % i
		r_node.scale = Vector3(0.64, 0.64, 0.64)
		r_node.set_meta("reserve_gamer_id", 1)
		r_node.set_meta("reserve_slot_idx", i)
		r_node.position = get_reserve_slot_position(1, i)
		add_child(r_node)
		reserve_red_nodes.append(r_node)

	for i in range(p2_cnt):
		var b_node = _build_3d_othello_piece(2)
		b_node.name = "Reserve_Blue_%d" % i
		b_node.scale = Vector3(0.64, 0.64, 0.64)
		b_node.set_meta("reserve_gamer_id", 2)
		b_node.set_meta("reserve_slot_idx", i)
		b_node.position = get_reserve_slot_position(2, i)
		add_child(b_node)
		reserve_blue_nodes.append(b_node)

	_update_reserve_labels()

func _refresh_reserve_pieces_positions() -> void:
	for i in range(reserve_red_nodes.size()):
		var p = reserve_red_nodes[i]
		if is_instance_valid(p):
			p.position = get_reserve_slot_position(1, i)
	for i in range(reserve_blue_nodes.size()):
		var p = reserve_blue_nodes[i]
		if is_instance_valid(p):
			p.position = get_reserve_slot_position(2, i)

func _update_reserve_labels() -> void:
	if is_instance_valid(lbl_tray_red_count):
		lbl_tray_red_count.text = "ذخیره قرمز: %s" % _fa_digits(max(0, player1_pawns))
	if is_instance_valid(lbl_tray_blue_count):
		lbl_tray_blue_count.text = "ذخیره آبی: %s" % _fa_digits(max(0, player2_pawns))

func _consume_reserve_piece(gamer_id: int) -> void:
	if gamer_id == 1 and not reserve_red_nodes.is_empty():
		var node = reserve_red_nodes.pop_back()
		if is_instance_valid(node):
			node.queue_free()
	elif gamer_id == 2 and not reserve_blue_nodes.is_empty():
		var node = reserve_blue_nodes.pop_back()
		if is_instance_valid(node):
			node.queue_free()
	_update_reserve_labels()

# --- Coordinate Helpers (Matching Flutter & Backend 1:1) ---
# r_index = index % 8 (0..7)
# c_index = index / 8 (0..7)
# index = c_index * 8 + r_index

func index_to_coord(index: int) -> Vector2i:
	return Vector2i(index % GRID_SIZE, index / GRID_SIZE)

func coord_to_index(r_index: int, c_index: int) -> int:
	return c_index * GRID_SIZE + r_index

func is_valid_coord(c_index: int, r_index: int) -> bool:
	return c_index >= 0 and c_index < GRID_SIZE and r_index >= 0 and r_index < GRID_SIZE

# --- Raycast Input Handling (Single Source of Input per GAME_SCENE_RULES 4.3) ---

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

# --- Board Data Initialization (Matches initPeaces / add_pawns_to_board 1:1) ---

func _init_board_data() -> void:
	board_data.clear()
	for _i in range(64):
		board_data.append(0)

	# 4 Center Starting Discs:
	# (3, 3) -> 27 = Player 1 (Red), (4, 4) -> 36 = Player 1 (Red)
	# (3, 4) -> 28 = Player 2 (Blue), (4, 3) -> 35 = Player 2 (Blue)
	board_data[27] = 1
	board_data[36] = 1
	board_data[28] = 2
	board_data[35] = 2

	player1_pawns = 30
	player2_pawns = 30
	player1_score = 2
	player2_score = 2

func _recalculate_scores_from_board() -> void:
	var s1 = 0
	var s2 = 0
	for i in range(board_data.size()):
		if board_data[i] == 1:
			s1 += 1
		elif board_data[i] == 2:
			s2 += 1
	player1_score = s1
	player2_score = s2

func _sync_hud_scores() -> void:
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var main_node = get_tree().current_scene
	if main_node and "base_game_hud" in main_node and is_instance_valid(main_node.base_game_hud):
		main_node.base_game_hud.update_scores(player1_score, player2_score)

# --- 3D Reversible Checkers-Style Othello Puck Builder ---

func _spawn_all_pieces_on_board() -> void:
	for p in pieces_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	pieces_nodes.clear()

	for i in range(64):
		var g_id = board_data[i]
		if g_id != 0:
			_spawn_piece_at_cell(i, g_id)

func _spawn_piece_at_cell(cell_idx: int, gamer_id: int) -> Node3D:
	var area = cells[cell_idx]
	var p_node = _build_3d_othello_piece(gamer_id)
	p_node.name = "OthelloDisc_%d_P%d" % [cell_idx, gamer_id]
	p_node.set_meta("cell_idx", cell_idx)
	p_node.set_meta("gamer_id", gamer_id)
	p_node.position = Vector3(area.position.x, 0.048, area.position.z)
	add_child(p_node)
	pieces_nodes[cell_idx] = p_node
	return p_node

func _build_3d_othello_piece(gamer_id: int) -> Node3D:
	# Dual-sided 3D Lathe-Turned Checkers Puck:
	# FlipPivot sits at y = 0.0155 above the board surface.
	# Upper half (y >= 0) is Imperial Ruby Crimson + 24K Gold Trim (Player 1).
	# Lower half (y <= 0, rotated 180 deg on X) is Royal Sapphire Blue + Platinum Trim (Player 2).
	# When gamer_id == 1, FlipPivot.rotation.x = 0.0 (Red faces up).
	# When gamer_id == 2, FlipPivot.rotation.x = PI  (Blue faces up).
	var root = Node3D.new()
	root.set_meta("gamer_id", gamer_id)

	var flip_pivot = Node3D.new()
	flip_pivot.name = "FlipPivot"
	flip_pivot.position = Vector3(0.0, 0.0155, 0.0)
	flip_pivot.rotation.x = 0.0 if gamer_id == 1 else PI
	root.add_child(flip_pivot)

	# 1. Center 24K Gold Equator Bevel Ring uniting Red & Blue halves
	var equator = MeshInstance3D.new()
	var torus_eq = TorusMesh.new()
	torus_eq.inner_radius = 0.0415
	torus_eq.outer_radius = 0.0468
	torus_eq.rings = 32
	torus_eq.ring_segments = 24
	equator.mesh = torus_eq
	equator.material_override = mat_gold_trim
	flip_pivot.add_child(equator)

	# 2. Top Half: Player 1 (Red) Ribbed Checker Puck Face
	var red_half = _build_half_checker_face(mat_piece_p1, mat_piece_p1_well, mat_gold_trim)
	red_half.name = "RedFace"
	flip_pivot.add_child(red_half)

	# 3. Bottom Half: Player 2 (Blue) Ribbed Checker Puck Face (Facing Downward so 180 flip brings it Up!)
	var blue_half = _build_half_checker_face(mat_piece_p2, mat_piece_p2_well, mat_platinum_trim)
	blue_half.name = "BlueFace"
	blue_half.rotation.x = PI
	flip_pivot.add_child(blue_half)

	return root

func _build_half_checker_face(mat_main: StandardMaterial3D, mat_well: StandardMaterial3D, mat_trim: StandardMaterial3D) -> Node3D:
	var half = Node3D.new()

	# Cylindrical Half-Puck Body (from y = 0.0005 to y = 0.0115)
	var body = MeshInstance3D.new()
	var cyl_body = CylinderMesh.new()
	cyl_body.top_radius = 0.0445
	cyl_body.bottom_radius = 0.0455
	cyl_body.height = 0.011
	cyl_body.radial_segments = 48
	body.mesh = cyl_body
	body.material_override = mat_main
	body.position.y = 0.006
	half.add_child(body)

	# Recessed Inner Well (Classic Checkers Dish)
	var dish = MeshInstance3D.new()
	var cyl_dish = CylinderMesh.new()
	cyl_dish.top_radius = 0.036
	cyl_dish.bottom_radius = 0.036
	cyl_dish.height = 0.002
	cyl_dish.radial_segments = 36
	dish.mesh = cyl_dish
	dish.material_override = mat_well
	dish.position.y = 0.0116
	half.add_child(dish)

	# Raised Outer Gripping Rim (Torus)
	var outer_rim = MeshInstance3D.new()
	var torus_rim = TorusMesh.new()
	torus_rim.inner_radius = 0.0355
	torus_rim.outer_radius = 0.045
	torus_rim.rings = 36
	torus_rim.ring_segments = 24
	outer_rim.mesh = torus_rim
	outer_rim.material_override = mat_main
	outer_rim.position.y = 0.0116
	half.add_child(outer_rim)

	# 16 Radial Tactile Grip Ridges around Outer Rim (Authentic Checkers 3D Edge)
	var notch_mesh = BoxMesh.new()
	notch_mesh.size = Vector3(0.0032, 0.0032, 0.0075)
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		var notch = MeshInstance3D.new()
		notch.mesh = notch_mesh
		notch.material_override = mat_main
		var r_pos = 0.040
		notch.position = Vector3(r_pos * cos(angle), 0.0138, r_pos * sin(angle))
		notch.rotation.y = -angle + PI * 0.5
		half.add_child(notch)

	# Concentric 24K Gold / Platinum Inlay Ring inside the Dish
	var mid_ring = MeshInstance3D.new()
	var torus_mid = TorusMesh.new()
	torus_mid.inner_radius = 0.0235
	torus_mid.outer_radius = 0.0278
	torus_mid.rings = 32
	torus_mid.ring_segments = 20
	mid_ring.mesh = torus_mid
	mid_ring.material_override = mat_trim
	mid_ring.position.y = 0.0124
	half.add_child(mid_ring)

	# Inner Concentric Lacquer Ridge
	var inner_ridge = MeshInstance3D.new()
	var torus_in = TorusMesh.new()
	torus_in.inner_radius = 0.0125
	torus_in.outer_radius = 0.0185
	torus_in.rings = 28
	torus_in.ring_segments = 20
	inner_ridge.mesh = torus_in
	inner_ridge.material_override = mat_main
	inner_ridge.position.y = 0.0126
	half.add_child(inner_ridge)

	# Center Medallion Boss
	var boss = MeshInstance3D.new()
	var cyl_boss = CylinderMesh.new()
	cyl_boss.top_radius = 0.0085
	cyl_boss.bottom_radius = 0.0095
	cyl_boss.height = 0.0028
	cyl_boss.radial_segments = 24
	boss.mesh = cyl_boss
	boss.material_override = mat_trim
	boss.position.y = 0.0129
	half.add_child(boss)

	return half

# --- Exact Othello Rule Engine (Ported 1:1 from OthelloController & OthelloGameClass) ---

func has_tile_to_flip(c_index: int, r_index: int, direction: Vector2i, gamer_id: int) -> bool:
	var i: int = 1
	if not is_valid_coord(c_index, r_index):
		return false
	while true:
		var nc = c_index + direction.x * i
		var nr = r_index + direction.y * i
		if not is_valid_coord(nc, nr):
			return false
		var occ = board_data[nc * GRID_SIZE + nr]
		if occ == 0:
			return false
		if occ == gamer_id:
			break
		i += 1
	return i > 1

func is_legal_move(c_index: int, r_index: int, gamer_id: int) -> bool:
	if not is_valid_coord(c_index, r_index):
		return false
	var idx = c_index * GRID_SIZE + r_index
	if board_data[idx] != 0:
		return false
	for dir in MOVE_DIRS:
		if has_tile_to_flip(c_index, r_index, dir, gamer_id):
			return true
	return false

func get_tiles_to_flip(c_index: int, r_index: int, gamer_id: int) -> Array[Dictionary]:
	var flipped_list: Array[Dictionary] = []
	if not is_valid_coord(c_index, r_index):
		return flipped_list

	for dir in MOVE_DIRS:
		if has_tile_to_flip(c_index, r_index, dir, gamer_id):
			var i: int = 1
			while true:
				var nc = c_index + dir.x * i
				var nr = r_index + dir.y * i
				var f_idx = nc * GRID_SIZE + nr
				if board_data[f_idx] == gamer_id:
					break
				flipped_list.append({
					"cell_idx": f_idx,
					"c_index": nc,
					"r_index": nr,
					"step": i,
					"dir": dir
				})
				i += 1
	return flipped_list

func update_legal_moves_for_turn() -> void:
	_clear_markers()
	current_legal_moves.clear()

	if not GameManager.is_game_active or not is_my_turn:
		return
	if board_data.size() < 64:
		return

	for idx in range(64):
		if board_data[idx] == 0:
			var r_idx = idx % GRID_SIZE
			var c_idx = idx / GRID_SIZE
			var flips = get_tiles_to_flip(c_idx, r_idx, my_player_index)
			if not flips.is_empty():
				current_legal_moves[idx] = flips
				_spawn_legal_move_marker(idx, flips.size())

func _spawn_legal_move_marker(cell_idx: int, _flip_count: int) -> void:
	if cell_idx < 0 or cell_idx >= cells.size():
		return
	var area = cells[cell_idx]
	var marker = Node3D.new()
	marker.name = "LegalMarker_%d" % cell_idx
	marker.position = Vector3(area.position.x, 0.050, area.position.z)

	# Outer Golden Target Ring
	var ring_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = cell_size * 0.25
	torus.outer_radius = cell_size * 0.34
	torus.rings = 24
	torus.ring_segments = 24
	torus.material = mat_marker_legal_ring
	ring_inst.mesh = torus
	marker.add_child(ring_inst)

	# Inner Emerald Bullseye Dot
	var dot_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = cell_size * 0.11
	cyl.bottom_radius = cell_size * 0.11
	cyl.height = 0.004
	cyl.radial_segments = 20
	cyl.material = mat_marker_legal
	dot_inst.mesh = cyl
	marker.add_child(dot_inst)

	add_child(marker)
	active_markers.append(marker)

	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", Vector3(1.14, 1.0, 1.14), 0.62)
	tw.tween_property(marker, "scale", Vector3(0.92, 1.0, 0.92), 0.62)

func _clear_markers() -> void:
	for m in active_markers:
		if is_instance_valid(m):
			m.queue_free()
	active_markers.clear()

# --- Interactive Click & Move Dispatch ---

func _on_cell_clicked(cell_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if cell_idx < 0 or cell_idx >= MAX_CELLS:
		return
	if is_board_locked:
		return
	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.play_sound("miss_turn")
		return

	var now = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_click_frame or (now - last_click_time < 0.04):
		return
	_last_click_frame = current_frame
	last_click_time = now

	if board_data[cell_idx] != 0:
		show_hint("این خانه قبلاً پر شده است؛ خانه دیگری انتخاب کنید.")
		AudioManager.play_sound("miss_turn")
		return

	var r_index = cell_idx % GRID_SIZE
	var c_index = cell_idx / GRID_SIZE

	if not is_legal_move(c_index, r_index, my_player_index):
		if current_legal_moves.is_empty():
			show_hint("حرکتی برای شما وجود ندارد؛ منتظر پایان زمان نوبت بمانید.")
		else:
			show_hint("حرکت نامعتبر! خانه‌ای را انتخاب کنید که مهره حریف را محاصره کند.")
		AudioManager.play_sound("miss_turn")
		return

	# Valid move! Lock board immediately and dispatch to server
	set_board_locked(true)
	is_my_turn = false
	_clear_markers()

	ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
	send_move(Commands.Select_Peace, {
		"c_index": c_index,
		"r_index": r_index
	})

# --- Server Event Execution & 3D 180-Degree Flip Wave Animation ---

func on_turn_changed(turn: int, is_me: bool) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)

	# In backend OthelloGameSession.change_turn():
	# if self.turn == 1: self.game.player1_pawns -= 1 else: self.game.player2_pawns -= 1
	if turn == 1:
		player1_pawns = max(0, player1_pawns - 1)
		_consume_reserve_piece(1)
	elif turn == 2:
		player2_pawns = max(0, player2_pawns - 1)
		_consume_reserve_piece(2)

	if is_me:
		update_legal_moves_for_turn()
		if current_legal_moves.is_empty() and GameManager.is_game_active:
			show_hint("هیچ حرکت مجازی ندارید؛ نوبت پس از پایان زمان تغییر می‌کند.")
	else:
		_clear_markers()

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	if extra.is_empty():
		return
	var data = extra
	if extra.has("select_data") and typeof(extra["select_data"]) == TYPE_DICTIONARY:
		data = extra["select_data"]

	var c_index = int(data.get("c_index", -1))
	var r_index = int(data.get("r_index", -1))
	var gamer_id = int(data.get("gamer_id", user_id))

	if c_index < 0 or c_index >= GRID_SIZE or r_index < 0 or r_index >= GRID_SIZE:
		return

	var server_scores: Array = []
	if extra.has("scores") and typeof(extra["scores"]) == TYPE_ARRAY:
		server_scores = extra["scores"]

	_execute_othello_move(c_index, r_index, gamer_id, server_scores)

func _execute_othello_move(c_index: int, r_index: int, gamer_id: int, server_scores: Array = []) -> void:
	_clear_markers()
	var target_idx = c_index * GRID_SIZE + r_index

	# 1. Identify all bracketed enemy tiles BEFORE mutating board_data
	var flips: Array[Dictionary] = get_tiles_to_flip(c_index, r_index, gamer_id)

	# 2. Mutate authoritative board_data immediately
	board_data[target_idx] = gamer_id
	var flipped_indices: Array[int] = []
	for f_info in flips:
		var f_idx = int(f_info["cell_idx"])
		board_data[f_idx] = gamer_id
		flipped_indices.append(f_idx)

	# 3. Update scores (prefer server authority if provided, otherwise exact board count)
	if server_scores.size() >= 2:
		player1_score = int(server_scores[0])
		player2_score = int(server_scores[1])
	else:
		_recalculate_scores_from_board()
	_sync_hud_scores()

	_update_last_move_highlights(target_idx, flipped_indices)

	# 4. Spawn & animate the newly placed 3D Othello puck dropping onto target_idx
	if pieces_nodes.has(target_idx) and is_instance_valid(pieces_nodes[target_idx]):
		pieces_nodes[target_idx].queue_free()
		pieces_nodes.erase(target_idx)

	var new_piece = _spawn_piece_at_cell(target_idx, gamer_id)
	var target_pos = new_piece.position
	new_piece.position = target_pos + Vector3(0.0, 0.22, 0.0)
	new_piece.scale = Vector3(0.35, 0.35, 0.35)

	var drop_tw = create_tween()
	drop_tw.set_parallel(true)
	drop_tw.tween_property(new_piece, "position", target_pos, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop_tw.tween_property(new_piece, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop_tw.chain().tween_callback(func():
		AudioManager.play_sound("add_peace")
		ActionVFXManager.spawn_piece_impact_vfx(self, target_pos, gamer_id)
	)

	# 5. Animate 180-degree mid-air 3D flip wave along each bracketed ray!
	for f_info in flips:
		var f_idx: int = int(f_info["cell_idx"])
		var step_dist: int = int(f_info["step"])
		var delay_sec: float = 0.16 + float(step_dist) * 0.07
		_animate_flip_piece_at_cell(f_idx, gamer_id, delay_sec)

	piece_placed.emit(target_idx, flips.size())

func _animate_flip_piece_at_cell(cell_idx: int, new_gamer_id: int, delay_sec: float) -> void:
	var p_node: Node3D = null
	if pieces_nodes.has(cell_idx) and is_instance_valid(pieces_nodes[cell_idx]):
		p_node = pieces_nodes[cell_idx]
	else:
		p_node = _spawn_piece_at_cell(cell_idx, new_gamer_id)
		return

	p_node.set_meta("gamer_id", new_gamer_id)
	var flip_pivot = p_node.get_node_or_null("FlipPivot") as Node3D
	if not flip_pivot:
		return

	var base_pos = Vector3(cells[cell_idx].position.x, 0.048, cells[cell_idx].position.z)
	var apex_pos = base_pos + Vector3(0.0, 0.115, 0.0)
	var target_rot_x = 0.0 if new_gamer_id == 1 else PI

	var tw = create_tween()
	if delay_sec > 0.0:
		tw.tween_interval(delay_sec)

	# Leap upward to mid-air apex while starting 180-degree somersault flip
	tw.tween_callback(func():
		AudioManager.play_sound("move_peace")
	)
	tw.tween_property(p_node, "position", apex_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flip_pivot, "rotation:x", target_rot_x, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(p_node, "scale", Vector3(1.12, 1.12, 1.12), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Land back onto square with crisp impact burst
	tw.chain().tween_property(p_node, "position", base_pos, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p_node, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_spawn_flip_shockwave_vfx(base_pos, new_gamer_id)
	)

func _spawn_flip_shockwave_vfx(pos_3d: Vector3, gamer_id: int) -> void:
	var vfx_root = Node3D.new()
	vfx_root.position = pos_3d + Vector3(0.0, 0.004, 0.0)
	add_child(vfx_root)

	var ring_mat = StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.34, 0.26, 0.88) if gamer_id == 1 else Color(0.28, 0.72, 1.0, 0.88)

	var ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.024
	torus.outer_radius = 0.035
	torus.rings = 24
	torus.ring_segments = 16
	torus.material = ring_mat
	ring_mesh.mesh = torus
	vfx_root.add_child(ring_mesh)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring_mesh, "scale", Vector3(2.1, 1.0, 2.1), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(func():
		if is_instance_valid(vfx_root):
			vfx_root.queue_free()
	)

func _update_last_move_highlights(placed_idx: int, flipped_indices: Array[int]) -> void:
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()

	if placed_idx >= 0 and placed_idx < cells.size():
		var area = cells[placed_idx]
		var marker = MeshInstance3D.new()
		var plane = BoxMesh.new()
		plane.size = Vector3(cell_size * 0.96, 0.005, cell_size * 0.96)
		plane.material = mat_last_move
		marker.mesh = plane
		marker.position = Vector3(area.position.x, 0.049, area.position.z)
		add_child(marker)
		last_move_markers.append(marker)

	for f_idx in flipped_indices:
		if f_idx >= 0 and f_idx < cells.size():
			var f_area = cells[f_idx]
			var f_marker = MeshInstance3D.new()
			var f_plane = BoxMesh.new()
			f_plane.size = Vector3(cell_size * 0.92, 0.004, cell_size * 0.92)
			f_plane.material = mat_flipped_highlight
			f_marker.mesh = f_plane
			f_marker.position = Vector3(f_area.position.x, 0.0488, f_area.position.z)
			add_child(f_marker)
			last_move_markers.append(f_marker)

# --- Lifecycle & Reconnect State Synchronization ---

func setup_board(game_data: Dictionary) -> void:
	reset_board()
	update_board_orientation(GameManager.my_player_index)
	super._ready()
	if game_data.has("board"):
		sync_board_state(game_data["board"])
	_sync_hud_scores()
	if is_my_turn:
		update_legal_moves_for_turn()

func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != 64:
		return
	update_board_orientation(GameManager.my_player_index)
	var b_arr = new_board as Array
	_clear_markers()

	for i in range(64):
		var raw = b_arr[i]
		var g_id = 0
		if typeof(raw) == TYPE_DICTIONARY:
			g_id = int(raw.get("pawn_gamer_id", raw.get("gamer_id", 0)))
		else:
			g_id = int(raw)
		board_data[i] = clampi(g_id, 0, 2)

	_recalculate_scores_from_board()
	_spawn_all_pieces_on_board()
	_sync_hud_scores()
	if is_my_turn:
		update_legal_moves_for_turn()

func on_reconnect_data(payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	update_board_orientation(my_player_index)
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("pawns_count") and typeof(g_data["pawns_count"]) == TYPE_ARRAY and (g_data["pawns_count"] as Array).size() >= 2:
			player1_pawns = int(g_data["pawns_count"][0])
			player2_pawns = int(g_data["pawns_count"][1])
			_sync_reserve_trays()
		if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
			player1_score = int(g_data["scores"][0])
			player2_score = int(g_data["scores"][1])
			_sync_hud_scores()
	sync_turn_state()

func reset_board() -> void:
	_clear_markers()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()
	current_legal_moves.clear()
	_init_board_data()
	_spawn_all_pieces_on_board()
	_sync_reserve_trays()
	_sync_hud_scores()
	update_board_orientation(GameManager.my_player_index)

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	_clear_markers()

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
	for p in reserve_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_red_nodes.clear()
	for p in reserve_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_blue_nodes.clear()
	current_legal_moves.clear()
	board_data.clear()
