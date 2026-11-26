extends PanelContainer

# Game History Dialog Controller
# Displays list of played games across Rank, Classic Rank, and Lobby modes.
# Features:
# - Persian Jalali (هجری شمسی) dates rendered LTR.
# - Integer scores and values throughout.
# - Restructured row layout:
#     - Left: Opponent avatar + name underneath.
#     - Center: Result status, integer scores, and Shamsi date (LTR).
#     - Right: Large game type mode badge icon (with padding and no mini-game icons in row).
# - Glowing shadow colors: Win = Green, Lose = Red, Draw = Yellow.
# - Tapping opponent avatar opens opponent profile.
# - Match details view:
#     - Game type mode badge on left of top header.
#     - Enlarged typography across all headers, stats, rounds, and buttons.
#     - Game icons for each round.
#     - Return button at bottom center.

signal closed()
signal user_profile_requested(user_data: Dictionary)

@onready var btn_close_top: TextureButton = $Margin/VBox/TopRow/BtnCloseTop
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var lbl_loading: Label = $Margin/VBox/LblLoading
@onready var scroll_list: ScrollContainer = $Margin/VBox/ScrollList
@onready var list_container: VBoxContainer = $Margin/VBox/ScrollList/ListContainer
@onready var scroll_details: ScrollContainer = $Margin/VBox/ScrollDetails
@onready var details_container: VBoxContainer = $Margin/VBox/ScrollDetails/DetailsContainer
@onready var btn_close: Button = $Margin/VBox/BtnClose
@onready var btn_back: Button = $Margin/VBox/BtnBack
@onready var sub_tabs_row: HBoxContainer = $Margin/VBox/SubTabsRow
@onready var btn_tab_matches: Button = $Margin/VBox/SubTabsRow/BtnTabMatches
@onready var btn_tab_games_history: Button = $Margin/VBox/SubTabsRow/BtnTabGamesHistory
@onready var scroll_games_history: ScrollContainer = $Margin/VBox/ScrollGamesHistory
@onready var games_history_container: VBoxContainer = $Margin/VBox/ScrollGamesHistory/GamesHistoryContainer

var _font_hekayat = preload("res://assets/fonts/hekayat.ttf")
var _history_items: Array = []
var _selected_game: Dictionary = {}
var _my_games_history_data: Dictionary = {}
var _active_tab: int = 0  # 0: Matches, 1: Games History

func _ready() -> void:
	KenneyUI.style_button(btn_close, KenneyUI.COLOR_BLUE)
	KenneyUI.style_button(btn_back, KenneyUI.COLOR_YELLOW)
	
	_update_tab_styles()

	btn_tab_matches.pressed.connect(func():
		AudioManager.sfx_tap()
		_active_tab = 0
		_update_tab_styles()
		show_list_view()
	)

	btn_tab_games_history.pressed.connect(func():
		AudioManager.sfx_tap()
		_active_tab = 1
		_update_tab_styles()
		show_games_history_view()
	)
	
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
	ResponsiveUI.register_dialog(self, 660.0, 1160.0, 320.0, 480.0)

func _update_tab_styles() -> void:
	CafeSocialTheme.style_parlor_tab_button(btn_tab_matches, _active_tab == 0, 21)
	CafeSocialTheme.style_parlor_tab_button(btn_tab_games_history, _active_tab == 1, 21)

func open() -> void:
	_active_tab = 0
	_update_tab_styles()
	show_list_view()
	ActionVFXManager.animate_dialog_open(self, null, true)
	load_history()

func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func show_list_view() -> void:
	lbl_title.text = "📜 تاریخچه مسابقات"
	scroll_list.visible = true
	scroll_details.visible = false
	scroll_games_history.visible = false
	btn_close.visible = true
	btn_back.visible = false
	sub_tabs_row.visible = true

func show_details_view() -> void:
	lbl_title.text = "🔍 جزئیات مسابقه"
	scroll_list.visible = false
	scroll_details.visible = true
	scroll_games_history.visible = false
	btn_close.visible = false
	btn_back.visible = true
	sub_tabs_row.visible = false

func show_games_history_view() -> void:
	lbl_title.text = "🎮 آمار بازی‌های شما"
	scroll_list.visible = false
	scroll_details.visible = false
	scroll_games_history.visible = true
	btn_close.visible = true
	btn_back.visible = false
	sub_tabs_row.visible = true
	load_games_history()

