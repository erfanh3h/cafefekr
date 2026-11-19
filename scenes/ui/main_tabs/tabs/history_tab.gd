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
@onready var your_rank_footer: PanelContainer = $OuterMargin/MainPanel/InnerMargin/VBox/YourRankFooter

var active_lb_tab: String = "score" # "score" | "win" | "friends" | "clans"
var active_section: String = "leaderboard" # compatibility

const _HEKAYAT_FONT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const _DEFAULT_AVATAR: Texture2D = preload("res://assets/icons/Avatars/0.png")

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
	CafeSocialTheme.style_parlor_tab_button(btn, is_act, 19)


func _create_compact_row_style(is_me: bool, state: String = "normal") -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = CafeSocialTheme.TEX_FRAME_SMALL
	sb.texture_margin_left = 44.0
	sb.texture_margin_right = 44.0
	sb.texture_margin_top = 14.0
	sb.texture_margin_bottom = 14.0
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	if state == "pressed":
		sb.modulate_color = Color(0.92, 0.87, 0.78, 1.0)
	elif state == "hover":
		sb.modulate_color = Color(1.14, 1.09, 0.98, 1.0) if not is_me else Color(1.18, 1.12, 0.92, 1.0)
	elif is_me:
		sb.modulate_color = Color(1.10, 1.04, 0.86, 1.0)
	return sb


func _load_leaderboard(lb_type: String) -> void:
	for c in lb_list_vbox.get_children():
		c.queue_free()
	lb_list_vbox.add_child(CafeSocialTheme.make_loading_state("در حال دریافت رتبه‌بندی..."))
	if lb_type == "clans":
		if is_instance_valid(your_rank_footer):
			your_rank_footer.visible = false
	else:
		if is_instance_valid(your_rank_footer):
			your_rank_footer.visible = true
	_update_your_rank_footer([], lb_type, {})

	var on_received := func(ok: bool, _c: int, data: Variant) -> void:
		if not is_instance_valid(lb_list_vbox):
			return
		if active_lb_tab != lb_type:
			return
		for c in lb_list_vbox.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			var resp_dict: Dictionary = data
			var list: Array = resp_dict["result"]
			_render_leaderboard_list(list, lb_type, resp_dict)
		else:
			_update_your_rank_footer([], lb_type, {})
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


