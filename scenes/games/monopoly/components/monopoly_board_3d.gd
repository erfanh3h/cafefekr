extends Node3D

signal tile_clicked(tile_id: int)
signal dice_sanctuary_clicked()

const MonopolyData = preload("res://scenes/games/monopoly/components/monopoly_data.gd")
const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const SURFACE_Y: float = 0.038
const CORNER_POS: float = 0.500
const TILE_STEP: float = 0.119
const EDGE_START: float = 0.357
const CORNER_SIZE: float = 0.165
const EDGE_W: float = 0.114
const EDGE_D: float = 0.165

var players_count: int = 2
var _tile_centers: Array[Vector3] = []
var _tile_inward_dirs: Array[Vector3] = []
var _tile_owner_strips: Array[MeshInstance3D] = []
var _tile_mortgage_veils: Array[MeshInstance3D] = []
var _tile_house_roots: Array[Node3D] = []
var _tile_highlight_rings: Array[Node3D] = []
var _pawn_nodes: Dictionary = {} # gamer_id -> Node3D
var _pawn_positions: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0}
var _pawn_bankrupt: Dictionary = {1: false, 2: false, 3: false, 4: false}
var _pawn_in_jail: Dictionary = {1: false, 2: false, 3: false, 4: false}

var _board_root: Node3D = null
var _tiles_root: Node3D = null
var _pawns_root: Node3D = null
var _vfx_root: Node3D = null
var _dice_sanctuary: Node3D = null
var _dice_pivots: Array[Node3D] = []
var _dice_halo_ring: MeshInstance3D = null
var _center_roll_label: Label3D = null
var _active_tile_marker: MeshInstance3D = null

var _mat_wood_dark: StandardMaterial3D
var _mat_wood_trim: StandardMaterial3D
var _mat_felt_emerald: StandardMaterial3D
var _mat_brass_gold: StandardMaterial3D
var _mat_ivory_tile: StandardMaterial3D
var _mat_corner_tile: StandardMaterial3D
var _mat_mortgaged: StandardMaterial3D
var _mat_house_green: StandardMaterial3D
var _mat_hotel_crimson: StandardMaterial3D
var _mat_highlight_gold: StandardMaterial3D
var _mat_die_ivory: StandardMaterial3D
var _mat_die_chamfer: StandardMaterial3D
var _mat_pip_dark: StandardMaterial3D
var _mat_pip_red: StandardMaterial3D
var _mat_group_mats: Dictionary = {}
var _mat_faction_pawn: Dictionary = {}
var _mat_faction_owner: Dictionary = {}

var _dice_tween: Tween = null
var _move_tween: Tween = null
var _is_animating: bool = false
var _can_roll_highlight: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	_init_materials()
	_compute_tile_layout()
	_build_cabinet_and_tiles()
	_build_center_dice_sanctuary()
	_build_pawns(players_count)


func _process(delta: float) -> void:
	_pulse_time += delta * 3.6
	var s_pulse: float = 1.0 + 0.08 * sin(_pulse_time)
	if is_instance_valid(_dice_halo_ring) and _dice_halo_ring.visible:
		_dice_halo_ring.scale = Vector3(s_pulse, 1.0, s_pulse)
	if is_instance_valid(_active_tile_marker) and _active_tile_marker.visible:
		_active_tile_marker.scale = Vector3(s_pulse, 1.0, s_pulse)


