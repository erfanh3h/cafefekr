class_name UnoTable3D
extends Node3D

# UnoTable3D - Cafe Fekr Royal 3D UNO Tabletop Showcase
# - Layered dark walnut & mahogany gaming chassis with brass corner bolsters
# - Recessed emerald velvet bed with brass inlay trim & card cradles
# - Interactive 3D Draw Pile & active 3D Discard Pile with under-cards stack
# - Animated 3D Active Color Crystal Beacon & orbiting Direction Flow Beads
# - Surrounding tabletop 3D props: Interactive Golden UNO Bell, Enamel Chip Bowl,
#   Brass Sand Hourglass, Score Ledger & Gold Pen, and 3D Opponent Card Racks

signal draw_pile_clicked()
signal uno_bell_clicked()

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const UNO_COLORS: Dictionary = {
	"red": Color(0.90, 0.16, 0.19),
	"yellow": Color(0.95, 0.76, 0.07),
	"green": Color(0.13, 0.69, 0.31),
	"blue": Color(0.11, 0.46, 0.92),
	"wild": Color(0.10, 0.11, 0.14)
}

const UNO_COLOR_NAMES_FA: Dictionary = {
	"red": "قرمز",
	"yellow": "زرد",
	"green": "سبز",
	"blue": "آبی",
	"wild": "آزاد"
}

var draw_pile_root: Node3D
var _draw_stack_body: MeshInstance3D
var _draw_top_card: Node3D
var _draw_highlight_frame: MeshInstance3D
var _draw_count_label: Label3D

var discard_pile_root: Node3D
var _discard_top_pivot: Node3D
var _discard_face_mesh: MeshInstance3D
var _discard_face_mat: StandardMaterial3D
var _discard_oval_mesh: MeshInstance3D
var _discard_oval_mat: StandardMaterial3D
var _discard_wild_quads: Node3D
var _discard_center_lbl: Label3D
var _discard_corner_tl: Label3D
var _discard_corner_br: Label3D

var color_indicator_root: Node3D
var _color_crystal_node: MeshInstance3D
var _color_halo_ring: MeshInstance3D
var _color_gem_mat: StandardMaterial3D
var _color_name_3d: Label3D

var _direction_pivot: Node3D
var _direction_orbit_ring: Node3D
var _direction_arrow_lbl: Label3D
var _direction_bead_mat: StandardMaterial3D
var _current_direction: int = 1

var _uno_bell_root: Node3D
var _uno_bell_plunger: MeshInstance3D
var _uno_bell_alert_ring: MeshInstance3D
var _uno_bell_alert_active: bool = false

var _hourglass_sand_pivot: Node3D
var _anim_time: float = 0.0

var _opponent_fans: Dictionary = {} # seat_idx (1=Top, 2=Left, 3=Right) -> Node3D

func _ready() -> void:
	_build_tabletop()

func _process(delta: float) -> void:
	_anim_time += delta

	# Rotate & gently levitate the Active Color Crystal Beacon
	if is_instance_valid(_color_crystal_node):
		_color_crystal_node.rotate_y(delta * 1.45)
		_color_crystal_node.position.y = 0.038 + sin(_anim_time * 2.6) * 0.004

	if is_instance_valid(_color_halo_ring):
		var sc = 1.0 + sin(_anim_time * 3.0) * 0.06
		_color_halo_ring.scale = Vector3(sc, 1.0, sc)

	# Orbit direction beads smoothly around the center arena
	if is_instance_valid(_direction_orbit_ring):
		_direction_orbit_ring.rotate_y(-delta * 0.85 * float(_current_direction))

	# Pulse UNO Bell alert ring when player has 1-2 cards
	if is_instance_valid(_uno_bell_alert_ring) and _uno_bell_alert_active:
		var pulse = 1.0 + sin(_anim_time * 6.0) * 0.10
		_uno_bell_alert_ring.scale = Vector3(pulse, 1.0, pulse)

	# Pulse Draw highlight frame when player needs to draw
	if is_instance_valid(_draw_highlight_frame) and _draw_highlight_frame.visible:
		var dp = 1.0 + sin(_anim_time * 5.0) * 0.03
		_draw_highlight_frame.scale = Vector3(dp, 1.0, dp)

