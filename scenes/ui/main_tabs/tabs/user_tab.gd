extends Control

## Cafe Fekr — User Tab (Personal Player Palace)
## Sections:
## 1. History (تاریخچه: مسابقات اخیر با کارت‌های نوستالژیک و ماتریس دوبل آمار)
## 2. Cosmetics (ظاهر نمایه: گالری ۴ ستونه آواتارهای بزرگ با فاصله باز و ثبت در پایین)
## 3. Privacy & Audio (حریم خصوصی، تنظیمات صدا و موسیقی، نام کاربری و حساب)
## 4. Notifications (مرکز اعلان‌های اختصاصی)

signal change_username_requested()
signal phone_upgrade_requested()
signal logout_confirmed()
signal store_requested()
signal login_requested()
signal user_profile_requested(user_data: Dictionary)

@onready var user_header: MarginContainer = $OuterMargin/MainPanel/InnerMargin/VBox/UserHeader

@onready var subtab_profile: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnProfile
@onready var subtab_cosmetics: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnCosmetics
@onready var subtab_frames: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnFrames
@onready var subtab_privacy: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnPrivacy
@onready var subtab_notifs: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnNotifications

@onready var content_profile: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/ProfileContent
@onready var content_cosmetics: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/CosmeticsContent
@onready var content_frames: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/FramesContent
@onready var content_privacy: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/PrivacyContent
@onready var content_notifs: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/NotificationsContent

@onready var toast_panel: PanelContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel
@onready var lbl_toast: Label = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel/LblToast

var active_subtab: String = "profile"
var active_history_view: String = "matches" # "matches" | "stats"
var _selected_avatar_id: int = -1
var _selected_frame_id: int = 1
var _my_games_history_data: Dictionary = {}
var _my_recent_matches: Array = []

var _font_hekayat = preload("res://assets/fonts/hekayat.ttf")
var _font_vazir = preload("res://assets/fonts/Vazir.ttf")

func _ready() -> void:
	var subnav_bar = get_node_or_null("OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar") as PanelContainer
	if is_instance_valid(subnav_bar):
		subnav_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	ActionVFXManager.apply_button_juice(subtab_profile, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_cosmetics, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_frames, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_privacy, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_notifs, "tap_button")

	subtab_profile.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("profile")
	)
	subtab_cosmetics.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("cosmetics")
	)
	subtab_frames.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("frames")
	)
	subtab_privacy.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("privacy")
	)
	subtab_notifs.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("notifs")
	)

	if is_instance_valid(user_header):
		if user_header.has_signal("change_username_requested"):
			user_header.change_username_requested.connect(func(): change_username_requested.emit())
		if user_header.has_signal("login_requested"):
			user_header.login_requested.connect(func(): phone_upgrade_requested.emit())
		if user_header.has_signal("store_requested"):
			user_header.store_requested.connect(func(): store_requested.emit())

	GameManager.user_logged_in.connect(func(_u): refresh_all())
	GameManager.user_logged_out.connect(func(): refresh_all())
	if GameManager.has_signal("user_data_updated"):
		GameManager.user_data_updated.connect(func(_u): refresh_all())

	switch_subtab("profile")


func switch_subtab(tab_name: String) -> void:
	active_subtab = tab_name

	_style_subnav_btn(subtab_profile, tab_name == "profile")
	_style_subnav_btn(subtab_cosmetics, tab_name == "cosmetics")
	_style_subnav_btn(subtab_frames, tab_name == "frames")
	_style_subnav_btn(subtab_privacy, tab_name == "privacy")
	_style_subnav_btn(subtab_notifs, tab_name == "notifs")

	content_profile.visible = (tab_name == "profile")
	content_cosmetics.visible = (tab_name == "cosmetics")
	content_frames.visible = (tab_name == "frames")
	content_privacy.visible = (tab_name == "privacy")
	content_notifs.visible = (tab_name == "notifs")

	match tab_name:
		"profile":
			_render_profile()
		"cosmetics":
			_render_cosmetics()
		"frames":
			_render_frames()
		"privacy":
			_render_privacy()
		"notifs":
			_render_notifs()


func _style_subnav_btn(btn: Button, is_act: bool, font_size: int = 18) -> void:
	CafeSocialTheme.style_parlor_tab_button(btn, is_act, font_size)


func show_toast(msg: String, col: Color = CafeSocialTheme.COL_EMERALD_TEXT) -> void:
	if not is_instance_valid(lbl_toast) or not is_instance_valid(toast_panel):
		return
	lbl_toast.text = msg
	lbl_toast.add_theme_color_override("font_color", col)
	toast_panel.visible = true
	get_tree().create_timer(3.5).timeout.connect(func():
		if is_instance_valid(toast_panel):
			toast_panel.visible = false
	)


func _update_main_tab_buttons() -> void:
	pass


func _show_toast(msg: String, col: Color = CafeSocialTheme.COL_EMERALD_TEXT) -> void:
	show_toast(msg, col)


func _refresh_current_tab() -> void:
	refresh_all()


func refresh_all() -> void:
	if is_instance_valid(user_header) and user_header.has_method("update_ui"):
		user_header.update_ui()
	switch_subtab(active_subtab)


# ==============================================================================
# 1. PROFILE / HISTORY SECTION ("تاریخچه" - Recent Matches & Double-Size Stats Matrix)
# ==============================================================================

func _render_profile() -> void:
	for c in content_profile.get_children():
		c.queue_free()

	# Section toggle switcher: [مسابقات اخیر] | [آمار بازی‌ها]
	var seg_box := HBoxContainer.new()
	seg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_box.custom_minimum_size = Vector2(0, 56)
	seg_box.add_theme_constant_override("separation", 10)
	content_profile.add_child(seg_box)

	var btn_seg_matches := Button.new()
	btn_seg_matches.text = "مسابقات اخیر"
	btn_seg_matches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seg_matches.custom_minimum_size = Vector2(0, 52)
	btn_seg_matches.focus_mode = Control.FOCUS_NONE
	btn_seg_matches.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_seg_matches, "tap_button")
	_style_subnav_btn(btn_seg_matches, active_history_view == "matches", 21)
	seg_box.add_child(btn_seg_matches)

	var btn_seg_stats := Button.new()
	btn_seg_stats.text = "آمار کلی"
	btn_seg_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seg_stats.custom_minimum_size = Vector2(0, 52)
	btn_seg_stats.focus_mode = Control.FOCUS_NONE
	btn_seg_stats.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_seg_stats, "tap_button")
	_style_subnav_btn(btn_seg_stats, active_history_view == "stats", 21)
	seg_box.add_child(btn_seg_stats)

	var dynamic_holder := VBoxContainer.new()
	dynamic_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dynamic_holder.add_theme_constant_override("separation", 14)
	content_profile.add_child(dynamic_holder)

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


# --- A. Recent Matches (Authentic Old Visual Card & Details Dialog) ---

