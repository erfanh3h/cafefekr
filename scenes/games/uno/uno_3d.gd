class_name Uno3D
extends "res://scripts/games/base_game_board.gd"

# Uno3D - Complete Commercial Mobile UNO Gameplay Scene
# Hybrid 3D Tabletop + Responsive 2D Mobile UX Architecture:
# - UnoTable3D: Rich walnut & dark emerald 3D playing surface, 3D Draw Pile, 3D Discard Pile, 3D Color Gem
# - UnoOpponentSeat: Upper-table opponent pods with Avatar, Name, Card Count, Mini Fan & Turn Status
# - UnoCardWidget: Large, readable player hand cards with smooth raise-on-select & fly-to-discard animation
# - UnoVFXLayer: Card flight animations, special card effects (Reverse, Skip, +2, Wild, +4, UNO!), auto-hiding toast

const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")
const UnoCardWidgetScript = preload("res://scenes/games/uno/components/uno_card_widget.gd")
const UnoOpponentSeatScript = preload("res://scenes/games/uno/components/uno_opponent_seat.gd")
const UnoTable3DScript = preload("res://scenes/games/uno/components/uno_table_3d.gd")
const UnoVFXLayerScript = preload("res://scenes/games/uno/components/uno_vfx_layer.gd")

@export var default_three_quarter_view: bool = true
@export var has_missed_turns_limit: bool = true
@export var camera_pitch: float = -1.05    # ~ -60 deg elevated tabletop perspective showing board + surrounding props
@export var camera_distance: float = 2.74  # Balanced portrait mobile framing for the card mat & tabletop props

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

# --- Authoritative Backend State ---
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

# --- UI Interaction State ---
var selected_card_uid: int = -1
var pending_wild_card: Dictionary = {}
var _last_played_card_global_pos: Vector2 = Vector2.ZERO
var _match_started: bool = false
var _zoom_preset_idx: int = 0

# --- Modular Components ---
var table_3d: Node3D
var hud_layer: CanvasLayer
var hud_root: Control
var vfx_layer: Control

# Top Status & Opponent Seats
var turn_status_pill: PanelContainer
var turn_status_style: StyleBoxFlat
var turn_status_label: Label
var active_color_swatch: PanelContainer
var active_color_swatch_style: StyleBoxFlat
var active_color_label: Label
var direction_icon_label: Label
var zoom_btn: Button

var opponent_seats: Dictionary = {} # seat_slot (1=Top, 2=Left, 3=Right) -> UnoOpponentSeat
var _pid_to_seat_slot: Dictionary = {} # pid -> seat_slot

# Central Draw / Pass / UNO Controls
var draw_action_btn: Button
var draw_action_style: StyleBoxFlat
var pass_turn_btn: Button
var call_uno_btn: Button

# Bottom Player Hand Tray
var hand_tray_panel: PanelContainer
var hand_tray_style: StyleBoxFlat
var hand_phase_label: Label
var hand_playable_pill: PanelContainer
var hand_playable_label: Label
var sort_hand_btn: Button
var focus_playable_btn: Button
var hand_count_pill_label: Label
var hand_scroll: ScrollContainer
var hand_hbox: HBoxContainer
var _card_widgets_by_uid: Dictionary = {}
var _uno_btn_pulse_time: float = 0.0

# Wild Color Selection Modal
var wild_modal_backdrop: ColorRect
var wild_modal_card_box: PanelContainer
var wild_modal_title: Label

func _ready() -> void:
	game_type = GameTypes.UNO
	_build_3d_table()
	_build_2d_interface()
	super._ready()
	_connect_uno_signals()
	_refresh_all_visuals()
	_update_hud_visibility()

func _process(delta: float) -> void:
	_update_hud_visibility()
	if is_instance_valid(call_uno_btn) and call_uno_btn.visible:
		_uno_btn_pulse_time += delta * 6.0
		var s = 1.0 + sin(_uno_btn_pulse_time) * 0.045
		call_uno_btn.scale = Vector2(s, s)
	elif is_instance_valid(call_uno_btn):
		call_uno_btn.scale = Vector2.ONE

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
# HUD OVERLAY PROTECTION (Never render HUD over StartGameOverlay or GameResultDialog)
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
# 1. 3D TABLETOP SETUP
# ==============================================================================

func _build_3d_table() -> void:
	table_3d = UnoTable3DScript.new()
	table_3d.name = "UnoTable3D"
	table_3d.draw_pile_clicked.connect(_on_draw_button_pressed)
	table_3d.uno_bell_clicked.connect(_on_3d_uno_bell_clicked)
	add_child(table_3d)

# ==============================================================================
# 2. RESPONSIVE 2D MOBILE INTERFACE
# ==============================================================================

