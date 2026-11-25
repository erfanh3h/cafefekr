class_name TutorialCoordinator
extends Node

## Master onboarding & tutorial orchestrator for Cafe Fekr.
## Coordinates two completely decoupled, extensible flows:
##
## 1. Pre-Login Offline Interactive Tic-Tac-Toe Tutorial
##    - Runs automatically on launch whenever the player is NOT logged in yet
##      (100% offline, zero NetworkManager emissions).
##    - Interactively teaches every top HUD button (2D/3D camera, Chat/Kori,
##      Emoji/Stickers, Settings/Menu, Opponent Card & Turn Timer) and how to
##      play & win Tic-Tac-Toe easily.
##    - Displays the real Win Dialog, then cleanly exits into the Auth Dialog.
##
## 2. Post-Auth One-Time Main Page Guided Tour
##    - Runs ONCE after authentication is completed (persisted via TutorialStore).
##    - Interactively showcases all 5 main bottom tabs (Play, Clan, Leaderboard,
##      Library, Profile) AND all 5 top buttons of the main page (Watch Live,
##      Match History, Friends, Notifications, Exit).

signal game_tutorial_finished()
signal library_tutorial_finished(game_type: String)
signal main_tutorial_finished()

const TUTORIAL_BOARD_SCENE: PackedScene = preload("res://scenes/games/tictactoe/tutorial_tictactoe_3d.tscn")
const DEFAULT_RETURN_BTN_TEXT: String = "بازگشت به کافه"

var is_game_tutorial_active: bool = false
var is_main_tutorial_active: bool = false

var _overlay: TutorialCoachOverlay = null
var _cafe_table: Node = null
var _base_game_hud: Control = null
var _menu_container: Control = null
var _main_tab_shell: Control = null
var _board: TutorialTicTacToe3D = null
var _active_lesson: GameTutorialLesson = null
var _lesson_board: Node3D = null
var _lesson_game_type: String = ""
var _is_final_lesson_step: bool = false
var _suppress_next_show: bool = false

var _steps: Array[TutorialStep] = []
var _step_index: int = -1
var _active_flow: String = "" # "" | "game" | "library_game" | "main"
var _game_phase: String = ""  # "" | "hud_tour" | "move_1" | "move_2" | "move_3" | "win"
var _saved_return_btn_text: String = DEFAULT_RETURN_BTN_TEXT
var _session_token: int = 0

# Bound temporary signal callables for clean disconnect
var _view_toggle_cb: Callable = Callable()
var _reaction_cb: Callable = Callable()


func _ready() -> void:
	_overlay = TutorialCoachOverlay.new()
	_overlay.name = "TutorialCoachOverlay"
	add_child(_overlay)
	_overlay.next_pressed.connect(_on_overlay_next)
	_overlay.back_pressed.connect(_on_overlay_back)
	_overlay.exit_pressed.connect(_on_overlay_exit)


# ==============================================================================
# PHASE 1: PRE-LOGIN OFFLINE INTERACTIVE TIC-TAC-TOE TUTORIAL
# ==============================================================================

func start_offline_game_tutorial(cafe_table: Node, base_game_hud: Control, menu_container: Control) -> void:
	if is_game_tutorial_active:
		return
	_stop_any_active_tour()

	_session_token += 1
	var my_token: int = _session_token
	is_game_tutorial_active = true
	_active_flow = "game"
	_game_phase = "hud_tour"

	_cafe_table = cafe_table
	_base_game_hud = base_game_hud
	_menu_container = menu_container

	# 1. Configure pure local offline match state in GameManager (no server IDs)
	GameManager.reset_match_state()
	GameManager.active_game_id = ""
	GameManager.current_game_type = GameTypes.TIC_TAC_TOE
	GameManager.current_round = 1
	GameManager.max_rounds = 1
	GameManager.p1_score = 0
	GameManager.p2_score = 0
	GameManager.my_player_index = 1
	GameManager.current_turn = 1
	GameManager.is_my_turn = true
	GameManager.is_game_active = true
	GameManager.is_spectating = false
	GameManager.match_players = [
		{
			"gamer_id": 1,
			"team_id": 1,
			"user_id": "tutorial_player",
			"name": "شما",
			"username": "شما",
			"image": 0,
			"level": 1,
			"score": 0,
			"not_played_turns": 0
		},
		{
			"gamer_id": 2,
			"team_id": 2,
			"user_id": "tutorial_bot",
			"name": "استاد کافه",
			"username": "استاد کافه",
			"image": 1,
			"level": 5,
			"score": 0,
			"not_played_turns": 0
		}
	]

	# 2. Switch UI cleanly into the 3D game table scene
	if is_instance_valid(_menu_container):
		_menu_container.visible = false
	if is_instance_valid(_cafe_table):
		_cafe_table.visible = true
		if _cafe_table.has_method("update_opponent_avatar"):
			_cafe_table.update_opponent_avatar(1)

	# 3. Prepare BaseGameHUD in offline tutorial mode
	if is_instance_valid(_base_game_hud):
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", true)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = true
		_base_game_hud.setup_match("دوز (آموزش)", "میز تمرینی کافه فکر")
		_base_game_hud.is_game_started = true
		_base_game_hud.is_start_overlay_dismissed = true
		_base_game_hud.force_dismiss_start_overlay(false)
		_base_game_hud.hide_turn_banner()
		_base_game_hud.update_turn(1)
		_base_game_hud.pause_turn_timer()
		if _base_game_hud.has_method("set_missed_turns_limit_visible"):
			_base_game_hud.set_missed_turns_limit_visible(false)
		if is_instance_valid(_base_game_hud.current_top_header) and _base_game_hud.current_top_header.has_method("update_timer"):
			_base_game_hud.current_top_header.update_timer(15.0, 15.0, 1)

	# 4. Spawn our inherited offline TutorialTicTacToe3D board onto CafeTable
	if is_instance_valid(_cafe_table) and _cafe_table.has_method("spawn_board"):
		var spawned: Node3D = _cafe_table.spawn_board(TUTORIAL_BOARD_SCENE)
		_board = spawned as TutorialTicTacToe3D

	if is_instance_valid(_board):
		_board.tutorial_input_enabled = false
		_board.tutorial_player_moved.connect(_on_tutorial_player_moved)
		_board.tutorial_bot_moved.connect(_on_tutorial_bot_moved)
		_board.tutorial_wrong_cell_tapped.connect(_on_tutorial_wrong_cell_tapped)
		_board.tutorial_player_won.connect(_on_tutorial_player_won)
		_board.tutorial_draw_reached.connect(_on_tutorial_draw_reached)

	AudioManager.play_game_music()

	# Hook optional interactive HUD feedback during the button tour
	_connect_game_tutorial_hud_listeners()

	# Wait briefly for the 3D camera intro glide & header layout to settle
	get_tree().create_timer(1.05).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or _session_token != my_token:
			return
		_steps = _build_game_tutorial_steps()
		_step_index = -1
		_advance_step()
	)


