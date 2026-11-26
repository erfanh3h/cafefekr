extends PanelContainer

# Classic Rank Game Selection Dialog
# Allows the gamer to filter & pick any game from the cafe, choose AI opponent difficulty
# (1: Easy, 2: Medium [default], 3: Hard), and earn XP & Coins scaled to opponent level & game difficulty.

signal closed()
signal start_game_requested(game_type: String, ai_level: int)

const FONT_HEKAYAT: FontFile = preload("res://assets/fonts/hekayat.ttf")
const FONT_VAZIR: FontFile = preload("res://assets/fonts/Vazir.ttf")
const TEX_CHECK_SEAL: Texture2D = preload("res://assets/images/frames/check.png")

@onready var btn_close: TextureButton = $InnerBezel/VBox/TopRow/CloseWrap/BtnClose

# Preview card for currently selected game
@onready var selected_preview_card: PanelContainer = $InnerBezel/VBox/SelectedPreviewCard
@onready var preview_icon: TextureRect = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/IconFrame/PreviewIcon
@onready var lbl_preview_name: Label = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/HeaderInfoRow/LblPreviewName
@onready var lbl_preview_diff: Label = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/HeaderInfoRow/DiffBadge/LblDiff
@onready var diff_badge: PanelContainer = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/HeaderInfoRow/DiffBadge
@onready var win_chip: PanelContainer = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/WinChip
@onready var draw_chip: PanelContainer = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/DrawChip
@onready var lose_chip: PanelContainer = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/LoseChip
@onready var lbl_win_xp: Label = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/WinChip/LblWinXp
@onready var lbl_draw_xp: Label = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/DrawChip/LblDrawXp
@onready var lbl_lose_xp: Label = $InnerBezel/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/RewardsRow/LoseChip/LblLoseXp

# AI opponent difficulty selector
@onready var lbl_ai_level_desc: Label = $InnerBezel/VBox/AiLevelTrack/AiLevelCol/AiLevelHeader/LblAiLevelDesc
@onready var ai_level_row: HBoxContainer = $InnerBezel/VBox/AiLevelTrack/AiLevelCol/AiLevelRow

# Difficulty filter row
@onready var filter_row: HBoxContainer = $InnerBezel/VBox/FilterTrack/FilterRow

# Grid of games
@onready var scroll_games: ScrollContainer = $InnerBezel/VBox/ScrollGames
@onready var game_grid: GridContainer = $InnerBezel/VBox/ScrollGames/GameGrid

# Bottom Start Game action
@onready var btn_start_game: Button = $InnerBezel/VBox/BottomRow/BtnStartGame

var selected_game_type: String = GameTypes.TIC_TAC_TOE
var selected_ai_level: int = GameRegistry.DEFAULT_CLASSIC_AI_LEVEL
var _difficulty_filter: String = "all" # "all" | "easy" | "normal" | "hard"
var _game_cards: Dictionary = {} # game_type -> Button card

# All playable games ordered logically
const AVAILABLE_GAMES: Array[String] = [
	GameTypes.TIC_TAC_TOE,
	GameTypes.CHESS,
	GameTypes.BACKGAMMON,
	GameTypes.CHECKERS,
	GameTypes.FOURINROW,
	GameTypes.OTHELLO,
	GameTypes.MILL,
	GameTypes.DOTBOX,
	GameTypes.PENTAGO,
	GameTypes.YINSH,
	GameTypes.QUORIDOR,
	GameTypes.YATZY,
	GameTypes.LUDO,
	GameTypes.RISK,
	GameTypes.UNO,
	GameTypes.COUP,
	GameTypes.MONOPOLY,
	GameTypes.QUIZ,
	GameTypes.BATTLESHIP,
	GameTypes.FEKRBEKR,
	GameTypes.RPC,
	GameTypes.SUDOKU,
	GameTypes.BOXFOUR,
	GameTypes.MNUMBERS,
	GameTypes.MSWEEPER
]

