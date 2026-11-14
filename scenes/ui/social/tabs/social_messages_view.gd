class_name SocialMessagesView
extends RefCounted

## Cafe Fekr — Direct Messages View
## Clean portrait-friendly 2-stage flow:
## Stage 1: Conversation List (with New Chat friend picker, previews, unread badges, online status)
## Stage 2: Active Thread (back button, partner header + game invite + profile, distinct bubbles, sticky compose bar)

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	if host._active_dm_partner_id.is_empty():
		_render_conversations_stage(host, body_vbox)
	else:
		_render_thread_stage(host, body_vbox)


static func _render_conversations_stage(host: Control, body_vbox: VBoxContainer) -> void:
	var header_card := PanelContainer.new()
	header_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	body_vbox.add_child(header_card)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	header_card.add_child(hrow)

	var btn_new_dm := CafeSocialTheme.make_button("گفتگوی جدید", "gold", Vector2(185, 54), 21)
	btn_new_dm.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friend_picker_modal(host)
	)
	hrow.add_child(btn_new_dm)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	hrow.add_child(title_col)

	title_col.add_child(CafeSocialTheme.make_title("گفتگوهای خصوصی", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var sub_msg := "بدون پیام خوانده‌نشده" if NetworkManager.unread_dms_count <= 0 else "%s پیام جدید در انتظار خواندن" % GameManager.to_fa_num(NetworkManager.unread_dms_count)
	title_col.add_child(CafeSocialTheme.make_body(sub_msg, 19, CafeSocialTheme.COL_EMERALD_TEXT if NetworkManager.unread_dms_count > 0 else CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.add_child(scroll)

	var list_box := VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 10)
	scroll.add_child(list_box)
	list_box.add_child(CafeSocialTheme.make_loading_state("در حال دریافت گفتگوها..."))

	NetworkManager.api.get_conversations_list(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(list_box):
			return
		for c in list_box.get_children():
			c.queue_free()

		if not ok or typeof(data) != TYPE_DICTIONARY or typeof(data.get("result")) != TYPE_ARRAY:
			list_box.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت گفتگوها",
				"اتصال برقرار نشد. دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): host._refresh_current_tab()
			))
			return

		host._conversations = data["result"]
		if host._conversations.is_empty():
			list_box.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.BADGE_CHAT,
				"هنوز گفتگویی ندارید",
				"از دکمه «گفتگوی جدید» با دوستان خود در کافه فکر گفتگو را آغاز کنید.",
				"شروع گفتگو با دوست", "gold", func(): _open_friend_picker_modal(host)
			))
			return

		for conv in host._conversations:
			if typeof(conv) == TYPE_DICTIONARY:
				list_box.add_child(_build_conversation_card(host, conv))
	)


static func _build_conversation_card(host: Control, conv: Dictionary) -> Control:
	var partner: Dictionary = conv.get("partner", {}) if typeof(conv.get("partner")) == TYPE_DICTIONARY else {}
	var pid := str(partner.get("user_id", partner.get("_id", "")))
	var pname := str(partner.get("username", "بازیکن"))
	var av_id := int(partner.get("image", 0))
	var frame_id := int(partner.get("profile_frame", 0))
	var pres: Dictionary = partner.get("presence", {}) if typeof(partner.get("presence")) == TYPE_DICTIONARY else {"status": str(partner.get("status", "offline"))}
	var p_info := CafeSocialTheme.format_presence(pres)
	var unread := int(conv.get("unread_count", 0))
	var last_msg := str(conv.get("last_message", ""))
	var upd_time := CafeSocialTheme.format_time_fa(str(conv.get("updated_at", "")))

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(0, 108)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var st_norm := CafeSocialTheme.create_highlight_card_style(true) if unread > 0 else CafeSocialTheme.create_card_style()
	var st_hov := st_norm.duplicate()
	st_hov.bg_color = st_norm.bg_color.lightened(0.08)
	st_hov.border_color = CafeSocialTheme.COL_GOLD_BRIGHT
	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hov)
	btn.add_theme_stylebox_override("pressed", st_norm)
	btn.add_theme_stylebox_override("focus", st_norm)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(row)
	btn.add_child(margin)

	# Leftmost: Time + Unread badge
	var meta_col := VBoxContainer.new()
	meta_col.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_col.add_theme_constant_override("separation", 6)
	meta_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(meta_col)

	if not upd_time.is_empty():
		var t_lbl := CafeSocialTheme.make_body(upd_time, 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
		t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_col.add_child(t_lbl)
	if unread > 0:
		var u_pill := CafeSocialTheme.make_badge_pill(
			"%s جدید" % GameManager.to_fa_num(unread),
			CafeSocialTheme.COL_IVORY,
			Color(0.16, 0.56, 0.30, 0.98),
			Color(0.54, 0.96, 0.68),
			18
		)
		u_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_col.add_child(u_pill)

	# Center: Partner Name + Last Message Preview
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 4)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(name_row)

	var raw_st := str(pres.get("status", "offline"))
	var st_badge := CafeSocialTheme.make_status_badge(raw_st, 24.0)
	st_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(st_badge)

	var nm_lbl := CafeSocialTheme.make_title(pname, 26, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	nm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(nm_lbl)

	var preview_txt := last_msg if not last_msg.is_empty() else "گفتگو را شروع کنید..."
	if preview_txt.length() > 54:
		preview_txt = preview_txt.substr(0, 52) + "..."
	var p_lbl := CafeSocialTheme.make_body(preview_txt, 20, CafeSocialTheme.COL_WARM_CREAM if unread > 0 else CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)
	p_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(p_lbl)

	# Rightmost: Avatar
	var av := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 78.0, str(pres.get("status", "offline")), true)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(av)

	ActionVFXManager.apply_button_juice(btn, "tap_button")
	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		host._active_dm_partner_id = pid
		host._active_dm_partner_name = pname
		host._active_dm_partner_info = partner
		host._refresh_current_tab()
	)
	return btn


