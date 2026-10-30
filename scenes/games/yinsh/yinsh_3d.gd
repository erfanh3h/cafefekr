class_name Yinsh3D
extends "res://scripts/games/base_game_board.gd"

# Yinsh 3D Board (یینش — Cafe Fekr Royal Tournament Edition)
# Exact 1:1 port of Flutter YinshController + Python Backend YinshGameClass & YinshGameSession.
# Features:
# - 3 Distinct Custom Sculpted 3D Models:
#   1. Player 1 (Red) 3D Commander Ring: Imperial Ruby Crimson Torus + 24K Gold Beveled Rim + 6 Compass Studs
#   2. Player 2 (Blue) 3D Commander Ring: Royal Sapphire Cobalt Torus + Brushed Platinum Beveled Rim + 6 Hex Studs
#   3. 3D Dual-Sided Reversible Yinsh Disk / Marker: FlipPivot with Ruby Red Top Face, Sapphire Blue Bottom Face,
#      and 24K Gold Equatorial Band that performs a 180-degree mid-air somersault when jumped over!
# - Luxury 85-Node Equilateral Triangular Lattice Board (0..84 across 11 rows)
# - Left & Right Mahogany Side Trays with 5 Reserve Ring Pegs + 3 Trophy Score Pedestals per player
# - Live 3D Remaining Disks Plaque (۵۱ دیسک) & Phase Status Banner
# - Hover Trajectory Preview & 5-in-a-Row Victory Celebration VFX

const NUM_SPOTS: int = 85
const ALL_DIRECTIONS: Array[int] = [1, 2, 3, 4, 5, 6]
const DOOZ_DIRECTIONS: Array = [[1, 4], [2, 5], [3, 6]]

# Lattice geometry constants (fits cleanly inside CafeTable play surface)
const HALF_COL_DX: float = 0.052
const ROW_DZ: float = 0.090
const BOARD_SURFACE_Y: float = 0.036

# Exact 11-row column offset table for all 85 spots (0..84)
const ROW_COLS: Array = [
	[-3, -1, 1, 3],                           # Row 0:  0..3   (4 spots)
	[-6, -4, -2, 0, 2, 4, 6],                 # Row 1:  4..10  (7 spots)
	[-7, -5, -3, -1, 1, 3, 5, 7],             # Row 2: 11..18  (8 spots)
	[-8, -6, -4, -2, 0, 2, 4, 6, 8],          # Row 3: 19..27  (9 spots)
	[-9, -7, -5, -3, -1, 1, 3, 5, 7, 9],      # Row 4: 28..37 (10 spots)
	[-8, -6, -4, -2, 0, 2, 4, 6, 8],          # Row 5: 38..46  (9 spots)
	[-9, -7, -5, -3, -1, 1, 3, 5, 7, 9],      # Row 6: 47..56 (10 spots)
	[-8, -6, -4, -2, 0, 2, 4, 6, 8],          # Row 7: 57..65  (9 spots)
	[-7, -5, -3, -1, 1, 3, 5, 7],             # Row 8: 66..73  (8 spots)
	[-6, -4, -2, 0, 2, 4, 6],                 # Row 9: 74..80  (7 spots)
	[-3, -1, 1, 3]                            # Row 10: 81..84 (4 spots)
]

# --- Authoritative Game State ---
var spot_positions: Array[Vector3] = []
var spot_neighbors: Array = [] # Array of Dictionary: dir_id (1..6) -> neighbor_piece_id
var ring_owners: Array[int] = [] # 0 = none, 1 = P1, 2 = P2
var disk_owners: Array[int] = [] # 0 = none, 1 = P1, 2 = P2

var is_setup_ring_phase: bool = true
var player1_rings_left: int = 5
var player2_rings_left: int = 5
var player1_score: int = 0
var player2_score: int = 0
var remaining_disks: int = 51
var last_selected_piece_id: int = -1
var possible_moves: Array[int] = []
var last_move_from: int = -1
var last_move_to: int = -1
var hovered_piece_id: int = -1

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _pulse_time: float = 0.0

# --- 3D Scene Nodes ---
var board_root: Node3D = null
var nodes_root: Node3D = null
var pieces_root: Node3D = null
var trays_root: Node3D = null
var fx_root: Node3D = null
var hover_preview_root: Node3D = null

var node_areas: Array[Area3D] = []
var node_socket_meshes: Array[MeshInstance3D] = []
var node_legal_halos: Array[MeshInstance3D] = []
var node_select_halos: Array[MeshInstance3D] = []
var node_last_halos: Array[MeshInstance3D] = []

# Active 3D piece instances on the 85 board spots (null when empty)
var board_ring_nodes: Array[Node3D] = []
var board_disk_nodes: Array[Node3D] = []

# Side tray reserve rings & trophy score slots
var p1_reserve_positions: Array[Vector3] = []
var p2_reserve_positions: Array[Vector3] = []
var p1_reserve_rings: Array[Node3D] = []
var p2_reserve_rings: Array[Node3D] = []

var p1_trophy_positions: Array[Vector3] = []
var p2_trophy_positions: Array[Vector3] = []
var p1_trophy_rings: Array[Node3D] = []
var p2_trophy_rings: Array[Node3D] = []

var lbl_disks_3d: Label3D = null
var lbl_phase_3d: Label3D = null
var lbl_p1_tray_3d: Label3D = null
var lbl_p2_tray_3d: Label3D = null

# --- Luxury Procedural Materials ---
var mat_walnut_plinth: StandardMaterial3D
var mat_ebony_surface: StandardMaterial3D
var mat_parchment_tri: StandardMaterial3D
var mat_obsidian_tri: StandardMaterial3D
var mat_gold_rail: StandardMaterial3D
var mat_brass_socket: StandardMaterial3D
var mat_socket_well: StandardMaterial3D

var mat_ring_p1_body: StandardMaterial3D
var mat_ring_p1_gold: StandardMaterial3D
var mat_ring_p2_body: StandardMaterial3D
var mat_ring_p2_plat: StandardMaterial3D

var mat_disk_edge_gold: StandardMaterial3D
var mat_disk_p1_face: StandardMaterial3D
var mat_disk_p2_face: StandardMaterial3D

var mat_halo_legal: StandardMaterial3D
var mat_halo_select: StandardMaterial3D
var mat_halo_last: StandardMaterial3D
var mat_Win_beam: StandardMaterial3D
var mat_ghost_p1: StandardMaterial3D
var mat_ghost_p2: StandardMaterial3D

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

func _init() -> void:
	game_type = GameTypes.YINSH

func _enter_tree() -> void:
	super._enter_tree()
	_connect_yinsh_signals()

func _ready() -> void:
	game_type = GameTypes.YINSH
	add_to_group("board")
	_build_lattice_topology()
	_init_materials()
	_build_board_3d()
	_init_board_state()
	_rebuild_all_pieces_visual()
	_sync_hud_scores()
	super._ready()

func _exit_tree() -> void:
	_disconnect_yinsh_signals()
	super._exit_tree()

func _connect_yinsh_signals() -> void:
	if not NetworkManager.ring_submitted.is_connected(on_ring_submitted):
		NetworkManager.ring_submitted.connect(on_ring_submitted)
	if not NetworkManager.ring_moved.is_connected(on_ring_moved):
		NetworkManager.ring_moved.connect(on_ring_moved)
	if not NetworkManager.remove_peace_received.is_connected(on_remove_peace):
		NetworkManager.remove_peace_received.connect(on_remove_peace)
	if not NetworkManager.win_happened_received.is_connected(on_win_happened):
		NetworkManager.win_happened_received.connect(on_win_happened)

func _disconnect_yinsh_signals() -> void:
	if NetworkManager.ring_submitted.is_connected(on_ring_submitted):
		NetworkManager.ring_submitted.disconnect(on_ring_submitted)
	if NetworkManager.ring_moved.is_connected(on_ring_moved):
		NetworkManager.ring_moved.disconnect(on_ring_moved)
	if NetworkManager.remove_peace_received.is_connected(on_remove_peace):
		NetworkManager.remove_peace_received.disconnect(on_remove_peace)
	if NetworkManager.win_happened_received.is_connected(on_win_happened):
		NetworkManager.win_happened_received.disconnect(on_win_happened)

func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse_fast = 1.0 + 0.08 * sin(_pulse_time * 5.5)
	var pulse_slow = 1.0 + 0.05 * sin(_pulse_time * 3.8)
	for i in range(NUM_SPOTS):
		if i < node_legal_halos.size() and is_instance_valid(node_legal_halos[i]) and node_legal_halos[i].visible:
			node_legal_halos[i].scale = Vector3(pulse_fast, 1.0, pulse_fast)
		if i < node_select_halos.size() and is_instance_valid(node_select_halos[i]) and node_select_halos[i].visible:
			node_select_halos[i].scale = Vector3(pulse_slow, 1.0, pulse_slow)
	if last_selected_piece_id >= 0 and last_selected_piece_id < board_ring_nodes.size():
		var sel_ring = board_ring_nodes[last_selected_piece_id]
		if is_instance_valid(sel_ring):
			sel_ring.position.y = BOARD_SURFACE_Y + 0.026 + 0.006 * sin(_pulse_time * 6.0)

