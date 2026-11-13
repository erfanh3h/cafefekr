class_name Quoridor3D
extends "res://scripts/games/base_game_board.gd"

# Quoridor 3D Board (کوریدور — Cafe Fekr Royal Tournament Edition)
# Full 2-player 9x9 Quoridor engine synced 1:1 with backend Entities/Games/Quoridor/__init__.py.
# - Pawns reuse Ludo's sculpted 6-part royal piece geometry (_create_royal_pawn_node)
# - 9x9 inlaid maple & walnut tiles + brass wall channels + watchtower corner finials + illuminated goal gates
# - Left/Right mahogany wall racks holding 10 physical 3D beveled fences per player
# - Single-source raycast plane input in _unhandled_input + mobile-friendly 2-tap / confirm wall placement UX

const BOARD_SIZE: int = 9
const WALL_GRID_SIZE: int = 8
const INITIAL_WALLS: int = 10

const BOARD_SURFACE_Y: float = 0.038
const CELL_STEP: float = 0.092
const TILE_SIZE: float = 0.072
const TILE_HEIGHT: float = 0.012
const WALL_LENGTH: float = 0.168
const WALL_THICK: float = 0.014
const WALL_HEIGHT: float = 0.068
const PAWN_SCALE: float = 0.215

const ACTION_MOVE: int = 0
const ACTION_WALL_H: int = 1
const ACTION_WALL_V: int = 2

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")

# --- Authoritative State ---
var pawns: Array = [[8, 4], [0, 4]] # index 0 -> Player 1, index 1 -> Player 2
var walls_left: Array = [10, 10]     # index 0 -> Player 1, index 1 -> Player 2
var h_walls: Array = []              # array of [wr, wc]
var v_walls: Array = []              # array of [wr, wc]
var _h_set: Dictionary = {}          # "wr,wc" -> true
var _v_set: Dictionary = {}          # "wr,wc" -> true
var winner_id: int = 0

# --- Interaction State ---
var current_mode: int = ACTION_MOVE
var preview_wall_rc: Vector2i = Vector2i(-1, -1)
var preview_wall_valid: bool = false
var hovered_cell_rc: Vector2i = Vector2i(-1, -1)
var _pulse_time: float = 0.0
var _win_vfx_shown: bool = false

# --- 3D Hierarchy ---
var board_root: Node3D = null
var tiles_root: Node3D = null
var walls_root: Node3D = null
var racks_root: Node3D = null
var pawns_root: Node3D = null
var highlights_root: Node3D = null
var decor_root: Node3D = null
var fx_root: Node3D = null

var pawn_nodes: Array[Node3D] = [null, null]
var pawn_turn_rings: Array[MeshInstance3D] = [null, null]
var legal_move_pads: Array[MeshInstance3D] = [] # 81 cell highlight pads
var last_move_pad: MeshInstance3D = null
var ghost_wall_node: Node3D = null
var ghost_wall_mesh: MeshInstance3D = null

var wall_rack_nodes: Array = [[], []] # P1 rack (10 meshes), P2 rack (10 meshes)
var placed_wall_nodes: Array[Node3D] = []

var lbl_top_goal_3d: Label3D = null
var lbl_bottom_start_3d: Label3D = null
var goal_strip_top: MeshInstance3D = null
var goal_strip_bottom: MeshInstance3D = null

# --- Floating Gamer-Friendly Control Dock (CanvasLayer) ---
var dock_layer: CanvasLayer = null
var dock_panel: PanelContainer = null
var btn_mode_move: Button = null
var btn_mode_wall_h: Button = null
var btn_mode_wall_v: Button = null
var btn_confirm_wall: Button = null

# --- Luxury Procedural Materials ---
var _mat_walnut: StandardMaterial3D
var _mat_mahogany: StandardMaterial3D
var _mat_tile_light: StandardMaterial3D
var _mat_tile_dark: StandardMaterial3D
var _mat_groove_gold: StandardMaterial3D
var _mat_brass_gold: StandardMaterial3D
var _mat_obsidian: StandardMaterial3D
var _mat_faction_pawn: Dictionary = {}
var _mat_wall_p1: StandardMaterial3D
var _mat_wall_p2: StandardMaterial3D
var _mat_wall_default: StandardMaterial3D
var _mat_legal_pad: StandardMaterial3D
var _mat_legal_jump_pad: StandardMaterial3D
var _mat_hover_pad: StandardMaterial3D
var _mat_last_pad: StandardMaterial3D
var _mat_ghost_valid: StandardMaterial3D
var _mat_ghost_invalid: StandardMaterial3D
var _mat_goal_emerald: StandardMaterial3D
var _mat_goal_crimson: StandardMaterial3D
var _mat_goal_sapphire: StandardMaterial3D

static func _fa_digits(val: Variant) -> String:
	var s := str(val)
	var fa := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			out += fa[int(ch)]
		else:
			out += ch
	return out

func _init() -> void:
	game_type = GameTypes.QUORIDOR

func _ready() -> void:
	game_type = GameTypes.QUORIDOR
	add_to_group("board")
	_init_materials()
	_build_board_3d()
	_build_action_dock()
	_reset_internal_state()
	_sync_all_visuals()
	super._ready()

func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse := 1.0 + 0.085 * sin(_pulse_time * 5.2)

	for i in range(legal_move_pads.size()):
		var pad: MeshInstance3D = legal_move_pads[i]
		if is_instance_valid(pad) and pad.visible:
			pad.scale = Vector3(pulse, 1.0, pulse)

	var active_idx := clampi(current_turn - 1, 0, 1)
	for p_idx in range(2):
		var ring: MeshInstance3D = pawn_turn_rings[p_idx]
		if is_instance_valid(ring):
			ring.visible = GameManager.is_game_active and winner_id == 0 and (p_idx == active_idx)
			if ring.visible:
				var rp := 1.0 + 0.10 * sin(_pulse_time * 6.0)
				ring.scale = Vector3(rp, 1.0, rp)

	_update_dock_visibility()

func _is_board_flipped() -> bool:
	return my_player_index == 2

func _canonical_to_visual_rc(r: int, c: int) -> Vector2i:
	if _is_board_flipped():
		return Vector2i(BOARD_SIZE - 1 - r, BOARD_SIZE - 1 - c)
	return Vector2i(r, c)

func _visual_to_canonical_rc(vr: int, vc: int) -> Vector2i:
	if _is_board_flipped():
		return Vector2i(BOARD_SIZE - 1 - vr, BOARD_SIZE - 1 - vc)
	return Vector2i(vr, vc)

func _canonical_to_visual_wall(wr: int, wc: int) -> Vector2i:
	if _is_board_flipped():
		return Vector2i(WALL_GRID_SIZE - 1 - wr, WALL_GRID_SIZE - 1 - wc)
	return Vector2i(wr, wc)

func _visual_to_canonical_wall(vwr: int, vwc: int) -> Vector2i:
	if _is_board_flipped():
		return Vector2i(WALL_GRID_SIZE - 1 - vwr, WALL_GRID_SIZE - 1 - vwc)
	return Vector2i(vwr, vwc)

func _cell_to_local_pos(r: int, c: int, y_offset: float = 0.0) -> Vector3:
	var vis := _canonical_to_visual_rc(r, c)
	var x := (float(vis.y) - 4.0) * CELL_STEP
	var z := (float(vis.x) - 4.0) * CELL_STEP
	return Vector3(x, BOARD_SURFACE_Y + TILE_HEIGHT + y_offset, z)

