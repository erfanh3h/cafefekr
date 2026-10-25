extends PanelContainer

# Rules and Game Encyclopedia Dialog
# Mirrors Flutter's LibraryPage & GlobalGameGuideWidget:
# Provides full game narratives, rules, and online gameplay guides for every game

signal closed()

@onready var btn_close: TextureButton = $Margin/VBox/TopRow/BtnClose
@onready var btn_select_game: Button = $Margin/VBox/BtnSelectGame
@onready var lbl_selected_game: Label = $Margin/VBox/BtnSelectGame/Margin/HBox/VBoxGameInfo/LblSelectedGame
@onready var selected_game_icon: TextureRect = $Margin/VBox/BtnSelectGame/Margin/HBox/IconFrame/SelectedGameIcon
@onready var btn_tab_overview: Button = $Margin/VBox/SubTabsRow/BtnTabOverview
@onready var btn_tab_rules: Button = $Margin/VBox/SubTabsRow/BtnTabRules
@onready var btn_tab_gameplay: Button = $Margin/VBox/SubTabsRow/BtnTabGameplay
@onready var sub_tabs_row: HBoxContainer = $Margin/VBox/SubTabsRow
@onready var scroll_content: ScrollContainer = $Margin/VBox/Scroll
@onready var content_box: VBoxContainer = $Margin/VBox/Scroll/Content
@onready var btn_understood: Button = $Margin/VBox/BtnUnderstood

# Game Select Modal
@onready var game_select_modal: Control = $GameSelectModal
@onready var game_select_panel: PanelContainer = $GameSelectModal/Panel
@onready var btn_close_game_select: TextureButton = $GameSelectModal/Panel/ModalMargin/VBox/TopRow/BtnCloseGameSelect
@onready var scroll_games: ScrollContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames
@onready var game_grid: GridContainer = $GameSelectModal/Panel/ModalMargin/VBox/ScrollGames/GameGrid
@onready var backdrop_game_select: ColorRect = $GameSelectModal/Backdrop

var _game_docs: Dictionary = {}
var selected_game_key: String = "tictactoe"
var active_sub_tab: int = 0 # 0: overview, 1: rules, 2: gameplay

const GAME_KEYS = [
	{"key": "tictactoe", "name": "تیک تاک تو", "time": "۵ دقیقه", "diff": "آسان"},
	{"key": "chess", "name": "شطرنج", "time": "۱۵ الی ۳۰ دقیقه", "diff": "سخت"},
	{"key": "backgammon", "name": "تخته نرد", "time": "۱۰ الی ۲۰ دقیقه", "diff": "متوسط"},
	{"key": "checkers", "name": "چکرز", "time": "۱۰ دقیقه", "diff": "متوسط"},
	{"key": "fourinrow", "name": "دوز چهارتایی", "time": "۵ الی ۱۰ دقیقه", "diff": "آسان"},
	{"key": "othello", "name": "اتللو", "time": "۱۰ دقیقه", "diff": "متوسط"},
	{"key": "mill", "name": "دوز نه تایی", "time": "۱۰ دقیقه", "diff": "متوسط"},
	{"key": "dotbox", "name": "نقطه خط", "time": "۸ دقیقه", "diff": "آسان"},
	{"key": "pentago", "name": "پنتاگو", "time": "۱۰ دقیقه", "diff": "متوسط"},
	{"key": "yatzy", "name": "یاتزی", "time": "۱۲ دقیقه", "diff": "متوسط"},
	{"key": "battleship", "name": "نبرد کشتی", "time": "۱۵ دقیقه", "diff": "متوسط"},
	{"key": "ludo", "name": "منچ", "time": "۱۵ الی ۲۵ دقیقه", "diff": "آسان"},
	{"key": "sudoku", "name": "سودوکو", "time": "۱۰ دقیقه", "diff": "سخت"},
	{"key": "yinsh", "name": "یینش", "time": "۱۵ دقیقه", "diff": "سخت"},
	{"key": "rpc", "name": "سنگ کاغذ قیچی", "time": "۲ دقیقه", "diff": "آسان"},
	{"key": "fekrbekr", "name": "فکر بکر", "time": "۸ دقیقه", "diff": "متوسط"},
	{"key": "rank_mode", "name": "رقابت رنکد", "time": "آنلاین", "diff": "رسمی"},
	{"key": "lobby_mode", "name": "اتاق دوستانه", "time": "آنلاین", "diff": "خصوصی"}
]

