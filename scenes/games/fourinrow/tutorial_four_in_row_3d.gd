class_name TutorialFourInRow3D
extends FourInRow3D

## Offline interactive Four-in-a-Row 3D board for the Library tutorial.

signal tutorial_player_dropped(col_idx: int)
signal tutorial_scripted_drop_finished(col_idx: int)
signal tutorial_wrong_col_tapped(col_idx: int)

var tutorial_input_enabled: bool = false
var guided_allowed_cols: Array[int] = []
var _scripted_busy: bool = false


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


func send_move(_command_id: String, payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var col_idx: int = int((payload as Dictionary).get("r_index", -1))
	var row_idx: int = _get_lowest_empty_row(col_idx)
	if row_idx < 0:
		set_board_locked(false)
		return
	on_piece_selected(1, 0, {"r_index": col_idx, "c_index": row_idx})
	is_my_turn = true
	set_board_locked(false)
	tutorial_player_dropped.emit(col_idx)


func _on_column_selection_tap(r_index: int) -> void:
	if _scripted_busy or not tutorial_input_enabled:
		return
	if not guided_allowed_cols.is_empty() and r_index not in guided_allowed_cols:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_col_tapped.emit(r_index)
		return
	super._on_column_selection_tap(r_index)


func trigger_scripted_drop(col_idx: int, delay_sec: float = 0.8) -> void:
	_scripted_busy = true
	tutorial_input_enabled = false
	set_board_locked(true)
	current_turn = 2
	is_my_turn = false
	GameManager.current_turn = 2

	get_tree().create_timer(delay_sec).timeout.connect(func():
		if not is_instance_valid(self):
			return
		var row_idx: int = _get_lowest_empty_row(col_idx)
		if row_idx >= 0:
			on_piece_selected(2, 0, {"r_index": col_idx, "c_index": row_idx})
		get_tree().create_timer(0.55).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_scripted_busy = false
			current_turn = 1
			is_my_turn = true
			GameManager.current_turn = 1
			set_board_locked(false)
			tutorial_scripted_drop_finished.emit(col_idx)
		)
	)


func get_column_screen_rect(col_idx: int) -> Rect2:
	if col_idx < 0 or col_idx >= GRID_SIZE:
		return Rect2()
	var x_local: float = _col_to_x(col_idx)
	var center_w: Vector3 = to_global(Vector3(x_local, 0.08, -0.02))
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), center_w, 0.075, 0.48, 56.0)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.62, 0.15)
