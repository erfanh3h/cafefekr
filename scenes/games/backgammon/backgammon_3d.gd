class_name BackGammon3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# CAFE FEKR — 3D ROYAL PERSIAN BACKGAMMON (تخته نرد کافه فکر)
# ==============================================================================
# 100% Rule, State & Socket Protocol Parity with:
#   - Backend: Entities/Games/BackGammon/__init__.py & backgammon_game_session.py
#   - Flutter: lib/Feature/BackGammon/Controllers/backgammon_controller.dart
#
# Key Highlights:
#   1. Luxury Hinged Persian Walnut & 24K Gold Khatamkari Backgammon Case with
#      Recessed Velvet Courts, Brass Hinges on the Center Bar, and Carved
#      Right-Side Bear-Off Trays.
#   2. Lathe-Turned 3D Ribbed Checkers (Crimson Ruby + 24K Gold for Player 1,
#      Sapphire Cobalt + Platinum for Player 2) matching Checkers3D.
#   3. Precision-Molded 3D Yatzy-Style Ivory Dice with Flush Enamel Pips,
#      Velvet Pedestals, Glowing Selection Rings, and 3D Numeral Plaques.
#   4. Rich 3D VFX: Parabolic Hop Trajectories, Blot-Hit Explosion & Bar Launch,
#      Bear-Off Golden Ascension Burst, Doubles Celebration, and Selection Aura.
# ==============================================================================

@export var camera_distance: float = 3.25
@export var camera_pitch: float = -0.82
@export var camera_top_down_height: float = 3.55

const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")

# --- Board Geometry Constants ---
const BOARD_W: float = 1.56
const BOARD_D: float = 1.04
const BOARD_H: float = 0.032
const SURFACE_Y: float = 0.025
const PIECE_RADIUS: float = 0.036
const PIECE_HEIGHT: float = 0.015
const DIE_SIZE: float = 0.064
const MAX_DICE_SLOTS: int = 4

# Center of the playing courts (shifted slightly left to leave room for Bear-Off Tray on +X)
const BAR_X: float = -0.08
const BEAR_OFF_X: float = 0.675

# --- Game State (Exact Parity with BackGammonGameClass & BackGammonController) ---
# board_spots[0..23]: {"count": int, "equipped_user": int}
var board_spots: Array[Dictionary] = []
var current_dices: Array[int] = []
var equipped_dice_index: int = -1
var dices_rolled: bool = false
var can_select_peace: bool = false

var p1_score: int = 0
var p2_score: int = 0
var p1_out_pieces: int = 0
var p2_out_pieces: int = 0
var p1_is_in_end_phase: bool = false
var p2_is_in_end_phase: bool = false
var last_played_point: int = -99

# Computed legal move highlights for the currently selected die
var can_select_points: Array[int] = []      # Source points (0..23) selectable by player
var can_hit_points: Array[int] = []         # Destination points (0..23) when entering from bar or previewing
var can_bear_off_sources: Array[int] = []   # Source points (0..23) that bear off to 24 or -1 with selected die

# --- 3D Scene Nodes & Caches ---
var _point_positions: Array[Vector3] = []   # 24 base anchors for points 0..23
var _point_is_top: Array[bool] = []         # True for points 0..11 (top row -Z), False for 12..23 (bottom row +Z)
var _point_source_rings: Array[MeshInstance3D] = []
var _point_target_rings: Array[MeshInstance3D] = []
var _point_last_rings: Array[MeshInstance3D] = []
var _point_count_labels: Array[Label3D] = []

var _pieces_container: Node3D = null
var _point_piece_nodes: Dictionary = {}     # point_idx (0..23) -> Array[Node3D]
var _bar_p1_nodes: Array[Node3D] = []
var _bar_p2_nodes: Array[Node3D] = []
var _bear_p1_nodes: Array[Node3D] = []
var _bear_p2_nodes: Array[Node3D] = []

var _bar_p1_ring: MeshInstance3D = null
var _bar_p2_ring: MeshInstance3D = null
var _bar_p1_label: Label3D = null
var _bar_p2_label: Label3D = null

var _bear_p1_ring: MeshInstance3D = null
var _bear_p2_ring: MeshInstance3D = null
var _bear_p1_label: Label3D = null
var _bear_p2_label: Label3D = null

var _dice_nodes: Array[Dictionary] = []
var _roll_btn_ui: Dictionary = {}
var _lbl_status_3d: Label3D = null

var _vfx_time: float = 0.0
var _sparkle_accum: float = 0.0
var _is_animating_move: bool = false
var _is_rolling_dice: bool = false

# --- Shared Luxury Materials ---
var mat_wood_case: StandardMaterial3D
var mat_wood_rail: StandardMaterial3D
var mat_velvet_court: StandardMaterial3D
var mat_velvet_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_point_light: StandardMaterial3D
var mat_point_dark: StandardMaterial3D

var mat_piece_p1: StandardMaterial3D
var mat_piece_p1_well: StandardMaterial3D
var mat_piece_p2: StandardMaterial3D
var mat_piece_p2_well: StandardMaterial3D
var mat_felt_base: StandardMaterial3D

var mat_die_ivory: StandardMaterial3D
var mat_die_chamfer: StandardMaterial3D
var mat_die_selected: StandardMaterial3D
var mat_pip_red: StandardMaterial3D
var mat_pip_dark: StandardMaterial3D
var mat_die_lock_ring: StandardMaterial3D
var mat_die_badge_idle: StandardMaterial3D
var mat_die_badge_selected: StandardMaterial3D

var mat_ring_selectable: StandardMaterial3D
var mat_ring_target: StandardMaterial3D
var mat_ring_hit_danger: StandardMaterial3D
var mat_ring_last_move: StandardMaterial3D

var mat_btn_roll_active: StandardMaterial3D
var mat_btn_roll_disabled: StandardMaterial3D

# ==============================================================================
# LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	game_type = GameTypes.BACKGAMMON
	_init_materials()
	_compute_point_anchors()
	_build_3d_backgammon_board()
	_init_board_state()
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()
	super._ready()

func _process(delta: float) -> void:
	_vfx_time += delta
	_sparkle_accum += delta

	# 1. Pulse selectable source rings & gently float top checkers on selectable points
	var pulse = 0.5 + 0.5 * sin(_vfx_time * 5.2)
	var float_y = sin(_vfx_time * 4.5) * 0.0045
	if is_instance_valid(mat_ring_selectable):
		mat_ring_selectable.emission_energy_multiplier = 1.6 + 1.1 * pulse
	if is_instance_valid(mat_ring_target):
		mat_ring_target.emission_energy_multiplier = 1.5 + 1.0 * pulse
	if is_instance_valid(mat_ring_hit_danger):
		mat_ring_hit_danger.emission_energy_multiplier = 1.8 + 1.4 * pulse

	if not _is_animating_move:
		for pt in range(24):
			var is_sel = (pt in can_select_points)
			if _point_piece_nodes.has(pt):
				var arr: Array = _point_piece_nodes[pt]
				if not arr.is_empty():
					var top_piece: Node3D = arr[arr.size() - 1]
					if is_instance_valid(top_piece) and top_piece.has_meta("base_y"):
						var by: float = float(top_piece.get_meta("base_y"))
						top_piece.position.y = by + (float_y if is_sel else 0.0)

	# 2. Float selected die pointer & pulse roll button when active
	for d_idx in range(_dice_nodes.size()):
		var d_ui = _dice_nodes[d_idx]
		if d_ui["slot"].visible and not _is_rolling_dice:
			var is_eq = (d_idx == equipped_dice_index)
			var pivot: Node3D = d_ui["pivot"]
			if is_instance_valid(pivot):
				var target_y = 0.056 + (sin(_vfx_time * 5.0) * 0.004 if is_eq else 0.0)
				pivot.position.y = lerpf(pivot.position.y, target_y, 12.0 * delta)

	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var btn_root: Node3D = _roll_btn_ui["root"]
		if btn_root.visible and is_my_turn and not dices_rolled and GameManager.is_game_active:
			var s = 1.0 + 0.035 * sin(_vfx_time * 5.5)
			btn_root.scale = Vector3(s, 1.0, s)
		else:
			btn_root.scale = Vector3.ONE

	# 3. Periodic golden sparkle particles on selectable pieces (Rich Selection VFX)
	if _sparkle_accum >= 0.28 and not _is_animating_move and is_my_turn and dices_rolled:
		_sparkle_accum = 0.0
		_emit_ambient_selection_sparkles()

# ==============================================================================
# MATERIALS & POINT COORDINATE GEOMETRY
# ==============================================================================

