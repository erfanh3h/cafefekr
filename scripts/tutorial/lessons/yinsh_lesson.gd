class_name YinshTutorialLesson
extends GameTutorialLesson

## Deep interactive YINSH (یینش) tutorial for the Library tab.
## Covers Phase 1 (placing 5 Commander Rings), Phase 2A (planting a disk inside a ring),
## Phase 2B (gliding & jumping over disks to flip their colors), forming 5-in-a-row,
## and removing 1 of your own rings to score (first to 3 points wins!).

const BOARD_SCENE: PackedScene = preload("res://scenes/games/yinsh/tutorial_yinsh_3d.tscn")

var _phase: String = "" # "place" | "select_jump" | "move_jump" | "five_select" | "five_move" | "remove_ring" | "done"


func get_game_type() -> String:
	return GameTypes.YINSH


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var yn := board as TutorialYinsh3D
	if not is_instance_valid(yn):
		return
	yn.tutorial_input_enabled = false
	yn.tutorial_ring_placed.connect(_on_ring_placed)
	yn.tutorial_ring_selected.connect(_on_ring_selected)
	yn.tutorial_ring_moved.connect(_on_ring_moved)
	yn.tutorial_five_formed.connect(_on_five_formed)
	yn.tutorial_ring_removed.connect(_on_ring_removed)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"yinsh_welcome",
		"آموزش کامل یینش (YINSH)",
		"هدف یینش ساختن «۵ دیسک هم‌رنگ در یک خط» است! هر بار ردیف ۵ تایی بسازی ۱ امتیاز می‌گیری — اما باید یکی از حلقه‌های خودت رو از صفحه برداری (هر کی زودتر ۳ حلقه برداره برنده‌ست!)."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع چیدمان")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Place 5th ring
	var st_place := TutorialStep.create(
		"yinsh_place",
		"۱. فاز چیدمان: قرار دادن ۵ حلقه فرمانده",
		"در شروع بازی هر بازیکن نوبتی ۵ حلقه روی تقاطع‌های خالی می‌گذاره. الان ۴ حلقه قرمز داری — آخرین حلقه‌ات رو روی نقطه مشخص‌شده بگذار!"
	)
	st_place.with_badge("تمرین ۱ از ۵")
	st_place.with_hint("نقطه روشن‌شده روی صفحه رو لمس کن")
	st_place.with_target(func(): return _get_spot_rect(5, 2), 8.0, 18.0)
	st_place.with_avoid_rect(func(): return _get_board_rect())
	st_place.with_scrim_alpha(0.65)
	st_place.with_interactive(true, false)
	st_place.with_placement("top")
	st_place.with_hooks(func(): _enter_phase("place"))
	s.append(st_place)

	# 2. Select Ring -> Plant Disk
	var st_sel := TutorialStep.create(
		"yinsh_select",
		"۲. گام اول نوبت: انتخاب حلقه و کاشت دیسک",
		"هر نوبت ۲ مرحله داره: اول حلقه قرمزِ مشخص‌شده رو لمس کن تا داخلش ۱ دیسک قرمز کاشته بشه و نقاط سبز مجاز روشن بشن!"
	)
	st_sel.with_badge("تمرین ۲ از ۵")
	st_sel.with_hint("روی حلقه قرمز مشخص‌شده بزن")
	st_sel.with_target(func(): return _get_spot_rect(5, -4), 8.0, 18.0)
	st_sel.with_avoid_rect(func(): return _get_board_rect())
	st_sel.with_scrim_alpha(0.65)
	st_sel.with_interactive(true, false)
	st_sel.with_placement("top")
	st_sel.with_hooks(func(): _enter_phase("select_jump"))
	s.append(st_sel)

	# 3. Jump & Flip Disks
	var st_jump := TutorialStep.create(
		"yinsh_jump",
		"۳. حرکت حلقه و برگرداندن رنگ دیسک‌ها!",
		"قانون کلیدی یینش:\n• روی نقاط خالی می‌تونی هر چقدر بخوای جلو بری.\n• اگر از روی دیسک‌ها بپری، باید دقیقاً روی «اولین نقطه خالی» بعدشون بشینی و رنگ همه دیسک‌های پریده‌شده (آبی ↔ قرمز) برعکس می‌شه!\nنقطه سبز مشخص‌شده رو بزن!"
	)
	st_jump.with_badge("تمرین ۳ از ۵")
	st_jump.with_hint("روی نقطه سبز مشخص‌شده بزن")
	st_jump.with_target(func(): return _get_spot_rect(5, 2), 8.0, 18.0)
	st_jump.with_avoid_rect(func(): return _get_board_rect())
	st_jump.with_scrim_alpha(0.65)
	st_jump.with_interactive(true, false)
	st_jump.with_placement("top")
	st_jump.with_hooks(func(): _enter_phase("move_jump"))
	s.append(st_jump)

	# 4. Form 5-in-a-Row
	var st_five := TutorialStep.create(
		"yinsh_five",
		"۴. ساخت ردیف ۵ تایی!",
		"الان ۴ دیسک قرمز توی ردیف وسط کنار هم هستن! حلقه قرمز سر ردیف رو انتخاب کن و به نقطه خالی کناریش ببر تا با دیسک کاشته‌شده «ردیف ۵ تایی» کامل بشه!"
	)
	st_five.with_badge("تمرین ۴ از ۵")
	st_five.with_hint("حلقه سر ردیف و سپس نقطه خالی مشخص‌شده رو بزن")
	st_five.with_target(func(): return _get_five_step_rect(), 8.0, 18.0)
	st_five.with_avoid_rect(func(): return _get_board_rect())
	st_five.with_scrim_alpha(0.65)
	st_five.with_interactive(true, false)
	st_five.with_placement("top")
	st_five.with_hooks(func(): _enter_phase("five_select"))
	s.append(st_five)

	# 5. Remove Ring to Score
	var st_rem := TutorialStep.create(
		"yinsh_remove",
		"۵. حذف حلقه برای گرفتن ۱ امتیاز!",
		"🎉 ردیف ۵ تایی ساخته شد و ۵ دیسک به جعبه برگشتن! حالا حلقه قرمز مشخص‌شده رو لمس کن تا به جایگاه امتیاز بره (امتیاز می‌گیری ولی ۱ حلقه کمتر داری!)."
	)
	st_rem.with_badge("تمرین ۵ از ۵")
	st_rem.with_hint("حلقه قرمز مشخص‌شده رو برای امتیاز لمس کن")
	st_rem.with_target(func(): return _get_spot_rect(2, -3), 8.0, 18.0)
	st_rem.with_avoid_rect(func(): return _get_board_rect())
	st_rem.with_scrim_alpha(0.65)
	st_rem.with_interactive(true, false)
	st_rem.with_placement("top")
	st_rem.with_hooks(func(): _enter_phase("remove_ring"))
	s.append(st_rem)

	# 6. Finish Dialog
	var st_done := TutorialStep.create(
		"yinsh_done",
		"پایان آموزش یینش",
		"آفرین استاد! حالا چیدمان ۵ حلقه، کاشت دیسک، پرش و برگرداندن رنگ دیسک‌ها، ساخت ردیف ۵ تایی و حذف حلقه برای امتیاز رو بلدی. اولین نفر با ۳ امتیاز برنده‌ست!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var yn := _board as TutorialYinsh3D
	if not is_instance_valid(yn):
		return
	if p == "select_jump":
		yn.setup_jump_and_flip_scenario()
	elif p == "five_select":
		yn.setup_five_in_row_scenario()
	yn.tutorial_input_enabled = (p != "done")


func _advance_after(delay_sec: float) -> void:
	var yn := _board as TutorialYinsh3D
	if is_instance_valid(yn):
		yn.tutorial_input_enabled = false
	if not is_instance_valid(_coordinator):
		return
	_coordinator.hide_overlay_temporarily()
	_coordinator.get_tree().create_timer(delay_sec).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _on_ring_placed(_pid: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "place":
		_phase = "wait"
		_coordinator.show_hud_toast("⭕ ۵ حلقه کامل شد! بریم سراغ حرکت و پرش.")
		_advance_after(0.8)


func _on_ring_selected(_pid: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "select_jump":
		_phase = "move_jump"
		_coordinator.show_hud_toast("🔴 دیسک قرمز کاشته شد! حالا نقطه سبز رو بزن.")
		_coordinator.advance_lesson_step()
	elif is_instance_valid(_coordinator) and _phase == "five_select":
		_phase = "five_move"
		_coordinator.show_hud_toast("🔴 عالی! حالا حلقه رو به نقطه خالی مشخص‌شده ببر.")


func _on_ring_moved(_tid: int, flipped: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "move_jump":
		_phase = "wait"
		_coordinator.show_hud_toast("🔄 پرش انجام شد! %d دیسک رنگش برگشت!" % flipped if flipped > 0 else "✨ حلقه حرکت کرد!")
		_advance_after(1.0)


func _on_five_formed() -> void:
	if is_instance_valid(_coordinator) and _phase in ["five_select", "five_move"]:
		_phase = "wait"
		_coordinator.show_hud_toast("🎉 ردیف ۵ تایی کامل شد! یک حلقه برای امتیاز بردار.")
		_advance_after(1.1)


func _on_ring_removed(_pid: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "remove_ring":
		_phase = "wait"
		_coordinator.show_hud_toast("🏆 +۱ امتیاز! (۲ امتیاز دیگه تا پیروزی)")
		_advance_after(1.0)


func _get_spot_rect(r: int, c: int) -> Rect2:
	var yn := _board as TutorialYinsh3D
	if is_instance_valid(yn):
		return yn.get_spot_screen_rect(r, c)
	return Rect2()


func _get_five_step_rect() -> Rect2:
	var yn := _board as TutorialYinsh3D
	if is_instance_valid(yn):
		if yn.last_selected_piece_id != -1:
			return yn.get_spot_screen_rect(5, -6)
		return yn.get_spot_screen_rect(5, -4)
	return Rect2()


func _get_board_rect() -> Rect2:
	var yn := _board as TutorialYinsh3D
	if is_instance_valid(yn):
		return yn.get_board_screen_rect()
	return Rect2()
