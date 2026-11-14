extends Control

# Cafe Fekr — Complete Social & Multiplayer Community Hub
# Includes: Friends, Clans & Clan Chat, Direct Messages, Notifications, and Social Profile/Privacy

signal closed()
signal spectate_match_requested(game_id: String, game_type: String)

const GameRegistry = preload("res://scripts/games/game_registry.gd")
const FONT_TITLE = preload("res://assets/fonts/hekayat.ttf")
const FONT_BODY = preload("res://assets/fonts/Vazir.ttf")

var main_panel: PanelContainer
var lbl_header_title: Label
var lbl_status_toast: Label

# Top-level tab buttons
var btn_tab_friends: Button
var btn_tab_clans: Button
var btn_tab_messages: Button
var btn_tab_notifs: Button
var btn_tab_privacy: Button

var content_area: MarginContainer
var current_main_tab: String = "friends"
var current_friends_subtab: String = "list"     # "list", "requests", "search", "blocks"
var current_clans_subtab: String = "my_clan"    # "my_clan", "chat", "search", "create", "leaderboard"
var current_clan_lb_mode: String = "clans"      # "clans", "clans_weekly", "clans_monthly"

# Cached data
var _friends_list: Array = []
var _incoming_requests: Array = []
var _outgoing_requests: Array = []
var _search_players_results: Array = []
var _recent_players: Array = []
var _suggested_players: Array = []
var _blocked_players: Array = []

var _my_clan_data: Dictionary = {}
var _clan_chat_messages: Array = []
var _clan_search_results: Array = []
var _clan_leaderboard_entries: Array = []

var _conversations: Array = []
var _active_dm_partner_id: String = ""
var _active_dm_partner_name: String = ""
var _active_dm_messages: Array = []

var _notifications: Array = []
var _notif_prefs: Dictionary = {
	"friend_requests": true,
	"clan_events": true,
	"clan_chat_mentions": true,
	"direct_messages": true,
	"game_invitations": true
}

var _my_public_profile: Dictionary = {}

# Dynamic live references for chat / lists
var _clan_chat_list_vbox: VBoxContainer = null
var _clan_chat_scroll: ScrollContainer = null
var _clan_chat_input: LineEdit = null
var _dm_messages_vbox: VBoxContainer = null
var _dm_messages_scroll: ScrollContainer = null
var _dm_input: LineEdit = null
var _invite_modal: Control = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui_shell()
	_connect_realtime_signals()


func _connect_realtime_signals() -> void:
	NetworkManager.social_presence_changed.connect(_on_realtime_presence_changed)
	NetworkManager.social_dm_received.connect(_on_realtime_dm_received)
	NetworkManager.social_clan_chat_received.connect(_on_realtime_clan_chat_received)
	NetworkManager.social_clan_chat_deleted.connect(_on_realtime_clan_chat_deleted)
	NetworkManager.social_clan_event_received.connect(_on_realtime_clan_event)
	NetworkManager.social_notification_received.connect(_on_realtime_notification_received)
	NetworkManager.social_error_received.connect(func(msg: String):
		_show_toast("⚠️ " + msg, Color(1.0, 0.55, 0.55))
	)


func open(initial_tab: String = "friends", dm_partner_id: String = "", dm_partner_name: String = "") -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not dm_partner_id.is_empty():
		_active_dm_partner_id = dm_partner_id
		_active_dm_partner_name = dm_partner_name if not dm_partner_name.is_empty() else "بازیکن"
		initial_tab = "messages"
	_switch_main_tab(initial_tab)


func open_direct_message_with(user_id: String, username: String) -> void:
	open("messages", user_id, username)


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func _make_lbl(txt: String, f_size: int = 26, col: Color = Color(0.98, 0.95, 0.88), use_title_font: bool = false, wrap: bool = false) -> Label:
	var l = Label.new()
	l.text = txt
	l.add_theme_font_override("font", FONT_TITLE if use_title_font else FONT_BODY)
	l.add_theme_font_size_override("font_size", f_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_outline_size", 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


func _make_btn(txt: String, min_w: float = 120.0, min_h: float = 54.0, bg: Color = Color(0.22, 0.46, 0.30, 0.96), border: Color = Color(0.55, 0.88, 0.65, 0.95), f_size: int = 24) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT_BODY)
	b.add_theme_font_size_override("font_size", f_size)
	b.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	var st = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	var st_h = st.duplicate()
	st_h.bg_color = bg.lightened(0.14)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st_h)
	b.add_theme_stylebox_override("pressed", st)
	return b


func _make_card_panel(bg: Color = Color(0.15, 0.10, 0.06, 0.94), border: Color = Color(0.68, 0.52, 0.28, 0.82)) -> PanelContainer:
	var p = PanelContainer.new()
	var st = StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", st)
	return p


func _build_ui_shell() -> void:
	for c in get_children():
		c.queue_free()

	# Backdrop
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.82)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	add_child(dim)

	var margin_outer = MarginContainer.new()
	margin_outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_outer.add_theme_constant_override("margin_left", 24)
	margin_outer.add_theme_constant_override("margin_right", 24)
	margin_outer.add_theme_constant_override("margin_top", 36)
	margin_outer.add_theme_constant_override("margin_bottom", 36)
	add_child(margin_outer)

	main_panel = PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shell_st = StyleBoxFlat.new()
	shell_st.bg_color = Color(0.11, 0.07, 0.04, 0.98)
	shell_st.border_color = Color(0.88, 0.68, 0.28, 0.95)
	shell_st.set_border_width_all(3)
	shell_st.set_corner_radius_all(24)
	shell_st.shadow_color = Color(0, 0, 0, 0.75)
	shell_st.shadow_size = 18
	shell_st.content_margin_left = 20
	shell_st.content_margin_right = 20
	shell_st.content_margin_top = 18
	shell_st.content_margin_bottom = 18
	main_panel.add_theme_stylebox_override("panel", shell_st)
	margin_outer.add_child(main_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(root_vbox)

	# Header Row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(header_row)

	var btn_close = _make_btn("✖ بستن", 110, 54, Color(0.52, 0.16, 0.16, 0.95), Color(0.95, 0.45, 0.45, 0.95), 24)
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	header_row.add_child(btn_close)

	lbl_header_title = _make_lbl("🛡️ جامعه کافه فکر — دوستان و کلن‌ها", 38, Color(1.0, 0.88, 0.38), true)
	lbl_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(lbl_header_title)

	var btn_refresh = _make_btn("🔄 بروزرسانی", 140, 54, Color(0.20, 0.34, 0.48, 0.95), Color(0.48, 0.75, 0.95, 0.95), 22)
	btn_refresh.pressed.connect(func():
		AudioManager.sfx_tap()
		_refresh_current_tab()
	)
	header_row.add_child(btn_refresh)

	# Status Toast Banner
	lbl_status_toast = _make_lbl("", 24, Color(0.55, 0.95, 0.65), false, true)
	lbl_status_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status_toast.visible = false
	root_vbox.add_child(lbl_status_toast)

	# Main 5 Navigation Tabs
	var nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(nav_hbox)

	btn_tab_friends = _make_btn("👥 دوستان", 0, 62, Color(0.18, 0.12, 0.08), Color(0.65, 0.50, 0.28), 25)
	btn_tab_friends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tab_friends.pressed.connect(func(): _switch_main_tab("friends"))
	nav_hbox.add_child(btn_tab_friends)

	btn_tab_clans = _make_btn("🛡️ کلن‌ها", 0, 62, Color(0.18, 0.12, 0.08), Color(0.65, 0.50, 0.28), 25)
	btn_tab_clans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tab_clans.pressed.connect(func(): _switch_main_tab("clans"))
	nav_hbox.add_child(btn_tab_clans)

	btn_tab_messages = _make_btn("💬 پیام‌ها", 0, 62, Color(0.18, 0.12, 0.08), Color(0.65, 0.50, 0.28), 25)
	btn_tab_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tab_messages.pressed.connect(func(): _switch_main_tab("messages"))
	nav_hbox.add_child(btn_tab_messages)

	btn_tab_notifs = _make_btn("🔔 اعلان‌ها", 0, 62, Color(0.18, 0.12, 0.08), Color(0.65, 0.50, 0.28), 25)
	btn_tab_notifs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tab_notifs.pressed.connect(func(): _switch_main_tab("notifs"))
	nav_hbox.add_child(btn_tab_notifs)

	btn_tab_privacy = _make_btn("🎖️ پروفایل من", 0, 62, Color(0.18, 0.12, 0.08), Color(0.65, 0.50, 0.28), 25)
	btn_tab_privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_tab_privacy.pressed.connect(func(): _switch_main_tab("privacy"))
	nav_hbox.add_child(btn_tab_privacy)

	# Content Container
	content_area = MarginContainer.new()
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_area)


