class_name Ten3D
extends "res://scripts/games/base_game_board.gd"

# Royal Persian Make 10 / 4=10 (ده بساز - Ten) 3D Physical Board
# 100% server parity with kafehfekrbackend/Entities/Games/Ten/__init__.py,
# kafehfekrbackend/Controllers/GameSession/ten_game_session.py,
# and kafehfekr/lib/Feature/Ten/Controllers/ten_controller.dart,
# enhanced with intuitive 4=10 (app.fourequalsten.fourequalsten_app) 3D UX:
# - Top 3D Live Equation & Target `= ۱۰` Display Console
# - Interactive 4=10 Equation Track:
#   * 4 sculpted 3D Number Tiles (auto-populated with the 4 round numbers; swap via Drag-and-Drop or Two-Tap)
#   * 3 sculpted 3D Binary Operator Wells between the 4 numbers (tap to cycle + - × ÷, or drag/tap from Operator Palette)
#   * 3D 24K Gold Parentheses Arch `( ... )` physically framing any of the 5 valid bracket spans
#   * Leading unary minus `±` toggle before the 1st number
# - Bottom 3D Operator Palette (`+`, `-`, `×`, `÷`, `( )` bracket cycler)
# - Bottom 3D Action Console: Reset (`پاک‌سازی`) & Glowing Emerald-Gold Submit (`ثبت عدد ۱۰`)
# - Left & right mahogany reserve trays holding 3 3D round-win medallions per player (no floating text)

const BOARD_SURFACE_Y: float = 0.048
const MAX_ROUNDS_TEN: int = 3

const TRACK_Z: float = -0.065
const PALETTE_Z: float = 0.195
const ACTION_Z: float = 0.415
const DISPLAY_Z: float = -0.365

const NUM_X: Array[float] = [-0.345, -0.115, 0.115, 0.345]
const OP_X: Array[float] = [-0.230, 0.000, 0.230]
const SIGN_X: float = -0.485

const PALETTE_OP_X: Array[float] = [-0.405, -0.225, -0.045, 0.135]
const PALETTE_OPS: Array[String] = ["+", "-", "x", "÷"]
const PALETTE_BRACKET_X: float = 0.355

const BTN_RESET_X: float = -0.255
const BTN_SUBMIT_X: float = 0.165

const TRAY_RED_X: float = -0.765
const TRAY_BLUE_X: float = 0.765

# 6 Parentheses Modes matching 4=10 & TenController operatorValues[0..4]:
# 0: None               -> a op0 b op1 c op2 d
# 1: (N1, N2)           -> (a op0 b) op1 c op2 d
# 2: (N2, N3)           -> a op0 (b op1 c) op2 d
# 3: (N3, N4)           -> a op0 b op1 (c op2 d)
# 4: (N1, N2, N3)       -> (a op0 b op1 c) op2 d
# 5: (N2, N3, N4)       -> a op0 (b op1 c op2 d)
const BRACKET_SPANS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, 1),
	Vector2i(1, 2),
	Vector2i(2, 3),
	Vector2i(0, 2),
	Vector2i(1, 3),
]

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")

# Logical State
var current_numbers: Array[int] = [3, 3, 3, 6]
var number_slots: Array[int] = [3, 3, 3, 6]
var op_slots: Array[String] = ["", "", ""]
var leading_minus: bool = false
var bracket_mode: int = 0

var selected_num_slot: int = -1
var selected_palette_op: String = ""

var current_result: float = 0.0
var has_valid_result: bool = false
var let_send_result: bool = false
var round_solved_submitted: bool = false

var player1_score: int = 0
var player2_score: int = 0

# Drag & Raycast State
var _drag_active: bool = false
var _drag_kind: String = "" # "num" or "op"
var _drag_source_idx: int = -1
var _drag_op_symbol: String = ""
var _drag_start_screen: Vector2 = Vector2.ZERO
var _drag_has_moved: bool = false
var _drag_ghost_node: Node3D = null
var _hovered_hit_key: String = ""
var _last_click_time: float = 0.0

# 3D Containers & Interactive Nodes
var board_decor_root: Node3D
var track_root: Node3D
var palette_root: Node3D
var actions_root: Node3D
var bracket_arch_root: Node3D
var tray_red_root: Node3D
var tray_blue_root: Node3D

var display_frame_mesh: MeshInstance3D
var lbl_expression_3d: Label3D
var lbl_result_3d: Label3D
var target_badge_mesh: MeshInstance3D

var sign_btn_root: Node3D
var sign_btn_body: MeshInstance3D
var sign_btn_lbl: Label3D

var num_tile_roots: Array[Node3D] = []
var num_tile_bodies: Array[MeshInstance3D] = []
var num_tile_rims: Array[MeshInstance3D] = []
var num_tile_rings: Array[MeshInstance3D] = []
var num_tile_labels: Array[Label3D] = []

var op_slot_roots: Array[Node3D] = []
var op_slot_bodies: Array[MeshInstance3D] = []
var op_slot_rims: Array[MeshInstance3D] = []
var op_slot_rings: Array[MeshInstance3D] = []
var op_slot_labels: Array[Label3D] = []

var palette_op_roots: Array[Node3D] = []
var palette_op_bodies: Array[MeshInstance3D] = []
var palette_op_rings: Array[MeshInstance3D] = []

var bracket_btn_root: Node3D
var bracket_btn_body: MeshInstance3D
var bracket_btn_ring: MeshInstance3D
var bracket_btn_sub_lbl: Label3D

var bracket_left_pillar: Node3D
var bracket_right_pillar: Node3D
var bracket_bridge_bar: MeshInstance3D

var btn_reset_root: Node3D
var btn_submit_root: Node3D
var btn_submit_body: MeshInstance3D
var btn_submit_rim: MeshInstance3D
var btn_submit_lbl: Label3D

var tray_red_pieces: Array[Node3D] = []
var tray_blue_pieces: Array[Node3D] = []

# Shared Materials
var _mat_gold_24k: StandardMaterial3D
var _mat_platinum: StandardMaterial3D
var _mat_brass_dark: StandardMaterial3D
var _mat_obsidian_well: StandardMaterial3D
var _mat_num_body: StandardMaterial3D
var _mat_num_selected: StandardMaterial3D
var _mat_op_empty: StandardMaterial3D
var _mat_op_filled: StandardMaterial3D
var _mat_palette_op: StandardMaterial3D
var _mat_emerald_ready: StandardMaterial3D
var _mat_emerald_glow_ring: StandardMaterial3D
var _mat_submit_disabled: StandardMaterial3D
var _mat_reset_body: StandardMaterial3D
var _mat_red_body: StandardMaterial3D
var _mat_blue_body: StandardMaterial3D
var _mat_select_ring: StandardMaterial3D
var _mat_hover_ring: StandardMaterial3D


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


static func _display_op(op_str: String) -> String:
	match op_str:
		"x", "*": return "×"
		"÷", "/": return "÷"
		"+": return "+"
		"-": return "−"
		_: return op_str


func _ready() -> void:
	game_type = GameTypes.TEN
	add_to_group("board")
	_init_shared_materials()
	_build_board_3d()
	reset_board()
	super._ready()