func _wall_to_local_pos(wr: int, wc: int, y_offset: float = 0.0) -> Vector3:
	var vis := _canonical_to_visual_wall(wr, wc)
	var x := (float(vis.y) - 3.5) * CELL_STEP
	var z := (float(vis.x) - 3.5) * CELL_STEP
	return Vector3(x, BOARD_SURFACE_Y + y_offset, z)

# ============================================================================
# 1. PROCEDURAL LUXURY MATERIALS
# ============================================================================

func _init_materials() -> void:
	_mat_walnut = StandardMaterial3D.new()
	_mat_walnut.albedo_color = Color(0.20, 0.11, 0.06)
	_mat_walnut.metallic = 0.06
	_mat_walnut.roughness = 0.36

	_mat_mahogany = StandardMaterial3D.new()
	_mat_mahogany.albedo_color = Color(0.32, 0.14, 0.07)
	_mat_mahogany.metallic = 0.10
	_mat_mahogany.roughness = 0.30

	_mat_tile_light = StandardMaterial3D.new()
	_mat_tile_light.albedo_color = Color(0.79, 0.65, 0.46)
	_mat_tile_light.roughness = 0.34
	_mat_tile_light.metallic = 0.04

	_mat_tile_dark = StandardMaterial3D.new()
	_mat_tile_dark.albedo_color = Color(0.30, 0.19, 0.12)
	_mat_tile_dark.roughness = 0.36
	_mat_tile_dark.metallic = 0.05

	_mat_groove_gold = StandardMaterial3D.new()
	_mat_groove_gold.albedo_color = Color(0.11, 0.07, 0.04)
	_mat_groove_gold.roughness = 0.55

	_mat_brass_gold = StandardMaterial3D.new()
	_mat_brass_gold.albedo_color = Color(0.95, 0.78, 0.28)
	_mat_brass_gold.metallic = 0.90
	_mat_brass_gold.roughness = 0.20

	_mat_obsidian = StandardMaterial3D.new()
	_mat_obsidian.albedo_color = Color(0.08, 0.08, 0.11)
	_mat_obsidian.metallic = 0.20
	_mat_obsidian.roughness = 0.40

	var mat_p1 := StandardMaterial3D.new()
	mat_p1.albedo_color = Color(0.90, 0.14, 0.18)
	mat_p1.roughness = 0.18
	mat_p1.metallic = 0.12
	mat_p1.emission_enabled = true
	mat_p1.emission = Color(0.35, 0.04, 0.05)
	mat_p1.emission_energy_multiplier = 0.35
	_mat_faction_pawn[1] = mat_p1

	var mat_p2 := StandardMaterial3D.new()
	mat_p2.albedo_color = Color(0.14, 0.52, 0.96)
	mat_p2.roughness = 0.18
	mat_p2.metallic = 0.12
	mat_p2.emission_enabled = true
	mat_p2.emission = Color(0.04, 0.16, 0.40)
	mat_p2.emission_energy_multiplier = 0.35
	_mat_faction_pawn[2] = mat_p2

	_mat_wall_p1 = StandardMaterial3D.new()
	_mat_wall_p1.albedo_color = Color(0.68, 0.22, 0.12)
	_mat_wall_p1.roughness = 0.28
	_mat_wall_p1.metallic = 0.08

	_mat_wall_p2 = StandardMaterial3D.new()
	_mat_wall_p2.albedo_color = Color(0.16, 0.36, 0.58)
	_mat_wall_p2.roughness = 0.28
	_mat_wall_p2.metallic = 0.08

	_mat_wall_default = StandardMaterial3D.new()
	_mat_wall_default.albedo_color = Color(0.58, 0.34, 0.16)
	_mat_wall_default.roughness = 0.30
	_mat_wall_default.metallic = 0.06

	_mat_legal_pad = StandardMaterial3D.new()
	_mat_legal_pad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_legal_pad.albedo_color = Color(0.22, 0.92, 0.48, 0.55)
	_mat_legal_pad.emission_enabled = true
	_mat_legal_pad.emission = Color(0.18, 0.88, 0.42)
	_mat_legal_pad.emission_energy_multiplier = 1.15

	_mat_legal_jump_pad = StandardMaterial3D.new()
	_mat_legal_jump_pad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_legal_jump_pad.albedo_color = Color(1.0, 0.82, 0.22, 0.65)
	_mat_legal_jump_pad.emission_enabled = true
	_mat_legal_jump_pad.emission = Color(1.0, 0.78, 0.18)
	_mat_legal_jump_pad.emission_energy_multiplier = 1.35

	_mat_hover_pad = StandardMaterial3D.new()
	_mat_hover_pad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_pad.albedo_color = Color(0.98, 0.94, 0.40, 0.80)
	_mat_hover_pad.emission_enabled = true
	_mat_hover_pad.emission = Color(1.0, 0.88, 0.32)
	_mat_hover_pad.emission_energy_multiplier = 1.60

	_mat_last_pad = StandardMaterial3D.new()
	_mat_last_pad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_last_pad.albedo_color = Color(1.0, 0.62, 0.16, 0.38)
	_mat_last_pad.emission_enabled = true
	_mat_last_pad.emission = Color(1.0, 0.55, 0.12)
	_mat_last_pad.emission_energy_multiplier = 0.7

	_mat_ghost_valid = StandardMaterial3D.new()
	_mat_ghost_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost_valid.albedo_color = Color(0.20, 0.95, 0.46, 0.68)
	_mat_ghost_valid.emission_enabled = true
	_mat_ghost_valid.emission = Color(0.20, 0.92, 0.44)
	_mat_ghost_valid.emission_energy_multiplier = 1.4

	_mat_ghost_invalid = StandardMaterial3D.new()
	_mat_ghost_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost_invalid.albedo_color = Color(0.98, 0.22, 0.24, 0.68)
	_mat_ghost_invalid.emission_enabled = true
	_mat_ghost_invalid.emission = Color(0.98, 0.18, 0.20)
	_mat_ghost_invalid.emission_energy_multiplier = 1.35

	_mat_goal_emerald = StandardMaterial3D.new()
	_mat_goal_emerald.albedo_color = Color(0.18, 0.84, 0.44)
	_mat_goal_emerald.emission_enabled = true
	_mat_goal_emerald.emission = Color(0.14, 0.75, 0.36)
	_mat_goal_emerald.emission_energy_multiplier = 1.1
	_mat_goal_emerald.roughness = 0.22

	_mat_goal_crimson = StandardMaterial3D.new()
	_mat_goal_crimson.albedo_color = Color(0.92, 0.22, 0.24)
	_mat_goal_crimson.emission_enabled = true
	_mat_goal_crimson.emission = Color(0.85, 0.18, 0.20)
	_mat_goal_crimson.emission_energy_multiplier = 0.9

	_mat_goal_sapphire = StandardMaterial3D.new()
	_mat_goal_sapphire.albedo_color = Color(0.18, 0.56, 0.96)
	_mat_goal_sapphire.emission_enabled = true
	_mat_goal_sapphire.emission = Color(0.16, 0.50, 0.92)
	_mat_goal_sapphire.emission_energy_multiplier = 0.9

# ============================================================================
# 2. SCULPTED 3D BOARD, LUDO PAWNS, WALL RACKS & CORNER FINIALS
# ============================================================================