func _init_materials() -> void:
	mat_wood_case = StandardMaterial3D.new()
	mat_wood_case.albedo_color = Color(0.18, 0.10, 0.05)
	mat_wood_case.roughness = 0.36
	mat_wood_case.metallic = 0.08

	mat_wood_rail = StandardMaterial3D.new()
	mat_wood_rail.albedo_color = Color(0.25, 0.14, 0.07)
	mat_wood_rail.roughness = 0.32
	mat_wood_rail.metallic = 0.10

	mat_velvet_court = StandardMaterial3D.new()
	mat_velvet_court.albedo_color = Color(0.07, 0.14, 0.11)
	mat_velvet_court.roughness = 0.86
	mat_velvet_court.metallic = 0.02

	mat_velvet_well = StandardMaterial3D.new()
	mat_velvet_well.albedo_color = Color(0.06, 0.09, 0.14)
	mat_velvet_well.roughness = 0.88

	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.95, 0.78, 0.28)
	mat_gold_trim.metallic = 0.92
	mat_gold_trim.roughness = 0.16
	mat_gold_trim.emission_enabled = true
	mat_gold_trim.emission = Color(0.32, 0.22, 0.04)
	mat_gold_trim.emission_energy_multiplier = 0.35

	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.88, 0.94, 1.0)
	mat_platinum_trim.metallic = 0.90
	mat_platinum_trim.roughness = 0.16
	mat_platinum_trim.emission_enabled = true
	mat_platinum_trim.emission = Color(0.15, 0.26, 0.42)
	mat_platinum_trim.emission_energy_multiplier = 0.35

	# Inlaid Triangles (Alternating Warm Ivory-Gold & Deep Persian Garnet)
	mat_point_light = StandardMaterial3D.new()
	mat_point_light.albedo_color = Color(0.88, 0.78, 0.58)
	mat_point_light.roughness = 0.34
	mat_point_light.metallic = 0.12

	mat_point_dark = StandardMaterial3D.new()
	mat_point_dark.albedo_color = Color(0.48, 0.16, 0.14)
	mat_point_dark.roughness = 0.36
	mat_point_dark.metallic = 0.12

	# Player 1 (Red - Royal Crimson Ruby Lacquer)
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.84, 0.12, 0.16)
	mat_piece_p1.metallic = 0.28
	mat_piece_p1.roughness = 0.16
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 1.0
	mat_piece_p1.clearcoat_roughness = 0.08
	mat_piece_p1.emission_enabled = true
	mat_piece_p1.emission = Color(0.32, 0.02, 0.04)
	mat_piece_p1.emission_energy_multiplier = 0.25

	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.56, 0.06, 0.09)
	mat_piece_p1_well.metallic = 0.32
	mat_piece_p1_well.roughness = 0.22

	# Player 2 (Blue - Royal Sapphire Cobalt Lacquer)
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.10, 0.44, 0.90)
	mat_piece_p2.metallic = 0.28
	mat_piece_p2.roughness = 0.16
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 1.0
	mat_piece_p2.clearcoat_roughness = 0.08
	mat_piece_p2.emission_enabled = true
	mat_piece_p2.emission = Color(0.02, 0.14, 0.36)
	mat_piece_p2.emission_energy_multiplier = 0.25

	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.05, 0.24, 0.58)
	mat_piece_p2_well.metallic = 0.32
	mat_piece_p2_well.roughness = 0.22

	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.06, 0.26, 0.14)
	mat_felt_base.roughness = 0.92

	# 3D Yatzy-Style Luxury Dice Materials
	mat_die_ivory = StandardMaterial3D.new()
	mat_die_ivory.albedo_color = Color(0.98, 0.95, 0.88)
	mat_die_ivory.roughness = 0.16
	mat_die_ivory.metallic = 0.05
	mat_die_ivory.clearcoat_enabled = true
	mat_die_ivory.clearcoat = 0.9
	mat_die_ivory.clearcoat_roughness = 0.1

	mat_die_chamfer = StandardMaterial3D.new()
	mat_die_chamfer.albedo_color = Color(0.90, 0.82, 0.65)
	mat_die_chamfer.roughness = 0.24
	mat_die_chamfer.metallic = 0.22

	mat_die_selected = StandardMaterial3D.new()
	mat_die_selected.albedo_color = Color(1.0, 0.92, 0.62)
	mat_die_selected.roughness = 0.14
	mat_die_selected.metallic = 0.25
	mat_die_selected.emission_enabled = true
	mat_die_selected.emission = Color(0.85, 0.62, 0.12)
	mat_die_selected.emission_energy_multiplier = 0.45

	mat_pip_red = StandardMaterial3D.new()
	mat_pip_red.albedo_color = Color(0.86, 0.12, 0.16)
	mat_pip_red.roughness = 0.20
	mat_pip_red.emission_enabled = true
	mat_pip_red.emission = Color(0.45, 0.04, 0.06)
	mat_pip_red.emission_energy_multiplier = 0.35

	mat_pip_dark = StandardMaterial3D.new()
	mat_pip_dark.albedo_color = Color(0.10, 0.08, 0.07)
	mat_pip_dark.roughness = 0.22

	mat_die_lock_ring = StandardMaterial3D.new()
	mat_die_lock_ring.albedo_color = Color(1.0, 0.84, 0.22)
	mat_die_lock_ring.emission_enabled = true
	mat_die_lock_ring.emission = Color(1.0, 0.78, 0.18)
	mat_die_lock_ring.emission_energy_multiplier = 2.0

	mat_die_badge_idle = StandardMaterial3D.new()
	mat_die_badge_idle.albedo_color = Color(0.10, 0.07, 0.05)
	mat_die_badge_idle.roughness = 0.40

	mat_die_badge_selected = StandardMaterial3D.new()
	mat_die_badge_selected.albedo_color = Color(0.32, 0.22, 0.05)
	mat_die_badge_selected.emission_enabled = true
	mat_die_badge_selected.emission = Color(0.65, 0.45, 0.08)
	mat_die_badge_selected.emission_energy_multiplier = 0.85

	# Highlight Rings (Selectable, Target, Hit Danger, Last Move)
	mat_ring_selectable = StandardMaterial3D.new()
	mat_ring_selectable.albedo_color = Color(1.0, 0.88, 0.25, 0.95)
	mat_ring_selectable.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_selectable.emission_enabled = true
	mat_ring_selectable.emission = Color(1.0, 0.82, 0.18)
	mat_ring_selectable.emission_energy_multiplier = 2.2

	mat_ring_target = StandardMaterial3D.new()
	mat_ring_target.albedo_color = Color(0.22, 0.98, 0.56, 0.95)
	mat_ring_target.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_target.emission_enabled = true
	mat_ring_target.emission = Color(0.15, 0.92, 0.48)
	mat_ring_target.emission_energy_multiplier = 2.0

	mat_ring_hit_danger = StandardMaterial3D.new()
	mat_ring_hit_danger.albedo_color = Color(1.0, 0.24, 0.28, 0.96)
	mat_ring_hit_danger.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_hit_danger.emission_enabled = true
	mat_ring_hit_danger.emission = Color(1.0, 0.16, 0.20)
	mat_ring_hit_danger.emission_energy_multiplier = 2.4

	mat_ring_last_move = StandardMaterial3D.new()
	mat_ring_last_move.albedo_color = Color(0.95, 0.78, 0.30, 0.72)
	mat_ring_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_last_move.emission_enabled = true
	mat_ring_last_move.emission = Color(0.85, 0.65, 0.20)
	mat_ring_last_move.emission_energy_multiplier = 0.9

	mat_btn_roll_active = StandardMaterial3D.new()
	mat_btn_roll_active.albedo_color = Color(0.12, 0.46, 0.24)
	mat_btn_roll_active.roughness = 0.28
	mat_btn_roll_active.emission_enabled = true
	mat_btn_roll_active.emission = Color(0.08, 0.38, 0.18)
	mat_btn_roll_active.emission_energy_multiplier = 0.75

	mat_btn_roll_disabled = StandardMaterial3D.new()
	mat_btn_roll_disabled.albedo_color = Color(0.18, 0.14, 0.12)
	mat_btn_roll_disabled.roughness = 0.65

func _compute_point_anchors() -> void:
	_point_positions.clear()
	_point_is_top.clear()

	# Right Court X range: [BAR_X + 0.095 .. +0.525], 6 columns spaced by 0.084m
	# Left Court X range:  [-0.635 .. BAR_X - 0.095], 6 columns spaced by 0.084m
	var spacing_x: float = 0.084
	var right_outer_x: float = 0.505     # Point 0 & Point 23 (near Bear-Off Tray)
	var left_inner_x: float = BAR_X - 0.095  # Point 6 & Point 17 (next to Center Bar)

	for i in range(24):
		var px: float = 0.0
		var pz: float = 0.0
		var is_top: bool = false
		if i >= 0 and i <= 5:
			# Top-Right Quadrant (0..5 right-to-left towards bar)
			is_top = true
			px = right_outer_x - float(i) * spacing_x
			pz = -0.44
		elif i >= 6 and i <= 11:
			# Top-Left Quadrant (6..11 right-to-left from bar to left edge)
			is_top = true
			px = left_inner_x - float(i - 6) * spacing_x
			pz = -0.44
		elif i >= 12 and i <= 17:
			# Bottom-Left Quadrant (12..17 left-to-right from left edge to bar)
			is_top = false
			var col_from_bar = 5 - (i - 12)
			px = left_inner_x - float(col_from_bar) * spacing_x
			pz = 0.44
		else:
			# Bottom-Right Quadrant (18..23 left-to-right from bar to right edge)
			is_top = false
			var col_from_right = 5 - (i - 18)
			px = right_outer_x - float(col_from_right) * spacing_x
			pz = 0.44

		_point_positions.append(Vector3(px, SURFACE_Y, pz))
		_point_is_top.append(is_top)

# ==============================================================================
# 3D BACKGAMMON BOARD CONSTRUCTION
# ==============================================================================

func _build_3d_backgammon_board() -> void:
	# 1. Main Walnut Plinth Base
	var base_plinth = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = Vector3(BOARD_W, 0.024, BOARD_D)
	base_plinth.mesh = base_box
	base_plinth.material_override = mat_wood_case
	base_plinth.position = Vector3(0.0, 0.012, 0.0)
	add_child(base_plinth)

	# 2. Recessed Playing Courts (Left Court & Right Court)
	var left_court = MeshInstance3D.new()
	var lc_box = BoxMesh.new()
	lc_box.size = Vector3(0.54, 0.004, 0.90)
	left_court.mesh = lc_box
	left_court.material_override = mat_velvet_court
	left_court.position = Vector3(-0.385, SURFACE_Y - 0.001, 0.0)
	add_child(left_court)

	var right_court = MeshInstance3D.new()
	var rc_box = BoxMesh.new()
	rc_box.size = Vector3(0.54, 0.004, 0.90)
	right_court.mesh = rc_box
	right_court.material_override = mat_velvet_court
	right_court.position = Vector3(0.295, SURFACE_Y - 0.001, 0.0)
	add_child(right_court)

	# 3. Outer Raised Wooden Rails + Gold Trim
	_build_outer_rails_and_bar()

	# 4. Right-Side Bear-Off Trays (Player 2 Top-Right [-1], Player 1 Bottom-Right [24])
	_build_bear_off_trays()

	# 5. The 24 Inlaid Triangular Points + Number Plaques + Highlight Rings + Area3Ds
	_build_24_points()

	# 6. Center Bar Checkers Pedestals & Clickable Area3Ds
	_build_bar_zones()

	# 7. Central Dice Court (4 Yatzy-Style 3D Dice Wells + 3D Roll Dice Button)
	_build_dice_and_roll_console()

	# 8. Dynamic Pieces Container
	_pieces_container = Node3D.new()
	_pieces_container.name = "PiecesContainer"
	add_child(_pieces_container)

func _build_outer_rails_and_bar() -> void:
	var rail_h: float = 0.046
	var rail_y: float = rail_h * 0.5

	# Top Rail (-Z), Bottom Rail (+Z), Left Rail (-X), Right Rail (+X), Divider Rail before Bear-Off Tray
	var rails = [
		{"pos": Vector3(0.0, rail_y, -0.485), "size": Vector3(BOARD_W, rail_h, 0.07)},
		{"pos": Vector3(0.0, rail_y, 0.485), "size": Vector3(BOARD_W, rail_h, 0.07)},
		{"pos": Vector3(-0.715, rail_y, 0.0), "size": Vector3(0.09, rail_h, BOARD_D)},
		{"pos": Vector3(0.745, rail_y, 0.0), "size": Vector3(0.07, rail_h, BOARD_D)},
		{"pos": Vector3(0.590, rail_y, 0.0), "size": Vector3(0.04, rail_h, 0.92)},
		# Hinged Center Bar (X = BAR_X)
		{"pos": Vector3(BAR_X, rail_y, 0.0), "size": Vector3(0.09, rail_h + 0.004, 0.92)},
	]
	for r in rails:
		var rm = MeshInstance3D.new()
		var rbox = BoxMesh.new()
		rbox.size = r["size"]
		rm.mesh = rbox
		rm.material_override = mat_wood_rail
		rm.position = r["pos"]
		add_child(rm)

		# Gold upper trim strip along each rail
		var tm = MeshInstance3D.new()
		var tbox = BoxMesh.new()
		tbox.size = Vector3(r["size"].x * 0.96, 0.003, r["size"].z * 0.96)
		tm.mesh = tbox
		tm.material_override = mat_gold_trim
		tm.position = r["pos"] + Vector3(0, r["size"].y * 0.5 + 0.001, 0)
		add_child(tm)

	# Two Ornate Brass Barrel Hinges on the Center Bar
	for hz in [-0.36, 0.36]:
		var hinge = MeshInstance3D.new()
		var h_cyl = CylinderMesh.new()
		h_cyl.top_radius = 0.014
		h_cyl.bottom_radius = 0.014
		h_cyl.height = 0.055
		hinge.mesh = h_cyl
		hinge.material_override = mat_gold_trim
		hinge.rotation_degrees = Vector3(90, 0, 0)
		hinge.position = Vector3(BAR_X, rail_h + 0.004, hz)
		add_child(hinge)

	# 3D Status Banner Label on Front Rail (+Z)
	_lbl_status_3d = _create_3d_label("🎲 تخته نرد کافه فکر", 26, Color(1.0, 0.92, 0.62))
	_lbl_status_3d.position = Vector3(-0.04, rail_h + 0.008, 0.486)
	add_child(_lbl_status_3d)

