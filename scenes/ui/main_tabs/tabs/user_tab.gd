extends Control

## Cafe Fekr — User Tab (Personal Player Palace)
## Sections:
## 1. My Profile (شناسنامه بازیکن، ماتریس کامل آمار بازی‌ها)
## 2. Cosmetics (انتخاب از میان ۷۲ آواتار اصیل با چیدمان وسط‌چین، دکمه ذخیره در پایین)
## 3. Privacy (تنظیمات بزرگ، خوانا و کاملاً کاربردی حریم خصوصی)
## 4. Notifications (مرکز اعلان‌های اختصاصی منتقل شده از بخش اجتماعی)
## 5. Account Settings (تنظیمات کامل صدا و موسیقی با اسلایدر، تغییر نام کاربری، ثبت موبایل و خروج ایمن)

signal change_username_requested()
signal phone_upgrade_requested()
signal logout_confirmed()

@onready var user_header: MarginContainer = $OuterMargin/MainPanel/InnerMargin/VBox/UserHeader

@onready var subtab_profile: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnProfile
@onready var subtab_cosmetics: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnCosmetics
@onready var subtab_privacy: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnPrivacy
@onready var subtab_notifs: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnNotifications
@onready var subtab_account: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnAccount

@onready var content_profile: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/ProfileContent
@onready var content_cosmetics: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/CosmeticsContent
@onready var content_privacy: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/PrivacyContent
@onready var content_notifs: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/NotificationsContent
@onready var content_account: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/AccountContent

@onready var toast_panel: PanelContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel
@onready var lbl_toast: Label = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel/LblToast

var active_subtab: String = "profile"
var _selected_avatar_id: int = -1
var _my_games_history_data: Dictionary = {}

func _ready() -> void:
	ActionVFXManager.apply_button_juice(subtab_profile, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_cosmetics, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_privacy, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_notifs, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_account, "tap_button")

	subtab_profile.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("profile")
	)
	subtab_cosmetics.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("cosmetics")
	)
	subtab_privacy.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("privacy")
	)
	subtab_notifs.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("notifs")
	)
	subtab_account.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("account")
	)

	if is_instance_valid(user_header):
		if user_header.has_signal("change_username_requested"):
			user_header.change_username_requested.connect(func(): change_username_requested.emit())
		if user_header.has_signal("login_requested"):
			user_header.login_requested.connect(func(): phone_upgrade_requested.emit())

	GameManager.user_logged_in.connect(func(_u): refresh_all())
	GameManager.user_logged_out.connect(func(): refresh_all())
	if GameManager.has_signal("user_data_updated"):
		GameManager.user_data_updated.connect(func(_u): refresh_all())

	switch_subtab("profile")


func switch_subtab(tab_name: String) -> void:
	active_subtab = tab_name

	_style_subnav_btn(subtab_profile, tab_name == "profile")
	_style_subnav_btn(subtab_cosmetics, tab_name == "cosmetics")
	_style_subnav_btn(subtab_privacy, tab_name == "privacy")
	_style_subnav_btn(subtab_notifs, tab_name == "notifs")
	_style_subnav_btn(subtab_account, tab_name == "account")

	content_profile.visible = (tab_name == "profile")
	content_cosmetics.visible = (tab_name == "cosmetics")
	content_privacy.visible = (tab_name == "privacy")
	content_notifs.visible = (tab_name == "notifs")
	content_account.visible = (tab_name == "account")

	match tab_name:
		"profile":
			_render_profile()
		"cosmetics":
			_render_cosmetics()
		"privacy":
			_render_privacy()
		"notifs":
			_render_notifs()
		"account":
			_render_account()


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


func refresh_all() -> void:
	if is_instance_valid(user_header) and user_header.has_method("update_ui"):
		user_header.update_ui()
	switch_subtab(active_subtab)


# ==============================================================================
# 1. PROFILE / MY GAMES STATISTICS MATRIX SECTION (No duplicate EXP/Level)
# ==============================================================================

