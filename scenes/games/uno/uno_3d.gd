class_name Uno3D
extends "res://scripts/games/base_game_board.gd"

# Uno3D - Luxury Cafe Fekr 2-4 Player UNO Game Scene
# Built to true Cafe Table physical scale (1.10m diameter arena on the 1.20m table mat)
# with HUD overlay protection so top/bottom panels never appear over StartGameOverlay or GameResultDialog.

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

@export var default_three_quarter_view: bool = true
@export var camera_pitch: float = -1.06    # ~ -61 deg elevated tabletop perspective
@export var camera_distance: float = 2.75  # Ideal portrait framing for 1.10m UNO arena

const UNO_COLORS: Dictionary = {
	"red": Color(0.92, 0.20, 0.22),
	"blue": Color(0.16, 0.52, 0.96),
	"green": Color(0.16, 0.76, 0.38),
	"yellow": Color(0.95, 0.76, 0.10),
	"wild": Color(0.22, 0.20, 0.30)
}

const UNO_COLOR_NAMES_FA: Dictionary = {
	"red": "قرمز",
	"blue": "آبی",
	"green": "سبز",
	"yellow": "زرد",
	"wild": "آزاد"
}

const UNO_COLOR_EMOJIS: Dictionary = {
	"red": "🔴",
	"blue": "🔵",
	"green": "🟢",
	"yellow": "🟡",
	"wild": "🎨"
}

# --- Game State ---
var my_hand: Array = []
var hands_count: Dictionary = {"1": 7, "2": 7, "3": 7, "4": 7}
var top_card: Dictionary = {}
var current_color: String = "red"
var direction: int = 1
var deck_remaining: int = 80
var has_drawn_this_turn: bool = false
var uno_called: Dictionary = {}
var rank1_player: int = 0
var rank2_player: int = 0
var players_count: int = 2
var pending_wild_card: Dictionary = {}
var _match_started: bool = false
var _zoom_preset_idx: int = 0

# --- 3D Nodes ---
var board_root: Node3D
var color_ring_mesh: MeshInstance3D
var color_ring_mat: StandardMaterial3D
var direction_label_3d: Label3D
var discard_pile_node: Node3D
var top_card_mesh: MeshInstance3D
var top_card_mat: StandardMaterial3D
var top_card_oval_mat: StandardMaterial3D
var top_card_value_3d: Label3D
var top_card_corner_tl_3d: Label3D
var top_card_sub_3d: Label3D
var deck_stack_node: Node3D
var deck_glow_mesh: MeshInstance3D
var deck_glow_mat: StandardMaterial3D
var deck_count_3d: Label3D
var opponent_stacks_3d: Dictionary = {} # seat_idx -> Node3D

# --- 2D HUD Layer ---
var hud_layer: CanvasLayer
var hud_root: Control
var status_banner_panel: PanelContainer
var color_badge_panel: PanelContainer
var color_badge_style: StyleBoxFlat
var color_badge_label: Label
var direction_badge_label: Label
var deck_badge_label: Label
var zoom_cycle_btn: Button
var turn_hint_label: Label
var action_toast_label: Label

# Action Buttons
var draw_btn: Button
var pass_btn: Button
var uno_btn: Button

# Hand Dock
var hand_scroll: ScrollContainer
var hand_hbox: HBoxContainer
var hand_count_badge: Label

# Wild Color Picker Modal
var wild_modal_backdrop: ColorRect
var wild_modal_card_label: Label

func _ready() -> void:
	game_type = GameTypes.UNO
	_build_3d_arena()
	_build_2d_hud()
	super._ready()
	_connect_uno_signals()
	_refresh_all_visuals()
	_update_hud_visibility()

func _process(_delta: float) -> void:
	_update_hud_visibility()

func _exit_tree() -> void:
	_disconnect_uno_signals()
	if hud_root and is_instance_valid(hud_root):
		hud_root.queue_free()
	if hud_layer and is_instance_valid(hud_layer):
		hud_layer.queue_free()
	super._exit_tree()

func _connect_uno_signals() -> void:
	if not NetworkManager.user_data_received.is_connected(_on_user_data_received):
		NetworkManager.user_data_received.connect(_on_user_data_received)
	if not NetworkManager.risk_event_received.is_connected(_on_uno_event_received):
		NetworkManager.risk_event_received.connect(_on_uno_event_received)
	if not NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.connect(_on_win_happened)
	if not NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.connect(_on_internal_reconnect_data)

func _disconnect_uno_signals() -> void:
	if NetworkManager.user_data_received.is_connected(_on_user_data_received):
		NetworkManager.user_data_received.disconnect(_on_user_data_received)
	if NetworkManager.risk_event_received.is_connected(_on_uno_event_received):
		NetworkManager.risk_event_received.disconnect(_on_uno_event_received)
	if NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.disconnect(_on_win_happened)
	if NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)

# ==============================================================================
# HUD VISIBILITY & OVERLAY PROTECTION (Prevents showing boxes over Start/End dialogs)
# ==============================================================================

func _is_hud_overlay_blocking() -> bool:
	if not _match_started or not GameManager.is_game_active:
		return true
	var tree = get_tree()
	if not tree:
		return false
	var hud = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		if "is_start_overlay_dismissed" in hud and not hud.is_start_overlay_dismissed:
			return true
		var start_ov = hud.get_node_or_null("StartGameOverlay")
		if is_instance_valid(start_ov) and start_ov.visible:
			return true
		var res_dlg = hud.get_node_or_null("GameResultDialog")
		if is_instance_valid(res_dlg) and res_dlg.visible:
			return true
	return false

func _update_hud_visibility() -> void:
	if not is_instance_valid(hud_root):
		return
	var tree = get_tree()
	if tree:
		var hud = tree.get_first_node_in_group("base_game_hud")
		if not is_instance_valid(hud):
			hud = tree.root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud) and hud_root.get_parent() != hud:
			if hud_root.get_parent():
				hud_root.get_parent().remove_child(hud_root)
			hud.add_child(hud_root)
			var start_ov = hud.get_node_or_null("StartGameOverlay")
			if is_instance_valid(start_ov):
				hud.move_child(hud_root, start_ov.get_index())
			if is_instance_valid(hud_layer):
				hud_layer.queue_free()
				hud_layer = null
	var should_show = not _is_hud_overlay_blocking()
	if hud_root.visible != should_show:
		hud_root.visible = should_show

# ==============================================================================
# 1. 3D TABLETOP ARENA (True Cafe Table Scale: 1.08m diameter, y_base = 0.064m)
# ==============================================================================