func _init_shared_materials() -> void:
	_mat_gold_24k = StandardMaterial3D.new()
	_mat_gold_24k.albedo_color = Color(0.88, 0.72, 0.28)
	_mat_gold_24k.metallic = 0.88
	_mat_gold_24k.roughness = 0.24

	_mat_platinum = StandardMaterial3D.new()
	_mat_platinum.albedo_color = Color(0.86, 0.90, 0.96)
	_mat_platinum.metallic = 0.88
	_mat_platinum.roughness = 0.22

	_mat_brass_dark = StandardMaterial3D.new()
	_mat_brass_dark.albedo_color = Color(0.36, 0.27, 0.14)
	_mat_brass_dark.metallic = 0.72
	_mat_brass_dark.roughness = 0.36

	_mat_obsidian_well = StandardMaterial3D.new()
	_mat_obsidian_well.albedo_color = Color(0.09, 0.08, 0.08)
	_mat_obsidian_well.metallic = 0.15
	_mat_obsidian_well.roughness = 0.42
	_mat_obsidian_well.clearcoat_enabled = true
	_mat_obsidian_well.clearcoat = 0.45

	# Number Medallion: Royal Ivory-Obsidian Slate with 24K Gold Bezel
	_mat_num_body = StandardMaterial3D.new()
	_mat_num_body.albedo_color = Color(0.20, 0.22, 0.28)
	_mat_num_body.metallic = 0.28
	_mat_num_body.roughness = 0.24
	_mat_num_body.clearcoat_enabled = true
	_mat_num_body.clearcoat = 0.86

	_mat_num_selected = StandardMaterial3D.new()
	_mat_num_selected.albedo_color = Color(0.28, 0.36, 0.52)
	_mat_num_selected.metallic = 0.34
	_mat_num_selected.roughness = 0.20
	_mat_num_selected.emission_enabled = true
	_mat_num_selected.emission = Color(0.22, 0.45, 0.85)
	_mat_num_selected.emission_energy_multiplier = 0.45

	# Operator Slot: Empty vs Filled
	_mat_op_empty = StandardMaterial3D.new()
	_mat_op_empty.albedo_color = Color(0.14, 0.13, 0.16)
	_mat_op_empty.metallic = 0.20
	_mat_op_empty.roughness = 0.46

	_mat_op_filled = StandardMaterial3D.new()
	_mat_op_filled.albedo_color = Color(0.34, 0.22, 0.12)
	_mat_op_filled.metallic = 0.42
	_mat_op_filled.roughness = 0.26
	_mat_op_filled.clearcoat_enabled = true
	_mat_op_filled.clearcoat = 0.78

	_mat_palette_op = StandardMaterial3D.new()
	_mat_palette_op.albedo_color = Color(0.25, 0.17, 0.11)
	_mat_palette_op.metallic = 0.35
	_mat_palette_op.roughness = 0.28
	_mat_palette_op.clearcoat_enabled = true
	_mat_palette_op.clearcoat = 0.75

	# Emerald Ready (= 10 solved!)
	_mat_emerald_ready = StandardMaterial3D.new()
	_mat_emerald_ready.albedo_color = Color(0.12, 0.68, 0.38)
	_mat_emerald_ready.metallic = 0.32
	_mat_emerald_ready.roughness = 0.20
	_mat_emerald_ready.clearcoat_enabled = true
	_mat_emerald_ready.clearcoat = 0.88
	_mat_emerald_ready.emission_enabled = true
	_mat_emerald_ready.emission = Color(0.14, 0.82, 0.44)
	_mat_emerald_ready.emission_energy_multiplier = 0.75

	_mat_emerald_glow_ring = StandardMaterial3D.new()
	_mat_emerald_glow_ring.albedo_color = Color(0.25, 0.98, 0.56, 0.90)
	_mat_emerald_glow_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_emerald_glow_ring.emission_enabled = true
	_mat_emerald_glow_ring.emission = Color(0.20, 0.95, 0.52)
	_mat_emerald_glow_ring.emission_energy_multiplier = 1.45

	_mat_submit_disabled = StandardMaterial3D.new()
	_mat_submit_disabled.albedo_color = Color(0.17, 0.16, 0.18)
	_mat_submit_disabled.metallic = 0.20
	_mat_submit_disabled.roughness = 0.48

	_mat_reset_body = StandardMaterial3D.new()
	_mat_reset_body.albedo_color = Color(0.32, 0.16, 0.14)
	_mat_reset_body.metallic = 0.28
	_mat_reset_body.roughness = 0.30
	_mat_reset_body.clearcoat_enabled = true
	_mat_reset_body.clearcoat = 0.70

	_mat_red_body = StandardMaterial3D.new()
	_mat_red_body.albedo_color = Color(0.80, 0.10, 0.14)
	_mat_red_body.metallic = 0.22
	_mat_red_body.roughness = 0.20
	_mat_red_body.clearcoat_enabled = true
	_mat_red_body.clearcoat = 0.90

	_mat_blue_body = StandardMaterial3D.new()
	_mat_blue_body.albedo_color = Color(0.10, 0.36, 0.82)
	_mat_blue_body.metallic = 0.25
	_mat_blue_body.roughness = 0.20
	_mat_blue_body.clearcoat_enabled = true
	_mat_blue_body.clearcoat = 0.90

	_mat_select_ring = StandardMaterial3D.new()
	_mat_select_ring.albedo_color = Color(0.98, 0.80, 0.26, 0.92)
	_mat_select_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_select_ring.emission_enabled = true
	_mat_select_ring.emission = Color(0.96, 0.74, 0.20)
	_mat_select_ring.emission_energy_multiplier = 1.30

	_mat_hover_ring = StandardMaterial3D.new()
	_mat_hover_ring.albedo_color = Color(0.75, 0.86, 1.0, 0.55)
	_mat_hover_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_ring.emission_enabled = true
	_mat_hover_ring.emission = Color(0.60, 0.78, 1.0)
	_mat_hover_ring.emission_energy_multiplier = 0.65


func _build_board_3d() -> void:
	board_decor_root = Node3D.new()
	board_decor_root.name = "BoardDecorRoot"
	add_child(board_decor_root)

	track_root = Node3D.new()
	track_root.name = "TrackRoot"
	add_child(track_root)

	bracket_arch_root = Node3D.new()
	bracket_arch_root.name = "BracketArchRoot"
	add_child(bracket_arch_root)

	palette_root = Node3D.new()
	palette_root.name = "PaletteRoot"
	add_child(palette_root)

	actions_root = Node3D.new()
	actions_root.name = "ActionsRoot"
	add_child(actions_root)

	_build_top_equation_display_console()
	_build_equation_track_3d()
	_build_parentheses_arch_3d()
	_build_operator_palette_3d()
	_build_bottom_action_buttons_3d()
	_build_side_reserve_trays()


func _build_top_equation_display_console() -> void:
	# Recessed obsidian equation console at Z = DISPLAY_Z (-0.365)
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(0.98, 0.016, 0.21)
	frame_box.material = _mat_brass_dark
	display_frame_mesh = MeshInstance3D.new()
	display_frame_mesh.mesh = frame_box
	display_frame_mesh.position = Vector3(0.0, BOARD_SURFACE_Y + 0.004, DISPLAY_Z)
	board_decor_root.add_child(display_frame_mesh)

	var screen_box := BoxMesh.new()
	screen_box.size = Vector3(0.94, 0.018, 0.175)
	screen_box.material = _mat_obsidian_well
	var screen_inst := MeshInstance3D.new()
	screen_inst.mesh = screen_box
	screen_inst.position = Vector3(0.0, BOARD_SURFACE_Y + 0.006, DISPLAY_Z)
	board_decor_root.add_child(screen_inst)

	# Target `= ۱۰` Medallion on the right of the console
	var badge_cyl := CylinderMesh.new()
	badge_cyl.top_radius = 0.068
	badge_cyl.bottom_radius = 0.072
	badge_cyl.height = 0.022
	badge_cyl.radial_segments = 32
	badge_cyl.material = _mat_op_filled
	target_badge_mesh = MeshInstance3D.new()
	target_badge_mesh.mesh = badge_cyl
	target_badge_mesh.position = Vector3(0.365, BOARD_SURFACE_Y + 0.014, DISPLAY_Z)
	board_decor_root.add_child(target_badge_mesh)

	var lbl_target := Label3D.new()
	lbl_target.font = _font_hekayat
	lbl_target.font_size = 56
	lbl_target.outline_size = 14
	lbl_target.text = "هدف: ۱۰"
	lbl_target.modulate = Color(1.0, 0.92, 0.55)
	lbl_target.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	lbl_target.pixel_size = 0.00072
	lbl_target.position = Vector3(0.365, BOARD_SURFACE_Y + 0.027, DISPLAY_Z)
	lbl_target.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	board_decor_root.add_child(lbl_target)

	# Live Expression String (Left-Center of console)
	lbl_expression_3d = Label3D.new()
	lbl_expression_3d.font = _font_hekayat
	lbl_expression_3d.font_size = 64
	lbl_expression_3d.outline_size = 16
	lbl_expression_3d.modulate = Color(0.95, 0.96, 1.0)
	lbl_expression_3d.outline_modulate = Color(0.03, 0.03, 0.05, 0.98)
	lbl_expression_3d.pixel_size = 0.00078
	lbl_expression_3d.position = Vector3(-0.115, BOARD_SURFACE_Y + 0.020, DISPLAY_Z - 0.024)
	lbl_expression_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	board_decor_root.add_child(lbl_expression_3d)

	# Live Result Line (Below Expression inside console)
	lbl_result_3d = Label3D.new()
	lbl_result_3d.font = _font_hekayat
	lbl_result_3d.font_size = 54
	lbl_result_3d.outline_size = 14
	lbl_result_3d.modulate = Color(1.0, 0.86, 0.42)
	lbl_result_3d.outline_modulate = Color(0.03, 0.03, 0.05, 0.98)
	lbl_result_3d.pixel_size = 0.00072
	lbl_result_3d.position = Vector3(-0.115, BOARD_SURFACE_Y + 0.020, DISPLAY_Z + 0.044)
	lbl_result_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	board_decor_root.add_child(lbl_result_3d)