func _build_2d_interface() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "UnoHUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	hud_layer.add_child(hud_root)

	# --- A. Clean Turn & Active Color Status Bar (Below TopHeader at y = 338px) ---
	turn_status_pill = PanelContainer.new()
	turn_status_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_status_pill.offset_left = -350.0
	turn_status_pill.offset_right = 350.0
	turn_status_pill.offset_top = 338.0
	turn_status_pill.offset_bottom = 392.0
	turn_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	turn_status_style = StyleBoxFlat.new()
	turn_status_style.bg_color = Color(0.07, 0.11, 0.09, 0.94)
	turn_status_style.border_color = Color(0.82, 0.68, 0.32, 0.65)
	turn_status_style.set_border_width_all(2)
	turn_status_style.set_corner_radius_all(24)
	turn_status_style.shadow_color = Color(0, 0, 0, 0.40)
	turn_status_style.shadow_size = 8
	turn_status_style.content_margin_left = 16
	turn_status_style.content_margin_right = 16
	turn_status_style.content_margin_top = 5
	turn_status_style.content_margin_bottom = 5
	turn_status_pill.add_theme_stylebox_override("panel", turn_status_style)
	hud_root.add_child(turn_status_pill)

	var status_hbox = HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.add_theme_constant_override("separation", 14)
	status_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_status_pill.add_child(status_hbox)

	# Active Color Swatch Pill
	active_color_swatch = PanelContainer.new()
	active_color_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_color_swatch_style = StyleBoxFlat.new()
	active_color_swatch_style.bg_color = UNO_COLORS["red"]
	active_color_swatch_style.border_color = Color.WHITE
	active_color_swatch_style.set_border_width_all(2)
	active_color_swatch_style.set_corner_radius_all(14)
	active_color_swatch_style.content_margin_left = 12
	active_color_swatch_style.content_margin_right = 12
	active_color_swatch_style.content_margin_top = 2
	active_color_swatch_style.content_margin_bottom = 2
	active_color_swatch.add_theme_stylebox_override("panel", active_color_swatch_style)
	status_hbox.add_child(active_color_swatch)

	active_color_label = Label.new()
	active_color_label.text = "رنگ: قرمز"
	active_color_label.add_theme_font_override("font", FontHekayat)
	active_color_label.add_theme_font_size_override("font_size", 21)
	active_color_label.add_theme_color_override("font_color", Color.WHITE)
	active_color_swatch.add_child(active_color_label)

	# Turn Owner Text
	turn_status_label = Label.new()
	turn_status_label.text = "🟢 نوبت شماست"
	turn_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_status_label.add_theme_font_override("font", FontHekayat)
	turn_status_label.add_theme_font_size_override("font_size", 23)
	turn_status_label.add_theme_color_override("font_color", Color(0.42, 0.98, 0.62))
	status_hbox.add_child(turn_status_label)

	# Direction Badge
	direction_icon_label = Label.new()
	direction_icon_label.text = "↻ ساعتگرد"
	direction_icon_label.add_theme_font_override("font", FontHekayat)
	direction_icon_label.add_theme_font_size_override("font_size", 20)
	direction_icon_label.add_theme_color_override("font_color", Color(0.94, 0.86, 0.64))
	status_hbox.add_child(direction_icon_label)

	# Camera Framing Toggle
	zoom_btn = Button.new()
	zoom_btn.custom_minimum_size = Vector2(78, 30)
	zoom_btn.text = "🔍 نما"
	zoom_btn.focus_mode = Control.FOCUS_NONE
	zoom_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zoom_btn.add_theme_font_override("font", FontHekayat)
	zoom_btn.add_theme_font_size_override("font_size", 19)
	zoom_btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	var z_st = StyleBoxFlat.new()
	z_st.bg_color = Color(0.14, 0.18, 0.16, 0.95)
	z_st.border_color = Color(0.80, 0.66, 0.32, 0.65)
	z_st.set_border_width_all(1)
	z_st.set_corner_radius_all(10)
	zoom_btn.add_theme_stylebox_override("normal", z_st)
	zoom_btn.add_theme_stylebox_override("hover", z_st)
	zoom_btn.add_theme_stylebox_override("pressed", z_st)
	zoom_btn.pressed.connect(_on_zoom_cycle_pressed)
	status_hbox.add_child(zoom_btn)

	# --- B. Opponent Table Seats Row (Upper Side of the Playing Area) ---
	var opp_row = HBoxContainer.new()
	opp_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	opp_row.offset_left = 16.0
	opp_row.offset_right = -16.0
	opp_row.offset_top = 400.0
	opp_row.offset_bottom = 476.0
	opp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_row.add_theme_constant_override("separation", 10)
	opp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(opp_row)

	# Create Left (2), Top (1), Right (3) Opponent Seats
	for s_slot in [2, 1, 3]:
		var seat = UnoOpponentSeatScript.new()
		seat.seat_slot = s_slot
		seat.visible = false
		opp_row.add_child(seat)
		opponent_seats[s_slot] = seat

	# --- C. Bottom Player Hand & Action Dock (Strictly above BottomBar at -158px) ---
	var bottom_dock = VBoxContainer.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 12.0
	bottom_dock.offset_right = -12.0
	bottom_dock.offset_top = -492.0
	bottom_dock.offset_bottom = -160.0
	bottom_dock.add_theme_constant_override("separation", 8)
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	# 1. Contextual Action Controls Row (Draw Pile Action, Pass Turn, Call UNO!)
	var action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 14)
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(action_row)

	# Draw Card Button (Visually paired with the Draw Pile)
	draw_action_btn = Button.new()
	draw_action_btn.custom_minimum_size = Vector2(204, 50)
	draw_action_btn.text = "🃏 کشیدن از دسته"
	draw_action_btn.focus_mode = Control.FOCUS_NONE
	draw_action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	draw_action_btn.add_theme_font_override("font", FontHekayat)
	draw_action_btn.add_theme_font_size_override("font_size", 24)
	draw_action_btn.add_theme_color_override("font_color", Color.WHITE)
	draw_action_style = StyleBoxFlat.new()
	draw_action_style.bg_color = Color(0.12, 0.38, 0.26, 0.96)
	draw_action_style.border_color = Color(0.86, 0.72, 0.34)
	draw_action_style.set_border_width_all(2)
	draw_action_style.set_corner_radius_all(16)
	draw_action_style.shadow_color = Color(0, 0, 0, 0.42)
	draw_action_style.shadow_size = 8
	draw_action_btn.add_theme_stylebox_override("normal", draw_action_style)
	draw_action_btn.add_theme_stylebox_override("hover", draw_action_style)
	draw_action_btn.add_theme_stylebox_override("pressed", draw_action_style)
	var draw_dis = draw_action_style.duplicate()
	draw_dis.bg_color = Color(0.12, 0.15, 0.14, 0.65)
	draw_dis.border_color = Color(0.40, 0.42, 0.40, 0.40)
	draw_action_btn.add_theme_stylebox_override("disabled", draw_dis)
	draw_action_btn.pressed.connect(_on_draw_button_pressed)
	action_row.add_child(draw_action_btn)

	# Pass Turn Button (Appears after drawing a card)
	pass_turn_btn = Button.new()
	pass_turn_btn.custom_minimum_size = Vector2(164, 50)
	pass_turn_btn.text = "⏭️ رد نوبت"
	pass_turn_btn.focus_mode = Control.FOCUS_NONE
	pass_turn_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pass_turn_btn.add_theme_font_override("font", FontHekayat)
	pass_turn_btn.add_theme_font_size_override("font_size", 24)
	pass_turn_btn.add_theme_color_override("font_color", Color.WHITE)
	var pass_st = StyleBoxFlat.new()
	pass_st.bg_color = Color(0.78, 0.42, 0.10, 0.96)
	pass_st.border_color = Color(1.0, 0.82, 0.36)
	pass_st.set_border_width_all(2)
	pass_st.set_corner_radius_all(16)
	pass_st.shadow_color = Color(0, 0, 0, 0.42)
	pass_st.shadow_size = 8
	pass_turn_btn.add_theme_stylebox_override("normal", pass_st)
	pass_turn_btn.add_theme_stylebox_override("hover", pass_st)
	pass_turn_btn.add_theme_stylebox_override("pressed", pass_st)
	pass_turn_btn.visible = false
	pass_turn_btn.pressed.connect(_on_pass_button_pressed)
	action_row.add_child(pass_turn_btn)

	# UNO Shout Button
	call_uno_btn = Button.new()
	call_uno_btn.custom_minimum_size = Vector2(158, 50)
	call_uno_btn.text = "🔥 اعلام اونو!"
	call_uno_btn.focus_mode = Control.FOCUS_NONE
	call_uno_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	call_uno_btn.add_theme_font_override("font", FontHekayat)
	call_uno_btn.add_theme_font_size_override("font_size", 24)
	call_uno_btn.add_theme_color_override("font_color", Color.WHITE)
	var uno_st = StyleBoxFlat.new()
	uno_st.bg_color = Color(0.90, 0.16, 0.19, 0.98)
	uno_st.border_color = Color(1.0, 0.88, 0.25)
	uno_st.set_border_width_all(3)
	uno_st.set_corner_radius_all(16)
	uno_st.shadow_color = Color(0.90, 0.16, 0.19, 0.50)
	uno_st.shadow_size = 10
	call_uno_btn.add_theme_stylebox_override("normal", uno_st)
	call_uno_btn.add_theme_stylebox_override("hover", uno_st)
	call_uno_btn.add_theme_stylebox_override("pressed", uno_st)
	call_uno_btn.visible = false
	call_uno_btn.pressed.connect(_on_uno_button_pressed)
	action_row.add_child(call_uno_btn)

	# 2. Premium Walnut & Emerald Player Card Tray
	hand_tray_panel = PanelContainer.new()
	hand_tray_panel.custom_minimum_size = Vector2(0, 268)
	hand_tray_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_tray_style = StyleBoxFlat.new()
	hand_tray_style.bg_color = Color(0.06, 0.11, 0.09, 0.94)
	hand_tray_style.border_color = Color(0.82, 0.68, 0.32, 0.62)
	hand_tray_style.set_border_width_all(2)
	hand_tray_style.set_corner_radius_all(24)
	hand_tray_style.shadow_color = Color(0, 0, 0, 0.50)
	hand_tray_style.shadow_size = 12
	hand_tray_style.content_margin_left = 14
	hand_tray_style.content_margin_right = 14
	hand_tray_style.content_margin_top = 8
	hand_tray_style.content_margin_bottom = 8
	hand_tray_panel.add_theme_stylebox_override("panel", hand_tray_style)
	bottom_dock.add_child(hand_tray_panel)

	var tray_vbox = VBoxContainer.new()
	tray_vbox.add_theme_constant_override("separation", 2)
	tray_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_tray_panel.add_child(tray_vbox)

	var tray_header = HBoxContainer.new()
	tray_header.add_theme_constant_override("separation", 8)
	tray_vbox.add_child(tray_header)

	sort_hand_btn = Button.new()
	sort_hand_btn.custom_minimum_size = Vector2(96, 32)
	sort_hand_btn.text = "🔀 مرتب"
	sort_hand_btn.focus_mode = Control.FOCUS_NONE
	sort_hand_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sort_hand_btn.add_theme_font_override("font", FontHekayat)
	sort_hand_btn.add_theme_font_size_override("font_size", 19)
	sort_hand_btn.add_theme_color_override("font_color", Color(0.98, 0.92, 0.72))
	var sort_st = StyleBoxFlat.new()
	sort_st.bg_color = Color(0.13, 0.19, 0.16, 0.95)
	sort_st.border_color = Color(0.78, 0.64, 0.30, 0.70)
	sort_st.set_border_width_all(1)
	sort_st.set_corner_radius_all(10)
	sort_hand_btn.add_theme_stylebox_override("normal", sort_st)
	sort_hand_btn.add_theme_stylebox_override("hover", sort_st)
	sort_hand_btn.add_theme_stylebox_override("pressed", sort_st)
	sort_hand_btn.pressed.connect(_on_sort_hand_pressed)
	tray_header.add_child(sort_hand_btn)

	focus_playable_btn = Button.new()
	focus_playable_btn.custom_minimum_size = Vector2(102, 32)
	focus_playable_btn.text = "💡 مجاز"
	focus_playable_btn.focus_mode = Control.FOCUS_NONE
	focus_playable_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_playable_btn.add_theme_font_override("font", FontHekayat)
	focus_playable_btn.add_theme_font_size_override("font_size", 19)
	focus_playable_btn.add_theme_color_override("font_color", Color(0.45, 0.98, 0.65))
	var fp_st = sort_st.duplicate()
	fp_st.bg_color = Color(0.08, 0.24, 0.15, 0.96)
	fp_st.border_color = Color(0.38, 0.96, 0.58, 0.85)
	focus_playable_btn.add_theme_stylebox_override("normal", fp_st)
	focus_playable_btn.add_theme_stylebox_override("hover", fp_st)
	focus_playable_btn.add_theme_stylebox_override("pressed", fp_st)
	focus_playable_btn.visible = false
	focus_playable_btn.pressed.connect(_on_focus_next_playable_pressed)
	tray_header.add_child(focus_playable_btn)

	hand_phase_label = Label.new()
	hand_phase_label.text = "روی کارت بزنید تا انتخاب و بازی شود"
	hand_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_phase_label.clip_text = true
	hand_phase_label.add_theme_font_override("font", FontHekayat)
	hand_phase_label.add_theme_font_size_override("font_size", 21)
	hand_phase_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.82))
	tray_header.add_child(hand_phase_label)

	hand_playable_pill = PanelContainer.new()
	hand_playable_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_st = StyleBoxFlat.new()
	hp_st.bg_color = Color(0.08, 0.22, 0.14, 0.95)
	hp_st.border_color = Color(0.36, 0.92, 0.56, 0.72)
	hp_st.set_border_width_all(1)
	hp_st.set_corner_radius_all(10)
	hp_st.content_margin_left = 10
	hp_st.content_margin_right = 10
	hp_st.content_margin_top = 2
	hp_st.content_margin_bottom = 2
	hand_playable_pill.add_theme_stylebox_override("panel", hp_st)
	hand_playable_pill.visible = false
	tray_header.add_child(hand_playable_pill)

	hand_playable_label = Label.new()
	hand_playable_label.text = "✨ ۰ مجاز"
	hand_playable_label.add_theme_font_override("font", FontHekayat)
	hand_playable_label.add_theme_font_size_override("font_size", 19)
	hand_playable_label.add_theme_color_override("font_color", Color(0.45, 0.98, 0.65))
	hand_playable_pill.add_child(hand_playable_label)

	hand_count_pill_label = Label.new()
	hand_count_pill_label.text = "دست شما: ۷ کارت"
	hand_count_pill_label.add_theme_font_override("font", FontHekayat)
	hand_count_pill_label.add_theme_font_size_override("font_size", 21)
	hand_count_pill_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.52))
	tray_header.add_child(hand_count_pill_label)

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
	hand_hbox.add_theme_constant_override("separation", 12)
	hand_scroll.add_child(hand_hbox)

	# --- D. Animation & Contextual Notification Layer ---
	vfx_layer = UnoVFXLayerScript.new()
	hud_root.add_child(vfx_layer)

	# --- E. Compact, Elegant Wild Color Selection Panel ---
	_build_wild_color_modal()

