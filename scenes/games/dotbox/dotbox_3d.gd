class_name DotBox3D
extends "res://scripts/games/base_game_board.gd"

# Royal Persian Dots & Boxes (نقطه خط - DotBox) 3D Physical Board
# 100% server parity with kafehfekrbackend/Entities/Games/DotBox/__init__.py
# and kafehfekr/lib/Feature/DotBox/Controllers/dotbox_controller.dart:
# - 6x6 sculpted 24K Gold pillar posts (36 dots)
# - 60 interactive 3D bridge channels (0..59: 30 horizontal + 30 vertical)
#   with forgiving ray-plane tap & hover detection, laser previews, and last-move gold aura
# - 25 recessed obsidian territory wells (0..24: 5x5 grid) with 3-wall opportunity glow
#   and 3D lathe-turned Checkers crest medallions slamming into captured boxes
# - Bonus turn continuation when 1 or 2 boxes are completed on a move

const TOTAL_LINES: int = 60
const TOTAL_BOXES: int = 25
const GRID_DOTS: int = 6
const GRID_BOXES: int = 5

const BOARD_SURFACE_Y: float = 0.048
const DOT_SPACING: float = 0.175
const GRID_MIN_XZ: float = -0.4375 # -2.5 * 0.175

const TRAY_RED_X: float = -0.765
const TRAY_BLUE_X: float = 0.765

# Exact 25 box-to-lines adjacency map matching DotBoxGameClass.boxes_neighbors 1:1
const BOXES_NEIGHBORS: Dictionary = {
	0: [0, 5, 6, 11],
	1: [1, 6, 7, 12],
	2: [2, 7, 8, 13],
	3: [3, 8, 9, 14],
	4: [4, 9, 10, 15],
	5: [11, 16, 17, 22],
	6: [12, 17, 18, 23],
	7: [13, 18, 19, 24],
	8: [14, 19, 20, 25],
	9: [15, 20, 21, 26],
	10: [22, 27, 28, 33],
	11: [23, 28, 29, 34],
	12: [24, 29, 30, 35],
	13: [25, 30, 31, 36],
	14: [26, 31, 32, 37],
	15: [33, 38, 39, 44],
	16: [34, 39, 40, 45],
	17: [35, 40, 41, 46],
	18: [36, 41, 42, 47],
	19: [37, 42, 43, 48],
	20: [44, 49, 50, 55],
	21: [45, 50, 51, 56],
	22: [46, 51, 52, 57],
	23: [47, 52, 53, 58],
	24: [48, 53, 54, 59],
}

# Logical State
var lines_board: Array[int] = []
var boxes_board: Array[int] = []
var player1_score: int = 0
var player2_score: int = 0
var last_played_line_id: int = -1
var hovered_line_id: int = -1

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

# 3D Containers & Nodes
var board_decor_root: Node3D
var lines_root: Node3D
var boxes_root: Node3D
var pieces_root: Node3D
var tray_red_root: Node3D
var tray_blue_root: Node3D

var line_centers: Array[Vector3] = []
var line_is_horizontal: Array[bool] = []
var line_slot_meshes: Array[MeshInstance3D] = []
var line_hover_meshes: Array[MeshInstance3D] = []
var line_bridge_nodes: Dictionary = {} # line_id -> Node3D

var box_centers: Array[Vector3] = []
var box_floor_meshes: Array[MeshInstance3D] = []
var box_opportunity_rings: Array[MeshInstance3D] = []
var box_crest_nodes: Dictionary = {} # box_id -> Node3D

var tray_red_pieces: Array[Node3D] = []
var tray_blue_pieces: Array[Node3D] = []
var tray_red_label: Label3D
var tray_blue_label: Label3D
var status_banner_3d: Label3D

# Shared Luxury Materials
var _mat_gold_24k: StandardMaterial3D
var _mat_brass_dark: StandardMaterial3D
var _mat_obsidian_well: StandardMaterial3D
var _mat_channel_empty: StandardMaterial3D
var _mat_channel_turn_ready: StandardMaterial3D
var _mat_channel_capture_ready: StandardMaterial3D
var _mat_red_body: StandardMaterial3D
var _mat_red_core: StandardMaterial3D
var _mat_blue_body: StandardMaterial3D
var _mat_blue_core: StandardMaterial3D
var _mat_platinum: StandardMaterial3D
var _mat_last_played_aura: StandardMaterial3D
var _mat_box_opportunity: StandardMaterial3D
var _mat_hover_red: StandardMaterial3D
var _mat_hover_blue: StandardMaterial3D
var _mat_hover_gold: StandardMaterial3D

var _pulse_tween: Tween = null
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


func _ready() -> void:
	game_type = GameTypes.DOTBOX
	add_to_group("board")
	lines_board.resize(TOTAL_LINES)
	lines_board.fill(0)
	boxes_board.resize(TOTAL_BOXES)
	boxes_board.fill(0)

	_init_shared_materials()
	_precompute_geometry()
	_build_board_3d()
	_start_ambient_pulse()
	reset_board()
	super._ready()


func _build_board_3d() -> void:
	board_decor_root = Node3D.new()
	board_decor_root.name = "BoardDecorRoot"
	add_child(board_decor_root)

	boxes_root = Node3D.new()
	boxes_root.name = "BoxesRoot"
	add_child(boxes_root)

	lines_root = Node3D.new()
	lines_root.name = "LinesRoot"
	add_child(lines_root)

	pieces_root = Node3D.new()
	pieces_root.name = "PiecesRoot"
	add_child(pieces_root)

	_build_25_territory_wells()
	_build_36_gold_dot_pillars()
	_build_60_interactive_line_channels()
	_build_side_reserve_trays()


