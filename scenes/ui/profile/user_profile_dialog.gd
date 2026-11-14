extends Control

# User Profile Dialog
# Shows detailed player profile (avatar, username, role, level, cups/score, coins, ID)
# Used both from main menu (user_header) and in-game HUD (tapping player avatars)

signal closed()
signal change_username_requested()

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var img_avatar: TextureRect = $CenterContainer/Panel/Margin/VBox/AvatarBox/Plaque/Avatar
@onready var lbl_username: Label = $CenterContainer/Panel/Margin/VBox/LblUsername
@onready var lbl_role: Label = $CenterContainer/Panel/Margin/VBox/LblRole
@onready var lbl_level: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/LevelCard/LevelVBox/LblLevel
@onready var lbl_score: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/ScoreCard/ScoreVBox/LblScore
@onready var coins_card: PanelContainer = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard
@onready var lbl_coins: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoinsCard/LblCoins
@onready var btn_copy_id: Button = $CenterContainer/Panel/Margin/VBox/UserIdBox/BtnCopyId
@onready var btn_close_top: TextureButton = $CenterContainer/Panel/Margin/VBox/TopRow/BtnCloseTop
@onready var scroll_stats: ScrollContainer = $CenterContainer/Panel/Margin/VBox/ScrollStats
@onready var lbl_stats_loading: Label = $CenterContainer/Panel/Margin/VBox/ScrollStats/StatsVBox/LblStatsLoading
@onready var games_history_container: VBoxContainer = $CenterContainer/Panel/Margin/VBox/ScrollStats/StatsVBox/GamesHistoryContainer

var _current_user_id: String = ""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(btn_copy_id):
		btn_copy_id.focus_mode = Control.FOCUS_NONE
	if is_instance_valid(btn_close_top):
		btn_close_top.focus_mode = Control.FOCUS_NONE
	coins_card.visible = false
	KenneyUI.style_button(btn_copy_id, KenneyUI.COLOR_BLUE)
	
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	$DimOverlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	
	btn_copy_id.pressed.connect(func():
		AudioManager.sfx_tap()
		if not _current_user_id.is_empty():
			DisplayServer.clipboard_set(_current_user_id)
			btn_copy_id.text = "کپی شد"
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(btn_copy_id):
					btn_copy_id.text = "کپی شناسه"
			)
	)

func open_for_user(user_dict: Dictionary, role_text: String = "") -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	var uname = user_dict.get("name", user_dict.get("username", "بازیکن کافه فکر"))
	lbl_username.text = uname
	
	if role_text.is_empty():
		lbl_role.visible = false
	else:
		lbl_role.visible = true
		lbl_role.text = role_text
		if role_text.contains("قرمز") or role_text.contains("۱"):
			lbl_role.add_theme_color_override("font_color", Color(1.0, 0.45, 0.48))
		elif role_text.contains("آبی") or role_text.contains("۲"):
			lbl_role.add_theme_color_override("font_color", Color(0.45, 0.78, 1.0))
		else:
			lbl_role.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
			
	var av_id = user_dict.get("image", user_dict.get("user_image", 0))
	var av_path = "res://assets/icons/Avatars/%d.png" % int(av_id)
	if ResourceLoader.exists(av_path):
		img_avatar.texture = load(av_path)
		
	var score_val = user_dict.get("score", user_dict.get("user_score", 0))
	lbl_score.text = GameManager.to_fa_num(int(score_val))
	
	var coin_val = user_dict.get("coin", user_dict.get("user_coin", user_dict.get("coins", 0)))
	lbl_coins.text = "💰 %s" % GameManager.to_fa_num(int(coin_val))
	
	var xp_val = int(float(user_dict.get("xp", user_dict.get("user_xp", 0))))
	var level_val = 1
	if xp_val > 0:
		level_val = GameManager.calculate_level(xp_val)
	else:
		level_val = int(user_dict.get("level", 1))
	lbl_level.text = GameManager.to_fa_num(level_val)
	
	_current_user_id = str(user_dict.get("_id", user_dict.get("id", user_dict.get("user_id", ""))))
	btn_copy_id.text = "📋 کپی شناسه"

	var is_self = (_current_user_id == str(GameManager.get_user_id()) or _current_user_id.is_empty())
	var vbox_root = $CenterContainer/Panel/Margin/VBox
	var btn_edit_name = vbox_root.get_node_or_null("BtnEditProfileUsername") as Button
	if is_self:
		if not is_instance_valid(btn_edit_name):
			btn_edit_name = Button.new()
			btn_edit_name.name = "BtnEditProfileUsername"
			btn_edit_name.text = "✏️ تغییر نام کاربری"
			btn_edit_name.custom_minimum_size = Vector2(340, 72)
			btn_edit_name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn_edit_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
			btn_edit_name.add_theme_font_size_override("font_size", 28)
			KenneyUI.style_button(btn_edit_name, KenneyUI.COLOR_YELLOW)
			btn_edit_name.pressed.connect(func():
				AudioManager.sfx_tap()
				close()
				change_username_requested.emit()
			)
			# Insert before ScrollStats if valid
			if is_instance_valid(scroll_stats):
				vbox_root.add_child(btn_edit_name)
				vbox_root.move_child(btn_edit_name, scroll_stats.get_index())
			else:
				vbox_root.add_child(btn_edit_name)
		btn_edit_name.visible = true
	elif is_instance_valid(btn_edit_name):
		btn_edit_name.visible = false

	# === Social Actions & Public Profile Enrichment ===
	_setup_social_profile_actions(vbox_root, is_self, uname)

	# === Load Games History & Statistics for this player ===
	_load_player_history(user_dict)
	
	# Entrance VFX Animation
	ActionVFXManager.animate_dialog_open(panel, self, true)

