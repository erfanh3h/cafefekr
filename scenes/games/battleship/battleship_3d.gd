class_name BattleShip3D
extends "res://scripts/games/base_game_board.gd"

# ==============================================================================
# BattleShip 3D ("نبرد کشتی") for Cafe Fekr
# 2-Phase Naval Strategy Game:
# - Phase 1 (Setup - 60s): Place 4 Warships (Lengths 2, 3, 4, 5) on an 8x8 Ocean Grid.
#   Supports Drag-and-Drop, Click-to-Place, In-Place Rotation, and Auto-Randomize.
# - Phase 2 (Combat - 12s/turn, Bonus Turn on Hit!):
#   Switchable 3D Views (like FekrBekr):
#     * ViewMode.MY_BOARD (0): Attack Radar Grid (Opponent's waters - click to fire!)
#     * ViewMode.OPP_BOARD (1): My Fleet Defense Grid (Your 3D warships & incoming shots)
#     * ViewMode.DUAL (2): Side-by-side simultaneous 3D boards!
#   Includes 3D artillery shell flight, water splash VFX, ship hit explosions, and
#   dramatic Full-Ship-Down chain explosions + sinking 3D warship reveal!
# ==============================================================================

const GRID_SIZE: int = 8
const TOTAL_CELLS: int = 64
const CELL_PITCH: float = 0.086
const SHIP_LENGTHS: Array[int] = [2, 3, 4, 5]

const SHIP_NAMES_FA: Dictionary = {
	2: "ناوچه گشتی (۲)",
	3: "زیردریایی (۳)",
	4: "نبردناو سنگین (۴)",
	5: "ناو هواپیمابر (۵)"
}

enum ViewMode {
	MY_BOARD = 0,   # Attack Radar Board (firing at opponent)
	OPP_BOARD = 1,  # My Fleet Defense Board (viewing own ships)
	DUAL = 2        # Both boards side-by-side
}

var view_mode: int = ViewMode.MY_BOARD
var is_play_phase: bool = false
var is_board_saved: bool = false
var is_waiting_server: bool = false

var p1_score: int = 0
var p2_score: int = 0

# Phase 1 Ship Placement State
var fleet_state: Dictionary = {}
var selected_ship_len: int = 5
var is_dragging_ship: bool = false
var dragged_ship_len: int = 0
var hover_grid_index: int = -1
var _last_piece_interaction_time: float = -10.0

# Phase 2 Board Cell States (64 entries each: { "is_selected": bool, "number": int })
var attack_cells_state: Array[Dictionary] = []
var defense_cells_state: Array[Dictionary] = []
var sunk_enemy_ships: Dictionary = {2: false, 3: false, 4: false, 5: false}
var sunk_my_ships: Dictionary = {2: false, 3: false, 4: false, 5: false}

# Scene Hierarchy Nodes
var board_root: Node3D
var phase1_root: Node3D
var phase1_grid_root: Node3D
var drydock_root: Node3D
var ghost_preview_root: Node3D
var phase1_cell_meshes: Array[MeshInstance3D] = []
var phase1_ship_nodes: Dictionary = {}
var drydock_slot_highlights: Dictionary = {}
var lbl_phase1_hint: Label3D

var phase2_root: Node3D
var attack_board_root: Node3D
var my_fleet_board_root: Node3D
var view_tabs_root: Node3D
var tab_meshes: Dictionary = {}

var attack_cell_meshes: Array[MeshInstance3D] = []
var attack_markers_root: Node3D
var attack_sunk_ships_root: Node3D
var attack_hover_reticle: Node3D
var enemy_status_badges: Dictionary = {}

var defense_cell_meshes: Array[MeshInstance3D] = []
var defense_ships_root: Node3D
var defense_markers_root: Node3D
var my_status_badges: Dictionary = {}

# Shared Materials
var _mat_mahogany: StandardMaterial3D
var _mat_brass: StandardMaterial3D
var _mat_ocean_cell: StandardMaterial3D
var _mat_ocean_alt: StandardMaterial3D
var _mat_radar_cell: StandardMaterial3D
var _mat_radar_alt: StandardMaterial3D
var _mat_ghost_valid: StandardMaterial3D
var _mat_ghost_invalid: StandardMaterial3D
var _mat_ship_hull: StandardMaterial3D
var _mat_ship_deck: StandardMaterial3D
var _mat_ship_dark: StandardMaterial3D
var _mat_ship_sunk_hull: StandardMaterial3D
var _mat_ship_sunk_fire: StandardMaterial3D

func _init() -> void:
	game_type = GameTypes.BATTLESHIP

func is_interacting_with_piece() -> bool:
	if is_dragging_ship:
		return true
	var now = Time.get_ticks_msec() / 1000.0
	return (now - _last_piece_interaction_time) < 0.28

func _mark_piece_interaction() -> void:
	_last_piece_interaction_time = Time.get_ticks_msec() / 1000.0

func _get_hud() -> Control:
	var hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if hud and is_instance_valid(hud):
		return hud
	return null

func _ready() -> void:
	game_type = GameTypes.BATTLESHIP
	_init_materials()
	_init_data_structures()
	_build_scene_hierarchy()
	_apply_default_initial_fleet()
	_update_phase_visibility()
	super._ready()

func _fa_num(n: int) -> String:
	var s = str(n)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out = ""
	for ch in s:
		var code = ch.unicode_at(0) - 48
		if code >= 0 and code <= 9:
			out += fa[code]
		else:
			out += ch
	return out

func _init_materials() -> void:
	_mat_mahogany = StandardMaterial3D.new()
	_mat_mahogany.albedo_color = Color(0.16, 0.09, 0.06)
	_mat_mahogany.roughness = 0.35
	_mat_mahogany.metallic = 0.15

	_mat_brass = StandardMaterial3D.new()
	_mat_brass.albedo_color = Color(0.85, 0.68, 0.28)
	_mat_brass.metallic = 0.85
	_mat_brass.roughness = 0.22

	_mat_ocean_cell = StandardMaterial3D.new()
	_mat_ocean_cell.albedo_color = Color(0.06, 0.24, 0.38, 0.92)
	_mat_ocean_cell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ocean_cell.roughness = 0.18
	_mat_ocean_cell.metallic = 0.25

	_mat_ocean_alt = StandardMaterial3D.new()
	_mat_ocean_alt.albedo_color = Color(0.08, 0.29, 0.44, 0.92)
	_mat_ocean_alt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ocean_alt.roughness = 0.18
	_mat_ocean_alt.metallic = 0.25

	_mat_radar_cell = StandardMaterial3D.new()
	_mat_radar_cell.albedo_color = Color(0.04, 0.18, 0.26, 0.94)
	_mat_radar_cell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_radar_cell.roughness = 0.20
	_mat_radar_cell.metallic = 0.30

	_mat_radar_alt = StandardMaterial3D.new()
	_mat_radar_alt.albedo_color = Color(0.06, 0.22, 0.31, 0.94)
	_mat_radar_alt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_radar_alt.roughness = 0.20
	_mat_radar_alt.metallic = 0.30

	_mat_ghost_valid = StandardMaterial3D.new()
	_mat_ghost_valid.albedo_color = Color(0.18, 0.95, 0.48, 0.55)
	_mat_ghost_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost_valid.emission_enabled = true
	_mat_ghost_valid.emission = Color(0.15, 0.85, 0.42)
	_mat_ghost_valid.emission_energy_multiplier = 0.9

	_mat_ghost_invalid = StandardMaterial3D.new()
	_mat_ghost_invalid.albedo_color = Color(0.98, 0.22, 0.25, 0.58)
	_mat_ghost_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ghost_invalid.emission_enabled = true
	_mat_ghost_invalid.emission = Color(0.95, 0.18, 0.20)
	_mat_ghost_invalid.emission_energy_multiplier = 1.1

	_mat_ship_hull = StandardMaterial3D.new()
	_mat_ship_hull.albedo_color = Color(0.36, 0.43, 0.50)
	_mat_ship_hull.metallic = 0.62
	_mat_ship_hull.roughness = 0.32

	_mat_ship_deck = StandardMaterial3D.new()
	_mat_ship_deck.albedo_color = Color(0.24, 0.29, 0.35)
	_mat_ship_deck.metallic = 0.48
	_mat_ship_deck.roughness = 0.42

	_mat_ship_dark = StandardMaterial3D.new()
	_mat_ship_dark.albedo_color = Color(0.14, 0.17, 0.21)
	_mat_ship_dark.metallic = 0.70
	_mat_ship_dark.roughness = 0.28

	_mat_ship_sunk_hull = StandardMaterial3D.new()
	_mat_ship_sunk_hull.albedo_color = Color(0.16, 0.08, 0.07)
	_mat_ship_sunk_hull.metallic = 0.45
	_mat_ship_sunk_hull.roughness = 0.65
	_mat_ship_sunk_hull.emission_enabled = true
	_mat_ship_sunk_hull.emission = Color(0.55, 0.12, 0.04)
	_mat_ship_sunk_hull.emission_energy_multiplier = 0.45

	_mat_ship_sunk_fire = StandardMaterial3D.new()
	_mat_ship_sunk_fire.albedo_color = Color(1.0, 0.38, 0.08)
	_mat_ship_sunk_fire.emission_enabled = true
	_mat_ship_sunk_fire.emission = Color(1.0, 0.32, 0.05)
	_mat_ship_sunk_fire.emission_energy_multiplier = 2.0

func _init_data_structures() -> void:
	fleet_state.clear()
	for s_len in SHIP_LENGTHS:
		fleet_state[s_len] = {
			"length": s_len,
			"cells": [],
			"is_horizontal": false,
			"placed": false
		}
	attack_cells_state.clear()
	defense_cells_state.clear()
	for i in range(TOTAL_CELLS):
		attack_cells_state.append({"is_selected": false, "number": 0})
		defense_cells_state.append({"is_selected": false, "number": 0})
	sunk_enemy_ships = {2: false, 3: false, 4: false, 5: false}
	sunk_my_ships = {2: false, 3: false, 4: false, 5: false}

