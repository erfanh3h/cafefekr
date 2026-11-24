class_name ChessTutorialLesson
extends GameTutorialLesson

## Interactive Chess tutorial for the Library tab.
## Covers:
##   1. Objective (Checkmate) & 8x8 board / captured-piece trays
##   2. Hands-on Pawn selection, movement (green dots), & diagonal capture (crimson ring)
##   3. Movement rules for every piece (Pawn, Rook, Knight, Bishop, Queen, King + Castling)
##   4. Live Check (کیش) warning ring & Checkmate (کیش و مات) win condition

const BOARD_SCENE: PackedScene = preload("res://scenes/games/chess/tutorial_chess_3d.tscn")

# Row 0 = White home rank (Rank 1), Row 1 = White Pawns (Rank 2),
# Row 6 = Black Pawns (Rank 7), Row 7 = Black home rank (Rank 8)
const IDX_A1_ROOK: int = 0 * 8 + 0   # 0
const IDX_D1_QUEEN: int = 0 * 8 + 3  # 3
const IDX_E1_KING: int = 0 * 8 + 4   # 4
const IDX_F1_BISHOP: int = 0 * 8 + 5 # 5
const IDX_G1_KNIGHT: int = 0 * 8 + 6 # 6
const IDX_E2: int = 1 * 8 + 4        # 12
const IDX_E4: int = 3 * 8 + 4        # 28
const IDX_D5: int = 4 * 8 + 3        # 35
const IDX_E8_KING: int = 7 * 8 + 4   # 60

const COORD_D7 := Vector2i(6, 3)
const COORD_D5 := Vector2i(4, 3)

const TOTAL_DISPLAY_STEPS: int = 14

var _phase: String = "" # "select_e2" | "move_e4" | "wait_bot" | "select_e4" | "capture_d5" | "tour"


func get_game_type() -> String:
	return GameTypes.CHESS


func get_tutorial_board_scene() -> PackedScene:
	return BOARD_SCENE


func get_missed_turns_limit_visible() -> bool:
	return false


func get_total_display_steps(_default_total: int) -> int:
	return TOTAL_DISPLAY_STEPS


func get_display_step_index(raw_index: int) -> int:
	# Account for the 2 dynamic capture steps inserted after index 3 (chess_move_e4)
	return raw_index + 2 if raw_index >= 4 else raw_index


func on_board_ready(board: Node, coordinator: Node) -> void:
	super.on_board_ready(board, coordinator)
	var chess := board as TutorialChess3D
	if not is_instance_valid(chess):
		return
	chess.tutorial_input_enabled = false
	chess.tutorial_piece_equipped.connect(_on_piece_equipped)
	chess.tutorial_player_moved.connect(_on_player_moved)
	chess.tutorial_scripted_move_finished.connect(_on_scripted_move_finished)
	chess.tutorial_wrong_cell_tapped.connect(_on_wrong_cell_tapped)


