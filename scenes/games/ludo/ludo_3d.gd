extends BaseGameBoard

# Luxury 3D Ludo (منچ) Game Scene for Cafe Fekr
# Supports 2, 3, or 4 Players with full backend protocol synchronization:
# - RollDice -> RollResult (with available_moves) or OutOfMove
# - SelectPeace (index: -2 = Home Yard, -1 = Start Portal, 0..35 = Main Track, 36..51 = Home Stretch)
# - Bonus turn on rolling a 6
# - 1st & 2nd place podium celebration (WinHappened / FinishGame)

const TRACK_SIZE: int = 36
const BOARD_SPOTS_COUNT: int = 52

const FACTION_COLORS: Dictionary = {
	1: Color(0.92, 0.16, 0.22), # Player 1: Ruby Red (South)
	2: Color(0.16, 0.52, 0.96), # Player 2: Royal Sapphire Blue (North)
	3: Color(0.14, 0.78, 0.36), # Player 3: Emerald Jade Green (East)
	4: Color(0.96, 0.74, 0.12), # Player 4: Sunburst Imperial Gold/Yellow (West)
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

const HOME_START_INDEX: Dictionary = {
	1: 36,
	2: 40,
	3: 44,
	4: 48,
}

# Backend win-entry lookup tables (exact mirror of Entities/Games/Ludo/__init__.py)
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
var available_moves: Array = []      # Array of int (-2, -1, 0..51)
var rank1_player: int = 0
var rank2_player: int = 0
var _is_animating_move: bool = false
var _roll_request_pending: bool = false

# 3D Spatial Lookup Positions
var _spot_positions: Array[Vector3] = []          # 0..51
var _start_portal_positions: Dictionary = {}      # gamer_id (1..4) -> Vector3
var _yard_slot_positions: Dictionary = {}         # gamer_id (1..4) -> Array[Vector3] (4 nests)

# 3D Scene Nodes
var _board_root: Node3D = null
var _tiles_root: Node3D = null
var _pawns_root: Node3D = null
var _vfx_root: Node3D = null
var _spot_ring_Highlights: Dictionary = {}        # spot_idx -> MeshInstance3D
var _start_portal_highlights: Dictionary = {}     # gamer_id -> MeshInstance3D
var _yard_highlights: Dictionary = {}             # gamer_id -> Array[MeshInstance3D]
var _target_preview_ring: Node3D = null

# Active 3D Pawn Nodes on the table
var _yard_pawn_nodes: Dictionary = {}             # gamer_id -> Array[Node3D] (up to 4)
var _start_portal_pawn_nodes: Dictionary = {}     # gamer_id -> Node3D
var _board_spot_pawn_nodes: Dictionary = {}       # spot_idx (0..51) -> Node3D

# 3D Interactive Dice Sanctuary
var _dice_sanctuary: Node3D = null
var _dice_pivot: Node3D = null
var _dice_mesh_root: Node3D = null
var _dice_halo_ring: MeshInstance3D = null
var _dice_value_label3d: Label3D = null
var _dice_tween: Tween = null

# 2D Gamer-Friendly Action Bar (Roll Dice Button & Status Pill)
var _hud_layer: CanvasLayer = null
var _action_panel: PanelContainer = null
var _btn_roll_dice: Button = null
var _lbl_status_hint: Label = null
var _dice_badge_lbl: Label = null

var _pulse_time: float = 0.0

# Shared Materials
var _mat_wood_dark: StandardMaterial3D
var _mat_wood_trim: StandardMaterial3D
var _mat_felt_emerald: StandardMaterial3D
var _mat_brass_gold: StandardMaterial3D
var _mat_ivory_tile: StandardMaterial3D
var _mat_faction_enamel: Dictionary = {}
var _mat_faction_pawn: Dictionary = {}
var _mat_highlight_select: StandardMaterial3D
var _mat_highlight_target: StandardMaterial3D

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
	_build_hud_controls()
	_rebuild_all_pawns_visuals()
	_update_interactive_highlights()

func _exit_tree() -> void:
	if NetworkManager.has_signal("win_happened_received"):
		if NetworkManager.win_happened_received.is_connected(_on_win_happened):
			NetworkManager.win_happened_received.disconnect(_on_win_happened)
	if is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
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

func _rotate_xz_90_cw(v: Vector3, quarter_turns: int) -> Vector3:
	var p = v
	for _i in range(quarter_turns % 4):
		p = Vector3(-p.z, p.y, p.x)
	return p

func _compute_all_board_coordinates() -> void:
	_spot_positions.resize(BOARD_SPOTS_COUNT)
	var y_top: float = 0.24

	# Base 9-tile quarter arm (Quarter 0: Tiles 0..8, Bottom Arm going up to Left Arm tip)
	var base_arm: Array[Vector3] = [
		Vector3(-0.62, y_top,  3.10), # k=0: Entry Tile (Tile 0 for P1 Red)
		Vector3(-0.62, y_top,  2.48), # k=1
		Vector3(-0.62, y_top,  1.86), # k=2
		Vector3(-0.62, y_top,  1.24), # k=3
		Vector3(-1.12, y_top,  1.12), # k=4: Inner Corner Junction
		Vector3(-1.24, y_top,  0.62), # k=5
		Vector3(-1.86, y_top,  0.62), # k=6
		Vector3(-2.48, y_top,  0.62), # k=7
		Vector3(-3.10, y_top,  0.00), # k=8: Arm Tip before next player's Home Stretch
	]

	# Quarter 0 -> Tiles 0..8 (Red Entry at 0, West Tip at 8 before Yellow Home)
	# Quarter 1 -> Tiles 9..17 (Yellow Entry at 9, North Tip at 17 before Blue Home)
	# Quarter 2 -> Tiles 18..26 (Blue Entry at 18, East Tip at 26 before Green Home)
	# Quarter 3 -> Tiles 27..35 (Green Entry at 27, South Tip at 35 before Red Home)
	for q in range(4):
		for k in range(9):
			var idx = q * 9 + k
			_spot_positions[idx] = _rotate_xz_90_cw(base_arm[k], q)

	# Home Stretch Corridors (36..51):
	# P1 Red (36..39): South Arm center column (x = 0, z = +2.48 -> +0.86)
	# P2 Blue (40..43): North Arm center column (x = 0, z = -2.48 -> -0.86)
	# P3 Green (44..47): East Arm center row (z = 0, x = +2.48 -> +0.86)
	# P4 Yellow (48..51): West Arm center row (z = 0, x = -2.48 -> -0.86)
	var home_radii: Array[float] = [2.48, 1.94, 1.40, 0.86]
	for step in range(4):
		var r = home_radii[step]
		_spot_positions[36 + step] = Vector3(0.0, y_top,  r) # P1 Red
		_spot_positions[40 + step] = Vector3(0.0, y_top, -r) # P2 Blue
		_spot_positions[44 + step] = Vector3( r,  y_top, 0.0) # P3 Green
		_spot_positions[48 + step] = Vector3(-r,  y_top, 0.0) # P4 Yellow

	# Start Portals (index = -1, staging pedestal right beside each player's Track Entry tile)
	var base_portal = Vector3(-1.32, y_top + 0.02, 3.10)
	_start_portal_positions[1] = _rotate_xz_90_cw(base_portal, 0) # P1 Red: near Tile 0
	_start_portal_positions[4] = _rotate_xz_90_cw(base_portal, 1) # P4 Yellow: near Tile 9
	_start_portal_positions[2] = _rotate_xz_90_cw(base_portal, 2) # P2 Blue: near Tile 18
	_start_portal_positions[3] = _rotate_xz_90_cw(base_portal, 3) # P3 Green: near Tile 27

	# 4 Corner Home Yards (index = -2, 4 pawn sockets per player)
	var yard_centers: Dictionary = {
		1: Vector3(-2.35, y_top + 0.02,  2.35), # P1 Red: Bottom-Left
		4: Vector3(-2.35, y_top + 0.02, -2.35), # P4 Yellow: Top-Left
		2: Vector3( 2.35, y_top + 0.02, -2.35), # P2 Blue: Top-Right
		3: Vector3( 2.35, y_top + 0.02,  2.35), # P3 Green: Bottom-Right
	}
	var offsets: Array[Vector3] = [
		Vector3(-0.42, 0.0, -0.42),
		Vector3( 0.42, 0.0, -0.42),
		Vector3(-0.42, 0.0,  0.42),
		Vector3( 0.42, 0.0,  0.42),
	]
	for g_id in [1, 2, 3, 4]:
		var arr: Array[Vector3] = []
		var c: Vector3 = yard_centers[g_id]
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

	# 1. Carved Royal Cabinet Base & Bevelled Frame
	var cabinet = MeshInstance3D.new()
	var cab_mesh = BoxMesh.new()
	cab_mesh.size = Vector3(7.6, 0.20, 7.6)
	cabinet.mesh = cab_mesh
	cabinet.position = Vector3(0.0, 0.10, 0.0)
	cabinet.material_override = _mat_wood_dark
	_board_root.add_child(cabinet)

	var playfield = MeshInstance3D.new()
	var pf_mesh = BoxMesh.new()
	pf_mesh.size = Vector3(7.1, 0.04, 7.1)
	playfield.mesh = pf_mesh
	playfield.position = Vector3(0.0, 0.21, 0.0)
	playfield.material_override = _mat_felt_emerald
	_board_root.add_child(playfield)

	# Cross Arm Plinths (Horizontal & Vertical Royal Inlays)
	for is_horiz in [false, true]:
		var arm = MeshInstance3D.new()
		var arm_mesh = BoxMesh.new()
		arm_mesh.size = Vector3(6.8, 0.025, 1.92) if is_horiz else Vector3(1.92, 0.025, 6.8)
		arm.mesh = arm_mesh
		arm.position = Vector3(0.0, 0.225, 0.0)
		arm.material_override = _mat_wood_trim
		_board_root.add_child(arm)

	# 4 Raised Brass Rails around Cabinet Perimeter
	var rail_positions = [
		{"pos": Vector3(0.0, 0.24,  3.68), "size": Vector3(7.6, 0.08, 0.22)},
		{"pos": Vector3(0.0, 0.24, -3.68), "size": Vector3(7.6, 0.08, 0.22)},
		{"pos": Vector3( 3.68, 0.24, 0.0), "size": Vector3(0.22, 0.08, 7.2)},
		{"pos": Vector3(-3.68, 0.24, 0.0), "size": Vector3(0.22, 0.08, 7.2)},
	]
	for rp in rail_positions:
		var rail = MeshInstance3D.new()
		var rm = BoxMesh.new()
		rm.size = rp["size"]
		rail.mesh = rm
		rail.position = rp["pos"]
		rail.material_override = _mat_wood_trim
		_board_root.add_child(rail)

		var strip = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(rp["size"].x * 0.96, 0.015, rp["size"].z * 0.55)
		strip.mesh = sm
		strip.position = rp["pos"] + Vector3(0.0, 0.045, 0.0)
		strip.material_override = _mat_brass_gold
		_board_root.add_child(strip)

	# 2. Build 36 Main Track Tiles (0..35) + 16 Home Stretch Tiles (36..51)
	var entry_map_inv: Dictionary = {0: 1, 18: 2, 27: 3, 9: 4}
	for idx in range(BOARD_SPOTS_COUNT):
		var pos = _spot_positions[idx]
		var tile_mat: StandardMaterial3D = _mat_ivory_tile
		var is_special: bool = false
		if idx < TRACK_SIZE:
			if entry_map_inv.has(idx):
				var f_id = entry_map_inv[idx]
				tile_mat = _mat_faction_enamel[f_id]
				is_special = true
		else:
			var home_owner = 1 + int((idx - 36) / 4)
			tile_mat = _mat_faction_enamel[home_owner]
			is_special = true

		_create_tile_medallion(idx, pos, tile_mat, is_special)

	# 3. Build 4 Start Portals (index = -1 for each player 1..4)
	for g_id in [1, 2, 3, 4]:
		_create_start_portal(g_id, _start_portal_positions[g_id])

	# 4. Build 4 Corner Home Yards (index = -2 for each player 1..4)
	var yard_centers: Dictionary = {
		1: Vector3(-2.35, 0.24,  2.35),
		4: Vector3(-2.35, 0.24, -2.35),
		2: Vector3( 2.35, 0.24, -2.35),
		3: Vector3( 2.35, 0.24,  2.35),
	}
	for g_id in [1, 2, 3, 4]:
		_create_corner_home_yard(g_id, yard_centers[g_id])

func _create_tile_medallion(spot_idx: int, pos: Vector3, mat: StandardMaterial3D, is_colored: bool) -> void:
	var holder = Node3D.new()
	holder.name = "Spot_%d" % spot_idx
	holder.position = pos
	_tiles_root.add_child(holder)

	# Outer brass bezel ring
	var bezel = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.255
	bm.bottom_radius = 0.27
	bm.height = 0.032
	bm.radial_segments = 24
	bezel.mesh = bm
	bezel.material_override = _mat_brass_gold if is_colored else _mat_wood_trim
	holder.add_child(bezel)

	# Inner marble/enamel surface
	var disc = MeshInstance3D.new()
	var dm = CylinderMesh.new()
	dm.top_radius = 0.225
	dm.bottom_radius = 0.23
	dm.height = 0.038
	dm.radial_segments = 24
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.004, 0.0)
	disc.material_override = mat
	holder.add_child(disc)

	# Selection Highlight Halo Ring (hidden unless spot_idx is in available_moves)
	var h_ring = _create_halo_ring_mesh(0.27, 0.035, _mat_highlight_select)
	h_ring.position = Vector3(0.0, 0.035, 0.0)
	h_ring.visible = false
	holder.add_child(h_ring)
	_spot_ring_Highlights[spot_idx] = h_ring

	# Clickable Area3D for selecting a pawn on this spot
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.28
	cyl.height = 0.55
	col.shape = cyl
	col.position = Vector3(0.0, 0.22, 0.0)
	area.add_child(col)
	holder.add_child(area)

	var captured_idx = spot_idx
	area.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape: int):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_move_index_clicked(captured_idx)
	)
	area.mouse_entered.connect(func(): _on_move_index_hovered(captured_idx, true))
	area.mouse_exited.connect(func(): _on_move_index_hovered(captured_idx, false))

