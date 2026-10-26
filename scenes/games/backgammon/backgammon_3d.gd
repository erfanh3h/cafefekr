class_name BackGammon3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# CAFE FEKR — 3D ROYAL PERSIAN BACKGAMMON (تخته نرد سلطنتی کافه فکر)
# ==============================================================================
# 100% Rule, State & Socket Protocol Parity with:
#   - Backend: Entities/Games/BackGammon/__init__.py & backgammon_game_session.py
#   - Flutter: lib/Feature/BackGammon/Controllers/backgammon_controller.dart
#
# Portrait-Optimized 3D Architecture (1.16m wide x 1.66m long — matches Yatzy3D):
#   1. Zone 1 (Top, Z = -0.715): Twin Carved Bear-Off Vaults holding 3D stacked
#      borne-off checkers (no cluttered piece-count text on top).
#   2. Zone 2 (Main Cabinet, Z = -0.60 to +0.30): Royal Persian Walnut & 24K Gold
#      Khatamkari Hinged Backgammon Cabinet with 24 multi-layered 3D inlaid points,
#      brass-hinged Center Bar, and large lathe-turned 3D ribbed checkers.
#   3. Zone 3 (Bottom Dice Tray, Z = +0.445): Recessed Emerald Velvet 3D Dice Arena
#      holding large Yatzy-style 3D Ivory Dice (outside the playing field!) with
#      glowing gold selection rings and large framed Persian numeral plaques.
#   4. Zone 4 (Bottom Action Console, Z = +0.665): Prominent, always-visible 3D
#      tactile "🎲 پرتاب تاس" button at the bottom of the board.
# ==============================================================================

@export var camera_distance: float = 3.22
@export var camera_pitch: float = -1.12

const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")
const FA_DIGITS = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

# --- Portrait Arena & Board Geometry Constants ---
const ARENA_W: float = 1.16
const ARENA_L: float = 1.66
const BOARD_H: float = 0.030
const SURFACE_Y: float = 0.030

# Main Backgammon Cabinet (Upper-Center of Portrait Arena)
const CABINET_W: float = 1.12
const CABINET_L: float = 0.90
const CABINET_CENTER_Z: float = -0.150
const CABINET_TOP_Z: float = -0.600
const CABINET_BOT_Z: float = 0.300
const BAR_X: float = 0.0

# Larger, Gamer-Friendly 3D Checkers & Yatzy-Scale 3D Dice
const PIECE_RADIUS: float = 0.0415
const PIECE_HEIGHT: float = 0.018
const DIE_SIZE: float = 0.090
const MAX_DICE_SLOTS: int = 4

# Bottom Dice Tray & Roll Button Coordinates (Comfortably above bottom HUD bar)
const DICE_TRAY_Z: float = 0.445
const DICE_TRAY_W: float = 1.06
const DICE_TRAY_L: float = 0.250
const ROLL_BTN_Z: float = 0.665

# Top Bear-Off Vault Coordinates
const BEAR_VAULT_Z: float = -0.715
const BEAR_P2_X: float = -0.275
const BEAR_P1_X: float = 0.275

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
var can_hit_points: Array[int] = []         # Destination points (0..23) when entering from bar
var can_target_points: Dictionary = {}      # target_pt (0..23) -> source_pt (-1, 24, or 0..23)
var can_bear_off_sources: Array[int] = []   # Source points (0..23) that bear off to 24 or -1

# --- 3D Scene Nodes & Caches ---
var _point_positions: Array[Vector3] = []   # 24 base anchors for points 0..23
var _point_is_top: Array[bool] = []         # True for points 0..11 (top row -Z), False for 12..23 (bottom row +Z)
var _point_source_rings: Array[MeshInstance3D] = []
var _point_target_rings: Array[MeshInstance3D] = []
var _point_last_rings: Array[MeshInstance3D] = []

var _pieces_container: Node3D = null
var _point_piece_nodes: Dictionary = {}     # point_idx (0..23) -> Array[Node3D]
var _bar_p1_nodes: Array[Node3D] = []
var _bar_p2_nodes: Array[Node3D] = []
var _bear_p1_nodes: Array[Node3D] = []
var _bear_p2_nodes: Array[Node3D] = []

var _bar_p1_ring: MeshInstance3D = null
var _bar_p2_ring: MeshInstance3D = null

var _bar_p1_count_lbl: Label3D = null
var _bar_p2_count_lbl: Label3D = null

var _center_rosette_lbl: Label3D = null

var _bear_p1_ring: MeshInstance3D = null
var _bear_p2_ring: MeshInstance3D = null

var _dice_nodes: Array[Dictionary] = []
var _roll_btn_ui: Dictionary = {}

var _vfx_time: float = 0.0
var _sparkle_accum: float = 0.0
var _is_animating_move: bool = false
var _is_rolling_dice: bool = false
var _last_interaction_msec: int = 0
var _reconnect_guard_msec: int = 0

# --- Shared Luxury Materials ---
var mat_wood_case: StandardMaterial3D
var mat_wood_rail: StandardMaterial3D
var mat_obsidian_bed: StandardMaterial3D
var mat_velvet_court: StandardMaterial3D
var mat_velvet_tray: StandardMaterial3D
var mat_velvet_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_bronze_bevel: StandardMaterial3D
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
var mat_die_preview: StandardMaterial3D
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
var mat_btn_roll_moved: StandardMaterial3D
var mat_btn_roll_disabled: StandardMaterial3D


# ==============================================================================
# LIFECYCLE & INITIALIZATION
# ==============================================================================

func _init() -> void:
	game_type = GameTypes.BACKGAMMON


func _ready() -> void:
	game_type = GameTypes.BACKGAMMON
	_init_materials()
	_compute_point_anchors()
	_build_3d_backgammon_board()
	_init_board_state()
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()
	super._ready()


func is_interacting_with_piece() -> bool:
	return (Time.get_ticks_msec() - _last_interaction_msec) < 350


func _mark_interaction() -> void:
	_last_interaction_msec = Time.get_ticks_msec()


func _process(delta: float) -> void:
	_vfx_time += delta
	_sparkle_accum += delta

	# 1. Pulse selectable source rings, target rings & float top checkers on selectable points
	var pulse = 0.5 + 0.5 * sin(_vfx_time * 5.2)
	var float_y = sin(_vfx_time * 4.6) * 0.0055

	if is_instance_valid(mat_ring_selectable):
		mat_ring_selectable.emission_energy_multiplier = 0.70 + 0.30 * pulse
	if is_instance_valid(mat_ring_target):
		mat_ring_target.emission_energy_multiplier = 1.5 + 1.1 * pulse
	if is_instance_valid(mat_ring_hit_danger):
		mat_ring_hit_danger.emission_energy_multiplier = 1.9 + 1.5 * pulse

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

	# 2. Float selected die in the bottom tray & pulse bottom Roll Dice button when ready
	for d_idx in range(_dice_nodes.size()):
		var d_ui = _dice_nodes[d_idx]
		if d_ui["slot"].visible and not _is_rolling_dice:
			var is_eq = (dices_rolled and d_idx == equipped_dice_index)
			var pivot: Node3D = d_ui["pivot"]
			if is_instance_valid(pivot):
				var target_y = 0.052 + (0.008 + sin(_vfx_time * 5.2) * 0.004 if is_eq else 0.0)
				pivot.position.y = lerpf(pivot.position.y, target_y, 12.0 * delta)

	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var btn_root: Node3D = _roll_btn_ui["root"]
		if is_my_turn and not dices_rolled and GameManager.is_game_active:
			var s = 1.0 + 0.028 * sin(_vfx_time * 5.8)
			btn_root.scale = Vector3(s, 1.0, s)
		else:
			btn_root.scale = Vector3.ONE

	# 3. Periodic golden sparkle particles on selectable pieces
	if _sparkle_accum >= 0.28 and not _is_animating_move and is_my_turn and dices_rolled:
		_sparkle_accum = 0.0
		_emit_ambient_selection_sparkles()


func _fa_digits(val: Variant) -> String:
	var s := str(val)
	var out := ""
	for i in range(s.length()):
		var ch := s.unicode_at(i)
		if ch >= 48 and ch <= 57:
			out += FA_DIGITS[ch - 48]
		else:
			out += s[i]
	return out


# ==============================================================================
# MATERIALS & POINT COORDINATE GEOMETRY
# ==============================================================================

