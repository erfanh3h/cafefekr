class_name ProfileHeader
extends PanelContainer

## Cafe Fekr — Reusable Profile Header Component
## Displays avatar with gold frame (Right), username & tags (Middle),
## large score & level crest badges with values inside (Top-Left),
## tappable clan pill (Bottom-Left), copyable user ID (Bottom-Right),
## and optional personal status quote.

signal copy_id_requested(user_id: String)
signal view_clan_requested(clan_id: String, clan_data: Dictionary)

const TEX_SCORE_BADGE := preload("res://assets/images/badges/score_frame.png")
const TEX_LEVEL_BADGE := preload("res://assets/images/badges/level_frame.png")

var _avatar_holder: Control
var _lbl_username: Label
var _lbl_score: Label
var _lbl_level: Label
var _lbl_id: Label
var _clan_box: HBoxContainer
var _lbl_status_msg: Label

var _current_user_id: String = ""
var _current_clan_data: Dictionary = {}


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _make_stat_crest(tex: Texture2D, font_sz: int, text_col: Color, y_top_off: float, y_bot_off: float) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(76, 84)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(icon)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_top = y_top_off
	lbl.offset_bottom = y_bot_off
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.text = "۰"
	holder.add_child(lbl)

	return {"root": holder, "label": lbl}


func _build_ui() -> void:
	# Generous inset padding so badges, clan pill, and avatar never touch the ornate frame edges
	add_theme_stylebox_override("panel", CafeSocialTheme.create_frame_style(true, 44.0, 24.0))

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# --- HERO ROW: [Score & Level Crests (Top-Left)] + [Username / Clan / ID (Middle)] + [Avatar (Right)] ---
	var hero_row := HBoxContainer.new()
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_theme_constant_override("separation", 10)
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(hero_row)

	# 1. Top-Left: Score & Level frames with clean values centered inside
	var badges_row := HBoxContainer.new()
	badges_row.add_theme_constant_override("separation", 6)
	badges_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	badges_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badges_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero_row.add_child(badges_row)

	var score_crest := _make_stat_crest(TEX_SCORE_BADGE, 23, Color(1.0, 0.96, 0.78, 1.0), 6.0, 0.0)
	_lbl_score = score_crest["label"]
	badges_row.add_child(score_crest["root"])

	var level_crest := _make_stat_crest(TEX_LEVEL_BADGE, 28, Color(1.0, 0.98, 0.88, 1.0), 6.0, 0.0)
	_lbl_level = level_crest["label"]
	badges_row.add_child(level_crest["root"])

	# 2. Middle: Username (+2px) -> Clan Box (if exists) -> Player ID (no copy button)
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_col.alignment = BoxContainer.ALIGNMENT_CENTER
	info_col.add_theme_constant_override("separation", 4)
	hero_row.add_child(info_col)

	_lbl_username = CafeSocialTheme.make_title("بازیکن کافه فکر", 28, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_username.clip_text = true
	_lbl_username.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info_col.add_child(_lbl_username)

	_clan_box = HBoxContainer.new()
	_clan_box.alignment = BoxContainer.ALIGNMENT_END
	_clan_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clan_box.visible = false
	info_col.add_child(_clan_box)

	_lbl_id = CafeSocialTheme.make_body("شناسه: -", 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_id.clip_text = true
	_lbl_id.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_id.mouse_filter = Control.MOUSE_FILTER_STOP
	_lbl_id.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_lbl_id.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _current_user_id.is_empty():
			AudioManager.sfx_tap()
			DisplayServer.clipboard_set(_current_user_id)
			copy_id_requested.emit(_current_user_id)
	)
	info_col.add_child(_lbl_id)

	# 3. Far-Right: Golden Framed Avatar Medallion
	_avatar_holder = Control.new()
	_avatar_holder.custom_minimum_size = Vector2(90, 90)
	_avatar_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_avatar_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_row.add_child(_avatar_holder)

	# Optional Personal Status Quote
	_lbl_status_msg = CafeSocialTheme.make_body("", 19, CafeSocialTheme.COL_WARM_CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	_lbl_status_msg.visible = false
	main_vbox.add_child(_lbl_status_msg)


func setup(user_data: Dictionary, _role_text: String = "", is_self: bool = false, is_bot: bool = false) -> void:
	_current_user_id = str(user_data.get("_id", user_data.get("id", user_data.get("user_id", ""))))
	var uname := str(user_data.get("name", user_data.get("username", "بازیکن کافه فکر")))
	var av_id := int(user_data.get("image", user_data.get("user_image", user_data.get("avatar", 0))))
	var frame_id := int(user_data.get("profile_frame", user_data.get("avatar_frame", 1)))
	if frame_id <= 0:
		frame_id = 1
	var p_status := str(user_data.get("status_message", ""))

	# Score & Level inside the Top-Left Crests
	var score_val := int(user_data.get("score", user_data.get("user_score", 0)))
	var xp_val := int(float(user_data.get("xp", user_data.get("user_xp", 0))))
	var lvl_val := GameManager.calculate_level(xp_val) if xp_val > 0 else int(user_data.get("level", 1))
	_lbl_score.text = GameManager.to_fa_num(score_val)
	_lbl_level.text = GameManager.to_fa_num(lvl_val)

	# Presence status
	var pres: Dictionary = user_data.get("presence", {}) if typeof(user_data.get("presence")) == TYPE_DICTIONARY else {}
	var pres_status := str(pres.get("status", user_data.get("status", "online" if is_self else "offline")))

	# 1. Username
	_lbl_username.text = uname

	# 2. Clan Pill directly under Username (hidden if player is not in a clan)
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

	# 3. Player ID directly under Clan Box (no copy button)
	if not _current_user_id.is_empty() and not is_bot:
		var short_id := _current_user_id.substr(0, 8) if _current_user_id.length() > 8 else _current_user_id
		_lbl_id.text = "شناسه: %s" % GameManager.to_fa_num(short_id)
		_lbl_id.visible = true
	else:
		_lbl_id.visible = false

	# 4. Avatar Medallion with Golden Frame
	for c in _avatar_holder.get_children():
		c.queue_free()
	var av_badge := CafeSocialTheme.make_avatar_badge(av_id, frame_id, 86.0, pres_status, false)
	av_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_holder.add_child(av_badge)

	# 5. Status Quote
	if not p_status.is_empty():
		_lbl_status_msg.text = "«%s»" % p_status
		_lbl_status_msg.visible = true
	else:
		_lbl_status_msg.visible = false


func _build_clan_chip(clan_id: String, clan_d: Dictionary) -> void:
	var cname := str(clan_d.get("name", "اتحاد")).strip_edges()
	var display_name := (cname.substr(0, 14) + "…") if cname.length() > 15 else cname
	var clan_btn := Button.new()
	clan_btn.text = display_name
	clan_btn.custom_minimum_size = Vector2(0, 32)
	clan_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	clan_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clan_btn.focus_mode = Control.FOCUS_NONE
	clan_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clan_btn.add_theme_font_override("font", CafeSocialTheme.FONT_TITLE)
	clan_btn.add_theme_font_size_override("font_size", 17)
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
