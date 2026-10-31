class_name Ludo3D
extends BaseGameBoard

# Ludo 3D Board (منچ — Cafe Fekr Royal Persian Edition)
# Supports 2, 3, or 4 Players:
# - Player 1 (Red):    Entry at 0,  Home Stretch 36..39, Yard Bottom-Left
# - Player 2 (Blue):   Entry at 18, Home Stretch 40..43, Yard Top-Right
# - Player 3 (Green):  Entry at 27, Home Stretch 44..47, Yard Bottom-Right
# - Player 4 (Yellow): Entry at 9,  Home Stretch 48..51, Yard Top-Left
#
# Physical Footprint:
# - 1.22m x 1.22m Royal Walnut & Brass Cabinet (S = 0.16)
# - Precision Yatzy-Style 3D Die with flush enamel pips and rounded casino bevels
# - Tactile 3D Roll Dice Button at Z = +0.695m + Center 3D Dice Sanctuary at (0, 0, 0)
# - No floating number on top of the die
# - Instant source piece removal on move start (no duplicate piece at start place)
# - Generous 2D top-down piece hit testing prioritizing available moves

@export var camera_distance: float = 2.85
@export var camera_pitch: float = -0.82

const TRACK_SIZE: int = 36
const BOARD_SPOTS_COUNT: int = 52
const S: float = 0.16
const SURFACE_Y: float = 0.038
const ROLL_BTN_Z: float = 0.695

const FA_DIGITS: Array[String] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const FACTION_COLORS: Dictionary = {
	1: Color(0.92, 0.18, 0.22), # P1: Crimson Red
	2: Color(0.16, 0.52, 0.96), # P2: Royal Sapphire Blue
	3: Color(0.16, 0.78, 0.36), # P3: Emerald Green
	4: Color(0.96, 0.76, 0.12), # P4: Imperial Sun Gold / Yellow
}

const FACTION_NAMES_FA: Dictionary = {
	1: "قرمز",
	2: "آبی",
	3: "سبز",
	4: "زرد",
}

const ENTRY_TRACK_INDEX: Dictionary = {
	1: 0,
	2: 18,
	3: 27,
	4: 9,
}

const HOME_STRETCH_INDICES: Dictionary = {
	1: [36, 37, 38, 39],
	2: [40, 41, 42, 43],
	3: [44, 45, 46, 47],
	4: [48, 49, 50, 51],
}

const GAMER_PIECES_WIN_MAP: Dictionary = {
	1: {
		30: {1: false, 2: false, 3: false, 4: false, 5: false, 6: true},
		31: {1: false, 2: false, 3: false, 4: false, 5: true, 6: true},
		32: {1: false, 2: false, 3: false, 4: true, 5: true, 6: true},
		33: {1: false, 2: false, 3: true, 4: true, 5: true, 6: true},
		34: {1: false, 2: true, 3: true, 4: true, 5: true, 6: null},
		35: {1: true, 2: true, 3: true, 4: true, 5: null, 6: null},
	},
	2: {
		12: {1: false, 2: false, 3: false, 4: false, 5: false, 6: true},
		13: {1: false, 2: false, 3: false, 4: false, 5: true, 6: true},
		14: {1: false, 2: false, 3: false, 4: true, 5: true, 6: true},
		15: {1: false, 2: false, 3: true, 4: true, 5: true, 6: true},
		16: {1: false, 2: true, 3: true, 4: true, 5: true, 6: null},
		17: {1: true, 2: true, 3: true, 4: true, 5: null, 6: null},
	},
	3: {
		21: {1: false, 2: false, 3: false, 4: false, 5: false, 6: true},
		22: {1: false, 2: false, 3: false, 4: false, 5: true, 6: true},
		23: {1: false, 2: false, 3: false, 4: true, 5: true, 6: true},
		24: {1: false, 2: false, 3: true, 4: true, 5: true, 6: true},
		25: {1: false, 2: true, 3: true, 4: true, 5: true, 6: null},
		26: {1: true, 2: true, 3: true, 4: true, 5: null, 6: null},
	},
	4: {
		3: {1: false, 2: false, 3: false, 4: false, 5: false, 6: true},
		4: {1: false, 2: false, 3: false, 4: false, 5: true, 6: true},
		5: {1: false, 2: false, 3: false, 4: true, 5: true, 6: true},
		6: {1: false, 2: false, 3: true, 4: true, 5: true, 6: true},
		7: {1: false, 2: true, 3: true, 4: true, 5: true, 6: null},
		8: {1: true, 2: true, 3: true, 4: true, 5: null, 6: null},
	},
}

const GAMER_WIN_INDEXES_MAP: Dictionary = {
	1: {30: {6: 36}, 31: {5: 36, 6: 37}, 32: {4: 36, 5: 37, 6: 38}, 33: {3: 36, 4: 37, 5: 38, 6: 39}, 34: {2: 36, 3: 37, 4: 38, 5: 39}, 35: {1: 36, 2: 37, 3: 38, 4: 39}},
	2: {12: {6: 40}, 13: {5: 40, 6: 41}, 14: {4: 40, 5: 41, 6: 42}, 15: {3: 40, 4: 41, 5: 42, 6: 43}, 16: {2: 40, 3: 41, 4: 42, 5: 43}, 17: {1: 40, 2: 41, 3: 42, 4: 43}},
	3: {21: {6: 44}, 22: {5: 44, 6: 45}, 23: {4: 44, 5: 45, 6: 46}, 24: {3: 44, 4: 45, 5: 46, 6: 47}, 25: {2: 44, 3: 45, 4: 46, 5: 47}, 26: {1: 44, 2: 45, 3: 46, 4: 47}},
	4: {3: {6: 48}, 4: {5: 48, 6: 49}, 5: {4: 48, 5: 49, 6: 50}, 6: {3: 48, 4: 49, 5: 50, 6: 51}, 7: {2: 48, 3: 49, 4: 50, 5: 51}, 8: {1: 48, 2: 49, 3: 50, 4: 51}},
}

const GAMER_IN_WIN_INDEXES_MAP: Dictionary = {
	1: {36: {1: 37, 2: 38, 3: 39}, 37: {1: 38, 2: 39}, 38: {1: 39}, 39: {}},
	2: {40: {1: 41, 2: 42, 3: 43}, 41: {1: 42, 2: 43}, 42: {1: 43}, 43: {}},
	3: {44: {1: 45, 2: 46, 3: 47}, 45: {1: 46, 2: 47}, 46: {1: 47}, 47: {}},
	4: {48: {1: 49, 2: 50, 3: 51}, 49: {1: 50, 2: 51}, 50: {1: 51}, 51: {}},
}

# Authoritative Board State
var players_count: int = 2
var board_state: Array = []          # 52 dicts: {"count": int, "equipped_user": int}
var start_board_state: Array = []    # 4 dicts:  {"count": int, "equipped_user": int}
var players_out_pieces: Array = [4, 4, 4, 4]
var active_player_indexes: Array = [1, 2]
var current_dice: int = 0
var has_rolled_this_turn: bool = false
var is_out_of_move: bool = false
var available_moves: Array = []      # Array of int (-2, -1, 0..51)
var rank1_player: int = 0
var rank2_player: int = 0
var _is_animating_move: bool = false
var _roll_request_pending: bool = false

# 3D Spatial Lookup Positions
var _spot_positions: Array[Vector3] = []          # 0..51
var _start_portal_positions: Dictionary = {}      # gamer_id (1..4) -> Vector3
var _yard_slot_positions: Dictionary = {}         # gamer_id (1..4) -> Array[Vector3] (4 nests)
var _yard_center_positions: Dictionary = {}       # gamer_id (1..4) -> Vector3

# 3D Scene Nodes
var _board_root: Node3D = null
var _tiles_root: Node3D = null
var _pawns_root: Node3D = null
var _vfx_root: Node3D = null
var _spot_ring_highlights: Dictionary = {}        # spot_idx -> MeshInstance3D
var _start_portal_highlights: Dictionary = {}     # gamer_id -> MeshInstance3D
var _yard_highlights: Dictionary = {}             # gamer_id -> Array[MeshInstance3D]
var _target_preview_ring: Node3D = null
var _hovered_move_idx: int = -999

# Active 3D Pawn Nodes on the table
var _yard_pawn_nodes: Dictionary = {}             # gamer_id -> Array[Node3D] (up to 4)
var _start_portal_pawn_nodes: Dictionary = {}     # gamer_id -> Node3D
var _board_spot_pawn_nodes: Dictionary = {}       # spot_idx (0..51) -> Node3D

# 3D Interactive Yatzy-Style Die Sanctuary & 3D Roll Button
var _dice_sanctuary: Node3D = null
var _dice_pivot: Node3D = null
var _dice_mesh_root: Node3D = null
var _dice_halo_ring: MeshInstance3D = null
var _dice_tween: Tween = null
var _roll_btn_ui: Dictionary = {}
var _pulse_time: float = 0.0

# Pointer tap tracking (Unified Raycast Input — never blocks camera zoom/orbit)
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_down_time: float = 0.0
var _is_pointer_down: bool = false
var _last_handled_tap_time: float = 0.0

# Shared Luxury Materials
var _mat_wood_dark: StandardMaterial3D
var _mat_wood_trim: StandardMaterial3D
var _mat_felt_emerald: StandardMaterial3D
var _mat_brass_gold: StandardMaterial3D
var _mat_ivory_tile: StandardMaterial3D
var _mat_faction_enamel: Dictionary = {}
var _mat_faction_pawn: Dictionary = {}
var _mat_highlight_select: StandardMaterial3D
var _mat_highlight_target: StandardMaterial3D
var _mat_btn_roll_active: StandardMaterial3D
var _mat_btn_roll_move: StandardMaterial3D
var _mat_btn_roll_idle: StandardMaterial3D

# Yatzy Die Materials
var _mat_die_ivory: StandardMaterial3D
var _mat_die_chamfer: StandardMaterial3D
var _mat_pip_dark: StandardMaterial3D
var _mat_pip_red: StandardMaterial3D

