class_name MillTutorialLesson
extends GameTutorialLesson

## Extra-interactive Mill (دوز نه‌تایی / Nine Men's Morris) tutorial.
## Hands-on walkthrough of ALL 3 phases:
##   1. Phase 1 (Placement): Place piece -> complete a Mill [0,1,2] -> remove enemy piece (15)
##   2. Phase 2 (Sliding): Select piece (2) -> slide along line to neighbor (14)
##   3. Phase 3 (Flying): Down to 3 pieces -> fly piece (20) anywhere to (2) to form a Mill!

const BOARD_SCENE: PackedScene = preload("res://scenes/games/mill/tutorial_mill_3d.tscn")

var _phase: String = "" # "place_1" | "make_mill" | "remove_enemy" | "p2_select" | "p2_slide" | "p3_select" | "p3_fly" | "done"


func get_game_type() -> String:
	return GameTypes.MILL


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var mill := board as TutorialMill3D
	if not is_instance_valid(mill):
		return
	mill.tutorial_input_enabled = false
	mill.tutorial_piece_placed.connect(_on_piece_placed)
	mill.tutorial_piece_equipped.connect(_on_piece_equipped)
	mill.tutorial_piece_swapped.connect(_on_piece_swapped)
	mill.tutorial_enemy_removed.connect(_on_enemy_removed)
	mill.tutorial_wrong_node_tapped.connect(_on_wrong_node_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome
	var st_welcome := TutorialStep.create(
		"mill_welcome",
		"آموزش دوز نه‌تایی (Mill)",
		"دوز نه‌تایی ۳ مرحله داره: چیدن ۹ مهره، حرکت روی خطوط، و پرواز! هر وقت ۳ تا مهره‌ات رو توی یک خط ردیف کنی (دوز بسازی)، یکی از مهره‌های حریف رو حذف می‌کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع مرحله ۱")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 2. Phase 1: Place first piece
	var st_place1 := TutorialStep.create(
		"mill_place_1",
		"فاز ۱: چیدن مهره‌ها",
		"در شروع بازی هر بازیکن ۹ مهره در سینی کنار داره و به نوبت روی نقاط خالی می‌چینه. روی نقطه طلایی (گوشه بالا) لمس کن تا اولین مهره‌ات رو بذاری!"
	)
	st_place1.with_badge("فاز ۱: چیدن مهره")
	st_place1.with_hint("روی نقطه طلایی لمس کن")
	st_place1.with_target(func(): return _get_node_rect(0), 10.0, 18.0)
	st_place1.with_avoid_rect(func(): return _get_board_rect())
	st_place1.with_scrim_alpha(0.84)
	st_place1.with_interactive(true, false)
	st_place1.with_placement("auto")
	st_place1.with_hooks(_enter_place_1)
	s.append(st_place1)

	# 3. Phase 1: Complete a Mill!
	var st_mill := TutorialStep.create(
		"mill_make_mill",
		"ساختن دوز (۳ مهره در یک خط)!",
		"حالا ۲ تا مهره‌ات ردیف شدن. نقطه طلایی سوم رو بذار تا یک «دوز» بسازی و جایزه حذف مهره حریف رو بگیری!"
	)
	st_mill.with_badge("فاز ۱: ساختن دوز")
	st_mill.with_hint("روی نقطه سوم خط لمس کن")
	st_mill.with_target(func(): return _get_node_rect(2), 10.0, 18.0)
	st_mill.with_avoid_rect(func(): return _get_board_rect())
	st_mill.with_scrim_alpha(0.84)
	st_mill.with_interactive(true, false)
	st_mill.with_placement("auto")
	st_mill.with_hooks(_enter_make_mill)
	s.append(st_mill)

	# 4. Phase 1: Remove enemy piece!
	var st_remove := TutorialStep.create(
		"mill_remove_enemy",
		"آفرین! دوز ساختی — یک مهره حریف رو حذف کن!",
		"هر وقت دوز بسازی، باید یکی از مهره‌های حریف رو از صفحه برداری (مهره‌هایی که خودشون توی دوز نیستن). روی مهره آبی مشخص‌شده لمس کن!"
	)
	st_remove.with_badge("حذف مهره حریف")
	st_remove.with_hint("روی مهره حریف لمس کن")
	st_remove.with_target(func(): return _get_node_rect(15), 10.0, 18.0)
	st_remove.with_avoid_rect(func(): return _get_board_rect())
	st_remove.with_scrim_alpha(0.84)
	st_remove.with_interactive(true, false)
	st_remove.with_placement("auto")
	st_remove.with_hooks(_enter_remove_enemy)
	s.append(st_remove)

	# 5. Phase 2: Select piece to slide
	var st_p2_sel := TutorialStep.create(
		"mill_p2_select",
		"فاز ۲: حرکت روی خطوط",
		"وقتی هر ۹ مهره چیده شدن، بازی وارد فاز دوم می‌شه! حالا باید مهره‌هات رو به خانه خالیِ همسایه حرکت بدی. این مهره رو انتخاب کن!"
	)
	st_p2_sel.with_badge("فاز ۲: حرکت")
	st_p2_sel.with_hint("روی مهره طلایی لمس کن")
	st_p2_sel.with_target(func(): return _get_node_rect(2), 10.0, 18.0)
	st_p2_sel.with_avoid_rect(func(): return _get_board_rect())
	st_p2_sel.with_scrim_alpha(0.84)
	st_p2_sel.with_interactive(true, false)
	st_p2_sel.with_placement("auto")
	st_p2_sel.with_hooks(_enter_p2_select)
	s.append(st_p2_sel)

	# 6. Phase 2: Slide to neighbor
	var st_p2_slide := TutorialStep.create(
		"mill_p2_slide",
		"حرکت به خانه همسایه",
		"نقطه سبز مسیر مجاز روی خط رو نشون می‌ده. روش لمس کن تا مهره‌ات سر بخوره!"
	)
	st_p2_slide.with_badge("فاز ۲: حرکت")
	st_p2_slide.with_hint("روی خانه سبز همسایه لمس کن")
	st_p2_slide.with_target(func(): return _get_node_rect(14), 10.0, 18.0)
	st_p2_slide.with_avoid_rect(func(): return _get_board_rect())
	st_p2_slide.with_scrim_alpha(0.84)
	st_p2_slide.with_interactive(true, false)
	st_p2_slide.with_placement("auto")
	st_p2_slide.with_hooks(_enter_p2_slide)
	s.append(st_p2_slide)

	# 7. Phase 3: Flying! Select piece
	var st_p3_sel := TutorialStep.create(
		"mill_p3_select",
		"فاز ۳: قدرت پرواز (۳ مهره باقی‌مانده)!",
		"وقتی فقط ۳ تا مهره برات بمونه، قدرت «پرواز» باز می‌شه! یعنی می‌تونی مهره‌ات رو به هر نقطه خالی روی صفحه بپرونی. این مهره پایین رو انتخاب کن!"
	)
	st_p3_sel.with_badge("فاز ۳: پرواز")
	st_p3_sel.with_hint("مهره طلایی پایین رو انتخاب کن")
	st_p3_sel.with_target(func(): return _get_node_rect(20), 10.0, 18.0)
	st_p3_sel.with_avoid_rect(func(): return _get_board_rect())
	st_p3_sel.with_scrim_alpha(0.55)
	st_p3_sel.with_interactive(true, false)
	st_p3_sel.with_placement("auto")
	st_p3_sel.with_hooks(_enter_p3_select)
	s.append(st_p3_sel)

	# 8. Phase 3: Fly across the board to make a Mill!
	var st_p3_fly := TutorialStep.create(
		"mill_p3_fly",
		"پرواز به آن سر تخته!",
		"ببین چطور می‌تونی مستقیم بپری اون سر صفحه و دوز بسازی! روی نقطه طلایی بالا لمس کن."
	)
	st_p3_fly.with_badge("فاز ۳: پرواز")
	st_p3_fly.with_hint("به نقطه طلایی بالا پرواز کن!")
	st_p3_fly.with_target(func(): return _get_node_rect(2), 10.0, 18.0)
	st_p3_fly.with_avoid_rect(func(): return _get_board_rect())
	st_p3_fly.with_scrim_alpha(0.55)
	st_p3_fly.with_interactive(true, false)
	st_p3_fly.with_placement("auto")
	st_p3_fly.with_hooks(_enter_p3_fly)
	s.append(st_p3_fly)

	# 9. Summary & Win Condition
	var st_done := TutorialStep.create(
		"mill_done",
		"آفرین! هر ۳ فاز دوز نه‌تایی رو یاد گرفتی",
		"شرط برد: هر بازیکنی که مهره‌های حریف رو به ۲ تا برسونه (کمتر از ۳ تا) یا همه راه‌های حرکتش رو ببنده، برنده بازی می‌شه!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.55)
	s.append(st_done)

	return s


func _enter_place_1() -> void:
	_phase = "place_1"
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([0])


func _enter_make_mill() -> void:
	_phase = "mill_preview"
	var mill := _board as TutorialMill3D
	if not is_instance_valid(mill):
		return
	mill.tutorial_input_enabled = false
	mill.setup_phase1_mill_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("حالا ببین چطور با ۳ مهره در یک خط «دوز» می‌سازیم...")
	_coordinator.get_tree().create_timer(1.8).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(mill) or _phase != "mill_preview":
			return
		_phase = "make_mill"
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([2])
		_coordinator.reshow_current_step()
	)


func _enter_remove_enemy() -> void:
	_phase = "remove_enemy"
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		mill.trigger_mill_removal_prompt()
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([15])


func _enter_p2_select() -> void:
	_phase = "p2_preview"
	var mill := _board as TutorialMill3D
	if not is_instance_valid(mill):
		return
	mill.tutorial_input_enabled = false
	mill.setup_phase2_slide_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("فاز ۲: همه ۹ مهره چیده شدن — حالا نوبت حرکت روی خطه!")
	_coordinator.get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(mill) or _phase != "p2_preview":
			return
		_phase = "p2_select"
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([2])
		_coordinator.reshow_current_step()
	)