func _create_label_3d(text_str: String, f_size: int = 36, col: Color = Color.WHITE, p_size: float = 0.0012) -> Label3D:
	var lbl = Label3D.new()
	lbl.font = FontHekayat
	lbl.text = text_str
	lbl.font_size = f_size
	lbl.pixel_size = p_size
	lbl.modulate = col
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.04, 0.05, 0.08, 0.96)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _build_3d_arena() -> void:
	board_root = Node3D.new()
	board_root.name = "UnoBoardRoot"
	add_child(board_root)

	var y_base: float = 0.064

	# 1. Luxury Circular Mahogany & Brushed Brass Table Plinth (1.08m diameter)
	var outer_rim = MeshInstance3D.new()
	var outer_cyl = CylinderMesh.new()
	outer_cyl.top_radius = 0.54
	outer_cyl.bottom_radius = 0.56
	outer_cyl.height = 0.016
	outer_cyl.radial_segments = 36
	outer_rim.mesh = outer_cyl
	outer_rim.position = Vector3(0.0, y_base + 0.008, 0.0)
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.22, 0.11, 0.07)
	rim_mat.roughness = 0.34
	rim_mat.metallic = 0.12
	outer_rim.material_override = rim_mat
	board_root.add_child(outer_rim)

	# Brushed Brass Bezel Ring around the Arena
	var brass_ring = MeshInstance3D.new()
	var brass_torus = TorusMesh.new()
	brass_torus.inner_radius = 0.505
	brass_torus.outer_radius = 0.525
	brass_torus.rings = 36
	brass_torus.ring_segments = 16
	brass_ring.mesh = brass_torus
	brass_ring.position = Vector3(0.0, y_base + 0.016, 0.0)
	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.85, 0.68, 0.30)
	brass_mat.metallic = 0.82
	brass_mat.roughness = 0.24
	brass_ring.material_override = brass_mat
	board_root.add_child(brass_ring)

	# Deep Royal Navy-Emerald Velvet Felt Surface
	var felt_mesh = MeshInstance3D.new()
	var felt_cyl = CylinderMesh.new()
	felt_cyl.top_radius = 0.508
	felt_cyl.bottom_radius = 0.508
	felt_cyl.height = 0.006
	felt_cyl.radial_segments = 36
	felt_mesh.mesh = felt_cyl
	felt_mesh.position = Vector3(0.0, y_base + 0.015, 0.0)
	var felt_mat = StandardMaterial3D.new()
	felt_mat.albedo_color = Color(0.08, 0.13, 0.20)
	felt_mat.roughness = 0.88
	felt_mesh.material_override = felt_mat
	board_root.add_child(felt_mesh)

	# Subtle Inner Gold Pinstripe Ring on Felt
	var inner_gold_ring = MeshInstance3D.new()
	var ig_torus = TorusMesh.new()
	ig_torus.inner_radius = 0.275
	ig_torus.outer_radius = 0.283
	ig_torus.rings = 32
	ig_torus.ring_segments = 12
	inner_gold_ring.mesh = ig_torus
	inner_gold_ring.position = Vector3(0.0, y_base + 0.019, -0.015)
	inner_gold_ring.material_override = brass_mat
	board_root.add_child(inner_gold_ring)

	# 2. Glowing Active Color Ring in the Center
	color_ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.232
	torus.outer_radius = 0.262
	torus.rings = 36
	torus.ring_segments = 16
	color_ring_mesh.mesh = torus
	color_ring_mesh.position = Vector3(0.0, y_base + 0.020, -0.015)
	color_ring_mat = StandardMaterial3D.new()
	color_ring_mat.albedo_color = UNO_COLORS["red"]
	color_ring_mat.emission_enabled = true
	color_ring_mat.emission = UNO_COLORS["red"]
	color_ring_mat.emission_energy_multiplier = 0.95
	color_ring_mat.roughness = 0.22
	color_ring_mesh.material_override = color_ring_mat
	board_root.add_child(color_ring_mesh)

	# Direction Label in 3D Center (Front of the ring)
	direction_label_3d = _create_label_3d("↻ جهت بازی: ساعتگرد", 30, Color(0.98, 0.93, 0.78), 0.00115)
	direction_label_3d.position = Vector3(0.0, y_base + 0.024, 0.205)
	direction_label_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	board_root.add_child(direction_label_3d)

	# 3. 3D Draw Pile (Left of Center) - Layered Card Stack + Clickable StaticBody3D
	deck_stack_node = Node3D.new()
	deck_stack_node.position = Vector3(-0.115, y_base + 0.019, -0.025)
	board_root.add_child(deck_stack_node)

	# Golden Pulse Highlight Frame under Draw Pile (lights up when player needs to draw)
	deck_glow_mesh = MeshInstance3D.new()
	var dg_box = BoxMesh.new()
	dg_box.size = Vector3(0.158, 0.003, 0.222)
	deck_glow_mesh.mesh = dg_box
	deck_glow_mesh.position = Vector3(0.0, 0.002, 0.0)
	deck_glow_mat = StandardMaterial3D.new()
	deck_glow_mat.albedo_color = Color(0.35, 0.75, 1.0, 0.85)
	deck_glow_mat.emission_enabled = true
	deck_glow_mat.emission = Color(0.25, 0.68, 1.0)
	deck_glow_mat.emission_energy_multiplier = 1.4
	deck_glow_mesh.material_override = deck_glow_mat
	deck_glow_mesh.visible = false
	deck_stack_node.add_child(deck_glow_mesh)

	# Layered Paper Card Stack
	var paper_mat = StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.95, 0.93, 0.88)
	paper_mat.roughness = 0.45

	var dark_back_mat = StandardMaterial3D.new()
	dark_back_mat.albedo_color = Color(0.12, 0.13, 0.18)
	dark_back_mat.roughness = 0.30

	for layer_i in range(6):
		var slab = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.136, 0.0045, 0.196)
		slab.mesh = s_mesh
		slab.position = Vector3(0.0, 0.004 + float(layer_i) * 0.005, 0.0)
		slab.rotation_degrees = Vector3(0.0, sin(float(layer_i) * 1.7) * 1.8, 0.0)
		slab.material_override = dark_back_mat if layer_i == 5 else paper_mat
		deck_stack_node.add_child(slab)

	# Red Oval Accent on Top of Draw Deck
	var deck_top_accent = MeshInstance3D.new()
	var dt_cyl = CylinderMesh.new()
	dt_cyl.top_radius = 0.052
	dt_cyl.bottom_radius = 0.052
	dt_cyl.height = 0.002
	dt_cyl.radial_segments = 24
	deck_top_accent.mesh = dt_cyl
	deck_top_accent.scale = Vector3(1.0, 1.0, 1.42)
	deck_top_accent.position = Vector3(0.0, 0.033, -0.008)
	deck_top_accent.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	var dt_mat = StandardMaterial3D.new()
	dt_mat.albedo_color = Color(0.88, 0.18, 0.22)
	dt_mat.roughness = 0.28
	deck_top_accent.material_override = dt_mat
	deck_stack_node.add_child(deck_top_accent)

	var deck_title_3d = _create_label_3d("UNO", 36, Color(1.0, 0.86, 0.22), 0.0011)
	deck_title_3d.position = Vector3(0.0, 0.036, -0.008)
	deck_title_3d.rotation_degrees = Vector3(-90.0, 0.0, -14.0)
	deck_stack_node.add_child(deck_title_3d)

	deck_count_3d = _create_label_3d("۸۰ کارت", 26, Color.WHITE, 0.0011)
	deck_count_3d.position = Vector3(0.0, 0.036, 0.068)
	deck_count_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	deck_stack_node.add_child(deck_count_3d)

	var deck_body = StaticBody3D.new()
	var deck_col = CollisionShape3D.new()
	var deck_shape = BoxShape3D.new()
	deck_shape.size = Vector3(0.16, 0.06, 0.22)
	deck_col.shape = deck_shape
	deck_col.position = Vector3(0.0, 0.025, 0.0)
	deck_body.add_child(deck_col)
	deck_body.input_event.connect(func(_cam, event, _pos, _norm, _idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_draw_button_pressed()
	)
	deck_stack_node.add_child(deck_body)

	# 4. 3D Top Discard Card (Right of Center)
	discard_pile_node = Node3D.new()
	discard_pile_node.position = Vector3(0.115, y_base + 0.019, -0.025)
	board_root.add_child(discard_pile_node)

	# Subtle previously played cards underneath for 3D depth
	for u_idx in range(2):
		var under_card = MeshInstance3D.new()
		var uc_mesh = BoxMesh.new()
		uc_mesh.size = Vector3(0.138, 0.003, 0.198)
		under_card.mesh = uc_mesh
		under_card.position = Vector3(0.0, 0.002 + float(u_idx) * 0.0035, 0.0)
		under_card.rotation_degrees = Vector3(0.0, -10.0 + float(u_idx) * 16.0, 0.0)
		under_card.material_override = paper_mat
		discard_pile_node.add_child(under_card)

	var card_base = MeshInstance3D.new()
	var cb_mesh = BoxMesh.new()
	cb_mesh.size = Vector3(0.144, 0.004, 0.204)
	card_base.mesh = cb_mesh
	card_base.position = Vector3(0.0, 0.010, 0.0)
	var cb_mat = StandardMaterial3D.new()
	cb_mat.albedo_color = Color.WHITE
	cb_mat.roughness = 0.22
	card_base.material_override = cb_mat
	discard_pile_node.add_child(card_base)

	top_card_mesh = MeshInstance3D.new()
	var tc_mesh = BoxMesh.new()
	tc_mesh.size = Vector3(0.130, 0.0045, 0.190)
	top_card_mesh.mesh = tc_mesh
	top_card_mesh.position = Vector3(0.0, 0.0115, 0.0)
	top_card_mat = StandardMaterial3D.new()
	top_card_mat.albedo_color = UNO_COLORS["red"]
	top_card_mat.roughness = 0.25
	top_card_mesh.material_override = top_card_mat
	discard_pile_node.add_child(top_card_mesh)

	# White Inner Oval on 3D Top Card
	var top_oval = MeshInstance3D.new()
	var to_cyl = CylinderMesh.new()
	to_cyl.top_radius = 0.050
	to_cyl.bottom_radius = 0.050
	to_cyl.height = 0.0015
	to_cyl.radial_segments = 24
	top_oval.mesh = to_cyl
	top_oval.scale = Vector3(1.0, 1.0, 1.38)
	top_oval.position = Vector3(0.0, 0.0142, -0.006)
	top_oval.rotation_degrees = Vector3(0.0, -14.0, 0.0)
	top_card_oval_mat = StandardMaterial3D.new()
	top_card_oval_mat.albedo_color = Color(0.98, 0.98, 0.98)
	top_card_oval_mat.roughness = 0.20
	top_oval.material_override = top_card_oval_mat
	discard_pile_node.add_child(top_oval)

	top_card_corner_tl_3d = _create_label_3d("۷", 22, Color.WHITE, 0.00105)
	top_card_corner_tl_3d.position = Vector3(-0.044, 0.016, -0.072)
	top_card_corner_tl_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	discard_pile_node.add_child(top_card_corner_tl_3d)

	top_card_value_3d = _create_label_3d("۷", 54, UNO_COLORS["red"], 0.0012)
	top_card_value_3d.outline_size = 6
	top_card_value_3d.outline_modulate = Color(1.0, 1.0, 1.0, 0.95)
	top_card_value_3d.position = Vector3(0.0, 0.0165, -0.006)
	top_card_value_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	discard_pile_node.add_child(top_card_value_3d)

	top_card_sub_3d = _create_label_3d("رنگ: قرمز", 24, Color(1.0, 0.96, 0.85), 0.00105)
	top_card_sub_3d.position = Vector3(0.0, 0.0165, 0.072)
	top_card_sub_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	discard_pile_node.add_child(top_card_sub_3d)

	# 5. Opponent 3D Card Stacks & Active Turn Pedestals around the Table Rim
	# Seat 1 = Top (Across), Seat 2 = Left, Seat 3 = Right
	var opp_configs = {
		1: {"pos": Vector3(0.0, y_base + 0.020, -0.385), "rot_y": 0.0},
		2: {"pos": Vector3(-0.385, y_base + 0.020, -0.025), "rot_y": -90.0},
		3: {"pos": Vector3(0.385, y_base + 0.020, -0.025), "rot_y": 90.0}
	}
	for seat_idx in opp_configs.keys():
		var cfg: Dictionary = opp_configs[seat_idx]
		var holder = Node3D.new()
		holder.position = cfg["pos"]
		board_root.add_child(holder)

		# Glowing Turn Plinth under Opponent Fan
		var turn_plinth = MeshInstance3D.new()
		turn_plinth.name = "TurnPlinth"
		var tp_cyl = CylinderMesh.new()
		tp_cyl.top_radius = 0.095
		tp_cyl.bottom_radius = 0.105
		tp_cyl.height = 0.004
		tp_cyl.radial_segments = 24
		turn_plinth.mesh = tp_cyl
		turn_plinth.scale = Vector3(1.45, 1.0, 0.72)
		var tp_mat = StandardMaterial3D.new()
		tp_mat.albedo_color = Color(0.22, 0.28, 0.38, 0.85)
		tp_mat.roughness = 0.35
		turn_plinth.material_override = tp_mat
		holder.add_child(turn_plinth)

		var badge_lbl = _create_label_3d("", 26, Color(1.0, 0.92, 0.68), 0.0011)
		badge_lbl.name = "BadgeLabel"
		badge_lbl.position = Vector3(0.0, 0.052, 0.0)
		badge_lbl.rotation_degrees = Vector3(-62.0, 0.0, 0.0)
		holder.add_child(badge_lbl)

		var fan_container = Node3D.new()
		fan_container.name = "FanContainer"
		fan_container.rotation_degrees = Vector3(0.0, float(cfg["rot_y"]), 0.0)
		holder.add_child(fan_container)
		holder.visible = false
		opponent_stacks_3d[seat_idx] = holder

# ==============================================================================
# 2. 2D GAMER-FRIENDLY HUD & INTERACTIVE CARD DOCK
# (Strictly positioned between TopHeader [0..335px] and BottomBar [1766..1920px])
# ==============================================================================

func _build_2d_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "UnoHUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	hud_layer.add_child(hud_root)

	# --- A. Compact Top-Center Table Status Bar (Strictly below TopHeader y=335px) ---
	status_banner_panel = PanelContainer.new()
	status_banner_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_banner_panel.offset_left = -355.0
	status_banner_panel.offset_right = 355.0
	status_banner_panel.offset_top = 340.0
	status_banner_panel.offset_bottom = 414.0
	status_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.07, 0.09, 0.14, 0.92)
	sb_style.border_color = Color(0.83, 0.69, 0.38, 0.55)
	sb_style.set_border_width_all(2)
	sb_style.set_corner_radius_all(16)
	sb_style.content_margin_left = 14
	sb_style.content_margin_right = 14
	sb_style.content_margin_top = 6
	sb_style.content_margin_bottom = 6
	status_banner_panel.add_theme_stylebox_override("panel", sb_style)
	hud_root.add_child(status_banner_panel)

	var sb_vbox = VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 3)
	sb_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_banner_panel.add_child(sb_vbox)

	var top_info_row = HBoxContainer.new()
	top_info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_info_row.add_theme_constant_override("separation", 12)
	top_info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb_vbox.add_child(top_info_row)

	# Active Color Badge
	color_badge_panel = PanelContainer.new()
	color_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_badge_style = StyleBoxFlat.new()
	color_badge_style.bg_color = UNO_COLORS["red"]
	color_badge_style.set_corner_radius_all(10)
	color_badge_style.set_border_width_all(2)
	color_badge_style.border_color = Color.WHITE
	color_badge_style.content_margin_left = 12
	color_badge_style.content_margin_right = 12
	color_badge_style.content_margin_top = 2
	color_badge_style.content_margin_bottom = 2
	color_badge_panel.add_theme_stylebox_override("panel", color_badge_style)
	top_info_row.add_child(color_badge_panel)

	color_badge_label = Label.new()
	color_badge_label.text = "🔴 رنگ فعال: قرمز"
	color_badge_label.add_theme_font_size_override("font_size", 16)
	color_badge_label.add_theme_color_override("font_color", Color.WHITE)
	color_badge_panel.add_child(color_badge_label)

	direction_badge_label = Label.new()
	direction_badge_label.text = "↻ ساعتگرد"
	direction_badge_label.add_theme_font_size_override("font_size", 15)
	direction_badge_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	top_info_row.add_child(direction_badge_label)

	deck_badge_label = Label.new()
	deck_badge_label.text = "📚 دسته: ۸۰"
	deck_badge_label.add_theme_font_size_override("font_size", 15)
	deck_badge_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	top_info_row.add_child(deck_badge_label)

	# Quick Camera Zoom/Angle Cycle Button
	zoom_cycle_btn = Button.new()
	zoom_cycle_btn.custom_minimum_size = Vector2(96, 28)
	zoom_cycle_btn.text = "🔍 نمای میز"
	zoom_cycle_btn.focus_mode = Control.FOCUS_NONE
	zoom_cycle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zoom_cycle_btn.add_theme_font_size_override("font_size", 14)
	zoom_cycle_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	var z_style = StyleBoxFlat.new()
	z_style.bg_color = Color(0.16, 0.20, 0.28, 0.95)
	z_style.border_color = Color(0.83, 0.69, 0.38, 0.70)
	z_style.set_border_width_all(1)
	z_style.set_corner_radius_all(8)
	z_style.content_margin_left = 8
	z_style.content_margin_right = 8
	zoom_cycle_btn.add_theme_stylebox_override("normal", z_style)
	zoom_cycle_btn.add_theme_stylebox_override("hover", z_style)
	zoom_cycle_btn.add_theme_stylebox_override("pressed", z_style)
	zoom_cycle_btn.pressed.connect(_on_zoom_cycle_pressed)
	top_info_row.add_child(zoom_cycle_btn)

	action_toast_label = Label.new()
	action_toast_label.text = "کارت هم‌رنگ یا هم‌عدد با کارت وسط بازی کنید!"
	action_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_toast_label.add_theme_font_size_override("font_size", 15)
	action_toast_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	sb_vbox.add_child(action_toast_label)

	# --- B. Bottom Interactive Area (Strictly above the 8-button BottomBar at -154px) ---
	var bottom_dock = VBoxContainer.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 14.0
	bottom_dock.offset_right = -14.0
	bottom_dock.offset_top = -456.0
	bottom_dock.offset_bottom = -162.0
	bottom_dock.add_theme_constant_override("separation", 6)
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	# 1. Action Controls Row (Draw Card, Pass Turn, Call UNO)
	var action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(action_row)

	# Draw Card Button
	draw_btn = Button.new()
	draw_btn.custom_minimum_size = Vector2(184, 48)
	draw_btn.text = "🃏 کشیدن کارت"
	draw_btn.focus_mode = Control.FOCUS_NONE
	draw_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	draw_btn.add_theme_font_size_override("font_size", 18)
	draw_btn.add_theme_color_override("font_color", Color.WHITE)
	var draw_style = StyleBoxFlat.new()
	draw_style.bg_color = Color(0.16, 0.44, 0.84)
	draw_style.border_color = Color(0.55, 0.82, 1.0)
	draw_style.set_border_width_all(2)
	draw_style.set_corner_radius_all(14)
	draw_btn.add_theme_stylebox_override("normal", draw_style)
	var draw_hover = draw_style.duplicate()
	draw_hover.bg_color = Color(0.22, 0.52, 0.94)
	draw_btn.add_theme_stylebox_override("hover", draw_hover)
	draw_btn.add_theme_stylebox_override("pressed", draw_hover)
	var draw_disabled = draw_style.duplicate()
	draw_disabled.bg_color = Color(0.18, 0.20, 0.26, 0.65)
	draw_disabled.border_color = Color(0.35, 0.38, 0.45, 0.45)
	draw_btn.add_theme_stylebox_override("disabled", draw_disabled)
	draw_btn.pressed.connect(_on_draw_button_pressed)
	action_row.add_child(draw_btn)

	# Pass Turn Button (Visible after drawing a card)
	pass_btn = Button.new()
	pass_btn.custom_minimum_size = Vector2(156, 48)
	pass_btn.text = "⏭️ رد نوبت"
	pass_btn.focus_mode = Control.FOCUS_NONE
	pass_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pass_btn.add_theme_font_size_override("font_size", 18)
	pass_btn.add_theme_color_override("font_color", Color.WHITE)
	var pass_style = StyleBoxFlat.new()
	pass_style.bg_color = Color(0.76, 0.42, 0.12)
	pass_style.border_color = Color(1.0, 0.78, 0.35)
	pass_style.set_border_width_all(2)
	pass_style.set_corner_radius_all(14)
	pass_btn.add_theme_stylebox_override("normal", pass_style)
	pass_btn.add_theme_stylebox_override("hover", pass_style)
	pass_btn.add_theme_stylebox_override("pressed", pass_style)
	pass_btn.visible = false
	pass_btn.pressed.connect(_on_pass_button_pressed)
	action_row.add_child(pass_btn)

	# UNO Shout Button
	uno_btn = Button.new()
	uno_btn.custom_minimum_size = Vector2(146, 48)
	uno_btn.text = "🔥 اونو! (UNO)"
	uno_btn.focus_mode = Control.FOCUS_NONE
	uno_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	uno_btn.add_theme_font_size_override("font_size", 18)
	uno_btn.add_theme_color_override("font_color", Color.WHITE)
	var uno_style = StyleBoxFlat.new()
	uno_style.bg_color = Color(0.88, 0.18, 0.22)
	uno_style.border_color = Color(1.0, 0.85, 0.25)
	uno_style.set_border_width_all(3)
	uno_style.set_corner_radius_all(14)
	uno_btn.add_theme_stylebox_override("normal", uno_style)
	uno_btn.add_theme_stylebox_override("hover", uno_style)
	uno_btn.add_theme_stylebox_override("pressed", uno_style)
	uno_btn.visible = false
	uno_btn.pressed.connect(_on_uno_button_pressed)
	action_row.add_child(uno_btn)

	# 2. Player's Card Hand Tray Panel
	var hand_tray = PanelContainer.new()
	hand_tray.custom_minimum_size = Vector2(0, 228)
	hand_tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tray_style = StyleBoxFlat.new()
	tray_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	tray_style.border_color = Color(0.83, 0.69, 0.38, 0.52)
	tray_style.set_border_width_all(2)
	tray_style.set_corner_radius_all(20)
	tray_style.content_margin_left = 14
	tray_style.content_margin_right = 14
	tray_style.content_margin_top = 8
	tray_style.content_margin_bottom = 8
	hand_tray.add_theme_stylebox_override("panel", tray_style)
	bottom_dock.add_child(hand_tray)

	var tray_vbox = VBoxContainer.new()
	tray_vbox.add_theme_constant_override("separation", 4)
	hand_tray.add_child(tray_vbox)

	var tray_header = HBoxContainer.new()
	tray_vbox.add_child(tray_header)

	turn_hint_label = Label.new()
	turn_hint_label.text = "در انتظار شروع بازی..."
	turn_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_hint_label.add_theme_font_size_override("font_size", 16)
	turn_hint_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.62))
	tray_header.add_child(turn_hint_label)

	hand_count_badge = Label.new()
	hand_count_badge.text = "دست شما: ۷ کارت"
	hand_count_badge.add_theme_font_size_override("font_size", 16)
	hand_count_badge.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	tray_header.add_child(hand_count_badge)

	hand_scroll = ScrollContainer.new()
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tray_vbox.add_child(hand_scroll)

	hand_hbox = HBoxContainer.new()
	hand_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_hbox.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(hand_hbox)

	# --- C. Wild Color Picker Modal ---
	_build_wild_color_modal()