static func _fa_int(val: int) -> String:
	var s = str(abs(val))
	var out = ""
	for i in range(s.length()):
		var code = s.unicode_at(i) - 48
		if code >= 0 and code <= 9:
			out += FA_DIGITS[code]
		else:
			out += s[i]
	return out

func _ready() -> void:
	game_type = GameTypes.LUDO
	super._ready()
	if NetworkManager.has_signal("win_happened_received"):
		if not NetworkManager.win_happened_received.is_connected(_on_win_happened):
			NetworkManager.win_happened_received.connect(_on_win_happened)
	_init_empty_state(max(2, GameManager.match_players.size()))
	_init_materials()
	_compute_all_board_coordinates()
	_build_board_3d()
	_build_center_dice_sanctuary()
	_build_target_preview_indicator()
	_build_3d_roll_dice_button()
	_rebuild_all_pawns_visuals()
	_update_interactive_highlights()

func _exit_tree() -> void:
	if NetworkManager.has_signal("win_happened_received"):
		if NetworkManager.win_happened_received.is_connected(_on_win_happened):
			NetworkManager.win_happened_received.disconnect(_on_win_happened)
	super._exit_tree()

func _init_empty_state(p_count: int) -> void:
	players_count = clampi(p_count, 2, 4)
	board_state.clear()
	for _i in range(BOARD_SPOTS_COUNT):
		board_state.append({"count": 0, "equipped_user": 0})
	start_board_state.clear()
	for _i in range(4):
		start_board_state.append({"count": 0, "equipped_user": 0})
	players_out_pieces = [4, 4, 4, 4]
	active_player_indexes.clear()
	for i in range(1, players_count + 1):
		active_player_indexes.append(i)
	current_dice = 0
	has_rolled_this_turn = false
	is_out_of_move = false
	available_moves.clear()

func _init_materials() -> void:
	_mat_wood_dark = StandardMaterial3D.new()
	_mat_wood_dark.albedo_color = Color(0.18, 0.10, 0.06)
	_mat_wood_dark.roughness = 0.42
	_mat_wood_dark.metallic = 0.08

	_mat_wood_trim = StandardMaterial3D.new()
	_mat_wood_trim.albedo_color = Color(0.28, 0.16, 0.09)
	_mat_wood_trim.roughness = 0.36
	_mat_wood_trim.metallic = 0.10

	_mat_felt_emerald = StandardMaterial3D.new()
	_mat_felt_emerald.albedo_color = Color(0.08, 0.16, 0.13)
	_mat_felt_emerald.roughness = 0.85
	_mat_felt_emerald.metallic = 0.02

	_mat_brass_gold = StandardMaterial3D.new()
	_mat_brass_gold.albedo_color = Color(0.94, 0.78, 0.34)
	_mat_brass_gold.metallic = 0.78
	_mat_brass_gold.roughness = 0.24

	_mat_ivory_tile = StandardMaterial3D.new()
	_mat_ivory_tile.albedo_color = Color(0.95, 0.91, 0.82)
	_mat_ivory_tile.roughness = 0.32
	_mat_ivory_tile.metallic = 0.05

	for f_id in FACTION_COLORS.keys():
		var col: Color = FACTION_COLORS[f_id]
		var m_tile = StandardMaterial3D.new()
		m_tile.albedo_color = col.darkened(0.08)
		m_tile.roughness = 0.28
		m_tile.metallic = 0.18
		m_tile.emission_enabled = true
		m_tile.emission = col * 0.22
		_mat_faction_enamel[f_id] = m_tile

		var m_pawn = StandardMaterial3D.new()
		m_pawn.albedo_color = col
		m_pawn.roughness = 0.18
		m_pawn.metallic = 0.25
		m_pawn.clearcoat_enabled = true
		m_pawn.clearcoat = 0.85
		m_pawn.clearcoat_roughness = 0.12
		m_pawn.emission_enabled = true
		m_pawn.emission = col * 0.18
		_mat_faction_pawn[f_id] = m_pawn

	_mat_highlight_select = StandardMaterial3D.new()
	_mat_highlight_select.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_highlight_select.albedo_color = Color(1.0, 0.90, 0.25, 0.88)
	_mat_highlight_select.emission_enabled = true
	_mat_highlight_select.emission = Color(1.0, 0.84, 0.20) * 1.6
	_mat_highlight_select.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mat_highlight_target = StandardMaterial3D.new()
	_mat_highlight_target.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_highlight_target.albedo_color = Color(0.25, 0.98, 0.88, 0.92)
	_mat_highlight_target.emission_enabled = true
	_mat_highlight_target.emission = Color(0.20, 0.95, 0.85) * 1.8
	_mat_highlight_target.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mat_btn_roll_active = StandardMaterial3D.new()
	_mat_btn_roll_active.albedo_color = Color(0.14, 0.62, 0.30)
	_mat_btn_roll_active.roughness = 0.28
	_mat_btn_roll_active.metallic = 0.18
	_mat_btn_roll_active.emission_enabled = true
	_mat_btn_roll_active.emission = Color(0.18, 0.82, 0.38) * 0.28

	_mat_btn_roll_move = StandardMaterial3D.new()
	_mat_btn_roll_move.albedo_color = Color(0.76, 0.48, 0.10)
	_mat_btn_roll_move.roughness = 0.28
	_mat_btn_roll_move.metallic = 0.22
	_mat_btn_roll_move.emission_enabled = true
	_mat_btn_roll_move.emission = Color(0.95, 0.68, 0.16) * 0.25

	_mat_btn_roll_idle = StandardMaterial3D.new()
	_mat_btn_roll_idle.albedo_color = Color(0.22, 0.16, 0.12)
	_mat_btn_roll_idle.roughness = 0.45
	_mat_btn_roll_idle.metallic = 0.10

	# Luxury Yatzy-style 3D Die Materials
	_mat_die_ivory = StandardMaterial3D.new()
	_mat_die_ivory.albedo_color = Color(0.99, 0.97, 0.93)
	_mat_die_ivory.roughness = 0.12
	_mat_die_ivory.metallic = 0.02
	_mat_die_ivory.clearcoat_enabled = true
	_mat_die_ivory.clearcoat = 0.90
	_mat_die_ivory.clearcoat_roughness = 0.06

	_mat_die_chamfer = StandardMaterial3D.new()
	_mat_die_chamfer.albedo_color = Color(0.94, 0.90, 0.80)
	_mat_die_chamfer.roughness = 0.18
	_mat_die_chamfer.metallic = 0.10
	_mat_die_chamfer.clearcoat_enabled = true
	_mat_die_chamfer.clearcoat = 0.75

	_mat_pip_dark = StandardMaterial3D.new()
	_mat_pip_dark.albedo_color = Color(0.05, 0.06, 0.10)
	_mat_pip_dark.roughness = 0.14
	_mat_pip_dark.metallic = 0.20
	_mat_pip_dark.clearcoat_enabled = true
	_mat_pip_dark.clearcoat = 0.85

	_mat_pip_red = StandardMaterial3D.new()
	_mat_pip_red.albedo_color = Color(0.88, 0.10, 0.15)
	_mat_pip_red.roughness = 0.14
	_mat_pip_red.metallic = 0.18
	_mat_pip_red.clearcoat_enabled = true
	_mat_pip_red.clearcoat = 0.90
	_mat_pip_red.emission_enabled = true
	_mat_pip_red.emission = Color(0.75, 0.08, 0.12)
	_mat_pip_red.emission_energy_multiplier = 0.25

func _rotate_xz_90_cw(v: Vector3, quarter_turns: int) -> Vector3:
	var p = v
	for _i in range(quarter_turns % 4):
		p = Vector3(-p.z, p.y, p.x)
	return p

func _compute_all_board_coordinates() -> void:
	_spot_positions.resize(BOARD_SPOTS_COUNT)
	var y_top: float = SURFACE_Y

	# Base 9-tile quarter arm scaled by S = 0.16 (fits cleanly inside 1.22m x 1.22m cabinet)
	var base_arm: Array[Vector3] = [
		Vector3(-0.62 * S, y_top,  3.10 * S), # k=0: Entry Tile (Tile 0 for P1 Red)
		Vector3(-0.62 * S, y_top,  2.48 * S), # k=1
		Vector3(-0.62 * S, y_top,  1.86 * S), # k=2
		Vector3(-0.62 * S, y_top,  1.24 * S), # k=3
		Vector3(-1.12 * S, y_top,  1.12 * S), # k=4: Inner Corner Junction
		Vector3(-1.24 * S, y_top,  0.62 * S), # k=5
		Vector3(-1.86 * S, y_top,  0.62 * S), # k=6
		Vector3(-2.48 * S, y_top,  0.62 * S), # k=7
		Vector3(-3.10 * S, y_top,  0.00 * S), # k=8: Arm Tip before next player's Home Stretch
	]

	for q in range(4):
		for k in range(9):
			var idx = q * 9 + k
			_spot_positions[idx] = _rotate_xz_90_cw(base_arm[k], q)

	# Home Stretch Corridors (36..51)
	var home_radii: Array[float] = [2.48 * S, 1.94 * S, 1.40 * S, 0.86 * S]
	for step in range(4):
		var r = home_radii[step]
		_spot_positions[36 + step] = Vector3(0.0, y_top,  r) # P1 Red (South)
		_spot_positions[40 + step] = Vector3(0.0, y_top, -r) # P2 Blue (North)
		_spot_positions[44 + step] = Vector3( r,  y_top, 0.0) # P3 Green (East)
		_spot_positions[48 + step] = Vector3(-r,  y_top, 0.0) # P4 Yellow (West)

	# Start Portals (index = -1, staging pedestal right beside each player's Track Entry tile)
	var base_portal = Vector3(-1.32 * S, y_top + 0.003, 3.10 * S)
	_start_portal_positions[1] = _rotate_xz_90_cw(base_portal, 0) # P1 Red: near Tile 0
	_start_portal_positions[4] = _rotate_xz_90_cw(base_portal, 1) # P4 Yellow: near Tile 9
	_start_portal_positions[2] = _rotate_xz_90_cw(base_portal, 2) # P2 Blue: near Tile 18
	_start_portal_positions[3] = _rotate_xz_90_cw(base_portal, 3) # P3 Green: near Tile 27

	# 4 Corner Home Yards (index = -2, 4 pawn sockets per player)
	_yard_center_positions = {
		1: Vector3(-2.35 * S, y_top + 0.003,  2.35 * S), # P1 Red: Bottom-Left
		4: Vector3(-2.35 * S, y_top + 0.003, -2.35 * S), # P4 Yellow: Top-Left
		2: Vector3( 2.35 * S, y_top + 0.003, -2.35 * S), # P2 Blue: Top-Right
		3: Vector3( 2.35 * S, y_top + 0.003,  2.35 * S), # P3 Green: Bottom-Right
	}
	var offsets: Array[Vector3] = [
		Vector3(-0.42 * S, 0.0, -0.42 * S),
		Vector3( 0.42 * S, 0.0, -0.42 * S),
		Vector3(-0.42 * S, 0.0,  0.42 * S),
		Vector3( 0.42 * S, 0.0,  0.42 * S),
	]
	for g_id in [1, 2, 3, 4]:
		var arr: Array[Vector3] = []
		var c: Vector3 = _yard_center_positions[g_id]
		for off in offsets:
			arr.append(c + off)
		_yard_slot_positions[g_id] = arr

