class_name CheckersTutorialLesson
extends GameTutorialLesson

## Interactive Checkers tutorial for the Library tab.
## Covers diagonal movement, jumping/capturing an enemy piece, and King promotion.

const BOARD_SCENE: PackedScene = preload("res://scenes/games/checkers/tutorial_checkers_3d.tscn")

const IDX_CAP_SRC: int = 5 * 8 + 1 # 41 (row=5, col=1)
const IDX_CAP_TGT: int = 7 * 8 + 3 # 59 (row=7, col=3 -> King promotion!)
const IDX_KING_BACK: int = 5 * 8 + 5 # 45 (row=5, col=5 -> backward King jump over 52!)

var _phase: String = "" # "select_1" | "move_1" | "select_cap" | "do_cap" | "king_sel" | "king_move" | "done"
var _src_cell: int = -1
var _tgt_cell: int = -1


func get_game_type() -> String:
	return GameTypes.CHECKERS


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var chk := board as TutorialCheckers3D
	if not is_instance_valid(chk):
		return
	chk.tutorial_input_enabled = false
	chk.tutorial_piece_equipped.connect(_on_piece_equipped)
	chk.tutorial_player_moved.connect(_on_player_moved)
	chk.tutorial_wrong_cell_tapped.connect(_on_wrong_cell_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	var st_welcome := TutorialStep.create(
		"chk_welcome",
		"آموزش چکرز (Checkers)",
		"در چکرز مهره‌ها فقط روی خانه‌های تیره و به‌صورت مورب حرکت می‌کنن. هدف اینه که همه مهره‌های حریف رو بزنی یا راهشون رو ببندی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع یادگیری")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	var st_sel1 := TutorialStep.create(
		"chk_select_1",
		"۱. انتخاب مهره",
		"مهره‌های عادی فقط ۱ خانه مورب به جلو حرکت می‌کنن. روی این مهره طلایی لمس کن تا مسیرهای مجازش روشن بشه!"
	)
	st_sel1.with_badge("تمرین ۱ از ۳")
	st_sel1.with_hint("روی مهره طلایی لمس کن")
	st_sel1.with_target(func(): return _get_cell_rect(_src_cell), 10.0, 18.0)
	st_sel1.with_avoid_rect(func(): return _get_board_rect())
	st_sel1.with_scrim_alpha(0.84)
	st_sel1.with_interactive(true, false)
	st_sel1.with_placement("auto")
	st_sel1.with_hooks(_enter_select_1)
	s.append(st_sel1)

	var st_move1 := TutorialStep.create(
		"chk_move_1",
		"۲. حرکت مورب",
		"حالا روی خانه سبز مشخص‌شده لمس کن تا مهره‌ات حرکت کنه!"
	)
	st_move1.with_badge("تمرین ۱ از ۳")
	st_move1.with_hint("روی خانه سبز لمس کن")
	st_move1.with_target(func(): return _get_cell_rect(_tgt_cell), 10.0, 18.0)
	st_move1.with_avoid_rect(func(): return _get_board_rect())
	st_move1.with_scrim_alpha(0.84)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_enter_move_1)
	s.append(st_move1)

	var st_sel_cap := TutorialStep.create(
		"chk_select_cap",
		"۳. پرش روی مهره حریف و شاه شدن!",
		"اگر مهره حریف جلوتر باشه و پشتش خالی باشه، باید از روش بپری و بزنیش! و وقتی به ردیف آخر برسی، مهره‌ات «شاه» (تاج‌دار) می‌شه. این مهره رو انتخاب کن!"
	)
	st_sel_cap.with_badge("تمرین ۲ از ۳")
	st_sel_cap.with_hint("مهره طلایی رو انتخاب کن")
	st_sel_cap.with_target(func(): return _get_cell_rect(IDX_CAP_SRC), 10.0, 18.0)
	st_sel_cap.with_avoid_rect(func(): return _get_board_rect())
	st_sel_cap.with_scrim_alpha(0.84)
	st_sel_cap.with_interactive(true, false)
	st_sel_cap.with_placement("auto")
	st_sel_cap.with_hooks(_enter_select_cap)
	s.append(st_sel_cap)

	var st_do_cap := TutorialStep.create(
		"chk_do_cap",
		"بپر، بزن و شاه شو!",
		"روی خانه ردیف آخر لمس کن تا از روی مهره حریف بپری، بزنیش و تاج شاهی بگیری!"
	)
	st_do_cap.with_badge("تمرین ۳ از ۳")
	st_do_cap.with_hint("روی خانه طلایی ردیف آخر لمس کن")
	st_do_cap.with_target(func(): return _get_cell_rect(IDX_CAP_TGT), 10.0, 18.0)
	st_do_cap.with_avoid_rect(func(): return _get_board_rect())
	st_do_cap.with_scrim_alpha(0.84)
	st_do_cap.with_interactive(true, false)
	st_do_cap.with_placement("auto")
	st_do_cap.with_hooks(_enter_do_cap)
	s.append(st_do_cap)

	var st_king_sel := TutorialStep.create(
		"chk_king_select",
		"۴. حرکت با مهره شاه (رو به عقب!)",
		"مهره‌ات تاج شاهی گرفت! برخلاف مهره‌های عادی، شاه می‌تونه هم به جلو و هم به عقب حرکت کنه و بزنه. روی مهره شاهت لمس کن!"
	)
	st_king_sel.with_badge("قدرت شاه")
	st_king_sel.with_hint("روی مهره شاه (ردیف آخر) لمس کن")
	st_king_sel.with_target(func(): return _get_cell_rect(IDX_CAP_TGT), 10.0, 18.0)
	st_king_sel.with_avoid_rect(func(): return _get_board_rect())
	st_king_sel.with_scrim_alpha(0.75)
	st_king_sel.with_interactive(true, false)
	st_king_sel.with_placement("auto")
	st_king_sel.with_hooks(_enter_king_select)
	s.append(st_king_sel)

	var st_king_move := TutorialStep.create(
		"chk_king_move",
		"پرش به عقب و زدن مهره حریف!",
		"ببین نقاط سبز هم رو به عقب باز شدن! شاه می‌تونه به عقب بپره و مهره حریف رو بزنه. روی خانه سبز پشت مهره حریف لمس کن!"
	)
	st_king_move.with_badge("قدرت شاه")
	st_king_move.with_hint("به عقب بپر و مهره حریف رو بزن!")
	st_king_move.with_target(func(): return _get_cell_rect(IDX_KING_BACK), 10.0, 18.0)
	st_king_move.with_avoid_rect(func(): return _get_board_rect())
	st_king_move.with_scrim_alpha(0.75)
	st_king_move.with_interactive(true, false)
	st_king_move.with_placement("auto")
	st_king_move.with_hooks(_enter_king_move)
	s.append(st_king_move)

	var st_done := TutorialStep.create(
		"chk_done",
		"چکرز رو یاد گرفتی!",
		"حالا حرکت مورب، پرش روی حریف و شاه شدن رو بلدی. وقتشه بری سر میز و حریفات رو شکست بدی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به راهنما")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.82)
	s.append(st_done)

	return s


