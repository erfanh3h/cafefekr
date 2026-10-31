extends PanelContainer

# Classic Rank Game Selection Dialog
# Allows the gamer to pick any game from the cafe and start an immediate match
# against an AI bot (difficulty level 2) to earn XP based on game difficulty.

signal closed()
signal start_game_requested(game_type: String)

@onready var btn_close: TextureButton = $Margin/VBox/TopRow/BtnClose
@onready var lbl_title: Label = $Margin/VBox/TopRow/TitleBox/LblTitle
@onready var lbl_subtitle: Label = $Margin/VBox/TopRow/TitleBox/LblSubtitle

# Preview card for currently selected game
@onready var selected_preview_card: PanelContainer = $Margin/VBox/SelectedPreviewCard
@onready var preview_icon: TextureRect = $Margin/VBox/SelectedPreviewCard/Margin/HBox/IconFrame/PreviewIcon
@onready var lbl_preview_name: Label = $Margin/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/LblPreviewName
@onready var lbl_preview_diff: Label = $Margin/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/HBoxBadges/DiffBadge/LblDiff
@onready var diff_badge: PanelContainer = $Margin/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/HBoxBadges/DiffBadge
@onready var lbl_preview_rewards: Label = $Margin/VBox/SelectedPreviewCard/Margin/HBox/VBoxInfo/LblPreviewRewards

# Grid of games
@onready var scroll_games: ScrollContainer = $Margin/VBox/ScrollGames
@onready var game_grid: GridContainer = $Margin/VBox/ScrollGames/GameGrid

# Bottom Start Game action
@onready var btn_start_game: Button = $Margin/VBox/BottomRow/BtnStartGame

var selected_game_type: String = GameTypes.TIC_TAC_TOE
var _game_cards: Dictionary = {} # game_type -> Button card

# All 19 playable games ordered logically
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
	GameTypes.YATZY,
	GameTypes.LUDO,
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

func _ready() -> void:
	visible = false
	_setup_styles()
	
	KenneyUI.style_button(btn_start_game, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(btn_start_game, "tap_button")
	
	btn_close.pressed.connect(_on_close_pressed)
	btn_start_game.pressed.connect(_on_start_game_pressed)
	
	_populate_games_grid()
	_update_selected_preview()

func _setup_styles() -> void:
	# Warm wooden card normal style matching lobby modal
	_style_card_normal = StyleBoxFlat.new()
	_style_card_normal.bg_color = Color(0.22, 0.15, 0.1, 0.98)
	_style_card_normal.set_corner_radius_all(18)
	_style_card_normal.set_border_width_all(3)
	_style_card_normal.border_color = Color(0.82, 0.68, 0.38, 0.85)
	_style_card_normal.shadow_color = Color(0, 0, 0, 0.5)
	_style_card_normal.shadow_size = 6
	_style_card_normal.shadow_offset = Vector2(0, 4)

	# Hover style
	_style_card_hover = StyleBoxFlat.new()
	_style_card_hover.bg_color = Color(0.3, 0.2, 0.13, 0.98)
	_style_card_hover.set_corner_radius_all(18)
	_style_card_hover.set_border_width_all(3)
	_style_card_hover.border_color = Color(1.0, 0.94, 0.55, 1.0)
	_style_card_hover.shadow_color = Color(1.0, 0.85, 0.2, 0.4)
	_style_card_hover.shadow_size = 12
	_style_card_hover.shadow_offset = Vector2(0, 5)

	# Selected style with golden aura glow
	_style_card_selected = StyleBoxFlat.new()
	_style_card_selected.bg_color = Color(0.24, 0.16, 0.1, 0.98)
	_style_card_selected.set_corner_radius_all(18)
	_style_card_selected.set_border_width_all(4)
	_style_card_selected.border_color = Color(1.0, 0.88, 0.28, 1.0)
	_style_card_selected.shadow_color = Color(1.0, 0.85, 0.25, 0.45)
	_style_card_selected.shadow_size = 14
	_style_card_selected.shadow_offset = Vector2(0, 4)

func open(default_game: String = "") -> void:
	if not default_game.is_empty():
		selected_game_type = GameRegistry.normalize_type(default_game)
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
	ActionVFXManager.animate_dialog_close(self, null, func():
		visible = false
		closed.emit()
		start_game_requested.emit(selected_game_type)
	)

func _populate_games_grid() -> void:
	for child in game_grid.get_children():
		child.queue_free()
	_game_cards.clear()
	
	for g_type in AVAILABLE_GAMES:
		var card = _create_game_card(g_type)
		game_grid.add_child(card)
		_game_cards[g_type] = card

func _create_game_card(g_type: String) -> Control:
	var is_selected = (g_type == selected_game_type)
	
	# Native Button control ensures robust child clipping and anchor support
	var card = Button.new()
	card.custom_minimum_size = Vector2(380, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.pivot_offset = Vector2(190, 100)
	
	var st = _style_card_selected if is_selected else _style_card_normal
	card.add_theme_stylebox_override("normal", st)
	card.add_theme_stylebox_override("hover", _style_card_hover)
	card.add_theme_stylebox_override("pressed", st)
	card.add_theme_stylebox_override("focus", st)
	
	# 1. Warm underlay glow so transparent or dark areas look warm
	var bg_warmth = ColorRect.new()
	bg_warmth.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_warmth.color = Color(0.28, 0.18, 0.1, 0.95)
	bg_warmth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg_warmth)
	
	# 2. Cover artwork (brightened and modulated for crisp contrast)
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.18, 1.12, 1.05)
	var icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	if ResourceLoader.exists(icon_path):
		img.texture = load(icon_path)
	else:
		img.texture = load("res://assets/icons/General/lobby.png")
	card.add_child(img)
	
	# 3. Gradient shadow overlay for maximum readability
	var shadow_overlay = ColorRect.new()
	shadow_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow_overlay.color = Color(0.02, 0.01, 0.0, 0.22)
	shadow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shadow_overlay)
	
	# 4. Bottom title banner with gold separator line
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
	lbl.text = GameTypes.get_display_name_fa(g_type)
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)
	
	# 5. Difficulty Pill badge (top-left)
	var diff = GameRegistry.get_difficulty(g_type)
	var diff_name = GameRegistry.get_difficulty_name_fa(g_type)
	var diff_pill = PanelContainer.new()
	diff_pill.position = Vector2(12, 12)
	diff_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	var p_color = Color(0.4, 0.9, 0.5) if diff == "easy" else (Color(1.0, 0.88, 0.4) if diff == "normal" else Color(1.0, 0.5, 0.4))
	p_style.bg_color = Color(0.14, 0.09, 0.05, 0.9)
	p_style.border_color = p_color
	p_style.set_border_width_all(1)
	diff_pill.add_theme_stylebox_override("panel", p_style)
	
	var d_lbl = Label.new()
	d_lbl.text = diff_name
	d_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	d_lbl.add_theme_font_size_override("font_size", 18)
	d_lbl.add_theme_color_override("font_color", p_color)
	diff_pill.add_child(d_lbl)
	card.add_child(diff_pill)
	
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Smooth 60fps Viewport-Coordinate Drag Scrolling + Clean Tap Selection
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
					var dy_release = absf(get_viewport().get_mouse_position().y - float(drag_state["start_y"]))
					if dy_release <= 14.0:
						AudioManager.sfx_tap()
						_select_game(g_type)
		elif event is InputEventMouseMotion and drag_state["active"]:
			var dy = get_viewport().get_mouse_position().y - float(drag_state["start_y"])
			if absf(dy) > 12.0 or drag_state["dragging"]:
				drag_state["dragging"] = true
				scroll_games.scroll_vertical = max(0, int(drag_state["start_scroll"]) - int(dy))
	)
	
	return card

