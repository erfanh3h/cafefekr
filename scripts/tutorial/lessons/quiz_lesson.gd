class_name QuizTutorialLesson
extends GameTutorialLesson

## Interactive Quiz (کوییز) tutorial for the Library tab.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/quiz/tutorial_quiz_3d.tscn")

var _phase: String = "" # "answer" | "done"


func get_game_type() -> String:
	return GameTypes.QUIZ


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var qz := board as TutorialQuiz3D
	if not is_instance_valid(qz):
		return
	qz.tutorial_input_enabled = false
	qz.tutorial_option_selected.connect(_on_option_selected)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"qz_welcome",
		"آموزش کوییز (Quiz)",
		"در کوییز ۱۰ سوال چهارگزینه‌ای هم‌زمان برای همه بازیکنان میاد. هر سوال رو درست و سریع‌تر جواب بدی امتیاز بیشتری می‌گیری!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_answer := TutorialStep.create(
		"qz_answer",
		"۱. انتخاب گزینه درست",
		"سوال روی میز نمایش داده شده و هر بازیکن جداگانه جوابش رو ثبت می‌کنه (حریف جواب تو رو نمی‌بینه). گزینه درست رو روی صفحه لمس کن!"
	)
	st_answer.with_badge("تمرین عملی")
	st_answer.with_hint("روی یکی از ۴ کلید گزینه لمس کن")
	st_answer.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_answer.with_avoid_rect(func(): return _get_board_rect())
	st_answer.with_scrim_alpha(0.55)
	st_answer.with_interactive(true, false)
	st_answer.with_placement("auto")
	st_answer.with_hooks(_enter_answer)
	s.append(st_answer)

	var st_done := TutorialStep.create(
		"qz_done",
		"کوییز رو یاد گرفتی!",
		"امتیازدهی هر سوال: جواب درست (+۱ امتیاز) • بدون پاسخ (۰ امتیاز) • جواب غلط (-۱ امتیاز منفی!). بعد از ۱۰ سوال، بیشترین امتیاز برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.75)
	s.append(st_done)

	return s


func _enter_answer() -> void:
	_phase = "answer"
	var qz := _board as TutorialQuiz3D
	if is_instance_valid(qz):
		qz.tutorial_input_enabled = true


func _on_option_selected(opt_idx: int) -> void:
	if not is_instance_valid(_coordinator) or _phase != "answer":
		return
	_phase = "done"
	var qz := _board as TutorialQuiz3D
	if is_instance_valid(qz):
		qz.tutorial_input_enabled = false
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("آفرین! جواب درست بود!" if opt_idx == 2 else "انتخاب ثبت شد! (جواب درست: تهران)")
	_coordinator.get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _get_board_rect() -> Rect2:
	var qz := _board as TutorialQuiz3D
	if is_instance_valid(qz):
		return qz.get_board_screen_rect()
	return Rect2()