func build_steps(_coordinator: Node) -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome & Goal
	var st_welcome := TutorialStep.create(
		"chess_welcome",
		"آموزش شطرنج کافه فکر",
		"در شطرنج دو ارتش سفید و سیاه روبه‌روی هم قرار می‌گیرن. هدف اصلی بازی اینه که شاه حریف رو «کیش و مات» کنی!"
	)
	st_welcome.with_badge("آشنایی با بازی")
	st_welcome.with_cta("شروع یادگیری")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 2. Board & Graveyard Overview
	var st_board := TutorialStep.create(
		"chess_board",
		"صفحه ۸×۸ و سینی مهره‌ها",
		"مهره‌های سفید (تیم تو) پایین صفحه هستن. هر مهره‌ای که از حریف بزنی، میره توی سینی مخملی کنار صفحه!"
	)
	st_board.with_badge("تخته و مهره‌ها")
	st_board.with_cta("فهمیدم، بزن بریم!")
	st_board.with_target(func(): return _get_board_rect(), 8.0, 18.0)
	st_board.with_avoid_rect(func(): return _get_board_rect())
	st_board.with_scrim_alpha(0.80)
	st_board.with_placement("auto")
	s.append(st_board)

	# 3. Interactive: Select e2 Pawn + Pawn Rules
	var st_select_e2 := TutorialStep.create(
		"chess_select_e2",
		"۱. سرباز (پیاده) و انتخاب مهره",
		"سرباز فقط رو به جلو ۱ خانه می‌ره (توی حرکت اول می‌تونه ۲ خانه بره) و برای زدن مهره حریف به‌صورت مورب حمله می‌کنه. روی سرباز طلایی (e2) لمس کن!"
	)
	st_select_e2.with_badge("حرکت مهره‌ها: سرباز")
	st_select_e2.with_hint("روی سرباز مشخص‌شده e2 لمس کن")
	st_select_e2.with_target(func(): return _get_cell_rect(IDX_E2), 10.0, 18.0)
	st_select_e2.with_avoid_rect(func(): return _get_board_rect())
	st_select_e2.with_scrim_alpha(0.84)
	st_select_e2.with_interactive(true, false)
	st_select_e2.with_placement("auto")
	st_select_e2.with_hooks(_enter_select_e2)
	s.append(st_select_e2)

	# 4. Interactive: Move e2 -> e4
	var st_move_e4 := TutorialStep.create(
		"chess_move_e4",
		"۲. حرکت به خانه سبز",
		"نقطه‌های سبز خانه‌هایی هستن که این مهره می‌تونه بره. خانه جلوتر (e4) رو لمس کن تا سرباز حرکت کنه!"
	)
	st_move_e4.with_badge("تمرین حرکت")
	st_move_e4.with_hint("روی خانه سبز e4 لمس کن")
	st_move_e4.with_target(func(): return _get_cell_rect(IDX_E4), 10.0, 18.0)
	st_move_e4.with_avoid_rect(func(): return _get_board_rect())
	st_move_e4.with_scrim_alpha(0.84)
	st_move_e4.with_interactive(true, false)
	st_move_e4.with_placement("auto")
	st_move_e4.with_hooks(_enter_move_e4)
	s.append(st_move_e4)

	# (Dynamic interactive capture steps chess_select_e4 & chess_capture_d5 run here)

	# 5. Rook (رخ)
	var st_rook := TutorialStep.create(
		"chess_piece_rook",
		"رخ (قلعه)",
		"رخ در مسیرهای افقی و عمودی هر چند خانه که بخواد حرکت می‌کنه، به شرطی که مهره‌ای سر راهش نباشه."
	)
	st_rook.with_badge("آشنایی با مهره‌ها")
	st_rook.with_cta("بعدی")
	st_rook.with_target(func(): return _get_cell_rect(IDX_A1_ROOK), 10.0, 18.0)
	st_rook.with_avoid_rect(func(): return _get_board_rect())
	st_rook.with_scrim_alpha(0.82)
	st_rook.with_placement("auto")
	st_rook.with_hooks(func(): _highlight_static_piece(IDX_A1_ROOK, false), _clear_piece_highlights)
	s.append(st_rook)

	# 6. Knight (اسب) — with live green L-move dots preview!
	var st_knight := TutorialStep.create(
		"chess_piece_knight",
		"اسب",
		"اسب به‌شکل «L» حرکت می‌کنه (۲ خانه مستقیم + ۱ خانه به پهلو). اسب تنها مهره‌ایه که می‌تونه از روی بقیه مهره‌ها بپره!"
	)
	st_knight.with_badge("آشنایی با مهره‌ها")
	st_knight.with_cta("بعدی")
	st_knight.with_target(func(): return _get_cell_rect(IDX_G1_KNIGHT), 10.0, 18.0)
	st_knight.with_avoid_rect(func(): return _get_board_rect())
	st_knight.with_scrim_alpha(0.82)
	st_knight.with_placement("auto")
	st_knight.with_hooks(func(): _highlight_static_piece(IDX_G1_KNIGHT, true), _clear_piece_highlights)
	s.append(st_knight)

	# 7. Bishop (فیل)
	var st_bishop := TutorialStep.create(
		"chess_piece_bishop",
		"فیل",
		"فیل فقط به‌صورت مورب (قطری) حرکت می‌کنه و هر چند خانه که مسیرش باز باشه پیش می‌ره. هر فیل همیشه روی رنگ خانه خودش می‌مونه."
	)
	st_bishop.with_badge("آشنایی با مهره‌ها")
	st_bishop.with_cta("بعدی")
	st_bishop.with_target(func(): return _get_cell_rect(IDX_F1_BISHOP), 10.0, 18.0)
	st_bishop.with_avoid_rect(func(): return _get_board_rect())
	st_bishop.with_scrim_alpha(0.82)
	st_bishop.with_placement("auto")
	st_bishop.with_hooks(func(): _highlight_static_piece(IDX_F1_BISHOP, false), _clear_piece_highlights)
	s.append(st_bishop)

	# 8. Queen (وزیر)
	var st_queen := TutorialStep.create(
		"chess_piece_queen",
		"وزیر (قدرتمندترین مهره)",
		"وزیر ترکیب رخ و فیله! می‌تونه افقی، عمودی و مورب به هر فاصله‌ای که مسیرش باز باشه حرکت کنه و حمله ببره."
	)
	st_queen.with_badge("آشنایی با مهره‌ها")
	st_queen.with_cta("بعدی")
	st_queen.with_target(func(): return _get_cell_rect(IDX_D1_QUEEN), 10.0, 18.0)
	st_queen.with_avoid_rect(func(): return _get_board_rect())
	st_queen.with_scrim_alpha(0.82)
	st_queen.with_placement("auto")
	st_queen.with_hooks(func(): _highlight_static_piece(IDX_D1_QUEEN, false), _clear_piece_highlights)
	s.append(st_queen)

	# 9. King (شاه)
	var st_king := TutorialStep.create(
		"chess_piece_king",
		"شاه (مهم‌ترین مهره)",
		"شاه در هر جهت فقط ۱ خانه حرکت می‌کنه (و با رخ می‌تونه حرکت «قلعه» بره). هیچ‌وقت نباید شاه رو در خانه تحت حمله بذاری!"
	)
	st_king.with_badge("آشنایی با مهره‌ها")
	st_king.with_cta("بعدی")
	st_king.with_target(func(): return _get_cell_rect(IDX_E1_KING), 10.0, 18.0)
	st_king.with_avoid_rect(func(): return _get_board_rect())
	st_king.with_scrim_alpha(0.82)
	st_king.with_placement("auto")
	st_king.with_hooks(func(): _highlight_static_piece(IDX_E1_KING, false), _clear_piece_highlights)
	s.append(st_king)

	# 10. What is Check (کیش)? — with live red Check marker!
	var st_check := TutorialStep.create(
		"chess_check",
		"کیش (Check) چیست؟",
		"وقتی شاه مستقیماً تهدید بشه، این حلقه قرمز دورش روشن می‌شه! در حالت «کیش» بازیکن مجبوره فوری نجاتش بده: شاه رو فراری بده، راه حمله رو ببنده یا مهره مهاجم رو بزنه."
	)
	st_check.with_badge("قوانین مهم")
	st_check.with_cta("بعدی")
	st_check.with_target(func(): return _get_cell_rect(IDX_E8_KING), 12.0, 18.0)
	st_check.with_avoid_rect(func(): return _get_board_rect())
	st_check.with_scrim_alpha(0.82)
	st_check.with_placement("auto")
	st_check.with_hooks(_enter_check_demo, Callable())
	s.append(st_check)

	# 11. What is Checkmate (کیش و مات)?
	var st_checkmate := TutorialStep.create(
		"chess_checkmate",
		"کیش و مات (Checkmate) و پیروزی!",
		"اگر شاه در حالت کیش باشه و هیچ راهی برای فرار، بستن مسیر یا زدن مهره مهاجم نداشته باشه، «کیش و مات» اتفاق می‌افته و بازی همون لحظه با پیروزی تمام می‌شه!"
	)
	st_checkmate.with_badge("قوانین مهم")
	st_checkmate.with_cta("بعدی")
	st_checkmate.with_target(func(): return _get_cell_rect(IDX_E8_KING), 12.0, 18.0)
	st_checkmate.with_avoid_rect(func(): return _get_board_rect())
	st_checkmate.with_scrim_alpha(0.82)
	st_checkmate.with_placement("auto")
	st_checkmate.with_hooks(Callable(), _exit_check_demo)
	s.append(st_checkmate)

	# 12. Final Summary
	var st_done := TutorialStep.create(
		"chess_done",
		"آماده مسابقه هستی!",
		"حالا حرکت همه مهره‌ها، زدن مهره حریف، کیش و کیش و مات رو بلدی. وقتشه بری سر میز واقعی و حریفات رو مات کنی!"
	)
	st_done.with_badge("پایان آموزش")
	st_done.with_cta("بازگشت به کتابخانه")
	st_done.with_placement("center")
	st_done.with_scrim_alpha(0.82)
	s.append(st_done)

	return s


