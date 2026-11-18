extends Control

signal exit_match_requested()
signal dismissed()

const GameRegistry = preload("res://scripts/games/game_registry.gd")
const KenneyUI = preload("res://scenes/ui/kenney_ui_helper.gd")

# Nodes
@onready var backdrop: ColorRect = $Backdrop
@onready var p1_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P1Box/P1Avatar
@onready var p1_name_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P1Box/P1Info/P1Name
@onready var p1_role_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P1Box/P1Info/P1Role
@onready var p1_score_badge: PanelContainer = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/P1ScoreBadge
@onready var p1_score_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/P1ScoreBadge/P1Score

@onready var p2_avatar: TextureRect = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P2Box/P2Avatar
@onready var p2_name_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P2Box/P2Info/P2Name
@onready var p2_role_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/PlayersRow/P2Box/P2Info/P2Role
@onready var p2_score_badge: PanelContainer = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/P2ScoreBadge
@onready var p2_score_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/P2ScoreBadge/P2Score

@onready var timer_container: Control = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/TimerBox
@onready var timer_seconds_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/TimerBox/SecondsLabel
@onready var timer_desc_label: Label = $Margin/VBox/HeaderCard/Margin/VBoxHeader/ScoreRow/TimerBox/DescLabel

@onready var status_panel: Control = $Margin/VBox/StatusPanel
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
var _rewards_cards_row: HBoxContainer = null
var _my_current_rating: int = 1000

func _is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func _ready() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)
	KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)
	btn_exit_match.pressed.connect(_on_exit_pressed)
	_setup_rtl_game_rows_and_scroll()


func _setup_rtl_game_rows_and_scroll() -> void:
	# 1. Wrap Margin/VBox in a vertical ScrollContainer so compact screens never clip vertically
	var m_node: Node = get_node_or_null("Margin")
	var vb_node: Node = m_node.get_node_or_null("VBox") if m_node != null else null
	if m_node != null and vb_node is VBoxContainer:
		var scroll := ScrollContainer.new()
		scroll.name = "BodyScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		m_node.remove_child(vb_node)
		m_node.add_child(scroll)
		(vb_node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vb_node)

	# 2. Reorder GameRow1..3 into natural Persian RTL flow: [StatusChip (left)] | [InfoBox (right-aligned)] | [Thumb] | [NumBox (right)]
	for i in range(1, 4):
		var card: Node = games_list_container.get_node_or_null("GameRow%d" % i)
		if card == null:
			continue
		if card is Control:
			(card as Control).custom_minimum_size = Vector2(0, 96)
		var hbox: Node = card.get_node_or_null("Margin/HBox")
		if hbox is HBoxContainer:
			var num_box := hbox.get_node_or_null("NumBox")
			var thumb := hbox.get_node_or_null("GameThumb")
			var info_box := hbox.get_node_or_null("InfoBox")
			var status_chip := hbox.get_node_or_null("StatusChip")
			if thumb is Control:
				(thumb as Control).custom_minimum_size = Vector2(68, 68)
			if num_box is Control:
				(num_box as Control).custom_minimum_size = Vector2(38, 38)
			if status_chip is Control:
				(status_chip as Control).custom_minimum_size = Vector2(124, 42)
			# Reorder LTR positions so Persian reads right-to-left: StatusChip | InfoBox | Thumb | NumBox
			if status_chip:
				hbox.move_child(status_chip, 0)
			if info_box:
				hbox.move_child(info_box, 1)
			if thumb:
				hbox.move_child(thumb, 2)
			if num_box:
				hbox.move_child(num_box, 3)

			var title_lbl: Label = card.get_node_or_null("Margin/HBox/InfoBox/GameTitle")
			if is_instance_valid(title_lbl):
				title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				title_lbl.clip_text = true
				title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				title_lbl.add_theme_font_size_override("font_size", 23)
			var sub_lbl: Label = card.get_node_or_null("Margin/HBox/InfoBox/GameIndexSub")
			if is_instance_valid(sub_lbl):
				sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				sub_lbl.clip_text = true
				sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				sub_lbl.add_theme_font_size_override("font_size", 16)
			var st_lbl: Label = card.get_node_or_null("Margin/HBox/StatusChip/StatusLabel")
			if is_instance_valid(st_lbl):
				st_lbl.clip_text = true
				st_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				st_lbl.add_theme_font_size_override("font_size", 17)

	# 3. Create 3-card rewards container inside FooterFinishedBox/VBox (replaces plain single-line FinishXP)
	var fin_vbox: Node = footer_finished_box.get_node_or_null("VBox")
	if fin_vbox is VBoxContainer and not is_instance_valid(_rewards_cards_row):
		_rewards_cards_row = HBoxContainer.new()
		_rewards_cards_row.name = "RewardsCardsRow"
		_rewards_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_rewards_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rewards_cards_row.add_theme_constant_override("separation", 8)
		_rewards_cards_row.visible = false
		fin_vbox.add_child(_rewards_cards_row)
		fin_vbox.move_child(_rewards_cards_row, finished_xp_label.get_index() + 1)

