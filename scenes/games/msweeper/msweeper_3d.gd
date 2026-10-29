extends BaseGameBoard
class_name MSweeper3D

const GRID_SIZE := 8
const TOTAL_CELLS := 64
const TOTAL_MINES := 10
const TOTAL_SAFE := 54

const STATE_HIDDEN := 0
const STATE_SAFE := 1
const STATE_MINE_HIT := 2
const STATE_FLAG_CORRECT := 3
const STATE_FLAG_WRONG := 4

# Dimensions tuned to fit comfortably inside the central cafe table arena (-0.82 to +0.82)
const CABINET_W := 1.24
const CABINET_D := 1.32
const CABINET_H := 0.044

const GRID_CENTER_Z := -0.105
const CELL_W := 0.118
const CELL_GAP := 0.008
const CELL_STEP := 0.126 # 8 * 0.118 + 7 * 0.008 = 1.000m total grid width

const CONSOLE_Z := 0.505
const LONG_PRESS_DURATION := 0.35

var grid_root: Node3D
var console_root: Node3D
var vfx_root: Node3D

# Per-cell nodes & state
var cell_roots: Array[Node3D] = []
var cell_cap_pivots: Array[Node3D] = []
var cell_cap_meshes: Array[MeshInstance3D] = []
var cell_base_meshes: Array[MeshInstance3D] = []
var cell_rim_meshes: Array[MeshInstance3D] = []
var cell_label_3ds: Array[Label3D] = []
var cell_ornament_roots: Array[Node3D] = []

var cell_states: Array[int] = []
var cell_adj_counts: Array[int] = []
var waving_flag_segments: Array[Dictionary] = []
var smoldering_craters: Array[Node3D] = []

# Counters & Console UI
var remaining_flags: int = TOTAL_MINES
var safe_remaining: int = TOTAL_SAFE
var flags_counter_label: Label3D
var safe_counter_label: Label3D
var hint_banner_label: Label3D

# Input / Hold-to-Flag state
var _down_cell_idx: int = -1
var _down_pos: Vector2 = Vector2.ZERO
var _down_time: float = 0.0
var _long_press_triggered: bool = false
var _hold_indicator_root: Node3D = null
var _hold_outer_ring: MeshInstance3D = null
var _hold_inner_ring: MeshInstance3D = null
var _hold_flag_preview: Node3D = null
var _smoke_spawn_accum: float = 0.0

# Shared Materials
var mat_cabinet_wood: StandardMaterial3D
var mat_cabinet_trim: StandardMaterial3D
var mat_recess_well: StandardMaterial3D
var mat_cap_unrevealed_a: StandardMaterial3D
var mat_cap_unrevealed_b: StandardMaterial3D
var mat_cap_hover: StandardMaterial3D
var mat_cap_holding: StandardMaterial3D
var mat_safe_zero: StandardMaterial3D
var mat_safe_numbered: StandardMaterial3D
var mat_mine_crater: StandardMaterial3D
var mat_flag_correct_base: StandardMaterial3D
var mat_flag_wrong_base: StandardMaterial3D
var mat_rim_brass: StandardMaterial3D
var mat_rim_emerald: StandardMaterial3D
var mat_rim_crimson: StandardMaterial3D
var mat_rim_gold_glow: StandardMaterial3D
var mat_mine_iron: StandardMaterial3D
var mat_mine_core_red: StandardMaterial3D
var mat_mine_core_green: StandardMaterial3D
var mat_flag_pole: StandardMaterial3D
var mat_flag_cloth_red: StandardMaterial3D
var mat_flag_cloth_gold: StandardMaterial3D
var mat_wrong_cross: StandardMaterial3D

const NUMBER_COLORS := {
	1: Color(0.25, 0.78, 1.0),   # Crisp Sky Cyan
	2: Color(0.28, 0.95, 0.52),  # Vivid Emerald Green
	3: Color(1.0, 0.42, 0.35),   # Warm Coral Red
	4: Color(0.75, 0.48, 1.0),   # Royal Amethyst Purple
	5: Color(1.0, 0.68, 0.20),   # Golden Amber
	6: Color(0.20, 0.92, 0.88),  # Turquoise
	7: Color(0.98, 0.35, 0.78),  # Magenta Rose
	8: Color(1.0, 0.95, 0.75)    # Ivory Gold
}

func _ready() -> void:
	super._ready()
	_init_materials()
	_init_state_arrays()
	_build_board_cabinet()
	_build_grid_cells()
	_build_bottom_console()
	_build_hold_indicator()
	_update_console_labels()

func _init_state_arrays() -> void:
	cell_states.resize(TOTAL_CELLS)
	cell_adj_counts.resize(TOTAL_CELLS)
	for i in range(TOTAL_CELLS):
		cell_states[i] = STATE_HIDDEN
		cell_adj_counts[i] = 0

