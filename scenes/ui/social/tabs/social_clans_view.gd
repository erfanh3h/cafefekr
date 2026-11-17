class_name SocialClansView
extends RefCounted

## Cafe Fekr — Complete Clan & Social System UI Redesign
##
## Implements a unified, luxurious antique board-game social experience:
## 1. Shared Clan Header & 3-Tab Navigation (Messages, Clan Overview, Members)
## 2. Redesigned Clan Chat with rich bubbles, sticker drawer, system events & game challenge cards
## 3. Clan Overview with Clan Identity hero plaque, XP progress, actions, weekly challenges & activity feed
## 4. Clan Members directory with 4-stat metric strip, real-time search, role filtering & member interactions sheet
## 5. Clan Discovery, Leaderboard & Free Clan Creation for non-members and browsing

# ------------------------------------------------------------------------------
# CONSTANTS & ASSETS
# ------------------------------------------------------------------------------

const ROLE_RANKS: Dictionary = {
	"leader": 4,
	"co_leader": 3,
	"elder": 2,
	"member": 1,
}

const ROLE_FA_MAP: Dictionary = {
	"leader": "رهبر اتحاد",
	"co_leader": "قائم‌مقام",
	"elder": "ارشد",
	"member": "عضو",
	"system": "سیستم",
}

# ------------------------------------------------------------------------------
# PRIMARY RENDER ENTRY POINT
# ------------------------------------------------------------------------------

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	var has_clan := _check_user_has_clan(host)

	# Ensure current subtab is valid
	var valid_tabs: Array[String] = []
	if has_clan:
		valid_tabs = ["my_clan", "chat", "members", "discover", "leaderboard"]
		if not host.current_clans_subtab in valid_tabs:
			host.current_clans_subtab = "my_clan"
	else:
		valid_tabs = ["my_clan", "discover", "leaderboard"]
		if not host.current_clans_subtab in valid_tabs:
			host.current_clans_subtab = "my_clan"

	# 1. Shared Header
	var header_box := _build_shared_header(host, has_clan)
	body_vbox.add_child(header_box)

	# 2. Shared Clan Navigation Tabs
	var tabs_bar := _build_clan_navigation_tabs(host, has_clan)
	body_vbox.add_child(tabs_bar)

	# 3. Content Area Holder
	var content_holder := VBoxContainer.new()
	content_holder.name = "ClanContentHolder"
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_theme_constant_override("separation", 10)
	body_vbox.add_child(content_holder)

	# Handle routing
	if not has_clan:
		if host.current_clans_subtab == "my_clan":
			_build_no_clan_overview(host, content_holder)
		elif host.current_clans_subtab == "leaderboard":
			_build_clan_leaderboard_inner(host, content_holder)
		else:
			_build_clan_search_inner(host, content_holder)
		return

	# User is in a clan
	if host.current_clans_subtab == "chat":
		_build_clan_chat_view(host, content_holder)
	elif host.current_clans_subtab in ["discover", "leaderboard"]:
		_build_clan_discover_view(host, content_holder)
	elif host.current_clans_subtab in ["my_clan", "members"]:
		var clan_dict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
		if clan_dict.is_empty():
			content_holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اطلاعات اتحاد..."))
			NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
				if not is_instance_valid(content_holder):
					return
				for ch in content_holder.get_children():
					ch.queue_free()
				if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
					host._my_clan_data = data["result"]
					var fresh_clan: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
					if host.current_clans_subtab == "members":
						_build_clan_members_tab(host, content_holder, fresh_clan)
					else:
						_build_clan_overview_tab(host, content_holder, fresh_clan)
				else:
					content_holder.add_child(CafeSocialTheme.make_empty_state(
						CafeSocialTheme.ICO_INFO,
						"خطا در دریافت اطلاعات اتحاد",
						"لطفاً اتصال خود را بررسی کرده و دوباره تلاش کنید.",
						"تلاش مجدد", "gold", func(): host._refresh_current_tab()
					))
			)
		else:
			if host.current_clans_subtab == "members":
				_build_clan_members_tab(host, content_holder, clan_dict)
			else:
				_build_clan_overview_tab(host, content_holder, clan_dict)


static func _check_user_has_clan(host: Control) -> bool:
	if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY and not host._my_clan_data["clan"].is_empty():
		return true
	if GameManager.user_data.has("clan") and typeof(GameManager.user_data["clan"]) == TYPE_DICTIONARY and not GameManager.user_data["clan"].is_empty():
		return true
	if GameManager.user_data.has("clan_id") and not str(GameManager.user_data["clan_id"]).is_empty():
		return true
	return false


# ==============================================================================
# 1. SHARED CLAN HEADER & NAVIGATION
# ==============================================================================

static func _build_shared_header(host: Control, has_clan: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var bg_st := StyleBoxFlat.new()
	bg_st.bg_color = Color(0.12, 0.08, 0.04, 0.96)
	bg_st.border_color = Color(0.72, 0.54, 0.24, 0.70)
	bg_st.set_border_width_all(1)
	bg_st.set_corner_radius_all(14)
	bg_st.shadow_color = Color(0, 0, 0, 0.40)
	bg_st.shadow_size = 6
	bg_st.shadow_offset = Vector2(0, 2)
	bg_st.content_margin_left = 14.0
	bg_st.content_margin_right = 14.0
	bg_st.content_margin_top = 8.0
	bg_st.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", bg_st)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	if not has_clan:
		var left_col := VBoxContainer.new()
		left_col.alignment = BoxContainer.ALIGNMENT_CENTER
		left_col.add_theme_constant_override("separation", 2)
		hbox.add_child(left_col)

		var b_create_quick := CafeSocialTheme.make_button("تاسیس اتحاد", "gold", Vector2(120, 42), 19)
		b_create_quick.pressed.connect(func():
			AudioManager.sfx_button()
			open_clan_create_modal(host)
		)
		left_col.add_child(b_create_quick)

		var title_col := VBoxContainer.new()
		title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_col.alignment = BoxContainer.ALIGNMENT_CENTER
		title_col.add_theme_constant_override("separation", 2)
		hbox.add_child(title_col)

		title_col.add_child(CafeSocialTheme.make_title("اتحادهای کافه فکر", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))
		title_col.add_child(CafeSocialTheme.make_body("باشگاه اجتماعی، چالش‌های هفتگی و مسابقات گروهی", 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

		hbox.add_child(CafeSocialTheme.make_clan_emblem(1, 56.0))
		return card

	# Has Clan
	var cdict: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var cname := str(cdict.get("name", "اتحاد من"))
	var ctag := str(cdict.get("tag", ""))
	var emb_id := int(cdict.get("emblem_id", 1))
	var clvl := int(cdict.get("clan_level", 1))
	var my_role_fa := str(cdict.get("my_role_fa", "عضو"))
	var mem_cnt := int(cdict.get("member_count", 1))
	var max_mem := int(cdict.get("max_members", 40))

	# Calculate online members count
	var online_cnt := 0
	var members_arr: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
	for m in members_arr:
		if typeof(m) == TYPE_DICTIONARY:
			var pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
			var st_str := str(pres.get("status", "offline"))
			if st_str in ["online", "in_game", "in_lobby", "in_queue"]:
				online_cnt += 1
	if online_cnt == 0:
		online_cnt = 1

	# Left utilities (Leaderboards shortcut + Online pill)
	var left_box := VBoxContainer.new()
	left_box.alignment = BoxContainer.ALIGNMENT_CENTER
	left_box.add_theme_constant_override("separation", 4)
	hbox.add_child(left_box)

	var b_lb := CafeSocialTheme.make_button("رتبه‌بندی", "bronze", Vector2(100, 36), 18, CafeSocialTheme.ICO_CUP, false, 10)
	b_lb.tooltip_text = "مشاهده جدول برترین اتحادها"
	b_lb.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "leaderboard"
		host._refresh_current_tab()
	)
	left_box.add_child(b_lb)

	var online_pill := CafeSocialTheme.make_badge_pill(
		"%s آنلاین" % GameManager.to_fa_num(online_cnt),
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		16
	)
	left_box.add_child(online_pill)

	# Center clan info
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 2)
	hbox.add_child(center_col)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 6)
	center_col.add_child(name_row)

	if not ctag.is_empty():
		var tag_lbl := CafeSocialTheme.make_body("[%s]" % ctag, 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
		name_row.add_child(tag_lbl)

	var name_lbl := CafeSocialTheme.make_title(cname, 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_lbl)

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_END
	meta_row.add_theme_constant_override("separation", 6)
	center_col.add_child(meta_row)

	meta_row.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(clvl), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 16))
	meta_row.add_child(CafeSocialTheme.make_badge_pill(my_role_fa, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 16))
	meta_row.add_child(CafeSocialTheme.make_body("%s/%s عضو" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false))

	# Right Emblem
	hbox.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 62.0))
	return card


static func _build_clan_navigation_tabs(host: Control, has_clan: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var tabs: Array[Dictionary] = []
	if has_clan:
		tabs = [
			{"id": "chat", "label": "پیام‌ها", "icon": null},
			{"id": "my_clan", "label": "اتحاد", "icon": null},
			{"id": "members", "label": "اعضا", "icon": null},
		]
	else:
		tabs = [
			{"id": "my_clan", "label": "معرفی و دعوت‌ها", "icon": null},
			{"id": "discover", "label": "جستجو و فهرست", "icon": null},
			{"id": "leaderboard", "label": "برترین اتحادها", "icon": null},
		]

	for td in tabs:
		var tid: String = td["id"]
		var is_active: bool = (host.current_clans_subtab == tid)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var st_norm := StyleBoxFlat.new()
		st_norm.set_corner_radius_all(12)
		st_norm.content_margin_left = 10.0
		st_norm.content_margin_right = 10.0
		st_norm.content_margin_top = 6.0
		st_norm.content_margin_bottom = 6.0

		if is_active:
			st_norm.bg_color = Color(0.14, 0.38, 0.23, 0.98) # Emerald
			st_norm.border_color = Color(0.92, 0.76, 0.32, 0.95) # Gold
			st_norm.set_border_width_all(2)
			st_norm.border_width_bottom = 4
			st_norm.shadow_color = Color(0, 0, 0, 0.40)
			st_norm.shadow_size = 5
		else:
			st_norm.bg_color = Color(0.14, 0.09, 0.05, 0.90) # Dark Walnut
			st_norm.border_color = Color(0.48, 0.36, 0.20, 0.65) # Bronze
			st_norm.set_border_width_all(1)

		btn.add_theme_stylebox_override("normal", st_norm)
		btn.add_theme_stylebox_override("hover", st_norm)
		btn.add_theme_stylebox_override("pressed", st_norm)

		# Tab contents: icon + label
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 8)
		btn.add_child(h)

		var lbl := Label.new()
		lbl.text = td["label"]
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		lbl.add_theme_font_size_override("font_size", 23)
		lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY if is_active else Color(0.82, 0.76, 0.68, 0.85))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("shadow_outline_size", 2)
		h.add_child(lbl)

		var tex: Texture2D = td.get("icon", null)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(26, 26)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.modulate = Color(1, 1, 1, 1) if is_active else Color(0.80, 0.74, 0.65, 0.80)
			h.add_child(tr)

		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_clans_subtab = tid
			host._refresh_current_tab()
		)
		row.add_child(btn)

	return panel


# ==============================================================================
# 2. CLAN CHAT – MESSAGES TAB
# ==============================================================================

static func _is_scroll_near_bottom(scroll: ScrollContainer) -> bool:
	if not is_instance_valid(scroll):
		return false
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if not bar:
		return true
	var max_scroll := bar.max_value - bar.page
	if max_scroll <= 0:
		return true
	return (scroll.scroll_vertical >= max_scroll - 160.0)


static func _scroll_clan_chat_to_bottom_smooth(host: Control) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host._clan_chat_scroll):
		return
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if is_instance_valid(host._clan_chat_scroll):
		var bar: VScrollBar = host._clan_chat_scroll.get_v_scroll_bar()
		if bar:
			host._clan_chat_scroll.scroll_vertical = int(bar.max_value)


