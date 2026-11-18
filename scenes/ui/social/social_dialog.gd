extends Control

## Cafe Fekr — Antique Board-Game Club Social Hub
## Complete visual & UX redesign using authentic wood/gold/emerald framing.
## Primary navigation strictly contains 4 hubs: Friends, Clans, Messages, Notifications.
## Personal profile customization, privacy, notification prefs & blocked players reside in UserProfileDialog.

signal closed()
signal spectate_match_requested(game_id: String, game_type: String)

var _dim_overlay: ColorRect
var main_panel: PanelContainer
var _toast_panel: PanelContainer
var lbl_status_toast: Label

# Top-level 4 navigation tabs container & buttons
var _nav_hbox: HBoxContainer
var content_area: MarginContainer

var current_main_tab: String = "friends"        # "friends" | "clans" | "messages" | "notifs"
var current_friends_subtab: String = "list"     # "list" | "requests" | "search" | "live"
var current_live_scope: String = "all"          # "all" | "friends" | "clan"
var current_live_game_type: String = ""         # "" or canonical game type
var current_clans_subtab: String = "my_clan"    # "my_clan" | "members" | "chat" | "discover" | "leaderboard"
var current_clan_lb_mode: String = "clans"      # "clans" | "clans_weekly" | "clans_monthly"

# Cached State (accessed cleanly by tab views)
var _friends_list: Array = []
var _incoming_requests: Array = []
var _outgoing_requests: Array = []

var _my_clan_data: Dictionary = {}
var _clan_chat_messages: Array = []

var _conversations: Array = []
var _active_dm_partner_id: String = ""
var _active_dm_partner_name: String = ""
var _active_dm_partner_info: Dictionary = {}
var _active_dm_messages: Array = []

# Dynamic live references for chat / message streams
var _clan_chat_list_vbox: VBoxContainer = null
var _clan_chat_scroll: ScrollContainer = null
var _clan_chat_input: LineEdit = null
var _clan_chat_has_more: bool = true
var _clan_chat_is_loading_older: bool = false
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
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui_shell()
	_connect_realtime_signals()


func _connect_realtime_signals() -> void:
	NetworkManager.social_init_received.connect(func(_p: Dictionary):
		_update_main_tab_buttons()
	)
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


func open(initial_tab: String = "friends", dm_partner_id: String = "", dm_partner_name: String = "") -> void:
	if not GameManager.is_logged_in or GameManager.is_guest:
		_show_toast("برای استفاده از باشگاه اجتماعی ابتدا وارد حساب کاربری خود شوید.", CafeSocialTheme.COL_GOLD_BRIGHT)
		return

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if not dm_partner_id.is_empty():
		_active_dm_partner_id = dm_partner_id
		_active_dm_partner_name = dm_partner_name if not dm_partner_name.is_empty() else "بازیکن"
		_active_dm_partner_info = {"user_id": dm_partner_id, "username": _active_dm_partner_name}
		initial_tab = "messages"
	elif initial_tab == "privacy":
		initial_tab = "friends"

	if initial_tab not in ["friends", "clans", "messages", "notifs"]:
		initial_tab = "friends"

	_preload_badge_counts()
	_switch_main_tab(initial_tab)
	ActionVFXManager.animate_dialog_open(main_panel, self, true)


func open_direct_message_with(user_id: String, username: String) -> void:
	open("messages", user_id, username)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_dim_overlay):
		_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(main_panel, self, func():
		visible = false
		closed.emit()
	)


func _preload_badge_counts() -> void:
	NetworkManager.api.get_friend_requests(func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var r: Dictionary = data["result"]
			_incoming_requests = r.get("incoming", []) if typeof(r.get("incoming")) == TYPE_ARRAY else []
			_outgoing_requests = r.get("outgoing", []) if typeof(r.get("outgoing")) == TYPE_ARRAY else []
			NetworkManager.incoming_friend_requests_count = _incoming_requests.size()
			NetworkManager.notify_social_badges_changed()
			_update_main_tab_buttons()
	)