func _init_materials() -> void:
	# Outer Cabinet: Hand-Rubbed Royal Persian Walnut
	mat_wood_case = StandardMaterial3D.new()
	mat_wood_case.albedo_color = Color(0.19, 0.10, 0.05)
	mat_wood_case.roughness = 0.34
	mat_wood_case.metallic = 0.06
	mat_wood_case.clearcoat_enabled = true
	mat_wood_case.clearcoat = 0.50

	# Raised Rails & Center Bar: Roasted Mahogany / Rosewood
	mat_wood_rail = StandardMaterial3D.new()
	mat_wood_rail.albedo_color = Color(0.30, 0.15, 0.08)
	mat_wood_rail.roughness = 0.28
	mat_wood_rail.metallic = 0.08
	mat_wood_rail.clearcoat_enabled = true
	mat_wood_rail.clearcoat = 0.62

	# Obsidian Backing
	mat_obsidian_bed = StandardMaterial3D.new()
	mat_obsidian_bed.albedo_color = Color(0.08, 0.09, 0.13)
	mat_obsidian_bed.roughness = 0.26
	mat_obsidian_bed.metallic = 0.20

	# Recessed Playing Court Baize: Deep Royal Emerald-Obsidian Velvet
	mat_velvet_court = StandardMaterial3D.new()
	mat_velvet_court.albedo_color = Color(0.05, 0.19, 0.14)
	mat_velvet_court.roughness = 0.86
	mat_velvet_court.metallic = 0.02

	# Bottom Dice Tray Baize: Lush Casino Emerald Felt
	mat_velvet_tray = StandardMaterial3D.new()
	mat_velvet_tray.albedo_color = Color(0.06, 0.26, 0.17)
	mat_velvet_tray.roughness = 0.85
	mat_velvet_tray.metallic = 0.0

	# Deep Velvet Wells (Bar, Bear-Off & Dice Wells)
	mat_velvet_well = StandardMaterial3D.new()
	mat_velvet_well.albedo_color = Color(0.04, 0.13, 0.10)
	mat_velvet_well.roughness = 0.90

	# 24K Royal Gold Filigree, Hinges & P1 Inlays
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.98, 0.82, 0.30)
	mat_gold_trim.metallic = 0.92
	mat_gold_trim.roughness = 0.16
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.88
	mat_gold_trim.emission_enabled = true
	mat_gold_trim.emission = Color(0.32, 0.24, 0.06)

	# Aged Burnished Bronze Bevel for 3D Point Bases
	mat_bronze_bevel = StandardMaterial3D.new()
	mat_bronze_bevel.albedo_color = Color(0.68, 0.50, 0.22)
	mat_bronze_bevel.metallic = 0.78
	mat_bronze_bevel.roughness = 0.26

	# Polished Platinum / Silver Trim for P2 Inlays & Medallions
	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.93, 0.96, 1.0)
	mat_platinum_trim.metallic = 0.92
	mat_platinum_trim.roughness = 0.16
	mat_platinum_trim.clearcoat_enabled = true
	mat_platinum_trim.clearcoat = 0.88
	mat_platinum_trim.emission_enabled = true
	mat_platinum_trim.emission = Color(0.18, 0.22, 0.30)

	# Even Points: Warm Persian Ivory / Sycamore Maple Inlay
	mat_point_light = StandardMaterial3D.new()
	mat_point_light.albedo_color = Color(0.95, 0.89, 0.76)
	mat_point_light.roughness = 0.36
	mat_point_light.metallic = 0.05
	mat_point_light.clearcoat_enabled = true
	mat_point_light.clearcoat = 0.35

	# Odd Points: Deep Royal Crimson-Garnet & Walnut Marquetry
	mat_point_dark = StandardMaterial3D.new()
	mat_point_dark.albedo_color = Color(0.56, 0.14, 0.12)
	mat_point_dark.roughness = 0.34
	mat_point_dark.metallic = 0.10
	mat_point_dark.clearcoat_enabled = true
	mat_point_dark.clearcoat = 0.40

	# Player 1 (Red / شما) Checker Puck: Imperial Crimson Ruby Lacquer
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.88, 0.11, 0.15)
	mat_piece_p1.metallic = 0.28
	mat_piece_p1.roughness = 0.15
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 1.0
	mat_piece_p1.clearcoat_roughness = 0.04

	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.54, 0.05, 0.08)
	mat_piece_p1_well.metallic = 0.34
	mat_piece_p1_well.roughness = 0.22
	mat_piece_p1_well.clearcoat_enabled = true
	mat_piece_p1_well.clearcoat = 0.85

	# Player 2 (Blue / حریف) Checker Puck: Royal Cobalt Sapphire Lacquer
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.11, 0.42, 0.90)
	mat_piece_p2.metallic = 0.28
	mat_piece_p2.roughness = 0.15
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 1.0
	mat_piece_p2.clearcoat_roughness = 0.04

	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.05, 0.20, 0.54)
	mat_piece_p2_well.metallic = 0.34
	mat_piece_p2_well.roughness = 0.22
	mat_piece_p2_well.clearcoat_enabled = true
	mat_piece_p2_well.clearcoat = 0.85

	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.06, 0.20, 0.11)
	mat_felt_base.roughness = 0.90

	# 3D Yatzy-Style Luxury Dice Materials
	mat_die_ivory = StandardMaterial3D.new()
	mat_die_ivory.albedo_color = Color(0.99, 0.97, 0.92)
	mat_die_ivory.roughness = 0.15
	mat_die_ivory.metallic = 0.04
	mat_die_ivory.clearcoat_enabled = true
	mat_die_ivory.clearcoat = 0.92

	mat_die_chamfer = StandardMaterial3D.new()
	mat_die_chamfer.albedo_color = Color(0.90, 0.84, 0.72)
	mat_die_chamfer.roughness = 0.22
	mat_die_chamfer.metallic = 0.15

	mat_die_selected = StandardMaterial3D.new()
	mat_die_selected.albedo_color = Color(1.0, 0.93, 0.70)
	mat_die_selected.roughness = 0.14
	mat_die_selected.metallic = 0.22
	mat_die_selected.clearcoat_enabled = true
	mat_die_selected.clearcoat = 0.95
	mat_die_selected.emission_enabled = true
	mat_die_selected.emission = Color(0.95, 0.72, 0.18)
	mat_die_selected.emission_energy_multiplier = 0.38

	mat_die_preview = StandardMaterial3D.new()
	mat_die_preview.albedo_color = Color(0.82, 0.80, 0.75)
	mat_die_preview.roughness = 0.35
	mat_die_preview.metallic = 0.05

	mat_pip_dark = StandardMaterial3D.new()
	mat_pip_dark.albedo_color = Color(0.08, 0.09, 0.12)
	mat_pip_dark.roughness = 0.18
	mat_pip_dark.metallic = 0.25

	mat_pip_red = StandardMaterial3D.new()
	mat_pip_red.albedo_color = Color(0.88, 0.12, 0.16)
	mat_pip_red.roughness = 0.18
	mat_pip_red.metallic = 0.20
	mat_pip_red.emission_enabled = true
	mat_pip_red.emission = Color(0.45, 0.05, 0.08)
	mat_pip_red.emission_energy_multiplier = 0.25

	mat_die_lock_ring = StandardMaterial3D.new()
	mat_die_lock_ring.albedo_color = Color(1.0, 0.82, 0.20)
	mat_die_lock_ring.metallic = 0.75
	mat_die_lock_ring.roughness = 0.18
	mat_die_lock_ring.emission_enabled = true
	mat_die_lock_ring.emission = Color(1.0, 0.76, 0.16)
	mat_die_lock_ring.emission_energy_multiplier = 1.45

	mat_die_badge_idle = StandardMaterial3D.new()
	mat_die_badge_idle.albedo_color = Color(0.13, 0.15, 0.20)
	mat_die_badge_idle.roughness = 0.30
	mat_die_badge_idle.metallic = 0.18

	mat_die_badge_selected = StandardMaterial3D.new()
	mat_die_badge_selected.albedo_color = Color(0.88, 0.62, 0.12)
	mat_die_badge_selected.roughness = 0.22
	mat_die_badge_selected.metallic = 0.45
	mat_die_badge_selected.emission_enabled = true
	mat_die_badge_selected.emission = Color(0.95, 0.70, 0.15)
	mat_die_badge_selected.emission_energy_multiplier = 0.55

	# Highlight Rings (Selectable Source: Rich Deep Antique Dark Gold, Matte & Glare-Free)
	mat_ring_selectable = StandardMaterial3D.new()
	mat_ring_selectable.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_selectable.albedo_color = Color(0.72, 0.44, 0.02, 0.95)
	mat_ring_selectable.metallic = 0.20
	mat_ring_selectable.roughness = 0.50
	mat_ring_selectable.clearcoat_enabled = false
	mat_ring_selectable.emission_enabled = true
	mat_ring_selectable.emission = Color(0.55, 0.32, 0.01)
	mat_ring_selectable.emission_energy_multiplier = 0.85

	mat_ring_target = StandardMaterial3D.new()
	mat_ring_target.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_target.albedo_color = Color(0.18, 0.96, 0.52, 0.92)
	mat_ring_target.emission_enabled = true
	mat_ring_target.emission = Color(0.12, 0.88, 0.44)
	mat_ring_target.emission_energy_multiplier = 1.8

	mat_ring_hit_danger = StandardMaterial3D.new()
	mat_ring_hit_danger.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_hit_danger.albedo_color = Color(1.0, 0.22, 0.26, 0.95)
	mat_ring_hit_danger.emission_enabled = true
	mat_ring_hit_danger.emission = Color(1.0, 0.14, 0.18)
	mat_ring_hit_danger.emission_energy_multiplier = 2.2

	mat_ring_last_move = StandardMaterial3D.new()
	mat_ring_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ring_last_move.albedo_color = Color(0.38, 0.82, 1.0, 0.85)
	mat_ring_last_move.emission_enabled = true
	mat_ring_last_move.emission = Color(0.28, 0.72, 1.0)
	mat_ring_last_move.emission_energy_multiplier = 1.3

	# Bottom 3D Roll Dice Button Materials
	mat_btn_roll_active = StandardMaterial3D.new()
	mat_btn_roll_active.albedo_color = Color(0.12, 0.64, 0.36)
	mat_btn_roll_active.roughness = 0.22
	mat_btn_roll_active.metallic = 0.24
	mat_btn_roll_active.clearcoat_enabled = true
	mat_btn_roll_active.clearcoat = 0.65
	mat_btn_roll_active.emission_enabled = true
	mat_btn_roll_active.emission = Color(0.08, 0.52, 0.26)
	mat_btn_roll_active.emission_energy_multiplier = 0.65

	mat_btn_roll_moved = StandardMaterial3D.new()
	mat_btn_roll_moved.albedo_color = Color(0.16, 0.38, 0.68)
	mat_btn_roll_moved.roughness = 0.26
	mat_btn_roll_moved.metallic = 0.22
	mat_btn_roll_moved.emission_enabled = true
	mat_btn_roll_moved.emission = Color(0.10, 0.28, 0.54)
	mat_btn_roll_moved.emission_energy_multiplier = 0.40

	mat_btn_roll_disabled = StandardMaterial3D.new()
	mat_btn_roll_disabled.albedo_color = Color(0.20, 0.22, 0.27)
	mat_btn_roll_disabled.roughness = 0.50
	mat_btn_roll_disabled.metallic = 0.12


func _compute_point_anchors() -> void:
	# Exact Layout Matching Flutter BackGammonBoardWidget:
	# - Points 0..11 are along the TOP edge (CABINET_TOP_Z = -0.600, base at Z = -0.558):
	#     0..5:   Top-Right quadrant (right-to-left: col 0..5)
	#     6..11:  Top-Left quadrant  (right-to-left: col 6..11)
	# - Points 12..23 are along the BOTTOM edge (CABINET_BOT_Z = +0.300, base at Z = +0.258):
	#     12..17: Bottom-Left quadrant  (left-to-right: col 11..6)
	#     18..23: Bottom-Right quadrant (left-to-right: col 5..0)
	_point_positions.resize(24)
	_point_is_top.resize(24)

	for i in range(24):
		var is_top: bool = (i < 12)
		_point_is_top[i] = is_top
		var col_from_right: int = i if is_top else (23 - i)
		var x_pos: float = 0.0
		if col_from_right < 6:
			# Right Court (Home quadrant): X from +0.484 down to +0.094 (spacing 0.078m)
			x_pos = 0.484 - float(col_from_right) * 0.078
		else:
			# Left Court (Outer quadrant): X from -0.094 down to -0.484 (spacing 0.078m)
			x_pos = -0.094 - float(col_from_right - 6) * 0.078

		var z_base: float = -0.558 if is_top else 0.258
		_point_positions[i] = Vector3(x_pos, SURFACE_Y, z_base)


# ==============================================================================
# 3D ROYAL PERSIAN BACKGAMMON ARENA CONSTRUCTION (1.16m x 1.66m Portrait)
# ==============================================================================

func _build_3d_backgammon_board() -> void:
	# 1. Master Portrait Carved Walnut Plinth (1.16m wide x 1.66m long)
	var base_plinth = MeshInstance3D.new()
	var bp_box = BoxMesh.new()
	bp_box.size = Vector3(ARENA_W, BOARD_H, ARENA_L)
	bp_box.material = mat_wood_case
	base_plinth.mesh = bp_box
	base_plinth.position = Vector3(0, BOARD_H * 0.5, 0)
	add_child(base_plinth)

	# Outer Mahogany Frame Moulding around entire Arena
	for rim_cfg in [
		{"pos": Vector3(0, BOARD_H + 0.006, -ARENA_L * 0.5 + 0.016), "size": Vector3(ARENA_W, 0.012, 0.032)},
		{"pos": Vector3(0, BOARD_H + 0.006, ARENA_L * 0.5 - 0.016), "size": Vector3(ARENA_W, 0.012, 0.032)},
		{"pos": Vector3(-ARENA_W * 0.5 + 0.016, BOARD_H + 0.006, 0), "size": Vector3(0.032, 0.012, ARENA_L - 0.064)},
		{"pos": Vector3(ARENA_W * 0.5 - 0.016, BOARD_H + 0.006, 0), "size": Vector3(0.032, 0.012, ARENA_L - 0.064)},
	]:
		var r_inst = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = rim_cfg["size"]
		r_box.material = mat_wood_rail
		r_inst.mesh = r_box
		r_inst.position = rim_cfg["pos"]
		add_child(r_inst)

	# 4 Ornate 24K Gold Corner Medallions on the Master Arena
	for cx in [-ARENA_W * 0.5 + 0.024, ARENA_W * 0.5 - 0.024]:
		for cz in [-ARENA_L * 0.5 + 0.024, ARENA_L * 0.5 - 0.024]:
			var med = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.022
			cyl.bottom_radius = 0.026
			cyl.height = 0.016
			cyl.material = mat_gold_trim
			med.mesh = cyl
			med.position = Vector3(cx, BOARD_H + 0.008, cz)
			add_child(med)

	_build_top_bear_off_vaults()
	_build_main_playing_cabinet()
	_build_24_points()
	_build_bar_zones()
	_build_bottom_dice_and_roll_console()

	_pieces_container = Node3D.new()
	_pieces_container.name = "PiecesContainer"
	add_child(_pieces_container)


func _build_top_bear_off_vaults() -> void:
	# Clean Top Bear-Off Vaults at Z = -0.715 (Left = P2 Blue, Right = P1 Red) — NO text clutter!
	var vault_configs = [
		{"gamer": 2, "x": BEAR_P2_X},
		{"gamer": 1, "x": BEAR_P1_X},
	]

	for vc in vault_configs:
		var g_id: int = vc["gamer"]
		var vx: float = vc["x"]
		var v_root = Node3D.new()
		v_root.name = "BearOffVault_P%d" % g_id
		v_root.position = Vector3(vx, SURFACE_Y, BEAR_VAULT_Z)
		add_child(v_root)

		# Gold Outer Frame
		var frame = MeshInstance3D.new()
		var f_box = BoxMesh.new()
		f_box.size = Vector3(0.510, 0.014, 0.126)
		f_box.material = mat_gold_trim
		frame.mesh = f_box
		frame.position = Vector3(0, 0.007, 0)
		v_root.add_child(frame)

		# Recessed Velvet Trough
		var bed = MeshInstance3D.new()
		var b_box = BoxMesh.new()
		b_box.size = Vector3(0.492, 0.016, 0.110)
		b_box.material = mat_velvet_well
		bed.mesh = b_box
		bed.position = Vector3(0, 0.008, 0)
		v_root.add_child(bed)

		# 15 Subtle Golden Slot Dividers inside the Bear-Off Trough
		for s_i in range(14):
			var div = MeshInstance3D.new()
			var d_box = BoxMesh.new()
			d_box.size = Vector3(0.002, 0.018, 0.088)
			d_box.material = mat_bronze_bevel
			div.mesh = d_box
			div.position = Vector3(-0.210 + float(s_i + 1) * 0.030, 0.009, 0.0)
			v_root.add_child(div)

		# Glowing Target Border (Lights up in Emerald when player can Bear Off!)
		var ring = MeshInstance3D.new()
		var r_box = BoxMesh.new()
		r_box.size = Vector3(0.522, 0.020, 0.136)
		r_box.material = mat_ring_target
		ring.mesh = r_box
		ring.position = Vector3(0, 0.010, 0)
		ring.visible = false
		v_root.add_child(ring)

		# Clickable Area3D for Bearing Off Checkers
		var area = Area3D.new()
		area.name = "BearOffArea_P%d" % g_id
		area.set_meta("hit_type", "bear_off")
		area.set_meta("gamer_id", g_id)
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.52, 0.08, 0.15)
		col.shape = shape
		area.add_child(col)
		area.position = Vector3(0, 0.025, 0)
		v_root.add_child(area)

		if g_id == 1:
			_bear_p1_ring = ring
		else:
			_bear_p2_ring = ring


