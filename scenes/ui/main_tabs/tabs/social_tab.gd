extends Control

## Cafe Fekr — Clan Tab (اتحاد)
## Dedicated Clan hub inside the persistent five-tab application shell.
## Friends and Direct Messages live in the dedicated FriendsPage accessed from PlayTab.

signal spectate_match_requested(game_id: String, game_type: String)
signal open_dm_requested(user_id: String, username: String)
signal clan_badge_changed(count: int)

var content_area: MarginContainer
var _toast_panel: PanelContainer
var lbl_status_toast: Label

var current_main_tab: String = "clans"
var current_clans_subtab: String = "my_clan"    # "my_clan" | "members" | "chat" | "discover" | "leaderboard"
var current_clan_lb_mode: String = "clans"      # "clans" | "clans_weekly" | "clans_monthly"

# Cached Clan State
var _friends_list: Array = []
var _my_clan_data: Dictionary = {}
var _clan_chat_messages: Array = []
var _clan_chat_has_more: bool = true
var _clan_chat_is_loading_older: bool = false
var _clan_unread_chat_count: int = 0

# Dynamic references for active clan chat & members
var _clan_chat_list_vbox: VBoxContainer = null
var _clan_chat_scroll: ScrollContainer = null
var _clan_chat_input: LineEdit = null
var _clan_online_pill_lbl: Label = null
var _clan_members_online_val_lbl: Label = null
var _clan_member_widgets: Dictionary = {}


func _ready() -> void:
	_build_ui_shell()
	_connect_realtime_signals()
	if NetworkManager.is_online and not NetworkManager.is_social_connected and GameManager.is_logged_in and not GameManager.token.is_empty():
		NetworkManager.connect_social_namespace()
	_preload_clan_data()
	_refresh_current_tab()


func _connect_realtime_signals() -> void:
	NetworkManager.social_init_received.connect(func(_p: Dictionary):
		_update_main_tab_buttons()
	)
	NetworkManager.social_badges_changed.connect(_update_main_tab_buttons)
	NetworkManager.social_presence_changed.connect(_on_realtime_presence_changed)
	NetworkManager.social_clan_chat_received.connect(_on_realtime_clan_chat_received)
	NetworkManager.social_clan_chat_deleted.connect(_on_realtime_clan_chat_deleted)
	NetworkManager.social_clan_event_received.connect(_on_realtime_clan_event)
	NetworkManager.social_error_received.connect(func(msg: String):
		_show_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
	)


func _build_ui_shell() -> void:
	for c: Node in get_children():
		c.queue_free()

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 8)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(outer_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(root_vbox)

	# 1. Top Subheader with Refresh (Left) and اتحاد Title (Right)
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_row)

	var btn_refresh: TextureButton = TextureButton.new()
	btn_refresh.name = "BtnRefreshTop"
	btn_refresh.texture_normal = CafeSocialTheme.ICO_REFRESH
	btn_refresh.custom_minimum_size = Vector2(62, 62)
	btn_refresh.ignore_texture_size = true
	btn_refresh.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_refresh.focus_mode = Control.FOCUS_NONE
	btn_refresh.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_refresh.tooltip_text = "بروزرسانی"
	ActionVFXManager.apply_button_juice(btn_refresh, "tap_button")
	btn_refresh.pressed.connect(func():
		AudioManager.sfx_tap()
		if NetworkManager.is_online and not NetworkManager.is_social_connected and not GameManager.token.is_empty():
			NetworkManager.connect_social_namespace()
		SocialClansView.invalidate_caches()
		if current_clans_subtab in ["my_clan", "members"]:
			refresh_my_clan_data(true)
		else:
			_preload_clan_data()
			_refresh_current_tab()
	)
	top_row.add_child(btn_refresh)

	var title_lbl: Label = Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_lbl.add_theme_constant_override("shadow_outline_size", 2)
	title_lbl.text = "اتحاد"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(title_lbl)

	# 2. Toast Panel
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	lbl_status_toast = CafeSocialTheme.make_body("", 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(lbl_status_toast)

	# 3. Direct Clan Content Area (top hub switcher removed — Clan-only)
	content_area = MarginContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_area)

	_update_main_tab_buttons()