func _create_start_portal(g_id: int, pos: Vector3) -> void:
	var holder = Node3D.new()
	holder.name = "StartPortal_P%d" % g_id
	holder.position = pos
	_tiles_root.add_child(holder)

	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.28
	bm.bottom_radius = 0.31
	bm.height = 0.045
	bm.radial_segments = 24
	base.mesh = bm
	base.material_override = _mat_brass_gold
	holder.add_child(base)

	var top = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.24
	tm.bottom_radius = 0.25
	tm.height = 0.052
	tm.radial_segments = 24
	top.mesh = tm
	top.position = Vector3(0.0, 0.006, 0.0)
	top.material_override = _mat_faction_enamel[g_id]
	holder.add_child(top)

	var h_ring = _create_halo_ring_mesh(0.30, 0.04, _mat_highlight_select)
	h_ring.position = Vector3(0.0, 0.04, 0.0)
	h_ring.visible = false
	holder.add_child(h_ring)
	_start_portal_highlights[g_id] = h_ring

	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.32
	cyl.height = 0.60
	col.shape = cyl
	col.position = Vector3(0.0, 0.25, 0.0)
	area.add_child(col)
	holder.add_child(area)

	var owner_id = g_id
	area.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if owner_id == GameManager.my_player_index:
				_on_move_index_clicked(-1)
			else:
				_on_wrong_pawn_clicked()
	)
	area.mouse_entered.connect(func():
		if owner_id == GameManager.my_player_index:
			_on_move_index_hovered(-1, true)
	)
	area.mouse_exited.connect(func():
		if owner_id == GameManager.my_player_index:
			_on_move_index_hovered(-1, false)
	)