func _build_wild_color_modal() -> void:
	wild_modal_backdrop = ColorRect.new()
	wild_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	wild_modal_backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	wild_modal_backdrop.visible = false
	wild_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(wild_modal_backdrop)

	var center_box = CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	wild_modal_backdrop.add_child(center_box)

	wild_modal_card_box = PanelContainer.new()
	wild_modal_card_box.custom_minimum_size = Vector2(456, 356)
	wild_modal_card_box.pivot_offset = Vector2(228, 178)
	var m_style = StyleBoxFlat.new()
	m_style.bg_color = Color(0.08, 0.13, 0.10, 0.98)
	m_style.border_color = Color(0.88, 0.72, 0.34)
	m_style.set_border_width_all(3)
	m_style.set_corner_radius_all(28)
	m_style.shadow_color = Color(0, 0, 0, 0.65)
	m_style.shadow_size = 20
	m_style.content_margin_left = 24
	m_style.content_margin_right = 24
	m_style.content_margin_top = 20
	m_style.content_margin_bottom = 20
	wild_modal_card_box.add_theme_stylebox_override("panel", m_style)
	center_box.add_child(wild_modal_card_box)

	var m_vbox = VBoxContainer.new()
	m_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m_vbox.add_theme_constant_override("separation", 16)
	wild_modal_card_box.add_child(m_vbox)

	wild_modal_title = Label.new()
	wild_modal_title.text = "🎨 رنگ فعال بعدی را انتخاب کنید"
	wild_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wild_modal_title.add_theme_font_override("font", FontHekayat)
	wild_modal_title.add_theme_font_size_override("font_size", 27)
	wild_modal_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	m_vbox.add_child(wild_modal_title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	m_vbox.add_child(grid)

	var color_choices = [
		{"key": "red", "label": "🔴 قرمز"},
		{"key": "yellow", "label": "🟡 زرد"},
		{"key": "green", "label": "🟢 سبز"},
		{"key": "blue", "label": "🔵 آبی"}
	]
	for item in color_choices:
		var c_key: String = item["key"]
		var c_btn = Button.new()
		c_btn.custom_minimum_size = Vector2(194, 84)
		c_btn.text = item["label"]
		c_btn.focus_mode = Control.FOCUS_NONE
		c_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		c_btn.add_theme_font_override("font", FontHekayat)
		c_btn.add_theme_font_size_override("font_size", 29)
		c_btn.add_theme_color_override("font_color", Color.WHITE if c_key != "yellow" else Color(0.14, 0.11, 0.04))

		var c_style = StyleBoxFlat.new()
		c_style.bg_color = UNO_COLORS[c_key]
		c_style.border_color = Color.WHITE
		c_style.set_border_width_all(4)
		c_style.set_corner_radius_all(20)
		c_style.shadow_color = UNO_COLORS[c_key].darkened(0.3)
		c_style.shadow_size = 8
		c_btn.add_theme_stylebox_override("normal", c_style)
		c_btn.add_theme_stylebox_override("hover", c_style)
		c_btn.add_theme_stylebox_override("pressed", c_style)
		c_btn.pressed.connect(func(): _on_wild_color_chosen(c_key))
		grid.add_child(c_btn)

	var cancel_btn = Button.new()
	cancel_btn.custom_minimum_size = Vector2(160, 42)
	cancel_btn.text = "انصراف"
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.add_theme_font_override("font", FontHekayat)
	cancel_btn.add_theme_font_size_override("font_size", 21)
	var cancel_st = StyleBoxFlat.new()
	cancel_st.bg_color = Color(0.16, 0.20, 0.18)
	cancel_st.border_color = Color(0.65, 0.68, 0.65, 0.6)
	cancel_st.set_border_width_all(1)
	cancel_st.set_corner_radius_all(12)
	cancel_btn.add_theme_stylebox_override("normal", cancel_st)
	cancel_btn.add_theme_stylebox_override("hover", cancel_st)
	cancel_btn.add_theme_stylebox_override("pressed", cancel_st)
	cancel_btn.pressed.connect(func():
		pending_wild_card.clear()
		wild_modal_backdrop.visible = false
	)
	m_vbox.add_child(cancel_btn)

# ==============================================================================
# 3. CARD PLAYABILITY & STATE HELPERS
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

func _get_player_short_name(pid: int) -> String:
	if pid == my_player_index:
		return "شما"
	var p_data = GameManager.get_player_data_by_gamer_id(pid)
	if not p_data.is_empty():
		var n = String(p_data.get("name", p_data.get("username", "")))
		if not n.is_empty():
			return n
	return "بازیکن %s" % UnoCardWidgetScript.to_fa_digits(str(pid))

func _get_player_avatar_id(pid: int) -> int:
	var p_data = GameManager.get_player_data_by_gamer_id(pid)
	if not p_data.is_empty():
		return int(p_data.get("image", p_data.get("user_image", 0)))
	return 0

# ==============================================================================
# 4. VISUAL SYNCHRONIZATION (3D TABLE, OPPONENTS, STATUS BAR, PLAYER HAND)
# ==============================================================================

func _refresh_all_visuals() -> void:
	my_player_index = GameManager.my_player_index
	current_turn = GameManager.current_turn
	is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active

	var any_playable = _has_any_playable_card()
	var highlight_draw = is_my_turn and (not has_drawn_this_turn) and (not any_playable)

	if is_instance_valid(table_3d):
		table_3d.update_table_state(top_card, current_color, direction, deck_remaining, highlight_draw)

	_refresh_opponents()
	_refresh_status_bar()
	_refresh_hand_dock(any_playable, highlight_draw)
	_refresh_top_header_badges()
	_update_hud_visibility()

func _refresh_opponents() -> void:
	var total_p = clampi(max(2, GameManager.match_players.size()), 2, 4)
	players_count = total_p
	_pid_to_seat_slot.clear()

	for s_slot in opponent_seats.keys():
		opponent_seats[s_slot].visible = false

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

	var seat_counts_3d: Dictionary = {}
	var active_seat_3d: int = 0

	for i in range(other_pids.size()):
		var pid = other_pids[i]
		var s_slot = seat_mapping[i]
		_pid_to_seat_slot[pid] = s_slot

		var c_count = int(hands_count.get(str(pid), hands_count.get(pid, 7)))
		var is_opp_turn = (current_turn == pid) and GameManager.is_game_active
		var r_place = 1 if rank1_player == pid else (2 if rank2_player == pid else 0)

		seat_counts_3d[s_slot] = c_count
		if is_opp_turn:
			active_seat_3d = s_slot

		var seat_ui = opponent_seats.get(s_slot)
		if is_instance_valid(seat_ui):
			seat_ui.visible = true
			seat_ui.update_opponent(
				pid,
				_get_player_short_name(pid),
				_get_player_avatar_id(pid),
				c_count,
				is_opp_turn,
				r_place
			)

	if is_instance_valid(table_3d):
		table_3d.update_3d_opponent_fans(seat_counts_3d, active_seat_3d)

func _refresh_status_bar() -> void:
	var act_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])
	if active_color_swatch_style:
		active_color_swatch_style.bg_color = act_col
	if active_color_label:
		active_color_label.text = "رنگ: " + UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		active_color_label.add_theme_color_override("font_color", Color.WHITE if current_color != "yellow" else Color(0.14, 0.11, 0.04))

	if direction_icon_label:
		direction_icon_label.text = "↻ ساعتگرد" if direction == 1 else "↺ پادساعتگرد"

	if turn_status_label:
		if rank1_player == my_player_index:
			turn_status_label.text = "👑 شما نفر اول شدید!"
			turn_status_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
			turn_status_style.border_color = Color(1.0, 0.86, 0.28, 0.85)
		elif is_my_turn:
			turn_status_label.text = "🟢 نوبت شماست"
			turn_status_label.add_theme_color_override("font_color", Color(0.42, 0.98, 0.62))
			turn_status_style.border_color = Color(0.38, 0.96, 0.58, 0.88)
		else:
			turn_status_label.text = "⏳ نوبت %s" % _get_player_short_name(current_turn)
			turn_status_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
			turn_status_style.border_color = Color(0.82, 0.68, 0.32, 0.55)

