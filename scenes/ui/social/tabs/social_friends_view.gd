class_name SocialFriendsView
extends RefCounted

## Cafe Fekr — Friends Tab View
## Subsections: My Friends, Requests (Incoming/Outgoing), Search & Discover.
## Blocked player management resides strictly in UserProfileDialog Privacy Settings.

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	# Sub-navigation bar (3 antique subtabs)
	var sub_bar := PanelContainer.new()
	sub_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 38.0, 18.0))
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
				NetworkManager.incoming_friend_requests_count = host._incoming_requests.size()
				NetworkManager.notify_social_badges_changed()
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
	elif host.current_friends_subtab == "live":
		_populate_live_games_discovery(host, list_vbox)
	else:
		_populate_search_and_discover(host, list_vbox)


static func _populate_friends_list(host: Control, list_vbox: VBoxContainer) -> void:
	if host._friends_list.is_empty():
		list_vbox.add_child(CafeSocialTheme.make_empty_state(
			null,
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

	var hdr_card := CafeSocialTheme.make_ornate_section_header(
		"فهرست دوستان شما",
		null,
		"%s دوست   •   %s نفر آنلاین" % [GameManager.to_fa_num(host._friends_list.size()), GameManager.to_fa_num(online_cnt)]
	)
	if hdr_card.get_child_count() > 0 and hdr_card.get_child(0).get_child_count() > 0:
		var t_col := hdr_card.get_child(0).get_child(0)
		if t_col.get_child_count() >= 2 and t_col.get_child(1) is Label:
			host._friends_online_sub_lbl = t_col.get_child(1) as Label
	list_vbox.add_child(hdr_card)

	for f in host._friends_list:
		if typeof(f) == TYPE_DICTIONARY:
			list_vbox.add_child(_build_player_card(host, f, "friend"))
	var end_sp := Control.new()
	end_sp.custom_minimum_size = Vector2(0, 36)
	list_vbox.add_child(end_sp)


static func update_friend_presence(host: Control, target_uid: String, new_status: String) -> void:
	var st := new_status if not new_status.is_empty() else "offline"
	var is_online := (st != "offline")
	# Update online summary label
	if is_instance_valid(host._friends_online_sub_lbl):
		var online_cnt := 0
		for f in host._friends_list:
			if typeof(f) == TYPE_DICTIONARY:
				var pr: Dictionary = f.get("presence", {}) if typeof(f.get("presence")) == TYPE_DICTIONARY else {}
				var fst := str(pr.get("status", f.get("status", "offline")))
				if fst != "offline":
					online_cnt += 1
		host._friends_online_sub_lbl.text = "%s دوست   •   %s نفر آنلاین" % [
			GameManager.to_fa_num(host._friends_list.size()),
			GameManager.to_fa_num(online_cnt)
		]

	if not host._friend_card_widgets.has(target_uid):
		return
	var w: Dictionary = host._friend_card_widgets[target_uid]
	var sb: TextureRect = w.get("status_badge", null)
	if is_instance_valid(sb):
		sb.texture = CafeSocialTheme.get_status_texture(st)
	var av_btn: Button = w.get("avatar_btn", null)
	if is_instance_valid(av_btn):
		for ch in av_btn.get_children():
			ch.queue_free()
		var fresh_av := CafeSocialTheme.make_avatar_badge(int(w.get("image", 0)), int(w.get("frame", 0)), 86.0, st, true)
		fresh_av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_btn.add_child(fresh_av)
	var btn_inv: BaseButton = w.get("invite_btn", null)
	if is_instance_valid(btn_inv):
		btn_inv.disabled = not is_online
		btn_inv.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_online else Color(0.48, 0.45, 0.42, 0.45)
		btn_inv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_online else Control.CURSOR_ARROW
		btn_inv.tooltip_text = "دعوت به بازی" if is_online else "بازیکن آفلاین است"


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
		list_vbox.add_child(CafeSocialTheme.make_body("درخواست ارسالی در انتظاری ندارید.", 23, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		for req in host._outgoing_requests:
			if typeof(req) == TYPE_DICTIONARY and typeof(req.get("user")) == TYPE_DICTIONARY:
				list_vbox.add_child(_build_player_card(host, req["user"], "outgoing_req", str(req.get("request_id", ""))))
	var req_end_sp := Control.new()
	req_end_sp.custom_minimum_size = Vector2(0, 36)
	list_vbox.add_child(req_end_sp)


static func _populate_search_and_discover(host: Control, list_vbox: VBoxContainer) -> void:
	# Search box inside framed plaque
	var search_card := PanelContainer.new()
	search_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))
	list_vbox.add_child(search_card)

	var sc_vbox := VBoxContainer.new()
	sc_vbox.add_theme_constant_override("separation", 10)
	search_card.add_child(sc_vbox)

	sc_vbox.add_child(CafeSocialTheme.make_title("جستجوی بازیکنان کافه فکر", 29, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	var search_bar := HBoxContainer.new()
	search_bar.add_theme_constant_override("separation", 10)
	sc_vbox.add_child(search_bar)

	var inp_q := CafeSocialTheme.make_line_edit("نام کاربری یا شناسه بازیکن را وارد کنید...", 62.0, 25)
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

	var btn_search := CafeSocialTheme.make_button("جستجو", "gold", Vector2(150, 62), 26)
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
				discover_box.add_child(CafeSocialTheme.make_body("هنوز هم‌بازی اخیری ثبت نشده است.", 23, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
			else:
				for r_u in recent:
					if typeof(r_u) == TYPE_DICTIONARY:
						discover_box.add_child(_build_player_card(host, r_u, "search"))

			discover_box.add_child(CafeSocialTheme.make_ornate_section_header(
				"پیشنهادهای دوستی", CafeSocialTheme.ICO_RANKING, "بر اساس دوستان مشترک و هم‌سطحی شما"
			))
			if suggested.is_empty():
				discover_box.add_child(CafeSocialTheme.make_body("در حال حاضر پیشنهاد جدیدی موجود نیست.", 23, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, true))
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
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))

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
	var st_badge_img := CafeSocialTheme.make_status_badge(raw_st, 35.0)
	stats_col.add_child(st_badge_img)

	var stat_pills := HBoxContainer.new()
	stat_pills.add_theme_constant_override("separation", 6)
	stat_pills.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_col.add_child(stat_pills)
	stat_pills.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(score), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03, 0.94), CafeSocialTheme.COL_BRONZE_BORDER, CafeSocialTheme.FONT_SIZE_BADGE))
	stat_pills.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(lvl), CafeSocialTheme.COL_EMERALD_TEXT, Color(0.10, 0.06, 0.03, 0.94), CafeSocialTheme.COL_EMERALD_BORDER, CafeSocialTheme.FONT_SIZE_BADGE))

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
	info_col.add_child(CafeSocialTheme.make_title(name_line, 31, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))

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
	info_col.add_child(CafeSocialTheme.make_body(" • ".join(sub_parts), 22, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Rightmost: Avatar Frame clickable to view profile
	var av_btn := Button.new()
	av_btn.flat = true
	av_btn.custom_minimum_size = Vector2(88, 88)
	av_btn.focus_mode = Control.FOCUS_NONE
	av_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var av_badge := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 86.0, str(pres.get("status", "offline")), true)
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

	if mode == "friend":
		act_row.alignment = BoxContainer.ALIGNMENT_CENTER
		act_row.add_theme_constant_override("separation", 22)

		var make_icon_btn := func(tex: Texture2D, tip: String) -> TextureButton:
			var ib := TextureButton.new()
			ib.texture_normal = tex
			ib.custom_minimum_size = Vector2(56, 56)
			ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ib.ignore_texture_size = true
			ib.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			ib.focus_mode = Control.FOCUS_NONE
			ib.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			ib.tooltip_text = tip
			ActionVFXManager.apply_button_juice(ib, "tap_button")
			return ib

		# 1. Remove Friend (moved to top action row, replaces More/Block/Report)
		var btn_rem: TextureButton = make_icon_btn.call(preload("res://assets/images/delete.png"), "حذف دوست")
		btn_rem.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_confirm_modal(
				host, "حذف دوست",
				"آیا مطمئن هستید می‌خواهید «%s» را از فهرست دوستان خود حذف کنید؟" % uname,
				"بله، حذف شود", true,
				func():
					NetworkManager.api.remove_friend(uid, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._show_toast("«%s» از دوستان شما حذف شد." % uname)
							host._friends_list = host._friends_list.filter(func(x):
								return typeof(x) == TYPE_DICTIONARY and str(x.get("user_id", x.get("_id", ""))) != uid
							)
							host._friend_card_widgets.erase(uid)
							host._update_main_tab_buttons()
							if host.has_method("refresh_friends_and_requests"):
								host.refresh_friends_and_requests(true)
							else:
								host._refresh_current_tab()
					)
			)
		)
		act_row.add_child(btn_rem)

		# 2. View Profile
		var btn_prof_ico: TextureButton = make_icon_btn.call(preload("res://assets/images/info.png"), "پروفایل")
		btn_prof_ico.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(u)
		)
		act_row.add_child(btn_prof_ico)

		# 3. Direct Message
		var btn_dm: TextureButton = make_icon_btn.call(preload("res://assets/images/chat.png"), "ارسال پیام")
		btn_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			host.open_direct_message_with(uid, uname)
		)
		act_row.add_child(btn_dm)

		# 4. Invite to Game (disabled & dimmed when offline)
		var btn_inv: TextureButton = make_icon_btn.call(preload("res://assets/images/game.png"), "دعوت به بازی")
		if not is_online_active:
			btn_inv.disabled = true
			btn_inv.modulate = Color(0.48, 0.45, 0.42, 0.45)
			btn_inv.mouse_default_cursor_shape = Control.CURSOR_ARROW
			btn_inv.tooltip_text = "بازیکن آفلاین است"
		btn_inv.pressed.connect(func():
			if btn_inv.disabled:
				return
			AudioManager.sfx_tap()
			CafeSocialTheme.show_game_invite_modal(host, uid, uname, func(gtitle: String):
				host._show_toast("دعوت‌نامه بازی «%s» برای %s ارسال شد!" % [gtitle, uname])
			)
		)
		act_row.add_child(btn_inv)
		if not uid.is_empty():
			host._friend_card_widgets[uid] = {
				"status_badge": st_badge_img,
				"avatar_btn": av_btn,
				"invite_btn": btn_inv,
				"image": av_id,
				"frame": frame_id,
			}

		# 5. Watch Live (when friend is currently in a match)
		if p_info["is_in_game"]:
			var btn_spec: TextureButton = make_icon_btn.call(preload("res://assets/images/frames/play.png"), "تماشای زنده")
			btn_spec.pressed.connect(func():
				AudioManager.sfx_button()
				NetworkManager.request_spectate_game(str(p_info["game_id"]))
				host._show_toast("درخواست تماشای مسابقه ارسال شد...")
			)
			act_row.add_child(btn_spec)

	elif mode == "incoming_req":
		var btn_prof := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(0, 50), 23)
		btn_prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_prof.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(u)
		)
		act_row.add_child(btn_prof)
		var btn_rej := CafeSocialTheme.make_friend_button("reject", "رد درخواست", Vector2(0, 50))
		btn_rej.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_rej.pressed.connect(func():
			AudioManager.sfx_tap()
			btn_rej.disabled = true
			NetworkManager.api.respond_friend_request(req_id, "reject", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("درخواست دوستی رد شد.")
					host._incoming_requests = host._incoming_requests.filter(func(x): return str(x.get("request_id", "")) != req_id)
					host._update_main_tab_buttons()
					if host.has_method("refresh_friends_and_requests"):
						host.refresh_friends_and_requests(true)
					else:
						host._refresh_current_tab()
				elif is_instance_valid(btn_rej):
					btn_rej.disabled = false
			)
		)
		act_row.add_child(btn_rej)

		var btn_acc := CafeSocialTheme.make_friend_button("accept", "پذیرش دوستی", Vector2(0, 50))
		btn_acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_acc.pressed.connect(func():
			AudioManager.sfx_button()
			btn_acc.disabled = true
			NetworkManager.api.respond_friend_request(req_id, "accept", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("«%s» به فهرست دوستان شما اضافه شد!" % uname)
					host._incoming_requests = host._incoming_requests.filter(func(x): return str(x.get("request_id", "")) != req_id)
					host._update_main_tab_buttons()
					if host.has_method("refresh_friends_and_requests"):
						host.refresh_friends_and_requests(true)
					else:
						host._refresh_current_tab()
				elif is_instance_valid(btn_acc):
					btn_acc.disabled = false
			)
		)
		act_row.add_child(btn_acc)

	elif mode == "outgoing_req":
		var btn_prof_out := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(0, 50), 23)
		btn_prof_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_prof_out.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(u)
		)
		act_row.add_child(btn_prof_out)
		var btn_cancel := CafeSocialTheme.make_friend_button("cancel", "لغو درخواست", Vector2(0, 50))
		btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cancel.pressed.connect(func():
			AudioManager.sfx_tap()
			btn_cancel.disabled = true
			NetworkManager.api.respond_friend_request(req_id, "cancel", func(ok: bool, _c: int, _d: Variant):
				if ok:
					host._show_toast("درخواست دوستی لغو شد.")
					host._outgoing_requests = host._outgoing_requests.filter(func(x): return str(x.get("request_id", "")) != req_id)
					host._update_main_tab_buttons()
					if host.has_method("refresh_friends_and_requests"):
						host.refresh_friends_and_requests(true)
					else:
						host._refresh_current_tab()
				elif is_instance_valid(btn_cancel):
					btn_cancel.disabled = false
			)
		)
		act_row.add_child(btn_cancel)

	elif mode == "search":
		var btn_prof_s := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(0, 50), 23)
		btn_prof_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_prof_s.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(u)
		)
		act_row.add_child(btn_prof_s)
		var is_fr := bool(u.get("is_friend", false))
		var p_req: Variant = u.get("pending_request", null)
		var req_sent := bool(u.get("request_sent", false))
		if p_info["is_in_game"]:
			var btn_spec_s: Button = CafeSocialTheme.make_button("تماشا", "gold", Vector2(114, 50), 23)
			btn_spec_s.pressed.connect(func():
				AudioManager.sfx_button()
				NetworkManager.request_spectate_game(str(p_info["game_id"]), uid)
				host._show_toast("درخواست تماشای مسابقه ارسال شد...")
			)
			act_row.add_child(btn_spec_s)

		if is_fr:
			var sp_ok := CafeSocialTheme.make_badge_pill("✓ دوست شما", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 22)
			sp_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_row.add_child(sp_ok)
		elif req_sent or typeof(p_req) == TYPE_DICTIONARY:
			var sp_wait := CafeSocialTheme.make_badge_pill("در انتظار تایید", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.14, 0.06, 0.95), CafeSocialTheme.COL_GOLD_ANTIQUE, 22)
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

	return card


