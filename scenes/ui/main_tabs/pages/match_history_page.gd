extends Control

## Cafe Fekr — Dedicated Game History Page (تاریخچه بازی‌ها)
## Moved out of UserTab and opened from top-right History icon button on PlayTab.
## Shares the Profile (user_bg) background via MainTabShell.

signal back_requested()

var active_history_view: String = "matches" # "matches" | "stats"
var _my_games_history_data: Dictionary = {}
var _body_vbox: VBoxContainer = null

var _font_hekayat: Font = preload("res://assets/fonts/hekayat.ttf")
var _font_vazir: Font = preload("res://assets/fonts/Vazir.ttf")


func _ready() -> void:
	_build_ui()
	GameManager.user_logged_in.connect(func(_u): refresh_all())
	GameManager.user_logged_out.connect(func(): refresh_all())
	refresh_all()


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 10)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(outer_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	outer_margin.add_child(root_vbox)

	# Top Bar: Back + Refresh on Left, Persian Title on Right
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_row)

	var btn_back: TextureButton = TextureButton.new()
	btn_back.name = "BtnBackHistory"
	btn_back.texture_normal = preload("res://assets/images/back.png")
	btn_back.custom_minimum_size = Vector2(58, 58)
	btn_back.ignore_texture_size = true
	btn_back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_back.focus_mode = Control.FOCUS_NONE
	btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_back.tooltip_text = "بازگشت"
	ActionVFXManager.apply_button_juice(btn_back, "tap_button")
	btn_back.pressed.connect(func():
		AudioManager.sfx_tap()
		back_requested.emit()
	)
	top_row.add_child(btn_back)

	var btn_refresh: TextureButton = TextureButton.new()
	btn_refresh.name = "BtnRefreshHistory"
	btn_refresh.texture_normal = CafeSocialTheme.ICO_REFRESH
	btn_refresh.custom_minimum_size = Vector2(58, 58)
	btn_refresh.ignore_texture_size = true
	btn_refresh.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_refresh.focus_mode = Control.FOCUS_NONE
	btn_refresh.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_refresh.tooltip_text = "بروزرسانی"
	ActionVFXManager.apply_button_juice(btn_refresh, "tap_button")
	btn_refresh.pressed.connect(func():
		AudioManager.sfx_tap()
		_my_games_history_data.clear()
		refresh_all()
	)
	top_row.add_child(btn_refresh)

	var title_lbl: Label = Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title_lbl.add_theme_constant_override("shadow_outline_size", 2)
	title_lbl.text = "تاریخچه بازی‌ها"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(title_lbl)

	# Scrollable Content Container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	_body_vbox = VBoxContainer.new()
	_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(_body_vbox)


func refresh_all() -> void:
	if not is_instance_valid(_body_vbox):
		return
	_my_games_history_data.clear()
	_render_history_section()


func _style_subnav_btn(btn: Button, is_act: bool, font_size: int = 21) -> void:
	CafeSocialTheme.style_parlor_tab_button(btn, is_act, font_size)


func _render_history_section() -> void:
	for c in _body_vbox.get_children():
		c.queue_free()

	# Section toggle switcher: [مسابقات اخیر] | [آمار کلی]
	var seg_box: HBoxContainer = HBoxContainer.new()
	seg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_box.custom_minimum_size = Vector2(0, 56)
	seg_box.add_theme_constant_override("separation", 10)
	_body_vbox.add_child(seg_box)

	var btn_seg_matches: Button = Button.new()
	btn_seg_matches.text = "مسابقات اخیر"
	btn_seg_matches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seg_matches.custom_minimum_size = Vector2(0, 52)
	btn_seg_matches.focus_mode = Control.FOCUS_NONE
	btn_seg_matches.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_seg_matches, "tap_button")
	_style_subnav_btn(btn_seg_matches, active_history_view == "matches", 21)
	seg_box.add_child(btn_seg_matches)

	var btn_seg_stats: Button = Button.new()
	btn_seg_stats.text = "آمار کلی"
	btn_seg_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seg_stats.custom_minimum_size = Vector2(0, 52)
	btn_seg_stats.focus_mode = Control.FOCUS_NONE
	btn_seg_stats.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_seg_stats, "tap_button")
	_style_subnav_btn(btn_seg_stats, active_history_view == "stats", 21)
	seg_box.add_child(btn_seg_stats)

	var dynamic_holder: VBoxContainer = VBoxContainer.new()
	dynamic_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dynamic_holder.add_theme_constant_override("separation", 14)
	_body_vbox.add_child(dynamic_holder)

	btn_seg_matches.pressed.connect(func():
		AudioManager.sfx_tap()
		active_history_view = "matches"
		_style_subnav_btn(btn_seg_matches, true, 21)
		_style_subnav_btn(btn_seg_stats, false, 21)
		_render_recent_matches(dynamic_holder)
	)

	btn_seg_stats.pressed.connect(func():
		AudioManager.sfx_tap()
		active_history_view = "stats"
		_style_subnav_btn(btn_seg_matches, false, 21)
		_style_subnav_btn(btn_seg_stats, true, 21)
		_render_stats_matrix(dynamic_holder)
	)

	if active_history_view == "matches":
		_render_recent_matches(dynamic_holder)
	else:
		_render_stats_matrix(dynamic_holder)


# ==============================================================================
# A. RECENT MATCHES
# ==============================================================================

func _render_recent_matches(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()

	holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت سوابق مسابقات اخیر..."))

	var my_uid: String = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))

	NetworkManager.api.get_my_game_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(holder):
			return
		for c in holder.get_children():
			c.queue_free()

		var matches_list: Array = []
		if ok and typeof(data) == TYPE_DICTIONARY:
			var res: Variant = data.get("result", [])
			if typeof(res) == TYPE_ARRAY:
				matches_list = res as Array
			elif typeof(res) == TYPE_DICTIONARY and res.has("games_history") and typeof(res["games_history"]) == TYPE_ARRAY:
				matches_list = res["games_history"] as Array

		_populate_matches_cards(holder, matches_list, my_uid)
	)


func _populate_matches_cards(holder: VBoxContainer, list: Array, my_uid: String) -> void:
	if list.is_empty():
		holder.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"سوابق مسابقات خالی است",
			"هنوز مسابقه‌ای در حساب کاربری شما ثبت نشده است."
		))
		return

	for game_data in list:
		if typeof(game_data) != TYPE_DICTIONARY:
			continue
		var card: Button = _create_authentic_summary_card(game_data as Dictionary, my_uid)
		holder.add_child(card)

	var matches_spacer: Control = Control.new()
	matches_spacer.custom_minimum_size = Vector2(0, 40)
	matches_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(matches_spacer)


