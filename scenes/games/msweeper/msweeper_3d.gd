class_name MSweeper3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# Royal Tactical Minesweeper (مین یاب) 3D Physical Board & Naval Minefield Arena
# 100% server parity with kafehfekrbackend and kafehfekr Flutter app:
# - Simultaneous 2-player competitive Minefield (8x8 = 64 cells, 10 mines, 54 safe spots)
# - Commands.Select_Peace (id="SelectPeace", data=peace_id) to reveal a safe cell
# - Commands.Select_Mine (id="SelectMine", data=peace_id) to flag/defuse a mine (+1 score)
# - Server responses: Select_Peace_Result, Mine_Selected, Select_Mine_Correct,
#   Select_Mine_Wrong, Player_Score, and full Reconnect_Data restoration.
# - Dual input ergonomics: Large 3D Mode Switch Buttons (Dig vs Flag) + Long-Press / Right-Click
# ==============================================================================

const GRID_SIZE: int = 8
const TOTAL_CELLS: int = 64
const INITIAL_MINES: int = 10
const INITIAL_SAFE_SPOTS: int = 54

const STATE_HIDDEN: int = 0
const STATE_REVEALED: int = 1
const STATE_FLAG_CORRECT: int = 2
const STATE_FLAG_WRONG: int = 3
const STATE_MINE_HIT: int = 4

const BOARD_SURFACE_Y: float = 0.048
const GRID_CENTER_Z: float = -0.115

# 8x8 Grid Metrics: 8 * 0.118 + 7 * 0.008 = 1.000m (Fits cleanly inside 1.36m arena)
const CELL_W: float = 0.118
const CELL_GAP: float = 0.008
const CELL_STEP: float = CELL_W + CELL_GAP # 0.126m
const TOTAL_GRID_W: float = (8.0 * CELL_W) + (7.0 * CELL_GAP) # 1.000m

# Bottom Console Metrics
const CONSOLE_Z: float = 0.485

# Camera framing hints for CafeTable
var camera_pitch: float = -0.733
var camera_distance: float = 3.35

var _game_font: Font = null

# Logical Board State
var cell_selected: Array = []          # bool (64)
var cell_state: Array = []             # int (64): STATE_*
var cell_value: Array = []             # int (64): 0..8 for STATE_REVEALED
var select_mine_remaining: int = INITIAL_MINES
var select_peace_remaining: int = INITIAL_SAFE_SPOTS
var is_hit_mine: bool = false
var is_flag_mode: bool = false         # False = Dig/Reveal (Select_Peace), True = Flag/Defuse (Select_Mine)
var hovered_cell_idx: int = -1

# Flood-fill cascade wave timing
var _last_reveal_msec: int = 0
var _cascade_counter: int = 0

# Input & Long-Press Tracking
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false
var _down_cell_idx: int = -1
var _long_press_triggered: bool = false
var _hold_ring_mesh: Node3D = null
var _hold_outer_ring: MeshInstance3D = null
var _hold_inner_ring: MeshInstance3D = null
var _hold_flag_preview: Node3D = null
var waving_flag_segments: Array = []
var smoldering_craters: Array = []
var _smoke_spawn_accum: float = 0.0
const DRAG_CLICK_THRESHOLD: float = 24.0
const LONG_PRESS_DURATION: float = 0.35

# 3D Node Hierarchy
var board_decor_root: Node3D
var cells_root: Node3D
var console_root: Node3D
var vfx_root: Node3D

# Cell 3D Nodes Cache
var cell_centers: Array = []           # Vector3 (64)
var cell_roots: Array = []             # Node3D (64)
var cell_cap_pivots: Array = []        # Node3D (64) - Unrevealed 3D armored cover cap
var cell_cap_meshes: Array = []        # MeshInstance3D (64)
var cell_cap_reticles: Array = []      # MeshInstance3D (64) - Tactical reticle in Flag mode
var cell_reveal_pivots: Array = []     # Node3D (64) - Revealed floor plaque & number
var cell_reveal_Tile_meshes: Array = []# MeshInstance3D (64)
var cell_number_labels: Array = []     # Label3D (64)
var cell_ornament_roots: Array = []    # Node3D (64) - Holds 3D Mine / Flag / Warning Cross models

# Console 3D Nodes
var badge_mines_lbl: Label3D
var badge_safe_lbl: Label3D
var lbl_status_hint: Label3D
var btn_dig_root: Node3D
var btn_dig_pivot: Node3D
var btn_dig_mesh: MeshInstance3D
var btn_dig_label: Label3D
var btn_flag_root: Node3D
var btn_flag_pivot: Node3D
var btn_flag_mesh: MeshInstance3D
var btn_flag_label: Label3D

# Shared 3D Materials
var mat_plinth: StandardMaterial3D
var mat_frame: StandardMaterial3D
var mat_brass_trim: StandardMaterial3D
var mat_playing_bed: StandardMaterial3D
var mat_well_socket: StandardMaterial3D
var mat_cap_normal: StandardMaterial3D
var mat_cap_boss: StandardMaterial3D
var mat_gold_rivet: StandardMaterial3D
var mat_revealed_zero: StandardMaterial3D
var mat_revealed_num: StandardMaterial3D
var mat_flag_correct_base: StandardMaterial3D
var mat_flag_wrong_base: StandardMaterial3D
var mat_mine_hit_base: StandardMaterial3D
var mat_mine_iron: StandardMaterial3D
var mat_mine_charred: StandardMaterial3D
var mat_flag_gold: StandardMaterial3D
var mat_flag_emerald: StandardMaterial3D
var mat_cross_crimson: StandardMaterial3D
var mat_lava_glow: StandardMaterial3D
var mat_reticle_flag: StandardMaterial3D
var mat_btn_dig_active: StandardMaterial3D
var mat_btn_dig_idle: StandardMaterial3D
var mat_btn_flag_active: StandardMaterial3D
var mat_btn_flag_idle: StandardMaterial3D
var mat_badge_panel: StandardMaterial3D
var _num_tile_mats: Dictionary = {}

func _init() -> void:
	game_type = GameTypes.MSWEEPER

func _ready() -> void:
	# 1. Load Persian Font Safely
	if ResourceLoader.exists("res://assets/fonts/hekayat.ttf"):
		_game_font = load("res://assets/fonts/hekayat.ttf")
	elif ResourceLoader.exists("res://assets/fonts/Vazir.ttf"):
		_game_font = load("res://assets/fonts/Vazir.ttf")

	# 2. Initialize State Arrays
	_init_data_structures()

	# 3. Build Physical 3D Materials & Board Architecture
	_init_materials()
	_build_scene_hierarchy()
	_build_master_cabinet()
	_build_minefield_grid()
	_build_bottom_console()
	_build_hold_progress_ring()

	# 4. Sync Initial Visual State
	_refresh_all_visuals()

	# 5. Call Base Lifecycle
	super._ready()

func _exit_tree() -> void:
	super._exit_tree()

func _init_data_structures() -> void:
	cell_selected.clear()
	cell_state.clear()
	cell_value.clear()
	for i in range(TOTAL_CELLS):
		cell_selected.append(false)
		cell_state.append(STATE_HIDDEN)
		cell_value.append(0)
	select_mine_remaining = INITIAL_MINES
	select_peace_remaining = INITIAL_SAFE_SPOTS
	is_hit_mine = false
	is_flag_mode = false
	hovered_cell_idx = -1
	_down_cell_idx = -1
	_long_press_triggered = false

