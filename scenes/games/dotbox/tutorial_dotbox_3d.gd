class_name TutorialDotBox3D
extends DotBox3D

## Offline interactive DotBox 3D board for the Library tutorial.

signal tutorial_line_drawn(line_id: int)
signal tutorial_wrong_line_tapped(line_id: int)

var tutorial_input_enabled: bool = false
var guided_allowed_lines: Array[int] = []


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
	var line_id: int = int(payload)
	on_piece_selected(1, line_id)
	is_my_turn = true
	set_board_locked(false)
	tutorial_line_drawn.emit(line_id)


func _on_line_channel_pressed(line_id: int) -> void:
	if not tutorial_input_enabled:
		return
	if not guided_allowed_lines.is_empty() and line_id not in guided_allowed_lines:
		AudioManager.play_sound("miss_turn")
		tutorial_wrong_line_tapped.emit(line_id)
		return
	super._on_line_channel_pressed(line_id)


func setup_box_completion_scenario() -> void:
	# Box 0 walls: top=0, left=5, right=6, bottom=11.
	# Pre-fill 0 (P1), 5 (P2), 6 (P1) so line 11 closes the box!
	var arr: Array[int] = []
	arr.resize(TOTAL_LINES)
	arr.fill(0)
	arr[0] = 1
	arr[5] = 2
	arr[6] = 1
	sync_board_state(arr)
	my_player_index = 1
	current_turn = 1
	is_my_turn = true
	is_board_locked = false


func get_line_screen_rect(line_id: int) -> Rect2:
	if line_id < 0 or line_id >= line_centers.size():
		return Rect2()
	var center_w: Vector3 = to_global(line_centers[line_id])
	var is_h: bool = line_is_horizontal[line_id]
	var hx: float = (DOT_SPACING * 0.48) if is_h else 0.045
	var hz: float = 0.045 if is_h else (DOT_SPACING * 0.48)
	return Tutorial3DHelper.project_world_box_rect(get_viewport(), center_w, hx, hz, 54.0)


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.58, 0.04)