func _render_recent_matches(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()

	holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت سوابق مسابقات اخیر..."))

	var my_uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))

	NetworkManager.api.get_my_game_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(holder):
			return
		for c in holder.get_children():
			c.queue_free()

		var matches_list: Array = []
		if ok and typeof(data) == TYPE_DICTIONARY:
			var res = data.get("result", [])
			if typeof(res) == TYPE_ARRAY:
				matches_list = res
			elif typeof(res) == TYPE_DICTIONARY and res.has("games_history") and typeof(res["games_history"]) == TYPE_ARRAY:
				matches_list = res["games_history"]

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
		var card: Button = _create_authentic_summary_card(game_data, my_uid)
		holder.add_child(card)

	var matches_spacer := Control.new()
	matches_spacer.custom_minimum_size = Vector2(0, 40)
	matches_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(matches_spacer)


func _is_single_round_match(game: Dictionary) -> bool:
	var users_info: Variant = game.get("users_info", [])
	if typeof(users_info) == TYPE_ARRAY and users_info.size() > 2:
		return true
	var rounds: Variant = game.get("rounds", [])
	var gtypes: Variant = game.get("game_types", [])
	var r_cnt: int = rounds.size() if typeof(rounds) == TYPE_ARRAY else 0
	var gt_cnt: int = gtypes.size() if typeof(gtypes) == TYPE_ARRAY else 0
	return r_cnt <= 1 and gt_cnt <= 1


func _extract_primary_game_type(game: Dictionary) -> String:
	var direct: String = str(game.get("game_type", game.get("game", game.get("game_name", "")))).strip_edges()
	if not direct.is_empty():
		return direct
	var gtypes: Variant = game.get("game_types", [])
	if typeof(gtypes) == TYPE_ARRAY and not gtypes.is_empty():
		var first_gt: String = str(gtypes[0]).strip_edges()
		if not first_gt.is_empty():
			return first_gt
	var rounds: Variant = game.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not rounds.is_empty() and typeof(rounds[0]) == TYPE_DICTIONARY:
		var r0: Dictionary = rounds[0]
		var r_gt: String = str(r0.get("game_type", r0.get("game", ""))).strip_edges()
		if not r_gt.is_empty():
			return r_gt
	return ""


func _make_match_card_style(bg: Color, border: Color, stripe_w: int, shadow_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
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
	var btn := Button.new()
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

	# Outcome-tinted parlor wood card with emerald (Win) / crimson (Loss) accent bar
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

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(row)

	# Opponent Info
	var opp_name = str(game.get("opponent_name", ""))
	var opp_avatar_id = int(game.get("opponent_image", 0))
	var opp_data: Dictionary = {}
	var users_info = game.get("users_info", [])
	if typeof(users_info) == TYPE_ARRAY:
		for u in users_info:
			if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
				if opp_name.is_empty():
					opp_name = str(u.get("username", u.get("name", "حریف")))
					opp_avatar_id = int(u.get("image", 0))
				opp_data = u.duplicate(true)
				break
	if opp_name.is_empty():
		opp_name = "حریف"
		opp_data = {"user_id": "opp", "username": opp_name, "image": opp_avatar_id}
	var opp_frame_id: int = GameManager.get_player_frame_id(opp_data if not opp_data.is_empty() else game)

	# 1. LEFT SIDE: Friends icon for >2-player matches, or Opponent Avatar + Name for 2-player matches
	var is_multi_card: bool = typeof(users_info) == TYPE_ARRAY and users_info.size() > 2
	var opp_col := VBoxContainer.new()
	opp_col.custom_minimum_size = Vector2(86, 108)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_col.add_theme_constant_override("separation", 4 if is_multi_card else 2)
	opp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_multi_card else Control.MOUSE_FILTER_PASS

	if is_multi_card:
		var fr_img := TextureRect.new()
		fr_img.custom_minimum_size = Vector2(68, 68)
		fr_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr_img.texture = preload("res://assets/images/frames/friends.png")
		opp_col.add_child(fr_img)
	else:
		var av_panel := PanelContainer.new()
		av_panel.custom_minimum_size = Vector2(74, 74)
		av_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		av_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var av_img := TextureRect.new()
		av_img.custom_minimum_size = Vector2(68, 68)
		av_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var av_path = "res://assets/icons/Avatars/%d.png" % opp_avatar_id
		av_img.texture = load(av_path) if ResourceLoader.exists(av_path) else preload("res://assets/icons/Avatars/0.png")
		av_panel.add_child(av_img)
		CafeSocialTheme.apply_frame_to_container(av_panel, av_img, opp_frame_id)

		av_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(opp_data, "", self)
		)
		opp_col.add_child(av_panel)

	var lbl_opp_name := Label.new()
	lbl_opp_name.text = ("%s نفره" % GameManager.to_fa_num(users_info.size())) if is_multi_card else opp_name
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

	# 2. CENTER SECTION: Outcome, Integer Score, and Shamsi Date (LTR)
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 6)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_mid := HBoxContainer.new()
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

	# Integer score — omit for single-round & >2-player matches (only show برد/باخت)
	var is_single_round: bool = _is_single_round_match(game)
	if not is_single_round:
		var scores: Variant = game.get("user_scores", [])
		var score_str: String = ""
		if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:
			var p1_uid: String = str(game.get("user1_id", ""))
			if p1_uid == my_uid:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[0])), GameManager.to_fa_num(int(scores[1]))]
			else:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[1])), GameManager.to_fa_num(int(scores[0]))]
		elif typeof(scores) == TYPE_ARRAY and not scores.is_empty():
			score_str = GameManager.to_fa_num(int(scores[0]))

		if not score_str.is_empty():
			var lbl_score := Label.new()
			lbl_score.text = "( %s )" % score_str
			lbl_score.add_theme_font_override("font", _font_hekayat)
			lbl_score.add_theme_font_size_override("font_size", 24)
			lbl_score.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
			lbl_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_mid.add_child(lbl_score)
	center_col.add_child(top_mid)

	# Shamsi Full Date and Time
	var s_date_raw: String = str(game.get("start_date", ""))
	var shamsi_date: String = _format_shamsi_date_ltr(s_date_raw)
	var lbl_date := Label.new()
	lbl_date.text_direction = Control.TEXT_DIRECTION_RTL
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.text = shamsi_date
	lbl_date.add_theme_font_override("font", _font_hekayat)
	lbl_date.add_theme_font_size_override("font_size", 20)
	lbl_date.add_theme_color_override("font_color", Color(0.90, 0.84, 0.74))
	lbl_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_col.add_child(lbl_date)
	row.add_child(center_col)

	# 3. RIGHT SIDE: Game-Specific Framed Icon + Game Name
	var primary_gtype: String = _extract_primary_game_type(game)
	var game_col := VBoxContainer.new()
	game_col.custom_minimum_size = Vector2(88, 108)
	game_col.alignment = BoxContainer.ALIGNMENT_CENTER
	game_col.add_theme_constant_override("separation", 4)
	game_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var g_icon_frame := PanelContainer.new()
	g_icon_frame.custom_minimum_size = Vector2(72, 72)
	g_icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	g_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g_if_style := StyleBoxFlat.new()
	g_if_style.bg_color = Color(0.09, 0.05, 0.03, 0.96)
	g_if_style.border_color = card_border if (my_res == "win" or my_res == "lose") else CafeSocialTheme.COL_GOLD_ANTIQUE
	g_if_style.set_border_width_all(2)
	g_if_style.set_corner_radius_all(14)
	g_if_style.content_margin_left = 4.0
	g_if_style.content_margin_right = 4.0
	g_if_style.content_margin_top = 4.0
	g_if_style.content_margin_bottom = 4.0
	g_icon_frame.add_theme_stylebox_override("panel", g_if_style)

	var game_icon := TextureRect.new()
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

	var lbl_game_tag := Label.new()
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
	var local_dt := GameManager.parse_server_iso_to_local(iso_str)
	if local_dt.is_empty():
		return iso_str
	var gy := int(local_dt["year"])
	var gm := int(local_dt["month"])
	var gd := int(local_dt["day"])
	var j = _gregorian_to_jalali(gy, gm, gd)
	var month_names = [
		"فروردین", "اردیبهشت", "خرداد",
		"تیر", "مرداد", "شهریور",
		"مهر", "آبان", "آذر",
		"دی", "بهمن", "اسفند"
	]
	var m_name = month_names[j["month"] - 1] if j["month"] >= 1 and j["month"] <= 12 else ""
	var hh := int(local_dt["hour"])
	var mm := int(local_dt["minute"])
	var time_formatted = "%02d:%02d" % [hh, mm]
	return "%s %s %s - ساعت %s" % [GameManager.to_fa_num(j["day"]), m_name, GameManager.to_fa_num(j["year"]), GameManager.to_fa_num(time_formatted)]