func _is_single_round_match(game: Dictionary) -> bool:
	var users_info: Variant = game.get("users_info", [])
	if typeof(users_info) == TYPE_ARRAY and (users_info as Array).size() > 2:
		return true
	var rounds: Variant = game.get("rounds", [])
	var gtypes: Variant = game.get("game_types", [])
	var r_cnt: int = (rounds as Array).size() if typeof(rounds) == TYPE_ARRAY else 0
	var gt_cnt: int = (gtypes as Array).size() if typeof(gtypes) == TYPE_ARRAY else 0
	return r_cnt <= 1 and gt_cnt <= 1


func _extract_primary_game_type(game: Dictionary) -> String:
	var direct: String = str(game.get("game_type", game.get("game", game.get("game_name", "")))).strip_edges()
	if not direct.is_empty():
		return direct
	var gtypes: Variant = game.get("game_types", [])
	if typeof(gtypes) == TYPE_ARRAY and not (gtypes as Array).is_empty():
		var first_gt: String = str((gtypes as Array)[0]).strip_edges()
		if not first_gt.is_empty():
			return first_gt
	var rounds: Variant = game.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not (rounds as Array).is_empty() and typeof((rounds as Array)[0]) == TYPE_DICTIONARY:
		var r0: Dictionary = (rounds as Array)[0] as Dictionary
		var r_gt: String = str(r0.get("game_type", r0.get("game", ""))).strip_edges()
		if not r_gt.is_empty():
			return r_gt
	return ""


func _make_match_card_style(bg: Color, border: Color, stripe_w: int, shadow_col: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_right = stripe_w
	sb.set_corner_radius_all(16)
	sb.shadow_color = shadow_col
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _create_authentic_summary_card(game: Dictionary, my_uid: String) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 146)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var mode_raw: String = str(game.get("game_score_type", "Rank"))
	var my_res: String = str(game.get("my_result", ""))
	var winner_id: String = str(game.get("winner_id", game.get("winner", "")))
	if my_res.is_empty():
		if winner_id == my_uid and not my_uid.is_empty():
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"

	var card_bg: Color = Color(0.15, 0.11, 0.08, 0.95)
	var card_border: Color = Color(0.56, 0.44, 0.30, 0.88)
	var card_shadow: Color = Color(0.0, 0.0, 0.0, 0.36)
	var stripe_w: int = 4
	if my_res == "win":
		card_bg = Color(0.09, 0.21, 0.13, 0.96)
		card_border = Color(0.27, 0.78, 0.44, 0.94)
		card_shadow = Color(0.08, 0.35, 0.16, 0.36)
		stripe_w = 6
	elif my_res == "lose":
		card_bg = Color(0.24, 0.09, 0.10, 0.96)
		card_border = Color(0.86, 0.34, 0.34, 0.92)
		card_shadow = Color(0.38, 0.08, 0.08, 0.36)
		stripe_w = 6
	elif my_res == "draw":
		card_bg = Color(0.21, 0.16, 0.07, 0.96)
		card_border = Color(0.90, 0.72, 0.30, 0.90)
		card_shadow = Color(0.30, 0.22, 0.06, 0.34)
		stripe_w = 6

	var st_norm: StyleBoxFlat = _make_match_card_style(card_bg, card_border, stripe_w, card_shadow)
	var st_hover: StyleBoxFlat = _make_match_card_style(card_bg.lightened(0.07), card_border.lightened(0.12), stripe_w, card_shadow)
	var st_press: StyleBoxFlat = _make_match_card_style(card_bg.darkened(0.07), card_border, stripe_w, card_shadow)
	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("pressed", st_press)
	btn.add_theme_stylebox_override("focus", st_norm)

	var pad: MarginContainer = MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(pad)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(row)

	var opp_name: String = str(game.get("opponent_name", ""))
	var opp_avatar_id: int = int(game.get("opponent_image", 0))
	var opp_data: Dictionary = {}
	var users_info: Variant = game.get("users_info", [])
	if typeof(users_info) == TYPE_ARRAY:
		for u in (users_info as Array):
			if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
				if opp_name.is_empty():
					opp_name = str(u.get("username", u.get("name", "حریف")))
					opp_avatar_id = int(u.get("image", 0))
				opp_data = (u as Dictionary).duplicate(true)
				break
	if opp_name.is_empty():
		opp_name = "حریف"
		opp_data = {"user_id": "opp", "username": opp_name, "image": opp_avatar_id}
	var opp_frame_id: int = GameManager.get_player_frame_id(opp_data if not opp_data.is_empty() else game)

	var is_multi_card: bool = typeof(users_info) == TYPE_ARRAY and (users_info as Array).size() > 2
	var opp_col: VBoxContainer = VBoxContainer.new()
	opp_col.custom_minimum_size = Vector2(86, 108)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_col.add_theme_constant_override("separation", 4 if is_multi_card else 2)
	opp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_multi_card else Control.MOUSE_FILTER_PASS

	if is_multi_card:
		var fr_img: TextureRect = TextureRect.new()
		fr_img.custom_minimum_size = Vector2(68, 68)
		fr_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr_img.texture = preload("res://assets/images/frames/friends.png")
		opp_col.add_child(fr_img)
	else:
		var av_panel: PanelContainer = PanelContainer.new()
		av_panel.custom_minimum_size = Vector2(74, 74)
		av_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		av_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var av_img: TextureRect = TextureRect.new()
		av_img.custom_minimum_size = Vector2(68, 68)
		av_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var av_path: String = "res://assets/icons/Avatars/%d.png" % opp_avatar_id
		av_img.texture = load(av_path) if ResourceLoader.exists(av_path) else preload("res://assets/icons/Avatars/0.png")
		av_panel.add_child(av_img)
		CafeSocialTheme.apply_frame_to_container(av_panel, av_img, opp_frame_id)

		av_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(opp_data, "", self)
		)
		opp_col.add_child(av_panel)

	var lbl_opp_name: Label = Label.new()
	lbl_opp_name.text = ("%s نفره" % GameManager.to_fa_num((users_info as Array).size())) if is_multi_card else opp_name
	lbl_opp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_opp_name.custom_minimum_size = Vector2(85, 0)
	lbl_opp_name.clip_text = true
	lbl_opp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_opp_name.add_theme_font_override("font", _font_hekayat)
	lbl_opp_name.add_theme_font_size_override("font_size", 20)
	lbl_opp_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lbl_opp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_col.add_child(lbl_opp_name)
	row.add_child(opp_col)

	var center_col: VBoxContainer = VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 6)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_mid: HBoxContainer = HBoxContainer.new()
	top_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top_mid.add_theme_constant_override("separation", 10)
	top_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var res_label_txt: String = "ناتمام"
	var res_txt_col: Color = Color(0.80, 0.78, 0.75, 1.0)
	var res_pill_bg: Color = Color(0.18, 0.14, 0.11, 0.94)
	var res_pill_bdr: Color = Color(0.55, 0.45, 0.35, 0.85)
	if my_res == "win":
		res_label_txt = "برد 🏆"
		res_txt_col = Color(0.55, 1.0, 0.66, 1.0)
		res_pill_bg = Color(0.11, 0.34, 0.18, 0.96)
		res_pill_bdr = Color(0.32, 0.86, 0.48, 0.96)
	elif my_res == "lose":
		res_label_txt = "باخت"
		res_txt_col = Color(1.0, 0.60, 0.60, 1.0)
		res_pill_bg = Color(0.38, 0.10, 0.11, 0.96)
		res_pill_bdr = Color(0.90, 0.38, 0.38, 0.94)
	elif my_res == "draw":
		res_label_txt = "مساوی"
		res_txt_col = Color(1.0, 0.92, 0.50, 1.0)
		res_pill_bg = Color(0.30, 0.22, 0.08, 0.96)
		res_pill_bdr = Color(0.92, 0.75, 0.32, 0.94)

	var res_pill: PanelContainer = CafeSocialTheme.make_badge_pill(res_label_txt, res_txt_col, res_pill_bg, res_pill_bdr, 23)
	res_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_mid.add_child(res_pill)

	var is_single_round: bool = _is_single_round_match(game)
	if not is_single_round:
		var scores: Variant = game.get("user_scores", [])
		var score_str: String = ""
		if typeof(scores) == TYPE_ARRAY and (scores as Array).size() >= 2:
			var sc_arr: Array = scores as Array
			var p1_uid: String = str(game.get("user1_id", ""))
			if p1_uid == my_uid:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(sc_arr[0])), GameManager.to_fa_num(int(sc_arr[1]))]
			else:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(sc_arr[1])), GameManager.to_fa_num(int(sc_arr[0]))]
		elif typeof(scores) == TYPE_ARRAY and not (scores as Array).is_empty():
			score_str = GameManager.to_fa_num(int((scores as Array)[0]))

		if not score_str.is_empty():
			var lbl_score: Label = Label.new()
			lbl_score.text = "( %s )" % score_str
			lbl_score.add_theme_font_override("font", _font_hekayat)
			lbl_score.add_theme_font_size_override("font_size", 24)
			lbl_score.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
			lbl_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_mid.add_child(lbl_score)
	center_col.add_child(top_mid)

	var s_date_raw: String = str(game.get("start_date", ""))
	var shamsi_date: String = _format_shamsi_date_ltr(s_date_raw)
	var lbl_date: Label = Label.new()
	lbl_date.text_direction = Control.TEXT_DIRECTION_RTL
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.text = shamsi_date
	lbl_date.add_theme_font_override("font", _font_hekayat)
	lbl_date.add_theme_font_size_override("font_size", 20)
	lbl_date.add_theme_color_override("font_color", Color(0.90, 0.84, 0.74))
	lbl_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_col.add_child(lbl_date)
	row.add_child(center_col)

	var primary_gtype: String = _extract_primary_game_type(game)
	var game_col: VBoxContainer = VBoxContainer.new()
	game_col.custom_minimum_size = Vector2(88, 108)
	game_col.alignment = BoxContainer.ALIGNMENT_CENTER
	game_col.add_theme_constant_override("separation", 4)
	game_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var g_icon_frame: PanelContainer = PanelContainer.new()
	g_icon_frame.custom_minimum_size = Vector2(72, 72)
	g_icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g_if_style: StyleBoxFlat = StyleBoxFlat.new()
	g_if_style.bg_color = Color(0.09, 0.05, 0.03, 0.96)
	g_if_style.border_color = card_border if (my_res == "win" or my_res == "lose") else CafeSocialTheme.COL_GOLD_ANTIQUE
	g_if_style.set_border_width_all(2)
	g_if_style.set_corner_radius_all(14)
	g_if_style.content_margin_left = 4.0
	g_if_style.content_margin_right = 4.0
	g_if_style.content_margin_top = 4.0
	g_if_style.content_margin_bottom = 4.0
	g_icon_frame.add_theme_stylebox_override("panel", g_if_style)

	var game_icon: TextureRect = TextureRect.new()
	game_icon.custom_minimum_size = Vector2(62, 62)
	game_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not primary_gtype.is_empty():
		game_icon.texture = _get_game_icon_texture(primary_gtype)
	else:
		game_icon.texture = _get_mode_badge_texture(mode_raw)
	g_icon_frame.add_child(game_icon)
	game_col.add_child(g_icon_frame)

	var lbl_game_tag: Label = Label.new()
	lbl_game_tag.text = _get_game_fa_name(primary_gtype) if not primary_gtype.is_empty() else _get_mode_fa_name(mode_raw)
	lbl_game_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_game_tag.custom_minimum_size = Vector2(88, 0)
	lbl_game_tag.clip_text = true
	lbl_game_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_game_tag.add_theme_font_override("font", _font_hekayat)
	lbl_game_tag.add_theme_font_size_override("font_size", 17)
	lbl_game_tag.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	lbl_game_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_col.add_child(lbl_game_tag)

	row.add_child(game_col)

	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		_show_game_details_dialog(game)
	)

	return btn