func _build_board_3d() -> void:
	_board_root = Node3D.new()
	_board_root.name = "BoardRoot"
	add_child(_board_root)

	_tiles_root = Node3D.new()
	_tiles_root.name = "TilesRoot"
	_board_root.add_child(_tiles_root)

	_pawns_root = Node3D.new()
	_pawns_root.name = "PawnsRoot"
	add_child(_pawns_root)

	_vfx_root = Node3D.new()
	_vfx_root.name = "VFXRoot"
	add_child(_vfx_root)

	# 1. Carved Royal Cabinet Base (1.22m x 1.22m)
	var cabinet = MeshInstance3D.new()
	var cab_mesh = BoxMesh.new()
	cab_mesh.size = Vector3(7.6 * S, 0.032, 7.6 * S)
	cabinet.mesh = cab_mesh
	cabinet.position = Vector3(0.0, 0.016, 0.0)
	cabinet.material_override = _mat_wood_dark
	_board_root.add_child(cabinet)

	# Recessed Emerald Baize Playfield
	var playfield = MeshInstance3D.new()
	var pf_mesh = BoxMesh.new()
	pf_mesh.size = Vector3(6.95 * S, 0.010, 6.95 * S)
	playfield.mesh = pf_mesh
	playfield.position = Vector3(0.0, 0.031, 0.0)
	playfield.material_override = _mat_felt_emerald
	_board_root.add_child(playfield)

	# Raised Walnut & Gold Outer Border Walls
	var wall_configs = [
		{"pos": Vector3(0.0, 0.038, -3.62 * S), "size": Vector3(7.6 * S, 0.022, 0.36 * S)},
		{"pos": Vector3(0.0, 0.038,  3.62 * S), "size": Vector3(7.6 * S, 0.022, 0.36 * S)},
		{"pos": Vector3(-3.62 * S, 0.038, 0.0), "size": Vector3(0.36 * S, 0.022, 6.88 * S)},
		{"pos": Vector3( 3.62 * S, 0.038, 0.0), "size": Vector3(0.36 * S, 0.022, 6.88 * S)},
	]
	for wc in wall_configs:
		var w = MeshInstance3D.new()
		var wm = BoxMesh.new()
		wm.size = wc["size"]
		w.mesh = wm
		w.position = wc["pos"]
		w.material_override = _mat_wood_trim
		_board_root.add_child(w)

		var trim = MeshInstance3D.new()
		var tm = BoxMesh.new()
		tm.size = Vector3(wc["size"].x * 0.96, 0.004, wc["size"].z * 0.38)
		trim.mesh = tm
		trim.position = wc["pos"] + Vector3(0.0, 0.012, 0.0)
		trim.material_override = _mat_brass_gold
		_board_root.add_child(trim)

	# Cross Arm Carpet Backing Plinths
	var arm_v = MeshInstance3D.new()
	var av_m = BoxMesh.new()
	av_m.size = Vector3(1.82 * S, 0.004, 6.68 * S)
	arm_v.mesh = av_m
	arm_v.position = Vector3(0.0, SURFACE_Y - 0.002, 0.0)
	arm_v.material_override = _mat_wood_trim
	_board_root.add_child(arm_v)

	var arm_h = MeshInstance3D.new()
	var ah_m = BoxMesh.new()
	ah_m.size = Vector3(6.68 * S, 0.004, 1.82 * S)
	arm_h.mesh = ah_m
	arm_h.position = Vector3(0.0, SURFACE_Y - 0.002, 0.0)
	arm_h.material_override = _mat_wood_trim
	_board_root.add_child(arm_h)

	# 2. Build 36 Circular Track Medallions (0..35)
	for idx in range(TRACK_SIZE):
		var is_entry_for: int = 0
		for g_id in ENTRY_TRACK_INDEX.keys():
			if ENTRY_TRACK_INDEX[g_id] == idx:
				is_entry_for = g_id
				break
		var mat = _mat_faction_enamel[is_entry_for] if is_entry_for > 0 else _mat_ivory_tile
		_create_tile_medallion(idx, _spot_positions[idx], mat, is_entry_for > 0)

	# 3. Build 16 Home Stretch Medallions (36..51)
	for g_id in HOME_STRETCH_INDICES.keys():
		var h_list: Array = HOME_STRETCH_INDICES[g_id]
		var mat = _mat_faction_enamel[g_id]
		for h_idx in h_list:
			_create_tile_medallion(h_idx, _spot_positions[h_idx], mat, true)

	# 4. Build 4 Start Portals (index = -1) & 4 Corner Home Yards (index = -2)
	for g_id in [1, 2, 3, 4]:
		_create_start_portal(g_id, _start_portal_positions[g_id])
		_create_corner_home_yard(g_id, _yard_center_positions[g_id])

func _create_tile_medallion(spot_idx: int, pos: Vector3, mat: StandardMaterial3D, is_colored: bool) -> void:
	var holder = Node3D.new()
	holder.name = "Spot_%d" % spot_idx
	holder.position = pos
	_tiles_root.add_child(holder)

	# Brass outer bezel cylinder
	var bezel = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.24 * S
	bm.bottom_radius = 0.26 * S
	bm.height = 0.005
	bm.radial_segments = 24
	bezel.mesh = bm
	bezel.material_override = _mat_brass_gold
	holder.add_child(bezel)

	# Inner marble/enamel disc
	var disc = MeshInstance3D.new()
	var dm = CylinderMesh.new()
	dm.top_radius = 0.205 * S
	dm.bottom_radius = 0.205 * S
	dm.height = 0.0065
	dm.radial_segments = 24
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.001, 0.0)
	disc.material_override = mat
	holder.add_child(disc)

	if is_colored:
		var star = MeshInstance3D.new()
		var sm = CylinderMesh.new()
		sm.top_radius = 0.075 * S
		sm.bottom_radius = 0.075 * S
		sm.height = 0.0075
		sm.radial_segments = 6
		star.mesh = sm
		star.position = Vector3(0.0, 0.0015, 0.0)
		star.material_override = _mat_brass_gold
		holder.add_child(star)

	# Selection halo ring (hidden by default)
	var ring = _create_halo_ring_mesh(0.255 * S, 0.042 * S, _mat_highlight_select)
	ring.position = Vector3(0.0, 0.005, 0.0)
	ring.visible = false
	holder.add_child(ring)
	_spot_ring_highlights[spot_idx] = ring

func _create_start_portal(g_id: int, pos: Vector3) -> void:
	var portal = Node3D.new()
	portal.name = "StartPortal_P%d" % g_id
	portal.position = pos
	_tiles_root.add_child(portal)

	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.27 * S
	bm.bottom_radius = 0.30 * S
	bm.height = 0.008
	bm.radial_segments = 8
	base.mesh = bm
	base.material_override = _mat_brass_gold
	portal.add_child(base)

	var core = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.22 * S
	cm.bottom_radius = 0.22 * S
	cm.height = 0.010
	cm.radial_segments = 16
	core.mesh = cm
	core.position = Vector3(0.0, 0.0015, 0.0)
	core.material_override = _mat_faction_enamel[g_id]
	portal.add_child(core)

	# Connecting golden bridge towards Entry Track Tile
	var entry_pos: Vector3 = _spot_positions[ENTRY_TRACK_INDEX[g_id]]
	var diff: Vector3 = entry_pos - pos
	var bridge = MeshInstance3D.new()
	var brm = BoxMesh.new()
	brm.size = Vector3(diff.length(), 0.004, 0.14 * S)
	bridge.mesh = brm
	bridge.position = diff * 0.5
	bridge.rotation.y = atan2(-diff.z, diff.x)
	bridge.material_override = _mat_brass_gold
	portal.add_child(bridge)

	var ring = _create_halo_ring_mesh(0.285 * S, 0.045 * S, _mat_highlight_select)
	ring.position = Vector3(0.0, 0.006, 0.0)
	ring.visible = false
	portal.add_child(ring)
	_start_portal_highlights[g_id] = ring

