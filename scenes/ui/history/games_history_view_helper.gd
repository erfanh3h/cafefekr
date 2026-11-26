class_name GamesHistoryViewHelper
extends RefCounted

## Cafe Fekr — Per-Game & Mode Statistics Builder
## Used by UserProfileDialog (user details), MatchHistoryPage (my games statistics),
## and GameHistoryDialog. Features interactive filter/sort chips, per-game win-rate pills,
## proportional segmented distribution bars, and compact collapsible unplayed games grid.

static var _font_hekayat: FontFile = preload("res://assets/fonts/hekayat.ttf")
static var _font_vazir: FontFile = preload("res://assets/fonts/Vazir.ttf")

const GAMES_LIST: Array[Dictionary] = [
	{"id": "TicTacToe", "key": "tictactoe", "name_fa": "تیک تاک تو", "multi": false},
	{"id": "Chess", "key": "chess", "name_fa": "شطرنج", "multi": false},
	{"id": "Checkers", "key": "checkers", "name_fa": "چکرز", "multi": false},
	{"id": "BackGammon", "key": "backgammon", "name_fa": "تخته نرد", "multi": false},
	{"id": "Othello", "key": "othello", "name_fa": "اتللو", "multi": false},
	{"id": "DotBox", "key": "dotbox", "name_fa": "نقطه خط", "multi": false},
	{"id": "FourInRow", "key": "fourinrow", "name_fa": "دوز چهارتایی", "multi": false},
	{"id": "Mill", "key": "mill", "name_fa": "دوز نه تایی", "multi": false},
	{"id": "Ludo", "key": "ludo", "name_fa": "منچ", "multi": true},
	{"id": "Risk", "key": "risk", "name_fa": "ریسک استرایک", "multi": true},
	{"id": "Uno", "key": "uno", "name_fa": "اونو", "multi": true},
	{"id": "Coup", "key": "coup", "name_fa": "کودتا", "multi": true},
	{"id": "Monopoly", "key": "monopoly", "name_fa": "روپولی", "multi": true},
	{"id": "Quiz", "key": "quiz", "name_fa": "کوییز", "multi": true},
	{"id": "Pentago", "key": "pentago", "name_fa": "پنتاگو", "multi": false},
	{"id": "FekrBekr", "key": "fekrbekr", "name_fa": "فکر بکر", "multi": false},
	{"id": "BattleShip", "key": "battleship", "name_fa": "نبرد کشتی", "multi": false},
	{"id": "Sudoku", "key": "sudoku", "name_fa": "سودوکو", "multi": false},
	{"id": "Yatzy", "key": "yatzy", "name_fa": "یاتزی", "multi": false},
	{"id": "RPC", "key": "rpc", "name_fa": "سنگ کاغذ قیچی", "multi": false},
	{"id": "MNumbers", "key": "mnumbers", "name_fa": "کشف اعداد", "multi": false},
	{"id": "MSweeper", "key": "msweeper", "name_fa": "مین یاب", "multi": false},
	{"id": "BoxFour", "key": "boxfour", "name_fa": "چهارطرفه", "multi": false},
	{"id": "Yinsh", "key": "yinsh", "name_fa": "یینش", "multi": false},
	{"id": "Quoridor", "key": "quoridor", "name_fa": "کوریدور", "multi": false},
]

