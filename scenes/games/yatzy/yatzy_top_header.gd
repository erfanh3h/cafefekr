class_name YatzyTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Yatzy Top Header
# Specialized header for Yatzy (پنج تاس):
# - Both players roll dice and pick scorecard categories simultaneously across 12 rounds.
# - Displays cumulative Yatzy points in Persian numerals on both player cards.

func setup_match(_game_name_fa: String, _mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	_last_displayed_sec = -1
	_update_score_badges_visibility()
	if is_instance_valid(lbl_round):
		lbl_round.text = "راند %s از %s" % [_fa_digits(max(1, round_num)), _fa_digits(max_rounds)]
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % int(turn_time))
		lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = Color(0.92, 0.72, 0.22)
	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = "🎲 تاس‌انداز قرمز"
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = "🎲 تاس‌انداز آبی"

func setup_players(p1_data: Dictionary, p2_data: Dictionary, my_idx: int) -> void:
	super.setup_players(p1_data, p2_data, my_idx)
	if is_instance_valid(p1_role_badge):
		p1_role_badge.text = "🎲 تاس‌انداز قرمز"
	if is_instance_valid(p2_role_badge):
		p2_role_badge.text = "🎲 تاس‌انداز آبی"

func set_waiting_opponent(custom_text: String = "امتیاز شما ثبت شد! در انتظار حریف...") -> void:
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "⏳ " + custom_text
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))

func set_round_wait(time_sec: int) -> void:
	_last_displayed_sec = -1
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "⏳ آماده‌سازی راند بعدی..."
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	if is_instance_valid(lbl_timer):
		lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % time_sec)
	if is_instance_valid(turn_timer_bar):
		turn_timer_bar.value = 100.0

func update_turn(turn: int, my_idx: int, _p1_n: String, _p2_n: String) -> void:
	_current_turn = turn
	_my_player_index = my_idx
	_last_critical_sec = -1
	_update_score_badges_visibility()

	if not GameManager.is_game_active:
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		return

	if turn > 0 and is_instance_valid(lbl_round):
		lbl_round.text = "راند %s از %s" % [_fa_digits(turn), _fa_digits(GameManager.max_rounds)]

	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "🎲 نوبت پرتاب تاس و انتخاب خانه"
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.45, 0.96, 0.62))

	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_active)
	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_active)
	if is_instance_valid(_p1_avatar_frame):
		_p1_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p1_active)
	if is_instance_valid(_p2_avatar_frame):
		_p2_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p2_active)
	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(0.92, 0.72, 0.22)
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = Color(0.92, 0.72, 0.22)

func update_timer(remaining_sec: float, total_sec: float, _turn: int) -> void:
	var is_danger = (remaining_sec <= 5.0 and remaining_sec > 0.0)
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = is_danger
		_timer_vfx_overlay.theme_color = Color(0.92, 0.72, 0.22)

	if is_instance_valid(lbl_timer):
		var sec_ceil = int(ceil(remaining_sec))
		if sec_ceil != _last_displayed_sec:
			_last_displayed_sec = sec_ceil
			lbl_timer.text = "%s ثانیه" % _fa_digits("%02d" % sec_ceil)
		if is_danger:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
			lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_danger)
			if sec_ceil != _last_critical_sec:
				_last_critical_sec = sec_ceil
				_animate_timer_warning()
				if is_instance_valid(_timer_vfx_overlay):
					_timer_vfx_overlay.trigger_danger_shockwave()
		else:
			lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
			lbl_timer.add_theme_stylebox_override("normal", _style_timer_pill_normal)

	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_danger if is_danger else _style_match_box_normal)

	if is_instance_valid(turn_timer_bar):
		var pct = clampf((remaining_sec / maxf(1.0, total_sec)) * 100.0, 0.0, 100.0)
		turn_timer_bar.value = pct

	if is_instance_valid(_timer_style_fill):
		if is_danger:
			_timer_style_fill.bg_color = Color(1.0, 0.24, 0.26)
		else:
			_timer_style_fill.bg_color = Color(0.92, 0.72, 0.22)