var _style_card_normal: StyleBoxFlat
var _style_card_hover: StyleBoxFlat
var _style_card_selected: StyleBoxFlat
var _cached_game_textures: Dictionary = {}


func _get_game_texture(g_type: String) -> Texture2D:
	if _cached_game_textures.has(g_type):
		return _cached_game_textures[g_type] as Texture2D
	var icon_path: String = "res://assets/images/games/%s.png" % g_type.to_lower()
	if not ResourceLoader.exists(icon_path):
		icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	if not tex:
		for ext in ["png", "jpg"]:
			var raw_path: String = ProjectSettings.globalize_path("res://assets/images/games/%s.%s" % [g_type.to_lower(), ext])
			if FileAccess.file_exists(raw_path):
				var img: Image = Image.load_from_file(raw_path)
				if img and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
					break
	if not tex:
		tex = load("res://assets/icons/General/lobby.png") as Texture2D
	_cached_game_textures[g_type] = tex
	return tex


func _ready() -> void:
	visible = false
	_setup_styles()
	_style_start_button()
	ActionVFXManager.apply_button_juice(btn_start_game, "tap_button")
	ActionVFXManager.apply_button_juice(btn_close, "tap_button")

	btn_close.pressed.connect(_on_close_pressed)
	btn_start_game.pressed.connect(_on_start_game_pressed)

	_render_ai_level_bar()
	_render_filter_bar()
	ResponsiveUI.register_dialog(self, 672.0, 1170.0, 320.0, 480.0)
	if is_instance_valid(btn_start_game) and not btn_start_game.resized.is_connected(_fit_start_button_text):
		btn_start_game.resized.connect(_fit_start_button_text)
	_populate_games_grid()
	_update_selected_preview()


func _is_mobile() -> bool:
	return GameManager.is_mobile


func _setup_styles() -> void:
	var p4_sb := StyleBoxTexture.new()
	p4_sb.texture = preload("res://assets/images/frames/frame4.png")
	p4_sb.texture_margin_left = 48.0
	p4_sb.texture_margin_right = 48.0
	p4_sb.texture_margin_top = 42.0
	p4_sb.texture_margin_bottom = 42.0
	p4_sb.content_margin_left = 44.0
	p4_sb.content_margin_right = 44.0
	p4_sb.content_margin_top = 26.0
	p4_sb.content_margin_bottom = 26.0
	selected_preview_card.add_theme_stylebox_override("panel", p4_sb)

	# Subtle antique walnut card pedestal for unselected games
	_style_card_normal = StyleBoxFlat.new()
	_style_card_normal.bg_color = Color(0.135, 0.084, 0.048, 0.94)
	_style_card_normal.set_corner_radius_all(18)
	_style_card_normal.set_border_width_all(1)
	_style_card_normal.border_color = Color(0.56, 0.42, 0.22, 0.65)
	_style_card_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	_style_card_normal.shadow_size = 0 if _is_mobile() else 5
	_style_card_normal.shadow_offset = Vector2(0, 2)

	# Hover style
	_style_card_hover = StyleBoxFlat.new()
	_style_card_hover.bg_color = Color(0.18, 0.115, 0.064, 0.96)
	_style_card_hover.set_corner_radius_all(18)
	_style_card_hover.set_border_width_all(2)
	_style_card_hover.border_color = Color(0.95, 0.80, 0.38, 0.92)
	_style_card_hover.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	_style_card_hover.shadow_size = 0 if _is_mobile() else 6
	_style_card_hover.shadow_offset = Vector2(0, 3)

	# Selected style with crisp golden border & luminous glow
	_style_card_selected = StyleBoxFlat.new()
	_style_card_selected.bg_color = Color(0.24, 0.16, 0.06, 0.98)
	_style_card_selected.set_corner_radius_all(18)
	_style_card_selected.set_border_width_all(3)
	_style_card_selected.border_color = Color(1.0, 0.86, 0.32, 1.0)
	_style_card_selected.shadow_color = Color(1.0, 0.82, 0.22, 0.45)
	_style_card_selected.shadow_size = 0 if _is_mobile() else 10
	_style_card_selected.shadow_offset = Vector2(0, 2)


