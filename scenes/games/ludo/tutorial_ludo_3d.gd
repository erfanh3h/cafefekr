class_name TutorialLudo3D
extends Ludo3D

## Offline interactive Ludo (منچ) 3D board for the Library tutorial.

signal tutorial_dice_rolled(dice_val: int)
signal tutorial_pawn_moved(src_index: int)

var tutorial_input_enabled: bool = false
var _scripted_dice: int = 6


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


func set_scripted_dice(val: int) -> void:
	_scripted_dice = val


func send_move(command_id: String, payload: Variant) -> void:
	if command_id == Commands.Roll_Dice:
		on_roll_result({"dice": _scripted_dice, "turn": 1})
		tutorial_dice_rolled.emit(_scripted_dice)
	elif command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		var src_idx: int = int((payload as Dictionary).get("index", -2))
		var move_type: String = "out" if src_idx == -2 else ("start" if src_idx == -1 else "normal")
		var tgt_idx: int = -1 if src_idx == -2 else _compute_target_index_for_move(src_idx, 1, current_dice)
		var hit_enemy_val: Variant = null
		if tgt_idx >= 0 and tgt_idx < board_state.size():
			var td: Dictionary = board_state[tgt_idx]
			if int(td.get("equipped_user", 0)) == 2 and int(td.get("count", 0)) > 0:
				hit_enemy_val = 2
		on_piece_selected(1, src_idx, {
			"gamer_id": 1,
			"index": src_idx,
			"target_index": tgt_idx,
			"type": move_type,
			"dice": current_dice,
			"hit_enemy": hit_enemy_val
		})
		is_my_turn = true
		set_board_locked(false)
		tutorial_pawn_moved.emit(src_idx)


func setup_hit_enemy_scenario() -> void:
	_init_empty_state(2)
	players_out_pieces = [3, 3, 0, 0]
	board_state[0] = {"count": 1, "equipped_user": 1}
	board_state[3] = {"count": 1, "equipped_user": 2}
	_rebuild_all_pawns_visuals()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	_scripted_dice = 3
	on_roll_result({"dice": 3, "turn": 1})


func _unhandled_input(event: InputEvent) -> void:
	if not tutorial_input_enabled:
		return
	super._unhandled_input(event)


func _request_roll_dice() -> void:
	if not tutorial_input_enabled:
		return
	super._request_roll_dice()


func get_roll_button_control() -> Control:
	return _action_roll_btn


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