func _init_materials() -> void:
	_mat_wood_dark = StandardMaterial3D.new()
	_mat_wood_dark.albedo_color = Color(0.14, 0.08, 0.05)
	_mat_wood_dark.roughness = 0.42
	_mat_wood_dark.metallic = 0.08

	_mat_wood_trim = StandardMaterial3D.new()
	_mat_wood_trim.albedo_color = Color(0.26, 0.14, 0.08)
	_mat_wood_trim.roughness = 0.34
	_mat_wood_trim.metallic = 0.12

	_mat_felt_emerald = StandardMaterial3D.new()
	_mat_felt_emerald.albedo_color = Color(0.07, 0.18, 0.13)
	_mat_felt_emerald.roughness = 0.86
	_mat_felt_emerald.metallic = 0.02

	_mat_brass_gold = StandardMaterial3D.new()
	_mat_brass_gold.albedo_color = Color(0.94, 0.78, 0.32)
	_mat_brass_gold.metallic = 0.76
	_mat_brass_gold.roughness = 0.24

	_mat_ivory_tile = StandardMaterial3D.new()
	_mat_ivory_tile.albedo_color = Color(0.95, 0.91, 0.82)
	_mat_ivory_tile.roughness = 0.32
	_mat_ivory_tile.metallic = 0.04

	_mat_corner_tile = StandardMaterial3D.new()
	_mat_corner_tile.albedo_color = Color(0.90, 0.84, 0.68)
	_mat_corner_tile.roughness = 0.30
	_mat_corner_tile.metallic = 0.08

	_mat_mortgaged = StandardMaterial3D.new()
	_mat_mortgaged.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_mortgaged.albedo_color = Color(0.12, 0.12, 0.16, 0.72)
	_mat_mortgaged.roughness = 0.60

	_mat_house_green = StandardMaterial3D.new()
	_mat_house_green.albedo_color = Color(0.12, 0.72, 0.28)
	_mat_house_green.roughness = 0.25
	_mat_house_green.metallic = 0.12

	_mat_hotel_crimson = StandardMaterial3D.new()
	_mat_hotel_crimson.albedo_color = Color(0.86, 0.12, 0.16)
	_mat_hotel_crimson.roughness = 0.20
	_mat_hotel_crimson.metallic = 0.22
	_mat_hotel_crimson.emission_enabled = true
	_mat_hotel_crimson.emission = Color(0.75, 0.08, 0.12) * 0.25

	_mat_highlight_gold = StandardMaterial3D.new()
	_mat_highlight_gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_highlight_gold.albedo_color = Color(1.0, 0.88, 0.22, 0.90)
	_mat_highlight_gold.emission_enabled = true
	_mat_highlight_gold.emission = Color(1.0, 0.84, 0.18) * 1.6
	_mat_highlight_gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for grp in MonopolyData.GROUP_COLORS.keys():
		var gm = StandardMaterial3D.new()
		gm.albedo_color = MonopolyData.GROUP_COLORS[grp]
		gm.roughness = 0.28
		gm.metallic = 0.10
		_mat_group_mats[grp] = gm

	for fid in MonopolyData.FACTION_COLORS.keys():
		var col: Color = MonopolyData.FACTION_COLORS[fid]
		var mp = StandardMaterial3D.new()
		mp.albedo_color = col
		mp.roughness = 0.16
		mp.metallic = 0.26
		mp.clearcoat_enabled = false
		mp.clearcoat = 0.88
		mp.clearcoat_roughness = 0.10
		mp.emission_enabled = true
		mp.emission = col * 0.20
		_mat_faction_pawn[fid] = mp

		var mo = StandardMaterial3D.new()
		mo.albedo_color = col
		mo.roughness = 0.25
		mo.metallic = 0.20
		mo.emission_enabled = true
		mo.emission = col * 0.45
		_mat_faction_owner[fid] = mo

	_mat_die_ivory = StandardMaterial3D.new()
	_mat_die_ivory.albedo_color = Color(0.99, 0.97, 0.93)
	_mat_die_ivory.roughness = 0.12
	_mat_die_ivory.metallic = 0.02

	_mat_die_chamfer = StandardMaterial3D.new()
	_mat_die_chamfer.albedo_color = Color(0.93, 0.89, 0.80)
	_mat_die_chamfer.roughness = 0.18
	_mat_die_chamfer.metallic = 0.08

	_mat_pip_dark = StandardMaterial3D.new()
	_mat_pip_dark.albedo_color = Color(0.05, 0.06, 0.10)
	_mat_pip_dark.roughness = 0.14
	_mat_pip_dark.metallic = 0.20

	_mat_pip_red = StandardMaterial3D.new()
	_mat_pip_red.albedo_color = Color(0.88, 0.10, 0.15)
	_mat_pip_red.roughness = 0.14
	_mat_pip_red.emission_enabled = true
	_mat_pip_red.emission = Color(0.75, 0.08, 0.12)
	_mat_pip_red.emission_energy_multiplier = 0.25


func _compute_tile_layout() -> void:
	_tile_centers.resize(32)
	_tile_inward_dirs.resize(32)

	# Bottom side: 0 (corner BR) -> 1..7 (right to left)
	_tile_centers[0] = Vector3(CORNER_POS, SURFACE_Y, CORNER_POS)
	_tile_inward_dirs[0] = Vector3(-0.707, 0.0, -0.707)
	for i in range(1, 8):
		_tile_centers[i] = Vector3(EDGE_START - float(i - 1) * TILE_STEP, SURFACE_Y, CORNER_POS)
		_tile_inward_dirs[i] = Vector3(0.0, 0.0, -1.0)

	# Left side: 8 (corner BL) -> 9..15 (bottom to top)
	_tile_centers[8] = Vector3(-CORNER_POS, SURFACE_Y, CORNER_POS)
	_tile_inward_dirs[8] = Vector3(0.707, 0.0, -0.707)
	for i in range(9, 16):
		_tile_centers[i] = Vector3(-CORNER_POS, SURFACE_Y, EDGE_START - float(i - 9) * TILE_STEP)
		_tile_inward_dirs[i] = Vector3(1.0, 0.0, 0.0)

	# Top side: 16 (corner TL) -> 17..23 (left to right)
	_tile_centers[16] = Vector3(-CORNER_POS, SURFACE_Y, -CORNER_POS)
	_tile_inward_dirs[16] = Vector3(0.707, 0.0, 0.707)
	for i in range(17, 24):
		_tile_centers[i] = Vector3(-EDGE_START + float(i - 17) * TILE_STEP, SURFACE_Y, -CORNER_POS)
		_tile_inward_dirs[i] = Vector3(0.0, 0.0, 1.0)

	# Right side: 24 (corner TR) -> 25..31 (top to bottom)
	_tile_centers[24] = Vector3(CORNER_POS, SURFACE_Y, -CORNER_POS)
	_tile_inward_dirs[24] = Vector3(-0.707, 0.0, 0.707)
	for i in range(25, 32):
		_tile_centers[i] = Vector3(CORNER_POS, SURFACE_Y, -EDGE_START + float(i - 25) * TILE_STEP)
		_tile_inward_dirs[i] = Vector3(-1.0, 0.0, 0.0)


