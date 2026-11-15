extends Control

## Cafe Fekr — User Tab (Personal Player Palace)
## Sections:
## 1. My Profile (شناسنامه بازیکن، آمار کلی، کاپ‌ها، سطح و پیشرفت)
## 2. Customization (انتخاب از میان ۷۲ آواتار اصیل با بروزرسانی در سرور)
## 3. Privacy (تنظیمات تماشای بازی، وضعیت آنلاین و اعلانات)
## 4. Wallet & Store (موجودی سکه، دریافت سکه رایگان روزانه و ارتقا)
## 5. Account Settings (تغییر نام کاربری، ثبت شماره موبایل و خروج ایمن)

signal change_username_requested()
signal phone_upgrade_requested()
signal logout_confirmed()

@onready var subtab_profile: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnProfile
@onready var subtab_cosmetics: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnCosmetics
@onready var subtab_privacy: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnPrivacy
@onready var subtab_wallet: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnWallet
@onready var subtab_account: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnAccount

@onready var content_profile: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/ProfileContent
@onready var content_cosmetics: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/CosmeticsContent
@onready var content_privacy: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/PrivacyContent
@onready var content_wallet: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/WalletContent
@onready var content_account: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/AccountContent

@onready var toast_panel: PanelContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel
@onready var lbl_toast: Label = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel/LblToast

var active_subtab: String = "profile"
var _selected_avatar_id: int = -1

func _ready() -> void:
	ActionVFXManager.apply_button_juice(subtab_profile, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_cosmetics, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_privacy, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_wallet, "tap_button")
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
	subtab_wallet.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("wallet")
	)
	subtab_account.pressed.connect(func():
		AudioManager.sfx_tap()
		switch_subtab("account")
	)

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
	_style_subnav_btn(subtab_wallet, tab_name == "wallet")
	_style_subnav_btn(subtab_account, tab_name == "account")

	content_profile.visible = (tab_name == "profile")
	content_cosmetics.visible = (tab_name == "cosmetics")
	content_privacy.visible = (tab_name == "privacy")
	content_wallet.visible = (tab_name == "wallet")
	content_account.visible = (tab_name == "account")

	match tab_name:
		"profile":
			_render_profile()
		"cosmetics":
			_render_cosmetics()
		"privacy":
			_render_privacy()
		"wallet":
			_render_wallet()
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
	switch_subtab(active_subtab)


# ==============================================================================
# 1. PROFILE SECTION
# ==============================================================================

func _render_profile() -> void:
	for c in content_profile.get_children():
		c.queue_free()

	# Hero Card
	var hero_panel := PanelContainer.new()
	hero_panel.custom_minimum_size = Vector2(0, 160)
	hero_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	content_profile.add_child(hero_panel)

	var h_margin := MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 20)
	h_margin.add_theme_constant_override("margin_top", 16)
	h_margin.add_theme_constant_override("margin_right", 20)
	h_margin.add_theme_constant_override("margin_bottom", 16)
	hero_panel.add_child(h_margin)

	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 18)
	h_margin.add_child(h_row)

	var copy_btn := CafeSocialTheme.make_button("کپی شناسه", "wood", Vector2(110, 48), 18)
	copy_btn.pressed.connect(func():
		AudioManager.sfx_tap()
		var uid = str(GameManager.user_data.get("_id", GameManager.user_data.get("id", "")))
		if not uid.is_empty():
			DisplayServer.clipboard_set(uid)
			show_toast("شناسه بازیکن با موفقیت کپی شد.")
	)
	h_row.add_child(copy_btn)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	h_row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	name_lbl.text = GameManager.get_username()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(name_lbl)

	var xp = GameManager.get_xp()
	var lvl_info = GameManager.get_level_info(xp)
	var level = int(lvl_info.get("level", 1))

	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	sub_lbl.text = "سطح %s • امتیاز کل: %s • سکه: %s" % [
		GameManager.to_fa_num(level),
		GameManager.to_fa_num(GameManager.get_score()),
		GameManager.to_fa_num(GameManager.get_coins())
	]
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text_col.add_child(sub_lbl)

	# Avatar
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(80, 80)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img_id = int(GameManager.user_data.get("image", 0))
	var a_path = "res://assets/icons/Avatars/%d.png" % img_id
	avatar.texture = load(a_path) if ResourceLoader.exists(a_path) else preload("res://assets/icons/Avatars/0.png")
	h_row.add_child(avatar)

	# Stats Summary Grid
	var stats_title := Label.new()
	stats_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	stats_title.add_theme_font_size_override("font_size", 26)
	stats_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	stats_title.text = "آمار و افتخارات"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_profile.add_child(stats_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content_profile.add_child(grid)

	var stat_cards = [
		{"label": "تعداد پیروزی‌ها", "value": GameManager.to_fa_num(GameManager.user_data.get("win", 0)), "icon": CafeSocialTheme.ICO_WIN},
		{"label": "تعداد شکست‌ها", "value": GameManager.to_fa_num(GameManager.user_data.get("lose", 0)), "icon": CafeSocialTheme.ICO_LOSE},
		{"label": "موجودی سکه", "value": GameManager.to_fa_num(GameManager.get_coins()), "icon": CafeSocialTheme.ICO_COIN},
		{"label": "مجموع تجربه (XP)", "value": GameManager.to_fa_num(xp), "icon": CafeSocialTheme.ICO_EXP},
	]

	for sc in stat_cards:
		var c_panel := PanelContainer.new()
		c_panel.custom_minimum_size = Vector2(0, 96)
		c_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 14))

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 14)
		cm.add_theme_constant_override("margin_top", 10)
		cm.add_theme_constant_override("margin_right", 14)
		cm.add_theme_constant_override("margin_bottom", 10)
		c_panel.add_child(cm)

		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 12)
		cm.add_child(ch)

		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_child(cv)

		var vl := Label.new()
		vl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		vl.add_theme_font_size_override("font_size", 26)
		vl.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
		vl.text = sc["value"]
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cv.add_child(vl)

		var lb := Label.new()
		lb.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lb.add_theme_font_size_override("font_size", 16)
		lb.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		lb.text = sc["label"]
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cv.add_child(lb)

		var ci := TextureRect.new()
		ci.custom_minimum_size = Vector2(48, 48)
		ci.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.texture = sc["icon"]
		ch.add_child(ci)

		grid.add_child(c_panel)


