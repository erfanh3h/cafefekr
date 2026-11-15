extends Control

## Cafe Fekr — History Tab (Royal Player Record Book)
## Sections:
## 1. Match History (سوابق مسابقات اخیر با جزییات و تاریخ شمسی)
## 2. Player Statistics (آمار بازی‌ها، بردها، باخت‌ها و نسبت پیروزی)
## 3. Leaderboards (رتبه‌بندی امتیازی، بیشترین پیروزی، دوستان و کلن‌ها)

signal user_profile_requested(user_data: Dictionary)

@onready var subtab_matches: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnMatches
@onready var subtab_stats: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnStats
@onready var subtab_leaderboard: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLeaderboard

@onready var content_matches: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/MatchesContent
@onready var content_stats: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/StatsContent
@onready var content_lb: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent
@onready var details_modal: Control = $OuterMargin/MainPanel/InnerMargin/VBox/DetailsModal
@onready var details_container: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/DetailsModal/Scroll/DetailsVBox
@onready var btn_back_from_details: Button = $OuterMargin/MainPanel/InnerMargin/VBox/DetailsModal/BtnBack

@onready var lb_subtabs: HBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbSubTabs
@onready var btn_lb_score: Button = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbSubTabs/BtnLbScore
@onready var btn_lb_win: Button = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbSubTabs/BtnLbWin
@onready var btn_lb_friends: Button = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbSubTabs/BtnLbFriends
@onready var btn_lb_clans: Button = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbSubTabs/BtnLbClans
@onready var lb_list_vbox: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/LeaderboardContent/LbListVBox

var active_section: String = "matches" # "matches" | "stats" | "leaderboard"
var active_lb_tab: String = "score"    # "score" | "win" | "friends" | "clans"

var _history_matches: Array = []
var _my_stats_data: Dictionary = {}
var _leaderboard_cache: Dictionary = {}

func _ready() -> void:
	KenneyUI.style_button(btn_back_from_details, KenneyUI.COLOR_YELLOW)
	ActionVFXManager.apply_button_juice(subtab_matches, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_stats, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_leaderboard, "tap_button")
	ActionVFXManager.apply_button_juice(btn_back_from_details, "tap_button")

	subtab_matches.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_section("matches")
	)
	subtab_stats.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_section("stats")
	)
	subtab_leaderboard.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_section("leaderboard")
	)

	btn_back_from_details.pressed.connect(func():
		AudioManager.sfx_tap()
		details_modal.visible = false
	)

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

	switch_section("matches")


func switch_section(sec_name: String) -> void:
	active_section = sec_name
	details_modal.visible = false

	_style_subnav_btn(subtab_matches, sec_name == "matches")
	_style_subnav_btn(subtab_stats, sec_name == "stats")
	_style_subnav_btn(subtab_leaderboard, sec_name == "leaderboard")

	content_matches.visible = (sec_name == "matches")
	content_stats.visible = (sec_name == "stats")
	content_lb.visible = (sec_name == "leaderboard")

	match sec_name:
		"matches":
			_load_matches_if_needed()
		"stats":
			_load_stats_if_needed()
		"leaderboard":
			switch_lb_tab(active_lb_tab)


func _style_subnav_btn(btn: Button, is_active: bool) -> void:
	if is_active:
		KenneyUI.style_button(btn, KenneyUI.COLOR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
	else:
		KenneyUI.style_button(btn, KenneyUI.COLOR_GREY)
		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))


func _load_matches_if_needed() -> void:
	if not _history_matches.is_empty():
		return
	for c in content_matches.get_children():
		c.queue_free()
	content_matches.add_child(CafeSocialTheme.make_loading_state("در حال دریافت تاریخچه بازی‌ها..."))

	NetworkManager.api.get_my_game_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(content_matches):
			return
		for c in content_matches.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_ARRAY:
			_history_matches = data["result"]
			_render_matches_list()
		else:
			content_matches.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"هنوز بازی ثبت نشده است",
				"با شروع رقابت در تب «بازی»، سوابق مسابقات شما در اینجا نمایش داده می‌شود."
			))
	)


func _render_matches_list() -> void:
	for c in content_matches.get_children():
		c.queue_free()

	if _history_matches.is_empty():
		content_matches.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"هیچ مسابقه‌ای یافت نشد",
			"اولین بازی خود را از بخش بازی شروع کنید!"
		))
		return

	var my_uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))

	for match_dict in _history_matches:
		var card = _create_match_card(match_dict, my_uid)
		content_matches.add_child(card)