func _select_game(g_type: String) -> void:
	selected_game_type = g_type
	_update_selected_preview()
	_update_grid_selection_visuals()

func _update_grid_selection_visuals() -> void:
	for g_type in _game_cards:
		var c = _game_cards[g_type]
		if not is_instance_valid(c):
			continue
		var is_sel = (g_type == selected_game_type)
		var st = _style_card_selected if is_sel else _style_card_normal
		c.add_theme_stylebox_override("normal", st)
		c.add_theme_stylebox_override("hover", _style_card_hover)
		c.add_theme_stylebox_override("pressed", st)
		c.add_theme_stylebox_override("focus", st)

func _update_selected_preview() -> void:
	if not is_instance_valid(preview_icon):
		return
	var cover_path = "res://assets/images/games/%s.jpg" % selected_game_type.to_lower()
	if ResourceLoader.exists(cover_path):
		preview_icon.texture = load(cover_path)
	else:
		preview_icon.texture = load("res://assets/icons/General/lobby.png")
	
	lbl_preview_name.text = GameTypes.get_display_name_fa(selected_game_type)
	
	var diff = GameRegistry.get_difficulty(selected_game_type)
	var diff_name = GameRegistry.get_difficulty_name_fa(selected_game_type)
	lbl_preview_diff.text = "درجه سختی: " + diff_name
	
	var badge_col = Color(0.4, 0.9, 0.5) if diff == "easy" else (Color(1.0, 0.88, 0.4) if diff == "normal" else Color(1.0, 0.5, 0.4))
	lbl_preview_diff.add_theme_color_override("font_color", badge_col)
	
	# Rewards info
	var win_xp = 15 if diff == "easy" else (25 if diff == "normal" else 40)
	var draw_xp = 8 if diff == "easy" else (14 if diff == "normal" else 20)
	var lose_xp = 4 if diff == "easy" else (7 if diff == "normal" else 10)
	lbl_preview_rewards.text = "پاداش: 🏆 برد %d+ XP | 🤝 مساوی %d+ XP | 👏 باخت %d+ XP" % [win_xp, draw_xp, lose_xp]
