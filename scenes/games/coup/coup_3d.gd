extends BaseGameBoard

# Coup3D - Royal Coup (کودتا) 3D Tabletop & Gamer-Friendly HUD Scene
# - Sits harmoniously on the Cafe Fekr 3D tabletop with 2-4 dynamic opponent stations
# - Displays player's secret 2 influence cards + coin vault in a clean open bottom dock
# - Context-aware 1-tap action/response dock:
#   * Action Turn: 7 official Coup actions with "✓ دارید" / "🎭 بلوف" role hints & >=10 coin mandatory Coup
#   * Smart Targeting: Instant 1-tap dispatch when 1 opponent alive; 3D seat + pill buttons when >=2 alive
#   * Challenge / Block Windows: Clear Persian claim explanation with 1-tap Pass / Challenge / Block buttons
#   * Lose Influence: Interactive golden highlight directly on your alive influence cards
#   * Ambassador Exchange: Crisp centered selection modal to pick your new hand

const CoupCardWidgetScript = preload("res://scenes/games/coup/components/coup_card_widget.gd")
const CoupTable3DScript = preload("res://scenes/games/coup/components/coup_table_3d.gd")
const CoupVFXLayerScript = preload("res://scenes/games/coup/components/coup_vfx_layer.gd")
const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

const ACTION_NAMES_FA: Dictionary = {
	"income": "درآمد (+۱🪙)",
	"foreign_aid": "کمک خارجی (+۲🪙)",
	"coup": "کودتا (-۷🪙)",
	"tax": "مالیات دوک (+۳🪙)",
	"assassinate": "ترور آدم‌کش (-۳🪙)",
	"steal": "سرقت کاپیتان (+۲🪙)",
	"exchange": "مبادله سفیر",
}

const ACTION_ALLOWED_BLOCKS: Dictionary = {
	"foreign_aid": ["duke"],
	"assassinate": ["contessa"],
	"steal": ["captain", "ambassador"],
}

# --- Authoritative Coup Match State ---
var total_players: int = 2
var phase: String = "action" # action | challenge_action | block_action | challenge_block | lose_influence | exchange | finished
var state_seq: int = 0
var deck_remaining: int = 11
var players_state: Array = [] # Array of public player dicts
var my_cards: Array = [] # Private cards [{uid, role, revealed}]
var exchange_cards: Array = []
var exchange_keep_count: int = 0

var pending_action: String = ""
var pending_actor: int = 0
var pending_target: int = 0
var pending_claimed_role: String = ""
var pending_blocker: int = 0
var pending_block_role: String = ""
var eligible_responders: Array = []
var passed_players: Array = []
var pending_loss_player: int = 0
var loss_reason: String = ""
var rank1_player: int = 0
var rank2_player: int = 0

var _pending_target_action: String = ""
var _selected_exchange_indices: Array[int] = []
var _match_started: bool = false
var _last_timer_seq: int = -1
var _last_event_seq: int = -1
var _zoom_preset_idx: int = 0
var _seat_slot_to_pid: Dictionary = {}

# --- Camera Framing (Mandatory on BaseGameBoard scenes) ---
var camera_distance: float = 2.42
var camera_pitch: float = -0.82

# --- 3D Table Component ---
var table_3d: Node3D

# --- Gamer-Friendly Floating 2D HUD ---
var hud_layer: CanvasLayer
var hud_root: Control
var vfx_layer: Control

# Top Status Pill
var status_pill: PanelContainer
var status_dot_style: StyleBoxFlat
var status_label: Label
var deck_badge_lbl: Label
var rules_btn: Button
var zoom_btn: Button

# Bottom Floating Dock
var bottom_dock: Control
var dock_panel: PanelContainer
var coins_pill_panel: PanelContainer
var coins_pill_style: StyleBoxFlat
var coins_pill_lbl: Label
var hand_prompt_lbl: Label
var my_cards_hbox: HBoxContainer
var actions_container: VBoxContainer

# Modals
var exchange_backdrop: ColorRect
var exchange_cards_hbox: HBoxContainer
var exchange_subtitle_lbl: Label
var exchange_confirm_btn: Button
var roles_modal_backdrop: ColorRect

# ==============================================================================
# 1. INITIALIZATION & LIFECYCLE
# ==============================================================================

func _init() -> void:
	camera_distance = 2.42
	camera_pitch = -0.82

func _ready() -> void:
	game_type = GameTypes.COUP
	_setup_table_3d()
	_build_hud()
	super._ready()
	_connect_coup_signals()
	_refresh_all_visuals()
	_update_hud_visibility()
	call_deferred("_enforce_camera_framing")

func _enforce_camera_framing() -> void:
	var table: Node = get_tree().get_first_node_in_group("cafe_table")
	if is_instance_valid(table):
		table.target_distance = camera_distance
		table.target_pitch = camera_pitch
		table.target_yaw = 0.0
		var p_cnt: int = _get_total_players()
		if table.has_method("set_player_chair_count"):
			table.set_player_chair_count(p_cnt)
		elif table.has_method("set_player_seats_count"):
			table.set_player_seats_count(p_cnt)

func _process(_delta: float) -> void:
	_update_hud_visibility()

func _setup_table_3d() -> void:
	table_3d = CoupTable3DScript.new()
	table_3d.name = "CoupTable3D"
	add_child(table_3d)
	table_3d.seat_clicked.connect(_on_3d_seat_clicked)

func _connect_coup_signals() -> void:
	if not NetworkManager.coup_event_received.is_connected(_on_coup_event_received):
		NetworkManager.coup_event_received.connect(_on_coup_event_received)
	if not NetworkManager.user_data_received.is_connected(_on_user_data_received):
		NetworkManager.user_data_received.connect(_on_user_data_received)
	if not NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.connect(_on_win_happened)
	if not NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.connect(_on_internal_reconnect_data)

func _disconnect_coup_signals() -> void:
	if NetworkManager.coup_event_received.is_connected(_on_coup_event_received):
		NetworkManager.coup_event_received.disconnect(_on_coup_event_received)
	if NetworkManager.user_data_received.is_connected(_on_user_data_received):
		NetworkManager.user_data_received.disconnect(_on_user_data_received)
	if NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.disconnect(_on_win_happened)
	if NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)

func _exit_tree() -> void:
	_disconnect_coup_signals()
	super._exit_tree()

# ==============================================================================
# 2. FLOATING ROYAL HUD CONSTRUCTION
# ==============================================================================

func _make_glass_style(bg: Color, border: Color, radius: int = 18, border_w: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s

func _style_action_button(btn: Button, bg: Color, border: Color, text_col: Color = Color.WHITE, f_size: int = 25, disabled: bool = false) -> void:
	btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", f_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.12))
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 0.78))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	btn.add_theme_constant_override("outline_size", 3)

	var st_norm: StyleBoxFlat = _make_glass_style(bg, border, 16, 2)
	var st_hov: StyleBoxFlat = _make_glass_style(bg.lightened(0.10), border.lightened(0.18), 16, 2)
	var st_press: StyleBoxFlat = _make_glass_style(bg.darkened(0.10), border, 16, 2)
	var st_dis: StyleBoxFlat = _make_glass_style(Color(0.13, 0.12, 0.14, 0.72), Color(0.36, 0.34, 0.34, 0.50), 16, 1)

	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_press)
	btn.add_theme_stylebox_override("disabled", st_dis)
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND

