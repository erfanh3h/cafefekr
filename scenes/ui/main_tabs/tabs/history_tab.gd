extends Control

## Cafe Fekr — History Tab (Royal Player Record Book)
## Sections:
## 1. Match History (سوابق مسابقات اخیر با جزییات، راندهای تفکیک شده و کارت‌های بزرگ و کلیک‌پذیر)
## 2. Leaderboards (رتبه‌بندی امتیازی، بیشترین پیروزی، دوستان و اتحادها با نماد اختصاصی اتحاد)

signal user_profile_requested(user_data: Dictionary)

@onready var subtab_matches: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnMatches
@onready var subtab_leaderboard: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnLeaderboard

@onready var content_matches: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ContentScroll/VBox/MatchesContent
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

var active_section: String = "matches" # "matches" | "leaderboard"
var active_lb_tab: String = "score"    # "score" | "win" | "friends" | "clans"

var _history_matches: Array = []
var _leaderboard_cache: Dictionary = {}

func _ready() -> void:
	KenneyUI.style_button(btn_back_from_details, KenneyUI.COLOR_YELLOW)
	ActionVFXManager.apply_button_juice(subtab_matches, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_leaderboard, "tap_button")
	ActionVFXManager.apply_button_juice(btn_back_from_details, "tap_button")

	subtab_matches.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_section("matches")
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
	_style_subnav_btn(subtab_leaderboard, sec_name == "leaderboard")

	content_matches.visible = (sec_name == "matches")
	content_lb.visible = (sec_name == "leaderboard")

	match sec_name:
		"matches":
			_load_matches_if_needed()
		"leaderboard":
			switch_lb_tab(active_lb_tab)


func _style_subnav_btn(btn: Button, is_active: bool) -> void:
	if is_active:
		KenneyUI.style_button(btn, KenneyUI.COLOR_YELLOW)
		btn.add_theme_color_override("font_color", Color(0.18, 0.10, 0.02, 1.0))
	else:
		KenneyUI.style_button(btn, KenneyUI.COLOR_GREY)
		btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72, 0.85))


