class_name FourInRow3D
extends "res://scripts/games/base_game_board.gd"

# Deluxe Royal 3D Four-in-a-Row (دوز چهارتایی) Gravity Rack Board
# 100% logic & payload parity with:
# - kafehfekrbackend/Controllers/GameSession/four_in_row_game_session.py
# - kafehfekrbackend/Entities/Games/FourInRow/__init__.py
# - kafehfekr/lib/Feature/FourInRow/Controllers/four_in_row_controller.dart
#
# Coordinate convention (1:1 with backend & Flutter):
# - r_index (0..7): Horizontal column from Left (0) to Right (7)
# - c_index (0..7): Vertical row from Top (0) to Bottom (7)
# - Gravity drops each piece into the lowest empty row (c_index = 7 down to 0) in column r_index
# - 1D cell index = c_index * 8 + r_index (0..63)

const GRID_SIZE: int = 8
const CELL_STEP: float = 0.102
const GRID_OFFSET_Z: float = 0.046
const CHUTE_Z: float = -0.422
const DRAG_THRESHOLD: float = 14.0

const _FONT_FA = preload("res://assets/fonts/hekayat.ttf")

# 8x8 Board State: board_state[c_index][r_index] = 0 (empty), 1 (Player 1 Red), 2 (Player 2 Blue)
var board_state: Array = []
var player1_pawns: int = 32
var player2_pawns: int = 32
var last_played_index: int = -1

# Scene Node References
var rack_pivot: Node3D = null
var discs_container: Node3D = null
var vfx_container: Node3D = null
var winning_line_node: Node3D = null
var hover_ghost_disc: Node3D = null
var last_played_ring: MeshInstance3D = null

# Interactive Hitboxes & Visual Elements
var col_buttons: Array[Area3D] = []          # 8 top drop-chute buttons (r_index 0..7)
var col_button_meshes: Array[MeshInstance3D] = []
var col_arrow_meshes: Array[MeshInstance3D] = []
var cell_areas: Array[Area3D] = []           # 64 cell hitboxes (c_index * 8 + r_index)
var cell_portholes: Array[MeshInstance3D] = []
var cell_target_rings: Array[MeshInstance3D] = []
var discs_nodes: Dictionary = {}             # cell_index (0..63) -> Node3D

# Side Dispenser Stacks & Counters
var p1_stack_nodes: Array[Node3D] = []
var p2_stack_nodes: Array[Node3D] = []
var p1_counter_lbl: Label3D = null
var p2_counter_lbl: Label3D = null

# Input & Hover Tracking
var hovered_col: int = -1
var _press_screen_pos: Vector2 = Vector2.ZERO
var _is_pointer_down: bool = false
var _last_click_time: float = 0.0
var _hover_bob_time: float = 0.0
var _active_tweens: Array[Tween] = []
var _rack_tilt_tween: Tween = null

# Luxury Procedural Materials
var mat_felt_base: StandardMaterial3D
var mat_mahogany_dark: StandardMaterial3D
var mat_walnut_frame: StandardMaterial3D
var mat_rack_royal_blue: StandardMaterial3D
var mat_rack_channel_well: StandardMaterial3D
var mat_gold_trim: StandardMaterial3D
var mat_platinum_trim: StandardMaterial3D
var mat_porthole_brass: StandardMaterial3D
var mat_porthole_hover: StandardMaterial3D
var mat_target_ring: StandardMaterial3D
var mat_last_played_ring: StandardMaterial3D
var mat_btn_normal: StandardMaterial3D
var mat_btn_hover: StandardMaterial3D
var mat_btn_disabled: StandardMaterial3D
var mat_arrow_gold: StandardMaterial3D
var mat_arrow_hover: StandardMaterial3D
var mat_piece_p1: StandardMaterial3D
var mat_piece_p1_well: StandardMaterial3D
var mat_piece_p1_ghost: StandardMaterial3D
var mat_piece_p2: StandardMaterial3D
var mat_piece_p2_well: StandardMaterial3D
var mat_piece_p2_ghost: StandardMaterial3D
var mat_win_beam: StandardMaterial3D

const PERSIAN_COLS = ["۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸"]

func _ready() -> void:
	game_type = GameTypes.FOURINROW
	_init_empty_board_state()
	_setup_materials()
	_build_luxury_architecture()
	_build_gravity_rack()
	_build_side_dispensers()
	_connect_camera_mode_signal()
	super._ready()

func _process(delta: float) -> void:
	_hover_bob_time += delta * 4.2
	if is_instance_valid(hover_ghost_disc) and hover_ghost_disc.visible:
		hover_ghost_disc.position.z = CHUTE_Z - 0.012 + sin(_hover_bob_time) * 0.009
		hover_ghost_disc.rotation_degrees.y = sin(_hover_bob_time * 0.6) * 8.0
	if is_instance_valid(last_played_ring) and last_played_ring.visible:
		var s = 1.0 + sin(_hover_bob_time * 1.4) * 0.045
		last_played_ring.scale = Vector3(s, 1.0, s)

func _init_empty_board_state() -> void:
	board_state.clear()
	for _c in range(GRID_SIZE):
		var row: Array = []
		for _r in range(GRID_SIZE):
			row.append(0)
		board_state.append(row)
	player1_pawns = 32
	player2_pawns = 32
	last_played_index = -1

# --- Materials Setup ---