func _make_gamer_action_btn(
	title_txt: String,
	cost_txt: String,
	badge_txt: String,
	badge_bg: Color,
	badge_bd: Color,
	bg: Color,
	bd: Color,
	btn_height: float = 84.0,
	is_dis: bool = false,
	title_size: int = 25
) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, btn_height)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	_style_action_button(btn, bg, bd, Color.WHITE, title_size, is_dis)

	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(m)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(vb)

	var top_hb: HBoxContainer = HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 6)
	top_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_hb)

	if not cost_txt.is_empty():
		var c_pill: PanelContainer = PanelContainer.new()
		c_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cp_st: StyleBoxFlat = StyleBoxFlat.new()
		cp_st.bg_color = Color(0.06, 0.05, 0.04, 0.72) if not is_dis else Color(0.10, 0.10, 0.12, 0.55)
		cp_st.border_color = Color(1.0, 0.84, 0.34, 0.72) if not is_dis else Color(0.45, 0.45, 0.48, 0.45)
		cp_st.set_border_width_all(1)
		cp_st.set_corner_radius_all(9)
		cp_st.content_margin_left = 8
		cp_st.content_margin_right = 8
		cp_st.content_margin_top = 1
		cp_st.content_margin_bottom = 1
		c_pill.add_theme_stylebox_override("panel", cp_st)
		top_hb.add_child(c_pill)

		var c_lbl: Label = Label.new()
		c_lbl.text = cost_txt
		c_lbl.add_theme_font_override("font", FontHekayat)
		c_lbl.add_theme_font_size_override("font_size", 22)
		c_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.44) if not is_dis else Color(0.66, 0.66, 0.70))
		c_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		c_lbl.add_theme_constant_override("outline_size", 2)
		c_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c_pill.add_child(c_lbl)

	var t_lbl: Label = Label.new()
	t_lbl.text = title_txt
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not cost_txt.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_override("font", FontHekayat)
	t_lbl.add_theme_font_size_override("font_size", title_size)
	t_lbl.add_theme_color_override("font_color", Color.WHITE if not is_dis else Color(0.68, 0.68, 0.72))
	t_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	t_lbl.add_theme_constant_override("outline_size", 3)
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(t_lbl)

	if not badge_txt.is_empty():
		var bot_hb: HBoxContainer = HBoxContainer.new()
		bot_hb.alignment = BoxContainer.ALIGNMENT_END if not cost_txt.is_empty() else BoxContainer.ALIGNMENT_CENTER
		bot_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bot_hb)

		var b_pill: PanelContainer = PanelContainer.new()
		b_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bp_st: StyleBoxFlat = StyleBoxFlat.new()
		bp_st.bg_color = badge_bg if not is_dis else Color(0.18, 0.16, 0.18, 0.82)
		bp_st.border_color = badge_bd if not is_dis else Color(0.45, 0.42, 0.45, 0.65)
		bp_st.set_border_width_all(1)
		bp_st.set_corner_radius_all(8)
		bp_st.content_margin_left = 8
		bp_st.content_margin_right = 8
		bp_st.content_margin_top = 1
		bp_st.content_margin_bottom = 1
		b_pill.add_theme_stylebox_override("panel", bp_st)
		bot_hb.add_child(b_pill)

		var b_lbl: Label = Label.new()
		b_lbl.text = badge_txt
		b_lbl.add_theme_font_override("font", FontHekayat)
		b_lbl.add_theme_font_size_override("font_size", 19)
		b_lbl.add_theme_color_override("font_color", Color(0.98, 0.98, 0.94) if not is_dis else Color(0.84, 0.74, 0.72))
		b_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		b_lbl.add_theme_constant_override("outline_size", 2)
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_pill.add_child(b_lbl)

	return btn

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_layer.name = "CoupHUDLayer"
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "CoupHUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# 1. Floating Top Status & Utility Bar (Below TopHeader, keeps 3D table clear)
	status_pill = PanelContainer.new()
	status_pill.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_pill.offset_left = 24
	status_pill.offset_right = -24
	status_pill.offset_top = 316
	status_pill.offset_bottom = 392
	status_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	status_pill.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.07, 0.05, 0.04, 0.92), Color(0.90, 0.72, 0.30, 0.82), 24, 2)
	)
	hud_root.add_child(status_pill)

	var pill_m: MarginContainer = MarginContainer.new()
	pill_m.add_theme_constant_override("margin_left", 14)
	pill_m.add_theme_constant_override("margin_right", 16)
	pill_m.add_theme_constant_override("margin_top", 6)
	pill_m.add_theme_constant_override("margin_bottom", 6)
	status_pill.add_child(pill_m)

	var pill_hbox: HBoxContainer = HBoxContainer.new()
	pill_hbox.add_theme_constant_override("separation", 10)
	pill_m.add_child(pill_hbox)

	zoom_btn = Button.new()
	zoom_btn.text = "🔍 نما"
	zoom_btn.custom_minimum_size = Vector2(106, 50)
	_style_action_button(zoom_btn, Color(0.14, 0.21, 0.28, 0.95), Color(0.56, 0.78, 0.94, 0.80), Color(0.94, 0.98, 1.0), 23)
	zoom_btn.pressed.connect(_on_zoom_cycle_pressed)
	pill_hbox.add_child(zoom_btn)

	rules_btn = Button.new()
	rules_btn.text = "📜 نقش‌ها"
	rules_btn.custom_minimum_size = Vector2(126, 50)
	_style_action_button(rules_btn, Color(0.36, 0.16, 0.46, 0.95), Color(0.80, 0.58, 0.96, 0.85), Color(0.98, 0.94, 1.0), 23)
	rules_btn.pressed.connect(_on_open_roles_modal)
	pill_hbox.add_child(rules_btn)

	var deck_pill: PanelContainer = PanelContainer.new()
	deck_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var deck_st: StyleBoxFlat = StyleBoxFlat.new()
	deck_st.bg_color = Color(0.18, 0.13, 0.06, 0.90)
	deck_st.border_color = Color(0.90, 0.72, 0.30, 0.68)
	deck_st.set_border_width_all(1)
	deck_st.set_corner_radius_all(12)
	deck_st.content_margin_left = 10
	deck_st.content_margin_right = 10
	deck_st.content_margin_top = 4
	deck_st.content_margin_bottom = 4
	deck_pill.add_theme_stylebox_override("panel", deck_st)
	pill_hbox.add_child(deck_pill)

	deck_badge_lbl = Label.new()
	deck_badge_lbl.text = "🃏 دربار: ۱۱"
	deck_badge_lbl.add_theme_font_override("font", FontHekayat)
	deck_badge_lbl.add_theme_font_size_override("font_size", 24)
	deck_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	deck_badge_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	deck_badge_lbl.add_theme_constant_override("outline_size", 2)
	deck_pill.add_child(deck_badge_lbl)

	status_label = Label.new()
	status_label.text = "در انتظار شروع بازی..."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_override("font", FontHekayat)
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92))
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	status_label.add_theme_constant_override("outline_size", 3)
	pill_hbox.add_child(status_label)

	var dot_p: PanelContainer = PanelContainer.new()
	dot_p.custom_minimum_size = Vector2(18, 18)
	dot_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_dot_style = StyleBoxFlat.new()
	status_dot_style.bg_color = Color(0.32, 0.96, 0.56)
	status_dot_style.set_corner_radius_all(9)
	dot_p.add_theme_stylebox_override("panel", status_dot_style)
	pill_hbox.add_child(dot_p)

	# 2. Roomy Bottom Floating Player Dock (Hand Cards + Coin Purse + Rich Command Deck)
	bottom_dock = Control.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 14
	bottom_dock.offset_right = -14
	bottom_dock.offset_top = -596
	bottom_dock.offset_bottom = -154
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	dock_panel = PanelContainer.new()
	dock_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.06, 0.045, 0.04, 0.90), Color(0.90, 0.72, 0.30, 0.76), 26, 2)
	)
	bottom_dock.add_child(dock_panel)

	var dock_m: MarginContainer = MarginContainer.new()
	dock_m.add_theme_constant_override("margin_left", 14)
	dock_m.add_theme_constant_override("margin_right", 14)
	dock_m.add_theme_constant_override("margin_top", 12)
	dock_m.add_theme_constant_override("margin_bottom", 12)
	dock_panel.add_child(dock_m)

	var dock_hbox: HBoxContainer = HBoxContainer.new()
	dock_hbox.add_theme_constant_override("separation", 14)
	dock_m.add_child(dock_hbox)

	# Left Column: Player Coins & 2 Large Influence Cards
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 10)
	left_col.custom_minimum_size = Vector2(342, 0)
	dock_hbox.add_child(left_col)

	var left_top_row: HBoxContainer = HBoxContainer.new()
	left_top_row.add_theme_constant_override("separation", 8)
	left_col.add_child(left_top_row)

	coins_pill_panel = PanelContainer.new()
	coins_pill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_pill_panel.custom_minimum_size = Vector2(0, 52)
	coins_pill_style = StyleBoxFlat.new()
	coins_pill_style.bg_color = Color(0.24, 0.17, 0.05, 0.96)
	coins_pill_style.border_color = Color(0.98, 0.80, 0.30)
	coins_pill_style.set_border_width_all(2)
	coins_pill_style.set_corner_radius_all(14)
	coins_pill_style.content_margin_left = 12
	coins_pill_style.content_margin_right = 12
	coins_pill_style.content_margin_top = 6
	coins_pill_style.content_margin_bottom = 6
	coins_pill_panel.add_theme_stylebox_override("panel", coins_pill_style)
	left_top_row.add_child(coins_pill_panel)

	coins_pill_lbl = Label.new()
	coins_pill_lbl.text = "🪙 ۲ سکه"
	coins_pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_pill_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_pill_lbl.add_theme_font_override("font", FontHekayat)
	coins_pill_lbl.add_theme_font_size_override("font_size", 28)
	coins_pill_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.48))
	coins_pill_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	coins_pill_lbl.add_theme_constant_override("outline_size", 3)
	coins_pill_panel.add_child(coins_pill_lbl)

	hand_prompt_lbl = Label.new()
	hand_prompt_lbl.text = "کارت‌های نفوذ شما"
	hand_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_prompt_lbl.add_theme_font_override("font", FontHekayat)
	hand_prompt_lbl.add_theme_font_size_override("font_size", 24)
	hand_prompt_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	hand_prompt_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
	hand_prompt_lbl.add_theme_constant_override("outline_size", 2)
	left_col.add_child(hand_prompt_lbl)

	my_cards_hbox = HBoxContainer.new()
	my_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	my_cards_hbox.add_theme_constant_override("separation", 12)
	my_cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(my_cards_hbox)

	# Vertical Divider
	var v_sep: VSeparator = VSeparator.new()
	v_sep.modulate = Color(0.92, 0.74, 0.36, 0.45)
	dock_hbox.add_child(v_sep)

	# Right Column: Context-Aware Action / Target / Response Dock
	actions_container = VBoxContainer.new()
	actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_container.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_container.add_theme_constant_override("separation", 8)
	dock_hbox.add_child(actions_container)

	# 3. Modals & VFX Layer
	_build_exchange_modal()
	_build_roles_modal()

	vfx_layer = CoupVFXLayerScript.new()
	vfx_layer.name = "CoupVFXLayer"
	hud_root.add_child(vfx_layer)