# ==============================================================================
# 1. MATCH HISTORY SECTION
# ==============================================================================

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
				"هنوز مسابقه‌ای ثبت نشده است",
				"با شروع رقابت در بخش «بازی»، سوابق مسابقات شما در اینجا نمایش داده می‌شود."
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
	panel.custom_minimum_size = Vector2(0, 140)
	panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 16))

	# Full card click button for match details
	var click_btn := Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(click_btn, "tap_button")
	click_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_match_details(m)
	)
	panel.add_child(click_btn)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Outcome determination
	var my_res = str(m.get("my_result", ""))
	var winner_id = str(m.get("winner", m.get("winner_id", "")))
	var is_draw = (my_res == "draw") or bool(m.get("is_draw", false)) or winner_id == "0" or winner_id == "draw"
	var is_win = (my_res == "win") or (winner_id == my_uid and not is_draw)

	var status_text = "پیروزی" if is_win else ("مساوی" if is_draw else "شکست")
	var status_col = CafeSocialTheme.COL_EMERALD_TEXT if is_win else (CafeSocialTheme.COL_GOLD_BRIGHT if is_draw else CafeSocialTheme.COL_CRIMSON_TEXT)

	# Left Action / Outcome Badge
	var outcome_box := VBoxContainer.new()
	outcome_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outcome_box.alignment = BoxContainer.ALIGNMENT_CENTER
	outcome_box.custom_minimum_size = Vector2(110, 0)
	hbox.add_child(outcome_box)

	var outcome_lbl := Label.new()
	outcome_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outcome_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	outcome_lbl.add_theme_font_size_override("font_size", 28)
	outcome_lbl.add_theme_color_override("font_color", status_col)
	outcome_lbl.text = status_text
	outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_box.add_child(outcome_lbl)

	var btn_view := CafeSocialTheme.make_button("جزییات", "wood", Vector2(96, 42), 18)
	btn_view.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_match_details(m)
	)
	outcome_box.add_child(btn_view)

	# Center info: Game Title and Match Type
	var center_col := VBoxContainer.new()
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 4)
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(center_col)

	var game_key = str(m.get("game_type", m.get("game", "بازی")))
	var game_name_fa = _get_game_fa_name(game_key)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title_lbl.text = game_name_fa
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center_col.add_child(title_lbl)

	var mode_name = str(m.get("game_score_type", "رتبه‌بندی"))
	var sub_lbl := Label.new()
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	sub_lbl.text = "حالت مسابقه: %s" % mode_name
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center_col.add_child(sub_lbl)

	# Opponent avatar & name (Interactive profile popup)
	var opp_name = str(m.get("opponent_name", ""))
	var opp_img_id = int(m.get("opponent_image", 0))
	var opp_id = str(m.get("opponent_id", ""))

	if opp_name.is_empty():
		var users_info = m.get("users_info", [])
		if typeof(users_info) == TYPE_ARRAY:
			for u in users_info:
				if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
					opp_name = str(u.get("username", u.get("name", "حریف")))
					opp_img_id = int(u.get("image", 0))
					opp_id = str(u.get("user_id", ""))
					break
	if opp_name.is_empty():
		opp_name = "حریف"

	var opp_btn := Button.new()
	opp_btn.custom_minimum_size = Vector2(100, 100)
	opp_btn.flat = true
	opp_btn.focus_mode = Control.FOCUS_NONE
	opp_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ActionVFXManager.apply_button_juice(opp_btn, "tap_button")
	opp_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		if not opp_id.is_empty() and not opp_id.begins_with("bot_"):
			UserProfileDialog.show_user({"_id": opp_id, "username": opp_name, "image": opp_img_id}, "", self)
		else:
			_open_match_details(m)
	)
	hbox.add_child(opp_btn)

	var opp_col := VBoxContainer.new()
	opp_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	opp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_col.add_theme_constant_override("separation", 4)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_btn.add_child(opp_col)

	var opp_avatar := TextureRect.new()
	opp_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_avatar.custom_minimum_size = Vector2(62, 62)
	opp_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	opp_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var a_path = "res://assets/icons/Avatars/%d.png" % opp_img_id
	if ResourceLoader.exists(a_path):
		opp_avatar.texture = load(a_path)
	else:
		opp_avatar.texture = preload("res://assets/icons/Avatars/0.png")
	opp_col.add_child(opp_avatar)

	var opp_lbl := Label.new()
	opp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	opp_lbl.add_theme_font_size_override("font_size", 16)
	opp_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
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
			var r_panel := PanelContainer.new()
			r_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))
			var r_m := MarginContainer.new()
			r_m.add_theme_constant_override("margin_left", 16)
			r_m.add_theme_constant_override("margin_top", 10)
			r_m.add_theme_constant_override("margin_right", 16)
			r_m.add_theme_constant_override("margin_bottom", 10)
			r_panel.add_child(r_m)

			var r_lbl := Label.new()
			r_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
			r_lbl.add_theme_font_size_override("font_size", 22)
			r_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
			r_lbl.text = "راند %s  •  شناسه برنده: %s" % [GameManager.to_fa_num(i + 1), str(r.get("winner_user_id", r.get("winner_id", "نامشخص")))]
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			r_m.add_child(r_lbl)
			details_container.add_child(r_panel)
	else:
		var no_rounds := Label.new()
		no_rounds.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		no_rounds.add_theme_font_size_override("font_size", 22)
		no_rounds.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		no_rounds.text = "اطلاعات راندهای مجزا برای این مسابقه ثبت نشده است."
		no_rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		details_container.add_child(no_rounds)