# ==============================================================================
# 2. COSMETICS / AVATAR SELECTION
# ==============================================================================

func _render_cosmetics() -> void:
	for c in content_cosmetics.get_children():
		c.queue_free()

	_selected_avatar_id = GameManager.get_avatar_id()

	var tip_lbl := Label.new()
	tip_lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	tip_lbl.add_theme_font_size_override("font_size", 18)
	tip_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	tip_lbl.text = "آواتار مورد نظر خود را از گالری زیر انتخاب نمایید و دکمه «ثبت تغییرات» را بزنید:"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_cosmetics.add_child(tip_lbl)

	var btn_save := CafeSocialTheme.make_button("ثبت تغییرات آواتار", "emerald", Vector2(260, 54), 22)
	btn_save.pressed.connect(func():
		AudioManager.sfx_button()
		if _selected_avatar_id >= 0:
			NetworkManager.api.update_avatar(_selected_avatar_id, func(ok: bool, _c: int, _d: Variant):
				if ok:
					GameManager.user_data["image"] = _selected_avatar_id
					GameManager.user_data["avatar"] = _selected_avatar_id
					GameManager.set_session(GameManager.token, GameManager.user_data, true)
					show_toast("تصویر نمایه شما با موفقیت بروزرسانی شد.")
				else:
					show_toast("خطا در ذخیره تصویر نمایه.", CafeSocialTheme.COL_CRIMSON_TEXT)
			)
	)
	content_cosmetics.add_child(btn_save)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content_cosmetics.add_child(grid)

	for i in range(72):
		var path = "res://assets/icons/Avatars/%d.png" % i
		if not ResourceLoader.exists(path):
			continue

		var p_btn := TextureButton.new()
		p_btn.custom_minimum_size = Vector2(96, 96)
		p_btn.ignore_texture_size = true
		p_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		p_btn.texture_normal = load(path)
		p_btn.focus_mode = Control.FOCUS_NONE
		ActionVFXManager.apply_button_juice(p_btn, "tap_button")

		var current_i = i
		p_btn.pressed.connect(func():
			AudioManager.sfx_tap()
			_selected_avatar_id = current_i
			show_toast("آواتار شماره %s انتخاب شد. دکمه ثبت را بزنید." % GameManager.to_fa_num(current_i + 1), CafeSocialTheme.COL_GOLD_BRIGHT)
		)
		grid.add_child(p_btn)


# ==============================================================================
# 3. PRIVACY SECTION
# ==============================================================================