func _cell_index_to_local_pos(idx: int) -> Vector3:
	var r: int = idx / GRID_SIZE
	var c: int = idx % GRID_SIZE
	var x: float = (float(c) - 3.5) * CELL_PITCH
	var z: float = (float(r) - 3.5) * CELL_PITCH
	return Vector3(x, 0.022, z)

func _build_scene_hierarchy() -> void:
	board_root = Node3D.new()
	board_root.name = "BattleShipBoardRoot"
	add_child(board_root)

	# Phase 1: Fleet Deployment Setup Root
	phase1_root = Node3D.new()
	phase1_root.name = "Phase1SetupRoot"
	board_root.add_child(phase1_root)
	_build_phase1_setup_ui()

	# Phase 2: Naval Combat Root (Dual Switchable Boards)
	phase2_root = Node3D.new()
	phase2_root.name = "Phase2CombatRoot"
	board_root.add_child(phase2_root)
	_build_phase2_combat_ui()

func _build_naval_grid_frame(parent_node: Node3D, title_text: String, title_color: Color, is_radar: bool, cell_meta_type: String, out_cell_meshes: Array[MeshInstance3D]) -> Node3D:
	var container = Node3D.new()
	parent_node.add_child(container)

	var board_span: float = GRID_SIZE * CELL_PITCH
	var frame_span: float = board_span + 0.13

	# Outer Mahogany Frame
	var base_box = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(frame_span, 0.032, frame_span + 0.08)
	base_box.mesh = b_mesh
	base_box.position = Vector3(0, 0.004, -0.01)
	base_box.material_override = _mat_mahogany
	container.add_child(base_box)

	# Brass Trim Border
	var brass_rim = MeshInstance3D.new()
	var r_mesh = BoxMesh.new()
	r_mesh.size = Vector3(board_span + 0.03, 0.036, board_span + 0.03)
	brass_rim.mesh = r_mesh
	brass_rim.position = Vector3(0, 0.006, 0.0)
	brass_rim.material_override = _mat_brass
	container.add_child(brass_rim)

	# Deep Water Basin Floor
	var basin = MeshInstance3D.new()
	var basin_mesh = BoxMesh.new()
	basin_mesh.size = Vector3(board_span + 0.01, 0.038, board_span + 0.01)
	basin.mesh = basin_mesh
	basin.position = Vector3(0, 0.007, 0.0)
	var mat_basin = StandardMaterial3D.new()
	mat_basin.albedo_color = Color(0.02, 0.09, 0.15) if is_radar else Color(0.03, 0.12, 0.22)
	mat_basin.roughness = 0.25
	basin.material_override = mat_basin
	container.add_child(basin)

	# Top Title Plaque
	var lbl_title = Label3D.new()
	lbl_title.text = title_text
	lbl_title.font_size = 30
	lbl_title.outline_size = 8
	lbl_title.modulate = title_color
	lbl_title.outline_modulate = Color(0.04, 0.04, 0.06, 0.95)
	lbl_title.position = Vector3(0, 0.032, -board_span * 0.5 - 0.055)
	lbl_title.rotation.x = -PI * 0.5
	container.add_child(lbl_title)

	# Column Coordinate Labels (A..H) and Row Coordinate Labels (۱..۸)
	var cols_text = ["A", "B", "C", "D", "E", "F", "G", "H"]
	for i in range(GRID_SIZE):
		var lbl_c = Label3D.new()
		lbl_c.text = cols_text[i]
		lbl_c.font_size = 20
		lbl_c.outline_size = 5
		lbl_c.modulate = Color(0.92, 0.80, 0.45)
		lbl_c.position = Vector3((float(i) - 3.5) * CELL_PITCH, 0.028, -board_span * 0.5 - 0.022)
		lbl_c.rotation.x = -PI * 0.5
		container.add_child(lbl_c)

		var lbl_r = Label3D.new()
		lbl_r.text = _fa_num(i + 1)
		lbl_r.font_size = 20
		lbl_r.outline_size = 5
		lbl_r.modulate = Color(0.92, 0.80, 0.45)
		lbl_r.position = Vector3(-board_span * 0.5 - 0.026, 0.028, (float(i) - 3.5) * CELL_PITCH)
		lbl_r.rotation.x = -PI * 0.5
		container.add_child(lbl_r)

	# 64 Interactive Grid Cells
	out_cell_meshes.clear()
	for idx in range(TOTAL_CELLS):
		var r: int = idx / GRID_SIZE
		var c: int = idx % GRID_SIZE
		var c_pos = _cell_index_to_local_pos(idx)

		var cell_mesh = MeshInstance3D.new()
		var cm = BoxMesh.new()
		cm.size = Vector3(CELL_PITCH - 0.005, 0.008, CELL_PITCH - 0.005)
		cell_mesh.mesh = cm
		cell_mesh.position = c_pos
		var is_checker: bool = ((r + c) % 2 == 0)
		if is_radar:
			cell_mesh.material_override = (_mat_radar_cell if is_checker else _mat_radar_alt).duplicate()
		else:
			cell_mesh.material_override = (_mat_ocean_cell if is_checker else _mat_ocean_alt).duplicate()
		container.add_child(cell_mesh)
		out_cell_meshes.append(cell_mesh)

		var sb = StaticBody3D.new()
		sb.position = c_pos
		sb.set_meta("bs_type", cell_meta_type)
		sb.set_meta("cell_index", idx)
		var col_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(CELL_PITCH, 0.035, CELL_PITCH)
		col_shape.shape = box_shape
		sb.add_child(col_shape)
		container.add_child(sb)

	# 4 Brass Corner Bollards
	var corner_off: float = frame_span * 0.5 - 0.022
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.014
			pm.bottom_radius = 0.018
			pm.height = 0.045
			post.mesh = pm
			post.position = Vector3(sx * corner_off, 0.022, sz * corner_off - 0.01)
			post.material_override = _mat_brass
			container.add_child(post)

	return container

func _build_phase1_setup_ui() -> void:
	# Left/Center: 8x8 Fleet Placement Grid
	phase1_grid_root = _build_naval_grid_frame(
		phase1_root,
		"⚓ میدان استقرار ناوگان شما (۸×۸)",
		Color(1.0, 0.88, 0.42),
		false,
		"p1_grid_cell",
		phase1_cell_meshes
	)
	phase1_grid_root.position = Vector3(-0.19, 0.0, 0.02)

	# Ghost Preview Container inside Phase 1 Grid
	ghost_preview_root = Node3D.new()
	ghost_preview_root.name = "GhostPreviewRoot"
	phase1_grid_root.add_child(ghost_preview_root)

	# Right: Drydock Shipyard Console + Tactical Controls
	drydock_root = Node3D.new()
	drydock_root.name = "DrydockRoot"
	drydock_root.position = Vector3(0.41, 0.0, 0.02)
	phase1_root.add_child(drydock_root)

	var dock_panel = MeshInstance3D.new()
	var dm = BoxMesh.new()
	dm.size = Vector3(0.36, 0.030, 0.82)
	dock_panel.mesh = dm
	dock_panel.position = Vector3(0, 0.004, -0.01)
	dock_panel.material_override = _mat_mahogany
	drydock_root.add_child(dock_panel)

	var dock_rim = MeshInstance3D.new()
	var drm = BoxMesh.new()
	drm.size = Vector3(0.33, 0.034, 0.79)
	dock_rim.mesh = drm
	dock_rim.position = Vector3(0, 0.006, -0.01)
	dock_rim.material_override = _mat_brass
	drydock_root.add_child(dock_rim)

	var dock_inner = MeshInstance3D.new()
	var dim = BoxMesh.new()
	dim.size = Vector3(0.31, 0.036, 0.77)
	dock_inner.mesh = dim
	dock_inner.position = Vector3(0, 0.007, -0.01)
	var mat_dock_in = StandardMaterial3D.new()
	mat_dock_in.albedo_color = Color(0.08, 0.13, 0.19)
	mat_dock_in.roughness = 0.35
	dock_inner.material_override = mat_dock_in
	drydock_root.add_child(dock_inner)

	var lbl_dock = Label3D.new()
	lbl_dock.text = "🚢 اسکله ناوگان"
	lbl_dock.font_size = 26
	lbl_dock.outline_size = 7
	lbl_dock.modulate = Color(0.98, 0.86, 0.42)
	lbl_dock.position = Vector3(0, 0.032, -0.34)
	lbl_dock.rotation.x = -PI * 0.5
	drydock_root.add_child(lbl_dock)

	lbl_phase1_hint = Label3D.new()
	lbl_phase1_hint.text = "کشتی را بکشید یا لمس کنید"
	lbl_phase1_hint.font_size = 18
	lbl_phase1_hint.outline_size = 5
	lbl_phase1_hint.modulate = Color(0.80, 0.92, 1.0)
	lbl_phase1_hint.position = Vector3(0, 0.030, -0.285)
	lbl_phase1_hint.rotation.x = -PI * 0.5
	drydock_root.add_child(lbl_phase1_hint)

	# 4 Drydock Ship Selector Berths (for lengths 5, 4, 3, 2)
	var berth_z = [-0.19, -0.07, 0.05, 0.17]
	var berth_lengths = [5, 4, 3, 2]
	for i in range(4):
		var s_len: int = berth_lengths[i]
		var bz: float = berth_z[i]

		var slot_box = MeshInstance3D.new()
		var sbm = BoxMesh.new()
		sbm.size = Vector3(0.28, 0.008, 0.095)
		slot_box.mesh = sbm
		slot_box.position = Vector3(0, 0.027, bz)
		var slot_mat = StandardMaterial3D.new()
		slot_mat.albedo_color = Color(0.14, 0.24, 0.34)
		slot_mat.roughness = 0.3
		slot_box.material_override = slot_mat
		drydock_root.add_child(slot_box)
		drydock_slot_highlights[s_len] = slot_box

		# Miniature 3D Warship preview inside the berth
		var mini_ship = _create_warship_3d_model(s_len, false, false)
		mini_ship.rotation.y = PI * 0.5
		var preview_scale: float = clampf(0.19 / (float(s_len) * CELL_PITCH), 0.38, 0.62)
		mini_ship.scale = Vector3(preview_scale, preview_scale, preview_scale)
		mini_ship.position = Vector3(-0.035, 0.032, bz)
		drydock_root.add_child(mini_ship)

		var lbl_s = Label3D.new()
		lbl_s.text = _fa_num(s_len)
		lbl_s.font_size = 24
		lbl_s.outline_size = 6
		lbl_s.modulate = Color(1.0, 0.90, 0.45)
		lbl_s.position = Vector3(0.105, 0.034, bz)
		lbl_s.rotation.x = -PI * 0.5
		drydock_root.add_child(lbl_s)

		var sb = StaticBody3D.new()
		sb.position = Vector3(0, 0.032, bz)
		sb.set_meta("bs_type", "drydock_ship")
		sb.set_meta("ship_len", s_len)
		var cs = CollisionShape3D.new()
		var bshape = BoxShape3D.new()
		bshape.size = Vector3(0.28, 0.04, 0.095)
		cs.shape = bshape
		sb.add_child(cs)
		drydock_root.add_child(sb)

	# 2 Tactical 3D Buttons on Drydock Console: Rotate ("🔄 چرخش") & Randomize ("🎲 تصادفی")
	_create_drydock_3d_button(
		Vector3(0, 0.032, 0.275),
		Vector3(0.28, 0.016, 0.068),
		"🔄 چرخش کشتی انتخابی",
		Color(0.18, 0.52, 0.86),
		"btn_rotate_ship"
	)
	_create_drydock_3d_button(
		Vector3(0, 0.032, 0.352),
		Vector3(0.28, 0.016, 0.068),
		"🎲 چیدمان تصادفی",
		Color(0.16, 0.66, 0.42),
		"btn_random_fleet"
	)