func _build_exchange_modal() -> void:
	exchange_backdrop = ColorRect.new()
	exchange_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	exchange_backdrop.color = Color(0.02, 0.04, 0.03, 0.84)
	exchange_backdrop.visible = false
	exchange_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(exchange_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	exchange_backdrop.add_child(center)

	var modal_panel: PanelContainer = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(920, 560)
	modal_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.06, 0.14, 0.10, 0.98), Color(0.48, 0.96, 0.64, 0.92), 28, 3)
	)
	center.add_child(modal_panel)

	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_right", 28)
	m.add_theme_constant_override("margin_top", 26)
	m.add_theme_constant_override("margin_bottom", 26)
	modal_panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	m.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📜 مبادله کارت با سفیر"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color(0.56, 0.98, 0.70))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	title_lbl.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title_lbl)

	exchange_subtitle_lbl = Label.new()
	exchange_subtitle_lbl.text = "۲ کارت را برای نگه داشتن انتخاب کنید؛ بقیه به دیوان برمی‌گردند."
	exchange_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exchange_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exchange_subtitle_lbl.add_theme_font_override("font", FontHekayat)
	exchange_subtitle_lbl.add_theme_font_size_override("font_size", 27)
	exchange_subtitle_lbl.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	exchange_subtitle_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	exchange_subtitle_lbl.add_theme_constant_override("outline_size", 3)
	vbox.add_child(exchange_subtitle_lbl)

	exchange_cards_hbox = HBoxContainer.new()
	exchange_cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	exchange_cards_hbox.add_theme_constant_override("separation", 18)
	vbox.add_child(exchange_cards_hbox)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var peek_btn: Button = Button.new()
	peek_btn.text = "👀 دیدن میز"
	peek_btn.custom_minimum_size = Vector2(200, 72)
	_style_action_button(peek_btn, Color(0.18, 0.24, 0.30), Color(0.56, 0.76, 0.92), Color.WHITE, 25, false)
	peek_btn.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		exchange_backdrop.visible = false
	)
	btn_row.add_child(peek_btn)

	exchange_confirm_btn = Button.new()
	exchange_confirm_btn.text = "✅ تایید و ثبت دست جدید"
	exchange_confirm_btn.custom_minimum_size = Vector2(390, 72)
	_style_action_button(exchange_confirm_btn, Color(0.12, 0.56, 0.28), Color(0.48, 0.96, 0.64), Color.WHITE, 28, true)
	exchange_confirm_btn.pressed.connect(_on_confirm_exchange_pressed)
	btn_row.add_child(exchange_confirm_btn)

func _build_roles_modal() -> void:
	roles_modal_backdrop = ColorRect.new()
	roles_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	roles_modal_backdrop.color = Color(0.02, 0.03, 0.04, 0.84)
	roles_modal_backdrop.visible = false
	roles_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	roles_modal_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			roles_modal_backdrop.visible = false
	)
	hud_root.add_child(roles_modal_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roles_modal_backdrop.add_child(center)

	var modal_panel: PanelContainer = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(940, 860)
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.08, 0.06, 0.05, 0.98), Color(0.94, 0.76, 0.32, 0.94), 28, 3)
	)
	center.add_child(modal_panel)

	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_right", 28)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	modal_panel.add_child(m)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "📜 راهنمای نقش‌ها و قوانین کودتا"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	title_lbl.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title_lbl)

	var roles_info: Array[Dictionary] = [
		{"role": "duke", "title": "👑 دوک", "txt": "گرفتن ۳ سکه مالیات  •  مسدود کردن کمک خارجی (+۲🪙)"},
		{"role": "assassin", "title": "🗡️ آدم‌کش", "txt": "پرداخت ۳ سکه و حذف یک کارت حریف (دفاع با کنتس)"},
		{"role": "captain", "title": "⚓ کاپیتان", "txt": "سرقت تا ۲ سکه از حریف  •  مسدود کردن سرقت"},
		{"role": "ambassador", "title": "📜 سفیر", "txt": "تعویض دلخواه کارت‌ها با دیوان  •  مسدود کردن سرقت"},
		{"role": "contessa", "title": "🛡️ کنتس", "txt": "مسدود کردن حمله آدم‌کش (فقط برای خودتان)"},
	]
	for ri: Dictionary in roles_info:
		var r_id: String = String(ri["role"])
		var r_col: Color = CoupCardWidgetScript.get_role_color(r_id)
		var row_p: PanelContainer = PanelContainer.new()
		row_p.add_theme_stylebox_override("panel", _make_glass_style(r_col.darkened(0.55), r_col.lightened(0.28), 16, 2))
		var rl_m: MarginContainer = MarginContainer.new()
		rl_m.add_theme_constant_override("margin_left", 16)
		rl_m.add_theme_constant_override("margin_right", 16)
		rl_m.add_theme_constant_override("margin_top", 12)
		rl_m.add_theme_constant_override("margin_bottom", 12)
		row_p.add_child(rl_m)

		var row_hb: HBoxContainer = HBoxContainer.new()
		row_hb.add_theme_constant_override("separation", 14)
		rl_m.add_child(row_hb)

		var lbl: Label = Label.new()
		lbl.text = String(ri["txt"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", FontHekayat)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 2)
		row_hb.add_child(lbl)

		var badge_p: PanelContainer = PanelContainer.new()
		badge_p.custom_minimum_size = Vector2(150, 0)
		badge_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b_st: StyleBoxFlat = StyleBoxFlat.new()
		b_st.bg_color = r_col
		b_st.border_color = r_col.lightened(0.40)
		b_st.set_border_width_all(1)
		b_st.set_corner_radius_all(12)
		b_st.content_margin_left = 10
		b_st.content_margin_right = 10
		b_st.content_margin_top = 6
		b_st.content_margin_bottom = 6
		badge_p.add_theme_stylebox_override("panel", b_st)
		row_hb.add_child(badge_p)

		var r_title_lbl: Label = Label.new()
		r_title_lbl.text = String(ri["title"])
		r_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_title_lbl.add_theme_font_override("font", FontHekayat)
		r_title_lbl.add_theme_font_size_override("font_size", 26)
		r_title_lbl.add_theme_color_override("font_color", Color.WHITE)
		r_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		r_title_lbl.add_theme_constant_override("outline_size", 3)
		badge_p.add_child(r_title_lbl)

		vbox.add_child(row_p)

	var note_p: PanelContainer = PanelContainer.new()
	note_p.add_theme_stylebox_override("panel", _make_glass_style(Color(0.18, 0.13, 0.04, 0.90), Color(0.95, 0.78, 0.28, 0.78), 16, 1))
	var n_m: MarginContainer = MarginContainer.new()
	n_m.add_theme_constant_override("margin_left", 16)
	n_m.add_theme_constant_override("margin_right", 16)
	n_m.add_theme_constant_override("margin_top", 10)
	n_m.add_theme_constant_override("margin_bottom", 10)
	note_p.add_child(n_m)
	var note_lbl: Label = Label.new()
	note_lbl.text = "💡 نکته کلیدی: می‌توانید با هر نقشی «بلوف» بزنید! اما اگر با ۱۰ سکه یا بیشتر نوبت را شروع کنید، اجرای «کودتا» (۷ سکه) اجباری و غیرقابل دفاع است."
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.add_theme_font_override("font", FontHekayat)
	note_lbl.add_theme_font_size_override("font_size", 23)
	note_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	note_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	note_lbl.add_theme_constant_override("outline_size", 2)
	n_m.add_child(note_lbl)
	vbox.add_child(note_p)

	var close_btn: Button = Button.new()
	close_btn.text = "متوجه شدم"
	close_btn.custom_minimum_size = Vector2(280, 68)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_action_button(close_btn, Color(0.14, 0.54, 0.28), Color(0.45, 0.94, 0.60), Color.WHITE, 28)
	close_btn.pressed.connect(func() -> void:
		AudioManager.sfx_tap()
		roles_modal_backdrop.visible = false
	)
	vbox.add_child(close_btn)

# ==============================================================================
# 3. STATE HELPERS & HUD VISIBILITY
# ==============================================================================

func _get_total_players() -> int:
	if GameManager.match_players.size() >= 2:
		total_players = clampi(GameManager.match_players.size(), 2, 4)
		return total_players
	if players_state.size() >= 2:
		total_players = clampi(players_state.size(), 2, 4)
		return total_players
	return total_players

func _get_player_entry(gid: int) -> Dictionary:
	for pv: Variant in players_state:
		if typeof(pv) == TYPE_DICTIONARY and int((pv as Dictionary).get("gamer_id", 0)) == gid:
			return pv as Dictionary
	return {}

func _get_my_coins() -> int:
	var me: Dictionary = _get_player_entry(my_player_index)
	if not me.is_empty():
		return int(me.get("coins", 2))
	return 2

func _is_player_alive(gid: int) -> bool:
	var p: Dictionary = _get_player_entry(gid)
	if not p.is_empty():
		return bool(p.get("alive", true)) and int(p.get("alive_cards", 1)) > 0
	return true

func _has_my_hidden_role(role: String) -> bool:
	var r_low: String = role.to_lower()
	for cv: Variant in my_cards:
		if typeof(cv) == TYPE_DICTIONARY:
			var cd: Dictionary = cv as Dictionary
			if not bool(cd.get("revealed", false)) and String(cd.get("role", "")).to_lower() == r_low:
				return true
	return false

func _get_player_short_name(pid: int) -> String:
	if pid <= 0:
		return "بازیکن"
	var p_data: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
	var p_name: String = String(p_data.get("name", p_data.get("username", "")))
	if p_name.is_empty():
		p_name = "بازیکن " + CoupCardWidgetScript.to_fa_digits(str(pid))
	return p_name

func _get_alive_opponents() -> Array[int]:
	var opps: Array[int] = []
	var tot: int = _get_total_players()
	for pid: int in range(1, tot + 1):
		if pid != my_player_index and _is_player_alive(pid):
			opps.append(pid)
	return opps

func _is_my_response_needed() -> bool:
	if not GameManager.is_game_active:
		return false
	if phase not in ["challenge_action", "block_action", "challenge_block"]:
		return false
	var my_in_elig: bool = false
	for e: Variant in eligible_responders:
		if int(e) == my_player_index:
			my_in_elig = true
			break
	if not my_in_elig:
		return false
	for p: Variant in passed_players:
		if int(p) == my_player_index:
			return false
	return _is_player_alive(my_player_index)

func _is_hud_overlay_blocking() -> bool:
	if not _match_started and not GameManager.is_game_active:
		return true
	var tree: SceneTree = get_tree()
	if not tree:
		return false
	var hud: Node = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var start_ov: Control = hud.get_node_or_null("StartGameOverlay") as Control
		if is_instance_valid(start_ov) and start_ov.visible:
			return true
		var res_dlg: Control = hud.get_node_or_null("GameResultDialog") as Control
		if is_instance_valid(res_dlg) and res_dlg.visible:
			return true
	return false

func _update_hud_visibility() -> void:
	if not is_instance_valid(hud_root):
		return
	var tree: SceneTree = get_tree()
	if tree:
		var hud: Node = tree.get_first_node_in_group("base_game_hud")
		if not is_instance_valid(hud):
			hud = tree.root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud) and hud_root.get_parent() != hud:
			if hud_root.get_parent():
				hud_root.get_parent().remove_child(hud_root)
			hud.add_child(hud_root)
			var start_ov: Node = hud.get_node_or_null("StartGameOverlay")
			if is_instance_valid(start_ov):
				hud.move_child(hud_root, start_ov.get_index())
			if is_instance_valid(hud_layer):
				hud_layer.queue_free()
				hud_layer = null
	var should_show: bool = not _is_hud_overlay_blocking()
	if hud_root.visible != should_show:
		hud_root.visible = should_show
		if should_show:
			_refresh_top_header_badges()

func _refresh_top_header_badges() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var hud: Node = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var header: Node = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
		if is_instance_valid(header) and header.has_method("update_coup_players"):
			header.update_coup_players(players_state, rank1_player, rank2_player)

func _sync_phase_timer(time_limit_hint: float = -1.0) -> void:
	if not _match_started or not GameManager.is_game_active:
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var hud: Node = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if not is_instance_valid(hud) or not hud.has_method("start_turn_timer"):
		return
	if state_seq > 0 and state_seq == _last_timer_seq:
		return
	_last_timer_seq = state_seq

	var t_sec: float = time_limit_hint
	if t_sec <= 0.0:
		if phase in ["challenge_action", "block_action", "challenge_block"]:
			t_sec = 12.0
		elif phase in ["lose_influence", "exchange"]:
			t_sec = 15.0
		else:
			t_sec = 25.0

	var banner: String = _build_phase_banner_text()
	hud.start_turn_timer(t_sec, banner)

func _build_phase_banner_text() -> String:
	match phase:
		"action":
			if is_my_turn:
				if _get_my_coins() >= 10:
					return "⚠️ ۱۰+ سکه دارید! اجرای «کودتا» اجباری است"
				return "🎭 نوبت شماست! یک اقدام یا بلوف انتخاب کنید"
			return "⏳ نوبت %s برای انتخاب حرکت..." % _get_player_short_name(current_turn)
		"challenge_action":
			var act_fa: String = String(ACTION_NAMES_FA.get(pending_action, pending_action))
			var role_fa: String = CoupCardWidgetScript.get_role_name_fa(pending_claimed_role)
			return "⚡ %s ادعای «%s» (%s) کرد!" % [_get_player_short_name(pending_actor), role_fa, act_fa]
		"block_action":
			if pending_action == "foreign_aid":
				return "🛡️ %s کمک خارجی (+۲) می‌خواهد؛ دفاع با دوک یا قبول؟" % _get_player_short_name(pending_actor)
			return "🛡️ %s به %s حمله کرد؛ دفاع یا قبول؟" % [_get_player_short_name(pending_actor), _get_player_short_name(pending_target)]
		"challenge_block":
			var b_role_fa: String = CoupCardWidgetScript.get_role_name_fa(pending_block_role)
			return "⚡ %s با «%s» دفاع کرد! چالش می‌زنید؟" % [_get_player_short_name(pending_blocker), b_role_fa]
		"lose_influence":
			if pending_loss_player == my_player_index:
				return "💔 یکی از کارت‌های نفوذ خود را برای حذف انتخاب کنید!"
			return "💔 %s در حال انتخاب کارت برای حذف..." % _get_player_short_name(pending_loss_player)
		"exchange":
			if current_turn == my_player_index:
				return "📜 کارت‌های خود را با سفیر مبادله کنید"
			return "📜 %s در حال مبادله کارت با سفیر..." % _get_player_short_name(current_turn)
		"finished":
			return "🏆 پایان نبرد کودتا!"
	return "کودتا"

# ==============================================================================
# 4. VISUAL REFRESH (3D TABLE, TOP PILL, MY CARDS, ACTION DOCK, EXCHANGE)
# ==============================================================================

func _refresh_all_visuals() -> void:
	my_player_index = max(1, GameManager.my_player_index)
	is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active

	if is_instance_valid(table_3d):
		table_3d.update_table_state(phase, deck_remaining)

	_refresh_top_pill()
	_refresh_3d_opponents()
	_refresh_my_cards_and_coins()
	_rebuild_action_dock()
	_refresh_exchange_modal()
	_refresh_top_header_badges()

func _refresh_top_pill() -> void:
	if not is_instance_valid(status_label):
		return
	if is_instance_valid(deck_badge_lbl):
		deck_badge_lbl.text = "🃏 دربار: %s" % CoupCardWidgetScript.to_fa_digits(str(max(0, deck_remaining)))

	status_label.text = _build_phase_banner_text()
	if phase == "lose_influence" and pending_loss_player == my_player_index:
		status_dot_style.bg_color = Color(1.0, 0.25, 0.28)
		status_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.56))
	elif _is_my_response_needed():
		status_dot_style.bg_color = Color(1.0, 0.72, 0.20)
		status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	elif is_my_turn and (phase in ["action", "exchange"]):
		status_dot_style.bg_color = Color(0.30, 0.98, 0.56)
		status_label.add_theme_color_override("font_color", Color(0.52, 0.98, 0.68))
	else:
		status_dot_style.bg_color = Color(0.45, 0.72, 0.98)
		status_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))