func _build_cabinet_and_tiles() -> void:
	_board_root = Node3D.new()
	_board_root.name = "MonopolyBoardRoot"
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

	# 1. Luxury Walnut Cabinet Base (1.30m x 1.30m)
	var cab = MeshInstance3D.new()
	var cab_m = BoxMesh.new()
	cab_m.size = Vector3(1.30, 0.034, 1.30)
	cab.mesh = cab_m
	cab.position = Vector3(0.0, 0.017, 0.0)
	cab.material_override = _mat_wood_dark
	_board_root.add_child(cab)

	# Outer Brass Frame Bezel
	var bezel = MeshInstance3D.new()
	var bez_m = BoxMesh.new()
	bez_m.size = Vector3(1.22, 0.008, 1.22)
	bezel.mesh = bez_m
	bez.position = Vector3(0.0, SURFACE_Y - 0.003, 0.0)
	bezel.material_override = _mat_brass_gold
	_board_root.add_child(bezel)

	# Inner Emerald Baize Playfield
	var felt = MeshInstance3D.new()
	var felt_m = BoxMesh.new()
	felt_m.size = Vector3(0.815, 0.010, 0.815)
	felt.mesh = felt_m
	felt.position = Vector3(0.0, SURFACE_Y - 0.002, 0.0)
	felt.material_override = _mat_felt_emerald
	_board_root.add_child(felt)

	# Decorative Brass Inner Border Square
	var inner_brass = MeshInstance3D.new()
	var ib_m = BoxMesh.new()
	ib_m.size = Vector3(0.832, 0.006, 0.832)
	inner_brass.mesh = ib_m
	inner_brass.position = Vector3(0.0, SURFACE_Y - 0.003, 0.0)
	inner_brass.material_override = _mat_brass_gold
	_board_root.add_child(inner_brass)

	# Decorative Chance & Chest 3D Card Stacks on the Baize Felt
	_build_center_card_stack(Vector3(-0.22, SURFACE_Y + 0.004, -0.22), Color(0.86, 0.44, 0.12), "شانس")
	_build_center_card_stack(Vector3(0.22, SURFACE_Y + 0.004, 0.22), Color(0.16, 0.56, 0.82), "صندوق")

	# Build all 32 Perimeter Tiles
	_tile_owner_strips.resize(32)
	_tile_mortgage_veils.resize(32)
	_tile_house_roots.resize(32)
	_tile_highlight_rings.resize(32)

	for tid in range(32):
		_build_single_tile(tid)

	# Active tile highlight ring
	_active_tile_marker = _create_ring_mesh(0.078, 0.010, _mat_highlight_gold)
	_active_tile_marker.visible = false
	_vfx_root.add_child(_active_tile_marker)


func _build_center_card_stack(pos: Vector3, col: Color, title_fa: String) -> void:
	var st = Node3D.new()
	st.position = pos
	st.rotation_degrees.y = 35.0
	_board_root.add_child(st)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.28
	mat.metallic = 0.14

	var deck = MeshInstance3D.new()
	var dm = BoxMesh.new()
	dm.size = Vector3(0.145, 0.014, 0.095)
	deck.mesh = dm
	deck.position = Vector3(0.0, 0.007, 0.0)
	deck.material_override = mat
	st.add_child(deck)

	var lbl = Label3D.new()
	lbl.text = title_fa
	lbl.font = FontHekayat
	lbl.font_size = 38
	lbl.outline_size = 10
	lbl.pixel_size = 0.00085
	lbl.modulate = Color(1.0, 0.96, 0.82)
	lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.95)
	lbl.position = Vector3(0.0, 0.016, 0.0)
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	st.add_child(lbl)