func _render_privacy() -> void:
	for c in content_privacy.get_children():
		c.queue_free()

	var title := Label.new()
	title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	title.text = "تنظیمات حریم خصوصی و دسترسی"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_privacy.add_child(title)

	var items = [
		{"key": "allow_spectators", "label": "اجازه تماشای زنده بازی‌ها توسط دیگران", "default": true},
		{"key": "show_online_status", "label": "نمایش وضعیت آنلاین به دوستان", "default": true},
		{"key": "allow_friend_requests", "label": "دریافت درخواست دوستی از سایر بازیکنان", "default": true},
		{"key": "allow_clan_invites", "label": "دریافت دعوت به عضویت در کلن‌ها", "default": true},
	]

	for item in items:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 68)
		panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(CafeSocialTheme.COL_WALNUT_CARD, CafeSocialTheme.COL_BRONZE_BORDER, 12))

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_right", 16)
		panel.add_child(m)

		var h := HBoxContainer.new()
		m.add_child(h)

		var toggle := CheckButton.new()
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.button_pressed = item["default"]
		toggle.toggled.connect(func(pressed: bool):
			AudioManager.sfx_tap()
			show_toast("تنظیمات با موفقیت ذخیره شد.")
		)
		h.add_child(toggle)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(spacer)

		var lbl := Label.new()
		lbl.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		lbl.text = item["label"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(lbl)

		content_privacy.add_child(panel)


# ==============================================================================
# 4. WALLET & STORE SECTION
# ==============================================================================

func _render_wallet() -> void:
	for c in content_wallet.get_children():
		c.queue_free()

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 160)
	card.add_theme_stylebox_override("panel", CafeSocialTheme.create_highlight_card_style(true))
	content_wallet.add_child(card)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_bottom", 16)
	card.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	m.add_child(h)

	var claim_btn := CafeSocialTheme.make_button("دریافت سکه رایگان", "emerald", Vector2(180, 54), 20)
	claim_btn.pressed.connect(func():
		AudioManager.sfx_button()
		NetworkManager.api.claim_free_coin(func(ok: bool, _c: int, data: Variant):
			if ok and typeof(data) == TYPE_DICTIONARY:
				var res = data.get("result", {})
				if typeof(res) == TYPE_DICTIONARY:
					var new_c = int(res.get("coins", GameManager.get_coins() + 50))
					GameManager.user_data["coins"] = new_c
					GameManager.set_session(GameManager.token, GameManager.user_data, true)
					show_toast("هدیه روزانه دریافت شد! ۵۰ سکه به کیف پول شما اضافه گردید.")
					_render_wallet()
					return
			show_toast("سکه روزانه قبلاً دریافت شده است. لطفاً بعداً مراجعه فرمایید.", CafeSocialTheme.COL_CRIMSON_TEXT)
		)
	)
	h.add_child(claim_btn)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)

	var l1 := Label.new()
	l1.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	l1.add_theme_font_size_override("font_size", 30)
	l1.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	l1.text = "%s سکه طلا" % GameManager.to_fa_num(GameManager.get_coins())
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(l1)

	var l2 := Label.new()
	l2.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	l2.add_theme_font_size_override("font_size", 17)
	l2.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	l2.text = "از سکه‌ها برای ورود به اتاق‌های اختصاصی و شرکت در لیگ‌های کافه فکر استفاده کنید."
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(l2)

	var coin_ico := TextureRect.new()
	coin_ico.custom_minimum_size = Vector2(72, 72)
	coin_ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_ico.texture = CafeSocialTheme.ICO_COIN
	h.add_child(coin_ico)


# ==============================================================================
# 5. ACCOUNT SETTINGS & LOGOUT
# ==============================================================================

func _render_account() -> void:
	for c in content_account.get_children():
		c.queue_free()

	# Change Username Card
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

	# Phone Registration Card (if guest or no phone)
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
	pl2.text = "برای بازیابی حساب در سایر دستگاه‌ها، شماره موبایل خود را ثبت کنید."
	pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.add_child(pl2)

	# Logout Button
	var btn_logout := CafeSocialTheme.make_button("خروج از حساب کاربری", "crimson", Vector2(260, 56), 22)
	btn_logout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_logout.pressed.connect(func():
		AudioManager.sfx_button()
		GameManager.logout()
		NetworkManager.disconnect_from_server()
		logout_confirmed.emit()
		show_toast("با موفقیت از حساب کاربری خارج شدید.", CafeSocialTheme.COL_GOLD_BRIGHT)
	)
	content_account.add_child(btn_logout)
