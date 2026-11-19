class_name SocialNotificationsView
extends RefCounted

## Cafe Fekr — Notifications Center View
## Icon-led antique notification cards with unread accents, formatted timestamps,
## Mark All Read, and contextual one-tap actions.

static func _has_ancestor_scroll(node: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


static func _notify_host_toast(host: Control, msg: String) -> void:
	if not is_instance_valid(host):
		return
	_show_bottom_center_toast(host, msg)

static func _show_bottom_center_toast(host: Control, msg: String) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	var root: Viewport = host.get_viewport()
	if not root:
		return

	var old = root.find_child("SocialBottomCenterToast", false, false)
	if is_instance_valid(old):
		old.queue_free()

	var toast_layer = CanvasLayer.new()
	toast_layer.name = "SocialBottomCenterToast"
	toast_layer.layer = 120
	root.add_child(toast_layer)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 32.0
	panel.offset_right = -32.0
	panel.offset_bottom = -96.0
	panel.offset_top = -156.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.05, 0.96)
	sb.border_color = Color(0.92, 0.74, 0.30, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	toast_layer.add_child(panel)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tw = toast_layer.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.20)
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.30)
	tw.tween_callback(func():
		if is_instance_valid(toast_layer):
			toast_layer.queue_free()
	)


static func _refresh_host(host: Control) -> void:
	if not is_instance_valid(host):
		return
	if host.has_method("_refresh_current_tab"):
		host._refresh_current_tab()
	elif host.has_method("refresh_all"):
		host.refresh_all()


static func _set_unread_subtitle(lbl: Label, unread_cnt: int) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.text = "بدون اعلان خوانده‌نشده" if unread_cnt <= 0 else "%s اعلان جدید" % GameManager.to_fa_num(unread_cnt)
	lbl.add_theme_color_override(
		"font_color",
		CafeSocialTheme.COL_EMERALD_TEXT if unread_cnt > 0 else CafeSocialTheme.COL_MUTED_SAND
	)


static func render(host: Control, body_vbox: VBoxContainer) -> void:
	# Top header bar with Mark All Read
	var header_margin := MarginContainer.new()
	header_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_right", 16)
	body_vbox.add_child(header_margin)

	var header_bar := PanelContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 128)
	header_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 44.0, 20.0))
	header_margin.add_child(header_bar)

	var hrow := HBoxContainer.new()
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	hrow.add_theme_constant_override("separation", 14)
	header_bar.add_child(hrow)

	var btn_read_all := TextureButton.new()
	btn_read_all.custom_minimum_size = Vector2(64, 64)
	btn_read_all.ignore_texture_size = true
	btn_read_all.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_read_all.texture_normal = preload("res://assets/images/frames/check.png")
	btn_read_all.focus_mode = Control.FOCUS_NONE
	btn_read_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_read_all, "tap_button")

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)

	title_col.add_child(CafeSocialTheme.make_title("مرکز اعلان‌های باشگاه", 29, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var lbl_unread_sub: Label = CafeSocialTheme.make_body("", 21, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT)
	_set_unread_subtitle(lbl_unread_sub, NetworkManager.unread_notifications_count)
	title_col.add_child(lbl_unread_sub)

	btn_read_all.disabled = (NetworkManager.unread_notifications_count <= 0)
	btn_read_all.pressed.connect(func():
		AudioManager.sfx_button()
		btn_read_all.disabled = true
		NetworkManager.api.mark_all_notifications_read(func(ok: bool, _c: int, _d: Variant):
			if ok:
				NetworkManager.unread_notifications_count = 0
				NetworkManager.notify_social_badges_changed()
				_set_unread_subtitle(lbl_unread_sub, 0)
				if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
					host._update_main_tab_buttons()
				_notify_host_toast(host, "تمام اعلان‌ها به عنوان خوانده‌شده علامت‌گذاری شدند.")
				_refresh_host(host)
			else:
				if is_instance_valid(btn_read_all):
					btn_read_all.disabled = false
		)
	)
	hrow.add_child(btn_read_all)
	hrow.add_child(title_col)

	# Avoid nested ScrollContainer collapsing to 0px height when body_vbox is already inside a ScrollContainer (e.g. UserTab)
	var n_vbox := VBoxContainer.new()
	n_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_vbox.add_theme_constant_override("separation", 12)

	if _has_ancestor_scroll(body_vbox):
		var list_margin := MarginContainer.new()
		list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_margin.add_theme_constant_override("margin_left", 6)
		list_margin.add_theme_constant_override("margin_right", 6)
		list_margin.add_child(n_vbox)
		body_vbox.add_child(list_margin)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 260)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(n_vbox)
		body_vbox.add_child(scroll)

	n_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اعلان‌ها..."))

	NetworkManager.api.get_notifications_list(false, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(n_vbox):
			return
		for c in n_vbox.get_children():
			c.queue_free()

		if not ok or typeof(data) != TYPE_DICTIONARY:
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت اعلان‌ها",
				"اتصال به سرور برقرار نشد. لطفاً دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): _refresh_host(host)
			))
			return

		var items: Array = []
		var unread_cnt: int = NetworkManager.unread_notifications_count
		var raw_result: Variant = data.get("result", null)

		if typeof(raw_result) == TYPE_DICTIONARY:
			var res: Dictionary = raw_result
			if res.has("items") and typeof(res["items"]) == TYPE_ARRAY:
				items = res["items"]
			elif res.has("notifications") and typeof(res["notifications"]) == TYPE_ARRAY:
				items = res["notifications"]
			if res.has("unread_count"):
				unread_cnt = int(res.get("unread_count", 0))
			else:
				unread_cnt = _count_unread_items(items)
			if res.has("unread_dm_count"):
				NetworkManager.unread_dms_count = int(res.get("unread_dm_count", NetworkManager.unread_dms_count))
		elif typeof(raw_result) == TYPE_ARRAY:
			items = raw_result
			unread_cnt = _count_unread_items(items)
		elif data.has("items") and typeof(data["items"]) == TYPE_ARRAY:
			items = data["items"]
			unread_cnt = int(data.get("unread_count", _count_unread_items(items)))
		elif data.has("notifications") and typeof(data["notifications"]) == TYPE_ARRAY:
			items = data["notifications"]
			unread_cnt = int(data.get("unread_count", _count_unread_items(items)))
		else:
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت اعلان‌ها",
				"پاسخ سرور نامعتبر بود. لطفاً دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): _refresh_host(host)
			))
			return

		NetworkManager.unread_notifications_count = unread_cnt
		NetworkManager.notify_social_badges_changed()
		_set_unread_subtitle(lbl_unread_sub, unread_cnt)
		if is_instance_valid(btn_read_all):
			btn_read_all.disabled = (unread_cnt <= 0 and items.is_empty())
		if is_instance_valid(host) and host.has_method("_update_main_tab_buttons"):
			host._update_main_tab_buttons()

		if items.is_empty():
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_STAR,
				"اعلانی وجود ندارد",
				"دعوت‌نامه‌های بازی، درخواست‌های دوستی و رویدادهای کلن شما اینجا نمایش داده می‌شوند."
			))
		else:
			for n in items:
				if typeof(n) == TYPE_DICTIONARY:
					n_vbox.add_child(_build_notification_card(host, n))

		var bottom_spacer := Control.new()
		bottom_spacer.custom_minimum_size = Vector2(0, 44)
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n_vbox.add_child(bottom_spacer)
	)