func _refresh_3d_opponents() -> void:
	_seat_slot_to_pid.clear()
	var total_p: int = _get_total_players()

	var table_node: Node = get_tree().get_first_node_in_group("cafe_table")
	if is_instance_valid(table_node):
		if table_node.has_method("set_player_chair_count"):
			table_node.set_player_chair_count(total_p)
		elif table_node.has_method("set_player_seats_count"):
			table_node.set_player_seats_count(total_p)

	var opp_pids: Array[int] = []
	for offset: int in range(1, total_p):
		var pid: int = ((my_player_index - 1 + offset) % total_p) + 1
		if pid != my_player_index:
			opp_pids.append(pid)

	var slot_map: Array[int] = [1]
	if opp_pids.size() == 2:
		slot_map = [2, 3]
	elif opp_pids.size() >= 3:
		slot_map = [2, 1, 3]

	var seat_data: Dictionary = {}
	var active_seat: int = -1
	var selecting_target: bool = (not _pending_target_action.is_empty()) and (phase == "action") and is_my_turn

	for i: int in range(min(opp_pids.size(), slot_map.size())):
		var pid: int = opp_pids[i]
		var s_slot: int = slot_map[i]
		_seat_slot_to_pid[s_slot] = pid

		var p_info: Dictionary = _get_player_entry(pid)
		var p_alive: bool = bool(p_info.get("alive", true)) and int(p_info.get("alive_cards", 2)) > 0
		var p_coins: int = int(p_info.get("coins", 2))
		var p_alive_cards: int = int(p_info.get("alive_cards", 2))
		var p_cards: Array = p_info.get("cards", [{"revealed": false}, {"revealed": false}]) if typeof(p_info.get("cards")) == TYPE_ARRAY else [{"revealed": false}, {"revealed": false}]

		seat_data[s_slot] = {
			"gamer_id": pid,
			"name": _get_player_short_name(pid),
			"coins": p_coins,
			"alive": p_alive,
			"alive_cards": p_alive_cards,
			"cards": p_cards,
			"targetable": selecting_target and p_alive,
			"pending_loss": (phase == "lose_influence" and pending_loss_player == pid),
		}
		if current_turn == pid and p_alive:
			active_seat = s_slot

	if is_instance_valid(table_3d):
		table_3d.update_opponent_stations(seat_data, active_seat)

