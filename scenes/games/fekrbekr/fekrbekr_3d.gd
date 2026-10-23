class_name FekrBekr3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# FekrBekr (Mastermind / فکر و بکر) 3D Board Implementation
# Cafe Fekr - High-end Board Game Experience
#
# Rules & Flow:
# 1. Phase 1 (Setup Phase, 60s):
#    - Shows deluxe Walnut & Brass Setup Tray with 4 secret slots and the 8-color palette.
#    - Player selects 4 distinct colors for the opponent to find (Save_Board).
#    - ONLY Checkmark (✓) and Cross (✕) HUD buttons are shown.
# 2. Phase 2 (Play Phase, 12 Tries):
#    - Transitions to full 12-row 3D playing board with spacious row pitch (+33% spacing).
#    - Player guesses opponent's code (Select_Peace).
#    - Server feedback pins (2x2 grid): Obsidian Black = exact match, Ivory White = color match.
#    - All 4 HUD buttons (✓, ✕, 🎯, 👥) are active.
# ==============================================================================

# --- Camera Tuning for Full 12-Row Board ---
@export var camera_distance: float = 3.35
@export var camera_pitch: float = -1.16

# --- Geometry Constants (Phase 2 Playing Board) ---
const BOARD_W: float = 0.60
const BOARD_L: float = 1.72
const BOARD_H: float = 0.028
const NUM_VISIBLE_ROWS: int = 12
const NUM_PEGS: int = 4

# Row distribution for 12 guess rows:
# Row 0 (bottom / 1st try) to Row 11 (top / 12th try)
# Span: 0.38 - (-0.66) = 1.04m across 11 gaps = 0.0945m (9.45 cm) pitch per row (+33% spacing increase!)
const ROW_Z_BOTTOM: float = 0.38
const ROW_Z_TOP: float = -0.66

# Peg X offsets (center-left area)
const PEG_X_OFFSETS = [-0.19, -0.10, -0.01, +0.08]

# Pin Pad (large, prominent feedback pins)
const PIN_GRID_X: float = 0.190
const PIN_OFFSET: float = 0.020

# Active Input Row & Palette
const ACTIVE_ROW_Z: float = 0.505
const PALETTE_ROW1_Z: float = 0.615
const PALETTE_ROW2_Z: float = 0.715
const PALETTE_X_OFFSETS = [-0.16, -0.05, +0.05, +0.16]

# --- Phase 1 Setup Tray Dimensions (Luxury Jewelry/Game Tray) ---
const TRAY_W: float = 0.56
const TRAY_L: float = 0.48
const TRAY_H: float = 0.030
const TRAY_SECRET_Z: float = -0.09
const TRAY_PALETTE_R1_Z: float = 0.05
const TRAY_PALETTE_R2_Z: float = 0.15
const TRAY_SECRET_X_OFFSETS = [-0.16, -0.05, 0.05, 0.16]
const TRAY_PALETTE_X_OFFSETS = [-0.16, -0.05, 0.05, 0.16]

# --- Color Definitions (8 Unique Gemstone Marbles, NO Numbers) ---
const COLOR_VALUES: Dictionary = {
	1: Color(0.92, 0.16, 0.18), # Red Ruby
	2: Color(0.18, 0.45, 0.95), # Blue Sapphire
	3: Color(0.18, 0.82, 0.32), # Emerald Green
	4: Color(0.98, 0.85, 0.12), # Amber Gold
	5: Color(0.68, 0.22, 0.88), # Amethyst Purple
	6: Color(0.98, 0.52, 0.12), # Carnelian Orange
	7: Color(0.12, 0.82, 0.88), # Turquoise Cyan
	8: Color(0.94, 0.94, 0.94), # Pearl White
}

enum ViewMode { MY_BOARD, OPP_BOARD, DUAL }

# --- State ---
var is_play_phase: bool = false
var current_round_num: int = 0
var current_view_mode: ViewMode = ViewMode.MY_BOARD

# Phase 1 setup selection [c0, c1, c2, c3]
var phase1_selection: Array = [0, 0, 0, 0]
var is_my_board_set: bool = false
var my_secret_board: Array = [0, 0, 0, 0]

# Phase 2 active guess selection
var active_selection: Array = [0, 0, 0, 0]
var is_revealed: bool = false

# History of guesses
var my_choices: Array = []
var my_results: Array = []
var opp_choices: Array = []
var opp_results: Array = []

# --- Node Hierarchy Roots ---
var phase1_root: Node3D = null
var phase2_root: Node3D = null
var my_board_root: Node3D = null
var opp_board_root: Node3D = null

# Phase 1 Nodes
var phase1_slot_nodes: Array[Node3D] = []
var phase1_slot_pieces: Array[MeshInstance3D] = []

# Phase 2 Row Nodes
var my_row_containers: Array[Node3D] = []
var my_row_pin_nodes: Array[Array] = []
var opp_row_containers: Array[Node3D] = []
var opp_row_pin_nodes: Array[Array] = []

# Active input slot nodes (Phase 2)
var active_slot_nodes: Array[Node3D] = []
var active_slot_pieces: Array[MeshInstance3D] = []

# Pointers
var my_row_pointer: Node3D = null
var opp_row_pointer: Node3D = null