func _style_start_button() -> void:
	if not is_instance_valid(btn_start_game):
		return
	KenneyUI.style_button(btn_start_game, KenneyUI.COLOR_GREEN)
	btn_start_game.focus_mode = Control.FOCUS_NONE
	btn_start_game.clip_text = true
	btn_start_game.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_start_game.custom_minimum_size.y = 100.0
	ResponsiveUI.apply_scaled_font(btn_start_game, 28, 22, 32)


func _render_ai_level_bar() -> void:
	if not is_instance_valid(ai_level_row):
		return
	for c in ai_level_row.get_children():
		c.queue_free()

	if is_instance_valid(lbl_ai_level_desc):
		lbl_ai_level_desc.text = GameRegistry.get_classic_ai_level_desc_fa(selected_ai_level)

	# RTL visual order (rightmost = Easy [1], Medium [2], Hard [3])
	var levels: Array[Dictionary] = [
		{"level": GameRegistry.CLASSIC_AI_LEVEL_HARD, "diff": "hard", "label": "سخت"},
		{"level": GameRegistry.CLASSIC_AI_LEVEL_MEDIUM, "diff": "normal", "label": "متوسط (پیش‌فرض)"},
		{"level": GameRegistry.CLASSIC_AI_LEVEL_EASY, "diff": "easy", "label": "آسان"}
	]

	for item in levels:
		var lvl: int = int(item["level"])
		var diff_key: String = str(item["diff"])
		var label_txt: String = str(item["label"])
		var is_active: bool = (selected_ai_level == lvl)
		var pal: Dictionary = _get_difficulty_palette(diff_key)

		var btn: Button = Button.new()
		btn.text = label_txt
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", FONT_VAZIR)
		ResponsiveUI.apply_scaled_font(btn, 16 if is_active else 15, 14, 18)

		var sb_norm: StyleBoxFlat = StyleBoxFlat.new()
		sb_norm.set_corner_radius_all(12)
		sb_norm.content_margin_left = 10.0
		sb_norm.content_margin_right = 10.0
		sb_norm.content_margin_top = 8.0
		sb_norm.content_margin_bottom = 8.0
		if is_active:
			sb_norm.bg_color = pal["bg"] as Color
			sb_norm.border_color = pal["border"] as Color
			sb_norm.set_border_width_all(2)
			btn.add_theme_color_override("font_color", pal["text"] as Color)
			btn.add_theme_color_override("font_hover_color", pal["text"] as Color)
			btn.add_theme_color_override("font_pressed_color", pal["text"] as Color)
		else:
			sb_norm.bg_color = Color(0.11, 0.068, 0.038, 0.92)
			sb_norm.border_color = Color(0.48, 0.36, 0.20, 0.55)
			sb_norm.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.82, 0.74, 0.62, 0.92))
			btn.add_theme_color_override("font_hover_color", Color(0.98, 0.92, 0.78, 1.0))
			btn.add_theme_color_override("font_pressed_color", pal["text"] as Color)

		var sb_hover: StyleBoxFlat = sb_norm.duplicate() as StyleBoxFlat
		sb_hover.bg_color = (sb_norm.bg_color as Color).lightened(0.08)
		sb_hover.border_color = pal["border"] as Color

		btn.add_theme_stylebox_override("normal", sb_norm)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_norm)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("disabled", sb_norm)

		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			if selected_ai_level != lvl:
				selected_ai_level = lvl
				_render_ai_level_bar()
				_update_selected_preview()
		)
		ai_level_row.add_child(btn)