func _build_equation_track_3d() -> void:
	# Recessed track groove behind the 4 numbers and 3 operators
	var track_plate := BoxMesh.new()
	track_plate.size = Vector3(1.02, 0.008, 0.22)
	track_plate.material = _mat_obsidian_well
	var track_inst := MeshInstance3D.new()
	track_inst.mesh = track_plate
	track_inst.position = Vector3(0.0, BOARD_SURFACE_Y + 0.002, TRACK_Z)
	track_root.add_child(track_inst)

	# Leading unary minus toggle button (`±`) at X = SIGN_X (-0.485)
	sign_btn_root = Node3D.new()
	sign_btn_root.position = Vector3(SIGN_X, BOARD_SURFACE_Y + 0.012, TRACK_Z)
	track_root.add_child(sign_btn_root)

	var sign_cyl := CylinderMesh.new()
	sign_cyl.top_radius = 0.034
	sign_cyl.bottom_radius = 0.038
	sign_cyl.height = 0.016
	sign_cyl.radial_segments = 24
	sign_btn_body = MeshInstance3D.new()
	sign_btn_body.mesh = sign_cyl
	sign_btn_body.material_override = _mat_op_empty
	sign_btn_root.add_child(sign_btn_body)

	sign_btn_lbl = Label3D.new()
	sign_btn_lbl.font = _font_hekayat
	sign_btn_lbl.font_size = 56
	sign_btn_lbl.outline_size = 14
	sign_btn_lbl.text = "±"
	sign_btn_lbl.modulate = Color(0.86, 0.88, 0.94)
	sign_btn_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	sign_btn_lbl.pixel_size = 0.00072
	sign_btn_lbl.position = Vector3(0.0, 0.010, 0.0)
	sign_btn_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	sign_btn_root.add_child(sign_btn_lbl)

	var sign_area := _create_hit_area(Vector3(0.085, 0.05, 0.14), "sign_0")
	sign_btn_root.add_child(sign_area)

	# 4 Sculpted 3D Number Tiles (`NumSlot 0..3`)
	num_tile_roots.resize(4)
	num_tile_bodies.resize(4)
	num_tile_rims.resize(4)
	num_tile_rings.resize(4)
	num_tile_labels.resize(4)

	var num_cyl := CylinderMesh.new()
	num_cyl.top_radius = 0.068
	num_cyl.bottom_radius = 0.072
	num_cyl.height = 0.022
	num_cyl.radial_segments = 32

	var num_rim_torus := TorusMesh.new()
	num_rim_torus.inner_radius = 0.057
	num_rim_torus.outer_radius = 0.069
	num_rim_torus.rings = 32
	num_rim_torus.ring_segments = 12

	var num_sel_torus := TorusMesh.new()
	num_sel_torus.inner_radius = 0.071
	num_sel_torus.outer_radius = 0.080
	num_sel_torus.rings = 32
	num_sel_torus.ring_segments = 12

	for i in range(4):
		var n_root := Node3D.new()
		n_root.name = "NumSlot_%d" % i
		n_root.position = Vector3(NUM_X[i], BOARD_SURFACE_Y + 0.015, TRACK_Z)
		track_root.add_child(n_root)
		num_tile_roots[i] = n_root

		var n_body := MeshInstance3D.new()
		n_body.mesh = num_cyl
		n_body.material_override = _mat_num_body
		n_root.add_child(n_body)
		num_tile_bodies[i] = n_body

		var n_rim := MeshInstance3D.new()
		n_rim.mesh = num_rim_torus
		n_rim.material_override = _mat_gold_24k
		n_rim.position.y = 0.011
		n_rim.scale = Vector3(1.0, 0.42, 1.0)
		n_root.add_child(n_rim)
		num_tile_rims[i] = n_rim

		var n_ring := MeshInstance3D.new()
		n_ring.mesh = num_sel_torus
		n_ring.material_override = _mat_select_ring
		n_ring.position.y = 0.002
		n_ring.scale = Vector3(1.0, 0.45, 1.0)
		n_ring.visible = false
		n_root.add_child(n_ring)
		num_tile_rings[i] = n_ring

		var n_lbl := Label3D.new()
		n_lbl.font = _font_hekayat
		n_lbl.font_size = 84
		n_lbl.outline_size = 18
		n_lbl.modulate = Color(1.0, 0.98, 0.92)
		n_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
		n_lbl.pixel_size = 0.00090
		n_lbl.position = Vector3(0.0, 0.0135, 0.0)
		n_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		n_root.add_child(n_lbl)
		num_tile_labels[i] = n_lbl

		var n_area := _create_hit_area(Vector3(0.145, 0.06, 0.165), "num_%d" % i)
		n_root.add_child(n_area)

	# 3 Sculpted 3D Operator Wells (`OpSlot 0..2`) between the 4 numbers
	op_slot_roots.resize(3)
	op_slot_bodies.resize(3)
	op_slot_rims.resize(3)
	op_slot_rings.resize(3)
	op_slot_labels.resize(3)

	var op_box := CylinderMesh.new()
	op_box.top_radius = 0.043
	op_box.bottom_radius = 0.046
	op_box.height = 0.018
	op_box.radial_segments = 24

	var op_rim_torus := TorusMesh.new()
	op_rim_torus.inner_radius = 0.036
	op_rim_torus.outer_radius = 0.044
	op_rim_torus.rings = 24
	op_rim_torus.ring_segments = 10

	var op_sel_torus := TorusMesh.new()
	op_sel_torus.inner_radius = 0.046
	op_sel_torus.outer_radius = 0.053
	op_sel_torus.rings = 24
	op_sel_torus.ring_segments = 10

	for i in range(3):
		var o_root := Node3D.new()
		o_root.name = "OpSlot_%d" % i
		o_root.position = Vector3(OP_X[i], BOARD_SURFACE_Y + 0.013, TRACK_Z)
		track_root.add_child(o_root)
		op_slot_roots[i] = o_root

		var o_body := MeshInstance3D.new()
		o_body.mesh = op_box
		o_body.material_override = _mat_op_empty
		o_root.add_child(o_body)
		op_slot_bodies[i] = o_body

		var o_rim := MeshInstance3D.new()
		o_rim.mesh = op_rim_torus
		o_rim.material_override = _mat_brass_dark
		o_rim.position.y = 0.009
		o_rim.scale = Vector3(1.0, 0.42, 1.0)
		o_root.add_child(o_rim)
		op_slot_rims[i] = o_rim

		var o_ring := MeshInstance3D.new()
		o_ring.mesh = op_sel_torus
		o_ring.material_override = _mat_hover_ring
		o_ring.position.y = 0.002
		o_ring.scale = Vector3(1.0, 0.45, 1.0)
		o_ring.visible = false
		o_root.add_child(o_ring)
		op_slot_rings[i] = o_ring

		var o_lbl := Label3D.new()
		o_lbl.font = _font_hekayat
		o_lbl.font_size = 68
		o_lbl.outline_size = 16
		o_lbl.text = "+"
		o_lbl.modulate = Color(1.0, 0.90, 0.48)
		o_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
		o_lbl.pixel_size = 0.00082
		o_lbl.position = Vector3(0.0, 0.0115, 0.0)
		o_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		o_root.add_child(o_lbl)
		op_slot_labels[i] = o_lbl

		var o_area := _create_hit_area(Vector3(0.095, 0.06, 0.155), "op_slot_%d" % i)
		o_root.add_child(o_area)


