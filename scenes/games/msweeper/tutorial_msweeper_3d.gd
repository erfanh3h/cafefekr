class_name TutorialMSweeper3D
extends "res://scenes/games/msweeper/msweeper_3d.gd"

## Offline interactive Minesweeper (مین یاب) 3D board for the Library tutorial.
## Overrides _reveal_safe_cell and _flag_mine_on_cell to run locally without NetworkManager.

signal tutorial_cell_dug(idx: int, val: int)
signal tutorial_mine_flagged(idx: int, correct: bool)

var tutorial_input_enabled: bool = false
var _tut_phase: String = "dig" # "dig" | "flood" | "flag" | "flag_2"
var _cell_vals: Array[int] = []
var _mines: Array[int] = [9, 10] # (1,1) and (1,2)


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_msweeper_state()
	call_deferred("enable_2d_top_down_view")
	get_tree().create_timer(1.10).timeout.connect(func():
		if is_instance_valid(self):
			enable_2d_top_down_view()
	)


func _find_cafe_table() -> Node:
	var p1: Node = get_parent()
	if is_instance_valid(p1) and is_instance_valid(p1.get_parent()) and p1.get_parent().has_method("set_top_down_view"):
		return p1.get_parent()
	var tree := get_tree()
	if not tree:
		return null
	var table: Node = tree.get_first_node_in_group("cafe_table")
	if not is_instance_valid(table):
		table = tree.root.find_child("CafeTable", true, false)
	return table


func enable_2d_top_down_view() -> void:
	var table: Node = _find_cafe_table()
	if not is_instance_valid(table):
		return
	table.set("_intro_glide_pending", false)
	table.set("_intro_glide_played_for_board", true)
	table.set("_intro_glide_active", false)
	table.set("is_board_view_active", true)
	table.set("top_down_target_height", 3.05)
	if not bool(table.get("is_top_down_view")) and table.has_method("set_top_down_view"):
		table.call("set_top_down_view", true, 0.25)


func _exit_tree() -> void:
	var table: Node = _find_cafe_table()
	if is_instance_valid(table) and table.has_method("set_top_down_view"):
		table.call("set_top_down_view", false, 0.25)
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_msweeper_state() -> void:
	_tut_phase = "dig"
	_cell_vals.clear()
	for r: int in range(8):
		for c: int in range(8):
			var idx: int = r * 8 + c
			if idx in _mines:
				_cell_vals.append(-1)
			else:
				var cnt: int = 0
				for dr: int in range(-1, 2):
					for dc: int in range(-1, 2):
						if dr == 0 and dc == 0:
							continue
						var nr: int = r + dr
						var nc: int = c + dc
						if nr >= 0 and nr < 8 and nc >= 0 and nc < 8 and ((nr * 8 + nc) in _mines):
							cnt += 1
				_cell_vals.append(cnt)

	on_start_game()
	is_my_turn = true
	is_board_locked = false
	is_hit_mine = false
	select_peace_remaining = 30
	select_mine_remaining = 10

	# Pre-reveal corner clues around (1,1) so player can deduce (1,1) is a mine!
	for pre_idx: int in [0, 1, 2, 8, 16]:
		on_select_peace_result({"peace_number": pre_idx, "value": _cell_vals[pre_idx]})


func set_tutorial_phase(p: String) -> void:
	_tut_phase = p
	enable_2d_top_down_view()


func _reveal_safe_cell(idx: int) -> void:
	if not tutorial_input_enabled or select_peace_remaining <= 0 or cell_selected[idx] or is_hit_mine:
		return
	if _tut_phase == "flag" or _tut_phase == "flag_2":
		AudioManager.play_sound("tap_wrong")
		show_hint("⚠️ اینجا مین است! انگشت را نگه دار، راست‌کلیک کن، یا حالت «پرچم» پایین تخته را بزن.")
		return
	if idx in _mines:
		AudioManager.play_sound("tap_wrong")
		show_hint("⚠️ اینجا مین مخفی شده! خانه امن مشخص‌شده رو بزن.")
		return

	AudioManager.play_sound("tap")
	var val: int = _cell_vals[idx]
	on_select_peace_result({"peace_number": idx, "value": val})
	if val == 0 and idx == 36:
		# Demonstrate flood-fill of safe 0 neighbors around (4,4)
		for flood_idx: int in [27, 28, 29, 35, 37, 43, 44, 45]:
			if not cell_selected[flood_idx] and not (flood_idx in _mines):
				on_select_peace_result({"peace_number": flood_idx, "value": _cell_vals[flood_idx]})
	tutorial_cell_dug.emit(idx, val)


func _flag_mine_on_cell(idx: int) -> void:
	if not tutorial_input_enabled or is_hit_mine or cell_selected[idx]:
		return
	if idx in _mines:
		select_mine_remaining = max(0, select_mine_remaining - 1)
		on_select_mine_correct({"peace_number": idx})
		tutorial_mine_flagged.emit(idx, true)
	else:
		select_mine_remaining = max(0, select_mine_remaining - 1)
		on_select_mine_wrong({"peace_number": idx})
		tutorial_mine_flagged.emit(idx, false)


func get_cell_screen_rect(idx: int) -> Rect2:
	if idx < 0 or idx >= cell_centers.size():
		return get_board_screen_rect()
	var w_pos: Vector3 = to_global(cell_centers[idx])
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), w_pos, 0.055, 0.055, 58.0)
	return r if r.size.x > 0.0 else get_board_screen_rect()


func get_board_screen_rect() -> Rect2:
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), global_position + Vector3(0.0, 0.04, -0.05), 0.68, 0.72, 12.0)
	return r if r.size.x > 12.0 else Tutorial3DHelper.get_board_bounds_rect(get_viewport(), global_position, 0.72, 0.04)