func _build_single_tile(tid: int) -> void:
	var meta: Dictionary = MonopolyData.BOARD_TILES[tid]
	var center: Vector3 = _tile_centers[tid]
	var inward: Vector3 = _tile_inward_dirs[tid]
	var t_type: String = str(meta.get("type", "street"))
	var grp: String = str(meta.get("group", ""))
	var is_corner: bool = (tid % 8 == 0)
	var is_horiz: bool = (tid > 0 and tid < 8) or (tid > 16 and tid < 24)

	var tile_root = Node3D.new()
	tile_root.name = "Tile_%d" % tid
	tile_root.position = center
	_tiles_root.add_child(tile_root)

	# Rotate tile locally so local -Z points INWARD toward board center (on side tiles)
	var rot_y: float = 0.0
	if tid >= 9 and tid <= 15:
		rot_y = -PI * 0.5
	elif tid >= 17 and tid <= 23:
		rot_y = PI
	elif tid >= 25 and tid <= 31:
		rot_y = PI * 0.5
	tile_root.rotation.y = rot_y

	var w: float = CORNER_SIZE if is_corner else EDGE_W
	var d: float = CORNER_SIZE if is_corner else EDGE_D

	# Base Plaque
	var base = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(w, 0.012, d)
	base.mesh = bm
	base.position = Vector3(0.0, 0.006, 0.0)
	base.material_override = _mat_corner_tile if is_corner else _mat_ivory_tile
	tile_root.add_child(base)

	# Color Group Header Strip (along local -Z inward edge)
	if t_type == "street" and _mat_group_mats.has(grp):
		var band = MeshInstance3D.new()
		var bnd_m = BoxMesh.new()
		bnd_m.size = Vector3(w * 0.96, 0.005, 0.036)
		band.mesh = bnd_m
		band.position = Vector3(0.0, 0.013, -d * 0.5 + 0.020)
		band.material_override = _mat_group_mats[grp]
		tile_root.add_child(band)
	elif t_type in ("railroad", "utility"):
		var b_mat: StandardMaterial3D = _mat_group_mats.get(t_type, _mat_brass_gold)
		var band2 = MeshInstance3D.new()
		var bnd_m2 = BoxMesh.new()
		bnd_m2.size = Vector3(w * 0.94, 0.004, 0.028)
		band2.mesh = bnd_m2
		band2.position = Vector3(0.0, 0.013, -d * 0.5 + 0.017)
		band2.material_override = b_mat
		tile_root.add_child(band2)
	elif t_type in ("chance", "chest", "tax"):
		var accent = StandardMaterial3D.new()
		if t_type == "chance":
			accent.albedo_color = Color(0.90, 0.45, 0.12)
		elif t_type == "chest":
			accent.albedo_color = Color(0.16, 0.56, 0.86)
		else:
			accent.albedo_color = Color(0.55, 0.14, 0.18)
		var band3 = MeshInstance3D.new()
		var bnd_m3 = BoxMesh.new()
		bnd_m3.size = Vector3(w * 0.92, 0.004, 0.024)
		band3.mesh = bnd_m3
		band3.position = Vector3(0.0, 0.013, -d * 0.5 + 0.015)
		band3.material_override = accent
		tile_root.add_child(band3)

	# Corner accent border
	if is_corner:
		var c_mat = StandardMaterial3D.new()
		match str(meta.get("subtype", "")):
			"go": c_mat.albedo_color = Color(0.14, 0.68, 0.34)
			"jail": c_mat.albedo_color = Color(0.88, 0.48, 0.12)
			"free_parking": c_mat.albedo_color = Color(0.18, 0.52, 0.88)
			_: c_mat.albedo_color = Color(0.84, 0.16, 0.20)
		var c_trim = MeshInstance3D.new()
		var ctm = BoxMesh.new()
		ctm.size = Vector3(w * 0.86, 0.004, d * 0.86)
		c_trim.mesh = ctm
		c_trim.position = Vector3(0.0, 0.011, 0.0)
		c_trim.material_override = c_mat
		tile_root.add_child(c_trim)

	# Owner Faction Glowing Strip along outer edge (+Z local)
	var owner_strip = MeshInstance3D.new()
	var osm = BoxMesh.new()
	osm.size = Vector3(w * 0.92, 0.006, 0.018)
	owner_strip.mesh = osm
	owner_strip.position = Vector3(0.0, 0.014, d * 0.5 - 0.012)
	owner_strip.visible = false
	tile_root.add_child(owner_strip)
	_tile_owner_strips[tid] = owner_strip

	# Mortgage Dark Veil
	var veil = MeshInstance3D.new()
	var vm = BoxMesh.new()
	vm.size = Vector3(w * 0.96, 0.003, d * 0.96)
	veil.mesh = vm
	veil.position = Vector3(0.0, 0.015, 0.0)
	veil.material_override = _mat_mortgaged
	veil.visible = false
	tile_root.add_child(veil)
	_tile_mortgage_veils[tid] = veil

	# Houses / Hotel Container (sits on top of the inward color band)
	var h_root = Node3D.new()
	h_root.name = "HousesRoot"
	h_root.position = Vector3(0.0, 0.016, -d * 0.5 + 0.020)
	tile_root.add_child(h_root)
	_tile_house_roots[tid] = h_root

	# Tile Name + Price Label3D (Large, Crisp, High-Contrast!)
	var lbl = Label3D.new()
	lbl.font = FontHekayat
	lbl.font_size = 40 if is_corner else 34
	lbl.outline_size = 11
	lbl.pixel_size = 0.00058 if is_corner else 0.00050
	lbl.modulate = Color(1.0, 0.98, 0.92) if is_corner else Color(0.10, 0.07, 0.04)
	lbl.outline_modulate = Color(0.05, 0.03, 0.02, 0.95) if is_corner else Color(1.0, 0.97, 0.88, 0.92)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.width = 230.0 if is_corner else 200.0
	var price: int = int(meta.get("price", 0))
	var tax_amt: int = int(meta.get("tax_amount", 0))
	var name_txt: String = str(meta.get("name", ""))
	if price > 0:
		lbl.text = "%s\n$%s" % [name_txt, MonopolyData.fa_num(price)]
	elif tax_amt > 0:
		lbl.text = "%s\n-%s$" % [name_txt, MonopolyData.fa_num(tax_amt)]
	elif is_corner and tid == 0:
		lbl.text = "شروع\n+۲۰۰$"
	else:
		lbl.text = name_txt
	lbl.position = Vector3(0.0, 0.0155, 0.006 if not is_corner else 0.0)
	# Keep Top edge text right-side up for the player's camera view!
	var text_yaw: float = 0.0
	if tid >= 17 and tid <= 23:
		text_yaw = 180.0
	lbl.rotation_degrees = Vector3(-90.0, text_yaw, 0.0)
	tile_root.add_child(lbl)

	# Keep unused var warning silent
	if is_horiz or inward.length() > 0.0:
		pass