static func _build_clan_chat_view(host: Control, holder: VBoxContainer) -> void:
	# A. Scroll Container for Chat Stream (top header box removed as requested)
	var chat_well := PanelContainer.new()
	chat_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well_st := StyleBoxFlat.new()
	well_st.bg_color = Color(0.08, 0.05, 0.03, 0.88)
	well_st.border_color = Color(0.40, 0.28, 0.16, 0.60)
	well_st.set_border_width_all(1)
	well_st.set_corner_radius_all(14)
	well_st.content_margin_left = 12.0
	well_st.content_margin_right = 12.0
	well_st.content_margin_top = 10.0
	well_st.content_margin_bottom = 10.0
	chat_well.add_theme_stylebox_override("panel", well_st)
	holder.add_child(chat_well)

	host._clan_chat_scroll = ScrollContainer.new()
	host._clan_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_well.add_child(host._clan_chat_scroll)

	host._clan_chat_list_vbox = VBoxContainer.new()
	host._clan_chat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_list_vbox.add_theme_constant_override("separation", 10)
	host._clan_chat_scroll.add_child(host._clan_chat_list_vbox)

	# If cached messages exist, render immediately to avoid 1-second disappearance flicker!
	if not host._clan_chat_messages.is_empty():
		_populate_all_clan_chat_messages(host)
		_scroll_clan_chat_to_bottom_smooth(host)
	else:
		host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت گفتگوهای اتحاد..."))

	# B. Chat Input Composer (docked at bottom)
	var composer := PanelContainer.new()
	composer.custom_minimum_size = Vector2(0, 84)
	var comp_st := StyleBoxFlat.new()
	comp_st.bg_color = Color(0.12, 0.08, 0.04, 0.98)
	comp_st.border_color = Color(0.60, 0.45, 0.22, 0.75)
	comp_st.set_border_width_all(1)
	comp_st.set_corner_radius_all(14)
	comp_st.shadow_color = Color(0, 0, 0, 0.40)
	comp_st.shadow_size = 6
	comp_st.shadow_offset = Vector2(0, -2)
	comp_st.content_margin_left = 10.0
	comp_st.content_margin_right = 10.0
	comp_st.content_margin_top = 8.0
	comp_st.content_margin_bottom = 8.0
	composer.add_theme_stylebox_override("panel", comp_st)
	holder.add_child(composer)

	var inp_row := HBoxContainer.new()
	inp_row.add_theme_constant_override("separation", 8)
	inp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	composer.add_child(inp_row)

	# Send Button (icon send.png)
	var btn_send := TextureButton.new()
	btn_send.texture_normal = preload("res://assets/images/send.png")
	btn_send.custom_minimum_size = Vector2(54, 54)
	btn_send.ignore_texture_size = true
	btn_send.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_send.focus_mode = Control.FOCUS_NONE
	btn_send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_send.tooltip_text = "ارسال پیام"
	ActionVFXManager.apply_button_juice(btn_send, "tap_button")
	btn_send.pressed.connect(func():
		AudioManager.sfx_tap()
		host._send_clan_chat_message()
	)
	inp_row.add_child(btn_send)

	# Text Input
	host._clan_chat_input = CafeSocialTheme.make_line_edit("پیام خود را بنویسید (از @ برای منشن استفاده کنید)...", 52.0, 22)
	host._clan_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inp_row.add_child(host._clan_chat_input)

	# Sticker Drawer Toggle Button (clean icon without background shadow)
	var btn_sticker := TextureButton.new()
	btn_sticker.texture_normal = CafeSocialTheme.BADGE_SOCIAL
	btn_sticker.custom_minimum_size = Vector2(50, 50)
	btn_sticker.ignore_texture_size = true
	btn_sticker.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_sticker.focus_mode = Control.FOCUS_NONE
	btn_sticker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_sticker.tooltip_text = "ارسال استیکر"
	ActionVFXManager.apply_button_juice(btn_sticker, "tap_button")
	btn_sticker.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_sticker_picker(host)
	)
	inp_row.add_child(btn_sticker)

	# Friendly Challenge Shortcut Button (icon game.png)
	var btn_chal := TextureButton.new()
	btn_chal.texture_normal = preload("res://assets/images/game.png")
	btn_chal.custom_minimum_size = Vector2(54, 54)
	btn_chal.ignore_texture_size = true
	btn_chal.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_chal.focus_mode = Control.FOCUS_NONE
	btn_chal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_chal.tooltip_text = "ایجاد چالش دوستانه در اتحاد"
	ActionVFXManager.apply_button_juice(btn_chal, "tap_button")
	btn_chal.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friendly_challenge_modal(host)
	)
	inp_row.add_child(btn_chal)

	host._clan_chat_input.text_submitted.connect(func(_t: String): host._send_clan_chat_message())

	# Load chat history
	NetworkManager.api.get_clan_chat_history("", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host._clan_chat_list_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var fresh_arr: Array = data["result"]
			if host._clan_chat_messages.is_empty():
				for ch in host._clan_chat_list_vbox.get_children():
					ch.queue_free()
				host._clan_chat_messages = fresh_arr
				_populate_all_clan_chat_messages(host)
				_scroll_clan_chat_to_bottom_smooth(host)
			else:
				# Incremental sync: Only insert new messages at the end, DO NOT wipe existing ones!
				var existing_ids: Dictionary = {}
				for m in host._clan_chat_messages:
					if typeof(m) == TYPE_DICTIONARY:
						var mid := str(m.get("message_id", m.get("_id", "")))
						if not mid.is_empty():
							existing_ids[mid] = true

				var new_msgs: Array = []
				for fm in fresh_arr:
					if typeof(fm) == TYPE_DICTIONARY:
						var fmid := str(fm.get("message_id", fm.get("_id", "")))
						if fmid.is_empty() or not existing_ids.has(fmid):
							new_msgs.append(fm)
							if not fmid.is_empty():
								existing_ids[fmid] = true

				for nm in new_msgs:
					host._clan_chat_messages.append(nm)
					append_clan_chat_message(host, nm)
		else:
			if host._clan_chat_messages.is_empty():
				for ch in host._clan_chat_list_vbox.get_children():
					ch.queue_free()
				host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.BADGE_CHAT,
					"هنوز پیامی ثبت نشده است",
					"اولین پیام یا چالش دوستانه را برای هم‌تیمی‌های خود ارسال کنید!"
				))
	)


static func render_clan_chat(host: Control) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	var was_near_bottom: bool = _is_scroll_near_bottom(host._clan_chat_scroll)
	for c in host._clan_chat_list_vbox.get_children():
		c.queue_free()
	_populate_all_clan_chat_messages(host)
	if was_near_bottom:
		_scroll_clan_chat_to_bottom_smooth(host)


static func _populate_all_clan_chat_messages(host: Control) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	if host._clan_chat_messages.is_empty():
		host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.BADGE_CHAT,
			"هنوز پیامی ارسال نشده است",
			"اولین پیام، استیکر یا چالش دوستانه را در چت اتحاد ثبت کنید!"
		))
		return

	var my_uid := str(GameManager.get_user_id())
	var clan_d: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var my_role := str(clan_d.get("my_role", "member"))

	for msg in host._clan_chat_messages:
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		var bubble := _build_single_chat_bubble(host, msg, my_uid, my_role)
		if bubble != null:
			host._clan_chat_list_vbox.add_child(bubble)


static func append_clan_chat_message(host: Control, msg: Dictionary) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return

	# Remove empty state or loading state placeholder if present
	for ch in host._clan_chat_list_vbox.get_children():
		if ch.name in ["EmptyState", "LoadingState"] or (ch is PanelContainer and (ch.has_node("EmptyStateVBox") or ch.has_node("LoadingVBox"))):
			ch.queue_free()

	var my_uid := str(GameManager.get_user_id())
	var clan_d: Dictionary = host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}
	var my_role := str(clan_d.get("my_role", "member"))

	var is_mine := (str(msg.get("sender_id", "")) == my_uid)
	var was_near_bottom: bool = _is_scroll_near_bottom(host._clan_chat_scroll)

	var bubble := _build_single_chat_bubble(host, msg, my_uid, my_role)
	if bubble != null:
		host._clan_chat_list_vbox.add_child(bubble)

	# Auto-scroll only if message is mine OR user was already near bottom
	if is_mine or was_near_bottom:
		_scroll_clan_chat_to_bottom_smooth(host)