func _format_shamsi_date_ltr(iso_str: String) -> String:
	if iso_str.is_empty():
		return "اخیراً"
	var local_dt: Dictionary = GameManager.parse_server_iso_to_local(iso_str)
	if local_dt.is_empty():
		return iso_str
	var gy: int = int(local_dt["year"])
	var gm: int = int(local_dt["month"])
	var gd: int = int(local_dt["day"])
	var j: Dictionary = _gregorian_to_jalali(gy, gm, gd)
	var month_names: Array[String] = [
		"فروردین", "اردیبهشت", "خرداد",
		"تیر", "مرداد", "شهریور",
		"مهر", "آبان", "آذر",
		"دی", "بهمن", "اسفند"
	]
	var jm: int = int(j["month"])
	var m_name: String = month_names[jm - 1] if jm >= 1 and jm <= 12 else ""
	var hh: int = int(local_dt["hour"])
	var mm: int = int(local_dt["minute"])
	var time_formatted: String = "%02d:%02d" % [hh, mm]
	return "%s %s %s - ساعت %s" % [GameManager.to_fa_num(j["day"]), m_name, GameManager.to_fa_num(j["year"]), GameManager.to_fa_num(time_formatted)]


func _gregorian_to_jalali(gy: int, gm: int, gd: int) -> Dictionary:
	var g_d_m: Array[int] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var jy: int
	if gy > 1600:
		jy = 979
		gy -= 1600
	else:
		jy = 0
		gy -= 621
	var gy2: int = gy + 1 if gm > 2 else gy
	var days: int = 365 * gy + int((gy2 + 3) / 4) - int((gy2 + 99) / 100) + int((gy2 + 399) / 400) - 80 + gd + g_d_m[gm - 1]
	jy += 33 * int(days / 12053)
	days %= 12053
	jy += 4 * int(days / 1461)
	days %= 1461
	if days > 365:
		jy += int((days - 1) / 365)
		days = (days - 1) % 365
	var jm: int
	var jd: int
	if days < 186:
		jm = 1 + int(days / 31)
		jd = 1 + (days % 31)
	else:
		jm = 7 + int((days - 186) / 30)
		jd = 1 + ((days - 186) % 30)
	return {"year": jy, "month": jm, "day": jd}


