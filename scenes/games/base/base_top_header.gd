class_name BaseTopHeader
extends Control

# Base Top Header for Cafe Fekr
# Standard in-game top header for all board games.
# Manages Player 1 and Player 2 profile cards, scores, turn highlights,
# active turn banners, and real-time turn countdown timer.
# Extended via inheritance for games requiring custom header widgets (e.g. ChessTopHeader).

signal p1_profile_clicked()
signal p2_profile_clicked()

# --- Player 1 Card Nodes ---
@onready var p1_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P1Card
@onready var p1_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/Avatar
@onready var p1_name: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/Name
@onready var p1_role_badge: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/RoleBadge
@onready var p1_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/ScoreBadge/Score
@onready var p1_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble
@onready var p1_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P1Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p1_profile: Button = $Margin/VBoxMain/PlayersRow/P1Card/HBox/AvatarContainer/BtnP1Profile

# --- Player 2 Card Nodes ---
@onready var p2_card: PanelContainer = $Margin/VBoxMain/PlayersRow/P2Card
@onready var p2_avatar: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/Avatar
@onready var p2_name: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/Name
@onready var p2_role_badge: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/RoleBadge
@onready var p2_score_lbl: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/ScoreBadge/Score
@onready var p2_reaction_bubble: Control = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble
@onready var p2_reaction_icon: TextureRect = $Margin/VBoxMain/PlayersRow/P2Card/ReactionBubble/BubbleFrame/Icon
@onready var btn_p2_profile: Button = $Margin/VBoxMain/PlayersRow/P2Card/HBox/AvatarContainer/BtnP2Profile

# --- Match Details & Turn Timer Nodes ---
@onready var match_details_box: PanelContainer = $Margin/VBoxMain/MatchDetailsBox
@onready var lbl_round: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/RoundPanel/LblRound
@onready var lbl_turn_banner: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnBanner
@onready var lbl_timer: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/TimerRow/LblTimer
@onready var turn_timer_bar: ProgressBar = $Margin/VBoxMain/MatchDetailsBox/VBox/TurnTimerBar

# --- Theme Styles ---
var _style_p1_active: StyleBoxFlat
var _style_p1_inactive: StyleBoxFlat
var _style_p2_active: StyleBoxFlat
var _style_p2_inactive: StyleBoxFlat
var _timer_style_fill: StyleBoxFlat

# --- State ---
var _current_turn: int = 1
var _my_player_index: int = 1
var _last_critical_sec: int = -1

func _ready() -> void:
	_setup_styles()
	_connect_buttons()
	if is_instance_valid(p1_reaction_bubble):
		p1_reaction_bubble.visible = false
	if is_instance_valid(p2_reaction_bubble):
		p2_reaction_bubble.visible = false

func _connect_buttons() -> void:
	if is_instance_valid(btn_p1_profile):
		btn_p1_profile.pressed.connect(func(): p1_profile_clicked.emit())
	if is_instance_valid(btn_p2_profile):
		btn_p2_profile.pressed.connect(func(): p2_profile_clicked.emit())

