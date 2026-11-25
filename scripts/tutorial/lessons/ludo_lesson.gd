class_name LudoTutorialLesson
extends GameTutorialLesson

## Interactive Ludo (منچ) tutorial for the Library tab.
## Covers rolling 6 to exit the Yard, bonus roll, moving on track, safe tiles & capturing.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/ludo/tutorial_ludo_3d.tscn")

var _phase: String = "" # "roll_6" | "spawn" | "roll_4" | "move" | "hit_preview" | "hit" | "done"


func get_game_type() -> String:
	return GameTypes.LUDO


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var ludo := board as TutorialLudo3D
	if not is_instance_valid(ludo):
		return
	ludo.tutorial_input_enabled = false
	ludo.tutorial_dice_rolled.connect(_on_dice_rolled)
	ludo.tutorial_pawn_moved.connect(_on_pawn_moved)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"ludo_welcome",
		"آموزش منچ (Ludo)",
		"در منچ باید هر ۴ مهره‌ات رو از حیاط بیرون بیاری، یک دور کامل دور تخته بچرخونی و زودتر از بقیه وارد خونه پایانی وسط صفحه کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع یادگیری")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_roll6 := TutorialStep.create(
		"ludo_roll_6",
		"۱. تاس بریز تا ۶ بیاری!",
		"برای بیرون آوردن مهره از حیاط، باید تاس ۶ بیاری! دکمه «تاس بریز» پایین صفحه رو بزن."
	)
	st_roll6.with_badge("تمرین ۱ از ۴")
	st_roll6.with_hint("روی دکمه تاس بریز لمس کن")
	st_roll6.with_target(func(): return _get_roll_btn(), 8.0, 16.0)
	st_roll6.with_scrim_alpha(0.82)
	st_roll6.with_interactive(true, false)
	st_roll6.with_placement("top")
	st_roll6.with_hooks(_enter_roll_6)
	s.append(st_roll6)

	var st_spawn := TutorialStep.create(
		"ludo_spawn",
		"۲. بیرون آوردن مهره از حیاط",
		"۶ آوردی! روی حیاط یا یکی از مهره‌های روشن‌شده بزن تا مهره‌ات وارد خط شروع بشه و یک تاس جایزه هم بگیری!"
	)
	st_spawn.with_badge("تمرین ۲ از ۴")
	st_spawn.with_hint("روی مهره روشن داخل حیاط لمس کن")
	st_spawn.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_spawn.with_avoid_rect(func(): return _get_board_rect())
	st_spawn.with_scrim_alpha(0.70)
	st_spawn.with_interactive(true, false)
	st_spawn.with_placement("auto")
	st_spawn.with_hooks(_enter_spawn)
	s.append(st_spawn)

	var st_roll4 := TutorialStep.create(
		"ludo_roll_4",
		"۳. تاس جایزه!",
		"چون ۶ آوردی، یک نوبت اضافه جایزه گرفتی! دوباره تاس بریز."
	)
	st_roll4.with_badge("تمرین ۳ از ۴")
	st_roll4.with_hint("دوباره تاس بریز!")
	st_roll4.with_target(func(): return _get_roll_btn(), 8.0, 16.0)
	st_roll4.with_scrim_alpha(0.82)
	st_roll4.with_interactive(true, false)
	st_roll4.with_placement("top")
	st_roll4.with_hooks(_enter_roll_4)
	s.append(st_roll4)

	var st_move := TutorialStep.create(
		"ludo_move",
		"۴. حرکت در مسیر اصلی",
		"تاس ۴ اومد! روی مهره‌ای که الان توی نقطه شروعِ صفحه هست لمس کن تا ۴ خانه جلو بره."
	)
	st_move.with_badge("تمرین ۴ از ۴")
	st_move.with_hint("روی مهره روشن توی صفحه لمس کن")
	st_move.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_move.with_avoid_rect(func(): return _get_board_rect())
	st_move.with_scrim_alpha(0.70)
	st_move.with_interactive(true, false)
	st_move.with_placement("auto")
	st_move.with_hooks(_enter_move)
	s.append(st_move)

	var st_hit := TutorialStep.create(
		"ludo_hit",
		"۵. زدن مهره حریف!",
		"ببین! ۳ خانه جلوتر یک مهره حریف هست و تاس ۳ آوردی. روی مهره خودت بزن تا مهره حریف رو بزنی و برگردونیش به حیاطش!"
	)
	st_hit.with_badge("حالت ویژه: زدن حریف")
	st_hit.with_hint("مهره خودت رو بزن تا حریف رو بزنی!")
	st_hit.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_hit.with_avoid_rect(func(): return _get_board_rect())
	st_hit.with_scrim_alpha(0.65)
	st_hit.with_interactive(true, false)
	st_hit.with_placement("auto")
	st_hit.with_hooks(_enter_hit)
	s.append(st_hit)

	var st_rules := TutorialStep.create(
		"ludo_rules",
		"زدن حریف و خانه‌های امن",
		"اگر روی مهره حریف فرود بیای، مهره‌اش برمی‌گرده به حیاط! روی خانه‌های ستاره‌دار (امن) هیچ مهره‌ای زده نمی‌شه و فقط آوردنِ ۶ بهت تاس جایزه می‌ده."
	)
	st_rules.with_badge("قوانین مهم")
	st_rules.with_cta("بعدی")
	st_rules.with_placement("center")
	st_rules.with_scrim_alpha(0.75)
	s.append(st_rules)

	var st_done := TutorialStep.create(
		"ludo_done",
		"منچ رو یاد گرفتی!",
		"هر بازیکنی که زودتر هر ۴ مهره‌اش رو با عدد دقیق تاس به خونه وسط برسونه برنده‌ست. موفق باشی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.75)
	s.append(st_done)

	return s


func _enter_roll_6() -> void:
	_phase = "roll_6"
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		ludo.set_scripted_dice(6)
		ludo.tutorial_input_enabled = true


func _enter_spawn() -> void:
	_phase = "spawn"
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		ludo.tutorial_input_enabled = true


func _enter_roll_4() -> void:
	_phase = "roll_4"
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		ludo.set_scripted_dice(4)
		ludo.tutorial_input_enabled = true


func _enter_move() -> void:
	_phase = "move"
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		ludo.tutorial_input_enabled = true


func _enter_hit() -> void:
	_phase = "hit_preview"
	var ludo := _board as TutorialLudo3D
	if not is_instance_valid(ludo):
		return
	ludo.tutorial_input_enabled = false
	ludo.setup_hit_enemy_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("حالا ببین چطور مهره حریف رو می‌زنیم...")
	_coordinator.get_tree().create_timer(1.6).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(ludo) or _phase != "hit_preview":
			return
		_phase = "hit"
		ludo.tutorial_input_enabled = true
		_coordinator.reshow_current_step()
	)


func _on_dice_rolled(_dice_val: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var ludo := _board as TutorialLudo3D
	if _phase == "roll_6" or _phase == "roll_4":
		if is_instance_valid(ludo):
			ludo.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(0.95).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_pawn_moved(_src_index: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var ludo := _board as TutorialLudo3D
	if _phase == "spawn" or _phase == "move" or _phase == "hit":
		var prev_phase: String = _phase
		_phase = "wait"
		if is_instance_valid(ludo):
			ludo.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		if prev_phase == "move":
			_coordinator.show_hud_toast("عالی! مهره ۴ خانه حرکت کرد!")
		elif prev_phase == "hit":
			_coordinator.show_hud_toast("ایول! مهره حریف زده شد و برگشت به حیاطش!")
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_roll_btn() -> Control:
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		return ludo.get_roll_button_control()
	return null


func _get_board_rect() -> Rect2:
	var ludo := _board as TutorialLudo3D
	if is_instance_valid(ludo):
		return ludo.get_board_screen_rect()
	return Rect2()
