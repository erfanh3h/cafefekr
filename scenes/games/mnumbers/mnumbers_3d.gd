class_name MNumbers3D
extends "res://scripts/games/base_game_board.gd"

# Royal Persian Match Numbers (کشف اعداد - MNumbers) 3D Physical Board
# 100% server parity with kafehfekrbackend/Entities/Games/MNumbers/__init__.py
# and kafehfekr/lib/Feature/MNumbers/Controllers/mnumbers_controller.dart:
# - 6x6 grid of 36 recessed obsidian wells (indices 0..35, 18 pairs of numbers 1..18)
# - 36 double-sided 3D lathe-turned Memory Medallions with smooth 180-degree mid-air 3D flip
# - Select 1st tile -> elevates with crisp player-colored rim (tap again to deselect)
# - Select 2nd tile -> dispatches Select_Peace {"index1": idx1, "index2": idx2}
# - Server broadcasts Peace_Selected {"user", "index1", "value1", "index2", "value2", "is_correct"}:
#   * If is_correct: permanently flips face-up in Player 1 (Ruby Red) or Player 2 (Sapphire Blue),
#     increments score (+1 pair), and updates side reserve trays
#   * If not is_correct: reveals both numbers for the 2s result window, then flips back face-down
# - Left & right mahogany reserve trays holding 18 3D score medallions per player (no floating text)

const TOTAL_TILES: int = 36
const GRID_SIZE: int = 6
const MAX_PAIRS: int = 18

const BOARD_SURFACE_Y: float = 0.048
const CELL_SPACING: float = 0.168
const GRID_MIN_XZ: float = -0.420 # -2.5 * 0.168

const TRAY_RED_X: float = -0.765
const TRAY_BLUE_X: float = 0.765

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")

# Logical State
var board_owner: Array[int] = []  # 0 = unmatched, 1 = Player 1 (Red), 2 = Player 2 (Blue)
var board_values: Array[int] = [] # 0 = unknown, 1..18 = revealed value
var equipped_index: int = -1
var loading_indices: Array[int] = []
var revealed_temp_indices: Array[int] = []
var hovered_tile_id: int = -1

var player1_score: int = 0
var player2_score: int = 0

var last_click_time: float = 0.0
var _last_click_frame: int = -1
var _raycast_down_pos: Vector2 = Vector2.ZERO
var _raycast_down_time: float = 0.0
var _raycast_is_down: bool = false

# 3D Containers & Nodes
var board_decor_root: Node3D
var cells_root: Node3D
var tiles_root: Node3D
var vfx_root: Node3D
var tray_red_root: Node3D
var tray_blue_root: Node3D

var cell_centers: Array[Vector3] = []
var cell_areas: Array[Area3D] = []
var tile_roots: Array[Node3D] = []
var tile_pivots: Array[Node3D] = []
var tile_front_bodies: Array[MeshInstance3D] = []
var tile_front_rims: Array[MeshInstance3D] = []
var tile_back_bodies: Array[MeshInstance3D] = []
var tile_back_rims: Array[MeshInstance3D] = []
var tile_select_rings: Array[MeshInstance3D] = []
var tile_labels: Array[Label3D] = []
var tile_tweens: Dictionary = {} # idx -> Tween
var _flip_back_generation: int = 0

var tray_red_pieces: Array[Node3D] = []
var tray_blue_pieces: Array[Node3D] = []

# Shared Luxury Materials
var _mat_gold_24k: StandardMaterial3D
var _mat_platinum: StandardMaterial3D
var _mat_brass_dark: StandardMaterial3D
var _mat_obsidian_well: StandardMaterial3D
var _mat_card_back_body: StandardMaterial3D
var _mat_card_back_ring: StandardMaterial3D
var _mat_card_back_boss: StandardMaterial3D
var _mat_red_body: StandardMaterial3D
var _mat_blue_body: StandardMaterial3D
var _mat_reveal_body: StandardMaterial3D
var _mat_select_red: StandardMaterial3D
var _mat_select_blue: StandardMaterial3D
var _mat_hover_red: StandardMaterial3D
var _mat_hover_blue: StandardMaterial3D
var _mat_reveal_ring: StandardMaterial3D


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
	game_type = GameTypes.MNUMBERS
	add_to_group("board")
	board_owner.resize(TOTAL_TILES)
	board_owner.fill(0)
	board_values.resize(TOTAL_TILES)
	board_values.fill(0)

	_init_shared_materials()
	_precompute_geometry()
	_build_board_3d()
	reset_board()
	super._ready()


