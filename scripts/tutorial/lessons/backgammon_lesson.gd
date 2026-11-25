class_name BackgammonTutorialLesson
extends GameTutorialLesson

## Interactive, scenario-driven Backgammon tutorial for the Library tab.
## Visually demonstrates every core rule on the 3D board:
##   1. Rolling dice ("تاس بریز") & moving a checker
##   2. Hitting an enemy blot (تک‌مهره) & sending it to the Bar
##   3. Bringing your own hit checker back from the Bar (ستون وسط)
##   4. Gathering all checkers in the home quadrant & Bearing Off into the vault

const BOARD_SCENE: PackedScene = preload("res://scenes/games/backgammon/tutorial_backgammon_3d.tscn")

var _phase: String = "" # "roll" | "move_1" | "hit_blot" | "bar_reentry" | "bear_off" | "done"


func get_game_type() -> String:
	return GameTypes.BACKGAMMON


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var bg := board as TutorialBackGammon3D
	if not is_instance_valid(bg):
		return
	bg.tutorial_input_enabled = false
	bg.tutorial_dice_rolled.connect(_on_dice_rolled)
	bg.tutorial_piece_moved.connect(_on_piece_moved)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome
	var st_welcome := TutorialStep.create(
		"bg_welcome",
		"آموزش تخته نرد",
		"در تخته نرد باید همه ۱۵ مهره‌ات رو با تاس ریختن دور تخته بچرخونی، توی خانه خودت جمع کنی و زودتر از حریف از صفحه خارج کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع یادگیری")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 2. Roll Dice
	var st_roll := TutorialStep.create(
		"bg_roll_dice",
		"۱. تاس ریختن",
		"در شروع هر نوبت باید دکمه «تاس بریز» رو بزنی تا عدد حرکتت مشخص بشه. الان امتحانش کن!"
	)
	st_roll.with_badge("تمرین ۱ از ۴")
	st_roll.with_hint("روی دکمه تاس بریز لمس کن")
	st_roll.with_target(func(): return _get_roll_btn(), 8.0, 16.0)
	st_roll.with_scrim_alpha(0.84)
	st_roll.with_interactive(true, false)
	st_roll.with_placement("top")
	st_roll.with_hooks(_enter_roll_step)
	s.append(st_roll)

	# 3. Basic Move
	var st_move1 := TutorialStep.create(
		"bg_move_1",
		"۲. حرکت دادن مهره",
		"تاس ۳ و ۱ اومد! هر تاس یک حرکت جداست. روی یکی از مهره‌های روشن‌شده بزن تا حرکت کنه."
	)
	st_move1.with_badge("تمرین ۲ از ۴")
	st_move1.with_hint("روی یکی از مهره‌های روشن لمس کن")
	st_move1.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_move1.with_avoid_rect(func(): return _get_board_rect())
	st_move1.with_scrim_alpha(0.75)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_enter_move_1)
	s.append(st_move1)

	# 4. Scenario: Hit Enemy Blot (تک‌مهره)
	var st_hit := TutorialStep.create(
		"bg_hit_blot",
		"۳. زدن تک‌مهره حریف!",
		"ببین! حریف یک مهره تنها (تک‌مهره) گذاشته. با تاس ۳ می‌تونی بزنیش! روی مهره روشن گوشه پایین (یا هدف قرمز) بزن تا مهره حریف بره توی ستون وسط!"
	)
	st_hit.with_badge("حالت ویژه: زدن مهره")
	st_hit.with_hint("مهره حریف رو بزن!")
	st_hit.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_hit.with_avoid_rect(func(): return _get_board_rect())
	st_hit.with_scrim_alpha(0.75)
	st_hit.with_interactive(true, false)
	st_hit.with_placement("auto")
	st_hit.with_hooks(_enter_hit_blot)
	s.append(st_hit)

	# 5. Scenario: Your Checker is Hit -> Bring back from Bar!
	var st_bar := TutorialStep.create(
		"bg_bar_reentry",
		"۴. مهره‌ات زده شده! (ستون وسط)",
		"الان یکی از مهره‌های خودت وسط تخته (Bar) افتاده! تا این مهره رو برنگردونی، نمی‌تونی بقیه مهره‌ها رو تکون بدی. روی ستون وسط یا خانه روشن بزن تا برگرده!"
	)
	st_bar.with_badge("حالت ویژه: بازگشت از بار")
	st_bar.with_hint("مهره وسط تخته رو برگردون!")
	st_bar.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_bar.with_avoid_rect(func(): return _get_board_rect())
	st_bar.with_scrim_alpha(0.75)
	st_bar.with_interactive(true, false)
	st_bar.with_placement("auto")
	st_bar.with_hooks(_enter_bar_reentry)
	s.append(st_bar)

	# 6. Scenario: All Checkers in Home Quadrant -> Bear Off into Box!
	var st_bear := TutorialStep.create(
		"bg_bear_off",
		"۵. جمع‌آوری در خانه آخر و خروج به جعبه!",
		"وقتی همه مهره‌هات به ربع آخر (بالا سمت راست) برسن، دیگه می‌تونی از صفحه خارجشون کنی! روی مهره روشن یا جعبه بالای تخته بزن تا خارج بشه."
	)
	st_bear.with_badge("مرحله پایانی: خروج مهره")
	st_bear.with_hint("یک مهره رو به جعبه خارج کن!")
	st_bear.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_bear.with_avoid_rect(func(): return _get_board_rect())
	st_bear.with_scrim_alpha(0.75)
	st_bear.with_interactive(true, false)
	st_bear.with_placement("auto")
	st_bear.with_hooks(_enter_bear_off)
	s.append(st_bear)

	# 7. Doubles & Summary
	var st_done := TutorialStep.create(
		"bg_done",
		"عالی! تخته نرد رو کامل یاد گرفتی",
		"یادآوری: اگر دو تاس مثل هم بیان (جفت)، ۴ بار حرکت می‌کنی. هرکس زودتر همه ۱۵ مهره‌اش رو خارج کنه برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.82)
	s.append(st_done)

	return s


func _enter_roll_step() -> void:
	_phase = "roll"
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		bg.set_scripted_dice([3, 1])
		bg.tutorial_input_enabled = true


func _on_dice_rolled() -> void:
	if is_instance_valid(_coordinator) and _phase == "roll":
		_phase = "move_1"
		_coordinator.advance_lesson_step()


func _enter_move_1() -> void:
	_phase = "move_1"
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		bg.tutorial_input_enabled = true


func _enter_hit_blot() -> void:
	_phase = "hit_blot"
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		bg.setup_hit_blot_scenario()
		bg.tutorial_input_enabled = true


func _enter_bar_reentry() -> void:
	_phase = "bar_reentry"
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		bg.setup_bar_reentry_scenario()
		bg.tutorial_input_enabled = true


func _enter_bear_off() -> void:
	_phase = "bear_off"
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		bg.setup_bear_off_scenario()
		bg.tutorial_input_enabled = true


func _on_piece_moved(_move_count: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var bg := _board as TutorialBackGammon3D
	if _phase in ["move_1", "hit_blot", "bar_reentry", "bear_off"]:
		var finished_phase: String = _phase
		_phase = "wait_anim"
		if is_instance_valid(bg):
			bg.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		if finished_phase == "hit_blot":
			_coordinator.show_hud_toast("ایول! تک‌مهره حریف زده شد و رفت توی ستون وسط!")
		elif finished_phase == "bar_reentry":
			_coordinator.show_hud_toast("آفرین! مهره‌ات دوباره وارد بازی شد!")
		elif finished_phase == "bear_off":
			_coordinator.show_hud_toast("عالی! مهره با موفقیت خارج شد!")
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_roll_btn() -> Control:
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		return bg.get_roll_button_control()
	return null


func _get_board_rect() -> Rect2:
	var bg := _board as TutorialBackGammon3D
	if is_instance_valid(bg):
		return bg.get_board_screen_rect()
	return Rect2()