func _setup_styles() -> void:
	# P1 Active (Crimson glow)
	_style_p1_active = StyleBoxFlat.new()
	_style_p1_active.bg_color = Color(0.24, 0.08, 0.08, 0.94)
	_style_p1_active.border_color = Color(1.0, 0.35, 0.40, 1.0)
	_style_p1_active.set_border_width_all(3)
	_style_p1_active.set_corner_radius_all(18)
	_style_p1_active.shadow_color = Color(1.0, 0.2, 0.25, 0.45)
	_style_p1_active.shadow_size = 14
	_style_p1_active.content_margin_left = 12
	_style_p1_active.content_margin_top = 8
	_style_p1_active.content_margin_right = 12
	_style_p1_active.content_margin_bottom = 8

	# P1 Inactive
	_style_p1_inactive = StyleBoxFlat.new()
	_style_p1_inactive.bg_color = Color(0.14, 0.09, 0.06, 0.88)
	_style_p1_inactive.border_color = Color(0.40, 0.30, 0.18, 0.8)
	_style_p1_inactive.set_border_width_all(3)
	_style_p1_inactive.set_corner_radius_all(18)
	_style_p1_inactive.shadow_color = Color(0, 0, 0, 0.45)
	_style_p1_inactive.shadow_size = 6
	_style_p1_inactive.content_margin_left = 12
	_style_p1_inactive.content_margin_top = 8
	_style_p1_inactive.content_margin_right = 12
	_style_p1_inactive.content_margin_bottom = 8

	# P2 Active (Royal Blue glow)
	_style_p2_active = StyleBoxFlat.new()
	_style_p2_active.bg_color = Color(0.08, 0.14, 0.26, 0.94)
	_style_p2_active.border_color = Color(0.30, 0.70, 1.0, 1.0)
	_style_p2_active.set_border_width_all(3)
	_style_p2_active.set_corner_radius_all(18)
	_style_p2_active.shadow_color = Color(0.2, 0.5, 1.0, 0.45)
	_style_p2_active.shadow_size = 14
	_style_p2_active.content_margin_left = 12
	_style_p2_active.content_margin_top = 8
	_style_p2_active.content_margin_right = 12
	_style_p2_active.content_margin_bottom = 8

	# P2 Inactive
	_style_p2_inactive = _style_p1_inactive.duplicate()

	# Timer Fill
	_timer_style_fill = StyleBoxFlat.new()
	_timer_style_fill.bg_color = Color(0.25, 0.65, 1.0)
	_timer_style_fill.set_corner_radius_all(7)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.add_theme_stylebox_override("fill", _timer_style_fill)

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			lbl_round.text = "%s - %s" % [game_name_fa, mode_title]
		else:
			lbl_round.text = "راند %d از %d" % [round_num, max_rounds]
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است..."
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%02d ثانیه" % int(turn_time)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0

func set_round(round_num: int, max_rounds: int) -> void:
	if is_instance_valid(lbl_round):
		if max_rounds <= 1:
			var g_info = GameRegistry.get_game_info(GameManager.current_game_type)
			var game_name_fa = g_info.get("name_fa", "بازی")
			lbl_round.text = game_name_fa
		else:
			lbl_round.text = "راند %d از %d" % [round_num, max_rounds]

func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	_my_player_index = my_idx
	if is_instance_valid(p1_name):
		p1_name.text = p1_data.get("name", "میزبان")
	if is_instance_valid(p2_name):
		p2_name.text = p2_data.get("name", "مهمان")

	if is_instance_valid(p1_avatar):
		var p1_img_id = int(p1_data.get("image", p1_data.get("user_image", 0)))
		var p1_path = "res://assets/icons/Avatars/%d.png" % p1_img_id
		if ResourceLoader.exists(p1_path):
			p1_avatar.texture = load(p1_path)

	if is_instance_valid(p2_avatar):
		var p2_img_id = int(p2_data.get("image", p2_data.get("user_image", 0)))
		var p2_path = "res://assets/icons/Avatars/%d.png" % p2_img_id
		if ResourceLoader.exists(p2_path):
			p2_avatar.texture = load(p2_path)

	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = "🔴"
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = "🔵"

func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1

	var is_p1 = (turn == 1)
	var is_me = (turn == my_idx)

	# Update Player Cards Active/Inactive Highlights
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_active if is_p1 else _style_p1_inactive)
		if is_p1:
			_animate_card_pulse(p1_card)
		else:
			p1_card.scale = Vector2.ONE

	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_active if not is_p1 else _style_p2_inactive)
		if not is_p1:
			_animate_card_pulse(p2_card)
		else:
			p2_card.scale = Vector2.ONE

	# Timer Fill Color
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(1.0, 0.32, 0.35) if is_p1 else Color(0.25, 0.65, 1.0)

	# Turn Banner Text
	if is_instance_valid(lbl_turn_banner):
		if is_me:
			var color_str = "قرمز" if is_p1 else "آبی"
			var dot = "🔴" if is_p1 else "🔵"
			lbl_turn_banner.text = "%s نوبت شماست (%s)! یک خانه انتخاب کنید" % [dot, color_str]
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		else:
			var opp_name = p1_n if is_p1 else p2_n
			var opp_color = "قرمز" if is_p1 else "آبی"
			lbl_turn_banner.text = "نوبت %s است (%s)..." % [opp_name, opp_color]
			lbl_turn_banner.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	_on_turn_changed(turn)