func _init_shared_materials() -> void:
	_mat_gold_24k = StandardMaterial3D.new()
	_mat_gold_24k.albedo_color = Color(0.86, 0.70, 0.28)
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
	_mat_obsidian_well.albedo_color = Color(0.09, 0.08, 0.07)
	_mat_obsidian_well.metallic = 0.15
	_mat_obsidian_well.roughness = 0.44
	_mat_obsidian_well.clearcoat_enabled = true
	_mat_obsidian_well.clearcoat = 0.45

	# Unclaimed Face-Down Medallion: Dark Onyx-Slate Lacquer with Brushed Pewter/Bronze Trim
	_mat_card_back_body = StandardMaterial3D.new()
	_mat_card_back_body.albedo_color = Color(0.18, 0.19, 0.23)
	_mat_card_back_body.metallic = 0.28
	_mat_card_back_body.roughness = 0.28
	_mat_card_back_body.clearcoat_enabled = true
	_mat_card_back_body.clearcoat = 0.82
	_mat_card_back_body.clearcoat_roughness = 0.14

	_mat_card_back_ring = StandardMaterial3D.new()
	_mat_card_back_ring.albedo_color = Color(0.56, 0.50, 0.40)
	_mat_card_back_ring.metallic = 0.78
	_mat_card_back_ring.roughness = 0.28

	_mat_card_back_boss = StandardMaterial3D.new()
	_mat_card_back_boss.albedo_color = Color(0.28, 0.29, 0.34)
	_mat_card_back_boss.metallic = 0.55
	_mat_card_back_boss.roughness = 0.30

	# Player 1 Claimed: Imperial Ruby Crimson Lacquer
	_mat_red_body = StandardMaterial3D.new()
	_mat_red_body.albedo_color = Color(0.80, 0.10, 0.14)
	_mat_red_body.metallic = 0.22
	_mat_red_body.roughness = 0.20
	_mat_red_body.clearcoat_enabled = true
	_mat_red_body.clearcoat = 0.90
	_mat_red_body.clearcoat_roughness = 0.10

	# Player 2 Claimed: Royal Sapphire Blue Lacquer
	_mat_blue_body = StandardMaterial3D.new()
	_mat_blue_body.albedo_color = Color(0.10, 0.36, 0.82)
	_mat_blue_body.metallic = 0.25
	_mat_blue_body.roughness = 0.20
	_mat_blue_body.clearcoat_enabled = true
	_mat_blue_body.clearcoat = 0.90
	_mat_blue_body.clearcoat_roughness = 0.10

	# Temporary Reveal Surface (when 2 flipped tiles do not match)
	_mat_reveal_body = StandardMaterial3D.new()
	_mat_reveal_body.albedo_color = Color(0.32, 0.26, 0.16)
	_mat_reveal_body.metallic = 0.35
	_mat_reveal_body.roughness = 0.26
	_mat_reveal_body.clearcoat_enabled = true
	_mat_reveal_body.clearcoat = 0.80

	# Selection / Hover Rings
	_mat_select_red = StandardMaterial3D.new()
	_mat_select_red.albedo_color = Color(1.0, 0.26, 0.28, 0.92)
	_mat_select_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_select_red.emission_enabled = true
	_mat_select_red.emission = Color(1.0, 0.20, 0.22)
	_mat_select_red.emission_energy_multiplier = 1.45

	_mat_select_blue = StandardMaterial3D.new()
	_mat_select_blue.albedo_color = Color(0.26, 0.68, 1.0, 0.92)
	_mat_select_blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_select_blue.emission_enabled = true
	_mat_select_blue.emission = Color(0.20, 0.58, 1.0)
	_mat_select_blue.emission_energy_multiplier = 1.45

	_mat_hover_red = StandardMaterial3D.new()
	_mat_hover_red.albedo_color = Color(1.0, 0.32, 0.34, 0.55)
	_mat_hover_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_red.emission_enabled = true
	_mat_hover_red.emission = Color(0.95, 0.24, 0.26)
	_mat_hover_red.emission_energy_multiplier = 0.75

	_mat_hover_blue = StandardMaterial3D.new()
	_mat_hover_blue.albedo_color = Color(0.32, 0.72, 1.0, 0.55)
	_mat_hover_blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_hover_blue.emission_enabled = true
	_mat_hover_blue.emission = Color(0.24, 0.62, 0.98)
	_mat_hover_blue.emission_energy_multiplier = 0.75

	_mat_reveal_ring = StandardMaterial3D.new()
	_mat_reveal_ring.albedo_color = Color(0.96, 0.78, 0.28, 0.88)
	_mat_reveal_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_reveal_ring.emission_enabled = true
	_mat_reveal_ring.emission = Color(0.92, 0.70, 0.20)
	_mat_reveal_ring.emission_energy_multiplier = 1.10


func _precompute_geometry() -> void:
	cell_centers.resize(TOTAL_TILES)
	for idx in range(TOTAL_TILES):
		var row: int = idx / GRID_SIZE
		var col: int = idx % GRID_SIZE
		var cx: float = GRID_MIN_XZ + float(col) * CELL_SPACING
		var cz: float = GRID_MIN_XZ + float(row) * CELL_SPACING
		cell_centers[idx] = Vector3(cx, BOARD_SURFACE_Y, cz)


func _build_board_3d() -> void:
	board_decor_root = Node3D.new()
	board_decor_root.name = "BoardDecorRoot"
	add_child(board_decor_root)

	cells_root = Node3D.new()
	cells_root.name = "CellsRoot"
	add_child(cells_root)

	tiles_root = Node3D.new()
	tiles_root.name = "TilesRoot"
	add_child(tiles_root)

	vfx_root = Node3D.new()
	vfx_root.name = "VFXRoot"
	add_child(vfx_root)

	_build_grid_wire_lines()
	_build_36_memory_wells_and_medallions()
	_build_side_reserve_trays()


