class_name FavoriteGameItem
extends PanelContainer

## Cafe Fekr — Favorite / Most-Played Game Card Item
## Displays framed game artwork, difficulty title banner, match count,
## mini win-rate bar, and color-coded win-rate pill.

const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

var _ico_game: TextureRect
var _name_banner: PanelContainer
var _lbl_name: Label
var _lbl_matches: Label
var _wr_bar: ProgressBar
var _lbl_winrate: Label
var _win_pill: PanelContainer


func _init() -> void:
	custom_minimum_size = Vector2(166, 188)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_build_ui()


func _build_ui() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(0.58, 0.44, 0.24, 0.82)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_top = 2
	sb.set_corner_radius_all(15)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 0 if ResponsiveUI.is_mobile() else 4
	sb.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", sb)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)

	# 1. Framed Game Icon Thumbnail (62x62)
	var icon_slot: PanelContainer = PanelContainer.new()
	icon_slot.custom_minimum_size = Vector2(62, 62)
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var isb: StyleBoxFlat = StyleBoxFlat.new()
	isb.bg_color = Color(0.08, 0.05, 0.03, 1.0)
	isb.border_color = CafeSocialTheme.COL_GOLD_ANTIQUE
	isb.set_border_width_all(1)
	isb.set_corner_radius_all(12)
	isb.content_margin_left = 3.0
	isb.content_margin_right = 3.0
	isb.content_margin_top = 3.0
	isb.content_margin_bottom = 3.0
	icon_slot.add_theme_stylebox_override("panel", isb)
	vb.add_child(icon_slot)

	_ico_game = TextureRect.new()
	_ico_game.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_game.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_slot.add_child(_ico_game)

	# 2. Game Title inside difficulty ribbon frame
	_name_banner = PanelContainer.new()
	_name_banner.custom_minimum_size = Vector2(0, 36)
	_name_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style("", 18.0, 2.0))
	vb.add_child(_name_banner)

	_lbl_name = CafeSocialTheme.make_title("نام بازی", 16, CafeSocialTheme.COL_IVORY, HORIZONTAL_ALIGNMENT_CENTER, false)
	_lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_name.clip_text = true
	_lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_banner.add_child(_lbl_name)

	# 3. Matches Count
	_lbl_matches = Label.new()
	_lbl_matches.text = "۰ مسابقه"
	_lbl_matches.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_matches.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(_lbl_matches, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	_lbl_matches.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	vb.add_child(_lbl_matches)

	# 4. Mini Win-Rate Progress Bar
	_wr_bar = ProgressBar.new()
	_wr_bar.custom_minimum_size = Vector2(0, 6)
	_wr_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wr_bar.min_value = 0.0
	_wr_bar.max_value = 100.0
	_wr_bar.value = 0.0
	_wr_bar.show_percentage = false
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.07, 0.04, 0.02, 0.92)
	bar_bg.set_corner_radius_all(3)
	_wr_bar.add_theme_stylebox_override("background", bar_bg)
	vb.add_child(_wr_bar)

	# 5. Color-Coded Win-Rate Pill
	_win_pill = PanelContainer.new()
	_win_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_win_pill)

	_lbl_winrate = Label.new()
	_lbl_winrate.text = "۰٪ برد"
	_lbl_winrate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_winrate.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(_lbl_winrate, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	_win_pill.add_child(_lbl_winrate)


func setup(game_type: String, total_matches: int, win_rate: float, _wins: int = 0) -> void:
	var thumb: Texture2D = CafeSocialTheme.get_game_thumb(game_type)
	if thumb != null:
		_ico_game.texture = thumb
	else:
		_ico_game.texture = CafeSocialTheme.ICO_CUP

	if is_instance_valid(_name_banner):
		_name_banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(game_type, 18.0, 2.0))
	_lbl_name.text = GameRegistry.get_display_name_fa(game_type)
	_lbl_matches.text = "%s مسابقه" % GameManager.to_fa_num(total_matches)

	var pct: int = clampi(int(round(win_rate)), 0, 100)
	_wr_bar.value = float(pct)
	_lbl_winrate.text = "%s٪ برد" % GameManager.to_fa_num(pct)

	var txt_col: Color = CafeSocialTheme.COL_EMERALD_TEXT
	var bg_col: Color = CafeSocialTheme.COL_EMERALD_BG
	var brd_col: Color = CafeSocialTheme.COL_EMERALD_BORDER
	var fill_col: Color = Color(0.30, 0.84, 0.48, 0.96)
	if pct < 35:
		txt_col = CafeSocialTheme.COL_CRIMSON_TEXT
		bg_col = CafeSocialTheme.COL_CRIMSON_BG
		brd_col = CafeSocialTheme.COL_CRIMSON_BORDER
		fill_col = Color(0.86, 0.34, 0.34, 0.92)
	elif pct < 55:
		txt_col = CafeSocialTheme.COL_GOLD_BRIGHT
		bg_col = Color(0.24, 0.17, 0.06, 0.94)
		brd_col = CafeSocialTheme.COL_GOLD_ANTIQUE
		fill_col = Color(0.95, 0.78, 0.28, 0.95)

	var fill_sb: StyleBoxFlat = StyleBoxFlat.new()
	fill_sb.bg_color = fill_col
	fill_sb.set_corner_radius_all(3)
	_wr_bar.add_theme_stylebox_override("fill", fill_sb)

	var wsb: StyleBoxFlat = StyleBoxFlat.new()
	wsb.bg_color = bg_col
	wsb.border_color = brd_col
	wsb.set_border_width_all(1)
	wsb.set_corner_radius_all(8)
	wsb.content_margin_left = 10.0
	wsb.content_margin_right = 10.0
	wsb.content_margin_top = 2.0
	wsb.content_margin_bottom = 2.0
	_win_pill.add_theme_stylebox_override("panel", wsb)
	_lbl_winrate.add_theme_color_override("font_color", txt_col)
