class_name Mill3D
extends "res://scripts/games/base_game_board.gd"

# Nine Men's Morris / Mill 3D Board (دوز نه‌تایی سه بعدی — Cafe Fekr Royal Tournament Edition)
# Exact 1:1 port of Flutter MillController + Python Backend MillGameClass & MillGameSession.
# Features:
# - Luxury 3D concentric-squares walnut cabinet with inlaid 24K gold rails, dark ebony track channels,
#   central brass rosette medallion, 24 sculpted brass/obsidian node sockets, and side reserve/capture trays.
# - 3D Lathe-Turned Ribbed Checkers Pucks (Imperial Ruby Crimson + 24K Gold for Player 1,
#   Royal Sapphire Blue + Platinum for Player 2) matching Checkers 3D craftsmanship.
# - Full 3-Phase Nine Men's Morris Rules:
#   1. Placement Phase (9 pieces per player: Select_Peace -> Peace_Selected)
#   2. Sliding Movement Phase along connected rails (Swap_Peace -> Peace_Swaped)
#   3. Flying Phase when a player has 3 pieces remaining (can jump to any empty node!)
#   4. Mill Capture Phase when forming 3-in-a-row (Select_Remove_Peace -> Peace_Removed)

const MAX_NODES: int = 24
const TOTAL_PIECES_PER_PLAYER: int = 9

# Concentric Square Radii on the 3D Playing Bed
const R_OUTER: float = 0.44
const R_MID: float = 0.295
const R_INNER: float = 0.15

# Exact 24 Node Coordinates (x, z) matching MillBoardWidget 7-row layout (0..23)
const NODE_COORDS: Array[Vector2] = [
	# Row 0: Outer Top (0, 1, 2)
	Vector2(-R_OUTER, -R_OUTER), Vector2(0.0, -R_OUTER), Vector2(R_OUTER, -R_OUTER),
	# Row 1: Middle Top (3, 4, 5)
	Vector2(-R_MID, -R_MID),     Vector2(0.0, -R_MID),   Vector2(R_MID, -R_MID),
	# Row 2: Inner Top (6, 7, 8)
	Vector2(-R_INNER, -R_INNER), Vector2(0.0, -R_INNER), Vector2(R_INNER, -R_INNER),
	# Row 3: Left & Right Equator (9, 10, 11 | 12, 13, 14)
	Vector2(-R_OUTER, 0.0),      Vector2(-R_MID, 0.0),   Vector2(-R_INNER, 0.0),
	Vector2(R_INNER, 0.0),       Vector2(R_MID, 0.0),    Vector2(R_OUTER, 0.0),
	# Row 4: Inner Bottom (15, 16, 17)
	Vector2(-R_INNER, R_INNER),  Vector2(0.0, R_INNER),  Vector2(R_INNER, R_INNER),
	# Row 5: Middle Bottom (18, 19, 20)
	Vector2(-R_MID, R_MID),      Vector2(0.0, R_MID),    Vector2(R_MID, R_MID),
	# Row 6: Outer Bottom (21, 22, 23)
	Vector2(-R_OUTER, R_OUTER),  Vector2(0.0, R_OUTER),  Vector2(R_OUTER, R_OUTER)
]

# Exact Adjacency Graph (Matches MillGameClass.pieces_neighbors & MillController.neighborsData 1:1)
const NEIGHBORS_DATA: Dictionary = {
	0: [1, 9],
	1: [0, 2, 4],
	2: [1, 14],
	3: [4, 10],
	4: [1, 3, 5, 7],
	5: [4, 13],
	6: [7, 11],
	7: [4, 6, 8],
	8: [7, 12],
	9: [0, 10, 21],
	10: [3, 9, 11, 18],
	11: [6, 10, 15],
	12: [8, 13, 17],
	13: [5, 12, 14, 20],
	14: [2, 13, 23],
	15: [11, 16],
	16: [15, 17, 19],
	17: [12, 16],
	18: [10, 19],
	19: [16, 18, 20, 22],
	20: [13, 19],
	21: [9, 22],
	22: [19, 21, 23],
	23: [14, 22]
}

# Exact 16 Mill Lines (Matches MillGameClass.win_conditions 1:1)
const WIN_CONDITIONS: Array = [
	[0, 1, 2],   [0, 9, 21],   [21, 22, 23], [23, 14, 2],
	[1, 4, 7],   [9, 10, 11],  [22, 19, 16], [14, 13, 12],
	[3, 4, 5],   [3, 10, 18],  [18, 19, 20], [20, 13, 5],
	[6, 7, 8],   [6, 11, 15],  [15, 16, 17], [17, 12, 8]
]

# --- Authoritative Game State (Matches MillController & MillGameClass 1:1) ---
var board_data: Array[int] = [] # 24 ints: 0 (empty), 1 (P1 Red), 2 (P2 Blue)
var player1_peaces: int = 9
var player2_peaces: int = 9
var player1_played_peaces: int = 0
var player2_played_peaces: int = 0
var player1_removed_peaces: int = 0
var player2_removed_peaces: int = 0

var equipped_peace_index: int = -1
var current_remover: int = 0
var let_remove_peace: bool = false

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

# --- 3D Nodes & Caches ---
var node_sockets: Array[Node3D] = []
var pieces_nodes: Dictionary = {} # node_id (0..23) -> Node3D
var reserve_red_nodes: Array[Node3D] = []
var reserve_blue_nodes: Array[Node3D] = []
var captured_red_nodes: Array[Node3D] = []
var captured_blue_nodes: Array[Node3D] = []

var tray_red: Node3D = null
var tray_blue: Node3D = null
var lbl_tray_red: Label3D = null
var lbl_tray_blue: Label3D = null

var active_markers: Array[Node3D] = []
var last_move_markers: Array[Node3D] = []
var mill_beam_nodes: Array[Node3D] = []

# --- Luxury Procedural Materials ---
var mat_ebony_groove: StandardMaterial3D
var mat_gold_rail: StandardMaterial3D
var mat_brass_socket: StandardMaterial3D
var mat_obsidian_well: StandardMaterial3D
var mat_felt_base: StandardMaterial3D
var mat_piece_p1: StandardMaterial3D
var mat_piece_p1_well: StandardMaterial3D
var mat_piece_p2: StandardMaterial3D
var mat_piece_p2_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_marker_place: StandardMaterial3D
var mat_marker_move: StandardMaterial3D
var mat_marker_equip: StandardMaterial3D
var mat_marker_remove: StandardMaterial3D
var mat_last_move: StandardMaterial3D

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
	game_type = GameTypes.MILL
	add_to_group("board")
	_init_materials()
	_build_board_3d()
	_init_board_data()
	_spawn_all_pieces_on_board()
	_sync_side_trays()
	_sync_hud_scores()
	super._ready()