func _build_grid_wire_lines() -> void:
	var grid_span: float = float(GRID_SIZE) * CELL_SPACING
	var wire_h := BoxMesh.new()
	wire_h.size = Vector3(grid_span, 0.003, 0.0035)
	wire_h.material = _mat_brass_dark

	var wire_v := BoxMesh.new()
	wire_v.size = Vector3(0.0035, 0.003, grid_span)
	wire_v.material = _mat_brass_dark

	var half_span: float = grid_span * 0.5
	for i in range(1, GRID_SIZE):
		var offset: float = -half_span + float(i) * CELL_SPACING

		var lh := MeshInstance3D.new()
		lh.mesh = wire_h
		lh.position = Vector3(0.0, BOARD_SURFACE_Y - 0.0005, offset)
		board_decor_root.add_child(lh)

		var lv := MeshInstance3D.new()
		lv.mesh = wire_v
		lv.position = Vector3(offset, BOARD_SURFACE_Y - 0.0005, 0.0)
		board_decor_root.add_child(lv)


func _build_36_memory_wells_and_medallions() -> void:
	cell_areas.resize(TOTAL_TILES)
	tile_roots.resize(TOTAL_TILES)
	tile_pivots.resize(TOTAL_TILES)
	tile_front_bodies.resize(TOTAL_TILES)
	tile_front_rims.resize(TOTAL_TILES)
	tile_back_bodies.resize(TOTAL_TILES)
	tile_back_rims.resize(TOTAL_TILES)
	tile_select_rings.resize(TOTAL_TILES)
	tile_labels.resize(TOTAL_TILES)

	# Recessed circular well in the board surface
	var well_mesh := CylinderMesh.new()
	well_mesh.top_radius = 0.072
	well_mesh.bottom_radius = 0.068
	well_mesh.height = 0.006
	well_mesh.radial_segments = 32
	well_mesh.material = _mat_obsidian_well

	var well_bezel_mesh := TorusMesh.new()
	well_bezel_mesh.inner_radius = 0.068
	well_bezel_mesh.outer_radius = 0.074
	well_bezel_mesh.rings = 28
	well_bezel_mesh.ring_segments = 12
	well_bezel_mesh.material = _mat_brass_dark

	var hit_shape := BoxShape3D.new()
	hit_shape.size = Vector3(CELL_SPACING * 0.94, 0.055, CELL_SPACING * 0.94)

	# Medallion Half-Cylinder Meshes (Back = +Y when rotation.x == 0, Front = -Y when rotation.x == 0)
	var half_body_mesh := CylinderMesh.new()
	half_body_mesh.top_radius = 0.063
	half_body_mesh.bottom_radius = 0.065
	half_body_mesh.height = 0.010
	half_body_mesh.radial_segments = 32

	var rim_torus_mesh := TorusMesh.new()
	rim_torus_mesh.inner_radius = 0.052
	rim_torus_mesh.outer_radius = 0.0635
	rim_torus_mesh.rings = 32
	rim_torus_mesh.ring_segments = 14

	var back_boss_mesh := CylinderMesh.new()
	back_boss_mesh.top_radius = 0.022
	back_boss_mesh.bottom_radius = 0.026
	back_boss_mesh.height = 0.003
	back_boss_mesh.radial_segments = 8
	back_boss_mesh.material = _mat_card_back_boss

	var back_inner_ring_mesh := TorusMesh.new()
	back_inner_ring_mesh.inner_radius = 0.032
	back_inner_ring_mesh.outer_radius = 0.036
	back_inner_ring_mesh.rings = 24
	back_inner_ring_mesh.ring_segments = 10
	back_inner_ring_mesh.material = _mat_card_back_ring

	var equator_mesh := CylinderMesh.new()
	equator_mesh.top_radius = 0.0655
	equator_mesh.bottom_radius = 0.0655
	equator_mesh.height = 0.004
	equator_mesh.radial_segments = 32
	equator_mesh.material = _mat_gold_24k

	var select_ring_mesh := TorusMesh.new()
	select_ring_mesh.inner_radius = 0.066
	select_ring_mesh.outer_radius = 0.075
	select_ring_mesh.rings = 32
	select_ring_mesh.ring_segments = 12

	for idx in range(TOTAL_TILES):
		var center: Vector3 = cell_centers[idx]

		# 1. Recessed Well & Area3D Hitbox
		var well_inst := MeshInstance3D.new()
		well_inst.mesh = well_mesh
		well_inst.position = Vector3(center.x, BOARD_SURFACE_Y - 0.001, center.z)
		cells_root.add_child(well_inst)

		var bezel_inst := MeshInstance3D.new()
		bezel_inst.mesh = well_bezel_mesh
		bezel_inst.position = Vector3(center.x, BOARD_SURFACE_Y + 0.001, center.z)
		cells_root.add_child(bezel_inst)

		var area := Area3D.new()
		area.name = "TileArea_%d" % idx
		area.position = Vector3(center.x, BOARD_SURFACE_Y + 0.012, center.z)
		area.set_meta("tile_id", idx)

		var col := CollisionShape3D.new()
		col.shape = hit_shape
		area.add_child(col)

		area.mouse_entered.connect(func(): _on_tile_mouse_entered(idx))
		area.mouse_exited.connect(func(): _on_tile_mouse_exited(idx))
		cells_root.add_child(area)
		cell_areas[idx] = area

		# 2. Interactive 3D Medallion Node
		var t_root := Node3D.new()
		t_root.name = "Tile_%d" % idx
		t_root.position = Vector3(center.x, BOARD_SURFACE_Y + 0.011, center.z)
		tiles_root.add_child(t_root)
		tile_roots[idx] = t_root

		var pivot := Node3D.new()
		pivot.name = "FlipPivot"
		t_root.add_child(pivot)
		tile_pivots[idx] = pivot

		var eq := MeshInstance3D.new()
		eq.mesh = equator_mesh
		pivot.add_child(eq)

		# Back Face (+Y when FlipPivot.rotation.x == 0.0 -> Face-Down Hidden State)
		var back_face := Node3D.new()
		back_face.name = "BackFace"
		pivot.add_child(back_face)

		var b_body := MeshInstance3D.new()
		b_body.mesh = half_body_mesh
		b_body.material_override = _mat_card_back_body
		b_body.position = Vector3(0.0, 0.005, 0.0)
		back_face.add_child(b_body)
		tile_back_bodies[idx] = b_body

		var b_rim := MeshInstance3D.new()
		b_rim.mesh = rim_torus_mesh
		b_rim.material_override = _mat_card_back_ring
		b_rim.position = Vector3(0.0, 0.010, 0.0)
		b_rim.scale = Vector3(1.0, 0.42, 1.0)
		back_face.add_child(b_rim)
		tile_back_rims[idx] = b_rim

		var b_inner := MeshInstance3D.new()
		b_inner.mesh = back_inner_ring_mesh
		b_inner.position = Vector3(0.0, 0.0105, 0.0)
		b_inner.scale = Vector3(1.0, 0.40, 1.0)
		back_face.add_child(b_inner)

		var b_boss := MeshInstance3D.new()
		b_boss.mesh = back_boss_mesh
		b_boss.position = Vector3(0.0, 0.0108, 0.0)
		back_face.add_child(b_boss)

		# Front Face (-Y when FlipPivot.rotation.x == 0.0 -> Becomes +Y when FlipPivot.rotation.x == PI)
		var front_face := Node3D.new()
		front_face.name = "FrontFace"
		front_face.rotation.x = PI
		pivot.add_child(front_face)

		var f_body := MeshInstance3D.new()
		f_body.mesh = half_body_mesh
		f_body.material_override = _mat_reveal_body
		f_body.position = Vector3(0.0, 0.005, 0.0)
		front_face.add_child(f_body)
		tile_front_bodies[idx] = f_body

		var f_rim := MeshInstance3D.new()
		f_rim.mesh = rim_torus_mesh
		f_rim.material_override = _mat_gold_24k
		f_rim.position = Vector3(0.0, 0.010, 0.0)
		f_rim.scale = Vector3(1.0, 0.42, 1.0)
		front_face.add_child(f_rim)
		tile_front_rims[idx] = f_rim

		# Selection / Hover Ring around Medallion
		var sel_ring := MeshInstance3D.new()
		sel_ring.mesh = select_ring_mesh
		sel_ring.material_override = _mat_select_red
		sel_ring.position = Vector3(0.0, 0.002, 0.0)
		sel_ring.scale = Vector3(1.0, 0.45, 1.0)
		sel_ring.visible = false
		t_root.add_child(sel_ring)
		tile_select_rings[idx] = sel_ring

		# Crisp Persian Number Label on top of revealed medallion (never inverted or mirrored)
		var lbl := Label3D.new()
		lbl.name = "NumberLabel"
		lbl.font = _font_hekayat
		lbl.font_size = 76
		lbl.outline_size = 18
		lbl.modulate = Color(1.0, 0.98, 0.92, 1.0)
		lbl.outline_modulate = Color(0.04, 0.03, 0.05, 0.98)
		lbl.pixel_size = 0.00088
		lbl.position = Vector3(0.0, 0.0145, 0.0)
		lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lbl.visible = false
		t_root.add_child(lbl)
		tile_labels[idx] = lbl


