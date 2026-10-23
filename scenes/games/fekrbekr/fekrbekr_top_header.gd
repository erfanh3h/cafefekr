class_name FekrBekrTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# FekrBekr Top Header for Cafe Fekr
# - Phase 1: Setting secret code for the opponent ("چینش رمز برای حریف")
# - Phase 2: Guessing opponent's code ("حدس X از ۱۲")
# - No "مهره قرمز" or "مهره آبی" distinctions (both players use all 8 colors)
# - Golden amber timer bar (#EAB838), changing to danger red (#FF4747) on low time

var is_setup_phase: bool = true
var is_guess_submitted: bool = false

func _ready() -> void:
	super._ready()

func _to_fa_num(n: int) -> String:
	var s = str(n)
	var fa = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var res = ""
	for ch in s:
		if ch >= "0" and ch <= "9":
			res += fa[int(ch)]
		else:
			res += ch
	return res

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	is_setup_phase = (round_num == 0)
	is_guess_submitted = false
	if is_setup_phase:
		set_setup_phase()
	else:
		if is_instance_valid(lbl_round):
			lbl_round.text = "حدس %s از ۱۲" % _to_fa_num(round_num if round_num > 0 else 1)
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "رمز ۴ رقمی حریف را کشف کنید"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		_highlight_both_players()

func set_setup_phase() -> void:
	is_setup_phase = true
	is_guess_submitted = false
	if is_instance_valid(lbl_round):
		lbl_round.text = "چینش رمز برای حریف"
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "۴ مهره با رنگ‌های متفاوت انتخاب کنید"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	_highlight_both_players()

func set_waiting_opponent(custom_text: String = "حرکت شما ثبت شد. در انتظار حریف...") -> void:
	is_guess_submitted = true
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = custom_text
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func set_round_wait(time_sec: int) -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "آماده‌سازی حدس بعدی..."
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))

func update_turn(turn: int, my_idx: int, _p1_n: String, _p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	is_setup_phase = (turn == 0)
	is_guess_submitted = false

	if is_setup_phase:
		set_setup_phase()
		return

	if is_instance_valid(lbl_round):
		lbl_round.text = "حدس %s از ۱۲" % _to_fa_num(turn)

	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "رمز ۴ رقمی حریف را کشف کنید"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))

	_highlight_both_players()

func _highlight_both_players() -> void:
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_active)
		p1_card.scale = Vector2.ONE
	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_active)
		p2_card.scale = Vector2.ONE
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(0.92, 0.72, 0.22)

func update_timer(remaining_sec: float, total_sec: float, _turn: int) -> void:
	if is_instance_valid(lbl_timer):
		var sec_ceil = int(ceil(remaining_sec))
		lbl_timer.text = "%02d ثانیه" % sec_ceil
		if remaining_sec <= 5.0 and remaining_sec > 0.0:
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
		if remaining_sec <= 5.0 and remaining_sec > 0.0:
			_timer_style_fill.bg_color = Color(1.0, 0.28, 0.28)
		else:
			_timer_style_fill.bg_color = Color(0.92, 0.72, 0.22)
