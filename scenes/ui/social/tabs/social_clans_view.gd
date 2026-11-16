class_name SocialClansView
extends RefCounted

## Cafe Fekr — Clans / Guilds System View
## Features:
## - My Clan Hub: Hero Guild Banner (emblem, tag, level/XP, score, settings, leave/disband),
##   Weekly Challenges with progress bars, Friendly Challenge game picker, Join Requests,
##   Clean Member List with Member Management Modal, Spacious Clan Chat
## - Clan Discovery & Leaderboards + Dedicated Ornate Clan Creation Modal (Free, max 1 per player)

static func render(host: Control, body_vbox: VBoxContainer) -> void:
	# Clean 4-item sub-navigation bar
	var sub_bar := PanelContainer.new()
	sub_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 38.0, 18.0))
	body_vbox.add_child(sub_bar)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	sub_bar.add_child(sub_row)

	var subtabs := [
		{"id": "my_clan", "label": "اتحاد من"},
		{"id": "members", "label": "اعضا"},
		{"id": "chat", "label": "چت اتحاد"},
		{"id": "discover", "label": "اتحادها و رتبه‌بندی"},
	]
	for sd in subtabs:
		var sid: String = sd["id"]
		var is_act: bool = (host.current_clans_subtab == sid or (host.current_clans_subtab == "search" and sid == "discover") or (host.current_clans_subtab == "leaderboard" and sid == "discover"))
		var b := CafeSocialTheme.make_subtab(sd["label"], is_act, 0)
		b.pressed.connect(func():
			AudioManager.sfx_tap()
			host.current_clans_subtab = sid
			host._refresh_current_tab()
		)
		sub_row.add_child(b)

	var content_holder := VBoxContainer.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.add_theme_constant_override("separation", 10)
	body_vbox.add_child(content_holder)

	if host.current_clans_subtab in ["my_clan", "members"]:
		content_holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اطلاعات اتحاد..."))
		NetworkManager.api.get_my_clan(func(ok: bool, _c: int, data: Variant):
			if not is_instance_valid(content_holder):
				return
			for ch in content_holder.get_children():
				ch.queue_free()
			if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
				host._my_clan_data = data["result"]
				if host.current_clans_subtab == "members":
					_build_clan_members_view(host, content_holder)
				else:
					_build_my_clan_overview(host, content_holder)
			else:
				content_holder.add_child(CafeSocialTheme.make_empty_state(
					CafeSocialTheme.ICO_INFO,
					"خطا در دریافت اطلاعات اتحاد",
					"لطفاً اتصال خود را بررسی کرده و دوباره تلاش کنید.",
					"تلاش مجدد", "gold", func(): host._refresh_current_tab()
				))
		)
	elif host.current_clans_subtab == "chat":
		_build_clan_chat_view(host, content_holder)
	else:
		_build_clan_discover_view(host, content_holder)