func load_games_history() -> void:
	if not _my_games_history_data.is_empty():
		lbl_loading.visible = false
		GamesHistoryViewHelper.populate_games_history(games_history_container, _my_games_history_data)
		return

	lbl_loading.visible = true
	lbl_loading.text = "در حال بارگذاری آمار بازی‌ها..."

	NetworkManager.api.get_my_history(func(success: bool, _code: int, data: Variant):
		if not is_instance_valid(self) or not visible:
			return
		lbl_loading.visible = false
		if success and typeof(data) == TYPE_DICTIONARY and data.has("result"):
			var res = data["result"]
			if typeof(res) == TYPE_DICTIONARY:
				_my_games_history_data = res
			else:
				_my_games_history_data = {}
			GamesHistoryViewHelper.populate_games_history(games_history_container, _my_games_history_data)
		else:
			lbl_loading.text = "خطا در دریافت آمار بازی‌ها"
			lbl_loading.visible = true
	)

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

# === Jalali (هجری شمسی) Date Helper ===
static func gregorian_to_jalali(gy: int, gm: int, gd: int) -> Array:
	var g_d_m: Array = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var gy2: int = (gy - 1600) if (gm > 2) else (gy - 1601)
	var days: int = 365 * gy2 + int((gy2 + 3) / 4) - int((gy2 + 99) / 100) + int((gy2 + 399) / 400) - 80 + gd + g_d_m[gm - 1]
	var jy: int = 979 + 33 * int(days / 12053)
	days %= 12053
	jy += 4 * int(days / 1461)
	days %= 1461
	if days > 365:
		jy += int((days - 1) / 365)
		days = (days - 1) % 365
	var jm: int = 0
	var jd: int = 0
	if days < 186:
		jm = 1 + int(days / 31)
		jd = 1 + (days % 31)
	else:
		jm = 7 + int((days - 186) / 30)
		jd = 1 + ((days - 186) % 30)
	return [jy, jm, jd]

static func _format_shamsi_date_ltr(iso_str: String) -> String:
	if iso_str.is_empty():
		return "اخیراً"
	var local_dt := GameManager.parse_server_iso_to_local(iso_str)
	if local_dt.is_empty():
		return iso_str
	var gy := int(local_dt["year"])
	var gm := int(local_dt["month"])
	var gd := int(local_dt["day"])
	var j = gregorian_to_jalali(gy, gm, gd)
	var hh := int(local_dt["hour"])
	var mm := int(local_dt["minute"])
	return "%04d/%02d/%02d  %02d:%02d" % [int(j[0]), int(j[1]), int(j[2]), hh, mm]

# === Game Asset Helpers ===
static func _get_game_icon_texture(game_type: String) -> Texture2D:
	var norm = game_type.strip_edges().to_lower().replace("_", "").replace("-", "")
	if norm == "tictactoe" or norm == "تیکتاکتو" or norm == "دوز":
		norm = "tictactoe"
	elif norm == "fourinrow" or norm == "دوزچهارتایی":
		norm = "fourinrow"
	elif norm == "battleship" or norm == "نبردکشتی":
		norm = "battleship"
	elif norm == "backgammon" or norm == "تختهنرد":
		norm = "backgammon"
	elif norm == "chess" or norm == "شطرنج":
		norm = "chess"
	elif norm == "checkers" or norm == "چکرز":
		norm = "checkers"
	elif norm == "fekrbekr" or norm == "فکربکر":
		norm = "fekrbekr"
	elif norm == "yatzy" or norm == "یاتزی":
		norm = "yatzy"
	elif norm == "rpc" or norm == "سنگکاغذقیچی":
		norm = "rpc"
	elif norm == "othello" or norm == "اتللو":
		norm = "othello"
	elif norm == "mill" or norm == "دوزنهتایی":
		norm = "mill"
	elif norm == "dotbox" or norm == "نقطهخط":
		norm = "dotbox"
	elif norm == "mnumbers" or norm == "کشفاعداد":
		norm = "mnumbers"
	elif norm == "msweeper" or norm == "مین یاب":
		norm = "msweeper"
	elif norm == "boxfour" or norm == "چهارطرفه":
		norm = "boxfour"
	elif norm == "yinsh" or norm == "یینش":
		norm = "yinsh"
	elif norm == "pentago" or norm == "پنتاگو":
		norm = "pentago"
	elif norm == "ludo" or norm == "منچ":
		norm = "ludo"
	elif norm == "sudoku" or norm == "سودوکو":
		norm = "sudoku"
	elif norm == "risk" or norm == "riskstrike" or norm == "ریسک" or norm == "ریسکاسترایک":
		norm = "risk"
	elif norm == "uno" or norm == "اونو":
		norm = "uno"
	elif norm == "coup" or norm == "کودتا":
		norm = "coup"
	elif norm == "monopoly" or norm == "روپولی" or norm == "مونوپولی" or norm == "منوپولی":
		norm = "monopoly"
	elif norm == "quoridor" or norm == "کوریدور":
		norm = "quoridor"
	
	var png_path = "res://assets/images/games/%s.png" % norm
	if ResourceLoader.exists(png_path):
		return load(png_path)
	var jpg_path = "res://assets/images/games/%s.jpg" % norm
	if ResourceLoader.exists(jpg_path):
		return load(jpg_path)
	for ext in ["png", "jpg"]:
		var raw_path = ProjectSettings.globalize_path("res://assets/images/games/%s.%s" % [norm, ext])
		if FileAccess.file_exists(raw_path):
			var img = Image.load_from_file(raw_path)
			if img and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return load("res://assets/images/games/tictactoe.png")