# ============================================================================
# 1. EXACT 85-NODE EQUILATERAL LATTICE & 6-DIRECTION TOPOLOGY
# ============================================================================

func _build_lattice_topology() -> void:
	spot_positions.resize(NUM_SPOTS)
	spot_neighbors.resize(NUM_SPOTS)
	var coord_to_id: Dictionary = {}
	var pid: int = 0
	for r in range(ROW_COLS.size()):
		var cols: Array = ROW_COLS[r]
		for c in cols:
			var col_i: int = int(c)
			coord_to_id[Vector2i(r, col_i)] = pid
			var x: float = float(col_i) * HALF_COL_DX
			var z: float = (float(r) - 5.0) * ROW_DZ
			spot_positions[pid] = Vector3(x, BOARD_SURFACE_Y, z)
			spot_neighbors[pid] = {}
			pid += 1

	# 6 Hex Directions matching backend Entities/Games/Yinsh/directions.py 100%:
	# 1: (-1, +1) Up-Right
	# 2: ( 0, +2) Right
	# 3: (+1, +1) Down-Right
	# 4: (+1, -1) Down-Left
	# 5: ( 0, -2) Left
	# 6: (-1, -1) Up-Left
	var dir_offsets: Dictionary = {
		1: Vector2i(-1, 1),
		2: Vector2i(0, 2),
		3: Vector2i(1, 1),
		4: Vector2i(1, -1),
		5: Vector2i(0, -2),
		6: Vector2i(-1, -1)
	}
	for coord in coord_to_id.keys():
		var cur_id: int = coord_to_id[coord]
		var nbr_dict: Dictionary = {}
		for d in ALL_DIRECTIONS:
			var target_coord: Vector2i = coord + dir_offsets[d]
			if coord_to_id.has(target_coord):
				nbr_dict[d] = int(coord_to_id[target_coord])
		spot_neighbors[cur_id] = nbr_dict

# ============================================================================
# 2. LUXURY PROCEDURAL MATERIALS
# ============================================================================

func _init_materials() -> void:
	mat_walnut_plinth = StandardMaterial3D.new()
	mat_walnut_plinth.albedo_color = Color(0.19, 0.10, 0.05)
	mat_walnut_plinth.metallic = 0.08
	mat_walnut_plinth.roughness = 0.34
	mat_walnut_plinth.clearcoat_enabled = true
	mat_walnut_plinth.clearcoat = 0.55

	mat_ebony_surface = StandardMaterial3D.new()
	mat_ebony_surface.albedo_color = Color(0.08, 0.07, 0.09)
	mat_ebony_surface.metallic = 0.20
	mat_ebony_surface.roughness = 0.36
	mat_ebony_surface.clearcoat_enabled = true
	mat_ebony_surface.clearcoat = 0.40

	mat_parchment_tri = StandardMaterial3D.new()
	mat_parchment_tri.albedo_color = Color(0.18, 0.15, 0.12)
	mat_parchment_tri.metallic = 0.12
	mat_parchment_tri.roughness = 0.42

	mat_obsidian_tri = StandardMaterial3D.new()
	mat_obsidian_tri.albedo_color = Color(0.11, 0.10, 0.13)
	mat_obsidian_tri.metallic = 0.18
	mat_obsidian_tri.roughness = 0.38

	mat_gold_rail = StandardMaterial3D.new()
	mat_gold_rail.albedo_color = Color(0.94, 0.78, 0.30)
	mat_gold_rail.metallic = 0.88
	mat_gold_rail.roughness = 0.22

	mat_brass_socket = StandardMaterial3D.new()
	mat_brass_socket.albedo_color = Color(0.80, 0.64, 0.26)
	mat_brass_socket.metallic = 0.82
	mat_brass_socket.roughness = 0.28

	mat_socket_well = StandardMaterial3D.new()
	mat_socket_well.albedo_color = Color(0.04, 0.04, 0.05)
	mat_socket_well.metallic = 0.15
	mat_socket_well.roughness = 0.55

	# Model 1: Player 1 (Red) Sculpted Commander Ring
	mat_ring_p1_body = StandardMaterial3D.new()
	mat_ring_p1_body.albedo_color = Color(0.86, 0.11, 0.16)
	mat_ring_p1_body.metallic = 0.28
	mat_ring_p1_body.roughness = 0.16
	mat_ring_p1_body.clearcoat_enabled = true
	mat_ring_p1_body.clearcoat = 0.95
	mat_ring_p1_body.clearcoat_roughness = 0.08
	mat_ring_p1_body.emission_enabled = true
	mat_ring_p1_body.emission = Color(0.55, 0.05, 0.08)
	mat_ring_p1_body.emission_energy_multiplier = 0.35

	mat_ring_p1_gold = StandardMaterial3D.new()
	mat_ring_p1_gold.albedo_color = Color(1.0, 0.82, 0.30)
	mat_ring_p1_gold.metallic = 0.94
	mat_ring_p1_gold.roughness = 0.16

	# Model 2: Player 2 (Blue) Sculpted Commander Ring
	mat_ring_p2_body = StandardMaterial3D.new()
	mat_ring_p2_body.albedo_color = Color(0.10, 0.42, 0.90)
	mat_ring_p2_body.metallic = 0.30
	mat_ring_p2_body.roughness = 0.16
	mat_ring_p2_body.clearcoat_enabled = true
	mat_ring_p2_body.clearcoat = 0.95
	mat_ring_p2_body.clearcoat_roughness = 0.08
	mat_ring_p2_body.emission_enabled = true
	mat_ring_p2_body.emission = Color(0.05, 0.22, 0.58)
	mat_ring_p2_body.emission_energy_multiplier = 0.38

	mat_ring_p2_plat = StandardMaterial3D.new()
	mat_ring_p2_plat.albedo_color = Color(0.86, 0.91, 0.98)
	mat_ring_p2_plat.metallic = 0.92
	mat_ring_p2_plat.roughness = 0.16

	# Model 3: Reversible Dual-Sided Yinsh Disk
	mat_disk_edge_gold = StandardMaterial3D.new()
	mat_disk_edge_gold.albedo_color = Color(0.92, 0.76, 0.32)
	mat_disk_edge_gold.metallic = 0.88
	mat_disk_edge_gold.roughness = 0.22

	mat_disk_p1_face = StandardMaterial3D.new()
	mat_disk_p1_face.albedo_color = Color(0.92, 0.16, 0.20)
	mat_disk_p1_face.metallic = 0.18
	mat_disk_p1_face.roughness = 0.20
	mat_disk_p1_face.clearcoat_enabled = true
	mat_disk_p1_face.clearcoat = 0.90
	mat_disk_p1_face.emission_enabled = true
	mat_disk_p1_face.emission = Color(0.50, 0.06, 0.08)
	mat_disk_p1_face.emission_energy_multiplier = 0.28

	mat_disk_p2_face = StandardMaterial3D.new()
	mat_disk_p2_face.albedo_color = Color(0.14, 0.52, 0.96)
	mat_disk_p2_face.metallic = 0.18
	mat_disk_p2_face.roughness = 0.20
	mat_disk_p2_face.clearcoat_enabled = true
	mat_disk_p2_face.clearcoat = 0.90
	mat_disk_p2_face.emission_enabled = true
	mat_disk_p2_face.emission = Color(0.06, 0.24, 0.55)
	mat_disk_p2_face.emission_energy_multiplier = 0.30

	# Interactive Halos & Previews
	mat_halo_legal = StandardMaterial3D.new()
	mat_halo_legal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo_legal.albedo_color = Color(0.25, 0.98, 0.52, 0.88)
	mat_halo_legal.emission_enabled = true
	mat_halo_legal.emission = Color(0.20, 0.95, 0.48)
	mat_halo_legal.emission_energy_multiplier = 1.65

	mat_halo_select = StandardMaterial3D.new()
	mat_halo_select.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo_select.albedo_color = Color(1.0, 0.86, 0.28, 0.88)
	mat_halo_select.emission_enabled = true
	mat_halo_select.emission = Color(1.0, 0.82, 0.22)
	mat_halo_select.emission_energy_multiplier = 1.55

	mat_halo_last = StandardMaterial3D.new()
	mat_halo_last.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo_last.albedo_color = Color(0.98, 0.76, 0.24, 0.72)
	mat_halo_last.emission_enabled = true
	mat_halo_last.emission = Color(0.95, 0.70, 0.18)
	mat_halo_last.emission_energy_multiplier = 0.95

	mat_Win_beam = StandardMaterial3D.new()
	mat_Win_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_Win_beam.albedo_color = Color(1.0, 0.90, 0.35, 0.92)
	mat_Win_beam.emission_enabled = true
	mat_Win_beam.emission = Color(1.0, 0.84, 0.25)
	mat_Win_beam.emission_energy_multiplier = 2.4

	mat_ghost_p1 = StandardMaterial3D.new()
	mat_ghost_p1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost_p1.albedo_color = Color(1.0, 0.28, 0.32, 0.46)
	mat_ghost_p1.emission_enabled = true
	mat_ghost_p1.emission = Color(1.0, 0.22, 0.26)
	mat_ghost_p1.emission_energy_multiplier = 1.1

	mat_ghost_p2 = StandardMaterial3D.new()
	mat_ghost_p2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost_p2.albedo_color = Color(0.28, 0.68, 1.0, 0.46)
	mat_ghost_p2.emission_enabled = true
	mat_ghost_p2.emission = Color(0.22, 0.58, 1.0)
	mat_ghost_p2.emission_energy_multiplier = 1.1