func _render_filter_bar() -> void:
	if not is_instance_valid(filter_row):
		return
	for c in filter_row.get_children():
		c.queue_free()

	# RTL visual order (rightmost = All, then Easy, Normal, Hard)
	var filters: Array = [
		{"id": "hard", "label": "سخت", "accent": Color(0.94, 0.44, 0.40, 1.0)},
		{"id": "normal", "label": "متوسط", "accent": Color(0.98, 0.82, 0.34, 1.0)},
		{"id": "easy", "label": "آسان", "accent": Color(0.42, 0.88, 0.56, 1.0)},
		{"id": "all", "label": "همه بازی‌ها", "accent": Color(0.96, 0.80, 0.32, 1.0)}
	]

	for f_item in filters:
		var fd: Dictionary = f_item as Dictionary
		var fid: String = str(fd["id"])
		var flabel: String = str(fd["label"])
		var is_active: bool = (_difficulty_filter == fid)

		var btn: Button = Button.new()
		btn.text = flabel
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CafeSocialTheme.style_parlor_tab_button(btn, is_active, 18, false, 14.0, 10.0)

		ActionVFXManager.apply_button_juice(btn, "tap_button")
		btn.pressed.connect(func():
			AudioManager.sfx_tap()
			if _difficulty_filter != fid:
				_difficulty_filter = fid
				_render_filter_bar()
				_populate_games_grid()
				_update_selected_preview()
		)
		filter_row.add_child(btn)


func _get_filtered_games() -> Array[String]:
	if _difficulty_filter == "all":
		return AVAILABLE_GAMES
	var out: Array[String] = []
	for g_type in AVAILABLE_GAMES:
		if GameRegistry.get_difficulty(g_type) == _difficulty_filter:
			out.append(g_type)
	return out


func open(default_game: String = "", default_ai_level: int = GameRegistry.DEFAULT_CLASSIC_AI_LEVEL) -> void:
	selected_ai_level = GameRegistry.normalize_classic_ai_level(default_ai_level)
	if not default_game.is_empty():
		selected_game_type = GameRegistry.normalize_type(default_game)
		_difficulty_filter = "all"
		_render_filter_bar()
		_populate_games_grid()
	_render_ai_level_bar()
	ActionVFXManager.animate_dialog_open(self, null, true)
	_update_selected_preview()
	_update_grid_selection_visuals()


func close() -> void:
	ActionVFXManager.animate_dialog_close(self, null, func():
		visible = false
		closed.emit()
	)


func _on_close_pressed() -> void:
	AudioManager.sfx_tap()
	close()


func _on_start_game_pressed() -> void:
	AudioManager.sfx_button()
	visible = false
	closed.emit()
	start_game_requested.emit(selected_game_type, selected_ai_level)


func _calculate_game_card_height() -> float:
	var total_w: float = 590.0
	if is_instance_valid(scroll_games) and scroll_games.size.x > 100.0:
		total_w = scroll_games.size.x - 14.0
	elif is_instance_valid(game_grid) and game_grid.size.x > 100.0:
		total_w = game_grid.size.x
	var cell_w: float = floor((total_w - 20.0) / 3.0)
	return maxf(120.0, cell_w)


func _populate_games_grid() -> void:
	game_grid.columns = 3
	for child in game_grid.get_children():
		child.queue_free()
	_game_cards.clear()

	var filtered: Array[String] = _get_filtered_games()

	if not filtered.is_empty() and not (selected_game_type in filtered):
		selected_game_type = filtered[0]

	var initial_h: float = _calculate_game_card_height()
	for g_type in filtered:
		var card: Control = _create_game_card(g_type, initial_h)
		game_grid.add_child(card)
		_game_cards[g_type] = card

	if is_instance_valid(scroll_games):
		scroll_games.scroll_vertical = 0


func _get_difficulty_palette(diff: String) -> Dictionary:
	if diff == "easy":
		return {
			"text": Color(0.50, 0.94, 0.64, 1.0),
			"bg": Color(0.10, 0.24, 0.15, 0.94),
			"border": Color(0.36, 0.82, 0.52, 0.86)
		}
	elif diff == "normal":
		return {
			"text": Color(0.99, 0.85, 0.38, 1.0),
			"bg": Color(0.24, 0.17, 0.06, 0.94),
			"border": Color(0.90, 0.72, 0.28, 0.88)
		}
	return {
		"text": Color(0.99, 0.56, 0.52, 1.0),
		"bg": Color(0.28, 0.10, 0.10, 0.94),
		"border": Color(0.88, 0.36, 0.34, 0.88)
	}