func _get_mode_badge_texture(mode_raw: String) -> Texture2D:
	if mode_raw == "ClassicRank":
		return preload("res://assets/images/badges/classic-rank.png")
	elif mode_raw == "Lobby":
		return preload("res://assets/images/badges/lobby.png")
	elif mode_raw == "MultiRank":
		return preload("res://assets/images/badges/multi-rank.png")
	return preload("res://assets/images/badges/rank.png")


func _normalize_game_icon_slug(g_type: String) -> String:
	var norm: String = g_type.strip_edges().to_lower().replace("-", "").replace("_", "").replace(" ", "")
	match norm:
		"connect4", "connectfour", "دوزچهارتایی":
			return "fourinrow"
		"minesweeper", "مینیاب", "مینروب":
			return "msweeper"
		"memorynumbers", "کشفاعداد", "رازاعداد":
			return "mnumbers"
		"rps", "rockpaperscissors", "سنگکاغذقیچی":
			return "rpc"
		"dotsandboxes", "dotsboxes", "نقطهخط":
			return "dotbox"
		"riskstrike", "ریسک", "ریسکاسترایک":
			return "risk"
		"اونو":
			return "uno"
		"کودتا":
			return "coup"
		"پنتاگو":
			return "pentago"
		"شطرنج":
			return "chess"
		"تختهنرد":
			return "backgammon"
		"منچ":
			return "ludo"
		"مونوپولی", "منوپولی":
			return "monopoly"
		"دوز", "تیکتاکتو":
			return "tictactoe"
		"چکرز":
			return "checkers"
		"فکربکر":
			return "fekrbekr"
		"یاتزی":
			return "yatzy"
		"اتللو":
			return "othello"
		"آسیاب", "دوزنهتایی":
			return "mill"
		"یینش":
			return "yinsh"
		"کوریدور", "راهرو":
			return "quoridor"
		"نبردناوها", "نبردکشتی":
			return "battleship"
		"جعبهچهار", "چهارطرفه":
			return "boxfour"
		"سودوکو":
			return "sudoku"
		"کوییز":
			return "quiz"
		_:
			return norm


func _get_game_icon_texture(g_type: String) -> Texture2D:
	var norm: String = _normalize_game_icon_slug(g_type)
	var p_jpg: String = "res://assets/images/games/%s.jpg" % norm
	if ResourceLoader.exists(p_jpg):
		return load(p_jpg) as Texture2D
	var p_png: String = "res://assets/images/games/%s.png" % norm
	if ResourceLoader.exists(p_png):
		return load(p_png) as Texture2D
	var info: Dictionary = GameRegistry.get_game_info(g_type)
	var reg_icon: String = str(info.get("icon", ""))
	if not reg_icon.is_empty() and ResourceLoader.exists(reg_icon):
		return load(reg_icon) as Texture2D
	return preload("res://assets/images/games/rpc.jpg")


func _get_game_fa_name(g_type: String) -> String:
	var name_fa: String = GameRegistry.get_display_name_fa(g_type)
	if not name_fa.is_empty() and name_fa != "بازی" and name_fa != g_type:
		return name_fa
	var norm: String = g_type.strip_edges().to_lower().replace("-", "").replace("_", "")
	match norm:
		"rpc": return "سنگ کاغذ قیچی"
		"fekrbekr": return "فکر بکر"
		"yatzy": return "یاتزی"
		"tictactoe": return "دوز"
		"chess": return "شطرنج"
		"checkers": return "چکرز"
		"fourinrow", "connect4": return "دوز چهارتایی"
		"backgammon": return "تخته نرد"
		"othello": return "اتللو"
		"mill": return "آسیاب"
		"dotbox": return "نقطه خط"
		"pentago": return "پنتاگو"
		"yinsh": return "یینش"
		"quoridor": return "راهرو"
		"battleship": return "نبرد ناوها"
		"boxfour": return "جعبه چهار"
		"sudoku": return "سودوکو"
		"mnumbers": return "راز اعداد"
		"msweeper": return "مین روب"
		"ludo": return "منچ"
		"risk": return "ریسک"
		"uno": return "اونو"
		"quiz": return "کوییز"
		"coup": return "کودتا"
		"monopoly": return "مونوپولی"
		_: return "بازی فکری"


func _get_mode_fa_name(mode_raw: String) -> String:
	match mode_raw:
		"ClassicRank": return "رنک کلاسیک"
		"Lobby": return "لابی دوستانه"
		"MultiRank": return "رنک چندنفره"
		"Rank": return "مسابقه رنکینگ"
		_: return "مسابقه"


