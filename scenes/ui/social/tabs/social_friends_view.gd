class_name SocialFriendsView
extends RefCounted

## Cafe Fekr — Friends Tab View
## Subsections: My Friends, Requests (Incoming/Outgoing), Search & Discover.
## Blocked player management resides strictly in UserProfileDialog Privacy Settings.

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	# Sub-navigation bar (3 antique subtabs)
	var sub_bar := PanelContainer.new()
	sub_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 8.0, 8.0))
	body_vbox.add_child(sub_bar)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	sub_bar.add_child(sub_row)

	var subtab_defs := [
		{"id": "list", "label": "دوستان من (%s)" % GameManager.to_fa_num(host._friends_list.size()), "badge": 0},
		{"id": "requests", "label": "درخواست‌ها", "badge": host._incoming_requests.size()},
		{"id": "search", "label": "یافتن بازیکن", "badge": 0},
	]
	for sd in subtab_defs:
		var sid: String = sd["id"]
		var is_act: bool = (host.current_friends_subtab == sid)
		var b := CafeSocialTheme.make_subtab(sd["label"], is_act, int(sd["badge"]))
		b.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_friends_subtab = sid
			host._refresh_current_tab()
		)
		sub_row.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(list_vbox)

	if host.current_friends_subtab == "list":
		list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت فهرست دوستان..."))
		NetworkManager.api.get_friends_list(func(ok: bool, _code: int, data: Variant):
			if not is_instance_valid(list_vbox):
				return
			for c in list_vbox.get_children():
				c.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
				host._friends_list = data["result"] if typeof(data["result"]) == TYPE_ARRAY else []
				host._update_main_tab_buttons()
				_populate_friends_list(host, list_vbox)
			else:
				list_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.ICO_INFO,
					"خطا در دریافت دوستان",
					"لطفاً اتصال خود را بررسی کرده و دوباره تلاش کنید.",
					"تلاش مجدد", "gold", func(): host._refresh_current_tab()
				))
		)
	elif host.current_friends_subtab == "requests":
		list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت درخواست‌های دوستی..."))
		NetworkManager.api.get_friend_requests(func(ok: bool, _code: int, data: Variant):
			if not is_instance_valid(list_vbox):
				return
			for c in list_vbox.get_children():
				c.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
				var r: Dictionary = data["result"] if typeof(data["result"]) == TYPE_DICTIONARY else {}
				host._incoming_requests = r.get("incoming", [])
				host._outgoing_requests = r.get("outgoing", [])
				host._update_main_tab_buttons()
				_populate_requests(host, list_vbox)
			else:
				list_vbox.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.ICO_INFO,
					"خطا در دریافت درخواست‌ها",
					"در حال حاضر امکان بارگذاری درخواست‌ها وجود ندارد.",
					"تلاش مجدد", "gold", func(): host._refresh_current_tab()
				))
		)
	else:
		_populate_search_and_discover(host, list_vbox)


static func _populate_friends_list(host: Control, list_vbox: VBoxContainer) -> void:
	if host._friends_list.is_empty():
		list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_LOBBY,
			"هنوز دوستی در باشگاه ندارید",
			"از بخش «یافتن بازیکن» هم‌بازی‌های اخیر یا دوستان جدید خود را پیدا کنید و به رقابت دعوت نمایید.",
			"یافتن بازیکن", "gold", func():
				host.current_friends_subtab = "search"
				host._refresh_current_tab()
		))
		return

	# Group summary header
	var online_cnt := 0
	for f in host._friends_list:
		if typeof(f) == TYPE_DICTIONARY:
			var pr: Dictionary = f.get("presence", {}) if typeof(f.get("presence")) == TYPE_DICTIONARY else {}
			var st := str(pr.get("status", f.get("status", "offline")))
			if st != "offline":
				online_cnt += 1

	list_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"فهرست دوستان شما",
		CafeSocialTheme.ICO_LOBBY,
		"%s دوست   •   %s نفر آنلاین" % [GameManager.to_fa_num(host._friends_list.size()), GameManager.to_fa_num(online_cnt)]
	))

	for f in host._friends_list:
		if typeof(f) == TYPE_DICTIONARY:
			list_vbox.add_child(_build_player_card(host, f, "friend"))