func _show_toast(txt: String, col: Color = Color(0.55, 0.95, 0.65)) -> void:
	if not is_instance_valid(lbl_status_toast):
		return
	lbl_status_toast.text = txt
	lbl_status_toast.add_theme_color_override("font_color", col)
	lbl_status_toast.visible = true
	get_tree().create_timer(3.5).timeout.connect(func():
		if is_instance_valid(lbl_status_toast) and lbl_status_toast.text == txt:
			lbl_status_toast.visible = false
	)


func _update_main_tab_buttons() -> void:
	var tabs = {
		"friends": btn_tab_friends,
		"clans": btn_tab_clans,
		"messages": btn_tab_messages,
		"notifs": btn_tab_notifs,
		"privacy": btn_tab_privacy
	}
	for k in tabs.keys():
		var b: Button = tabs[k]
		if not is_instance_valid(b):
			continue
		var active = (k == current_main_tab)
		var bg = Color(0.76, 0.54, 0.14, 0.98) if active else Color(0.18, 0.12, 0.08, 0.92)
		var bd = Color(1.0, 0.88, 0.42, 1.0) if active else Color(0.55, 0.42, 0.25, 0.75)
		var st = StyleBoxFlat.new()
		st.bg_color = bg
		st.border_color = bd
		st.set_border_width_all(3 if active else 2)
		st.set_corner_radius_all(14)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)

	if is_instance_valid(btn_tab_messages):
		btn_tab_messages.text = "💬 پیام‌ها (%s)" % GameManager.to_fa_num(NetworkManager.unread_dms_count) if NetworkManager.unread_dms_count > 0 else "💬 پیام‌ها"
	if is_instance_valid(btn_tab_notifs):
		btn_tab_notifs.text = "🔔 اعلان‌ها (%s)" % GameManager.to_fa_num(NetworkManager.unread_notifications_count) if NetworkManager.unread_notifications_count > 0 else "🔔 اعلان‌ها"


func _switch_main_tab(tab_name: String) -> void:
	AudioManager.sfx_tap()
	current_main_tab = tab_name
	_update_main_tab_buttons()
	_refresh_current_tab()


func _refresh_current_tab() -> void:
	match current_main_tab:
		"friends":
			_load_friends_data()
		"clans":
			_load_clans_data()
		"messages":
			_load_messages_data()
		"notifs":
			_load_notifications_data()
		"privacy":
			_load_privacy_profile_data()


func _clear_content() -> VBoxContainer:
	_clan_chat_list_vbox = null
	_clan_chat_scroll = null
	_clan_chat_input = null
	_dm_messages_vbox = null
	_dm_messages_scroll = null
	_dm_input = null
	for c in content_area.get_children():
		c.queue_free()
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	content_area.add_child(vbox)
	return vbox


func _format_presence_badge(presence: Dictionary) -> Dictionary:
	var st = str(presence.get("status", "offline"))
	var gtype = str(presence.get("current_game_type", ""))
	match st:
		"online":
			return {"text": "🟢 آنلاین", "color": Color(0.45, 0.95, 0.55)}
		"in_game":
			var gt_fa = GameRegistry.get_display_name_fa(gtype) if not gtype.is_empty() else "مسابقه"
			return {"text": "🎮 در بازی (%s)" % gt_fa, "color": Color(0.45, 0.85, 1.0)}
		"in_lobby":
			return {"text": "🏠 در لابی دوستانه", "color": Color(1.0, 0.85, 0.40)}
		"in_queue":
			return {"text": "⏳ در صف جستجو", "color": Color(0.95, 0.75, 0.35)}
		"away":
			return {"text": "🌙 دور از دسترس", "color": Color(0.85, 0.75, 0.50)}
		_:
			return {"text": "⚪ آفلاین", "color": Color(0.68, 0.64, 0.60)}


# ==============================================================================
# TAB 1: FRIENDS SYSTEM
# ==============================================================================

