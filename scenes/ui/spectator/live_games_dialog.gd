class_name LiveGamesDialog
extends Control

## Cafe Fekr — Centered Live Spectator Browser Dialog
## Fetches ongoing active matches from both Socket.IO backend RAM and REST API,
## and renders a centered antique Cafe Fekr card browser with clean hierarchy.

signal closed()

var _dim_overlay: ColorRect = null
var _screen_margin: MarginContainer = null
var main_panel: PanelContainer = null
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
	_apply_safe_area_and_width()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_safe_area_and_width):
		get_viewport().size_changed.connect(_apply_safe_area_and_width)
	if not NetworkManager.live_games_list_received.is_connected(_on_realtime_live_games_received):
		NetworkManager.live_games_list_received.connect(_on_realtime_live_games_received)


func _apply_safe_area_and_width() -> void:
	if not is_instance_valid(_screen_margin) or get_viewport() == null:
		return
	var vis_w: float = get_viewport().get_visible_rect().size.x
	var extra_x: int = maxi(20, int(round((vis_w - 680.0) * 0.5))) if vis_w > 740.0 else 20
	CafeSocialTheme.apply_safe_area_to_margin(_screen_margin, extra_x, 28, extra_x, 28, true, true)


func open(initial_scope: String = "all") -> void:
	if not GameManager.is_logged_in:
		return
	current_scope = initial_scope
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_safe_area_and_width()
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
			var d: Dictionary = item
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
				var existing: Dictionary = _merged_games[gid]
				if int(d.get("spectator_count", 0)) > int(existing.get("spectator_count", 0)):
					existing["spectator_count"] = int(d.get("spectator_count", 0))
				if str(existing.get("game_score_type", "")).is_empty() and not str(d.get("game_score_type", "")).is_empty():
					existing["game_score_type"] = d.get("game_score_type", "")
				var ex_players: Array = existing.get("players", []) if typeof(existing.get("players")) == TYPE_ARRAY else []
				var new_players: Array = d.get("players", []) if typeof(d.get("players")) == TYPE_ARRAY else []
				if ex_players.is_empty() and not new_players.is_empty():
					existing["players"] = new_players
				_merged_games[gid] = existing


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
	_dim_overlay.color = Color(0.03, 0.015, 0.01, 0.80)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	# Screen-bounded Margin host so the dialog can NEVER overflow left/right of viewport or clip notches
	_screen_margin = MarginContainer.new()
	_screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_screen_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	_screen_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_margin.add_theme_constant_override("margin_left", 20)
	_screen_margin.add_theme_constant_override("margin_right", 20)
	_screen_margin.add_theme_constant_override("margin_top", 28)
	_screen_margin.add_theme_constant_override("margin_bottom", 28)
	add_child(_screen_margin)

	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.clip_contents = true
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	_screen_margin.add_child(main_panel)

	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_top", 22)
	inner.add_theme_constant_override("margin_bottom", 22)
	main_panel.add_child(inner)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	inner.add_child(root)

	# 1. Header Row (Close left, Ornate Title + Subtitle center, Refresh right)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(header)

	var btn_close := TextureButton.new()
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(48, 48)
	btn_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	header.add_child(btn_close)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	title_box.add_child(CafeSocialTheme.make_title(
		"تماشای زنده بازی‌ها",
		CafeSocialTheme.FONT_SIZE_CARD_TITLE,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	))
	title_box.add_child(CafeSocialTheme.make_body(
		"مسابقات در حال برگزاری کافه فکر را به صورت زنده تماشا کنید",
		CafeSocialTheme.FONT_SIZE_BADGE,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	))

	var btn_ref := TextureButton.new()
	btn_ref.texture_normal = preload("res://assets/images/frames/refresh.png")
	btn_ref.custom_minimum_size = Vector2(48, 48)
	btn_ref.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	header.add_child(btn_ref)

	# 2. Scope Subtab Bar (All | Friends | Clan) - Clean KenneyUI tabs without shadow/well background
	var scope_well := PanelContainer.new()
	scope_well.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(scope_well)

	_scope_row = HBoxContainer.new()
	_scope_row.add_theme_constant_override("separation", 10)
	scope_well.add_child(_scope_row)

	# 2b. Game Mode Filter Row (All | Rank | MultiRank | ClassicRank | Lobby)
	var mode_well := PanelContainer.new()
	mode_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(12, 8.0, 6.0))
	root.add_child(mode_well)

	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 6)
	_mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_well.add_child(_mode_row)

	# 3. Clean 1-Row Scrollable Game Filter Row (no outer box/padding around icons)
	var filter_scroll := ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 86)
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

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_list_vbox.add_theme_constant_override("separation", 14)
	_scroll_games.add_child(_list_vbox)

	_render_filters()


