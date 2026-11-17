class_name RankingCard
extends PanelContainer

## Cafe Fekr — Competitive Statistics & Ranking Card Component
## Displays competitive game mode stats:
## Mode Name, Rank / Position, Wins, Draws, Losses, and Win Rate progress bar.

var _lbl_title: Label
var _ico_mode: TextureRect
var _rank_badge_holder: Control
var _chips_row: HBoxContainer
var _progress_bar: ProgressBar
var _lbl_winrate: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.52, 0.40, 0.22, 0.82)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# 1. Header Row: Mode Title (Right) + Rank/Position Badge (Left)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	_rank_badge_holder = Control.new()
	hdr.add_child(_rank_badge_holder)

	var title_box := HBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_END
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	hdr.add_child(title_box)

	_lbl_title = CafeSocialTheme.make_title("رده‌بندی", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	title_box.add_child(_lbl_title)

	_ico_mode = TextureRect.new()
	_ico_mode.custom_minimum_size = Vector2(26, 26)
	_ico_mode.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_mode.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_box.add_child(_ico_mode)

	# 2. Stats Chips Row (Wins, Draws, Losses)
	_chips_row = HBoxContainer.new()
	_chips_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips_row.add_theme_constant_override("separation", 6)
	vb.add_child(_chips_row)

	# 3. Win Rate Progress Bar & Summary
	var wr_box := VBoxContainer.new()
	wr_box.add_theme_constant_override("separation", 3)
	vb.add_child(wr_box)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.06, 0.04, 0.02, 0.9)
	pb_bg.border_color = Color(0.38, 0.28, 0.16, 0.6)
	pb_bg.set_border_width_all(1)
	pb_bg.set_corner_radius_all(5)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.28, 0.78, 0.44, 0.95)
	pb_fill.set_corner_radius_all(5)
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	wr_box.add_child(_progress_bar)

	_lbl_winrate = CafeSocialTheme.make_body("۰٪ پیروزی", 16, CafeSocialTheme.COL_MUTED_SAND, HORIZONTAL_ALIGNMENT_CENTER, false)
	wr_box.add_child(_lbl_winrate)


func setup_mode(
	title_text: String,
	rank_text: String,
	wins: int,
	draws: int,
	losses: int,
	icon_tex: Texture2D = null
) -> void:
	_lbl_title.text = title_text
	if icon_tex != null:
		_ico_mode.texture = icon_tex
		_ico_mode.visible = true
	else:
		_ico_mode.visible = false

	# Rank badge
	for c in _rank_badge_holder.get_children():
		c.queue_free()
	if not rank_text.is_empty():
		var pill := CafeSocialTheme.make_badge_pill(rank_text, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 17)
		_rank_badge_holder.add_child(pill)
		_rank_badge_holder.visible = true
	else:
		_rank_badge_holder.visible = false

	# Chips
	for c in _chips_row.get_children():
		c.queue_free()

	_chips_row.add_child(_create_chip("برد: %s" % GameManager.to_fa_num(wins), CafeSocialTheme.COL_EMERALD_TEXT, CafeSocialTheme.COL_EMERALD_BG, CafeSocialTheme.COL_EMERALD_BORDER))
	_chips_row.add_child(_create_chip("مساوی: %s" % GameManager.to_fa_num(draws), CafeSocialTheme.COL_WARM_CREAM, Color(0.14, 0.10, 0.06), CafeSocialTheme.COL_BRONZE_BORDER))
	_chips_row.add_child(_create_chip("باخت: %s" % GameManager.to_fa_num(losses), CafeSocialTheme.COL_CRIMSON_TEXT, CafeSocialTheme.COL_CRIMSON_BG, CafeSocialTheme.COL_CRIMSON_BORDER))

	# Win rate
	var total := wins + draws + losses
	var wr_pct := round((float(wins) / float(total)) * 100.0) if total > 0 else 0.0
	_progress_bar.value = wr_pct
	_lbl_winrate.text = "نرخ برد: %s٪  •  %s مسابقه ثبت‌شده" % [GameManager.to_fa_num(int(wr_pct)), GameManager.to_fa_num(total)]


func setup_multiplayer(
	title_text: String,
	rank_text: String,
	rank1: int,
	rank2: int,
	rank_other: int,
	icon_tex: Texture2D = null
) -> void:
	_lbl_title.text = title_text
	if icon_tex != null:
		_ico_mode.texture = icon_tex
		_ico_mode.visible = true
	else:
		_ico_mode.visible = false

	# Rank badge
	for c in _rank_badge_holder.get_children():
		c.queue_free()
	if not rank_text.is_empty():
		var pill := CafeSocialTheme.make_badge_pill(rank_text, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.18, 0.12, 0.05), CafeSocialTheme.COL_GOLD_ANTIQUE, 17)
		_rank_badge_holder.add_child(pill)
		_rank_badge_holder.visible = true
	else:
		_rank_badge_holder.visible = false

	# Chips for 1st, 2nd, other
	for c in _chips_row.get_children():
		c.queue_free()

	_chips_row.add_child(_create_chip("🥇 اول: %s" % GameManager.to_fa_num(rank1), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.22, 0.16, 0.06), CafeSocialTheme.COL_GOLD_ANTIQUE))
	_chips_row.add_child(_create_chip("🥈 دوم: %s" % GameManager.to_fa_num(rank2), CafeSocialTheme.COL_WARM_CREAM, Color(0.16, 0.12, 0.08), CafeSocialTheme.COL_BRONZE_BORDER))
	_chips_row.add_child(_create_chip("🥉 سایر: %s" % GameManager.to_fa_num(rank_other), CafeSocialTheme.COL_MUTED_SAND, Color(0.12, 0.08, 0.05), Color(0.4, 0.3, 0.2)))

	var total := rank1 + rank2 + rank_other
	var win_pct := round((float(rank1) / float(total)) * 100.0) if total > 0 else 0.0
	_progress_bar.value = win_pct
	_lbl_winrate.text = "مقام اول: %s٪  •  %s بازی چندنفره" % [GameManager.to_fa_num(int(win_pct)), GameManager.to_fa_num(total)]


func _create_chip(txt: String, text_col: Color, bg_col: Color, border_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.content_margin_left = 6.0
	st.content_margin_right = 6.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	p.add_theme_stylebox_override("panel", st)
	p.add_child(CafeSocialTheme.make_body(txt, 16, text_col, HORIZONTAL_ALIGNMENT_CENTER, false))
	return p