static func _count_unread_items(items: Array) -> int:
	var count: int = 0
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and not bool(item.get("is_read", false)):
			count += 1
	return count


static func _get_notif_icon(ntype: String) -> Texture2D:
	if ntype.begins_with("friend"):
		return CafeSocialTheme.ICO_LOBBY
	if ntype.begins_with("clan"):
		return CafeSocialTheme.ICO_RANK
	if ntype.begins_with("direct_message"):
		return CafeSocialTheme.BADGE_CHAT
	if ntype.begins_with("game_"):
		return CafeSocialTheme.ICO_CUP
	return CafeSocialTheme.ICO_SPARKLE


static func _build_notification_card(host: Control, n: Dictionary) -> PanelContainer:
	var nid: String = str(n.get("notification_id", n.get("_id", n.get("id", ""))))
	var ntype: String = str(n.get("type", ""))
	var is_read: bool = bool(n.get("is_read", false))
	var payload: Dictionary = n.get("payload", {}) if typeof(n.get("payload")) == TYPE_DICTIONARY else {}
	var actor_id: String = str(n.get("actor_id", ""))
	var actor_name: String = str(n.get("actor_name", "بازیکن"))
	var time_str: String = CafeSocialTheme.format_time_fa(str(n.get("created_at", "")))

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = CafeSocialTheme.create_card_style(
		Color(0.14, 0.09, 0.05, 0.94) if is_read else Color(0.18, 0.12, 0.06, 0.97),
		CafeSocialTheme.COL_BRONZE_BORDER if is_read else Color("#F5C542"),
		16, 1 if is_read else 2, 16.0, 14.0
	)
	if not is_read:
		card_style.border_width_right = 5
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	if not time_str.is_empty():
		var pill_time: PanelContainer = CafeSocialTheme.make_badge_pill(
			time_str, CafeSocialTheme.COL_MUTED_SAND, Color(0.08, 0.05, 0.03, 0.9), CafeSocialTheme.COL_BRONZE_BORDER, 17
		)
		pill_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_row.add_child(pill_time)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	top_row.add_child(text_col)

	text_col.add_child(CafeSocialTheme.make_title(
		str(n.get("title", "اعلان")),
		25,
		CafeSocialTheme.COL_WARM_CREAM if is_read else CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))
	text_col.add_child(CafeSocialTheme.make_body(
		str(n.get("body", "")),
		20,
		CafeSocialTheme.COL_MUTED_SAND if is_read else CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))

	var ico_wrap := PanelContainer.new()
	ico_wrap.custom_minimum_size = Vector2(56, 56)
	ico_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ico_wrap.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
		Color(0.10, 0.06, 0.03, 0.95),
		CafeSocialTheme.COL_BRONZE_BORDER if is_read else CafeSocialTheme.COL_GOLD_BRIGHT,
		14, 2, 8.0, 8.0
	))
	var ico := TextureRect.new()
	ico.texture = _get_notif_icon(ntype)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico_wrap.add_child(ico)
	top_row.add_child(ico_wrap)

	# Contextual action buttons row
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	var has_acts: bool = false

	if ntype == "friend_request_received" and payload.has("request_id"):
		has_acts = true
		var rid: String = str(payload.get("request_id", ""))
		var b_acc := CafeSocialTheme.make_friend_button("accept", "پذیرش دوستی", Vector2(0, 46))
		b_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			_show_notification_result(act_row, "✓ درخواست دوستی پذیرفته شد", Color(0.40, 0.90, 0.55))
			NetworkManager.api.respond_friend_request(rid, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
					_notify_host_toast(host, "درخواست دوستی پذیرفته شد!")
					_refresh_host(host)
			)
		)
		act_row.add_child(b_acc)

		var b_rej := CafeSocialTheme.make_friend_button("reject", "رد", Vector2(110, 46))
		b_rej.pressed.connect(func():
			AudioManager.sfx_tap()
			_show_notification_result(act_row, "✕ درخواست دوستی رد شد", Color(0.95, 0.45, 0.45))
			NetworkManager.api.respond_friend_request(rid, "reject", func(_ok: bool, _c: int, _d: Variant):
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
				_refresh_host(host)
			)
		)
		act_row.add_child(b_rej)

	elif ntype == "clan_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var inv_id: String = str(payload.get("invite_id", ""))
		var b_join := CafeSocialTheme.make_button("پیوستن به کلن", "emerald", Vector2(0, 46), 22)
		b_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			_show_notification_result(act_row, "✓ عضویت در کلن پذیرفته شد", Color(0.40, 0.90, 0.55))
			NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
					_notify_host_toast(host, "به کلن خوش آمدید!")
					if is_instance_valid(host) and host.has_method("_switch_main_tab"):
						host._switch_main_tab("clans")
					else:
						_refresh_host(host)
			)
		)
		act_row.add_child(b_join)

		var b_crej := CafeSocialTheme.make_button("رد دعوت", "crimson", Vector2(110, 46), 22)
		b_crej.pressed.connect(func():
			AudioManager.sfx_tap()
			_show_notification_result(act_row, "✕ دعوت به کلن رد شد", Color(0.95, 0.45, 0.45))
			NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(_ok: bool, _c: int, _d: Variant):
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
				_refresh_host(host)
			)
		)
		act_row.add_child(b_crej)

	elif ntype == "direct_message_received" and not actor_id.is_empty():
		has_acts = true
		var b_open_dm := CafeSocialTheme.make_button("مشاهده گفتگو", "sapphire", Vector2(0, 46), 22)
		b_open_dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_open_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			if not is_read:
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
			if is_instance_valid(host) and host.has_method("open_direct_message_with"):
				host.open_direct_message_with(actor_id, actor_name)
			else:
				_notify_host_toast(host, "برای پاسخ، تب اجتماعی و بخش گفتگوها را باز کنید.")
				_refresh_host(host)
		)
		act_row.add_child(b_open_dm)

	elif ntype == "game_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var g_inv_id: String = str(payload.get("invite_id", ""))
		var b_gacc := CafeSocialTheme.make_button("قبول دعوت بازی", "emerald", Vector2(0, 46), 22)
		b_gacc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_gacc.pressed.connect(func():
			AudioManager.sfx_button()
			_show_notification_result(act_row, "✓ دعوت مسابقه پذیرفته شد", Color(0.40, 0.90, 0.55))
			NetworkManager.respond_game_invite_realtime(g_inv_id, "accept")
			if not is_read:
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
		)
		act_row.add_child(b_gacc)

		var b_grej := CafeSocialTheme.make_button("رد دعوت", "crimson", Vector2(140, 46), 22)
		b_grej.pressed.connect(func():
			AudioManager.sfx_tap()
			b_grej.disabled = true
			_show_notification_result(act_row, "✕ دعوت مسابقه رد شد", Color(0.95, 0.45, 0.45))
			NetworkManager.respond_game_invite_realtime(g_inv_id, "reject")
			NetworkManager.api.mark_notification_read(nid, func(_ok: bool, _c2: int, _d2: Variant):
				_refresh_host(host)
			)
		)
		act_row.add_child(b_grej)

	elif not is_read:
		has_acts = true
		var b_mark := CafeSocialTheme.make_button("خوانده شد", "bronze", Vector2(140, 46), 22)
		b_mark.pressed.connect(func():
			AudioManager.sfx_tap()
			b_mark.disabled = true
			NetworkManager.api.mark_notification_read(nid, func(_ok: bool, _c2: int, _d2: Variant):
				_refresh_host(host)
			)
		)
		act_row.add_child(b_mark)

	if has_acts:
		vbox.add_child(act_row)

	return card

static func _show_notification_result(act_row: HBoxContainer, text: String, color: Color) -> void:
	if not is_instance_valid(act_row):
		return
	for ch in act_row.get_children():
		ch.visible = false
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	act_row.add_child(lbl)