func _gregorian_to_jalali(gy: int, gm: int, gd: int) -> Dictionary:
	var g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var jy: int
	if gy > 1600:
		jy = 979
		gy -= 1600
	else:
		jy = 0
		gy -= 621
	var gy2 = gy + 1 if gm > 2 else gy
	var days = 365 * gy + int((gy2 + 3) / 4) - int((gy2 + 99) / 100) + int((gy2 + 399) / 400) - 80 + gd + g_d_m[gm - 1]
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
	var name_fa = GameRegistry.get_display_name_fa(g_type)
	if not name_fa.is_empty() and name_fa != "بازی" and name_fa != g_type:
		return name_fa
	var norm = g_type.strip_edges().to_lower().replace("-", "").replace("_", "")
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
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 60

	# Dim background
	var bg_dim := ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0.04, 0.02, 0.01, 0.85)
	modal.add_child(bg_dim)
	bg_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			AudioManager.sfx_tap()
			modal.queue_free()
	)

	# Global Dialog Shell Frame (board.png)
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 20)
	outer.add_theme_constant_override("margin_right", 20)
	outer.add_theme_constant_override("margin_top", 42)
	outer.add_theme_constant_override("margin_bottom", 42)
	modal.add_child(outer)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_board_shell_style())
	outer.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 24)
	inner.add_theme_constant_override("margin_right", 24)
	inner.add_theme_constant_override("margin_top", 24)
	inner.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(inner)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	inner.add_child(root_vbox)

	# 1. Top Bar with Close Button at Top-Left and Centered Title
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", CafeSocialTheme.create_well_style(16, 10.0, 8.0))
	root_vbox.add_child(top_bar)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_row)

	var btn_close := TextureButton.new()
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

	var lbl_title := CafeSocialTheme.make_title("جزئیات مسابقه", 30, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(lbl_title)

	var dummy_spacer := Control.new()
	dummy_spacer.custom_minimum_size = Vector2(46, 46)
	top_row.add_child(dummy_spacer)

	# 2. Scrollable Body
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var dvbox := VBoxContainer.new()
	dvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_theme_constant_override("separation", 14)
	scroll.add_child(dvbox)

	# Match extraction
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
	if main_game_type.is_empty() and game.has("game_types") and typeof(game["game_types"]) == TYPE_ARRAY and not game["game_types"].is_empty():
		main_game_type = str(game["game_types"][0])
	if main_game_type.is_empty() and not rounds.is_empty():
		main_game_type = str(rounds[0].get("game_type", ""))
	if main_game_type.is_empty():
		main_game_type = "rpc"

	var game_fa_title = _get_game_fa_name(main_game_type)
	var mode_raw = str(game.get("game_score_type", "Rank"))
	var mode_fa = _get_mode_fa_name(mode_raw)
	var s_date = _format_shamsi_date_ltr(str(game.get("start_date", "")))

	# 3. Game Type Hero Plaque (shadow box matching rounds card instead of wood frame)
	var hero_plaque := PanelContainer.new()
	hero_plaque.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14, 1, 16.0, 14.0))
	dvbox.add_child(hero_plaque)

	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 8)
	hero_plaque.add_child(hv)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(96, 96)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ib_style := StyleBoxFlat.new()
	ib_style.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	ib_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	ib_style.set_border_width_all(3)
	ib_style.set_corner_radius_all(18)
	icon_box.add_theme_stylebox_override("panel", ib_style)
	hv.add_child(icon_box)

	var icon_img := TextureRect.new()
	icon_img.custom_minimum_size = Vector2(88, 88)
	icon_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_img.texture = _get_game_icon_texture(main_game_type)
	icon_box.add_child(icon_img)

	# Label of game type in Persian UNDER the icon inside difficulty ribbon frame
	var game_name_banner := PanelContainer.new()
	game_name_banner.custom_minimum_size = Vector2(280, 60)
	game_name_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(main_game_type, 48.0, 6.0))
	hv.add_child(game_name_banner)

	var lbl_game_name := CafeSocialTheme.make_title(game_fa_title, 26, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false)
	game_name_banner.add_child(lbl_game_name)

	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 8)
	hv.add_child(tag_row)

	tag_row.add_child(CafeSocialTheme.make_badge_pill(mode_fa, CafeSocialTheme.COL_GOLD_BRIGHT, CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_GOLD_ANTIQUE, 20))
	tag_row.add_child(CafeSocialTheme.make_badge_pill(s_date, CafeSocialTheme.COL_WARM_CREAM, Color(0.12, 0.09, 0.06, 0.9), CafeSocialTheme.COL_BRONZE_BORDER, 20))

	# 4. Match Outcome & Players Card (shadow box matching rounds card instead of wood frame)
	var outcome_card := PanelContainer.new()
	outcome_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14, 1, 14.0, 12.0))
	dvbox.add_child(outcome_card)

	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 10)
	outcome_card.add_child(ov)

	var res_text = ""
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

	var res_badge := CafeSocialTheme.make_badge_pill(res_text, res_color, res_bg, res_border, 24)
	res_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov.add_child(res_badge)

	# Players Matchup / Multiplayer Roster
	var users_info = game.get("users_info", []) if typeof(game.get("users_info")) == TYPE_ARRAY else []
	var is_multiplayer: bool = users_info.size() > 2
	var is_single_round: bool = _is_single_round_match(game)
	var winner_uid := str(game.get("winner_id", game.get("winner", "")))
	var winner_list: Array = game.get("winner_list", []) if typeof(game.get("winner_list")) == TYPE_ARRAY else []
	if winner_uid.is_empty() and not winner_list.is_empty():
		winner_uid = str(winner_list[0])
	var runner_up_uid := str(winner_list[1]) if winner_list.size() >= 2 else ""

	if is_multiplayer:
		var players_hdr := CafeSocialTheme.make_title(
			"بازیکنان مسابقه (%s نفره)" % GameManager.to_fa_num(users_info.size()),
			24, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER, false
		)
		ov.add_child(players_hdr)

		var p_grid := GridContainer.new()
		p_grid.columns = 2
		p_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_grid.add_theme_constant_override("h_separation", 10)
		p_grid.add_theme_constant_override("v_separation", 10)
		ov.add_child(p_grid)

		for u in users_info:
			if typeof(u) != TYPE_DICTIONARY:
				continue
			var u_uid := str(u.get("user_id", u.get("_id", "")))
			var u_name := str(u.get("username", u.get("name", "بازیکن")))
			var u_img := int(u.get("image", 0))
			var u_fid := GameManager.get_player_frame_id(u)
			var is_self_u := (not my_uid.is_empty() and u_uid == my_uid)
			var is_winner_u := (not winner_uid.is_empty() and winner_uid != "0" and u_uid == winner_uid)
			var is_runner_up := (not is_winner_u and not runner_up_uid.is_empty() and u_uid == runner_up_uid)

			var p_card := PanelContainer.new()
			p_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var p_bg := Color(0.11, 0.25, 0.14, 0.96) if is_winner_u else CafeSocialTheme.COL_WALNUT_CARD
			var p_border := CafeSocialTheme.COL_GOLD_BRIGHT if is_winner_u else (CafeSocialTheme.COL_GOLD_ANTIQUE if is_self_u else CafeSocialTheme.COL_BRONZE_BORDER)
			var p_bw := 3 if is_winner_u else 1
			p_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(p_bg, p_border, 14, p_bw, 10.0, 10.0))

			var pv := VBoxContainer.new()
			pv.alignment = BoxContainer.ALIGNMENT_CENTER
			pv.add_theme_constant_override("separation", 6)
			p_card.add_child(pv)

			var u_badge := CafeSocialTheme.make_avatar_badge(u_img, u_fid, 66.0)
			u_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if not is_self_u:
				u_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var u_copy: Dictionary = u.duplicate(true)
				u_badge.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed:
						AudioManager.sfx_tap()
						UserProfileDialog.show_user(u_copy, "", self)
				)
			pv.add_child(u_badge)

			var lbl_u := Label.new()
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
				var win_pill := CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 18)
				win_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(win_pill)
			elif is_runner_up:
				var sec_pill := CafeSocialTheme.make_badge_pill("🥈 نفر دوم", Color(0.88, 0.90, 0.95), Color(0.18, 0.16, 0.14, 0.95), Color(0.70, 0.72, 0.78), 16)
				sec_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(sec_pill)

			p_grid.add_child(p_card)
	else:
		# 2-Player Opponent & User matchup
		var opp_name = str(game.get("opponent_name", ""))
		var opp_avatar_id = int(game.get("opponent_image", 0))
		var opp_data: Dictionary = {}
		for u in users_info:
			if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
				if opp_name.is_empty():
					opp_name = str(u.get("username", u.get("name", "حریف")))
					opp_avatar_id = int(u.get("image", 0))
				opp_data = u.duplicate(true)
				break
		if opp_name.is_empty():
			opp_name = "حریف"
			opp_data = {"user_id": "opp", "username": opp_name, "image": opp_avatar_id}
		var opp_frame_id: int = GameManager.get_player_frame_id(opp_data if not opp_data.is_empty() else game)
		var opp_uid := str(opp_data.get("user_id", game.get("opponent_id", "")))

		var my_name = str(GameManager.user_data.get("name", GameManager.user_data.get("username", "شما")))
		var my_avatar_id = int(GameManager.user_data.get("image", 0))
		var my_frame_id = GameManager.get_player_frame_id(GameManager.user_data)

		var vs_row := HBoxContainer.new()
		vs_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vs_row.add_theme_constant_override("separation", 16)
		ov.add_child(vs_row)

		# Opponent (Left)
		var opp_item := VBoxContainer.new()
		opp_item.alignment = BoxContainer.ALIGNMENT_CENTER
		opp_item.add_theme_constant_override("separation", 4)
		opp_item.mouse_filter = Control.MOUSE_FILTER_PASS

		var opp_badge = CafeSocialTheme.make_avatar_badge(opp_avatar_id, opp_frame_id, 74.0)
		opp_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		opp_badge.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(opp_data, "", self)
		)
		opp_item.add_child(opp_badge)

		var lbl_opp := Label.new()
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
			var ow_pill := CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 16)
			ow_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			opp_item.add_child(ow_pill)
		vs_row.add_child(opp_item)

		# Center: Score (multi-round only) / VS (single-round)
		var scores = game.get("user_scores", []) if typeof(game.get("user_scores")) == TYPE_ARRAY else []
		var score_str = ""
		if not is_single_round:
			if scores.size() >= 2:
				var p1_uid = str(game.get("user1_id", ""))
				if p1_uid == my_uid:
					score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[1])), GameManager.to_fa_num(int(scores[0]))]
				else:
					score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[0])), GameManager.to_fa_num(int(scores[1]))]
			elif not scores.is_empty():
				score_str = GameManager.to_fa_num(int(scores[0]))

		var center_badge_col := VBoxContainer.new()
		center_badge_col.alignment = BoxContainer.ALIGNMENT_CENTER
		center_badge_col.add_theme_constant_override("separation", 2)

		if not score_str.is_empty():
			var lbl_match_score := Label.new()
			lbl_match_score.text = score_str
			lbl_match_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_match_score.add_theme_font_override("font", _font_hekayat)
			lbl_match_score.add_theme_font_size_override("font_size", 42)
			lbl_match_score.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
			center_badge_col.add_child(lbl_match_score)
		else:
			var lbl_vs := Label.new()
			lbl_vs.text = "VS"
			lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_vs.add_theme_font_override("font", _font_hekayat)
			lbl_vs.add_theme_font_size_override("font_size", 32)
			lbl_vs.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_ANTIQUE)
			center_badge_col.add_child(lbl_vs)

		vs_row.add_child(center_badge_col)

		# Player (Right)
		var my_item := VBoxContainer.new()
		my_item.alignment = BoxContainer.ALIGNMENT_CENTER
		my_item.add_theme_constant_override("separation", 4)

		var my_badge = CafeSocialTheme.make_avatar_badge(my_avatar_id, my_frame_id, 74.0)
		my_item.add_child(my_badge)

		var lbl_my := Label.new()
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
			var mw_pill := CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 16)
			mw_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			my_item.add_child(mw_pill)
		vs_row.add_child(my_item)

	# 5. Organized Rounds Breakdown
	var r_title := Label.new()
	r_title.text = "جزئیات راندهای مسابقه"
	r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r_title.add_theme_font_override("font", _font_hekayat)
	r_title.add_theme_font_size_override("font_size", 28)
	r_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	dvbox.add_child(r_title)

	if rounds.is_empty():
		var single_round_card := PanelContainer.new()
		single_round_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
		var srm := MarginContainer.new()
		srm.add_theme_constant_override("margin_left", 16)
		srm.add_theme_constant_override("margin_right", 16)
		srm.add_theme_constant_override("margin_top", 12)
		srm.add_theme_constant_override("margin_bottom", 12)
		single_round_card.add_child(srm)

		var srh := HBoxContainer.new()
		srh.alignment = BoxContainer.ALIGNMENT_CENTER
		srh.add_theme_constant_override("separation", 12)
		srm.add_child(srh)

		srh.add_child(CafeSocialTheme.make_badge_pill(res_text, res_color, res_bg, res_border, 18))

		var mid_v := VBoxContainer.new()
		mid_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid_v.alignment = BoxContainer.ALIGNMENT_CENTER
		var l_gname := Label.new()
		l_gname.text = "راند تک‌دست • %s" % game_fa_title
		l_gname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l_gname.add_theme_font_override("font", _font_hekayat)
		l_gname.add_theme_font_size_override("font_size", 22)
		l_gname.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		mid_v.add_child(l_gname)
		srh.add_child(mid_v)

		var r_icon := TextureRect.new()
		r_icon.custom_minimum_size = Vector2(48, 48)
		r_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r_icon.texture = _get_game_icon_texture(main_game_type)
		srh.add_child(r_icon)

		dvbox.add_child(single_round_card)
	else:
		for i in range(rounds.size()):
			var r = rounds[i]
			var r_gtype = str(r.get("game_type", main_game_type))
			var r_gname = _get_game_fa_name(r_gtype)

			var r_card := PanelContainer.new()
			r_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
			var rm := MarginContainer.new()
			rm.add_theme_constant_override("margin_left", 16)
			rm.add_theme_constant_override("margin_right", 16)
			rm.add_theme_constant_override("margin_top", 10)
			rm.add_theme_constant_override("margin_bottom", 10)
			r_card.add_child(rm)

			var rh := HBoxContainer.new()
			rh.alignment = BoxContainer.ALIGNMENT_CENTER
			rh.add_theme_constant_override("separation", 12)
			rm.add_child(rh)

			var r_win_uid = str(r.get("winner_user_id", ""))
			var r_win_id = str(r.get("winner_id", ""))
			var r_status_txt = "مساوی"
			var r_st_color = Color(1.0, 0.90, 0.40)
			var r_st_bg = Color(0.24, 0.18, 0.08, 0.95)
			var r_st_border = Color(0.80, 0.65, 0.35)

			var p1_uid = str(game.get("user1_id", ""))
			var is_p1 = (p1_uid == my_uid)

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

			var r_col := VBoxContainer.new()
			r_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_col.alignment = BoxContainer.ALIGNMENT_CENTER
			r_col.add_theme_constant_override("separation", 2)
			rh.add_child(r_col)

			var r_lbl := Label.new()
			r_lbl.text = "راند %s  •  %s" % [GameManager.to_fa_num(i + 1), r_gname]
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r_lbl.add_theme_font_override("font", _font_hekayat)
			r_lbl.add_theme_font_size_override("font_size", 24)
			r_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
			r_col.add_child(r_lbl)

			var r_date_str = str(r.get("date", ""))
			if not r_date_str.is_empty():
				var r_sub := Label.new()
				r_sub.text = _format_shamsi_date_ltr(r_date_str)
				r_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				r_sub.add_theme_font_override("font", _font_hekayat)
				r_sub.add_theme_font_size_override("font_size", 18)
				r_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
				r_col.add_child(r_sub)

			var r_icon_frame := PanelContainer.new()
			r_icon_frame.custom_minimum_size = Vector2(52, 52)
			var r_if_style := StyleBoxFlat.new()
			r_if_style.bg_color = Color(0.10, 0.07, 0.03, 0.95)
			r_if_style.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
			r_if_style.set_border_width_all(2)
			r_if_style.set_corner_radius_all(10)
			r_icon_frame.add_theme_stylebox_override("panel", r_if_style)

			var r_icon := TextureRect.new()
			r_icon.custom_minimum_size = Vector2(46, 46)
			r_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r_icon.texture = _get_game_icon_texture(r_gtype)
			r_icon_frame.add_child(r_icon)
			rh.add_child(r_icon_frame)

			dvbox.add_child(r_card)

	add_child(modal)