func _build_parentheses_arch_3d() -> void:
	# 3D 24K Gold Parentheses Arch spanning whichever numbers are wrapped by `bracket_mode`
	bracket_left_pillar = _create_bracket_pillar("(")
	bracket_arch_root.add_child(bracket_left_pillar)

	bracket_right_pillar = _create_bracket_pillar(")")
	bracket_arch_root.add_child(bracket_right_pillar)

	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(0.30, 0.006, 0.010)
	bridge_mesh.material = _mat_gold_24k
	bracket_bridge_bar = MeshInstance3D.new()
	bracket_bridge_bar.mesh = bridge_mesh
	bracket_bridge_bar.position = Vector3(0.0, BOARD_SURFACE_Y + 0.008, TRACK_Z + 0.096)
	bracket_arch_root.add_child(bracket_bridge_bar)


func _create_bracket_pillar(sym: String) -> Node3D:
	var root := Node3D.new()
	var base := CylinderMesh.new()
	base.top_radius = 0.018
	base.bottom_radius = 0.021
	base.height = 0.022
	base.radial_segments = 20
	base.material = _mat_gold_24k
	var b_inst := MeshInstance3D.new()
	b_inst.mesh = base
	b_inst.position.y = 0.011
	root.add_child(b_inst)

	var lbl := Label3D.new()
	lbl.font = _font_hekayat
	lbl.font_size = 76
	lbl.outline_size = 16
	lbl.text = sym
	lbl.modulate = Color(1.0, 0.88, 0.36)
	lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	lbl.pixel_size = 0.00088
	lbl.position = Vector3(0.0, 0.024, 0.0)
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(lbl)
	return root


func _build_operator_palette_3d() -> void:
	var tray_plate := BoxMesh.new()
	tray_plate.size = Vector3(0.98, 0.008, 0.175)
	tray_plate.material = _mat_obsidian_well
	var tray_inst := MeshInstance3D.new()
	tray_inst.mesh = tray_plate
	tray_inst.position = Vector3(0.0, BOARD_SURFACE_Y + 0.002, PALETTE_Z)
	palette_root.add_child(tray_inst)

	palette_op_roots.resize(4)
	palette_op_bodies.resize(4)
	palette_op_rings.resize(4)

	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.054
	p_cyl.bottom_radius = 0.058
	p_cyl.height = 0.020
	p_cyl.radial_segments = 28

	var p_rim := TorusMesh.new()
	p_rim.inner_radius = 0.045
	p_rim.outer_radius = 0.055
	p_rim.rings = 28
	p_rim.ring_segments = 12
	p_rim.material = _mat_gold_24k

	var p_sel := TorusMesh.new()
	p_sel.inner_radius = 0.057
	p_sel.outer_radius = 0.065
	p_sel.rings = 28
	p_sel.ring_segments = 12

	for i in range(4):
		var sym: String = PALETTE_OPS[i]
		var p_root := Node3D.new()
		p_root.name = "PaletteOp_%d" % i
		p_root.position = Vector3(PALETTE_OP_X[i], BOARD_SURFACE_Y + 0.014, PALETTE_Z)
		palette_root.add_child(p_root)
		palette_op_roots[i] = p_root

		var body := MeshInstance3D.new()
		body.mesh = p_cyl
		body.material_override = _mat_palette_op
		p_root.add_child(body)
		palette_op_bodies[i] = body

		var rim := MeshInstance3D.new()
		rim.mesh = p_rim
		rim.position.y = 0.010
		rim.scale = Vector3(1.0, 0.42, 1.0)
		p_root.add_child(rim)

		var ring := MeshInstance3D.new()
		ring.mesh = p_sel
		ring.material_override = _mat_select_ring
		ring.position.y = 0.002
		ring.scale = Vector3(1.0, 0.45, 1.0)
		ring.visible = false
		p_root.add_child(ring)
		palette_op_rings[i] = ring

		var lbl := Label3D.new()
		lbl.font = _font_hekayat
		lbl.font_size = 76
		lbl.outline_size = 16
		lbl.text = _display_op(sym)
		lbl.modulate = Color(1.0, 0.94, 0.72)
		lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
		lbl.pixel_size = 0.00086
		lbl.position = Vector3(0.0, 0.012, 0.0)
		lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		p_root.add_child(lbl)

		var area := _create_hit_area(Vector3(0.145, 0.06, 0.155), "pal_op_%d" % i)
		p_root.add_child(area)

	# 3D Parentheses `( )` Grouping Button at X = PALETTE_BRACKET_X (+0.355)
	bracket_btn_root = Node3D.new()
	bracket_btn_root.name = "BracketCycleBtn"
	bracket_btn_root.position = Vector3(PALETTE_BRACKET_X, BOARD_SURFACE_Y + 0.014, PALETTE_Z)
	palette_root.add_child(bracket_btn_root)

	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.21, 0.020, 0.125)
	bracket_btn_body = MeshInstance3D.new()
	bracket_btn_body.mesh = b_box
	bracket_btn_body.material_override = _mat_palette_op
	bracket_btn_root.add_child(bracket_btn_body)

	var b_rim_box := BoxMesh.new()
	b_rim_box.size = Vector3(0.222, 0.006, 0.136)
	b_rim_box.material = _mat_gold_24k
	bracket_btn_ring = MeshInstance3D.new()
	bracket_btn_ring.mesh = b_rim_box
	bracket_btn_ring.position.y = -0.005
	bracket_btn_root.add_child(bracket_btn_ring)

	var b_lbl := Label3D.new()
	b_lbl.font = _font_hekayat
	b_lbl.font_size = 56
	b_lbl.outline_size = 14
	b_lbl.text = "( ) پرانتز"
	b_lbl.modulate = Color(1.0, 0.90, 0.45)
	b_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	b_lbl.pixel_size = 0.00072
	b_lbl.position = Vector3(0.0, 0.012, -0.015)
	b_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	bracket_btn_root.add_child(b_lbl)

	bracket_btn_sub_lbl = Label3D.new()
	bracket_btn_sub_lbl.font = _font_hekayat
	bracket_btn_sub_lbl.font_size = 42
	bracket_btn_sub_lbl.outline_size = 12
	bracket_btn_sub_lbl.text = "بدون پرانتز"
	bracket_btn_sub_lbl.modulate = Color(0.84, 0.88, 0.95)
	bracket_btn_sub_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	bracket_btn_sub_lbl.pixel_size = 0.00064
	bracket_btn_sub_lbl.position = Vector3(0.0, 0.012, 0.032)
	bracket_btn_sub_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	bracket_btn_root.add_child(bracket_btn_sub_lbl)

	var b_area := _create_hit_area(Vector3(0.24, 0.06, 0.155), "bracket_cycle")
	bracket_btn_root.add_child(b_area)