func _create_corner_home_yard(g_id: int, center_pos: Vector3) -> void:
	var yard = Node3D.new()
	yard.name = "HomeYard_P%d" % g_id
	yard.position = center_pos
	_tiles_root.add_child(yard)

	# Outer Brass & Faction Enamel Platform
	var outer = MeshInstance3D.new()
	var om = CylinderMesh.new()
	om.top_radius = 1.02
	om.bottom_radius = 1.08
	om.height = 0.045
	om.radial_segments = 32
	outer.mesh = om
	outer.material_override = _mat_brass_gold
	yard.add_child(outer)

	var inner = MeshInstance3D.new()
	var im = CylinderMesh.new()
	im.top_radius = 0.94
	im.bottom_radius = 0.96
	im.height = 0.052
	im.radial_segments = 32
	inner.mesh = im
	inner.position = Vector3(0.0, 0.005, 0.0)
	inner.material_override = _mat_faction_enamel[g_id]
	yard.add_child(inner)

	# 4 Nest Sockets inside the Yard
	var nest_rings: Array[MeshInstance3D] = []
	var slots: Array = _yard_slot_positions[g_id]
	for s_idx in range(slots.size()):
		var world_slot: Vector3 = slots[s_idx]
		var local_slot = world_slot - center_pos

		var socket_mesh = MeshInstance3D.new()
		var sm = CylinderMesh.new()
		sm.top_radius = 0.24
		sm.bottom_radius = 0.25
		sm.height = 0.058
		sm.radial_segments = 20
		socket_mesh.mesh = sm
		socket_mesh.position = Vector3(local_slot.x, 0.008, local_slot.z)
		socket_mesh.material_override = _mat_ivory_tile
		yard.add_child(socket_mesh)

		var n_ring = _create_halo_ring_mesh(0.26, 0.035, _mat_highlight_select)
		n_ring.position = Vector3(local_slot.x, 0.042, local_slot.z)
		n_ring.visible = false
		yard.add_child(n_ring)
		nest_rings.append(n_ring)

	_yard_highlights[g_id] = nest_rings

	# Clickable Area3D covering the Yard so clicking ANY yard pawn selects index = -2
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 1.04
	cyl.height = 0.65
	col.shape = cyl
	col.position = Vector3(0.0, 0.28, 0.0)
	area.add_child(col)
	yard.add_child(area)

	var owner_id = g_id
	area.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if owner_id == GameManager.my_player_index:
				_on_move_index_clicked(-2)
			else:
				_on_wrong_pawn_clicked()
	)
	area.mouse_entered.connect(func():
		if owner_id == GameManager.my_player_index:
			_on_move_index_hovered(-2, true)
	)
	area.mouse_exited.connect(func():
		if owner_id == GameManager.my_player_index:
			_on_move_index_hovered(-2, false)
	)