func _render_filters() -> void:
	if is_instance_valid(_scope_row):
		for c in _scope_row.get_children():
			c.queue_free()
		var scopes: Array = [
			{"id": "all", "label": "همه بازی‌ها"},
			{"id": "friends", "label": "دوستان"},
			{"id": "clan", "label": "کلن من"},
		]
		for sc in scopes:
			var sc_d: Dictionary = sc
			var sid: String = str(sc_d["id"])
			var b := Button.new()
			b.text = str(sc_d["label"])
			b.custom_minimum_size = Vector2(0, 56)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
			b.add_theme_font_size_override("font_size", CafeSocialTheme.FONT_SIZE_TAB_COMPACT)
			if current_scope == sid:
				KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
				b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
			else:
				KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
				b.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))
			CafeSocialTheme.configure_single_line_tab(b, CafeSocialTheme.FONT_SIZE_TAB_COMPACT, 56.0, 6.0)
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
			{"id": "", "label": "همه"},
			{"id": "Rank", "label": "رقابتی"},
			{"id": "MultiRank", "label": "چندنفره"},
			{"id": "ClassicRank", "label": "کلاسیک"},
			{"id": "Lobby", "label": "لابی"},
		]
		for md in modes:
			var md_d: Dictionary = md
			var mid: String = str(md_d["id"])
			var is_m_sel: bool = (_normalize_mode(current_game_mode) == _normalize_mode(mid))
			var bm := CafeSocialTheme.make_button(
				str(md_d["label"]),
				"emerald" if is_m_sel else "muted",
				Vector2(0, 48),
				CafeSocialTheme.FONT_SIZE_BADGE
			)
			bm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			CafeSocialTheme.configure_single_line_tab(bm, CafeSocialTheme.FONT_SIZE_BADGE, 48.0, 4.0)
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

		# Spectatable games + "all"
		var gfilters: Array = [{"id": "", "label": "همه"}]
		for g in GamesHistoryViewHelper.GAMES_LIST:
			var gid_check: String = str(g.get("id", "")).strip_edges().to_lower()
			if gid_check in NON_SPECTATABLE_GAMES:
				continue
			gfilters.append({"id": g["id"], "label": g["name_fa"]})

		for gf in gfilters:
			var gf_d: Dictionary = gf
			var gid_f: String = str(gf_d["id"])
			var is_sel: bool = (current_game_type == gid_f)

			var btn := TextureButton.new()
			btn.custom_minimum_size = Vector2(80, 80)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = str(gf_d["label"])
			if gid_f.is_empty():
				btn.texture_normal = preload("res://assets/images/frames/question.png")
			else:
				btn.texture_normal = CafeSocialTheme.get_game_thumb(gid_f)

			# No box or padding: fill button directly with game icon; selected icon is brighter/lighter
			if is_sel:
				btn.self_modulate = Color(1.22, 1.22, 1.22, 1.0)
			else:
				btn.self_modulate = Color(0.55, 0.52, 0.48, 0.72)

			ActionVFXManager.apply_button_juice(btn, "tap_button")
			btn.pressed.connect(func():
				AudioManager.sfx_tap()
				current_game_type = gid_f
				_render_filters()
				refresh()
			)
			_game_filter_hbox.add_child(btn)