func _build_bear_off_trays() -> void:
	# Top Bear-Off Well (Player 2 Blue - destination -1)
	var p2_well = MeshInstance3D.new()
	var w2_box = BoxMesh.new()
	w2_box.size = Vector3(0.11, 0.010, 0.38)
	p2_well.mesh = w2_box
	p2_well.material_override = mat_velvet_well
	p2_well.position = Vector3(BEAR_OFF_X, SURFACE_Y + 0.002, -0.23)
	add_child(p2_well)

	_bear_p2_ring = MeshInstance3D.new()
	var r2_box = BoxMesh.new()
	r2_box.size = Vector3(0.118, 0.014, 0.39)
	_bear_p2_ring.mesh = r2_box
	_bear_p2_ring.material_override = mat_ring_target
	_bear_p2_ring.position = Vector3(BEAR_OFF_X, SURFACE_Y + 0.006, -0.23)
	_bear_p2_ring.visible = false
	add_child(_bear_p2_ring)

	_bear_p2_label = _create_3d_label("آبی: ۰/۱۵", 21, Color(0.62, 0.86, 1.0))
	_bear_p2_label.position = Vector3(BEAR_OFF_X, 0.052, -0.445)
	add_child(_bear_p2_label)

	var area_b2 = Area3D.new()
	area_b2.name = "BearOffArea_2"
	area_b2.set_meta("hit_type", "bear_off")
	area_b2.set_meta("gamer_id", 2)
	var col_b2 = CollisionShape3D.new()
	var shp_b2 = BoxShape3D.new()
	shp_b2.size = Vector3(0.14, 0.12, 0.42)
	col_b2.shape = shp_b2
	area_b2.add_child(col_b2)
	area_b2.position = Vector3(BEAR_OFF_X, 0.05, -0.23)
	add_child(area_b2)

	# Bottom Bear-Off Well (Player 1 Red - destination 24)
	var p1_well = MeshInstance3D.new()
	var w1_box = BoxMesh.new()
	w1_box.size = Vector3(0.11, 0.010, 0.38)
	p1_well.mesh = w1_box
	p1_well.material_override = mat_velvet_well
	p1_well.position = Vector3(BEAR_OFF_X, SURFACE_Y + 0.002, 0.23)
	add_child(p1_well)

	_bear_p1_ring = MeshInstance3D.new()
	var r1_box = BoxMesh.new()
	r1_box.size = Vector3(0.118, 0.014, 0.39)
	_bear_p1_ring.mesh = r1_box
	_bear_p1_ring.material_override = mat_ring_target
	_bear_p1_ring.position = Vector3(BEAR_OFF_X, SURFACE_Y + 0.006, 0.23)
	_bear_p1_ring.visible = false
	add_child(_bear_p1_ring)

	_bear_p1_label = _create_3d_label("قرمز: ۰/۱۵", 21, Color(1.0, 0.65, 0.65))
	_bear_p1_label.position = Vector3(BEAR_OFF_X, 0.052, 0.445)
	add_child(_bear_p1_label)

	var area_b1 = Area3D.new()
	area_b1.name = "BearOffArea_1"
	area_b1.set_meta("hit_type", "bear_off")
	area_b1.set_meta("gamer_id", 1)
	var col_b1 = CollisionShape3D.new()
	var shp_b1 = BoxShape3D.new()
	shp_b1.size = Vector3(0.14, 0.12, 0.42)
	col_b1.shape = shp_b1
	area_b1.add_child(col_b1)
	area_b1.position = Vector3(BEAR_OFF_X, 0.05, 0.23)
	add_child(area_b1)

func _build_24_points() -> void:
	_point_source_rings.clear()
	_point_target_rings.clear()
	_point_last_rings.clear()
	_point_count_labels.clear()

	var tri_half_w: float = 0.038
	var tri_len: float = 0.355

	for i in range(24):
		var anchor: Vector3 = _point_positions[i]
		var is_top: bool = _point_is_top[i]
		var dir_z: float = 1.0 if is_top else -1.0

		# 1. Custom 3D Extruded Triangle Mesh
		var tri_mesh_inst = MeshInstance3D.new()
		tri_mesh_inst.name = "PointTriangle_%d" % i
		tri_mesh_inst.mesh = _create_point_triangle_mesh(tri_half_w, tri_len, 0.0035, dir_z)
		tri_mesh_inst.material_override = mat_point_light if (i % 2 == 0) else mat_point_dark
		tri_mesh_inst.position = anchor
		add_child(tri_mesh_inst)

		# 2. Point Index Label (1..24 in Persian numerals) on the rail edge
		var num_lbl = _create_3d_label(_fa_digits(i + 1), 18, Color(0.92, 0.82, 0.58))
		num_lbl.position = Vector3(anchor.x, 0.051, -0.462 if is_top else 0.462)
		add_child(num_lbl)

		# 3. Source Selection Ring (Glowing Gold Torus at first checker slot)
		var src_ring = MeshInstance3D.new()
		var s_tor = TorusMesh.new()
		s_tor.inner_radius = 0.035
		s_tor.outer_radius = 0.043
		src_ring.mesh = s_tor
		src_ring.material_override = mat_ring_selectable
		src_ring.position = Vector3(anchor.x, SURFACE_Y + 0.005, anchor.z + dir_z * 0.042)
		src_ring.visible = false
		add_child(src_ring)
		_point_source_rings.append(src_ring)

		# 4. Target Destination Ring (Glowing Emerald or Crimson Hit Ring near point tip/landing)
		var tgt_ring = MeshInstance3D.new()
		var t_tor = TorusMesh.new()
		t_tor.inner_radius = 0.034
		t_tor.outer_radius = 0.043
		tgt_ring.mesh = t_tor
		tgt_ring.material_override = mat_ring_target
		tgt_ring.position = Vector3(anchor.x, SURFACE_Y + 0.005, anchor.z + dir_z * 0.14)
		tgt_ring.visible = false
		add_child(tgt_ring)
		_point_target_rings.append(tgt_ring)

		# 5. Last Move Indicator Ring
		var last_ring = MeshInstance3D.new()
		var l_tor = TorusMesh.new()
		l_tor.inner_radius = 0.036
		l_tor.outer_radius = 0.041
		last_ring.mesh = l_tor
		last_ring.material_override = mat_ring_last_move
		last_ring.position = Vector3(anchor.x, SURFACE_Y + 0.003, anchor.z + dir_z * 0.042)
		last_ring.visible = false
		add_child(last_ring)
		_point_last_rings.append(last_ring)

		# 6. Stack Count Badge Label (Shown when count >= 2)
		var cnt_lbl = _create_3d_label("", 23, Color(1.0, 0.96, 0.78))
		cnt_lbl.position = Vector3(anchor.x, SURFACE_Y + 0.045, anchor.z + dir_z * 0.042)
		cnt_lbl.visible = false
		add_child(cnt_lbl)
		_point_count_labels.append(cnt_lbl)

		# 7. Clickable Area3D covering the entire Point Column
		var pt_area = Area3D.new()
		pt_area.name = "PointArea_%d" % i
		pt_area.set_meta("hit_type", "point")
		pt_area.set_meta("point_index", i)
		var pt_col = CollisionShape3D.new()
		var pt_shape = BoxShape3D.new()
		pt_shape.size = Vector3(0.082, 0.12, 0.38)
		pt_col.shape = pt_shape
		pt_area.add_child(pt_col)
		pt_area.position = Vector3(anchor.x, SURFACE_Y + 0.04, anchor.z + dir_z * 0.18)
		add_child(pt_area)