func _create_label_3d(txt: String, f_size: int = 39, col: Color = Color.WHITE, p_size: float = 0.0012) -> Label3D:
	var lbl = Label3D.new()
	lbl.font = FontHekayat
	lbl.text = txt
	lbl.font_size = f_size
	lbl.pixel_size = p_size
	lbl.modulate = col
	lbl.outline_size = 8
	lbl.outline_modulate = Color(0.04, 0.05, 0.07, 0.92)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 20) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_torus(parent: Node3D, inner_r: float, outer_r: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = inner_r
	tm.outer_radius = outer_r
	tm.rings = 28
	tm.ring_segments = 10
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_tabletop() -> void:
	var y_base: float = 0.064

	# --- Luxury Tabletop Materials ---
	var mat_walnut = StandardMaterial3D.new()
	mat_walnut.albedo_color = Color(0.15, 0.08, 0.045)
	mat_walnut.roughness = 0.34
	mat_walnut.metallic = 0.06

	var mat_mahogany = StandardMaterial3D.new()
	mat_mahogany.albedo_color = Color(0.24, 0.11, 0.06)
	mat_mahogany.roughness = 0.30
	mat_mahogany.metallic = 0.08

	var mat_emerald = StandardMaterial3D.new()
	mat_emerald.albedo_color = Color(0.05, 0.23, 0.15)
	mat_emerald.roughness = 0.86

	var mat_emerald_well = StandardMaterial3D.new()
	mat_emerald_well.albedo_color = Color(0.035, 0.16, 0.105)
	mat_emerald_well.roughness = 0.90

	var mat_bronze = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.84, 0.67, 0.28)
	mat_bronze.metallic = 0.84
	mat_bronze.roughness = 0.25

	var mat_aged_brass = StandardMaterial3D.new()
	mat_aged_brass.albedo_color = Color(0.56, 0.43, 0.18)
	mat_aged_brass.metallic = 0.78
	mat_aged_brass.roughness = 0.36

	var mat_shadow = StandardMaterial3D.new()
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	mat_shadow.roughness = 1.0

	var mat_paper = StandardMaterial3D.new()
	mat_paper.albedo_color = Color(0.95, 0.93, 0.89)
	mat_paper.roughness = 0.46

	var mat_white_card = StandardMaterial3D.new()
	mat_white_card.albedo_color = Color(0.99, 0.99, 0.99)
	mat_white_card.roughness = 0.22

	var mat_uno_back = StandardMaterial3D.new()
	mat_uno_back.albedo_color = Color(0.09, 0.10, 0.13)
	mat_uno_back.roughness = 0.26

	var mat_uno_red = StandardMaterial3D.new()
	mat_uno_red.albedo_color = UNO_COLORS["red"]
	mat_uno_red.roughness = 0.22

	var mat_glass = StandardMaterial3D.new()
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.85, 0.94, 1.0, 0.34)
	mat_glass.roughness = 0.08

	var mat_amber_sand = StandardMaterial3D.new()
	mat_amber_sand.albedo_color = Color(0.95, 0.72, 0.22)
	mat_amber_sand.emission_enabled = true
	mat_amber_sand.emission = Color(0.85, 0.56, 0.14)
	mat_amber_sand.emission_energy_multiplier = 0.65

	# =========================================================================
	# 1. MULTI-TIER WALNUT & MAHOGANY GAMING TABLE CHASSIS + BRASS BOLSTERS
	# =========================================================================
	# Outer Walnut Surround Deck (Holds side props around the emerald baize)
	_add_box(self, Vector3(1.18, 0.014, 0.96), Vector3(0.0, y_base + 0.007, -0.02), mat_walnut)
	# Brass Outer Lip
	_add_box(self, Vector3(1.19, 0.004, 0.014), Vector3(0.0, y_base + 0.015, -0.495), mat_aged_brass)
	_add_box(self, Vector3(1.19, 0.004, 0.014), Vector3(0.0, y_base + 0.015, 0.455), mat_aged_brass)
	_add_box(self, Vector3(0.014, 0.004, 0.96), Vector3(-0.585, y_base + 0.015, -0.02), mat_aged_brass)
	_add_box(self, Vector3(0.014, 0.004, 0.96), Vector3(0.585, y_base + 0.015, -0.02), mat_aged_brass)

	# Carved Mahogany Inner Arena Frame
	_add_box(self, Vector3(0.94, 0.010, 0.78), Vector3(0.0, y_base + 0.014, -0.02), mat_mahogany)

	# Emerald Velvet Playing Bed
	_add_box(self, Vector3(0.86, 0.006, 0.70), Vector3(0.0, y_base + 0.018, -0.02), mat_emerald)

	# Subtle Brass Pinstripe Trim around Emerald Felt
	_add_box(self, Vector3(0.868, 0.002, 0.007), Vector3(0.0, y_base + 0.0215, -0.370), mat_bronze)
	_add_box(self, Vector3(0.868, 0.002, 0.007), Vector3(0.0, y_base + 0.0215, 0.330), mat_bronze)
	_add_box(self, Vector3(0.007, 0.002, 0.700), Vector3(-0.432, y_base + 0.0215, -0.02), mat_bronze)
	_add_box(self, Vector3(0.007, 0.002, 0.700), Vector3(0.432, y_base + 0.0215, -0.02), mat_bronze)

	# 4 Corner Brass Bolsters + Rivet Studs on the Mahogany Frame
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cx = sx * 0.448
			var cz = -0.02 + sz * 0.368
			_add_cyl(self, 0.022, 0.026, 0.014, Vector3(cx, y_base + 0.022, cz), mat_bronze, Vector3.ZERO, 8)
			_add_cyl(self, 0.010, 0.012, 0.017, Vector3(cx, y_base + 0.024, cz), mat_aged_brass, Vector3.ZERO, 8)

	# =========================================================================
	# 2. ANIMATED 3D DIRECTION ORBIT RING & FLOW INDICATOR
	# =========================================================================
	var ring_center = Vector3(-0.04, y_base + 0.0215, 0.005)
	_add_torus(self, 0.238, 0.244, ring_center, mat_aged_brass)

	_direction_orbit_ring = Node3D.new()
	_direction_orbit_ring.position = ring_center
	add_child(_direction_orbit_ring)

	_direction_bead_mat = StandardMaterial3D.new()
	_direction_bead_mat.albedo_color = UNO_COLORS["red"]
	_direction_bead_mat.emission_enabled = true
	_direction_bead_mat.emission = UNO_COLORS["red"]
	_direction_bead_mat.emission_energy_multiplier = 1.05
	_direction_bead_mat.roughness = 0.18

	# 4 Orbiting Brass-Cased Gem Beads on the Orbit Ring
	for b_i in range(4):
		var ang = float(b_i) * PI * 0.5
		var bx = cos(ang) * 0.241
		var bz = sin(ang) * 0.241
		_add_cyl(_direction_orbit_ring, 0.014, 0.016, 0.005, Vector3(bx, 0.002, bz), mat_bronze, Vector3.ZERO, 12)
		var gem_mi = MeshInstance3D.new()
		var sm = SphereMesh.new()
		sm.radius = 0.009
		sm.height = 0.012
		gem_mi.mesh = sm
		gem_mi.position = Vector3(bx, 0.006, bz)
		gem_mi.material_override = _direction_bead_mat
		_direction_orbit_ring.add_child(gem_mi)

	_direction_pivot = Node3D.new()
	_direction_pivot.position = Vector3(-0.04, y_base + 0.022, 0.245)
	add_child(_direction_pivot)

	# Framed plaque for Direction Text
	_add_box(_direction_pivot, Vector3(0.28, 0.004, 0.044), Vector3(0.0, 0.001, 0.0), mat_walnut)
	_add_box(_direction_pivot, Vector3(0.29, 0.002, 0.048), Vector3(0.0, 0.0, 0.0), mat_bronze)

	_direction_arrow_lbl = _create_label_3d("↻ ساعتگرد", 28, Color(0.98, 0.90, 0.62), 0.00105)
	_direction_arrow_lbl.position = Vector3(0.0, 0.005, 0.0)
	_direction_arrow_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_direction_pivot.add_child(_direction_arrow_lbl)

	# =========================================================================
	# 3. DRAW PILE (Left of Center) - Brass-Framed Card Cradle + UNO Deck
	# =========================================================================
	draw_pile_root = Node3D.new()
	draw_pile_root.position = Vector3(-0.180, y_base + 0.022, 0.005)
	add_child(draw_pile_root)

	# Walnut & Brass Card Cradle Base
	_add_box(draw_pile_root, Vector3(0.204, 0.004, 0.286), Vector3(0.0, 0.001, 0.0), mat_walnut)
	_add_box(draw_pile_root, Vector3(0.194, 0.002, 0.276), Vector3(0.0, 0.003, 0.0), mat_emerald_well)
	for cx in [-0.095, 0.095]:
		for cz in [-0.136, 0.136]:
			_add_box(draw_pile_root, Vector3(0.024, 0.006, 0.024), Vector3(cx, 0.004, cz), mat_bronze)

	var draw_shadow = _add_box(draw_pile_root, Vector3(0.186, 0.001, 0.268), Vector3(0.005, 0.0042, 0.006), mat_shadow)
	draw_shadow.name = "DrawShadow"

	# Interactive Golden Highlight Frame (Visible when player should draw)
	_draw_highlight_frame = _add_box(draw_pile_root, Vector3(0.212, 0.004, 0.296), Vector3(0.0, 0.0045, 0.0), mat_bronze)
	var dh_mat = StandardMaterial3D.new()
	dh_mat.albedo_color = Color(1.0, 0.88, 0.30)
	dh_mat.emission_enabled = true
	dh_mat.emission = Color(1.0, 0.78, 0.18)
	dh_mat.emission_energy_multiplier = 1.6
	_draw_highlight_frame.material_override = dh_mat
	_draw_highlight_frame.visible = false

	# 3D Paper Deck Block
	_draw_stack_body = _add_box(draw_pile_root, Vector3(0.172, 0.042, 0.252), Vector3(0.0, 0.024, 0.0), mat_paper)

	# Top Face-Down UNO Card on the Draw Pile
	_draw_top_card = Node3D.new()
	_draw_top_card.position = Vector3(0.0, 0.046, 0.0)
	draw_pile_root.add_child(_draw_top_card)

	_add_box(_draw_top_card, Vector3(0.174, 0.003, 0.254), Vector3.ZERO, mat_white_card)
	_add_box(_draw_top_card, Vector3(0.158, 0.0035, 0.238), Vector3(0.0, 0.0005, 0.0), mat_uno_back)

	var dt_oval = MeshInstance3D.new()
	var dto_cyl = CylinderMesh.new()
	dto_cyl.top_radius = 0.062
	dto_cyl.bottom_radius = 0.062
	dto_cyl.height = 0.002
	dto_cyl.radial_segments = 24
	dt_oval.mesh = dto_cyl
	dt_oval.scale = Vector3(1.0, 1.0, 1.42)
	dt_oval.position = Vector3(0.0, 0.0022, 0.0)
	dt_oval.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	dt_oval.material_override = mat_uno_red
	_draw_top_card.add_child(dt_oval)

	var uno_logo_3d = _create_label_3d("UNO", 45, Color(1.0, 0.86, 0.18), 0.00115)
	uno_logo_3d.outline_size = 12
	uno_logo_3d.position = Vector3(0.0, 0.004, 0.0)
	uno_logo_3d.rotation_degrees = Vector3(-90.0, 0.0, -15.0)
	_draw_top_card.add_child(uno_logo_3d)

	_draw_count_label = _create_label_3d("۸۰ کارت", 26, Color(0.95, 0.96, 0.90), 0.00105)
	_draw_count_label.position = Vector3(0.0, 0.006, 0.165)
	_draw_count_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	draw_pile_root.add_child(_draw_count_label)

	var draw_body = StaticBody3D.new()
	var draw_col = CollisionShape3D.new()
	var draw_shape = BoxShape3D.new()
	draw_shape.size = Vector3(0.22, 0.09, 0.30)
	draw_col.shape = draw_shape
	draw_col.position = Vector3(0.0, 0.035, 0.0)
	draw_body.add_child(draw_col)
	draw_body.input_event.connect(func(_cam, event, _pos, _norm, _idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			draw_pile_clicked.emit()
	)
	draw_pile_root.add_child(draw_body)

	# =========================================================================
	# 4. DISCARD PILE (Center-Right) - Framed Velvet Tray + Stacked Cards
	# =========================================================================
	discard_pile_root = Node3D.new()
	discard_pile_root.position = Vector3(0.095, y_base + 0.022, 0.005)
	add_child(discard_pile_root)

	_add_box(discard_pile_root, Vector3(0.218, 0.004, 0.304), Vector3.ZERO, mat_walnut)
	_add_box(discard_pile_root, Vector3(0.208, 0.002, 0.294), Vector3(0.0, 0.002, 0.0), mat_emerald_well)
	for cx in [-0.102, 0.102]:
		for cz in [-0.145, 0.145]:
			_add_box(discard_pile_root, Vector3(0.024, 0.006, 0.024), Vector3(cx, 0.004, cz), mat_bronze)

	_add_box(discard_pile_root, Vector3(0.202, 0.001, 0.288), Vector3(0.006, 0.0035, 0.006), mat_shadow)

	# 3 Underneath Discard Cards for organic stack feel
	for u_i in range(3):
		var under_c = _add_box(
			discard_pile_root,
			Vector3(0.184, 0.003, 0.266),
			Vector3(0.0, 0.0045 + float(u_i) * 0.003, 0.0),
			mat_paper,
			Vector3(0.0, -11.0 + float(u_i) * 10.5, 0.0)
		)
		under_c.name = "UnderCard_%d" % u_i

	_discard_top_pivot = Node3D.new()
	_discard_top_pivot.position = Vector3(0.0, 0.015, 0.0)
	_discard_top_pivot.rotation_degrees = Vector3(0.0, 3.5, 0.0)
	discard_pile_root.add_child(_discard_top_pivot)

	_add_box(_discard_top_pivot, Vector3(0.192, 0.004, 0.278), Vector3.ZERO, mat_white_card)

	_discard_face_mesh = MeshInstance3D.new()
	var df_box = BoxMesh.new()
	df_box.size = Vector3(0.174, 0.0045, 0.260)
	_discard_face_mesh.mesh = df_box
	_discard_face_mesh.position = Vector3(0.0, 0.0006, 0.0)
	_discard_face_mat = StandardMaterial3D.new()
	_discard_face_mat.albedo_color = UNO_COLORS["red"]
	_discard_face_mat.roughness = 0.24
	_discard_face_mesh.material_override = _discard_face_mat
	_discard_top_pivot.add_child(_discard_face_mesh)

	_discard_oval_mesh = MeshInstance3D.new()
	var do_cyl = CylinderMesh.new()
	do_cyl.top_radius = 0.068
	do_cyl.bottom_radius = 0.068
	do_cyl.height = 0.0018
	do_cyl.radial_segments = 28
	_discard_oval_mesh.mesh = do_cyl
	_discard_oval_mesh.scale = Vector3(1.0, 1.0, 1.42)
	_discard_oval_mesh.position = Vector3(0.0, 0.0032, 0.0)
	_discard_oval_mesh.rotation_degrees = Vector3(0.0, -15.0, 0.0)
	_discard_oval_mat = StandardMaterial3D.new()
	_discard_oval_mat.albedo_color = Color(0.99, 0.99, 0.99)
	_discard_oval_mat.roughness = 0.20
	_discard_oval_mesh.material_override = _discard_oval_mat
	_discard_top_pivot.add_child(_discard_oval_mesh)

	_discard_wild_quads = Node3D.new()
	_discard_wild_quads.position = Vector3(0.0, 0.0044, 0.0)
	_discard_wild_quads.visible = false
	_discard_top_pivot.add_child(_discard_wild_quads)
	var quad_offsets = [
		{"pos": Vector3(-0.024, 0, -0.028), "col": UNO_COLORS["red"]},
		{"pos": Vector3(0.024, 0, -0.028), "col": UNO_COLORS["blue"]},
		{"pos": Vector3(-0.024, 0, 0.028), "col": UNO_COLORS["yellow"]},
		{"pos": Vector3(0.024, 0, 0.028), "col": UNO_COLORS["green"]},
	]
	for qo in quad_offsets:
		var q_mat = StandardMaterial3D.new()
		q_mat.albedo_color = qo["col"]
		q_mat.roughness = 0.25
		_add_cyl(_discard_wild_quads, 0.024, 0.024, 0.001, qo["pos"], q_mat, Vector3.ZERO, 18)

	_discard_corner_tl = _create_label_3d("۷", 31, Color.WHITE, 0.0011)
	_discard_corner_tl.position = Vector3(-0.062, 0.0055, -0.098)
	_discard_corner_tl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_discard_top_pivot.add_child(_discard_corner_tl)

	_discard_center_lbl = _create_label_3d("۷", 71, UNO_COLORS["red"], 0.00125)
	_discard_center_lbl.outline_size = 6
	_discard_center_lbl.outline_modulate = Color(1.0, 1.0, 1.0, 0.92)
	_discard_center_lbl.position = Vector3(0.0, 0.006, 0.0)
	_discard_center_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_discard_top_pivot.add_child(_discard_center_lbl)

	_discard_corner_br = _create_label_3d("۷", 31, Color.WHITE, 0.0011)
	_discard_corner_br.position = Vector3(0.062, 0.0055, 0.098)
	_discard_corner_br.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	_discard_top_pivot.add_child(_discard_corner_br)

	# =========================================================================
	# 5. 3D ACTIVE COLOR CRYSTAL BEACON PEDESTAL (Right of Discard Pile)
	# =========================================================================
	color_indicator_root = Node3D.new()
	color_indicator_root.position = Vector3(0.305, y_base + 0.022, 0.005)
	add_child(color_indicator_root)

	# Stepped Walnut & Brass Octagonal Pedestal
	_add_cyl(color_indicator_root, 0.062, 0.068, 0.010, Vector3(0.0, 0.005, 0.0), mat_walnut, Vector3.ZERO, 8)
	_add_cyl(color_indicator_root, 0.052, 0.056, 0.010, Vector3(0.0, 0.012, 0.0), mat_bronze, Vector3.ZERO, 8)

	_color_gem_mat = StandardMaterial3D.new()
	_color_gem_mat.albedo_color = UNO_COLORS["red"]
	_color_gem_mat.roughness = 0.14
	_color_gem_mat.metallic = 0.25
	_color_gem_mat.emission_enabled = true
	_color_gem_mat.emission = UNO_COLORS["red"]
	_color_gem_mat.emission_energy_multiplier = 1.15

	# Glowing Halo Ring
	_color_halo_ring = _add_torus(color_indicator_root, 0.040, 0.048, Vector3(0.0, 0.018, 0.0), _color_gem_mat)

	# Faceted Rotating Diamond Crystal
	_color_crystal_node = MeshInstance3D.new()
	var crys_mesh = SphereMesh.new()
	crys_mesh.radius = 0.028
	crys_mesh.height = 0.058
	crys_mesh.radial_segments = 6
	crys_mesh.rings = 2
	_color_crystal_node.mesh = crys_mesh
	_color_crystal_node.position = Vector3(0.0, 0.038, 0.0)
	_color_crystal_node.material_override = _color_gem_mat
	color_indicator_root.add_child(_color_crystal_node)

	_color_name_3d = _create_label_3d("قرمز", 27, Color.WHITE, 0.00105)
	_color_name_3d.position = Vector3(0.0, 0.018, 0.088)
	_color_name_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	color_indicator_root.add_child(_color_name_3d)

	# =========================================================================
	# 6. 3D OPPONENT CARD RACKS & TURN BEACONS AROUND UPPER TABLE EDGES
	# =========================================================================
	var opp_slots = {
		1: {"pos": Vector3(0.0, y_base + 0.022, -0.305), "rot_y": 0.0},
		2: {"pos": Vector3(-0.355, y_base + 0.022, -0.145), "rot_y": -65.0},
		3: {"pos": Vector3(0.355, y_base + 0.022, -0.145), "rot_y": 65.0},
	}
	for s_idx in opp_slots.keys():
		var cfg = opp_slots[s_idx]
		var fan_holder = Node3D.new()
		fan_holder.position = cfg["pos"]
		fan_holder.rotation_degrees = Vector3(0.0, float(cfg["rot_y"]), 0.0)
		fan_holder.visible = false
		add_child(fan_holder)
		_opponent_fans[s_idx] = fan_holder

	# =========================================================================
	# 7. SURROUNDING 3D TABLETOP PROPS AROUND THE UNO BOARD LEDGES
	# =========================================================================
	_build_uno_bell_prop(Vector3(0.505, y_base + 0.015, 0.315), mat_walnut, mat_bronze, mat_uno_red)
	_build_uno_chips_bowl_prop(Vector3(-0.505, y_base + 0.015, 0.315), mat_mahogany, mat_bronze)
	_build_mini_hourglass_prop(Vector3(-0.505, y_base + 0.015, -0.355), mat_walnut, mat_bronze, mat_glass, mat_amber_sand)
	_build_score_ledger_prop(Vector3(0.505, y_base + 0.015, -0.355), mat_mahogany, mat_paper, mat_bronze)

func _build_uno_bell_prop(pos: Vector3, mat_walnut: Material, mat_brass: Material, mat_red: Material) -> void:
	_uno_bell_root = Node3D.new()
	_uno_bell_root.name = "UnoShoutBell3D"
	_uno_bell_root.position = pos
	add_child(_uno_bell_root)

	# Carved Walnut Coaster + Brass Bell Dome
	_add_cyl(_uno_bell_root, 0.068, 0.074, 0.010, Vector3(0.0, 0.005, 0.0), mat_walnut, Vector3.ZERO, 20)
	_add_cyl(_uno_bell_root, 0.056, 0.062, 0.008, Vector3(0.0, 0.013, 0.0), mat_brass, Vector3.ZERO, 24)
	_add_cyl(_uno_bell_root, 0.044, 0.054, 0.024, Vector3(0.0, 0.028, 0.0), mat_brass, Vector3.ZERO, 24)

	# Ruby-Red Buzzer Plunger Button on top of Bell
	_uno_bell_plunger = _add_cyl(_uno_bell_root, 0.022, 0.024, 0.014, Vector3(0.0, 0.044, 0.0), mat_red, Vector3.ZERO, 20)

	# Glowing Gold Alert Ring (active when player has 1-2 cards)
	var alert_mat = StandardMaterial3D.new()
	alert_mat.albedo_color = Color(1.0, 0.86, 0.22)
	alert_mat.emission_enabled = true
	alert_mat.emission = Color(1.0, 0.72, 0.12)
	alert_mat.emission_energy_multiplier = 2.0
	_uno_bell_alert_ring = _add_torus(_uno_bell_root, 0.064, 0.072, Vector3(0.0, 0.011, 0.0), alert_mat)
	_uno_bell_alert_ring.visible = false

	var bell_lbl = _create_label_3d("UNO!", 26, Color(1.0, 0.90, 0.35), 0.00095)
	bell_lbl.position = Vector3(0.0, 0.014, 0.088)
	bell_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_uno_bell_root.add_child(bell_lbl)

	# Interactive Raycast Hitbox
	var bell_body = StaticBody3D.new()
	var b_col = CollisionShape3D.new()
	var b_shape = CylinderShape3D.new()
	b_shape.radius = 0.085
	b_shape.height = 0.075
	b_col.shape = b_shape
	b_col.position = Vector3(0.0, 0.032, 0.0)
	bell_body.add_child(b_col)
	bell_body.input_event.connect(func(_cam, event, _p, _n, _idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			animate_uno_bell_tap()
			uno_bell_clicked.emit()
	)
	_uno_bell_root.add_child(bell_body)

func _build_uno_chips_bowl_prop(pos: Vector3, mat_wood: Material, mat_brass: Material) -> void:
	var bowl = Node3D.new()
	bowl.name = "UnoChipBowl3D"
	bowl.position = pos
	add_child(bowl)

	_add_cyl(bowl, 0.074, 0.056, 0.018, Vector3(0.0, 0.009, 0.0), mat_wood, Vector3.ZERO, 24)
	_add_torus(bowl, 0.066, 0.075, Vector3(0.0, 0.018, 0.0), mat_brass)

	var chip_specs = [
		{"pos": Vector3(-0.022, 0.020, -0.016), "count": 4, "col": UNO_COLORS["red"]},
		{"pos": Vector3(0.022, 0.020, -0.016), "count": 3, "col": UNO_COLORS["blue"]},
		{"pos": Vector3(-0.018, 0.020, 0.022), "count": 3, "col": UNO_COLORS["yellow"]},
		{"pos": Vector3(0.022, 0.020, 0.020), "count": 4, "col": UNO_COLORS["green"]},
	]
	for cs in chip_specs:
		var c_mat = StandardMaterial3D.new()
		c_mat.albedo_color = cs["col"]
		c_mat.roughness = 0.24
		var base_p: Vector3 = cs["pos"]
		for i in range(int(cs["count"])):
			var y_off = float(i) * 0.0055
			_add_cyl(bowl, 0.018, 0.018, 0.005, base_p + Vector3(0.0, y_off, 0.0), c_mat, Vector3.ZERO, 16)
			_add_cyl(bowl, 0.011, 0.011, 0.0054, base_p + Vector3(0.0, y_off, 0.0), mat_brass, Vector3.ZERO, 12)

func _build_mini_hourglass_prop(pos: Vector3, mat_walnut: Material, mat_brass: Material, mat_glass: Material, mat_sand: Material) -> void:
	var hg = Node3D.new()
	hg.name = "UnoMiniHourglass3D"
	hg.position = pos
	add_child(hg)

	_add_cyl(hg, 0.048, 0.052, 0.010, Vector3(0.0, 0.005, 0.0), mat_walnut, Vector3.ZERO, 6)
	_add_cyl(hg, 0.042, 0.044, 0.005, Vector3(0.0, 0.012, 0.0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(hg, 0.044, 0.042, 0.005, Vector3(0.0, 0.118, 0.0), mat_brass, Vector3.ZERO, 6)
	_add_cyl(hg, 0.052, 0.048, 0.010, Vector3(0.0, 0.125, 0.0), mat_walnut, Vector3.ZERO, 6)

	for i in range(4):
		var a = float(i) * PI * 0.5 + PI * 0.25
		var rx = cos(a) * 0.036
		var rz = sin(a) * 0.036
		_add_cyl(hg, 0.0035, 0.0035, 0.106, Vector3(rx, 0.065, rz), mat_brass, Vector3.ZERO, 8)

	_add_cyl(hg, 0.007, 0.030, 0.050, Vector3(0.0, 0.038, 0.0), mat_glass, Vector3.ZERO, 16)
	_add_cyl(hg, 0.030, 0.007, 0.050, Vector3(0.0, 0.092, 0.0), mat_glass, Vector3.ZERO, 16)
	_add_cyl(hg, 0.008, 0.026, 0.028, Vector3(0.0, 0.028, 0.0), mat_sand, Vector3.ZERO, 14)
	_add_cyl(hg, 0.022, 0.006, 0.022, Vector3(0.0, 0.094, 0.0), mat_sand, Vector3.ZERO, 14)

func _build_score_ledger_prop(pos: Vector3, mat_leather: Material, mat_paper: Material, mat_brass: Material) -> void:
	var book = Node3D.new()
	book.name = "UnoScoreLedger3D"
	book.position = pos
	book.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	add_child(book)

	_add_box(book, Vector3(0.110, 0.010, 0.140), Vector3(0.0, 0.005, 0.0), mat_leather)
	_add_box(book, Vector3(0.096, 0.008, 0.126), Vector3(0.004, 0.011, 0.0), mat_paper)
	for rz in [-0.042, -0.014, 0.014, 0.042]:
		_add_box(book, Vector3(0.076, 0.001, 0.003), Vector3(0.004, 0.0156, rz), mat_brass)
	# Gold Fountain Pen diagonally across the ledger
	_add_cyl(book, 0.0045, 0.0038, 0.115, Vector3(-0.012, 0.020, 0.008), mat_brass, Vector3(90.0, 26.0, 0.0), 10)

func set_uno_bell_alert(enabled: bool) -> void:
	_uno_bell_alert_active = enabled
	if is_instance_valid(_uno_bell_alert_ring):
		_uno_bell_alert_ring.visible = enabled

func animate_uno_bell_tap() -> void:
	if not is_instance_valid(_uno_bell_plunger):
		return
	var tw = create_tween()
	tw.tween_property(_uno_bell_plunger, "position:y", 0.036, 0.06)
	tw.tween_property(_uno_bell_plunger, "position:y", 0.044, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_table_state(top_card: Dictionary, active_color: String, dir: int, deck_rem: int, highlight_draw: bool) -> void:
	_current_direction = 1 if dir >= 0 else -1

	# 1. Active Color Crystal Beacon
	var act_col: Color = UNO_COLORS.get(active_color, UNO_COLORS["red"])
	if _color_gem_mat:
		_color_gem_mat.albedo_color = act_col
		_color_gem_mat.emission = act_col
	if _direction_bead_mat:
		_direction_bead_mat.albedo_color = act_col
		_direction_bead_mat.emission = act_col
	if _color_name_3d:
		_color_name_3d.text = "رنگ: " + UNO_COLOR_NAMES_FA.get(active_color, "قرمز")
		_color_name_3d.modulate = act_col.lightened(0.45)

	# 2. Direction Indicator
	if _direction_arrow_lbl:
		_direction_arrow_lbl.text = "↻ ساعتگرد" if _current_direction == 1 else "↺ پادساعتگرد"

	# 3. Draw Pile Thickness & Count
	if _draw_highlight_frame:
		_draw_highlight_frame.visible = highlight_draw
	if _draw_count_label:
		_draw_count_label.visible = (deck_rem > 0)
		_draw_count_label.text = "%s کارت" % UnoCardWidget.to_fa_digits(str(deck_rem))
	var ratio = clampf(float(deck_rem) / 80.0, 0.14, 1.0)
	var h = 0.044 * ratio
	if _draw_stack_body:
		_draw_stack_body.scale.y = ratio
		_draw_stack_body.position.y = 0.003 + h * 0.5
	if _draw_top_card:
		_draw_top_card.position.y = h + 0.005

	# 4. Discard Pile Top Card
	if not top_card.is_empty():
		var c_color = String(top_card.get("color", active_color))
		var c_val = String(top_card.get("value", "0"))
		var is_wild = (c_color == "wild" or c_val in ["wild", "wild_draw4"])
		var card_col: Color = UNO_COLORS["wild"] if is_wild else UNO_COLORS.get(c_color, act_col)

		if _discard_face_mat:
			_discard_face_mat.albedo_color = card_col
		if _discard_oval_mat:
			_discard_oval_mat.albedo_color = Color(0.15, 0.16, 0.20) if is_wild else Color(0.99, 0.99, 0.99)
		if _discard_wild_quads:
			_discard_wild_quads.visible = is_wild

		var sym_center = UnoCardWidget.format_center_symbol(c_val)
		var sym_corner = UnoCardWidget.format_corner_symbol(c_val)
		if _discard_center_lbl:
			_discard_center_lbl.text = "" if c_val == "wild" else sym_center
			_discard_center_lbl.modulate = Color.WHITE if is_wild else (card_col.darkened(0.08) if c_color != "yellow" else Color(0.75, 0.52, 0.02))
		if _discard_corner_tl:
			_discard_corner_tl.text = sym_corner
			_discard_corner_tl.modulate = Color.WHITE if c_color != "yellow" else Color(0.15, 0.12, 0.04)
		if _discard_corner_br:
			_discard_corner_br.text = sym_corner
			_discard_corner_br.modulate = Color.WHITE if c_color != "yellow" else Color(0.15, 0.12, 0.04)

func update_3d_opponent_fans(seat_counts: Dictionary, active_seat: int) -> void:
	var rack_wood = StandardMaterial3D.new()
	rack_wood.albedo_color = Color(0.20, 0.10, 0.05)
	rack_wood.roughness = 0.36

	var rack_trim = StandardMaterial3D.new()
	rack_trim.albedo_color = Color(0.84, 0.67, 0.28)
	rack_trim.metallic = 0.80
	rack_trim.roughness = 0.28

	for s_idx in _opponent_fans.keys():
		var holder: Node3D = _opponent_fans[s_idx]
		for ch in holder.get_children():
			ch.queue_free()
		if not seat_counts.has(s_idx):
			holder.visible = false
			continue
		holder.visible = true
		var count: int = int(seat_counts[s_idx])
		var vis_cards = clampi(count, 0, 8)
		var is_turn = (active_seat == s_idx)

		# 3D Brass-Trimmed Card Holder Stand for this Opponent
		_add_box(holder, Vector3(0.21, 0.008, 0.048), Vector3(0.0, 0.002, 0.0), rack_wood)
		var beacon_mat = StandardMaterial3D.new()
		if count == 1:
			beacon_mat.albedo_color = Color(0.95, 0.22, 0.24)
			beacon_mat.emission_enabled = true
			beacon_mat.emission = Color(0.95, 0.20, 0.22)
			beacon_mat.emission_energy_multiplier = 1.6
		elif is_turn:
			beacon_mat.albedo_color = Color(0.28, 0.94, 0.56)
			beacon_mat.emission_enabled = true
			beacon_mat.emission = Color(0.20, 0.88, 0.48)
			beacon_mat.emission_energy_multiplier = 1.3
		else:
			beacon_mat.albedo_color = rack_trim.albedo_color
			beacon_mat.metallic = 0.78
			beacon_mat.roughness = 0.28
		_add_box(holder, Vector3(0.218, 0.004, 0.054), Vector3(0.0, 0.0005, 0.0), beacon_mat)

		for i in range(vis_cards):
			var c_mi = MeshInstance3D.new()
			var c_box = BoxMesh.new()
			c_box.size = Vector3(0.056, 0.0025, 0.082)
			c_mi.mesh = c_box
			var norm = float(i) - float(vis_cards - 1) * 0.5
			c_mi.position = Vector3(norm * 0.021, 0.012 + float(i) * 0.0014, absf(norm) * 0.003)
			c_mi.rotation_degrees = Vector3(18.0, -norm * 5.0, 0.0)
			var c_mat = StandardMaterial3D.new()
			if count == 1:
				c_mat.albedo_color = Color(0.88, 0.16, 0.19)
			elif is_turn:
				c_mat.albedo_color = Color(0.15, 0.30, 0.22)
			else:
				c_mat.albedo_color = Color(0.11, 0.12, 0.16)
			c_mat.roughness = 0.30
			c_mi.material_override = c_mat
			holder.add_child(c_mi)

func animate_discard_pop() -> void:
	if not is_instance_valid(_discard_top_pivot):
		return
	_discard_top_pivot.scale = Vector3(0.76, 0.76, 0.76)
	_discard_top_pivot.rotation_degrees.y = randf_range(-9.0, 9.0)
	var tw = create_tween()
	tw.tween_property(_discard_top_pivot, "scale", Vector3(1.12, 1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_discard_top_pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)

func animate_reverse_spin() -> void:
	if is_instance_valid(_direction_pivot):
		var tw = create_tween()
		tw.tween_property(_direction_pivot, "scale", Vector3(1.26, 1.26, 1.26), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_direction_pivot, "scale", Vector3.ONE, 0.18)
	if is_instance_valid(_direction_orbit_ring):
		var tw2 = create_tween()
		tw2.tween_property(_direction_orbit_ring, "rotation:y", _direction_orbit_ring.rotation.y + (-PI * float(_current_direction)), 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func get_draw_pile_screen_pos() -> Vector2:
	var vp = get_viewport()
	if vp and vp.get_camera_3d() and is_instance_valid(draw_pile_root):
		return vp.get_camera_3d().unproject_position(draw_pile_root.global_position + Vector3(0, 0.04, 0))
	return Vector2(380, 820)

func get_discard_pile_screen_pos() -> Vector2:
	var vp = get_viewport()
	if vp and vp.get_camera_3d() and is_instance_valid(discard_pile_root):
		return vp.get_camera_3d().unproject_position(discard_pile_root.global_position + Vector3(0, 0.02, 0))
	return Vector2(640, 820)
