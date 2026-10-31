class_name Pentago3D
extends "res://scripts/games/base_game_board.gd"

# Pentago 3D Board (پنتاگو — Cafe Fekr Royal Tournament Edition)
# Exact 1:1 port of Flutter PentagoController + Python Backend PentagoGameClass & PentagoGameSession.
# Features:
# - 3 Distinct Custom Sculpted 3D Models:
#   1. Player 1 (Red) 3D Imperial Ruby Orb: Clearcoat Ruby Sphere + 24K Gold Equatorial Band + 4 Compass Studs + Crown Finial
#   2. Player 2 (Blue) 3D Royal Sapphire Orb: Clearcoat Sapphire Sphere + Brushed Platinum Band + 4 Hex Studs + Diamond Finial
#   3. Sculpted 3D Mechanical Rotation Paddle & Turntable Gear: 4 Independent 3x3 Rotating Quadrants on Brass Gears +
#      8 Interactive 3D Curved-Arrow Rotation Levers (1..8) with Live Quadrant Spin Preview!
# - Left & Right Mahogany Reserve Marble Trays (18 Ruby Orbs & 18 Sapphire Orbs)
# - Step-by-Step Gamer-Friendly Phase Banner (Step 1: Place Marble -> Step 2: Rotate Any Quadrant 90°)
# - Spectacular 5-in-a-Row Victory Laser Beam, Vertical Beacons & Shockwave VFX

const NUM_CELLS: int = 36
const NUM_QUADRANTS: int = 4
const CELLS_PER_QUADRANT: int = 9

# Board & Quadrant Geometry Constants (fits cleanly inside CafeTable play zone)
const BOARD_SURFACE_Y: float = 0.038
const QUAD_OFFSET: float = 0.195
const CELL_SPACING: float = 0.112
const QUAD_SIZE: float = 0.368

const QUAD_CENTERS: Array[Vector3] = [
	Vector3(-QUAD_OFFSET, BOARD_SURFACE_Y, -QUAD_OFFSET), # Quadrant 0: Top-Left (0..8)
	Vector3(QUAD_OFFSET, BOARD_SURFACE_Y, -QUAD_OFFSET),  # Quadrant 1: Top-Right (9..17)
	Vector3(-QUAD_OFFSET, BOARD_SURFACE_Y, QUAD_OFFSET),  # Quadrant 2: Bottom-Left (18..26)
	Vector3(QUAD_OFFSET, BOARD_SURFACE_Y, QUAD_OFFSET)    # Quadrant 3: Bottom-Right (27..35)
]

# Exact 32 5-in-a-row win conditions from Entities/Games/Pentago/__init__.py
const WIN_CONDITIONS: Array = [
	[0, 1, 2, 9, 10], [1, 2, 9, 10, 11], [3, 4, 5, 12, 13], [4, 5, 12, 13, 14],
	[6, 7, 8, 15, 16], [7, 8, 15, 16, 17], [18, 19, 20, 27, 28], [19, 20, 27, 28, 29],
	[21, 22, 23, 30, 31], [22, 23, 30, 31, 32], [24, 25, 26, 33, 34], [25, 26, 33, 34, 35],
	[0, 3, 6, 18, 21], [3, 6, 18, 21, 24], [1, 4, 7, 19, 22], [4, 7, 19, 22, 25],
	[2, 5, 8, 20, 23], [5, 8, 20, 23, 26], [9, 12, 15, 27, 30], [12, 15, 27, 30, 33],
	[10, 13, 16, 28, 31], [13, 16, 28, 31, 34], [11, 14, 17, 29, 32], [14, 17, 29, 32, 35],
	[21, 19, 8, 12, 10], [25, 23, 27, 16, 14], [1, 5, 15, 28, 32], [3, 7, 20, 30, 34],
	[24, 22, 20, 15, 13], [11, 13, 15, 20, 22], [0, 4, 8, 27, 31], [35, 31, 27, 8, 4]
]

# --- Authoritative Game State ---
var board_state: Array[int] = [] # 0 = empty, 1 = P1 (Red), 2 = P2 (Blue) across 36 cells
var player1_pawns: int = 18
var player2_pawns: int = 18
var is_selection_played: bool = false
var is_rotation_played: bool = false
var is_animating_rotation: bool = false
var last_placed_cell_id: int = -1
var last_rotated_quadrant: int = -1
var hovered_cell_id: int = -1
var hovered_rotation_id: int = -1
var _pulse_time: float = 0.0
var _win_vfx_shown: bool = false
var _win_vfx_started_msec: int = 0

# --- 3D Scene Hierarchy ---
var board_root: Node3D = null
var quadrants_root: Node3D = null
var controls_root: Node3D = null
var trays_root: Node3D = null
var fx_root: Node3D = null
var hover_preview_root: Node3D = null

var quadrant_pivots: Array[Node3D] = [] # 4 rotating quadrant pivot nodes (0..3)
var quadrant_rim_meshes: Array[MeshInstance3D] = [] # 4 quadrant outer frames for highlight
var cell_local_positions: Array[Vector3] = [] # 36 local positions inside their quadrant pivot
var cell_areas: Array[Area3D] = [] # 36 cell raycast areas
var cell_legal_halos: Array[MeshInstance3D] = [] # 36 legal/hover halos
var cell_last_halos: Array[MeshInstance3D] = [] # 36 last-move halos
var board_marble_nodes: Array[Node3D] = [] # 36 active marble 3D nodes (children of quadrant_pivots)

# 8 Sculpted 3D Rotation Buttons (index 0..7 -> rotation_id 1..8)
var rotation_btn_nodes: Array[Node3D] = []
var rotation_btn_halos: Array[MeshInstance3D] = []
var rotation_btn_plate_groups: Array = [] # Array of Array[MeshInstance3D] for pill plates
var rotation_btn_dials: Array[Node3D] = [] # 8 rotating 3D curved-arrow dial pivots
var rotation_btn_glow_rings: Array[MeshInstance3D] = [] # 8 oval glow rings around buttons
var rotation_btn_areas: Array[Area3D] = []

# Side Reserve Marble Trays
var p1_reserve_positions: Array[Vector3] = []
var p2_reserve_positions: Array[Vector3] = []
var p1_reserve_marbles: Array[Node3D] = []
var p2_reserve_marbles: Array[Node3D] = []

# 3D Typography Labels
var lbl_title_3d: Label3D = null
var lbl_phase_3d: Label3D = null
var lbl_p1_tray_3d: Label3D = null
var lbl_p2_tray_3d: Label3D = null

# Hover Preview Nodes
var ghost_marble_p1: Node3D = null
var ghost_marble_p2: Node3D = null
var quadrant_spin_preview: Node3D = null
var spin_preview_arrows: Array[MeshInstance3D] = []

# --- Luxury Procedural Materials ---
var mat_walnut_chassis: StandardMaterial3D
var mat_mahogany_trim: StandardMaterial3D
var mat_obsidian_bed: StandardMaterial3D
var mat_quad_slate: StandardMaterial3D
var mat_gold_rail: StandardMaterial3D
var mat_gold_highlight: StandardMaterial3D
var mat_brass_gear: StandardMaterial3D
var mat_socket_well: StandardMaterial3D
var mat_velvet_tray: StandardMaterial3D

var mat_marble_p1_body: StandardMaterial3D
var mat_marble_p1_gold: StandardMaterial3D
var mat_marble_p2_body: StandardMaterial3D
var mat_marble_p2_plat: StandardMaterial3D

var mat_rot_btn_idle: StandardMaterial3D
var mat_rot_btn_active: StandardMaterial3D
var mat_rot_btn_hover: StandardMaterial3D
var mat_rot_arrow_gold: StandardMaterial3D
var mat_rot_arrow_emerald: StandardMaterial3D

var mat_halo_legal: StandardMaterial3D
var mat_halo_last: StandardMaterial3D
var mat_ghost_p1: StandardMaterial3D
var mat_ghost_p2: StandardMaterial3D

var mat_win_beam_core: StandardMaterial3D
var mat_win_beam_sheath: StandardMaterial3D
var mat_win_beacon: StandardMaterial3D

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
	game_type = GameTypes.PENTAGO

func _enter_tree() -> void:
	super._enter_tree()
	_connect_pentago_signals()

func _ready() -> void:
	game_type = GameTypes.PENTAGO
	add_to_group("board")
	_connect_pentago_signals()
	_init_materials()
	_build_board_3d()
	_init_board_state()
	_rebuild_all_pieces_visual()
	super._ready()

func _exit_tree() -> void:
	_disconnect_pentago_signals()
	super._exit_tree()

func _connect_pentago_signals() -> void:
	if is_instance_valid(NetworkManager.socket) and not NetworkManager.socket.event_received.is_connected(_on_pentago_socket_event):
		NetworkManager.socket.event_received.connect(_on_pentago_socket_event)

func _disconnect_pentago_signals() -> void:
	if is_instance_valid(NetworkManager.socket) and NetworkManager.socket.event_received.is_connected(_on_pentago_socket_event):
		NetworkManager.socket.event_received.disconnect(_on_pentago_socket_event)

func _on_pentago_socket_event(_ns: String, event_name: String, data: Variant) -> void:
	if event_name != "command" or typeof(data) != TYPE_DICTIONARY:
		return
	var cmd_id: String = str(data.get("id", ""))
	var payload: Variant = data.get("data", null)
	if cmd_id == Commands.Peace_Rotated and typeof(payload) == TYPE_DICTIONARY:
		on_peace_rotated(payload)

func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse_fast: float = 1.0 + 0.08 * sin(_pulse_time * 6.0)
	var pulse_rot: float = 1.0 + 0.07 * sin(_pulse_time * 5.2)

	for i in range(NUM_CELLS):
		if i < cell_legal_halos.size() and is_instance_valid(cell_legal_halos[i]) and cell_legal_halos[i].visible:
			cell_legal_halos[i].scale = Vector3(pulse_fast, 1.0, pulse_fast)

	var rot_phase_active: bool = GameManager.is_game_active and is_my_turn and is_selection_played and not is_rotation_played and not is_animating_rotation
	for r_idx in range(8):
		if r_idx < rotation_btn_nodes.size() and is_instance_valid(rotation_btn_nodes[r_idx]):
			var btn_node = rotation_btn_nodes[r_idx]
			var rot_id: int = r_idx + 1
			var is_ccw: bool = (rot_id % 2 == 1)
			var dir_sign: float = 1.0 if is_ccw else -1.0
			if rot_phase_active:
				var is_hov: bool = (hovered_rotation_id == rot_id)
				var s_val: float = 1.14 if is_hov else pulse_rot
				btn_node.scale = Vector3(s_val, 1.0, s_val)
				btn_node.position.y = BOARD_SURFACE_Y + (0.018 if is_hov else 0.011 + 0.003 * sin(_pulse_time * 5.2))
				if r_idx < rotation_btn_dials.size() and is_instance_valid(rotation_btn_dials[r_idx]):
					if is_hov:
						rotation_btn_dials[r_idx].rotation.y += delta * 2.8 * dir_sign
					else:
						rotation_btn_dials[r_idx].rotation.y = dir_sign * 0.36 * sin(_pulse_time * 4.8)
			else:
				btn_node.scale = Vector3.ONE
				btn_node.position.y = BOARD_SURFACE_Y + 0.004
				if r_idx < rotation_btn_dials.size() and is_instance_valid(rotation_btn_dials[r_idx]):
					rotation_btn_dials[r_idx].rotation.y = 0.0

	if is_instance_valid(quadrant_spin_preview) and quadrant_spin_preview.visible:
		var dir_sign: float = 1.0 if (hovered_rotation_id % 2 == 1) else -1.0
		quadrant_spin_preview.rotation.y += delta * 1.65 * dir_sign

