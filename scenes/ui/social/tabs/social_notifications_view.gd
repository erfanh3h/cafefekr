class_name SocialNotificationsView
extends RefCounted

## Cafe Fekr — Notifications Center View
## Icon-led antique notification cards with unread accents, formatted timestamps,
## Mark All Read, and contextual one-tap actions.

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	# Top header bar with Mark All Read
	var header_bar := PanelContainer.new()
	header_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	body_vbox.add_child(header_bar)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	header_bar.add_child(hrow)

	var btn_read_all := CafeSocialTheme.make_button("خواندن همه", "emerald", Vector2(175, 52), 21)
	btn_read_all.pressed.connect(func():
		AudioManager.sfx_button()
		btn_read_all.disabled = true
		NetworkManager.api.mark_all_notifications_read(func(ok: bool, _c: int, _d: Variant):
			if ok:
				NetworkManager.unread_notifications_count = 0
				host._update_main_tab_buttons()
				host._show_toast("تمام اعلان‌ها به عنوان خوانده‌شده علامت‌گذاری شدند.")
				host._refresh_current_tab()
			else:
				if is_instance_valid(btn_read_all):
					btn_read_all.disabled = false
		)
	)
	hrow.add_child(btn_read_all)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	hrow.add_child(title_col)

	title_col.add_child(CafeSocialTheme.make_title("مرکز اعلان‌های باشگاه", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var unread_str := "بدون اعلان خوانده‌نشده" if NetworkManager.unread_notifications_count <= 0 else "%s اعلان جدید" % GameManager.to_fa_num(NetworkManager.unread_notifications_count)
	title_col.add_child(CafeSocialTheme.make_body(unread_str, 19, CafeSocialTheme.COL_EMERALD_TEXT if NetworkManager.unread_notifications_count > 0 else CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.add_child(scroll)

	var n_vbox := VBoxContainer.new()
	n_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(n_vbox)
	n_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اعلان‌ها..."))

	NetworkManager.api.get_notifications_list(false, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(n_vbox):
			return
		for c in n_vbox.get_children():
			c.queue_free()

		if not ok or typeof(data) != TYPE_DICTIONARY or typeof(data.get("result")) != TYPE_DICTIONARY:
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت اعلان‌ها",
				"اتصال به سرور برقرار نشد. لطفاً دوباره تلاش کنید.",
				"تلاش مجدد", "gold", func(): host._refresh_current_tab()
			))
			return

		var res: Dictionary = data["result"]
		NetworkManager.unread_notifications_count = int(res.get("unread_count", 0))
		if res.has("unread_dm_count"):
			NetworkManager.unread_dms_count = int(res.get("unread_dm_count", NetworkManager.unread_dms_count))
		host._update_main_tab_buttons()

		var items: Array = res.get("items", []) if typeof(res.get("items")) == TYPE_ARRAY else []
		if items.is_empty():
			n_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_STAR,
				"اعلانی وجود ندارد",
				"دعوت‌نامه‌های بازی، درخواست‌های دوستی و رویدادهای کلن شما اینجا نمایش داده می‌شوند."
			))
			return

		for n in items:
			if typeof(n) == TYPE_DICTIONARY:
				n_vbox.add_child(_build_notification_card(host, n))
	)


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
	var nid := str(n.get("notification_id", ""))
	var ntype := str(n.get("type", ""))
	var is_read := bool(n.get("is_read", false))
	var payload: Dictionary = n.get("payload", {}) if typeof(n.get("payload")) == TYPE_DICTIONARY else {}
	var actor_id := str(n.get("actor_id", ""))
	var actor_name := str(n.get("actor_name", "بازیکن"))
	var time_str := CafeSocialTheme.format_time_fa(str(n.get("created_at", "")))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(
		CafeSocialTheme.COL_WALNUT_CARD if is_read else Color(0.22, 0.14, 0.07, 0.98),
		CafeSocialTheme.COL_BRONZE_BORDER if is_read else CafeSocialTheme.COL_GOLD_BRIGHT
	))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	if not time_str.is_empty():
		top_row.add_child(CafeSocialTheme.make_badge_pill(
			time_str, CafeSocialTheme.COL_MUTED_SAND, Color(0.08, 0.05, 0.03, 0.9), CafeSocialTheme.COL_BRONZE_BORDER, 17
		))

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
	var has_acts := false

	if ntype == "friend_request_received" and payload.has("request_id"):
		has_acts = true
		var rid := str(payload.get("request_id", ""))
		var b_acc := CafeSocialTheme.make_friend_button("accept", "پذیرش دوستی", Vector2(0, 46))
		b_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.respond_friend_request(rid, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
					host._show_toast("درخواست دوستی پذیرفته شد!")
					host._refresh_current_tab()
			)
		)
		act_row.add_child(b_acc)

		var b_rej := CafeSocialTheme.make_friend_button("reject", "رد", Vector2(110, 46))
		b_rej.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.respond_friend_request(rid, "reject", func(_ok: bool, _c: int, _d: Variant):
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
				host._refresh_current_tab()
			)
		)
		act_row.add_child(b_rej)

	elif ntype == "clan_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var inv_id := str(payload.get("invite_id", ""))
		var b_join := CafeSocialTheme.make_button("پیوستن به کلن", "emerald", Vector2(0, 46), 19)
		b_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
					host._show_toast("به کلن خوش آمدید!")
					host._switch_main_tab("clans")
			)
		)
		act_row.add_child(b_join)

	elif ntype == "direct_message_received" and not actor_id.is_empty():
		has_acts = true
		var b_open_dm := CafeSocialTheme.make_button("مشاهده گفتگو", "sapphire", Vector2(0, 46), 19)
		b_open_dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_open_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			if not is_read:
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
			host.open_direct_message_with(actor_id, actor_name)
		)
		act_row.add_child(b_open_dm)

	elif ntype == "game_invitation_received" and payload.has("invite_id"):
		has_acts = true
		var g_inv_id := str(payload.get("invite_id", ""))
		var b_gacc := CafeSocialTheme.make_button("قبول دعوت بازی", "emerald", Vector2(0, 46), 19)
		b_gacc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_gacc.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.respond_game_invite_realtime(g_inv_id, "accept")
			if not is_read:
				NetworkManager.api.mark_notification_read(nid, func(_o, _c2, _d2): pass)
		)
		act_row.add_child(b_gacc)

	if not is_read:
		has_acts = true
		var b_mark := CafeSocialTheme.make_button("خوانده شد", "bronze", Vector2(140, 46), 19)
		b_mark.pressed.connect(func():
			AudioManager.sfx_tap()
			b_mark.disabled = true
			NetworkManager.api.mark_notification_read(nid, func(_ok: bool, _c2: int, _d2: Variant):
				host._refresh_current_tab()
			)
		)
		act_row.add_child(b_mark)

	if has_acts:
		vbox.add_child(act_row)

	return card
