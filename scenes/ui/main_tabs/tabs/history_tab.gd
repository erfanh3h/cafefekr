extends Control

## Cafe Fekr — History Tab (دیوان برترین‌ها)
## Leaderboard across 4 categories:
## 1. امتیاز کل (Global Score)
## 2. بیشترین پیروزی (Total Wins)
## 3. دوستان (Friends Leaderboard - Self excluded)
## 4. اتحادها (Clans Leaderboard - Emblems and Clan details)

signal user_profile_requested(user_data: Dictionary)

@onready var btn_lb_score: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLbScore
@onready var btn_lb_win: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLbWin
@onready var btn_lb_friends: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLbFriends
@onready var btn_lb_clans: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLbClans
@onready var lb_list_vbox: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/LbListVBox

var active_lb_tab: String = "score" # "score" | "win" | "friends" | "clans"
var active_section: String = "leaderboard" # compatibility

var _SCORE_ICON = preload("res://assets/images/badges/score.png")
var _HEKAYAT_FONT = preload("res://assets/fonts/hekayat.ttf")

func _ready() -> void:
	ActionVFXManager.apply_button_juice(btn_lb_score, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lb_win, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lb_friends, "tap_button")
	ActionVFXManager.apply_button_juice(btn_lb_clans, "tap_button")

	btn_lb_score.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_lb_tab("score")
	)
	btn_lb_win.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_lb_tab("win")
	)
	btn_lb_friends.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_lb_tab("friends")
	)
	btn_lb_clans.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_lb_tab("clans")
	)

	switch_lb_tab("score")


func switch_section(_sec_name: String) -> void:
	# Backward compatibility stub
	switch_lb_tab(active_lb_tab)


func switch_lb_tab(t_name: String) -> void:
	active_lb_tab = t_name
	_style_lb_btn(btn_lb_score, t_name == "score")
	_style_lb_btn(btn_lb_win, t_name == "win")
	_style_lb_btn(btn_lb_friends, t_name == "friends")
	_style_lb_btn(btn_lb_clans, t_name == "clans")
	_load_leaderboard(t_name)


func _style_lb_btn(btn: Button, is_act: bool) -> void:
	if is_act:
		KenneyUI.style_button(btn, KenneyUI.COLOR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
	else:
		KenneyUI.style_button(btn, KenneyUI.COLOR_GREY)
		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))


func _load_leaderboard(lb_type: String) -> void:
	for c in lb_list_vbox.get_children():
		c.queue_free()
	lb_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت رتبه‌بندی..."))

	var on_received = func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(lb_list_vbox):
			return
		for c in lb_list_vbox.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var list: Array = data["result"]
			_render_leaderboard_list(list, lb_type)
		else:
			lb_list_vbox.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"رتبه‌بندی خالی است",
				"هنوز رکوردی در این بخش به ثبت نرسیده است."
			))

	match lb_type:
		"score":
			NetworkManager.api.get_ranking_by_score(on_received)
		"win":
			NetworkManager.api.get_ranking_by_win(on_received)
		"friends":
			NetworkManager.api.get_social_leaderboard("friends", "", "", on_received)
		"clans":
			NetworkManager.api.get_social_leaderboard("clans", "", "", on_received)