func _build_wild_color_modal() -> void:
	wild_modal_backdrop = ColorRect.new()
	wild_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	wild_modal_backdrop.color = Color(0.0, 0.0, 0.0, 0.72)
	wild_modal_backdrop.visible = false
	wild_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(wild_modal_backdrop)

	var center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	wild_modal_backdrop.add_child(center_box)

	var modal_panel = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(440, 320)
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(0.10, 0.12, 0.18, 0.98)
	m_style.border_color = Color(0.92, 0.78, 0.38)
	m_style.set_border_width_all(3)
	m_style.set_corner_radius_all(24)
	m_style.content_margin_left = 24
	m_style.content_margin_right = 24
	m_style.content_margin_top = 20
	m_style.content_margin_bottom = 20
	modal_panel.add_theme_stylebox_override("panel", m_style)
	center_box.add_child(modal_panel)

	var m_vbox = VBoxContainer.new()
	m_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m_vbox.add_theme_constant_override("separation", 16)
	modal_panel.add_child(m_vbox)

	wild_modal_card_label = Label.new()
	wild_modal_card_label.text = "🎨 رنگ بعدی بازی را انتخاب کنید"
	wild_modal_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wild_modal_card_label.add_theme_font_size_override("font_size", 22)
	wild_modal_card_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	m_vbox.add_child(wild_modal_card_label)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	m_vbox.add_child(grid)

	var color_choices = [
		{"key": "red", "label": "🔴 قرمز"},
		{"key": "blue", "label": "🔵 آبی"},
		{"key": "green", "label": "🟢 سبز"},
		{"key": "yellow", "label": "🟡 زرد"}
	]
	for item in color_choices:
		var c_key: String = item["key"]
		var c_btn = Button.new()
		c_btn.custom_minimum_size = Vector2(185, 74)
		c_btn.text = item["label"]
		c_btn.focus_mode = Control.FOCUS_NONE
		c_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c_btn.add_theme_font_size_override("font_size", 22)
		c_btn.add_theme_color_override("font_color", Color.WHITE)

		var c_style = StyleBoxFlat.new()
		c_style.bg_color = UNO_COLORS[c_key]
		c_style.border_color = Color.WHITE
		c_style.set_border_width_all(3)
		c_style.set_corner_radius_all(16)
		c_btn.add_theme_stylebox_override("normal", c_style)
		c_btn.add_theme_stylebox_override("hover", c_style)
		c_btn.add_theme_stylebox_override("pressed", c_style)
		c_btn.pressed.connect(func(): _on_wild_color_chosen(c_key))
		grid.add_child(c_btn)

	var cancel_btn = Button.new()
	cancel_btn.custom_minimum_size = Vector2(160, 44)
	cancel_btn.text = "انصراف"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.add_theme_font_size_override("font_size", 17)
	cancel_btn.pressed.connect(func():
		pending_wild_card.clear()
		wild_modal_backdrop.visible = false
	)
	m_vbox.add_child(cancel_btn)