# Materials
var mat_wood_base: StandardMaterial3D
var mat_wood_rim: StandardMaterial3D
var mat_slate_player: StandardMaterial3D
var mat_slate_opp: StandardMaterial3D
var mat_brass_trim: StandardMaterial3D
var mat_socket_rim: StandardMaterial3D
var mat_gold_ring: StandardMaterial3D
var mat_hole_concave: StandardMaterial3D
var mat_pin_black: StandardMaterial3D
var mat_pin_white: StandardMaterial3D
var piece_materials: Dictionary = {}

func _init() -> void:
	game_type = GameTypes.FEKRBEKR

# ==============================================================================
# 1. INITIALIZATION & MATERIALS
# ==============================================================================

func _ready() -> void:
	game_type = GameTypes.FEKRBEKR
	_init_materials()
	_build_scene_hierarchy()
	_connect_hud_signals()
	super._ready()
	set_phase(is_play_phase)

func _init_materials() -> void:
	# Wooden plinth: rich walnut with subtle luster
	mat_wood_base = StandardMaterial3D.new()
	mat_wood_base.albedo_color = Color(0.18, 0.10, 0.05)
	mat_wood_base.roughness = 0.45
	mat_wood_base.metallic_specular = 0.50

	mat_wood_rim = StandardMaterial3D.new()
	mat_wood_rim.albedo_color = Color(0.13, 0.07, 0.03)
	mat_wood_rim.roughness = 0.40

	# Player Slate (deep graphite charcoal satin)
	mat_slate_player = StandardMaterial3D.new()
	mat_slate_player.albedo_color = Color(0.08, 0.09, 0.11)
	mat_slate_player.roughness = 0.32

	# Opponent Slate (subtle navy graphite)
	mat_slate_opp = StandardMaterial3D.new()
	mat_slate_opp.albedo_color = Color(0.07, 0.09, 0.13)
	mat_slate_opp.roughness = 0.32

	# Polished Brass Trim & Corner Brackets
	mat_brass_trim = StandardMaterial3D.new()
	mat_brass_trim.albedo_color = Color(0.88, 0.72, 0.30)
	mat_brass_trim.metallic = 0.90
	mat_brass_trim.roughness = 0.22

	# Machined Socket Rim
	mat_socket_rim = StandardMaterial3D.new()
	mat_socket_rim.albedo_color = Color(0.75, 0.60, 0.25)
	mat_socket_rim.metallic = 0.85
	mat_socket_rim.roughness = 0.28

	# Active Gold Ring (pulsing emissive glow)
	mat_gold_ring = StandardMaterial3D.new()
	mat_gold_ring.albedo_color = Color(1.0, 0.86, 0.28)
	mat_gold_ring.metallic = 0.95
	mat_gold_ring.roughness = 0.18
	mat_gold_ring.emission_enabled = true
	mat_gold_ring.emission = Color(0.50, 0.38, 0.08)

	# Concave socket hole interior
	mat_hole_concave = StandardMaterial3D.new()
	mat_hole_concave.albedo_color = Color(0.03, 0.03, 0.03)
	mat_hole_concave.roughness = 0.90

	# Feedback Pins: Glossy Jet-Black Obsidian & Porcelain Pearl White
	mat_pin_black = StandardMaterial3D.new()
	mat_pin_black.albedo_color = Color(0.02, 0.02, 0.02)
	mat_pin_black.roughness = 0.12
	mat_pin_black.metallic = 0.15
	mat_pin_black.clearcoat_enabled = true
	mat_pin_black.clearcoat = 0.80

	mat_pin_white = StandardMaterial3D.new()
	mat_pin_white.albedo_color = Color(0.98, 0.98, 0.96)
	mat_pin_white.roughness = 0.12
	mat_pin_white.metallic = 0.05
	mat_pin_white.clearcoat_enabled = true
	mat_pin_white.clearcoat = 0.80

	# 8 Pure 3D Colored Gemstone Marble Materials
	for color_id in COLOR_VALUES.keys():
		var col = COLOR_VALUES[color_id]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.10
		mat.metallic = 0.08
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.85
		piece_materials[color_id] = mat

func _connect_hud_signals() -> void:
	# Signal connections are managed centrally by Main scene to prevent duplicate triggers
	pass

func _get_hud() -> Control:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud):
		return hud
	return null

# ==============================================================================
# 2. SCENE HIERARCHY SETUP
# ==============================================================================

func _build_scene_hierarchy() -> void:
	# Root for Phase 1 (Deluxe Setup Tray)
	phase1_root = Node3D.new()
	phase1_root.name = "Phase1Root"
	add_child(phase1_root)
	_build_phase1_tray(phase1_root)

	# Root for Phase 2 (12-Row Playing Boards)
	phase2_root = Node3D.new()
	phase2_root.name = "Phase2Root"
	add_child(phase2_root)

	my_board_root = Node3D.new()
	my_board_root.name = "MyBoard"
	phase2_root.add_child(my_board_root)
	_build_play_board(my_board_root, mat_slate_player, true)

	opp_board_root = Node3D.new()
	opp_board_root.name = "OpponentBoard"
	phase2_root.add_child(opp_board_root)
	_build_play_board(opp_board_root, mat_slate_opp, false)

	_apply_view_mode_positions(ViewMode.MY_BOARD, false)