func _init_materials() -> void:
	# 1. Recessed Dark Ebony Track Groove
	mat_ebony_groove = StandardMaterial3D.new()
	mat_ebony_groove.albedo_color = Color(0.11, 0.06, 0.03)
	mat_ebony_groove.metallic = 0.05
	mat_ebony_groove.roughness = 0.42

	# 2. Inlaid 24K Gold Track Rail
	mat_gold_rail = StandardMaterial3D.new()
	mat_gold_rail.albedo_color = Color(0.94, 0.78, 0.28)
	mat_gold_rail.metallic = 0.90
	mat_gold_rail.roughness = 0.24

	# 3. Sculpted Brass Node Bezel Socket
	mat_brass_socket = StandardMaterial3D.new()
	mat_brass_socket.albedo_color = Color(0.92, 0.74, 0.26)
	mat_brass_socket.metallic = 0.92
	mat_brass_socket.roughness = 0.20

	# 4. Recessed Obsidian Node Well
	mat_obsidian_well = StandardMaterial3D.new()
	mat_obsidian_well.albedo_color = Color(0.09, 0.08, 0.10)
	mat_obsidian_well.metallic = 0.12
	mat_obsidian_well.roughness = 0.32
	mat_obsidian_well.clearcoat_enabled = true
	mat_obsidian_well.clearcoat = 0.65

	# 5. Piece Bottom Baize Felt Pad
	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.08, 0.28, 0.14)
	mat_felt_base.roughness = 0.90
	mat_felt_base.metallic = 0.0

	# 6. Player 1 (Red) — Imperial Ruby Crimson Lacquer (Matches Checkers 3D)
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.76, 0.11, 0.15)
	mat_piece_p1.metallic = 0.18
	mat_piece_p1.roughness = 0.22
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 0.92
	mat_piece_p1.clearcoat_roughness = 0.10

	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.56, 0.07, 0.10)
	mat_piece_p1_well.metallic = 0.22
	mat_piece_p1_well.roughness = 0.28
	mat_piece_p1_well.clearcoat_enabled = true
	mat_piece_p1_well.clearcoat = 0.85

	# 7. Player 2 (Blue) — Royal Sapphire Cobalt Lacquer (Matches Checkers 3D)
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.11, 0.36, 0.78)
	mat_piece_p2.metallic = 0.20
	mat_piece_p2.roughness = 0.22
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 0.92
	mat_piece_p2.clearcoat_roughness = 0.10

	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.07, 0.24, 0.58)
	mat_piece_p2_well.metallic = 0.24
	mat_piece_p2_well.roughness = 0.28
	mat_piece_p2_well.clearcoat_enabled = true
	mat_piece_p2_well.clearcoat = 0.85

	# 8. 24K Gold & Brushed Platinum Trim
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.98, 0.82, 0.28)
	mat_gold_trim.metallic = 0.94
	mat_gold_trim.roughness = 0.16

	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.88, 0.93, 1.0)
	mat_platinum_trim.metallic = 0.92
	mat_platinum_trim.roughness = 0.18

	# 9. Interactive Highlights & Markers
	mat_marker_place = StandardMaterial3D.new()
	mat_marker_place.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_place.albedo_color = Color(0.28, 0.95, 0.52, 0.78)
	mat_marker_place.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_marker_move = StandardMaterial3D.new()
	mat_marker_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_move.albedo_color = Color(0.25, 0.96, 0.50, 0.92)
	mat_marker_move.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_marker_equip = StandardMaterial3D.new()
	mat_marker_equip.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_equip.albedo_color = Color(0.94, 0.72, 0.08, 0.96)
	mat_marker_equip.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_marker_remove = StandardMaterial3D.new()
	mat_marker_remove.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_marker_remove.albedo_color = Color(1.0, 0.26, 0.22, 0.95)
	mat_marker_remove.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mat_last_move = StandardMaterial3D.new()
	mat_last_move.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_last_move.albedo_color = Color(1.0, 0.88, 0.28, 0.65)
	mat_last_move.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# --- 3D Concentric Nine Men's Morris Board Construction ---

func _build_board_3d() -> void:
	# 1. Build 3 Concentric Squares (Outer, Middle, Inner)
	for r in [R_OUTER, R_MID, R_INNER]:
		var len_side = r * 2.0
		# Top & Bottom horizontal tracks
		_add_track_segment(Vector3(0.0, 0.048, -r), Vector3(len_side, 1.0, 1.0), true)
		_add_track_segment(Vector3(0.0, 0.048, r), Vector3(len_side, 1.0, 1.0), true)
		# Left & Right vertical tracks
		_add_track_segment(Vector3(-r, 0.048, 0.0), Vector3(1.0, 1.0, len_side), false)
		_add_track_segment(Vector3(r, 0.048, 0.0), Vector3(1.0, 1.0, len_side), false)

	# 2. Build 4 Cross Spokes connecting Outer -> Middle -> Inner midpoints
	var spoke_len = R_OUTER - R_INNER # 0.29m
	var spoke_mid = (R_OUTER + R_INNER) * 0.5 # 0.295m
	# North spoke (1 - 4 - 7)
	_add_track_segment(Vector3(0.0, 0.048, -spoke_mid), Vector3(1.0, 1.0, spoke_len), false)
	# South spoke (16 - 19 - 22)
	_add_track_segment(Vector3(0.0, 0.048, spoke_mid), Vector3(1.0, 1.0, spoke_len), false)
	# West spoke (9 - 10 - 11)
	_add_track_segment(Vector3(-spoke_mid, 0.048, 0.0), Vector3(spoke_len, 1.0, 1.0), true)
	# East spoke (12 - 13 - 14)
	_add_track_segment(Vector3(spoke_mid, 0.048, 0.0), Vector3(spoke_len, 1.0, 1.0), true)

	# 3. Build Decorative Center Court Medallion at (0, 0)
	_build_center_medallion()

	# 4. Build 24 Brass & Obsidian Node Sockets (0..23)
	node_sockets.resize(MAX_NODES)
	for i in range(MAX_NODES):
		var pt = NODE_COORDS[i]
		var sock = _build_single_node_socket(i, Vector3(pt.x, 0.048, pt.y))
		add_child(sock)
		node_sockets[i] = sock

	# 5. Build Left & Right Mahogany Side Trays (Reserve + Captured Graveyard)
	_build_side_trays()

