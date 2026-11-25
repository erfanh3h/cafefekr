class_name MSweeperTutorialLesson
extends GameTutorialLesson

## Interactive Minesweeper (مین یاب) tutorial for the Library tab.
## Runs in persistent 2D top-down view and covers 8-neighbor counts, 0 flood-fill,
## long-press / right-click / Flag mode mine defusal (+1 score), wrong flags, and multi-step deduction.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/msweeper/tutorial_msweeper_3d.tscn")

var _phase: String = "" # "dig" | "flood" | "flag" | "flag_2" | "done"


func get_game_type() -> String:
	return GameTypes.MSWEEPER


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var ms := board as TutorialMSweeper3D
	if not is_instance_valid(ms):
		return
	ms.tutorial_input_enabled = false
	ms.tutorial_cell_dug.connect(_on_cell_dug)
	ms.tutorial_mine_flagged.connect(_on_mine_flagged)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"ms_welcome",
		"آموزش مین‌یاب (Minesweeper)",
		"صفحه ۸×۸ مین‌یاب ۵۴ خانه امن و ۱۰ مین مخفی داره!\n• هر عدد (۱ تا ۸) نشون می‌ده توی ۸ خانه همسایه (افقی، عمودی و مورب) چند مین هست.\n• پرچم درست روی مین = +۱ امتیاز | پرچم اشتباه = علامت اخطار ❌\n• لمس مستقیم مین = انفجار و باخت!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع کاوش")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	st_welcome.with_hooks(func(): _ensure_2d_view())
	s.append(st_welcome)

	# 1. Dig numbered cell (0,3) -> idx 3
	var st_dig := TutorialStep.create(
		"ms_dig",
		"۱. باز کردن خانه امن (لمس کوتاه)",
		"در حالت «کاوش»، با یک لمس کوتاه خانه باز می‌شه. روی خانه مشخص‌شده کنار عدد «۲» ضربه بزن تا باز بشه و ببینی چند مین در ۸ همسایه دورش هست!"
	)
	st_dig.with_badge("تمرین ۱ از ۴")
	st_dig.with_hint("روی خانه مشخص‌شده ضربه بزن")
	st_dig.with_target(func(): return _get_cell_rect(3), 8.0, 14.0)
	st_dig.with_avoid_rect(func(): return _get_board_rect())
	st_dig.with_scrim_alpha(0.55)
	st_dig.with_interactive(true, false)
	st_dig.with_placement("top")
	st_dig.with_hooks(func(): _enter_phase("dig"))
	s.append(st_dig)

	# 2. Dig 0 cell (4,4) -> idx 36 (flood-fill!)
	var st_flood := TutorialStep.create(
		"ms_flood",
		"۲. کشف منطقه امن (عدد ۰ و باز شدن خودکار)",
		"وقتی خانه‌ای بزنی که هیچ مینی در ۸ همسایه‌اش نباشه (۰)، تمام خانه‌های امن اطرافش زنجیروار باز می‌شن! خانه مرکز صفحه رو بزن."
	)
	st_flood.with_badge("تمرین ۲ از ۴")
	st_flood.with_hint("روی خانه مشخص‌شده مرکز صفحه ضربه بزن")
	st_flood.with_target(func(): return _get_cell_rect(36), 8.0, 14.0)
	st_flood.with_avoid_rect(func(): return _get_board_rect())
	st_flood.with_scrim_alpha(0.55)
	st_flood.with_interactive(true, false)
	st_flood.with_placement("top")
	st_flood.with_hooks(func(): _enter_phase("flood"))
	s.append(st_flood)

	# 3. Flag Mine #1 at (1,1) -> idx 9
	var st_flag := TutorialStep.create(
		"ms_flag",
		"۳. پرچم‌گذاری مین (نگه‌داشتن / راست‌کلیک / دکمه پرچم)",
		"به عدد «۱» گوشه بالا-چپ نگاه کن: فقط همین یک خانه بسته کنارش مونده — پس صددرصد «مین» هست! انگشتت رو روش نگه دار (یا راست‌کلیک کن، یا حالت «پرچم» پایین تخته رو بزن) تا خنثی بشه و +۱ امتیاز بگیری!"
	)
	st_flag.with_badge("تمرین ۳ از ۴")
	st_flag.with_hint("روی خانه مین نگه‌دار (Long-press) یا راست‌کلیک کن")
	st_flag.with_target(func(): return _get_cell_rect(9), 8.0, 14.0)
	st_flag.with_avoid_rect(func(): return _get_board_rect())
	st_flag.with_scrim_alpha(0.55)
	st_flag.with_interactive(true, false)
	st_flag.with_placement("top")
	st_flag.with_hooks(func(): _enter_phase("flag"))
	s.append(st_flag)

	# 4. Flag Mine #2 at (1,2) -> idx 10 using deduction from '2' at (0,1)!
	var st_flag_2 := TutorialStep.create(
		"ms_flag_2",
		"۴. استنتاج با عدد «۲» و خنثی‌سازی مین دوم",
		"حالا به عدد «۲» در ردیف بالا نگاه کن: یکی از مین‌هاش رو الان پرچم زدی، و بین همسایه‌هاش فقط همین یک خانه بسته مونده — پس اینم قطعا مین دومه! پرچمش کن (+۱ امتیاز). مراقب باش پرچم روی خانه امن علامت خطا می‌گیره!"
	)
	st_flag_2.with_badge("تمرین ۴ از ۴")
	st_flag_2.with_hint("روی مین دوم نگه‌دار (Long-press) یا راست‌کلیک کن")
	st_flag_2.with_target(func(): return _get_cell_rect(10), 8.0, 14.0)
	st_flag_2.with_avoid_rect(func(): return _get_board_rect())
	st_flag_2.with_scrim_alpha(0.55)
	st_flag_2.with_interactive(true, false)
	st_flag_2.with_placement("top")
	st_flag_2.with_hooks(func(): _enter_phase("flag_2"))
	s.append(st_flag_2)

	# 5. Finish
	var st_done := TutorialStep.create(
		"ms_done",
		"پایان آموزش مین‌یاب",
		"عالی بود! حالا با قوانین مین‌یاب کاملاً آشنایی: باز کردن خانه‌های امن، استنتاج تعداد مین‌ها در ۸ همسایگی، باز شدن زنجیروار ۰، پرچم زدن با لمس طولانی یا دکمه «پرچم»، و پرهیز از پرچم اشتباه و انفجار!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	st_done.with_hooks(func(): _enter_phase("done"))
	s.append(st_done)

	return s


func _ensure_2d_view() -> void:
	var ms := _board as TutorialMSweeper3D
	if is_instance_valid(ms):
		ms.enable_2d_top_down_view()


func _enter_phase(p: String) -> void:
	_phase = p
	var ms := _board as TutorialMSweeper3D
	if is_instance_valid(ms):
		ms.set_tutorial_phase(p)
		ms.tutorial_input_enabled = (p != "done")


func _on_cell_dug(_idx: int, val: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "dig":
		_phase = "wait"
		_coordinator.show_hud_toast("🔍 عدد %d یعنی %d مین در همسایگی!" % [val, val])
		_coordinator.advance_lesson_step()
	elif _phase == "flood":
		_phase = "wait"
		_coordinator.show_hud_toast("✨ منطقه امن خودکار باز شد!")
		_coordinator.advance_lesson_step()


func _on_mine_flagged(_idx: int, correct: bool) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "flag" and correct:
		_phase = "wait"
		_coordinator.show_hud_toast("🎯 مین اول خنثی شد! +۱ امتیاز!")
		_coordinator.advance_lesson_step()
	elif _phase == "flag_2" and correct:
		_phase = "wait"
		_coordinator.show_hud_toast("🏆 مین دوم هم خنثی شد! +۲ امتیاز!")
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif not correct:
		_coordinator.show_hud_toast("❌ پرچم اشتباه! این خانه امن بود.")


func _get_cell_rect(idx: int) -> Rect2:
	var ms := _board as TutorialMSweeper3D
	if is_instance_valid(ms):
		return ms.get_cell_screen_rect(idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var ms := _board as TutorialMSweeper3D
	if is_instance_valid(ms):
		return ms.get_board_screen_rect()
	return Rect2()
