extends BaseGameBoard

# Uno3D - Authentic 3D Tabletop UNO Scene on the Cafe Fekr Green Felt Table
# - True 3D tabletop gameplay: 3D Opponent Card Fans & 3D Floating Seat Badges around the table,
#   3D Dealer Shoe Draw Deck, 3D Stacked Discard Pile, 3D Color Crystal, and 3D UNO Bell
# - Gamer-friendly, zero-clutter HUD: Open floating curved card fan at the bottom (1-tap play!)
#   with contextual floating pills ONLY when needed (Pass Turn after drawing, UNO shout, or Draw prompt)

const UnoCardWidgetScript = preload("res://scenes/games/uno/components/uno_card_widget.gd")
const UnoTable3DScript = preload("res://scenes/games/uno/components/uno_table_3d.gd")
const UnoVFXOverlayScript = preload("res://scenes/games/uno/components/uno_vfx_layer.gd")
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

class WildColorWheelPicker extends Control:
	signal color_chosen(color_id: String)

	const QUADRANTS: Array[Dictionary] = [
		{"id": "red", "label": "قرمز", "col": Color(0.90, 0.16, 0.19), "txt": Color.WHITE},
		{"id": "blue", "label": "آبی", "col": Color(0.11, 0.46, 0.92), "txt": Color.WHITE},
		{"id": "green", "label": "سبز", "col": Color(0.13, 0.69, 0.31), "txt": Color.WHITE},
		{"id": "yellow", "label": "زرد", "col": Color(0.95, 0.76, 0.07), "txt": Color(0.14, 0.12, 0.04)},
	]

	var _hover_idx: int = -1
	var _font: Font = preload("res://assets/fonts/hekayat.ttf")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_exited.connect(func() -> void:
			if _hover_idx != -1:
				_hover_idx = -1
				queue_redraw()
		)

	func _hit_quadrant(local_pos: Vector2) -> int:
		var c: Vector2 = size * 0.5
		var r_outer: float = minf(size.x, size.y) * 0.47
		var r_inner: float = r_outer * 0.28
		var v: Vector2 = local_pos - c
		var dist: float = v.length()
		if dist < r_inner or dist > r_outer + 8.0:
			return -1
		var ang: float = atan2(v.y, v.x)
		if ang < 0.0:
			ang += TAU
		return clampi(int(floor(ang / (PI * 0.5))), 0, 3)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var idx: int = _hit_quadrant(event.position)
			if idx != _hover_idx:
				_hover_idx = idx
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _hit_quadrant(event.position)
			if idx >= 0 and idx < QUADRANTS.size():
				color_chosen.emit(String(QUADRANTS[idx]["id"]))
		elif event is InputEventScreenTouch and event.pressed:
			var idx: int = _hit_quadrant(event.position)
			if idx >= 0 and idx < QUADRANTS.size():
				color_chosen.emit(String(QUADRANTS[idx]["id"]))

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r_outer: float = minf(size.x, size.y) * 0.46
		var r_inner: float = r_outer * 0.28
		if r_outer <= 6.0:
			return
		draw_circle(c, r_outer + 7.0, Color(0.96, 0.84, 0.42, 0.90))
		draw_circle(c, r_outer + 3.0, Color(0.07, 0.09, 0.12, 0.98))
		for q: int in range(4):
			var meta: Dictionary = QUADRANTS[q]
			var is_hov: bool = (q == _hover_idx)
			var col: Color = (meta["col"] as Color).lightened(0.14) if is_hov else (meta["col"] as Color)
			var r_q: float = r_outer + (4.0 if is_hov else 0.0)
			var a0: float = float(q) * PI * 0.5 + 0.045
			var a1: float = (float(q) + 1.0) * PI * 0.5 - 0.045
			var pts: PackedVector2Array = PackedVector2Array([c])
			for s: int in range(15):
				var a: float = lerpf(a0, a1, float(s) / 14.0)
				pts.append(c + Vector2(cos(a), sin(a)) * r_q)
			draw_colored_polygon(pts, col)
			var mid_a: float = (a0 + a1) * 0.5
			var lbl_r: float = lerpf(r_inner, r_outer, 0.56)
			var lbl_pos: Vector2 = c + Vector2(cos(mid_a), sin(mid_a)) * lbl_r
			var txt: String = String(meta["label"])
			var f_sz: int = 23 if is_hov else 21
			var str_sz: Vector2 = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, f_sz)
			var draw_pt: Vector2 = Vector2(lbl_pos.x - str_sz.x * 0.5, lbl_pos.y + str_sz.y * 0.28)
			if meta["id"] != "yellow":
				draw_string(_font, draw_pt + Vector2(0, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, Color(0, 0, 0, 0.65))
			draw_string(_font, draw_pt, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, f_sz, meta["txt"] as Color)
		draw_circle(c, r_inner + 3.0, Color(0.98, 0.98, 0.98, 0.96))
		draw_circle(c, r_inner, Color(0.09, 0.11, 0.15, 0.98))
		var center_txt: String = "UNO"
		var c_sz: Vector2 = _font.get_string_size(center_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(_font, Vector2(c.x - c_sz.x * 0.5, c.y + c_sz.y * 0.30), center_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.88, 0.38))

# --- Authoritative UNO Match State ---
var my_hand: Array = []
var hands_count: Dictionary = {}
var total_players: int = 2
var top_card: Dictionary = {"color": "red", "value": "7", "uid": 0}
var current_color: String = "red"
var direction: int = 1
var deck_remaining: int = 80
var has_drawn_this_turn: bool = false
var uno_called: Dictionary = {}
var rank1_player: int = 0
var rank2_player: int = 0

var selected_card_uid: int = -1
var _last_drawn_uid: int = -1
var _draw_request_pending: bool = false
var pending_wild_card: Dictionary = {}
var _match_started: bool = false

# --- 3D Table Component ---
var table_3d: Node3D

# --- Minimal Gamer-Friendly 2D HUD References ---
var hud_layer: CanvasLayer
var hud_root: Control
var vfx_layer: Control

# Slim Floating Table Compass Pill (Color + Direction + Deck Count ONLY)
var turn_status_pill: PanelContainer
var active_color_chip: PanelContainer
var active_color_chip_style: StyleBoxFlat
var active_color_chip_label: Label
var direction_chip_label: Label
var deck_count_chip_label: Label

# Open Floating Bottom Hand & Contextual Action Controls
var bottom_dock: Control
var sort_hand_btn: Button
var contextual_action_bar: HBoxContainer
var draw_action_btn: Button
var pass_turn_btn: Button
var call_uno_btn: Button
var hand_scroll: ScrollContainer
var hand_cards_box: HBoxContainer
var hand_empty_label: Label
var hand_count_badge_lbl: Label

# Wild Color Picker Modal
var wild_modal_backdrop: ColorRect
var wild_modal_panel: PanelContainer
var wild_preview_holder: CenterContainer

var _pid_to_seat_slot: Dictionary = {} # gamer_id -> 1 (Top), 2 (Left), 3 (Right)
var _card_widgets_by_uid: Dictionary = {}
var _sort_by_value_first: bool = false
var _uno_pulse_tween: Tween
var _draw_pulse_tween: Tween
var _last_top_pill_y: float = -1.0
var _is_mobile_gpu: bool = false
var _hud_vis_accum: float = 0.0
var _cached_hud: Node = null
var _cached_start_ov: Control = null
var _cached_result_dlg: Control = null

var camera_distance: float = 2.42
var camera_pitch: float = -1.08

# ==============================================================================
# 1. INITIALIZATION & LIFECYCLE
# ==============================================================================

func _init() -> void:
	# Immersive 3D Cafe Fekr Lounge perspective showing the room, opponent chairs, and 3D tabletop
	camera_distance = 2.42
	camera_pitch = -1.08

func _ready() -> void:
	game_type = GameTypes.UNO
	_is_mobile_gpu = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	_setup_table_3d()
	_build_hud()
	super._ready()
	_connect_uno_signals()
	var vp: Viewport = get_viewport()
	if vp and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	_refresh_all_visuals()
	_update_hud_visibility()
	call_deferred("_enforce_camera_framing")
	call_deferred("_enforce_hud_geometry")

func _on_viewport_resized() -> void:
	_last_top_pill_y = -1.0
	_enforce_hud_geometry()
	_rebuild_hand_cards(_get_playable_count())

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

func _process(delta: float) -> void:
	_hud_vis_accum += delta
	if _hud_vis_accum >= 0.15:
		_hud_vis_accum = 0.0
		_update_hud_visibility()

func _setup_table_3d() -> void:
	table_3d = UnoTable3DScript.new()
	table_3d.name = "UnoTable3D"
	add_child(table_3d)
	table_3d.draw_pile_clicked.connect(_on_draw_action_pressed)
	table_3d.uno_bell_clicked.connect(_on_uno_button_pressed)

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

func _exit_tree() -> void:
	_disconnect_uno_signals()
	super._exit_tree()

# ==============================================================================
# 2. MINIMAL, GAMER-FRIENDLY FLOATING HUD ARCHITECTURE
# ==============================================================================

func _make_glass_style(bg: Color, border: Color, radius: int = 18, border_w: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if not _is_mobile_gpu:
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 2)
	return s

func _style_action_button(btn: Button, bg: Color, border: Color, text_col: Color = Color.WHITE, f_size: int = 20, radius: int = 16) -> void:
	btn.add_theme_font_override("font", FontHekayat)
	btn.add_theme_font_size_override("font_size", f_size)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.12))
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.78))
	btn.add_theme_constant_override("outline_size", 2)

	var st_norm: StyleBoxFlat = _make_glass_style(bg, border, radius, 2)
	var st_hov: StyleBoxFlat = _make_glass_style(bg.lightened(0.08), border.lightened(0.18), radius, 2)
	var st_press: StyleBoxFlat = _make_glass_style(bg.darkened(0.10), border, radius, 2)

	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_press)
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _enforce_hud_geometry() -> void:
	var vp_sz: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(720, 1280)
	var vp_w: float = maxf(320.0, vp_sz.x)
	if is_instance_valid(hud_root):
		hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(turn_status_pill):
		var half_pill: float = minf(168.0, (vp_w - 24.0) * 0.5)
		turn_status_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
		turn_status_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		turn_status_pill.offset_left = -half_pill
		turn_status_pill.offset_right = half_pill
		_sync_top_pill_position()
	var bottom_pad: float = float(HudTheme.get_safe_insets(get_viewport()).get("bottom", 14))
	if is_instance_valid(bottom_dock):
		bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bottom_dock.offset_left = 8.0
		bottom_dock.offset_right = -8.0
		bottom_dock.offset_top = -bottom_pad - 244.0
		bottom_dock.offset_bottom = -bottom_pad
		bottom_dock.clip_contents = true
	if is_instance_valid(call_uno_btn):
		call_uno_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		call_uno_btn.offset_left = 14.0
		call_uno_btn.offset_right = 88.0
		call_uno_btn.offset_top = -bottom_pad - 326.0
		call_uno_btn.offset_bottom = -bottom_pad - 252.0
	if is_instance_valid(wild_modal_panel):
		var mw: float = minf(390.0, vp_w - 36.0)
		wild_modal_panel.custom_minimum_size = Vector2(mw, 410.0)

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	hud_layer.name = "UnoHUDLayer"
	add_child(hud_layer)

	hud_root = Control.new()
	hud_root.name = "UnoHUDRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# --- 1. Slim Floating Table Compass Pill (Centered symmetrically with GROW_DIRECTION_BOTH) ---
	turn_status_pill = PanelContainer.new()
	turn_status_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_status_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	turn_status_pill.offset_left = -168
	turn_status_pill.offset_right = 168
	turn_status_pill.offset_top = 264
	turn_status_pill.offset_bottom = 304
	turn_status_pill.mouse_filter = Control.MOUSE_FILTER_PASS
	turn_status_pill.visible = false
	turn_status_pill.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.05, 0.09, 0.08, 0.86), Color(0.86, 0.68, 0.30, 0.72), 20, 1)
	)
	hud_root.add_child(turn_status_pill)

	var pill_margin: MarginContainer = MarginContainer.new()
	pill_margin.add_theme_constant_override("margin_left", 10)
	pill_margin.add_theme_constant_override("margin_right", 10)
	pill_margin.add_theme_constant_override("margin_top", 4)
	pill_margin.add_theme_constant_override("margin_bottom", 4)
	turn_status_pill.add_child(pill_margin)

	var pill_hbox: HBoxContainer = HBoxContainer.new()
	pill_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pill_hbox.add_theme_constant_override("separation", 10)
	pill_margin.add_child(pill_hbox)

	# Active Color Swatch Pill
	active_color_chip = PanelContainer.new()
	active_color_chip.custom_minimum_size = Vector2(92, 30)
	active_color_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_color_chip_style = StyleBoxFlat.new()
	active_color_chip_style.bg_color = UNO_COLORS["red"]
	active_color_chip_style.border_color = Color.WHITE
	active_color_chip_style.set_border_width_all(2)
	active_color_chip_style.set_corner_radius_all(14)
	active_color_chip.add_theme_stylebox_override("panel", active_color_chip_style)
	pill_hbox.add_child(active_color_chip)

	active_color_chip_label = Label.new()
	active_color_chip_label.text = "رنگ: قرمز"
	active_color_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_color_chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_color_chip_label.add_theme_font_override("font", FontHekayat)
	active_color_chip_label.add_theme_font_size_override("font_size", 17)
	active_color_chip_label.add_theme_color_override("font_color", Color.WHITE)
	active_color_chip.add_child(active_color_chip_label)

	direction_chip_label = Label.new()
	direction_chip_label.text = "↻ ساعتگرد"
	direction_chip_label.add_theme_font_override("font", FontHekayat)
	direction_chip_label.add_theme_font_size_override("font_size", 17)
	direction_chip_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.64))
	pill_hbox.add_child(direction_chip_label)

	deck_count_chip_label = Label.new()
	deck_count_chip_label.text = "🃏 ۸۰"
	deck_count_chip_label.add_theme_font_override("font", FontHekayat)
	deck_count_chip_label.add_theme_font_size_override("font_size", 16)
	deck_count_chip_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.96))
	pill_hbox.add_child(deck_count_chip_label)

	# --- 2. Open Floating Handheld Card Fan in Cleared Bottom HUD Space (Clipped strictly inside viewport!) ---
	var init_bottom_pad: float = float(HudTheme.get_safe_insets(get_viewport()).get("bottom", 14))
	bottom_dock = Control.new()
	bottom_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_dock.offset_left = 8
	bottom_dock.offset_right = -8
	bottom_dock.offset_top = -init_bottom_pad - 244.0
	bottom_dock.offset_bottom = -init_bottom_pad
	bottom_dock.clip_contents = true
	bottom_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_dock)

	# Compact Top Bar of Hand Dock: Left = Sort + Count, Right = Thumb-Zone Draw / Pass CTA
	contextual_action_bar = HBoxContainer.new()
	contextual_action_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	contextual_action_bar.offset_left = 8
	contextual_action_bar.offset_right = -8
	contextual_action_bar.offset_top = 4
	contextual_action_bar.offset_bottom = 50
	contextual_action_bar.add_theme_constant_override("separation", 8)
	contextual_action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(contextual_action_bar)

	# Left Utility Group: Sort & Hand Count
	sort_hand_btn = Button.new()
	sort_hand_btn.text = "⇅ رنگ"
	sort_hand_btn.custom_minimum_size = Vector2(84, 38)
	sort_hand_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_action_button(sort_hand_btn, Color(0.10, 0.18, 0.14, 0.88), Color(0.45, 0.78, 0.58, 0.68), Color(0.92, 0.98, 0.94), 19, 14)
	sort_hand_btn.pressed.connect(_on_sort_hand_pressed)
	contextual_action_bar.add_child(sort_hand_btn)

	var count_pill: PanelContainer = PanelContainer.new()
	count_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cp_st: StyleBoxFlat = _make_glass_style(Color(0.08, 0.06, 0.04, 0.76), Color(0.84, 0.68, 0.32, 0.48), 14, 1)
	cp_st.content_margin_left = 10
	cp_st.content_margin_right = 10
	cp_st.content_margin_top = 4
	cp_st.content_margin_bottom = 4
	count_pill.add_theme_stylebox_override("panel", cp_st)
	contextual_action_bar.add_child(count_pill)

	hand_count_badge_lbl = Label.new()
	hand_count_badge_lbl.text = "۷ کارت"
	hand_count_badge_lbl.add_theme_font_override("font", FontHekayat)
	hand_count_badge_lbl.add_theme_font_size_override("font_size", 19)
	hand_count_badge_lbl.add_theme_color_override("font_color", Color(0.98, 0.90, 0.66))
	hand_count_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_pill.add_child(hand_count_badge_lbl)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contextual_action_bar.add_child(spacer)

	# Right Thumb-Zone Primary Action Pills (Draw / Pass)
	draw_action_btn = Button.new()
	draw_action_btn.text = "🃏 کشیدن کارت"
	draw_action_btn.custom_minimum_size = Vector2(150, 44)
	draw_action_btn.pivot_offset = Vector2(75, 22)
	_style_action_button(draw_action_btn, Color(0.11, 0.42, 0.78, 0.96), Color(0.50, 0.82, 1.0), Color.WHITE, 21, 18)
	draw_action_btn.visible = false
	draw_action_btn.pressed.connect(_on_draw_action_pressed)
	contextual_action_bar.add_child(draw_action_btn)

	pass_turn_btn = Button.new()
	pass_turn_btn.text = "⏭️ رد نوبت"
	pass_turn_btn.custom_minimum_size = Vector2(142, 44)
	_style_action_button(pass_turn_btn, Color(0.76, 0.46, 0.08, 0.98), Color(1.0, 0.86, 0.36), Color.WHITE, 21, 18)
	pass_turn_btn.visible = false
	pass_turn_btn.pressed.connect(_on_pass_turn_pressed)
	contextual_action_bar.add_child(pass_turn_btn)

	# Signature Floating Circular UNO! FAB (Sibling on hud_root so bottom_dock clip_contents never clips it!)
	call_uno_btn = Button.new()
	call_uno_btn.text = "🔥\nUNO!"
	call_uno_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	call_uno_btn.offset_left = 14
	call_uno_btn.offset_right = 88
	call_uno_btn.offset_top = -init_bottom_pad - 326.0
	call_uno_btn.offset_bottom = -init_bottom_pad - 252.0
	call_uno_btn.pivot_offset = Vector2(37, 37)
	_style_action_button(call_uno_btn, Color(0.86, 0.14, 0.18, 0.98), Color(1.0, 0.88, 0.32), Color(1.0, 0.98, 0.86), 18, 37)
	call_uno_btn.visible = false
	call_uno_btn.pressed.connect(_on_uno_button_pressed)
	hud_root.add_child(call_uno_btn)

	# Floating Card Fan Scroll Area (Centered MarginContainer wrapper so edge cards never clip)
	hand_scroll = ScrollContainer.new()
	hand_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_scroll.offset_left = 4
	hand_scroll.offset_right = -4
	hand_scroll.offset_top = 50
	hand_scroll.offset_bottom = -4
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_dock.add_child(hand_scroll)

	var scroll_pad: MarginContainer = MarginContainer.new()
	scroll_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_pad.add_theme_constant_override("margin_left", 10)
	scroll_pad.add_theme_constant_override("margin_right", 10)
	scroll_pad.mouse_filter = Control.MOUSE_FILTER_PASS
	hand_scroll.add_child(scroll_pad)

	hand_cards_box = HBoxContainer.new()
	hand_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_cards_box.add_theme_constant_override("separation", -10)
	hand_cards_box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_pad.add_child(hand_cards_box)

	hand_empty_label = Label.new()
	hand_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_empty_label.offset_top = 68
	hand_empty_label.text = "در انتظار پخش کارت‌ها روی میز..."
	hand_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_empty_label.add_theme_font_override("font", FontHekayat)
	hand_empty_label.add_theme_font_size_override("font_size", 20)
	hand_empty_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.86, 0.78))
	hand_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_dock.add_child(hand_empty_label)

	# --- 3. Interactive Radial Wild Color Wheel Modal & VFX Layer ---
	_build_wild_color_modal()

	vfx_layer = UnoVFXOverlayScript.new()
	vfx_layer.name = "UnoVFXOverlay"
	hud_root.add_child(vfx_layer)