func _build_game_tutorial_steps() -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome modal
	var st_welcome: TutorialStep = TutorialStep.create(
		"game_welcome",
		"سلام به کافه فکر خوش اومدی",
		"آماده‌ای یه دست دوز سریع و باحال بزنیم؟ تو کمتر از یک دقیقه همه دکمه‌ها و قلق بازی رو یاد می‌گیری"
	)
	st_welcome.with_badge("خوش اومدی!")
	st_welcome.with_cta("بزن بریم!")
	st_welcome.with_placement("center")
	st_welcome.with_scrim_alpha(0.82)
	s.append(st_welcome)

	# 2. Top Button: 2D/3D Camera Toggle (interactive!)
	var st_view: TutorialStep = TutorialStep.create(
		"hud_view_2d3d",
		"زاویه دوربین سه‌بعدی و دوبعدی",
		"دوست داری میز رو از بالا ببینی یا زاویه سه‌بعدی؟ با این دکمه هر وقت خواستی نمای بازی رو عوض کن!"
	)
	st_view.with_badge("دکمه‌های بازی")
	st_view.with_cta("بعدی")
	st_view.with_hint("همین الان یه بار امتحانش کن یا بزن «بعدی»")
	st_view.with_target(func(): return _get_top_header_node("btn_view_2d3d"), 8.0, 16.0)
	st_view.with_avoid_rect(_get_game_header_avoid_rect)
	st_view.with_scrim_alpha(0.85)
	st_view.with_interactive(false, true)
	st_view.with_placement("bottom")
	s.append(st_view)

	# 3. Top Button: Quick Chat / Kori
	var st_chat: TutorialStep = TutorialStep.create(
		"hud_chat",
		"چت و کُری‌خوانی وسط بازی",
		"وسط مسابقه حال و هوا رو گرم کن! از اینجا می‌تونی پیام‌های آماده بفرستی و برای حریف کُری بخونی."
	)
	st_chat.with_badge("دکمه‌های بازی")
	st_chat.with_cta("بعدی")
	st_chat.with_target(func(): return _get_top_header_node("btn_chat"), 8.0, 16.0)
	st_chat.with_avoid_rect(_get_game_header_avoid_rect)
	st_chat.with_scrim_alpha(0.85)
	st_chat.with_placement("bottom")
	st_chat.with_hooks(_on_enter_chat_step)
	s.append(st_chat)

	# 4. Top Button: Emoji & Stickers
	var st_emoji: TutorialStep = TutorialStep.create(
		"hud_emoji",
		"استیکر و واکنش‌های باحال",
		"حرکت خفنی زدی یا حریف غافلگیرت کرد؟ با استیکرهای بامزه حس و حالت رو همون لحظه نشون بده!"
	)
	st_emoji.with_badge("دکمه‌های بازی")
	st_emoji.with_cta("بعدی")
	st_emoji.with_target(func(): return _get_top_header_node("btn_emoji"), 8.0, 16.0)
	st_emoji.with_avoid_rect(_get_game_header_avoid_rect)
	st_emoji.with_scrim_alpha(0.85)
	st_emoji.with_placement("bottom")
	st_emoji.with_hooks(_on_enter_emoji_step)
	s.append(st_emoji)

	# 5. Top Button: Settings / Menu Drawer
	var st_settings: TutorialStep = TutorialStep.create(
		"hud_settings",
		"تنظیمات و راهنمای میز",
		"صدا و موزیک، قوانین بازی، بستن چت یا خروج از میز؛ همه‌چیز مرتب توی این منو دم دستته."
	)
	st_settings.with_badge("دکمه‌های بازی")
	st_settings.with_cta("بعدی")
	st_settings.with_target(func(): return _get_top_header_node("btn_settings"), 8.0, 16.0)
	st_settings.with_avoid_rect(_get_game_header_avoid_rect)
	st_settings.with_scrim_alpha(0.85)
	st_settings.with_placement("bottom")
	s.append(st_settings)

	# 6. Opponent Pod & Turn Timer Bar
	var st_timer: TutorialStep = TutorialStep.create(
		"hud_turn_and_timer",
		"نوبت تو و تایمر طلایی!",
		"بالای صفحه حریف رو می‌بینی و این نوار طلایی وقتِ حرکتت رو نشون می‌ده. هر وقت روشن شد، نوبت توئه!"
	)
	st_timer.with_badge("نوبت و زمان")
	st_timer.with_cta("آماده‌ام، شروع بازی!")
	st_timer.with_target(_get_timer_bar_target, 10.0, 16.0)
	st_timer.with_avoid_rect(_get_game_header_avoid_rect)
	st_timer.with_scrim_alpha(0.85)
	st_timer.with_placement("bottom")
	st_timer.with_hooks(Callable(), _on_exit_timer_step)
	s.append(st_timer)

	# 7. Interactive Gameplay Move 1 — Guided Center Cell (Index 4)
	var st_move1: TutorialStep = TutorialStep.create(
		"play_move_1",
		"نوبت توئه! اولین حرکت",
		"باید ۳ تا از مهره‌هات رو پشت سر هم (افقی، عمودی یا مورب) ردیف کنی. بیا با خونه وسط شروع کنیم!"
	)
	st_move1.with_badge("دست تمرینی")
	st_move1.with_hint("روی خونه طلایی وسط بزن!")
	st_move1.with_target(func(): return _get_board_cell_rect(4), 8.0, 18.0)
	st_move1.with_avoid_rect(_get_board_screen_rect)
	st_move1.with_scrim_alpha(0.85)
	st_move1.with_interactive(true, false)
	st_move1.with_placement("auto")
	st_move1.with_hooks(_on_enter_move_1_step)
	s.append(st_move1)

	return s