static func _build_no_clan_hero(host: Control, vbox: VBoxContainer) -> void:
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 26.0))
	vbox.add_child(hero)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 14)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hv)

	var shield := CafeSocialTheme.make_clan_emblem(1, 96.0)
	hv.add_child(shield)

	hv.add_child(CafeSocialTheme.make_title("به یک اتحاد بپیوندید یا اتحاد خودتان را بسازید!", 35, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	hv.add_child(CafeSocialTheme.make_body(
		"در اتحادهای کافه فکر می‌توانید با دوستان و هم‌تیمی‌های خود چت کنید، چالش‌های هفتگی اتحاد را فتح نمایید، بازی دوستانه بسازید و نام اتحاد خود را در صدر جدول قهرمانان ثبت کنید.",
		21, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true
	))
	hv.add_child(CafeSocialTheme.make_badge_pill(
		"تاسیس اتحاد کاملاً رایگان است (سهمیه هر بازیکن: ۱ اتحاد)",
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		20
	))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(btn_row)

	var b_search := CafeSocialTheme.make_button("جستجو و عضویت در اتحاد", "emerald", Vector2(0, 58), 25)
	b_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_search.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "discover"
		host._refresh_current_tab()
	)
	btn_row.add_child(b_search)

	var b_create := CafeSocialTheme.make_button("تاسیس اتحاد جدید (رایگان)", "gold", Vector2(0, 58), 25)
	b_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_create.pressed.connect(func():
		AudioManager.sfx_button()
		open_clan_create_modal(host)
	)
	btn_row.add_child(b_create)

	# Incoming Clan Invitations
	var invs: Array = host._my_clan_data.get("invitations", []) if typeof(host._my_clan_data.get("invitations")) == TYPE_ARRAY else []
	if not invs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"دعوت‌نامه‌های اتحاد برای شما", CafeSocialTheme.ICO_STAR,
			"%s دعوت‌نامه در انتظار پاسخ" % GameManager.to_fa_num(invs.size())
		))
		for inv in invs:
			if typeof(inv) != TYPE_DICTIONARY:
				continue
			var c_sub: Dictionary = inv.get("clan", {}) if typeof(inv.get("clan")) == TYPE_DICTIONARY else {}
			var cname := str(c_sub.get("name", "اتحاد"))
			var ctag := str(c_sub.get("tag", ""))
			var emb := int(c_sub.get("emblem_id", 1))
			var inv_id := str(inv.get("invite_id", ""))

			var icard := PanelContainer.new()
			icard.custom_minimum_size = Vector2(0, 140)
			icard.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))
			vbox.add_child(icard)

			var irow := HBoxContainer.new()
			irow.alignment = BoxContainer.ALIGNMENT_CENTER
			irow.add_theme_constant_override("separation", 12)
			icard.add_child(irow)

			var b_rej := CafeSocialTheme.make_button("رد", "crimson", Vector2(96, 48), 23)
			b_rej.pressed.connect(func():
				AudioManager.sfx_tap()
				NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(_ok: bool, _c: int, _d: Variant):
					host._refresh_current_tab()
				)
			)
			irow.add_child(b_rej)

			var b_acc := CafeSocialTheme.make_button("پیوستن", "emerald", Vector2(140, 48), 23)
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
			ic_col.add_child(CafeSocialTheme.make_title("%s  [%s]" % [cname, ctag], 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
			ic_col.add_child(CafeSocialTheme.make_body("سطح %s • %s عضو" % [
				GameManager.to_fa_num(int(c_sub.get("clan_level", 1))),
				GameManager.to_fa_num(int(c_sub.get("member_count", 1)))
			], 19, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT))

			irow.add_child(CafeSocialTheme.make_clan_emblem(emb, 64.0))


static func _build_my_clan_overview(host: Control, holder: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	var clan: Variant = host._my_clan_data.get("clan", null)
	if clan == null or typeof(clan) != TYPE_DICTIONARY or clan.is_empty():
		_build_no_clan_hero(host, vbox)
		return

	var cdict: Dictionary = clan
	var cid := str(cdict.get("clan_id", ""))
	NetworkManager.join_clan_room_realtime(cid)
	var my_role := str(cdict.get("my_role", "member"))
	var my_role_fa := str(cdict.get("my_role_fa", "عضو"))
	var emb_id := int(cdict.get("emblem_id", 1))
	var clan_lvl := int(cdict.get("clan_level", 1))
	var clan_xp := int(cdict.get("clan_xp", 0))
	var next_xp: int = maxi(100, clan_lvl * 500)

	# 1. Hero Guild Crest Plaque
	var hero := PanelContainer.new()
	hero.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 26.0))
	vbox.add_child(hero)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero.add_child(hv)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	hv.add_child(top_bar)

	# Left badges: Role & Level
	var badges_col := VBoxContainer.new()
	badges_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badges_col.add_theme_constant_override("separation", 6)
	top_bar.add_child(badges_col)
	badges_col.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(clan_lvl), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 22))
	badges_col.add_child(CafeSocialTheme.make_badge_pill("سمت: %s" % my_role_fa, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 21))

	# Center Info
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 4)
	top_bar.add_child(info_col)

	info_col.add_child(CafeSocialTheme.make_title("%s  [%s]" % [str(cdict.get("name", "")), str(cdict.get("tag", ""))], 35, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var desc_txt := str(cdict.get("description", "")).strip_edges()
	info_col.add_child(CafeSocialTheme.make_body(desc_txt if not desc_txt.is_empty() else "باشگاه رسمی بازیکنان کافه فکر", 23, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Right Emblem
	top_bar.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 92.0))

	# Clan XP Progress Bar
	hv.add_child(CafeSocialTheme.make_xp_progress_bar(
		float(clan_xp % next_xp) / float(next_xp),
		"تجربه اتحاد: %s / %s XP" % [GameManager.to_fa_num(clan_xp % next_xp), GameManager.to_fa_num(next_xp)],
		Color(0.86, 0.66, 0.20)
	))

	# 3-stat strip
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	hv.add_child(stat_row)
	var sp1 := CafeSocialTheme.make_badge_pill("امتیاز کل: %s" % GameManager.to_fa_num(int(cdict.get("clan_score", 0))), CafeSocialTheme.COL_GOLD_BRIGHT)
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(sp1)
	var sp2 := CafeSocialTheme.make_badge_pill("هفتگی: %s" % GameManager.to_fa_num(int(cdict.get("weekly_score", 0))), CafeSocialTheme.COL_EMERALD_TEXT)
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(sp2)
	var sp3 := CafeSocialTheme.make_badge_pill("اعضا: %s / %s" % [GameManager.to_fa_num(int(cdict.get("member_count", 1))), GameManager.to_fa_num(int(cdict.get("max_members", 50)))], CafeSocialTheme.COL_IVORY)
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(sp3)

	# Action Strip
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 8)
	hv.add_child(act_row)

	var b_leave := CafeSocialTheme.make_button("انحلال اتحاد" if my_role == "leader" else "خروج از اتحاد", "crimson", Vector2(0, 50), 23)
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
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا در انحلال اتحاد")), CafeSocialTheme.COL_CRIMSON_TEXT)
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
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
					)
			)
	)
	act_row.add_child(b_leave)

	if my_role in ["leader", "co_leader"]:
		var b_settings := CafeSocialTheme.make_button("تنظیمات اتحاد", "bronze", Vector2(0, 50), 23)
		b_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_settings.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_clan_settings_modal(host, cdict)
		)
		act_row.add_child(b_settings)

	var b_chal := CafeSocialTheme.make_button("چالش دوستانه", "emerald", Vector2(0, 50), 23)
	b_chal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_chal.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friendly_challenge_modal(host)
	)
	act_row.add_child(b_chal)

	# 1.5 Active Friendly Challenges (closable by creator / co-leader+ before start)
	var open_chals_raw: Variant = cdict.get("open_challenges", host._my_clan_data.get("open_challenges", []))
	var open_chals: Array = open_chals_raw if typeof(open_chals_raw) == TYPE_ARRAY else []
	if not open_chals.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های دوستانه فعال اتحاد", CafeSocialTheme.ICO_LOBBY, "%s چالش باز در انتظار هم‌تیمی" % GameManager.to_fa_num(open_chals.size())
		))
		var my_uid_ov: String = str(GameManager.get_user_id())
		for ch_item in open_chals:
			if typeof(ch_item) != TYPE_DICTIONARY:
				continue
			vbox.add_child(_build_overview_challenge_card(host, ch_item, my_uid_ov, my_role))

	# 2. Weekly Challenges
	var challenges: Array = cdict.get("weekly_challenges", []) if typeof(cdict.get("weekly_challenges")) == TYPE_ARRAY else []
	if not challenges.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های هفتگی اتحاد", CafeSocialTheme.ICO_CUP, "همکاری اعضای اتحاد برای دریافت XP اتحاد"
		))
		for ch in challenges:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			var ch_card := PanelContainer.new()
			var done := bool(ch.get("completed", false))
			ch_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))
			vbox.add_child(ch_card)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 8)
			ch_card.add_child(cv)

			var cr := HBoxContainer.new()
			cv.add_child(cr)
			cr.add_child(CafeSocialTheme.make_badge_pill(
				"تکمیل شد!" if done else "+%s XP اتحاد" % GameManager.to_fa_num(int(ch.get("reward_clan_xp", 150))),
				CafeSocialTheme.COL_EMERALD_TEXT if done else CafeSocialTheme.COL_GOLD_BRIGHT,
				CafeSocialTheme.COL_EMERALD_BG if done else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_EMERALD_BORDER if done else CafeSocialTheme.COL_BRONZE_BORDER,
				18
			))
			var ct := CafeSocialTheme.make_title(str(ch.get("title", "")), 27, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
			ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cr.add_child(ct)

			cv.add_child(CafeSocialTheme.make_body(str(ch.get("desc", "")), 22, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
			var prog := int(ch.get("progress", 0))
			var targ: int = maxi(1, int(ch.get("target", 1)))
			cv.add_child(CafeSocialTheme.make_xp_progress_bar(
				float(prog) / float(targ),
				"%s از %s" % [GameManager.to_fa_num(prog), GameManager.to_fa_num(targ)],
				Color(0.32, 0.86, 0.50) if done else Color(0.88, 0.66, 0.22)
			))

	# 3. Pending Join Requests (Elder+)
	var pending_reqs: Array = cdict.get("pending_join_requests", []) if typeof(cdict.get("pending_join_requests")) == TYPE_ARRAY else []
	if not pending_reqs.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"درخواست‌های عضویت", CafeSocialTheme.ICO_STAR, "%s درخواست در انتظار بررسی" % GameManager.to_fa_num(pending_reqs.size())
		))
		for req in pending_reqs:
			if typeof(req) != TYPE_DICTIONARY:
				continue
			var ru: Dictionary = req.get("user", {}) if typeof(req.get("user")) == TYPE_DICTIONARY else {}
			var rid := str(req.get("request_id", ""))
			var rcard := PanelContainer.new()
			rcard.custom_minimum_size = Vector2(0, 140)
			rcard.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))
			vbox.add_child(rcard)

			var rrow := HBoxContainer.new()
			rrow.alignment = BoxContainer.ALIGNMENT_CENTER
			rrow.add_theme_constant_override("separation", 10)
			rcard.add_child(rrow)

			var b_no := CafeSocialTheme.make_button("رد", "crimson", Vector2(90, 46), 22)
			b_no.pressed.connect(func():
				NetworkManager.api.respond_clan_join_request(rid, "reject", func(_ok, _c, _d): host._refresh_current_tab())
			)
			rrow.add_child(b_no)

			var b_ok := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(120, 46), 22)
			b_ok.pressed.connect(func():
				NetworkManager.api.respond_clan_join_request(rid, "accept", func(ok: bool, _c: int, _d: Variant):
					if ok:
						host._show_toast("عضو جدید پذیرفته شد!")
					host._refresh_current_tab()
				)
			)
			rrow.add_child(b_ok)

			var rcol := VBoxContainer.new()
			rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rrow.add_child(rcol)
			rcol.add_child(CafeSocialTheme.make_title(str(ru.get("username", "بازیکن")), 27, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
			rcol.add_child(CafeSocialTheme.make_body("امتیاز: %s  %s" % [GameManager.to_fa_num(int(ru.get("score", 0))), str(req.get("message", ""))], 19, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))
			rrow.add_child(CafeSocialTheme.make_avatar_badge(int(ru.get("image", 0)), int(ru.get("profile_frame", 0)), 64.0))


static func _build_clan_members_view(host: Control, holder: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var clan: Variant = host._my_clan_data.get("clan", null)
	if clan == null or typeof(clan) != TYPE_DICTIONARY or clan.is_empty():
		_build_no_clan_hero(host, vbox)
		return

	var cdict: Dictionary = clan
	var my_role := str(cdict.get("my_role", "member"))
	var members: Array = cdict.get("members", []) if typeof(cdict.get("members")) == TYPE_ARRAY else []

	vbox.add_child(CafeSocialTheme.make_ornate_section_header(
		"اعضای اتحاد %s" % str(cdict.get("name", "")),
		CafeSocialTheme.ICO_ARMY,
		"%s عضو فعال • برای مشاهده پروفایل یا مدیریت عضو روی کارت ضربه بزنید" % GameManager.to_fa_num(members.size())
	))

	var my_uid: String = str(GameManager.get_user_id())
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var m_dict: Dictionary = m
		var m_uid: String = str(m_dict.get("user_id", ""))
		var m_name: String = str(m_dict.get("username", "بازیکن"))
		var m_role: String = str(m_dict.get("role", "member"))
		var m_role_fa: String = str(m_dict.get("role_title", m_dict.get("role_fa", "عضو")))
		var m_contrib: int = int(m_dict.get("weekly_contribution", 0))
		var m_score: int = int(m_dict.get("score", 0))
		var m_pres: Dictionary = m_dict.get("presence", {}) if typeof(m_dict.get("presence")) == TYPE_DICTIONARY else {}
		var raw_st: String = str(m_pres.get("status", "offline"))

		var mcard := PanelContainer.new()
		mcard.custom_minimum_size = Vector2(0, 144)
		mcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mcard.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))
		vbox.add_child(mcard)

		var mrow := HBoxContainer.new()
		mrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mrow.alignment = BoxContainer.ALIGNMENT_CENTER
		mrow.add_theme_constant_override("separation", 12)
		mcard.add_child(mrow)

		var act_col := VBoxContainer.new()
		act_col.alignment = BoxContainer.ALIGNMENT_CENTER
		act_col.add_theme_constant_override("separation", 6)
		mrow.add_child(act_col)

		var b_prof := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(118, 42), 21)
		b_prof.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(m_dict)
		)
		act_col.add_child(b_prof)

		var m_p_info: Dictionary = CafeSocialTheme.format_presence(m_pres if not m_pres.is_empty() else {"status": raw_st})
		if m_uid != my_uid and bool(m_p_info.get("is_in_game", false)):
			var b_spec_m: Button = CafeSocialTheme.make_button("تماشا", "emerald", Vector2(118, 42), 21)
			b_spec_m.pressed.connect(func():
				AudioManager.sfx_button()
				NetworkManager.request_spectate_game(str(m_p_info.get("game_id", "")), m_uid)
				host._show_toast("درخواست تماشای مسابقه ارسال شد...")
			)
			act_col.add_child(b_spec_m)

		var can_manage: bool = (m_uid != my_uid) and (
			my_role == "leader"
			or (my_role == "co_leader" and m_role in ["elder", "member"])
			or (my_role == "elder" and m_role == "member")
		)
		if can_manage:
			var b_mgr := CafeSocialTheme.make_button("مدیریت", "gold", Vector2(118, 42), 21)
			b_mgr.pressed.connect(func():
				AudioManager.sfx_tap()
				_open_member_manage_modal(host, m_dict, my_role)
			)
			act_col.add_child(b_mgr)

		var m_col := VBoxContainer.new()
		m_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_col.alignment = BoxContainer.ALIGNMENT_CENTER
		m_col.add_theme_constant_override("separation", 6)
		mrow.add_child(m_col)

		var title_row := HBoxContainer.new()
		title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.alignment = BoxContainer.ALIGNMENT_END
		title_row.add_theme_constant_override("separation", 8)
		m_col.add_child(title_row)

		var role_text_col: Color = CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if m_role == "co_leader" else CafeSocialTheme.COL_WARM_CREAM)
		var role_bg_col: Color = Color(0.22, 0.14, 0.04, 0.96) if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BG if m_role == "co_leader" else Color(0.11, 0.07, 0.04, 0.94))
		var role_border_col: Color = CafeSocialTheme.COL_GOLD_ANTIQUE if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_BORDER if m_role == "co_leader" else CafeSocialTheme.COL_BRONZE_BORDER)
		title_row.add_child(CafeSocialTheme.make_badge_pill(m_role_fa, role_text_col, role_bg_col, role_border_col, 18))

		var nm_lbl := CafeSocialTheme.make_title(m_name, 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		nm_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm_lbl.clip_text = true
		nm_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_row.add_child(nm_lbl)

		var meta_row := HBoxContainer.new()
		meta_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta_row.alignment = BoxContainer.ALIGNMENT_END
		meta_row.add_theme_constant_override("separation", 10)
		m_col.add_child(meta_row)

		var contrib_lbl := CafeSocialTheme.make_body(
			"مشارکت هفتگی: %s  •  امتیاز: %s" % [
				GameManager.to_fa_num(m_contrib),
				GameManager.to_fa_num(m_score)
			],
			19, role_text_col, HORIZONTAL_ALIGNMENT_RIGHT, false
		)
		contrib_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		contrib_lbl.clip_text = true
		contrib_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		meta_row.add_child(contrib_lbl)

		var st_badge := CafeSocialTheme.make_status_badge(raw_st, 27.0)
		meta_row.add_child(st_badge)

		var av_btn := Button.new()
		av_btn.flat = true
		av_btn.focus_mode = Control.FOCUS_NONE
		av_btn.custom_minimum_size = Vector2(76, 76)
		av_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var av_vis := CafeSocialTheme.make_avatar_badge(int(m_dict.get("image", 0)), int(m_dict.get("profile_frame", 0)), 74.0, raw_st, false)
		av_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_btn.add_child(av_vis)
		av_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(m_dict)
		)
		mrow.add_child(av_btn)