func _ready() -> void:
	KenneyUI.style_button(btn_understood, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(btn_select_game, "tap_button")
	
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	btn_understood.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	btn_select_game.pressed.connect(func():
		AudioManager.sfx_tap()
		_open_game_select_modal()
	)
	
	btn_close_game_select.pressed.connect(func():
		AudioManager.sfx_tap()
		_close_game_select_modal()
	)
	
	backdrop_game_select.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.sfx_tap()
			_close_game_select_modal()
	)
	
	btn_tab_overview.pressed.connect(func():
		AudioManager.sfx_tap()
		active_sub_tab = 0
		_update_tab_button_styles()
		_render_content()
	)
	btn_tab_rules.pressed.connect(func():
		AudioManager.sfx_tap()
		active_sub_tab = 1
		_update_tab_button_styles()
		_render_content()
	)
	btn_tab_gameplay.pressed.connect(func():
		AudioManager.sfx_tap()
		active_sub_tab = 2
		_update_tab_button_styles()
		_render_content()
	)
	
	_load_docs()
	_update_selected_game_display()
	_update_tab_button_styles()
	_render_content()

func _load_docs() -> void:
	var path = "res://scripts/games/game_docs.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_str = file.get_as_text()
		var json = JSON.new()
		var parse_err = json.parse(json_str)
		if parse_err == OK and typeof(json.data) == TYPE_DICTIONARY:
			_game_docs = json.data

func open() -> void:
	ActionVFXManager.animate_dialog_open(self, null, true)
	scroll_content.scroll_vertical = 0
	_update_tab_button_styles()
	_render_content()

func close() -> void:
	if is_instance_valid(game_select_modal) and game_select_modal.visible:
		_close_game_select_modal()
		return
	ActionVFXManager.animate_dialog_close(self, null, func():
		closed.emit()
	)

func _update_tab_button_styles() -> void:
	var tabs = [btn_tab_overview, btn_tab_rules, btn_tab_gameplay]
	for i in range(tabs.size()):
		var b = tabs[i]
		if i == active_sub_tab:
			KenneyUI.style_button(b, KenneyUI.COLOR_YELLOW)
			b.add_theme_color_override("font_color", Color(0.18, 0.1, 0.02, 1.0))
		else:
			KenneyUI.style_button(b, KenneyUI.COLOR_GREY)
			b.add_theme_color_override("font_color", Color(0.85, 0.8, 0.72, 0.85))

func _update_selected_game_display() -> void:
	if not is_instance_valid(lbl_selected_game) or not is_instance_valid(selected_game_icon):
		return
	var g_name = "تیک تاک تو"
	for g in GAME_KEYS:
		if g["key"] == selected_game_key:
			g_name = g["name"]
			break
	lbl_selected_game.text = g_name
	
	var icon_path = "res://assets/images/games/%s.jpg" % selected_game_key
	if ResourceLoader.exists(icon_path):
		selected_game_icon.texture = load(icon_path)
		selected_game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	elif selected_game_key == "rank_mode":
		selected_game_icon.texture = load("res://assets/icons/General/rank.png")
		selected_game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif selected_game_key == "lobby_mode":
		selected_game_icon.texture = load("res://assets/icons/General/lobby.png")
		selected_game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		selected_game_icon.texture = load("res://assets/icons/General/lobby.png")
		selected_game_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _open_game_select_modal() -> void:
	game_select_modal.visible = true
	_populate_game_grid()
	
	var p_size = game_select_panel.size
	if p_size == Vector2.ZERO:
		p_size = Vector2(940, 1150)
	game_select_panel.pivot_offset = p_size / 2.0
	game_select_panel.scale = Vector2(0.88, 0.88)
	game_select_panel.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(game_select_panel, "modulate:a", 1.0, 0.18)