func _show_loading_state() -> void:
	if not is_instance_valid(_list_vbox):
		return
	for c in _list_vbox.get_children():
		c.queue_free()
	_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت مسابقات زنده..."))


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

	if items.is_empty():
		_list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var empty_lbl := CafeSocialTheme.make_body(
			"در حال حاضر مسابقه زنده‌ای با این فیلتر در جریان نیست.",
			23,
			CafeSocialTheme.COL_MUTED_SAND,
			HORIZONTAL_ALIGNMENT_CENTER,
			true
		)
		_list_vbox.add_child(empty_lbl)
		return

	_list_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			_list_vbox.add_child(_build_match_card(item))
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 32)
	_list_vbox.add_child(bottom_pad)


func _build_match_card(m: Dictionary) -> PanelContainer:
	var gid: String = str(m.get("game_id", ""))
	var gtype: String = str(m.get("game_type", "Ludo"))
	var gtitle: String = GameRegistry.get_display_name_fa(gtype)
	var mode_fa: String = _get_mode_label_fa(str(m.get("game_score_type", "")))
	var spec_cnt: int = int(m.get("spectator_count", 0))
	var has_friend: bool = bool(m.get("has_friend", false))
	var has_clanmate: bool = bool(m.get("has_clanmate", false))
	var players: Array = m.get("players", []) if typeof(m.get("players")) == TYPE_ARRAY else []

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.add_theme_stylebox_override(
		"panel",
		CafeSocialTheme.create_frame_style(true, 18.0, 14.0)
	)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Row 1: Top-left Eye+Count pill (+ optional mode/relation badge), Title + Thumbnail right
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var badges_col := HBoxContainer.new()
	badges_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	badges_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badges_col.add_theme_constant_override("separation", 6)
	top_row.add_child(badges_col)

	# Watcher count pill: Eye icon on left, count on right (LTR), NO "تماشاگر" text
	var eye_pill := PanelContainer.new()
	var eye_st := StyleBoxFlat.new()
	eye_st.bg_color = CafeSocialTheme.COL_EMERALD_BG
	eye_st.border_color = CafeSocialTheme.COL_EMERALD_BORDER
	eye_st.set_border_width_all(1)
	eye_st.set_corner_radius_all(10)
	eye_st.content_margin_left = 10.0
	eye_st.content_margin_right = 10.0
	eye_st.content_margin_top = 4.0
	eye_st.content_margin_bottom = 4.0
	eye_pill.add_theme_stylebox_override("panel", eye_st)
	var eye_hbox := HBoxContainer.new()
	eye_hbox.layout_direction = Control.LAYOUT_DIRECTION_LTR
	eye_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	eye_hbox.add_theme_constant_override("separation", 5)
	eye_pill.add_child(eye_hbox)
	eye_hbox.add_child(CafeSocialTheme.make_body("👁", CafeSocialTheme.FONT_SIZE_BADGE, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	eye_hbox.add_child(CafeSocialTheme.make_body(GameManager.to_fa_num(spec_cnt), CafeSocialTheme.FONT_SIZE_BADGE, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	badges_col.add_child(eye_pill)

	if not mode_fa.is_empty():
		badges_col.add_child(CafeSocialTheme.make_badge_pill(
			mode_fa,
			CafeSocialTheme.COL_WARM_CREAM,
			Color(0.14, 0.10, 0.06, 0.94),
			CafeSocialTheme.COL_BRONZE_BORDER,
			CafeSocialTheme.FONT_SIZE_BADGE
		))
	if has_friend:
		badges_col.add_child(CafeSocialTheme.make_badge_pill(
			"دوست",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.18, 0.12, 0.05, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			CafeSocialTheme.FONT_SIZE_BADGE
		))
	elif has_clanmate:
		badges_col.add_child(CafeSocialTheme.make_badge_pill(
			"کلن",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.18, 0.12, 0.05, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			CafeSocialTheme.FONT_SIZE_BADGE
		))

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 2)
	top_row.add_child(title_col)

	var t_lbl := CafeSocialTheme.make_title(
		"مسابقه %s" % gtitle,
		CafeSocialTheme.FONT_SIZE_BODY,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(t_lbl)

	var sub_lbl := CafeSocialTheme.make_body(
		"%s بازیکن • در حال رقابت" % GameManager.to_fa_num(maxi(2, players.size())),
		CafeSocialTheme.FONT_SIZE_BADGE,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_col.add_child(sub_lbl)

	var thumb_wrap := PanelContainer.new()
	thumb_wrap.custom_minimum_size = Vector2(60, 60)
	thumb_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_wrap.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.08, 0.05, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 14, 2, 4.0, 4.0))
	top_row.add_child(thumb_wrap)

	var thumb := TextureRect.new()
	thumb.texture = CafeSocialTheme.get_game_thumb(gtype)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_wrap.add_child(thumb)

	# Row 2: Players Matchup Strip (2-col Grid for >2 players so cards NEVER overflow horizontally)
	if not players.is_empty():
		var players_well := PanelContainer.new()
		players_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		players_well.clip_contents = true
		players_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(12, 10.0, 8.0))
		vbox.add_child(players_well)

		var make_player_chip := func(pd: Dictionary) -> HBoxContainer:
			var p_chip := HBoxContainer.new()
			p_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_chip.alignment = BoxContainer.ALIGNMENT_CENTER
			p_chip.add_theme_constant_override("separation", 6)
			var av_id: int = int(pd.get("avatar", pd.get("image", 0)))
			var fr_id: int = int(pd.get("profile_frame", 0))
			p_chip.add_child(CafeSocialTheme.make_avatar_badge(av_id, maxi(1, fr_id), 48.0, "", false))
			var pname: String = str(pd.get("username", "بازیکن"))
			var c_info: Variant = pd.get("clan", null)
			if typeof(c_info) == TYPE_DICTIONARY and not str((c_info as Dictionary).get("tag", "")).is_empty():
				pname += " [%s]" % str((c_info as Dictionary).get("tag", ""))
			var p_lbl := CafeSocialTheme.make_body(pname, CafeSocialTheme.FONT_SIZE_BADGE, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
			p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_lbl.clip_text = true
			p_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			p_chip.add_child(p_lbl)
			return p_chip

		if players.size() > 2:
			var players_grid := GridContainer.new()
			players_grid.columns = 2
			players_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			players_grid.add_theme_constant_override("h_separation", 10)
			players_grid.add_theme_constant_override("v_separation", 8)
			players_well.add_child(players_grid)
			for p_item in players:
				if typeof(p_item) == TYPE_DICTIONARY:
					players_grid.add_child(make_player_chip.call(p_item as Dictionary))
		else:
			var players_row := HBoxContainer.new()
			players_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			players_row.alignment = BoxContainer.ALIGNMENT_CENTER
			players_row.add_theme_constant_override("separation", 8)
			players_well.add_child(players_row)
			for i in range(players.size()):
				var p_item: Variant = players[i]
				if typeof(p_item) != TYPE_DICTIONARY:
					continue
				if i > 0:
					var vs_lbl := CafeSocialTheme.make_title("⚔", CafeSocialTheme.FONT_SIZE_BADGE, CafeSocialTheme.COL_GOLD_ANTIQUE, HORIZONTAL_ALIGNMENT_CENTER, false)
					vs_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					players_row.add_child(vs_lbl)
				players_row.add_child(make_player_chip.call(p_item as Dictionary))

	# Row 3: Full-width Watch Action Button
	var btn_watch := CafeSocialTheme.make_button("تماشای زنده مسابقه", "gold", Vector2(0, 56), CafeSocialTheme.FONT_SIZE_TAB_LABEL)
	btn_watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_watch.pressed.connect(func():
		AudioManager.sfx_button()
		close_immediate()
		NetworkManager.request_spectate_game(gid)
	)
	vbox.add_child(btn_watch)

	return card
