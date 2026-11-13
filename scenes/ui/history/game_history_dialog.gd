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

func _update_tab_styles() -> void:
	if _active_tab == 0:
		KenneyUI.style_button(btn_tab_matches, KenneyUI.COLOR_YELLOW)
		btn_tab_matches.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))
		KenneyUI.style_button(btn_tab_games_history, KenneyUI.COLOR_GREY)
		btn_tab_games_history.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))
	else:
		KenneyUI.style_button(btn_tab_games_history, KenneyUI.COLOR_YELLOW)
		btn_tab_games_history.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))
		KenneyUI.style_button(btn_tab_matches, KenneyUI.COLOR_GREY)
		btn_tab_matches.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))

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
	var clean = iso_str.strip_edges().replace("T", " ")
	var space_parts = clean.split(" ")
	var date_parts = space_parts[0].split("-")
	if date_parts.size() < 3:
		return iso_str
	var gy = int(date_parts[0])
	var gm = int(date_parts[1])
	var gd = int(date_parts[2])
	if gy <= 0:
		return iso_str
	var j = gregorian_to_jalali(gy, gm, gd)
	var hh = 0
	var mm = 0
	if space_parts.size() > 1:
		var time_parts = space_parts[1].split(":")
		if time_parts.size() >= 2:
			hh = int(time_parts[0])
			mm = int(time_parts[1])
	return "%04d/%02d/%02d  %02d:%02d" % [int(j[0]), int(j[1]), int(j[2]), int(hh), int(mm)]

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
	elif norm == "monopoly" or norm == "مونوپولی" or norm == "منوپولی":
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
	btn.custom_minimum_size = Vector2(0, 176)
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
	
	# Outcome-based shadow color and padding from right and left
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.08, 0.05, 0.94)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(14)
	style_normal.content_margin_left = 32
	style_normal.content_margin_right = 32
	style_normal.content_margin_top = 14
	style_normal.content_margin_bottom = 14
	style_normal.shadow_size = 14
	style_normal.shadow_offset = Vector2(0, 3)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.16, 0.11, 0.07, 0.98)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(14)
	style_hover.content_margin_left = 32
	style_hover.content_margin_right = 32
	style_hover.content_margin_top = 14
	style_hover.content_margin_bottom = 14
	style_hover.shadow_size = 18
	style_hover.shadow_offset = Vector2(0, 4)
	
	if my_res == "win":
		style_normal.shadow_color = Color(0.18, 0.85, 0.28, 0.80)
		style_normal.border_color = Color(0.30, 0.85, 0.45, 0.85)
		style_hover.shadow_color = Color(0.25, 0.95, 0.35, 0.95)
		style_hover.border_color = Color(0.40, 0.95, 0.55, 1.0)
	elif my_res == "lose":
		style_normal.shadow_color = Color(0.90, 0.18, 0.18, 0.80)
		style_normal.border_color = Color(0.90, 0.30, 0.30, 0.85)
		style_hover.shadow_color = Color(1.0, 0.25, 0.25, 0.95)
		style_hover.border_color = Color(1.0, 0.40, 0.40, 1.0)
	elif my_res == "draw":
		style_normal.shadow_color = Color(0.95, 0.85, 0.18, 0.80)
		style_normal.border_color = Color(0.95, 0.85, 0.30, 0.85)
		style_hover.shadow_color = Color(1.0, 0.92, 0.25, 0.95)
		style_hover.border_color = Color(1.0, 0.92, 0.40, 1.0)
	else:
		style_normal.shadow_color = Color(0.45, 0.40, 0.35, 0.40)
		style_normal.border_color = Color(0.60, 0.50, 0.38, 0.60)
		style_hover.shadow_color = Color(0.55, 0.50, 0.45, 0.60)
		style_hover.border_color = Color(0.80, 0.70, 0.55, 0.85)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus", style_normal)
	
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
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
	
	# 1. LEFT SIDE: Opponent Avatar (larger) + Name directly underneath (larger text)
	var opp_col = VBoxContainer.new()
	opp_col.custom_minimum_size = Vector2(110, 150)
	opp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	opp_col.add_theme_constant_override("separation", 6)
	opp_col.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var av_panel = PanelContainer.new()
	av_panel.custom_minimum_size = Vector2(96, 96)
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
	av_img.custom_minimum_size = Vector2(90, 90)
	av_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av_path = "res://assets/icons/Avatars/%d.png" % int(opp_avatar_id)
	if ResourceLoader.exists(av_path):
		av_img.texture = load(av_path)
	else:
		av_img.texture = load("res://assets/icons/Avatars/0.png")
	av_panel.add_child(av_img)
	
	# Clicking avatar opens opponent details box
	av_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			user_profile_requested.emit(opp_data)
	)
	opp_col.add_child(av_panel)
	
	var lbl_opp_name = Label.new()
	lbl_opp_name.text = opp_name
	lbl_opp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_opp_name.custom_minimum_size = Vector2(110, 0)
	lbl_opp_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_opp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_opp_name.add_theme_font_override("font", _font_hekayat)
	lbl_opp_name.add_theme_font_size_override("font_size", 28)
	lbl_opp_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	lbl_opp_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opp_col.add_child(lbl_opp_name)
	
	row.add_child(opp_col)
	
	# 2. CENTER SECTION: Outcome, Integer Score, and Persian Date (LTR) with larger fonts
	var center_col = VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 8)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var top_mid = HBoxContainer.new()
	top_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top_mid.add_theme_constant_override("separation", 14)
	top_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var lbl_res = Label.new()
	lbl_res.add_theme_font_override("font", _font_hekayat)
	lbl_res.add_theme_font_size_override("font_size", 36)
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
	
	# Integer score
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
		lbl_score.add_theme_font_size_override("font_size", 34)
		lbl_score.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
		top_mid.add_child(lbl_score)
	
	center_col.add_child(top_mid)
	
	# Persian Date (هجری شمسی) strictly LTR with larger font
	var s_date_raw = str(game.get("start_date", ""))
	var shamsi_date = _format_shamsi_date_ltr(s_date_raw)
	
	var lbl_date = Label.new()
	lbl_date.text_direction = Control.TEXT_DIRECTION_LTR
	lbl_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date.text = shamsi_date
	lbl_date.add_theme_font_override("font", _font_hekayat)
	lbl_date.add_theme_font_size_override("font_size", 28)
	lbl_date.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70))
	center_col.add_child(lbl_date)
	
	row.add_child(center_col)
	
	# 3. RIGHT SIDE: Big Game Mode Badge Icon (only game type icon, mini-game types removed)
	var mode_badge = TextureRect.new()
	mode_badge.custom_minimum_size = Vector2(104, 104)
	mode_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mode_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mode_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_badge.texture = _get_mode_badge_texture(mode_raw)
	row.add_child(mode_badge)
	
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
	
	var tc_hbox = HBoxContainer.new()
	tc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_hbox.add_theme_constant_override("separation", 20)
	top_card.add_child(tc_hbox)
	
	# Game type icon on the LEFT of top header
	var mode_icon = TextureRect.new()
	mode_icon.custom_minimum_size = Vector2(110, 110)
	mode_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mode_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mode_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_icon.texture = _get_mode_badge_texture(mode_raw)
	tc_hbox.add_child(mode_icon)
	
	var tc_vbox = VBoxContainer.new()
	tc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tc_vbox.add_theme_constant_override("separation", 8)
	tc_hbox.add_child(tc_vbox)
	
	var lbl_head = Label.new()
	lbl_head.text = res_headline
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_override("font", _font_hekayat)
	lbl_head.add_theme_font_size_override("font_size", 44)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	tc_vbox.add_child(lbl_head)
	
	# Persian Shamsi Date LTR & Mode Title (larger font)
	var s_date_raw = str(game.get("start_date", ""))
	var shamsi_date = _format_shamsi_date_ltr(s_date_raw)
	
	var lbl_date_mode = Label.new()
	lbl_date_mode.text_direction = Control.TEXT_DIRECTION_LTR
	lbl_date_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_date_mode.text = "%s   |   %s" % [shamsi_date, mode_title]
	lbl_date_mode.add_theme_font_override("font", _font_hekayat)
	lbl_date_mode.add_theme_font_size_override("font_size", 30)
	lbl_date_mode.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	tc_vbox.add_child(lbl_date_mode)
	
	details_container.add_child(top_card)
	
	# === 2. PLAYERS HEAD-TO-HEAD SECTION (ENLARGED) ===
	var h2h_card = PanelContainer.new()
	var h2h_style = StyleBoxFlat.new()
	h2h_style.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	h2h_style.border_color = Color(0.80, 0.65, 0.35, 0.9)
	h2h_style.set_border_width_all(2)
	h2h_style.set_corner_radius_all(14)
	h2h_style.content_margin_left = 22
	h2h_style.content_margin_right = 22
	h2h_style.content_margin_top = 20
	h2h_style.content_margin_bottom = 20
	h2h_card.add_theme_stylebox_override("panel", h2h_style)
	
	var h2h_row = HBoxContainer.new()
	h2h_row.alignment = BoxContainer.ALIGNMENT_CENTER
	h2h_row.add_theme_constant_override("separation", 28)
	h2h_card.add_child(h2h_row)
	
	var users_info = game.get("users_info", [])
	var scores = game.get("user_scores", [])
	
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
	
	# Left: You (larger fonts & avatar)
	var you_col = _create_player_column("شما (" + str(p_you.get("username", "")) + ")", int(p_you.get("image", 0)), score_you, my_res == "win")
	h2h_row.add_child(you_col)
	
	# Middle: VS & Integer Score (larger fonts)
	var vs_box = VBoxContainer.new()
	vs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vs_box.add_theme_constant_override("separation", 6)
	
	var lbl_vs = Label.new()
	lbl_vs.text = "VS"
	lbl_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_vs.add_theme_font_override("font", _font_hekayat)
	lbl_vs.add_theme_font_size_override("font_size", 48)
	lbl_vs.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	vs_box.add_child(lbl_vs)
	
	var lbl_final_score = Label.new()
	lbl_final_score.text = "%s : %s" % [GameManager.to_fa_num(score_you), GameManager.to_fa_num(score_opp)]
	lbl_final_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_final_score.add_theme_font_override("font", _font_hekayat)
	lbl_final_score.add_theme_font_size_override("font_size", 42)
	lbl_final_score.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	vs_box.add_child(lbl_final_score)
	
	h2h_row.add_child(vs_box)
	
	# Right: Opponent (larger fonts & avatar)
	var opp_col = _create_player_column(str(p_opp.get("username", "حریف")), int(p_opp.get("image", 0)), score_opp, my_res == "lose")
	h2h_row.add_child(opp_col)
	
	details_container.add_child(h2h_card)
	
	# === 3. ROUNDS / MINI-GAMES BREAKDOWN (ENLARGED) ===
	var rounds_title = Label.new()
	rounds_title.text = "🎮 بازی‌های این مسابقه"
	rounds_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounds_title.add_theme_font_override("font", _font_hekayat)
	rounds_title.add_theme_font_size_override("font_size", 38)
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
			empty_lbl.add_theme_font_size_override("font_size", 30)
			empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
			details_container.add_child(empty_lbl)