func _setup_materials() -> void:
	# Weighted Green Tournament Felt Pad
	mat_felt_base = StandardMaterial3D.new()
	mat_felt_base.albedo_color = Color(0.07, 0.17, 0.10)
	mat_felt_base.roughness = 0.95
	mat_felt_base.metallic = 0.0

	# Deep Roasted Mahogany Plinth
	mat_mahogany_dark = StandardMaterial3D.new()
	mat_mahogany_dark.albedo_color = Color(0.16, 0.09, 0.05)
	mat_mahogany_dark.metallic = 0.04
	mat_mahogany_dark.roughness = 0.36
	mat_mahogany_dark.clearcoat_enabled = true
	mat_mahogany_dark.clearcoat = 0.60
	mat_mahogany_dark.clearcoat_roughness = 0.18

	# Hand-Rubbed Royal Walnut Frame & Pillars
	mat_walnut_frame = StandardMaterial3D.new()
	mat_walnut_frame.albedo_color = Color(0.26, 0.15, 0.09)
	mat_walnut_frame.metallic = 0.05
	mat_walnut_frame.roughness = 0.30
	mat_walnut_frame.clearcoat_enabled = true
	mat_walnut_frame.clearcoat = 0.68
	mat_walnut_frame.clearcoat_roughness = 0.15

	# Classic Royal Connect-4 Deep Prussian Navy-Slate Cage Body
	mat_rack_royal_blue = StandardMaterial3D.new()
	mat_rack_royal_blue.albedo_color = Color(0.11, 0.17, 0.28)
	mat_rack_royal_blue.metallic = 0.18
	mat_rack_royal_blue.roughness = 0.28
	mat_rack_royal_blue.clearcoat_enabled = true
	mat_rack_royal_blue.clearcoat = 0.65
	mat_rack_royal_blue.clearcoat_roughness = 0.16

	# Recessed Obsidian-Velvet Slot Backing inside Cage
	mat_rack_channel_well = StandardMaterial3D.new()
	mat_rack_channel_well.albedo_color = Color(0.06, 0.08, 0.12)
	mat_rack_channel_well.metallic = 0.05
	mat_rack_channel_well.roughness = 0.78

	# Polished 24K Imperial Gold Inlay & Trim
	mat_gold_trim = StandardMaterial3D.new()
	mat_gold_trim.albedo_color = Color(0.98, 0.82, 0.30)
	mat_gold_trim.metallic = 0.94
	mat_gold_trim.roughness = 0.16
	mat_gold_trim.clearcoat_enabled = true
	mat_gold_trim.clearcoat = 0.88
	mat_gold_trim.clearcoat_roughness = 0.06
	mat_gold_trim.emission_enabled = true
	mat_gold_trim.emission = Color(0.32, 0.24, 0.06)

	# Polished Sterling Platinum Trim
	mat_platinum_trim = StandardMaterial3D.new()
	mat_platinum_trim.albedo_color = Color(0.92, 0.95, 1.0)
	mat_platinum_trim.metallic = 0.95
	mat_platinum_trim.roughness = 0.14
	mat_platinum_trim.clearcoat_enabled = true
	mat_platinum_trim.clearcoat = 0.90
	mat_platinum_trim.clearcoat_roughness = 0.05
	mat_platinum_trim.emission_enabled = true
	mat_platinum_trim.emission = Color(0.20, 0.24, 0.30)

	# Brushed Brass Circular Porthole Bezel
	mat_porthole_brass = StandardMaterial3D.new()
	mat_porthole_brass.albedo_color = Color(0.86, 0.70, 0.28)
	mat_porthole_brass.metallic = 0.86
	mat_porthole_brass.roughness = 0.24
	mat_porthole_brass.clearcoat_enabled = true
	mat_porthole_brass.clearcoat = 0.55

	# Illuminated Golden Porthole Bezel on Column Hover
	mat_porthole_hover = StandardMaterial3D.new()
	mat_porthole_hover.albedo_color = Color(1.0, 0.90, 0.42)
	mat_porthole_hover.metallic = 0.92
	mat_porthole_hover.roughness = 0.14
	mat_porthole_hover.emission_enabled = true
	mat_porthole_hover.emission = Color(0.96, 0.78, 0.24)
	mat_porthole_hover.emission_energy_multiplier = 0.85

	# Target Landing Cell Indicator Ring
	mat_target_ring = StandardMaterial3D.new()
	mat_target_ring.albedo_color = Color(1.0, 0.88, 0.32)
	mat_target_ring.metallic = 0.90
	mat_target_ring.roughness = 0.12
	mat_target_ring.emission_enabled = true
	mat_target_ring.emission = Color(1.0, 0.82, 0.22)
	mat_target_ring.emission_energy_multiplier = 1.45

	# Last Turn Played Radiant Gold Halo (matches Flutter yellow border)
	mat_last_played_ring = StandardMaterial3D.new()
	mat_last_played_ring.albedo_color = Color(1.0, 0.92, 0.28)
	mat_last_played_ring.metallic = 0.92
	mat_last_played_ring.roughness = 0.10
	mat_last_played_ring.emission_enabled = true
	mat_last_played_ring.emission = Color(1.0, 0.86, 0.18)
	mat_last_played_ring.emission_energy_multiplier = 1.65

	# Top Column Drop-Chute Button Materials
	mat_btn_normal = StandardMaterial3D.new()
	mat_btn_normal.albedo_color = Color(0.88, 0.82, 0.70)
	mat_btn_normal.metallic = 0.08
	mat_btn_normal.roughness = 0.30
	mat_btn_normal.clearcoat_enabled = true
	mat_btn_normal.clearcoat = 0.60

	mat_btn_hover = StandardMaterial3D.new()
	mat_btn_hover.albedo_color = Color(1.0, 0.92, 0.56)
	mat_btn_hover.metallic = 0.35
	mat_btn_hover.roughness = 0.18
	mat_btn_hover.emission_enabled = true
	mat_btn_hover.emission = Color(0.92, 0.74, 0.22)
	mat_btn_hover.emission_energy_multiplier = 0.65

	mat_btn_disabled = StandardMaterial3D.new()
	mat_btn_disabled.albedo_color = Color(0.32, 0.28, 0.24)
	mat_btn_disabled.metallic = 0.05
	mat_btn_disabled.roughness = 0.75

	mat_arrow_gold = StandardMaterial3D.new()
	mat_arrow_gold.albedo_color = Color(0.88, 0.24, 0.16)
	mat_arrow_gold.metallic = 0.45
	mat_arrow_gold.roughness = 0.22
	mat_arrow_gold.clearcoat_enabled = true
	mat_arrow_gold.clearcoat = 0.70

	mat_arrow_hover = StandardMaterial3D.new()
	mat_arrow_hover.albedo_color = Color(1.0, 0.86, 0.24)
	mat_arrow_hover.metallic = 0.85
	mat_arrow_hover.roughness = 0.14
	mat_arrow_hover.emission_enabled = true
	mat_arrow_hover.emission = Color(1.0, 0.80, 0.20)
	mat_arrow_hover.emission_energy_multiplier = 1.25

	# Player 1 (Red / Host): Royal Crimson Piano Lacquer Disc
	mat_piece_p1 = StandardMaterial3D.new()
	mat_piece_p1.albedo_color = Color(0.78, 0.11, 0.15)
	mat_piece_p1.metallic = 0.08
	mat_piece_p1.roughness = 0.20
	mat_piece_p1.clearcoat_enabled = true
	mat_piece_p1.clearcoat = 0.78
	mat_piece_p1.clearcoat_roughness = 0.12

	mat_piece_p1_well = StandardMaterial3D.new()
	mat_piece_p1_well.albedo_color = Color(0.50, 0.06, 0.09)
	mat_piece_p1_well.metallic = 0.04
	mat_piece_p1_well.roughness = 0.36
	mat_piece_p1_well.clearcoat_enabled = true
	mat_piece_p1_well.clearcoat = 0.45

	mat_piece_p1_ghost = StandardMaterial3D.new()
	mat_piece_p1_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_piece_p1_ghost.albedo_color = Color(0.95, 0.22, 0.26, 0.68)
	mat_piece_p1_ghost.emission_enabled = true
	mat_piece_p1_ghost.emission = Color(0.90, 0.18, 0.22)
	mat_piece_p1_ghost.emission_energy_multiplier = 0.65

	# Player 2 (Blue / Guest): Imperial Cobalt-Sapphire Piano Lacquer Disc
	mat_piece_p2 = StandardMaterial3D.new()
	mat_piece_p2.albedo_color = Color(0.11, 0.32, 0.76)
	mat_piece_p2.metallic = 0.08
	mat_piece_p2.roughness = 0.20
	mat_piece_p2.clearcoat_enabled = true
	mat_piece_p2.clearcoat = 0.78
	mat_piece_p2.clearcoat_roughness = 0.12

	mat_piece_p2_well = StandardMaterial3D.new()
	mat_piece_p2_well.albedo_color = Color(0.06, 0.18, 0.46)
	mat_piece_p2_well.metallic = 0.04
	mat_piece_p2_well.roughness = 0.36
	mat_piece_p2_well.clearcoat_enabled = true
	mat_piece_p2_well.clearcoat = 0.45

	mat_piece_p2_ghost = StandardMaterial3D.new()
	mat_piece_p2_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_piece_p2_ghost.albedo_color = Color(0.22, 0.56, 1.0, 0.68)
	mat_piece_p2_ghost.emission_enabled = true
	mat_piece_p2_ghost.emission = Color(0.18, 0.48, 0.95)
	mat_piece_p2_ghost.emission_energy_multiplier = 0.65

	# Winning 4-in-a-Row Energy Beam
	mat_win_beam = StandardMaterial3D.new()
	mat_win_beam.albedo_color = Color(1.0, 0.92, 0.38)
	mat_win_beam.metallic = 0.85
	mat_win_beam.roughness = 0.10
	mat_win_beam.emission_enabled = true
	mat_win_beam.emission = Color(1.0, 0.86, 0.24)
	mat_win_beam.emission_energy_multiplier = 2.2