func _build_center_dice_sanctuary() -> void:
	_dice_sanctuary = Node3D.new()
	_dice_sanctuary.name = "CenterDiceSanctuary"
	_dice_sanctuary.position = Vector3(0.0, 0.24, 0.0)
	_board_root.add_child(_dice_sanctuary)

	# Octagonal Brass & Velvet Pedestal
	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.64
	bm.bottom_radius = 0.72
	bm.height = 0.07
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.035, 0.0)
	base.material_override = _mat_brass_gold
	_dice_sanctuary.add_child(base)

	var cushion = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.56
	cm.bottom_radius = 0.58
	cm.height = 0.08
	cm.radial_segments = 8
	cushion.mesh = cm
	cushion.position = Vector3(0.0, 0.04, 0.0)
	cushion.material_override = _mat_felt_emerald
	_dice_sanctuary.add_child(cushion)

	_dice_halo_ring = _create_halo_ring_mesh(0.66, 0.05, _mat_highlight_select)
	_dice_halo_ring.position = Vector3(0.0, 0.082, 0.0)
	_dice_halo_ring.visible = false
	_dice_sanctuary.add_child(_dice_halo_ring)

	# 3D Interactive 6-Sided Ivory & Gold Pipped Die
	_dice_pivot = Node3D.new()
	_dice_pivot.name = "DicePivot"
	_dice_pivot.position = Vector3(0.0, 0.30, 0.0)
	_dice_sanctuary.add_child(_dice_pivot)

	_dice_mesh_root = _create_3d_pipped_die_model(0.38)
	_dice_pivot.add_child(_dice_mesh_root)

	# Floating 3D Number Readout above Center Die
	_dice_value_label3d = Label3D.new()
	_dice_value_label3d.position = Vector3(0.0, 0.72, 0.0)
	_dice_value_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_dice_value_label3d.no_depth_test = true
	_dice_value_label3d.font = preload("res://assets/fonts/hekayat.ttf")
	_dice_value_label3d.font_size = 64
	_dice_value_label3d.outline_size = 14
	_dice_value_label3d.modulate = Color(1.0, 0.92, 0.35)
	_dice_value_label3d.outline_modulate = Color(0.08, 0.04, 0.02, 0.95)
	_dice_value_label3d.text = ""
	_dice_sanctuary.add_child(_dice_value_label3d)

	# Clickable Area3D on Center Sanctuary to Roll Dice
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 0.68
	cyl.height = 0.85
	col.shape = cyl
	col.position = Vector3(0.0, 0.35, 0.0)
	area.add_child(col)
	_dice_sanctuary.add_child(area)

	area.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _s: int):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_request_roll_dice()
	)

func _create_3d_pipped_die_model(sz: float) -> Node3D:
	var root = Node3D.new()

	var mat_ivory = StandardMaterial3D.new()
	mat_ivory.albedo_color = Color(0.98, 0.95, 0.88)
	mat_ivory.roughness = 0.22
	mat_ivory.metallic = 0.05

	var mat_pip_dark = StandardMaterial3D.new()
	mat_pip_dark.albedo_color = Color(0.12, 0.09, 0.08)
	mat_pip_dark.roughness = 0.3

	var mat_pip_red = StandardMaterial3D.new()
	mat_pip_red.albedo_color = Color(0.90, 0.14, 0.18)
	mat_pip_red.roughness = 0.25
	mat_pip_red.emission_enabled = true
	mat_pip_red.emission = Color(0.90, 0.14, 0.18) * 0.25

	var cube = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(sz, sz, sz)
	cube.mesh = bm
	cube.material_override = mat_ivory
	root.add_child(cube)

	var half = sz * 0.502
	var step = sz * 0.26
	var pip_mesh = SphereMesh.new()
	pip_mesh.radius = sz * 0.085
	pip_mesh.height = sz * 0.09

	var layouts = {
		1: [Vector2(0, 0)],
		2: [Vector2(-step, -step), Vector2(step, step)],
		3: [Vector2(-step, -step), Vector2(0, 0), Vector2(step, step)],
		4: [Vector2(-step, -step), Vector2(step, -step), Vector2(-step, step), Vector2(step, step)],
		5: [Vector2(-step, -step), Vector2(step, -step), Vector2(0, 0), Vector2(-step, step), Vector2(step, step)],
		6: [Vector2(-step, -step), Vector2(step, -step), Vector2(-step, 0), Vector2(step, 0), Vector2(-step, step), Vector2(step, step)],
	}
	# Face normals: 1:+Y, 6:-Y, 2:+X, 5:-X, 3:+Z, 4:-Z
	for face_val in layouts.keys():
		var pts: Array = layouts[face_val]
		for pt in pts:
			var pip = MeshInstance3D.new()
			pip.mesh = pip_mesh
			pip.material_override = mat_pip_red if (face_val == 1 or face_val == 6) else mat_pip_dark
			match face_val:
				1: pip.position = Vector3(pt.x, half, pt.y)
				6: pip.position = Vector3(pt.x, -half, pt.y)
				2: pip.position = Vector3(half, pt.x, pt.y)
				5: pip.position = Vector3(-half, pt.x, pt.y)
				3: pip.position = Vector3(pt.x, pt.y, half)
				4: pip.position = Vector3(pt.x, pt.y, -half)
			root.add_child(pip)
	return root