func _show_game_details_dialog(game: Dictionary) -> void:
	var modal: Control = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 60

	var bg_dim: ColorRect = ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.04, 0.02, 0.01, 0.85)
	modal.add_child(bg_dim)
	bg_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			modal.queue_free()
	)

	var outer: MarginContainer = MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 42)
	outer.add_theme_constant_override("margin_bottom", 42)
	modal.add_child(outer)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	outer.add_child(panel)

	var inner: MarginContainer = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 24)
	inner.add_theme_constant_override("margin_right", 24)
	inner.add_theme_constant_override("margin_top", 24)
	inner.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(inner)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	inner.add_child(root_vbox)

	var top_bar: PanelContainer = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 10.0, 8.0))
	root_vbox.add_child(top_bar)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_row)

	var btn_close: TextureButton = TextureButton.new()
	btn_close.name = "BtnCloseMatchDetails"
	btn_close.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_close.custom_minimum_size = Vector2(46, 46)
	btn_close.ignore_texture_size = true
	btn_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")
	btn_close.pressed.connect(func():
		AudioManager.sfx_tap()
		modal.queue_free()
	)
	top_row.add_child(btn_close)

	var lbl_title: Label = CafeSocialTheme.make_title("جزئیات مسابقه", 30, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lbl_title)

	var dummy_spacer: Control = Control.new()
	dummy_spacer.custom_minimum_size = Vector2(46, 46)
	top_row.add_child(dummy_spacer)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var dvbox: VBoxContainer = VBoxContainer.new()
	dvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_theme_constant_override("separation", 14)
	scroll.add_child(dvbox)

	var my_uid: String = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))
	var winner_id: String = str(game.get("winner_id", game.get("winner", "")))
	var my_res: String = str(game.get("my_result", ""))
	if my_res.is_empty():
		if winner_id == my_uid and not my_uid.is_empty():
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"

	var rounds: Array = game.get("rounds", []) if typeof(game.get("rounds")) == TYPE_ARRAY else []

	var main_game_type: String = str(game.get("game_type", ""))
	if main_game_type.is_empty() and game.has("game_types") and typeof(game["game_types"]) == TYPE_ARRAY and not (game["game_types"] as Array).is_empty():
		main_game_type = str((game["game_types"] as Array)[0])
	if main_game_type.is_empty() and not rounds.is_empty():
		main_game_type = str(rounds[0].get("game_type", ""))
	if main_game_type.is_empty():
		main_game_type = "rpc"

	var game_fa_title: String = _get_game_fa_name(main_game_type)
	var mode_raw: String = str(game.get("game_score_type", "Rank"))
	var mode_fa: String = _get_mode_fa_name(mode_raw)
	var s_date: String = _format_shamsi_date_ltr(str(game.get("start_date", "")))

	var hero_plaque: PanelContainer = PanelContainer.new()
	hero_plaque.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14, 1, 16.0, 14.0))
	dvbox.add_child(hero_plaque)

	var hv: VBoxContainer = VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 8)
	hero_plaque.add_child(hv)

	var icon_box: PanelContainer = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(96, 96)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ib_style: StyleBoxFlat = StyleBoxFlat.new()
	ib_style.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	ib_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	ib_style.set_border_width_all(3)
	ib_style.set_corner_radius_all(18)
	icon_box.add_theme_stylebox_override("panel", ib_style)
	hv.add_child(icon_box)

	var icon_img: TextureRect = TextureRect.new()
	icon_img.custom_minimum_size = Vector2(88, 88)
	icon_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_img.texture = _get_game_icon_texture(main_game_type)
	icon_box.add_child(icon_img)

	var game_name_banner: PanelContainer = PanelContainer.new()
	game_name_banner.custom_minimum_size = Vector2(280, 60)
	game_name_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(main_game_type, 48.0, 6.0))
	hv.add_child(game_name_banner)

	var lbl_game_name: Label = CafeSocialTheme.make_title(game_fa_title, 26, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false)
	game_name_banner.add_child(lbl_game_name)

	var tag_row: HBoxContainer = HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 8)
	hv.add_child(tag_row)

	tag_row.add_child(CafeSocialTheme.make_badge_pill(mode_fa, CafeSocialTheme.COL_GOLD_BRIGHT, CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_GOLD_ANTIQUE, 20))
	tag_row.add_child(CafeSocialTheme.make_badge_pill(s_date, CafeSocialTheme.COL_WARM_CREAM, Color(0.12, 0.09, 0.06, 0.9), CafeSocialTheme.COL_BRONZE_BORDER, 20))

	var outcome_card: PanelContainer = PanelContainer.new()
	outcome_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14, 1, 14.0, 12.0))
	dvbox.add_child(outcome_card)

	var ov: VBoxContainer = VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 10)
	outcome_card.add_child(ov)

	var res_text: String = ""
	var res_color: Color = CafeSocialTheme.COL_WARM_CREAM
	var res_bg: Color = Color(0.15, 0.12, 0.08, 0.95)
	var res_border: Color = CafeSocialTheme.COL_BRONZE_BORDER

	if my_res == "win":
		res_text = "پیروزی شما! 🏆"
		res_color = CafeSocialTheme.COL_EMERALD_TEXT
		res_bg = CafeSocialTheme.COL_EMERALD_BG
		res_border = CafeSocialTheme.COL_EMERALD_BORDER
	elif my_res == "lose":
		res_text = "شکست در این مسابقه"
		res_color = CafeSocialTheme.COL_CRIMSON_TEXT
		res_bg = Color(0.35, 0.08, 0.08, 0.95)
		res_border = Color(0.85, 0.35, 0.35, 1.0)
	elif my_res == "draw":
		res_text = "نتیجه مساوی"
		res_color = Color(1.0, 0.90, 0.40)
		res_bg = Color(0.24, 0.18, 0.08, 0.95)
		res_border = Color(0.80, 0.65, 0.35)
	else:
		res_text = "مسابقه ناتمام"
		res_color = Color(0.75, 0.75, 0.75)
		res_bg = Color(0.18, 0.15, 0.12, 0.95)
		res_border = Color(0.50, 0.45, 0.40)

	var res_badge: PanelContainer = CafeSocialTheme.make_badge_pill(res_text, res_color, res_bg, res_border, 24)
	res_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov.add_child(res_badge)

	var users_info: Array = game.get("users_info", []) if typeof(game.get("users_info")) == TYPE_ARRAY else []
	var is_multiplayer: bool = users_info.size() > 2
	var is_single_round: bool = _is_single_round_match(game)
	var winner_uid: String = str(game.get("winner_id", game.get("winner", "")))
	var winner_list: Array = game.get("winner_list", []) if typeof(game.get("winner_list")) == TYPE_ARRAY else []
	if winner_uid.is_empty() and not winner_list.is_empty():
		winner_uid = str(winner_list[0])
	var runner_up_uid: String = str(winner_list[1]) if winner_list.size() >= 2 else ""

	if is_multiplayer:
		var players_hdr: Label = CafeSocialTheme.make_title(
			"بازیکنان مسابقه (%s نفره)" % GameManager.to_fa_num(users_info.size()),
			24, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false
		)
		ov.add_child(players_hdr)

		var p_grid: GridContainer = GridContainer.new()
		p_grid.columns = 2
		p_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_grid.add_theme_constant_override("h_separation", 10)
		p_grid.add_theme_constant_override("v_separation", 10)
		ov.add_child(p_grid)

		for u in users_info:
			if typeof(u) != TYPE_DICTIONARY:
				continue
			var ud: Dictionary = u as Dictionary
			var u_uid: String = str(ud.get("user_id", ud.get("_id", "")))
			var u_name: String = str(ud.get("username", ud.get("name", "بازیکن")))
			var u_img: int = int(ud.get("image", 0))
			var u_fid: int = GameManager.get_player_frame_id(ud)
			var is_self_u: bool = (not my_uid.is_empty() and u_uid == my_uid)
			var is_winner_u: bool = (not winner_uid.is_empty() and winner_uid != "0" and u_uid == winner_uid)
			var is_runner_up: bool = (not is_winner_u and not runner_up_uid.is_empty() and u_uid == runner_up_uid)

			var p_card: PanelContainer = PanelContainer.new()
			p_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var p_bg: Color = Color(0.11, 0.25, 0.14, 0.96) if is_winner_u else CafeSocialTheme.COL_WALNUT_CARD
			var p_border: Color = CafeSocialTheme.COL_GOLD_BRIGHT if is_winner_u else (CafeSocialTheme.COL_GOLD_ANTIQUE if is_self_u else CafeSocialTheme.COL_BRONZE_BORDER)
			var p_bw: int = 3 if is_winner_u else 1
			p_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(p_bg, p_border, 14, p_bw, 10.0, 10.0))

			var pv: VBoxContainer = VBoxContainer.new()
			pv.alignment = BoxContainer.ALIGNMENT_CENTER
			pv.add_theme_constant_override("separation", 6)
			p_card.add_child(pv)

			var u_badge: Control = CafeSocialTheme.make_avatar_badge(u_img, u_fid, 66.0)
			u_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if not is_self_u:
				u_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var u_copy: Dictionary = ud.duplicate(true)
				u_badge.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed:
						AudioManager.sfx_tap()
						UserProfileDialog.show_user(u_copy, "", self)
				)
			pv.add_child(u_badge)

			var lbl_u: Label = Label.new()
			lbl_u.text = ("%s (شما)" % u_name) if is_self_u else u_name
			lbl_u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_u.clip_text = true
			lbl_u.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lbl_u.add_theme_font_override("font", _font_hekayat)
			lbl_u.add_theme_font_size_override("font_size", 21)
			lbl_u.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if (is_winner_u or is_self_u) else CafeSocialTheme.COL_IVORY)
			pv.add_child(lbl_u)

			if is_winner_u:
				var win_pill: PanelContainer = CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 18)
				win_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(win_pill)
			elif is_runner_up:
				var sec_pill: PanelContainer = CafeSocialTheme.make_badge_pill("🥈 نفر دوم", Color(0.88, 0.90, 0.95), Color(0.18, 0.16, 0.14, 0.95), Color(0.70, 0.72, 0.78), 16)
				sec_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(sec_pill)

			p_grid.add_child(p_card)
	else:
		var opp_name: String = str(game.get("opponent_name", ""))
		var opp_avatar_id: int = int(game.get("opponent_image", 0))
		var opp_data: Dictionary = {}
		for u in users_info:
			if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
				if opp_name.is_empty():
					opp_name = str(u.get("username", u.get("name", "حریف")))
					opp_avatar_id = int(u.get("image", 0))
				opp_data = (u as Dictionary).duplicate(true)
				break
		if opp_name.is_empty():
			opp_name = "حریف"
			opp_data = {"user_id": "opp", "username": opp_name, "image": opp_avatar_id}
		var opp_frame_id: int = GameManager.get_player_frame_id(opp_data if not opp_data.is_empty() else game)
		var opp_uid: String = str(opp_data.get("user_id", game.get("opponent_id", "")))

		var my_name: String = str(GameManager.user_data.get("name", GameManager.user_data.get("username", "شما")))
		var my_avatar_id: int = int(GameManager.user_data.get("image", 0))
		var my_frame_id: int = GameManager.get_player_frame_id(GameManager.user_data)

		var vs_row: HBoxContainer = HBoxContainer.new()
		vs_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vs_row.add_theme_constant_override("separation", 16)
		ov.add_child(vs_row)

		var opp_item: VBoxContainer = VBoxContainer.new()
		opp_item.alignment = BoxContainer.ALIGNMENT_CENTER
		opp_item.add_theme_constant_override("separation", 4)
		opp_item.mouse_filter = Control.MOUSE_FILTER_PASS

		var opp_badge: Control = CafeSocialTheme.make_avatar_badge(opp_avatar_id, opp_frame_id, 74.0)
		opp_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		opp_badge.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(opp_data, "", self)
		)
		opp_item.add_child(opp_badge)

		var lbl_opp: Label = Label.new()
		lbl_opp.text = opp_name
		lbl_opp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_opp.custom_minimum_size = Vector2(100, 0)
		lbl_opp.clip_text = true
		lbl_opp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_opp.add_theme_font_override("font", _font_hekayat)
		lbl_opp.add_theme_font_size_override("font_size", 22)
		lbl_opp.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		opp_item.add_child(lbl_opp)
		if my_res == "lose" or (not opp_uid.is_empty() and opp_uid == winner_uid):
			var ow_pill: PanelContainer = CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 16)
			ow_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			opp_item.add_child(ow_pill)
		vs_row.add_child(opp_item)

		var scores: Array = game.get("user_scores", []) if typeof(game.get("user_scores")) == TYPE_ARRAY else []
		var score_str: String = ""
		if not is_single_round:
			if scores.size() >= 2:
				var p1_uid: String = str(game.get("user1_id", ""))
				if p1_uid == my_uid:
					score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[1])), GameManager.to_fa_num(int(scores[0]))]
				else:
					score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[0])), GameManager.to_fa_num(int(scores[1]))]
			elif not scores.is_empty():
				score_str = GameManager.to_fa_num(int(scores[0]))

		var center_badge_col: VBoxContainer = VBoxContainer.new()
		center_badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
		center_badge_col.add_theme_constant_override("separation", 2)

		if not score_str.is_empty():
			var lbl_match_score: Label = Label.new()
			lbl_match_score.text = score_str
			lbl_match_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_match_score.add_theme_font_override("font", _font_hekayat)
			lbl_match_score.add_theme_font_size_override("font_size", 42)
			lbl_match_score.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
			center_badge_col.add_child(lbl_match_score)
		else:
			var lbl_vs: Label = Label.new()
			lbl_vs.text = "VS"
			lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_vs.add_theme_font_override("font", _font_hekayat)
			lbl_vs.add_theme_font_size_override("font_size", 32)
			lbl_vs.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_ANTIQUE)
			center_badge_col.add_child(lbl_vs)

		vs_row.add_child(center_badge_col)

		var my_item: VBoxContainer = VBoxContainer.new()
		my_item.alignment = BoxContainer.ALIGNMENT_CENTER
		my_item.add_theme_constant_override("separation", 4)

		var my_badge: Control = CafeSocialTheme.make_avatar_badge(my_avatar_id, my_frame_id, 74.0)
		my_item.add_child(my_badge)

		var lbl_my: Label = Label.new()
		lbl_my.text = my_name
		lbl_my.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_my.custom_minimum_size = Vector2(100, 0)
		lbl_my.clip_text = true
		lbl_my.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl_my.add_theme_font_override("font", _font_hekayat)
		lbl_my.add_theme_font_size_override("font_size", 22)
		lbl_my.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
		my_item.add_child(lbl_my)
		if my_res == "win":
			var mw_pill: PanelContainer = CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 16)
			mw_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			my_item.add_child(mw_pill)
		vs_row.add_child(my_item)

	var r_title: Label = Label.new()
	r_title.text = "جزئیات راندهای مسابقه"
	r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r_title.add_theme_font_override("font", _font_hekayat)
	r_title.add_theme_font_size_override("font_size", 28)
	r_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	dvbox.add_child(r_title)

	if rounds.is_empty():
		var single_round_card: PanelContainer = PanelContainer.new()
		single_round_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
		var srm: MarginContainer = MarginContainer.new()
		srm.add_theme_constant_override("margin_left", 16)
		srm.add_theme_constant_override("margin_right", 16)
		srm.add_theme_constant_override("margin_top", 12)
		srm.add_theme_constant_override("margin_bottom", 12)
		single_round_card.add_child(srm)

		var srh: HBoxContainer = HBoxContainer.new()
		srh.alignment = BoxContainer.ALIGNMENT_CENTER
		srh.add_theme_constant_override("separation", 12)
		srm.add_child(srh)

		srh.add_child(CafeSocialTheme.make_badge_pill(res_text, res_color, res_bg, res_border, 18))

		var mid_v: VBoxContainer = VBoxContainer.new()
		mid_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_v.alignment = BoxContainer.ALIGNMENT_CENTER
		var l_gname: Label = Label.new()
		l_gname.text = "راند تک‌دست • %s" % game_fa_title
		l_gname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l_gname.add_theme_font_override("font", _font_hekayat)
		l_gname.add_theme_font_size_override("font_size", 22)
		l_gname.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		mid_v.add_child(l_gname)
		srh.add_child(mid_v)

		var r_icon: TextureRect = TextureRect.new()
		r_icon.custom_minimum_size = Vector2(48, 48)
		r_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r_icon.texture = _get_game_icon_texture(main_game_type)
		srh.add_child(r_icon)

		dvbox.add_child(single_round_card)
	else:
		for i in range(rounds.size()):
			var r: Dictionary = rounds[i] as Dictionary
			var r_gtype: String = str(r.get("game_type", main_game_type))
			var r_gname: String = _get_game_fa_name(r_gtype)

			var r_card: PanelContainer = PanelContainer.new()
			r_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
			var rm: MarginContainer = MarginContainer.new()
			rm.add_theme_constant_override("margin_left", 16)
			rm.add_theme_constant_override("margin_right", 16)
			rm.add_theme_constant_override("margin_top", 10)
			rm.add_theme_constant_override("margin_bottom", 10)
			r_card.add_child(rm)

			var rh: HBoxContainer = HBoxContainer.new()
			rh.alignment = BoxContainer.ALIGNMENT_CENTER
			rh.add_theme_constant_override("separation", 12)
			rm.add_child(rh)

			var r_win_uid: String = str(r.get("winner_user_id", ""))
			var r_win_id: String = str(r.get("winner_id", ""))
			var r_status_txt: String = "مساوی"
			var r_st_color: Color = Color(1.0, 0.90, 0.40)
			var r_st_bg: Color = Color(0.24, 0.18, 0.08, 0.95)
			var r_st_border: Color = Color(0.80, 0.65, 0.35)

			var p1_uid: String = str(game.get("user1_id", ""))
			var is_p1: bool = (p1_uid == my_uid)

			if r_win_uid == my_uid or (r_win_uid.is_empty() and ((r_win_id == "1" and is_p1) or (r_win_id == "2" and not is_p1))):
				r_status_txt = "برد 🏆"
				r_st_color = CafeSocialTheme.COL_EMERALD_TEXT
				r_st_bg = CafeSocialTheme.COL_EMERALD_BG
				r_st_border = CafeSocialTheme.COL_EMERALD_BORDER
			elif not r_win_uid.is_empty() or (r_win_id in ["1", "2"]):
				r_status_txt = "باخت"
				r_st_color = CafeSocialTheme.COL_CRIMSON_TEXT
				r_st_bg = Color(0.35, 0.08, 0.08, 0.95)
				r_st_border = Color(0.85, 0.35, 0.35, 1.0)
			elif r_win_id == "0":
				r_status_txt = "مساوی"
				r_st_color = Color(1.0, 0.90, 0.40)
				r_st_bg = Color(0.24, 0.18, 0.08, 0.95)
				r_st_border = Color(0.80, 0.65, 0.35)

			rh.add_child(CafeSocialTheme.make_badge_pill(r_status_txt, r_st_color, r_st_bg, r_st_border, 18))

			var r_col: VBoxContainer = VBoxContainer.new()
			r_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_col.alignment = BoxContainer.ALIGNMENT_CENTER
			r_col.add_theme_constant_override("separation", 2)
			rh.add_child(r_col)

			var r_lbl: Label = Label.new()
			r_lbl.text = "راند %s  •  %s" % [GameManager.to_fa_num(i + 1), r_gname]
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r_lbl.add_theme_font_override("font", _font_hekayat)
			r_lbl.add_theme_font_size_override("font_size", 24)
			r_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
			r_col.add_child(r_lbl)

			var r_date_str: String = str(r.get("date", ""))
			if not r_date_str.is_empty():
				var r_sub: Label = Label.new()
				r_sub.text = _format_shamsi_date_ltr(r_date_str)
				r_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				r_sub.add_theme_font_override("font", _font_hekayat)
				r_sub.add_theme_font_size_override("font_size", 18)
				r_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
				r_col.add_child(r_sub)

			var r_icon_frame: PanelContainer = PanelContainer.new()
			r_icon_frame.custom_minimum_size = Vector2(52, 52)
			var r_if_style: StyleBoxFlat = StyleBoxFlat.new()
			r_if_style.bg_color = Color(0.10, 0.07, 0.03, 0.95)
			r_if_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
			r_if_style.set_border_width_all(2)
			r_if_style.set_corner_radius_all(10)
			r_icon_frame.add_theme_stylebox_override("panel", r_if_style)

			var r_icon: TextureRect = TextureRect.new()
			r_icon.custom_minimum_size = Vector2(46, 46)
			r_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_icon.texture = _get_game_icon_texture(r_gtype)
			r_icon_frame.add_child(r_icon)
			rh.add_child(r_icon_frame)

			dvbox.add_child(r_card)

	add_child(modal)