func set_phase(play_phase: bool) -> void:
	is_play_phase = play_phase
	var hud = _get_hud()
	if hud and hud.has_method("set_fekrbekr_hud_buttons"):
		hud.set_fekrbekr_hud_buttons(play_phase)
	if not is_instance_valid(phase1_root) or not is_instance_valid(phase2_root):
		return
	if not play_phase:
		phase1_root.visible = true
		phase2_root.visible = false
		_clear_phase1_selection()
	else:
		phase1_root.visible = false
		phase2_root.visible = true
		_update_active_row_pointer(my_row_pointer, current_round_num - 1 if current_round_num > 0 else 0)

# ==============================================================================
# 3. PHASE 1: DELUXE SETUP TRAY (SECRET CODE SELECTION)
# ==============================================================================

func _build_phase1_tray(root: Node3D) -> void:
	# 1. Beveled Walnut Plinth
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(TRAY_W + 0.04, TRAY_H, TRAY_L + 0.04)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, -TRAY_H * 0.5, 0)
	root.add_child(plinth)

	# 2. Inset Graphite Playing Slab
	var slab = MeshInstance3D.new()
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(TRAY_W, 0.014, TRAY_L)
	slab_mesh.material = mat_slate_player
	slab.mesh = slab_mesh
	slab.position = Vector3(0, 0.007, 0)
	root.add_child(slab)

	# 3. Brass Perimeter Bezel & Luxury Corner Brackets
	_create_bezel(root, TRAY_W, TRAY_L, 0.014)
	_create_corner_brackets(root, TRAY_W, TRAY_L, 0.014)

	# 4. Inlaid Decorative Brass Divider between Secret Slots and Palette
	var div = MeshInstance3D.new()
	var div_m = BoxMesh.new()
	div_m.size = Vector3(TRAY_W - 0.06, 0.003, 0.003)
	div_m.material = mat_brass_trim
	div.mesh = div_m
	div.position = Vector3(0, 0.015, -0.015)
	root.add_child(div)

	# 5. The 4 Secret Code Sockets (stepped brass chalice cups)
	phase1_slot_nodes.clear()
	phase1_slot_pieces.clear()
	for col in range(NUM_PEGS):
		var pos_x = TRAY_SECRET_X_OFFSETS[col]
		var sock_node = _create_chalice_socket_mesh(0.026, 0.008, mat_hole_concave, mat_gold_ring)
		sock_node.position = Vector3(pos_x, 0.014, TRAY_SECRET_Z)
		root.add_child(sock_node)
		phase1_slot_nodes.append(sock_node)

		var piece = _create_piece_mesh(1)
		piece.position = Vector3(pos_x, 0.034, TRAY_SECRET_Z)
		piece.visible = false
		root.add_child(piece)
		phase1_slot_pieces.append(piece)

		# Tap to clear slot
		_create_slot_click_area(root, Vector3(pos_x, 0.025, TRAY_SECRET_Z), 0.030, func(c=col):
			_on_phase1_slot_clicked(c)
		)

	# 6. 8-Color Gemstone Palette (2 rows of 4)
	_build_palette(root, TRAY_PALETTE_R1_Z, TRAY_PALETTE_R2_Z, TRAY_PALETTE_X_OFFSETS, 0.014, func(color_id):
		_on_phase1_color_selected(color_id)
	)

