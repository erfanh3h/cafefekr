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

func _ready() -> void:
	var lbl_title := get_node_or_null("OuterMargin/MainPanel/InnerMargin/VBox/TitleRow/LblTitle") as Label
	if is_instance_valid(lbl_title):
		lbl_title.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
		lbl_title.add_theme_font_size_override("font_size", CafeSocialTheme.FONT_SIZE_SCREEN_TITLE)
		CafeSocialTheme.apply_wood_text_shadow(lbl_title, 3)

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
		btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80, 0.92))
	CafeSocialTheme.configure_single_line_tab(btn, CafeSocialTheme.FONT_SIZE_TAB_COMPACT, 62.0, 6.0)


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
		var clan_tag: String = ""
		var subtitle_extra: String = ""
		var img_id: int = 0
		var score_val: int = 0
		var win_val: int = 0
		var lvl_val: int = 1
		var mem_cnt: int = 1
		var item_uid: String = str(raw_item.get("_id", raw_item.get("user_id", raw_item.get("id", ""))))
		var entry_dict: Dictionary = {}

		if lb_type == "clans":
			username = str(raw_item.get("name", "اتحاد"))
			clan_tag = str(raw_item.get("tag", ""))
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

			var frame_val = raw_item.get("profile_frame", raw_item.get("avatar_frame", 1))
			if raw_item.has("user_data") and typeof(raw_item["user_data"]) == TYPE_DICTIONARY:
				var ud: Dictionary = raw_item["user_data"]
				if ud.has("profile_frame") or ud.has("avatar_frame"):
					frame_val = ud.get("profile_frame", ud.get("avatar_frame", frame_val))

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
				"profile_frame": frame_val,
				"avatar_frame": frame_val,
			}

		var is_me = (item_uid == my_uid and lb_type != "clans")

		# --- Outer Card with frame_small ---
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 176)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.flat = false
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(card, "tap_button")

		var style_frame := CafeSocialTheme.create_frame_style(false, 54.0, 18.0)
		card.add_theme_stylebox_override("normal", style_frame)
		card.add_theme_stylebox_override("hover", style_frame)
		card.add_theme_stylebox_override("pressed", style_frame)
		card.add_theme_stylebox_override("focus", style_frame)
		card.add_theme_stylebox_override("disabled", style_frame)

		var pad := MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_theme_constant_override("margin_left", 36)
		pad.add_theme_constant_override("margin_right", 36)
		pad.add_theme_constant_override("margin_top", 14)
		pad.add_theme_constant_override("margin_bottom", 18)
		card.add_child(pad)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		pad.add_child(row)

		# 1. Number / Rank (Far Right)
		var rank_frame := PanelContainer.new()
		rank_frame.custom_minimum_size = Vector2(68, 68)
		rank_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var rf_style := StyleBoxFlat.new()
		rf_style.bg_color = Color(0.12, 0.08, 0.04, 0.88)
		rf_style.set_corner_radius_all(14)
		rank_frame.add_theme_stylebox_override("panel", rf_style)

		var rank_lbl := Label.new()
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
		rank_lbl.add_theme_font_size_override("font_size", 36)
		CafeSocialTheme.apply_wood_text_shadow(rank_lbl, 3)

		if rank == 1:
			rank_lbl.text = "🥇"
		elif rank == 2:
			rank_lbl.text = "🥈"
		elif rank == 3:
			rank_lbl.text = "🥉"
		else:
			rank_lbl.text = GameManager.to_fa_num(int(rank))
			rank_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))

		rank_frame.add_child(rank_lbl)

		# 2. Avatar / Clan Emblem Plaque (Immediately to the left of Rank)
		var av_frame := PanelContainer.new()
		av_frame.custom_minimum_size = Vector2(106, 106)
		av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var avatar := TextureRect.new()
		avatar.custom_minimum_size = Vector2(95, 95)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_frame.add_child(avatar)

		if lb_type == "clans":
			av_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			avatar.texture = CafeSocialTheme.get_clan_emblem_texture(img_id)
		else:
			var av_path: String = "res://assets/icons/Avatars/%d.png" % img_id
			avatar.texture = load(av_path) if ResourceLoader.exists(av_path) else preload("res://assets/icons/Avatars/0.png")
			var u_fid = GameManager.get_player_frame_id(entry_dict if not entry_dict.is_empty() else raw_item)
			CafeSocialTheme.apply_frame_to_container(av_frame, avatar, u_fid)

		# 3. Name & Subtitle/Clan-Tag Column (To the left of avatar, aligned to right of column)
		var name_col := VBoxContainer.new()
		name_col.custom_minimum_size = Vector2(180, 0)
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_col.alignment = BoxContainer.ALIGNMENT_CENTER
		name_col.add_theme_constant_override("separation", 2)
		name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_lbl := Label.new()
		name_lbl.text = username
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Mandatory GAME_SCENE_RULES.md guardrail: preserve clip_text = false + SIZE_EXPAND_FILL on leaderboard names
		name_lbl.clip_text = false
		name_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
		name_lbl.add_theme_font_size_override("font_size", CafeSocialTheme.FONT_SIZE_CARD_TITLE)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0) if not is_me else Color(1.0, 0.90, 0.35, 1.0))
		CafeSocialTheme.apply_wood_text_shadow(name_lbl, 3)
		name_col.add_child(name_lbl)

		if lb_type == "clans":
			var tag_lbl := Label.new()
			if not clan_tag.is_empty():
				if mem_cnt > 0:
					tag_lbl.text = "[%s]  •  %s عضو" % [clan_tag, GameManager.to_fa_num(int(mem_cnt))]
				else:
					tag_lbl.text = "[%s]" % clan_tag
			else:
				tag_lbl.text = "%s عضو" % GameManager.to_fa_num(int(mem_cnt))
			tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tag_lbl.clip_text = true
			tag_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tag_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_font())
			tag_lbl.add_theme_font_size_override("font_size", 24)
			tag_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42, 1.0))
			CafeSocialTheme.apply_wood_text_shadow(tag_lbl, 2)
			name_col.add_child(tag_lbl)
		else:
			var sub_lbl := Label.new()
			sub_lbl.text = "سطح %s" % GameManager.to_fa_num(int(lvl_val))
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sub_lbl.clip_text = true
			sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			sub_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_font())
			sub_lbl.add_theme_font_size_override("font_size", 24)
			sub_lbl.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 1.0))
			CafeSocialTheme.apply_wood_text_shadow(sub_lbl, 2)
			name_col.add_child(sub_lbl)

		# 4. Score or Wins count (Far Left)
		var val_box := HBoxContainer.new()
		val_box.alignment = BoxContainer.ALIGNMENT_CENTER
		val_box.add_theme_constant_override("separation", 6)
		val_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if lb_type == "win":
			var val_lbl := Label.new()
			val_lbl.text = GameManager.to_fa_num(int(win_val))
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
			val_lbl.add_theme_font_size_override("font_size", 38)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38, 1.0))
			CafeSocialTheme.apply_wood_text_shadow(val_lbl, 3)
			val_box.add_child(val_lbl)
		else:
			var val_lbl := Label.new()
			val_lbl.text = GameManager.to_fa_num(int(score_val))
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			val_lbl.add_theme_font_override("font", CafeSocialTheme.get_ui_bold_font())
			val_lbl.add_theme_font_size_override("font_size", 36)
			val_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
			CafeSocialTheme.apply_wood_text_shadow(val_lbl, 2)
			val_box.add_child(val_lbl)

		# Assembly in LTR order: [val_box (Left)] -> [name_col (Aligns Right)] -> [av_frame] -> [rank_frame (Right)]
		row.add_child(val_box)
		row.add_child(name_col)
		row.add_child(av_frame)
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

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 36)
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_list_vbox.add_child(bottom_spacer)