func _close_game_select_modal() -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(game_select_panel, "scale", Vector2(0.88, 0.88), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(game_select_panel, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		game_select_modal.visible = false
	)

func _populate_game_grid() -> void:
	for child in game_grid.get_children():
		child.queue_free()
	
	for g in GAME_KEYS:
		var card = _create_game_card(g)
		game_grid.add_child(card)

func _create_game_card(g: Dictionary) -> Control:
	var k = g["key"]
	var is_selected = (k == selected_game_key)
	
	var card = Button.new()
	card.custom_minimum_size = Vector2(380, 190)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.pivot_offset = Vector2(190, 95)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.22, 0.15, 0.1, 0.98)
	style_normal.set_corner_radius_all(18)
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color(1.0, 0.88, 0.28, 1.0) if is_selected else Color(0.82, 0.68, 0.38, 0.85)
	style_normal.shadow_color = Color(1.0, 0.85, 0.25, 0.3) if is_selected else Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 10 if is_selected else 6
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.2, 0.13, 0.98)
	style_hover.set_corner_radius_all(18)
	style_hover.set_border_width_all(3)
	style_hover.border_color = Color(1.0, 0.94, 0.55, 1.0)
	style_hover.shadow_color = Color(1.0, 0.85, 0.2, 0.4)
	style_hover.shadow_size = 12
	style_hover.shadow_offset = Vector2(0, 5)
	
	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)
	
	var bg_warmth = ColorRect.new()
	bg_warmth.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_warmth.color = Color(0.28, 0.18, 0.1, 0.95)
	bg_warmth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg_warmth)
	
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.18, 1.12, 1.05)
	var icon_path = "res://assets/images/games/%s.jpg" % k
	if ResourceLoader.exists(icon_path):
		img.texture = load(icon_path)
	elif k == "rank_mode":
		img.texture = load("res://assets/icons/General/rank.png")
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif k == "lobby_mode":
		img.texture = load("res://assets/icons/General/lobby.png")
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		img.texture = load("res://assets/icons/General/lobby.png")
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(img)
	
	# Bottom title banner
	var banner = PanelContainer.new()
	banner.anchor_top = 0.68
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.12, 0.08, 0.05, 0.92)
	b_style.border_width_top = 2
	b_style.border_color = Color(0.85, 0.7, 0.35, 0.75)
	b_style.corner_radius_bottom_left = 16
	b_style.corner_radius_bottom_right = 16
	banner.add_theme_stylebox_override("panel", b_style)
	
	var lbl = Label.new()
	lbl.text = g["name"]
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)
	
	# Difficulty / Mode pill (top-left)
	var mode_pill = PanelContainer.new()
	mode_pill.position = Vector2(12, 12)
	mode_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.16, 0.1, 0.06, 0.85)
	p_style.border_width_left = 1
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.78, 0.62, 0.35, 0.8)
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	mode_pill.add_theme_stylebox_override("panel", p_style)
	var mode_lbl = Label.new()
	mode_lbl.text = g.get("diff", "آسان")
	mode_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	mode_lbl.add_theme_font_size_override("font_size", 18)
	mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	mode_pill.add_child(mode_lbl)
	card.add_child(mode_pill)
	
	# Golden active badge (top-right)
	if is_selected:
		var badge = PanelContainer.new()
		badge.custom_minimum_size = Vector2(36, 36)
		badge.position = Vector2(card.custom_minimum_size.x - 48, 12)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(1.0, 0.82, 0.15, 1.0)
		badge_style.set_corner_radius_all(18)
		badge_style.border_color = Color(1, 1, 1, 0.95)
		badge_style.set_border_width_all(2)
		badge_style.shadow_color = Color(1.0, 0.8, 0.2, 0.5)
		badge_style.shadow_size = 6
		badge.add_theme_stylebox_override("panel", badge_style)
		
		var check_lbl = Label.new()
		check_lbl.text = "✓"
		check_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		check_lbl.add_theme_font_size_override("font_size", 22)
		check_lbl.add_theme_color_override("font_color", Color(0.15, 0.1, 0.02, 1.0))
		check_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		check_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(check_lbl)
		card.add_child(badge)
	
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var drag_state = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_games.scroll_vertical
			else:
				var was_dragging = drag_state["dragging"]
				var was_active = drag_state["active"]
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_rel = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_rel <= 14.0:
						AudioManager.sfx_button()
						selected_game_key = k
						_update_selected_game_display()
						scroll_content.scroll_vertical = 0
						_render_content()
						_close_game_select_modal()
		elif event is InputEventMouseMotion and drag_state["active"]:
			var dy = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or drag_state["dragging"]:
				drag_state["dragging"] = true
				scroll_games.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)
	
	return card