func _on_enter_chat_step() -> void:
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_toast_hint("عجب حرکت هوشمندانه‌ای بود!")


func _on_enter_emoji_step() -> void:
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_reaction(2, 1)


func _get_timer_bar_target() -> Control:
	var frame: Control = _get_top_header_node("timer_bar_frame")
	if is_instance_valid(frame) and frame.is_visible_in_tree():
		return frame
	return _get_top_header_node("local_turn_bar_wrap")


func _on_exit_timer_step() -> void:
	if is_instance_valid(_base_game_hud) and is_instance_valid(_base_game_hud.reaction_picker) and _base_game_hud.reaction_picker.visible:
		_base_game_hud.reaction_picker.close()


func _on_enter_move_1_step() -> void:
	_game_phase = "move_1"
	if is_instance_valid(_board):
		_board.tutorial_input_enabled = true
		_board.set_guided_cells([4])


func _on_tutorial_player_moved(cell_idx: int) -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return

	# Hide coach overlay while bot thinks so player enjoys the 3D piece drop
	_overlay.hide_overlay()
	_board.tutorial_input_enabled = false

	if _game_phase == "move_1":
		_game_phase = "bot_1"
		if is_instance_valid(_base_game_hud):
			_base_game_hud.update_turn(2)
			_base_game_hud.pause_turn_timer()
			_base_game_hud.show_toast_hint("ایول! حالا ببینیم استاد کافه چی می‌چینه...")
		# Bot places O in top-left corner (0), keeping row 3-4-5 completely open
		_board.trigger_easy_bot_move(0, 0.70)
	elif _game_phase == "move_2":
		_game_phase = "bot_2"
		if is_instance_valid(_base_game_hud):
			_base_game_hud.update_turn(2)
			_base_game_hud.pause_turn_timer()
			_base_game_hud.show_toast_hint("عالی زدی! فقط یه قدم تا پیروزی مونده...")
		# Bot places O in top-right corner (2), leaving cell 5 wide open for player's easy win!
		_board.trigger_easy_bot_move(2, 0.70)
	elif _game_phase == "move_3":
		# Player just tapped winning cell (or free move if somehow not yet won)
		if _board._check_winning_line(1).is_empty():
			_game_phase = "bot_free"
			if is_instance_valid(_base_game_hud):
				_base_game_hud.update_turn(2)
				_base_game_hud.pause_turn_timer()
			_board.trigger_easy_bot_move(-1, 0.65)
	elif _game_phase == "free_play":
		if _board._check_winning_line(1).is_empty():
			_game_phase = "bot_free"
			if is_instance_valid(_base_game_hud):
				_base_game_hud.update_turn(2)
				_base_game_hud.pause_turn_timer()
			_board.trigger_easy_bot_move(-1, 0.65)


func _on_tutorial_bot_moved(_cell_idx: int) -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return

	if is_instance_valid(_base_game_hud):
		_base_game_hud.update_turn(1)
		_base_game_hud.pause_turn_timer()
		if is_instance_valid(_base_game_hud.current_top_header) and _base_game_hud.current_top_header.has_method("update_timer"):
			_base_game_hud.current_top_header.update_timer(15.0, 15.0, 1)

	if _game_phase == "bot_1":
		_game_phase = "move_2"
		var next_cell: int = 3 if int(_board.board_state[3]) == 0 else _board.find_recommended_player_cell()
		var step2: TutorialStep = TutorialStep.create(
			"play_move_2",
			"ایول! حالا ردیف رو بساز",
			"استاد کافه حرکتش رو زد. حالا این خونه طلایی رو بزن تا دو تا مهره‌ات کنار هم بیفتن و آماده بُرد بشی!"
		)
		step2.with_badge("دست تمرینی")
		step2.with_hint("خونه طلایی رو لمس کن!")
		step2.with_target(func(): return _get_board_cell_rect(next_cell), 8.0, 18.0)
		step2.with_avoid_rect(_get_board_screen_rect)
		step2.with_scrim_alpha(0.85)
		step2.with_interactive(true, false)
		step2.with_placement("auto")

		_board.tutorial_input_enabled = true
		_board.set_guided_cells([next_cell])
		_overlay.show_step(step2, 7, 9, false)

	elif _game_phase == "bot_2" or _game_phase == "bot_free":
		var win_cell: int = _board.find_recommended_player_cell()
		_game_phase = "move_3" if win_cell >= 0 else "free_play"
		var step3: TutorialStep = TutorialStep.create(
			"play_move_3",
			"ضربه نهایی و بُرد!",
			"فقط یه خونه تا پیروزی مونده! این خونه رو بزن تا ۳ تا مهره‌ات ردیف بشن و بازی رو ببری!"
		)
		step3.with_badge("حرکت پیروزی!")
		step3.with_hint("بزن روی خونه طلایی و برنده شو!")
		step3.with_target(func(): return _get_board_cell_rect(win_cell), 8.0, 18.0)
		step3.with_avoid_rect(_get_board_screen_rect)
		step3.with_scrim_alpha(0.85)
		step3.with_interactive(true, false)
		step3.with_placement("auto")

		_board.tutorial_input_enabled = true
		if win_cell >= 0:
			_board.set_guided_cells([win_cell])
		else:
			_board.clear_guided_cells()
		_overlay.show_step(step3, 8, 9, false)


func _on_tutorial_wrong_cell_tapped(_cell_idx: int) -> void:
	if is_instance_valid(_overlay):
		_overlay.show_nudge("برای ادامه آموزش، روی خونه طلایی روشن بزن!")


func _on_tutorial_draw_reached() -> void:
	if not is_game_tutorial_active or not is_instance_valid(_board):
		return
	# Safety net: guarantee the player always finishes with an easy victory
	if is_instance_valid(_base_game_hud):
		_base_game_hud.show_toast_hint("بیا یه دست سریع دیگه بریم تا این دفعه ببری!")
	get_tree().create_timer(0.9).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or not is_instance_valid(_board):
			return
		_board.reset_tutorial_match()
		_game_phase = "move_1"
		_board.tutorial_input_enabled = true
		_board.set_guided_cells([4])
		var retry_step: TutorialStep = TutorialStep.create(
			"play_retry",
			"یه دست سریع دیگه!",
			"بیا از خونه وسط شروع کنیم تا این دفعه راحت برنده بشی!"
		)
		retry_step.with_badge("دوباره بریم!")
		retry_step.with_hint("خونه طلایی وسط رو بزن!")
		retry_step.with_target(func(): return _get_board_cell_rect(4), 8.0, 18.0)
		retry_step.with_avoid_rect(_get_board_screen_rect)
		retry_step.with_scrim_alpha(0.85)
		retry_step.with_interactive(true, false)
		retry_step.with_placement("auto")
		_overlay.show_step(retry_step, 6, 9, false)
	)


