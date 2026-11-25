class_name YatzyTutorialLesson
extends GameTutorialLesson

## Interactive Yatzy (یاتزی) tutorial for the Library tab.
## Covers:
##   1. Rolling 5 dice
##   2. Holding all three 6s (highlighted together; user taps each to lock)
##   3. Re-rolling remaining dice
##   4. Left column (1..6 + 63 bonus) highlighted all at once
##   5. Right column (categories 6..11) highlighted one by one
##   6. Selecting a category on the 3D table & submitting score

const BOARD_SCENE: PackedScene = preload("res://scenes/games/yatzy/tutorial_yatzy_3d.tscn")

var _phase: String = "" # "roll_1" | "hold" | "roll_2" | "select_cat" | "submit" | "done"


func get_game_type() -> String:
	return GameTypes.YATZY


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var yat := board as TutorialYatzy3D
	if not is_instance_valid(yat):
		return
	yat.tutorial_input_enabled = false
	yat.tutorial_dice_rolled.connect(_on_dice_rolled)
	yat.tutorial_die_toggled.connect(_on_die_toggled)
	yat.tutorial_three_sixes_held.connect(_on_three_sixes_held)
	yat.tutorial_category_selected.connect(_on_category_selected)
	yat.tutorial_score_submitted.connect(_on_score_submitted)
	if is_instance_valid(coordinator) and coordinator.has_method("zoom_table_in"):
		coordinator.zoom_table_in(2)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"yat_welcome",
		"آموزش یاتزی (Yatzy)",
		"در یاتزی ۱۲ راند بازی می‌کنید. هر نوبت تا ۳ بار می‌تونی ۵ تا تاس رو بریزی، تاس‌های خوب رو نگه داری و بهترین ترکیب رو توی جدول امتیازات ثبت کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع تمرین")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Roll 1
	var st_roll1 := TutorialStep.create(
		"yat_roll_1",
		"۱. اولین پرتاب تاس",
		"دکمه «پرتاب تاس» پایین صفحه رو بزن تا ۵ تا تاس ریخته بشن!"
	)
	st_roll1.with_badge("تمرین ۱ از ۵")
	st_roll1.with_hint("روی دکمه پرتاب تاس لمس کن")
	st_roll1.with_target(func(): return _get_roll_btn(), 8.0, 16.0)
	st_roll1.with_scrim_alpha(0.82)
	st_roll1.with_interactive(true, false)
	st_roll1.with_placement("top")
	st_roll1.with_hooks(_enter_roll_1)
	s.append(st_roll1)

	# 2. Hold the three 6s!
	var st_hold := TutorialStep.create(
		"yat_hold",
		"۲. نگه داشتن سه تاسِ ۶!",
		"عالیه! ۳ تا ۶ اومد. روی هر ۳ تا تاسِ ۶ لمس کن تا قفل طلایی بشن و توی پرتاب بعدی ثابت بمونن!"
	)
	st_hold.with_badge("تمرین ۲ از ۵")
	st_hold.with_hint("هر ۳ تاس ۶ مشخص‌شده رو لمس کن")
	st_hold.with_target(func(): return _get_three_sixes_rect(), 8.0, 16.0)
	st_hold.with_avoid_rect(func(): return _get_board_rect())
	st_hold.with_scrim_alpha(0.75)
	st_hold.with_interactive(true, false)
	st_hold.with_placement("auto")
	st_hold.with_hooks(_enter_hold)
	s.append(st_hold)

	# 3. Roll 2
	var st_roll2 := TutorialStep.create(
		"yat_roll_2",
		"۳. پرتاب مجدد بقیه تاس‌ها",
		"ایول! حالا دکمه «پرتاب تاس» رو بزن تا ۲ تاس آزاد دوباره ریخته بشن!"
	)
	st_roll2.with_badge("تمرین ۳ از ۵")
	st_roll2.with_hint("دوباره پرتاب تاس رو بزن")
	st_roll2.with_target(func(): return _get_roll_btn(), 8.0, 16.0)
	st_roll2.with_scrim_alpha(0.82)
	st_roll2.with_interactive(true, false)
	st_roll2.with_placement("top")
	st_roll2.with_hooks(_enter_roll_2)
	s.append(st_roll2)

	# 4. Left Column (all 6 rows highlighted at once)
	var st_left_col := TutorialStep.create(
		"yat_left_col",
		"ستون چپ: اعداد ۱ تا ۶",
		"توی این ۶ خانه، مجموع تاس‌های همون عدد حساب می‌شه (مثلاً ۴ تا ۶ = ۲۴ امتیاز). نکته مهم: اگر جمع امتیاز این ۶ خانه به ۶۳ یا بیشتر برسه، ۳۵ امتیاز جایزه می‌گیری!"
	)
	st_left_col.with_badge("قوانین جدول (ستون چپ)")
	st_left_col.with_cta("بعدی")
	st_left_col.with_target(func(): return _get_left_col_rect(), 8.0, 14.0)
	st_left_col.with_avoid_rect(func(): return _get_board_rect())
	st_left_col.with_scrim_alpha(0.68)
	st_left_col.with_placement("auto")
	s.append(st_left_col)

	# 5..10. Right Column — one by one!
	var right_items: Array[Dictionary] = [
		{"idx": 6, "title": "ستون راست: سه‌تایی", "body": "اگر حداقل ۳ تا تاس هم‌عدد داشته باشی، مجموع تمام ۵ تاس برات ثبت می‌شه!"},
		{"idx": 7, "title": "ستون راست: چهارتایی", "body": "اگر حداقل ۴ تا تاس هم‌عدد داشته باشی، مجموع تمام ۵ تاس امتیاز می‌گیری!"},
		{"idx": 8, "title": "ستون راست: شانس", "body": "بدون هیچ شرطی! مجموع کل ۵ تاس حساب می‌شه (وقتی ترکیب خاصی نیومد عالیه)."},
		{"idx": 9, "title": "ستون راست: فول‌هاوس", "body": "۳ تاس از یک عدد + ۲ تاس از عدد دیگه (مثلاً سه تا ۶ و دو تا ۲) = ۲۵ امتیاز ثابت!"},
		{"idx": 10, "title": "ستون راست: ردیف بزرگ", "body": "۵ عدد پشت سر هم (۱ تا ۵ یا ۲ تا ۶) = ۴۰ امتیاز ثابت!"},
		{"idx": 11, "title": "ستون راست: یاتزی!", "body": "هر ۵ تاس کاملاً هم‌عدد باشن (مثل الان که ۵ تا ۶ داری!) = ۵۰ امتیاز طلایی!"},
	]
	for item in right_items:
		var c_idx: int = int(item["idx"])
		var st_r := TutorialStep.create(
			"yat_right_%d" % c_idx,
			str(item["title"]),
			str(item["body"])
		)
		st_r.with_badge("قوانین جدول (ستون راست)")
		st_r.with_cta("بعدی")
		st_r.with_target(func(): return _get_cat_rect(c_idx), 6.0, 12.0)
		st_r.with_avoid_rect(func(): return _get_board_rect())
		st_r.with_scrim_alpha(0.68)
		st_r.with_placement("auto")
		s.append(st_r)

	# 11. Select Category on 3D Table (specifically Yatzy row 11!)
	var st_select_cat := TutorialStep.create(
		"yat_select_cat",
		"۴. انتخاب ردیف یاتزی (۵۰ امتیاز)!",
		"الان ۵ تا ۶ داری! روی ردیف «یاتزی» مشخص‌شده لمس کن تا ۵۰ امتیاز برات انتخاب بشه."
	)
	st_select_cat.with_badge("تمرین ۴ از ۵")
	st_select_cat.with_hint("روی ردیف یاتزی لمس کن")
	st_select_cat.with_target(func(): return _get_cat_rect(11), 6.0, 12.0)
	st_select_cat.with_avoid_rect(func(): return _get_board_rect())
	st_select_cat.with_scrim_alpha(0.60)
	st_select_cat.with_interactive(true, false)
	st_select_cat.with_placement("auto")
	st_select_cat.with_hooks(_enter_select_cat)
	s.append(st_select_cat)

	# 12. Submit Score
	var st_submit := TutorialStep.create(
		"yat_submit",
		"۵. تایید و ثبت امتیاز!",
		"عالی! ردیف انتخاب شد. حالا دکمه «ثبت امتیاز» پایین صفحه رو بزن تا امتیازت قفل بشه و راند تمام بشه."
	)
	st_submit.with_badge("تمرین ۵ از ۵")
	st_submit.with_hint("روی دکمه ثبت امتیاز پایین صفحه لمس کن")
	st_submit.with_target(func(): return _get_submit_btn(), 8.0, 16.0)
	st_submit.with_scrim_alpha(0.75)
	st_submit.with_interactive(true, false)
	st_submit.with_placement("top")
	st_submit.with_hooks(_enter_submit)
	s.append(st_submit)

	# 13. Done
	var st_done := TutorialStep.create(
		"yat_done",
		"یاتزی رو کامل یاد گرفتی!",
		"در پایان ۱۲ راند، هرکی جمع امتیازش بیشتر باشه برنده‌ست. آماده رقابت شو!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.75)
	s.append(st_done)

	return s


func _enter_roll_1() -> void:
	_phase = "roll_1"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.guided_allowed_dice.clear()
		yat.tutorial_input_enabled = true


func _enter_hold() -> void:
	_phase = "hold"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.guided_allowed_dice = [0, 1, 2]
		yat.tutorial_input_enabled = true


func _enter_roll_2() -> void:
	_phase = "roll_2"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.guided_allowed_dice.clear()
		yat.tutorial_input_enabled = true


func _enter_select_cat() -> void:
	_phase = "select_cat"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.guided_allowed_dice.clear()
		yat.guided_allowed_category = 11
		yat.tutorial_input_enabled = true


func _enter_submit() -> void:
	_phase = "submit"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.guided_allowed_category = -1
		yat.tutorial_input_enabled = true


func _on_dice_rolled(_roll_num: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var yat := _board as TutorialYatzy3D
	if _phase == "roll_1" or _phase == "roll_2":
		if is_instance_valid(yat):
			yat.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(0.95).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_die_toggled(_die_idx: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "hold":
		var yat := _board as TutorialYatzy3D
		if is_instance_valid(yat):
			var cnt: int = 0
			for idx in [0, 1, 2]:
				if idx in yat.held_dice_indices:
					cnt += 1
			if cnt < 3:
				_coordinator.show_hud_toast("عالی! %s از ۳ تاس قفل شد." % GameManager.to_fa_num(cnt))


func _on_three_sixes_held() -> void:
	if not is_instance_valid(_coordinator) or _phase != "hold":
		return
	_phase = "roll_2"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.tutorial_input_enabled = false
	_coordinator.show_hud_toast("هر ۳ تا ۶ قفل شدن!")
	_coordinator.advance_lesson_step()


func _on_category_selected(_cat_idx: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "select_cat":
		_phase = "submit"
		_coordinator.advance_lesson_step()


func _on_score_submitted(_cat_idx: int, sc: int) -> void:
	if not is_instance_valid(_coordinator) or _phase != "submit":
		return
	_phase = "done"
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		yat.tutorial_input_enabled = false
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("آفرین! %s امتیاز ثبت شد!" % GameManager.to_fa_num(sc))
	_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _get_roll_btn() -> Control:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_roll_button_control()
	return null


func _get_submit_btn() -> Control:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_submit_button_control()
	return null


func _get_three_sixes_rect() -> Rect2:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_first_three_dice_rect()
	return Rect2()


func _get_left_col_rect() -> Rect2:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_left_column_rect()
	return Rect2()


func _get_cat_rect(cat_idx: int) -> Rect2:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_category_row_rect(cat_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var yat := _board as TutorialYatzy3D
	if is_instance_valid(yat):
		return yat.get_board_screen_rect()
	return Rect2()