static func _build_single_chat_bubble(host: Control, msg: Dictionary, my_uid: String, my_role: String) -> Control:
	var mtype := str(msg.get("msg_type", "text"))
	var sender_id := str(msg.get("sender_id", ""))
	var sender_name := str(msg.get("sender_name", "بازیکن"))
	var sender_role := str(msg.get("sender_role", "member"))
	var sender_img := int(msg.get("sender_image", 0))
	var sender_frame := int(msg.get("sender_profile_frame", msg.get("profile_frame", 1)))
	var text := str(msg.get("text", ""))
	var msg_id := str(msg.get("message_id", msg.get("_id", "")))
	var time_str := CafeSocialTheme.format_time_fa(str(msg.get("created_at", "")))
	var is_mine := (sender_id == my_uid)

	var is_challenge_msg: bool = (mtype == "friendly_challenge") or (mtype == "system" and typeof(msg.get("metadata")) == TYPE_DICTIONARY and msg["metadata"].has("challenge_id"))
	if is_challenge_msg:
		var meta_check: Dictionary = msg.get("metadata", {}) if typeof(msg.get("metadata")) == TYPE_DICTIONARY else {}
		var chal_st: String = str(meta_check.get("status", "open"))
		if chal_st in ["closed", "finished", "canceled", "cancelled"]:
			return null
		return _build_challenge_chat_bubble(host, meta_check, text, my_uid, my_role)

	# --- A. SYSTEM MESSAGES ---
	if mtype == "system":
		return _build_system_chat_bubble(text, time_str)

	# --- B. STANDARD CHAT BUBBLE (Text / Sticker) ---
	var msg_row := HBoxContainer.new()
	msg_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	msg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_row.add_theme_constant_override("separation", 10)

	# Avatar component (with click -> profile)
	var av_btn := Button.new()
	av_btn.flat = true
	av_btn.focus_mode = Control.FOCUS_NONE
	av_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	av_btn.custom_minimum_size = Vector2(58, 58)
	var av_badge := CafeSocialTheme.make_avatar_badge(sender_img, sender_frame, 56.0)
	av_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_btn.add_child(av_badge)
	av_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		UserProfileDialog.show_user({"user_id": sender_id, "username": sender_name, "image": sender_img, "profile_frame": sender_frame}, ROLE_FA_MAP.get(sender_role, "عضو"), host)
	)

	var bubble_col := VBoxContainer.new()
	bubble_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_col.size_flags_stretch_ratio = 0.82
	bubble_col.add_theme_constant_override("separation", 3)

	# Header above bubble: Username + Role Pill (For user's own message: aligned to top-right)
	var hdr_row := HBoxContainer.new()
	hdr_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_theme_constant_override("separation", 6)
	bubble_col.add_child(hdr_row)

	var role_title: String = ROLE_FA_MAP.get(sender_role, "عضو")
	var role_badge := CafeSocialTheme.make_badge_pill(
		role_title,
		CafeSocialTheme.COL_GOLD_BRIGHT if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if sender_role in ["co_leader", "elder"] else CafeSocialTheme.COL_MUTED_SAND),
		Color(0.18, 0.12, 0.05) if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_BG if sender_role in ["co_leader", "elder"] else Color(0.11, 0.07, 0.04)),
		CafeSocialTheme.COL_GOLD_ANTIQUE if sender_role == "leader" else (CafeSocialTheme.COL_EMERALD_BORDER if sender_role in ["co_leader", "elder"] else CafeSocialTheme.COL_BRONZE_BORDER),
		15
	)

	var uname_lbl := CafeSocialTheme.make_title(
		sender_name if not is_mine else "شما",
		20,
		CafeSocialTheme.COL_EMERALD_TEXT if is_mine else CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT if is_mine else HORIZONTAL_ALIGNMENT_LEFT,
		false
	)

	if is_mine:
		hdr_row.alignment = BoxContainer.ALIGNMENT_END
		hdr_row.add_child(role_badge)
		hdr_row.add_child(uname_lbl)
	else:
		hdr_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		hdr_row.add_child(uname_lbl)
		hdr_row.add_child(role_badge)

	# Delete button as little icon button with delete.png
	var del_icon_btn: TextureButton = null
	if (is_mine or my_role in ["leader", "co_leader", "elder"]) and not msg_id.is_empty():
		del_icon_btn = TextureButton.new()
		del_icon_btn.texture_normal = preload("res://assets/images/delete.png")
		del_icon_btn.custom_minimum_size = Vector2(30, 30)
		del_icon_btn.ignore_texture_size = true
		del_icon_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		del_icon_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del_icon_btn.focus_mode = Control.FOCUS_NONE
		del_icon_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		del_icon_btn.tooltip_text = "حذف پیام"
		ActionVFXManager.apply_button_juice(del_icon_btn, "tap_button")
		del_icon_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.delete_clan_chat_message(msg_id, func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._clan_chat_messages = host._clan_chat_messages.filter(func(x): return str(x.get("message_id", x.get("_id", ""))) != msg_id)
					if is_instance_valid(msg_row):
						msg_row.queue_free()
			)
		)

	# Bubble Frame (my chat frame vs others frame)
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(220, 96)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.add_theme_stylebox_override("panel", CafeSocialTheme.create_chat_bubble_style(is_mine))
	bubble_col.add_child(bubble)

	var b_vbox := VBoxContainer.new()
	b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_vbox.add_theme_constant_override("separation", 4)
	bubble.add_child(b_vbox)

	# Check if text is a sticker e.g. [استیکر X] or [sticker:X]
	var is_sticker := false
	var sticker_id := 0
	if text.begins_with("[sticker:") and text.ends_with("]"):
		sticker_id = int(text.substr(9, text.length() - 10))
		is_sticker = true
	elif text.begins_with("[استیکر ") and text.ends_with("]"):
		sticker_id = int(text.substr(9, text.length() - 10))
		is_sticker = true

	if is_sticker and sticker_id >= 1 and sticker_id <= 16:
		var s_tex: Texture2D = load("res://assets/icons/Reactions/%d.png" % sticker_id)
		if s_tex != null:
			var s_rect := TextureRect.new()
			s_rect.texture = s_tex
			s_rect.custom_minimum_size = Vector2(88, 88)
			s_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			s_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			s_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b_vbox.add_child(s_rect)
	else:
		var msg_lbl := Label.new()
		msg_lbl.text = text
		msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		msg_lbl.add_theme_font_size_override("font_size", 22)
		if is_mine:
			msg_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		else:
			msg_lbl.add_theme_color_override("font_color", Color(0.24, 0.15, 0.06, 1.0))
		b_vbox.add_child(msg_lbl)

	if not time_str.is_empty():
		var date_lbl := Label.new()
		date_lbl.text = time_str
		date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_mine else HORIZONTAL_ALIGNMENT_RIGHT
		date_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		date_lbl.add_theme_font_size_override("font_size", 16)
		if is_mine:
			date_lbl.add_theme_color_override("font_color", Color(0.80, 0.95, 0.85, 0.90))
		else:
			date_lbl.add_theme_color_override("font_color", Color(0.42, 0.32, 0.20, 0.90))
		b_vbox.add_child(date_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 0.18

	if is_mine:
		msg_row.add_child(spacer)
		if del_icon_btn != null:
			msg_row.add_child(del_icon_btn)
		msg_row.add_child(bubble_col)
		msg_row.add_child(av_btn)
	else:
		msg_row.add_child(av_btn)
		msg_row.add_child(bubble_col)
		if del_icon_btn != null:
			msg_row.add_child(del_icon_btn)
		msg_row.add_child(spacer)

	return msg_row


static func _build_system_chat_bubble(text: String, time_str: String = "") -> PanelContainer:
	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.90)
	st.border_color = Color(0.68, 0.50, 0.22, 0.60)
	st.set_border_width_all(1)
	st.set_corner_radius_all(12)
	st.content_margin_left = 14.0
	st.content_margin_right = 14.0
	st.content_margin_top = 6.0
	st.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", st)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	pill.add_child(h)

	var ico := TextureRect.new()
	ico.texture = CafeSocialTheme.ICO_SPARKLE
	ico.custom_minimum_size = Vector2(22, 22)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.modulate = CafeSocialTheme.COL_GOLD_BRIGHT
	h.add_child(ico)

	var full_txt := text
	if not time_str.is_empty():
		full_txt += " (%s)" % time_str
	var lbl := CafeSocialTheme.make_body(full_txt, 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	h.add_child(lbl)

	return pill


static func _build_challenge_chat_bubble(host: Control, meta: Dictionary, desc_text: String, my_uid: String, my_role: String) -> PanelContainer:
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	st.border_color = Color(0.92, 0.74, 0.30, 0.90)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 6
	st.content_margin_left = 14.0
	st.content_margin_right = 14.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", st)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(top_row)

	var chal_gt: String = str(meta.get("game_type", "Monopoly"))
	var chal_thumb := CafeSocialTheme.get_game_thumb(chal_gt)
	if chal_thumb != null:
		var tr := TextureRect.new()
		tr.texture = chal_thumb
		tr.custom_minimum_size = Vector2(56, 56)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		top_row.add_child(tr)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	top_row.add_child(col)

	var gt_fa: String = str(meta.get("game_title_fa", GameRegistry.get_display_name_fa(chal_gt)))
	col.add_child(CafeSocialTheme.make_title("چالش دوستانه %s" % gt_fa, 23, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false))
	col.add_child(CafeSocialTheme.make_body(desc_text, 18, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var chal_act := _build_challenge_action_row(host, meta, my_uid, my_role, true)
	if chal_act != null:
		v.add_child(chal_act)

	return card


static func _open_sticker_picker(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 60

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.70)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	var top_r := HBoxContainer.new()
	vbox.add_child(top_r)

	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(44, 44)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func(): overlay.queue_free())
	top_r.add_child(bx)

	var ttl := CafeSocialTheme.make_title("ارسال استیکر و واکنش به اتحاد", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_r.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 44)
	top_r.add_child(sp)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for sid in range(1, 17):
		var s_btn := Button.new()
		s_btn.custom_minimum_size = Vector2(120, 110)
		s_btn.focus_mode = Control.FOCUS_NONE
		s_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		s_btn.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(Color(0.12, 0.08, 0.04), CafeSocialTheme.COL_BRONZE_BORDER, 12, 1, 6.0, 6.0))
		s_btn.add_theme_stylebox_override("hover", CafeSocialTheme.create_card_style(Color(0.22, 0.15, 0.08), CafeSocialTheme.COL_GOLD_BRIGHT, 12, 2, 6.0, 6.0))

		var s_tex: Texture2D = load("res://assets/icons/Reactions/%d.png" % sid)
		if s_tex != null:
			var tr := TextureRect.new()
			tr.texture = s_tex
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_btn.add_child(tr)

		var chosen_id := sid
		s_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			overlay.queue_free()
			var sticker_text := "[sticker:%d]" % chosen_id
			if is_instance_valid(host._clan_chat_input):
				host._clan_chat_input.text = sticker_text
				host._send_clan_chat_message()
		)
		grid.add_child(s_btn)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


# ==============================================================================
# 3. CLAN OVERVIEW – MAIN CLAN TAB
# ==============================================================================

static func _build_clan_overview_tab(host: Control, holder: VBoxContainer, cdict: Dictionary) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	var my_role := str(cdict.get("my_role", "member"))
	var my_role_fa := str(cdict.get("my_role_fa", "عضو"))
	var my_uid := str(GameManager.get_user_id())

	# Join clan room in realtime for live events
	var cid := str(cdict.get("clan_id", cdict.get("_id", "")))
	if not cid.is_empty():
		NetworkManager.join_clan_room_realtime(cid)

	# --------------------------------------------------------------------------
	# A. CLAN IDENTITY HERO CARD
	# --------------------------------------------------------------------------
	var hero_card := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.14, 0.09, 0.05, 0.98)
	h_sb.border_color = Color(0.85, 0.68, 0.30, 0.90)
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(16)
	h_sb.shadow_color = Color(0, 0, 0, 0.45)
	h_sb.shadow_size = 8
	h_sb.shadow_offset = Vector2(0, 3)
	h_sb.content_margin_left = 18.0
	h_sb.content_margin_right = 18.0
	h_sb.content_margin_top = 16.0
	h_sb.content_margin_bottom = 16.0
	hero_card.add_theme_stylebox_override("panel", h_sb)
	vbox.add_child(hero_card)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero_card.add_child(hv)

	# Top Identity Row: Badges / Info / Large Crest
	var top_id_row := HBoxContainer.new()
	top_id_row.add_theme_constant_override("separation", 14)
	hv.add_child(top_id_row)

	# Left Column: Badges & Leader name
	var left_id := VBoxContainer.new()
	left_id.alignment = BoxContainer.ALIGNMENT_CENTER
	left_id.add_theme_constant_override("separation", 6)
	top_id_row.add_child(left_id)

	var clvl := int(cdict.get("clan_level", 1))
	left_id.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(clvl), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.20, 0.13, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 20))
	left_id.add_child(CafeSocialTheme.make_badge_pill("سمت: %s" % my_role_fa, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 19))

	var leader_name := str(cdict.get("leader_name", ""))
	if leader_name.is_empty():
		var mems_check: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
		for m in mems_check:
			if typeof(m) == TYPE_DICTIONARY and str(m.get("role", "")) == "leader":
				leader_name = str(m.get("username", ""))
				break
	if not leader_name.is_empty():
		left_id.add_child(CafeSocialTheme.make_badge_pill("👑 %s" % leader_name, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.12, 0.07, 0.04), CafeSocialTheme.COL_BRONZE_BORDER, 17))

	# Center Column: Clan Name & Description
	var center_id := VBoxContainer.new()
	center_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_id.alignment = BoxContainer.ALIGNMENT_CENTER
	center_id.add_theme_constant_override("separation", 4)
	top_id_row.add_child(center_id)

	var full_name := "%s  [%s]" % [str(cdict.get("name", "اتحاد")), str(cdict.get("tag", ""))]
	center_id.add_child(CafeSocialTheme.make_title(full_name, 32, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var desc := str(cdict.get("description", "")).strip_edges()
	center_id.add_child(CafeSocialTheme.make_body(desc if not desc.is_empty() else "باشگاه اختصاصی بازیکنان کافه فکر", 21, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Right Column: Large Emblem
	var emb_id := int(cdict.get("emblem_id", 1))
	top_id_row.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 88.0))

	# Clan XP Progress Bar
	var cxp := int(cdict.get("clan_xp", 0))
	var next_xp: int = maxi(100, clvl * 500)
	var xp_ratio: float = float(cxp % next_xp) / float(next_xp)
	hv.add_child(CafeSocialTheme.make_xp_progress_bar(
		xp_ratio,
		"تجربه اتحاد: %s / %s XP" % [GameManager.to_fa_num(cxp % next_xp), GameManager.to_fa_num(next_xp)],
		Color(0.88, 0.70, 0.24)
	))

	# 3-Stat Strip (icons removed as requested)
	var stat_strip := HBoxContainer.new()
	stat_strip.add_theme_constant_override("separation", 8)
	hv.add_child(stat_strip)

	var st1 := CafeSocialTheme.make_metric_card("امتیاز کل اتحاد", GameManager.to_fa_num(int(cdict.get("clan_score", 0))), CafeSocialTheme.COL_GOLD_BRIGHT, null)
	st1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st1)

	var st2 := CafeSocialTheme.make_metric_card("فعالیت هفتگی", GameManager.to_fa_num(int(cdict.get("weekly_score", 0))), CafeSocialTheme.COL_EMERALD_TEXT, null)
	st2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st2)

	var st3 := CafeSocialTheme.make_metric_card("ظرفیت اعضا", "%s / %s" % [GameManager.to_fa_num(int(cdict.get("member_count", 1))), GameManager.to_fa_num(int(cdict.get("max_members", 40)))], CafeSocialTheme.COL_IVORY, null)
	st3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_strip.add_child(st3)

	# --------------------------------------------------------------------------
	# B. MAIN CLAN ACTIONS (Challenge Friends / Leave Clan / Settings)
	# --------------------------------------------------------------------------
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	vbox.add_child(act_row)

	var b_leave := CafeSocialTheme.make_button("انحلال اتحاد" if my_role == "leader" else "خروج از اتحاد", "crimson", Vector2(0, 54), 23)
	b_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_leave.pressed.connect(func():
		if my_role == "leader":
			CafeSocialTheme.show_confirm_modal(
				host, "انحلال اتحاد",
				"آیا مطمئن هستید می‌خواهید اتحاد «%s» را منحل کنید؟ تمام اعضای اتحاد خارج خواهند شد." % str(cdict.get("name", "")),
				"بله، منحل شود", true,
				func():
					NetworkManager.api.disband_clan(func(ok: bool, _c: int, d: Variant):
						if ok:
							host._show_toast("اتحاد منحل شد.")
							host.current_clans_subtab = "my_clan"
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا در انحلال")), CafeSocialTheme.COL_CRIMSON_TEXT)
					)
			)
		else:
			CafeSocialTheme.show_confirm_modal(
				host, "خروج از اتحاد",
				"آیا می‌خواهید از اتحاد «%s» خارج شوید؟" % str(cdict.get("name", "")),
				"خروج از اتحاد", true,
				func():
					NetworkManager.api.leave_clan(func(ok: bool, _c: int, d: Variant):
						if ok:
							host._show_toast("از اتحاد خارج شدید.")
							host.current_clans_subtab = "my_clan"
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
					)
			)
	)
	act_row.add_child(b_leave)

	if my_role in ["leader", "co_leader"]:
		var b_settings := CafeSocialTheme.make_button("تنظیمات اتحاد", "bronze", Vector2(0, 54), 23)
		b_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_settings.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_clan_settings_modal(host, cdict)
		)
		act_row.add_child(b_settings)

	var b_challenge := CafeSocialTheme.make_button("چالش دوستانه", "emerald", Vector2(0, 54), 24, CafeSocialTheme.ICO_LOBBY, true)
	b_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_challenge.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friendly_challenge_modal(host)
	)
	act_row.add_child(b_challenge)

	# --------------------------------------------------------------------------
	# C. ACTIVE FRIENDLY CHALLENGES
	# --------------------------------------------------------------------------
	var open_chals_raw: Variant = cdict.get("open_challenges", host._my_clan_data.get("open_challenges", []))
	var open_chals: Array = open_chals_raw if typeof(open_chals_raw) == TYPE_ARRAY else []
	if not open_chals.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های دوستانه فعال", CafeSocialTheme.ICO_LOBBY, "%s چالش باز در انتظار هم‌تیمی" % GameManager.to_fa_num(open_chals.size())
		))
		for ch_item in open_chals:
			if typeof(ch_item) == TYPE_DICTIONARY:
				vbox.add_child(_build_overview_challenge_card(host, ch_item, my_uid, my_role))

	# --------------------------------------------------------------------------
	# D. WEEKLY CLAN CHALLENGES (icon removed as requested)
	# --------------------------------------------------------------------------
	var challenges: Array = cdict.get("weekly_challenges", []) if typeof(cdict.get("weekly_challenges")) == TYPE_ARRAY else []
	if not challenges.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های هفتگی اتحاد", null, "همکاری اعضای اتحاد برای دریافت XP و ارتقای سطح"
		))
		for ch in challenges:
			if typeof(ch) == TYPE_DICTIONARY:
				vbox.add_child(_build_weekly_challenge_card(ch))

	# --------------------------------------------------------------------------
	# E. PENDING JOIN REQUESTS (Elder+)
	# --------------------------------------------------------------------------
	var pending_reqs: Array = cdict.get("pending_join_requests", []) if typeof(cdict.get("pending_join_requests")) == TYPE_ARRAY else []
	if not pending_reqs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"درخواست‌های عضویت در اتحاد", CafeSocialTheme.ICO_STAR, "%s درخواست در انتظار بررسی" % GameManager.to_fa_num(pending_reqs.size())
		))
		for req in pending_reqs:
			if typeof(req) == TYPE_DICTIONARY:
				vbox.add_child(_build_join_request_card(host, req))

	# --------------------------------------------------------------------------
	# F. RECENT CLAN ACTIVITY TIMELINE
	# --------------------------------------------------------------------------
	var audit_logs: Array = cdict.get("audit_logs", host._my_clan_data.get("audit_logs", [])) if typeof(cdict.get("audit_logs", host._my_clan_data.get("audit_logs", []))) == TYPE_ARRAY else []
	if not audit_logs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"رویدادها و فعالیت‌های اخیر اتحاد", CafeSocialTheme.ICO_HISTORY, "ثبت خودکار پیوستن، ارتقای درجه و دستاوردهای اعضا"
		))
		var act_card := PanelContainer.new()
		var ac_st := StyleBoxFlat.new()
		ac_st.bg_color = Color(0.12, 0.08, 0.04, 0.95)
		ac_st.border_color = Color(0.50, 0.36, 0.20, 0.65)
		ac_st.set_border_width_all(1)
		ac_st.set_corner_radius_all(14)
		ac_st.content_margin_left = 14.0
		ac_st.content_margin_right = 14.0
		ac_st.content_margin_top = 10.0
		ac_st.content_margin_bottom = 10.0
		act_card.add_theme_stylebox_override("panel", ac_st)
		vbox.add_child(act_card)

		var ac_vbox := VBoxContainer.new()
		ac_vbox.add_theme_constant_override("separation", 8)
		act_card.add_child(ac_vbox)

		for entry in audit_logs.slice(0, 6):
			if typeof(entry) == TYPE_DICTIONARY:
				ac_vbox.add_child(_build_activity_entry_row(entry))