func _create_game_card(g_type: String, initial_h: float = 250.0) -> Control:
	var is_selected: bool = (g_type == selected_game_type)
	var diff: String = GameRegistry.get_difficulty(g_type)
	var diff_name: String = GameRegistry.get_difficulty_name_fa(g_type)
	var diff_pal: Dictionary = _get_difficulty_palette(diff)

	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(0, initial_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = false
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.pivot_offset = Vector2(initial_h / 2.0, initial_h / 2.0)

	card.item_rect_changed.connect(func():
		var w: float = card.size.x
		if w > 60.0:
			var target_h: float = floor(w)
			if absf(card.custom_minimum_size.y - target_h) > 2.0:
				card.set_deferred("custom_minimum_size", Vector2(0, target_h))
				card.pivot_offset = Vector2(w / 2.0, target_h / 2.0)
	)

	var st: StyleBoxFlat = _style_card_selected if is_selected else _style_card_normal
	card.add_theme_stylebox_override("normal", st)
	card.add_theme_stylebox_override("hover", _style_card_hover)
	card.add_theme_stylebox_override("pressed", st)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.add_theme_stylebox_override("disabled", st)

	# 1. Inset Cover Artwork
	var art_margin: MarginContainer = MarginContainer.new()
	art_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_margin.add_theme_constant_override("margin_left", 7)
	art_margin.add_theme_constant_override("margin_right", 7)
	art_margin.add_theme_constant_override("margin_top", 7)
	art_margin.add_theme_constant_override("margin_bottom", 7)
	art_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art_margin)

	var img: TextureRect = TextureRect.new()
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.08, 1.05, 1.01)
	img.texture = _get_game_texture(g_type)
	art_margin.add_child(img)

	# 2. Compact Difficulty Pill (Top-Left)
	var d_pill: PanelContainer = PanelContainer.new()
	d_pill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	d_pill.offset_left = 7.0
	d_pill.offset_top = 7.0
	d_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d_sb: StyleBoxFlat = StyleBoxFlat.new()
	d_sb.bg_color = diff_pal["bg"] as Color
	d_sb.border_color = diff_pal["border"] as Color
	d_sb.set_border_width_all(1)
	d_sb.set_corner_radius_all(8)
	d_sb.content_margin_left = 6.0
	d_sb.content_margin_right = 6.0
	d_sb.content_margin_top = 1.0
	d_sb.content_margin_bottom = 1.0
	d_pill.add_theme_stylebox_override("panel", d_sb)
	card.add_child(d_pill)

	var d_lbl: Label = Label.new()
	d_lbl.text = diff_name
	d_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_lbl.add_theme_font_override("font", FONT_VAZIR)
	ResponsiveUI.apply_text(d_lbl, UITypography.Role.MICRO, {"min_px": 14, "max_px": 17})
	d_lbl.add_theme_color_override("font_color", diff_pal["text"] as Color)
	d_pill.add_child(d_lbl)

	# 3. Golden Selection Seal (Top-Right, uses texture icon instead of raw Unicode glyph)
	var sel_badge: PanelContainer = PanelContainer.new()
	sel_badge.name = "SelectionBadge"
	sel_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sel_badge.offset_left = -33.0
	sel_badge.offset_top = 7.0
	sel_badge.offset_right = -7.0
	sel_badge.offset_bottom = 33.0
	sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.pivot_offset = Vector2(13.0, 13.0)
	var badge_sb: StyleBoxFlat = StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.98, 0.82, 0.28, 0.98)
	badge_sb.border_color = Color(0.18, 0.12, 0.04, 0.95)
	badge_sb.set_border_width_all(2)
	badge_sb.set_corner_radius_all(13)
	badge_sb.content_margin_left = 4.0
	badge_sb.content_margin_right = 4.0
	badge_sb.content_margin_top = 4.0
	badge_sb.content_margin_bottom = 4.0
	badge_sb.shadow_color = Color(0, 0, 0, 0.45)
	badge_sb.shadow_size = 0 if _is_mobile() else 4
	sel_badge.add_theme_stylebox_override("panel", badge_sb)
	sel_badge.visible = is_selected

	var badge_ico: TextureRect = TextureRect.new()
	badge_ico.texture = TEX_CHECK_SEAL
	badge_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.add_child(badge_ico)
	card.add_child(sel_badge)

	# 4. Bottom Title Ribbon Banner
	var banner: PanelContainer = PanelContainer.new()
	banner.anchor_top = 0.70
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = 4.0
	banner.offset_right = -4.0
	banner.offset_bottom = -4.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(g_type, 20.0, 3.0))

	var lbl: Label = Label.new()
	lbl.text = GameTypes.get_display_name_fa(g_type)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_override("font", FONT_HEKAYAT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)

	card.mouse_filter = Control.MOUSE_FILTER_PASS

	# Smooth 60fps Viewport-Coordinate Drag Scrolling + Clean Tap Selection
	var drag_state: Dictionary = {"active": false, "dragging": false, "start_y": 0.0, "start_scroll": 0}
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_state["active"] = true
				drag_state["dragging"] = false
				drag_state["start_y"] = get_viewport().get_mouse_position().y
				drag_state["start_scroll"] = scroll_games.scroll_vertical
			else:
				var was_dragging: bool = bool(drag_state["dragging"])
				var was_active: bool = bool(drag_state["active"])
				drag_state["active"] = false
				drag_state["dragging"] = false
				if was_active and not was_dragging:
					var dy_release: float = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_release <= 14.0:
						AudioManager.sfx_tap()
						_select_game(g_type)
		elif event is InputEventMouseMotion and bool(drag_state["active"]):
			var dy: float = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or bool(drag_state["dragging"]):
				drag_state["dragging"] = true
				scroll_games.scroll_vertical = maxi(0, int(drag_state["start_scroll"]) - int(dy))
	)

	return card