func _add_track_segment(pos: Vector3, scale_vec: Vector3, is_horizontal: bool) -> void:
	# Recessed Ebony Channel
	var groove = MeshInstance3D.new()
	var g_box = BoxMesh.new()
	if is_horizontal:
		g_box.size = Vector3(scale_vec.x + 0.016, 0.003, 0.018)
	else:
		g_box.size = Vector3(0.018, 0.003, scale_vec.z + 0.016)
	g_box.material = mat_ebony_groove
	groove.mesh = g_box
	groove.position = pos
	add_child(groove)

	# Raised 24K Gold Rail Bar
	var rail = MeshInstance3D.new()
	var r_box = BoxMesh.new()
	if is_horizontal:
		r_box.size = Vector3(scale_vec.x + 0.006, 0.005, 0.0075)
	else:
		r_box.size = Vector3(0.0075, 0.005, scale_vec.z + 0.006)
	r_box.material = mat_gold_rail
	rail.mesh = r_box
	rail.position = pos + Vector3(0.0, 0.002, 0.0)
	add_child(rail)

func _build_center_medallion() -> void:
	var med_root = Node3D.new()
	med_root.name = "CenterCourtMedallion"
	med_root.position = Vector3(0.0, 0.048, 0.0)
	add_child(med_root)

	var outer_ring = MeshInstance3D.new()
	var torus_out = TorusMesh.new()
	torus_out.inner_radius = 0.052
	torus_out.outer_radius = 0.060
	torus_out.rings = 32
	torus_out.ring_segments = 20
	torus_out.material = mat_brass_socket
	outer_ring.mesh = torus_out
	med_root.add_child(outer_ring)

	var plate = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.052
	cyl.bottom_radius = 0.052
	cyl.height = 0.003
	cyl.radial_segments = 32
	cyl.material = mat_ebony_groove
	plate.mesh = cyl
	med_root.add_child(plate)

	var boss = MeshInstance3D.new()
	var cyl_boss = CylinderMesh.new()
	cyl_boss.top_radius = 0.018
	cyl_boss.bottom_radius = 0.022
	cyl_boss.height = 0.005
	cyl_boss.radial_segments = 24
	cyl_boss.material = mat_brass_socket
	boss.mesh = cyl_boss
	boss.position.y = 0.002
	med_root.add_child(boss)

func _build_single_node_socket(idx: int, pos: Vector3) -> Node3D:
	var sock = Node3D.new()
	sock.name = "NodeSocket_%d" % idx
	sock.position = pos

	# Outer Sculpted Brass Bezel Ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.038
	torus.outer_radius = 0.046
	torus.rings = 28
	torus.ring_segments = 20
	torus.material = mat_brass_socket
	ring.mesh = torus
	ring.position.y = 0.002
	sock.add_child(ring)

	# Recessed Dark Obsidian Well
	var well = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.039
	cyl.bottom_radius = 0.039
	cyl.height = 0.0035
	cyl.radial_segments = 32
	cyl.material = mat_obsidian_well
	well.mesh = cyl
	well.position.y = 0.0015
	sock.add_child(well)

	# Center Brass Pin Dot
	var pin = MeshInstance3D.new()
	var cyl_pin = CylinderMesh.new()
	cyl_pin.top_radius = 0.007
	cyl_pin.bottom_radius = 0.007
	cyl_pin.height = 0.0045
	cyl_pin.radial_segments = 16
	cyl_pin.material = mat_brass_socket
	pin.mesh = cyl_pin
	pin.position.y = 0.002
	sock.add_child(pin)

	return sock

# --- Side Trays (Reserve Unplaced Pieces + Captured Pieces) ---

func _build_side_trays() -> void:
	if tray_red and is_instance_valid(tray_red):
		tray_red.queue_free()
	if tray_blue and is_instance_valid(tray_blue):
		tray_blue.queue_free()

	tray_red = _create_single_tray_mesh("MillTrayRed", Color(0.45, 0.08, 0.10), "مهره قرمز")
	tray_red.position = Vector3(-0.765, 0.012, 0.0)
	add_child(tray_red)
	lbl_tray_red = tray_red.get_node_or_null("TrayLabel") as Label3D
	if lbl_tray_red:
		lbl_tray_red.position.x = -0.080

	tray_blue = _create_single_tray_mesh("MillTrayBlue", Color(0.08, 0.22, 0.48), "مهره آبی")
	tray_blue.position = Vector3(0.765, 0.012, 0.0)
	add_child(tray_blue)
	lbl_tray_blue = tray_blue.get_node_or_null("TrayLabel") as Label3D
	if lbl_tray_blue:
		lbl_tray_blue.position.x = 0.080

func _create_single_tray_mesh(tray_name: String, felt_color: Color, label_fa: String) -> Node3D:
	var root = Node3D.new()
	root.name = tray_name

	const TRAY_W: float = 0.178
	const TRAY_L: float = 0.98
	const TRAY_H: float = 0.022
	const WALL_T: float = 0.015
	const WALL_H: float = 0.015

	var mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.20, 0.11, 0.06)
	mat_wood.metallic = 0.04
	mat_wood.roughness = 0.36
	mat_wood.clearcoat_enabled = true
	mat_wood.clearcoat = 0.55

	var base_inst = MeshInstance3D.new()
	var base_box = BoxMesh.new()
	base_box.size = Vector3(TRAY_W, TRAY_H, TRAY_L)
	base_box.material = mat_wood
	base_inst.mesh = base_box
	root.add_child(base_inst)

	var mat_felt = StandardMaterial3D.new()
	mat_felt.albedo_color = felt_color
	mat_felt.roughness = 0.88

	var felt_inst = MeshInstance3D.new()
	var felt_box = BoxMesh.new()
	felt_box.size = Vector3(TRAY_W - WALL_T * 1.8, 0.004, TRAY_L - WALL_T * 1.8)
	felt_box.material = mat_felt
	felt_inst.mesh = felt_box
	felt_inst.position = Vector3(0.0, TRAY_H * 0.5 + 0.001, 0.0)
	root.add_child(felt_inst)

	var wall_long_mesh = BoxMesh.new()
	wall_long_mesh.size = Vector3(WALL_T, WALL_H, TRAY_L)
	wall_long_mesh.material = mat_wood
	for sx in [-1.0, 1.0]:
		var w_side = MeshInstance3D.new()
		w_side.mesh = wall_long_mesh
		w_side.position = Vector3(sx * (TRAY_W * 0.5 - WALL_T * 0.5), TRAY_H * 0.5 + WALL_H * 0.5 - 0.002, 0.0)
		root.add_child(w_side)

	var wall_short_mesh = BoxMesh.new()
	wall_short_mesh.size = Vector3(TRAY_W, WALL_H, WALL_T)
	wall_short_mesh.material = mat_wood
	for sz in [-1.0, 1.0]:
		var w_end = MeshInstance3D.new()
		w_end.mesh = wall_short_mesh
		w_end.position = Vector3(0.0, TRAY_H * 0.5 + WALL_H * 0.5 - 0.002, sz * (TRAY_L * 0.5 - WALL_T * 0.5))
		root.add_child(w_end)

	# Horizontal Brass Divider separating Reserve (Upper) from Captured (Lower)
	var div_h_mesh = BoxMesh.new()
	div_h_mesh.size = Vector3(TRAY_W - WALL_T * 1.6, 0.008, 0.008)
	div_h_mesh.material = mat_brass_socket
	var div_h = MeshInstance3D.new()
	div_h.mesh = div_h_mesh
	div_h.position = Vector3(0.0, TRAY_H * 0.5 + 0.005, 0.02)
	root.add_child(div_h)

	var corner_cap_mesh = BoxMesh.new()
	corner_cap_mesh.size = Vector3(0.026, WALL_H + 0.006, 0.026)
	corner_cap_mesh.material = mat_brass_socket
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cap = MeshInstance3D.new()
			cap.mesh = corner_cap_mesh
			cap.position = Vector3(sx * (TRAY_W * 0.5 - 0.008), TRAY_H * 0.5 + WALL_H * 0.5, sz * (TRAY_L * 0.5 - 0.008))
			root.add_child(cap)

	var lbl = Label3D.new()
	lbl.name = "TrayLabel"
	if _font_hekayat:
		lbl.font = _font_hekayat
	lbl.text = "%s: ۹" % label_fa
	lbl.font_size = 24
	lbl.pixel_size = 0.00065
	lbl.modulate = Color(0.98, 0.88, 0.45, 0.98)
	lbl.outline_modulate = Color(0.10, 0.06, 0.03, 0.95)
	lbl.outline_size = 6
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.0, 0.032, 0.0)
	root.add_child(lbl)

	return root