func _create_drydock_3d_button(pos: Vector3, sz: Vector3, text_str: String, bg_col: Color, meta_type: String) -> void:
	var btn_mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	btn_mesh.mesh = bm
	btn_mesh.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = bg_col
	mat.roughness = 0.28
	mat.metallic = 0.25
	btn_mesh.material_override = mat
	drydock_root.add_child(btn_mesh)

	var lbl = Label3D.new()
	lbl.text = text_str
	lbl.font_size = 19
	lbl.outline_size = 6
	lbl.modulate = Color.WHITE
	lbl.position = pos + Vector3(0, 0.012, 0)
	lbl.rotation.x = -PI * 0.5
	drydock_root.add_child(lbl)

	var sb = StaticBody3D.new()
	sb.position = pos
	sb.set_meta("bs_type", meta_type)
	var cs = CollisionShape3D.new()
	var bshape = BoxShape3D.new()
	bshape.size = sz + Vector3(0.01, 0.03, 0.01)
	cs.shape = bshape
	sb.add_child(cs)
	drydock_root.add_child(sb)

func _build_phase2_combat_ui() -> void:
	# 1. Top 3D View Switcher Tabs (in addition to HUD buttons!)
	view_tabs_root = Node3D.new()
	view_tabs_root.name = "ViewTabsRoot"
	view_tabs_root.position = Vector3(0, 0.015, -0.455)
	phase2_root.add_child(view_tabs_root)

	var tab_defs = [
		{"mode": ViewMode.MY_BOARD, "text": "🎯 میدان حمله", "x": -0.27},
		{"mode": ViewMode.OPP_BOARD, "text": "🛡️ ناوگان من", "x": 0.0},
		{"mode": ViewMode.DUAL, "text": "👥 نمایش همزمان", "x": 0.27}
	]
	for td in tab_defs:
		var t_mesh = MeshInstance3D.new()
		var tm = BoxMesh.new()
		tm.size = Vector3(0.24, 0.016, 0.056)
		t_mesh.mesh = tm
		t_mesh.position = Vector3(td["x"], 0.01, 0)
		var t_mat = StandardMaterial3D.new()
		t_mat.albedo_color = Color(0.18, 0.26, 0.36)
		t_mat.roughness = 0.3
		t_mesh.material_override = t_mat
		view_tabs_root.add_child(t_mesh)
		tab_meshes[td["mode"]] = t_mesh

		var lbl_t = Label3D.new()
		lbl_t.text = td["text"]
		lbl_t.font_size = 18
		lbl_t.outline_size = 5
		lbl_t.modulate = Color.WHITE
		lbl_t.position = Vector3(td["x"], 0.022, 0)
		lbl_t.rotation.x = -PI * 0.5
		view_tabs_root.add_child(lbl_t)

		var sb = StaticBody3D.new()
		sb.position = Vector3(td["x"], 0.015, 0)
		sb.set_meta("bs_type", "view_tab")
		sb.set_meta("view_mode", td["mode"])
		var cs = CollisionShape3D.new()
		var bs = BoxShape3D.new()
		bs.size = Vector3(0.25, 0.035, 0.065)
		cs.shape = bs
		sb.add_child(cs)
		view_tabs_root.add_child(sb)

	# 2. Attack Radar Board (Firing at opponent's fleet)
	attack_board_root = _build_naval_grid_frame(
		phase2_root,
		"🎯 رادار حمله (میدان حریف)",
		Color(1.0, 0.45, 0.38),
		true,
		"attack_grid_cell",
		attack_cell_meshes
	)
	attack_sunk_ships_root = Node3D.new()
	attack_sunk_ships_root.name = "AttackSunkShipsRoot"
	attack_board_root.add_child(attack_sunk_ships_root)

	attack_markers_root = Node3D.new()
	attack_markers_root.name = "AttackMarkersRoot"
	attack_board_root.add_child(attack_markers_root)

	attack_hover_reticle = _create_target_reticle()
	attack_hover_reticle.visible = false
	attack_board_root.add_child(attack_hover_reticle)

	_build_fleet_status_strip(attack_board_root, enemy_status_badges, "ناوگان حریف:")

	# 3. My Fleet Defense Board (Viewing own 3D ships + opponent's shots)
	my_fleet_board_root = _build_naval_grid_frame(
		phase2_root,
		"🛡️ ناوگان خودی (میدان دفاع)",
		Color(0.38, 0.90, 0.98),
		false,
		"defense_grid_cell",
		defense_cell_meshes
	)
	defense_ships_root = Node3D.new()
	defense_ships_root.name = "DefenseShipsRoot"
	my_fleet_board_root.add_child(defense_ships_root)

	defense_markers_root = Node3D.new()
	defense_markers_root.name = "DefenseMarkersRoot"
	my_fleet_board_root.add_child(defense_markers_root)

	_build_fleet_status_strip(my_fleet_board_root, my_status_badges, "ناوگان شما:")

func _build_fleet_status_strip(parent_board: Node3D, badge_dict: Dictionary, label_prefix: String) -> void:
	var strip_z: float = (GRID_SIZE * CELL_PITCH) * 0.5 + 0.044
	var lbl = Label3D.new()
	lbl.text = label_prefix
	lbl.font_size = 18
	lbl.outline_size = 5
	lbl.modulate = Color(0.92, 0.84, 0.62)
	lbl.position = Vector3(0.25, 0.028, strip_z)
	lbl.rotation.x = -PI * 0.5
	parent_board.add_child(lbl)

	var x_positions = [-0.28, -0.13, 0.02, 0.14]
	var lengths = [5, 4, 3, 2]
	for i in range(4):
		var s_len: int = lengths[i]
		var pill = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.125, 0.010, 0.038)
		pill.mesh = pm
		pill.position = Vector3(x_positions[i], 0.026, strip_z)
		var pmat = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.14, 0.36, 0.28)
		pmat.roughness = 0.3
		pill.material_override = pmat
		parent_board.add_child(pill)

		var slbl = Label3D.new()
		slbl.text = "🚢×%s" % _fa_num(s_len)
		slbl.font_size = 17
		slbl.outline_size = 5
		slbl.modulate = Color(0.75, 1.0, 0.85)
		slbl.position = Vector3(x_positions[i], 0.034, strip_z)
		slbl.rotation.x = -PI * 0.5
		parent_board.add_child(slbl)

		badge_dict[s_len] = {"pill": pill, "label": slbl}

func _update_fleet_status_badge(badge_dict: Dictionary, s_len: int, is_sunk: bool) -> void:
	if not badge_dict.has(s_len):
		return
	var entry = badge_dict[s_len]
	var pill: MeshInstance3D = entry["pill"]
	var slbl: Label3D = entry["label"]
	if is_instance_valid(pill) and pill.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = pill.material_override
		if is_sunk:
			mat.albedo_color = Color(0.55, 0.12, 0.14)
			mat.emission_enabled = true
			mat.emission = Color(0.85, 0.15, 0.15)
			mat.emission_energy_multiplier = 0.5
		else:
			mat.albedo_color = Color(0.14, 0.36, 0.28)
			mat.emission_enabled = false
	if is_instance_valid(slbl):
		if is_sunk:
			slbl.text = "💥×%s" % _fa_num(s_len)
			slbl.modulate = Color(1.0, 0.45, 0.45)
		else:
			slbl.text = "🚢×%s" % _fa_num(s_len)
			slbl.modulate = Color(0.75, 1.0, 0.85)

func _create_target_reticle() -> Node3D:
	var root = Node3D.new()
	var torus_mesh = TorusMesh.new()
	torus_mesh.inner_radius = CELL_PITCH * 0.32
	torus_mesh.outer_radius = CELL_PITCH * 0.42
	var ring = MeshInstance3D.new()
	ring.mesh = torus_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.80, 0.15)
	mat.emission_energy_multiplier = 1.6
	ring.material_override = mat
	root.add_child(ring)
	return root