func _init_shared_materials() -> void:
	_mat_gold_24k = StandardMaterial3D.new()
	_mat_gold_24k.albedo_color = Color(0.95, 0.78, 0.26)
	_mat_gold_24k.metallic = 0.90
	_mat_gold_24k.roughness = 0.22

	_mat_brass_dark = StandardMaterial3D.new()
	_mat_brass_dark.albedo_color = Color(0.42, 0.31, 0.15)
	_mat_brass_dark.metallic = 0.72
	_mat_brass_dark.roughness = 0.36

	_mat_obsidian_well = StandardMaterial3D.new()
	_mat_obsidian_well.albedo_color = Color(0.11, 0.08, 0.06)
	_mat_obsidian_well.metallic = 0.15
	_mat_obsidian_well.roughness = 0.42
	_mat_obsidian_well.clearcoat_enabled = true
	_mat_obsidian_well.clearcoat = 0.45

	_mat_channel_empty = StandardMaterial3D.new()
	_mat_channel_empty.albedo_color = Color(0.32, 0.23, 0.15, 0.88)
	_mat_channel_empty.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_channel_empty.roughness = 0.45

	_mat_channel_turn_ready = StandardMaterial3D.new()
	_mat_channel_turn_ready.albedo_color = Color(0.92, 0.76, 0.36, 0.55)
	_mat_channel_turn_ready.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_channel_turn_ready.emission_enabled = true
	_mat_channel_turn_ready.emission = Color(0.88, 0.70, 0.26)
	_mat_channel_turn_ready.emission_energy_multiplier = 0.55

	_mat_channel_capture_ready = StandardMaterial3D.new()
	_mat_channel_capture_ready.albedo_color = Color(1.0, 0.86, 0.22, 0.85)
	_mat_channel_capture_ready.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_channel_capture_ready.emission_enabled = true
	_mat_channel_capture_ready.emission = Color(1.0, 0.80, 0.15)
	_mat_channel_capture_ready.emission_energy_multiplier = 1.65

	# Player 1: Imperial Ruby Crimson & 24K Gold
	_mat_red_body = StandardMaterial3D.new()
	_mat_red_body.albedo_color = Color(0.76, 0.10, 0.14)
	_mat_red_body.metallic = 0.22
	_mat_red_body.roughness = 0.22
	_mat_red_body.clearcoat_enabled = true
	_mat_red_body.clearcoat = 0.88
	_mat_red_body.clearcoat_roughness = 0.10

	_mat_red_core = StandardMaterial3D.new()
	_mat_red_core.albedo_color = Color(1.0, 0.28, 0.24)
	_mat_red_core.emission_enabled = true
	_mat_red_core.emission = Color(0.95, 0.18, 0.16)
	_mat_red_core.emission_energy_multiplier = 1.15

	# Player 2: Royal Sapphire Blue & Brushed Platinum
	_mat_blue_body = StandardMaterial3D.new()
	_mat_blue_body.albedo_color = Color(0.10, 0.34, 0.78)
	_mat_blue_body.metallic = 0.25
	_mat_blue_body.roughness = 0.22
	_mat_blue_body.clearcoat_enabled = true
	_mat_blue_body.clearcoat = 0.88
	_mat_blue_body.clearcoat_roughness = 0.10

	_mat_blue_core = StandardMaterial3D.new()
	_mat_blue_core.albedo_color = Color(0.28, 0.68, 1.0)
	_mat_blue_core.emission_enabled = true
	_mat_blue_core.emission = Color(0.18, 0.54, 0.98)
	_mat_blue_core.emission_energy_multiplier = 1.15

	_mat_platinum = StandardMaterial3D.new()
	_mat_platinum.albedo_color = Color(0.86, 0.90, 0.96)
	_mat_platinum.metallic = 0.88
	_mat_platinum.roughness = 0.20

	_mat_last_played_aura = StandardMaterial3D.new()
	_mat_last_played_aura.albedo_color = Color(1.0, 0.86, 0.20, 0.65)
	_mat_last_played_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_last_played_aura.emission_enabled = true
	_mat_last_played_aura.emission = Color(1.0, 0.82, 0.15)
	_mat_last_played_aura.emission_energy_multiplier = 1.9

	_mat_box_opportunity = StandardMaterial3D.new()
	_mat_box_opportunity.albedo_color = Color(1.0, 0.82, 0.22, 0.52)
	_mat_box_opportunity.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_box_opportunity.emission_enabled = true
	_mat_box_opportunity.emission = Color(1.0, 0.76, 0.16)
	_mat_box_opportunity.emission_energy_multiplier = 1.35

	_mat_hover_red = StandardMaterial3D.new()
	_mat_hover_red.albedo_color = Color(1.0, 0.26, 0.28, 0.75)
	_mat_hover_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_red.emission_enabled = true
	_mat_hover_red.emission = Color(1.0, 0.22, 0.24)
	_mat_hover_red.emission_energy_multiplier = 1.5

	_mat_hover_blue = StandardMaterial3D.new()
	_mat_hover_blue.albedo_color = Color(0.24, 0.64, 1.0, 0.75)
	_mat_hover_blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_blue.emission_enabled = true
	_mat_hover_blue.emission = Color(0.20, 0.58, 1.0)
	_mat_hover_blue.emission_energy_multiplier = 1.5

	_mat_hover_gold = StandardMaterial3D.new()
	_mat_hover_gold.albedo_color = Color(1.0, 0.88, 0.26, 0.90)
	_mat_hover_gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_gold.emission_enabled = true
	_mat_hover_gold.emission = Color(1.0, 0.82, 0.18)
	_mat_hover_gold.emission_energy_multiplier = 2.1