static func _get_mode_badge_texture(mode_raw: String) -> Texture2D:
	if mode_raw == "ClassicRank":
		return load("res://assets/images/badges/classic-rank.png")
	elif mode_raw == "Lobby":
		return load("res://assets/images/badges/lobby.png")
	return load("res://assets/images/badges/rank.png")

# === History Row Summary Card ===
func _create_game_summary_card(game: Dictionary, my_uid: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 140)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Determine game mode
	var mode_raw = str(game.get("game_score_type", "Rank"))
	
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
	
	var card_tint: Color = Color.WHITE
	if my_res == "win":
		card_tint = Color(0.92, 1.06, 0.94)
	elif my_res == "lose":
		card_tint = Color(1.06, 0.90, 0.90)
	elif my_res == "draw":
		card_tint = Color(1.05, 1.00, 0.88)

	var make_frame_card := func(tint: Color) -> StyleBoxTexture:
		var sb := StyleBoxTexture.new()
		sb.texture = preload("res://assets/images/frames/frame.png")
		sb.texture_margin_left = 48.0
		sb.texture_margin_top = 28.0
		sb.texture_margin_right = 48.0
		sb.texture_margin_bottom = 28.0
		sb.content_margin_left = 44.0
		sb.content_margin_right = 44.0
		sb.content_margin_top = 12.0
		sb.content_margin_bottom = 12.0
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		sb.modulate_color = tint
		return sb

	var style_normal = make_frame_card.call(card_tint)
	var style_hover = make_frame_card.call(card_tint.lightened(0.08))

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus", style_normal)

	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(row)
	
	# Opponent Info Lookup
	var opp_name = "حریف"
	var opp_avatar_id = 0
	var opp_data: Dictionary = {}
	var users_info = game.get("users_info", [])
	for u in users_info:
		if typeof(u) == TYPE_DICTIONARY and str(u.get("user_id", "")) != my_uid:
			opp_name = str(u.get("username", u.get("name", "حریف")))
			opp_avatar_id = int(u.get("image", 0))
			opp_data = u.duplicate(true)
			break
	if opp_data.is_empty():
		if mode_raw == "ClassicRank":
			opp_name = "ربات هوشمند"
			opp_avatar_id = 1
			opp_data = {
				"user_id": "bot_classic",
				"username": "ربات هوشمند",
				"name": "ربات هوشمند",
				"image": 1,
				"score": 1000,
				"level": 1,
				"xp": 0,
				"coin": 0
			}
		else:
			opp_data = {
				"user_id": "opp",
				"username": opp_name,
				"name": opp_name,
				"image": opp_avatar_id,
				"score": 0,
				"level": 1,
				"xp": 0,
				"coin": 0
			}
	
	# 1. LEFT SIDE: Opponent Avatar + Name directly underneath
	var opp_col = VBoxContainer.new()
	opp_col.custom_minimum_size = Vector2(90, 120)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_col.add_theme_constant_override("separation", 4)
	opp_col.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var _card_users_info = game.get("users_info", [])
	var _is_multi_card: bool = typeof(_card_users_info) == TYPE_ARRAY and _card_users_info.size() > 2
	if _is_multi_card:
		var fr_img = TextureRect.new()
		fr_img.custom_minimum_size = Vector2(70, 70)
		fr_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fr_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fr_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fr_img.texture = preload("res://assets/images/frames/friends.png")
		opp_col.add_child(fr_img)
	else:
		var av_panel = PanelContainer.new()
		av_panel.custom_minimum_size = Vector2(76, 76)
		av_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		av_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		av_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		var av_style = StyleBoxFlat.new()
		av_style.bg_color = Color(0.08, 0.05, 0.03, 0.95)
		av_style.set_corner_radius_all(14)
		av_style.set_border_width_all(2)
		av_style.border_color = Color(0.90, 0.75, 0.35, 0.90)
		av_panel.add_theme_stylebox_override("panel", av_style)
		
		var av_img = TextureRect.new()
		av_img.custom_minimum_size = Vector2(70, 70)
		av_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var av_path = "res://assets/icons/Avatars/%d.png" % int(opp_avatar_id)
		if ResourceLoader.exists(av_path):
			av_img.texture = load(av_path)
		else:
			av_img.texture = load("res://assets/icons/Avatars/0.png")
		av_panel.add_child(av_img)
		var opp_fid = GameManager.get_player_frame_id(opp_data)
		CafeSocialTheme.apply_frame_to_container(av_panel, av_img, opp_fid)
		
		# Clicking avatar opens opponent details box
		av_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				AudioManager.sfx_tap()
				user_profile_requested.emit(opp_data)
		)
		opp_col.add_child(av_panel)
	
	var lbl_opp_name = Label.new()
	lbl_opp_name.text = ("%s نفره" % GameManager.to_fa_num(_card_users_info.size())) if _is_multi_card else opp_name
	lbl_opp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_opp_name.custom_minimum_size = Vector2(90, 0)
	lbl_opp_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_opp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_opp_name.add_theme_font_override("font", _font_hekayat)
	lbl_opp_name.add_theme_font_size_override("font_size", 22)
	lbl_opp_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lbl_opp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_col.add_child(lbl_opp_name)
	
	row.add_child(opp_col)
	
	# 2. CENTER SECTION: Outcome, Integer Score, and Persian Date (LTR)
	var center_col = VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 6)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var top_mid = HBoxContainer.new()
	top_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top_mid.add_theme_constant_override("separation", 10)
	top_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var lbl_res = Label.new()
	lbl_res.add_theme_font_override("font", _font_hekayat)
	lbl_res.add_theme_font_size_override("font_size", 28)
	if my_res == "win":
		lbl_res.text = "برد 🏆"
		lbl_res.add_theme_color_override("font_color", Color(0.40, 0.95, 0.45))
	elif my_res == "lose":
		lbl_res.text = "باخت"
		lbl_res.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	elif my_res == "draw":
		lbl_res.text = "مساوی"
		lbl_res.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	else:
		lbl_res.text = "ناتمام"
		lbl_res.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	top_mid.add_child(lbl_res)
	
	# Integer score — omit for single-round & >2-player matches
	var _u_info = game.get("users_info", [])
	var _r_arr = game.get("rounds", [])
	var _gt_arr = game.get("game_types", [])
	var _is_single_or_multi: bool = (typeof(_u_info) == TYPE_ARRAY and _u_info.size() > 2) or ((_r_arr.size() if typeof(_r_arr) == TYPE_ARRAY else 0) <= 1 and (_gt_arr.size() if typeof(_gt_arr) == TYPE_ARRAY else 0) <= 1)
	if not _is_single_or_multi:
		var scores = game.get("user_scores", [])
		var score_str = ""
		if scores.size() >= 2:
			var p1_uid = str(game.get("user1_id", ""))
			if p1_uid == my_uid:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[0])), GameManager.to_fa_num(int(scores[1]))]
			else:
				score_str = "%s - %s" % [GameManager.to_fa_num(int(scores[1])), GameManager.to_fa_num(int(scores[0]))]
		elif not scores.is_empty():
			score_str = GameManager.to_fa_num(int(scores[0]))
		
		if not score_str.is_empty():
			var lbl_score = Label.new()
			lbl_score.text = "( %s )" % score_str
			lbl_score.add_theme_font_override("font", _font_hekayat)
			lbl_score.add_theme_font_size_override("font_size", 26)
			lbl_score.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
			top_mid.add_child(lbl_score)
	
	center_col.add_child(top_mid)
	
	# Persian Date (هجری شمسی) strictly LTR
	var s_date_raw = str(game.get("start_date", ""))
	var shamsi_date = _format_shamsi_date_ltr(s_date_raw)
	
	var lbl_date = Label.new()
	lbl_date.text_direction = Control.TEXT_DIRECTION_LTR
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.text = shamsi_date
	lbl_date.add_theme_font_override("font", _font_hekayat)
	lbl_date.add_theme_font_size_override("font_size", 20)
	lbl_date.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	center_col.add_child(lbl_date)
	
	row.add_child(center_col)
	
	# 3. RIGHT SIDE: Game-Specific Framed Icon (fallback to mode badge if game type missing)
	var primary_gtype: String = str(game.get("game_type", game.get("game", ""))).strip_edges()
	if primary_gtype.is_empty() and typeof(_gt_arr) == TYPE_ARRAY and not _gt_arr.is_empty():
		primary_gtype = str(_gt_arr[0]).strip_edges()
	if primary_gtype.is_empty() and typeof(_r_arr) == TYPE_ARRAY and not _r_arr.is_empty() and typeof(_r_arr[0]) == TYPE_DICTIONARY:
		primary_gtype = str(_r_arr[0].get("game_type", _r_arr[0].get("game", ""))).strip_edges()

	var g_icon_frame := PanelContainer.new()
	g_icon_frame.custom_minimum_size = Vector2(76, 76)
	g_icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g_icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g_if_style := StyleBoxFlat.new()
	g_if_style.bg_color = Color(0.09, 0.05, 0.03, 0.96)
	g_if_style.border_color = style_normal.border_color
	g_if_style.set_border_width_all(2)
	g_if_style.set_corner_radius_all(14)
	g_if_style.content_margin_left = 4.0
	g_if_style.content_margin_right = 4.0
	g_if_style.content_margin_top = 4.0
	g_if_style.content_margin_bottom = 4.0
	g_icon_frame.add_theme_stylebox_override("panel", g_if_style)

	var mode_badge := TextureRect.new()
	mode_badge.custom_minimum_size = Vector2(66, 66)
	mode_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mode_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mode_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_badge.texture = _get_game_icon_texture(primary_gtype) if not primary_gtype.is_empty() else _get_mode_badge_texture(mode_raw)
	g_icon_frame.add_child(mode_badge)
	row.add_child(g_icon_frame)
	
	btn.pressed.connect(func():
		AudioManager.sfx_tap()
		show_game_details(game)
	)
	
	return btn

