extends Control

signal exit_match_requested()
signal dismissed()

# Nodes
@onready var backdrop: ColorRect = $Backdrop
@onready var p1_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/HBox/P1Box/P1Avatar
@onready var p1_name_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P1Box/P1Info/P1Name
@onready var p1_score_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P1ScoreBadge/P1Score
@onready var p2_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/HBox/P2Box/P2Avatar
@onready var p2_name_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P2Box/P2Info/P2Name
@onready var p2_score_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P2ScoreBadge/P2Score

@onready var timer_container: Control = $Margin/VBox/HeaderCard/Margin/HBox/TimerBox
@onready var timer_seconds_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/TimerBox/SecondsLabel
@onready var timer_desc_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/TimerBox/DescLabel

@onready var mode_badge_title: Label = $Margin/VBox/StatusPanel/Margin/VBox/ModeTitle
@onready var mode_badge_sub: Label = $Margin/VBox/StatusPanel/Margin/VBox/StatusSubtitle

@onready var games_list_container: VBoxContainer = $Margin/VBox/GamesPanel/Margin/GamesVBox

@onready var footer_waiting_box: Control = $Margin/VBox/FooterWaitingBox
@onready var footer_waiting_label: Label = $Margin/VBox/FooterWaitingBox/VBox/WaitingLabel
@onready var footer_progress_bar: ProgressBar = $Margin/VBox/FooterWaitingBox/VBox/ProgressBar

@onready var footer_finished_box: Control = $Margin/VBox/FooterFinishedBox
@onready var finished_title_label: Label = $Margin/VBox/FooterFinishedBox/VBox/FinishTitle
@onready var finished_winner_label: Label = $Margin/VBox/FooterFinishedBox/VBox/FinishWinner
@onready var finished_score_label: Label = $Margin/VBox/FooterFinishedBox/VBox/FinishScore
@onready var finished_xp_label: Label = $Margin/VBox/FooterFinishedBox/VBox/FinishXP
@onready var btn_exit_match: Button = $Margin/VBox/FooterFinishedBox/VBox/BtnExitMatch

var _current_payload: Dictionary = {}
var _remaining_seconds: int = 20
var _timer_tween: Tween = null
var _pulse_tween: Tween = null
var _is_dismissing: bool = false

func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)
	btn_exit_match.pressed.connect(_on_exit_pressed)

func is_open() -> bool:
	return visible and not _is_dismissing

func open(payload: Dictionary) -> void:
	_current_payload = payload
	_is_dismissing = false
	visible = true

	_setup_players(payload)
	_setup_games(payload)
	_setup_finish_state(payload)

	# Animate smooth appearance
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	modulate = Color(1, 1, 1, 0)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Sound cue
	var is_finished = bool(payload.get("is_game_finished", false))
	if is_finished:
		AudioManager.play_sound("win")
	else:
		AudioManager.play_sound("bell")

func dismiss() -> void:
	if not visible or _is_dismissing:
		return
	_is_dismissing = true
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		visible = false
		_is_dismissing = false
		dismissed.emit()
	)

func update_timer(time_val: int) -> void:
	_remaining_seconds = max(0, time_val)
	timer_seconds_label.text = _fa_num(_remaining_seconds)
	footer_progress_bar.value = _remaining_seconds

	if _remaining_seconds <= 3 and _remaining_seconds > 0:
		timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		AudioManager.play_sound("time")
	else:
		timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	footer_waiting_label.text = "آماده‌سازی زمین بازی... شروع بازی در %s ثانیه" % _fa_num(_remaining_seconds)

