class_name UnoTable3D
extends Node3D

# UnoTable3D - Premium Walnut & Dark Emerald 3D Tabletop Centerpiece
# Follows the UNO Mobile Redesign Specification:
# - Rich dark walnut wood frame with warm bronze trim & dark emerald green baize
# - Compact, intentional proportions (no oversized glowing rings or wasted space)
# - Recognizable 3D Draw Pile (left) with realistic thickness, contact shadow & tap interaction
# - Visual centerpiece 3D Discard Pile (right) with authentic UNO card proportions & colors
# - Compact Current Color Indicator right beside the Discard Pile
# - Neat 3D opponent card-back fans along the upper edges of the table

signal draw_pile_clicked()

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
var _color_gem_mat: StandardMaterial3D
var _color_name_3d: Label3D

var _direction_pivot: Node3D
var _direction_arrow_lbl: Label3D

var _opponent_fans: Dictionary = {} # seat_idx (1=Top, 2=Left, 3=Right) -> Node3D

func _ready() -> void:
	_build_tabletop()

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

func _build_tabletop() -> void:
	var y_base: float = 0.064

	# Materials
	var mat_walnut = StandardMaterial3D.new()
	mat_walnut.albedo_color = Color(0.17, 0.09, 0.05)
	mat_walnut.roughness = 0.36
	mat_walnut.metallic = 0.08

	var mat_emerald = StandardMaterial3D.new()
	mat_emerald.albedo_color = Color(0.05, 0.23, 0.15)
	mat_emerald.roughness = 0.86
	mat_emerald.metallic = 0.0

	var mat_emerald_well = StandardMaterial3D.new()
	mat_emerald_well.albedo_color = Color(0.04, 0.17, 0.11)
	mat_emerald_well.roughness = 0.90

	var mat_bronze = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.80, 0.63, 0.28)
	mat_bronze.metallic = 0.78
	mat_bronze.roughness = 0.28

	var mat_shadow = StandardMaterial3D.new()
	mat_shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shadow.albedo_color = Color(0.0, 0.0, 0.0, 0.42)
	mat_shadow.roughness = 1.0

	var mat_paper = StandardMaterial3D.new()
	mat_paper.albedo_color = Color(0.95, 0.93, 0.89)
	mat_paper.roughness = 0.48

	var mat_white_card = StandardMaterial3D.new()
	mat_white_card.albedo_color = Color(0.99, 0.99, 0.99)
	mat_white_card.roughness = 0.22

	var mat_uno_back = StandardMaterial3D.new()
	mat_uno_back.albedo_color = Color(0.09, 0.10, 0.13)
	mat_uno_back.roughness = 0.26

	var mat_uno_red = StandardMaterial3D.new()
	mat_uno_red.albedo_color = UNO_COLORS["red"]
	mat_uno_red.roughness = 0.24

	# 1. Compact Dark Walnut & Emerald Playing Surface (0.90m x 0.74m)
	var walnut_base = MeshInstance3D.new()
	var wb_box = BoxMesh.new()
	wb_box.size = Vector3(0.92, 0.014, 0.76)
	walnut_base.mesh = wb_box
	walnut_base.position = Vector3(0.0, y_base + 0.007, -0.02)
	walnut_base.material_override = mat_walnut
	walnut_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walnut_base)

	var emerald_baize = MeshInstance3D.new()
	var eb_box = BoxMesh.new()
	eb_box.size = Vector3(0.85, 0.004, 0.69)
	emerald_baize.mesh = eb_box
	emerald_baize.position = Vector3(0.0, y_base + 0.015, -0.02)
	emerald_baize.material_override = mat_emerald
	emerald_baize.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emerald_baize)

	# Subtle Bronze Inlay Trim Frame
	var trim_configs = [
		{"size": Vector3(0.856, 0.002, 0.006), "pos": Vector3(0.0, y_base + 0.0175, -0.365)},
		{"size": Vector3(0.856, 0.002, 0.006), "pos": Vector3(0.0, y_base + 0.0175, 0.325)},
		{"size": Vector3(0.006, 0.002, 0.690), "pos": Vector3(-0.425, y_base + 0.0175, -0.02)},
		{"size": Vector3(0.006, 0.002, 0.690), "pos": Vector3(0.425, y_base + 0.0175, -0.02)},
	]
	for tc in trim_configs:
		var t_mi = MeshInstance3D.new()
		var t_bm = BoxMesh.new()
		t_bm.size = tc["size"]
		t_mi.mesh = t_bm
		t_mi.position = tc["pos"]
		t_mi.material_override = mat_bronze
		t_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(t_mi)

	# 2. Central Direction Flow Indicator (Clean & Restrained between the two piles)
	_direction_pivot = Node3D.new()
	_direction_pivot.position = Vector3(-0.01, y_base + 0.018, 0.195)
	add_child(_direction_pivot)

	_direction_arrow_lbl = _create_label_3d("↻ جهت چرخش: ساعتگرد", 27, Color(0.90, 0.84, 0.64), 0.0011)
	_direction_arrow_lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_direction_pivot.add_child(_direction_arrow_lbl)

	# =========================================================================
	# 3. DRAW PILE (Left of Center) - Face-Down UNO Deck with Realistic 3D Thickness
	# =========================================================================
	draw_pile_root = Node3D.new()
	draw_pile_root.position = Vector3(-0.165, y_base + 0.018, 0.005)
	add_child(draw_pile_root)

	# Subtle Recessed Card Well & Contact Shadow
	var draw_shadow = MeshInstance3D.new()
	var ds_box = BoxMesh.new()
	ds_box.size = Vector3(0.192, 0.001, 0.274)
	draw_shadow.mesh = ds_box
	draw_shadow.position = Vector3(0.006, 0.0005, 0.008)
	draw_shadow.material_override = mat_shadow
	draw_pile_root.add_child(draw_shadow)

	# Interactive Golden Highlight Frame (Only visible when player should draw)
	_draw_highlight_frame = MeshInstance3D.new()
	var dh_box = BoxMesh.new()
	dh_box.size = Vector3(0.196, 0.002, 0.278)
	_draw_highlight_frame.mesh = dh_box
	_draw_highlight_frame.position = Vector3(0.0, 0.001, 0.0)
	var dh_mat = StandardMaterial3D.new()
	dh_mat.albedo_color = Color(1.0, 0.86, 0.28)
	dh_mat.emission_enabled = true
	dh_mat.emission = Color(1.0, 0.78, 0.20)
	dh_mat.emission_energy_multiplier = 1.2
	_draw_highlight_frame.material_override = dh_mat
	_draw_highlight_frame.visible = false
	draw_pile_root.add_child(_draw_highlight_frame)

	# 3D Paper Deck Block (Scales vertically with remaining cards)
	_draw_stack_body = MeshInstance3D.new()
	var dsb_mesh = BoxMesh.new()
	dsb_mesh.size = Vector3(0.172, 0.042, 0.252)
	_draw_stack_body.mesh = dsb_mesh
	_draw_stack_body.position = Vector3(0.0, 0.021, 0.0)
	_draw_stack_body.material_override = mat_paper
	draw_pile_root.add_child(_draw_stack_body)

	# Top Face-Down UNO Card on the Draw Pile
	_draw_top_card = Node3D.new()
	_draw_top_card.position = Vector3(0.0, 0.043, 0.0)
	draw_pile_root.add_child(_draw_top_card)

	var dt_border = MeshInstance3D.new()
	var dtb_mesh = BoxMesh.new()
	dtb_mesh.size = Vector3(0.174, 0.003, 0.254)
	dt_border.mesh = dtb_mesh
	dt_border.material_override = mat_white_card
	_draw_top_card.add_child(dt_border)

	var dt_black = MeshInstance3D.new()
	var dtbl_mesh = BoxMesh.new()
	dtbl_mesh.size = Vector3(0.158, 0.0035, 0.238)
	dt_black.mesh = dtbl_mesh
	dt_black.position = Vector3(0.0, 0.0005, 0.0)
	dt_black.material_override = mat_uno_back
	_draw_top_card.add_child(dt_black)

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

	_draw_count_label = _create_label_3d("۸۰ کارت", 25, Color(0.92, 0.95, 0.90), 0.00105)
	_draw_count_label.position = Vector3(0.0, 0.004, 0.155)
	_draw_count_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	draw_pile_root.add_child(_draw_count_label)

	# Clickable StaticBody3D for tapping the 3D Draw Pile directly
	var draw_body = StaticBody3D.new()
	var draw_col = CollisionShape3D.new()
	var draw_shape = BoxShape3D.new()
	draw_shape.size = Vector3(0.21, 0.08, 0.29)
	draw_col.shape = draw_shape
	draw_col.position = Vector3(0.0, 0.03, 0.0)
	draw_body.add_child(draw_col)
	draw_body.input_event.connect(func(_cam, event, _pos, _norm, _idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			draw_pile_clicked.emit()
	)
	draw_pile_root.add_child(draw_body)

	# =========================================================================
	# 4. DISCARD PILE (Right of Center) - Visual Centerpiece Active Card
	# =========================================================================
	discard_pile_root = Node3D.new()
	discard_pile_root.position = Vector3(0.095, y_base + 0.018, 0.005)
	add_child(discard_pile_root)

	# Recessed Well & Contact Shadow under Discard Pile
	var disc_well = MeshInstance3D.new()
	var dw_box = BoxMesh.new()
	dw_box.size = Vector3(0.210, 0.001, 0.296)
	disc_well.mesh = dw_box
	disc_well.material_override = mat_emerald_well
	discard_pile_root.add_child(disc_well)

	var disc_shadow = MeshInstance3D.new()
	var dsh_box = BoxMesh.new()
	dsh_box.size = Vector3(0.204, 0.001, 0.290)
	disc_shadow.mesh = dsh_box
	disc_shadow.position = Vector3(0.006, 0.0015, 0.008)
	disc_shadow.material_override = mat_shadow
	discard_pile_root.add_child(disc_shadow)

	# 2 Subtle Previously-Played Cards underneath at natural angles
	for u_i in range(2):
		var under_c = MeshInstance3D.new()
		var uc_box = BoxMesh.new()
		uc_box.size = Vector3(0.184, 0.003, 0.266)
		under_c.mesh = uc_box
		under_c.position = Vector3(0.0, 0.003 + float(u_i) * 0.0035, 0.0)
		under_c.rotation_degrees = Vector3(0.0, -9.0 + float(u_i) * 15.0, 0.0)
		under_c.material_override = mat_paper
		discard_pile_root.add_child(under_c)

	# Top Active Discard Card Pivot
	_discard_top_pivot = Node3D.new()
	_discard_top_pivot.position = Vector3(0.0, 0.011, 0.0)
	_discard_top_pivot.rotation_degrees = Vector3(0.0, 3.5, 0.0)
	discard_pile_root.add_child(_discard_top_pivot)

	var top_white_border = MeshInstance3D.new()
	var twb_box = BoxMesh.new()
	twb_box.size = Vector3(0.192, 0.004, 0.278)
	top_white_border.mesh = twb_box
	top_white_border.material_override = mat_white_card
	_discard_top_pivot.add_child(top_white_border)

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

	# Center White Oval on Discard Card
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

	# 4-Color Quadrant Discs for Wild Cards on 3D Discard Card
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
		var q_mi = MeshInstance3D.new()
		var q_cyl = CylinderMesh.new()
		q_cyl.top_radius = 0.024
		q_cyl.bottom_radius = 0.024
		q_cyl.height = 0.001
		q_mi.mesh = q_cyl
		q_mi.position = qo["pos"]
		var q_mat = StandardMaterial3D.new()
		q_mat.albedo_color = qo["col"]
		q_mat.roughness = 0.25
		q_mi.material_override = q_mat
		_discard_wild_quads.add_child(q_mi)

	# Top-Left, Center, and Bottom-Right 3D Symbols on Discard Card
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
	# 5. COMPACT CURRENT COLOR INDICATOR (Right Beside Discard Pile)
	# =========================================================================
	color_indicator_root = Node3D.new()
	color_indicator_root.position = Vector3(0.285, y_base + 0.018, 0.005)
	add_child(color_indicator_root)

	var ci_bezel = MeshInstance3D.new()
	var cib_cyl = CylinderMesh.new()
	cib_cyl.top_radius = 0.058
	cib_cyl.bottom_radius = 0.064
	cib_cyl.height = 0.010
	cib_cyl.radial_segments = 28
	ci_bezel.mesh = cib_cyl
	ci_bezel.position = Vector3(0.0, 0.005, 0.0)
	ci_bezel.material_override = mat_bronze
	color_indicator_root.add_child(ci_bezel)

	var ci_gem = MeshInstance3D.new()
	var cig_cyl = CylinderMesh.new()
	cig_cyl.top_radius = 0.048
	cig_cyl.bottom_radius = 0.048
	cig_cyl.height = 0.012
	cig_cyl.radial_segments = 28
	ci_gem.mesh = cig_cyl
	ci_gem.position = Vector3(0.0, 0.007, 0.0)
	_color_gem_mat = StandardMaterial3D.new()
	_color_gem_mat.albedo_color = UNO_COLORS["red"]
	_color_gem_mat.roughness = 0.18
	_color_gem_mat.emission_enabled = true
	_color_gem_mat.emission = UNO_COLORS["red"]
	_color_gem_mat.emission_energy_multiplier = 0.45
	ci_gem.material_override = _color_gem_mat
	color_indicator_root.add_child(ci_gem)

	_color_name_3d = _create_label_3d("قرمز", 27, Color.WHITE, 0.00105)
	_color_name_3d.position = Vector3(0.0, 0.016, 0.082)
	_color_name_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	color_indicator_root.add_child(_color_name_3d)

	# =========================================================================
	# 6. 3D OPPONENT CARD-BACK STACKS AROUND UPPER TABLE EDGES
	# =========================================================================
	var opp_slots = {
		1: {"pos": Vector3(0.0, y_base + 0.018, -0.285), "rot_y": 0.0},
		2: {"pos": Vector3(-0.345, y_base + 0.018, -0.145), "rot_y": -65.0},
		3: {"pos": Vector3(0.345, y_base + 0.018, -0.145), "rot_y": 65.0},
	}
	for s_idx in opp_slots.keys():
		var cfg = opp_slots[s_idx]
		var fan_holder = Node3D.new()
		fan_holder.position = cfg["pos"]
		fan_holder.rotation_degrees = Vector3(0.0, float(cfg["rot_y"]), 0.0)
		fan_holder.visible = false
		add_child(fan_holder)
		_opponent_fans[s_idx] = fan_holder

func update_table_state(top_card: Dictionary, active_color: String, dir: int, deck_rem: int, highlight_draw: bool) -> void:
	# 1. Active Color Indicator
	var act_col: Color = UNO_COLORS.get(active_color, UNO_COLORS["red"])
	if _color_gem_mat:
		_color_gem_mat.albedo_color = act_col
		_color_gem_mat.emission = act_col
	if _color_name_3d:
		_color_name_3d.text = "رنگ: " + UNO_COLOR_NAMES_FA.get(active_color, "قرمز")
		_color_name_3d.modulate = act_col.lightened(0.42)

	# 2. Direction Indicator
	if _direction_arrow_lbl:
		_direction_arrow_lbl.text = "↻ جهت چرخش: ساعتگرد" if dir == 1 else "↺ جهت چرخش: پادساعتگرد"

	# 3. Draw Pile Thickness & Count
	if _draw_highlight_frame:
		_draw_highlight_frame.visible = highlight_draw
	if _draw_count_label:
		_draw_count_label.visible = (deck_rem > 0)
		_draw_count_label.text = "%s کارت" % UnoCardWidget.to_fa_digits(str(deck_rem))
	var ratio = clampf(float(deck_rem) / 80.0, 0.12, 1.0)
	var h = 0.044 * ratio
	if _draw_stack_body:
		_draw_stack_body.scale.y = ratio
		_draw_stack_body.position.y = h * 0.5
	if _draw_top_card:
		_draw_top_card.position.y = h + 0.002

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
		for i in range(vis_cards):
			var c_mi = MeshInstance3D.new()
			var c_box = BoxMesh.new()
			c_box.size = Vector3(0.056, 0.0025, 0.082)
			c_mi.mesh = c_box
			var norm = float(i) - float(vis_cards - 1) * 0.5
			c_mi.position = Vector3(norm * 0.020, 0.002 + float(i) * 0.0015, absf(norm) * 0.003)
			c_mi.rotation_degrees = Vector3(14.0, -norm * 5.0, 0.0)
			var c_mat = StandardMaterial3D.new()
			if count == 1:
				c_mat.albedo_color = Color(0.88, 0.16, 0.19)
			elif is_turn:
				c_mat.albedo_color = Color(0.16, 0.28, 0.22)
			else:
				c_mat.albedo_color = Color(0.11, 0.12, 0.16)
			c_mat.roughness = 0.30
			c_mi.material_override = c_mat
			holder.add_child(c_mi)

func animate_discard_pop() -> void:
	if not is_instance_valid(_discard_top_pivot):
		return
	_discard_top_pivot.scale = Vector3(0.78, 0.78, 0.78)
	_discard_top_pivot.rotation_degrees.y = randf_range(-8.0, 8.0)
	var tw = create_tween()
	tw.tween_property(_discard_top_pivot, "scale", Vector3(1.10, 1.10, 1.10), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_discard_top_pivot, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)

func animate_reverse_spin() -> void:
	if not is_instance_valid(_direction_pivot):
		return
	var tw = create_tween()
	tw.tween_property(_direction_pivot, "scale", Vector3(1.25, 1.25, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_direction_pivot, "scale", Vector3.ONE, 0.18)

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