func _on_phase1_color_selected(color_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or is_play_phase:
		return
	# Find next empty slot
	for i in range(4):
		if phase1_selection[i] == 0:
			phase1_selection[i] = color_id
			AudioManager.play_sound("tap")
			_animate_slot_placement(phase1_slot_pieces[i], color_id)
			return
	AudioManager.play_sound("tap_wrong")
	show_hint("همه ۴ جایگاه رمز پر شده‌اند. برای حذف روی مهره کلیک کنید.")

func _on_phase1_slot_clicked(col_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or is_play_phase:
		return
	if phase1_selection[col_idx] != 0:
		AudioManager.play_sound("tap")
		phase1_selection[col_idx] = 0
		_animate_slot_removal(phase1_slot_pieces[col_idx])

func _clear_phase1_selection() -> void:
	phase1_selection = [0, 0, 0, 0]
	_update_phase1_slots()

func _update_phase1_slots() -> void:
	if phase1_slot_pieces.size() < 4:
		return
	for i in range(4):
		var c_id = int(phase1_selection[i])
		var p_mesh = phase1_slot_pieces[i]
		if c_id > 0:
			p_mesh.material_override = piece_materials[c_id]
			p_mesh.visible = true
			p_mesh.scale = Vector3.ONE
		else:
			p_mesh.visible = false

# ==============================================================================
# 4. PHASE 2: FULL 12-ROW PLAYING BOARD (+33% ROW PITCH)
# ==============================================================================

func _build_play_board(root: Node3D, slate_mat: Material, is_player_board: bool) -> void:
	# 1. Walnut Plinth
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(BOARD_W + 0.04, BOARD_H, BOARD_L + 0.04)
	plinth_mesh.material = mat_wood_base
	plinth.mesh = plinth_mesh
	plinth.position = Vector3(0, -BOARD_H * 0.5, 0)
	root.add_child(plinth)

	# 2. Inset Graphite Playing Slab
	var slab = MeshInstance3D.new()
	var slab_mesh = BoxMesh.new()
	slab_mesh.size = Vector3(BOARD_W, 0.014, BOARD_L)
	slab_mesh.material = slate_mat
	slab.mesh = slab_mesh
	slab.position = Vector3(0, 0.007, 0)
	root.add_child(slab)

	# 3. Perimeter Bezel & Corner Brackets
	_create_bezel(root, BOARD_W, BOARD_L, 0.014)
	_create_corner_brackets(root, BOARD_W, BOARD_L, 0.014)

	if is_player_board:
		my_row_containers.clear()
		my_row_pin_nodes.clear()
		_build_12_rows(root, my_row_containers, my_row_pin_nodes)
		my_row_pointer = _create_pointer_mesh()
		my_row_pointer.position = Vector3(-BOARD_W * 0.5 + 0.018, 0.014, _get_row_z(0))
		root.add_child(my_row_pointer)

		# Active Guess Input Row (4 luminous gold chalice sockets)
		_build_active_input_row(root)

		# 8-Color Palette
		_build_palette(root, PALETTE_ROW1_Z, PALETTE_ROW2_Z, PALETTE_X_OFFSETS, 0.014, func(color_id):
			_on_phase2_color_selected(color_id)
		)
	else:
		opp_row_containers.clear()
		opp_row_pin_nodes.clear()
		_build_12_rows(root, opp_row_containers, opp_row_pin_nodes)
		opp_row_pointer = _create_pointer_mesh()
		opp_row_pointer.position = Vector3(-BOARD_W * 0.5 + 0.018, 0.014, _get_row_z(0))
		root.add_child(opp_row_pointer)

func _build_12_rows(root: Node3D, containers: Array[Node3D], pin_arrays: Array[Array]) -> void:
	var pin_coords = [
		Vector2(-PIN_OFFSET, -PIN_OFFSET),
		Vector2(PIN_OFFSET, -PIN_OFFSET),
		Vector2(-PIN_OFFSET, PIN_OFFSET),
		Vector2(PIN_OFFSET, PIN_OFFSET)
	]

	var step = (ROW_Z_BOTTOM - ROW_Z_TOP) / float(NUM_VISIBLE_ROWS - 1)

	for r in range(NUM_VISIBLE_ROWS):
		var z_pos = _get_row_z(r)
		var row_node = Node3D.new()
		row_node.name = "Row_%d" % r
		row_node.position = Vector3(0, 0.014, z_pos)
		root.add_child(row_node)
		containers.append(row_node)

		# Dedicated container for guess pieces (CRUCIAL for clean reloads without deleting sockets)
		var pieces_container = Node3D.new()
		pieces_container.name = "PiecesContainer"
		row_node.add_child(pieces_container)

		# Inlaid Brass Divider between rows
		if r < NUM_VISIBLE_ROWS - 1:
			var div = MeshInstance3D.new()
			var div_m = BoxMesh.new()
			div_m.size = Vector3(BOARD_W - 0.06, 0.003, 0.003)
			div_m.material = mat_brass_trim
			div.mesh = div_m
			div.position = Vector3(0, 0.002, -step * 0.5)
			row_node.add_child(div)

		# 4 Concave Peg Sockets
		for col in range(NUM_PEGS):
			var pos_x = PEG_X_OFFSETS[col]
			var sock = _create_chalice_socket_mesh(0.023, 0.007, mat_hole_concave, mat_socket_rim)
			sock.position = Vector3(pos_x, 0.002, 0)
			row_node.add_child(sock)

		# 2x2 Feedback Pin Pad (LARGE, Prominent Obsidian Black / Ivory Pearl Marbles)
		var pad = MeshInstance3D.new()
		var pad_m = BoxMesh.new()
		pad_m.size = Vector3(0.084, 0.005, 0.084)
		pad_m.material = mat_hole_concave
		pad.mesh = pad_m
		pad.position = Vector3(PIN_GRID_X, 0.002, 0)
		row_node.add_child(pad)

		# Polished rim around pin pad
		var pad_rim = MeshInstance3D.new()
		var pad_rim_m = BoxMesh.new()
		pad_rim_m.size = Vector3(0.088, 0.003, 0.088)
		pad_rim_m.material = mat_brass_trim
		pad_rim.mesh = pad_rim_m
		pad_rim.position = Vector3(PIN_GRID_X, 0.001, 0)
		row_node.add_child(pad_rim)

		var pins_for_row: Array = []
		for p_idx in range(4):
			var offset = pin_coords[p_idx]
			var pin_x = PIN_GRID_X + offset.x
			var pin_z = offset.y

			var p_sock = _create_chalice_socket_mesh(0.013, 0.004, mat_hole_concave, mat_brass_trim)
			p_sock.position = Vector3(pin_x, 0.004, pin_z)
			row_node.add_child(p_sock)

			var p_mesh = MeshInstance3D.new()
			var sph = SphereMesh.new()
			sph.radius = 0.015
			sph.height = 0.018
			sph.material = mat_pin_black
			p_mesh.mesh = sph
			p_mesh.position = Vector3(pin_x, 0.015, pin_z)
			p_mesh.visible = false
			row_node.add_child(p_mesh)
			pins_for_row.append(p_mesh)

		pin_arrays.append(pins_for_row)

func _get_row_z(row_idx: int) -> float:
	var step = (ROW_Z_BOTTOM - ROW_Z_TOP) / float(NUM_VISIBLE_ROWS - 1)
	return ROW_Z_BOTTOM - (float(row_idx) * step)

func _build_active_input_row(root: Node3D) -> void:
	active_slot_nodes.clear()
	active_slot_pieces.clear()

	# Brass separator bar above active row
	var div = MeshInstance3D.new()
	var div_m = BoxMesh.new()
	div_m.size = Vector3(BOARD_W - 0.06, 0.004, 0.004)
	div_m.material = mat_gold_ring
	div.mesh = div_m
	div.position = Vector3(0, 0.016, ACTIVE_ROW_Z - 0.055)
	root.add_child(div)

	for col in range(NUM_PEGS):
		var pos_x = PEG_X_OFFSETS[col]
		var sock = _create_chalice_socket_mesh(0.026, 0.008, mat_hole_concave, mat_gold_ring)
		sock.position = Vector3(pos_x, 0.014, ACTIVE_ROW_Z)
		root.add_child(sock)
		active_slot_nodes.append(sock)

		var piece = _create_piece_mesh(1)
		piece.position = Vector3(pos_x, 0.034, ACTIVE_ROW_Z)
		piece.visible = false
		root.add_child(piece)
		active_slot_pieces.append(piece)

		_create_slot_click_area(root, Vector3(pos_x, 0.025, ACTIVE_ROW_Z), 0.030, func(c=col):
			_on_active_slot_clicked(c)
		)

func _build_palette(root: Node3D, r1_z: float, r2_z: float, x_offsets: Array, slab_y: float, on_color_clicked: Callable) -> void:
	for i in range(8):
		var color_id = i + 1
		var is_r1 = (i < 4)
		var col_idx = i if is_r1 else (i - 4)
		var p_x = x_offsets[col_idx]
		var p_z = r1_z if is_r1 else r2_z

		# Polished Brass Pedestal Dish
		var dish = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.027
		cyl.bottom_radius = 0.023
		cyl.height = 0.006
		dish.mesh = cyl
		dish.material_override = mat_brass_trim
		dish.position = Vector3(p_x, slab_y + 0.003, p_z)
		root.add_child(dish)

		# Gemstone Marble
		var piece = _create_piece_mesh(color_id)
		piece.position = Vector3(p_x, slab_y + 0.023, p_z)
		root.add_child(piece)

		# Click Area3D
		var area = Area3D.new()
		var col_shape = CollisionShape3D.new()
		var sph_shape = SphereShape3D.new()
		sph_shape.radius = 0.032
		col_shape.shape = sph_shape
		area.add_child(col_shape)
		area.position = piece.position
		root.add_child(area)

		area.input_event.connect(func(_cam, ev, _pos, _norm, _idx):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				on_color_clicked.call(color_id)
		)

func _create_bezel(root: Node3D, w: float, l: float, y_h: float) -> void:
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(w + 0.008, 0.012, 0.008)
	h_mesh.material = mat_brass_trim

	var v_mesh = BoxMesh.new()
	v_mesh.size = Vector3(0.008, 0.012, l + 0.008)
	v_mesh.material = mat_brass_trim

	var b_top = MeshInstance3D.new()
	b_top.mesh = h_mesh
	b_top.position = Vector3(0, y_h + 0.004, -l * 0.5)
	root.add_child(b_top)

	var b_bot = MeshInstance3D.new()
	b_bot.mesh = h_mesh
	b_bot.position = Vector3(0, y_h + 0.004, l * 0.5)
	root.add_child(b_bot)

	var b_left = MeshInstance3D.new()
	b_left.mesh = v_mesh
	b_left.position = Vector3(-w * 0.5, y_h + 0.004, 0)
	root.add_child(b_left)

	var b_right = MeshInstance3D.new()
	b_right.mesh = v_mesh
	b_right.position = Vector3(w * 0.5, y_h + 0.004, 0)
	root.add_child(b_right)

func _create_corner_brackets(root: Node3D, w: float, l: float, y_h: float) -> void:
	var offsets = [
		Vector3(-w * 0.5 + 0.016, y_h + 0.006, -l * 0.5 + 0.016),
		Vector3(w * 0.5 - 0.016, y_h + 0.006, -l * 0.5 + 0.016),
		Vector3(-w * 0.5 + 0.016, y_h + 0.006, l * 0.5 - 0.016),
		Vector3(w * 0.5 - 0.016, y_h + 0.006, l * 0.5 - 0.016)
	]
	for pos in offsets:
		var stud = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.024, 0.006, 0.024)
		sm.material = mat_brass_trim
		stud.mesh = sm
		stud.position = pos
		root.add_child(stud)

func _create_slot_click_area(root: Node3D, pos: Vector3, radius: float, callback: Callable) -> void:
	var area = Area3D.new()
	var col_shape = CollisionShape3D.new()
	var sph = SphereShape3D.new()
	sph.radius = radius
	col_shape.shape = sph
	area.add_child(col_shape)
	area.position = pos
	root.add_child(area)

	area.input_event.connect(func(_cam, ev, _pos, _norm, _idx):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			callback.call()
	)

func _create_piece_mesh(color_id: int) -> MeshInstance3D:
	var inst = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.023
	sph.height = 0.023
	sph.radial_segments = 32
	sph.rings = 16
	inst.mesh = sph
	inst.material_override = piece_materials.get(color_id, mat_pin_white)
	return inst

func _create_chalice_socket_mesh(radius: float, depth: float, concave_mat: Material, rim_mat: Material) -> Node3D:
	var root_node = Node3D.new()
	var hole = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.75
	cyl.height = depth
	cyl.radial_segments = 28
	hole.mesh = cyl
	hole.material_override = concave_mat
	hole.position = Vector3(0, -depth * 0.5, 0)
	root_node.add_child(hole)

	var rim = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.004
	torus.rings = 20
	torus.ring_segments = 20
	rim.mesh = torus
	rim.material_override = rim_mat
	rim.position = Vector3(0, 0.001, 0)
	root_node.add_child(rim)
	return root_node

func _create_pointer_mesh() -> Node3D:
	var node = Node3D.new()
	var ptr = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(0.028, 0.028, 0.014)
	prism.material = mat_brass_trim
	ptr.mesh = prism
	ptr.rotation_degrees = Vector3(0, 0, -90)
	node.add_child(ptr)
	return node

func _update_active_row_pointer(pointer: Node3D, row_idx: int) -> void:
	if not is_instance_valid(pointer):
		return
	var clamped_idx = clampi(row_idx, 0, NUM_VISIBLE_ROWS - 1)
	var target_z = _get_row_z(clamped_idx)
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pointer, "position:z", target_z, 0.35)