func _render_leaderboard_list(list: Array, lb_type: String, extra_meta: Dictionary = {}) -> void:
	var my_uid: String = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", GameManager.get_user_id())))

	# Update sticky "Your Rank" footer using the full list (before self-exclusion in friends)
	_update_your_rank_footer(list, lb_type, extra_meta)

	# Filter out current user from friends tab (and filter test bots)
	var filtered_list: Array = []
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_dict: Dictionary = item
		var item_uid: String = str(item_dict.get("_id", item_dict.get("user_id", item_dict.get("id", ""))))
		if lb_type == "friends" and item_uid == my_uid and not my_uid.is_empty():
			continue
		if item_uid.begins_with("bot_") or item_uid.begins_with("test_bot"):
			continue
		filtered_list.append(item_dict)

	if filtered_list.is_empty():
		lb_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"اطلاعاتی یافت نشد",
			"رکوردی در این بخش وجود ندارد."
		))
		return

	var metric_icon_tex: Texture2D = CafeSocialTheme.ICO_CUP if lb_type == "win" else CafeSocialTheme.ICO_STAR

	var rank_idx: int = 0
	for i in range(filtered_list.size()):
		var raw_item: Dictionary = filtered_list[i]
		rank_idx += 1
		var rank: int = rank_idx

		var username: String = ""
		var clan_tag: String = ""
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
			var xp_val: int = int(raw_item.get("xp", 0))

			if raw_item.has("user_data") and typeof(raw_item["user_data"]) == TYPE_DICTIONARY:
				var ud: Dictionary = raw_item["user_data"]
				if username.is_empty():
					username = str(ud.get("username", ud.get("name", "بازیکن")))
				if img_id == 0:
					img_id = int(ud.get("image", ud.get("avatar", 0)))
				if score_val == 0:
					score_val = int(round(float(ud.get("score", 0))))
				if win_val == 0:
					win_val = int(round(float(ud.get("win", 0))))
				if xp_val == 0:
					xp_val = int(ud.get("xp", 0))
				if ud.has("level"):
					lvl_val = int(ud.get("level", 1))

			var frame_val: Variant = raw_item.get("profile_frame", raw_item.get("avatar_frame", 1))
			if raw_item.has("user_data") and typeof(raw_item["user_data"]) == TYPE_DICTIONARY:
				var ud2: Dictionary = raw_item["user_data"]
				if ud2.has("profile_frame") or ud2.has("avatar_frame"):
					frame_val = ud2.get("profile_frame", ud2.get("avatar_frame", frame_val))

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

		var is_me: bool = (item_uid == my_uid and not my_uid.is_empty() and lb_type != "clans")

		# --- Enhanced Scannable Outer Card (92px tall) ---
		var card: Button = Button.new()
		card.custom_minimum_size = Vector2(0, 92)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.flat = false
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(card, "tap_button")

		var style_normal: StyleBoxTexture = _create_compact_row_style(is_me, "normal")
		var style_hover: StyleBoxTexture = _create_compact_row_style(is_me, "hover")
		var style_pressed: StyleBoxTexture = _create_compact_row_style(is_me, "pressed")
		card.add_theme_stylebox_override("normal", style_normal)
		card.add_theme_stylebox_override("hover", style_hover)
		card.add_theme_stylebox_override("pressed", style_pressed)
		card.add_theme_stylebox_override("focus", style_normal)
		card.add_theme_stylebox_override("disabled", style_normal)

		# +20px inner left padding (56px vs 36px) so scores never collide with the left emerald diamond
		var pad: MarginContainer = MarginContainer.new()
		pad.set_anchors_preset(Control.PRESET_FULL_RECT)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_theme_constant_override("margin_left", 56)
		pad.add_theme_constant_override("margin_right", 34)
		pad.add_theme_constant_override("margin_top", 10)
		pad.add_theme_constant_override("margin_bottom", 10)
		card.add_child(pad)

		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		pad.add_child(row)

		# 1. Rank Badge (Far Right)
		var rank_frame: PanelContainer = _build_rank_badge(rank, is_me)

		# 2. Avatar / Clan Emblem Plaque (Immediately to the left of Rank)
		var av_frame: PanelContainer = PanelContainer.new()
		av_frame.custom_minimum_size = Vector2(52, 52)
		av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var avatar: TextureRect = TextureRect.new()
		avatar.custom_minimum_size = Vector2(44, 44)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_frame.add_child(avatar)

		if lb_type == "clans":
			av_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			avatar.texture = CafeSocialTheme.get_clan_emblem_texture(img_id)
		else:
			var av_path: String = "res://assets/icons/Avatars/%d.png" % img_id
			var av_tex: Texture2D = load(av_path) as Texture2D if ResourceLoader.exists(av_path) else _DEFAULT_AVATAR
			avatar.texture = av_tex if av_tex != null else _DEFAULT_AVATAR
			var u_fid: int = GameManager.get_player_frame_id(entry_dict if not entry_dict.is_empty() else raw_item)
			CafeSocialTheme.apply_frame_to_container(av_frame, avatar, u_fid)

		# 3. Name & Subtitle/Clan-Tag Column (Right-aligned RTL)
		var name_col: VBoxContainer = VBoxContainer.new()
		name_col.custom_minimum_size = Vector2(120, 0)
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_col.alignment = BoxContainer.ALIGNMENT_CENTER
		name_col.add_theme_constant_override("separation", 1)
		name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_lbl: Label = Label.new()
		name_lbl.text = username
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color("#FFF7E0") if not is_me else Color("#FFD86B"))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
		name_lbl.add_theme_constant_override("shadow_offset_y", 2)
		name_lbl.add_theme_constant_override("shadow_outline_size", 2)
		name_col.add_child(name_lbl)

		var sub_lbl: Label = Label.new()
		if lb_type == "clans":
			if not clan_tag.is_empty():
				if mem_cnt > 0:
					sub_lbl.text = "[%s] • %s عضو" % [clan_tag, GameManager.to_fa_num(int(mem_cnt))]
				else:
					sub_lbl.text = "[%s]" % clan_tag
			else:
				sub_lbl.text = "%s عضو" % GameManager.to_fa_num(int(mem_cnt))
			sub_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42, 0.95))
		else:
			sub_lbl.text = "سطح %s" % GameManager.to_fa_num(int(lvl_val))
			sub_lbl.add_theme_color_override("font_color", Color(0.86, 0.78, 0.62, 0.92))
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_lbl.clip_text = true
		sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
		sub_lbl.add_theme_font_size_override("font_size", 16)
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		sub_lbl.add_theme_constant_override("shadow_offset_y", 1)
		sub_lbl.add_theme_constant_override("shadow_outline_size", 1)
		name_col.add_child(sub_lbl)

		# 4. Score / Wins with Gold Trophy or Star Icon (Far Left, padded clear of diamond)
		var metric_val: int = win_val if lb_type == "win" else score_val
		var val_box: HBoxContainer = _build_metric_box(metric_val, metric_icon_tex)

		# Assembly in LTR order: [val_box (Left)] -> [name_col (Aligns Right)] -> [av_frame] -> [rank_frame (Right)]
		row.add_child(val_box)
		row.add_child(name_col)
		row.add_child(av_frame)
		row.add_child(rank_frame)

		# Row Click Handler
		if lb_type == "clans":
			var c_id: String = str(entry_dict.get("_id", entry_dict.get("clan_id", item_uid)))
			var captured_clan: Dictionary = entry_dict
			card.pressed.connect(func():
				AudioManager.sfx_tap()
				CafeSocialTheme.show_clan_details_modal(self, c_id, captured_clan)
			)
		else:
			var captured_entry: Dictionary = entry_dict
			card.pressed.connect(func():
				AudioManager.sfx_tap()
				user_profile_requested.emit(captured_entry)
				UserProfileDialog.show_user(captured_entry, "", self)
			)

		lb_list_vbox.add_child(card)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 10)
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_list_vbox.add_child(bottom_spacer)