# ==============================================================================
# PROCEDURAL 3D WARSHIP GENERATOR (Lengths 2, 3, 4, 5)
# ==============================================================================
func _create_warship_3d_model(ship_len: int, is_enemy_sunk: bool = false, is_ghost: bool = false) -> Node3D:
	var ship_root = Node3D.new()
	var total_len: float = float(ship_len) * CELL_PITCH - 0.016
	var hull_width: float = CELL_PITCH * 0.64
	var hull_height: float = 0.024

	var mat_hull: Material = _mat_ship_hull
	var mat_deck: Material = _mat_ship_deck
	var mat_dark: Material = _mat_ship_dark
	var mat_accent: Material = _mat_brass

	if is_enemy_sunk:
		mat_hull = _mat_ship_sunk_hull
		mat_deck = _mat_ship_sunk_hull
		mat_dark = _mat_ship_sunk_fire
		mat_accent = _mat_ship_sunk_fire
	elif is_ghost:
		mat_hull = _mat_ghost_valid
		mat_deck = _mat_ghost_valid
		mat_dark = _mat_ghost_valid
		mat_accent = _mat_ghost_valid

	# 1. Main Armored Hull Body
	var main_len: float = maxf(0.04, total_len - 0.055)
	var hull_mesh = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(hull_width, hull_height, main_len)
	hull_mesh.mesh = hm
	hull_mesh.position = Vector3(0, hull_height * 0.5, 0)
	hull_mesh.material_override = mat_hull
	ship_root.add_child(hull_mesh)

	# 2. Tapered Bow (Front +Z) & Stern (Back -Z)
	var bow_prism = MeshInstance3D.new()
	var bpm = CylinderMesh.new()
	bpm.top_radius = hull_width * 0.48
	bpm.bottom_radius = hull_width * 0.36
	bpm.height = hull_height
	bpm.radial_segments = 6
	bow_prism.mesh = bpm
	bow_prism.position = Vector3(0, hull_height * 0.5, main_len * 0.5 + 0.012)
	bow_prism.material_override = mat_hull
	ship_root.add_child(bow_prism)

	var stern_prism = MeshInstance3D.new()
	stern_prism.mesh = bpm
	stern_prism.position = Vector3(0, hull_height * 0.5, -main_len * 0.5 - 0.010)
	stern_prism.material_override = mat_hull
	ship_root.add_child(stern_prism)

	# 3. Upper Armored Deck Plate
	var deck_mesh = MeshInstance3D.new()
	var dm = BoxMesh.new()
	dm.size = Vector3(hull_width * 0.84, 0.006, main_len * 0.94)
	deck_mesh.mesh = dm
	deck_mesh.position = Vector3(0, hull_height + 0.003, 0)
	deck_mesh.material_override = mat_deck
	ship_root.add_child(deck_mesh)

	# 4. Class-Specific Superstructure Details
	if ship_len == 2:
		_add_ship_box(ship_root, Vector3(0, hull_height + 0.014, -0.012), Vector3(hull_width * 0.58, 0.020, 0.045), mat_hull)
		_add_ship_turret(ship_root, Vector3(0, hull_height + 0.008, 0.032), mat_dark, mat_accent, 1)
	elif ship_len == 3:
		_add_ship_box(ship_root, Vector3(0, hull_height + 0.018, 0.0), Vector3(hull_width * 0.52, 0.028, 0.068), mat_dark)
		_add_ship_box(ship_root, Vector3(0, hull_height + 0.038, -0.005), Vector3(0.008, 0.022, 0.008), mat_accent)
		_add_ship_turret(ship_root, Vector3(0, hull_height + 0.008, 0.068), mat_hull, mat_accent, 2)
		_add_ship_turret(ship_root, Vector3(0, hull_height + 0.008, -0.068), mat_hull, mat_accent, 1)
	elif ship_len == 4:
		_add_ship_box(ship_root, Vector3(0, hull_height + 0.020, 0.015), Vector3(hull_width * 0.62, 0.032, 0.065), mat_hull)
		_add_ship_box(ship_root, Vector3(0, hull_height + 0.038, 0.020), Vector3(hull_width * 0.42, 0.018, 0.038), mat_dark)
		var funnel = MeshInstance3D.new()
		var fm = CylinderMesh.new()
		fm.top_radius = 0.012
		fm.bottom_radius = 0.015
		fm.height = 0.032
		funnel.mesh = fm
		funnel.position = Vector3(0, hull_height + 0.020, -0.032)
		funnel.material_override = mat_dark
		ship_root.add_child(funnel)
		_add_ship_turret(ship_root, Vector3(0, hull_height + 0.009, 0.095), mat_dark, mat_accent, 2)
		_add_ship_turret(ship_root, Vector3(0, hull_height + 0.009, -0.095), mat_dark, mat_accent, 2)
	else:
		var flight_deck = MeshInstance3D.new()
		var fdm = BoxMesh.new()
		fdm.size = Vector3(hull_width * 1.12, 0.008, total_len * 0.94)
		flight_deck.mesh = fdm
		flight_deck.position = Vector3(0, hull_height + 0.008, 0)
		flight_deck.material_override = mat_dark
		ship_root.add_child(flight_deck)

		_add_ship_box(ship_root, Vector3(-0.006, hull_height + 0.013, 0), Vector3(0.006, 0.002, total_len * 0.84), mat_accent)
		_add_ship_box(ship_root, Vector3(hull_width * 0.36, hull_height + 0.026, -0.02), Vector3(0.018, 0.032, 0.085), mat_hull)
		_add_ship_box(ship_root, Vector3(hull_width * 0.36, hull_height + 0.048, -0.02), Vector3(0.010, 0.018, 0.025), mat_accent)
		_add_ship_box(ship_root, Vector3(-0.010, hull_height + 0.016, 0.09), Vector3(0.024, 0.006, 0.028), mat_hull)
		_add_ship_box(ship_root, Vector3(-0.010, hull_height + 0.016, -0.10), Vector3(0.024, 0.006, 0.028), mat_hull)

	return ship_root

