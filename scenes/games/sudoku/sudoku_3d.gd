class_name Sudoku3D
extends "res://scripts/games/base_game_board.gd"

# Royal Persian Sudoku (سودوکو) 3D Physical Board & Gamer-Friendly Arena
# 100% server parity with kafehfekrbackend/Entities/Games/Sudoku/__init__.py
# and kafehfekr/lib/Feature/Sudoku/Controllers/sudoku_controller.dart:
# - 9x9 grid of 81 recessed slate/walnut wells partitioned into 9 major 3x3 blocks
# - Distinct styling for Base Clues (Antique Gold inlay) vs Placed Digits (Vibrant Cyan)
# - Real-time conflict detection with soft pulsing red highlight on duplicate row/col/box cells
# - Same-number illumination across all 81 cells when a number is selected
# - Line & Box completion celebration shimmer VFX waves
# - Tactile 3D bottom console: 9 large digit buttons with remaining count badges + Erase + Submit & Solve
# - Large, crisp typography with hekayat.ttf / Vazir.ttf

const TOTAL_CELLS: int = 81
const GRID_SIZE: int = 9
const BOX_SIZE: int = 3
const BOARD_SURFACE_Y: float = 0.048
const GRID_CENTER_Z: float = -0.160

# Cell & Block Metrics
const CELL_W: float = 0.106
const CELL_GAP: float = 0.005
const BLOCK_GAP: float = 0.016
const BLOCK_W: float = (3.0 * CELL_W) + (2.0 * CELL_GAP) # 0.328m
const TOTAL_GRID_W: float = (3.0 * BLOCK_W) + (2.0 * BLOCK_GAP) # 1.016m

# Bottom Console Metrics
const CONSOLE_Z: float = 0.465
const PAD_BTN_W: float = 0.098
const PAD_BTN_D: float = 0.092
const PAD_BTN_H: float = 0.024
const ACTION_BTN_Y: float = 0.038
const ACTION_BTN_Z: float = 0.575

# Camera framing hint for CafeTable
var camera_pitch: float = -0.733
var camera_distance: float = 3.35

var _game_font: Font = null

# Logical Board State
var board_values: Array = []         # 0..9 (0 = empty)
var is_base_number: Array = []       # True for immutable starting clues
var selected_cell_idx: int = -1            # Currently focused cell (0..80, or -1)
var selected_digit: int = 1                # Currently selected digit in pad (1..9, or 0 for erase mode)
var numbers_count: Dictionary = {}         # digit (1..9) -> count on board (0..9)
var conflicting_indices: Array = []   # Indices of cells violating Sudoku rules
var completed_rows: Array = []        # Completed 9-cell rows (0..8)
var completed_cols: Array = []        # Completed 9-cell cols (0..8)
var completed_boxes: Array = []       # Completed 3x3 boxes (0..8)

# Input Tracking
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false
const DRAG_CLICK_THRESHOLD: float = 14.0

# 3D Node Hierarchy
var board_decor_root: Node3D
var cells_root: Node3D
var console_root: Node3D
var vfx_root: Node3D

# Cell Nodes Cache
var cell_centers: Array = []
var cell_boxes: Array = []
var cell_highlights: Array = []
var cell_labels: Array = []
var cell_rivets: Array = []

# Console Nodes Cache
var pad_btn_roots: Array = []
var pad_btn_meshes: Array = []
var pad_btn_labels: Array = []
var pad_btn_count_labels: Array = []
var btn_erase_root: Node3D
var btn_erase_mesh: MeshInstance3D
var btn_erase_label: Label3D
var btn_solve_root: Node3D
var btn_solve_mesh: MeshInstance3D
var btn_solve_label: Label3D
var lbl_status_hint: Label3D

# Materials
var mat_plinth: StandardMaterial3D
var mat_frame: StandardMaterial3D
var mat_playing_bed: StandardMaterial3D
var mat_cell_base: StandardMaterial3D
var mat_cell_given: StandardMaterial3D
var mat_cell_hover: StandardMaterial3D
var mat_cell_select: StandardMaterial3D
var mat_cell_match: StandardMaterial3D
var mat_cell_conflict: StandardMaterial3D
var mat_gold_rim: StandardMaterial3D
var mat_pad_normal: StandardMaterial3D
var mat_pad_selected: StandardMaterial3D
var mat_pad_completed: StandardMaterial3D
var mat_btn_erase: StandardMaterial3D
var mat_btn_erase_active: StandardMaterial3D
var mat_btn_solve: StandardMaterial3D

func _init() -> void:
	game_type = GameTypes.SUDOKU

func _ready() -> void:
	# 1. Load Fonts Safely
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		_game_font = load("res://assets/fonts/hekayat.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Vazir.ttf"):
		_game_font = load("res://assets/fonts/Vazir.ttf")

	# 2. Initialize Data & Default Starter Puzzle
	_init_data_structures()
	_apply_default_starter_puzzle()

	# 3. Build Physical 3D Materials & Geometry
	_init_materials()
	_build_scene_hierarchy()
	_build_master_cabinet()
	_build_sudoku_grid()
	_build_bottom_console()

	# 4. Synchronize Visuals & Counts
	_update_numbers_count()
	_refresh_board_visuals()

	# 5. Call base lifecycle after full setup
	super._ready()

func _exit_tree() -> void:
	super._exit_tree()

func _init_data_structures() -> void:
	board_values.clear()
	is_base_number.clear()
	conflicting_indices.clear()
	completed_rows.clear()
	completed_cols.clear()
	completed_boxes.clear()
	for i in range(TOTAL_CELLS):
		board_values.append(0)
		is_base_number.append(false)
	for d in range(1, 10):
		numbers_count[d] = 0