func _enter_select_e2() -> void:
	_phase = "select_e2"
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.release_piece()
		chess.tutorial_input_enabled = true
		chess.set_guided_cells([IDX_E2])


func _enter_move_e4() -> void:
	_phase = "move_e4"
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.tutorial_input_enabled = true
		chess.set_guided_cells([IDX_E4])


func _on_piece_equipped(cell_idx: int) -> void:
	if not is_instance_valid(_coordinator):
		return
	if _phase == "select_e2" and cell_idx == IDX_E2:
		_coordinator.advance_lesson_step()
	elif _phase == "select_e4" and cell_idx == IDX_E4:
		_enter_capture_d5()


func _on_player_moved(_src_idx: int, tgt_idx: int, _is_hit: bool) -> void:
	if not is_instance_valid(_coordinator) or not is_instance_valid(_board):
		return
	var chess := _board as TutorialChess3D
	if _phase == "move_e4" and tgt_idx == IDX_E4:
		_phase = "wait_bot"
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("عالی! حالا ببین حریف چه حرکتی می‌کنه...")
		if is_instance_valid(chess):
			chess.trigger_scripted_move(COORD_D7, COORD_D5, 0.85)
	elif _phase == "capture_d5" and tgt_idx == IDX_D5:
		_phase = "tour"
		_coordinator.hide_overlay_temporarily()
		_coordinator.show_hud_toast("ایول! مهره حریف رو زدی و رفت توی سینی کناری!")
		if is_instance_valid(chess):
			chess.tutorial_input_enabled = false
		_coordinator.get_tree().create_timer(1.0).timeout.connect(func():
			if not is_instance_valid(_coordinator):
				return
			_coordinator.advance_lesson_step()
		)


