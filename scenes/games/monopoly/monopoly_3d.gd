extends BaseGameBoard

# Monopoly3D - Monopoly (مونوپولی) 3D Tabletop & Gamer-Friendly Large-Font HUD
# - Ludo-inspired walnut & brass 3D cabinet, 32 perimeter tiles, 3D houses/hotels, dual Yatzy dice, and royal clearcoat pawns.
# - Complete 2-4 player Monopoly rules: Buy/Auction, Houses/Hotels, Mortgage/Unmortgage, Jail options, Debt resolution, and Player Trade.
# - Gamer-friendly high-contrast typography (24px-38px UI, 34px-54px 3D).

const MonopolyData = preload("res://scenes/games/monopoly/components/monopoly_data.gd")
const MonopolyBoard3DScript = preload("res://scenes/games/monopoly/components/monopoly_board_3d.gd")
const FontHekayat: Font = preload("res://assets/fonts/hekayat.ttf")

# --- Camera Framing (Mandatory on BaseGameBoard scenes) ---
var camera_distance: float = 2.68
var camera_pitch: float = -0.84

# --- Authoritative Monopoly State ---
var total_players: int = 2
var phase: String = "roll" # roll | buy_or_auction | auction | debt | manage | trade | finished
var state_seq: int = 0
var round_number: int = 1
var last_dice: Array = [0, 0]
var players_state: Array = []
var tiles_state: Array = []
var pending_tile_id: int = -1
var auction_state: Dictionary = {}
var debt_state: Dictionary = {}
var pending_trade: Dictionary = {}
var trades_this_turn: int = 0
var bonus_doubles: bool = false
var buildable_tiles: Array = []
var sellable_tiles: Array = []
var mortgageable_tiles: Array = []
var unmortgageable_tiles: Array = []
var rank1_player: int = 0
var rank2_player: int = 0

var _match_started: bool = false
var _last_timer_seq: int = -1
var _last_event_seq: int = -1
var _zoom_preset_idx: int = 0
var _is_animating_turn: bool = false
var _last_feed_text: String = "در انتظار شروع بازی..."

# Pointer tap tracking (never interferes with camera orbit/zoom)
var _pointer_down_pos: Vector2 = Vector2.ZERO
var _pointer_down_time: float = 0.0
var _is_pointer_down: bool = false

# Trade Builder Draft State
var _trade_target_id: int = 0
var _trade_offer_cash: int = 0
var _trade_request_cash: int = 0
var _trade_offer_tiles: Array[int] = []
var _trade_request_tiles: Array[int] = []

# --- 3D Board Component ---
var board_3d: Node3D

# --- 2D HUD & Modals ---
var hud_layer: CanvasLayer
var hud_root: Control
var status_pill: PanelContainer
var status_label: Label
var zoom_btn: Button
var portfolio_btn: Button
var trade_btn: Button

var bottom_dock: Control
var dock_panel: PanelContainer
var my_cash_lbl: Label
var my_props_lbl: Label
var my_jail_lbl: Label
var dock_info_lbl: Label
var actions_vbox: VBoxContainer

var portfolio_backdrop: ColorRect
var portfolio_list_vbox: VBoxContainer
var portfolio_title_lbl: Label

var inspector_backdrop: ColorRect
var inspector_card_vbox: VBoxContainer

var trade_builder_backdrop: ColorRect
var trade_builder_vbox: VBoxContainer

var trade_incoming_backdrop: ColorRect
var trade_incoming_vbox: VBoxContainer

var card_popup_panel: PanelContainer
var card_popup_title: Label
var card_popup_desc: Label
var _card_popup_seq: int = 0


func _init() -> void:
	camera_distance = 2.68
	camera_pitch = -0.84


func _ready() -> void:
	game_type = GameTypes.MONOPOLY
	_setup_board_3d()
	_build_hud()
	super._ready()
	_connect_monopoly_signals()
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


func _setup_board_3d() -> void:
	board_3d = MonopolyBoard3DScript.new()
	board_3d.name = "MonopolyBoard3D"
	board_3d.players_count = _get_total_players()
	add_child(board_3d)
	board_3d.tile_clicked.connect(_on_3d_tile_clicked)
	board_3d.dice_sanctuary_clicked.connect(_on_3d_dice_sanctuary_clicked)


func _connect_monopoly_signals() -> void:
	if NetworkManager.has_signal("monopoly_event_received"):
		if not NetworkManager.monopoly_event_received.is_connected(_on_monopoly_event_received):
			NetworkManager.monopoly_event_received.connect(_on_monopoly_event_received)
	if not NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.connect(_on_win_happened)
	if not NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.connect(_on_internal_reconnect_data)


func _disconnect_monopoly_signals() -> void:
	if NetworkManager.has_signal("monopoly_event_received"):
		if NetworkManager.monopoly_event_received.is_connected(_on_monopoly_event_received):
			NetworkManager.monopoly_event_received.disconnect(_on_monopoly_event_received)
	if NetworkManager.win_happened_received.is_connected(_on_win_happened):
		NetworkManager.win_happened_received.disconnect(_on_win_happened)
	if NetworkManager.reconnect_data_received.is_connected(_on_internal_reconnect_data):
		NetworkManager.reconnect_data_received.disconnect(_on_internal_reconnect_data)


func _exit_tree() -> void:
	_disconnect_monopoly_signals()
	super._exit_tree()


# ==============================================================================
# 1. STYLING & LARGE-FONT UI HELPERS
# ==============================================================================

func _make_glass_style(bg: Color, border: Color, radius: int = 18, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _style_btn(btn: Button, bg: Color, border: Color, text_col: Color = Color.WHITE, f_size: int = 26, disabled: bool = false) -> void:
	btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", f_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.12))
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.66, 0.78))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_stylebox_override("normal", _make_glass_style(bg, border, 16, 2))
	btn.add_theme_stylebox_override("hover", _make_glass_style(bg.lightened(0.10), border.lightened(0.16), 16, 2))
	btn.add_theme_stylebox_override("pressed", _make_glass_style(bg.darkened(0.10), border, 16, 2))
	btn.add_theme_stylebox_override("disabled", _make_glass_style(Color(0.14, 0.13, 0.16, 0.74), Color(0.36, 0.34, 0.38, 0.50), 16, 1))
	btn.disabled = disabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND


