extends PanelContainer

# Game History Dialog Controller
# Fetches match history from /my-game-history
# Displays list of played games across Rank, Classic Rank, and Lobby modes.
# Tapping any game opens a rich detail view with player stats and round breakdown.

signal closed()

@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var btn_back: Button = $Margin/VBox/TopRow/BtnBack
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var lbl_loading: Label = $Margin/VBox/LblLoading
@onready var scroll_list: ScrollContainer = $Margin/VBox/ScrollList
@onready var list_container: VBoxContainer = $Margin/VBox/ScrollList/ListContainer
@onready var scroll_details: ScrollContainer = $Margin/VBox/ScrollDetails
@onready var details_container: VBoxContainer = $Margin/VBox/ScrollDetails/DetailsContainer
@onready var btn_close: Button = $Margin/VBox/BtnClose

var _font_hekayat = preload("res://assets/fonts/hekayat.ttf")
var _history_items: Array = []
var _selected_game: Dictionary = {}

func _ready() -> void:
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_back, KenneyUI.COLOR_YELLOW)
	
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	btn_close_top.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	btn_back.pressed.connect(func():
		AudioManager.sfx_tap()
		show_list_view()
	)

func open() -> void:
	show_list_view()
	ActionVFXManager.animate_dialog_open(self, null, true)
	load_history()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func show_list_view() -> void:
	lbl_title.text = "📜 تاریخچه بازی‌ها"
	btn_back.visible = false
	scroll_list.visible = true
	scroll_details.visible = false

func show_details_view() -> void:
	lbl_title.text = "🔍 جزئیات مسابقه"
	btn_back.visible = true
	scroll_list.visible = false
	scroll_details.visible = true

func load_history() -> void:
	for child in list_container.get_children():
		child.queue_free()
	
	lbl_loading.visible = true
	lbl_loading.text = "در حال دریافت تاریخچه بازی‌ها..."
	
	NetworkManager.api.get_my_game_history(_on_history_received)

func _on_history_received(success: bool, _code: int, data: Variant) -> void:
	lbl_loading.visible = false
	if not success or typeof(data) != TYPE_DICTIONARY or not data.has("result"):
		lbl_loading.text = "خطا در دریافت تاریخچه بازی‌ها"
		lbl_loading.visible = true
		return
	
	_history_items = data["result"]
	if _history_items.is_empty():
		lbl_loading.text = "هنوز مسابقه‌ای ثبت نشده است."
		lbl_loading.visible = true
		return
	
	var my_uid = str(GameManager.get_user_id())
	for i in range(_history_items.size()):
		var item = _history_items[i]
		if typeof(item) == TYPE_DICTIONARY:
			var card = _create_game_summary_card(item, my_uid)
			list_container.add_child(card)

