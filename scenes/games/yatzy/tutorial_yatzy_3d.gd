class_name TutorialYatzy3D
extends Yatzy3D

## Offline interactive Yatzy 3D board for the Library tutorial.

signal tutorial_dice_rolled(roll_num: int)
signal tutorial_die_toggled(die_idx: int)
signal tutorial_three_sixes_held()
signal tutorial_category_selected(cat_idx: int)
signal tutorial_score_submitted(cat_idx: int, score: int)

var tutorial_input_enabled: bool = false
var guided_allowed_dice: Array[int] = []
var guided_allowed_category: int = -1
var _roll_count: int = 0


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


func send_move(command_id: String, _payload: Variant) -> void:
	if command_id == Commands.Roll_Dice:
		_roll_count += 1
		var dices: Array = [6, 6, 6, 3, 2] if _roll_count == 1 else [6, 6, 6, 6, 6]
		on_roll_result({"dices": dices})
		is_my_turn = true
		set_board_locked(false)
		tutorial_dice_rolled.emit(_roll_count)
	elif command_id == Commands.Select_Peace:
		var cat: int = equipped_index if equipped_index >= 0 else 5
		var sc: int = _calculate_category_score(cat)
		on_piece_selected(1, cat, {
			"selected_index": cat,
			"score": sc,
			"player1_score": sc,
			"player2_score": 0
		})
		is_my_turn = true
		set_board_locked(false)
		tutorial_score_submitted.emit(cat, sc)


func _on_die_clicked(die_idx: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_dice.is_empty() and die_idx not in guided_allowed_dice:
		AudioManager.play_sound("miss_turn")
		return
	super._on_die_clicked(die_idx)
	tutorial_die_toggled.emit(die_idx)
	if (0 in held_dice_indices) and (1 in held_dice_indices) and (2 in held_dice_indices):
		tutorial_three_sixes_held.emit()


func _on_category_clicked(cat_idx: int) -> void:
	if not tutorial_input_enabled:
		return
	if guided_allowed_category >= 0 and cat_idx != guided_allowed_category:
		AudioManager.play_sound("miss_turn")
		return
	super._on_category_clicked(cat_idx)
	tutorial_category_selected.emit(cat_idx)


func _on_roll_button_clicked() -> void:
	if not tutorial_input_enabled:
		return
	super._on_roll_button_clicked()


func _on_submit_button_clicked() -> void:
	if not tutorial_input_enabled:
		return
	super._on_submit_button_clicked()


func get_roll_button_control() -> Control:
	return _action_roll_btn


func get_submit_button_control() -> Control:
	return _action_submit_btn


func get_first_three_dice_rect() -> Rect2:
	var center_w: Vector3 = to_global(Vector3(-0.175, BOARD_H + 0.03, 0.376))
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), center_w, 0.24, 0.075, 56.0)


func get_category_row_rect(cat_idx: int) -> Rect2:
	var row_node: Node3D = get_node_or_null("CategoryRow_%d" % cat_idx) as Node3D
	if not is_instance_valid(row_node):
		return Rect2()
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), row_node.global_position, 0.24, 0.068, 48.0)


func get_left_column_rect() -> Rect2:
	var combined := Rect2()
	for idx in range(6):
		var r: Rect2 = get_category_row_rect(idx)
		if r.size.x > 1.0 and r.size.y > 1.0:
			combined = r if combined.size.x <= 1.0 else combined.merge(r)
	return combined


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.65, 0.04)
