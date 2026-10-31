extends PanelContainer

# Classic Rank Game Mode Dialog
# Allows players to choose any game to play against human-like AI (Level 2).
# Wins/Draws/Losses yield EXP based on game difficulty without affecting rank cups/score.

signal closed()
signal match_ready(game_id: String, game_type: String)

@onready var btn_close: TextureButton = $Margin/VBox/TopRow/BtnClose
@onready var lbl_title: Label = $Margin/VBox/TopRow/LblTitle
@onready var banner_panel: PanelContainer = $Margin/VBox/BannerPanel
@onready var game_grid: GridContainer = $Margin/VBox/ScrollGames/GameGrid
@onready var bottom_panel: PanelContainer = $Margin/VBox/BottomPanel
@onready var lbl_selected_name: Label = $Margin/VBox/BottomPanel/Margin/HBox/InfoVBox/LblGameName
@onready var lbl_selected_details: Label = $Margin/VBox/BottomPanel/Margin/HBox/InfoVBox/LblGameDetails
@onready var btn_start: Button = $Margin/VBox/BottomPanel/Margin/HBox/BtnStart
@onready var status_box: HBoxContainer = $Margin/VBox/BottomPanel/Margin/HBox/StatusBox
@onready var spinner: TextureRect = $Margin/VBox/BottomPanel/Margin/HBox/StatusBox/Spinner
@onready var lbl_status: Label = $Margin/VBox/BottomPanel/Margin/HBox/StatusBox/LblStatus

var selected_game_type: String = GameTypes.TIC_TAC_TOE
var is_starting_match: bool = false
var _game_cards: Dictionary = {} # game_type -> Button

const CLASSIC_GAMES = [
	GameTypes.TIC_TAC_TOE,
	GameTypes.PENTAGO,
	GameTypes.LUDO,
	GameTypes.FOURINROW,
	GameTypes.DOTBOX,
	GameTypes.YATZY,
	GameTypes.FEKRBEKR,
	GameTypes.RPC,
	GameTypes.BOXFOUR,
	GameTypes.MNUMBERS,
	GameTypes.MSWEEPER,
	GameTypes.BATTLESHIP,
	GameTypes.SUDOKU,
	GameTypes.CHECKERS,
	GameTypes.CHESS,
	GameTypes.OTHELLO,
	GameTypes.BACKGAMMON,
	GameTypes.MILL,
	GameTypes.YINSH
]

func _ready() -> void:
	visible = false
	KenneyUI.style_button(btn_start, KenneyUI.COLOR_GREEN)
	ActionVFXManager.apply_button_juice(btn_start, "tap_button")
	
	btn_close.pressed.connect(func():
		AudioManager.sfx_button()
		close()
	)
	
	btn_start.pressed.connect(_on_start_pressed)
	NetworkManager.game_match_found.connect(_on_match_found)
	
	_populate_grid()
	_update_selected_summary()

func _process(delta: float) -> void:
	if visible and is_starting_match and spinner:
		spinner.rotation += delta * 3.5

func open() -> void:
	is_starting_match = false
	if is_instance_valid(status_box):
		status_box.visible = false
	if is_instance_valid(btn_start):
		btn_start.visible = true
		btn_start.disabled = false
	ActionVFXManager.animate_dialog_open(self, null, true)
	_update_selected_summary()

func close() -> void:
	is_starting_match = false
	ActionVFXManager.animate_dialog_close(self, null, func():
		visible = false
		closed.emit()
	)

func _populate_grid() -> void:
	for child in game_grid.get_children():
		child.queue_free()
	_game_cards.clear()
	
	for g_type in CLASSIC_GAMES:
		var card = _create_game_card(g_type)
		game_grid.add_child(card)
		_game_cards[g_type] = card