func _get_reserve_slot_pos(gamer_id: int, slot_idx: int) -> Vector3:
	var tray_x = -0.765 if gamer_id == 1 else 0.765
	var col = slot_idx % 2
	var row = slot_idx / 2
	var x_off = -0.034 if col == 0 else 0.034
	var z_off = -0.40 + float(row) * 0.095
	return Vector3(tray_x + x_off, 0.024, z_off)

func _get_captured_slot_pos(captured_gamer_id: int, slot_idx: int) -> Vector3:
	var tray_x = -0.765 if captured_gamer_id == 1 else 0.765
	var col = slot_idx % 2
	var row = slot_idx / 2
	var x_off = -0.034 if col == 0 else 0.034
	var z_off = 0.08 + float(row) * 0.095
	return Vector3(tray_x + x_off, 0.024, z_off)

func _sync_side_trays() -> void:
	for p in reserve_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_red_nodes.clear()
	for p in reserve_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_blue_nodes.clear()
	for p in captured_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_red_nodes.clear()
	for p in captured_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_blue_nodes.clear()

	var p1_unplaced = clampi(player1_peaces - player1_played_peaces, 0, 9)
	var p2_unplaced = clampi(player2_peaces - player2_played_peaces, 0, 9)

	for i in range(p1_unplaced):
		var n1 = _build_3d_checker_piece(1)
		n1.scale = Vector3(0.64, 0.64, 0.64)
		n1.position = _get_reserve_slot_pos(1, i)
		add_child(n1)
		reserve_red_nodes.append(n1)

	for i in range(p2_unplaced):
		var n2 = _build_3d_checker_piece(2)
		n2.scale = Vector3(0.64, 0.64, 0.64)
		n2.position = _get_reserve_slot_pos(2, i)
		add_child(n2)
		reserve_blue_nodes.append(n2)

	for i in range(clampi(player1_removed_peaces, 0, 9)):
		var c1 = _build_3d_checker_piece(1)
		c1.scale = Vector3(0.58, 0.58, 0.58)
		c1.position = _get_captured_slot_pos(1, i)
		add_child(c1)
		captured_red_nodes.append(c1)

	for i in range(clampi(player2_removed_peaces, 0, 9)):
		var c2 = _build_3d_checker_piece(2)
		c2.scale = Vector3(0.58, 0.58, 0.58)
		c2.position = _get_captured_slot_pos(2, i)
		add_child(c2)
		captured_blue_nodes.append(c2)

	_update_tray_labels()

func _update_tray_labels() -> void:
	var p1_unplaced = max(0, player1_peaces - player1_played_peaces)
	var p2_unplaced = max(0, player2_peaces - player2_played_peaces)
	if is_instance_valid(lbl_tray_red):
		lbl_tray_red.text = "ذخیره قرمز: %s" % _fa_digits(p1_unplaced)
	if is_instance_valid(lbl_tray_blue):
		lbl_tray_blue.text = "ذخیره آبی: %s" % _fa_digits(p2_unplaced)

func _sync_hud_scores() -> void:
	# In MillPage (Flutter):
	# player1Number1 = controller.player2RemovedPeaces.value (enemy pieces captured by P1)
	# player2Number1 = controller.player1RemovedPeaces.value (enemy pieces captured by P2)
	var p1_captured_enemy = clampi(player2_removed_peaces, 0, 9)
	var p2_captured_enemy = clampi(player1_removed_peaces, 0, 9)
	GameManager.p1_score = p1_captured_enemy
	GameManager.p2_score = p2_captured_enemy
	var main_node = get_tree().current_scene
	if main_node and "base_game_hud" in main_node and is_instance_valid(main_node.base_game_hud):
		main_node.base_game_hud.update_scores(p1_captured_enemy, p2_captured_enemy)

# --- 3D Lathe-Turned Ribbed Checkers Piece Builder (1:1 with Checkers3D) ---

