extends Control

signal exit_match_requested()
signal dismissed()

const GameRegistry = preload("res://scripts/games/game_registry.gd")
const KenneyUI = preload("res://scenes/ui/kenney_ui_helper.gd")

# Nodes
@onready var backdrop: ColorRect = $Backdrop
@onready var p1_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/HBox/P1Box/P1Avatar
@onready var p1_name_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P1Box/P1Info/P1Name
@onready var p1_role_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P1Box/P1Info/P1Role
@onready var p1_score_badge: PanelContainer = $Margin/VBox/HeaderCard/Margin/HBox/P1ScoreBadge
@onready var p1_score_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P1ScoreBadge/P1Score

@onready var p2_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/HBox/P2Box/P2Avatar
@onready var p2_name_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P2Box/P2Info/P2Name
@onready var p2_role_label: Label = $Margin/VBox/HeaderCard/Margin/HBox/P2Box/P2Info/P2Role
@onready var p2_score_badge: PanelContainer = $Margin/VBox/HeaderCard/Margin/HBox/P2ScoreBadge
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
var _remaining_seconds: int = 10
var _time_left: float = 10.0
var _max_time: float = 10.0
var _timer_running: bool = false
var _last_tick_sec: int = -1
var _pulse_tween: Tween = null
var _is_dismissing: bool = false

func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)
	KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)
	btn_exit_match.pressed.connect(_on_exit_pressed)

func _process(delta: float) -> void:
	if not visible or _is_dismissing or not _timer_running:
		return
	_time_left = max(0.0, _time_left - delta)
	footer_progress_bar.max_value = _max_time
	footer_progress_bar.value = _time_left
	var sec_int = int(ceil(_time_left))
	if sec_int != _last_tick_sec:
		_last_tick_sec = sec_int
		_remaining_seconds = sec_int
		timer_seconds_label.text = _fa_num(sec_int)
		footer_waiting_label.text = "⚡ آماده‌سازی زمین بازی بعدی... شروع تا %s ثانیه دیگر" % _fa_num(sec_int)
		if sec_int <= 3 and sec_int > 0:
			timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			AudioManager.play_sound("time")
		else:
			timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	if _time_left <= 0.0:
		_timer_running = false

func is_open() -> bool:
	return visible and not _is_dismissing

func open(payload: Dictionary) -> void:
	_current_payload = payload
	_is_dismissing = false
	visible = true

	var is_finished = bool(payload.get("is_game_finished", false))
	if not is_finished:
		_max_time = 10.0
		_time_left = 10.0
		_remaining_seconds = 10
		_last_tick_sec = 10
		_timer_running = true
	else:
		_timer_running = false

	_setup_players(payload)
	_setup_games(payload)
	_setup_finish_state(payload)

	# Animate smooth appearance
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	modulate = Color(1, 1, 1, 0)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Music & Sound cue
	if is_finished:
		AudioManager.play_theme_music()
		var winner_id = payload.get("game_winner_id", null)
		var my_id = str(GameManager.get_user_id())
		if winner_id == null or str(winner_id) == "0" or str(winner_id) == "":
			AudioManager.play_sound("draw")
		elif str(winner_id) == my_id:
			AudioManager.play_sound("win")
		else:
			AudioManager.play_sound("lose")
	else:
		AudioManager.play_queue_music()
		AudioManager.play_sound("bell")

func dismiss() -> void:
	if not visible or _is_dismissing:
		return
	_is_dismissing = true
	_timer_running = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		visible = false
		_is_dismissing = false
		dismissed.emit()
	)

func update_timer(time_val: int, max_time_val: int = 10) -> void:
	_max_time = float(max(1, max_time_val))
	_remaining_seconds = max(0, time_val)
	_time_left = float(_remaining_seconds)
	_last_tick_sec = _remaining_seconds
	_timer_running = (_remaining_seconds > 0)
	footer_progress_bar.max_value = _max_time
	footer_progress_bar.value = _time_left
	timer_seconds_label.text = _fa_num(_remaining_seconds)

	if _remaining_seconds <= 3 and _remaining_seconds > 0:
		timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		AudioManager.play_sound("time")
	else:
		timer_seconds_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	footer_waiting_label.text = "⚡ آماده‌سازی زمین بازی بعدی... شروع تا %s ثانیه دیگر" % _fa_num(_remaining_seconds)