func _make_lbl(txt: String, f_size: int = 26, col: Color = Color(0.98, 0.96, 0.90), align: int = HORIZONTAL_ALIGNMENT_RIGHT, outline: int = 3) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", FontHekayat)
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ==============================================================================
# 2. HUD & MODALS CONSTRUCTION
# ==============================================================================

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_layer.name = "MonopolyHUDLayer"
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "MonopolyHUDRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# 1. Floating Top Utility & Live Event Bar
	status_pill = PanelContainer.new()
	status_pill.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_pill.offset_left = 20
	status_pill.offset_right = -20
	status_pill.offset_top = 316
	status_pill.offset_bottom = 398
	status_pill.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.07, 0.05, 0.04, 0.92), Color(0.92, 0.74, 0.32, 0.85), 22, 2)
	)
	hud_root.add_child(status_pill)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 12)
	pm.add_theme_constant_override("margin_right", 14)
	pm.add_theme_constant_override("margin_top", 6)
	pm.add_theme_constant_override("margin_bottom", 6)
	status_pill.add_child(pm)

	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", 8)
	pm.add_child(phb)

	zoom_btn = Button.new()
	zoom_btn.text = "🔍 نما"
	zoom_btn.custom_minimum_size = Vector2(102, 54)
	_style_btn(zoom_btn, Color(0.14, 0.22, 0.30, 0.95), Color(0.56, 0.78, 0.95, 0.85), Color(0.95, 0.98, 1.0), 24)
	zoom_btn.pressed.connect(_on_zoom_cycle_pressed)
	phb.add_child(zoom_btn)

	portfolio_btn = Button.new()
	portfolio_btn.text = "🏘️ املاک من"
	portfolio_btn.custom_minimum_size = Vector2(142, 54)
	_style_btn(portfolio_btn, Color(0.16, 0.34, 0.22, 0.96), Color(0.45, 0.90, 0.56, 0.88), Color(0.96, 1.0, 0.96), 24)
	portfolio_btn.pressed.connect(_open_portfolio_modal)
	phb.add_child(portfolio_btn)

	trade_btn = Button.new()
	trade_btn.text = "🤝 معامله"
	trade_btn.custom_minimum_size = Vector2(126, 54)
	_style_btn(trade_btn, Color(0.38, 0.22, 0.08, 0.96), Color(0.96, 0.74, 0.28, 0.88), Color(1.0, 0.96, 0.86), 24)
	trade_btn.pressed.connect(_open_trade_builder_modal)
	phb.add_child(trade_btn)

	status_label = _make_lbl(_last_feed_text, 25, Color(1.0, 0.95, 0.82), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phb.add_child(status_label)

	# 2. Bottom Floating Gamer Action Dock
	bottom_dock = Control.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 20
	bottom_dock.offset_right = -20
	bottom_dock.offset_top = -470
	bottom_dock.offset_bottom = -130
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	var dock_vb := VBoxContainer.new()
	dock_vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_vb.alignment = BoxContainer.ALIGNMENT_END
	dock_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(dock_vb)

	dock_panel = PanelContainer.new()
	dock_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.08, 0.06, 0.05, 0.94), Color(0.90, 0.72, 0.30, 0.88), 24, 2)
	)
	dock_vb.add_child(dock_panel)

	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_left", 16)
	dm.add_theme_constant_override("margin_right", 16)
	dm.add_theme_constant_override("margin_top", 12)
	dm.add_theme_constant_override("margin_bottom", 14)
	dock_panel.add_child(dm)

	var inner_vb := VBoxContainer.new()
	inner_vb.add_theme_constant_override("separation", 10)
	dm.add_child(inner_vb)

	# Stats Strip (My Cash, My Properties, My Jail Cards)
	var stats_hb := HBoxContainer.new()
	stats_hb.add_theme_constant_override("separation", 12)
	inner_vb.add_child(stats_hb)

	my_cash_lbl = _make_lbl("💵 ۱۵۰۰$", 30, Color(0.45, 0.98, 0.56), HORIZONTAL_ALIGNMENT_LEFT, 3)
	stats_hb.add_child(my_cash_lbl)

	my_props_lbl = _make_lbl("🏠 ۰ ملک", 26, Color(1.0, 0.90, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 3)
	my_props_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_hb.add_child(my_props_lbl)

	my_jail_lbl = _make_lbl("🎫 کارت آزادی: ۰", 24, Color(0.70, 0.88, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 2)
	stats_hb.add_child(my_jail_lbl)

	dock_info_lbl = _make_lbl("برای مشاهده سند هر خانه، روی آن در صفحه ضربه بزنید.", 25, Color(0.95, 0.93, 0.88), HORIZONTAL_ALIGNMENT_CENTER, 2)
	inner_vb.add_child(dock_info_lbl)

	actions_vbox = VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 10)
	inner_vb.add_child(actions_vbox)

	# 3. Centered Modals
	_build_portfolio_modal()
	_build_inspector_modal()
	_build_trade_builder_modal()
	_build_trade_incoming_modal()
	_build_card_popup()


func _build_portfolio_modal() -> void:
	portfolio_backdrop = ColorRect.new()
	portfolio_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	portfolio_backdrop.color = Color(0.02, 0.02, 0.03, 0.78)
	portfolio_backdrop.visible = false
	portfolio_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			portfolio_backdrop.visible = false
	)
	hud_root.add_child(portfolio_backdrop)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	portfolio_backdrop.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 1080)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_glass_style(Color(0.09, 0.07, 0.06, 0.98), Color(0.94, 0.76, 0.34, 0.92), 26, 3))
	cc.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var btn_x := Button.new()
	btn_x.text = "✕ بستن"
	btn_x.custom_minimum_size = Vector2(140, 62)
	_style_btn(btn_x, Color(0.45, 0.14, 0.16, 0.96), Color(0.95, 0.45, 0.45, 0.9), Color.WHITE, 25)
	btn_x.pressed.connect(func(): portfolio_backdrop.visible = false)
	hdr.add_child(btn_x)

	portfolio_title_lbl = _make_lbl("🏘️ مدیریت املاک و ساخت‌وساز", 34, Color(1.0, 0.88, 0.42), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	portfolio_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(portfolio_title_lbl)

	var sub := _make_lbl("ساخت خانه فقط پس از مالکیت هر ۲ ملک هم‌رنگ و به‌صورت متعادل مجاز است.", 24, Color(0.84, 0.88, 0.92), HORIZONTAL_ALIGNMENT_RIGHT, 2)
	vb.add_child(sub)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)

	portfolio_list_vbox = VBoxContainer.new()
	portfolio_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portfolio_list_vbox.add_theme_constant_override("separation", 12)
	sc.add_child(portfolio_list_vbox)


func _build_inspector_modal() -> void:
	inspector_backdrop = ColorRect.new()
	inspector_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspector_backdrop.color = Color(0.02, 0.02, 0.03, 0.72)
	inspector_backdrop.visible = false
	inspector_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			inspector_backdrop.visible = false
	)
	hud_root.add_child(inspector_backdrop)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspector_backdrop.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_glass_style(Color(0.09, 0.08, 0.07, 0.98), Color(0.95, 0.80, 0.36, 0.94), 24, 3))
	cc.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(m)

	inspector_card_vbox = VBoxContainer.new()
	inspector_card_vbox.add_theme_constant_override("separation", 12)
	m.add_child(inspector_card_vbox)


func _build_trade_builder_modal() -> void:
	trade_builder_backdrop = ColorRect.new()
	trade_builder_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	trade_builder_backdrop.color = Color(0.02, 0.02, 0.03, 0.78)
	trade_builder_backdrop.visible = false
	trade_builder_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			trade_builder_backdrop.visible = false
	)
	hud_root.add_child(trade_builder_backdrop)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	trade_builder_backdrop.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 1080)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_glass_style(Color(0.08, 0.07, 0.09, 0.98), Color(0.96, 0.74, 0.28, 0.94), 26, 3))
	cc.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(m)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(sc)

	trade_builder_vbox = VBoxContainer.new()
	trade_builder_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trade_builder_vbox.add_theme_constant_override("separation", 14)
	sc.add_child(trade_builder_vbox)


func _build_trade_incoming_modal() -> void:
	trade_incoming_backdrop = ColorRect.new()
	trade_incoming_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	trade_incoming_backdrop.color = Color(0.02, 0.02, 0.03, 0.80)
	trade_incoming_backdrop.visible = false
	hud_root.add_child(trade_incoming_backdrop)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	trade_incoming_backdrop.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_glass_style(Color(0.10, 0.08, 0.06, 0.98), Color(0.98, 0.80, 0.30, 0.96), 26, 3))
	cc.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 26)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(m)

	trade_incoming_vbox = VBoxContainer.new()
	trade_incoming_vbox.add_theme_constant_override("separation", 14)
	m.add_child(trade_incoming_vbox)