func _init_materials() -> void:
	mat_plinth = StandardMaterial3D.new()
	mat_plinth.albedo_color = Color(0.15, 0.09, 0.05)
	mat_plinth.roughness = 0.42
	mat_plinth.metallic = 0.08

	mat_frame = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.24, 0.13, 0.07)
	mat_frame.roughness = 0.34
	mat_frame.metallic = 0.12

	mat_brass_trim = StandardMaterial3D.new()
	mat_brass_trim.albedo_color = Color(0.88, 0.70, 0.28)
	mat_brass_trim.metallic = 0.85
	mat_brass_trim.roughness = 0.22

	mat_playing_bed = StandardMaterial3D.new()
	mat_playing_bed.albedo_color = Color(0.06, 0.11, 0.14)
	mat_playing_bed.roughness = 0.55
	mat_playing_bed.metallic = 0.15

	mat_well_socket = StandardMaterial3D.new()
	mat_well_socket.albedo_color = Color(0.04, 0.07, 0.09)
	mat_well_socket.roughness = 0.65
	mat_well_socket.metallic = 0.20

	# Unrevealed Armored Mechanical Tile Cap (Rich Naval Slate & Warm Bronze-Walnut sheen)
	mat_cap_normal = StandardMaterial3D.new()
	mat_cap_normal.albedo_color = Color(0.18, 0.24, 0.30)
	mat_cap_normal.metallic = 0.42
	mat_cap_normal.roughness = 0.28

	mat_cap_boss = StandardMaterial3D.new()
	mat_cap_boss.albedo_color = Color(0.24, 0.32, 0.39)
	mat_cap_boss.metallic = 0.52
	mat_cap_boss.roughness = 0.24

	mat_gold_rivet = StandardMaterial3D.new()
	mat_gold_rivet.albedo_color = Color(0.95, 0.78, 0.32)
	mat_gold_rivet.metallic = 0.90
	mat_gold_rivet.roughness = 0.18

	# Revealed Empty (0 adjacent mines) - Calm recessed dark emerald-slate floor
	mat_revealed_zero = StandardMaterial3D.new()
	mat_revealed_zero.albedo_color = Color(0.07, 0.15, 0.14)
	mat_revealed_zero.roughness = 0.48
	mat_revealed_zero.metallic = 0.12

	# Revealed Numbered Cell Base
	mat_revealed_num = StandardMaterial3D.new()
	mat_revealed_num.albedo_color = Color(0.10, 0.16, 0.22)
	mat_revealed_num.roughness = 0.32
	mat_revealed_num.metallic = 0.22

	# Per-number subtle tinted 3D plaques for instant gamer readability
	var num_tint_colors = {
		1: Color(0.09, 0.22, 0.32),
		2: Color(0.08, 0.25, 0.16),
		3: Color(0.28, 0.11, 0.12),
		4: Color(0.20, 0.11, 0.30),
		5: Color(0.28, 0.20, 0.08),
		6: Color(0.08, 0.26, 0.26),
		7: Color(0.26, 0.10, 0.24),
		8: Color(0.22, 0.22, 0.24)
	}
	for n in num_tint_colors.keys():
		var m = StandardMaterial3D.new()
		m.albedo_color = num_tint_colors[n]
		m.roughness = 0.30
		m.metallic = 0.25
		_num_tile_mats[n] = m

	# Correctly Flagged Mine Base
	mat_flag_correct_base = StandardMaterial3D.new()
	mat_flag_correct_base.albedo_color = Color(0.07, 0.28, 0.16)
	mat_flag_correct_base.roughness = 0.28
	mat_flag_correct_base.metallic = 0.30
	mat_flag_correct_base.emission_enabled = true
	mat_flag_correct_base.emission = Color(0.12, 0.65, 0.35)
	mat_flag_correct_base.emission_energy_multiplier = 0.40

	# Wrongly Flagged Spot Base
	mat_flag_wrong_base = StandardMaterial3D.new()
	mat_flag_wrong_base.albedo_color = Color(0.28, 0.12, 0.08)
	mat_flag_wrong_base.roughness = 0.32
	mat_flag_wrong_base.metallic = 0.20

	# Exploded Mine Base
	mat_mine_hit_base = StandardMaterial3D.new()
	mat_mine_hit_base.albedo_color = Color(0.32, 0.06, 0.05)
	mat_mine_hit_base.roughness = 0.35
	mat_mine_hit_base.emission_enabled = true
	mat_mine_hit_base.emission = Color(0.95, 0.20, 0.08)
	mat_mine_hit_base.emission_energy_multiplier = 0.65

	# 3D Naval Spiked Mine & Ornaments
	mat_mine_iron = StandardMaterial3D.new()
	mat_mine_iron.albedo_color = Color(0.16, 0.18, 0.20)
	mat_mine_iron.metallic = 0.78
	mat_mine_iron.roughness = 0.26

	mat_mine_charred = StandardMaterial3D.new()
	mat_mine_charred.albedo_color = Color(0.12, 0.05, 0.04)
	mat_mine_charred.metallic = 0.60
	mat_mine_charred.roughness = 0.38
	mat_mine_charred.emission_enabled = true
	mat_mine_charred.emission = Color(1.0, 0.28, 0.05)
	mat_mine_charred.emission_energy_multiplier = 0.55

	mat_flag_gold = StandardMaterial3D.new()
	mat_flag_gold.albedo_color = Color(1.0, 0.84, 0.28)
	mat_flag_gold.metallic = 0.82
	mat_flag_gold.roughness = 0.20
	mat_flag_gold.emission_enabled = true
	mat_flag_gold.emission = Color(1.0, 0.78, 0.20)
	mat_flag_gold.emission_energy_multiplier = 0.35

	mat_flag_emerald = StandardMaterial3D.new()
	mat_flag_emerald.albedo_color = Color(0.18, 0.92, 0.48)
	mat_flag_emerald.roughness = 0.25
	mat_flag_emerald.emission_enabled = true
	mat_flag_emerald.emission = Color(0.15, 0.88, 0.42)
	mat_flag_emerald.emission_energy_multiplier = 0.50

	mat_cross_crimson = StandardMaterial3D.new()
	mat_cross_crimson.albedo_color = Color(1.0, 0.32, 0.24)
	mat_cross_crimson.roughness = 0.25
	mat_cross_crimson.emission_enabled = true
	mat_cross_crimson.emission = Color(0.95, 0.25, 0.18)
	mat_cross_crimson.emission_energy_multiplier = 0.55

	mat_lava_glow = StandardMaterial3D.new()
	mat_lava_glow.albedo_color = Color(1.0, 0.42, 0.10, 0.92)
	mat_lava_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_lava_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_reticle_flag = StandardMaterial3D.new()
	mat_reticle_flag.albedo_color = Color(1.0, 0.72, 0.22, 0.42)
	mat_reticle_flag.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_reticle_flag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Console Mode Buttons
	mat_btn_dig_active = StandardMaterial3D.new()
	mat_btn_dig_active.albedo_color = Color(0.10, 0.42, 0.56)
	mat_btn_dig_active.roughness = 0.24
	mat_btn_dig_active.metallic = 0.25
	mat_btn_dig_active.emission_enabled = true
	mat_btn_dig_active.emission = Color(0.18, 0.72, 0.95)
	mat_btn_dig_active.emission_energy_multiplier = 0.50

	mat_btn_dig_idle = StandardMaterial3D.new()
	mat_btn_dig_idle.albedo_color = Color(0.12, 0.18, 0.24)
	mat_btn_dig_idle.roughness = 0.42
	mat_btn_dig_idle.metallic = 0.18

	mat_btn_flag_active = StandardMaterial3D.new()
	mat_btn_flag_active.albedo_color = Color(0.58, 0.22, 0.12)
	mat_btn_flag_active.roughness = 0.24
	mat_btn_flag_active.metallic = 0.25
	mat_btn_flag_active.emission_enabled = true
	mat_btn_flag_active.emission = Color(1.0, 0.52, 0.18)
	mat_btn_flag_active.emission_energy_multiplier = 0.55

	mat_btn_flag_idle = StandardMaterial3D.new()
	mat_btn_flag_idle.albedo_color = Color(0.22, 0.14, 0.12)
	mat_btn_flag_idle.roughness = 0.42
	mat_btn_flag_idle.metallic = 0.18

	mat_badge_panel = StandardMaterial3D.new()
	mat_badge_panel.albedo_color = Color(0.09, 0.13, 0.17)
	mat_badge_panel.roughness = 0.35
	mat_badge_panel.metallic = 0.25

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
	# 1. Master Beveled Walnut Plinth (Contained strictly inside 1.36m x 1.36m arena)
	var plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(1.14, 0.032, 1.34)
	plinth.mesh = plinth_mesh
	plinth.material_override = mat_plinth
	plinth.position = Vector3(0, 0.016, -0.005)
	board_decor_root.add_child(plinth)

	# 2. Inner Playing Bed (Dark Naval Obsidian-Slate Bed)
	var bed = MeshInstance3D.new()
	var bed_mesh = BoxMesh.new()
	bed_mesh.size = Vector3(1.06, 0.020, 1.06)
	bed.mesh = bed_mesh
	bed.material_override = mat_playing_bed
	bed.position = Vector3(0, 0.034, GRID_CENTER_Z)
	board_decor_root.add_child(bed)

	# 3. 4 Sculpted Mahogany Outer Walls + Gleaming Brass Inlay Strips
	var wall_h: float = 0.050
	var walls = [
		{"pos": Vector3(0, wall_h * 0.5, -0.665), "size": Vector3(1.14, wall_h, 0.032)},
		{"pos": Vector3(0, wall_h * 0.5, 0.655), "size": Vector3(1.14, wall_h, 0.032)},
		{"pos": Vector3(-0.554, wall_h * 0.5, -0.005), "size": Vector3(0.032, wall_h, 1.30)},
		{"pos": Vector3(0.554, wall_h * 0.5, -0.005), "size": Vector3(0.032, wall_h, 1.30)}
	]
	for w in walls:
		var w_inst = MeshInstance3D.new()
		var w_mesh = BoxMesh.new()
		w_mesh.size = w["size"]
		w_inst.mesh = w_mesh
		w_inst.material_override = mat_frame
		w_inst.position = w["pos"]
		board_decor_root.add_child(w_inst)

		var trim = MeshInstance3D.new()
		var t_mesh = BoxMesh.new()
		var s: Vector3 = w["size"]
		t_mesh.size = Vector3(s.x * 0.96, 0.005, s.z * 0.96)
		trim.mesh = t_mesh
		trim.material_override = mat_brass_trim
		trim.position = w["pos"] + Vector3(0, wall_h * 0.5 + 0.002, 0)
		board_decor_root.add_child(trim)

	# 4. Brass Frame Border Around the 8x8 Minefield Grid
	var grid_frame_bars = [
		{"pos": Vector3(0, BOARD_SURFACE_Y - 0.002, GRID_CENTER_Z - 0.512), "size": Vector3(1.036, 0.008, 0.012)},
		{"pos": Vector3(0, BOARD_SURFACE_Y - 0.002, GRID_CENTER_Z + 0.512), "size": Vector3(1.036, 0.008, 0.012)},
		{"pos": Vector3(-0.512, BOARD_SURFACE_Y - 0.002, GRID_CENTER_Z), "size": Vector3(0.012, 0.008, 1.036)},
		{"pos": Vector3(0.512, BOARD_SURFACE_Y - 0.002, GRID_CENTER_Z), "size": Vector3(0.012, 0.008, 1.036)}
	]
	for gb in grid_frame_bars:
		var bar = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = gb["size"]
		bar.mesh = b_mesh
		bar.material_override = mat_brass_trim
		bar.position = gb["pos"]
		board_decor_root.add_child(bar)