# ============================================================================
# 1. LUXURY PROCEDURAL MATERIALS
# ============================================================================

func _init_materials() -> void:
	mat_walnut_chassis = StandardMaterial3D.new()
	mat_walnut_chassis.albedo_color = Color(0.22, 0.11, 0.06)
	mat_walnut_chassis.metallic = 0.08
	mat_walnut_chassis.roughness = 0.36
	mat_walnut_chassis.clearcoat_enabled = true
	mat_walnut_chassis.clearcoat = 0.60
	mat_walnut_chassis.clearcoat_roughness = 0.22

	mat_mahogany_trim = StandardMaterial3D.new()
	mat_mahogany_trim.albedo_color = Color(0.30, 0.14, 0.08)
	mat_mahogany_trim.metallic = 0.12
	mat_mahogany_trim.roughness = 0.30
	mat_mahogany_trim.clearcoat_enabled = true
	mat_mahogany_trim.clearcoat = 0.65

	mat_obsidian_bed = StandardMaterial3D.new()
	mat_obsidian_bed.albedo_color = Color(0.06, 0.06, 0.08)
	mat_obsidian_bed.metallic = 0.22
	mat_obsidian_bed.roughness = 0.42

	mat_quad_slate = StandardMaterial3D.new()
	mat_quad_slate.albedo_color = Color(0.13, 0.12, 0.16)
	mat_quad_slate.metallic = 0.18
	mat_quad_slate.roughness = 0.32
	mat_quad_slate.clearcoat_enabled = true
	mat_quad_slate.clearcoat = 0.50
	mat_quad_slate.clearcoat_roughness = 0.18

	mat_gold_rail = StandardMaterial3D.new()
	mat_gold_rail.albedo_color = Color(0.95, 0.79, 0.30)
	mat_gold_rail.metallic = 0.90
	mat_gold_rail.roughness = 0.20

	mat_gold_highlight = StandardMaterial3D.new()
	mat_gold_highlight.albedo_color = Color(1.0, 0.88, 0.36)
	mat_gold_highlight.metallic = 0.92
	mat_gold_highlight.roughness = 0.14
	mat_gold_highlight.emission_enabled = true
	mat_gold_highlight.emission = Color(1.0, 0.80, 0.22)
	mat_gold_highlight.emission_energy_multiplier = 1.45

	mat_brass_gear = StandardMaterial3D.new()
	mat_brass_gear.albedo_color = Color(0.82, 0.66, 0.28)
	mat_brass_gear.metallic = 0.86
	mat_brass_gear.roughness = 0.26

	mat_socket_well = StandardMaterial3D.new()
	mat_socket_well.albedo_color = Color(0.04, 0.04, 0.06)
	mat_socket_well.metallic = 0.15
	mat_socket_well.roughness = 0.55

	mat_velvet_tray = StandardMaterial3D.new()
	mat_velvet_tray.albedo_color = Color(0.05, 0.08, 0.15)
	mat_velvet_tray.metallic = 0.05
	mat_velvet_tray.roughness = 0.82

	# Model 1: Player 1 (Red) Imperial Ruby Orb
	mat_marble_p1_body = StandardMaterial3D.new()
	mat_marble_p1_body.albedo_color = Color(0.90, 0.12, 0.18)
	mat_marble_p1_body.metallic = 0.26
	mat_marble_p1_body.roughness = 0.12
	mat_marble_p1_body.clearcoat_enabled = true
	mat_marble_p1_body.clearcoat = 0.98
	mat_marble_p1_body.clearcoat_roughness = 0.05
	mat_marble_p1_body.emission_enabled = true
	mat_marble_p1_body.emission = Color(0.58, 0.05, 0.09)
	mat_marble_p1_body.emission_energy_multiplier = 0.38

	mat_marble_p1_gold = StandardMaterial3D.new()
	mat_marble_p1_gold.albedo_color = Color(1.0, 0.84, 0.32)
	mat_marble_p1_gold.metallic = 0.95
	mat_marble_p1_gold.roughness = 0.14

	# Model 2: Player 2 (Blue) Royal Sapphire Orb
	mat_marble_p2_body = StandardMaterial3D.new()
	mat_marble_p2_body.albedo_color = Color(0.10, 0.46, 0.94)
	mat_marble_p2_body.metallic = 0.28
	mat_marble_p2_body.roughness = 0.12
	mat_marble_p2_body.clearcoat_enabled = true
	mat_marble_p2_body.clearcoat = 0.98
	mat_marble_p2_body.clearcoat_roughness = 0.05
	mat_marble_p2_body.emission_enabled = true
	mat_marble_p2_body.emission = Color(0.05, 0.24, 0.62)
	mat_marble_p2_body.emission_energy_multiplier = 0.42

	mat_marble_p2_plat = StandardMaterial3D.new()
	mat_marble_p2_plat.albedo_color = Color(0.88, 0.93, 1.0)
	mat_marble_p2_plat.metallic = 0.94
	mat_marble_p2_plat.roughness = 0.14

	# Model 3: Sculpted 3D Rotation Paddles
	mat_rot_btn_idle = StandardMaterial3D.new()
	mat_rot_btn_idle.albedo_color = Color(0.16, 0.13, 0.11)
	mat_rot_btn_idle.metallic = 0.25
	mat_rot_btn_idle.roughness = 0.42

	mat_rot_btn_active = StandardMaterial3D.new()
	mat_rot_btn_active.albedo_color = Color(0.12, 0.38, 0.24)
	mat_rot_btn_active.metallic = 0.35
	mat_rot_btn_active.roughness = 0.22
	mat_rot_btn_active.emission_enabled = true
	mat_rot_btn_active.emission = Color(0.18, 0.85, 0.46)
	mat_rot_btn_active.emission_energy_multiplier = 1.25

	mat_rot_btn_hover = StandardMaterial3D.new()
	mat_rot_btn_hover.albedo_color = Color(0.95, 0.78, 0.22)
	mat_rot_btn_hover.metallic = 0.50
	mat_rot_btn_hover.roughness = 0.16
	mat_rot_btn_hover.emission_enabled = true
	mat_rot_btn_hover.emission = Color(1.0, 0.84, 0.28)
	mat_rot_btn_hover.emission_energy_multiplier = 2.1

	mat_rot_arrow_gold = StandardMaterial3D.new()
	mat_rot_arrow_gold.albedo_color = Color(1.0, 0.86, 0.36)
	mat_rot_arrow_gold.metallic = 0.92
	mat_rot_arrow_gold.roughness = 0.16
	mat_rot_arrow_gold.emission_enabled = true
	mat_rot_arrow_gold.emission = Color(0.95, 0.75, 0.20)
	mat_rot_arrow_gold.emission_energy_multiplier = 0.65

	mat_rot_arrow_emerald = StandardMaterial3D.new()
	mat_rot_arrow_emerald.albedo_color = Color(0.35, 1.0, 0.62)
	mat_rot_arrow_emerald.emission_enabled = true
	mat_rot_arrow_emerald.emission = Color(0.25, 0.98, 0.55)
	mat_rot_arrow_emerald.emission_energy_multiplier = 2.2

	# Halos & Ghost Previews
	mat_halo_legal = StandardMaterial3D.new()
	mat_halo_legal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo_legal.albedo_color = Color(0.25, 0.98, 0.54, 0.86)
	mat_halo_legal.emission_enabled = true
	mat_halo_legal.emission = Color(0.20, 0.95, 0.48)
	mat_halo_legal.emission_energy_multiplier = 1.65

	mat_halo_last = StandardMaterial3D.new()
	mat_halo_last.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_halo_last.albedo_color = Color(1.0, 0.84, 0.28, 0.82)
	mat_halo_last.emission_enabled = true
	mat_halo_last.emission = Color(1.0, 0.76, 0.20)
	mat_halo_last.emission_energy_multiplier = 1.35

	mat_ghost_p1 = StandardMaterial3D.new()
	mat_ghost_p1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost_p1.albedo_color = Color(1.0, 0.26, 0.32, 0.48)
	mat_ghost_p1.emission_enabled = true
	mat_ghost_p1.emission = Color(1.0, 0.20, 0.26)
	mat_ghost_p1.emission_energy_multiplier = 1.15

	mat_ghost_p2 = StandardMaterial3D.new()
	mat_ghost_p2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ghost_p2.albedo_color = Color(0.26, 0.66, 1.0, 0.48)
	mat_ghost_p2.emission_enabled = true
	mat_ghost_p2.emission = Color(0.20, 0.56, 1.0)
	mat_ghost_p2.emission_energy_multiplier = 1.15

	# 5-in-a-Row Victory VFX Materials
	mat_win_beam_core = StandardMaterial3D.new()
	mat_win_beam_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_win_beam_core.albedo_color = Color(1.0, 0.95, 0.55, 0.95)
	mat_win_beam_core.emission_enabled = true
	mat_win_beam_core.emission = Color(1.0, 0.88, 0.30)
	mat_win_beam_core.emission_energy_multiplier = 4.2

	mat_win_beam_sheath = StandardMaterial3D.new()
	mat_win_beam_sheath.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_win_beam_sheath.albedo_color = Color(1.0, 0.82, 0.24, 0.48)
	mat_win_beam_sheath.emission_enabled = true
	mat_win_beam_sheath.emission = Color(1.0, 0.74, 0.18)
	mat_win_beam_sheath.emission_energy_multiplier = 3.2

	mat_win_beacon = StandardMaterial3D.new()
	mat_win_beacon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_win_beacon.albedo_color = Color(1.0, 0.94, 0.62, 0.65)
	mat_win_beacon.emission_enabled = true
	mat_win_beacon.emission = Color(1.0, 0.88, 0.40)
	mat_win_beacon.emission_energy_multiplier = 4.0

# ============================================================================
# 2. THREE CUSTOM SCULPTED 3D MODELS (RUBY ORB, SAPPHIRE ORB, ROTATION PADDLE)
# ============================================================================