func _on_tutorial_player_won(_winning_line: Array) -> void:
	if not is_game_tutorial_active:
		return
	var my_token: int = _session_token
	_game_phase = "win"
	_overlay.hide_overlay()
	TutorialStore.record_game_tutorial_win()

	GameManager.p1_score = 1
	GameManager.p2_score = 0
	if is_instance_valid(_base_game_hud):
		_base_game_hud.update_scores(1, 0)
		_base_game_hud.show_toast_hint("ایول قهرمان! اولین بُردت توی کافه فکر!")

	# Let the golden winning laser beam & 3D victory effects shine briefly,
	# then show the real GameResultDialog (Win Dialog).
	get_tree().create_timer(1.15).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or _session_token != my_token:
			return
		if is_instance_valid(_base_game_hud):
			var rd: Control = _base_game_hud.result_dialog
			if is_instance_valid(rd) and is_instance_valid(rd.btn_return):
				_saved_return_btn_text = rd.btn_return.text
			_base_game_hud.show_game_result(1, 1, 0, 50, 25, 0, true)
			if is_instance_valid(rd):
				if is_instance_valid(rd.lbl_title):
					rd.lbl_title.text_direction = Control.TEXT_DIRECTION_RTL
					rd.lbl_title.text = "ایول! برنده شدی!"
				if is_instance_valid(rd.lbl_subtitle):
					rd.lbl_subtitle.visible = true
					rd.lbl_subtitle.text_direction = Control.TEXT_DIRECTION_RTL
					rd.lbl_subtitle.text = "هم بازی دوز رو قشنگ یاد گرفتی هم دکمه‌ها رو! حالا وارد کافه فکر شو و با بازیکنای واقعی رقابت کن!"
				if is_instance_valid(rd.btn_return):
					rd.btn_return.text = "ورود به کافه فکر"
	)


func finish_offline_game_tutorial() -> void:
	if not is_game_tutorial_active:
		return
	_session_token += 1
	is_game_tutorial_active = false
	_active_flow = ""
	_game_phase = ""

	_disconnect_game_tutorial_hud_listeners()
	_overlay.hide_overlay()

	# Clean up board & 3D table
	if is_instance_valid(_cafe_table):
		if _cafe_table.has_method("clear_board"):
			_cafe_table.clear_board()
		if _cafe_table.has_method("reset_table_state"):
			_cafe_table.reset_table_state()
		if _cafe_table.has_method("transition_to_menu_view"):
			_cafe_table.transition_to_menu_view(0.4)
		_cafe_table.visible = false
	_board = null

	# Restore BaseGameHUD completely cleanly for future real online matches
	if is_instance_valid(_base_game_hud):
		if is_instance_valid(_base_game_hud.result_dialog) and is_instance_valid(_base_game_hud.result_dialog.btn_return):
			_base_game_hud.result_dialog.btn_return.text = _saved_return_btn_text if not _saved_return_btn_text.is_empty() else DEFAULT_RETURN_BTN_TEXT
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", false)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = false

	# Restore menu shell & clean GameManager match state
	if is_instance_valid(_menu_container):
		_menu_container.visible = true
	GameManager.reset_match_state()
	AudioManager.play_theme_music()

	game_tutorial_finished.emit()


# ==============================================================================
# PHASE 1B: LIBRARY INTERACTIVE GAME TUTORIALS (EXTENSIBLE PER-GAME LESSONS)
# ==============================================================================

func start_library_game_tutorial(game_type: String, cafe_table: Node, base_game_hud: Control, menu_container: Control) -> bool:
	if is_game_tutorial_active:
		return false
	var lesson: GameTutorialLesson = GameTutorialRegistry.create_lesson(game_type)
	if lesson == null:
		return false
	var board_scene: PackedScene = lesson.get_tutorial_board_scene()
	if board_scene == null:
		return false

	_stop_any_active_tour()

	_session_token += 1
	var my_token: int = _session_token
	is_game_tutorial_active = true
	_active_flow = "library_game"
	_game_phase = "lesson"
	_active_lesson = lesson
	_lesson_game_type = GameRegistry.normalize_type(game_type)
	_is_final_lesson_step = false

	_cafe_table = cafe_table
	_base_game_hud = base_game_hud
	_menu_container = menu_container

	# 1. Configure pure local offline match state in GameManager
	GameManager.reset_match_state()
	GameManager.is_tutorial_mode = true
	GameManager.active_game_id = ""
	GameManager.set_game_type(_lesson_game_type)
	GameManager.current_round = 1
	GameManager.max_rounds = 1
	GameManager.p1_score = 0
	GameManager.p2_score = 0
	GameManager.my_player_index = 1
	GameManager.current_turn = 1
	GameManager.is_game_active = true
	GameManager.is_spectating = false

	var my_name: String = GameManager.get_username()
	if my_name.is_empty():
		my_name = "شما"
	var my_image: int = int(GameManager.user_data.get("image", GameManager.user_data.get("user_image", 0)))
	var my_level: int = GameManager.get_user_level()
	GameManager.match_players = [
		{
			"gamer_id": 1,
			"team_id": 1,
			"user_id": "tutorial_player",
			"name": my_name,
			"username": my_name,
			"image": my_image,
			"level": my_level,
			"score": 0,
			"not_played_turns": 0
		},
		{
			"gamer_id": 2,
			"team_id": 2,
			"user_id": "tutorial_bot",
			"name": "استاد کافه",
			"username": "استاد کافه",
			"image": 1,
			"level": 5,
			"score": 0,
			"not_played_turns": 0
		}
	]

	# 2. Switch UI cleanly into the 3D game table scene
	if is_instance_valid(_menu_container):
		_menu_container.visible = false
	if is_instance_valid(_cafe_table):
		_cafe_table.visible = true
		if _cafe_table.has_method("update_opponent_avatar"):
			_cafe_table.update_opponent_avatar(1)

	# 3. Prepare BaseGameHUD in library tutorial mode (hide top header & sub-header rail)
	if is_instance_valid(_base_game_hud):
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", true)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = true
		_base_game_hud.setup_match(lesson.get_tutorial_title_fa(), lesson.get_tutorial_subtitle_fa())
		_base_game_hud.is_game_started = true
		_base_game_hud.is_start_overlay_dismissed = true
		_base_game_hud.force_dismiss_start_overlay(false)
		_base_game_hud.hide_turn_banner()
		_base_game_hud.pause_turn_timer()
		if is_instance_valid(_base_game_hud.top_header_slot):
			_base_game_hud.top_header_slot.visible = false
		if is_instance_valid(_base_game_hud.sub_header_rail):
			_base_game_hud.sub_header_rail.visible = false

	if is_instance_valid(_overlay):
		_overlay.set_exit_button_visible(true)

	# 4. Spawn inherited Tutorial<Game>3D board onto CafeTable
	if is_instance_valid(_cafe_table) and _cafe_table.has_method("spawn_board"):
		_lesson_board = _cafe_table.spawn_board(board_scene)

	if is_instance_valid(_lesson_board):
		_active_lesson.on_board_ready(_lesson_board, self)

	AudioManager.play_game_music()

	# Wait briefly for the 3D camera intro glide & header layout to settle
	get_tree().create_timer(1.05).timeout.connect(func():
		if not is_instance_valid(self) or not is_game_tutorial_active or _session_token != my_token:
			return
		if _active_lesson == null:
			return
		_steps = _active_lesson.build_steps(self)
		_step_index = -1
		_advance_step()
	)
	return true