static func _build_weekly_challenge_card(ch: Dictionary) -> PanelContainer:
	var ch_card := PanelContainer.new()
	var done := bool(ch.get("completed", false))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.24, 0.16, 0.96) if done else Color(0.15, 0.10, 0.06, 0.96)
	sb.border_color = Color(0.42, 0.85, 0.55, 0.92) if done else Color(0.72, 0.54, 0.24, 0.70)
	sb.set_border_width_all(2 if done else 1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	ch_card.add_theme_stylebox_override("panel", sb)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	ch_card.add_child(cv)

	var cr := HBoxContainer.new()
	cv.add_child(cr)

	var xp_reward := int(ch.get("reward_clan_xp", 150))
	var pill := CafeSocialTheme.make_badge_pill(
		"تکمیل شد!" if done else "+%s XP اتحاد" % GameManager.to_fa_num(xp_reward),
		CafeSocialTheme.COL_EMERALD_TEXT if done else CafeSocialTheme.COL_GOLD_BRIGHT,
		CafeSocialTheme.COL_EMERALD_BG if done else Color(0.18, 0.11, 0.04),
		CafeSocialTheme.COL_EMERALD_BORDER if done else CafeSocialTheme.COL_GOLD_ANTIQUE,
		18
	)
	cr.add_child(pill)

	var ct := CafeSocialTheme.make_title(str(ch.get("title", "")), 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(ct)

	cv.add_child(CafeSocialTheme.make_body(str(ch.get("desc", "")), 20, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var prog := int(ch.get("progress", 0))
	var targ: int = maxi(1, int(ch.get("target", 1)))
	cv.add_child(CafeSocialTheme.make_xp_progress_bar(
		float(prog) / float(targ),
		"%s از %s" % [GameManager.to_fa_num(prog), GameManager.to_fa_num(targ)],
		Color(0.38, 0.88, 0.54) if done else Color(0.88, 0.68, 0.24)
	))
	return ch_card


static func _build_join_request_card(host: Control, req: Dictionary) -> PanelContainer:
	var ru: Dictionary = req.get("user", {}) if typeof(req.get("user")) == TYPE_DICTIONARY else {}
	var rid := str(req.get("request_id", ""))
	var rcard := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.10, 0.06, 0.95)
	sb.border_color = Color(0.65, 0.48, 0.24, 0.70)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	rcard.add_theme_stylebox_override("panel", sb)

	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 10)
	rcard.add_child(rrow)

	var b_no := CafeSocialTheme.make_button("رد", "crimson", Vector2(88, 44), 20)
	b_no.pressed.connect(func():
		NetworkManager.api.respond_clan_join_request(rid, "reject", func(_ok, _c, _d): host._refresh_current_tab())
	)
	rrow.add_child(b_no)

	var b_ok := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(110, 44), 20)
	b_ok.pressed.connect(func():
		NetworkManager.api.respond_clan_join_request(rid, "accept", func(ok: bool, _c: int, _d: Variant):
			if ok:
				host._show_toast("عضو جدید به اتحاد پیوست!")
			host._refresh_current_tab()
		)
	)
	rrow.add_child(b_ok)

	var rcol := VBoxContainer.new()
	rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(rcol)
	rcol.add_child(CafeSocialTheme.make_title(str(ru.get("username", "بازیکن")), 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
	var msg_txt := str(req.get("message", ""))
	rcol.add_child(CafeSocialTheme.make_body("امتیاز: %s  %s" % [GameManager.to_fa_num(int(ru.get("score", 0))), msg_txt], 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	rrow.add_child(CafeSocialTheme.make_avatar_badge(int(ru.get("image", 0)), int(ru.get("profile_frame", 1)), 60.0))
	return rcard


static func _build_activity_entry_row(entry: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)

	var act := str(entry.get("action", ""))
	var text_desc := ""
	var act_col := CafeSocialTheme.COL_WARM_CREAM
	var act_ico: Texture2D = CafeSocialTheme.ICO_SPARKLE

	match act:
		"member_joined", "join_accepted":
			text_desc = "عضو جدید به جمع اعضای اتحاد پیوست"
			act_col = CafeSocialTheme.COL_EMERALD_TEXT
			act_ico = CafeSocialTheme.ICO_STAR
		"member_left":
			text_desc = "یکی از اعضا از اتحاد خارج شد"
			act_col = CafeSocialTheme.COL_CRIMSON_TEXT
		"member_kicked":
			text_desc = "یکی از اعضا توسط مدیر از اتحاد اخراج شد"
			act_col = CafeSocialTheme.COL_CRIMSON_TEXT
		"role_changed", "member_promoted":
			text_desc = "درجه و مسئولیت یکی از اعضای اتحاد تغییر یافت"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
			act_ico = CafeSocialTheme.ICO_KING
		"leadership_transferred":
			text_desc = "رهبری اتحاد با موفقیت منتقل گردید"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
			act_ico = CafeSocialTheme.ICO_KING
		"clan_created":
			text_desc = "اتحاد رسماً تاسیس شد"
			act_col = CafeSocialTheme.COL_GOLD_BRIGHT
		_:
			text_desc = "رویداد جدید در اتحاد ثبت شد"

	var time_lbl := CafeSocialTheme.make_body(CafeSocialTheme.format_time_fa(str(entry.get("created_at", ""))), 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_LEFT, false)
	h.add_child(time_lbl)

	var d_lbl := CafeSocialTheme.make_body(text_desc, 18, act_col, HORIZONTAL_ALIGNMENT_RIGHT, true)
	d_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(d_lbl)

	var tr := TextureRect.new()
	tr.texture = act_ico
	tr.custom_minimum_size = Vector2(22, 22)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = act_col
	h.add_child(tr)
	return h


# ==============================================================================
# 4. CLAN MEMBERS – MEMBERS TAB
# ==============================================================================

static func _build_clan_members_tab(host: Control, holder: VBoxContainer, cdict: Dictionary) -> void:
	var members: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []
	var my_role := str(cdict.get("my_role", "member"))
	var my_uid := str(GameManager.get_user_id())

	# A. 4-Metric Overview Strip
	var online_cnt := 0
	var total_contrib := 0
	for m in members:
		if typeof(m) == TYPE_DICTIONARY:
			total_contrib += int(m.get("weekly_contribution", 0))
			var pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
			var st: String = str(pres.get("status", "offline"))
			if st in ["online", "in_game", "in_lobby", "in_queue"]:
				online_cnt += 1
	if online_cnt == 0:
		online_cnt = 1

	var ov_strip := HBoxContainer.new()
	ov_strip.add_theme_constant_override("separation", 8)
	holder.add_child(ov_strip)

	# 4-Metric Overview Strip (icons removed as requested)
	var m1 := CafeSocialTheme.make_metric_card("کل اعضا", GameManager.to_fa_num(members.size()), CafeSocialTheme.COL_IVORY, null)
	m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_strip.add_child(m1)

	var m2 := CafeSocialTheme.make_metric_card("آنلاین", GameManager.to_fa_num(online_cnt), CafeSocialTheme.COL_EMERALD_TEXT, null)
	m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_strip.add_child(m2)

	var max_cap := int(cdict.get("max_members", 40))
	var m3 := CafeSocialTheme.make_metric_card("ظرفیت", GameManager.to_fa_num(max_cap), CafeSocialTheme.COL_GOLD_BRIGHT, null)
	m3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_strip.add_child(m3)

	var m4 := CafeSocialTheme.make_metric_card("مشارکت کل", GameManager.to_fa_num(total_contrib), CafeSocialTheme.COL_GOLD_BRIGHT, null)
	m4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ov_strip.add_child(m4)

	# B. Search & Filter Bar
	var filter_card := PanelContainer.new()
	var fc_sb := StyleBoxFlat.new()
	fc_sb.bg_color = Color(0.12, 0.08, 0.04, 0.94)
	fc_sb.border_color = Color(0.50, 0.38, 0.20, 0.65)
	fc_sb.set_border_width_all(1)
	fc_sb.set_corner_radius_all(12)
	fc_sb.content_margin_left = 10.0
	fc_sb.content_margin_right = 10.0
	fc_sb.content_margin_top = 8.0
	fc_sb.content_margin_bottom = 8.0
	filter_card.add_theme_stylebox_override("panel", fc_sb)
	holder.add_child(filter_card)

	var fc_vbox := VBoxContainer.new()
	fc_vbox.add_theme_constant_override("separation", 8)
	filter_card.add_child(fc_vbox)

	var search_input := CafeSocialTheme.make_line_edit("جستجوی عضو بر اساس نام کاربری...", 48.0, 20)
	fc_vbox.add_child(search_input)

	# Filter Pills
	var pills_row := HBoxContainer.new()
	pills_row.add_theme_constant_override("separation", 6)
	fc_vbox.add_child(pills_row)

	var cur_filter := ["all"] # "all" | "online" | "officers" | "contrib" | "score"
	var pill_defs := [
		{"id": "all", "label": "همه"},
		{"id": "online", "label": "آنلاین"},
		{"id": "officers", "label": "مدیران"},
		{"id": "contrib", "label": "بیشترین مشارکت"},
		{"id": "score", "label": "بالاترین امتیاز"},
	]

	# C. Scrollable Member Cards List
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var m_vbox := VBoxContainer.new()
	m_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(m_vbox)

	var pill_buttons: Dictionary = {}
	var refresh_members_list := func():
		for ch in m_vbox.get_children():
			ch.queue_free()

		var q := search_input.text.strip_edges().to_lower()
		var filtered_arr: Array = []
		for m in members:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var m_uname := str(m.get("username", "")).to_lower()
			if not q.is_empty() and not q in m_uname:
				continue
			var m_role: String = str(m.get("role", "member"))
			var pres_st := str((m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}).get("status", "offline"))
			var is_online: bool = pres_st in ["online", "in_game", "in_lobby", "in_queue"]

			match cur_filter[0]:
				"online":
					if not is_online:
						continue
				"officers":
					if not m_role in ["leader", "co_leader", "elder"]:
						continue

			filtered_arr.append(m)

		# Sorting
		match cur_filter[0]:
			"contrib":
				filtered_arr.sort_custom(func(a, b): return int(a.get("weekly_contribution", 0)) > int(b.get("weekly_contribution", 0)))
			"score":
				filtered_arr.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
			_:
				filtered_arr.sort_custom(func(a, b):
					var ra: int = ROLE_RANKS.get(str(a.get("role", "member")), 1)
					var rb: int = ROLE_RANKS.get(str(b.get("role", "member")), 1)
					if ra != rb:
						return ra > rb
					return int(a.get("weekly_contribution", 0)) > int(b.get("weekly_contribution", 0))
				)

		if filtered_arr.is_empty():
			m_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"عضوی با این مشخصات یافت نشد",
				"عبارت جستجو یا فیلتر را تغییر دهید."
			))
			return

		for m_item in filtered_arr:
			m_vbox.add_child(_build_clan_member_card(host, m_item, my_uid, my_role))

	var update_pill_styles := func():
		for pk in pill_buttons.keys():
			var pb: Button = pill_buttons[pk]
			var act: bool = (pk == cur_filter[0])
			pb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 10))
			pb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 10))

	for pd in pill_defs:
		var pid: String = pd["id"]
		var pb := CafeSocialTheme.make_button(pd["label"], "muted", Vector2(0, 40), 18)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			cur_filter[0] = pid
			update_pill_styles.call()
			refresh_members_list.call()
		)
		pill_buttons[pid] = pb
		pills_row.add_child(pb)

	search_input.text_changed.connect(func(_t: String): refresh_members_list.call())
	update_pill_styles.call()
	refresh_members_list.call()