func _load_friends_data() -> void:
	var root = _clear_content()
	# Sub-navigation bar
	var sub_row = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	root.add_child(sub_row)

	var subtabs = [
		{"id": "list", "label": "👥 دوستان من (%s)" % GameManager.to_fa_num(_friends_list.size())},
		{"id": "requests", "label": "📩 درخواست‌ها (%s)" % GameManager.to_fa_num(_incoming_requests.size())},
		{"id": "search", "label": "🔍 جستجو و پیشنهادها"},
		{"id": "blocks", "label": "🚫 مسدودشده‌ها"}
	]
	for st_info in subtabs:
		var sid = st_info["id"]
		var is_act = (current_friends_subtab == sid)
		var btn = _make_btn(
			st_info["label"], 0, 50,
			Color(0.28, 0.52, 0.34) if is_act else Color(0.16, 0.11, 0.07),
			Color(0.62, 0.92, 0.68) if is_act else Color(0.45, 0.34, 0.22),
			22
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			current_friends_subtab = sid
			_load_friends_data()
		)
		sub_row.add_child(btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vbox)

	if current_friends_subtab == "list":
		NetworkManager.api.get_friends_list(func(ok: bool, _code: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
				_friends_list = data["result"] if typeof(data["result"]) == TYPE_ARRAY else []
				if is_instance_valid(list_vbox):
					_populate_friends_list_ui(list_vbox)
		)
	elif current_friends_subtab == "requests":
		NetworkManager.api.get_friend_requests(func(ok: bool, _code: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
				var r = data["result"] if typeof(data["result"]) == TYPE_DICTIONARY else {}
				_incoming_requests = r.get("incoming", [])
				_outgoing_requests = r.get("outgoing", [])
				if is_instance_valid(list_vbox):
					_populate_friend_requests_ui(list_vbox)
		)
	elif current_friends_subtab == "search":
		_populate_friend_search_and_discover_ui(list_vbox)
	elif current_friends_subtab == "blocks":
		NetworkManager.api.get_blocked_players(func(ok: bool, _code: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
				_blocked_players = data["result"] if typeof(data["result"]) == TYPE_ARRAY else []
				if is_instance_valid(list_vbox):
					_populate_blocked_players_ui(list_vbox)
		)


func _populate_friends_list_ui(list_vbox: VBoxContainer) -> void:
	for c in list_vbox.get_children():
		c.queue_free()
	if _friends_list.is_empty():
		var empty_lbl = _make_lbl("هنوز دوستی در لیست شما نیست. از بخش «جستجو و پیشنهادها» دوستان خود را پیدا کنید!", 26, Color(0.85, 0.80, 0.72), false, true)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_vbox.add_child(empty_lbl)
		return

	for f in _friends_list:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		list_vbox.add_child(_build_player_social_card(f, "friend"))


func _build_player_social_card(u: Dictionary, mode: String, req_id: String = "") -> PanelContainer:
	var card = _make_card_panel()
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var uid = str(u.get("user_id", u.get("_id", "")))
	var uname = str(u.get("username", "بازیکن"))
	var score = int(u.get("score", 0))
	var lvl = int(u.get("level", 1))
	var clan_info = u.get("clan", {}) if typeof(u.get("clan")) == TYPE_DICTIONARY else {}
	var clan_tag = str(clan_info.get("tag", "")) if typeof(clan_info) == TYPE_DICTIONARY else ""
	var pres = u.get("presence", {}) if typeof(u.get("presence")) == TYPE_DICTIONARY else {}
	var pres_info = _format_presence_badge(pres if typeof(pres) == TYPE_DICTIONARY else {})

	# Info Column
	var info_col = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 4)
	row.add_child(info_col)

	var title_txt = uname + ("  [%s]" % clan_tag if not clan_tag.is_empty() else "")
	info_col.add_child(_make_lbl(title_txt, 28, Color(1.0, 0.96, 0.86), true))
	info_col.add_child(_make_lbl("🏆 امتیاز: %s   |   ⭐ سطح: %s   |   %s" % [
		GameManager.to_fa_num(score),
		GameManager.to_fa_num(lvl),
		pres_info["text"]
	], 22, pres_info["color"]))

	# Action Buttons
	var acts = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	row.add_child(acts)

	var btn_prof = _make_btn("👤 پروفایل", 110, 48, Color(0.24, 0.20, 0.16), Color(0.75, 0.62, 0.42), 21)
	btn_prof.pressed.connect(func():
		var prof_dlg = get_tree().root.find_child("UserProfileDialog", true, false)
		if prof_dlg and prof_dlg.has_method("open_for_user"):
			prof_dlg.open_for_user({"_id": uid, "username": uname, "score": score, "image": int(u.get("image", 0)), "level": lvl})
	)
	acts.add_child(btn_prof)

	if mode == "friend":
		var btn_dm = _make_btn("💬 پیام", 105, 48, Color(0.18, 0.38, 0.56), Color(0.48, 0.78, 0.98), 21)
		btn_dm.pressed.connect(func():
			open_direct_message_with(uid, uname)
		)
		acts.add_child(btn_dm)

		var btn_inv = _make_btn("⚔️ دعوت بازی", 130, 48, Color(0.20, 0.48, 0.28), Color(0.52, 0.92, 0.62), 21)
		btn_inv.pressed.connect(func():
			_open_game_invite_modal(uid, uname)
		)
		acts.add_child(btn_inv)

		var cur_gid = str(pres.get("current_game_id", "")) if typeof(pres) == TYPE_DICTIONARY else ""
		if str(pres.get("status", "")) == "in_game" and not cur_gid.is_empty():
			var btn_spec = _make_btn("👁️ تماشا", 110, 48, Color(0.46, 0.34, 0.14), Color(0.95, 0.78, 0.35), 21)
			btn_spec.pressed.connect(func():
				NetworkManager.request_spectate_game(cur_gid)
				_show_toast("درخواست تماشای مسابقه ارسال شد...")
			)
			acts.add_child(btn_spec)

		var btn_rem = _make_btn("✖", 54, 48, Color(0.48, 0.16, 0.16), Color(0.88, 0.42, 0.42), 21)
		btn_rem.pressed.connect(func():
			NetworkManager.api.remove_friend(uid, func(ok: bool, _c: int, _d: Variant):
				if ok:
					_show_toast("از لیست دوستان حذف شد.")
					_load_friends_data()
			)
		)
		acts.add_child(btn_rem)

	elif mode == "incoming_req":
		var btn_acc = _make_btn("✅ قبول", 110, 48, Color(0.18, 0.50, 0.28), Color(0.52, 0.92, 0.62), 21)
		btn_acc.pressed.connect(func():
			NetworkManager.api.respond_friend_request(req_id, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					_show_toast("درخواست دوستی پذیرفته شد!")
					_load_friends_data()
			)
		)
		acts.add_child(btn_acc)

		var btn_rej = _make_btn("❌ رد", 95, 48, Color(0.50, 0.18, 0.18), Color(0.90, 0.45, 0.45), 21)
		btn_rej.pressed.connect(func():
			NetworkManager.api.respond_friend_request(req_id, "reject", func(ok: bool, _c: int, _d: Variant):
				if ok:
					_load_friends_data()
			)
		)
		acts.add_child(btn_rej)

	elif mode == "outgoing_req":
		var btn_cancel = _make_btn("لغو درخواست", 130, 48, Color(0.45, 0.24, 0.16), Color(0.85, 0.52, 0.38), 21)
		btn_cancel.pressed.connect(func():
			NetworkManager.api.respond_friend_request(req_id, "cancel", func(ok: bool, _c: int, _d: Variant):
				if ok:
					_show_toast("درخواست دوستی لغو شد.")
					_load_friends_data()
			)
		)
		acts.add_child(btn_cancel)

	elif mode == "search":
		var is_fr = bool(u.get("is_friend", false))
		var p_req = u.get("pending_request", null)
		if is_fr:
			acts.add_child(_make_lbl("✓ دوست شما", 22, Color(0.52, 0.95, 0.62)))
		elif typeof(p_req) == TYPE_DICTIONARY:
			acts.add_child(_make_lbl("⏳ در انتظار پاسخ", 22, Color(1.0, 0.84, 0.42)))
		else:
			var btn_add = _make_btn("➕ درخواست دوستی", 165, 48, Color(0.20, 0.48, 0.28), Color(0.55, 0.92, 0.65), 21)
			btn_add.pressed.connect(func():
				NetworkManager.api.send_friend_request(uid, "", func(ok: bool, _c: int, d: Variant):
					if ok:
						_show_toast("درخواست دوستی برای %s ارسال شد!" % uname)
						btn_add.disabled = true
						btn_add.text = "✓ ارسال شد"
					else:
						var detail = str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا"
						_show_toast(detail, Color(1.0, 0.55, 0.55))
				)
			)
			acts.add_child(btn_add)

	elif mode == "blocked":
		var btn_unblk = _make_btn("رفع مسدودیت", 145, 48, Color(0.24, 0.42, 0.54), Color(0.55, 0.82, 0.95), 21)
		btn_unblk.pressed.connect(func():
			NetworkManager.api.unblock_player(uid, func(ok: bool, _c: int, _d: Variant):
				if ok:
					_show_toast("رفع مسدودیت انجام شد.")
					_load_friends_data()
			)
		)
		acts.add_child(btn_unblk)

	return card


func _populate_friend_requests_ui(list_vbox: VBoxContainer) -> void:
	for c in list_vbox.get_children():
		c.queue_free()
	list_vbox.add_child(_make_lbl("📥 درخواست‌های دوستی دریافتی (%s)" % GameManager.to_fa_num(_incoming_requests.size()), 28, Color(1.0, 0.88, 0.42), true))
	if _incoming_requests.is_empty():
		list_vbox.add_child(_make_lbl("درخواست دوستی جدیدی ندارید.", 22, Color(0.75, 0.70, 0.64)))
	else:
		for req in _incoming_requests:
			if typeof(req) == TYPE_DICTIONARY and typeof(req.get("user")) == TYPE_DICTIONARY:
				list_vbox.add_child(_build_player_social_card(req["user"], "incoming_req", str(req.get("request_id", ""))))

	list_vbox.add_child(_make_lbl("📤 درخواست‌های ارسالی در انتظار (%s)" % GameManager.to_fa_num(_outgoing_requests.size()), 28, Color(0.85, 0.82, 0.72), true))
	if _outgoing_requests.is_empty():
		list_vbox.add_child(_make_lbl("درخواست ارسالی در انتظاری ندارید.", 22, Color(0.75, 0.70, 0.64)))
	else:
		for req in _outgoing_requests:
			if typeof(req) == TYPE_DICTIONARY and typeof(req.get("user")) == TYPE_DICTIONARY:
				list_vbox.add_child(_build_player_social_card(req["user"], "outgoing_req", str(req.get("request_id", ""))))


func _populate_friend_search_and_discover_ui(list_vbox: VBoxContainer) -> void:
	for c in list_vbox.get_children():
		c.queue_free()

	var search_bar = HBoxContainer.new()
	search_bar.add_theme_constant_override("separation", 10)
	list_vbox.add_child(search_bar)

	var input_q = LineEdit.new()
	input_q.placeholder_text = "نام کاربری یا شناسه بازیکن را وارد کنید..."
	input_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_q.custom_minimum_size = Vector2(0, 54)
	input_q.add_theme_font_override("font", FONT_BODY)
	input_q.add_theme_font_size_override("font_size", 24)
	search_bar.add_child(input_q)

	var results_box = VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 8)

	var btn_do_search = _make_btn("🔍 جستجو", 140, 54, Color(0.72, 0.50, 0.14), Color(1.0, 0.85, 0.38), 24)
	btn_do_search.pressed.connect(func():
		var q = input_q.text.strip_edges()
		if q.is_empty():
			return
		NetworkManager.api.search_social_players(q, func(ok: bool, _c: int, data: Variant):
			for ch in results_box.get_children():
				ch.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				var arr: Array = data["result"]
				if arr.is_empty():
					results_box.add_child(_make_lbl("بازیکنی با این مشخصات یافت نشد.", 24, Color(0.85, 0.75, 0.68)))
				for item in arr:
					if typeof(item) == TYPE_DICTIONARY:
						results_box.add_child(_build_player_social_card(item, "search"))
		)
	)
	search_bar.add_child(btn_do_search)
	list_vbox.add_child(results_box)

	var discover_box = VBoxContainer.new()
	discover_box.add_theme_constant_override("separation", 8)
	list_vbox.add_child(discover_box)

	NetworkManager.api.get_social_discover(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(discover_box):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			var recent: Array = res.get("recently_played", [])
			var suggested: Array = res.get("suggested_friends", [])

			discover_box.add_child(_make_lbl("⚔️ هم‌بازی‌های اخیر شما", 28, Color(1.0, 0.88, 0.42), true))
			if recent.is_empty():
				discover_box.add_child(_make_lbl("هنوز مسابقه‌ای ثبت نشده است.", 22, Color(0.72, 0.68, 0.62)))
			for r_u in recent:
				if typeof(r_u) == TYPE_DICTIONARY:
					discover_box.add_child(_build_player_social_card(r_u, "search"))

			discover_box.add_child(_make_lbl("✨ پیشنهاد دوستی (دوستان مشترک)", 28, Color(0.55, 0.92, 0.72), true))
			if suggested.is_empty():
				discover_box.add_child(_make_lbl("پیشنهاد جدیدی موجود نیست.", 22, Color(0.72, 0.68, 0.62)))
			for s_u in suggested:
				if typeof(s_u) == TYPE_DICTIONARY:
					discover_box.add_child(_build_player_social_card(s_u, "search"))
	)


func _populate_blocked_players_ui(list_vbox: VBoxContainer) -> void:
	for c in list_vbox.get_children():
		c.queue_free()
	if _blocked_players.is_empty():
		list_vbox.add_child(_make_lbl("لیست مسدودشده‌های شما خالی است.", 24, Color(0.80, 0.76, 0.70)))
		return
	for b in _blocked_players:
		if typeof(b) == TYPE_DICTIONARY and typeof(b.get("user")) == TYPE_DICTIONARY:
			list_vbox.add_child(_build_player_social_card(b["user"], "blocked"))


# ==============================================================================
# TAB 2: CLAN / GUILD SYSTEM & CLAN CHAT
# ==============================================================================

func _load_clans_data() -> void:
	var root = _clear_content()
	var sub_row = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	root.add_child(sub_row)

	var subtabs = [
		{"id": "my_clan", "label": "🛡️ کلن من"},
		{"id": "chat", "label": "💬 چت کلن"},
		{"id": "search", "label": "🔍 جستجوی کلن"},
		{"id": "create", "label": "➕ ساخت کلن"},
		{"id": "leaderboard", "label": "🏆 برترین کلن‌ها"}
	]
	for st_info in subtabs:
		var sid = st_info["id"]
		var is_act = (current_clans_subtab == sid)
		var btn = _make_btn(
			st_info["label"], 0, 50,
			Color(0.28, 0.52, 0.34) if is_act else Color(0.16, 0.11, 0.07),
			Color(0.62, 0.92, 0.68) if is_act else Color(0.45, 0.34, 0.22),
			22
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			current_clans_subtab = sid
			_load_clans_data()
		)
		sub_row.add_child(btn)

	var body_box = VBoxContainer.new()
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override("separation", 10)
	root.add_child(body_box)

	if current_clans_subtab == "my_clan":
		NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(body_box):
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_my_clan_data = data["result"]
				_build_my_clan_view(body_box)
		)
	elif current_clans_subtab == "chat":
		_build_clan_chat_view(body_box)
	elif current_clans_subtab == "search":
		_build_clan_search_view(body_box)
	elif current_clans_subtab == "create":
		_build_clan_create_view(body_box)
	elif current_clans_subtab == "leaderboard":
		_build_clan_leaderboard_view(body_box)


