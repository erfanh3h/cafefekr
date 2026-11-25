class_name DotBoxTutorialLesson
extends GameTutorialLesson

## Interactive DotBox (نقطه خط) tutorial for the Library tab.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/dotbox/tutorial_dotbox_3d.tscn")
const LINE_FIRST: int = 1
const LINE_CLOSE_BOX: int = 11

var _phase: String = "" # "draw_1" | "close_box" | "done"


func get_game_type() -> String:
	return GameTypes.DOTBOX


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var db := board as TutorialDotBox3D
	if not is_instance_valid(db):
		return
	db.tutorial_input_enabled = false
	db.tutorial_line_drawn.connect(_on_line_drawn)
	db.tutorial_wrong_line_tapped.connect(_on_wrong_line_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"db_welcome",
		"آموزش نقطه خط (DotBox)",
		"در نقطه خط به نوبت بین دو نقطه خط می‌کشید. هرکی چهارمین ضلع یک مربع رو ببنده، اون مربع مال خودشه و یک نوبت جایزه می‌گیره!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_draw1 := TutorialStep.create(
		"db_draw_1",
		"۱. کشیدن خط بین دو نقطه",
		"روی یکی از مسیرهای خط‌چین لمس کن تا خط کشیده بشه. الان خط طلایی مشخص‌شده رو لمس کن!"
	)
	st_draw1.with_badge("تمرین ۱ از ۲")
	st_draw1.with_hint("روی خط طلایی لمس کن")
	st_draw1.with_target(func(): return _get_line_rect(LINE_FIRST), 8.0, 14.0)
	st_draw1.with_avoid_rect(func(): return _get_board_rect())
	st_draw1.with_scrim_alpha(0.84)
	st_draw1.with_interactive(true, false)
	st_draw1.with_placement("auto")
	st_draw1.with_hooks(_enter_draw_1)
	s.append(st_draw1)

	var st_close := TutorialStep.create(
		"db_close_box",
		"۲. بستن مربع و گرفتن امتیاز!",
		"این مربع ۳ ضلعش پر شده! با کشیدن ضلع چهارم، مربع رو تصاحب می‌کنی و یک حرکتِ اضافه جایزه می‌گیری. ببندش!"
	)
	st_close.with_badge("تمرین ۲ از ۲")
	st_close.with_hint("ضلع چهارم مربع رو بکش!")
	st_close.with_target(func(): return _get_line_rect(LINE_CLOSE_BOX), 8.0, 14.0)
	st_close.with_avoid_rect(func(): return _get_board_rect())
	st_close.with_scrim_alpha(0.75)
	st_close.with_interactive(true, false)
	st_close.with_placement("auto")
	st_close.with_hooks(_enter_close_box)
	s.append(st_close)

	var st_done := TutorialStep.create(
		"db_done",
		"نقطه خط رو یاد گرفتی!",
		"یادت باشه: خط سومِ یک مربع رو نکش مگه مجبور باشی، چون حریف راحت مربع رو می‌بنده! هرکی مربع بیشتری ببنده برنده‌ست."
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.75)
	s.append(st_done)

	return s


func _enter_draw_1() -> void:
	_phase = "draw_1"
	var db := _board as TutorialDotBox3D
	if is_instance_valid(db):
		db.tutorial_input_enabled = true
		db.guided_allowed_lines = [LINE_FIRST]


func _enter_close_box() -> void:
	_phase = "close_preview"
	var db := _board as TutorialDotBox3D
	if not is_instance_valid(db):
		return
	db.tutorial_input_enabled = false
	db.setup_box_completion_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("ببین! یک مربع ۳ ضلعش پر شده و آماده بسته شدنه...")
	_coordinator.get_tree().create_timer(1.5).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(db) or _phase != "close_preview":
			return
		_phase = "close_box"
		db.tutorial_input_enabled = true
		db.guided_allowed_lines = [LINE_CLOSE_BOX]
		_coordinator.reshow_current_step()
	)


func _on_line_drawn(line_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var db := _board as TutorialDotBox3D
	if _phase == "draw_1" and line_id == LINE_FIRST:
		if is_instance_valid(db):
			db.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "close_box" and line_id == LINE_CLOSE_BOX:
		_phase = "done"
		if is_instance_valid(db):
			db.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("ایول! مربع رو بستی و ۱ امتیاز گرفتی!")
		_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_wrong_line_tapped(_line_id: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی خط طلایی مشخص‌شده لمس کن!")


func _get_line_rect(line_id: int) -> Rect2:
	var db := _board as TutorialDotBox3D
	if is_instance_valid(db):
		return db.get_line_screen_rect(line_id)
	return Rect2()


func _get_board_rect() -> Rect2:
	var db := _board as TutorialDotBox3D
	if is_instance_valid(db):
		return db.get_board_screen_rect()
	return Rect2()