func _create_game_summary_card(game: Dictionary, my_uid: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 160)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.08, 0.05, 0.90)
	style_normal.border_color = Color(0.70, 0.52, 0.28, 0.85)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(14)
	style_normal.content_margin_left = 18
	style_normal.content_margin_right = 18
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.18, 0.12, 0.08, 0.95)
	style_hover.border_color = Color(1.0, 0.85, 0.40, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(14)
	style_hover.content_margin_left = 18
	style_hover.content_margin_right = 18
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus", style_normal)
	
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(row)
	
	# Determine game mode
	var mode_raw = str(game.get("game_score_type", "Rank"))
	var mode_title = "رده‌بندی"
	var mode_color = Color(1.0, 0.85, 0.40) # Gold
	if mode_raw == "ClassicRank":
		mode_title = "رنک تک‌نفره"
		mode_color = Color(0.45, 0.82, 1.0) # Light blue
	elif mode_raw == "Lobby":
		mode_title = "اتاق دوستانه"
		mode_color = Color(0.60, 0.95, 0.60) # Green
	
	# Determine winner & my result
	var my_res = str(game.get("my_result", ""))
	var winner_id = str(game.get("winner_id", ""))
	if my_res.is_empty():
		if winner_id == my_uid:
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"
	
	# 1. Result Badge (Leftmost)
	var badge_frame = PanelContainer.new()
	badge_frame.custom_minimum_size = Vector2(100, 70)
	badge_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_style = StyleBoxFlat.new()
	b_style.set_corner_radius_all(12)
	
	var res_text = "برد"
	if my_res == "win":
		b_style.bg_color = Color(0.18, 0.55, 0.22, 0.95)
		res_text = "برد 🏆"
	elif my_res == "lose":
		b_style.bg_color = Color(0.65, 0.18, 0.18, 0.95)
		res_text = "باخت"
	elif my_res == "draw":
		b_style.bg_color = Color(0.45, 0.45, 0.45, 0.95)
		res_text = "مساوی"
	else:
		b_style.bg_color = Color(0.35, 0.30, 0.25, 0.90)
		res_text = "ناتمام"
	badge_frame.add_theme_stylebox_override("panel", b_style)
	
	var lbl_res = Label.new()
	lbl_res.text = res_text
	lbl_res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_res.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_res.add_theme_font_override("font", _font_hekayat)
	lbl_res.add_theme_font_size_override("font_size", 28)
	lbl_res.add_theme_color_override("font_color", Color.WHITE)
	badge_frame.add_child(lbl_res)
	row.add_child(badge_frame)
	
	# 2. Opponent Avatar & Name
	var opp_name = "حریف"
	var opp_avatar_id = 0
	var users_info = game.get("users_info", [])
	for u in users_info:
		if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
			opp_name = str(u.get("username", "حریف"))
			opp_avatar_id = int(u.get("image", 0))
			break
	if mode_raw == "ClassicRank" and opp_name == "حریف":
		opp_name = "ربات هوشمند"
		opp_avatar_id = 1
	
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(76, 76)
	av_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var af_sb = StyleBoxFlat.new()
	af_sb.bg_color = Color(0.1, 0.07, 0.04, 0.9)
	af_sb.set_corner_radius_all(10)
	af_sb.set_border_width_all(2)
	af_sb.border_color = Color(0.85, 0.70, 0.35, 0.85)
	av_frame.add_theme_stylebox_override("panel", af_sb)
	
	var av_img = TextureRect.new()
	av_img.custom_minimum_size = Vector2(72, 72)
	av_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av_path = "res://assets/icons/Avatars/%d.png" % opp_avatar_id
	if ResourceLoader.exists(av_path):
		av_img.texture = load(av_path)
	else:
		av_img.texture = load("res://assets/icons/Avatars/0.png")
	av_frame.add_child(av_img)
	row.add_child(av_frame)
	
	# 3. Main Text Column (Opponent Name, Games, Mode & Date)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	
	var lbl_opp = Label.new()
	lbl_opp.text = "حریف: " + opp_name
	lbl_opp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_opp.add_theme_font_override("font", _font_hekayat)
	lbl_opp.add_theme_font_size_override("font_size", 32)
	lbl_opp.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	col.add_child(lbl_opp)
	
	# Games string
	var games_arr = game.get("game_types", [])
	var games_display = []
	for gt in games_arr:
		games_display.append(GameRegistry.get_display_name_fa(str(gt)))
	var games_str = "، ".join(games_display) if not games_display.is_empty() else "بازی"
	
	var lbl_games = Label.new()
	lbl_games.text = "بازی: " + games_str
	lbl_games.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_games.add_theme_font_override("font", _font_hekayat)
	lbl_games.add_theme_font_size_override("font_size", 24)
	lbl_games.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	col.add_child(lbl_games)
	
	# Mode & Date line
	var s_date_raw = str(game.get("start_date", ""))
	var date_short = _format_short_date(s_date_raw)
	
	var lbl_meta = Label.new()
	lbl_meta.text = "%s • %s" % [mode_title, date_short]
	lbl_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_meta.add_theme_font_override("font", _font_hekayat)
	lbl_meta.add_theme_font_size_override("font_size", 22)
	lbl_meta.add_theme_color_override("font_color", mode_color)
	col.add_child(lbl_meta)
	
	row.add_child(col)
	
	# 4. Score Display
	var scores = game.get("user_scores", [])
	var score_str = ""
	if scores.size() >= 2:
		# Put caller's score first
		var p1_uid = str(game.get("user1_id", ""))
		if p1_uid == my_uid:
			score_str = "%s - %s" % [GameManager.to_fa_num(scores[0]), GameManager.to_fa_num(scores[1])]
		else:
			score_str = "%s - %s" % [GameManager.to_fa_num(scores[1]), GameManager.to_fa_num(scores[0])]
	elif not scores.is_empty():
		score_str = GameManager.to_fa_num(scores[0])
	
	if not score_str.is_empty():
		var score_box = PanelContainer.new()
		score_box.custom_minimum_size = Vector2(85, 56)
		score_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb_style = StyleBoxFlat.new()
		sb_style.bg_color = Color(0.08, 0.05, 0.03, 0.85)
		sb_style.set_corner_radius_all(10)
		score_box.add_theme_stylebox_override("panel", sb_style)
		
		var lbl_score = Label.new()
		lbl_score.text = score_str
		lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_score.add_theme_font_override("font", _font_hekayat)
		lbl_score.add_theme_font_size_override("font_size", 30)
		lbl_score.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
		score_box.add_child(lbl_score)
		row.add_child(score_box)
	
	# 5. Detail arrow indicator
	var lbl_arrow = Label.new()
	lbl_arrow.text = "‹"
	lbl_arrow.add_theme_font_override("font", _font_hekayat)
	lbl_arrow.add_theme_font_size_override("font_size", 42)
	lbl_arrow.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	lbl_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl_arrow)
	
	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		show_game_details(game)
	)
	
	return btn

