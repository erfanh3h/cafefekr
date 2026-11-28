class_name RankingCard
extends PanelContainer

## Cafe Fekr — Competitive Statistics & Ranking Card Component
## Displays mode name, rank/tier badge, 3 structured metric tiles,
## a proportional segmented Win/Draw/Loss distribution bar, and win-rate summary.

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")

var _lbl_title: Label
var _ico_mode: TextureRect
var _rank_badge_holder: HBoxContainer
var _chips_row: HBoxContainer
var _seg_bar_track: PanelContainer
var _seg_bar_row: HBoxContainer
var _lbl_winrate: Label
var _lbl_total: Label


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_ui()


func _build_ui() -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(0.60, 0.46, 0.24, 0.85)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_top = 2
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	sb.shadow_size = 0 if ResponsiveUI.is_mobile() else 5
	sb.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", sb)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)

	# 1. Header Row: Rank/Mode Pill (Left) + Mode Title & Optional Icon (Right)
	var hdr: HBoxContainer = HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hdr)

	_rank_badge_holder = HBoxContainer.new()
	_rank_badge_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(_rank_badge_holder)

	var title_box: HBoxContainer = HBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_END
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	hdr.add_child(title_box)

	_lbl_title = CafeSocialTheme.make_title("رده‌بندی", 21, CafeSocialTheme.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT, false)
	_lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_title.clip_text = true
	_lbl_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_box.add_child(_lbl_title)

	_ico_mode = TextureRect.new()
	_ico_mode.custom_minimum_size = Vector2(24, 24)
	_ico_mode.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ico_mode.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ico_mode.visible = false
	title_box.add_child(_ico_mode)

	# 2. 3-Column Metric Tiles
	_chips_row = HBoxContainer.new()
	_chips_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chips_row.add_theme_constant_override("separation", 8)
	vb.add_child(_chips_row)

	# 3. Proportional Segmented Distribution Bar + Footer Summary
	var wr_box: VBoxContainer = VBoxContainer.new()
	wr_box.add_theme_constant_override("separation", 6)
	vb.add_child(wr_box)

	_seg_bar_track = PanelContainer.new()
	_seg_bar_track.custom_minimum_size = Vector2(0, 10)
	_seg_bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seg_bar_track.clip_contents = true
	var track_sb: StyleBoxFlat = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.07, 0.04, 0.02, 0.94)
	track_sb.border_color = Color(0.42, 0.31, 0.17, 0.65)
	track_sb.set_border_width_all(1)
	track_sb.set_corner_radius_all(5)
	track_sb.content_margin_left = 1.0
	track_sb.content_margin_right = 1.0
	track_sb.content_margin_top = 1.0
	track_sb.content_margin_bottom = 1.0
	_seg_bar_track.add_theme_stylebox_override("panel", track_sb)
	wr_box.add_child(_seg_bar_track)

	_seg_bar_row = HBoxContainer.new()
	_seg_bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seg_bar_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seg_bar_row.add_theme_constant_override("separation", 2)
	_seg_bar_track.add_child(_seg_bar_row)

	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wr_box.add_child(footer_row)

	_lbl_winrate = Label.new()
	_lbl_winrate.text = "نرخ برد: ۰٪"
	_lbl_winrate.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(_lbl_winrate, UITypography.Role.CAPTION, {"min_px": 15, "max_px": 20})
	_lbl_winrate.add_theme_color_override("font_color", CafeSocialTheme.COL_EMERALD_TEXT)
	footer_row.add_child(_lbl_winrate)

	_lbl_total = Label.new()
	_lbl_total.text = "۰ مسابقه"
	_lbl_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_total.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(_lbl_total, UITypography.Role.CAPTION, {"min_px": 15, "max_px": 20})
	_lbl_total.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	footer_row.add_child(_lbl_total)


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

	_set_rank_pill(rank_text)

	for c in _chips_row.get_children():
		c.queue_free()

	# RTL order (left-to-right in HBox -> losses on left, draws center, wins right)
	_chips_row.add_child(_create_metric_tile("باخت", losses, CafeSocialTheme.COL_CRIMSON_TEXT, Color(0.24, 0.09, 0.09, 0.92), Color(0.76, 0.30, 0.28, 0.72)))
	_chips_row.add_child(_create_metric_tile("مساوی", draws, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.22, 0.16, 0.07, 0.92), Color(0.76, 0.58, 0.24, 0.72)))
	_chips_row.add_child(_create_metric_tile("برد", wins, CafeSocialTheme.COL_EMERALD_TEXT, Color(0.10, 0.24, 0.15, 0.94), Color(0.32, 0.74, 0.46, 0.78)))

	var total: int = wins + draws + losses
	var wr_pct: int = int(round((float(wins) / float(total)) * 100.0)) if total > 0 else 0
	_render_segmented_bar(
		[losses, draws, wins],
		[Color(0.86, 0.34, 0.34, 0.92), Color(0.92, 0.74, 0.28, 0.92), Color(0.30, 0.84, 0.48, 0.96)],
		total
	)
	_lbl_winrate.text = "نرخ برد: %s٪" % GameManager.to_fa_num(wr_pct)
	_lbl_winrate.add_theme_color_override("font_color", _winrate_color(wr_pct, total))
	_lbl_total.text = "%s مسابقه ثبت‌شده" % GameManager.to_fa_num(total)


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

	_set_rank_pill(rank_text)

	for c in _chips_row.get_children():
		c.queue_free()

	_chips_row.add_child(_create_metric_tile("سایر رتبه‌ها", rank_other, CafeSocialTheme.COL_MUTED_SAND, Color(0.16, 0.11, 0.07, 0.90), Color(0.46, 0.36, 0.24, 0.70)))
	_chips_row.add_child(_create_metric_tile("رتبه دوم", rank2, CafeSocialTheme.COL_IVORY, Color(0.19, 0.15, 0.10, 0.92), Color(0.68, 0.58, 0.42, 0.75)))
	_chips_row.add_child(_create_metric_tile("رتبه اول", rank1, CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.26, 0.19, 0.06, 0.95), CafeSocialTheme.COL_GOLD_ANTIQUE))

	var total: int = rank1 + rank2 + rank_other
	var win_pct: int = int(round((float(rank1) / float(total)) * 100.0)) if total > 0 else 0
	_render_segmented_bar(
		[rank_other, rank2, rank1],
		[Color(0.56, 0.44, 0.30, 0.85), Color(0.84, 0.80, 0.72, 0.90), Color(0.98, 0.80, 0.28, 0.98)],
		total
	)
	_lbl_winrate.text = "مقام اول: %s٪" % GameManager.to_fa_num(win_pct)
	_lbl_winrate.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if total > 0 else CafeSocialTheme.COL_MUTED_SAND)
	_lbl_total.text = "%s بازی چندنفره" % GameManager.to_fa_num(total)