func _build_ui_shell() -> void:
	for c in get_children():
		c.queue_free()

	# Backdrop
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
	margin_outer.add_theme_constant_override("margin_left", 20)
	margin_outer.add_theme_constant_override("margin_right", 20)
	margin_outer.add_theme_constant_override("margin_top", 28)
	margin_outer.add_theme_constant_override("margin_bottom", 28)
	add_child(margin_outer)

	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	margin_outer.add_child(main_panel)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 28)
	inner_margin.add_theme_constant_override("margin_right", 28)
	inner_margin.add_theme_constant_override("margin_top", 26)
	inner_margin.add_theme_constant_override("margin_bottom", 26)
	main_panel.add_child(inner_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	inner_margin.add_child(root_vbox)

	# 1. Slim Top Utility Row (Close left, Refresh right — no oversized title bar)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_row)

	var btn_close := TextureButton.new()
	btn_close.name = "BtnCloseTop"
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
	header_row.add_child(btn_close)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(top_spacer)

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
		_refresh_current_tab()
	)
	header_row.add_child(btn_refresh)

	# 2. Toast Feedback Banner
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	root_vbox.add_child(_toast_panel)

	lbl_status_toast = CafeSocialTheme.make_body("", 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(lbl_status_toast)

	# 3. Primary 4-Hub Navigation Bar (Friends | Clans | Messages | Notifications)
	_nav_hbox = HBoxContainer.new()
	_nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_hbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(_nav_hbox)

	# 4. Content Container
	content_area = MarginContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_area)

	_update_main_tab_buttons()


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

	var tab_defs := [
		{"id": "friends", "badge": _incoming_requests.size()},
		{"id": "clans", "badge": 0},
		{"id": "messages", "badge": NetworkManager.unread_dms_count},
		{"id": "notifs", "badge": NetworkManager.unread_notifications_count},
	]
	for td in tab_defs:
		var tid: String = td["id"]
		var btn := CafeSocialTheme.make_nav_tab(
			tid,
			int(td["badge"]),
			current_main_tab == tid
		)
		btn.pressed.connect(func():
			_switch_main_tab(tid)
		)
		_nav_hbox.add_child(btn)


func _switch_main_tab(tab_name: String) -> void:
	if visible:
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
		"notifs":
			SocialNotificationsView.render(self, body_vbox)


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


func _open_player_profile(u_dict: Dictionary, role_text: String = "") -> void:
	var uid := str(u_dict.get("_id", u_dict.get("user_id", u_dict.get("id", ""))))
	var clean_dict := u_dict.duplicate(true)
	clean_dict["_id"] = uid
	clean_dict["user_id"] = uid
	var dlg = UserProfileDialog.show_user(clean_dict, role_text, self)
	if dlg == null:
		_show_toast("خطا در باز کردن پروفایل بازیکن.", CafeSocialTheme.COL_CRIMSON_TEXT)


# ==============================================================================
# REALTIME / REST MESSAGE SENDERS & SCROLL HELPERS
# ==============================================================================

func _send_clan_chat_message() -> void:
	if not is_instance_valid(_clan_chat_input):
		return
	var txt := _clan_chat_input.text.strip_edges()
	if txt.is_empty():
		return
	_clan_chat_input.text = ""
	if NetworkManager.is_online:
		NetworkManager.send_clan_chat_realtime(txt)
	else:
		NetworkManager.api.send_clan_chat_rest(txt, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_clan_chat_messages.append(data["result"])
				SocialClansView.render_clan_chat(self)
			elif typeof(data) == TYPE_DICTIONARY:
				_show_toast(str(data.get("detail", "خطا در ارسال پیام کلن")), CafeSocialTheme.COL_CRIMSON_TEXT)
		)


func _send_active_dm() -> void:
	if _active_dm_partner_id.is_empty() or not is_instance_valid(_dm_input):
		return
	var txt := _dm_input.text.strip_edges()
	if txt.is_empty():
		return
	_dm_input.text = ""
	NetworkManager.api.send_direct_message_rest(_active_dm_partner_id, txt, func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			_active_dm_messages.append(data["result"])
			SocialMessagesView.render_messages(self)
		elif typeof(data) == TYPE_DICTIONARY:
			_show_toast(str(data.get("detail", "خطا در ارسال پیام خصوصی")), CafeSocialTheme.COL_CRIMSON_TEXT)
	)


func _scroll_dm_to_bottom() -> void:
	if not is_instance_valid(_dm_messages_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_dm_messages_scroll):
		var bar: VScrollBar = _dm_messages_scroll.get_v_scroll_bar()
		if bar:
			_dm_messages_scroll.scroll_vertical = int(bar.max_value)


func _scroll_clan_chat_to_bottom() -> void:
	if not is_instance_valid(_clan_chat_scroll):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_clan_chat_scroll):
		var bar: VScrollBar = _clan_chat_scroll.get_v_scroll_bar()
		if bar:
			_clan_chat_scroll.scroll_vertical = int(bar.max_value)


# ==============================================================================
# REAL-TIME EVENT HANDLERS
# ==============================================================================