func _load_player_history(user_dict: Dictionary) -> void:
	if not is_instance_valid(games_history_container):
		return

	for child in games_history_container.get_children():
		child.queue_free()

	if user_dict.has("history") and typeof(user_dict["history"]) == TYPE_DICTIONARY:
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		GamesHistoryViewHelper.populate_games_history(games_history_container, user_dict["history"])
		return

	if _current_user_id.is_empty() or _current_user_id.begins_with("bot_") or _current_user_id.begins_with("test_bot"):
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		GamesHistoryViewHelper.populate_games_history(games_history_container, {})
		return

	if is_instance_valid(lbl_stats_loading):
		lbl_stats_loading.visible = true
		lbl_stats_loading.text = "در حال دریافت آمار بازی‌ها..."

	var req_uid = _current_user_id
	NetworkManager.api.get_user_data(req_uid, func(success: bool, _code: int, data: Variant):
		if not is_instance_valid(self) or not visible or _current_user_id != req_uid:
			return
		if is_instance_valid(lbl_stats_loading):
			lbl_stats_loading.visible = false
		if success and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res = data["result"]
			var hist_dict = {}
			if typeof(res) == TYPE_DICTIONARY and res.has("history") and typeof(res["history"]) == TYPE_DICTIONARY:
				hist_dict = res["history"]
			GamesHistoryViewHelper.populate_games_history(games_history_container, hist_dict)
		else:
			if is_instance_valid(lbl_stats_loading):
				lbl_stats_loading.text = "آمار بازی‌ها در دسترس نیست"
				lbl_stats_loading.visible = true
	)

func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ActionVFXManager.animate_dialog_close(panel, self, func():
		visible = false
		closed.emit()
	)