func _build_bottom_action_buttons_3d() -> void:
	# 1. Reset / Clear Button (Left)
	btn_reset_root = Node3D.new()
	btn_reset_root.name = "BtnReset3D"
	btn_reset_root.position = Vector3(BTN_RESET_X, BOARD_SURFACE_Y + 0.014, ACTION_Z)
	actions_root.add_child(btn_reset_root)

	var r_box := BoxMesh.new()
	r_box.size = Vector3(0.32, 0.022, 0.125)
	r_box.material = _mat_reset_body
	var r_inst := MeshInstance3D.new()
	r_inst.mesh = r_box
	btn_reset_root.add_child(r_inst)

	var r_rim := BoxMesh.new()
	r_rim.size = Vector3(0.334, 0.008, 0.138)
	r_rim.material = _mat_brass_dark
	var r_rim_inst := MeshInstance3D.new()
	r_rim_inst.mesh = r_rim
	r_rim_inst.position.y = -0.005
	btn_reset_root.add_child(r_rim_inst)

	var r_lbl := Label3D.new()
	r_lbl.font = _font_hekayat
	r_lbl.font_size = 54
	r_lbl.outline_size = 14
	r_lbl.text = "پاک‌سازی"
	r_lbl.modulate = Color(1.0, 0.88, 0.84)
	r_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	r_lbl.pixel_size = 0.00072
	r_lbl.position = Vector3(0.0, 0.013, 0.0)
	r_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	btn_reset_root.add_child(r_lbl)

	var r_area := _create_hit_area(Vector3(0.35, 0.06, 0.15), "btn_reset")
	btn_reset_root.add_child(r_area)

	# 2. Submit Solution `= ۱۰` Button (Right)
	btn_submit_root = Node3D.new()
	btn_submit_root.name = "BtnSubmit3D"
	btn_submit_root.position = Vector3(BTN_SUBMIT_X, BOARD_SURFACE_Y + 0.015, ACTION_Z)
	actions_root.add_child(btn_submit_root)

	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.44, 0.024, 0.130)
	btn_submit_body = MeshInstance3D.new()
	btn_submit_body.mesh = s_box
	btn_submit_body.material_override = _mat_submit_disabled
	btn_submit_root.add_child(btn_submit_body)

	var s_rim := BoxMesh.new()
	s_rim.size = Vector3(0.456, 0.008, 0.144)
	btn_submit_rim = MeshInstance3D.new()
	btn_submit_rim.mesh = s_rim
	btn_submit_rim.material_override = _mat_brass_dark
	btn_submit_rim.position.y = -0.005
	btn_submit_root.add_child(btn_submit_rim)

	btn_submit_lbl = Label3D.new()
	btn_submit_lbl.font = _font_hekayat
	btn_submit_lbl.font_size = 58
	btn_submit_lbl.outline_size = 15
	btn_submit_lbl.text = "ثبت پاسخ (= ۱۰)"
	btn_submit_lbl.modulate = Color(0.65, 0.68, 0.72)
	btn_submit_lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	btn_submit_lbl.pixel_size = 0.00074
	btn_submit_lbl.position = Vector3(0.0, 0.014, 0.0)
	btn_submit_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	btn_submit_root.add_child(btn_submit_lbl)

	var s_area := _create_hit_area(Vector3(0.47, 0.06, 0.155), "btn_submit")
	btn_submit_root.add_child(s_area)


func _create_hit_area(box_size: Vector3, hit_key: String) -> Area3D:
	var area := Area3D.new()
	area.set_meta("hit_key", hit_key)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	area.add_child(col)
	return area


func _build_side_reserve_trays() -> void:
	tray_red_root = _create_single_tray("TrayRed", TRAY_RED_X, 1)
	add_child(tray_red_root)

	tray_blue_root = _create_single_tray("TrayBlue", TRAY_BLUE_X, 2)
	add_child(tray_blue_root)

	tray_red_pieces.clear()
	tray_blue_pieces.clear()

	for i in range(MAX_ROUNDS_TEN):
		var pz: float = -0.22 + float(i) * 0.22
		var py: float = 0.022

		var p_red := _create_reserve_crest_mesh(1)
		p_red.position = Vector3(0.0, py, pz)
		p_red.scale = Vector3(0.88, 0.88, 0.88)
		tray_red_root.add_child(p_red)
		tray_red_pieces.append(p_red)

		var p_blue := _create_reserve_crest_mesh(2)
		p_blue.position = Vector3(0.0, py, pz)
		p_blue.scale = Vector3(0.88, 0.88, 0.88)
		tray_blue_root.add_child(p_blue)
		tray_blue_pieces.append(p_blue)


func _create_single_tray(tray_name: String, pos_x: float, gamer_id: int) -> Node3D:
	var root := Node3D.new()
	root.name = tray_name
	root.position = Vector3(pos_x, 0.0, 0.0)

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.20, 0.11, 0.07)
	mat_wood.roughness = 0.40
	mat_wood.clearcoat_enabled = true
	mat_wood.clearcoat = 0.55

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.155, 0.022, 0.72)
	base_mesh.material = mat_wood
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0.0, 0.008, 0.0)
	root.add_child(base_inst)

	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(0.128, 0.006, 0.66)
	bed_mesh.material = _mat_obsidian_well
	var bed_inst := MeshInstance3D.new()
	bed_inst.mesh = bed_mesh
	bed_inst.position = Vector3(0.0, 0.018, 0.0)
	root.add_child(bed_inst)

	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.158, 0.005, 0.012)
	trim_mesh.material = _mat_gold_24k if gamer_id == 1 else _mat_platinum

	for z_sign in [-1.0, 1.0]:
		var trim := MeshInstance3D.new()
		trim.mesh = trim_mesh
		trim.position = Vector3(0.0, 0.021, z_sign * 0.348)
		root.add_child(trim)

	return root


func _create_reserve_crest_mesh(gamer_id: int) -> Node3D:
	var root := Node3D.new()
	var body_mat: StandardMaterial3D = _mat_red_body if gamer_id == 1 else _mat_blue_body
	var trim_mat: StandardMaterial3D = _mat_gold_24k if gamer_id == 1 else _mat_platinum

	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 0.046
	base_cyl.bottom_radius = 0.050
	base_cyl.height = 0.016
	base_cyl.radial_segments = 24
	base_cyl.material = body_mat
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_cyl
	base_inst.position.y = 0.008
	root.add_child(base_inst)

	var rim_torus := TorusMesh.new()
	rim_torus.inner_radius = 0.036
	rim_torus.outer_radius = 0.046
	rim_torus.rings = 24
	rim_torus.ring_segments = 12
	rim_torus.material = trim_mat
	var rim_inst := MeshInstance3D.new()
	rim_inst.mesh = rim_torus
	rim_inst.position.y = 0.016
	rim_inst.scale = Vector3(1.0, 0.45, 1.0)
	root.add_child(rim_inst)

	return root


# --- BaseGameBoard Lifecycle Hooks ---

func reset_board() -> void:
	_cancel_drag()
	op_slots = ["", "", ""]
	leading_minus = false
	bracket_mode = 0
	selected_num_slot = -1
	selected_palette_op = ""
	round_solved_submitted = false
	if current_numbers.size() == 4:
		number_slots = [current_numbers[0], current_numbers[1], current_numbers[2], current_numbers[3]]
	_recalculate_and_refresh_ui()
	_sync_reserve_trays()


func cleanup_board() -> void:
	_cancel_drag()


func setup_board(game_data: Dictionary) -> void:
	if game_data.has("current_numbers") and typeof(game_data["current_numbers"]) == TYPE_ARRAY:
		_apply_round_numbers(game_data["current_numbers"])
	if game_data.has("scores") and typeof(game_data["scores"]) == TYPE_ARRAY and (game_data["scores"] as Array).size() >= 2:
		player1_score = int(game_data["scores"][0])
		player2_score = int(game_data["scores"][1])
		_sync_hud_scores()
		_sync_reserve_trays()


func on_turn_data(payload: Dictionary) -> void:
	if payload.has("numbers") and typeof(payload["numbers"]) == TYPE_ARRAY:
		_apply_round_numbers(payload["numbers"])