func _build_3d_checker_piece(gamer_id: int) -> Node3D:
	var root = Node3D.new()
	root.set_meta("gamer_id", gamer_id)

	var mat_main = mat_piece_p1 if gamer_id == 1 else mat_piece_p2
	var mat_well = mat_piece_p1_well if gamer_id == 1 else mat_piece_p2_well
	var mat_trim = mat_gold_trim if gamer_id == 1 else mat_platinum_trim

	# 1. Weighted Velvet Green Felt Base Pad
	var felt_pad = MeshInstance3D.new()
	var cyl_felt = CylinderMesh.new()
	cyl_felt.top_radius = 0.044
	cyl_felt.bottom_radius = 0.044
	cyl_felt.height = 0.002
	cyl_felt.radial_segments = 36
	felt_pad.mesh = cyl_felt
	felt_pad.material_override = mat_felt_base
	felt_pad.position.y = 0.001
	root.add_child(felt_pad)

	# 2. Lower Beveled Gold/Platinum Plinth Ring
	var lower_ring = MeshInstance3D.new()
	var torus_low = TorusMesh.new()
	torus_low.inner_radius = 0.040
	torus_low.outer_radius = 0.0455
	torus_low.rings = 32
	torus_low.ring_segments = 24
	lower_ring.mesh = torus_low
	lower_ring.material_override = mat_trim
	lower_ring.position.y = 0.005
	root.add_child(lower_ring)

	# 3. Main Cylindrical Puck Body
	var body = MeshInstance3D.new()
	var cyl_body = CylinderMesh.new()
	cyl_body.top_radius = 0.0435
	cyl_body.bottom_radius = 0.0445
	cyl_body.height = 0.017
	cyl_body.radial_segments = 48
	body.mesh = cyl_body
	body.material_override = mat_main
	body.position.y = 0.011
	root.add_child(body)

	# 4. Recessed Inner Well (Classic Checkers Dish)
	var dish = MeshInstance3D.new()
	var cyl_dish = CylinderMesh.new()
	cyl_dish.top_radius = 0.035
	cyl_dish.bottom_radius = 0.035
	cyl_dish.height = 0.002
	cyl_dish.radial_segments = 36
	dish.mesh = cyl_dish
	dish.material_override = mat_well
	dish.position.y = 0.0192
	root.add_child(dish)

	# 5. Raised Outer Gripping Rim (Torus)
	var outer_rim = MeshInstance3D.new()
	var torus_rim = TorusMesh.new()
	torus_rim.inner_radius = 0.0345
	torus_rim.outer_radius = 0.044
	torus_rim.rings = 36
	torus_rim.ring_segments = 24
	outer_rim.mesh = torus_rim
	outer_rim.material_override = mat_main
	outer_rim.position.y = 0.0192
	root.add_child(outer_rim)

	# 6. 16 Radial Tactile Grip Ridges around Outer Rim
	var notch_mesh = BoxMesh.new()
	notch_mesh.size = Vector3(0.0032, 0.0035, 0.0075)
	for i in range(16):
		var angle = (float(i) / 16.0) * TAU
		var notch = MeshInstance3D.new()
		notch.mesh = notch_mesh
		notch.material_override = mat_main
		var r_pos = 0.039
		notch.position = Vector3(r_pos * cos(angle), 0.0215, r_pos * sin(angle))
		notch.rotation.y = -angle + PI * 0.5
		root.add_child(notch)

	# 7. Concentric 24K Gold / Platinum Inlay Ring inside Dish
	var mid_gold_ring = MeshInstance3D.new()
	var torus_mid = TorusMesh.new()
	torus_mid.inner_radius = 0.0225
	torus_mid.outer_radius = 0.0268
	torus_mid.rings = 32
	torus_mid.ring_segments = 20
	mid_gold_ring.mesh = torus_mid
	mid_gold_ring.material_override = mat_trim
	mid_gold_ring.position.y = 0.020
	root.add_child(mid_gold_ring)

	# 8. Inner Concentric Lacquer Ridge
	var inner_ridge = MeshInstance3D.new()
	var torus_in = TorusMesh.new()
	torus_in.inner_radius = 0.012
	torus_in.outer_radius = 0.018
	torus_in.rings = 28
	torus_in.ring_segments = 20
	inner_ridge.mesh = torus_in
	inner_ridge.material_override = mat_main
	inner_ridge.position.y = 0.0202
	root.add_child(inner_ridge)

	# 9. Center Medallion Boss
	var boss = MeshInstance3D.new()
	var cyl_boss = CylinderMesh.new()
	cyl_boss.top_radius = 0.0085
	cyl_boss.bottom_radius = 0.0095
	cyl_boss.height = 0.003
	cyl_boss.radial_segments = 24
	boss.mesh = cyl_boss
	boss.material_override = mat_trim
	boss.position.y = 0.0205
	root.add_child(boss)

	return root

# --- Board State & Piece Spawning ---

func _init_board_data() -> void:
	board_data.clear()
	for _i in range(MAX_NODES):
		board_data.append(0)
	player1_peaces = 9
	player2_peaces = 9
	player1_played_peaces = 0
	player2_played_peaces = 0
	player1_removed_peaces = 0
	player2_removed_peaces = 0
	equipped_peace_index = -1
	current_remover = 0
	let_remove_peace = false

func _spawn_all_pieces_on_board() -> void:
	for p in pieces_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	pieces_nodes.clear()

	for i in range(MAX_NODES):
		var g_id = board_data[i]
		if g_id != 0:
			_spawn_piece_at_node(i, g_id)

func _spawn_piece_at_node(node_id: int, gamer_id: int) -> Node3D:
	var sock = node_sockets[node_id]
	var p_node = _build_3d_checker_piece(gamer_id)
	p_node.name = "MillPiece_%d_P%d" % [node_id, gamer_id]
	p_node.set_meta("node_id", node_id)
	p_node.set_meta("gamer_id", gamer_id)
	p_node.position = Vector3(sock.position.x, 0.050, sock.position.z)
	add_child(p_node)
	pieces_nodes[node_id] = p_node
	return p_node

# --- Raycast Input Handling (Single Source of Input per GAME_SCENE_RULES 4.3) ---

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_game_active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
					var now = Time.get_ticks_msec() / 1000.0
					if now - last_click_time >= 0.15:
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
					var now = Time.get_ticks_msec() / 1000.0
					if now - last_click_time >= 0.15:
						_raycast_board_click(event.position)

func _raycast_board_click(screen_pos: Vector2) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_normal = cam.project_ray_normal(screen_pos)
	var board_y = global_position.y + 0.052
	if abs(ray_normal.y) < 0.0001:
		return
	var t = (board_y - ray_origin.y) / ray_normal.y
	if t < 0.0:
		return
	var hit_world = ray_origin + ray_normal * t
	var local_hit = to_local(hit_world)
	var hit_2d = Vector2(local_hit.x, local_hit.z)

	# Find nearest of the 24 node sockets within generous tap radius (0.078m)
	var best_idx: int = -1
	var best_dist: float = 0.078
	for i in range(MAX_NODES):
		var d = hit_2d.distance_to(NODE_COORDS[i])
		if d < best_dist:
			best_dist = d
			best_idx = i

	if best_idx != -1:
		_on_node_clicked(best_idx)

# --- Exact Mill Rule Helpers (Ported 1:1 from MillController & MillGameClass) ---

func check_all_of_my_peaces_placed(gamer_id: int = -1) -> bool:
	var gid = gamer_id if gamer_id != -1 else my_player_index
	if gid == 1:
		return player1_played_peaces >= player1_peaces
	else:
		return player2_played_peaces >= player2_peaces

func get_remaining_peaces_count(gamer_id: int) -> int:
	if gamer_id == 1:
		return player1_peaces - player1_removed_peaces
	else:
		return player2_peaces - player2_removed_peaces

func check_peace_is_empty(node_id: int) -> bool:
	if node_id < 0 or node_id >= board_data.size():
		return false
	return board_data[node_id] == 0