func _process(delta: float) -> void:
	if not visible or _is_dismissing or not _timer_running:
		if not visible:
			set_process(false)
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
	set_process(true)

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

func update_data(payload: Dictionary) -> void:
	_current_payload = payload
	var is_finished = bool(payload.get("is_game_finished", false))
	if is_finished:
		_timer_running = false

	_setup_players(payload)
	_setup_games(payload)
	_setup_finish_state(payload)

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

func _apply_avatar_frame_safe(avatar_rect: TextureRect, frame_id: int, slot_sz: float = 58.0) -> void:
	if not is_instance_valid(avatar_rect):
		return
	var p := avatar_rect.get_parent()
	var slot: Control = null
	if p is Control and p.name.ends_with("_AvatarSlot"):
		slot = p as Control
	elif p is Container:
		var idx := avatar_rect.get_index()
		slot = Control.new()
		slot.name = avatar_rect.name + "_AvatarSlot"
		slot.custom_minimum_size = Vector2(slot_sz, slot_sz)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(slot)
		p.move_child(slot, idx)
		p.remove_child(avatar_rect)
		slot.add_child(avatar_rect)
		avatar_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		slot = p as Control if p is Control else avatar_rect
	CafeSocialTheme.apply_frame_to_container(slot, avatar_rect, frame_id)


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
	_my_current_rating = p1_rating if is_p1_me_check else p2_rating

	var p1_img = int(p1_data.get("image", p1_data.get("user_image", 0)))
	var p2_img = int(p2_data.get("image", p2_data.get("user_image", 1)))

	p1_name_label.text = p1_name
	p2_name_label.text = p2_name

	p1_avatar.texture = _load_avatar(p1_img)
	p2_avatar.texture = _load_avatar(p2_img)
	var p1_fid = GameManager.get_player_frame_id(p1_data)
	var p2_fid = GameManager.get_player_frame_id(p2_data)
	_apply_avatar_frame_safe(p1_avatar, p1_fid, 58.0)
	_apply_avatar_frame_safe(p2_avatar, p2_fid, 58.0)

	var is_p1_me = (str(p1_data.get("user_id", "")) == my_id)
	if is_instance_valid(p1_role_label) and is_instance_valid(p2_role_label):
		if is_p1_me:
			p1_role_label.text = "شما"
			p1_role_label.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
			p2_role_label.text = "حریف"
			p2_role_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))
		else:
			p1_role_label.text = "حریف"
			p1_role_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))
			p2_role_label.text = "شما"
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
			_set_card_highlight(card, false, Color(0.15, 0.10, 0.07, 0.78))

		elif i == current_idx and not is_finished:
			# Active Upcoming Game
			status_label.text = "➔ بازی بعدی"
			_style_chip(status_chip, Color(0.95, 0.62, 0.12, 0.98))
			_set_card_highlight(card, true, Color(0.24, 0.16, 0.08, 0.84))
			_start_card_pulse(card)

		else:
			# Future pending or unneeded game (e.g., 2-0 sweep)
			if is_finished:
				status_label.text = "— نیاز به برگزاری نبود"
				_style_chip(status_chip, Color(0.28, 0.24, 0.22, 0.85))
			else:
				status_label.text = "⏳ در انتظار نوبت"
				_style_chip(status_chip, Color(0.38, 0.32, 0.26, 0.88))
			_set_card_highlight(card, false, Color(0.11, 0.07, 0.05, 0.72))

func _make_reward_card(title_txt: String, val_txt: String, accent: Color, bg_col: Color, sub_txt: String = "") -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	var t_lbl := Label.new()
	t_lbl.text = title_txt
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.clip_text = true
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	t_lbl.add_theme_font_size_override("font_size", 15)
	t_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.72))
	v.add_child(t_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_txt
	v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
	v_lbl.add_theme_font_size_override("font_size", 24)
	v_lbl.add_theme_color_override("font_color", accent)
	v.add_child(v_lbl)

	if not sub_txt.is_empty():
		var s_lbl := Label.new()
		s_lbl.text = sub_txt
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.add_theme_font_override("font", preload("res://assets/fonts/hekayat.ttf"))
		s_lbl.add_theme_font_size_override("font_size", 14)
		s_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74, 0.90))
		v.add_child(s_lbl)

	return card