static func populate_games_history(target_container: VBoxContainer, history_data: Dictionary, include_mode_cards: bool = true) -> void:
	if not is_instance_valid(target_container):
		return

	for child in target_container.get_children():
		child.queue_free()

	if history_data == null or history_data.is_empty():
		var empty_card: PanelContainer = _create_empty_card("هنوز آماری برای بازی‌ها ثبت نشده است.")
		target_container.add_child(empty_card)
		return

	# === 1. OPTIONAL MODE SUMMARY CARDS (when caller hasn't already rendered them) ===
	if include_mode_cards:
		var mode_hdr: PanelContainer = CafeSocialTheme.make_ornate_section_header("آمار حالت‌های رتبه‌بندی", null)
		target_container.add_child(mode_hdr)

		var modes_vbox: VBoxContainer = VBoxContainer.new()
		modes_vbox.add_theme_constant_override("separation", 10)
		target_container.add_child(modes_vbox)

		var win_rank: int = int(history_data.get("win_rank", 0))
		var draw_rank: int = int(history_data.get("draw_rank", 0))
		var lose_rank: int = int(history_data.get("lose_rank", 0))
		var card_rank: RankingCard = RankingCard.new()
		card_rank.setup_mode("رده‌بندی دو نفره", "رقابتی آنلاین", win_rank, draw_rank, lose_rank, null)
		modes_vbox.add_child(card_rank)

		var win_cr: int = int(history_data.get("win_classic_rank", 0))
		var draw_cr: int = int(history_data.get("draw_classic_rank", 0))
		var lose_cr: int = int(history_data.get("lose_classic_rank", 0))
		var card_cr: RankingCard = RankingCard.new()
		card_cr.setup_mode("کلاسیک تک‌نفره", "هوش مصنوعی", win_cr, draw_cr, lose_cr, null)
		modes_vbox.add_child(card_cr)

		var r1: int = int(history_data.get("rank1_multi_rank", 0))
		var r2: int = int(history_data.get("rank2_multi_rank", 0))
		var rn: int = int(history_data.get("rankn_multi_rank", 0))
		var card_mr: RankingCard = RankingCard.new()
		card_mr.setup_multiplayer("رده‌بندی چندنفره", "رقابت گروهی", r1, r2, rn, null)
		modes_vbox.add_child(card_mr)

		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		target_container.add_child(spacer)

	# === 2. COMPUTE & PARTITION PER-GAME STATS ===
	var played_games: Array[Dictionary] = []
	var unplayed_games: Array[Dictionary] = []

	for g in GAMES_LIST:
		var k: String = str(g["key"])
		var is_multi: bool = bool(g.get("multi", false))
		var w: int = int(history_data.get("%s_win" % k, 0))
		var d: int = int(history_data.get("%s_draw" % k, 0))
		var l: int = int(history_data.get("%s_lose" % k, 0))
		var gr1: int = int(history_data.get("%s_rank1" % k, 0))
		var gr2: int = int(history_data.get("%s_rank2" % k, 0))
		var grn: int = int(history_data.get("%s_rankn" % k, 0))

		var c1: int = (gr1 + w) if is_multi else w
		var c2: int = (gr2 + d) if is_multi else d
		var c3: int = (grn + l) if is_multi else l
		var total_matches: int = c1 + c2 + c3
		var win_pct: float = (float(c1) / float(total_matches)) * 100.0 if total_matches > 0 else 0.0

		var item: Dictionary = {
			"id": str(g["id"]),
			"key": k,
			"name_fa": str(g["name_fa"]),
			"multi": is_multi,
			"c1": c1,
			"c2": c2,
			"c3": c3,
			"total": total_matches,
			"win_pct": win_pct
		}

		if total_matches > 0:
			played_games.append(item)
		else:
			unplayed_games.append(item)

	played_games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["total"]) > int(b["total"])
	)

	# Section header
	var sub_txt: String = "%s بازی فعال" % GameManager.to_fa_num(played_games.size()) if not played_games.is_empty() else ""
	target_container.add_child(CafeSocialTheme.make_ornate_section_header("آمار تفکیکی بازی‌ها", null, sub_txt))

	var games_cards_vbox: VBoxContainer = VBoxContainer.new()
	games_cards_vbox.add_theme_constant_override("separation", 10)

	# Interactive Filter & Sort Toolbar (shown when multiple played games exist)
	if played_games.size() > 1:
		var state: Dictionary = {"filter": "all", "sort": "played"}
		var toolbar_row: HBoxContainer = HBoxContainer.new()
		toolbar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar_row.add_theme_constant_override("separation", 6)
		target_container.add_child(toolbar_row)

		var btn_sort: Button = _create_toolbar_chip("مرتب‌سازی: پربازی‌ترین", false)
		btn_sort.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		toolbar_row.add_child(btn_sort)

		var tb_spacer: Control = Control.new()
		tb_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toolbar_row.add_child(tb_spacer)

		var filter_btns: Dictionary = {}
		var filter_defs: Array[Dictionary] = [
			{"id": "multi", "label": "چندنفره"},
			{"id": "two", "label": "دو نفره"},
			{"id": "all", "label": "همه"}
		]
		for fdef in filter_defs:
			var fid: String = str(fdef["id"])
			var fbtn: Button = _create_toolbar_chip(str(fdef["label"]), fid == "all")
			toolbar_row.add_child(fbtn)
			filter_btns[fid] = fbtn

		var rebuild_list: Callable = func():
			if not is_instance_valid(games_cards_vbox):
				return
			for ch in games_cards_vbox.get_children():
				ch.queue_free()

			var filtered: Array[Dictionary] = []
			var active_filter: String = str(state["filter"])
			for g_item in played_games:
				var is_m: bool = bool(g_item["multi"])
				if active_filter == "multi" and not is_m:
					continue
				if active_filter == "two" and is_m:
					continue
				filtered.append(g_item)

			var active_sort: String = str(state["sort"])
			if active_sort == "winrate":
				filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					if absf(float(a["win_pct"]) - float(b["win_pct"])) > 0.01:
						return float(a["win_pct"]) > float(b["win_pct"])
					return int(a["total"]) > int(b["total"])
				)
			else:
				filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					return int(a["total"]) > int(b["total"])
				)

			if filtered.is_empty():
				games_cards_vbox.add_child(_create_empty_card("در این دسته‌بندی هنوز بازی‌ای ثبت نشده است."))
			else:
				for g_info in filtered:
					games_cards_vbox.add_child(_create_game_stat_card(g_info))

		for fid_key in filter_btns.keys():
			var fid_str: String = str(fid_key)
			var fbtn_ref: Button = filter_btns[fid_key] as Button
			fbtn_ref.pressed.connect(func():
				AudioManager.sfx_tap()
				state["filter"] = fid_str
				for k_btn in filter_btns.keys():
					_style_toolbar_chip(filter_btns[k_btn] as Button, str(k_btn) == fid_str)
				rebuild_list.call()
			)

		btn_sort.pressed.connect(func():
			AudioManager.sfx_tap()
			if str(state["sort"]) == "played":
				state["sort"] = "winrate"
				btn_sort.text = "مرتب‌سازی: نرخ برد"
				_style_toolbar_chip(btn_sort, true)
			else:
				state["sort"] = "played"
				btn_sort.text = "مرتب‌سازی: پربازی‌ترین"
				_style_toolbar_chip(btn_sort, false)
			rebuild_list.call()
		)

		target_container.add_child(games_cards_vbox)
		rebuild_list.call()
	else:
		target_container.add_child(games_cards_vbox)
		if played_games.is_empty():
			games_cards_vbox.add_child(_create_empty_card("هنوز هیچ مسابقه‌ای ثبت نشده است."))
		else:
			for g_info in played_games:
				games_cards_vbox.add_child(_create_game_stat_card(g_info))

	# === 3. COLLAPSIBLE COMPACT UNPLAYED GAMES GRID ===
	if not unplayed_games.is_empty() and not played_games.is_empty():
		var unplayed_grid: GridContainer = GridContainer.new()
		unplayed_grid.columns = 2
		unplayed_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unplayed_grid.add_theme_constant_override("h_separation", 8)
		unplayed_grid.add_theme_constant_override("v_separation", 8)
		unplayed_grid.visible = false
		target_container.add_child(unplayed_grid)

		for u_info in unplayed_games:
			unplayed_grid.add_child(_create_unplayed_chip(u_info))

		var btn_toggle: Button = CafeSocialTheme.make_button(
			"▼ بازی‌های بدون سابقه (%s)" % GameManager.to_fa_num(unplayed_games.size()),
			"bronze",
			Vector2(0, 44),
			17
		)
		btn_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_toggle.pressed.connect(func():
			AudioManager.sfx_tap()
			unplayed_grid.visible = not unplayed_grid.visible
			if unplayed_grid.visible:
				btn_toggle.text = "▲ بستن بازی‌های بدون سابقه"
			else:
				btn_toggle.text = "▼ بازی‌های بدون سابقه (%s)" % GameManager.to_fa_num(unplayed_games.size())
		)
		target_container.add_child(btn_toggle)