func _build_main_playing_cabinet() -> void:
	# Left & Right Recessed Royal Emerald Velvet Playing Courts
	for court_x in [-0.286, 0.286]:
		var court = MeshInstance3D.new()
		var c_box = BoxMesh.new()
		c_box.size = Vector3(0.486, 0.006, 0.836)
		c_box.material = mat_velvet_court
		court.mesh = c_box
		court.position = Vector3(court_x, SURFACE_Y - 0.001, CABINET_CENTER_Z)
		add_child(court)

		# Gold Inner Filigree Frame around each court
		for c_rim in [
			{"pos": Vector3(court_x, SURFACE_Y + 0.003, CABINET_TOP_Z + 0.032), "size": Vector3(0.488, 0.004, 0.005)},
			{"pos": Vector3(court_x, SURFACE_Y + 0.003, CABINET_BOT_Z - 0.032), "size": Vector3(0.488, 0.004, 0.005)},
			{"pos": Vector3(court_x - 0.243, SURFACE_Y + 0.003, CABINET_CENTER_Z), "size": Vector3(0.005, 0.004, 0.836)},
			{"pos": Vector3(court_x + 0.243, SURFACE_Y + 0.003, CABINET_CENTER_Z), "size": Vector3(0.005, 0.004, 0.836)},
		]:
			var g_inst = MeshInstance3D.new()
			var g_box = BoxMesh.new()
			g_box.size = c_rim["size"]
			g_box.material = mat_gold_trim
			g_inst.mesh = g_box
			g_inst.position = c_rim["pos"]
			add_child(g_inst)

		# Persian Khatamkari Star Medallion in the center of each court
		_build_court_marquetry_emblem(Vector3(court_x, SURFACE_Y + 0.002, CABINET_CENTER_Z))

	# Raised Mahogany Rails framing the Backgammon Cabinet (Top, Bottom, Left, Right)
	var rail_h: float = 0.026
	var rail_y: float = SURFACE_Y + rail_h * 0.5
	var rails = [
		{"pos": Vector3(0, rail_y, CABINET_TOP_Z + 0.015), "size": Vector3(CABINET_W, rail_h, 0.030)},
		{"pos": Vector3(0, rail_y, CABINET_BOT_Z - 0.015), "size": Vector3(CABINET_W, rail_h, 0.030)},
		{"pos": Vector3(-CABINET_W * 0.5 + 0.015, rail_y, CABINET_CENTER_Z), "size": Vector3(0.030, rail_h, CABINET_L)},
		{"pos": Vector3(CABINET_W * 0.5 - 0.015, rail_y, CABINET_CENTER_Z), "size": Vector3(0.030, rail_h, CABINET_L)},
		{"pos": Vector3(BAR_X, rail_y + 0.002, CABINET_CENTER_Z), "size": Vector3(0.088, rail_h + 0.004, CABINET_L - 0.04)},
	]

	for r in rails:
		var m = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = r["size"]
		box.material = mat_wood_rail
		m.mesh = box
		m.position = r["pos"]
		add_child(m)

		var trim = MeshInstance3D.new()
		var t_box = BoxMesh.new()
		t_box.size = Vector3(r["size"].x * 0.98, 0.003, r["size"].z * 0.45)
		t_box.material = mat_gold_trim
		trim.mesh = t_box
		trim.position = r["pos"] + Vector3(0, r["size"].y * 0.5 + 0.0015, 0)
		add_child(trim)

	# Twin 3D Brass Hinges on the Center Bar
	for hz in [CABINET_TOP_Z + 0.14, CABINET_BOT_Z - 0.14]:
		var hinge = MeshInstance3D.new()
		var h_cyl = CylinderMesh.new()
		h_cyl.top_radius = 0.011
		h_cyl.bottom_radius = 0.011
		h_cyl.height = 0.072
		h_cyl.material = mat_gold_trim
		hinge.mesh = h_cyl
		hinge.rotation_degrees = Vector3(90, 0, 0)
		hinge.position = Vector3(BAR_X, rail_y + 0.016, hz)
		add_child(hinge)


func _build_court_marquetry_emblem(center_pos: Vector3) -> void:
	var emblem_root = Node3D.new()
	emblem_root.position = center_pos
	add_child(emblem_root)

	for rot_y in [0.0, 45.0]:
		var sq = MeshInstance3D.new()
		var s_box = BoxMesh.new()
		s_box.size = Vector3(0.052, 0.0015, 0.052)
		s_box.material = mat_bronze_bevel
		sq.mesh = s_box
		sq.rotation_degrees = Vector3(0, rot_y, 0)
		emblem_root.add_child(sq)

	var core = MeshInstance3D.new()
	var c_cyl = CylinderMesh.new()
	c_cyl.top_radius = 0.016
	c_cyl.bottom_radius = 0.016
	c_cyl.height = 0.0025
	c_cyl.material = mat_gold_trim
	core.mesh = c_cyl
	emblem_root.add_child(core)


func _build_24_points() -> void:
	_point_source_rings.resize(24)
	_point_target_rings.resize(24)
	_point_last_rings.resize(24)

	var tri_half_w: float = 0.0365
	var tri_len: float = 0.372
	var dir_top_mesh = _create_point_triangle_mesh(tri_half_w, tri_len, 0.0045, 1.0)
	var dir_bot_mesh = _create_point_triangle_mesh(tri_half_w, tri_len, 0.0045, -1.0)
	var bevel_top_mesh = _create_point_triangle_mesh(tri_half_w + 0.003, tri_len + 0.008, 0.0025, 1.0)
	var bevel_bot_mesh = _create_point_triangle_mesh(tri_half_w + 0.003, tri_len + 0.008, 0.0025, -1.0)

	for i in range(24):
		var anchor: Vector3 = _point_positions[i]
		var is_top: bool = _point_is_top[i]
		var dir_z: float = 1.0 if is_top else -1.0

		var pt_root = Node3D.new()
		pt_root.name = "Point_%d" % i
		pt_root.position = anchor
		add_child(pt_root)

		# 1. Raised Bronze/Gold Bevel Triangle Base
		var bevel_inst = MeshInstance3D.new()
		bevel_inst.mesh = bevel_top_mesh if is_top else bevel_bot_mesh
		bevel_inst.material_override = mat_bronze_bevel
		pt_root.add_child(bevel_inst)

		# 2. Inner Satin Ivory or Royal Ruby-Garnet Inlaid Point Spear
		var tri_inst = MeshInstance3D.new()
		tri_inst.mesh = dir_top_mesh if is_top else dir_bot_mesh
		tri_inst.material_override = mat_point_light if (i % 2 == 0) else mat_point_dark
		tri_inst.position = Vector3(0, 0.001, 0)
		pt_root.add_child(tri_inst)

		# 3. 24K Gold Base Stud at the root of each point
		var stud = MeshInstance3D.new()
		var s_cyl = CylinderMesh.new()
		s_cyl.top_radius = 0.006
		s_cyl.bottom_radius = 0.007
		s_cyl.height = 0.006
		s_cyl.material = mat_gold_trim
		stud.mesh = s_cyl
		stud.position = Vector3(0, 0.004, dir_z * 0.012)
		pt_root.add_child(stud)

		# 4. Larger Persian Point Number (۱..۲۴) on the outer wooden rail
		var pt_num_fa = _fa_digits(24 - i)
		var num_lbl = _create_3d_label(pt_num_fa, 22, Color(1.0, 0.90, 0.62))
		num_lbl.position = Vector3(0, 0.030, -dir_z * 0.026)
		pt_root.add_child(num_lbl)

		# 5. Selectable Source Ring (Exact Original Thickness, Deep Dark Gold)
		var src_ring = MeshInstance3D.new()
		var sr_cyl = CylinderMesh.new()
		sr_cyl.top_radius = PIECE_RADIUS + 0.009
		sr_cyl.bottom_radius = PIECE_RADIUS + 0.012
		sr_cyl.height = 0.007
		sr_cyl.material = mat_ring_selectable
		src_ring.mesh = sr_cyl
		src_ring.position = Vector3(0, 0.005, dir_z * 0.044)
		src_ring.visible = false
		pt_root.add_child(src_ring)
		_point_source_rings[i] = src_ring

		# 6. Destination Target Ring (Glowing Emerald or Crimson Hit Ring)
		var tgt_ring = MeshInstance3D.new()
		var tr_cyl = CylinderMesh.new()
		tr_cyl.top_radius = PIECE_RADIUS + 0.010
		tr_cyl.bottom_radius = PIECE_RADIUS + 0.013
		tr_cyl.height = 0.008
		tr_cyl.material = mat_ring_target
		tgt_ring.mesh = tr_cyl
		tgt_ring.position = Vector3(0, 0.005, dir_z * 0.165)
		tgt_ring.visible = false
		pt_root.add_child(tgt_ring)
		_point_target_rings[i] = tgt_ring

		# 7. Last Move Ring
		var last_ring = MeshInstance3D.new()
		var lr_cyl = CylinderMesh.new()
		lr_cyl.top_radius = PIECE_RADIUS + 0.007
		lr_cyl.bottom_radius = PIECE_RADIUS + 0.009
		lr_cyl.height = 0.005
		lr_cyl.material = mat_ring_last_move
		last_ring.mesh = lr_cyl
		last_ring.position = Vector3(0, 0.004, dir_z * 0.044)
		last_ring.visible = false
		pt_root.add_child(last_ring)
		_point_last_rings[i] = last_ring

		# 8. Clickable Area3D covering the full point column
		var area = Area3D.new()
		area.name = "PointArea_%d" % i
		area.set_meta("hit_type", "point")
		area.set_meta("point_index", i)
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.076, 0.09, tri_len + 0.04)
		col.shape = shape
		area.add_child(col)
		area.position = Vector3(0, 0.03, dir_z * (tri_len * 0.5))
		pt_root.add_child(area)


func _create_point_triangle_mesh(half_w: float, length: float, height: float, dir_z: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var v_left = Vector3(-half_w, height, 0.0)
	var v_right = Vector3(half_w, height, 0.0)
	var v_tip = Vector3(0.0, height, dir_z * length)

	st.set_normal(Vector3.UP)
	if dir_z > 0.0:
		st.add_vertex(v_left)
		st.add_vertex(v_right)
		st.add_vertex(v_tip)
	else:
		st.add_vertex(v_right)
		st.add_vertex(v_left)
		st.add_vertex(v_tip)

	return st.commit()


func _build_bar_zones() -> void:
	# Center Bar Prison Wells for Hit Checkers (No text labels on top of pieces)
	var bar_configs = [
		{"gamer": 2, "z": CABINET_CENTER_Z - 0.175},
		{"gamer": 1, "z": CABINET_CENTER_Z + 0.175},
	]

	for bc in bar_configs:
		var g_id: int = bc["gamer"]
		var bz: float = bc["z"]
		var bar_node = Node3D.new()
		bar_node.name = "BarZone_P%d" % g_id
		bar_node.position = Vector3(BAR_X, SURFACE_Y + 0.028, bz)
		add_child(bar_node)

		var well = MeshInstance3D.new()
		var w_cyl = CylinderMesh.new()
		w_cyl.top_radius = PIECE_RADIUS + 0.004
		w_cyl.bottom_radius = PIECE_RADIUS + 0.004
		w_cyl.height = 0.005
		w_cyl.material = mat_velvet_well
		well.mesh = w_cyl
		bar_node.add_child(well)

		var ring = MeshInstance3D.new()
		var r_cyl = CylinderMesh.new()
		r_cyl.top_radius = PIECE_RADIUS + 0.011
		r_cyl.bottom_radius = PIECE_RADIUS + 0.014
		r_cyl.height = 0.008
		r_cyl.material = mat_ring_selectable
		ring.mesh = r_cyl
		ring.visible = false
		bar_node.add_child(ring)

		var area = Area3D.new()
		area.name = "BarArea_P%d" % g_id
		area.set_meta("hit_type", "bar")
		area.set_meta("gamer_id", g_id)
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.095, 0.10, 0.24)
		col.shape = shape
		area.add_child(col)
		area.position = Vector3(0, 0.03, 0)
		bar_node.add_child(area)

		if g_id == 1:
			_bar_p1_ring = ring
		else:
			_bar_p2_ring = ring

	# --- Hit / Out Piece Count on Center Bar (Sword icon and number directly on the piece) ---
	_bar_p1_count_lbl = _create_3d_label("", 28, Color(0.82, 0.52, 0.04))
	_bar_p1_count_lbl.visible = false
	add_child(_bar_p1_count_lbl)

	_bar_p2_count_lbl = _create_3d_label("", 28, Color(0.82, 0.52, 0.04))
	_bar_p2_count_lbl.visible = false
	add_child(_bar_p2_count_lbl)

	# Center Bar Rosette Medallion (at exact center of the bar: X = 0, Z = CABINET_CENTER_Z)
	var rosette = MeshInstance3D.new()
	var ros_cyl = CylinderMesh.new()
	ros_cyl.top_radius = 0.036
	ros_cyl.bottom_radius = 0.040
	ros_cyl.height = 0.008
	ros_cyl.material = mat_gold_trim
	rosette.mesh = ros_cyl
	rosette.position = Vector3(BAR_X, SURFACE_Y + 0.030, CABINET_CENTER_Z)
	add_child(rosette)

	var ros_inner = MeshInstance3D.new()
	var ri_cyl = CylinderMesh.new()
	ri_cyl.top_radius = 0.030
	ri_cyl.bottom_radius = 0.030
	ri_cyl.height = 0.010
	ri_cyl.material = mat_obsidian_bed
	ros_inner.mesh = ri_cyl
	ros_inner.position = Vector3(BAR_X, SURFACE_Y + 0.031, CABINET_CENTER_Z)
	add_child(ros_inner)

	_center_rosette_lbl = _create_3d_label("🎲", 28, Color(1.0, 0.90, 0.45))
	_center_rosette_lbl.position = Vector3(BAR_X, SURFACE_Y + 0.038, CABINET_CENTER_Z)
	add_child(_center_rosette_lbl)