func _build_wild_color_modal() -> void:
	wild_modal_backdrop = ColorRect.new()
	wild_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	wild_modal_backdrop.color = Color(0.02, 0.04, 0.04, 0.78)
	wild_modal_backdrop.visible = false
	wild_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	wild_modal_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pending_wild_card.clear()
			wild_modal_backdrop.visible = false
	)
	hud_root.add_child(wild_modal_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wild_modal_backdrop.add_child(center)

	wild_modal_panel = PanelContainer.new()
	wild_modal_panel.custom_minimum_size = Vector2(390, 410)
	wild_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	wild_modal_panel.add_theme_stylebox_override(
		"panel",
		_make_glass_style(Color(0.07, 0.12, 0.10, 0.97), Color(0.95, 0.80, 0.35, 0.92), 26, 3)
	)
	center.add_child(wild_modal_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	wild_modal_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = "🎨 رنگ جدید را لمس کنید"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontHekayat)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	vbox.add_child(title_lbl)

	wild_preview_holder = CenterContainer.new()
	wild_preview_holder.visible = false
	vbox.add_child(wild_preview_holder)

	var wheel_holder: CenterContainer = CenterContainer.new()
	vbox.add_child(wheel_holder)

	var wheel_picker: WildColorWheelPicker = WildColorWheelPicker.new()
	wheel_picker.custom_minimum_size = Vector2(276, 276)
	wheel_picker.color_chosen.connect(_on_wild_color_selected)
	wheel_holder.add_child(wheel_picker)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "انصراف"
	cancel_btn.custom_minimum_size = Vector2(150, 42)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_action_button(cancel_btn, Color(0.18, 0.22, 0.28), Color(0.55, 0.62, 0.72), Color(0.90, 0.92, 0.96), 18, 16)
	cancel_btn.pressed.connect(func() -> void:
		pending_wild_card.clear()
		wild_modal_backdrop.visible = false
	)
	vbox.add_child(cancel_btn)

# ==============================================================================
# 3. GAME RULES & PLAYABLE CARD DETECTION
# ==============================================================================

func _is_card_playable(card: Dictionary) -> bool:
	if card.is_empty():
		return false
	var c_col: String = String(card.get("color", ""))
	var c_val: String = String(card.get("value", ""))
	if c_col == "wild" or c_val in ["wild", "wild_draw4"]:
		return true
	var active_c: String = current_color if not current_color.is_empty() else String(top_card.get("color", "red"))
	var top_val: String = String(top_card.get("value", ""))
	return (c_col == active_c) or (c_val == top_val and not top_val.is_empty())

func _get_playable_count() -> int:
	var count: int = 0
	for c: Variant in my_hand:
		if typeof(c) == TYPE_DICTIONARY and _is_card_playable(c as Dictionary):
			count += 1
	return count

func _get_total_players() -> int:
	if GameManager.match_players.size() >= 2:
		total_players = clampi(GameManager.match_players.size(), 2, 4)
		return total_players
	var inferred: int = 2
	for k: Variant in hands_count.keys():
		var ki: int = int(str(k))
		if ki >= 2 and ki <= 4 and int(hands_count[k]) > 0 and ki > inferred:
			inferred = ki
	total_players = clampi(inferred, 2, 4)
	return total_players

func _get_card_count_for_player(pid: int) -> int:
	var s_key: String = str(pid)
	if hands_count.has(s_key):
		return int(hands_count[s_key])
	if hands_count.has(pid):
		return int(hands_count[pid])
	if pid == my_player_index and (_match_started or not my_hand.is_empty()):
		return my_hand.size()
	return 7

func _has_player_called_uno(pid: int) -> bool:
	var s_key: String = str(pid)
	if uno_called.has(s_key):
		return bool(uno_called[s_key])
	if uno_called.has(pid):
		return bool(uno_called[pid])
	return false

func _get_player_short_name(pid: int) -> String:
	if pid <= 0:
		return "بازیکن"
	var p_data: Dictionary = GameManager.get_player_data_by_gamer_id(pid)
	var p_name: String = String(p_data.get("name", p_data.get("username", "")))
	if p_name.is_empty():
		p_name = "بازیکن " + UnoCardWidgetScript.to_fa_digits(str(pid))
	return p_name

func _update_hands_count_from_variant(raw_counts: Variant) -> void:
	if typeof(raw_counts) == TYPE_DICTIONARY:
		var d: Dictionary = raw_counts as Dictionary
		if not d.is_empty():
			hands_count.clear()
			for k: Variant in d.keys():
				hands_count[str(k)] = int(d[k])
	elif typeof(raw_counts) == TYPE_ARRAY:
		var arr: Array = raw_counts as Array
		if not arr.is_empty():
			hands_count.clear()
			for i: int in range(arr.size()):
				hands_count[str(i + 1)] = int(arr[i])

func _get_hands_count_array() -> Array:
	var arr: Array = []
	var total_p: int = _get_total_players()
	for i: int in range(1, total_p + 1):
		arr.append(_get_card_count_for_player(i))
	return arr

func _refresh_top_header_badges() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var hud: Node = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(hud):
		hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(hud):
		var header: Node = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
		if is_instance_valid(header) and header.has_method("update_uno_hands"):
			header.update_uno_hands(_get_hands_count_array(), rank1_player, rank2_player)

# ==============================================================================
# 4. VISUAL REFRESH (3D TABLETOP, 3D OPPONENTS & FLOATING CURVED CARD HAND)
# ==============================================================================

func _resolve_cached_hud() -> Node:
	if is_instance_valid(_cached_hud):
		return _cached_hud
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	_cached_hud = tree.get_first_node_in_group("base_game_hud")
	if not is_instance_valid(_cached_hud):
		_cached_hud = tree.root.find_child("BaseGameHUD", true, false)
	if is_instance_valid(_cached_hud):
		_cached_start_ov = _cached_hud.get_node_or_null("StartGameOverlay") as Control
		_cached_result_dlg = _cached_hud.get_node_or_null("GameResultDialog") as Control
	return _cached_hud

func _is_hud_overlay_blocking() -> bool:
	if not _match_started and not GameManager.is_game_active:
		return true
	var hud: Node = _resolve_cached_hud()
	if is_instance_valid(hud):
		if is_instance_valid(_cached_start_ov) and _cached_start_ov.visible:
			return true
		if is_instance_valid(_cached_result_dlg) and _cached_result_dlg.visible:
			return true
	return false

func _update_hud_visibility() -> void:
	if not is_instance_valid(hud_root):
		return
	var hud: Node = _resolve_cached_hud()
	if is_instance_valid(hud) and hud_root.get_parent() != hud:
		if hud_root.get_parent():
			hud_root.get_parent().remove_child(hud_root)
		hud.add_child(hud_root)
		if is_instance_valid(_cached_start_ov):
			hud.move_child(hud_root, _cached_start_ov.get_index())
		if is_instance_valid(hud_layer):
			hud_layer.queue_free()
			hud_layer = null
		_enforce_hud_geometry()
	var should_show: bool = not _is_hud_overlay_blocking()
	if hud_root.visible != should_show:
		hud_root.visible = should_show
		if should_show:
			_enforce_hud_geometry()
			_refresh_top_header_badges()

func _refresh_all_visuals() -> void:
	my_player_index = max(1, GameManager.my_player_index)
	is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active

	var playable_cnt: int = _get_playable_count()
	var should_highlight_draw: bool = is_my_turn and (not has_drawn_this_turn) and (playable_cnt == 0)

	# 1. Refresh 3D Tabletop State
	if is_instance_valid(table_3d):
		table_3d.update_table_state(top_card, current_color, direction, deck_remaining, should_highlight_draw)

	# 2. Refresh Compact Top Status Pill
	_refresh_top_status_pill(playable_cnt)

	# 3. Refresh 3D Opponent Card Fans & 3D Floating Badges on the Table
	_refresh_3d_opponents()

	# 4. Refresh Floating Handheld Card Fan
	_rebuild_hand_cards(playable_cnt)

	# 5. Refresh Contextual Action Pills
	_refresh_action_buttons(playable_cnt)

	# 6. Refresh Player Card Count Badges in Top Header
	_refresh_top_header_badges()

func _sync_top_pill_position() -> void:
	if not is_instance_valid(turn_status_pill):
		return
	turn_status_pill.visible = false
	var target_y: float = 166.0 if _get_total_players() <= 2 else 224.0
	var tree: SceneTree = get_tree()
	if tree:
		var hud: Node = tree.get_first_node_in_group("base_game_hud")
		if not is_instance_valid(hud):
			hud = tree.root.find_child("BaseGameHUD", true, false)
		if is_instance_valid(hud):
			var rail: Control = hud.get_node_or_null("SubHeaderRail") as Control
			if is_instance_valid(rail) and rail.size.y > 10.0:
				target_y = clampf(rail.global_position.y + rail.size.y + 8.0, 152.0, 310.0)
			else:
				var header: Node = hud.current_top_header if ("current_top_header" in hud and is_instance_valid(hud.current_top_header)) else hud.get_node_or_null("TopHeader")
				if is_instance_valid(header):
					var vbox_main: Control = header.get_node_or_null("Margin/VBoxMain") as Control
					if is_instance_valid(vbox_main) and vbox_main.size.y > 40.0:
						target_y = clampf(vbox_main.global_position.y + vbox_main.size.y + 50.0, 152.0, 310.0)
	if absf(target_y - _last_top_pill_y) > 1.0:
		_last_top_pill_y = target_y
		turn_status_pill.offset_top = target_y
		turn_status_pill.offset_bottom = target_y + 40.0

func _refresh_top_status_pill(_playable_cnt: int) -> void:
	_sync_top_pill_position()
	var act_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])
	if active_color_chip_style:
		active_color_chip_style.bg_color = act_col
	if active_color_chip_label:
		active_color_chip_label.text = "رنگ: " + String(UNO_COLOR_NAMES_FA.get(current_color, "قرمز"))
		active_color_chip_label.add_theme_color_override("font_color", Color.WHITE if current_color != "yellow" else Color(0.14, 0.12, 0.04))

	if direction_chip_label:
		direction_chip_label.text = "↻ ساعتگرد" if direction >= 0 else "↺ پادساعتگرد"
	if deck_count_chip_label:
		deck_count_chip_label.text = "🃏 %s" % UnoCardWidgetScript.to_fa_digits(str(max(0, deck_remaining)))