func _preload_clan_data() -> void:
	if not GameManager.is_logged_in:
		return
	NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(self):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			_my_clan_data = data["result"]
			_update_main_tab_buttons()
	)


func _show_toast(txt: String, col: Color = CafeSocialTheme.COL_EMERALD_TEXT) -> void:
	if not is_instance_valid(lbl_status_toast) or not is_instance_valid(_toast_panel):
		return
	lbl_status_toast.text = txt
	lbl_status_toast.add_theme_color_override("font_color", col)
	_toast_panel.visible = true
	get_tree().create_timer(3.6).timeout.connect(func():
		if is_instance_valid(_toast_panel) and is_instance_valid(lbl_status_toast) and lbl_status_toast.text == txt:
			_toast_panel.visible = false
	)


func _update_main_tab_buttons() -> void:
	var badge_cnt: int = SocialClansView.get_clans_badge_count(self)
	clan_badge_changed.emit(badge_cnt)


func _refresh_current_tab() -> void:
	var body_vbox: VBoxContainer = _clear_content()
	SocialClansView.render(self, body_vbox)


func _clear_content() -> VBoxContainer:
	_clan_chat_list_vbox = null
	_clan_chat_scroll = null
	_clan_chat_input = null
	_clan_chat_is_loading_older = false
	_clan_online_pill_lbl = null
	_clan_members_online_val_lbl = null
	_clan_member_widgets.clear()
	for c: Node in content_area.get_children():
		c.queue_free()
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	content_area.add_child(vbox)
	return vbox


func _open_player_profile(u_dict: Dictionary) -> void:
	UserProfileDialog.show_user(u_dict, "", self)


func open_direct_message_with(user_id: String, username: String) -> void:
	open_dm_requested.emit(user_id, username)


func _send_clan_chat_message() -> void:
	if not is_instance_valid(_clan_chat_input):
		return
	var txt: String = _clan_chat_input.text.strip_edges()
	if txt.is_empty():
		return
	_clan_chat_input.text = ""
	if NetworkManager.is_social_connected:
		NetworkManager.send_clan_chat_realtime(txt)
	else:
		if NetworkManager.is_online and not GameManager.token.is_empty():
			NetworkManager.connect_social_namespace()
		NetworkManager.api.send_clan_chat_rest(txt, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var msg_res: Dictionary = data["result"]
				var mid: String = str(msg_res.get("message_id", msg_res.get("_id", "")))
				var exists: bool = false
				for m: Variant in _clan_chat_messages:
					if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid and not mid.is_empty():
						exists = true
						break
				if not exists:
					_clan_chat_messages.append(msg_res)
					SocialClansView.append_clan_chat_message(self, msg_res)
			elif typeof(data) == TYPE_DICTIONARY:
				_show_toast(str(data.get("detail", "خطا در ارسال پیام اتحاد")), CafeSocialTheme.COL_CRIMSON_TEXT)
		)


func refresh_my_clan_data(force_render: bool = true) -> void:
	if not GameManager.is_logged_in:
		return
	var prev_has_clan: bool = typeof(_my_clan_data.get("clan")) == TYPE_DICTIONARY and not _my_clan_data["clan"].is_empty()
	NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(self):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			_my_clan_data = data["result"]
			var c_obj: Variant = _my_clan_data.get("clan", null)
			var now_has_clan: bool = typeof(c_obj) == TYPE_DICTIONARY and not c_obj.is_empty()
			if now_has_clan:
				GameManager.user_data["clan"] = c_obj
				GameManager.user_data["clan_id"] = str(c_obj.get("clan_id", c_obj.get("_id", "")))
			else:
				GameManager.user_data.erase("clan")
				GameManager.user_data.erase("clan_id")
				_clan_chat_messages.clear()
			_update_main_tab_buttons()
			if force_render:
				if not now_has_clan and current_clans_subtab in ["chat", "members"]:
					current_clans_subtab = "my_clan"
					_refresh_current_tab()
				elif (now_has_clan != prev_has_clan) or current_clans_subtab != "chat":
					_refresh_current_tab()
	)