func _animate_slot_placement(piece_mesh: MeshInstance3D, color_id: int) -> void:
	if not is_instance_valid(piece_mesh):
		return
	piece_mesh.material_override = piece_materials[color_id]
	piece_mesh.visible = true
	piece_mesh.scale = Vector3(0.3, 0.3, 0.3)
	var final_y = piece_mesh.position.y
	piece_mesh.position.y = final_y + 0.035
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(piece_mesh, "scale", Vector3.ONE, 0.25)
	tw.tween_property(piece_mesh, "position:y", final_y, 0.25)

func _animate_slot_removal(piece_mesh: MeshInstance3D) -> void:
	if not is_instance_valid(piece_mesh):
		return
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(piece_mesh, "scale", Vector3(0.1, 0.1, 0.1), 0.15)
	tw.tween_callback(func():
		piece_mesh.visible = false
		piece_mesh.scale = Vector3.ONE
	)

# ==============================================================================
# 5. INPUT & SELECTION LOGIC
# ==============================================================================

func _on_phase2_color_selected(color_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or not is_play_phase:
		return
	for i in range(4):
		if active_selection[i] == 0:
			active_selection[i] = color_id
			AudioManager.play_sound("tap")
			_animate_slot_placement(active_slot_pieces[i], color_id)
			return
	AudioManager.play_sound("tap_wrong")
	show_hint("همه ۴ مهره حدس انتخاب شده‌اند. برای ارسال دکمه تایید (✓) را بزنید.")

func _on_active_slot_clicked(col_idx: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked or not is_play_phase:
		return
	if active_selection[col_idx] != 0:
		AudioManager.play_sound("tap")
		active_selection[col_idx] = 0
		_animate_slot_removal(active_slot_pieces[col_idx])

func _clear_current_selection() -> void:
	if not GameManager.is_game_active or is_board_locked:
		return
	if not is_play_phase:
		_clear_phase1_selection()
	else:
		active_selection = [0, 0, 0, 0]
		_update_active_slots()
	AudioManager.play_sound("tap")

func _update_active_slots() -> void:
	if active_slot_pieces.size() < 4:
		return
	for i in range(4):
		var c_id = int(active_selection[i])
		var p_mesh = active_slot_pieces[i]
		if c_id > 0:
			p_mesh.material_override = piece_materials[c_id]
			p_mesh.visible = true
			p_mesh.scale = Vector3.ONE
		else:
			p_mesh.visible = false

# ==============================================================================
# 6. ACTION BUTTON HANDLERS (SUBMIT, CLEAR, VIEWS)
# ==============================================================================

func _on_hud_submit_pressed() -> void:
	_submit_selection()

func _on_hud_clear_pressed() -> void:
	_clear_current_selection()

func _on_hud_opponent_pressed() -> void:
	if not GameManager.is_game_active:
		return
	AudioManager.play_sound("tap_button")
	if current_view_mode == ViewMode.OPP_BOARD:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)
		show_hint("نمایش صفحه شما")
	else:
		_apply_view_mode_positions(ViewMode.OPP_BOARD, true)
		show_hint("نمایش حدس‌های حریف")

func _on_hud_dual_pressed() -> void:
	if not GameManager.is_game_active:
		return
	AudioManager.play_sound("tap_button")
	if current_view_mode == ViewMode.DUAL:
		_apply_view_mode_positions(ViewMode.MY_BOARD, true)
		show_hint("نمایش صفحه شما")
	else:
		_apply_view_mode_positions(ViewMode.DUAL, true)
		show_hint("نمایش همزمان هر دو صفحه")

func _submit_selection() -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked:
		return

	if not is_play_phase:
		# Phase 1: Submit Secret Board for Opponent
		for v in phase1_selection:
			if v <= 0:
				show_hint("لطفاً همه ۴ مهره رمز را انتخاب کنید.")
				AudioManager.play_sound("tap_wrong")
				return

		# Verify all 4 colors are distinct
		var uniq = []
		for v in phase1_selection:
			if v in uniq:
				show_hint("رنگ‌های رمز باید متفاوت از یکدیگر باشند.")
				AudioManager.play_sound("tap_wrong")
				return
			uniq.append(v)

		set_board_locked(true)
		AudioManager.play_sound("tap_button")
		NetworkManager.send_save_board(phase1_selection)

		# Hide board and show waiting state until Phase 2 starts
		if is_instance_valid(phase1_root):
			phase1_root.visible = false

		var hud = _get_hud()
		if hud and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("رمز شما برای حریف ثبت شد. در انتظار حریف...")
	else:
		# Phase 2: Submit Guess for Active Row
		for v in active_selection:
			if v <= 0:
				show_hint("لطفاً همه ۴ مهره حدس را انتخاب کنید.")
				AudioManager.play_sound("tap_wrong")
				return

		set_board_locked(true)
		AudioManager.play_sound("tap_button")
		NetworkManager.send_select_peace(active_selection)

		var hud = _get_hud()
		if hud and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("حدس شما ثبت شد. در انتظار ثبت حرکت حریف...")

func _apply_view_mode_positions(mode: ViewMode, animate: bool = true) -> void:
	current_view_mode = mode
	var my_pos = Vector3.ZERO
	var opp_pos = Vector3.ZERO

	match mode:
		ViewMode.MY_BOARD:
			my_pos = Vector3.ZERO
			opp_pos = Vector3(3.0, 0, 0) # Offscreen
		ViewMode.OPP_BOARD:
			my_pos = Vector3(-3.0, 0, 0) # Offscreen
			opp_pos = Vector3.ZERO
		ViewMode.DUAL:
			my_pos = Vector3(-0.35, 0, 0)
			opp_pos = Vector3(0.35, 0, 0)

	if animate:
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(my_board_root, "position", my_pos, 0.45)
		tw.tween_property(opp_board_root, "position", opp_pos, 0.45)
	else:
		my_board_root.position = my_pos
		opp_board_root.position = opp_pos

# ==============================================================================
# 7. BASEGAMEBOARD VIRTUAL HOOKS
# ==============================================================================

func setup_board(_game_data: Dictionary) -> void:
	set_phase(false)
	current_round_num = 0
	set_board_locked(not GameManager.is_game_active)
	if GameManager.is_game_active:
		var hud = _get_hud()
		if hud and hud.has_method("set_setup_phase"):
			hud.set_setup_phase()

func on_start_game() -> void:
	set_phase(false)
	current_round_num = 0
	set_board_locked(false)
	var hud = _get_hud()
	if hud and hud.has_method("set_setup_phase"):
		hud.set_setup_phase()

func on_turn_changed(turn: int, _is_me: bool) -> void:
	if turn == 0:
		set_phase(false)
		current_round_num = 0
		set_board_locked(not GameManager.is_game_active)
		if GameManager.is_game_active:
			var hud = _get_hud()
			if hud and hud.has_method("set_setup_phase"):
				hud.set_setup_phase()
		return

	# Phase 2: Play Phase
	set_phase(true)
	current_round_num = turn
	set_board_locked(false)
	_clear_current_selection()

	_update_active_row_pointer(my_row_pointer, current_round_num - 1)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var guess_data: Array = []
	var result_data: Array = []

	if extra.has("data") and typeof(extra["data"]) == TYPE_ARRAY:
		guess_data = extra["data"]
	if extra.has("result") and typeof(extra["result"]) == TYPE_ARRAY:
		result_data = extra["result"]

	if guess_data.is_empty():
		return

	if user_id == my_player_index:
		# Player's guess -> Place on My Board
		my_choices.append(guess_data)
		my_results.append(result_data)
		var r_idx = my_choices.size() - 1
		_render_guess_row_on_board(my_row_containers, my_row_pin_nodes, r_idx, guess_data, result_data)

		var is_cracked = (result_data.size() == 4 and result_data[0] == 2 and result_data[1] == 2 and result_data[2] == 2 and result_data[3] == 2)
		if is_cracked:
			AudioManager.play_sound("win")
			show_hint("🎉 آفرین! رمز حریف را کشف کردید!")
	else:
		# Opponent's guess -> Place on Opponent Board
		opp_choices.append(guess_data)
		opp_results.append(result_data)
		var r_idx = opp_choices.size() - 1
		_render_guess_row_on_board(opp_row_containers, opp_row_pin_nodes, r_idx, guess_data, result_data)
		_update_active_row_pointer(opp_row_pointer, r_idx)

func on_wait_time(time_sec: int) -> void:
	set_board_locked(true)
	var hud = _get_hud()
	if hud and hud.has_method("set_round_wait"):
		hud.set_round_wait(time_sec)

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) != TYPE_DICTIONARY:
		return

	is_play_phase = bool(g_data.get("is_play_phase", false))
	current_round_num = int(g_data.get("current_round", 1))

	if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
		my_secret_board = g_data["board"]
		is_my_board_set = (my_secret_board.size() == 4 and my_secret_board[0] != 0)

	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()

	var p1_c = g_data.get("player1_choices", [])
	var p1_r = g_data.get("player1_results", [])
	var p2_c = g_data.get("player2_choices", [])
	var p2_r = g_data.get("player2_results", [])

	if my_player_index == 1:
		my_choices = p1_c.duplicate()
		my_results = p1_r.duplicate()
		opp_choices = p2_c.duplicate()
		opp_results = p2_r.duplicate()
	else:
		my_choices = p2_c.duplicate()
		my_results = p2_r.duplicate()
		opp_choices = p1_c.duplicate()
		opp_results = p1_r.duplicate()

	set_phase(is_play_phase)
	_refresh_both_boards()
	var is_waiting = bool(g_data.get("is_turn_played", false)) if is_play_phase else bool(g_data.get("is_player_rdy", false))
	set_board_locked(is_waiting)
	var hud = _get_hud()
	if hud:
		if is_play_phase:
			if hud.has_method("update_turn"):
				hud.update_turn(max(1, current_round_num))
		else:
			if hud.has_method("set_setup_phase"):
				hud.set_setup_phase()
		if hud.has_method("set_fekrbekr_hud_buttons"):
			hud.set_fekrbekr_hud_buttons(is_play_phase)
		if is_waiting and hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("حدس شما ثبت شده است. در انتظار حریف..." if is_play_phase else "رمز شما ثبت شده است. در انتظار حریف...")
	if not is_play_phase and is_waiting:
		if is_instance_valid(phase1_root):
			phase1_root.visible = false

