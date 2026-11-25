class_name MNumbersTutorialLesson
extends GameTutorialLesson

## Interactive Match Numbers (کشف اعداد) tutorial for the Library tab.
## Covers flipping two mismatched tiles (memorize & flip back) and two matching tiles (+1 point + bonus turn).

const BOARD_SCENE: PackedScene = preload("res://scenes/games/mnumbers/tutorial_mnumbers_3d.tscn")

var _phase: String = "" # "mis_1" | "mis_2" | "mat_1" | "mat_2" | "done"


func get_game_type() -> String:
	return GameTypes.MNUMBERS


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var mn := board as TutorialMNumbers3D
	if not is_instance_valid(mn):
		return
	mn.tutorial_input_enabled = false
	mn.tutorial_tile_flipped.connect(_on_tile_flipped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"mn_welcome",
		"آموزش کشف اعداد (Match Numbers)",
		"توی صفحه ۳۶ کاشی پنهان با ۱۸ جفت عدد وجود داره! هر نوبت ۲ کاشی برمی‌گردونی: اگه هم‌شماره باشن ۱ امتیاز می‌گیری و دوباره نوبت توئه؛ اگه نه، برمی‌گردن و نوبت حریف می‌شه."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع کشف")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Flip first tile (0 -> 7)
	var st_m1 := TutorialStep.create(
		"mn_mis1",
		"۱. برگرداندن کاشی اول",
		"روی کاشی مشخص‌شده گوشه بالا-چپ بزن تا عددش رو ببینی و به خاطر بسپاری!"
	)
	st_m1.with_badge("تمرین ۱ از ۴")
	st_m1.with_hint("کاشی مشخص‌شده رو لمس کن")
	st_m1.with_target(func(): return _get_tile_rect(0), 8.0, 14.0)
	st_m1.with_avoid_rect(func(): return _get_board_rect())
	st_m1.with_scrim_alpha(0.55)
	st_m1.with_interactive(true, false)
	st_m1.with_placement("top")
	st_m1.with_hooks(func(): _enter_phase("mis_1"))
	s.append(st_m1)

	# 2. Flip second tile (1 -> 4, mismatch!)
	var st_m2 := TutorialStep.create(
		"mn_mis2",
		"۲. کاشی دوم و قانون عدم تطابق",
		"عالی! عدد «۷» رو دیدی. حالا کاشی کناریش رو بزن تا ببینی وقتی دو عدد یکی نباشن چه اتفاقی می‌افته."
	)
	st_m2.with_badge("تمرین ۲ از ۴")
	st_m2.with_hint("کاشی کناری رو لمس کن")
	st_m2.with_target(func(): return _get_tile_rect(1), 8.0, 14.0)
	st_m2.with_avoid_rect(func(): return _get_board_rect())
	st_m2.with_scrim_alpha(0.55)
	st_m2.with_interactive(true, false)
	st_m2.with_placement("top")
	st_m2.with_hooks(func(): _enter_phase("mis_2"))
	s.append(st_m2)

	# 3. Flip matching pair: tile 0 again (7)
	var st_mat1 := TutorialStep.create(
		"mn_mat1",
		"۳. استفاده از حافظه: انتخاب جفت اول",
		"دیدی کاشی‌ها برگشتن! حالا که می‌دونی کاشی اول «۷» هست، دوباره روش بزن!"
	)
	st_mat1.with_badge("تمرین ۳ از ۴")
	st_mat1.with_hint("کاشی «۷» رو لمس کن")
	st_mat1.with_target(func(): return _get_tile_rect(0), 8.0, 14.0)
	st_mat1.with_avoid_rect(func(): return _get_board_rect())
	st_mat1.with_scrim_alpha(0.55)
	st_mat1.with_interactive(true, false)
	st_mat1.with_placement("top")
	st_mat1.with_hooks(func(): _enter_phase("mat_1"))
	s.append(st_mat1)

	# 4. Flip matching pair: tile 2 (7 -> Match!)
	var st_mat2 := TutorialStep.create(
		"mn_mat2",
		"۴. کشف جفت و نوبت جایزه!",
		"حالا کاشی سوم رو بزن تا «۷» جفت بشه، +۱ امتیاز بگیری و نوبت جایزه هم مال خودت بمونه!"
	)
	st_mat2.with_badge("تمرین ۴ از ۴")
	st_mat2.with_hint("کاشی سوم رو لمس کن")
	st_mat2.with_target(func(): return _get_tile_rect(2), 8.0, 14.0)
	st_mat2.with_avoid_rect(func(): return _get_board_rect())
	st_mat2.with_scrim_alpha(0.55)
	st_mat2.with_interactive(true, false)
	st_mat2.with_placement("top")
	st_mat2.with_hooks(func(): _enter_phase("mat_2"))
	s.append(st_mat2)

	# 5. Finish
	var st_done := TutorialStep.create(
		"mn_done",
		"پایان آموزش کشف اعداد",
		"آفرین! هر کی در پایان ۱۸ جفت امتیاز بیشتری جمع کنه برنده‌ست. به حرکات حریف هم خوب دقت کن!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var mn := _board as TutorialMNumbers3D
	if is_instance_valid(mn):
		mn.tutorial_input_enabled = (p != "done")


func _on_tile_flipped(_idx: int, is_first: bool, is_match: bool) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "mis_1" and is_first:
		_phase = "wait"
		_coordinator.advance_lesson_step()
	elif _phase == "mis_2" and not is_first:
		_phase = "wait"
		_coordinator.show_hud_toast("جفت نشد! کاشی‌ها برمی‌گردن — ولی جاشون یادت موند!")
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "mat_1" and is_first:
		_phase = "wait"
		_coordinator.advance_lesson_step()
	elif _phase == "mat_2" and not is_first and is_match:
		_phase = "wait"
		_coordinator.show_hud_toast("🎉 جفت کشف شد! +۱ امتیاز + نوبت جایزه!")
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_tile_rect(idx: int) -> Rect2:
	var mn := _board as TutorialMNumbers3D
	if is_instance_valid(mn):
		return mn.get_tile_screen_rect(idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var mn := _board as TutorialMNumbers3D
	if is_instance_valid(mn):
		return mn.get_board_screen_rect()
	return Rect2()