func show_game_details(game: Dictionary) -> void:
	_selected_game = game
	show_details_view()
	
	for child in details_container.get_children():
		child.queue_free()
	
	var my_uid = str(GameManager.get_user_id())
	var mode_raw = str(game.get("game_score_type", "Rank"))
	var mode_title = "مسابقه رده‌بندی (Rank)"
	if mode_raw == "ClassicRank":
		mode_title = "رنک تک‌نفره (کلاسیک)"
	elif mode_raw == "Lobby":
		mode_title = "اتاق دوستانه (لابی)"
	
	var winner_id = str(game.get("winner_id", ""))
	var my_res = str(game.get("my_result", ""))
	if my_res.is_empty():
		if winner_id == my_uid:
			my_res = "win"
		elif winner_id == "0":
			my_res = "draw"
		elif not winner_id.is_empty():
			my_res = "lose"
		else:
			my_res = "unfinished"
	
	# === 1. TOP RESULT BANNER CARD ===
	var top_card = PanelContainer.new()
	var tc_style = StyleBoxFlat.new()
	tc_style.set_corner_radius_all(16)
	tc_style.set_border_width_all(2)
	tc_style.content_margin_left = 24
	tc_style.content_margin_right = 24
	tc_style.content_margin_top = 18
	tc_style.content_margin_bottom = 18
	
	var res_headline = "پیروزی شما! 🏆"
	if my_res == "win":
		tc_style.bg_color = Color(0.12, 0.40, 0.16, 0.95)
		tc_style.border_color = Color(0.40, 0.85, 0.45, 1.0)
		res_headline = "تبریک! برنده این مسابقه شدید 🏆"
	elif my_res == "lose":
		tc_style.bg_color = Color(0.45, 0.12, 0.12, 0.95)
		tc_style.border_color = Color(0.85, 0.35, 0.35, 1.0)
		res_headline = "در این مسابقه شکست خوردید"
	elif my_res == "draw":
		tc_style.bg_color = Color(0.25, 0.22, 0.18, 0.95)
		tc_style.border_color = Color(0.75, 0.65, 0.45, 1.0)
		res_headline = "این مسابقه مساوی شد"
	else:
		tc_style.bg_color = Color(0.20, 0.16, 0.12, 0.95)
		tc_style.border_color = Color(0.60, 0.50, 0.35, 1.0)
		res_headline = "مسابقه ناتمام ماند"
	top_card.add_theme_stylebox_override("panel", tc_style)
	
	var tc_vbox = VBoxContainer.new()
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_vbox.add_theme_constant_override("separation", 8)
	top_card.add_child(tc_vbox)
	
	var lbl_head = Label.new()
	lbl_head.text = res_headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_override("font", _font_hekayat)
	lbl_head.add_theme_font_size_override("font_size", 36)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	tc_vbox.add_child(lbl_head)
	
	var s_date_raw = str(game.get("start_date", ""))
	var lbl_date_mode = Label.new()
	lbl_date_mode.text = "%s  |  زمان شروع: %s" % [mode_title, _format_full_date(s_date_raw)]
	lbl_date_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date_mode.add_theme_font_override("font", _font_hekayat)
	lbl_date_mode.add_theme_font_size_override("font_size", 24)
	lbl_date_mode.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	tc_vbox.add_child(lbl_date_mode)
	
	details_container.add_child(top_card)
	
	# === 2. PLAYERS HEAD-TO-HEAD SECTION ===
	var h2h_card = PanelContainer.new()
	var h2h_style = StyleBoxFlat.new()
	h2h_style.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	h2h_style.border_color = Color(0.80, 0.65, 0.35, 0.9)
	h2h_style.set_border_width_all(2)
	h2h_style.set_corner_radius_all(14)
	h2h_style.content_margin_left = 20
	h2h_style.content_margin_right = 20
	h2h_style.content_margin_top = 18
	h2h_style.content_margin_bottom = 18
	h2h_card.add_theme_stylebox_override("panel", h2h_style)
	
	var h2h_row = HBoxContainer.new()
	h2h_row.alignment = BoxContainer.ALIGNMENT_CENTER
	h2h_row.add_theme_constant_override("separation", 24)
	h2h_card.add_child(h2h_row)
	
	# Gather players info
	var users_info = game.get("users_info", [])
	var scores = game.get("user_scores", [])
	
	var p_you: Dictionary = {}
	var p_opp: Dictionary = {}
	var score_you = 0
	var score_opp = 0
	
	for idx in range(users_info.size()):
		var u = users_info[idx]
		var sc = scores[idx] if idx < scores.size() else 0
		if str(u.get("user_id", "")) == my_uid:
			p_you = u
			score_you = sc
		else:
			p_opp = u
			score_opp = sc
	
	if p_you.is_empty():
		p_you = {"username": GameManager.get_username(), "image": GameManager.get_avatar_id()}
		score_you = scores[0] if scores.size() > 0 else 0
		score_opp = scores[1] if scores.size() > 1 else 0
	
	if p_opp.is_empty():
		p_opp = {"username": "حریف", "image": 0}
		if mode_raw == "ClassicRank":
			p_opp = {"username": "ربات هوشمند", "image": 1}
	
	# Left: You
	var you_col = _create_player_column("شما (" + str(p_you.get("username", "")) + ")", int(p_you.get("image", 0)), score_you, my_res == "win")
	h2h_row.add_child(you_col)
	
	# Middle: VS & Score
	var vs_box = VBoxContainer.new()
	vs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vs_box.add_theme_constant_override("separation", 6)
	
	var lbl_vs = Label.new()
	lbl_vs.text = "VS"
	lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_vs.add_theme_font_override("font", _font_hekayat)
	lbl_vs.add_theme_font_size_override("font_size", 38)
	lbl_vs.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	vs_box.add_child(lbl_vs)
	
	var lbl_final_score = Label.new()
	lbl_final_score.text = "%s : %s" % [GameManager.to_fa_num(score_you), GameManager.to_fa_num(score_opp)]
	lbl_final_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_final_score.add_theme_font_override("font", _font_hekayat)
	lbl_final_score.add_theme_font_size_override("font_size", 34)
	lbl_final_score.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	vs_box.add_child(lbl_final_score)
	
	h2h_row.add_child(vs_box)
	
	# Right: Opponent
	var opp_col = _create_player_column(str(p_opp.get("username", "حریف")), int(p_opp.get("image", 0)), score_opp, my_res == "lose")
	h2h_row.add_child(opp_col)
	
	details_container.add_child(h2h_card)
	
	# === 3. ROUNDS / MINI-GAMES BREAKDOWN ===
	var rounds_title = Label.new()
	rounds_title.text = "🎮 بازی‌های این مسابقه"
	rounds_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounds_title.add_theme_font_override("font", _font_hekayat)
	rounds_title.add_theme_font_size_override("font_size", 32)
	rounds_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	details_container.add_child(rounds_title)
	
	var rounds = game.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not rounds.is_empty():
		for r_idx in range(rounds.size()):
			var r_data = rounds[r_idx]
			var r_card = _create_round_row(r_idx + 1, r_data, my_uid)
			details_container.add_child(r_card)
	else:
		# Fallback to game_types list if no rounds saved in database
		var game_types = game.get("game_types", [])
		var winner_list = game.get("winner_list", [])
		if not game_types.is_empty():
			for g_idx in range(game_types.size()):
				var gtype = str(game_types[g_idx])
				var w_val = winner_list[g_idx] if g_idx < winner_list.size() else -1
				var pseudo_round = {
					"game_type": gtype,
					"winner_id": w_val
				}
				var r_card = _create_round_row(g_idx + 1, pseudo_round, my_uid)
				details_container.add_child(r_card)
		else:
			var empty_lbl = Label.new()
			empty_lbl.text = "اطلاعات جزئیات راندها در دسترس نیست."
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_override("font", _font_hekayat)
			empty_lbl.add_theme_font_size_override("font_size", 26)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
			details_container.add_child(empty_lbl)
	
	# === 4. BACK BUTTON AT BOTTOM ===
	var btn_back_bottom = Button.new()
	btn_back_bottom.text = "بازگشت به لیست بازی‌ها"
	btn_back_bottom.custom_minimum_size = Vector2(340, 80)
	btn_back_bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_back_bottom.add_theme_font_override("font", _font_hekayat)
	btn_back_bottom.add_theme_font_size_override("font_size", 30)
	KenneyUI.style_button(btn_back_bottom, KenneyUI.COLOR_YELLOW)
	btn_back_bottom.pressed.connect(func():
		AudioManager.sfx_tap()
		show_list_view()
	)
	details_container.add_child(btn_back_bottom)