func _get_dice_target_rotation_degrees(face_val: int) -> Vector3:
	match face_val:
		1: return Vector3(0.0, 0.0, 0.0)     # +Y up
		6: return Vector3(180.0, 0.0, 0.0)   # -Y up
		2: return Vector3(0.0, 0.0, 90.0)    # +X up
		5: return Vector3(0.0, 0.0, -90.0)   # -X up
		3: return Vector3(-90.0, 0.0, 0.0)   # +Z up
		4: return Vector3(90.0, 0.0, 0.0)    # -Z up
	return Vector3.ZERO

func _create_royal_pawn_node(g_id: int, stack_count: int = 1) -> Node3D:
	var pawn = Node3D.new()
	var mat: StandardMaterial3D = _mat_faction_pawn.get(g_id, _mat_faction_pawn[1])

	# 1. Brass Base Rim
	var rim = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = 0.165
	rm.bottom_radius = 0.185
	rm.height = 0.04
	rm.radial_segments = 20
	rim.mesh = rm
	rim.position = Vector3(0.0, 0.02, 0.0)
	rim.material_override = _mat_brass_gold
	pawn.add_child(rim)

	# 2. Stepped Lower Pedestal
	var plinth = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.135
	pm.bottom_radius = 0.16
	pm.height = 0.08
	pm.radial_segments = 20
	plinth.mesh = pm
	plinth.position = Vector3(0.0, 0.08, 0.0)
	plinth.material_override = mat
	pawn.add_child(plinth)

	# 3. Tapered Sculpted Body
	var body = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.075
	bm.bottom_radius = 0.125
	bm.height = 0.24
	bm.radial_segments = 20
	body.mesh = bm
	body.position = Vector3(0.0, 0.24, 0.0)
	body.material_override = mat
	pawn.add_child(body)

	# 4. Gold Collar Ring
	var collar = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.095
	cm.bottom_radius = 0.095
	cm.height = 0.032
	cm.radial_segments = 20
	collar.mesh = cm
	collar.position = Vector3(0.0, 0.365, 0.0)
	collar.material_override = _mat_brass_gold
	pawn.add_child(collar)

	# 5. Royal Crown Head Sphere
	var head = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.105
	hm.height = 0.21
	head.mesh = hm
	head.position = Vector3(0.0, 0.45, 0.0)
	head.material_override = mat
	pawn.add_child(head)

	# 6. Gold Finial Tip
	var finial = MeshInstance3D.new()
	var fm = SphereMesh.new()
	fm.radius = 0.038
	fm.height = 0.076
	finial.mesh = fm
	finial.position = Vector3(0.0, 0.565, 0.0)
	finial.material_override = _mat_brass_gold
	pawn.add_child(finial)

	# 7. Stack Count Badge when count > 1
	if stack_count > 1:
		var lbl = Label3D.new()
		lbl.name = "StackLabel"
		lbl.position = Vector3(0.0, 0.72, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font = preload("res://assets/fonts/hekayat.ttf")
		lbl.font_size = 42
		lbl.outline_size = 10
		lbl.modulate = Color(1.0, 0.95, 0.45)
		lbl.outline_modulate = Color(0.05, 0.02, 0.01, 0.98)
		lbl.text = "×%d" % stack_count
		pawn.add_child(lbl)

	return pawn

func _create_halo_ring_mesh(radius: float, thickness: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var m_inst = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = maxf(0.05, radius - thickness)
	torus.outer_radius = radius + thickness
	torus.rings = 24
	torus.ring_segments = 12
	m_inst.mesh = torus
	m_inst.material_override = mat
	return m_inst

func _build_target_preview_indicator() -> void:
	_target_preview_ring = Node3D.new()
	_target_preview_ring.name = "TargetPreviewRing"
	_target_preview_ring.visible = false
	add_child(_target_preview_ring)

	var ring = _create_halo_ring_mesh(0.29, 0.045, _mat_highlight_target)
	_target_preview_ring.add_child(ring)

	var beacon = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.14
	cm.height = 0.22
	beacon.mesh = cm
	beacon.position = Vector3(0.0, 0.22, 0.0)
	beacon.material_override = _mat_highlight_target
	_target_preview_ring.add_child(beacon)

func _build_hud_controls() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)

	_action_panel = PanelContainer.new()
	_action_panel.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_action_panel.anchor_left = 0.5
	_action_panel.anchor_right = 0.5
	_action_panel.anchor_top = 1.0
	_action_panel.anchor_bottom = 1.0
	_action_panel.offset_left = -270.0
	_action_panel.offset_right = 270.0
	_action_panel.offset_top = -238.0
	_action_panel.offset_bottom = -148.0

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.94)
	sb.border_color = Color(0.92, 0.76, 0.32, 0.92)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 10
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_action_panel.add_theme_stylebox_override("panel", sb)
	_hud_layer.add_child(_action_panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_panel.add_child(hbox)

	_btn_roll_dice = Button.new()
	_btn_roll_dice.custom_minimum_size = Vector2(190, 64)
	_btn_roll_dice.text = "🎲 پرتاب تاس"
	_btn_roll_dice.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	_btn_roll_dice.add_theme_font_size_override("font_size", 28)
	KenneyUI.style_button(_btn_roll_dice, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(_btn_roll_dice, "tap_button")
	_btn_roll_dice.pressed.connect(_request_roll_dice)
	hbox.add_child(_btn_roll_dice)

	var dice_pill = PanelContainer.new()
	dice_pill.custom_minimum_size = Vector2(68, 64)
	var d_sb = StyleBoxFlat.new()
	d_sb.bg_color = Color(0.20, 0.13, 0.07, 0.96)
	d_sb.border_color = Color(1.0, 0.85, 0.35, 0.9)
	d_sb.set_border_width_all(2)
	d_sb.set_corner_radius_all(14)
	dice_pill.add_theme_stylebox_override("panel", d_sb)
	hbox.add_child(dice_pill)

	_dice_badge_lbl = Label.new()
	_dice_badge_lbl.text = "-"
	_dice_badge_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	_dice_badge_lbl.add_theme_font_size_override("font_size", 36)
	_dice_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.40))
	_dice_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_pill.add_child(_dice_badge_lbl)

	_lbl_status_hint = Label.new()
	_lbl_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_status_hint.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	_lbl_status_hint.add_theme_font_size_override("font_size", 24)
	_lbl_status_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	_lbl_status_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_status_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_status_hint.text = "در انتظار شروع مسابقه..."
	hbox.add_child(_lbl_status_hint)