func _setup_players(payload: Dictionary) -> void:
	var gamers = payload.get("gamers", GameManager.match_players) as Array
	var p1_data: Dictionary = {}
	var p2_data: Dictionary = {}
	var my_id = str(GameManager.get_user_id())

	if gamers.size() >= 2:
		p1_data = gamers[0] if typeof(gamers[0]) == TYPE_DICTIONARY else {}
		p2_data = gamers[1] if typeof(gamers[1]) == TYPE_DICTIONARY else {}
	else:
		p1_data = GameManager.get_my_player_data()
		p2_data = GameManager.get_opponent_player_data()

	var p1_name = str(p1_data.get("username", p1_data.get("name", "بازیکن ۱")))
	var p2_name = str(p2_data.get("username", p2_data.get("name", "بازیکن ۲")))
	var is_p1_me_check = (str(p1_data.get("user_id", "")) == my_id)
	var p1_rating = int(p1_data.get("score", p1_data.get("user_score", GameManager.get_score() if is_p1_me_check else 1000)))
	var p2_rating = int(p2_data.get("score", p2_data.get("user_score", GameManager.get_score() if not is_p1_me_check else 1000)))

	var p1_img = int(p1_data.get("image", p1_data.get("user_image", 0)))
	var p2_img = int(p2_data.get("image", p2_data.get("user_image", 1)))

	p1_name_label.text = p1_name
	p2_name_label.text = p2_name

	p1_avatar.texture = _load_avatar(p1_img)
	p2_avatar.texture = _load_avatar(p2_img)

	var is_p1_me = (str(p1_data.get("user_id", "")) == my_id)
	if is_instance_valid(p1_role_label) and is_instance_valid(p2_role_label):
		if is_p1_me:
			p1_role_label.text = "شما • امتیاز: %s" % _fa_num(p1_rating)
			p1_role_label.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
			p2_role_label.text = "حریف • امتیاز: %s" % _fa_num(p2_rating)
			p2_role_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))
		else:
			p1_role_label.text = "حریف • امتیاز: %s" % _fa_num(p1_rating)
			p1_role_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))
			p2_role_label.text = "شما • امتیاز: %s" % _fa_num(p2_rating)
			p2_role_label.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))

	var scores = payload.get("scores", [0, 0]) as Array
	var p1_score = int(scores[0]) if scores.size() > 0 else 0
	var p2_score = int(scores[1]) if scores.size() > 1 else 0

	p1_score_label.text = _fa_num(p1_score)
	p2_score_label.text = _fa_num(p2_score)
	_style_score_badge(p1_score_badge, p1_score > p2_score)
	_style_score_badge(p2_score_badge, p2_score > p1_score)

	var current_idx = int(payload.get("current_game_index", 0))
	var is_finished = bool(payload.get("is_game_finished", false))
	var my_series_score = p1_score if is_p1_me else p2_score
	var opp_series_score = p2_score if is_p1_me else p1_score
	if is_finished:
		mode_badge_sub.text = "نتیجه نهایی سری شما: %s - %s  (بهترین از ۳)" % [_fa_num(my_series_score), _fa_num(opp_series_score)]
	else:
		mode_badge_sub.text = "نتیجه سری شما: %s - %s  •  آماده برای بازی %s از ۳" % [_fa_num(my_series_score), _fa_num(opp_series_score), _fa_num(min(3, current_idx + 1))]

func _style_score_badge(badge: PanelContainer, is_leading: bool) -> void:
	if not is_instance_valid(badge):
		return
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	if is_leading:
		sb.bg_color = Color(0.10, 0.28, 0.14, 0.95)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.35, 0.95, 0.55, 1.0)
	else:
		sb.bg_color = Color(0.08, 0.05, 0.04, 0.9)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.85, 0.70, 0.30, 0.9)
	badge.add_theme_stylebox_override("panel", sb)