# ==============================================================================
# 8. ROW RENDERING & RECONNECT SAFETY
# ==============================================================================

func _render_guess_row_on_board(containers: Array[Node3D], pin_arrays: Array[Array], row_idx: int, guess: Array, result: Array) -> void:
	if row_idx < 0 or row_idx >= NUM_VISIBLE_ROWS or row_idx >= containers.size():
		return

	var row_node = containers[row_idx]
	if not is_instance_valid(row_node):
		return

	var pc = row_node.get_node_or_null("PiecesContainer")
	if not pc:
		pc = Node3D.new()
		pc.name = "PiecesContainer"
		row_node.add_child(pc)

	# 1. Spawn pure color pieces (NO numbers) inside PiecesContainer
	for col in range(min(guess.size(), NUM_PEGS)):
		var color_val = int(guess[col])
		if color_val <= 0:
			continue

		var piece = _create_piece_mesh(color_val)
		piece.position = Vector3(PEG_X_OFFSETS[col], 0.050, 0)
		piece.scale = Vector3(0.5, 0.5, 0.5)
		pc.add_child(piece)

		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(piece, "position:y", 0.016, 0.20 + col * 0.03)
		tw.parallel().tween_property(piece, "scale", Vector3.ONE, 0.20 + col * 0.03)

	# 2. Sequential Pop-in for Feedback Pins
	if row_idx < pin_arrays.size():
		var pin_nodes = pin_arrays[row_idx]
		for p_idx in range(min(result.size(), 4)):
			var r_val = int(result[p_idx])
			var pin = pin_nodes[p_idx]
			if not is_instance_valid(pin):
				continue

			if r_val == 0:
				pin.visible = false
				continue

			pin.material_override = mat_pin_black if r_val == 2 else mat_pin_white
			pin.visible = true
			pin.scale = Vector3.ZERO
			pin.position.y = 0.005

			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.18 + p_idx * 0.06)
			tw.parallel().tween_property(pin, "scale", Vector3.ONE, 0.16)
			tw.parallel().tween_property(pin, "position:y", 0.015, 0.16)