func _get_cell_pos(row: int, col: int) -> Vector3:
	var start_x = -((GRID_SIZE - 1) * CELL_STEP) * 0.5
	var start_z = GRID_CENTER_Z - ((GRID_SIZE - 1) * CELL_STEP) * 0.5
	return Vector3(
		start_x + float(col) * CELL_STEP,
		BOARD_SURFACE_Y,
		start_z + float(row) * CELL_STEP
	)

func _build_minefield_grid() -> void:
	cell_centers.resize(TOTAL_CELLS)
	cell_roots.resize(TOTAL_CELLS)
	cell_cap_pivots.resize(TOTAL_CELLS)
	cell_cap_meshes.resize(TOTAL_CELLS)
	cell_cap_reticles.resize(TOTAL_CELLS)
	cell_reveal_pivots.resize(TOTAL_CELLS)
	cell_reveal_Tile_meshes.resize(TOTAL_CELLS)
	cell_number_labels.resize(TOTAL_CELLS)
	cell_ornament_roots.resize(TOTAL_CELLS)

	var socket_mesh = BoxMesh.new()
	socket_mesh.size = Vector3(CELL_W, 0.006, CELL_W)

	# Unrevealed 3D Mechanical Cover Cap
	var cap_mesh = BoxMesh.new()
	cap_mesh.size = Vector3(CELL_W - 0.008, 0.018, CELL_W - 0.008)

	var cap_boss_mesh = CylinderMesh.new()
	cap_boss_mesh.top_radius = 0.024
	cap_boss_mesh.bottom_radius = 0.028
	cap_boss_mesh.height = 0.005
	cap_boss_mesh.radial_segments = 16

	var rivet_mesh = CylinderMesh.new()
	rivet_mesh.top_radius = 0.0045
	rivet_mesh.bottom_radius = 0.0045
	rivet_mesh.height = 0.004
	rivet_mesh.radial_segments = 8

	var reticle_mesh = BoxMesh.new()
	reticle_mesh.size = Vector3(CELL_W - 0.004, 0.003, CELL_W - 0.004)

	# Revealed Floor Plaque
	var reveal_tile_mesh = BoxMesh.new()
	reveal_tile_mesh.size = Vector3(CELL_W - 0.010, 0.010, CELL_W - 0.010)

	var r_offset = (CELL_W - 0.026) * 0.5

	for r in range(GRID_SIZE):
		for c in range(GRID_SIZE):
			var idx = r * GRID_SIZE + c
			var pos = _get_cell_pos(r, c)
			cell_centers[idx] = pos

			var c_root = Node3D.new()
			c_root.name = "Cell_%d" % idx
			c_root.position = pos
			cells_root.add_child(c_root)
			cell_roots[idx] = c_root

			# 1. Recessed Socket Well
			var sock = MeshInstance3D.new()
			sock.mesh = socket_mesh
			sock.material_override = mat_well_socket
			sock.position = Vector3(0, -0.002, 0)
			c_root.add_child(sock)

			# 2. Revealed State Pivot (Sits inside well, revealed when cap flips away)
			var rev_pivot = Node3D.new()
			rev_pivot.name = "RevealPivot"
			rev_pivot.position = Vector3(0, 0.003, 0)
			rev_pivot.visible = false
			c_root.add_child(rev_pivot)
			cell_reveal_pivots[idx] = rev_pivot

			var rev_tile = MeshInstance3D.new()
			rev_tile.mesh = reveal_tile_mesh
			rev_tile.material_override = mat_revealed_zero
			rev_pivot.add_child(rev_tile)
			cell_reveal_Tile_meshes[idx] = rev_tile

			var lbl = Label3D.new()
			if _game_font:
				lbl.font = _game_font
			lbl.font_size = 64
			lbl.pixel_size = 0.00142
			lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			lbl.rotation_degrees = Vector3(-90, 0, 0)
			lbl.position = Vector3(0, 0.008, 0)
			lbl.text = ""
			lbl.outline_modulate = Color(0.04, 0.05, 0.08, 0.98)
			lbl.outline_size = 11
			rev_pivot.add_child(lbl)
			cell_number_labels[idx] = lbl

			# 3D Ornament Container (For Flagged Mine, Wrong Cross, or Exploded Mine)
			var orn_root = Node3D.new()
			orn_root.name = "OrnamentRoot"
			orn_root.position = Vector3(0, 0.006, 0)
			rev_pivot.add_child(orn_root)
			cell_ornament_roots[idx] = orn_root

			# 3. Unrevealed 3D Armored Cover Cap Pivot
			var cap_pivot = Node3D.new()
			cap_pivot.name = "CapPivot"
			cap_pivot.position = Vector3(0, 0.009, 0)
			c_root.add_child(cap_pivot)
			cell_cap_pivots[idx] = cap_pivot

			var cap_inst = MeshInstance3D.new()
			cap_inst.mesh = cap_mesh
			cap_inst.material_override = mat_cap_normal
			cap_pivot.add_child(cap_inst)
			cell_cap_meshes[idx] = cap_inst

			# Center Raised Emblem Boss on Cover Cap
			var boss_inst = MeshInstance3D.new()
			boss_inst.mesh = cap_boss_mesh
			boss_inst.material_override = mat_cap_boss
			boss_inst.position = Vector3(0, 0.010, 0)
			cap_pivot.add_child(boss_inst)

			# 4 Brass Rivets on Cover Cap Corners
			for corner in [
				Vector3(-r_offset, 0.010, -r_offset),
				Vector3(r_offset, 0.010, -r_offset),
				Vector3(-r_offset, 0.010, r_offset),
				Vector3(r_offset, 0.010, r_offset)
			]:
				var riv = MeshInstance3D.new()
				riv.mesh = rivet_mesh
				riv.material_override = mat_gold_rivet
				riv.position = corner
				cap_pivot.add_child(riv)

			# Flag Mode Tactical Reticle Overlay
			var ret = MeshInstance3D.new()
			ret.mesh = reticle_mesh
			ret.material_override = mat_reticle_flag
			ret.position = Vector3(0, 0.012, 0)
			ret.visible = false
			cap_pivot.add_child(ret)
			cell_cap_reticles[idx] = ret

func _build_bottom_console() -> void:
	# 1. Master Console Wood & Brass Base Plinth (Compact, no mode toggle buttons)
	var console_plinth = MeshInstance3D.new()
	var plinth_mesh = BoxMesh.new()
	plinth_mesh.size = Vector3(1.06, 0.024, 0.19)
	console_plinth.mesh = plinth_mesh
	console_plinth.material_override = mat_plinth
	console_plinth.position = Vector3(0, 0.024, CONSOLE_Z)
	console_root.add_child(console_plinth)

	# Brass Divider Bar Between Grid and Console
	var trim_bar = MeshInstance3D.new()
	var trim_mesh = BoxMesh.new()
	trim_mesh.size = Vector3(1.04, 0.008, 0.008)
	trim_bar.mesh = trim_mesh
	trim_bar.material_override = mat_brass_trim
	trim_bar.position = Vector3(0, 0.038, 0.382)
	console_root.add_child(trim_bar)

	# 2. Counter Badges Row (Remaining Flags & Remaining Safe Cells)
	var badge_mesh = BoxMesh.new()
	badge_mesh.size = Vector3(0.48, 0.018, 0.072)
	var badge_rim_mesh = BoxMesh.new()
	badge_rim_mesh.size = Vector3(0.490, 0.012, 0.080)

	# Left Badge: Remaining Mine Flags (پرچم باقی‌مانده)
	var left_badge_pos = Vector3(-0.260, 0.038, 0.448)
	var left_rim = MeshInstance3D.new()
	left_rim.mesh = badge_rim_mesh
	left_rim.material_override = mat_brass_trim
	left_rim.position = left_badge_pos + Vector3(0, -0.003, 0)
	console_root.add_child(left_rim)

	var left_badge = MeshInstance3D.new()
	left_badge.mesh = badge_mesh
	left_badge.material_override = mat_badge_panel
	left_badge.position = left_badge_pos
	console_root.add_child(left_badge)

	badge_mines_lbl = Label3D.new()
	if _game_font:
		badge_mines_lbl.font = _game_font
	badge_mines_lbl.font_size = 36
	badge_mines_lbl.pixel_size = 0.00142
	badge_mines_lbl.rotation_degrees = Vector3(-90, 0, 0)
	badge_mines_lbl.position = left_badge_pos + Vector3(0, 0.012, 0)
	badge_mines_lbl.text = "🚩 پرچم باقی‌مانده: ۱۰"
	badge_mines_lbl.modulate = Color(1.0, 0.88, 0.38)
	badge_mines_lbl.outline_modulate = Color(0.05, 0.05, 0.08)
	badge_mines_lbl.outline_size = 9
	console_root.add_child(badge_mines_lbl)

	# Right Badge: Remaining Safe Cells (خانه‌های امن باقی‌مانده)
	var right_badge_pos = Vector3(0.260, 0.038, 0.448)
	var right_rim = MeshInstance3D.new()
	right_rim.mesh = badge_rim_mesh
	right_rim.material_override = mat_brass_trim
	right_rim.position = right_badge_pos + Vector3(0, -0.003, 0)
	console_root.add_child(right_rim)

	var right_badge = MeshInstance3D.new()
	right_badge.mesh = badge_mesh
	right_badge.material_override = mat_badge_panel
	right_badge.position = right_badge_pos
	console_root.add_child(right_badge)

	badge_safe_lbl = Label3D.new()
	if _game_font:
		badge_safe_lbl.font = _game_font
	badge_safe_lbl.font_size = 36
	badge_safe_lbl.pixel_size = 0.00142
	badge_safe_lbl.rotation_degrees = Vector3(-90, 0, 0)
	badge_safe_lbl.position = right_badge_pos + Vector3(0, 0.012, 0)
	badge_safe_lbl.text = "✨ خانه‌های امن: ۵۴"
	badge_safe_lbl.modulate = Color(0.45, 0.95, 1.0)
	badge_safe_lbl.outline_modulate = Color(0.05, 0.05, 0.08)
	badge_safe_lbl.outline_size = 9
	console_root.add_child(badge_safe_lbl)

	# 3. Dynamic Status & Hold-to-Flag Hint Label
	lbl_status_hint = Label3D.new()
	if _game_font:
		lbl_status_hint.font = _game_font
	lbl_status_hint.font_size = 28
	lbl_status_hint.pixel_size = 0.00136
	lbl_status_hint.rotation_degrees = Vector3(-90, 0, 0)
	lbl_status_hint.position = Vector3(0, 0.040, 0.532)
	lbl_status_hint.text = "ضربه کوتاه: کاوش خانه امن  •  نگه داشتن (لمس طولانی): پرچم‌گذاری مین 🚩"
	lbl_status_hint.modulate = Color(0.96, 0.92, 0.82)
	lbl_status_hint.outline_modulate = Color(0.05, 0.05, 0.08)
	lbl_status_hint.outline_size = 8
	console_root.add_child(lbl_status_hint)

