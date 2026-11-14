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
	sub_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(14, 8.0, 8.0))
	body_vbox.add_child(sub_bar)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	sub_bar.add_child(sub_row)

	var subtabs := [
		{"id": "my_clan", "label": "کلن من"},
		{"id": "members", "label": "اعضا"},
		{"id": "chat", "label": "چت کلن"},
		{"id": "discover", "label": "کلن‌ها و رتبه‌بندی"},
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
		content_holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت اطلاعات کلن..."))
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
					"خطا در دریافت اطلاعات کلن",
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
	hero.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false))
	vbox.add_child(hero)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 14)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(hv)

	var shield := CafeSocialTheme.make_clan_emblem(1, 96.0)
	hv.add_child(shield)

	hv.add_child(CafeSocialTheme.make_title("به یک کلن بپیوندید یا کلن خودتان را بسازید!", 32, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	hv.add_child(CafeSocialTheme.make_body(
		"در کلن‌های کافه فکر می‌توانید با دوستان و هم‌تیمی‌های خود چت کنید، چالش‌های هفتگی کلن را فتح نمایید، بازی دوستانه بسازید و نام کلن خود را در صدر جدول قهرمانان ثبت کنید.",
		21, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true
	))
	hv.add_child(CafeSocialTheme.make_badge_pill(
		"تاسیس کلن کاملاً رایگان است (سهمیه هر بازیکن: ۱ کلن)",
		CafeSocialTheme.COL_EMERALD_TEXT,
		CafeSocialTheme.COL_EMERALD_BG,
		CafeSocialTheme.COL_EMERALD_BORDER,
		20
	))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(btn_row)

	var b_search := CafeSocialTheme.make_button("جستجو و عضویت در کلن", "emerald", Vector2(0, 58), 22, CafeSocialTheme.ICO_RANKING)
	b_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_search.pressed.connect(func():
		AudioManager.sfx_tap()
		host.current_clans_subtab = "discover"
		host._refresh_current_tab()
	)
	btn_row.add_child(b_search)

	var b_create := CafeSocialTheme.make_button("تاسیس کلن جدید (رایگان)", "gold", Vector2(0, 58), 22, CafeSocialTheme.BADGE_PLUS)
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
			"دعوت‌نامه‌های کلن برای شما", CafeSocialTheme.ICO_STAR,
			"%s دعوت‌نامه در انتظار پاسخ" % GameManager.to_fa_num(invs.size())
		))
		for inv in invs:
			if typeof(inv) != TYPE_DICTIONARY:
				continue
			var c_sub: Dictionary = inv.get("clan", {}) if typeof(inv.get("clan")) == TYPE_DICTIONARY else {}
			var cname := str(c_sub.get("name", "کلن"))
			var ctag := str(c_sub.get("tag", ""))
			var emb := int(c_sub.get("emblem_id", 1))
			var inv_id := str(inv.get("invite_id", ""))

			var icard := PanelContainer.new()
			icard.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
			vbox.add_child(icard)

			var irow := HBoxContainer.new()
			irow.add_theme_constant_override("separation", 12)
			icard.add_child(irow)

			var b_rej := CafeSocialTheme.make_button("رد", "crimson", Vector2(96, 48), 20)
			b_rej.pressed.connect(func():
				AudioManager.sfx_tap()
				NetworkManager.api.respond_clan_invitation(inv_id, "reject", func(_ok: bool, _c: int, _d: Variant):
					host._refresh_current_tab()
				)
			)
			irow.add_child(b_rej)

			var b_acc := CafeSocialTheme.make_button("پیوستن", "emerald", Vector2(140, 48), 20, CafeSocialTheme.ICO_CHECK)
			b_acc.pressed.connect(func():
				AudioManager.sfx_button()
				NetworkManager.api.respond_clan_invitation(inv_id, "accept", func(ok: bool, _c: int, d: Variant):
					if ok:
						host._show_toast("به کلن «%s» خوش آمدید!" % cname)
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
	hero.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false))
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
	badges_col.add_child(CafeSocialTheme.make_badge_pill("سطح %s" % GameManager.to_fa_num(clan_lvl), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 19))
	badges_col.add_child(CafeSocialTheme.make_badge_pill("سمت: %s" % my_role_fa, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 18))

	# Center Info
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 4)
	top_bar.add_child(info_col)

	info_col.add_child(CafeSocialTheme.make_title("%s  [%s]" % [str(cdict.get("name", "")), str(cdict.get("tag", ""))], 32, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	var desc_txt := str(cdict.get("description", "")).strip_edges()
	info_col.add_child(CafeSocialTheme.make_body(desc_txt if not desc_txt.is_empty() else "باشگاه رسمی بازیکنان کافه فکر", 20, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))

	# Right Emblem
	top_bar.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 92.0))

	# Clan XP Progress Bar
	hv.add_child(CafeSocialTheme.make_xp_progress_bar(
		float(clan_xp % next_xp) / float(next_xp),
		"تجربه کلن: %s / %s XP" % [GameManager.to_fa_num(clan_xp % next_xp), GameManager.to_fa_num(next_xp)],
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

	var b_leave := CafeSocialTheme.make_button("انحلال کلن" if my_role == "leader" else "خروج از کلن", "crimson", Vector2(0, 50), 20)
	b_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_leave.pressed.connect(func():
		if my_role == "leader":
			CafeSocialTheme.show_confirm_modal(
				host, "انحلال کلن",
				"آیا مطمئن هستید می‌خواهید کلن «%s» را منحل کنید؟ تمام اعضای کلن خارج خواهند شد." % str(cdict.get("name", "")),
				"بله، منحل شود", true,
				func():
					NetworkManager.api.disband_clan(func(ok: bool, _c: int, d: Variant):
						if ok:
							host._show_toast("کلن منحل شد.")
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا در انحلال کلن")), CafeSocialTheme.COL_CRIMSON_TEXT)
					)
			)
		else:
			CafeSocialTheme.show_confirm_modal(
				host, "خروج از کلن",
				"آیا می‌خواهید از کلن «%s» خارج شوید؟" % str(cdict.get("name", "")),
				"خروج از کلن", true,
				func():
					NetworkManager.api.leave_clan(func(ok: bool, _c: int, d: Variant):
						if ok:
							host._show_toast("از کلن خارج شدید.")
							host._refresh_current_tab()
						elif typeof(d) == TYPE_DICTIONARY:
							host._show_toast(str(d.get("detail", "خطا")), CafeSocialTheme.COL_CRIMSON_TEXT)
					)
			)
	)
	act_row.add_child(b_leave)

	if my_role in ["leader", "co_leader"]:
		var b_settings := CafeSocialTheme.make_button("تنظیمات کلن", "bronze", Vector2(0, 50), 20, CafeSocialTheme.ICO_SETTING)
		b_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_settings.pressed.connect(func():
			AudioManager.sfx_tap()
			_open_clan_settings_modal(host, cdict)
		)
		act_row.add_child(b_settings)

	var b_chal := CafeSocialTheme.make_button("چالش دوستانه", "emerald", Vector2(0, 50), 20, CafeSocialTheme.ICO_CUP)
	b_chal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_chal.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_friendly_challenge_modal(host)
	)
	act_row.add_child(b_chal)

	# 2. Weekly Challenges
	var challenges: Array = cdict.get("weekly_challenges", []) if typeof(cdict.get("weekly_challenges")) == TYPE_ARRAY else []
	if not challenges.is_empty():
		vbox.add_child(CafeSocialTheme.make_ornate_section_header(
			"چالش‌های هفتگی کلن", CafeSocialTheme.ICO_CUP, "همکاری اعضای کلن برای دریافت XP کلن"
		))
		for ch in challenges:
			if typeof(ch) != TYPE_DICTIONARY:
				continue
			var ch_card := PanelContainer.new()
			var done := bool(ch.get("completed", false))
			ch_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(done))
			vbox.add_child(ch_card)

			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 8)
			ch_card.add_child(cv)

			var cr := HBoxContainer.new()
			cv.add_child(cr)
			cr.add_child(CafeSocialTheme.make_badge_pill(
				"تکمیل شد!" if done else "+%s XP کلن" % GameManager.to_fa_num(int(ch.get("reward_clan_xp", 150))),
				CafeSocialTheme.COL_EMERALD_TEXT if done else CafeSocialTheme.COL_GOLD_BRIGHT,
				CafeSocialTheme.COL_EMERALD_BG if done else Color(0.10, 0.06, 0.03),
				CafeSocialTheme.COL_EMERALD_BORDER if done else CafeSocialTheme.COL_BRONZE_BORDER,
				18
			))
			var ct := CafeSocialTheme.make_title(str(ch.get("title", "")), 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true)
			ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cr.add_child(ct)

			cv.add_child(CafeSocialTheme.make_body(str(ch.get("desc", "")), 19, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_RIGHT, true))
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
			rcard.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
			vbox.add_child(rcard)

			var rrow := HBoxContainer.new()
			rrow.add_theme_constant_override("separation", 10)
			rcard.add_child(rrow)

			var b_no := CafeSocialTheme.make_button("رد", "crimson", Vector2(90, 46), 19)
			b_no.pressed.connect(func():
				NetworkManager.api.respond_clan_join_request(rid, "reject", func(_ok, _c, _d): host._refresh_current_tab())
			)
			rrow.add_child(b_no)

			var b_ok := CafeSocialTheme.make_button("پذیرش", "emerald", Vector2(120, 46), 19, CafeSocialTheme.ICO_CHECK)
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
			rcol.add_child(CafeSocialTheme.make_title(str(ru.get("username", "بازیکن")), 24, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT))
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
		"اعضای کلن %s" % str(cdict.get("name", "")),
		CafeSocialTheme.ICO_ARMY,
		"%s عضو فعال • برای مشاهده پروفایل یا مدیریت عضو روی کارت ضربه بزنید" % GameManager.to_fa_num(members.size())
	))

	var my_uid := str(GameManager.get_user_id())
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var m_uid := str(m.get("user_id", ""))
		var m_name := str(m.get("username", "بازیکن"))
		var m_role := str(m.get("role", "member"))
		var m_role_fa := str(m.get("role_title", m.get("role_fa", "عضو")))
		var m_contrib := int(m.get("weekly_contribution", 0))
		var m_pres: Dictionary = m.get("presence", {}) if typeof(m.get("presence")) == TYPE_DICTIONARY else {}
		var p_info := CafeSocialTheme.format_presence(m_pres)

		var mcard := PanelContainer.new()
		mcard.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false) if m_role == "leader" else CafeSocialTheme.create_card_style())
		vbox.add_child(mcard)

		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 12)
		mcard.add_child(mrow)

		var act_col := VBoxContainer.new()
		act_col.alignment = BoxContainer.ALIGNMENT_CENTER
		act_col.add_theme_constant_override("separation", 6)
		mrow.add_child(act_col)

		var b_prof := CafeSocialTheme.make_button("پروفایل", "bronze", Vector2(120, 44), 19)
		b_prof.pressed.connect(func():
			AudioManager.sfx_tap()
			host._open_player_profile(m)
		)
		act_col.add_child(b_prof)

		var can_manage := (m_uid != my_uid) and (
			my_role == "leader"
			or (my_role == "co_leader" and m_role in ["elder", "member"])
			or (my_role == "elder" and m_role == "member")
		)
		if can_manage:
			var b_mgr := CafeSocialTheme.make_button("مدیریت", "gold", Vector2(120, 44), 19, CafeSocialTheme.ICO_SETTING)
			b_mgr.pressed.connect(func():
				AudioManager.sfx_tap()
				_open_member_manage_modal(host, m, my_role)
			)
			act_col.add_child(b_mgr)

		var m_col := VBoxContainer.new()
		m_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_col.alignment = BoxContainer.ALIGNMENT_CENTER
		m_col.add_theme_constant_override("separation", 4)
		mrow.add_child(m_col)

		var role_col := CafeSocialTheme.COL_GOLD_BRIGHT if m_role == "leader" else (CafeSocialTheme.COL_EMERALD_TEXT if m_role == "co_leader" else CafeSocialTheme.COL_WARM_CREAM)
		m_col.add_child(CafeSocialTheme.make_title("%s  •  [%s]" % [m_name, m_role_fa], 25, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
		m_col.add_child(CafeSocialTheme.make_body(
			"مشارکت هفتگی: %s  |  امتیاز: %s  |  %s" % [
				GameManager.to_fa_num(m_contrib),
				GameManager.to_fa_num(int(m.get("score", 0))),
				p_info["text"]
			],
			19, role_col, HORIZONTAL_ALIGNMENT_RIGHT, true
		))

		mrow.add_child(CafeSocialTheme.make_avatar_badge(int(m.get("image", 0)), int(m.get("profile_frame", 0)), 74.0, str(m_pres.get("status", "offline")), true))


static func _build_clan_chat_view(host: Control, holder: VBoxContainer) -> void:
	var well := PanelContainer.new()
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 12.0, 12.0))
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
	host._clan_chat_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت گفتگوهای کلن..."))

	var compose := PanelContainer.new()
	compose.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_MAHOGANY_CARD, CafeSocialTheme.COL_GOLD_ANTIQUE, 16, 2, 12.0, 10.0))
	holder.add_child(compose)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	compose.add_child(input_row)

	var btn_send := CafeSocialTheme.make_button("ارسال", "emerald", Vector2(142, 64), 23, CafeSocialTheme.TEX_REPLY)
	input_row.add_child(btn_send)

	host._clan_chat_input = CafeSocialTheme.make_line_edit("پیام خود را برای اعضای کلن بنویسید (برای منشن از @ استفاده کنید)...", 64.0, 22)
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
				"چت کلن در دسترس نیست",
				"برای استفاده از گفتگوی کلن ابتدا وارد یک کلن شوید.",
				"یافتن کلن", "gold", func():
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
			"اولین پیام یا چالش دوستانه را در چت کلن ثبت کنید!"
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

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		if is_mine or my_role in ["leader", "co_leader", "elder"]:
			if mtype == "text" and not msg_id.is_empty():
				var b_del := CafeSocialTheme.make_button("حذف", "crimson", Vector2(76, 40), 17)
				b_del.pressed.connect(func():
					NetworkManager.api.delete_clan_chat_message(msg_id, func(ok: bool, _c: int, _d: Variant):
						if ok:
							host._clan_chat_messages = host._clan_chat_messages.filter(func(x): return str(x.get("message_id", "")) != msg_id)
							render_clan_chat(host)
					)
				)
				row.add_child(b_del)

		if mtype == "friendly_challenge" or (mtype == "system" and typeof(msg.get("metadata")) == TYPE_DICTIONARY and msg["metadata"].has("challenge_id")):
			var meta: Dictionary = msg.get("metadata", {}) if typeof(msg.get("metadata")) == TYPE_DICTIONARY else {}
			var chal_gt := str(meta.get("game_type", "Monopoly"))
			var chal_creator := str(meta.get("creator_id", ""))
			if not chal_creator.is_empty() and chal_creator != my_uid:
				var b_acc := CafeSocialTheme.make_button("قبول چالش", "emerald", Vector2(148, 46), 19, CafeSocialTheme.ICO_CUP)
				b_acc.pressed.connect(func():
					AudioManager.sfx_button()
					NetworkManager.send_game_invite_realtime(chal_creator, chal_gt, "direct_match")
					host._show_toast("درخواست بازی دوستانه ارسال شد!")
				)
				row.add_child(b_acc)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)

		if mtype == "text":
			var r_lbl: String = role_fa_map.get(sender_role, "عضو")
			var hdr_txt := "%s  •  %s" % [sender_name, r_lbl]
			if not time_str.is_empty():
				hdr_txt += "  (%s)" % time_str
			col.add_child(CafeSocialTheme.make_title(hdr_txt, 22, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
		col.add_child(CafeSocialTheme.make_body(text, 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT if mtype == "text" else HORIZONTAL_ALIGNMENT_CENTER, true))

		if mtype == "text":
			row.add_child(CafeSocialTheme.make_avatar_badge(sender_img, 0, 56.0))

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

	var btn_lb := CafeSocialTheme.make_button("جدول برترین کلن‌ها", "gold" if is_lb else "muted", Vector2(0, 52), 21, CafeSocialTheme.ICO_FIRST)
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
		var btn_new_c := CafeSocialTheme.make_button("ساخت کلن (رایگان)", "emerald", Vector2(210, 52), 21, CafeSocialTheme.BADGE_PLUS)
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
	s_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style())
	holder.add_child(s_card)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	s_card.add_child(sv)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 10)
	sv.add_child(s_row)

	var inp := CafeSocialTheme.make_line_edit("جستجوی نام یا تگ کلن (مثلاً CAFE#)...", 60.0, 22)
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
		res_vbox.add_child(CafeSocialTheme.make_loading_state("در حال جستجوی کلن‌ها..."))
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
						"کلنی با این مشخصات پیدا نشد",
						"عبارت جستجو یا فیلتر عضویت را تغییر دهید یا کلن جدید خود را بسازید."
					))
					return
				for cl in arr:
					if typeof(cl) == TYPE_DICTIONARY:
						res_vbox.add_child(_build_clan_directory_card(host, cl))
		)

	var f_defs := [
		{"id": "", "label": "همه کلن‌ها"},
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
		var fb := CafeSocialTheme.make_button(fd["label"], "muted", Vector2(0, 44), 19)
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

	var btn_s := CafeSocialTheme.make_button("جستجو", "gold", Vector2(142, 60), 22)
	btn_s.pressed.connect(func():
		AudioManager.sfx_tap()
		do_search.call()
	)
	inp.text_submitted.connect(func(_t: String): do_search.call())
	s_row.add_child(btn_s)

	do_search.call()


static func _build_clan_directory_card(host: Control, cl: Dictionary, rank_num: int = 0) -> PanelContainer:
	var cid := str(cl.get("clan_id", cl.get("_id", "")))
	var cname := str(cl.get("name", "کلن"))
	var ctag := str(cl.get("tag", ""))
	var emb_id := int(cl.get("emblem_id", 1))
	var lvl := int(cl.get("clan_level", 1))
	var cscore := int(cl.get("clan_score", 0))
	var mem_cnt := int(cl.get("member_count", 1))
	var max_mem := int(cl.get("max_members", 50))
	var jtype := str(cl.get("join_type", "open"))
	var jtype_fa := "آزاد" if jtype == "open" else ("درخواستی" if jtype == "request" else "دعوت‌نامه‌ای")

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(false) if rank_num in [1, 2, 3] else CafeSocialTheme.create_card_style())

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	card.add_child(root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)

	# Left metrics
	var left_col := VBoxContainer.new()
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 6)
	row.add_child(left_col)
	left_col.add_child(CafeSocialTheme.make_badge_pill("امتیاز %s" % GameManager.to_fa_num(cscore), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.10, 0.06, 0.03), CafeSocialTheme.COL_GOLD_ANTIQUE, 18))
	left_col.add_child(CafeSocialTheme.make_badge_pill("اعضا %s/%s" % [GameManager.to_fa_num(mem_cnt), GameManager.to_fa_num(max_mem)], CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var title_prefix := "#%s  " % GameManager.to_fa_num(rank_num) if rank_num > 0 else ""
	info.add_child(CafeSocialTheme.make_title("%s%s  [%s]" % [title_prefix, cname, ctag], 27, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, true))
	info.add_child(CafeSocialTheme.make_body("سطح %s  •  عضویت: %s" % [GameManager.to_fa_num(lvl), jtype_fa], 19, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, true))

	row.add_child(CafeSocialTheme.make_clan_emblem(emb_id, 78.0))

	if jtype != "invite_only":
		var b_join := CafeSocialTheme.make_button("عضویت در کلن" if jtype == "open" else "ارسال درخواست عضویت", "emerald" if jtype == "open" else "bronze", Vector2(0, 48), 20)
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
	lb_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت جدول رتبه‌بندی کلن‌ها..."))

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
					"هنوز کلنی در جدول ثبت نشده است",
					"اولین کلن خود را بسازید و نامش را در تاریخ کافه فکر ثبت کنید!"
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
	var ttl := CafeSocialTheme.make_title("تاسیس کلن جدید", 36, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ttl)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(54, 54)
	top.add_child(sp)

	vbox.add_child(CafeSocialTheme.make_badge_pill("ساخت کلن رایگان است • سهمیه هر بازیکن: ۱ کلن", CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 20))

	# Emblem Picker
	vbox.add_child(CafeSocialTheme.make_body("نشان (لوگو) کلن را انتخاب کنید:", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
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

	var inp_name := CafeSocialTheme.make_line_edit("نام کلن (۳ تا ۲۴ حرف، مثلاً: عقاب‌های کافه فکر)", 62.0, 22)
	vbox.add_child(inp_name)

	var inp_tag := CafeSocialTheme.make_line_edit("تگ یکتای کلن (۲ تا ۱۰ حرف یا عدد، مثلاً: CAFE1)", 62.0, 22)
	vbox.add_child(inp_tag)

	var inp_desc := CafeSocialTheme.make_line_edit("معرفی کوتاه و قوانین کلن (اختیاری)...", 62.0, 21)
	vbox.add_child(inp_desc)

	var join_type_val := ["open"]
	var jt_row := HBoxContainer.new()
	jt_row.add_theme_constant_override("separation", 10)
	vbox.add_child(jt_row)

	var b_jt_req := CafeSocialTheme.make_button("نیازمند تایید", "muted", Vector2(0, 52), 21)
	b_jt_req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b_jt_open := CafeSocialTheme.make_button("عضویت آزاد", "emerald", Vector2(0, 52), 21)
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
	jt_row.add_child(CafeSocialTheme.make_body("نوع عضویت:", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false))

	var err_panel := PanelContainer.new()
	err_panel.visible = false
	err_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(Color(0.28, 0.08, 0.08, 0.96), CafeSocialTheme.COL_CRIMSON_TEXT, 12, 2, 12.0, 8.0))
	var err_lbl := CafeSocialTheme.make_body("", 19, CafeSocialTheme.COL_CRIMSON_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
	err_panel.add_child(err_lbl)
	vbox.add_child(err_panel)

	var b_submit := CafeSocialTheme.make_button("تاسیس کلن (رایگان)", "gold", Vector2(0, 66), 25, CafeSocialTheme.ICO_CHECK, true)
	b_submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_submit.pressed.connect(func():
		AudioManager.sfx_button()
		err_panel.visible = false
		var c_name := inp_name.text.strip_edges()
		var c_tag := inp_tag.text.strip_edges().lstrip("#").strip_edges()
		if c_name.length() < 3:
			err_lbl.text = "نام کلن باید حداقل ۳ حرف باشد."
			err_panel.visible = true
			return
		if c_tag.length() < 2 or c_tag.length() > 10:
			err_lbl.text = "تگ کلن باید بین ۲ تا ۱۰ حرف یا عدد باشد."
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
				host._show_toast("کلن شما با موفقیت تاسیس شد!")
				host.current_clans_subtab = "my_clan"
				host._refresh_current_tab()
			else:
				if is_instance_valid(b_submit):
					b_submit.disabled = false
				var detail := str(data.get("detail", "خطا در ساخت کلن")) if typeof(data) == TYPE_DICTIONARY else "خطا در ساخت کلن"
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

	vbox.add_child(CafeSocialTheme.make_title("تنظیمات کلن %s" % str(cdict.get("name", "")), 34, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	var inp_desc := CafeSocialTheme.make_line_edit("توضیحات کلن...", 60.0, 21)
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
		var jb := CafeSocialTheme.make_button(jd["label"], "muted", Vector2(0, 50), 20)
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

	var b_cancel := CafeSocialTheme.make_button("بستن", "bronze", Vector2(0, 56), 21)
	b_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_cancel.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(b_cancel)

	var b_save := CafeSocialTheme.make_button("ذخیره تغییرات", "emerald", Vector2(0, 56), 21, CafeSocialTheme.ICO_CHECK)
	b_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_save.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.update_clan_settings({
			"description": inp_desc.text.strip_edges(),
			"join_type": jt_val[0]
		}, func(ok: bool, _c: int, _d: Variant):
			overlay.queue_free()
			if ok:
				host._show_toast("تنظیمات کلن بروزرسانی شد.")
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
	card.custom_minimum_size = Vector2(780, 0)
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

	vbox.add_child(CafeSocialTheme.make_title("ایجاد چالش دوستانه در کلن", 34, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(CafeSocialTheme.make_body("بازی مورد نظر را انتخاب کنید تا در چت کلن برای هم‌تیمی‌ها اعلام شود:", 21, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var games := [
		{"id": "Monopoly", "title": "مونوپولی"},
		{"id": "Ludo", "title": "منچ (لودو)"},
		{"id": "Chess", "title": "شطرنج"},
		{"id": "BackGammon", "title": "تخته نرد"},
		{"id": "Coup", "title": "کودتا"},
		{"id": "Uno", "title": "اونو"},
	]
	for g in games:
		var gid: String = g["id"]
		var b := CafeSocialTheme.make_button(g["title"], "bronze", Vector2(0, 62), 23, CafeSocialTheme.get_game_thumb(gid))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			AudioManager.sfx_button()
			NetworkManager.api.create_clan_friendly_challenge(gid, 2, func(ok: bool, _c: int, _d: Variant):
				overlay.queue_free()
				if ok:
					host._show_toast("چالش دوستانه «%s» در چت کلن اعلام شد!" % g["title"])
					host.current_clans_subtab = "chat"
					host._refresh_current_tab()
			)
		)
		grid.add_child(b)

	var bc := CafeSocialTheme.make_button("انصراف", "muted", Vector2(200, 52), 21)
	bc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bc.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(bc)

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

	vbox.add_child(CafeSocialTheme.make_title("مدیریت عضو: %s" % m_name, 32, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))

	if my_role in ["leader", "co_leader"]:
		if m_role == "member":
			var b_p1 := CafeSocialTheme.make_button("ارتقا به ارشد (Elder)", "sapphire", Vector2(0, 56), 22)
			b_p1.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, "elder", func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه %s به ارشد ارتقا یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_p1)
		elif m_role == "elder" and my_role == "leader":
			var b_p2 := CafeSocialTheme.make_button("ارتقا به قائم‌مقام رهبر", "sapphire", Vector2(0, 56), 22)
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
			var b_dem := CafeSocialTheme.make_button("تنزل درجه", "bronze", Vector2(0, 56), 22)
			b_dem.pressed.connect(func():
				NetworkManager.api.change_clan_member_role(m_uid, target_r, func(_ok, _c, _d):
					overlay.queue_free()
					host._show_toast("درجه %s تغییر یافت." % m_name)
					host._refresh_current_tab()
				)
			)
			vbox.add_child(b_dem)

	if my_role == "leader":
		var b_lead := CafeSocialTheme.make_button("انتقال رهبری کلن به این عضو", "gold", Vector2(0, 56), 22, CafeSocialTheme.ICO_KING)
		b_lead.pressed.connect(func():
			overlay.queue_free()
			CafeSocialTheme.show_confirm_modal(
				host, "انتقال رهبری کلن",
				"آیا مطمئن هستید می‌خواهید رهبری کلن را به «%s» واگذار کنید؟" % m_name,
				"انتقال رهبری", true,
				func():
					NetworkManager.api.transfer_clan_leadership(m_uid, func(_ok, _c, _d):
						host._show_toast("رهبری کلن به %s منتقل شد." % m_name)
						host._refresh_current_tab()
					)
			)
		)
		vbox.add_child(b_lead)

	var b_kick := CafeSocialTheme.make_button("اخراج از کلن", "crimson", Vector2(0, 56), 22)
	b_kick.pressed.connect(func():
		overlay.queue_free()
		CafeSocialTheme.show_confirm_modal(
			host, "اخراج عضو",
			"آیا می‌خواهید «%s» را از کلن اخراج کنید؟" % m_name,
			"اخراج شود", true,
			func():
				NetworkManager.api.kick_clan_member(m_uid, func(_ok, _c, _d):
					host._show_toast("«%s» از کلن اخراج شد." % m_name)
					host._refresh_current_tab()
				)
		)
	)
	vbox.add_child(b_kick)

	var b_close := CafeSocialTheme.make_button("بستن", "muted", Vector2(0, 52), 20)
	b_close.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(b_close)

	host.add_child(overlay)
	ActionVFXManager.animate_dialog_open(card, overlay, true)
