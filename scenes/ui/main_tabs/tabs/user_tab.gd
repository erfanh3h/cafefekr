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


func _style_subnav_btn(btn: Button, is_act: bool) -> void:
	if is_act:
		KenneyUI.style_button(btn, KenneyUI.COLOR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
	else:
		KenneyUI.style_button(btn, KenneyUI.COLOR_GREY)
		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))


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
	_style_subnav_btn(btn_seg_matches, active_history_view == "matches")
	seg_box.add_child(btn_seg_matches)

	var btn_seg_stats := Button.new()
	btn_seg_stats.text = "آمار کلی و بردگیم‌ها"
	btn_seg_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_seg_stats.custom_minimum_size = Vector2(0, 52)
	btn_seg_stats.focus_mode = Control.FOCUS_NONE
	btn_seg_stats.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(btn_seg_stats, "tap_button")
	_style_subnav_btn(btn_seg_stats, active_history_view == "stats")
	seg_box.add_child(btn_seg_stats)

	var dynamic_holder := VBoxContainer.new()
	dynamic_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dynamic_holder.add_theme_constant_override("separation", 14)
	content_profile.add_child(dynamic_holder)

	btn_seg_matches.pressed.connect(func():
		AudioManager.sfx_tap()
		active_history_view = "matches"
		_style_subnav_btn(btn_seg_matches, true)
		_style_subnav_btn(btn_seg_stats, false)
		_render_recent_matches(dynamic_holder)
	)

	btn_seg_stats.pressed.connect(func():
		AudioManager.sfx_tap()
		active_history_view = "stats"
		_style_subnav_btn(btn_seg_matches, false)
		_style_subnav_btn(btn_seg_stats, true)
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
		var card = _create_authentic_summary_card(game_data, my_uid)
		holder.add_child(card)


func _create_authentic_summary_card(game: Dictionary, my_uid: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 184)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var mode_raw = str(game.get("game_score_type", "Rank"))
	var my_res = str(game.get("my_result", ""))
	var winner_id = str(game.get("winner_id", game.get("winner", "")))
	if my_res.is_empty():
		if winner_id == my_uid and not my_uid.is_empty():
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"

	var style_frame := CafeSocialTheme.create_frame_style(true, 38.0, 24.0)
	btn.add_theme_stylebox_override("normal", style_frame)
	btn.add_theme_stylebox_override("hover", style_frame)
	btn.add_theme_stylebox_override("pressed", style_frame)
	btn.add_theme_stylebox_override("focus", style_frame)

	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_right", 40)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 28)
	btn.add_child(pad)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
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

	# 1. LEFT SIDE: Opponent Avatar + Name directly underneath
	var opp_col := VBoxContainer.new()
	opp_col.custom_minimum_size = Vector2(108, 130)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_col.add_theme_constant_override("separation", 4)
	opp_col.mouse_filter = Control.MOUSE_FILTER_PASS

	var av_panel := PanelContainer.new()
	av_panel.custom_minimum_size = Vector2(92, 92)
	av_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	av_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var av_img := TextureRect.new()
	av_img.custom_minimum_size = Vector2(88, 88)
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
	lbl_opp_name.text = opp_name
	lbl_opp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_opp_name.custom_minimum_size = Vector2(105, 0)
	lbl_opp_name.clip_text = true
	lbl_opp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_opp_name.add_theme_font_override("font", _font_hekayat)
	lbl_opp_name.add_theme_font_size_override("font_size", 24)
	lbl_opp_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lbl_opp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_col.add_child(lbl_opp_name)
	row.add_child(opp_col)

	# 2. CENTER SECTION: Outcome, Integer Score, and Shamsi Date (LTR)
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 8)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_mid := HBoxContainer.new()
	top_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top_mid.add_theme_constant_override("separation", 14)
	top_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl_res := Label.new()
	lbl_res.add_theme_font_override("font", _font_hekayat)
	lbl_res.add_theme_font_size_override("font_size", 34)
	if my_res == "win":
		lbl_res.text = "برد 🏆"
		lbl_res.add_theme_color_override("font_color", Color(0.40, 0.95, 0.45))
	elif my_res == "lose":
		lbl_res.text = "باخت"
		lbl_res.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	elif my_res == "draw":
		lbl_res.text = "مساوی"
		lbl_res.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	else:
		lbl_res.text = "ناتمام"
		lbl_res.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	top_mid.add_child(lbl_res)

	# Integer score
	var scores = game.get("user_scores", [])
	var score_str = ""
	if typeof(scores) == TYPE_ARRAY and scores.size() >= 2:
		var p1_uid = str(game.get("user1_id", ""))
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
		lbl_score.add_theme_font_size_override("font_size", 32)
		lbl_score.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
		top_mid.add_child(lbl_score)
	center_col.add_child(top_mid)

	# Shamsi Date LTR
	var s_date_raw = str(game.get("start_date", ""))
	var shamsi_date = _format_shamsi_date_ltr(s_date_raw)
	var lbl_date := Label.new()
	lbl_date.text_direction = Control.TEXT_DIRECTION_LTR
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.text = shamsi_date
	lbl_date.add_theme_font_override("font", _font_hekayat)
	lbl_date.add_theme_font_size_override("font_size", 26)
	lbl_date.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	center_col.add_child(lbl_date)
	row.add_child(center_col)

	# 3. RIGHT SIDE: Big Game Mode Badge Icon
	var mode_badge := TextureRect.new()
	mode_badge.custom_minimum_size = Vector2(92, 92)
	mode_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mode_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mode_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_badge.texture = _get_mode_badge_texture(mode_raw)
	row.add_child(mode_badge)

	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		_show_game_details_dialog(game)
	)

	return btn