func _create_match_card(m: Dictionary, my_uid: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Outcome Badge
	var winner_id = str(m.get("winner", m.get("winner_id", "")))
	var is_draw = bool(m.get("is_draw", false)) or winner_id == "draw"
	var is_win = (winner_id == my_uid and not is_draw)

	var btn_details := CafeSocialTheme.make_button("جزییات", "wood", Vector2(100, 48), 20)
	btn_details.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_match_details(m)
	)
	hbox.add_child(btn_details)

	# Center info: Scores & Mode
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 4)
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(center_col)

	var game_key = str(m.get("game_type", m.get("game", "بازی")))
	var game_name_fa = _get_game_fa_name(game_key)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.text = game_name_fa
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center_col.add_child(title_lbl)

	var status_text = "برد" if is_win else ("مساوی" if is_draw else "باخت")
	var status_color = CafeSocialTheme.COL_EMERALD_TEXT if is_win else (CafeSocialTheme.COL_GOLD_BRIGHT if is_draw else CafeSocialTheme.COL_CRIMSON_TEXT)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	status_lbl.add_theme_font_size_override("font_size", 18)
	status_lbl.add_theme_color_override("font_color", status_color)
	status_lbl.text = "نتیجه: %s" % status_text
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center_col.add_child(status_lbl)

	# Opponent avatar & name
	var opp_name = str(m.get("opponent_name", m.get("opponent", "حریف")))
	var opp_col := VBoxContainer.new()
	opp_col.add_theme_constant_override("separation", 2)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(opp_col)

	var opp_avatar := TextureRect.new()
	opp_avatar.custom_minimum_size = Vector2(54, 54)
	opp_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	opp_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var opp_img_id = int(m.get("opponent_image", 0))
	var a_path = "res://assets/icons/Avatars/%d.png" % opp_img_id
	if ResourceLoader.exists(a_path):
		opp_avatar.texture = load(a_path)
	else:
		opp_avatar.texture = preload("res://assets/icons/Avatars/0.png")
	opp_col.add_child(opp_avatar)

	var opp_lbl := Label.new()
	opp_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	opp_lbl.add_theme_font_size_override("font_size", 16)
	opp_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	opp_lbl.text = opp_name.substr(0, 12)
	opp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opp_col.add_child(opp_lbl)

	return panel


func _open_match_details(m: Dictionary) -> void:
	for c in details_container.get_children():
		c.queue_free()

	details_modal.visible = true
	var title := Label.new()
	title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title.text = "جزییات مسابقه: " + _get_game_fa_name(str(m.get("game_type", m.get("game", ""))))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_container.add_child(title)

	var rounds = m.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not rounds.is_empty():
		for i in range(rounds.size()):
			var r = rounds[i]
			var r_lbl := Label.new()
			r_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
			r_lbl.add_theme_font_size_override("font_size", 20)
			r_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
			r_lbl.text = "راند %s: برنده: %s" % [GameManager.to_fa_num(i + 1), str(r.get("winner", "ناشناخته"))]
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			details_container.add_child(r_lbl)
	else:
		var no_rounds := Label.new()
		no_rounds.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		no_rounds.add_theme_font_size_override("font_size", 20)
		no_rounds.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		no_rounds.text = "اطلاعات راندهای مجزا برای این بازی ثبت نشده است."
		no_rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		details_container.add_child(no_rounds)


func _load_stats_if_needed() -> void:
	if not _my_stats_data.is_empty():
		return
	for c in content_stats.get_children():
		c.queue_free()
	content_stats.add_child(CafeSocialTheme.make_loading_state("در حال دریافت آمار بازی‌ها..."))

	NetworkManager.api.get_my_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(content_stats):
			return
		for c in content_stats.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY:
			var res = data.get("result", data)
			if typeof(res) == TYPE_DICTIONARY:
				_my_stats_data = res
				GamesHistoryViewHelper.populate_games_history(content_stats, _my_stats_data)
				return
		content_stats.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"خطا در دریافت آمار",
			"لطفاً ارتباط اینترنت خود را بررسی و مجدداً تلاش کنید."
		))
	)


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
				"هنوز امتیازی برای این دسته ثبت نشده است."
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
	if list.is_empty():
		lb_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"اطلاعاتی یافت نشد",
			""
		))
		return

	var my_uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))

	for i in range(list.size()):
		var item: Dictionary = list[i]
		var rank = i + 1
		var item_uid = str(item.get("_id", item.get("user_id", item.get("id", ""))))
		var is_me = (item_uid == my_uid)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 92)
		var style = CafeSocialTheme.create_highlight_card_style(true) if is_me else CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14)
		card.add_theme_stylebox_override("panel", style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(hbox)

		# Rank number / Medal
		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(48, 0)
		rank_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		rank_lbl.add_theme_font_size_override("font_size", 28)
		rank_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if rank <= 3 else CafeSocialTheme.COL_WARM_CREAM)
		rank_lbl.text = GameManager.to_fa_num(rank)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(rank_lbl)

		# Avatar
		var avatar := TextureRect.new()
		avatar.custom_minimum_size = Vector2(56, 56)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var img_id = int(item.get("image", 0))
		var a_path = "res://assets/icons/Avatars/%d.png" % img_id
		avatar.texture = load(a_path) if ResourceLoader.exists(a_path) else preload("res://assets/icons/Avatars/0.png")
		hbox.add_child(avatar)

		# Name & details
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(col)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY if not is_me else CafeSocialTheme.COL_GOLD_BRIGHT)
		name_lbl.text = str(item.get("name", item.get("username", "بازیکن")))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(name_lbl)

		var val = item.get("score", item.get("win", 0))
		var unit = "امتیاز" if lb_type in ["score", "friends"] else "پیروزی"
		var val_lbl := Label.new()
		val_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		val_lbl.add_theme_font_size_override("font_size", 18)
		val_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
		val_lbl.text = "%s %s" % [GameManager.to_fa_num(val), unit]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(val_lbl)

		# Profile button
		if not is_me and lb_type != "clans":
			var btn_prof := CafeSocialTheme.make_button("پروفایل", "wood", Vector2(90, 44), 18)
			btn_prof.pressed.connect(func():
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(item, "", self)
			)
			hbox.add_child(btn_prof)

		lb_list_vbox.add_child(card)


func _get_game_fa_name(key: String) -> String:
	for g in GamesHistoryViewHelper.GAMES_LIST:
		if str(g.get("key", "")).to_lower() == key.to_lower() or str(g.get("id", "")).to_lower() == key.to_lower():
			return str(g.get("name_fa", key))
	return key
