extends Control

## Cafe Fekr — User Tab (Personal Player Palace)
## Sections:
## 1. Cosmetics (تصویر نمایه: گالری ۵ ستونه آواتارها)
## 2. Avatar Frames (قاب آواتار: گالری ۵ ستونه قاب‌ها)
## 3. Privacy & Audio (حریم خصوصی و تنظیمات صدا و موسیقی)
## (History & Notifications moved to dedicated pages opened from top-right of PlayTab)

signal change_username_requested()
signal phone_upgrade_requested()
signal logout_confirmed()
signal store_requested()
signal login_requested()
signal user_profile_requested(user_data: Dictionary)

@onready var user_header: MarginContainer = $OuterMargin/MainPanel/InnerMargin/VBox/UserHeader

@onready var subtab_cosmetics: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnCosmetics
@onready var subtab_frames: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnFrames
@onready var subtab_privacy: Button = $OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar/HBox/BtnPrivacy

@onready var content_cosmetics: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/CosmeticsContent
@onready var content_frames: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/FramesContent
@onready var content_privacy: VBoxContainer = $OuterMargin/MainPanel/InnerMargin/VBox/Scroll/ContentVBox/PrivacyContent

@onready var toast_panel: PanelContainer = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel
@onready var lbl_toast: Label = $OuterMargin/MainPanel/InnerMargin/VBox/ToastPanel/LblToast

var active_subtab: String = "cosmetics"
var _selected_avatar_id: int = -1
var _selected_frame_id: int = 1

var _font_hekayat: Font = preload("res://assets/fonts/hekayat.ttf")
var _font_vazir: Font = preload("res://assets/fonts/Vazir.ttf")

var _cosmetic_tile_styles: Dictionary = {}
var _cosmetic_check_style: StyleBoxFlat = null
var _cosmetic_lock_style: StyleBoxFlat = null
var _cosmetics_built: bool = false
var _avatar_entries: Array[Dictionary] = []
var _frames_built: bool = false
var _frame_entries: Array[Dictionary] = []


func _ready() -> void:
	var subnav_bar: PanelContainer = get_node_or_null("OuterMargin/MainPanel/InnerMargin/VBox/SubnavBar") as PanelContainer
	if is_instance_valid(subnav_bar):
		subnav_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	ActionVFXManager.apply_button_juice(subtab_cosmetics, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_frames, "tap_button")
	ActionVFXManager.apply_button_juice(subtab_privacy, "tap_button")

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

	switch_subtab("cosmetics")


func switch_subtab(tab_name: String) -> void:
	var resolved: String = tab_name if tab_name in ["cosmetics", "frames", "privacy"] else "cosmetics"
	active_subtab = resolved

	_style_subnav_btn(subtab_cosmetics, resolved == "cosmetics")
	_style_subnav_btn(subtab_frames, resolved == "frames")
	_style_subnav_btn(subtab_privacy, resolved == "privacy")

	content_cosmetics.visible = (resolved == "cosmetics")
	content_frames.visible = (resolved == "frames")
	content_privacy.visible = (resolved == "privacy")

	match resolved:
		"cosmetics":
			_render_cosmetics()
		"frames":
			_render_frames()
		"privacy":
			_render_privacy()


func _style_subnav_btn(btn: Button, is_act: bool, font_size: int = 20) -> void:
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
# 1. COSMETICS / AVATAR & FRAME TILE HELPERS
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
	var key: String = "locked" if is_locked else ("selected" if is_selected else "normal")
	if _cosmetic_tile_styles.has(key):
		return _cosmetic_tile_styles[key] as StyleBoxFlat
	var sb: StyleBoxFlat = StyleBoxFlat.new()
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
		sb.shadow_size = 0 if ResponsiveUI.is_mobile() else 10
		sb.shadow_offset = Vector2(0, 2)
	else:
		sb.bg_color = Color(0.14, 0.08, 0.05, 0.92)
		sb.border_color = Color(0.38, 0.25, 0.14, 0.85)
		sb.set_border_width_all(1)
	_cosmetic_tile_styles[key] = sb
	return sb


