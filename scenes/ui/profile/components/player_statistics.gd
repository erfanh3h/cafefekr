class_name PlayerStatistics
extends HBoxContainer

## Cafe Fekr — Player Statistics Component
## Displays 3 distinguishable statistic cards without icons:
## 1. Cafe Fekr Points (امتیاز کافه فکر)
## 2. Player Level (سطح بازیکن)
## 3. Friends Count (تعداد دوستان) or Coins (سکه شما if self)

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
	# Card 1: Score / Cafe Fekr Points (Gold Accent)
	var sc_res := _create_stat_card("امتیاز کافه", CafeSocialTheme.COL_GOLD_BRIGHT)
	_card_score = sc_res["panel"]
	_lbl_score_val = sc_res["val_label"]
	add_child(_card_score)

	# Card 2: Level (Emerald Accent)
	var lvl_res := _create_stat_card("سطح بازیکن", CafeSocialTheme.COL_EMERALD_TEXT)
	_card_level = lvl_res["panel"]
	_lbl_level_val = lvl_res["val_label"]
	add_child(_card_level)

	# Card 3: Friends / Coins (Warm Cream Accent)
	var fr_res := _create_stat_card("دوستان", CafeSocialTheme.COL_WARM_CREAM)
	_card_friends = fr_res["panel"]
	_lbl_friends_val = fr_res["val_label"]
	_lbl_friends_title = fr_res["title_label"]
	add_child(_card_friends)


func _create_stat_card(title: String, accent_col: Color) -> Dictionary:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 98)

	# Clean, refined dark walnut well card without inner ornamental icons
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.94)
	sb.border_color = Color(0.48, 0.36, 0.20, 0.70)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)

	# Large Crisp Number (Zero icons as requested)
	var val_lbl := CafeSocialTheme.make_title("۰", 30, accent_col, HORIZONTAL_ALIGNMENT_CENTER, false)
	vb.add_child(val_lbl)

	# Label Underneath
	var tit_lbl := CafeSocialTheme.make_body(title, 22, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
	tit_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tit_lbl.clip_text = true
	tit_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