func _create_player_column(name_text: String, avatar_id: int, score_val: int, is_winner: bool) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(100, 100)
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var af_sb = StyleBoxFlat.new()
	af_sb.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	af_sb.set_corner_radius_all(14)
	af_sb.set_border_width_all(3)
	af_sb.border_color = Color(0.95, 0.80, 0.30, 1.0) if is_winner else Color(0.5, 0.4, 0.3, 0.7)
	av_frame.add_theme_stylebox_override("panel", af_sb)
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(94, 94)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var av_path = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(av_path):
		img.texture = load(av_path)
	else:
		img.texture = load("res://assets/icons/Avatars/0.png")
	av_frame.add_child(img)
	vbox.add_child(av_frame)
	
	var lbl_name = Label.new()
	lbl_name.text = name_text
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_override("font", _font_hekayat)
	lbl_name.add_theme_font_size_override("font_size", 28)
	lbl_name.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_name)
	
	var lbl_sc = Label.new()
	lbl_sc.text = "امتیاز: %s" % GameManager.to_fa_num(score_val)
	lbl_sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sc.add_theme_font_override("font", _font_hekayat)
	lbl_sc.add_theme_font_size_override("font_size", 24)
	lbl_sc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if is_winner else Color(0.8, 0.75, 0.7))
	vbox.add_child(lbl_sc)
	
	return vbox