func _build_hold_progress_ring() -> void:
	_hold_ring_mesh = Node3D.new()
	_hold_ring_mesh.name = "HoldIndicatorRoot"
	_hold_ring_mesh.visible = false
	vfx_root.add_child(_hold_ring_mesh)

	_hold_outer_ring = MeshInstance3D.new()
	var outer_t = TorusMesh.new()
	outer_t.inner_radius = 0.042
	outer_t.outer_radius = 0.054
	_hold_outer_ring.mesh = outer_t
	_hold_outer_ring.material_override = mat_flag_gold
	_hold_ring_mesh.add_child(_hold_outer_ring)

	_hold_inner_ring = MeshInstance3D.new()
	var inner_t = TorusMesh.new()
	inner_t.inner_radius = 0.022
	inner_t.outer_radius = 0.034
	_hold_inner_ring.mesh = inner_t
	_hold_inner_ring.material_override = mat_flag_emerald
	_hold_ring_mesh.add_child(_hold_inner_ring)

	_hold_flag_preview = Node3D.new()
	_hold_ring_mesh.add_child(_hold_flag_preview)

	var p_mi = MeshInstance3D.new()
	var p_cyl = CylinderMesh.new()
	p_cyl.top_radius = 0.003
	p_cyl.bottom_radius = 0.0035
	p_cyl.height = 0.068
	p_mi.mesh = p_cyl
	p_mi.position = Vector3(-0.010, 0.034, 0.0)
	p_mi.material_override = mat_brass_trim
	_hold_flag_preview.add_child(p_mi)

	var c_mi = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.036, 0.024, 0.005)
	c_mi.mesh = c_box
	c_mi.position = Vector3(0.010, 0.052, 0.0)
	c_mi.material_override = mat_cross_crimson
	_hold_flag_preview.add_child(c_mi)

# ==============================================================================
# 3D Sculpted Cell Ornaments (Naval Horned Mine, Defuse Flag, Warning Cross)
# ==============================================================================
func _populate_cell_ornament(idx: int, state: int) -> void:
	var orn_root: Node3D = cell_ornament_roots[idx]
	if not is_instance_valid(orn_root):
		return
	for ch in orn_root.get_children():
		ch.queue_free()

	if state == STATE_FLAG_CORRECT:
		var holder = Node3D.new()
		orn_root.add_child(holder)

		# 1. Luxury Octagonal Emerald-Gold Shield Pedestal
		var ped_base = MeshInstance3D.new()
		var ped_cyl = CylinderMesh.new()
		ped_cyl.top_radius = 0.044
		ped_cyl.bottom_radius = 0.050
		ped_cyl.height = 0.010
		ped_cyl.radial_segments = 8
		ped_base.mesh = ped_cyl
		ped_base.material_override = mat_brass_trim
		ped_base.position = Vector3(0, 0.005, 0)
		holder.add_child(ped_base)

		var ped_inlay = MeshInstance3D.new()
		var inlay_cyl = CylinderMesh.new()
		inlay_cyl.top_radius = 0.038
		inlay_cyl.bottom_radius = 0.040
		inlay_cyl.height = 0.005
		inlay_cyl.radial_segments = 8
		ped_inlay.mesh = inlay_cyl
		ped_inlay.material_override = mat_flag_emerald
		ped_inlay.position = Vector3(0, 0.011, 0)
		holder.add_child(ped_inlay)

		# 2. Sculpted 3D Naval Spiked Mine with Brass Collar & Glowing Emerald Defused Core
		var sphere = MeshInstance3D.new()
		var sp_mesh = SphereMesh.new()
		sp_mesh.radius = 0.022
		sp_mesh.height = 0.044
		sphere.mesh = sp_mesh
		sphere.material_override = mat_mine_iron
		sphere.position = Vector3(0.014, 0.026, 0.010)
		holder.add_child(sphere)

		var collar = MeshInstance3D.new()
		var col_mesh = TorusMesh.new()
		col_mesh.inner_radius = 0.018
		col_mesh.outer_radius = 0.025
		collar.mesh = col_mesh
		collar.material_override = mat_gold_rivet
		collar.position = sphere.position
		collar.scale = Vector3(1.0, 0.45, 1.0)
		holder.add_child(collar)

		var safe_core = MeshInstance3D.new()
		var sc_mesh = SphereMesh.new()
		sc_mesh.radius = 0.0085
		sc_mesh.height = 0.017
		safe_core.mesh = sc_mesh
		safe_core.material_override = mat_flag_emerald
		safe_core.position = sphere.position + Vector3(0, 0.020, 0)
		holder.add_child(safe_core)

		var horn_mesh = CylinderMesh.new()
		horn_mesh.top_radius = 0.0022
		horn_mesh.bottom_radius = 0.0045
		horn_mesh.height = 0.016
		for i in range(6):
			var ang = float(i) * PI / 3.0
			var h = MeshInstance3D.new()
			h.mesh = horn_mesh
			h.material_override = mat_gold_rivet
			h.position = sphere.position + Vector3(cos(ang) * 0.019, 0.006, sin(ang) * 0.019)
			h.rotation = Vector3(sin(ang) * 0.85, 0.0, -cos(ang) * 0.85)
			holder.add_child(h)

		# 3. Tall Golden Flagpole + Finial Orb + 3-Segment Waving Crimson-Gold Royal Pennant Flag
		var pole = MeshInstance3D.new()
		var p_mesh = CylinderMesh.new()
		p_mesh.top_radius = 0.0032
		p_mesh.bottom_radius = 0.0045
		p_mesh.height = 0.110
		pole.mesh = p_mesh
		pole.material_override = mat_brass_trim
		pole.position = Vector3(-0.020, 0.062, -0.010)
		holder.add_child(pole)

		var finial = MeshInstance3D.new()
		var fin_sph = SphereMesh.new()
		fin_sph.radius = 0.0075
		fin_sph.height = 0.015
		finial.mesh = fin_sph
		finial.material_override = mat_flag_gold
		finial.position = Vector3(-0.020, 0.120, -0.010)
		holder.add_child(finial)

		var seg_widths = [0.018, 0.017, 0.015]
		var seg_heights = [0.032, 0.026, 0.018]
		var cur_x = -0.009
		for s_idx in range(3):
			var seg_pivot = Node3D.new()
			seg_pivot.position = Vector3(cur_x, 0.098, -0.010)
			holder.add_child(seg_pivot)

			var cloth_mi = MeshInstance3D.new()
			var c_box = BoxMesh.new()
			c_box.size = Vector3(seg_widths[s_idx], seg_heights[s_idx], 0.0055)
			cloth_mi.mesh = c_box
			cloth_mi.material_override = mat_cross_crimson
			seg_pivot.add_child(cloth_mi)

			var trim_mi = MeshInstance3D.new()
			var t_box = BoxMesh.new()
			t_box.size = Vector3(seg_widths[s_idx] + 0.001, 0.0045, 0.0068)
			trim_mi.mesh = t_box
			trim_mi.position = Vector3(0.0, seg_heights[s_idx] * 0.44, 0.0)
			trim_mi.material_override = mat_flag_gold
			seg_pivot.add_child(trim_mi)

			waving_flag_segments.append({
				"node": seg_pivot,
				"phase": float(idx) * 0.65,
				"seg": s_idx
			})
			cur_x += seg_widths[s_idx] - 0.0015

	elif state == STATE_FLAG_WRONG:
		var holder = Node3D.new()
		orn_root.add_child(holder)

		# Beveled Crimson-Brass Hazard Pedestal + Tilted Broken Flagpole + 3D Glowing Cross (✖)
		var ped_mi = MeshInstance3D.new()
		var ped_cyl = CylinderMesh.new()
		ped_cyl.top_radius = 0.042
		ped_cyl.bottom_radius = 0.046
		ped_cyl.height = 0.009
		ped_cyl.radial_segments = 8
		ped_mi.mesh = ped_cyl
		ped_mi.position = Vector3(0.0, 0.0045, 0.0)
		ped_mi.material_override = mat_cross_crimson
		holder.add_child(ped_mi)

		var broken_pole = MeshInstance3D.new()
		var bp_cyl = CylinderMesh.new()
		bp_cyl.top_radius = 0.0028
		bp_cyl.bottom_radius = 0.0038
		bp_cyl.height = 0.060
		broken_pole.mesh = bp_cyl
		broken_pole.position = Vector3(-0.018, 0.030, -0.012)
		broken_pole.rotation_degrees = Vector3(18.0, 0.0, -24.0)
		broken_pole.material_override = mat_brass_trim
		holder.add_child(broken_pole)

		var bar_mesh = BoxMesh.new()
		bar_mesh.size = Vector3(0.076, 0.014, 0.016)
		var bar1 = MeshInstance3D.new()
		bar1.mesh = bar_mesh
		bar1.material_override = mat_cross_crimson
		bar1.position = Vector3(0, 0.018, 0)
		bar1.rotation_degrees = Vector3(0, 45, 0)
		holder.add_child(bar1)

		var bar2 = MeshInstance3D.new()
		bar2.mesh = bar_mesh
		bar2.material_override = mat_cross_crimson
		bar2.position = Vector3(0, 0.018, 0)
		bar2.rotation_degrees = Vector3(0, -45, 0)
		holder.add_child(bar2)

	elif state == STATE_MINE_HIT:
		var holder = Node3D.new()
		orn_root.add_child(holder)

		# Scorched 3D Blast Crater Rim + Glowing Magma Pool + Exposed Spiked Naval Mine
		var crater = MeshInstance3D.new()
		var c_mesh = TorusMesh.new()
		c_mesh.inner_radius = 0.034
		c_mesh.outer_radius = 0.050
		crater.mesh = c_mesh
		crater.material_override = mat_mine_charred
		crater.position = Vector3(0, 0.004, 0)
		crater.scale = Vector3(1.0, 0.45, 1.0)
		holder.add_child(crater)

		var lava_pool = MeshInstance3D.new()
		var l_cyl = CylinderMesh.new()
		l_cyl.top_radius = 0.036
		l_cyl.bottom_radius = 0.036
		l_cyl.height = 0.004
		lava_pool.mesh = l_cyl
		lava_pool.material_override = mat_lava_glow
		lava_pool.position = Vector3(0, 0.003, 0)
		holder.add_child(lava_pool)

		var core = MeshInstance3D.new()
		var sp_mesh = SphereMesh.new()
		sp_mesh.radius = 0.028
		sp_mesh.height = 0.054
		core.mesh = sp_mesh
		core.material_override = mat_mine_charred
		core.position = Vector3(0, 0.020, 0)
		holder.add_child(core)

		var hot_top = MeshInstance3D.new()
		var ht_cyl = CylinderMesh.new()
		ht_cyl.top_radius = 0.014
		ht_cyl.bottom_radius = 0.014
		ht_cyl.height = 0.010
		hot_top.mesh = ht_cyl
		hot_top.material_override = mat_lava_glow
		hot_top.position = Vector3(0, 0.044, 0)
		holder.add_child(hot_top)

		var spike_mesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.002
		spike_mesh.bottom_radius = 0.006
		spike_mesh.height = 0.026
		for i in range(8):
			var ang = float(i) * PI * 0.25
			var sp = MeshInstance3D.new()
			sp.mesh = spike_mesh
			sp.material_override = mat_cross_crimson
			sp.position = Vector3(cos(ang) * 0.024, 0.022, sin(ang) * 0.024)
			sp.rotation = Vector3(sin(ang) * 0.95, 0.0, -cos(ang) * 0.95)
			holder.add_child(sp)

		smoldering_craters.append(holder)

