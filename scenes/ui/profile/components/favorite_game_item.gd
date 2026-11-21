class_name FavoriteGameItem
extends PanelContainer

## Cafe Fekr — Favorite / Most-Played Game Card Item
## Displays small game icon, game name, number of matches, and win/achievement indicator.

var _ico_game: TextureRect
var _name_banner: PanelContainer
var _lbl_name: Label
var _lbl_matches: Label
var _lbl_winrate: Label
var _win_pill: PanelContainer


func _init() -> void:
	custom_minimum_size = Vector2(188, 204)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.04, 0.95)
	sb.border_color = Color(0.48, 0.36, 0.20, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)

	# 1. Game Icon Thumbnail (Framed)
	var icon_slot := PanelContainer.new()
	icon_slot.custom_minimum_size = Vector2(56, 56)
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.08, 0.05, 0.03, 1.0)
	isb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	isb.set_border_width_all(1)
	isb.set_corner_radius_all(12)
	icon_slot.add_theme_stylebox_override("panel", isb)
	vb.add_child(icon_slot)

	_ico_game = TextureRect.new()
	_ico_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ico_game.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_game.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_slot.add_child(_ico_game)

	# 2. Game Title inside difficulty ribbon frame
	_name_banner = PanelContainer.new()
	_name_banner.custom_minimum_size = Vector2(0, 44)
	_name_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style("", 22.0, 2.0))
	vb.add_child(_name_banner)

	_lbl_name = CafeSocialTheme.make_title("نام بازی", 22, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_name.clip_text = true
	_lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_banner.add_child(_lbl_name)

	# 3. Matches Count
	_lbl_matches = CafeSocialTheme.make_body("۰ بازی", 22, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
	vb.add_child(_lbl_matches)

	# 4. Win / Achievement Indicator Pill
	_win_pill = PanelContainer.new()
	_win_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = CafeSocialTheme.COL_EMERALD_BG
	wsb.border_color = CafeSocialTheme.COL_EMERALD_BORDER
	wsb.set_border_width_all(1)
	wsb.set_corner_radius_all(8)
	wsb.content_margin_left = 10.0
	wsb.content_margin_right = 10.0
	wsb.content_margin_top = 3.0
	wsb.content_margin_bottom = 3.0
	_win_pill.add_theme_stylebox_override("panel", wsb)
	vb.add_child(_win_pill)

	_lbl_winrate = CafeSocialTheme.make_body("۰٪ برد", 22, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	_win_pill.add_child(_lbl_winrate)


func setup(game_type: String, total_matches: int, win_rate: float, wins: int = 0) -> void:
	var thumb := CafeSocialTheme.get_game_thumb(game_type)
	if thumb != null:
		_ico_game.texture = thumb
	else:
		_ico_game.texture = CafeSocialTheme.ICO_CUP

	if is_instance_valid(_name_banner):
		_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(game_type, 22.0, 2.0))
	_lbl_name.text = GameRegistry.get_display_name_fa(game_type)
	_lbl_matches.text = "%s مسابقه" % GameManager.to_fa_num(total_matches)
	_lbl_winrate.text = "%s٪ برد" % GameManager.to_fa_num(int(round(win_rate)))
