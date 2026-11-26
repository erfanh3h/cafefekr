class_name PlayerStatistics
extends HBoxContainer

## Cafe Fekr — Player Statistics Component
## Displays 3 distinguishable statistic cards without icons:
## 1. Cafe Fekr Points (امتیاز کافه فکر)
## 2. Player Level (سطح بازیکن)
## 3. Friends Count (تعداد دوستان) or Coins (سکه شما if self)

const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

var _card_score: PanelContainer
var _card_level: PanelContainer
var _card_friends: PanelContainer

var _lbl_score_val: Label
var _lbl_level_val: Label
var _lbl_friends_val: Label
var _lbl_friends_title: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_build_ui()


func _build_ui() -> void:
	var sc_res: Dictionary = _create_stat_card("امتیاز کافه", CafeSocialTheme.COL_GOLD_BRIGHT)
	_card_score = sc_res["panel"] as PanelContainer
	_lbl_score_val = sc_res["val_label"] as Label
	add_child(_card_score)

	var lvl_res: Dictionary = _create_stat_card("سطح بازیکن", CafeSocialTheme.COL_EMERALD_TEXT)
	_card_level = lvl_res["panel"] as PanelContainer
	_lbl_level_val = lvl_res["val_label"] as Label
	add_child(_card_level)

	var fr_res: Dictionary = _create_stat_card("دوستان", CafeSocialTheme.COL_WARM_CREAM)
	_card_friends = fr_res["panel"] as PanelContainer
	_lbl_friends_val = fr_res["val_label"] as Label
	_lbl_friends_title = fr_res["title_label"] as Label
	add_child(_card_friends)


func _create_stat_card(title: String, accent_col: Color) -> Dictionary:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 84)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.55)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_top = 2
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)

	var val_lbl: Label = CafeSocialTheme.make_title("۰", 26, accent_col, HORIZONTAL_ALIGNMENT_CENTER, false)
	vb.add_child(val_lbl)

	var tit_lbl: Label = Label.new()
	tit_lbl.text = title
	tit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit_lbl.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(tit_lbl, UITypography.Role.BODY_SM, {"min_px": 15, "max_px": 20})
	tit_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	vb.add_child(tit_lbl)

	return {
		"panel": p,
		"val_label": val_lbl,
		"title_label": tit_lbl
	}


func setup(score: int, level: int, friends_count: int, is_self: bool = false, coin_count: int = 0) -> void:
	_lbl_score_val.text = GameManager.to_fa_num(score)
	_lbl_level_val.text = GameManager.to_fa_num(level)

	if is_self:
		_lbl_friends_title.text = "سکه شما"
		_lbl_friends_val.text = GameManager.to_fa_num(coin_count)
	else:
		_lbl_friends_title.text = "دوستان"
		_lbl_friends_val.text = GameManager.to_fa_num(friends_count)