func _create_point_triangle_mesh(half_w: float, length: float, height: float, dir_z: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var p_left = Vector3(-half_w, height, 0.0)
	var p_right = Vector3(half_w, height, 0.0)
	var p_tip = Vector3(0.0, height, dir_z * length)

	st.set_normal(Vector3.UP)
	if dir_z > 0.0:
		st.add_vertex(p_left)
		st.add_vertex(p_right)
		st.add_vertex(p_tip)
	else:
		st.add_vertex(p_right)
		st.add_vertex(p_left)
		st.add_vertex(p_tip)

	return st.commit()

func _build_bar_zones() -> void:
	# Player 1 Bar Zone (Upper Bar: Z = -0.18, enters at points 0..5)
	_bar_p1_ring = MeshInstance3D.new()
	var tor1 = TorusMesh.new()
	tor1.inner_radius = 0.036
	tor1.outer_radius = 0.045
	_bar_p1_ring.mesh = tor1
	_bar_p1_ring.material_override = mat_ring_selectable
	_bar_p1_ring.position = Vector3(BAR_X, 0.052, -0.18)
	_bar_p1_ring.visible = false
	add_child(_bar_p1_ring)

	_bar_p1_label = _create_3d_label("", 22, Color(1.0, 0.80, 0.80))
	_bar_p1_label.position = Vector3(BAR_X, 0.095, -0.18)
	_bar_p1_label.visible = false
	add_child(_bar_p1_label)

	var bar_area_1 = Area3D.new()
	bar_area_1.name = "BarArea_1"
	bar_area_1.set_meta("hit_type", "bar")
	bar_area_1.set_meta("gamer_id", 1)
	var col1 = CollisionShape3D.new()
	var shp1 = BoxShape3D.new()
	shp1.size = Vector3(0.10, 0.14, 0.24)
	col1.shape = shp1
	bar_area_1.add_child(col1)
	bar_area_1.position = Vector3(BAR_X, 0.06, -0.18)
	add_child(bar_area_1)

	# Player 2 Bar Zone (Lower Bar: Z = +0.18, enters at points 18..23)
	_bar_p2_ring = MeshInstance3D.new()
	var tor2 = TorusMesh.new()
	tor2.inner_radius = 0.036
	tor2.outer_radius = 0.045
	_bar_p2_ring.mesh = tor2
	_bar_p2_ring.material_override = mat_ring_selectable
	_bar_p2_ring.position = Vector3(BAR_X, 0.052, 0.18)
	_bar_p2_ring.visible = false
	add_child(_bar_p2_ring)

	_bar_p2_label = _create_3d_label("", 22, Color(0.75, 0.90, 1.0))
	_bar_p2_label.position = Vector3(BAR_X, 0.095, 0.18)
	_bar_p2_label.visible = false
	add_child(_bar_p2_label)

	var bar_area_2 = Area3D.new()
	bar_area_2.name = "BarArea_2"
	bar_area_2.set_meta("hit_type", "bar")
	bar_area_2.set_meta("gamer_id", 2)
	var col2 = CollisionShape3D.new()
	var shp2 = BoxShape3D.new()
	shp2.size = Vector3(0.10, 0.14, 0.24)
	col2.shape = shp2
	bar_area_2.add_child(col2)
	bar_area_2.position = Vector3(BAR_X, 0.06, 0.18)
	add_child(bar_area_2)

# ==============================================================================
# YATZY-STYLE 3D LUXURY DICE & 3D ROLL BUTTON CONSOLE
# ==============================================================================

func _build_dice_and_roll_console() -> void:
	# 1. 3D Roll Dice Button in Left Court Center (Vector3(-0.385, SURFACE_Y, 0.0))
	_roll_btn_ui = _build_3d_roll_button(Vector3(-0.385, SURFACE_Y + 0.002, 0.0))

	# 2. 4 Yatzy-Style 3D Dice Slots in Right Court Center (around X = 0.295, Z = 0.0)
	_dice_nodes.clear()
	for d_idx in range(MAX_DICE_SLOTS):
		var slot_pos = Vector3(0.11 + float(d_idx) * 0.125, SURFACE_Y + 0.002, -0.015)
		var d_ui = _build_single_3d_die(d_idx, slot_pos)
		_dice_nodes.append(d_ui)

func _build_3d_roll_button(pos: Vector3) -> Dictionary:
	var root = Node3D.new()
	root.name = "RollDiceButton3D"
	root.position = pos
	add_child(root)

	var frame = MeshInstance3D.new()
	var f_box = BoxMesh.new()
	f_box.size = Vector3(0.28, 0.016, 0.105)
	frame.mesh = f_box
	frame.material_override = mat_gold_trim
	frame.position = Vector3(0, 0.008, 0)
	root.add_child(frame)

	var cap = MeshInstance3D.new()
	var c_box = BoxMesh.new()
	c_box.size = Vector3(0.264, 0.020, 0.090)
	cap.mesh = c_box
	cap.material_override = mat_btn_roll_active
	cap.position = Vector3(0, 0.013, 0)
	root.add_child(cap)

	var lbl = _create_3d_label("🎲 پرتاب تاس", 28, Color(1.0, 0.97, 0.86))
	lbl.position = Vector3(0, 0.026, 0)
	root.add_child(lbl)

	var area = Area3D.new()
	area.name = "RollDiceBtnArea"
	area.set_meta("hit_type", "roll_btn")
	var col = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = Vector3(0.30, 0.08, 0.13)
	col.shape = shp
	area.add_child(col)
	area.position = Vector3(0, 0.025, 0)
	root.add_child(area)

	return {"root": root, "cap": cap, "label": lbl}

func _build_single_3d_die(die_idx: int, slot_pos: Vector3) -> Dictionary:
	var slot_root = Node3D.new()
	slot_root.name = "DieSlot_%d" % die_idx
	slot_root.position = slot_pos
	add_child(slot_root)

	# 1. Carved Velvet & Brass Dice Well Pedestal
	var well_rim = MeshInstance3D.new()
	var wr_cyl = CylinderMesh.new()
	wr_cyl.top_radius = 0.048
	wr_cyl.bottom_radius = 0.052
	wr_cyl.height = 0.005
	well_rim.mesh = wr_cyl
	well_rim.material_override = mat_gold_trim
	well_rim.position = Vector3(0, 0.0025, 0)
	slot_root.add_child(well_rim)

	var well_bed = MeshInstance3D.new()
	var wb_cyl = CylinderMesh.new()
	wb_cyl.top_radius = 0.044
	wb_cyl.bottom_radius = 0.044
	wb_cyl.height = 0.006
	well_bed.mesh = wb_cyl
	well_bed.material_override = mat_velvet_well
	well_bed.position = Vector3(0, 0.0035, 0)
	slot_root.add_child(well_bed)

	# 2. Glowing Gold Selection Ring Pedestal (Visible when die is Selected!)
	var lock_ring = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.053
	cyl.bottom_radius = 0.057
	cyl.height = 0.011
	lock_ring.mesh = cyl
	lock_ring.material_override = mat_die_lock_ring
	lock_ring.position = Vector3(0, 0.006, 0)
	lock_ring.visible = false
	slot_root.add_child(lock_ring)

	# 3. 3D Die Pivot (Rotates so top face matches current_dices[die_idx])
	var die_pivot = Node3D.new()
	die_pivot.name = "DiePivot"
	die_pivot.position = Vector3(0, 0.044, 0)
	slot_root.add_child(die_pivot)

	var chamfer_core = MeshInstance3D.new()
	var core_box = BoxMesh.new()
	core_box.size = Vector3(DIE_SIZE * 0.94, DIE_SIZE * 0.94, DIE_SIZE * 0.94)
	chamfer_core.mesh = core_box
	chamfer_core.material_override = mat_die_chamfer
	die_pivot.add_child(chamfer_core)

	var face_meshes: Array[MeshInstance3D] = []
	for slab_size in [
		Vector3(DIE_SIZE, DIE_SIZE * 0.86, DIE_SIZE * 0.86),
		Vector3(DIE_SIZE * 0.86, DIE_SIZE, DIE_SIZE * 0.86),
		Vector3(DIE_SIZE * 0.86, DIE_SIZE * 0.86, DIE_SIZE),
	]:
		var slab_inst = MeshInstance3D.new()
		var slab_box = BoxMesh.new()
		slab_box.size = slab_size
		slab_inst.mesh = slab_box
		slab_inst.material_override = mat_die_ivory
		die_pivot.add_child(slab_inst)
		face_meshes.append(slab_inst)

	_add_3d_die_pips(die_pivot, DIE_SIZE * 0.5)

	# 4. Framed 3D Brass & Obsidian Numeral Plaque below each die well
	var badge_rim = MeshInstance3D.new()
	var br_box = BoxMesh.new()
	br_box.size = Vector3(0.088, 0.005, 0.042)
	badge_rim.mesh = br_box
	badge_rim.material_override = mat_gold_trim
	badge_rim.position = Vector3(0, 0.003, 0.082)
	slot_root.add_child(badge_rim)

	var badge_cap = MeshInstance3D.new()
	var bc_box = BoxMesh.new()
	bc_box.size = Vector3(0.080, 0.008, 0.035)
	badge_cap.mesh = bc_box
	badge_cap.material_override = mat_die_badge_idle
	badge_cap.position = Vector3(0, 0.005, 0.082)
	slot_root.add_child(badge_cap)

	var val_lbl = _create_3d_label("۱", 22, Color(1.0, 0.96, 0.86))
	val_lbl.position = Vector3(0, 0.011, 0.082)
	slot_root.add_child(val_lbl)

	# 5. Clickable Area3D for Selecting this Die
	var die_area = Area3D.new()
	die_area.name = "DieArea_%d" % die_idx
	die_area.set_meta("hit_type", "die")
	die_area.set_meta("die_index", die_idx)
	var die_col = CollisionShape3D.new()
	var die_shape = BoxShape3D.new()
	die_shape.size = Vector3(0.115, 0.14, 0.16)
	die_col.shape = die_shape
	die_area.add_child(die_col)
	die_area.position = Vector3(0, 0.045, 0.02)
	slot_root.add_child(die_area)

	return {
		"slot": slot_root,
		"pivot": die_pivot,
		"chamfer": chamfer_core,
		"slabs": face_meshes,
		"lock_ring": lock_ring,
		"badge_cap": badge_cap,
		"label": val_lbl,
	}

func _add_3d_die_pips(die_pivot: Node3D, half_s: float) -> void:
	var o: float = half_s * 0.54
	var face_configs = [
		{"normal": Vector3.UP, "right": Vector3.RIGHT, "fwd": Vector3.BACK, "rot_deg": Vector3(0, 0, 0), "pips": [Vector2(0, 0)], "red": true, "big": true},
		{"normal": Vector3.DOWN, "right": Vector3.RIGHT, "fwd": Vector3.FORWARD, "rot_deg": Vector3(0, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.BACK, "right": Vector3.RIGHT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.FORWARD, "right": Vector3.LEFT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.RIGHT, "right": Vector3.FORWARD, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [
			Vector2(-o, -o), Vector2(0, 0), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.LEFT, "right": Vector3.BACK, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)
		], "red": true, "big": false},
	]
	for fc in face_configs:
		var n: Vector3 = fc["normal"]
		var r: Vector3 = fc["right"]
		var f: Vector3 = fc["fwd"]
		var rot_d: Vector3 = fc["rot_deg"]
		var is_red: bool = fc["red"]
		var is_big: bool = fc["big"]
		var rad: float = 0.0085 if is_big else 0.0054
		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = rad
			cyl.bottom_radius = rad
			cyl.height = 0.0018
			cyl.radial_segments = 16
			pip.mesh = cyl
			pip.material_override = mat_pip_red if is_red else mat_pip_dark
			pip.rotation_degrees = rot_d
			pip.position = n * (half_s + 0.0004) + r * p2.x + f * p2.y
			die_pivot.add_child(pip)

func _get_die_target_rotation(val: int) -> Vector3:
	match val:
		1: return Vector3(0.0, 0.0, 0.0)
		2: return Vector3(-PI * 0.5, 0.0, 0.0)
		3: return Vector3(0.0, 0.0, PI * 0.5)
		4: return Vector3(0.0, 0.0, -PI * 0.5)
		5: return Vector3(PI * 0.5, 0.0, 0.0)
		6: return Vector3(PI, 0.0, 0.0)
		_: return Vector3.ZERO

# ==============================================================================
# 3D TOURNAMENT CHECKERS PIECE BUILDER (Ported from Checkers3D)
# ==============================================================================

func _build_3d_checker_piece(gamer_id: int) -> Node3D:
	var root = Node3D.new()
	root.set_meta("gamer_id", gamer_id)

	var mat_main = mat_piece_p1 if gamer_id == 1 else mat_piece_p2
	var mat_well = mat_piece_p1_well if gamer_id == 1 else mat_piece_p2_well
	var mat_trim = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. Weighted Velvet Green Felt Base Pad
	var felt_pad = MeshInstance3D.new()
	var cyl_felt = CylinderMesh.new()
	cyl_felt.top_radius = PIECE_RADIUS
	cyl_felt.bottom_radius = PIECE_RADIUS
	cyl_felt.height = 0.0016
	cyl_felt.radial_segments = 32
	felt_pad.mesh = cyl_felt
	felt_pad.material_override = mat_felt_base
	felt_pad.position.y = 0.0008
	root.add_child(felt_pad)

	# 2. Lower Beveled Gold/Platinum Plinth Ring
	var lower_ring = MeshInstance3D.new()
	var torus_low = TorusMesh.new()
	torus_low.inner_radius = PIECE_RADIUS * 0.90
	torus_low.outer_radius = PIECE_RADIUS * 1.03
	torus_low.rings = 28
	torus_low.ring_segments = 20
	lower_ring.mesh = torus_low
	lower_ring.material_override = mat_trim
	lower_ring.position.y = 0.0025
	root.add_child(lower_ring)

	# 3. Main Cylindrical Puck Body
	var body = MeshInstance3D.new()
	var cyl_body = CylinderMesh.new()
	cyl_body.top_radius = PIECE_RADIUS * 0.98
	cyl_body.bottom_radius = PIECE_RADIUS
	cyl_body.height = PIECE_HEIGHT
	cyl_body.radial_segments = 36
	body.mesh = cyl_body
	body.material_override = mat_main
	body.position.y = 0.008
	root.add_child(body)

	# 4. Recessed Inner Well Dish
	var dish = MeshInstance3D.new()
	var cyl_dish = CylinderMesh.new()
	cyl_dish.top_radius = PIECE_RADIUS * 0.78
	cyl_dish.bottom_radius = PIECE_RADIUS * 0.78
	cyl_dish.height = 0.0018
	cyl_dish.radial_segments = 32
	dish.mesh = cyl_dish
	dish.material_override = mat_well
	dish.position.y = 0.0152
	root.add_child(dish)

	# 5. Raised Outer Gripping Rim (Torus)
	var outer_rim = MeshInstance3D.new()
	var torus_rim = TorusMesh.new()
	torus_rim.inner_radius = PIECE_RADIUS * 0.77
	torus_rim.outer_radius = PIECE_RADIUS * 0.99
	torus_rim.rings = 32
	torus_rim.ring_segments = 20
	outer_rim.mesh = torus_rim
	outer_rim.material_override = mat_main
	outer_rim.position.y = 0.0152
	root.add_child(outer_rim)

	# 6. 12 Radial Tactile Grip Ridges around Outer Rim
	var notch_mesh = BoxMesh.new()
	notch_mesh.size = Vector3(0.0026, 0.0030, 0.0062)
	for i in range(12):
		var angle = (float(i) / 12.0) * TAU
		var notch = MeshInstance3D.new()
		notch.mesh = notch_mesh
		notch.material_override = mat_main
		var r_pos = PIECE_RADIUS * 0.88
		notch.position = Vector3(r_pos * cos(angle), 0.0170, r_pos * sin(angle))
		notch.rotation.y = -angle + PI * 0.5
		root.add_child(notch)

	# 7. Concentric 24K Gold / Platinum Inlay Ring inside the Dish
	var mid_gold_ring = MeshInstance3D.new()
	var torus_mid = TorusMesh.new()
	torus_mid.inner_radius = PIECE_RADIUS * 0.50
	torus_mid.outer_radius = PIECE_RADIUS * 0.60
	torus_mid.rings = 28
	torus_mid.ring_segments = 18
	mid_gold_ring.mesh = torus_mid
	mid_gold_ring.material_override = mat_trim
	mid_gold_ring.position.y = 0.0158
	root.add_child(mid_gold_ring)

	# 8. Center Medallion Boss
	var boss = MeshInstance3D.new()
	var cyl_boss = CylinderMesh.new()
	cyl_boss.top_radius = PIECE_RADIUS * 0.20
	cyl_boss.bottom_radius = PIECE_RADIUS * 0.22
	cyl_boss.height = 0.0026
	cyl_boss.radial_segments = 20
	boss.mesh = cyl_boss
	boss.material_override = mat_trim
	boss.position.y = 0.0162
	root.add_child(boss)

	return root

# ==============================================================================
# PURE GAME LOGIC & RULES ENGINE (100% Backend + Flutter Parity)
# ==============================================================================

func _init_board_state() -> void:
	board_spots.clear()
	for _i in range(24):
		board_spots.append({"count": 0, "equipped_user": 0})

	# Standard Backgammon Initial Setup (Matches BackGammonGameClass.init_board)
	_set_spot(0, 1, 2)
	_set_spot(23, 2, 2)
	_set_spot(5, 2, 5)
	_set_spot(18, 1, 5)
	_set_spot(7, 2, 3)
	_set_spot(16, 1, 3)
	_set_spot(11, 1, 5)
	_set_spot(12, 2, 5)

	current_dices.clear()
	equipped_dice_index = -1
	dices_rolled = false
	can_select_peace = false
	p1_score = 0
	p2_score = 0
	p1_out_pieces = 0
	p2_out_pieces = 0
	p1_is_in_end_phase = false
	p2_is_in_end_phase = false
	last_played_point = -99

func _set_spot(idx: int, gamer_id: int, cnt: int) -> void:
	if idx >= 0 and idx < 24:
		board_spots[idx] = {"count": cnt, "equipped_user": gamer_id if cnt > 0 else 0}

func _check_gamer_is_in_end_phase(gamer_id: int) -> void:
	if gamer_id == 1:
		var total = p1_score
		for pt in range(18, 24):
			if int(board_spots[pt]["equipped_user"]) == 1:
				total += int(board_spots[pt]["count"])
		p1_is_in_end_phase = (total == 15)
	else:
		var total = p2_score
		for pt in range(0, 6):
			if int(board_spots[pt]["equipped_user"]) == 2:
				total += int(board_spots[pt]["count"])
		p2_is_in_end_phase = (total == 15)

func _check_gamer_piece_is_out(gamer_id: int) -> bool:
	if gamer_id == 1 and p1_out_pieces > 0:
		return true
	if gamer_id == 2 and p2_out_pieces > 0:
		return true
	return false

func _is_valid_index(idx: int) -> bool:
	return idx >= 0 and idx < 24

func _is_valid_index_in_end_phase(idx: int, gamer_id: int) -> bool:
	if gamer_id == 1:
		return idx >= 0 and idx <= 24
	if gamer_id == 2:
		return idx >= -1 and idx < 24
	return false

func _is_enemy_spot(idx: int, gamer_id: int) -> bool:
	if idx < 0 or idx >= 24:
		return false
	var owner = int(board_spots[idx]["equipped_user"])
	return owner != 0 and owner != gamer_id

func _is_single_spot(idx: int) -> bool:
	if idx < 0 or idx >= 24:
		return false
	return int(board_spots[idx]["count"]) == 1

func _check_source_can_move_n_count(source_idx: int, dice_val: int, gamer_id: int) -> bool:
	var multiple: int = 1 if gamer_id == 1 else -1
	var destination: int = source_idx + (dice_val * multiple)
	var is_in_end: bool = p1_is_in_end_phase if gamer_id == 1 else p2_is_in_end_phase

	if is_in_end:
		if not _is_valid_index_in_end_phase(destination, gamer_id):
			return false
		if destination != -1 and destination != 24 and _is_enemy_spot(destination, gamer_id) and not _is_single_spot(destination):
			return false
	else:
		if not _is_valid_index(destination):
			return false
		if _is_enemy_spot(destination, gamer_id) and not _is_single_spot(destination):
			return false
	return true

func _get_my_piece_indexes(gamer_id: int) -> Array[int]:
	var res: Array[int] = []
	for i in range(24):
		if int(board_spots[i]["equipped_user"]) == gamer_id and int(board_spots[i]["count"]) > 0:
			res.append(i)
	return res

func _has_available_move_for_die(dice_val: int, gamer_id: int) -> bool:
	if _check_gamer_piece_is_out(gamer_id):
		var bar_idx = -1 if gamer_id == 1 else 24
		return _check_source_can_move_n_count(bar_idx, dice_val, gamer_id)
	else:
		for pt in _get_my_piece_indexes(gamer_id):
			if _check_source_can_move_n_count(pt, dice_val, gamer_id):
				return true
	return false

func _has_any_available_move(gamer_id: int) -> bool:
	for d in current_dices:
		if _has_available_move_for_die(d, gamer_id):
			return true
	return false

func _auto_select_first_playable_die() -> void:
	if not is_my_turn or not dices_rolled or current_dices.is_empty():
		equipped_dice_index = -1
		_recompute_active_possible_pieces()
		return
	# If currently selected die is still valid and playable, keep it
	if equipped_dice_index >= 0 and equipped_dice_index < current_dices.size():
		if _has_available_move_for_die(current_dices[equipped_dice_index], my_player_index):
			_recompute_active_possible_pieces()
			return
	# Otherwise pick the first die in current_dices that has a valid move
	equipped_dice_index = -1
	for i in range(current_dices.size()):
		if _has_available_move_for_die(current_dices[i], my_player_index):
			equipped_dice_index = i
			break
	_recompute_active_possible_pieces()

func _recompute_active_possible_pieces() -> void:
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()

	if not is_my_turn or not dices_rolled or equipped_dice_index < 0 or equipped_dice_index >= current_dices.size():
		return

	var dice_val: int = current_dices[equipped_dice_index]
	var multiple: int = 1 if my_player_index == 1 else -1

	if _check_gamer_piece_is_out(my_player_index):
		var bar_source: int = -1 if my_player_index == 1 else 24
		var dest: int = bar_source + (dice_val * multiple)
		if _check_source_can_move_n_count(bar_source, dice_val, my_player_index) and dest >= 0 and dest < 24:
			can_hit_points.append(dest)
	else:
		var my_pts = _get_my_piece_indexes(my_player_index)
		for pt in my_pts:
			if _check_source_can_move_n_count(pt, dice_val, my_player_index):
				can_select_points.append(pt)
				var dest: int = pt + (dice_val * multiple)
				if dest >= 0 and dest < 24:
					if not (dest in can_hit_points):
						can_hit_points.append(dest)
				elif dest == 24 or dest == -1:
					can_bear_off_sources.append(pt)

# ==============================================================================
# 3D PIECE PLACEMENT, STACKING & VISUAL REFRESH
# ==============================================================================

func _get_point_piece_world_pos(point_idx: int, stack_idx: int, total_count: int) -> Vector3:
	var anchor: Vector3 = _point_positions[point_idx]
	var is_top: bool = _point_is_top[point_idx]
	var dir_z: float = 1.0 if is_top else -1.0

	var tier: int = stack_idx / 5
	var slot_in_tier: int = stack_idx % 5
	var step_z: float = 0.066
	if total_count <= 5:
		step_z = 0.068
	var z_pos: float = anchor.z + dir_z * (0.042 + float(slot_in_tier) * step_z)
	var y_pos: float = SURFACE_Y + float(tier) * (PIECE_HEIGHT + 0.002)
	return Vector3(anchor.x, y_pos, z_pos)

func _get_bar_piece_world_pos(gamer_id: int, stack_idx: int) -> Vector3:
	var base_z: float = -0.18 if gamer_id == 1 else 0.18
	var tier: int = min(stack_idx, 6)
	return Vector3(BAR_X, 0.048 + float(tier) * (PIECE_HEIGHT + 0.001), base_z)

func _get_bear_off_piece_world_pos(gamer_id: int, stack_idx: int) -> Vector3:
	var center_z: float = 0.23 if gamer_id == 1 else -0.23
	var start_z: float = center_z - 0.155
	var step_z: float = 0.022
	var clamped_idx: int = clampi(stack_idx, 0, 14)
	return Vector3(BEAR_OFF_X, SURFACE_Y + 0.010 + float(clamped_idx % 2) * 0.002, start_z + float(clamped_idx) * step_z)

func _rebuild_all_3d_pieces() -> void:
	if not is_instance_valid(_pieces_container):
		return
	for child in _pieces_container.get_children():
		child.queue_free()
	_point_piece_nodes.clear()
	_bar_p1_nodes.clear()
	_bar_p2_nodes.clear()
	_bear_p1_nodes.clear()
	_bear_p2_nodes.clear()

	# 1. Spawn checkers on all 24 points
	for pt in range(24):
		var cnt: int = int(board_spots[pt]["count"])
		var owner: int = int(board_spots[pt]["equipped_user"])
		var pt_arr: Array[Node3D] = []
		if cnt > 0 and owner != 0:
			for s_idx in range(cnt):
				var p_node = _build_3d_checker_piece(owner)
				var w_pos = _get_point_piece_world_pos(pt, s_idx, cnt)
				p_node.position = w_pos
				p_node.set_meta("base_y", w_pos.y)
				_pieces_container.add_child(p_node)
				pt_arr.append(p_node)
		_point_piece_nodes[pt] = pt_arr

	# 2. Spawn hit checkers on the Center Bar
	for i in range(p1_out_pieces):
		var p_node = _build_3d_checker_piece(1)
		p_node.position = _get_bar_piece_world_pos(1, i)
		_pieces_container.add_child(p_node)
		_bar_p1_nodes.append(p_node)

	for i in range(p2_out_pieces):
		var p_node = _build_3d_checker_piece(2)
		p_node.position = _get_bar_piece_world_pos(2, i)
		_pieces_container.add_child(p_node)
		_bar_p2_nodes.append(p_node)

	# 3. Spawn borne-off checkers in the Right-Side Bear-Off Trays
	for i in range(p1_score):
		var p_node = _build_3d_checker_piece(1)
		p_node.scale = Vector3(0.82, 0.82, 0.82)
		p_node.position = _get_bear_off_piece_world_pos(1, i)
		_pieces_container.add_child(p_node)
		_bear_p1_nodes.append(p_node)

	for i in range(p2_score):
		var p_node = _build_3d_checker_piece(2)
		p_node.scale = Vector3(0.82, 0.82, 0.82)
		p_node.position = _get_bear_off_piece_world_pos(2, i)
		_pieces_container.add_child(p_node)
		_bear_p2_nodes.append(p_node)

func _refresh_ui_and_highlights() -> void:
	# 1. Update Point Rings & Count Badges
	for pt in range(24):
		var cnt: int = int(board_spots[pt]["count"])
		var owner: int = int(board_spots[pt]["equipped_user"])
		var is_top: bool = _point_is_top[pt]
		var dir_z: float = 1.0 if is_top else -1.0

		var is_sel: bool = (pt in can_select_points)
		var is_tgt: bool = (pt in can_hit_points)

		if pt < _point_source_rings.size() and is_instance_valid(_point_source_rings[pt]):
			var s_ring = _point_source_rings[pt]
			s_ring.visible = is_sel
			if is_sel and cnt > 0:
				var top_pos = _get_point_piece_world_pos(pt, cnt - 1, cnt)
				s_ring.position = Vector3(top_pos.x, top_pos.y + 0.004, top_pos.z)

		if pt < _point_target_rings.size() and is_instance_valid(_point_target_rings[pt]):
			var t_ring = _point_target_rings[pt]
			t_ring.visible = is_tgt
			if is_tgt:
				var is_blot_hit = (owner != 0 and owner != my_player_index and cnt == 1)
				t_ring.material_override = mat_ring_hit_danger if is_blot_hit else mat_ring_target
				var dest_slot = min(cnt, 4)
				var dest_pos = _get_point_piece_world_pos(pt, dest_slot, max(1, cnt + 1))
				t_ring.position = Vector3(dest_pos.x, SURFACE_Y + 0.005, dest_pos.z)

		if pt < _point_last_rings.size() and is_instance_valid(_point_last_rings[pt]):
			_point_last_rings[pt].visible = (pt == last_played_point and not is_sel)

		if pt < _point_count_labels.size() and is_instance_valid(_point_count_labels[pt]):
			var c_lbl = _point_count_labels[pt]
			if cnt >= 2:
				c_lbl.visible = true
				c_lbl.text = _fa_digits(cnt)
				var front_idx = min(cnt - 1, 4)
				var f_pos = _get_point_piece_world_pos(pt, front_idx, cnt)
				c_lbl.position = Vector3(f_pos.x, f_pos.y + 0.028, f_pos.z)
				c_lbl.modulate = Color(1.0, 0.85, 0.85) if owner == 1 else Color(0.82, 0.92, 1.0)
			else:
				c_lbl.visible = false

	# 2. Update Bar Rings & Labels
	if is_instance_valid(_bar_p1_label):
		_bar_p1_label.visible = (p1_out_pieces > 0)
		_bar_p1_label.text = "خورده: %s" % _fa_digits(p1_out_pieces)
	if is_instance_valid(_bar_p2_label):
		_bar_p2_label.visible = (p2_out_pieces > 0)
		_bar_p2_label.text = "خورده: %s" % _fa_digits(p2_out_pieces)

	if is_instance_valid(_bar_p1_ring):
		_bar_p1_ring.visible = (is_my_turn and my_player_index == 1 and p1_out_pieces > 0 and not can_hit_points.is_empty())
	if is_instance_valid(_bar_p2_ring):
		_bar_p2_ring.visible = (is_my_turn and my_player_index == 2 and p2_out_pieces > 0 and not can_hit_points.is_empty())

	# 3. Update Bear-Off Trays & HUD Scores
	if is_instance_valid(_bear_p1_label):
		_bear_p1_label.text = "قرمز: %s/۱۵" % _fa_digits(p1_score)
	if is_instance_valid(_bear_p2_label):
		_bear_p2_label.text = "آبی: %s/۱۵" % _fa_digits(p2_score)

	if is_instance_valid(_bear_p1_ring):
		_bear_p1_ring.visible = (is_my_turn and my_player_index == 1 and not can_bear_off_sources.is_empty())
	if is_instance_valid(_bear_p2_ring):
		_bear_p2_ring.visible = (is_my_turn and my_player_index == 2 and not can_bear_off_sources.is_empty())

	# 4. Update 3D Roll Dice Button & 3D Dice Slots
	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var show_roll_btn = (not dices_rolled and is_my_turn and GameManager.is_game_active)
		_roll_btn_ui["root"].visible = show_roll_btn

	var num_dices: int = current_dices.size()
	var start_x: float = 0.295 - float(max(0, num_dices - 1)) * 0.062
	for d_idx in range(MAX_DICE_SLOTS):
		if d_idx >= _dice_nodes.size():
			continue
		var d_ui = _dice_nodes[d_idx]
		var slot: Node3D = d_ui["slot"]
		if dices_rolled and d_idx < num_dices:
			slot.visible = true
			slot.position.x = start_x + float(d_idx) * 0.124
			var val: int = current_dices[d_idx]
			if not _is_rolling_dice:
				d_ui["pivot"].rotation = _get_die_target_rotation(val)
			d_ui["label"].text = _fa_digits(val)
			var is_selected_die: bool = (d_idx == equipped_dice_index and is_my_turn)
			d_ui["lock_ring"].visible = is_selected_die
			d_ui["badge_cap"].material_override = mat_die_badge_selected if is_selected_die else mat_die_badge_idle
			for slab in d_ui["slabs"]:
				slab.material_override = mat_die_selected if is_selected_die else mat_die_ivory
		else:
			slot.visible = false

	# 5. Update 3D Status Banner
	_update_3d_status_banner()

func _update_3d_status_banner() -> void:
	if not is_instance_valid(_lbl_status_3d):
		return
	if not GameManager.is_game_active:
		_lbl_status_3d.text = "🎲 تخته نرد کافه فکر — آماده شروع"
		_lbl_status_3d.modulate = Color(1.0, 0.92, 0.62)
		return

	if is_my_turn:
		if not dices_rolled:
			_lbl_status_3d.text = "🎲 نوبت شماست — دکمه «پرتاب تاس» را بزنید!"
			_lbl_status_3d.modulate = Color(0.45, 0.98, 0.65)
		elif current_dices.is_empty():
			_lbl_status_3d.text = "✅ نوبت شما کامل شد"
			_lbl_status_3d.modulate = Color(0.75, 0.95, 0.85)
		elif not _has_any_available_move(my_player_index):
			_lbl_status_3d.text = "⛔ حرکتی با تاس باقی‌مانده وجود ندارد"
			_lbl_status_3d.modulate = Color(1.0, 0.48, 0.48)
		elif _check_gamer_piece_is_out(my_player_index):
			_lbl_status_3d.text = "⚠️ مهره خورده دارید! خانه سبز مشخص‌شده را انتخاب کنید"
			_lbl_status_3d.modulate = Color(1.0, 0.86, 0.35)
		elif equipped_dice_index == -1:
			_lbl_status_3d.text = "🎲 یکی از تاس‌ها را انتخاب کنید"
			_lbl_status_3d.modulate = Color(1.0, 0.92, 0.55)
		else:
			var d_val = current_dices[equipped_dice_index]
			if not can_bear_off_sources.is_empty():
				_lbl_status_3d.text = "🏁 تاس %s انتخاب شد — مهره را خارج کنید یا حرکت دهید" % _fa_digits(d_val)
			else:
				_lbl_status_3d.text = "✨ تاس %s انتخاب شد — روی مهره درخشان بزنید" % _fa_digits(d_val)
			_lbl_status_3d.modulate = Color(1.0, 0.94, 0.55)
	else:
		if not dices_rolled:
			_lbl_status_3d.text = "⏳ نوبت حریف — در انتظار پرتاب تاس..."
		else:
			_lbl_status_3d.text = "⏳ نوبت حریف — در حال انجام حرکت..."
		_lbl_status_3d.modulate = Color(0.82, 0.86, 0.92)

func _sync_hud_scores() -> void:
	GameManager.p1_score = p1_score
	GameManager.p2_score = p2_score
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("update_scores"):
		hud.update_scores(p1_score, p2_score)

# ==============================================================================
# SERVER PROTOCOL HOOKS (BaseGameBoard Overrides)
# ==============================================================================

func setup_board(_game_data: Dictionary) -> void:
	_init_board_state()
	_rebuild_all_3d_pieces()
	_sync_hud_scores()
	_refresh_ui_and_highlights()

func on_turn_changed(turn: int, is_me: bool) -> void:
	current_turn = turn
	is_my_turn = is_me
	equipped_dice_index = -1
	dices_rolled = false
	current_dices.clear()
	can_select_peace = is_me
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()
	if is_me and GameManager.is_game_active:
		AudioManager.sfx_turn()
	_refresh_ui_and_highlights()

func on_roll_result(payload: Dictionary) -> void:
	dices_rolled = true
	current_dices.clear()
	var raw_dices = payload.get("dices", [])
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))

	if current_dices.size() == 4:
		AudioManager.sfx_win_round()
		var d_num = _fa_digits(current_dices[0])
		show_hint("✨ جفت %s! چهار حرکت دارید!" % d_num)
		_spawn_3d_ring_burst(Vector3(0.295, SURFACE_Y + 0.02, 0.0), Color(1.0, 0.85, 0.25), 0.34)
	else:
		AudioManager.sfx_dice()

	_animate_dice_roll()
	if is_my_turn:
		_auto_select_first_playable_die()
	else:
		equipped_dice_index = -1
		_recompute_active_possible_pieces()
	_refresh_ui_and_highlights()