func _on_scripted_move_finished(_src_idx: int, _tgt_idx: int) -> void:
	if not is_instance_valid(_coordinator) or not is_instance_valid(_board):
		return
	if _phase != "wait_bot":
		return
	_phase = "select_e4"
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.tutorial_input_enabled = true
		chess.set_guided_cells([IDX_E4])

	var st_sel_cap := TutorialStep.create(
		"chess_select_e4",
		"۳. زدن مهره حریف",
		"حریف سربازش رو آورد روبه‌روی تو! دوباره سربازت (e4) رو انتخاب کن تا هدف قرمزِ حمله رو ببینی."
	)
	st_sel_cap.with_badge("تمرین حمله")
	st_sel_cap.with_hint("روی سرباز سفید e4 لمس کن")
	st_sel_cap.with_target(func(): return _get_cell_rect(IDX_E4), 10.0, 18.0)
	st_sel_cap.with_avoid_rect(func(): return _get_board_rect())
	st_sel_cap.with_scrim_alpha(0.84)
	st_sel_cap.with_interactive(true, false)
	st_sel_cap.with_placement("auto")
	_coordinator.show_custom_step(st_sel_cap, 4, TOTAL_DISPLAY_STEPS)


func _enter_capture_d5() -> void:
	_phase = "capture_d5"
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.tutorial_input_enabled = true
		chess.set_guided_cells([IDX_D5])

	var st_cap := TutorialStep.create(
		"chess_capture_d5",
		"ضربه و تسخیر مهره!",
		"حلقه قرمز یعنی می‌تونی مهره حریف رو بزنی! روی سرباز سیاه (d5) لمس کن تا از صفحه حذف بشه."
	)
	st_cap.with_badge("تمرین حمله")
	st_cap.with_hint("روی حلقه قرمز d5 لمس کن")
	st_cap.with_target(func(): return _get_cell_rect(IDX_D5), 10.0, 18.0)
	st_cap.with_avoid_rect(func(): return _get_board_rect())
	st_cap.with_scrim_alpha(0.84)
	st_cap.with_interactive(true, false)
	st_cap.with_placement("auto")
	_coordinator.show_custom_step(st_cap, 5, TOTAL_DISPLAY_STEPS)


func _highlight_static_piece(cell_idx: int, show_moves: bool) -> void:
	var chess := _board as TutorialChess3D
	if not is_instance_valid(chess):
		return
	chess.tutorial_input_enabled = false
	chess.set_guided_cells([cell_idx])
	if show_moves:
		chess.preview_piece_moves(cell_idx)
	else:
		chess.clear_piece_preview()


func _clear_piece_highlights() -> void:
	var chess := _board as TutorialChess3D
	if not is_instance_valid(chess):
		return
	chess.clear_guided_cells()
	chess.clear_piece_preview()


func _enter_check_demo() -> void:
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.clear_guided_cells()
		chess.clear_piece_preview()
		chess.show_demo_check_marker(IDX_E8_KING)


func _exit_check_demo() -> void:
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		chess.clear_demo_check_marker()


func _on_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_coordinator):
		_coordinator.nudge_overlay("برای ادامه آموزش، روی خانه طلایی مشخص‌شده لمس کن!")


func _get_cell_rect(cell_idx: int) -> Rect2:
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		return chess.get_cell_screen_rect(cell_idx)
	return Rect2()


func _get_board_rect() -> Rect2:
	var chess := _board as TutorialChess3D
	if is_instance_valid(chess):
		return chess.get_board_screen_rect()
	return Rect2()