func get_enemy_peaces_indexes(gamer_id: int = -1) -> Array[int]:
	var gid = gamer_id if gamer_id != -1 else my_player_index
	var res: Array[int] = []
	for i in range(MAX_NODES):
		if board_data[i] != 0 and board_data[i] != gid:
			res.append(i)
	return res

func get_valid_swap_targets(source_id: int, gamer_id: int) -> Array[int]:
	var targets: Array[int] = []
	if source_id < 0 or source_id >= MAX_NODES:
		return targets
	if board_data[source_id] != gamer_id:
		return targets

	var remaining = get_remaining_peaces_count(gamer_id)
	if remaining <= 3:
		# Flying Rule: When player has 3 pieces left, can jump to ANY empty node!
		for i in range(MAX_NODES):
			if board_data[i] == 0:
				targets.append(i)
	else:
		# Normal Sliding Rule: Can slide to any empty adjacent neighbor
		var nbrs: Array = NEIGHBORS_DATA.get(source_id, [])
		for n_id in nbrs:
			if board_data[int(n_id)] == 0:
				targets.append(int(n_id))
	return targets

func get_completed_mills_at(node_id: int, gamer_id: int) -> Array:
	var matched_lines: Array = []
	for line in WIN_CONDITIONS:
		if (line as Array).has(node_id):
			var all_match = true
			for idx in line:
				if board_data[int(idx)] != gamer_id:
					all_match = false
					break
			if all_match:
				matched_lines.append(line)
	return matched_lines

# --- Interactive Click & 3-Phase Dispatch (Matches MillController.onEachButtonTap 1:1) ---

func _on_node_clicked(node_id: int) -> void:
	if not GameManager.is_game_active:
		show_hint("لطفاً تا شروع مسابقه صبر کنید...")
		AudioManager.play_sound("miss_turn")
		return
	if is_board_locked:
		return
	if not is_my_turn and not let_remove_peace:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.play_sound("miss_turn")
		return

	var now = Time.get_ticks_msec() / 1000.0
	var current_frame = Engine.get_process_frames()
	if current_frame == _last_click_frame or (now - last_click_time < 0.04):
		return
	_last_click_frame = current_frame
	last_click_time = now

	var occupant = board_data[node_id]

	# CASE 1: Mill Capture Phase (let_remove_peace == true)
	if let_remove_peace:
		if occupant == 0 or occupant == my_player_index:
			show_hint("یک مهره از حریف را برای حذف انتخاب کنید!")
			AudioManager.play_sound("miss_turn")
			return

		let_remove_peace = false
		set_board_locked(true)
		_clear_markers()
		AudioManager.play_sound("remove_peace")
		ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.35, 0.30))
		send_move(Commands.Select_Remove_Peace, node_id)
		return

	# CASE 2: Movement / Flying Phase (all 9 pieces placed)
	if check_all_of_my_peaces_placed(my_player_index):
		if equipped_peace_index != -1:
			if equipped_peace_index == node_id:
				release_peace()
				AudioManager.play_sound("tap")
				return
			elif occupant == my_player_index:
				release_peace()
				equip_peace(node_id)
				return
			else:
				if occupant != 0:
					show_hint("نمی‌توانید مهره حریف را جابه‌جا کنید!")
					AudioManager.play_sound("miss_turn")
					return
				var valid_targets = get_valid_swap_targets(equipped_peace_index, my_player_index)
				if not valid_targets.has(node_id):
					show_hint("فقط به خانه‌های متصل خالی می‌توانید حرکت کنید!")
					AudioManager.play_sound("miss_turn")
					return

				var src_id = equipped_peace_index
				release_peace()
				set_board_locked(true)
				is_my_turn = false
				AudioManager.play_sound("move_peace")
				ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
				send_move(Commands.Swap_Peace, {
					"source": src_id,
					"target": node_id
				})
				return
		else:
			if occupant == my_player_index:
				equip_peace(node_id)
			elif occupant != 0:
				show_hint("این مهره متعلق به شما نیست!")
				AudioManager.play_sound("miss_turn")
			else:
				show_hint("ابتدا یکی از مهره‌های خود را برای حرکت انتخاب کنید.")
				AudioManager.play_sound("miss_turn")
			return

	# CASE 3: Placement Phase (player has unplaced pieces in reserve)
	else:
		if occupant != 0:
			show_hint("این نقطه قبلاً پر شده است؛ نقطه دیگری انتخاب کنید.")
			AudioManager.play_sound("miss_turn")
			return

		set_board_locked(true)
		is_my_turn = false
		_clear_markers()
		AudioManager.play_sound("tap")
		ActionVFXManager.spawn_ui_click_burst(get_viewport().get_mouse_position(), Color(1.0, 0.85, 0.35))
		send_move(Commands.Select_Peace, node_id)

func equip_peace(node_id: int) -> void:
	if board_data[node_id] != my_player_index:
		return
	var valid_targets = get_valid_swap_targets(node_id, my_player_index)
	if valid_targets.is_empty():
		show_hint("این مهره راه حرکتی ندارد!")
		AudioManager.play_sound("miss_turn")
		return

	equipped_peace_index = node_id
	AudioManager.play_sound("tap")

	if pieces_nodes.has(node_id) and is_instance_valid(pieces_nodes[node_id]):
		var p_node = pieces_nodes[node_id]
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "position:y", 0.050 + 0.026, 0.16)

	_clear_markers()
	_spawn_equipped_aura(node_id)
	for tgt_id in valid_targets:
		_spawn_move_target_marker(tgt_id)

func release_peace() -> void:
	if equipped_peace_index != -1:
		if pieces_nodes.has(equipped_peace_index) and is_instance_valid(pieces_nodes[equipped_peace_index]):
			var p_node = pieces_nodes[equipped_peace_index]
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(p_node, "position:y", 0.050, 0.12)
	equipped_peace_index = -1
	_clear_markers()

# --- Visual Markers & Mill Line Beams ---

func _refresh_turn_markers() -> void:
	_clear_markers()
	if not GameManager.is_game_active:
		return

	if let_remove_peace:
		for enemy_idx in get_enemy_peaces_indexes(my_player_index):
			_spawn_removable_enemy_marker(enemy_idx)
		return

	if is_my_turn and not check_all_of_my_peaces_placed(my_player_index):
		# Placement Phase: show subtle target rings on all empty sockets
		for i in range(MAX_NODES):
			if board_data[i] == 0:
				_spawn_placement_hint_marker(i)

func _spawn_placement_hint_marker(node_id: int) -> void:
	var sock = node_sockets[node_id]
	var marker = Node3D.new()
	marker.position = Vector3(sock.position.x, 0.053, sock.position.z)

	var dot = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 0.003
	cyl.radial_segments = 20
	cyl.material = mat_marker_place
	dot.mesh = cyl
	marker.add_child(dot)

	add_child(marker)
	active_markers.append(marker)