func _render_leaderboard_list(list: Array, lb_type: String) -> void:
	var my_uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))

	# Filter out current user from friends tab (and filter test bots)
	var filtered_list: Array = []
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_uid = str(item.get("_id", item.get("user_id", item.get("id", ""))))
		if lb_type == "friends" and item_uid == my_uid and not my_uid.is_empty():
			continue
		if item_uid.begins_with("bot_") or item_uid.begins_with("test_bot"):
			continue
		filtered_list.append(item)

	if filtered_list.is_empty():
		lb_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"اطلاعاتی یافت نشد",
			"رکوردی در این بخش وجود ندارد."
		))
		return

	var rank_idx = 0
	for i in range(filtered_list.size()):
		var raw_item: Dictionary = filtered_list[i]
		rank_idx += 1
		var rank = rank_idx

		var username: String = ""
		var subtitle_extra: String = ""
		var img_id: int = 0
		var score_val: int = 0
		var win_val: int = 0
		var lvl_val: int = 1
		var mem_cnt: int = 1
		var item_uid: String = str(raw_item.get("_id", raw_item.get("user_id", raw_item.get("id", ""))))
		var entry_dict: Dictionary = {}

		if lb_type == "clans":
			var cname = str(raw_item.get("name", "اتحاد"))
			var ctag = str(raw_item.get("tag", ""))
			username = cname if ctag.is_empty() else "%s  [%s]" % [cname, ctag]
			score_val = int(round(float(raw_item.get("clan_score", raw_item.get("score", 0)))))
			lvl_val = int(raw_item.get("clan_level", raw_item.get("level", 1)))
			mem_cnt = int(raw_item.get("member_count", raw_item.get("members_count", 1)))
			img_id = int(raw_item.get("emblem_id", raw_item.get("emblem", raw_item.get("badge", 1))))
			entry_dict = raw_item.duplicate(true)
		else:
			username = str(raw_item.get("username", raw_item.get("name", "")))
			img_id = int(raw_item.get("image", raw_item.get("avatar", 0)))
			score_val = int(round(float(raw_item.get("score", 0))))
			win_val = int(round(float(raw_item.get("win", 0))))
			var xp_val = int(raw_item.get("xp", 0))

			if raw_item.has("user_data") and typeof(raw_item["user_data"]) == TYPE_DICTIONARY:
				var ud: Dictionary = raw_item["user_data"]
				if username.is_empty():
					username = str(ud.get("username", ud.get("name", "بازیکن")))
				if img_id == 0:
					img_id = int(ud.get("image", ud.get("avatar", 0)))
				if score_val == 0:
					score_val = int(round(float(ud.get("score", 0))))
				if xp_val == 0:
					xp_val = int(ud.get("xp", 0))
				if ud.has("level"):
					lvl_val = int(ud.get("level", 1))

			if username.is_empty():
				username = "بازیکن"

			if xp_val > 0:
				lvl_val = GameManager.calculate_level(xp_val)
			elif raw_item.has("level"):
				lvl_val = int(raw_item.get("level", 1))

			entry_dict = {
				"_id": item_uid,
				"user_id": item_uid,
				"username": username,
				"name": username,
				"image": img_id,
				"avatar": img_id,
				"score": score_val,
				"win": win_val,
				"level": lvl_val,
				"xp": xp_val,
			}

		var is_me = (item_uid == my_uid and lb_type != "clans")

		# --- Outer Card ---
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 134)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(card, "tap_button")

		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(18)
		style_normal.shadow_size = 3
		style_normal.shadow_offset = Vector2(0, 2)

		if is_me:
			style_normal.bg_color = Color(0.24, 0.16, 0.08, 0.98)
			style_normal.border_color = Color(1.0, 0.85, 0.30, 1.0)
			style_normal.set_border_width_all(3)
			style_normal.shadow_color = Color(1.0, 0.82, 0.25, 0.35)
		elif rank == 1:
			style_normal.bg_color = Color(0.28, 0.18, 0.08, 0.96)
			style_normal.border_color = Color(1.0, 0.85, 0.25, 1.0)
			style_normal.set_border_width_all(3)
			style_normal.shadow_color = Color(1.0, 0.82, 0.2, 0.35)
		elif rank == 2:
			style_normal.bg_color = Color(0.20, 0.17, 0.15, 0.96)
			style_normal.border_color = Color(0.88, 0.92, 0.98, 0.95)
			style_normal.set_border_width_all(3)
			style_normal.shadow_color = Color(0.8, 0.88, 1.0, 0.25)
		elif rank == 3:
			style_normal.bg_color = Color(0.22, 0.16, 0.10, 0.96)
			style_normal.border_color = Color(0.90, 0.62, 0.38, 0.95)
			style_normal.set_border_width_all(3)
			style_normal.shadow_color = Color(0.85, 0.55, 0.30, 0.25)
		else:
			style_normal.bg_color = Color(0.14, 0.09, 0.06, 0.92)
			style_normal.border_color = Color(0.58, 0.45, 0.30, 0.82)
			style_normal.set_border_width_all(2)
			style_normal.shadow_color = Color(0, 0, 0, 0.5)

		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = Color(0.30, 0.20, 0.12, 0.98)
		style_hover.set_corner_radius_all(18)
		style_hover.set_border_width_all(3)
		style_hover.border_color = Color(1.0, 0.92, 0.5, 1.0)
		style_hover.shadow_color = Color(1.0, 0.85, 0.25, 0.4)
		style_hover.shadow_size = 4

		card.add_theme_stylebox_override("normal", style_normal)
		card.add_theme_stylebox_override("hover", style_hover)
		card.add_theme_stylebox_override("pressed", style_normal)
		card.add_theme_stylebox_override("focus", style_normal)

		var pad := MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_theme_constant_override("margin_left", 18)
		pad.add_theme_constant_override("margin_right", 18)
		pad.add_theme_constant_override("margin_top", 12)
		pad.add_theme_constant_override("margin_bottom", 12)
		card.add_child(pad)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		pad.add_child(row)

		# 1. Stat Value (Child 0: Far Left)
		var val_box := VBoxContainer.new()
		val_box.custom_minimum_size = Vector2(100, 0)
		val_box.add_theme_constant_override("separation", 2)
		val_box.alignment = BoxContainer.ALIGNMENT_CENTER
		val_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val_box)

		if lb_type == "win":
			var val_lbl := Label.new()
			val_lbl.text = GameManager.to_fa_num(int(win_val))
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			val_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
			val_lbl.add_theme_font_size_override("font_size", 42)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38, 1.0))
			val_box.add_child(val_lbl)

			var win_sub := Label.new()
			win_sub.text = "برد"
			win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			win_sub.add_theme_font_override("font", _HEKAYAT_FONT)
			win_sub.add_theme_font_size_override("font_size", 22)
			win_sub.add_theme_color_override("font_color", Color(0.55, 0.92, 0.64, 1.0))
			val_box.add_child(win_sub)
		else:
			var sc_icon := TextureRect.new()
			sc_icon.texture = _SCORE_ICON
			sc_icon.custom_minimum_size = Vector2(44, 46)
			sc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sc_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			sc_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			val_box.add_child(sc_icon)

			var val_lbl := Label.new()
			val_lbl.text = GameManager.to_fa_num(int(score_val))
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			val_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
			val_lbl.add_theme_font_size_override("font_size", 30)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))

			var sc_pill := StyleBoxFlat.new()
			sc_pill.bg_color = Color(0.10, 0.06, 0.03, 0.94)
			sc_pill.border_color = Color(0.85, 0.68, 0.28, 0.88)
			sc_pill.set_border_width_all(1)
			sc_pill.set_corner_radius_all(10)
			sc_pill.content_margin_left = 12
			sc_pill.content_margin_right = 12
			sc_pill.content_margin_top = 2
			sc_pill.content_margin_bottom = 2
			val_lbl.add_theme_stylebox_override("normal", sc_pill)
			val_box.add_child(val_lbl)

		# 2. Avatar / Clan Emblem Plaque (Child 1: To the left of text_col)
		var av_frame := PanelContainer.new()
		av_frame.custom_minimum_size = Vector2(88, 88)
		av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_frame.clip_contents = true

		var f_style := StyleBoxFlat.new()
		f_style.bg_color = Color(0.10, 0.07, 0.04, 0.94)
		f_style.set_corner_radius_all(12)
		f_style.set_border_width_all(2)
		f_style.border_color = Color(1.0, 0.82, 0.35, 0.85)
		av_frame.add_theme_stylebox_override("panel", f_style)

		var avatar := TextureRect.new()
		avatar.custom_minimum_size = Vector2(82, 82)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if lb_type == "clans":
			avatar.texture = CafeSocialTheme.get_clan_emblem_texture(img_id)
		else:
			var av_path: String = "res://assets/icons/Avatars/%d.png" % img_id
			avatar.texture = load(av_path) if ResourceLoader.exists(av_path) else preload("res://assets/icons/Avatars/0.png")
		av_frame.add_child(avatar)
		row.add_child(av_frame)

		# 3. Name & Subtitle Column (Child 2: situated to the RIGHT of Avatar)
		var text_col := VBoxContainer.new()
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_col.alignment = BoxContainer.ALIGNMENT_CENTER
		text_col.add_theme_constant_override("separation", 4)
		text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_col)

		var name_lbl := Label.new()
		name_lbl.text = username
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		name_lbl.add_theme_font_size_override("font_size", 32)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0) if not is_me else Color(1.0, 0.90, 0.35, 1.0))
		text_col.add_child(name_lbl)

		# Level row with BADGE_LEVEL icon instead of "سطح" word
		var sub_hbox := HBoxContainer.new()
		sub_hbox.alignment = BoxContainer.ALIGNMENT_END
		sub_hbox.add_theme_constant_override("separation", 6)
		sub_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(sub_hbox)

		if lb_type == "clans":
			var lbl_mem := Label.new()
			lbl_mem.text = "•  %s عضو" % GameManager.to_fa_num(int(mem_cnt))
			lbl_mem.add_theme_font_override("font", _HEKAYAT_FONT)
			lbl_mem.add_theme_font_size_override("font_size", 22)
			lbl_mem.add_theme_color_override("font_color", Color(0.82, 0.75, 0.64, 1.0))
			sub_hbox.add_child(lbl_mem)

		var lbl_lvl_num := Label.new()
		lbl_lvl_num.text = GameManager.to_fa_num(int(lvl_val))
		lbl_lvl_num.add_theme_font_override("font", _HEKAYAT_FONT)
		lbl_lvl_num.add_theme_font_size_override("font_size", 24)
		lbl_lvl_num.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50, 1.0))
		sub_hbox.add_child(lbl_lvl_num)

		var lvl_ico := TextureRect.new()
		lvl_ico.texture = CafeSocialTheme.BADGE_LEVEL
		lvl_ico.custom_minimum_size = Vector2(28, 28)
		lvl_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lvl_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lvl_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_hbox.add_child(lvl_ico)

		# 4. Rank Badge (Child 3: Far Right - Only icons for 1, 2, 3)
		var rank_frame := PanelContainer.new()
		rank_frame.custom_minimum_size = Vector2(68, 68)
		rank_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var rf_style := StyleBoxFlat.new()
		rf_style.bg_color = Color(0.10, 0.06, 0.03, 0.82)
		rf_style.set_corner_radius_all(14)
		rank_frame.add_theme_stylebox_override("panel", rf_style)

		var rank_lbl := Label.new()
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		rank_lbl.add_theme_font_size_override("font_size", 36)

		if rank == 1:
			rank_lbl.text = "🥇"
		elif rank == 2:
			rank_lbl.text = "🥈"
		elif rank == 3:
			rank_lbl.text = "🥉"
		else:
			rank_lbl.text = GameManager.to_fa_num(int(rank))
			rank_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))

		rank_frame.add_child(rank_lbl)
		row.add_child(rank_frame)

		# Row Click Handler
		if lb_type == "clans":
			var c_id = str(entry_dict.get("_id", entry_dict.get("clan_id", item_uid)))
			card.pressed.connect(func():
				AudioManager.sfx_tap()
				CafeSocialTheme.show_clan_details_modal(self, c_id, entry_dict)
			)
		else:
			card.pressed.connect(func():
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(entry_dict, "", self)
			)

		lb_list_vbox.add_child(card)