# Model 1 (gamer_id == 1) & Model 2 (gamer_id == 2):
# Sculpted 3D Tournament Orb with equatorial metallic belt, 4 directional studs, and crown finial
func _create_marble_3d_model(gamer_id: int, is_ghost: bool = false) -> Node3D:
	var root = Node3D.new()
	root.name = "PentagoOrbP%d" % gamer_id

	var body_mat: StandardMaterial3D
	var trim_mat: StandardMaterial3D
	if is_ghost:
		body_mat = mat_ghost_p1 if gamer_id == 1 else mat_ghost_p2
		trim_mat = body_mat
	else:
		body_mat = mat_marble_p1_body if gamer_id == 1 else mat_marble_p2_body
		trim_mat = mat_marble_p1_gold if gamer_id == 1 else mat_marble_p2_plat

	# 1. Core Lacquered Gemstone Sphere
	var orb_inst = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.036
	sph.height = 0.072
	sph.radial_segments = 32
	sph.rings = 16
	orb_inst.mesh = sph
	orb_inst.position = Vector3(0.0, 0.028, 0.0)
	orb_inst.material_override = body_mat
	root.add_child(orb_inst)

	# 2. Equatorial Metallic Collar Belt (shows 3D rotation clearly)
	var belt_inst = MeshInstance3D.new()
	var belt_torus = TorusMesh.new()
	belt_torus.inner_radius = 0.032
	belt_torus.outer_radius = 0.0385
	belt_torus.rings = 28
	belt_torus.ring_segments = 12
	belt_inst.mesh = belt_torus
	belt_inst.position = Vector3(0.0, 0.028, 0.0)
	belt_inst.scale = Vector3(1.0, 0.55, 1.0)
	belt_inst.material_override = trim_mat
	root.add_child(belt_inst)

	# 3. Top Crown Ring & Finial Stud (Distinct geometry for P1 Ruby vs P2 Sapphire)
	var crown_ring = MeshInstance3D.new()
	var c_torus = TorusMesh.new()
	c_torus.inner_radius = 0.012
	c_torus.outer_radius = 0.017
	c_torus.rings = 24
	c_torus.ring_segments = 10
	crown_ring.mesh = c_torus
	crown_ring.position = Vector3(0.0, 0.060, 0.0)
	crown_ring.scale = Vector3(1.0, 0.5, 1.0)
	crown_ring.material_override = trim_mat
	root.add_child(crown_ring)

	var finial = MeshInstance3D.new()
	if gamer_id == 1:
		var f_sph = SphereMesh.new()
		f_sph.radius = 0.0075
		f_sph.height = 0.015
		finial.mesh = f_sph
	else:
		var f_cyl = CylinderMesh.new()
		f_cyl.top_radius = 0.0055
		f_cyl.bottom_radius = 0.0085
		f_cyl.height = 0.012
		f_cyl.radial_segments = 6
		finial.mesh = f_cyl
	finial.position = Vector3(0.0, 0.063, 0.0)
	finial.material_override = trim_mat
	root.add_child(finial)

	# 4. Four Compass Studs around the Equator
	for k in range(4):
		var ang: float = float(k) * (PI * 0.5)
		var stud = MeshInstance3D.new()
		var s_sph = SphereMesh.new()
		s_sph.radius = 0.0045
		s_sph.height = 0.009
		stud.mesh = s_sph
		stud.position = Vector3(cos(ang) * 0.0365, 0.028, sin(ang) * 0.0365)
		stud.material_override = trim_mat
		root.add_child(stud)

	return root

# Model 3: Luxury Pill-Medallion & 3D Sculpted Curved-Arrow Rotation Button (1..8)
func _create_rotation_paddle_3d(rot_id: int, pos: Vector3, is_ccw: bool, label_fa: String) -> Node3D:
	var root = Node3D.new()
	root.name = "RotationPaddle_%d" % rot_id
	root.position = pos

	# 1. Stepped Pill-Shaped 24K Gold Bezel (Center Box + Rounded Cylinder End-Caps)
	var bezel_center = MeshInstance3D.new()
	var bz_box = BoxMesh.new()
	bz_box.size = Vector3(0.096, 0.016, 0.072)
	bezel_center.mesh = bz_box
	bezel_center.material_override = mat_gold_rail
	root.add_child(bezel_center)

	for end_sign in [-1.0, 1.0]:
		var bz_cap = MeshInstance3D.new()
		var bzc_cyl = CylinderMesh.new()
		bzc_cyl.top_radius = 0.036
		bzc_cyl.bottom_radius = 0.037
		bzc_cyl.height = 0.016
		bzc_cyl.radial_segments = 24
		bz_cap.mesh = bzc_cyl
		bz_cap.position = Vector3(end_sign * 0.048, 0.0, 0.0)
		bz_cap.material_override = mat_gold_rail
		root.add_child(bz_cap)

	# 2. Inner Interactive Core Pill Plate (Center Box + Rounded End-Caps)
	var plate_meshes: Array[MeshInstance3D] = []
	var plate_center = MeshInstance3D.new()
	plate_center.name = "CorePlate"
	var pl_box = BoxMesh.new()
	pl_box.size = Vector3(0.090, 0.020, 0.062)
	plate_center.mesh = pl_box
	plate_center.position = Vector3(0.0, 0.0025, 0.0)
	plate_center.material_override = mat_rot_btn_idle
	root.add_child(plate_center)
	plate_meshes.append(plate_center)
	rotation_btn_halos.append(plate_center)

	for end_sign in [-1.0, 1.0]:
		var pl_cap = MeshInstance3D.new()
		var plc_cyl = CylinderMesh.new()
		plc_cyl.top_radius = 0.031
		plc_cyl.bottom_radius = 0.031
		plc_cyl.height = 0.020
		plc_cyl.radial_segments = 24
		pl_cap.mesh = plc_cyl
		pl_cap.position = Vector3(end_sign * 0.045, 0.0025, 0.0)
		pl_cap.material_override = mat_rot_btn_idle
		root.add_child(pl_cap)
		plate_meshes.append(pl_cap)

	rotation_btn_plate_groups.append(plate_meshes)

	# 3. Glowing Active Halo Ring around the Pill Button (visible during Step 2)
	var glow_ring = MeshInstance3D.new()
	var gr_torus = TorusMesh.new()
	gr_torus.inner_radius = 0.040
	gr_torus.outer_radius = 0.046
	gr_torus.rings = 28
	gr_torus.ring_segments = 12
	glow_ring.mesh = gr_torus
	glow_ring.position = Vector3(0.0, 0.005, 0.0)
	glow_ring.scale = Vector3(2.05, 0.40, 0.92)
	glow_ring.material_override = mat_halo_legal
	glow_ring.visible = false
	root.add_child(glow_ring)
	rotation_btn_glow_rings.append(glow_ring)

	# 4. Raised Circular Turntable Dial Boss with True 3D Sculpted Curved Arrow
	var dial_x: float = -0.044 if is_ccw else 0.044
	var dial_well = MeshInstance3D.new()
	var dw_cyl = CylinderMesh.new()
	dw_cyl.top_radius = 0.024
	dw_cyl.bottom_radius = 0.025
	dw_cyl.height = 0.006
	dw_cyl.radial_segments = 24
	dial_well.mesh = dw_cyl
	dial_well.position = Vector3(dial_x, 0.013, 0.0)
	dial_well.material_override = mat_obsidian_bed
	root.add_child(dial_well)

	var dial_collar = MeshInstance3D.new()
	var dc_torus = TorusMesh.new()
	dc_torus.inner_radius = 0.022
	dc_torus.outer_radius = 0.0255
	dc_torus.rings = 24
	dc_torus.ring_segments = 10
	dial_collar.mesh = dc_torus
	dial_collar.position = Vector3(dial_x, 0.015, 0.0)
	dial_collar.scale = Vector3(1.0, 0.45, 1.0)
	dial_collar.material_override = mat_gold_rail
	root.add_child(dial_collar)

	var dial_pivot = Node3D.new()
	dial_pivot.name = "ArrowDialPivot"
	dial_pivot.position = Vector3(dial_x, 0.017, 0.0)
	root.add_child(dial_pivot)
	rotation_btn_dials.append(dial_pivot)

	# Build 230-degree open circular arc + 3D conical arrowhead inside dial_pivot
	var arc_radius: float = 0.0145
	var num_beads: int = 11
	var start_deg: float = 20.0 if is_ccw else 160.0
	var sweep_deg: float = -225.0 if is_ccw else 225.0
	for b_i in range(num_beads):
		var frac: float = float(b_i) / float(num_beads - 1)
		var ang: float = deg_to_rad(start_deg + sweep_deg * frac)
		var bead = MeshInstance3D.new()
		var b_sph = SphereMesh.new()
		var r_bead: float = lerpf(0.0024, 0.0038, frac)
		b_sph.radius = r_bead
		b_sph.height = r_bead * 1.6
		bead.mesh = b_sph
		bead.position = Vector3(cos(ang) * arc_radius, 0.001, sin(ang) * arc_radius)
		bead.material_override = mat_rot_arrow_gold
		dial_pivot.add_child(bead)

	# Conical 3D Arrowhead at the leading tip of the arc
	var end_ang: float = deg_to_rad(start_deg + sweep_deg)
	var tip_pos = Vector3(cos(end_ang) * arc_radius, 0.002, sin(end_ang) * arc_radius)
	var tangent_ang: float = end_ang + (-PI * 0.5 if is_ccw else PI * 0.5)
	var arrow_head = MeshInstance3D.new()
	var ah_cone = CylinderMesh.new()
	ah_cone.top_radius = 0.0
	ah_cone.bottom_radius = 0.0076
	ah_cone.height = 0.0145
	ah_cone.radial_segments = 12
	arrow_head.mesh = ah_cone
	arrow_head.position = tip_pos
	var dir_vec = Vector3(cos(tangent_ang), 0.0, sin(tangent_ang)).normalized()
	var up_axis = Vector3.UP.cross(dir_vec).normalized()
	arrow_head.basis = Basis(up_axis, PI * 0.5)
	arrow_head.scale = Vector3(1.0, 1.0, 0.55)
	arrow_head.material_override = mat_rot_arrow_emerald
	dial_pivot.add_child(arrow_head)

	# Center Jewel Pin inside Dial
	var center_pin = MeshInstance3D.new()
	var cp_sph = SphereMesh.new()
	cp_sph.radius = 0.0042
	cp_sph.height = 0.0065
	center_pin.mesh = cp_sph
	center_pin.position = Vector3(0.0, 0.0015, 0.0)
	center_pin.material_override = mat_gold_highlight
	dial_pivot.add_child(center_pin)

	# 5. Crisp Persian Direction Label (No unsupported Unicode boxes)
	var lbl = Label3D.new()
	lbl.name = "DirLabel"
	lbl.font = _font_hekayat
	lbl.font_size = 34
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.96, 0.74)
	lbl.outline_modulate = Color(0.04, 0.03, 0.02, 0.98)
	lbl.position = Vector3(0.020 if is_ccw else -0.020, 0.015, 0.0)
	lbl.rotation.x = -PI * 0.5
	lbl.pixel_size = 0.00092
	lbl.text = label_fa
	root.add_child(lbl)

	# 6. Raycast Area3D for Click & Hover
	var area = Area3D.new()
	area.name = "RotArea_%d" % rot_id
	area.set_meta("rotation_id", rot_id)
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.172, 0.048, 0.080)
	col.shape = box_shape
	area.add_child(col)
	var captured_id: int = rot_id
	area.mouse_entered.connect(func(): _on_rotation_btn_mouse_entered(captured_id))
	area.mouse_exited.connect(func(): _on_rotation_btn_mouse_exited(captured_id))
	root.add_child(area)
	rotation_btn_areas.append(area)

	return root

