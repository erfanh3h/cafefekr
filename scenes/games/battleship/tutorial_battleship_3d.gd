class_name TutorialBattleShip3D
extends BattleShip3D

## Offline interactive BattleShip 3D board for the Library tutorial.

signal tutorial_ship_moved()
signal tutorial_fleet_saved()
signal tutorial_shot_fired(cell_idx: int, is_hit: bool)

var tutorial_input_enabled: bool = false
var _shot_count: int = 0
var _force_next_hit: bool = false


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


func submit_code() -> void:
	if is_play_phase or is_board_saved:
		return
	for s_len in SHIP_LENGTHS:
		if not fleet_state[s_len]["placed"] or fleet_state[s_len]["cells"].size() != s_len:
			_apply_default_initial_fleet()
			break
	is_board_saved = true
	is_play_phase = true
	is_my_turn = true
	set_board_locked(false)
	_update_phase_visibility()
	AudioManager.play_sound("tap_button")
	tutorial_fleet_saved.emit()


func _input(event: InputEvent) -> void:
	if not tutorial_input_enabled:
		return
	super._input(event)


func set_force_next_hit(hit_val: bool) -> void:
	_force_next_hit = hit_val


func _handle_phase1_input(event: InputEvent) -> void:
	super._handle_phase1_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tutorial_ship_moved.emit()


func _handle_phase2_input(event: InputEvent) -> void:
	if not tutorial_input_enabled or not is_play_phase:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var world_pt: Variant = _project_screen_to_board_plane(event.position)
		if world_pt != null and is_instance_valid(attack_board_root):
			var c_idx: int = _world_to_grid_cell(attack_board_root, world_pt as Vector3)
			if c_idx >= 0 and c_idx < TOTAL_CELLS and not bool(attack_cells_state[c_idx]["is_selected"]):
				_shot_count += 1
				var is_hit: bool = _force_next_hit
				on_piece_selected(1, c_idx, {
					"index": c_idx,
					"gamer_id": 1,
					"number": 3 if is_hit else 0,
					"is_turn_win_happened": is_hit
				})
				is_my_turn = true
				set_board_locked(false)
				tutorial_shot_fired.emit(c_idx, is_hit)
				return
	super._handle_phase2_input(event)


func get_fleet_status_rect() -> Rect2:
	if not is_instance_valid(attack_board_root):
		return Rect2()
	var strip_z: float = (GRID_SIZE * CELL_PITCH) * 0.5 + 0.068
	var center_w: Vector3 = attack_board_root.to_global(Vector3(0.0, 0.025, strip_z))
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), center_w, 0.45, 0.045, 48.0)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