func _animate_card_pulse(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.18)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.14)

func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	if is_instance_valid(lbl_timer):
		var sec_ceil = int(ceil(remaining_sec))
		lbl_timer.text = "%02d ثانیه" % sec_ceil
		if remaining_sec <= 3.0 and remaining_sec > 0.0:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			if sec_ceil != _last_critical_sec:
				_last_critical_sec = sec_ceil
				_animate_timer_warning()
		else:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))

	if is_instance_valid(turn_timer_bar):
		var pct = clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
		turn_timer_bar.value = pct

	if is_instance_valid(_timer_style_fill):
		if remaining_sec <= 3.0 and remaining_sec > 0.0:
			_timer_style_fill.bg_color = Color(1.0, 0.28, 0.28)
		else:
			_timer_style_fill.bg_color = Color(1.0, 0.32, 0.35) if turn == 1 else Color(0.25, 0.65, 1.0)

func _animate_timer_warning() -> void:
	if not is_instance_valid(lbl_timer):
		return
	lbl_timer.pivot_offset = lbl_timer.size / 2.0
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl_timer, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(lbl_timer, "scale", Vector2(1.0, 1.0), 0.14)

func update_scores(p1_score: int, p2_score: int) -> void:
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = str(p1_score)
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = str(p2_score)

func show_reaction(user_index: int, reaction_id: int) -> void:
	var bubble = p1_reaction_bubble if user_index == 1 else p2_reaction_bubble
	var icon = p1_reaction_icon if user_index == 1 else p2_reaction_icon
	if not is_instance_valid(bubble) or not is_instance_valid(icon):
		return

	var r_path = "res://assets/icons/Reactions/%d.png" % reaction_id
	if ResourceLoader.exists(r_path):
		icon.texture = load(r_path)

	bubble.visible = true
	bubble.scale = Vector2(0.1, 0.1)
	bubble.modulate.a = 0.0
	bubble.pivot_offset = Vector2(60, 60)

	var start_rot = -7.0 if user_index == 1 else 7.0
	bubble.rotation_degrees = start_rot

	AudioManager.play_sound("chat")

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "scale", Vector2(1.18, 1.18), 0.22)
	tw.parallel().tween_property(bubble, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.22)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.1)

	var idle_tw = create_tween().set_loops(3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tw.tween_property(bubble, "scale", Vector2(1.05, 1.05), 0.35)
	idle_tw.parallel().tween_property(bubble, "rotation_degrees", -3.5 if user_index == 1 else 3.5, 0.35)
	idle_tw.tween_property(bubble, "scale", Vector2.ONE, 0.35)
	idle_tw.parallel().tween_property(bubble, "rotation_degrees", 0.0, 0.35)

	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(bubble) and bubble.visible:
		var fade_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tw.tween_property(bubble, "scale", Vector2(1.12, 1.12), 0.1)
		fade_tw.parallel().tween_property(bubble, "modulate:a", 0.0, 0.28)
		await fade_tw.finished
		if is_instance_valid(bubble):
			bubble.visible = false
			bubble.scale = Vector2.ONE
			bubble.rotation_degrees = 0.0

func reset_header() -> void:
	if is_instance_valid(p1_score_lbl):
		p1_score_lbl.text = "0"
	if is_instance_valid(p2_score_lbl):
		p2_score_lbl.text = "0"
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "--"
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_inactive)
		p1_card.scale = Vector2.ONE
	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_inactive)
		p2_card.scale = Vector2.ONE
	if is_instance_valid(p1_reaction_bubble):
		p1_reaction_bubble.visible = false
	if is_instance_valid(p2_reaction_bubble):
		p2_reaction_bubble.visible = false

# Virtual hook for child headers
func _on_turn_changed(_turn: int) -> void:
	pass