func _spawn_equipped_aura(node_id: int) -> void:
	var sock = node_sockets[node_id]
	var aura = Node3D.new()
	aura.position = Vector3(sock.position.x, 0.053, sock.position.z)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.044
	torus.outer_radius = 0.054
	torus.rings = 28
	torus.ring_segments = 20
	torus.material = mat_marker_equip
	ring.mesh = torus
	aura.add_child(ring)

	add_child(aura)
	active_markers.append(aura)

	var tw = aura.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(aura, "scale", Vector3(1.12, 1.0, 1.12), 0.55)
	tw.tween_property(aura, "scale", Vector3(0.94, 1.0, 0.94), 0.55)

func _spawn_move_target_marker(node_id: int) -> void:
	var sock = node_sockets[node_id]
	var marker = Node3D.new()
	marker.position = Vector3(sock.position.x, 0.054, sock.position.z)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.026
	torus.outer_radius = 0.036
	torus.rings = 24
	torus.ring_segments = 20
	torus.material = mat_marker_move
	ring.mesh = torus
	marker.add_child(ring)

	var dot = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = 0.004
	cyl.material = mat_marker_move
	dot.mesh = cyl
	marker.add_child(dot)

	add_child(marker)
	active_markers.append(marker)

	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", Vector3(1.16, 1.0, 1.16), 0.60)
	tw.tween_property(marker, "scale", Vector3(0.90, 1.0, 0.90), 0.60)

func _spawn_removable_enemy_marker(node_id: int) -> void:
	var sock = node_sockets[node_id]
	var marker = Node3D.new()
	marker.position = Vector3(sock.position.x, 0.082, sock.position.z)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.036
	torus.outer_radius = 0.048
	torus.rings = 28
	torus.ring_segments = 20
	torus.material = mat_marker_remove
	ring.mesh = torus
	marker.add_child(ring)

	var inner_dot = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.014
	cyl.bottom_radius = 0.014
	cyl.height = 0.004
	cyl.material = mat_marker_remove
	inner_dot.mesh = cyl
	marker.add_child(inner_dot)

	add_child(marker)
	active_markers.append(marker)

	var tw = marker.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(marker, "scale", Vector3(1.18, 1.0, 1.18), 0.45)
	tw.tween_property(marker, "scale", Vector3(0.92, 1.0, 0.92), 0.45)

func _spawn_mill_beam_vfx(lines: Array, gamer_id: int) -> void:
	for b in mill_beam_nodes:
		if is_instance_valid(b):
			b.queue_free()
	mill_beam_nodes.clear()

	for line in lines:
		var n0 = int(line[0])
		var n2 = int(line[2])
		var p0 = NODE_COORDS[n0]
		var p2 = NODE_COORDS[n2]
		var mid = (p0 + p2) * 0.5
		var dist = p0.distance_to(p2)
		var is_horiz = abs(p0.y - p2.y) < 0.01

		var beam_mat = StandardMaterial3D.new()
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.92) if gamer_id == 1 else Color(0.38, 0.86, 1.0, 0.92)

		var beam = MeshInstance3D.new()
		var box = BoxMesh.new()
		if is_horiz:
			box.size = Vector3(dist + 0.06, 0.008, 0.022)
		else:
			box.size = Vector3(0.022, 0.008, dist + 0.06)
		box.material = beam_mat
		beam.mesh = box
		beam.position = Vector3(mid.x, 0.056, mid.y)
		add_child(beam)
		mill_beam_nodes.append(beam)

func _clear_mill_beams() -> void:
	for b in mill_beam_nodes:
		if is_instance_valid(b):
			b.queue_free()
	mill_beam_nodes.clear()

func _update_last_move_highlight(node_id: int) -> void:
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()

	if node_id >= 0 and node_id < node_sockets.size():
		var sock = node_sockets[node_id]
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.045
		torus.outer_radius = 0.053
		torus.rings = 28
		torus.ring_segments = 20
		torus.material = mat_last_move
		ring.mesh = torus
		ring.position = Vector3(sock.position.x, 0.052, sock.position.z)
		add_child(ring)
		last_move_markers.append(ring)

func _clear_markers() -> void:
	for m in active_markers:
		if is_instance_valid(m):
			m.queue_free()
	active_markers.clear()

# --- Server Command Hooks (1:1 with MillController & MillGameSession) ---

func on_turn_changed(_turn: int, is_me: bool) -> void:
	my_player_index = GameManager.my_player_index
	current_remover = 0
	let_remove_peace = false
	release_peace()
	_clear_mill_beams()
	if is_me:
		_refresh_turn_markers()