func finish_library_game_tutorial() -> void:
	if not is_game_tutorial_active or _active_flow != "library_game":
		return
	var finished_type: String = _lesson_game_type
	_session_token += 1
	is_game_tutorial_active = false
	_active_flow = ""
	_game_phase = ""
	_is_final_lesson_step = false
	_lesson_game_type = ""

	if _active_lesson != null:
		_active_lesson.cleanup()
		_active_lesson = null

	if is_instance_valid(_overlay):
		_overlay.set_exit_button_visible(false)
		_overlay.hide_overlay()

	if is_instance_valid(_cafe_table):
		if _cafe_table.has_method("clear_board"):
			_cafe_table.clear_board()
		if _cafe_table.has_method("reset_table_state"):
			_cafe_table.reset_table_state()
		if _cafe_table.has_method("transition_to_menu_view"):
			_cafe_table.transition_to_menu_view(0.4)
		_cafe_table.visible = false
	_lesson_board = null

	if is_instance_valid(_base_game_hud):
		if is_instance_valid(_base_game_hud.top_header_slot):
			_base_game_hud.top_header_slot.visible = true
		if is_instance_valid(_base_game_hud.sub_header_rail):
			_base_game_hud.sub_header_rail.visible = true
		if "is_offline_tutorial" in _base_game_hud:
			_base_game_hud.set("is_offline_tutorial", false)
		_base_game_hud.reset_for_new_match(false)
		_base_game_hud.visible = false

	if is_instance_valid(_menu_container):
		_menu_container.visible = true
	GameManager.reset_match_state()
	AudioManager.play_theme_music()

	library_tutorial_finished.emit(finished_type)


func is_library_game_tutorial_active() -> bool:
	return is_game_tutorial_active and _active_flow == "library_game"


func advance_lesson_step() -> void:
	if is_library_game_tutorial_active():
		_advance_step()


func show_custom_step(step: TutorialStep, idx: int, total: int) -> void:
	if is_library_game_tutorial_active() and is_instance_valid(_overlay):
		_is_final_lesson_step = false
		_overlay.show_step(step, idx, total, false)


func show_final_lesson_step(step: TutorialStep, idx: int, total: int) -> void:
	if is_library_game_tutorial_active() and is_instance_valid(_overlay):
		_is_final_lesson_step = true
		_overlay.show_step(step, idx, total, false)


func hide_overlay_temporarily() -> void:
	_suppress_next_show = true
	if is_instance_valid(_overlay):
		_overlay.set_exit_button_visible(false)
		_overlay.hide_overlay()


func reshow_current_step() -> void:
	_suppress_next_show = false
	if is_library_game_tutorial_active() and _step_index >= 0 and _step_index < _steps.size() and is_instance_valid(_overlay):
		_overlay.set_exit_button_visible(true)
		var step: TutorialStep = _steps[_step_index]
		var total_display: int = _active_lesson.get_total_display_steps(_steps.size()) if _active_lesson != null else _steps.size()
		var display_idx: int = _active_lesson.get_display_step_index(_step_index) if _active_lesson != null else _step_index
		_overlay.show_step(step, display_idx, total_display, false)


func nudge_overlay(msg: String) -> void:
	if is_instance_valid(_overlay):
		_overlay.show_nudge(msg)


func show_hud_turn(turn: int, toast_msg: String = "") -> void:
	if is_instance_valid(_base_game_hud):
		_base_game_hud.update_turn(turn)
		_base_game_hud.pause_turn_timer()
		if not toast_msg.is_empty():
			_base_game_hud.show_toast_hint(toast_msg)


func show_hud_toast(msg: String) -> void:
	if is_instance_valid(_base_game_hud) and not msg.is_empty():
		_base_game_hud.show_toast_hint(msg)


func zoom_table_in(steps: int = 2) -> void:
	if is_instance_valid(_cafe_table) and _cafe_table.has_method("zoom_in"):
		for _i in range(steps):
			_cafe_table.zoom_in()