func _setup_games(payload: Dictionary) -> void:
	var games = payload.get("games", []) as Array
	var winners = payload.get("winners", [-1, -1, -1]) as Array
	var current_idx = int(payload.get("current_game_index", 0))
	var is_finished = bool(payload.get("is_game_finished", false))
	var my_id = str(GameManager.get_user_id())

	var gamers = payload.get("gamers", GameManager.match_players) as Array
	var p1_name = "بازیکن ۱"
	var p2_name = "بازیکن ۲"
	var is_p1_me = true
	if gamers.size() >= 2:
		var g0 = gamers[0] as Dictionary if typeof(gamers[0]) == TYPE_DICTIONARY else {}
		var g1 = gamers[1] as Dictionary if typeof(gamers[1]) == TYPE_DICTIONARY else {}
		p1_name = str(g0.get("username", g0.get("name", "بازیکن ۱")))
		p2_name = str(g1.get("username", g1.get("name", "بازیکن ۲")))
		is_p1_me = (str(g0.get("user_id", "")) == my_id)

	var ordinal_fa = ["بازی اول", "بازی دوم", "بازی سوم"]
	var picker_fa = [
		"انتخاب شما" if is_p1_me else ("انتخاب %s" % p1_name),
		"انتخاب شما" if not is_p1_me else ("انتخاب %s" % p2_name),
		"قرعه تصادفی سیستم"
	]

	for i in range(3):
		var card = games_list_container.get_node_or_null("GameRow%d" % (i + 1))
		if not card:
			continue

		var game_type = str(games[i]) if i < games.size() else "TicTacToe"
		var norm = GameRegistry.normalize_type(game_type)
		var fa_name = GameTypes.get_display_name_fa(norm)
		var diff_fa = GameRegistry.get_difficulty_name_fa(norm)

		var title_label: Label = card.get_node("Margin/HBox/InfoBox/GameTitle")
		var sub_label: Label = card.get_node_or_null("Margin/HBox/InfoBox/GameIndexSub")
		var num_label: Label = card.get_node("Margin/HBox/NumBox/NumLabel")
		var icon_rect: TextureRect = card.get_node("Margin/HBox/GameThumb")
		var status_chip: PanelContainer = card.get_node("Margin/HBox/StatusChip")
		var status_label: Label = card.get_node("Margin/HBox/StatusChip/StatusLabel")

		num_label.text = _fa_num(i + 1)
		title_label.text = fa_name
		if is_instance_valid(sub_label):
			sub_label.text = "%s • %s • سختی: %s" % [ordinal_fa[i], picker_fa[i], diff_fa]
		icon_rect.texture = _load_game_thumb(norm)
		card.scale = Vector2.ONE

		var win_val = int(winners[i]) if i < winners.size() else -1
		var has_played = (i < current_idx) or (is_finished and win_val != -1)

		# Evaluate card status: Finished, Active/Upcoming, or Unneeded/Pending
		if has_played:
			var winner_str = ""
			var chip_color = Color(0.2, 0.7, 0.3, 0.95)
			if win_val == 1:
				var p1_won_me = is_p1_me
				winner_str = "🏆 برد شما" if p1_won_me else ("✓ برد %s" % p1_name)
				chip_color = Color(0.14, 0.68, 0.36, 0.96) if p1_won_me else Color(0.82, 0.25, 0.25, 0.96)
			elif win_val == 2:
				var p2_won_me = not is_p1_me
				winner_str = "🏆 برد شما" if p2_won_me else ("✓ برد %s" % p2_name)
				chip_color = Color(0.14, 0.68, 0.36, 0.96) if p2_won_me else Color(0.82, 0.25, 0.25, 0.96)
			else:
				winner_str = "🤝 مساوی"
				chip_color = Color(0.75, 0.58, 0.16, 0.96)

			status_label.text = winner_str
			_style_chip(status_chip, chip_color)
			_set_card_highlight(card, false, Color(0.18, 0.12, 0.08, 0.96))

		elif i == current_idx and not is_finished:
			# Active Upcoming Game
			status_label.text = "➔ بازی بعدی"
			_style_chip(status_chip, Color(0.95, 0.62, 0.12, 0.98))
			_set_card_highlight(card, true, Color(0.26, 0.18, 0.10, 0.98))
			_start_card_pulse(card)

		else:
			# Future pending or unneeded game (e.g., 2-0 sweep)
			if is_finished:
				status_label.text = "— نیاز به برگزاری نبود"
				_style_chip(status_chip, Color(0.28, 0.24, 0.22, 0.85))
			else:
				status_label.text = "⏳ در انتظار نوبت"
				_style_chip(status_chip, Color(0.38, 0.32, 0.26, 0.88))
			_set_card_highlight(card, false, Color(0.12, 0.08, 0.06, 0.85))