static func _build_clan_chat_view(host: Control, holder: VBoxContainer) -> void:
	var well := PanelContainer.new()
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 26.0))
	holder.add_child(well)

	host._clan_chat_scroll = ScrollContainer.new()
	host._clan_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host._clan_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	well.add_child(host._clan_chat_scroll)

	host._clan_chat_list_vbox = VBoxContainer.new()
	host._clan_chat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._clan_chat_list_vbox.add_theme_constant_override("separation", 10)
	host._clan_chat_scroll.add_child(host._clan_chat_list_vbox)
	host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت گفتگوهای اتحاد..."))

	var compose := PanelContainer.new()
	compose.custom_minimum_size = Vector2(0, 108)
	compose.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 38.0, 18.0))
	holder.add_child(compose)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	compose.add_child(input_row)

	var btn_send := CafeSocialTheme.make_button("ارسال", "emerald", Vector2(142, 64), 26)
	input_row.add_child(btn_send)

	host._clan_chat_input = CafeSocialTheme.make_line_edit("پیام خود را برای اعضای اتحاد بنویسید (برای منشن از @ استفاده کنید)...", 64.0, 25)
	host._clan_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(host._clan_chat_input)

	btn_send.pressed.connect(func():
		AudioManager.sfx_tap()
		host._send_clan_chat_message()
	)
	host._clan_chat_input.text_submitted.connect(func(_t: String): host._send_clan_chat_message())

	NetworkManager.api.get_clan_chat_history("", func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(host._clan_chat_list_vbox):
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			host._clan_chat_messages = data["result"]
			render_clan_chat(host)
		else:
			for ch in host._clan_chat_list_vbox.get_children():
				ch.queue_free()
			host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_RANK,
				"چت اتحاد در دسترس نیست",
				"برای استفاده از گفتگوی اتحاد ابتدا وارد یک اتحاد شوید.",
				"یافتن اتحاد", "gold", func():
					host.current_clans_subtab = "discover"
					host._refresh_current_tab()
			))
	)


