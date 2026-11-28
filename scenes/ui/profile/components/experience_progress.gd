class_name ExperienceProgress
extends PanelContainer

## Cafe Fekr — Experience & Level Progression Bar Component
## Displays current player level, progress percentage,
## current experience versus required experience in emerald green & gold.

var _lbl_level_title: Label
var _lbl_percentage: Label
var _progress_bar: ProgressBar
var _lbl_exp_ratio: Label
var _lbl_exp_remaining: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.03, 0.94)
	sb.border_color = Color(0.52, 0.40, 0.22, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 0 if ResponsiveUI.is_mobile() else 4
	sb.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)

	# 1. Top Row: Level Title (Right) + Percentage (Left)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)

	_lbl_percentage = CafeSocialTheme.make_body("۰٪", 19, CafeSocialTheme.COL_EMERALD_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	top_row.add_child(_lbl_percentage)

	_lbl_level_title = CafeSocialTheme.make_title("پیشرفت سطح ۱", 20, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_lbl_level_title)

	# 2. Progress Bar (Emerald Green & Gold)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 20)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	var bg_st := StyleBoxFlat.new()
	bg_st.bg_color = Color(0.06, 0.04, 0.02, 0.95)
	bg_st.border_color = Color(0.50, 0.38, 0.20, 0.80)
	bg_st.set_border_width_all(1)
	bg_st.set_corner_radius_all(10)
	_progress_bar.add_theme_stylebox_override("background", bg_st)

	var fill_st := StyleBoxFlat.new()
	fill_st.bg_color = Color(0.26, 0.82, 0.46, 0.98) # Emerald Green
	fill_st.border_color = CafeSocialTheme.COL_GOLD_BRIGHT
	fill_st.border_width_top = 1
	fill_st.border_width_bottom = 1
	fill_st.set_corner_radius_all(9)
	_progress_bar.add_theme_stylebox_override("fill", fill_st)
	vb.add_child(_progress_bar)

	# 3. Bottom Row: Remaining XP (Left) + Current vs Required XP (Right)
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	vb.add_child(bot_row)

	_lbl_exp_remaining = CafeSocialTheme.make_body("", 17, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_LEFT, false)
	bot_row.add_child(_lbl_exp_remaining)

	_lbl_exp_ratio = CafeSocialTheme.make_body("۰ / ۰ XP", 17, Color(1.0, 1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_exp_ratio.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 0.92))
	_lbl_exp_ratio.add_theme_constant_override("outline_size", 2)
	_lbl_exp_ratio.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_lbl_exp_ratio.add_theme_constant_override("shadow_offset_y", 1)
	_lbl_exp_ratio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_row.add_child(_lbl_exp_ratio)


func setup(xp: int, level: int = 0) -> void:
	var lvl_info := GameManager.get_level_info(xp)
	var lvl: int = level if level > 0 else int(lvl_info.get("level", 1))
	var pct_int: int = int(lvl_info.get("percent_int", 0))
	var in_level: int = int(lvl_info.get("exp_in_level", 0))
	var needed: int = int(lvl_info.get("exp_needed", 100))
	var remaining: int = int(lvl_info.get("remaining_xp", 0))

	_lbl_level_title.text = "پیشرفت سطح %s" % GameManager.to_fa_num(lvl)
	_lbl_percentage.text = "%s٪" % GameManager.to_fa_num(pct_int)
	_progress_bar.value = float(lvl_info.get("progress", 0.0)) * 100.0

	_lbl_exp_ratio.text = "%s / %s XP" % [GameManager.to_fa_num(in_level), GameManager.to_fa_num(needed)]
	if remaining > 0:
		_lbl_exp_remaining.text = "%s XP تا سطح بعدی" % GameManager.to_fa_num(remaining)
	else:
		_lbl_exp_remaining.text = "سطح حداکثر"