# --- 3D Board & Stand Architecture ---

func _build_luxury_architecture() -> void:
	var arch = Node3D.new()
	arch.name = "LuxuryStandArchitecture"
	add_child(arch)

	# Tournament Felt Base Pad
	var felt = MeshInstance3D.new()
	var felt_box = BoxMesh.new()
	felt_box.size = Vector3(1.38, 0.010, 1.28)
	felt.mesh = felt_box
	felt.material_override = mat_felt_base
	felt.position = Vector3(0, -0.024, 0)
	arch.add_child(felt)

	# Left & Right Sculpted Walnut & Brass Trunnion Support Pillars (for 3D rack stand)
	for side in [-1.0, 1.0]:
		var px: float = side * 0.458
		var pillar = Node3D.new()
		pillar.name = "TrunnionPillar_L" if side < 0 else "TrunnionPillar_R"
		pillar.position = Vector3(px, 0.036, 0.0)
		arch.add_child(pillar)

		# Stepped Walnut Base Foot
		var foot = MeshInstance3D.new()
		var foot_box = BoxMesh.new()
		foot_box.size = Vector3(0.044, 0.028, 0.96)
		foot.mesh = foot_box
		foot.material_override = mat_walnut_frame
		foot.position = Vector3(0, 0.014, 0)
		pillar.add_child(foot)

		# Gold Accent Strip along Foot
		var strip = MeshInstance3D.new()
		var strip_box = BoxMesh.new()
		strip_box.size = Vector3(0.048, 0.008, 0.964)
		strip.mesh = strip_box
		strip.material_override = mat_gold_trim
		strip.position = Vector3(0, 0.028, 0)
		pillar.add_child(strip)

		# Central Turned Brass Trunnion Post & Hinge Wheel
		var post = MeshInstance3D.new()
		var post_cyl = CylinderMesh.new()
		post_cyl.top_radius = 0.018
		post_cyl.bottom_radius = 0.024
		post_cyl.height = 0.14
		post.mesh = post_cyl
		post.material_override = mat_walnut_frame
		post.position = Vector3(0, 0.085, 0.02)
		pillar.add_child(post)

		var wheel = MeshInstance3D.new()
		var wheel_torus = TorusMesh.new()
		wheel_torus.inner_radius = 0.018
		wheel_torus.outer_radius = 0.030
		wheel.mesh = wheel_torus
		wheel.material_override = mat_gold_trim
		wheel.position = Vector3(0, 0.145, 0.02)
		wheel.rotation_degrees = Vector3(0, 0, 90)
		pillar.add_child(wheel)

		# 4 Corner Brass Finial Bollards on Pillar Ends
		for z_end in [-0.45, 0.45]:
			var bollard = MeshInstance3D.new()
			var b_cyl = CylinderMesh.new()
			b_cyl.top_radius = 0.014
			b_cyl.bottom_radius = 0.018
			b_cyl.height = 0.038
			bollard.mesh = b_cyl
			bollard.material_override = mat_gold_trim
			bollard.position = Vector3(0, 0.045, z_end)
			pillar.add_child(bollard)

			var cap = MeshInstance3D.new()
			var c_sph = SphereMesh.new()
			c_sph.radius = 0.015
			c_sph.height = 0.030
			cap.mesh = c_sph
			cap.material_override = mat_piece_p1 if side < 0 else mat_piece_p2
			cap.position = Vector3(0, 0.068, z_end)
			pillar.add_child(cap)