# ==============================================================================
# BOTTOM 3D DICE TRAY & ALWAYS-VISIBLE TACTILE ROLL BUTTON CONSOLE
# ==============================================================================

func _build_bottom_dice_and_roll_console() -> void:
	# 1. Recessed Emerald Velvet 3D Dice Tray (Z = +0.445, Width = 1.06m, Length = 0.25m)
	var felt_bed = MeshInstance3D.new()
	var fb_mesh = BoxMesh.new()
	fb_mesh.size = Vector3(DICE_TRAY_W, 0.008, DICE_TRAY_L)
	fb_mesh.material = mat_velvet_tray
	felt_bed.mesh = fb_mesh
	felt_bed.position = Vector3(0, SURFACE_Y + 0.004, DICE_TRAY_Z)
	add_child(felt_bed)

	# Carved Mahogany & 24K Gold Walls around the Bottom Dice Tray
	for wall_cfg in [
		{"pos": Vector3(0, SURFACE_Y + 0.014, DICE_TRAY_Z - DICE_TRAY_L * 0.5), "size": Vector3(DICE_TRAY_W + 0.016, 0.022, 0.016)},
		{"pos": Vector3(0, SURFACE_Y + 0.014, DICE_TRAY_Z + DICE_TRAY_L * 0.5), "size": Vector3(DICE_TRAY_W + 0.016, 0.022, 0.016)},
		{"pos": Vector3(-DICE_TRAY_W * 0.5, SURFACE_Y + 0.014, DICE_TRAY_Z), "size": Vector3(0.016, 0.022, DICE_TRAY_L)},
		{"pos": Vector3(DICE_TRAY_W * 0.5, SURFACE_Y + 0.014, DICE_TRAY_Z), "size": Vector3(0.016, 0.022, DICE_TRAY_L)},
	]:
		var w_inst = MeshInstance3D.new()
		var w_box = BoxMesh.new()
		w_box.size = wall_cfg["size"]
		w_box.material = mat_wood_rail
		w_inst.mesh = w_box
		w_inst.position = wall_cfg["pos"]
		add_child(w_inst)

		var trim_inst = MeshInstance3D.new()
		var trim_box = BoxMesh.new()
		trim_box.size = Vector3(wall_cfg["size"].x * 0.98, 0.004, wall_cfg["size"].z * 0.65)
		trim_box.material = mat_gold_trim
		trim_inst.mesh = trim_box
		trim_inst.position = wall_cfg["pos"] + Vector3(0, 0.012, 0)
		add_child(trim_inst)

	# 4 Precision-Molded 3D Yatzy-Style Dice Slots inside the Bottom Dice Tray
	_dice_nodes.clear()
	for d_i in range(MAX_DICE_SLOTS):
		var slot_x = -0.345 + float(d_i) * 0.230
		var d_ui = _build_single_3d_die(d_i, Vector3(slot_x, SURFACE_Y + 0.008, DICE_TRAY_Z - 0.026))
		_dice_nodes.append(d_ui)

	# 2. Large Tactile 3D Roll Dice Button at the Bottom of the Board (Z = +0.665)
	_roll_btn_ui = _build_3d_roll_button(Vector3(0.0, SURFACE_Y + 0.018, ROLL_BTN_Z))


func _build_3d_roll_button(pos: Vector3) -> Dictionary:
	var btn_size = Vector3(0.82, 0.038, 0.142)
	var root = Node3D.new()
	root.name = "BtnRollDice3D"
	root.position = pos
	add_child(root)

	# 24K Gold Bezel Base
	var bezel = MeshInstance3D.new()
	var bz_box = BoxMesh.new()
	bz_box.size = btn_size + Vector3(0.024, -0.004, 0.024)
	bz_box.material = mat_gold_trim
	bezel.mesh = bz_box
	root.add_child(bezel)

	# Tactile Button Cap
	var cap = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = btn_size
	cap_box.material = mat_btn_roll_active
	cap.mesh = cap_box
	cap.position = Vector3(0, 0.006, 0)
	root.add_child(cap)

	# Twin 3D Decorative Mini-Dice Sculptures on Left & Right ends of the Button
	for side_x in [-0.345, 0.345]:
		var mini_ped = MeshInstance3D.new()
		var mp_cyl = CylinderMesh.new()
		mp_cyl.top_radius = 0.024
		mp_cyl.bottom_radius = 0.027
		mp_cyl.height = 0.006
		mp_cyl.material = mat_gold_trim
		mini_ped.mesh = mp_cyl
		mini_ped.position = Vector3(side_x, btn_size.y * 0.5 + 0.008, 0)
		root.add_child(mini_ped)

		var mini_die = MeshInstance3D.new()
		var md_box = BoxMesh.new()
		md_box.size = Vector3(0.030, 0.030, 0.030)
		md_box.material = mat_die_ivory
		mini_die.mesh = md_box
		mini_die.position = Vector3(side_x, btn_size.y * 0.5 + 0.023, 0)
		mini_die.rotation_degrees = Vector3(18, 32, -15)
		root.add_child(mini_die)

	var lbl = _create_3d_label("🎲 پرتاب تاس", 32, Color(1.0, 0.98, 0.90))
	lbl.position = Vector3(0, btn_size.y * 0.5 + 0.010, 0)
	root.add_child(lbl)

	var area = Area3D.new()
	area.name = "Area_RollDice"
	area.set_meta("hit_type", "btn_roll")
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = btn_size + Vector3(0.14, 0.12, 0.10)
	col.shape = shape
	area.add_child(col)
	root.add_child(area)

	return {
		"root": root,
		"cap": cap,
		"label": lbl,
	}


func _build_single_3d_die(die_idx: int, slot_pos: Vector3) -> Dictionary:
	var slot_root = Node3D.new()
	slot_root.name = "DieSlot_%d" % die_idx
	slot_root.position = slot_pos
	add_child(slot_root)

	# 1. Velvet & Brass Dice Well Pedestal
	var well_rim = MeshInstance3D.new()
	var wr_cyl = CylinderMesh.new()
	wr_cyl.top_radius = 0.056
	wr_cyl.bottom_radius = 0.060
	wr_cyl.height = 0.005
	wr_cyl.material = mat_gold_trim
	well_rim.mesh = wr_cyl
	well_rim.position = Vector3(0, 0.0025, 0)
	slot_root.add_child(well_rim)

	var well_bed = MeshInstance3D.new()
	var wb_cyl = CylinderMesh.new()
	wb_cyl.top_radius = 0.051
	wb_cyl.bottom_radius = 0.051
	wb_cyl.height = 0.006
	wb_cyl.material = mat_velvet_well
	well_bed.mesh = wb_cyl
	well_bed.position = Vector3(0, 0.0035, 0)
	slot_root.add_child(well_bed)

	# 2. Glowing Gold Selection Ring Pedestal (Visible when die is Active / Equipped)
	var lock_ring = MeshInstance3D.new()
	var lr_cyl = CylinderMesh.new()
	lr_cyl.top_radius = 0.062
	lr_cyl.bottom_radius = 0.066
	lr_cyl.height = 0.012
	lr_cyl.material = mat_die_lock_ring
	lock_ring.mesh = lr_cyl
	lock_ring.position = Vector3(0, 0.006, 0)
	lock_ring.visible = false
	slot_root.add_child(lock_ring)

	# 3. 3D Beveled Die Pivot (Yatzy-scale 0.084m)
	var die_pivot = Node3D.new()
	die_pivot.name = "DiePivot"
	die_pivot.position = Vector3(0, 0.052, 0)
	slot_root.add_child(die_pivot)

	var chamfer_core = MeshInstance3D.new()
	var core_box = BoxMesh.new()
	core_box.size = Vector3(DIE_SIZE * 0.94, DIE_SIZE * 0.94, DIE_SIZE * 0.94)
	core_box.material = mat_die_chamfer
	chamfer_core.mesh = core_box
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
		slab_box.material = mat_die_ivory
		slab_inst.mesh = slab_box
		die_pivot.add_child(slab_inst)
		face_meshes.append(slab_inst)

	_add_3d_die_pips(die_pivot, DIE_SIZE * 0.5)

	# 4. Larger Framed 3D Brass & Obsidian Numeral Plaque below each die well
	var badge_rim = MeshInstance3D.new()
	var br_box = BoxMesh.new()
	br_box.size = Vector3(0.146, 0.006, 0.058)
	br_box.material = mat_gold_trim
	badge_rim.mesh = br_box
	badge_rim.position = Vector3(0, 0.004, 0.096)
	slot_root.add_child(badge_rim)

	var badge_cap = MeshInstance3D.new()
	var bc_box = BoxMesh.new()
	bc_box.size = Vector3(0.138, 0.009, 0.050)
	bc_box.material = mat_die_badge_idle
	badge_cap.mesh = bc_box
	badge_cap.position = Vector3(0, 0.006, 0.096)
	slot_root.add_child(badge_cap)

	var val_lbl = _create_3d_label("۱", 28, Color(1.0, 0.96, 0.86))
	val_lbl.position = Vector3(0, 0.013, 0.096)
	slot_root.add_child(val_lbl)

	# 5. Clickable Area3D for Selecting this Die
	var die_area = Area3D.new()
	die_area.name = "DieArea_%d" % die_idx
	die_area.set_meta("hit_type", "die")
	die_area.set_meta("die_index", die_idx)
	var die_col = CollisionShape3D.new()
	var die_shape = BoxShape3D.new()
	die_shape.size = Vector3(0.26, 0.28, 0.28)
	die_col.shape = die_shape
	die_area.add_child(die_col)
	die_area.position = Vector3(0, 0.06, 0.03)
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
		var rad: float = 0.0102 if is_big else 0.0064

		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = rad
			cyl.bottom_radius = rad
			cyl.height = 0.0020
			cyl.radial_segments = 16
			cyl.material = mat_pip_red if is_red else mat_pip_dark
			pip.mesh = cyl
			pip.rotation_degrees = rot_d
			pip.position = n * (half_s + 0.0005) + r * p2.x + f * p2.y
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
# LATHE-TURNED 3D CHECKER PIECE BUILDER (Larger 0.083m Diameter Pucks)
# ==============================================================================

func _build_3d_checker_piece(gamer_id: int) -> Node3D:
	var root = Node3D.new()
	var is_p1: bool = (gamer_id == 1)
	var body_mat = mat_piece_p1 if is_p1 else mat_piece_p2
	var well_mat = mat_piece_p1_well if is_p1 else mat_piece_p2_well
	var trim_mat = mat_gold_trim if is_p1 else mat_platinum_trim

	var r: float = PIECE_RADIUS
	var h: float = PIECE_HEIGHT

	# 1. Green Billiard Felt Base Pad
	var felt = MeshInstance3D.new()
	var f_cyl = CylinderMesh.new()
	f_cyl.top_radius = r * 0.94
	f_cyl.bottom_radius = r * 0.94
	f_cyl.height = 0.002
	f_cyl.radial_segments = 28
	f_cyl.material = mat_felt_base
	felt.mesh = f_cyl
	felt.position.y = 0.001
	root.add_child(felt)

	# 2. Main Sculpted Puck Drum
	var body = MeshInstance3D.new()
	var b_cyl = CylinderMesh.new()
	b_cyl.top_radius = r * 0.97
	b_cyl.bottom_radius = r
	b_cyl.height = h * 0.78
	b_cyl.radial_segments = 28
	b_cyl.material = body_mat
	body.mesh = b_cyl
	body.position.y = 0.002 + h * 0.39
	root.add_child(body)

	# 3. Outer Raised Crown Lip
	var rim = MeshInstance3D.new()
	var r_torus = TorusMesh.new()
	r_torus.inner_radius = r * 0.68
	r_torus.outer_radius = r * 0.98
	r_torus.rings = 24
	r_torus.ring_segments = 14
	r_torus.material = body_mat
	rim.mesh = r_torus
	rim.scale = Vector3(1.0, 0.42, 1.0)
	rim.position.y = h * 0.80
	root.add_child(rim)

	# 4. Recessed Inner Dish Well
	var well = MeshInstance3D.new()
	var w_cyl = CylinderMesh.new()
	w_cyl.top_radius = r * 0.72
	w_cyl.bottom_radius = r * 0.72
	w_cyl.height = h * 0.16
	w_cyl.radial_segments = 24
	w_cyl.material = well_mat
	well.mesh = w_cyl
	well.position.y = h * 0.76
	root.add_child(well)

	# 5. Concentric Lathe-Turned Metallic Ring & Center Crown Medallion
	var ring = MeshInstance3D.new()
	var m_torus = TorusMesh.new()
	m_torus.inner_radius = r * 0.46
	m_torus.outer_radius = r * 0.56
	m_torus.rings = 24
	m_torus.ring_segments = 12
	m_torus.material = trim_mat
	ring.mesh = m_torus
	ring.scale = Vector3(1.0, 0.34, 1.0)
	ring.position.y = h * 0.86
	root.add_child(ring)

	var button = MeshInstance3D.new()
	var btn_sph = SphereMesh.new()
	btn_sph.radius = r * 0.25
	btn_sph.height = h * 0.28
	btn_sph.radial_segments = 18
	btn_sph.rings = 10
	btn_sph.material = trim_mat
	button.mesh = btn_sph
	button.position.y = h * 0.85
	root.add_child(button)

	return root


