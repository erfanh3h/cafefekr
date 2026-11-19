class_name YatzyTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Yatzy Top Header — Warm Classic Parlor Compact HUD
# Simultaneous dice-rolling rounds across 12 rounds with Persian score badges and integrated card timers.


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	if is_instance_valid(lbl_round):
		lbl_round.text = "راند %s از %s" % [_fa_digits(max(1, round_num)), _fa_digits(max_rounds)]
	_set_role_badge(1, "")
	_set_role_badge(2, "")


func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	super.setup_players(p1_data, p2_data, my_idx)
	_set_role_badge(1, "")
	_set_role_badge(2, "")


func set_waiting_opponent(custom_text: String = "امتیاز شما ثبت شد! منتظر حریف...") -> void:
	show_turn_toast("⏳ " + custom_text, HudTheme.COL_TEXT_SAND, false, 2.4)


func set_round_wait(time_sec: int) -> void:
	_last_displayed_sec = -1
	show_turn_toast("⏳ آماده‌سازی راند بعدی...", HudTheme.COL_TEXT_GOLD, false, 1.8)
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % time_sec)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0


func update_turn(turn: int, my_idx: int, _p1_n: String, _p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_cached_timer_danger = -1
	_update_score_badges_visibility()

	if not GameManager.is_game_active:
		hide_turn_toast()
		return

	if turn > 0 and is_instance_valid(lbl_round):
		lbl_round.text = "راند %s از %s" % [_fa_digits(turn), _fa_digits(GameManager.max_rounds)]

	_set_active_cards_visual([1, 2], false, false)
	var r_str := "راند %s — " % _fa_digits(turn) if turn > 0 else ""
	show_turn_toast("🎲 %sپرتاب تاس و انتخاب خانه" % r_str, HudTheme.COL_TEXT_GOLD, false, 1.9)


func update_timer(remaining_sec: float, total_sec: float, _turn: int) -> void:
	_update_card_timer_visuals(remaining_sec, total_sec, [1, 2])