func _precompute_geometry() -> void:
	line_centers.resize(TOTAL_LINES)
	line_is_horizontal.resize(TOTAL_LINES)
	for line_id in range(TOTAL_LINES):
		var row_group: int = line_id / 11
		var rem: int = line_id % 11
		if rem < 5:
			# Horizontal line at dot-row `row_group` (0..5), box-col `rem` (0..4)
			var x: float = GRID_MIN_XZ + (float(rem) + 0.5) * DOT_SPACING
			var z: float = GRID_MIN_XZ + float(row_group) * DOT_SPACING
			line_centers[line_id] = Vector3(x, BOARD_SURFACE_Y, z)
			line_is_horizontal[line_id] = true
		else:
			# Vertical line at box-row `row_group` (0..4), dot-col `rem - 5` (0..5)
			var c_dot: int = rem - 5
			var x: float = GRID_MIN_XZ + float(c_dot) * DOT_SPACING
			var z: float = GRID_MIN_XZ + (float(row_group) + 0.5) * DOT_SPACING
			line_centers[line_id] = Vector3(x, BOARD_SURFACE_Y, z)
			line_is_horizontal[line_id] = false

	box_centers.resize(TOTAL_BOXES)
	for box_id in range(TOTAL_BOXES):
		var r: int = box_id / 5
		var c: int = box_id % 5
		var x: float = GRID_MIN_XZ + (float(c) + 0.5) * DOT_SPACING
		var z: float = GRID_MIN_XZ + (float(r) + 0.5) * DOT_SPACING
		box_centers[box_id] = Vector3(x, BOARD_SURFACE_Y, z)


func _build_25_territory_wells() -> void:
	box_floor_meshes.clear()
	box_opportunity_rings.clear()

	var well_frame_mesh = BoxMesh.new()
	well_frame_mesh.size = Vector3(DOT_SPACING - 0.022, 0.004, DOT_SPACING - 0.022)
	well_frame_mesh.material = _mat_brass_dark

	var well_floor_mesh = BoxMesh.new()
	well_floor_mesh.size = Vector3(DOT_SPACING - 0.032, 0.005, DOT_SPACING - 0.032)

	var opp_ring_mesh = TorusMesh.new()
	opp_ring_mesh.inner_radius = 0.038
	opp_ring_mesh.outer_radius = 0.052
	opp_ring_mesh.rings = 24
	opp_ring_mesh.ring_segments = 16
	opp_ring_mesh.material = _mat_box_opportunity

	for box_id in range(TOTAL_BOXES):
		var center: Vector3 = box_centers[box_id]
		var well_node = Node3D.new()
		well_node.name = "BoxWell_%d" % box_id
		well_node.position = center
		boxes_root.add_child(well_node)

		var frame_inst = MeshInstance3D.new()
		frame_inst.mesh = well_frame_mesh
		frame_inst.position = Vector3(0, -0.0005, 0)
		well_node.add_child(frame_inst)

		var floor_inst = MeshInstance3D.new()
		floor_inst.mesh = well_floor_mesh
		floor_inst.material_override = _mat_obsidian_well
		floor_inst.position = Vector3(0, 0.0005, 0)
		well_node.add_child(floor_inst)
		box_floor_meshes.append(floor_inst)

		var opp_inst = MeshInstance3D.new()
		opp_inst.mesh = opp_ring_mesh
		opp_inst.position = Vector3(0, 0.004, 0)
		opp_inst.scale = Vector3(1.0, 0.35, 1.0)
		opp_inst.visible = false
		well_node.add_child(opp_inst)
		box_opportunity_rings.append(opp_inst)


func _build_36_gold_dot_pillars() -> void:
	var base_ring_mesh = CylinderMesh.new()
	base_ring_mesh.top_radius = 0.024
	base_ring_mesh.bottom_radius = 0.028
	base_ring_mesh.height = 0.010
	base_ring_mesh.radial_segments = 24
	base_ring_mesh.material = _mat_brass_dark

	var pillar_col_mesh = CylinderMesh.new()
	pillar_col_mesh.top_radius = 0.018
	pillar_col_mesh.bottom_radius = 0.021
	pillar_col_mesh.height = 0.024
	pillar_col_mesh.radial_segments = 24
	pillar_col_mesh.material = _mat_gold_24k

	var dome_cap_mesh = SphereMesh.new()
	dome_cap_mesh.radius = 0.019
	dome_cap_mesh.height = 0.024
	dome_cap_mesh.radial_segments = 24
	dome_cap_mesh.rings = 12
	dome_cap_mesh.material = _mat_gold_24k

	for r in range(GRID_DOTS):
		for c in range(GRID_DOTS):
			var pos = Vector3(
				GRID_MIN_XZ + float(c) * DOT_SPACING,
				BOARD_SURFACE_Y,
				GRID_MIN_XZ + float(r) * DOT_SPACING
			)
			var pillar = Node3D.new()
			pillar.name = "DotPillar_%d_%d" % [r, c]
			pillar.position = pos
			board_decor_root.add_child(pillar)

			var base_inst = MeshInstance3D.new()
			base_inst.mesh = base_ring_mesh
			base_inst.position = Vector3(0, 0.005, 0)
			pillar.add_child(base_inst)

			var col_inst = MeshInstance3D.new()
			col_inst.mesh = pillar_col_mesh
			col_inst.position = Vector3(0, 0.014, 0)
			pillar.add_child(col_inst)

			var cap_inst = MeshInstance3D.new()
			cap_inst.mesh = dome_cap_mesh
			cap_inst.position = Vector3(0, 0.025, 0)
			pillar.add_child(cap_inst)