# ============================================================================
# 3. 3D BOARD, 4 MECHANICAL QUADRANTS & SIDE RESERVE TRAYS CONSTRUCTION
# ============================================================================

func _build_board_3d() -> void:
	if is_instance_valid(board_root):
		board_root.queue_free()

	board_root = Node3D.new()
	board_root.name = "PentagoBoardRoot"
	add_child(board_root)

	quadrants_root = Node3D.new()
	quadrants_root.name = "QuadrantsRoot"
	board_root.add_child(quadrants_root)

	controls_root = Node3D.new()
	controls_root.name = "ControlsRoot"
	board_root.add_child(controls_root)

	trays_root = Node3D.new()
	trays_root.name = "TraysRoot"
	board_root.add_child(trays_root)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	board_root.add_child(fx_root)

	hover_preview_root = Node3D.new()
	hover_preview_root.name = "HoverPreviewRoot"
	board_root.add_child(hover_preview_root)

	# 1. Stepped Royal Walnut Outer Plinth & Obsidian Mechanical Bed
	var plinth_low = MeshInstance3D.new()
	var pl_box1 = BoxMesh.new()
	pl_box1.size = Vector3(0.92, 0.020, 0.92)
	plinth_low.mesh = pl_box1
	plinth_low.position = Vector3(0.0, 0.010, 0.0)
	plinth_low.material_override = mat_walnut_chassis
	board_root.add_child(plinth_low)

	var plinth_mid = MeshInstance3D.new()
	var pl_box2 = BoxMesh.new()
	pl_box2.size = Vector3(0.86, 0.016, 0.86)
	plinth_mid.mesh = pl_box2
	plinth_mid.position = Vector3(0.0, 0.024, 0.0)
	plinth_mid.material_override = mat_mahogany_trim
	board_root.add_child(plinth_mid)

	var gold_border = MeshInstance3D.new()
	var gb_box = BoxMesh.new()
	gb_box.size = Vector3(0.835, 0.014, 0.835)
	gold_border.mesh = gb_box
	gold_border.position = Vector3(0.0, 0.028, 0.0)
	gold_border.material_override = mat_gold_rail
	board_root.add_child(gold_border)

	var inner_bed = MeshInstance3D.new()
	var ib_box = BoxMesh.new()
	ib_box.size = Vector3(0.810, 0.012, 0.810)
	inner_bed.mesh = ib_box
	inner_bed.position = Vector3(0.0, 0.031, 0.0)
	inner_bed.material_override = mat_obsidian_bed
	board_root.add_child(inner_bed)

	# Central Mechanical Brass Compass Hub (between the 4 rotating quadrants)
	var center_hub = MeshInstance3D.new()
	var ch_cyl = CylinderMesh.new()
	ch_cyl.top_radius = 0.036
	ch_cyl.bottom_radius = 0.042
	ch_cyl.height = 0.016
	ch_cyl.radial_segments = 24
	center_hub.mesh = ch_cyl
	center_hub.position = Vector3(0.0, BOARD_SURFACE_Y + 0.002, 0.0)
	center_hub.material_override = mat_brass_gear
	board_root.add_child(center_hub)

	var center_jewel = MeshInstance3D.new()
	var cj_sph = SphereMesh.new()
	cj_sph.radius = 0.016
	cj_sph.height = 0.016
	center_jewel.mesh = cj_sph
	center_jewel.position = Vector3(0.0, BOARD_SURFACE_Y + 0.010, 0.0)
	center_jewel.material_override = mat_gold_rail
	board_root.add_child(center_jewel)

	# 4 Corner Brass Boss Rivets on Outer Chassis
	for cx in [-0.405, 0.405]:
		for cz in [-0.405, 0.405]:
			var boss = MeshInstance3D.new()
			var b_sph = SphereMesh.new()
			b_sph.radius = 0.014
			b_sph.height = 0.014
			boss.mesh = b_sph
			boss.position = Vector3(cx, BOARD_SURFACE_Y, cz)
			boss.material_override = mat_gold_rail
			board_root.add_child(boss)

	# 2. Build the 4 Rotating 3x3 Quadrants (0..3) and 36 Sockets (0..35)
	quadrant_pivots.clear()
	quadrant_rim_meshes.clear()
	cell_local_positions.resize(NUM_CELLS)
	cell_areas.resize(NUM_CELLS)
	cell_legal_halos.resize(NUM_CELLS)
	cell_last_halos.resize(NUM_CELLS)
	board_marble_nodes.resize(NUM_CELLS)

	for q_idx in range(NUM_QUADRANTS):
		var q_pivot = Node3D.new()
		q_pivot.name = "QuadrantPivot_%d" % q_idx
		q_pivot.position = QUAD_CENTERS[q_idx]
		quadrants_root.add_child(q_pivot)
		quadrant_pivots.append(q_pivot)

		# Brass Turntable Gear Under-Ring
		var gear_ring = MeshInstance3D.new()
		var gr_cyl = CylinderMesh.new()
		gr_cyl.top_radius = 0.175
		gr_cyl.bottom_radius = 0.180
		gr_cyl.height = 0.010
		gr_cyl.radial_segments = 32
		gear_ring.mesh = gr_cyl
		gear_ring.position = Vector3(0.0, -0.002, 0.0)
		gear_ring.material_override = mat_brass_gear
		q_pivot.add_child(gear_ring)

		# Quadrant Gold Beveled Outer Frame
		var q_rim = MeshInstance3D.new()
		q_rim.name = "QuadRim"
		var qr_box = BoxMesh.new()
		qr_box.size = Vector3(QUAD_SIZE + 0.012, 0.014, QUAD_SIZE + 0.012)
		q_rim.mesh = qr_box
		q_rim.position = Vector3(0.0, 0.003, 0.0)
		q_rim.material_override = mat_gold_rail
		q_pivot.add_child(q_rim)
		quadrant_rim_meshes.append(q_rim)

		# Quadrant Slate Playing Block
		var q_block = MeshInstance3D.new()
		var qb_box = BoxMesh.new()
		qb_box.size = Vector3(QUAD_SIZE, 0.016, QUAD_SIZE)
		q_block.mesh = qb_box
		q_block.position = Vector3(0.0, 0.005, 0.0)
		q_block.material_override = mat_quad_slate
		q_pivot.add_child(q_block)

		# Decorative Gold Corner Studs on each Quadrant
		for qcx in [-0.165, 0.165]:
			for qcz in [-0.165, 0.165]:
				var q_stud = MeshInstance3D.new()
				var qs_sph = SphereMesh.new()
				qs_sph.radius = 0.0065
				qs_sph.height = 0.008
				q_stud.mesh = qs_sph
				q_stud.position = Vector3(qcx, 0.014, qcz)
				q_stud.material_override = mat_gold_rail
				q_pivot.add_child(q_stud)

		# 9 Recessed Marble Sockets inside Quadrant q_idx
		for local_i in range(CELLS_PER_QUADRANT):
			var cell_id: int = q_idx * 9 + local_i
			var r_loc: int = int(local_i / 3)
			var c_loc: int = local_i % 3
			var lx: float = float(c_loc - 1) * CELL_SPACING
			var lz: float = float(r_loc - 1) * CELL_SPACING
			var loc_pos = Vector3(lx, 0.013, lz)
			cell_local_positions[cell_id] = loc_pos
			board_marble_nodes[cell_id] = null

			# Brass Socket Rim
			var s_rim = MeshInstance3D.new()
			var sr_torus = TorusMesh.new()
			sr_torus.inner_radius = 0.036
			sr_torus.outer_radius = 0.043
			sr_torus.rings = 24
			sr_torus.ring_segments = 12
			s_rim.mesh = sr_torus
			s_rim.position = loc_pos + Vector3(0.0, 0.001, 0.0)
			s_rim.scale = Vector3(1.0, 0.55, 1.0)
			s_rim.material_override = mat_brass_gear
			q_pivot.add_child(s_rim)

			# Dark Recessed Socket Well
			var s_well = MeshInstance3D.new()
			var sw_cyl = CylinderMesh.new()
			sw_cyl.top_radius = 0.036
			sw_cyl.bottom_radius = 0.032
			sw_cyl.height = 0.006
			sw_cyl.radial_segments = 24
			s_well.mesh = sw_cyl
			s_well.position = loc_pos + Vector3(0.0, -0.001, 0.0)
			s_well.material_override = mat_socket_well
			q_pivot.add_child(s_well)

			# Legal Move / Hover Halo Ring
			var leg_halo = MeshInstance3D.new()
			var lh_torus = TorusMesh.new()
			lh_torus.inner_radius = 0.039
			lh_torus.outer_radius = 0.046
			lh_torus.rings = 24
			lh_torus.ring_segments = 10
			leg_halo.mesh = lh_torus
			leg_halo.position = loc_pos + Vector3(0.0, 0.003, 0.0)
			leg_halo.scale = Vector3(1.0, 0.4, 1.0)
			leg_halo.material_override = mat_halo_legal
			leg_halo.visible = false
			q_pivot.add_child(leg_halo)
			cell_legal_halos[cell_id] = leg_halo

			# Last Placed Marble Halo Ring
			var last_halo = MeshInstance3D.new()
			var lah_torus = TorusMesh.new()
			lah_torus.inner_radius = 0.041
			lah_torus.outer_radius = 0.049
			lah_torus.rings = 24
			lah_torus.ring_segments = 10
			last_halo.mesh = lah_torus
			last_halo.position = loc_pos + Vector3(0.0, 0.0025, 0.0)
			last_halo.scale = Vector3(1.0, 0.4, 1.0)
			last_halo.material_override = mat_halo_last
			last_halo.visible = false
			q_pivot.add_child(last_halo)
			cell_last_halos[cell_id] = last_halo

			# Raycast Area3D for Cell Click & Hover
			var c_area = Area3D.new()
			c_area.name = "CellArea_%d" % cell_id
			c_area.position = loc_pos
			c_area.set_meta("cell_id", cell_id)
			var c_col = CollisionShape3D.new()
			var c_cyl = CylinderShape3D.new()
			c_cyl.radius = 0.050
			c_cyl.height = 0.055
			c_col.shape = c_cyl
			c_area.add_child(c_col)
			var captured_cid: int = cell_id
			c_area.mouse_entered.connect(func(): _on_cell_mouse_entered(captured_cid))
			c_area.mouse_exited.connect(func(): _on_cell_mouse_exited(captured_cid))
			q_pivot.add_child(c_area)
			cell_areas[cell_id] = c_area

	# 3. Build the 8 Sculpted 3D Rotation Paddles around the Quadrants (1..8)
	# Exact parity with Flutter PentagoBoardWidget & Backend rotate_piece(1..8):
	# - Top Row (above Q0 & Q1, Z = -0.458):
	#   1: Q0 CCW (↺ پادساعتگرد) at X = -0.285
	#   2: Q0 CW  (↻ ساعتگرد)    at X = -0.105
	#   3: Q1 CCW (↺ پادساعتگرد) at X = +0.105
	#   4: Q1 CW  (↻ ساعتگرد)    at X = +0.285
	# - Bottom Row (below Q2 & Q3, Z = +0.458):
	#   6: Q2 CW  (↻ ساعتگرد)    at X = -0.285
	#   5: Q2 CCW (↺ پادساعتگرد) at X = -0.105
	#   8: Q3 CW  (↻ ساعتگرد)    at X = +0.285  (Wait: let's place CCW ↺ on left and CW ↻ on right or match exact rotation_id!)
	_build_rotation_paddles()

	# 4. Build Side Reserve Trays & Top/Bottom Status Plaques
	_build_side_trays_and_plaques()

	# 5. Build Hover Ghost Marbles & Quadrant Spin Preview Ring
	_build_hover_previews()

