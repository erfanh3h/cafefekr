class_name LiveGamesDialog
extends Control

## Cafe Fekr — Refined Live Spectator Browser Dialog
## Fetches ongoing active matches from both Socket.IO backend RAM and REST API,
## and renders a double-beveled antique walnut & gold parlor browser with clean hierarchy.

signal closed()

const TEX_REFRESH: Texture2D = preload("res://assets/images/frames/refresh.png")

var _dim_overlay: ColorRect = null
var main_panel: PanelContainer = null
var _inner_bezel: PanelContainer = null
var _lbl_live_sub: Label = null
var _live_dot: Panel = null
var _scope_row: HBoxContainer = null
var _mode_row: HBoxContainer = null
var _game_filter_hbox: HBoxContainer = null
var _list_vbox: VBoxContainer = null
var _scroll_games: ScrollContainer = null

var current_scope: String = "all"         # "all" | "friends" | "clan"
var current_game_mode: String = ""        # "" | "Rank" | "MultiRank" | "ClassicRank" | "Lobby"
var current_game_type: String = ""        # "" or canonical GameTypes string

const NON_SPECTATABLE_GAMES: Array[String] = [
	"battleship", "uno", "coup", "fekrbekr", "sudoku", "msweeper", "quiz", "rpc"
]

var _merged_games: Dictionary = {}        # game_id -> Dictionary
var _is_loading: bool = false
var _request_token: int = 0


static func _normalize_mode(m: String) -> String:
	return m.strip_edges().to_lower().replace("_", "").replace("-", "").replace(" ", "")


static func _get_mode_label_fa(m: String) -> String:
	match _normalize_mode(m):
		"rank":
			return "رقابتی"
		"multirank":
			return "چندنفره"
		"classicrank":
			return "کلاسیک"
		"lobby":
			return "لابی"
		"normal":
			return "عادی"
		_:
			return ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 48
	_build_ui()
	if not NetworkManager.live_games_list_received.is_connected(_on_realtime_live_games_received):
		NetworkManager.live_games_list_received.connect(_on_realtime_live_games_received)


func open(initial_scope: String = "all") -> void:
	if not GameManager.is_logged_in:
		return
	current_scope = initial_scope
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(main_panel):
		main_panel.scale = Vector2.ONE
		if main_panel.size.x < 100.0 or main_panel.size.y < 100.0:
			main_panel.size = main_panel.custom_minimum_size
		main_panel.pivot_offset = main_panel.size * 0.5
	_render_filters()
	refresh()
	ActionVFXManager.animate_dialog_open(main_panel, self, true)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(main_panel, self, func():
		visible = false
		closed.emit()
	)


func close_immediate() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	closed.emit()


func refresh() -> void:
	if not is_instance_valid(_list_vbox):
		return
	_request_token += 1
	var req_token: int = _request_token
	_merged_games.clear()
	_is_loading = true
	_update_live_header_status(-1)
	_show_loading_state()

	# Source 1: Direct Socket.IO /social query (live RAM games in kafehfekrbackend)
	if NetworkManager.is_online:
		if NetworkManager.is_social_connected:
			NetworkManager.request_live_games_realtime(current_scope, current_game_type, current_game_mode)
		else:
			NetworkManager.connect_social_namespace()
			get_tree().create_timer(0.55).timeout.connect(func():
				if req_token == _request_token and visible and NetworkManager.is_online:
					NetworkManager.request_live_games_realtime(current_scope, current_game_type, current_game_mode)
			)

	# Source 2: REST API query (/spectator/live-games in kafehfekrserver)
	NetworkManager.api.get_live_spectator_games(
		current_scope,
		current_game_type,
		"",
		"",
		1,
		30,
		func(ok: bool, _code: int, data: Variant):
			if req_token != _request_token or not is_instance_valid(_list_vbox):
				return
			_is_loading = false
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var res: Dictionary = data["result"]
				var arr: Array = []
				if typeof(res.get("items")) == TYPE_ARRAY:
					arr = res["items"]
				elif typeof(res.get("games")) == TYPE_ARRAY:
					arr = res["games"]
				_ingest_games_array(arr)
			_render_games_list(),
		current_game_mode
	)

	get_tree().create_timer(2.0).timeout.connect(func():
		if req_token == _request_token and _is_loading and is_instance_valid(_list_vbox):
			_is_loading = false
			_render_games_list()
	)