static func _build_clan_member_card(host: Control, m_dict: Dictionary, my_uid: String, my_role: String) -> PanelContainer:
	var m_uid := str(m_dict.get("user_id", m_dict.get("_id", "")))
	var m_name := str(m_dict.get("username", "بازیکن"))
	var m_role := str(m_dict.get("role", "member"))
	var m_role_fa := str(m_dict.get("role_title", m_dict.get("role_fa", ROLE_FA_MAP.get(m_role, "عضو"))))
	var m_contrib := int(m_dict.get("weekly_contribution", 0))
	var m_score := int(m_dict.get("score", 0))
	var m_pres: Dictionary = m_dict.get("presence", {}) if typeof(m_dict.get("presence")) == TYPE_DICTIONARY else {}
	var p_info := CafeSocialTheme.format_presence(m_pres)
	var raw_st := str(m_pres.get("status", "offline"))

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 126)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(0.50, 0.36, 0.20, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 4
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	# Left actions column
	var act_col := VBoxContainer.new()
	act_col.alignment = BoxContainer.ALIGNMENT_CENTER
	act_col.add_theme_constant_override("separation", 4)
	row.add_child(act_col)

	var b_act := TextureButton.new()
	b_act.custom_minimum_size = Vector2(48, 48)
	b_act.ignore_texture_size = true
	b_act.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b_act.texture_normal = preload("res://assets/images/config.png")
	b_act.focus_mode = Control.FOCUS_NONE
	b_act.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b_act.tooltip_text = "عملیات"
	ActionVFXManager.apply_button_juice(b_act, "tap_button")
	b_act.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_member_interaction_sheet(host, m_dict, my_role)
	)
	act_col.add_child(b_act)

	if m_uid != my_uid and bool(p_info.get("is_in_game", false)):
		var b_spec := CafeSocialTheme.make_button("تماشا", "emerald", Vector2(88, 36), 18)
		b_spec.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.request_spectate_game(str(p_info.get("game_id", "")), m_uid)
			host._show_toast("درخواست تماشای مسابقه ارسال شد...")
		)
		act_col.add_child(b_spec)

	# Center member details
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	# Row 1: Username on top with 2x bigger font size (~34px)
	var nm_lbl := CafeSocialTheme.make_title(
		m_name if m_uid != my_uid else "%s (شما)" % m_name,
		34,
		CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	)
	nm_lbl.clip_text = true
	nm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm_lbl)

	# Row 2: Distinctive role badge under username
	var role_row := HBoxContainer.new()
	role_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(role_row)

	var role_badge := CafeSocialTheme.make_badge_pill(
		"👑 %s" % m_role_fa if m_role == "leader" else ("⭐ %s" % m_role_fa if m_role == "co_leader" else ("🛡️ %s" % m_role_fa if m_role == "elder" else m_role_fa)),
		CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if m_role in ["co_leader", "elder"] else CafeSocialTheme.COL_MUTED_SAND),
		Color(0.20, 0.13, 0.05) if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BG if m_role in ["co_leader", "elder"] else Color(0.10, 0.16, 0.24)),
		CafeSocialTheme.COL_GOLD_ANTIQUE if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BORDER if m_role in ["co_leader", "elder"] else Color(0.35, 0.65, 0.85)),
		16
	)
	role_row.add_child(role_badge)

	# Row 3: Contribution & score (مشارکت value strictly LTR so + is on the left)
	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_END
	meta_row.add_theme_constant_override("separation", 6)
	col.add_child(meta_row)

	var score_lbl := CafeSocialTheme.make_body("امتیاز: %s" % GameManager.to_fa_num(m_score), 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)

	var dot_lbl := CafeSocialTheme.make_body("•", 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)

	var contrib_val_lbl := Label.new()
	contrib_val_lbl.text = "+%s" % GameManager.to_fa_num(m_contrib)
	contrib_val_lbl.layout_direction = Control.LAYOUT_DIRECTION_LTR
	contrib_val_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if m_contrib > 0 else CafeSocialTheme.COL_MUTED_SAND)
	contrib_val_lbl.add_theme_font_size_override("font_size", 18)
	contrib_val_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)

	var contrib_title_lbl := CafeSocialTheme.make_body("مشارکت:", 17, CafeSocialTheme.COL_GOLD_BRIGHT if m_contrib > 0 else CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)

	meta_row.add_child(score_lbl)
	meta_row.add_child(dot_lbl)
	meta_row.add_child(contrib_val_lbl)
	meta_row.add_child(contrib_title_lbl)

	# Right: Avatar with frame
	var av_vis := CafeSocialTheme.make_avatar_badge(int(m_dict.get("image", 0)), int(m_dict.get("profile_frame", 1)), 66.0, raw_st, true)
	row.add_child(av_vis)

	# Tapping whole card opens member interactions
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			_open_member_interaction_sheet(host, m_dict, my_role)
	)

	return card