# ============================================================================
# 3. THREE CUSTOM SCULPTED 3D MODELS (RED RING, BLUE RING, REVERSIBLE DISK)
# ============================================================================

# Model 1 (gamer_id == 1) & Model 2 (gamer_id == 2):
# Sculpted 3D Commander Ring with inner metallic collar, top/bottom beveled inlay rings,
# and 6 compass studs aligned with the 6 hex movement axes.
func _create_ring_3d_model(gamer_id: int, is_ghost: bool = false) -> Node3D:
	var root = Node3D.new()
	root.name = "YinshRingP%d" % gamer_id

	var body_mat: StandardMaterial3D
	var trim_mat: StandardMaterial3D
	if is_ghost:
		body_mat = mat_ghost_p1 if gamer_id == 1 else mat_ghost_p2
		trim_mat = body_mat
	else:
		body_mat = mat_ring_p1_body if gamer_id == 1 else mat_ring_p2_body
		trim_mat = mat_ring_p1_gold if gamer_id == 1 else mat_ring_p2_plat

	# 1. Main Sculpted Torus Body
	var torus_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.025
	torus.outer_radius = 0.043
	torus.rings = 32
	torus.ring_segments = 20
	torus_inst.mesh = torus
	torus_inst.scale = Vector3(1.0, 1.15, 1.0)
	torus_inst.material_override = body_mat
	root.add_child(torus_inst)

	# 2. Top Beveled Crown Inlay Ring
	var top_rim = MeshInstance3D.new()
	var top_torus = TorusMesh.new()
	top_torus.inner_radius = 0.030
	top_torus.outer_radius = 0.038
	top_torus.rings = 28
	top_torus.ring_segments = 14
	top_rim.mesh = top_torus
	top_rim.position = Vector3(0.0, 0.0085, 0.0)
	top_rim.scale = Vector3(1.0, 0.55, 1.0)
	top_rim.material_override = trim_mat
	root.add_child(top_rim)

	# 3. Inner Metallic Collar Ring (frames the disk inside the ring!)
	var inner_collar = MeshInstance3D.new()
	var collar_torus = TorusMesh.new()
	collar_torus.inner_radius = 0.0235
	collar_torus.outer_radius = 0.0275
	collar_torus.rings = 28
	collar_torus.ring_segments = 12
	inner_collar.mesh = collar_torus
	inner_collar.scale = Vector3(1.0, 1.35, 1.0)
	inner_collar.material_override = trim_mat
	root.add_child(inner_collar)

	# 4. 6 Sculpted Hex Compass Studs (Spheres for P1 Imperial Ruby, Hex Jewels for P2 Sapphire)
	var stud_radius_pos: float = 0.034
	for k in range(6):
		var angle: float = float(k) * (PI / 3.0)
		var stud = MeshInstance3D.new()
		if gamer_id == 1:
			var sph = SphereMesh.new()
			sph.radius = 0.0038
			sph.height = 0.0076
			stud.mesh = sph
		else:
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.0032
			cyl.bottom_radius = 0.0042
			cyl.height = 0.0055
			cyl.radial_segments = 6
			stud.mesh = cyl
		stud.position = Vector3(cos(angle) * stud_radius_pos, 0.010, sin(angle) * stud_radius_pos)
		stud.material_override = trim_mat
		root.add_child(stud)

	return root

# Model 3: 3D Dual-Sided Reversible Yinsh Disk / Marker
# Has a FlipPivot child that rotates 180 degrees around X:
# - rotation.x = 0.0 -> Red (Player 1) face on top
# - rotation.x = PI  -> Blue (Player 2) face on top
func _create_disk_3d_model(initial_owner: int) -> Node3D:
	var root = Node3D.new()
	root.name = "YinshDisk"

	var flip_pivot = Node3D.new()
	flip_pivot.name = "FlipPivot"
	flip_pivot.rotation.x = 0.0 if initial_owner == 1 else PI
	root.add_child(flip_pivot)

	# 1. Central 24K Gold Equatorial Band
	var edge_inst = MeshInstance3D.new()
	var edge_cyl = CylinderMesh.new()
	edge_cyl.top_radius = 0.0225
	edge_cyl.bottom_radius = 0.0225
	edge_cyl.height = 0.0065
	edge_cyl.radial_segments = 28
	edge_inst.mesh = edge_cyl
	edge_inst.material_override = mat_disk_edge_gold
	flip_pivot.add_child(edge_inst)

	# 2. Top Hemisphere: Ruby Red Face (+Y)
	var red_face = MeshInstance3D.new()
	var red_cyl = CylinderMesh.new()
	red_cyl.top_radius = 0.0205
	red_cyl.bottom_radius = 0.0222
	red_cyl.height = 0.0045
	red_cyl.radial_segments = 28
	red_face.mesh = red_cyl
	red_face.position = Vector3(0.0, 0.0042, 0.0)
	red_face.material_override = mat_disk_p1_face
	flip_pivot.add_child(red_face)

	var red_ring = MeshInstance3D.new()
	var r_torus = TorusMesh.new()
	r_torus.inner_radius = 0.012
	r_torus.outer_radius = 0.015
	r_torus.rings = 24
	r_torus.ring_segments = 12
	red_ring.mesh = r_torus
	red_ring.position = Vector3(0.0, 0.0066, 0.0)
	red_ring.scale = Vector3(1.0, 0.45, 1.0)
	red_ring.material_override = mat_ring_p1_gold
	flip_pivot.add_child(red_ring)

	var red_gem = MeshInstance3D.new()
	var r_sph = SphereMesh.new()
	r_sph.radius = 0.0075
	r_sph.height = 0.006
	red_gem.mesh = r_sph
	red_gem.position = Vector3(0.0, 0.0065, 0.0)
	red_gem.material_override = mat_ring_p1_body
	flip_pivot.add_child(red_gem)

	# 3. Bottom Hemisphere: Sapphire Blue Face (-Y)
	var blue_face = MeshInstance3D.new()
	var blue_cyl = CylinderMesh.new()
	blue_cyl.top_radius = 0.0222
	blue_cyl.bottom_radius = 0.0205
	blue_cyl.height = 0.0045
	blue_cyl.radial_segments = 28
	blue_face.mesh = blue_cyl
	blue_face.position = Vector3(0.0, -0.0042, 0.0)
	blue_face.material_override = mat_disk_p2_face
	flip_pivot.add_child(blue_face)

	var blue_ring = MeshInstance3D.new()
	var b_torus = TorusMesh.new()
	b_torus.inner_radius = 0.012
	b_torus.outer_radius = 0.015
	b_torus.rings = 24
	b_torus.ring_segments = 12
	blue_ring.mesh = b_torus
	blue_ring.position = Vector3(0.0, -0.0066, 0.0)
	blue_ring.scale = Vector3(1.0, 0.45, 1.0)
	blue_ring.material_override = mat_ring_p2_plat
	flip_pivot.add_child(blue_ring)

	var blue_gem = MeshInstance3D.new()
	var b_sph = SphereMesh.new()
	b_sph.radius = 0.0075
	b_sph.height = 0.006
	blue_gem.mesh = b_sph
	blue_gem.position = Vector3(0.0, -0.0065, 0.0)
	blue_gem.material_override = mat_ring_p2_body
	flip_pivot.add_child(blue_gem)

	return root

# ============================================================================
# 4. 3D BOARD, LATTICE RAILS, SOCKETS & SIDE TRAYS CONSTRUCTION
# ============================================================================