func _add_box_mesh(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _add_cyl_mesh(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, segs: int = 18) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _build_board_3d() -> void:
	board_root = Node3D.new()
	board_root.name = "QuoridorBoardRoot"
	add_child(board_root)

	tiles_root = Node3D.new()
	board_root.add_child(tiles_root)
	walls_root = Node3D.new()
	board_root.add_child(walls_root)
	racks_root = Node3D.new()
	board_root.add_child(racks_root)
	pawns_root = Node3D.new()
	board_root.add_child(pawns_root)
	highlights_root = Node3D.new()
	board_root.add_child(highlights_root)
	decor_root = Node3D.new()
	board_root.add_child(decor_root)
	fx_root = Node3D.new()
	board_root.add_child(fx_root)

	# 1. Luxury Walnut Chassis + Recessed Groove Bed + Mahogany & Brass Molding Frame
	_add_box_mesh(decor_root, Vector3(0.96, BOARD_SURFACE_Y, 0.96), Vector3(0.0, BOARD_SURFACE_Y * 0.5, 0.0), _mat_walnut)
	_add_box_mesh(decor_root, Vector3(0.84, 0.008, 0.84), Vector3(0.0, BOARD_SURFACE_Y + 0.002, 0.0), _mat_groove_gold)

	# Raised outer frame molding rails (4 edges)
	var rail_len := 0.98
	var rail_w := 0.055
	var rail_y := BOARD_SURFACE_Y + 0.012
	_add_box_mesh(decor_root, Vector3(rail_len, 0.024, rail_w), Vector3(0.0, rail_y, -0.462), _mat_mahogany)
	_add_box_mesh(decor_root, Vector3(rail_len, 0.024, rail_w), Vector3(0.0, rail_y, 0.462), _mat_mahogany)
	_add_box_mesh(decor_root, Vector3(rail_w, 0.024, rail_len), Vector3(-0.462, rail_y, 0.0), _mat_mahogany)
	_add_box_mesh(decor_root, Vector3(rail_w, 0.024, rail_len), Vector3(0.462, rail_y, 0.0), _mat_mahogany)

	# Brass inlay accent trim around the 9x9 grid
	_add_box_mesh(decor_root, Vector3(0.855, 0.004, 0.008), Vector3(0.0, BOARD_SURFACE_Y + 0.024, -0.432), _mat_brass_gold)
	_add_box_mesh(decor_root, Vector3(0.855, 0.004, 0.008), Vector3(0.0, BOARD_SURFACE_Y + 0.024, 0.432), _mat_brass_gold)
	_add_box_mesh(decor_root, Vector3(0.008, 0.004, 0.855), Vector3(-0.432, BOARD_SURFACE_Y + 0.024, 0.0), _mat_brass_gold)
	_add_box_mesh(decor_root, Vector3(0.008, 0.004, 0.855), Vector3(0.432, BOARD_SURFACE_Y + 0.024, 0.0), _mat_brass_gold)

	# Illuminated Goal Threshold Strips & Ornamental Labyrinth Watchtower Pillars at the 4 corners
	goal_strip_top = _add_box_mesh(decor_root, Vector3(0.81, 0.006, 0.016), Vector3(0.0, BOARD_SURFACE_Y + 0.024, -0.422), _mat_goal_emerald)
	goal_strip_bottom = _add_box_mesh(decor_root, Vector3(0.81, 0.006, 0.016), Vector3(0.0, BOARD_SURFACE_Y + 0.024, 0.422), _mat_goal_crimson)

	# Carved Brass Goal Gate Posts flanking top (finish) and bottom (origin) edges
	for z_gate: float in [-0.462, 0.462]:
		var g_mat: StandardMaterial3D = _mat_goal_emerald if z_gate < 0.0 else _mat_brass_gold
		for x_post: float in [-0.21, 0.21]:
			_add_cyl_mesh(decor_root, 0.014, 0.018, 0.036, Vector3(x_post, BOARD_SURFACE_Y + 0.036, z_gate), _mat_brass_gold, 12)
			var finial := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.012
			fm.height = 0.024
			finial.mesh = fm
			finial.position = Vector3(x_post, BOARD_SURFACE_Y + 0.058, z_gate)
			finial.material_override = g_mat
			decor_root.add_child(finial)

	var corner_coords: Array[Vector2] = [
		Vector2(-0.462, -0.462), Vector2(0.462, -0.462),
		Vector2(-0.462, 0.462),  Vector2(0.462, 0.462)
	]
	for idx in range(corner_coords.size()):
		var cc: Vector2 = corner_coords[idx]
		var tower := Node3D.new()
		tower.position = Vector3(cc.x, BOARD_SURFACE_Y + 0.024, cc.y)
		decor_root.add_child(tower)
		_add_cyl_mesh(tower, 0.026, 0.032, 0.014, Vector3(0.0, 0.007, 0.0), _mat_brass_gold, 8)
		_add_cyl_mesh(tower, 0.019, 0.024, 0.044, Vector3(0.0, 0.036, 0.0), _mat_mahogany, 8)
		_add_cyl_mesh(tower, 0.024, 0.024, 0.010, Vector3(0.0, 0.062, 0.0), _mat_brass_gold, 8)
		var gem_mat := _mat_goal_emerald if cc.y < 0.0 else _mat_brass_gold
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.015
		sm.height = 0.030
		gem.mesh = sm
		gem.position = Vector3(0.0, 0.078, 0.0)
		gem.material_override = gem_mat
		tower.add_child(gem)

	# Center Goal & Start Edge Direction Labels
	lbl_top_goal_3d = Label3D.new()
	lbl_top_goal_3d.text = "🏁 خط پایان شما"
	lbl_top_goal_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.030, -0.465)
	lbl_top_goal_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl_top_goal_3d.pixel_size = 0.0011
	lbl_top_goal_3d.font = _font_hekayat
	lbl_top_goal_3d.font_size = 34
	lbl_top_goal_3d.outline_size = 14
	lbl_top_goal_3d.modulate = Color(0.55, 1.0, 0.68)
	lbl_top_goal_3d.outline_modulate = Color(0.06, 0.03, 0.01, 0.98)
	decor_root.add_child(lbl_top_goal_3d)

	lbl_bottom_start_3d = Label3D.new()
	lbl_bottom_start_3d.text = "▲ مسیر حرکت شما ▲"
	lbl_bottom_start_3d.position = Vector3(0.0, BOARD_SURFACE_Y + 0.030, 0.465)
	lbl_bottom_start_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl_bottom_start_3d.pixel_size = 0.0010
	lbl_bottom_start_3d.font = _font_hekayat
	lbl_bottom_start_3d.font_size = 30
	lbl_bottom_start_3d.outline_size = 14
	lbl_bottom_start_3d.modulate = Color(1.0, 0.90, 0.55)
	lbl_bottom_start_3d.outline_modulate = Color(0.06, 0.03, 0.01, 0.98)
	decor_root.add_child(lbl_bottom_start_3d)

	# 2. 9x9 Beveled Board Squares + Legal Move Highlight Pads
	legal_move_pads.clear()
	for vr in range(BOARD_SIZE):
		for vc in range(BOARD_SIZE):
			var x := (float(vc) - 4.0) * CELL_STEP
			var z := (float(vr) - 4.0) * CELL_STEP
			var tile_mat := _mat_tile_light if ((vr + vc) % 2 == 0) else _mat_tile_dark
			_add_box_mesh(tiles_root, Vector3(TILE_SIZE, TILE_HEIGHT, TILE_SIZE), Vector3(x, BOARD_SURFACE_Y + TILE_HEIGHT * 0.5, z), tile_mat)

			var pad := _add_box_mesh(highlights_root, Vector3(TILE_SIZE * 0.82, 0.004, TILE_SIZE * 0.82), Vector3(x, BOARD_SURFACE_Y + TILE_HEIGHT + 0.003, z), _mat_legal_pad)
			pad.visible = false
			legal_move_pads.append(pad)

	last_move_pad = _add_box_mesh(highlights_root, Vector3(TILE_SIZE * 0.92, 0.003, TILE_SIZE * 0.92), Vector3(0.0, BOARD_SURFACE_Y + TILE_HEIGHT + 0.002, 0.0), _mat_last_pad)
	last_move_pad.visible = false

	# 3. Left & Right Mahogany Wall Racks (10 sculpted 3D fences per player)
	_build_wall_racks()

	# 4. Sculpted Ludo Royal Pawn Pieces (Player 1 Ruby vs Player 2 Sapphire)
	for p_id: int in [1, 2]:
		var holder := Node3D.new()
		holder.name = "PawnHolder_P%d" % p_id
		pawns_root.add_child(holder)

		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.030
		tm.outer_radius = 0.039
		ring.mesh = tm
		ring.position = Vector3(0.0, 0.004, 0.0)
		ring.material_override = _mat_hover_pad if p_id == 1 else _mat_legal_pad
		ring.visible = false
		holder.add_child(ring)

		var ludo_pawn := _create_royal_pawn_node(p_id)
		holder.add_child(ludo_pawn)

		pawn_nodes[p_id - 1] = holder
		pawn_turn_rings[p_id - 1] = ring

	# 5. Live 3D Wall Ghost Preview Node
	ghost_wall_node = Node3D.new()
	ghost_wall_node.visible = false
	highlights_root.add_child(ghost_wall_node)
	ghost_wall_mesh = _add_box_mesh(ghost_wall_node, Vector3(WALL_LENGTH, WALL_HEIGHT + 0.006, WALL_THICK + 0.004), Vector3(0.0, (WALL_HEIGHT + 0.006) * 0.5, 0.0), _mat_ghost_valid)