func _select_game(g_type: String) -> void:
	selected_game_type = g_type
	_update_selected_preview()
	_update_grid_selection_visuals()


func _update_grid_selection_visuals() -> void:
	for g_type in _game_cards:
		var c: Button = _game_cards[g_type] as Button
		if not is_instance_valid(c):
			continue
		var is_sel: bool = (g_type == selected_game_type)
		var st: StyleBoxFlat = _style_card_selected if is_sel else _style_card_normal
		c.add_theme_stylebox_override("normal", st)
		c.add_theme_stylebox_override("hover", _style_card_hover)
		c.add_theme_stylebox_override("pressed", st)
		c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var badge: Control = c.get_node_or_null("SelectionBadge") as Control
		if is_instance_valid(badge):
			if is_sel and not badge.visible:
				badge.visible = true
				badge.scale = Vector2(0.5, 0.5)
				var tw: Tween = badge.create_tween()
				tw.tween_property(badge, "scale", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(badge, "scale", Vector2.ONE, 0.08)
			elif not is_sel:
				badge.visible = false
		if is_sel:
			var tw_c: Tween = c.create_tween()
			tw_c.tween_property(c, "scale", Vector2(1.025, 1.025), 0.08)
			tw_c.tween_property(c, "scale", Vector2.ONE, 0.10)


func _style_xp_chip(chip: PanelContainer, border_col: Color) -> void:
	if not is_instance_valid(chip):
		return
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.055, 0.032, 0.95)
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	chip.add_theme_stylebox_override("panel", sb)