func _on_realtime_live_games_received(payload: Dictionary) -> void:
	if not visible:
		return
	var req_scope: String = str(payload.get("scope", "all")).strip_edges().to_lower()
	var req_gtype: String = str(payload.get("game_type", "")).strip_edges().to_lower()
	var req_mode: String = _normalize_mode(str(payload.get("game_mode", "")))
	if req_scope != current_scope.strip_edges().to_lower() \
		or req_gtype != current_game_type.strip_edges().to_lower() \
		or req_mode != _normalize_mode(current_game_mode):
		return
	_is_loading = false
	var arr: Array = payload.get("items", []) if typeof(payload.get("items")) == TYPE_ARRAY else []
	_ingest_games_array(arr)
	_render_games_list()


func _ingest_games_array(arr: Array) -> void:
	var target_mode_norm: String = _normalize_mode(current_game_mode)
	for item in arr:
		if typeof(item) == TYPE_DICTIONARY:
			var d: Dictionary = item as Dictionary
			var gid: String = str(d.get("game_id", ""))
			if gid.is_empty():
				continue
			if not current_game_type.is_empty():
				var gt: String = str(d.get("game_type", "")).strip_edges().to_lower()
				if gt != current_game_type.strip_edges().to_lower():
					continue
			if not target_mode_norm.is_empty():
				var gm: String = _normalize_mode(str(d.get("game_score_type", "")))
				if gm != target_mode_norm:
					continue
			if not _merged_games.has(gid):
				_merged_games[gid] = d
			else:
				var existing: Dictionary = _merged_games[gid] as Dictionary
				if int(d.get("spectator_count", 0)) > int(existing.get("spectator_count", 0)):
					existing["spectator_count"] = int(d.get("spectator_count", 0))
				if str(existing.get("game_score_type", "")).is_empty() and not str(d.get("game_score_type", "")).is_empty():
					existing["game_score_type"] = d.get("game_score_type", "")
				var ex_players: Array = existing.get("players", []) if typeof(existing.get("players")) == TYPE_ARRAY else []
				var new_players: Array = d.get("players", []) if typeof(d.get("players")) == TYPE_ARRAY else []
				if ex_players.is_empty() and not new_players.is_empty():
					existing["players"] = new_players
				_merged_games[gid] = existing


func _make_parlor_outer_frame_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.125, 0.075, 0.042, 0.99)
	sb.border_color = Color(0.89, 0.70, 0.29, 0.98)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(26)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	return sb


func _make_parlor_inner_inlay_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.082, 0.048, 0.027, 0.98)
	sb.border_color = Color(0.78, 0.59, 0.24, 0.44)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb


func _make_header_crown_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.100, 0.056, 0.97)
	sb.border_color = Color(0.85, 0.67, 0.28, 0.62)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