func on_out_of_move(payload: Dictionary) -> void:
	dices_rolled = true
	current_dices.clear()
	var raw_dices = payload.get("dices", [])
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))
	var turn_id = int(payload.get("turn", current_turn))

	equipped_dice_index = -1
	can_select_peace = false
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()

	_animate_dice_roll()
	_refresh_ui_and_highlights()

	if turn_id == my_player_index:
		AudioManager.sfx_wrong()
		show_hint("⛔ شما با این تاس حرکتی ندارید! نوبت رد شد.")
	else:
		show_hint("⛔ حریف با این تاس حرکتی ندارد! نوبت به شما می‌رسد.")

	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(4.0, "⛔ بدون حرکت ممکن — تعویض نوبت...")

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id: int = int(extra.get("gamer_id", user_id))
	var index: int = int(extra.get("index", target_peace))
	var dice_index: int = int(extra.get("dice_index", 0))

	if dice_index < 0 or dice_index >= current_dices.size():
		dice_index = 0
	if current_dices.is_empty():
		return

	var dice_val: int = current_dices[dice_index]
	var rem_idx: int = current_dices.find(dice_val)
	if rem_idx != -1:
		current_dices.remove_at(rem_idx)
	else:
		current_dices.remove_at(dice_index)
	equipped_dice_index = -1

	_apply_move_and_animate(index, dice_val, gamer_id)

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) != TYPE_DICTIONARY:
		return

	var b_arr = g_data.get("board", [])
	if typeof(b_arr) == TYPE_ARRAY and b_arr.size() == 24:
		for i in range(24):
			var sp = b_arr[i]
			if typeof(sp) == TYPE_DICTIONARY:
				board_spots[i] = {
					"count": int(sp.get("count", 0)),
					"equipped_user": int(sp.get("equipped_user", 0))
				}

	var scores = g_data.get("scores", [0, 0])
	if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:
		p1_score = int(scores[0])
		p2_score = int(scores[1])

	var out_arr = g_data.get("out_pieces", [0, 0])
	if typeof(out_arr) == TYPE_ARRAY and out_arr.size() >= 2:
		p1_out_pieces = int(out_arr[0])
		p2_out_pieces = int(out_arr[1])

	var end_arr = g_data.get("end_phases", [false, false])
	if typeof(end_arr) == TYPE_ARRAY and end_arr.size() >= 2:
		p1_is_in_end_phase = bool(end_arr[0])
		p2_is_in_end_phase = bool(end_arr[1])
	else:
		_check_gamer_is_in_end_phase(1)
		_check_gamer_is_in_end_phase(2)

	current_turn = int(g_data.get("current_turn", GameManager.current_turn))
	is_my_turn = (current_turn == my_player_index)
	can_select_peace = is_my_turn
	dices_rolled = bool(g_data.get("current_turn_player_rolled", false))

	current_dices.clear()
	var raw_dices = g_data.get("current_dices", [])
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))

	_rebuild_all_3d_pieces()
	_sync_hud_scores()

	if is_my_turn and dices_rolled:
		_auto_select_first_playable_die()
	else:
		equipped_dice_index = -1
		_recompute_active_possible_pieces()

	_refresh_ui_and_highlights()