func _build_center_dice_sanctuary() -> void:
	_dice_sanctuary = Node3D.new()
	_dice_sanctuary.name = "DiceSanctuary"
	_dice_sanctuary.position = Vector3(0.0, SURFACE_Y, 0.0)
	_board_root.add_child(_dice_sanctuary)

	# Octagonal Brass & Emerald Arena Pedestal
	var base = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.145
	bm.bottom_radius = 0.158
	bm.height = 0.010
	bm.radial_segments = 8
	base.mesh = bm
	base.position = Vector3(0.0, 0.005, 0.0)
	base.material_override = _mat_brass_gold
	_dice_sanctuary.add_child(base)

	var pad = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.128
	pm.bottom_radius = 0.132
	pm.height = 0.012
	pm.radial_segments = 8
	pad.mesh = pm
	pad.position = Vector3(0.0, 0.006, 0.0)
	pad.material_override = _mat_felt_emerald
	_dice_sanctuary.add_child(pad)

	_dice_halo_ring = _create_ring_mesh(0.152, 0.012, _mat_highlight_gold)
	_dice_halo_ring.position = Vector3(0.0, 0.013, 0.0)
	_dice_halo_ring.visible = false
	_dice_sanctuary.add_child(_dice_halo_ring)

	# Dual Yatzy-Style 3D Ivory Dice
	_dice_pivots.clear()
	for offset_x in [-0.052, 0.052]:
		var piv = Node3D.new()
		piv.position = Vector3(offset_x, 0.044, -0.010)
		_dice_sanctuary.add_child(piv)
		var die_mesh = _create_yatzy_die_model(0.064)
		piv.add_child(die_mesh)
		_dice_pivots.append(piv)

	# Title Crest Above Dice
	var crest = Label3D.new()
	crest.text = "مونوپولی"
	crest.font = FontHekayat
	crest.font_size = 54
	crest.outline_size = 14
	crest.pixel_size = 0.00090
	crest.modulate = Color(1.0, 0.88, 0.38)
	crest.outline_modulate = Color(0.08, 0.04, 0.02, 0.96)
	crest.position = Vector3(0.0, 0.014, -0.225)
	crest.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_dice_sanctuary.add_child(crest)

	# Center Roll Sum / Status Readout Below Dice
	_center_roll_label = Label3D.new()
	_center_roll_label.text = "آماده پرتاب تاس"
	_center_roll_label.font = FontHekayat
	_center_roll_label.font_size = 40
	_center_roll_label.outline_size = 12
	_center_roll_label.pixel_size = 0.00080
	_center_roll_label.modulate = Color(0.98, 0.95, 0.86)
	_center_roll_label.outline_modulate = Color(0.04, 0.02, 0.01, 0.95)
	_center_roll_label.position = Vector3(0.0, 0.014, 0.210)
	_center_roll_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_dice_sanctuary.add_child(_center_roll_label)


