extends Control

## Cafe Fekr — Dedicated Notifications Page
## Opened from top-right Notifications icon button on PlayTab.
## Shares the Profile (user_bg) background via MainTabShell.

signal back_requested()
signal open_dm_requested(user_id: String, username: String)

var _body_vbox: VBoxContainer = null


func _ready() -> void:
	_build_ui()
	if NetworkManager.is_online and not NetworkManager.is_social_connected and GameManager.is_logged_in and not GameManager.token.is_empty():
		NetworkManager.connect_social_namespace()
	NetworkManager.social_notification_received.connect(_on_realtime_notification)
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
	root_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(root_vbox)

	# Top Bar: Back + Refresh on Left, Persian Title on Right
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_row)

	var btn_back: TextureButton = TextureButton.new()
	btn_back.name = "BtnBackNotifs"
	btn_back.texture_normal = CafeSocialTheme.TEX_CLOSE
	btn_back.custom_minimum_size = Vector2(58, 58)
	btn_back.ignore_texture_size = true
	btn_back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_back.focus_mode = Control.FOCUS_NONE
	btn_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_back.tooltip_text = "بستن"
	ActionVFXManager.apply_button_juice(btn_back, "tap_button")
	btn_back.pressed.connect(func():
		AudioManager.sfx_tap()
		back_requested.emit()
	)
	top_row.add_child(btn_back)

	var btn_refresh: TextureButton = TextureButton.new()
	btn_refresh.name = "BtnRefreshNotifs"
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
	title_lbl.text = "اعلان‌ها"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(title_lbl)

	# Content Body
	_body_vbox = VBoxContainer.new()
	_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_vbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(_body_vbox)


func refresh_all() -> void:
	if not is_instance_valid(_body_vbox):
		return
	for c in _body_vbox.get_children():
		c.queue_free()
	SocialNotificationsView.render(self, _body_vbox)


func _refresh_current_tab() -> void:
	refresh_all()


func _update_main_tab_buttons() -> void:
	pass


func open_direct_message_with(user_id: String, username: String) -> void:
	open_dm_requested.emit(user_id, username)


func _on_realtime_notification(_payload: Dictionary) -> void:
	if visible:
		refresh_all()
