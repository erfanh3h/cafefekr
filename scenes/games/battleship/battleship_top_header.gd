class_name BattleShipTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# BattleShip Top Header for Cafe Fekr
# - Pre-Game: Shows "بازی درحال آغاز است" until Start_Game arrives
# - Phase 1 (Setup): Placing 4 warships on the 8x8 fleet grid (60s golden timer)
# - Phase 2 (Combat): Alternating 12s turns (bonus turn on hit!), score badges 0..14

var is_setup_phase: bool = true
var is_board_submitted: bool = false

func _ready() -> void:
	super._ready()
	_update_score_badges_visibility()

func _is_score_based_game() -> bool:
	return true

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
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_highlight_both_players()
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
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		return
	if is_instance_valid(lbl_round):
		lbl_round.text = "مرحله ۱: آرایش ناوگان"
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "⚓ ۴ کشتی جنگی خود را در میدان مستقر کنید"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	_highlight_both_players()

func set_waiting_opponent(custom_text: String = "ناوگان شما ثبت شد. در انتظار حریف...") -> void:
	is_board_submitted = true
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = custom_text
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))

func set_round_wait(_time_sec: int) -> void:
	if not GameManager.is_game_active:
		if is_instance_valid(lbl_turn_banner):
			lbl_turn_banner.text = "بازی درحال آغاز است"
			lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		return
	if is_instance_valid(lbl_turn_banner):
		lbl_turn_banner.text = "⏳ آماده‌سازی میدان نبرد..."
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))

func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	if turn == 0:
		_current_turn = 0
		_my_player_index = my_idx
		_last_critical_sec = -1
		is_setup_phase = true
		_update_score_badges_visibility()
		set_setup_phase()
		return
	is_setup_phase = false
	is_board_submitted = false
	super.update_turn(turn, my_idx, p1_n, p2_n)
	if is_instance_valid(lbl_round):
		lbl_round.text = "مرحله ۲: نبرد دریایی"
	if GameManager.is_game_active and is_instance_valid(lbl_turn_banner):
		if turn == my_idx:
			lbl_turn_banner.text = "🎯 نوبت شلیک شماست! به میدان حریف شلیک کنید"
		else:
			lbl_turn_banner.text = "🛡️ نوبت شلیک حریف..."

func _highlight_both_players() -> void:
	if is_instance_valid(p1_card):
		p1_card.add_theme_stylebox_override("panel", _style_p1_active)
		p1_card.scale = Vector2.ONE
	if is_instance_valid(_p1_avatar_frame):
		_p1_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p1_active)
	if is_instance_valid(p2_card):
		p2_card.add_theme_stylebox_override("panel", _style_p2_active)
		p2_card.scale = Vector2.ONE
	if is_instance_valid(_p2_avatar_frame):
		_p2_avatar_frame.add_theme_stylebox_override("panel", _style_avatar_p2_active)
	if is_instance_valid(match_details_box):
		match_details_box.add_theme_stylebox_override("panel", _style_match_box_normal)
	if is_instance_valid(_timer_style_fill):
		_timer_style_fill.bg_color = Color(0.92, 0.72, 0.22)
	if is_instance_valid(_timer_vfx_overlay):
		_timer_vfx_overlay.is_danger = false
		_timer_vfx_overlay.theme_color = Color(0.92, 0.72, 0.22)

func update_timer(remaining_sec: float, total_sec: float, turn: int) -> void:
	if not is_setup_phase and turn in [1, 2]:
		super.update_timer(remaining_sec, total_sec, turn)
		return
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
