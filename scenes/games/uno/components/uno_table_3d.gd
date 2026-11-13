class_name UnoTable3D
extends Node3D

# UnoTable3D - Authentic 3D UNO Tabletop Scene on the Cafe Fekr Green Felt Table
# - Sits directly and harmoniously on the global Cafe Fekr green felt tabletop (y_base = 0.059)
# - Inlaid Brass & Mahogany Center Arena Ring with revolving 3D Direction Chevrons
# - Sculpted 3D Card Dealer Shoe & Draw Pile with floating 3D "بکشید!" prompt badge
# - Organic 3D Discard Pile with 5 fanned under-cards and full 3D top card graphics
# - Levitating 3D Active Color Crystal Plinth & Interactive 3D Brass UNO Bell
# - 3D Opponent Card Fans & 3D Floating Seat Nameplates positioned at each chair around the table

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
var _draw_prompt_badge: Label3D

var discard_pile_root: Node3D
var _discard_under_cards: Array[MeshInstance3D] = []
var _discard_under_mats: Array[StandardMaterial3D] = []
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

var _anim_time: float = 0.0

var _opponent_fans: Dictionary = {} # seat_idx (1=Top, 2=Left, 3=Right) -> Node3D

func _ready() -> void:
	_build_tabletop()

func _process(delta: float) -> void:
	_anim_time += delta

	# Rotate & gently levitate the Active Color Crystal Beacon
	if is_instance_valid(_color_crystal_node):
		_color_crystal_node.rotate_y(delta * 1.45)
		_color_crystal_node.position.y = 0.042 + sin(_anim_time * 2.6) * 0.005

	if is_instance_valid(_color_halo_ring):
		var sc: float = 1.0 + sin(_anim_time * 3.0) * 0.06
		_color_halo_ring.scale = Vector3(sc, 1.0, sc)

	# Orbit direction beads smoothly around the center arena
	if is_instance_valid(_direction_orbit_ring):
		_direction_orbit_ring.rotate_y(-delta * 0.90 * float(_current_direction))

	# Pulse UNO Bell alert ring when player has 1-2 cards
	if is_instance_valid(_uno_bell_alert_ring) and _uno_bell_alert_active:
		var pulse: float = 1.0 + sin(_anim_time * 6.5) * 0.12
		_uno_bell_alert_ring.scale = Vector3(pulse, 1.0, pulse)

	# Pulse Draw highlight frame & floating prompt when player needs to draw
	if is_instance_valid(_draw_highlight_frame) and _draw_highlight_frame.visible:
		var dp: float = 1.0 + sin(_anim_time * 5.2) * 0.04
		_draw_highlight_frame.scale = Vector3(dp, 1.0, dp)
	if is_instance_valid(_draw_prompt_badge) and _draw_prompt_badge.visible:
		_draw_prompt_badge.position.y = 0.095 + sin(_anim_time * 4.5) * 0.008

