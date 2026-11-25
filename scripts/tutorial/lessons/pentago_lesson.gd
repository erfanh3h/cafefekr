class_name PentagoTutorialLesson
extends GameTutorialLesson

## Interactive Pentago (پنتاگو) tutorial for the Library tab.
## Covers 2 full turns:
##   Turn 1: Place marble -> Rotate any quadrant
##   Turn 2: Strategic 5-in-a-row win by placing at Q1 center (10) & rotating Q1!

const BOARD_SCENE: PackedScene = preload("res://scenes/games/pentago/tutorial_pentago_3d.tscn")
const CELL_PLACE_1: int = 0
const CELL_WIN_PLACE: int = 13 # Center of Q1 (9 + 4)

var _phase: String = "" # "place_1" | "rotate_1" | "win_preview" | "place_2" | "rotate_2" | "done"


func get_game_type() -> String:
	return GameTypes.PENTAGO


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var pen := board as TutorialPentago3D
	if not is_instance_valid(pen):
		return
	pen.tutorial_input_enabled = false
	pen.tutorial_marble_placed.connect(_on_marble_placed)
	pen.tutorial_quadrant_rotated.connect(_on_quadrant_rotated)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"pen_welcome",
		"آموزش پنتاگو (Pentago)",
		"در پنتاگو هر نوبت دو کار می‌کنی: اول یک گوی می‌ذاری، بعد یکی از ۴ صفحه ۳×۳ رو ۹۰ درجه می‌چرخونی! هرکی ۵ تا گوی هم‌رنگ رو پشت سر هم ردیف کنه برنده‌ست."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_place1 := TutorialStep.create(
		"pen_place_1",
		"۱. گذاشتن گوی",
		"اولین مرحله نوبتت گذاشتن گوی روی یک خانه خالیه. روی خانه مشخص‌شده در گوشه بالا لمس کن!"
	)
	st_place1.with_badge("تمرین ۱ از ۴")
	st_place1.with_hint("روی خانه طلایی لمس کن")
	st_place1.with_target(func(): return _get_cell_rect(CELL_PLACE_1), 4.0, 14.0)
	st_place1.with_avoid_rect(func(): return _get_board_rect())
	st_place1.with_scrim_alpha(0.75)
	st_place1.with_interactive(true, false)
	st_place1.with_placement("auto")
	st_place1.with_hooks(_enter_place_1)
	s.append(st_place1)

	var st_rotate1 := TutorialStep.create(
		"pen_rotate_1",
		"۲. چرخاندن یکی از ۴ صفحه!",
		"حالا دستگیره‌های چرخش دور تخته روشن شدن! یکی از فلش‌های چرخش دور صفحه رو لمس کن تا اون بخش ۹۰ درجه بچرخه."
	)
	st_rotate1.with_badge("تمرین ۲ از ۴")
	st_rotate1.with_hint("یکی از دستگیره‌های چرخش کنار صفحه رو بزن")
	st_rotate1.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_rotate1.with_avoid_rect(func(): return _get_board_rect())
	st_rotate1.with_scrim_alpha(0.58)
	st_rotate1.with_interactive(true, false)
	st_rotate1.with_placement("auto")
	st_rotate1.with_hooks(_enter_rotate_1)
	s.append(st_rotate1)

	var st_place2 := TutorialStep.create(
		"pen_place_2",
		"۳. ساختن ردیف ۵ تایی با چرخش!",
		"ببین ۳ تا گوی ردیف داری! گوی جدید رو وسط صفحه بالا-راست بذار تا با چرخش بعدی، ۵ تا گوی پشت سر هم بسازی!"
	)
	st_place2.with_badge("تمرین ۳ از ۴")
	st_place2.with_hint("روی خانه وسط صفحه بالا-راست لمس کن")
	st_place2.with_target(func(): return _get_cell_rect(CELL_WIN_PLACE), 4.0, 14.0)
	st_place2.with_avoid_rect(func(): return _get_board_rect())
	st_place2.with_scrim_alpha(0.65)
	st_place2.with_interactive(true, false)
	st_place2.with_placement("auto")
	st_place2.with_hooks(_enter_win_place)
	s.append(st_place2)

	var st_rotate2 := TutorialStep.create(
		"pen_rotate_2",
		"۴. چرخش نهایی و پیروزی!",
		"حالا دستگیره چرخشِ مشخص‌شده روی صفحه بالا-راست رو بزن تا هر ۵ گوی توی یک خط قرار بگیرن و برنده بشی!"
	)
	st_rotate2.with_badge("تمرین ۴ از ۴")
	st_rotate2.with_hint("دستگیره چرخش طلایی رو بزن!")
	st_rotate2.with_target(func(): return _get_rot_rect(3), 10.0, 16.0)
	st_rotate2.with_avoid_rect(func(): return _get_board_rect())
	st_rotate2.with_scrim_alpha(0.55)
	st_rotate2.with_interactive(true, false)
	st_rotate2.with_placement("auto")
	st_rotate2.with_hooks(_enter_rotate_2)
	s.append(st_rotate2)

	var st_done := TutorialStep.create(
		"pen_done",
		"پنتاگو رو کامل یاد گرفتی!",
		"یادت باشه هم خودت می‌تونی با چرخش، ردیف ۵ تایی بسازی و هم می‌تونی ردیف حریف رو خراب کنی. آماده رقابت شو!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.65)
	s.append(st_done)

	return s


func _enter_place_1() -> void:
	_phase = "place_1"
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		pen.tutorial_input_enabled = true
		pen.guided_allowed_cells = [CELL_PLACE_1]


func _enter_rotate_1() -> void:
	_phase = "rotate_1"
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		pen.tutorial_input_enabled = true
		pen.guided_allowed_cells.clear()
		pen.guided_allowed_rotations.clear()


func _enter_win_place() -> void:
	_phase = "win_preview"
	var pen := _board as TutorialPentago3D
	if not is_instance_valid(pen):
		return
	pen.tutorial_input_enabled = false
	pen.setup_winning_rotation_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("حالا ببین چطور با یک چرخش، ۵ تایی می‌سازیم...")
	_coordinator.get_tree().create_timer(1.6).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(pen) or _phase != "win_preview":
			return
		_phase = "place_2"
		pen.tutorial_input_enabled = true
		pen.guided_allowed_cells = [CELL_WIN_PLACE]
		_coordinator.reshow_current_step()
	)


func _enter_rotate_2() -> void:
	_phase = "rotate_2"
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		pen.tutorial_input_enabled = true
		pen.guided_allowed_cells.clear()
		pen.guided_allowed_rotations = [3]


func _on_marble_placed(_cell_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "place_1" or _phase == "place_2":
		_coordinator.advance_lesson_step()


func _on_quadrant_rotated(_rot_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var pen := _board as TutorialPentago3D
	if _phase == "rotate_1":
		_phase = "wait_1"
		if is_instance_valid(pen):
			pen.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("عالی! صفحه چرخید!")
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "rotate_2":
		_phase = "done"
		if is_instance_valid(pen):
			pen.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("فوق‌العاده! ۵ گوی در یک خط و پیروزی!")
		_coordinator.get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_rot_rect(rot_id: int) -> Rect2:
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		return pen.get_rotation_paddle_screen_rect(rot_id)
	return Rect2()


func _get_cell_rect(cell_id: int) -> Rect2:
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		return pen.get_cell_screen_rect(cell_id)
	return Rect2()


func _get_board_rect() -> Rect2:
	var pen := _board as TutorialPentago3D
	if is_instance_valid(pen):
		return pen.get_board_screen_rect()
	return Rect2()