static func _create_toolbar_chip(txt: String, is_active: bool) -> Button:
	var btn: Button = Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_override("font", _font_vazir)
	btn.add_theme_font_size_override("font_size", UITypography.scale_px(17, 15, 22))
	_style_toolbar_chip(btn, is_active)
	return btn


static func _style_toolbar_chip(btn: Button, is_active: bool) -> void:
	if not is_instance_valid(btn):
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.20, 0.08, 0.96) if is_active else Color(0.13, 0.08, 0.05, 0.92)
	sb.border_color = Color(0.96, 0.80, 0.32, 0.95) if is_active else Color(0.48, 0.36, 0.20, 0.72)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_color_override("font_color", CafeSocialTheme.COL_GOLD_BRIGHT if is_active else CafeSocialTheme.COL_WARM_CREAM)


static func _create_game_stat_card(info: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.96)
	sb.border_color = Color(0.56, 0.43, 0.23, 0.82)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(15)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", sb)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var is_multi: bool = bool(info.get("multi", false))
	var c1: int = int(info.get("c1", 0))
	var c2: int = int(info.get("c2", 0))
	var c3: int = int(info.get("c3", 0))
	var total_count: int = int(info.get("total", c1 + c2 + c3))
	var wr_pct: int = int(round(float(info.get("win_pct", 0.0))))

	# Left/Center Expanding Column: Header + Segmented Bar + 3 Metric Chips
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 7)
	hbox.add_child(col)

	# Row 1: Win-Rate Pill (Left) + Matches Count + Game Title (Right)
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row1)

	var wr_txt: String = ("%s٪ اول" if is_multi else "%s٪ برد") % GameManager.to_fa_num(wr_pct)
	var wr_col: Color = CafeSocialTheme.COL_EMERALD_TEXT
	var wr_bg: Color = CafeSocialTheme.COL_EMERALD_BG
	var wr_brd: Color = CafeSocialTheme.COL_EMERALD_BORDER
	if wr_pct < 35:
		wr_col = CafeSocialTheme.COL_CRIMSON_TEXT
		wr_bg = CafeSocialTheme.COL_CRIMSON_BG
		wr_brd = CafeSocialTheme.COL_CRIMSON_BORDER
	elif wr_pct < 55:
		wr_col = CafeSocialTheme.COL_GOLD_BRIGHT
		wr_bg = Color(0.24, 0.17, 0.06, 0.94)
		wr_brd = CafeSocialTheme.COL_GOLD_ANTIQUE
	row1.add_child(CafeSocialTheme.make_badge_pill(wr_txt, wr_col, wr_bg, wr_brd, 14))

	var lbl_matches: Label = Label.new()
	lbl_matches.text = "%s بازی" % GameManager.to_fa_num(total_count)
	lbl_matches.add_theme_font_override("font", _font_vazir)
	lbl_matches.add_theme_font_size_override("font_size", UITypography.scale_px(16, 15, 20))
	lbl_matches.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	row1.add_child(lbl_matches)

	var lbl_name: Label = Label.new()
	lbl_name.text = str(info["name_fa"])
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.clip_text = true
	lbl_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_name.add_theme_font_override("font", _font_hekayat)
	lbl_name.add_theme_font_size_override("font_size", UITypography.scale_px(22, 18, 28))
	lbl_name.add_theme_color_override("font_color", CafeSocialTheme.COL_IVORY)
	row1.add_child(lbl_name)

	# Row 2: Proportional Segmented Distribution Bar
	var bar_track: PanelContainer = PanelContainer.new()
	bar_track.custom_minimum_size = Vector2(0, 7)
	bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_track.clip_contents = true
	var track_sb: StyleBoxFlat = StyleBoxFlat.new()
	track_sb.bg_color = Color(0.07, 0.04, 0.02, 0.92)
	track_sb.set_corner_radius_all(4)
	track_sb.content_margin_left = 1.0
	track_sb.content_margin_right = 1.0
	track_sb.content_margin_top = 1.0
	track_sb.content_margin_bottom = 1.0
	bar_track.add_theme_stylebox_override("panel", track_sb)
	col.add_child(bar_track)

	var seg_row: HBoxContainer = HBoxContainer.new()
	seg_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seg_row.add_theme_constant_override("separation", 2)
	bar_track.add_child(seg_row)

	var seg_vals: Array[int] = [c3, c2, c1]
	var seg_cols: Array[Color] = [
		Color(0.56, 0.44, 0.30, 0.85) if is_multi else Color(0.86, 0.34, 0.34, 0.92),
		Color(0.84, 0.80, 0.72, 0.90) if is_multi else Color(0.92, 0.74, 0.28, 0.92),
		Color(0.98, 0.80, 0.28, 0.98) if is_multi else Color(0.30, 0.84, 0.48, 0.96)
	]
	if total_count > 0:
		for i in range(seg_vals.size()):
			if seg_vals[i] <= 0:
				continue
			var seg: Panel = Panel.new()
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.size_flags_vertical = Control.SIZE_EXPAND_FILL
			seg.size_flags_stretch_ratio = float(seg_vals[i])
			var seg_sb: StyleBoxFlat = StyleBoxFlat.new()
			seg_sb.bg_color = seg_cols[i]
			seg_sb.set_corner_radius_all(2)
			seg.add_theme_stylebox_override("panel", seg_sb)
			seg_row.add_child(seg)

	# Row 3: 3 Compact Stat Chips (RTL order: Loss/Other left -> Draw/2nd middle -> Win/1st right)
	var row3: HBoxContainer = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 6)
	col.add_child(row3)

	if is_multi:
		row3.add_child(_create_stat_pill("سایر: %s" % GameManager.to_fa_num(c3), CafeSocialTheme.COL_MUTED_SAND, Color(0.16, 0.11, 0.07, 0.90), 14))
		row3.add_child(_create_stat_pill("دوم: %s" % GameManager.to_fa_num(c2), CafeSocialTheme.COL_IVORY, Color(0.19, 0.15, 0.10, 0.92), 14))
		row3.add_child(_create_stat_pill("اول: %s" % GameManager.to_fa_num(c1), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.26, 0.19, 0.06, 0.95), 14))
	else:
		row3.add_child(_create_stat_pill("باخت: %s" % GameManager.to_fa_num(c3), CafeSocialTheme.COL_CRIMSON_TEXT, Color(0.24, 0.09, 0.09, 0.90), 14))
		row3.add_child(_create_stat_pill("مساوی: %s" % GameManager.to_fa_num(c2), CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.22, 0.16, 0.07, 0.90), 14))
		row3.add_child(_create_stat_pill("برد: %s" % GameManager.to_fa_num(c1), CafeSocialTheme.COL_EMERALD_TEXT, Color(0.10, 0.24, 0.15, 0.92), 14))

	# Right Anchor: Framed Game Icon Plaque (68x68)
	var icon_plaque: PanelContainer = PanelContainer.new()
	icon_plaque.custom_minimum_size = Vector2(68, 68)
	icon_plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb_icon: StyleBoxFlat = StyleBoxFlat.new()
	sb_icon.bg_color = Color(0.08, 0.05, 0.03, 1.0)
	sb_icon.set_border_width_all(1)
	sb_icon.border_color = Color(0.84, 0.67, 0.30, 0.85)
	sb_icon.set_corner_radius_all(12)
	sb_icon.content_margin_left = 3.0
	sb_icon.content_margin_right = 3.0
	sb_icon.content_margin_top = 3.0
	sb_icon.content_margin_bottom = 3.0
	icon_plaque.add_theme_stylebox_override("panel", sb_icon)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = get_game_icon_texture(str(info["key"]))
	if icon_tex != null:
		icon_rect.texture = icon_tex
	icon_plaque.add_child(icon_rect)
	hbox.add_child(icon_plaque)

	return panel