static func _populate_live_games_discovery(host: Control, list_vbox: VBoxContainer) -> void:
	# Filter Plaque (Scope + Game Type)
	var filter_card: PanelContainer = PanelContainer.new()
	filter_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))
	list_vbox.add_child(filter_card)

	var fv: VBoxContainer = VBoxContainer.new()
	fv.add_theme_constant_override("separation", 10)
	filter_card.add_child(fv)

	fv.add_child(CafeSocialTheme.make_title("تماشای زنده مسابقات کافه فکر", 28, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	var scope_row: HBoxContainer = HBoxContainer.new()
	scope_row.add_theme_constant_override("separation", 8)
	fv.add_child(scope_row)

	var scopes: Array = [
		{"id": "all", "label": "همه بازی‌ها"},
		{"id": "friends", "label": "دوستان در حال بازی"},
		{"id": "clan", "label": "اعضای کلن من"},
	]
	for sc in scopes:
		var sc_dict: Dictionary = sc
		var sid: String = str(sc_dict["id"])
		var is_sel: bool = (host.current_live_scope == sid)
		var b_sc: Button = CafeSocialTheme.make_button(str(sc_dict["label"]), "gold" if is_sel else "muted", Vector2(0, 52), CafeSocialTheme.FONT_SIZE_TAB_COMPACT)
		b_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CafeSocialTheme.configure_single_line_tab(b_sc, CafeSocialTheme.FONT_SIZE_TAB_COMPACT, 52.0, 6.0)
		b_sc.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_live_scope = sid
			host._refresh_current_tab()
		)
		scope_row.add_child(b_sc)

	var game_row: HBoxContainer = HBoxContainer.new()
	game_row.add_theme_constant_override("separation", 6)
	fv.add_child(game_row)

	var game_filters: Array = [
		{"id": "", "label": "همه"},
		{"id": "Ludo", "label": "منچ"},
		{"id": "Monopoly", "label": "مونوپولی"},
		{"id": "Chess", "label": "شطرنج"},
		{"id": "Backgammon", "label": "تخته‌نرد"},
		{"id": "Risk", "label": "ریسک"},
	]
	for gf in game_filters:
		var gf_dict: Dictionary = gf
		var gid_f: String = str(gf_dict["id"])
		var is_g_sel: bool = (host.current_live_game_type == gid_f)
		var b_gf: Button = CafeSocialTheme.make_button(str(gf_dict["label"]), "emerald" if is_g_sel else "bronze", Vector2(0, 50), CafeSocialTheme.FONT_SIZE_BADGE)
		b_gf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CafeSocialTheme.configure_single_line_tab(b_gf, CafeSocialTheme.FONT_SIZE_BADGE, 50.0, 4.0)
		b_gf.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_live_game_type = gid_f
			host._refresh_current_tab()
		)
		game_row.add_child(b_gf)

	var games_box: VBoxContainer = VBoxContainer.new()
	games_box.add_theme_constant_override("separation", 10)
	games_box.add_child(CafeSocialTheme.make_loading_state("در حال جستجوی مسابقات زنده..."))
	list_vbox.add_child(games_box)

	var merged_map: Dictionary = {}
	var render_merged := func():
		if not is_instance_valid(games_box):
			return
		for ch in games_box.get_children():
			ch.queue_free()
		var items: Array = merged_map.values()
		if items.is_empty():
			games_box.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_LOBBY,
				"مسابقه زنده‌ای یافت نشد",
				"در حال حاضر مسابقه فعالی با این فیلتر برای تماشا در جریان نیست.",
				"بروزرسانی فهرست",
				"gold",
				func(): host._refresh_current_tab()
			))
			return
		games_box.add_child(CafeSocialTheme.make_ornate_section_header(
			"مسابقات در حال برگزاری",
			CafeSocialTheme.ICO_CUP,
			"%s مسابقه زنده آماده تماشا" % GameManager.to_fa_num(items.size())
		))
		for item in items:
			if typeof(item) == TYPE_DICTIONARY:
				games_box.add_child(_build_live_match_card(host, item))

	var ingest_fn := func(arr: Array):
		for it in arr:
			if typeof(it) == TYPE_DICTIONARY:
				var d: Dictionary = it
				var g_id: String = str(d.get("game_id", ""))
				if not g_id.is_empty() and not merged_map.has(g_id):
					merged_map[g_id] = d

	var rt_cb := func(payload: Dictionary):
		if not is_instance_valid(games_box):
			return
		var arr: Array = payload.get("items", []) if typeof(payload.get("items")) == TYPE_ARRAY else []
		ingest_fn.call(arr)
		render_merged.call()

	if NetworkManager.is_online:
		NetworkManager.live_games_list_received.connect(rt_cb, CONNECT_ONE_SHOT)
		NetworkManager.request_live_games_realtime(host.current_live_scope, host.current_live_game_type)

	NetworkManager.api.get_live_spectator_games(
		host.current_live_scope,
		host.current_live_game_type,
		"",
		"",
		1,
		25,
		func(ok: bool, _code: int, data: Variant):
			if not is_instance_valid(games_box):
				return
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				var res: Dictionary = data["result"]
				var arr: Array = []
				if typeof(res.get("items")) == TYPE_ARRAY:
					arr = res["items"]
				elif typeof(res.get("games")) == TYPE_ARRAY:
					arr = res["games"]
				ingest_fn.call(arr)
			render_merged.call()
	)