# ==============================================================================
# 3. CARD PLAYABILITY & FORMATTING HELPERS
# ==============================================================================

func _is_card_playable(card: Dictionary) -> bool:
	if not is_my_turn or is_board_locked:
		return false
	if rank1_player == my_player_index:
		return false
	var c_color = String(card.get("color", ""))
	var c_value = String(card.get("value", ""))
	if c_color == "wild" or c_value in ["wild", "wild_draw4"]:
		return true
	if c_color == current_color:
		return true
	var top_val = String(top_card.get("value", ""))
	if not top_val.is_empty() and c_value == top_val:
		return true
	return false

func _has_any_playable_card() -> bool:
	for card in my_hand:
		if typeof(card) == TYPE_DICTIONARY and _is_card_playable(card):
			return true
	return false

func _format_card_center_text(value: String) -> String:
	match value:
		"skip":
			return "🚫"
		"reverse":
			return "🔄"
		"draw2":
			return "+۲"
		"wild":
			return "🎨"
		"wild_draw4":
			return "+۴"
		_:
			return _to_persian_digits(value)

func _format_card_subtitle_text(value: String) -> String:
	match value:
		"skip":
			return "پرش نوبت"
		"reverse":
			return "دوربرگردان"
		"draw2":
			return "۲ کارت جریمه"
		"wild":
			return "تغییر رنگ"
		"wild_draw4":
			return "تغییر رنگ +۴"
		_:
			return "عدد " + _to_persian_digits(value)