func _create_label_3d(txt: String, f_size: int = 39, col: Color = Color.WHITE, p_size: float = 0.0012) -> Label3D:
	var lbl: Label3D = Label3D.new()
	lbl.font = FontHekayat
	lbl.text = txt
	lbl.font_size = f_size
	lbl.pixel_size = p_size
	lbl.modulate = col
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.03, 0.04, 0.06, 0.94)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, segs: int = 20) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
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
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
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
	# Sits directly on the Cafe Fekr Green Felt surface (y = 0.059)
	var y_base: float = 0.059

	var mat_walnut: StandardMaterial3D = StandardMaterial3D.new()
	mat_walnut.albedo_color = Color(0.16, 0.085, 0.045)
	mat_walnut.roughness = 0.32
	mat_walnut.metallic = 0.06

	var mat_mahogany: StandardMaterial3D = StandardMaterial3D.new()
	mat_mahogany.albedo_color = Color(0.25, 0.11, 0.06)
	mat_mahogany.roughness = 0.28
	mat_mahogany.metallic = 0.08

	var mat_emerald_well: StandardMaterial3D = StandardMaterial3D.new()
	mat_emerald_well.albedo_color = Color(0.035, 0.17, 0.105)
	mat_emerald_well.roughness = 0.88

	var mat_bronze: StandardMaterial3D = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.85, 0.68, 0.28)
	mat_bronze.metallic = 0.84
	mat_bronze.roughness = 0.24

	var mat_aged_brass: StandardMaterial3D = StandardMaterial3D.new()
	mat_aged_brass.albedo_color = Color(0.58, 0.44, 0.18)
	mat_aged_brass.metallic = 0.78
	mat_aged_brass.roughness = 0.34

	var mat_shadow: StandardMaterial3D = StandardMaterial3D.new()
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.albedo_color = Color(0.0, 0.0, 0.0, 0.44)
	mat_shadow.roughness = 1.0

	var mat_paper: StandardMaterial3D = StandardMaterial3D.new()
	mat_paper.albedo_color = Color(0.95, 0.93, 0.89)
	mat_paper.roughness = 0.44

	var mat_white_card: StandardMaterial3D = StandardMaterial3D.new()
	mat_white_card.albedo_color = Color(0.99, 0.99, 0.99)
	mat_white_card.roughness = 0.20

	var mat_uno_back: StandardMaterial3D = StandardMaterial3D.new()
	mat_uno_back.albedo_color = Color(0.08, 0.09, 0.12)
	mat_uno_back.roughness = 0.24

	var mat_uno_red: StandardMaterial3D = StandardMaterial3D.new()
	mat_uno_red.albedo_color = UNO_COLORS["red"]
	mat_uno_red.roughness = 0.22

	# =========================================================================
	# 1. INLAID BRASS & MAHOGANY CENTER ARENA RING ON THE CAFE FEKR GREEN FELT
	# =========================================================================
	var ring_center: Vector3 = Vector3(-0.03, y_base + 0.002, -0.02)
	_add_cyl(self, 0.365, 0.375, 0.003, ring_center, mat_emerald_well, Vector3.ZERO, 36)
	_add_torus(self, 0.358, 0.372, ring_center + Vector3(0.0, 0.002, 0.0), mat_mahogany)
	_add_torus(self, 0.348, 0.356, ring_center + Vector3(0.0, 0.003, 0.0), mat_aged_brass)
	_add_torus(self, 0.258, 0.264, ring_center + Vector3(0.0, 0.003, 0.0), mat_aged_brass)

	# =========================================================================
	# 2. ANIMATED 3D DIRECTION ORBIT RING & FLOW INDICATOR
	# =========================================================================
	_direction_orbit_ring = Node3D.new()
	_direction_orbit_ring.position = ring_center + Vector3(0.0, 0.003, 0.0)
	add_child(_direction_orbit_ring)

	_direction_bead_mat = StandardMaterial3D.new()
	_direction_bead_mat.albedo_color = UNO_COLORS["red"]
	_direction_bead_mat.emission_enabled = true
	_direction_bead_mat.emission = UNO_COLORS["red"]
	_direction_bead_mat.emission_energy_multiplier = 1.15
	_direction_bead_mat.roughness = 0.18

	# 6 Orbiting Brass-Cased Gem Nodes on the Arena Ring
	for b_i: int in range(6):
		var ang: float = float(b_i) * TAU / 6.0
		var bx: float = cos(ang) * 0.305
		var bz: float = sin(ang) * 0.305
		_add_cyl(_direction_orbit_ring, 0.014, 0.016, 0.005, Vector3(bx, 0.002, bz), mat_bronze, Vector3.ZERO, 12)
		var gem_mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.010
		sm.height = 0.013
		gem_mi.mesh = sm
		gem_mi.position = Vector3(bx, 0.006, bz)
		gem_mi.material_override = _direction_bead_mat
		_direction_orbit_ring.add_child(gem_mi)

	_direction_pivot = Node3D.new()
	_direction_pivot.position = Vector3(-0.03, y_base + 0.004, 0.265)
	add_child(_direction_pivot)

	_add_box(_direction_pivot, Vector3(0.26, 0.005, 0.044), Vector3(0.0, 0.001, 0.0), mat_walnut)
	_add_box(_direction_pivot, Vector3(0.27, 0.003, 0.048), Vector3(0.0, 0.0, 0.0), mat_bronze)

	_direction_arrow_lbl = _create_label_3d("↻ ساعتگرد", 28, Color(0.98, 0.90, 0.62), 0.00105)
	_direction_arrow_lbl.position = Vector3(0.0, 0.005, 0.0)
	_direction_arrow_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_direction_pivot.add_child(_direction_arrow_lbl)

	# =========================================================================
	# 3. DRAW PILE (Left of Center) - Sculpted Dealer Shoe + Thick 3D UNO Deck
	# =========================================================================
	draw_pile_root = Node3D.new()
	draw_pile_root.position = Vector3(-0.185, y_base + 0.003, -0.02)
	draw_pile_root.rotation_degrees = Vector3(0.0, 6.0, 0.0)
	add_child(draw_pile_root)

	# Walnut & Brass Dealer Shoe Base
	_add_box(draw_pile_root, Vector3(0.206, 0.006, 0.288), Vector3(0.0, 0.002, 0.0), mat_walnut)
	_add_box(draw_pile_root, Vector3(0.194, 0.003, 0.276), Vector3(0.0, 0.005, 0.0), mat_emerald_well)
	# Dealer Shoe Side Walls
	_add_box(draw_pile_root, Vector3(0.010, 0.038, 0.240), Vector3(-0.096, 0.020, -0.010), mat_mahogany)
	_add_box(draw_pile_root, Vector3(0.010, 0.038, 0.240), Vector3(0.096, 0.020, -0.010), mat_mahogany)
	_add_box(draw_pile_root, Vector3(0.202, 0.042, 0.010), Vector3(0.0, 0.022, -0.132), mat_mahogany)
	for cx: float in [-0.096, 0.096]:
		for cz: float in [-0.136, 0.136]:
			_add_box(draw_pile_root, Vector3(0.024, 0.008, 0.024), Vector3(cx, 0.005, cz), mat_bronze)

	var draw_shadow: MeshInstance3D = _add_box(draw_pile_root, Vector3(0.188, 0.001, 0.270), Vector3(0.006, 0.0045, 0.006), mat_shadow)
	draw_shadow.name = "DrawShadow"

	# Interactive Golden Highlight Frame (Pulses when player should draw)
	_draw_highlight_frame = _add_box(draw_pile_root, Vector3(0.222, 0.005, 0.304), Vector3(0.0, 0.005, 0.0), mat_bronze)
	var dh_mat: StandardMaterial3D = StandardMaterial3D.new()
	dh_mat.albedo_color = Color(1.0, 0.88, 0.30)
	dh_mat.emission_enabled = true
	dh_mat.emission = Color(1.0, 0.78, 0.18)
	dh_mat.emission_energy_multiplier = 1.85
	_draw_highlight_frame.material_override = dh_mat
	_draw_highlight_frame.visible = false

	# 3D Paper Deck Block
	_draw_stack_body = _add_box(draw_pile_root, Vector3(0.172, 0.046, 0.252), Vector3(0.0, 0.026, 0.0), mat_paper)

	# Top Face-Down UNO Card on the Draw Pile
	_draw_top_card = Node3D.new()
	_draw_top_card.position = Vector3(0.0, 0.050, 0.0)
	draw_pile_root.add_child(_draw_top_card)

	_add_box(_draw_top_card, Vector3(0.174, 0.003, 0.254), Vector3.ZERO, mat_white_card)
	_add_box(_draw_top_card, Vector3(0.158, 0.0035, 0.238), Vector3(0.0, 0.0005, 0.0), mat_uno_back)

	var dt_oval: MeshInstance3D = MeshInstance3D.new()
	var dto_cyl: CylinderMesh = CylinderMesh.new()
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

	var uno_logo_3d: Label3D = _create_label_3d("UNO", 46, Color(1.0, 0.86, 0.18), 0.00115)
	uno_logo_3d.outline_size = 12
	uno_logo_3d.position = Vector3(0.0, 0.004, 0.0)
	uno_logo_3d.rotation_degrees = Vector3(-90.0, 0.0, -15.0)
	_draw_top_card.add_child(uno_logo_3d)

	_draw_count_label = _create_label_3d("۸۰ کارت", 26, Color(0.95, 0.96, 0.90), 0.00105)
	_draw_count_label.position = Vector3(0.0, 0.007, 0.168)
	_draw_count_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	draw_pile_root.add_child(_draw_count_label)

	_draw_prompt_badge = _create_label_3d("🃏 ضربه بزنید و بکشید", 30, Color(1.0, 0.94, 0.42), 0.00108)
	_draw_prompt_badge.position = Vector3(0.0, 0.095, 0.0)
	_draw_prompt_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_draw_prompt_badge.no_depth_test = true
	_draw_prompt_badge.visible = false
	draw_pile_root.add_child(_draw_prompt_badge)

	var draw_body: StaticBody3D = StaticBody3D.new()
	var draw_col: CollisionShape3D = CollisionShape3D.new()
	var draw_shape: BoxShape3D = BoxShape3D.new()
	draw_shape.size = Vector3(0.25, 0.11, 0.34)
	draw_col.shape = draw_shape
	draw_col.position = Vector3(0.0, 0.045, 0.0)
	draw_body.add_child(draw_col)
	draw_body.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _norm: Vector3, _idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			draw_pile_clicked.emit()
	)
	draw_pile_root.add_child(draw_body)

	# =========================================================================
	# 4. DISCARD PILE (Center-Right) - Organic Messy 3D Stack of Played Cards
	# =========================================================================
	discard_pile_root = Node3D.new()
	discard_pile_root.position = Vector3(0.095, y_base + 0.003, -0.02)
	add_child(discard_pile_root)

	_add_box(discard_pile_root, Vector3(0.218, 0.004, 0.304), Vector3.ZERO, mat_walnut)
	_add_box(discard_pile_root, Vector3(0.208, 0.002, 0.294), Vector3(0.0, 0.002, 0.0), mat_emerald_well)
	for cx: float in [-0.102, 0.102]:
		for cz: float in [-0.145, 0.145]:
			_add_box(discard_pile_root, Vector3(0.024, 0.006, 0.024), Vector3(cx, 0.004, cz), mat_bronze)

	_add_box(discard_pile_root, Vector3(0.202, 0.001, 0.288), Vector3(0.006, 0.0035, 0.006), mat_shadow)

	# 5 Organic Fanned Under-Cards with Colored Borders to look like a real played pile
	_discard_under_cards.clear()
	_discard_under_mats.clear()
	var under_angles: Array[float] = [-16.0, 11.0, -7.5, 14.0, -4.0]
	var under_offsets: Array[Vector3] = [
		Vector3(-0.010, 0.0045, 0.008),
		Vector3(0.008, 0.0075, -0.006),
		Vector3(-0.006, 0.0105, -0.009),
		Vector3(0.009, 0.0135, 0.007),
		Vector3(-0.004, 0.0165, 0.003),
	]
	var sample_cols: Array[Color] = [
		UNO_COLORS["blue"],
		UNO_COLORS["green"],
		UNO_COLORS["yellow"],
		UNO_COLORS["red"],
		UNO_COLORS["blue"],
	]
	for u_i: int in range(5):
		var u_mat: StandardMaterial3D = StandardMaterial3D.new()
		u_mat.albedo_color = sample_cols[u_i].darkened(0.12)
		u_mat.roughness = 0.28
		var under_c: MeshInstance3D = _add_box(
			discard_pile_root,
			Vector3(0.184, 0.003, 0.266),
			under_offsets[u_i],
			u_mat,
			Vector3(0.0, under_angles[u_i], 0.0)
		)
		under_c.name = "UnderCard_%d" % u_i
		_discard_under_cards.append(under_c)
		_discard_under_mats.append(u_mat)

	_discard_top_pivot = Node3D.new()
	_discard_top_pivot.position = Vector3(0.0, 0.020, 0.0)
	_discard_top_pivot.rotation_degrees = Vector3(0.0, 3.5, 0.0)
	discard_pile_root.add_child(_discard_top_pivot)

	_add_box(_discard_top_pivot, Vector3(0.194, 0.004, 0.280), Vector3.ZERO, mat_white_card)

	_discard_face_mesh = MeshInstance3D.new()
	var df_box: BoxMesh = BoxMesh.new()
	df_box.size = Vector3(0.176, 0.0045, 0.262)
	_discard_face_mesh.mesh = df_box
	_discard_face_mesh.position = Vector3(0.0, 0.0006, 0.0)
	_discard_face_mat = StandardMaterial3D.new()
	_discard_face_mat.albedo_color = UNO_COLORS["red"]
	_discard_face_mat.roughness = 0.24
	_discard_face_mesh.material_override = _discard_face_mat
	_discard_top_pivot.add_child(_discard_face_mesh)

	_discard_oval_mesh = MeshInstance3D.new()
	var do_cyl: CylinderMesh = CylinderMesh.new()
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
	var quad_offsets: Array[Dictionary] = [
		{"pos": Vector3(-0.024, 0, -0.028), "col": UNO_COLORS["red"]},
		{"pos": Vector3(0.024, 0, -0.028), "col": UNO_COLORS["blue"]},
		{"pos": Vector3(-0.024, 0, 0.028), "col": UNO_COLORS["yellow"]},
		{"pos": Vector3(0.024, 0, 0.028), "col": UNO_COLORS["green"]},
	]
	for qo: Dictionary in quad_offsets:
		var q_mat: StandardMaterial3D = StandardMaterial3D.new()
		q_mat.albedo_color = qo["col"]
		q_mat.roughness = 0.25
		_add_cyl(_discard_wild_quads, 0.024, 0.024, 0.001, qo["pos"], q_mat, Vector3.ZERO, 18)

	_discard_corner_tl = _create_label_3d("۷", 32, Color.WHITE, 0.0011)
	_discard_corner_tl.position = Vector3(-0.062, 0.0055, -0.098)
	_discard_corner_tl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_discard_top_pivot.add_child(_discard_corner_tl)

	_discard_center_lbl = _create_label_3d("۷", 72, UNO_COLORS["red"], 0.00125)
	_discard_center_lbl.outline_size = 6
	_discard_center_lbl.outline_modulate = Color(1.0, 1.0, 1.0, 0.92)
	_discard_center_lbl.position = Vector3(0.0, 0.006, 0.0)
	_discard_center_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_discard_top_pivot.add_child(_discard_center_lbl)

	_discard_corner_br = _create_label_3d("۷", 32, Color.WHITE, 0.0011)
	_discard_corner_br.position = Vector3(0.062, 0.0055, 0.098)
	_discard_corner_br.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	_discard_top_pivot.add_child(_discard_corner_br)

	# =========================================================================
	# 5. 3D ACTIVE COLOR CRYSTAL BEACON PEDESTAL (Right of Discard Pile)
	# =========================================================================
	color_indicator_root = Node3D.new()
	color_indicator_root.position = Vector3(0.315, y_base + 0.003, -0.06)
	add_child(color_indicator_root)

	_add_cyl(color_indicator_root, 0.064, 0.070, 0.010, Vector3(0.0, 0.005, 0.0), mat_walnut, Vector3.ZERO, 8)
	_add_cyl(color_indicator_root, 0.054, 0.058, 0.010, Vector3(0.0, 0.012, 0.0), mat_bronze, Vector3.ZERO, 8)

	_color_gem_mat = StandardMaterial3D.new()
	_color_gem_mat.albedo_color = UNO_COLORS["red"]
	_color_gem_mat.roughness = 0.14
	_color_gem_mat.metallic = 0.25
	_color_gem_mat.emission_enabled = true
	_color_gem_mat.emission = UNO_COLORS["red"]
	_color_gem_mat.emission_energy_multiplier = 1.25

	_color_halo_ring = _add_torus(color_indicator_root, 0.042, 0.050, Vector3(0.0, 0.018, 0.0), _color_gem_mat)

	_color_crystal_node = MeshInstance3D.new()
	var crys_mesh: SphereMesh = SphereMesh.new()
	crys_mesh.radius = 0.030
	crys_mesh.height = 0.062
	crys_mesh.radial_segments = 6
	crys_mesh.rings = 2
	_color_crystal_node.mesh = crys_mesh
	_color_crystal_node.position = Vector3(0.0, 0.042, 0.0)
	_color_crystal_node.material_override = _color_gem_mat
	color_indicator_root.add_child(_color_crystal_node)

	_color_name_3d = _create_label_3d("قرمز", 28, Color.WHITE, 0.00108)
	_color_name_3d.position = Vector3(0.0, 0.018, 0.088)
	_color_name_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	color_indicator_root.add_child(_color_name_3d)

	# =========================================================================
	# 6. 3D OPPONENT CARD FANS & FLOATING NAMEPLATES AROUND THE TABLE SEATS
	# =========================================================================
	var opp_slots: Dictionary = {
		1: {"pos": Vector3(0.0, y_base + 0.003, -0.365), "rot_y": 0.0},
		2: {"pos": Vector3(-0.465, y_base + 0.003, -0.145), "rot_y": -62.0},
		3: {"pos": Vector3(0.465, y_base + 0.003, -0.145), "rot_y": 62.0},
	}
	for s_idx: int in opp_slots.keys():
		var cfg: Dictionary = opp_slots[s_idx]
		var fan_holder: Node3D = Node3D.new()
		fan_holder.position = cfg["pos"]
		fan_holder.rotation_degrees = Vector3(0.0, float(cfg["rot_y"]), 0.0)
		fan_holder.visible = false
		add_child(fan_holder)
		_opponent_fans[s_idx] = fan_holder

	# =========================================================================
	# 7. INTERACTIVE 3D GOLDEN UNO BELL & CHIP BOWL ON THE FELT
	# =========================================================================
	_build_uno_bell_prop(Vector3(0.355, y_base + 0.003, 0.215), mat_walnut, mat_bronze, mat_uno_red)
	_build_uno_chips_bowl_prop(Vector3(-0.425, y_base + 0.003, 0.215), mat_mahogany, mat_bronze)