func _build_card_popup() -> void:
	card_popup_panel = PanelContainer.new()
	card_popup_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card_popup_panel.offset_left = -360
	card_popup_panel.offset_right = 360
	card_popup_panel.offset_top = 420
	card_popup_panel.offset_bottom = 620
	card_popup_panel.visible = false
	card_popup_panel.add_theme_stylebox_override("panel", _make_glass_style(Color(0.14, 0.08, 0.04, 0.97), Color(1.0, 0.82, 0.28, 0.96), 22, 3))
	card_popup_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			card_popup_panel.visible = false
	)
	hud_root.add_child(card_popup_panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 16)
	card_popup_panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)

	card_popup_title = _make_lbl("🎴 کارت شانس", 34, Color(1.0, 0.88, 0.36), HORIZONTAL_ALIGNMENT_CENTER, 3)
	vb.add_child(card_popup_title)

	card_popup_desc = _make_lbl("", 26, Color(0.98, 0.96, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 2)
	vb.add_child(card_popup_desc)


# ==============================================================================
# 3. STATE HELPERS
# ==============================================================================

func _get_total_players() -> int:
	if total_players >= 2:
		return clampi(total_players, 2, 4)
	return clampi(max(2, GameManager.match_players.size()), 2, 4)


func _get_player_dict(pid: int) -> Dictionary:
	for pv in players_state:
		if typeof(pv) == TYPE_DICTIONARY and int(pv.get("gamer_id", 0)) == pid:
			return pv
	return {}


func _get_player_name(pid: int) -> String:
	var p := GameManager.get_player_data_by_gamer_id(pid)
	var nm := str(p.get("name", p.get("username", "")))
	if not nm.is_empty():
		return nm
	return "بازیکن %s" % MonopolyData.fa_num(pid)


func _get_tile_state(tid: int) -> Dictionary:
	if tid >= 0 and tid < tiles_state.size() and typeof(tiles_state[tid]) == TYPE_DICTIONARY:
		return tiles_state[tid]
	return {"id": tid, "owner": 0, "houses": 0, "mortgaged": false}


func _is_my_turn_acting() -> bool:
	var my_id: int = GameManager.my_player_index
	if my_id <= 0 or not GameManager.is_game_active:
		return false
	if phase == "finished":
		return false
	if phase == "auction":
		return int(auction_state.get("current_bidder", 0)) == my_id
	if phase == "debt":
		return int(debt_state.get("player_id", 0)) == my_id
	if phase == "trade":
		return int(pending_trade.get("to_player", 0)) == my_id
	return current_turn == my_id


func _owns_full_group_local(pid: int, grp: String) -> bool:
	if grp.is_empty() or not MonopolyData.STREET_GROUPS.has(grp):
		return false
	for tid in MonopolyData.STREET_GROUPS[grp]:
		if int(_get_tile_state(int(tid)).get("owner", 0)) != pid:
			return false
	return true


func _group_has_houses_local(grp: String) -> bool:
	if grp.is_empty() or not MonopolyData.STREET_GROUPS.has(grp):
		return false
	for tid in MonopolyData.STREET_GROUPS[grp]:
		if int(_get_tile_state(int(tid)).get("houses", 0)) > 0:
			return true
	return false


func _is_tradeable_local(pid: int, tid: int) -> bool:
	var ts := _get_tile_state(tid)
	if int(ts.get("owner", 0)) != pid:
		return false
	var meta := MonopolyData.get_tile(tid)
	if str(meta.get("type", "")) == "street" and _group_has_houses_local(str(meta.get("group", ""))):
		return false
	return true


# ==============================================================================
# 4. VISUAL & DOCK RENDERING
# ==============================================================================

func _refresh_all_visuals() -> void:
	_update_header_players()
	if is_instance_valid(board_3d):
		var can_roll_now: bool = (
			GameManager.is_game_active
			and phase == "roll"
			and current_turn == GameManager.my_player_index
			and not _is_animating_turn
		)
		board_3d.sync_board_visuals(players_state, tiles_state, current_turn, can_roll_now, last_dice)
	_refresh_hud_dock()
	_refresh_incoming_trade_modal()
	if portfolio_backdrop.visible:
		_populate_portfolio_list()


func _update_header_players() -> void:
	var tree := get_tree()
	if not tree:
		return
	var hud := tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var header: Node = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
		if is_instance_valid(header) and header.has_method("update_monopoly_players"):
			header.update_monopoly_players(players_state, rank1_player, rank2_player)


func _refresh_hud_dock() -> void:
	if not is_instance_valid(actions_vbox):
		return
	for ch in actions_vbox.get_children():
		ch.queue_free()

	if is_instance_valid(status_label):
		status_label.text = _last_feed_text

	var my_id: int = GameManager.my_player_index
	var me := _get_player_dict(my_id)
	var my_cash: int = int(me.get("cash", 1500))
	var my_owned: int = int(me.get("owned_count", 0))
	var my_jcards: int = int(me.get("jail_cards", 0))
	var in_jail: bool = bool(me.get("in_jail", false))
	var am_bankrupt: bool = bool(me.get("bankrupt", false))
	var my_turn_now: bool = (current_turn == my_id)

	if is_instance_valid(my_cash_lbl):
		my_cash_lbl.text = "💵 $%s" % MonopolyData.fa_num(my_cash)
		my_cash_lbl.add_theme_color_override("font_color", Color(1.0, 0.36, 0.36) if my_cash < 100 else Color(0.42, 0.98, 0.56))
	if is_instance_valid(my_props_lbl):
		my_props_lbl.text = "🏠 %s ملک" % MonopolyData.fa_num(my_owned)
	if is_instance_valid(my_jail_lbl):
		my_jail_lbl.text = "🎫 کارت آزادی: %s" % MonopolyData.fa_num(my_jcards)

	if is_instance_valid(portfolio_btn):
		var b_cnt: int = buildable_tiles.size() if my_turn_now else 0
		portfolio_btn.text = "🏘️ املاک (%s)" % MonopolyData.fa_num(b_cnt) if b_cnt > 0 else "🏘️ املاک من"

	if is_instance_valid(trade_btn):
		var can_open_trade: bool = GameManager.is_game_active and my_turn_now and phase in ["roll", "manage"] and trades_this_turn < 2 and not am_bankrupt
		trade_btn.disabled = not can_open_trade

	if not GameManager.is_game_active:
		dock_info_lbl.text = "⏳ در حال آماده‌سازی تخته مونوپولی..."
		return

	if am_bankrupt:
		dock_info_lbl.text = "💀 شما ورشکسته شده‌اید — در حال تماشای ادامه رقابت"
		return

	if _is_animating_turn:
		dock_info_lbl.text = "🎲 در حال حرکت مهره..."
		return

	# --- Phase 1: ROLL ---
	if phase == "roll":
		if my_turn_now:
			if in_jail:
				dock_info_lbl.text = "🔒 شما در زندان هستید! (تلاش %s از ۳)" % MonopolyData.fa_num(int(me.get("jail_turns", 0)) + 1)
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 10)
				actions_vbox.add_child(hb)

				var btn_rj := Button.new()
				btn_rj.text = "🎲 تاس جفت (رایگان)"
				btn_rj.custom_minimum_size = Vector2(0, 82)
				btn_rj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_style_btn(btn_rj, Color(0.14, 0.44, 0.72, 0.96), Color(0.50, 0.84, 1.0, 0.90), Color.WHITE, 26)
				btn_rj.pressed.connect(func(): _send_monopoly_action("roll_jail"))
				hb.add_child(btn_rj)

				var btn_bail := Button.new()
				btn_bail.text = "💰 وثیقه ۵۰$"
				btn_bail.custom_minimum_size = Vector2(0, 82)
				btn_bail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_style_btn(btn_bail, Color(0.68, 0.42, 0.08, 0.96), Color(1.0, 0.82, 0.30, 0.92), Color.WHITE, 26, my_cash < 50)
				btn_bail.pressed.connect(func(): _send_monopoly_action("pay_bail"))
				hb.add_child(btn_bail)

				if my_jcards > 0:
					var btn_jc := Button.new()
					btn_jc.text = "🎫 استفاده از کارت آزادی زندان"
					btn_jc.custom_minimum_size = Vector2(0, 74)
					_style_btn(btn_jc, Color(0.16, 0.56, 0.28, 0.96), Color(0.52, 0.96, 0.62, 0.92), Color.WHITE, 26)
					btn_jc.pressed.connect(func(): _send_monopoly_action("use_jail_card"))
					actions_vbox.add_child(btn_jc)
			else:
				dock_info_lbl.text = "🔥 تاس جفت آوردید! دوباره تاس بیندازید!" if bonus_doubles else "🎲 نوبت شماست! تاس بیندازید یا املاک خود را بسازید."
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 12)
				actions_vbox.add_child(hb)

				var btn_roll := Button.new()
				btn_roll.text = "🎲 پرتاب تاس"
				btn_roll.custom_minimum_size = Vector2(0, 86)
				btn_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_style_btn(btn_roll, Color(0.12, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 30)
				btn_roll.pressed.connect(_on_roll_pressed)
				hb.add_child(btn_roll)

				if not buildable_tiles.is_empty():
					var btn_bld := Button.new()
					btn_bld.text = "🏗️ ساخت‌وساز (%s)" % MonopolyData.fa_num(buildable_tiles.size())
					btn_bld.custom_minimum_size = Vector2(260, 86)
					_style_btn(btn_bld, Color(0.18, 0.34, 0.58, 0.96), Color(0.55, 0.80, 1.0, 0.90), Color.WHITE, 25)
					btn_bld.pressed.connect(_open_portfolio_modal)
					hb.add_child(btn_bld)
		else:
			dock_info_lbl.text = "⏳ در انتظار پرتاب تاس %s..." % _get_player_name(current_turn)
		return

	# --- Phase 2: BUY OR AUCTION ---
	if phase == "buy_or_auction":
		var meta := MonopolyData.get_tile(pending_tile_id)
		var t_name := str(meta.get("name", "ملک"))
		var price := int(meta.get("price", 0))
		if my_turn_now:
			var rents: Array = meta.get("rents", [])
			var base_r: int = int(rents[0]) if not rents.is_empty() else 0
			var rent_info: String = ("اجاره پایه $%s" % MonopolyData.fa_num(base_r)) if base_r > 0 else "املاک ویژه"
			dock_info_lbl.text = "🏠 ملک آزاد «%s» — قیمت: $%s (%s)" % [t_name, MonopolyData.fa_num(price), rent_info]

			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 12)
			actions_vbox.add_child(hb)

			var can_buy: bool = (my_cash >= price)
			var btn_buy := Button.new()
			btn_buy.text = "✅ خرید ملک ($%s)" % MonopolyData.fa_num(price)
			btn_buy.custom_minimum_size = Vector2(0, 86)
			btn_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_buy, Color(0.12, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 28, not can_buy)
			btn_buy.pressed.connect(func(): _send_monopoly_action("buy_property"))
			hb.add_child(btn_buy)

			var btn_auc := Button.new()
			btn_auc.text = "🔨 ارسال به مزایده"
			btn_auc.custom_minimum_size = Vector2(0, 86)
			btn_auc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_auc, Color(0.68, 0.36, 0.08, 0.96), Color(1.0, 0.76, 0.28, 0.92), Color.WHITE, 28)
			btn_auc.pressed.connect(func(): _send_monopoly_action("decline_buy"))
			hb.add_child(btn_auc)
		else:
			dock_info_lbl.text = "⏳ %s در حال تصمیم برای خرید «%s» ($%s)..." % [_get_player_name(current_turn), t_name, MonopolyData.fa_num(price)]
		return

	# --- Phase 3: AUCTION ---
	if phase == "auction" and not auction_state.is_empty():
		var a_tile := str(auction_state.get("tile_name", "ملک"))
		var cur_bid := int(auction_state.get("current_bid", 0))
		var leader_id := int(auction_state.get("highest_bidder", 0))
		var cur_bidder := int(auction_state.get("current_bidder", 0))
		var leader_txt := _get_player_name(leader_id) if leader_id > 0 else "بدون پیشنهاد"
		var min_next := 10 if cur_bid == 0 else cur_bid + 10
		dock_info_lbl.text = "🔨 مزایده «%s» | بالاترین: $%s (%s)" % [a_tile, MonopolyData.fa_num(cur_bid), leader_txt]

		if cur_bidder == my_id:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			actions_vbox.add_child(hb)

			var btn_b10 := Button.new()
			btn_b10.text = "💰 پیشنهاد $%s" % MonopolyData.fa_num(min_next)
			btn_b10.custom_minimum_size = Vector2(0, 84)
			btn_b10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_b10, Color(0.14, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 26, my_cash < min_next or leader_id == my_id)
			btn_b10.pressed.connect(func(): _send_monopoly_auction("bid", min_next))
			hb.add_child(btn_b10)

			var big_bid := min_next + 20
			var btn_b30 := Button.new()
			btn_b30.text = "🔥 $%s" % MonopolyData.fa_num(big_bid)
			btn_b30.custom_minimum_size = Vector2(180, 84)
			_style_btn(btn_b30, Color(0.62, 0.42, 0.08, 0.96), Color(1.0, 0.84, 0.30, 0.92), Color.WHITE, 26, my_cash < big_bid or leader_id == my_id)
			btn_b30.pressed.connect(func(): _send_monopoly_auction("bid", big_bid))
			hb.add_child(btn_b30)

			var btn_pass := Button.new()
			btn_pass.text = "❌ انصراف"
			btn_pass.custom_minimum_size = Vector2(190, 84)
			_style_btn(btn_pass, Color(0.56, 0.14, 0.16, 0.96), Color(0.96, 0.44, 0.44, 0.92), Color.WHITE, 26)
			btn_pass.pressed.connect(func(): _send_monopoly_auction("pass", 0))
			hb.add_child(btn_pass)
		else:
			var wait_lbl := _make_lbl("⏳ نوبت پیشنهاد %s در مزایده..." % _get_player_name(cur_bidder), 27, Color(1.0, 0.88, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 3)
			actions_vbox.add_child(wait_lbl)
		return

	# --- Phase 4: DEBT ---
	if phase == "debt" and not debt_state.is_empty():
		var d_pid := int(debt_state.get("player_id", 0))
		var d_amt := int(debt_state.get("amount", 0))
		var d_reason := str(debt_state.get("reason", "بدهی"))
		if d_pid == my_id:
			dock_info_lbl.text = "⚠️ بدهی فوری ($%s بابت %s) | نقد فعلی: $%s" % [MonopolyData.fa_num(d_amt), d_reason, MonopolyData.fa_num(my_cash)]
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			actions_vbox.add_child(hb)

			var btn_pay := Button.new()
			btn_pay.text = "💳 پرداخت بدهی ($%s)" % MonopolyData.fa_num(d_amt)
			btn_pay.custom_minimum_size = Vector2(0, 84)
			btn_pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_pay, Color(0.14, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 26, my_cash < d_amt)
			btn_pay.pressed.connect(func(): _send_monopoly_action("pay_debt"))
			hb.add_child(btn_pay)

			var btn_raise := Button.new()
			btn_raise.text = "🏚️ فروش / رهن"
			btn_raise.custom_minimum_size = Vector2(230, 84)
			_style_btn(btn_raise, Color(0.66, 0.40, 0.08, 0.96), Color(1.0, 0.80, 0.28, 0.92), Color.WHITE, 25)
			btn_raise.pressed.connect(_open_portfolio_modal)
			hb.add_child(btn_raise)

			var btn_bk := Button.new()
			btn_bk.text = "🏳️ ورشکستگی"
			btn_bk.custom_minimum_size = Vector2(200, 84)
			_style_btn(btn_bk, Color(0.56, 0.14, 0.16, 0.96), Color(0.96, 0.44, 0.44, 0.92), Color.WHITE, 25)
			btn_bk.pressed.connect(func(): _send_monopoly_action("declare_bankruptcy"))
			hb.add_child(btn_bk)
		else:
			dock_info_lbl.text = "⚠️ %s در حال تامین نقدینگی برای پرداخت بدهی $%s..." % [_get_player_name(d_pid), MonopolyData.fa_num(d_amt)]
		return

	# --- Phase 5: TRADE ---
	if phase == "trade" and not pending_trade.is_empty():
		var f_pid := int(pending_trade.get("from_player", 0))
		var t_pid := int(pending_trade.get("to_player", 0))
		dock_info_lbl.text = "🤝 %s پیشنهاد معامله برای %s فرستاده است..." % [_get_player_name(f_pid), _get_player_name(t_pid)]
		return

	# --- Phase 6: MANAGE ---
	if phase == "manage":
		if my_turn_now:
			dock_info_lbl.text = "✅ نوبت شما کامل شد — املاک را بسازید/معامله کنید یا نوبت را به نفر بعد بدهید."
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 12)
			actions_vbox.add_child(hb)

			var btn_end := Button.new()
			btn_end.text = "✅ پایان نوبت"
			btn_end.custom_minimum_size = Vector2(0, 86)
			btn_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_end, Color(0.14, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 30)
			btn_end.pressed.connect(func(): _send_monopoly_action("end_turn"))
			hb.add_child(btn_end)

			var bld_cnt: int = buildable_tiles.size()
			var btn_mgr := Button.new()
			btn_mgr.text = "🏗️ ساخت و رهن (%s)" % MonopolyData.fa_num(bld_cnt) if bld_cnt > 0 else "🏘️ مدیریت املاک"
			btn_mgr.custom_minimum_size = Vector2(280, 86)
			_style_btn(btn_mgr, Color(0.18, 0.34, 0.58, 0.96), Color(0.55, 0.80, 1.0, 0.90), Color.WHITE, 25)
			btn_mgr.pressed.connect(_open_portfolio_modal)
			hb.add_child(btn_mgr)
		else:
			dock_info_lbl.text = "⏳ %s در حال مدیریت املاک و پایان نوبت..." % _get_player_name(current_turn)
		return