# --- B. Double-Size Statistics Matrix (2 Items per Row, Double Height & Font) ---

func _render_stats_matrix(holder: VBoxContainer) -> void:
	for c in holder.get_children():
		c.queue_free()

	if not _my_games_history_data.is_empty():
		_populate_double_stats_matrix(holder, _my_games_history_data)
		return

	holder.add_child(CafeSocialTheme.make_loading_state("در حال دریافت آمار تفصیلی..."))

	NetworkManager.api.get_my_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(holder): return
		for c in holder.get_children(): c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res = data["result"]
			_my_games_history_data = res if typeof(res) == TYPE_DICTIONARY else {}
			_populate_double_stats_matrix(holder, _my_games_history_data)
		else:
			holder.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت آمار بازی‌ها",
				"لطفاً ارتباط شبکه خود را بررسی فرمایید."
			))
	)


func _populate_double_stats_matrix(holder: VBoxContainer, hist: Dictionary) -> void:
	var title := Label.new()
	title.text = "📊 کارنامه و آمار کل مسابقات"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_override("font", _font_hekayat)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	holder.add_child(title)

	var w_rank = int(hist.get("win_rank", 0))
	var l_rank = int(hist.get("lose_rank", 0))
	var d_rank = int(hist.get("draw_rank", 0))
	var w_cr = int(hist.get("win_classic_rank", 0))
	var r1_mr = int(hist.get("rank1_multi_rank", 0))
	var r2_mr = int(hist.get("rank2_multi_rank", 0))

	var total_played = w_rank + l_rank + d_rank + w_cr + r1_mr + r2_mr
	var total_wins = w_rank + w_cr + r1_mr
	var win_rate = int(round((float(total_wins) / float(max(1, total_played))) * 100.0))

	var stat_cards_data = [
		{"label": "پیروزی‌های رنک", "val": GameManager.to_fa_num(w_rank), "col": Color(0.35, 0.95, 0.45), "sub": "مسابقات دو نفره"},
		{"label": "شکست‌های رنک", "val": GameManager.to_fa_num(l_rank), "col": Color(0.95, 0.40, 0.40), "sub": "مسابقات دو نفره"},
		{"label": "تک‌نفره (AI)", "val": GameManager.to_fa_num(w_cr), "col": Color(0.45, 0.85, 1.0), "sub": "کلاسیک هوش مصنوعی"},
		{"label": "مقام اول چندنفره", "val": GameManager.to_fa_num(r1_mr), "col": Color(1.0, 0.85, 0.35), "sub": "منچ، ریسک، مونوپولی"},
		{"label": "کل مسابقات", "val": GameManager.to_fa_num(total_played), "col": Color(0.95, 0.90, 0.80), "sub": "مجموع کل بازی‌ها"},
		{"label": "درصد برد کل", "val": "%s٪" % GameManager.to_fa_num(win_rate), "col": Color(1.0, 0.90, 0.35), "sub": "نرخ موفقیت"},
	]

	# Grid with 2 items per row, double height (200px) and double font size
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	holder.add_child(grid)

	for sc in stat_cards_data:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 130)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 16.0, 12.0))

		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 8)
		pad.add_theme_constant_override("margin_right", 8)
		card.add_child(pad)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 4)
		pad.add_child(cv)

		var lbl_title := Label.new()
		lbl_title.text = sc["label"]
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_title.add_theme_font_override("font", _font_hekayat)
		lbl_title.add_theme_font_size_override("font_size", 22)
		lbl_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
		cv.add_child(lbl_title)

		var lbl_val := Label.new()
		lbl_val.text = sc["val"]
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.add_theme_font_override("font", _font_hekayat)
		lbl_val.add_theme_font_size_override("font_size", 36)
		lbl_val.add_theme_color_override("font_color", sc["col"])
		cv.add_child(lbl_val)

		var lbl_sub := Label.new()
		lbl_sub.text = sc["sub"]
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.add_theme_font_override("font", _font_vazir)
		lbl_sub.add_theme_font_size_override("font_size", 16)
		lbl_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		cv.add_child(lbl_sub)

		grid.add_child(card)

	# Games breakdown cards underneath
	var g_spacer := Control.new()
	g_spacer.custom_minimum_size = Vector2(0, 10)
	holder.add_child(g_spacer)

	GamesHistoryViewHelper.populate_games_history(holder, hist)

	var stats_spacer := Control.new()
	stats_spacer.custom_minimum_size = Vector2(0, 40)
	stats_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(stats_spacer)


