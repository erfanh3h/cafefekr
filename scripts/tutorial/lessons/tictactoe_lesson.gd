class_name TicTacToeTutorialLesson
extends GameTutorialLesson

## Interactive Tic-Tac-Toe tutorial for the Library tab.
## Reuses the existing `TutorialTicTacToe3D` inherited board.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/tictactoe/tutorial_tictactoe_3d.tscn")

var _phase: String = "" # "move_1" | "bot_1" | "move_2" | "bot_2" | "move_3" | "done"


func get_game_type() -> String:
	return GameTypes.TIC_TAC_TOE


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var ttt := board as TutorialTicTacToe3D
	if not is_instance_valid(ttt):
		return
	ttt.tutorial_input_enabled = false
	ttt.tutorial_player_moved.connect(_on_player_moved)
	ttt.tutorial_bot_moved.connect(_on_bot_moved)
	ttt.tutorial_wrong_cell_tapped.connect(_on_wrong_cell_tapped)
	ttt.tutorial_player_won.connect(_on_player_won)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"ttt_welcome",
		"آموزش دوز (تیک تاک تو)",
		"هدف بازی خیلی ساده‌ست: ۳ تا از مهره‌هات (X) رو پشت سر هم — افقی، عمودی یا مورب — ردیف کن تا برنده بشی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_move1 := TutorialStep.create(
		"ttt_move_1",
		"۱. شروع از خانه وسط",
		"بهترین شروع توی دوز، گرفتن خانه وسطه! روی خانه طلایی وسط لمس کن."
	)
	st_move1.with_badge("تمرین ۱ از ۳")
	st_move1.with_hint("روی خانه وسط لمس کن")
	st_move1.with_target(func(): return _get_cell_rect(4), 8.0, 18.0)
	st_move1.with_avoid_rect(func(): return _get_board_rect())
	st_move1.with_scrim_alpha(0.84)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_enter_move_1)
	s.append(st_move1)

	return s


func _enter_move_1() -> void:
	_phase = "move_1"
	var ttt := _board as TutorialTicTacToe3D
	if is_instance_valid(ttt):
		ttt.tutorial_input_enabled = true
		ttt.set_guided_cells([4])


func _on_player_moved(_cell_idx: int) -> void:
	var ttt := _board as TutorialTicTacToe3D
	if not is_instance_valid(_coordinator) or not is_instance_valid(ttt):
		return
	_coordinator.hide_overlay_temporarily()
	ttt.tutorial_input_enabled = false

	if _phase == "move_1":
		_phase = "bot_1"
		_coordinator.show_hud_toast("ایول! حالا نوبت حریفه...")
		ttt.trigger_easy_bot_move(0, 0.70)
	elif _phase == "move_2":
		_phase = "bot_2"
		_coordinator.show_hud_toast("عالی! فقط یه قدم تا بُرد مونده...")
		ttt.trigger_easy_bot_move(2, 0.70)


func _on_bot_moved(_cell_idx: int) -> void:
	var ttt := _board as TutorialTicTacToe3D
	if not is_instance_valid(_coordinator) or not is_instance_valid(ttt):
		return

	if _phase == "bot_1":
		_phase = "move_2"
		var next_cell: int = 3 if int(ttt.board_state[3]) == 0 else ttt.find_recommended_player_cell()
		ttt.tutorial_input_enabled = true
		ttt.set_guided_cells([next_cell])
		var st2 := TutorialStep.create(
			"ttt_move_2",
			"۲. ساختن ردیف",
			"حریف حرکتش رو زد. حالا این خانه طلایی رو بزن تا دو تا مهره‌ات کنار هم بیفتن!"
		)
		st2.with_badge("تمرین ۲ از ۳")
		st2.with_hint("روی خانه طلایی لمس کن")
		st2.with_target(func(): return _get_cell_rect(next_cell), 8.0, 18.0)
		st2.with_avoid_rect(func(): return _get_board_rect())
		st2.with_scrim_alpha(0.84)
		st2.with_interactive(true, false)
		st2.with_placement("auto")
		_coordinator.show_custom_step(st2, 2, 5)
	elif _phase == "bot_2":
		_phase = "move_3"
		var win_cell: int = ttt.find_recommended_player_cell()
		ttt.tutorial_input_enabled = true
		if win_cell >= 0:
			ttt.set_guided_cells([win_cell])
		var st3 := TutorialStep.create(
			"ttt_move_3",
			"۳. ضربه نهایی و پیروزی!",
			"فقط یه خانه تا پیروزی مونده! این خانه رو بزن تا ۳ تا مهره‌ات ردیف بشن."
		)
		st3.with_badge("تمرین ۳ از ۳")
		st3.with_hint("روی خانه پیروزی لمس کن")
		st3.with_target(func(): return _get_cell_rect(win_cell), 8.0, 18.0)
		st3.with_avoid_rect(func(): return _get_board_rect())
		st3.with_scrim_alpha(0.84)
		st3.with_interactive(true, false)
		st3.with_placement("auto")
		_coordinator.show_custom_step(st3, 3, 5)


func _on_player_won(_winning_line: Array) -> void:
	if not is_instance_valid(_coordinator):
		return
	_phase = "done"
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("ایول! خط پیروزی رو ساختی!")
	_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
		if not is_instance_valid(_coordinator):
			return
		var st_done := TutorialStep.create(
			"ttt_done",
			"دوز رو یاد گرفتی!",
			"به همین سادگی! توی مسابقات واقعی حواست به بستن مسیر حریف هم باشه."
		)
		st_done.with_badge("پایان آموزش")
		st_done.with_cta("بازگشت به کتابخانه")
		st_done.with_placement("center")
		st_done.with_scrim_alpha(0.82)
		_coordinator.show_final_lesson_step(st_done, 4, 5)
	)


func _on_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی خانه طلایی روشن بزن!")


func _get_cell_rect(cell_idx: int) -> Rect2:
	var ttt := _board as TutorialTicTacToe3D
	if is_instance_valid(ttt):
		return ttt.get_cell_screen_rect(cell_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var ttt := _board as TutorialTicTacToe3D
	if is_instance_valid(ttt):
		return ttt.get_board_screen_rect()
	return Rect2()
