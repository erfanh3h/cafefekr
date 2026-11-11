class_name GamesHistoryViewHelper
extends RefCounted

# Helper to construct rich, tactile, and highly readable games history UI
# Used by both UserProfileDialog (when inspecting any player's details)
# and GameHistoryDialog (under the "Games History" tab for user's own statistics).

static var _font_hekayat = preload("res://assets/fonts/hekayat.ttf")

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
]

static func populate_games_history(target_container: VBoxContainer, history_data: Dictionary) -> void:
	if not is_instance_valid(target_container):
		return

	for child in target_container.get_children():
		child.queue_free()

	if history_data == null or history_data.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "هنوز آماری برای بازی‌ها ثبت نشده است."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", _font_hekayat)
		empty_lbl.add_theme_font_size_override("font_size", 28)
		empty_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72))
		target_container.add_child(empty_lbl)
		return

	# === 1. TOP MODE SUMMARY CARDS ===
	var mode_summary_title = Label.new()
	mode_summary_title.text = "🏆 آمار حالت‌های رتبه‌بندی"
	mode_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_summary_title.add_theme_font_override("font", _font_hekayat)
	mode_summary_title.add_theme_font_size_override("font_size", 34)
	mode_summary_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	target_container.add_child(mode_summary_title)

	var modes_vbox = VBoxContainer.new()
	modes_vbox.theme_override_constants/separation = 12
	target_container.add_child(modes_vbox)

	# Card A: Rank (دو نفره)
	var win_rank = int(history_data.get("win_rank", 0))
	var draw_rank = int(history_data.get("draw_rank", 0))
	var lose_rank = int(history_data.get("lose_rank", 0))
	var card_rank = _create_mode_card(
		"🏆 رده‌بندی دو نفره (Rank)",
		win_rank, draw_rank, lose_rank,
		"برد", "مساوی", "باخت"
	)
	modes_vbox.add_child(card_rank)

	# Card B: Classic Rank (تک‌نفره)
	var win_cr = int(history_data.get("win_classic_rank", 0))
	var draw_cr = int(history_data.get("draw_classic_rank", 0))
	var lose_cr = int(history_data.get("lose_classic_rank", 0))
	var card_cr = _create_mode_card(
		"🤖 کلاسیک تک‌نفره (هوش مصنوعی)",
		win_cr, draw_cr, lose_cr,
		"برد", "مساوی", "باخت"
	)
	modes_vbox.add_child(card_cr)

	# Card C: Multi-Rank (چند نفره)
	var r1 = int(history_data.get("rank1_multi_rank", 0))
	var r2 = int(history_data.get("rank2_multi_rank", 0))
	var rn = int(history_data.get("rankn_multi_rank", 0))
	var card_mr = _create_mode_card(
		"👥 رده‌بندی چندنفره (منچ، ریسک، اونو)",
		r1, r2, rn,
		"اول 🥇", "دوم 🥈", "سایر 🥉"
	)
	modes_vbox.add_child(card_mr)

	# === 2. GAMES BREAKDOWN SECTION ===
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	target_container.add_child(spacer)

	var games_header_box = HBoxContainer.new()
	games_header_box.alignment = BoxContainer.ALIGNMENT_END
	target_container.add_child(games_header_box)

	var games_title = Label.new()
	games_title.text = "🎮 آمار بازی‌ها به تفکیک"
	games_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	games_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	games_title.add_theme_font_override("font", _font_hekayat)
	games_title.add_theme_font_size_override("font_size", 34)
	games_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	games_header_box.add_child(games_title)

	# Compute and partition games
	var played_games: Array[Dictionary] = []
	var unplayed_games: Array[Dictionary] = []

	for g in GAMES_LIST:
		var k = str(g["key"])
		var is_multi = bool(g.get("multi", false))
		var w = int(history_data.get("%s_win" % k, 0))
		var d = int(history_data.get("%s_draw" % k, 0))
		var l = int(history_data.get("%s_lose" % k, 0))
		var gr1 = int(history_data.get("%s_rank1" % k, 0))
		var gr2 = int(history_data.get("%s_rank2" % k, 0))
		var grn = int(history_data.get("%s_rankn" % k, 0))

		var total_matches = 0
		if is_multi:
			total_matches = w + d + l + gr1 + gr2 + grn
		else:
			total_matches = w + d + l

		var item = {
			"id": g["id"],
			"key": k,
			"name_fa": g["name_fa"],
			"multi": is_multi,
			"win": w,
			"draw": d,
			"lose": l,
			"rank1": gr1,
			"rank2": gr2,
			"rankn": grn,
			"total": total_matches
		}

		if total_matches > 0:
			played_games.append(item)
		else:
			unplayed_games.append(item)

	# Sort played games by total played descending
	played_games.sort_custom(func(a, b):
		return a["total"] > b["total"]
	)

	var games_cards_vbox = VBoxContainer.new()
	games_cards_vbox.theme_override_constants/separation = 10
	target_container.add_child(games_cards_vbox)

	if played_games.is_empty():
		var no_games_card = _create_empty_card("هنوز هیچ بازی‌ای با این کاربر انجام نشده است.")
		games_cards_vbox.add_child(no_games_card)
	else:
		for g_info in played_games:
			var card = _create_game_stat_card(g_info)
			games_cards_vbox.add_child(card)

	# If there are unplayed games, offer an expandable toggle section
	if not unplayed_games.is_empty() and not played_games.is_empty():
		var unplayed_container = VBoxContainer.new()
		unplayed_container.theme_override_constants/separation = 10
		unplayed_container.visible = false
		target_container.add_child(unplayed_container)

		for g_info in unplayed_games:
			var card = _create_game_stat_card(g_info, true)
			unplayed_container.add_child(card)

		var btn_toggle = Button.new()
		btn_toggle.text = "▼ مشاهده سایر بازی‌ها (%s)" % GameManager.to_fa_num(unplayed_games.size())
		btn_toggle.custom_minimum_size = Vector2(300, 60)
		btn_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_toggle.add_theme_font_override("font", _font_hekayat)
		btn_toggle.add_theme_font_size_override("font_size", 24)
		KenneyUI.style_button(btn_toggle, KenneyUI.COLOR_GREY)
		btn_toggle.pressed.connect(func():
			AudioManager.sfx_tap()
			unplayed_container.visible = not unplayed_container.visible
			if unplayed_container.visible:
				btn_toggle.text = "▲ بستن سایر بازی‌ها"
			else:
				btn_toggle.text = "▼ مشاهده سایر بازی‌ها (%s)" % GameManager.to_fa_num(unplayed_games.size())
		)
		target_container.add_child(btn_toggle)