func _build_uno_bell_prop(pos: Vector3, mat_walnut: Material, mat_brass: Material, mat_red: Material) -> void:
	_uno_bell_root = Node3D.new()
	_uno_bell_root.name = "UnoShoutBell3D"
	_uno_bell_root.position = pos
	add_child(_uno_bell_root)

	_add_cyl(_uno_bell_root, 0.070, 0.076, 0.010, Vector3(0.0, 0.005, 0.0), mat_walnut, Vector3.ZERO, 20)
	_add_cyl(_uno_bell_root, 0.058, 0.064, 0.008, Vector3(0.0, 0.013, 0.0), mat_brass, Vector3.ZERO, 24)
	_add_cyl(_uno_bell_root, 0.046, 0.056, 0.026, Vector3(0.0, 0.028, 0.0), mat_brass, Vector3.ZERO, 24)

	_uno_bell_plunger = _add_cyl(_uno_bell_root, 0.024, 0.026, 0.015, Vector3(0.0, 0.046, 0.0), mat_red, Vector3.ZERO, 20)

	var alert_mat: StandardMaterial3D = StandardMaterial3D.new()
	alert_mat.albedo_color = Color(1.0, 0.86, 0.22)
	alert_mat.emission_enabled = true
	alert_mat.emission = Color(1.0, 0.72, 0.12)
	alert_mat.emission_energy_multiplier = 2.2
	_uno_bell_alert_ring = _add_torus(_uno_bell_root, 0.066, 0.076, Vector3(0.0, 0.011, 0.0), alert_mat)
	_uno_bell_alert_ring.visible = false

	var bell_lbl: Label3D = _create_label_3d("🔥 UNO!", 28, Color(1.0, 0.90, 0.35), 0.0010)
	bell_lbl.position = Vector3(0.0, 0.014, 0.092)
	bell_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_uno_bell_root.add_child(bell_lbl)

	var bell_body: StaticBody3D = StaticBody3D.new()
	var b_col: CollisionShape3D = CollisionShape3D.new()
	var b_shape: CylinderShape3D = CylinderShape3D.new()
	b_shape.radius = 0.090
	b_shape.height = 0.080
	b_col.shape = b_shape
	b_col.position = Vector3(0.0, 0.035, 0.0)
	bell_body.add_child(b_col)
	bell_body.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			animate_uno_bell_tap()
			uno_bell_clicked.emit()
	)
	_uno_bell_root.add_child(bell_body)

