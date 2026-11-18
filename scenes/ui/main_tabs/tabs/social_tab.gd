extends Control

## Cafe Fekr — Social Tab (Antique Board-Game Club)
## Embedded social hub: Friends, Clans, Direct Messages, and Notifications.
## Integrates seamlessly into the persistent five-tab application shell.

signal spectate_match_requested(game_id: String, game_type: String)

var content_area: MarginContainer
var _toast_panel: PanelContainer
var lbl_status_toast: Label
var _nav_hbox: HBoxContainer

var current_main_tab: String = "friends"        # "friends" | "clans" | "messages" | "notifs"
var current_friends_subtab: String = "list"     # "list" | "requests" | "search" | "live"
var current_live_scope: String = "all"          # "all" | "friends" | "clan"
var current_live_game_type: String = ""         # "" or canonical game type
var current_clans_subtab: String = "my_clan"    # "my_clan" | "members" | "chat" | "discover" | "leaderboard"
var current_clan_lb_mode: String = "clans"      # "clans" | "clans_weekly" | "clans_monthly"

# Cached State
var _friends_list: Array = []
var _incoming_requests: Array = []
var _outgoing_requests: Array = []
var _my_clan_data: Dictionary = {}
var _clan_chat_messages: Array = []
var _clan_chat_has_more: bool = true
var _clan_chat_is_loading_older: bool = false
var _conversations: Array = []
var _active_dm_partner_id: String = ""
var _active_dm_partner_name: String = ""
var _active_dm_partner_info: Dictionary = {}
var _active_dm_messages: Array = []

# Dynamic references for active chat streams
var _clan_chat_list_vbox: VBoxContainer = null
var _clan_chat_scroll: ScrollContainer = null
var _clan_chat_input: LineEdit = null
var _dm_messages_vbox: VBoxContainer = null
var _dm_messages_scroll: ScrollContainer = null
var _dm_input: LineEdit = null
var _dm_partner_status_badge: TextureRect = null
var _dm_partner_avatar_btn: Button = null
var _dm_invite_btn: TextureButton = null
var _dm_conv_widgets: Dictionary = {}
var _friend_card_widgets: Dictionary = {}
var _friends_online_sub_lbl: Label = null
var _clan_online_pill_lbl: Label = null
var _clan_members_online_val_lbl: Label = null
var _clan_member_widgets: Dictionary = {}

func _ready() -> void:
	_build_ui_shell()
	_connect_realtime_signals()
	if NetworkManager.is_online and not NetworkManager.is_social_connected and GameManager.is_logged_in and not GameManager.token.is_empty():
		NetworkManager.connect_social_namespace()
	_preload_badge_counts()
	_refresh_current_tab()


func _connect_realtime_signals() -> void:
	NetworkManager.social_init_received.connect(func(_p: Dictionary):
		_update_main_tab_buttons()
	)
	NetworkManager.social_badges_changed.connect(_update_main_tab_buttons)
	NetworkManager.social_presence_changed.connect(_on_realtime_presence_changed)
	NetworkManager.social_dm_received.connect(_on_realtime_dm_received)
	NetworkManager.social_dm_read_received.connect(_on_realtime_dm_read_received)
	NetworkManager.social_clan_chat_received.connect(_on_realtime_clan_chat_received)
	NetworkManager.social_clan_chat_deleted.connect(_on_realtime_clan_chat_deleted)
	NetworkManager.social_clan_event_received.connect(_on_realtime_clan_event)
	NetworkManager.social_notification_received.connect(_on_realtime_notification_received)
	NetworkManager.social_error_received.connect(func(msg: String):
		_show_toast(msg, CafeSocialTheme.COL_CRIMSON_TEXT)
	)


func _build_ui_shell() -> void:
	for c in get_children():
		c.queue_free()

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_top", 10)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(outer_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(root_vbox)

	# 1. Top Subheader with Title and Refresh
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_row)

	var btn_refresh := TextureButton.new()
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
		_preload_badge_counts()
		if current_main_tab == "clans" and current_clans_subtab in ["my_clan", "members"]:
			refresh_my_clan_data(true)
		else:
			_refresh_current_tab()
	)
	top_row.add_child(btn_refresh)

	var title_lbl := Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_lbl.add_theme_constant_override("shadow_outline_size", 2)
	title_lbl.text = "کافه"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(title_lbl)

	# 2. Toast Panel
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	lbl_status_toast = CafeSocialTheme.make_body("", 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(lbl_status_toast)

	# 3. 3-Hub Navigation Bar inside frame_small (remove frame under these 3 tabs)
	var nav_frame := PanelContainer.new()
	nav_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root_vbox.add_child(nav_frame)

	_nav_hbox = HBoxContainer.new()
	_nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_hbox.add_theme_constant_override("separation", 8)
	nav_frame.add_child(_nav_hbox)

	# 4. Content Area
	content_area = MarginContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_area)

	_update_main_tab_buttons()