static func _render_thread_stage(host: Control, body_vbox: VBoxContainer) -> void:
	var partner: Dictionary = host._active_dm_partner_info
	var pid: String = str(host._active_dm_partner_id)
	var pname: String = str(host._active_dm_partner_name)
	var av_id := int(partner.get("image", 0))
	var frame_id := int(partner.get("profile_frame", 0))
	var pres: Dictionary = partner.get("presence", {}) if typeof(partner.get("presence")) == TYPE_DICTIONARY else {"status": str(partner.get("status", "online"))}
	var p_info := CafeSocialTheme.format_presence(pres)

	# Conversation Top Header
	var hdr := PanelContainer.new()
	hdr.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false))
	body_vbox.add_child(hdr)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hdr.add_child(hrow)

	var btn_back := CafeSocialTheme.make_button("بازگشت", "bronze", Vector2(124, 54), 20)
	btn_back.pressed.connect(func():
		AudioManager.sfx_tap()
		host._active_dm_partner_id = ""
		host._active_dm_partner_name = ""
		host._active_dm_partner_info = {}
		host._active_dm_messages.clear()
		host._refresh_current_tab()
	)
	hrow.add_child(btn_back)

	var btn_inv := CafeSocialTheme.make_button("دعوت بازی", "emerald", Vector2(142, 54), 20)
	btn_inv.pressed.connect(func():
		AudioManager.sfx_tap()
		CafeSocialTheme.show_game_invite_modal(host, pid, pname, func(gtitle: String):
			host._show_toast("دعوت‌نامه بازی «%s» برای %s ارسال شد!" % [gtitle, pname])
		)
	)
	hrow.add_child(btn_inv)

	var p_col := VBoxContainer.new()
	p_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_col.alignment = BoxContainer.ALIGNMENT_CENTER
	p_col.add_theme_constant_override("separation", 2)
	hrow.add_child(p_col)

	p_col.add_child(CafeSocialTheme.make_title(pname, 27, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var st_badge_partner := CafeSocialTheme.make_status_badge(str(pres.get("status", "offline")), 26.0)
	st_badge_partner.size_flags_horizontal = Control.SIZE_SHRINK_END
	p_col.add_child(st_badge_partner)

	var av_btn := Button.new()
	av_btn.flat = true
	av_btn.custom_minimum_size = Vector2(68, 68)
	av_btn.focus_mode = Control.FOCUS_NONE
	var av := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 66.0, str(pres.get("status", "offline")), true)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_btn.add_child(av)
	av_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		host._open_player_profile(partner if not partner.is_empty() else {"_id": pid, "username": pname})
	)
	hrow.add_child(av_btn)

	# Messages Scroll Area
	var msg_well := PanelContainer.new()
	msg_well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 12.0, 12.0))
	body_vbox.add_child(msg_well)

	host._dm_messages_scroll = ScrollContainer.new()
	host._dm_messages_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._dm_messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._dm_messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	msg_well.add_child(host._dm_messages_scroll)

	host._dm_messages_vbox = VBoxContainer.new()
	host._dm_messages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._dm_messages_vbox.add_theme_constant_override("separation", 10)
	host._dm_messages_scroll.add_child(host._dm_messages_vbox)
	host._dm_messages_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت پیام‌ها..."))

	# Sticky Bottom Input Bar
	var compose_card := PanelContainer.new()
	compose_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_MAHOGANY_CARD, CafeSocialTheme.COL_GOLD_ANTIQUE, 16, 2, 12.0, 10.0))
	body_vbox.add_child(compose_card)

	var dm_input_row := HBoxContainer.new()
	dm_input_row.add_theme_constant_override("separation", 10)
	compose_card.add_child(dm_input_row)

	var btn_send := CafeSocialTheme.make_button("ارسال", "emerald", Vector2(142, 64), 23)
	dm_input_row.add_child(btn_send)

	host._dm_input = CafeSocialTheme.make_line_edit("پیام خصوصی خود را بنویسید...", 64.0, 23)
	host._dm_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dm_input_row.add_child(host._dm_input)

	btn_send.pressed.connect(func():
		AudioManager.sfx_tap()
		host._send_active_dm()
	)
	host._dm_input.text_submitted.connect(func(_t: String): host._send_active_dm())

	NetworkManager.api.get_direct_messages(pid, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host._dm_messages_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			if typeof(res.get("partner")) == TYPE_DICTIONARY:
				host._active_dm_partner_info = res["partner"]
				var p_fresh: Dictionary = res["partner"]
				var pr_fresh: Dictionary = p_fresh.get("presence", {}) if typeof(p_fresh.get("presence")) == TYPE_DICTIONARY else {}
				if is_instance_valid(st_badge_partner) and st_badge_partner is TextureRect:
					st_badge_partner.texture = CafeSocialTheme.get_status_texture(str(pr_fresh.get("status", "offline")))
			host._active_dm_messages = res.get("messages", []) if typeof(res.get("messages")) == TYPE_ARRAY else []
			NetworkManager.unread_dms_count = max(0, NetworkManager.unread_dms_count - 1)
			host._update_main_tab_buttons()
			render_messages(host)
		else:
			for ch in host._dm_messages_vbox.get_children():
				ch.queue_free()
			host._dm_messages_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"امکان بارگذاری گفتگو وجود ندارد",
				"ممکن است تنظیمات حریم خصوصی این بازیکن اجازه دسترسی ندهد."
			))
	)