# ==============================================================================
# B. DOUBLE-SIZE STATISTICS MATRIX
# ==============================================================================

func _render_stats_matrix(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()

	if not _my_games_history_data.is_empty():
		_populate_double_stats_matrix(holder, _my_games_history_data)
		return

	holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت آمار تفصیلی..."))

	NetworkManager.api.get_my_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(holder):
			return
		for c in holder.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res: Variant = data["result"]
			_my_games_history_data = res as Dictionary if typeof(res) == TYPE_DICTIONARY else {}
			_populate_double_stats_matrix(holder, _my_games_history_data)
		else:
			holder.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت آمار بازی‌ها",
				"لطفاً ارتباط شبکه خود را بررسی فرمایید."
			))
	)


func _populate_double_stats_matrix(holder: VBoxContainer, hist: Dictionary) -> void:
	holder.add_child(CafeSocialTheme.make_ornate_section_header("کارنامه و آمار بازی‌های من", null))

	var w_rank: int = int(hist.get("win_rank", 0))
	var d_rank: int = int(hist.get("draw_rank", 0))
	var l_rank: int = int(hist.get("lose_rank", 0))

	var w_cr: int = int(hist.get("win_classic_rank", 0))
	var d_cr: int = int(hist.get("draw_classic_rank", 0))
	var l_cr: int = int(hist.get("lose_classic_rank", 0))

	var r1_mr: int = int(hist.get("rank1_multi_rank", 0))
	var r2_mr: int = int(hist.get("rank2_multi_rank", 0))
	var rn_mr: int = int(hist.get("rankn_multi_rank", 0))

	var total_wins: int = w_rank + w_cr + r1_mr
	var total_draws: int = d_rank + d_cr + r2_mr
	var total_losses: int = l_rank + l_cr + rn_mr
	var total_played: int = total_wins + total_draws + total_losses
	var win_rate: int = int(round((float(total_wins) / float(total_played)) * 100.0)) if total_played > 0 else 0

	# === 1. HERO CAREER SUMMARY CARD ===
	var hero_card: PanelContainer = PanelContainer.new()
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero_sb: StyleBoxFlat = StyleBoxFlat.new()
	hero_sb.bg_color = Color(0.16, 0.10, 0.06, 0.97)
	hero_sb.border_color = Color(0.86, 0.68, 0.30, 0.90)
	hero_sb.border_width_left = 1
	hero_sb.border_width_right = 1
	hero_sb.border_width_bottom = 1
	hero_sb.border_width_top = 2
	hero_sb.set_corner_radius_all(18)
	hero_sb.content_margin_left = 14.0
	hero_sb.content_margin_right = 14.0
	hero_sb.content_margin_top = 14.0
	hero_sb.content_margin_bottom = 14.0
	hero_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	hero_sb.shadow_size = 6
	hero_sb.shadow_offset = Vector2(0, 3)
	hero_card.add_theme_stylebox_override("panel", hero_sb)
	holder.add_child(hero_card)

	var hv: VBoxContainer = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero_card.add_child(hv)

	var wr_col: Color = CafeSocialTheme.COL_MUTED_SAND
	if total_played > 0:
		if win_rate >= 55:
			wr_col = CafeSocialTheme.COL_EMERALD_TEXT
		elif win_rate >= 35:
			wr_col = CafeSocialTheme.COL_GOLD_BRIGHT
		else:
			wr_col = CafeSocialTheme.COL_CRIMSON_TEXT

	# 3 Executive KPI Wells (RTL: Win Rate left, Wins center, Total Matches right)
	var kpi_row: HBoxContainer = HBoxContainer.new()
	kpi_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kpi_row.add_theme_constant_override("separation", 10)
	hv.add_child(kpi_row)

	kpi_row.add_child(_create_history_kpi_well("%s٪" % GameManager.to_fa_num(win_rate), "نرخ برد کل", wr_col))
	kpi_row.add_child(_create_history_kpi_well(GameManager.to_fa_num(total_wins), "کل پیروزی‌ها", CafeSocialTheme.COL_EMERALD_TEXT))
	kpi_row.add_child(_create_history_kpi_well(GameManager.to_fa_num(total_played), "کل مسابقات", CafeSocialTheme.COL_GOLD_BRIGHT))

	# Overall Proportional Segmented Distribution Bar
	var bar_track: PanelContainer = PanelContainer.new()
	bar_track.custom_minimum_size = Vector2(0, 12)
	bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_track.clip_contents = true
	var track_sb: StyleBoxFlat = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.07, 0.04, 0.02, 0.94)
	track_sb.border_color = Color(0.45, 0.34, 0.19, 0.65)
	track_sb.set_border_width_all(1)
	track_sb.set_corner_radius_all(6)
	track_sb.content_margin_left = 1.0
	track_sb.content_margin_right = 1.0
	track_sb.content_margin_top = 1.0
	track_sb.content_margin_bottom = 1.0
	bar_track.add_theme_stylebox_override("panel", track_sb)
	hv.add_child(bar_track)

	var seg_row: HBoxContainer = HBoxContainer.new()
	seg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seg_row.add_theme_constant_override("separation", 2)
	bar_track.add_child(seg_row)

	if total_played > 0:
		var seg_vals: Array[int] = [total_losses, total_draws, total_wins]
		var seg_cols: Array[Color] = [
			Color(0.86, 0.34, 0.34, 0.92),
			Color(0.94, 0.76, 0.28, 0.92),
			Color(0.30, 0.84, 0.48, 0.96)
		]
		for i in range(seg_vals.size()):
			if seg_vals[i] <= 0:
				continue
			var seg: Panel = Panel.new()
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_vertical = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = float(seg_vals[i])
			var seg_sb: StyleBoxFlat = StyleBoxFlat.new()
			seg_sb.bg_color = seg_cols[i]
			seg_sb.set_corner_radius_all(4)
			seg.add_theme_stylebox_override("panel", seg_sb)
			seg_row.add_child(seg)

	var legend: Label = Label.new()
	legend.text = "برد و مقام اول: %s  •  مساوی و دوم: %s  •  باخت و سایر: %s" % [
		GameManager.to_fa_num(total_wins),
		GameManager.to_fa_num(total_draws),
		GameManager.to_fa_num(total_losses)
	]
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_override("font", _font_vazir)
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	hv.add_child(legend)

	# === 2. MODE PERFORMANCE BREAKDOWN (SINGLE CLEAN SET, NO DUPLICATION) ===
	var m_spacer: Control = Control.new()
	m_spacer.custom_minimum_size = Vector2(0, 6)
	holder.add_child(m_spacer)

	holder.add_child(CafeSocialTheme.make_ornate_section_header("عملکرد به تفکیک حالت مسابقه", null))

	var card_rank: RankingCard = RankingCard.new()
	card_rank.setup_mode("رده‌بندی دو نفره", "رقابتی آنلاین", w_rank, d_rank, l_rank, null)
	holder.add_child(card_rank)

	var card_cr: RankingCard = RankingCard.new()
	card_cr.setup_mode("کلاسیک تک‌نفره", "هوش مصنوعی", w_cr, d_cr, l_cr, null)
	holder.add_child(card_cr)

	var card_mr: RankingCard = RankingCard.new()
	card_mr.setup_multiplayer("رده‌بندی چندنفره", "رقابت گروهی", r1_mr, r2_mr, rn_mr, null)
	holder.add_child(card_mr)

	# === 3. PER-GAME ANALYTICS WITH FILTER/SORT ===
	var g_spacer: Control = Control.new()
	g_spacer.custom_minimum_size = Vector2(0, 8)
	holder.add_child(g_spacer)

	GamesHistoryViewHelper.populate_games_history(holder, hist, false)

	var stats_spacer: Control = Control.new()
	stats_spacer.custom_minimum_size = Vector2(0, 40)
	stats_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stats_spacer)


func _create_history_kpi_well(val_txt: String, caption_txt: String, accent_col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.06, 0.03, 0.94)
	st.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(13)
	st.content_margin_left = 6.0
	st.content_margin_right = 6.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	p.add_theme_stylebox_override("panel", st)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)

	var lbl_v: Label = Label.new()
	lbl_v.text = val_txt
	lbl_v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_v.add_theme_font_override("font", _font_hekayat)
	lbl_v.add_theme_font_size_override("font_size", 28)
	lbl_v.add_theme_color_override("font_color", accent_col)
	vb.add_child(lbl_v)

	var lbl_c: Label = Label.new()
	lbl_c.text = caption_txt
	lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c.add_theme_font_override("font", _font_vazir)
	lbl_c.add_theme_font_size_override("font_size", 14)
	lbl_c.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	vb.add_child(lbl_c)
	return p