func _format_shamsi_date_ltr(iso_str: String) -> String:
	if iso_str.is_empty():
		return "امروز"
	var parts = iso_str.split("T")
	var date_part = parts[0]
	var ymd = date_part.split("-")
	if ymd.size() == 3:
		var gy = int(ymd[0])
		var gm = int(ymd[1])
		var gd = int(ymd[2])
		var j = _gregorian_to_jalali(gy, gm, gd)
		var month_names = [
			"فروردین", "اردیبهشت", "خرداد",
			"تیر", "مرداد", "شهریور",
			"مهر", "آبان", "آذر",
			"دی", "بهمن", "اسفند"
		]
		var m_name = month_names[j["month"] - 1] if j["month"] >= 1 and j["month"] <= 12 else ""
		return "%s %s %s" % [GameManager.to_fa_num(j["day"]), m_name, GameManager.to_fa_num(j["year"])]
	return iso_str


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


func _show_game_details_dialog(game: Dictionary) -> void:
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.z_index = 50

	var bg_dim := ColorRect.new()
	bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_dim.color = Color(0, 0, 0, 0.75)
	modal.add_child(bg_dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20
	panel.offset_top = 40
	panel.offset_right = -20
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_GOLD_BRIGHT, 18))
	modal.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(m)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = 0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(scroll)

	var dvbox := VBoxContainer.new()
	dvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dvbox.add_theme_constant_override("separation", 14)
	scroll.add_child(dvbox)

	var my_uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))
	var winner_id = str(game.get("winner_id", game.get("winner", "")))
	var my_res = str(game.get("my_result", ""))
	if my_res.is_empty():
		if winner_id == my_uid and not my_uid.is_empty():
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"

	var top_card := PanelContainer.new()
	var tc_style := StyleBoxFlat.new()
	tc_style.set_corner_radius_all(16)
	tc_style.set_border_width_all(2)
	tc_style.content_margin_left = 20
	tc_style.content_margin_right = 20
	tc_style.content_margin_top = 16
	tc_style.content_margin_bottom = 16

	var res_headline = "پیروزی شما! 🏆"
	if my_res == "win":
		tc_style.bg_color = Color(0.12, 0.40, 0.16, 0.95)
		tc_style.border_color = Color(0.40, 0.85, 0.45, 1.0)
		res_headline = "تبریک! برنده این مسابقه شدید 🏆"
	elif my_res == "lose":
		tc_style.bg_color = Color(0.45, 0.12, 0.12, 0.95)
		tc_style.border_color = Color(0.85, 0.35, 0.35, 1.0)
		res_headline = "در این مسابقه شکست خوردید"
	elif my_res == "draw":
		tc_style.bg_color = Color(0.25, 0.22, 0.18, 0.95)
		tc_style.border_color = Color(0.75, 0.65, 0.45, 1.0)
		res_headline = "این مسابقه مساوی شد"
	else:
		tc_style.bg_color = Color(0.20, 0.16, 0.12, 0.95)
		tc_style.border_color = Color(0.60, 0.50, 0.35, 1.0)
		res_headline = "مسابقه ناتمام ماند"
	top_card.add_theme_stylebox_override("panel", tc_style)

	var tc_vbox := VBoxContainer.new()
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_vbox.add_theme_constant_override("separation", 6)
	top_card.add_child(tc_vbox)

	var lbl_hd := Label.new()
	lbl_hd.text = res_headline
	lbl_hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hd.add_theme_font_override("font", _font_hekayat)
	lbl_hd.add_theme_font_size_override("font_size", 38)
	lbl_hd.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	tc_vbox.add_child(lbl_hd)

	var s_date = _format_shamsi_date_ltr(str(game.get("start_date", "")))
	var lbl_dm := Label.new()
	lbl_dm.text = "%s  •  %s" % [s_date, str(game.get("game_score_type", "Rank"))]
	lbl_dm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dm.add_theme_font_override("font", _font_hekayat)
	lbl_dm.add_theme_font_size_override("font_size", 26)
	lbl_dm.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	tc_vbox.add_child(lbl_dm)
	dvbox.add_child(top_card)

	# Rounds details if present
	var rounds = game.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not rounds.is_empty():
		var r_title := Label.new()
		r_title.text = "راندهای مسابقه"
		r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r_title.add_theme_font_override("font", _font_hekayat)
		r_title.add_theme_font_size_override("font_size", 30)
		r_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
		dvbox.add_child(r_title)

		for i in range(rounds.size()):
			var r = rounds[i]
			var r_card := PanelContainer.new()
			r_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
			var rm := MarginContainer.new()
			rm.add_theme_constant_override("margin_left", 16)
			rm.add_theme_constant_override("margin_top", 10)
			rm.add_theme_constant_override("margin_right", 16)
			rm.add_theme_constant_override("margin_bottom", 10)
			r_card.add_child(rm)

			var rh := HBoxContainer.new()
			rm.add_child(rh)

			var r_lbl := Label.new()
			r_lbl.text = "راند %s  •  نوع: %s" % [GameManager.to_fa_num(i + 1), str(r.get("game_type", "بازی"))]
			r_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r_lbl.add_theme_font_override("font", _font_hekayat)
			r_lbl.add_theme_font_size_override("font_size", 24)
			r_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
			rh.add_child(r_lbl)
			dvbox.add_child(r_card)

	# Back button
	var btn_close := CafeSocialTheme.make_button("بازگشت", "gold", Vector2(240, 56), 24)
	btn_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_close.pressed.connect(func():
		AudioManager.sfx_tap()
		modal.queue_free()
	)
	dvbox.add_child(btn_close)

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
		card.custom_minimum_size = Vector2(0, 196)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)

		var lbl_title := Label.new()
		lbl_title.text = sc["label"]
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_title.add_theme_font_override("font", _font_hekayat)
		lbl_title.add_theme_font_size_override("font_size", 28)
		lbl_title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
		cv.add_child(lbl_title)

		var lbl_val := Label.new()
		lbl_val.text = sc["val"]
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_val.add_theme_font_override("font", _font_hekayat)
		lbl_val.add_theme_font_size_override("font_size", 52)
		lbl_val.add_theme_color_override("font_color", sc["col"])
		cv.add_child(lbl_val)

		var lbl_sub := Label.new()
		lbl_sub.text = sc["sub"]
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.add_theme_font_override("font", _font_vazir)
		lbl_sub.add_theme_font_size_override("font_size", 18)
		lbl_sub.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		cv.add_child(lbl_sub)

		grid.add_child(card)

	# Games breakdown cards underneath
	var g_spacer := Control.new()
	g_spacer.custom_minimum_size = Vector2(0, 10)
	holder.add_child(g_spacer)

	GamesHistoryViewHelper.populate_games_history(holder, hist)


