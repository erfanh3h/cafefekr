class_name TutorialQuoridor3D
extends "res://scenes/games/quoridor/quoridor_3d.gd"

## Offline interactive Quoridor 3D board for the Library tutorial.
## Covers pawn movement toward goal row, jumping over an adjacent opponent pawn,
## and placing a horizontal/vertical wall without sealing off the opponent's path.

signal tutorial_pawn_moved(row: int, col: int)
signal tutorial_wall_placed(orient: String, row: int, col: int)

var tutorial_input_enabled: bool = false
var wall_only_mode: bool = false


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_quoridor_state()


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_quoridor_state() -> void:
	wall_only_mode = false
	winner_id = 0
	current_turn = 1
	is_my_turn = true
	is_board_locked = false
	current_mode = ACTION_MOVE
	on_reconnect_data({
		"pawns": [[6, 4], [2, 4]],
		"walls_left": [10, 10],
		"h_walls": [],
		"v_walls": [],
		"current_turn": 1,
	})


func setup_jump_scenario() -> void:
	wall_only_mode = false
	current_mode = ACTION_MOVE
	# Keep Player 1 right at [5, 4] (where they moved in Phase 2) and place Opponent directly in front at [4, 4]!
	on_reconnect_data({
		"pawns": [[5, 4], [4, 4]],
		"walls_left": [10, 10],
		"h_walls": [],
		"v_walls": [],
		"current_turn": 1,
	})
	is_my_turn = true
	is_board_locked = false


func setup_wall_scenario() -> void:
	wall_only_mode = true
	current_mode = ACTION_MOVE
	preview_wall_rc = Vector2i(-1, -1)
	preview_wall_valid = false
	is_my_turn = true
	is_board_locked = false
	_refresh_dock_buttons()
	_refresh_highlights_and_preview()


func _attempt_pawn_move(r: int, c: int) -> void:
	if not tutorial_input_enabled:
		return
	if wall_only_mode:
		show_hint("در این مرحله حرکت مهره قفل است — یک دیوار بگذارید!")
		AudioManager.play_sound("miss_turn")
		return
	var legal: Array[Vector2i] = get_legal_pawn_moves(my_player_index)
	var is_ok: bool = false
	for m: Vector2i in legal:
		if m.x == r and m.y == c:
			is_ok = true
			break
	if not is_ok:
		show_hint("تنها می‌توانید به خانه‌های سبز روشن‌شده حرکت کنید.")
		AudioManager.play_sound("miss_turn")
		return
	_clear_all_legal_pads()
	send_move(Commands.Select_Peace, {
		"action": "move",
		"row": r,
		"col": c,
	})


func _confirm_previewed_wall() -> void:
	if not tutorial_input_enabled or is_board_locked or winner_id != 0:
		return
	if not is_my_turn or current_mode == ACTION_MOVE or preview_wall_rc.x < 0:
		return
	var ori := "H" if current_mode == ACTION_WALL_H else "V"
	var err := _diagnose_wall_error(my_player_index, preview_wall_rc.x, preview_wall_rc.y, ori)
	if err != "":
		show_hint(err)
		AudioManager.play_sound("miss_turn")
		return
	var wr := preview_wall_rc.x
	var wc := preview_wall_rc.y
	preview_wall_rc = Vector2i(-1, -1)
	preview_wall_valid = false
	if is_instance_valid(ghost_wall_node):
		ghost_wall_node.visible = false
	_set_action_mode(ACTION_MOVE)
	send_move(Commands.Select_Peace, {
		"action": "wall",
		"row": wr,
		"col": wc,
		"orientation": ori,
	})


func send_move(command_id: String, payload: Variant) -> void:
	if not tutorial_input_enabled:
		return
	if command_id == Commands.Select_Peace and typeof(payload) == TYPE_DICTIONARY:
		var d: Dictionary = payload as Dictionary
		var act: String = str(d.get("action", "move"))
		if act == "move":
			var r: int = int(d.get("row", pawns[0][0]))
			var c: int = int(d.get("col", pawns[0][1]))
			on_piece_selected(1, -1, {
				"action": "move",
				"gamer_id": 1,
				"pawns": [[r, c], pawns[1].duplicate()],
				"walls_left": walls_left.duplicate(),
				"h_walls": h_walls.duplicate(true),
				"v_walls": v_walls.duplicate(true),
				"current_turn": 1,
			})
			is_my_turn = true
			is_board_locked = false
			tutorial_pawn_moved.emit(r, c)
		elif act == "wall":
			var ori: String = str(d.get("orientation", d.get("orient", "H"))).to_lower()
			var wr: int = int(d.get("row", 0))
			var wc: int = int(d.get("col", 0))
			var new_h: Array = h_walls.duplicate(true)
			var new_v: Array = v_walls.duplicate(true)
			if ori == "h":
				new_h.append([wr, wc])
			else:
				new_v.append([wr, wc])
			var new_wl: Array = [maxi(0, int(walls_left[0]) - 1), int(walls_left[1])]
			current_mode = ACTION_MOVE
			on_piece_selected(1, -1, {
				"action": "wall",
				"gamer_id": 1,
				"row": wr,
				"col": wc,
				"pawns": pawns.duplicate(true),
				"walls_left": new_wl,
				"h_walls": new_h,
				"v_walls": new_v,
				"current_turn": 1,
			})
			is_my_turn = true
			is_board_locked = false
			tutorial_wall_placed.emit(ori, wr, wc)


func get_cell_screen_rect(r: int, c: int) -> Rect2:
	var local_p: Vector3 = _cell_to_local_pos(r, c, 0.02)
	var world_p: Vector3 = to_global(local_p)
	var rect: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), world_p, 0.085, 0.085, 64.0)
	return rect if rect.size.x > 0.0 else get_board_screen_rect()


func get_wall_step_target() -> Variant:
	if current_mode == ACTION_MOVE:
		if is_instance_valid(btn_mode_wall_h) and is_instance_valid(btn_mode_wall_v):
			return btn_mode_wall_h.get_global_rect().merge(btn_mode_wall_v.get_global_rect())
		return dock_panel
	if preview_wall_rc.x >= 0 and is_instance_valid(btn_confirm_wall):
		return btn_confirm_wall
	return get_board_screen_rect()


func get_dock_control() -> Control:
	return dock_panel


func get_board_and_dock_rect() -> Variant:
	var br: Rect2 = get_board_screen_rect()
	if is_instance_valid(dock_panel):
		var dr: Rect2 = dock_panel.get_global_rect()
		if br.size.x > 0.0 and dr.size.x > 0.0:
			return br.merge(dr)
		return dock_panel
	return br


func get_board_screen_rect() -> Rect2:
	return Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