func _build_rank_badge(rank: int, highlight: bool = false) -> PanelContainer:
	var rank_frame: PanelContainer = PanelContainer.new()
	rank_frame.custom_minimum_size = Vector2(44, 44)
	rank_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rank_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var rf_style: StyleBoxFlat = StyleBoxFlat.new()
	if rank == 1:
		rf_style.bg_color = Color(0.32, 0.22, 0.05, 0.94)
		rf_style.border_color = Color("#F5C542")
		rf_style.set_border_width_all(2)
	elif rank == 2:
		rf_style.bg_color = Color(0.20, 0.22, 0.25, 0.92)
		rf_style.border_color = Color(0.82, 0.86, 0.92, 0.88)
		rf_style.set_border_width_all(1)
	elif rank == 3:
		rf_style.bg_color = Color(0.26, 0.14, 0.07, 0.92)
		rf_style.border_color = Color(0.84, 0.54, 0.28, 0.88)
		rf_style.set_border_width_all(1)
	else:
		rf_style.bg_color = Color(0.11, 0.07, 0.04, 0.88)
		rf_style.border_color = Color("#F5C542") if highlight else Color(0.56, 0.41, 0.21, 0.65)
		rf_style.set_border_width_all(1)
	rf_style.set_corner_radius_all(10)
	rank_frame.add_theme_stylebox_override("panel", rf_style)

	var rank_lbl: Label = Label.new()
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	rank_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	rank_lbl.add_theme_constant_override("shadow_outline_size", 2)

	if rank == 1:
		rank_lbl.text = "🥇"
		rank_lbl.add_theme_font_size_override("font_size", 24)
	elif rank == 2:
		rank_lbl.text = "🥈"
		rank_lbl.add_theme_font_size_override("font_size", 24)
	elif rank == 3:
		rank_lbl.text = "🥉"
		rank_lbl.add_theme_font_size_override("font_size", 24)
	elif rank > 0:
		rank_lbl.text = GameManager.to_fa_num(int(rank))
		rank_lbl.add_theme_font_size_override("font_size", 21)
		rank_lbl.add_theme_color_override("font_color", Color("#FFD86B") if highlight else Color("#EFE2CB"))
	else:
		rank_lbl.text = "—"
		rank_lbl.add_theme_font_size_override("font_size", 20)
		rank_lbl.add_theme_color_override("font_color", Color("#CBB89D"))

	rank_frame.add_child(rank_lbl)
	return rank_frame