func _on_realtime_presence_changed(payload: Dictionary) -> void:
	var pid: String = str(payload.get("user_id", ""))
	if pid.is_empty():
		return
	var new_st: String = str(payload.get("status", "offline"))
	var pres_dict: Dictionary = {
		"status": new_st,
		"current_game_type": str(payload.get("current_game_type", "")),
		"current_game_id": str(payload.get("current_game_id", "")),
		"current_lobby_id": str(payload.get("current_lobby_id", "")),
		"last_seen": str(payload.get("last_seen", "")),
	}

	var c_dict: Variant = _my_clan_data.get("clan", null)
	if typeof(c_dict) == TYPE_DICTIONARY and typeof(c_dict.get("members")) == TYPE_ARRAY:
		for m: Variant in c_dict["members"]:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("user_id", m.get("_id", ""))) == pid:
				m["status"] = new_st
				m["presence"] = pres_dict

	SocialClansView.update_member_presence(self, pid, new_st)


func _on_realtime_clan_chat_received(msg: Dictionary) -> void:
	var sender_id: String = str(msg.get("sender_id", ""))
	var is_mine: bool = (sender_id == str(GameManager.get_user_id()))
	var mid: String = str(msg.get("message_id", msg.get("_id", "")))
	var exists: bool = false
	if not mid.is_empty():
		for m: Variant in _clan_chat_messages:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid:
				exists = true
				break
	if not exists:
		_clan_chat_messages.append(msg)
	if current_clans_subtab == "chat":
		if not exists:
			SocialClansView.append_clan_chat_message(self, msg)
	elif not is_mine and not exists:
		_clan_unread_chat_count += 1
		_update_main_tab_buttons()
		SocialClansView.refresh_nav_badges(self)


func _on_realtime_clan_chat_deleted(payload: Dictionary) -> void:
	var message_id: String = str(payload.get("message_id", payload.get("_id", "")))
	if message_id.is_empty():
		return
	for i: int in range(_clan_chat_messages.size() - 1, -1, -1):
		var m: Variant = _clan_chat_messages[i]
		if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", m.get("id", "")))) == message_id:
			_clan_chat_messages.remove_at(i)
	if current_clans_subtab == "chat":
		SocialClansView.render_clan_chat(self)


func _on_realtime_clan_event(event: Dictionary) -> void:
	var msg_txt: String = str(event.get("message", ""))
	if not msg_txt.is_empty():
		_show_toast(msg_txt, CafeSocialTheme.COL_GOLD_BRIGHT)
	var ev_type: String = str(event.get("event_type", ""))
	var ev_uid: String = str(event.get("user_id", ""))
	var my_uid: String = str(GameManager.get_user_id())
	if ev_type == "clan_disbanded" or (ev_type in ["member_left", "member_kicked"] and ev_uid == my_uid):
		_my_clan_data = {}
		_clan_chat_messages.clear()
		GameManager.user_data.erase("clan")
		GameManager.user_data.erase("clan_id")
		_update_main_tab_buttons()
		current_clans_subtab = "my_clan"
		_refresh_current_tab()
		return
	refresh_my_clan_data(true)


func _scroll_clan_chat_to_bottom() -> void:
	if not is_instance_valid(_clan_chat_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_clan_chat_scroll):
		var bar: VScrollBar = _clan_chat_scroll.get_v_scroll_bar()
		if bar:
			_clan_chat_scroll.scroll_vertical = int(bar.max_value)
