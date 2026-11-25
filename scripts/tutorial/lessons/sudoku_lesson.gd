class_name SudokuTutorialLesson
extends GameTutorialLesson

## Interactive Sudoku (سودوکو) tutorial for the Library tab.
## Teaches row/column/3x3 box deduction, conflict detection, and solving the grid.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/sudoku/tutorial_sudoku_3d.tscn")

var _phase: String = "" # "fill_1" | "fill_2" | "fill_3" | "solve" | "done"


func get_game_type() -> String:
	return GameTypes.SUDOKU


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var sdk := board as TutorialSudoku3D
	if not is_instance_valid(sdk):
		return
	sdk.tutorial_input_enabled = false
	sdk.tutorial_cell_filled.connect(_on_cell_filled)
	sdk.tutorial_solved.connect(_on_solved)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"sudoku_welcome",
		"آموزش سودوکو (Sudoku)",
		"قانون سودوکو ساده ولی جذابه: تمام ۸۱ خانه جدول ۹×۹ باید طوری با اعداد ۱ تا ۹ پر بشن که توی هیچ سطر، ستون یا مربع ۳×۳ عدد تکراری نباشه!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("بزن حل کنیم!")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	st_welcome.with_hooks(func(): _ensure_2d_view())
	s.append(st_welcome)

	# 1. Fill cell (0, 2) = 4
	var st_f1 := TutorialStep.create(
		"sudoku_f1",
		"۱. پیدا کردن عدد گمشده (ردیف و مربع ۳×۳)",
		"توی ردیف اول اعداد ۵، ۳، ۶، ۷، ۸، ۹، ۱، ۲ وجود دارن — فقط «۴» کمه! اول عدد «۴» رو از نوار پایین انتخاب کن و بعد روی خانه خالی مشخص‌شده بزن."
	)
	st_f1.with_badge("تمرین ۱ از ۴")
	st_f1.with_hint("اول عدد ۴ رو بزن و بعد خانه خالی ردیف اول رو لمس کن")
	st_f1.with_target(func(): return _get_cell_or_digit_rect(2, 4), 8.0, 14.0)
	st_f1.with_avoid_rect(func(): return _get_board_rect())
	st_f1.with_scrim_alpha(0.50)
	st_f1.with_interactive(true, false)
	st_f1.with_placement("top")
	st_f1.with_hooks(func(): _enter_phase("fill_1"))
	s.append(st_f1)

	# 2. Fill cell (4, 4) = 5
	var st_f2 := TutorialStep.create(
		"sudoku_f2",
		"۲. مرکز جدول و تشخیص خطا (قرمز)",
		"اگر عدد تکراری بذاری، بازی با رنگ قرمز بهت هشدار می‌ده! توی مربع وسط عدد «۵» کمه. اول «۵» رو از پایین انتخاب کن و بعد خانه مرکز جدول رو بزن."
	)
	st_f2.with_badge("تمرین ۲ از ۴")
	st_f2.with_hint("اول عدد ۵ رو بزن و بعد خانه مرکز جدول رو لمس کن")
	st_f2.with_target(func(): return _get_cell_or_digit_rect(40, 5), 8.0, 14.0)
	st_f2.with_avoid_rect(func(): return _get_board_rect())
	st_f2.with_scrim_alpha(0.50)
	st_f2.with_interactive(true, false)
	st_f2.with_placement("top")
	st_f2.with_hooks(func(): _enter_phase("fill_2"))
	s.append(st_f2)

	# 3. Fill cell (8, 8) = 9
	var st_f3 := TutorialStep.create(
		"sudoku_f3",
		"۳. آخرین خانه جدول!",
		"توی ردیف آخر و مربع گوشه پایین-راست فقط عدد «۹» باقی مونده! اول «۹» رو از پایین انتخاب کن و بعد خانه خالی گوشه رو بزن."
	)
	st_f3.with_badge("تمرین ۳ از ۴")
	st_f3.with_hint("اول عدد ۹ رو بزن و بعد خانه گوشه پایین-راست رو لمس کن")
	st_f3.with_target(func(): return _get_cell_or_digit_rect(80, 9), 8.0, 14.0)
	st_f3.with_avoid_rect(func(): return _get_board_rect())
	st_f3.with_scrim_alpha(0.50)
	st_f3.with_interactive(true, false)
	st_f3.with_placement("top")
	st_f3.with_hooks(func(): _enter_phase("fill_3"))
	s.append(st_f3)

	# 4. Tap Solve button in bottom dock
	var st_solve := TutorialStep.create(
		"sudoku_solve",
		"۴. ثبت حل جدول و پیروزی!",
		"هر ۸۱ خانه بدون تناقض پر شدن! حالا دکمه سبز «✨ بررسی و ثبت حل سودوکو» رو بزن تا جدول ثبت بشه."
	)
	st_solve.with_badge("تمرین ۴ از ۴")
	st_solve.with_hint("دکمه «بررسی و ثبت حل سودوکو» رو بزن")
	st_solve.with_target(func(): return _get_solve_ctrl(), 6.0, 14.0)
	st_solve.with_scrim_alpha(0.55)
	st_solve.with_interactive(true, false)
	st_solve.with_placement("top")
	st_solve.with_hooks(func(): _enter_phase("solve"))
	s.append(st_solve)

	# 5. Finish
	var st_done := TutorialStep.create(
		"sudoku_done",
		"پایان آموزش سودوکو",
		"آفرین! حالا قوانین سطر، ستون و مربع ۳×۳، تشخیص تناقض و ثبت حل جدول سودوکو رو کاملاً بلدی. کسی که زودتر جدول رو درست حل کنه برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _ensure_2d_view() -> void:
	var sdk := _board as TutorialSudoku3D
	if is_instance_valid(sdk):
		sdk.enable_2d_top_down_view()


func _enter_phase(p: String) -> void:
	_phase = p
	var sdk := _board as TutorialSudoku3D
	if is_instance_valid(sdk):
		sdk.enable_2d_top_down_view()
		sdk.tutorial_input_enabled = (p != "done")


func _on_cell_filled(idx: int, num: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "fill_1" and idx == 2 and num == 4:
		_phase = "wait"
		_coordinator.show_hud_toast("عالی! عدد ۴ درست بود!")
		_coordinator.advance_lesson_step()
	elif _phase == "fill_2" and idx == 40 and num == 5:
		_phase = "wait"
		_coordinator.show_hud_toast("آفرین! عدد ۵ درست بود!")
		_coordinator.advance_lesson_step()
	elif _phase == "fill_3" and idx == 80 and num == 9:
		_phase = "wait"
		_coordinator.show_hud_toast("تمام خانه‌ها پر شدن! حالا ثبت حل جدول رو بزن.")
		_coordinator.advance_lesson_step()


func _on_solved() -> void:
	if is_instance_valid(_coordinator) and _phase == "solve":
		_phase = "wait"
		_coordinator.show_hud_toast("🏆 جدول سودوکو با موفقیت حل شد!")
		_coordinator.advance_lesson_step()


func _get_cell_or_digit_rect(target_idx: int, target_digit: int) -> Variant:
	var sdk := _board as TutorialSudoku3D
	if not is_instance_valid(sdk):
		return null
	if sdk.selected_digit != target_digit:
		return sdk.get_digit_button(target_digit)
	return sdk.get_cell_screen_rect(target_idx)


func _get_solve_ctrl() -> Control:
	var sdk := _board as TutorialSudoku3D
	if is_instance_valid(sdk):
		return sdk.get_solve_button_control()
	return null


func _get_board_rect() -> Rect2:
	var sdk := _board as TutorialSudoku3D
	if is_instance_valid(sdk):
		return sdk.get_board_screen_rect()
	return Rect2()