# ==============================================================================
# EXACT BACKGAMMON ENGINE & MOVE GENERATOR (1:1 WITH BACKEND & FLUTTER)
# ==============================================================================

func _init_board_state() -> void:
	board_spots.clear()
	for _i in range(24):
		board_spots.append({"count": 0, "equipped_user": -1})

	# Standard Backgammon Starting Setup (Matches BackGammonGameClass.init_board)
	# Player 1 (Red, moves 0 -> 23, bears off at 24)
	_set_spot(0, 1, 2)
	_set_spot(11, 1, 5)
	_set_spot(16, 1, 3)
	_set_spot(18, 1, 5)

	# Player 2 (Blue, moves 23 -> 0, bears off at -1)
	_set_spot(5, 2, 5)
	_set_spot(7, 2, 3)
	_set_spot(12, 2, 5)
	_set_spot(23, 2, 2)

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

	can_select_points.clear()
	can_hit_points.clear()
	can_target_points.clear()
	can_bear_off_sources.clear()


func _set_spot(idx: int, gamer_id: int, cnt: int) -> void:
	board_spots[idx] = {"count": cnt, "equipped_user": gamer_id}


func _check_gamer_is_in_end_phase(gamer_id: int) -> void:
	var piece_count: int = 0
	var start_idx: int = 18 if gamer_id == 1 else 0
	var end_idx: int = 24 if gamer_id == 1 else 6
	for idx in range(start_idx, end_idx):
		if board_spots[idx]["equipped_user"] == gamer_id:
			piece_count += int(board_spots[idx]["count"])

	if gamer_id == 1:
		p1_is_in_end_phase = (piece_count + p1_score == 15)
	else:
		p2_is_in_end_phase = (piece_count + p2_score == 15)


func _check_gamer_piece_is_out(gamer_id: int) -> bool:
	if gamer_id == 1:
		return p1_out_pieces != 0
	return p2_out_pieces != 0


func _is_valid_index(idx: int) -> bool:
	return idx >= 0 and idx <= 23


func _is_valid_index_in_end_phase(idx: int, gamer_id: int) -> bool:
	var is_end: bool = p1_is_in_end_phase if gamer_id == 1 else p2_is_in_end_phase
	if is_end:
		return (idx == 24) if gamer_id == 1 else (idx == -1)
	return false


func _is_enemy_spot(idx: int, gamer_id: int) -> bool:
	var eq: int = int(board_spots[idx]["equipped_user"])
	if eq <= 0 or eq == gamer_id:
		return false
	return true


func _is_single_spot(idx: int) -> bool:
	return int(board_spots[idx]["count"]) == 1


func _check_source_can_move_n_count(source_idx: int, dice_val: int, gamer_id: int) -> bool:
	var step: int = dice_val if gamer_id == 1 else -dice_val
	var next_idx: int = source_idx + step

	if _is_valid_index(next_idx):
		if _is_enemy_spot(next_idx, gamer_id) and not _is_single_spot(next_idx):
			return false
		return true
	elif _is_valid_index_in_end_phase(next_idx, gamer_id):
		return true
	return false


func _get_my_piece_indexes(gamer_id: int) -> Array[int]:
	var res: Array[int] = []
	for i in range(24):
		if int(board_spots[i]["equipped_user"]) == gamer_id and int(board_spots[i]["count"]) > 0:
			res.append(i)
	return res


func _has_available_move_for_die(dice_val: int, gamer_id: int) -> bool:
	if _check_gamer_piece_is_out(gamer_id):
		var bar_src: int = -1 if gamer_id == 1 else 24
		return _check_source_can_move_n_count(bar_src, dice_val, gamer_id)
	for pt in _get_my_piece_indexes(gamer_id):
		if _check_source_can_move_n_count(pt, dice_val, gamer_id):
			return true
	return false


func _has_any_available_move(gamer_id: int) -> bool:
	for d_val in current_dices:
		if _has_available_move_for_die(int(d_val), gamer_id):
			return true
	return false


func _auto_select_first_playable_die() -> void:
	var my_id: int = GameManager.my_player_index
	if current_dices.is_empty():
		equipped_dice_index = -1
		can_select_peace = false
		_recompute_active_possible_pieces()
		return

	if equipped_dice_index >= 0 and equipped_dice_index < current_dices.size():
		if _has_available_move_for_die(int(current_dices[equipped_dice_index]), my_id):
			can_select_peace = true
			_recompute_active_possible_pieces()
			return

	for i in range(current_dices.size()):
		if _has_available_move_for_die(int(current_dices[i]), my_id):
			equipped_dice_index = i
			can_select_peace = true
			_recompute_active_possible_pieces()
			return

	equipped_dice_index = 0
	can_select_peace = false
	_recompute_active_possible_pieces()


func _recompute_active_possible_pieces() -> void:
	can_select_points.clear()
	can_hit_points.clear()
	can_target_points.clear()
	can_bear_off_sources.clear()

	if not is_my_turn or not dices_rolled or equipped_dice_index < 0 or equipped_dice_index >= current_dices.size():
		return

	var my_id: int = GameManager.my_player_index
	var dice_val: int = int(current_dices[equipped_dice_index])
	var step: int = dice_val if my_id == 1 else -dice_val

	if _check_gamer_piece_is_out(my_id):
		var bar_src: int = -1 if my_id == 1 else 24
		if _check_source_can_move_n_count(bar_src, dice_val, my_id):
			var target_pt: int = bar_src + step
			if _is_valid_index(target_pt):
				can_hit_points.append(target_pt)
				can_target_points[target_pt] = bar_src
		return

	for pt in _get_my_piece_indexes(my_id):
		if _check_source_can_move_n_count(pt, dice_val, my_id):
			can_select_points.append(pt)
			var next_idx: int = pt + step
			if _is_valid_index(next_idx):
				if not can_target_points.has(next_idx):
					can_target_points[next_idx] = pt
			elif next_idx == 24 or next_idx == -1:
				can_bear_off_sources.append(pt)


# ==============================================================================
# 3D PIECE PLACEMENT, STACKING & VISUAL SYNCHRONIZATION
# ==============================================================================

func _get_point_piece_world_pos(point_idx: int, stack_idx: int, total_count: int) -> Vector3:
	var anchor: Vector3 = _point_positions[point_idx]
	var is_top: bool = _point_is_top[point_idx]
	var dir_z: float = 1.0 if is_top else -1.0

	var max_span: float = 0.285
	var default_step: float = 0.064
	var step: float = default_step
	if total_count > 5:
		step = max_span / float(max(total_count - 1, 1))

	var z_offset: float = 0.044 + float(stack_idx) * step
	var y_lift: float = 0.002 + (float(stack_idx) * 0.0022 if total_count > 5 else 0.0)
	return Vector3(anchor.x, anchor.y + y_lift, anchor.z + dir_z * z_offset)


func _get_bar_piece_world_pos(gamer_id: int, stack_idx: int) -> Vector3:
	var base_z: float = (CABINET_CENTER_Z - 0.175) if gamer_id == 2 else (CABINET_CENTER_Z + 0.175)
	var vis_idx: int = mini(stack_idx, 6)
	var z_stagger: float = float(vis_idx) * 0.006 * (1.0 if gamer_id == 1 else -1.0)
	return Vector3(BAR_X, SURFACE_Y + 0.030 + float(vis_idx) * (PIECE_HEIGHT * 0.85), base_z + z_stagger)


func _get_bear_off_piece_world_pos(gamer_id: int, stack_idx: int) -> Vector3:
	var vx: float = BEAR_P1_X if gamer_id == 1 else BEAR_P2_X
	var start_x: float = vx - 0.210
	var x_pos: float = start_x + float(clampi(stack_idx, 0, 14)) * 0.030
	return Vector3(x_pos, SURFACE_Y + 0.016, BEAR_VAULT_Z)


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

	# 1. Spawn All Checkers on the 24 Points (Dynamic compression up to 15 pieces, no text overlay)
	for pt in range(24):
		var cnt: int = int(board_spots[pt]["count"])
		var eq: int = int(board_spots[pt]["equipped_user"])
		var pt_arr: Array[Node3D] = []
		if cnt > 0 and (eq == 1 or eq == 2):
			for s_i in range(cnt):
				var p_node = _build_3d_checker_piece(eq)
				var w_pos = _get_point_piece_world_pos(pt, s_i, cnt)
				p_node.position = w_pos
				p_node.set_meta("base_y", w_pos.y)
				_pieces_container.add_child(p_node)
				pt_arr.append(p_node)
		_point_piece_nodes[pt] = pt_arr

	# 2. Spawn Hit Checkers on the Center Bar (P1 & P2)
	for s_i in range(p1_out_pieces):
		var p_node = _build_3d_checker_piece(1)
		p_node.position = _get_bar_piece_world_pos(1, s_i)
		_pieces_container.add_child(p_node)
		_bar_p1_nodes.append(p_node)

	for s_i in range(p2_out_pieces):
		var p_node = _build_3d_checker_piece(2)
		p_node.position = _get_bar_piece_world_pos(2, s_i)
		_pieces_container.add_child(p_node)
		_bar_p2_nodes.append(p_node)

	# 3. Spawn Borne-Off Checkers in the Top Bear-Off Vaults
	for s_i in range(mini(p1_score, 15)):
		var p_node = _build_3d_checker_piece(1)
		p_node.position = _get_bear_off_piece_world_pos(1, s_i)
		p_node.rotation_degrees = Vector3(0, 0, 78)
		p_node.scale = Vector3(0.78, 0.78, 0.78)
		_pieces_container.add_child(p_node)
		_bear_p1_nodes.append(p_node)

	for s_i in range(mini(p2_score, 15)):
		var p_node = _build_3d_checker_piece(2)
		p_node.position = _get_bear_off_piece_world_pos(2, s_i)
		p_node.rotation_degrees = Vector3(0, 0, 78)
		p_node.scale = Vector3(0.78, 0.78, 0.78)
		_pieces_container.add_child(p_node)
		_bear_p2_nodes.append(p_node)