func _refresh_3d_opponents() -> void:
	_pid_to_seat_slot.clear()
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

	# Seat slots on 3D table: 1 = Top (across), 2 = Left, 3 = Right
	var slot_map: Array[int] = [1]
	if opp_pids.size() == 2:
		slot_map = [2, 3]
	elif opp_pids.size() >= 3:
		slot_map = [2, 1, 3]

	var seat_counts_3d: Dictionary = {}
	var seat_names_3d: Dictionary = {}
	var seat_uno_3d: Dictionary = {}
	var active_3d_seat: int = -1

	for i: int in range(min(opp_pids.size(), slot_map.size())):
		var pid: int = opp_pids[i]
		var s_slot: int = slot_map[i]
		_pid_to_seat_slot[pid] = s_slot

		var c_count: int = _get_card_count_for_player(pid)
		var is_t: bool = (current_turn == pid) and GameManager.is_game_active
		var is_u: bool = _has_player_called_uno(pid) or (c_count == 1)

		seat_counts_3d[s_slot] = c_count
		seat_names_3d[s_slot] = _get_player_short_name(pid)
		seat_uno_3d[s_slot] = is_u
		if is_t:
			active_3d_seat = s_slot

	if is_instance_valid(table_3d):
		table_3d.update_3d_opponent_fans(seat_counts_3d, active_3d_seat, seat_names_3d, seat_uno_3d)

