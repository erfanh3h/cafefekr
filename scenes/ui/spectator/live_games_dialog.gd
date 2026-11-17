class_name LiveGamesDialog
extends Control

## Cafe Fekr — Centered Live Spectator Browser Dialog
## Fetches ongoing active matches from both Socket.IO backend RAM and REST API,
## and renders a centered antique Cafe Fekr card browser with clean hierarchy.

signal closed()

var _dim_overlay: ColorRect = null
var main_panel: PanelContainer = null
var _scope_row: HBoxContainer = null
var _game_filter_hbox: HBoxContainer = null
var _list_vbox: VBoxContainer = null
var _lbl_count: Label = null
var _status_plaque: PanelContainer = null
var _scroll_games: ScrollContainer = null

var current_scope: String = "all"         # "all" | "friends" | "clan"
var current_game_type: String = ""        # "" or canonical GameTypes string

var _merged_games: Dictionary = {}        # game_id -> Dictionary
var _is_loading: bool = false
var _request_token: int = 0


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
	_show_loading_state()

	# Source 1: Direct Socket.IO /social query (live RAM games in kafehfekrbackend)
	if NetworkManager.is_online:
		NetworkManager.request_live_games_realtime(current_scope, current_game_type)

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
			_render_games_list()
	)

	get_tree().create_timer(2.0).timeout.connect(func():
		if req_token == _request_token and _is_loading and is_instance_valid(_list_vbox):
			_is_loading = false
			_render_games_list()
	)


func _on_realtime_live_games_received(payload: Dictionary) -> void:
	if not visible:
		return
	var req_scope: String = str(payload.get("scope", "all"))
	var req_gtype: String = str(payload.get("game_type", ""))
	if req_scope != current_scope or req_gtype != current_game_type:
		return
	_is_loading = false
	var arr: Array = payload.get("items", []) if typeof(payload.get("items")) == TYPE_ARRAY else []
	_ingest_games_array(arr)
	_render_games_list()


func _ingest_games_array(arr: Array) -> void:
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
			if not _merged_games.has(gid):
				_merged_games[gid] = d
			else:
				var existing: Dictionary = _merged_games[gid]
				if int(d.get("spectator_count", 0)) > int(existing.get("spectator_count", 0)):
					existing["spectator_count"] = int(d.get("spectator_count", 0))
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

	# Centered Modal Host matching RankingDialog / LobbyDialog / StoreDialog
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(660, 1160)
	main_panel.size = Vector2(660, 1160)
	main_panel.pivot_offset = Vector2(330, 580)
	main_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(main_panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 20)
	inner.add_theme_constant_override("margin_right", 20)
	inner.add_theme_constant_override("margin_top", 24)
	inner.add_theme_constant_override("margin_bottom", 24)
	main_panel.add_child(inner)

	var root := VBoxContainer.new()
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
		30,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	))
	title_box.add_child(CafeSocialTheme.make_body(
		"مسابقات در حال برگزاری کافه فکر را به صورت زنده تماشا کنید",
		18,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
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

	# 3. Clean 1-Row Scrollable Game Filter Row inside Antique Well (taller height & tight padding)
	var filter_well := PanelContainer.new()
	filter_well.custom_minimum_size = Vector2(0, 100)
	filter_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 4.0, 4.0))
	root.add_child(filter_well)

	var filter_scroll := ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 92)
	filter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_well.add_child(filter_scroll)

	_game_filter_hbox = HBoxContainer.new()
	_game_filter_hbox.add_theme_constant_override("separation", 6)
	_game_filter_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_scroll.add_child(_game_filter_hbox)

	# 4. Active Count Strip
	_status_plaque = PanelContainer.new()
	_status_plaque.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(12, 14.0, 8.0))
	root.add_child(_status_plaque)

	_lbl_count = CafeSocialTheme.make_body(
		"در حال دریافت فهرست بازی‌های فعال...",
		22,
		CafeSocialTheme.COL_WARM_CREAM,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	_status_plaque.add_child(_lbl_count)

	# 5. Scrollable Matches Container
	_scroll_games = ScrollContainer.new()
	_scroll_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_games.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_games.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
			b.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
			b.add_theme_font_size_override("font_size", 24)
			if current_scope == sid:
				KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
				b.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
			else:
				KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
				b.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))
			ActionVFXManager.apply_button_juice(b, "tap_button")
			b.pressed.connect(func():
				AudioManager.sfx_tap()
				current_scope = sid
				_render_filters()
				refresh()
			)
			_scope_row.add_child(b)

	if is_instance_valid(_game_filter_hbox):
		for c in _game_filter_hbox.get_children():
			c.queue_free()

		# All 25 games + "all"
		var gfilters: Array = [{"id": "", "label": "همه"}]
		for g in GamesHistoryViewHelper.GAMES_LIST:
			gfilters.append({"id": g["id"], "label": g["name_fa"]})

		for gf in gfilters:
			var gf_d: Dictionary = gf
			var gid_f: String = str(gf_d["id"])
			var is_sel: bool = (current_game_type == gid_f)

			var btn := TextureButton.new()
			btn.custom_minimum_size = Vector2(80, 80)
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = str(gf_d["label"])
			ActionVFXManager.apply_button_juice(btn, "tap_button")

			var frame_panel := PanelContainer.new()
			frame_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
			frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if is_sel:
				frame_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
					Color(0.24, 0.16, 0.08, 0.98),
					Color(1.0, 0.85, 0.35, 1.0),
					12,
					3
				))
			else:
				frame_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
					Color(0.10, 0.06, 0.03, 0.90),
					Color(0.55, 0.40, 0.20, 0.70),
					12,
					1
				))
			btn.add_child(frame_panel)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.offset_left = 2
			icon_rect.offset_top = 2
			icon_rect.offset_right = -2
			icon_rect.offset_bottom = -2

			if gid_f.is_empty():
				icon_rect.texture = preload("res://assets/images/frames/question.png")
			else:
				icon_rect.texture = CafeSocialTheme.get_game_thumb(gid_f)

			if not is_sel:
				icon_rect.modulate = Color(0.80, 0.75, 0.70, 0.85)
			else:
				icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
			frame_panel.add_child(icon_rect)

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
	if is_instance_valid(_lbl_count):
		_lbl_count.text = "در حال دریافت مسابقات زنده..."


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

	if is_instance_valid(_lbl_count) and is_instance_valid(_status_plaque):
		if items.is_empty():
			_status_plaque.visible = false
			_lbl_count.text = ""
		else:
			_status_plaque.visible = true
			_lbl_count.text = "●  %s مسابقه زنده آماده تماشا" % GameManager.to_fa_num(items.size())

	if items.is_empty():
		# Empty list without any extra text information
		return

	_list_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			_list_vbox.add_child(_build_match_card(item))