func _create_round_row(round_num: int, r_data: Dictionary, my_uid: String) -> PanelContainer:
	var card = PanelContainer.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.14, 0.10, 0.07, 0.90)
	c_style.border_color = Color(0.65, 0.50, 0.28, 0.8)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(12)
	c_style.content_margin_left = 18
	c_style.content_margin_right = 18
	c_style.content_margin_top = 10
	c_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", c_style)
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	
	# Round Result Badge
	var w_uid = str(r_data.get("winner_user_id", ""))
	var w_id = r_data.get("winner_id")
	var is_my_win = false
	var is_draw = false
	if not w_uid.is_empty():
		if w_uid == my_uid:
			is_my_win = true
		elif w_uid == "0":
			is_draw = true
	elif w_id != null:
		if int(w_id) == 1 and GameManager.my_player_index == 1:
			is_my_win = true
		elif int(w_id) == 2 and GameManager.my_player_index == 2:
			is_my_win = true
		elif int(w_id) == 0:
			is_draw = true
	
	var r_badge = PanelContainer.new()
	r_badge.custom_minimum_size = Vector2(80, 50)
	var rb_style = StyleBoxFlat.new()
	rb_style.set_corner_radius_all(8)
	var status_text = "برد"
	if is_my_win:
		rb_style.bg_color = Color(0.18, 0.55, 0.22, 0.95)
		status_text = "برد"
	elif is_draw:
		rb_style.bg_color = Color(0.40, 0.40, 0.40, 0.95)
		status_text = "مساوی"
	else:
		rb_style.bg_color = Color(0.65, 0.18, 0.18, 0.95)
		status_text = "باخت"
	r_badge.add_theme_stylebox_override("panel", rb_style)
	
	var lbl_st = Label.new()
	lbl_st.text = status_text
	lbl_st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_st.add_theme_font_override("font", _font_hekayat)
	lbl_st.add_theme_font_size_override("font_size", 24)
	lbl_st.add_theme_color_override("font_color", Color.WHITE)
	r_badge.add_child(lbl_st)
	row.add_child(r_badge)
	
	# Game Info
	var gtype = str(r_data.get("game_type", "دوز"))
	var gname = GameRegistry.get_display_name_fa(gtype)
	
	var lbl_gname = Label.new()
	lbl_gname.text = "راند %s: %s" % [GameManager.to_fa_num(round_num), gname]
	lbl_gname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_gname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_gname.add_theme_font_override("font", _font_hekayat)
	lbl_gname.add_theme_font_size_override("font_size", 28)
	lbl_gname.add_theme_color_override("font_color", Color(0.96, 0.92, 0.85))
	row.add_child(lbl_gname)
	
	return card

func _format_short_date(iso_str: String) -> String:
	if iso_str.is_empty():
		return "اخیراً"
	var parts = iso_str.split("T")
	if parts.size() >= 2:
		var date_part = parts[0]
		var time_part = parts[1].substr(0, 5)
		return "%s %s" % [GameManager.to_fa_num(time_part), GameManager.to_fa_num(date_part)]
	return GameManager.to_fa_num(iso_str.substr(0, 10))

func _format_full_date(iso_str: String) -> String:
	if iso_str.is_empty():
		return "اخیراً"
	var parts = iso_str.split("T")
	if parts.size() >= 2:
		var date_part = parts[0]
		var time_part = parts[1].substr(0, 5)
		return "%s ساعت %s" % [GameManager.to_fa_num(date_part), GameManager.to_fa_num(time_part)]
	return GameManager.to_fa_num(iso_str)