func _add_ship_box(parent_node: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> void:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent_node.add_child(mi)

func _add_ship_turret(parent_node: Node3D, pos: Vector3, mat_base: Material, mat_barrel: Material, barrel_count: int) -> void:
	var base = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.014
	cm.bottom_radius = 0.017
	cm.height = 0.014
	base.mesh = cm
	base.position = pos
	base.material_override = mat_base
	parent_node.add_child(base)

	for i in range(barrel_count):
		var x_off: float = 0.0 if barrel_count == 1 else (-0.005 + float(i) * 0.010)
		var barrel = MeshInstance3D.new()
		var b_cyl = CylinderMesh.new()
		b_cyl.top_radius = 0.0025
		b_cyl.bottom_radius = 0.003
		b_cyl.height = 0.026
		barrel.mesh = b_cyl
		barrel.rotation.x = PI * 0.5
		barrel.position = pos + Vector3(x_off, 0.003, 0.016)
		barrel.material_override = mat_barrel
		parent_node.add_child(barrel)

# ==============================================================================
# PHASE 1: FLEET PLACEMENT & VALIDATION LOGIC
# ==============================================================================
func _apply_default_initial_fleet() -> void:
	var default_layout = {
		5: {"cells": [0, 8, 16, 24, 32], "horiz": false},
		4: {"cells": [2, 10, 18, 26], "horiz": false},
		3: {"cells": [4, 12, 20], "horiz": false},
		2: {"cells": [6, 14], "horiz": false}
	}
	for s_len in SHIP_LENGTHS:
		fleet_state[s_len]["cells"] = default_layout[s_len]["cells"].duplicate()
		fleet_state[s_len]["is_horizontal"] = default_layout[s_len]["horiz"]
		fleet_state[s_len]["placed"] = true
	selected_ship_len = 5
	_rebuild_phase1_ships_visuals()
	_highlight_selected_drydock_berth()

func _compute_candidate_cells(anchor_idx: int, s_len: int, is_horiz: bool) -> Array[int]:
	var r: int = anchor_idx / GRID_SIZE
	var c: int = anchor_idx % GRID_SIZE
	if is_horiz:
		if c + s_len > GRID_SIZE:
			c = GRID_SIZE - s_len
	else:
		if r + s_len > GRID_SIZE:
			r = GRID_SIZE - s_len
	var result: Array[int] = []
	for step in range(s_len):
		var nr: int = r + (0 if is_horiz else step)
		var nc: int = c + (step if is_horiz else 0)
		result.append(nr * GRID_SIZE + nc)
	return result

func _are_cells_free_for_ship(candidate_cells: Array[int], ignore_ship_len: int) -> bool:
	if candidate_cells.is_empty():
		return false
	for idx in candidate_cells:
		if idx < 0 or idx >= TOTAL_CELLS:
			return false
	for other_len in SHIP_LENGTHS:
		if other_len == ignore_ship_len:
			continue
		if not fleet_state[other_len]["placed"]:
			continue
		var occupied: Array = fleet_state[other_len]["cells"]
		for idx in candidate_cells:
			if idx in occupied:
				return false
	return true

func _try_place_ship_at(s_len: int, anchor_idx: int, is_horiz: bool) -> bool:
	var cells = _compute_candidate_cells(anchor_idx, s_len, is_horiz)
	if not _are_cells_free_for_ship(cells, s_len):
		return false
	fleet_state[s_len]["cells"] = cells
	fleet_state[s_len]["is_horizontal"] = is_horiz
	fleet_state[s_len]["placed"] = true
	AudioManager.play_sound("tap_button")
	_rebuild_phase1_ships_visuals()
	_highlight_selected_drydock_berth()
	return true

func _rotate_selected_ship() -> void:
	if is_play_phase or is_board_saved:
		return
	var st = fleet_state.get(selected_ship_len)
	if st == null:
		return
	var new_horiz: bool = not st["is_horizontal"]
	if not st["placed"] or st["cells"].is_empty():
		st["is_horizontal"] = new_horiz
		_show_phase1_feedback("جهت کشتی سایز %s تغییر کرد" % _fa_num(selected_ship_len), Color(0.55, 0.92, 1.0))
		return

	var anchor_idx: int = int(st["cells"][0])
	var candidate = _compute_candidate_cells(anchor_idx, selected_ship_len, new_horiz)
	if _are_cells_free_for_ship(candidate, selected_ship_len):
		st["cells"] = candidate
		st["is_horizontal"] = new_horiz
		AudioManager.play_sound("tap_button")
		_rebuild_phase1_ships_visuals()
		return

	var base_r: int = anchor_idx / GRID_SIZE
	var base_c: int = anchor_idx % GRID_SIZE
	for delta in [-1, 1, -2, 2, -3, 3]:
		var test_r = clampi(base_r + (0 if new_horiz else delta), 0, GRID_SIZE - 1)
		var test_c = clampi(base_c + (delta if new_horiz else 0), 0, GRID_SIZE - 1)
		var alt_cells = _compute_candidate_cells(test_r * GRID_SIZE + test_c, selected_ship_len, new_horiz)
		if _are_cells_free_for_ship(alt_cells, selected_ship_len):
			st["cells"] = alt_cells
			st["is_horizontal"] = new_horiz
			AudioManager.play_sound("tap_button")
			_rebuild_phase1_ships_visuals()
			return

	_show_phase1_feedback("فضای کافی برای چرخش در این نقطه نیست!", Color(1.0, 0.45, 0.45))

func _randomize_fleet_placement() -> void:
	if is_play_phase or is_board_saved:
		return
	for s_len in SHIP_LENGTHS:
		fleet_state[s_len]["placed"] = false
		fleet_state[s_len]["cells"] = []

	var lengths_desc = [5, 4, 3, 2]
	for s_len in lengths_desc:
		var placed_ok: bool = false
		for _attempt in range(120):
			var rand_horiz: bool = (randi() % 2 == 0)
			var rand_idx: int = randi() % TOTAL_CELLS
			var cells = _compute_candidate_cells(rand_idx, s_len, rand_horiz)
			if _are_cells_free_for_ship(cells, s_len):
				fleet_state[s_len]["cells"] = cells
				fleet_state[s_len]["is_horizontal"] = rand_horiz
				fleet_state[s_len]["placed"] = true
				placed_ok = true
				break
		if not placed_ok:
			_apply_default_initial_fleet()
			return

	AudioManager.play_sound("tap_button")
	_rebuild_phase1_ships_visuals()
	_highlight_selected_drydock_berth()
	_show_phase1_feedback("🎲 ناوگان به صورت تصادفی چیده شد!", Color(0.45, 1.0, 0.68))

func _rebuild_phase1_ships_visuals() -> void:
	for s_len in phase1_ship_nodes.keys():
		var old_node = phase1_ship_nodes[s_len]
		if is_instance_valid(old_node):
			old_node.queue_free()
	phase1_ship_nodes.clear()

	for idx in range(phase1_cell_meshes.size()):
		var r: int = idx / GRID_SIZE
		var c: int = idx % GRID_SIZE
		var cm: MeshInstance3D = phase1_cell_meshes[idx]
		if is_instance_valid(cm) and cm.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = cm.material_override
			mat.albedo_color = Color(0.06, 0.24, 0.38, 0.92) if ((r + c) % 2 == 0) else Color(0.08, 0.29, 0.44, 0.92)
			mat.emission_enabled = false

	for s_len in SHIP_LENGTHS:
		var st = fleet_state[s_len]
		if not st["placed"] or st["cells"].is_empty():
			continue
		var cells: Array = st["cells"]
		var is_horiz: bool = st["is_horizontal"]
		var p_first: Vector3 = _cell_index_to_local_pos(int(cells[0]))
		var p_last: Vector3 = _cell_index_to_local_pos(int(cells[cells.size() - 1]))
		var center_pos: Vector3 = (p_first + p_last) * 0.5
		center_pos.y = 0.026

		var ship_node = _create_warship_3d_model(s_len, false, false)
		ship_node.position = center_pos
		ship_node.rotation.y = (PI * 0.5) if is_horiz else 0.0
		phase1_grid_root.add_child(ship_node)
		phase1_ship_nodes[s_len] = ship_node

		var is_sel: bool = (s_len == selected_ship_len)
		for c_idx in cells:
			if c_idx >= 0 and c_idx < phase1_cell_meshes.size():
				var cm: MeshInstance3D = phase1_cell_meshes[c_idx]
				if is_instance_valid(cm) and cm.material_override is StandardMaterial3D:
					var mat: StandardMaterial3D = cm.material_override
					if is_sel:
						mat.albedo_color = Color(0.16, 0.55, 0.42, 0.95)
						mat.emission_enabled = true
						mat.emission = Color(0.18, 0.75, 0.50)
						mat.emission_energy_multiplier = 0.45
					else:
						mat.albedo_color = Color(0.10, 0.38, 0.52, 0.95)

func _highlight_selected_drydock_berth() -> void:
	for s_len in drydock_slot_highlights.keys():
		var box: MeshInstance3D = drydock_slot_highlights[s_len]
		if not is_instance_valid(box) or not (box.material_override is StandardMaterial3D):
			continue
		var mat: StandardMaterial3D = box.material_override
		var is_placed: bool = fleet_state[s_len]["placed"]
		if s_len == selected_ship_len:
			mat.albedo_color = Color(0.85, 0.65, 0.18)
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.72, 0.20)
			mat.emission_energy_multiplier = 0.55
		elif is_placed:
			mat.albedo_color = Color(0.12, 0.38, 0.28)
			mat.emission_enabled = false
		else:
			mat.albedo_color = Color(0.14, 0.24, 0.34)
			mat.emission_enabled = false

func _update_ghost_preview(anchor_idx: int) -> void:
	for ch in ghost_preview_root.get_children():
		ch.queue_free()
	if anchor_idx < 0 or is_play_phase or is_board_saved or selected_ship_len <= 0:
		return

	var is_horiz: bool = fleet_state[selected_ship_len]["is_horizontal"]
	var candidate = _compute_candidate_cells(anchor_idx, selected_ship_len, is_horiz)
	var is_valid: bool = _are_cells_free_for_ship(candidate, selected_ship_len)
	var ghost_mat: StandardMaterial3D = _mat_ghost_valid if is_valid else _mat_ghost_invalid

	for c_idx in candidate:
		var pos = _cell_index_to_local_pos(c_idx)
		var g_box = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(CELL_PITCH - 0.008, 0.016, CELL_PITCH - 0.008)
		g_box.mesh = bm
		g_box.position = pos + Vector3(0, 0.010, 0)
		g_box.material_override = ghost_mat
		ghost_preview_root.add_child(g_box)

func _show_phase1_feedback(msg: String, col: Color) -> void:
	if is_instance_valid(lbl_phase1_hint):
		lbl_phase1_hint.text = msg
		lbl_phase1_hint.modulate = col

# ==============================================================================
# HUD BUTTON CALLBACKS (Matches FekrBekr Interface in Main & BaseGameHUD)
# ==============================================================================
func _on_hud_submit_pressed() -> void:
	submit_code()

func _on_hud_clear_pressed() -> void:
	clear_current_row()

func _on_hud_opponent_pressed() -> void:
	toggle_opponent_view()

func _on_hud_dual_pressed() -> void:
	toggle_dual_view()

func clear_current_row() -> void:
	if is_play_phase or is_board_saved:
		return
	_randomize_fleet_placement()

func submit_code() -> void:
	if is_play_phase or is_board_saved:
		return
	for s_len in SHIP_LENGTHS:
		if not fleet_state[s_len]["placed"] or fleet_state[s_len]["cells"].size() != s_len:
			_apply_default_initial_fleet()
			break

	var payload: Dictionary = {}
	for s_len in SHIP_LENGTHS:
		var cells_arr: Array[int] = []
		for idx in fleet_state[s_len]["cells"]:
			cells_arr.append(int(idx))
		cells_arr.sort()
		payload[str(s_len)] = cells_arr

	is_board_saved = true
	set_board_locked(true)
	_update_ghost_preview(-1)
	AudioManager.play_sound("tap_button")
	_show_phase1_feedback("✓ ناوگان شما ثبت شد! در انتظار حریف...", Color(0.45, 1.0, 0.65))
	NetworkManager.send_save_board(payload)

	var hud = _get_hud()
	if hud:
		if hud.has_method("show_toast_hint"):
			hud.show_toast_hint("⚓ آرایش ناوگان ثبت شد. منتظر آماده شدن حریف باشید...")
		if hud.has_method("set_waiting_opponent"):
			hud.set_waiting_opponent("ناوگان شما ثبت شد. در انتظار حریف...")

func toggle_opponent_view() -> void:
	if not is_play_phase:
		return
	AudioManager.play_sound("tap_button")
	if view_mode == ViewMode.OPP_BOARD:
		view_mode = ViewMode.MY_BOARD
		show_hint("🎯 نمایش رادار حمله (میدان حریف)")
	else:
		view_mode = ViewMode.OPP_BOARD
		show_hint("🛡️ نمایش ناوگان شما (میدان دفاع)")
	_animate_view_transition()

func toggle_dual_view() -> void:
	if not is_play_phase:
		return
	AudioManager.play_sound("tap_button")
	if view_mode == ViewMode.DUAL:
		view_mode = ViewMode.MY_BOARD
		show_hint("🎯 نمایش رادار حمله (میدان حریف)")
	else:
		view_mode = ViewMode.DUAL
		show_hint("👥 نمایش همزمان هر دو میدان نبرد")
	_animate_view_transition()

func _set_view_mode_direct(target_mode: int) -> void:
	if not is_play_phase:
		return
	AudioManager.play_sound("tap_button")
	view_mode = target_mode
	_animate_view_transition()