func _build_my_clan_view(body_box: VBoxContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var clan = _my_clan_data.get("clan", null)
	if clan == null or typeof(clan) != TYPE_DICTIONARY or clan.is_empty():
		var no_card = _make_card_panel()
		var nc_vbox = VBoxContainer.new()
		nc_vbox.add_theme_constant_override("separation", 10)
		no_card.add_child(nc_vbox)
		nc_vbox.add_child(_make_lbl("شما هنوز عضو هیچ کلنی نیستید!", 32, Color(1.0, 0.88, 0.38), true))
		nc_vbox.add_child(_make_lbl("با عضویت در یک کلن، در چالش‌های هفتگی، چت تیمی و جدول رتبه‌بندی کلن‌ها شرکت کنید.", 24, Color(0.88, 0.82, 0.74), false, true))

		var act_row = HBoxContainer.new()
		act_row.add_theme_constant_override("separation", 12)
		nc_vbox.add_child(act_row)

		var btn_go_search = _make_btn("🔍 جستجوی کلن‌های فعال", 240, 56)
		btn_go_search.pressed.connect(func():
			current_clans_subtab = "search"
			_load_clans_data()
		)
		act_row.add_child(btn_go_search)

		var btn_go_create = _make_btn("➕ ساخت کلن جدید (رایگان)", 260, 56, Color(0.68, 0.46, 0.12), Color(1.0, 0.84, 0.36))
		btn_go_create.pressed.connect(func():
			current_clans_subtab = "create"
			_load_clans_data()
		)
		act_row.add_child(btn_go_create)
		vbox.add_child(no_card)

		# Incoming clan invitations
		var invs: Array = _my_clan_data.get("invitations", []) if typeof(_my_clan_data.get("invitations")) == TYPE_ARRAY else []
		if not invs.is_empty():
			vbox.add_child(_make_lbl("💌 دعوت‌نامه‌های کلن برای شما", 28, Color(0.55, 0.92, 0.68), true))
			for inv in invs:
				if typeof(inv) != TYPE_DICTIONARY:
					continue
				var icard = _make_card_panel()
				var irow = HBoxContainer.new()
				icard.add_child(irow)
				var c_sub = inv.get("clan", {}) if typeof(inv.get("clan")) == TYPE_DICTIONARY else {}
				var cname = str(c_sub.get("name", "کلن"))
				var ctag = str(c_sub.get("tag", ""))
				var lbl = _make_lbl("دعوت به کلن «%s» [%s]" % [cname, ctag], 26, Color(1.0, 0.94, 0.82))
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				irow.add_child(lbl)
				var inv_id = str(inv.get("invite_id", ""))
				var b_acc = _make_btn("✅ پیوستن", 120, 48)
				b_acc.pressed.connect(func():
					NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, _d: Variant):
						if ok:
							_show_toast("به کلن خوش آمدید!")
							_load_clans_data()
					)
				)
				irow.add_child(b_acc)
				vbox.add_child(icard)
		return

	# Active Clan Header Card
	var cid = str(clan.get("clan_id", ""))
	NetworkManager.join_clan_room_realtime(cid)
	var my_role = str(clan.get("my_role", "member"))
	var my_role_fa = str(clan.get("my_role_fa", "عضو"))

	var header_card = _make_card_panel(Color(0.18, 0.12, 0.06, 0.96), Color(0.95, 0.76, 0.28, 0.95))
	var hc_vbox = VBoxContainer.new()
	hc_vbox.add_theme_constant_override("separation", 8)
	header_card.add_child(hc_vbox)

	var top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	hc_vbox.add_child(top_bar)

	var title_lbl = _make_lbl("🛡️ %s  [%s]   —   سطح کلن: %s" % [
		str(clan.get("name", "")),
		str(clan.get("tag", "")),
		GameManager.to_fa_num(int(clan.get("clan_level", 1)))
	], 34, Color(1.0, 0.88, 0.36), true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title_lbl)

	var btn_challenge = _make_btn("⚔️ چالش دوستانه در کلن", 210, 50, Color(0.68, 0.44, 0.12), Color(1.0, 0.84, 0.36), 22)
	btn_challenge.pressed.connect(func():
		NetworkManager.api.create_clan_friendly_challenge("Monopoly", 2, func(ok: bool, _c: int, _d: Variant):
			if ok:
				_show_toast("چالش دوستانه در چت کلن اعلام شد!")
				current_clans_subtab = "chat"
				_load_clans_data()
		)
	)
	top_bar.add_child(btn_challenge)

	var btn_leave = _make_btn("🚪 خروج از کلن" if my_role != "leader" else "🗑️ انحلال کلن", 160, 50, Color(0.50, 0.16, 0.16), Color(0.92, 0.45, 0.45), 21)
	btn_leave.pressed.connect(func():
		if my_role == "leader":
			NetworkManager.api.disband_clan(func(ok: bool, _c: int, _d: Variant):
				if ok:
					_show_toast("کلن منحل شد.")
					_load_clans_data()
			)
		else:
			NetworkManager.api.leave_clan(func(ok: bool, _c: int, d: Variant):
				if ok:
					_show_toast("از کلن خارج شدید.")
					_load_clans_data()
				elif typeof(d) == TYPE_DICTIONARY:
					_show_toast(str(d.get("detail", "خطا")), Color(1.0, 0.55, 0.55))
			)
	)
	top_bar.add_child(btn_leave)

	hc_vbox.add_child(_make_lbl(str(clan.get("description", "بدون توضیحات")), 23, Color(0.92, 0.86, 0.78), false, true))
	hc_vbox.add_child(_make_lbl("🏆 امتیاز کل: %s  |  🔥 امتیاز هفتگی: %s  |  👥 اعضا: %s/%s  |  🎖️ سمت شما: %s" % [
		GameManager.to_fa_num(int(clan.get("clan_score", 0))),
		GameManager.to_fa_num(int(clan.get("weekly_score", 0))),
		GameManager.to_fa_num(int(clan.get("member_count", 1))),
		GameManager.to_fa_num(int(clan.get("max_members", 50))),
		my_role_fa
	], 23, Color(0.58, 0.92, 0.70)))
	vbox.add_child(header_card)

	# Weekly Clan Challenges
	var challenges: Array = clan.get("weekly_challenges", []) if typeof(clan.get("weekly_challenges")) == TYPE_ARRAY else []
	if not challenges.is_empty():
		vbox.add_child(_make_lbl("🎯 چالش‌های هفتگی کلن", 28, Color(1.0, 0.86, 0.38), true))
		for ch in challenges:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			var ch_card = _make_card_panel()
			var ch_row = HBoxContainer.new()
			ch_card.add_child(ch_row)
			var ch_title = _make_lbl("%s — %s (%s / %s)" % [
				str(ch.get("title", "")),
				str(ch.get("desc", "")),
				GameManager.to_fa_num(int(ch.get("progress", 0))),
				GameManager.to_fa_num(int(ch.get("target", 1)))
			], 22, Color(0.95, 0.92, 0.82))
			ch_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ch_row.add_child(ch_title)
			var done = bool(ch.get("completed", false))
			ch_row.add_child(_make_lbl("✅ تکمیل شد!" if done else "🎁 +%s XP کلن" % GameManager.to_fa_num(int(ch.get("reward_clan_xp", 150))), 22, Color(0.45, 0.95, 0.55) if done else Color(1.0, 0.84, 0.38)))
			vbox.add_child(ch_card)

	# Pending Join Requests (Visible to Elder / Co-Leader / Leader)
	var pending_reqs: Array = clan.get("pending_join_requests", []) if typeof(clan.get("pending_join_requests")) == TYPE_ARRAY else []
	if not pending_reqs.is_empty():
		vbox.add_child(_make_lbl("📩 درخواست‌های عضویت در کلن (%s)" % GameManager.to_fa_num(pending_reqs.size()), 28, Color(0.55, 0.92, 0.68), true))
		for req in pending_reqs:
			if typeof(req) != TYPE_DICTIONARY:
				continue
			var rcard = _make_card_panel()
			var rrow = HBoxContainer.new()
			rcard.add_child(rrow)
			var ru = req.get("user", {}) if typeof(req.get("user")) == TYPE_DICTIONARY else {}
			var rlbl = _make_lbl("%s (امتیاز: %s) — %s" % [
				str(ru.get("username", "بازیکن")),
				GameManager.to_fa_num(int(ru.get("score", 0))),
				str(req.get("message", ""))
			], 23)
			rlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rrow.add_child(rlbl)
			var rid = str(req.get("request_id", ""))
			var b_ok = _make_btn("✅ پذیرش", 110, 46)
			b_ok.pressed.connect(func():
				NetworkManager.api.respond_clan_join_request(rid, "accept", func(_ok: bool, _c: int, _d: Variant):
					_load_clans_data()
				)
			)
			rrow.add_child(b_ok)
			var b_no = _make_btn("❌ رد", 90, 46, Color(0.50, 0.16, 0.16), Color(0.90, 0.45, 0.45))
			b_no.pressed.connect(func():
				NetworkManager.api.respond_clan_join_request(rid, "reject", func(_ok: bool, _c: int, _d: Variant):
					_load_clans_data()
				)
			)
			rrow.add_child(b_no)
			vbox.add_child(rcard)

	# Clan Members List
	var members: Array = clan.get("members", []) if typeof(clan.get("members")) == TYPE_ARRAY else []
	vbox.add_child(_make_lbl("👥 اعضای کلن (%s نفر)" % GameManager.to_fa_num(members.size()), 28, Color(1.0, 0.88, 0.42), true))
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var mcard = _make_card_panel()
		var mrow = HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 12)
		mcard.add_child(mrow)

		var m_uid = str(m.get("user_id", ""))
		var m_name = str(m.get("username", "بازیکن"))
		var m_role = str(m.get("role", "member"))
		var m_role_fa = str(m.get("role_fa", "عضو"))
		var m_contrib = int(m.get("weekly_contribution", 0))
		var m_pres = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
		var p_badge = _format_presence_badge(m_pres)

		var m_info = VBoxContainer.new()
		m_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mrow.add_child(m_info)
		m_info.add_child(_make_lbl("%s   [%s]" % [m_name, m_role_fa], 26, Color(1.0, 0.95, 0.84), true))
		m_info.add_child(_make_lbl("🔥 مشارکت هفتگی: %s   |   🏆 امتیاز: %s   |   %s" % [
			GameManager.to_fa_num(m_contrib),
			GameManager.to_fa_num(int(m.get("score", 0))),
			p_badge["text"]
		], 21, p_badge["color"]))

		if m_uid != str(GameManager.get_user_id()) and my_role in ["leader", "co_leader", "elder"]:
			if my_role in ["leader", "co_leader"]:
				if m_role == "member":
					var b_prom = _make_btn("⬆️ ارتقا به ارشد", 145, 44, Color(0.22, 0.44, 0.56), Color(0.52, 0.82, 0.96), 20)
					b_prom.pressed.connect(func():
						NetworkManager.api.change_clan_member_role(m_uid, "elder", func(_ok: bool, _c: int, _d: Variant): _load_clans_data())
					)
					mrow.add_child(b_prom)
				elif m_role == "elder" and my_role == "leader":
					var b_prom2 = _make_btn("⬆️ معاون رهبر", 135, 44, Color(0.22, 0.44, 0.56), Color(0.52, 0.82, 0.96), 20)
					b_prom2.pressed.connect(func():
						NetworkManager.api.change_clan_member_role(m_uid, "co_leader", func(_ok: bool, _c: int, _d: Variant): _load_clans_data())
					)
					mrow.add_child(b_prom2)
				if m_role in ["elder", "co_leader"] and my_role == "leader":
					var b_dem = _make_btn("⬇️ تنزل", 95, 44, Color(0.42, 0.30, 0.16), Color(0.82, 0.64, 0.38), 20)
					b_dem.pressed.connect(func():
						var target_r = "member" if m_role == "elder" else "elder"
						NetworkManager.api.change_clan_member_role(m_uid, target_r, func(_ok: bool, _c: int, _d: Variant): _load_clans_data())
					)
					mrow.add_child(b_dem)

			if my_role == "leader":
				var b_lead = _make_btn("👑 انتقال رهبری", 145, 44, Color(0.62, 0.44, 0.12), Color(1.0, 0.84, 0.36), 20)
				b_lead.pressed.connect(func():
					NetworkManager.api.transfer_clan_leadership(m_uid, func(_ok: bool, _c: int, _d: Variant):
						_show_toast("رهبری کلن منتقل شد.")
						_load_clans_data()
					)
				)
				mrow.add_child(b_lead)

			var b_kick = _make_btn("اخراج", 90, 44, Color(0.50, 0.16, 0.16), Color(0.92, 0.45, 0.45), 20)
			b_kick.pressed.connect(func():
				NetworkManager.api.kick_clan_member(m_uid, func(_ok: bool, _c: int, _d: Variant):
					_show_toast("عضو از کلن اخراج شد.")
					_load_clans_data()
				)
			)
			mrow.add_child(b_kick)

		vbox.add_child(mcard)


