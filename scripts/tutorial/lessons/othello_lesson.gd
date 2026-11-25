class_name OthelloTutorialLesson
extends GameTutorialLesson

## Interactive Othello tutorial for the Library tab.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/othello/tutorial_othello_3d.tscn")

var _phase: String = ""
var _target_cell: int = 19


func get_game_type() -> String:
	return GameTypes.OTHELLO


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var oth := board as TutorialOthello3D
	if not is_instance_valid(oth):
		return
	oth.tutorial_input_enabled = false
	oth.tutorial_player_moved.connect(_on_player_moved)
	oth.tutorial_scripted_move_finished.connect(_on_scripted_move_finished)
	oth.tutorial_wrong_cell_tapped.connect(_on_wrong_cell_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"oth_welcome",
		"آموزش اتللو (Othello)",
		"در اتللو هر بار مهره‌ای می‌ذاری که مهره‌های حریف بین دو تا از مهره‌های تو گیر بیفتن، رنگشون به رنگ تو برمی‌گرده! آخر بازی هرکی مهره بیشتری داشته باشه برنده‌ست."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع یادگیری")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_board := TutorialStep.create(
		"oth_board",
		"صفحه ۸×۸ و خانه‌های مجاز",
		"نشانگرهای سبز روی صفحه، خانه‌هایی هستن که الان می‌تونی مهره بذاری و حداقل یک مهره حریف رو برگردونی."
	)
	st_board.with_badge("قانون حرکت")
	st_board.with_cta("بزن بریم!")
	st_board.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_board.with_avoid_rect(func(): return _get_board_rect())
	st_board.with_scrim_alpha(0.80)
	st_board.with_placement("auto")
	s.append(st_board)

	var st_move1 := TutorialStep.create(
		"oth_move_1",
		"۱. محاصره و برگرداندن مهره",
		"این خانه طلایی رو لمس کن تا مهره حریف بین دو مهره تو گیر بیفته و برگرده!"
	)
	st_move1.with_badge("تمرین عملی")
	st_move1.with_hint("روی خانه طلایی لمس کن")
	st_move1.with_target(func(): return _get_cell_rect(_target_cell), 10.0, 18.0)
	st_move1.with_avoid_rect(func(): return _get_board_rect())
	st_move1.with_scrim_alpha(0.84)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_enter_move_1)
	s.append(st_move1)

	var st_corners := TutorialStep.create(
		"oth_corners",
		"نکته طلایی: گوشه‌های صفحه!",
		"مهره‌هایی که توی ۴ گوشه صفحه قرار می‌گیرن هیچ‌وقت برنمی‌گردن و تا آخر بازی مال تو می‌مونن. پس همیشه دنبال گرفتن گوشه‌ها باش!"
	)
	st_corners.with_badge("استراتژی برد")
	st_corners.with_cta("بعدی")
	st_corners.with_target(func(): return _get_cell_rect(0), 10.0, 18.0)
	st_corners.with_avoid_rect(func(): return _get_board_rect())
	st_corners.with_scrim_alpha(0.82)
	st_corners.with_placement("auto")
	s.append(st_corners)

	var st_done := TutorialStep.create(
		"oth_done",
		"اتللو رو یاد گرفتی!",
		"حالا محاصره مهره‌ها و اهمیت گوشه‌ها رو بلدی. وقتشه بری سر میز و حریفات رو غافلگیر کنی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.82)
	s.append(st_done)

	return s


func _enter_move_1() -> void:
	_phase = "move_1"
	var oth := _board as TutorialOthello3D
	if is_instance_valid(oth):
		oth.update_legal_moves_for_turn()
		_target_cell = oth.get_first_legal_cell()
		oth.tutorial_input_enabled = true
		oth.set_guided_cells([_target_cell])


func _on_player_moved(_cell_idx: int) -> void:
	var oth := _board as TutorialOthello3D
	if not is_instance_valid(_coordinator) or not is_instance_valid(oth):
		return
	if _phase == "move_1":
		_phase = "wait_bot"
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("ایول! مهره حریف برگشت! حالا نوبت حریفه...")
		oth.trigger_scripted_move(2, 2, 0.85)


func _on_scripted_move_finished(_cell_idx: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "wait_bot":
		_phase = "done"
		_coordinator.advance_lesson_step()


func _on_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی خانه طلایی مشخص‌شده لمس کن!")


func _get_cell_rect(cell_idx: int) -> Rect2:
	var oth := _board as TutorialOthello3D
	if is_instance_valid(oth):
		return oth.get_cell_screen_rect(cell_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var oth := _board as TutorialOthello3D
	if is_instance_valid(oth):
		return oth.get_board_screen_rect()
	return Rect2()