func _process(delta: float) -> void:
	_pulse_time += delta * 4.2
	var s_pulse = 1.0 + 0.08 * sin(_pulse_time)
	var y_bob = 0.04 * abs(sin(_pulse_time * 0.85))

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
	for child in _pawns_root.get_children():
		child.queue_free()
	_yard_pawn_nodes.clear()
	_start_portal_pawn_nodes.clear()
	_board_spot_pawn_nodes.clear()

	var total_p = clampi(max(players_count, GameManager.match_players.size()), 2, 4)

	# 1. Spawn Home Yard (Out) Pawns for active players (1..total_p)
	for g_id in range(1, total_p + 1):
		var out_cnt = int(players_out_pieces[g_id - 1]) if g_id - 1 < players_out_pieces.size() else 4
		out_cnt = clampi(out_cnt, 0, 4)
		var arr: Array[Node3D] = []
		var slots: Array = _yard_slot_positions.get(g_id, [])
		for i in range(out_cnt):
			if i < slots.size():
				var p_node = _create_royal_pawn_node(g_id, 1)
				p_node.position = slots[i]
				_pawns_root.add_child(p_node)
				arr.append(p_node)
		_yard_pawn_nodes[g_id] = arr

	# 2. Spawn Start Portal Pawns (start_board_state[0..total_p-1])
	for g_id in range(1, total_p + 1):
		if g_id - 1 < start_board_state.size():
			var s_dict: Dictionary = start_board_state[g_id - 1]
			var cnt = int(s_dict.get("count", 0))
			if cnt > 0:
				var p_node = _create_royal_pawn_node(g_id, cnt)
				p_node.position = _start_portal_positions[g_id]
				_pawns_root.add_child(p_node)
				_start_portal_pawn_nodes[g_id] = p_node

	# 3. Spawn Main Track & Home Stretch Pawns (board_state[0..51])
	for idx in range(min(BOARD_SPOTS_COUNT, board_state.size())):
		var b_dict: Dictionary = board_state[idx]
		var cnt = int(b_dict.get("count", 0))
		var eq_user = int(b_dict.get("equipped_user", 0))
		if cnt > 0 and eq_user >= 1 and eq_user <= 4:
			var p_node = _create_royal_pawn_node(eq_user, cnt)
			p_node.position = _spot_positions[idx]
			_pawns_root.add_child(p_node)
			_board_spot_pawn_nodes[idx] = p_node

	_sync_header_home_counts()

func _sync_header_home_counts() -> void:
	var counts = [0, 0, 0, 0]
	for p_id in [1, 2, 3, 4]:
		var start_idx: int = HOME_START_INDEX[p_id]
		var c: int = 0
		for offset in range(4):
			var idx = start_idx + offset
			if idx < board_state.size():
				var d: Dictionary = board_state[idx]
				if int(d.get("equipped_user", 0)) == p_id and int(d.get("count", 0)) > 0:
					c += int(d.get("count", 1))
		counts[p_id - 1] = c

	GameManager.p1_score = counts[0]
	GameManager.p2_score = counts[1]

	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud) and "current_top_header" in hud and is_instance_valid(hud.current_top_header):
		if hud.current_top_header.has_method("update_ludo_home_counts"):
			hud.current_top_header.update_ludo_home_counts(counts, rank1_player, rank2_player)
		else:
			hud.update_scores(counts[0], counts[1])