func _build_clan_chat_view(body_box: VBoxContainer) -> void:
	_clan_chat_scroll = ScrollContainer.new()
	_clan_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clan_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_child(_clan_chat_scroll)

	_clan_chat_list_vbox = VBoxContainer.new()
	_clan_chat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clan_chat_list_vbox.add_theme_constant_override("separation", 8)
	_clan_chat_scroll.add_child(_clan_chat_list_vbox)

	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	body_box.add_child(input_row)

	_clan_chat_input = LineEdit.new()
	_clan_chat_input.placeholder_text = "پیام خود را برای کلن بنویسید (برای منشن از @نام استفاده کنید)..."
	_clan_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clan_chat_input.custom_minimum_size = Vector2(0, 54)
	_clan_chat_input.add_theme_font_override("font", FONT_BODY)
	_clan_chat_input.add_theme_font_size_override("font_size", 24)
	input_row.add_child(_clan_chat_input)

	var btn_send = _make_btn("📤 ارسال در کلن", 160, 54)
	btn_send.pressed.connect(_send_clan_chat_message)
	_clan_chat_input.text_submitted.connect(func(_t: String): _send_clan_chat_message())
	input_row.add_child(btn_send)

	NetworkManager.api.get_clan_chat_history("", func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			_clan_chat_messages = data["result"]
			_render_clan_chat_messages()
	)


func _send_clan_chat_message() -> void:
	if not is_instance_valid(_clan_chat_input):
		return
	var txt = _clan_chat_input.text.strip_edges()
	if txt.is_empty():
		return
	_clan_chat_input.text = ""
	if NetworkManager.is_online:
		NetworkManager.send_clan_chat_realtime(txt)
	else:
		NetworkManager.api.send_clan_chat_rest(txt, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				_clan_chat_messages.append(data["result"])
				_render_clan_chat_messages()
		)