func _apply_default_starter_puzzle() -> void:
	# Classic valid starter Sudoku puzzle with 36 initial clues
	var default_puzzle: Array = [
		5, 3, 0,  0, 7, 0,  0, 0, 0,
		6, 0, 0,  1, 9, 5,  0, 0, 0,
		0, 9, 8,  0, 0, 0,  0, 6, 0,

		8, 0, 0,  0, 6, 0,  0, 0, 3,
		4, 0, 0,  8, 0, 3,  0, 0, 1,
		7, 0, 0,  0, 2, 0,  0, 0, 6,

		0, 6, 0,  0, 0, 0,  2, 8, 0,
		0, 0, 0,  4, 1, 9,  0, 0, 5,
		0, 0, 0,  0, 8, 0,  0, 7, 9
	]
	for i in range(min(TOTAL_CELLS, default_puzzle.size())):
		var val = default_puzzle[i]
		board_values[i] = val
		is_base_number[i] = (val > 0)

func _init_materials() -> void:
	mat_plinth = StandardMaterial3D.new()
	mat_plinth.albedo_color = Color(0.13, 0.08, 0.05, 1.0)
	mat_plinth.metallic = 0.04
	mat_plinth.roughness = 0.60

	mat_frame = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.24, 0.14, 0.08, 1.0)
	mat_frame.metallic = 0.08
	mat_frame.roughness = 0.35
	mat_frame.clearcoat_enabled = true
	mat_frame.clearcoat = 0.6

	mat_playing_bed = StandardMaterial3D.new()
	mat_playing_bed.albedo_color = Color(0.10, 0.11, 0.13, 1.0)
	mat_playing_bed.metallic = 0.02
	mat_playing_bed.roughness = 0.70

	mat_cell_base = StandardMaterial3D.new()
	mat_cell_base.albedo_color = Color(0.18, 0.20, 0.24, 1.0)
	mat_cell_base.metallic = 0.05
	mat_cell_base.roughness = 0.50

	mat_cell_given = StandardMaterial3D.new()
	mat_cell_given.albedo_color = Color(0.13, 0.15, 0.19, 1.0)
	mat_cell_given.metallic = 0.12
	mat_cell_given.roughness = 0.40

	mat_gold_rim = StandardMaterial3D.new()
	mat_gold_rim.albedo_color = Color(0.92, 0.76, 0.28, 1.0)
	mat_gold_rim.metallic = 0.90
	mat_gold_rim.roughness = 0.22

	mat_cell_hover = StandardMaterial3D.new()
	mat_cell_hover.albedo_color = Color(0.95, 0.85, 0.45, 0.65)
	mat_cell_hover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cell_hover.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_cell_select = StandardMaterial3D.new()
	mat_cell_select.albedo_color = Color(0.30, 0.85, 1.0, 0.85)
	mat_cell_select.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cell_select.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_cell_match = StandardMaterial3D.new()
	mat_cell_match.albedo_color = Color(0.95, 0.82, 0.30, 0.45)
	mat_cell_match.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cell_match.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_cell_conflict = StandardMaterial3D.new()
	mat_cell_conflict.albedo_color = Color(1.0, 0.25, 0.25, 0.80)
	mat_cell_conflict.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cell_conflict.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_pad_normal = StandardMaterial3D.new()
	mat_pad_normal.albedo_color = Color(0.24, 0.16, 0.11, 1.0)
	mat_pad_normal.metallic = 0.08
	mat_pad_normal.roughness = 0.38
	mat_pad_normal.clearcoat_enabled = true
	mat_pad_normal.clearcoat = 0.5

	mat_pad_selected = StandardMaterial3D.new()
	mat_pad_selected.albedo_color = Color(0.18, 0.55, 0.80, 1.0)
	mat_pad_selected.metallic = 0.20
	mat_pad_selected.roughness = 0.25
	mat_pad_selected.emission_enabled = true
	mat_pad_selected.emission = Color(0.15, 0.45, 0.70)
	mat_pad_selected.emission_energy_multiplier = 0.6

	mat_pad_completed = StandardMaterial3D.new()
	mat_pad_completed.albedo_color = Color(0.14, 0.38, 0.24, 1.0)
	mat_pad_completed.metallic = 0.15
	mat_pad_completed.roughness = 0.35

	mat_btn_erase = StandardMaterial3D.new()
	mat_btn_erase.albedo_color = Color(0.55, 0.22, 0.18, 1.0)
	mat_btn_erase.metallic = 0.10
	mat_btn_erase.roughness = 0.35

	mat_btn_erase_active = StandardMaterial3D.new()
	mat_btn_erase_active.albedo_color = Color(0.85, 0.25, 0.20, 1.0)
	mat_btn_erase_active.emission_enabled = true
	mat_btn_erase_active.emission = Color(0.70, 0.20, 0.15)
	mat_btn_erase_active.emission_energy_multiplier = 0.7

	mat_btn_solve = StandardMaterial3D.new()
	mat_btn_solve.albedo_color = Color(0.16, 0.58, 0.35, 1.0)
	mat_btn_solve.metallic = 0.15
	mat_btn_solve.roughness = 0.28
	mat_btn_solve.clearcoat_enabled = true
	mat_btn_solve.clearcoat = 0.6

