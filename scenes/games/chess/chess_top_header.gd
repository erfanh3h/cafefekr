class_name ChessTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Chess Top Header — Warm Classic Parlor Compact HUD
# Preserves AFK missed-turn strike dot indicators inside compact 2-player cards.

@onready var p1_missed_turns_box: HBoxContainer = get_node_or_null("Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns")
@onready var p1_dot1: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot1")
@onready var p1_dot2: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot2")
@onready var p1_dot3: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot3")
@onready var p1_strike_count_lbl: Label = get_node_or_null("Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1StrikeCount")

@onready var p2_missed_turns_box: HBoxContainer = get_node_or_null("Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns")
@onready var p2_dot1: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot1")
@onready var p2_dot2: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot2")
@onready var p2_dot3: Panel = get_node_or_null("Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot3")
@onready var p2_strike_count_lbl: Label = get_node_or_null("Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2StrikeCount")

@onready var afk_rule_row: HBoxContainer = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/AfkRuleRow")
@onready var lbl_afk_rule: Label = get_node_or_null("Margin/VBoxMain/MatchDetailsBox/VBox/AfkRuleRow/LblAfkRule")

var _dot_style_empty: StyleBoxFlat
var _dot_style_filled: StyleBoxFlat
var _dot_style_danger: StyleBoxFlat
var _max_missed_turns: int = 2


func _ready() -> void:
	super._ready()
	_setup_strike_dot_styles()
	if is_instance_valid(_p1_score_badge):
		_p1_score_badge.visible = false
	if is_instance_valid(_p2_score_badge):
		_p2_score_badge.visible = false
	if is_instance_valid(p1_dot3):
		p1_dot3.visible = false
	if is_instance_valid(p2_dot3):
		p2_dot3.visible = false
	if is_instance_valid(p1_missed_turns_box):
		p1_missed_turns_box.visible = false
	if is_instance_valid(p2_missed_turns_box):
		p2_missed_turns_box.visible = false
	set_penalty_box_visible(true)
	update_not_played_turns(1, 0)
	update_not_played_turns(2, 0)


func _is_score_based_game() -> bool:
	return false


func _setup_strike_dot_styles() -> void:
	_dot_style_empty = StyleBoxFlat.new()
	_dot_style_empty.bg_color = HudTheme.COL_WALNUT_DEEP
	_dot_style_empty.border_color = HudTheme.COL_BRONZE_MUTED
	_dot_style_empty.set_border_width_all(1)
	_dot_style_empty.set_corner_radius_all(5)

	_dot_style_filled = StyleBoxFlat.new()
	_dot_style_filled.bg_color = HudTheme.COL_AMBER_GLOW
	_dot_style_filled.border_color = HudTheme.COL_GOLD_ACTIVE
	_dot_style_filled.set_border_width_all(1)
	_dot_style_filled.set_corner_radius_all(5)

	_dot_style_danger = StyleBoxFlat.new()
	_dot_style_danger.bg_color = HudTheme.COL_DANGER
	_dot_style_danger.border_color = Color(1.0, 0.78, 0.78, 1.0)
	_dot_style_danger.set_border_width_all(1)
	_dot_style_danger.set_corner_radius_all(5)


func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	_max_missed_turns = GameRegistry.get_max_missed_turns(GameManager.current_game_type)
	if _max_missed_turns <= 0:
		_max_missed_turns = 2
	if is_instance_valid(lbl_afk_rule):
		lbl_afk_rule.text = "هر نوبت: %s ثانیه | %s نوبت بدون حرکت = باخت" % [_fa_digits(int(turn_time)), _fa_digits(_max_missed_turns)]
	set_match_meta_text("⏱ %s ثانیه | %s خطا = باخت" % [_fa_digits(int(turn_time)), _fa_digits(_max_missed_turns)])
	set_penalty_box_visible(true)
	update_not_played_turns(1, 0)
	update_not_played_turns(2, 0)


func update_not_played_turns(gamer_id: int, count: int) -> void:
	var clamped_count := clampi(count, 0, _max_missed_turns)
	set_penalty_box_visible(true)
	update_penalty_dots(gamer_id, clamped_count, _max_missed_turns)

	# Opponent pod remains clean with no empty/extra containers on the right
	update_player_counter(gamer_id, "")
	_set_role_badge(gamer_id, "")

	var dots := [p1_dot1, p1_dot2] if gamer_id == 1 else [p2_dot1, p2_dot2]
	var count_lbl: Label = p1_strike_count_lbl if gamer_id == 1 else p2_strike_count_lbl
	var box: HBoxContainer = p1_missed_turns_box if gamer_id == 1 else p2_missed_turns_box

	if not is_instance_valid(count_lbl) or dots.is_empty():
		return

	for i in range(dots.size()):
		var dot = dots[i]
		if not is_instance_valid(dot):
			continue
		if clamped_count > i:
			dot.add_theme_stylebox_override("panel", _dot_style_danger if clamped_count >= _max_missed_turns else _dot_style_filled)
		else:
			dot.add_theme_stylebox_override("panel", _dot_style_empty)

	count_lbl.text = "%s/%s" % [_fa_digits(clamped_count), _fa_digits(_max_missed_turns)]
	if clamped_count >= _max_missed_turns:
		count_lbl.add_theme_color_override("font_color", HudTheme.COL_DANGER)
	elif clamped_count > 0:
		count_lbl.add_theme_color_override("font_color", HudTheme.COL_GOLD_ACTIVE)
	else:
		count_lbl.add_theme_color_override("font_color", HudTheme.COL_TEXT_SAND)

	if count > 0 and is_instance_valid(box):
		box.pivot_offset = box.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "scale", Vector2(1.14, 1.14), 0.14)
		tw.tween_property(box, "scale", Vector2.ONE, 0.14)


func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	super.update_turn(turn, my_idx, p1_n, p2_n)
	if not GameManager.is_game_active:
		hide_turn_toast()
		return
	var is_p1 := (turn == 1)
	var is_me := (turn == my_idx)
	if is_me:
		var color_str := "سفید" if is_p1 else "سیاه"
		show_turn_toast("♟️ نوبت شماست (%s)" % color_str, HudTheme.COL_TEXT_GOLD, false, 1.8)
	else:
		var opp_name := p1_n if is_p1 else p2_n
		show_turn_toast("نوبت %s" % opp_name, HudTheme.COL_TEXT_SAND, false, 1.5)


func reset_header() -> void:
	super.reset_header()
	update_not_played_turns(1, 0)
	update_not_played_turns(2, 0)
