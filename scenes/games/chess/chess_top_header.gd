class_name ChessTopHeader
extends "res://scenes/games/base/base_top_header.gd"

# Chess Top Header for Cafe Fekr
# Inherits from BaseTopHeader and extends it with Chess-specific features:
# - Missed turns / AFK strike indicators (3 visual dot meters per player)
# - Strike count warning badge
# - Chess AFK limit rule notification bar (4 missed turns = forfeit)

# --- Chess-Specific AFK & Strike Nodes ---
@onready var p1_missed_turns_box: HBoxContainer = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns
@onready var p1_dot1: Panel = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot1
@onready var p1_dot2: Panel = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot2
@onready var p1_dot3: Panel = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1Dot3
@onready var p1_strike_count_lbl: Label = $Margin/VBoxMain/PlayersRow/P1Card/HBox/InfoBox/P1MissedTurns/P1StrikeCount

@onready var p2_missed_turns_box: HBoxContainer = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns
@onready var p2_dot1: Panel = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot1
@onready var p2_dot2: Panel = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot2
@onready var p2_dot3: Panel = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2Dot3
@onready var p2_strike_count_lbl: Label = $Margin/VBoxMain/PlayersRow/P2Card/HBox/InfoBox/P2MissedTurns/P2StrikeCount

@onready var afk_rule_row: HBoxContainer = $Margin/VBoxMain/MatchDetailsBox/VBox/AfkRuleRow
@onready var lbl_afk_rule: Label = $Margin/VBoxMain/MatchDetailsBox/VBox/AfkRuleRow/LblAfkRule

# --- Dot Styles ---
var _dot_style_empty: StyleBoxFlat
var _dot_style_filled: StyleBoxFlat
var _dot_style_danger: StyleBoxFlat
var _max_missed_turns: int = 4

func _ready() -> void:
	super._ready()
	_setup_strike_dot_styles()
	if is_instance_valid(p1_missed_turns_box):
		p1_missed_turns_box.visible = true
	if is_instance_valid(p2_missed_turns_box):
		p2_missed_turns_box.visible = true
	if is_instance_valid(afk_rule_row):
		afk_rule_row.visible = true

func _setup_strike_dot_styles() -> void:
	_dot_style_empty = StyleBoxFlat.new()
	_dot_style_empty.bg_color = Color(0.22, 0.16, 0.12, 0.65)
	_dot_style_empty.border_color = Color(0.42, 0.32, 0.20, 0.7)
	_dot_style_empty.set_border_width_all(1)
	_dot_style_empty.set_corner_radius_all(6)

	_dot_style_filled = StyleBoxFlat.new()
	_dot_style_filled.bg_color = Color(1.0, 0.55, 0.18, 0.95) # Amber warning
	_dot_style_filled.border_color = Color(1.0, 0.82, 0.35, 1.0)
	_dot_style_filled.set_border_width_all(2)
	_dot_style_filled.set_corner_radius_all(6)
	_dot_style_filled.shadow_color = Color(1.0, 0.5, 0.1, 0.45)
	_dot_style_filled.shadow_size = 4

	_dot_style_danger = StyleBoxFlat.new()
	_dot_style_danger.bg_color = Color(1.0, 0.18, 0.22, 1.0) # Urgent crimson
	_dot_style_danger.border_color = Color(1.0, 0.7, 0.7, 1.0)
	_dot_style_danger.set_border_width_all(2)
	_dot_style_danger.set_corner_radius_all(6)
	_dot_style_danger.shadow_color = Color(1.0, 0.1, 0.15, 0.6)
	_dot_style_danger.shadow_size = 6

func setup_match(game_name_fa: String, mode_title: String, round_num: int, max_rounds: int, turn_time: float) -> void:
	super.setup_match(game_name_fa, mode_title, round_num, max_rounds, turn_time)
	_max_missed_turns = GameRegistry.get_max_missed_turns(GameTypes.CHESS)
	if _max_missed_turns <= 0:
		_max_missed_turns = 4
	if is_instance_valid(lbl_afk_rule):
		lbl_afk_rule.text = "هر نوبت بازی: %d ثانیه  |  در %d نوبت بدون حرکت = باخت مستقیم" % [int(turn_time), _max_missed_turns]
	update_not_played_turns(1, 0)
	update_not_played_turns(2, 0)

func update_not_played_turns(gamer_id: int, count: int) -> void:
	var dots = [p1_dot1, p1_dot2, p1_dot3] if gamer_id == 1 else [p2_dot1, p2_dot2, p2_dot3]
	var count_lbl: Label = p1_strike_count_lbl if gamer_id == 1 else p2_strike_count_lbl
	var box: HBoxContainer = p1_missed_turns_box if gamer_id == 1 else p2_missed_turns_box

	if not is_instance_valid(count_lbl) or dots.is_empty():
		return

	var clamped_count = clampi(count, 0, _max_missed_turns)

	# Update 3 visual dot indicators
	for i in range(3):
		var dot = dots[i]
		if not is_instance_valid(dot):
			continue
		if clamped_count > i:
			if clamped_count >= 3:
				dot.add_theme_stylebox_override("panel", _dot_style_danger)
			else:
				dot.add_theme_stylebox_override("panel", _dot_style_filled)
		else:
			dot.add_theme_stylebox_override("panel", _dot_style_empty)

	# Update textual strike indicator (e.g. "خطا: 2/4")
	count_lbl.text = "خطا: %d/%d" % [clamped_count, _max_missed_turns]
	if clamped_count >= 3:
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	elif clamped_count > 0:
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	else:
		count_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.70))

	# Dynamic feedback when strike count increases
	if count > 0 and is_instance_valid(box):
		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		box.pivot_offset = box.size / 2.0
		tw.tween_property(box, "scale", Vector2(1.15, 1.15), 0.15)
		tw.tween_property(box, "scale", Vector2(1.0, 1.0), 0.15)

func update_turn(turn: int, my_idx: int, p1_n: String, p2_n: String) -> void:
	super.update_turn(turn, my_idx, p1_n, p2_n)
	if not is_instance_valid(lbl_turn_banner):
		return
	if not GameManager.is_game_active:
		lbl_turn_banner.text = "بازی درحال آغاز است"
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		return
	var is_p1 = (turn == 1)
	var is_me = (turn == my_idx)
	if is_me:
		var color_str = "ارتش قرمز" if is_p1 else "ارتش آبی"
		var dot = "🔴" if is_p1 else "🔵"
		lbl_turn_banner.text = "%s نوبت شماست (%s) — مهره خود را حرکت دهید" % [dot, color_str]
		lbl_turn_banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	else:
		var opp_name = p1_n if is_p1 else p2_n
		var opp_color = "ارتش قرمز" if is_p1 else "ارتش آبی"
		lbl_turn_banner.text = "⏳ نوبت %s (%s) — در انتظار حرکت حریف..." % [opp_name, opp_color]
		lbl_turn_banner.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

func reset_header() -> void:
	super.reset_header()
	update_not_played_turns(1, 0)
	update_not_played_turns(2, 0)