func _refresh_ui_and_highlights() -> void:
	var my_id: int = GameManager.my_player_index

	# 1. Point Highlights (Source Gold Rings, Destination Target Emerald/Crimson Rings — No text clutter!)
	for i in range(24):
		var cnt: int = int(board_spots[i]["count"])
		var is_selectable_src: bool = (i in can_select_points)
		var is_target_dest: bool = can_target_points.has(i) or (i in can_hit_points)
		var is_blot_hit: bool = is_target_dest and _is_enemy_spot(i, my_id) and _is_single_spot(i)

		var src_ring: MeshInstance3D = _point_source_rings[i]
		if is_instance_valid(src_ring):
			src_ring.visible = is_selectable_src
			if is_selectable_src:
				var top_idx = maxi(cnt - 1, 0)
				var top_pos = _get_point_piece_world_pos(i, top_idx, maxi(cnt, 1))
				src_ring.position.z = (top_pos.z - _point_positions[i].z)

		var tgt_ring: MeshInstance3D = _point_target_rings[i]
		if is_instance_valid(tgt_ring):
			tgt_ring.visible = is_target_dest
			if is_target_dest:
				tgt_ring.material_override = mat_ring_hit_danger if is_blot_hit else mat_ring_target
				var dest_stack_idx = 0 if is_blot_hit else cnt
				var dest_pos = _get_point_piece_world_pos(i, dest_stack_idx, maxi(cnt + 1, 1))
				tgt_ring.position.z = (dest_pos.z - _point_positions[i].z)

		var last_ring: MeshInstance3D = _point_last_rings[i]
		if is_instance_valid(last_ring):
			last_ring.visible = (i == last_played_point and not is_selectable_src and not is_target_dest)

	# 2. Bar Hit Piece Count Displays (Sword icon and number directly on the piece) & Highlights
	if is_instance_valid(_bar_p1_count_lbl):
		if p1_out_pieces > 0:
			_bar_p1_count_lbl.visible = true
			var top_p1_pos = _get_bar_piece_world_pos(1, maxi(p1_out_pieces - 1, 0))
			_bar_p1_count_lbl.position = Vector3(BAR_X, top_p1_pos.y + PIECE_HEIGHT * 0.85 + 0.005, top_p1_pos.z)
			_bar_p1_count_lbl.text = "⚔️ " + _fa_digits(p1_out_pieces)
		else:
			_bar_p1_count_lbl.visible = false

	if is_instance_valid(_bar_p2_count_lbl):
		if p2_out_pieces > 0:
			_bar_p2_count_lbl.visible = true
			var top_p2_pos = _get_bar_piece_world_pos(2, maxi(p2_out_pieces - 1, 0))
			_bar_p2_count_lbl.position = Vector3(BAR_X, top_p2_pos.y + PIECE_HEIGHT * 0.85 + 0.005, top_p2_pos.z)
			_bar_p2_count_lbl.text = "⚔️ " + _fa_digits(p2_out_pieces)
		else:
			_bar_p2_count_lbl.visible = false

	var is_bar_p1_sel: bool = (is_my_turn and my_id == 1 and p1_out_pieces > 0 and not can_hit_points.is_empty())
	if is_instance_valid(_bar_p1_ring):
		_bar_p1_ring.visible = is_bar_p1_sel

	var is_bar_p2_sel: bool = (is_my_turn and my_id == 2 and p2_out_pieces > 0 and not can_hit_points.is_empty())
	if is_instance_valid(_bar_p2_ring):
		_bar_p2_ring.visible = is_bar_p2_sel

	# 3. Top Bear-Off Vault Highlights
	if is_instance_valid(_bear_p1_ring):
		_bear_p1_ring.visible = (is_my_turn and my_id == 1 and not can_bear_off_sources.is_empty())
	if is_instance_valid(_bear_p2_ring):
		_bear_p2_ring.visible = (is_my_turn and my_id == 2 and not can_bear_off_sources.is_empty())

	# 4. Center Bar Medallion Display
	if is_instance_valid(_center_rosette_lbl):
		if dices_rolled and equipped_dice_index >= 0 and equipped_dice_index < current_dices.size():
			_center_rosette_lbl.text = _fa_digits(current_dices[equipped_dice_index])
			_center_rosette_lbl.modulate = Color(1.0, 0.92, 0.38)
		else:
			_center_rosette_lbl.text = "🎲"
			_center_rosette_lbl.modulate = Color(0.95, 0.82, 0.45)

	# 5. Bottom 3D Dice Tray Slots
	var num_d: int = current_dices.size()
	var show_preview_dice: bool = (not dices_rolled or num_d == 0)
	var display_count: int = 2 if show_preview_dice else num_d
	var span_step: float = 0.235 if display_count > 2 else 0.300
	var start_x: float = -float(display_count - 1) * span_step * 0.5

	for d_i in range(MAX_DICE_SLOTS):
		var d_ui = _dice_nodes[d_i]
		var slot: Node3D = d_ui["slot"]
		if d_i < display_count:
			slot.visible = true
			slot.position.x = start_x + float(d_i) * span_step
			if show_preview_dice:
				var prev_val: int = 6 if d_i == 0 else 5
				d_ui["lock_ring"].visible = false
				d_ui["badge_cap"].material_override = mat_die_badge_idle
				d_ui["label"].text = "🎲 " + _fa_digits(prev_val)
				d_ui["label"].modulate = Color(0.78, 0.76, 0.70)
				for slab in d_ui["slabs"]:
					slab.material_override = mat_die_preview
				if not _is_rolling_dice:
					d_ui["pivot"].rotation = _get_die_target_rotation(prev_val)
			else:
				var d_val: int = int(current_dices[d_i])
				var is_sel: bool = (is_my_turn and d_i == equipped_dice_index)
				var is_playable: bool = _has_available_move_for_die(d_val, my_id) if is_my_turn else true

				d_ui["lock_ring"].visible = is_sel
				d_ui["badge_cap"].material_override = mat_die_badge_selected if is_sel else mat_die_badge_idle
				d_ui["label"].text = ("✓ تاس " + _fa_digits(d_val)) if is_sel else ("تاس " + _fa_digits(d_val))
				d_ui["label"].modulate = Color(1.0, 0.98, 0.85) if is_playable else Color(0.55, 0.55, 0.55)

				for slab in d_ui["slabs"]:
					slab.material_override = mat_die_selected if is_sel else mat_die_ivory

				if not _is_rolling_dice:
					d_ui["pivot"].rotation = _get_die_target_rotation(d_val)
		else:
			slot.visible = false

	# 6. Always-Visible Bottom 3D Roll Dice Button State
	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var btn_cap: MeshInstance3D = _roll_btn_ui["cap"]
		var btn_lbl: Label3D = _roll_btn_ui["label"]
		_roll_btn_ui["root"].visible = true

		if not GameManager.is_game_active:
			btn_cap.material_override = mat_btn_roll_disabled
			btn_lbl.text = "🎲 آماده شروع بازی..."
			btn_lbl.modulate = Color(0.88, 0.86, 0.80)
		elif is_my_turn and not dices_rolled:
			btn_cap.material_override = mat_btn_roll_active
			btn_lbl.text = "🎲 پرتاب تاس"
			btn_lbl.modulate = Color(1.0, 0.98, 0.90)
		elif is_my_turn and dices_rolled:
			if not current_dices.is_empty() and _has_any_available_move(my_id):
				btn_cap.material_override = mat_btn_roll_moved
				btn_lbl.text = "✨ حرکت دهید (%s)" % _fa_digits(current_dices.size())
				btn_lbl.modulate = Color(0.95, 0.96, 1.0)
			else:
				btn_cap.material_override = mat_btn_roll_disabled
				btn_lbl.text = "⚠️ بدون حرکت مجاز..."
				btn_lbl.modulate = Color(1.0, 0.68, 0.62)
		else:
			btn_cap.material_override = mat_btn_roll_disabled
			btn_lbl.text = "⏳ نوبت حریف..."
			btn_lbl.modulate = Color(0.75, 0.78, 0.84)


func _sync_hud_scores() -> void:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if hud and hud.has_method("update_scores"):
		hud.update_scores(p1_score, p2_score)


# ==============================================================================
# BASEGAMEBOARD LIFECYCLE & NETWORK EVENT HANDLERS
# ==============================================================================

func setup_board(_game_data: Dictionary) -> void:
	_init_board_state()
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()
	_sync_hud_scores()


func on_start_game() -> void:
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index)
	is_board_locked = not is_my_turn
	_refresh_ui_and_highlights()


func on_turn_changed(turn: int, is_me: bool) -> void:
	super.on_turn_changed(turn, is_me)
	my_player_index = GameManager.my_player_index
	current_turn = turn
	is_my_turn = is_me
	is_board_locked = not is_me

	# Guard against sync_turn_state() wiping restored dice right after on_reconnect_data()
	if Time.get_ticks_msec() < _reconnect_guard_msec:
		if is_my_turn and dices_rolled and not current_dices.is_empty():
			_auto_select_first_playable_die()
		_refresh_ui_and_highlights()
		return

	dices_rolled = false
	current_dices.clear()
	equipped_dice_index = -1
	can_select_peace = false
	can_select_points.clear()
	can_hit_points.clear()
	can_target_points.clear()
	can_bear_off_sources.clear()
	_refresh_ui_and_highlights()


func on_roll_result(payload: Dictionary) -> void:
	# Server payload: {"dices": [d1, d2]} or {"dices": [d, d, d, d]} on doubles
	var raw_dices = payload.get("dices", [])
	current_dices.clear()
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))

	dices_rolled = true
	if is_my_turn:
		_auto_select_first_playable_die()
	else:
		equipped_dice_index = 0 if not current_dices.is_empty() else -1
		can_select_peace = false
		can_select_points.clear()
		can_hit_points.clear()
		can_target_points.clear()
		can_bear_off_sources.clear()

	_animate_dice_roll()
	_refresh_ui_and_highlights()


func on_out_of_move(payload: Dictionary) -> void:
	# Server payload: {"turn": turn, "dices": [...]} when roll has no legal moves (4s auto pass_turn on server)
	var raw_dices = payload.get("dices", [])
	current_dices.clear()
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))

	dices_rolled = true
	equipped_dice_index = -1
	can_select_peace = false
	can_select_points.clear()
	can_hit_points.clear()
	can_target_points.clear()
	can_bear_off_sources.clear()

	_animate_dice_roll()
	_refresh_ui_and_highlights()
	AudioManager.play_sound("tap_wrong")

	var turn_id: int = int(payload.get("turn", current_turn))
	if turn_id == GameManager.my_player_index:
		show_hint("هیچ حرکت مجازی با این تاس وجود ندارد! تعویض نوبت...")
	else:
		show_hint("حریف هیچ حرکت مجازی ندارد! تعویض نوبت...")

	# Sync HUD countdown to Backend's BackGammon_Out_Of_Move_time (4.0s)
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if hud and hud.has_method("start_turn_timer"):
		hud.start_turn_timer(4.0)


func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	# Server payload: {"gamer_id": 1|2, "index": -1..24, "dice_index": 0..3}
	var gamer_id: int = int(extra.get("gamer_id", user_id))
	var source_idx: int = int(extra.get("index", target_peace))
	var d_idx: int = int(extra.get("dice_index", 0))

	if d_idx < 0 or d_idx >= current_dices.size():
		if not current_dices.is_empty():
			d_idx = 0
		else:
			return

	var dice_val: int = int(current_dices[d_idx])
	current_dices.remove_at(d_idx)
	equipped_dice_index = -1
	can_select_peace = false

	_apply_move_and_animate(source_idx, dice_val, gamer_id)


func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != 24:
		return
	var raw_board: Array = new_board as Array
	board_spots.clear()
	for item in raw_board:
		if typeof(item) == TYPE_DICTIONARY:
			var cnt: int = int(item.get("count", 0))
			var eq: int = int(item.get("equipped_user", item.get("selected_user", -1)))
			if cnt <= 0 or eq <= 0:
				eq = -1
				cnt = 0
			board_spots.append({
				"count": cnt,
				"equipped_user": eq,
			})
		else:
			board_spots.append({"count": 0, "equipped_user": -1})
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()


func on_reconnect_data(payload: Dictionary) -> void:
	_reconnect_guard_msec = Time.get_ticks_msec() + 800
	_is_rolling_dice = false
	_is_animating_move = false
	my_player_index = GameManager.my_player_index

	var g_data = payload.get("game_data", payload)
	if typeof(g_data) != TYPE_DICTIONARY or g_data.is_empty():
		return

	# 1. Board spots (24 points)
	var raw_board = g_data.get("board", [])
	if typeof(raw_board) == TYPE_ARRAY and (raw_board as Array).size() == 24:
		sync_board_state(raw_board)

	# 2. Scores: Backend sends Array [p1_score, p2_score]
	var raw_scores = g_data.get("scores", [])
	if typeof(raw_scores) == TYPE_ARRAY and (raw_scores as Array).size() >= 2:
		p1_score = int(raw_scores[0])
		p2_score = int(raw_scores[1])
	elif typeof(raw_scores) == TYPE_DICTIONARY:
		p1_score = int(raw_scores.get("player_1_score", p1_score))
		p2_score = int(raw_scores.get("player_2_score", p2_score))

	# 3. Out pieces (Bar): Backend sends Array [p1_out_pieces, p2_out_pieces]
	var raw_out = g_data.get("out_pieces", [])
	if typeof(raw_out) == TYPE_ARRAY and (raw_out as Array).size() >= 2:
		p1_out_pieces = int(raw_out[0])
		p2_out_pieces = int(raw_out[1])
	elif typeof(raw_out) == TYPE_DICTIONARY:
		p1_out_pieces = int(raw_out.get("player_1", 0))
		p2_out_pieces = int(raw_out.get("player_2", 0))

	# 4. End phases: Backend sends Array [p1_is_in_end_phase, p2_is_in_end_phase]
	var raw_end = g_data.get("end_phases", [])
	if typeof(raw_end) == TYPE_ARRAY and (raw_end as Array).size() >= 2:
		p1_is_in_end_phase = bool(raw_end[0])
		p2_is_in_end_phase = bool(raw_end[1])
	elif typeof(raw_end) == TYPE_DICTIONARY:
		p1_is_in_end_phase = bool(raw_end.get("player_1", false))
		p2_is_in_end_phase = bool(raw_end.get("player_2", false))
	else:
		_check_gamer_is_in_end_phase(1)
		_check_gamer_is_in_end_phase(2)

	# 5. Current dices & rolled state: Backend sends "current_turn_player_rolled" and "current_dices"
	current_dices.clear()
	var raw_dices = g_data.get("current_dices", [])
	if typeof(raw_dices) == TYPE_ARRAY:
		for d in raw_dices:
			current_dices.append(int(d))

	if g_data.has("current_turn_player_rolled"):
		dices_rolled = bool(g_data.get("current_turn_player_rolled", false))
	elif g_data.has("dices_rolled"):
		dices_rolled = bool(g_data.get("dices_rolled", false))
	else:
		dices_rolled = not current_dices.is_empty()

	# 6. Turn state: Backend sends "current_turn"
	var t: int = int(g_data.get("current_turn", g_data.get("turn", GameManager.current_turn)))
	GameManager.current_turn = t
	current_turn = t
	is_my_turn = (t == my_player_index)
	is_board_locked = not is_my_turn

	if is_my_turn and dices_rolled and not current_dices.is_empty():
		_auto_select_first_playable_die()
	else:
		equipped_dice_index = 0 if (dices_rolled and not current_dices.is_empty()) else -1
		can_select_peace = false
		can_select_points.clear()
		can_hit_points.clear()
		can_target_points.clear()
		can_bear_off_sources.clear()

	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()
	_sync_hud_scores()