func _rebuild_hand_cards(_playable_cnt: int) -> void:
	if not is_instance_valid(hand_cards_box):
		return
	for ch: Node in hand_cards_box.get_children():
		hand_cards_box.remove_child(ch)
		ch.queue_free()
	_card_widgets_by_uid.clear()

	var total_cards: int = my_hand.size()
	if is_instance_valid(hand_count_badge_lbl):
		hand_count_badge_lbl.text = "%s کارت" % UnoCardWidgetScript.to_fa_digits(str(total_cards))
	if is_instance_valid(hand_empty_label):
		hand_empty_label.visible = (total_cards == 0)

	if total_cards == 0:
		selected_card_uid = -1
		return

	# Dynamic viewport-aware card sizing & adaptive overlap so even 15+ cards fit and select effortlessly
	var vp_w: float = get_viewport().get_visible_rect().size.x if get_viewport() else 720.0
	var avail_w: float = maxf(280.0, (hand_scroll.size.x if (is_instance_valid(hand_scroll) and hand_scroll.size.x > 100.0) else (vp_w - 24.0)) - 24.0)
	var card_w: float = clampf(avail_w / maxf(6.0, float(total_cards) * 0.62), 68.0, 104.0)
	var slot_w: float = card_w + 6.0
	var sep: int = 4
	if total_cards > 1:
		var fit_sep: float = (avail_w - float(total_cards) * slot_w) / float(total_cards - 1)
		sep = clampi(int(floor(fit_sep)), -int(roundf(card_w * 0.56)), 6)
	hand_cards_box.add_theme_constant_override("separation", sep)

	var still_exists: bool = false
	for c: Variant in my_hand:
		if typeof(c) == TYPE_DICTIONARY and int((c as Dictionary).get("uid", -1)) == selected_card_uid:
			still_exists = true
			break
	if not still_exists:
		selected_card_uid = -1

	var is_crowded_fan: bool = (total_cards >= 10) or (sep < -28)
	var mid_idx: float = float(total_cards - 1) * 0.5
	for idx: int in range(total_cards):
		var c_var: Variant = my_hand[idx]
		if typeof(c_var) != TYPE_DICTIONARY:
			continue
		var c_dict: Dictionary = c_var as Dictionary
		var uid: int = int(c_dict.get("uid", -1))
		var playable: bool = _is_card_playable(c_dict)
		var selected: bool = (uid == selected_card_uid)
		var is_new_card: bool = (_last_drawn_uid >= 0 and uid == _last_drawn_uid)
		var c_val: String = String(c_dict.get("value", ""))
		var is_wild_card: bool = (String(c_dict.get("color", "")) == "wild") or (c_val in ["wild", "wild_draw4"])
		var confirm_tap: bool = is_crowded_fan or is_wild_card

		# Subtle handheld fan curve (angle & vertical arc)
		var norm_offset: float = (float(idx) - mid_idx) / maxf(1.0, mid_idx) if total_cards > 1 else 0.0
		var angle_deg: float = clampf(norm_offset * 5.5, -7.0, 7.0)
		var arc_y: float = absf(norm_offset) * absf(norm_offset) * 9.0

		var card_widget: UnoCardWidget = UnoCardWidgetScript.new()
		card_widget.setup_card(c_dict, playable, selected, is_my_turn, angle_deg, arc_y, confirm_tap, card_w, is_new_card)
		card_widget.card_tapped.connect(_on_hand_card_tapped)
		card_widget.card_play_confirmed.connect(_on_hand_card_play_confirmed)
		hand_cards_box.add_child(card_widget)
		_card_widgets_by_uid[uid] = card_widget

	if _last_drawn_uid >= 0 and _card_widgets_by_uid.has(_last_drawn_uid):
		call_deferred("_scroll_to_card_uid", _last_drawn_uid)

