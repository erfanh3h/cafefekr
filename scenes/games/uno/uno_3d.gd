class_name Uno3D
extends "res://scripts/games/base_game_board.gd"

# Uno3D - Gamer-Friendly, Clean 2-4 Player UNO Game Scene
# Combines a tactile 3D cafe table centerpiece (Draw Deck, Top Discard Card, Active Color Ring,
# Direction Indicator, and Opponent Card Stacks) with a crystal-clear, responsive 2D Card Dock
# so players can read and play their cards effortlessly within 1 second.

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

# --- 3D Nodes ---
var board_root: Node3D
var color_ring_mesh: MeshInstance3D
var color_ring_mat: StandardMaterial3D
var direction_label_3d: Label3D
var top_card_mesh: MeshInstance3D
var top_card_mat: StandardMaterial3D
var top_card_value_3d: Label3D
var top_card_sub_3d: Label3D
var deck_stack_node: Node3D
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

func _exit_tree() -> void:
	_disconnect_uno_signals()
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
# 1. 3D TABLETOP ARENA
# ==============================================================================

func _build_3d_arena() -> void:
	board_root = Node3D.new()
	board_root.name = "UnoBoardRoot"
	add_child(board_root)

	# 1. Circular Mahogany & Velvet Felt Table Mat
	var outer_rim = MeshInstance3D.new()
	var outer_cyl = CylinderMesh.new()
	outer_cyl.top_radius = 4.6
	outer_cyl.bottom_radius = 4.75
	outer_cyl.height = 0.16
	outer_cyl.radial_segments = 48
	outer_rim.mesh = outer_cyl
	outer_rim.position = Vector3(0, 0.08, 0)
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.16, 0.10, 0.08)
	rim_mat.roughness = 0.35
	rim_mat.metallic = 0.2
	outer_rim.material_override = rim_mat
	board_root.add_child(outer_rim)

	var felt_mesh = MeshInstance3D.new()
	var felt_cyl = CylinderMesh.new()
	felt_cyl.top_radius = 4.35
	felt_cyl.bottom_radius = 4.35
	felt_cyl.height = 0.18
	felt_cyl.radial_segments = 48
	felt_mesh.mesh = felt_cyl
	felt_mesh.position = Vector3(0, 0.09, 0)
	var felt_mat = StandardMaterial3D.new()
	felt_mat.albedo_color = Color(0.09, 0.13, 0.20)
	felt_mat.roughness = 0.85
	felt_mesh.material_override = felt_mat
	board_root.add_child(felt_mesh)

	# 2. Glowing Active Color Ring in the Center
	color_ring_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 2.05
	torus.outer_radius = 2.32
	torus.rings = 48
	torus.ring_segments = 24
	color_ring_mesh.mesh = torus
	color_ring_mesh.position = Vector3(0, 0.20, -0.25)
	color_ring_mat = StandardMaterial3D.new()
	color_ring_mat.albedo_color = UNO_COLORS["red"]
	color_ring_mat.emission_enabled = true
	color_ring_mat.emission = UNO_COLORS["red"]
	color_ring_mat.emission_energy_multiplier = 0.85
	color_ring_mat.roughness = 0.25
	color_ring_mesh.material_override = color_ring_mat
	board_root.add_child(color_ring_mesh)

	# Direction Label in 3D Center
	direction_label_3d = Label3D.new()
	direction_label_3d.text = "↻ جهت بازی: ساعتگرد"
	direction_label_3d.font_size = 46
	direction_label_3d.outline_size = 10
	direction_label_3d.modulate = Color(0.95, 0.92, 0.82)
	direction_label_3d.position = Vector3(0, 0.24, 1.55)
	direction_label_3d.rotation_degrees = Vector3(-90, 0, 0)
	board_root.add_child(direction_label_3d)

	# 3. 3D Draw Pile (Left of Center) - Also clickable in 3D!
	deck_stack_node = Node3D.new()
	deck_stack_node.position = Vector3(-1.05, 0.20, -0.25)
	board_root.add_child(deck_stack_node)

	var deck_box = MeshInstance3D.new()
	var d_mesh = BoxMesh.new()
	d_mesh.size = Vector3(1.35, 0.28, 1.95)
	deck_box.mesh = d_mesh
	deck_box.position = Vector3(0, 0.14, 0)
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.14, 0.14, 0.20)
	d_mat.roughness = 0.4
	deck_box.material_override = d_mat
	deck_stack_node.add_child(deck_box)

	var deck_top_accent = MeshInstance3D.new()
	var dt_mesh = BoxMesh.new()
	dt_mesh.size = Vector3(1.18, 0.02, 1.76)
	deck_top_accent.mesh = dt_mesh
	deck_top_accent.position = Vector3(0, 0.29, 0)
	var dt_mat = StandardMaterial3D.new()
	dt_mat.albedo_color = Color(0.85, 0.18, 0.22)
	dt_mat.roughness = 0.3
	deck_top_accent.material_override = dt_mat
	deck_stack_node.add_child(deck_top_accent)

	var deck_title_3d = Label3D.new()
	deck_title_3d.text = "UNO"
	deck_title_3d.font_size = 56
	deck_title_3d.outline_size = 12
	deck_title_3d.modulate = Color(1.0, 0.86, 0.22)
	deck_title_3d.position = Vector3(0, 0.32, -0.18)
	deck_title_3d.rotation_degrees = Vector3(-90, 0, -15)
	deck_stack_node.add_child(deck_title_3d)

	deck_count_3d = Label3D.new()
	deck_count_3d.text = "۸۰ کارت"
	deck_count_3d.font_size = 38
	deck_count_3d.outline_size = 8
	deck_count_3d.modulate = Color.WHITE
	deck_count_3d.position = Vector3(0, 0.32, 0.48)
	deck_count_3d.rotation_degrees = Vector3(-90, 0, 0)
	deck_stack_node.add_child(deck_count_3d)

	var deck_body = StaticBody3D.new()
	var deck_col = CollisionShape3D.new()
	var deck_shape = BoxShape3D.new()
	deck_shape.size = Vector3(1.5, 0.5, 2.1)
	deck_col.shape = deck_shape
	deck_col.position = Vector3(0, 0.2, 0)
	deck_body.add_child(deck_col)
	deck_body.input_event.connect(func(_cam, event, _pos, _norm, _idx):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_draw_button_pressed()
	)
	deck_stack_node.add_child(deck_body)

	# 4. 3D Top Discard Card (Right of Center)
	var discard_node = Node3D.new()
	discard_node.position = Vector3(0.95, 0.20, -0.25)
	board_root.add_child(discard_node)

	var card_base = MeshInstance3D.new()
	var cb_mesh = BoxMesh.new()
	cb_mesh.size = Vector3(1.50, 0.06, 2.12)
	card_base.mesh = cb_mesh
	card_base.position = Vector3(0, 0.03, 0)
	var cb_mat = StandardMaterial3D.new()
	cb_mat.albedo_color = Color.WHITE
	cb_mat.roughness = 0.25
	card_base.material_override = cb_mat
	discard_node.add_child(card_base)

	top_card_mesh = MeshInstance3D.new()
	var tc_mesh = BoxMesh.new()
	tc_mesh.size = Vector3(1.34, 0.07, 1.94)
	top_card_mesh.mesh = tc_mesh
	top_card_mesh.position = Vector3(0, 0.04, 0)
	top_card_mat = StandardMaterial3D.new()
	top_card_mat.albedo_color = UNO_COLORS["red"]
	top_card_mat.roughness = 0.28
	top_card_mesh.material_override = top_card_mat
	discard_node.add_child(top_card_mesh)

	top_card_value_3d = Label3D.new()
	top_card_value_3d.text = "۷"
	top_card_value_3d.font_size = 96
	top_card_value_3d.outline_size = 16
	top_card_value_3d.modulate = Color.WHITE
	top_card_value_3d.position = Vector3(0, 0.10, -0.10)
	top_card_value_3d.rotation_degrees = Vector3(-90, 0, 0)
	discard_node.add_child(top_card_value_3d)

	top_card_sub_3d = Label3D.new()
	top_card_sub_3d.text = "قرمز"
	top_card_sub_3d.font_size = 40
	top_card_sub_3d.outline_size = 10
	top_card_sub_3d.modulate = Color(1.0, 0.96, 0.85)
	top_card_sub_3d.position = Vector3(0, 0.10, 0.62)
	top_card_sub_3d.rotation_degrees = Vector3(-90, 0, 0)
	discard_node.add_child(top_card_sub_3d)

	# 5. Opponent 3D Card Stacks around the Top/Sides of the Table
	# Seat 1 = Top, Seat 2 = Left, Seat 3 = Right
	var opp_positions = {
		1: Vector3(0.0, 0.22, -3.25),
		2: Vector3(-3.35, 0.22, -0.35),
		3: Vector3(3.35, 0.22, -0.35)
	}
	for seat_idx in opp_positions.keys():
		var holder = Node3D.new()
		holder.position = opp_positions[seat_idx]
		board_root.add_child(holder)

		var badge_lbl = Label3D.new()
		badge_lbl.name = "BadgeLabel"
		badge_lbl.text = ""
		badge_lbl.font_size = 44
		badge_lbl.outline_size = 12
		badge_lbl.modulate = Color(1.0, 0.92, 0.65)
		badge_lbl.position = Vector3(0, 0.35, 0)
		badge_lbl.rotation_degrees = Vector3(-75, 0, 0)
		holder.add_child(badge_lbl)

		var fan_container = Node3D.new()
		fan_container.name = "FanContainer"
		holder.add_child(fan_container)
		holder.visible = false
		opponent_stacks_3d[seat_idx] = holder

