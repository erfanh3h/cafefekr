class_name TutorialQuiz3D
extends Quiz3D

## Offline interactive Quiz 3D board for the Library tutorial.

signal tutorial_option_selected(opt_idx: int)

var tutorial_input_enabled: bool = false


func _ready() -> void:
	super._ready()
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	setup_sample_question()


func _connect_network_signals() -> void:
	pass


func _disconnect_network_signals() -> void:
	pass


func _needs_gamer_id_sync() -> bool:
	return false


func setup_sample_question() -> void:
	on_reconnect_data({
		"current_question": {
			"question_number": 1,
			"total_questions": 10,
			"question": "پایتخت ایران کدام شهر است؟",
			"options": ["شیراز", "تهران", "اصفهان", "تبریز"]
		}
	})
	has_answered_this_turn = false
	is_in_reveal_phase = false
	is_my_turn = true
	set_board_locked(false)


func _select_option(opt_idx: int) -> void:
	if not tutorial_input_enabled:
		return
	super._select_option(opt_idx)


func send_move(command_id: String, payload: Variant) -> void:
	if command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		var opt_idx: int = int((payload as Dictionary).get("option", 2))
		tutorial_option_selected.emit(opt_idx)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