func _animate_view_transition() -> void:
	for m in tab_meshes.keys():
		var mesh_inst: MeshInstance3D = tab_meshes[m]
		if is_instance_valid(mesh_inst) and mesh_inst.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = mesh_inst.material_override
			if m == view_mode:
				mat.albedo_color = Color(0.88, 0.66, 0.18)
				mat.emission_enabled = true
				mat.emission = Color(0.95, 0.72, 0.20)
				mat.emission_energy_multiplier = 0.55
			else:
				mat.albedo_color = Color(0.18, 0.26, 0.36)
				mat.emission_enabled = false

	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if view_mode == ViewMode.MY_BOARD:
		attack_board_root.visible = true
		my_fleet_board_root.visible = true
		tw.tween_property(attack_board_root, "position", Vector3(0.0, 0.0, 0.03), 0.34)
		tw.tween_property(attack_board_root, "scale", Vector3.ONE, 0.34)
		tw.tween_property(my_fleet_board_root, "position", Vector3(1.65, -0.05, 0.03), 0.34)
		tw.tween_property(my_fleet_board_root, "scale", Vector3(0.65, 0.65, 0.65), 0.34)
	elif view_mode == ViewMode.OPP_BOARD:
		attack_board_root.visible = true
		my_fleet_board_root.visible = true
		tw.tween_property(attack_board_root, "position", Vector3(-1.65, -0.05, 0.03), 0.34)
		tw.tween_property(attack_board_root, "scale", Vector3(0.65, 0.65, 0.65), 0.34)
		tw.tween_property(my_fleet_board_root, "position", Vector3(0.0, 0.0, 0.03), 0.34)
		tw.tween_property(my_fleet_board_root, "scale", Vector3.ONE, 0.34)
	else:
		attack_board_root.visible = true
		my_fleet_board_root.visible = true
		tw.tween_property(attack_board_root, "position", Vector3(-0.37, 0.0, 0.03), 0.34)
		tw.tween_property(attack_board_root, "scale", Vector3(0.80, 0.80, 0.80), 0.34)
		tw.tween_property(my_fleet_board_root, "position", Vector3(0.37, 0.0, 0.03), 0.34)
		tw.tween_property(my_fleet_board_root, "scale", Vector3(0.80, 0.80, 0.80), 0.34)

func _update_phase_visibility() -> void:
	if is_instance_valid(phase1_root):
		phase1_root.visible = not is_play_phase
	if is_instance_valid(phase2_root):
		phase2_root.visible = is_play_phase
	if is_play_phase:
		_animate_view_transition()

func _populate_defense_board_ships() -> void:
	for ch in defense_ships_root.get_children():
		ch.queue_free()
	for s_len in SHIP_LENGTHS:
		var st = fleet_state[s_len]
		if not st["placed"] or st["cells"].is_empty():
			continue
		var cells: Array = st["cells"]
		var is_horiz: bool = st["is_horizontal"]
		var p_first: Vector3 = _cell_index_to_local_pos(int(cells[0]))
		var p_last: Vector3 = _cell_index_to_local_pos(int(cells[cells.size() - 1]))
		var center_pos: Vector3 = (p_first + p_last) * 0.5
		center_pos.y = 0.024

		var ship_node = _create_warship_3d_model(s_len, false, false)
		ship_node.name = "MyDefenseShip_%d" % s_len
		ship_node.position = center_pos
		ship_node.rotation.y = (PI * 0.5) if is_horiz else 0.0
		defense_ships_root.add_child(ship_node)

# ==============================================================================
# INPUT HANDLING (3D Raycasting for Phase 1 Placement & Phase 2 Firing)
# ==============================================================================
func _raycast_board(screen_pos: Vector2) -> Dictionary:
	var vp = get_viewport()
	if vp == null:
		return {}
	var cam = vp.get_camera_3d()
	if cam == null:
		return {}
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 20.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	return space.intersect_ray(query)

func _get_ship_at_cell(cell_idx: int) -> int:
	for s_len in SHIP_LENGTHS:
		if fleet_state[s_len]["placed"] and (cell_idx in fleet_state[s_len]["cells"]):
			return s_len
	return 0

func _input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return

	if not is_play_phase:
		_handle_phase1_input(event)
	else:
		_handle_phase2_input(event)

func _handle_phase1_input(event: InputEvent) -> void:
	if is_board_saved:
		return

	if event is InputEventMouseMotion:
		var hit = _raycast_board(event.position)
		if not hit.is_empty() and hit.collider and hit.collider.has_meta("bs_type"):
			var btype = str(hit.collider.get_meta("bs_type"))
			if btype == "p1_grid_cell":
				var c_idx: int = int(hit.collider.get_meta("cell_index"))
				if c_idx != hover_grid_index:
					hover_grid_index = c_idx
					_update_ghost_preview(hover_grid_index)
				if is_dragging_ship:
					_mark_piece_interaction()
				return
		if hover_grid_index != -1:
			hover_grid_index = -1
			_update_ghost_preview(-1)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_mark_piece_interaction()
		_rotate_selected_ship()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit = _raycast_board(event.position)
		if event.pressed:
			if hit.is_empty() or not hit.collider or not hit.collider.has_meta("bs_type"):
				return
			_mark_piece_interaction()
			var btype = str(hit.collider.get_meta("bs_type"))
			if btype == "btn_rotate_ship":
				_rotate_selected_ship()
				get_viewport().set_input_as_handled()
			elif btype == "btn_random_fleet":
				_randomize_fleet_placement()
				get_viewport().set_input_as_handled()
			elif btype == "drydock_ship":
				var s_len: int = int(hit.collider.get_meta("ship_len"))
				if selected_ship_len == s_len:
					_rotate_selected_ship()
				else:
					selected_ship_len = s_len
					_highlight_selected_drydock_berth()
					_rebuild_phase1_ships_visuals()
					_show_phase1_feedback("کشتی سایز %s انتخاب شد — روی میدان کلیک کنید" % _fa_num(s_len), Color(1.0, 0.90, 0.45))
				is_dragging_ship = true
				dragged_ship_len = s_len
				get_viewport().set_input_as_handled()
			elif btype == "p1_grid_cell":
				var c_idx: int = int(hit.collider.get_meta("cell_index"))
				var occupant_len: int = _get_ship_at_cell(c_idx)
				if occupant_len > 0:
					if selected_ship_len == occupant_len:
						is_dragging_ship = true
						dragged_ship_len = occupant_len
						hover_grid_index = c_idx
					else:
						selected_ship_len = occupant_len
						is_dragging_ship = true
						dragged_ship_len = occupant_len
						hover_grid_index = c_idx
						_highlight_selected_drydock_berth()
						_rebuild_phase1_ships_visuals()
						_show_phase1_feedback("کشتی سایز %s انتخاب شد (کلیک مجدد = چرخش)" % _fa_num(occupant_len), Color(0.55, 0.92, 1.0))
				else:
					if _try_place_ship_at(selected_ship_len, c_idx, fleet_state[selected_ship_len]["is_horizontal"]):
						_show_phase1_feedback("⚓ کشتی سایز %s مستقر شد" % _fa_num(selected_ship_len), Color(0.45, 1.0, 0.68))
				get_viewport().set_input_as_handled()
		else:
			if is_dragging_ship:
				is_dragging_ship = false
				_mark_piece_interaction()
				if not hit.is_empty() and hit.collider and hit.collider.has_meta("bs_type"):
					if str(hit.collider.get_meta("bs_type")) == "p1_grid_cell":
						var drop_idx: int = int(hit.collider.get_meta("cell_index"))
						var cur_cells: Array = fleet_state[selected_ship_len]["cells"]
						if not cur_cells.is_empty() and drop_idx == int(cur_cells[0]):
							_rotate_selected_ship()
						else:
							_try_place_ship_at(selected_ship_len, drop_idx, fleet_state[selected_ship_len]["is_horizontal"])
				_update_ghost_preview(-1)
				get_viewport().set_input_as_handled()

func _handle_phase2_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit = _raycast_board(event.position)
		if is_my_turn and not is_waiting_server and not hit.is_empty() and hit.collider and hit.collider.has_meta("bs_type"):
			if str(hit.collider.get_meta("bs_type")) == "attack_grid_cell":
				var c_idx: int = int(hit.collider.get_meta("cell_index"))
				if c_idx >= 0 and c_idx < TOTAL_CELLS and not attack_cells_state[c_idx]["is_selected"]:
					attack_hover_reticle.visible = true
					attack_hover_reticle.position = _cell_index_to_local_pos(c_idx) + Vector3(0, 0.012, 0)
					return
		attack_hover_reticle.visible = false

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit = _raycast_board(event.position)
		if hit.is_empty() or not hit.collider or not hit.collider.has_meta("bs_type"):
			return
		var btype = str(hit.collider.get_meta("bs_type"))
		if btype == "view_tab":
			_mark_piece_interaction()
			var target_mode: int = int(hit.collider.get_meta("view_mode"))
			_set_view_mode_direct(target_mode)
			get_viewport().set_input_as_handled()
			return
		elif btype == "attack_grid_cell":
			if not is_my_turn or is_waiting_server or is_board_locked:
				return
			var c_idx: int = int(hit.collider.get_meta("cell_index"))
			if c_idx < 0 or c_idx >= TOTAL_CELLS:
				return
			if attack_cells_state[c_idx]["is_selected"]:
				return
			_mark_piece_interaction()
			is_waiting_server = true
			attack_hover_reticle.visible = true
			attack_hover_reticle.position = _cell_index_to_local_pos(c_idx) + Vector3(0, 0.012, 0)
			AudioManager.play_sound("tap_button")
			NetworkManager.send_select_peace(c_idx)
			get_viewport().set_input_as_handled()

# ==============================================================================
# BASEGAMEBOARD VIRTUAL HOOKS & SERVER LIFECYCLE
# ==============================================================================
func setup_board(_game_data: Dictionary) -> void:
	is_play_phase = false
	is_board_saved = false
	is_waiting_server = false
	set_board_locked(not GameManager.is_game_active)
	_update_phase_visibility()
	if GameManager.is_game_active:
		var hud = _get_hud()
		if hud and hud.has_method("set_setup_phase"):
			hud.set_setup_phase()