func _build_side_reserve_trays() -> void:
	tray_red_root = _create_single_tray("TrayRed", TRAY_RED_X, 1)
	add_child(tray_red_root)

	tray_blue_root = _create_single_tray("TrayBlue", TRAY_BLUE_X, 2)
	add_child(tray_blue_root)

	tray_red_pieces.clear()
	tray_blue_pieces.clear()

	# 18 pairs total on a 36-tile board -> 18 reserve score medallions per side in 2 columns of 9
	for i in range(MAX_PAIRS):
		var col: int = i % 2
		var row: int = i / 2
		var px: float = -0.032 + float(col) * 0.064
		var pz: float = -0.360 + float(row) * 0.090
		var py: float = 0.022

		var p_red := _create_reserve_crest_mesh(1)
		p_red.position = Vector3(px, py, pz)
		p_red.scale = Vector3(0.68, 0.68, 0.68)
		tray_red_root.add_child(p_red)
		tray_red_pieces.append(p_red)

		var p_blue := _create_reserve_crest_mesh(2)
		p_blue.position = Vector3(px, py, pz)
		p_blue.scale = Vector3(0.68, 0.68, 0.68)
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
	base_mesh.size = Vector3(0.165, 0.022, 0.90)
	base_mesh.material = mat_wood
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0.0, 0.008, 0.0)
	root.add_child(base_inst)

	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(0.138, 0.006, 0.85)
	bed_mesh.material = _mat_obsidian_well
	var bed_inst := MeshInstance3D.new()
	bed_inst.mesh = bed_mesh
	bed_inst.position = Vector3(0.0, 0.018, 0.0)
	root.add_child(bed_inst)

	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(0.168, 0.005, 0.012)
	trim_mesh.material = _mat_gold_24k if gamer_id == 1 else _mat_platinum

	for z_sign in [-1.0, 1.0]:
		var trim := MeshInstance3D.new()
		trim.mesh = trim_mesh
		trim.position = Vector3(0.0, 0.021, z_sign * 0.438)
		root.add_child(trim)

	return root