func _preload_badge_counts() -> void:
	if not GameManager.is_logged_in:
		return
	NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			_my_clan_data = data["result"]
			_update_main_tab_buttons()
	)
	NetworkManager.api.get_friend_requests(func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var r: Dictionary = data["result"]
			_incoming_requests = r.get("incoming", []) if typeof(r.get("incoming")) == TYPE_ARRAY else []
			_outgoing_requests = r.get("outgoing", []) if typeof(r.get("outgoing")) == TYPE_ARRAY else []
			NetworkManager.incoming_friend_requests_count = _incoming_requests.size()
			NetworkManager.notify_social_badges_changed()
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
	if not is_instance_valid(_nav_hbox):
		return
	for ch in _nav_hbox.get_children():
		ch.queue_free()

	var has_clan := false
	var clan_emb := 1
	if _my_clan_data.has("clan") and typeof(_my_clan_data["clan"]) == TYPE_DICTIONARY and not _my_clan_data["clan"].is_empty():
		has_clan = true
		clan_emb = int(_my_clan_data["clan"].get("emblem_id", 1))
	elif GameManager.user_data.has("clan") and typeof(GameManager.user_data["clan"]) == TYPE_DICTIONARY and not GameManager.user_data["clan"].is_empty():
		has_clan = true
		clan_emb = int(GameManager.user_data["clan"].get("emblem_id", 1))
	elif GameManager.user_data.has("clan_id") and not str(GameManager.user_data["clan_id"]).is_empty():
		has_clan = true

	var tab_defs := [
		{"id": "friends", "badge": _incoming_requests.size()},
		{"id": "clans", "badge": 0},
		{"id": "messages", "badge": NetworkManager.unread_dms_count},
	]
	for td in tab_defs:
		var tid: String = td["id"]
		var custom_icon: Texture2D = null
		if tid == "clans":
			if has_clan:
				custom_icon = CafeSocialTheme.get_clan_emblem_texture(clan_emb)
			else:
				custom_icon = preload("res://assets/images/frames/clan.png")
		elif tid == "friends":
			custom_icon = preload("res://assets/images/frames/friends.png")
		elif tid == "messages":
			custom_icon = preload("res://assets/images/frames/chat.png")

		var btn := CafeSocialTheme.make_nav_tab(
			tid,
			int(td["badge"]),
			current_main_tab == tid,
			custom_icon
		)
		btn.pressed.connect(func():
			_switch_main_tab(tid)
		)
		_nav_hbox.add_child(btn)


func _switch_main_tab(tab_name: String) -> void:
	AudioManager.sfx_tap()
	current_main_tab = tab_name
	_update_main_tab_buttons()
	_refresh_current_tab()


func _refresh_current_tab() -> void:
	var body_vbox := _clear_content()
	match current_main_tab:
		"friends":
			SocialFriendsView.render(self, body_vbox)
		"clans":
			SocialClansView.render(self, body_vbox)
		"messages":
			SocialMessagesView.render(self, body_vbox)
		_:
			SocialFriendsView.render(self, body_vbox)


func _clear_content() -> VBoxContainer:
	_clan_chat_list_vbox = null
	_clan_chat_scroll = null
	_clan_chat_input = null
	_clan_chat_is_loading_older = false
	_dm_messages_vbox = null
	_dm_messages_scroll = null
	_dm_input = null
	_dm_partner_status_badge = null
	_dm_partner_avatar_btn = null
	_dm_invite_btn = null
	_dm_conv_widgets.clear()
	_friend_card_widgets.clear()
	_friends_online_sub_lbl = null
	_clan_online_pill_lbl = null
	_clan_members_online_val_lbl = null
	_clan_member_widgets.clear()
	for c in content_area.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	content_area.add_child(vbox)
	return vbox


func _open_player_profile(u_dict: Dictionary) -> void:
	UserProfileDialog.show_user(u_dict, "", self)


func open_direct_message_with(user_id: String, username: String) -> void:
	_active_dm_partner_id = user_id
	_active_dm_partner_name = username if not username.is_empty() else "بازیکن"
	_active_dm_partner_info = {"user_id": user_id, "username": _active_dm_partner_name}
	_switch_main_tab("messages")


func _send_clan_chat_message() -> void:
	if not is_instance_valid(_clan_chat_input):
		return
	var txt := _clan_chat_input.text.strip_edges()
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
				var mid := str(msg_res.get("message_id", msg_res.get("_id", "")))
				var exists := false
				for m in _clan_chat_messages:
					if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid and not mid.is_empty():
						exists = true
						break
				if not exists:
					_clan_chat_messages.append(msg_res)
					SocialClansView.append_clan_chat_message(self, msg_res)
			elif typeof(data) == TYPE_DICTIONARY:
				_show_toast(str(data.get("detail", "خطا در ارسال پیام اتحاد")), CafeSocialTheme.COL_CRIMSON_TEXT)
		)