static func render_clan_chat(host: Control) -> void:
	if not is_instance_valid(host._clan_chat_list_vbox):
		return
	for c in host._clan_chat_list_vbox.get_children():
		c.queue_free()

	if host._clan_chat_messages.is_empty():
		host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.BADGE_CHAT,
			"هنوز پیامی ارسال نشده است",
			"اولین پیام یا چالش دوستانه را در چت اتحاد ثبت کنید!"
		))
		return

	var my_uid := str(GameManager.get_user_id())
	var my_role := str((host._my_clan_data.get("clan", {}) if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY else {}).get("my_role", "member"))
	var role_fa_map := {"leader": "رهبر", "co_leader": "قائم‌مقام", "elder": "ارشد", "member": "عضو", "system": "سیستم"}

	for msg in host._clan_chat_messages:
		if typeof(msg) != TYPE_DICTIONARY:
			continue
		var mtype := str(msg.get("msg_type", "text"))
		var sender_id := str(msg.get("sender_id", ""))
		var sender_name := str(msg.get("sender_name", "بازیکن"))
		var sender_role := str(msg.get("sender_role", "member"))
		var sender_img := int(msg.get("sender_image", 0))
		var text := str(msg.get("text", ""))
		var msg_id := str(msg.get("message_id", ""))
		var time_str := CafeSocialTheme.format_time_fa(str(msg.get("created_at", "")))
		var is_mine := (sender_id == my_uid)

		var bg := Color(0.12, 0.27, 0.18, 0.96) if is_mine else (Color(0.24, 0.17, 0.07, 0.96) if mtype != "text" else CafeSocialTheme.COL_WALNUT_CARD)
		var border := CafeSocialTheme.COL_EMERALD_BORDER if is_mine else (CafeSocialTheme.COL_GOLD_BRIGHT if mtype != "text" else CafeSocialTheme.COL_BRONZE_BORDER)

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(bg, border, 16, 2, 14.0, 10.0))
		host._clan_chat_list_vbox.add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_vbox.add_theme_constant_override("separation", 8)
		card.add_child(card_vbox)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		card_vbox.add_child(row)

		if is_mine or my_role in ["leader", "co_leader", "elder"]:
			if mtype == "text" and not msg_id.is_empty():
				var b_del := CafeSocialTheme.make_button("حذف", "crimson", Vector2(76, 40), 20)
				b_del.pressed.connect(func():
					NetworkManager.api.delete_clan_chat_message(msg_id, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._clan_chat_messages = host._clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != msg_id)
							render_clan_chat(host)
					)
				)
				row.add_child(b_del)

		var is_challenge_msg: bool = (mtype == "friendly_challenge") or (mtype == "system" and typeof(msg.get("metadata")) == TYPE_DICTIONARY and msg["metadata"].has("challenge_id"))

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)

		if mtype == "text":
			var r_lbl: String = role_fa_map.get(sender_role, "عضو")
			var hdr_txt := "%s  •  %s" % [sender_name, r_lbl]
			if not time_str.is_empty():
				hdr_txt += "  (%s)" % time_str
			col.add_child(CafeSocialTheme.make_title(hdr_txt, 25, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
		col.add_child(CafeSocialTheme.make_body(text, 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT if mtype == "text" else HORIZONTAL_ALIGNMENT_CENTER, true))

		if mtype == "text":
			row.add_child(CafeSocialTheme.make_avatar_badge(sender_img, 0, 56.0))
		elif is_challenge_msg:
			var meta: Dictionary = msg.get("metadata", {}) if typeof(msg.get("metadata")) == TYPE_DICTIONARY else {}
			var chal_gt: String = str(meta.get("game_type", "Monopoly"))
			var chal_thumb: Texture2D = CafeSocialTheme.get_game_thumb(chal_gt)
			if chal_thumb != null:
				var th := TextureRect.new()
				th.texture = chal_thumb
				th.custom_minimum_size = Vector2(58, 58)
				th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				row.add_child(th)
			var chal_act_row := _build_challenge_action_row(host, meta, my_uid, my_role, true)
			if chal_act_row != null:
				card_vbox.add_child(chal_act_row)

	if is_instance_valid(host._clan_chat_scroll):
		host.call_deferred("_scroll_clan_chat_to_bottom")


static func _build_clan_discover_view(host: Control, holder: VBoxContainer) -> void:
	# Toggle between Search Directory & Clan Leaderboards + Create Clan button
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	holder.add_child(mode_row)

	var is_lb: bool = (str(host.current_clans_subtab) == "leaderboard")
	var btn_dir := CafeSocialTheme.make_button("فهرست و جستجو", "gold" if not is_lb else "muted", Vector2(0, 52), 21)
	btn_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dir.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "discover"
		host._refresh_current_tab()
	)
	mode_row.add_child(btn_dir)

	var btn_lb := CafeSocialTheme.make_button("جدول برترین اتحادها", "gold" if is_lb else "muted", Vector2(0, 52), 21)
	btn_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_lb.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "leaderboard"
		host._refresh_current_tab()
	)
	mode_row.add_child(btn_lb)

	var has_clan := false
	if typeof(host._my_clan_data.get("clan")) == TYPE_DICTIONARY and not host._my_clan_data["clan"].is_empty():
		has_clan = true
	if not has_clan:
		var btn_new_c := CafeSocialTheme.make_button("ساخت اتحاد (رایگان)", "emerald", Vector2(210, 52), 21)
		btn_new_c.pressed.connect(func():
			AudioManager.sfx_button()
			open_clan_create_modal(host)
		)
		mode_row.add_child(btn_new_c)

	if is_lb:
		_build_clan_leaderboard_inner(host, holder)
	else:
		_build_clan_search_inner(host, holder)