func reset_board() -> void:
	_init_board_state()
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()


func cleanup_board() -> void:
	_is_animating_move = false
	_is_rolling_dice = false


# ==============================================================================
# STATE MUTATION + 3D PARABOLIC FLIGHT & RICH VFX
# ==============================================================================

func _apply_move_and_animate(source_idx: int, dice_val: int, gamer_id: int) -> void:
	var step: int = dice_val if gamer_id == 1 else -dice_val
	var target_idx: int = source_idx + step

	# Capture start 3D position for flight animation before mutating board_spots
	var start_pos: Vector3 = Vector3.ZERO
	if source_idx == -1 or source_idx == 24:
		var out_cnt = p1_out_pieces if gamer_id == 1 else p2_out_pieces
		start_pos = _get_bar_piece_world_pos(gamer_id, maxi(out_cnt - 1, 0))
	elif _is_valid_index(source_idx):
		var src_cnt: int = int(board_spots[source_idx]["count"])
		start_pos = _get_point_piece_world_pos(source_idx, maxi(src_cnt - 1, 0), maxi(src_cnt, 1))

	# 1. Mutate Source (Matches BackGammonGameClass.select_peace)
	if source_idx == -1 or source_idx == 24:
		if gamer_id == 1:
			p1_out_pieces = maxi(0, p1_out_pieces - 1)
		else:
			p2_out_pieces = maxi(0, p2_out_pieces - 1)
	elif _is_valid_index(source_idx):
		var new_src_cnt: int = int(board_spots[source_idx]["count"]) - 1
		board_spots[source_idx]["count"] = maxi(0, new_src_cnt)
		if new_src_cnt <= 0:
			board_spots[source_idx]["equipped_user"] = -1

	# 2. Mutate Target (Normal Move, Blot Hit, or Bear-Off)
	var was_blot_hit: bool = false
	var hit_enemy_id: int = 2 if gamer_id == 1 else 1
	var end_pos: Vector3 = Vector3.ZERO

	if _is_valid_index(target_idx):
		last_played_point = target_idx
		if _is_enemy_spot(target_idx, gamer_id):
			was_blot_hit = true
			board_spots[target_idx]["equipped_user"] = gamer_id
			board_spots[target_idx]["count"] = 1
			if gamer_id == 1:
				p2_out_pieces += 1
			else:
				p1_out_pieces += 1
		else:
			board_spots[target_idx]["equipped_user"] = gamer_id
			board_spots[target_idx]["count"] = int(board_spots[target_idx]["count"]) + 1

		var tgt_cnt: int = int(board_spots[target_idx]["count"])
		end_pos = _get_point_piece_world_pos(target_idx, maxi(tgt_cnt - 1, 0), maxi(tgt_cnt, 1))
	elif target_idx == 24 or target_idx == -1:
		last_played_point = -99
		if gamer_id == 1:
			p1_score += 1
			end_pos = _get_bear_off_piece_world_pos(1, maxi(p1_score - 1, 0))
		else:
			p2_score += 1
			end_pos = _get_bear_off_piece_world_pos(2, maxi(p2_score - 1, 0))

	# 3. Recompute End-Phase Eligibility for Both Players
	_check_gamer_is_in_end_phase(1)
	_check_gamer_is_in_end_phase(2)
	_sync_hud_scores()

	# 4. If my turn still has remaining dice & moves, auto-select next playable die
	if is_my_turn and not current_dices.is_empty():
		if _has_any_available_move(GameManager.my_player_index):
			_auto_select_first_playable_die()
		else:
			equipped_dice_index = -1
			can_select_peace = false
			can_select_points.clear()
			can_hit_points.clear()
			can_target_points.clear()
			can_bear_off_sources.clear()
			show_hint("با تاس باقی‌مانده هیچ حرکت مجازی وجود ندارد!")
	else:
		can_select_points.clear()
		can_hit_points.clear()
		can_target_points.clear()
		can_bear_off_sources.clear()

	# 5. Play 3D Parabolic Flight & Impact VFX
	_animate_checker_flight(gamer_id, start_pos, end_pos, target_idx, was_blot_hit, hit_enemy_id)


func _animate_checker_flight(gamer_id: int, start_pos: Vector3, end_pos: Vector3, target_idx: int, was_blot_hit: bool, hit_enemy_id: int) -> void:
	_is_animating_move = true
	_rebuild_all_3d_pieces()
	_refresh_ui_and_highlights()

	# Hide the newly spawned destination piece while the flying clone is in mid-air
	var hidden_dest_piece: Node3D = null
	if _is_valid_index(target_idx) and _point_piece_nodes.has(target_idx):
		var arr: Array = _point_piece_nodes[target_idx]
		if not arr.is_empty():
			hidden_dest_piece = arr[arr.size() - 1]
			if is_instance_valid(hidden_dest_piece):
				hidden_dest_piece.visible = false
	elif target_idx == 24 and not _bear_p1_nodes.is_empty():
		hidden_dest_piece = _bear_p1_nodes[_bear_p1_nodes.size() - 1]
		if is_instance_valid(hidden_dest_piece):
			hidden_dest_piece.visible = false
	elif target_idx == -1 and not _bear_p2_nodes.is_empty():
		hidden_dest_piece = _bear_p2_nodes[_bear_p2_nodes.size() - 1]
		if is_instance_valid(hidden_dest_piece):
			hidden_dest_piece.visible = false

	var hidden_bar_piece: Node3D = null
	if was_blot_hit:
		var bar_arr = _bar_p1_nodes if hit_enemy_id == 1 else _bar_p2_nodes
		if not bar_arr.is_empty():
			hidden_bar_piece = bar_arr[bar_arr.size() - 1]
			if is_instance_valid(hidden_bar_piece):
				hidden_bar_piece.visible = false

	_spawn_3d_ring_burst(start_pos, Color(1.0, 0.85, 0.30), 0.08)

	var flyer = _build_3d_checker_piece(gamer_id)
	flyer.position = start_pos
	add_child(flyer)

	var dist: float = start_pos.distance_to(end_pos)
	var arc_h: float = clampf(0.11 + dist * 0.22, 0.12, 0.28)
	var dur: float = clampf(0.28 + dist * 0.14, 0.28, 0.46)

	var tw = create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(flyer):
			return
		var p = start_pos.lerp(end_pos, t)
		p.y += sin(t * PI) * arc_h
		flyer.position = p
		flyer.rotation.x = sin(t * PI) * 0.18
	, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.tween_callback(func():
		if is_instance_valid(flyer):
			flyer.queue_free()
		if is_instance_valid(hidden_dest_piece):
			hidden_dest_piece.visible = true

		AudioManager.sfx_move_piece()
		_is_animating_move = false

		if was_blot_hit:
			AudioManager.play_sound("hit")
			var bar_dest = _get_bar_piece_world_pos(hit_enemy_id, maxi((p1_out_pieces if hit_enemy_id == 1 else p2_out_pieces) - 1, 0))
			_spawn_hit_explosion_vfx(end_pos, hit_enemy_id, bar_dest, hidden_bar_piece)
		elif target_idx == 24 or target_idx == -1:
			AudioManager.sfx_add_piece()
			_spawn_bear_off_celebration_vfx(end_pos, gamer_id)
		else:
			var land_col = Color(1.0, 0.36, 0.32) if gamer_id == 1 else Color(0.32, 0.68, 1.0)
			_spawn_3d_ring_burst(end_pos, land_col, 0.10)
	)


func _animate_dice_roll() -> void:
	_is_rolling_dice = true
	AudioManager.sfx_dice()

	var is_doubles: bool = (current_dices.size() == 4)
	for d_i in range(current_dices.size()):
		if d_i >= _dice_nodes.size():
			break
		var d_ui = _dice_nodes[d_i]
		var pivot: Node3D = d_ui["pivot"]
		var target_rot = _get_die_target_rotation(int(current_dices[d_i]))

		pivot.position.y = 0.20 + float(d_i) * 0.025
		pivot.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(pivot, "position:y", 0.052, 0.44 + float(d_i) * 0.05).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(pivot, "rotation", target_rot + Vector3(TAU * 2.0, TAU, TAU * 2.0), 0.42 + float(d_i) * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			if is_instance_valid(pivot):
				pivot.rotation = target_rot
				var impact_col = Color(1.0, 0.85, 0.25) if is_doubles else Color(0.95, 0.90, 0.72)
				_spawn_3d_ring_burst(d_ui["slot"].global_position + Vector3(0, 0.01, 0), impact_col, 0.12 if is_doubles else 0.08)
		)

	get_tree().create_timer(0.56).timeout.connect(func():
		if is_instance_valid(self):
			_is_rolling_dice = false
			_refresh_ui_and_highlights()
	)


# ==============================================================================
# 3D VISUAL EFFECTS (SHOCKWAVES, BLOT HIT LAUNCH, BEAR-OFF PILLAR, SPARKLES)
# ==============================================================================

func _spawn_3d_ring_burst(pos: Vector3, col: Color, max_r: float = 0.12) -> void:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = max_r * 0.72
	torus.outer_radius = max_r
	torus.rings = 20
	torus.ring_segments = 12

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	torus.material = mat
	ring.mesh = torus
	ring.position = pos + Vector3(0, 0.008, 0)
	ring.scale = Vector3(0.15, 1.0, 0.15)
	add_child(ring)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.4, 1.0, 1.4), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.36)
	tw.chain().tween_callback(ring.queue_free)