func _setup_finish_state(payload: Dictionary) -> void:
	var is_finished = bool(payload.get("is_game_finished", false))
	if is_finished:
		footer_waiting_box.visible = false
		footer_finished_box.visible = true
		timer_container.visible = false

		var winner_id = payload.get("game_winner_id", null)
		var gamers = payload.get("gamers", GameManager.match_players) as Array
		var my_id = str(GameManager.get_user_id())
		var winner_name = ""
		var is_i_won = false

		if winner_id != null and str(winner_id) != "0" and str(winner_id) != "":
			for g in gamers:
				if typeof(g) == TYPE_DICTIONARY and str(g.get("user_id", "")) == str(winner_id):
					winner_name = str(g.get("username", g.get("name", "برنده")))
					break
			if str(winner_id) == my_id:
				is_i_won = true

		if not winner_name.is_empty():
			if is_i_won:
				finished_title_label.text = "👑 پیروزی در مسابقه رنک! 👑"
				finished_title_label.add_theme_color_override("font_color", Color(0.35, 0.98, 0.55))
				finished_winner_label.text = "🎉 تبریک! شما برنده نهایی این سری شدید!"
				finished_winner_label.add_theme_color_override("font_color", Color(0.45, 0.98, 0.60))
				KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_GREEN)
			else:
				finished_title_label.text = "🏆 پایان مسابقه رنک"
				finished_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
				finished_winner_label.text = "برنده نهایی مسابقه: %s" % winner_name
				finished_winner_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
				KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)
		else:
			finished_title_label.text = "🤝 پایان مسابقه رنک (مساوی)"
			finished_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
			finished_winner_label.text = "مسابقه با نتیجه مساوی به پایان رسید!"
			finished_winner_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)

		var scores = payload.get("scores", [0, 0]) as Array
		var p1_s = int(scores[0]) if scores.size() > 0 else 0
		var p2_s = int(scores[1]) if scores.size() > 1 else 0
		var is_p1_me = true
		if gamers.size() >= 1 and typeof(gamers[0]) == TYPE_DICTIONARY:
			is_p1_me = (str((gamers[0] as Dictionary).get("user_id", "")) == my_id)
		var my_s = p1_s if is_p1_me else p2_s
		var opp_s = p2_s if is_p1_me else p1_s
		finished_score_label.text = "نتیجه نهایی سری: %s - %s" % [_fa_num(my_s), _fa_num(opp_s)]

		# Extract Rank Score, XP, and Coins awarded
		var xp_map = payload.get("xp_awarded", {})
		var score_map = payload.get("score_awarded", {})
		var coin_map = payload.get("coin_awarded", {})

		var my_xp = 0
		if typeof(xp_map) == TYPE_DICTIONARY and xp_map.has(my_id):
			my_xp = int(xp_map[my_id])
		elif payload.has("xp_earned"):
			my_xp = int(payload["xp_earned"])

		var my_score_delta = 0
		var has_score_delta = false
		if typeof(score_map) == TYPE_DICTIONARY and score_map.has(my_id):
			my_score_delta = int(score_map[my_id])
			has_score_delta = true
		elif payload.has("score_earned"):
			my_score_delta = int(payload["score_earned"])
			has_score_delta = true

		var my_coin_delta = 0
		if typeof(coin_map) == TYPE_DICTIONARY and coin_map.has(my_id):
			my_coin_delta = int(coin_map[my_id])
		elif payload.has("coin_earned"):
			my_coin_delta = int(payload["coin_earned"])

		var reward_parts: Array = []
		if has_score_delta:
			var sign_str = "+" if my_score_delta >= 0 else ""
			reward_parts.append("🏆 امتیاز رنک: %s%s" % [sign_str, _fa_num(my_score_delta)])
		if my_xp > 0:
			reward_parts.append("⭐ تجربه: +%s XP" % _fa_num(my_xp))
		if my_coin_delta > 0:
			reward_parts.append("🪙 سکه: +%s" % _fa_num(my_coin_delta))

		if not reward_parts.is_empty():
			finished_xp_label.visible = true
			finished_xp_label.text = "   |   ".join(reward_parts)
		else:
			finished_xp_label.visible = false

	else:
		footer_waiting_box.visible = true
		footer_finished_box.visible = false
		timer_container.visible = true
		footer_progress_bar.max_value = _max_time
		footer_progress_bar.value = _time_left
		timer_seconds_label.text = _fa_num(_remaining_seconds)
		footer_waiting_label.text = "⚡ آماده‌سازی زمین بازی بعدی... شروع تا %s ثانیه دیگر" % _fa_num(_remaining_seconds)

func _on_exit_pressed() -> void:
	AudioManager.sfx_button()
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
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_corner_radius_all(12)
	chip.add_theme_stylebox_override("panel", sb)

func _set_card_highlight(card: PanelContainer, is_highlight: bool, bg_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(16)
	if is_highlight:
		sb.set_border_width_all(3)
		sb.border_color = Color(1.0, 0.78, 0.25, 0.98)
		sb.shadow_color = Color(1.0, 0.65, 0.15, 0.40)
		sb.shadow_size = 10
	else:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.45, 0.35, 0.22, 0.7)
	card.add_theme_stylebox_override("panel", sb)

func _start_card_pulse(card: PanelContainer) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	card.pivot_offset = card.size * 0.5
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(card, "scale", Vector2(1.015, 1.015), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)

func _fa_num(val: Variant) -> String:
	var s = str(val)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	for i in range(10):
		s = s.replace(str(i), fa[i])
	return s