static func _build_clan_search_inner(host: Control, holder: VBoxContainer) -> void:
	var s_card := PanelContainer.new()
	s_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))
	holder.add_child(s_card)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	s_card.add_child(sv)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 10)
	sv.add_child(s_row)

	var inp := CafeSocialTheme.make_line_edit("جستجوی نام یا تگ اتحاد (مثلاً CAFE#)...", 60.0, 22)
	inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_row.add_child(inp)

	var filter_jt := [""]
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	sv.add_child(filter_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)

	var res_vbox := VBoxContainer.new()
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 10)
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
						"عبارت جستجو یا فیلتر عضویت را تغییر دهید یا اتحاد جدید خود را بسازید."
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
			fb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "normal", 11))
			fb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if active else "muted", "hover", 11))

	for fd in f_defs:
		var fid: String = fd["id"]
		var fb := CafeSocialTheme.make_button(fd["label"], "muted", Vector2(0, 44), 22)
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

	var btn_s := CafeSocialTheme.make_button("جستجو", "gold", Vector2(142, 60), 25)
	btn_s.pressed.connect(func():
		AudioManager.sfx_tap()
		do_search.call()
	)
	inp.text_submitted.connect(func(_t: String): do_search.call())
	s_row.add_child(btn_s)

	do_search.call()