func _build_wall_racks() -> void:
	for side_idx in range(2):
		var side_x := -0.575 if side_idx == 0 else 0.575
		var p_id := side_idx + 1
		# Base mahogany tray slab with brass trim
		_add_box_mesh(racks_root, Vector3(0.11, 0.022, 0.82), Vector3(side_x, 0.011, 0.0), _mat_walnut)
		_add_box_mesh(racks_root, Vector3(0.116, 0.006, 0.826), Vector3(side_x, 0.022, 0.0), _mat_brass_gold)

		wall_rack_nodes[side_idx] = []
		var fence_mat := _mat_wall_p1 if p_id == 1 else _mat_wall_p2
		for w_i in range(INITIAL_WALLS):
			var z_slot := (float(w_i) - 4.5) * 0.072
			var f_node := _create_fence_3d(fence_mat, WALL_LENGTH * 0.54, WALL_HEIGHT * 0.72, WALL_THICK * 0.90)
			f_node.position = Vector3(side_x, 0.025, z_slot)
			racks_root.add_child(f_node)
			wall_rack_nodes[side_idx].append(f_node)

func _create_fence_3d(main_mat: Material, length: float = WALL_LENGTH, height: float = WALL_HEIGHT, thick: float = WALL_THICK) -> Node3D:
	var fence := Node3D.new()
	# Sculpted mahogany/tinted wooden plank body
	_add_box_mesh(fence, Vector3(length, height, thick), Vector3(0.0, height * 0.5, 0.0), main_mat)
	# Brushed brass top crest & end-cap pillars
	_add_box_mesh(fence, Vector3(length + 0.004, 0.007, thick + 0.003), Vector3(0.0, height + 0.0035, 0.0), _mat_brass_gold)
	_add_box_mesh(fence, Vector3(0.012, height + 0.008, thick + 0.004), Vector3(-length * 0.5, height * 0.5 + 0.004, 0.0), _mat_brass_gold)
	_add_box_mesh(fence, Vector3(0.012, height + 0.008, thick + 0.004), Vector3(length * 0.5, height * 0.5 + 0.004, 0.0), _mat_brass_gold)
	return fence

# Exact Ludo Royal Pawn 3D geometry (ported from scenes/games/ludo/ludo_3d.gd)
func _create_royal_pawn_node(g_id: int) -> Node3D:
	var pawn := Node3D.new()
	var mat: StandardMaterial3D = _mat_faction_pawn.get(g_id, _mat_faction_pawn[1])
	var s := PAWN_SCALE

	# 1. Brass Base Rim
	_add_cyl_mesh(pawn, 0.165 * s, 0.185 * s, 0.04 * s, Vector3(0.0, 0.02 * s, 0.0), _mat_brass_gold, 20)
	# 2. Stepped Lower Pedestal
	_add_cyl_mesh(pawn, 0.135 * s, 0.165 * s, 0.09 * s, Vector3(0.0, 0.085 * s, 0.0), mat, 20)
	# 3. Sculpted Tapered Body Column
	_add_cyl_mesh(pawn, 0.072 * s, 0.130 * s, 0.24 * s, Vector3(0.0, 0.25 * s, 0.0), mat, 20)
	# 4. Golden Neck Collar Ring
	_add_cyl_mesh(pawn, 0.096 * s, 0.096 * s, 0.032 * s, Vector3(0.0, 0.375 * s, 0.0), _mat_brass_gold, 20)

	# 5. Polished Crown Sphere Head
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.108 * s
	hm.height = 0.216 * s
	head.mesh = hm
	head.position = Vector3(0.0, 0.48 * s, 0.0)
	head.material_override = mat
	pawn.add_child(head)

	# 6. Golden Finial Tip
	var tip := MeshInstance3D.new()
	var tm := SphereMesh.new()
	tm.radius = 0.036 * s
	tm.height = 0.072 * s
	tip.mesh = tm
	tip.position = Vector3(0.0, 0.60 * s, 0.0)
	tip.material_override = _mat_brass_gold
	pawn.add_child(tip)

	return pawn

# ============================================================================
# 3. GAMER-FRIENDLY FLOATING ACTION BAR (MOVE vs HORIZONTAL / VERTICAL WALL)
# ============================================================================