func _build_gravity_rack() -> void:
	rack_pivot = Node3D.new()
	rack_pivot.name = "RackPivot"
	rack_pivot.position = Vector3(0, 0.044, 0)
	add_child(rack_pivot)

	discs_container = Node3D.new()
	discs_container.name = "DiscsContainer"
	rack_pivot.add_child(discs_container)

	vfx_container = Node3D.new()
	vfx_container.name = "VFXContainer"
	rack_pivot.add_child(vfx_container)

	var cage_group = Node3D.new()
	cage_group.name = "PerforatedGravityCage"
	rack_pivot.add_child(cage_group)

	var span: float = float(GRID_SIZE) * CELL_STEP # 0.816m

	# 1. Recessed Dark Velvet-Obsidian Backplate behind the 8x8 Cage
	var backplate = MeshInstance3D.new()
	var bp_box = BoxMesh.new()
	bp_box.size = Vector3(span + 0.044, 0.008, span + 0.044)
	backplate.mesh = bp_box
	backplate.material_override = mat_rack_channel_well
	backplate.position = Vector3(0, -0.004, GRID_OFFSET_Z)
	cage_group.add_child(backplate)

	# 2. 9 Vertical Column Divider Ribs (forming 8 physical gravity channels)
	for i in range(GRID_SIZE + 1):
		var rx: float = (float(i) - 4.0) * CELL_STEP
		var rib = MeshInstance3D.new()
		var rib_box = BoxMesh.new()
		var is_outer: bool = (i == 0 or i == GRID_SIZE)
		rib_box.size = Vector3(0.018 if is_outer else 0.012, 0.028, span + 0.024)
		rib.mesh = rib_box
		rib.material_override = mat_walnut_frame if is_outer else mat_rack_royal_blue
		rib.position = Vector3(rx, 0.014, GRID_OFFSET_Z)
		cage_group.add_child(rib)

		# Fine 24K Gold Inlay Strip on Top of Each Vertical Channel Divider
		var gold_inlay = MeshInstance3D.new()
		var gi_box = BoxMesh.new()
		gi_box.size = Vector3(0.006 if is_outer else 0.0035, 0.003, span + 0.020)
		gold_inlay.mesh = gi_box
		gold_inlay.material_override = mat_gold_trim
		gold_inlay.position = Vector3(rx, 0.029, GRID_OFFSET_Z)
		cage_group.add_child(gold_inlay)

	# 3. 9 Horizontal Structural Cross-Beams
	for j in range(GRID_SIZE + 1):
		var rz: float = (float(j) - 4.0) * CELL_STEP + GRID_OFFSET_Z
		var is_outer_h: bool = (j == 0 or j == GRID_SIZE)
		var beam = MeshInstance3D.new()
		var beam_box = BoxMesh.new()
		beam_box.size = Vector3(span + 0.036, 0.026 if is_outer_h else 0.020, 0.020 if is_outer_h else 0.012)
		beam.mesh = beam_box
		beam.material_override = mat_walnut_frame if is_outer_h else mat_rack_royal_blue
		beam.position = Vector3(0, 0.013, rz)
		cage_group.add_child(beam)

		if is_outer_h:
			var h_gold = MeshInstance3D.new()
			var hg_box = BoxMesh.new()
			hg_box.size = Vector3(span + 0.038, 0.004, 0.008)
			h_gold.mesh = hg_box
			h_gold.material_override = mat_gold_trim
			h_gold.position = Vector3(0, 0.028, rz)
			cage_group.add_child(h_gold)

	# 4. 8 Top Column Selection Funnel Buttons (FourInRowSelectionButton 0..7)
	col_buttons.clear()
	col_button_meshes.clear()
	col_arrow_meshes.clear()

	var header_bar = MeshInstance3D.new()
	var hb_box = BoxMesh.new()
	hb_box.size = Vector3(span + 0.040, 0.022, 0.094)
	header_bar.mesh = hb_box
	header_bar.material_override = mat_walnut_frame
	header_bar.position = Vector3(0, 0.010, CHUTE_Z)
	cage_group.add_child(header_bar)

	var header_gold = MeshInstance3D.new()
	var hbg_box = BoxMesh.new()
	hbg_box.size = Vector3(span + 0.044, 0.004, 0.098)
	header_gold.mesh = hbg_box
	header_gold.material_override = mat_gold_trim
	header_gold.position = Vector3(0, 0.022, CHUTE_Z)
	cage_group.add_child(header_gold)

	for r_idx in range(GRID_SIZE):
		var cx: float = _col_to_x(r_idx)
		var btn_root = Node3D.new()
		btn_root.name = "ColDropBtn_%d" % r_idx
		btn_root.position = Vector3(cx, 0.024, CHUTE_Z)
		cage_group.add_child(btn_root)

		# Beveled Luxury Button Pad
		var pad = MeshInstance3D.new()
		var pad_box = BoxMesh.new()
		pad_box.size = Vector3(CELL_STEP - 0.014, 0.012, 0.074)
		pad.mesh = pad_box
		pad.material_override = mat_btn_normal
		btn_root.add_child(pad)
		col_button_meshes.append(pad)

		# Gold Frame around Button Pad
		var b_ring = MeshInstance3D.new()
		var br_box = BoxMesh.new()
		br_box.size = Vector3(CELL_STEP - 0.010, 0.008, 0.078)
		b_ring.mesh = br_box
		b_ring.material_override = mat_gold_trim
		b_ring.position = Vector3(0, -0.002, 0)
		btn_root.add_child(b_ring)

		# Sculpted 3D Downward Arrow (▼) pointing into Column r_idx
		var arrow = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(0.036, 0.032, 0.008)
		arrow.mesh = prism
		arrow.material_override = mat_arrow_gold
		# Rotate PrismMesh so its apex points toward +Z (down into the column!)
		arrow.rotation_degrees = Vector3(90, 180, 0)
		arrow.position = Vector3(0, 0.009, 0.010)
		btn_root.add_child(arrow)
		col_arrow_meshes.append(arrow)

		# Column Number Label (۱..۸)
		var col_lbl = Label3D.new()
		col_lbl.text = PERSIAN_COLS[r_idx]
		col_lbl.font = _FONT_FA
		col_lbl.font_size = 34
		col_lbl.pixel_size = 0.00065
		col_lbl.modulate = Color(0.22, 0.14, 0.08)
		col_lbl.outline_size = 2
		col_lbl.outline_modulate = Color(1.0, 0.95, 0.85, 0.6)
		col_lbl.rotation_degrees = Vector3(-90, 0, 0)
		col_lbl.position = Vector3(0, 0.009, -0.018)
		btn_root.add_child(col_lbl)

		# Physics Hitbox for Top Selection Button
		var btn_area = Area3D.new()
		btn_area.name = "ColBtnArea_%d" % r_idx
		btn_area.set_meta("r_index", r_idx)
		btn_area.set_meta("is_col_btn", true)
		var btn_col = CollisionShape3D.new()
		var btn_shape = BoxShape3D.new()
		btn_shape.size = Vector3(CELL_STEP, 0.045, 0.095)
		btn_col.shape = btn_shape
		btn_area.add_child(btn_col)
		btn_root.add_child(btn_area)
		col_buttons.append(btn_area)

	# 5. 64 Circular Beveled Portholes & Hitboxes (c_index = 0..7, r_index = 0..7)
	cell_areas.clear()
	cell_portholes.clear()
	cell_target_rings.clear()

	for c_idx in range(GRID_SIZE):
		for r_idx in range(GRID_SIZE):
			var cell_pos: Vector3 = _cell_to_local_pos(c_idx, r_idx)
			var cell_node = Node3D.new()
			cell_node.name = "Slot_%d_%d" % [c_idx, r_idx]
			cell_node.position = cell_pos
			cage_group.add_child(cell_node)

			# Circular Recessed Well Backing
			var well = MeshInstance3D.new()
			var well_cyl = CylinderMesh.new()
			well_cyl.top_radius = 0.042
			well_cyl.bottom_radius = 0.042
			well_cyl.height = 0.006
			well_cyl.radial_segments = 24
			well.mesh = well_cyl
			well.material_override = mat_rack_channel_well
			well.position = Vector3(0, 0.002, 0)
			cell_node.add_child(well)

			# Circular Brushed Brass Porthole Bezel on Cage Front
			var bezel = MeshInstance3D.new()
			var bezel_torus = TorusMesh.new()
			bezel_torus.inner_radius = 0.038
			bezel_torus.outer_radius = 0.046
			bezel_torus.rings = 24
			bezel_torus.ring_segments = 12
			bezel.mesh = bezel_torus
			bezel.material_override = mat_porthole_brass
			bezel.position = Vector3(0, 0.025, 0)
			cell_node.add_child(bezel)
			cell_portholes.append(bezel)

			# Inner Target Ring (Hidden until column is hovered and this cell is the landing row)
			var target_ring = MeshInstance3D.new()
			var tr_torus = TorusMesh.new()
			tr_torus.inner_radius = 0.030
			tr_torus.outer_radius = 0.036
			tr_torus.rings = 24
			tr_torus.ring_segments = 12
			target_ring.mesh = tr_torus
			target_ring.material_override = mat_target_ring
			target_ring.position = Vector3(0, 0.008, 0)
			target_ring.visible = false
			cell_node.add_child(target_ring)
			cell_target_rings.append(target_ring)

			# Physics Hitbox for Clicking Any Cell in Column r_idx
			var area = Area3D.new()
			area.name = "CellArea_%d_%d" % [c_idx, r_idx]
			area.set_meta("c_index", c_idx)
			area.set_meta("r_index", r_idx)
			var col_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(CELL_STEP, 0.045, CELL_STEP)
			col_shape.shape = box_shape
			area.add_child(col_shape)
			cell_node.add_child(area)
			cell_areas.append(area)

	# 6. Last-Turn Played Radiant Golden Halo Ring
	last_played_ring = MeshInstance3D.new()
	last_played_ring.name = "LastPlayedHalo"
	var lp_torus = TorusMesh.new()
	lp_torus.inner_radius = 0.039
	lp_torus.outer_radius = 0.047
	lp_torus.rings = 28
	lp_torus.ring_segments = 14
	last_played_ring.mesh = lp_torus
	last_played_ring.material_override = mat_last_played_ring
	last_played_ring.visible = false
	rack_pivot.add_child(last_played_ring)

	# 7. Hover Ghost Preview Disc above Chute
	hover_ghost_disc = _create_disc_node(1, true)
	hover_ghost_disc.name = "HoverGhostDisc"
	hover_ghost_disc.visible = false
	rack_pivot.add_child(hover_ghost_disc)