func _send_active_dm() -> void:
	if _active_dm_partner_id.is_empty() or not is_instance_valid(_dm_input):
		return
	var txt := _dm_input.text.strip_edges()
	if txt.is_empty():
		return
	_dm_input.text = ""
	if NetworkManager.is_social_connected:
		NetworkManager.send_dm_realtime(_active_dm_partner_id, txt)
	else:
		if NetworkManager.is_online and not GameManager.token.is_empty():
			NetworkManager.connect_social_namespace()
		NetworkManager.api.send_direct_message_rest(_active_dm_partner_id, txt, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var dm_res: Dictionary = data["result"]
				var mid := str(dm_res.get("message_id", dm_res.get("_id", "")))
				var exists := false
				for m in _active_dm_messages:
					if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid and not mid.is_empty():
						exists = true
						break
				if not exists:
					_active_dm_messages.append(dm_res)
					SocialMessagesView.render_messages(self)
			elif typeof(data) == TYPE_DICTIONARY:
				_show_toast(str(data.get("detail", "خطا در ارسال پیام")), CafeSocialTheme.COL_CRIMSON_TEXT)
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
			if force_render and current_main_tab == "clans":
				if not now_has_clan and current_clans_subtab in ["chat", "members"]:
					current_clans_subtab = "my_clan"
					_refresh_current_tab()
				elif (now_has_clan != prev_has_clan) or current_clans_subtab != "chat":
					_refresh_current_tab()
	)


func refresh_friends_and_requests(force_render: bool = true) -> void:
	if not GameManager.is_logged_in:
		return
	NetworkManager.api.get_friend_requests(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(self):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var r: Dictionary = data["result"]
			_incoming_requests = r.get("incoming", []) if typeof(r.get("incoming")) == TYPE_ARRAY else []
			_outgoing_requests = r.get("outgoing", []) if typeof(r.get("outgoing")) == TYPE_ARRAY else []
			NetworkManager.incoming_friend_requests_count = _incoming_requests.size()
			NetworkManager.notify_social_badges_changed()
			_update_main_tab_buttons()
		NetworkManager.api.get_friends_list(func(ok2: bool, _c2: int, data2: Variant):
			if not is_instance_valid(self):
				return
			if ok2 and typeof(data2) == TYPE_DICTIONARY and typeof(data2.get("result")) == TYPE_ARRAY:
				_friends_list = data2["result"]
			_update_main_tab_buttons()
			if force_render and current_main_tab == "friends":
				_refresh_current_tab()
		)
	)


func _on_realtime_presence_changed(payload: Dictionary) -> void:
	var pid := str(payload.get("user_id", ""))
	if pid.is_empty():
		return
	var new_st := str(payload.get("status", "offline"))
	var pres_dict := {
		"status": new_st,
		"current_game_type": str(payload.get("current_game_type", "")),
		"current_game_id": str(payload.get("current_game_id", "")),
		"current_lobby_id": str(payload.get("current_lobby_id", "")),
		"last_seen": str(payload.get("last_seen", "")),
	}

	# Update cached friends list
	for f in _friends_list:
		if typeof(f) == TYPE_DICTIONARY and str(f.get("user_id", f.get("_id", ""))) == pid:
			f["status"] = new_st
			f["presence"] = pres_dict

	# Update cached clan members
	var c_dict: Variant = _my_clan_data.get("clan", null)
	if typeof(c_dict) == TYPE_DICTIONARY and typeof(c_dict.get("members")) == TYPE_ARRAY:
		for m in c_dict["members"]:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("user_id", m.get("_id", ""))) == pid:
				m["status"] = new_st
				m["presence"] = pres_dict

	# Update cached conversations & active DM partner
	for conv in _conversations:
		if typeof(conv) == TYPE_DICTIONARY and typeof(conv.get("partner")) == TYPE_DICTIONARY:
			var p: Dictionary = conv["partner"]
			if str(p.get("user_id", p.get("_id", ""))) == pid:
				p["status"] = new_st
				p["presence"] = pres_dict
	if pid == _active_dm_partner_id and typeof(_active_dm_partner_info) == TYPE_DICTIONARY:
		_active_dm_partner_info["status"] = new_st
		_active_dm_partner_info["presence"] = pres_dict

	# Lightweight in-place UI updates (zero redundant HTTP calls!)
	if current_main_tab == "friends" and current_friends_subtab == "list":
		SocialFriendsView.update_friend_presence(self, pid, new_st)
	elif current_main_tab == "clans":
		SocialClansView.update_member_presence(self, pid, new_st)
	elif current_main_tab == "messages":
		if _active_dm_partner_id.is_empty():
			SocialMessagesView.update_conversation_presence(self, pid, new_st)
		elif pid == _active_dm_partner_id:
			SocialMessagesView.update_active_partner_presence(self, new_st)