func _create_corner_home_yard(g_id: int, center_pos: Vector3) -> void:
	var yard = Node3D.new()
	yard.name = "HomeYard_P%d" % g_id
	yard.position = center_pos
	_tiles_root.add_child(yard)

	# Outer walnut & brass sanctuary platform
	var plat = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(1.62 * S, 0.008, 1.62 * S)
	plat.mesh = pm
	plat.material_override = _mat_wood_trim
	yard.add_child(plat)

	var trim = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(1.50 * S, 0.010, 1.50 * S)
	trim.mesh = tm
	trim.position = Vector3(0.0, 0.001, 0.0)
	trim.material_override = _mat_brass_gold
	yard.add_child(trim)

	var inner = MeshInstance3D.new()
	var im = BoxMesh.new()
	im.size = Vector3(1.38 * S, 0.011, 1.38 * S)
	inner.mesh = im
	inner.position = Vector3(0.0, 0.002, 0.0)
	inner.material_override = _mat_faction_enamel[g_id]
	yard.add_child(inner)

	# 4 Circular Pawn Sockets inside the Home Yard
	var slot_rings: Array[MeshInstance3D] = []
	var slots: Array = _yard_slot_positions[g_id]
	for i in range(slots.size()):
		var world_slot: Vector3 = slots[i]
		var local_slot: Vector3 = world_slot - center_pos

		var sock = MeshInstance3D.new()
		var sm = CylinderMesh.new()
		sm.top_radius = 0.23 * S
		sm.bottom_radius = 0.25 * S
		sm.height = 0.008
		sm.radial_segments = 20
		sock.mesh = sm
		sock.position = local_slot + Vector3(0.0, 0.005, 0.0)
		sock.material_override = _mat_ivory_tile
		yard.add_child(sock)

		var ring = _create_halo_ring_mesh(0.26 * S, 0.042 * S, _mat_highlight_select)
		ring.position = local_slot + Vector3(0.0, 0.010, 0.0)
		ring.visible = false
		yard.add_child(ring)
		slot_rings.append(ring)

	_yard_highlights[g_id] = slot_rings

func _build_center_dice_sanctuary() -> void:
	_dice_sanctuary = Node3D.new()
	_dice_sanctuary.name = "DiceSanctuary"
	_dice_sanctuary.position = Vector3(0.0, SURFACE_Y, 0.0)
	_board_root.add_child(_dice_sanctuary)

	# Octagonal Golden Arena Pedestal in the center of the cross
	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.62 * S
	bm.bottom_radius = 0.68 * S
	bm.height = 0.011
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.0055, 0.0)
	base.material_override = _mat_brass_gold
	_dice_sanctuary.add_child(base)

	var cushion = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.54 * S
	cm.bottom_radius = 0.56 * S
	cm.height = 0.013
	cm.radial_segments = 8
	cushion.mesh = cm
	cushion.position = Vector3(0.0, 0.0065, 0.0)
	cushion.material_override = _mat_felt_emerald
	_dice_sanctuary.add_child(cushion)

	_dice_halo_ring = _create_halo_ring_mesh(0.64 * S, 0.055 * S, _mat_highlight_select)
	_dice_halo_ring.position = Vector3(0.0, 0.014, 0.0)
	_dice_halo_ring.visible = false
	_dice_sanctuary.add_child(_dice_halo_ring)

	# 3D Interactive Yatzy-Style Ivory Die
	_dice_pivot = Node3D.new()
	_dice_pivot.name = "DicePivot"
	_dice_pivot.position = Vector3(0.0, 0.048, 0.0)
	_dice_sanctuary.add_child(_dice_pivot)

	_dice_mesh_root = _create_yatzy_die_model(0.082)
	_dice_pivot.add_child(_dice_mesh_root)

func _build_3d_roll_dice_button() -> void:
	var btn_size = Vector3(0.76, 0.034, 0.126)
	var root = Node3D.new()
	root.name = "BtnRollDice3D"
	root.position = Vector3(0.0, 0.022, ROLL_BTN_Z)
	add_child(root)

	# 24K Gold Bezel Base
	var bezel = MeshInstance3D.new()
	var bz_box = BoxMesh.new()
	bz_box.size = btn_size + Vector3(0.022, -0.004, 0.022)
	bezel.mesh = bz_box
	bezel.material_override = _mat_brass_gold
	root.add_child(bezel)

	# Tactile Button Cap
	var cap = MeshInstance3D.new()
	var cap_box = BoxMesh.new()
	cap_box.size = btn_size
	cap.mesh = cap_box
	cap.position = Vector3(0.0, 0.005, 0.0)
	cap.material_override = _mat_btn_roll_idle
	root.add_child(cap)

	# Decorative Mini Yatzy Dice on Left & Right Ends of the Button
	for side_x in [-0.31, 0.31]:
		var mini_die = _create_yatzy_die_model(0.034)
		mini_die.position = Vector3(side_x, 0.036, 0.0)
		mini_die.rotation = Vector3(0.38, 0.60 * sign(side_x), -0.32)
		root.add_child(mini_die)

	# Crisp 3D Persian Label on the Button Cap (hekayat.ttf, no emojis)
	var lbl = Label3D.new()
	lbl.position = Vector3(0.0, 0.025, 0.006)
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.pixel_size = 0.00082
	lbl.font = preload("res://assets/fonts/hekayat.ttf")
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.96, 0.86)
	lbl.outline_modulate = Color(0.06, 0.03, 0.01, 0.95)
	lbl.text = "آماده شروع مسابقه..."
	root.add_child(lbl)

	_roll_btn_ui = {
		"root": root,
		"cap": cap,
		"label": lbl,
	}

func _create_yatzy_die_model(sz: float) -> Node3D:
	var root = Node3D.new()

	# 1. Smooth Chamfered Inner Core
	var chamfer_core = MeshInstance3D.new()
	var core_box = BoxMesh.new()
	core_box.size = Vector3(sz * 0.94, sz * 0.94, sz * 0.94)
	core_box.material = _mat_die_chamfer
	chamfer_core.mesh = core_box
	root.add_child(chamfer_core)

	# 2. 3 Overlapping Beveled Face Slabs (X, Y, Z) forming rounded-edge casino die
	for slab_size in [
		Vector3(sz, sz * 0.86, sz * 0.86),
		Vector3(sz * 0.86, sz, sz * 0.86),
		Vector3(sz * 0.86, sz * 0.86, sz),
	]:
		var slab_inst = MeshInstance3D.new()
		var slab_box = BoxMesh.new()
		slab_box.size = slab_size
		slab_box.material = _mat_die_ivory
		slab_inst.mesh = slab_box
		root.add_child(slab_inst)

	# 3. Precision Flush Enamel Pips on all 6 faces
	_add_3d_die_pips(root, sz * 0.5)
	return root

func _add_3d_die_pips(die_root: Node3D, half_s: float) -> void:
	var o: float = half_s * 0.54
	# Opposing faces sum to 7:
	# +Y = 1 (Ruby big pip), -Y = 6 (dark), +Z = 2 (dark), -Z = 5 (dark), +X = 3 (dark), -X = 4 (Ruby)
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

	var pip_mesh_big = CylinderMesh.new()
	pip_mesh_big.top_radius = half_s * 0.25
	pip_mesh_big.bottom_radius = half_s * 0.25
	pip_mesh_big.height = 0.0018
	pip_mesh_big.radial_segments = 20

	var pip_mesh_small = CylinderMesh.new()
	pip_mesh_small.top_radius = half_s * 0.155
	pip_mesh_small.bottom_radius = half_s * 0.155
	pip_mesh_small.height = 0.0018
	pip_mesh_small.radial_segments = 16

	for fc in face_configs:
		var n: Vector3 = fc["normal"]
		var r: Vector3 = fc["right"]
		var f: Vector3 = fc["fwd"]
		var rot_d: Vector3 = fc["rot_deg"]
		var is_red: bool = fc["red"]
		var is_big: bool = fc["big"]
		var p_mesh = pip_mesh_big if is_big else pip_mesh_small
		var p_mat = _mat_pip_red if is_red else _mat_pip_dark
		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			pip.mesh = p_mesh
			pip.material_override = p_mat
			pip.rotation_degrees = rot_d
			pip.position = n * (half_s + 0.0004) + r * p2.x + f * p2.y
			die_root.add_child(pip)

func _get_die_target_rotation(val: int) -> Vector3:
	match val:
		1: return Vector3(0.0, 0.0, 0.0)
		2: return Vector3(-PI * 0.5, 0.0, 0.0)
		3: return Vector3(0.0, 0.0, PI * 0.5)
		4: return Vector3(0.0, 0.0, -PI * 0.5)
		5: return Vector3(PI * 0.5, 0.0, 0.0)
		6: return Vector3(PI, 0.0, 0.0)
		_: return Vector3.ZERO

func _create_royal_pawn_node(g_id: int, stack_count: int = 1) -> Node3D:
	var pawn = Node3D.new()
	var mat: StandardMaterial3D = _mat_faction_pawn.get(g_id, _mat_faction_pawn[1])

	# 1. Brass Base Rim
	var rim = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = 0.165 * S
	rm.bottom_radius = 0.185 * S
	rm.height = 0.04 * S
	rm.radial_segments = 20
	rim.mesh = rm
	rim.position = Vector3(0.0, 0.02 * S, 0.0)
	rim.material_override = _mat_brass_gold
	pawn.add_child(rim)

	# 2. Stepped Lower Pedestal
	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.135 * S
	bm.bottom_radius = 0.165 * S
	bm.height = 0.09 * S
	bm.radial_segments = 20
	base.mesh = bm
	base.position = Vector3(0.0, 0.085 * S, 0.0)
	base.material_override = mat
	pawn.add_child(base)

	# 3. Sculpted Tapered Body Column
	var body = MeshInstance3D.new()
	var bdm = CylinderMesh.new()
	bdm.top_radius = 0.072 * S
	bdm.bottom_radius = 0.130 * S
	bdm.height = 0.24 * S
	bdm.radial_segments = 20
	body.mesh = bdm
	body.position = Vector3(0.0, 0.25 * S, 0.0)
	body.material_override = mat
	pawn.add_child(body)

	# 4. Golden Neck Collar Ring
	var collar = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.096 * S
	cm.bottom_radius = 0.096 * S
	cm.height = 0.032 * S
	cm.radial_segments = 20
	collar.mesh = cm
	collar.position = Vector3(0.0, 0.375 * S, 0.0)
	collar.material_override = _mat_brass_gold
	pawn.add_child(collar)

	# 5. Polished Crown Sphere Head
	var head = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.108 * S
	hm.height = 0.216 * S
	head.mesh = hm
	head.position = Vector3(0.0, 0.48 * S, 0.0)
	head.material_override = mat
	pawn.add_child(head)

	# 6. Golden Finial Tip
	var tip = MeshInstance3D.new()
	var tm = SphereMesh.new()
	tm.radius = 0.036 * S
	tm.height = 0.072 * S
	tip.mesh = tm
	tip.position = Vector3(0.0, 0.60 * S, 0.0)
	tip.material_override = _mat_brass_gold
	pawn.add_child(tip)

	# 7. Stack Count Badge (if > 1 pawn stacked on same spot)
	if stack_count > 1:
		var lbl = Label3D.new()
		lbl.position = Vector3(0.0, 0.78 * S, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.pixel_size = 0.0009
		lbl.font = preload("res://assets/fonts/hekayat.ttf")
		lbl.font_size = 42
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.95, 0.40)
		lbl.outline_modulate = Color(0.08, 0.04, 0.02, 0.98)
		lbl.text = "×%s" % _fa_int(stack_count)
		pawn.add_child(lbl)

	return pawn