# ==============================================================================
# 5. MODALS: PORTFOLIO / INSPECTOR / TRADE / CARD POPUP
# ==============================================================================

func _open_portfolio_modal() -> void:
	_populate_portfolio_list()
	portfolio_backdrop.visible = true


func _populate_portfolio_list() -> void:
	for ch in portfolio_list_vbox.get_children():
		ch.queue_free()

	var my_id: int = GameManager.my_player_index
	var me := _get_player_dict(my_id)
	var my_cash: int = int(me.get("cash", 0))
	var my_turn_now: bool = (current_turn == my_id and phase in ["roll", "manage"])
	var my_debt_now: bool = (phase == "debt" and int(debt_state.get("player_id", 0)) == my_id)

	if is_instance_valid(portfolio_title_lbl):
		portfolio_title_lbl.text = "🏘️ املاک من (نقد: $%s)" % MonopolyData.fa_num(my_cash)

	var owned_ids: Array[int] = []
	for tid in range(32):
		if int(_get_tile_state(tid).get("owner", 0)) == my_id:
			owned_ids.append(tid)

	if owned_ids.is_empty():
		var empty_lbl := _make_lbl("هنوز هیچ ملکی نخریده‌اید! با فرود روی خانه‌های آزاد یا شرکت در مزایده، املاک تهران را بخرید.", 28, Color(0.86, 0.84, 0.80), HORIZONTAL_ALIGNMENT_CENTER, 2)
		portfolio_list_vbox.add_child(empty_lbl)
		return

	for tid in owned_ids:
		var meta := MonopolyData.get_tile(tid)
		var ts := _get_tile_state(tid)
		var houses := int(ts.get("houses", 0))
		var mortgaged := bool(ts.get("mortgaged", false))
		var grp := str(meta.get("group", ""))
		var grp_col: Color = MonopolyData.GROUP_COLORS.get(grp, Color(0.4, 0.4, 0.45))

		var row_card := PanelContainer.new()
		row_card.add_theme_stylebox_override("panel", _make_glass_style(Color(0.14, 0.11, 0.10, 0.96), grp_col.lightened(0.25), 18, 2))
		portfolio_list_vbox.add_child(row_card)

		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 16)
		rm.add_theme_constant_override("margin_right", 16)
		rm.add_theme_constant_override("margin_top", 12)
		rm.add_theme_constant_override("margin_bottom", 12)
		row_card.add_child(rm)

		var rvb := VBoxContainer.new()
		rvb.add_theme_constant_override("separation", 8)
		rm.add_child(rvb)

		var top_hb := HBoxContainer.new()
		top_hb.add_theme_constant_override("separation", 10)
		rvb.add_child(top_hb)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(22, 42)
		swatch.color = grp_col
		top_hb.add_child(swatch)

		var house_txt: String = ""
		if mortgaged:
			house_txt = "🔒 در رهن"
		elif houses >= 5:
			house_txt = "🏨 هتل"
		elif houses > 0:
			house_txt = "🏠 ×%s خانه" % MonopolyData.fa_num(houses)
		elif _owns_full_group_local(my_id, grp):
			house_txt = "✨ ست کامل (اجاره ۲×)"
		else:
			house_txt = "گروه %s" % MonopolyData.GROUP_NAMES_FA.get(grp, "")

		var status_l := _make_lbl(house_txt, 24, Color(1.0, 0.72, 0.42) if mortgaged else Color(0.75, 0.96, 0.78), HORIZONTAL_ALIGNMENT_LEFT, 2)
		top_hb.add_child(status_l)

		var name_l := _make_lbl(str(meta.get("name", "")), 30, Color(1.0, 0.96, 0.88), HORIZONTAL_ALIGNMENT_RIGHT, 3)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_hb.add_child(name_l)

		var btns_hb := HBoxContainer.new()
		btns_hb.add_theme_constant_override("separation", 8)
		rvb.add_child(btns_hb)

		var h_cost: int = int(meta.get("house_cost", 0))
		var m_val: int = int(meta.get("price", 0)) / 2
		var u_cost: int = int(round(float(m_val) * 1.1))

		if my_turn_now and buildable_tiles.has(tid):
			var b_lbl: String = "🏨 +هتل (-$%s)" % MonopolyData.fa_num(h_cost) if houses == 4 else "🏠 +خانه (-$%s)" % MonopolyData.fa_num(h_cost)
			var btn_b := Button.new()
			btn_b.text = b_lbl
			btn_b.custom_minimum_size = Vector2(0, 62)
			btn_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_b, Color(0.12, 0.54, 0.26, 0.96), Color(0.46, 0.96, 0.56, 0.9), Color.WHITE, 23)
			var t_cap: int = tid
			btn_b.pressed.connect(func(): _send_monopoly_action("build_house", {"tile_id": t_cap}))
			btns_hb.add_child(btn_b)

		if (my_turn_now or my_debt_now) and sellable_tiles.has(tid):
			var btn_s := Button.new()
			btn_s.text = "🏚️ فروش خانه (+$%s)" % MonopolyData.fa_num(h_cost / 2)
			btn_s.custom_minimum_size = Vector2(0, 62)
			btn_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_s, Color(0.58, 0.34, 0.10, 0.96), Color(1.0, 0.72, 0.28, 0.9), Color.WHITE, 23)
			var t_cap2: int = tid
			btn_s.pressed.connect(func(): _send_monopoly_action("sell_house", {"tile_id": t_cap2}))
			btns_hb.add_child(btn_s)

		if (my_turn_now or my_debt_now) and mortgageable_tiles.has(tid):
			var btn_m := Button.new()
			btn_m.text = "🏦 رهن (+$%s)" % MonopolyData.fa_num(m_val)
			btn_m.custom_minimum_size = Vector2(0, 62)
			btn_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_m, Color(0.48, 0.20, 0.16, 0.96), Color(0.95, 0.54, 0.44, 0.9), Color.WHITE, 23)
			var t_cap3: int = tid
			btn_m.pressed.connect(func(): _send_monopoly_action("mortgage", {"tile_id": t_cap3}))
			btns_hb.add_child(btn_m)

		if my_turn_now and unmortgageable_tiles.has(tid):
			var btn_u := Button.new()
			btn_u.text = "🔓 فک رهن (-$%s)" % MonopolyData.fa_num(u_cost)
			btn_u.custom_minimum_size = Vector2(0, 62)
			btn_u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_btn(btn_u, Color(0.16, 0.38, 0.62, 0.96), Color(0.52, 0.82, 1.0, 0.9), Color.WHITE, 23)
			var t_cap4: int = tid
			btn_u.pressed.connect(func(): _send_monopoly_action("unmortgage", {"tile_id": t_cap4}))
			btns_hb.add_child(btn_u)


