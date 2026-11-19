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
		return _cached_game_textures[g_type]
	var icon_path = "res://assets/images/games/%s.png" % g_type.to_lower()
	if not ResourceLoader.exists(icon_path):
		icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path)
	if not tex:
		for ext in ["png", "jpg"]:
			var raw_path = ProjectSettings.globalize_path("res://assets/images/games/%s.%s" % [g_type.to_lower(), ext])
			if FileAccess.file_exists(raw_path):
				var img = Image.load_from_file(raw_path)
				if img and not img.is_empty():
					tex = ImageTexture.create_from_image(img)
					break
	if not tex:
		tex = load("res://assets/icons/General/lobby.png")
	_cached_game_textures[g_type] = tex
	return tex

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
	# Clean transparent card style (no dark box or shadow under game icon)
	_style_card_normal = StyleBoxFlat.new()
	_style_card_normal.bg_color = Color(0, 0, 0, 0)
	_style_card_normal.set_corner_radius_all(18)
	_style_card_normal.set_border_width_all(0)
	_style_card_normal.shadow_size = 0

	# Hover style
	_style_card_hover = StyleBoxFlat.new()
	_style_card_hover.bg_color = Color(0, 0, 0, 0)
	_style_card_hover.set_corner_radius_all(18)
	_style_card_hover.set_border_width_all(3)
	_style_card_hover.border_color = Color(1.0, 0.94, 0.55, 0.9)
	_style_card_hover.shadow_size = 0

	# Selected style with crisp golden border & luminous glow
	_style_card_selected = StyleBoxFlat.new()
	_style_card_selected.bg_color = Color(0.98, 0.84, 0.25, 0.12)
	_style_card_selected.set_corner_radius_all(18)
	_style_card_selected.set_border_width_all(4)
	_style_card_selected.border_color = Color(1.0, 0.90, 0.35, 1.0)
	_style_card_selected.shadow_color = Color(1.0, 0.85, 0.20, 0.50)
	_style_card_selected.shadow_size = 8

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
	visible = false
	closed.emit()
	start_game_requested.emit(selected_game_type)

func _calculate_game_card_height() -> float:
	var total_w := 560.0
	if is_instance_valid(scroll_games) and scroll_games.size.x > 100.0:
		total_w = scroll_games.size.x - 14.0
	elif is_instance_valid(game_grid) and game_grid.size.x > 100.0:
		total_w = game_grid.size.x
	var cell_w := floor((total_w - 12.0) / 2.0)
	return maxf(160.0, cell_w)

func _populate_games_grid() -> void:
	game_grid.columns = 2
	for child in game_grid.get_children():
		child.queue_free()
	_game_cards.clear()
	
	var initial_h := _calculate_game_card_height()
	for g_type in AVAILABLE_GAMES:
		var card = _create_game_card(g_type, initial_h)
		game_grid.add_child(card)
		_game_cards[g_type] = card

func _create_game_card(g_type: String, initial_h: float = 260.0) -> Control:
	var is_selected = (g_type == selected_game_type)
	
	# Native Button control ensures robust child clipping and anchor support
	# 2 games per row with 1:1 square aspect ratio (height = width)
	var card = Button.new()
	card.custom_minimum_size = Vector2(0, initial_h)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.pivot_offset = Vector2(initial_h / 2.0, initial_h / 2.0)
	
	card.item_rect_changed.connect(func():
		var w = card.size.x
		if w > 80.0:
			var target_h = floor(w)
			if absf(card.custom_minimum_size.y - target_h) > 2.0:
				card.set_deferred("custom_minimum_size", Vector2(0, target_h))
				card.pivot_offset = Vector2(w / 2.0, target_h / 2.0)
	)
	
	var st = _style_card_selected if is_selected else _style_card_normal
	card.add_theme_stylebox_override("normal", st)
	card.add_theme_stylebox_override("hover", _style_card_hover)
	card.add_theme_stylebox_override("pressed", st)
	card.add_theme_stylebox_override("focus", st)
	
	# 1. Cover artwork (clean, no dark backdrop or shadow overlay)
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.12, 1.08, 1.02)
	img.texture = _get_game_texture(g_type)
	card.add_child(img)
	
	# Golden Selection Checkmark Badge
	var sel_badge := PanelContainer.new()
	sel_badge.name = "SelectionBadge"
	sel_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sel_badge.offset_left = -40.0
	sel_badge.offset_top = 8.0
	sel_badge.offset_right = -10.0
	sel_badge.offset_bottom = 38.0
	sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.pivot_offset = Vector2(15.0, 15.0)
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.98, 0.82, 0.25, 0.98)
	badge_sb.border_color = Color(0.18, 0.12, 0.04, 0.95)
	badge_sb.set_border_width_all(2)
	badge_sb.set_corner_radius_all(15)
	badge_sb.shadow_color = Color(0, 0, 0, 0.40)
	badge_sb.shadow_size = 3
	sel_badge.add_theme_stylebox_override("panel", badge_sb)
	sel_badge.visible = is_selected

	var badge_lbl := Label.new()
	badge_lbl.text = "✓"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	badge_lbl.add_theme_font_size_override("font_size", 20)
	badge_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02, 1.0))
	sel_badge.add_child(badge_lbl)
	card.add_child(sel_badge)
	
	# 4. Bottom title ribbon banner based on game difficulty
	var banner = PanelContainer.new()
	banner.anchor_top = 0.74
	banner.anchor_right = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_left = 4.0
	banner.offset_right = -4.0
	banner.offset_bottom = -4.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", GameRegistry.create_game_name_frame_style(g_type, 40.0, 4.0))
	
	var lbl = Label.new()
	lbl.text = GameTypes.get_display_name_fa(g_type)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(lbl)
	card.add_child(banner)
	
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
		var badge = c.get_node_or_null("SelectionBadge") as Control
		if is_instance_valid(badge):
			if is_sel and not badge.visible:
				badge.visible = true
				badge.scale = Vector2(0.5, 0.5)
				var tw = badge.create_tween()
				tw.tween_property(badge, "scale", Vector2(1.2, 1.2), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(badge, "scale", Vector2.ONE, 0.08)
			elif not is_sel:
				badge.visible = false
		if is_sel:
			var tw_c = c.create_tween()
			tw_c.tween_property(c, "scale", Vector2(1.03, 1.03), 0.08)
			tw_c.tween_property(c, "scale", Vector2.ONE, 0.10)

func _update_selected_preview() -> void:
	if not is_instance_valid(preview_icon):
		return
	var cover_path = "res://assets/images/games/%s.png" % selected_game_type.to_lower()
	if not ResourceLoader.exists(cover_path):
		cover_path = "res://assets/images/games/%s.jpg" % selected_game_type.to_lower()
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