func _make_medallion_wrap() -> PanelContainer:
	var wrap: PanelContainer = PanelContainer.new()
	wrap.custom_minimum_size = Vector2(46, 46)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.065, 0.036, 0.95)
	sb.border_color = Color(0.82, 0.64, 0.28, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(23)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	wrap.add_theme_stylebox_override("panel", sb)
	return wrap


func _make_track_style(corner: int = 14, pad_x: float = 6.0, pad_y: float = 6.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.036, 0.020, 0.94)
	sb.border_color = Color(0.50, 0.36, 0.18, 0.64)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func _style_segment_button(
	btn: Button,
	is_active: bool,
	bg_active: Color,
	border_active: Color,
	text_active: Color,
	font_res: Font,
	font_size: int
) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", font_res)
	btn.add_theme_font_size_override("font_size", font_size)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0

	var txt_col: Color = Color(0.84, 0.78, 0.68, 0.90)
	if is_active:
		sb.bg_color = bg_active
		sb.border_color = border_active
		sb.set_border_width_all(2)
		txt_col = text_active
	else:
		sb.bg_color = Color(0.115, 0.072, 0.042, 0.88)
		sb.border_color = Color(0.38, 0.28, 0.16, 0.45)
		sb.set_border_width_all(1)

	var sb_hover: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = sb.bg_color.lightened(0.08)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", sb)

	btn.add_theme_color_override("font_color", txt_col)
	btn.add_theme_color_override("font_hover_color", text_active if is_active else Color(1.0, 0.98, 0.92, 1.0))
	btn.add_theme_color_override("font_pressed_color", txt_col)
	btn.add_theme_color_override("font_focus_color", txt_col)
	btn.add_theme_color_override("font_hover_pressed_color", txt_col)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.44, 0.6))