func _create_halo_ring_mesh(radius: float, thickness: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = max(0.002, radius - thickness * 0.5)
	tm.outer_radius = radius + thickness * 0.5
	tm.rings = 24
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = mat
	return mi

func _build_target_preview_indicator() -> void:
	_target_preview_ring = Node3D.new()
	_target_preview_ring.name = "TargetPreviewRing"
	_target_preview_ring.visible = false
	_vfx_root.add_child(_target_preview_ring)

	var ring = _create_halo_ring_mesh(0.275 * S, 0.055 * S, _mat_highlight_target)
	ring.position = Vector3(0.0, 0.006, 0.0)
	_target_preview_ring.add_child(ring)

	var beacon = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.04 * S
	cm.bottom_radius = 0.14 * S
	cm.height = 0.36 * S
	beacon.mesh = cm
	beacon.position = Vector3(0.0, 0.20 * S, 0.0)
	beacon.material_override = _mat_highlight_target
	_target_preview_ring.add_child(beacon)

func _process(delta: float) -> void:
	_pulse_time += delta * 4.2
	var s_pulse = 1.0 + 0.08 * sin(_pulse_time)
	var y_bob = 0.007 * abs(sin(_pulse_time * 0.85))

	if is_instance_valid(_dice_halo_ring) and _dice_halo_ring.visible:
		_dice_halo_ring.scale = Vector3(s_pulse, 1.0, s_pulse)
	if is_instance_valid(_target_preview_ring) and _target_preview_ring.visible:
		_target_preview_ring.scale = Vector3(s_pulse, 1.0, s_pulse)

	# Gently bob selectable pawns when it is our turn to select a pawn
	if GameManager.is_my_turn and has_rolled_this_turn and not _is_animating_move:
		var my_id = GameManager.my_player_index
		if available_moves.has(-2) and _yard_pawn_nodes.has(my_id):
			for p_node in _yard_pawn_nodes[my_id]:
				if is_instance_valid(p_node):
					p_node.position.y = _yard_slot_positions[my_id][0].y + y_bob
		if available_moves.has(-1) and _start_portal_pawn_nodes.has(my_id):
			var sp_node = _start_portal_pawn_nodes[my_id]
			if is_instance_valid(sp_node):
				sp_node.position.y = _start_portal_positions[my_id].y + y_bob
		for mv in available_moves:
			var idx = int(mv)
			if idx >= 0 and _board_spot_pawn_nodes.has(idx):
				var b_node = _board_spot_pawn_nodes[idx]
				if is_instance_valid(b_node):
					b_node.position.y = _spot_positions[idx].y + y_bob

func _rebuild_all_pawns_visuals() -> void:
	if not is_instance_valid(_pawns_root):
		return
	for ch in _pawns_root.get_children():
		ch.queue_free()
	_yard_pawn_nodes.clear()
	_start_portal_pawn_nodes.clear()
	_board_spot_pawn_nodes.clear()

	# 1. Spawn Home Yard Pawns (index = -2) for active players 1..players_count
	for g_id in range(1, players_count + 1):
		var out_cnt: int = int(players_out_pieces[g_id - 1]) if g_id - 1 < players_out_pieces.size() else 0
		var yard_list: Array[Node3D] = []
		var slots: Array = _yard_slot_positions.get(g_id, [])
		for s_i in range(clampi(out_cnt, 0, slots.size())):
			var p_node = _create_royal_pawn_node(g_id, 1)
			p_node.position = slots[s_i]
			_pawns_root.add_child(p_node)
			yard_list.append(p_node)
		_yard_pawn_nodes[g_id] = yard_list

	# 2. Spawn Start Portal Pawns (index = -1)
	for g_id in range(1, min(players_count, start_board_state.size()) + 1):
		var st_dict: Dictionary = start_board_state[g_id - 1]
		var cnt: int = int(st_dict.get("count", 0))
		if cnt > 0:
			var p_node = _create_royal_pawn_node(g_id, cnt)
			p_node.position = _start_portal_positions[g_id]
			_pawns_root.add_child(p_node)
			_start_portal_pawn_nodes[g_id] = p_node

	# 3. Spawn Main Track & Home Stretch Pawns (0..51)
	for spot_idx in range(min(BOARD_SPOTS_COUNT, board_state.size())):
		var b_dict: Dictionary = board_state[spot_idx]
		var cnt: int = int(b_dict.get("count", 0))
		var owner_id: int = int(b_dict.get("equipped_user", 0))
		if cnt > 0 and owner_id >= 1 and owner_id <= 4:
			var p_node = _create_royal_pawn_node(owner_id, cnt)
			p_node.position = _spot_positions[spot_idx]
			_pawns_root.add_child(p_node)
			_board_spot_pawn_nodes[spot_idx] = p_node

	_sync_header_home_counts()

func _sync_header_home_counts() -> void:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		var main_node = get_tree().current_scene
		if is_instance_valid(main_node):
			hud = main_node.get_node_or_null("CanvasLayer/BaseGameHUD")
	if not is_instance_valid(hud) or not is_instance_valid(hud.current_top_header):
		return
	var header = hud.current_top_header
	if header.has_method("update_home_counts"):
		var counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
		for g_id in HOME_STRETCH_INDICES.keys():
			var c: int = 0
			for h_idx in HOME_STRETCH_INDICES[g_id]:
				if h_idx < board_state.size() and int(board_state[h_idx].get("equipped_user", 0)) == g_id:
					c += int(board_state[h_idx].get("count", 0))
			counts[g_id] = c
		header.update_home_counts(counts, rank1_player, rank2_player)

func _update_interactive_highlights() -> void:
	for idx in _spot_ring_highlights.keys():
		_spot_ring_highlights[idx].visible = false
	for g_id in _start_portal_highlights.keys():
		_start_portal_highlights[g_id].visible = false
	for g_id in _yard_highlights.keys():
		for r in _yard_highlights[g_id]:
			r.visible = false
	if is_instance_valid(_target_preview_ring):
		_target_preview_ring.visible = false

	var my_turn: bool = GameManager.is_my_turn and GameManager.is_game_active
	var my_id: int = GameManager.my_player_index
	var can_roll_now: bool = my_turn and not has_rolled_this_turn and not _roll_request_pending and not _is_animating_move and not is_out_of_move

	if is_instance_valid(_dice_halo_ring):
		_dice_halo_ring.visible = can_roll_now

	# Update 3D Roll Dice Button visual state & text
	if not _roll_btn_ui.is_empty() and is_instance_valid(_roll_btn_ui.get("root")):
		var btn_cap: MeshInstance3D = _roll_btn_ui["cap"]
		var btn_lbl: Label3D = _roll_btn_ui["label"]
		if not GameManager.is_game_active:
			btn_cap.material_override = _mat_btn_roll_idle
			btn_lbl.text = "آماده شروع مسابقه..."
			btn_lbl.modulate = Color(0.90, 0.86, 0.78)
		elif my_turn and (is_out_of_move or (has_rolled_this_turn and available_moves.is_empty())):
			btn_cap.material_override = _mat_btn_roll_idle
			if current_dice > 0:
				btn_lbl.text = "تاس %s — بدون حرکت ممکن (پایان نوبت...)" % _fa_int(current_dice)
			else:
				btn_lbl.text = "بدون حرکت ممکن (پایان نوبت...)"
			btn_lbl.modulate = Color(0.85, 0.75, 0.75)
		elif can_roll_now:
			btn_cap.material_override = _mat_btn_roll_active
			btn_lbl.text = "پرتاب تاس (کلیک کنید)"
			btn_lbl.modulate = Color(1.0, 0.98, 0.88)
		elif my_turn and has_rolled_this_turn:
			btn_cap.material_override = _mat_btn_roll_move
			btn_lbl.text = "تاس %s — مهره خود را حرکت دهید" % _fa_int(current_dice)
			btn_lbl.modulate = Color(1.0, 0.96, 0.84)
		else:
			btn_cap.material_override = _mat_btn_roll_idle
			var turn_color_fa = FACTION_NAMES_FA.get(current_turn, "")
			if current_dice > 0:
				btn_lbl.text = "نوبت %s (تاس %s)" % [turn_color_fa, _fa_int(current_dice)]
			else:
				btn_lbl.text = "نوبت %s برای پرتاب تاس..." % turn_color_fa
			btn_lbl.modulate = Color(0.82, 0.80, 0.76)

	if my_turn and has_rolled_this_turn and not _is_animating_move:
		for mv in available_moves:
			var move_idx = int(mv)
			if move_idx == -2:
				var out_cnt: int = int(players_out_pieces[my_id - 1]) if my_id - 1 < players_out_pieces.size() else 0
				var rings: Array = _yard_highlights.get(my_id, [])
				for i in range(clampi(out_cnt, 0, rings.size())):
					rings[i].visible = true
			elif move_idx == -1:
				if _start_portal_highlights.has(my_id):
					_start_portal_highlights[my_id].visible = true
			elif _spot_ring_highlights.has(move_idx):
				_spot_ring_highlights[move_idx].visible = true

func _compute_local_available_moves(gamer_id: int, dice_val: int) -> Array:
	var res: Array = []
	if dice_val <= 0 or gamer_id < 1 or gamer_id > 4:
		return res

	for idx in range(min(BOARD_SPOTS_COUNT, board_state.size())):
		var d: Dictionary = board_state[idx]
		if int(d.get("equipped_user", 0)) == gamer_id and int(d.get("count", 0)) > 0:
			if idx >= 36:
				var in_map: Dictionary = GAMER_IN_WIN_INDEXES_MAP.get(gamer_id, {}).get(idx, {})
				if in_map.has(dice_val):
					var t_idx = int(in_map[dice_val])
					if int(board_state[t_idx].get("count", 0)) == 0:
						res.append(idx)
			else:
				if (gamer_id == 1 and idx <= 29) or (gamer_id == 2 and (idx <= 11 or idx >= 18)) or (gamer_id == 3 and (idx <= 20 or idx >= 27)) or (gamer_id == 4 and (idx <= 2 or idx >= 9)):
					res.append(idx)
				else:
					var w_map: Dictionary = GAMER_PIECES_WIN_MAP.get(gamer_id, {}).get(idx, {})
					if w_map.has(dice_val) and w_map[dice_val] != null:
						if bool(w_map[dice_val]):
							var win_idx = int(GAMER_WIN_INDEXES_MAP[gamer_id][idx][dice_val])
							if int(board_state[win_idx].get("count", 0)) == 0:
								res.append(idx)
						else:
							res.append(idx)

	var out_cnt = int(players_out_pieces[gamer_id - 1]) if gamer_id - 1 < players_out_pieces.size() else 0
	if out_cnt > 0 and dice_val == 6:
		res.append(-2)
	if gamer_id - 1 < start_board_state.size() and int(start_board_state[gamer_id - 1].get("count", 0)) > 0:
		res.append(-1)
	return res

func _compute_target_index_for_move(index: int, gamer_id: int, dice_val: int) -> int:
	if index == -2:
		return -1
	elif index == -1:
		return int(ENTRY_TRACK_INDEX.get(gamer_id, 0)) + dice_val - 1
	elif index >= 36:
		var in_map: Dictionary = GAMER_IN_WIN_INDEXES_MAP.get(gamer_id, {}).get(index, {})
		if in_map.has(dice_val):
			return int(in_map[dice_val])
		return index
	else:
		if (gamer_id == 1 and index <= 29) or (gamer_id == 2 and (index <= 11 or index >= 18)) or (gamer_id == 3 and (index <= 20 or idx_check(index, 27))) or (gamer_id == 4 and (index <= 2 or index >= 9)):
			return (index + dice_val) % TRACK_SIZE
		var w_map: Dictionary = GAMER_PIECES_WIN_MAP.get(gamer_id, {}).get(index, {})
		if w_map.has(dice_val) and bool(w_map[dice_val]):
			return int(GAMER_WIN_INDEXES_MAP[gamer_id][index][dice_val])
		return (index + dice_val) % TRACK_SIZE

func idx_check(index: int, threshold: int) -> bool:
	return index >= threshold

# ==============================================================================
# UNIFIED 3D RAYCAST INPUT & GENEROUS 2D HIT TESTING
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active or _is_animating_move:
		return

	if event is InputEventMouseMotion:
		_handle_hover_motion(event.position)
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
				if dist <= 48.0 and elapsed < 1.0:
					if now - _last_handled_tap_time >= 0.12:
						if _handle_screen_tap(event.position):
							_last_handled_tap_time = now
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
				if dist <= 48.0 and elapsed < 1.0:
					if now - _last_handled_tap_time >= 0.12:
						if _handle_screen_tap(event.position):
							_last_handled_tap_time = now
							get_viewport().set_input_as_handled()

func _project_screen_to_board_local(screen_pos: Vector2) -> Variant:
	var vp = get_viewport()
	if not vp:
		return null
	var cam = vp.get_camera_3d()
	if not is_instance_valid(cam):
		return null
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane = Plane(Vector3.UP, SURFACE_Y + 0.015)
	var hit = plane.intersects_ray(from, dir)
	if hit == null:
		return null
	return to_local(hit)

func _handle_hover_motion(screen_pos: Vector2) -> void:
	if not GameManager.is_my_turn or not has_rolled_this_turn:
		if is_instance_valid(_target_preview_ring):
			_target_preview_ring.visible = false
		return
	var local_pt = _project_screen_to_board_local(screen_pos)
	if local_pt == null:
		if is_instance_valid(_target_preview_ring):
			_target_preview_ring.visible = false
		return
	var hit_info = _hit_test_board_point(local_pt)
	if hit_info.get("type", "") == "move" and available_moves.has(int(hit_info["move_idx"])):
		var mv_idx = int(hit_info["move_idx"])
		if mv_idx != _hovered_move_idx:
			_hovered_move_idx = mv_idx
			_on_move_index_hovered(mv_idx, true)
	else:
		if _hovered_move_idx != -999:
			_hovered_move_idx = -999
			_on_move_index_hovered(-999, false)

func _hit_test_board_point(local_pt: Vector3) -> Dictionary:
	var pt2 = Vector2(local_pt.x, local_pt.z)

	# 1. Front 3D Roll Dice Button (Z = ROLL_BTN_Z)
	if absf(local_pt.x) <= 0.44 and absf(local_pt.z - ROLL_BTN_Z) <= 0.095:
		if is_out_of_move or (has_rolled_this_turn and available_moves.is_empty()):
			return {"type": "no_moves"}
		return {"type": "roll"}

	# 2. Center 3D Dice Sanctuary (radius <= 0.125m around center)
	if pt2.length() <= 0.125:
		if is_out_of_move or (has_rolled_this_turn and available_moves.is_empty()):
			return {"type": "no_moves"}
		return {"type": "roll"}

	var my_id = GameManager.my_player_index

	# 3. IF IT IS MY TURN TO MOVE AND I HAVE AVAILABLE MOVES: PRIORITIZE SELECTING MY PLAYABLE PIECES!
	if GameManager.is_my_turn and has_rolled_this_turn and not available_moves.is_empty():
		# A. Home Yard (-2): If -2 is available, tapping anywhere in the player's corner yard quadrant registers -2!
		if available_moves.has(-2):
			var yc: Vector3 = _yard_center_positions[my_id]
			if pt2.distance_to(Vector2(yc.x, yc.z)) <= 0.20 or (absf(local_pt.x - yc.x) <= 0.16 and absf(local_pt.z - yc.z) <= 0.16):
				return {"type": "move", "move_idx": -2}

		# B. Start Portal (-1): If -1 is available, tapping near the portal registers -1!
		if available_moves.has(-1) and _start_portal_positions.has(my_id):
			var sp_pos: Vector3 = _start_portal_positions[my_id]
			if pt2.distance_to(Vector2(sp_pos.x, sp_pos.z)) <= 0.11:
				return {"type": "move", "move_idx": -1}

		# C. Check nearest available move among board spots (0..51) with generous 12cm tolerance
		var best_avail_idx: int = -1
		var best_avail_dist: float = 0.12
		for mv in available_moves:
			var idx = int(mv)
			if idx >= 0 and idx < _spot_positions.size():
				var spos: Vector3 = _spot_positions[idx]
				var d = pt2.distance_to(Vector2(spos.x, spos.z))
				if d < best_avail_dist:
					best_avail_dist = d
					best_avail_idx = idx

		if best_avail_idx >= 0:
			return {"type": "move", "move_idx": best_avail_idx}

	# 4. Check Start Portals for general feedback
	for g_id in _start_portal_positions.keys():
		var sp_pos: Vector3 = _start_portal_positions[g_id]
		if pt2.distance_to(Vector2(sp_pos.x, sp_pos.z)) <= 0.09:
			if g_id == my_id:
				return {"type": "move", "move_idx": -1}
			elif g_id <= players_count and int(start_board_state[g_id - 1].get("count", 0)) > 0:
				return {"type": "wrong_pawn"}

	# 5. Check Corner Home Yards for general feedback
	for g_id in _yard_center_positions.keys():
		var yc: Vector3 = _yard_center_positions[g_id]
		if pt2.distance_to(Vector2(yc.x, yc.z)) <= 0.18 or (absf(local_pt.x - yc.x) <= 0.15 and absf(local_pt.z - yc.z) <= 0.15):
			if g_id == my_id:
				return {"type": "move", "move_idx": -2}
			elif g_id <= players_count:
				return {"type": "wrong_pawn"}

	# 6. Check 52 Track & Home Stretch Spots (0..51) with generous 0.085m tolerance
	var best_idx: int = -1
	var best_dist: float = 0.085
	for idx in range(_spot_positions.size()):
		var spos: Vector3 = _spot_positions[idx]
		var d = pt2.distance_to(Vector2(spos.x, spos.z))
		if d < best_dist:
			best_dist = d
			best_idx = idx

	if best_idx >= 0:
		var owner_id = int(board_state[best_idx].get("equipped_user", 0))
		if owner_id == my_id or available_moves.has(best_idx):
			return {"type": "move", "move_idx": best_idx}
		elif owner_id > 0:
			return {"type": "wrong_pawn"}

	return {}

func _handle_screen_tap(screen_pos: Vector2) -> bool:
	var local_pt = _project_screen_to_board_local(screen_pos)
	if local_pt == null:
		return false
	var hit_info = _hit_test_board_point(local_pt)
	if hit_info.is_empty():
		return false

	var h_type: String = str(hit_info.get("type", ""))
	if h_type == "roll":
		_request_roll_dice()
		return true
	elif h_type == "no_moves":
		if current_dice > 0:
			show_hint("🎲 با تاس %s هیچ حرکتی ممکن نیست؛ نوبت در حال انتقال است..." % _fa_int(current_dice))
		else:
			show_hint("⏳ در انتظار نوبت بعدی...")
		AudioManager.play_sound("wrong_Touch")
		return true
	elif h_type == "move":
		_on_move_index_clicked(int(hit_info["move_idx"]))
		return true
	elif h_type == "wrong_pawn":
		_on_wrong_pawn_clicked()
		return true
	return false

func _on_move_index_hovered(move_idx: int, entered: bool) -> void:
	if not is_instance_valid(_target_preview_ring):
		return
	if not entered or not GameManager.is_my_turn or not has_rolled_this_turn or not available_moves.has(move_idx):
		_target_preview_ring.visible = false
		return
	var my_id = GameManager.my_player_index
	var target_idx = _compute_target_index_for_move(move_idx, my_id, current_dice)
	if target_idx == -1:
		_target_preview_ring.position = _start_portal_positions[my_id]
		_target_preview_ring.visible = true
	elif target_idx >= 0 and target_idx < _spot_positions.size():
		_target_preview_ring.position = _spot_positions[target_idx]
		_target_preview_ring.visible = true
	else:
		_target_preview_ring.visible = false

func _request_roll_dice() -> void:
	if is_board_locked or not GameManager.is_game_active or _is_animating_move:
		return
	if not GameManager.is_my_turn:
		show_hint("⏳ اکنون نوبت شما نیست!")
		AudioManager.play_sound("wrong_Touch")
		return
	if is_out_of_move or (has_rolled_this_turn and available_moves.is_empty()):
		if current_dice > 0:
			show_hint("🎲 با تاس %s هیچ حرکتی ممکن نیست؛ نوبت در حال انتقال است..." % _fa_int(current_dice))
		else:
			show_hint("⏳ در انتظار نوبت بعدی...")
		AudioManager.play_sound("wrong_Touch")
		return
	if has_rolled_this_turn or _roll_request_pending:
		show_hint("🎲 شما تاس انداخته‌اید؛ یکی از مهره‌های درخشان خود را حرکت دهید!")
		return

	_roll_request_pending = true
	if _roll_btn_ui.has("root") and is_instance_valid(_roll_btn_ui["root"]):
		var b_root: Node3D = _roll_btn_ui["root"]
		var tw = create_tween()
		tw.tween_property(b_root, "scale", Vector3(0.94, 0.85, 0.94), 0.07)
		tw.tween_property(b_root, "scale", Vector3.ONE, 0.10)

	AudioManager.play_sound("dice")
	_update_interactive_highlights()
	send_move(Commands.Roll_Dice, {})

func _on_move_index_clicked(move_idx: int) -> void:
	if is_board_locked or not GameManager.is_game_active or _is_animating_move:
		return
	if not GameManager.is_my_turn:
		show_hint("⏳ اکنون نوبت شما نیست!")
		AudioManager.play_sound("wrong_Touch")
		return
	if not has_rolled_this_turn:
		_request_roll_dice()
		return
	if not available_moves.has(move_idx):
		if move_idx == -2 and current_dice != 6:
			show_hint("🎲 برای وارد کردن مهره جدید به بازی باید عدد ۶ بیاورید!")
		else:
			show_hint("⚠️ این مهره با عدد تاس فعلی قابل حرکت نیست!")
		AudioManager.play_sound("wrong_Touch")
		return

	has_rolled_this_turn = false
	available_moves.clear()
	_update_interactive_highlights()
	AudioManager.sfx_tap()
	send_move(Commands.Select_Peace, {"index": move_idx})

func _on_wrong_pawn_clicked() -> void:
	if not GameManager.is_game_active:
		return
	if not GameManager.is_my_turn:
		show_hint("⏳ اکنون نوبت شما نیست!")
	else:
		show_hint("⚠️ فقط مهره‌های هم‌رنگ خودتان را می‌توانید حرکت دهید!")
	AudioManager.play_sound("wrong_Touch")

func _animate_3d_dice_roll(dice_val: int, on_done: Callable = Callable()) -> void:
	if not is_instance_valid(_dice_pivot):
		if on_done.is_valid():
			on_done.call()
		return
	if _dice_tween and _dice_tween.is_valid():
		_dice_tween.kill()

	AudioManager.play_sound("dice")
	var target_rot = _get_die_target_rotation(dice_val)
	var spin_start = target_rot + Vector3(PI * 4.0, PI * 3.0, PI * 2.0)
	_dice_pivot.rotation = spin_start

	_dice_tween = create_tween()
	_dice_tween.set_parallel(true)
	_dice_tween.tween_property(_dice_pivot, "rotation", target_rot, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_dice_tween.tween_property(_dice_pivot, "position:y", 0.120, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dice_tween.chain().tween_property(_dice_pivot, "position:y", 0.048, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_dice_tween.chain().tween_callback(func():
		if on_done.is_valid():
			on_done.call()
	)

# ==============================================================================
# BaseGameBoard Virtual Lifecycle Hooks
# ==============================================================================
func setup_board(game_data: Dictionary) -> void:
	var g_list = game_data.get("gamers", GameManager.match_players)
	var p_cnt = g_list.size() if typeof(g_list) == TYPE_ARRAY and g_list.size() >= 2 else max(2, GameManager.match_players.size())
	_init_empty_state(p_cnt)
	_rebuild_all_pawns_visuals()
	_update_interactive_highlights()

func on_start_game() -> void:
	set_board_locked(false)
	_update_interactive_highlights()

func sync_turn_state() -> void:
	super.sync_turn_state()
	_roll_request_pending = false
	_update_interactive_highlights()

func on_turn_data(payload: Dictionary) -> void:
	var turn_id = int(payload.get("turn", GameManager.current_turn))
	if turn_id > 0:
		GameManager.current_turn = turn_id
		current_turn = turn_id
		on_turn_changed(turn_id, turn_id == GameManager.my_player_index)

func on_turn_changed(turn: int, is_me: bool) -> void:
	current_turn = turn
	is_my_turn = is_me
	has_rolled_this_turn = false
	is_out_of_move = false
	_roll_request_pending = false
	current_dice = 0
	available_moves.clear()
	_update_interactive_highlights()

func on_roll_result(payload: Dictionary) -> void:
	_roll_request_pending = false
	current_dice = int(payload.get("dice", 1))
	has_rolled_this_turn = true

	if payload.has("available_moves") and typeof(payload["available_moves"]) == TYPE_ARRAY:
		available_moves.clear()
		for m in payload["available_moves"]:
			available_moves.append(int(m))
	else:
		available_moves = _compute_local_available_moves(current_turn, current_dice)

	is_out_of_move = available_moves.is_empty()

	_animate_3d_dice_roll(current_dice, func():
		if is_out_of_move and current_turn == GameManager.my_player_index:
			show_hint("🎲 تاس %s آمد — حرکتی برای انجام وجود ندارد!" % _fa_int(current_dice))
		_update_interactive_highlights()
	)

func on_out_of_move(payload: Dictionary) -> void:
	_roll_request_pending = false
	current_dice = int(payload.get("dice", current_dice))
	has_rolled_this_turn = true
	is_out_of_move = true
	available_moves.clear()
	_animate_3d_dice_roll(current_dice, func():
		if current_turn == GameManager.my_player_index:
			show_hint("🎲 تاس %s آمد — حرکتی برای انجام وجود ندارد!" % _fa_int(current_dice))
		_update_interactive_highlights()
	)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id = int(extra.get("gamer_id", user_id))
	var src_index = int(extra.get("index", _target_peace))
	var raw_target = extra.get("target_index", null)
	var target_index: int = int(raw_target) if raw_target != null else -1
	var move_type = str(extra.get("type", "normal"))
	var rolled_dice = int(extra.get("dice", current_dice if current_dice > 0 else 1))

	if extra.has("board") and typeof(extra["board"]) == TYPE_ARRAY:
		board_state = (extra["board"] as Array).duplicate(true)
	if extra.has("start_board") and typeof(extra["start_board"]) == TYPE_ARRAY:
		start_board_state = (extra["start_board"] as Array).duplicate(true)
	if extra.has("players_out_pieces") and typeof(extra["players_out_pieces"]) == TYPE_ARRAY:
		players_out_pieces = (extra["players_out_pieces"] as Array).duplicate(true)

	if not extra.has("board"):
		_apply_move_locally(gamer_id, src_index, target_index, move_type)

	_animate_pawn_move(gamer_id, src_index, target_index, move_type, rolled_dice, extra.get("hit_enemy", null))

func _apply_move_locally(gamer_id: int, src_index: int, target_index: int, move_type: String) -> void:
	if move_type == "out" or src_index == -2:
		if gamer_id - 1 < players_out_pieces.size():
			players_out_pieces[gamer_id - 1] = max(0, int(players_out_pieces[gamer_id - 1]) - 1)
		if gamer_id - 1 < start_board_state.size():
			start_board_state[gamer_id - 1]["count"] = int(start_board_state[gamer_id - 1].get("count", 0)) + 1
			start_board_state[gamer_id - 1]["equipped_user"] = gamer_id
	elif move_type == "start" or src_index == -1:
		if gamer_id - 1 < start_board_state.size():
			var new_c = max(0, int(start_board_state[gamer_id - 1].get("count", 0)) - 1)
			start_board_state[gamer_id - 1]["count"] = new_c
			if new_c == 0:
				start_board_state[gamer_id - 1]["equipped_user"] = 0
		if target_index >= 0 and target_index < board_state.size():
			var td: Dictionary = board_state[target_index]
			if int(td.get("equipped_user", 0)) != 0 and int(td.get("equipped_user", 0)) != gamer_id and target_index < TRACK_SIZE:
				var enemy_id = int(td["equipped_user"])
				if enemy_id - 1 < players_out_pieces.size():
					players_out_pieces[enemy_id - 1] = int(players_out_pieces[enemy_id - 1]) + int(td.get("count", 1))
				td["count"] = 0
			td["equipped_user"] = gamer_id
			td["count"] = int(td.get("count", 0)) + 1
	elif src_index >= 0 and src_index < board_state.size():
		var sd: Dictionary = board_state[src_index]
		var sc = max(0, int(sd.get("count", 0)) - 1)
		sd["count"] = sc
		if sc == 0:
			sd["equipped_user"] = 0
		if target_index >= 0 and target_index < board_state.size():
			var td2: Dictionary = board_state[target_index]
			if int(td2.get("equipped_user", 0)) != 0 and int(td2.get("equipped_user", 0)) != gamer_id and target_index < TRACK_SIZE:
				var enemy_id2 = int(td2["equipped_user"])
				if enemy_id2 - 1 < players_out_pieces.size():
					players_out_pieces[enemy_id2 - 1] = int(players_out_pieces[enemy_id2 - 1]) + int(td2.get("count", 1))
				td2["count"] = 0
			td2["equipped_user"] = gamer_id
			td2["count"] = int(td2.get("count", 0)) + 1

func _animate_pawn_move(gamer_id: int, src_index: int, target_index: int, move_type: String, rolled_dice: int, hit_info: Variant) -> void:
	_is_animating_move = true
	_update_interactive_highlights()

	# Build waypoint positions for smooth step-by-step hop
	var waypoints: Array[Vector3] = []
	var start_pos: Vector3 = Vector3.ZERO

	if move_type == "out" or src_index == -2:
		var slots: Array = _yard_slot_positions.get(gamer_id, [])
		start_pos = slots[0] if not slots.is_empty() else Vector3.ZERO
		waypoints.append(_start_portal_positions.get(gamer_id, Vector3.ZERO))
	elif move_type == "start" or src_index == -1:
		start_pos = _start_portal_positions.get(gamer_id, Vector3.ZERO)
		var entry_idx: int = ENTRY_TRACK_INDEX.get(gamer_id, 0)
		for step in range(max(1, rolled_dice)):
			var s_idx = (entry_idx + step) % TRACK_SIZE
			waypoints.append(_spot_positions[s_idx])
			if s_idx == target_index:
				break
	elif src_index >= 0 and src_index < _spot_positions.size():
		start_pos = _spot_positions[src_index]
		if src_index < TRACK_SIZE and target_index >= 0 and target_index < TRACK_SIZE:
			var cur = src_index
			for _s in range(max(1, rolled_dice)):
				cur = (cur + 1) % TRACK_SIZE
				waypoints.append(_spot_positions[cur])
				if cur == target_index:
					break
		elif target_index >= 0 and target_index < _spot_positions.size():
			waypoints.append(_spot_positions[target_index])

	if waypoints.is_empty() and target_index >= 0 and target_index < _spot_positions.size():
		waypoints.append(_spot_positions[target_index])

	# IMMEDIATELY remove/hide the moving pawn from its start place BEFORE spawning flyer:
	if move_type == "out" or src_index == -2:
		if _yard_pawn_nodes.has(gamer_id) and not _yard_pawn_nodes[gamer_id].is_empty():
			var p_node = _yard_pawn_nodes[gamer_id].pop_back()
			if is_instance_valid(p_node):
				p_node.queue_free()
	elif move_type == "start" or src_index == -1:
		if _start_portal_pawn_nodes.has(gamer_id):
			var sp_node = _start_portal_pawn_nodes[gamer_id]
			var rem_cnt = int(start_board_state[gamer_id - 1].get("count", 0)) if gamer_id - 1 < start_board_state.size() else 0
			if is_instance_valid(sp_node):
				sp_node.queue_free()
			_start_portal_pawn_nodes.erase(gamer_id)
			if rem_cnt > 0:
				var new_sp = _create_royal_pawn_node(gamer_id, rem_cnt)
				new_sp.position = _start_portal_positions[gamer_id]
				_pawns_root.add_child(new_sp)
				_start_portal_pawn_nodes[gamer_id] = new_sp
	elif src_index >= 0 and src_index < _spot_positions.size():
		if _board_spot_pawn_nodes.has(src_index):
			var b_node = _board_spot_pawn_nodes[src_index]
			var rem_cnt = int(board_state[src_index].get("count", 0)) if src_index < board_state.size() else 0
			if is_instance_valid(b_node):
				b_node.queue_free()
			_board_spot_pawn_nodes.erase(src_index)
			if rem_cnt > 0:
				var new_b = _create_royal_pawn_node(gamer_id, rem_cnt)
				new_b.position = _spot_positions[src_index]
				_pawns_root.add_child(new_b)
				_board_spot_pawn_nodes[src_index] = new_b

	# Create the hopping flyer pawn
	var flyer = _create_royal_pawn_node(gamer_id, 1)
	flyer.position = start_pos
	_vfx_root.add_child(flyer)

	var tw = create_tween()
	var prev_pos = start_pos
	for wp in waypoints:
		var mid = (prev_pos + wp) * 0.5 + Vector3(0.0, 0.065, 0.0)
		tw.tween_property(flyer, "position", mid, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(flyer, "position", wp, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): AudioManager.sfx_tap())
		prev_pos = wp

	tw.tween_callback(func():
		if is_instance_valid(flyer):
			flyer.queue_free()
		if typeof(hit_info) == TYPE_DICTIONARY and hit_info.has("enemy_gamer_id"):
			var enemy_id = int(hit_info["enemy_gamer_id"])
			_spawn_capture_vfx(waypoints[-1] if not waypoints.is_empty() else Vector3.ZERO, enemy_id)
		_is_animating_move = false
		_rebuild_all_pawns_visuals()
		_update_interactive_highlights()
	)

func _spawn_capture_vfx(hit_pos: Vector3, enemy_gamer_id: int) -> void:
	AudioManager.play_sound("bell")
	if enemy_gamer_id == GameManager.my_player_index:
		show_hint("💥 مهره شما زده شد و به خانه شروع بازگشت!")
	else:
		show_hint("⚔️ ضربه عالی! مهره %s به خانه شروع فرستاده شد!" % FACTION_NAMES_FA.get(enemy_gamer_id, "حریف"))

	var ring = _create_halo_ring_mesh(0.22 * S, 0.05 * S, _mat_highlight_select)
	ring.position = hit_pos + Vector3(0.0, 0.008, 0.0)
	_vfx_root.add_child(ring)

	var knocked = _create_royal_pawn_node(enemy_gamer_id, 1)
	knocked.position = hit_pos
	_vfx_root.add_child(knocked)

	var yard_slots: Array = _yard_slot_positions.get(enemy_gamer_id, [])
	var dest_yard: Vector3 = yard_slots[0] if not yard_slots.is_empty() else Vector3.ZERO
	var apex = (hit_pos + dest_yard) * 0.5 + Vector3(0.0, 0.22, 0.0)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.6, 1.0, 2.6), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(knocked, "position", apex, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(knocked, "rotation_degrees:x", 360.0, 0.45)
	tw.chain().tween_property(knocked, "position", dest_yard, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
		if is_instance_valid(knocked):
			knocked.queue_free()
	)

func _on_win_happened(payload: Dictionary) -> void:
	var winner_id = int(payload.get("Winner", 0))
	if payload.has("rank1") and payload["rank1"] != null:
		rank1_player = int(payload["rank1"])
		GameManager.ludo_rank1 = rank1_player
	elif rank1_player == 0:
		rank1_player = winner_id
		GameManager.ludo_rank1 = rank1_player

	if payload.has("rank2") and payload["rank2"] != null:
		rank2_player = int(payload["rank2"])
		GameManager.ludo_rank2 = rank2_player

	_sync_header_home_counts()
	AudioManager.play_sound("bell")

	var p_data = GameManager.get_player_data_by_gamer_id(winner_id)
	var p_name = str(p_data.get("name", p_data.get("username", "بازیکن %d" % winner_id)))
	if winner_id == rank1_player:
		show_hint("👑 %s تمام مهره‌های خود را به خانه رساند و مقام اول را کسب کرد!" % p_name)
	else:
		show_hint("🥈 %s به مقام دوم رسید!" % p_name)

func on_player_surrendered(gamer_id: int) -> void:
	if gamer_id >= 1 and gamer_id <= 4:
		if gamer_id - 1 < players_out_pieces.size():
			players_out_pieces[gamer_id - 1] = 4
		if gamer_id - 1 < start_board_state.size():
			start_board_state[gamer_id - 1] = {"count": 0, "equipped_user": 0}
		for i in range(board_state.size()):
			if int(board_state[i].get("equipped_user", 0)) == gamer_id:
				board_state[i] = {"count": 0, "equipped_user": 0}
		_rebuild_all_pawns_visuals()

func sync_board_state(b_data: Variant) -> void:
	if typeof(b_data) == TYPE_ARRAY:
		board_state = (b_data as Array).duplicate(true)
		_rebuild_all_pawns_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) != TYPE_DICTIONARY:
		return

	var g_list = payload.get("gamers", GameManager.match_players)
	if typeof(g_list) == TYPE_ARRAY and g_list.size() >= 2:
		players_count = clampi(g_list.size(), 2, 4)
	elif g_data.has("players_count"):
		players_count = clampi(int(g_data["players_count"]), 2, 4)

	if g_data.has("board") and typeof(g_data["board"]) == TYPE_ARRAY:
		board_state = (g_data["board"] as Array).duplicate(true)
	if g_data.has("start_board") and typeof(g_data["start_board"]) == TYPE_ARRAY:
		start_board_state = (g_data["start_board"] as Array).duplicate(true)
	if g_data.has("players_out_pieces") and typeof(extra_array(g_data, "players_out_pieces")) == TYPE_ARRAY:
		players_out_pieces = (g_data["players_out_pieces"] as Array).duplicate(true)
	if g_data.has("rank1") and g_data["rank1"] != null:
		rank1_player = int(g_data["rank1"])
		GameManager.ludo_rank1 = rank1_player
	if g_data.has("rank2") and g_data["rank2"] != null:
		rank2_player = int(g_data["rank2"])
		GameManager.ludo_rank2 = rank2_player

	current_turn = int(g_data.get("current_turn", GameManager.current_turn))
	current_dice = int(g_data.get("current_dice", 0))
	has_rolled_this_turn = bool(g_data.get("current_turn_player_rolled", false))

	if g_data.has("available_moves") and typeof(g_data["available_moves"]) == TYPE_ARRAY:
		available_moves.clear()
		for m in g_data["available_moves"]:
			available_moves.append(int(m))
	elif has_rolled_this_turn:
		available_moves = _compute_local_available_moves(current_turn, current_dice)
	else:
		available_moves.clear()

	is_out_of_move = has_rolled_this_turn and available_moves.is_empty()

	if current_dice > 0 and is_instance_valid(_dice_pivot):
		_dice_pivot.rotation = _get_die_target_rotation(current_dice)

	_rebuild_all_pawns_visuals()
	_update_interactive_highlights()

func extra_array(d: Dictionary, k: String) -> Variant:
	return d.get(k, null)