func _init_materials() -> void:
	mat_cabinet_wood = StandardMaterial3D.new()
	mat_cabinet_wood.albedo_color = Color(0.14, 0.09, 0.06)
	mat_cabinet_wood.roughness = 0.38
	mat_cabinet_wood.metallic = 0.12

	mat_cabinet_trim = StandardMaterial3D.new()
	mat_cabinet_trim.albedo_color = Color(0.85, 0.68, 0.28)
	mat_cabinet_trim.metallic = 0.82
	mat_cabinet_trim.roughness = 0.24
	mat_cabinet_trim.emission_enabled = true
	mat_cabinet_trim.emission = Color(0.85, 0.65, 0.22)
	mat_cabinet_trim.emission_energy_multiplier = 0.14

	mat_recess_well = StandardMaterial3D.new()
	mat_recess_well.albedo_color = Color(0.06, 0.11, 0.09)
	mat_recess_well.roughness = 0.72
	mat_recess_well.metallic = 0.15

	# Alternating subtle tactician slate-emerald bevel caps
	mat_cap_unrevealed_a = StandardMaterial3D.new()
	mat_cap_unrevealed_a.albedo_color = Color(0.16, 0.27, 0.23)
	mat_cap_unrevealed_a.roughness = 0.34
	mat_cap_unrevealed_a.metallic = 0.32

	mat_cap_unrevealed_b = StandardMaterial3D.new()
	mat_cap_unrevealed_b.albedo_color = Color(0.13, 0.23, 0.20)
	mat_cap_unrevealed_b.roughness = 0.36
	mat_cap_unrevealed_b.metallic = 0.30

	mat_cap_hover = StandardMaterial3D.new()
	mat_cap_hover.albedo_color = Color(0.24, 0.42, 0.34)
	mat_cap_hover.roughness = 0.25
	mat_cap_hover.metallic = 0.45
	mat_cap_hover.emission_enabled = true
	mat_cap_hover.emission = Color(0.25, 0.75, 0.50)
	mat_cap_hover.emission_energy_multiplier = 0.25

	mat_cap_holding = StandardMaterial3D.new()
	mat_cap_holding.albedo_color = Color(0.45, 0.34, 0.14)
	mat_cap_holding.roughness = 0.22
	mat_cap_holding.metallic = 0.58
	mat_cap_holding.emission_enabled = true
	mat_cap_holding.emission = Color(1.0, 0.75, 0.22)
	mat_cap_holding.emission_energy_multiplier = 0.55

	mat_safe_zero = StandardMaterial3D.new()
	mat_safe_zero.albedo_color = Color(0.09, 0.15, 0.13)
	mat_safe_zero.roughness = 0.58
	mat_safe_zero.metallic = 0.12

	mat_safe_numbered = StandardMaterial3D.new()
	mat_safe_numbered.albedo_color = Color(0.12, 0.20, 0.17)
	mat_safe_numbered.roughness = 0.44
	mat_safe_numbered.metallic = 0.20

	mat_mine_crater = StandardMaterial3D.new()
	mat_mine_crater.albedo_color = Color(0.16, 0.05, 0.04)
	mat_mine_crater.roughness = 0.65
	mat_mine_crater.metallic = 0.20
	mat_mine_crater.emission_enabled = true
	mat_mine_crater.emission = Color(0.95, 0.22, 0.06)
	mat_mine_crater.emission_energy_multiplier = 0.55

	mat_flag_correct_base = StandardMaterial3D.new()
	mat_flag_correct_base.albedo_color = Color(0.09, 0.28, 0.18)
	mat_flag_correct_base.roughness = 0.30
	mat_flag_correct_base.metallic = 0.40
	mat_flag_correct_base.emission_enabled = true
	mat_flag_correct_base.emission = Color(0.18, 0.85, 0.45)
	mat_flag_correct_base.emission_energy_multiplier = 0.28

	mat_flag_wrong_base = StandardMaterial3D.new()
	mat_flag_wrong_base.albedo_color = Color(0.28, 0.10, 0.09)
	mat_flag_wrong_base.roughness = 0.38
	mat_flag_wrong_base.metallic = 0.30
	mat_flag_wrong_base.emission_enabled = true
	mat_flag_wrong_base.emission = Color(0.85, 0.20, 0.15)
	mat_flag_wrong_base.emission_energy_multiplier = 0.24

	mat_rim_brass = StandardMaterial3D.new()
	mat_rim_brass.albedo_color = Color(0.76, 0.60, 0.26)
	mat_rim_brass.metallic = 0.82
	mat_rim_brass.roughness = 0.28

	mat_rim_emerald = StandardMaterial3D.new()
	mat_rim_emerald.albedo_color = Color(0.22, 0.92, 0.54)
	mat_rim_emerald.metallic = 0.50
	mat_rim_emerald.roughness = 0.22
	mat_rim_emerald.emission_enabled = true
	mat_rim_emerald.emission = Color(0.22, 0.92, 0.54)
	mat_rim_emerald.emission_energy_multiplier = 0.60

	mat_rim_crimson = StandardMaterial3D.new()
	mat_rim_crimson.albedo_color = Color(1.0, 0.28, 0.20)
	mat_rim_crimson.metallic = 0.45
	mat_rim_crimson.roughness = 0.22
	mat_rim_crimson.emission_enabled = true
	mat_rim_crimson.emission = Color(1.0, 0.26, 0.18)
	mat_rim_crimson.emission_energy_multiplier = 0.72

	mat_rim_gold_glow = StandardMaterial3D.new()
	mat_rim_gold_glow.albedo_color = Color(1.0, 0.84, 0.32)
	mat_rim_gold_glow.metallic = 0.78
	mat_rim_gold_glow.roughness = 0.20
	mat_rim_gold_glow.emission_enabled = true
	mat_rim_gold_glow.emission = Color(1.0, 0.80, 0.25)
	mat_rim_gold_glow.emission_energy_multiplier = 0.65

	mat_mine_iron = StandardMaterial3D.new()
	mat_mine_iron.albedo_color = Color(0.14, 0.15, 0.17)
	mat_mine_iron.metallic = 0.88
	mat_mine_iron.roughness = 0.24

	mat_mine_core_red = StandardMaterial3D.new()
	mat_mine_core_red.albedo_color = Color(1.0, 0.24, 0.12)
	mat_mine_core_red.emission_enabled = true
	mat_mine_core_red.emission = Color(1.0, 0.22, 0.08)
	mat_mine_core_red.emission_energy_multiplier = 2.4

	mat_mine_core_green = StandardMaterial3D.new()
	mat_mine_core_green.albedo_color = Color(0.22, 1.0, 0.56)
	mat_mine_core_green.emission_enabled = true
	mat_mine_core_green.emission = Color(0.18, 0.98, 0.50)
	mat_mine_core_green.emission_energy_multiplier = 1.9

	mat_flag_pole = StandardMaterial3D.new()
	mat_flag_pole.albedo_color = Color(0.96, 0.82, 0.36)
	mat_flag_pole.metallic = 0.92
	mat_flag_pole.roughness = 0.16
	mat_flag_pole.emission_enabled = true
	mat_flag_pole.emission = Color(0.85, 0.68, 0.22)
	mat_flag_pole.emission_energy_multiplier = 0.20

	mat_flag_cloth_red = StandardMaterial3D.new()
	mat_flag_cloth_red.albedo_color = Color(0.96, 0.18, 0.22)
	mat_flag_cloth_red.roughness = 0.28
	mat_flag_cloth_red.emission_enabled = true
	mat_flag_cloth_red.emission = Color(0.95, 0.16, 0.20)
	mat_flag_cloth_red.emission_energy_multiplier = 0.50

	mat_flag_cloth_gold = StandardMaterial3D.new()
	mat_flag_cloth_gold.albedo_color = Color(1.0, 0.82, 0.24)
	mat_flag_cloth_gold.metallic = 0.72
	mat_flag_cloth_gold.roughness = 0.20
	mat_flag_cloth_gold.emission_enabled = true
	mat_flag_cloth_gold.emission = Color(1.0, 0.78, 0.22)
	mat_flag_cloth_gold.emission_energy_multiplier = 0.58

	mat_wrong_cross = StandardMaterial3D.new()
	mat_wrong_cross.albedo_color = Color(1.0, 0.22, 0.20)
	mat_wrong_cross.roughness = 0.22
	mat_wrong_cross.emission_enabled = true
	mat_wrong_cross.emission = Color(1.0, 0.18, 0.14)
	mat_wrong_cross.emission_energy_multiplier = 1.35

func _build_board_cabinet() -> void:
	var cabinet_root := Node3D.new()
	cabinet_root.name = "CabinetRoot"
	add_child(cabinet_root)

	# Outer luxury mahogany/walnut base slab
	var base_mesh := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(CABINET_W, CABINET_H, CABINET_D)
	base_mesh.mesh = base_box
	base_mesh.position = Vector3(0.0, CABINET_H * 0.5, 0.02)
	base_mesh.material_override = mat_cabinet_wood
	cabinet_root.add_child(base_mesh)

	# Inner dark tactical emerald well under the 8x8 grid
	var well_mesh := MeshInstance3D.new()
	var well_box := BoxMesh.new()
	well_box.size = Vector3(1.055, 0.012, 1.055)
	well_mesh.mesh = well_box
	well_mesh.position = Vector3(0.0, CABINET_H + 0.004, GRID_CENTER_Z)
	well_mesh.material_override = mat_recess_well
	cabinet_root.add_child(well_mesh)

	# Brass perimeter frame around the 8x8 grid well
	var border_thickness := 0.022
	var border_h := 0.022
	var inner_span := 1.055
	var top_b := MeshInstance3D.new()
	var tb_box := BoxMesh.new()
	tb_box.size = Vector3(inner_span + border_thickness * 2.0, border_h, border_thickness)
	top_b.mesh = tb_box
	top_b.position = Vector3(0.0, CABINET_H + border_h * 0.5, GRID_CENTER_Z - inner_span * 0.5 - border_thickness * 0.5)
	top_b.material_override = mat_cabinet_trim
	cabinet_root.add_child(top_b)

	var bot_b := MeshInstance3D.new()
	bot_b.mesh = tb_box
	bot_b.position = Vector3(0.0, CABINET_H + border_h * 0.5, GRID_CENTER_Z + inner_span * 0.5 + border_thickness * 0.5)
	bot_b.material_override = mat_cabinet_trim
	cabinet_root.add_child(bot_b)

	var side_box := BoxMesh.new()
	side_box.size = Vector3(border_thickness, border_h, inner_span)
	var left_b := MeshInstance3D.new()
	left_b.mesh = side_box
	left_b.position = Vector3(-inner_span * 0.5 - border_thickness * 0.5, CABINET_H + border_h * 0.5, GRID_CENTER_Z)
	left_b.material_override = mat_cabinet_trim
	cabinet_root.add_child(left_b)

	var right_b := MeshInstance3D.new()
	right_b.mesh = side_box
	right_b.position = Vector3(inner_span * 0.5 + border_thickness * 0.5, CABINET_H + border_h * 0.5, GRID_CENTER_Z)
	right_b.material_override = mat_cabinet_trim
	cabinet_root.add_child(right_b)

	# 4 Corner brass rivets on the cabinet
	var rivet_cyl := CylinderMesh.new()
	rivet_cyl.top_radius = 0.018
	rivet_cyl.bottom_radius = 0.022
	rivet_cyl.height = 0.026
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var rivet := MeshInstance3D.new()
			rivet.mesh = rivet_cyl
			rivet.position = Vector3(
				cx * (inner_span * 0.5 + border_thickness * 0.5),
				CABINET_H + 0.013,
				GRID_CENTER_Z + cz * (inner_span * 0.5 + border_thickness * 0.5)
			)
			rivet.material_override = mat_cabinet_trim
			cabinet_root.add_child(rivet)

	vfx_root = Node3D.new()
	vfx_root.name = "VFXRoot"
	add_child(vfx_root)