func _update_live_header_status(count: int) -> void:
	if not is_instance_valid(_lbl_live_sub) or not is_instance_valid(_live_dot):
		return
	var dot_sb: StyleBoxFlat = StyleBoxFlat.new()
	dot_sb.set_corner_radius_all(5)
	if count < 0:
		_lbl_live_sub.text = "در حال دریافت مسابقات زنده..."
		_lbl_live_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		dot_sb.bg_color = CafeSocialTheme.COL_GOLD_BRIGHT
	elif count == 0:
		_lbl_live_sub.text = "مسابقه‌ای با این فیلتر فعال نیست"
		_lbl_live_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		dot_sb.bg_color = Color(0.58, 0.52, 0.46, 0.85)
	else:
		_lbl_live_sub.text = "%s مسابقه زنده در حال برگزاری" % GameManager.to_fa_num(count)
		_lbl_live_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_EMERALD_TEXT)
		dot_sb.bg_color = Color(0.32, 0.92, 0.52, 1.0)
	_live_dot.add_theme_stylebox_override("panel", dot_sb)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	_dim_overlay = ColorRect.new()
	_dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dim_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dim_overlay.color = Color(0.02, 0.012, 0.008, 0.84)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	# Safe Viewport-Bounded Outer Margin Host
	var screen_margin: MarginContainer = MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	screen_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	screen_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_margin.add_theme_constant_override("margin_left", 20)
	screen_margin.add_theme_constant_override("margin_right", 20)
	screen_margin.add_theme_constant_override("margin_top", 34)
	screen_margin.add_theme_constant_override("margin_bottom", 34)
	add_child(screen_margin)

	# Double-Beveled Antique Walnut & Gold Parlor Frame
	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.clip_contents = false
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.add_theme_stylebox_override("panel", _make_parlor_outer_frame_style())
	screen_margin.add_child(main_panel)

	_inner_bezel = PanelContainer.new()
	_inner_bezel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner_bezel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner_bezel.clip_contents = true
	_inner_bezel.add_theme_stylebox_override("panel", _make_parlor_inner_inlay_style())
	main_panel.add_child(_inner_bezel)

	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	_inner_bezel.add_child(root)

	# 1. Sculpted Parlor Header Crown (Close Medallion + Title/Live Status + Refresh Medallion)
	var header_crown: PanelContainer = PanelContainer.new()
	header_crown.add_theme_stylebox_override("panel", _make_header_crown_style())
	root.add_child(header_crown)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header_crown.add_child(header)

	var close_wrap: PanelContainer = _make_medallion_wrap()
	header.add_child(close_wrap)

	var btn_close: TextureButton = TextureButton.new()
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_close.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	close_wrap.add_child(btn_close)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	title_box.add_child(CafeSocialTheme.make_title(
		"تماشای زنده بازی‌ها",
		28,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	))

	var live_row: HBoxContainer = HBoxContainer.new()
	live_row.alignment = BoxContainer.ALIGNMENT_CENTER
	live_row.add_theme_constant_override("separation", 7)
	title_box.add_child(live_row)

	_lbl_live_sub = CafeSocialTheme.make_body(
		"مسابقات زنده کافه فکر",
		15,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	live_row.add_child(_lbl_live_sub)

	_live_dot = Panel.new()
	_live_dot.custom_minimum_size = Vector2(9, 9)
	_live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var init_dot: StyleBoxFlat = StyleBoxFlat.new()
	init_dot.bg_color = Color(0.32, 0.92, 0.52, 1.0)
	init_dot.set_corner_radius_all(5)
	_live_dot.add_theme_stylebox_override("panel", init_dot)
	live_row.add_child(_live_dot)

	var ref_wrap: PanelContainer = _make_medallion_wrap()
	header.add_child(ref_wrap)

	var btn_ref: TextureButton = TextureButton.new()
	btn_ref.texture_normal = TEX_REFRESH
	btn_ref.custom_minimum_size = Vector2(36, 36)
	btn_ref.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ref.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_ref.ignore_texture_size = true
	btn_ref.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_ref.focus_mode = Control.FOCUS_NONE
	btn_ref.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_ref.tooltip_text = "بروزرسانی فهرست"
	ActionVFXManager.apply_button_juice(btn_ref, "tap_button")
	btn_ref.pressed.connect(func():
		AudioManager.sfx_tap()
		refresh()
	)
	ref_wrap.add_child(btn_ref)

	# 1b. Ornamental Gold Hairline Divider
	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color(0.84, 0.66, 0.28, 0.32)
	root.add_child(divider)

	# 2. Scope Segmented Bar (All | Friends | Clan)
	var scope_well: PanelContainer = PanelContainer.new()
	scope_well.add_theme_stylebox_override("panel", _make_track_style(14, 6.0, 6.0))
	root.add_child(scope_well)

	_scope_row = HBoxContainer.new()
	_scope_row.add_theme_constant_override("separation", 6)
	scope_well.add_child(_scope_row)

	# 2b. Game Mode Filter Row (All | Rank | MultiRank | ClassicRank | Lobby)
	var mode_well: PanelContainer = PanelContainer.new()
	mode_well.add_theme_stylebox_override("panel", _make_track_style(12, 6.0, 5.0))
	root.add_child(mode_well)

	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 5)
	_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_well.add_child(_mode_row)

	# 3. Framed Scrollable Game Filter Strip
	var filter_scroll: ScrollContainer = ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 74)
	filter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.clip_contents = true
	root.add_child(filter_scroll)

	_game_filter_hbox = HBoxContainer.new()
	_game_filter_hbox.add_theme_constant_override("separation", 8)
	_game_filter_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_scroll.add_child(_game_filter_hbox)

	# 4. Scrollable Matches Container
	_scroll_games = ScrollContainer.new()
	_scroll_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_games.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_games.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_games.clip_contents = true
	root.add_child(_scroll_games)

	var list_pad: MarginContainer = MarginContainer.new()
	list_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_pad.add_theme_constant_override("margin_left", 2)
	list_pad.add_theme_constant_override("margin_right", 2)
	list_pad.add_theme_constant_override("margin_top", 2)
	list_pad.add_theme_constant_override("margin_bottom", 8)
	_scroll_games.add_child(list_pad)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_list_vbox.add_theme_constant_override("separation", 12)
	list_pad.add_child(_list_vbox)

	_render_filters()