# ==============================================================================
# 2. 2D GAMER-FRIENDLY HUD & INTERACTIVE CARD DOCK
# ==============================================================================

func _build_2d_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# --- A. Compact Top-Center Table Status Bar (Below TopHeader) ---
	status_banner_panel = PanelContainer.new()
	status_banner_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_banner_panel.offset_left = -330
	status_banner_panel.offset_right = 330
	status_banner_panel.offset_top = 156
	status_banner_panel.offset_bottom = 252
	status_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.07, 0.09, 0.14, 0.92)
	sb_style.border_color = Color(0.83, 0.69, 0.38, 0.55)
	sb_style.set_border_width_all(2)
	sb_style.set_corner_radius_all(18)
	sb_style.content_margin_left = 16
	sb_style.content_margin_right = 16
	sb_style.content_margin_top = 8
	sb_style.content_margin_bottom = 8
	status_banner_panel.add_theme_stylebox_override("panel", sb_style)
	hud_root.add_child(status_banner_panel)

	var sb_vbox = VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 4)
	status_banner_panel.add_child(sb_vbox)

	var top_info_row = HBoxContainer.new()
	top_info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_info_row.add_theme_constant_override("separation", 14)
	sb_vbox.add_child(top_info_row)

	# Active Color Pill
	color_badge_panel = PanelContainer.new()
	color_badge_style = StyleBoxFlat.new()
	color_badge_style.bg_color = UNO_COLORS["red"]
	color_badge_style.set_corner_radius_all(12)
	color_badge_style.set_border_width_all(2)
	color_badge_style.border_color = Color.WHITE
	color_badge_style.content_margin_left = 14
	color_badge_style.content_margin_right = 14
	color_badge_style.content_margin_top = 4
	color_badge_style.content_margin_bottom = 4
	color_badge_panel.add_theme_stylebox_override("panel", color_badge_style)
	top_info_row.add_child(color_badge_panel)

	color_badge_label = Label.new()
	color_badge_label.text = "🔴 رنگ فعال: قرمز"
	color_badge_label.add_theme_font_size_override("font_size", 18)
	color_badge_label.add_theme_color_override("font_color", Color.WHITE)
	color_badge_panel.add_child(color_badge_label)

	direction_badge_label = Label.new()
	direction_badge_label.text = "↻ ساعتگرد"
	direction_badge_label.add_theme_font_size_override("font_size", 17)
	direction_badge_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	top_info_row.add_child(direction_badge_label)

	deck_badge_label = Label.new()
	deck_badge_label.text = "📚 دسته: ۸۰"
	deck_badge_label.add_theme_font_size_override("font_size", 17)
	deck_badge_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	top_info_row.add_child(deck_badge_label)

	action_toast_label = Label.new()
	action_toast_label.text = "کارت هم‌رنگ یا هم‌عدد با کارت وسط بازی کنید!"
	action_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_toast_label.add_theme_font_size_override("font_size", 16)
	action_toast_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	sb_vbox.add_child(action_toast_label)

	# --- B. Bottom Interactive Area (Above the 8-button BottomBar) ---
	var bottom_dock = VBoxContainer.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 14
	bottom_dock.offset_right = -14
	bottom_dock.offset_top = -410
	bottom_dock.offset_bottom = -118
	bottom_dock.add_theme_constant_override("separation", 8)
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	# 1. Action Controls Row (Draw Card, Pass Turn, Call UNO, Turn Status)
	var action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(action_row)

	# Draw Card Button
	draw_btn = Button.new()
	draw_btn.custom_minimum_size = Vector2(186, 52)
	draw_btn.text = "🃏 کشیدن کارت"
	draw_btn.focus_mode = Control.FOCUS_NONE
	draw_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	draw_btn.add_theme_font_size_override("font_size", 19)
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
	pass_btn.custom_minimum_size = Vector2(160, 52)
	pass_btn.text = "⏭️ رد نوبت"
	pass_btn.focus_mode = Control.FOCUS_NONE
	pass_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pass_btn.add_theme_font_size_override("font_size", 19)
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
	uno_btn.custom_minimum_size = Vector2(148, 52)
	uno_btn.text = "🔥 اونو! (UNO)"
	uno_btn.focus_mode = Control.FOCUS_NONE
	uno_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	uno_btn.add_theme_font_size_override("font_size", 19)
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
	hand_tray.custom_minimum_size = Vector2(0, 224)
	hand_tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tray_style = StyleBoxFlat.new()
	tray_style.bg_color = Color(0.06, 0.08, 0.13, 0.90)
	tray_style.border_color = Color(0.83, 0.69, 0.38, 0.50)
	tray_style.set_border_width_all(2)
	tray_style.set_corner_radius_all(20)
	tray_style.content_margin_left = 14
	tray_style.content_margin_right = 14
	tray_style.content_margin_top = 8
	tray_style.content_margin_bottom = 10
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
	turn_hint_label.add_theme_font_size_override("font_size", 17)
	turn_hint_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.62))
	tray_header.add_child(turn_hint_label)

	hand_count_badge = Label.new()
	hand_count_badge.text = "دست شما: ۷ کارت"
	hand_count_badge.add_theme_font_size_override("font_size", 17)
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