func _build_60_interactive_line_channels() -> void:
	line_slot_meshes.clear()
	line_hover_meshes.clear()

	var groove_len: float = DOT_SPACING - 0.038 # 0.137m clear between dot pillars
	var groove_width: float = 0.020

	var h_groove_mesh = BoxMesh.new()
	h_groove_mesh.size = Vector3(groove_len, 0.006, groove_width)

	var v_groove_mesh = BoxMesh.new()
	v_groove_mesh.size = Vector3(groove_width, 0.006, groove_len)

	var h_hover_mesh = BoxMesh.new()
	h_hover_mesh.size = Vector3(groove_len, 0.018, 0.026)

	var v_hover_mesh = BoxMesh.new()
	v_hover_mesh.size = Vector3(0.026, 0.018, groove_len)

	var h_hit_shape = BoxShape3D.new()
	h_hit_shape.size = Vector3(DOT_SPACING - 0.032, 0.055, 0.074)

	var v_hit_shape = BoxShape3D.new()
	v_hit_shape.size = Vector3(0.074, 0.055, DOT_SPACING - 0.032)

	for line_id in range(TOTAL_LINES):
		var is_horiz: bool = line_is_horizontal[line_id]
		var center: Vector3 = line_centers[line_id]

		var ch_root = Node3D.new()
		ch_root.name = "LineChannel_%d" % line_id
		ch_root.position = center
		lines_root.add_child(ch_root)

		var slot_inst = MeshInstance3D.new()
		slot_inst.mesh = h_groove_mesh if is_horiz else v_groove_mesh
		slot_inst.material_override = _mat_channel_empty
		slot_inst.position = Vector3(0, 0.003, 0)
		ch_root.add_child(slot_inst)
		line_slot_meshes.append(slot_inst)

		var hover_inst = MeshInstance3D.new()
		hover_inst.mesh = h_hover_mesh if is_horiz else v_hover_mesh
		hover_inst.material_override = _mat_hover_red
		hover_inst.position = Vector3(0, 0.010, 0)
		hover_inst.visible = false
		ch_root.add_child(hover_inst)
		line_hover_meshes.append(hover_inst)

		var area = Area3D.new()
		area.name = "LineArea_%d" % line_id
		var col = CollisionShape3D.new()
		col.shape = h_hit_shape if is_horiz else v_hit_shape
		col.position = Vector3(0, 0.015, 0)
		area.add_child(col)
		ch_root.add_child(area)

		var captured_id: int = line_id
		area.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _idx: int):
			if event is InputEventMouseMotion:
				_on_line_hovered(captured_id)
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_line_channel_pressed(captured_id)
			elif event is InputEventScreenTouch and event.pressed:
				_on_line_channel_pressed(captured_id)
		)
		area.mouse_entered.connect(func(): _on_line_hovered(captured_id))
		area.mouse_exited.connect(func():
			if hovered_line_id == captured_id:
				_clear_line_hover()
		)


# --- Raycast Input Handling (Single Source of Input per GAME_SCENE_RULES 4.3) ---

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return

	if event is InputEventMouseMotion:
		_raycast_board_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_raycast_down_pos = event.position
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
		else:
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = event.position.distance_to(_raycast_down_pos)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if dist <= 28.0 and elapsed < 0.65:
					_raycast_board_click(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_raycast_down_pos = event.position
			_raycast_down_time = Time.get_ticks_msec() / 1000.0
			_raycast_is_down = true
		else:
			if _raycast_is_down:
				_raycast_is_down = false
				var dist = event.position.distance_to(_raycast_down_pos)
				var elapsed = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
				if dist <= 28.0 and elapsed < 0.65:
					_raycast_board_click(event.position)


func _project_screen_to_local_board(screen_pos: Vector2) -> Vector3:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return Vector3(999.0, 0.0, 999.0)
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var board_y = global_position.y + BOARD_SURFACE_Y
	if abs(ray_normal.y) < 0.0001:
		return Vector3(999.0, 0.0, 999.0)
	var t = (board_y - ray_origin.y) / ray_normal.y
	if t < 0.0:
		return Vector3(999.0, 0.0, 999.0)
	var hit_world = ray_origin + ray_normal * t
	return to_local(hit_world)


func _raycast_board_hover(screen_pos: Vector2) -> void:
	var local_hit = _project_screen_to_local_board(screen_pos)
	if abs(local_hit.x) > 0.56 or abs(local_hit.z) > 0.56:
		_clear_line_hover()
		return
	var nearest_id = _find_closest_line_to_local_pos(local_hit, 0.048, true)
	if nearest_id != -1:
		_on_line_hovered(nearest_id)
	else:
		_clear_line_hover()


func _raycast_board_click(screen_pos: Vector2) -> void:
	var local_hit = _project_screen_to_local_board(screen_pos)
	if abs(local_hit.x) > 0.56 or abs(local_hit.z) > 0.56:
		return
	# First prefer closest empty line within forgiving radius; otherwise closest line overall
	var nearest_id = _find_closest_line_to_local_pos(local_hit, 0.056, true)
	if nearest_id == -1:
		nearest_id = _find_closest_line_to_local_pos(local_hit, 0.048, false)
	if nearest_id != -1:
		_on_line_channel_pressed(nearest_id)


func _find_closest_line_to_local_pos(local_pos: Vector3, max_dist: float, prefer_empty: bool = false) -> int:
	var best_id: int = -1
	var best_d: float = max_dist
	var p2 = Vector2(local_pos.x, local_pos.z)
	var half_seg: float = (DOT_SPACING - 0.048) * 0.5 # ~0.0635m half-length of channel between dots
	for line_id in range(TOTAL_LINES):
		if prefer_empty and lines_board[line_id] != 0:
			continue
		var c: Vector3 = line_centers[line_id]
		var is_horiz: bool = line_is_horizontal[line_id]
		var a: Vector2
		var b: Vector2
		if is_horiz:
			a = Vector2(c.x - half_seg, c.z)
			b = Vector2(c.x + half_seg, c.z)
		else:
			a = Vector2(c.x, c.z - half_seg)
			b = Vector2(c.x, c.z + half_seg)
		var closest_pt: Vector2 = Geometry2D.get_closest_point_to_segment(p2, a, b)
		var d: float = p2.distance_to(closest_pt)
		if d < best_d:
			best_d = d
			best_id = line_id
	return best_id


func _build_side_reserve_trays() -> void:
	tray_red_root = _create_single_side_tray(TRAY_RED_X, 1, "خانه‌های قرمز")
	tray_blue_root = _create_single_side_tray(TRAY_BLUE_X, 2, "خانه‌های آبی")

	status_banner_3d = Label3D.new()
	status_banner_3d.font = _font_hekayat
	status_banner_3d.font_size = 38
	status_banner_3d.outline_size = 8
	status_banner_3d.modulate = Color(1.0, 0.90, 0.42)
	status_banner_3d.outline_modulate = Color(0, 0, 0, 0.92)
	status_banner_3d.pixel_size = 0.0014
	status_banner_3d.position = Vector3(0, BOARD_SURFACE_Y + 0.035, -0.585)
	status_banner_3d.rotation.x = -deg_to_rad(52)
	status_banner_3d.text = ""
	board_decor_root.add_child(status_banner_3d)


func _create_single_side_tray(x_pos: float, player_id: int, title_text: String) -> Node3D:
	var tray = Node3D.new()
	tray.name = "SideTray_P%d" % player_id
	tray.position = Vector3(x_pos, 0.0, 0.0)
	board_decor_root.add_child(tray)

	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.20, 0.12, 0.07)
	base_mat.roughness = 0.38
	base_mat.clearcoat_enabled = true
	base_mat.clearcoat = 0.55

	var base_mesh = BoxMesh.new()
	base_mesh.size = Vector3(0.15, 0.032, 0.98)
	base_mesh.material = base_mat
	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0, 0.012, 0)
	tray.add_child(base_inst)

	var rim_mesh = BoxMesh.new()
	rim_mesh.size = Vector3(0.16, 0.006, 1.00)
	rim_mesh.material = _mat_gold_24k
	var rim_inst = MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.position = Vector3(0, 0.029, 0)
	tray.add_child(rim_inst)

	var lbl = Label3D.new()
	lbl.font = _font_hekayat
	lbl.font_size = 34
	lbl.outline_size = 7
	lbl.modulate = Color(1.0, 0.45, 0.45) if player_id == 1 else Color(0.48, 0.78, 1.0)
	lbl.outline_modulate = Color(0, 0, 0, 0.95)
	lbl.pixel_size = 0.0014
	lbl.position = Vector3(0, 0.062, -0.42)
	lbl.rotation.x = -deg_to_rad(55)
	lbl.text = "%s: ۰" % title_text
	tray.add_child(lbl)

	if player_id == 1:
		tray_red_label = lbl
	else:
		tray_blue_label = lbl

	return tray