func _to_persian_digits(input_str: String) -> String:
	var eng = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
	var per = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var res = input_str
	for i in range(10):
		res = res.replace(eng[i], per[i])
	return res

func _update_hands_count_from_variant(raw: Variant) -> void:
	if typeof(raw) == TYPE_ARRAY:
		var arr: Array = raw
		for i in range(arr.size()):
			hands_count[str(i + 1)] = int(arr[i])
	elif typeof(raw) == TYPE_DICTIONARY:
		var d: Dictionary = raw
		for k in d.keys():
			hands_count[str(k)] = int(d[k])

func _get_hands_count_array() -> Array:
	var arr: Array = []
	var total_p = clampi(max(2, GameManager.match_players.size()), 2, 4)
	for i in range(1, total_p + 1):
		arr.append(int(hands_count.get(str(i), hands_count.get(i, 7))))
	return arr

# ==============================================================================
# 4. RENDERING & UI REFRESH
# ==============================================================================

func _refresh_all_visuals() -> void:
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active

	_refresh_3d_centerpiece()
	_refresh_3d_opponents()
	_refresh_status_banner()
	_refresh_hand_dock()
	_refresh_top_header_badges()
	_update_hud_visibility()

func _refresh_3d_centerpiece() -> void:
	var active_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])
	if color_ring_mat:
		color_ring_mat.albedo_color = active_col
		color_ring_mat.emission = active_col

	if direction_label_3d:
		direction_label_3d.text = "↻ جهت بازی: ساعتگرد" if direction == 1 else "↺ جهت بازی: پادساعتگرد"

	if deck_count_3d:
		deck_count_3d.text = "%s کارت" % _to_persian_digits(str(deck_remaining))

	if deck_glow_mesh:
		var must_draw = is_my_turn and (not has_drawn_this_turn) and (not _has_any_playable_card())
		deck_glow_mesh.visible = must_draw

	if top_card_mat and not top_card.is_empty():
		var tc_color_key = String(top_card.get("color", current_color))
		var display_key = current_color if tc_color_key == "wild" else tc_color_key
		var face_col: Color = UNO_COLORS.get(display_key, active_col)
		top_card_mat.albedo_color = face_col
		if top_card_value_3d:
			top_card_value_3d.modulate = face_col if tc_color_key != "wild" else Color(1.0, 0.88, 0.25)
		if top_card_oval_mat:
			top_card_oval_mat.albedo_color = Color(0.98, 0.98, 0.98) if tc_color_key != "wild" else Color(0.14, 0.14, 0.20)

	if not top_card.is_empty():
		var val_str = String(top_card.get("value", "0"))
		var center_txt = _format_card_center_text(val_str)
		if top_card_value_3d:
			top_card_value_3d.text = center_txt
		if top_card_corner_tl_3d:
			top_card_corner_tl_3d.text = center_txt

	if top_card_sub_3d:
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		top_card_sub_3d.text = "رنگ: " + cname

