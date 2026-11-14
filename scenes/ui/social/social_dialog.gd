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
var current_friends_subtab: String = "list"     # "list" | "requests" | "search"
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
var _dm_messages_vbox: VBoxContainer = null
var _dm_messages_scroll: ScrollContainer = null
var _dm_input: LineEdit = null


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

	var btn_refresh := CafeSocialTheme.make_button("", "bronze", Vector2(56, 56), 20, CafeSocialTheme.ICO_REFRESH, false, 14)
	btn_refresh.tooltip_text = "بروزرسانی"
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

	lbl_status_toast = CafeSocialTheme.make_body("", 21, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_panel.add_child(lbl_status_toast)

	# 3. Primary 4-Hub Navigation Bar (Friends | Clans | Messages | Notifications)
	var nav_well := PanelContainer.new()
	nav_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(18, 8.0, 8.0))
	root_vbox.add_child(nav_well)

	_nav_hbox = HBoxContainer.new()
	_nav_hbox.add_theme_constant_override("separation", 8)
	nav_well.add_child(_nav_hbox)

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
		{"id": "friends", "label": "دوستان", "icon": CafeSocialTheme.ICO_LOBBY, "badge": _incoming_requests.size()},
		{"id": "clans", "label": "کلن‌ها", "icon": CafeSocialTheme.ICO_RANK, "badge": 0},
		{"id": "messages", "label": "پیام‌ها", "icon": CafeSocialTheme.BADGE_CHAT, "badge": NetworkManager.unread_dms_count},
		{"id": "notifs", "label": "اعلان‌ها", "icon": CafeSocialTheme.ICO_STAR, "badge": NetworkManager.unread_notifications_count},
	]
	for td in tab_defs:
		var tid: String = td["id"]
		var btn := CafeSocialTheme.make_nav_tab(
			td["label"],
			td["icon"],
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
	_dm_messages_vbox = null
	_dm_messages_scroll = null
	_dm_input = null
	for c in content_area.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	content_area.add_child(vbox)
	return vbox


func _open_player_profile(u_dict: Dictionary) -> void:
	var prof_dlg: Node = null
	if is_instance_valid(get_parent()):
		prof_dlg = get_parent().get_node_or_null("UserProfileDialog")
	if prof_dlg == null:
		prof_dlg = get_tree().root.find_child("UserProfileDialog", true, false)
	if prof_dlg and prof_dlg.has_method("open_for_user"):
		var uid := str(u_dict.get("_id", u_dict.get("user_id", u_dict.get("id", ""))))
		var clean_dict := u_dict.duplicate(true)
		clean_dict["_id"] = uid
		clean_dict["user_id"] = uid
		prof_dlg.open_for_user(clean_dict)
	else:
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
	if is_instance_valid(_dm_messages_scroll):
		var bar := _dm_messages_scroll.get_v_scroll_bar()
		if bar:
			_dm_messages_scroll.scroll_vertical = int(bar.max_value)


func _scroll_clan_chat_to_bottom() -> void:
	if not is_instance_valid(_clan_chat_scroll):
		return
	await get_tree().process_frame
	if is_instance_valid(_clan_chat_scroll):
		var bar := _clan_chat_scroll.get_v_scroll_bar()
		if bar:
			_clan_chat_scroll.scroll_vertical = int(bar.max_value)


# ==============================================================================
# REAL-TIME EVENT HANDLERS
# ==============================================================================

func _on_realtime_presence_changed(payload: Dictionary) -> void:
	if not visible:
		return
	var uid := str(payload.get("user_id", ""))
	for f in _friends_list:
		if typeof(f) == TYPE_DICTIONARY and str(f.get("user_id", f.get("_id", ""))) == uid:
			f["presence"] = payload
	if current_main_tab == "friends" and current_friends_subtab == "list":
		_refresh_current_tab()


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
	SocialClansView.render_clan_chat(self)


func _on_realtime_clan_chat_deleted(payload: Dictionary) -> void:
	var mid := str(payload.get("message_id", ""))
	_clan_chat_messages = _clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != mid)
	if visible and current_main_tab == "clans" and current_clans_subtab == "chat":
		SocialClansView.render_clan_chat(self)


func _on_realtime_clan_event(_payload: Dictionary) -> void:
	if visible and current_main_tab == "clans" and current_clans_subtab in ["my_clan", "members"]:
		_refresh_current_tab()


func _on_realtime_notification_received(_payload: Dictionary) -> void:
	_update_main_tab_buttons()
	if visible and current_main_tab == "notifs":
		_refresh_current_tab()