func _refresh_my_cards_and_coins() -> void:
	var coins: int = _get_my_coins()
	var my_alive: bool = _is_player_alive(my_player_index)
	if is_instance_valid(coins_pill_lbl):
		if not my_alive:
			coins_pill_lbl.text = "💀 حذف شدید"
			coins_pill_lbl.add_theme_font_size_override("font_size", 26)
			coins_pill_style.bg_color = Color(0.28, 0.10, 0.12, 0.94)
			coins_pill_style.border_color = Color(0.95, 0.35, 0.35)
		elif coins >= 10:
			coins_pill_lbl.text = "🪙 %s سکه (کودتا اجباری!)" % CoupCardWidgetScript.to_fa_digits(str(coins))
			coins_pill_lbl.add_theme_font_size_override("font_size", 24)
			coins_pill_style.bg_color = Color(0.58, 0.16, 0.10, 0.98)
			coins_pill_style.border_color = Color(1.0, 0.80, 0.24)
		else:
			coins_pill_lbl.text = "🪙 %s سکه" % CoupCardWidgetScript.to_fa_digits(str(coins))
			coins_pill_lbl.add_theme_font_size_override("font_size", 28)
			coins_pill_style.bg_color = Color(0.24, 0.17, 0.05, 0.96)
			coins_pill_style.border_color = Color(0.98, 0.80, 0.30)

	var must_sacrifice: bool = GameManager.is_game_active and (phase == "lose_influence") and (pending_loss_player == my_player_index)
	if is_instance_valid(hand_prompt_lbl):
		if must_sacrifice:
			hand_prompt_lbl.text = "💔 کارت قربانی را لمس کنید!"
			hand_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.54, 0.52))
		else:
			hand_prompt_lbl.text = "کارت‌های نفوذ شما"
			hand_prompt_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))

	if not is_instance_valid(my_cards_hbox):
		return
	for ch: Node in my_cards_hbox.get_children():
		ch.queue_free()

	for idx: int in range(my_cards.size()):
		var c_var: Variant = my_cards[idx]
		if typeof(c_var) != TYPE_DICTIONARY:
			continue
		var c_dict: Dictionary = c_var as Dictionary
		var card_w: CoupCardWidget = CoupCardWidgetScript.new()
		card_w.setup_card(idx, c_dict, must_sacrifice, false, Vector2(158, 230))
		card_w.card_clicked.connect(_on_my_card_clicked)
		my_cards_hbox.add_child(card_w)

func _rebuild_action_dock() -> void:
	if not is_instance_valid(actions_container):
		return
	for ch: Node in actions_container.get_children():
		ch.queue_free()

	if not _is_player_alive(my_player_index) and GameManager.is_game_active:
		_add_dock_info_panel("💀 تمام کارت‌های نفوذ شما سوخته است.\nدر حال تماشای ادامه نبرد...", Color(1.0, 0.66, 0.66), Color(0.28, 0.10, 0.12, 0.86), Color(0.90, 0.36, 0.36, 0.78), 27)
		return

	# 1. Target Selection Strip (when player clicked Coup / Assassinate / Steal with >=2 opponents alive)
	if not _pending_target_action.is_empty() and phase == "action" and is_my_turn:
		var act_fa: String = String(ACTION_NAMES_FA.get(_pending_target_action, _pending_target_action))
		_add_dock_info_panel("🎯 هدف %s را انتخاب کنید (روی بازیکن یا دکمه بزنید):" % act_fa, Color(1.0, 0.90, 0.44), Color(0.22, 0.15, 0.05, 0.92), Color(0.98, 0.78, 0.28, 0.85), 25)
		var opps: Array[int] = _get_alive_opponents()
		var t_grid: GridContainer = GridContainer.new()
		t_grid.columns = 2
		t_grid.add_theme_constant_override("h_separation", 10)
		t_grid.add_theme_constant_override("v_separation", 10)
		t_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_container.add_child(t_grid)

		for opp_pid: int in opps:
			var p_entry: Dictionary = _get_player_entry(opp_pid)
			var c_cnt: int = int(p_entry.get("coins", 0))
			var h_cnt: int = int(p_entry.get("alive_cards", 2))
			var t_stats: String = "🪙 %s   |   ♥ %s" % [CoupCardWidgetScript.to_fa_digits(str(c_cnt)), CoupCardWidgetScript.to_fa_digits(str(h_cnt))]
			var f_col: Color = CoupTable3DScript.FACTION_COLORS.get(opp_pid, Color(0.95, 0.42, 0.38))
			var btn: Button = _make_gamer_action_btn(
				"🎯 " + _get_player_short_name(opp_pid),
				"",
				t_stats,
				Color(0.08, 0.06, 0.06, 0.72),
				f_col.lightened(0.32),
				f_col.darkened(0.45),
				f_col.lightened(0.25),
				84.0,
				false,
				26
			)
			var target_id_cap: int = opp_pid
			btn.pressed.connect(func() -> void:
				_dispatch_action(_pending_target_action, target_id_cap)
			)
			t_grid.add_child(btn)

		var cancel_btn: Button = Button.new()
		cancel_btn.text = "↩ بازگشت به اقدامات"
		cancel_btn.custom_minimum_size = Vector2(0, 62)
		_style_action_button(cancel_btn, Color(0.20, 0.23, 0.28), Color(0.66, 0.70, 0.78), Color.WHITE, 25)
		cancel_btn.pressed.connect(func() -> void:
			AudioManager.sfx_tap()
			_pending_target_action = ""
			_refresh_3d_opponents()
			_rebuild_action_dock()
		)
		actions_container.add_child(cancel_btn)
		return

	# 2. Sacrifice Card Prompt
	if phase == "lose_influence":
		if pending_loss_player == my_player_index:
			_add_dock_info_panel("💔 زمان از دست دادن نفوذ!\nروی یکی از کارت‌های درخشان سمت چپ بزنید تا سوزانده شود.", Color(1.0, 0.62, 0.60), Color(0.32, 0.09, 0.11, 0.92), Color(1.0, 0.42, 0.40, 0.88), 27)
		else:
			_add_dock_info_panel("⏳ %s در حال انتخاب کارت برای حذف شدن است..." % _get_player_short_name(pending_loss_player), Color(1.0, 0.88, 0.56), Color(0.16, 0.12, 0.07, 0.85), Color(0.90, 0.72, 0.34, 0.65), 27)
		return

	# 3. Ambassador Exchange Phase
	if phase == "exchange":
		if current_turn == my_player_index:
			_add_dock_info_panel("📜 نوبت مبادله کارت با دیوان دربار است!", Color(0.56, 0.98, 0.72), Color(0.08, 0.24, 0.14, 0.90), Color(0.45, 0.94, 0.62, 0.85), 27)
			var open_ex: Button = Button.new()
			open_ex.text = "📜 انتخاب کارت‌های جدید"
			open_ex.custom_minimum_size = Vector2(330, 72)
			open_ex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_style_action_button(open_ex, Color(0.12, 0.54, 0.28), Color(0.48, 0.96, 0.64), Color.WHITE, 27)
			open_ex.pressed.connect(func() -> void:
				if is_instance_valid(exchange_backdrop):
					exchange_backdrop.visible = true
			)
			actions_container.add_child(open_ex)
		else:
			_add_dock_info_panel("📜 %s در حال انتخاب کارت‌های جدید با سفیر است..." % _get_player_short_name(current_turn), Color(0.90, 0.95, 0.88), Color(0.10, 0.16, 0.12, 0.85), Color(0.48, 0.84, 0.58, 0.65), 27)
		return

	# 4. Challenge / Block Response Window
	if phase in ["challenge_action", "block_action", "challenge_block"]:
		if _is_my_response_needed():
			var desc: String = _build_response_prompt_detail()
			var p_bd: Color = Color(1.0, 0.74, 0.26, 0.90) if phase != "block_action" else Color(0.36, 0.76, 1.0, 0.90)
			_add_dock_info_panel(desc, Color(1.0, 0.94, 0.58), Color(0.18, 0.12, 0.06, 0.92), p_bd, 26)

			var resp_grid: GridContainer = GridContainer.new()
			resp_grid.columns = 2
			resp_grid.add_theme_constant_override("h_separation", 10)
			resp_grid.add_theme_constant_override("v_separation", 10)
			resp_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions_container.add_child(resp_grid)

			var pass_btn: Button = Button.new()
			pass_btn.text = "✅ قبول / رد شدن"
			pass_btn.custom_minimum_size = Vector2(0, 86)
			pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_action_button(pass_btn, Color(0.14, 0.50, 0.27), Color(0.44, 0.94, 0.58), Color.WHITE, 26)
			pass_btn.pressed.connect(_on_pass_pressed)
			resp_grid.add_child(pass_btn)

			if phase in ["challenge_action", "challenge_block"]:
				var chal_btn: Button = Button.new()
				chal_btn.text = "⚡ بلوف می‌گیرد! (چالش)"
				chal_btn.custom_minimum_size = Vector2(0, 86)
				chal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_style_action_button(chal_btn, Color(0.76, 0.18, 0.18), Color(1.0, 0.58, 0.42), Color.WHITE, 26)
				chal_btn.pressed.connect(_on_challenge_pressed)
				resp_grid.add_child(chal_btn)
			elif phase == "block_action":
				var allowed_roles: Array = ACTION_ALLOWED_BLOCKS.get(pending_action, [])
				for r_var: Variant in allowed_roles:
					var r_id: String = String(r_var)
					var has_r: bool = _has_my_hidden_role(r_id)
					var hint_txt: String = "✓ کارت دارید" if has_r else "🎭 ادعای بلوف"
					var h_bg: Color = Color(0.10, 0.52, 0.24, 0.95) if has_r else Color(0.42, 0.16, 0.52, 0.92)
					var h_bd: Color = Color(0.45, 0.98, 0.62) if has_r else Color(0.86, 0.62, 1.0)
					var r_col: Color = CoupCardWidgetScript.get_role_color(r_id)
					var blk_btn: Button = _make_gamer_action_btn(
						"🛡️ دفاع با %s" % CoupCardWidgetScript.get_role_name_fa(r_id),
						"",
						hint_txt,
						h_bg,
						h_bd,
						r_col,
						r_col.lightened(0.40),
						86.0,
						false,
						25
					)
					var role_cap: String = r_id
					blk_btn.pressed.connect(func() -> void:
						_on_block_pressed(role_cap)
					)
					resp_grid.add_child(blk_btn)
		else:
			var passed_cnt: int = passed_players.size()
			var elig_cnt: int = max(1, eligible_responders.size())
			_add_dock_info_panel("⏳ در انتظار پاسخ سایر بازیکنان (%s از %s رد شده‌اند)..." % [CoupCardWidgetScript.to_fa_digits(str(passed_cnt)), CoupCardWidgetScript.to_fa_digits(str(elig_cnt))], Color(0.96, 0.92, 0.80), Color(0.12, 0.10, 0.08, 0.85), Color(0.75, 0.64, 0.42, 0.55), 26)
		return

	# 5. Main Action Turn
	if phase == "action" and is_my_turn:
		var coins: int = _get_my_coins()
		var must_coup: bool = (coins >= 10)

		var turn_lbl: Label = Label.new()
		turn_lbl.text = "⚠️ ۱۰+ سکه دارید! اجرای «کودتا» اجباری است:" if must_coup else "🎭 نوبت شماست — اقدام خود را انتخاب کنید:"
		turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		turn_lbl.add_theme_font_override("font", FontHekayat)
		turn_lbl.add_theme_font_size_override("font_size", 25)
		turn_lbl.add_theme_color_override("font_color", Color(1.0, 0.68, 0.36) if must_coup else Color(0.60, 0.98, 0.72))
		turn_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		turn_lbl.add_theme_constant_override("outline_size", 3)
		actions_container.add_child(turn_lbl)

		var grid: GridContainer = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		actions_container.add_child(grid)

		var action_specs: Array[Dictionary] = [
			{"id": "income", "title": "🪙 درآمد", "cost": "+۱🪙", "hint": "امن • بدون دفاع", "role": "", "min_c": 0, "bg": Color(0.16, 0.36, 0.24), "bd": Color(0.48, 0.88, 0.58)},
			{"id": "foreign_aid", "title": "🤝 کمک خارجی", "cost": "+۲🪙", "hint": "دفاع با دوک", "role": "", "min_c": 0, "bg": Color(0.14, 0.34, 0.46), "bd": Color(0.48, 0.84, 0.98)},
			{"id": "tax", "title": "👑 مالیات دوک", "cost": "+۳🪙", "hint": "", "role": "duke", "min_c": 0, "bg": Color(0.42, 0.16, 0.62), "bd": Color(0.84, 0.60, 1.0)},
			{"id": "steal", "title": "⚓ سرقت کاپیتان", "cost": "+۲🪙", "hint": "", "role": "captain", "min_c": 0, "bg": Color(0.10, 0.34, 0.68), "bd": Color(0.50, 0.84, 1.0)},
			{"id": "assassinate", "title": "🗡️ ترور آدم‌کش", "cost": "-۳🪙", "hint": "", "role": "assassin", "min_c": 3, "bg": Color(0.56, 0.12, 0.20), "bd": Color(1.0, 0.54, 0.58)},
			{"id": "exchange", "title": "📜 مبادله سفیر", "cost": "تعویض", "hint": "", "role": "ambassador", "min_c": 0, "bg": Color(0.12, 0.46, 0.27), "bd": Color(0.50, 0.94, 0.66)},
		]

		for spec: Dictionary in action_specs:
			var act_id: String = String(spec["id"])
			var role_req: String = String(spec["role"])
			var min_c: int = int(spec["min_c"])
			var is_dis: bool = (coins < min_c) or (must_coup and act_id != "coup")

			var badge_txt: String = String(spec["hint"])
			var badge_bg: Color = Color(0.08, 0.14, 0.14, 0.72)
			var badge_bd: Color = Color(0.55, 0.78, 0.80, 0.60)
			if is_dis:
				badge_txt = "⚠️ فقط کودتا مجاز است" if must_coup else ("🔒 نیاز به %s سکه" % CoupCardWidgetScript.to_fa_digits(str(min_c)))
			elif not role_req.is_empty():
				var owns: bool = _has_my_hidden_role(role_req)
				badge_txt = "✓ کارت دارید" if owns else "🎭 بلوف"
				badge_bg = Color(0.10, 0.54, 0.24, 0.94) if owns else Color(0.42, 0.14, 0.52, 0.90)
				badge_bd = Color(0.48, 0.98, 0.64) if owns else Color(0.86, 0.60, 1.0)

			var btn: Button = _make_gamer_action_btn(
				String(spec["title"]),
				String(spec["cost"]),
				badge_txt,
				badge_bg,
				badge_bd,
				spec["bg"],
				spec["bd"],
				84.0,
				is_dis,
				25
			)
			var cap_act: String = act_id
			btn.pressed.connect(func() -> void:
				_on_action_button_pressed(cap_act)
			)
			grid.add_child(btn)

		# Full-width Hero Coup Button
		var coup_dis: bool = (coins < 7)
		var coup_badge: String = "🔒 نیاز به ۷ سکه (فعلاً %s سکه)" % CoupCardWidgetScript.to_fa_digits(str(coins)) if coup_dis else ("⚡ کودتای اجباری — غیرقابل دفاع!" if must_coup else "🔥 غیرقابل دفاع • حذف فوری ۱ کارت حریف")
		var coup_btn: Button = _make_gamer_action_btn(
			"💥 اجرای کودتا" + (" (اجباری)" if must_coup else ""),
			"-۷🪙",
			coup_badge,
			Color(0.62, 0.16, 0.06, 0.95) if not coup_dis else Color(0.18, 0.16, 0.18, 0.82),
			Color(1.0, 0.86, 0.34),
			Color(0.78, 0.28, 0.08) if not must_coup else Color(0.88, 0.22, 0.10),
			Color(1.0, 0.84, 0.28),
			74.0,
			coup_dis,
			27
		)
		coup_btn.pressed.connect(func() -> void:
			_on_action_button_pressed("coup")
		)
		actions_container.add_child(coup_btn)
		return

	# 6. Default Waiting State (Opponent's Action Turn)
	var active_name: String = _get_player_short_name(current_turn)
	var opp_info: Dictionary = _get_player_entry(current_turn)
	var opp_coins: int = int(opp_info.get("coins", 0))
	var wait_txt: String = "⏳ نوبت «%s» است؛ آماده پاسخ یا بلوف‌گیری بمانید!" % active_name
	if opp_coins >= 10:
		wait_txt += "\n⚠️ %s بالای ۱۰ سکه دارد و مجبور به اجرای کودتاست!" % active_name
	elif opp_coins >= 7:
		wait_txt += "\n🪙 %s اکنون %s سکه دارد (امکان اجرای کودتا یا ترور)." % [active_name, CoupCardWidgetScript.to_fa_digits(str(opp_coins))]
	_add_dock_info_panel(wait_txt, Color(0.96, 0.93, 0.82), Color(0.11, 0.09, 0.07, 0.82), Color(0.82, 0.66, 0.32, 0.52), 26)