func _rebuild_reserve_tray_stacks() -> void:
	for p in tray_red_pieces:
		if is_instance_valid(p):
			p.queue_free()
	tray_red_pieces.clear()

	for p in tray_blue_pieces:
		if is_instance_valid(p):
			p.queue_free()
	tray_blue_pieces.clear()

	var red_remaining: int = clampi(13 - player1_score, 0, 13)
	var blue_remaining: int = clampi(13 - player2_score, 0, 13)

	for i in range(red_remaining):
		var puck = _build_3d_territory_crest(1)
		puck.scale = Vector3(0.76, 0.76, 0.76)
		var z_off: float = -0.30 + float(i) * 0.056
		puck.position = Vector3(0, 0.036, z_off)
		tray_red_root.add_child(puck)
		tray_red_pieces.append(puck)

	for i in range(blue_remaining):
		var puck = _build_3d_territory_crest(2)
		puck.scale = Vector3(0.76, 0.76, 0.76)
		var z_off: float = -0.30 + float(i) * 0.056
		puck.position = Vector3(0, 0.036, z_off)
		tray_blue_root.add_child(puck)
		tray_blue_pieces.append(puck)

	if is_instance_valid(tray_red_label):
		tray_red_label.text = "خانه‌های قرمز: %s" % _fa_digits(player1_score)
	if is_instance_valid(tray_blue_label):
		tray_blue_label.text = "خانه‌های آبی: %s" % _fa_digits(player2_score)


func _build_3d_bridge_bar(owner_id: int, is_horiz: bool, is_last_played: bool) -> Node3D:
	var root = Node3D.new()
	var body_mat = _mat_red_body if owner_id == 1 else _mat_blue_body
	var core_mat = _mat_red_core if owner_id == 1 else _mat_blue_core
	var cap_mat = _mat_gold_24k if owner_id == 1 else _mat_platinum

	var bar_len: float = DOT_SPACING - 0.034 # 0.141m
	var bar_thick: float = 0.022
	var bar_height: float = 0.018

	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(bar_len, bar_height, bar_thick) if is_horiz else Vector3(bar_thick, bar_height, bar_len)
	body_mesh.material = body_mat
	var body_inst = MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.position = Vector3(0, bar_height * 0.5, 0)
	root.add_child(body_inst)

	# Glowing Top Energy Core Strip
	var core_mesh = BoxMesh.new()
	var core_len: float = bar_len - 0.022
	core_mesh.size = Vector3(core_len, 0.004, 0.008) if is_horiz else Vector3(0.008, 0.004, core_len)
	core_mesh.material = core_mat
	var core_inst = MeshInstance3D.new()
	core_inst.mesh = core_mesh
	core_inst.position = Vector3(0, bar_height + 0.001, 0)
	root.add_child(core_inst)

	# 24K Gold / Platinum End Collars
	var cap_mesh = BoxMesh.new()
	cap_mesh.size = Vector3(0.012, bar_height + 0.003, bar_thick + 0.004) if is_horiz else Vector3(bar_thick + 0.004, bar_height + 0.003, 0.012)
	cap_mesh.material = cap_mat
	for dir_sign in [-1.0, 1.0]:
		var cap_inst = MeshInstance3D.new()
		cap_inst.mesh = cap_mesh
		var offset: float = dir_sign * (bar_len * 0.5 - 0.006)
		cap_inst.position = Vector3(offset, bar_height * 0.5, 0) if is_horiz else Vector3(0, bar_height * 0.5, offset)
		root.add_child(cap_inst)

	# Last-Turn Played Golden Highlight Frame (matches Flutter PeaceStatusTypes.lastTurnPlayed)
	var aura_mesh = BoxMesh.new()
	aura_mesh.size = Vector3(bar_len + 0.008, 0.006, bar_thick + 0.012) if is_horiz else Vector3(bar_thick + 0.012, 0.006, bar_len + 0.008)
	aura_mesh.material = _mat_last_played_aura
	var aura_inst = MeshInstance3D.new()
	aura_inst.name = "LastPlayedAura"
	aura_inst.mesh = aura_mesh
	aura_inst.position = Vector3(0, 0.003, 0)
	aura_inst.visible = is_last_played
	root.add_child(aura_inst)

	return root