static func _build_clan_directory_card(host: Control, cl: Dictionary, rank_num: int = 0) -> PanelContainer:
	var cid := str(cl.get("clan_id", cl.get("_id", "")))
	var cname := str(cl.get("name", "اتحاد"))
	var ctag := str(cl.get("tag", ""))
	var emb_id := int(cl.get("emblem_id", 1))
	var lvl := int(cl.get("clan_level", 1))
	var cscore := int(cl.get("clan_score", 0))
	var mem_cnt := int(cl.get("member_count", 1))
	var max_mem := int(cl.get("max_members", 50))
	var jtype := str(cl.get("join_type", "open"))
	var jtype_fa := "آزاد" if jtype == "open" else ("درخواستی" if jtype == "request" else "دعوت‌نامه‌ای")

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			CafeSocialTheme.show_clan_details_modal(host, cid, cl)
	)
	card.add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)

	# Left metrics
	var left_col := VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 6)
	row.add_child(left_col)
	left_col.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(cscore), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 21))
	left_col.add_child(CafeSocialTheme.make_badge_pill("اعضا %s/%s" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 20))

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var title_prefix := "#%s  " % GameManager.to_fa_num(rank_num) if rank_num > 0 else ""
	info.add_child(CafeSocialTheme.make_title("%s%s  [%s]" % [title_prefix, cname, ctag], 30, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	info.add_child(CafeSocialTheme.make_body("سطح %s  •  عضویت: %s" % [GameManager.to_fa_num(lvl), jtype_fa], 22, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	row.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 78.0))

	if jtype != "invite_only":
		var b_join := CafeSocialTheme.make_button("عضویت در اتحاد" if jtype == "open" else "ارسال درخواست عضویت", "emerald" if jtype == "open" else "bronze", Vector2(0, 48), 23)
		b_join.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.join_or_request_clan(cid, "درخواست عضویت از باشگاه کافه فکر", func(ok_j: bool, _cj: int, dj: Variant):
				if ok_j:
					host._show_toast("عضویت یا درخواست شما با موفقیت ثبت شد!")
					host.current_clans_subtab = "my_clan"
					host._refresh_current_tab()
				elif typeof(dj) == TYPE_DICTIONARY:
					host._show_toast(str(dj.get("detail", "خطا در عضویت")), CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		root.add_child(b_join)

	return card


static func _build_clan_leaderboard_inner(host: Control, holder: VBoxContainer) -> void:
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 8)
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
	lb_vbox.add_theme_constant_override("separation", 10)
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
					CafeSocialTheme.ICO_FIRST,
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


static func open_clan_create_modal(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 45

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
	card.custom_minimum_size = Vector2(880, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 44)
	m.add_theme_constant_override("margin_right", 44)
	m.add_theme_constant_override("margin_top", 36)
	m.add_theme_constant_override("margin_bottom", 36)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var bx := TextureButton.new()
	bx.texture_normal = CafeSocialTheme.TEX_CLOSE
	bx.custom_minimum_size = Vector2(54, 54)
	bx.ignore_texture_size = true
	bx.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bx.pressed.connect(func():
		AudioManager.sfx_button()
		overlay.queue_free()
	)
	top.add_child(bx)
	var ttl := CafeSocialTheme.make_title("تاسیس اتحاد جدید", 38, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(54, 54)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_badge_pill("ساخت اتحاد رایگان است • سهمیه هر بازیکن: ۱ اتحاد", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 22))

	# Emblem Picker
	vbox.add_child(CafeSocialTheme.make_body("نشان (لوگو) اتحاد را انتخاب کنید:", 24, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var selected_emblem := [1]
	var emb_grid := HBoxContainer.new()
	emb_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	emb_grid.add_theme_constant_override("separation", 10)
	vbox.add_child(emb_grid)

	var emb_wraps: Dictionary = {}
	var update_emb_sel := func():
		for eid in emb_wraps.keys():
			var eb: Button = emb_wraps[eid]
			var act: bool = (eid == selected_emblem[0])
			eb.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.16, 0.08) if act else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_GOLD_BRIGHT if act else CafeSocialTheme.COL_BRONZE_BORDER,
				14, 3 if act else 1, 6.0, 6.0
			))
			eb.add_theme_stylebox_override("hover", eb.get_theme_stylebox("normal"))

	for ecfg in CafeSocialTheme.CLAN_EMBLEMS:
		var eid: int = int(ecfg["id"])
		var eb := Button.new()
		eb.custom_minimum_size = Vector2(82, 82)
		eb.focus_mode = Control.FOCUS_NONE
		var em_vis := CafeSocialTheme.make_clan_emblem(eid, 66.0)
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

	var inp_name := CafeSocialTheme.make_line_edit("نام اتحاد (۳ تا ۲۴ حرف، مثلاً: عقاب‌های کافه فکر)", 62.0, 25)
	vbox.add_child(inp_name)

	var inp_tag := CafeSocialTheme.make_line_edit("تگ یکتای اتحاد (۲ تا ۱۰ حرف یا عدد، مثلاً: CAFE1)", 62.0, 25)
	vbox.add_child(inp_tag)

	var inp_desc := CafeSocialTheme.make_line_edit("معرفی کوتاه و قوانین اتحاد (اختیاری)...", 62.0, 24)
	vbox.add_child(inp_desc)

	var join_type_val := ["open"]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 10)
	vbox.add_child(jt_row)

	var b_jt_req := CafeSocialTheme.make_button("نیازمند تایید", "muted", Vector2(0, 52), 24)
	b_jt_req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_jt_open := CafeSocialTheme.make_button("عضویت آزاد", "emerald", Vector2(0, 52), 24)
	b_jt_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var refresh_jt := func():
		b_jt_open.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "open" else "muted", "normal", 13))
		b_jt_req.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if join_type_val[0] == "request" else "muted", "normal", 13))
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
	jt_row.add_child(CafeSocialTheme.make_body("نوع عضویت:", 24, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var err_panel := PanelContainer.new()
	err_panel.visible = false
	err_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.28, 0.08, 0.08, 0.96), CafeSocialTheme.COL_CRIMSON_TEXT, 12, 2, 12.0, 8.0))
	var err_lbl := CafeSocialTheme.make_body("", 22, CafeSocialTheme.COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	err_panel.add_child(err_lbl)
	vbox.add_child(err_panel)

	var b_submit := CafeSocialTheme.make_button("تاسیس اتحاد (رایگان)", "gold", Vector2(0, 66), 28, CafeSocialTheme.ICO_CHECK, true)
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
	card.custom_minimum_size = Vector2(820, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 42)
	m.add_theme_constant_override("margin_right", 42)
	m.add_theme_constant_override("margin_top", 34)
	m.add_theme_constant_override("margin_bottom", 34)
	card.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	m.add_child(vbox)

	vbox.add_child(CafeSocialTheme.make_title("تنظیمات اتحاد %s" % str(cdict.get("name", "")), 37, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_desc := CafeSocialTheme.make_line_edit("توضیحات اتحاد...", 60.0, 24)
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
			b.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if jk == jt_val[0] else "muted", "normal", 12))
	for jd in jt_defs:
		var jid: String = jd["id"]
		var jb := CafeSocialTheme.make_button(jd["label"], "muted", Vector2(0, 50), 23)
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
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var b_cancel := CafeSocialTheme.make_button("بستن", "bronze", Vector2(0, 56), 24)
	b_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_cancel.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(b_cancel)

	var b_save := CafeSocialTheme.make_button("ذخیره تغییرات", "emerald", Vector2(0, 56), 24, CafeSocialTheme.ICO_CHECK)
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


static func _build_challenge_action_row(host: Control, meta: Dictionary, my_uid: String, my_role: String, _in_chat: bool = false) -> HBoxContainer:
	var ch_id: String = str(meta.get("challenge_id", ""))
	var chal_gt: String = str(meta.get("game_type", "Monopoly"))
	var chal_creator: String = str(meta.get("creator_id", ""))
	var chal_status: String = str(meta.get("status", "open"))
	var p_count: int = int(meta.get("player_count", 2))
	if p_count < 2:
		p_count = 2
	elif p_count > 4:
		p_count = 4
	var parts: Array = meta.get("participants", []) if typeof(meta.get("participants")) == TYPE_ARRAY else []

	var act_row := HBoxContainer.new()
	act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	act_row.add_theme_constant_override("separation", 10)

	if chal_status == "closed":
		act_row.add_child(CafeSocialTheme.make_badge_pill(
			"چالش بسته شد",
			CafeSocialTheme.COL_CRIMSON_TEXT,
			Color(0.22, 0.06, 0.06, 0.94),
			CafeSocialTheme.COL_CRIMSON_BORDER,
			19
		))
		return act_row

	if chal_status == "started":
		act_row.add_child(CafeSocialTheme.make_badge_pill(
			"مسابقه شروع شد",
			CafeSocialTheme.COL_EMERALD_TEXT,
			CafeSocialTheme.COL_EMERALD_BG,
			CafeSocialTheme.COL_EMERALD_BORDER,
			19
		))
		return act_row

	var already_joined: bool = false
	for pt in parts:
		if typeof(pt) == TYPE_DICTIONARY and str(pt.get("user_id", "")) == my_uid:
			already_joined = true
			break
	if not already_joined and not chal_creator.is_empty() and chal_creator == my_uid:
		already_joined = true

	var cur_players: int = parts.size() if not parts.is_empty() else 1
	act_row.add_child(CafeSocialTheme.make_badge_pill(
		"%s از %s نفر" % [GameManager.to_fa_num(cur_players), GameManager.to_fa_num(p_count)],
		CafeSocialTheme.COL_GOLD_BRIGHT,
		Color(0.10, 0.06, 0.03, 0.95),
		CafeSocialTheme.COL_GOLD_ANTIQUE,
		19
	))

	var can_close: bool = (not ch_id.is_empty()) and (chal_creator == my_uid or my_role in ["leader", "co_leader"])
	if can_close:
		var b_close_chal := CafeSocialTheme.make_button("بستن چالش", "crimson", Vector2(150, 44), 21)
		b_close_chal.pressed.connect(func():
			AudioManager.sfx_tap()
			b_close_chal.disabled = true
			NetworkManager.api.close_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					host._show_toast("چالش دوستانه بسته شد.")
					host._refresh_current_tab()
				else:
					if is_instance_valid(b_close_chal):
						b_close_chal.disabled = false
					var err_txt: String = "خطا در بستن چالش"
					if typeof(res_d) == TYPE_DICTIONARY:
						err_txt = str(res_d.get("detail", err_txt))
					host._show_toast(err_txt, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_close_chal)

	if not ch_id.is_empty() and chal_creator == my_uid and cur_players >= 2:
		var b_start := CafeSocialTheme.make_button("شروع بازی", "emerald", Vector2(148, 44), 21)
		b_start.pressed.connect(func():
			AudioManager.sfx_button()
			b_start.disabled = true
			NetworkManager.start_clan_challenge_realtime(ch_id)
			host._show_toast("در حال شروع مسابقه دوستانه...")
		)
		act_row.add_child(b_start)

	if not already_joined and cur_players < p_count:
		var join_label: String = "پیوستن به چالش" if p_count > 2 else "قبول چالش"
		var b_acc := CafeSocialTheme.make_button(join_label, "emerald", Vector2(168, 44), 21)
		b_acc.pressed.connect(func():
			AudioManager.sfx_button()
			b_acc.disabled = true
			if ch_id.is_empty():
				if not chal_creator.is_empty():
					NetworkManager.send_game_invite_realtime(chal_creator, chal_gt, "direct_match")
					host._show_toast("درخواست بازی دوستانه ارسال شد!")
				return
			NetworkManager.api.join_clan_friendly_challenge(ch_id, func(ok: bool, _c: int, res_d: Variant):
				if ok:
					var res_obj: Dictionary = {}
					if typeof(res_d) == TYPE_DICTIONARY:
						res_obj = res_d.get("result", res_d) if typeof(res_d.get("result", res_d)) == TYPE_DICTIONARY else {}
					var is_full: bool = bool(res_obj.get("is_full", false))
					if is_full:
						NetworkManager.start_clan_challenge_realtime(ch_id)
						host._show_toast("ظرفیت تکمیل شد! در حال شروع بازی...")
					else:
						host._show_toast("به چالش دوستانه پیوستید! منتظر شروع...")
						host._refresh_current_tab()
				else:
					if is_instance_valid(b_acc):
						b_acc.disabled = false
					var err_txt: String = "خطا در پیوستن به چالش"
					if typeof(res_d) == TYPE_DICTIONARY:
						err_txt = str(res_d.get("detail", err_txt))
					host._show_toast(err_txt, CafeSocialTheme.COL_CRIMSON_TEXT)
			)
		)
		act_row.add_child(b_acc)
	elif already_joined and chal_creator != my_uid:
		act_row.add_child(CafeSocialTheme.make_badge_pill(
			"در انتظار شروع",
			CafeSocialTheme.COL_EMERALD_TEXT,
			CafeSocialTheme.COL_EMERALD_BG,
			CafeSocialTheme.COL_EMERALD_BORDER,
			18
		))

	return act_row


static func _build_overview_challenge_card(host: Control, chal: Dictionary, my_uid: String, my_role: String) -> PanelContainer:
	var gt: String = str(chal.get("game_type", "Monopoly"))
	var gt_fa: String = str(chal.get("game_title_fa", ""))
	if gt_fa.is_empty():
		gt_fa = GameRegistry.get_display_name_fa(gt)
	var creator_name: String = str(chal.get("creator_name", "هم‌اتحادی"))
	var p_count: int = int(chal.get("player_count", 2))
	if p_count < 2:
		p_count = 2
	elif p_count > 4:
		p_count = 4

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 20.0, 16.0))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)

	info.add_child(CafeSocialTheme.make_title(
		"چالش دوستانه %s (%s نفره)" % [gt_fa, GameManager.to_fa_num(p_count)],
		27, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true
	))
	info.add_child(CafeSocialTheme.make_body(
		"ساخته‌شده توسط %s" % creator_name,
		20, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true
	))

	var thumb_tex: Texture2D = CafeSocialTheme.get_game_thumb(gt)
	if thumb_tex != null:
		var tr := TextureRect.new()
		tr.texture = thumb_tex
		tr.custom_minimum_size = Vector2(68, 68)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		top.add_child(tr)

	v.add_child(_build_challenge_action_row(host, chal, my_uid, my_role, false))
	return card