# === Game Details View ===
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
	
	# === 1. TOP RESULT BANNER CARD WITH GAME TYPE ICON ON LEFT ===
	var top_card = PanelContainer.new()
	var tc_style = StyleBoxFlat.new()
	tc_style.set_corner_radius_all(16)
	tc_style.set_border_width_all(2)
	tc_style.content_margin_left = 16
	tc_style.content_margin_right = 16
	tc_style.content_margin_top = 12
	tc_style.content_margin_bottom = 12
	
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
	
	var tc_hbox = HBoxContainer.new()
	tc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_hbox.add_theme_constant_override("separation", 14)
	top_card.add_child(tc_hbox)
	
	# Game type icon on the LEFT of top header
	var mode_icon = TextureRect.new()
	mode_icon.custom_minimum_size = Vector2(80, 80)
	mode_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mode_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mode_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_icon.texture = _get_mode_badge_texture(mode_raw)
	tc_hbox.add_child(mode_icon)
	
	var tc_vbox = VBoxContainer.new()
	tc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_vbox.add_theme_constant_override("separation", 6)
	tc_hbox.add_child(tc_vbox)
	
	var lbl_head = Label.new()
	lbl_head.text = res_headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_override("font", _font_hekayat)
	lbl_head.add_theme_font_size_override("font_size", 30)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	tc_vbox.add_child(lbl_head)
	
	# Persian Shamsi Date LTR & Mode Title
	var s_date_raw = str(game.get("start_date", ""))
	var shamsi_date = _format_shamsi_date_ltr(s_date_raw)
	
	var lbl_date_mode = Label.new()
	lbl_date_mode.text_direction = Control.TEXT_DIRECTION_LTR
	lbl_date_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date_mode.text = "%s   |   %s" % [shamsi_date, mode_title]
	lbl_date_mode.add_theme_font_override("font", _font_hekayat)
	lbl_date_mode.add_theme_font_size_override("font_size", 22)
	lbl_date_mode.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	tc_vbox.add_child(lbl_date_mode)
	
	details_container.add_child(top_card)
	
	# === 2. PLAYERS HEAD-TO-HEAD SECTION ===
	var h2h_card = PanelContainer.new()
	var h2h_style = StyleBoxFlat.new()
	h2h_style.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	h2h_style.border_color = Color(0.80, 0.65, 0.35, 0.9)
	h2h_style.set_border_width_all(2)
	h2h_style.set_corner_radius_all(14)
	h2h_style.content_margin_left = 16
	h2h_style.content_margin_right = 16
	h2h_style.content_margin_top = 14
	h2h_style.content_margin_bottom = 14
	h2h_card.add_theme_stylebox_override("panel", h2h_style)
	
	var users_info = game.get("users_info", []) if typeof(game.get("users_info")) == TYPE_ARRAY else []
	var scores = game.get("user_scores", []) if typeof(game.get("user_scores")) == TYPE_ARRAY else []
	var r_arr = game.get("rounds", []) if typeof(game.get("rounds")) == TYPE_ARRAY else []
	var gt_arr = game.get("game_types", []) if typeof(game.get("game_types")) == TYPE_ARRAY else []
	var is_multiplayer: bool = users_info.size() > 2
	var is_single_round: bool = is_multiplayer or (r_arr.size() <= 1 and gt_arr.size() <= 1)
	var _w_list = game.get("winner_list", []) if typeof(game.get("winner_list")) == TYPE_ARRAY else []
	var resolved_winner_id = winner_id if not winner_id.is_empty() else (str(_w_list[0]) if not _w_list.is_empty() else "")
	var runner_up_id = str(_w_list[1]) if _w_list.size() >= 2 else ""

	if is_multiplayer:
		var m_vbox = VBoxContainer.new()
		m_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_vbox.add_theme_constant_override("separation", 10)
		h2h_card.add_child(m_vbox)

		var lbl_players_t = Label.new()
		lbl_players_t.text = "بازیکنان مسابقه (%s نفره)" % GameManager.to_fa_num(users_info.size())
		lbl_players_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_players_t.add_theme_font_override("font", _font_hekayat)
		lbl_players_t.add_theme_font_size_override("font_size", 26)
		lbl_players_t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		m_vbox.add_child(lbl_players_t)

		var p_grid = GridContainer.new()
		p_grid.columns = 2
		p_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_grid.add_theme_constant_override("h_separation", 10)
		p_grid.add_theme_constant_override("v_separation", 10)
		m_vbox.add_child(p_grid)

		for u in users_info:
			if typeof(u) != TYPE_DICTIONARY:
				continue
			var u_uid = str(u.get("user_id", u.get("_id", "")))
			var u_name = str(u.get("username", u.get("name", "بازیکن")))
			var is_self_u = (not my_uid.is_empty() and u_uid == my_uid)
			var is_win_u = (not resolved_winner_id.is_empty() and resolved_winner_id != "0" and u_uid == resolved_winner_id)
			var is_sec_u = (not is_win_u and not runner_up_id.is_empty() and u_uid == runner_up_id)

			var p_card = PanelContainer.new()
			p_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var p_bg = Color(0.11, 0.25, 0.14, 0.96) if is_win_u else Color(0.15, 0.11, 0.07, 0.94)
			var p_br = Color(1.0, 0.84, 0.30) if is_win_u else (Color(0.75, 0.58, 0.28) if is_self_u else Color(0.45, 0.34, 0.20))
			p_card.add_theme_stylebox_override("panel", CafeSocialTheme.create_card_style(p_bg, p_br, 14, 3 if is_win_u else 1, 10.0, 10.0))

			var pv = VBoxContainer.new()
			pv.alignment = BoxContainer.ALIGNMENT_CENTER
			pv.add_theme_constant_override("separation", 6)
			p_card.add_child(pv)

			var av_b = CafeSocialTheme.make_avatar_badge(int(u.get("image", 0)), GameManager.get_player_frame_id(u), 68.0)
			av_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pv.add_child(av_b)

			var l_nm = Label.new()
			l_nm.text = ("%s (شما)" % u_name) if is_self_u else u_name
			l_nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l_nm.clip_text = true
			l_nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l_nm.add_theme_font_override("font", _font_hekayat)
			l_nm.add_theme_font_size_override("font_size", 22)
			l_nm.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45) if (is_win_u or is_self_u) else Color.WHITE)
			pv.add_child(l_nm)

			if is_win_u:
				var wp = CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 18)
				wp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(wp)
			elif is_sec_u:
				var sp = CafeSocialTheme.make_badge_pill("🥈 نفر دوم", Color(0.88, 0.90, 0.95), Color(0.18, 0.16, 0.14, 0.95), Color(0.70, 0.72, 0.78), 16)
				sp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				pv.add_child(sp)

			p_grid.add_child(p_card)
	else:
		var h2h_row = HBoxContainer.new()
		h2h_row.alignment = BoxContainer.ALIGNMENT_CENTER
		h2h_row.add_theme_constant_override("separation", 16)
		h2h_card.add_child(h2h_row)
		
		var p_you: Dictionary = {}
		var p_opp: Dictionary = {}
		var score_you: int = 0
		var score_opp: int = 0
		
		for idx in range(users_info.size()):
			var u = users_info[idx]
			var sc = int(scores[idx]) if idx < scores.size() else 0
			if str(u.get("user_id", "")) == my_uid:
				p_you = u
				score_you = sc
			else:
				p_opp = u
				score_opp = sc
		
		if p_you.is_empty():
			p_you = {"username": GameManager.get_username(), "image": GameManager.get_avatar_id()}
			score_you = int(scores[0]) if scores.size() > 0 else 0
			score_opp = int(scores[1]) if scores.size() > 1 else 0
		
		if p_opp.is_empty():
			p_opp = {"username": "حریف", "image": 0}
			if mode_raw == "ClassicRank":
				p_opp = {"username": "ربات هوشمند", "image": 1}
		
		# Left: You
		var you_col = _create_player_column("شما (" + str(p_you.get("username", "")) + ")", int(p_you.get("image", 0)), -1 if is_single_round else score_you, my_res == "win", GameManager.get_player_frame_id(p_you))
		h2h_row.add_child(you_col)
		
		# Middle: VS & Integer Score (only for multi-round series)
		var vs_box = VBoxContainer.new()
		vs_box.alignment = BoxContainer.ALIGNMENT_CENTER
		vs_box.add_theme_constant_override("separation", 4)
		
		var lbl_vs = Label.new()
		lbl_vs.text = "VS"
		lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_vs.add_theme_font_override("font", _font_hekayat)
		lbl_vs.add_theme_font_size_override("font_size", 34)
		lbl_vs.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
		vs_box.add_child(lbl_vs)
		
		if not is_single_round:
			var lbl_final_score = Label.new()
			lbl_final_score.text = "%s : %s" % [GameManager.to_fa_num(score_you), GameManager.to_fa_num(score_opp)]
			lbl_final_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_final_score.add_theme_font_override("font", _font_hekayat)
			lbl_final_score.add_theme_font_size_override("font_size", 32)
			lbl_final_score.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
			vs_box.add_child(lbl_final_score)
		
		h2h_row.add_child(vs_box)
		
		# Right: Opponent
		var opp_col = _create_player_column(str(p_opp.get("username", "حریف")), int(p_opp.get("image", 0)), -1 if is_single_round else score_opp, my_res == "lose", GameManager.get_player_frame_id(p_opp))
		h2h_row.add_child(opp_col)
	
	details_container.add_child(h2h_card)
	
	# === 3. ROUNDS / MINI-GAMES BREAKDOWN ===
	var rounds_title = Label.new()
	rounds_title.text = "🎮 بازی‌های این مسابقه"
	rounds_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounds_title.add_theme_font_override("font", _font_hekayat)
	rounds_title.add_theme_font_size_override("font_size", 28)
	rounds_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	details_container.add_child(rounds_title)
	
	var rounds = game.get("rounds", [])
	if typeof(rounds) == TYPE_ARRAY and not rounds.is_empty():
		for r_idx in range(rounds.size()):
			var r_data = rounds[r_idx]
			var r_card = _create_round_row(r_idx + 1, r_data, my_uid)
			details_container.add_child(r_card)
	else:
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
			empty_lbl.add_theme_font_size_override("font_size", 24)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
			details_container.add_child(empty_lbl)