# ==============================================================================
# Visual Synchronization & Color Coding
# ==============================================================================
func _get_number_color(val: int) -> Color:
	match val:
		1: return Color(0.32, 0.90, 1.0)  # Radiant Cyan-Blue
		2: return Color(0.35, 1.0, 0.56)  # Vivid Emerald Green
		3: return Color(1.0, 0.44, 0.38)  # Coral Crimson Red
		4: return Color(0.84, 0.55, 1.0)  # Royal Amethyst Purple
		5: return Color(1.0, 0.84, 0.28)  # Imperial Amber Gold
		6: return Color(0.28, 0.96, 0.88) # Turquoise Teal
		7: return Color(1.0, 0.48, 0.86)  # Vivid Magenta
		8: return Color(1.0, 0.98, 0.92)  # Platinum Ivory
		_: return Color(0.90, 0.90, 0.90)

func _refresh_cell_visual(idx: int, animate_transition: bool = false, delay_sec: float = 0.0) -> void:
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	var st: int = cell_state[idx]
	var val: int = cell_value[idx]
	var cap_pivot: Node3D = cell_cap_pivots[idx]
	var rev_pivot: Node3D = cell_reveal_pivots[idx]
	var rev_tile: MeshInstance3D = cell_reveal_Tile_meshes[idx]
	var lbl: Label3D = cell_number_labels[idx]
	var ret: MeshInstance3D = cell_cap_reticles[idx]

	if st == STATE_HIDDEN:
		if is_instance_valid(cap_pivot):
			cap_pivot.visible = true
			cap_pivot.scale = Vector3.ONE
			cap_pivot.rotation_degrees = Vector3.ZERO
			cap_pivot.position = Vector3(0, 0.009, 0)
		if is_instance_valid(ret):
			ret.visible = is_flag_mode and not is_hit_mine
		if is_instance_valid(rev_pivot):
			rev_pivot.visible = false
		_populate_cell_ornament(idx, STATE_HIDDEN)
		return

	# Cell is revealed / flagged / exploded
	if is_instance_valid(ret):
		ret.visible = false

	# Configure revealed base & ornaments
	if st == STATE_REVEALED:
		_populate_cell_ornament(idx, STATE_REVEALED)
		if val <= 0:
			rev_tile.material_override = mat_revealed_zero
			lbl.text = ""
		else:
			rev_tile.material_override = _num_tile_mats.get(val, mat_revealed_num)
			lbl.text = _fa_num(val)
			lbl.modulate = _get_number_color(val)
	elif st == STATE_FLAG_CORRECT:
		rev_tile.material_override = mat_flag_correct_base
		lbl.text = ""
		_populate_cell_ornament(idx, STATE_FLAG_CORRECT)
	elif st == STATE_FLAG_WRONG:
		rev_tile.material_override = mat_flag_wrong_base
		lbl.text = ""
		_populate_cell_ornament(idx, STATE_FLAG_WRONG)
	elif st == STATE_MINE_HIT:
		rev_tile.material_override = mat_mine_hit_base
		lbl.text = ""
		_populate_cell_ornament(idx, STATE_MINE_HIT)

	if not animate_transition:
		if is_instance_valid(cap_pivot):
			cap_pivot.visible = false
		if is_instance_valid(rev_pivot):
			rev_pivot.visible = true
			rev_pivot.scale = Vector3.ONE
			rev_pivot.position = Vector3(0, 0.003, 0)
		return

	# Animated 3D Mechanical Cap Flip & Reveal Pop
	if is_instance_valid(rev_pivot):
		rev_pivot.visible = true
		rev_pivot.scale = Vector3(0.25, 0.25, 0.25)

	var tw = create_tween()
	if delay_sec > 0.001:
		tw.tween_interval(delay_sec)
	tw.tween_callback(func():
		if is_instance_valid(cap_pivot):
			var cap_tw = create_tween().set_parallel(true)
			cap_tw.tween_property(cap_pivot, "position:y", 0.032, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			cap_tw.tween_property(cap_pivot, "rotation_degrees:x", -75.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			cap_tw.tween_property(cap_pivot, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
			cap_tw.chain().tween_callback(func():
				if is_instance_valid(cap_pivot):
					cap_pivot.visible = false
			)
		if is_instance_valid(rev_pivot):
			var rev_tw = create_tween()
			rev_tw.tween_property(rev_pivot, "scale", Vector3(1.10, 1.15, 1.10), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			rev_tw.tween_property(rev_pivot, "scale", Vector3.ONE, 0.10)
		if st == STATE_REVEALED:
			_spawn_reveal_ripple_vfx(cell_centers[idx], val)
	)

func _refresh_all_visuals() -> void:
	for i in range(TOTAL_CELLS):
		_refresh_cell_visual(i, false)
	_refresh_console_visuals()

func _refresh_console_visuals() -> void:
	if is_instance_valid(badge_mines_lbl):
		badge_mines_lbl.text = "🚩 پرچم باقی‌مانده: %s" % _fa_num(max(0, select_mine_remaining))
	if is_instance_valid(badge_safe_lbl):
		badge_safe_lbl.text = "✨ خانه‌های امن: %s" % _fa_num(max(0, select_peace_remaining))
	for i in range(TOTAL_CELLS):
		if is_instance_valid(cell_cap_reticles[i]):
			cell_cap_reticles[i].visible = false

# ==============================================================================
# 3D Procedural VFX (Ripple Waves, Defuse Shield Burst, Explosion Fireball)
# ==============================================================================
func _spawn_reveal_ripple_vfx(pos: Vector3, val: int) -> void:
	var ring = MeshInstance3D.new()
	var t_mesh = TorusMesh.new()
	t_mesh.inner_radius = 0.016
	t_mesh.outer_radius = 0.026
	ring.mesh = t_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.90, 0.75, 0.75) if val == 0 else _get_number_color(val)
	mat.albedo_color.a = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = pos + Vector3(0, 0.014, 0)
	vfx_root.add_child(ring)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.3, 1.0, 2.3), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_defuse_success_vfx(pos: Vector3) -> void:
	# Expanding Golden-Emerald Shield Ring + Rising Sparkle Stars
	for i in range(2):
		var ring = MeshInstance3D.new()
		var t_mesh = TorusMesh.new()
		t_mesh.inner_radius = 0.022
		t_mesh.outer_radius = 0.034
		ring.mesh = t_mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 1.0, 0.55, 0.95) if i == 0 else Color(1.0, 0.88, 0.30, 0.95)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		ring.position = pos + Vector3(0, 0.016 + float(i) * 0.01, 0)
		vfx_root.add_child(ring)

		var tw = create_tween().set_parallel(true)
		var delay = float(i) * 0.08
		tw.tween_property(ring, "scale", Vector3(2.8, 1.0, 2.8), 0.42).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "position:y", pos.y + 0.065, 0.42).set_delay(delay)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.42).set_delay(delay)
		tw.chain().tween_callback(ring.queue_free)

	# 8 Golden Sparkle Cubes bursting outward
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.012, 0.012, 0.012)
	for s in range(8):
		var sp = MeshInstance3D.new()
		sp.mesh = spark_mesh
		var s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = Color(1.0, 0.92, 0.35, 1.0)
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sp.material_override = s_mat
		sp.position = pos + Vector3(0, 0.025, 0)
		vfx_root.add_child(sp)

		var angle = float(s) * (TAU / 8.0)
		var target_pos = pos + Vector3(cos(angle) * 0.075, 0.085, sin(angle) * 0.075)
		var stw = create_tween().set_parallel(true)
		stw.tween_property(sp, "position", target_pos, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.tween_property(sp, "rotation_degrees", Vector3(180, 240, 90), 0.38)
		stw.tween_property(s_mat, "albedo_color:a", 0.0, 0.38)
		stw.chain().tween_callback(sp.queue_free)

func _spawn_wrong_flag_vfx(pos: Vector3) -> void:
	var ring = MeshInstance3D.new()
	var t_mesh = TorusMesh.new()
	t_mesh.inner_radius = 0.020
	t_mesh.outer_radius = 0.032
	ring.mesh = t_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.32, 0.22, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position = pos + Vector3(0, 0.016, 0)
	vfx_root.add_child(ring)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.34)
	tw.chain().tween_callback(ring.queue_free)

