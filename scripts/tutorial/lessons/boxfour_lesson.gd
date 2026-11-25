class_name BoxFourTutorialLesson
extends GameTutorialLesson

## Interactive BoxFour (چهارطرفه) tutorial for the Library tab.
## Covers boosting your own orb stacks (1->2->3) and triggering a 4-way chain-reaction explosion.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/boxfour/tutorial_boxfour_3d.tscn")

var _phase: String = "" # "boost" | "explode" | "done"


func get_game_type() -> String:
	return GameTypes.BOXFOUR


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var bf := board as TutorialBoxFour3D
	if not is_instance_valid(bf):
		return
	bf.tutorial_input_enabled = false
	bf.tutorial_cell_played.connect(_on_cell_played)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"bf_welcome",
		"آموزش چهارطرفه (BoxFour)",
		"در چهارطرفه فقط می‌تونی روی خانه‌های هم‌رنگ خودت ضربه بزنی تا گوی‌ها زیاد بشن (۱ ← ۲ ← ۳). وقتی یک خانه به «۴ گوی» برسه، به ۴ طرف منفجر می‌شه و خانه‌های اطراف (حتی مال حریف!) رو تسخیر می‌کنه!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع آزمایش")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Boost center (2,2) from 2 -> 3
	var st_boost := TutorialStep.create(
		"bf_boost",
		"۱. تقویت خانه خودی تا آستانه انفجار (۳ گوی)",
		"روی خانه قرمز وسط صفحه (با ۲ گوی) ضربه بزن تا به «۳ گوی» برسه و آماده انفجار بشه!"
	)
	st_boost.with_badge("تمرین ۱ از ۲")
	st_boost.with_hint("روی خانه قرمز وسط صفحه ضربه بزن")
	st_boost.with_target(func(): return _get_cell_rect(12), 10.0, 16.0)
	st_boost.with_avoid_rect(func(): return _get_board_rect())
	st_boost.with_scrim_alpha(0.55)
	st_boost.with_interactive(true, false)
	st_boost.with_placement("top")
	st_boost.with_hooks(func(): _enter_phase("boost"))
	s.append(st_boost)

	# 2. Tap center again (3 -> 4 BOOM + Chain Reaction!)
	var st_exp := TutorialStep.create(
		"bf_explode",
		"۲. انفجار چهارطرفه و واکنش زنجیره‌ای!",
		"دوباره روی همین خانه ۳ گویی وسط ضربه بزن تا منفجر بشه، خانه ۳ گویی آبی کناریش رو تسخیر کنه و زنجیره‌وار همسایه‌ها رو هم فتح کنه!"
	)
	st_exp.with_badge("تمرین ۲ از ۲")
	st_exp.with_hint("دوباره روی خانه ۳ گویی وسط ضربه بزن")
	st_exp.with_target(func(): return _get_cell_rect(12), 10.0, 16.0)
	st_exp.with_avoid_rect(func(): return _get_board_rect())
	st_exp.with_scrim_alpha(0.55)
	st_exp.with_interactive(true, false)
	st_exp.with_placement("top")
	st_exp.with_hooks(func(): _enter_phase("explode"))
	s.append(st_exp)

	# 3. Finish
	var st_done := TutorialStep.create(
		"bf_done",
		"پایان آموزش چهارطرفه",
		"عالی بود! هر وقت تمام گوی‌های حریف از صفحه پاک و به رنگ تو تبدیل بشن، برنده‌ای!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var bf := _board as TutorialBoxFour3D
	if is_instance_valid(bf):
		bf.tutorial_input_enabled = (p != "done")


func _on_cell_played(_c: int, _r: int, _val: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "boost":
		_phase = "wait"
		_coordinator.show_hud_toast("🔥 خانه وسط به ۳ گوی رسید — آماده انفجار!")
		_coordinator.advance_lesson_step()
	elif _phase == "explode":
		_phase = "wait"
		var bf := _board as TutorialBoxFour3D
		if is_instance_valid(bf):
			bf.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("💥 انفجار زنجیره‌ای! کل منطقه تسخیر شد!")
		_coordinator.get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_cell_rect(idx: int) -> Rect2:
	var bf := _board as TutorialBoxFour3D
	if is_instance_valid(bf):
		return bf.get_cell_screen_rect(idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var bf := _board as TutorialBoxFour3D
	if is_instance_valid(bf):
		return bf.get_board_screen_rect()
	return Rect2()