func _build_3d_territory_crest(owner_id: int) -> Node3D:
	# Lathe-turned 3D Checkers-style Royal Territory Crest Medallion
	var root = Node3D.new()
	var body_mat = _mat_red_body if owner_id == 1 else _mat_blue_body
	var trim_mat = _mat_gold_24k if owner_id == 1 else _mat_platinum
	var core_mat = _mat_red_core if owner_id == 1 else _mat_blue_core

	# 1. Beveled Base Pedestal Cushion
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.056
	base_mesh.bottom_radius = 0.060
	base_mesh.height = 0.012
	base_mesh.radial_segments = 32
	base_mesh.material = body_mat
	var base_inst = MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0, 0.006, 0)
	root.add_child(base_inst)

	# 2. Outer Metallic Crown Rim
	var rim_mesh = TorusMesh.new()
	rim_mesh.outer_radius = 0.054
	rim_mesh.inner_radius = 0.045
	rim_mesh.rings = 28
	rim_mesh.ring_segments = 16
	rim_mesh.material = trim_mat
	var rim_inst = MeshInstance3D.new()
	rim_inst.mesh = rim_mesh
	rim_inst.position = Vector3(0, 0.013, 0)
	rim_inst.scale = Vector3(1.0, 0.45, 1.0)
	root.add_child(rim_inst)

	# 3. Inner Ribbed Concentric Ring
	var inner_ring = TorusMesh.new()
	inner_ring.outer_radius = 0.034
	inner_ring.inner_radius = 0.027
	inner_ring.rings = 24
	inner_ring.ring_segments = 12
	inner_ring.material = trim_mat
	var inner_inst = MeshInstance3D.new()
	inner_inst.mesh = inner_ring
	inner_inst.position = Vector3(0, 0.014, 0)
	inner_inst.scale = Vector3(1.0, 0.45, 1.0)
	root.add_child(inner_inst)

	# 4. Central Glowing Jewel Star Boss
	var boss_mesh = CylinderMesh.new()
	boss_mesh.top_radius = 0.016
	boss_mesh.bottom_radius = 0.020
	boss_mesh.height = 0.008
	boss_mesh.radial_segments = 8
	boss_mesh.material = core_mat
	var boss_inst = MeshInstance3D.new()
	boss_inst.mesh = boss_mesh
	boss_inst.position = Vector3(0, 0.015, 0)
	root.add_child(boss_inst)

	return root


func _start_ambient_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_mat_box_opportunity, "emission_energy_multiplier", 2.1, 0.75).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_mat_box_opportunity, "emission_energy_multiplier", 0.75, 0.75).set_trans(Tween.TRANS_SINE)


# --- Rule Helpers (1:1 with DotBoxGameClass & DotBoxController) ---

func _check_each_box_completed(neighbors: Array) -> bool:
	for line_idx in neighbors:
		if lines_board[int(line_idx)] == 0:
			return false
	return true


func _check_box_win_happen(peace_number: int) -> Array[int]:
	var completed_boxes: Array[int] = []
	for box_id in BOXES_NEIGHBORS.keys():
		var neighbors: Array = BOXES_NEIGHBORS[box_id]
		if neighbors.has(peace_number):
			if _check_each_box_completed(neighbors):
				completed_boxes.append(int(box_id))
	return completed_boxes


func _count_filled_walls_for_box(box_id: int) -> int:
	var count: int = 0
	var neighbors: Array = BOXES_NEIGHBORS.get(box_id, [])
	for line_idx in neighbors:
		if lines_board[int(line_idx)] != 0:
			count += 1
	return count


func _would_line_complete_box(line_id: int) -> bool:
	if line_id < 0 or line_id >= TOTAL_LINES or lines_board[line_id] != 0:
		return false
	for box_id in BOXES_NEIGHBORS.keys():
		var neighbors: Array = BOXES_NEIGHBORS[box_id]
		if neighbors.has(line_id):
			var filled: int = 0
			for n_idx in neighbors:
				if int(n_idx) == line_id or lines_board[int(n_idx)] != 0:
					filled += 1
			if filled == 4:
				return true
	return false


# --- Input & Hover Interaction ---

func _on_line_hovered(line_id: int) -> void:
	if line_id < 0 or line_id >= TOTAL_LINES:
		return
	if is_board_locked or not is_my_turn or lines_board[line_id] != 0:
		_clear_line_hover()
		return
	if hovered_line_id == line_id:
		return
	_clear_line_hover()
	hovered_line_id = line_id
	var hover_inst: MeshInstance3D = line_hover_meshes[line_id]
	if is_instance_valid(hover_inst):
		if _would_line_complete_box(line_id):
			hover_inst.material_override = _mat_hover_gold
		else:
			var my_idx: int = GameManager.my_player_index if GameManager.my_player_index > 0 else 1
			hover_inst.material_override = _mat_hover_red if my_idx == 1 else _mat_hover_blue
		hover_inst.visible = true


func _clear_line_hover() -> void:
	if hovered_line_id >= 0 and hovered_line_id < line_hover_meshes.size():
		var prev_inst: MeshInstance3D = line_hover_meshes[hovered_line_id]
		if is_instance_valid(prev_inst):
			prev_inst.visible = false
	hovered_line_id = -1