static func _open_friendly_challenge_modal(host: Control) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 45

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
	card.custom_minimum_size = Vector2(880, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 36)
	m.add_theme_constant_override("margin_right", 36)
	m.add_theme_constant_override("margin_top", 28)
	m.add_theme_constant_override("margin_bottom", 28)
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

	var ttl := CafeSocialTheme.make_title("ایجاد چالش دوستانه در اتحاد", 36, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(52, 52)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_body("بازی مورد نظر و تعداد بازیکنان را انتخاب کنید:", 23, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var selected_gid: Array = [GameTypes.MONOPOLY]
	var selected_pcount: Array = [2]
	var game_cards: Dictionary = {}
	var pcount_btns: Dictionary = {}

	# Scrollable all-games picker matching LobbyDialog
	var g_scroll := ScrollContainer.new()
	g_scroll.custom_minimum_size = Vector2(0, 500)
	g_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(g_scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	g_scroll.add_child(grid)

	# Player count selector panel (for 2-4 player games)
	var pcount_panel := PanelContainer.new()
	pcount_panel.custom_minimum_size = Vector2(0, 96)
	pcount_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 38.0, 18.0))
	vbox.add_child(pcount_panel)

	var pcount_row := HBoxContainer.new()
	pcount_row.add_theme_constant_override("separation", 10)
	pcount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pcount_panel.add_child(pcount_row)

	var p_btns_row := HBoxContainer.new()
	p_btns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_btns_row.add_theme_constant_override("separation", 10)
	pcount_row.add_child(p_btns_row)

	var p_lbl := CafeSocialTheme.make_title("تعداد بازیکنان:", 26, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	pcount_row.add_child(p_lbl)

	var lbl_sel_summary := CafeSocialTheme.make_badge_pill(
		"",
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		21
	)
	vbox.add_child(lbl_sel_summary)

	var refresh_pcount_ui := func():
		var cur_gid: String = str(selected_gid[0])
		var is_multi: bool = GameRegistry.is_multiplayer_game(cur_gid)
		pcount_panel.visible = is_multi
		if not is_multi:
			selected_pcount[0] = 2
		for cnt_key in pcount_btns.keys():
			var pb: Button = pcount_btns[cnt_key]
			var act: bool = (int(cnt_key) == int(selected_pcount[0]))
			pb.add_theme_stylebox_override("normal", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "normal", 12))
			pb.add_theme_stylebox_override("hover", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "hover", 12))
			pb.add_theme_stylebox_override("pressed", CafeSocialTheme._get_flat_btn_style("emerald" if act else "muted", "pressed", 12))
		for gk in game_cards.keys():
			var gbtn: Button = game_cards[gk]
			var g_act: bool = (str(gk) == cur_gid)
			gbtn.add_theme_stylebox_override("normal", CafeSocialTheme.create_card_style(
				Color(0.24, 0.17, 0.08, 0.98) if g_act else Color(0.11, 0.07, 0.04, 0.95),
				CafeSocialTheme.COL_GOLD_BRIGHT if g_act else CafeSocialTheme.COL_BRONZE_BORDER,
				14, 3 if g_act else 1, 10.0, 10.0
			))
			gbtn.add_theme_stylebox_override("hover", gbtn.get_theme_stylebox("normal"))
			gbtn.add_theme_stylebox_override("pressed", gbtn.get_theme_stylebox("normal"))
		var summary_lbl: Label = lbl_sel_summary.get_child(0) as Label
		if is_instance_valid(summary_lbl):
			summary_lbl.text = "انتخاب فعلی: %s (%s نفره)" % [
				GameRegistry.get_display_name_fa(cur_gid),
				GameManager.to_fa_num(int(selected_pcount[0]))
			]

	var cnt_labels: Dictionary = {2: "۲ نفره", 3: "۳ نفره", 4: "۴ نفره"}
	for cnt in [2, 3, 4]:
		var chosen_cnt: int = int(cnt)
		var pb := CafeSocialTheme.make_button(str(cnt_labels[cnt]), "muted", Vector2(0, 54), 24)
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
		gbtn.custom_minimum_size = Vector2(0, 112)
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.focus_mode = Control.FOCUS_NONE
		gbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 12)
		var hm := MarginContainer.new()
		hm.set_anchors_preset(Control.PRESET_FULL_RECT)
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hm.add_theme_constant_override("margin_left", 12)
		hm.add_theme_constant_override("margin_right", 12)
		hm.add_theme_constant_override("margin_top", 10)
		hm.add_theme_constant_override("margin_bottom", 10)
		hm.add_child(h)
		gbtn.add_child(hm)

		var g_info := VBoxContainer.new()
		g_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g_info.alignment = BoxContainer.ALIGNMENT_CENTER
		g_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_info.add_theme_constant_override("separation", 4)
		h.add_child(g_info)

		var g_lbl := CafeSocialTheme.make_title(g_title, 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
		g_lbl.clip_text = true
		g_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		g_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_info.add_child(g_lbl)

		var p_badge := CafeSocialTheme.make_badge_pill(
			"۲ تا ۴ نفره" if is_multi_g else "۲ نفره",
			CafeSocialTheme.COL_GOLD_BRIGHT if is_multi_g else CafeSocialTheme.COL_MUTED_SAND,
			Color(0.14, 0.09, 0.04, 0.92),
			CafeSocialTheme.COL_GOLD_ANTIQUE if is_multi_g else CafeSocialTheme.COL_BRONZE_BORDER,
			16
		)
		p_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		p_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_info.add_child(p_badge)

		var th_tex: Texture2D = CafeSocialTheme.get_game_thumb(g_str)
		if th_tex != null:
			var th := TextureRect.new()
			th.texture = th_tex
			th.custom_minimum_size = Vector2(78, 78)
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
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var bc := CafeSocialTheme.make_button("انصراف", "muted", Vector2(180, 56), 24)
	bc.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(bc)

	var b_submit := CafeSocialTheme.make_button("ارسال چالش دوستانه", "emerald", Vector2(320, 56), 25)
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		b_submit.disabled = true
		var gid_s: String = str(selected_gid[0])
		var cnt_i: int = int(selected_pcount[0])
		NetworkManager.api.create_clan_friendly_challenge(gid_s, cnt_i, func(ok: bool, _c: int, _d: Variant):
			if ok:
				overlay.queue_free()
				host._show_toast("چالش دوستانه «%s» (%s نفره) در اتحاد اعلام شد!" % [
					GameRegistry.get_display_name_fa(gid_s),
					GameManager.to_fa_num(cnt_i)
				])
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


static func _open_member_manage_modal(host: Control, m_dict: Dictionary, my_role: String) -> void:
	var m_uid := str(m_dict.get("user_id", ""))
	var m_name := str(m_dict.get("username", "بازیکن"))
	var m_role := str(m_dict.get("role", "member"))

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
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	vbox.add_child(CafeSocialTheme.make_title("مدیریت عضو: %s" % m_name, 35, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	if my_role in ["leader", "co_leader"]:
		if m_role == "member":
			var b_p1 := CafeSocialTheme.make_button("ارتقا به ارشد (Elder)", "sapphire", Vector2(0, 56), 25)
			b_p1.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "elder", func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه %s به ارشد ارتقا یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p1)
		elif m_role == "elder" and my_role == "leader":
			var b_p2 := CafeSocialTheme.make_button("ارتقا به قائم‌مقام رهبر", "sapphire", Vector2(0, 56), 25)
			b_p2.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "co_leader", func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه %s به قائم‌مقام ارتقا یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p2)

		if m_role in ["elder", "co_leader"] and my_role == "leader":
			var target_r := "member" if m_role == "elder" else "elder"
			var b_dem := CafeSocialTheme.make_button("تنزل درجه", "bronze", Vector2(0, 56), 25)
			b_dem.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, target_r, func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه %s تغییر یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_dem)

	if my_role == "leader":
		var b_lead := CafeSocialTheme.make_button("انتقال رهبری اتحاد به این عضو", "gold", Vector2(0, 56), 25, CafeSocialTheme.ICO_KING)
		b_lead.pressed.connect(func():
			overlay.queue_free()
			CafeSocialTheme.show_confirm_modal(
				host, "انتقال رهبری اتحاد",
				"آیا مطمئن هستید می‌خواهید رهبری اتحاد را به «%s» واگذار کنید؟" % m_name,
				"انتقال رهبری", true,
				func():
					NetworkManager.api.transfer_clan_leadership(m_uid, func(_ok, _c, _d):
						host._show_toast("رهبری اتحاد به %s منتقل شد." % m_name)
						host._refresh_current_tab()
					)
			)
		)
		vbox.add_child(b_lead)

	var b_kick := CafeSocialTheme.make_button("اخراج از اتحاد", "crimson", Vector2(0, 56), 25)
	b_kick.pressed.connect(func():
		overlay.queue_free()
		CafeSocialTheme.show_confirm_modal(
			host, "اخراج عضو",
			"آیا می‌خواهید «%s» را از اتحاد اخراج کنید؟" % m_name,
			"اخراج شود", true,
			func():
				NetworkManager.api.kick_clan_member(m_uid, func(_ok, _c, _d):
					host._show_toast("«%s» از اتحاد اخراج شد." % m_name)
					host._refresh_current_tab()
				)
		)
	)
	vbox.add_child(b_kick)

	var b_close := CafeSocialTheme.make_button("بستن", "muted", Vector2(0, 52), 23)
	b_close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(b_close)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