static func _create_mode_card(title_text: String, val1: int, val2: int, val3: int, label1: String, label2: String, label3: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.09, 0.05, 0.94)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.70, 0.52, 0.22, 0.85)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_right = 18.0
	sb.content_margin_bottom = 14.0
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.theme_override_constants/separation = 8
	panel.add_child(vbox)

	# Header row
	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)

	var total_matches = val1 + val2 + val3
	if total_matches > 0:
		var lbl_total = Label.new()
		lbl_total.text = "%s بازی" % GameManager.to_fa_num(total_matches)
		lbl_total.add_theme_font_override("font", _font_hekayat)
		lbl_total.add_theme_font_size_override("font_size", 24)
		lbl_total.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
		header_row.add_child(lbl_total)

	var lbl_title = Label.new()
	lbl_title.text = title_text
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.add_theme_font_override("font", _font_hekayat)
	lbl_title.add_theme_font_size_override("font_size", 28)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	header_row.add_child(lbl_title)

	# Stats pill row
	var stats_row = HBoxContainer.new()
	stats_row.theme_override_constants/separation = 12
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stats_row)

	# Win / Rank 1 (Green)
	var pill1 = _create_stat_pill("%s: %s" % [label1, GameManager.to_fa_num(val1)], Color(0.35, 0.88, 0.45), Color(0.12, 0.28, 0.15, 0.95))
	pill1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(pill1)

	# Draw / Rank 2 (Yellow)
	var pill2 = _create_stat_pill("%s: %s" % [label2, GameManager.to_fa_num(val2)], Color(1.0, 0.85, 0.35), Color(0.28, 0.24, 0.10, 0.95))
	pill2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(pill2)

	# Lose / Rank 3+ (Red)
	var pill3 = _create_stat_pill("%s: %s" % [label3, GameManager.to_fa_num(val3)], Color(0.95, 0.45, 0.45), Color(0.30, 0.12, 0.12, 0.95))
	pill3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(pill3)

	return panel