func _build_board_3d() -> void:
	if is_instance_valid(board_root):
		board_root.queue_free()

	board_root = Node3D.new()
	board_root.name = "YinshBoardRoot"
	add_child(board_root)

	nodes_root = Node3D.new()
	nodes_root.name = "NodesRoot"
	board_root.add_child(nodes_root)

	pieces_root = Node3D.new()
	pieces_root.name = "PiecesRoot"
	board_root.add_child(pieces_root)

	trays_root = Node3D.new()
	trays_root.name = "TraysRoot"
	board_root.add_child(trays_root)

	hover_preview_root = Node3D.new()
	hover_preview_root.name = "HoverPreviewRoot"
	board_root.add_child(hover_preview_root)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	board_root.add_child(fx_root)

	# 1. Luxury Carved Walnut Plinth & Recessed Ebony Arena
	var plinth = MeshInstance3D.new()
	var plinth_box = BoxMesh.new()
	plinth_box.size = Vector3(1.42, 0.028, 1.12)
	plinth.mesh = plinth_box
	plinth.position = Vector3(0.0, 0.014, 0.0)
	plinth.material_override = mat_walnut_plinth
	board_root.add_child(plinth)

	var playfield = MeshInstance3D.new()
	var pf_cyl = CylinderMesh.new()
	pf_cyl.top_radius = 0.535
	pf_cyl.bottom_radius = 0.548
	pf_cyl.height = 0.014
	pf_cyl.radial_segments = 12
	playfield.mesh = pf_cyl
	playfield.position = Vector3(0.0, 0.029, 0.0)
	playfield.material_override = mat_ebony_surface
	board_root.add_child(playfield)

	var outer_gold_ring = MeshInstance3D.new()
	var ogr_torus = TorusMesh.new()
	ogr_torus.inner_radius = 0.530
	ogr_torus.outer_radius = 0.548
	ogr_torus.rings = 36
	ogr_torus.ring_segments = 16
	outer_gold_ring.mesh = ogr_torus
	outer_gold_ring.position = Vector3(0.0, 0.035, 0.0)
	outer_gold_ring.scale = Vector3(1.0, 0.55, 1.0)
	outer_gold_ring.material_override = mat_gold_rail
	board_root.add_child(outer_gold_ring)

	# 2. Build Inlaid 24K Gold Lattice Rails along Directions 1, 2, 3
	for pid in range(NUM_SPOTS):
		var p_from: Vector3 = spot_positions[pid]
		var nbrs: Dictionary = spot_neighbors[pid]
		for d in [1, 2, 3]:
			if nbrs.has(d):
				var nbr_id: int = int(nbrs[d])
				var p_to: Vector3 = spot_positions[nbr_id]
				_add_lattice_rail(p_from, p_to)

	# 3. Build 85 Sculpted Node Sockets & Raycast Areas
	node_areas.clear()
	node_socket_meshes.clear()
	node_legal_halos.clear()
	node_select_halos.clear()
	node_last_halos.clear()

	for pid in range(NUM_SPOTS):
		var pos: Vector3 = spot_positions[pid]
		var n_holder = Node3D.new()
		n_holder.name = "Spot_%d" % pid
		n_holder.position = pos
		nodes_root.add_child(n_holder)

		# Brass outer rim
		var sock_rim = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.0155
		s_cyl.bottom_radius = 0.0170
		s_cyl.height = 0.004
		s_cyl.radial_segments = 20
		sock_rim.mesh = s_cyl
		sock_rim.position = Vector3(0.0, 0.001, 0.0)
		sock_rim.material_override = mat_brass_socket
		n_holder.add_child(sock_rim)
		node_socket_meshes.append(sock_rim)

		# Recessed dark well
		var well = MeshInstance3D.new()
		var w_cyl = CylinderMesh.new()
		w_cyl.top_radius = 0.0115
		w_cyl.bottom_radius = 0.0115
		w_cyl.height = 0.0046
		w_cyl.radial_segments = 18
		well.mesh = w_cyl
		well.position = Vector3(0.0, 0.0012, 0.0)
		well.material_override = mat_socket_well
		n_holder.add_child(well)

		# Legal landing halo (emerald green)
		var legal_halo = MeshInstance3D.new()
		var lh_torus = TorusMesh.new()
		lh_torus.inner_radius = 0.018
		lh_torus.outer_radius = 0.026
		lh_torus.rings = 24
		lh_torus.ring_segments = 12
		legal_halo.mesh = lh_torus
		legal_halo.position = Vector3(0.0, 0.004, 0.0)
		legal_halo.scale = Vector3(1.0, 0.35, 1.0)
		legal_halo.material_override = mat_halo_legal
		legal_halo.visible = false
		n_holder.add_child(legal_halo)
		node_legal_halos.append(legal_halo)

		# Selectable ring halo (royal gold)
		var sel_halo = MeshInstance3D.new()
		var sh_torus = TorusMesh.new()
		sh_torus.inner_radius = 0.041
		sh_torus.outer_radius = 0.049
		sh_torus.rings = 28
		sh_torus.ring_segments = 12
		sel_halo.mesh = sh_torus
		sel_halo.position = Vector3(0.0, 0.0045, 0.0)
		sel_halo.scale = Vector3(1.0, 0.35, 1.0)
		sel_halo.material_override = mat_halo_select
		sel_halo.visible = false
		n_holder.add_child(sel_halo)
		node_select_halos.append(sel_halo)

		# Last move indicator halo
		var last_halo = MeshInstance3D.new()
		var lst_torus = TorusMesh.new()
		lst_torus.inner_radius = 0.032
		lst_torus.outer_radius = 0.038
		lst_torus.rings = 24
		lst_torus.ring_segments = 12
		last_halo.mesh = lst_torus
		last_halo.position = Vector3(0.0, 0.0035, 0.0)
		last_halo.scale = Vector3(1.0, 0.32, 1.0)
		last_halo.material_override = mat_halo_last
		last_halo.visible = false
		n_holder.add_child(last_halo)
		node_last_halos.append(last_halo)

		# Thin wafer Area3D at board surface level (prevents neighboring cylinders blocking angled rays)
		var area = Area3D.new()
		area.name = "SpotArea_%d" % pid
		area.set_meta("piece_id", pid)
		var col = CollisionShape3D.new()
		var cyl_shape = CylinderShape3D.new()
		cyl_shape.radius = 0.038
		cyl_shape.height = 0.010
		col.shape = cyl_shape
		col.position = Vector3(0.0, 0.005, 0.0)
		area.add_child(col)
		n_holder.add_child(area)
		node_areas.append(area)

	# 4. Build Left (P1 Red) & Right (P2 Blue) Side Trays + Remaining Disks Plaque
	_build_side_trays_and_plaques()

func _add_lattice_rail(p1: Vector3, p2: Vector3) -> void:
	var diff: Vector3 = p2 - p1
	var dist: float = diff.length()
	if dist <= 0.001:
		return
	var mid: Vector3 = (p1 + p2) * 0.5
	var angle_y: float = atan2(diff.x, diff.z)
	var rail = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.0042, 0.0022, dist)
	rail.mesh = box
	rail.position = Vector3(mid.x, BOARD_SURFACE_Y + 0.0005, mid.z)
	rail.rotation.y = angle_y
	rail.material_override = mat_gold_rail
	nodes_root.add_child(rail)

func _build_side_trays_and_plaques() -> void:
	p1_reserve_positions.clear()
	p2_reserve_positions.clear()
	p1_trophy_positions.clear()
	p2_trophy_positions.clear()

	# Left Tray (P1 Red) at X = -0.60, Right Tray (P2 Blue) at X = +0.60
	for side in [1, 2]:
		var x_center: float = -0.605 if side == 1 else 0.605
		var tray_base = MeshInstance3D.new()
		var t_box = BoxMesh.new()
		t_box.size = Vector3(0.14, 0.016, 0.88)
		tray_base.mesh = t_box
		tray_base.position = Vector3(x_center, BOARD_SURFACE_Y + 0.002, 0.0)
		tray_base.material_override = mat_ebony_surface
		trays_root.add_child(tray_base)

		var tray_rim = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = Vector3(0.148, 0.012, 0.89)
		tray_rim.mesh = r_box
		tray_rim.position = Vector3(x_center, BOARD_SURFACE_Y - 0.001, 0.0)
		tray_rim.material_override = mat_ring_p1_gold if side == 1 else mat_ring_p2_plat
		trays_root.add_child(tray_rim)

		# 3 Trophy Score Pedestals (Top section of tray: Z = -0.34, -0.23, -0.12)
		for t_idx in range(3):
			var z_pos: float = -0.34 + float(t_idx) * 0.105
			var ped_pos = Vector3(x_center, BOARD_SURFACE_Y + 0.016, z_pos)
			if side == 1:
				p1_trophy_positions.append(ped_pos)
			else:
				p2_trophy_positions.append(ped_pos)

			var ped = MeshInstance3D.new()
			var p_cyl = CylinderMesh.new()
			p_cyl.top_radius = 0.038
			p_cyl.bottom_radius = 0.042
			p_cyl.height = 0.006
			p_cyl.radial_segments = 24
			ped.mesh = p_cyl
			ped.position = Vector3(x_center, BOARD_SURFACE_Y + 0.011, z_pos)
			ped.material_override = mat_ring_p1_gold if side == 1 else mat_ring_p2_plat
			trays_root.add_child(ped)

		# 5 Reserve Ring Pegs (Bottom section of tray: Z = 0.04 .. 0.38)
		for r_idx in range(5):
			var z_pos: float = 0.04 + float(r_idx) * 0.084
			var peg_pos = Vector3(x_center, BOARD_SURFACE_Y + 0.016, z_pos)
			if side == 1:
				p1_reserve_positions.append(peg_pos)
			else:
				p2_reserve_positions.append(peg_pos)

			var peg = MeshInstance3D.new()
			var pg_cyl = CylinderMesh.new()
			pg_cyl.top_radius = 0.012
			pg_cyl.bottom_radius = 0.016
			pg_cyl.height = 0.010
			pg_cyl.radial_segments = 16
			peg.mesh = pg_cyl
			peg.position = Vector3(x_center, BOARD_SURFACE_Y + 0.012, z_pos)
			peg.material_override = mat_brass_socket
			trays_root.add_child(peg)

		# Tray Score Label
		var lbl = Label3D.new()
		lbl.font = _font_hekayat
		lbl.font_size = 38
		lbl.outline_size = 8
		lbl.modulate = Color(1.0, 0.55, 0.55) if side == 1 else Color(0.55, 0.82, 1.0)
		lbl.outline_modulate = Color(0.06, 0.03, 0.02, 0.95)
		lbl.position = Vector3(x_center, BOARD_SURFACE_Y + 0.020, -0.415)
		lbl.rotation.x = -PI * 0.5
		lbl.pixel_size = 0.0011
		lbl.text = "امتیاز: ۰/۳"
		trays_root.add_child(lbl)
		if side == 1:
			lbl_p1_tray_3d = lbl
		else:
			lbl_p2_tray_3d = lbl

	# Top Remaining Disks Plaque (Z = -0.505)
	var top_plaque = MeshInstance3D.new()
	var tp_box = BoxMesh.new()
	tp_box.size = Vector3(0.46, 0.014, 0.062)
	top_plaque.mesh = tp_box
	top_plaque.position = Vector3(0.0, BOARD_SURFACE_Y + 0.006, -0.508)
	top_plaque.material_override = mat_ebony_surface
	trays_root.add_child(top_plaque)

	lbl_disks_3d = Label3D.new()
	lbl_disks_3d.font = _font_hekayat
	lbl_disks_3d.font_size = 42
	lbl_disks_3d.outline_size = 8
	lbl_disks_3d.modulate = Color(1.0, 0.90, 0.42)
	lbl_disks_3d.outline_modulate = Color(0.08, 0.04, 0.02, 0.95)
	lbl_disks_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.016, -0.508)
	lbl_disks_3d.rotation.x = -PI * 0.5
	lbl_disks_3d.pixel_size = 0.0011
	lbl_disks_3d.text = "دیسک‌های مخزن: ۵۱"
	trays_root.add_child(lbl_disks_3d)

	# Bottom Phase Instruction Plaque (Z = +0.508)
	var bot_plaque = MeshInstance3D.new()
	var bp_box = BoxMesh.new()
	bp_box.size = Vector3(0.68, 0.014, 0.064)
	bot_plaque.mesh = bp_box
	bot_plaque.position = Vector3(0.0, BOARD_SURFACE_Y + 0.006, 0.508)
	bot_plaque.material_override = mat_ebony_surface
	trays_root.add_child(bot_plaque)

	lbl_phase_3d = Label3D.new()
	lbl_phase_3d.font = _font_hekayat
	lbl_phase_3d.font_size = 38
	lbl_phase_3d.outline_size = 8
	lbl_phase_3d.modulate = Color(0.96, 0.94, 0.88)
	lbl_phase_3d.outline_modulate = Color(0.08, 0.04, 0.02, 0.95)
	lbl_phase_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.016, 0.508)
	lbl_phase_3d.rotation.x = -PI * 0.5
	lbl_phase_3d.pixel_size = 0.00105
	lbl_phase_3d.text = "فاز ۱: چیدمان ۵ حلقه فرمانده روی صفحه"
	trays_root.add_child(lbl_phase_3d)