func _setup_finish_state(payload: Dictionary) -> void:
	var is_finished = bool(payload.get("is_game_finished", false))
	if is_instance_valid(status_panel):
		status_panel.visible = not is_finished
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

		# Distinct hero framing for Victory vs Defeat vs Draw
		var fin_sb := StyleBoxFlat.new()
		fin_sb.content_margin_left = 18.0
		fin_sb.content_margin_right = 18.0
		fin_sb.content_margin_top = 16.0
		fin_sb.content_margin_bottom = 16.0
		fin_sb.set_border_width_all(3)
		fin_sb.set_corner_radius_all(20)

		if not winner_name.is_empty():
			if is_i_won:
				fin_sb.bg_color = Color(0.08, 0.18, 0.11, 0.94)
				fin_sb.border_color = Color(0.35, 0.95, 0.55, 0.96)
				finished_title_label.text = "👑 پیروزی در مسابقه رنک!"
				finished_title_label.add_theme_color_override("font_color", Color(0.42, 0.98, 0.60))
				finished_winner_label.text = "تبریک! شما فاتح این سری ۳ بازی شدید"
				finished_winner_label.add_theme_color_override("font_color", Color(0.88, 0.98, 0.90))
				KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_GREEN)
			else:
				fin_sb.bg_color = Color(0.18, 0.08, 0.08, 0.94)
				fin_sb.border_color = Color(0.88, 0.36, 0.34, 0.92)
				finished_title_label.text = "⚔️ پایان مسابقه رنک"
				finished_title_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.56))
				finished_winner_label.text = "برنده این سری: %s" % winner_name
				finished_winner_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.78))
				KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)
		else:
			fin_sb.bg_color = Color(0.16, 0.12, 0.06, 0.94)
			fin_sb.border_color = Color(0.92, 0.76, 0.30, 0.95)
			finished_title_label.text = "🤝 پایان مسابقه رنک (مساوی)"
			finished_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
			finished_winner_label.text = "مسابقه با نتیجه مساوی به پایان رسید!"
			finished_winner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
			KenneyUI.style_button(btn_exit_match, KenneyUI.COLOR_BLUE)
		if footer_finished_box is PanelContainer:
			(footer_finished_box as PanelContainer).add_theme_stylebox_override("panel", fin_sb)

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

		# Build 3 distinct color-coded reward cards instead of one monochrome text line!
		finished_xp_label.visible = false
		if is_instance_valid(_rewards_cards_row):
			for ch in _rewards_cards_row.get_children():
				ch.queue_free()
			var any_card := false
			if has_score_delta:
				var score_delta_i: int = int(my_score_delta)
				var is_pos: bool = score_delta_i >= 0
				var sign_str: String = "+" if is_pos else "-"
				var delta_str: String = "\u200E%s%s\u200E" % [sign_str, _fa_num(abs(score_delta_i))]
				var new_rating: int = maxi(0, GameManager.get_score())
				var old_rating: int = maxi(0, new_rating - score_delta_i) if new_rating > 0 else _my_current_rating
				var prog_str: String = "%s → %s" % [_fa_num(old_rating), _fa_num(new_rating)] if new_rating > 0 else ""
				_rewards_cards_row.add_child(_make_reward_card(
					"تغییر امتیاز رنک",
					delta_str,
					Color(0.42, 0.98, 0.60) if is_pos else Color(1.0, 0.45, 0.45),
					Color(0.08, 0.22, 0.13, 0.94) if is_pos else Color(0.24, 0.08, 0.08, 0.94),
					prog_str
				))
				any_card = true
			if my_xp > 0:
				_rewards_cards_row.add_child(_make_reward_card(
					"⭐ تجربه (XP)",
					"\u200E+%s\u200E" % _fa_num(my_xp),
					Color(0.48, 0.86, 1.0),
					Color(0.08, 0.16, 0.24, 0.94)
				))
				any_card = true
			if my_coin_delta > 0:
				_rewards_cards_row.add_child(_make_reward_card(
					"🪙 سکه جایزه",
					"\u200E+%s\u200E" % _fa_num(my_coin_delta),
					Color(1.0, 0.86, 0.34),
					Color(0.22, 0.16, 0.06, 0.94)
				))
				any_card = true
			_rewards_cards_row.visible = any_card

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
	var path_png = "res://assets/images/games/%s.png" % clean
	if ResourceLoader.exists(path_png):
		return load(path_png)
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
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	chip.add_theme_stylebox_override("panel", sb)

func _set_card_highlight(card: PanelContainer, is_highlight: bool, bg_color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(16)
	if is_highlight:
		sb.set_border_width_all(3)
		sb.border_color = Color(1.0, 0.78, 0.25, 0.98)
		if not _is_mobile():
			sb.shadow_color = Color(1.0, 0.65, 0.15, 0.40)
			sb.shadow_size = 10
	else:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.45, 0.35, 0.22, 0.7)
	card.add_theme_stylebox_override("panel", sb)

func _start_card_pulse(card: PanelContainer) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _is_mobile():
		card.scale = Vector2.ONE
		return
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