func _on_realtime_dm_received(payload: Dictionary) -> void:
	var my_uid := str(GameManager.get_user_id())
	var from_uid := str(payload.get("from_user_id", payload.get("sender_id", "")))
	var to_uid := str(payload.get("to_user_id", ""))
	var matches_active := (not _active_dm_partner_id.is_empty()) and (
		from_uid == _active_dm_partner_id
		or (from_uid == my_uid and to_uid == _active_dm_partner_id)
	)
	if current_main_tab == "messages" and matches_active:
		var mid := str(payload.get("message_id", payload.get("_id", "")))
		var exists := false
		if not mid.is_empty():
			for m in _active_dm_messages:
				if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid:
					exists = true
					break
		if not exists:
			_active_dm_messages.append(payload)
			SocialMessagesView.render_messages(self)
		if from_uid == _active_dm_partner_id:
			NetworkManager.mark_dm_read_realtime(_active_dm_partner_id)
			NetworkManager.unread_dms_count = max(0, NetworkManager.unread_dms_count - 1)
			NetworkManager.notify_social_badges_changed()
	elif current_main_tab == "messages" and _active_dm_partner_id.is_empty():
		_refresh_current_tab()
	_update_main_tab_buttons()


func _on_realtime_dm_read_received(payload: Dictionary) -> void:
	var reader_id := str(payload.get("reader_id", ""))
	if current_main_tab == "messages" and not _active_dm_partner_id.is_empty() and reader_id == _active_dm_partner_id:
		for m in _active_dm_messages:
			if typeof(m) == TYPE_DICTIONARY:
				m["is_read"] = true
		SocialMessagesView.render_messages(self)
	_update_main_tab_buttons()


func _on_realtime_clan_chat_received(msg: Dictionary) -> void:
	var mid := str(msg.get("message_id", msg.get("_id", "")))
	var exists := false
	if not mid.is_empty():
		for m in _clan_chat_messages:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", ""))) == mid:
				exists = true
				break
	if not exists:
		_clan_chat_messages.append(msg)
	if current_main_tab == "clans" and current_clans_subtab == "chat":
		SocialClansView.append_clan_chat_message(self, msg)


func _on_realtime_clan_chat_deleted(payload: Dictionary) -> void:
	var message_id := str(payload.get("message_id", payload.get("_id", "")))
	if message_id.is_empty():
		return
	for i in range(_clan_chat_messages.size() - 1, -1, -1):
		var m = _clan_chat_messages[i]
		if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", m.get("_id", m.get("id", "")))) == message_id:
			_clan_chat_messages.remove_at(i)
	if current_main_tab == "clans" and current_clans_subtab == "chat":
		SocialClansView.render_clan_chat(self)


func _on_realtime_clan_event(event: Dictionary) -> void:
	var msg_txt := str(event.get("message", ""))
	if not msg_txt.is_empty():
		_show_toast(msg_txt, CafeSocialTheme.COL_GOLD_BRIGHT)
	var ev_type := str(event.get("event_type", ""))
	var ev_uid := str(event.get("user_id", ""))
	var my_uid := str(GameManager.get_user_id())
	if ev_type == "clan_disbanded" or (ev_type in ["member_left", "member_kicked"] and ev_uid == my_uid):
		_my_clan_data = {}
		_clan_chat_messages.clear()
		GameManager.user_data.erase("clan")
		GameManager.user_data.erase("clan_id")
		_update_main_tab_buttons()
		if current_main_tab == "clans":
			current_clans_subtab = "my_clan"
			_refresh_current_tab()
		return
	refresh_my_clan_data(true)


func _on_realtime_notification_received(notif: Dictionary) -> void:
	_update_main_tab_buttons()
	var ntype := str(notif.get("type", ""))
	if ntype in ["friend_request_received", "friend_request_accepted", "friend_request_updated", "friend_removed"]:
		refresh_friends_and_requests(current_main_tab == "friends")


func _scroll_clan_chat_to_bottom() -> void:
	if not is_instance_valid(_clan_chat_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_clan_chat_scroll):
		var bar: VScrollBar = _clan_chat_scroll.get_v_scroll_bar()
		if bar:
			_clan_chat_scroll.scroll_vertical = int(bar.max_value)


func _scroll_dm_to_bottom() -> void:
	if not is_instance_valid(_dm_messages_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_dm_messages_scroll):
		var bar: VScrollBar = _dm_messages_scroll.get_v_scroll_bar()
		if bar:
			_dm_messages_scroll.scroll_vertical = int(bar.max_value)