func _refresh_hand_dock(any_playable: bool, highlight_draw: bool) -> void:
	if not is_instance_valid(hand_hbox):
		return
	for ch in hand_hbox.get_children():
		ch.queue_free()
	_card_widgets_by_uid.clear()

	var my_count = my_hand.size()
	var playable_count: int = 0
	for c in my_hand:
		if typeof(c) == TYPE_DICTIONARY and _is_card_playable(c):
			playable_count += 1

	if hand_count_pill_label:
		hand_count_pill_label.text = "%s کارت" % UnoCardWidgetScript.to_fa_digits(str(my_count))

	if is_instance_valid(hand_playable_pill) and is_instance_valid(hand_playable_label):
		hand_playable_pill.visible = is_my_turn and playable_count > 0
		hand_playable_label.text = "✨ %s مجاز" % UnoCardWidgetScript.to_fa_digits(str(playable_count))

	if is_instance_valid(focus_playable_btn):
		focus_playable_btn.visible = is_my_turn and playable_count > 0 and my_count >= 5

	if hand_phase_label:
		if rank1_player == my_player_index:
			hand_phase_label.text = "👑 تمام کارت‌های شما بازی شد!"
			hand_phase_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif is_my_turn:
			if any_playable:
				hand_phase_label.text = "کارت روشن را لمس کنید؛ با لمس مجدد بازی می‌شود"
				hand_phase_label.add_theme_color_override("font_color", Color(0.45, 0.98, 0.65))
			elif has_drawn_this_turn:
				hand_phase_label.text = "کارت قابل بازی ندارید؛ روی «رد نوبت» بزنید"
				hand_phase_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
			else:
				hand_phase_label.text = "کارت قابل بازی ندارید؛ از دسته وسط کارت بکشید"
				hand_phase_label.add_theme_color_override("font_color", Color(0.62, 0.88, 1.0))
		else:
			hand_phase_label.text = "کارت‌های خود را بررسی کنید"
			hand_phase_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.76))

	if hand_tray_style:
		hand_tray_style.border_color = Color(0.38, 0.96, 0.58, 0.85) if is_my_turn else Color(0.82, 0.68, 0.32, 0.55)

	# Update Draw / Pass / UNO Buttons & 3D UNO Bell Alert
	if draw_action_btn:
		draw_action_btn.disabled = (not is_my_turn) or has_drawn_this_turn or is_board_locked
		if highlight_draw:
			draw_action_btn.text = "🃏 کشیدن کارت (نوبت شما)"
			draw_action_style.bg_color = Color(0.16, 0.54, 0.34, 0.98)
			draw_action_style.border_color = Color(1.0, 0.90, 0.35)
		else:
			draw_action_btn.text = "🃏 کشیدن از دسته"
			draw_action_style.bg_color = Color(0.12, 0.38, 0.26, 0.96)
			draw_action_style.border_color = Color(0.86, 0.72, 0.34)

	if pass_turn_btn:
		pass_turn_btn.visible = is_my_turn and has_drawn_this_turn

	var already_called = bool(uno_called.get(str(my_player_index), uno_called.get(my_player_index, false)))
	var can_uno_now = (my_count <= 2 and my_count >= 1 and not already_called)
	if call_uno_btn:
		call_uno_btn.visible = can_uno_now
		call_uno_btn.pivot_offset = call_uno_btn.size * 0.5
	if is_instance_valid(table_3d) and table_3d.has_method("set_uno_bell_alert"):
		table_3d.set_uno_bell_alert(can_uno_now)

	# Keep selection valid if card still exists in hand
	var still_has_selected = false
	for card in my_hand:
		if typeof(card) == TYPE_DICTIONARY and int(card.get("uid", -1)) == selected_card_uid:
			still_has_selected = true
			break
	if not still_has_selected:
		selected_card_uid = -1

	# Populate Player Hand with UnoCardWidget instances
	for card in my_hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var uid = int(card.get("uid", -1))
		var playable = _is_card_playable(card)
		var is_sel = (uid == selected_card_uid)
		var widget = UnoCardWidgetScript.new()
		widget.setup_card(card, playable, is_sel, is_my_turn)
		widget.card_tapped.connect(_on_hand_card_tapped)
		widget.card_play_confirmed.connect(_on_hand_card_play_confirmed)
		hand_hbox.add_child(widget)
		_card_widgets_by_uid[uid] = widget