func _connect_game_tutorial_hud_listeners() -> void:
	_disconnect_game_tutorial_hud_listeners()
	if is_instance_valid(_base_game_hud):
		_view_toggle_cb = func():
			if is_game_tutorial_active and _active_flow == "game" and _step_index >= 0 and _step_index < _steps.size():
				if _steps[_step_index].id == "hud_view_2d3d":
					if is_instance_valid(_base_game_hud):
						_base_game_hud.show_toast_hint("باریکلا! هر وقت خواستی می‌تونی زاویه دوربین رو عوض کنی.")
		if _base_game_hud.has_signal("top_view_requested") and not _base_game_hud.top_view_requested.is_connected(_view_toggle_cb):
			_base_game_hud.top_view_requested.connect(_view_toggle_cb)

		_reaction_cb = func(_r_id):
			if is_game_tutorial_active and is_instance_valid(_base_game_hud):
				_base_game_hud.show_toast_hint("ایول! واکنشت توی مسابقه واقعی هم همین‌طور نشون داده می‌شه.")
		if _base_game_hud.has_signal("reaction_sent") and not _base_game_hud.reaction_sent.is_connected(_reaction_cb):
			_base_game_hud.reaction_sent.connect(_reaction_cb)


func _disconnect_game_tutorial_hud_listeners() -> void:
	if is_instance_valid(_base_game_hud):
		if _view_toggle_cb.is_valid() and _base_game_hud.has_signal("top_view_requested") and _base_game_hud.top_view_requested.is_connected(_view_toggle_cb):
			_base_game_hud.top_view_requested.disconnect(_view_toggle_cb)
		if _reaction_cb.is_valid() and _base_game_hud.has_signal("reaction_sent") and _base_game_hud.reaction_sent.is_connected(_reaction_cb):
			_base_game_hud.reaction_sent.disconnect(_reaction_cb)
	_view_toggle_cb = Callable()
	_reaction_cb = Callable()


# ==============================================================================
# PHASE 2: POST-AUTH ONE-TIME MAIN PAGE GUIDED TOUR (5 TABS + TOP BUTTONS)
# ==============================================================================

func try_start_main_page_tutorial(main_tab_shell: Control) -> bool:
	if TutorialStore.is_main_tour_completed():
		return false
	if is_game_tutorial_active or is_main_tutorial_active:
		return false
	if not is_instance_valid(main_tab_shell) or not main_tab_shell.visible:
		return false

	_session_token += 1
	var my_token: int = _session_token
	is_main_tutorial_active = true
	_active_flow = "main"
	_main_tab_shell = main_tab_shell

	# Ensure we start cleanly on the Play tab
	if _main_tab_shell.has_method("close_subpage"):
		_main_tab_shell.close_subpage()
	if _main_tab_shell.has_method("switch_to_tab"):
		_main_tab_shell.switch_to_tab("play")

	# Wait briefly so layout & controls finalize their global rects
	get_tree().create_timer(0.35).timeout.connect(func():
		if not is_instance_valid(self) or not is_main_tutorial_active or _session_token != my_token:
			return
		_steps = _build_main_page_tutorial_steps()
		_step_index = -1
		_advance_step()
	)
	return true