# ============================================================================
# 5. GAME LOGIC & VALID MOVE CALCULATION (100% PARITY WITH BACKEND & FLUTTER)
# ============================================================================

func _init_board_state() -> void:
	ring_owners.resize(NUM_SPOTS)
	disk_owners.resize(NUM_SPOTS)
	for i in range(NUM_SPOTS):
		ring_owners[i] = 0
		disk_owners[i] = 0
	is_setup_ring_phase = true
	player1_rings_left = 5
	player2_rings_left = 5
	player1_score = 0
	player2_score = 0
	remaining_disks = 51
	last_selected_piece_id = -1
	possible_moves.clear()
	last_move_from = -1
	last_move_to = -1
	hovered_piece_id = -1
	GameManager.p1_score = 0
	GameManager.p2_score = 0

# Exact port of YinshGameClass.get_direction_idies(direction_id, start_piece_id):
# - Cannot land on or jump over any ring (ring_owners[id] != 0 stops the ray immediately).
# - Every empty spot (disk_owners[id] == 0) before the first disk is a legal landing spot.
# - Once a disk (disk_owners[id] != 0) is encountered, the ring MUST jump over the contiguous
#   chain of disks and land on the VERY FIRST empty spot immediately after that chain, then stop!
func _get_valid_targets_in_direction(dir_id: int, start_piece_id: int) -> Array[int]:
	var valid_targets: Array[int] = []
	var cur_id: int = start_piece_id
	var jumped_disk: bool = false

	while true:
		var nbrs: Dictionary = spot_neighbors[cur_id]
		if not nbrs.has(dir_id):
			break
		var next_id: int = int(nbrs[dir_id])
		# Any ring blocks movement along this direction
		if ring_owners[next_id] != 0:
			break
		if disk_owners[next_id] != 0:
			# Jumping over a contiguous line of disks
			jumped_disk = true
			cur_id = next_id
		else:
			# Empty spot!
			valid_targets.append(next_id)
			if jumped_disk:
				# Must land on the first empty spot after jumping contiguous disks
				break
			cur_id = next_id
	return valid_targets

func _compute_possible_moves_for_ring(piece_id: int) -> Array[int]:
	var moves: Array[int] = []
	if piece_id < 0 or piece_id >= NUM_SPOTS:
		return moves
	for d in ALL_DIRECTIONS:
		var dir_targets: Array[int] = _get_valid_targets_in_direction(d, piece_id)
		for tid in dir_targets:
			if not moves.has(tid):
				moves.append(tid)
	return moves

func _get_disks_between(source_id: int, target_id: int) -> Array[int]:
	for d in ALL_DIRECTIONS:
		var cur_id: int = source_id
		var disks_in_ray: Array[int] = []
		while true:
			var nbrs: Dictionary = spot_neighbors[cur_id]
			if not nbrs.has(d):
				break
			var next_id: int = int(nbrs[d])
			if next_id == target_id:
				return disks_in_ray
			if ring_owners[next_id] != 0:
				break
			if disk_owners[next_id] != 0:
				disks_in_ray.append(next_id)
			cur_id = next_id
	return []

# ============================================================================
# 6. VISUAL PIECE MANAGEMENT & ANIMATIONS
# ============================================================================

func _rebuild_all_pieces_visual() -> void:
	for child in pieces_root.get_children():
		pieces_root.remove_child(child)
		child.queue_free()
	board_ring_nodes.resize(NUM_SPOTS)
	board_disk_nodes.resize(NUM_SPOTS)
	for i in range(NUM_SPOTS):
		board_ring_nodes[i] = null
		board_disk_nodes[i] = null
		if disk_owners[i] != 0:
			var d_node = _create_disk_3d_model(disk_owners[i])
			d_node.position = spot_positions[i] + Vector3(0.0, 0.008, 0.0)
			pieces_root.add_child(d_node)
			board_disk_nodes[i] = d_node
		if ring_owners[i] != 0:
			var r_node = _create_ring_3d_model(ring_owners[i])
			r_node.position = spot_positions[i] + Vector3(0.0, 0.012, 0.0)
			pieces_root.add_child(r_node)
			board_ring_nodes[i] = r_node

	_rebuild_side_tray_rings()
	_update_3d_labels_and_highlights()

func _rebuild_side_tray_rings() -> void:
	for r in p1_reserve_rings:
		if is_instance_valid(r):
			r.queue_free()
	for r in p2_reserve_rings:
		if is_instance_valid(r):
			r.queue_free()
	for r in p1_trophy_rings:
		if is_instance_valid(r):
			r.queue_free()
	for r in p2_trophy_rings:
		if is_instance_valid(r):
			r.queue_free()
	p1_reserve_rings.clear()
	p2_reserve_rings.clear()
	p1_trophy_rings.clear()
	p2_trophy_rings.clear()

	var p1_res_cnt: int = clampi(player1_rings_left, 0, 5)
	for i in range(p1_res_cnt):
		var r1 = _create_ring_3d_model(1)
		r1.position = p1_reserve_positions[i]
		r1.scale = Vector3(0.86, 0.86, 0.86)
		pieces_root.add_child(r1)
		p1_reserve_rings.append(r1)

	var p2_res_cnt: int = clampi(player2_rings_left, 0, 5)
	for i in range(p2_res_cnt):
		var r2 = _create_ring_3d_model(2)
		r2.position = p2_reserve_positions[i]
		r2.scale = Vector3(0.86, 0.86, 0.86)
		pieces_root.add_child(r2)
		p2_reserve_rings.append(r2)

	var p1_sc_cnt: int = clampi(player1_score, 0, 3)
	for i in range(p1_sc_cnt):
		var t1 = _create_ring_3d_model(1)
		t1.position = p1_trophy_positions[i]
		t1.scale = Vector3(0.92, 0.92, 0.92)
		pieces_root.add_child(t1)
		p1_trophy_rings.append(t1)

	var p2_sc_cnt: int = clampi(player2_score, 0, 3)
	for i in range(p2_sc_cnt):
		var t2 = _create_ring_3d_model(2)
		t2.position = p2_trophy_positions[i]
		t2.scale = Vector3(0.92, 0.92, 0.92)
		pieces_root.add_child(t2)
		p2_trophy_rings.append(t2)