func _build_scene_hierarchy() -> void:
	board_decor_root = Node3D.new()
	board_decor_root.name = "BoardDecorRoot"
	add_child(board_decor_root)

	cells_root = Node3D.new()
	cells_root.name = "CellsRoot"
	add_child(cells_root)

	console_root = Node3D.new()
	console_root.name = "ConsoleRoot"
	add_child(console_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VFXRoot"
	add_child(vfx_root)

func _build_master_cabinet() -> void:
	# 1. Master Plinth Base
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(1.24, 0.03, 1.46)
	plinth_mesh.material = mat_plinth
	plinth.mesh = plinth_mesh
	plinth.material_override = mat_plinth
	plinth.position = Vector3(0, -0.015, 0.06)
	board_decor_root.add_child(plinth)

	# 2. Polished Board Frame
	var frame = MeshInstance3D.new()
	var frame_mesh = BoxMesh.new()
	frame_mesh.size = Vector3(1.18, 0.045, 1.40)
	frame_mesh.material = mat_frame
	frame.mesh = frame_mesh
	frame.material_override = mat_frame
	frame.position = Vector3(0, 0.015, 0.06)
	board_decor_root.add_child(frame)

	# 3. Recessed Slate Playing Bed
	var bed = MeshInstance3D.new()
	var bed_mesh = BoxMesh.new()
	bed_mesh.size = Vector3(1.08, 0.02, 1.28)
	bed_mesh.material = mat_playing_bed
	bed.mesh = bed_mesh
	bed.material_override = mat_playing_bed
	bed.position = Vector3(0, 0.038, 0.06)
	board_decor_root.add_child(bed)

	# 4. Corner Golden Brackets
	var corner_mesh = BoxMesh.new()
	corner_mesh.size = Vector3(0.08, 0.052, 0.08)
	corner_mesh.material = mat_gold_rim

	var rivet_mesh = SphereMesh.new()
	rivet_mesh.radius = 0.014
	rivet_mesh.height = 0.020
	rivet_mesh.material = mat_gold_rim

	var corners = [
		Vector3(-0.56, 0.020, -0.60),
		Vector3(0.56, 0.020, -0.60),
		Vector3(-0.56, 0.020, 0.72),
		Vector3(0.56, 0.020, 0.72)
	]
	for c_pos in corners:
		var c_inst = MeshInstance3D.new()
		c_inst.mesh = corner_mesh
		c_inst.material_override = mat_gold_rim
		c_inst.position = c_pos
		board_decor_root.add_child(c_inst)

		var r_inst = MeshInstance3D.new()
		r_inst.mesh = rivet_mesh
		r_inst.material_override = mat_gold_rim
		r_inst.position = Vector3(0, 0.026, 0)
		c_inst.add_child(r_inst)

func _get_cell_pos(r: int, c: int) -> Vector3:
	var c_block = c / 3
	var c_sub = c % 3
	var r_block = r / 3
	var r_sub = r % 3
	var half_w = TOTAL_GRID_W * 0.5 - (CELL_W * 0.5)
	var x = -half_w + float(c_block) * (BLOCK_W + BLOCK_GAP) + float(c_sub) * (CELL_W + CELL_GAP)
	var z = GRID_CENTER_Z - half_w + float(r_block) * (BLOCK_W + BLOCK_GAP) + float(r_sub) * (CELL_W + CELL_GAP)
	return Vector3(x, BOARD_SURFACE_Y, z)

func _build_sudoku_grid() -> void:
	# 1. 3x3 Major Subgrid Brass Divider Bars
	var rib_mesh_v = BoxMesh.new()
	rib_mesh_v.size = Vector3(0.012, 0.012, TOTAL_GRID_W + 0.02)
	rib_mesh_v.material = mat_gold_rim

	var rib_mesh_h = BoxMesh.new()
	rib_mesh_h.size = Vector3(TOTAL_GRID_W + 0.02, 0.012, 0.012)
	rib_mesh_h.material = mat_gold_rim

	for b in [1, 2]:
		var offset = -TOTAL_GRID_W * 0.5 + float(b) * (BLOCK_W + BLOCK_GAP) - (BLOCK_GAP * 0.5)
		# Vertical major dividers
		var v_inst = MeshInstance3D.new()
		v_inst.mesh = rib_mesh_v
		v_inst.material_override = mat_gold_rim
		v_inst.position = Vector3(offset, BOARD_SURFACE_Y + 0.006, GRID_CENTER_Z)
		board_decor_root.add_child(v_inst)
		# Horizontal major dividers
		var h_inst = MeshInstance3D.new()
		h_inst.mesh = rib_mesh_h
		h_inst.material_override = mat_gold_rim
		h_inst.position = Vector3(0, BOARD_SURFACE_Y + 0.006, GRID_CENTER_Z + offset)
		board_decor_root.add_child(h_inst)

	# 2. Outer Golden Perimeter Border
	var border_mesh_h = BoxMesh.new()
	border_mesh_h.size = Vector3(TOTAL_GRID_W + 0.035, 0.010, 0.014)
	border_mesh_h.material = mat_gold_rim

	var border_mesh_v = BoxMesh.new()
	border_mesh_v.size = Vector3(0.014, 0.010, TOTAL_GRID_W + 0.035)
	border_mesh_v.material = mat_gold_rim

	var half_tot = TOTAL_GRID_W * 0.5 + 0.010
	var b_top = MeshInstance3D.new()
	b_top.mesh = border_mesh_h
	b_top.material_override = mat_gold_rim
	b_top.position = Vector3(0, BOARD_SURFACE_Y + 0.005, GRID_CENTER_Z - half_tot)
	board_decor_root.add_child(b_top)

	var b_bot = MeshInstance3D.new()
	b_bot.mesh = border_mesh_h
	b_bot.material_override = mat_gold_rim
	b_bot.position = Vector3(0, BOARD_SURFACE_Y + 0.005, GRID_CENTER_Z + half_tot)
	board_decor_root.add_child(b_bot)

	var b_left = MeshInstance3D.new()
	b_left.mesh = border_mesh_v
	b_left.material_override = mat_gold_rim
	b_left.position = Vector3(-half_tot, BOARD_SURFACE_Y + 0.005, GRID_CENTER_Z)
	board_decor_root.add_child(b_left)

	var b_right = MeshInstance3D.new()
	b_right.mesh = border_mesh_v
	b_right.material_override = mat_gold_rim
	b_right.position = Vector3(half_tot, BOARD_SURFACE_Y + 0.005, GRID_CENTER_Z)
	board_decor_root.add_child(b_right)

	# 3. 81 Cell Wells
	cell_centers.resize(TOTAL_CELLS)
	cell_boxes.resize(TOTAL_CELLS)
	cell_highlights.resize(TOTAL_CELLS)
	cell_labels.resize(TOTAL_CELLS)
	cell_rivets.resize(TOTAL_CELLS)

	var cell_box_mesh = BoxMesh.new()
	cell_box_mesh.size = Vector3(CELL_W, 0.008, CELL_W)

	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(CELL_W * 0.94, CELL_W * 0.94)
	quad_mesh.orientation = PlaneMesh.FACE_Y

	var rivet_mesh = SphereMesh.new()
	rivet_mesh.radius = 0.006
	rivet_mesh.height = 0.008
	rivet_mesh.material = mat_gold_rim

	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var idx = r * GRID_SIZE + c
			var pos = _get_cell_pos(r, c)
			cell_centers[idx] = pos

			var cell_node = Node3D.new()
			cell_node.name = "Cell_%d" % idx
			cell_node.position = pos
			cells_root.add_child(cell_node)

			# Base well box
			var c_mesh = MeshInstance3D.new()
			c_mesh.mesh = cell_box_mesh
			c_mesh.material_override = mat_cell_base
			cell_node.add_child(c_mesh)
			cell_boxes[idx] = c_mesh

			# Highlight quad (hover, select, same-number, conflict)
			var h_mesh = MeshInstance3D.new()
			h_mesh.mesh = quad_mesh
			h_mesh.position = Vector3(0, 0.0045, 0)
			h_mesh.visible = false
			cell_node.add_child(h_mesh)
			cell_highlights[idx] = h_mesh

			# Initial Clue Rivet (antique brass corner dot)
			var r_mesh = MeshInstance3D.new()
			r_mesh.mesh = rivet_mesh
			r_mesh.position = Vector3(-CELL_W * 0.38, 0.005, -CELL_W * 0.38)
			r_mesh.visible = false
			cell_node.add_child(r_mesh)
			cell_rivets[idx] = r_mesh

			# Large Crisp Digit Label
			var lbl = Label3D.new()
			if _game_font:
				lbl.font = _game_font
			lbl.font_size = 72
			lbl.pixel_size = 0.00165
			lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			lbl.rotation_degrees = Vector3(-90, 0, 0)
			lbl.position = Vector3(0, 0.006, 0)
			lbl.text = ""
			lbl.modulate = Color(1.0, 0.88, 0.50)
			lbl.outline_modulate = Color(0.08, 0.08, 0.10, 0.95)
			lbl.outline_size = 10
			cell_node.add_child(lbl)
			cell_labels[idx] = lbl

func _build_bottom_console() -> void:
	# Master Console Wood Base Plinth
	var console_plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(1.14, 0.035, 0.28)
	plinth_mesh.material = mat_pad_normal
	console_plinth.mesh = plinth_mesh
	console_plinth.material_override = mat_pad_normal
	console_plinth.position = Vector3(0, 0.020, CONSOLE_Z + 0.05)
	console_root.add_child(console_plinth)

	# Brass Trim Bar
	var trim_bar = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(1.10, 0.008, 0.008)
	trim_mesh.material = mat_gold_rim
	trim_bar.mesh = trim_mesh
	trim_bar.material_override = mat_gold_rim
	trim_bar.position = Vector3(0, 0.038, CONSOLE_Z - 0.082)
	console_root.add_child(trim_bar)

	# Hint / Status Instruction Label
	lbl_status_hint = Label3D.new()
	if _game_font:
		lbl_status_hint.font = _game_font
	lbl_status_hint.font_size = 28
	lbl_status_hint.pixel_size = 0.00155
	lbl_status_hint.rotation_degrees = Vector3(-90, 0, 0)
	lbl_status_hint.position = Vector3(0, 0.040, CONSOLE_Z - 0.060)
	lbl_status_hint.text = "یک عدد انتخاب کنید و روی خانه‌های جدول بزنید"
	lbl_status_hint.modulate = Color(0.92, 0.90, 0.80)
	lbl_status_hint.outline_modulate = Color(0.05, 0.05, 0.08)
	lbl_status_hint.outline_size = 8
	console_root.add_child(lbl_status_hint)

	# 1. 9 Digit Pad Buttons (1..9)
	pad_btn_roots.resize(10)
	pad_btn_meshes.resize(10)
	pad_btn_labels.resize(10)
	pad_btn_count_labels.resize(10)

	var pad_mesh = BoxMesh.new()
	pad_mesh.size = Vector3(PAD_BTN_W, PAD_BTN_H, PAD_BTN_D)

	var start_x = -((9 - 1) * 0.118) * 0.5
	for d in range(1, 10):
		var btn_root = Node3D.new()
		btn_root.name = "PadBtn_%d" % d
		var x = start_x + float(d - 1) * 0.118
		btn_root.position = Vector3(x, 0.036, CONSOLE_Z)
		console_root.add_child(btn_root)
		pad_btn_roots[d] = btn_root

		var b_mesh = MeshInstance3D.new()
		b_mesh.mesh = pad_mesh
		b_mesh.material_override = mat_pad_normal
		btn_root.add_child(b_mesh)
		pad_btn_meshes[d] = b_mesh

		# Large Prominent Digit Label
		var lbl_d = Label3D.new()
		if _game_font:
			lbl_d.font = _game_font
		lbl_d.font_size = 58
		lbl_d.pixel_size = 0.00160
		lbl_d.rotation_degrees = Vector3(-90, 0, 0)
		lbl_d.position = Vector3(0, PAD_BTN_H * 0.5 + 0.004, -0.012)
		lbl_d.text = _fa_num(d)
		lbl_d.modulate = Color(1.0, 0.95, 0.80)
		lbl_d.outline_modulate = Color(0.05, 0.05, 0.08)
		lbl_d.outline_size = 8
		btn_root.add_child(lbl_d)
		pad_btn_labels[d] = lbl_d

		# Remaining Count Badge Label
		var lbl_cnt = Label3D.new()
		if _game_font:
			lbl_cnt.font = _game_font
		lbl_cnt.font_size = 26
		lbl_cnt.pixel_size = 0.00135
		lbl_cnt.rotation_degrees = Vector3(-90, 0, 0)
		lbl_cnt.position = Vector3(0, PAD_BTN_H * 0.5 + 0.004, 0.026)
		lbl_cnt.text = "۰/۹"
		lbl_cnt.modulate = Color(0.75, 0.80, 0.85)
		lbl_cnt.outline_modulate = Color(0.05, 0.05, 0.08)
		lbl_cnt.outline_size = 6
		btn_root.add_child(lbl_cnt)
		pad_btn_count_labels[d] = lbl_cnt

	# 2. Action Button: Erase (🧹 پاک کردن)
	btn_erase_root = Node3D.new()
	btn_erase_root.name = "BtnErase"
	btn_erase_root.position = Vector3(-0.28, ACTION_BTN_Y, ACTION_BTN_Z)
	console_root.add_child(btn_erase_root)

	var erase_mesh = BoxMesh.new()
	erase_mesh.size = Vector3(0.44, 0.024, 0.068)
	btn_erase_mesh = MeshInstance3D.new()
	btn_erase_mesh.mesh = erase_mesh
	btn_erase_mesh.material_override = mat_btn_erase
	btn_erase_root.add_child(btn_erase_mesh)

	btn_erase_label = Label3D.new()
	if _game_font:
		btn_erase_label.font = _game_font
	btn_erase_label.font_size = 32
	btn_erase_label.pixel_size = 0.00155
	btn_erase_label.rotation_degrees = Vector3(-90, 0, 0)
	btn_erase_label.position = Vector3(0, 0.015, 0)
	btn_erase_label.text = "🧹 پاک کردن خانه"
	btn_erase_label.modulate = Color(1.0, 0.95, 0.92)
	btn_erase_label.outline_modulate = Color(0.12, 0.04, 0.04)
	btn_erase_label.outline_size = 8
	btn_erase_root.add_child(btn_erase_label)

	# 3. Action Button: Submit & Solve (✨ بررسی و ثبت حل)
	btn_solve_root = Node3D.new()
	btn_solve_root.name = "BtnSolve"
	btn_solve_root.position = Vector3(0.24, ACTION_BTN_Y, ACTION_BTN_Z)
	console_root.add_child(btn_solve_root)

	var solve_mesh = BoxMesh.new()
	solve_mesh.size = Vector3(0.52, 0.024, 0.068)
	btn_solve_mesh = MeshInstance3D.new()
	btn_solve_mesh.mesh = solve_mesh
	btn_solve_mesh.material_override = mat_btn_solve
	btn_solve_root.add_child(btn_solve_mesh)

	btn_solve_label = Label3D.new()
	if _game_font:
		btn_solve_label.font = _game_font
	btn_solve_label.font_size = 32
	btn_solve_label.pixel_size = 0.00155
	btn_solve_label.rotation_degrees = Vector3(-90, 0, 0)
	btn_solve_label.position = Vector3(0, 0.015, 0)
	btn_solve_label.text = "✨ بررسی و ثبت حل"
	btn_solve_label.modulate = Color(1.0, 1.0, 0.90)
	btn_solve_label.outline_modulate = Color(0.04, 0.12, 0.06)
	btn_solve_label.outline_size = 8
	btn_solve_root.add_child(btn_solve_label)

func _update_numbers_count() -> void:
	for d in range(1, 10):
		numbers_count[d] = 0
	for val in board_values:
		if val in numbers_count:
			numbers_count[val] += 1

	for d in range(1, 10):
		var cnt = numbers_count.get(d, 0)
		var is_full = (cnt >= 9)
		if is_instance_valid(pad_btn_count_labels[d]):
			if is_full:
				pad_btn_count_labels[d].text = "✓ کامل"
				pad_btn_count_labels[d].modulate = Color(0.40, 1.0, 0.50)
			else:
				pad_btn_count_labels[d].text = "%s/۹" % _fa_num(cnt)
				pad_btn_count_labels[d].modulate = Color(0.75, 0.82, 0.88)
		if is_instance_valid(pad_btn_meshes[d]):
			if d == selected_digit:
				pad_btn_meshes[d].material_override = mat_pad_selected
			elif is_full:
				pad_btn_meshes[d].material_override = mat_pad_completed
			else:
				pad_btn_meshes[d].material_override = mat_pad_normal

	# Update Erase Button styling
	if is_instance_valid(btn_erase_mesh):
		btn_erase_mesh.material_override = mat_btn_erase_active if selected_digit == 0 else mat_btn_erase

	# Update Solve Button styling (ready if all 81 filled)
	var filled_cnt = 0
	for v in board_values:
		if v > 0: filled_cnt += 1
	if is_instance_valid(btn_solve_label):
		if filled_cnt >= TOTAL_CELLS:
			btn_solve_label.text = "✨ ثبت و ارسال حل نهایی"
			btn_solve_label.modulate = Color(1.0, 0.95, 0.35)
		else:
			btn_solve_label.text = "✨ بررسی و ثبت حل (%s/۸۱)" % _fa_num(filled_cnt)
			btn_solve_label.modulate = Color(0.95, 0.95, 0.95)

func _refresh_board_visuals() -> void:
	_calculate_conflicts()
	for i in range(TOTAL_CELLS):
		var val = board_values[i]
		var is_base = is_base_number[i]
		var is_conflict = i in conflicting_indices
		var is_selected = (i == selected_cell_idx)
		var is_same_number = (selected_digit > 0 and val == selected_digit) or (selected_cell_idx >= 0 and val > 0 and val == board_values[selected_cell_idx])

		# Label text & color
		if is_instance_valid(cell_labels[i]):
			if val > 0:
				cell_labels[i].text = _fa_num(val)
				if is_conflict:
					cell_labels[i].modulate = Color(1.0, 0.32, 0.32)
				elif is_base:
					cell_labels[i].modulate = Color(1.0, 0.88, 0.48)
				else:
					cell_labels[i].modulate = Color(0.35, 0.88, 1.0)
			else:
				cell_labels[i].text = ""

		# Rivet visibility
		if is_instance_valid(cell_rivets[i]):
			cell_rivets[i].visible = is_base

		# Box base material
		if is_instance_valid(cell_boxes[i]):
			cell_boxes[i].material_override = mat_cell_given if is_base else mat_cell_base

		# Highlight overlay
		if is_instance_valid(cell_highlights[i]):
			if is_conflict:
				cell_highlights[i].material_override = mat_cell_conflict
				cell_highlights[i].visible = true
			elif is_selected:
				cell_highlights[i].material_override = mat_cell_select
				cell_highlights[i].visible = true
			elif is_same_number:
				cell_highlights[i].material_override = mat_cell_match
				cell_highlights[i].visible = true
			else:
				cell_highlights[i].visible = false

func _calculate_conflicts() -> void:
	conflicting_indices.clear()
	# Check rows
	for r in range(GRID_SIZE):
		var seen: Dictionary = {}
		for c in range(GRID_SIZE):
			var idx = r * GRID_SIZE + c
			var val = board_values[idx]
			if val > 0:
				if not seen.has(val):
					seen[val] = []
				seen[val].append(idx)
		for val in seen.keys():
			var list = seen[val]
			if list.size() > 1:
				for i in list:
					if not i in conflicting_indices:
						conflicting_indices.append(i)

	# Check columns
	for c in range(GRID_SIZE):
		var seen: Dictionary = {}
		for r in range(GRID_SIZE):
			var idx = r * GRID_SIZE + c
			var val = board_values[idx]
			if val > 0:
				if not seen.has(val):
					seen[val] = []
				seen[val].append(idx)
		for val in seen.keys():
			var list = seen[val]
			if list.size() > 1:
				for i in list:
					if not i in conflicting_indices:
						conflicting_indices.append(i)

	# Check 3x3 boxes
	for b_r in range(3):
		for b_c in range(3):
			var seen: Dictionary = {}
			for r in range(b_r * 3, b_r * 3 + 3):
				for c in range(b_c * 3, b_c * 3 + 3):
					var idx = r * GRID_SIZE + c
					var val = board_values[idx]
					if val > 0:
						if not seen.has(val):
							seen[val] = []
						seen[val].append(idx)
			for val in seen.keys():
				var list = seen[val]
				if list.size() > 1:
					for i in list:
						if not i in conflicting_indices:
							conflicting_indices.append(i)

func _check_completions() -> void:
	# Check rows
	for r in range(GRID_SIZE):
		if not r in completed_rows:
			var is_full = true
			var nums: Array = []
			for c in range(GRID_SIZE):
				var v = board_values[r * GRID_SIZE + c]
				if v == 0 or v in nums:
					is_full = false
					break
				nums.append(v)
			if is_full:
				completed_rows.append(r)
				_spawn_line_completion_vfx(r, true)

	# Check columns
	for c in range(GRID_SIZE):
		if not c in completed_cols:
			var is_full = true
			var nums: Array = []
			for r in range(GRID_SIZE):
				var v = board_values[r * GRID_SIZE + c]
				if v == 0 or v in nums:
					is_full = false
					break
				nums.append(v)
			if is_full:
				completed_cols.append(c)
				_spawn_line_completion_vfx(c, false)

	# Check 3x3 boxes
	for b in range(9):
		if not b in completed_boxes:
			var b_r = b / 3
			var b_c = b % 3
			var is_full = true
			var nums: Array = []
			for r in range(b_r * 3, b_r * 3 + 3):
				for c in range(b_c * 3, b_c * 3 + 3):
					var v = board_values[r * GRID_SIZE + c]
					if v == 0 or v in nums:
						is_full = false
						break
					nums.append(v)
			if is_full:
				completed_boxes.append(b)
				_spawn_box_completion_vfx(b)

func _spawn_placement_vfx(pos: Vector3, is_erase: bool) -> void:
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.015
	ring_mesh.outer_radius = 0.025
	ring.mesh = ring_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.40, 0.30, 0.9) if is_erase else Color(0.35, 0.88, 1.0, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat

	ring.position = pos + Vector3(0, 0.012, 0)
	vfx_root.add_child(ring)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)