func _build_grid_cells() -> void:
	grid_root = Node3D.new()
	grid_root.name = "GridRoot"
	add_child(grid_root)

	cell_roots.clear()
	cell_cap_pivots.clear()
	cell_cap_meshes.clear()
	cell_base_meshes.clear()
	cell_rim_meshes.clear()
	cell_label_3ds.clear()
	cell_ornament_roots.clear()

	var base_box := BoxMesh.new()
	base_box.size = Vector3(CELL_W, 0.012, CELL_W)

	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(CELL_W - 0.006, 0.015, CELL_W - 0.006)

	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(CELL_W - 0.010, 0.026, CELL_W - 0.010)

	var cap_top_bevel := BoxMesh.new()
	cap_top_bevel.size = Vector3(CELL_W - 0.024, 0.006, CELL_W - 0.024)

	var rivet_mesh := SphereMesh.new()
	rivet_mesh.radius = 0.0045
	rivet_mesh.height = 0.009

	for idx in range(TOTAL_CELLS):
		var cell_pos := _get_cell_world_pos(idx)
		var r := int(idx / GRID_SIZE)
		var c := idx % GRID_SIZE

		var cell_node := Node3D.new()
		cell_node.name = "Cell_%d" % idx
		cell_node.position = cell_pos
		grid_root.add_child(cell_node)
		cell_roots.append(cell_node)

		# Revealed floor plate
		var base_mi := MeshInstance3D.new()
		base_mi.mesh = base_box
		base_mi.position = Vector3(0.0, 0.006, 0.0)
		base_mi.material_override = mat_safe_zero
		cell_node.add_child(base_mi)
		cell_base_meshes.append(base_mi)

		# Subtle metallic inner rim
		var rim_mi := MeshInstance3D.new()
		rim_mi.mesh = rim_box
		rim_mi.position = Vector3(0.0, 0.0075, 0.0)
		rim_mi.material_override = mat_rim_brass
		cell_node.add_child(rim_mi)
		cell_rim_meshes.append(rim_mi)

		# 3D Elevated Armored Cover Cap (visible when unrevealed)
		var cap_pivot := Node3D.new()
		cap_pivot.name = "CapPivot"
		cap_pivot.position = Vector3(0.0, 0.020, 0.0)
		cell_node.add_child(cap_pivot)
		cell_cap_pivots.append(cap_pivot)

		var is_alt := ((r + c) % 2) == 1
		var cap_mat := mat_cap_unrevealed_b if is_alt else mat_cap_unrevealed_a

		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = cap_box
		cap_mi.material_override = cap_mat
		cap_pivot.add_child(cap_mi)
		cell_cap_meshes.append(cap_mi)

		var bevel_mi := MeshInstance3D.new()
		bevel_mi.mesh = cap_top_bevel
		bevel_mi.position = Vector3(0.0, 0.015, 0.0)
		bevel_mi.material_override = cap_mat
		cap_pivot.add_child(bevel_mi)

		# 4 micro brass corner rivets on each unrevealed tile cap
		var r_off := (CELL_W - 0.032) * 0.5
		for rx in [-1.0, 1.0]:
			for rz in [-1.0, 1.0]:
				var rv := MeshInstance3D.new()
				rv.mesh = rivet_mesh
				rv.position = Vector3(rx * r_off, 0.017, rz * r_off)
				rv.material_override = mat_rim_brass
				cap_pivot.add_child(rv)

		# 3D Number Label on revealed tile floor
		var lbl := Label3D.new()
		lbl.name = "AdjLabel"
		lbl.position = Vector3(0.0, 0.020, 0.0)
		lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lbl.pixel_size = 0.0011
		lbl.font_size = 64
		lbl.outline_size = 14
		lbl.outline_modulate = Color(0.02, 0.04, 0.03, 0.95)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.visible = false
		cell_node.add_child(lbl)
		cell_label_3ds.append(lbl)

		# Container for 3D Mine / Flag / Wrong-Flag ornaments
		var ornament_root := Node3D.new()
		ornament_root.name = "OrnamentRoot"
		ornament_root.position = Vector3(0.0, 0.015, 0.0)
		cell_node.add_child(ornament_root)
		cell_ornament_roots.append(ornament_root)

func _build_bottom_console() -> void:
	console_root = Node3D.new()
	console_root.name = "ConsoleRoot"
	console_root.position = Vector3(0.0, CABINET_H + 0.008, CONSOLE_Z)
	add_child(console_root)

	# Sleek brass-trimmed status deck (no mode toggle buttons; hold-to-flag is direct!)
	var bay_mesh := MeshInstance3D.new()
	var bay_box := BoxMesh.new()
	bay_box.size = Vector3(1.08, 0.016, 0.21)
	bay_mesh.mesh = bay_box
	bay_mesh.material_override = mat_recess_well
	console_root.add_child(bay_mesh)

	var trim_mesh := MeshInstance3D.new()
	var trim_box := BoxMesh.new()
	trim_box.size = Vector3(1.10, 0.012, 0.225)
	trim_mesh.mesh = trim_box
	trim_mesh.position = Vector3(0.0, -0.002, 0.0)
	trim_mesh.material_override = mat_cabinet_trim
	console_root.add_child(trim_mesh)

	# Left Plaque: Remaining Flags Counter
	var left_plaque := MeshInstance3D.new()
	var plaque_box := BoxMesh.new()
	plaque_box.size = Vector3(0.49, 0.022, 0.095)
	left_plaque.mesh = plaque_box
	left_plaque.position = Vector3(-0.26, 0.012, -0.038)
	left_plaque.material_override = mat_cap_unrevealed_a
	console_root.add_child(left_plaque)

	flags_counter_label = Label3D.new()
	flags_counter_label.position = Vector3(-0.26, 0.026, -0.038)
	flags_counter_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	flags_counter_label.pixel_size = 0.00088
	flags_counter_label.font_size = 38
	flags_counter_label.outline_size = 10
	flags_counter_label.modulate = Color(1.0, 0.86, 0.38)
	console_root.add_child(flags_counter_label)

	# Right Plaque: Remaining Safe Cells Counter
	var right_plaque := MeshInstance3D.new()
	right_plaque.mesh = plaque_box
	right_plaque.position = Vector3(0.26, 0.012, -0.038)
	right_plaque.material_override = mat_cap_unrevealed_a
	console_root.add_child(right_plaque)

	safe_counter_label = Label3D.new()
	safe_counter_label.position = Vector3(0.26, 0.026, -0.038)
	safe_counter_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	safe_counter_label.pixel_size = 0.00088
	safe_counter_label.font_size = 38
	safe_counter_label.outline_size = 10
	safe_counter_label.modulate = Color(0.55, 0.96, 0.74)
	console_root.add_child(safe_counter_label)

	# Tactile instruction bar across bottom of console
	hint_banner_label = Label3D.new()
	hint_banner_label.position = Vector3(0.0, 0.022, 0.056)
	hint_banner_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	hint_banner_label.pixel_size = 0.00078
	hint_banner_label.font_size = 34
	hint_banner_label.outline_size = 9
	hint_banner_label.modulate = Color(0.92, 0.90, 0.82, 0.95)
	hint_banner_label.text = "ضربه کوتاه: کاوش خانه امن   •   نگه داشتن (لمس طولانی): پرچم‌گذاری مین 🚩"
	console_root.add_child(hint_banner_label)

func _build_hold_indicator() -> void:
	_hold_indicator_root = Node3D.new()
	_hold_indicator_root.name = "HoldIndicator"
	_hold_indicator_root.visible = false
	add_child(_hold_indicator_root)

	# Outer rotating golden target ring
	_hold_outer_ring = MeshInstance3D.new()
	var outer_torus := TorusMesh.new()
	outer_torus.inner_radius = 0.044
	outer_torus.outer_radius = 0.056
	_hold_outer_ring.mesh = outer_torus
	_hold_outer_ring.material_override = mat_rim_gold_glow
	_hold_indicator_root.add_child(_hold_outer_ring)

	# Inner emerald-gold charging ring
	_hold_inner_ring = MeshInstance3D.new()
	var inner_torus := TorusMesh.new()
	inner_torus.inner_radius = 0.022
	inner_torus.outer_radius = 0.034
	_hold_inner_ring.mesh = inner_torus
	_hold_inner_ring.material_override = mat_rim_emerald
	_hold_indicator_root.add_child(_hold_inner_ring)

	# Rising 3D miniature flag preview during hold
	_hold_flag_preview = Node3D.new()
	_hold_indicator_root.add_child(_hold_flag_preview)

	var pole_mi := MeshInstance3D.new()
	var pole_cyl := CylinderMesh.new()
	pole_cyl.top_radius = 0.003
	pole_cyl.bottom_radius = 0.0035
	pole_cyl.height = 0.068
	pole_mi.mesh = pole_cyl
	pole_mi.position = Vector3(-0.008, 0.034, 0.0)
	pole_mi.material_override = mat_flag_pole
	_hold_flag_preview.add_child(pole_mi)

	var cloth_mi := MeshInstance3D.new()
	var cloth_box := BoxMesh.new()
	cloth_box.size = Vector3(0.036, 0.024, 0.005)
	cloth_mi.mesh = cloth_box
	cloth_mi.position = Vector3(0.011, 0.052, 0.0)
	cloth_mi.material_override = mat_flag_cloth_red
	_hold_flag_preview.add_child(cloth_mi)