func _create_reserve_crest_mesh(gamer_id: int) -> Node3D:
	var root := Node3D.new()
	var body_mat: StandardMaterial3D = _mat_red_body if gamer_id == 1 else _mat_blue_body
	var trim_mat: StandardMaterial3D = _mat_gold_24k if gamer_id == 1 else _mat_platinum

	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 0.044
	base_cyl.bottom_radius = 0.048
	base_cyl.height = 0.015
	base_cyl.radial_segments = 24
	base_cyl.material = body_mat
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_cyl
	base_inst.position.y = 0.0075
	root.add_child(base_inst)

	var rim_torus := TorusMesh.new()
	rim_torus.inner_radius = 0.034
	rim_torus.outer_radius = 0.044
	rim_torus.rings = 24
	rim_torus.ring_segments = 12
	rim_torus.material = trim_mat
	var rim_inst := MeshInstance3D.new()
	rim_inst.mesh = rim_torus
	rim_inst.position.y = 0.015
	rim_inst.scale = Vector3(1.0, 0.45, 1.0)
	root.add_child(rim_inst)

	return root


# --- BaseGameBoard Lifecycle Hooks ---

func reset_board() -> void:
	_flip_back_generation += 1
	board_owner.fill(0)
	board_values.fill(0)
	equipped_index = -1
	loading_indices.clear()
	revealed_temp_indices.clear()
	hovered_tile_id = -1
	player1_score = 0
	player2_score = 0

	for k in tile_tweens.keys():
		var tw: Tween = tile_tweens[k]
		if tw and tw.is_valid():
			tw.kill()
	tile_tweens.clear()

	if vfx_root and is_instance_valid(vfx_root):
		for child in vfx_root.get_children():
			child.queue_free()

	for idx in range(TOTAL_TILES):
		_snap_tile_visual(idx, 0, 0, false)

	_sync_reserve_trays()
	_sync_hud_scores()


func cleanup_board() -> void:
	_flip_back_generation += 1
	for k in tile_tweens.keys():
		var tw: Tween = tile_tweens[k]
		if tw and tw.is_valid():
			tw.kill()
	tile_tweens.clear()


func setup_board(game_data: Dictionary) -> void:
	reset_board()
	if game_data.has("board"):
		sync_board_state(game_data["board"])
	if game_data.has("scores") and typeof(game_data["scores"]) == TYPE_ARRAY and (game_data["scores"] as Array).size() >= 2:
		player1_score = int(game_data["scores"][0])
		player2_score = int(game_data["scores"][1])
		_sync_hud_scores()
		_sync_reserve_trays()


func on_start_game() -> void:
	_update_all_tile_rings()


func on_turn_changed(turn: int, is_me: bool) -> void:
	current_turn = turn
	is_my_turn = is_me
	is_board_locked = not is_me
	equipped_index = -1
	loading_indices.clear()
	_flip_back_unmatched_revealed_tiles()
	_update_all_tile_rings()
	if is_me and GameManager.is_game_active:
		AudioManager.play_sound("start_turn")