# ==============================================================================
# 2. COSMETICS / AVATAR & FRAME TILE HELPERS (Selection Glow, Tween, Checkmark & Lock)
# ==============================================================================

func _is_cosmetic_locked(kind: String, item_id: int) -> bool:
	var keys: Array = ["owned_avatars", "unlocked_avatars"] if kind == "avatar" else ["owned_frames", "unlocked_frames"]
	for key in keys:
		if GameManager.user_data.has(key) and typeof(GameManager.user_data[key]) == TYPE_ARRAY:
			var owned: Array = GameManager.user_data[key]
			if owned.is_empty():
				return false
			for entry in owned:
				if int(entry) == item_id:
					return false
			return true
	return false


func _make_cosmetic_tile_style(is_selected: bool, is_locked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	if is_locked:
		sb.bg_color = Color(0.10, 0.06, 0.04, 0.85)
		sb.border_color = Color(0.32, 0.22, 0.14, 0.65)
		sb.set_border_width_all(1)
	elif is_selected:
		sb.bg_color = Color(0.36, 0.23, 0.08, 0.96)
		sb.border_color = Color("#FFD86B")
		sb.set_border_width_all(3)
		sb.shadow_color = Color(1.0, 0.85, 0.42, 0.52)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 2)
	else:
		sb.bg_color = Color(0.14, 0.08, 0.05, 0.92)
		sb.border_color = Color(0.38, 0.25, 0.14, 0.85)
		sb.set_border_width_all(1)
	return sb