func _update_3d_labels_and_highlights() -> void:
	if is_instance_valid(lbl_disks_3d):
		lbl_disks_3d.text = "دیسک‌های مخزن: %s" % _fa_digits(max(0, remaining_disks))
	if is_instance_valid(lbl_p1_tray_3d):
		lbl_p1_tray_3d.text = "امتیاز قرمز: %s/۳" % _fa_digits(player1_score)
	if is_instance_valid(lbl_p2_tray_3d):
		lbl_p2_tray_3d.text = "امتیاز آبی: %s/۳" % _fa_digits(player2_score)

	if is_instance_valid(lbl_phase_3d):
		if is_setup_ring_phase:
			if is_my_turn:
				var my_rem = player1_rings_left if GameManager.my_player_index == 1 else player2_rings_left
				lbl_phase_3d.text = "فاز ۱: یک نقطه خالی برای قرار دادن حلقه انتخاب کنید (%s حلقه باقی‌مانده)" % _fa_digits(my_rem)
				lbl_phase_3d.modulate = Color(0.45, 1.0, 0.62)
			else:
				lbl_phase_3d.text = "فاز ۱: حریف در حال چیدمان حلقه فرمانده است..."
				lbl_phase_3d.modulate = Color(1.0, 0.86, 0.45)
		else:
			if is_my_turn:
				if last_selected_piece_id == -1:
					lbl_phase_3d.text = "نوبت شما: یکی از حلقه‌های خود را برای کاشت دیسک انتخاب کنید"
					lbl_phase_3d.modulate = Color(1.0, 0.88, 0.36)
				else:
					lbl_phase_3d.text = "نوبت شما: یکی از نقاط سبز را برای حرکت و پرش حلقه انتخاب کنید"
					lbl_phase_3d.modulate = Color(0.38, 1.0, 0.58)
			else:
				if last_selected_piece_id == -1:
					lbl_phase_3d.text = "نوبت حریف: در انتظار انتخاب حلقه توسط حریف..."
				else:
					lbl_phase_3d.text = "نوبت حریف: حریف دیسک کاشت و در حال حرکت حلقه است..."
				lbl_phase_3d.modulate = Color(0.78, 0.84, 0.94)

	var my_idx: int = GameManager.my_player_index
	for i in range(NUM_SPOTS):
		if i < node_last_halos.size() and is_instance_valid(node_last_halos[i]):
			node_last_halos[i].visible = (i == last_move_from or i == last_move_to or i == last_selected_piece_id)
		if i < node_select_halos.size() and is_instance_valid(node_select_halos[i]):
			var can_sel: bool = false
			if GameManager.is_game_active and is_my_turn and not is_board_locked:
				if not is_setup_ring_phase and last_selected_piece_id == -1 and ring_owners[i] == my_idx:
					if not _compute_possible_moves_for_ring(i).is_empty():
						can_sel = true
				elif i == last_selected_piece_id:
					can_sel = true
			node_select_halos[i].visible = can_sel

		if i < node_legal_halos.size() and is_instance_valid(node_legal_halos[i]):
			var is_leg: bool = false
			if GameManager.is_game_active and is_my_turn and not is_board_locked:
				if not is_setup_ring_phase and last_selected_piece_id != -1 and possible_moves.has(i):
					is_leg = true
			node_legal_halos[i].visible = is_leg

	_update_hover_preview()

func _update_hover_preview() -> void:
	if not is_instance_valid(hover_preview_root):
		return
	for ch in hover_preview_root.get_children():
		hover_preview_root.remove_child(ch)
		ch.queue_free()

	if not GameManager.is_game_active or not is_my_turn or is_board_locked:
		return
	if hovered_piece_id < 0 or hovered_piece_id >= NUM_SPOTS:
		return

	var my_idx: int = GameManager.my_player_index
	if is_setup_ring_phase:
		if ring_owners[hovered_piece_id] == 0 and disk_owners[hovered_piece_id] == 0:
			var ghost = _create_ring_3d_model(my_idx, true)
			ghost.position = spot_positions[hovered_piece_id] + Vector3(0.0, 0.014, 0.0)
			hover_preview_root.add_child(ghost)
	elif last_selected_piece_id != -1 and possible_moves.has(hovered_piece_id):
		var ghost_dest = _create_ring_3d_model(my_idx, true)
		ghost_dest.position = spot_positions[hovered_piece_id] + Vector3(0.0, 0.014, 0.0)
		hover_preview_root.add_child(ghost_dest)

		var p_from: Vector3 = spot_positions[last_selected_piece_id]
		var p_to: Vector3 = spot_positions[hovered_piece_id]
		var diff: Vector3 = p_to - p_from
		var dist: float = diff.length()
		if dist > 0.001:
			var beam = MeshInstance3D.new()
			var b_box = BoxMesh.new()
			b_box.size = Vector3(0.010, 0.004, dist)
			beam.mesh = b_box
			beam.position = (p_from + p_to) * 0.5 + Vector3(0.0, 0.014, 0.0)
			beam.rotation.y = atan2(diff.x, diff.z)
			beam.material_override = mat_halo_legal
			hover_preview_root.add_child(beam)

# ============================================================================
# 7. RAYCAST SINGLE-SOURCE INPUT (_unhandled_input)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked or not GameManager.is_game_active or not is_my_turn:
		return

	if event is InputEventMouseMotion:
		var hit_hover: int = _raycast_spot(event.position)
		if hit_hover != hovered_piece_id:
			hovered_piece_id = hit_hover
			_update_hover_preview()
		return

	var click_pos: Vector2 = Vector2(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
	else:
		return

	var frame: int = Engine.get_process_frames()
	var now: float = Time.get_ticks_msec() / 1000.0
	if frame == _last_click_frame or (now - last_click_time) < 0.14:
		return

	var hit_id: int = _raycast_spot(click_pos)
	if hit_id < 0 or hit_id >= NUM_SPOTS:
		return

	_last_click_frame = frame
	last_click_time = now
	_handle_spot_clicked(hit_id)

func _raycast_spot(screen_pos: Vector2) -> int:
	var vp = get_viewport()
	if not vp:
		return -1
	var cam = vp.get_camera_3d()
	if not cam:
		return -1
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)

	# 1. Exact Board Surface Plane Intersection (Y = BOARD_SURFACE_Y + 0.008)
	# Guarantees 100% accurate spot picking from any 2D or 3D camera angle without tall cylinder occlusion!
	if abs(dir.y) > 0.0001:
		var t: float = ((BOARD_SURFACE_Y + 0.008) - from.y) / dir.y
		if t > 0.0:
			var local_pt: Vector3 = to_local(from + dir * t)
			var best_id: int = -1
			var best_dist: float = 0.048
			for i in range(NUM_SPOTS):
				var d: float = Vector2(local_pt.x - spot_positions[i].x, local_pt.z - spot_positions[i].z).length()
				if d < best_dist:
					best_dist = d
					best_id = i
			if best_id != -1:
				return best_id

	# 2. Fallback Physics Area3D Raycast
	var space = get_world_3d().direct_space_state
	if not space:
		return -1
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 25.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit = space.intersect_ray(query)
	if hit and hit.has("collider") and is_instance_valid(hit["collider"]):
		var col = hit["collider"]
		if col.has_meta("piece_id"):
			return int(col.get_meta("piece_id"))
	return -1

func _handle_spot_clicked(piece_id: int) -> void:
	var my_idx: int = GameManager.my_player_index

	# Phase 1: Setup 5 Rings
	if is_setup_ring_phase:
		if ring_owners[piece_id] != 0 or disk_owners[piece_id] != 0:
			AudioManager.sfx_invalid()
			show_hint("این نقطه قبلاً اشغال شده است! یک نقطه خالی انتخاب کنید.")
			return
		is_board_locked = true
		hovered_piece_id = -1
		_update_hover_preview()
		AudioManager.sfx_tap()
		send_move(Commands.Submit_Ring, piece_id)
		return

	# Phase 2A: Select one of player's own rings to plant a disk inside
	if last_selected_piece_id == -1:
		if ring_owners[piece_id] != my_idx:
			AudioManager.sfx_invalid()
			show_hint("لطفاً یکی از حلقه‌های خودتان را برای شروع حرکت انتخاب کنید!")
			return
		var legal_for_ring = _compute_possible_moves_for_ring(piece_id)
		if legal_for_ring.is_empty():
			AudioManager.sfx_invalid()
			show_hint("این حلقه هیچ مسیر آزادی برای پرش ندارد! حلقه دیگری انتخاب کنید.")
			return
		AudioManager.sfx_tap()
		# Immediately select ring, place disk, and light up legal destinations (1:1 with Flutter YinshController)
		_execute_place_disk(my_idx, piece_id)
		is_board_locked = false
		send_move(Commands.Select_Peace, piece_id)
		return

	# Phase 2B: Move the selected ring to a legal landing spot along one of the 6 hex directions
	if not possible_moves.has(piece_id):
		AudioManager.sfx_invalid()
		show_hint("فقط نقاط سبز رنگ در امتداد ۶ جهت حلقه مجاز هستند!")
		return

	var src_id: int = last_selected_piece_id
	var rots: Array[int] = _get_disks_between(src_id, piece_id)
	is_board_locked = true
	hovered_piece_id = -1
	_update_hover_preview()
	AudioManager.sfx_tap()
	_execute_ring_move(my_idx, src_id, piece_id, rots)
	send_move(Commands.Move_Ring, {"target_id": piece_id})

# ============================================================================
# 8. SERVER COMMAND HANDLERS & 3D ANIMATIONS
# ============================================================================

func on_turn_data(payload: Dictionary) -> void:
	if payload.has("is_setup_ring_phase"):
		is_setup_ring_phase = bool(payload["is_setup_ring_phase"])