func _refresh_top_header_badges() -> void:
	var hud = get_tree().get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = get_tree().root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var header = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
		if is_instance_valid(header) and header.has_method("update_uno_hands"):
			header.update_uno_hands(_get_hands_count_array(), rank1_player, rank2_player)

# ==============================================================================
# 5. USER INTERACTIONS (SELECT CARD, PLAY CARD, WILD COLOR, DRAW, PASS, UNO)
# ==============================================================================

func _on_hand_card_tapped(card_uid: int, card_data: Dictionary, widget: Control) -> void:
	selected_card_uid = card_uid
	for uid in _card_widgets_by_uid.keys():
		var w = _card_widgets_by_uid[uid]
		if is_instance_valid(w):
			w.set_selected_state(uid == card_uid, true)

	if is_my_turn and not _is_card_playable(card_data):
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("کارت هم‌رنگ (%s) یا هم‌نماد با کارت وسط بازی کنید" % cname, Color(0.95, 0.45, 0.45), 1.8)
	elif is_instance_valid(widget):
		_last_played_card_global_pos = widget.global_position + widget.size * 0.5

func _on_hand_card_play_confirmed(card_uid: int, card_data: Dictionary, widget: Control) -> void:
	if not is_my_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("الان نوبت شما نیست!", Color(0.95, 0.45, 0.45), 1.6)
		return
	if is_board_locked:
		return
	if not _is_card_playable(card_data):
		var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("این کارت قابل بازی نیست (رنگ فعال: %s)" % cname, Color(0.95, 0.45, 0.45), 1.8)
		return

	if is_instance_valid(widget):
		_last_played_card_global_pos = widget.global_position + widget.size * 0.5

	var c_color = String(card_data.get("color", ""))
	var c_val = String(card_data.get("value", ""))
	if c_color == "wild" or c_val in ["wild", "wild_draw4"]:
		pending_wild_card = card_data.duplicate(true)
		var is_plus4 = (c_val == "wild_draw4")
		if wild_modal_title:
			wild_modal_title.text = "🎨 رنگ بعدی را برای «%s» انتخاب کنید" % ("آزاد +۴" if is_plus4 else "تغییر رنگ")
		wild_modal_backdrop.visible = true
		if is_instance_valid(wild_modal_card_box):
			wild_modal_card_box.scale = Vector2(0.82, 0.82)
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(wild_modal_card_box, "scale", Vector2.ONE, 0.20)
		return

	_send_play_card(card_uid, c_color, card_data)