func _create_cosmetic_tile(tex: Texture2D, is_selected: bool, is_locked: bool, on_tap: Callable) -> Dictionary:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(108, 108)
	tile.pivot_offset = Vector2(54, 54)

	var inner := Control.new()
	inner.custom_minimum_size = Vector2(96, 96)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(inner)

	var btn := TextureButton.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_normal = tex
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
	if not is_locked:
		ActionVFXManager.apply_button_juice(btn, "tap_button")
	btn.pressed.connect(on_tap)
	inner.add_child(btn)

	# Selected corner checkmark badge (top-right)
	var check_badge := PanelContainer.new()
	check_badge.custom_minimum_size = Vector2(26, 26)
	check_badge.anchor_left = 1.0
	check_badge.anchor_top = 0.0
	check_badge.anchor_right = 1.0
	check_badge.anchor_bottom = 0.0
	check_badge.offset_left = -24.0
	check_badge.offset_top = -2.0
	check_badge.offset_right = 2.0
	check_badge.offset_bottom = 24.0
	check_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chk_sb := StyleBoxFlat.new()
	chk_sb.bg_color = Color("#1F7A3E")
	chk_sb.border_color = Color("#FFD86B")
	chk_sb.set_border_width_all(2)
	chk_sb.set_corner_radius_all(13)
	check_badge.add_theme_stylebox_override("panel", chk_sb)

	var lbl_chk := Label.new()
	lbl_chk.text = "✓"
	lbl_chk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_chk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_chk.add_theme_font_override("font", _font_vazir)
	lbl_chk.add_theme_font_size_override("font_size", 14)
	lbl_chk.add_theme_color_override("font_color", Color(1.0, 0.99, 0.94, 1.0))
	lbl_chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_badge.add_child(lbl_chk)
	inner.add_child(check_badge)

	# Locked corner badge (top-left)
	var lock_badge := PanelContainer.new()
	lock_badge.custom_minimum_size = Vector2(28, 28)
	lock_badge.anchor_left = 0.0
	lock_badge.anchor_top = 0.0
	lock_badge.anchor_right = 0.0
	lock_badge.anchor_bottom = 0.0
	lock_badge.offset_left = -2.0
	lock_badge.offset_top = -2.0
	lock_badge.offset_right = 26.0
	lock_badge.offset_bottom = 26.0
	lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lck_sb := StyleBoxFlat.new()
	lck_sb.bg_color = Color(0.11, 0.06, 0.03, 0.94)
	lck_sb.border_color = Color("#A87C44")
	lck_sb.set_border_width_all(1)
	lck_sb.set_corner_radius_all(14)
	lock_badge.add_theme_stylebox_override("panel", lck_sb)

	var lbl_lck := Label.new()
	lbl_lck.text = "🔒"
	lbl_lck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_lck.add_theme_font_size_override("font_size", 13)
	lbl_lck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge.add_child(lbl_lck)
	inner.add_child(lock_badge)

	var entry: Dictionary = {
		"tile": tile,
		"btn": btn,
		"check": check_badge,
		"lock": lock_badge,
		"locked": is_locked
	}
	_apply_cosmetic_tile_state(entry, is_selected, false)
	return entry


func _apply_cosmetic_tile_state(entry: Dictionary, is_selected: bool, animate: bool = false) -> void:
	var tile: PanelContainer = entry["tile"] as PanelContainer
	var btn: TextureButton = entry["btn"] as TextureButton
	var check_badge: PanelContainer = entry["check"] as PanelContainer
	var lock_badge: PanelContainer = entry["lock"] as PanelContainer
	var is_locked: bool = bool(entry["locked"])
	if not is_instance_valid(tile):
		return

	var active: bool = is_selected and not is_locked
	tile.add_theme_stylebox_override("panel", _make_cosmetic_tile_style(active, is_locked))
	tile.z_index = 2 if active else 0
	if is_instance_valid(check_badge):
		check_badge.visible = active
	if is_instance_valid(lock_badge):
		lock_badge.visible = is_locked
	if is_instance_valid(btn):
		if is_locked:
			btn.modulate = Color(0.75, 0.72, 0.68, 0.50)
		elif active:
			btn.modulate = Color(1.06, 1.04, 0.98, 1.0)
		else:
			btn.modulate = Color(0.95, 0.93, 0.90, 0.92)

	var target_scale: Vector2 = Vector2(1.08, 1.08) if active else Vector2.ONE
	if animate and tile.is_inside_tree():
		var tw: Tween = tile.create_tween()
		tw.set_trans(Tween.TRANS_BACK if active else Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "scale", target_scale, 0.16)
	else:
		tile.scale = target_scale