# ==============================================================================
# 2. COSMETICS / AVATAR GALLERY (4 Columns, Bigger Icons 170x170, Wide Spacing)
# ==============================================================================

func _render_cosmetics() -> void:
	for c in content_cosmetics.get_children():
		c.queue_free()

	_selected_avatar_id = GameManager.get_avatar_id()

	# Center wrapper for avatar grid
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_cosmetics.add_child(center_wrap)

	# 5 avatars per row, larger avatar icons and generous spacing
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 24)
	center_wrap.add_child(grid)

	var avatar_buttons: Array[TextureButton] = []

	for i in range(72):
		var path = "res://assets/icons/Avatars/%d.png" % i
		if not ResourceLoader.exists(path):
			continue

		var p_btn := TextureButton.new()
		p_btn.custom_minimum_size = Vector2(162, 162)
		p_btn.ignore_texture_size = true
		p_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		p_btn.texture_normal = load(path)
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(p_btn, "tap_button")

		if i == _selected_avatar_id:
			p_btn.modulate = Color(1.2, 1.1, 0.8, 1.0)

		var current_i = i
		p_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			_selected_avatar_id = current_i
			for btn in avatar_buttons:
				btn.modulate = Color(1.0, 1.0, 1.0, 0.85)
			p_btn.modulate = Color(1.2, 1.1, 0.8, 1.0)
			show_toast("آواتار شماره %s برگزیده شد." % GameManager.to_fa_num(current_i + 1), CafeSocialTheme.COL_GOLD_BRIGHT)
		)
		avatar_buttons.append(p_btn)
		grid.add_child(p_btn)

	# Save button DOWN below the icons
	var save_box := HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_cosmetics.add_child(save_box)

	var btn_save := CafeSocialTheme.make_button("ثبت تغییرات آواتار", "emerald", Vector2(340, 62), 26, CafeSocialTheme.ICO_CHECK)
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