func _build_main_page_tutorial_steps() -> Array[TutorialStep]:
	var s: Array[TutorialStep] = []

	# 1. Welcome to Main Lobby
	var st_main_welcome: TutorialStep = TutorialStep.create(
		"main_welcome",
		"به سالن کافه فکر خوش اومدی!",
		"حسابت آماده شد! بیا یه گشت سریع و باحال تو بخش‌های اصلی و دکمه‌های بالای صفحه بزنیم تا همه‌جا رو بلد باشی."
	)
	st_main_welcome.with_badge("سالن کافه فکر")
	st_main_welcome.with_cta("بزن بریم!")
	st_main_welcome.with_placement("center")
	st_main_welcome.with_scrim_alpha(0.82)
	s.append(st_main_welcome)

	# --- 5 MAIN TABS (BottomNavigation) ---

	# 2. Tab: Play (بازی)
	var st_tab_play: TutorialStep = TutorialStep.create(
		"tab_play",
		"۱. میز بازی و رقابت",
		"قلب کافه فکر اینجاست! از رقابت ۱ به ۱ و بازی‌های چندنفره تا میزهای دوستانه، هر مدلی دوست داری انتخاب کن."
	)
	st_tab_play.with_badge("بخش‌های اصلی (۱ از ۵)")
	st_tab_play.with_cta("بعدی")
	st_tab_play.with_target(func(): return _get_bottom_nav_btn("btn_play"), 8.0, 16.0)
	st_tab_play.with_scrim_alpha(0.85)
	st_tab_play.with_placement("top")
	st_tab_play.with_hooks(func(): _switch_main_tab("play"))
	s.append(st_tab_play)

	# 3. Tab: Social / Clan (اتحاد)
	var st_tab_social: TutorialStep = TutorialStep.create(
		"tab_social",
		"۲. اتحاد و کلن",
		"تیم خودت رو بساز یا به یه اتحاد باحال بپیوند! با هم‌تیمی‌هات گپ بزن و با هم امتیاز کلن رو بالا ببر."
	)
	st_tab_social.with_badge("بخش‌های اصلی (۲ از ۵)")
	st_tab_social.with_cta("بعدی")
	st_tab_social.with_target(func(): return _get_bottom_nav_btn("btn_social"), 8.0, 16.0)
	st_tab_social.with_scrim_alpha(0.85)
	st_tab_social.with_placement("top")
	st_tab_social.with_hooks(func(): _switch_main_tab("social"))
	s.append(st_tab_social)

	# 4. Tab: Leaderboard (برترین‌ها)
	var st_tab_history: TutorialStep = TutorialStep.create(
		"tab_history",
		"۳. جدول برترین‌ها",
		"اینجا ستاره‌های کافه فکر صف کشیدن! با هر بُرد پله‌پله بالا برو و اسمت رو بین برترین‌ها ثبت کن."
	)
	st_tab_history.with_badge("بخش‌های اصلی (۳ از ۵)")
	st_tab_history.with_cta("بعدی")
	st_tab_history.with_target(func(): return _get_bottom_nav_btn("btn_history"), 8.0, 16.0)
	st_tab_history.with_scrim_alpha(0.85)
	st_tab_history.with_placement("top")
	st_tab_history.with_hooks(func(): _switch_main_tab("history"))
	s.append(st_tab_history)

	# 5. Tab: Library (کتابخانه)
	var st_tab_library: TutorialStep = TutorialStep.create(
		"tab_library",
		"۴. کتابخانه بازی‌ها",
		"قانون یا قلقِ یه بازی رو می‌خوای بدونی؟ همه بازی‌های فکری کافه فکر با راهنمای کامل اینجان."
	)
	st_tab_library.with_badge("بخش‌های اصلی (۴ از ۵)")
	st_tab_library.with_cta("بعدی")
	st_tab_library.with_target(func(): return _get_bottom_nav_btn("btn_library"), 8.0, 16.0)
	st_tab_library.with_scrim_alpha(0.85)
	st_tab_library.with_placement("top")
	st_tab_library.with_hooks(func(): _switch_main_tab("library"))
	s.append(st_tab_library)

	# 6. Tab: User Profile (کاربر)
	var st_tab_user: TutorialStep = TutorialStep.create(
		"tab_user",
		"۵. پروفایل تو",
		"سطح، تجربه، سکه‌ها، آواتار و قاب اختصاصی‌ات اینجاست؛ هرجور دوست داری کاراکترت رو خفن‌تر کن!"
	)
	st_tab_user.with_badge("بخش‌های اصلی (۵ از ۵)")
	st_tab_user.with_cta("بعدی")
	st_tab_user.with_target(func(): return _get_bottom_nav_btn("btn_user"), 8.0, 16.0)
	st_tab_user.with_scrim_alpha(0.85)
	st_tab_user.with_placement("top")
	st_tab_user.with_hooks(func(): _switch_main_tab("user"))
	s.append(st_tab_user)

	# --- TOP BUTTONS OF MAIN PAGE (PlayTab TopBarRow) ---

	# 7. Top Button: Watch Live (تماشای زنده)
	var st_top_watch: TutorialStep = TutorialStep.create(
		"top_watch_live",
		"تماشای زنده بازی‌ها",
		"ببین حرفه‌ای‌ها چطور بازی می‌کنن! از اینجا می‌تونی مسابقات زنده رو ببینی و تاکتیک‌های جدید یاد بگیری."
	)
	st_top_watch.with_badge("دکمه‌های بالا")
	st_top_watch.with_cta("بعدی")
	st_top_watch.with_target(func(): return _get_play_tab_btn("btn_watch_live"), 8.0, 16.0)
	st_top_watch.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_watch.with_scrim_alpha(0.85)
	st_top_watch.with_placement("bottom")
	st_top_watch.with_hooks(_focus_play_tab_top)
	s.append(st_top_watch)

	# 8. Top Button: Match History (تاریخچه بازی‌ها)
	var st_top_history: TutorialStep = TutorialStep.create(
		"top_history",
		"تاریخچه بازی‌هات",
		"نتیجه، امتیاز و جزئیات بازی‌های قبلیت همه اینجا ذخیره شدن؛ هر وقت خواستی برگرد و چکشون کن."
	)
	st_top_history.with_badge("دکمه‌های بالا")
	st_top_history.with_cta("بعدی")
	st_top_history.with_target(func(): return _get_play_tab_btn("btn_history"), 8.0, 14.0)
	st_top_history.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_history.with_scrim_alpha(0.85)
	st_top_history.with_placement("bottom")
	st_top_history.with_hooks(_focus_play_tab_top)
	s.append(st_top_history)

	# 9. Top Button: Friends & Direct Messages (دوستان و پیام‌ها)
	var st_top_friends: TutorialStep = TutorialStep.create(
		"top_friends",
		"دوستان و پیام‌ها",
		"رفیقات رو اینجا پیدا کن، باهاشون گپ بزن و یه راست دعوتشون کن سر میز مسابقه!"
	)
	st_top_friends.with_badge("دکمه‌های بالا")
	st_top_friends.with_cta("بعدی")
	st_top_friends.with_target(func(): return _get_play_tab_btn("btn_friends"), 8.0, 14.0)
	st_top_friends.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_friends.with_scrim_alpha(0.85)
	st_top_friends.with_placement("bottom")
	st_top_friends.with_hooks(_focus_play_tab_top)
	s.append(st_top_friends)

	# 10. Top Button: Notifications (اعلان‌ها)
	var st_top_notif: TutorialStep = TutorialStep.create(
		"top_notifications",
		"اعلان‌ها و دعوت‌نامه‌ها",
		"دعوت به بازی، درخواست دوستی یا خبرهای مهم؛ هیچ‌چیز از دستت درنمی‌ره و همه اینجا بهت خبر داده می‌شن."
	)
	st_top_notif.with_badge("دکمه‌های بالا")
	st_top_notif.with_cta("بعدی")
	st_top_notif.with_target(func(): return _get_play_tab_btn("btn_notifications"), 8.0, 14.0)
	st_top_notif.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_notif.with_scrim_alpha(0.85)
	st_top_notif.with_placement("bottom")
	st_top_notif.with_hooks(_focus_play_tab_top)
	s.append(st_top_notif)

	# 11. Top Button: Exit (خروج)
	var st_top_exit: TutorialStep = TutorialStep.create(
		"top_exit",
		"دکمه خروج",
		"هر وقت کارت تموم شد، از اینجا با خیال راحت و با تاییدیه ایمن از برنامه خارج شو."
	)
	st_top_exit.with_badge("دکمه‌های بالا")
	st_top_exit.with_cta("بعدی")
	st_top_exit.with_target(func(): return _get_play_tab_btn("btn_exit"), 8.0, 14.0)
	st_top_exit.with_avoid_rect(_get_play_topbar_avoid_rect)
	st_top_exit.with_scrim_alpha(0.85)
	st_top_exit.with_placement("bottom")
	st_top_exit.with_hooks(_focus_play_tab_top)
	s.append(st_top_exit)

	# 12. Completion Card
	var st_main_done: TutorialStep = TutorialStep.create(
		"main_done",
		"همه‌چیز رو یاد گرفتی، قهرمان!",
		"الان دیگه کافه فکر رو کامل بلدی! اولین مسابقه‌ات رو انتخاب کن و نشون بده کی رئیس میزه!"
	)
	st_main_done.with_badge("آماده رقابت!")
	st_main_done.with_cta("شروع رقابت!")
	st_main_done.with_placement("center")
	st_main_done.with_scrim_alpha(0.82)
	st_main_done.with_hooks(func(): _switch_main_tab("play"))
	s.append(st_main_done)

	return s


func _finish_main_page_tutorial() -> void:
	if not is_main_tutorial_active:
		return
	is_main_tutorial_active = false
	_active_flow = ""
	_overlay.hide_overlay()
	_switch_main_tab("play")
	TutorialStore.mark_main_tour_completed()
	main_tutorial_finished.emit()