func _build_rotation_paddles() -> void:
	rotation_btn_nodes.resize(8)
	rotation_btn_halos.clear()
	rotation_btn_plate_groups.clear()
	rotation_btn_dials.clear()
	rotation_btn_glow_rings.clear()
	rotation_btn_areas.clear()

	# Build 4 Sculpted Quadrant Control Console Bridges linking each button pair to its Quadrant
	var console_centers: Array[Vector3] = [
		Vector3(-0.195, BOARD_SURFACE_Y - 0.002, -0.458), # Q0 Console (Top-Left)
		Vector3(0.195,  BOARD_SURFACE_Y - 0.002, -0.458), # Q1 Console (Top-Right)
		Vector3(-0.195, BOARD_SURFACE_Y - 0.002,  0.458), # Q2 Console (Bottom-Left)
		Vector3(0.195,  BOARD_SURFACE_Y - 0.002,  0.458)  # Q3 Console (Bottom-Right)
	]
	for q_i in range(4):
		var c_pos: Vector3 = console_centers[q_i]
		var z_dir: float = -1.0 if q_i < 2 else 1.0
		var dock = MeshInstance3D.new()
		var dk_box = BoxMesh.new()
		dk_box.size = Vector3(0.376, 0.012, 0.088)
		dock.mesh = dk_box
		dock.position = c_pos
		dock.material_override = mat_mahogany_trim
		controls_root.add_child(dock)

		var dock_rim = MeshInstance3D.new()
		var dr_box = BoxMesh.new()
		dr_box.size = Vector3(0.384, 0.008, 0.094)
		dock_rim.mesh = dr_box
		dock_rim.position = c_pos + Vector3(0.0, -0.002, 0.0)
		dock_rim.material_override = mat_brass_gear
		controls_root.add_child(dock_rim)

		# Dual Brass Mechanical Connector Struts linking the console to its 3x3 quadrant
		for sx in [-0.092, 0.092]:
			var strut = MeshInstance3D.new()
			var st_box = BoxMesh.new()
			st_box.size = Vector3(0.022, 0.010, 0.052)
			strut.mesh = st_box
			strut.position = Vector3(c_pos.x + sx, BOARD_SURFACE_Y, c_pos.z - z_dir * 0.052)
			strut.material_override = mat_gold_rail
			controls_root.add_child(strut)

	# Position each of the 8 rotation buttons clearly on its quadrant console:
	# Left button = CCW (odd id: 1, 3, 5, 7) and Right button = CW (even id: 2, 4, 6, 8)
	var btn_specs: Array = [
		{"id": 1, "pos": Vector3(-0.288, BOARD_SURFACE_Y + 0.004, -0.458), "ccw": true,  "txt": "چرخش چپ"},
		{"id": 2, "pos": Vector3(-0.102, BOARD_SURFACE_Y + 0.004, -0.458), "ccw": false, "txt": "چرخش راست"},
		{"id": 3, "pos": Vector3(0.102,  BOARD_SURFACE_Y + 0.004, -0.458), "ccw": true,  "txt": "چرخش چپ"},
		{"id": 4, "pos": Vector3(0.288,  BOARD_SURFACE_Y + 0.004, -0.458), "ccw": false, "txt": "چرخش راست"},
		{"id": 5, "pos": Vector3(-0.288, BOARD_SURFACE_Y + 0.004,  0.458), "ccw": true,  "txt": "چرخش چپ"},
		{"id": 6, "pos": Vector3(-0.102, BOARD_SURFACE_Y + 0.004,  0.458), "ccw": false, "txt": "چرخش راست"},
		{"id": 7, "pos": Vector3(0.102,  BOARD_SURFACE_Y + 0.004,  0.458), "ccw": true,  "txt": "چرخش چپ"},
		{"id": 8, "pos": Vector3(0.288,  BOARD_SURFACE_Y + 0.004,  0.458), "ccw": false, "txt": "چرخش راست"}
	]
	for spec in btn_specs:
		var rid: int = int(spec["id"])
		var paddle = _create_rotation_paddle_3d(rid, spec["pos"], bool(spec["ccw"]), str(spec["txt"]))
		controls_root.add_child(paddle)
		rotation_btn_nodes[rid - 1] = paddle

func _build_side_trays_and_plaques() -> void:
	p1_reserve_positions.clear()
	p2_reserve_positions.clear()

	# Left Reserve Tray (P1 Red, X = -0.575) & Right Reserve Tray (P2 Blue, X = +0.575)
	for side in [1, 2]:
		var x_center: float = -0.575 if side == 1 else 0.575

		var tray_base = MeshInstance3D.new()
		var tb_box = BoxMesh.new()
		tb_box.size = Vector3(0.165, 0.020, 0.84)
		tray_base.mesh = tb_box
		tray_base.position = Vector3(x_center, BOARD_SURFACE_Y - 0.004, 0.0)
		tray_base.material_override = mat_walnut_chassis
		trays_root.add_child(tray_base)

		var tray_rim = MeshInstance3D.new()
		var tr_box = BoxMesh.new()
		tr_box.size = Vector3(0.173, 0.012, 0.848)
		tray_rim.mesh = tr_box
		tray_rim.position = Vector3(x_center, BOARD_SURFACE_Y - 0.009, 0.0)
		tray_rim.material_override = mat_brass_gear
		trays_root.add_child(tray_rim)

		var velvet = MeshInstance3D.new()
		var v_box = BoxMesh.new()
		v_box.size = Vector3(0.138, 0.008, 0.72)
		velvet.mesh = v_box
		velvet.position = Vector3(x_center, BOARD_SURFACE_Y + 0.004, 0.035)
		velvet.material_override = mat_velvet_tray
		trays_root.add_child(velvet)

		# Header Label on Tray
		var lbl = Label3D.new()
		lbl.font = _font_hekayat
		lbl.font_size = 34
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.52, 0.55) if side == 1 else Color(0.52, 0.82, 1.0)
		lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.96)
		lbl.position = Vector3(x_center, BOARD_SURFACE_Y + 0.014, -0.365)
		lbl.rotation.x = -PI * 0.5
		lbl.pixel_size = 0.0010
		lbl.text = "گوی قرمز: ۱۸" if side == 1 else "گوی آبی: ۱۸"
		trays_root.add_child(lbl)
		if side == 1:
			lbl_p1_tray_3d = lbl
		else:
			lbl_p2_tray_3d = lbl

		# 18 Reserve Marble Slots (9 rows x 2 cols)
		for row_i in range(9):
			var z_s: float = -0.275 + float(row_i) * 0.076
			for col_i in range(2):
				var x_s: float = x_center + (-0.034 if col_i == 0 else 0.034)
				var slot_pos = Vector3(x_s, BOARD_SURFACE_Y + 0.008, z_s)
				if side == 1:
					p1_reserve_positions.append(slot_pos)
				else:
					p2_reserve_positions.append(slot_pos)

				var well = MeshInstance3D.new()
				var w_torus = TorusMesh.new()
				w_torus.inner_radius = 0.016
				w_torus.outer_radius = 0.021
				w_torus.rings = 16
				w_torus.ring_segments = 8
				well.mesh = w_torus
				well.position = slot_pos + Vector3(0.0, 0.001, 0.0)
				well.scale = Vector3(1.0, 0.5, 1.0)
				well.material_override = mat_socket_well
				trays_root.add_child(well)

	# Top Title Plaque (Z = -0.555)
	var top_plaque = MeshInstance3D.new()
	var tp_box = BoxMesh.new()
	tp_box.size = Vector3(0.62, 0.014, 0.056)
	top_plaque.mesh = tp_box
	top_plaque.position = Vector3(0.0, BOARD_SURFACE_Y, -0.555)
	top_plaque.material_override = mat_walnut_chassis
	trays_root.add_child(top_plaque)

	var top_gold = MeshInstance3D.new()
	var tg_box = BoxMesh.new()
	tg_box.size = Vector3(0.63, 0.008, 0.064)
	top_gold.mesh = tg_box
	top_gold.position = Vector3(0.0, BOARD_SURFACE_Y - 0.003, -0.555)
	top_gold.material_override = mat_gold_rail
	trays_root.add_child(top_gold)

	lbl_title_3d = Label3D.new()
	lbl_title_3d.font = _font_hekayat
	lbl_title_3d.font_size = 38
	lbl_title_3d.outline_size = 10
	lbl_title_3d.modulate = Color(1.0, 0.90, 0.45)
	lbl_title_3d.outline_modulate = Color(0.06, 0.03, 0.02, 0.98)
	lbl_title_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.012, -0.555)
	lbl_title_3d.rotation.x = -PI * 0.5
	lbl_title_3d.pixel_size = 0.00105
	lbl_title_3d.text = "پنتاگو — نبرد ۵ گوی در یک ردیف"
	trays_root.add_child(lbl_title_3d)

	# Bottom Phase Instruction Plaque (Z = +0.555)
	var bot_plaque = MeshInstance3D.new()
	var bp_box = BoxMesh.new()
	bp_box.size = Vector3(0.76, 0.014, 0.062)
	bot_plaque.mesh = bp_box
	bot_plaque.position = Vector3(0.0, BOARD_SURFACE_Y, 0.555)
	bot_plaque.material_override = mat_walnut_chassis
	trays_root.add_child(bot_plaque)

	var bot_gold = MeshInstance3D.new()
	var bg_box = BoxMesh.new()
	bg_box.size = Vector3(0.77, 0.008, 0.070)
	bot_gold.mesh = bg_box
	bot_gold.position = Vector3(0.0, BOARD_SURFACE_Y - 0.003, 0.555)
	bot_gold.material_override = mat_gold_rail
	trays_root.add_child(bot_gold)

	lbl_phase_3d = Label3D.new()
	lbl_phase_3d.font = _font_hekayat
	lbl_phase_3d.font_size = 38
	lbl_phase_3d.outline_size = 10
	lbl_phase_3d.modulate = Color(0.95, 0.96, 1.0)
	lbl_phase_3d.outline_modulate = Color(0.05, 0.03, 0.02, 0.98)
	lbl_phase_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.012, 0.555)
	lbl_phase_3d.rotation.x = -PI * 0.5
	lbl_phase_3d.pixel_size = 0.00105
	lbl_phase_3d.text = "فاز ۱ از ۲: یک گوی در یکی از خانه‌های خالی قرار دهید"
	trays_root.add_child(lbl_phase_3d)