func _create_yatzy_die_model(sz: float) -> Node3D:
	var root = Node3D.new()
	var chamfer_core = MeshInstance3D.new()
	var core_box = BoxMesh.new()
	core_box.size = Vector3(sz * 0.94, sz * 0.94, sz * 0.94)
	core_box.material = _mat_die_chamfer
	chamfer_core.mesh = core_box
	root.add_child(chamfer_core)

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

	_add_3d_die_pips(root, sz * 0.5)
	return root


func _add_3d_die_pips(die_root: Node3D, half_s: float) -> void:
	var o: float = half_s * 0.54
	var face_configs = [
		{"normal": Vector3.UP, "right": Vector3.RIGHT, "fwd": Vector3.BACK, "rot_deg": Vector3(0, 0, 0), "pips": [Vector2(0, 0)], "red": true, "big": true},
		{"normal": Vector3.DOWN, "right": Vector3.RIGHT, "fwd": Vector3.FORWARD, "rot_deg": Vector3(0, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0), Vector2(o, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.BACK, "right": Vector3.RIGHT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [Vector2(-o, -o), Vector2(o, o)], "red": false, "big": false},
		{"normal": Vector3.FORWARD, "right": Vector3.LEFT, "fwd": Vector3.DOWN, "rot_deg": Vector3(90, 0, 0), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(0, 0), Vector2(-o, o), Vector2(o, o)
		], "red": false, "big": false},
		{"normal": Vector3.RIGHT, "right": Vector3.FORWARD, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [Vector2(-o, -o), Vector2(0, 0), Vector2(o, o)], "red": false, "big": false},
		{"normal": Vector3.LEFT, "right": Vector3.BACK, "fwd": Vector3.DOWN, "rot_deg": Vector3(0, 0, 90), "pips": [
			Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)
		], "red": true, "big": false},
	]
	var pip_big = CylinderMesh.new()
	pip_big.top_radius = half_s * 0.25
	pip_big.bottom_radius = half_s * 0.25
	pip_big.height = 0.0018
	pip_big.radial_segments = 16
	var pip_small = CylinderMesh.new()
	pip_small.top_radius = half_s * 0.155
	pip_small.bottom_radius = half_s * 0.155
	pip_small.height = 0.0018
	pip_small.radial_segments = 14
	for fc in face_configs:
		var n: Vector3 = fc["normal"]
		var r: Vector3 = fc["right"]
		var f: Vector3 = fc["fwd"]
		var rot_d: Vector3 = fc["rot_deg"]
		var pm = pip_big if fc["big"] else pip_small
		var mat = _mat_pip_red if fc["red"] else _mat_pip_dark
		for p2 in fc["pips"]:
			var pip = MeshInstance3D.new()
			pip.mesh = pm
			pip.material_override = mat
			pip.position = n * (half_s + 0.0004) + r * p2.x + f * p2.y
			pip.rotation_degrees = rot_d
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