func reset_board() -> void:
	_init_board_state()
	_rebuild_all_3d_pieces()
	_sync_hud_scores()
	_refresh_ui_and_highlights()

func cleanup_board() -> void:
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()

# ==============================================================================
# MOVE EXECUTION & 3D PARABOLIC FLIGHT / HIT / BEAR-OFF VFX
# ==============================================================================

func _apply_move_and_animate(source_idx: int, dice_val: int, gamer_id: int) -> void:
	var multiple: int = 1 if gamer_id == 1 else -1
	var target_idx: int = source_idx + (dice_val * multiple)
	var is_in_end: bool = p1_is_in_end_phase if gamer_id == 1 else p2_is_in_end_phase

	# Determine start 3D position before mutating state
	var start_pos: Vector3
	if source_idx == -1 or source_idx == 24:
		var out_cnt = p1_out_pieces if gamer_id == 1 else p2_out_pieces
		start_pos = _get_bar_piece_world_pos(gamer_id, max(0, out_cnt - 1))
		if gamer_id == 1:
			p1_out_pieces = max(0, p1_out_pieces - 1)
		else:
			p2_out_pieces = max(0, p2_out_pieces - 1)
	elif source_idx >= 0 and source_idx < 24:
		var old_cnt = int(board_spots[source_idx]["count"])
		start_pos = _get_point_piece_world_pos(source_idx, max(0, old_cnt - 1), max(1, old_cnt))
		var new_cnt = max(0, old_cnt - 1)
		board_spots[source_idx]["count"] = new_cnt
		if new_cnt == 0:
			board_spots[source_idx]["equipped_user"] = 0
	else:
		start_pos = Vector3(0, SURFACE_Y, 0)

	var was_blot_hit: bool = false
	var hit_enemy_id: int = 2 if gamer_id == 1 else 1
	var end_pos: Vector3

	# Check bearing off vs normal/hit move (Matches BackGammonGameClass.move_piece)
	if is_in_end and (target_idx == -1 or target_idx == 24):
		if gamer_id == 1:
			p1_score += 1
			end_pos = _get_bear_off_piece_world_pos(1, p1_score - 1)
		else:
			p2_score += 1
			end_pos = _get_bear_off_piece_world_pos(2, p2_score - 1)
		last_played_point = -99
		_sync_hud_scores()
	elif target_idx >= 0 and target_idx < 24:
		if _is_enemy_spot(target_idx, gamer_id):
			was_blot_hit = true
			if gamer_id == 1:
				p2_out_pieces += 1
			else:
				p1_out_pieces += 1
			board_spots[target_idx]["count"] = 1
			board_spots[target_idx]["equipped_user"] = gamer_id
			end_pos = _get_point_piece_world_pos(target_idx, 0, 1)
		else:
			var new_target_cnt = int(board_spots[target_idx]["count"]) + 1
			board_spots[target_idx]["count"] = new_target_cnt
			board_spots[target_idx]["equipped_user"] = gamer_id
			end_pos = _get_point_piece_world_pos(target_idx, new_target_cnt - 1, new_target_cnt)
		last_played_point = target_idx
	else:
		end_pos = start_pos

	# Exact parity with BackGammonGameClass.move_piece
	_check_gamer_is_in_end_phase(gamer_id)

	# Auto-select next playable die if it's still our turn
	if is_my_turn and not current_dices.is_empty():
		_auto_select_first_playable_die()
	else:
		equipped_dice_index = -1
		_recompute_active_possible_pieces()
		if is_my_turn and current_dices.is_empty():
			can_select_peace = false

	# Animate flying checker & impact VFX
	_animate_checker_flight(gamer_id, start_pos, end_pos, target_idx, was_blot_hit, hit_enemy_id)