func _on_wild_color_chosen(chosen_color: String) -> void:
	wild_modal_backdrop.visible = false
	if pending_wild_card.is_empty():
		return
	var c_uid = int(pending_wild_card.get("uid", -1))
	var card_copy = pending_wild_card.duplicate(true)
	pending_wild_card.clear()
	if c_uid >= 0:
		_send_play_card(c_uid, chosen_color, card_copy)

func _send_play_card(card_uid: int, chosen_color: String, card_data: Dictionary) -> void:
	set_board_locked(true)
	selected_card_uid = -1
	if is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
		var from_pos = _last_played_card_global_pos if _last_played_card_global_pos != Vector2.ZERO else Vector2(540, 1520)
		var to_pos = table_3d.get_discard_pile_screen_pos()
		vfx_layer.animate_card_flight(from_pos, to_pos, card_data, true, 0.26)
	send_move(Commands.Play_Card, {
		"card_uid": card_uid,
		"chosen_color": chosen_color
	})

func _on_draw_button_pressed() -> void:
	if not is_my_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("الان نوبت شما نیست!", Color(0.95, 0.45, 0.45), 1.6)
		return
	if is_board_locked:
		return
	if has_drawn_this_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("در این نوبت قبلاً کارت کشیده‌اید", Color(1.0, 0.82, 0.32), 1.6)
		return
	set_board_locked(true)
	if is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
		var from_pos = table_3d.get_draw_pile_screen_pos()
		var to_pos = hand_tray_panel.global_position + hand_tray_panel.size * 0.5 if is_instance_valid(hand_tray_panel) else Vector2(540, 1540)
		vfx_layer.animate_card_flight(from_pos, to_pos, {}, false, 0.28)
	send_move(Commands.Draw_Card, {})

