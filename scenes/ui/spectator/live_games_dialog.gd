class_name LiveGamesDialog
extends Control

## Cafe Fekr — Live Spectator Browser Dialog
## Displays ongoing online matches (from both Socket.IO backend RAM and REST API)
## so players can discover active games and join to spectate in 1 tap.

signal closed()

var _dim_overlay: ColorRect = null
var main_panel: PanelContainer = null
var _scope_row: HBoxContainer = null
var _game_row: HBoxContainer = null
var _list_vbox: VBoxContainer = null
var _lbl_count: Label = null

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
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
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

	# Source 1: Direct Socket.IO /social namespace query (reads live RAM games directly from game backend)
	if NetworkManager.is_online:
		NetworkManager.request_live_games_realtime(current_scope, current_game_type)

	# Source 2: REST API query (/spectator/live-games)
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

	# Safety fallback if neither completes quickly
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
			if not _merged_games.has(gid):
				_merged_games[gid] = d
			else:
				var existing: Dictionary = _merged_games[gid]
				if int(d.get("spectator_count", 0)) > int(existing.get("spectator_count", 0)):
					existing["spectator_count"] = int(d.get("spectator_count", 0))
				if (existing.get("players", []) as Array).is_empty() and not (d.get("players", []) as Array).is_empty():
					existing["players"] = d["players"]
				_merged_games[gid] = existing


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_dim_overlay = ColorRect.new()
	_dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.color = Color(0.03, 0.015, 0.01, 0.80)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			close()
	)
	add_child(_dim_overlay)

	var margin_outer := MarginContainer.new()
	margin_outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_outer.add_theme_constant_override("margin_left", 24)
	margin_outer.add_theme_constant_override("margin_right", 24)
	margin_outer.add_theme_constant_override("margin_top", 56)
	margin_outer.add_theme_constant_override("margin_bottom", 56)
	add_child(margin_outer)

	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	margin_outer.add_child(main_panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 32)
	inner.add_theme_constant_override("margin_right", 32)
	inner.add_theme_constant_override("margin_top", 30)
	inner.add_theme_constant_override("margin_bottom", 30)
	main_panel.add_child(inner)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	inner.add_child(root)

	# Header Row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var btn_close := TextureButton.new()
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(56, 56)
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

	var title_lbl := CafeSocialTheme.make_title(
		"تماشای زنده بازی‌ها",
		38,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		false
	)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var btn_ref := CafeSocialTheme.make_button("", "bronze", Vector2(56, 56), 22, CafeSocialTheme.ICO_REFRESH, false, 14)
	btn_ref.tooltip_text = "بروزرسانی فهرست بازی‌ها"
	btn_ref.pressed.connect(func():
		AudioManager.sfx_tap()
		refresh()
	)
	header.add_child(btn_ref)

	# Filters Plaque
	var filter_card := PanelContainer.new()
	filter_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 14.0, 12.0))
	root.add_child(filter_card)

	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 10)
	filter_card.add_child(fv)

	_scope_row = HBoxContainer.new()
	_scope_row.add_theme_constant_override("separation", 8)
	fv.add_child(_scope_row)

	_game_row = HBoxContainer.new()
	_game_row.add_theme_constant_override("separation", 6)
	fv.add_child(_game_row)

	# Subheader Count Banner
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 10)
	root.add_child(count_row)

	_lbl_count = CafeSocialTheme.make_body(
		"در حال دریافت فهرست بازی‌های فعال...",
		23,
		CafeSocialTheme.COL_WARM_CREAM,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	_lbl_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(_lbl_count)

	# Scroll List
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_list_vbox)

	_render_filters()


