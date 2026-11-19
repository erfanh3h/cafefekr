class_name BattleShipTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# BattleShip Top Header — Warm Classic Parlor Compact HUD
# Phase 1 (Setup): Both players place 4 warships simultaneously.
# Phase 2 (Combat): Alternating turns with integrated bottom-edge card timers.

var is_setup_phase: bool = true
var is_board_submitted: bool = false


func _ready() -> void:
	super._ready()
	_update_score_badges_visibility()


func _is_score_based_game() -> bool:
	return true


func _is_simultaneous_turn() -> bool:
	return is_setup_phase


func _get_simultaneous_turn_text() -> String:
	return "چیدن کشتی‌ها"


func _to_fa_num(n: int) -> String:
	return _fa_digits(n)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	is_setup_phase = (round_num == 0)
	is_board_submitted = false
	_update_score_badges_visibility()
	if not GameManager.is_game_active:
		if is_instance_valid(lbl_round):
			lbl_round.text = "%s" % game_name_fa
		_highlight_both_players()
		hide_turn_toast()
		return
	if is_setup_phase:
		set_setup_phase()
	else:
		if is_instance_valid(lbl_round):
			lbl_round.text = "مرحله ۲: نبرد دریایی"


func set_setup_phase() -> void:
	is_setup_phase = true
	is_board_submitted = false
	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	if is_instance_valid(lbl_round):
		lbl_round.text = "مرحله ۱: آرایش ناوگان"
	set_match_meta_text("⚓ مرحله ۱: آرایش ناوگان (۴ ناو)")
	_highlight_both_players()
	show_turn_toast("⚓ ۴ کشتی جنگی خود را مستقر کنید", HudTheme.COL_TEXT_GOLD, false, 2.4)


func set_waiting_opponent(custom_text: String = "ناوگان شما ثبت شد — منتظر حریف...") -> void:
	is_board_submitted = true
	set_match_meta_text("⏳ ناوگان ثبت شد — منتظر حریف...")
	show_turn_toast("⏳ " + custom_text, HudTheme.COL_TEXT_SAND, false, 2.4)


func set_round_wait(_time_sec: int) -> void:
	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	show_turn_toast("⏳ آماده‌سازی میدان نبرد...", HudTheme.COL_TEXT_GOLD, false, 1.8)


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	if turn == 0:
		super.update_turn(turn, my_idx, p1_n, p2_n)
		is_setup_phase = true
		_update_score_badges_visibility()
		set_setup_phase()
		return
	is_setup_phase = false
	is_board_submitted = false
	super.update_turn(turn, my_idx, p1_n, p2_n)
	if is_instance_valid(lbl_round):
		lbl_round.text = "مرحله ۲: نبرد دریایی"
	set_match_meta_text("⚓ مرحله ۲: نبرد دریایی")
	if GameManager.is_game_active:
		if turn == my_idx:
			show_turn_toast("🎯 نوبت شلیک شماست!", HudTheme.COL_TEXT_GOLD, false, 1.8)
		else:
			show_turn_toast("🛡️ نوبت شلیک حریف...", HudTheme.COL_TEXT_SAND, false, 1.5)


func _highlight_both_players() -> void:
	_set_active_cards_visual([1, 2], false, false)


func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	super.update_timer(remaining_sec, total_sec, turn)