func _create_ring_mesh(radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = maxf(0.005, radius - thickness * 0.5)
	tm.outer_radius = radius + thickness * 0.5
	tm.rings = 24
	tm.ring_segments = 12
	mi.mesh = tm
	mi.material_override = mat
	mi.scale = Vector3(1.0, 0.16, 1.0)
	return mi


func _create_royal_pawn(gamer_id: int) -> Node3D:
	var root = Node3D.new()
	root.name = "Pawn_P%d" % gamer_id
	var p_mat: StandardMaterial3D = _mat_faction_pawn.get(gamer_id, _mat_brass_gold)

	var rim = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = 0.022
	rm.bottom_radius = 0.024
	rm.height = 0.006
	rm.radial_segments = 20
	rim.mesh = rm
	rim.position = Vector3(0.0, 0.003, 0.0)
	rim.material_override = _mat_brass_gold
	root.add_child(rim)

	var body = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.010
	bm.bottom_radius = 0.019
	bm.height = 0.042
	bm.radial_segments = 20
	body.mesh = bm
	body.position = Vector3(0.0, 0.027, 0.0)
	body.material_override = p_mat
	root.add_child(body)

	var collar = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.015
	cm.bottom_radius = 0.015
	cm.height = 0.005
	cm.radial_segments = 16
	collar.mesh = cm
	collar.position = Vector3(0.0, 0.046, 0.0)
	collar.material_override = _mat_brass_gold
	root.add_child(collar)

	var head = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.015
	hm.height = 0.030
	hm.radial_segments = 18
	hm.rings = 10
	head.mesh = hm
	head.position = Vector3(0.0, 0.059, 0.0)
	head.material_override = p_mat
	root.add_child(head)

	return root


func _build_pawns(p_count: int) -> void:
	players_count = clampi(p_count, 2, 4)
	if not is_instance_valid(_pawns_root):
		return
	for ch in _pawns_root.get_children():
		ch.queue_free()
	_pawn_nodes.clear()
	for pid in range(1, players_count + 1):
		var pawn = _create_royal_pawn(pid)
		_pawns_root.add_child(pawn)
		_pawn_nodes[pid] = pawn
	_refresh_pawn_positions(true)


func set_players_count(p_count: int) -> void:
	if p_count != players_count or _pawn_nodes.size() != p_count:
		_build_pawns(p_count)


func _get_slot_world_pos(tile_id: int, gamer_id: int, in_jail: bool) -> Vector3:
	var tid: int = clampi(tile_id, 0, 31)
	var base: Vector3 = _tile_centers[tid] + Vector3(0.0, 0.015, 0.0)
	var offsets: Array[Vector3] = [
		Vector3(-0.022, 0.0, -0.022),
		Vector3( 0.022, 0.0, -0.022),
		Vector3(-0.022, 0.0,  0.022),
		Vector3( 0.022, 0.0,  0.022),
	]
	var slot_idx: int = clampi(gamer_id - 1, 0, 3)
	var off: Vector3 = offsets[slot_idx]
	if tid == 8 and in_jail:
		off *= 0.65
	return base + off


func _refresh_pawn_positions(snap_all: bool = false) -> void:
	for pid in _pawn_nodes.keys():
		var p_node: Node3D = _pawn_nodes[pid]
		if not is_instance_valid(p_node):
			continue
		var is_b: bool = bool(_pawn_bankrupt.get(pid, false))
		p_node.visible = not is_b
		if is_b:
			continue
		if snap_all:
			p_node.position = _get_slot_world_pos(int(_pawn_positions.get(pid, 0)), pid, bool(_pawn_in_jail.get(pid, false)))


func sync_board_visuals(players_arr: Array, tiles_arr: Array, active_turn: int, can_roll: bool, last_dice: Array) -> void:
	var p_cnt: int = clampi(players_arr.size(), 2, 4) if players_arr.size() >= 2 else players_count
	if p_cnt != players_count:
		_build_pawns(p_cnt)

	_can_roll_highlight = can_roll
	if is_instance_valid(_dice_halo_ring):
		_dice_halo_ring.visible = can_roll

	if last_dice.size() >= 2 and int(last_dice[0]) > 0 and int(last_dice[1]) > 0 and not _is_animating:
		var d1: int = int(last_dice[0])
		var d2: int = int(last_dice[1])
		if _dice_pivots.size() >= 2:
			_dice_pivots[0].rotation = _get_die_target_rotation(d1)
			_dice_pivots[1].rotation = _get_die_target_rotation(d2)
		if is_instance_valid(_center_roll_label):
			var sum_d: int = d1 + d2
			_center_roll_label.text = "تاس %s + %s = %s" % [MonopolyData.fa_num(d1), MonopolyData.fa_num(d2), MonopolyData.fa_num(sum_d)]
	elif not _is_animating and is_instance_valid(_center_roll_label):
		_center_roll_label.text = "نوبت پرتاب تاس" if can_roll else "مونوپولی کافه فکر"

	for pv in players_arr:
		if typeof(pv) != TYPE_DICTIONARY:
			continue
		var pd: Dictionary = pv as Dictionary
		var gid: int = int(pd.get("gamer_id", 0))
		if gid < 1 or gid > 4:
			continue
		_pawn_positions[gid] = int(pd.get("position", 0))
		_pawn_bankrupt[gid] = bool(pd.get("bankrupt", false))
		_pawn_in_jail[gid] = bool(pd.get("in_jail", false))

	if not _is_animating:
		_refresh_pawn_positions(true)

	# Highlight active player's current tile
	if is_instance_valid(_active_tile_marker):
		var act_pos: int = int(_pawn_positions.get(active_turn, -1))
		if act_pos >= 0 and act_pos < _tile_centers.size():
			_active_tile_marker.position = _tile_centers[act_pos] + Vector3(0.0, 0.017, 0.0)
			_active_tile_marker.visible = true
		else:
			_active_tile_marker.visible = false

	# Update Tile Ownership, Mortgage Veils, and 3D Houses/Hotels
	for tv in tiles_arr:
		if typeof(tv) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tv as Dictionary
		var tid: int = int(td.get("id", -1))
		if tid < 0 or tid >= 32:
			continue
		var owner_id: int = int(td.get("owner", 0))
		var houses: int = int(td.get("houses", 0))
		var mortgaged: bool = bool(td.get("mortgaged", false))

		var strip: MeshInstance3D = _tile_owner_strips[tid]
		if is_instance_valid(strip):
			if owner_id >= 1 and owner_id <= 4:
				strip.material_override = _mat_faction_owner[owner_id]
				strip.visible = true
			else:
				strip.visible = false

		var veil: MeshInstance3D = _tile_mortgage_veils[tid]
		if is_instance_valid(veil):
			veil.visible = mortgaged

		_rebuild_tile_houses(tid, houses)


func _rebuild_tile_houses(tid: int, houses: int) -> void:
	var h_root: Node3D = _tile_house_roots[tid]
	if not is_instance_valid(h_root):
		return
	if h_root.get_meta("last_houses", -1) == houses:
		return
	h_root.set_meta("last_houses", houses)
	for ch in h_root.get_children():
		ch.queue_free()
	if houses <= 0:
		return
	if houses >= 5:
		# Grand Crimson Hotel with Gold Trim
		var hotel = MeshInstance3D.new()
		var hm = BoxMesh.new()
		hm.size = Vector3(0.044, 0.032, 0.024)
		hotel.mesh = hm
		hotel.position = Vector3(0.0, 0.016, 0.0)
		hotel.material_override = _mat_hotel_crimson
		h_root.add_child(hotel)
		var roof = MeshInstance3D.new()
		var rfm = BoxMesh.new()
		rfm.size = Vector3(0.048, 0.006, 0.028)
		roof.mesh = rfm
		roof.position = Vector3(0.0, 0.034, 0.0)
		roof.material_override = _mat_brass_gold
		h_root.add_child(roof)
	else:
		var start_x: float = -float(houses - 1) * 0.0115
		for i in range(houses):
			var hx: float = start_x + float(i) * 0.023
			var house = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.018, 0.020, 0.018)
			house.mesh = bm
			house.position = Vector3(hx, 0.010, 0.0)
			house.material_override = _mat_house_green
			h_root.add_child(house)