func _spawn_line_completion_vfx(line_index: int, is_row: bool) -> void:
	AudioManager.play_sound("correct")
	var streak = MeshInstance3D.new()
	var streak_mesh = BoxMesh.new()
	if is_row:
		streak_mesh.size = Vector3(TOTAL_GRID_W, 0.012, CELL_W)
	else:
		streak_mesh.size = Vector3(CELL_W, 0.012, TOTAL_GRID_W)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.35, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.mesh = streak_mesh
	streak.material_override = mat

	var center_pos: Vector3
	if is_row:
		var p = _get_cell_pos(line_index, 4)
		center_pos = Vector3(0, BOARD_SURFACE_Y + 0.012, p.z)
	else:
		var p = _get_cell_pos(4, line_index)
		center_pos = Vector3(p.x, BOARD_SURFACE_Y + 0.012, GRID_CENTER_Z)

	streak.position = center_pos
	streak.scale = Vector3(0.1, 1.0, 0.1)
	vfx_root.add_child(streak)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(streak, "scale", Vector3(1.05, 1.0, 1.05), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.50).set_delay(0.20)
	tw.chain().tween_callback(streak.queue_free)

func _spawn_box_completion_vfx(box_index: int) -> void:
	AudioManager.play_sound("correct")
	var b_r = box_index / 3
	var b_c = box_index % 3
	var center_cell = _get_cell_pos(b_r * 3 + 1, b_c * 3 + 1)

	var box_sweep = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(BLOCK_W, 0.012, BLOCK_W)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 1.0, 0.65, 0.80)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box_sweep.mesh = box_mesh
	box_sweep.material_override = mat
	box_sweep.position = Vector3(center_cell.x, BOARD_SURFACE_Y + 0.012, center_cell.z)
	box_sweep.scale = Vector3(0.2, 1.0, 0.2)
	vfx_root.add_child(box_sweep)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(box_sweep, "scale", Vector3(1.08, 1.0, 1.08), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.50).set_delay(0.20)
	tw.chain().tween_callback(box_sweep.queue_free)