func _create_player_column(name_text: String, avatar_id: int, score_val: int, is_winner: bool) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	
	var av_frame = PanelContainer.new()
	av_frame.custom_minimum_size = Vector2(116, 116)
	av_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var af_sb = StyleBoxFlat.new()
	af_sb.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	af_sb.set_corner_radius_all(16)
	af_sb.set_border_width_all(3)
	af_sb.border_color = Color(0.95, 0.80, 0.30, 1.0) if is_winner else Color(0.5, 0.4, 0.3, 0.7)
	av_frame.add_theme_stylebox_override("panel", af_sb)
	
	var img = TextureRect.new()
	img.custom_minimum_size = Vector2(110, 110)
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
	lbl_name.add_theme_font_size_override("font_size", 34)
	lbl_name.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(lbl_name)
	
	var lbl_sc = Label.new()
	lbl_sc.text = "امتیاز: %s" % GameManager.to_fa_num(int(score_val))
	lbl_sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sc.add_theme_font_override("font", _font_hekayat)
	lbl_sc.add_theme_font_size_override("font_size", 30)
	lbl_sc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if is_winner else Color(0.8, 0.75, 0.7))
	vbox.add_child(lbl_sc)
	
	return vbox

func _create_round_row(round_num: int, r_data: Dictionary, my_uid: String) -> PanelContainer:
	var card = PanelContainer.new()
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.14, 0.10, 0.07, 0.90)
	c_style.border_color = Color(0.65, 0.50, 0.28, 0.8)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(14)
	c_style.content_margin_left = 22
	c_style.content_margin_right = 22
	c_style.content_margin_top = 12
	c_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", c_style)
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
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
	r_badge.custom_minimum_size = Vector2(96, 56)
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
	lbl_st.add_theme_font_size_override("font_size", 28)
	lbl_st.add_theme_color_override("font_color", Color.WHITE)
	r_badge.add_child(lbl_st)
	row.add_child(r_badge)
	
	# Game Info (larger font)
	var gtype = str(r_data.get("game_type", "دوز"))
	var gname = GameRegistry.get_display_name_fa(gtype)
	
	var lbl_gname = Label.new()
	lbl_gname.text = "راند %s: %s" % [GameManager.to_fa_num(int(round_num)), gname]
	lbl_gname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_gname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_gname.add_theme_font_override("font", _font_hekayat)
	lbl_gname.add_theme_font_size_override("font_size", 34)
	lbl_gname.add_theme_color_override("font_color", Color(0.96, 0.92, 0.85))
	row.add_child(lbl_gname)
	
	# Game Icon in Round Row (larger icon)
	var g_icon_panel = PanelContainer.new()
	g_icon_panel.custom_minimum_size = Vector2(64, 64)
	var gip_sb = StyleBoxFlat.new()
	gip_sb.bg_color = Color(0.08, 0.05, 0.03, 0.90)
	gip_sb.set_corner_radius_all(12)
	gip_sb.set_border_width_all(1)
	gip_sb.border_color = Color(0.75, 0.60, 0.35, 0.85)
	g_icon_panel.add_theme_stylebox_override("panel", gip_sb)

	var g_icon = TextureRect.new()
	g_icon.custom_minimum_size = Vector2(58, 58)
	g_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g_icon.texture = _get_game_icon_texture(gtype)
	g_icon_panel.add_child(g_icon)
	row.add_child(g_icon_panel)
	
	return card