func _launch_and_shatter_cell_cap(idx: int) -> void:
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	var pos: Vector3 = cell_centers[idx]
	var flying_cap = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = Vector3(CELL_W - 0.010, 0.024, CELL_W - 0.010)
	flying_cap.mesh = cap_box
	flying_cap.position = pos + Vector3(0.0, 0.022, 0.0)
	flying_cap.material_override = mat_mine_charred
	vfx_root.add_child(flying_cap)

	var drift_x = randf_range(-0.15, 0.15)
	var drift_z = randf_range(-0.15, 0.15)
	var spin_vec = Vector3(randf_range(9.0, 15.0), randf_range(-10.0, 10.0), randf_range(9.0, 15.0))

	var tw = flying_cap.create_tween().set_parallel(true)
	tw.tween_method(func(t: float):
		var arc_y = sin(t * PI) * 0.44
		flying_cap.position = pos + Vector3(drift_x * t, 0.022 + arc_y, drift_z * t)
		flying_cap.rotation = spin_vec * t
	, 0.0, 1.0, 0.54)
	tw.tween_property(flying_cap, "scale", Vector3(0.05, 0.05, 0.05), 0.54).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(flying_cap.queue_free)

func _trigger_neighbor_blast_ripple(center_idx: int) -> void:
	var cr = center_idx / GRID_SIZE
	var cc = center_idx % GRID_SIZE
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			if dr == 0 and dc == 0:
				continue
			var nr = cr + dr
			var nc = cc + dc
			if nr < 0 or nr >= GRID_SIZE or nc < 0 or nc >= GRID_SIZE:
				continue
			var n_idx = nr * GRID_SIZE + nc
			var dist = sqrt(float(dr * dr + dc * dc))
			var delay = dist * 0.035
			var jump_h = 0.028 / dist
			var c_node: Node3D = cell_roots[n_idx]
			if is_instance_valid(c_node):
				var base_y = cell_centers[n_idx].y
				var tw = c_node.create_tween()
				tw.tween_interval(delay)
				tw.tween_property(c_node, "position:y", base_y + jump_h, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(c_node, "position:y", base_y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _spawn_crater_smolder_puff(local_pos: Vector3) -> void:
	var puff = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.013
	sph.height = 0.026
	puff.mesh = sph

	var sm_mat = StandardMaterial3D.new()
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.albedo_color = Color(0.22, 0.18, 0.17, 0.58)
	sm_mat.emission_enabled = true
	sm_mat.emission = Color(0.95, 0.32, 0.08)
	sm_mat.emission_energy_multiplier = 0.45
	puff.material_override = sm_mat

	puff.position = local_pos + Vector3(randf_range(-0.018, 0.018), 0.032, randf_range(-0.018, 0.018))
	puff.scale = Vector3.ONE * 0.45
	vfx_root.add_child(puff)

	var target_pos = puff.position + Vector3(randf_range(-0.025, 0.025), randf_range(0.08, 0.13), randf_range(-0.025, 0.025))
	var tw = puff.create_tween().set_parallel(true)
	tw.tween_property(puff, "position", target_pos, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "scale", Vector3.ONE * 1.45, 0.85)
	tw.tween_property(sm_mat, "emission_energy_multiplier", 0.0, 0.45)
	tw.tween_property(sm_mat, "albedo_color:a", 0.0, 0.85)
	tw.chain().tween_callback(puff.queue_free)

func _spawn_mine_explosion_vfx(pos: Vector3) -> void:
	var fx = Node3D.new()
	fx.position = pos + Vector3(0.0, 0.022, 0.0)
	vfx_root.add_child(fx)

	# 1. Dynamic 3D OmniLight3D Explosion Flash illuminating the board
	var blast_light = OmniLight3D.new()
	blast_light.light_color = Color(1.0, 0.58, 0.16)
	blast_light.light_energy = 7.5
	blast_light.omni_range = 1.45
	blast_light.position = Vector3(0.0, 0.14, 0.0)
	fx.add_child(blast_light)

	# 2. White-Hot Inner Plasma Core Sphere
	var core_mat = StandardMaterial3D.new()
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = Color(1.0, 0.96, 0.78, 0.98)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.92, 0.65)
	core_mat.emission_energy_multiplier = 4.8

	var core_mi = MeshInstance3D.new()
	var core_sph = SphereMesh.new()
	core_sph.radius = 0.052
	core_sph.height = 0.104
	core_mi.mesh = core_sph
	core_mi.material_override = core_mat
	core_mi.scale = Vector3(0.2, 0.2, 0.2)
	fx.add_child(core_mi)

	# 3. Fiery Orange-Crimson Outer Fireball Sphere
	var fb_mat = StandardMaterial3D.new()
	fb_mat.albedo_color = Color(1.0, 0.42, 0.08, 0.94)
	fb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fb_mat.emission_enabled = true
	fb_mat.emission = Color(1.0, 0.30, 0.04)
	fb_mat.emission_energy_multiplier = 3.6

	var fireball = MeshInstance3D.new()
	var fb_mesh = SphereMesh.new()
	fb_mesh.radius = 0.072
	fb_mesh.height = 0.144
	fireball.mesh = fb_mesh
	fireball.material_override = fb_mat
	fireball.scale = Vector3(0.2, 0.2, 0.2)
	fx.add_child(fireball)

	# 4. Dual Expanding Ground Shockwave Rings
	var ring1_mat = StandardMaterial3D.new()
	ring1_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring1_mat.albedo_color = Color(1.0, 0.78, 0.22, 0.95)
	ring1_mat.emission_enabled = true
	ring1_mat.emission = Color(1.0, 0.68, 0.16)
	ring1_mat.emission_energy_multiplier = 2.8

	var ring1 = MeshInstance3D.new()
	var r_torus = TorusMesh.new()
	r_torus.inner_radius = 0.042
	r_torus.outer_radius = 0.062
	ring1.mesh = r_torus
	ring1.material_override = ring1_mat
	ring1.scale = Vector3(0.3, 1.0, 0.3)
	fx.add_child(ring1)

	var ring2_mat = StandardMaterial3D.new()
	ring2_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring2_mat.albedo_color = Color(1.0, 0.26, 0.10, 0.90)
	ring2_mat.emission_enabled = true
	ring2_mat.emission = Color(1.0, 0.20, 0.06)
	ring2_mat.emission_energy_multiplier = 2.2

	var ring2 = MeshInstance3D.new()
	ring2.mesh = r_torus
	ring2.material_override = ring2_mat
	ring2.scale = Vector3(0.2, 1.0, 0.2)
	fx.add_child(ring2)

	# 5. Rising Mushroom Smoke Plume Cloud Spheres (7 billowing puffs)
	var smoke_puffs: Array = []
	var puff_sph = SphereMesh.new()
	puff_sph.radius = 0.036
	puff_sph.height = 0.072
	for p_i in range(7):
		var sm_mat = StandardMaterial3D.new()
		sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm_mat.albedo_color = Color(0.18, 0.14, 0.13, 0.85)
		sm_mat.roughness = 0.9
		sm_mat.emission_enabled = true
		sm_mat.emission = Color(0.75, 0.22, 0.05)
		sm_mat.emission_energy_multiplier = 0.8

		var puff_mi = MeshInstance3D.new()
		puff_mi.mesh = puff_sph
		puff_mi.material_override = sm_mat
		puff_mi.scale = Vector3.ONE * 0.3
		fx.add_child(puff_mi)

		var ang = float(p_i) * TAU / 7.0
		var rad = 0.045 if p_i > 0 else 0.0
		smoke_puffs.append({
			"node": puff_mi,
			"mat": sm_mat,
			"target_pos": Vector3(cos(ang) * rad, 0.18 + float(p_i % 3) * 0.045, sin(ang) * rad),
			"target_scale": randf_range(1.25, 1.75)
		})

	# 6. 20 Ballistic Shrapnel & Glowing Ember Fragments
	var shrapnel_list: Array = []
	var frag_box = BoxMesh.new()
	frag_box.size = Vector3(0.015, 0.012, 0.018)
	var ember_sph = SphereMesh.new()
	ember_sph.radius = 0.008
	ember_sph.height = 0.016

	for i in range(20):
		var is_ember = (i % 2) == 0
		var sh = MeshInstance3D.new()
		sh.mesh = ember_sph if is_ember else frag_box
		sh.material_override = mat_lava_glow if is_ember else mat_mine_iron
		fx.add_child(sh)

		var ang = (float(i) / 20.0) * TAU + randf_range(-0.18, 0.18)
		var dist = randf_range(0.14, 0.38)
		var peak_h = randf_range(0.14, 0.36)
		var rot_spd = Vector3(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		shrapnel_list.append({
			"node": sh,
			"dir": Vector3(cos(ang) * dist, 0.0, sin(ang) * dist),
			"peak": peak_h,
			"rot": rot_spd
		})

	var tw = fx.create_tween().set_parallel(true)
	tw.tween_property(blast_light, "light_energy", 0.0, 0.65).set_ease(Tween.EASE_OUT)
	tw.tween_property(core_mi, "scale", Vector3(2.2, 2.0, 2.2), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(core_mat, "albedo_color:a", 0.0, 0.26)
	tw.tween_property(fireball, "scale", Vector3(2.8, 2.5, 2.8), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fireball, "position:y", 0.085, 0.36)
	tw.tween_property(fb_mat, "albedo_color:a", 0.0, 0.42)
	tw.tween_property(ring1, "scale", Vector3(4.5, 1.0, 4.5), 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring1_mat, "albedo_color:a", 0.0, 0.44)
	tw.tween_property(ring2, "scale", Vector3(3.2, 1.0, 3.2), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring2_mat, "albedo_color:a", 0.0, 0.55)

	for puff in smoke_puffs:
		var p_node: MeshInstance3D = puff["node"]
		var p_mat: StandardMaterial3D = puff["mat"]
		var t_pos: Vector3 = puff["target_pos"]
		var t_sc: float = puff["target_scale"]
		tw.tween_property(p_node, "position", t_pos, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "scale", Vector3.ONE * t_sc, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_mat, "emission_energy_multiplier", 0.0, 0.35)
		tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.75).set_ease(Tween.EASE_IN)

	for item in shrapnel_list:
		var sh_node: MeshInstance3D = item["node"]
		var target_dir: Vector3 = item["dir"]
		var peak_y: float = item["peak"]
		var rot_vec: Vector3 = item["rot"]
		tw.tween_method(func(t: float):
			var p = target_dir * t
			p.y = sin(t * PI) * peak_y
			sh_node.position = p
			sh_node.rotation = rot_vec * t
		, 0.0, 1.0, 0.58)
		tw.tween_property(sh_node, "scale", Vector3.ZERO, 0.58).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(fx.queue_free)

# ==============================================================================
# Input, Raycasting & Hold-to-Flag Detection
# ==============================================================================
func _process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0

	# 1. Animate 3D waving royal pennant flags on flagged cells
	for item in waving_flag_segments:
		var seg_node: Node3D = item.get("node")
		if is_instance_valid(seg_node):
			var phase: float = float(item.get("phase", 0.0))
			var seg_idx: int = int(item.get("seg", 0))
			var wave = sin(now * 6.5 + phase - float(seg_idx) * 0.95)
			seg_node.position.z = -0.010 + wave * (0.0022 * float(seg_idx + 1))
			seg_node.rotation.y = cos(now * 6.5 + phase - float(seg_idx) * 0.8) * 0.14

	# 2. Spawn continuous smoldering smoke puffs from exploded bomb craters
	_smoke_spawn_accum += delta
	if _smoke_spawn_accum >= 0.25:
		_smoke_spawn_accum = 0.0
		for i in range(TOTAL_CELLS):
			if cell_state[i] == STATE_MINE_HIT:
				_spawn_crater_smolder_puff(cell_centers[i])

	# 3. Hold-to-Flag progress reticle & rising flag preview
	if _raycast_is_down and not _long_press_triggered and _down_cell_idx >= 0 and not is_board_locked and not is_hit_mine:
		var elapsed = now - _raycast_down_time
		if elapsed >= 0.08 and not cell_selected[_down_cell_idx]:
			if is_instance_valid(_hold_ring_mesh):
				_hold_ring_mesh.visible = true
				_hold_ring_mesh.position = cell_centers[_down_cell_idx] + Vector3(0, 0.028, 0)
				var pct = clampf((elapsed - 0.08) / (LONG_PRESS_DURATION - 0.08), 0.1, 1.0)
				if is_instance_valid(_hold_outer_ring):
					_hold_outer_ring.scale = Vector3.ONE * lerpf(1.35, 0.88, pct)
					_hold_outer_ring.rotation.y += delta * 7.5
				if is_instance_valid(_hold_inner_ring):
					_hold_inner_ring.scale = Vector3.ONE * lerpf(0.25, 1.05, pct)
				if is_instance_valid(_hold_flag_preview):
					_hold_flag_preview.scale = Vector3.ONE * ease(pct, 0.5)
					_hold_flag_preview.position.y = lerpf(-0.012, 0.004, pct)
		if elapsed >= LONG_PRESS_DURATION:
			_long_press_triggered = true
			if is_instance_valid(_hold_ring_mesh):
				_hold_ring_mesh.visible = false
			var target_idx = _down_cell_idx
			_restore_cell_cap_after_hold(target_idx)
			_on_cell_long_pressed(target_idx)

func _restore_cell_cap_after_hold(idx: int) -> void:
	if idx >= 0 and idx < TOTAL_CELLS and not cell_selected[idx]:
		if is_instance_valid(cell_cap_pivots[idx]):
			cell_cap_pivots[idx].position.y = 0.009

func _get_hud() -> Control:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud):
		return hud
	return null

func _is_gui_blocking_at(screen_pos: Vector2) -> bool:
	var hud = _get_hud()
	if not hud or not hud.visible:
		return false
	for modal_name in ["StartGameOverlay", "DisconnectPauseDialog", "SurrenderDialog", "RoundFinishBanner", "ReactionPicker", "GameResultDialog", "UserProfileDialog"]:
		var node = hud.get_node_or_null(modal_name)
		if node and node is Control and node.visible:
			return true
	for bar_name in ["BottomBar", "TopHeaderSlot"]:
		var bar = hud.get_node_or_null(bar_name)
		if bar and bar is Control and bar.visible and bar.get_global_rect().has_point(screen_pos):
			return true
	return false

func _project_screen_to_board_plane(screen_pos: Vector2) -> Variant:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return null
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var plane_y = global_position.y + BOARD_SURFACE_Y
	var plane = Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(ray_origin, ray_normal)
	if hit == null:
		return null
	return to_local(hit)

func _find_cell_at_local_pos(hit_pos: Vector3) -> int:
	var best_idx = -1
	var min_dist = 999.0
	for i in range(TOTAL_CELLS):
		var c_pos = cell_centers[i]
		var d = Vector2(hit_pos.x - c_pos.x, hit_pos.z - c_pos.z).length()
		if d <= (CELL_W * 0.56) and d < min_dist:
			min_dist = d
			best_idx = i
	return best_idx

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked:
		return

	# Support Right-Click on Desktop to directly Flag a Mine!
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_gui_blocking_at(event.position):
			return
		var hit = _project_screen_to_board_plane(event.position)
		if hit != null:
			var c_idx = _find_cell_at_local_pos(hit)
			if c_idx != -1:
				_flag_mine_on_cell(c_idx)
		return

	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch):
		var pos = event.position
		if _is_gui_blocking_at(pos):
			_cancel_pointer_down()
			return

		if event.pressed:
			_raycast_down_pos = pos
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
			_long_press_triggered = false
			var hit = _project_screen_to_board_plane(pos)
			_down_cell_idx = _find_cell_at_local_pos(hit) if hit != null else -1
			if _down_cell_idx >= 0 and not cell_selected[_down_cell_idx] and is_instance_valid(cell_cap_pivots[_down_cell_idx]):
				cell_cap_pivots[_down_cell_idx].position.y = 0.005
		else:
			if _down_cell_idx >= 0:
				_restore_cell_cap_after_hold(_down_cell_idx)
			if is_instance_valid(_hold_ring_mesh):
				_hold_ring_mesh.visible = false
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = _raycast_down_pos.distance_to(pos)
				var dur = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if not _long_press_triggered and dist < DRAG_CLICK_THRESHOLD and dur < 0.65:
					_handle_tap_at(pos)
			_down_cell_idx = -1
			_long_press_triggered = false

	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _raycast_is_down and event.position.distance_to(_raycast_down_pos) > DRAG_CLICK_THRESHOLD:
			if _down_cell_idx >= 0:
				_restore_cell_cap_after_hold(_down_cell_idx)
			_cancel_pointer_down()