func _build_uno_chips_bowl_prop(pos: Vector3, mat_wood: Material, mat_brass: Material) -> void:
	var bowl: Node3D = Node3D.new()
	bowl.name = "UnoChipBowl3D"
	bowl.position = pos
	add_child(bowl)

	_add_cyl(bowl, 0.072, 0.054, 0.018, Vector3(0.0, 0.009, 0.0), mat_wood, Vector3.ZERO, 20)
	_add_torus(bowl, 0.064, 0.073, Vector3(0.0, 0.018, 0.0), mat_brass)

	var chip_specs: Array[Dictionary] = [
		{"pos": Vector3(-0.020, 0.020, -0.015), "count": 3, "col": UNO_COLORS["red"]},
		{"pos": Vector3(0.020, 0.020, -0.015), "count": 3, "col": UNO_COLORS["blue"]},
		{"pos": Vector3(-0.016, 0.020, 0.020), "count": 2, "col": UNO_COLORS["yellow"]},
		{"pos": Vector3(0.020, 0.020, 0.018), "count": 3, "col": UNO_COLORS["green"]},
	]
	for cs: Dictionary in chip_specs:
		var c_mat: StandardMaterial3D = StandardMaterial3D.new()
		c_mat.albedo_color = cs["col"]
		c_mat.roughness = 0.24
		var base_p: Vector3 = cs["pos"]
		for i: int in range(int(cs["count"])):
			var y_off: float = float(i) * 0.0055
			_add_cyl(bowl, 0.017, 0.017, 0.005, base_p + Vector3(0.0, y_off, 0.0), c_mat, Vector3.ZERO, 14)