func on_turn_changed(_turn: int, _is_me: bool) -> void:
	is_my_turn = true
	is_board_locked = false
	round_solved_submitted = false
	_recalculate_and_refresh_ui()
	var hud = _get_hud()
	if hud and hud.has_method("set_custom_banner"):
		var nums_fa := "%s ، %s ، %s ، %s" % [
			_fa_digits(current_numbers[0]),
			_fa_digits(current_numbers[1]),
			_fa_digits(current_numbers[2]),
			_fa_digits(current_numbers[3])
		]
		hud.set_custom_banner("🧮 با اعداد (%s) عدد ۱۰ بسازید!" % nums_fa, Color(1.0, 0.90, 0.45))


func on_new_round(round_num: int) -> void:
	GameManager.current_round = round_num
	round_solved_submitted = false
	reset_board()


func on_round_finished(payload: Variant) -> void:
	_cancel_drag()
	set_board_locked(true)
	var winner: int = 0
	if typeof(payload) == TYPE_DICTIONARY:
		winner = int(payload.get("Winner", payload.get("winner", 0)))
	else:
		winner = int(payload)
	if winner == 1:
		player1_score = max(player1_score, GameManager.p1_score)
	elif winner == 2:
		player2_score = max(player2_score, GameManager.p2_score)
	_sync_reserve_trays()


func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("current_numbers") and typeof(g_data["current_numbers"]) == TYPE_ARRAY:
			_apply_round_numbers(g_data["current_numbers"])
		if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
			player1_score = int(g_data["scores"][0])
			player2_score = int(g_data["scores"][1])
			_sync_hud_scores()
			_sync_reserve_trays()
	is_my_turn = true
	is_board_locked = false
	_recalculate_and_refresh_ui()


func _apply_round_numbers(arr: Array) -> void:
	if arr.size() < 4:
		return
	current_numbers = [int(arr[0]), int(arr[1]), int(arr[2]), int(arr[3])]
	number_slots = [current_numbers[0], current_numbers[1], current_numbers[2], current_numbers[3]]
	op_slots = ["", "", ""]
	leading_minus = false
	bracket_mode = 0
	selected_num_slot = -1
	selected_palette_op = ""
	round_solved_submitted = false
	_recalculate_and_refresh_ui()


func _sync_hud_scores() -> void:
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var hud = _get_hud()
	if hud and hud.has_method("update_scores"):
		hud.update_scores(player1_score, player2_score)


func _sync_reserve_trays() -> void:
	var p1_s: int = max(player1_score, GameManager.p1_score)
	var p2_s: int = max(player2_score, GameManager.p2_score)
	var red_rem: int = clampi(MAX_ROUNDS_TEN - p1_s, 0, MAX_ROUNDS_TEN)
	var blue_rem: int = clampi(MAX_ROUNDS_TEN - p2_s, 0, MAX_ROUNDS_TEN)
	for i in range(tray_red_pieces.size()):
		if is_instance_valid(tray_red_pieces[i]):
			tray_red_pieces[i].visible = (i < red_rem)
	for i in range(tray_blue_pieces.size()):
		if is_instance_valid(tray_blue_pieces[i]):
			tray_blue_pieces[i].visible = (i < blue_rem)


func _get_hud() -> Node:
	var main_node = get_tree().current_scene
	if main_node and is_instance_valid(main_node) and "base_game_hud" in main_node:
		return main_node.base_game_hud
	return null


func _set_camera_drag_locked(locked: bool) -> void:
	var p = get_parent()
	while p:
		if "camera_drag_locked" in p:
			p.camera_drag_locked = locked
			break
		p = p.get_parent()


# --- Expression Builder & Floating-Point Arithmetic Evaluator ---

func _build_raw_expression_string() -> String:
	# Mirrors TenController.calculateExpression() 1:1
	var span: Vector2i = BRACKET_SPANS[bracket_mode]
	var open_idx: int = span.x
	var close_idx: int = span.y

	var expr: String = ""
	if leading_minus:
		expr += "-"

	for i in range(4):
		if open_idx == i:
			expr += "("
		expr += str(number_slots[i])
		if close_idx == i:
			expr += ")"
		if i < 3:
			if op_slots[i].is_empty():
				return expr
			var op_c: String = op_slots[i].replace("x", "*").replace("÷", "/")
			expr += op_c
	return expr


func _build_pretty_persian_expression() -> String:
	var span: Vector2i = BRACKET_SPANS[bracket_mode]
	var open_idx: int = span.x
	var close_idx: int = span.y

	var parts: Array[String] = []
	for i in range(4):
		var token: String = ""
		if i == 0 and leading_minus:
			token += "−"
		if open_idx == i:
			token += "("
		token += _fa_digits(number_slots[i])
		if close_idx == i:
			token += ")"
		parts.append(token)
		if i < 3:
			if op_slots[i].is_empty():
				parts.append("؟")
			else:
				parts.append(_display_op(op_slots[i]))
	return " ".join(parts)


static func _eval_math_expression(expr: String) -> Variant:
	# Exact floating-point arithmetic evaluator supporting unary '-', binary '+', '-', '*', '/', and '(...)'
	if expr.is_empty():
		return null

	var tokens: Array = []
	var i: int = 0
	var n: int = expr.length()
	while i < n:
		var ch: String = expr[i]
		if ch == " ":
			i += 1
			continue
		if ch in ["+", "-", "*", "/", "(", ")"]:
			# Check if '-' is unary (at start, or immediately after '(' or another binary operator)
			if ch == "-" and (tokens.is_empty() or str(tokens[-1]) in ["+", "-", "*", "/", "("]):
				tokens.append("u-")
			else:
				tokens.append(ch)
			i += 1
		elif ch >= "0" and ch <= "9":
			var num_str: String = ""
			while i < n and ((expr[i] >= "0" and expr[i] <= "9") or expr[i] == "."):
				num_str += expr[i]
				i += 1
			tokens.append(float(num_str))
		else:
			return null

	# Shunting-yard algorithm to RPN
	var output: Array = []
	var ops: Array[String] = []
	var prec := {"+": 1, "-": 1, "*": 2, "/": 2, "u-": 3}

	for tok in tokens:
		if typeof(tok) == TYPE_FLOAT:
			output.append(tok)
		elif tok == "(":
			ops.append("(")
		elif tok == ")":
			var found_open: bool = false
			while not ops.is_empty():
				var top: String = ops.pop_back()
				if top == "(":
					found_open = true
					break
				output.append(top)
			if not found_open:
				return null
		else:
			var op_s: String = str(tok)
			while not ops.is_empty() and ops[-1] != "(":
				var top_op: String = ops[-1]
				if (op_s != "u-" and prec.get(top_op, 0) >= prec.get(op_s, 0)) or (op_s == "u-" and prec.get(top_op, 0) > prec.get(op_s, 0)):
					output.append(ops.pop_back())
				else:
					break
			ops.append(op_s)

	while not ops.is_empty():
		var top: String = ops.pop_back()
		if top == "(" or top == ")":
			return null
		output.append(top)

	# Evaluate RPN stack
	var stack: Array[float] = []
	for item in output:
		if typeof(item) == TYPE_FLOAT:
			stack.append(float(item))
		elif item == "u-":
			if stack.is_empty():
				return null
			var v: float = stack.pop_back()
			stack.append(-v)
		else:
			if stack.size() < 2:
				return null
			var b: float = stack.pop_back()
			var a: float = stack.pop_back()
			match str(item):
				"+": stack.append(a + b)
				"-": stack.append(a - b)
				"*": stack.append(a * b)
				"/":
					if absf(b) < 1e-8:
						return null
					stack.append(a / b)
				_:
					return null

	if stack.size() != 1:
		return null
	return stack[0]


func _recalculate_and_refresh_ui() -> void:
	var all_ops_filled: bool = not op_slots[0].is_empty() and not op_slots[1].is_empty() and not op_slots[2].is_empty()
	var raw_expr: String = _build_raw_expression_string()

	has_valid_result = false
	current_result = 0.0
	let_send_result = false

	if all_ops_filled:
		var val = _eval_math_expression(raw_expr)
		if val != null and not is_nan(float(val)) and not is_inf(float(val)):
			has_valid_result = true
			current_result = float(val)
			if absf(current_result - 10.0) < 0.0001:
				let_send_result = true

	_refresh_visuals()