func _render_filters() -> void:
	if is_instance_valid(_scope_row):
		for c in _scope_row.get_children():
			c.queue_free()
		var scopes: Array = [
			{"id": "all", "label": "همه بازی‌ها"},
			{"id": "friends", "label": "دوستان در حال بازی"},
			{"id": "clan", "label": "اعضای کلن من"},
		]
		for sc in scopes:
			var sc_d: Dictionary = sc
			var sid: String = str(sc_d["id"])
			var b := CafeSocialTheme.make_button(str(sc_d["label"]), "gold" if current_scope == sid else "muted", Vector2(0, 50), 22)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				AudioManager.sfx_tap()
				current_scope = sid
				_render_filters()
				refresh()
			)
			_scope_row.add_child(b)

	if is_instance_valid(_game_row):
		for c in _game_row.get_children():
			c.queue_free()
		var gfilters: Array = [
			{"id": "", "label": "همه"},
			{"id": "Ludo", "label": "منچ"},
			{"id": "Monopoly", "label": "مونوپولی"},
			{"id": "Chess", "label": "شطرنج"},
			{"id": "Backgammon", "label": "تخته‌نرد"},
			{"id": "Risk", "label": "ریسک"},
			{"id": "Uno", "label": "اونو"},
		]
		for gf in gfilters:
			var gf_d: Dictionary = gf
			var gid_f: String = str(gf_d["id"])
			var b := CafeSocialTheme.make_button(str(gf_d["label"]), "emerald" if current_game_type == gid_f else "bronze", Vector2(0, 44), 20)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				AudioManager.sfx_tap()
				current_game_type = gid_f
				_render_filters()
				refresh()
			)
			_game_row.add_child(b)


func _show_loading_state() -> void:
	if not is_instance_valid(_list_vbox):
		return
	for c in _list_vbox.get_children():
		c.queue_free()
	if is_instance_valid(_lbl_count):
		_lbl_count.text = "در حال جستجوی بازی‌های فعال..."
	_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت فهرست بازی‌های در حال اجرا..."))


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

	if is_instance_valid(_lbl_count):
		if items.is_empty():
			_lbl_count.text = "هیچ مسابقه فعالی با این فیلتر پیدا نشد"
		else:
			_lbl_count.text = "%s مسابقه زنده در حال برگزاری است" % GameManager.to_fa_num(items.size())

	if items.is_empty():
		_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_LOBBY,
			"در حال حاضر مسابقه‌ای در حال اجرا نیست",
			"به محض شروع یک رقابت آنلاین بین بازیکنان، نام آن در این فهرست ظاهر می‌شود و می‌توانید وارد تماشای زنده شوید.",
			"بروزرسانی فهرست",
			"gold",
			func(): refresh()
		))
		return

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
	card.add_theme_stylebox_override(
		"panel",
		CafeSocialTheme.create_highlight_card_style(true) if (has_friend or has_clanmate) else CafeSocialTheme.create_card_style()
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var btn_watch := CafeSocialTheme.make_button("تماشای زنده", "gold", Vector2(170, 58), 24)
	btn_watch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_watch.pressed.connect(func():
		AudioManager.sfx_button()
		close_immediate()
		NetworkManager.request_spectate_game(gid)
	)
	row.add_child(btn_watch)

	var meta_col := VBoxContainer.new()
	meta_col.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_col.add_theme_constant_override("separation", 6)
	row.add_child(meta_col)

	meta_col.add_child(CafeSocialTheme.make_badge_pill(
		"👁 %s تماشاگر" % GameManager.to_fa_num(spec_cnt),
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		20
	))
	if has_friend:
		meta_col.add_child(CafeSocialTheme.make_badge_pill(
			"دوست شما",
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.18, 0.12, 0.05, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			19
		))

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 4)
	row.add_child(title_col)

	title_col.add_child(CafeSocialTheme.make_title(
		"مسابقه %s" % gtitle,
		30,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	))

	var names_arr: Array[String] = []
	for p in players:
		if typeof(p) == TYPE_DICTIONARY:
			var pd: Dictionary = p
			var pname: String = str(pd.get("username", "بازیکن"))
			var c_info: Variant = pd.get("clan", null)
			if typeof(c_info) == TYPE_DICTIONARY and not str((c_info as Dictionary).get("tag", "")).is_empty():
				pname += " [%s]" % str((c_info as Dictionary).get("tag", ""))
			names_arr.append(pname)
	title_col.add_child(CafeSocialTheme.make_body(
		" در برابر ".join(names_arr) if not names_arr.is_empty() else "مسابقه فعال آنلاین",
		23,
		CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))

	var thumb := TextureRect.new()
	thumb.texture = CafeSocialTheme.get_game_thumb(gtype)
	thumb.custom_minimum_size = Vector2(72, 72)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(thumb)

	return card