func _cancel_pointer_down() -> void:
	if _down_cell_idx >= 0:
		_restore_cell_cap_after_hold(_down_cell_idx)
	_raycast_is_down = false
	_down_cell_idx = -1
	_long_press_triggered = false
	if is_instance_valid(_hold_ring_mesh):
		_hold_ring_mesh.visible = false

func _handle_tap_at(screen_pos: Vector2) -> void:
	var hit = _project_screen_to_board_plane(screen_pos)
	if hit == null:
		return
	var hit_pos: Vector3 = hit

	var cell_idx = _find_cell_at_local_pos(hit_pos)
	if cell_idx != -1:
		_on_cell_tapped(cell_idx)

func _on_cell_tapped(idx: int) -> void:
	if is_hit_mine:
		AudioManager.play_sound("tap_wrong")
		show_hint("💥 شما قبلاً روی مین رفته‌اید! منتظر پایان بازی بمانید.")
		return
	if cell_selected[idx]:
		AudioManager.play_sound("tap")
		return

	# Short tap always digs/reveals safe cell; holding flags as mine!
	_reveal_safe_cell(idx)

func _on_cell_long_pressed(idx: int) -> void:
	if is_hit_mine or cell_selected[idx]:
		return
	_flag_mine_on_cell(idx)

func _reveal_safe_cell(idx: int) -> void:
	if select_peace_remaining <= 0 or cell_selected[idx] or is_hit_mine:
		return
	AudioManager.play_sound("tap")
	if is_instance_valid(cell_cap_pivots[idx]):
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cell_cap_pivots[idx].position.y = 0.004
		tw.tween_property(cell_cap_pivots[idx], "position:y", 0.009, 0.16)
	NetworkManager.send_select_peace(idx)