func _render_profile() -> void:
	for c in content_profile.get_children():
		c.queue_free()

	if not _my_games_history_data.is_empty():
		GamesHistoryViewHelper.populate_games_history(content_profile, _my_games_history_data)
		return

	content_profile.add_child(CafeSocialTheme.make_loading_state("در حال دریافت آمار تفصیلی بازی‌های شما..."))

	NetworkManager.api.get_my_history(func(ok: bool, _c: int, data: Variant):
		if not is_instance_valid(content_profile):
			return
		for c in content_profile.get_children():
			c.queue_free()
		if ok and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res = data["result"]
			if typeof(res) == TYPE_DICTIONARY:
				_my_games_history_data = res
			else:
				_my_games_history_data = {}
			GamesHistoryViewHelper.populate_games_history(content_profile, _my_games_history_data)
		else:
			content_profile.add_child(CafeSocialTheme.make_empty_state(
				CafeSocialTheme.ICO_INFO,
				"خطا در دریافت آمار بازی‌ها",
				"لطفاً ارتباط شبکه خود را بررسی فرمایید."
			))
	)


# ==============================================================================
# 2. COSMETICS / AVATAR GALLERY (Centered, Bigger Icons, Save Button Down)
# ==============================================================================

func _render_cosmetics() -> void:
	for c in content_cosmetics.get_children():
		c.queue_free()

	_selected_avatar_id = GameManager.get_avatar_id()

	var tip_lbl := Label.new()
	tip_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	tip_lbl.add_theme_font_size_override("font_size", 20)
	tip_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	tip_lbl.text = "آواتار دلخواه خود را از گالری نفیس زیر انتخاب کنید و سپس دکمه «ثبت تغییرات» در پایین صفحه را فشار دهید:"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_cosmetics.add_child(tip_lbl)

	# Center wrapper for avatar grid
	var center_wrap := CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_cosmetics.add_child(center_wrap)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	center_wrap.add_child(grid)

	var avatar_buttons: Array[TextureButton] = []

	for i in range(72):
		var path = "res://assets/icons/Avatars/%d.png" % i
		if not ResourceLoader.exists(path):
			continue

		var p_btn := TextureButton.new()
		p_btn.custom_minimum_size = Vector2(108, 108)
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
			show_toast("آواتار شماره %s برگزیده شد. دکمه ثبت در پایین را بزنید." % GameManager.to_fa_num(current_i + 1), CafeSocialTheme.COL_GOLD_BRIGHT)
		)
		avatar_buttons.append(p_btn)
		grid.add_child(p_btn)

	# Save button DOWN below the icons
	var save_box := HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_cosmetics.add_child(save_box)

	var btn_save := CafeSocialTheme.make_button("ثبت تغییرات آواتار", "emerald", Vector2(320, 58), 24, CafeSocialTheme.ICO_CHECK)
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
# 3. PRIVACY SECTION (Bigger items & fully functional)
# ==============================================================================

func _render_privacy() -> void:
	for c in content_privacy.get_children():
		c.queue_free()

	var title := Label.new()
	title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title.text = "تنظیمات حریم خصوصی و امنیت اطلاعات"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_privacy.add_child(title)

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
		panel.custom_minimum_size = Vector2(0, 88)
		panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14))

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_theme_constant_override("margin_top", 12)
		m.add_theme_constant_override("margin_right", 20)
		m.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(m)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		m.add_child(h)

		var toggle := CheckButton.new()
		toggle.custom_minimum_size = Vector2(64, 48)
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
		lbl_title.add_theme_font_size_override("font_size", 24)
		lbl_title.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		lbl_title.text = item["label"]
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_col.add_child(lbl_title)

		var lbl_desc := Label.new()
		lbl_desc.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lbl_desc.add_theme_font_size_override("font_size", 16)
		lbl_desc.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		lbl_desc.text = item["desc"]
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_col.add_child(lbl_desc)

		content_privacy.add_child(panel)

	# Save Privacy Button
	var btn_save_priv := CafeSocialTheme.make_button("ذخیره تنظیمات حریم خصوصی", "gold", Vector2(340, 58), 24, CafeSocialTheme.ICO_CHECK)
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


# ==============================================================================
# 5. ACCOUNT SETTINGS & AUDIO CONTROLS
# ==============================================================================

