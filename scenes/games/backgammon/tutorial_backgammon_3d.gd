class_name TutorialBackGammon3D
extends BackGammon3D

## Offline interactive Backgammon 3D board for the Library tutorial.
## Supports scripted visual scenarios for:
##   - Rolling dice & normal checker movement
##   - Hitting an enemy blot (sending it to the Bar)
##   - Re-entering a hit checker from the Bar
##   - End-phase home quadrant & bearing off into the vault

signal tutorial_dice_rolled()
signal tutorial_piece_moved(move_count: int)

var tutorial_input_enabled: bool = false
var _moves_done_this_turn: int = 0
var _scripted_dice: Array = [3, 1]


func _ready() -> void:
	super._ready()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func send_move(command_id: String, payload: Variant) -> void:
	if command_id == Commands.Roll_Dice:
		_moves_done_this_turn = 0
		on_roll_result({"dices": _scripted_dice.duplicate(), "turn": 1})
		tutorial_dice_rolled.emit()
	elif command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		_moves_done_this_turn += 1
		on_piece_selected(1, 0, payload as Dictionary)
		tutorial_piece_moved.emit(_moves_done_this_turn)


func _unhandled_input(event: InputEvent) -> void:
	if not tutorial_input_enabled:
		return
	super._unhandled_input(event)


func set_scripted_dice(dices: Array) -> void:
	_scripted_dice = dices.duplicate()


func setup_hit_blot_scenario() -> void:
	_clear_all_board_spots()
	# P1 has 2 checkers on point 0 and can hit P2's lone blot on point 3 with die=3
	_set_spot(0, 1, 2)
	_set_spot(11, 1, 5)
	_set_spot(16, 1, 3)
	_set_spot(18, 1, 5)
	_set_spot(3, 2, 1) # Lone enemy blot!
	_set_spot(12, 2, 5)
	_set_spot(23, 2, 4)
	_apply_scenario_dice([3, 2])


func setup_bar_reentry_scenario() -> void:
	_clear_all_board_spots()
	# P1 has 1 checker hit on the Bar (p1_out_pieces = 1) and must bring it back first
	_set_spot(11, 1, 5)
	_set_spot(16, 1, 4)
	_set_spot(18, 1, 5)
	p1_out_pieces = 1
	_set_spot(5, 2, 3)
	_set_spot(12, 2, 5)
	_set_spot(23, 2, 2)
	_apply_scenario_dice([4, 2])


func setup_bear_off_scenario() -> void:
	_clear_all_board_spots()
	# All remaining P1 checkers are gathered in the home quadrant (points 18..23)
	p1_score = 10
	_set_spot(20, 1, 3) # Needs 4 to bear off (20 + 4 = 24)
	_set_spot(22, 1, 2) # Needs 2 to bear off (22 + 2 = 24)
	_set_spot(0, 2, 2)
	_set_spot(5, 2, 3)
	_apply_scenario_dice([4, 2])


func _clear_all_board_spots() -> void:
	board_spots.clear()
	for _i in range(24):
		board_spots.append({"count": 0, "equipped_user": -1})
	p1_score = 0
	p2_score = 0
	p1_out_pieces = 0
	p2_out_pieces = 0
	p1_is_in_end_phase = false
	p2_is_in_end_phase = false
	_moves_done_this_turn = 0
	current_dices.clear()
	equipped_dice_index = -1
	dices_rolled = false
	can_select_peace = false


func _apply_scenario_dice(dices: Array) -> void:
	_scripted_dice = dices.duplicate()
	_check_gamer_is_in_end_phase(1)
	_check_gamer_is_in_end_phase(2)
	_rebuild_all_3d_pieces()
	on_roll_result({"dices": dices.duplicate(), "turn": 1})


func get_roll_button_control() -> Control:
	return _action_roll_btn


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.68, 0.04)