func _build_action_dock() -> void:
	dock_layer = CanvasLayer.new()
	dock_layer.name = "QuoridorDockLayer"
	dock_layer.layer = 6
	add_child(dock_layer)

	dock_panel = PanelContainer.new()
	dock_panel.name = "QuoridorActionDock"
	dock_panel.anchor_left = 0.5
	dock_panel.anchor_right = 0.5
	dock_panel.anchor_top = 1.0
	dock_panel.anchor_bottom = 1.0
	dock_panel.offset_left = -460.0
	dock_panel.offset_right = 460.0
	dock_panel.offset_top = -345.0
	dock_panel.offset_bottom = -255.0
	dock_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.05, 0.90)
	sb.border_color = Color(0.75, 0.56, 0.24, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	dock_panel.add_theme_stylebox_override("panel", sb)
	dock_layer.add_child(dock_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_panel.add_child(hbox)

	btn_mode_move = _make_dock_button("🚶 حرکت مهره")
	btn_mode_wall_h = _make_dock_button("➖ دیوار افقی")
	btn_mode_wall_v = _make_dock_button("｜ دیوار عمودی")
	btn_confirm_wall = _make_dock_button("✅ ثبت دیوار")

	hbox.add_child(btn_mode_move)
	hbox.add_child(btn_mode_wall_h)
	hbox.add_child(btn_mode_wall_v)
	hbox.add_child(btn_confirm_wall)

	btn_mode_move.pressed.connect(func():
		AudioManager.sfx_tap()
		_set_action_mode(ACTION_MOVE)
	)
	btn_mode_wall_h.pressed.connect(func():
		AudioManager.sfx_tap()
		_set_action_mode(ACTION_WALL_H)
	)
	btn_mode_wall_v.pressed.connect(func():
		AudioManager.sfx_tap()
		_set_action_mode(ACTION_WALL_V)
	)
	btn_confirm_wall.pressed.connect(func():
		_confirm_previewed_wall()
	)

	_refresh_dock_buttons()

func _make_dock_button(label_text: String) -> Button:
	var b := Button.new()
	b.text = label_text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 68)
	b.add_theme_font_override("font", _font_hekayat)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	b.focus_mode = Control.FOCUS_NONE
	KenneyUI.style_button(b, KenneyUI.COLOR_WOOD)
	ActionVFXManager.apply_button_juice(b, "tap_button")
	return b

func _set_action_mode(mode: int) -> void:
	if mode != ACTION_MOVE and _get_my_walls_left() <= 0:
		show_hint("دیواری برای شما باقی نمانده است؛ مهره خود را حرکت دهید.")
		AudioManager.play_sound("miss_turn")
		current_mode = ACTION_MOVE
	else:
		current_mode = mode
	if current_mode == ACTION_MOVE:
		preview_wall_rc = Vector2i(-1, -1)
		preview_wall_valid = false
	elif preview_wall_rc != Vector2i(-1, -1):
		var ori := "H" if current_mode == ACTION_WALL_H else "V"
		preview_wall_valid = can_place_wall(my_player_index, preview_wall_rc.x, preview_wall_rc.y, ori)
	_refresh_dock_buttons()
	_refresh_highlights_and_preview()

func _refresh_dock_buttons() -> void:
	if not is_instance_valid(btn_mode_move):
		return
	var my_walls := _get_my_walls_left()
	var can_wall := (my_walls > 0) and is_my_turn and not is_board_locked and winner_id == 0

	btn_mode_move.modulate = Color(1.18, 1.12, 0.88) if current_mode == ACTION_MOVE else Color(0.84, 0.84, 0.84)
	btn_mode_wall_h.modulate = Color(1.18, 1.12, 0.88) if current_mode == ACTION_WALL_H else Color(0.84, 0.84, 0.84)
	btn_mode_wall_v.modulate = Color(1.18, 1.12, 0.88) if current_mode == ACTION_WALL_V else Color(0.84, 0.84, 0.84)

	btn_mode_wall_h.disabled = (my_walls <= 0)
	btn_mode_wall_v.disabled = (my_walls <= 0)
	btn_mode_wall_h.text = "➖ افقی (%s)" % _fa_digits(my_walls)
	btn_mode_wall_v.text = "｜ عمودی (%s)" % _fa_digits(my_walls)

	var show_confirm := (current_mode != ACTION_MOVE) and can_wall and preview_wall_rc.x >= 0
	btn_confirm_wall.visible = (current_mode != ACTION_MOVE)
	btn_confirm_wall.disabled = not (show_confirm and preview_wall_valid)
	if not show_confirm:
		btn_confirm_wall.text = "👆 محل دیوار؟"
		btn_confirm_wall.modulate = Color(0.75, 0.75, 0.75)
	elif preview_wall_valid:
		btn_confirm_wall.text = "✅ ثبت دیوار"
		btn_confirm_wall.modulate = Color(0.88, 1.22, 0.88)
	else:
		btn_confirm_wall.text = "🚫 غیرمجاز"
		btn_confirm_wall.modulate = Color(1.15, 0.65, 0.65)

func _update_dock_visibility() -> void:
	if not is_instance_valid(dock_panel):
		return
	var should_show := GameManager.is_game_active and winner_id == 0
	if dock_panel.visible != should_show:
		dock_panel.visible = should_show

# ============================================================================
# 4. QUORIDOR RULES ENGINE (1:1 MIRROR OF BACKEND)
# ============================================================================

func _wall_key(wr: int, wc: int) -> String:
	return "%d,%d" % [wr, wc]

func _is_blocked(r1: int, c1: int, r2: int, c2: int, extra_h: Dictionary = {}, extra_v: Dictionary = {}) -> bool:
	if r2 < 0 or r2 >= BOARD_SIZE or c2 < 0 or c2 >= BOARD_SIZE:
		return true
	var dr := r2 - r1
	var dc := c2 - c1
	if abs(dr) + abs(dc) != 1:
		return true
	if dr == -1:
		var wr := r1 - 1
		return _has_h(wr, c1, extra_h) or _has_h(wr, c1 - 1, extra_h)
	if dr == 1:
		var wr := r1
		return _has_h(wr, c1, extra_h) or _has_h(wr, c1 - 1, extra_h)
	if dc == -1:
		var wc := c1 - 1
		return _has_v(r1, wc, extra_v) or _has_v(r1 - 1, wc, extra_v)
	if dc == 1:
		var wc := c1
		return _has_v(r1, wc, extra_v) or _has_v(r1 - 1, wc, extra_v)
	return true

func _has_h(wr: int, wc: int, extra_h: Dictionary) -> bool:
	var k := _wall_key(wr, wc)
	return _h_set.has(k) or extra_h.has(k)

func _has_v(wr: int, wc: int, extra_v: Dictionary) -> bool:
	var k := _wall_key(wr, wc)
	return _v_set.has(k) or extra_v.has(k)

func get_legal_pawn_moves(g_id: int) -> Array[Vector2i]:
	var p_rc: Array = pawns[g_id - 1]
	var opp_rc: Array = pawns[2 - g_id]
	var r: int = int(p_rc[0])
	var c: int = int(p_rc[1])
	var orow: int = int(opp_rc[0])
	var ocol: int = int(opp_rc[1])
	var legal: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for d: Vector2i in dirs:
		var nr: int = r + d.x
		var nc: int = c + d.y
		if _is_blocked(r, c, nr, nc):
			continue
		if nr == orow and nc == ocol:
			var jr: int = nr + d.x
			var jc: int = nc + d.y
			if not _is_blocked(nr, nc, jr, jc):
				legal.append(Vector2i(jr, jc))
			else:
				if d.x != 0:
					for sc: int in [-1, 1]:
						if not _is_blocked(nr, nc, nr, nc + sc):
							legal.append(Vector2i(nr, nc + sc))
				else:
					for sr: int in [-1, 1]:
						if not _is_blocked(nr, nc, nr + sr, nc):
							legal.append(Vector2i(nr + sr, nc))
		else:
			legal.append(Vector2i(nr, nc))
	return legal

func _has_path_to_goal(start_r: int, start_c: int, goal_row: int, extra_h: Dictionary, extra_v: Dictionary) -> bool:
	if start_r == goal_row:
		return true
	var visited: Dictionary = {_wall_key(start_r, start_c): true}
	var queue: Array[Vector2i] = [Vector2i(start_r, start_c)]
	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d: Vector2i in dirs:
			var nr: int = cur.x + d.x
			var nc: int = cur.y + d.y
			var vk: String = _wall_key(nr, nc)
			if visited.has(vk):
				continue
			if _is_blocked(cur.x, cur.y, nr, nc, extra_h, extra_v):
				continue
			if nr == goal_row:
				return true
			visited[vk] = true
			queue.append(Vector2i(nr, nc))
	return false

func _diagnose_wall_error(g_id: int, wr: int, wc: int, ori: String) -> String:
	if walls_left[g_id - 1] <= 0:
		return "دیواری برای شما باقی نمانده است."
	if wr < 0 or wr >= WALL_GRID_SIZE or wc < 0 or wc >= WALL_GRID_SIZE:
		return "محل دیوار خارج از محدوده مجاز صفحه است."
	var k := _wall_key(wr, wc)
	if _h_set.has(k) or _v_set.has(k):
		return "این محل قبلاً با دیوار دیگری اشغال یا قطع شده است."
	var extra_h: Dictionary = {}
	var extra_v: Dictionary = {}
	if ori == "H":
		if _h_set.has(_wall_key(wr, wc - 1)) or _h_set.has(_wall_key(wr, wc + 1)):
			return "دیوار افقی با دیوار هم‌ردیف مجاور تداخل دارد."
		extra_h[k] = true
	else:
		if _v_set.has(_wall_key(wr - 1, wc)) or _v_set.has(_wall_key(wr + 1, wc)):
			return "دیوار عمودی با دیوار هم‌ستون مجاور تداخل دارد."
		extra_v[k] = true

	var p1: Array = pawns[0]
	var p2: Array = pawns[1]
	if not _has_path_to_goal(int(p1[0]), int(p1[1]), 0, extra_h, extra_v):
		return "این دیوار تمام مسیرهای بازیکن اول را به خط پایان می‌بندد!"
	if not _has_path_to_goal(int(p2[0]), int(p2[1]), BOARD_SIZE - 1, extra_h, extra_v):
		return "این دیوار تمام مسیرهای بازیکن دوم را به خط پایان می‌بندد!"
	return ""

func can_place_wall(g_id: int, wr: int, wc: int, ori: String) -> bool:
	return _diagnose_wall_error(g_id, wr, wc, ori) == ""

func _get_my_walls_left() -> int:
	var idx := clampi(my_player_index - 1, 0, 1)
	return int(walls_left[idx])

# ============================================================================
# 5. INPUT HANDLING (CAMERA RAYCAST TO HORIZONTAL PLANE — ZERO COLLIDER RACES)
# ============================================================================

func _raycast_board_plane(screen_pos: Vector2) -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return null
	var target_y := BOARD_SURFACE_Y + TILE_HEIGHT
	var t := (target_y - origin.y) / dir.y
	if t <= 0.0:
		return null
	var world_hit := origin + dir * t
	return to_local(world_hit)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active or winner_id != 0:
		return

	if event is InputEventMouseMotion:
		var local_hit: Variant = _raycast_board_plane(event.position)
		if local_hit == null:
			hovered_cell_rc = Vector2i(-1, -1)
			return
		var hit_v: Vector3 = local_hit
		if current_mode == ACTION_MOVE:
			hovered_cell_rc = _local_pos_to_canonical_cell(hit_v)
			_refresh_highlights_and_preview()
		else:
			if preview_wall_rc.x < 0: # track hover smoothly only before user locks a tap target
				var w_rc := _local_pos_to_canonical_wall(hit_v)
				if w_rc.x >= 0:
					_update_wall_preview_only(w_rc.x, w_rc.y)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_hit: Variant = _raycast_board_plane(event.position)
		if local_hit == null:
			return
		var hit_v: Vector3 = local_hit
		if absf(hit_v.x) > 0.44 or absf(hit_v.z) > 0.44:
			return

		if is_board_locked:
			return
		if not is_my_turn:
			show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
			AudioManager.play_sound("miss_turn")
			return

		if current_mode == ACTION_MOVE:
			var rc := _local_pos_to_canonical_cell(hit_v)
			if rc.x >= 0:
				_attempt_pawn_move(rc.x, rc.y)
		else:
			var w_rc := _local_pos_to_canonical_wall(hit_v)
			if w_rc.x >= 0:
				_handle_wall_tap(w_rc.x, w_rc.y)

func _local_pos_to_canonical_cell(local_v: Vector3) -> Vector2i:
	var vc := int(round(local_v.x / CELL_STEP + 4.0))
	var vr := int(round(local_v.z / CELL_STEP + 4.0))
	if vr < 0 or vr >= BOARD_SIZE or vc < 0 or vc >= BOARD_SIZE:
		return Vector2i(-1, -1)
	var cx := (float(vc) - 4.0) * CELL_STEP
	var cz := (float(vr) - 4.0) * CELL_STEP
	if absf(local_v.x - cx) > CELL_STEP * 0.52 or absf(local_v.z - cz) > CELL_STEP * 0.52:
		return Vector2i(-1, -1)
	return _visual_to_canonical_rc(vr, vc)

func _local_pos_to_canonical_wall(local_v: Vector3) -> Vector2i:
	var vwc := clampi(int(round(local_v.x / CELL_STEP + 3.5)), 0, WALL_GRID_SIZE - 1)
	var vwr := clampi(int(round(local_v.z / CELL_STEP + 3.5)), 0, WALL_GRID_SIZE - 1)
	return _visual_to_canonical_wall(vwr, vwc)

func _attempt_pawn_move(r: int, c: int) -> void:
	var legal: Array[Vector2i] = get_legal_pawn_moves(my_player_index)
	var is_ok: bool = false
	for m: Vector2i in legal:
		if m.x == r and m.y == c:
			is_ok = true
			break
	if not is_ok:
		show_hint("تنها می‌توانید به خانه‌های سبز روشن‌شده حرکت کنید.")
		AudioManager.play_sound("miss_turn")
		return

	set_board_locked(true)
	is_my_turn = false
	_clear_legal_pads()
	NetworkManager.send_select_peace({
		"action": "move",
		"row": r,
		"col": c,
	})

func _update_wall_preview_only(wr: int, wc: int) -> void:
	var ori := "H" if current_mode == ACTION_WALL_H else "V"
	var valid := can_place_wall(my_player_index, wr, wc, ori)
	if not is_instance_valid(ghost_wall_node):
		return
	ghost_wall_node.visible = GameManager.is_game_active and is_my_turn and not is_board_locked and winner_id == 0
	ghost_wall_node.position = _wall_to_local_pos(wr, wc, 0.0)
	ghost_wall_node.rotation_degrees = Vector3(0.0, 0.0 if ori == "H" else 90.0, 0.0)
	ghost_wall_mesh.material_override = _mat_ghost_valid if valid else _mat_ghost_invalid

func _handle_wall_tap(wr: int, wc: int) -> void:
	var ori := "H" if current_mode == ACTION_WALL_H else "V"
	if preview_wall_rc.x == wr and preview_wall_rc.y == wc and preview_wall_valid:
		_confirm_previewed_wall()
		return

	preview_wall_rc = Vector2i(wr, wc)
	var err := _diagnose_wall_error(my_player_index, wr, wc, ori)
	preview_wall_valid = (err == "")
	_refresh_dock_buttons()
	_refresh_highlights_and_preview()

	if not preview_wall_valid:
		show_hint(err)
		AudioManager.play_sound("miss_turn")
	else:
		AudioManager.sfx_tap()
		show_hint("✅ جای دیوار مناسب است! برای ثبت مجدداً بزنید یا دکمه «ثبت دیوار» را فشار دهید.")

func _confirm_previewed_wall() -> void:
	if not GameManager.is_game_active or is_board_locked or winner_id != 0:
		return
	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		return
	if current_mode == ACTION_MOVE or preview_wall_rc.x < 0:
		return
	var ori := "H" if current_mode == ACTION_WALL_H else "V"
	var err := _diagnose_wall_error(my_player_index, preview_wall_rc.x, preview_wall_rc.y, ori)
	if err != "":
		show_hint(err)
		AudioManager.play_sound("miss_turn")
		return

	var wr := preview_wall_rc.x
	var wc := preview_wall_rc.y
	set_board_locked(true)
	is_my_turn = false
	preview_wall_rc = Vector2i(-1, -1)
	preview_wall_valid = false
	if is_instance_valid(ghost_wall_node):
		ghost_wall_node.visible = false
	_set_action_mode(ACTION_MOVE)

	NetworkManager.send_select_peace({
		"action": "wall",
		"row": wr,
		"col": wc,
		"orientation": ori,
	})

# ============================================================================
# 6. BOARD HOOKS & NETWORK SYNCHRONIZATION
# ============================================================================

func setup_board(game_data: Dictionary) -> void:
	_apply_server_snapshot(game_data, false)
	sync_turn_state()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data: Dictionary = payload.get("game_data", payload) if typeof(payload) == TYPE_DICTIONARY else {}
	if not g_data.is_empty():
		_apply_server_snapshot(g_data, false)
	sync_turn_state()

func on_turn_changed(turn: int, my_turn: bool) -> void:
	current_turn = turn
	is_my_turn = my_turn
	is_board_locked = (not my_turn) or (winner_id != 0) or (not GameManager.is_game_active)
	preview_wall_rc = Vector2i(-1, -1)
	preview_wall_valid = false
	if not my_turn:
		current_mode = ACTION_MOVE
	_refresh_dock_buttons()
	_refresh_highlights_and_preview()

func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var prev_p1: Array = pawns[0].duplicate()
	var prev_p2: Array = pawns[1].duplicate()
	var prev_h_count := h_walls.size()
	var prev_v_count := v_walls.size()

	_apply_server_snapshot(extra, true)

	var act := str(extra.get("action", "")).to_lower()
	var g_id := int(extra.get("gamer_id", user_id))
	if act == "move" and g_id in [1, 2]:
		var new_rc: Array = pawns[g_id - 1]
		var old_rc: Array = prev_p1 if g_id == 1 else prev_p2
		if old_rc != new_rc:
			_animate_pawn_hop(g_id, old_rc, new_rc)
		if is_instance_valid(last_move_pad):
			last_move_pad.position = _cell_to_local_pos(int(new_rc[0]), int(new_rc[1]), 0.002)
			last_move_pad.visible = true
		AudioManager.play_sound("add_peace")
	elif act == "wall":
		AudioManager.play_sound("tap_button")
		if (h_walls.size() > prev_h_count or v_walls.size() > prev_v_count):
			var wr := int(extra.get("row", -1))
			var wc := int(extra.get("col", -1))
			if wr >= 0 and wc >= 0:
				var w_local := _wall_to_local_pos(wr, wc, 0.010)
				ActionVFXManager.spawn_piece_impact_vfx(fx_root, w_local, g_id)
				if not placed_wall_nodes.is_empty():
					var last_w: Node3D = placed_wall_nodes[placed_wall_nodes.size() - 1]
					if is_instance_valid(last_w):
						var rest_pos := last_w.position
						last_w.position = rest_pos + Vector3(0.0, 0.14, 0.0)
						var wtw := create_tween()
						wtw.tween_property(last_w, "position", rest_pos, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	if winner_id != 0 and not _win_vfx_shown:
		_win_vfx_shown = true
		_trigger_victory_vfx(winner_id)

	_refresh_dock_buttons()
	_refresh_highlights_and_preview()

func on_round_finished(payload: Variant) -> void:
	is_board_locked = true
	is_my_turn = false
	var w := 0
	if typeof(payload) == TYPE_DICTIONARY:
		w = int(payload.get("Winner", payload.get("winner", 0)))
	elif typeof(payload) in [TYPE_INT, TYPE_FLOAT]:
		w = int(payload)
	if w in [1, 2]:
		winner_id = w
		if not _win_vfx_shown:
			_win_vfx_shown = true
			_trigger_victory_vfx(w)
	_clear_legal_pads()
	if is_instance_valid(ghost_wall_node):
		ghost_wall_node.visible = false
	_refresh_dock_buttons()

func reset_board() -> void:
	_reset_internal_state()
	_sync_all_visuals()

func cleanup_board() -> void:
	if is_instance_valid(dock_layer):
		dock_layer.queue_free()
		dock_layer = null

# ============================================================================
# 7. STATE SYNC & VISUAL UPDATES
# ============================================================================

func _reset_internal_state() -> void:
	pawns = [[8, 4], [0, 4]]
	walls_left = [INITIAL_WALLS, INITIAL_WALLS]
	h_walls = []
	v_walls = []
	_h_set.clear()
	_v_set.clear()
	winner_id = 0
	current_mode = ACTION_MOVE
	preview_wall_rc = Vector2i(-1, -1)
	preview_wall_valid = false
	hovered_cell_rc = Vector2i(-1, -1)
	_win_vfx_shown = false

func _apply_server_snapshot(data: Dictionary, from_move_event: bool) -> void:
	if data.is_empty():
		return

	if data.has("pawns"):
		var raw_p = data["pawns"]
		if typeof(raw_p) == TYPE_ARRAY and raw_p.size() >= 2:
			if typeof(raw_p[0]) == TYPE_ARRAY and raw_p[0].size() >= 2:
				pawns[0] = [int(raw_p[0][0]), int(raw_p[0][1])]
			if typeof(raw_p[1]) == TYPE_ARRAY and raw_p[1].size() >= 2:
				pawns[1] = [int(raw_p[1][0]), int(raw_p[1][1])]

	if data.has("walls_left"):
		var raw_w = data["walls_left"]
		if typeof(raw_w) == TYPE_ARRAY and raw_w.size() >= 2:
			walls_left = [int(raw_w[0]), int(raw_w[1])]
		elif typeof(raw_w) == TYPE_DICTIONARY:
			walls_left = [
				int(raw_w.get("1", raw_w.get(1, walls_left[0]))),
				int(raw_w.get("2", raw_w.get(2, walls_left[1]))),
			]

	if data.has("h_walls") and typeof(data["h_walls"]) == TYPE_ARRAY:
		h_walls = []
		_h_set.clear()
		for w in data["h_walls"]:
			if typeof(w) == TYPE_ARRAY and w.size() >= 2:
				var wr := int(w[0])
				var wc := int(w[1])
				h_walls.append([wr, wc])
				_h_set[_wall_key(wr, wc)] = true

	if data.has("v_walls") and typeof(data["v_walls"]) == TYPE_ARRAY:
		v_walls = []
		_v_set.clear()
		for w in data["v_walls"]:
			if typeof(w) == TYPE_ARRAY and w.size() >= 2:
				var wr := int(w[0])
				var wc := int(w[1])
				v_walls.append([wr, wc])
				_v_set[_wall_key(wr, wc)] = true

	if data.has("current_turn"):
		current_turn = int(data["current_turn"])
	if data.has("winner") and int(data["winner"]) > 0:
		winner_id = int(data["winner"])

	_sync_all_visuals(from_move_event)

func _sync_all_visuals(skip_pawn_snap: bool = false) -> void:
	my_player_index = GameManager.my_player_index

	# Orient Goal Strips & 3D Labels clearly to match player perspective
	if is_instance_valid(goal_strip_top) and is_instance_valid(goal_strip_bottom):
		goal_strip_top.material_override = _mat_goal_emerald
		goal_strip_bottom.material_override = _mat_goal_crimson if my_player_index == 1 else _mat_goal_sapphire
	if is_instance_valid(lbl_top_goal_3d):
		lbl_top_goal_3d.text = "🏁 خط پایان شما"
	if is_instance_valid(lbl_bottom_start_3d):
		lbl_bottom_start_3d.text = "▲ جهت حرکت شما ▲"

	if not skip_pawn_snap:
		for p_id: int in [1, 2]:
			var node: Node3D = pawn_nodes[p_id - 1]
			if is_instance_valid(node):
				var rc: Array = pawns[p_id - 1]
				node.position = _cell_to_local_pos(int(rc[0]), int(rc[1]), 0.0)

	_rebuild_placed_walls_visual()
	_sync_wall_racks_visual()
	_sync_top_header_walls()
	_refresh_highlights_and_preview()
	_refresh_dock_buttons()

func _rebuild_placed_walls_visual() -> void:
	for n: Node3D in placed_wall_nodes:
		if is_instance_valid(n):
			n.queue_free()
	placed_wall_nodes.clear()

	for w in h_walls:
		var wr: int = int(w[0])
		var wc: int = int(w[1])
		var f: Node3D = _create_fence_3d(_mat_wall_default)
		f.position = _wall_to_local_pos(wr, wc, 0.002)
		f.rotation_degrees = Vector3.ZERO
		walls_root.add_child(f)
		placed_wall_nodes.append(f)

	for w in v_walls:
		var wr: int = int(w[0])
		var wc: int = int(w[1])
		var f: Node3D = _create_fence_3d(_mat_wall_default)
		f.position = _wall_to_local_pos(wr, wc, 0.002)
		f.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		walls_root.add_child(f)
		placed_wall_nodes.append(f)

func _sync_wall_racks_visual() -> void:
	# Always place my rack on Left (or Red on Left, Blue on Right matching card positions)
	for side_idx in range(2):
		var rem := clampi(int(walls_left[side_idx]), 0, INITIAL_WALLS)
		var arr: Array = wall_rack_nodes[side_idx]
		for i in range(arr.size()):
			if is_instance_valid(arr[i]):
				arr[i].visible = (i < rem)

func _sync_top_header_walls() -> void:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		var main_node = get_tree().current_scene
		if is_instance_valid(main_node):
			hud = main_node.get_node_or_null("CanvasLayer/BaseGameHUD")
	if not is_instance_valid(hud):
		return
	var hdr: Variant = hud.get("current_top_header")
	if is_instance_valid(hdr) and hdr.has_method("update_walls"):
		hdr.update_walls(int(walls_left[0]), int(walls_left[1]))

func _animate_pawn_hop(g_id: int, from_rc: Array, to_rc: Array) -> void:
	var node: Node3D = pawn_nodes[g_id - 1]
	if not is_instance_valid(node):
		return
	var p_start := _cell_to_local_pos(int(from_rc[0]), int(from_rc[1]), 0.0)
	var p_end := _cell_to_local_pos(int(to_rc[0]), int(to_rc[1]), 0.0)
	node.position = p_start

	var mid := (p_start + p_end) * 0.5
	mid.y += 0.11

	var tw := create_tween()
	tw.tween_property(node, "position", mid, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", p_end, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(node) and is_instance_valid(fx_root):
			ActionVFXManager.spawn_piece_impact_vfx(fx_root, p_end, g_id)
	)

func _clear_legal_pads() -> void:
	for p in legal_move_pads:
		if is_instance_valid(p):
			p.visible = false

func _refresh_highlights_and_preview() -> void:
	_clear_legal_pads()
	if is_instance_valid(ghost_wall_node):
		ghost_wall_node.visible = false

	if not GameManager.is_game_active or winner_id != 0:
		return

	if current_mode == ACTION_MOVE and is_my_turn and not is_board_locked:
		var legal: Array[Vector2i] = get_legal_pawn_moves(my_player_index)
		var my_rc: Array = pawns[my_player_index - 1]
		var my_r: int = int(my_rc[0])
		var my_c: int = int(my_rc[1])
		for m: Vector2i in legal:
			var vr_vc: Vector2i = _canonical_to_visual_rc(m.x, m.y)
			var pad_idx: int = vr_vc.x * BOARD_SIZE + vr_vc.y
			if pad_idx >= 0 and pad_idx < legal_move_pads.size():
				var pad: MeshInstance3D = legal_move_pads[pad_idx]
				var dist: int = absi(m.x - my_r) + absi(m.y - my_c)
				var is_hov: bool = (hovered_cell_rc.x == m.x and hovered_cell_rc.y == m.y)
				if is_hov:
					pad.material_override = _mat_hover_pad
				elif dist >= 2:
					pad.material_override = _mat_legal_jump_pad
				else:
					pad.material_override = _mat_legal_pad
				pad.visible = true

	elif current_mode != ACTION_MOVE and is_my_turn and not is_board_locked and preview_wall_rc.x >= 0:
		var ori := "H" if current_mode == ACTION_WALL_H else "V"
		preview_wall_valid = can_place_wall(my_player_index, preview_wall_rc.x, preview_wall_rc.y, ori)
		if is_instance_valid(ghost_wall_node):
			ghost_wall_node.visible = true
			ghost_wall_node.position = _wall_to_local_pos(preview_wall_rc.x, preview_wall_rc.y, 0.0)
			ghost_wall_node.rotation_degrees = Vector3(0.0, 0.0 if ori == "H" else 90.0, 0.0)
			ghost_wall_mesh.material_override = _mat_ghost_valid if preview_wall_valid else _mat_ghost_invalid

func _trigger_victory_vfx(w_id: int) -> void:
	if w_id not in [1, 2]:
		return
	var node: Node3D = pawn_nodes[w_id - 1]
	if is_instance_valid(node):
		ActionVFXManager.play_win_celebration_vfx(fx_root, node.position, w_id)
		var beacon := _add_cyl_mesh(fx_root, 0.055, 0.075, 0.42, node.position + Vector3(0.0, 0.22, 0.0), _mat_goal_emerald, 18)
		beacon.transparency = 0.45
		var tw := create_tween().set_loops(4)
		tw.tween_property(beacon, "scale", Vector3(1.3, 1.15, 1.3), 0.25)
		tw.tween_property(beacon, "scale", Vector3(1.0, 1.0, 1.0), 0.25)