func _render_clan_chat_messages() -> void:
	if not is_instance_valid(_clan_chat_list_vbox):
		return
	for c in _clan_chat_list_vbox.get_children():
		c.queue_free()

	if _clan_chat_messages.is_empty():
		_clan_chat_list_vbox.add_child(_make_lbl("هنوز پیامی در چت کلن ارسال نشده است.", 24, Color(0.75, 0.70, 0.64)))
		return

	var my_uid = str(GameManager.get_user_id())
	for msg in _clan_chat_messages:
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		var mtype = str(msg.get("msg_type", "text"))
		var sender_id = str(msg.get("sender_id", ""))
		var sender_name = str(msg.get("sender_name", "بازیکن"))
		var text = str(msg.get("text", ""))
		var msg_id = str(msg.get("message_id", ""))

		var bg = Color(0.18, 0.26, 0.18, 0.95) if sender_id == my_uid else Color(0.16, 0.11, 0.07, 0.94)
		if mtype != "text":
			bg = Color(0.26, 0.20, 0.08, 0.95)
		var card = _make_card_panel(bg, Color(0.65, 0.52, 0.28, 0.8))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)

		if mtype == "text":
			col.add_child(_make_lbl("%s (%s):" % [sender_name, str(msg.get("sender_role", "member"))], 21, Color(1.0, 0.86, 0.42), true))
		col.add_child(_make_lbl(text, 24, Color(0.98, 0.96, 0.90), false, true))

		if mtype == "friendly_challenge":
			var meta = msg.get("metadata", {}) if typeof(msg.get("metadata")) == TYPE_DICTIONARY else {}
			var chal_gt = str(meta.get("game_type", "Monopoly"))
			var chal_creator = str(meta.get("creator_id", ""))
			if chal_creator != my_uid and not chal_creator.is_empty():
				var btn_accept_chal = _make_btn("⚔️ قبول چالش", 140, 44)
				btn_accept_chal.pressed.connect(func():
					NetworkManager.send_game_invite_realtime(chal_creator, chal_gt, "direct_match")
					_show_toast("درخواست شروع بازی دوستانه ارسال شد!")
				)
				row.add_child(btn_accept_chal)

		if sender_id == my_uid:
			var btn_del = _make_btn("🗑️", 52, 42, Color(0.45, 0.16, 0.16), Color(0.85, 0.42, 0.42), 18)
			btn_del.pressed.connect(func():
				NetworkManager.api.delete_clan_chat_message(msg_id, func(ok: bool, _c: int, _d: Variant):
					if ok:
						_clan_chat_messages = _clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != msg_id)
						_render_clan_chat_messages()
				)
			)
			row.add_child(btn_del)

		_clan_chat_list_vbox.add_child(card)


func _build_clan_search_view(body_box: VBoxContainer) -> void:
	var s_row = HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 10)
	body_box.add_child(s_row)

	var inp = LineEdit.new()
	inp.placeholder_text = "جستجوی نام یا تگ کلن (مثلاً #CAFE)..."
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp.custom_minimum_size = Vector2(0, 52)
	inp.add_theme_font_override("font", FONT_BODY)
	inp.add_theme_font_size_override("font_size", 24)
	s_row.add_child(inp)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var res_vbox = VBoxContainer.new()
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(res_vbox)

	var do_search = func():
		NetworkManager.api.search_clans(inp.text.strip_edges(), "", "clan_score", func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(res_vbox):
				return
			for ch in res_vbox.get_children():
				ch.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				var arr: Array = data["result"]
				if arr.is_empty():
					res_vbox.add_child(_make_lbl("کلنی یافت نشد.", 24, Color(0.80, 0.75, 0.68)))
				for cl in arr:
					if typeof(cl) != TYPE_DICTIONARY:
						continue
					var ccard = _make_card_panel()
					var crow = HBoxContainer.new()
					ccard.add_child(crow)
					var cinfo = VBoxContainer.new()
					cinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					crow.add_child(cinfo)
					var cid = str(cl.get("clan_id", ""))
					var jtype = str(cl.get("join_type", "open"))
					var jtype_fa = "آزاد" if jtype == "open" else ("درخواستی" if jtype == "request" else "فقط با دعوت")
					cinfo.add_child(_make_lbl("🛡️ %s  [%s]   —   سطح %s" % [
						str(cl.get("name", "")),
						str(cl.get("tag", "")),
						GameManager.to_fa_num(int(cl.get("clan_level", 1)))
					], 28, Color(1.0, 0.88, 0.38), true))
					cinfo.add_child(_make_lbl("🏆 امتیاز: %s  |  👥 اعضا: %s/%s  |  نوع عضویت: %s" % [
						GameManager.to_fa_num(int(cl.get("clan_score", 0))),
						GameManager.to_fa_num(int(cl.get("member_count", 1))),
						GameManager.to_fa_num(int(cl.get("max_members", 50))),
						jtype_fa
					], 22, Color(0.82, 0.88, 0.78)))
					if jtype != "invite_only":
						var b_join = _make_btn("➕ عضویت" if jtype == "open" else "📩 درخواست عضویت", 165, 48)
						b_join.pressed.connect(func():
							NetworkManager.api.join_or_request_clan(cid, "درخواست عضویت در کلن", func(ok_j: bool, _cj: int, dj: Variant):
								if ok_j:
									_show_toast("انجام شد!")
									current_clans_subtab = "my_clan"
									_load_clans_data()
								elif typeof(dj) == TYPE_DICTIONARY:
									_show_toast(str(dj.get("detail", "خطا")), Color(1.0, 0.55, 0.55))
							)
						)
						crow.add_child(b_join)
					res_vbox.add_child(ccard)
		)

	var btn_s = _make_btn("🔍 جستجو", 140, 52)
	btn_s.pressed.connect(do_search)
	s_row.add_child(btn_s)
	body_box.add_child(scroll)
	do_search.call()


func _build_clan_create_view(body_box: VBoxContainer) -> void:
	var card = _make_card_panel()
	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	card.add_child(form)
	body_box.add_child(card)

	form.add_child(_make_lbl("➕ ساخت کلن جدید در کافه فکر (رایگان — هر بازیکن حداکثر ۱ کلن)", 30, Color(1.0, 0.88, 0.38), true))

	var inp_name = LineEdit.new()
	inp_name.placeholder_text = "نام کلن (۳ تا ۲۸ حرف، مثلاً: قهرمانان کافه فکر)"
	inp_name.custom_minimum_size = Vector2(0, 52)
	inp_name.add_theme_font_override("font", FONT_BODY)
	inp_name.add_theme_font_size_override("font_size", 24)
	form.add_child(inp_name)

	var inp_tag = LineEdit.new()
	inp_tag.placeholder_text = "تگ یکتای کلن (۳ تا ۶ کاراکتر انگلیسی/عدد، مثلاً: CAFE1)"
	inp_tag.custom_minimum_size = Vector2(0, 52)
	inp_tag.add_theme_font_override("font", FONT_BODY)
	inp_tag.add_theme_font_size_override("font_size", 24)
	form.add_child(inp_tag)

	var inp_desc = LineEdit.new()
	inp_desc.placeholder_text = "توضیحات و قوانین کلن..."
	inp_desc.custom_minimum_size = Vector2(0, 52)
	inp_desc.add_theme_font_override("font", FONT_BODY)
	inp_desc.add_theme_font_size_override("font_size", 24)
	form.add_child(inp_desc)

	var join_type_val = ["open"]
	var jt_row = HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 10)
	form.add_child(jt_row)
	jt_row.add_child(_make_lbl("نوع عضویت:", 24))

	var btn_jt_open = _make_btn("آزاد (Open)", 150, 48)
	var btn_jt_req = _make_btn("با تایید (Request)", 180, 48, Color(0.24, 0.20, 0.16), Color(0.65, 0.52, 0.32))
	btn_jt_open.pressed.connect(func():
		join_type_val[0] = "open"
		_show_toast("نوع عضویت: آزاد")
	)
	btn_jt_req.pressed.connect(func():
		join_type_val[0] = "request"
		_show_toast("نوع عضویت: نیازمند تایید")
	)
	jt_row.add_child(btn_jt_open)
	jt_row.add_child(btn_jt_req)

	var btn_submit = _make_btn("🛡️ تاسیس کلن (رایگان)", 260, 58, Color(0.72, 0.48, 0.12), Color(1.0, 0.86, 0.38), 26)
	btn_submit.pressed.connect(func():
		var payload = {
			"name": inp_name.text.strip_edges(),
			"tag": inp_tag.text.strip_edges(),
			"description": inp_desc.text.strip_edges(),
			"emblem_id": 1,
			"language": "fa",
			"join_type": join_type_val[0],
			"min_score": 0,
			"min_level": 1
		}
		NetworkManager.api.create_clan(payload, func(ok: bool, _c: int, data: Variant):
			if ok:
				_show_toast("🎉 کلن شما با موفقیت تاسیس شد!")
				current_clans_subtab = "my_clan"
				_load_clans_data()
			elif typeof(data) == TYPE_DICTIONARY:
				_show_toast(str(data.get("detail", "خطا در ساخت کلن")), Color(1.0, 0.55, 0.55))
		)
	)
	form.add_child(btn_submit)