static func _populate_requests(host: Control, list_vbox: VBoxContainer) -> void:
	list_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"درخواست‌های دریافتی",
		CafeSocialTheme.ICO_STAR,
		"%s درخواست در انتظار تایید شما" % GameManager.to_fa_num(host._incoming_requests.size())
	))
	if host._incoming_requests.is_empty():
		list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_CHECK,
			"درخواست دریافتی جدیدی نیست",
			"تمام درخواست‌های دوستی خود را بررسی کرده‌اید."
		))
	else:
		for req in host._incoming_requests:
			if typeof(req) == TYPE_DICTIONARY and typeof(req.get("user")) == TYPE_DICTIONARY:
				list_vbox.add_child(_build_player_card(host, req["user"], "incoming_req", str(req.get("request_id", ""))))

	list_vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"درخواست‌های ارسالی",
		CafeSocialTheme.ICO_EXP,
		"%s درخواست در انتظار پاسخ دیگران" % GameManager.to_fa_num(host._outgoing_requests.size())
	))
	if host._outgoing_requests.is_empty():
		list_vbox.add_child(CafeSocialTheme.make_body("درخواست ارسالی در انتظاری ندارید.", 20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		for req in host._outgoing_requests:
			if typeof(req) == TYPE_DICTIONARY and typeof(req.get("user")) == TYPE_DICTIONARY:
				list_vbox.add_child(_build_player_card(host, req["user"], "outgoing_req", str(req.get("request_id", ""))))


static func _populate_search_and_discover(host: Control, list_vbox: VBoxContainer) -> void:
	# Search box inside framed plaque
	var search_card := PanelContainer.new()
	search_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	list_vbox.add_child(search_card)

	var sc_vbox := VBoxContainer.new()
	sc_vbox.add_theme_constant_override("separation", 10)
	search_card.add_child(sc_vbox)

	sc_vbox.add_child(CafeSocialTheme.make_title("جستجوی بازیکنان کافه فکر", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	var search_bar := HBoxContainer.new()
	search_bar.add_theme_constant_override("separation", 10)
	sc_vbox.add_child(search_bar)

	var inp_q := CafeSocialTheme.make_line_edit("نام کاربری یا شناسه بازیکن را وارد کنید...", 62.0, 22)
	inp_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_bar.add_child(inp_q)

	var results_box := VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 10)

	var do_search := func():
		var q := inp_q.text.strip_edges()
		if q.is_empty():
			return
		for ch in results_box.get_children():
			ch.queue_free()
		results_box.add_child(CafeSocialTheme.make_loading_state("در حال جستجو..."))
		NetworkManager.api.search_social_players(q, func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(results_box):
				return
			for ch in results_box.get_children():
				ch.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
				var arr: Array = data["result"]
				if arr.is_empty():
					results_box.add_child(CafeSocialTheme.make_empty_state(
						CafeSocialTheme.ICO_INFO,
						"بازیکنی یافت نشد",
						"نام کاربری دقیق‌تر یا بخشی از شناسه بازیکن را امتحان کنید."
					))
				else:
					results_box.add_child(CafeSocialTheme.make_ornate_section_header("نتایج جستجو", CafeSocialTheme.ICO_STAR))
					for item in arr:
						if typeof(item) == TYPE_DICTIONARY:
							results_box.add_child(_build_player_card(host, item, "search"))
		)

	var btn_search := CafeSocialTheme.make_button("جستجو", "gold", Vector2(150, 62), 23)
	btn_search.pressed.connect(func():
		AudioManager.sfx_tap()
		do_search.call()
	)
	inp_q.text_submitted.connect(func(_t: String): do_search.call())
	search_bar.add_child(btn_search)
	list_vbox.add_child(results_box)

	var discover_box := VBoxContainer.new()
	discover_box.add_theme_constant_override("separation", 10)
	discover_box.add_child(CafeSocialTheme.make_loading_state("در حال یافتن هم‌بازی‌های اخیر و پیشنهادها..."))
	list_vbox.add_child(discover_box)

	NetworkManager.api.get_social_discover(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(discover_box):
			return
		for ch in discover_box.get_children():
			ch.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var res: Dictionary = data["result"]
			var recent: Array = res.get("recently_played", [])
			var suggested: Array = res.get("suggested_friends", [])

			discover_box.add_child(CafeSocialTheme.make_ornate_section_header(
				"هم‌بازی‌های اخیر شما", CafeSocialTheme.ICO_HISTORY, "بازیکنانی که اخیراً با آن‌ها رقابت کرده‌اید"
			))
			if recent.is_empty():
				discover_box.add_child(CafeSocialTheme.make_body("هنوز هم‌بازی اخیری ثبت نشده است.", 20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
			else:
				for r_u in recent:
					if typeof(r_u) == TYPE_DICTIONARY:
						discover_box.add_child(_build_player_card(host, r_u, "search"))

			discover_box.add_child(CafeSocialTheme.make_ornate_section_header(
				"پیشنهادهای دوستی", CafeSocialTheme.ICO_RANKING, "بر اساس دوستان مشترک و هم‌سطحی شما"
			))
			if suggested.is_empty():
				discover_box.add_child(CafeSocialTheme.make_body("در حال حاضر پیشنهاد جدیدی موجود نیست.", 20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
			else:
				for s_u in suggested:
					if typeof(s_u) == TYPE_DICTIONARY:
						discover_box.add_child(_build_player_card(host, s_u, "search"))
	)


static func _build_player_card(host: Control, u: Dictionary, mode: String, req_id: String = "") -> PanelContainer:
	var uid := str(u.get("user_id", u.get("_id", "")))
	var uname := str(u.get("username", "بازیکن"))
	var av_id := int(u.get("image", u.get("avatar", 0)))
	var frame_id := int(u.get("profile_frame", 0))
	var score := int(u.get("score", 0))
	var lvl := int(u.get("level", GameManager.calculate_level(int(u.get("xp", 0)))))
	var rank_title := str(u.get("rank_title", ""))
	var clan_info: Dictionary = u.get("clan", {}) if typeof(u.get("clan")) == TYPE_DICTIONARY else {}
	var clan_tag := str(clan_info.get("tag", "")) if not clan_info.is_empty() else ""
	var pres: Dictionary = u.get("presence", {}) if typeof(u.get("presence")) == TYPE_DICTIONARY else {"status": str(u.get("status", "offline"))}
	var p_info := CafeSocialTheme.format_presence(pres)

	var is_online_active := (str(pres.get("status", "offline")) != "offline")
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true) if p_info["is_in_game"] else CafeSocialTheme.create_card_style(
		CafeSocialTheme.COL_MAHOGANY_CARD if is_online_active else CafeSocialTheme.COL_WALNUT_CARD,
		CafeSocialTheme.COL_GOLD_ANTIQUE if is_online_active else CafeSocialTheme.COL_BRONZE_BORDER
	))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	card.add_child(root)

	# Row 1: Identity & Status
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	root.add_child(top_row)

	# Left side: Status + Score/Level badge pills
	var stats_col := VBoxContainer.new()
	stats_col.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_col.add_theme_constant_override("separation", 6)
	top_row.add_child(stats_col)

	var raw_st := str(pres.get("status", "offline"))
	stats_col.add_child(CafeSocialTheme.make_status_badge(raw_st, 32.0))

	var stat_pills := HBoxContainer.new()
	stat_pills.add_theme_constant_override("separation", 6)
	stat_pills.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_col.add_child(stat_pills)
	stat_pills.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(score), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03, 0.94), CafeSocialTheme.COL_BRONZE_BORDER, 17))
	stat_pills.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(lvl), CafeSocialTheme.COL_EMERALD_TEXT, Color(0.10, 0.06, 0.03, 0.94), CafeSocialTheme.COL_EMERALD_BORDER, 17))

	# Center/Right: Name + Clan + Title (expandable, right aligned, tappable for profile)
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.mouse_filter = Control.MOUSE_FILTER_PASS
	info_col.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	info_col.add_theme_constant_override("separation", 4)
	var tap_start_y: Array[float] = [-1.0]
	info_col.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				tap_start_y[0] = ev.global_position.y
			elif tap_start_y[0] >= 0.0:
				var moved: float = absf(ev.global_position.y - tap_start_y[0])
				tap_start_y[0] = -1.0
				if moved <= 14.0:
					AudioManager.sfx_tap()
					host._open_player_profile(u)
	)
	top_row.add_child(info_col)

	var name_line := uname
	if not clan_tag.is_empty():
		name_line += "  [%s]" % clan_tag
	info_col.add_child(CafeSocialTheme.make_title(name_line, 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))

	var sub_parts: Array[String] = []
	if not rank_title.is_empty():
		sub_parts.append(rank_title)
	var p_title := str(u.get("profile_title", ""))
	if not p_title.is_empty():
		sub_parts.append(p_title)
	if int(u.get("mutual_friends", 0)) > 0:
		sub_parts.append("%s دوست مشترک" % GameManager.to_fa_num(int(u.get("mutual_friends", 0))))
	if sub_parts.is_empty():
		sub_parts.append("عضو باشگاه کافه فکر")
	info_col.add_child(CafeSocialTheme.make_body(" • ".join(sub_parts), 19, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Rightmost: Avatar Frame clickable to view profile
	var av_btn := Button.new()
	av_btn.flat = true
	av_btn.custom_minimum_size = Vector2(86, 86)
	av_btn.focus_mode = Control.FOCUS_NONE
	av_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var av_badge := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 84.0, str(pres.get("status", "offline")), true)
	av_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_btn.add_child(av_badge)
	av_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		host._open_player_profile(u)
	)
	top_row.add_child(av_btn)

	# Row 2: Contextual Actions
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	root.add_child(act_row)

	var btn_prof := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(0, 50), 20)
	btn_prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_prof.pressed.connect(func():
		AudioManager.sfx_tap()
		host._open_player_profile(u)
	)

	if mode == "friend":
		var extra_drawer := HBoxContainer.new()
		extra_drawer.visible = false
		extra_drawer.add_theme_constant_override("separation", 8)

		var btn_more := CafeSocialTheme.make_button("بیشتر", "muted", Vector2(98, 50), 20)
		btn_more.pressed.connect(func():
			AudioManager.sfx_tap()
			extra_drawer.visible = not extra_drawer.visible
		)
		act_row.add_child(btn_more)

		act_row.add_child(btn_prof)

		var btn_dm := CafeSocialTheme.make_button("پیام", "sapphire", Vector2(0, 50), 20)
		btn_dm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			host.open_direct_message_with(uid, uname)
		)
		act_row.add_child(btn_dm)

		var btn_inv := CafeSocialTheme.make_button("دعوت بازی", "emerald", Vector2(0, 50), 20)
		btn_inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_inv.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_game_invite_modal(host, uid, uname, func(gtitle: String):
				host._show_toast("دعوت‌نامه بازی «%s» برای %s ارسال شد!" % [gtitle, uname])
			)
		)
		act_row.add_child(btn_inv)

		if p_info["is_in_game"]:
			var btn_spec := CafeSocialTheme.make_button("تماشا", "gold", Vector2(118, 50), 20)
			btn_spec.pressed.connect(func():
				AudioManager.sfx_button()
				NetworkManager.request_spectate_game(str(p_info["game_id"]))
				host._show_toast("درخواست تماشای مسابقه ارسال شد...")
			)
			act_row.add_child(btn_spec)

		# Secondary More Drawer (Remove / Block / Report)
		root.add_child(extra_drawer)
		var b_rem := CafeSocialTheme.make_friend_button("remove", "حذف دوست", Vector2(0, 48))
		b_rem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_rem.pressed.connect(func():
			CafeSocialTheme.show_confirm_modal(
				host, "حذف دوست",
				"آیا مطمئن هستید می‌خواهید «%s» را از فهرست دوستان خود حذف کنید؟" % uname,
				"بله، حذف شود", true,
				func():
					NetworkManager.api.remove_friend(uid, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._show_toast("«%s» از دوستان شما حذف شد." % uname)
							host._refresh_current_tab()
					)
			)
		)
		extra_drawer.add_child(b_rem)

		var b_blk := CafeSocialTheme.make_button("مسدود کردن", "muted", Vector2(0, 48), 19)
		b_blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_blk.pressed.connect(func():
			CafeSocialTheme.show_confirm_modal(
				host, "مسدود کردن بازیکن",
				"پس از مسدود کردن «%s»، امکان ارسال پیام یا درخواست بازی بین شما وجود نخواهد داشت." % uname,
				"مسدود شود", true,
				func():
					NetworkManager.api.block_player(uid, "Blocked from friends", func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._show_toast("«%s» مسدود شد. مدیریت مسدودها در پروفایل شماست." % uname)
							host._refresh_current_tab()
					)
			)
		)
		extra_drawer.add_child(b_blk)

		var b_rep := CafeSocialTheme.make_button("گزارش تخلف", "muted", Vector2(0, 48), 19)
		b_rep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_rep.pressed.connect(func():
			CafeSocialTheme.show_report_modal(host, "player", uid, uname, func(ok: bool):
				if ok:
					host._show_toast("گزارش شما با موفقیت ثبت شد.")
			)
		)
		extra_drawer.add_child(b_rep)

	elif mode == "incoming_req":
		act_row.add_child(btn_prof)
		var btn_rej := CafeSocialTheme.make_friend_button("reject", "رد درخواست", Vector2(0, 50))
		btn_rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_rej.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.respond_friend_request(req_id, "reject", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("درخواست دوستی رد شد.")
					host._refresh_current_tab()
			)
		)
		act_row.add_child(btn_rej)

		var btn_acc := CafeSocialTheme.make_friend_button("accept", "پذیرش دوستی", Vector2(0, 50))
		btn_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_acc.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.respond_friend_request(req_id, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("«%s» به فهرست دوستان شما اضافه شد!" % uname)
					host._refresh_current_tab()
			)
		)
		act_row.add_child(btn_acc)

	elif mode == "outgoing_req":
		act_row.add_child(btn_prof)
		var btn_cancel := CafeSocialTheme.make_friend_button("cancel", "لغو درخواست", Vector2(0, 50))
		btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cancel.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.respond_friend_request(req_id, "cancel", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("درخواست دوستی لغو شد.")
					host._refresh_current_tab()
			)
		)
		act_row.add_child(btn_cancel)

	elif mode == "search":
		act_row.add_child(btn_prof)
		var is_fr := bool(u.get("is_friend", false))
		var p_req: Variant = u.get("pending_request", null)
		var req_sent := bool(u.get("request_sent", false))
		if is_fr:
			var sp_ok := CafeSocialTheme.make_badge_pill("✓ دوست شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 20)
			sp_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_row.add_child(sp_ok)
		elif req_sent or typeof(p_req) == TYPE_DICTIONARY:
			var sp_wait := CafeSocialTheme.make_badge_pill("در انتظار تایید", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.14, 0.06, 0.95), CafeSocialTheme.COL_GOLD_ANTIQUE, 20)
			sp_wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_row.add_child(sp_wait)
		else:
			var btn_add := CafeSocialTheme.make_friend_button("add", "افزودن دوست", Vector2(0, 50))
			btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_add.pressed.connect(func():
				AudioManager.sfx_button()
				btn_add.disabled = true
				NetworkManager.api.send_friend_request(uid, "", func(ok: bool, _c: int, d: Variant):
					if ok:
						host._show_toast("درخواست دوستی برای «%s» ارسال شد!" % uname)
						btn_add.text = "✓ درخواست ارسال شد"
					else:
						btn_add.disabled = false
						var detail := str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا در ارسال درخواست"
						host._show_toast(detail, CafeSocialTheme.COL_CRIMSON_TEXT)
				)
			)
			act_row.add_child(btn_add)
			btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_add.pressed.connect(func():
				AudioManager.sfx_button()
				btn_add.disabled = true
				NetworkManager.api.send_friend_request(uid, "", func(ok: bool, _c: int, d: Variant):
					if ok:
						host._show_toast("درخواست دوستی برای «%s» ارسال شد!" % uname)
						btn_add.text = "✓ درخواست ارسال شد"
					else:
						btn_add.disabled = false
						var detail := str(d.get("detail", "خطا در ارسال درخواست")) if typeof(d) == TYPE_DICTIONARY else "خطا در ارسال درخواست"
						host._show_toast(detail, CafeSocialTheme.COL_CRIMSON_TEXT)
				)
			)
			act_row.add_child(btn_add)

	return card