func _on_pass_button_pressed() -> void:
	if not is_my_turn or not has_drawn_this_turn:
		return
	set_board_locked(true)
	send_move(Commands.Pass_Turn, {})

func _on_uno_button_pressed() -> void:
	send_move(Commands.Call_Uno, {})
	call_uno_btn.visible = false
	if is_instance_valid(table_3d) and table_3d.has_method("set_uno_bell_alert"):
		table_3d.set_uno_bell_alert(false)
		table_3d.animate_uno_bell_tap()
	if is_instance_valid(vfx_layer):
		vfx_layer.play_special_effect_badge("🔥 UNO!", UNO_COLORS["red"], 1.35)
		vfx_layer.show_contextual_toast("🔥 شما «اونو!» اعلام کردید", Color(1.0, 0.86, 0.28), 2.0)

func _on_3d_uno_bell_clicked() -> void:
	var my_count = my_hand.size()
	var already_called = bool(uno_called.get(str(my_player_index), uno_called.get(my_player_index, false)))
	if my_count <= 2 and my_count >= 1 and not already_called:
		_on_uno_button_pressed()
	elif is_instance_valid(vfx_layer):
		vfx_layer.show_contextual_toast("🔔 زنگ اونو! وقتی ۱ یا ۲ کارت داشتید بزنید", Color(0.98, 0.86, 0.42), 1.9)

func _on_sort_hand_pressed() -> void:
	if my_hand.size() <= 1:
		return
	var color_rank = {"red": 0, "yellow": 1, "green": 2, "blue": 3, "wild": 4}
	var val_rank = {
		"0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9,
		"skip": 10, "reverse": 11, "draw2": 12, "wild": 13, "wild_draw4": 14
	}
	my_hand.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		var ca = String(a.get("color", "wild"))
		var cb = String(b.get("color", "wild"))
		var va = String(a.get("value", "0"))
		var vb = String(b.get("value", "0"))
		if va in ["wild", "wild_draw4"]:
			ca = "wild"
		if vb in ["wild", "wild_draw4"]:
			cb = "wild"
		var ra = int(color_rank.get(ca, 5))
		var rb = int(color_rank.get(cb, 5))
		if ra != rb:
			return ra < rb
		return int(val_rank.get(va, 99)) < int(val_rank.get(vb, 99))
	)
	_refresh_all_visuals()
	if is_instance_valid(vfx_layer):
		vfx_layer.show_contextual_toast("🔀 کارت‌ها بر اساس رنگ و شماره مرتب شدند", Color(0.94, 0.86, 0.50), 1.4)

func _on_focus_next_playable_pressed() -> void:
	if not is_my_turn:
		return
	var playable_uids: Array[int] = []
	for c in my_hand:
		if typeof(c) == TYPE_DICTIONARY and _is_card_playable(c):
			playable_uids.append(int(c.get("uid", -1)))
	if playable_uids.is_empty():
		return
	var next_uid = playable_uids[0]
	var cur_idx = playable_uids.find(selected_card_uid)
	if cur_idx >= 0:
		next_uid = playable_uids[(cur_idx + 1) % playable_uids.size()]
	var widget = _card_widgets_by_uid.get(next_uid)
	if is_instance_valid(widget):
		_on_hand_card_tapped(next_uid, widget.card_data, widget)
		if is_instance_valid(hand_scroll):
			hand_scroll.ensure_control_visible(widget)

func _on_zoom_cycle_pressed() -> void:
	var table = get_tree().get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		return
	_zoom_preset_idx = (_zoom_preset_idx + 1) % 3
	if _zoom_preset_idx == 0:
		camera_distance = 2.74
		camera_pitch = -1.05
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 2.74
		table.target_pitch = -1.05
		table.target_yaw = 0.0
		if zoom_btn:
			zoom_btn.text = "🔍 نما"
	elif _zoom_preset_idx == 1:
		camera_distance = 3.25
		camera_pitch = -0.94
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 3.25
		table.target_pitch = -0.94
		table.target_yaw = 0.0
		if zoom_btn:
			zoom_btn.text = "🔍 میز"
	else:
		table.top_down_target_height = 2.75
		table.set_top_down_view(true, 0.45)
		if zoom_btn:
			zoom_btn.text = "🔍 بالا"

# ==============================================================================
# 6. AUTHORITATIVE BACKEND SYNC & NETWORK EVENT HANDLERS
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