func _build_metric_box(metric_val: int, icon_tex: Texture2D, show_dash: bool = false) -> HBoxContainer:
	var val_box: HBoxContainer = HBoxContainer.new()
	val_box.alignment = BoxContainer.ALIGNMENT_CENTER
	val_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_box.add_theme_constant_override("separation", 6)
	val_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ico: TextureRect = TextureRect.new()
	ico.texture = icon_tex
	ico.custom_minimum_size = Vector2(28, 28)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.modulate = Color(1.0, 0.84, 0.22, 1.0) # Golden tone for left icon
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	val_box.add_child(ico)

	var val_lbl: Label = Label.new()
	val_lbl.text = "—" if show_dash else GameManager.to_fa_num(int(metric_val))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	val_lbl.add_theme_font_size_override("font_size", 25)
	val_lbl.add_theme_color_override("font_color", Color("#FFD86B"))
	val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	val_lbl.add_theme_constant_override("shadow_offset_y", 2)
	val_lbl.add_theme_constant_override("shadow_outline_size", 2)
	val_box.add_child(val_lbl)

	return val_box


func _update_your_rank_footer(raw_list: Array, lb_type: String, extra_meta: Dictionary = {}) -> void:
	if not is_instance_valid(your_rank_footer):
		return
	if lb_type == "clans":
		your_rank_footer.visible = false
		for c in your_rank_footer.get_children():
			c.queue_free()
		return
	your_rank_footer.visible = true
	for c in your_rank_footer.get_children():
		c.queue_free()

	var my_uid: String = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", GameManager.get_user_id())))
	var my_name: String = GameManager.get_username()
	if my_name.is_empty():
		my_name = str(GameManager.user_data.get("username", GameManager.user_data.get("name", "شما")))
	var my_avatar_id: int = GameManager.get_avatar_id()
	var my_frame_id: int = GameManager.get_frame_id()
	var my_level: int = GameManager.get_user_level()
	var my_score: int = GameManager.get_score()
	var my_wins: int = int(round(float(GameManager.user_data.get("win", 0))))
	var my_clan_id: String = str(GameManager.user_data.get("clan_id", ""))
	if my_clan_id.is_empty() and GameManager.user_data.has("clan") and typeof(GameManager.user_data["clan"]) == TYPE_DICTIONARY:
		var cd: Dictionary = GameManager.user_data["clan"]
		my_clan_id = str(cd.get("_id", cd.get("id", cd.get("clan_id", ""))))

	var found_rank: int = 0
	var display_name: String = my_name
	var display_sub: String = "سطح %s" % GameManager.to_fa_num(my_level)
	var display_val: int = my_wins if lb_type == "win" else my_score
	var show_dash_val: bool = false
	var is_clan_entry: bool = false
	var clan_emblem_id: int = 1
	var matched_clan_dict: Dictionary = {}

	# Check optional rank metadata returned by server
	if extra_meta.has("my_rank") and int(extra_meta["my_rank"]) > 0:
		found_rank = int(extra_meta["my_rank"])
	elif extra_meta.has("user_rank") and int(extra_meta["user_rank"]) > 0:
		found_rank = int(extra_meta["user_rank"])

	if lb_type == "clans":
		is_clan_entry = true
		var valid_idx: int = 0
		for item in raw_list:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = item
			var cid: String = str(d.get("_id", d.get("clan_id", d.get("id", ""))))
			if cid.begins_with("bot_") or cid.begins_with("test_bot"):
				continue
			valid_idx += 1
			if not my_clan_id.is_empty() and cid == my_clan_id:
				found_rank = valid_idx
				display_name = str(d.get("name", "اتحاد شما"))
				var ctag: String = str(d.get("tag", ""))
				var mem_cnt: int = int(d.get("member_count", d.get("members_count", 1)))
				display_sub = ("[%s] • %s عضو" % [ctag, GameManager.to_fa_num(mem_cnt)]) if not ctag.is_empty() else ("%s عضو" % GameManager.to_fa_num(mem_cnt))
				display_val = int(round(float(d.get("clan_score", d.get("score", 0)))))
				clan_emblem_id = int(d.get("emblem_id", d.get("emblem", d.get("badge", 1))))
				matched_clan_dict = d.duplicate(true)
				break
		if matched_clan_dict.is_empty():
			if my_clan_id.is_empty():
				display_name = "عضو اتحادی نیستید"
				display_sub = "برای رقابت به یک اتحاد بپیوندید"
				show_dash_val = true
			else:
				display_name = str(GameManager.user_data.get("clan_name", "اتحاد شما"))
				display_sub = "خارج از فهرست برتر"
				show_dash_val = true
	else:
		var valid_idx: int = 0
		for item in raw_list:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = item
			var uid: String = str(d.get("_id", d.get("user_id", d.get("id", ""))))
			if uid.begins_with("bot_") or uid.begins_with("test_bot"):
				continue
			valid_idx += 1
			if not my_uid.is_empty() and uid == my_uid:
				found_rank = valid_idx
				if lb_type == "win":
					display_val = int(round(float(d.get("win", my_wins))))
				else:
					display_val = int(round(float(d.get("score", my_score))))
				break

	var click_btn: Button = Button.new()
	click_btn.flat = true
	click_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	click_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	your_rank_footer.add_child(click_btn)

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	click_btn.add_child(row)

	# Far Left: Gold Trophy / Star + Score
	var metric_icon_tex: Texture2D = CafeSocialTheme.ICO_CUP if lb_type == "win" else CafeSocialTheme.ICO_STAR
	var val_box: HBoxContainer = _build_metric_box(display_val, metric_icon_tex, show_dash_val)

	# Middle-Right: "رتبه شما" pill + username + level/subtitle
	var info_col: VBoxContainer = VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 2)
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.alignment = BoxContainer.ALIGNMENT_END
	top_line.add_theme_constant_override("separation", 8)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl: Label = Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	name_lbl.add_theme_font_size_override("font_size", 21)
	name_lbl.add_theme_color_override("font_color", Color("#FFF7E0"))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	top_line.add_child(name_lbl)

	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_sb: StyleBoxFlat = StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.50, 0.31, 0.08, 0.96)
	pill_sb.border_color = Color("#F5C542")
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(8)
	pill_sb.content_margin_left = 8.0
	pill_sb.content_margin_right = 8.0
	pill_sb.content_margin_top = 1.0
	pill_sb.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override("panel", pill_sb)

	var pill_lbl: Label = Label.new()
	pill_lbl.text = "رتبه اتحاد شما" if is_clan_entry else "رتبه شما"
	pill_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	pill_lbl.add_theme_font_size_override("font_size", 14)
	pill_lbl.add_theme_color_override("font_color", Color("#FFF7E0"))
	pill.add_child(pill_lbl)
	top_line.add_child(pill)

	info_col.add_child(top_line)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = display_sub
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_lbl.add_theme_font_override("font", _HEKAYAT_FONT)
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color(0.84, 0.94, 0.86, 0.92))
	info_col.add_child(sub_lbl)

	# Right: Avatar / Clan Emblem
	var av_frame: PanelContainer = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(46, 46)
	av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var avatar: TextureRect = TextureRect.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av_frame.add_child(avatar)

	if is_clan_entry:
		av_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		avatar.texture = CafeSocialTheme.get_clan_emblem_texture(clan_emblem_id)
	else:
		var av_path: String = "res://assets/icons/Avatars/%d.png" % my_avatar_id
		var av_tex: Texture2D = load(av_path) as Texture2D if ResourceLoader.exists(av_path) else _DEFAULT_AVATAR
		avatar.texture = av_tex if av_tex != null else _DEFAULT_AVATAR
		CafeSocialTheme.apply_frame_to_container(av_frame, avatar, my_frame_id)

	# Far Right: Rank Badge
	var rank_badge: PanelContainer = _build_rank_badge(found_rank, true)

	row.add_child(val_box)
	row.add_child(info_col)
	row.add_child(av_frame)
	row.add_child(rank_badge)

	if is_clan_entry and not matched_clan_dict.is_empty():
		var c_id: String = str(matched_clan_dict.get("_id", matched_clan_dict.get("clan_id", my_clan_id)))
		var captured_clan: Dictionary = matched_clan_dict
		click_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			CafeSocialTheme.show_clan_details_modal(self, c_id, captured_clan)
		)
	elif not is_clan_entry:
		var my_entry: Dictionary = {
			"_id": my_uid,
			"user_id": my_uid,
			"username": my_name,
			"name": my_name,
			"image": my_avatar_id,
			"avatar": my_avatar_id,
			"score": my_score,
			"win": my_wins,
			"level": my_level,
			"xp": GameManager.get_xp(),
			"profile_frame": my_frame_id,
			"avatar_frame": my_frame_id,
		}
		click_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			user_profile_requested.emit(my_entry)
			UserProfileDialog.show_user(my_entry, "", self)
		)