func _animate_discard_card_pop() -> void:
	if not discard_pile_node or not is_instance_valid(discard_pile_node):
		return
	discard_pile_node.scale = Vector3(0.75, 0.75, 0.75)
	discard_pile_node.rotation_degrees.y = randf_range(-10.0, 10.0)
	var tw = create_tween()
	tw.tween_property(discard_pile_node, "scale", Vector3(1.12, 1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(discard_pile_node, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)

func _refresh_3d_opponents() -> void:
	var total_p = clampi(max(2, GameManager.match_players.size()), 2, 4)
	players_count = total_p

	for seat_idx in opponent_stacks_3d.keys():
		opponent_stacks_3d[seat_idx].visible = false

	# Map other players to seats around the table
	var other_pids: Array[int] = []
	for offset in range(1, total_p):
		var pid = ((my_player_index - 1 + offset) % total_p) + 1
		other_pids.append(pid)

	var seat_mapping: Array[int] = []
	if other_pids.size() == 1:
		seat_mapping = [1] # Directly across (Top)
	elif other_pids.size() == 2:
		seat_mapping = [2, 3] # Left and Right
	else:
		seat_mapping = [2, 1, 3] # Left, Top, Right

	for i in range(other_pids.size()):
		var pid = other_pids[i]
		var seat = seat_mapping[i]
		var holder: Node3D = opponent_stacks_3d.get(seat)
		if not holder:
			continue
		holder.visible = true

		var c_count = int(hands_count.get(str(pid), hands_count.get(pid, 7)))
		var p_name = _get_player_short_name(pid)
		var is_opp_turn: bool = (current_turn == pid) and GameManager.is_game_active

		var turn_plinth: MeshInstance3D = holder.get_node_or_null("TurnPlinth")
		if turn_plinth and turn_plinth.material_override is StandardMaterial3D:
			var tp_mat: StandardMaterial3D = turn_plinth.material_override
			if is_opp_turn:
				tp_mat.albedo_color = Color(0.22, 0.92, 0.52)
				tp_mat.emission_enabled = true
				tp_mat.emission = Color(0.18, 0.85, 0.45)
				tp_mat.emission_energy_multiplier = 1.15
			elif c_count == 1:
				tp_mat.albedo_color = Color(0.92, 0.22, 0.22)
				tp_mat.emission_enabled = true
				tp_mat.emission = Color(0.92, 0.18, 0.18)
				tp_mat.emission_energy_multiplier = 1.0
			else:
				tp_mat.albedo_color = Color(0.18, 0.24, 0.34)
				tp_mat.emission_enabled = false

		var badge_lbl: Label3D = holder.get_node_or_null("BadgeLabel")
		if badge_lbl:
			var turn_prefix = "⏳ " if is_opp_turn else ""
			var uno_suffix = " 🔥UNO!" if c_count == 1 else ""
			badge_lbl.text = "%s%s: %s کارت%s" % [turn_prefix, p_name, _to_persian_digits(str(c_count)), uno_suffix]
			badge_lbl.modulate = Color(0.45, 1.0, 0.65) if is_opp_turn else (Color(1.0, 0.48, 0.48) if c_count == 1 else Color(1.0, 0.92, 0.72))

		var fan_container: Node3D = holder.get_node_or_null("FanContainer")
		if fan_container:
			for child in fan_container.get_children():
				child.queue_free()
			var visible_cards = clampi(c_count, 0, 10)
			for c_idx in range(visible_cards):
				var mini_card = MeshInstance3D.new()
				var m_box = BoxMesh.new()
				m_box.size = Vector3(0.062, 0.003, 0.092)
				mini_card.mesh = m_box
				var norm_idx: float = float(c_idx) - float(visible_cards - 1) * 0.5
				var spread_x: float = norm_idx * 0.024
				var arch_z: float = absf(norm_idx) * 0.004
				mini_card.position = Vector3(spread_x, 0.006 + 0.0018 * float(c_idx), arch_z)
				mini_card.rotation_degrees = Vector3(18.0, -norm_idx * 5.5, 0.0)
				var m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.88, 0.16, 0.20) if c_count == 1 else Color(0.16, 0.20, 0.32)
				m_mat.roughness = 0.32
				mini_card.material_override = m_mat
				fan_container.add_child(mini_card)

func _refresh_status_banner() -> void:
	var active_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])
	if color_badge_style:
		color_badge_style.bg_color = active_col
	if color_badge_label:
		var emoji = UNO_COLOR_EMOJIS.get(current_color, "🔴")
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		color_badge_label.text = "%s رنگ فعال: %s" % [emoji, cname]

	if direction_badge_label:
		direction_badge_label.text = "↻ ساعتگرد" if direction == 1 else "↺ پادساعتگرد"

	if deck_badge_label:
		deck_badge_label.text = "📚 دسته: %s" % _to_persian_digits(str(deck_remaining))

func _refresh_hand_dock() -> void:
	if not hand_hbox:
		return
	for child in hand_hbox.get_children():
		child.queue_free()

	var my_count = my_hand.size()
	if hand_count_badge:
		hand_count_badge.text = "دست شما: %s کارت" % _to_persian_digits(str(my_count))

	var any_playable = _has_any_playable_card()

	if turn_hint_label:
		if rank1_player == my_player_index:
			turn_hint_label.text = "👑 شما تمام کارت‌هایتان را بازی کردید و نفر اول شدید!"
			turn_hint_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif is_my_turn:
			if any_playable:
				turn_hint_label.text = "🟢 نوبت شماست! روی یکی از کارت‌های روشن بزنید"
				turn_hint_label.add_theme_color_override("font_color", Color(0.40, 0.98, 0.58))
			elif has_drawn_this_turn:
				turn_hint_label.text = "🟡 کارت قابل بازی ندارید؛ روی «رد نوبت» بزنید"
				turn_hint_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
			else:
				turn_hint_label.text = "🔵 کارت قابل بازی ندارید؛ روی «کشیدن کارت» یا دسته وسط بزنید"
				turn_hint_label.add_theme_color_override("font_color", Color(0.52, 0.84, 1.0))
		else:
			var active_name = _get_player_short_name(current_turn)
			turn_hint_label.text = "⏳ نوبت %s است..." % active_name
			turn_hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))

	# Update Action Buttons
	if draw_btn:
		draw_btn.disabled = (not is_my_turn) or has_drawn_this_turn or is_board_locked
		if is_my_turn and not has_drawn_this_turn and not any_playable:
			draw_btn.text = "🃏 کشیدن کارت (اجباری)"
		else:
			draw_btn.text = "🃏 کشیدن کارت"

	if pass_btn:
		pass_btn.visible = is_my_turn and has_drawn_this_turn

	if uno_btn:
		var already_called = bool(uno_called.get(str(my_player_index), uno_called.get(my_player_index, false)))
		uno_btn.visible = (my_count <= 2 and my_count >= 1 and not already_called)

	# Build Tactile 2D Card Buttons in Player's Hand
	for card in my_hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var playable = _is_card_playable(card)
		var card_ctrl = _create_hand_card_widget(card, playable)
		hand_hbox.add_child(card_ctrl)