static func _open_member_interaction_sheet(host: Control, m_dict: Dictionary, my_role: String) -> void:
	var m_uid := str(m_dict.get("user_id", m_dict.get("_id", "")))
	var m_name := str(m_dict.get("username", "بازیکن"))
	var m_role := str(m_dict.get("role", "member"))
	var m_role_fa := str(m_dict.get("role_title", m_dict.get("role_fa", ROLE_FA_MAP.get(m_role, "عضو"))))
	var my_uid := str(GameManager.get_user_id())

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.80)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m.add_child(vbox)

	# Member Header inside modal
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 12)
	top_h.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_h)

	var p_col := VBoxContainer.new()
	p_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_col.alignment = BoxContainer.ALIGNMENT_CENTER
	p_col.add_theme_constant_override("separation", 3)
	top_h.add_child(p_col)

	p_col.add_child(CafeSocialTheme.make_title(m_name, 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false))
	p_col.add_child(CafeSocialTheme.make_body("سمت: %s • مشارکت: %s • امتیاز: %s" % [
		m_role_fa,
		GameManager.to_fa_num(int(m_dict.get("weekly_contribution", 0))),
		GameManager.to_fa_num(int(m_dict.get("score", 0)))
	], 18, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	top_h.add_child(CafeSocialTheme.make_avatar_badge(int(m_dict.get("image", 0)), int(m_dict.get("profile_frame", 1)), 72.0))

	# Action 1: View Profile
	var b_prof := CafeSocialTheme.make_button("مشاهده پروفایل بازیکن", "gold", Vector2(0, 50), 22)
	b_prof.pressed.connect(func():
		overlay.queue_free()
		UserProfileDialog.show_user(m_dict, m_role_fa, host)
	)
	vbox.add_child(b_prof)

	# Action 2: Direct Message (if not self)
	if m_uid != my_uid:
		var b_dm := CafeSocialTheme.make_button("ارسال پیام خصوصی", "emerald", Vector2(0, 50), 22)
		b_dm.pressed.connect(func():
			overlay.queue_free()
			host.open_direct_message_with(m_uid, m_name)
		)
		vbox.add_child(b_dm)

		# Action 3: Invite to Game
		var b_inv := CafeSocialTheme.make_button("دعوت به بازی دوستانه", "bronze", Vector2(0, 50), 22)
		b_inv.pressed.connect(func():
			overlay.queue_free()
			CafeSocialTheme.show_game_invite_modal(host, m_uid, m_name, func(g_title: String):
				host._show_toast("دعوت‌نامه بازی «%s» برای «%s» ارسال شد!" % [g_title, m_name])
			)
		)
		vbox.add_child(b_inv)

	# Administrative Actions
	var can_manage: bool = (m_uid != my_uid) and (
		my_role == "leader"
		or (my_role == "co_leader" and m_role in ["elder", "member"])
		or (my_role == "elder" and m_role == "member")
	)

	if can_manage:
		var sep := HSeparator.new()
		vbox.add_child(sep)
		vbox.add_child(CafeSocialTheme.make_body("اختیارات مدیریتی شما برای این عضو:", 18, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

		# Promote actions
		if my_role in ["leader", "co_leader"] and m_role == "member":
			var b_p1 := CafeSocialTheme.make_button("ارتقا به ارشد (Elder)", "sapphire", Vector2(0, 48), 21)
			b_p1.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "elder", func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("«%s» به ارشد ارتقا یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p1)
		elif my_role == "leader" and m_role == "elder":
			var b_p2 := CafeSocialTheme.make_button("ارتقا به قائم‌مقام رهبر (Co-Leader)", "sapphire", Vector2(0, 48), 21)
			b_p2.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "co_leader", func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("«%s» به قائم‌مقام ارتقا یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p2)

		# Demote actions
		if my_role == "leader" and m_role in ["co_leader", "elder"]:
			var target_r := "member" if m_role == "elder" else "elder"
			var b_dem := CafeSocialTheme.make_button("تنزل درجه", "bronze", Vector2(0, 48), 21)
			b_dem.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, target_r, func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه «%s» تنزل یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_dem)

		# Transfer Leadership
		if my_role == "leader":
			var b_lead := CafeSocialTheme.make_button("انتقال رهبری اتحاد به این عضو", "gold", Vector2(0, 48), 21, CafeSocialTheme.ICO_KING)
			b_lead.pressed.connect(func():
				overlay.queue_free()
				CafeSocialTheme.show_confirm_modal(
					host, "انتقال رهبری اتحاد",
					"آیا مطمئن هستید می‌خواهید رهبری اتحاد را به «%s» واگذار کنید؟ پس از این کار شما قائم‌مقام خواهید شد." % m_name,
					"انتقال رهبری", true,
					func():
						NetworkManager.api.transfer_clan_leadership(m_uid, func(_ok, _c, _d):
							host._show_toast("رهبری اتحاد به %s منتقل شد." % m_name)
							host._refresh_current_tab()
						)
				)
			)
			vbox.add_child(b_lead)

		# Kick from clan
		var b_kick := CafeSocialTheme.make_button("اخراج از اتحاد", "crimson", Vector2(0, 48), 21)
		b_kick.pressed.connect(func():
			overlay.queue_free()
			CafeSocialTheme.show_confirm_modal(
				host, "اخراج از اتحاد",
				"آیا مطمئن هستید می‌خواهید «%s» را از اتحاد اخراج کنید؟" % m_name,
				"اخراج شود", true,
				func():
					NetworkManager.api.kick_clan_member(m_uid, func(_ok, _c, _d):
						host._show_toast("«%s» از اتحاد اخراج شد." % m_name)
						host._refresh_current_tab()
					)
			)
		)
		vbox.add_child(b_kick)

	var b_close := CafeSocialTheme.make_button("بستن", "muted", Vector2(0, 46), 20)
	b_close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(b_close)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


# ==============================================================================
# 5. NO CLAN HERO & DISCOVERY & LEADERBOARDS
# ==============================================================================

static func _build_no_clan_overview(host: Control, vbox: VBoxContainer) -> void:
	var hero := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.14, 0.09, 0.05, 0.98)
	h_sb.border_color = Color(0.85, 0.68, 0.30, 0.90)
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(16)
	h_sb.shadow_color = Color(0, 0, 0, 0.45)
	h_sb.shadow_size = 8
	h_sb.content_margin_left = 20.0
	h_sb.content_margin_right = 20.0
	h_sb.content_margin_top = 22.0
	h_sb.content_margin_bottom = 22.0
	hero.add_theme_stylebox_override("panel", h_sb)
	vbox.add_child(hero)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 14)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hv)

	hv.add_child(CafeSocialTheme.make_clan_emblem(1, 96.0))
	hv.add_child(CafeSocialTheme.make_title("به یک اتحاد بپیوندید یا اتحاد خودتان را بسازید!", 32, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	hv.add_child(CafeSocialTheme.make_body(
		"در اتحادهای کافه فکر می‌توانید با دوستان خود چت کنید، چالش‌های هفتگی را فتح کرده و پاداش بگیرید، مسابقات دوستانه بسازید و نام اتحاد خود را در صدر جدول قهرمانان ثبت کنید.",
		21, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true
	))
	hv.add_child(CafeSocialTheme.make_badge_pill(
		"تاسیس اتحاد کاملاً رایگان است (سهمیه هر بازیکن: ۱ اتحاد)",
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		19
	))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(btn_row)

	var b_search := CafeSocialTheme.make_button("جستجو و عضویت در اتحادها", "emerald", Vector2(0, 56), 23)
	b_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_search.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "discover"
		host._refresh_current_tab()
	)
	btn_row.add_child(b_search)

	var b_create := CafeSocialTheme.make_button("تاسیس اتحاد جدید (رایگان)", "gold", Vector2(0, 56), 23)
	b_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_create.pressed.connect(func():
		AudioManager.sfx_button()
		open_clan_create_modal(host)
	)
	btn_row.add_child(b_create)

	# Incoming Invitations
	var invs: Array = host._my_clan_data.get("invitations", []) if typeof(host._my_clan_data.get("invitations")) == TYPE_ARRAY else []
	if not invs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"دعوت‌نامه‌های اتحاد برای شما", CafeSocialTheme.ICO_STAR,
			"%s دعوت‌نامه در انتظار پاسخ" % GameManager.to_fa_num(invs.size())
		))
		for inv in invs:
			if typeof(inv) == TYPE_DICTIONARY:
				vbox.add_child(_build_incoming_invitation_card(host, inv))


static func _build_incoming_invitation_card(host: Control, inv: Dictionary) -> PanelContainer:
	var c_sub: Dictionary = inv.get("clan", {}) if typeof(inv.get("clan")) == TYPE_DICTIONARY else {}
	var cname := str(c_sub.get("name", "اتحاد"))
	var ctag := str(c_sub.get("tag", ""))
	var emb := int(c_sub.get("emblem_id", 1))
	var inv_id := str(inv.get("invite_id", ""))

	var icard := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.95)
	sb.border_color = Color(0.70, 0.52, 0.24, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	icard.add_theme_stylebox_override("panel", sb)

	var irow := HBoxContainer.new()
	irow.alignment = BoxContainer.ALIGNMENT_CENTER
	irow.add_theme_constant_override("separation", 10)
	icard.add_child(irow)

	var b_rej := CafeSocialTheme.make_button("رد", "crimson", Vector2(88, 46), 20)
	b_rej.pressed.connect(func():
		AudioManager.sfx_tap()
		NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(_ok: bool, _c: int, _d: Variant):
			host._refresh_current_tab()
		)
	)
	irow.add_child(b_rej)

	var b_acc := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(110, 46), 20)
	b_acc.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, d: Variant):
			if ok:
				host._show_toast("به اتحاد «%s» خوش آمدید!" % cname)
				host._refresh_current_tab()
			elif typeof(d) == TYPE_DICTIONARY:
				host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	irow.add_child(b_acc)

	var ic_col := VBoxContainer.new()
	ic_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic_col.alignment = BoxContainer.ALIGNMENT_CENTER
	irow.add_child(ic_col)
	ic_col.add_child(CafeSocialTheme.make_title("%s  [%s]" % [cname, ctag], 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
	ic_col.add_child(CafeSocialTheme.make_body("سطح %s • %s عضو" % [
		GameManager.to_fa_num(int(c_sub.get("clan_level", 1))),
		GameManager.to_fa_num(int(c_sub.get("member_count", 1)))
	], 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	irow.add_child(CafeSocialTheme.make_clan_emblem(emb, 60.0))
	return icard


static func _build_clan_discover_view(host: Control, holder: VBoxContainer) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	holder.add_child(mode_row)

	var has_clan := _check_user_has_clan(host)
	if has_clan:
		var b_back := CafeSocialTheme.make_button("بازگشت به اتحاد", "emerald", Vector2(160, 50), 20)
		b_back.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_clans_subtab = "my_clan"
			host._refresh_current_tab()
		)
		mode_row.add_child(b_back)

	var is_lb: bool = (str(host.current_clans_subtab) == "leaderboard")
	var btn_dir := CafeSocialTheme.make_button("فهرست و جستجوی اتحادها", "gold" if not is_lb else "muted", Vector2(0, 50), 21)
	btn_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dir.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "discover"
		host._refresh_current_tab()
	)
	mode_row.add_child(btn_dir)

	var btn_lb := CafeSocialTheme.make_button("جدول برترین اتحادها", "gold" if is_lb else "muted", Vector2(0, 50), 21)
	btn_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_lb.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "leaderboard"
		host._refresh_current_tab()
	)
	mode_row.add_child(btn_lb)

	if is_lb:
		_build_clan_leaderboard_inner(host, holder)
	else:
		_build_clan_search_inner(host, holder)


static func _build_clan_search_inner(host: Control, holder: VBoxContainer) -> void:
	var s_card := PanelContainer.new()
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color(0.13, 0.09, 0.05, 0.94)
	sc_sb.border_color = Color(0.55, 0.40, 0.22, 0.65)
	sc_sb.set_border_width_all(1)
	sc_sb.set_corner_radius_all(12)
	sc_sb.content_margin_left = 12.0
	sc_sb.content_margin_right = 12.0
	sc_sb.content_margin_top = 8.0
	sc_sb.content_margin_bottom = 8.0
	s_card.add_theme_stylebox_override("panel", sc_sb)
	holder.add_child(s_card)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	s_card.add_child(sv)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 8)
	sv.add_child(s_row)

	var btn_s := CafeSocialTheme.make_button("جستجو", "gold", Vector2(110, 52), 22)
	s_row.add_child(btn_s)

	var inp := CafeSocialTheme.make_line_edit("جستجوی نام یا تگ اتحاد (مثلاً CAFE#)...", 52.0, 21)
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_row.add_child(inp)

	var filter_jt := [""]
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	sv.add_child(filter_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var res_vbox := VBoxContainer.new()
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(res_vbox)

	var do_search := func():
		for ch in res_vbox.get_children():
			ch.queue_free()
		res_vbox.add_child(CafeSocialTheme.make_loading_state("در حال جستجوی اتحادها..."))
		NetworkManager.api.search_clans(inp.text.strip_edges(), filter_jt[0], "clan_score", func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(res_vbox):
				return
			for ch in res_vbox.get_children():
				ch.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				var arr: Array = data["result"]
				if arr.is_empty():
					res_vbox.add_child(CafeSocialTheme.make_empty_state(
						CafeSocialTheme.ICO_INFO,
						"اتحادی با این مشخصات پیدا نشد",
						"عبارت جستجو یا فیلتر را تغییر دهید یا اتحاد جدید خود را بسازید."
					))
					return
				for cl in arr:
					if typeof(cl) == TYPE_DICTIONARY:
						res_vbox.add_child(_build_clan_directory_card(host, cl))
		)

	var f_defs := [
		{"id": "", "label": "همه اتحادها"},
		{"id": "open", "label": "عضویت آزاد"},
		{"id": "request", "label": "نیازمند تایید"},
	]
	var f_btns: Dictionary = {}
	var update_f_btns := func():
		for fk in f_btns.keys():
			var fb: Button = f_btns[fk]
			var active: bool = (fk == filter_jt[0])
			fb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "normal", 10))
			fb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "hover", 10))

	for fd in f_defs:
		var fid: String = fd["id"]
		var fb := CafeSocialTheme.make_button(fd["label"], "muted", Vector2(0, 40), 19)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			AudioManager.sfx_tap()
			filter_jt[0] = fid
			update_f_btns.call()
			do_search.call()
		)
		f_btns[fid] = fb
		filter_row.add_child(fb)
	update_f_btns.call()

	btn_s.pressed.connect(func():
		AudioManager.sfx_tap()
		do_search.call()
	)
	inp.text_submitted.connect(func(_t: String): do_search.call())
	do_search.call()