func _add_dock_info_label(txt: String, col: Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	lbl.add_theme_constant_override("outline_size", 3)
	actions_container.add_child(lbl)

func _add_dock_info_panel(txt: String, text_col: Color, bg_col: Color, bd_col: Color, f_size: int = 26) -> void:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: StyleBoxFlat = _make_glass_style(bg_col, bd_col, 16, 2)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", st)
	actions_container.add_child(p)

	var lbl: Label = Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FontHekayat)
	lbl.add_theme_font_size_override("font_size", f_size)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	lbl.add_theme_constant_override("outline_size", 3)
	p.add_child(lbl)

func _build_response_prompt_detail() -> String:
	var actor_n: String = _get_player_short_name(pending_actor)
	var target_n: String = _get_player_short_name(pending_target)
	if phase == "challenge_action":
		var role_fa: String = CoupCardWidgetScript.get_role_name_fa(pending_claimed_role)
		var act_fa: String = String(ACTION_NAMES_FA.get(pending_action, pending_action))
		if pending_target > 0:
			return "⚡ %s ادعای «%s» برای %s علیه %s کرد!" % [actor_n, role_fa, act_fa, target_n]
		return "⚡ %s ادعای «%s» برای %s کرد!" % [actor_n, role_fa, act_fa]
	elif phase == "block_action":
		if pending_action == "foreign_aid":
			return "🛡️ %s قصد گرفتن کمک خارجی (+۲🪙) دارد؛ با دوک مسدود می‌کنید؟" % actor_n
		elif pending_action == "assassinate":
			return "🗡️ %s قصد ترور شما را دارد! اگر کنتس دارید (یا بلوف می‌زنید) دفاع کنید:" % actor_n
		elif pending_action == "steal":
			return "⚓ %s قصد سرقت ۲ سکه از شما دارد! با کاپیتان یا سفیر دفاع کنید:" % actor_n
	elif phase == "challenge_block":
		var blocker_n: String = _get_player_short_name(pending_blocker)
		var b_role_fa: String = CoupCardWidgetScript.get_role_name_fa(pending_block_role)
		return "⚡ %s با نقش «%s» دفاع کرد! آیا بلوف می‌گیرد؟" % [blocker_n, b_role_fa]
	return ""