func _render_account() -> void:
	for c in content_account.get_children():
		c.queue_free()

	# --- Sound & Music Settings Card ---
	var audio_card := PanelContainer.new()
	audio_card.custom_minimum_size = Vector2(0, 200)
	audio_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 16))
	content_account.add_child(audio_card)

	var am := MarginContainer.new()
	am.add_theme_constant_override("margin_left", 20)
	am.add_theme_constant_override("margin_top", 16)
	am.add_theme_constant_override("margin_right", 20)
	am.add_theme_constant_override("margin_bottom", 16)
	audio_card.add_child(am)

	var a_vbox := VBoxContainer.new()
	a_vbox.add_theme_constant_override("separation", 14)
	am.add_child(a_vbox)

	var a_title := Label.new()
	a_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	a_title.add_theme_font_size_override("font_size", 26)
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
	chk_music.button_pressed = AudioManager.is_music_enabled
	chk_music.focus_mode = Control.FOCUS_NONE
	music_row.add_child(chk_music)

	var music_slider := HSlider.new()
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.value = AudioManager.music_volume * 100.0
	music_row.add_child(music_slider)

	var lbl_music_val := Label.new()
	lbl_music_val.custom_minimum_size = Vector2(50, 0)
	lbl_music_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	lbl_music_val.add_theme_font_size_override("font_size", 18)
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
	chk_sfx.button_pressed = AudioManager.is_sound_enabled
	chk_sfx.focus_mode = Control.FOCUS_NONE
	sfx_row.add_child(chk_sfx)

	var sfx_slider := HSlider.new()
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.value = AudioManager.sfx_volume * 100.0
	sfx_row.add_child(sfx_slider)

	var lbl_sfx_val := Label.new()
	lbl_sfx_val.custom_minimum_size = Vector2(50, 0)
	lbl_sfx_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	lbl_sfx_val.add_theme_font_size_override("font_size", 18)
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

	# --- Change Username Card ---
	var un_card := PanelContainer.new()
	un_card.custom_minimum_size = Vector2(0, 96)
	un_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14))
	content_account.add_child(un_card)

	var um := MarginContainer.new()
	um.add_theme_constant_override("margin_left", 18)
	um.add_theme_constant_override("margin_right", 18)
	un_card.add_child(um)

	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 14)
	um.add_child(uh)

	var btn_edit_un := CafeSocialTheme.make_button("تغییر نام", "wood", Vector2(130, 48), 18)
	btn_edit_un.pressed.connect(func():
		AudioManager.sfx_tap()
		change_username_requested.emit()
	)
	uh.add_child(btn_edit_un)

	var uc := VBoxContainer.new()
	uc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uc.alignment = BoxContainer.ALIGNMENT_CENTER
	uh.add_child(uc)

	var ul1 := Label.new()
	ul1.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	ul1.add_theme_font_size_override("font_size", 24)
	ul1.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	ul1.text = "نام کاربری فعلی: " + GameManager.get_username()
	ul1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	uc.add_child(ul1)

	# --- Phone Registration Card ---
	var ph_card := PanelContainer.new()
	ph_card.custom_minimum_size = Vector2(0, 96)
	ph_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14))
	content_account.add_child(ph_card)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 18)
	pm.add_theme_constant_override("margin_right", 18)
	ph_card.add_child(pm)

	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 14)
	pm.add_child(ph)

	var btn_ph := CafeSocialTheme.make_button("ثبت شماره", "emerald", Vector2(130, 48), 18)
	btn_ph.pressed.connect(func():
		AudioManager.sfx_tap()
		phone_upgrade_requested.emit()
	)
	ph.add_child(btn_ph)

	var pc := VBoxContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(pc)

	var pl1 := Label.new()
	pl1.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	pl1.add_theme_font_size_override("font_size", 24)
	pl1.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	pl1.text = "ارتقا به حساب دائمی با شماره موبایل"
	pl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.add_child(pl1)

	var pl2 := Label.new()
	pl2.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	pl2.add_theme_font_size_override("font_size", 16)
	pl2.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	pl2.text = "برای بازیابی حساب در سایر دستگاه‌ها، شماره موبایل خود را ثبت فرمایید."
	pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.add_child(pl2)

	# --- Logout Button ---
	var btn_logout := CafeSocialTheme.make_button("خروج ایمن از حساب کاربری", "crimson", Vector2(300, 56), 22)
	btn_logout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_logout.pressed.connect(func():
		AudioManager.sfx_button()
		GameManager.logout()
		NetworkManager.disconnect_from_server()
		logout_confirmed.emit()
		show_toast("با موفقیت از حساب کاربری خارج شدید.", CafeSocialTheme.COL_GOLD_BRIGHT)
	)
	content_account.add_child(btn_logout)