func on_piece_selected(user_id: int, _target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id: int = int(extra.get("user", extra.get("gamer_id", user_id)))
	var index1: int = int(extra.get("index1", -1))
	var index2: int = int(extra.get("index2", -1))
	var value1: int = int(extra.get("value1", 0))
	var value2: int = int(extra.get("value2", 0))
	var is_correct: bool = bool(extra.get("is_correct", false))

	if index1 < 0 or index1 >= TOTAL_TILES or index2 < 0 or index2 >= TOTAL_TILES:
		return

	equipped_index = -1
	loading_indices.clear()
	_flip_back_unmatched_revealed_tiles()

	board_values[index1] = value1
	board_values[index2] = value2

	if is_correct:
		board_owner[index1] = gamer_id
		board_owner[index2] = gamer_id
		if gamer_id == 1:
			player1_score += 1
		elif gamer_id == 2:
			player2_score += 1
		else:
			_recalculate_scores_from_board()

		_sync_hud_scores()
		_sync_reserve_trays()

		_animate_flip_tile(index1, value1, gamer_id, true)
		_animate_flip_tile(index2, value2, gamer_id, true)
		_spawn_match_vfx(index1, index2, gamer_id)
		AudioManager.play_sound("add_peace")

		var hud = _get_hud()
		if hud and hud.has_method("start_wait_timer"):
			var v_fa: String = _fa_digits(value1)
			var msg: String = "🎯 جفت عدد %s کشف شد! (+۱ امتیاز)" % v_fa
			hud.start_wait_timer(2, msg)
	else:
		revealed_temp_indices = [index1, index2]
		_animate_flip_tile(index1, value1, gamer_id, false)
		_animate_flip_tile(index2, value2, gamer_id, false)
		AudioManager.play_sound("move_peace")

		var hud = _get_hud()
		if hud and hud.has_method("start_wait_timer"):
			var v1_fa: String = _fa_digits(value1)
			var v2_fa: String = _fa_digits(value2)
			var msg: String = "🔍 بررسی کارت‌ها (%s و %s)..." % [v1_fa, v2_fa]
			hud.start_wait_timer(2, msg)

		_flip_back_generation += 1
		var gen: int = _flip_back_generation
		get_tree().create_timer(1.85).timeout.connect(func():
			if not is_instance_valid(self) or gen != _flip_back_generation:
				return
			_flip_back_unmatched_revealed_tiles()
		)

	_update_all_tile_rings()


func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var arr: Array = board_data
	if arr.size() != TOTAL_TILES:
		return

	_flip_back_generation += 1
	equipped_index = -1
	loading_indices.clear()
	revealed_temp_indices.clear()

	for idx in range(TOTAL_TILES):
		var item = arr[idx]
		var eq_user: int = 0
		var val: int = 0
		if typeof(item) == TYPE_DICTIONARY:
			eq_user = int(item.get("equipped_user", 0))
			val = int(item.get("value", 0))
		board_owner[idx] = eq_user
		board_values[idx] = val
		_snap_tile_visual(idx, val, eq_user, eq_user != 0)

	_recalculate_scores_from_board()
	_sync_hud_scores()
	_sync_reserve_trays()
	_update_all_tile_rings()


func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board"):
			sync_board_state(g_data["board"])
		if g_data.has("scores") and typeof(g_data["scores"]) == TYPE_ARRAY and (g_data["scores"] as Array).size() >= 2:
			player1_score = int(g_data["scores"][0])
			player2_score = int(g_data["scores"][1])
		else:
			_recalculate_scores_from_board()
		_sync_hud_scores()
		_sync_reserve_trays()
	_update_all_tile_rings()


func _recalculate_scores_from_board() -> void:
	var p1_tiles: int = 0
	var p2_tiles: int = 0
	for idx in range(TOTAL_TILES):
		if board_owner[idx] == 1:
			p1_tiles += 1
		elif board_owner[idx] == 2:
			p2_tiles += 1
	player1_score = p1_tiles / 2
	player2_score = p2_tiles / 2


func _recalculate_scores_from_boxes() -> void:
	# Hook called by main.gd before game result dialog
	if player1_score == 0 and player2_score == 0:
		_recalculate_scores_from_board()


func _sync_hud_scores() -> void:
	GameManager.p1_score = player1_score
	GameManager.p2_score = player2_score
	var hud = _get_hud()
	if hud and hud.has_method("update_scores"):
		hud.update_scores(player1_score, player2_score)


func _sync_reserve_trays() -> void:
	var red_remaining: int = clampi(MAX_PAIRS - player1_score, 0, MAX_PAIRS)
	var blue_remaining: int = clampi(MAX_PAIRS - player2_score, 0, MAX_PAIRS)
	for i in range(tray_red_pieces.size()):
		if is_instance_valid(tray_red_pieces[i]):
			tray_red_pieces[i].visible = (i < red_remaining)
	for i in range(tray_blue_pieces.size()):
		if is_instance_valid(tray_blue_pieces[i]):
			tray_blue_pieces[i].visible = (i < blue_remaining)


func _get_hud() -> Node:
	var main_node = get_tree().current_scene
	if main_node and is_instance_valid(main_node) and "base_game_hud" in main_node:
		return main_node.base_game_hud
	return null


# --- 3D Medallion Flip & Visual State Helpers ---

func _snap_tile_visual(idx: int, val: int, owner_id: int, is_face_up: bool) -> void:
	if tile_tweens.has(idx):
		var old_tw: Tween = tile_tweens[idx]
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		tile_tweens.erase(idx)

	var t_root: Node3D = tile_roots[idx]
	var pivot: Node3D = tile_pivots[idx]
	var f_body: MeshInstance3D = tile_front_bodies[idx]
	var f_rim: MeshInstance3D = tile_front_rims[idx]
	var lbl: Label3D = tile_labels[idx]
	var center: Vector3 = cell_centers[idx]

	t_root.position = Vector3(center.x, BOARD_SURFACE_Y + 0.011, center.z)
	t_root.scale = Vector3.ONE

	if is_face_up:
		pivot.rotation = Vector3(PI, 0.0, 0.0)
		if owner_id == 1:
			f_body.material_override = _mat_red_body
			f_rim.material_override = _mat_gold_24k
		elif owner_id == 2:
			f_body.material_override = _mat_blue_body
			f_rim.material_override = _mat_platinum
		else:
			f_body.material_override = _mat_reveal_body
			f_rim.material_override = _mat_gold_24k
		lbl.text = _fa_digits(val) if val > 0 else ""
		lbl.visible = (val > 0)
		lbl.scale = Vector3.ONE
	else:
		pivot.rotation = Vector3.ZERO
		lbl.visible = false
		lbl.text = ""


func _animate_flip_tile(idx: int, val: int, gamer_id: int, is_matched: bool) -> void:
	if tile_tweens.has(idx):
		var old_tw: Tween = tile_tweens[idx]
		if old_tw and old_tw.is_valid():
			old_tw.kill()

	var t_root: Node3D = tile_roots[idx]
	var pivot: Node3D = tile_pivots[idx]
	var f_body: MeshInstance3D = tile_front_bodies[idx]
	var f_rim: MeshInstance3D = tile_front_rims[idx]
	var lbl: Label3D = tile_labels[idx]
	var center: Vector3 = cell_centers[idx]
	var base_y: float = BOARD_SURFACE_Y + 0.011

	if is_matched:
		if gamer_id == 1:
			f_body.material_override = _mat_red_body
			f_rim.material_override = _mat_gold_24k
		else:
			f_body.material_override = _mat_blue_body
			f_rim.material_override = _mat_platinum
	else:
		f_body.material_override = _mat_reveal_body
		f_rim.material_override = _mat_gold_24k if gamer_id == 1 else _mat_platinum

	lbl.text = _fa_digits(val)
	lbl.visible = false

	var tw := create_tween()
	tile_tweens[idx] = tw

	# Phase 1: Leap up and rotate halfway (0 -> PI/2)
	tw.set_parallel(true)
	tw.tween_property(t_root, "position:y", base_y + 0.075, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:x", PI * 0.5, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Midpoint: Show crisp Persian number and complete flip to PI while landing
	tw.chain().tween_callback(func():
		if not is_instance_valid(lbl):
			return
		lbl.visible = true
		lbl.scale = Vector3(0.4, 0.4, 0.4)
	)
	tw.chain().set_parallel(true)
	tw.tween_property(pivot, "rotation:x", PI, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t_root, "position:y", base_y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_flip_back_face_down(idx: int) -> void:
	if board_owner[idx] != 0:
		return
	if tile_tweens.has(idx):
		var old_tw: Tween = tile_tweens[idx]
		if old_tw and old_tw.is_valid():
			old_tw.kill()

	var t_root: Node3D = tile_roots[idx]
	var pivot: Node3D = tile_pivots[idx]
	var lbl: Label3D = tile_labels[idx]
	var base_y: float = BOARD_SURFACE_Y + 0.011

	var tw := create_tween()
	tile_tweens[idx] = tw

	tw.set_parallel(true)
	tw.tween_property(t_root, "position:y", base_y + 0.055, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:x", PI * 0.5, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(func():
		if is_instance_valid(lbl):
			lbl.visible = false
			lbl.text = ""
	)
	tw.chain().set_parallel(true)
	tw.tween_property(pivot, "rotation:x", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t_root, "position:y", base_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flip_back_unmatched_revealed_tiles() -> void:
	if revealed_temp_indices.is_empty():
		return
	var to_flip: Array[int] = revealed_temp_indices.duplicate()
	revealed_temp_indices.clear()
	for idx in to_flip:
		if idx >= 0 and idx < TOTAL_TILES and board_owner[idx] == 0:
			board_values[idx] = 0
			_animate_flip_back_face_down(idx)
	_update_all_tile_rings()


func _update_all_tile_rings() -> void:
	var my_idx: int = GameManager.my_player_index
	var sel_mat: StandardMaterial3D = _mat_select_red if my_idx == 1 else _mat_select_blue
	var hov_mat: StandardMaterial3D = _mat_hover_red if my_idx == 1 else _mat_hover_blue
	var base_y: float = BOARD_SURFACE_Y + 0.011

	for idx in range(TOTAL_TILES):
		var ring: MeshInstance3D = tile_select_rings[idx]
		var t_root: Node3D = tile_roots[idx]
		if not is_instance_valid(ring) or not is_instance_valid(t_root):
			continue

		if board_owner[idx] != 0:
			ring.visible = false
			continue

		if revealed_temp_indices.has(idx):
			ring.visible = true
			ring.material_override = _mat_reveal_ring
			continue

		if equipped_index == idx or loading_indices.has(idx):
			ring.visible = true
			ring.material_override = sel_mat
			if not tile_tweens.has(idx) or not tile_tweens[idx].is_running():
				t_root.position.y = base_y + 0.020
			continue

		if is_my_turn and not is_board_locked and hovered_tile_id == idx:
			ring.visible = true
			ring.material_override = hov_mat
			if not tile_tweens.has(idx) or not tile_tweens[idx].is_running():
				t_root.position.y = base_y + 0.008
		else:
			ring.visible = false
			if not tile_tweens.has(idx) or not tile_tweens[idx].is_running():
				t_root.position.y = base_y


func _spawn_match_vfx(idx1: int, idx2: int, gamer_id: int) -> void:
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.32, 0.30, 0.90) if gamer_id == 1 else Color(0.30, 0.72, 1.0, 0.90)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.75, 0.25)
	ring_mat.emission_energy_multiplier = 1.65

	for idx in [idx1, idx2]:
		var center: Vector3 = cell_centers[idx]
		var torus := TorusMesh.new()
		torus.inner_radius = 0.045
		torus.outer_radius = 0.062
		torus.rings = 28
		torus.ring_segments = 12
		torus.material = ring_mat

		var ring_inst := MeshInstance3D.new()
		ring_inst.mesh = torus
		ring_inst.position = Vector3(center.x, BOARD_SURFACE_Y + 0.016, center.z)
		ring_inst.scale = Vector3(0.7, 0.4, 0.7)
		vfx_root.add_child(ring_inst)

		var tw := create_tween().set_parallel(true)
		tw.tween_property(ring_inst, "scale", Vector3(1.55, 0.4, 1.55), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			if is_instance_valid(ring_inst):
				ring_inst.queue_free()
		)


# --- Input & Raycast Handling ---

func _on_tile_mouse_entered(tile_id: int) -> void:
	if hovered_tile_id != tile_id:
		hovered_tile_id = tile_id
		_update_all_tile_rings()


func _on_tile_mouse_exited(tile_id: int) -> void:
	if hovered_tile_id == tile_id:
		hovered_tile_id = -1
		_update_all_tile_rings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var hov_id: int = _raycast_tile_at_screen_pos(mm.position)
		if hov_id != hovered_tile_id:
			hovered_tile_id = hov_id
			_update_all_tile_rings()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_raycast_is_down = true
				_raycast_down_pos = mb.position
				_raycast_down_time = Time.get_ticks_msec() / 1000.0
			else:
				if _raycast_is_down:
					_raycast_is_down = false
					var dist: float = mb.position.distance_to(_raycast_down_pos)
					var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _raycast_down_time
					if dist <= 24.0 and elapsed <= 0.85:
						var hit_tile: int = _raycast_tile_at_screen_pos(mb.position)
						if hit_tile != -1:
							_attempt_select_tile(hit_tile)


func _raycast_tile_at_screen_pos(screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return -1

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
		if col and col.has_meta("tile_id"):
			return int(col.get_meta("tile_id"))

	# Fallback mathematical board-plane intersection so taps between or on edges of medallions never miss
	var board_plane := Plane(Vector3.UP, BOARD_SURFACE_Y + 0.011)
	var world_pt = board_plane.intersects_ray(from, dir)
	if world_pt != null:
		var local_pt: Vector3 = to_local(world_pt)
		var best_id: int = -1
		var best_dist: float = CELL_SPACING * 0.54
		for idx in range(TOTAL_TILES):
			var c: Vector3 = cell_centers[idx]
			var d: float = Vector2(local_pt.x, local_pt.z).distance_to(Vector2(c.x, c.z))
			if d < best_dist:
				best_dist = d
				best_id = idx
		return best_id

	return -1


func _attempt_select_tile(tile_id: int) -> void:
	if not GameManager.is_game_active:
		return
	if tile_id < 0 or tile_id >= TOTAL_TILES:
		return

	var cur_frame: int = Engine.get_process_frames()
	var now: float = Time.get_ticks_msec() / 1000.0
	if cur_frame == _last_click_frame or (now - last_click_time) < 0.08:
		return
	_last_click_frame = cur_frame
	last_click_time = now

	if is_board_locked:
		return

	if not is_my_turn:
		show_hint("نوبت شما نیست؛ لطفاً منتظر حرکت حریف بمانید.")
		AudioManager.play_sound("miss_turn")
		return

	if board_owner[tile_id] != 0:
		show_hint("این خانه قبلاً کشف شده است؛ خانه دیگری انتخاب کنید.")
		AudioManager.play_sound("miss_turn")
		return

	if equipped_index != -1:
		# Tapping the same 1st tile again deselects it (matches MNumbersController.onEachButtonTap)
		if tile_id == equipped_index:
			equipped_index = -1
			AudioManager.sfx_tap()
			_update_all_tile_rings()
			return

		var idx1: int = equipped_index
		var idx2: int = tile_id
		equipped_index = -1
		loading_indices = [idx1, idx2]
		set_board_locked(true)
		is_my_turn = false
		AudioManager.sfx_tap()
		_update_all_tile_rings()

		send_move(Commands.Select_Peace, {"index1": idx1, "index2": idx2})
	else:
		equipped_index = tile_id
		AudioManager.sfx_tap()
		_update_all_tile_rings()