func on_start_game() -> void:
	is_play_phase = false
	is_board_saved = false
	is_waiting_server = false
	p1_score = 0
	p2_score = 0
	view_mode = ViewMode.MY_BOARD
	set_board_locked(false)
	_init_data_structures()
	_apply_default_initial_fleet()
	_update_phase_visibility()

	var hud = _get_hud()
	if hud:
		if hud.has_method("set_setup_phase"):
			hud.set_setup_phase()
		if hud.has_method("set_fekrbekr_hud_buttons"):
			hud.set_fekrbekr_hud_buttons(false)

func on_wait_time(time_sec: int) -> void:
	set_board_locked(true)
	var hud = _get_hud()
	if hud and hud.has_method("set_round_wait"):
		hud.set_round_wait(time_sec)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	is_waiting_server = false
	if turn == 0:
		is_play_phase = false
		set_board_locked(not GameManager.is_game_active)
		_update_phase_visibility()
		return

	if not is_play_phase and turn in [1, 2]:
		is_play_phase = true
		_populate_defense_board_ships()
		view_mode = ViewMode.MY_BOARD
		_update_phase_visibility()

		var hud = _get_hud()
		if hud and hud.has_method("set_fekrbekr_hud_buttons"):
			hud.set_fekrbekr_hud_buttons(true)

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var sdata: Dictionary = extra
	if extra.has("select_data") and typeof(extra["select_data"]) == TYPE_DICTIONARY:
		sdata = extra["select_data"]

	var cell_idx: int = int(sdata.get("index", target_peace))
	var shooter_id: int = int(sdata.get("gamer_id", user_id))
	var hit_number: int = int(sdata.get("number", 0))
	var is_bonus_turn: bool = bool(sdata.get("is_turn_win_happened", hit_number > 0))

	if cell_idx < 0 or cell_idx >= TOTAL_CELLS:
		is_waiting_server = false
		return

	attack_hover_reticle.visible = false
	var is_my_shot: bool = (shooter_id == my_player_index)
	var target_board_root: Node3D = attack_board_root if is_my_shot else my_fleet_board_root
	var target_markers_root: Node3D = attack_markers_root if is_my_shot else defense_markers_root
	var cells_state: Array[Dictionary] = attack_cells_state if is_my_shot else defense_cells_state
	var cell_meshes: Array[MeshInstance3D] = attack_cell_meshes if is_my_shot else defense_cell_meshes

	if view_mode != ViewMode.DUAL:
		var desired_mode = ViewMode.MY_BOARD if is_my_shot else ViewMode.OPP_BOARD
		if view_mode != desired_mode:
			view_mode = desired_mode
			_animate_view_transition()

	cells_state[cell_idx]["is_selected"] = true
	cells_state[cell_idx]["number"] = hit_number

	# Update scores on Hit
	var hud = _get_hud()
	if hit_number > 0:
		if shooter_id == 1:
			p1_score += 1
		else:
			p2_score += 1
		GameManager.p1_score = p1_score
		GameManager.p2_score = p2_score
		if hud and hud.has_method("update_scores"):
			hud.update_scores(p1_score, p2_score)

	# Check if this hit completed/sank an entire warship (length 2, 3, 4, or 5)
	var is_ship_sunk: bool = false
	var sunk_ship_cells: Array[int] = []
	if hit_number in [2, 3, 4, 5]:
		for idx in range(TOTAL_CELLS):
			if cells_state[idx]["is_selected"] and int(cells_state[idx]["number"]) == hit_number:
				sunk_ship_cells.append(idx)
		if sunk_ship_cells.size() >= hit_number:
			is_ship_sunk = true
			if is_my_shot:
				sunk_enemy_ships[hit_number] = true
				_update_fleet_status_badge(enemy_status_badges, hit_number, true)
			else:
				sunk_my_ships[hit_number] = true
				_update_fleet_status_badge(my_status_badges, hit_number, true)

	var impact_pos: Vector3 = _cell_index_to_local_pos(cell_idx)
	_play_shot_sequence_vfx(
		target_board_root,
		target_markers_root,
		cell_meshes,
		cell_idx,
		impact_pos,
		hit_number,
		is_ship_sunk,
		sunk_ship_cells,
		is_my_shot
	)

	# Bonus Turn Handling: When a ship is hit, backend restarts the 12s timer for the SAME player
	# without sending Current_Turn! Unlock immediately and restart HUD 12s turn timer!
	if is_bonus_turn:
		is_waiting_server = false
		is_my_turn = (shooter_id == my_player_index)
		set_board_locked(not is_my_turn)
		if hud:
			if hud.has_method("start_turn_timer"):
				hud.start_turn_timer(12.0)
			if is_ship_sunk and hud.has_method("show_toast_hint"):
				if is_my_shot:
					hud.show_toast_hint("💥 ناو جنگی سایز %s حریف کاملاً غرق شد! شلیک جایزه دارید!" % _fa_num(hit_number))
				else:
					hud.show_toast_hint("⚠️ ناو جنگی سایز %s شما غرق شد!" % _fa_num(hit_number))

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data: Dictionary = payload.get("game_data", payload)
	if typeof(g_data) != TYPE_DICTIONARY:
		return
	is_play_phase = bool(g_data.get("is_play_phase", false))
	is_board_saved = bool(g_data.get("is_player_rdy", false))
	var c_turn: int = int(g_data.get("current_turn", 0))

	var sc = g_data.get("scores", [0, 0])
	var hud = _get_hud()
	if typeof(sc) == TYPE_ARRAY and sc.size() >= 2:
		p1_score = int(sc[0])
		p2_score = int(sc[1])
		GameManager.p1_score = p1_score
		GameManager.p2_score = p2_score
		if hud and hud.has_method("update_scores"):
			hud.update_scores(p1_score, p2_score)

	var p1_board: Array = g_data.get("player1_board", [])
	var p2_board: Array = g_data.get("player2_board", [])
	var my_board_raw: Array = p1_board if my_player_index == 1 else p2_board
	var opp_board_raw: Array = p2_board if my_player_index == 1 else p1_board

	var by_num: Dictionary = {2: [], 3: [], 4: [], 5: []}
	for idx in range(mini(TOTAL_CELLS, my_board_raw.size())):
		var item = my_board_raw[idx]
		if typeof(item) == TYPE_DICTIONARY:
			var num: int = int(item.get("number", 0))
			var sel: bool = bool(item.get("is_selected", false))
			defense_cells_state[idx] = {"is_selected": sel, "number": num}
			if num in [2, 3, 4, 5]:
				by_num[num].append(idx)

	for s_len in SHIP_LENGTHS:
		var cells_arr: Array = by_num[s_len]
		if cells_arr.size() == s_len:
			cells_arr.sort()
			var is_horiz: bool = (cells_arr.size() >= 2 and (int(cells_arr[1]) - int(cells_arr[0]) == 1))
			fleet_state[s_len]["cells"] = cells_arr
			fleet_state[s_len]["is_horizontal"] = is_horiz
			fleet_state[s_len]["placed"] = true

	_rebuild_phase1_ships_visuals()
	_populate_defense_board_ships()

	for ch in attack_markers_root.get_children():
		ch.queue_free()
	for ch in attack_sunk_ships_root.get_children():
		ch.queue_free()
	for ch in defense_markers_root.get_children():
		ch.queue_free()

	var opp_hit_counts: Dictionary = {2: [], 3: [], 4: [], 5: []}
	var my_hit_counts: Dictionary = {2: [], 3: [], 4: [], 5: []}

	for idx in range(mini(TOTAL_CELLS, opp_board_raw.size())):
		var item = opp_board_raw[idx]
		if typeof(item) == TYPE_DICTIONARY:
			var sel: bool = bool(item.get("is_selected", false))
			var num: int = int(item.get("number", 0))
			attack_cells_state[idx] = {"is_selected": sel, "number": num}
			if sel:
				var pos = _cell_index_to_local_pos(idx)
				_place_persistent_shot_marker(attack_markers_root, attack_cell_meshes, idx, pos, num > 0)
				if num in [2, 3, 4, 5]:
					opp_hit_counts[num].append(idx)

	for idx in range(TOTAL_CELLS):
		if defense_cells_state[idx]["is_selected"]:
			var num: int = int(defense_cells_state[idx]["number"])
			var pos = _cell_index_to_local_pos(idx)
			_place_persistent_shot_marker(defense_markers_root, defense_cell_meshes, idx, pos, num > 0)
			if num in [2, 3, 4, 5]:
				my_hit_counts[num].append(idx)

	for s_len in SHIP_LENGTHS:
		if opp_hit_counts[s_len].size() >= s_len:
			sunk_enemy_ships[s_len] = true
			_update_fleet_status_badge(enemy_status_badges, s_len, true)
			_spawn_sunk_enemy_warship_model(opp_hit_counts[s_len], s_len, false)
		if my_hit_counts[s_len].size() >= s_len:
			sunk_my_ships[s_len] = true
			_update_fleet_status_badge(my_status_badges, s_len, true)

	_update_phase_visibility()
	if hud and hud.has_method("set_fekrbekr_hud_buttons"):
		hud.set_fekrbekr_hud_buttons(is_play_phase)

	if is_play_phase and c_turn in [1, 2]:
		is_my_turn = (c_turn == my_player_index)
		set_board_locked(not is_my_turn)

