class_name FekrBekrTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# FekrBekr Top Header — Warm Classic Parlor Compact HUD
# Simultaneous setup & guessing rounds with integrated bottom-edge card timers and fading turn toasts.

var is_setup_phase: bool = true
var is_guess_submitted: bool = false


func _ready() -> void:
	super._ready()
	if is_instance_valid(_p1_score_badge):
		_p1_score_badge.visible = false
	if is_instance_valid(_p2_score_badge):
		_p2_score_badge.visible = false


func _is_score_based_game() -> bool:
	return false


func _to_fa_num(n: int) -> String:
	return _fa_digits(n)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	is_setup_phase = (round_num == 0)
	is_guess_submitted = false
	if not GameManager.is_game_active:
		if is_instance_valid(lbl_round):
			lbl_round.text = "%s" % game_name_fa
		_highlight_both_players()
		hide_turn_toast()
		return
	if is_setup_phase:
		set_setup_phase()
	else:
		var r_idx := round_num if round_num > 0 else 1
		if is_instance_valid(lbl_round):
			lbl_round.text = "حدس %s از ۱۲" % _to_fa_num(r_idx)
		_highlight_both_players()
		show_turn_toast("🔍 حدس %s از ۱۲ — رمز حریف را بیابید" % _to_fa_num(r_idx), HudTheme.COL_TEXT_GOLD, false, 2.0)


func set_setup_phase() -> void:
	is_setup_phase = true
	is_guess_submitted = false
	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	if is_instance_valid(lbl_round):
		lbl_round.text = "مرحله ۱: تعیین رمز"
	_highlight_both_players()
	show_turn_toast("🔐 ۴ مهره غیرتکراری برای رمز بچینید", HudTheme.COL_TEXT_GOLD, false, 2.4)


func set_waiting_opponent(custom_text: String = "حرکت شما ثبت شد — منتظر حریف...") -> void:
	is_guess_submitted = true
	show_turn_toast("⏳ " + custom_text, HudTheme.COL_TEXT_SAND, false, 2.4)


func set_round_wait(_time_sec: int) -> void:
	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	show_turn_toast("⏳ آماده‌سازی مرحله بعدی...", HudTheme.COL_TEXT_GOLD, false, 1.8)


func update_turn(turn: int, my_idx: int, _p1_n: String, _p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_cached_timer_danger = -1
	is_setup_phase = (turn == 0)
	is_guess_submitted = false
	_update_score_badges_visibility()

	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	if is_setup_phase:
		set_setup_phase()
		return
	if is_instance_valid(lbl_round):
		lbl_round.text = "حدس %s از ۱۲" % _to_fa_num(turn)
	_highlight_both_players()
	show_turn_toast("🔍 حدس %s از ۱۲ — رمز ۴ رنگ را بیابید" % _to_fa_num(turn), HudTheme.COL_TEXT_GOLD, false, 2.0)


func _highlight_both_players() -> void:
	_set_active_cards_visual([1, 2], false, false)


func update_timer(remaining_sec: float, total_sec: float, _turn: int) -> void:
	_update_card_timer_visuals(remaining_sec, total_sec, [1, 2])