func _create_player_column(name_text: String, avatar_id: int, score_val: int, is_winner: bool, frame_id: int = 1) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(88, 88)
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var af_sb = StyleBoxFlat.new()
	af_sb.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	af_sb.set_corner_radius_all(16)
	af_sb.set_border_width_all(3)
	af_sb.border_color = Color(0.95, 0.80, 0.30, 1.0) if is_winner else Color(0.5, 0.4, 0.3, 0.7)
	av_frame.add_theme_stylebox_override("panel", af_sb)
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(82, 82)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var av_path = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(av_path):
		img.texture = load(av_path)
	else:
		img.texture = load("res://assets/icons/Avatars/0.png")
	av_frame.add_child(img)
	CafeSocialTheme.apply_frame_to_container(av_frame, img, frame_id)
	vbox.add_child(av_frame)
	
	var lbl_name = Label.new()
	lbl_name.text = name_text
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_override("font", _font_hekayat)
	lbl_name.add_theme_font_size_override("font_size", 24)
	lbl_name.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_name)
	
	if int(score_val) >= 0:
		var lbl_sc = Label.new()
		lbl_sc.text = "امتیاز: %s" % GameManager.to_fa_num(int(score_val))
		lbl_sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sc.add_theme_font_override("font", _font_hekayat)
		lbl_sc.add_theme_font_size_override("font_size", 22)
		lbl_sc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if is_winner else Color(0.8, 0.75, 0.7))
		vbox.add_child(lbl_sc)
	elif is_winner:
		var wp = CafeSocialTheme.make_badge_pill("👑 برنده", CafeSocialTheme.COL_GOLD_BRIGHT, Color(0.16, 0.34, 0.16, 0.98), CafeSocialTheme.COL_GOLD_BRIGHT, 16)
		wp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(wp)
	
	return vbox