# ==============================================================================
# Input & Raycasting
# ==============================================================================

func _get_hud() -> Control:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud):
		return hud
	return null

func _is_gui_blocking_at(screen_pos: Vector2) -> bool:
	var hud = _get_hud()
	if not hud or not hud.visible:
		return false
	# Modal overlays
	for modal_name in ["StartGameOverlay", "DisconnectPauseDialog", "SurrenderDialog", "RoundFinishBanner", "ReactionPicker", "GameResultDialog", "UserProfileDialog"]:
		var node = hud.get_node_or_null(modal_name)
		if node and node is Control and node.visible:
			return true
	# Bars (bottom bar & top header)
	for bar_name in ["BottomBar", "TopHeaderSlot"]:
		var bar = hud.get_node_or_null(bar_name)
		if bar and bar is Control and bar.visible and bar.get_global_rect().has_point(screen_pos):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked:
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch):
		var pos = event.position
		if _is_gui_blocking_at(pos):
			return

		if event.pressed:
			_raycast_down_pos = pos
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
		else:
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = _raycast_down_pos.distance_to(pos)
				var dur = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if dist < DRAG_CLICK_THRESHOLD and dur < 0.60:
					_handle_tap_at(pos)

func _project_screen_to_board_plane(screen_pos: Vector2) -> Variant:
	var cam = get_viewport().get_camera_3d()
	if not cam: return null
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var plane_y = global_position.y + BOARD_SURFACE_Y
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_normal)
	if hit == null: return null
	return to_local(hit)