func _build_hover_previews() -> void:
	ghost_marble_p1 = _create_marble_3d_model(1, true)
	ghost_marble_p1.visible = false
	hover_preview_root.add_child(ghost_marble_p1)

	ghost_marble_p2 = _create_marble_3d_model(2, true)
	ghost_marble_p2.visible = false
	hover_preview_root.add_child(ghost_marble_p2)

	# Quadrant Spin Preview Ring (appears over a quadrant when hovering a rotation paddle)
	quadrant_spin_preview = Node3D.new()
	quadrant_spin_preview.name = "QuadrantSpinPreview"
	quadrant_spin_preview.visible = false
	hover_preview_root.add_child(quadrant_spin_preview)

	var ring_inst = MeshInstance3D.new()
	var r_torus = TorusMesh.new()
	r_torus.inner_radius = 0.145
	r_torus.outer_radius = 0.160
	r_torus.rings = 32
	r_torus.ring_segments = 12
	ring_inst.mesh = r_torus
	ring_inst.scale = Vector3(1.0, 0.35, 1.0)
	ring_inst.material_override = mat_rot_arrow_emerald
	quadrant_spin_preview.add_child(ring_inst)

	spin_preview_arrows.clear()
	for k in range(4):
		var ang: float = float(k) * (PI * 0.5)
		var cone_inst = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.020
		cone.height = 0.042
		cone.radial_segments = 12
		cone_inst.mesh = cone
		cone_inst.position = Vector3(cos(ang) * 0.152, 0.005, sin(ang) * 0.152)
		cone_inst.material_override = mat_gold_highlight
		quadrant_spin_preview.add_child(cone_inst)
		spin_preview_arrows.append(cone_inst)

# ============================================================================
# 4. STATE INITIALIZATION, SYNC & VISUAL REBUILD
# ============================================================================

func _init_board_state() -> void:
	board_state.resize(NUM_CELLS)
	for i in range(NUM_CELLS):
		board_state[i] = 0
	player1_pawns = 18
	player2_pawns = 18
	is_selection_played = false
	is_rotation_played = false
	is_animating_rotation = false
	last_placed_cell_id = -1
	last_rotated_quadrant = -1
	hovered_cell_id = -1
	hovered_rotation_id = -1
	_win_vfx_shown = false

func _rebuild_all_pieces_visual() -> void:
	# Reset quadrant pivots to 0 rotation
	for q_idx in range(quadrant_pivots.size()):
		if is_instance_valid(quadrant_pivots[q_idx]):
			quadrant_pivots[q_idx].rotation = Vector3.ZERO
			quadrant_pivots[q_idx].position = QUAD_CENTERS[q_idx]

	# Clear and respawn active marbles on the 36 cells
	var p1_on_board: int = 0
	var p2_on_board: int = 0
	for i in range(NUM_CELLS):
		if i < board_marble_nodes.size() and is_instance_valid(board_marble_nodes[i]):
			board_marble_nodes[i].queue_free()
			board_marble_nodes[i] = null
		var owner_id: int = board_state[i]
		if owner_id == 1 or owner_id == 2:
			if owner_id == 1:
				p1_on_board += 1
			else:
				p2_on_board += 1
			var q_idx: int = int(i / 9)
			var m_node = _create_marble_3d_model(owner_id, false)
			m_node.position = cell_local_positions[i]
			quadrant_pivots[q_idx].add_child(m_node)
			board_marble_nodes[i] = m_node

	player1_pawns = clampi(18 - p1_on_board, 0, 18)
	player2_pawns = clampi(18 - p2_on_board, 0, 18)
	_sync_reserve_trays_visual()
	_update_3d_labels_and_highlights()

func _sync_reserve_trays_visual() -> void:
	while p1_reserve_marbles.size() > player1_pawns:
		var m1 = p1_reserve_marbles.pop_back()
		if is_instance_valid(m1):
			m1.queue_free()
	while p1_reserve_marbles.size() < player1_pawns and p1_reserve_marbles.size() < p1_reserve_positions.size():
		var idx1: int = p1_reserve_marbles.size()
		var rm1 = _create_marble_3d_model(1, false)
		rm1.position = p1_reserve_positions[idx1]
		rm1.scale = Vector3(0.62, 0.62, 0.62)
		trays_root.add_child(rm1)
		p1_reserve_marbles.append(rm1)

	while p2_reserve_marbles.size() > player2_pawns:
		var m2 = p2_reserve_marbles.pop_back()
		if is_instance_valid(m2):
			m2.queue_free()
	while p2_reserve_marbles.size() < player2_pawns and p2_reserve_marbles.size() < p2_reserve_positions.size():
		var idx2: int = p2_reserve_marbles.size()
		var rm2 = _create_marble_3d_model(2, false)
		rm2.position = p2_reserve_positions[idx2]
		rm2.scale = Vector3(0.62, 0.62, 0.62)
		trays_root.add_child(rm2)
		p2_reserve_marbles.append(rm2)

func _update_3d_labels_and_highlights() -> void:
	if is_instance_valid(lbl_p1_tray_3d):
		lbl_p1_tray_3d.text = "گوی قرمز: %s" % _fa_digits(player1_pawns)
	if is_instance_valid(lbl_p2_tray_3d):
		lbl_p2_tray_3d.text = "گوی آبی: %s" % _fa_digits(player2_pawns)

	var can_place: bool = GameManager.is_game_active and is_my_turn and not is_board_locked and not is_selection_played and not is_animating_rotation
	var can_rotate: bool = GameManager.is_game_active and is_my_turn and not is_board_locked and is_selection_played and not is_rotation_played and not is_animating_rotation

	if is_instance_valid(lbl_phase_3d):
		if _win_vfx_shown:
			lbl_phase_3d.text = "پنج گوی در یک ردیف تکمیل شد! پایان مسابقه"
			lbl_phase_3d.modulate = Color(1.0, 0.92, 0.35)
		elif not GameManager.is_game_active:
			lbl_phase_3d.text = "پنتاگو: یک گوی بگذارید و یکی از ۴ صفحه را بچرخانید"
			lbl_phase_3d.modulate = Color(0.95, 0.95, 1.0)
		elif can_place:
			lbl_phase_3d.text = "گام ۱ از ۲: یک گوی در یکی از خانه‌های خالی قرار دهید"
			lbl_phase_3d.modulate = Color(0.42, 1.0, 0.62)
		elif can_rotate:
			lbl_phase_3d.text = "گام ۲ از ۲: با دکمه‌های چرخش، یکی از ۴ صفحه را ۹۰ درجه بچرخانید"
			lbl_phase_3d.modulate = Color(1.0, 0.90, 0.32)
		elif is_my_turn:
			lbl_phase_3d.text = "در حال ثبت حرکت و چرخش صفحه..."
			lbl_phase_3d.modulate = Color(0.90, 0.92, 1.0)
		else:
			if not is_selection_played:
				lbl_phase_3d.text = "نوبت حریف: در حال کاشت گوی روی صفحه..."
			else:
				lbl_phase_3d.text = "نوبت حریف: در حال انتخاب جهت چرخش یکی از ۴ صفحه..."
			lbl_phase_3d.modulate = Color(1.0, 0.78, 0.42)

	# Update 36 cell halos
	for i in range(NUM_CELLS):
		if i < cell_last_halos.size() and is_instance_valid(cell_last_halos[i]):
			cell_last_halos[i].visible = (i == last_placed_cell_id)
		if i < cell_legal_halos.size() and is_instance_valid(cell_legal_halos[i]):
			cell_legal_halos[i].visible = (can_place and board_state[i] == 0 and (hovered_cell_id == i or hovered_cell_id == -1))

	# Update 8 rotation button visuals (all pill meshes + outer glow ring)
	for r_idx in range(8):
		var rot_id: int = r_idx + 1
		var target_mat: StandardMaterial3D = mat_rot_btn_idle
		if can_rotate:
			target_mat = mat_rot_btn_hover if (hovered_rotation_id == rot_id) else mat_rot_btn_active
		if r_idx < rotation_btn_plate_groups.size():
			for mesh_part in rotation_btn_plate_groups[r_idx]:
				if is_instance_valid(mesh_part):
					mesh_part.material_override = target_mat
		elif r_idx < rotation_btn_halos.size() and is_instance_valid(rotation_btn_halos[r_idx]):
			rotation_btn_halos[r_idx].material_override = target_mat
		if r_idx < rotation_btn_glow_rings.size() and is_instance_valid(rotation_btn_glow_rings[r_idx]):
			rotation_btn_glow_rings[r_idx].visible = can_rotate

	# Update quadrant rim highlight when hovering a rotation paddle
	var hov_quad: int = int((hovered_rotation_id - 1) / 2) if (can_rotate and hovered_rotation_id >= 1 and hovered_rotation_id <= 8) else -1
	for q_idx in range(quadrant_rim_meshes.size()):
		if is_instance_valid(quadrant_rim_meshes[q_idx]):
			quadrant_rim_meshes[q_idx].material_override = mat_gold_highlight if q_idx == hov_quad else mat_gold_rail

	_update_hover_preview()