func _update_selected_preview() -> void:
	if not is_instance_valid(preview_icon):
		return
	preview_icon.texture = _get_game_texture(selected_game_type)

	var game_name_fa: String = GameTypes.get_display_name_fa(selected_game_type)
	lbl_preview_name.text = game_name_fa

	var diff: String = GameRegistry.get_difficulty(selected_game_type)
	var diff_name: String = GameRegistry.get_difficulty_name_fa(selected_game_type)
	var pal: Dictionary = _get_difficulty_palette(diff)

	lbl_preview_diff.text = "سختی: %s" % diff_name
	lbl_preview_diff.add_theme_color_override("font_color", pal["text"] as Color)
	if is_instance_valid(diff_badge):
		var d_sb: StyleBoxFlat = StyleBoxFlat.new()
		d_sb.bg_color = pal["bg"] as Color
		d_sb.border_color = pal["border"] as Color
		d_sb.set_border_width_all(1)
		d_sb.set_corner_radius_all(10)
		d_sb.content_margin_left = 10.0
		d_sb.content_margin_right = 10.0
		d_sb.content_margin_top = 3.0
		d_sb.content_margin_bottom = 3.0
		diff_badge.add_theme_stylebox_override("panel", d_sb)

	# 3-Chip Reward Breakdown (XP + Coins scaled by AI opponent level & game difficulty)
	var srv_classic_cfg: Dictionary = {}
	if typeof(GameManager.server_config) == TYPE_DICTIONARY:
		var raw_cfg: Variant = GameManager.server_config.get("classic_rank_config", {})
		if typeof(raw_cfg) == TYPE_DICTIONARY:
			srv_classic_cfg = raw_cfg as Dictionary
	var reward_prof: Dictionary = GameRegistry.get_classic_rank_reward_profile(selected_game_type, selected_ai_level, srv_classic_cfg)
	var win_xp: int = int(reward_prof.get("win_xp", 0))
	var draw_xp: int = int(reward_prof.get("draw_xp", 0))
	var lose_xp: int = int(reward_prof.get("lose_xp", 0))
	var win_coin: int = int(reward_prof.get("win_coin", 0))
	var draw_coin: int = int(reward_prof.get("draw_coin", 0))
	var lose_coin: int = int(reward_prof.get("lose_coin", 0))

	var format_chip := func(title_fa: String, xp_val: int, coin_val: int) -> String:
		if coin_val > 0:
			return "%s\n+%s XP • +%s سکه" % [title_fa, GameManager.to_fa_num(xp_val), GameManager.to_fa_num(coin_val)]
		return "%s\n+%s XP" % [title_fa, GameManager.to_fa_num(xp_val)]

	lbl_win_xp.text = format_chip.call("برد", win_xp, win_coin)
	lbl_draw_xp.text = format_chip.call("مساوی", draw_xp, draw_coin)
	lbl_lose_xp.text = format_chip.call("باخت", lose_xp, lose_coin)

	_style_xp_chip(win_chip, Color(0.36, 0.80, 0.50, 0.62))
	_style_xp_chip(draw_chip, Color(0.84, 0.68, 0.28, 0.60))
	_style_xp_chip(lose_chip, Color(0.56, 0.44, 0.30, 0.52))

	if is_instance_valid(btn_start_game):
		var ai_lvl_fa: String = GameRegistry.get_classic_ai_level_name_fa(selected_ai_level)
		btn_start_game.text = "شروع %s • حریف %s" % [game_name_fa, ai_lvl_fa]
		_fit_start_button_text()


func _fit_start_button_text() -> void:
	if not is_instance_valid(btn_start_game):
		return
	var base_px: int = UITypography.scale_px(28, 22, 32)
	var avail_w: float = maxf(260.0, btn_start_game.size.x - 80.0)
	if btn_start_game.size.x <= 10.0:
		avail_w = 500.0
	var chosen: int = base_px
	while chosen > 21:
		if FONT_HEKAYAT.get_string_size(btn_start_game.text, HORIZONTAL_ALIGNMENT_CENTER, -1, chosen).x <= avail_w:
			break
		chosen -= 1
	ResponsiveUI.apply_scaled_font(btn_start_game, chosen, 21, 32)
