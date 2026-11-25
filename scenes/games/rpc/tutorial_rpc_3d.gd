class_name TutorialRPC3D
extends "res://scenes/games/rpc/rpc_3d.gd"

## Offline interactive Rock-Paper-Scissors (سنگ کاغذ قیچی) 3D board for the Library tutorial.

signal tutorial_round_clashed(my_choice: String, opp_choice: String, winner: int)

var tutorial_input_enabled: bool = false
var _round_idx: int = 0


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_rpc_state()


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_rpc_state() -> void:
	_round_idx = 0
	on_new_turn_round()


func _get_winning_opp_choice(my_c: String) -> Array:
	# Return [opp_choice, winner] where player wins first 2 rounds, or normal RPS rule
	var beats: Dictionary = {"rock": "cutter", "paper": "rock", "cutter": "paper"}
	var opp_c: String = str(beats.get(my_c, "cutter"))
	return [opp_c, 1]


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id == Commands.Select_Peace:
		var my_c: String = str(payload).to_lower()
		var res := _get_winning_opp_choice(my_c)
		var opp_c: String = str(res[0])
		var w: int = int(res[1])
		_round_idx += 1
		on_finish_turn_round({
			"Winner": w,
			"P1_selection": my_c,
			"P2_selection": opp_c,
		})
		tutorial_round_clashed.emit(my_c, opp_c, w)


func prepare_next_turn_round() -> void:
	on_new_turn_round()


func get_choice_button(choice_key: String) -> Control:
	if _action_choice_buttons.has(choice_key) and is_instance_valid(_action_choice_buttons[choice_key]):
		return _action_choice_buttons[choice_key]
	return _action_dock_panel


func get_dock_control() -> Control:
	return _action_dock_panel


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