func _build_clan_leaderboard_view(body_box: VBoxContainer) -> void:
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 10)
	body_box.add_child(mode_row)

	var modes = [
		{"id": "clans", "label": "🏆 کل امتیاز کلن‌ها"},
		{"id": "clans_weekly", "label": "🔥 برترین‌های هفته"},
		{"id": "clans_monthly", "label": "📅 برترین‌های ماه"}
	]
	for m in modes:
		var mid = m["id"]
		var act = (current_clan_lb_mode == mid)
		var b = _make_btn(m["label"], 0, 48, Color(0.68, 0.46, 0.12) if act else Color(0.18, 0.12, 0.08), Color(1.0, 0.84, 0.36) if act else Color(0.55, 0.42, 0.24), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			current_clan_lb_mode = mid
			_load_clans_data()
		)
		mode_row.add_child(b)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_child(scroll)

	var lb_vbox = VBoxContainer.new()
	lb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(lb_vbox)

	NetworkManager.api.get_social_leaderboard(current_clan_lb_mode, "", "", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(lb_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var arr: Array = data["result"]
			if arr.is_empty():
				lb_vbox.add_child(_make_lbl("هنوز کلنی در جدول رتبه‌بندی ثبت نشده است.", 24, Color(0.80, 0.75, 0.68)))
			for item in arr:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var card = _make_card_panel()
				var row = HBoxContainer.new()
				card.add_child(row)
				var rnk = int(item.get("rank", 1))
				var lbl_r = _make_lbl("#%s   🛡️ %s [%s]" % [
					GameManager.to_fa_num(rnk),
					str(item.get("name", "")),
					str(item.get("tag", ""))
				], 28, Color(1.0, 0.88, 0.38), true)
				lbl_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl_r)
				row.add_child(_make_lbl("🏆 امتیاز: %s   |   👥 %s/%s" % [
					GameManager.to_fa_num(int(item.get("clan_score", 0))),
					GameManager.to_fa_num(int(item.get("member_count", 1))),
					GameManager.to_fa_num(int(item.get("max_members", 50)))
				], 23, Color(0.55, 0.92, 0.68)))
				lb_vbox.add_child(card)
	)


# ==============================================================================
# TAB 3: DIRECT MESSAGES (1-TO-1 CHAT)
# ==============================================================================

func _load_messages_data() -> void:
	var root = _clear_content()
	var split = HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	root.add_child(split)

	# Left column: Conversations list
	var conv_panel = _make_card_panel()
	conv_panel.custom_minimum_size = Vector2(310, 0)
	conv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(conv_panel)

	var conv_vbox = VBoxContainer.new()
	conv_vbox.add_theme_constant_override("separation", 8)
	conv_panel.add_child(conv_vbox)
	conv_vbox.add_child(_make_lbl("💬 گفتگوهای خصوصی", 28, Color(1.0, 0.88, 0.38), true))

	var conv_scroll = ScrollContainer.new()
	conv_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conv_vbox.add_child(conv_scroll)

	var conv_list_box = VBoxContainer.new()
	conv_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conv_list_box.add_theme_constant_override("separation", 6)
	conv_scroll.add_child(conv_list_box)

	# Right column: Active DM thread
	var chat_panel = _make_card_panel()
	chat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(chat_panel)

	var chat_vbox = VBoxContainer.new()
	chat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_vbox.add_theme_constant_override("separation", 10)
	chat_panel.add_child(chat_vbox)

	var chat_header = HBoxContainer.new()
	chat_vbox.add_child(chat_header)
	var partner_title = _make_lbl(
		"گفتگو با: %s" % _active_dm_partner_name if not _active_dm_partner_id.is_empty() else "یک گفتگو را از لیست انتخاب کنید",
		28, Color(1.0, 0.88, 0.42), true
	)
	partner_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_header.add_child(partner_title)

	if not _active_dm_partner_id.is_empty():
		var btn_inv_dm = _make_btn("⚔️ دعوت به بازی", 150, 46)
		btn_inv_dm.pressed.connect(func():
			_open_game_invite_modal(_active_dm_partner_id, _active_dm_partner_name)
		)
		chat_header.add_child(btn_inv_dm)

	_dm_messages_scroll = ScrollContainer.new()
	_dm_messages_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_vbox.add_child(_dm_messages_scroll)

	_dm_messages_vbox = VBoxContainer.new()
	_dm_messages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_messages_vbox.add_theme_constant_override("separation", 8)
	_dm_messages_scroll.add_child(_dm_messages_vbox)

	var dm_input_row = HBoxContainer.new()
	dm_input_row.add_theme_constant_override("separation", 8)
	chat_vbox.add_child(dm_input_row)

	_dm_input = LineEdit.new()
	_dm_input.placeholder_text = "پیام خصوصی خود را بنویسید..."
	_dm_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dm_input.custom_minimum_size = Vector2(0, 52)
	_dm_input.add_theme_font_override("font", FONT_BODY)
	_dm_input.add_theme_font_size_override("font_size", 24)
	dm_input_row.add_child(_dm_input)

	var btn_send_dm = _make_btn("📤 ارسال", 130, 52)
	btn_send_dm.pressed.connect(_send_active_dm)
	_dm_input.text_submitted.connect(func(_t: String): _send_active_dm())
	dm_input_row.add_child(btn_send_dm)

	NetworkManager.api.get_conversations_list(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(conv_list_box):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			_conversations = data["result"]
			for conv in _conversations:
				if typeof(conv) != TYPE_DICTIONARY:
					continue
				var partner = conv.get("partner", {}) if typeof(conv.get("partner")) == TYPE_DICTIONARY else {}
				var pid = str(partner.get("user_id", ""))
				var pname = str(partner.get("username", "بازیکن"))
				var unread = int(conv.get("unread_count", 0))
				var btn_c = _make_btn(
					"%s%s" % [pname, " (%s)" % GameManager.to_fa_num(unread) if unread > 0 else ""],
					0, 50,
					Color(0.28, 0.48, 0.34) if pid == _active_dm_partner_id else Color(0.18, 0.12, 0.08),
					Color(0.65, 0.92, 0.68) if pid == _active_dm_partner_id else Color(0.50, 0.38, 0.24),
					22
				)
				btn_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn_c.pressed.connect(func():
					_active_dm_partner_id = pid
					_active_dm_partner_name = pname
					_load_messages_data()
				)
				conv_list_box.add_child(btn_c)
	)

	if not _active_dm_partner_id.is_empty():
		NetworkManager.api.get_direct_messages(_active_dm_partner_id, func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var res = data["result"]
				_active_dm_messages = res.get("messages", []) if typeof(res.get("messages")) == TYPE_ARRAY else []
				NetworkManager.unread_dms_count = max(0, NetworkManager.unread_dms_count - 1)
				_update_main_tab_buttons()
				_render_active_dm_messages()
		)


func _send_active_dm() -> void:
	if _active_dm_partner_id.is_empty() or not is_instance_valid(_dm_input):
		return
	var txt = _dm_input.text.strip_edges()
	if txt.is_empty():
		return
	_dm_input.text = ""
	NetworkManager.api.send_direct_message_rest(_active_dm_partner_id, txt, func(ok: bool, _c: int, data: Variant):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			_active_dm_messages.append(data["result"])
			_render_active_dm_messages()
		elif typeof(data) == TYPE_DICTIONARY:
			_show_toast(str(data.get("detail", "خطا در ارسال پیام")), Color(1.0, 0.55, 0.55))
	)


func _render_active_dm_messages() -> void:
	if not is_instance_valid(_dm_messages_vbox):
		return
	for c in _dm_messages_vbox.get_children():
		c.queue_free()
	var my_uid = str(GameManager.get_user_id())
	for m in _active_dm_messages:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var from_me = (str(m.get("from_user_id", "")) == my_uid)
		var bg = Color(0.18, 0.34, 0.22, 0.96) if from_me else Color(0.18, 0.13, 0.09, 0.96)
		var card = _make_card_panel(bg, Color(0.58, 0.78, 0.58, 0.85) if from_me else Color(0.62, 0.48, 0.30, 0.85))
		var vbox = VBoxContainer.new()
		card.add_child(vbox)
		var sender_lbl = "شما" if from_me else _active_dm_partner_name
		var read_mark = ("  ✓✓" if bool(m.get("is_read", false)) else "  ✓") if from_me else ""
		vbox.add_child(_make_lbl(sender_lbl + read_mark, 19, Color(0.85, 0.92, 0.78)))
		vbox.add_child(_make_lbl(str(m.get("text", "")), 24, Color(1.0, 0.98, 0.94), false, true))
		_dm_messages_vbox.add_child(card)


# ==============================================================================
# TAB 4: SOCIAL NOTIFICATIONS & PREFERENCES
# ==============================================================================