func _setup_players(payload: Dictionary) -> void:
	var gamers = payload.get("gamers", GameManager.match_players) as Array
	var p1_data: Dictionary = {}
	var p2_data: Dictionary = {}
	var my_id = GameManager.get_user_id()

	if gamers.size() >= 2:
		p1_data = gamers[0] if typeof(gamers[0]) == TYPE_DICTIONARY else {}
		p2_data = gamers[1] if typeof(gamers[1]) == TYPE_DICTIONARY else {}
	else:
		p1_data = GameManager.get_my_player_data()
		p2_data = GameManager.get_opponent_player_data()

	var p1_name = str(p1_data.get("username", p1_data.get("name", "بازیکن ۱")))
	var p2_name = str(p2_data.get("username", p2_data.get("name", "بازیکن ۲")))

	var p1_img = int(p1_data.get("image", p1_data.get("user_image", 0)))
	var p2_img = int(p2_data.get("image", p2_data.get("user_image", 1)))

	p1_name_label.text = p1_name
	p2_name_label.text = p2_name

	p1_avatar.texture = _load_avatar(p1_img)
	p2_avatar.texture = _load_avatar(p2_img)

	var scores = payload.get("scores", [0, 0]) as Array
	var p1_score = int(scores[0]) if scores.size() > 0 else 0
	var p2_score = int(scores[1]) if scores.size() > 1 else 0

	p1_score_label.text = _fa_num(p1_score)
	p2_score_label.text = _fa_num(p2_score)

	var my_idx = GameManager.my_player_index
	if my_idx == 1:
		mode_badge_sub.text = "نتیجه سری: %s - %s  (بهترین از ۳)" % [_fa_num(p1_score), _fa_num(p2_score)]
	else:
		mode_badge_sub.text = "نتیجه سری: %s - %s  (بهترین از ۳)" % [_fa_num(p2_score), _fa_num(p1_score)]

func _setup_games(payload: Dictionary) -> void:
	var games = payload.get("games", []) as Array
	var winners = payload.get("winners", [-1, -1, -1]) as Array
	var current_idx = int(payload.get("current_game_index", 0))
	var is_finished = bool(payload.get("is_game_finished", false))

	var gamers = payload.get("gamers", GameManager.match_players) as Array
	var p1_name = "بازیکن ۱"
	var p2_name = "بازیکن ۲"
	if gamers.size() >= 2:
		p1_name = str((gamers[0] as Dictionary).get("username", (gamers[0] as Dictionary).get("name", "بازیکن ۱")))
		p2_name = str((gamers[1] as Dictionary).get("username", (gamers[1] as Dictionary).get("name", "بازیکن ۲")))

	for i in range(3):
		var card = games_list_container.get_node_or_null("GameRow%d" % (i + 1))
		if not card:
			continue

		var game_type = str(games[i]) if i < games.size() else "TicTacToe"
		var norm = GameRegistry.normalize_type(game_type)
		var fa_name = GameTypes.get_display_name_fa(norm)

		var title_label: Label = card.get_node("Margin/HBox/InfoBox/GameTitle")
		var num_label: Label = card.get_node("Margin/HBox/NumBox/NumLabel")
		var icon_rect: TextureRect = card.get_node("Margin/HBox/GameThumb")
		var status_chip: PanelContainer = card.get_node("Margin/HBox/StatusChip")
		var status_label: Label = card.get_node("Margin/HBox/StatusChip/StatusLabel")

		num_label.text = _fa_num(i + 1)
		title_label.text = fa_name
		icon_rect.texture = _load_game_thumb(norm)

		# Evaluate card status: Finished, Active/Upcoming, or Pending
		if i < current_idx:
			# Finished Game
			var win_id = int(winners[i]) if i < winners.size() else 0
			var winner_str = ""
			var chip_color = Color(0.2, 0.7, 0.3, 0.95)
			if win_id == 1:
				winner_str = "✓ برنده: %s" % p1_name
				chip_color = Color(0.2, 0.65, 0.9, 0.95)
			elif win_id == 2:
				winner_str = "✓ برنده: %s" % p2_name
				chip_color = Color(0.9, 0.35, 0.35, 0.95)
			else:
				winner_str = "🤝 مساوی"
				chip_color = Color(0.8, 0.7, 0.2, 0.95)

			status_label.text = winner_str
			_style_chip(status_chip, chip_color)
			_set_card_highlight(card, false, Color(0.18, 0.12, 0.08, 0.95))

		elif i == current_idx and not is_finished:
			# Active Upcoming Game
			status_label.text = "➔ بازی بعدی"
			_style_chip(status_chip, Color(1.0, 0.65, 0.1, 0.95))
			_set_card_highlight(card, true, Color(0.26, 0.18, 0.10, 0.98))
			_start_card_pulse(card)

		else:
			# Future pending or unneeded game
			if is_finished:
				status_label.text = "پایان مسابقه"
				_style_chip(status_chip, Color(0.35, 0.35, 0.35, 0.8))
			else:
				status_label.text = "⏳ در انتظار"
				_style_chip(status_chip, Color(0.4, 0.35, 0.3, 0.8))
			_set_card_highlight(card, false, Color(0.12, 0.08, 0.06, 0.85))