func _animate_checker_flight(gamer_id: int, start_pos: Vector3, end_pos: Vector3, target_idx: int, was_blot_hit: bool, hit_enemy_id: int) -> void:
	_is_animating_move = true
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()

	# Hide the newly placed destination piece while the flying proxy arcs through the air
	var dest_piece: Node3D = null
	if target_idx == 24 and not _bear_p1_nodes.is_empty():
		dest_piece = _bear_p1_nodes[_bear_p1_nodes.size() - 1]
	elif target_idx == -1 and not _bear_p2_nodes.is_empty():
		dest_piece = _bear_p2_nodes[_bear_p2_nodes.size() - 1]
	elif target_idx >= 0 and target_idx < 24 and _point_piece_nodes.has(target_idx):
		var arr: Array = _point_piece_nodes[target_idx]
		if not arr.is_empty():
			dest_piece = arr[arr.size() - 1]

	if is_instance_valid(dest_piece):
		dest_piece.visible = false

	# If a blot was hit, also hide the newly added bar piece until the knocked checker lands on the bar
	var hit_bar_piece: Node3D = null
	if was_blot_hit:
		var bar_arr = _bar_p1_nodes if hit_enemy_id == 1 else _bar_p2_nodes
		if not bar_arr.is_empty():
			hit_bar_piece = bar_arr[bar_arr.size() - 1]
			if is_instance_valid(hit_bar_piece):
				hit_bar_piece.visible = false

	var flyer = _build_3d_checker_piece(gamer_id)
	if target_idx == 24 or target_idx == -1:
		flyer.scale = Vector3(0.82, 0.82, 0.82)
	flyer.position = start_pos
	add_child(flyer)

	# Takeoff ring burst
	var col_player = Color(1.0, 0.35, 0.35) if gamer_id == 1 else Color(0.35, 0.75, 1.0)
	_spawn_3d_ring_burst(start_pos + Vector3(0, 0.005, 0), col_player, 0.09)

	var duration: float = 0.30
	var peak_y: float = maxf(start_pos.y, end_pos.y) + 0.14
	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(flyer):
			return
		var pos = start_pos.lerp(end_pos, t)
		pos.y = lerpf(start_pos.y, end_pos.y, t) + sin(t * PI) * (peak_y - maxf(start_pos.y, end_pos.y))
		flyer.position = pos
		flyer.rotation.x = sin(t * PI) * 0.22
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.tween_callback(func():
		if is_instance_valid(flyer):
			flyer.queue_free()
		if is_instance_valid(dest_piece):
			dest_piece.visible = true

		if target_idx == 24 or target_idx == -1:
			# Bear-Off Golden Ascension Celebration VFX
			AudioManager.sfx_win_round()
			_spawn_bear_off_celebration_vfx(end_pos, gamer_id)
		elif was_blot_hit:
			# Blot Hit Explosion + Knocked Enemy Checker Arcing to Center Bar!
			AudioManager.sfx_capture()
			var bar_dest = _get_bar_piece_world_pos(hit_enemy_id, max(0, (p1_out_pieces if hit_enemy_id == 1 else p2_out_pieces) - 1))
			_spawn_hit_explosion_vfx(end_pos, hit_enemy_id, bar_dest, hit_bar_piece)
		else:
			AudioManager.sfx_move()
			_spawn_3d_ring_burst(end_pos + Vector3(0, 0.005, 0), col_player, 0.11)

		_is_animating_move = false
		_refresh_ui_and_highlights()
	)

func _animate_dice_roll() -> void:
	_is_rolling_dice = true
	var num_dices: int = current_dices.size()
	for d_idx in range(num_dices):
		if d_idx >= _dice_nodes.size():
			continue
		var d_ui = _dice_nodes[d_idx]
		var slot: Node3D = d_ui["slot"]
		slot.visible = true
		var pivot: Node3D = d_ui["pivot"]
		var val: int = current_dices[d_idx]
		var final_rot: Vector3 = _get_die_target_rotation(val)
		var spin_rot: Vector3 = final_rot + Vector3(TAU * 2.0, TAU * 1.0, TAU * 2.0)

		pivot.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "position:y", 0.145, 0.15)
		tw.parallel().tween_property(pivot, "rotation", spin_rot, 0.34)
		tw.tween_property(pivot, "position:y", 0.044, 0.18)
		tw.tween_callback(func():
			if is_instance_valid(pivot):
				pivot.rotation = final_rot
		)

	get_tree().create_timer(0.36).timeout.connect(func():
		if is_instance_valid(self):
			_is_rolling_dice = false
			_refresh_ui_and_highlights()
	)

# ==============================================================================
# RICH 3D VFX (Blot Hit Explosion, Bear-Off Ascension, Ring Bursts, Sparkles)
# ==============================================================================