func _update_hover_preview() -> void:
	if is_instance_valid(ghost_marble_p1):
		ghost_marble_p1.visible = false
	if is_instance_valid(ghost_marble_p2):
		ghost_marble_p2.visible = false
	if is_instance_valid(quadrant_spin_preview):
		quadrant_spin_preview.visible = false

	if not GameManager.is_game_active or not is_my_turn or is_board_locked or is_animating_rotation:
		return

	var my_idx: int = GameManager.my_player_index

	# Step 1 Hover: Show Ghost Marble in empty socket
	if not is_selection_played:
		if hovered_cell_id >= 0 and hovered_cell_id < NUM_CELLS and board_state[hovered_cell_id] == 0:
			var q_idx: int = int(hovered_cell_id / 9)
			var world_pos: Vector3 = QUAD_CENTERS[q_idx] + cell_local_positions[hovered_cell_id]
			var g_node: Node3D = ghost_marble_p1 if my_idx == 1 else ghost_marble_p2
			if is_instance_valid(g_node):
				g_node.position = world_pos
				g_node.visible = true
		return

	# Step 2 Hover: Show Rotating Ring Preview on Hovered Quadrant
	if is_selection_played and not is_rotation_played:
		if hovered_rotation_id >= 1 and hovered_rotation_id <= 8 and is_instance_valid(quadrant_spin_preview):
			var q_idx: int = int((hovered_rotation_id - 1) / 2)
			var is_ccw: bool = (hovered_rotation_id % 2 == 1)
			quadrant_spin_preview.position = QUAD_CENTERS[q_idx] + Vector3(0.0, 0.045, 0.0)
			quadrant_spin_preview.visible = true
			for k in range(spin_preview_arrows.size()):
				var ang: float = float(k) * (PI * 0.5)
				var tangent_dir: float = -ang + (PI if is_ccw else 0.0)
				spin_preview_arrows[k].rotation = Vector3(PI * 0.5, tangent_dir, 0.0)

# ============================================================================
# 5. INPUT HANDLING & CAMERA RAYCASTING (SINGLE SOURCE OF INPUT)
# ============================================================================

func _on_cell_mouse_entered(cell_id: int) -> void:
	hovered_cell_id = cell_id
	_update_3d_labels_and_highlights()

func _on_cell_mouse_exited(cell_id: int) -> void:
	if hovered_cell_id == cell_id:
		hovered_cell_id = -1
		_update_3d_labels_and_highlights()

func _on_rotation_btn_mouse_entered(rot_id: int) -> void:
	hovered_rotation_id = rot_id
	_update_3d_labels_and_highlights()

func _on_rotation_btn_mouse_exited(rot_id: int) -> void:
	if hovered_rotation_id == rot_id:
		hovered_rotation_id = -1
		_update_3d_labels_and_highlights()

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return

	if event is InputEventMouseMotion:
		_perform_hover_raycast(event.position)
		return

	var is_click: bool = false
	var click_pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
		click_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
		click_pos = event.position

	if not is_click:
		return

	var hit = _raycast_board(click_pos)
	if hit.is_empty():
		return

	get_viewport().set_input_as_handled()
	if hit.has("rotation_id"):
		_attempt_rotate_quadrant(int(hit["rotation_id"]))
	elif hit.has("cell_id"):
		_attempt_place_marble(int(hit["cell_id"]))

func _perform_hover_raycast(screen_pos: Vector2) -> void:
	var hit = _raycast_board(screen_pos)
	var new_cell: int = int(hit.get("cell_id", -1))
	var new_rot: int = int(hit.get("rotation_id", -1))
	if new_cell != hovered_cell_id or new_rot != hovered_rotation_id:
		hovered_cell_id = new_cell
		hovered_rotation_id = new_rot
		_update_3d_labels_and_highlights()

func _raycast_board(screen_pos: Vector2) -> Dictionary:
	var cam = get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return {}
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * 10.0)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var res = space.intersect_ray(query)
	if not res.is_empty() and res.has("collider") and is_instance_valid(res["collider"]):
		var col = res["collider"]
		if col.has_meta("rotation_id"):
			return {"rotation_id": int(col.get_meta("rotation_id"))}
		if col.has_meta("cell_id"):
			return {"cell_id": int(col.get_meta("cell_id"))}

	# Geometric fallback on board plane Y = BOARD_SURFACE_Y + 0.015
	if absf(dir.y) > 0.001:
		var t: float = ((BOARD_SURFACE_Y + 0.015) - from.y) / dir.y
		if t > 0.0:
			var pt: Vector3 = from + dir * t
			var local_pt: Vector3 = global_transform.affine_inverse() * pt
			# Check 8 rotation buttons first
			for r_idx in range(rotation_btn_nodes.size()):
				var b_node = rotation_btn_nodes[r_idx]
				if is_instance_valid(b_node):
					if absf(local_pt.x - b_node.position.x) <= 0.086 and absf(local_pt.z - b_node.position.z) <= 0.044:
						return {"rotation_id": r_idx + 1}
			# Check 36 cells
			var best_cid: int = -1
			var best_dist: float = 0.054
			for cid in range(NUM_CELLS):
				var q_idx: int = int(cid / 9)
				var c_world: Vector3 = QUAD_CENTERS[q_idx] + cell_local_positions[cid]
				var d2: float = Vector2(local_pt.x - c_world.x, local_pt.z - c_world.z).length()
				if d2 < best_dist:
					best_dist = d2
					best_cid = cid
			if best_cid != -1:
				return {"cell_id": best_cid}
	return {}

func _attempt_place_marble(cell_id: int) -> void:
	if not GameManager.is_game_active or cell_id < 0 or cell_id >= NUM_CELLS:
		return
	if is_board_locked or is_animating_rotation:
		return
	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.sfx_invalid()
		return
	if is_selection_played:
		show_hint("شما گوی خود را کاشته‌اید! اکنون یکی از ۴ صفحه را با فلش‌ها ۹۰ درجه بچرخانید.")
		AudioManager.sfx_invalid()
		return
	if board_state[cell_id] != 0:
		show_hint("این خانه قبلاً پر شده است؛ خانه دیگری انتخاب کنید.")
		AudioManager.sfx_invalid()
		return

	AudioManager.sfx_tap()
	is_selection_played = true
	hovered_cell_id = -1
	var my_idx: int = GameManager.my_player_index
	_execute_place_marble(my_idx, cell_id)
	send_move(Commands.Select_Peace, cell_id)

func _attempt_rotate_quadrant(rot_id: int) -> void:
	if not GameManager.is_game_active or rot_id < 1 or rot_id > 8:
		return
	if is_board_locked or is_animating_rotation:
		return
	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.sfx_invalid()
		return
	if not is_selection_played:
		show_hint("ابتدا یک گوی در یکی از خانه‌های خالی روی صفحه قرار دهید!")
		AudioManager.sfx_invalid()
		return
	if is_rotation_played:
		return

	AudioManager.sfx_tap()
	is_rotation_played = true
	set_board_locked(true)
	hovered_rotation_id = -1
	_update_3d_labels_and_highlights()
	send_move(Commands.Rotate_Peace, rot_id)

# ============================================================================
# 6. PHYSICAL 3D ANIMATIONS (MARBLE DROP, 90° QUADRANT TURNTABLE & WIN VFX)
# ============================================================================

func _execute_place_marble(user_id: int, cell_id: int) -> void:
	if cell_id < 0 or cell_id >= NUM_CELLS:
		return
	var already_there: bool = (board_state[cell_id] == user_id and is_instance_valid(board_marble_nodes[cell_id]))
	board_state[cell_id] = user_id
	last_placed_cell_id = cell_id

	if already_there:
		_update_3d_labels_and_highlights()
		return

	if is_instance_valid(board_marble_nodes[cell_id]):
		board_marble_nodes[cell_id].queue_free()
		board_marble_nodes[cell_id] = null

	# Pop one reserve marble from the player's side tray
	var reserve_arr = p1_reserve_marbles if user_id == 1 else p2_reserve_marbles
	var start_world: Vector3 = Vector3(-0.575 if user_id == 1 else 0.575, BOARD_SURFACE_Y + 0.04, 0.0)
	if not reserve_arr.is_empty():
		var popped = reserve_arr.pop_back()
		if is_instance_valid(popped):
			start_world = popped.position
			popped.queue_free()

	if user_id == 1:
		player1_pawns = max(0, player1_pawns - 1)
	else:
		player2_pawns = max(0, player2_pawns - 1)

	var q_idx: int = int(cell_id / 9)
	var q_pivot: Node3D = quadrant_pivots[q_idx]
	var dest_local: Vector3 = cell_local_positions[cell_id]
	var start_local: Vector3 = start_world - q_pivot.position
	var mid_local: Vector3 = (start_local + dest_local) * 0.5 + Vector3(0.0, 0.22, 0.0)

	var m_node = _create_marble_3d_model(user_id, false)
	m_node.position = start_local
	m_node.scale = Vector3(0.55, 0.55, 0.55)
	q_pivot.add_child(m_node)
	board_marble_nodes[cell_id] = m_node

	var tw = m_node.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m_node, "position", mid_local, 0.14)
	tw.parallel().tween_property(m_node, "scale", Vector3(1.05, 1.05, 1.05), 0.14)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m_node, "position", dest_local, 0.16)
	tw.parallel().tween_property(m_node, "scale", Vector3.ONE, 0.16)
	tw.tween_callback(func():
		AudioManager.sfx_add_piece()
		_spawn_socket_ripple_vfx(q_pivot.position + dest_local, user_id)
		_check_and_celebrate_win()
	)

	_update_3d_labels_and_highlights()