func _spawn_hit_explosion_vfx(hit_pos: Vector3, hit_enemy_id: int, bar_dest: Vector3, hit_bar_piece: Node3D) -> void:
	_spawn_3d_ring_burst(hit_pos, Color(1.0, 0.22, 0.16), 0.15)
	_spawn_3d_ring_burst(hit_pos, Color(1.0, 0.78, 0.20), 0.10)

	for i in range(10):
		var spark = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.011, 0.011, 0.011)
		var s_mat = StandardMaterial3D.new()
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s_mat.albedo_color = Color(1.0, 0.65, 0.18) if (i % 2 == 0) else Color(1.0, 0.24, 0.20)
		box.material = s_mat
		spark.mesh = box
		spark.position = hit_pos + Vector3(0, 0.015, 0)
		add_child(spark)

		var angle = float(i) * (TAU / 10.0)
		var target_p = hit_pos + Vector3(cos(angle) * 0.12, 0.07, sin(angle) * 0.12)
		var s_tw = create_tween()
		s_tw.set_parallel(true)
		s_tw.tween_property(spark, "position", target_p, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(spark, "scale", Vector3.ZERO, 0.32)
		s_tw.chain().tween_callback(spark.queue_free)

	var knocked = _build_3d_checker_piece(hit_enemy_id)
	knocked.position = hit_pos
	add_child(knocked)

	var k_tw = create_tween()
	k_tw.tween_method(func(t: float):
		if not is_instance_valid(knocked):
			return
		var p = hit_pos.lerp(bar_dest, t)
		p.y += sin(t * PI) * 0.24
		knocked.position = p
		knocked.rotation.z = t * TAU
	, 0.0, 1.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	k_tw.tween_callback(func():
		if is_instance_valid(knocked):
			knocked.queue_free()
		if is_instance_valid(hit_bar_piece):
			hit_bar_piece.visible = true
		_spawn_3d_ring_burst(bar_dest, Color(1.0, 0.45, 0.20), 0.09)
	)


func _spawn_bear_off_celebration_vfx(tray_pos: Vector3, gamer_id: int) -> void:
	var col = Color(1.0, 0.84, 0.24) if gamer_id == 1 else Color(0.38, 0.88, 1.0)
	_spawn_3d_ring_burst(tray_pos, col, 0.13)

	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.044
	cyl.height = 0.24
	var p_mat = StandardMaterial3D.new()
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(col.r, col.g, col.b, 0.78)
	cyl.material = p_mat
	pillar.mesh = cyl
	pillar.position = tray_pos + Vector3(0, 0.12, 0)
	add_child(pillar)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(pillar, "scale", Vector3(1.6, 1.5, 1.6), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.42)
	tw.chain().tween_callback(pillar.queue_free)


func _emit_ambient_selection_sparkles() -> void:
	if can_select_points.is_empty() and can_hit_points.is_empty():
		return

	var pos: Vector3 = Vector3.ZERO
	if not can_select_points.is_empty():
		var pt: int = can_select_points[randi() % can_select_points.size()]
		var cnt: int = int(board_spots[pt]["count"])
		pos = _get_point_piece_world_pos(pt, maxi(cnt - 1, 0), maxi(cnt, 1))
	else:
		var my_id: int = GameManager.my_player_index
		var out_cnt = p1_out_pieces if my_id == 1 else p2_out_pieces
		pos = _get_bar_piece_world_pos(my_id, maxi(out_cnt - 1, 0))

	var orb = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.004
	sph.height = 0.008
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.72, 0.44, 0.02, 0.75)
	sph.material = mat
	orb.mesh = sph
	orb.position = pos + Vector3(randf_range(-0.020, 0.020), 0.018, randf_range(-0.020, 0.020))
	add_child(orb)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(orb, "position:y", orb.position.y + 0.055, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(orb.queue_free)


# ==============================================================================
# UNIFIED 3D RAYCAST INPUT HANDLER (Matches Yatzy3D & GAME_SCENE_RULES.md)
# ==============================================================================

var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_down_time: float = 0.0
var _is_pointer_down: bool = false
var _last_handled_tap_time: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active or _is_animating_move:
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
				if dist <= 42.0 and elapsed < 0.90:
					if now - _last_handled_tap_time >= 0.12:
						_last_handled_tap_time = now
						if _handle_screen_tap(event.position):
							get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
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
				if dist <= 42.0 and elapsed < 0.90:
					if now - _last_handled_tap_time >= 0.12:
						_last_handled_tap_time = now
						if _handle_screen_tap(event.position):
							get_viewport().set_input_as_handled()


func _handle_screen_tap(screen_pos: Vector2) -> bool:
	var viewport = get_viewport()
	if not viewport:
		return false
	var cam = viewport.get_camera_3d()
	if not cam:
		return false

	var from = cam.project_ray_origin(screen_pos)
	var dir = cam.project_ray_normal(screen_pos)
	var to = from + dir * 15.0

	# 1. Check 3D Board Plane Intersection first for ultra-reliable Dice Tray & Roll Button tapping!
	var board_plane = Plane(Vector3.UP, SURFACE_Y + 0.04)
	var plane_hit = board_plane.intersects_ray(from, dir)
	if plane_hit != null:
		var local_hit: Vector3 = to_local(plane_hit)
		# Roll Button Zone (Z around ROLL_BTN_Z = 0.665)
		if absf(local_hit.x) <= 0.48 and absf(local_hit.z - ROLL_BTN_Z) <= 0.095:
			_mark_interaction()
			_on_roll_button_tapped()
			return true
		# Bottom Dice Tray Zone (Z around DICE_TRAY_Z = 0.445)
		if absf(local_hit.x) <= (DICE_TRAY_W * 0.52) and absf(local_hit.z - DICE_TRAY_Z) <= (DICE_TRAY_L * 0.56):
			_mark_interaction()
			var best_die_idx: int = _find_nearest_visible_die(local_hit.x)
			if best_die_idx >= 0:
				_on_die_tapped(best_die_idx)
				return true

	# 2. Physics Area3D Raycast for Points, Bar, Bear-Off, Dice & Button
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_ray(query)
	if result.is_empty() or not result.has("collider"):
		return false

	var col: Object = result["collider"]
	if not col or not col.has_meta("hit_type"):
		return false

	_mark_interaction()
	var hit_type: String = str(col.get_meta("hit_type"))
	match hit_type:
		"btn_roll":
			_on_roll_button_tapped()
			return true
		"die":
			var d_idx: int = int(col.get_meta("die_index"))
			_on_die_tapped(d_idx)
			return true
		"bar":
			var g_id: int = int(col.get_meta("gamer_id"))
			_on_bar_tapped(g_id)
			return true
		"bear_off":
			var g_id: int = int(col.get_meta("gamer_id"))
			_on_bear_off_tapped(g_id)
			return true
		"point":
			var pt_idx: int = int(col.get_meta("point_index"))
			_on_point_tapped(pt_idx)
			return true
	return false


func _find_nearest_visible_die(local_x: float) -> int:
	var best_idx: int = -1
	var best_dist: float = 999.0
	for i in range(_dice_nodes.size()):
		var slot: Node3D = _dice_nodes[i]["slot"]
		if is_instance_valid(slot) and slot.visible:
			var d: float = absf(local_x - slot.position.x)
			if d < best_dist:
				best_dist = d
				best_idx = i
	return best_idx


func _on_roll_button_tapped() -> void:
	if not GameManager.is_game_active:
		return

	# Ensure turn state is synced with GameManager
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index)

	if not is_my_turn:
		AudioManager.play_sound("miss_turn")
		show_hint("هنوز نوبت شما نیست!")
		return
	if dices_rolled:
		AudioManager.play_sound("miss_turn")
		show_hint("تاس‌ها قبلاً پرتاب شده‌اند؛ روی مهره طلایی یا خانه سبز مقصد بزنید!")
		return

	if _roll_btn_ui.has("root") and is_instance_valid(_roll_btn_ui["root"]):
		var b_root: Node3D = _roll_btn_ui["root"]
		var tw = create_tween()
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.07)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.10)

	AudioManager.sfx_tap()
	send_move(Commands.Roll_Dice, {})


func _on_die_tapped(die_idx: int) -> void:
	if not GameManager.is_game_active:
		return

	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index)

	# Gamer-friendly shortcut: tapping the preview dice before rolling also rolls the dice!
	if is_my_turn and not dices_rolled:
		_on_roll_button_tapped()
		return
	if not is_my_turn or not dices_rolled:
		return
	if die_idx < 0 or die_idx >= current_dices.size():
		return

	var my_id: int = GameManager.my_player_index
	var target_idx: int = die_idx

	# If tapping the already-equipped die and another playable die exists, cycle to it!
	if target_idx == equipped_dice_index and current_dices.size() > 1:
		for offset in range(1, current_dices.size()):
			var cand_idx: int = (die_idx + offset) % current_dices.size()
			if _has_available_move_for_die(int(current_dices[cand_idx]), my_id):
				target_idx = cand_idx
				break

	var d_val: int = int(current_dices[target_idx])
	if not _has_available_move_for_die(d_val, my_id):
		# Try to find any playable die if the tapped one has no move
		var fallback_idx: int = -1
		for i in range(current_dices.size()):
			if _has_available_move_for_die(int(current_dices[i]), my_id):
				fallback_idx = i
				break
		if fallback_idx >= 0 and fallback_idx != equipped_dice_index:
			target_idx = fallback_idx
			d_val = int(current_dices[target_idx])
		else:
			AudioManager.play_sound("miss_turn")
			show_hint("با تاس %s هیچ حرکت مجازی وجود ندارد!" % _fa_digits(d_val))
			return

	AudioManager.sfx_tap()
	equipped_dice_index = target_idx
	can_select_peace = true

	if target_idx >= 0 and target_idx < _dice_nodes.size():
		var slot_node: Node3D = _dice_nodes[target_idx]["slot"]
		if is_instance_valid(slot_node):
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(slot_node, "scale", Vector3(1.14, 1.14, 1.14), 0.10)
			tw.tween_property(slot_node, "scale", Vector3.ONE, 0.12)

	_recompute_active_possible_pieces()
	_refresh_ui_and_highlights()


func _on_bar_tapped(gamer_id: int) -> void:
	var my_id: int = GameManager.my_player_index
	if not is_my_turn or not dices_rolled or gamer_id != my_id:
		return
	if not _check_gamer_piece_is_out(my_id):
		return

	if can_hit_points.is_empty():
		for i in range(current_dices.size()):
			var bar_src: int = -1 if my_id == 1 else 24
			if _check_source_can_move_n_count(bar_src, int(current_dices[i]), my_id):
				equipped_dice_index = i
				can_select_peace = true
				_recompute_active_possible_pieces()
				break

	if not can_hit_points.is_empty():
		_dispatch_bar_entry_move()
	else:
		AudioManager.play_sound("miss_turn")
		show_hint("با این تاس امکان ورود مهره از بار وجود ندارد!")


func _on_bear_off_tapped(gamer_id: int) -> void:
	var my_id: int = GameManager.my_player_index
	if not is_my_turn or not dices_rolled or gamer_id != my_id:
		return

	if can_bear_off_sources.is_empty():
		for i in range(current_dices.size()):
			var d_val: int = int(current_dices[i])
			var step: int = d_val if my_id == 1 else -d_val
			for pt in _get_my_piece_indexes(my_id):
				var next_idx: int = pt + step
				if (next_idx == 24 or next_idx == -1) and _is_valid_index_in_end_phase(next_idx, my_id):
					equipped_dice_index = i
					can_select_peace = true
					_recompute_active_possible_pieces()
					break
			if not can_bear_off_sources.is_empty():
				break

	if not can_bear_off_sources.is_empty():
		_dispatch_point_move(can_bear_off_sources[0])
	else:
		AudioManager.play_sound("miss_turn")
		show_hint("برای خارج کردن مهره، تمام مهره‌های شما باید در خانه خودی باشند!")


func _on_point_tapped(pt_idx: int) -> void:
	if not GameManager.is_game_active:
		return

	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index)

	if not is_my_turn:
		AudioManager.play_sound("miss_turn")
		show_hint("نوبت حریف است!")
		return
	if not dices_rolled:
		AudioManager.play_sound("miss_turn")
		show_hint("ابتدا دکمه سبز «پرتاب تاس» در پایین صفحه را بزنید!")
		return

	var my_id: int = GameManager.my_player_index

	# Case 1: Player has hit checkers on the Bar -> must enter from Bar first
	if _check_gamer_piece_is_out(my_id):
		if pt_idx in can_hit_points:
			_dispatch_bar_entry_move()
			return
		var bar_src: int = -1 if my_id == 1 else 24
		for i in range(current_dices.size()):
			var d_val: int = int(current_dices[i])
			var step: int = d_val if my_id == 1 else -d_val
			if bar_src + step == pt_idx and _check_source_can_move_n_count(bar_src, d_val, my_id):
				equipped_dice_index = i
				can_select_peace = true
				_recompute_active_possible_pieces()
				_dispatch_bar_entry_move()
				return
		AudioManager.play_sound("miss_turn")
		show_hint("ابتدا باید مهره زده‌شده در بار (وسط تخته) را وارد بازی کنید!")
		return

	# Case 2: Tapped a selectable source checker directly -> move it!
	if pt_idx in can_select_points:
		_dispatch_point_move(pt_idx)
		return

	# Case 3: Tapped a glowing destination point -> move the corresponding source checker there!
	if can_target_points.has(pt_idx):
		var src_pt: int = int(can_target_points[pt_idx])
		if src_pt == -1 or src_pt == 24:
			_dispatch_bar_entry_move()
		else:
			_dispatch_point_move(src_pt)
		return

	# Case 4: Tapped one of my checkers that is movable with a DIFFERENT die -> auto-switch die & move!
	if int(board_spots[pt_idx]["equipped_user"]) == my_id and int(board_spots[pt_idx]["count"]) > 0:
		for i in range(current_dices.size()):
			if _check_source_can_move_n_count(pt_idx, int(current_dices[i]), my_id):
				equipped_dice_index = i
				can_select_peace = true
				_recompute_active_possible_pieces()
				_refresh_ui_and_highlights()
				_dispatch_point_move(pt_idx)
				return
		AudioManager.play_sound("miss_turn")
		show_hint("این مهره با تاس‌های فعلی امکان حرکت ندارد!")
		return

	AudioManager.play_sound("miss_turn")
	show_hint("روی یکی از مهره‌های درخشان طلایی یا خانه سبز مقصد بزنید!")


func _dispatch_bar_entry_move() -> void:
	if equipped_dice_index < 0 or equipped_dice_index >= current_dices.size():
		return
	var my_id: int = GameManager.my_player_index
	var bar_index: int = -1 if my_id == 1 else 24
	AudioManager.sfx_tap()
	send_move(Commands.Select_Peace, {
		"index": bar_index,
		"dice_index": equipped_dice_index,
	})


func _dispatch_point_move(pt_idx: int) -> void:
	if equipped_dice_index < 0 or equipped_dice_index >= current_dices.size():
		return
	AudioManager.sfx_tap()
	send_move(Commands.Select_Peace, {
		"index": pt_idx,
		"dice_index": equipped_dice_index,
	})


# ==============================================================================
# 3D PERSIAN TEXT LABEL HELPER (Larger 0.00150 Pixel Scale & Bold Outline)
# ==============================================================================

func _create_3d_label(txt: String, f_size: int, col: Color) -> Label3D:
	var lbl = Label3D.new()
	lbl.text = txt
	if _FONT_FA:
		lbl.font = _FONT_FA
	lbl.font_size = f_size
	lbl.pixel_size = 0.00150
	lbl.modulate = col
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.rotation_degrees = Vector3(-90, 0, 0)
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.04, 0.02, 0.01, 0.98)
	return lbl