func _on_realtime_presence_changed(payload: Dictionary) -> void:
	var uid := str(payload.get("user_id", ""))
	if uid.is_empty():
		return
	var new_st := str(payload.get("status", "offline"))
	var pres_dict := {
		"status": new_st,
		"current_game_type": str(payload.get("current_game_type", "")),
		"current_game_id": str(payload.get("current_game_id", "")),
		"current_lobby_id": str(payload.get("current_lobby_id", "")),
		"last_seen": str(payload.get("last_seen", "")),
	}
	for f in _friends_list:
		if typeof(f) == TYPE_DICTIONARY and str(f.get("user_id", f.get("_id", ""))) == uid:
			f["status"] = new_st
			f["presence"] = pres_dict
	var c_dict: Variant = _my_clan_data.get("clan", null)
	if typeof(c_dict) == TYPE_DICTIONARY and typeof(c_dict.get("members")) == TYPE_ARRAY:
		for m in c_dict["members"]:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("user_id", m.get("_id", ""))) == uid:
				m["status"] = new_st
				m["presence"] = pres_dict
	if uid == _active_dm_partner_id and typeof(_active_dm_partner_info) == TYPE_DICTIONARY:
		_active_dm_partner_info["status"] = new_st
		_active_dm_partner_info["presence"] = pres_dict
	if not visible:
		return
	if current_main_tab == "friends" and current_friends_subtab == "list":
		SocialFriendsView.update_friend_presence(self, uid, new_st)
	elif current_main_tab == "clans":
		SocialClansView.update_member_presence(self, uid, new_st)
	elif current_main_tab == "messages":
		if _active_dm_partner_id.is_empty():
			SocialMessagesView.update_conversation_presence(self, uid, new_st)
		elif uid == _active_dm_partner_id:
			SocialMessagesView.update_active_partner_presence(self, new_st)


func _on_realtime_dm_received(payload: Dictionary) -> void:
	_update_main_tab_buttons()
	if not visible or current_main_tab != "messages":
		return
	var fid := str(payload.get("from_user_id", ""))
	var tid := str(payload.get("to_user_id", ""))
	if _active_dm_partner_id.is_empty():
		_refresh_current_tab()
	elif fid == _active_dm_partner_id or tid == _active_dm_partner_id:
		var mid := str(payload.get("message_id", ""))
		var dup := false
		for m in _active_dm_messages:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", "")) == mid and not mid.is_empty():
				dup = true
				break
		if not dup:
			_active_dm_messages.append(payload)
			SocialMessagesView.render_messages(self)
		if fid == _active_dm_partner_id and NetworkManager.is_online:
			NetworkManager.mark_dm_read_realtime(_active_dm_partner_id)


func _on_realtime_dm_read_received(payload: Dictionary) -> void:
	if not visible or current_main_tab != "messages" or _active_dm_partner_id.is_empty():
		return
	var reader_id := str(payload.get("reader_id", payload.get("user_id", "")))
	if reader_id != _active_dm_partner_id:
		return
	for m in _active_dm_messages:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("to_user_id", "")) == _active_dm_partner_id:
			m["is_read"] = true
	SocialMessagesView.render_messages(self)


func _on_realtime_clan_chat_received(payload: Dictionary) -> void:
	if not visible or current_main_tab != "clans" or current_clans_subtab != "chat":
		return
	var mid := str(payload.get("message_id", ""))
	for m in _clan_chat_messages:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("message_id", "")) == mid and not mid.is_empty():
			return
	_clan_chat_messages.append(payload)
	SocialClansView.append_clan_chat_message(self, payload)


func _on_realtime_clan_chat_deleted(payload: Dictionary) -> void:
	var mid := str(payload.get("message_id", ""))
	_clan_chat_messages = _clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != mid)
	if visible and current_main_tab == "clans" and current_clans_subtab == "chat":
		SocialClansView.render_clan_chat(self)


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
			if force_render and visible and current_main_tab == "clans":
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
			if force_render and visible and current_main_tab == "friends":
				_refresh_current_tab()
		)
	)


func _on_realtime_clan_event(payload: Dictionary) -> void:
	var ev_type := str(payload.get("event_type", ""))
	var ev_uid := str(payload.get("user_id", ""))
	var my_uid := str(GameManager.get_user_id())
	if ev_type == "clan_disbanded" or (ev_type in ["member_left", "member_kicked"] and ev_uid == my_uid):
		_my_clan_data = {}
		_clan_chat_messages.clear()
		GameManager.user_data.erase("clan")
		GameManager.user_data.erase("clan_id")
		_update_main_tab_buttons()
		if visible and current_main_tab == "clans":
			current_clans_subtab = "my_clan"
			_refresh_current_tab()
		return
	refresh_my_clan_data(true)


func _on_realtime_notification_received(payload: Dictionary) -> void:
	_update_main_tab_buttons()
	var ntype := str(payload.get("type", ""))
	if ntype in ["friend_request_received", "friend_request_accepted", "friend_request_updated", "friend_removed"]:
		refresh_friends_and_requests(visible and current_main_tab == "friends")
	elif visible and current_main_tab == "notifs":
		_refresh_current_tab()