func _spawn_3d_ring_burst(pos: Vector3, col: Color, max_r: float = 0.12) -> void:
	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = max_r * 0.65
	tor.outer_radius = max_r
	ring.mesh = tor

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.6
	ring.material_override = mat
	ring.position = pos
	ring.scale = Vector3(0.2, 1.0, 0.2)
	add_child(ring)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.35, 1.0, 1.35), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_hit_explosion_vfx(hit_pos: Vector3, hit_enemy_id: int, bar_dest: Vector3, hit_bar_piece: Node3D) -> void:
	# 1. Double Shockwave Ring + 10 Flying Sparks at Hit Location
	var blast_col = Color(1.0, 0.45, 0.15)
	_spawn_3d_ring_burst(hit_pos + Vector3(0, 0.008, 0), blast_col, 0.16)
	_spawn_3d_ring_burst(hit_pos + Vector3(0, 0.014, 0), Color(1.0, 0.90, 0.35), 0.11)

	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.010, 0.010, 0.010)
	for i in range(10):
		var sp = MeshInstance3D.new()
		sp.mesh = spark_mesh
		var smat = StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.80, 0.25)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.emission_enabled = true
		smat.emission = Color(1.0, 0.55, 0.15)
		smat.emission_energy_multiplier = 3.0
		sp.material_override = smat
		sp.position = hit_pos + Vector3(0, 0.015, 0)
		add_child(sp)

		var ang = (float(i) / 10.0) * TAU + randf_range(-0.2, 0.2)
		var dist = randf_range(0.06, 0.13)
		var target_p = hit_pos + Vector3(cos(ang) * dist, randf_range(0.05, 0.11), sin(ang) * dist)
		var stw = create_tween().set_parallel(true)
		stw.tween_property(sp, "position", target_p, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.tween_property(sp, "rotation", Vector3(randf() * TAU, randf() * TAU, randf() * TAU), 0.30)
		stw.tween_property(smat, "albedo_color:a", 0.0, 0.30)
		stw.chain().tween_callback(sp.queue_free)

	# 2. Knocked Enemy Piece Tumbling Arc onto the Center Bar
	var knocked = _build_3d_checker_piece(hit_enemy_id)
	knocked.position = hit_pos + Vector3(0, 0.015, 0)
	add_child(knocked)

	var k_tw = create_tween()
	k_tw.tween_method(func(t: float):
		if not is_instance_valid(knocked):
			return
		var p = hit_pos.lerp(bar_dest, t)
		p.y = lerpf(hit_pos.y, bar_dest.y, t) + sin(t * PI) * 0.20
		knocked.position = p
		knocked.rotation = Vector3(t * TAU * 1.5, 0.0, t * PI)
	, 0.0, 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	k_tw.tween_callback(func():
		if is_instance_valid(knocked):
			knocked.queue_free()
		if is_instance_valid(hit_bar_piece):
			hit_bar_piece.visible = true
		_spawn_3d_ring_burst(bar_dest + Vector3(0, 0.006, 0), Color(1.0, 0.30, 0.30), 0.09)
	)

func _spawn_bear_off_celebration_vfx(tray_pos: Vector3, gamer_id: int) -> void:
	var gold_col = Color(1.0, 0.88, 0.28)
	_spawn_3d_ring_burst(tray_pos + Vector3(0, 0.01, 0), gold_col, 0.14)

	var star_mesh = BoxMesh.new()
	star_mesh.size = Vector3(0.009, 0.009, 0.009)
	for i in range(8):
		var st = MeshInstance3D.new()
		st.mesh = star_mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = gold_col if (i % 2 == 0) else (Color(1.0, 0.4, 0.4) if gamer_id == 1 else Color(0.4, 0.8, 1.0))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 2.8
		st.material_override = mat
		st.position = tray_pos + Vector3(0, 0.015, 0)
		add_child(st)

		var ang = (float(i) / 8.0) * TAU
		var dest = tray_pos + Vector3(cos(ang) * 0.07, randf_range(0.07, 0.14), sin(ang) * 0.07)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(st, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
		tw.chain().tween_callback(st.queue_free)

func _emit_ambient_selection_sparkles() -> void:
	# Spawn subtle rising golden sparkles around up to 3 selectable points
	var sources: Array[Vector3] = []
	if _check_gamer_piece_is_out(my_player_index) and not can_hit_points.is_empty():
		sources.append(_get_bar_piece_world_pos(my_player_index, 0))
	else:
		for pt in can_select_points:
			var cnt = int(board_spots[pt]["count"])
			if cnt > 0:
				sources.append(_get_point_piece_world_pos(pt, cnt - 1, cnt))

	if sources.is_empty():
		return

	var sp_mesh = BoxMesh.new()
	sp_mesh.size = Vector3(0.0055, 0.0055, 0.0055)
	for s_idx in range(min(sources.size(), 4)):
		var base_p: Vector3 = sources[s_idx]
		var sp = MeshInstance3D.new()
		sp.mesh = sp_mesh
		var smat = StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.90, 0.35, 0.90)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.emission_enabled = true
		smat.emission = Color(1.0, 0.82, 0.22)
		smat.emission_energy_multiplier = 2.4
		sp.material_override = smat
		var ang = randf() * TAU
		var r = PIECE_RADIUS * 0.85
		sp.position = base_p + Vector3(cos(ang) * r, 0.012, sin(ang) * r)
		add_child(sp)

		var tw = create_tween().set_parallel(true)
		tw.tween_property(sp, "position:y", sp.position.y + 0.048, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(smat, "albedo_color:a", 0.0, 0.42)
		tw.chain().tween_callback(sp.queue_free)

# ==============================================================================
# 3D CAMERA RAYCAST INPUT HANDLING (Single Unified Input Pipeline)
# ==============================================================================

var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_down_time: float = 0.0
var _is_pointer_down: bool = false
var _last_tap_time: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down_pos = event.position
			_pointer_down_time = Time.get_ticks_msec() / 1000.0
			_is_pointer_down = true
		else:
			if _is_pointer_down:
				_is_pointer_down = false
				var dist = event.position.distance_to(_pointer_down_pos)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _pointer_down_time
				var now = Time.get_ticks_msec() / 1000.0
				if dist <= 24.0 and elapsed < 0.65 and (now - _last_tap_time) > 0.08:
					_last_tap_time = now
					_handle_screen_tap(event.position)

func _handle_screen_tap(screen_pos: Vector2) -> void:
	if _is_animating_move or _is_rolling_dice:
		return
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return

	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 12.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit = space.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		return

	var collider = hit["collider"]
	if not is_instance_valid(collider) or not collider.has_meta("hit_type"):
		return

	var hit_type: String = str(collider.get_meta("hit_type"))
	match hit_type:
		"roll_btn":
			_on_roll_button_tapped()
		"die":
			var d_idx = int(collider.get_meta("die_index"))
			_on_die_tapped(d_idx)
		"point":
			var pt_idx = int(collider.get_meta("point_index"))
			_on_point_tapped(pt_idx)
		"bar":
			var g_id = int(collider.get_meta("gamer_id"))
			_on_bar_tapped(g_id)
		"bear_off":
			var g_id = int(collider.get_meta("gamer_id"))
			_on_bear_off_tapped(g_id)

func _on_roll_button_tapped() -> void:
	if not is_my_turn or not can_select_peace:
		AudioManager.sfx_wrong()
		show_hint("⏳ نوبت شما نیست!")
		return
	if dices_rolled:
		return
	AudioManager.sfx_tap()
	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var btn_root: Node3D = _roll_btn_ui["root"]
		var tw = create_tween()
		tw.tween_property(btn_root, "scale", Vector3(0.92, 0.92, 0.92), 0.07)
		tw.tween_property(btn_root, "scale", Vector3.ONE, 0.09)
	send_move(Commands.Roll_Dice, {})

func _on_die_tapped(die_idx: int) -> void:
	if not is_my_turn or not can_select_peace:
		AudioManager.sfx_wrong()
		show_hint("⏳ نوبت شما نیست!")
		return
	if not dices_rolled or die_idx < 0 or die_idx >= current_dices.size():
		return

	AudioManager.sfx_tap()
	if equipped_dice_index == die_idx:
		equipped_dice_index = -1
	else:
		equipped_dice_index = die_idx

	_recompute_active_possible_pieces()
	_refresh_ui_and_highlights()

	if equipped_dice_index != -1 and can_select_points.is_empty() and can_hit_points.is_empty() and can_bear_off_sources.is_empty():
		show_hint("⚠️ با این تاس حرکتی ممکن نیست — تاس دیگر را امتحان کنید")

func _on_bar_tapped(gamer_id: int) -> void:
	if gamer_id != my_player_index:
		return
	if not is_my_turn or not can_select_peace:
		AudioManager.sfx_wrong()
		show_hint("⏳ نوبت شما نیست!")
		return
	if not dices_rolled:
		AudioManager.sfx_wrong()
		show_hint("🎲 ابتدا تاس بریزید!")
		return
	if equipped_dice_index == -1:
		_auto_select_first_playable_die()
		if equipped_dice_index == -1:
			AudioManager.sfx_wrong()
			show_hint("🎲 ابتدا یک تاس انتخاب کنید!")
			return

	if _check_gamer_piece_is_out(my_player_index) and not can_hit_points.is_empty():
		_dispatch_bar_entry_move()

func _on_bear_off_tapped(gamer_id: int) -> void:
	if gamer_id != my_player_index:
		return
	if not is_my_turn or not can_select_peace or not dices_rolled:
		return
	if equipped_dice_index == -1:
		_auto_select_first_playable_die()
	if not can_bear_off_sources.is_empty():
		var src_pt: int = can_bear_off_sources[0]
		_dispatch_point_move(src_pt)

func _on_point_tapped(pt_idx: int) -> void:
	if not is_my_turn or not can_select_peace:
		AudioManager.sfx_wrong()
		show_hint("⏳ نوبت شما نیست!")
		return
	if not dices_rolled:
		AudioManager.sfx_wrong()
		show_hint("🎲 ابتدا دکمه «پرتاب تاس» را بزنید!")
		return
	if equipped_dice_index == -1:
		_auto_select_first_playable_die()
		if equipped_dice_index == -1:
			AudioManager.sfx_wrong()
			show_hint("🎲 ابتدا یک تاس انتخاب کنید!")
			return

	# Case 1: Player has hit pieces on the Bar -> Must enter onto can_hit_points
	if _check_gamer_piece_is_out(my_player_index):
		if pt_idx in can_hit_points:
			_dispatch_bar_entry_move()
		else:
			# Check if another die in current_dices can enter onto pt_idx!
			var bar_src = -1 if my_player_index == 1 else 24
			var mult = 1 if my_player_index == 1 else -1
			for d_i in range(current_dices.size()):
				if bar_src + current_dices[d_i] * mult == pt_idx and _check_source_can_move_n_count(bar_src, current_dices[d_i], my_player_index):
					equipped_dice_index = d_i
					_recompute_active_possible_pieces()
					_dispatch_bar_entry_move()
					return
			AudioManager.sfx_wrong()
			show_hint("⚠️ ابتدا باید مهره خورده خود را وارد بازی کنید!")
		return

	# Case 2: Normal board move or bear-off from pt_idx
	if pt_idx in can_select_points:
		_dispatch_point_move(pt_idx)
		return

	# Smart Convenience: If user tapped their own piece at pt_idx and the OTHER die can move it, auto-switch die and move!
	if int(board_spots[pt_idx]["equipped_user"]) == my_player_index and int(board_spots[pt_idx]["count"]) > 0:
		for d_i in range(current_dices.size()):
			if _check_source_can_move_n_count(pt_idx, current_dices[d_i], my_player_index):
				equipped_dice_index = d_i
				_recompute_active_possible_pieces()
				_dispatch_point_move(pt_idx)
				return

	AudioManager.sfx_wrong()
	show_hint("⚠️ این مهره با تاس انتخاب‌شده قابل حرکت نیست!")

func _dispatch_bar_entry_move() -> void:
	var bar_index: int = -1 if my_player_index == 1 else 24
	var d_idx: int = equipped_dice_index
	AudioManager.sfx_tap()
	equipped_dice_index = -1
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()
	_refresh_ui_and_highlights()
	send_move(Commands.Select_Peace, {"index": bar_index, "dice_index": d_idx})

func _dispatch_point_move(pt_idx: int) -> void:
	var d_idx: int = equipped_dice_index
	AudioManager.sfx_tap()
	equipped_dice_index = -1
	can_select_points.clear()
	can_hit_points.clear()
	can_bear_off_sources.clear()
	_refresh_ui_and_highlights()
	send_move(Commands.Select_Peace, {"index": pt_idx, "dice_index": d_idx})

# ==============================================================================
# HELPERS (3D Typography & Persian Numerals)
# ==============================================================================

func _create_3d_label(txt: String, f_size: int, col: Color) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = txt
	lbl.font = _FONT_FA
	lbl.font_size = f_size
	lbl.pixel_size = 0.00075
	lbl.modulate = col
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0.08, 0.04, 0.02, 0.95)
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	return lbl

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
