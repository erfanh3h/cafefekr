class_name ProfileHeader
extends PanelContainer

## Cafe Fekr — Reusable Profile Header Component
## Displays large avatar with gold frame, username, online/offline status,
## copyable user ID, title/tier badges, personal status quote, and clan info.

signal copy_id_requested(user_id: String)
signal view_clan_requested(clan_id: String, clan_data: Dictionary)

var _avatar_holder: Control
var _lbl_username: Label
var _lbl_role: Label
var _status_badge: Control
var _tags_row: HBoxContainer
var _id_row: HBoxContainer
var _lbl_id: Label
var _btn_copy: Button
var _clan_box: Control
var _lbl_status_msg: Label

var _current_user_id: String = ""
var _current_clan_data: Dictionary = {}


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	# Outer plaque styling: dark walnut with warm bronze/gold filigree border
	add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 18.0, 16.0))

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Top Hero Row: Info Column (Left) + Avatar Medallion (Right) - Persian RTL Layout
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 14)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(hero_row)

	# --- Left Info Column ---
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 4)
	hero_row.add_child(info_col)

	# Row 1: Tappable Clan Pill (Top-Left, replaces status image) + Username (Top-Right)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	name_row.add_theme_constant_override("separation", 8)
	info_col.add_child(name_row)

	_clan_box = HBoxContainer.new()
	_clan_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_clan_box.visible = false
	name_row.add_child(_clan_box)

	_lbl_username = CafeSocialTheme.make_title("بازیکن کافه فکر", 30, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_username.clip_text = true
	_lbl_username.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(_lbl_username)

	# Row 2: In-Game Role (Optional)
	_lbl_role = CafeSocialTheme.make_body("", 19, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_role.visible = false
	info_col.add_child(_lbl_role)

	# Row 3: Honor Title & Competitive Tier Badges
	_tags_row = HBoxContainer.new()
	_tags_row.alignment = BoxContainer.ALIGNMENT_END
	_tags_row.add_theme_constant_override("separation", 6)
	info_col.add_child(_tags_row)

	# Row 4: Player ID with Copy Button
	_id_row = HBoxContainer.new()
	_id_row.alignment = BoxContainer.ALIGNMENT_END
	_id_row.add_theme_constant_override("separation", 6)
	info_col.add_child(_id_row)

	_btn_copy = CafeSocialTheme.make_button("کپی", "bronze", Vector2(62, 34), 16)
	_btn_copy.pressed.connect(func():
		AudioManager.sfx_tap()
		if not _current_user_id.is_empty():
			DisplayServer.clipboard_set(_current_user_id)
			copy_id_requested.emit(_current_user_id)
	)
	_id_row.add_child(_btn_copy)

	_lbl_id = CafeSocialTheme.make_body("شناسه: -", 18, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_id_row.add_child(_lbl_id)

	# --- Right Avatar Column (Prominent Golden Framed Avatar) ---
	_avatar_holder = Control.new()
	_avatar_holder.custom_minimum_size = Vector2(104, 104)
	_avatar_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_avatar_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_row.add_child(_avatar_holder)

	# Bottom: Personal Status Quote (Optional)
	_lbl_status_msg = CafeSocialTheme.make_body("", 19, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_lbl_status_msg.visible = false
	main_vbox.add_child(_lbl_status_msg)


func setup(user_data: Dictionary, role_text: String = "", is_self: bool = false, is_bot: bool = false) -> void:
	_current_user_id = str(user_data.get("_id", user_data.get("id", user_data.get("user_id", ""))))
	var uname := str(user_data.get("name", user_data.get("username", "بازیکن کافه فکر")))
	var av_id := int(user_data.get("image", user_data.get("user_image", user_data.get("avatar", 0))))
	var frame_id := int(user_data.get("profile_frame", user_data.get("avatar_frame", 1)))
	if frame_id <= 0:
		frame_id = 1
	var p_title := str(user_data.get("profile_title", ""))
	var p_status := str(user_data.get("status_message", ""))

	# Presence status
	var pres: Dictionary = user_data.get("presence", {}) if typeof(user_data.get("presence")) == TYPE_DICTIONARY else {}
	var pres_status := str(pres.get("status", user_data.get("status", "online" if is_self else "offline")))
	var p_info := CafeSocialTheme.format_presence(pres if not pres.is_empty() else {"status": pres_status})

	# Tier info (Text only, no icon on right of label)
	var tier: Dictionary = user_data.get("tier", {}) if typeof(user_data.get("tier")) == TYPE_DICTIONARY else {}
	var tier_txt := str(tier.get("title_fa", user_data.get("rank_title", ""))).strip_edges()

	# 1. Username
	_lbl_username.text = uname

	# 2. Top-Left Clan Name Pill (replaces status image; hidden if player is not in a clan)
	for c in _clan_box.get_children():
		c.queue_free()
	var clan_d: Dictionary = user_data.get("clan", {}) if typeof(user_data.get("clan")) == TYPE_DICTIONARY else {}
	var clan_id_str := str(clan_d.get("clan_id", clan_d.get("_id", user_data.get("clan_id", "")))).strip_edges()
	var has_clan := (not clan_id_str.is_empty()) or (not clan_d.is_empty() and not str(clan_d.get("name", "")).strip_edges().is_empty())
	if has_clan and not is_bot:
		_current_clan_data = clan_d
		_build_clan_chip(clan_id_str, clan_d)
		_clan_box.visible = true
	else:
		_clan_box.visible = false

	# 3. Role
	if not role_text.is_empty():
		_lbl_role.text = role_text
		var r_col := CafeSocialTheme.COL_GOLD_BRIGHT
		if role_text.contains("قرمز") or role_text.contains("۱"):
			r_col = Color(1.0, 0.48, 0.48)
		elif role_text.contains("آبی") or role_text.contains("۲"):
			r_col = Color(0.48, 0.80, 1.0)
		_lbl_role.add_theme_color_override("font_color", r_col)
		_lbl_role.visible = true
	else:
		_lbl_role.visible = false

	# 4. Tags / Badges (Pure text labels, no icons)
	for c in _tags_row.get_children():
		c.queue_free()
	var has_tags := false
	if not p_title.is_empty():
		has_tags = true
		_tags_row.add_child(CafeSocialTheme.make_badge_pill(p_title, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.10, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 17))
	if not tier_txt.is_empty():
		has_tags = true
		_tags_row.add_child(CafeSocialTheme.make_badge_pill(tier_txt, CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER, 17))
	_tags_row.visible = has_tags

	# 5. ID & Copy
	if not _current_user_id.is_empty() and not is_bot:
		_lbl_id.text = "شناسه: %s" % GameManager.to_fa_num(_current_user_id)
		_id_row.visible = true
	else:
		_id_row.visible = false

	# 7. Avatar Medallion with Golden Frame (Circle dot removed: show_dot = false)
	for c in _avatar_holder.get_children():
		c.queue_free()
	var av_badge := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 96.0, pres_status, false)
	av_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_holder.add_child(av_badge)

	# 8. Status Quote
	if not p_status.is_empty():
		_lbl_status_msg.text = "«%s»" % p_status
		_lbl_status_msg.visible = true
	else:
		_lbl_status_msg.visible = false


func _build_clan_chip(clan_id: String, clan_d: Dictionary) -> void:
	var cname := str(clan_d.get("name", "اتحاد"))
	var clan_btn := Button.new()
	clan_btn.text = cname
	clan_btn.custom_minimum_size = Vector2(0, 34)
	clan_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clan_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clan_btn.focus_mode = Control.FOCUS_NONE
	clan_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clan_btn.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	clan_btn.add_theme_font_size_override("font_size", 18)
	clan_btn.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT)
	clan_btn.add_theme_color_override("font_hover_color", CafeSocialTheme.COL_IVORY)

	var c_sb := CafeSocialTheme.create_card_style(Color(0.18, 0.11, 0.05, 0.95), CafeSocialTheme.COL_GOLD_ANTIQUE, 10, 1, 10.0, 3.0)
	var c_sb_h := CafeSocialTheme.create_card_style(Color(0.28, 0.17, 0.08, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 10, 1, 10.0, 3.0)
	clan_btn.add_theme_stylebox_override("normal", c_sb)
	clan_btn.add_theme_stylebox_override("hover", c_sb_h)
	clan_btn.add_theme_stylebox_override("pressed", c_sb)
	clan_btn.add_theme_stylebox_override("focus", c_sb_h)

	ActionVFXManager.apply_button_juice(clan_btn, "tap_button")
	clan_btn.pressed.connect(func():
		AudioManager.sfx_button()
		view_clan_requested.emit(clan_id, clan_d)
	)
	_clan_box.add_child(clan_btn)