func _refresh_both_boards() -> void:
	# 1. Clear ONLY PiecesContainer children on My Board (keeps sockets, dividers, pin pads 100% intact!)
	for r in range(my_row_containers.size()):
		var row_node = my_row_containers[r]
		if is_instance_valid(row_node):
			var pc = row_node.get_node_or_null("PiecesContainer")
			if pc:
				for ch in pc.get_children():
					ch.queue_free()
		if r < my_row_pin_nodes.size():
			for p in my_row_pin_nodes[r]:
				if is_instance_valid(p):
					p.visible = false

	for r in range(min(my_choices.size(), NUM_VISIBLE_ROWS)):
		_render_guess_row_on_board(my_row_containers, my_row_pin_nodes, r, my_choices[r], my_results[r] if r < my_results.size() else [])

	# 2. Clear ONLY PiecesContainer children on Opponent Board
	for r in range(opp_row_containers.size()):
		var row_node = opp_row_containers[r]
		if is_instance_valid(row_node):
			var pc = row_node.get_node_or_null("PiecesContainer")
			if pc:
				for ch in pc.get_children():
					ch.queue_free()
		if r < opp_row_pin_nodes.size():
			for p in opp_row_pin_nodes[r]:
				if is_instance_valid(p):
					p.visible = false

	for r in range(min(opp_choices.size(), NUM_VISIBLE_ROWS)):
		_render_guess_row_on_board(opp_row_containers, opp_row_pin_nodes, r, opp_choices[r], opp_results[r] if r < opp_results.size() else [])

func reset_board() -> void:
	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()
	phase1_selection = [0, 0, 0, 0]
	active_selection = [0, 0, 0, 0]
	is_my_board_set = false
	is_revealed = false
	current_round_num = 0
	set_phase(false)
	_refresh_both_boards()
	_update_phase1_slots()
	_update_active_slots()

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)

func on_new_round(round_num: int) -> void:
	current_round_num = round_num
	set_phase(true)
	set_board_locked(false)
	_clear_current_selection()
	_update_active_row_pointer(my_row_pointer, current_round_num - 1)

func cleanup_board() -> void:
	is_play_phase = false
	current_round_num = 0
	is_my_board_set = false
	is_revealed = false
	phase1_selection = [0, 0, 0, 0]
	active_selection = [0, 0, 0, 0]
	my_choices.clear()
	my_results.clear()
	opp_choices.clear()
	opp_results.clear()
	set_phase(false)