# ==============================================================================
# 2. LEADERBOARDS SECTION (Score | Win | Friends | Clans)
# ==============================================================================

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

	# Filter out current user from friends tab if returned
	var filtered_list: Array = []
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_uid = str(item.get("_id", item.get("user_id", item.get("id", ""))))
		if lb_type == "friends" and item_uid == my_uid:
			continue
		filtered_list.append(item)

	if filtered_list.is_empty():
		lb_list_vbox.add_child(CafeSocialTheme.make_empty_state(
			CafeSocialTheme.ICO_INFO,
			"اطلاعاتی یافت نشد",
			"رکوردی در این بخش وجود ندارد."
		))
		return

	for i in range(filtered_list.size()):
		var raw_item: Dictionary = filtered_list[i]
		var rank = i + 1

		# Unpack if nested user_data
		var item: Dictionary = raw_item
		if raw_item.has("user_data") and typeof(raw_item["user_data"]) == TYPE_DICTIONARY:
			item = raw_item["user_data"].duplicate()
			if raw_item.has("win"): item["win"] = raw_item["win"]
			if raw_item.has("score"): item["score"] = raw_item["score"]

		var item_uid = str(item.get("_id", item.get("user_id", item.get("id", ""))))
		var is_me = (item_uid == my_uid and lb_type != "clans")

		# Outer Card
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 120)
		var style = CafeSocialTheme.create_highlight_card_style(true) if is_me else CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 16)
		card.add_theme_stylebox_override("panel", style)

		# Make full row clickable with juice
		var click_btn := Button.new()
		click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_btn.flat = true
		click_btn.focus_mode = Control.FOCUS_NONE
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ActionVFXManager.apply_button_juice(click_btn, "tap_button")

		if lb_type == "clans":
			var c_id = str(item.get("_id", item.get("clan_id", item.get("id", ""))))
			click_btn.pressed.connect(func():
				AudioManager.sfx_tap()
				CafeSocialTheme.show_clan_details_modal(self, c_id, item)
			)
		else:
			click_btn.pressed.connect(func():
				AudioManager.sfx_tap()
				UserProfileDialog.show_user(item, "", self)
			)
		card.add_child(click_btn)

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 12)
		card.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 18)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(hbox)

		# Rank Medal / Number
		var rank_lbl := Label.new()
		rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank_lbl.custom_minimum_size = Vector2(56, 0)
		rank_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		rank_lbl.add_theme_font_size_override("font_size", 32)
		if rank == 1:
			rank_lbl.text = "🥇 ۱"
			rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		elif rank == 2:
			rank_lbl.text = "🥈 ۲"
			rank_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		elif rank == 3:
			rank_lbl.text = "🥉 ۳"
			rank_lbl.add_theme_color_override("font_color", Color(0.88, 0.65, 0.42))
		else:
			rank_lbl.text = GameManager.to_fa_num(rank)
			rank_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(rank_lbl)

		# Avatar or Clan Emblem
		var avatar := TextureRect.new()
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.custom_minimum_size = Vector2(64, 64)
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if lb_type == "clans":
			var emb_idx = int(item.get("emblem", item.get("badge", item.get("image", 0))))
			avatar.texture = CafeSocialTheme.get_clan_emblem_texture(emb_idx)
		else:
			var img_id = int(item.get("image", 0))
			var a_path = "res://assets/icons/Avatars/%d.png" % img_id
			avatar.texture = load(a_path) if ResourceLoader.exists(a_path) else preload("res://assets/icons/Avatars/0.png")
		hbox.add_child(avatar)

		# Title & Subtitle (Same structure for ALL rows)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(col)

		var name_lbl := Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		name_lbl.add_theme_font_size_override("font_size", 28)
		name_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY if not is_me else CafeSocialTheme.COL_GOLD_BRIGHT)
		name_lbl.text = str(item.get("name", item.get("username", "بازیکن")))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(name_lbl)

		var sub_text := ""
		if lb_type == "clans":
			var lvl = int(item.get("level", 1))
			var mem_cnt = int(item.get("member_count", item.get("members_count", 1)))
			sub_text = "سطح %s  •  %s عضو" % [GameManager.to_fa_num(lvl), GameManager.to_fa_num(mem_cnt)]
		else:
			var lvl = int(item.get("level", 1))
			sub_text = "سطح %s" % GameManager.to_fa_num(lvl)

		var sub_lbl := Label.new()
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		sub_lbl.add_theme_font_size_override("font_size", 18)
		sub_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		sub_lbl.text = sub_text
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(sub_lbl)

		# Right Stat Badge (Trophies or Wins)
		var val_col := VBoxContainer.new()
		val_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		val_col.alignment = BoxContainer.ALIGNMENT_CENTER
		val_col.custom_minimum_size = Vector2(130, 0)
		hbox.add_child(val_col)

		var val = item.get("score", item.get("win", 0))
		if lb_type == "win":
			val = item.get("win", item.get("score", 0))

		var unit = "امتیاز" if lb_type in ["score", "friends", "clans"] else "پیروزی"
		var val_lbl := Label.new()
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		val_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		val_lbl.add_theme_font_size_override("font_size", 26)
		val_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
		val_lbl.text = GameManager.to_fa_num(val)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_col.add_child(val_lbl)

		var unit_lbl := Label.new()
		unit_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		unit_lbl.add_theme_font_size_override("font_size", 16)
		unit_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
		unit_lbl.text = unit
		unit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_col.add_child(unit_lbl)

		lb_list_vbox.add_child(card)


func _get_game_fa_name(key: String) -> String:
	for g in GamesHistoryViewHelper.GAMES_LIST:
		if str(g.get("key", "")).to_lower() == key.to_lower() or str(g.get("id", "")).to_lower() == key.to_lower():
			return str(g.get("name_fa", key))
	return key