func on_peace_rotated(payload: Dictionary) -> void:
	var rot_id: int = int(payload.get("rotation_id", 1))
	var server_board = payload.get("board", [])
	is_rotation_played = true

	var q_idx: int = clampi(int((rot_id - 1) / 2), 0, 3)
	var is_ccw: bool = (rot_id % 2 == 1)
	var target_angle_y: float = (PI * 0.5) if is_ccw else (-PI * 0.5)
	last_rotated_quadrant = q_idx

	# Update authoritative board_state
	if typeof(server_board) == TYPE_ARRAY and (server_board as Array).size() >= NUM_CELLS:
		for i in range(NUM_CELLS):
			board_state[i] = int(server_board[i])
	else:
		_apply_local_quadrant_rotation(rot_id)

	if not is_instance_valid(quadrant_pivots[q_idx]):
		_rebuild_all_pieces_visual()
		_check_and_celebrate_win()
		return

	is_animating_rotation = true
	_update_3d_labels_and_highlights()
	AudioManager.sfx_move_piece()

	var q_pivot: Node3D = quadrant_pivots[q_idx]
	var base_pos: Vector3 = QUAD_CENTERS[q_idx]

	# Highlight rotating quadrant rim in glowing gold
	if q_idx < quadrant_rim_meshes.size() and is_instance_valid(quadrant_rim_meshes[q_idx]):
		quadrant_rim_meshes[q_idx].material_override = mat_gold_highlight

	var tw = q_pivot.create_tween()
	# 1. Slight mechanical lift on the brass turntable axle
	tw.tween_property(q_pivot, "position", base_pos + Vector3(0.0, 0.016, 0.0), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. Smooth 90-degree physical rotation of the entire 3x3 block + marbles
	tw.tween_property(q_pivot, "rotation:y", target_angle_y, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	# 3. Settle back down into the chassis lock
	tw.tween_property(q_pivot, "position", base_pos, 0.10).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		AudioManager.sfx_add_piece()
		is_animating_rotation = false
		_spawn_quadrant_lock_vfx(base_pos)
		_rebuild_all_pieces_visual()
		_check_and_celebrate_win()
	)

func _apply_local_quadrant_rotation(rot_id: int) -> void:
	var q_idx: int = clampi(int((rot_id - 1) / 2), 0, 3)
	var base_i: int = q_idx * 9
	var old_q: Array[int] = []
	for k in range(9):
		old_q.append(board_state[base_i + k])
	if rot_id % 2 == 1:
		# Counter-Clockwise (1, 3, 5, 7)
		board_state[base_i + 0] = old_q[2]
		board_state[base_i + 1] = old_q[5]
		board_state[base_i + 2] = old_q[8]
		board_state[base_i + 3] = old_q[1]
		board_state[base_i + 4] = old_q[4]
		board_state[base_i + 5] = old_q[7]
		board_state[base_i + 6] = old_q[0]
		board_state[base_i + 7] = old_q[3]
		board_state[base_i + 8] = old_q[6]
	else:
		# Clockwise (2, 4, 6, 8)
		board_state[base_i + 0] = old_q[6]
		board_state[base_i + 1] = old_q[3]
		board_state[base_i + 2] = old_q[0]
		board_state[base_i + 3] = old_q[7]
		board_state[base_i + 4] = old_q[4]
		board_state[base_i + 5] = old_q[1]
		board_state[base_i + 6] = old_q[8]
		board_state[base_i + 7] = old_q[5]
		board_state[base_i + 8] = old_q[2]

func _spawn_socket_ripple_vfx(world_pos: Vector3, user_id: int) -> void:
	if not is_instance_valid(fx_root):
		return
	var ring = MeshInstance3D.new()
	var r_torus = TorusMesh.new()
	r_torus.inner_radius = 0.025
	r_torus.outer_radius = 0.034
	r_torus.rings = 24
	r_torus.ring_segments = 10
	ring.mesh = r_torus
	ring.position = world_pos + Vector3(0.0, 0.005, 0.0)
	ring.scale = Vector3(0.6, 0.4, 0.6)
	ring.material_override = mat_marble_p1_gold if user_id == 1 else mat_marble_p2_plat
	fx_root.add_child(ring)

	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(1.85, 0.1, 1.85), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)

func _spawn_quadrant_lock_vfx(quad_pos: Vector3) -> void:
	if not is_instance_valid(fx_root):
		return
	var wave = MeshInstance3D.new()
	var w_torus = TorusMesh.new()
	w_torus.inner_radius = 0.14
	w_torus.outer_radius = 0.16
	w_torus.rings = 28
	w_torus.ring_segments = 10
	wave.mesh = w_torus
	wave.position = quad_pos + Vector3(0.0, 0.008, 0.0)
	wave.scale = Vector3(0.85, 0.35, 0.85)
	wave.material_override = mat_gold_highlight
	fx_root.add_child(wave)

	var tw = wave.create_tween()
	tw.tween_property(wave, "scale", Vector3(1.35, 0.08, 1.35), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(wave.queue_free)

func _check_and_celebrate_win() -> void:
	if _win_vfx_shown:
		return
	for cond in WIN_CONDITIONS:
		var first_owner: int = board_state[int(cond[0])]
		if first_owner == 0:
			continue
		var all_match: bool = true
		for idx_v in cond:
			if board_state[int(idx_v)] != first_owner:
				all_match = false
				break
		if all_match:
			_win_vfx_shown = true
			_win_vfx_started_msec = Time.get_ticks_msec()
			_update_3d_labels_and_highlights()
			_spawn_five_in_row_vfx(cond, first_owner)
			break

func _get_cell_world_pos(cell_id: int) -> Vector3:
	var q_idx: int = clampi(int(cell_id / 9), 0, 3)
	return QUAD_CENTERS[q_idx] + cell_local_positions[cell_id]

func _spawn_five_in_row_vfx(win_cells: Array, _winner_id: int) -> void:
	if win_cells.size() < 5 or not is_instance_valid(fx_root):
		return
	AudioManager.sfx_win()

	var p_start: Vector3 = _get_cell_world_pos(int(win_cells[0]))
	var p_end: Vector3 = _get_cell_world_pos(int(win_cells[win_cells.size() - 1]))
	var diff: Vector3 = p_end - p_start
	var dist: float = diff.length()
	if dist > 0.01:
		var center_pos: Vector3 = (p_start + p_end) * 0.5 + Vector3(0.0, 0.042, 0.0)
		var rot_y: float = atan2(diff.x, diff.z)

		# 1. Inner White-Gold Laser Core
		var beam = MeshInstance3D.new()
		var b_box = BoxMesh.new()
		b_box.size = Vector3(0.024, 0.018, dist + 0.08)
		beam.mesh = b_box
		beam.position = center_pos
		beam.rotation.y = rot_y
		beam.material_override = mat_win_beam_core
		fx_root.add_child(beam)

		var tw_b = beam.create_tween()
		tw_b.tween_property(beam, "scale", Vector3(1.5, 1.5, 1.04), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# 2. Outer Glowing Energy Sheath
		var sheath = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.038
		s_cyl.bottom_radius = 0.038
		s_cyl.height = dist + 0.06
		s_cyl.radial_segments = 24
		sheath.mesh = s_cyl
		sheath.position = center_pos
		sheath.rotation.y = rot_y
		sheath.rotation.x = PI * 0.5
		sheath.material_override = mat_win_beam_sheath
		fx_root.add_child(sheath)

	# 3. 5 Vertical Light Beacons & Bouncing Winning Orbs
	var idx_step: int = 0
	for cid_v in win_cells:
		var cid: int = int(cid_v)
		var w_pos: Vector3 = _get_cell_world_pos(cid)

		var pillar = MeshInstance3D.new()
		var p_cyl = CylinderMesh.new()
		p_cyl.top_radius = 0.018
		p_cyl.bottom_radius = 0.028
		p_cyl.height = 0.42
		p_cyl.radial_segments = 16
		pillar.mesh = p_cyl
		pillar.position = w_pos + Vector3(0.0, 0.21, 0.0)
		pillar.scale = Vector3(0.2, 0.1, 0.2)
		pillar.material_override = mat_win_beacon
		fx_root.add_child(pillar)

		var tw_p = pillar.create_tween()
		tw_p.tween_property(pillar, "scale", Vector3(1.2, 1.0, 1.2), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_p.tween_property(pillar, "scale", Vector3(0.08, 1.7, 0.08), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_p.tween_callback(pillar.queue_free)

		if cid >= 0 and cid < board_marble_nodes.size() and is_instance_valid(board_marble_nodes[cid]):
			var m_node = board_marble_nodes[cid]
			var base_m_pos: Vector3 = cell_local_positions[cid]
			var tw_m = m_node.create_tween()
			tw_m.tween_interval(float(idx_step) * 0.05)
			tw_m.tween_property(m_node, "position", base_m_pos + Vector3(0.0, 0.045, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_m.tween_property(m_node, "position", base_m_pos, 0.20).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		idx_step += 1

# ============================================================================
# 7. BASE_GAME_BOARD LIFECYCLE HOOKS
# ============================================================================

func setup_board(game_data: Dictionary) -> void:
	_init_board_state()
	if game_data.has("board") and typeof(game_data["board"]) == TYPE_ARRAY:
		sync_board_state(game_data["board"])
	else:
		_rebuild_all_pieces_visual()

func on_turn_changed(turn: int, active_turn: bool) -> void:
	current_turn = turn
	is_my_turn = active_turn
	is_board_locked = not active_turn
	is_selection_played = false
	is_rotation_played = false
	hovered_cell_id = -1
	hovered_rotation_id = -1
	_update_3d_labels_and_highlights()

func on_piece_selected(user_id: int, target_peace: int, _extra: Dictionary = {}) -> void:
	is_selection_played = true
	if user_id == GameManager.my_player_index:
		is_board_locked = false
	_execute_place_marble(user_id, target_peace)

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) == TYPE_ARRAY:
		var arr: Array = board_data
		for i in range(min(NUM_CELLS, arr.size())):
			board_state[i] = int(arr[i]) if arr[i] != null else 0
	if not is_animating_rotation:
		_rebuild_all_pieces_visual()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
			var arr: Array = g_data["board"]
			for i in range(min(NUM_CELLS, arr.size())):
				board_state[i] = int(arr[i]) if arr[i] != null else 0
		if g_data.has("pawns") and typeof(g_data["pawns"]) == TYPE_ARRAY and (g_data["pawns"] as Array).size() >= 2:
			player1_pawns = int(g_data["pawns"][0])
			player2_pawns = int(g_data["pawns"][1])
		is_selection_played = bool(g_data.get("selection_played", false))
		is_rotation_played = bool(g_data.get("rotation_played", false))
		if g_data.has("current_turn"):
			current_turn = int(g_data["current_turn"])
			is_my_turn = (current_turn == GameManager.my_player_index)
			is_board_locked = not is_my_turn or is_rotation_played
	is_animating_rotation = false
	_rebuild_all_pieces_visual()

func reset_board() -> void:
	_init_board_state()
	_rebuild_all_pieces_visual()

func _on_internal_game_finished(data: Dictionary) -> void:
	super._on_internal_game_finished(data)
	if GameManager.local_player_surrendered or GameManager.opponent_player_surrendered:
		return
	if not _win_vfx_shown and not is_animating_rotation:
		_check_and_celebrate_win()
	var elapsed_sec: float = float(Time.get_ticks_msec() - _win_vfx_started_msec) / 1000.0 if _win_vfx_started_msec > 0 else 0.0
	var needed_wait: float = 2.4 - elapsed_sec
	if is_animating_rotation:
		needed_wait = maxf(needed_wait, 2.5)
	if needed_wait > 0.15:
		call_deferred("_hold_result_dialog_for_win_vfx", needed_wait)

func _hold_result_dialog_for_win_vfx(wait_sec: float) -> void:
	if not is_inside_tree():
		return
	var dlg = get_tree().root.find_child("GameResultDialog", true, false)
	if dlg and dlg is CanvasItem and dlg.visible:
		dlg.visible = false
		get_tree().create_timer(wait_sec).timeout.connect(func():
			if is_instance_valid(dlg):
				dlg.visible = true
		)

func cleanup_board() -> void:
	_disconnect_pentago_signals()
	board_marble_nodes.clear()
	p1_reserve_marbles.clear()
	p2_reserve_marbles.clear()
	quadrant_pivots.clear()
	rotation_btn_nodes.clear()
	rotation_btn_halos.clear()
	rotation_btn_plate_groups.clear()
	rotation_btn_dials.clear()
	rotation_btn_glow_rings.clear()
	rotation_btn_areas.clear()