func _format_number_fa(v: float) -> String:
	if absf(v - roundf(v)) < 0.0005:
		return _fa_digits(int(roundf(v)))
	return _fa_digits("%.2f" % v)


func _refresh_visuals() -> void:
	# 1. Top Console Labels & Target Badge
	if is_instance_valid(lbl_expression_3d):
		lbl_expression_3d.text = _build_pretty_persian_expression()

	if is_instance_valid(lbl_result_3d):
		if let_send_result:
			lbl_result_3d.text = "🎉 حاصل برابر ۱۰ شد! دکمه ثبت پاسخ را بزنید"
			lbl_result_3d.modulate = Color(0.32, 0.98, 0.56)
			target_badge_mesh.material_override = _mat_emerald_ready
			display_frame_mesh.material_override = _mat_gold_24k
		elif has_valid_result:
			lbl_result_3d.text = "حاصل فعلی: %s  (هدف: ۱۰)" % _format_number_fa(current_result)
			lbl_result_3d.modulate = Color(1.0, 0.86, 0.42)
			target_badge_mesh.material_override = _mat_op_filled
			display_frame_mesh.material_override = _mat_brass_dark
		else:
			lbl_result_3d.text = "عملگرهای ریاضی (+ − × ÷) را بین ۴ عدد قرار دهید"
			lbl_result_3d.modulate = Color(0.82, 0.86, 0.94)
			target_badge_mesh.material_override = _mat_op_filled
			display_frame_mesh.material_override = _mat_brass_dark

	# 2. Leading Minus Toggle (`±`)
	if is_instance_valid(sign_btn_body):
		sign_btn_body.material_override = _mat_op_filled if leading_minus else _mat_op_empty
		sign_btn_lbl.text = "−" if leading_minus else "±"
		sign_btn_lbl.modulate = Color(1.0, 0.88, 0.36) if leading_minus else Color(0.76, 0.80, 0.88)

	# 3. 4 Number Tiles
	var base_num_y: float = BOARD_SURFACE_Y + 0.015
	for i in range(4):
		var n_root: Node3D = num_tile_roots[i]
		var n_body: MeshInstance3D = num_tile_bodies[i]
		var n_ring: MeshInstance3D = num_tile_rings[i]
		var n_lbl: Label3D = num_tile_labels[i]
		n_lbl.text = _fa_digits(number_slots[i])

		var is_sel: bool = (selected_num_slot == i)
		var is_hov: bool = (_hovered_hit_key == ("num_%d" % i))
		n_body.material_override = _mat_num_selected if is_sel else _mat_num_body
		n_root.position.y = base_num_y + (0.018 if is_sel else (0.006 if is_hov else 0.0))
		if is_sel:
			n_ring.visible = true
			n_ring.material_override = _mat_select_ring
		elif is_hov:
			n_ring.visible = true
			n_ring.material_override = _mat_hover_ring
		else:
			n_ring.visible = false

	# 4. 3 Operator Slots
	var base_op_y: float = BOARD_SURFACE_Y + 0.013
	for i in range(3):
		var o_root: Node3D = op_slot_roots[i]
		var o_body: MeshInstance3D = op_slot_bodies[i]
		var o_rim: MeshInstance3D = op_slot_rims[i]
		var o_ring: MeshInstance3D = op_slot_rings[i]
		var o_lbl: Label3D = op_slot_labels[i]

		var has_op: bool = not op_slots[i].is_empty()
		var is_hov: bool = (_hovered_hit_key == ("op_slot_%d" % i))
		o_body.material_override = _mat_op_filled if has_op else _mat_op_empty
		o_rim.material_override = _mat_gold_24k if has_op else _mat_brass_dark
		o_lbl.text = _display_op(op_slots[i]) if has_op else "؟"
		o_lbl.modulate = Color(1.0, 0.94, 0.56) if has_op else Color(0.55, 0.58, 0.65)
		o_root.position.y = base_op_y + (0.006 if is_hov else 0.0)
		o_ring.visible = is_hov or not selected_palette_op.is_empty()
		o_ring.material_override = _mat_select_ring if is_hov else _mat_hover_ring

	# 5. 3D Golden Parentheses Arch `( ... )`
	var span: Vector2i = BRACKET_SPANS[bracket_mode]
	if span.x == -1:
		bracket_arch_root.visible = false
	else:
		bracket_arch_root.visible = true
		var left_x: float = NUM_X[span.x] - 0.078
		var right_x: float = NUM_X[span.y] + 0.078
		bracket_left_pillar.position = Vector3(left_x, BOARD_SURFACE_Y + 0.008, TRACK_Z + 0.068)
		bracket_right_pillar.position = Vector3(right_x, BOARD_SURFACE_Y + 0.008, TRACK_Z + 0.068)
		var width_x: float = right_x - left_x
		bracket_bridge_bar.position = Vector3((left_x + right_x) * 0.5, BOARD_SURFACE_Y + 0.010, TRACK_Z + 0.088)
		var b_mesh := bracket_bridge_bar.mesh as BoxMesh
		if b_mesh:
			b_mesh.size = Vector3(width_x, 0.006, 0.010)

	# 6. Palette Operator Tokens & Bracket Cycle Button
	var base_pal_y: float = BOARD_SURFACE_Y + 0.014
	for i in range(4):
		var sym: String = PALETTE_OPS[i]
		var p_root: Node3D = palette_op_roots[i]
		var p_ring: MeshInstance3D = palette_op_rings[i]
		var is_sel: bool = (selected_palette_op == sym)
		var is_hov: bool = (_hovered_hit_key == ("pal_op_%d" % i))
		p_root.position.y = base_pal_y + (0.016 if is_sel else (0.006 if is_hov else 0.0))
		p_ring.visible = is_sel or is_hov
		p_ring.material_override = _mat_select_ring if is_sel else _mat_hover_ring

	var bracket_names: Array[String] = [
		"بدون پرانتز",
		"(اول و دوم)",
		"(دوم و سوم)",
		"(سوم و چهارم)",
		"(سه عدد اول)",
		"(سه عدد آخر)"
	]
	if is_instance_valid(bracket_btn_sub_lbl):
		bracket_btn_sub_lbl.text = bracket_names[bracket_mode]
		bracket_btn_body.material_override = _mat_op_filled if bracket_mode > 0 else _mat_palette_op

	# 7. Submit Button (`= ۱۰`)
	if is_instance_valid(btn_submit_body):
		if let_send_result and not round_solved_submitted:
			btn_submit_body.material_override = _mat_emerald_ready
			btn_submit_rim.material_override = _mat_gold_24k
			btn_submit_lbl.modulate = Color(1.0, 1.0, 0.95)
			btn_submit_lbl.text = "✅ ثبت پاسخ (= ۱۰)"
		else:
			btn_submit_body.material_override = _mat_submit_disabled
			btn_submit_rim.material_override = _mat_brass_dark
			btn_submit_lbl.modulate = Color(0.62, 0.65, 0.70)
			btn_submit_lbl.text = "ثبت پاسخ (= ۱۰)"


# --- Input, Drag-and-Drop & Tap Handling ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_active:
			if not _drag_has_moved and mm.position.distance_to(_drag_start_screen) > 12.0:
				_drag_has_moved = true
				_spawn_drag_ghost()
			if _drag_has_moved:
				_update_drag_ghost_position(mm.position)
		var hov_key: String = _raycast_hit_key(mm.position)
		if hov_key != _hovered_hit_key:
			_hovered_hit_key = hov_key
			_refresh_visuals()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_pointer_down(mb.position)
			else:
				_on_pointer_up(mb.position)