func _create_round_row(round_num: int, r_data: Dictionary, my_uid: String) -> PanelContainer:
	var card = PanelContainer.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.14, 0.10, 0.07, 0.90)
	c_style.border_color = Color(0.65, 0.50, 0.28, 0.8)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(14)
	c_style.content_margin_left = 16
	c_style.content_margin_right = 16
	c_style.content_margin_top = 10
	c_style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", c_style)
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
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
	r_badge.custom_minimum_size = Vector2(76, 44)
	var rb_style = StyleBoxFlat.new()
	rb_style.set_corner_radius_all(10)
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
	lbl_st.add_theme_font_size_override("font_size", 22)
	lbl_st.add_theme_color_override("font_color", Color.WHITE)
	r_badge.add_child(lbl_st)
	row.add_child(r_badge)
	
	# Game Info
	var gtype = str(r_data.get("game_type", "دوز"))
	var gname = GameRegistry.get_display_name_fa(gtype)
	
	var lbl_gname = Label.new()
	lbl_gname.text = "راند %s: %s" % [GameManager.to_fa_num(int(round_num)), gname]
	lbl_gname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_gname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_gname.add_theme_font_override("font", _font_hekayat)
	lbl_gname.add_theme_font_size_override("font_size", 24)
	lbl_gname.add_theme_color_override("font_color", Color(0.96, 0.92, 0.85))
	row.add_child(lbl_gname)
	
	# Game Icon in Round Row
	var g_icon_panel = PanelContainer.new()
	g_icon_panel.custom_minimum_size = Vector2(50, 50)
	var gip_sb = StyleBoxFlat.new()
	gip_sb.bg_color = Color(0.08, 0.05, 0.03, 0.90)
	gip_sb.set_corner_radius_all(12)
	gip_sb.set_border_width_all(1)
	gip_sb.border_color = Color(0.75, 0.60, 0.35, 0.85)
	g_icon_panel.add_theme_stylebox_override("panel", gip_sb)

	var g_icon = TextureRect.new()
	g_icon.custom_minimum_size = Vector2(44, 44)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g_icon.texture = _get_game_icon_texture(gtype)
	g_icon_panel.add_child(g_icon)
	row.add_child(g_icon_panel)
	
	return card