# ==============================================================================
# 2.5. AVATAR FRAMES GALLERY ("قاب آواتار" - Clean Selection Like Change Avatar)
# ==============================================================================

func _render_frames() -> void:
	for c in content_frames.get_children():
		c.queue_free()

	_selected_frame_id = GameManager.get_frame_id()

	# Center wrapper for frames grid (simple selection matching change avatar part)
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frames.add_child(center_wrap)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 24)
	center_wrap.add_child(grid)

	var frame_buttons: Array[TextureButton] = []

	for fid in range(1, 21):
		var f_tex: Texture2D = CafeSocialTheme.get_frame_texture(fid)
		if f_tex == null:
			continue

		var f_btn := TextureButton.new()
		f_btn.custom_minimum_size = Vector2(162, 162)
		f_btn.ignore_texture_size = true
		f_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		f_btn.texture_normal = f_tex
		f_btn.focus_mode = Control.FOCUS_NONE
		f_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(f_btn, "tap_button")

		if fid == _selected_frame_id:
			f_btn.modulate = Color(1.25, 1.15, 0.82, 1.0)
		else:
			f_btn.modulate = Color(1.0, 1.0, 1.0, 0.85)

		var cur_fid: int = fid
		f_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			_selected_frame_id = cur_fid
			for btn in frame_buttons:
				btn.modulate = Color(1.0, 1.0, 1.0, 0.85)
			f_btn.modulate = Color(1.25, 1.15, 0.82, 1.0)
			show_toast("قاب شماره %s برگزیده شد." % GameManager.to_fa_num(cur_fid), CafeSocialTheme.COL_GOLD_BRIGHT)
		)
		frame_buttons.append(f_btn)
		grid.add_child(f_btn)

	# Save Button Below Frames
	var save_box := HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_frames.add_child(save_box)

	var btn_save := CafeSocialTheme.make_button("ثبت تغییرات قاب آواتار", "emerald", Vector2(360, 62), 26, CafeSocialTheme.ICO_CHECK)
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


# ==============================================================================
# 3. PRIVACY & SOUND/MUSIC SECTION (Bigger Switches, Functional Audio & Privacy)
# ==============================================================================

