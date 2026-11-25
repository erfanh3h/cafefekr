class_name TutorialFekrBekr3D
extends "res://scenes/games/fekrbekr/fekrbekr_3d.gd"

## Offline interactive FekrBekr (فکر بکر / Mastermind) 3D board for the Library tutorial.
## Phase 1: Set a 4-color non-repeating secret code on the Grand Royal Vault Tray.
## Phase 2: Guess opponent's secret [1, 2, 3, 4] and read Black (exact) / White (color-only) clue pins.

signal tutorial_secret_set(secret: Array)
signal tutorial_guess_submitted(guess: Array, result: Array, cracked: bool)

const TUTORIAL_OPP_SECRET: Array[int] = [1, 2, 3, 4]

var tutorial_input_enabled: bool = false


func _ready() -> void:
	GameManager.my_player_index = 1
	GameManager.is_game_active = true
	super._ready()
	setup_tutorial_fekrbekr_state()


func _exit_tree() -> void:
	GameManager.is_game_active = false
	super._exit_tree()


func setup_tutorial_fekrbekr_state() -> void:
	setup_board({})
	on_start_game()
	set_board_locked(false)


func _compute_mastermind_feedback(guess: Array) -> Array:
	var res: Array = []
	for i: int in range(4):
		var g: int = int(guess[i])
		if g == TUTORIAL_OPP_SECRET[i]:
			res.append(2) # Black: right color + right slot
		elif g in TUTORIAL_OPP_SECRET:
			res.append(1) # White: right color, wrong slot
		else:
			res.append(0) # Empty: not in secret
	res.sort()
	res.reverse() # Standard Mastermind pin order: Blacks (2), then Whites (1), then Empty (0)
	return res


func has_full_selection() -> bool:
	var sel: Array = active_selection if is_play_phase else phase1_selection
	if sel.size() < 4:
		return false
	for v in sel:
		if int(v) <= 0:
			return false
	return true


func _submit_selection() -> void:
	if not tutorial_input_enabled or is_board_locked:
		return
	_cancel_active_drag()

	if not is_play_phase:
		for v in phase1_selection:
			if v <= 0:
				show_hint("لطفاً هر ۴ مهره رمز را انتخاب کنید.")
				AudioManager.play_sound("tap_wrong")
				return
		var uniq := []
		for v in phase1_selection:
			if v in uniq:
				show_hint("رنگ‌های رمز باید غیرتکراری باشند.")
				AudioManager.play_sound("tap_wrong")
				return
			uniq.append(v)

		AudioManager.play_sound("tap_button")
		my_secret_board = phase1_selection.duplicate()
		is_my_board_set = true
		if is_instance_valid(phase1_root):
			phase1_root.visible = false
		on_turn_changed(1, true)
		tutorial_secret_set.emit(my_secret_board)
	else:
		for v in active_selection:
			if v <= 0:
				show_hint("لطفاً هر ۴ مهره حدس را در جایگاه قرار دهید.")
				AudioManager.play_sound("tap_wrong")
				return
		var uniq_guess := []
		for v in active_selection:
			if v in uniq_guess:
				show_hint("رنگ‌های انتخاب‌شده نباید تکراری باشند.")
				AudioManager.play_sound("tap_wrong")
				return
			uniq_guess.append(v)

		AudioManager.play_sound("tap_button")
		var guess_copy: Array = active_selection.duplicate()
		var fb: Array = _compute_mastermind_feedback(guess_copy)
		on_piece_selected(1, -1, {"data": guess_copy, "result": fb})
		var cracked: bool = (fb.size() == 4 and fb[0] == 2 and fb[1] == 2 and fb[2] == 2 and fb[3] == 2)
		if not cracked and current_round_num < 12:
			on_turn_changed(current_round_num + 1, true)
		else:
			set_board_locked(false)
		tutorial_guess_submitted.emit(guess_copy, fb, cracked)


func get_submit_button_control() -> Control:
	var hud := _get_hud()
	if is_instance_valid(hud) and "btn_fekr_submit" in hud and is_instance_valid(hud.get("btn_fekr_submit")):
		return hud.get("btn_fekr_submit") as Control
	return null


func ensure_my_board_view() -> void:
	if current_view_mode != ViewMode.MY_BOARD:
		_apply_view_mode_positions(ViewMode.MY_BOARD, false)


func get_phase2_input_rect(include_first_row: bool = false) -> Rect2:
	if not is_play_phase:
		return get_board_screen_rect()
	ensure_my_board_view()
	var base_pos: Vector3 = my_board_root.global_position if is_instance_valid(my_board_root) else global_position
	# Cover active input box ("حدس فعلی" at z=0.508) + all 8 selectable palette pegs (z=0.632..0.738),
	# and optionally Row 1 (z=0.37) so feedback pins stay highlighted on the second guess.
	var center_z: float = 0.555 if include_first_row else 0.625
	var half_z: float = 0.255 if include_first_row else 0.185
	var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), base_pos + Vector3(0.0, 0.03, center_z), 0.37, half_z, 80.0)
	return r if r.size.x > 12.0 else get_board_screen_rect()


func get_board_screen_rect() -> Rect2:
	if is_play_phase:
		var base_pos: Vector3 = my_board_root.global_position if is_instance_valid(my_board_root) else global_position
		var r: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), base_pos + Vector3(0.0, 0.03, 0.0), (BOARD_W * 0.5) + 0.04, (BOARD_L * 0.5) + 0.04, 12.0)
		return r if r.size.x > 12.0 else Rect2()
	var p1_pos: Vector3 = phase1_root.global_position if is_instance_valid(phase1_root) else global_position
	var r1: Rect2 = Tutorial3DHelper.project_world_box_rect(get_viewport(), p1_pos + Vector3(0.0, 0.04, 0.0), (TRAY_W * 0.5) + 0.04, (TRAY_L * 0.5) + 0.04, 12.0)
	return r1 if r1.size.x > 12.0 else Rect2()