func _render_filters() -> void:
	if is_instance_valid(_scope_row):
		for c in _scope_row.get_children():
			c.queue_free()
		# RTL visual order: All rightmost
		var scopes: Array = [
			{"id": "clan", "label": "اتحاد من"},
			{"id": "friends", "label": "دوستان"},
			{"id": "all", "label": "همه بازی‌ها"},
		]
		for sc in scopes:
			var sc_d: Dictionary = sc as Dictionary
			var sid: String = str(sc_d["id"])
			var is_sel: bool = (current_scope == sid)
			var b: Button = Button.new()
			b.text = str(sc_d["label"])
			b.custom_minimum_size = Vector2(0, 44)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_segment_button(
				b,
				is_sel,
				Color(0.58, 0.41, 0.12, 0.98),
				Color(1.0, 0.86, 0.36, 1.0),
				Color(1.0, 0.98, 0.90, 1.0),
				CafeSocialTheme.FONT_TITLE,
				21
			)
			ActionVFXManager.apply_button_juice(b, "tap_button")
			b.pressed.connect(func():
				AudioManager.sfx_tap()
				current_scope = sid
				_render_filters()
				refresh()
			)
			_scope_row.add_child(b)

	if is_instance_valid(_mode_row):
		for c in _mode_row.get_children():
			c.queue_free()
		var modes: Array = [
			{"id": "Lobby", "label": "لابی"},
			{"id": "ClassicRank", "label": "کلاسیک"},
			{"id": "MultiRank", "label": "چندنفره"},
			{"id": "Rank", "label": "رقابتی"},
			{"id": "", "label": "همه"},
		]
		for md in modes:
			var md_d: Dictionary = md as Dictionary
			var mid: String = str(md_d["id"])
			var is_m_sel: bool = (_normalize_mode(current_game_mode) == _normalize_mode(mid))
			var bm: Button = Button.new()
			bm.text = str(md_d["label"])
			bm.custom_minimum_size = Vector2(0, 38)
			bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_segment_button(
				bm,
				is_m_sel,
				Color(0.13, 0.34, 0.21, 0.98),
				Color(0.42, 0.86, 0.56, 0.95),
				Color(0.96, 1.0, 0.96, 1.0),
				CafeSocialTheme.FONT_BODY,
				15
			)
			ActionVFXManager.apply_button_juice(bm, "tap_button")
			bm.pressed.connect(func():
				AudioManager.sfx_tap()
				current_game_mode = mid
				_render_filters()
				refresh()
			)
			_mode_row.add_child(bm)

	if is_instance_valid(_game_filter_hbox):
		for c in _game_filter_hbox.get_children():
			c.queue_free()

		# 1. Explicit labeled "همه بازی‌ها" chip (replaces confusing question.png icon)
		var is_all_sel: bool = current_game_type.is_empty()
		var btn_all: Button = Button.new()
		btn_all.text = "همه بازی‌ها"
		btn_all.custom_minimum_size = Vector2(92, 62)
		btn_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_segment_button(
			btn_all,
			is_all_sel,
			Color(0.32, 0.21, 0.08, 0.98),
			Color(0.98, 0.82, 0.32, 1.0),
			CafeSocialTheme.COL_GOLD_BRIGHT,
			CafeSocialTheme.FONT_BODY,
			15
		)
		ActionVFXManager.apply_button_juice(btn_all, "tap_button")
		btn_all.pressed.connect(func():
			AudioManager.sfx_tap()
			current_game_type = ""
			_render_filters()
			refresh()
		)
		_game_filter_hbox.add_child(btn_all)

		# 2. Framed Spectatable Game Icon Chips
		for g in GamesHistoryViewHelper.GAMES_LIST:
			var gid_raw: String = str(g.get("id", ""))
			var gid_check: String = gid_raw.strip_edges().to_lower()
			if gid_check in NON_SPECTATABLE_GAMES:
				continue
			var is_sel: bool = (current_game_type == gid_raw)

			var tile: PanelContainer = PanelContainer.new()
			tile.custom_minimum_size = Vector2(64, 64)
			tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var tile_sb: StyleBoxFlat = StyleBoxFlat.new()
			tile_sb.set_corner_radius_all(13)
			tile_sb.content_margin_left = 4.0
			tile_sb.content_margin_right = 4.0
			tile_sb.content_margin_top = 4.0
			tile_sb.content_margin_bottom = 4.0
			if is_sel:
				tile_sb.bg_color = Color(0.28, 0.19, 0.07, 0.98)
				tile_sb.border_color = Color(1.0, 0.86, 0.34, 1.0)
				tile_sb.set_border_width_all(2)
				tile_sb.shadow_color = Color(1.0, 0.82, 0.24, 0.35)
				tile_sb.shadow_size = 5
			else:
				tile_sb.bg_color = Color(0.11, 0.068, 0.038, 0.90)
				tile_sb.border_color = Color(0.48, 0.35, 0.19, 0.55)
				tile_sb.set_border_width_all(1)
			tile.add_theme_stylebox_override("panel", tile_sb)
			_game_filter_hbox.add_child(tile)

			var btn: TextureButton = TextureButton.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = str(g.get("name_fa", gid_raw))
			btn.texture_normal = CafeSocialTheme.get_game_thumb(gid_raw)
			btn.self_modulate = Color(1.12, 1.10, 1.06, 1.0) if is_sel else Color(0.76, 0.72, 0.66, 0.82)

			ActionVFXManager.apply_button_juice(btn, "tap_button")
			btn.pressed.connect(func():
				AudioManager.sfx_tap()
				current_game_type = gid_raw
				_render_filters()
				refresh()
			)
			tile.add_child(btn)


