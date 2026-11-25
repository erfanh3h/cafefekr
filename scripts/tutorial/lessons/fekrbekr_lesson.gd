class_name FekrBekrTutorialLesson
extends GameTutorialLesson

## Interactive FekrBekr (فکر بکر / Mastermind) tutorial for the Library tab.
## Covers Phase 1 (setting a 4-color non-repeating secret code) and Phase 2
## (submitting guesses and reading Black exact / White color-only feedback pins).

const BOARD_SCENE: PackedScene = preload("res://scenes/games/fekrbekr/tutorial_fekrbekr_3d.tscn")

var _phase: String = "" # "secret" | "guess_1" | "guess_2" | "done"


func get_game_type() -> String:
	return GameTypes.FEKRBEKR


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var fb := board as TutorialFekrBekr3D
	if not is_instance_valid(fb):
		return
	fb.tutorial_input_enabled = false
	fb.tutorial_secret_set.connect(_on_secret_set)
	fb.tutorial_guess_submitted.connect(_on_guess_submitted)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"fb_welcome",
		"آموزش فکر بکر (FekrBekr)",
		"هدف فکر بکر کشف رمز ۴ رنگِ غیرتکراری حریف در حداکثر ۱۲ حرکت است!\n• پین ⚫ سیاه: رنگ درست + جای درست\n• پین ⚪ سفید: رنگ درست ولی جای اشتباه\n• خالی: رنگ اصلاً توی رمز نیست!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("انتخاب رمز مخفی")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Phase 1: Set secret code
	var st_secret := TutorialStep.create(
		"fb_secret",
		"۱. مرحله اول: ساخت رمز ۴ رنگی خودت",
		"۴ رنگ مختلف رو از سینی پایین روی ۴ جایگاه بالای تخته بگذار (یا بکش) تا رمز مخفی تو ساخته بشه، بعد دکمه «✅ ثبت رمز» رو بزن!"
	)
	st_secret.with_badge("تمرین ۱ از ۳")
	st_secret.with_hint("۴ رنگ غیرتکراری انتخاب کن و «ثبت رمز» رو بزن")
	st_secret.with_target(func(): return _get_board_or_submit(), 8.0, 14.0)
	st_secret.with_avoid_rect(func(): return _get_board_rect())
	st_secret.with_scrim_alpha(0.45)
	st_secret.with_interactive(true, false)
	st_secret.with_placement("top")
	st_secret.with_hooks(func(): _enter_phase("secret"))
	s.append(st_secret)

	# 2. Phase 2: First Guess -> see Black/White pins
	var st_g1 := TutorialStep.create(
		"fb_guess_1",
		"۲. اولین حدس و خواندن پین‌های راهنما",
		"حالا نوبت کشف رمز حریفه! از پالت پایین ۴ رنگ غیرتکراری انتخاب کن تا توی باکس «حدس فعلی» بالای اون قرار بگیرن، بعد «✅ ثبت حدس» رو بزن تا پین‌های ⚫ سیاه و ⚪ سفید وضعیت هر مهره رو نشون بدن!"
	)
	st_g1.with_badge("تمرین ۲ از ۳")
	st_g1.with_hint("۴ رنگ از پایین انتخاب کن تا در «حدس فعلی» بشینن و ثبت رو بزن")
	st_g1.with_target(func(): return _get_guess_input_or_submit(false), 10.0, 16.0)
	st_g1.with_avoid_rect(func(): return _get_board_rect())
	st_g1.with_scrim_alpha(0.45)
	st_g1.with_interactive(true, false)
	st_g1.with_placement("top")
	st_g1.with_hooks(func(): _enter_phase("guess_1"))
	s.append(st_g1)

	# 3. Phase 2: Second Guess using Black/White feedback pins
	var st_g2 := TutorialStep.create(
		"fb_guess_2",
		"۳. تحلیل پین سیاه و سفید (رمز آزمایشی: ۴ رنگ اول!)",
		"نکته حرفه‌ای: ترتیب پین‌های سیاه و سفید با جای مهره‌ها یکی نیست — پین ⚫ سیاه یعنی تعداد مهره‌هایی که هم رنگ و هم جاشون درسته، و پین ⚪ سفید یعنی رنگشون درسته ولی جاشون نه! حدس دوم رو بچین (رمز تمرینی: ۴ رنگ اول از چپ)."
	)
	st_g2.with_badge("تمرین ۳ از ۳")
	st_g2.with_hint("حدس دوم رو بچین و «ثبت حدس» رو بزن")
	st_g2.with_target(func(): return _get_guess_input_or_submit(true), 10.0, 16.0)
	st_g2.with_avoid_rect(func(): return _get_board_rect())
	st_g2.with_scrim_alpha(0.45)
	st_g2.with_interactive(true, false)
	st_g2.with_placement("top")
	st_g2.with_hooks(func(): _enter_phase("guess_2"))
	s.append(st_g2)

	# 4. Finish
	var st_done := TutorialStep.create(
		"fb_done",
		"پایان آموزش فکر بکر",
		"آفرین! حالا چیدن رمز غیرتکراری و کشف رمز حریف با تحلیل پین‌های سیاه و سفید رو بلدی. هر کی زودتر رمز حریف رو بشکنه برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var fb := _board as TutorialFekrBekr3D
	if is_instance_valid(fb):
		fb.tutorial_input_enabled = (p != "done")
		if p == "guess_1" or p == "guess_2":
			fb.ensure_my_board_view()


func _on_secret_set(_secret: Array) -> void:
	if is_instance_valid(_coordinator) and _phase == "secret":
		_phase = "wait"
		_coordinator.show_hud_toast("🔐 رمز ثبت شد! حالا بریم سراغ کشف رمز حریف.")
		_coordinator.advance_lesson_step()


func _on_guess_submitted(_guess: Array, fb_pins: Array, cracked: bool) -> void:
	if not is_instance_valid(_coordinator):
		return
	var blacks: int = fb_pins.count(2)
	var whites: int = fb_pins.count(1)
	if _phase == "guess_1":
		_phase = "wait"
		_coordinator.show_hud_toast("نتیجه: %d ⚫ سیاه  |  %d ⚪ سفید" % [blacks, whites])
		_coordinator.advance_lesson_step()
	elif _phase == "guess_2":
		_phase = "wait"
		_coordinator.show_hud_toast("🎉 رمز شکسته شد!" if cracked else "نتیجه: %d ⚫ سیاه  |  %d ⚪ سفید" % [blacks, whites])
		_coordinator.advance_lesson_step()


func _get_board_or_submit() -> Variant:
	var fb := _board as TutorialFekrBekr3D
	if not is_instance_valid(fb):
		return null
	if fb.has_full_selection():
		var btn: Control = fb.get_submit_button_control()
		if is_instance_valid(btn):
			return btn
	return fb.get_board_screen_rect()


func _get_guess_input_or_submit(include_first_row: bool) -> Variant:
	var fb := _board as TutorialFekrBekr3D
	if not is_instance_valid(fb):
		return null
	if fb.has_full_selection():
		var btn: Control = fb.get_submit_button_control()
		if is_instance_valid(btn):
			return btn
	return fb.get_phase2_input_rect(include_first_row)


func _get_board_rect() -> Rect2:
	var fb := _board as TutorialFekrBekr3D
	if is_instance_valid(fb):
		return fb.get_board_screen_rect()
	return Rect2()