func _render_cosmetics() -> void:
	for c in content_cosmetics.get_children():
		c.queue_free()

	_selected_avatar_id = GameManager.get_avatar_id()

	# Center wrapper for avatar grid
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_cosmetics.add_child(center_wrap)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_top", 8)
	grid_margin.add_theme_constant_override("margin_bottom", 8)
	center_wrap.add_child(grid_margin)

	# 5 avatars per row, sized to fit comfortably within 720 screen
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(grid)

	var avatar_entries: Array[Dictionary] = []

	for i in range(72):
		var path: String = "res://assets/icons/Avatars/%d.png" % i
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue

		var current_i: int = i
		var is_locked: bool = _is_cosmetic_locked("avatar", current_i)
		var entry_ref: Array[Dictionary] = []
		var on_tap := func():
			if is_locked:
				AudioManager.sfx_tap()
				show_toast("این تصویر نمایه هنوز آزاد نشده است.", CafeSocialTheme.COL_GOLD_ANTIQUE)
				return
			AudioManager.sfx_tap()
			_selected_avatar_id = current_i
			for other in avatar_entries:
				_apply_cosmetic_tile_state(other, other == entry_ref[0], true)

		var entry: Dictionary = _create_cosmetic_tile(tex, current_i == _selected_avatar_id, is_locked, on_tap)
		entry_ref.append(entry)
		avatar_entries.append(entry)
		grid.add_child(entry["tile"] as PanelContainer)

	# Save button DOWN below the icons
	var save_box := HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_cosmetics.add_child(save_box)

	var btn_save := TextureButton.new()
	btn_save.custom_minimum_size = Vector2(83, 83)
	btn_save.ignore_texture_size = true
	btn_save.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_save.texture_normal = preload("res://assets/images/frames/check.png")
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_save, "tap_button")

	btn_save.pressed.connect(func():
		AudioManager.sfx_button()
		if _selected_avatar_id >= 0:
			btn_save.disabled = true
			NetworkManager.api.update_avatar(_selected_avatar_id, func(ok: bool, _c: int, _d: Variant):
				if is_instance_valid(btn_save):
					btn_save.disabled = false
				if ok:
					GameManager.user_data["image"] = _selected_avatar_id
					GameManager.user_data["avatar"] = _selected_avatar_id
					GameManager.set_session(GameManager.token, GameManager.user_data, true)
					if is_instance_valid(user_header) and user_header.has_method("update_ui"):
						user_header.update_ui()
					show_toast("تصویر نمایه شما با موفقیت بروزرسانی شد.")
				else:
					show_toast("خطا در ذخیره تصویر نمایه.", CafeSocialTheme.COL_CRIMSON_TEXT)
			)
	)
	save_box.add_child(btn_save)

	var av_spacer := Control.new()
	av_spacer.custom_minimum_size = Vector2(0, 44)
	av_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_cosmetics.add_child(av_spacer)


# ==============================================================================
# 2.5. AVATAR FRAMES GALLERY ("قاب آواتار" - Clean Selection Like Change Avatar)
# ==============================================================================

func _render_frames() -> void:
	for c in content_frames.get_children():
		c.queue_free()

	_selected_frame_id = GameManager.get_frame_id()

	# Center wrapper for frames grid
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frames.add_child(center_wrap)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_top", 8)
	grid_margin.add_theme_constant_override("margin_bottom", 8)
	center_wrap.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(grid)

	var frame_entries: Array[Dictionary] = []

	for fid in range(1, 21):
		var f_tex: Texture2D = CafeSocialTheme.get_frame_texture(fid)
		if f_tex == null:
			continue

		var cur_fid: int = fid
		var is_locked: bool = _is_cosmetic_locked("frame", cur_fid)
		var entry_ref: Array[Dictionary] = []
		var on_tap := func():
			if is_locked:
				AudioManager.sfx_tap()
				show_toast("این قاب آواتار هنوز آزاد نشده است.", CafeSocialTheme.COL_GOLD_ANTIQUE)
				return
			AudioManager.sfx_tap()
			_selected_frame_id = cur_fid
			for other in frame_entries:
				_apply_cosmetic_tile_state(other, other == entry_ref[0], true)

		var entry: Dictionary = _create_cosmetic_tile(f_tex, cur_fid == _selected_frame_id, is_locked, on_tap)
		entry_ref.append(entry)
		frame_entries.append(entry)
		grid.add_child(entry["tile"] as PanelContainer)

	# Save Button Below Frames
	var save_box := HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_frames.add_child(save_box)

	var btn_save := TextureButton.new()
	btn_save.custom_minimum_size = Vector2(83, 83)
	btn_save.ignore_texture_size = true
	btn_save.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_save.texture_normal = preload("res://assets/images/frames/check.png")
	btn_save.focus_mode = Control.FOCUS_NONE
	btn_save.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_save, "tap_button")

	btn_save.pressed.connect(func():
		AudioManager.sfx_button()
		if _selected_frame_id >= 1:
			btn_save.disabled = true
			NetworkManager.api.update_frame(_selected_frame_id, func(ok: bool, _c: int, _d: Variant):
				if is_instance_valid(btn_save):
					btn_save.disabled = false
				if ok:
					GameManager.user_data["profile_frame"] = _selected_frame_id
					GameManager.user_data["avatar_frame"] = _selected_frame_id
					GameManager.set_session(GameManager.token, GameManager.user_data, true)
					NetworkManager.api.customize_my_profile({"profile_frame": _selected_frame_id})
					if is_instance_valid(user_header) and user_header.has_method("update_ui"):
						user_header.update_ui()
					show_toast("قاب آواتار شما با موفقیت بروزرسانی و فعال شد.")
				else:
					show_toast("خطا در ذخیره قاب آواتار.", CafeSocialTheme.COL_CRIMSON_TEXT)
			)
	)
	save_box.add_child(btn_save)

	var fr_spacer := Control.new()
	fr_spacer.custom_minimum_size = Vector2(0, 44)
	fr_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frames.add_child(fr_spacer)


# ==============================================================================
# 3. PRIVACY & SOUND/MUSIC SECTION (Parlor-Styled Sliders, Toggles & Aligned Rows)
# ==============================================================================

func _build_aligned_audio_row(
	label_text: String,
	initial_enabled: bool,
	initial_volume_pct: float,
	on_toggle: Callable,
	on_volume_change: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	# 1. [Toggle]
	var chk := CheckButton.new()
	chk.text = ""
	chk.custom_minimum_size = Vector2(64, 42)
	chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chk.button_pressed = initial_enabled
	CafeSocialTheme.style_parlor_check_button(chk)
	row.add_child(chk)

	# 2. [Fixed-Width Label] (Identical width across Music & SFX rows for crisp alignment)
	var lbl_name := Label.new()
	lbl_name.custom_minimum_size = Vector2(124, 0)
	lbl_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_name.text = label_text
	lbl_name.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	lbl_name.add_theme_font_size_override("font_size", 21)
	lbl_name.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	row.add_child(lbl_name)

	# 3. [Parlor Slider]
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 38)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = initial_volume_pct
	slider.editable = initial_enabled
	slider.modulate.a = 1.0 if initial_enabled else 0.50
	CafeSocialTheme.style_parlor_slider(slider)
	row.add_child(slider)

	# 4. [Percentage]
	var lbl_val := Label.new()
	lbl_val.custom_minimum_size = Vector2(54, 0)
	lbl_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	lbl_val.add_theme_font_size_override("font_size", 18)
	lbl_val.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	lbl_val.text = "%s٪" % GameManager.to_fa_num(int(round(initial_volume_pct)))
	lbl_val.modulate.a = 1.0 if initial_enabled else 0.55
	row.add_child(lbl_val)

	slider.value_changed.connect(func(v: float):
		lbl_val.text = "%s٪" % GameManager.to_fa_num(int(round(v)))
		on_volume_change.call(v)
	)

	chk.toggled.connect(func(p: bool):
		slider.editable = p
		slider.modulate.a = 1.0 if p else 0.50
		lbl_val.modulate.a = 1.0 if p else 0.55
		on_toggle.call(p)
	)

	return row