func _update_console_labels() -> void:
	if flags_counter_label:
		flags_counter_label.text = "🚩 پرچم باقی‌مانده: %s" % _to_persian_digits(str(max(0, remaining_flags)))
	if safe_counter_label:
		safe_counter_label.text = "✨ خانه‌های امن: %s" % _to_persian_digits(str(max(0, safe_remaining)))

func _recalculate_counters_from_board() -> void:
	var used_flags := 0
	var revealed_safe := 0
	for i in range(TOTAL_CELLS):
		if cell_states[i] == STATE_FLAG_CORRECT or cell_states[i] == STATE_FLAG_WRONG:
			used_flags += 1
		elif cell_states[i] == STATE_SAFE:
			revealed_safe += 1
	remaining_flags = max(0, TOTAL_MINES - used_flags)
	safe_remaining = max(0, TOTAL_SAFE - revealed_safe)
	_update_console_labels()

func _get_cell_world_pos(idx: int) -> Vector3:
	var r := int(idx / GRID_SIZE)
	var c := idx % GRID_SIZE
	var x := (float(c) - 3.5) * CELL_STEP
	var z := GRID_CENTER_Z + (float(r) - 3.5) * CELL_STEP
	return Vector3(x, CABINET_H + 0.008, z)

# ==============================================================================
# Touch / Mouse Raycast & Hold-to-Flag Handling
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _is_point_blocked_by_hud(mb.position):
				var hit_pos := _get_board_hit(mb.position)
				if hit_pos != Vector3.INF:
					var idx := _world_to_cell_index(hit_pos)
					if idx >= 0 and cell_states[idx] == STATE_HIDDEN:
						_flag_mine_on_cell(idx)
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_pointer_down(mb.position)
			else:
				_on_pointer_up(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_on_pointer_down(st.position)
		else:
			_on_pointer_up(st.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_on_pointer_move(mm.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_on_pointer_move(sd.position)

func _on_pointer_down(screen_pos: Vector2) -> void:
	if _is_point_blocked_by_hud(screen_pos):
		_cancel_pointer_hold()
		return
	var hit_pos := _get_board_hit(screen_pos)
	if hit_pos == Vector3.INF:
		_cancel_pointer_hold()
		return

	_down_pos = screen_pos
	_down_time = Time.get_ticks_msec() / 1000.0
	_long_press_triggered = false
	_down_cell_idx = _world_to_cell_index(hit_pos)

	if _down_cell_idx >= 0 and cell_states[_down_cell_idx] == STATE_HIDDEN:
		var cap_pivot := cell_cap_pivots[_down_cell_idx]
		cap_pivot.position.y = 0.014
		cell_cap_meshes[_down_cell_idx].material_override = mat_cap_hover

func _on_pointer_move(screen_pos: Vector2) -> void:
	if _down_cell_idx < 0:
		return
	if screen_pos.distance_to(_down_pos) > 36.0:
		_restore_cell_cap_visual(_down_cell_idx)
		_cancel_pointer_hold()

func _on_pointer_up(screen_pos: Vector2) -> void:
	var active_cell := _down_cell_idx
	var was_long := _long_press_triggered
	if active_cell >= 0:
		_restore_cell_cap_visual(active_cell)
	_cancel_pointer_hold()

	if was_long:
		return

	if _is_point_blocked_by_hud(screen_pos):
		return

	var hit_pos := _get_board_hit(screen_pos)
	if hit_pos == Vector3.INF:
		return

	var up_cell := _world_to_cell_index(hit_pos)
	if up_cell >= 0 and up_cell == active_cell:
		_on_cell_short_tapped(up_cell)

func _cancel_pointer_hold() -> void:
	_down_cell_idx = -1
	_long_press_triggered = false
	if _hold_indicator_root:
		_hold_indicator_root.visible = false

func _restore_cell_cap_visual(idx: int) -> void:
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	if cell_states[idx] != STATE_HIDDEN:
		return
	var r := int(idx / GRID_SIZE)
	var c := idx % GRID_SIZE
	var is_alt := ((r + c) % 2) == 1
	cell_cap_meshes[idx].material_override = mat_cap_unrevealed_b if is_alt else mat_cap_unrevealed_a
	cell_cap_pivots[idx].position.y = 0.020
	cell_cap_pivots[idx].scale = Vector3.ONE

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	# 1. Animate waving 3D pennant flags on flagged cells
	for item in waving_flag_segments:
		var seg_node: Node3D = item.get("node")
		if is_instance_valid(seg_node):
			var phase: float = float(item.get("phase", 0.0))
			var seg_idx: int = int(item.get("seg", 0))
			var wave := sin(now * 6.5 + phase - float(seg_idx) * 0.95)
			seg_node.position.z = wave * (0.0022 * float(seg_idx + 1))
			seg_node.rotation.y = cos(now * 6.5 + phase - float(seg_idx) * 0.8) * 0.14

	# 2. Spawn continuous smoldering smoke & sparks on exploded bomb craters
	_smoke_spawn_accum += delta
	if _smoke_spawn_accum >= 0.24:
		_smoke_spawn_accum = 0.0
		for crater_node in smoldering_craters:
			if is_instance_valid(crater_node):
				_spawn_crater_smolder_puff(crater_node.global_position)

	# 3. Hold-to-Flag progress ring & rising flag preview
	if _down_cell_idx >= 0 and not _long_press_triggered:
		if cell_states[_down_cell_idx] != STATE_HIDDEN:
			_cancel_pointer_hold()
			return
		var elapsed := now - _down_time
		var progress := clampf(elapsed / LONG_PRESS_DURATION, 0.0, 1.0)
		if progress > 0.14 and _hold_indicator_root:
			_hold_indicator_root.visible = true
			var cell_pos := _get_cell_world_pos(_down_cell_idx)
			_hold_indicator_root.position = cell_pos + Vector3(0.0, 0.045, 0.0)
			cell_cap_meshes[_down_cell_idx].material_override = mat_cap_holding
			cell_cap_pivots[_down_cell_idx].position.y = lerpf(0.016, 0.010, progress)

			if _hold_outer_ring:
				_hold_outer_ring.scale = Vector3.ONE * lerpf(1.35, 0.88, progress)
				_hold_outer_ring.rotation.y += delta * 7.5
			if _hold_inner_ring:
				_hold_inner_ring.scale = Vector3.ONE * lerpf(0.25, 1.05, progress)
			if _hold_flag_preview:
				_hold_flag_preview.scale = Vector3.ONE * ease(progress, 0.5)
				_hold_flag_preview.position.y = lerpf(-0.015, 0.005, progress)

		if elapsed >= LONG_PRESS_DURATION:
			_long_press_triggered = true
			if _hold_indicator_root:
				_hold_indicator_root.visible = false
			var target_idx := _down_cell_idx
			_restore_cell_cap_visual(target_idx)
			_flag_mine_on_cell(target_idx)

func _on_cell_short_tapped(idx: int) -> void:
	if idx < 0 or idx >= TOTAL_CELLS:
		return
	if cell_states[idx] != STATE_HIDDEN:
		_pulse_revealed_cell(idx)
		return
	# Short tap always digs/reveals safe cell; holding flags as mine!
	_reveal_safe_cell(idx)

func _reveal_safe_cell(idx: int) -> void:
	if cell_states[idx] != STATE_HIDDEN:
		return
	AudioManager.play_sound("click")
	_animate_cell_press(idx)
	NetworkManager.send_select_peace(idx)

func _flag_mine_on_cell(idx: int) -> void:
	if cell_states[idx] != STATE_HIDDEN:
		return
	if remaining_flags <= 0:
		AudioManager.play_sound("invalid")
		return
	AudioManager.play_sound("place")
	_animate_cell_press(idx)
	NetworkManager.send_select_mine(idx)

func _animate_cell_press(idx: int) -> void:
	var cap_pivot := cell_cap_pivots[idx]
	var tw := create_tween()
	tw.tween_property(cap_pivot, "scale", Vector3(0.88, 0.65, 0.88), 0.06)
	tw.tween_property(cap_pivot, "scale", Vector3.ONE, 0.08)

func _pulse_revealed_cell(idx: int) -> void:
	var root := cell_roots[idx]
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(1.05, 1.0, 1.05), 0.07)
	tw.tween_property(root, "scale", Vector3.ONE, 0.09)

func _get_board_hit(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3.INF
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, CABINET_H + 0.020)
	var hit: Variant = plane.intersects_ray(from, dir)
	return hit if hit != null else Vector3.INF

func _world_to_cell_index(world_pos: Vector3) -> int:
	var local_x := world_pos.x
	var local_z := world_pos.z - GRID_CENTER_Z
	var col_f := (local_x / CELL_STEP) + 3.5
	var row_f := (local_z / CELL_STEP) + 3.5
	var col := int(round(col_f))
	var row := int(round(row_f))
	if col < 0 or col >= GRID_SIZE or row < 0 or row >= GRID_SIZE:
		return -1
	var cell_center := _get_cell_world_pos(row * GRID_SIZE + col)
	if absf(world_pos.x - cell_center.x) > CELL_W * 0.56 or absf(world_pos.z - cell_center.z) > CELL_W * 0.56:
		return -1
	return row * GRID_SIZE + col

func _is_point_blocked_by_hud(screen_pos: Vector2) -> bool:
	var hud := get_tree().get_first_node_in_group("base_game_hud")
	if hud == null:
		return false
	for modal_name in ["SettingsModal", "ExitModal", "SurrenderModal", "GameOverModal", "AlertModal", "VictoryScreen"]:
		var m := hud.get_node_or_null(modal_name)
		if m and m.visible:
			return true
	var top_bar := hud.get_node_or_null("MarginContainer/VBoxContainer/TopHeader")
	if top_bar and top_bar is Control and top_bar.visible:
		if (top_bar as Control).get_global_rect().has_point(screen_pos):
			return true
	var bottom_bar := hud.get_node_or_null("MarginContainer/VBoxContainer/BottomBar")
	if bottom_bar and bottom_bar is Control and bottom_bar.visible:
		if (bottom_bar as Control).get_global_rect().has_point(screen_pos):
			return true
	return false

# ==============================================================================
# Server Command Virtual Callbacks (from BaseGameBoard)
# ==============================================================================

func reset_board() -> void:
	for i in range(TOTAL_CELLS):
		_reset_cell_to_hidden(i)
	waving_flag_segments.clear()
	smoldering_craters.clear()
	remaining_flags = TOTAL_MINES
	safe_remaining = TOTAL_SAFE
	_update_console_labels()

func on_start_game() -> void:
	set_board_locked(false)
	reset_board()

func on_select_peace_result(payload: Dictionary) -> void:
	var cells_list: Array = payload.get("p", [])
	var newly_revealed: Array[int] = []

	for entry in cells_list:
		if entry is Dictionary:
			var idx := int(entry.get("n", -1))
			var adj_mines := int(entry.get("m", 0))
			if idx >= 0 and idx < TOTAL_CELLS:
				var was_hidden := (cell_states[idx] == STATE_HIDDEN)
				cell_states[idx] = STATE_SAFE
				cell_adj_counts[idx] = adj_mines
				_apply_cell_visual(idx, was_hidden, newly_revealed.size())
				if was_hidden:
					newly_revealed.append(idx)

	if newly_revealed.size() > 1:
		AudioManager.play_sound("score")
	elif newly_revealed.size() == 1:
		AudioManager.play_sound("move")

	_recalculate_counters_from_board()

func on_mine_selected(payload: Dictionary) -> void:
	var peace_num := int(payload.get("n", payload.get("p", -1)))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return
	cell_states[peace_num] = STATE_MINE_HIT
	AudioManager.play_sound("explode")
	AudioManager.play_sound("hit")
	_launch_and_shatter_cell_cap(peace_num)
	_apply_cell_visual(peace_num, true, 0)
	_spawn_mine_explosion_vfx(_get_cell_world_pos(peace_num), peace_num)
	_trigger_neighbor_blast_ripple(peace_num)
	_recalculate_counters_from_board()

func on_select_mine_correct(payload: Dictionary) -> void:
	var peace_num := int(payload.get("n", payload.get("p", -1)))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return
	cell_states[peace_num] = STATE_FLAG_CORRECT
	AudioManager.play_sound("score")
	_apply_cell_visual(peace_num, true, 0)
	_spawn_flag_success_vfx(_get_cell_world_pos(peace_num))
	_recalculate_counters_from_board()

func on_select_mine_wrong(payload: Dictionary) -> void:
	var peace_num := int(payload.get("n", payload.get("p", -1)))
	if peace_num < 0 or peace_num >= TOTAL_CELLS:
		return
	cell_states[peace_num] = STATE_FLAG_WRONG
	AudioManager.play_sound("invalid")
	_apply_cell_visual(peace_num, true, 0)
	_spawn_flag_wrong_vfx(_get_cell_world_pos(peace_num))
	_recalculate_counters_from_board()

func on_reconnect_data(payload: Dictionary) -> void:
	waving_flag_segments.clear()
	smoldering_craters.clear()
	for i in range(TOTAL_CELLS):
		_reset_cell_to_hidden(i)

	var g_data: Dictionary = payload.get("game_data", payload) if payload.get("game_data") is Dictionary else payload
	var board_arr: Array = g_data.get("board", payload.get("board", []))
	for entry in board_arr:
		if entry is Dictionary:
			var idx := int(entry.get("n", -1))
			var st := int(entry.get("s", 0))
			var adj := int(entry.get("m", 0))
			if idx >= 0 and idx < TOTAL_CELLS and st > 0:
				cell_states[idx] = st
				cell_adj_counts[idx] = adj
				_apply_cell_visual(idx, false, 0)

	if g_data.has("remaining_mines"):
		remaining_flags = int(g_data.get("remaining_mines", TOTAL_MINES))
		var revealed_safe := 0
		for i in range(TOTAL_CELLS):
			if cell_states[i] == STATE_SAFE:
				revealed_safe += 1
		safe_remaining = max(0, TOTAL_SAFE - revealed_safe)
		_update_console_labels()
	else:
		_recalculate_counters_from_board()

# ==============================================================================
# Cell Visual State & Handcrafted 3D Ornaments
# ==============================================================================

func _reset_cell_to_hidden(idx: int) -> void:
	cell_states[idx] = STATE_HIDDEN
	cell_adj_counts[idx] = 0
	var cap_pivot := cell_cap_pivots[idx]
	cap_pivot.visible = true
	cap_pivot.scale = Vector3.ONE
	cap_pivot.rotation = Vector3.ZERO
	cap_pivot.position = Vector3(0.0, 0.020, 0.0)
	var r := int(idx / GRID_SIZE)
	var c := idx % GRID_SIZE
	var is_alt := ((r + c) % 2) == 1
	cell_cap_meshes[idx].material_override = mat_cap_unrevealed_b if is_alt else mat_cap_unrevealed_a
	cell_base_meshes[idx].material_override = mat_safe_zero
	cell_rim_meshes[idx].material_override = mat_rim_brass
	cell_label_3ds[idx].visible = false
	for child in cell_ornament_roots[idx].get_children():
		child.queue_free()

func _apply_cell_visual(idx: int, animate: bool, cascade_order: int) -> void:
	var st := cell_states[idx]
	var cap_pivot := cell_cap_pivots[idx]
	var base_mi := cell_base_meshes[idx]
	var rim_mi := cell_rim_meshes[idx]
	var lbl := cell_label_3ds[idx]
	var ornament_root := cell_ornament_roots[idx]

	for child in ornament_root.get_children():
		child.queue_free()

	if st == STATE_HIDDEN:
		_reset_cell_to_hidden(idx)
		return

	# Hide or animate removal of the 3D armored cap
	if animate and cap_pivot.visible and st != STATE_MINE_HIT:
		var delay := minf(float(cascade_order) * 0.018, 0.28)
		var tw := create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(cap_pivot, "scale", Vector3(0.1, 0.1, 0.1), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): cap_pivot.visible = false)
	else:
		cap_pivot.visible = false

	lbl.visible = false

	match st:
		STATE_SAFE:
			var count := cell_adj_counts[idx]
			if count <= 0:
				base_mi.material_override = mat_safe_zero
				rim_mi.material_override = mat_rim_brass
			else:
				base_mi.material_override = mat_safe_numbered
				rim_mi.material_override = mat_rim_brass
				lbl.visible = true
				lbl.text = _to_persian_digits(str(count))
				lbl.modulate = NUMBER_COLORS.get(count, Color.WHITE)
				if animate:
					lbl.scale = Vector3.ZERO
					var delay := minf(float(cascade_order) * 0.018, 0.28)
					var ltw := create_tween()
					if delay > 0.0:
						ltw.tween_interval(delay + 0.06)
					ltw.tween_property(lbl, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		STATE_MINE_HIT:
			base_mi.material_override = mat_mine_crater
			rim_mi.material_override = mat_rim_crimson
			_populate_cell_ornament(ornament_root, STATE_MINE_HIT, animate, idx)

		STATE_FLAG_CORRECT:
			base_mi.material_override = mat_flag_correct_base
			rim_mi.material_override = mat_rim_emerald
			_populate_cell_ornament(ornament_root, STATE_FLAG_CORRECT, animate, idx)

		STATE_FLAG_WRONG:
			base_mi.material_override = mat_flag_wrong_base
			rim_mi.material_override = mat_rim_crimson
			_populate_cell_ornament(ornament_root, STATE_FLAG_WRONG, animate, idx)

func _populate_cell_ornament(ornament_root: Node3D, state: int, animate: bool, cell_idx: int) -> void:
	var holder := Node3D.new()
	ornament_root.add_child(holder)

	if state == STATE_MINE_HIT:
		# Scorched Blast Crater Rim + Exposed Detonated Naval Mine + Glowing Lava Fissures
		var crater_torus := TorusMesh.new()
		crater_torus.inner_radius = 0.032
		crater_torus.outer_radius = 0.050
		var crater_rim := MeshInstance3D.new()
		crater_rim.mesh = crater_torus
		crater_rim.position = Vector3(0.0, 0.004, 0.0)
		crater_rim.scale = Vector3(1.0, 0.45, 1.0)
		crater_rim.material_override = mat_mine_iron
		holder.add_child(crater_rim)

		# Glowing magma pool inside crater
		var lava_cyl := CylinderMesh.new()
		lava_cyl.top_radius = 0.035
		lava_cyl.bottom_radius = 0.035
		lava_cyl.height = 0.004
		var lava_mi := MeshInstance3D.new()
		lava_mi.mesh = lava_cyl
		lava_mi.position = Vector3(0.0, 0.003, 0.0)
		lava_mi.material_override = mat_mine_core_red
		holder.add_child(lava_mi)

		# Jagged scorched bomb hemisphere sitting in crater
		var sphere_mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.028
		sph.height = 0.052
		sphere_mi.mesh = sph
		sphere_mi.position = Vector3(0.0, 0.018, 0.0)
		sphere_mi.material_override = mat_mine_iron
		holder.add_child(sphere_mi)

		# Pulsing red-hot cracked core
		var core_mi := MeshInstance3D.new()
		var core_cyl := CylinderMesh.new()
		core_cyl.top_radius = 0.015
		core_cyl.bottom_radius = 0.015
		core_cyl.height = 0.010
		core_mi.mesh = core_cyl
		core_mi.position = Vector3(0.0, 0.042, 0.0)
		core_mi.material_override = mat_mine_core_red
		holder.add_child(core_mi)

		# 8 radial naval mine spikes with glowing tips
		var spike_mesh := CylinderMesh.new()
		spike_mesh.top_radius = 0.002
		spike_mesh.bottom_radius = 0.0055
		spike_mesh.height = 0.026
		for i in range(8):
			var angle := float(i) * PI * 0.25
			var sp := MeshInstance3D.new()
			sp.mesh = spike_mesh
			sp.position = Vector3(cos(angle) * 0.024, 0.022, sin(angle) * 0.024)
			sp.rotation = Vector3(sin(angle) * 0.95, 0.0, -cos(angle) * 0.95)
			sp.material_override = mat_mine_iron
			holder.add_child(sp)

		smoldering_craters.append(holder)

	elif state == STATE_FLAG_CORRECT:
		# 1. Luxury Octagonal Emerald-Gold Shield Pedestal
		var ped_base := MeshInstance3D.new()
		var ped_cyl := CylinderMesh.new()
		ped_cyl.top_radius = 0.044
		ped_cyl.bottom_radius = 0.050
		ped_cyl.height = 0.012
		ped_cyl.radial_segments = 8
		ped_base.mesh = ped_cyl
		ped_base.position = Vector3(0.0, 0.006, 0.0)
		ped_base.material_override = mat_rim_gold_glow
		holder.add_child(ped_base)

		var ped_inlay := MeshInstance3D.new()
		var inlay_cyl := CylinderMesh.new()
		inlay_cyl.top_radius = 0.038
		inlay_cyl.bottom_radius = 0.040
		inlay_cyl.height = 0.006
		inlay_cyl.radial_segments = 8
		ped_inlay.mesh = inlay_cyl
		ped_inlay.position = Vector3(0.0, 0.013, 0.0)
		ped_inlay.material_override = mat_rim_emerald
		holder.add_child(ped_inlay)

		# 2. Defused 3D Naval Mine (with emerald safe core & brass equatorial collar)
		var mine_mi := MeshInstance3D.new()
		var m_sph := SphereMesh.new()
		m_sph.radius = 0.021
		m_sph.height = 0.042
		mine_mi.mesh = m_sph
		mine_mi.position = Vector3(0.014, 0.028, 0.010)
		mine_mi.material_override = mat_mine_iron
		holder.add_child(mine_mi)

		var collar_mi := MeshInstance3D.new()
		var collar_torus := TorusMesh.new()
		collar_torus.inner_radius = 0.017
		collar_torus.outer_radius = 0.024
		collar_mi.mesh = collar_torus
		collar_mi.position = Vector3(0.014, 0.028, 0.010)
		collar_mi.scale = Vector3(1.0, 0.45, 1.0)
		collar_mi.material_override = mat_rim_brass
		holder.add_child(collar_mi)

		var safe_core := MeshInstance3D.new()
		var sc_sph := SphereMesh.new()
		sc_sph.radius = 0.0085
		sc_sph.height = 0.017
		safe_core.mesh = sc_sph
		safe_core.position = Vector3(0.014, 0.048, 0.010)
		safe_core.material_override = mat_mine_core_green
		holder.add_child(safe_core)

		var horn_cyl := CylinderMesh.new()
		horn_cyl.top_radius = 0.0022
		horn_cyl.bottom_radius = 0.004
		horn_cyl.height = 0.016
		for i in range(6):
			var ang := float(i) * PI / 3.0
			var horn := MeshInstance3D.new()
			horn.mesh = horn_cyl
			horn.position = Vector3(0.014 + cos(ang) * 0.019, 0.034, 0.010 + sin(ang) * 0.019)
			horn.rotation = Vector3(sin(ang) * 0.85, 0.0, -cos(ang) * 0.85)
			horn.material_override = mat_rim_brass
			holder.add_child(horn)

		# 3. Tall Golden Flagpole + Finial Orb + Multi-Segment Waving Royal Pennant Flag
		var pole_mi := MeshInstance3D.new()
		var pole_cyl := CylinderMesh.new()
		pole_cyl.top_radius = 0.0032
		pole_cyl.bottom_radius = 0.0045
		pole_cyl.height = 0.112
		pole_mi.mesh = pole_cyl
		pole_mi.position = Vector3(-0.020, 0.064, -0.010)
		pole_mi.material_override = mat_flag_pole
		holder.add_child(pole_mi)

		var finial_mi := MeshInstance3D.new()
		var finial_sph := SphereMesh.new()
		finial_sph.radius = 0.0075
		finial_sph.height = 0.015
		finial_mi.mesh = finial_sph
		finial_mi.position = Vector3(-0.020, 0.123, -0.010)
		finial_mi.material_override = mat_flag_cloth_gold
		holder.add_child(finial_mi)

		# 3 articulated cloth segments for smooth 3D wind wave animation
		var seg_widths := [0.018, 0.017, 0.015]
		var seg_heights := [0.032, 0.026, 0.018]
		var cur_x := -0.009
		for s_idx in range(3):
			var seg_pivot := Node3D.new()
			seg_pivot.position = Vector3(cur_x, 0.100, -0.010)
			holder.add_child(seg_pivot)

			var cloth_mi := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(seg_widths[s_idx], seg_heights[s_idx], 0.0055)
			cloth_mi.mesh = c_box
			cloth_mi.material_override = mat_flag_cloth_red
			seg_pivot.add_child(cloth_mi)

			# Gold royal trim stripe along top & bottom of flag segment
			var trim_mi := MeshInstance3D.new()
			var t_box := BoxMesh.new()
			t_box.size = Vector3(seg_widths[s_idx] + 0.001, 0.0045, 0.0068)
			trim_mi.mesh = t_box
			trim_mi.position = Vector3(0.0, seg_heights[s_idx] * 0.44, 0.0)
			trim_mi.material_override = mat_flag_cloth_gold
			seg_pivot.add_child(trim_mi)

			waving_flag_segments.append({
				"node": seg_pivot,
				"phase": float(cell_idx) * 0.65,
				"seg": s_idx
			})
			cur_x += seg_widths[s_idx] - 0.0015

	elif state == STATE_FLAG_WRONG:
		# Beveled Crimson-Brass Hazard Pedestal + Tilted Broken Flagpole + 3D Glowing Cross (✖)
		var ped_mi := MeshInstance3D.new()
		var ped_cyl := CylinderMesh.new()
		ped_cyl.top_radius = 0.042
		ped_cyl.bottom_radius = 0.046
		ped_cyl.height = 0.010
		ped_cyl.radial_segments = 8
		ped_mi.mesh = ped_cyl
		ped_mi.position = Vector3(0.0, 0.005, 0.0)
		ped_mi.material_override = mat_rim_crimson
		holder.add_child(ped_mi)

		# Tilted broken flagpole
		var broken_pole := MeshInstance3D.new()
		var bp_cyl := CylinderMesh.new()
		bp_cyl.top_radius = 0.0028
		bp_cyl.bottom_radius = 0.0038
		bp_cyl.height = 0.062
		broken_pole.mesh = bp_cyl
		broken_pole.position = Vector3(-0.018, 0.032, -0.012)
		broken_pole.rotation_degrees = Vector3(18.0, 0.0, -24.0)
		broken_pole.material_override = mat_rim_brass
		holder.add_child(broken_pole)

		# Glowing Ruby 3D X Cross
		var bar_box := BoxMesh.new()
		bar_box.size = Vector3(0.074, 0.015, 0.016)
		var bar_a := MeshInstance3D.new()
		bar_a.mesh = bar_box
		bar_a.position = Vector3(0.0, 0.020, 0.0)
		bar_a.rotation_degrees = Vector3(0.0, 45.0, 0.0)
		bar_a.material_override = mat_wrong_cross
		holder.add_child(bar_a)

		var bar_b := MeshInstance3D.new()
		bar_b.mesh = bar_box
		bar_b.position = Vector3(0.0, 0.020, 0.0)
		bar_b.rotation_degrees = Vector3(0.0, -45.0, 0.0)
		bar_b.material_override = mat_wrong_cross
		holder.add_child(bar_b)

	if animate:
		holder.scale = Vector3.ZERO
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector3(1.18, 1.24, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "scale", Vector3.ONE, 0.10)

# ==============================================================================
# Bomb Explosion & Flagging 3D VFX
# ==============================================================================

func _launch_and_shatter_cell_cap(idx: int) -> void:
	# Clone the cell's 3D armored cover cap and blast it tumbling skyward!
	var world_pos := _get_cell_world_pos(idx)
	var flying_cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(CELL_W - 0.010, 0.026, CELL_W - 0.010)
	flying_cap.mesh = cap_box
	flying_cap.position = world_pos + Vector3(0.0, 0.025, 0.0)
	flying_cap.material_override = mat_mine_crater
	vfx_root.add_child(flying_cap)

	var drift_x := randf_range(-0.14, 0.14)
	var drift_z := randf_range(-0.14, 0.14)
	var spin_vec := Vector3(randf_range(8.0, 14.0), randf_range(-10.0, 10.0), randf_range(8.0, 14.0))

	var tw := flying_cap.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float):
		var arc_y := sin(t * PI) * 0.42
		flying_cap.position = world_pos + Vector3(drift_x * t, 0.025 + arc_y, drift_z * t)
		flying_cap.rotation = spin_vec * t
	, 0.0, 1.0, 0.52)
	tw.tween_property(flying_cap, "scale", Vector3(0.05, 0.05, 0.05), 0.52).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(flying_cap.queue_free)