func _get_player_screen_anchor(pid: int) -> Vector2:
	if pid == my_player_index:
		if is_instance_valid(hand_tray_panel):
			return hand_tray_panel.global_position + hand_tray_panel.size * 0.5
		return Vector2(540, 1520)
	var s_slot = int(_pid_to_seat_slot.get(pid, 1))
	var seat_ui = opponent_seats.get(s_slot)
	if is_instance_valid(seat_ui):
		return seat_ui.get_card_origin_global_pos()
	return Vector2(540, 430)

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

			# Animate opponent playing card to the Discard Pile
			if pid != my_player_index and is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
				var from_opp = _get_player_screen_anchor(pid)
				var to_disc = table_3d.get_discard_pile_screen_pos()
				vfx_layer.animate_card_flight(from_opp, to_disc, card, true, 0.28)

			var actor_name = _get_player_short_name(pid)
			var val_str = String(card.get("value", ""))
			var cname = UNO_COLOR_NAMES_FA.get(current_color, "قرمز")
			var act_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])

			var effect: Dictionary = p.get("effect", {}) if typeof(p.get("effect")) == TYPE_DICTIONARY else {}
			var eff_type = String(effect.get("type", val_str))

			if is_instance_valid(vfx_layer):
				if eff_type == "skip":
					var sk_p = int(effect.get("skipped_player", p.get("skipped_player", 0)))
					vfx_layer.play_special_effect_badge("🚫 پرش نوبت", act_col, 1.35)
					vfx_layer.show_contextual_toast("🚫 نوبت %s سوخت!" % _get_player_short_name(sk_p), act_col, 2.1)
				elif eff_type == "reverse":
					if is_instance_valid(table_3d):
						table_3d.animate_reverse_spin()
					vfx_layer.play_special_effect_badge("⇄ تغییر جهت", act_col, 1.35)
					vfx_layer.show_contextual_toast("⇄ جهت بازی برعکس شد", act_col, 2.0)
				elif eff_type == "draw2":
					var tp2 = int(effect.get("target_player", p.get("penalty_target", 0)))
					if is_instance_valid(table_3d) and tp2 > 0:
						vfx_layer.animate_penalty_cards(table_3d.get_draw_pile_screen_pos(), _get_player_screen_anchor(tp2), 2)
					vfx_layer.play_special_effect_badge("+۲ جریمه", act_col, 1.45)
					vfx_layer.show_contextual_toast("💥 ۲ کارت جریمه برای %s" % _get_player_short_name(tp2), act_col, 2.2)
				elif eff_type == "wild_draw4":
					var tp4 = int(effect.get("target_player", p.get("penalty_target", 0)))
					if is_instance_valid(table_3d) and tp4 > 0:
						vfx_layer.animate_penalty_cards(table_3d.get_draw_pile_screen_pos(), _get_player_screen_anchor(tp4), 4)
					vfx_layer.play_special_effect_badge("🎨 +۴ (%s)" % cname, act_col, 1.55)
					vfx_layer.show_contextual_toast("🔥 رنگ «%s» + ۴ کارت جریمه برای %s" % [cname, _get_player_short_name(tp4)], act_col, 2.4)
				elif eff_type == "wild":
					vfx_layer.play_special_effect_badge("🎨 رنگ %s" % cname, act_col, 1.35)
					vfx_layer.show_contextual_toast("🎨 %s رنگ بازی را «%s» کرد" % [actor_name, cname], act_col, 2.1)

			_refresh_all_visuals()
			if is_instance_valid(table_3d):
				table_3d.animate_discard_pop()

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
			if is_instance_valid(vfx_layer):
				if playable:
					vfx_layer.show_contextual_toast("✨ کارت جدید قابل بازی است!", Color(0.38, 0.96, 0.58), 2.1)
				else:
					vfx_layer.show_contextual_toast("🃏 کارت کشیده شد؛ نوبت رد شد", Color(0.75, 0.84, 0.92), 1.8)
			_refresh_all_visuals()

		Commands.Draw_Result:
			var d_pid = int(p.get("player", p.get("gamer_id", 0)))
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if p.has("deck_remaining") and p["deck_remaining"] != null:
				deck_remaining = int(p["deck_remaining"])
			elif p.has("draw_pile_count") and p["draw_pile_count"] != null:
				deck_remaining = int(p["draw_pile_count"])
			if d_pid != my_player_index and is_instance_valid(vfx_layer):
				if is_instance_valid(table_3d):
					vfx_layer.animate_card_flight(table_3d.get_draw_pile_screen_pos(), _get_player_screen_anchor(d_pid), {}, false, 0.28)
				vfx_layer.show_contextual_toast("🃏 %s یک کارت کشید" % _get_player_short_name(d_pid), Color(0.82, 0.88, 0.96), 1.7)
			_refresh_all_visuals()

		Commands.Pass_Turn:
			var pass_pid = int(p.get("player", p.get("gamer_id", 0)))
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if is_instance_valid(vfx_layer):
				vfx_layer.show_contextual_toast("⏭️ %s نوبت را رد کرد" % _get_player_short_name(pass_pid), Color(0.95, 0.78, 0.35), 1.6)
			_refresh_all_visuals()

		Commands.Uno_Called:
			var u_pid = int(p.get("player", p.get("gamer_id", 0)))
			uno_called[str(u_pid)] = true
			if is_instance_valid(vfx_layer):
				vfx_layer.play_special_effect_badge("🔥 UNO! (%s)" % _get_player_short_name(u_pid), UNO_COLORS["red"], 1.45)
				vfx_layer.show_contextual_toast("🔥 %s اعلام اونو کرد!" % _get_player_short_name(u_pid), Color(1.0, 0.86, 0.28), 2.1)
			_refresh_all_visuals()

		Commands.User_Data:
			_apply_uno_state_dict(p)

func on_not_played_turns_updated(gamer_id: int, count: int) -> void:
	if count <= 0 or not is_instance_valid(vfx_layer):
		return
	var p_name = _get_player_short_name(gamer_id)
	var fa_cnt = UnoCardWidgetScript.to_fa_digits(str(count))
	if gamer_id == my_player_index:
		if count < 3:
			vfx_layer.show_contextual_toast("⚠️ نوبت شما سوخت! (%s از ۳ خطای عدم بازی)" % fa_cnt, Color(1.0, 0.78, 0.25), 2.4)
		else:
			vfx_layer.show_contextual_toast("🚨 ۳ نوبت بازی نکردید؛ شما بازنده اعلام شدید", Color(1.0, 0.35, 0.35), 2.8)
	else:
		if count < 3:
			vfx_layer.show_contextual_toast("⚠️ %s در زمان مجاز بازی نکرد (%s از ۳)" % [p_name, fa_cnt], Color(1.0, 0.80, 0.32), 2.2)
		else:
			vfx_layer.show_contextual_toast("🏳️ %s به دلیل ۳ نوبت عدم بازی حذف شد!" % p_name, Color(1.0, 0.42, 0.42), 2.6)

func on_player_surrendered(gamer_id: int) -> void:
	if is_instance_valid(vfx_layer):
		vfx_layer.show_contextual_toast("🏳️ %s از بازی خارج شد" % _get_player_short_name(gamer_id), Color(1.0, 0.45, 0.45), 2.3)
	_refresh_all_visuals()

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
	selected_card_uid = -1
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