func _setup_social_profile_actions(vbox_root: VBoxContainer, is_self: bool, uname: String) -> void:
	var old_box = vbox_root.get_node_or_null("SocialProfileBox")
	if is_instance_valid(old_box):
		old_box.queue_free()
	if _current_user_id.is_empty() or _current_user_id.begins_with("bot_") or _current_user_id.begins_with("test_bot"):
		return

	var social_box = VBoxContainer.new()
	social_box.name = "SocialProfileBox"
	social_box.add_theme_constant_override("separation", 8)
	if is_instance_valid(scroll_stats):
		vbox_root.add_child(social_box)
		vbox_root.move_child(social_box, scroll_stats.get_index())
	else:
		vbox_root.add_child(social_box)

	var lbl_clan_tier = Label.new()
	lbl_clan_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_clan_tier.add_theme_font_override("font", preload("res://assets/fonts/Vazir.ttf"))
	lbl_clan_tier.add_theme_font_size_override("font_size", 22)
	lbl_clan_tier.add_theme_color_override("font_color", Color(0.55, 0.92, 0.68))
	lbl_clan_tier.autowrap_mode = TextServer.AUTOWRAP_OFF
	social_box.add_child(lbl_clan_tier)

	if not is_self:
		var act_row = HBoxContainer.new()
		act_row.alignment = BoxContainer.ALIGNMENT_CENTER
		act_row.add_theme_constant_override("separation", 8)
		social_box.add_child(act_row)

		var make_sbtn = func(txt: String, col_bg: Color) -> Button:
			var b = Button.new()
			b.text = txt
			b.custom_minimum_size = Vector2(130, 48)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_override("font", preload("res://assets/fonts/Vazir.ttf"))
			b.add_theme_font_size_override("font_size", 20)
			var st = StyleBoxFlat.new()
			st.bg_color = col_bg
			st.border_color = col_bg.lightened(0.35)
			st.set_border_width_all(2)
			st.set_corner_radius_all(12)
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)
			b.add_theme_stylebox_override("pressed", st)
			return b

		var btn_add_f = make_sbtn.call("➕ افزودن دوست", Color(0.18, 0.46, 0.26))
		btn_add_f.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.send_friend_request(_current_user_id, "", func(ok: bool, _c: int, _d: Variant):
				btn_add_f.text = "✓ ارسال شد" if ok else "ارسال شده"
				btn_add_f.disabled = true
			)
		)
		act_row.add_child(btn_add_f)

		var btn_dm = make_sbtn.call("💬 پیام خصوصی", Color(0.18, 0.36, 0.54))
		btn_dm.pressed.connect(func():
			AudioManager.sfx_tap()
			var target_uid = _current_user_id
			close()
			var s_dlg = get_tree().root.find_child("SocialDialog", true, false)
			if s_dlg and s_dlg.has_method("open_direct_message_with"):
				s_dlg.open_direct_message_with(target_uid, uname)
		)
		act_row.add_child(btn_dm)

		var btn_clan_inv = make_sbtn.call("🛡️ دعوت به کلن", Color(0.56, 0.38, 0.12))
		btn_clan_inv.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.invite_to_clan(_current_user_id, func(ok: bool, _c: int, _d: Variant):
				btn_clan_inv.text = "✓ دعوت شد" if ok else "خطا"
			)
		)
		act_row.add_child(btn_clan_inv)

		var btn_rep = make_sbtn.call("🚩 گزارش", Color(0.46, 0.16, 0.16))
		btn_rep.custom_minimum_size = Vector2(105, 48)
		btn_rep.pressed.connect(func():
			AudioManager.sfx_tap()
			NetworkManager.api.report_social_target("user", _current_user_id, "inappropriate_behavior", "Reported from profile", func(_ok: bool, _c: int, _d: Variant):
				btn_rep.text = "✓ ثبت شد"
				btn_rep.disabled = true
			)
		)
		act_row.add_child(btn_rep)

	var req_uid = _current_user_id
	NetworkManager.api.get_public_profile(req_uid, func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(lbl_clan_tier) or _current_user_id != req_uid:
			return
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("result")) == TYPE_DICTIONARY:
			var prof: Dictionary = data["result"]
			var tier: Dictionary = prof.get("tier", {}) if typeof(prof.get("tier")) == TYPE_DICTIONARY else {}
			var clan_d: Dictionary = prof.get("clan", {}) if typeof(prof.get("clan")) == TYPE_DICTIONARY else {}
			var tier_txt = "%s %s" % [str(tier.get("icon", "🎖️")), str(tier.get("title_fa", "رقابتی"))]
			var clan_txt = "🛡️ کلن: %s [%s]" % [str(clan_d.get("name", "")), str(clan_d.get("tag", ""))] if not clan_d.is_empty() else "بدون کلن"
			lbl_clan_tier.text = "%s   |   %s" % [tier_txt, clan_txt]
	)