static func _build_live_match_card(host: Control, m: Dictionary) -> PanelContainer:
	var gid: String = str(m.get("game_id", ""))
	var gtype: String = str(m.get("game_type", "Ludo"))
	var gtitle: String = GameRegistry.get_display_name_fa(gtype)
	var spec_cnt: int = int(m.get("spectator_count", 0))
	var has_friend: bool = bool(m.get("has_friend", false))
	var has_clanmate: bool = bool(m.get("has_clanmate", false))
	var players: Array = m.get("players", []) if typeof(m.get("players")) == TYPE_ARRAY else []

	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(
		"panel",
		CafeSocialTheme.create_frame_style(true, 20.0, 16.0)
	)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	card.add_child(root)

	# Header Row: Spectator Count & Watch Button on Left, Game Title & Icon on Right
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root.add_child(top_row)

	var btn_watch: Button = CafeSocialTheme.make_button("تماشای زنده", "gold", Vector2(164, 52), 23)
	btn_watch.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.request_spectate_game(gid)
		host._show_toast("در حال ورود به تماشای زنده «%s»..." % gtitle)
	)
	top_row.add_child(btn_watch)

	top_row.add_child(CafeSocialTheme.make_badge_pill(
		"👁️ %s تماشاگر" % GameManager.to_fa_num(spec_cnt),
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		CafeSocialTheme.FONT_SIZE_BADGE
	))

	var title_col: VBoxContainer = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.alignment = BoxContainer.ALIGNMENT_CENTER
	title_col.add_theme_constant_override("separation", 2)
	top_row.add_child(title_col)

	title_col.add_child(CafeSocialTheme.make_title(
		"مسابقه %s" % gtitle,
		28,
		CafeSocialTheme.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT,
		false
	))

	var names_arr: Array[String] = []
	for p in players:
		if typeof(p) == TYPE_DICTIONARY:
			var pd: Dictionary = p
			var pname: String = str(pd.get("username", "بازیکن"))
			var c_info: Variant = pd.get("clan", null)
			if typeof(c_info) == TYPE_DICTIONARY and not str((c_info as Dictionary).get("tag", "")).is_empty():
				pname += " [%s]" % str((c_info as Dictionary).get("tag", ""))
			names_arr.append(pname)
	title_col.add_child(CafeSocialTheme.make_body(
		" ⚔️ ".join(names_arr) if not names_arr.is_empty() else "در حال رقابت",
		22,
		CafeSocialTheme.COL_IVORY,
		HORIZONTAL_ALIGNMENT_RIGHT,
		true
	))

	var thumb: TextureRect = TextureRect.new()
	thumb.texture = CafeSocialTheme.get_game_thumb(gtype)
	thumb.custom_minimum_size = Vector2(64, 64)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_row.add_child(thumb)

	return card