func _refresh_3d_centerpiece() -> void:
	var active_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])
	if color_ring_mat:
		color_ring_mat.albedo_color = active_col
		color_ring_mat.emission = active_col

	if direction_label_3d:
		direction_label_3d.text = "↻ جهت بازی: ساعتگرد" if direction == 1 else "↺ جهت بازی: پادساعتگرد"

	if deck_count_3d:
		deck_count_3d.text = "%s کارت" % _to_persian_digits(str(deck_remaining))

	if top_card_mat and not top_card.is_empty():
		var tc_color_key = String(top_card.get("color", current_color))
		var display_key = current_color if tc_color_key == "wild" else tc_color_key
		top_card_mat.albedo_color = UNO_COLORS.get(display_key, active_col)

	if top_card_value_3d and not top_card.is_empty():
		var val_str = String(top_card.get("value", "0"))
		top_card_value_3d.text = _format_card_center_text(val_str)

	if top_card_sub_3d:
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		top_card_sub_3d.text = "رنگ: " + cname

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
		var badge_lbl: Label3D = holder.get_node_or_null("BadgeLabel")
		if badge_lbl:
			var turn_prefix = "⏳ " if current_turn == pid else ""
			var uno_suffix = " 🔥UNO!" if c_count == 1 else ""
			badge_lbl.text = "%s%s: %s کارت%s" % [turn_prefix, p_name, _to_persian_digits(str(c_count)), uno_suffix]
			badge_lbl.modulate = Color(0.45, 1.0, 0.65) if current_turn == pid else Color(1.0, 0.92, 0.72)

		var fan_container: Node3D = holder.get_node_or_null("FanContainer")
		if fan_container:
			for child in fan_container.get_children():
				child.queue_free()
			var visible_cards = clampi(c_count, 0, 10)
			for c_idx in range(visible_cards):
				var mini_card = MeshInstance3D.new()
				var m_box = BoxMesh.new()
				m_box.size = Vector3(0.46, 0.03, 0.68)
				mini_card.mesh = m_box
				var spread = (float(c_idx) - float(visible_cards - 1) * 0.5) * 0.24
				mini_card.position = Vector3(spread, 0.02 * c_idx, 0)
				var m_mat = StandardMaterial3D.new()
				m_mat.albedo_color = Color(0.86, 0.16, 0.20) if c_count == 1 else Color(0.18, 0.22, 0.34)
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
				turn_hint_label.text = "🔵 کارت قابل بازی ندارید؛ روی «کشیدن کارت» بزنید"
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
	wrapper.custom_minimum_size = Vector2(114, 168)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(110, 152)
	btn.position = Vector2(2, 2 if playable else 16)
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
	corner_top.add_theme_font_size_override("font_size", 16)
	corner_top.add_theme_color_override("font_color", Color.WHITE)
	corner_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(corner_top)

	# Center White Oval with big symbol
	var center_oval = PanelContainer.new()
	center_oval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_oval.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var oval_style = StyleBoxFlat.new()
	oval_style.bg_color = Color(1.0, 1.0, 1.0, 0.94) if c_color != "wild" else Color(0.14, 0.14, 0.20, 0.95)
	oval_style.set_corner_radius_all(28)
	center_oval.add_theme_stylebox_override("panel", oval_style)
	vbox.add_child(center_oval)

	var center_lbl = Label.new()
	center_lbl.text = _format_card_center_text(c_value)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_lbl.add_theme_font_size_override("font_size", 34)
	center_lbl.add_theme_color_override("font_color", base_color if c_color != "wild" else Color(1.0, 0.88, 0.28))
	center_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_oval.add_child(center_lbl)

	# Bottom Subtitle (e.g., پرش نوبت / تغییر رنگ / عدد ۷)
	var bottom_lbl = Label.new()
	bottom_lbl.text = _format_card_subtitle_text(c_value)
	bottom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_lbl.add_theme_font_size_override("font_size", 13)
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
# 5. USER INTERACTIONS (PLAY CARD, WILD COLOR, DRAW, PASS, CALL UNO)
# ==============================================================================

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
	if game_data.has("gamers") and typeof(game_data["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(game_data["gamers"])
	var inner = game_data.get("game_data", game_data)
	if typeof(inner) == TYPE_DICTIONARY:
		_apply_uno_state_dict(inner)
	if game_data.has("user_data") and typeof(game_data["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(game_data["user_data"])

func _on_user_data_received(data: Dictionary) -> void:
	_apply_uno_state_dict(data)

func on_turn_data(payload: Dictionary) -> void:
	_apply_uno_state_dict(payload)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	current_turn = turn
	is_my_turn = (turn == GameManager.my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn
	if not is_my_turn:
		has_drawn_this_turn = false
		wild_modal_backdrop.visible = false
	_refresh_all_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"])
	var g_data = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_uno_state_dict(g_data)
	if payload.has("user_data") and typeof(payload["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(payload["user_data"])

func _on_uno_event_received(event_type: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var p: Dictionary = payload

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
	my_hand.clear()
	hands_count = {"1": 7, "2": 7, "3": 7, "4": 7}
	top_card.clear()
	has_drawn_this_turn = false
	pending_wild_card.clear()
	if wild_modal_backdrop:
		wild_modal_backdrop.visible = false
	_refresh_all_visuals()

func cleanup_board() -> void:
	if hud_layer and is_instance_valid(hud_layer):
		hud_layer.queue_free()