func _refresh_exchange_modal() -> void:
	if not is_instance_valid(exchange_backdrop):
		return
	var should_open: bool = GameManager.is_game_active and (phase == "exchange") and (current_turn == my_player_index) and not exchange_cards.is_empty()
	if not should_open:
		exchange_backdrop.visible = false
		_selected_exchange_indices.clear()
		return

	exchange_backdrop.visible = true
	var need_cnt: int = clampi(exchange_keep_count, 1, 2)
	var valid_sel: Array[int] = []
	for i: int in _selected_exchange_indices:
		if i >= 0 and i < exchange_cards.size() and i not in valid_sel:
			valid_sel.append(i)
	_selected_exchange_indices = valid_sel
	if _selected_exchange_indices.size() > need_cnt:
		_selected_exchange_indices = _selected_exchange_indices.slice(0, need_cnt)

	if is_instance_valid(exchange_subtitle_lbl):
		exchange_subtitle_lbl.text = "دقیقاً %s کارت را برای نگه داشتن انتخاب کنید (%s از %s انتخاب شده)" % [
			CoupCardWidgetScript.to_fa_digits(str(need_cnt)),
			CoupCardWidgetScript.to_fa_digits(str(_selected_exchange_indices.size())),
			CoupCardWidgetScript.to_fa_digits(str(need_cnt)),
		]

	if is_instance_valid(exchange_cards_hbox):
		for ch: Node in exchange_cards_hbox.get_children():
			ch.queue_free()
		for idx: int in range(exchange_cards.size()):
			var cv: Variant = exchange_cards[idx]
			if typeof(cv) != TYPE_DICTIONARY:
				continue
			var cd: Dictionary = cv as Dictionary
			var is_sel: bool = idx in _selected_exchange_indices
			var cw: CoupCardWidget = CoupCardWidgetScript.new()
			cw.setup_card(idx, cd, true, is_sel, Vector2(174, 248))
			cw.card_clicked.connect(_on_exchange_card_clicked)
			exchange_cards_hbox.add_child(cw)

	if is_instance_valid(exchange_confirm_btn):
		var ready: bool = (_selected_exchange_indices.size() == need_cnt)
		_style_action_button(
			exchange_confirm_btn,
			Color(0.12, 0.56, 0.28),
			Color(0.48, 0.96, 0.64),
			Color.WHITE,
			28,
			not ready
		)

# ==============================================================================
# 5. USER INTERACTION HANDLERS
# ==============================================================================

func _on_action_button_pressed(act_id: String) -> void:
	if not is_my_turn or phase != "action" or not GameManager.is_game_active:
		return
	AudioManager.sfx_button()
	if act_id in ["coup", "assassinate", "steal"]:
		var opps: Array[int] = _get_alive_opponents()
		if opps.is_empty():
			return
		if opps.size() == 1:
			_dispatch_action(act_id, opps[0])
			return
		_pending_target_action = act_id
		_refresh_3d_opponents()
		_rebuild_action_dock()
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("🎯 هدف %s را روی میز یا از پنل پایین انتخاب کنید" % String(ACTION_NAMES_FA.get(act_id, act_id)), Color(1.0, 0.86, 0.28), 2.2)
		return
	_dispatch_action(act_id, 0)

func _on_3d_seat_clicked(seat_slot: int) -> void:
	if _pending_target_action.is_empty() or phase != "action" or not is_my_turn:
		return
	if not _seat_slot_to_pid.has(seat_slot):
		return
	var target_pid: int = int(_seat_slot_to_pid[seat_slot])
	if not _is_player_alive(target_pid):
		return
	AudioManager.sfx_button()
	_dispatch_action(_pending_target_action, target_pid)

func _dispatch_action(act_id: String, target_id: int) -> void:
	_pending_target_action = ""
	AudioManager.sfx_move_piece()
	var payload: Dictionary = {"action": act_id}
	if target_id > 0:
		payload["target_id"] = target_id
	send_move(Commands.Coup_Action, payload)

func _on_pass_pressed() -> void:
	if not _is_my_response_needed():
		return
	AudioManager.sfx_tap()
	send_move(Commands.Coup_Pass, {})

func _on_challenge_pressed() -> void:
	if not _is_my_response_needed() or phase not in ["challenge_action", "challenge_block"]:
		return
	AudioManager.sfx_button()
	send_move(Commands.Coup_Challenge, {})

func _on_block_pressed(role_id: String) -> void:
	if not _is_my_response_needed() or phase != "block_action":
		return
	AudioManager.sfx_button()
	send_move(Commands.Coup_Block, {"block_role": role_id})

func _on_my_card_clicked(card_idx: int, card_dict: Dictionary, _widget: Control) -> void:
	if not GameManager.is_game_active:
		return
	if phase != "lose_influence" or pending_loss_player != my_player_index:
		return
	if bool(card_dict.get("revealed", false)):
		return
	AudioManager.sfx_button()
	var uid: int = int(card_dict.get("uid", -1))
	var payload: Dictionary = {"card_index": card_idx}
	if uid > 0:
		payload["card_uid"] = uid
	send_move(Commands.Coup_Lose_Influence, payload)

func _on_exchange_card_clicked(card_idx: int, _card_dict: Dictionary, _widget: Control) -> void:
	if phase != "exchange" or current_turn != my_player_index:
		return
	AudioManager.sfx_tap()
	var need_cnt: int = clampi(exchange_keep_count, 1, 2)
	if card_idx in _selected_exchange_indices:
		_selected_exchange_indices.erase(card_idx)
	else:
		if _selected_exchange_indices.size() >= need_cnt:
			_selected_exchange_indices.pop_front()
		_selected_exchange_indices.append(card_idx)
	_refresh_exchange_modal()

func _on_confirm_exchange_pressed() -> void:
	var need_cnt: int = clampi(exchange_keep_count, 1, 2)
	if phase != "exchange" or current_turn != my_player_index:
		return
	if _selected_exchange_indices.size() != need_cnt:
		return
	AudioManager.sfx_button()
	var indices_to_send: Array = []
	for idx: int in _selected_exchange_indices:
		indices_to_send.append(idx)
	exchange_backdrop.visible = false
	send_move(Commands.Coup_Exchange, {"keep_indices": indices_to_send})

func _on_open_roles_modal() -> void:
	AudioManager.sfx_tap()
	if is_instance_valid(roles_modal_backdrop):
		roles_modal_backdrop.visible = true

func _on_zoom_cycle_pressed() -> void:
	AudioManager.sfx_tap()
	var table: Node = get_tree().get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		return
	_zoom_preset_idx = (_zoom_preset_idx + 1) % 3
	if _zoom_preset_idx == 0:
		camera_distance = 2.42
		camera_pitch = -0.82
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 2.42
		table.target_pitch = -0.82
		table.target_yaw = 0.0
		if zoom_btn:
			zoom_btn.text = "🔍 نما"
	elif _zoom_preset_idx == 1:
		camera_distance = 2.95
		camera_pitch = -0.74
		if table.is_top_down_view:
			table.set_top_down_view(false, 0.45)
		table.target_distance = 2.95
		table.target_pitch = -0.74
		table.target_yaw = 0.0
		if zoom_btn:
			zoom_btn.text = "🔍 سالن"
	else:
		table.top_down_target_height = 2.45
		table.set_top_down_view(true, 0.45)
		if zoom_btn:
			zoom_btn.text = "🔍 بالا"

# ==============================================================================
# 6. AUTHORITATIVE BACKEND STATE SYNC & EVENT TOASTS
# ==============================================================================

func _apply_coup_state_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	_match_started = true

	var new_seq: int = int(data.get("state_seq", 0))
	if new_seq > 0 and state_seq > 0 and new_seq < state_seq:
		return
	if new_seq > 0:
		state_seq = new_seq

	if data.has("players_count") and data["players_count"] != null:
		total_players = clampi(int(data["players_count"]), 2, 4)
	if data.has("phase") and data["phase"] != null:
		var old_phase: String = phase
		phase = String(data["phase"])
		if phase != "action" or old_phase != phase:
			_pending_target_action = ""
		if phase != "exchange":
			_selected_exchange_indices.clear()
	if data.has("deck_remaining") and data["deck_remaining"] != null:
		deck_remaining = int(data["deck_remaining"])
	if data.has("players") and typeof(data["players"]) == TYPE_ARRAY:
		players_state = (data["players"] as Array).duplicate(true)
	if data.has("my_cards") and typeof(data["my_cards"]) == TYPE_ARRAY:
		my_cards = (data["my_cards"] as Array).duplicate(true)
	if data.has("exchange_cards") and typeof(data["exchange_cards"]) == TYPE_ARRAY:
		exchange_cards = (data["exchange_cards"] as Array).duplicate(true)
	elif phase != "exchange":
		exchange_cards.clear()

	if data.has("pending_action"):
		pending_action = "" if data["pending_action"] == null else String(data["pending_action"])
	if data.has("pending_actor") and data["pending_actor"] != null:
		pending_actor = int(data["pending_actor"])
	if data.has("pending_target") and data["pending_target"] != null:
		pending_target = int(data["pending_target"])
	if data.has("pending_claimed_role"):
		pending_claimed_role = "" if data["pending_claimed_role"] == null else String(data["pending_claimed_role"])
	if data.has("pending_blocker") and data["pending_blocker"] != null:
		pending_blocker = int(data["pending_blocker"])
	if data.has("pending_block_role"):
		pending_block_role = "" if data["pending_block_role"] == null else String(data["pending_block_role"])
	if data.has("eligible_responders") and typeof(data["eligible_responders"]) == TYPE_ARRAY:
		eligible_responders = (data["eligible_responders"] as Array).duplicate(true)
	if data.has("passed_players") and typeof(data["passed_players"]) == TYPE_ARRAY:
		passed_players = (data["passed_players"] as Array).duplicate(true)
	if data.has("pending_loss_player") and data["pending_loss_player"] != null:
		pending_loss_player = int(data["pending_loss_player"])
	if data.has("loss_reason"):
		loss_reason = "" if data["loss_reason"] == null else String(data["loss_reason"])
	if data.has("exchange_keep_count") and data["exchange_keep_count"] != null:
		exchange_keep_count = int(data["exchange_keep_count"])

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

	my_player_index = max(1, GameManager.my_player_index)
	is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn

	var t_lim: float = float(data.get("time_limit", -1.0)) if data.has("time_limit") and data["time_limit"] != null else -1.0
	_sync_phase_timer(t_lim)
	_refresh_all_visuals()