func _scroll_to_card_uid(uid: int) -> void:
	if not is_instance_valid(hand_scroll) or not _card_widgets_by_uid.has(uid):
		return
	var cw: Control = _card_widgets_by_uid[uid] as Control
	if not is_instance_valid(cw):
		return
	var content_w: float = hand_cards_box.get_combined_minimum_size().x + 20.0
	var max_scroll: int = maxi(0, int(ceilf(content_w - hand_scroll.size.x)))
	if max_scroll <= 0:
		hand_scroll.scroll_horizontal = 0
		return
	var target_x: int = clampi(int(cw.position.x + cw.size.x * 0.5 - hand_scroll.size.x * 0.5), 0, max_scroll)
	if is_inside_tree():
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(hand_scroll, "scroll_horizontal", target_x, 0.20)
	else:
		hand_scroll.scroll_horizontal = target_x

func _refresh_action_buttons(playable_cnt: int) -> void:
	if not is_instance_valid(draw_action_btn):
		return

	# Persistent Draw CTA on your turn before drawing:
	# - Highlighted & pulsing when 0 playable cards (urgent)
	# - Subtle calm dark-glass pill when playable cards exist (strategic draw option)
	var can_draw: bool = is_my_turn and (not has_drawn_this_turn)
	draw_action_btn.visible = can_draw
	if _draw_pulse_tween and _draw_pulse_tween.is_valid():
		_draw_pulse_tween.kill()
		draw_action_btn.scale = Vector2.ONE
	if can_draw:
		draw_action_btn.text = "🃏 کشیدن کارت"
		if playable_cnt == 0:
			draw_action_btn.custom_minimum_size = Vector2(166, 46)
			_style_action_button(draw_action_btn, Color(0.12, 0.46, 0.86, 0.98), Color(1.0, 0.88, 0.36), Color.WHITE, 21, 18)
			if is_inside_tree() and not _is_mobile_gpu:
				draw_action_btn.pivot_offset = Vector2(83, 23)
				_draw_pulse_tween = create_tween().set_loops()
				_draw_pulse_tween.tween_property(draw_action_btn, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE)
				_draw_pulse_tween.tween_property(draw_action_btn, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
		else:
			draw_action_btn.custom_minimum_size = Vector2(150, 44)
			_style_action_button(draw_action_btn, Color(0.10, 0.18, 0.28, 0.86), Color(0.45, 0.72, 0.96, 0.70), Color(0.90, 0.96, 1.0), 19, 16)

	# Show "Pass Turn" pill immediately after drawing a playable card
	var can_pass: bool = is_my_turn and has_drawn_this_turn
	pass_turn_btn.visible = can_pass

	# Signature pulsing Circular UNO! FAB when holding 1 or 2 cards
	var can_uno: bool = GameManager.is_game_active and (my_hand.size() <= 2 and my_hand.size() >= 1) and not _has_player_called_uno(my_player_index)
	call_uno_btn.visible = can_uno
	if _uno_pulse_tween and _uno_pulse_tween.is_valid():
		_uno_pulse_tween.kill()
		call_uno_btn.scale = Vector2.ONE
	if can_uno and is_inside_tree():
		_uno_pulse_tween = create_tween().set_loops()
		_uno_pulse_tween.tween_property(call_uno_btn, "scale", Vector2(1.10, 1.10), 0.45).set_trans(Tween.TRANS_SINE)
		_uno_pulse_tween.tween_property(call_uno_btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)

	if is_instance_valid(table_3d):
		table_3d.set_uno_bell_alert(can_uno)

func _get_my_hand_center_screen_pos() -> Vector2:
	if is_instance_valid(hand_scroll):
		var r: Rect2 = hand_scroll.get_global_rect()
		if r.size.x > 10.0 and r.size.y > 10.0:
			return r.get_center()
	var vp: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(720, 1280)
	return Vector2(vp.x * 0.5, vp.y * 0.84)

# ==============================================================================
# 5. USER INTERACTION HANDLERS (SMART TAP / SWIPE-UP PLAY, DRAW, PASS, UNO, WILD)
# ==============================================================================

func _on_hand_card_tapped(uid: int, card_data: Dictionary, _widget: Control) -> void:
	AudioManager.sfx_tap()
	if not is_my_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("⏳ هنوز نوبت شما نرسیده است", Color(0.95, 0.78, 0.30), 1.5)
		return

	if not _is_card_playable(card_data):
		var cname: String = String(UNO_COLOR_NAMES_FA.get(current_color, "قرمز"))
		var t_val: String = UnoCardWidgetScript.format_center_symbol(String(top_card.get("value", "")))
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("⚠️ این کارت با رنگ «%s» یا نماد «%s» همخوانی ندارد" % [cname, t_val], Color(1.0, 0.52, 0.52), 1.8)
		return

	# Crowded fan or Wild card: First tap lifts & previews; second tap (or ▲ بازی / swipe-up) plays!
	if selected_card_uid == uid:
		_on_hand_card_play_confirmed(uid, card_data, _widget)
		return
	var prev_uid: int = selected_card_uid
	selected_card_uid = uid
	if _card_widgets_by_uid.has(prev_uid) and is_instance_valid(_card_widgets_by_uid[prev_uid]):
		(_card_widgets_by_uid[prev_uid] as UnoCardWidget).set_selected_state(false, true)
	if _card_widgets_by_uid.has(uid) and is_instance_valid(_card_widgets_by_uid[uid]):
		(_card_widgets_by_uid[uid] as UnoCardWidget).set_selected_state(true, true)
		call_deferred("_scroll_to_card_uid", uid)

func _on_hand_card_play_confirmed(uid: int, card_data: Dictionary, widget: Control) -> void:
	if not is_my_turn:
		return
	if not _is_card_playable(card_data):
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("⚠️ این کارت قابل بازی نیست!", Color(1.0, 0.45, 0.45), 1.6)
		return

	var c_col: String = String(card_data.get("color", ""))
	var c_val: String = String(card_data.get("value", ""))
	if c_col == "wild" or c_val in ["wild", "wild_draw4"]:
		pending_wild_card = card_data.duplicate(true)
		_open_wild_color_modal(pending_wild_card)
		return

	_dispatch_play_card(uid, "", card_data, widget)

func _open_wild_color_modal(card_data: Dictionary) -> void:
	AudioManager.sfx_button()
	if is_instance_valid(wild_preview_holder):
		for ch: Node in wild_preview_holder.get_children():
			ch.queue_free()
		var preview_card: UnoCardWidget = UnoCardWidgetScript.new()
		preview_card.setup_card(card_data, true, false, false)
		preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wild_preview_holder.add_child(preview_card)
	wild_modal_backdrop.visible = true

func _on_wild_color_selected(chosen_color: String) -> void:
	if pending_wild_card.is_empty():
		wild_modal_backdrop.visible = false
		return
	AudioManager.sfx_button()
	var uid: int = int(pending_wild_card.get("uid", -1))
	var card_copy: Dictionary = pending_wild_card.duplicate(true)
	var widget: Control = _card_widgets_by_uid.get(uid, null) as Control
	pending_wild_card.clear()
	wild_modal_backdrop.visible = false
	_dispatch_play_card(uid, chosen_color, card_copy, widget)

func _dispatch_play_card(uid: int, chosen_color: String, card_data: Dictionary, widget: Control) -> void:
	if uid < 0:
		return
	AudioManager.sfx_move_piece()

	if is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
		var start_pos: Vector2 = _get_my_hand_center_screen_pos()
		if is_instance_valid(widget):
			start_pos = widget.global_position + widget.size * 0.5
		var end_pos: Vector2 = table_3d.get_discard_pile_screen_pos()
		vfx_layer.animate_card_flight(start_pos, end_pos, card_data, true, 0.25)

	selected_card_uid = -1
	_last_drawn_uid = -1
	_draw_request_pending = false
	var payload: Dictionary = {"card_uid": uid}
	if not chosen_color.is_empty():
		payload["chosen_color"] = chosen_color
	send_move(Commands.Play_Card, payload)

func _on_draw_action_pressed() -> void:
	if not is_my_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("⏳ فقط در نوبت خودتان می‌توانید کارت بکشید", Color(0.95, 0.78, 0.30), 1.6)
		return
	if has_drawn_this_turn:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("🃏 این نوبت کارت کشیده‌اید؛ کارت جدید را بازی کنید یا «رد نوبت» بزنید", Color(0.98, 0.82, 0.35), 2.0)
		return
	if _draw_request_pending:
		return

	_draw_request_pending = true
	if is_instance_valid(draw_action_btn):
		draw_action_btn.disabled = true
	AudioManager.sfx_add_piece()
	if is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
		var from_pos: Vector2 = table_3d.get_draw_pile_screen_pos()
		var to_pos: Vector2 = _get_my_hand_center_screen_pos()
		vfx_layer.animate_card_flight(from_pos, to_pos, {}, false, 0.28)

	send_move(Commands.Draw_Card, {})
	if is_inside_tree():
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			if _draw_request_pending:
				_draw_request_pending = false
				if is_instance_valid(draw_action_btn):
					draw_action_btn.disabled = false
		)