func _get_cosmetic_check_style() -> StyleBoxFlat:
	if _cosmetic_check_style != null:
		return _cosmetic_check_style
	var chk_sb: StyleBoxFlat = StyleBoxFlat.new()
	chk_sb.bg_color = Color("#1F7A3E")
	chk_sb.border_color = Color("#FFD86B")
	chk_sb.set_border_width_all(2)
	chk_sb.set_corner_radius_all(13)
	_cosmetic_check_style = chk_sb
	return chk_sb


func _get_cosmetic_lock_style() -> StyleBoxFlat:
	if _cosmetic_lock_style != null:
		return _cosmetic_lock_style
	var lck_sb: StyleBoxFlat = StyleBoxFlat.new()
	lck_sb.bg_color = Color(0.11, 0.06, 0.03, 0.94)
	lck_sb.border_color = Color("#A87C44")
	lck_sb.set_border_width_all(1)
	lck_sb.set_corner_radius_all(14)
	_cosmetic_lock_style = lck_sb
	return lck_sb


func _create_cosmetic_tile(item_id: int, tex: Texture2D, is_selected: bool, is_locked: bool, on_tap: Callable) -> Dictionary:
	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = Vector2(108, 108)
	tile.pivot_offset = Vector2(54, 54)

	var inner: Control = Control.new()
	inner.custom_minimum_size = Vector2(96, 96)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(inner)

	var btn: TextureButton = TextureButton.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_normal = tex
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
	if not is_locked:
		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.set_meta("_juiced", true)
	btn.pressed.connect(on_tap)
	inner.add_child(btn)

	var check_badge: PanelContainer = PanelContainer.new()
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
	check_badge.add_theme_stylebox_override("panel", _get_cosmetic_check_style())

	var lbl_chk: Label = Label.new()
	lbl_chk.text = "✓"
	lbl_chk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_chk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_chk.add_theme_font_override("font", _font_vazir)
	ResponsiveUI.apply_text(lbl_chk, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	lbl_chk.add_theme_color_override("font_color", Color(1.0, 0.99, 0.94, 1.0))
	lbl_chk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_badge.add_child(lbl_chk)
	inner.add_child(check_badge)

	var lock_badge: PanelContainer = PanelContainer.new()
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
	lock_badge.add_theme_stylebox_override("panel", _get_cosmetic_lock_style())

	var lbl_lck: Label = Label.new()
	lbl_lck.text = "🔒"
	lbl_lck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ResponsiveUI.apply_text(lbl_lck, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	lbl_lck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_badge.add_child(lbl_lck)
	inner.add_child(lock_badge)

	var entry: Dictionary = {
		"id": item_id,
		"tile": tile,
		"btn": btn,
		"check": check_badge,
		"lock": lock_badge,
		"locked": is_locked,
		"active": false
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
	entry["active"] = active
	tile.add_theme_stylebox_override("panel", _make_cosmetic_tile_style(active, is_locked))
	tile.z_index = 2 if active else 0
	if is_instance_valid(check_badge):
		check_badge.visible = active
	if is_instance_valid(lock_badge):
		lock_badge.visible = is_locked
	if is_instance_valid(btn):
		btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
		if not is_locked and not btn.has_meta("_juiced"):
			ActionVFXManager.apply_button_juice(btn, "tap_button")
			btn.set_meta("_juiced", true)
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


func _sync_cosmetic_entries(entries: Array[Dictionary], kind: String, selected_id: int) -> void:
	for entry in entries:
		var item_id: int = int(entry["id"])
		var locked_now: bool = _is_cosmetic_locked(kind, item_id)
		var active_now: bool = (item_id == selected_id) and not locked_now
		if bool(entry["locked"]) != locked_now or bool(entry["active"]) != active_now:
			entry["locked"] = locked_now
			_apply_cosmetic_tile_state(entry, item_id == selected_id, false)


func _render_cosmetics() -> void:
	_selected_avatar_id = GameManager.get_avatar_id()
	if _cosmetics_built and not _avatar_entries.is_empty():
		_sync_cosmetic_entries(_avatar_entries, "avatar", _selected_avatar_id)
		return

	for c in content_cosmetics.get_children():
		c.queue_free()
	_avatar_entries.clear()

	var center_wrap: CenterContainer = CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_cosmetics.add_child(center_wrap)

	var grid_margin: MarginContainer = MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_top", 8)
	grid_margin.add_theme_constant_override("margin_bottom", 8)
	center_wrap.add_child(grid_margin)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(grid)

	for i in range(72):
		var path: String = "res://assets/icons/Avatars/%d.png" % i
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = CafeSocialTheme.get_avatar_texture(i)
		if tex == null:
			continue

		var current_i: int = i
		var is_locked: bool = _is_cosmetic_locked("avatar", current_i)
		var entry_ref: Array[Dictionary] = []
		var on_tap: Callable = func():
			var cur_entry: Dictionary = entry_ref[0]
			if bool(cur_entry["locked"]):
				AudioManager.sfx_tap()
				show_toast("این تصویر نمایه هنوز آزاد نشده است.", CafeSocialTheme.COL_GOLD_ANTIQUE)
				return
			AudioManager.sfx_tap()
			if _selected_avatar_id == current_i and bool(cur_entry["active"]):
				return
			_selected_avatar_id = current_i
			for other in _avatar_entries:
				var should_select: bool = (other == cur_entry)
				if bool(other["active"]) != should_select:
					_apply_cosmetic_tile_state(other, should_select, true)

		var entry: Dictionary = _create_cosmetic_tile(current_i, tex, current_i == _selected_avatar_id, is_locked, on_tap)
		entry_ref.append(entry)
		_avatar_entries.append(entry)
		grid.add_child(entry["tile"] as PanelContainer)

	var save_box: HBoxContainer = HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_cosmetics.add_child(save_box)

	var btn_save: TextureButton = TextureButton.new()
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

	var av_spacer: Control = Control.new()
	av_spacer.custom_minimum_size = Vector2(0, 44)
	av_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_cosmetics.add_child(av_spacer)
	_cosmetics_built = true


# ==============================================================================
# 2. AVATAR FRAMES GALLERY
# ==============================================================================

func _render_frames() -> void:
	_selected_frame_id = GameManager.get_frame_id()
	if _frames_built and not _frame_entries.is_empty():
		_sync_cosmetic_entries(_frame_entries, "frame", _selected_frame_id)
		return

	for c in content_frames.get_children():
		c.queue_free()
	_frame_entries.clear()

	var center_wrap: CenterContainer = CenterContainer.new()
	center_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_frames.add_child(center_wrap)

	var grid_margin: MarginContainer = MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_top", 8)
	grid_margin.add_theme_constant_override("margin_bottom", 8)
	center_wrap.add_child(grid_margin)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(grid)

	for fid in range(1, 21):
		var f_tex: Texture2D = CafeSocialTheme.get_frame_texture(fid)
		if f_tex == null:
			continue

		var cur_fid: int = fid
		var is_locked: bool = _is_cosmetic_locked("frame", cur_fid)
		var entry_ref: Array[Dictionary] = []
		var on_tap: Callable = func():
			var cur_entry: Dictionary = entry_ref[0]
			if bool(cur_entry["locked"]):
				AudioManager.sfx_tap()
				show_toast("این قاب آواتار هنوز آزاد نشده است.", CafeSocialTheme.COL_GOLD_ANTIQUE)
				return
			AudioManager.sfx_tap()
			if _selected_frame_id == cur_fid and bool(cur_entry["active"]):
				return
			_selected_frame_id = cur_fid
			for other in _frame_entries:
				var should_select: bool = (other == cur_entry)
				if bool(other["active"]) != should_select:
					_apply_cosmetic_tile_state(other, should_select, true)

		var entry: Dictionary = _create_cosmetic_tile(cur_fid, f_tex, cur_fid == _selected_frame_id, is_locked, on_tap)
		entry_ref.append(entry)
		_frame_entries.append(entry)
		grid.add_child(entry["tile"] as PanelContainer)

	var save_box: HBoxContainer = HBoxContainer.new()
	save_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_frames.add_child(save_box)

	var btn_save: TextureButton = TextureButton.new()
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

	var fr_spacer: Control = Control.new()
	fr_spacer.custom_minimum_size = Vector2(0, 44)
	fr_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_frames.add_child(fr_spacer)
	_frames_built = true


# ==============================================================================
# 3. PRIVACY & SOUND/MUSIC SECTION
# ==============================================================================

func _build_aligned_audio_row(
	label_text: String,
	initial_enabled: bool,
	initial_volume_pct: float,
	on_toggle: Callable,
	on_volume_change: Callable
) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var chk: CheckButton = CheckButton.new()
	chk.text = ""
	chk.custom_minimum_size = Vector2(64, 42)
	chk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chk.button_pressed = initial_enabled
	CafeSocialTheme.style_parlor_check_button(chk)
	row.add_child(chk)

	var lbl_name: Label = Label.new()
	lbl_name.custom_minimum_size = Vector2(124, 0)
	lbl_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_name.text = label_text
	lbl_name.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	ResponsiveUI.apply_text(lbl_name, UITypography.Role.TITLE_SM, {"min_px": 18, "max_px": 26})
	lbl_name.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	row.add_child(lbl_name)

	var slider: HSlider = HSlider.new()
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

	var lbl_val: Label = Label.new()
	lbl_val.custom_minimum_size = Vector2(54, 0)
	lbl_val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_val.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
	ResponsiveUI.apply_text(lbl_val, UITypography.Role.BODY, {"min_px": 16, "max_px": 22})
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

	var audio_margin: MarginContainer = MarginContainer.new()
	audio_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_margin.add_theme_constant_override("margin_left", 10)
	audio_margin.add_theme_constant_override("margin_right", 10)
	content_privacy.add_child(audio_margin)

	var audio_card: PanelContainer = PanelContainer.new()
	audio_card.custom_minimum_size = Vector2(0, 196)
	audio_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_panel_box_style(44.0, 24.0))
	audio_margin.add_child(audio_card)

	var a_vbox: VBoxContainer = VBoxContainer.new()
	a_vbox.add_theme_constant_override("separation", 14)
	audio_card.add_child(a_vbox)

	var a_title: Label = Label.new()
	a_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	ResponsiveUI.apply_text(a_title, UITypography.Role.TITLE, {"min_px": 20, "max_px": 30})
	a_title.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	a_title.text = "تنظیمات صدا و موسیقی کافه فکر"
	a_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a_vbox.add_child(a_title)

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

	var p_title: Label = Label.new()
	p_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	ResponsiveUI.apply_text(p_title, UITypography.Role.TITLE, {"min_px": 20, "max_px": 30})
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

		var item_margin: MarginContainer = MarginContainer.new()
		item_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_margin.add_theme_constant_override("margin_left", 10)
		item_margin.add_theme_constant_override("margin_right", 10)

		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 108)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", CafeSocialTheme.create_item_frame_style(46.0, 14.0))
		item_margin.add_child(panel)

		var h: HBoxContainer = HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		panel.add_child(h)

		var toggle: CheckButton = CheckButton.new()
		toggle.text = ""
		toggle.custom_minimum_size = Vector2(64, 42)
		toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		toggle.button_pressed = current_val
		CafeSocialTheme.style_parlor_check_button(toggle)
		toggle.toggled.connect(func(_p: bool): AudioManager.sfx_tap())
		h.add_child(toggle)
		toggle_map[key] = toggle

		var v_col: VBoxContainer = VBoxContainer.new()
		v_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v_col.add_theme_constant_override("separation", 2)
		v_col.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v_col)

		var lbl_title: Label = Label.new()
		lbl_title.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
		ResponsiveUI.apply_text(lbl_title, UITypography.Role.TITLE_SM, {"min_px": 18, "max_px": 26, "wrap": true})
		lbl_title.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
		lbl_title.text = str(item["label"])
		lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_col.add_child(lbl_title)

		var lbl_desc: Label = Label.new()
		lbl_desc.add_theme_font_override("font", CafeSocialTheme.FONT_BODY)
		ResponsiveUI.apply_text(lbl_desc, UITypography.Role.BODY_SM, {"min_px": 15, "max_px": 21, "wrap": true})
		lbl_desc.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
		lbl_desc.text = str(item["desc"])
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_col.add_child(lbl_desc)

		content_privacy.add_child(item_margin)

	var save_priv_box: HBoxContainer = HBoxContainer.new()
	save_priv_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_privacy.add_child(save_priv_box)

	var btn_save_priv: TextureButton = TextureButton.new()
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

	var bottom_spacer: Control = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 44)
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_privacy.add_child(bottom_spacer)