func cancel_main_page_tutorial_if_active() -> void:
	if is_main_tutorial_active:
		is_main_tutorial_active = false
		_active_flow = ""
		_overlay.hide_overlay()


# ==============================================================================
# STEP ENGINE & TARGET RESOLVERS
# ==============================================================================

func _advance_step() -> void:
	if _step_index >= 0 and _step_index < _steps.size():
		var prev_step: TutorialStep = _steps[_step_index]
		if prev_step.on_exit.is_valid():
			prev_step.on_exit.call()

	_step_index += 1
	if _step_index >= _steps.size():
		if _active_flow == "main":
			_finish_main_page_tutorial()
		elif _active_flow == "library_game":
			finish_library_game_tutorial()
		return

	_present_current_step()


func _go_back_step() -> void:
	if _step_index <= 0:
		return
	var curr_step: TutorialStep = _steps[_step_index]
	if curr_step.on_exit.is_valid():
		curr_step.on_exit.call()
	_step_index -= 1
	_present_current_step()


func _present_current_step() -> void:
	if _step_index < 0 or _step_index >= _steps.size():
		return
	_suppress_next_show = false
	var step: TutorialStep = _steps[_step_index]
	if step.on_enter.is_valid():
		step.on_enter.call()
	if _suppress_next_show:
		_suppress_next_show = false
		return

	var total_display: int = 9 if _active_flow == "game" else _steps.size()
	var display_idx: int = _step_index
	if _active_flow == "library_game" and _active_lesson != null:
		total_display = _active_lesson.get_total_display_steps(_steps.size())
		display_idx = _active_lesson.get_display_step_index(_step_index)
	var can_back: bool = (_active_flow == "main" and _step_index > 0) or (_active_flow == "game" and _step_index > 0 and _game_phase == "hud_tour")
	_overlay.show_step(step, display_idx, total_display, can_back)


func _on_overlay_next() -> void:
	if _active_flow == "library_game":
		if _is_final_lesson_step:
			finish_library_game_tutorial()
		else:
			_advance_step()
	elif _active_flow == "game" or _active_flow == "main":
		_advance_step()


func _on_overlay_back() -> void:
	if _active_flow == "game" or _active_flow == "main" or _active_flow == "library_game":
		_go_back_step()


func _on_overlay_exit() -> void:
	if _active_flow == "library_game":
		finish_library_game_tutorial()


func _stop_any_active_tour() -> void:
	_disconnect_game_tutorial_hud_listeners()
	if _active_lesson != null:
		_active_lesson.cleanup()
		_active_lesson = null
	_lesson_board = null
	_lesson_game_type = ""
	_is_final_lesson_step = false
	_suppress_next_show = false
	is_game_tutorial_active = false
	is_main_tutorial_active = false
	_active_flow = ""
	_game_phase = ""
	_steps.clear()
	_step_index = -1
	if is_instance_valid(_overlay):
		_overlay.set_exit_button_visible(false)
		_overlay.hide_overlay()


func _get_top_header_node(prop_name: String) -> Control:
	if not is_instance_valid(_base_game_hud):
		return null
	var header: Node = _base_game_hud.get("current_top_header")
	if not is_instance_valid(header):
		return null
	var node: Variant = header.get(prop_name)
	if node is Control and is_instance_valid(node):
		return node as Control
	return null


func _get_board_cell_rect(cell_idx: int) -> Rect2:
	if not is_instance_valid(_board):
		return Rect2()
	return _board.get_cell_screen_rect(cell_idx)


func _get_board_screen_rect() -> Rect2:
	if not is_instance_valid(_board):
		return Rect2()
	return _board.get_board_screen_rect()


func _get_game_header_avoid_rect() -> Rect2:
	var combined := Rect2()
	var top_row: Control = _get_top_header_node("top_row")
	if is_instance_valid(top_row) and top_row.is_visible_in_tree():
		combined = top_row.get_global_rect()
	var timer_wrap: Control = _get_top_header_node("local_turn_bar_wrap")
	if is_instance_valid(timer_wrap) and timer_wrap.is_visible_in_tree():
		var tr: Rect2 = timer_wrap.get_global_rect()
		if tr.size.x > 1.0 and tr.size.y > 1.0:
			combined = tr if combined.size.x <= 1.0 else combined.merge(tr)
	return combined


func _focus_play_tab_top() -> void:
	_switch_main_tab("play")
	if not is_instance_valid(_main_tab_shell):
		return
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	if is_instance_valid(play_tab):
		var sc: ScrollContainer = play_tab.get_node_or_null("Scroll") as ScrollContainer
		if is_instance_valid(sc):
			sc.scroll_vertical = 0


func _get_play_topbar_avoid_rect() -> Rect2:
	if not is_instance_valid(_main_tab_shell):
		return Rect2()
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	if not is_instance_valid(play_tab):
		return Rect2()
	var top_bar: Control = play_tab.get_node_or_null("Scroll/Content/TopBarRow") as Control
	if is_instance_valid(top_bar) and top_bar.is_visible_in_tree():
		return top_bar.get_global_rect()
	return Rect2()


func _switch_main_tab(tab_name: String) -> void:
	if is_instance_valid(_main_tab_shell) and _main_tab_shell.has_method("switch_to_tab"):
		_main_tab_shell.switch_to_tab(tab_name)


func _get_bottom_nav_btn(prop_name: String) -> Control:
	if not is_instance_valid(_main_tab_shell):
		return null
	var nav: Node = _main_tab_shell.get("bottom_navigation")
	if not is_instance_valid(nav):
		return null
	var btn: Variant = nav.get(prop_name)
	if btn is Control and is_instance_valid(btn):
		return btn as Control
	return null


func _get_play_tab_btn(prop_name: String) -> Control:
	if not is_instance_valid(_main_tab_shell):
		return null
	var play_tab: Control = null
	if _main_tab_shell.has_method("get_tab_instance"):
		play_tab = _main_tab_shell.call("get_tab_instance", "play") as Control
	elif _main_tab_shell.has_method("get_active_tab_instance"):
		play_tab = _main_tab_shell.call("get_active_tab_instance") as Control
	if not is_instance_valid(play_tab):
		return null
	var btn: Variant = play_tab.get(prop_name)
	if btn is Control and is_instance_valid(btn):
		return btn as Control
	return null