func _on_pass_turn_pressed() -> void:
	if not is_my_turn or not has_drawn_this_turn:
		return
	_last_drawn_uid = -1
	_draw_request_pending = false
	AudioManager.sfx_button()
	send_move(Commands.Pass_Turn, {})

func _on_uno_button_pressed() -> void:
	if not GameManager.is_game_active:
		return
	if my_hand.size() > 2:
		if is_instance_valid(vfx_layer):
			vfx_layer.show_contextual_toast("🔥 دکمه و زنگ «اونو!» زمانی فعال می‌شود که ۱ یا ۲ کارت داشته باشید", Color(0.98, 0.80, 0.32), 2.0)
		return
	AudioManager.sfx_win()
	send_move(Commands.Call_Uno, {})

func _on_sort_hand_pressed() -> void:
	if my_hand.size() <= 1:
		return
	AudioManager.sfx_tap()
	_sort_by_value_first = not _sort_by_value_first
	var color_rank: Dictionary = {"red": 0, "yellow": 1, "green": 2, "blue": 3, "wild": 4}
	my_hand.sort_custom(func(a: Variant, b: Variant) -> bool:
		if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
			return false
		var da: Dictionary = a as Dictionary
		var db: Dictionary = b as Dictionary
		var ca: int = int(color_rank.get(String(da.get("color", "wild")), 4))
		var cb: int = int(color_rank.get(String(db.get("color", "wild")), 4))
		var va: String = String(da.get("value", ""))
		var vb: String = String(db.get("value", ""))
		if _sort_by_value_first:
			if va != vb:
				return va < vb
			return ca < cb
		else:
			if ca != cb:
				return ca < cb
			return va < vb
	)
	if sort_hand_btn:
		sort_hand_btn.text = "⇅ عدد" if _sort_by_value_first else "⇅ رنگ"
	_rebuild_hand_cards(_get_playable_count())