func _build_match_card(m: Dictionary) -> PanelContainer:
	var gid: String = str(m.get("game_id", ""))
	var gtype: String = str(m.get("game_type", "Ludo"))
	var gtitle: String = GameRegistry.get_display_name_fa(gtype)
	var spec_cnt: int = int(m.get("spectator_count", 0))
	var has_friend: bool = bool(m.get("has_friend", false))
	var has_clanmate: bool = bool(m.get("has_clanmate", false))
	var players: Array = m.get("players", []) if typeof(m.get("players")) == TYPE_ARRAY else []

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		CafeSocialTheme.create_frame_style(true, 18.0, 14.0)
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Row 1: Badges left, Title + Thumbnail right
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	var badges_col := HBoxContainer.new()
	badges_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	badges_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badges_col.add_theme_constant_override("separation", 6)
	top_row.add_child(badges_col)

	badges_col.add_child(CafeSocialTheme.make_badge_pill(
		"👁 %s تماشاگر" % GameManager.to_fa_num(spec_cnt),
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		18
	))
	if has_friend:
		badges_col.add_child(CafeSocialTheme.make_badge_pill(
			"دوست شما",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.18, 0.12, 0.05, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			17
		))
	elif has_clanmate:
		badges_col.add_child(CafeSocialTheme.make_badge_pill(
			"هم‌کلنی",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.18, 0.12, 0.05, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			17
		))

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 2)
	top_row.add_child(title_col)

	title_col.add_child(CafeSocialTheme.make_title(
		"مسابقه %s" % gtitle,
		26,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	))
	title_col.add_child(CafeSocialTheme.make_body(
		"%s بازیکن • در حال رقابت" % GameManager.to_fa_num(maxi(2, players.size())),
		18,
		CafeSocialTheme.COL_MUTED_SAND,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	))

	var thumb_wrap := PanelContainer.new()
	thumb_wrap.custom_minimum_size = Vector2(64, 64)
	thumb_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_wrap.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.08, 0.05, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 14, 2, 4.0, 4.0))
	top_row.add_child(thumb_wrap)

	var thumb := TextureRect.new()
	thumb.texture = CafeSocialTheme.get_game_thumb(gtype)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_wrap.add_child(thumb)

	# Row 2: Players Matchup Strip
	if not players.is_empty():
		var players_well := PanelContainer.new()
		players_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(12, 12.0, 8.0))
		vbox.add_child(players_well)

		var players_row := HBoxContainer.new()
		players_row.alignment = BoxContainer.ALIGNMENT_CENTER
		players_row.add_theme_constant_override("separation", 10)
		players_well.add_child(players_row)

		for i in range(players.size()):
			var p_item: Variant = players[i]
			if typeof(p_item) != TYPE_DICTIONARY:
				continue
			var pd: Dictionary = p_item
			if i > 0:
				var vs_lbl := CafeSocialTheme.make_title("⚔", 24, CafeSocialTheme.COL_GOLD_ANTIQUE, HORIZONTAL_ALIGNMENT_CENTER, false)
				vs_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				players_row.add_child(vs_lbl)

			var p_chip := HBoxContainer.new()
			p_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_chip.alignment = BoxContainer.ALIGNMENT_CENTER
			p_chip.add_theme_constant_override("separation", 8)
			players_row.add_child(p_chip)

			var av_id: int = int(pd.get("avatar", pd.get("image", 0)))
			var fr_id: int = int(pd.get("profile_frame", 0))
			p_chip.add_child(CafeSocialTheme.make_avatar_badge(av_id, maxi(1, fr_id), 54.0, "", false))

			var pname: String = str(pd.get("username", "بازیکن"))
			var c_info: Variant = pd.get("clan", null)
			if typeof(c_info) == TYPE_DICTIONARY and not str((c_info as Dictionary).get("tag", "")).is_empty():
				pname += " [%s]" % str((c_info as Dictionary).get("tag", ""))
			var p_lbl := CafeSocialTheme.make_body(pname, 21, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false)
			p_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			p_chip.add_child(p_lbl)

	# Row 3: Full-width Watch Action Button
	var btn_watch := CafeSocialTheme.make_button("تماشای زنده مسابقه", "gold", Vector2(0, 54), 25)
	btn_watch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_watch.pressed.connect(func():
		AudioManager.sfx_button()
		close_immediate()
		NetworkManager.request_spectate_game(gid)
	)
	vbox.add_child(btn_watch)

	return card