func _render_content() -> void:
	for child in content_box.get_children():
		child.queue_free()
	
	# If rank or lobby special mode
	if selected_game_key == "rank_mode" or selected_game_key == "lobby_mode":
		sub_tabs_row.visible = false
		_render_general_guide(selected_game_key)
		return
	
	sub_tabs_row.visible = true
	var g_data = _game_docs.get(selected_game_key, {})
	var meta = _get_game_meta(selected_game_key)
	
	# Header Card (Icon, Title, Time, Difficulty)
	var header_card = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color(0.18, 0.12, 0.07, 0.9)
	h_style.border_color = Color(0.85, 0.72, 0.35, 0.8)
	h_style.set_border_width_all(2)
	h_style.set_corner_radius_all(16)
	h_style.content_margin_left = 18
	h_style.content_margin_right = 18
	h_style.content_margin_top = 12
	h_style.content_margin_bottom = 12
	header_card.add_theme_stylebox_override("panel", h_style)
	
	var h_row = HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 18)
	h_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Badges (Time & Difficulty)
	var badges_col = VBoxContainer.new()
	badges_col.alignment = BoxContainer.ALIGNMENT_CENTER
	badges_col.add_theme_constant_override("separation", 6)
	
	var time_lbl = Label.new()
	time_lbl.text = "⏱️ مدت بازی: %s" % meta.get("time", "")
	time_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	time_lbl.add_theme_font_size_override("font_size", 26)
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	badges_col.add_child(time_lbl)
	
	var diff_lbl = Label.new()
	diff_lbl.text = "⚡ سطح سختی: %s" % meta.get("diff", "")
	diff_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	diff_lbl.add_theme_font_size_override("font_size", 26)
	diff_lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.7))
	badges_col.add_child(diff_lbl)
	h_row.add_child(badges_col)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(spacer)
	
	# Title
	var title_lbl = Label.new()
	title_lbl.text = meta.get("name", "")
	title_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("shadow_outline_size", 3)
	h_row.add_child(title_lbl)
	
	# Game Cover Icon
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(84, 84)
	var ib_style = StyleBoxFlat.new()
	ib_style.bg_color = Color(0.08, 0.05, 0.03, 0.95)
	ib_style.border_color = Color(1.0, 0.85, 0.35, 0.9)
	ib_style.set_border_width_all(2)
	ib_style.set_corner_radius_all(14)
	icon_box.add_theme_stylebox_override("panel", ib_style)
	
	var cover_img = TextureRect.new()
	cover_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var ipath = "res://assets/images/games/%s.jpg" % selected_game_key
	if ResourceLoader.exists(ipath):
		cover_img.texture = load(ipath)
	icon_box.add_child(cover_img)
	h_row.add_child(icon_box)
	
	header_card.add_child(h_row)
	content_box.add_child(header_card)
	
	# Body Text
	var text_content = ""
	var section_title = ""
	if active_sub_tab == 0:
		section_title = "داستان و پیش‌زمینه بازی"
		text_content = str(g_data.get("narrative", "این بازی یکی از بازی‌های جذاب و خاطره‌انگیز کافه فکر است."))
	elif active_sub_tab == 1:
		section_title = "قوانین و استراتژی‌های بازی"
		text_content = str(g_data.get("guide", "هدف اصلی بازی تلاش برای غلبه بر حریف با بهره‌گیری از هوش و تاکتیک است."))
	else:
		section_title = "راهنمای بازی آنلاین در کافه فکر"
		text_content = str(g_data.get("gameplay", "با شروع بازی، هر بازیکن در نوبت خود زمان مشخصی برای انتخاب حرکت دارد. در صورت قطعی اتصال، تا ۱۲۰ ثانیه فرصت بازگشت وجود دارد."))
	
	var sec_lbl = Label.new()
	sec_lbl.text = "📜 " + section_title
	sec_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	sec_lbl.add_theme_font_size_override("font_size", 34)
	sec_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_box.add_child(sec_lbl)
	
	var body_lbl = Label.new()
	body_lbl.text = text_content
	body_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	body_lbl.add_theme_font_size_override("font_size", 32)
	body_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.86))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body_lbl.add_theme_constant_override("line_spacing", 14)
	content_box.add_child(body_lbl)

func _render_general_guide(mode_key: String) -> void:
	var title = "رقابت‌های آنلاین رنکد" if mode_key == "rank_mode" else "اتاق‌های دوستانه (لابی)"
	var text_key = "rankGuide" if mode_key == "rank_mode" else "lobbyGuide"
	var text_content = str(_game_docs.get(text_key, ""))
	if text_content.is_empty():
		if mode_key == "rank_mode":
			text_content = "در بخش رقابت آنلاین، سیستم به طور خودکار بازیکنی هم‌سطح شما انتخاب می‌کند. با هر پیروزی، امتیاز رنکینگ شما افزایش یافته و در جدول برترین‌های کافه فکر ارتقا می‌یابید."
		else:
			text_content = "در لابی خصوصی می‌توانید با ساختن اتاق دلخواه یا وارد کردن کد ۶ رقمی دوستانتان، مستقیماً بدون تأثیر در رنک با دوستان خود بازی کنید."
			
	var t_lbl = Label.new()
	t_lbl.text = "🏆 " + title
	t_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	t_lbl.add_theme_font_size_override("font_size", 36)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_box.add_child(t_lbl)
	
	var b_lbl = Label.new()
	b_lbl.text = text_content
	b_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	b_lbl.add_theme_font_size_override("font_size", 32)
	b_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.86))
	b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b_lbl.add_theme_constant_override("line_spacing", 14)
	content_box.add_child(b_lbl)

func _get_game_meta(key: String) -> Dictionary:
	for g in GAME_KEYS:
		if g["key"] == key:
			return g
	return {"name": key, "time": "۱۰ دقیقه", "diff": "متوسط"}