func _handle_tap_at(screen_pos: Vector2) -> void:
	var hit = _project_screen_to_board_plane(screen_pos)
	if hit == null: return
	var hit_pos: Vector3 = hit

	# 1. Check Console Buttons Hit
	# Check Digit Pad Buttons (1..9)
	for d in range(1, 10):
		var btn = pad_btn_roots[d]
		if btn and is_instance_valid(btn):
			var b_pos = btn.position
			var half_w = PAD_BTN_W * 0.55
			var half_d = PAD_BTN_D * 0.55
			if abs(hit_pos.x - b_pos.x) <= half_w and abs(hit_pos.z - b_pos.z) <= half_d:
				_on_pad_button_tapped(d)
				return

	# Check Erase Button
	if btn_erase_root and is_instance_valid(btn_erase_root):
		var e_pos = btn_erase_root.position
		if abs(hit_pos.x - e_pos.x) <= 0.23 and abs(hit_pos.z - e_pos.z) <= 0.040:
			_on_erase_button_tapped()
			return

	# Check Submit Solve Button
	if btn_solve_root and is_instance_valid(btn_solve_root):
		var s_pos = btn_solve_root.position
		if abs(hit_pos.x - s_pos.x) <= 0.27 and abs(hit_pos.z - s_pos.z) <= 0.040:
			_on_solve_button_tapped()
			return

	# 2. Check 9x9 Board Cells Hit
	var best_idx = -1
	var min_dist = 999.0
	for i in range(TOTAL_CELLS):
		var c_pos = cell_centers[i]
		var d = Vector2(hit_pos.x - c_pos.x, hit_pos.z - c_pos.z).length()
		if d <= (CELL_W * 0.58) and d < min_dist:
			min_dist = d
			best_idx = i

	if best_idx != -1:
		_on_cell_tapped(best_idx)