func _on_line_channel_pressed(line_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if line_id < 0 or line_id >= TOTAL_LINES:
		return
	if is_board_locked:
		return
	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.play_sound("miss_turn")
		return

	var now = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_click_frame or (now - last_click_time < 0.08):
		return
	_last_click_frame = current_frame
	last_click_time = now

	if lines_board[line_id] != 0:
		show_hint("این خط قبلاً انتخاب شده است؛ خط دیگری انتخاب کنید.")
		AudioManager.play_sound("miss_turn")
		return

	set_board_locked(true)
	is_my_turn = false
	_clear_line_hover()
	AudioManager.play_sound("tap")
	ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
	send_move(Commands.Select_Peace, line_id)


# --- BaseGameBoard Lifecycle & Network Hooks ---

func set_board_locked(locked: bool) -> void:
	super.set_board_locked(locked)
	if locked:
		_clear_line_hover()
	_refresh_visual_guides()


func setup_board(game_data: Dictionary) -> void:
	reset_board()
	super._ready()
	if game_data.has("lines_board"):
		sync_board_state(game_data["lines_board"])
	_sync_hud_scores()
	_refresh_visual_guides()


func on_start_game() -> void:
	sync_turn_state()
	_refresh_visual_guides()


func on_turn_changed(turn: int, is_me: bool) -> void:
	my_player_index = GameManager.my_player_index
	current_turn = turn
	is_my_turn = is_me
	is_board_locked = not is_me
	_clear_line_hover()
	_refresh_visual_guides()


func on_piece_selected(user_id: int, target_peace: int, _extra: Dictionary = {}) -> void:
	var line_id: int = int(target_peace)
	var gamer_id: int = int(user_id) if user_id > 0 else current_turn
	if line_id < 0 or line_id >= TOTAL_LINES or gamer_id <= 0:
		return

	lines_board[line_id] = gamer_id
	last_played_line_id = line_id
	_spawn_or_animate_bridge_bar(line_id, gamer_id, true)
	_update_last_played_highlights()

	var newly_completed: Array[int] = _check_box_win_happen(line_id)
	if not newly_completed.is_empty():
		for i in range(newly_completed.size()):
			var box_id: int = newly_completed[i]
			if boxes_board[box_id] == 0:
				boxes_board[box_id] = gamer_id
				_spawn_or_animate_box_crest(box_id, gamer_id, true, float(i) * 0.12)

		_recalculate_scores_from_boxes()
		_sync_hud_scores()
		_rebuild_reserve_tray_stacks()
		AudioManager.play_sound("correct")

		# When a box is completed and lines still remain, the same player continues their turn!
		if not _is_all_lines_filled():
			current_turn = gamer_id
			GameManager.current_turn = gamer_id
			my_player_index = GameManager.my_player_index
			if gamer_id == my_player_index:
				is_my_turn = true
				set_board_locked(false)
				var count_fa = "۲ خانه" if newly_completed.size() > 1 else "۱ خانه"
				show_hint("🎁 %s گرفتید! نوبت جایزه شماست" % count_fa)
			else:
				is_my_turn = false
				set_board_locked(true)
	else:
		AudioManager.play_sound("add_peace")

	_refresh_visual_guides()


func on_reconnect_data(payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		var l_arr = g_data.get("lines_board", [])
		if typeof(l_arr) == TYPE_ARRAY and (l_arr as Array).size() == TOTAL_LINES:
			for i in range(TOTAL_LINES):
				lines_board[i] = int(l_arr[i])

		var b_arr = g_data.get("boxes_board", [])
		if typeof(b_arr) == TYPE_ARRAY and (b_arr as Array).size() == TOTAL_BOXES:
			for i in range(TOTAL_BOXES):
				boxes_board[i] = int(b_arr[i])

		if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
			player1_score = int(g_data["scores"][0])
			player2_score = int(g_data["scores"][1])
		else:
			_recalculate_scores_from_boxes()

		if g_data.has("current_turn"):
			current_turn = int(g_data["current_turn"])
			GameManager.current_turn = current_turn

	last_played_line_id = -1
	_rebuild_all_3d_pieces_from_state()
	_sync_hud_scores()
	_rebuild_reserve_tray_stacks()
	sync_turn_state()
	_refresh_visual_guides()


func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) == TYPE_ARRAY and (board_data as Array).size() == TOTAL_LINES:
		var arr: Array = board_data
		for i in range(TOTAL_LINES):
			lines_board[i] = int(arr[i])
		_rebuild_all_3d_pieces_from_state()
		_refresh_visual_guides()


func _is_all_lines_filled() -> bool:
	for v in lines_board:
		if v == 0:
			return false
	return true


func _recalculate_scores_from_boxes() -> void:
	var p1: int = 0
	var p2: int = 0
	for owner in boxes_board:
		if owner == 1:
			p1 += 1
		elif owner == 2:
			p2 += 1
	player1_score = p1
	player2_score = p2


func _sync_hud_scores() -> void:
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var main_node = get_tree().current_scene if get_tree() else null
	if main_node and "base_game_hud" in main_node and is_instance_valid(main_node.base_game_hud):
		main_node.base_game_hud.update_scores(player1_score, player2_score)


func _spawn_or_animate_bridge_bar(line_id: int, owner_id: int, animate: bool) -> void:
	if line_bridge_nodes.has(line_id) and is_instance_valid(line_bridge_nodes[line_id]):
		line_bridge_nodes[line_id].queue_free()
		line_bridge_nodes.erase(line_id)

	var is_horiz: bool = line_is_horizontal[line_id]
	var bar_node: Node3D = _build_3d_bridge_bar(owner_id, is_horiz, line_id == last_played_line_id)
	var target_pos: Vector3 = line_centers[line_id]
	pieces_root.add_child(bar_node)
	line_bridge_nodes[line_id] = bar_node

	if animate:
		bar_node.position = target_pos + Vector3(0, 0.14, 0)
		bar_node.scale = Vector3(0.4, 0.4, 0.4)
		var tw = create_tween().set_parallel(true)
		tw.tween_property(bar_node, "position", target_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(bar_node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		bar_node.position = target_pos


func _update_last_played_highlights() -> void:
	for l_id in line_bridge_nodes.keys():
		var node: Node3D = line_bridge_nodes[l_id]
		if is_instance_valid(node):
			var aura = node.get_node_or_null("LastPlayedAura")
			if aura and aura is VisualInstance3D:
				aura.visible = (int(l_id) == last_played_line_id)


func _spawn_or_animate_box_crest(box_id: int, owner_id: int, animate: bool, delay_sec: float = 0.0) -> void:
	if box_crest_nodes.has(box_id) and is_instance_valid(box_crest_nodes[box_id]):
		box_crest_nodes[box_id].queue_free()
		box_crest_nodes.erase(box_id)

	var crest: Node3D = _build_3d_territory_crest(owner_id)
	var target_pos: Vector3 = box_centers[box_id] + Vector3(0, 0.002, 0)
	pieces_root.add_child(crest)
	box_crest_nodes[box_id] = crest

	# Tint floor well subtly with owner color
	if box_id >= 0 and box_id < box_floor_meshes.size():
		var floor_inst: MeshInstance3D = box_floor_meshes[box_id]
		if is_instance_valid(floor_inst):
			var tint_mat = StandardMaterial3D.new()
			tint_mat.albedo_color = Color(0.38, 0.08, 0.10) if owner_id == 1 else Color(0.08, 0.20, 0.42)
			tint_mat.roughness = 0.35
			floor_inst.material_override = tint_mat

	if animate:
		var start_x: float = TRAY_RED_X if owner_id == 1 else TRAY_BLUE_X
		crest.position = Vector3(start_x, BOARD_SURFACE_Y + 0.18, target_pos.z)
		crest.scale = Vector3(0.25, 0.25, 0.25)
		crest.rotation.y = PI
		var tw = create_tween()
		if delay_sec > 0.0:
			tw.tween_interval(delay_sec)
		tw.set_parallel(true)
		tw.tween_property(crest, "position", target_pos, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(crest, "scale", Vector3.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(crest, "rotation:y", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			if is_instance_valid(crest):
				ActionVFXManager.spawn_piece_impact_vfx(self, target_pos, owner_id)
		)
	else:
		crest.position = target_pos


func _rebuild_all_3d_pieces_from_state() -> void:
	for k in line_bridge_nodes.keys():
		if is_instance_valid(line_bridge_nodes[k]):
			line_bridge_nodes[k].queue_free()
	line_bridge_nodes.clear()

	for k in box_crest_nodes.keys():
		if is_instance_valid(box_crest_nodes[k]):
			box_crest_nodes[k].queue_free()
	box_crest_nodes.clear()

	for box_id in range(TOTAL_BOXES):
		if box_id < box_floor_meshes.size() and is_instance_valid(box_floor_meshes[box_id]):
			box_floor_meshes[box_id].material_override = _mat_obsidian_well

	for line_id in range(TOTAL_LINES):
		var owner_id: int = lines_board[line_id]
		if owner_id > 0:
			_spawn_or_animate_bridge_bar(line_id, owner_id, false)

	for box_id in range(TOTAL_BOXES):
		var owner_id: int = boxes_board[box_id]
		if owner_id > 0:
			_spawn_or_animate_box_crest(box_id, owner_id, false)


func _refresh_visual_guides() -> void:
	# 1. Update 3-wall opportunity glow on uncaptured boxes
	var has_opportunity: bool = false
	for box_id in range(TOTAL_BOXES):
		if box_id >= box_opportunity_rings.size():
			continue
		var opp_ring: MeshInstance3D = box_opportunity_rings[box_id]
		if not is_instance_valid(opp_ring):
			continue
		if boxes_board[box_id] == 0 and _count_filled_walls_for_box(box_id) == 3:
			opp_ring.visible = true
			has_opportunity = true
		else:
			opp_ring.visible = false

	# 2. Update empty channel slot shimmer so active player clearly sees available moves and immediate captures
	for line_id in range(TOTAL_LINES):
		if line_id >= line_slot_meshes.size():
			continue
		var slot_inst: MeshInstance3D = line_slot_meshes[line_id]
		if not is_instance_valid(slot_inst):
			continue
		if lines_board[line_id] != 0:
			slot_inst.visible = false
		else:
			slot_inst.visible = true
			if is_my_turn and not is_board_locked:
				if _would_line_complete_box(line_id):
					slot_inst.material_override = _mat_channel_capture_ready
				else:
					slot_inst.material_override = _mat_channel_turn_ready
			else:
				slot_inst.material_override = _mat_channel_empty

	# 3. Update 3D top status banner
	if is_instance_valid(status_banner_3d):
		var remaining_boxes: int = TOTAL_BOXES - (player1_score + player2_score)
		if not GameManager.is_game_active:
			status_banner_3d.text = "نقطه خط — ۲۵ خانه"
		elif is_my_turn and not is_board_locked:
			if has_opportunity:
				status_banner_3d.text = "✨ فرصت تسخیر خانه! یک خط طلایی را ببندید"
				status_banner_3d.modulate = Color(1.0, 0.88, 0.25)
			else:
				status_banner_3d.text = "نوبت شما — یک خط بین دو ستون طلایی رسم کنید (%s خانه باقی‌مانده)" % _fa_digits(remaining_boxes)
				status_banner_3d.modulate = Color(0.95, 0.92, 0.78)
		else:
			status_banner_3d.text = "در انتظار حرکت حریف... (%s خانه باقی‌مانده)" % _fa_digits(remaining_boxes)
			status_banner_3d.modulate = Color(0.75, 0.78, 0.85)


func reset_board() -> void:
	lines_board.fill(0)
	boxes_board.fill(0)
	player1_score = 0
	player2_score = 0
	last_played_line_id = -1
	_clear_line_hover()
	_rebuild_all_3d_pieces_from_state()
	_rebuild_reserve_tray_stacks()
	_sync_hud_scores()
	_refresh_visual_guides()


func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	_clear_line_hover()


func on_new_round(_round_num: int) -> void:
	reset_board()


func cleanup_board() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_clear_line_hover()
	for k in line_bridge_nodes.keys():
		if is_instance_valid(line_bridge_nodes[k]):
			line_bridge_nodes[k].queue_free()
	line_bridge_nodes.clear()
	for k in box_crest_nodes.keys():
		if is_instance_valid(box_crest_nodes[k]):
			box_crest_nodes[k].queue_free()
	box_crest_nodes.clear()
	for p in tray_red_pieces:
		if is_instance_valid(p):
			p.queue_free()
	tray_red_pieces.clear()
	for p in tray_blue_pieces:
		if is_instance_valid(p):
			p.queue_free()
	tray_blue_pieces.clear()