func on_turn_changed(turn: int, active_turn: bool) -> void:
	current_turn = turn
	is_my_turn = active_turn
	is_board_locked = not active_turn
	last_selected_piece_id = -1
	possible_moves.clear()
	hovered_piece_id = -1
	var hud = _get_base_hud()
	if is_instance_valid(hud) and GameManager.is_game_active:
		if is_setup_ring_phase:
			var banner = "نوبت شما (کاشت حلقه)" if active_turn else "نوبت حریف (کاشت حلقه)"
			hud.start_turn_timer(20.0, banner)
	_update_3d_labels_and_highlights()

func on_ring_submitted(payload: Dictionary) -> void:
	var gamer_id: int = int(payload.get("gamer_id", 1))
	var piece_id: int = int(payload.get("piece_id", -1))
	if piece_id < 0 or piece_id >= NUM_SPOTS:
		return

	ring_owners[piece_id] = gamer_id
	last_move_from = -1
	last_move_to = piece_id

	var reserve_arr: Array[Node3D] = p1_reserve_rings if gamer_id == 1 else p2_reserve_rings
	if gamer_id == 1:
		player1_rings_left = max(0, player1_rings_left - 1)
	else:
		player2_rings_left = max(0, player2_rings_left - 1)

	if player1_rings_left == 0 and player2_rings_left == 0:
		is_setup_ring_phase = false

	# Animate ring flying from side reserve tray to the board spot
	var start_pos: Vector3 = spot_positions[piece_id] + Vector3(0.0, 0.18, 0.0)
	if not reserve_arr.is_empty():
		var popped = reserve_arr.pop_back()
		if is_instance_valid(popped):
			start_pos = popped.position
			popped.queue_free()

	if is_instance_valid(board_ring_nodes[piece_id]):
		board_ring_nodes[piece_id].queue_free()

	var ring_node = _create_ring_3d_model(gamer_id)
	ring_node.position = start_pos
	ring_node.scale = Vector3(0.88, 0.88, 0.88)
	pieces_root.add_child(ring_node)
	board_ring_nodes[piece_id] = ring_node

	var dest_pos: Vector3 = spot_positions[piece_id] + Vector3(0.0, 0.012, 0.0)
	var mid_pos: Vector3 = (start_pos + dest_pos) * 0.5 + Vector3(0.0, 0.14, 0.0)
	var tw = ring_node.create_tween()
	tw.tween_property(ring_node, "position", mid_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring_node, "scale", Vector3(1.08, 1.08, 1.08), 0.16)
	tw.tween_property(ring_node, "position", dest_pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring_node, "scale", Vector3.ONE, 0.16)
	tw.tween_callback(func():
		AudioManager.sfx_add_piece()
		_spawn_ring_pulse_vfx(spot_positions[piece_id], gamer_id)
	)

	_update_3d_labels_and_highlights()

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id: int = int(extra.get("gamer_id", user_id))
	var piece_id: int = int(extra.get("piece_id", target_peace))
	if piece_id < 0 or piece_id >= NUM_SPOTS:
		return

	_execute_place_disk(gamer_id, piece_id)
	if gamer_id == GameManager.my_player_index and is_my_turn:
		is_board_locked = false
	_update_3d_labels_and_highlights()

func _execute_place_disk(gamer_id: int, piece_id: int) -> void:
	if piece_id < 0 or piece_id >= NUM_SPOTS:
		return
	var already_placed: bool = (disk_owners[piece_id] == gamer_id and is_instance_valid(board_disk_nodes[piece_id]))
	disk_owners[piece_id] = gamer_id
	last_selected_piece_id = piece_id
	possible_moves = _compute_possible_moves_for_ring(piece_id)

	if already_placed:
		_update_3d_labels_and_highlights()
		return

	remaining_disks = max(0, remaining_disks - 1)
	if is_instance_valid(board_disk_nodes[piece_id]):
		board_disk_nodes[piece_id].queue_free()

	var disk_node = _create_disk_3d_model(gamer_id)
	var dest_pos: Vector3 = spot_positions[piece_id] + Vector3(0.0, 0.008, 0.0)
	disk_node.position = dest_pos + Vector3(0.0, 0.09, 0.0)
	disk_node.scale = Vector3(0.4, 0.4, 0.4)
	pieces_root.add_child(disk_node)
	board_disk_nodes[piece_id] = disk_node

	var tw = disk_node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk_node, "position", dest_pos, 0.22)
	tw.parallel().tween_property(disk_node, "scale", Vector3.ONE, 0.22)
	tw.tween_callback(func():
		AudioManager.sfx_add_piece()
	)
	_update_3d_labels_and_highlights()

func on_ring_moved(payload: Dictionary) -> void:
	var gamer_id: int = int(payload.get("gamer_id", 1))
	var source_id: int = int(payload.get("source_id", last_selected_piece_id))
	var target_id: int = int(payload.get("target_id", -1))
	var rotations_raw = payload.get("rotations_list", [])
	_execute_ring_move(gamer_id, source_id, target_id, rotations_raw)

func _execute_ring_move(gamer_id: int, source_id: int, target_id: int, rotations_raw: Variant) -> void:
	if source_id < 0 or source_id >= NUM_SPOTS or target_id < 0 or target_id >= NUM_SPOTS:
		return

	# Idempotency check if already moved optimistically on local player click
	if ring_owners[target_id] == gamer_id and ring_owners[source_id] == 0 and last_move_from == source_id and last_move_to == target_id:
		last_selected_piece_id = -1
		possible_moves.clear()
		_update_3d_labels_and_highlights()
		return

	ring_owners[source_id] = 0
	ring_owners[target_id] = gamer_id
	last_selected_piece_id = -1
	possible_moves.clear()
	last_move_from = source_id
	last_move_to = target_id
	hovered_piece_id = -1

	# 1. Parabolic 3D Glide of the Commander Ring from source_id to target_id
	var ring_node: Node3D = board_ring_nodes[source_id]
	board_ring_nodes[source_id] = null
	if not is_instance_valid(ring_node):
		ring_node = _create_ring_3d_model(gamer_id)
		pieces_root.add_child(ring_node)
	board_ring_nodes[target_id] = ring_node

	var start_pos: Vector3 = spot_positions[source_id] + Vector3(0.0, 0.012, 0.0)
	var end_pos: Vector3 = spot_positions[target_id] + Vector3(0.0, 0.012, 0.0)
	var arc_mid: Vector3 = (start_pos + end_pos) * 0.5 + Vector3(0.0, 0.11, 0.0)

	AudioManager.sfx_move_piece()
	var tw = ring_node.create_tween()
	tw.tween_property(ring_node, "position", arc_mid, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_node, "position", end_pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		AudioManager.sfx_add_piece()
		_spawn_ring_pulse_vfx(spot_positions[target_id], gamer_id)
	)

	# 2. Staggered 180-Degree Mid-Air Somersault Flip for every jumped disk in rotations_list!
	if typeof(rotations_raw) == TYPE_ARRAY:
		var delay_idx: int = 0
		for pid_var in rotations_raw:
			var f_id: int = int(pid_var)
			if f_id >= 0 and f_id < NUM_SPOTS and disk_owners[f_id] != 0:
				var new_owner: int = 2 if disk_owners[f_id] == 1 else 1
				disk_owners[f_id] = new_owner
				_animate_disk_flip(f_id, new_owner, float(delay_idx) * 0.055)
				delay_idx += 1

	_update_3d_labels_and_highlights()