func _render_privacy() -> void:
	for c in content_privacy.get_children():
		c.queue_free()

	# --- 1. Sound & Music Settings Card ---
	var audio_margin := MarginContainer.new()
	audio_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_margin.add_theme_constant_override("margin_left", 10)
	audio_margin.add_theme_constant_override("margin_right", 10)
	content_privacy.add_child(audio_margin)

	var audio_card := PanelContainer.new()
	audio_card.custom_minimum_size = Vector2(0, 184)
	audio_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 18.0, 16.0))
	audio_margin.add_child(audio_card)

	var a_vbox := VBoxContainer.new()
	a_vbox.add_theme_constant_override("separation", 14)
	audio_card.add_child(a_vbox)

	var a_title := Label.new()
	a_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	a_title.add_theme_font_size_override("font_size", 25)
	a_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	a_title.text = "تنظیمات صدا و موسیقی کافه فکر"
	a_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a_vbox.add_child(a_title)

	# Music row: [Toggle] + [Label] + [Slider] + [Percentage]
	a_vbox.add_child(_build_aligned_audio_row(
		"موسیقی",
		AudioManager.is_music_enabled,
		AudioManager.music_volume * 100.0,
		func(p: bool):
			AudioManager.set_music_enabled(p)
			if p and not AudioManager.music_player.playing:
				AudioManager.play_theme_music(),
		func(v: float):
			AudioManager.set_music_volume(v / 100.0)
	))

	# SFX row: [Toggle] + [Label] + [Slider] + [Percentage]
	a_vbox.add_child(_build_aligned_audio_row(
		"جلوه‌ها (SFX)",
		AudioManager.is_sound_enabled,
		AudioManager.sfx_volume * 100.0,
		func(p: bool):
			AudioManager.set_sound_enabled(p)
			if p:
				AudioManager.sfx_tap(),
		func(v: float):
			AudioManager.set_sfx_volume(v / 100.0)
	))

	# --- 2. Privacy Toggles with Parlor Styling & Mobile Sizing ---
	var p_title := Label.new()
	p_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	p_title.add_theme_font_size_override("font_size", 25)
	p_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	p_title.text = "حریم خصوصی و دسترسی‌ها"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_privacy.add_child(p_title)

	var current_priv: Dictionary = GameManager.user_data.get("privacy", {}) if typeof(GameManager.user_data.get("privacy")) == TYPE_DICTIONARY else {}

	var items: Array[Dictionary] = [
		{
			"key": "allow_friend_requests",
			"label": "دریافت درخواست دوستی از سایر بازیکنان",
			"desc": "امکان ارسال پیام دعوت به دوستی از سمت کاربران دیگر",
			"default": true
		},
		{
			"key": "allow_spectators",
			"label": "اجازه تماشای زنده مسابقات من توسط دیگران",
			"desc": "نمایش مسابقه زنده شما در بخش تماشاگران برای دوستان و هم‌اتحادی‌ها",
			"default": true
		},
		{
			"key": "show_last_seen",
			"label": "نمایش وضعیت آنلاین و آخرین حضور",
			"desc": "آیا دوستان شما متوجه حضور شما در بازی باشند",
			"default": true
		},
		{
			"key": "show_current_game",
			"label": "نمایش بازی در حال انجام به دیگران",
			"desc": "اشتراک‌گذاری نوع بردگیمی که هم‌اکنون مشغول انجام آن هستید",
			"default": true
		},
		{
			"key": "show_match_history",
			"label": "نمایش تاریخچه و سوابق مسابقات در پروفایل",
			"desc": "اجازه مشاهده سوابق و بردهای قبلی شما توسط سایر کاربران",
			"default": true
		},
	]

	var toggle_map: Dictionary = {}

	for item in items:
		var key: String = str(item["key"])
		var current_val: bool = bool(current_priv.get(key, item["default"]))

		var item_margin := MarginContainer.new()
		item_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_margin.add_theme_constant_override("margin_left", 10)
		item_margin.add_theme_constant_override("margin_right", 10)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 108)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 16.0, 12.0))
		item_margin.add_child(panel)

		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)

		var toggle := CheckButton.new()
		toggle.text = ""
		toggle.custom_minimum_size = Vector2(64, 42)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.button_pressed = current_val
		CafeSocialTheme.style_parlor_check_button(toggle)
		toggle.toggled.connect(func(_p: bool): AudioManager.sfx_tap())
		h.add_child(toggle)
		toggle_map[key] = toggle

		var v_col := VBoxContainer.new()
		v_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_col.add_theme_constant_override("separation", 2)
		v_col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v_col)

		var lbl_title := Label.new()
		lbl_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		lbl_title.add_theme_font_size_override("font_size", 22)
		lbl_title.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		lbl_title.text = str(item["label"])
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_col.add_child(lbl_title)

		var lbl_desc := Label.new()
		lbl_desc.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lbl_desc.add_theme_font_size_override("font_size", 17)
		lbl_desc.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		lbl_desc.text = str(item["desc"])
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_col.add_child(lbl_desc)

		content_privacy.add_child(item_margin)

	# Save Privacy Button (Icon button with check.png)
	var save_priv_box := HBoxContainer.new()
	save_priv_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_privacy.add_child(save_priv_box)

	var btn_save_priv := TextureButton.new()
	btn_save_priv.custom_minimum_size = Vector2(83, 83)
	btn_save_priv.ignore_texture_size = true
	btn_save_priv.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_save_priv.texture_normal = preload("res://assets/images/frames/check.png")
	btn_save_priv.focus_mode = Control.FOCUS_NONE
	btn_save_priv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_save_priv, "tap_button")

	btn_save_priv.pressed.connect(func():
		AudioManager.sfx_button()
		btn_save_priv.disabled = true
		var new_priv: Dictionary = {}
		for k in toggle_map:
			var cb_node: CheckButton = toggle_map[k] as CheckButton
			if is_instance_valid(cb_node):
				new_priv[k] = cb_node.button_pressed

		NetworkManager.api.customize_my_profile({"privacy": new_priv}, func(ok: bool, _c: int, _data: Variant):
			if is_instance_valid(btn_save_priv):
				btn_save_priv.disabled = false
			if ok:
				GameManager.user_data["privacy"] = new_priv
				GameManager.set_session(GameManager.token, GameManager.user_data, true)
				show_toast("تنظیمات حریم خصوصی با موفقیت در سرور ذخیره شد.")
			else:
				show_toast("خطا در برقراری ارتباط با سرور.", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	save_priv_box.add_child(btn_save_priv)

	# Bottom padding spacer so the save button / last toggle never clips behind the bottom nav bar
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 44)
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_privacy.add_child(bottom_spacer)


# ==============================================================================
# 4. NOTIFICATIONS SECTION (Moved from Social Tab)
# ==============================================================================

func _render_notifs() -> void:
	for c in content_notifs.get_children():
		c.queue_free()

	SocialNotificationsView.render(self, content_notifs)
