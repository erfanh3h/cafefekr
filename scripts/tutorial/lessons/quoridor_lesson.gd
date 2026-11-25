class_name QuoridorTutorialLesson
extends GameTutorialLesson

## Interactive Quoridor (کوریدور) tutorial for the Library tab.
## Teaches pawn movement toward the goal row, jumping over an adjacent opponent pawn,
## and placing horizontal/vertical walls without blocking all paths.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/quoridor/tutorial_quoridor_3d.tscn")

var _phase: String = "" # "move" | "jump" | "wall" | "done"


func get_game_type() -> String:
	return GameTypes.QUORIDOR


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var qr := board as TutorialQuoridor3D
	if not is_instance_valid(qr):
		return
	qr.tutorial_input_enabled = false
	qr.tutorial_pawn_moved.connect(_on_pawn_moved)
	qr.tutorial_wall_placed.connect(_on_wall_placed)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"quoridor_welcome",
		"آموزش کوریدور (Quoridor)",
		"هدف کوریدور اینه که مهره‌ات رو زودتر از حریف به ردیف انتهای زمین حریف برسونی! هر نوبت یا ۱ خانه حرکت می‌کنی، یا یکی از ۱۰ دیوارت رو برای طولانی کردن مسیر حریف می‌گذاری."
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع حرکت")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 1. Move Pawn Forward
	var st_move := TutorialStep.create(
		"quoridor_move",
		"۱. حرکت مهره به سمت هدف",
		"مهره قرمز تو باید به ردیف بالای صفحه برسه. روی خانه سبزِ جلوی مهره‌ات بزن تا ۱ خانه جلو بره!"
	)
	st_move.with_badge("تمرین ۱ از ۳")
	st_move.with_hint("خانه سبزِ جلوی مهره قرمز رو لمس کن")
	st_move.with_target(func(): return _get_cell_rect(5, 4), 10.0, 16.0)
	st_move.with_avoid_rect(func(): return _get_board_rect())
	st_move.with_scrim_alpha(0.55)
	st_move.with_interactive(true, false)
	st_move.with_placement("top")
	st_move.with_hooks(func(): _enter_phase("move"))
	s.append(st_move)

	# 2. Jump Over Opponent Pawn
	var st_jump := TutorialStep.create(
		"quoridor_jump",
		"۲. پرش از روی مهره حریف!",
		"وقتی مهره حریف دقیقاً جلوت باشه، می‌تونی مستقیم از روش بپری و ۱ خانه جلو بیفتی (و اگه پشتش دیوار باشه، مورب بپری)! روی خانه سبزِ پشت مهره حریف بزن."
	)
	st_jump.with_badge("تمرین ۲ از ۳")
	st_jump.with_hint("خانه سبز پشت مهره حریف رو لمس کن")
	st_jump.with_target(func(): return _get_cell_rect(3, 4), 10.0, 16.0)
	st_jump.with_avoid_rect(func(): return _get_board_rect())
	st_jump.with_scrim_alpha(0.55)
	st_jump.with_interactive(true, false)
	st_jump.with_placement("top")
	st_jump.with_hooks(func(): _enter_phase("jump"))
	s.append(st_jump)

	# 3. Place Wall
	var st_wall := TutorialStep.create(
		"quoridor_wall",
		"۳. گذاشتن دیوار و قانون ممنوعیت حبس",
		"دکمه «دیوار افقی» یا «دیوار عمودی» رو از نوار پایین بزن، یک شیار روی تخته انتخاب کن و «تایید دیوار» رو بزن! (نکته طلایی: هیچ‌وقت نمی‌تونی تمام راه‌های حریف رو ببندی!)"
	)
	st_wall.with_badge("تمرین ۳ از ۳")
	st_wall.with_hint("دیوار افقی/عمودی انتخاب کن، روی تخته بگذار و تایید کن")
	st_wall.with_target(func(): return _get_wall_target(), 8.0, 14.0)
	st_wall.with_scrim_alpha(0.55)
	st_wall.with_interactive(true, false)
	st_wall.with_placement("top")
	st_wall.with_hooks(func(): _enter_phase("wall"))
	s.append(st_wall)

	# 4. Finish
	var st_done := TutorialStep.create(
		"quoridor_done",
		"پایان آموزش کوریدور",
		"آفرین! حالا حرکت مهره، پرش از روی حریف و چیدن دیوارهای هوشمندانه (بدون مسدود کردن کامل مسیر) رو بلدی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.78)
	s.append(st_done)

	return s


func _enter_phase(p: String) -> void:
	_phase = p
	var qr := _board as TutorialQuoridor3D
	if not is_instance_valid(qr):
		return
	if p == "jump":
		qr.setup_jump_scenario()
	elif p == "wall":
		qr.setup_wall_scenario()
	qr.tutorial_input_enabled = (p != "done")


func _advance_after(delay_sec: float) -> void:
	var qr := _board as TutorialQuoridor3D
	if is_instance_valid(qr):
		qr.tutorial_input_enabled = false
	if not is_instance_valid(_coordinator):
		return
	_coordinator.hide_overlay_temporarily()
	_coordinator.get_tree().create_timer(delay_sec).timeout.connect(func():
		if is_instance_valid(_coordinator):
			_coordinator.advance_lesson_step()
	)


func _on_pawn_moved(_r: int, _c: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "move":
		_phase = "wait"
		_coordinator.show_hud_toast("عالی! مهره جلو رفت!")
		_advance_after(0.45)
	elif _phase == "jump":
		_phase = "wait"
		_coordinator.show_hud_toast("آفرین! از روی مهره حریف پریدی!")
		_advance_after(0.45)


func _on_wall_placed(_ori: String, _r: int, _c: int) -> void:
	if is_instance_valid(_coordinator) and _phase == "wall":
		_phase = "wait"
		_coordinator.show_hud_toast("🧱 دیوار با موفقیت گذاشته شد!")
		_advance_after(0.5)


func _get_wall_target() -> Variant:
	var qr := _board as TutorialQuoridor3D
	if is_instance_valid(qr):
		return qr.get_wall_step_target()
	return null


func _get_cell_rect(r: int, c: int) -> Rect2:
	var qr := _board as TutorialQuoridor3D
	if is_instance_valid(qr):
		return qr.get_cell_screen_rect(r, c)
	return Rect2()


func _get_board_and_dock() -> Variant:
	var qr := _board as TutorialQuoridor3D
	if is_instance_valid(qr):
		return qr.get_board_and_dock_rect()
	return null


func _get_board_rect() -> Rect2:
	var qr := _board as TutorialQuoridor3D
	if is_instance_valid(qr):
		return qr.get_board_screen_rect()
	return Rect2()