func _update_interactive_highlights() -> void:
	# Clear all highlights first
	for k in _spot_ring_Highlights.keys():
		if is_instance_valid(_spot_ring_Highlights[k]):
			_spot_ring_Highlights[k].visible = false
	for k in _start_portal_highlights.keys():
		if is_instance_valid(_start_portal_highlights[k]):
			_start_portal_highlights[k].visible = false
	for g_id in _yard_highlights.keys():
		for r in _yard_highlights[g_id]:
			if is_instance_valid(r):
				r.visible = false
	if is_instance_valid(_target_preview_ring):
		_target_preview_ring.visible = false

	var my_id = GameManager.my_player_index
	var my_turn_now = GameManager.is_game_active and (GameManager.current_turn == my_id) and not is_board_locked
	var can_roll = my_turn_now and not has_rolled_this_turn and not _roll_request_pending and not _is_animating_move
	var can_select = my_turn_now and has_rolled_this_turn and not available_moves.is_empty() and not _is_animating_move

	if is_instance_valid(_dice_halo_ring):
		_dice_halo_ring.visible = can_roll

	if is_instance_valid(_btn_roll_dice):
		_btn_roll_dice.disabled = not can_roll
		_btn_roll_dice.modulate = Color.WHITE if can_roll else Color(0.65, 0.65, 0.65, 0.65)

	if is_instance_valid(_dice_badge_lbl):
		_dice_badge_lbl.text = str(current_dice) if current_dice > 0 else "-"

	if is_instance_valid(_lbl_status_hint):
		if not GameManager.is_game_active:
			_lbl_status_hint.text = "در انتظار شروع مسابقه..."
		elif can_roll:
			_lbl_status_hint.text = "نوبت شماست! روی تاس یا دکمه پرتاب تاس بزنید"
		elif can_select:
			_lbl_status_hint.text = "تاس %d آمد! یکی از مهره‌های درخشان خود را حرکت دهید" % current_dice
		elif _roll_request_pending:
			_lbl_status_hint.text = "در حال پرتاب تاس..."
		else:
			var t_id = max(1, GameManager.current_turn)
			var p_data = GameManager.get_player_data_by_gamer_id(t_id)
			var p_name = str(p_data.get("name", p_data.get("username", "بازیکن %d" % t_id)))
			_lbl_status_hint.text = "نوبت %s (%s)..." % [p_name, FACTION_NAMES_FA.get(t_id, "")]

	if can_select:
		if available_moves.has(-2) and _yard_highlights.has(my_id):
			var out_cnt = int(players_out_pieces[my_id - 1]) if my_id - 1 < players_out_pieces.size() else 0
			var rings: Array = _yard_highlights[my_id]
			for i in range(min(out_cnt, rings.size())):
				if is_instance_valid(rings[i]):
					rings[i].visible = true
		if available_moves.has(-1) and _start_portal_highlights.has(my_id):
			if is_instance_valid(_start_portal_highlights[my_id]):
				_start_portal_highlights[my_id].visible = true
		for mv in available_moves:
			var s_idx = int(mv)
			if s_idx >= 0 and _spot_ring_Highlights.has(s_idx):
				if is_instance_valid(_spot_ring_Highlights[s_idx]):
					_spot_ring_Highlights[s_idx].visible = true

# Computes local legal moves for current_dice and my_player_index as fallback if server RollResult omitted available_moves
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
		return -1 # Moves to Start Portal
	elif index == -1:
		return int(ENTRY_TRACK_INDEX.get(gamer_id, 0)) + dice_val - 1
	elif index >= 36:
		var in_map: Dictionary = GAMER_IN_WIN_INDEXES_MAP.get(gamer_id, {}).get(index, {})
		if in_map.has(dice_val):
			return int(in_map[dice_val])
		return index
	else:
		if (gamer_id == 1 and index <= 29) or (gamer_id == 2 and (index <= 11 or index >= 18)) or (gamer_id == 3 and (index <= 20 or index >= 27)) or (gamer_id == 4 and (index <= 2 or index >= 9)):
			return (index + dice_val) % TRACK_SIZE
		var w_map: Dictionary = GAMER_PIECES_WIN_MAP.get(gamer_id, {}).get(index, {})
		if w_map.has(dice_val) and bool(w_map[dice_val]):
			return int(GAMER_WIN_INDEXES_MAP[gamer_id][index][dice_val])
		return (index + dice_val) % TRACK_SIZE

func _on_move_index_hovered(move_idx: int, entered: bool) -> void:
	if not is_instance_valid(_target_preview_ring):
		return
	if not entered or not GameManager.is_my_turn or not has_rolled_this_turn or not available_moves.has(move_idx):
		_target_preview_ring.visible = false
		return
	var my_id = GameManager.my_player_index
	var target_idx = _compute_target_index_for_move(move_idx, my_id, current_dice)
	if target_idx == -1:
		_target_preview_ring.position = _start_portal_positions[my_id] + Vector3(0.0, 0.04, 0.0)
		_target_preview_ring.visible = true
	elif target_idx >= 0 and target_idx < _spot_positions.size():
		_target_preview_ring.position = _spot_positions[target_idx] + Vector3(0.0, 0.04, 0.0)
		_target_preview_ring.visible = true

func _request_roll_dice() -> void:
	if not GameManager.is_game_active or is_board_locked:
		return
	if GameManager.current_turn != GameManager.my_player_index:
		show_hint("نوبت شما نیست!")
		return
	if has_rolled_this_turn:
		show_hint("شما تاس ریخته‌اید! لطفاً یکی از مهره‌های مجاز خود را انتخاب کنید.")
		return
	if _roll_request_pending or _is_animating_move:
		return
	_roll_request_pending = true
	AudioManager.sfx_tap()
	_update_interactive_highlights()
	send_move(Commands.Roll_Dice, {})