# ==============================================================================
# 3D NAVAL COMBAT VFX (Artillery Shell, Water Splash, Hit Explosion & Sunk Ship!)
# ==============================================================================
func _play_shot_sequence_vfx(
	target_board: Node3D,
	markers_root: Node3D,
	cell_meshes: Array[MeshInstance3D],
	cell_idx: int,
	impact_pos: Vector3,
	hit_number: int,
	is_ship_sunk: bool,
	sunk_ship_cells: Array[int],
	is_my_shot: bool
) -> void:
	var shell = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.015
	sm.height = 0.030
	shell.mesh = sm
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(1.0, 0.78, 0.25)
	s_mat.emission_enabled = true
	s_mat.emission = Color(1.0, 0.55, 0.12)
	s_mat.emission_energy_multiplier = 2.5
	shell.material_override = s_mat
	var start_pos = Vector3(0.0, 0.38, 0.42 if is_my_shot else -0.42)
	shell.position = start_pos
	target_board.add_child(shell)

	var flight_dur: float = 0.24
	var tw = create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(shell):
			var p = start_pos.lerp(impact_pos, t)
			p.y += sin(t * PI) * 0.22
			shell.position = p
	, 0.0, 1.0, flight_dur)

	tw.tween_callback(func():
		if is_instance_valid(shell):
			shell.queue_free()
		_place_persistent_shot_marker(markers_root, cell_meshes, cell_idx, impact_pos, hit_number > 0)
		if hit_number == 0:
			AudioManager.play_sound("tap_wrong")
			_spawn_water_splash_vfx(target_board, impact_pos)
		else:
			AudioManager.play_sound("win" if is_ship_sunk else "bell")
			_spawn_ship_hit_vfx(target_board, impact_pos)
			if is_ship_sunk:
				_trigger_full_ship_sunk_vfx(target_board, hit_number, sunk_ship_cells, is_my_shot)
	)

func _place_persistent_shot_marker(markers_root: Node3D, cell_meshes: Array[MeshInstance3D], cell_idx: int, pos: Vector3, is_hit: bool) -> void:
	if cell_idx >= 0 and cell_idx < cell_meshes.size():
		var cm: MeshInstance3D = cell_meshes[cell_idx]
		if is_instance_valid(cm) and cm.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = cm.material_override
			if is_hit:
				mat.albedo_color = Color(0.75, 0.14, 0.12, 0.96)
				mat.emission_enabled = true
				mat.emission = Color(0.95, 0.22, 0.10)
				mat.emission_energy_multiplier = 0.65
			else:
				mat.albedo_color = Color(0.14, 0.42, 0.56, 0.90)

	var peg = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.014 if is_hit else 0.011
	cyl.bottom_radius = 0.016 if is_hit else 0.013
	cyl.height = 0.028 if is_hit else 0.018
	peg.mesh = cyl
	peg.position = pos + Vector3(0, 0.016, 0)
	var p_mat = StandardMaterial3D.new()
	if is_hit:
		p_mat.albedo_color = Color(1.0, 0.25, 0.15)
		p_mat.emission_enabled = true
		p_mat.emission = Color(1.0, 0.30, 0.10)
		p_mat.emission_energy_multiplier = 1.8
	else:
		p_mat.albedo_color = Color(0.82, 0.94, 1.0)
		p_mat.roughness = 0.2
	peg.material_override = p_mat
	markers_root.add_child(peg)

func _spawn_water_splash_vfx(target_board: Node3D, pos: Vector3) -> void:
	var ring = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.012
	tm.outer_radius = 0.020
	ring.mesh = tm
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.65, 0.95, 1.0, 0.90)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.45, 0.88, 1.0)
	r_mat.emission_energy_multiplier = 1.2
	ring.material_override = r_mat
	ring.position = pos + Vector3(0, 0.008, 0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	target_board.add_child(ring)

	var plume = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.006
	pm.bottom_radius = 0.016
	pm.height = 0.065
	plume.mesh = pm
	plume.material_override = r_mat
	plume.position = pos + Vector3(0, 0.025, 0)
	target_board.add_child(plume)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.4, 1.0, 2.4), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r_mat, "albedo_color:a", 0.0, 0.42)
	tw.tween_property(plume, "position:y", pos.y + 0.065, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
		if is_instance_valid(plume):
			plume.queue_free()
	)

func _spawn_ship_hit_vfx(target_board: Node3D, pos: Vector3) -> void:
	var fireball = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.028
	sm.height = 0.056
	fireball.mesh = sm
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(1.0, 0.45, 0.10, 0.95)
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.35, 0.05)
	f_mat.emission_energy_multiplier = 2.8
	fireball.material_override = f_mat
	fireball.position = pos + Vector3(0, 0.022, 0)
	fireball.scale = Vector3(0.3, 0.3, 0.3)
	target_board.add_child(fireball)

	var shock = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.018
	tm.outer_radius = 0.028
	shock.mesh = tm
	shock.material_override = f_mat
	shock.position = pos + Vector3(0, 0.010, 0)
	shock.scale = Vector3(0.4, 1.0, 0.4)
	target_board.add_child(shock)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(fireball, "scale", Vector3(1.85, 1.85, 1.85), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shock, "scale", Vector3(2.8, 1.0, 2.8), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(f_mat, "albedo_color:a", 0.0, 0.40)
	tw.chain().tween_callback(func():
		if is_instance_valid(fireball):
			fireball.queue_free()
		if is_instance_valid(shock):
			shock.queue_free()
	)

func _trigger_full_ship_sunk_vfx(target_board: Node3D, ship_len: int, ship_cells: Array[int], is_enemy_board: bool) -> void:
	ship_cells.sort()
	if is_enemy_board:
		_spawn_sunk_enemy_warship_model(ship_cells, ship_len, true)
	else:
		var my_ship = defense_ships_root.get_node_or_null("MyDefenseShip_%d" % ship_len)
		if is_instance_valid(my_ship):
			var stw = create_tween().set_parallel(true)
			stw.tween_property(my_ship, "rotation:z", deg_to_rad(18.0), 0.65).set_trans(Tween.TRANS_SINE)
			stw.tween_property(my_ship, "position:y", 0.012, 0.65).set_trans(Tween.TRANS_SINE)

	for i in range(ship_cells.size()):
		var c_idx: int = int(ship_cells[i])
		var c_pos: Vector3 = _cell_index_to_local_pos(c_idx)
		get_tree().create_timer(float(i) * 0.11).timeout.connect(func():
			if is_instance_valid(target_board):
				_spawn_ship_hit_vfx(target_board, c_pos)
				_spawn_sunk_debris_burst(target_board, c_pos)
		)

	var p_first = _cell_index_to_local_pos(int(ship_cells[0]))
	var p_last = _cell_index_to_local_pos(int(ship_cells[ship_cells.size() - 1]))
	var ship_center = (p_first + p_last) * 0.5

	var mega_ring = MeshInstance3D.new()
	var mtm = TorusMesh.new()
	mtm.inner_radius = 0.035
	mtm.outer_radius = 0.055
	mega_ring.mesh = mtm
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(1.0, 0.65, 0.15, 0.95)
	m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_mat.emission_enabled = true
	m_mat.emission = Color(1.0, 0.45, 0.08)
	m_mat.emission_energy_multiplier = 3.2
	mega_ring.material_override = m_mat
	mega_ring.position = ship_center + Vector3(0, 0.018, 0)
	mega_ring.scale = Vector3(0.4, 1.0, 0.4)
	target_board.add_child(mega_ring)

	var base_pos = target_board.position
	var tw = create_tween()
	tw.tween_property(target_board, "position", base_pos + Vector3(0.016, 0, -0.012), 0.05)
	tw.tween_property(target_board, "position", base_pos + Vector3(-0.016, 0, 0.012), 0.05)
	tw.tween_property(target_board, "position", base_pos + Vector3(0.010, 0, 0.008), 0.05)
	tw.tween_property(target_board, "position", base_pos, 0.06)

	var rtw = create_tween().set_parallel(true)
	rtw.tween_property(mega_ring, "scale", Vector3(4.5, 1.0, 4.5), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rtw.tween_property(m_mat, "albedo_color:a", 0.0, 0.65)
	rtw.chain().tween_callback(func():
		if is_instance_valid(mega_ring):
			mega_ring.queue_free()
	)

func _spawn_sunk_enemy_warship_model(ship_cells: Array, ship_len: int, animate_sink: bool) -> void:
	if ship_cells.is_empty():
		return
	ship_cells.sort()
	var is_horiz: bool = (ship_cells.size() >= 2 and (int(ship_cells[1]) - int(ship_cells[0]) == 1))
	var p_first: Vector3 = _cell_index_to_local_pos(int(ship_cells[0]))
	var p_last: Vector3 = _cell_index_to_local_pos(int(ship_cells[ship_cells.size() - 1]))
	var center_pos: Vector3 = (p_first + p_last) * 0.5
	center_pos.y = 0.022

	var sunk_ship = _create_warship_3d_model(ship_len, true, false)
	sunk_ship.position = center_pos
	sunk_ship.rotation.y = (PI * 0.5) if is_horiz else 0.0
	attack_sunk_ships_root.add_child(sunk_ship)

	if animate_sink:
		sunk_ship.scale = Vector3(0.2, 0.2, 0.2)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(sunk_ship, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sunk_ship, "rotation:z", deg_to_rad(15.0), 0.70).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sunk_ship, "position:y", 0.013, 0.70).set_trans(Tween.TRANS_SINE)
	else:
		sunk_ship.rotation.z = deg_to_rad(15.0)
		sunk_ship.position.y = 0.013

func _spawn_sunk_debris_burst(target_board: Node3D, pos: Vector3) -> void:
	for i in range(6):
		var spark = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.010, 0.010, 0.010)
		spark.mesh = bm
		spark.material_override = _mat_ship_sunk_fire
		spark.position = pos + Vector3(0, 0.02, 0)
		target_board.add_child(spark)

		var angle: float = float(i) * (TAU / 6.0) + randf_range(-0.3, 0.3)
		var dist: float = randf_range(0.04, 0.09)
		var target_p = pos + Vector3(cos(angle) * dist, randf_range(0.05, 0.11), sin(angle) * dist)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(spark, "position", target_p, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "scale", Vector3(0.1, 0.1, 0.1), 0.38)
		tw.chain().tween_callback(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)