func _show_coup_event_feedback(ev: Dictionary) -> void:
	if not is_instance_valid(vfx_layer) or ev.is_empty():
		return
	var seq: int = int(ev.get("state", {}).get("state_seq", 0)) if typeof(ev.get("state")) == TYPE_DICTIONARY else state_seq
	if seq > 0 and seq == _last_event_seq:
		return
	if seq > 0:
		_last_event_seq = seq

	var ev_type: String = String(ev.get("event", ""))
	match ev_type:
		"action_declared":
			var actor_n: String = _get_player_short_name(int(ev.get("actor_id", 0)))
			var act: String = String(ev.get("action", ""))
			if act == "income":
				vfx_layer.show_contextual_toast("🪙 %s درآمد (+۱ سکه) گرفت" % actor_n, Color(0.55, 0.92, 0.62), 1.8)
			elif act == "foreign_aid":
				vfx_layer.show_contextual_toast("🤝 %s درخواست کمک خارجی (+۲ سکه) کرد" % actor_n, Color(0.45, 0.84, 1.0), 2.1)
			else:
				var role_fa: String = CoupCardWidgetScript.get_role_name_fa(String(ev.get("claimed_role", "")))
				var act_fa: String = String(ACTION_NAMES_FA.get(act, act))
				vfx_layer.show_contextual_toast("🎭 %s با ادعای «%s» اقدام به %s کرد" % [actor_n, role_fa, act_fa], Color(1.0, 0.84, 0.32), 2.4)
		"coup_launched":
			var actor_n2: String = _get_player_short_name(int(ev.get("actor_id", 0)))
			var target_n2: String = _get_player_short_name(int(ev.get("target_id", 0)))
			AudioManager.sfx_lose()
			vfx_layer.play_special_effect_badge("💥 کودتا علیه %s!" % target_n2, Color(0.95, 0.30, 0.18), 1.55)
			vfx_layer.show_contextual_toast("💥 %s علیه %s کودتا کرد!" % [actor_n2, target_n2], Color(1.0, 0.45, 0.32), 2.5)
		"block_declared":
			var blocker_n: String = _get_player_short_name(int(ev.get("blocker_id", 0)))
			var b_role_fa: String = CoupCardWidgetScript.get_role_name_fa(String(ev.get("block_role", "")))
			vfx_layer.play_special_effect_badge("🛡️ دفاع با %s" % b_role_fa, Color(0.32, 0.70, 1.0), 1.35)
			vfx_layer.show_contextual_toast("🛡️ %s با نقش «%s» دفاع کرد!" % [blocker_n, b_role_fa], Color(0.48, 0.84, 1.0), 2.3)
		"challenge_result":
			var chal_n: String = _get_player_short_name(int(ev.get("challenger_id", 0)))
			var claimed_n: String = _get_player_short_name(int(ev.get("claimed_by", 0)))
			var c_role_fa: String = CoupCardWidgetScript.get_role_name_fa(String(ev.get("claimed_role", "")))
			var won: bool = bool(ev.get("challenge_won", false))
			if won:
				AudioManager.sfx_win()
				vfx_layer.play_special_effect_badge("⚡ بلوف %s لو رفت!" % claimed_n, Color(1.0, 0.32, 0.28), 1.65)
				vfx_layer.show_contextual_toast("⚡ %s مچ %s را گرفت! (%s نداشت)" % [chal_n, claimed_n, c_role_fa], Color(1.0, 0.45, 0.38), 2.8)
			else:
				AudioManager.sfx_lose()
				vfx_layer.play_special_effect_badge("👑 ادعای %s واقعی بود!" % claimed_n, Color(0.35, 0.90, 0.56), 1.65)
				vfx_layer.show_contextual_toast("✅ %s کارت «%s» را رو کرد؛ %s یک نفوذ از دست داد!" % [claimed_n, c_role_fa, chal_n], Color(0.48, 0.96, 0.68), 2.8)
		"action_resolved":
			var act_r: String = String(ev.get("action", ""))
			var actor_r: String = _get_player_short_name(int(ev.get("actor_id", 0)))
			if act_r == "tax":
				vfx_layer.show_contextual_toast("👑 %s +۳ سکه مالیات دریافت کرد" % actor_r, Color(0.84, 0.58, 1.0), 2.0)
			elif act_r == "foreign_aid":
				vfx_layer.show_contextual_toast("🤝 %s +۲ سکه کمک خارجی گرفت" % actor_r, Color(0.48, 0.86, 1.0), 2.0)
			elif act_r == "steal":
				var targ_r: String = _get_player_short_name(int(ev.get("target_id", 0)))
				var st_amt: int = int(ev.get("stolen", 0))
				vfx_layer.show_contextual_toast("⚓ %s %s سکه از %s دزدید!" % [actor_r, CoupCardWidgetScript.to_fa_digits(str(st_amt)), targ_r], Color(0.52, 0.86, 1.0), 2.2)
		"assassinate_hit":
			var targ_a: String = _get_player_short_name(int(ev.get("target_id", 0)))
			AudioManager.sfx_lose()
			vfx_layer.play_special_effect_badge("🗡️ ترور موفق!", Color(0.82, 0.16, 0.24), 1.45)
			vfx_layer.show_contextual_toast("🗡️ ترور %s به سرانجام رسید!" % targ_a, Color(1.0, 0.45, 0.48), 2.3)
		"block_succeeded":
			var b_n: String = _get_player_short_name(int(ev.get("blocker_id", 0)))
			vfx_layer.show_contextual_toast("🛡️ دفاع %s با موفقیت اقدام را خنثی کرد" % b_n, Color(0.50, 0.84, 1.0), 2.1)
		"influence_lost":
			var g_n: String = _get_player_short_name(int(ev.get("gamer_id", 0)))
			var l_role: String = CoupCardWidgetScript.get_role_name_fa(String(ev.get("lost_role", "")))
			var elim: bool = bool(ev.get("eliminated", false))
			if elim:
				vfx_layer.play_special_effect_badge("💀 %s حذف شد!" % g_n, Color(0.75, 0.15, 0.18), 1.6)
				vfx_layer.show_contextual_toast("💀 %s با از دست دادن «%s» از بازی حذف شد!" % [g_n, l_role], Color(1.0, 0.42, 0.42), 2.8)
			else:
				vfx_layer.show_contextual_toast("💔 %s کارت «%s» خود را سوزاند" % [g_n, l_role], Color(1.0, 0.62, 0.45), 2.2)
		"exchange_completed":
			var ex_n: String = _get_player_short_name(int(ev.get("actor_id", 0)))
			vfx_layer.show_contextual_toast("📜 %s کارت‌هایش را با دیوان مبادله کرد" % ex_n, Color(0.50, 0.96, 0.66), 2.0)

func setup_board(game_data: Dictionary) -> void:
	_match_started = true
	if game_data.has("gamers") and typeof(game_data["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(game_data["gamers"] as Array)
	var inner: Variant = game_data.get("game_data", game_data)
	if typeof(inner) == TYPE_DICTIONARY:
		_apply_coup_state_dict(inner as Dictionary)
	if game_data.has("user_data") and typeof(game_data["user_data"]) == TYPE_DICTIONARY:
		_apply_coup_state_dict(game_data["user_data"] as Dictionary)
	_update_hud_visibility()

func on_start_game() -> void:
	_match_started = true
	super.on_start_game()
	_sync_phase_timer()
	_refresh_all_visuals()
	_update_hud_visibility()

func on_start_game_data(payload: Dictionary) -> void:
	_match_started = true
	_apply_coup_state_dict(payload)
	_update_hud_visibility()

func _on_user_data_received(payload: Dictionary) -> void:
	if payload.has("my_cards") or payload.has("players"):
		_apply_coup_state_dict(payload)

func on_turn_data(payload: Dictionary) -> void:
	if payload.has("phase") or payload.has("players"):
		_apply_coup_state_dict(payload)

func on_turn_changed(turn: int, _is_me: bool) -> void:
	current_turn = turn
	is_my_turn = (turn == GameManager.my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn
	_refresh_all_visuals()

func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"] as Array)
	var g_data: Variant = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_coup_state_dict(g_data as Dictionary)
	if payload.has("user_data") and typeof(payload["user_data"]) == TYPE_DICTIONARY:
		_apply_coup_state_dict(payload["user_data"] as Dictionary)
	_update_hud_visibility()

func _on_coup_event_received(cmd_id: String, payload: Dictionary) -> void:
	if cmd_id == Commands.Coup_State:
		_apply_coup_state_dict(payload)
	elif cmd_id == Commands.Coup_Event:
		if payload.has("state") and typeof(payload["state"]) == TYPE_DICTIONARY:
			_apply_coup_state_dict(payload["state"] as Dictionary)
		_show_coup_event_feedback(payload)

func on_not_played_turns_updated(gamer_id: int, count: int) -> void:
	if count <= 0 or not is_instance_valid(vfx_layer):
		return
	var p_name: String = _get_player_short_name(gamer_id)
	var fa_cnt: String = CoupCardWidgetScript.to_fa_digits(str(count))
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
	phase = "action"
	state_seq = 0
	_last_timer_seq = -1
	_last_event_seq = -1
	_pending_target_action = ""
	_selected_exchange_indices.clear()
	players_state.clear()
	my_cards.clear()
	exchange_cards.clear()
	if is_instance_valid(exchange_backdrop):
		exchange_backdrop.visible = false
	if is_instance_valid(roles_modal_backdrop):
		roles_modal_backdrop.visible = false
	_refresh_all_visuals()
	_update_hud_visibility()

func cleanup_board() -> void:
	if hud_root and is_instance_valid(hud_root):
		hud_root.queue_free()
	if hud_layer and is_instance_valid(hud_layer):
		hud_layer.queue_free()
