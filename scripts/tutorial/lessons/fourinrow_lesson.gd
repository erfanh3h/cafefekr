class_name FourInRowTutorialLesson
extends GameTutorialLesson

## Interactive Four-in-a-Row tutorial for the Library tab.
## Guides the player all the way to a 4-in-a-row win!

const BOARD_SCENE: PackedScene = preload("res://scenes/games/fourinrow/tutorial_four_in_row_3d.tscn")
const CENTER_COL: int = 3

var _phase: String = "" # "drop_1" | "wait_1" | "drop_2" | "wait_2" | "drop_3" | "wait_3" | "drop_4" | "done"


func get_game_type() -> String:
	return GameTypes.FOURINROW


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var fir := board as TutorialFourInRow3D
	if not is_instance_valid(fir):
		return
	fir.tutorial_input_enabled = false
	fir.tutorial_player_dropped.connect(_on_player_dropped)
	fir.tutorial_scripted_drop_finished.connect(_on_scripted_drop_finished)
	fir.tutorial_wrong_col_tapped.connect(_on_wrong_col_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"fir_welcome",
		"آموزش دوز چهارتایی",
		"در دوز چهارتایی باید مهره‌هات رو توی ستون‌ها بندازی و زودتر از حریف ۴ تا مهره هم‌رنگ رو پشت سر هم (افقی، عمودی یا مورب) ردیف کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_drop1 := TutorialStep.create(
		"fir_drop_1",
		"۱. انداختن مهره در ستون وسط",
		"مهره‌ها با جاذبه به پایین‌ترین خانه خالی هر ستون می‌افتن! ستون وسط رو لمس کن تا اولین مهره‌ات بیفته."
	)
	st_drop1.with_badge("تمرین ۱ از ۴")
	st_drop1.with_hint("روی ستون وسط لمس کن")
	st_drop1.with_target(func(): return _get_col_rect(CENTER_COL), 8.0, 18.0)
	st_drop1.with_avoid_rect(func(): return _get_board_rect())
	st_drop1.with_scrim_alpha(0.84)
	st_drop1.with_interactive(true, false)
	st_drop1.with_placement("auto")
	st_drop1.with_hooks(func(): _enter_drop("drop_1"))
	s.append(st_drop1)

	var st_drop2 := TutorialStep.create(
		"fir_drop_2",
		"۲. چیدن روی مهره قبلی",
		"دوباره ستون وسط رو بزن تا دومین مهره‌ات روی مهره قبلی بشینه!"
	)
	st_drop2.with_badge("تمرین ۲ از ۴")
	st_drop2.with_hint("دوباره ستون وسط رو لمس کن")
	st_drop2.with_target(func(): return _get_col_rect(CENTER_COL), 8.0, 18.0)
	st_drop2.with_avoid_rect(func(): return _get_board_rect())
	st_drop2.with_scrim_alpha(0.84)
	st_drop2.with_interactive(true, false)
	st_drop2.with_placement("auto")
	st_drop2.with_hooks(func(): _enter_drop("drop_2"))
	s.append(st_drop2)

	var st_drop3 := TutorialStep.create(
		"fir_drop_3",
		"۳. ساختن تهدید ۳ تایی",
		"عالیه! یک بار دیگه ستون وسط رو بزن تا ۳ تا مهره پشت سر هم بسازی و آماده بُرد بشی!"
	)
	st_drop3.with_badge("تمرین ۳ از ۴")
	st_drop3.with_hint("ستون وسط رو لمس کن")
	st_drop3.with_target(func(): return _get_col_rect(CENTER_COL), 8.0, 18.0)
	st_drop3.with_avoid_rect(func(): return _get_board_rect())
	st_drop3.with_scrim_alpha(0.84)
	st_drop3.with_interactive(true, false)
	st_drop3.with_placement("auto")
	st_drop3.with_hooks(func(): _enter_drop("drop_3"))
	s.append(st_drop3)

	var st_drop4 := TutorialStep.create(
		"fir_drop_4",
		"۴. ضربه نهایی و پیروزی!",
		"فقط یک مهره تا ۴ تایی شدن مونده! ستون وسط رو بزن تا خط پیروزی روشن بشه و بازی رو ببری!"
	)
	st_drop4.with_badge("ضربه پیروزی!")
	st_drop4.with_hint("برای بُرد، ستون وسط رو لمس کن!")
	st_drop4.with_target(func(): return _get_col_rect(CENTER_COL), 8.0, 18.0)
	st_drop4.with_avoid_rect(func(): return _get_board_rect())
	st_drop4.with_scrim_alpha(0.84)
	st_drop4.with_interactive(true, false)
	st_drop4.with_placement("auto")
	st_drop4.with_hooks(func(): _enter_drop("drop_4"))
	s.append(st_drop4)

	var st_done := TutorialStep.create(
		"fir_done",
		"ایول! ۴ تایی شدی و بُردی!",
		"ستون وسط همیشه بهترین جای شروعِ بازیه، چون بیشترین مسیرهای افقی و مورب ازش رد می‌شن. آماده رقابت شو!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.82)
	s.append(st_done)

	return s


func _enter_drop(phase_name: String) -> void:
	_phase = phase_name
	var fir := _board as TutorialFourInRow3D
	if is_instance_valid(fir):
		fir.tutorial_input_enabled = true
		fir.guided_allowed_cols = [CENTER_COL]


func _on_player_dropped(_col_idx: int) -> void:
	var fir := _board as TutorialFourInRow3D
	if not is_instance_valid(_coordinator) or not is_instance_valid(fir):
		return
	_coordinator.hide_overlay_temporarily()
	fir.tutorial_input_enabled = false
	if _phase == "drop_1":
		_phase = "wait_1"
		_coordinator.show_hud_toast("عالی! حالا نوبت حریفه...")
		fir.trigger_scripted_drop(2, 0.75)
	elif _phase == "drop_2":
		_phase = "wait_2"
		fir.trigger_scripted_drop(2, 0.75)
	elif _phase == "drop_3":
		_phase = "wait_3"
		_coordinator.show_hud_toast("یک قدم تا پیروزی!")
		fir.trigger_scripted_drop(2, 0.75)
	elif _phase == "drop_4":
		_phase = "done"
		_coordinator.show_hud_toast("ایول! ۴ مهره پشت سر هم!")
		_coordinator.get_tree().create_timer(1.4).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_scripted_drop_finished(_col_idx: int) -> void:
	if is_instance_valid(_coordinator) and _phase in ["wait_1", "wait_2", "wait_3"]:
		_coordinator.advance_lesson_step()


func _on_wrong_col_tapped(_col_idx: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی ستون طلایی وسط لمس کن!")


func _get_col_rect(col_idx: int) -> Rect2:
	var fir := _board as TutorialFourInRow3D
	if is_instance_valid(fir):
		return fir.get_column_screen_rect(col_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var fir := _board as TutorialFourInRow3D
	if is_instance_valid(fir):
		return fir.get_board_screen_rect()
	return Rect2()