func _enter_p2_slide() -> void:
	_phase = "p2_slide"
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([14])


func _enter_p3_select() -> void:
	_phase = "p3_preview"
	var mill := _board as TutorialMill3D
	if not is_instance_valid(mill):
		return
	mill.tutorial_input_enabled = false
	mill.setup_phase3_flying_scenario()
	_coordinator.hide_overlay_temporarily()
	_coordinator.show_hud_toast("فاز ۳: فقط ۳ مهره مونده — قدرت پرواز باز شد!")
	_coordinator.get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(_coordinator) or not is_instance_valid(mill) or _phase != "p3_preview":
			return
		_phase = "p3_select"
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([20])
		_coordinator.reshow_current_step()
	)


func _enter_p3_fly() -> void:
	_phase = "p3_fly"
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		mill.tutorial_input_enabled = true
		mill.set_guided_nodes([2])


func _on_piece_placed(node_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "place_1" and node_id == 0:
		_coordinator.advance_lesson_step()
	elif _phase == "make_mill" and node_id == 2:
		_coordinator.advance_lesson_step()


func _on_enemy_removed(node_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "remove_enemy" and node_id == 15:
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("ایول! مهره حریف حذف شد!")
		_coordinator.get_tree().create_timer(0.85).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_piece_equipped(node_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "p2_select" and node_id == 2:
		_coordinator.advance_lesson_step()
	elif _phase == "p3_select" and node_id == 20:
		_coordinator.advance_lesson_step()


func _on_piece_swapped(_src_id: int, tgt_id: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var mill := _board as TutorialMill3D
	if _phase == "p2_slide" and tgt_id == 14:
		_phase = "p2_wait"
		if is_instance_valid(mill):
			mill.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(0.95).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "p3_fly" and tgt_id == 2:
		_phase = "done"
		if is_instance_valid(mill):
			mill.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("فوق‌العاده! با پرواز دوز ساختی!")
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_wrong_node_tapped(_node_id: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی نقطه طلایی مشخص‌شده لمس کن!")


func _get_node_rect(node_id: int) -> Rect2:
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		return mill.get_node_screen_rect(node_id)
	return Rect2()


func _get_board_rect() -> Rect2:
	var mill := _board as TutorialMill3D
	if is_instance_valid(mill):
		return mill.get_board_screen_rect()
	return Rect2()