func _load_notifications_data() -> void:
	var root = _clear_content()
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root.add_child(top_row)

	var lbl_t = _make_lbl("🔔 مرکز اعلان‌های اجتماعی", 30, Color(1.0, 0.88, 0.38), true)
	lbl_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lbl_t)

	var btn_read_all = _make_btn("✓ خواندن همه اعلان‌ها", 210, 50)
	btn_read_all.pressed.connect(func():
		NetworkManager.api.mark_all_notifications_read(func(ok: bool, _c: int, _d: Variant):
			if ok:
				NetworkManager.unread_notifications_count = 0
				_update_main_tab_buttons()
				_load_notifications_data()
		)
	)
	top_row.add_child(btn_read_all)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var n_vbox = VBoxContainer.new()
	n_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(n_vbox)

	NetworkManager.api.get_notifications_list(false, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(n_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			NetworkManager.unread_notifications_count = int(res.get("unread_count", 0))
			_update_main_tab_buttons()
			var items: Array = res.get("items", []) if typeof(res.get("items")) == TYPE_ARRAY else []
			if items.is_empty():
				n_vbox.add_child(_make_lbl("اعلانی برای نمایش وجود ندارد.", 24, Color(0.78, 0.74, 0.68)))
			for n in items:
				if typeof(n) != TYPE_DICTIONARY:
					continue
				var is_read = bool(n.get("is_read", false))
				var ncard = _make_card_panel(
					Color(0.15, 0.10, 0.06, 0.92) if is_read else Color(0.22, 0.16, 0.08, 0.98),
					Color(0.55, 0.42, 0.25, 0.75) if is_read else Color(1.0, 0.84, 0.36, 0.95)
				)
				var nrow = HBoxContainer.new()
				ncard.add_child(nrow)
				var ncol = VBoxContainer.new()
				ncol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				nrow.add_child(ncol)
				ncol.add_child(_make_lbl(str(n.get("title", "اعلان")), 25, Color(1.0, 0.90, 0.42), true))
				ncol.add_child(_make_lbl(str(n.get("body", "")), 22, Color(0.95, 0.92, 0.86), false, true))
				if not is_read:
					var nid = str(n.get("notification_id", ""))
					var b_mark = _make_btn("✓ خواندم", 110, 44)
					b_mark.pressed.connect(func():
						NetworkManager.api.mark_notification_read(nid, func(_ok: bool, _c2: int, _d2: Variant):
							_load_notifications_data()
						)
					)
					nrow.add_child(b_mark)
				n_vbox.add_child(ncard)
	)


# ==============================================================================
# TAB 5: MY SOCIAL PROFILE CUSTOMIZATION & PRIVACY SETTINGS
# ==============================================================================

func _load_privacy_profile_data() -> void:
	var root = _clear_content()
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var card = _make_card_panel()
	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	card.add_child(form)
	vbox.add_child(card)

	form.add_child(_make_lbl("🎖️ شخصی‌سازی پروفایل اجتماعی و حریم خصوصی", 30, Color(1.0, 0.88, 0.38), true))

	var inp_title = LineEdit.new()
	inp_title.placeholder_text = "عنوان افتخاری پروفایل (مثلاً: استاد منچ و مونوپولی)"
	inp_title.custom_minimum_size = Vector2(0, 52)
	inp_title.add_theme_font_override("font", FONT_BODY)
	inp_title.add_theme_font_size_override("font_size", 24)
	form.add_child(inp_title)

	var inp_status = LineEdit.new()
	inp_status.placeholder_text = "پیام وضعیت شخصی (Status Message)..."
	inp_status.custom_minimum_size = Vector2(0, 52)
	inp_status.add_theme_font_override("font", FONT_BODY)
	inp_status.add_theme_font_size_override("font_size", 24)
	form.add_child(inp_status)

	var priv_state = {
		"allow_friend_requests": true,
		"allow_dms": "everyone",
		"show_last_seen": true,
		"show_active_game": true,
		"show_match_history": true
	}

	var chk_freq = CheckBox.new()
	chk_freq.text = "اجازه دریافت درخواست دوستی از بازیکنان"
	chk_freq.button_pressed = true
	chk_freq.add_theme_font_override("font", FONT_BODY)
	chk_freq.add_theme_font_size_override("font_size", 23)
	form.add_child(chk_freq)

	var chk_last_seen = CheckBox.new()
	chk_last_seen.text = "نمایش وضعیت آنلاین و آخرین بازدید به دیگران"
	chk_last_seen.button_pressed = true
	chk_last_seen.add_theme_font_override("font", FONT_BODY)
	chk_last_seen.add_theme_font_size_override("font_size", 23)
	form.add_child(chk_last_seen)

	var chk_active_game = CheckBox.new()
	chk_active_game.text = "نمایش بازی در حال انجام و امکان تماشای مسابقه توسط دوستان"
	chk_active_game.button_pressed = true
	chk_active_game.add_theme_font_override("font", FONT_BODY)
	chk_active_game.add_theme_font_size_override("font_size", 23)
	form.add_child(chk_active_game)

	var btn_save = _make_btn("💾 ذخیره تنظیمات پروفایل و حریم خصوصی", 320, 56)
	btn_save.pressed.connect(func():
		priv_state["allow_friend_requests"] = chk_freq.button_pressed
		priv_state["show_last_seen"] = chk_last_seen.button_pressed
		priv_state["show_active_game"] = chk_active_game.button_pressed
		NetworkManager.api.customize_my_profile({
			"profile_title": inp_title.text.strip_edges(),
			"status_message": inp_status.text.strip_edges(),
			"privacy": priv_state
		}, func(ok: bool, _c: int, _d: Variant):
			if ok:
				_show_toast("✅ تنظیمات پروفایل و حریم خصوصی ذخیره شد!")
		)
	)
	form.add_child(btn_save)


# ==============================================================================
# GAME INVITATION SELECTOR MODAL
# ==============================================================================

func _open_game_invite_modal(target_uid: String, target_name: String) -> void:
	if is_instance_valid(_invite_modal):
		_invite_modal.queue_free()

	_invite_modal = Control.new()
	_invite_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_invite_modal)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_invite_modal.queue_free()
	)
	_invite_modal.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_invite_modal.add_child(center)

	var card = _make_card_panel(Color(0.14, 0.09, 0.05, 0.99), Color(0.95, 0.78, 0.32, 1.0))
	card.custom_minimum_size = Vector2(540, 420)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	vbox.add_child(_make_lbl("⚔️ دعوت «%s» به مسابقه دوستانه" % target_name, 30, Color(1.0, 0.88, 0.38), true))
	vbox.add_child(_make_lbl("بازی مورد نظر خود را برای ارسال دعوت‌نامه انتخاب کنید:", 23))

	var games_grid = GridContainer.new()
	games_grid.columns = 2
	games_grid.add_theme_constant_override("h_separation", 10)
	games_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(games_grid)

	var popular_games = [
		{"id": "Monopoly", "title": "🎩 مونوپولی"},
		{"id": "Ludo", "title": "🎲 منچ (لودو)"},
		{"id": "Backgammon", "title": "⚪ تخته نرد"},
		{"id": "Chess", "title": "♟️ شطرنج"},
		{"id": "Coup", "title": "🎭 کودتا (Coup)"},
		{"id": "Uno", "title": "🃏 اونو (Uno)"},
		{"id": "Battleship", "title": "🚢 نبرد دریایی"},
		{"id": "TicTacToe", "title": "❌ دوز"}
	]
	for g in popular_games:
		var gid = g["id"]
		var b = _make_btn(g["title"], 230, 52)
		b.pressed.connect(func():
			if NetworkManager.is_online:
				NetworkManager.send_game_invite_realtime(target_uid, gid, "direct_match")
			else:
				NetworkManager.api.send_game_invitation_rest(target_uid, gid, "direct_match")
			_show_toast("🎮 دعوت‌نامه بازی «%s» برای %s ارسال شد!" % [g["title"], target_name])
			if is_instance_valid(_invite_modal):
				_invite_modal.queue_free()
		)
		games_grid.add_child(b)

	var btn_cancel = _make_btn("انصراف", 160, 48, Color(0.48, 0.16, 0.16), Color(0.88, 0.42, 0.42))
	btn_cancel.pressed.connect(func():
		if is_instance_valid(_invite_modal):
			_invite_modal.queue_free()
	)
	vbox.add_child(btn_cancel)


# ==============================================================================
# REAL-TIME EVENT HANDLERS
# ==============================================================================

func _on_realtime_presence_changed(payload: Dictionary) -> void:
	if not visible:
		return
	var uid = str(payload.get("user_id", ""))
	for f in _friends_list:
		if typeof(f) == TYPE_DICTIONARY and str(f.get("user_id", "")) == uid:
			f["presence"] = payload
	if current_main_tab == "friends" and current_friends_subtab == "list":
		_load_friends_data()


func _on_realtime_dm_received(payload: Dictionary) -> void:
	_update_main_tab_buttons()
	if not visible or current_main_tab != "messages":
		return
	var fid = str(payload.get("from_user_id", ""))
	var tid = str(payload.get("to_user_id", ""))
	if fid == _active_dm_partner_id or tid == _active_dm_partner_id:
		_active_dm_messages.append(payload)
		_render_active_dm_messages()


func _on_realtime_clan_chat_received(payload: Dictionary) -> void:
	if not visible or current_main_tab != "clans" or current_clans_subtab != "chat":
		return
	_clan_chat_messages.append(payload)
	_render_clan_chat_messages()


func _on_realtime_clan_chat_deleted(payload: Dictionary) -> void:
	var mid = str(payload.get("message_id", ""))
	_clan_chat_messages = _clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != mid)
	if visible and current_main_tab == "clans" and current_clans_subtab == "chat":
		_render_clan_chat_messages()


func _on_realtime_clan_event(_payload: Dictionary) -> void:
	if visible and current_main_tab == "clans" and current_clans_subtab == "my_clan":
		_load_clans_data()


func _on_realtime_notification_received(_payload: Dictionary) -> void:
	_update_main_tab_buttons()
	if visible and current_main_tab == "notifs":
		_load_notifications_data()