static func render_messages(host: Control) -> void:
	if not is_instance_valid(host._dm_messages_vbox):
		return
	for c in host._dm_messages_vbox.get_children():
		c.queue_free()

	if host._active_dm_messages.is_empty():
		host._dm_messages_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.BADGE_CHAT,
			"آغاز گفتگوی تازه",
			"اولین پیام خود را برای %s ارسال کنید!" % host._active_dm_partner_name
		))
		return

	var my_uid := str(GameManager.get_user_id())
	for m in host._active_dm_messages:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var from_me := (str(m.get("from_user_id", "")) == my_uid)
		var txt := str(m.get("text", ""))
		var t_str := CafeSocialTheme.format_time_fa(str(m.get("created_at", "")))
		var read_tick := ("✓✓" if bool(m.get("is_read", false)) else "✓") if from_me else ""

		var align_row := HBoxContainer.new()
		align_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.size_flags_stretch_ratio = 0.22

		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bubble.size_flags_stretch_ratio = 0.78
		bubble.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
			Color(0.13, 0.30, 0.20, 0.97) if from_me else Color(0.22, 0.14, 0.08, 0.97),
			Color(0.46, 0.86, 0.58, 0.88) if from_me else Color(0.76, 0.58, 0.28, 0.85),
			16, 2, 16.0, 12.0
		))

		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 6)
		bubble.add_child(bv)

		bv.add_child(CafeSocialTheme.make_body(txt, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))

		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 8)
		bv.add_child(meta)
		if not read_tick.is_empty():
			meta.add_child(CafeSocialTheme.make_body(read_tick, 16, Color(0.56, 0.96, 0.72), HORIZONTAL_ALIGNMENT_LEFT, false))
		var who_lbl := CafeSocialTheme.make_body(
			("شما" if from_me else host._active_dm_partner_name) + (" • " + t_str if not t_str.is_empty() else ""),
			16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false
		)
		who_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_child(who_lbl)

		if from_me:
			align_row.add_child(spacer)
			align_row.add_child(bubble)
		else:
			align_row.add_child(bubble)
			align_row.add_child(spacer)

		host._dm_messages_vbox.add_child(align_row)

	# Scroll smoothly to bottom
	if is_instance_valid(host._dm_messages_scroll):
		host.call_deferred("_scroll_dm_to_bottom")


static func _open_friend_picker_modal(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 45

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
	card.custom_minimum_size = Vector2(780, 920)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(52, 52)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)

	var ttl := CafeSocialTheme.make_title("شروع گفتگو با دوست", 32, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(52, 52)
	top.add_child(sp)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(sc)

	var flist := VBoxContainer.new()
	flist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flist.add_theme_constant_override("separation", 8)
	sc.add_child(flist)

	var populate := func(arr: Array):
		if not is_instance_valid(flist):
			return
		for ch in flist.get_children():
			ch.queue_free()
		if arr.is_empty():
			flist.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_LOBBY,
				"فهرست دوستان خالی است",
				"ابتدا از بخش «دوستان» بازیکنان را به فهرست دوستان خود اضافه کنید."
			))
			return
		for f in arr:
			if typeof(f) != TYPE_DICTIONARY:
				continue
			var uid := str(f.get("user_id", f.get("_id", "")))
			var uname := str(f.get("username", "بازیکن"))
			var b := CafeSocialTheme.make_button(uname, "bronze", Vector2(0, 62), 23)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				AudioManager.sfx_tap()
				overlay.queue_free()
				host._active_dm_partner_id = uid
				host._active_dm_partner_name = uname
				host._active_dm_partner_info = f
				host._refresh_current_tab()
			)
			flist.add_child(b)

	if host._friends_list.is_empty():
		flist.add_child(CafeSocialTheme.make_loading_state("در حال دریافت دوستان..."))
		NetworkManager.api.get_friends_list(func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				host._friends_list = data["result"]
			populate.call(host._friends_list)
		)
	else:
		populate.call(host._friends_list)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