func _animate_disk_flip(piece_id: int, new_owner: int, delay_sec: float) -> void:
	var disk_node: Node3D = board_disk_nodes[piece_id]
	if not is_instance_valid(disk_node):
		disk_node = _create_disk_3d_model(new_owner)
		disk_node.position = spot_positions[piece_id] + Vector3(0.0, 0.008, 0.0)
		pieces_root.add_child(disk_node)
		board_disk_nodes[piece_id] = disk_node
		return

	var flip_pivot: Node3D = disk_node.get_node_or_null("FlipPivot")
	var base_pos: Vector3 = spot_positions[piece_id] + Vector3(0.0, 0.008, 0.0)
	var target_rot_x: float = 0.0 if new_owner == 1 else PI

	var tw = disk_node.create_tween()
	if delay_sec > 0.0:
		tw.tween_interval(delay_sec)
	tw.tween_callback(func():
		AudioManager.sfx_tap()
		_spawn_ring_pulse_vfx(spot_positions[piece_id], new_owner)
	)
	tw.tween_property(disk_node, "position:y", base_pos.y + 0.068, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(flip_pivot):
		tw.parallel().tween_property(flip_pivot, "rotation:x", target_rot_x, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk_node, "position:y", base_pos.y, 0.13).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func on_remove_peace(payload: Dictionary) -> void:
	# Triggered when a player selects a ring (Step 2A) but times out before moving it (Step 2B)
	var piece_id: int = int(payload.get("piece_id", -1))
	last_selected_piece_id = -1
	possible_moves.clear()
	if piece_id >= 0 and piece_id < NUM_SPOTS:
		disk_owners[piece_id] = 0
		remaining_disks = min(51, remaining_disks + 1)
		if is_instance_valid(board_disk_nodes[piece_id]):
			var d_node = board_disk_nodes[piece_id]
			board_disk_nodes[piece_id] = null
			var tw = d_node.create_tween()
			tw.tween_property(d_node, "scale", Vector3(0.05, 0.05, 0.05), 0.18)
			tw.tween_callback(d_node.queue_free)
	_update_3d_labels_and_highlights()

func on_win_happened(payload: Dictionary) -> void:
	# Triggered when 5+ contiguous same-color disks are cleared and a ring is scored!
	var win_arr = payload.get("win_data", [])
	var rem_rings = payload.get("removed_rings", [])

	AudioManager.play_sound("win")

	var fallback_gamer_id: int = 1
	if typeof(win_arr) == TYPE_ARRAY:
		for w_entry in win_arr:
			if typeof(w_entry) == TYPE_DICTIONARY:
				var gid: int = int(w_entry.get("gamer_id", 1))
				fallback_gamer_id = gid
				var d_list = w_entry.get("data", [])
				if gid == 1:
					player1_score = min(3, player1_score + 1)
				else:
					player2_score = min(3, player2_score + 1)

				if typeof(d_list) == TYPE_ARRAY:
					_spawn_five_in_row_beam_vfx(d_list, gid)
					for pid_v in d_list:
						var pid: int = int(pid_v)
						if pid >= 0 and pid < NUM_SPOTS:
							disk_owners[pid] = 0
							remaining_disks = min(51, remaining_disks + 1)
							if is_instance_valid(board_disk_nodes[pid]):
								var dn = board_disk_nodes[pid]
								board_disk_nodes[pid] = null
								var tw_d = dn.create_tween()
								tw_d.tween_property(dn, "position:y", dn.position.y + 0.09, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
								tw_d.parallel().tween_property(dn, "scale", Vector3(0.05, 0.05, 0.05), 0.24)
								tw_d.tween_callback(dn.queue_free)

	if typeof(rem_rings) == TYPE_ARRAY:
		for r_id_v in rem_rings:
			if r_id_v == null:
				continue
			var r_id: int = int(r_id_v)
			if r_id >= 0 and r_id < NUM_SPOTS:
				var r_owner: int = ring_owners[r_id] if ring_owners[r_id] != 0 else fallback_gamer_id
				ring_owners[r_id] = 0
				var r_node = board_ring_nodes[r_id]
				board_ring_nodes[r_id] = null
				if is_instance_valid(r_node):
					var trophy_arr = p1_trophy_rings if r_owner == 1 else p2_trophy_rings
					var trophy_pos_arr = p1_trophy_positions if r_owner == 1 else p2_trophy_positions
					var slot_idx: int = clampi(trophy_arr.size(), 0, 2)
					var dest_trophy: Vector3 = trophy_pos_arr[slot_idx]
					trophy_arr.append(r_node)
					var mid_trophy: Vector3 = (r_node.position + dest_trophy) * 0.5 + Vector3(0.0, 0.18, 0.0)
					var tw_r = r_node.create_tween()
					tw_r.tween_property(r_node, "position", mid_trophy, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
					tw_r.tween_property(r_node, "position", dest_trophy, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tw_r.parallel().tween_property(r_node, "scale", Vector3(0.92, 0.92, 0.92), 0.22)

	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	_sync_hud_scores()
	_update_3d_labels_and_highlights()

func _spawn_ring_pulse_vfx(pos: Vector3, gamer_id: int) -> void:
	if not is_instance_valid(fx_root):
		return
	var wave = MeshInstance3D.new()
	var w_torus = TorusMesh.new()
	w_torus.inner_radius = 0.020
	w_torus.outer_radius = 0.028
	w_torus.rings = 24
	w_torus.ring_segments = 12
	wave.mesh = w_torus
	wave.position = pos + Vector3(0.0, 0.005, 0.0)
	wave.scale = Vector3(0.6, 0.4, 0.6)
	wave.material_override = mat_ring_p1_gold if gamer_id == 1 else mat_ring_p2_plat
	fx_root.add_child(wave)

	var tw = wave.create_tween()
	tw.tween_property(wave, "scale", Vector3(1.85, 0.1, 1.85), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(wave.queue_free)

func _spawn_five_in_row_beam_vfx(disk_ids: Array, gamer_id: int) -> void:
	if disk_ids.size() < 2 or not is_instance_valid(fx_root):
		return
	var min_id: int = int(disk_ids[0])
	var max_id: int = int(disk_ids[0])
	for v in disk_ids:
		var id_i: int = int(v)
		if id_i < min_id:
			min_id = id_i
		if id_i > max_id:
			max_id = id_i
	if min_id < 0 or max_id >= NUM_SPOTS:
		return
	var p1: Vector3 = spot_positions[min_id]
	var p2: Vector3 = spot_positions[max_id]
	var diff: Vector3 = p2 - p1
	var dist: float = diff.length()
	if dist <= 0.01:
		return

	var beam = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.026, 0.016, dist + 0.05)
	beam.mesh = b_box
	beam.position = (p1 + p2) * 0.5 + Vector3(0.0, 0.025, 0.0)
	beam.rotation.y = atan2(diff.x, diff.z)
	beam.material_override = mat_Win_beam
	fx_root.add_child(beam)

	var tw = beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(1.5, 1.5, 1.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(beam, "scale", Vector3(0.05, 0.05, 1.0), 0.22)
	tw.tween_callback(beam.queue_free)

	var hud = _get_base_hud()
	if is_instance_valid(hud) and hud.has_method("show_toast_hint"):
		if gamer_id == GameManager.my_player_index:
			hud.show_toast_hint("🌟 آفرین! ردیف ۵تایی ساختید و ۱ حلقه امتیاز گرفتید!")
		else:
			hud.show_toast_hint("⚠️ حریف ردیف ۵تایی ساخت و ۱ امتیاز کسب کرد!")

# ============================================================================
# 9. BOARD SYNC, RECONNECT & HUD HELPERS
# ============================================================================

func setup_board(payload: Dictionary) -> void:
	_init_board_state()
	if payload.has("board") and typeof(payload["board"]) == TYPE_ARRAY:
		sync_board_state(payload["board"])
	else:
		_rebuild_all_pieces_visual()
	_sync_hud_scores()

func reset_board() -> void:
	_init_board_state()
	_rebuild_all_pieces_visual()
	_sync_hud_scores()

func on_start_game() -> void:
	_update_3d_labels_and_highlights()
	_sync_hud_scores()

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var arr: Array = board_data
	if arr.size() < NUM_SPOTS:
		return
	var p1_rings_on_board: int = 0
	var p2_rings_on_board: int = 0
	var disks_on_board: int = 0
	for i in range(NUM_SPOTS):
		var item = arr[i]
		if typeof(item) == TYPE_DICTIONARY:
			var r_u = item.get("ring_user", null)
			var d_u = item.get("disk_user", null)
			ring_owners[i] = int(r_u) if r_u != null else 0
			disk_owners[i] = int(d_u) if d_u != null else 0
			if ring_owners[i] == 1:
				p1_rings_on_board += 1
			elif ring_owners[i] == 2:
				p2_rings_on_board += 1
			if disk_owners[i] != 0:
				disks_on_board += 1
	remaining_disks = clampi(51 - disks_on_board, 0, 51)
	if not is_setup_ring_phase:
		player1_rings_left = 0
		player2_rings_left = 0
	else:
		player1_rings_left = clampi(5 - p1_rings_on_board, 0, 5)
		player2_rings_left = clampi(5 - p2_rings_on_board, 0, 5)
	_rebuild_all_pieces_visual()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		is_setup_ring_phase = bool(g_data.get("is_setup_ring_phase", false))
		player1_score = int(g_data.get("player1_score", 0))
		player2_score = int(g_data.get("player2_score", 0))
		player1_rings_left = int(g_data.get("player1_rings", 0))
		player2_rings_left = int(g_data.get("player2_rings", 0))
		remaining_disks = int(g_data.get("disk_count", 51))
		last_selected_piece_id = int(g_data.get("last_selected_piece_id", -1))
		GameManager.p1_score = player1_score
		GameManager.p2_score = player2_score
		if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
			var arr: Array = g_data["board"]
			if arr.size() >= NUM_SPOTS:
				for i in range(NUM_SPOTS):
					var item = arr[i]
					if typeof(item) == TYPE_DICTIONARY:
						var r_u = item.get("ring_user", null)
						var d_u = item.get("disk_user", null)
						ring_owners[i] = int(r_u) if r_u != null else 0
						disk_owners[i] = int(d_u) if d_u != null else 0
		if last_selected_piece_id >= 0 and last_selected_piece_id < NUM_SPOTS:
			possible_moves = _compute_possible_moves_for_ring(last_selected_piece_id)
		else:
			possible_moves.clear()
		if g_data.has("current_turn"):
			current_turn = int(g_data["current_turn"])
			is_my_turn = (current_turn == GameManager.my_player_index)
			is_board_locked = not is_my_turn
	_rebuild_all_pieces_visual()
	_sync_hud_scores()

func _sync_hud_scores() -> void:
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var hud = _get_base_hud()
	if is_instance_valid(hud) and hud.has_method("update_scores"):
		hud.update_scores(player1_score, player2_score)

func _get_base_hud() -> Node:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return null
	return tree.current_scene.get_node_or_null("BaseGameHUD")