func set_uno_bell_alert(enabled: bool) -> void:
	_uno_bell_alert_active = enabled
	if is_instance_valid(_uno_bell_alert_ring):
		_uno_bell_alert_ring.visible = enabled

func animate_uno_bell_tap() -> void:
	if not is_instance_valid(_uno_bell_plunger):
		return
	var tw: Tween = create_tween()
	tw.tween_property(_uno_bell_plunger, "position:y", 0.036, 0.06)
	tw.tween_property(_uno_bell_plunger, "position:y", 0.046, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		_color_name_3d.text = "رنگ: " + str(UNO_COLOR_NAMES_FA.get(active_color, "قرمز"))
		_color_name_3d.modulate = act_col.lightened(0.45)

	# 2. Direction Indicator
	if _direction_arrow_lbl:
		_direction_arrow_lbl.text = "↻ ساعتگرد" if _current_direction == 1 else "↺ پادساعتگرد"

	# 3. Draw Pile Thickness, Highlight & Floating Prompt
	if _draw_highlight_frame:
		_draw_highlight_frame.visible = highlight_draw
	if _draw_prompt_badge:
		_draw_prompt_badge.visible = highlight_draw
	if _draw_count_label:
		_draw_count_label.visible = (deck_rem > 0)
		_draw_count_label.text = "%s کارت" % UnoCardWidget.to_fa_digits(str(deck_rem))
	var ratio: float = clampf(float(deck_rem) / 80.0, 0.14, 1.0)
	var h: float = 0.046 * ratio
	if _draw_stack_body:
		_draw_stack_body.scale.y = ratio
		_draw_stack_body.position.y = 0.004 + h * 0.5
	if _draw_top_card:
		_draw_top_card.position.y = h + 0.006

	# 4. Discard Pile Top Card
	if not top_card.is_empty():
		var c_color: String = String(top_card.get("color", active_color))
		var c_val: String = String(top_card.get("value", "0"))
		var is_wild: bool = (c_color == "wild" or c_val in ["wild", "wild_draw4"])
		var card_col: Color = UNO_COLORS["wild"] if is_wild else UNO_COLORS.get(c_color, act_col)

		if _discard_face_mat:
			_discard_face_mat.albedo_color = card_col
		if _discard_oval_mat:
			_discard_oval_mat.albedo_color = Color(0.15, 0.16, 0.20) if is_wild else Color(0.99, 0.99, 0.99)
		if _discard_wild_quads:
			_discard_wild_quads.visible = is_wild

		var sym_center: String = UnoCardWidget.format_center_symbol(c_val)
		var sym_corner: String = UnoCardWidget.format_corner_symbol(c_val)
		if _discard_center_lbl:
			_discard_center_lbl.text = "" if c_val == "wild" else sym_center
			_discard_center_lbl.modulate = Color.WHITE if is_wild else (card_col.darkened(0.08) if c_color != "yellow" else Color(0.75, 0.52, 0.02))
		if _discard_corner_tl:
			_discard_corner_tl.text = sym_corner
			_discard_corner_tl.modulate = Color.WHITE if c_color != "yellow" else Color(0.15, 0.12, 0.04)
		if _discard_corner_br:
			_discard_corner_br.text = sym_corner
			_discard_corner_br.modulate = Color.WHITE if c_color != "yellow" else Color(0.15, 0.12, 0.04)

func update_3d_opponent_fans(seat_counts: Dictionary, active_seat: int, seat_names: Dictionary = {}, seat_uno: Dictionary = {}) -> void:
	var rack_wood: StandardMaterial3D = StandardMaterial3D.new()
	rack_wood.albedo_color = Color(0.20, 0.10, 0.05)
	rack_wood.roughness = 0.34

	var rack_trim: StandardMaterial3D = StandardMaterial3D.new()
	rack_trim.albedo_color = Color(0.84, 0.67, 0.28)
	rack_trim.metallic = 0.80
	rack_trim.roughness = 0.26

	var mat_card_white: StandardMaterial3D = StandardMaterial3D.new()
	mat_card_white.albedo_color = Color(0.96, 0.95, 0.92)
	mat_card_white.roughness = 0.25

	var mat_card_red_oval: StandardMaterial3D = StandardMaterial3D.new()
	mat_card_red_oval.albedo_color = UNO_COLORS["red"]
	mat_card_red_oval.roughness = 0.25

	for s_idx: int in _opponent_fans.keys():
		var holder: Node3D = _opponent_fans[s_idx]
		for ch: Node in holder.get_children():
			ch.queue_free()
		if not seat_counts.has(s_idx):
			holder.visible = false
			continue
		holder.visible = true
		var count: int = int(seat_counts[s_idx])
		var vis_cards: int = clampi(count, 0, 9)
		var is_turn: bool = (active_seat == s_idx)
		var has_uno: bool = bool(seat_uno.get(s_idx, count == 1))
		var p_name: String = str(seat_names.get(s_idx, "حریف"))

		# 1. 3D Brass-Trimmed Mahogany Card Stand
		_add_box(holder, Vector3(0.24, 0.010, 0.056), Vector3(0.0, 0.005, 0.0), rack_wood)
		var beacon_mat: StandardMaterial3D = StandardMaterial3D.new()
		if has_uno or count == 1:
			beacon_mat.albedo_color = Color(0.96, 0.20, 0.22)
			beacon_mat.emission_enabled = true
			beacon_mat.emission = Color(0.96, 0.20, 0.22)
			beacon_mat.emission_energy_multiplier = 1.8
		elif is_turn:
			beacon_mat.albedo_color = Color(0.28, 0.96, 0.56)
			beacon_mat.emission_enabled = true
			beacon_mat.emission = Color(0.20, 0.90, 0.48)
			beacon_mat.emission_energy_multiplier = 1.6
		else:
			beacon_mat.albedo_color = rack_trim.albedo_color
			beacon_mat.metallic = 0.78
			beacon_mat.roughness = 0.28
		_add_box(holder, Vector3(0.252, 0.004, 0.064), Vector3(0.0, 0.001, 0.0), beacon_mat)

		# 2. Upright Arched Fan of 3D UNO Cards Facing the Center of the Table
		for i: int in range(vis_cards):
			var norm: float = float(i) - float(vis_cards - 1) * 0.5
			var card_pivot: Node3D = Node3D.new()
			card_pivot.position = Vector3(norm * 0.024, 0.044 - absf(norm) * 0.0025, norm * 0.0015)
			card_pivot.rotation_degrees = Vector3(-16.0, 0.0, -norm * 6.5)
			holder.add_child(card_pivot)

			# White border + Dark UNO card back + Red center badge
			_add_box(card_pivot, Vector3(0.064, 0.092, 0.0025), Vector3.ZERO, mat_card_white)
			var c_mat: StandardMaterial3D = StandardMaterial3D.new()
			if has_uno or count == 1:
				c_mat.albedo_color = Color(0.75, 0.12, 0.15)
			elif is_turn:
				c_mat.albedo_color = Color(0.12, 0.24, 0.18)
			else:
				c_mat.albedo_color = Color(0.09, 0.10, 0.14)
			c_mat.roughness = 0.28
			_add_box(card_pivot, Vector3(0.058, 0.084, 0.003), Vector3(0.0, 0.0, 0.0004), c_mat)
			_add_box(card_pivot, Vector3(0.030, 0.042, 0.0034), Vector3(0.0, 0.0, 0.0006), mat_card_red_oval, Vector3(0.0, 0.0, -18.0))

		# 3. Floating 3D Seat Badge (Player Name + Card Count + UNO / Turn Halo)
		var badge_str: String = "%s • %s🃏" % [p_name, UnoCardWidget.to_fa_digits(str(count))]
		if has_uno or count == 1:
			badge_str = "🔥 UNO! • " + badge_str
		elif is_turn:
			badge_str = "🟢 " + badge_str
		var badge_col: Color = Color(1.0, 0.48, 0.48) if (has_uno or count == 1) else (Color(0.46, 0.98, 0.66) if is_turn else Color(0.95, 0.90, 0.78))
		var seat_lbl: Label3D = _create_label_3d(badge_str, 30, badge_col, 0.00112)
		seat_lbl.position = Vector3(0.0, 0.112, 0.0)
		seat_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		seat_lbl.no_depth_test = true
		holder.add_child(seat_lbl)

func get_opponent_seat_screen_pos(seat_idx: int) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp and vp.get_camera_3d() and _opponent_fans.has(seat_idx):
		var h: Node3D = _opponent_fans[seat_idx]
		if is_instance_valid(h):
			return vp.get_camera_3d().unproject_position(h.global_position + Vector3(0.0, 0.05, 0.0))
	return Vector2(540, 420)

func animate_discard_pop() -> void:
	if not is_instance_valid(_discard_top_pivot):
		return
	# Cycle under-card angles slightly for organic physical stack feel
	for u_i: int in range(_discard_under_cards.size()):
		var uc: MeshInstance3D = _discard_under_cards[u_i]
		if is_instance_valid(uc):
			uc.rotation_degrees.y += randf_range(-4.0, 4.0)
	_discard_top_pivot.scale = Vector3(0.76, 0.76, 0.76)
	_discard_top_pivot.rotation_degrees.y = randf_range(-11.0, 11.0)
	var tw: Tween = create_tween()
	tw.tween_property(_discard_top_pivot, "scale", Vector3(1.14, 1.14, 1.14), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_discard_top_pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)

func animate_reverse_spin() -> void:
	if is_instance_valid(_direction_pivot):
		var tw: Tween = create_tween()
		tw.tween_property(_direction_pivot, "scale", Vector3(1.26, 1.26, 1.26), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_direction_pivot, "scale", Vector3.ONE, 0.18)
	if is_instance_valid(_direction_orbit_ring):
		var tw2: Tween = create_tween()
		tw2.tween_property(_direction_orbit_ring, "rotation:y", _direction_orbit_ring.rotation.y + (-PI * float(_current_direction)), 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func get_draw_pile_screen_pos() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp and vp.get_camera_3d() and is_instance_valid(draw_pile_root):
		return vp.get_camera_3d().unproject_position(draw_pile_root.global_position + Vector3(0, 0.04, 0))
	return Vector2(380, 820)

func get_discard_pile_screen_pos() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp and vp.get_camera_3d() and is_instance_valid(discard_pile_root):
		return vp.get_camera_3d().unproject_position(discard_pile_root.global_position + Vector3(0, 0.02, 0))
	return Vector2(640, 820)