func _on_pointer_down(screen_pos: Vector2) -> void:
	if not GameManager.is_game_active or is_board_locked:
		return
	var hit_key: String = _raycast_hit_key(screen_pos)
	if hit_key.is_empty():
		return

	_set_camera_drag_locked(true)
	_drag_start_screen = screen_pos
	_drag_has_moved = false

	if hit_key.begins_with("num_"):
		_drag_active = true
		_drag_kind = "num"
		_drag_source_idx = int(hit_key.trim_prefix("num_"))
	elif hit_key.begins_with("pal_op_"):
		var op_idx: int = int(hit_key.trim_prefix("pal_op_"))
		_drag_active = true
		_drag_kind = "op"
		_drag_source_idx = op_idx
		_drag_op_symbol = PALETTE_OPS[op_idx]
	else:
		_drag_active = true
		_drag_kind = "click_only"
		_drag_source_idx = -1


func _on_pointer_up(screen_pos: Vector2) -> void:
	_set_camera_drag_locked(false)
	if not _drag_active:
		return

	var was_moved: bool = _drag_has_moved
	var kind: String = _drag_kind
	var src_idx: int = _drag_source_idx
	var op_sym: String = _drag_op_symbol
	_cancel_drag()

	if not GameManager.is_game_active or is_board_locked:
		return

	var target_key: String = _raycast_hit_key(screen_pos)

	if was_moved:
		if kind == "num" and target_key.begins_with("num_"):
			var dst_idx: int = int(target_key.trim_prefix("num_"))
			if dst_idx != src_idx and dst_idx >= 0 and dst_idx < 4:
				_swap_number_slots(src_idx, dst_idx)
				return
		elif kind == "op" and target_key.begins_with("op_slot_"):
			var slot_idx: int = int(target_key.trim_prefix("op_slot_"))
			if slot_idx >= 0 and slot_idx < 3:
				_set_operator_slot(slot_idx, op_sym)
				return

	# Treat as tap/click if not dragged onto another slot
	if not target_key.is_empty():
		_handle_tap_key(target_key)


func _spawn_drag_ghost() -> void:
	if _drag_ghost_node and is_instance_valid(_drag_ghost_node):
		_drag_ghost_node.queue_free()
	_drag_ghost_node = Node3D.new()
	add_child(_drag_ghost_node)

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.056
	cyl.bottom_radius = 0.058
	cyl.height = 0.020
	cyl.radial_segments = 24
	cyl.material = _mat_num_selected if _drag_kind == "num" else _mat_op_filled
	var m_inst := MeshInstance3D.new()
	m_inst.mesh = cyl
	_drag_ghost_node.add_child(m_inst)

	var lbl := Label3D.new()
	lbl.font = _font_hekayat
	lbl.font_size = 72
	lbl.outline_size = 16
	lbl.text = _fa_digits(number_slots[_drag_source_idx]) if _drag_kind == "num" else _display_op(_drag_op_symbol)
	lbl.modulate = Color(1.0, 0.96, 0.75)
	lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
	lbl.pixel_size = 0.00084
	lbl.position = Vector3(0.0, 0.013, 0.0)
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_drag_ghost_node.add_child(lbl)


func _update_drag_ghost_position(screen_pos: Vector2) -> void:
	if not _drag_ghost_node or not is_instance_valid(_drag_ghost_node):
		return
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, BOARD_SURFACE_Y + 0.055)
	var pt = plane.intersects_ray(from, dir)
	if pt != null:
		_drag_ghost_node.position = to_local(pt)


func _cancel_drag() -> void:
	_drag_active = false
	_drag_has_moved = false
	_drag_kind = ""
	_drag_source_idx = -1
	_drag_op_symbol = ""
	if _drag_ghost_node and is_instance_valid(_drag_ghost_node):
		_drag_ghost_node.queue_free()
		_drag_ghost_node = null
	_set_camera_drag_locked(false)


func _raycast_hit_key(screen_pos: Vector2) -> String:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return ""
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var to: Vector3 = from + dir * 12.0

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit.has("collider"):
		var col = hit["collider"]
		if col and col.has_meta("hit_key"):
			return str(col.get_meta("hit_key"))
	return ""


func _handle_tap_key(key: String) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _last_click_time) < 0.06:
		return
	_last_click_time = now

	if key == "sign_0":
		leading_minus = not leading_minus
		AudioManager.sfx_tap()
		_recalculate_and_refresh_ui()
		return

	if key.begins_with("num_"):
		var idx: int = int(key.trim_prefix("num_"))
		if selected_num_slot == -1:
			selected_num_slot = idx
			AudioManager.sfx_tap()
			_recalculate_and_refresh_ui()
		elif selected_num_slot == idx:
			selected_num_slot = -1
			AudioManager.sfx_tap()
			_recalculate_and_refresh_ui()
		else:
			var first_idx: int = selected_num_slot
			selected_num_slot = -1
			_swap_number_slots(first_idx, idx)
		return

	if key.begins_with("op_slot_"):
		var slot_idx: int = int(key.trim_prefix("op_slot_"))
		if not selected_palette_op.is_empty():
			_set_operator_slot(slot_idx, selected_palette_op)
		else:
			# 4=10 style quick-tap cycle: "" -> "+" -> "-" -> "x" -> "÷" -> "+"
			var cur_op: String = op_slots[slot_idx]
			var idx_in_pal: int = PALETTE_OPS.find(cur_op)
			var next_op: String = PALETTE_OPS[(idx_in_pal + 1) % PALETTE_OPS.size()]
			_set_operator_slot(slot_idx, next_op)
		return

	if key.begins_with("pal_op_"):
		var p_idx: int = int(key.trim_prefix("pal_op_"))
		var sym: String = PALETTE_OPS[p_idx]
		# If an empty operator slot exists on the track, fill it right away AND select this operator
		var empty_slot: int = op_slots.find("")
		if empty_slot != -1:
			selected_palette_op = sym
			_set_operator_slot(empty_slot, sym)
		else:
			if selected_palette_op == sym:
				selected_palette_op = ""
			else:
				selected_palette_op = sym
			AudioManager.sfx_tap()
			_recalculate_and_refresh_ui()
		return

	if key == "bracket_cycle":
		bracket_mode = (bracket_mode + 1) % BRACKET_SPANS.size()
		AudioManager.sfx_tap()
		_recalculate_and_refresh_ui()
		return

	if key == "btn_reset":
		AudioManager.sfx_button()
		reset_board()
		return

	if key == "btn_submit":
		_attempt_submit_solution()
		return


func _swap_number_slots(idx1: int, idx2: int) -> void:
	if idx1 < 0 or idx1 >= 4 or idx2 < 0 or idx2 >= 4 or idx1 == idx2:
		return
	var tmp: int = number_slots[idx1]
	number_slots[idx1] = number_slots[idx2]
	number_slots[idx2] = tmp
	AudioManager.play_sound("move_peace")

	for idx in [idx1, idx2]:
		var n_root: Node3D = num_tile_roots[idx]
		n_root.scale = Vector3(1.16, 1.16, 1.16)
		var tw := create_tween()
		tw.tween_property(n_root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_recalculate_and_refresh_ui()


func _set_operator_slot(slot_idx: int, op_sym: String) -> void:
	if slot_idx < 0 or slot_idx >= 3:
		return
	op_slots[slot_idx] = op_sym
	AudioManager.play_sound("add_peace")

	var o_root: Node3D = op_slot_roots[slot_idx]
	o_root.scale = Vector3(1.22, 1.22, 1.22)
	var tw := create_tween()
	tw.tween_property(o_root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_recalculate_and_refresh_ui()


func _attempt_submit_solution() -> void:
	if not GameManager.is_game_active or is_board_locked or round_solved_submitted:
		return
	if not let_send_result:
		if not has_valid_result:
			show_hint("ابتدا هر ۳ عملگر ریاضی را بین اعداد قرار دهید.")
		else:
			show_hint("حاصل عبارت فعلی %s است؛ باید دقیقاً برابر ۱۰ شود!" % _format_number_fa(current_result))
		AudioManager.play_sound("miss_turn")
		return

	round_solved_submitted = true
	set_board_locked(true)
	AudioManager.play_sound("win")
	send_move(Commands.Solve, "")