func _setup_finish_state(payload: Dictionary) -> void:
	var is_finished = bool(payload.get("is_game_finished", false))
	if is_finished:
		footer_waiting_box.visible = false
		footer_finished_box.visible = true
		timer_container.visible = false

		var winner_id = payload.get("game_winner_id", null)
		var gamers = payload.get("gamers", GameManager.match_players) as Array
		var my_id = GameManager.get_user_id()
		var winner_name = ""
		var is_i_won = false

		if winner_id != null and str(winner_id) != "0":
			for g in gamers:
				if typeof(g) == TYPE_DICTIONARY and str(g.get("user_id", "")) == str(winner_id):
					winner_name = str(g.get("username", g.get("name", "برنده")))
					break
			if str(winner_id) == str(my_id):
				is_i_won = true

		if not winner_name.is_empty():
			if is_i_won:
				finished_winner_label.text = "🎉 تبریک! شما برنده کل مسابقه شدید! (%s)" % winner_name
				finished_winner_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
			else:
				finished_winner_label.text = "🏆 برنده کل مسابقه: %s" % winner_name
				finished_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			finished_winner_label.text = "🤝 مسابقه با نتیجه مساوی به اتمام رسید!"
			finished_winner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))

		var scores = payload.get("scores", [0, 0]) as Array
		var p1_s = int(scores[0]) if scores.size() > 0 else 0
		var p2_s = int(scores[1]) if scores.size() > 1 else 0
		finished_score_label.text = "نتیجه نهایی سری: %s - %s" % [_fa_num(p1_s), _fa_num(p2_s)]

		var xp_map = payload.get("xp_awarded", {})
		var my_xp = 0
		if typeof(xp_map) == TYPE_DICTIONARY and xp_map.has(str(my_id)):
			my_xp = int(xp_map[str(my_id)])
		elif payload.has("xp_earned"):
			my_xp = int(payload["xp_earned"])

		if my_xp > 0:
			finished_xp_label.visible = true
			finished_xp_label.text = "⭐ امتیاز تجربه کسب‌شده: +%s XP" % _fa_num(my_xp)
		else:
			finished_xp_label.visible = false

	else:
		footer_waiting_box.visible = true
		footer_finished_box.visible = false
		timer_container.visible = true
		footer_progress_bar.max_value = 20
		footer_progress_bar.value = _remaining_seconds
		timer_seconds_label.text = _fa_num(_remaining_seconds)

func _on_exit_pressed() -> void:
	AudioManager.play_sound("click")
	dismiss()
	exit_match_requested.emit()

func _load_avatar(avatar_id: int) -> Texture2D:
	var path = "res://assets/icons/Avatars/%d.png" % avatar_id
	if ResourceLoader.exists(path):
		return load(path)
	var fallback = "res://assets/icons/Avatars/0.png"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null

func _load_game_thumb(game_type: String) -> Texture2D:
	var clean = game_type.to_lower().strip_edges()
	var path = "res://assets/images/games/%s.jpg" % clean
	if ResourceLoader.exists(path):
		return load(path)
	var fallback = "res://assets/images/games/tictactoe.jpg"
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null

func _style_chip(chip: PanelContainer, col: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	chip.add_theme_stylebox_override("panel", sb)

func _set_card_highlight(card: PanelContainer, is_highlight: bool, bg_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	if is_highlight:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(1.0, 0.75, 0.25, 0.95)
		sb.shadow_color = Color(1.0, 0.6, 0.1, 0.35)
		sb.shadow_size = 8
	else:
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.45, 0.35, 0.22, 0.7)
	card.add_theme_stylebox_override("panel", sb)

func _start_card_pulse(card: PanelContainer) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(card, "scale", Vector2(1.015, 1.015), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)

func _fa_num(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(str(i), fa[i])
	return s