func on_piece_selected(user_id: int, target_peace: int, _extra: Dictionary = {}) -> void:
	if target_peace < 0 or target_peace >= MAX_NODES:
		return
	var gamer_id = user_id if user_id > 0 else current_turn

	board_data[target_peace] = gamer_id
	if gamer_id == 1:
		player1_played_peaces = min(player1_peaces, player1_played_peaces + 1)
	else:
		player2_played_peaces = min(player2_peaces, player2_played_peaces + 1)

	# Consume one reserve piece from player's side tray and fly it onto the node socket
	var start_pos: Vector3
	var res_arr = reserve_red_nodes if gamer_id == 1 else reserve_blue_nodes
	if not res_arr.is_empty():
		var r_node = res_arr.pop_back()
		if is_instance_valid(r_node):
			start_pos = r_node.position
			r_node.queue_free()
		else:
			start_pos = Vector3(-0.765 if gamer_id == 1 else 0.765, 0.16, 0.0)
	else:
		start_pos = Vector3(-0.765 if gamer_id == 1 else 0.765, 0.16, 0.0)
	_update_tray_labels()

	if pieces_nodes.has(target_peace) and is_instance_valid(pieces_nodes[target_peace]):
		pieces_nodes[target_peace].queue_free()
		pieces_nodes.erase(target_peace)

	var p_node = _spawn_piece_at_node(target_peace, gamer_id)
	var final_pos = p_node.position
	p_node.position = start_pos
	p_node.scale = Vector3(0.68, 0.68, 0.68)

	var mid_pos = (start_pos + final_pos) * 0.5 + Vector3(0.0, 0.18, 0.0)
	var tw = create_tween()
	tw.tween_property(p_node, "scale", Vector3.ONE, 0.28)
	tw.parallel().tween_property(p_node, "position", mid_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(p_node, "position", final_pos, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		AudioManager.play_sound("add_peace")
		ActionVFXManager.spawn_piece_impact_vfx(self, final_pos, gamer_id)
	)

	_update_last_move_highlight(target_peace)

	var mills = get_completed_mills_at(target_peace, gamer_id)
	if not mills.is_empty():
		_spawn_mill_beam_vfx(mills, gamer_id)

func on_piece_swapped(data: Dictionary) -> void:
	var src_id = int(data.get("source_peace", data.get("source", -1)))
	var tgt_id = int(data.get("target_peace", data.get("target", -1)))
	var gamer_id = int(data.get("user", data.get("gamer_id", current_turn)))
	if src_id < 0 or src_id >= MAX_NODES or tgt_id < 0 or tgt_id >= MAX_NODES:
		return

	board_data[src_id] = 0
	board_data[tgt_id] = gamer_id

	var moving_node: Node3D = null
	if pieces_nodes.has(src_id) and is_instance_valid(pieces_nodes[src_id]):
		moving_node = pieces_nodes[src_id]
		pieces_nodes.erase(src_id)
	else:
		moving_node = _spawn_piece_at_node(src_id, gamer_id)
		pieces_nodes.erase(src_id)

	if pieces_nodes.has(tgt_id) and is_instance_valid(pieces_nodes[tgt_id]):
		pieces_nodes[tgt_id].queue_free()

	pieces_nodes[tgt_id] = moving_node
	moving_node.set_meta("node_id", tgt_id)

	var tgt_sock = node_sockets[tgt_id]
	var final_pos = Vector3(tgt_sock.position.x, 0.050, tgt_sock.position.z)
	var start_pos = moving_node.position
	var is_flying = not (NEIGHBORS_DATA.get(src_id, []) as Array).has(tgt_id)
	var arc_h = 0.15 if is_flying else 0.065
	var mid_pos = (start_pos + final_pos) * 0.5 + Vector3(0.0, arc_h, 0.0)

	var tw = create_tween()
	tw.tween_property(moving_node, "position", mid_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(moving_node, "position", final_pos, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		AudioManager.play_sound("move_peace")
		ActionVFXManager.spawn_piece_impact_vfx(self, final_pos, gamer_id)
	)

	_update_last_move_highlight(tgt_id)

	var mills = get_completed_mills_at(tgt_id, gamer_id)
	if not mills.is_empty():
		_spawn_mill_beam_vfx(mills, gamer_id)

func on_select_remove_peace(remover_id: int) -> void:
	current_remover = remover_id
	my_player_index = GameManager.my_player_index
	if remover_id == my_player_index:
		let_remove_peace = true
		set_board_locked(false)
		_refresh_turn_markers()
		show_hint("🎯 دوز ساختید! یکی از مهره‌های حریف را برای حذف انتخاب کنید.")
		AudioManager.play_sound("bell")
	else:
		let_remove_peace = false
		set_board_locked(true)
		_clear_markers()

func on_piece_removed(data: Dictionary) -> void:
	var peace_id = int(data.get("target_peace", -1))
	var gamer_id = int(data.get("user", data.get("gamer_id", 1)))
	if peace_id < 0 or peace_id >= MAX_NODES:
		return

	var captured_owner = 2 if gamer_id == 1 else 1
	board_data[peace_id] = 0
	if gamer_id == 1:
		player2_removed_peaces += 1
	else:
		player1_removed_peaces += 1

	current_remover = 0
	let_remove_peace = false
	_clear_markers()
	_clear_mill_beams()
	_sync_hud_scores()

	var sock_pos = node_sockets[peace_id].position + Vector3(0.0, 0.050, 0.0)
	AudioManager.play_sound("hit")
	ActionVFXManager.spawn_piece_impact_vfx(self, sock_pos, gamer_id)

	if pieces_nodes.has(peace_id) and is_instance_valid(pieces_nodes[peace_id]):
		var cap_node = pieces_nodes[peace_id]
		pieces_nodes.erase(peace_id)
		var cap_arr = captured_red_nodes if captured_owner == 1 else captured_blue_nodes
		var slot_idx = cap_arr.size()
		cap_arr.append(cap_node)
		var target_pos = _get_captured_slot_pos(captured_owner, slot_idx)
		var mid_pos = (cap_node.position + target_pos) * 0.5 + Vector3(0.0, 0.24, 0.0)

		var tw = create_tween()
		tw.tween_property(cap_node, "scale", Vector3(0.58, 0.58, 0.58), 0.34)
		tw.parallel().tween_property(cap_node, "position", mid_pos, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(cap_node, "position", target_pos, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# --- Lifecycle & Reconnect State Synchronization ---

func setup_board(game_data: Dictionary) -> void:
	reset_board()
	super._ready()
	if game_data.has("board"):
		sync_board_state(game_data["board"])
	_sync_hud_scores()

func sync_board_state(new_board: Variant) -> void:
	if typeof(new_board) != TYPE_ARRAY or (new_board as Array).size() != MAX_NODES:
		return
	var b_arr = new_board as Array
	_clear_markers()
	for i in range(MAX_NODES):
		board_data[i] = clampi(int(b_arr[i]), 0, 2)
	_spawn_all_pieces_on_board()

func on_reconnect_data(payload: Dictionary) -> void:
	my_player_index = GameManager.my_player_index
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("played_peaces") and typeof(g_data["played_peaces"]) == TYPE_ARRAY and (g_data["played_peaces"] as Array).size() >= 2:
			player1_played_peaces = int(g_data["played_peaces"][0])
			player2_played_peaces = int(g_data["played_peaces"][1])
		if g_data.has("removed_peaces") and typeof(g_data["removed_peaces"]) == TYPE_ARRAY and (g_data["removed_peaces"] as Array).size() >= 2:
			player1_removed_peaces = int(g_data["removed_peaces"][0])
			player2_removed_peaces = int(g_data["removed_peaces"][1])
		current_remover = int(g_data.get("current_remover", 0))
		_sync_side_trays()
		_sync_hud_scores()

	sync_turn_state()
	if current_remover == my_player_index and current_remover > 0:
		on_select_remove_peace(current_remover)
	elif is_my_turn:
		_refresh_turn_markers()

func reset_board() -> void:
	_clear_markers()
	_clear_mill_beams()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()
	_init_board_data()
	_spawn_all_pieces_on_board()
	_sync_side_trays()
	_sync_hud_scores()

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	release_peace()
	_clear_mill_beams()

func on_new_round(_round_num: int) -> void:
	reset_board()

func cleanup_board() -> void:
	_clear_markers()
	_clear_mill_beams()
	for m in last_move_markers:
		if is_instance_valid(m):
			m.queue_free()
	last_move_markers.clear()
	for p in pieces_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	pieces_nodes.clear()
	for p in reserve_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_red_nodes.clear()
	for p in reserve_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	reserve_blue_nodes.clear()
	for p in captured_red_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_red_nodes.clear()
	for p in captured_blue_nodes:
		if is_instance_valid(p):
			p.queue_free()
	captured_blue_nodes.clear()
	board_data.clear()