func _render_privacy() -> void:
	for c in content_privacy.get_children():
		c.queue_free()

	# --- 1. Sound & Music Settings Card (Moved to Privacy) ---
	var audio_card := PanelContainer.new()
	audio_card.custom_minimum_size = Vector2(0, 224)
	audio_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 38.0, 24.0))
	content_privacy.add_child(audio_card)

	var a_vbox := VBoxContainer.new()
	a_vbox.add_theme_constant_override("separation", 14)
	audio_card.add_child(a_vbox)

	var a_title := Label.new()
	a_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	a_title.add_theme_font_size_override("font_size", 28)
	a_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	a_title.text = "تنظیمات صدا و موسیقی کافه فکر"
	a_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a_vbox.add_child(a_title)

	# Music row
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 16)
	a_vbox.add_child(music_row)

	var chk_music := CheckButton.new()
	chk_music.text = "موسیقی"
	chk_music.custom_minimum_size = Vector2(80, 56)
	chk_music.button_pressed = AudioManager.is_music_enabled
	chk_music.focus_mode = Control.FOCUS_NONE
	music_row.add_child(chk_music)

	var music_slider := HSlider.new()
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.custom_minimum_size = Vector2(0, 48)
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.value = AudioManager.music_volume * 100.0
	music_row.add_child(music_slider)

	var lbl_music_val := Label.new()
	lbl_music_val.custom_minimum_size = Vector2(60, 0)
	lbl_music_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	lbl_music_val.add_theme_font_size_override("font_size", 22)
	lbl_music_val.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	lbl_music_val.text = "%s٪" % GameManager.to_fa_num(int(music_slider.value))
	music_row.add_child(lbl_music_val)

	music_slider.value_changed.connect(func(v: float):
		lbl_music_val.text = "%s٪" % GameManager.to_fa_num(int(v))
		AudioManager.set_music_volume(v / 100.0)
	)

	chk_music.toggled.connect(func(p: bool):
		AudioManager.set_music_enabled(p)
		if p and not AudioManager.music_player.playing:
			AudioManager.play_theme_music()
	)

	# SFX row
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 16)
	a_vbox.add_child(sfx_row)

	var chk_sfx := CheckButton.new()
	chk_sfx.text = "جلوه‌ها (SFX)"
	chk_sfx.custom_minimum_size = Vector2(80, 56)
	chk_sfx.button_pressed = AudioManager.is_sound_enabled
	chk_sfx.focus_mode = Control.FOCUS_NONE
	sfx_row.add_child(chk_sfx)

	var sfx_slider := HSlider.new()
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.custom_minimum_size = Vector2(0, 48)
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.value = AudioManager.sfx_volume * 100.0
	sfx_row.add_child(sfx_slider)

	var lbl_sfx_val := Label.new()
	lbl_sfx_val.custom_minimum_size = Vector2(60, 0)
	lbl_sfx_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	lbl_sfx_val.add_theme_font_size_override("font_size", 22)
	lbl_sfx_val.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	lbl_sfx_val.text = "%s٪" % GameManager.to_fa_num(int(sfx_slider.value))
	sfx_row.add_child(lbl_sfx_val)

	sfx_slider.value_changed.connect(func(v: float):
		lbl_sfx_val.text = "%s٪" % GameManager.to_fa_num(int(v))
		AudioManager.set_sfx_volume(v / 100.0)
	)

	chk_sfx.toggled.connect(func(p: bool):
		AudioManager.set_sound_enabled(p)
		if p:
			AudioManager.sfx_tap()
	)

	# --- 2. Privacy Toggles with Bigger Switches & Text ---
	var p_title := Label.new()
	p_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	p_title.add_theme_font_size_override("font_size", 30)
	p_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	p_title.text = "حریم خصوصی و دسترسی‌ها"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_privacy.add_child(p_title)

	var current_priv: Dictionary = GameManager.user_data.get("privacy", {})

	var items = [
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
		var key: String = item["key"]
		var current_val: bool = bool(current_priv.get(key, item["default"]))

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 124)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(false, 40.0, 20.0))

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		panel.add_child(h)

		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(90, 60)
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggle.button_pressed = current_val
		h.add_child(toggle)
		toggle_map[key] = toggle

		var v_col := VBoxContainer.new()
		v_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_col.add_theme_constant_override("separation", 4)
		v_col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v_col)

		var lbl_title := Label.new()
		lbl_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		lbl_title.add_theme_font_size_override("font_size", 30)
		lbl_title.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		lbl_title.text = item["label"]
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_col.add_child(lbl_title)

		var lbl_desc := Label.new()
		lbl_desc.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lbl_desc.add_theme_font_size_override("font_size", 22)
		lbl_desc.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		lbl_desc.text = item["desc"]
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_col.add_child(lbl_desc)

		content_privacy.add_child(panel)

	# Save Privacy Button
	var btn_save_priv := CafeSocialTheme.make_button("ذخیره تنظیمات حریم خصوصی", "gold", Vector2(360, 60), 26, CafeSocialTheme.ICO_CHECK)
	btn_save_priv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_save_priv.pressed.connect(func():
		AudioManager.sfx_button()
		btn_save_priv.disabled = true
		var new_priv: Dictionary = {}
		for k in toggle_map:
			new_priv[k] = toggle_map[k].button_pressed

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
	content_privacy.add_child(btn_save_priv)


# ==============================================================================
# 4. NOTIFICATIONS SECTION (Moved from Social Tab)
# ==============================================================================

func _render_notifs() -> void:
	for c in content_notifs.get_children():
		c.queue_free()

	SocialNotificationsView.render(self, content_notifs)