func _on_pad_button_tapped(digit: int) -> void:
	AudioManager.play_sound("tap_button")
	if selected_digit == digit:
		selected_digit = -1 # Deselect
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "یک عدد را انتخاب کنید"
	else:
		selected_digit = digit
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "عدد %s انتخاب شد • روی خانه مورد نظر بزنید" % _fa_num(digit)

	# If a non-base cell was already selected, apply this digit to it immediately!
	if selected_cell_idx >= 0 and not is_base_number[selected_cell_idx]:
		if selected_digit > 0:
			_place_number_on_cell(selected_cell_idx, selected_digit)
		elif selected_digit == 0:
			_erase_cell(selected_cell_idx)

	_update_numbers_count()
	_refresh_board_visuals()

func _on_erase_button_tapped() -> void:
	AudioManager.play_sound("tap_button")
	if selected_digit == 0:
		selected_digit = 1
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "حالت پاک‌کن غیرفعال شد"
	else:
		selected_digit = 0
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "🧹 حالت پاک‌کن فعال شد • روی خانه مورد نظر برای حذف بزنید"

	if selected_cell_idx >= 0 and not is_base_number[selected_cell_idx]:
		_erase_cell(selected_cell_idx)

	_update_numbers_count()
	_refresh_board_visuals()

func _on_cell_tapped(idx: int) -> void:
	var is_base = is_base_number[idx]
	if is_base:
		AudioManager.play_sound("tap")
		selected_cell_idx = idx
		var val = board_values[idx]
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "خانه پیش‌فرض (%s) • غیرقابل تغییر" % _fa_num(val)
		_refresh_board_visuals()
		return

	selected_cell_idx = idx

	# Dual input logic:
	# If Erase mode is active -> erase this cell
	if selected_digit == 0:
		if board_values[idx] > 0:
			_erase_cell(idx)
		else:
			AudioManager.play_sound("tap")
		_refresh_board_visuals()
		return

	# If a digit (1..9) is active:
	if selected_digit in range(1, 10):
		# If cell already has this exact digit, toggle/erase it!
		if board_values[idx] == selected_digit:
			_erase_cell(idx)
		else:
			_place_number_on_cell(idx, selected_digit)
	else:
		# Just selecting the cell
		AudioManager.play_sound("tap")
		if board_values[idx] > 0:
			if is_instance_valid(lbl_status_hint):
				lbl_status_hint.text = "خانه انتخاب شد (عدد %s) • برای تغییر روی اعداد پایین بزنید" % _fa_num(board_values[idx])
		else:
			if is_instance_valid(lbl_status_hint):
				lbl_status_hint.text = "خانه خالی انتخاب شد • یک عدد را از پایین بزنید"

	_update_numbers_count()
	_refresh_board_visuals()