func animate_dice_and_hop(gamer_id: int, d1: int, d2: int, path: Array, in_jail: bool, on_done: Callable = Callable()) -> void:
	_is_animating = true
	if _dice_tween and _dice_tween.is_valid():
		_dice_tween.kill()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	AudioManager.play_sound("dice")
	if _dice_pivots.size() >= 2:
		_dice_tween = create_tween().set_parallel(true)
		var vals: Array[int] = [d1, d2]
		for idx in range(2):
			var piv: Node3D = _dice_pivots[idx]
			var target_rot = _get_die_target_rotation(vals[idx])
			piv.rotation = target_rot + Vector3(PI * 4.0, PI * 3.0, PI * 2.0)
			_dice_tween.tween_property(piv, "rotation", target_rot, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_dice_tween.tween_property(piv, "position:y", 0.115, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_dice_tween.chain().tween_property(piv, "position:y", 0.044, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_center_roll_label):
		_center_roll_label.text = "تاس %s + %s = %s" % [MonopolyData.fa_num(d1), MonopolyData.fa_num(d2), MonopolyData.fa_num(d1 + d2)]

	var pawn: Node3D = _pawn_nodes.get(gamer_id, null)
	if path.is_empty() or not is_instance_valid(pawn):
		get_tree().create_timer(0.46).timeout.connect(func():
			_is_animating = false
			_refresh_pawn_positions(true)
			if on_done.is_valid():
				on_done.call()
		)
		return

	_move_tween = create_tween()
	_move_tween.tween_interval(0.32)
	var prev_pos: Vector3 = pawn.position
	# Cap step duration so long jumps (e.g. Go via Chance) stay brisk (~0.8s max)
	var step_dur: float = clampf(0.95 / maxf(1.0, float(path.size())), 0.035, 0.095)
	for step_tid in path:
		var tid_i: int = int(step_tid)
		var wp: Vector3 = _get_slot_world_pos(tid_i, gamer_id, in_jail)
		var mid: Vector3 = (prev_pos + wp) * 0.5 + Vector3(0.0, 0.055, 0.0)
		_move_tween.tween_property(pawn, "position", mid, step_dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_move_tween.tween_property(pawn, "position", wp, step_dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_move_tween.tween_callback(func(): AudioManager.sfx_tap())
		prev_pos = wp
	_move_tween.tween_callback(func():
		_is_animating = false
		_refresh_pawn_positions(true)
		if on_done.is_valid():
			on_done.call()
	)


func handle_board_tap(screen_pos: Vector2) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return false
	var ray_orig: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane := Plane(global_transform.basis.y.normalized(), global_position.y + SURFACE_Y + 0.012)
	var hit: Variant = plane.intersects_ray(ray_orig, ray_dir)
	if hit == null:
		return false
	var local_pt: Vector3 = to_local(hit)
	var pt2 := Vector2(local_pt.x, local_pt.z)

	# 1. Center Dice Sanctuary tap
	if pt2.length() <= 0.175:
		dice_sanctuary_clicked.emit()
		return true

	# 2. Perimeter Tile tap
	var best_tid: int = -1
	var best_dist: float = 0.092
	for tid in range(32):
		var c: Vector3 = _tile_centers[tid]
		var d: float = pt2.distance_to(Vector2(c.x, c.z))
		if d < best_dist:
			best_dist = d
			best_tid = tid
	if best_tid >= 0:
		tile_clicked.emit(best_tid)
		return true
	return false