func _build_side_dispensers() -> void:
	p1_stack_nodes.clear()
	p2_stack_nodes.clear()

	# Left Side Dispenser (Player 1 - Crimson Red, 32 discs) & Right Side Dispenser (Player 2 - Sapphire Blue, 32 discs)
	for side_idx in range(2):
		var is_p1: bool = (side_idx == 0)
		var sx: float = -0.562 if is_p1 else 0.562
		var tray = Node3D.new()
		tray.name = "DispenserTray_P1" if is_p1 else "DispenserTray_P2"
		tray.position = Vector3(sx, 0.038, 0.02)
		add_child(tray)

		# Carved Mahogany Tray Bed
		var bed = MeshInstance3D.new()
		var bed_box = BoxMesh.new()
		bed_box.size = Vector3(0.092, 0.016, 0.78)
		bed.mesh = bed_box
		bed.material_override = mat_mahogany_dark
		tray.add_child(bed)

		# Gold Rim Border
		var rim = MeshInstance3D.new()
		var rim_box = BoxMesh.new()
		rim_box.size = Vector3(0.098, 0.008, 0.786)
		rim.mesh = rim_box
		rim.material_override = mat_gold_trim
		rim.position = Vector3(0, 0.008, 0)
		tray.add_child(rim)

		# Live Remaining Pawns Counter Label3D (۳۲ .. ۰)
		var counter_lbl = Label3D.new()
		counter_lbl.text = _fa_digits(32)
		counter_lbl.font = _FONT_FA
		counter_lbl.font_size = 44
		counter_lbl.pixel_size = 0.0008
		counter_lbl.modulate = Color(1.0, 0.45, 0.48) if is_p1 else Color(0.48, 0.75, 1.0)
		counter_lbl.outline_size = 6
		counter_lbl.outline_modulate = Color(0.08, 0.05, 0.03)
		counter_lbl.rotation_degrees = Vector3(-90, 0, 0)
		counter_lbl.position = Vector3(0, 0.018, -0.33)
		tray.add_child(counter_lbl)
		if is_p1:
			p1_counter_lbl = counter_lbl
		else:
			p2_counter_lbl = counter_lbl

		# 32 Stacked Physical Reserve Discs arranged in 2 rows of 16 upright-tilted coins
		for i in range(32):
			var col_lane: int = i / 16 # 0 or 1
			var slot_in_lane: int = i % 16
			var dx: float = -0.018 if col_lane == 0 else 0.018
			var dz: float = -0.24 + float(slot_in_lane) * 0.036
			var mini_disc = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.015
			cyl.bottom_radius = 0.015
			cyl.height = 0.018
			cyl.radial_segments = 16
			mini_disc.mesh = cyl
			mini_disc.material_override = mat_piece_p1 if is_p1 else mat_piece_p2
			mini_disc.position = Vector3(dx, 0.018, dz)
			tray.add_child(mini_disc)

			var g_ring = MeshInstance3D.new()
			var gt = TorusMesh.new()
			gt.inner_radius = 0.010
			gt.outer_radius = 0.014
			g_ring.mesh = gt
			g_ring.material_override = mat_gold_trim if is_p1 else mat_platinum_trim
			g_ring.position = Vector3(0, 0.0095, 0)
			mini_disc.add_child(g_ring)

			if is_p1:
				p1_stack_nodes.append(mini_disc)
			else:
				p2_stack_nodes.append(mini_disc)

func _update_dispenser_visuals() -> void:
	if is_instance_valid(p1_counter_lbl):
		p1_counter_lbl.text = _fa_digits(max(0, player1_pawns))
	if is_instance_valid(p2_counter_lbl):
		p2_counter_lbl.text = _fa_digits(max(0, player2_pawns))
	for i in range(p1_stack_nodes.size()):
		if is_instance_valid(p1_stack_nodes[i]):
			p1_stack_nodes[i].visible = (i < player1_pawns)
	for i in range(p2_stack_nodes.size()):
		if is_instance_valid(p2_stack_nodes[i]):
			p2_stack_nodes[i].visible = (i < player2_pawns)

# --- 3D Lathe-Turned & Ribbed Four-in-a-Row Disc Model ---

func _create_disc_node(gamer_id: int, is_ghost: bool = false) -> Node3D:
	var disc = Node3D.new()
	var mat_body: Material = (mat_piece_p1_ghost if gamer_id == 1 else mat_piece_p2_ghost) if is_ghost else (mat_piece_p1 if gamer_id == 1 else mat_piece_p2)
	var mat_well: Material = mat_body if is_ghost else (mat_piece_p1_well if gamer_id == 1 else mat_piece_p2_well)
	var mat_metal: Material = mat_body if is_ghost else (mat_gold_trim if gamer_id == 1 else mat_platinum_trim)

	# 1. Outer Ribbed Tire Body
	var outer = MeshInstance3D.new()
	outer.name = "DiscBody"
	var outer_cyl = CylinderMesh.new()
	outer_cyl.top_radius = 0.039
	outer_cyl.bottom_radius = 0.039
	outer_cyl.height = 0.018
	outer_cyl.radial_segments = 28
	outer.mesh = outer_cyl
	outer.material_override = mat_body
	outer.position = Vector3(0, 0.011, 0)
	disc.add_child(outer)

	# 2. Recessed Concentric Inner Dish
	var well = MeshInstance3D.new()
	var well_cyl = CylinderMesh.new()
	well_cyl.top_radius = 0.030
	well_cyl.bottom_radius = 0.030
	well_cyl.height = 0.019
	well_cyl.radial_segments = 24
	well.mesh = well_cyl
	well.material_override = mat_well
	well.position = Vector3(0, 0.0112, 0)
	disc.add_child(well)

	# 3. 16 Radial Knurled Edge Grip Ridges around the Disc Rim
	if not is_ghost:
		for i in range(16):
			var angle: float = float(i) * (TAU / 16.0)
			var ridge = MeshInstance3D.new()
			var r_box = BoxMesh.new()
			r_box.size = Vector3(0.0032, 0.016, 0.0085)
			ridge.mesh = r_box
			ridge.material_override = mat_body
			ridge.position = Vector3(cos(angle) * 0.0365, 0.0115, sin(angle) * 0.0365)
			ridge.rotation = Vector3(0, -angle + PI * 0.5, 0)
			disc.add_child(ridge)

	# 4. Outer & Inner Concentric Machined Metallic Rings
	var ring_outer = MeshInstance3D.new()
	var ro_torus = TorusMesh.new()
	ro_torus.inner_radius = 0.029
	ro_torus.outer_radius = 0.033
	ro_torus.rings = 24
	ro_torus.ring_segments = 12
	ring_outer.mesh = ro_torus
	ring_outer.material_override = mat_metal
	ring_outer.position = Vector3(0, 0.0205, 0)
	disc.add_child(ring_outer)

	var ring_inner = MeshInstance3D.new()
	var ri_torus = TorusMesh.new()
	ri_torus.inner_radius = 0.016
	ri_torus.outer_radius = 0.0195
	ri_torus.rings = 20
	ri_torus.ring_segments = 10
	ring_inner.mesh = ri_torus
	ring_inner.material_override = mat_metal
	ring_inner.position = Vector3(0, 0.0208, 0)
	disc.add_child(ring_inner)

	# 5. Center Embossed 4-Pointed Star Medallion Boss (Symbolizing Four-in-a-Row)
	var boss = MeshInstance3D.new()
	var boss_cyl = CylinderMesh.new()
	boss_cyl.top_radius = 0.011
	boss_cyl.bottom_radius = 0.013
	boss_cyl.height = 0.0205
	boss_cyl.radial_segments = 16
	boss.mesh = boss_cyl
	boss.material_override = mat_body
	boss.position = Vector3(0, 0.0115, 0)
	disc.add_child(boss)

	for rot_deg in [0.0, 45.0]:
		var star_arm = MeshInstance3D.new()
		var sa_box = BoxMesh.new()
		sa_box.size = Vector3(0.014, 0.0025, 0.014)
		star_arm.mesh = sa_box
		star_arm.material_override = mat_metal
		star_arm.position = Vector3(0, 0.022, 0)
		star_arm.rotation_degrees = Vector3(0, rot_deg, 0)
		disc.add_child(star_arm)

	return disc