func _set_rank_pill(rank_text: String) -> void:
	for c in _rank_badge_holder.get_children():
		c.queue_free()
	if not rank_text.is_empty():
		var pill: PanelContainer = CafeSocialTheme.make_badge_pill(
			rank_text,
			CafeSocialTheme.COL_GOLD_BRIGHT,
			Color(0.20, 0.14, 0.06, 0.95),
			CafeSocialTheme.COL_GOLD_ANTIQUE,
			15
		)
		_rank_badge_holder.add_child(pill)
		_rank_badge_holder.visible = true
	else:
		_rank_badge_holder.visible = false


func _render_segmented_bar(values: Array[int], colors: Array[Color], total: int) -> void:
	for c in _seg_bar_row.get_children():
		c.queue_free()
	if total <= 0:
		return
	for i in range(values.size()):
		var v: int = values[i]
		if v <= 0:
			continue
		var seg: Panel = Panel.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(v)
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = colors[i]
		st.set_corner_radius_all(3)
		seg.add_theme_stylebox_override("panel", st)
		_seg_bar_row.add_child(seg)


func _create_metric_tile(label_txt: String, value: int, text_col: Color, bg_col: Color, border_col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(1)
	st.set_corner_radius_all(11)
	st.content_margin_left = 6.0
	st.content_margin_right = 6.0
	st.content_margin_top = 6.0
	st.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", st)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	p.add_child(vb)

	var val_lbl: Label = Label.new()
	val_lbl.text = GameManager.to_fa_num(value)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", FONT_HEKAYAT)
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.add_theme_color_override("font_color", text_col)
	vb.add_child(val_lbl)

	var cap_lbl: Label = Label.new()
	cap_lbl.text = label_txt
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_lbl.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(cap_lbl, UITypography.Role.CAPTION, {"min_px": 14, "max_px": 18})
	cap_lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_WARM_CREAM)
	vb.add_child(cap_lbl)
	return p


func _winrate_color(pct: int, total: int) -> Color:
	if total <= 0:
		return CafeSocialTheme.COL_MUTED_SAND
	if pct >= 55:
		return CafeSocialTheme.COL_EMERALD_TEXT
	if pct >= 35:
		return CafeSocialTheme.COL_GOLD_BRIGHT
	return CafeSocialTheme.COL_CRIMSON_TEXT