func _create_game_card(g_type: String) -> Button:
	var is_sel = (g_type == selected_game_type)
	var card = Button.new()
	# 2 columns layout: each card ~430px wide, ~210px high for huge readability
	card.custom_minimum_size = Vector2(430, 210)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.flat = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(215, 105)
	
	_apply_card_style(card, is_sel, g_type)
	
	# Background warmth
	var bg_warmth = ColorRect.new()
	bg_warmth.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_warmth.color = Color(0.24, 0.16, 0.08, 0.95)
	bg_warmth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg_warmth)
	
	# Cover artwork
	var img = TextureRect.new()
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate = Color(1.15, 1.10, 1.05)
	var icon_path = "res://assets/images/games/%s.jpg" % g_type.to_lower()
	if ResourceLoader.exists(icon_path):
		img.texture = load(icon_path)
	card.add_child(img)
	
	# Bottom dark gradient vignette for readable title
	var vignette = Panel.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_style = StyleBoxFlat.new()
	vig_style.bg_color = Color(0.04, 0.03, 0.02, 0.72)
	vig_style.set_corner_radius_all(18)
	vignette.add_theme_stylebox_override("panel", vig_style)
	card.add_child(vignette)
	
	# Content Container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)
	
	# Top row: XP badge and Difficulty badge
	var top_row = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(top_row)
	
	var diff_name = GameRegistry.get_difficulty_name_fa(g_type)
	var diff_color = GameRegistry.get_difficulty_color(g_type)
	var diff_badge = Label.new()
	diff_badge.text = " " + diff_name + " "
	diff_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diff_badge.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	diff_badge.add_theme_font_size_override("font_size", 22)
	diff_badge.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	diff_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	diff_badge.add_theme_constant_override("shadow_outline_size", 3)
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(diff_color.r * 0.45, diff_color.g * 0.45, diff_color.b * 0.45, 0.95)
	b_style.border_color = diff_color
	b_style.set_border_width_all(2)
	b_style.set_corner_radius_all(10)
	b_style.content_margin_left = 10
	b_style.content_margin_right = 10
	b_style.content_margin_top = 4
	b_style.content_margin_bottom = 4
	diff_badge.add_theme_stylebox_override("normal", b_style)
	top_row.add_child(diff_badge)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	
	var diff_key = GameRegistry.get_game_difficulty(g_type)
	var win_xp = 12 if diff_key == "easy" else (25 if diff_key == "hard" else 18)
	var xp_badge = Label.new()
	xp_badge.text = "+%d XP" % win_xp
	xp_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_badge.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	xp_badge.add_theme_font_size_override("font_size", 26)
	xp_badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	xp_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	xp_badge.add_theme_constant_override("shadow_outline_size", 3)
	top_row.add_child(xp_badge)
	
	# Spacer to push title to bottom
	var v_spacer = Control.new()
	v_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(v_spacer)
	
	# Game title at bottom (large, readable font size 34)
	var lbl_name = Label.new()
	lbl_name.text = GameRegistry.get_display_name_fa(g_type)
	lbl_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_name.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	lbl_name.add_theme_font_size_override("font_size", 34)
	lbl_name.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	lbl_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl_name.add_theme_constant_override("shadow_outline_size", 4)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_name)
	
	# Whole button area is cleanly clickable
	card.pressed.connect(func():
		_on_game_selected(g_type)
	)
	
	return card

func _apply_card_style(card: Button, is_selected: bool, _g_type: String) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.20, 0.14, 0.08, 0.95)
	style_normal.set_corner_radius_all(18)
	style_normal.set_border_width_all(4 if is_selected else 2)
	style_normal.border_color = Color(1.0, 0.88, 0.28, 1.0) if is_selected else Color(0.60, 0.48, 0.30, 0.85)
	style_normal.shadow_color = Color(1.0, 0.85, 0.25, 0.5) if is_selected else Color(0, 0, 0, 0.5)
	style_normal.shadow_size = 14 if is_selected else 5
	style_normal.shadow_offset = Vector2(0, 4)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.28, 0.19, 0.12, 0.98)
	style_hover.border_color = Color(1.0, 0.95, 0.55, 1.0)
	
	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_normal)
	card.add_theme_stylebox_override("focus", style_normal)

func _on_game_selected(g_type: String) -> void:
	if is_starting_match:
		return
	AudioManager.sfx_tap()
	selected_game_type = g_type
	
	for g in _game_cards.keys():
		var card = _game_cards[g]
		if is_instance_valid(card):
			_apply_card_style(card, g == selected_game_type, g)
	
	_update_selected_summary()

func _update_selected_summary() -> void:
	var name_fa = GameRegistry.get_display_name_fa(selected_game_type)
	var diff_fa = GameRegistry.get_difficulty_name_fa(selected_game_type)
	var diff_color = GameRegistry.get_difficulty_color(selected_game_type)
	var diff_key = GameRegistry.get_game_difficulty(selected_game_type)
	
	var win_xp = 12 if diff_key == "easy" else (25 if diff_key == "hard" else 18)
	var draw_xp = 6 if diff_key == "easy" else (12 if diff_key == "hard" else 9)
	var lose_xp = 3 if diff_key == "easy" else (6 if diff_key == "hard" else 4)
	
	if is_instance_valid(lbl_selected_name):
		lbl_selected_name.text = name_fa
		lbl_selected_name.add_theme_color_override("font_color", diff_color)
	
	if is_instance_valid(lbl_selected_details):
		lbl_selected_details.text = "درجه سختی: %s  •  پاداش پیروزی: %d+ XP (مساوی: %d+ | باخت: %d+)" % [diff_fa, win_xp, draw_xp, lose_xp]

func _on_start_pressed() -> void:
	if is_starting_match:
		return
	AudioManager.sfx_button()
	is_starting_match = true
	
	if is_instance_valid(btn_start):
		btn_start.visible = false
	if is_instance_valid(status_box):
		status_box.visible = true
	if is_instance_valid(lbl_status):
		lbl_status.text = "در حال آماده‌سازی میز بازی..."
		lbl_status.modulate = Color(1.0, 0.9, 0.4)
	
	GameManager.current_match_mode = "classic_rank"
	GameManager.set_game_type(selected_game_type)
	NetworkManager.start_classic_rank(selected_game_type)

func _on_match_found(game_id: String) -> void:
	if not is_starting_match:
		return
	is_starting_match = false
	AudioManager.sfx_queue_found()
	
	if is_instance_valid(lbl_status):
		lbl_status.text = "میز آماده شد! ورود به بازی..."
		lbl_status.modulate = Color(0.3, 1.0, 0.4)
	
	await get_tree().create_timer(0.5).timeout
	visible = false
	match_ready.emit(game_id, selected_game_type)