func _show_loading_state() -> void:
	if not is_instance_valid(_list_vbox):
		return
	for c in _list_vbox.get_children():
		c.queue_free()
	_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت مسابقات زنده..."))


func _build_empty_state_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.135, 0.082, 0.046, 0.95)
	sb.border_color = Color(0.68, 0.52, 0.25, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	card.add_theme_stylebox_override("panel", sb)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	vb.add_child(CafeSocialTheme.make_title(
		"مسابقه زنده‌ای یافت نشد",
		24,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	))

	var has_filters: bool = (current_scope != "all") or (not current_game_mode.is_empty()) or (not current_game_type.is_empty())
	var sub_msg: String = "در حال حاضر مسابقه‌ای با فیلترهای انتخابی شما در جریان نیست." if has_filters else "فعلاً هیچ مسابقه قابل تماشایی در کافه فعال نیست. لحظاتی دیگر دوباره بررسی کنید."
	vb.add_child(CafeSocialTheme.make_body(
		sub_msg,
		17,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	))

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var btn_retry: Button = CafeSocialTheme.make_button("بروزرسانی فهرست", "emerald", Vector2(154, 44), 17)
	btn_retry.pressed.connect(func():
		AudioManager.sfx_tap()
		refresh()
	)
	btn_row.add_child(btn_retry)

	if has_filters:
		var btn_reset: Button = CafeSocialTheme.make_button("نمایش همه بازی‌ها", "bronze", Vector2(154, 44), 17)
		btn_reset.pressed.connect(func():
			AudioManager.sfx_tap()
			current_scope = "all"
			current_game_mode = ""
			current_game_type = ""
			_render_filters()
			refresh()
		)
		btn_row.add_child(btn_reset)

	return card


func _render_games_list() -> void:
	if not is_instance_valid(_list_vbox):
		return
	for c in _list_vbox.get_children():
		c.queue_free()

	var items: Array = _merged_games.values()
	items.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: Dictionary = a if typeof(a) == TYPE_DICTIONARY else {}
		var db: Dictionary = b if typeof(b) == TYPE_DICTIONARY else {}
		var sa: int = (1000 if bool(da.get("has_friend", false)) else 0) + (500 if bool(da.get("has_clanmate", false)) else 0) + int(da.get("spectator_count", 0))
		var sb: int = (1000 if bool(db.get("has_friend", false)) else 0) + (500 if bool(db.get("has_clanmate", false)) else 0) + int(db.get("spectator_count", 0))
		return sa > sb
	)

	_update_live_header_status(items.size())

	if items.is_empty():
		_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		_list_vbox.add_child(_build_empty_state_card())
		return

	_list_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			_list_vbox.add_child(_build_match_card(item as Dictionary))