static func _create_game_stat_card(info: Dictionary, is_dimmed: bool = false) -> PanelContainer:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	if is_dimmed:
		sb.bg_color = Color(0.10, 0.07, 0.04, 0.85)
		sb.border_color = Color(0.35, 0.26, 0.16, 0.5)
	else:
		sb.bg_color = Color(0.16, 0.10, 0.06, 0.95)
		sb.border_color = Color(0.55, 0.40, 0.20, 0.8)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.theme_override_constants/separation = 16
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# Left: Game Icon Plaque
	var icon_plaque = PanelContainer.new()
	icon_plaque.custom_minimum_size = Vector2(76, 76)
	var sb_icon = StyleBoxFlat.new()
	sb_icon.bg_color = Color(0.08, 0.05, 0.03, 1.0)
	sb_icon.border_width_left = 2
	sb_icon.border_width_top = 2
	sb_icon.border_width_right = 2
	sb_icon.border_width_bottom = 2
	sb_icon.border_color = Color(0.85, 0.70, 0.35, 0.8)
	sb_icon.set_corner_radius_all(14)
	icon_plaque.add_theme_stylebox_override("panel", sb_icon)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(68, 68)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon_tex = get_game_icon_texture(info["key"])
	if icon_tex != null:
		icon_rect.texture = icon_tex
	icon_plaque.add_child(icon_rect)
	hbox.add_child(icon_plaque)

	# Center / Right Column: Info & Stats
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.theme_override_constants/separation = 6
	hbox.add_child(col)

	# Row 1: Game Persian Name + Total matches badge
	var row1 = HBoxContainer.new()
	col.add_child(row1)

	var total_count = int(info["total"])
	var lbl_matches = Label.new()
	if total_count > 0:
		lbl_matches.text = "%s مسابقه" % GameManager.to_fa_num(total_count)
		lbl_matches.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	else:
		lbl_matches.text = "بدون مسابقه"
		lbl_matches.add_theme_color_override("font_color", Color(0.60, 0.55, 0.50))
	lbl_matches.add_theme_font_override("font", _font_hekayat)
	lbl_matches.add_theme_font_size_override("font_size", 22)
	row1.add_child(lbl_matches)

	var lbl_name = Label.new()
	lbl_name.text = str(info["name_fa"])
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_name.add_theme_font_override("font", _font_hekayat)
	lbl_name.add_theme_font_size_override("font_size", 30)
	lbl_name.add_theme_color_override("font_color", Color.WHITE if not is_dimmed else Color(0.75, 0.70, 0.65))
	row1.add_child(lbl_name)

	# Row 2: Stat Pills
	var row2 = HBoxContainer.new()
	row2.theme_override_constants/separation = 8
	col.add_child(row2)

	var is_multi = bool(info.get("multi", false))
	if is_multi:
		var r1_cnt = int(info["rank1"])
		var r2_cnt = int(info["rank2"])
		var rn_cnt = int(info["rankn"])
		# If user played classic rank or 2-player on multi game, check win/draw/lose
		var w_cnt = int(info["win"])
		var d_cnt = int(info["draw"])
		var l_cnt = int(info["lose"])

		var p1 = _create_stat_pill("اول: %s" % GameManager.to_fa_num(max(r1_cnt, w_cnt)), Color(0.35, 0.88, 0.45), Color(0.12, 0.28, 0.15, 0.85), 20)
		p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p1)

		var p2 = _create_stat_pill("دوم: %s" % GameManager.to_fa_num(max(r2_cnt, d_cnt)), Color(1.0, 0.85, 0.35), Color(0.28, 0.24, 0.10, 0.85), 20)
		p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p2)

		var p3 = _create_stat_pill("سایر: %s" % GameManager.to_fa_num(max(rn_cnt, l_cnt)), Color(0.95, 0.45, 0.45), Color(0.30, 0.12, 0.12, 0.85), 20)
		p3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p3)
	else:
		var w_cnt = int(info["win"])
		var d_cnt = int(info["draw"])
		var l_cnt = int(info["lose"])

		var p1 = _create_stat_pill("برد: %s" % GameManager.to_fa_num(w_cnt), Color(0.35, 0.88, 0.45), Color(0.12, 0.28, 0.15, 0.85), 20)
		p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p1)

		var p2 = _create_stat_pill("مساوی: %s" % GameManager.to_fa_num(d_cnt), Color(1.0, 0.85, 0.35), Color(0.28, 0.24, 0.10, 0.85), 20)
		p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p2)

		var p3 = _create_stat_pill("باخت: %s" % GameManager.to_fa_num(l_cnt), Color(0.95, 0.45, 0.45), Color(0.30, 0.12, 0.12, 0.85), 20)
		p3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(p3)

	return panel

static func _create_stat_pill(text_content: String, text_color: Color, bg_color: Color, font_size: int = 22) -> PanelContainer:
	var pill = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(text_color.r, text_color.g, text_color.b, 0.6)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = text_content
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_hekayat)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", text_color)
	pill.add_child(lbl)

	return pill

static func _create_empty_card(msg: String) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.8)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.4, 0.3, 0.2, 0.5)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16.0
	sb.content_margin_top = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 16.0
	p.add_theme_stylebox_override("panel", sb)

	var lbl = Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_hekayat)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.68))
	p.add_child(lbl)
	return p

static func get_game_icon_texture(key: String) -> Texture2D:
	var png_path = "res://assets/images/games/%s.png" % key.to_lower()
	if ResourceLoader.exists(png_path):
		return load(png_path)
	var jpg_path = "res://assets/images/games/%s.jpg" % key.to_lower()
	if ResourceLoader.exists(jpg_path):
		return load(jpg_path)
	return null