func _create_hand_card_widget(card: Dictionary, playable: bool) -> Control:
	var c_uid = int(card.get("uid", -1))
	var c_color = String(card.get("color", "red"))
	var c_value = String(card.get("value", "0"))

	# Wrapper adds top padding so playable cards visually pop UP towards the table
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(110, 162)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(106, 146)
	btn.position = Vector2(2, 2 if playable else 14)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if playable else Control.CURSOR_ARROW

	var base_color: Color = UNO_COLORS.get(c_color, UNO_COLORS["red"])
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = base_color
	card_style.set_corner_radius_all(16)
	if playable:
		card_style.set_border_width_all(4)
		card_style.border_color = Color(1.0, 0.94, 0.38)
		card_style.shadow_color = Color(1.0, 0.88, 0.25, 0.45)
		card_style.shadow_size = 8
	else:
		card_style.set_border_width_all(2)
		card_style.border_color = Color(1.0, 1.0, 1.0, 0.65)

	btn.add_theme_stylebox_override("normal", card_style)
	var hover_style = card_style.duplicate()
	if playable:
		hover_style.border_color = Color.WHITE
		hover_style.shadow_size = 12
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	if not playable and is_my_turn:
		btn.modulate = Color(0.62, 0.64, 0.70, 0.90)
	elif not is_my_turn:
		btn.modulate = Color(0.82, 0.84, 0.88, 0.95)

	# Card Inner Layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_right = -8
	vbox.offset_top = 6
	vbox.offset_bottom = -6
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# Top-left corner symbol
	var corner_top = Label.new()
	corner_top.text = _format_card_center_text(c_value)
	corner_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	corner_top.add_theme_font_size_override("font_size", 15)
	corner_top.add_theme_color_override("font_color", Color.WHITE)
	corner_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(corner_top)

	# Center White Oval with big symbol
	var center_oval = PanelContainer.new()
	center_oval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_oval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var oval_style = StyleBoxFlat.new()
	oval_style.bg_color = Color(1.0, 1.0, 1.0, 0.94) if c_color != "wild" else Color(0.14, 0.14, 0.20, 0.95)
	oval_style.set_corner_radius_all(26)
	center_oval.add_theme_stylebox_override("panel", oval_style)
	vbox.add_child(center_oval)

	var center_lbl = Label.new()
	center_lbl.text = _format_card_center_text(c_value)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_lbl.add_theme_font_size_override("font_size", 32)
	center_lbl.add_theme_color_override("font_color", base_color if c_color != "wild" else Color(1.0, 0.88, 0.28))
	center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_oval.add_child(center_lbl)

	# Bottom Subtitle (e.g., پرش نوبت / تغییر رنگ / عدد ۷)
	var bottom_lbl = Label.new()
	bottom_lbl.text = _format_card_subtitle_text(c_value)
	bottom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_lbl.add_theme_font_size_override("font_size", 12)
	bottom_lbl.add_theme_color_override("font_color", Color.WHITE)
	bottom_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_lbl)

	btn.pressed.connect(func(): _on_hand_card_clicked(c_uid, card))
	wrapper.add_child(btn)
	return wrapper

func _refresh_top_header_badges() -> void:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var header = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
		if is_instance_valid(header) and header.has_method("update_uno_hands"):
			header.update_uno_hands(_get_hands_count_array(), rank1_player, rank2_player)

func _get_player_short_name(pid: int) -> String:
	if pid == my_player_index:
		return "شما"
	var p_data = GameManager.get_player_data_by_gamer_id(pid)
	if not p_data.is_empty():
		var n = String(p_data.get("name", p_data.get("username", "")))
		if not n.is_empty():
			return n
	return "بازیکن %s" % _to_persian_digits(str(pid))

# ==============================================================================
# 5. USER INTERACTIONS (PLAY CARD, WILD COLOR, DRAW, PASS, CALL UNO, ZOOM)
# ==============================================================================

func _on_zoom_cycle_pressed() -> void:
	var table = get_tree().get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		return
	_zoom_preset_idx = (_zoom_preset_idx + 1) % 3
	if _zoom_preset_idx == 0:
		# Default Balanced Tabletop View
		camera_distance = 2.75
		camera_pitch = -1.06
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 2.75
		table.target_pitch = -1.06
		table.target_yaw = 0.0
		if zoom_cycle_btn:
			zoom_cycle_btn.text = "🔍 نمای میز"
	elif _zoom_preset_idx == 1:
		# Wide Zoomed-Out Cafe View
		camera_distance = 3.55
		camera_pitch = -0.96
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 3.55
		table.target_pitch = -0.96
		table.target_yaw = 0.0
		if zoom_cycle_btn:
			zoom_cycle_btn.text = "🔍 نمای دور"
	else:
		# Direct Top-Down 2D View
		table.top_down_target_height = 2.85
		table.set_top_down_view(true, 0.45)
		if zoom_cycle_btn:
			zoom_cycle_btn.text = "🔍 نمای بالا"

func _on_hand_card_clicked(card_uid: int, card: Dictionary) -> void:
	if not is_my_turn:
		show_hint("الان نوبت شما نیست!")
		return
	if is_board_locked:
		return
	if not _is_card_playable(card):
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		show_hint("این کارت قابل بازی نیست! کارت هم‌رنگ (%s) یا هم‌عدد بازی کنید." % cname)
		return

	var c_color = String(card.get("color", ""))
	var c_val = String(card.get("value", ""))
	if c_color == "wild" or c_val in ["wild", "wild_draw4"]:
		pending_wild_card = card.duplicate()
		var is_plus4 = (c_val == "wild_draw4")
		if wild_modal_card_label:
			wild_modal_card_label.text = "🎨 رنگ بعدی را برای کارت «%s» انتخاب کنید:" % ("+۴ جریمه" if is_plus4 else "تغییر رنگ")
		wild_modal_backdrop.visible = true
		return

	_send_play_card(card_uid, c_color)

func _on_wild_color_chosen(chosen_color: String) -> void:
	wild_modal_backdrop.visible = false
	if pending_wild_card.is_empty():
		return
	var c_uid = int(pending_wild_card.get("uid", -1))
	pending_wild_card.clear()
	if c_uid >= 0:
		_send_play_card(c_uid, chosen_color)

func _send_play_card(card_uid: int, chosen_color: String) -> void:
	set_board_locked(true)
	send_move(Commands.Play_Card, {
		"card_uid": card_uid,
		"chosen_color": chosen_color
	})

func _on_draw_button_pressed() -> void:
	if not is_my_turn:
		show_hint("الان نوبت شما نیست!")
		return
	if is_board_locked:
		return
	if has_drawn_this_turn:
		show_hint("شما در این نوبت قبلاً کارت کشیده‌اید!")
		return
	set_board_locked(true)
	send_move(Commands.Draw_Card, {})

func _on_pass_button_pressed() -> void:
	if not is_my_turn or not has_drawn_this_turn:
		return
	set_board_locked(true)
	send_move(Commands.Pass_Turn, {})

func _on_uno_button_pressed() -> void:
	send_move(Commands.Call_Uno, {})
	uno_btn.visible = false
	if action_toast_label:
		action_toast_label.text = "🔥 شما «اونو (UNO)!» اعلام کردید!"

# ==============================================================================
# 6. NETWORK SYNC & EVENT HANDLERS
# ==============================================================================