# --- Coordinate & Board Helpers ---

func _col_to_x(r_index: int) -> float:
	return (float(r_index) - 3.5) * CELL_STEP

func _row_to_z(c_index: int) -> float:
	return (float(c_index) - 3.5) * CELL_STEP + GRID_OFFSET_Z

func _cell_to_local_pos(c_index: int, r_index: int) -> Vector3:
	return Vector3(_col_to_x(r_index), 0.0, _row_to_z(c_index))

func _get_lowest_empty_row(r_index: int) -> int:
	if r_index < 0 or r_index >= GRID_SIZE:
		return -1
	for c_idx in range(GRID_SIZE - 1, -1, -1):
		if int(board_state[c_idx][r_index]) == 0:
			return c_idx
	return -1

func _is_col_valid(r_index: int) -> bool:
	return _get_lowest_empty_row(r_index) != -1

func _refresh_column_buttons_state() -> void:
	for r_idx in range(GRID_SIZE):
		var valid: bool = _is_col_valid(r_idx)
		if r_idx < col_button_meshes.size() and is_instance_valid(col_button_meshes[r_idx]):
			if not valid:
				col_button_meshes[r_idx].material_override = mat_btn_disabled
			elif r_idx == hovered_col and is_my_turn and not is_board_locked:
				col_button_meshes[r_idx].material_override = mat_btn_hover
			else:
				col_button_meshes[r_idx].material_override = mat_btn_normal
		if r_idx < col_arrow_meshes.size() and is_instance_valid(col_arrow_meshes[r_idx]):
			if not valid:
				col_arrow_meshes[r_idx].material_override = mat_btn_disabled
			elif r_idx == hovered_col and is_my_turn and not is_board_locked:
				col_arrow_meshes[r_idx].material_override = mat_arrow_hover
			else:
				col_arrow_meshes[r_idx].material_override = mat_arrow_gold

# --- 2D / 3D Camera Mode Rack Tilt Sync (Passive Only - Never Forces Camera Mode) ---

func _connect_camera_mode_signal() -> void:
	var table = get_tree().get_first_node_in_group("cafe_table")
	if table:
		if table.has_signal("camera_mode_changed") and not table.camera_mode_changed.is_connected(_on_camera_mode_changed):
			table.camera_mode_changed.connect(_on_camera_mode_changed)
		var is_2d: bool = bool(table.get("is_top_down_view")) if "is_top_down_view" in table else true
		_apply_rack_tilt(is_2d, false)

func _on_camera_mode_changed(is_top_down: bool) -> void:
	_apply_rack_tilt(is_top_down, true)

func _apply_rack_tilt(is_top_down: bool, animated: bool = true) -> void:
	if not is_instance_valid(rack_pivot):
		return
	if _rack_tilt_tween and _rack_tilt_tween.is_valid():
		_rack_tilt_tween.kill()
	# In 2D Top-Down view: flat (0 deg) so all 64 portholes & 8 drop buttons face the top-down camera squarely.
	# In 3D Orbit view: inclined (+26 deg) on its brass side trunnion pillars like a classic standing 3D gravity rack!
	var target_rot_x: float = 0.0 if is_top_down else 26.0
	var target_pos_y: float = 0.044 if is_top_down else 0.215
	if not animated:
		rack_pivot.rotation_degrees.x = target_rot_x
		rack_pivot.position.y = target_pos_y
		return
	_rack_tilt_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rack_tilt_tween.tween_property(rack_pivot, "rotation_degrees:x", target_rot_x, 0.38)
	_rack_tilt_tween.tween_property(rack_pivot, "position:y", target_pos_y, 0.38)

# --- Single-Source Camera Raycast Input (Rule 4.2) ---

func _unhandled_input(event: InputEvent) -> void:
	if is_board_locked or not GameManager.is_game_active:
		_clear_hover()
		return

	if event is InputEventMouseMotion:
		_handle_pointer_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_pointer_down = true
			_press_screen_pos = event.position
			_handle_pointer_hover(event.position)
		else:
			if _is_pointer_down:
				_is_pointer_down = false
				if _press_screen_pos.distance_to(event.position) <= DRAG_THRESHOLD:
					_handle_pointer_tap(event.position)

func _raycast_column_at(screen_pos: Vector2) -> int:
	var viewport = get_viewport()
	if not viewport:
		return -1
	var cam = viewport.get_camera_3d()
	if not cam:
		return -1
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 12.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var col_obj = result["collider"]
		if col_obj and col_obj.has_meta("r_index"):
			return int(col_obj.get_meta("r_index"))
	return -1

func _handle_pointer_hover(screen_pos: Vector2) -> void:
	var r_idx: int = _raycast_column_at(screen_pos)
	if r_idx == hovered_col:
		return
	hovered_col = r_idx
	_update_hover_visuals()

func _clear_hover() -> void:
	if hovered_col == -1 and (not is_instance_valid(hover_ghost_disc) or not hover_ghost_disc.visible):
		return
	hovered_col = -1
	_update_hover_visuals()

func _update_hover_visuals() -> void:
	# Reset all portholes and target rings
	for i in range(cell_portholes.size()):
		if is_instance_valid(cell_portholes[i]):
			var col_i: int = i % GRID_SIZE
			if col_i == hovered_col and is_my_turn and not is_board_locked and _is_col_valid(hovered_col):
				cell_portholes[i].material_override = mat_porthole_hover
			else:
				cell_portholes[i].material_override = mat_porthole_brass
	for i in range(cell_target_rings.size()):
		if is_instance_valid(cell_target_rings[i]):
			cell_target_rings[i].visible = false

	_refresh_column_buttons_state()

	if hovered_col != -1 and is_my_turn and not is_board_locked:
		var target_c: int = _get_lowest_empty_row(hovered_col)
		if target_c != -1:
			var target_idx: int = target_c * GRID_SIZE + hovered_col
			if target_idx >= 0 and target_idx < cell_target_rings.size() and is_instance_valid(cell_target_rings[target_idx]):
				cell_target_rings[target_idx].visible = true
			if is_instance_valid(hover_ghost_disc):
				hover_ghost_disc.visible = true
				hover_ghost_disc.position = Vector3(_col_to_x(hovered_col), 0.022, CHUTE_Z - 0.012)
				_update_ghost_disc_material(my_player_index if my_player_index in [1, 2] else 1)
			return

	if is_instance_valid(hover_ghost_disc):
		hover_ghost_disc.visible = false