func _flag_mine_on_cell(idx: int) -> void:
	if is_hit_mine:
		AudioManager.play_sound("tap_wrong")
		show_hint("💥 شما قبلاً روی مین رفته‌اید!")
		return
	if cell_selected[idx]:
		return
	if select_mine_remaining <= 0:
		AudioManager.play_sound("tap_wrong")
		show_hint("⚠️ تمام ۱۰ پرچم مین خود را استفاده کرده‌اید!")
		if is_instance_valid(lbl_status_hint):
			lbl_status_hint.text = "⚠️ تمام ۱۰ پرچم استفاده شده است • خانه‌های امن را باز کنید"
		return

	AudioManager.play_sound("add_peace")
	select_mine_remaining = max(0, select_mine_remaining - 1)
	_refresh_console_visuals()
	NetworkManager.send_select_mine(idx)

# ==============================================================================
# BaseGameBoard Server Command Hooks (100% Parity with Backend & Flutter)
# ==============================================================================
func on_start_game() -> void:
	is_board_locked = false
	is_my_turn = true

func on_select_peace_result(payload: Dictionary) -> void:
	var peace_num = int(payload.get("peace_number", -1))
	var val = int(payload.get("value", 0))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return

	if not cell_selected[peace_num]:
		select_peace_remaining = max(0, select_peace_remaining - 1)
	cell_selected[peace_num] = true
	cell_state[peace_num] = STATE_REVEALED
	cell_value[peace_num] = val

	# Calculate smooth domino cascade delay when server flood-fills 0s
	var now_ms = Time.get_ticks_msec()
	if now_ms - _last_reveal_msec < 90:
		_cascade_counter = min(_cascade_counter + 1, 18)
	else:
		_cascade_counter = 0
	_last_reveal_msec = now_ms

	var delay_sec = float(_cascade_counter) * 0.025
	if _cascade_counter == 0:
		AudioManager.play_sound("add_peace")

	_refresh_cell_visual(peace_num, true, delay_sec)
	_refresh_console_visuals()

	if is_instance_valid(lbl_status_hint) and not is_hit_mine:
		if val == 0:
			lbl_status_hint.text = "✨ منطقه امن باز شد! به کاوش و پیدا کردن مین‌ها ادامه دهید"
			lbl_status_hint.modulate = Color(0.45, 0.95, 1.0)
		else:
			lbl_status_hint.text = "🔍 در همسایگی این خانه %s مین پنهان شده است" % _fa_num(val)
			lbl_status_hint.modulate = _get_number_color(val)

func on_mine_selected(payload: Dictionary) -> void:
	var peace_num = int(payload.get("peace_number", payload.get("n", -1)))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return

	is_hit_mine = true
	select_mine_remaining = 0
	select_peace_remaining = 0
	cell_selected[peace_num] = true
	cell_state[peace_num] = STATE_MINE_HIT

	AudioManager.play_sound("explode")
	AudioManager.play_sound("hit")
	ActionVFXManager.shake_camera(0.085, 0.55)
	_launch_and_shatter_cell_cap(peace_num)
	_refresh_cell_visual(peace_num, true, 0.0)
	_spawn_mine_explosion_vfx(cell_centers[peace_num])
	_trigger_neighbor_blast_ripple(peace_num)
	_refresh_console_visuals()

	if is_instance_valid(lbl_status_hint):
		lbl_status_hint.text = "💥 متاسفانه روی مین رفتید! منتظر پایان بازی حریف بمانید..."
		lbl_status_hint.modulate = Color(1.0, 0.38, 0.32)
	show_hint("💥 انفجار مین! امکان انتخاب خانه جدید وجود ندارد.")

func on_select_mine_correct(payload: Dictionary) -> void:
	var peace_num = int(payload.get("peace_number", -1))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return

	cell_selected[peace_num] = true
	cell_state[peace_num] = STATE_FLAG_CORRECT

	AudioManager.play_sound("correct")
	_refresh_cell_visual(peace_num, true, 0.0)
	_spawn_defuse_success_vfx(cell_centers[peace_num])
	_refresh_console_visuals()

	if is_instance_valid(lbl_status_hint):
		lbl_status_hint.text = "🎯 آفرین! مین با موفقیت کشف و خنثی شد (+۱ امتیاز)"
		lbl_status_hint.modulate = Color(0.38, 1.0, 0.55)

func on_select_mine_wrong(payload: Dictionary) -> void:
	var peace_num = int(payload.get("peace_number", -1))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return

	cell_selected[peace_num] = true
	cell_state[peace_num] = STATE_FLAG_WRONG

	AudioManager.play_sound("tap_wrong")
	ActionVFXManager.shake_camera(0.028, 0.22)
	_refresh_cell_visual(peace_num, true, 0.0)
	_spawn_wrong_flag_vfx(cell_centers[peace_num])
	_refresh_console_visuals()

	# Horizontal shake on the wrong cross ornament
	if is_instance_valid(cell_ornament_roots[peace_num]):
		var orn = cell_ornament_roots[peace_num]
		var tw = create_tween()
		tw.tween_property(orn, "position:x", 0.012, 0.05)
		tw.tween_property(orn, "position:x", -0.012, 0.05)
		tw.tween_property(orn, "position:x", 0.008, 0.05)
		tw.tween_property(orn, "position:x", 0.0, 0.05)

	if is_instance_valid(lbl_status_hint):
		lbl_status_hint.text = "⚠️ این خانه مین نبود! یک پرچم از دست رفت"
		lbl_status_hint.modulate = Color(1.0, 0.45, 0.35)

func on_player_score(payload: Dictionary) -> void:
	var g_id = int(payload.get("gamer_id", 0))
	var val = int(payload.get("value", 0))
	if g_id != GameManager.my_player_index and g_id > 0:
		if is_instance_valid(lbl_status_hint) and not is_hit_mine:
			lbl_status_hint.text = "⚡ حریف یک مین کشف کرد! (امتیاز حریف: %s)" % _fa_num(val)

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var arr: Array = board_data as Array
	for i in range(min(TOTAL_CELLS, arr.size())):
		var item = arr[i]
		if typeof(item) == TYPE_DICTIONARY:
			var is_sel = bool(item.get("selected", false))
			var is_corr = bool(item.get("correctly_selected_mine", false))
			var is_wrong = bool(item.get("wrongly_selected_mine", false))
			var is_hit = bool(item.get("hitted_mine", false))
			var val = int(item.get("value", 0))

			cell_selected[i] = is_sel
			cell_value[i] = val
			if is_hit:
				cell_state[i] = STATE_MINE_HIT
				cell_selected[i] = true
			elif is_corr:
				cell_state[i] = STATE_FLAG_CORRECT
				cell_selected[i] = true
			elif is_wrong:
				cell_state[i] = STATE_FLAG_WRONG
				cell_selected[i] = true
			elif is_sel:
				cell_state[i] = STATE_REVEALED
			else:
				cell_state[i] = STATE_HIDDEN
	_refresh_all_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("remaining_selectable_mines"):
			select_mine_remaining = int(g_data["remaining_selectable_mines"])
		if g_data.has("remaining_selectable_peaces"):
			select_peace_remaining = int(g_data["remaining_selectable_peaces"])
		if g_data.has("is_tapped_mine"):
			is_hit_mine = bool(g_data["is_tapped_mine"])
		if g_data.has("board"):
			sync_board_state(g_data["board"])
	is_board_locked = false
	is_my_turn = true
	_refresh_all_visuals()

func reset_board() -> void:
	_cancel_pointer_down()
	_init_data_structures()
	for ch in vfx_root.get_children():
		if ch != _hold_ring_mesh:
			ch.queue_free()
	_refresh_all_visuals()

func cleanup_board() -> void:
	_cancel_pointer_down()
	for ch in vfx_root.get_children():
		ch.queue_free()

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