func _place_number_on_cell(idx: int, num: int) -> void:
	AudioManager.play_sound("add_peace")
	board_values[idx] = num
	_spawn_placement_vfx(cell_centers[idx], false)

	# Label pop bounce
	if is_instance_valid(cell_labels[idx]):
		var tw = create_tween()
		cell_labels[idx].scale = Vector3(1.35, 1.35, 1.35)
		tw.tween_property(cell_labels[idx], "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Send command to server (Network parity with Flutter & backend)
	_send_sudoku_command(Commands.Select_Peace, {
		"piece_id": idx,
		"number": num
	})

	_update_numbers_count()
	_refresh_board_visuals()
	_check_completions()

func _erase_cell(idx: int) -> void:
	if board_values[idx] == 0: return
	AudioManager.play_sound("remove_peace")
	board_values[idx] = 0
	_spawn_placement_vfx(cell_centers[idx], true)

	_send_sudoku_command(Commands.Remove_Peace, {
		"piece_id": idx
	})

	_update_numbers_count()
	_refresh_board_visuals()

func _on_solve_button_tapped() -> void:
	AudioManager.play_sound("tap_button")
	# Check if all 81 are filled
	var empty_count = 0
	for v in board_values:
		if v == 0: empty_count += 1

	if empty_count > 0:
		AudioManager.play_sound("tap_wrong")
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "⚠️ لطفاً ابتدا تمام خانه‌ها را پر کنید (%s خانه خالیست)" % _fa_num(empty_count)
		return

	# If local conflicts exist, notify user gently
	if conflicting_indices.size() > 0:
		AudioManager.play_sound("tap_wrong")
		ActionVFXManager.shake_camera(0.03, 0.25)
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "⚠️ در جدول تناقض وجود دارد! خانه‌های قرمز را بررسی کنید"
		return

	# Dispatch Solve command to server
	if is_instance_valid(lbl_status_hint):
		lbl_status_hint.text = "در حال بررسی و ثبت حل جدول..."
	_send_sudoku_command(Commands.Solve, {})

func _send_sudoku_command(cmd_id: String, params: Dictionary) -> void:
	# Sends both top-level and in data dictionary for 100% backend compatibility
	var payload = {
		"id": cmd_id,
		"data": params
	}
	for k in params.keys():
		payload[k] = params[k]
	NetworkManager.socket.emit_event("/game", "user_command", payload)

# ==============================================================================
# BaseGameBoard Network Hooks & Lifecycle
# ==============================================================================

func setup_board(game_data: Dictionary) -> void:
	if game_data.has("board") and typeof(game_data["board"]) == TYPE_ARRAY:
		sync_board_state(game_data["board"])

func on_start_game() -> void:
	is_board_locked = false
	is_my_turn = true

func on_start_game_data(payload: Dictionary) -> void:
	if payload.has("board") and typeof(payload["board"]) == TYPE_ARRAY:
		sync_board_state(payload["board"])

func on_wrong_solve() -> void:
	AudioManager.play_sound("tap_wrong")
	ActionVFXManager.shake_camera(0.045, 0.35)
	if is_instance_valid(lbl_status_hint):
		lbl_status_hint.text = "❌ حل نادرست است! ردیف‌ها و ستون‌ها را دوباره بررسی کنید"
	_refresh_board_visuals()

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var board_array: Array = board_data as Array
	if board_array.size() < TOTAL_CELLS:
		return
	for i in range(min(TOTAL_CELLS, board_array.size())):
		var item = board_array[i]
		if typeof(item) == TYPE_DICTIONARY:
			var num = int(item.get("number", 0))
			var is_base = bool(item.get("is_base_number", false))
			board_values[i] = num
			is_base_number[i] = is_base
		elif typeof(item) in [TYPE_INT, TYPE_FLOAT]:
			board_values[i] = int(item)
			is_base_number[i] = (int(item) > 0)

	_update_numbers_count()
	_refresh_board_visuals()
	_check_completions()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY and g_data.has("board"):
		sync_board_state(g_data["board"])
	is_board_locked = false
	is_my_turn = true

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var num = int(extra.get("number", 0))
	if target_peace >= 0 and target_peace < TOTAL_CELLS:
		if not is_base_number[target_peace]:
			board_values[target_peace] = num
			_update_numbers_count()
			_refresh_board_visuals()
			_check_completions()

func on_piece_removed(data: Dictionary) -> void:
	var p_id = int(data.get("piece_id", data.get("index", -1)))
	if p_id >= 0 and p_id < TOTAL_CELLS:
		if not is_base_number[p_id]:
			board_values[p_id] = 0
			_update_numbers_count()
			_refresh_board_visuals()

func on_game_finished(data: Dictionary) -> void:
	is_board_locked = true
	var winner = int(data.get("winner", data.get("Winner", 0)))
	if winner == GameManager.my_player_index:
		ActionVFXManager.spawn_victory_celebration(vfx_root, Vector3(0, 0.1, GRID_CENTER_Z), winner)
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "🏆 تبریک! شما برنده شدید و سودوکو را حل کردید!"
			lbl_status_hint.modulate = Color(0.40, 1.0, 0.50)

func _fa_num(n: int) -> String:
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var s = str(n)
	var res = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			res += fa[int(ch)]
		else:
			res += ch
	return res
