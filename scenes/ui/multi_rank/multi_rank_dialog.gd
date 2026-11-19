extends PanelContainer

# Multiplayer Rank (4-Player Ranked) Game Selection Dialog
# Allows the gamer to select a multiplayer-capable game (currently Ludo and Risk Strike)
# and join the 4-player online ranked matchmaking queue (/multi-queue).

signal closed()
signal start_multi_rank_requested(game_type: String)

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

var selected_game_type: String = GameTypes.LUDO
var _game_cards: Dictionary = {} # game_type -> Button card

const AVAILABLE_MULTI_RANK_GAMES: Array[String] = [
	GameTypes.LUDO,
	GameTypes.RISK,
	GameTypes.UNO,
	GameTypes.COUP,
	GameTypes.MONOPOLY,
	GameTypes.QUIZ
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
	_style_card_normal = StyleBoxFlat.new()
	_style_card_normal.bg_color = Color(0, 0, 0, 0)
	_style_card_normal.set_corner_radius_all(18)
	_style_card_normal.set_border_width_all(0)
	_style_card_normal.shadow_size = 0

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
		var norm = GameRegistry.normalize_type(default_game)
		if norm in AVAILABLE_MULTI_RANK_GAMES:
			selected_game_type = norm
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
		start_multi_rank_requested.emit(selected_game_type)
	)

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
	for g_type in AVAILABLE_MULTI_RANK_GAMES:
		var card = _create_game_card(g_type, initial_h)
		game_grid.add_child(card)
		_game_cards[g_type] = card

func _create_game_card(g_type: String, initial_h: float = 260.0) -> Control:
	var is_selected = (g_type == selected_game_type)

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

	var cap_pill = PanelContainer.new()
	cap_pill.position = Vector2(12, 12)
	cap_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style = StyleBoxFlat.new()
	p_style.set_corner_radius_all(10)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 4
	p_style.content_margin_bottom = 4
	var p_color = Color(1.0, 0.88, 0.35)
	p_style.bg_color = Color(0.14, 0.09, 0.05, 0.92)
	p_style.border_color = p_color
	p_style.set_border_width_all(1)
	cap_pill.add_theme_stylebox_override("panel", p_style)

	var d_lbl = Label.new()
	d_lbl.text = "👥 ۴ نفره آنلاین"
	d_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	d_lbl.add_theme_font_size_override("font_size", 24)
	d_lbl.add_theme_color_override("font_color", p_color)
	cap_pill.add_child(d_lbl)
	card.add_child(cap_pill)

	card.pressed.connect(func():
		AudioManager.sfx_tap()
		_select_game(g_type)
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
	preview_icon.texture = _get_game_texture(selected_game_type)
	lbl_preview_name.text = GameTypes.get_display_name_fa(selected_game_type)

	var diff_name = GameRegistry.get_difficulty_name_fa(selected_game_type)
	lbl_preview_diff.text = "ظرفیت: ۴ بازیکن آنلاین | سختی: " + diff_name
	lbl_preview_diff.add_theme_color_override("font_color", Color(0.45, 0.92, 0.58))

	lbl_preview_rewards.text = "پاداش: 🏆 اول ۱۲+ کاپ، ۵۰+ XP، ۲۵+ سکه | 🥈 دوم ۴+ کاپ، ۳۰+ XP، ۱۵+ سکه"