func _build_match_card(m: Dictionary) -> PanelContainer:
	var gid: String = str(m.get("game_id", ""))
	var gtype: String = str(m.get("game_type", "Ludo"))
	var gtitle: String = GameRegistry.get_display_name_fa(gtype)
	var mode_fa: String = _get_mode_label_fa(str(m.get("game_score_type", "")))
	var spec_cnt: int = int(m.get("spectator_count", 0))
	var has_friend: bool = bool(m.get("has_friend", false))
	var has_clanmate: bool = bool(m.get("has_clanmate", false))
	var players: Array = m.get("players", []) if typeof(m.get("players")) == TYPE_ARRAY else []

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	var card_sb: StyleBoxFlat = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.155, 0.095, 0.054, 0.97)
	card_sb.border_color = Color(0.84, 0.66, 0.28, 0.84) if (has_friend or has_clanmate) else Color(0.68, 0.52, 0.25, 0.72)
	card_sb.border_width_left = 1
	card_sb.border_width_right = 1
	card_sb.border_width_bottom = 1
	card_sb.border_width_top = 2
	card_sb.set_corner_radius_all(18)
	card_sb.content_margin_left = 14.0
	card_sb.content_margin_right = 14.0
	card_sb.content_margin_top = 12.0
	card_sb.content_margin_bottom = 12.0
	card_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	card_sb.shadow_size = 7
	card_sb.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Row 1: Badges (Left) + Title & Meta (Center-Right) + Game Thumbnail (Far-Right)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_row)

	var badges_col: VBoxContainer = VBoxContainer.new()
	badges_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badges_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badges_col.add_theme_constant_override("separation", 5)
	top_row.add_child(badges_col)

	# Live Viewer Pill (Emerald dot + Persian count — zero raw emojis)
	var eye_pill: PanelContainer = PanelContainer.new()
	var eye_st: StyleBoxFlat = StyleBoxFlat.new()
	eye_st.bg_color = CafeSocialTheme.COL_EMERALD_BG
	eye_st.border_color = CafeSocialTheme.COL_EMERALD_BORDER
	eye_st.set_border_width_all(1)
	eye_st.set_corner_radius_all(10)
	eye_st.content_margin_left = 9.0
	eye_st.content_margin_right = 9.0
	eye_st.content_margin_top = 3.0
	eye_st.content_margin_bottom = 3.0
	eye_pill.add_theme_stylebox_override("panel", eye_st)
	var eye_hbox: HBoxContainer = HBoxContainer.new()
	eye_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	eye_hbox.add_theme_constant_override("separation", 6)
	eye_pill.add_child(eye_hbox)
	eye_hbox.add_child(CafeSocialTheme.make_body("%s بیننده" % GameManager.to_fa_num(spec_cnt), 14, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	var live_pip: Panel = Panel.new()
	live_pip.custom_minimum_size = Vector2(8, 8)
	live_pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pip_sb: StyleBoxFlat = StyleBoxFlat.new()
	pip_sb.bg_color = Color(0.34, 0.94, 0.56, 1.0)
	pip_sb.set_corner_radius_all(4)
	live_pip.add_theme_stylebox_override("panel", pip_sb)
	eye_hbox.add_child(live_pip)
	badges_col.add_child(eye_pill)

	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	tag_row.add_theme_constant_override("separation", 5)
	badges_col.add_child(tag_row)

	if not mode_fa.is_empty():
		tag_row.add_child(CafeSocialTheme.make_badge_pill(
			mode_fa,
			CafeSocialTheme.COL_WARM_CREAM,
			Color(0.11, 0.07, 0.04, 0.94),
			CafeSocialTheme.COL_BRONZE_BORDER,
			13
		))
	if has_friend:
		tag_row.add_child(CafeSocialTheme.make_badge_pill(
			"دوست",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.20, 0.13, 0.05, 0.96),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			13
		))
	elif has_clanmate:
		tag_row.add_child(CafeSocialTheme.make_badge_pill(
			"اتحاد",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.20, 0.13, 0.05, 0.96),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			13
		))

	var title_col: VBoxContainer = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 2)
	top_row.add_child(title_col)

	var t_lbl: Label = CafeSocialTheme.make_title(
		"مسابقه %s" % gtitle,
		23,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(t_lbl)

	var sub_lbl: Label = CafeSocialTheme.make_body(
		"%s بازیکن  •  در حال رقابت" % GameManager.to_fa_num(maxi(2, players.size())),
		15,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(sub_lbl)

	var thumb_wrap: PanelContainer = PanelContainer.new()
	thumb_wrap.custom_minimum_size = Vector2(60, 60)
	thumb_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_wrap.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.08, 0.05, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 14, 2, 4.0, 4.0))
	top_row.add_child(thumb_wrap)

	var thumb: TextureRect = TextureRect.new()
	thumb.texture = CafeSocialTheme.get_game_thumb(gtype)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_wrap.add_child(thumb)

	# Row 2: Players Matchup Strip
	if not players.is_empty():
		var players_well: PanelContainer = PanelContainer.new()
		players_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		players_well.clip_contents = true
		players_well.add_theme_stylebox_override("panel", _make_track_style(12, 10.0, 8.0))
		vbox.add_child(players_well)

		var make_player_chip: Callable = func(pd: Dictionary) -> HBoxContainer:
			var p_chip: HBoxContainer = HBoxContainer.new()
			p_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_chip.alignment = BoxContainer.ALIGNMENT_CENTER
			p_chip.add_theme_constant_override("separation", 6)
			var av_id: int = int(pd.get("avatar", pd.get("image", 0)))
			var fr_id: int = int(pd.get("profile_frame", 0))
			p_chip.add_child(CafeSocialTheme.make_avatar_badge(av_id, maxi(1, fr_id), 44.0, "", false))
			var pname: String = str(pd.get("username", "بازیکن"))
			var c_info: Variant = pd.get("clan", null)
			if typeof(c_info) == TYPE_DICTIONARY and not str((c_info as Dictionary).get("tag", "")).is_empty():
				pname += " [%s]" % str((c_info as Dictionary).get("tag", ""))
			var p_lbl: Label = CafeSocialTheme.make_body(pname, 18, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
			p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_lbl.clip_text = true
			p_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			p_chip.add_child(p_lbl)
			return p_chip

		if players.size() > 2:
			var players_grid: GridContainer = GridContainer.new()
			players_grid.columns = 2
			players_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			players_grid.add_theme_constant_override("h_separation", 10)
			players_grid.add_theme_constant_override("v_separation", 8)
			players_well.add_child(players_grid)
			for p_item in players:
				if typeof(p_item) == TYPE_DICTIONARY:
					players_grid.add_child(make_player_chip.call(p_item as Dictionary))
		else:
			var players_row: HBoxContainer = HBoxContainer.new()
			players_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			players_row.alignment = BoxContainer.ALIGNMENT_CENTER
			players_row.add_theme_constant_override("separation", 8)
			players_well.add_child(players_row)
			for i in range(players.size()):
				var p_item: Variant = players[i]
				if typeof(p_item) != TYPE_DICTIONARY:
					continue
				if i > 0:
					var vs_pill: PanelContainer = CafeSocialTheme.make_badge_pill(
						"در برابر",
						CafeSocialTheme.COL_GOLD_BRIGHT,
						Color(0.18, 0.12, 0.05, 0.95),
						CafeSocialTheme.COL_GOLD_ANTIQUE,
						13
					)
					vs_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					players_row.add_child(vs_pill)
				players_row.add_child(make_player_chip.call(p_item as Dictionary))

	# Row 3: Full-width Watch Action Button
	var btn_watch: Button = CafeSocialTheme.make_button("تماشای زنده مسابقه", "gold", Vector2(0, 50), 22, null, true)
	btn_watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_watch.pressed.connect(func():
		AudioManager.sfx_button()
		close_immediate()
		NetworkManager.request_spectate_game(gid)
	)
	vbox.add_child(btn_watch)

	return card