# ==============================================================================
# 6. AUTHORITATIVE BACKEND SYNC & NETWORK EVENT HANDLERS
# ==============================================================================

func _has_card_uid_in_hand(uid: int) -> bool:
	if uid < 0:
		return false
	for c: Variant in my_hand:
		if typeof(c) == TYPE_DICTIONARY and int((c as Dictionary).get("uid", -1)) == uid:
			return true
	return false

func _apply_uno_state_dict(data: Dictionary, do_refresh: bool = true) -> void:
	if data.is_empty():
		return
	_match_started = true
	_draw_request_pending = false
	if is_instance_valid(draw_action_btn):
		draw_action_btn.disabled = false

	if data.has("my_hand") and typeof(data["my_hand"]) == TYPE_ARRAY:
		my_hand = (data["my_hand"] as Array).duplicate(true)
	elif data.has("hand") and typeof(data["hand"]) == TYPE_ARRAY:
		my_hand = (data["hand"] as Array).duplicate(true)

	if data.has("hands_count"):
		_update_hands_count_from_variant(data["hands_count"])
	elif (data.has("my_hand") or data.has("hand")) and my_player_index >= 1:
		hands_count[str(my_player_index)] = my_hand.size()

	if data.has("top_card") and typeof(data["top_card"]) == TYPE_DICTIONARY:
		top_card = (data["top_card"] as Dictionary).duplicate(true)
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
		uno_called = (data["uno_called"] as Dictionary).duplicate(true)
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
	if do_refresh:
		_refresh_all_visuals()