func _on_3d_tile_clicked(tid: int) -> void:
	AudioManager.sfx_tap()
	for ch in inspector_card_vbox.get_children():
		ch.queue_free()

	var meta := MonopolyData.get_tile(tid)
	var ts := _get_tile_state(tid)
	var t_type := str(meta.get("type", ""))
	var grp := str(meta.get("group", ""))
	var grp_col: Color = MonopolyData.GROUP_COLORS.get(grp, Color(0.75, 0.62, 0.30))

	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", _make_glass_style(grp_col, Color(1.0, 0.92, 0.72, 0.90), 16, 2))
	inspector_card_vbox.add_child(banner)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_top", 12)
	bm.add_theme_constant_override("margin_bottom", 12)
	banner.add_child(bm)
	bm.add_child(_make_lbl(str(meta.get("name", "")), 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3))

	var owner_id := int(ts.get("owner", 0))
	var owner_str: String = "آزاد (قابل خرید)" if owner_id == 0 else ("مالک: %s" % _get_player_name(owner_id))
	if bool(ts.get("mortgaged", false)):
		owner_str += " (🔒 در رهن)"
	inspector_card_vbox.add_child(_make_lbl(owner_str, 26, Color(1.0, 0.88, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 2))

	if t_type in ["street", "railroad", "utility"]:
		var price := int(meta.get("price", 0))
		inspector_card_vbox.add_child(_make_lbl("💰 قیمت خرید: $%s  |  🏦 ارزش رهن: $%s" % [MonopolyData.fa_num(price), MonopolyData.fa_num(price / 2)], 25, Color(0.92, 0.96, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 2))

	if t_type == "street":
		var rents: Array = meta.get("rents", [])
		if rents.size() >= 6:
			var lines: Array[String] = [
				"اجاره پایه: $%s  (با ست کامل: $%s)" % [MonopolyData.fa_num(rents[0]), MonopolyData.fa_num(int(rents[0]) * 2)],
				"با ۱ خانه: $%s  |  با ۲ خانه: $%s" % [MonopolyData.fa_num(rents[1]), MonopolyData.fa_num(rents[2])],
				"با ۳ خانه: $%s  |  با ۴ خانه: $%s" % [MonopolyData.fa_num(rents[3]), MonopolyData.fa_num(rents[4])],
				"🏨 با هتل: $%s  |  هزینه هر خانه: $%s" % [MonopolyData.fa_num(rents[5]), MonopolyData.fa_num(meta.get("house_cost", 0))],
			]
			for ln in lines:
				inspector_card_vbox.add_child(_make_lbl(ln, 24, Color(0.94, 0.92, 0.86), HORIZONTAL_ALIGNMENT_CENTER, 2))
	elif t_type == "railroad":
		inspector_card_vbox.add_child(_make_lbl("۱ ایستگاه: ۲۵$ | ۲ ایستگاه: ۵۰$ | ۳ ایستگاه: ۱۰۰$ | ۴ ایستگاه: ۲۰۰$", 24, Color(0.94, 0.92, 0.86), HORIZONTAL_ALIGNMENT_CENTER, 2))
	elif t_type == "utility":
		inspector_card_vbox.add_child(_make_lbl("۱ شرکت: ۴× مجموع تاس | هر ۲ شرکت: ۱۰× مجموع تاس", 24, Color(0.94, 0.92, 0.86), HORIZONTAL_ALIGNMENT_CENTER, 2))
	elif t_type == "tax":
		inspector_card_vbox.add_child(_make_lbl("مبلغ مالیات: $%s پرداخت به بانک" % MonopolyData.fa_num(meta.get("tax_amount", 0)), 26, Color(1.0, 0.72, 0.72), HORIZONTAL_ALIGNMENT_CENTER, 2))
	elif tid == 0:
		inspector_card_vbox.add_child(_make_lbl("هر بار عبور یا فرود روی خانه شروع ۲۰۰$ جایزه دریافت می‌کنید!", 25, Color(0.60, 0.98, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 2))
	elif tid == 8:
		inspector_card_vbox.add_child(_make_lbl("ملاقات آزاد است؛ اگر زندانی شوید با تاس جفت، وثیقه ۵۰$ یا کارت آزادی خارج می‌شوید.", 24, Color(0.94, 0.92, 0.86), HORIZONTAL_ALIGNMENT_CENTER, 2))

	var btn_close := Button.new()
	btn_close.text = "بستن"
	btn_close.custom_minimum_size = Vector2(0, 68)
	_style_btn(btn_close, Color(0.24, 0.22, 0.26, 0.96), Color(0.85, 0.72, 0.36, 0.9), Color.WHITE, 26)
	btn_close.pressed.connect(func(): inspector_backdrop.visible = false)
	inspector_card_vbox.add_child(btn_close)

	inspector_backdrop.visible = true


func _open_trade_builder_modal() -> void:
	var my_id: int = GameManager.my_player_index
	_trade_offer_cash = 0
	_trade_request_cash = 0
	_trade_offer_tiles.clear()
	_trade_request_tiles.clear()
	_trade_target_id = 0
	for pv in players_state:
		if typeof(pv) == TYPE_DICTIONARY:
			var gid := int(pv.get("gamer_id", 0))
			if gid != my_id and not bool(pv.get("bankrupt", false)) and bool(pv.get("alive", true)):
				_trade_target_id = gid
				break
	if _trade_target_id <= 0:
		show_hint("⚠️ حریف فعالی برای معامله وجود ندارد!")
		return
	_rebuild_trade_builder_ui()
	trade_builder_backdrop.visible = true


func _rebuild_trade_builder_ui() -> void:
	for ch in trade_builder_vbox.get_children():
		ch.queue_free()

	var my_id: int = GameManager.my_player_index
	var me := _get_player_dict(my_id)
	var target_d := _get_player_dict(_trade_target_id)
	var my_cash: int = int(me.get("cash", 0))
	var their_cash: int = int(target_d.get("cash", 0))

	var hdr := HBoxContainer.new()
	trade_builder_vbox.add_child(hdr)
	var btn_x := Button.new()
	btn_x.text = "✕ بستن"
	btn_x.custom_minimum_size = Vector2(140, 62)
	_style_btn(btn_x, Color(0.45, 0.14, 0.16, 0.96), Color(0.95, 0.45, 0.45, 0.9), Color.WHITE, 25)
	btn_x.pressed.connect(func(): trade_builder_backdrop.visible = false)
	hdr.add_child(btn_x)
	var t_lbl := _make_lbl("🤝 پیشنهاد معامله به حریف", 34, Color(1.0, 0.88, 0.42), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(t_lbl)

	# Opponent selector
	var opp_hb := HBoxContainer.new()
	opp_hb.add_theme_constant_override("separation", 8)
	trade_builder_vbox.add_child(opp_hb)
	for pv in players_state:
		if typeof(pv) != TYPE_DICTIONARY:
			continue
		var gid := int(pv.get("gamer_id", 0))
		if gid == my_id or bool(pv.get("bankrupt", false)) or not bool(pv.get("alive", true)):
			continue
		var btn_op := Button.new()
		btn_op.text = "%s ($%s)" % [_get_player_name(gid), MonopolyData.fa_num(int(pv.get("cash", 0)))]
		btn_op.custom_minimum_size = Vector2(0, 60)
		btn_op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_sel: bool = (gid == _trade_target_id)
		_style_btn(
			btn_op,
			Color(0.18, 0.46, 0.28, 0.96) if is_sel else Color(0.18, 0.16, 0.20, 0.92),
			Color(0.50, 0.95, 0.60, 0.95) if is_sel else Color(0.55, 0.55, 0.62, 0.70),
			Color.WHITE,
			24
		)
		var g_cap: int = gid
		btn_op.pressed.connect(func():
			_trade_target_id = g_cap
			_trade_request_tiles.clear()
			_trade_request_cash = 0
			_rebuild_trade_builder_ui()
		)
		opp_hb.add_child(btn_op)

	# My Offer Section
	trade_builder_vbox.add_child(_make_lbl("📤 چیزی که شما می‌دهید (نقد: $%s):" % MonopolyData.fa_num(_trade_offer_cash), 27, Color(0.98, 0.84, 0.48), HORIZONTAL_ALIGNMENT_RIGHT, 2))
	var oc_hb := HBoxContainer.new()
	oc_hb.add_theme_constant_override("separation", 8)
	trade_builder_vbox.add_child(oc_hb)
	for delta in [-100, -50, 50, 100]:
		var btn_c := Button.new()
		btn_c.text = "%s%s$" % ["+" if delta > 0 else "", MonopolyData.fa_num(delta)]
		btn_c.custom_minimum_size = Vector2(0, 58)
		btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_btn(btn_c, Color(0.24, 0.22, 0.18, 0.96), Color(0.90, 0.76, 0.36, 0.85), Color.WHITE, 24)
		var d_cap: int = int(delta)
		btn_c.pressed.connect(func():
			_trade_offer_cash = clampi(_trade_offer_cash + d_cap, 0, my_cash)
			_rebuild_trade_builder_ui()
		)
		oc_hb.add_child(btn_c)

	var my_prop_flow := HFlowContainer.new()
	my_prop_flow.add_theme_constant_override("h_separation", 8)
	my_prop_flow.add_theme_constant_override("v_separation", 8)
	trade_builder_vbox.add_child(my_prop_flow)
	for tid in range(32):
		if _is_tradeable_local(my_id, tid):
			var chosen := _trade_offer_tiles.has(tid)
			var b := Button.new()
			b.text = ("%s " % ("✓" if chosen else "")) + str(MonopolyData.get_tile(tid).get("name", ""))
			b.custom_minimum_size = Vector2(180, 56)
			_style_btn(b, Color(0.16, 0.50, 0.26, 0.96) if chosen else Color(0.18, 0.16, 0.16, 0.94), Color(0.55, 0.96, 0.62) if chosen else Color(0.65, 0.58, 0.45), Color.WHITE, 23)
			var t_cap: int = int(tid)
			b.pressed.connect(func():
				if _trade_offer_tiles.has(t_cap):
					_trade_offer_tiles.erase(t_cap)
				else:
					_trade_offer_tiles.append(t_cap)
				_rebuild_trade_builder_ui()
			)
			my_prop_flow.add_child(b)

	# Their Request Section
	trade_builder_vbox.add_child(_make_lbl("📥 چیزی که از %s می‌خواهید (نقد: $%s):" % [_get_player_name(_trade_target_id), MonopolyData.fa_num(_trade_request_cash)], 27, Color(0.65, 0.90, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 2))
	var rc_hb := HBoxContainer.new()
	rc_hb.add_theme_constant_override("separation", 8)
	trade_builder_vbox.add_child(rc_hb)
	for delta in [-100, -50, 50, 100]:
		var btn_c2 := Button.new()
		btn_c2.text = "%s%s$" % ["+" if delta > 0 else "", MonopolyData.fa_num(delta)]
		btn_c2.custom_minimum_size = Vector2(0, 58)
		btn_c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_btn(btn_c2, Color(0.18, 0.24, 0.30, 0.96), Color(0.52, 0.80, 0.96, 0.85), Color.WHITE, 24)
		var d_cap2: int = int(delta)
		btn_c2.pressed.connect(func():
			_trade_request_cash = clampi(_trade_request_cash + d_cap2, 0, their_cash)
			_rebuild_trade_builder_ui()
		)
		rc_hb.add_child(btn_c2)

	var th_prop_flow := HFlowContainer.new()
	th_prop_flow.add_theme_constant_override("h_separation", 8)
	th_prop_flow.add_theme_constant_override("v_separation", 8)
	trade_builder_vbox.add_child(th_prop_flow)
	for tid in range(32):
		if _is_tradeable_local(_trade_target_id, tid):
			var chosen2 := _trade_request_tiles.has(tid)
			var b2 := Button.new()
			b2.text = ("%s " % ("✓" if chosen2 else "")) + str(MonopolyData.get_tile(tid).get("name", ""))
			b2.custom_minimum_size = Vector2(180, 56)
			_style_btn(b2, Color(0.16, 0.42, 0.62, 0.96) if chosen2 else Color(0.18, 0.16, 0.16, 0.94), Color(0.52, 0.86, 1.0) if chosen2 else Color(0.65, 0.58, 0.45), Color.WHITE, 23)
			var t_cap2: int = int(tid)
			b2.pressed.connect(func():
				if _trade_request_tiles.has(t_cap2):
					_trade_request_tiles.erase(t_cap2)
				else:
					_trade_request_tiles.append(t_cap2)
				_rebuild_trade_builder_ui()
			)
			th_prop_flow.add_child(b2)

	var has_offer: bool = (_trade_offer_cash > 0 or not _trade_offer_tiles.is_empty())
	var has_req: bool = (_trade_request_cash > 0 or not _trade_request_tiles.is_empty())
	var btn_send := Button.new()
	btn_send.text = "📨 ارسال پیشنهاد معامله"
	btn_send.custom_minimum_size = Vector2(0, 78)
	_style_btn(btn_send, Color(0.14, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 28, not (has_offer and has_req))
	btn_send.pressed.connect(func():
		trade_builder_backdrop.visible = false
		AudioManager.sfx_tap()
		send_move(Commands.Monopoly_Trade, {
			"action": "propose",
			"target_id": _trade_target_id,
			"offer_cash": _trade_offer_cash,
			"offer_tiles": _trade_offer_tiles,
			"request_cash": _trade_request_cash,
			"request_tiles": _trade_request_tiles,
		})
	)
	trade_builder_vbox.add_child(btn_send)


func _refresh_incoming_trade_modal() -> void:
	var my_id: int = GameManager.my_player_index
	if phase != "trade" or pending_trade.is_empty() or int(pending_trade.get("to_player", 0)) != my_id:
		trade_incoming_backdrop.visible = false
		return

	for ch in trade_incoming_vbox.get_children():
		ch.queue_free()

	var f_pid := int(pending_trade.get("from_player", 0))
	var o_cash := int(pending_trade.get("offer_cash", 0))
	var r_cash := int(pending_trade.get("request_cash", 0))
	var o_tiles: Array = pending_trade.get("offer_tiles", [])
	var r_tiles: Array = pending_trade.get("request_tiles", [])

	trade_incoming_vbox.add_child(_make_lbl("🤝 پیشنهاد معامله از %s" % _get_player_name(f_pid), 34, Color(1.0, 0.88, 0.38), HORIZONTAL_ALIGNMENT_CENTER, 3))

	var give_names: Array[String] = []
	if r_cash > 0:
		give_names.append("$%s نقد" % MonopolyData.fa_num(r_cash))
	for tid in r_tiles:
		give_names.append(str(MonopolyData.get_tile(int(tid)).get("name", "")))

	var get_names: Array[String] = []
	if o_cash > 0:
		get_names.append("$%s نقد" % MonopolyData.fa_num(o_cash))
	for tid in o_tiles:
		get_names.append(str(MonopolyData.get_tile(int(tid)).get("name", "")))

	trade_incoming_vbox.add_child(_make_lbl("📥 دریافت می‌کنید: " + (" + ".join(get_names) if not get_names.is_empty() else "هیچ"), 27, Color(0.55, 0.98, 0.62), HORIZONTAL_ALIGNMENT_CENTER, 2))
	trade_incoming_vbox.add_child(_make_lbl("📤 پرداخت می‌کنید: " + (" + ".join(give_names) if not give_names.is_empty() else "هیچ"), 27, Color(1.0, 0.70, 0.60), HORIZONTAL_ALIGNMENT_CENTER, 2))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	trade_incoming_vbox.add_child(hb)

	var btn_acc := Button.new()
	btn_acc.text = "✅ قبول معامله"
	btn_acc.custom_minimum_size = Vector2(0, 82)
	btn_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(btn_acc, Color(0.14, 0.58, 0.28, 0.98), Color(0.46, 0.98, 0.58, 0.95), Color.WHITE, 28)
	btn_acc.pressed.connect(func():
		trade_incoming_backdrop.visible = false
		send_move(Commands.Monopoly_Trade, {"action": "accept"})
	)
	hb.add_child(btn_acc)

	var btn_rej := Button.new()
	btn_rej.text = "❌ رد معامله"
	btn_rej.custom_minimum_size = Vector2(0, 82)
	btn_rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(btn_rej, Color(0.56, 0.14, 0.16, 0.96), Color(0.96, 0.44, 0.44, 0.92), Color.WHITE, 28)
	btn_rej.pressed.connect(func():
		trade_incoming_backdrop.visible = false
		send_move(Commands.Monopoly_Trade, {"action": "reject"})
	)
	hb.add_child(btn_rej)

	trade_incoming_backdrop.visible = true


func _show_chance_chest_card(card: Dictionary, deck: String) -> void:
	_card_popup_seq += 1
	var my_seq: int = _card_popup_seq
	var icon_prefix: String = "🎲 کارت شانس: " if deck == "chance" else "📦 صندوق شانس: "
	card_popup_title.text = icon_prefix + str(card.get("title", ""))
	card_popup_desc.text = str(card.get("desc", ""))
	card_popup_panel.visible = true
	await get_tree().create_timer(3.2).timeout
	if _card_popup_seq == my_seq and is_instance_valid(card_popup_panel):
		card_popup_panel.visible = false


# ==============================================================================
# 6. USER ACTIONS & 3D TAP INPUT
# ==============================================================================

func _on_zoom_cycle_pressed() -> void:
	AudioManager.sfx_tap()
	_zoom_preset_idx = (_zoom_preset_idx + 1) % 3
	match _zoom_preset_idx:
		0:
			camera_distance = 2.68
			camera_pitch = -0.84
		1:
			camera_distance = 2.25
			camera_pitch = -0.78
		2:
			camera_distance = 3.05
			camera_pitch = -0.92
	_enforce_camera_framing()


func _on_3d_dice_sanctuary_clicked() -> void:
	if phase == "roll" and current_turn == GameManager.my_player_index and not _is_animating_turn:
		var me := _get_player_dict(GameManager.my_player_index)
		if bool(me.get("in_jail", false)):
			_send_monopoly_action("roll_jail")
		else:
			_on_roll_pressed()


func _on_roll_pressed() -> void:
	if is_board_locked or not GameManager.is_game_active or _is_animating_turn:
		return
	if current_turn != GameManager.my_player_index or phase != "roll":
		show_hint("⏳ اکنون نوبت پرتاب تاس شما نیست!")
		AudioManager.play_sound("wrong_Touch")
		return
	AudioManager.play_sound("dice")
	send_move(Commands.Monopoly_Roll, {})


func _send_monopoly_action(act: String, extra: Dictionary = {}) -> void:
	if is_board_locked or not GameManager.is_game_active:
		return
	AudioManager.sfx_tap()
	var data := {"action": act}
	for k in extra.keys():
		data[k] = extra[k]
	send_move(Commands.Monopoly_Action, data)


func _send_monopoly_auction(decision: String, amount: int) -> void:
	if not GameManager.is_game_active:
		return
	AudioManager.sfx_tap()
	send_move(Commands.Monopoly_Auction, {"decision": decision, "amount": amount})


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if portfolio_backdrop.visible or inspector_backdrop.visible or trade_builder_backdrop.visible or trade_incoming_backdrop.visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			# Ignore clicks on HUD top header or bottom dock area
			if mb.position.y < 410.0 or mb.position.y > get_viewport().get_visible_rect().size.y - 470.0:
				_is_pointer_down = false
				return
			_is_pointer_down = true
			_pointer_down_pos = mb.position
			_pointer_down_time = Time.get_ticks_msec() / 1000.0
		elif _is_pointer_down:
			_is_pointer_down = false
			var dt := (Time.get_ticks_msec() / 1000.0) - _pointer_down_time
			if dt <= 0.35 and mb.position.distance_to(_pointer_down_pos) <= 18.0:
				if is_instance_valid(board_3d):
					board_3d.handle_board_tap(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.position.y < 410.0 or st.position.y > get_viewport().get_visible_rect().size.y - 470.0:
				_is_pointer_down = false
				return
			_is_pointer_down = true
			_pointer_down_pos = st.position
			_pointer_down_time = Time.get_ticks_msec() / 1000.0
		elif _is_pointer_down:
			_is_pointer_down = false
			var dt2 := (Time.get_ticks_msec() / 1000.0) - _pointer_down_time
			if dt2 <= 0.35 and st.position.distance_to(_pointer_down_pos) <= 22.0:
				if is_instance_valid(board_3d):
					board_3d.handle_board_tap(st.position)


# ==============================================================================
# 7. NETWORK SYNC & EVENT ANIMATIONS
# ==============================================================================

func _apply_monopoly_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("players_count"):
		total_players = clampi(int(data["players_count"]), 2, 4)
	elif data.has("players") and typeof(data["players"]) == TYPE_ARRAY and data["players"].size() >= 2:
		total_players = clampi(data["players"].size(), 2, 4)

	if data.has("phase"):
		phase = str(data["phase"])
	if data.has("state_seq"):
		state_seq = int(data["state_seq"])
	if data.has("round_number"):
		round_number = int(data["round_number"])
	if data.has("current_turn"):
		current_turn = int(data["current_turn"])
		GameManager.current_turn = current_turn
	if data.has("last_dice") and typeof(data["last_dice"]) == TYPE_ARRAY:
		last_dice = (data["last_dice"] as Array).duplicate()
	if data.has("players") and typeof(data["players"]) == TYPE_ARRAY:
		players_state = (data["players"] as Array).duplicate(true)
	if data.has("tiles") and typeof(data["tiles"]) == TYPE_ARRAY:
		tiles_state = (data["tiles"] as Array).duplicate(true)
	if data.has("pending_tile_id"):
		pending_tile_id = int(data.get("pending_tile_id", -1))
	auction_state = (data["auction"] as Dictionary).duplicate(true) if typeof(data.get("auction")) == TYPE_DICTIONARY else {}
	debt_state = (data["debt"] as Dictionary).duplicate(true) if typeof(data.get("debt")) == TYPE_DICTIONARY else {}
	pending_trade = (data["pending_trade"] as Dictionary).duplicate(true) if typeof(data.get("pending_trade")) == TYPE_DICTIONARY else {}
	trades_this_turn = int(data.get("trades_this_turn", 0))
	bonus_doubles = bool(data.get("bonus_doubles", false))
	buildable_tiles = (data["buildable_tiles"] as Array).duplicate() if typeof(data.get("buildable_tiles")) == TYPE_ARRAY else []
	sellable_tiles = (data["sellable_tiles"] as Array).duplicate() if typeof(data.get("sellable_tiles")) == TYPE_ARRAY else []
	mortgageable_tiles = (data["mortgageable_tiles"] as Array).duplicate() if typeof(data.get("mortgageable_tiles")) == TYPE_ARRAY else []
	unmortgageable_tiles = (data["unmortgageable_tiles"] as Array).duplicate() if typeof(data.get("unmortgageable_tiles")) == TYPE_ARRAY else []

	if data.has("rank1") and data["rank1"] != null:
		rank1_player = int(data["rank1"])
		GameManager.ludo_rank1 = rank1_player
	if data.has("rank2") and data["rank2"] != null:
		rank2_player = int(data["rank2"])
		GameManager.ludo_rank2 = rank2_player

	is_my_turn = _is_my_turn_acting()
	var t_lim: float = float(data.get("time_limit", -1.0)) if data.has("time_limit") and data["time_limit"] != null else -1.0
	_sync_phase_timer(t_lim)


func _sync_phase_timer(time_limit_hint: float = -1.0) -> void:
	if not _match_started or not GameManager.is_game_active:
		return
	var tree := get_tree()
	if not tree:
		return
	var hud := tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if not is_instance_valid(hud) or not hud.has_method("start_turn_timer"):
		return
	if state_seq > 0 and state_seq == _last_timer_seq:
		return
	_last_timer_seq = state_seq
	var t_sec: float = time_limit_hint
	if t_sec <= 0.0:
		if phase in ["auction", "trade"]:
			t_sec = 14.0
		elif phase in ["buy_or_auction", "manage", "debt"]:
			t_sec = 25.0
		else:
			t_sec = 28.0
	var banner: String = _build_banner_text()
	hud.start_turn_timer(t_sec, banner)


func _build_banner_text() -> String:
	var my_id: int = GameManager.my_player_index
	match phase:
		"roll":
			if current_turn == my_id:
				return "🎲 نوبت شماست! تاس بیندازید"
			return "⏳ نوبت %s برای پرتاب تاس..." % _get_player_name(current_turn)
		"buy_or_auction":
			if current_turn == my_id:
				return "🏠 تصمیم خرید ملک یا برگزاری مزایده"
			return "⏳ %s در حال بررسی خرید ملک..." % _get_player_name(current_turn)
		"auction":
			var b_id := int(auction_state.get("current_bidder", 0))
			if b_id == my_id:
				return "🔨 نوبت پیشنهاد شما در مزایده!"
			return "🔨 مزایده — نوبت %s" % _get_player_name(b_id)
		"debt":
			var d_id := int(debt_state.get("player_id", 0))
			if d_id == my_id:
				return "⚠️ بدهی خود را تامین و پرداخت کنید"
			return "⚠️ %s در حال تسویه بدهی..." % _get_player_name(d_id)
		"trade":
			var t_id := int(pending_trade.get("to_player", 0))
			if t_id == my_id:
				return "🤝 پیشنهاد معامله جدید برای شما!"
			return "🤝 در انتظار پاسخ %s به معامله..." % _get_player_name(t_id)
		"manage":
			if current_turn == my_id:
				return "🏗️ مدیریت املاک یا پایان نوبت"
			return "⏳ %s در حال مدیریت املاک..." % _get_player_name(current_turn)
		"finished":
			return "🏆 پایان مسابقه مونوپولی!"
	return "مونوپولی"


func _describe_event(ev: Dictionary) -> String:
	var etype := str(ev.get("event", ""))
	var pid := int(ev.get("player_id", 0))
	var p_name := _get_player_name(pid)
	var t_name := str(ev.get("tile_name", ""))
	var amt := int(ev.get("amount", 0))

	match etype:
		"offer_purchase":
			return "🎲 %s به «%s» رسید ($%s)" % [p_name, t_name, MonopolyData.fa_num(amt if amt > 0 else int(ev.get("price", 0)))]
		"property_bought":
			AudioManager.play_sound("bell")
			return "🏠 %s ملک «%s» را خرید ($%s)" % [p_name, t_name, MonopolyData.fa_num(amt)]
		"rent_paid":
			var o_id := int(ev.get("owner_id", 0))
			return "💸 %s مبلغ $%s اجاره به %s داد" % [p_name, MonopolyData.fa_num(amt), _get_player_name(o_id)]
		"tax_paid":
			return "🏛️ %s مبلغ $%s مالیات پرداخت کرد" % [p_name, MonopolyData.fa_num(amt)]
		"card_drawn":
			var c: Dictionary = ev.get("card", {})
			return "🎴 %s: %s" % [p_name, str(c.get("title", "کارت شانس"))]
		"go_to_jail", "three_doubles_jail":
			AudioManager.play_sound("wrong_Touch")
			return "🚓 %s راهی زندان شد!" % p_name
		"bail_paid":
			return "💰 %s با پرداخت ۵۰$ از زندان آزاد شد" % p_name
		"jail_card_used":
			return "🎫 %s با کارت آزادی از زندان خارج شد" % p_name
		"jail_stay":
			return "🔒 %s تاس جفت نیاورد و در زندان ماند" % p_name
		"auction_started":
			return "🔨 مزایده برای «%s» آغاز شد!" % str(MonopolyData.get_tile(int(ev.get("tile_id", 0))).get("name", ""))
		"auction_bid":
			return "💰 پیشنهاد $%s از %s در مزایده" % [MonopolyData.fa_num(amt), p_name]
		"auction_won":
			AudioManager.play_sound("bell")
			var w_id := int(ev.get("winner_id", 0))
			return "🏆 %s ملک «%s» را با $%s برد!" % [_get_player_name(w_id), t_name, MonopolyData.fa_num(amt)]
		"auction_unsold":
			return "🔨 مزایده «%s» بدون خریدار بسته شد" % t_name
		"house_built":
			AudioManager.play_sound("bell")
			return "🏗️ %s در «%s» ساخت‌وساز کرد!" % [p_name, t_name]
		"house_sold":
			return "🏚️ %s یک خانه در «%s» فروخت" % [p_name, t_name]
		"property_mortgaged":
			return "🏦 %s ملک «%s» را رهن کرد (+$%s)" % [p_name, t_name, MonopolyData.fa_num(amt)]
		"property_unmortgaged":
			return "🔓 %s ملک «%s» را فک رهن کرد" % [p_name, t_name]
		"trade_accepted":
			AudioManager.play_sound("bell")
			return "🤝 معامله بین %s و %s انجام شد!" % [_get_player_name(int(ev.get("from_player", 0))), _get_player_name(int(ev.get("to_player", 0)))]
		"trade_rejected":
			return "❌ پیشنهاد معامله رد شد"
		"bankrupt":
			AudioManager.play_sound("wrong_Touch")
			return "💀 %s ورشکسته شد!" % p_name
		"turn_ended":
			return "🎲 نوبت %s آغاز شد" % _get_player_name(int(ev.get("next_turn", current_turn)))
	if ev.get("passed_go", false):
		return "💵 %s از خط شروع گذشت (+۲۰۰$)" % p_name
	return "🎲 %s به «%s» رفت" % [p_name, t_name]


func _on_monopoly_event_received(cmd_id: String, payload: Dictionary) -> void:
	_match_started = true
	if cmd_id == Commands.Monopoly_Event:
		if typeof(payload.get("state")) == TYPE_DICTIONARY:
			_apply_monopoly_state(payload["state"])
		var ev_seq: int = state_seq
		if ev_seq > 0 and ev_seq == _last_event_seq:
			_refresh_all_visuals()
			return
		_last_event_seq = ev_seq

		var txt := _describe_event(payload)
		if not txt.is_empty():
			_last_feed_text = txt

		if str(payload.get("event", "")) == "card_drawn" and typeof(payload.get("card")) == TYPE_DICTIONARY:
			_show_chance_chest_card(payload["card"], str(payload.get("deck", "chance")))

		var dice_arr: Array = payload.get("dice", [])
		var path_arr: Array = payload.get("path", [])
		var pid: int = int(payload.get("player_id", 0))
		if dice_arr.size() >= 2 and int(dice_arr[0]) > 0 and not path_arr.is_empty() and is_instance_valid(board_3d):
			_is_animating_turn = true
			_refresh_hud_dock()
			var p_d := _get_player_dict(pid)
			board_3d.animate_dice_and_hop(
				pid,
				int(dice_arr[0]),
				int(dice_arr[1]),
				path_arr,
				bool(p_d.get("in_jail", false)),
				func():
					_is_animating_turn = false
					_refresh_all_visuals()
			)
			return
		_refresh_all_visuals()
	elif cmd_id == Commands.Monopoly_State:
		_apply_monopoly_state(payload)
		_refresh_all_visuals()


func _on_win_happened(payload: Dictionary) -> void:
	if payload.has("rank1") and payload["rank1"] != null:
		rank1_player = int(payload["rank1"])
		GameManager.ludo_rank1 = rank1_player
	elif payload.has("Winner") and payload["Winner"] != null:
		rank1_player = int(payload["Winner"])
		GameManager.ludo_rank1 = rank1_player
	if payload.has("rank2") and payload["rank2"] != null:
		rank2_player = int(payload["rank2"])
		GameManager.ludo_rank2 = rank2_player
	phase = "finished"
	_update_header_players()
	_refresh_hud_dock()


func _update_hud_visibility() -> void:
	if not is_instance_valid(hud_layer):
		return
	var should_show := visible and is_inside_tree()
	hud_layer.visible = should_show


# ==============================================================================
# 8. BASEGAMEBOARD VIRTUAL LIFECYCLE HOOKS
# ==============================================================================

func setup_board(game_data: Dictionary) -> void:
	var g_list = game_data.get("gamers", GameManager.match_players)
	var p_cnt: int = g_list.size() if typeof(g_list) == TYPE_ARRAY and g_list.size() >= 2 else max(2, GameManager.match_players.size())
	total_players = clampi(p_cnt, 2, 4)
	if is_instance_valid(board_3d):
		board_3d.set_players_count(total_players)
	if game_data.has("game_data") and typeof(game_data["game_data"]) == TYPE_DICTIONARY:
		_apply_monopoly_state(game_data["game_data"])
	_refresh_all_visuals()


func on_start_game() -> void:
	_match_started = true
	set_board_locked(false)
	_enforce_camera_framing()
	_refresh_all_visuals()


func on_turn_data(payload: Dictionary) -> void:
	_match_started = true
	_apply_monopoly_state(payload)
	_refresh_all_visuals()


func on_turn_changed(_turn: int, _is_me: bool) -> void:
	_refresh_all_visuals()


func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	var g_data = payload.get("game_data", {})
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_monopoly_state(g_data)
	_enforce_camera_framing()
	_refresh_all_visuals()


func reset_board() -> void:
	_is_animating_turn = false
	_last_timer_seq = -1
	_last_event_seq = -1
	_refresh_all_visuals()
