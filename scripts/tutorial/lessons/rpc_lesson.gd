class_name RPCTutorialLesson
extends GameTutorialLesson

## Interactive Rock-Paper-Scissors (سنگ کاغذ قیچی) tutorial for the Library tab.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/rpc/tutorial_rpc_3d.tscn")

var _phase: String = "" # "r1" | "r2" | "r3" | "done"


func get_game_type() -> String:
	return GameTypes.RPC


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var rpc := board as TutorialRPC3D
	if not is_instance_valid(rpc):
		return
	rpc.tutorial_input_enabled = false
	rpc.tutorial_round_clashed.connect(_on_clashed)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"rpc_welcome",
		"آموزش سنگ کاغذ قیچی",
		"قانون کلاسیک: 🪨 سنگ قیچی رو می‌شکنه، ✂️ قیچی کاغذ رو می‌بره، 📄 کاغذ سنگ رو می‌پوشونه! هر راند ۵ دست داره و برنده‌ی دست‌ها امتیاز راند رو می‌گیره."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع رقابت")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Rock
	var st_r1 := TutorialStep.create(
		"rpc_r1",
		"۱. انتخاب سنگ (🪨)",
		"دکمه «سنگ» رو بزن تا حریف رو با قیچی شکست بدی!"
	)
	st_r1.with_badge("تمرین ۱ از ۳")
	st_r1.with_hint("دکمه «سنگ» رو لمس کن")
	st_r1.with_target(func(): return _get_choice_btn("rock"), 6.0, 14.0)
	st_r1.with_avoid_rect(func(): return _get_board_rect())
	st_r1.with_scrim_alpha(0.35)
	st_r1.with_interactive(true, false)
	st_r1.with_placement("top")
	st_r1.with_hooks(func(): _enter_phase("r1"))
	s.append(st_r1)

	# 2. Paper
	var st_r2 := TutorialStep.create(
		"rpc_r2",
		"۲. انتخاب کاغذ (📄)",
		"این بار «کاغذ» رو انتخاب کن تا سنگ حریف رو بپوشونی!"
	)
	st_r2.with_badge("تمرین ۲ از ۳")
	st_r2.with_hint("دکمه «کاغذ» رو لمس کن")
	st_r2.with_target(func(): return _get_choice_btn("paper"), 6.0, 14.0)
	st_r2.with_avoid_rect(func(): return _get_board_rect())
	st_r2.with_scrim_alpha(0.35)
	st_r2.with_interactive(true, false)
	st_r2.with_placement("top")
	st_r2.with_hooks(func(): _enter_phase("r2"))
	s.append(st_r2)

	# 3. Scissors
	var st_r3 := TutorialStep.create(
		"rpc_r3",
		"۳. انتخاب قیچی (✂️)",
		"و حالا «قیچی» رو بزن تا کاغذ حریف رو ببری و امتیاز راند رو کامل کنی!"
	)
	st_r3.with_badge("تمرین ۳ از ۳")
	st_r3.with_hint("دکمه «قیچی» رو لمس کن")
	st_r3.with_target(func(): return _get_choice_btn("cutter"), 6.0, 14.0)
	st_r3.with_avoid_rect(func(): return _get_board_rect())
	st_r3.with_scrim_alpha(0.35)
	st_r3.with_interactive(true, false)
	st_r3.with_placement("top")
	st_r3.with_hooks(func(): _enter_phase("r3"))
	s.append(st_r3)

	# 4. Finish
	var st_done := TutorialStep.create(
		"rpc_done",
		"پایان آموزش سنگ کاغذ قیچی",
		"آفرین! هر راند ۵ دست رقابتی داره و در مساوی امتیاز تقسیم نمی‌شه — حدس حرکت بعدی حریف راز بردنه!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var rpc := _board as TutorialRPC3D
	if not is_instance_valid(rpc):
		return
	if p in ["r2", "r3"]:
		rpc.prepare_next_turn_round()
	rpc.tutorial_input_enabled = (p != "done")


func _on_clashed(_my_c: String, _opp_c: String, _w: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase in ["r1", "r2", "r3"]:
		_phase = "wait"
		var rpc := _board as TutorialRPC3D
		if is_instance_valid(rpc):
			rpc.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("⚔️ بردی! (+۱ امتیاز)")
		_coordinator.get_tree().create_timer(1.6).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _get_choice_btn(choice_key: String) -> Control:
	var rpc := _board as TutorialRPC3D
	if is_instance_valid(rpc):
		return rpc.get_choice_button(choice_key)
	return null


func _get_board_rect() -> Rect2:
	var rpc := _board as TutorialRPC3D
	if is_instance_valid(rpc):
		return rpc.get_board_screen_rect()
	return Rect2()