func setup_board(game_data: Dictionary) -> void:
	_match_started = true
	if game_data.has("gamers") and typeof(game_data["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(game_data["gamers"] as Array)
	var inner: Variant = game_data.get("game_data", game_data)
	if typeof(inner) == TYPE_DICTIONARY:
		_apply_uno_state_dict(inner as Dictionary)
	if game_data.has("user_data") and typeof(game_data["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(game_data["user_data"] as Dictionary)
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
	_draw_request_pending = false
	if is_instance_valid(draw_action_btn):
		draw_action_btn.disabled = false
	var prev_turn: int = current_turn
	current_turn = turn
	my_player_index = max(1, GameManager.my_player_index)
	is_my_turn = (turn == my_player_index) and GameManager.is_game_active
	is_board_locked = not is_my_turn
	if not is_my_turn:
		has_drawn_this_turn = false
		wild_modal_backdrop.visible = false
	elif prev_turn != turn:
		_last_drawn_uid = -1
	_refresh_all_visuals()
	_update_hud_visibility()

func on_reconnect_data(payload: Dictionary) -> void:
	_match_started = true
	if payload.has("gamers") and typeof(payload["gamers"]) == TYPE_ARRAY:
		GameManager.set_match_gamers(payload["gamers"] as Array)
	var g_data: Variant = payload.get("game_data", payload)
	if typeof(g_data) == TYPE_DICTIONARY:
		_apply_uno_state_dict(g_data as Dictionary)
	if payload.has("user_data") and typeof(payload["user_data"]) == TYPE_DICTIONARY:
		_apply_uno_state_dict(payload["user_data"] as Dictionary)
	_update_hud_visibility()

func _get_player_screen_anchor(pid: int) -> Vector2:
	if pid == my_player_index:
		return _get_my_hand_center_screen_pos()
	var s_slot: int = int(_pid_to_seat_slot.get(pid, 1))
	if is_instance_valid(table_3d) and table_3d.has_method("get_opponent_seat_screen_pos"):
		return table_3d.get_opponent_seat_screen_pos(s_slot)
	var vp: Vector2 = get_viewport().get_visible_rect().size if get_viewport() else Vector2(720, 1280)
	return Vector2(vp.x * 0.5, vp.y * 0.30)

func _on_uno_event_received(event_type: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var p: Dictionary = payload as Dictionary
	_match_started = true

	match event_type:
		Commands.Card_Played:
			var pid: int = int(p.get("player", p.get("gamer_id", 0)))
			var card: Dictionary = (p.get("card", {}) as Dictionary) if typeof(p.get("card")) == TYPE_DICTIONARY else {}
			if not card.is_empty():
				top_card = card.duplicate(true)
			if pid == my_player_index and card.has("uid"):
				var played_uid: int = int(card["uid"])
				for h_i: int in range(my_hand.size() - 1, -1, -1):
					var hc: Variant = my_hand[h_i]
					if typeof(hc) == TYPE_DICTIONARY and int((hc as Dictionary).get("uid", -1)) == played_uid:
						my_hand.remove_at(h_i)
						break
			if p.has("current_color") and p["current_color"] != null:
				current_color = String(p["current_color"])
			if p.has("direction") and p["direction"] != null:
				direction = int(p["direction"])
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			elif pid > 0 and hands_count.has(str(pid)):
				hands_count[str(pid)] = maxi(0, int(hands_count[str(pid)]) - 1)
			if p.has("deck_remaining") and p["deck_remaining"] != null:
				deck_remaining = int(p["deck_remaining"])
			elif p.has("draw_pile_count") and p["draw_pile_count"] != null:
				deck_remaining = int(p["draw_pile_count"])

			if pid != my_player_index and is_instance_valid(vfx_layer) and is_instance_valid(table_3d):
				var from_opp: Vector2 = _get_player_screen_anchor(pid)
				var to_disc: Vector2 = table_3d.get_discard_pile_screen_pos()
				vfx_layer.animate_card_flight(from_opp, to_disc, card, true, 0.28)

			var actor_name: String = _get_player_short_name(pid)
			var val_str: String = String(card.get("value", ""))
			var cname: String = String(UNO_COLOR_NAMES_FA.get(current_color, "قرمز"))
			var act_col: Color = UNO_COLORS.get(current_color, UNO_COLORS["red"])

			var effect: Dictionary = (p.get("effect", {}) as Dictionary) if typeof(p.get("effect")) == TYPE_DICTIONARY else {}
			var eff_type: String = String(effect.get("type", val_str))

			if is_instance_valid(vfx_layer):
				if eff_type == "skip":
					var sk_p: int = int(effect.get("skipped_player", p.get("skipped_player", 0)))
					vfx_layer.play_special_effect_badge("🚫 پرش نوبت", act_col, 1.35)
					vfx_layer.show_contextual_toast("🚫 نوبت %s سوخت!" % _get_player_short_name(sk_p), act_col, 2.1)
				elif eff_type == "reverse":
					if is_instance_valid(table_3d):
						table_3d.animate_reverse_spin()
					vfx_layer.play_special_effect_badge("⇄ تغییر جهت", act_col, 1.35)
					vfx_layer.show_contextual_toast("⇄ جهت بازی برعکس شد", act_col, 2.0)
				elif eff_type == "draw2":
					var tp2: int = int(effect.get("target_player", p.get("penalty_target", 0)))
					if is_instance_valid(table_3d) and tp2 > 0:
						vfx_layer.animate_penalty_cards(table_3d.get_draw_pile_screen_pos(), _get_player_screen_anchor(tp2), 2)
					vfx_layer.play_special_effect_badge("+۲ جریمه", act_col, 1.45)
					vfx_layer.show_contextual_toast("💥 ۲ کارت جریمه برای %s" % _get_player_short_name(tp2), act_col, 2.2)
				elif eff_type == "wild_draw4":
					var tp4: int = int(effect.get("target_player", p.get("penalty_target", 0)))
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
			_draw_request_pending = false
			if is_instance_valid(draw_action_btn):
				draw_action_btn.disabled = false
			my_player_index = max(1, GameManager.my_player_index)

			if p.has("user_data") and typeof(p["user_data"]) == TYPE_DICTIONARY:
				_apply_uno_state_dict(p["user_data"] as Dictionary, false)
			if p.has("my_hand") and typeof(p["my_hand"]) == TYPE_ARRAY:
				my_hand = (p["my_hand"] as Array).duplicate(true)
			elif p.has("hand") and typeof(p["hand"]) == TYPE_ARRAY:
				my_hand = (p["hand"] as Array).duplicate(true)

			var drawn_dict: Dictionary = (p.get("drawn_card", {}) as Dictionary) if typeof(p.get("drawn_card")) == TYPE_DICTIONARY else {}
			if not drawn_dict.is_empty():
				var d_uid: int = int(drawn_dict.get("uid", -1))
				if d_uid >= 0 and not _has_card_uid_in_hand(d_uid):
					my_hand.append(drawn_dict.duplicate(true))
				_last_drawn_uid = d_uid
			elif not my_hand.is_empty() and typeof(my_hand[-1]) == TYPE_DICTIONARY:
				_last_drawn_uid = int((my_hand[-1] as Dictionary).get("uid", -1))

			hands_count[str(my_player_index)] = my_hand.size()

			var turn_passed: bool = bool(p.get("turn_passed", false))
			var playable: bool = bool(p.get("playable", p.get("drawn_is_playable", false))) and not turn_passed
			if turn_passed:
				has_drawn_this_turn = false
				if p.has("next_turn") and p["next_turn"] != null:
					current_turn = int(p["next_turn"])
					GameManager.current_turn = current_turn
				is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active and not turn_passed
				is_board_locked = not is_my_turn
			else:
				has_drawn_this_turn = playable
				is_my_turn = (current_turn == my_player_index) and GameManager.is_game_active
				is_board_locked = not (is_my_turn and playable)
				if playable and _last_drawn_uid >= 0:
					selected_card_uid = _last_drawn_uid

			if is_instance_valid(vfx_layer):
				if playable:
					vfx_layer.show_contextual_toast("✨ کارت جدید قابل بازی است!", Color(0.38, 0.96, 0.58), 2.1)
				else:
					vfx_layer.show_contextual_toast("🃏 کارت کشیده شد؛ نوبت رد شد", Color(0.75, 0.84, 0.92), 1.8)
			_refresh_all_visuals()

		Commands.Draw_Result:
			_draw_request_pending = false
			if is_instance_valid(draw_action_btn):
				draw_action_btn.disabled = false
			var d_pid: int = int(p.get("player", p.get("gamer_id", 0)))
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			elif d_pid > 0 and hands_count.has(str(d_pid)):
				var d_cnt: int = int(p.get("count", p.get("drawn_count", 1)))
				hands_count[str(d_pid)] = int(hands_count[str(d_pid)]) + maxi(1, d_cnt)
			if p.has("deck_remaining") and p["deck_remaining"] != null:
				deck_remaining = int(p["deck_remaining"])
			elif p.has("draw_pile_count") and p["draw_pile_count"] != null:
				deck_remaining = int(p["draw_pile_count"])
			if d_pid == my_player_index:
				if bool(p.get("turn_passed", false)) and p.has("next_turn") and p["next_turn"] != null:
					current_turn = int(p["next_turn"])
					GameManager.current_turn = current_turn
					has_drawn_this_turn = false
			elif is_instance_valid(vfx_layer):
				if is_instance_valid(table_3d):
					vfx_layer.animate_card_flight(table_3d.get_draw_pile_screen_pos(), _get_player_screen_anchor(d_pid), {}, false, 0.28)
				vfx_layer.show_contextual_toast("🃏 %s یک کارت کشید" % _get_player_short_name(d_pid), Color(0.82, 0.88, 0.96), 1.7)
			_refresh_all_visuals()

		Commands.Pass_Turn:
			var pass_pid: int = int(p.get("player", p.get("gamer_id", 0)))
			if pass_pid == my_player_index:
				_last_drawn_uid = -1
			if p.has("hands_count"):
				_update_hands_count_from_variant(p["hands_count"])
			if is_instance_valid(vfx_layer):
				vfx_layer.show_contextual_toast("⏭️ %s نوبت را رد کرد" % _get_player_short_name(pass_pid), Color(0.95, 0.78, 0.35), 1.6)
			_refresh_all_visuals()

		Commands.Uno_Called:
			var u_pid: int = int(p.get("player", p.get("gamer_id", 0)))
			uno_called[str(u_pid)] = true
			if is_instance_valid(vfx_layer):
				vfx_layer.play_special_effect_badge("🔥 UNO! (%s)" % _get_player_short_name(u_pid), UNO_COLORS["red"], 1.45)
				vfx_layer.show_contextual_toast("🔥 %s اعلام اونو کرد!" % _get_player_short_name(u_pid), Color(1.0, 0.86, 0.28), 2.1)
			_refresh_all_visuals()

		Commands.User_Data:
			# Already handled cleanly by _on_user_data_received (avoid duplicate rebuild)
			pass

func on_not_played_turns_updated(gamer_id: int, count: int) -> void:
	if count <= 0 or not is_instance_valid(vfx_layer):
		return
	var p_name: String = _get_player_short_name(gamer_id)
	var fa_cnt: String = UnoCardWidgetScript.to_fa_digits(str(count))
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
	_last_drawn_uid = -1
	_draw_request_pending = false
	my_hand.clear()
	hands_count.clear()
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