func _apply_uno_state_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	_match_started = true
	if data.has("my_hand") and typeof(data["my_hand"]) == TYPE_ARRAY:
		my_hand = data["my_hand"].duplicate(true)
	elif data.has("hand") and typeof(data["hand"]) == TYPE_ARRAY:
		my_hand = data["hand"].duplicate(true)

	if data.has("hands_count"):
		_update_hands_count_from_variant(data["hands_count"])

	if data.has("top_card") and typeof(data["top_card"]) == TYPE_DICTIONARY:
		top_card = data["top_card"].duplicate(true)
	if data.has("current_color") and data["current_color"] != null:
		current_color = String(data["current_color"])
	if data.has("direction") and data["direction"] != null:
		direction = int(data["direction"])
	if data.has("deck_remaining") and data["deck_remaining"] != null:
		deck_remaining = int(data["deck_remaining"])
	elif data.has("draw_pile_count") and data["draw_pile_count"] != null:
		deck_remaining = int(data["draw_pile_count"])

	if data.has("has_drawn_this_turn"):
		has_drawn_this_turn = bool(data["has_drawn_this_turn"])
	if data.has("uno_called") and typeof(data["uno_called"]) == TYPE_DICTIONARY:
		uno_called = data["uno_called"].duplicate(true)
	if data.has("rank1") and data["rank1"] != null:
		rank1_player = int(data["rank1"])
		GameManager.ludo_rank1 = rank1_player
	if data.has("rank2") and data["rank2"] != null:
		rank2_player = int(data["rank2"])
		GameManager.ludo_rank2 = rank2_player

	if data.has("current_turn") and data["current_turn"] != null:
		current_turn = int(data["current_turn"])
		GameManager.current_turn = current_turn
	elif data.has("turn") and data["turn"] != null:
		current_turn = int(data["turn"])
		GameManager.current_turn = current_turn

	is_my_turn = (current_turn == GameManager.my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn
	_refresh_all_visuals()

func setup_board(game_data: Dictionary) -> void:
	_match_started = true
	if game_data.has("gamers") and typeof(game_data["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(game_data["gamers"])
	var inner = game_data.get("game_data", game_data)
	if typeof(inner) == TYPE_DICTIONARY:
		_apply_uno_state_dict(inner)
	if game_data.has("user_data") and typeof(game_data["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(game_data["user_data"])
	_update_hud_visibility()

func on_start_game() -> void:
	_match_started = true
	super.on_start_game()
	_refresh_all_visuals()
	_update_hud_visibility()

func _on_user_data_received(data: Dictionary) -> void:
	_apply_uno_state_dict(data)

func on_turn_data(payload: Dictionary) -> void:
	_apply_uno_state_dict(payload)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	_match_started = true
	current_turn = turn
	is_my_turn = (turn == GameManager.my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn
	if not is_my_turn:
		has_drawn_this_turn = false
		wild_modal_backdrop.visible = false
	_refresh_all_visuals()
	_update_hud_visibility()

func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
	var g_data = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_uno_state_dict(g_data)
	if payload.has("user_data") and typeof(payload["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(payload["user_data"])
	_update_hud_visibility()

func _on_uno_event_received(event_type: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var p: Dictionary = payload
	_match_started = true

	match event_type:
		Commands.Card_Played:
			var pid = int(p.get("player", p.get("gamer_id", 0)))
			var card: Dictionary = p.get("card", {}) if typeof(p.get("card")) == TYPE_DICTIONARY else {}
			if not card.is_empty():
				top_card = card.duplicate(true)
			if p.has("current_color") and p["current_color"] != null:
				current_color = String(p["current_color"])
			if p.has("direction") and p["direction"] != null:
				direction = int(p["direction"])
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if p.has("deck_remaining") and p["deck_remaining"] != null:
				deck_remaining = int(p["deck_remaining"])
			elif p.has("draw_pile_count") and p["draw_pile_count"] != null:
				deck_remaining = int(p["draw_pile_count"])

			var actor_name = _get_player_short_name(pid)
			var val_str = String(card.get("value", ""))
			var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
			var msg = "%s کارت «%s» بازی کرد (رنگ: %s)" % [actor_name, _format_card_subtitle_text(val_str), cname]

			var effect: Dictionary = p.get("effect", {}) if typeof(p.get("effect")) == TYPE_DICTIONARY else {}
			var eff_type = String(effect.get("type", val_str))
			if eff_type == "skip":
				var sk_p = int(effect.get("skipped_player", p.get("skipped_player", 0)))
				msg = "🚫 %s نوبت %s را سوزاند!" % [actor_name, _get_player_short_name(sk_p)]
			elif eff_type == "reverse":
				msg = "🔄 %s جهت چرخش بازی را برعکس کرد!" % actor_name
			elif eff_type == "draw2":
				var tp = int(effect.get("target_player", p.get("penalty_target", 0)))
				msg = "💥 %s به %s جریمه +۲ کارت زد!" % [actor_name, _get_player_short_name(tp)]
			elif eff_type == "wild_draw4":
				var tp4 = int(effect.get("target_player", p.get("penalty_target", 0)))
				msg = "🔥 %s کارت +۴ بازی کرد و رنگ را «%s» کرد! (%s ۴ کارت کشید)" % [actor_name, cname, _get_player_short_name(tp4)]
			elif eff_type == "wild":
				msg = "🎨 %s رنگ بازی را به «%s» تغییر داد!" % [actor_name, cname]

			if action_toast_label:
				action_toast_label.text = msg
			_refresh_all_visuals()
			_animate_discard_card_pop()

		Commands.Draw_Result_Private:
			if p.has("user_data") and typeof(p["user_data"]) == TYPE_DICTIONARY:
				_apply_uno_state_dict(p["user_data"])
			if p.has("my_hand") and typeof(p["my_hand"]) == TYPE_ARRAY:
				my_hand = p["my_hand"].duplicate(true)
			elif p.has("hand") and typeof(p["hand"]) == TYPE_ARRAY:
				my_hand = p["hand"].duplicate(true)

			var turn_passed = bool(p.get("turn_passed", false))
			var playable = bool(p.get("playable", p.get("drawn_is_playable", false))) and not turn_passed
			has_drawn_this_turn = playable
			is_board_locked = not (is_my_turn and playable)
			if action_toast_label:
				if playable:
					action_toast_label.text = "✨ کارت جدید قابل بازی است! می‌توانید بازی کنید یا «رد نوبت» بزنید."
				else:
					action_toast_label.text = "🃏 یک کارت کشیدید؛ کارت قابل بازی نبود و نوبت رد شد."
			_refresh_all_visuals()

		Commands.Draw_Result:
			var d_pid = int(p.get("player", p.get("gamer_id", 0)))
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if p.has("deck_remaining") and p["deck_remaining"] != null:
				deck_remaining = int(p["deck_remaining"])
			elif p.has("draw_pile_count") and p["draw_pile_count"] != null:
				deck_remaining = int(p["draw_pile_count"])
			if d_pid != my_player_index and action_toast_label:
				action_toast_label.text = "🃏 %s یک کارت از دسته کشید." % _get_player_short_name(d_pid)
			_refresh_all_visuals()

		Commands.Pass_Turn:
			var pass_pid = int(p.get("player", p.get("gamer_id", 0)))
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if action_toast_label:
				action_toast_label.text = "⏭️ %s نوبت را رد کرد." % _get_player_short_name(pass_pid)
			_refresh_all_visuals()

		Commands.Uno_Called:
			var u_pid = int(p.get("player", p.get("gamer_id", 0)))
			uno_called[str(u_pid)] = true
			if action_toast_label:
				action_toast_label.text = "🔥 %s فریاد زد: اونو (UNO)!" % _get_player_short_name(u_pid)
			_refresh_all_visuals()

		Commands.User_Data:
			_apply_uno_state_dict(p)

func _on_win_happened(payload: Dictionary) -> void:
	if payload.has("rank1") and payload["rank1"] != null:
		rank1_player = int(payload["rank1"])
	elif payload.has("winner_id") and payload["winner_id"] != null:
		rank1_player = int(payload["winner_id"])
	elif payload.has("Winner") and payload["Winner"] != null:
		rank1_player = int(payload["Winner"])
	if payload.has("rank2") and payload["rank2"] != null:
		rank2_player = int(payload["rank2"])
	if rank1_player > 0:
		GameManager.ludo_rank1 = rank1_player
	if rank2_player > 0:
		GameManager.ludo_rank2 = rank2_player
	_refresh_all_visuals()

func reset_board() -> void:
	_match_started = false
	my_hand.clear()
	hands_count = {"1": 7, "2": 7, "3": 7, "4": 7}
	top_card.clear()
	has_drawn_this_turn = false
	pending_wild_card.clear()
	if wild_modal_backdrop:
		wild_modal_backdrop.visible = false
	_refresh_all_visuals()
	_update_hud_visibility()

func cleanup_board() -> void:
	if hud_root and is_instance_valid(hud_root):
		hud_root.queue_free()
	if hud_layer and is_instance_valid(hud_layer):
		hud_layer.queue_free()