func _update_ghost_disc_material(gamer_id: int) -> void:
	if not is_instance_valid(hover_ghost_disc):
		return
	var g_mat: Material = mat_piece_p1_ghost if gamer_id == 1 else mat_piece_p2_ghost
	for child in hover_ghost_disc.get_children():
		if child is MeshInstance3D:
			child.material_override = g_mat

func _handle_pointer_tap(screen_pos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_click_time < 0.22:
		return
	var r_idx: int = _raycast_column_at(screen_pos)
	if r_idx == -1:
		return
	_on_column_selection_tap(r_idx)

func _on_column_selection_tap(r_index: int) -> void:
	if is_board_locked or not GameManager.is_game_active:
		return
	if not is_my_turn:
		AudioManager.play_sound("tap_wrong")
		show_hint("نوبت شما نیست!")
		return
	if not _is_col_valid(r_index):
		AudioManager.play_sound("tap_wrong")
		show_hint("این ستون پر شده است!")
		return

	_last_click_time = Time.get_ticks_msec() / 1000.0
	set_board_locked(true)
	_clear_hover()

	# Animate top column button press
	if r_index >= 0 and r_index < col_button_meshes.size() and is_instance_valid(col_button_meshes[r_index]):
		var btn_mesh = col_button_meshes[r_index]
		var tw = _create_tracked_tween()
		tw.tween_property(btn_mesh, "position:y", -0.005, 0.06)
		tw.tween_property(btn_mesh, "position:y", 0.0, 0.10)

	AudioManager.play_sound("tap")
	# 1:1 with Flutter controller.onSelectionTap(rowIndex):
	# sendCommand({"id": GameCommands.selectPeace, "data": {'r_index': rowIndex}})
	send_move(Commands.Select_Peace, {"r_index": r_index})

# --- BaseGameBoard Lifecycle Hooks ---

func setup_board(_game_data: Dictionary) -> void:
	reset_board()

func on_turn_changed(turn: int, is_me: bool) -> void:
	current_turn = turn
	is_my_turn = is_me
	set_board_locked(not is_me)
	_update_ghost_disc_material(my_player_index if my_player_index in [1, 2] else turn)
	_update_hover_visuals()
	if is_me:
		AudioManager.play_sound("start_turn")

func on_piece_selected(user_id: int, target_peace: int, extra: Dictionary = {}) -> void:
	var gamer_id: int = int(extra.get("gamer_id", user_id))
	var r_index: int = int(extra.get("r_index", target_peace % GRID_SIZE))
	var c_index: int = int(extra.get("c_index", target_peace / GRID_SIZE))
	if extra.has("select_data") and typeof(extra["select_data"]) == TYPE_DICTIONARY:
		var sdata: Dictionary = extra["select_data"]
		r_index = int(sdata.get("r_index", r_index))
		c_index = int(sdata.get("c_index", c_index))
		gamer_id = int(sdata.get("gamer_id", gamer_id))

	if c_index < 0 or c_index >= GRID_SIZE or r_index < 0 or r_index >= GRID_SIZE:
		return
	if gamer_id not in [1, 2]:
		gamer_id = 1 if current_turn == 1 else 2

	# Update pawn counts (1:1 with backend & Flutter)
	if gamer_id == 1:
		player1_pawns = max(0, player1_pawns - 1)
	else:
		player2_pawns = max(0, player2_pawns - 1)
	_update_dispenser_visuals()

	board_state[c_index][r_index] = gamer_id
	var cell_idx: int = c_index * GRID_SIZE + r_index
	last_played_index = cell_idx

	_refresh_column_buttons_state()
	_spawn_and_drop_disc(c_index, r_index, gamer_id, true)

func sync_board_state(board_data: Variant) -> void:
	if typeof(board_data) != TYPE_ARRAY:
		return
	var arr: Array = board_data
	if arr.size() < 64:
		return

	_clear_discs_and_vfx()
	var p1_placed: int = 0
	var p2_placed: int = 0

	for idx in range(64):
		var c_idx: int = idx / GRID_SIZE
		var r_idx: int = idx % GRID_SIZE
		var val: int = int(arr[idx])
		board_state[c_idx][r_idx] = val
		if val == 1 or val == 2:
			if val == 1:
				p1_placed += 1
			else:
				p2_placed += 1
			_spawn_and_drop_disc(c_idx, r_idx, val, false)

	player1_pawns = max(0, 32 - p1_placed)
	player2_pawns = max(0, 32 - p2_placed)
	_update_dispenser_visuals()
	_refresh_column_buttons_state()

func on_reconnect_data(payload: Dictionary) -> void:
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		if g_data.has("board"):
			sync_board_state(g_data["board"])
		if g_data.has("pawns_count") and typeof(g_data["pawns_count"]) == TYPE_ARRAY:
			var pc: Array = g_data["pawns_count"]
			if pc.size() >= 2:
				player1_pawns = int(pc[0])
				player2_pawns = int(pc[1])
				_update_dispenser_visuals()
	_refresh_column_buttons_state()

func on_round_finished(_payload: Variant) -> void:
	set_board_locked(true)
	_clear_hover()

func on_new_round(_round_num: int) -> void:
	reset_board()

func reset_board() -> void:
	_clear_hover()
	_clear_discs_and_vfx()
	_init_empty_board_state()
	_update_dispenser_visuals()
	_refresh_column_buttons_state()

func cleanup_board() -> void:
	_kill_all_tweens()
	if _rack_tilt_tween and _rack_tilt_tween.is_valid():
		_rack_tilt_tween.kill()
	_clear_discs_and_vfx()

# --- Gravity Drop Animation, Last-Played Highlight & Winning Line VFX ---

func _spawn_and_drop_disc(c_index: int, r_index: int, gamer_id: int, animated: bool) -> void:
	var cell_idx: int = c_index * GRID_SIZE + r_index
	if discs_nodes.has(cell_idx) and is_instance_valid(discs_nodes[cell_idx]):
		discs_nodes[cell_idx].queue_free()
		discs_nodes.erase(cell_idx)

	var disc: Node3D = _create_disc_node(gamer_id, false)
	discs_container.add_child(disc)
	discs_nodes[cell_idx] = disc

	var target_pos: Vector3 = _cell_to_local_pos(c_index, r_index)

	if not animated:
		disc.position = target_pos
		_update_last_played_ring(c_index, r_index)
		return

	# Spawn at the top drop-chute funnel of column r_index
	var start_pos := Vector3(_col_to_x(r_index), 0.004, CHUTE_Z)
	disc.position = start_pos
	disc.scale = Vector3(0.45, 0.45, 0.45)

	AudioManager.play_sound("move_peace")

	# Physics-inspired gravity fall time proportional to sqrt(drop distance)
	var fall_duration: float = clamp(0.18 + sqrt(float(c_index + 1)) * 0.082, 0.24, 0.44)
	var bounce_dist: float = clamp(0.022 + float(c_index) * 0.0025, 0.022, 0.040)

	var tw: Tween = _create_tracked_tween()
	# 1. Quick pop-in at funnel mouth
	tw.tween_property(disc, "scale", Vector3.ONE, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2. Gravity-accelerated drop down column channel (+Z)
	tw.tween_property(disc, "position", target_pos, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 3. Impact sound, VFX shockwave, and last-played ring activation
	tw.tween_callback(func():
		if not is_instance_valid(self) or not is_inside_tree() or not is_instance_valid(disc):
			return
		AudioManager.play_sound("add_peace")
		_update_last_played_ring(c_index, r_index)
		_pulse_porthole_bezel(c_index, r_index)
		var p_col := Color(1.0, 0.25, 0.30) if gamer_id == 1 else Color(0.28, 0.68, 1.0)
		ActionVFXManager.play_piece_drop_vfx(self, disc.global_position, p_col)
	)
	# 4. Crisp physical bounce up & settle at bottom of column
	var bounce_pos := target_pos + Vector3(0, 0.005, -bounce_dist)
	tw.tween_property(disc, "position", bounce_pos, 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "position", target_pos, 0.068).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 5. Check for 4-in-a-Row winning line highlight
	tw.tween_callback(func():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		var win_cells: Array = _find_winning_line(c_index, r_index, gamer_id)
		if win_cells.size() >= 4:
			_spawn_winning_line_vfx(win_cells, gamer_id)
	)

func _update_last_played_ring(c_index: int, r_index: int) -> void:
	if not is_instance_valid(last_played_ring):
		return
	last_played_ring.visible = true
	last_played_ring.position = _cell_to_local_pos(c_index, r_index) + Vector3(0, 0.026, 0)

func _pulse_porthole_bezel(c_index: int, r_index: int) -> void:
	var idx: int = c_index * GRID_SIZE + r_index
	if idx < 0 or idx >= cell_portholes.size():
		return
	var bezel = cell_portholes[idx]
	if not is_instance_valid(bezel):
		return
	bezel.material_override = mat_porthole_hover
	var tw = _create_tracked_tween()
	tw.tween_property(bezel, "scale", Vector3(1.14, 1.14, 1.14), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bezel, "scale", Vector3.ONE, 0.14)
	tw.tween_callback(func():
		if is_instance_valid(bezel):
			bezel.material_override = mat_porthole_brass
	)

func _find_winning_line(c_index: int, r_index: int, gamer_id: int) -> Array:
	# Check all 4 axes passing through (c_index, r_index): Horizontal, Vertical, Diag \, Diag /
	var axes = [
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(1, -1)
	]
	for axis in axes:
		var line: Array = [Vector2i(c_index, r_index)]
		# Forward along axis
		var step: int = 1
		while step < 8:
			var nc: int = c_index + axis.x * step
			var nr: int = r_index + axis.y * step
			if nc >= 0 and nc < GRID_SIZE and nr >= 0 and nr < GRID_SIZE and int(board_state[nc][nr]) == gamer_id:
				line.append(Vector2i(nc, nr))
				step += 1
			else:
				break
		# Backward along axis
		step = 1
		while step < 8:
			var nc: int = c_index - axis.x * step
			var nr: int = r_index - axis.y * step
			if nc >= 0 and nc < GRID_SIZE and nr >= 0 and nr < GRID_SIZE and int(board_state[nc][nr]) == gamer_id:
				line.push_front(Vector2i(nc, nr))
				step += 1
			else:
				break
		if line.size() >= 4:
			return line.slice(0, 4)
	return []

func _spawn_winning_line_vfx(win_cells: Array, gamer_id: int) -> void:
	if is_instance_valid(winning_line_node):
		winning_line_node.queue_free()

	winning_line_node = Node3D.new()
	winning_line_node.name = "WinningLineStrike"
	vfx_container.add_child(winning_line_node)

	var first_cell: Vector2i = win_cells[0]
	var last_cell: Vector2i = win_cells[win_cells.size() - 1]
	var p_start: Vector3 = _cell_to_local_pos(first_cell.x, first_cell.y) + Vector3(0, 0.034, 0)
	var p_end: Vector3 = _cell_to_local_pos(last_cell.x, last_cell.y) + Vector3(0, 0.034, 0)
	var center_pos: Vector3 = (p_start + p_end) * 0.5
	var length: float = p_start.distance_to(p_end) + 0.055
	var angle_y: float = atan2(p_end.x - p_start.x, p_end.z - p_start.z)

	# Glowing Golden Energy Beam connecting the 4 winning discs
	var beam = MeshInstance3D.new()
	var beam_cyl = CylinderMesh.new()
	beam_cyl.top_radius = 0.011
	beam_cyl.bottom_radius = 0.011
	beam_cyl.height = length
	beam.mesh = beam_cyl
	beam.material_override = mat_win_beam
	beam.position = center_pos
	beam.rotation = Vector3(PI * 0.5, angle_y, 0)
	beam.scale = Vector3(1.0, 0.01, 1.0)
	winning_line_node.add_child(beam)

	var b_tw = _create_tracked_tween()
	b_tw.tween_property(beam, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Radiant Halos & Pulse on all 4 Winning Discs
	for coord in win_cells:
		var c_pos: Vector3 = _cell_to_local_pos(coord.x, coord.y) + Vector3(0, 0.030, 0)
		var halo = MeshInstance3D.new()
		var h_torus = TorusMesh.new()
		h_torus.inner_radius = 0.038
		h_torus.outer_radius = 0.048
		halo.mesh = h_torus
		halo.material_override = mat_win_beam
		halo.position = c_pos
		winning_line_node.add_child(halo)

		var c_idx: int = coord.x * GRID_SIZE + coord.y
		if discs_nodes.has(c_idx) and is_instance_valid(discs_nodes[c_idx]):
			var d_node: Node3D = discs_nodes[c_idx]
			var d_tw = _create_tracked_tween()
			d_tw.tween_property(d_node, "scale", Vector3(1.15, 1.25, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			d_tw.tween_property(d_node, "scale", Vector3.ONE, 0.16)

	ActionVFXManager.play_win_celebration_vfx(self, winning_line_node.to_global(center_pos), gamer_id)

# --- Cleanup & Tween Tracking Helpers ---

func _create_tracked_tween() -> Tween:
	var tw = create_tween()
	_active_tweens.append(tw)
	return tw

func _kill_all_tweens() -> void:
	for tw in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()

func _clear_discs_and_vfx() -> void:
	_kill_all_tweens()
	for k in discs_nodes.keys():
		var n = discs_nodes[k]
		if is_instance_valid(n):
			n.queue_free()
	discs_nodes.clear()
	if is_instance_valid(winning_line_node):
		winning_line_node.queue_free()
		winning_line_node = null
	if is_instance_valid(last_played_ring):
		last_played_ring.visible = false
	if is_instance_valid(hover_ghost_disc):
		hover_ghost_disc.visible = false

func _fa_digits(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(str(i), fa[i])
	return s