func _enter_select_1() -> void:
	_phase = "select_1"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.set_pieces_movements()
		_src_cell = chk.get_first_movable_cell()
		_tgt_cell = chk.get_first_target_for(_src_cell)
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([_src_cell])


func _enter_move_1() -> void:
	_phase = "move_1"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([_tgt_cell])


func _enter_select_cap() -> void:
	_phase = "select_cap"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.setup_capture_and_king_scenario()
		chk.is_my_turn = true
		chk.set_board_locked(false)
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([IDX_CAP_SRC])


func _enter_do_cap() -> void:
	_phase = "do_cap"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([IDX_CAP_TGT])


func _enter_king_select() -> void:
	_phase = "king_sel"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.set_pieces_movements()
		chk.is_my_turn = true
		chk.set_board_locked(false)
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([IDX_CAP_TGT])


func _enter_king_move() -> void:
	_phase = "king_move"
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		chk.tutorial_input_enabled = true
		chk.set_guided_cells([IDX_KING_BACK])


func _on_piece_equipped(cell_idx: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "select_1" and cell_idx == _src_cell:
		_coordinator.advance_lesson_step()
	elif _phase == "select_cap" and cell_idx == IDX_CAP_SRC:
		_coordinator.advance_lesson_step()
	elif _phase == "king_sel" and cell_idx == IDX_CAP_TGT:
		_coordinator.advance_lesson_step()


func _on_player_moved(_src: int, _tgt: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	var chk := _board as TutorialCheckers3D
	if _phase == "move_1":
		_phase = "wait"
		if is_instance_valid(chk):
			chk.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.get_tree().create_timer(0.55).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "do_cap":
		_phase = "wait_king"
		if is_instance_valid(chk):
			chk.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("ایول! هم مهره حریف رو زدی هم شاه شدی!")
		_coordinator.get_tree().create_timer(1.1).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)
	elif _phase == "king_move":
		_phase = "done"
		if is_instance_valid(chk):
			chk.tutorial_input_enabled = false
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("عالی! مهره شاه رو به عقب هم حرکت می‌کنه!")
		_coordinator.get_tree().create_timer(0.95).timeout.connect(func():
			if is_instance_valid(_coordinator):
				_coordinator.advance_lesson_step()
		)


func _on_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی خانه طلایی مشخص‌شده لمس کن!")


func _get_cell_rect(cell_idx: int) -> Rect2:
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		return chk.get_cell_screen_rect(cell_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var chk := _board as TutorialCheckers3D
	if is_instance_valid(chk):
		return chk.get_board_screen_rect()
	return Rect2()