func _trigger_neighbor_blast_ripple(center_idx: int) -> void:
	var cr := int(center_idx / GRID_SIZE)
	var cc := center_idx % GRID_SIZE
	for dr in range(-2, 3):
		for dc in range(-2, 3):
			if dr == 0 and dc == 0:
				continue
			var nr := cr + dr
			var nc := cc + dc
			if nr < 0 or nr >= GRID_SIZE or nc < 0 or nc >= GRID_SIZE:
				continue
			var n_idx := nr * GRID_SIZE + nc
			var dist := sqrt(float(dr * dr + dc * dc))
			var delay := dist * 0.035
			var jump_h := 0.028 / dist
			var cell_node := cell_roots[n_idx]
			var base_y := cell_node.position.y
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(cell_node, "position:y", base_y + jump_h, 0.065).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell_node, "position:y", base_y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _spawn_mine_explosion_vfx(world_pos: Vector3, _cell_idx: int) -> void:
	ActionVFXManager.shake_camera(0.085, 0.55)

	var fx := Node3D.new()
	fx.position = world_pos + Vector3(0.0, 0.025, 0.0)
	vfx_root.add_child(fx)

	# 1. Dynamic 3D OmniLight3D Explosion Flash illuminating the board
	var blast_light := OmniLight3D.new()
	blast_light.light_color = Color(1.0, 0.58, 0.16)
	blast_light.light_energy = 7.5
	blast_light.omni_range = 1.45
	blast_light.position = Vector3(0.0, 0.14, 0.0)
	fx.add_child(blast_light)

	# 2. White-Hot Inner Plasma Core Sphere
	var core_mat := StandardMaterial3D.new()
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = Color(1.0, 0.96, 0.78, 0.98)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.92, 0.65)
	core_mat.emission_energy_multiplier = 5.0

	var core_mi := MeshInstance3D.new()
	var core_sph := SphereMesh.new()
	core_sph.radius = 0.055
	core_sph.height = 0.11
	core_mi.mesh = core_sph
	core_mi.material_override = core_mat
	core_mi.scale = Vector3(0.2, 0.2, 0.2)
	fx.add_child(core_mi)

	# 3. Fiery Orange-Crimson Outer Blast Fireball
	var fire_mat := StandardMaterial3D.new()
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.albedo_color = Color(1.0, 0.38, 0.08, 0.92)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.30, 0.04)
	fire_mat.emission_energy_multiplier = 3.6

	var fireball := MeshInstance3D.new()
	var fb_sph := SphereMesh.new()
	fb_sph.radius = 0.075
	fb_sph.height = 0.15
	fireball.mesh = fb_sph
	fireball.material_override = fire_mat
	fireball.scale = Vector3(0.2, 0.2, 0.2)
	fx.add_child(fireball)

	# 4. Dual Expanding Ground Shockwave Rings (Primary Gold + Secondary Crimson)
	var ring1_mat := StandardMaterial3D.new()
	ring1_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring1_mat.albedo_color = Color(1.0, 0.78, 0.22, 0.95)
	ring1_mat.emission_enabled = true
	ring1_mat.emission = Color(1.0, 0.68, 0.16)
	ring1_mat.emission_energy_multiplier = 2.8

	var ring1 := MeshInstance3D.new()
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = 0.045
	r_torus.outer_radius = 0.065
	ring1.mesh = r_torus
	ring1.material_override = ring1_mat
	ring1.scale = Vector3(0.3, 1.0, 0.3)
	fx.add_child(ring1)

	var ring2_mat := StandardMaterial3D.new()
	ring2_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring2_mat.albedo_color = Color(1.0, 0.26, 0.10, 0.90)
	ring2_mat.emission_enabled = true
	ring2_mat.emission = Color(1.0, 0.20, 0.06)
	ring2_mat.emission_energy_multiplier = 2.2

	var ring2 := MeshInstance3D.new()
	ring2.mesh = r_torus
	ring2.material_override = ring2_mat
	ring2.scale = Vector3(0.2, 1.0, 0.2)
	fx.add_child(ring2)

	# 5. Rising Mushroom Smoke Plume Cloud Spheres (7 billowing puffs)
	var smoke_puffs: Array[Dictionary] = []
	var puff_sph := SphereMesh.new()
	puff_sph.radius = 0.038
	puff_sph.height = 0.076
	for p_i in range(7):
		var sm_mat := StandardMaterial3D.new()
		sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm_mat.albedo_color = Color(0.18, 0.14, 0.13, 0.85)
		sm_mat.roughness = 0.9
		sm_mat.emission_enabled = true
		sm_mat.emission = Color(0.75, 0.22, 0.05)
		sm_mat.emission_energy_multiplier = 0.8

		var puff_mi := MeshInstance3D.new()
		puff_mi.mesh = puff_sph
		puff_mi.material_override = sm_mat
		puff_mi.scale = Vector3.ONE * 0.3
		fx.add_child(puff_mi)

		var ang := float(p_i) * TAU / 7.0
		var rad := 0.045 if p_i > 0 else 0.0
		smoke_puffs.append({
			"node": puff_mi,
			"mat": sm_mat,
			"target_pos": Vector3(cos(ang) * rad, 0.18 + float(p_i % 3) * 0.045, sin(ang) * rad),
			"target_scale": randf_range(1.25, 1.75)
		})

	# 6. 20 Ballistic Shrapnel & Glowing Ember Fragments
	var shrapnel_list: Array[Dictionary] = []
	var frag_box := BoxMesh.new()
	frag_box.size = Vector3(0.015, 0.012, 0.018)
	var ember_sph := SphereMesh.new()
	ember_sph.radius = 0.008
	ember_sph.height = 0.016

	for i in range(20):
		var is_ember := (i % 2) == 0
		var sh := MeshInstance3D.new()
		sh.mesh = ember_sph if is_ember else frag_box
		sh.material_override = mat_mine_core_red if is_ember else mat_mine_iron
		fx.add_child(sh)

		var ang := (float(i) / 20.0) * TAU + randf_range(-0.18, 0.18)
		var dist := randf_range(0.14, 0.38)
		var peak_h := randf_range(0.14, 0.36)
		var rot_spd := Vector3(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		shrapnel_list.append({
			"node": sh,
			"dir": Vector3(cos(ang) * dist, 0.0, sin(ang) * dist),
			"peak": peak_h,
			"rot": rot_spd
		})

	var tw := create_tween()
	tw.set_parallel(true)

	# Light flash decay
	tw.tween_property(blast_light, "light_energy", 0.0, 0.65).set_ease(Tween.EASE_OUT)

	# Inner core flash
	tw.tween_property(core_mi, "scale", Vector3(2.2, 2.0, 2.2), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(core_mat, "albedo_color:a", 0.0, 0.26)

	# Outer fireball expansion & rise
	tw.tween_property(fireball, "scale", Vector3(2.8, 2.5, 2.8), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fireball, "position:y", 0.085, 0.36)
	tw.tween_property(fire_mat, "albedo_color:a", 0.0, 0.42)

	# Shockwave rings
	tw.tween_property(ring1, "scale", Vector3(4.5, 1.0, 4.5), 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring1_mat, "albedo_color:a", 0.0, 0.44)
	tw.tween_property(ring2, "scale", Vector3(3.2, 1.0, 3.2), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring2_mat, "albedo_color:a", 0.0, 0.55)

	# Mushroom smoke cloud billowing upward
	for puff in smoke_puffs:
		var p_node: MeshInstance3D = puff["node"]
		var p_mat: StandardMaterial3D = puff["mat"]
		var t_pos: Vector3 = puff["target_pos"]
		var t_sc: float = puff["target_scale"]
		tw.tween_property(p_node, "position", t_pos, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_node, "scale", Vector3.ONE * t_sc, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p_mat, "emission_energy_multiplier", 0.0, 0.35)
		tw.tween_property(p_mat, "albedo_color:a", 0.0, 0.75).set_ease(Tween.EASE_IN)

	# Parabolic shrapnel trajectories
	for item in shrapnel_list:
		var sh_node: MeshInstance3D = item["node"]
		var target_dir: Vector3 = item["dir"]
		var peak_y: float = item["peak"]
		var rot_vec: Vector3 = item["rot"]
		tw.tween_method(func(t: float):
			var p := target_dir * t
			p.y = sin(t * PI) * peak_y
			sh_node.position = p
			sh_node.rotation = rot_vec * t
		, 0.0, 1.0, 0.58)
		tw.tween_property(sh_node, "scale", Vector3.ZERO, 0.58).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(fx.queue_free)

func _spawn_crater_smolder_puff(world_pos: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.012
	sph.height = 0.024
	puff.mesh = sph

	var sm_mat := StandardMaterial3D.new()
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.albedo_color = Color(0.24, 0.20, 0.18, 0.55)
	sm_mat.emission_enabled = true
	sm_mat.emission = Color(0.95, 0.32, 0.08)
	sm_mat.emission_energy_multiplier = 0.45
	puff.material_override = sm_mat

	var jitter := Vector3(randf_range(-0.018, 0.018), 0.035, randf_range(-0.018, 0.018))
	puff.position = world_pos + jitter
	puff.scale = Vector3.ONE * 0.45
	vfx_root.add_child(puff)

	var target_pos := puff.position + Vector3(randf_range(-0.025, 0.025), randf_range(0.08, 0.13), randf_range(-0.025, 0.025))
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "position", target_pos, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(puff, "scale", Vector3.ONE * 1.45, 0.85)
	tw.tween_property(sm_mat, "emission_energy_multiplier", 0.0, 0.45)
	tw.tween_property(sm_mat, "albedo_color:a", 0.0, 0.85)
	tw.chain().tween_callback(puff.queue_free)

func _spawn_flag_success_vfx(world_pos: Vector3) -> void:
	var fx := Node3D.new()
	fx.position = world_pos + Vector3(0.0, 0.028, 0.0)
	vfx_root.add_child(fx)

	# Dual rising emerald-gold celebratory rings
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.25, 1.0, 0.58, 0.92)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.22, 0.98, 0.54)
	ring_mat.emission_energy_multiplier = 2.2

	var ring := MeshInstance3D.new()
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = 0.032
	r_torus.outer_radius = 0.046
	ring.mesh = r_torus
	ring.material_override = ring_mat
	ring.scale = Vector3(0.5, 1.0, 0.5)
	fx.add_child(ring)

	# 8 Golden-Emerald rising spark stars
	var spark_sph := SphereMesh.new()
	spark_sph.radius = 0.0065
	spark_sph.height = 0.013
	var sparks: Array[MeshInstance3D] = []
	for i in range(8):
		var sp := MeshInstance3D.new()
		sp.mesh = spark_sph
		sp.material_override = mat_flag_cloth_gold if (i % 2 == 0) else mat_mine_core_green
		fx.add_child(sp)
		sparks.append(sp)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.2, 1.0, 2.2), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "position:y", 0.065, 0.42)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.42)

	for i in range(8):
		var ang := float(i) * TAU / 8.0
		var sp_node := sparks[i]
		var target := Vector3(cos(ang) * 0.075, 0.095, sin(ang) * 0.075)
		tw.tween_property(sp_node, "position", target, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp_node, "scale", Vector3.ZERO, 0.42).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(fx.queue_free)

func _spawn_flag_wrong_vfx(world_pos: Vector3) -> void:
	ActionVFXManager.shake_camera(0.035, 0.25)

	var fx := Node3D.new()
	fx.position = world_pos + Vector3(0.0, 0.028, 0.0)
	vfx_root.add_child(fx)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.25, 0.20, 0.90)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.20, 0.15)
	ring_mat.emission_energy_multiplier = 2.0

	var ring := MeshInstance3D.new()
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = 0.032
	r_torus.outer_radius = 0.046
	ring.mesh = r_torus
	ring.material_override = ring_mat
	ring.scale = Vector3(0.5, 1.0, 0.5)
	fx.add_child(ring)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.0, 1.0, 2.0), 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.34)
	tw.chain().tween_callback(fx.queue_free)

func _to_persian_digits(val: String) -> String:
	var eng := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var per := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := val
	for i in range(10):
		out = out.replace(eng[i], per[i])
	return out