func _on_move_index_clicked(move_idx: int) -> void:
	if not GameManager.is_game_active or is_board_locked or _is_animating_move:
		return
	if GameManager.current_turn != GameManager.my_player_index:
		show_hint("نوبت شما نیست!")
		return
	if not has_rolled_this_turn:
		show_hint("ابتدا تاس بریزید! 🎲")
		return
	if not available_moves.has(move_idx):
		if move_idx == -2 and current_dice != 6:
			show_hint("برای وارد کردن مهره جدید به بازی باید عدد ۶ بیاورید!")
		else:
			show_hint("این مهره با عدد تاس فعلی قابل حرکت نیست!")
		return

	AudioManager.sfx_tap()
	has_rolled_this_turn = false
	available_moves.clear()
	_update_interactive_highlights()
	send_move(Commands.Select_Peace, {"index": move_idx})

func _on_wrong_pawn_clicked() -> void:
	if not GameManager.is_game_active:
		return
	if GameManager.current_turn != GameManager.my_player_index:
		show_hint("نوبت شما نیست!")
	else:
		show_hint("فقط مهره‌های هم‌رنگ خودتان را می‌توانید حرکت دهید!")

func _animate_3d_dice_roll(dice_val: int, on_done: Callable = Callable()) -> void:
	if not is_instance_valid(_dice_pivot):
		if on_done.is_valid():
			on_done.call()
		return
	if _dice_tween and _dice_tween.is_valid():
		_dice_tween.kill()

	AudioManager.sfx_button()
	var target_rot = _get_dice_target_rotation_degrees(dice_val)
	var spin_rot = target_rot + Vector3(720.0, 360.0, 360.0)

	if is_instance_valid(_dice_value_label3d):
		_dice_value_label3d.text = ""

	_dice_tween = create_tween()
	_dice_tween.set_parallel(true)
	_dice_tween.tween_property(_dice_pivot, "position:y", 1.15, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dice_tween.tween_property(_dice_pivot, "rotation_degrees", spin_rot, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_dice_tween.chain().tween_property(_dice_pivot, "position:y", 0.30, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_dice_tween.chain().tween_callback(func():
		_dice_pivot.rotation_degrees = target_rot
		if is_instance_valid(_dice_value_label3d):
			_dice_value_label3d.text = "%d" % dice_val
		if on_done.is_valid():
			on_done.call()
	)

# ============================================================================
# SERVER PROTOCOL HOOKS
# ============================================================================

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
	current_turn = GameManager.current_turn
	my_player_index = GameManager.my_player_index
	is_my_turn = (current_turn == my_player_index)
	_update_interactive_highlights()

func on_turn_data(payload: Dictionary) -> void:
	var is_bonus = bool(payload.get("bonus", false))
	if is_bonus:
		var t_id = int(payload.get("turn", GameManager.current_turn))
		if t_id == GameManager.my_player_index:
			show_hint("🎉 جایزه عدد ۶! دوباره تاس بریزید")

func on_turn_changed(turn: int, is_me: bool) -> void:
	current_turn = turn
	is_my_turn = is_me
	has_rolled_this_turn = false
	_roll_request_pending = false
	current_dice = 0
	available_moves.clear()
	if is_instance_valid(_dice_value_label3d):
		_dice_value_label3d.text = ""
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
		available_moves = _compute_local_available_moves(GameManager.current_turn, current_dice)

	_animate_3d_dice_roll(current_dice, func():
		_update_interactive_highlights()
	)

func on_out_of_move(payload: Dictionary) -> void:
	_roll_request_pending = false
	current_dice = int(payload.get("dice", 1))
	has_rolled_this_turn = false
	available_moves.clear()
	var turn_id = int(payload.get("turn", GameManager.current_turn))
	_animate_3d_dice_roll(current_dice, func():
		if turn_id == GameManager.my_player_index:
			show_hint("🎲 عدد %d آمد — هیچ حرکتی مجاز نیست!" % current_dice)
		_update_interactive_highlights()
	)

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id = int(extra.get("gamer_id", user_id))
	var src_index = int(extra.get("index", _target_peace))
	var raw_target = extra.get("target_index", null)
	var target_index: int = int(raw_target) if raw_target != null else -1
	var move_type = str(extra.get("type", "normal"))
	var rolled_dice = int(extra.get("dice", current_dice if current_dice > 0 else 1))

	# Update authoritative board state from server payload if included, otherwise apply locally
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

	var flyer = _create_royal_pawn_node(gamer_id, 1)
	flyer.position = start_pos
	_vfx_root.add_child(flyer)

	var tw = create_tween()
	for wp in waypoints:
		var mid = (flyer.position + wp) * 0.5 + Vector3(0.0, 0.42, 0.0)
		tw.tween_property(flyer, "position", mid, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(flyer, "position", wp, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): AudioManager.sfx_tap())

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

	var ring = _create_halo_ring_mesh(0.22, 0.05, _mat_highlight_select)
	ring.position = hit_pos + Vector3(0.0, 0.06, 0.0)
	_vfx_root.add_child(ring)

	var knocked = _create_royal_pawn_node(enemy_gamer_id, 1)
	knocked.position = hit_pos
	_vfx_root.add_child(knocked)

	var yard_slots: Array = _yard_slot_positions.get(enemy_gamer_id, [])
	var dest_yard: Vector3 = yard_slots[0] if not yard_slots.is_empty() else Vector3.ZERO
	var apex = (hit_pos + dest_yard) * 0.5 + Vector3(0.0, 1.35, 0.0)

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
	if g_data.has("players_out_pieces") and typeof(g_data["players_out_pieces"]) == TYPE_ARRAY:
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

	if current_dice > 0 and is_instance_valid(_dice_pivot):
		_dice_pivot.rotation_degrees = _get_dice_target_rotation_degrees(current_dice)
		if is_instance_valid(_dice_value_label3d):
			_dice_value_label3d.text = "%d" % current_dice

	_rebuild_all_pawns_visuals()
	_update_interactive_highlights()