static func _build_clan_directory_card(host: Control, cl: Dictionary, rank_num: int = 0) -> PanelContainer:
	var cid := str(cl.get("clan_id", cl.get("_id", "")))
	var cname := str(cl.get("name", "اتحاد"))
	var ctag := str(cl.get("tag", ""))
	var emb_id := int(cl.get("emblem_id", 1))
	var lvl := int(cl.get("clan_level", 1))
	var cscore := int(cl.get("clan_score", 0))
	var mem_cnt := int(cl.get("member_count", 1))
	var max_mem := int(cl.get("max_members", 40))
	var jtype := str(cl.get("join_type", "open"))
	var jtype_fa := "آزاد" if jtype == "open" else ("با تایید" if jtype == "request" else "دعوت‌نامه‌ای")

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(0.55, 0.40, 0.22, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			CafeSocialTheme.show_clan_details_modal(host, cid, cl)
	)
	card.add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	# Left metrics
	var left_col := VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 4)
	row.add_child(left_col)
	left_col.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(cscore), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 18))
	left_col.add_child(CafeSocialTheme.make_badge_pill("%s/%s عضو" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	# Center info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var prefix := "#%s  " % GameManager.to_fa_num(rank_num) if rank_num > 0 else ""
	info.add_child(CafeSocialTheme.make_title("%s%s  [%s]" % [prefix, cname, ctag], 26, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	info.add_child(CafeSocialTheme.make_body("سطح %s  •  عضویت: %s" % [GameManager.to_fa_num(lvl), jtype_fa], 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	row.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 64.0))

	if jtype != "invite_only":
		var b_join := CafeSocialTheme.make_button("عضویت در اتحاد" if jtype == "open" else "ارسال درخواست عضویت", "emerald" if jtype == "open" else "bronze", Vector2(0, 44), 20)
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.join_or_request_clan(cid, "درخواست عضویت از کافه فکر", func(ok_j: bool, _cj: int, dj: Variant):
				if ok_j:
					host._show_toast("درخواست یا عضویت شما با موفقیت ثبت شد!")
					host.current_clans_subtab = "my_clan"
					host._refresh_current_tab()
				elif typeof(dj) == TYPE_DICTIONARY:
					host._show_toast(str(dj.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		root.add_child(b_join)

	return card


static func _build_clan_leaderboard_inner(host: Control, holder: VBoxContainer) -> void:
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 6)
	holder.add_child(m_row)

	var modes := [
		{"id": "clans", "label": "کل امتیاز"},
		{"id": "clans_weekly", "label": "برترین‌های هفته"},
		{"id": "clans_monthly", "label": "برترین‌های ماه"},
	]
	for m in modes:
		var mid: String = m["id"]
		var act: bool = (str(host.current_clan_lb_mode) == mid)
		var b := CafeSocialTheme.make_subtab(m["label"], act, 0)
		b.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_clan_lb_mode = mid
			host._refresh_current_tab()
		)
		m_row.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var lb_vbox := VBoxContainer.new()
	lb_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(lb_vbox)
	lb_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت جدول رتبه‌بندی اتحادها..."))

	NetworkManager.api.get_social_leaderboard(host.current_clan_lb_mode, "", "", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(lb_vbox):
			return
		for ch in lb_vbox.get_children():
			ch.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var arr: Array = data["result"]
			if arr.is_empty():
				lb_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.ICO_CUP,
					"هنوز اتحادی در جدول ثبت نشده است",
					"اولین اتحاد خود را بسازید و نامش را در تاریخ کافه فکر ثبت کنید!"
				))
				return
			for i in range(arr.size()):
				var item = arr[i]
				if typeof(item) == TYPE_DICTIONARY:
					var rnk := int(item.get("rank", i + 1))
					lb_vbox.add_child(_build_clan_directory_card(host, item, rnk))
	)


# ==============================================================================
# 6. FRIENDLY CHALLENGE ACTION ROW & OVERVIEW CARD
# ==============================================================================

static func _build_challenge_action_row(host: Control, meta: Dictionary, my_uid: String, my_role: String, _in_chat: bool = false) -> HBoxContainer:
	var ch_id: String = str(meta.get("challenge_id", ""))
	var chal_gt: String = str(meta.get("game_type", "Monopoly"))
	var chal_creator: String = str(meta.get("creator_id", ""))
	var chal_status: String = str(meta.get("status", "open"))
	var p_count: int = clampi(int(meta.get("player_count", 2)), 2, 4)
	var parts: Array = meta.get("participants", []) if typeof(meta.get("participants")) == TYPE_ARRAY else []

	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 8)

	if chal_status == "closed":
		act_row.add_child(CafeSocialTheme.make_badge_pill("چالش بسته شد", CafeSocialTheme.COL_CRIMSON_TEXT, Color(0.22, 0.06, 0.06, 0.94), CafeSocialTheme.COL_CRIMSON_BORDER, 17))
		return act_row

	if chal_status == "started":
		act_row.add_child(CafeSocialTheme.make_badge_pill("مسابقه شروع شد", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))
		return act_row

	var already_joined: bool = false
	for pt in parts:
		if typeof(pt) == TYPE_DICTIONARY and str(pt.get("user_id", "")) == my_uid:
			already_joined = true
			break
	if not already_joined and not chal_creator.is_empty() and chal_creator == my_uid:
		already_joined = true

	var cur_players: int = maxi(1, parts.size())
	act_row.add_child(CafeSocialTheme.make_badge_pill(
		"%s از %s نفر" % [GameManager.to_fa_num(cur_players), GameManager.to_fa_num(p_count)],
		CafeSocialTheme.COL_GOLD_BRIGHT,
		Color(0.18, 0.12, 0.04),
		CafeSocialTheme.COL_GOLD_ANTIQUE,
		17
	))

	var can_close: bool = (not ch_id.is_empty()) and (chal_creator == my_uid or my_role in ["leader", "co_leader"])
	if can_close:
		var b_close := CafeSocialTheme.make_button("بستن چالش", "crimson", Vector2(110, 40), 18)
		b_close.pressed.connect(func():
			AudioManager.sfx_tap()
			b_close.disabled = true
			NetworkManager.api.close_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					host._show_toast("چالش دوستانه بسته شد.")
					host._refresh_current_tab()
				else:
					if is_instance_valid(b_close):
						b_close.disabled = false
					var err := "خطا در بستن چالش"
					if typeof(res_d) == TYPE_DICTIONARY:
						err = str(res_d.get("detail", err))
					host._show_toast(err, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_close)

	# When required players fill completely, game automatically starts without needing creator to tap start
	if not ch_id.is_empty() and cur_players >= p_count and chal_status == "open":
		act_row.add_child(CafeSocialTheme.make_badge_pill(
			"ظرفیت تکمیل شد • در حال آغاز بازی...",
			CafeSocialTheme.COL_EMERALD_TEXT,
			CafeSocialTheme.COL_EMERALD_BG,
			CafeSocialTheme.COL_EMERALD_BORDER,
			17
		))
		# Auto-trigger start
		NetworkManager.start_clan_challenge_realtime(ch_id)
		# Verification: check if the game really started
		if is_instance_valid(host):
			host.get_tree().create_timer(3.0).timeout.connect(func():
				if not GameManager.is_game_active and is_instance_valid(host):
					NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
						if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
							host._my_clan_data = data["result"]
							if is_instance_valid(host) and host.has_method("_refresh_current_tab"):
								host._refresh_current_tab()
					)
			)
	elif not ch_id.is_empty() and chal_creator == my_uid and cur_players >= 2 and cur_players < p_count:
		var b_start := CafeSocialTheme.make_button("شروع زودهنگام", "emerald", Vector2(120, 40), 19)
		b_start.pressed.connect(func():
			AudioManager.sfx_button()
			b_start.disabled = true
			NetworkManager.start_clan_challenge_realtime(ch_id)
			host._show_toast("در حال شروع مسابقه دوستانه...")
		)
		act_row.add_child(b_start)

	if not already_joined and cur_players < p_count:
		var b_acc := CafeSocialTheme.make_button("پیوستن به چالش", "emerald", Vector2(130, 40), 19)
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			b_acc.disabled = true
			NetworkManager.api.join_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					var res_obj: Dictionary = {}
					if typeof(res_d) == TYPE_DICTIONARY:
						res_obj = res_d.get("result", res_d) if typeof(res_d.get("result", res_d)) == TYPE_DICTIONARY else {}
					var is_full: bool = bool(res_obj.get("is_full", false)) or (cur_players + 1 >= p_count)
					if is_full:
						NetworkManager.start_clan_challenge_realtime(ch_id)
						host._show_toast("ظرفیت تکمیل شد! بازی در حال آغاز است...")
						if is_instance_valid(host):
							host.get_tree().create_timer(3.0).timeout.connect(func():
								if not GameManager.is_game_active and is_instance_valid(host):
									host._refresh_current_tab()
							)
					else:
						host._show_toast("به چالش پیوستید! منتظر پیوستن سایر بازیکنان...")
						host._refresh_current_tab()
				else:
					if is_instance_valid(b_acc):
						b_acc.disabled = false
					var err := "خطا در پیوستن"
					if typeof(res_d) == TYPE_DICTIONARY:
						err = str(res_d.get("detail", err))
					host._show_toast(err, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_acc)
	elif already_joined and cur_players < p_count and chal_creator != my_uid:
		act_row.add_child(CafeSocialTheme.make_badge_pill("در انتظار هم‌تیمی‌ها", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	return act_row


static func _build_overview_challenge_card(host: Control, chal: Dictionary, my_uid: String, my_role: String) -> PanelContainer:
	var gt: String = str(chal.get("game_type", "Monopoly"))
	var gt_fa: String = str(chal.get("game_title_fa", GameRegistry.get_display_name_fa(gt)))
	var creator_name: String = str(chal.get("creator_name", "هم‌اتحادی"))
	var p_count: int = clampi(int(chal.get("player_count", 2)), 2, 4)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.10, 0.06, 0.96)
	sb.border_color = Color(0.70, 0.54, 0.24, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 5
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)

	info.add_child(CafeSocialTheme.make_title("چالش دوستانه %s (%s نفره)" % [gt_fa, GameManager.to_fa_num(p_count)], 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	info.add_child(CafeSocialTheme.make_body("ایجاد شده توسط %s" % creator_name, 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var thumb_tex := CafeSocialTheme.get_game_thumb(gt)
	if thumb_tex != null:
		var tr := TextureRect.new()
		tr.texture = thumb_tex
		tr.custom_minimum_size = Vector2(58, 58)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		top.add_child(tr)

	v.add_child(_build_challenge_action_row(host, chal, my_uid, my_role, false))
	return card


# ==============================================================================
# 7. MODALS: CLAN CREATION, SETTINGS & FRIENDLY CHALLENGE
# ==============================================================================

static func open_clan_create_modal(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.82)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(44, 44)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("تاسیس اتحاد جدید", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 44)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_badge_pill("ساخت اتحاد رایگان است • سهمیه هر بازیکن: ۱ اتحاد", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	# Emblem Picker
	vbox.add_child(CafeSocialTheme.make_body("نشان (لوگو) اتحاد را انتخاب کنید:", 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var selected_emblem := [1]
	var emb_grid := HBoxContainer.new()
	emb_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	emb_grid.add_theme_constant_override("separation", 8)
	vbox.add_child(emb_grid)

	var emb_wraps: Dictionary = {}
	var update_emb_sel := func():
		for eid in emb_wraps.keys():
			var eb: Button = emb_wraps[eid]
			var act: bool = (eid == selected_emblem[0])
			eb.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.16, 0.08) if act else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_GOLD_BRIGHT if act else CafeSocialTheme.COL_BRONZE_BORDER,
				12, 2 if act else 1, 6.0, 6.0
			))
			eb.add_theme_stylebox_override("hover", eb.get_theme_stylebox("normal"))

	for ecfg in CafeSocialTheme.CLAN_EMBLEMS:
		var eid: int = int(ecfg["id"])
		var eb := Button.new()
		eb.custom_minimum_size = Vector2(62, 62)
		eb.focus_mode = Control.FOCUS_NONE
		var em_vis := CafeSocialTheme.make_clan_emblem(eid, 50.0)
		em_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(em_vis)
		eb.add_child(cc)
		eb.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_emblem[0] = eid
			update_emb_sel.call()
		)
		emb_wraps[eid] = eb
		emb_grid.add_child(eb)
	update_emb_sel.call()

	var inp_name := CafeSocialTheme.make_line_edit("نام اتحاد (۳ تا ۲۴ حرف، مثلاً: عقاب‌های کافه فکر)", 56.0, 23)
	vbox.add_child(inp_name)

	var inp_tag := CafeSocialTheme.make_line_edit("تگ یکتای اتحاد (۲ تا ۱۰ حرف یا عدد، مثلاً: CAFE1)", 56.0, 23)
	vbox.add_child(inp_tag)

	var inp_desc := CafeSocialTheme.make_line_edit("معرفی کوتاه و قوانین اتحاد (اختیاری)...", 56.0, 21)
	vbox.add_child(inp_desc)

	var join_type_val := ["open"]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 8)
	vbox.add_child(jt_row)

	var b_jt_req := CafeSocialTheme.make_button("نیازمند تایید", "muted", Vector2(0, 48), 21)
	b_jt_req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_jt_open := CafeSocialTheme.make_button("عضویت آزاد", "emerald", Vector2(0, 48), 21)
	b_jt_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var refresh_jt := func():
		b_jt_open.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "open" else "muted", "normal", 12))
		b_jt_req.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "request" else "muted", "normal", 12))
	b_jt_open.pressed.connect(func():
		AudioManager.sfx_tap()
		join_type_val[0] = "open"
		refresh_jt.call()
	)
	b_jt_req.pressed.connect(func():
		AudioManager.sfx_tap()
		join_type_val[0] = "request"
		refresh_jt.call()
	)
	jt_row.add_child(b_jt_req)
	jt_row.add_child(b_jt_open)
	jt_row.add_child(CafeSocialTheme.make_body("نوع عضویت:", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var err_panel := PanelContainer.new()
	err_panel.visible = false
	err_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.28, 0.08, 0.08, 0.96), CafeSocialTheme.COL_CRIMSON_TEXT, 12, 1, 10.0, 6.0))
	var err_lbl := CafeSocialTheme.make_body("", 20, CafeSocialTheme.COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	err_panel.add_child(err_lbl)
	vbox.add_child(err_panel)

	var b_submit := CafeSocialTheme.make_button("تاسیس اتحاد (رایگان)", "gold", Vector2(0, 58), 25, CafeSocialTheme.ICO_CHECK, true)
	b_submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		err_panel.visible = false
		var c_name := inp_name.text.strip_edges()
		var c_tag := inp_tag.text.strip_edges().lstrip("#").strip_edges()
		if c_name.length() < 3:
			err_lbl.text = "نام اتحاد باید حداقل ۳ حرف باشد."
			err_panel.visible = true
			return
		if c_tag.length() < 2 or c_tag.length() > 10:
			err_lbl.text = "تگ اتحاد باید بین ۲ تا ۱۰ حرف یا عدد باشد."
			err_panel.visible = true
			return

		b_submit.disabled = true
		var payload := {
			"name": c_name,
			"tag": c_tag,
			"description": inp_desc.text.strip_edges(),
			"emblem_id": selected_emblem[0],
			"language": "fa",
			"join_type": join_type_val[0],
			"min_score": 0,
			"min_level": 1
		}
		NetworkManager.api.create_clan(payload, func(ok: bool, _c: int, data: Variant):
			if ok:
				if is_instance_valid(overlay):
					overlay.queue_free()
				host._show_toast("اتحاد شما با موفقیت تاسیس شد!")
				host.current_clans_subtab = "my_clan"
				host._refresh_current_tab()
			else:
				if is_instance_valid(b_submit):
					b_submit.disabled = false
				var detail := str(data.get("detail", "خطا در ساخت اتحاد")) if typeof(data) == TYPE_DICTIONARY else "خطا در ساخت اتحاد"
				if is_instance_valid(err_lbl) and is_instance_valid(err_panel):
					err_lbl.text = detail
					err_panel.visible = true
				host._show_toast(detail, CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	vbox.add_child(b_submit)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _open_clan_settings_modal(host: Control, cdict: Dictionary) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.80)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)

	vbox.add_child(CafeSocialTheme.make_title("تنظیمات اتحاد %s" % str(cdict.get("name", "")), 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_desc := CafeSocialTheme.make_line_edit("توضیحات و قوانین اتحاد...", 52.0, 21)
	inp_desc.text = str(cdict.get("description", ""))
	vbox.add_child(inp_desc)

	var jt_val := [str(cdict.get("join_type", "open"))]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 8)
	vbox.add_child(jt_row)

	var jt_defs := [
		{"id": "invite_only", "label": "فقط با دعوت"},
		{"id": "request", "label": "با تایید"},
		{"id": "open", "label": "آزاد"},
	]
	var jt_btns: Dictionary = {}
	var ref_jt := func():
		for jk in jt_btns.keys():
			var b: Button = jt_btns[jk]
			b.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if jk == jt_val[0] else "muted", "normal", 11))

	for jd in jt_defs:
		var jid: String = jd["id"]
		var jb := CafeSocialTheme.make_button(jd["label"], "muted", Vector2(0, 46), 21)
		jb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jb.pressed.connect(func():
			AudioManager.sfx_tap()
			jt_val[0] = jid
			ref_jt.call()
		)
		jt_btns[jid] = jb
		jt_row.add_child(jb)
	ref_jt.call()

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var b_cancel := CafeSocialTheme.make_button("بستن", "bronze", Vector2(0, 52), 22)
	b_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_cancel.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(b_cancel)

	var b_save := CafeSocialTheme.make_button("ذخیره تغییرات", "emerald", Vector2(0, 52), 22, CafeSocialTheme.ICO_CHECK)
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_save.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.update_clan_settings({
			"description": inp_desc.text.strip_edges(),
			"join_type": jt_val[0]
		}, func(ok: bool, _c: int, _d: Variant):
			overlay.queue_free()
			if ok:
				host._show_toast("تنظیمات اتحاد بروزرسانی شد.")
				host._refresh_current_tab()
		)
	)
	btn_row.add_child(b_save)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _open_friendly_challenge_modal(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.01, 0.01, 0.82)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 22)
	m.add_theme_constant_override("margin_bottom", 22)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)

	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(44, 44)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("ایجاد چالش دوستانه در اتحاد", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(44, 44)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_body("بازی مورد نظر و تعداد بازیکنان را انتخاب کنید:", 19, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var selected_gid: Array = [GameTypes.MONOPOLY]
	var selected_pcount: Array = [2]
	var game_cards: Dictionary = {}
	var pcount_btns: Dictionary = {}

	var g_scroll := ScrollContainer.new()
	g_scroll.custom_minimum_size = Vector2(0, 420)
	g_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(g_scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	g_scroll.add_child(grid)

	# Player count selector panel
	var pcount_panel := PanelContainer.new()
	pcount_panel.custom_minimum_size = Vector2(0, 72)
	var pc_sb := StyleBoxFlat.new()
	pc_sb.bg_color = Color(0.12, 0.08, 0.04, 0.95)
	pc_sb.border_color = Color(0.50, 0.38, 0.20, 0.65)
	pc_sb.set_border_width_all(1)
	pc_sb.set_corner_radius_all(12)
	pc_sb.content_margin_left = 12.0
	pc_sb.content_margin_right = 12.0
	pcount_panel.add_theme_stylebox_override("panel", pc_sb)
	vbox.add_child(pcount_panel)

	var pcount_row := HBoxContainer.new()
	pcount_row.add_theme_constant_override("separation", 10)
	pcount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pcount_panel.add_child(pcount_row)

	var p_btns_row := HBoxContainer.new()
	p_btns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_btns_row.add_theme_constant_override("separation", 8)
	pcount_row.add_child(p_btns_row)

	var p_lbl := CafeSocialTheme.make_title("تعداد بازیکنان:", 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	pcount_row.add_child(p_lbl)

	var refresh_pcount_ui := func():
		var cur_gid: String = str(selected_gid[0])
		var is_multi: bool = GameRegistry.is_multiplayer_game(cur_gid)
		pcount_panel.visible = is_multi
		if not is_multi:
			selected_pcount[0] = 2
		for cnt_key in pcount_btns.keys():
			var pb: Button = pcount_btns[cnt_key]
			var act: bool = (int(cnt_key) == int(selected_pcount[0]))
			pb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 11))
			pb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 11))
		for gk in game_cards.keys():
			var gbtn: Button = game_cards[gk]
			var g_act: bool = (str(gk) == cur_gid)
			gbtn.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.17, 0.08, 0.98) if g_act else Color(0.12, 0.08, 0.04, 0.95),
				CafeSocialTheme.COL_GOLD_BRIGHT if g_act else CafeSocialTheme.COL_BRONZE_BORDER,
				12, 2 if g_act else 1, 8.0, 8.0
			))
			gbtn.add_theme_stylebox_override("hover", gbtn.get_theme_stylebox("normal"))

	var cnt_labels: Dictionary = {2: "۲ نفره", 3: "۳ نفره", 4: "۴ نفره"}
	for cnt in [2, 3, 4]:
		var chosen_cnt: int = int(cnt)
		var pb := CafeSocialTheme.make_button(str(cnt_labels[cnt]), "muted", Vector2(0, 44), 21)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_pcount[0] = chosen_cnt
			refresh_pcount_ui.call()
		)
		pcount_btns[chosen_cnt] = pb
		p_btns_row.add_child(pb)

	for gid in _get_all_challenge_games():
		var g_str: String = str(gid)
		var g_title: String = GameRegistry.get_display_name_fa(g_str)
		var is_multi_g: bool = GameRegistry.is_multiplayer_game(g_str)

		var gbtn := Button.new()
		gbtn.custom_minimum_size = Vector2(0, 96)
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.focus_mode = Control.FOCUS_NONE
		gbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var hm := MarginContainer.new()
		hm.set_anchors_preset(Control.PRESET_FULL_RECT)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hm.add_theme_constant_override("margin_left", 10)
		hm.add_theme_constant_override("margin_right", 10)
		hm.add_theme_constant_override("margin_top", 8)
		hm.add_theme_constant_override("margin_bottom", 8)
		gbtn.add_child(hm)

		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		hm.add_child(h)

		var g_info := VBoxContainer.new()
		g_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_info.alignment = BoxContainer.ALIGNMENT_CENTER
		g_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_info.add_theme_constant_override("separation", 2)
		h.add_child(g_info)

		var g_lbl := CafeSocialTheme.make_title(g_title, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		g_lbl.clip_text = true
		g_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		g_info.add_child(g_lbl)

		var p_badge := CafeSocialTheme.make_badge_pill(
			"۲ تا ۴ نفره" if is_multi_g else "۲ نفره",
			CafeSocialTheme.COL_GOLD_BRIGHT if is_multi_g else CafeSocialTheme.COL_MUTED_SAND,
			Color(0.14, 0.09, 0.04),
			CafeSocialTheme.COL_GOLD_ANTIQUE if is_multi_g else CafeSocialTheme.COL_BRONZE_BORDER,
			15
		)
		p_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		g_info.add_child(p_badge)

		var th_tex := CafeSocialTheme.get_game_thumb(g_str)
		if th_tex != null:
			var th := TextureRect.new()
			th.texture = th_tex
			th.custom_minimum_size = Vector2(66, 66)
			th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			th.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(th)

		gbtn.pressed.connect(func():
			AudioManager.sfx_tap()
			selected_gid[0] = g_str
			refresh_pcount_ui.call()
		)
		game_cards[g_str] = gbtn
		grid.add_child(gbtn)

	refresh_pcount_ui.call()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var bc := CafeSocialTheme.make_button("انصراف", "muted", Vector2(160, 52), 22)
	bc.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(bc)

	var b_submit := CafeSocialTheme.make_button("ارسال چالش دوستانه", "emerald", Vector2(280, 52), 23)
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		b_submit.disabled = true
		var gid_s: String = str(selected_gid[0])
		var cnt_i: int = int(selected_pcount[0])
		NetworkManager.api.create_clan_friendly_challenge(gid_s, cnt_i, func(ok: bool, _c: int, _d: Variant):
			if ok:
				overlay.queue_free()
				host._show_toast("چالش دوستانه «%s» در چت اتحاد اعلام شد!" % GameRegistry.get_display_name_fa(gid_s))
				host.current_clans_subtab = "chat"
				host._refresh_current_tab()
			else:
				if is_instance_valid(b_submit):
					b_submit.disabled = false
				host._show_toast("خطا در ایجاد چالش دوستانه", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	btn_row.add_child(b_submit)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)


static func _get_all_challenge_games() -> Array[String]:
	return [
		GameTypes.TIC_TAC_TOE,
		GameTypes.CHESS,
		GameTypes.BACKGAMMON,
		GameTypes.CHECKERS,
		GameTypes.FOURINROW,
		GameTypes.OTHELLO,
		GameTypes.MILL,
		GameTypes.DOTBOX,
		GameTypes.PENTAGO,
		GameTypes.YINSH,
		GameTypes.QUORIDOR,
		GameTypes.YATZY,
		GameTypes.LUDO,
		GameTypes.RISK,
		GameTypes.UNO,
		GameTypes.COUP,
		GameTypes.MONOPOLY,
		GameTypes.QUIZ,
		GameTypes.BATTLESHIP,
		GameTypes.FEKRBEKR,
		GameTypes.RPC,
		GameTypes.SUDOKU,
		GameTypes.BOXFOUR,
		GameTypes.MNUMBERS,
		GameTypes.MSWEEPER,
	]