static func _create_unplayed_chip(info: Dictionary) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.07, 0.04, 0.82)
	sb.border_color = Color(0.42, 0.32, 0.18, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", sb)

	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(hb)

	var lbl: Label = Label.new()
	lbl.text = str(info["name_fa"])
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_override("font", _font_vazir)
	lbl.add_theme_font_size_override("font_size", UITypography.scale_px(16, 15, 20))
	lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	hb.add_child(lbl)

	var ico: TextureRect = TextureRect.new()
	ico.custom_minimum_size = Vector2(30, 30)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.modulate = Color(0.75, 0.72, 0.68, 0.85)
	var tex: Texture2D = get_game_icon_texture(str(info["key"]))
	if tex != null:
		ico.texture = tex
	hb.add_child(ico)

	return p


static func _create_stat_pill(text_content: String, text_color: Color, bg_color: Color, font_size: int = 16) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_border_width_all(1)
	sb.border_color = Color(text_color.r, text_color.g, text_color.b, 0.45)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_right = 6.0
	sb.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", sb)

	var lbl: Label = Label.new()
	lbl.text = text_content
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_vazir)
	lbl.add_theme_font_size_override("font_size", UITypography.scale_px(font_size, 15, 22))
	lbl.add_theme_color_override("font_color", text_color)
	pill.add_child(lbl)

	return pill


static func _create_empty_card(msg: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 96)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.04, 0.90)
	sb.border_color = Color(0.48, 0.36, 0.20, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	p.add_theme_stylebox_override("panel", sb)

	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font_vazir)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", CafeSocialTheme.COL_MUTED_SAND)
	p.add_child(lbl)
	return p


static func get_game_icon_texture(key: String) -> Texture2D:
	var png_path: String = "res://assets/images/games/%s.png" % key.to_lower()
	if ResourceLoader.exists(png_path):
		return load(png_path)
	var jpg_path: String = "res://assets/images/games/%s.jpg" % key.to_lower()
	if ResourceLoader.exists(jpg_path):
		return load(jpg_path)
	return null
